import Foundation
import RealityKit
import simd

/// Gameplay root for the vehicle. The imported model sits in a holder that fixes
/// orientation and scale; only `root` is animated (brief §3).
@MainActor
final class SpeederController {
    let root = Entity()
    let engineLight = PointLight()
    let underLight = PointLight()
    private let holder = Entity()
    private var glows: [ModelEntity] = []
    private var underGlow: ModelEntity?
    private var trail: Entity?

    private(set) var x: Float = 0
    private(set) var steer: Float = 0
    private var vx: Float = 0
    private var recoilTimer: Float = 0
    private var recoilDir: Float = 1
    /// True while pressed against the roadside barrier.
    private(set) var scraping = false
    let laneLimit: Float = 6.9
    let maxAltitude: Float = 5.6
    /// Height of the vehicle centre above the road (rest hover = restHeight).
    private(set) var altitude: Float = 1.05
    private var vy: Float = 0
    private(set) var bank: Float = 0
    let halfHeight: Float = 0.55
    /// When set, movement is constrained to a cylinder (centre height, radius).
    var tube: (centerY: Float, radius: Float)? = nil
    let restHeight: Float = 1.05
    let scale: Float = 2.0

    static func load(materials: SceneMaterials) async throws -> SpeederController {
        guard let url = Bundle.main.url(forResource: "Speeder", withExtension: "usdz") else {
            throw NSError(domain: "Speeder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speeder.usdz missing from bundle"])
        }
        let model = try await Entity(contentsOf: url)
        return SpeederController(model: model, materials: materials)
    }

    init(model: Entity, materials: SceneMaterials) {
        root.name = "SpeederRoot"
        model.name = "ImportedSpeeder"
        let bounds = model.visualBounds(relativeTo: nil)
        // centre the mesh on the gameplay root, nose (+X in the asset) toward -Z
        model.position = -bounds.center + SIMD3<Float>(0, bounds.extents.y * 0.15, 0)
        holder.addChild(model)
        holder.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
        holder.scale = SIMD3<Float>(repeating: scale)
        root.addChild(holder)
        root.position = [0, restHeight, 0]

        let rearZ = bounds.extents.x * 0.5 * scale     // asset length axis becomes Z
        // engine halos: bright cyan core + wide magenta halo
        for (offset, color, size, alpha) in [
            (SIMD3<Float>( 0.02, 0.18, rearZ * 0.96), Neon.cyan, Float(0.95), Float(0.95)),     // main nozzle core
            (SIMD3<Float>( 0.02, 0.12, rearZ * 1.02), Neon.magenta, Float(2.0), Float(0.28)),  // wide halo
            (SIMD3<Float>(-0.36, -0.42, rearZ * 0.35), Neon.cyan, Float(0.45), Float(0.7)),    // lower thrusters
            (SIMD3<Float>( 0.36, -0.42, rearZ * 0.35), Neon.cyan, Float(0.45), Float(0.7)),
        ] {
            let q = ModelEntity(mesh: .generatePlane(width: size, height: size), materials: [materials.glow(color, opacity: alpha)])
            q.position = offset
            root.addChild(q)
            glows.append(q)
        }
        // hover glow pool on the road surface under the vehicle
        let pool = ModelEntity(mesh: .generatePlane(width: 3.2, depth: 4.5), materials: [materials.glow(Neon.magenta, opacity: 0.22)])
        pool.position = [0, -restHeight + 0.04, 0.2]
        root.addChild(pool)
        underGlow = pool

        engineLight.light.color = .rgb(Neon.cyan)
        engineLight.light.intensity = 18000
        engineLight.light.attenuationRadius = 9
        engineLight.position = [0, 0.3, rearZ * 1.1]
        root.addChild(engineLight)

        underLight.light.color = .rgb(Neon.magenta)
        underLight.light.intensity = 14000
        underLight.light.attenuationRadius = 7
        underLight.position = [0, -0.4, 0]
        root.addChild(underLight)

        // short additive engine trail
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .box
        emitter.emitterShapeSize = [1.6, 0.25, 0.2]
        emitter.birthLocation = .volume
        emitter.emissionDirection = [0, 0, 1]
        emitter.speed = 22
        emitter.speedVariation = 6
        emitter.mainEmitter.birthRate = 160
        emitter.mainEmitter.lifeSpan = 0.22
        emitter.mainEmitter.lifeSpanVariation = 0.08
        emitter.mainEmitter.size = 0.10
        emitter.mainEmitter.sizeVariation = 0.05
        emitter.mainEmitter.stretchFactor = 5
        emitter.mainEmitter.blendMode = .additive
        emitter.mainEmitter.opacityCurve = .quickFadeInOut
        emitter.mainEmitter.color = .evolving(start: .single(.rgb(Neon.cyan, 0.9)), end: .single(.rgb(Neon.magenta, 0.0)))
        let t = Entity()
        t.components.set(emitter)
        t.position = [0, 0.05, rearZ * 0.95]
        root.addChild(t)
        trail = t
    }

    func setParticles(_ on: Bool) { trail?.isEnabled = on }
    func setLights(_ on: Bool) { engineLight.isEnabled = on; underLight.isEnabled = on }

    /// Kick the vehicle after a collision.
    func recoil(direction: Float) {
        recoilTimer = 0.45
        recoilDir = direction
    }

    /// Conduit geometry and how much of it applies (eased in and out by the scroller so a
    /// section change never snaps the vehicle).
    var tubeBlend: Float = 0
    /// Fork divider: (side, minimum |x| on that side); set by the scroller past the nose.
    var wedgeLimit: (side: Float, limit: Float)? = nil
    /// Bank without the collision jolt: what the camera follows.
    private(set) var smoothBank: Float = 0
    private var lastTrailRate = -1

    func update(dt: Float, time: Float, steerInput: Float, climbInput: Float, speedNorm: Float, roadShift: Float) {
        steer = damp(steer, steerInput, 8.0, dt)
        // velocity-based steering; curves tug the vehicle toward the outside
        let steerSpeed: Float = 7.5 + 7.0 * speedNorm
        var newX = x + steer * steerSpeed * dt - roadShift * 0.6
        if recoilTimer > 0 { newX += recoilDir * 6.0 * dt * (recoilTimer / 0.45) }
        // altitude: stick drives vertical speed, settles back toward hover height when released
        let climbSpeed: Float = 6.5
        let inTube = tubeBlend >= 0.5
        if abs(climbInput) > 0.05 {
            vy = damp(vy, climbInput * climbSpeed, 10, dt)
        } else {
            // hold altitude when released; only drift down when already close to the deck
            let settle: Float = (!inTube && altitude < 1.6) ? -1.2 : 0
            vy = damp(vy, settle, 6, dt)
        }
        var newY = altitude + vy * dt
        // two constraint sets blended by the conduit lead-in: the flat road's lane limit and
        // altitude band, and the pipe's cylinder
        var flatScrape = abs(newX) > laneLimit
        var flatX = max(-laneLimit, min(laneLimit, newX))
        if let w = wedgeLimit, flatX * w.side < w.limit {
            // the divider wall: pushed out to the branch, with the scrape response
            flatX = w.limit * w.side
            flatScrape = true
        }
        let flatY = max(restHeight, min(maxAltitude, newY))
        var tubeX = newX, tubeY = newY, tubeScrape = false
        if let tube, tubeBlend > 0 {
            var d = SIMD2<Float>(newX, newY - tube.centerY)
            let len = simd_length(d)
            if len > tube.radius { d *= tube.radius / len; tubeScrape = true }
            tubeX = d.x; tubeY = d.y + tube.centerY
        }
        let b = tubeBlend
        newX = flatX + (tubeX - flatX) * b
        newY = flatY + (tubeY - flatY) * b
        scraping = inTube ? tubeScrape : flatScrape
        if newY <= restHeight && vy < 0 { vy = 0 }
        altitude = newY
        vx = (newX - x) / max(dt, 1e-4)
        x = newX
        recoilTimer = max(0, recoilTimer - dt)

        // hover bob: slow and deep at rest, quicker and shallower at speed; vibration only at speed
        let idle = 1 - speedNorm
        let hover = sin(time * (2.2 + speedNorm * 1.6)) * (0.02 + 0.03 * idle) + sin(time * 4.5) * 0.015
        let vibration = sin(time * 23) * 0.012 * speedNorm
        root.position = [x, altitude + hover + vibration, 0]

        // the knock starts from zero and rolls the vehicle the way it is pushed, so it never fights the sideways motion
        let jolt = recoilTimer > 0 ? sin((0.45 - recoilTimer) * 40) * recoilTimer * 0.35 : 0
        var wallBank: Float = 0
        if let tube, b > 0 {
            // roll toward the tube wall when flying near it, like riding the inside of a pipe
            let d = SIMD2<Float>(x, altitude - tube.centerY)
            let len = simd_length(d)
            if len > 2.0 { wallBank = atan2(d.x, -d.y) * min(1, (len - 2.0) / (tube.radius - 2.0)) * 0.45 * b }
        }
        smoothBank = -steer * 0.24 - vx * 0.02 + wallBank
        bank = smoothBank - jolt * recoilDir
        let yaw = -steer * 0.12 + sin(time * 0.7) * 0.012 * idle
        let pitch = -speedNorm * 0.035 + sin(time * 3.1) * 0.008 + jolt * 0.4 + vy * 0.045
        root.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
                         * simd_quatf(angle: pitch, axis: [1, 0, 0])
                         * simd_quatf(angle: bank, axis: [0, 0, 1])

        underGlow?.orientation = root.orientation.inverse
        underGlow?.position = root.orientation.inverse.act([0, -(altitude + hover + vibration) + 0.04, 0.2])
        underGlow?.isEnabled = !inTube
        let pulse = 1 + 0.08 * sin(time * 27) + speedNorm * 0.5
        for g in glows { g.scale = SIMD3<Float>(repeating: pulse) }
        engineLight.light.intensity = 14000 + speedNorm * 18000
        // the exhaust idles when parked instead of blasting at full rate
        let trailRate = Int((30 + speedNorm * 160) / 10)
        if trailRate != lastTrailRate, let t = trail, var e = t.components[ParticleEmitterComponent.self] {
            lastTrailRate = trailRate
            e.mainEmitter.birthRate = Float(trailRate * 10)
            e.speed = 6 + speedNorm * 18
            t.components.set(e)
        }
    }

    // MARK: - Arena

    /// Place the vehicle directly from a light cycle's state (position is the ground
    /// contact point, y = height above the deck).
    func poseArena(position: SIMD3<Float>, heading: Float, lean: Float, pitch: Float, time: Float, speedNorm: Float, airborne: Bool) {
        let hover = sin(time * 4.5) * 0.04 + sin(time * 2.3) * 0.02
        let vibration = sin(time * 23) * 0.012 * speedNorm
        root.position = position + [0, restHeight + hover + vibration, 0]
        bank = lean
        root.orientation = simd_quatf(angle: heading, axis: [0, 1, 0])
                         * simd_quatf(angle: pitch, axis: [1, 0, 0])
                         * simd_quatf(angle: lean, axis: [0, 0, 1])
        underGlow?.orientation = root.orientation.inverse
        underGlow?.position = root.orientation.inverse.act([0, -(restHeight + hover + vibration + position.y) + 0.04, 0.2])
        underGlow?.isEnabled = !airborne
        let pulse = 1 + 0.08 * sin(time * 27) + speedNorm * 0.5
        for g in glows { g.scale = SIMD3<Float>(repeating: pulse) }
        engineLight.light.intensity = 14000 + speedNorm * 18000
    }

    /// Recolour the engine halos and lights (opponent cycles).
    func tint(_ color: SIMD3<Float>, materials: SceneMaterials) {
        for (i, g) in glows.enumerated() {
            if var model = g.model { model.materials = [materials.glow(color, opacity: i == 1 ? 0.28 : 0.8)]; g.model = model }
        }
        engineLight.light.color = .rgb(color)
        underLight.light.color = .rgb(color)
        if let pool = underGlow, var model = pool.model { model.materials = [materials.glow(color, opacity: 0.22)]; pool.model = model }
        if let t = trail, var e = t.components[ParticleEmitterComponent.self] {
            e.mainEmitter.color = .evolving(start: .single(.rgb(color, 0.9)), end: .single(.rgb(color * 0.6, 0.0)))
            t.components.set(e)
        }
    }

    func setVisible(_ on: Bool) { holder.isEnabled = on; for g in glows { g.isEnabled = on }; underGlow?.isEnabled = on; trail?.isEnabled = on }
}
