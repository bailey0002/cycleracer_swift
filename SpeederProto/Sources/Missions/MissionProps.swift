import Foundation
import RealityKit
import simd

/// Beacon rings for search missions. They live in the world anchor and are re-positioned
/// every frame from their track distance, so they follow the road's curves.
@MainActor
final class BeaconLayer {
    let root = Entity()
    private struct Beacon { let entity: Entity; let distance: Float; let lane: Float; let y: Float; var passed = false }
    private var beacons: [Beacon] = []
    private(set) var hit = 0
    private(set) var missed = 0

    init(materials: SceneMaterials, count: Int, trackLength: Float, seed: UInt64) {
        root.name = "Beacons"
        var rng = SeededRNG(seed: seed)
        // NOTE: zero-thickness meshes (flat rings, planes) on an entity that moves every frame are
        // culled by RealityKit and never draw; the ring is a short cylinder band and the flat quads
        // carry a tiny tilt so their bounds have volume.
        let bandMesh = try? Meshes.tube(radius: 1.7, length: 0.35, segments: 40, uRepeat: 1, vRepeat: 1)
        var core = materials.neon(ArenaController.pickupColor, intensity: 4)
        core.faceCulling = .none
        var inner = materials.neon(SIMD3(1.0, 0.95, 1.0), intensity: 3)
        inner.faceCulling = .none
        let lanes: [Float] = [-5.7, -1.9, 1.9, 5.7]
        let first: Float = 350
        let spacing = max(200, (trackLength - 600 - first) / Float(max(1, count - 1)))
        for i in 0..<count {
            let e = Entity()
            if let bandMesh {
                let band = ModelEntity(mesh: bandMesh, materials: [core])
                band.position.z = 0.17
                e.addChild(band)
                let band2 = ModelEntity(mesh: bandMesh, materials: [inner])
                band2.scale = [0.86, 0.86, 0.5]
                band2.position.z = 0.09
                e.addChild(band2)
            }
            let halo = ModelEntity(mesh: .generatePlane(width: 5.0, height: 5.0), materials: [materials.glow(ArenaController.pickupColor, opacity: 0.4)])
            halo.orientation = simd_quatf(angle: 0.03, axis: [1, 0, 0])
            e.addChild(halo)
            let y: Float = rng.chance(0.4) ? 3.7 : 1.05
            let lane = rng.pick(lanes)
            let pool = ModelEntity(mesh: .generatePlane(width: 3.5, depth: 6), materials: [materials.reflection(ArenaController.pickupColor, opacity: 0.35)])
            pool.position = [0, -y + 0.03, 1.5]
            pool.orientation = simd_quatf(angle: 0.01, axis: [1, 0, 0])
            e.addChild(pool)
            e.position = [0, -50, 500]
            root.addChild(e)
            beacons.append(Beacon(entity: e, distance: first + Float(i) * spacing, lane: lane, y: y))
        }
    }

    var nearestWorldPosition: SIMD3<Float> { beacons.first(where: { !$0.passed })?.entity.position(relativeTo: nil) ?? .zero }

    /// Nearest beacon ahead, for logging.
    var debugNearest: String {
        guard let b = beacons.first(where: { !$0.passed }) else { return "none" }
        let wp = b.entity.position(relativeTo: nil)
        let ring = b.entity.children[0]
        return "D=\(Int(b.distance)) world=\(wp) ringModel=\(ring.components[ModelComponent.self] != nil) ringActive=\(ring.isActive) rootPos=\(root.position(relativeTo: nil)) parent=\(root.parent?.name ?? "nil")"
    }

    /// Returns the number of rings flown through this frame.
    func update(distance: Float, roadX: (Float) -> Float, playerX: Float, playerY: Float, time: Float) -> Int {
        var hits = 0
        for i in beacons.indices where !beacons[i].passed {
            let z = -(beacons[i].distance - distance)
            let b = beacons[i]
            if z > 6 || z < -700 { b.entity.isEnabled = false; continue }
            b.entity.isEnabled = true
            b.entity.position = [roadX(z) + b.lane, b.y, z]
            b.entity.children[0].orientation = simd_quatf(angle: time * 1.5, axis: [0, 0, 1])
            if z >= 0 {
                beacons[i].passed = true
                if abs(b.entity.position.x - playerX) < 2.3 && abs(b.y - playerY) < 1.8 {
                    hits += 1; hit += 1
                    b.entity.isEnabled = false
                } else {
                    missed += 1
                }
            }
        }
        return hits
    }
}

/// The pursuer on an escape run: a dark craft with red lights that sits behind the
/// vehicle at the current gap, closer and angrier as the gap shrinks.
@MainActor
final class PursuerActor {
    let root = Entity()
    private let light = PointLight()
    private let spot = SpotLight()
    private let eye: ModelEntity

    init(materials: SceneMaterials) {
        root.name = "Pursuer"
        let body = ModelEntity(mesh: .generateBox(size: [2.6, 0.7, 3.4], cornerRadius: 0.2), materials: [materials.barrier])
        root.addChild(body)
        let fin = ModelEntity(mesh: .generateBox(size: [0.3, 1.2, 1.6]), materials: [materials.barrier])
        fin.position = [0, 0.8, 0.8]
        root.addChild(fin)
        let red = materials.neon(Neon.red, intensity: 6)
        eye = ModelEntity(mesh: .generateBox(size: [1.8, 0.16, 0.2]), materials: [red])
        eye.position = [0, 0.1, -1.75]
        root.addChild(eye)
        for x in [-1.1, 1.1] as [Float] {
            let g = ModelEntity(mesh: .generatePlane(width: 1.6, height: 1.6), materials: [materials.glow(Neon.red, opacity: 0.7)])
            g.position = [x, 0, 1.7]
            root.addChild(g)
        }
        light.light.color = .rgb(Neon.red)
        light.light.intensity = 30000
        light.light.attenuationRadius = 14
        light.position = [0, 0.5, -1]
        root.addChild(light)
        // searchlight down the road ahead of the player: the cue that it is behind you
        spot.light.color = .rgb(1.0, 0.25, 0.2)
        spot.light.intensity = 60000
        spot.light.innerAngleInDegrees = 12
        spot.light.outerAngleInDegrees = 22
        spot.light.attenuationRadius = 90
        spot.position = [0, 0.3, -1.6]
        spot.look(at: [-3, -1.2, -40], from: spot.position, relativeTo: nil)
        root.addChild(spot)
        root.isEnabled = false
    }

    /// Far away it is only a red glow on the road behind you; under ~25 m it pulls alongside
    /// on the right, and at the catch distance it is level with the cockpit.
    func update(gap: Float, playerX: Float, time: Float) {
        root.isEnabled = true
        // the chase camera sits 5.8 m behind the bike, so the craft only reads once it is level
        // with the bike: it slides up alongside from about 18 m and sits at the cockpit at the catch
        let close = clamp01(1 - gap / 30)
        let z = max(-2.5, (gap - 18) * 0.5)
        let side: Float = 3.6 + (1 - close) * 1.5
        root.position = [playerX * 0.5 + side, 1.7 + sin(time * 1.3) * 0.15, z]
        root.orientation = simd_quatf(angle: -0.15 - sin(time * 0.9) * 0.05, axis: [0, 0, 1])
        light.light.intensity = 25000 + close * 90000 * (Int(time * 8) % 2 == 0 ? 1 : 0.5)
        light.light.attenuationRadius = 14 + close * 16
        eye.scale = SIMD3<Float>(repeating: 1 + close * 0.6)
        spot.light.intensity = 40000 + close * 120000
    }

    func hide() { root.isEnabled = false }
}
