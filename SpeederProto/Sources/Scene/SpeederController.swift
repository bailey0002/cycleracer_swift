import Foundation
import RealityKit
import Metal
import simd

/// Which vehicle the player rides. `SPEEDER_VEHICLE=board` swaps the speeder for the hoverboard
/// (KERB's board + a Character Creator rider, `RiderRig`); everything else in the game is unchanged.
enum VehicleKind: String {
    case speeder, board
    static var current: VehicleKind {
        if let k = VehicleKind(rawValue: ProcessInfo.processInfo.environment["SPEEDER_VEHICLE"] ?? "") { return k }
        return UserDefaults.standard.integer(forKey: "prefs.vehicle") == 1 ? .board : .speeder
    }
}

/// Gameplay root for the vehicle. The imported model sits in a holder that fixes
/// orientation and scale; only `root` is animated (brief §3).
@MainActor
final class SpeederController {
    let root = Entity()
    let kind: VehicleKind
    /// The hoverboard's rider (nil for the speeder).
    private(set) var rider: RiderRig?
    /// Extra chase-camera height and distance for a tall vehicle.
    var cameraLift: SIMD2<Float> = .zero
    /// The rider's handling multipliers (steer, climb, boost, hull); neutral for the speeder.
    private(set) var handling = RiderHandling.neutral
    let engineLight = PointLight()
    let underLight = PointLight()
    private let holder = Entity()
    private var glows: [ModelEntity] = []
    private var underGlow: ModelEntity?
    private var shadow: ModelEntity?
    private var rearZ: Float = 1
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
    private(set) var halfHeight: Float = 0.55
    /// When set, movement is constrained to a cylinder (centre height, radius).
    var tube: (centerY: Float, radius: Float)? = nil
    let restHeight: Float = 1.05
    let scale: Float = 2.0

    static func load(materials: SceneMaterials, kind: VehicleKind = .current) async throws -> SpeederController {
        func entity(_ name: String) async throws -> Entity {
            guard let url = Bundle.main.url(forResource: name, withExtension: "usdz") else {
                throw NSError(domain: "Speeder", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(name).usdz missing from bundle"])
            }
            return try await Entity(contentsOf: url)
        }
        switch kind {
        case .speeder:
            return SpeederController(model: try await entity("Speeder"), materials: materials)
        case .board:
            let profile = Roster.current()
            let c = SpeederController(board: try await entity("Board"), rider: try await entity(profile.asset), materials: materials)
            c.handling = profile.handling
            print("Board: rider \(profile.name) (\(profile.asset))")
            return c
        }
    }

    init(model: Entity, materials: SceneMaterials) {
        kind = .speeder
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
        self.rearZ = rearZ
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
        // contact shadow: a soft dark blob on the road that shrinks and fades with altitude
        let blob = ModelEntity(mesh: .generatePlane(width: 2.6, depth: 4.2), materials: [materials.glow(SIMD3<Float>(0, 0, 0), opacity: 0.6)])
        blob.position = [0, -restHeight + 0.03, 0.1]
        root.addChild(blob)
        shadow = blob

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

    /// The hoverboard: KERB's skateboard (nose toward -Z, deck top at the holder's y = 0) with the rider
    /// standing on it, edge light strips, a tail thruster and a tight hover pool. The deck floats
    /// `deckDrop` below the gameplay root so the rider's head stays inside the road's clearance.
    init(board: Entity, rider riderModel: Entity, materials: SceneMaterials) {
        kind = .board
        root.name = "SpeederRoot"
        board.name = "ImportedBoard"
        let deckDrop: Float = 0.35
        let boardLength: Float = 1.7
        let big: Float = 1.35                 // the board and rider are scaled up so they read on a phone
        let bounds = board.visualBounds(relativeTo: nil)
        let ext = bounds.extents
        if ext.x > ext.z { board.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0]) }
        let fit = boardLength / max(0.01, max(ext.x, ext.z))
        board.scale = SIMD3<Float>(repeating: fit)
        // KERB's board is one mesh with material subsets (steel, aluminium, bearing_shield, bushing, maple_ply,
        // griptape, deck_graphic, riser, urethane): a hoverboard has no wheels, so the urethane and bearing
        // parts go invisible and the aluminium trucks become the glowing hover pods.
        func walk(_ e: Entity) {
            if let m = e as? ModelEntity, var model = m.model, model.materials.count >= 9 {
                var clear = UnlitMaterial(color: .black)
                clear.blending = .transparent(opacity: .init(floatLiteral: 0))
                var pod = PhysicallyBasedMaterial()
                pod.baseColor = .init(tint: .init(red: 0.1, green: 0.2, blue: 0.25, alpha: 1))
                pod.emissiveColor = .init(color: .init(red: 0.2, green: 1.0, blue: 1.0, alpha: 1))
                pod.emissiveIntensity = 3
                pod.roughness = 0.4
                model.materials[2] = clear
                model.materials[8] = clear
                model.materials[1] = pod
                m.model = model
                print("Board: \(model.materials.count) material slots, wheels hidden")
            }
            for c in e.children { walk(c) }
        }
        walk(board)
        let deck = Entity(); deck.name = "Deck"
        deck.addChild(board)
        let b2 = deck.visualBounds(relativeTo: deck)
        board.position = [-b2.center.x, -b2.max.y, -b2.center.z]         // deck top at y = 0, centred
        holder.addChild(deck)
        holder.position = [0, -deckDrop, 0]
        holder.scale = SIMD3<Float>(repeating: big)
        root.addChild(holder)
        root.position = [0, restHeight, 0]
        halfHeight = 1.1
        cameraLift = [0.9, 1.9]
        rearZ = boardLength * 0.5 * big
        let deckWidth = b2.extents.x * big, deckThickness = b2.extents.y * big

        if let rig = RiderRig(entity: riderModel) {
            let target: Float = 1.75
            if rig.height > 0.5 { rig.root.scale = SIMD3<Float>(repeating: target / rig.height) }
            deck.addChild(rig.root)
            rider = rig
            rig.pose(bank: 0, speedNorm: 0, boost: 0, climb: 0, time: 0, dt: 1)
            rig.apply(dt: 1, rate: 1000)
        } else {
            print("Board: rider rig missing, riding empty")
        }
        print("Board: extents \(ext) fit \(fit) deck \(deckWidth) x \(deckThickness) rider \(rider?.height ?? 0)")

        // edge light strips along both rails, a nose tip and the tail thruster
        let strip: Float = 0.10
        for sx: Float in [-1, 1] {
            let q = ModelEntity(mesh: .generatePlane(width: strip, depth: boardLength * big * 0.9), materials: [materials.glow(Neon.cyan, opacity: 0.9)])
            q.position = [sx * (deckWidth * 0.5 - 0.01), -deckDrop - deckThickness * 0.5, 0]
            q.orientation = simd_quatf(angle: 0.02, axis: [0, 0, 1])
            root.addChild(q); glows.append(q)
        }
        for (offset, color, size, alpha) in [
            (SIMD3<Float>(0, -deckDrop - 0.05, rearZ * 1.02), Neon.cyan, Float(0.55), Float(0.95)),      // tail thruster core
            (SIMD3<Float>(0, -deckDrop - 0.05, rearZ * 1.08), Neon.magenta, Float(1.3), Float(0.28)),    // halo
            (SIMD3<Float>(0, -deckDrop - 0.16, -rearZ * 0.55), Neon.cyan, Float(0.35), Float(0.6)),     // front hover pod
            (SIMD3<Float>(0, -deckDrop - 0.16, rearZ * 0.55), Neon.cyan, Float(0.35), Float(0.6)),      // rear hover pod
        ] {
            let q = ModelEntity(mesh: .generatePlane(width: size, height: size), materials: [materials.glow(color, opacity: alpha)])
            q.position = offset
            root.addChild(q)
            glows.append(q)
        }
        let pool = ModelEntity(mesh: .generatePlane(width: 1.6, depth: 2.6), materials: [materials.glow(Neon.magenta, opacity: 0.26)])
        pool.position = [0, -restHeight + 0.04, 0]
        root.addChild(pool)
        underGlow = pool
        let blob = ModelEntity(mesh: .generatePlane(width: 1.3, depth: 2.4), materials: [materials.glow(SIMD3<Float>(0, 0, 0), opacity: 0.6)])
        blob.position = [0, -restHeight + 0.03, 0]
        root.addChild(blob)
        shadow = blob

        engineLight.light.color = .rgb(Neon.cyan)
        engineLight.light.intensity = 12000
        engineLight.light.attenuationRadius = 7
        engineLight.position = [0, -deckDrop + 0.1, rearZ * 1.1]
        root.addChild(engineLight)
        underLight.light.color = .rgb(Neon.magenta)
        underLight.light.intensity = 12000
        underLight.light.attenuationRadius = 6
        underLight.position = [0, -deckDrop - 0.3, 0]
        root.addChild(underLight)

        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .box
        emitter.emitterShapeSize = [0.5, 0.12, 0.15]
        emitter.birthLocation = .volume
        emitter.emissionDirection = [0, 0, 1]
        emitter.speed = 18
        emitter.speedVariation = 5
        emitter.mainEmitter.birthRate = 120
        emitter.mainEmitter.lifeSpan = 0.2
        emitter.mainEmitter.lifeSpanVariation = 0.08
        emitter.mainEmitter.size = 0.07
        emitter.mainEmitter.sizeVariation = 0.04
        emitter.mainEmitter.stretchFactor = 5
        emitter.mainEmitter.blendMode = .additive
        emitter.mainEmitter.opacityCurve = .quickFadeInOut
        emitter.mainEmitter.color = .evolving(start: .single(.rgb(Neon.cyan, 0.9)), end: .single(.rgb(Neon.magenta, 0.0)))
        let t = Entity()
        t.components.set(emitter)
        t.position = [0, -deckDrop - 0.04, rearZ * 0.98]
        root.addChild(t)
        trail = t
    }

    // MARK: - Tricks (hoverboard)

    enum Trick { case spin, roll }
    private var trick: Trick? = nil
    private var trickTime: Float = 0
    private let trickDuration: Float = 0.85
    /// 0 ... 1 through the current trick (0 when none).
    var trickProgress: Float { trick == nil ? 0 : min(1, trickTime / trickDuration) }

    /// Start a 360 spin or a barrel roll; nil when one is already running or the vehicle is not a board.
    func startTrick(_ t: Trick) -> String? {
        guard kind == .board, trick == nil else { return nil }
        trick = t; trickTime = 0
        return t == .spin ? "360" : "BARREL ROLL"
    }

    /// Extra orientation and hop from the running trick; advances it by `dt`.
    private func trickTransform(dt: Float) -> (rotation: simd_quatf, hop: Float, air: Float) {
        guard let t = trick else { return (simd_quatf(angle: 0, axis: [0, 1, 0]), 0, 0) }
        trickTime += dt
        let p = min(1, trickTime / trickDuration)
        let e = p * p * (3 - 2 * p)                      // smoothstep: launches and lands soft
        let angle = e * 2 * .pi
        let air = sin(p * .pi)
        if p >= 1 { trick = nil }
        let rot = t == .spin ? simd_quatf(angle: angle, axis: [0, 1, 0]) : simd_quatf(angle: angle, axis: [0, 0, 1])
        return (rot, air * (t == .spin ? 0.9 : 1.2), air)
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

    /// World position of the main nozzle (for the post pass's heat haze).
    var thrusterWorldPosition: SIMD3<Float> { root.convert(position: [0.02, 0.15, rearZ * 1.0], to: nil) }

    /// Shadow and ground glow on the road plane under the vehicle: the glow grows with throttle, the
    /// shadow shrinks and fades as the vehicle climbs (contact reads on a phone screen).
    private func placeGround(height: Float, inverse: simd_quatf, throttle: Float, hidden: Bool) {
        let above = max(0, height - restHeight)
        let lift = 1 / (1 + above * 0.45)
        underGlow?.orientation = inverse
        underGlow?.position = inverse.act([0, -height + 0.04, 0.2])
        underGlow?.scale = SIMD3<Float>(repeating: 0.85 + throttle * 0.55) * (0.7 + 0.3 * lift)
        underGlow?.isEnabled = !hidden
        shadow?.orientation = inverse
        shadow?.position = inverse.act([0, -height + 0.03, 0.1])
        shadow?.scale = SIMD3<Float>(repeating: lift)
        shadow?.isEnabled = !hidden
    }

    func update(dt: Float, time: Float, steerInput: Float, climbInput: Float, speedNorm: Float, roadShift: Float, boost: Float = 0) {
        steer = damp(steer, steerInput, 8.0, dt)
        // velocity-based steering; curves tug the vehicle toward the outside
        let steerSpeed: Float = (7.5 + 7.0 * speedNorm) * handling.steer
        var newX = x + steer * steerSpeed * dt - roadShift * 0.6
        if recoilTimer > 0 { newX += recoilDir * 6.0 * dt * (recoilTimer / 0.45) }
        // altitude: stick drives vertical speed, settles back toward hover height when released
        let climbSpeed: Float = 6.5 * handling.climb
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
        let trickFX = trickTransform(dt: dt)
        root.position = [x, altitude + hover + vibration + trickFX.hop, 0]

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
                         * trickFX.rotation

        placeGround(height: altitude + hover + vibration + trickFX.hop, inverse: root.orientation.inverse, throttle: speedNorm + boost * 0.6, hidden: inTube)
        rider?.pose(bank: bank, speedNorm: speedNorm, boost: boost, climb: vy, time: time, dt: dt, tuck: trickFX.air)
        let pulse = 1 + 0.08 * sin(time * 27) + speedNorm * 0.5 + boost * 0.55
        for g in glows { g.scale = SIMD3<Float>(repeating: pulse) }
        engineLight.light.intensity = 14000 + speedNorm * 18000 + boost * 14000
        // the exhaust idles when parked instead of blasting at full rate; boost stretches it
        let trailRate = Int((30 + speedNorm * 160 + boost * 80) / 10)
        if trailRate != lastTrailRate, let t = trail, var e = t.components[ParticleEmitterComponent.self] {
            lastTrailRate = trailRate
            e.mainEmitter.birthRate = Float(trailRate * 10)
            e.speed = 6 + speedNorm * 18 + boost * 16
            e.mainEmitter.lifeSpan = Double(0.22 + boost * 0.16)
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
        placeGround(height: restHeight + hover + vibration + position.y, inverse: root.orientation.inverse, throttle: speedNorm, hidden: airborne)
        rider?.pose(bank: lean, speedNorm: speedNorm, boost: 0, climb: 0, time: time, dt: 1 / 60)
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

    func setVisible(_ on: Bool) {
        if on { endDissolve() }
        holder.isEnabled = on; for g in glows { g.isEnabled = on }; underGlow?.isEnabled = on; shadow?.isEnabled = on; trail?.isEnabled = on
    }

    // MARK: - Derez dissolve

    private var dissolveOriginals: [(ModelEntity, [any Material])] = []
    private var dissolveMaterials: [(ModelEntity, [CustomMaterial?])] = []

    /// Swap the model's materials for the dissolve shader (keeps each material's base colour texture
    /// and tint). `color` is the hot rim. No-op when the Metal library is missing.
    func beginDissolve(color: SIMD3<Float>, library: MTLLibrary?) {
        guard dissolveOriginals.isEmpty, let library else { return }
        let shader = CustomMaterial.SurfaceShader(named: "dissolveSurface", in: library)
        var models: [ModelEntity] = []
        func walk(_ e: Entity) { if let m = e as? ModelEntity { models.append(m) }; for c in e.children { walk(c) } }
        walk(holder)
        for m in models {
            guard let model = m.model else { continue }
            dissolveOriginals.append((m, model.materials))
            var custom: [CustomMaterial?] = []
            var replaced: [any Material] = []
            for mat in model.materials {
                if let pbm = mat as? PhysicallyBasedMaterial, var cm = try? CustomMaterial(from: pbm, surfaceShader: shader) {
                    cm.custom.value = SIMD4<Float>(0, color.x, color.y, color.z)
                    cm.opacityThreshold = 0.5
                    custom.append(cm); replaced.append(cm)
                } else {
                    custom.append(nil); replaced.append(mat)
                }
            }
            var mm = model; mm.materials = replaced; m.model = mm
            dissolveMaterials.append((m, custom))
        }
        for g in glows { g.isEnabled = false }
        trail?.isEnabled = false
    }

    /// Advance the burn: 0 whole, 1 gone. Materials are values, so they are re-assigned each call.
    func updateDissolve(progress: Float) {
        guard !dissolveMaterials.isEmpty else { return }
        for (m, mats) in dissolveMaterials {
            guard var model = m.model else { continue }
            var out = model.materials
            for (i, cm) in mats.enumerated() {
                guard var c = cm else { continue }
                var v = c.custom.value; v.x = progress; c.custom.value = v
                out[i] = c
            }
            model.materials = out
            m.model = model
        }
    }

    func endDissolve() {
        guard !dissolveOriginals.isEmpty else { return }
        for (m, mats) in dissolveOriginals { if var model = m.model { model.materials = mats; m.model = model } }
        dissolveOriginals.removeAll(); dissolveMaterials.removeAll()
    }
}
