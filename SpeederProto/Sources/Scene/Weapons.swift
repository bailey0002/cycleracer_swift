import Foundation
import RealityKit
import simd

/// Pooled plasma bolts fired down the corridor plus pooled explosion bursts.
@MainActor
final class WeaponSystem {
    let root = Entity()
    private struct Bolt { let entity: Entity; var alive = false; var age: Float = 0 }
    private var bolts: [Bolt] = []
    private var explosions: [(entity: Entity, light: PointLight, timer: Float)] = []
    private var cooldown: Float = 0
    private var muzzleSide: Float = 1
    private let flash = PointLight()
    private var flashTimer: Float = 0
    let boltSpeed: Float = 95
    let fireInterval: Float = 0.14

    init(materials: SceneMaterials) {
        root.name = "Weapons"
        // the photon (2 Oct 2026): a hot white core inside a cyan sheath, a head halo and a short additive
        // trail, so a shot reads at 95 m/s against the neon
        let core = materials.neon(SIMD3(1.0, 1.0, 1.0), intensity: 9)
        let sheath = materials.neon(SIMD3(0.45, 0.95, 1.0), intensity: 5)
        let halo = materials.glow(Neon.cyan, opacity: 0.8)
        for _ in 0..<16 {
            let e = Entity()
            let body = ModelEntity(mesh: .generateBox(size: [0.10, 0.10, 2.4], cornerRadius: 0.05), materials: [core])
            let shell = ModelEntity(mesh: .generateBox(size: [0.22, 0.22, 2.0], cornerRadius: 0.11), materials: [sheath])
            let g = ModelEntity(mesh: .generatePlane(width: 1.4, height: 1.4), materials: [halo])
            g.position = [0, 0, -0.9]
            g.orientation = simd_quatf(angle: 0.02, axis: [1, 0, 0])
            var p = ParticleEmitterComponent()
            p.emitterShape = .point
            p.emissionDirection = [0, 0, 1]
            p.speed = 4
            p.mainEmitter.birthRate = 220
            p.mainEmitter.lifeSpan = 0.18
            p.mainEmitter.size = 0.12
            p.mainEmitter.sizeVariation = 0.05
            p.mainEmitter.stretchFactor = 6
            p.mainEmitter.blendMode = .additive
            p.mainEmitter.opacityCurve = .linearFadeOut
            p.mainEmitter.color = .evolving(start: .single(.rgb(0.6, 1.0, 1.0, 0.9)), end: .single(.rgb(0.2, 0.5, 1.0, 0.0)))
            let trail = Entity()
            trail.components.set(p)
            trail.position = [0, 0, 1.0]
            e.addChild(body); e.addChild(shell); e.addChild(g); e.addChild(trail)
            e.isEnabled = false
            root.addChild(e)
            bolts.append(Bolt(entity: e))
        }
        flash.light.color = .rgb(Neon.cyan)
        flash.light.intensity = 40000
        flash.light.attenuationRadius = 6
        flash.isEnabled = false
        root.addChild(flash)
        for _ in 0..<3 {
            let e = Entity()
            var p = ParticleEmitterComponent()
            p.emitterShape = .sphere
            p.emitterShapeSize = [0.5, 0.5, 0.5]
            p.birthLocation = .volume
            p.birthDirection = .normal
            p.speed = 16
            p.speedVariation = 8
            p.mainEmitter.birthRate = 1600
            p.mainEmitter.lifeSpan = 0.6
            p.mainEmitter.lifeSpanVariation = 0.3
            p.mainEmitter.size = 0.14
            p.mainEmitter.sizeVariation = 0.08
            p.mainEmitter.stretchFactor = 3
            p.mainEmitter.dampingFactor = 3
            p.mainEmitter.acceleration = [0, -6, 10]
            p.mainEmitter.blendMode = .additive
            p.mainEmitter.opacityCurve = .linearFadeOut
            p.mainEmitter.color = .evolving(start: .single(.rgb(1.0, 0.9, 0.6, 1.0)), end: .single(.rgb(1.0, 0.25, 0.05, 0.0)))
            p.isEmitting = false
            e.components.set(p)
            let light = PointLight()
            light.light.color = .rgb(1.0, 0.6, 0.3)
            light.light.intensity = 90000
            light.light.attenuationRadius = 14
            light.isEnabled = false
            e.addChild(light)
            root.addChild(e)
            explosions.append((e, light, 0))
        }
    }

    /// Try to fire from the vehicle; returns true when a bolt left the muzzle.
    func fire(from vehicle: SIMD3<Float>, orientation: simd_quatf) -> Bool {
        guard cooldown <= 0, let i = bolts.firstIndex(where: { !$0.alive }) else { return false }
        cooldown = fireInterval
        muzzleSide = -muzzleSide
        let muzzle = vehicle + orientation.act([muzzleSide * 0.7, -0.1, -1.4])
        bolts[i].alive = true
        bolts[i].age = 0
        bolts[i].entity.position = muzzle
        bolts[i].entity.orientation = orientation
        bolts[i].entity.isEnabled = true
        flash.position = muzzle
        flash.isEnabled = true
        flashTimer = 0.06
        return true
    }

    /// Advance bolts; `hitTest` receives the bolt tip position and returns true when it consumed the bolt.
    func update(dt: Float, hitTest: (SIMD3<Float>) -> Bool) {
        cooldown -= dt
        if flashTimer > 0 { flashTimer -= dt; if flashTimer <= 0 { flash.isEnabled = false } }
        for i in bolts.indices where bolts[i].alive {
            bolts[i].age += dt
            let e = bolts[i].entity
            e.position += e.orientation.act([0, 0, -boltSpeed * dt])
            let tip = e.position + e.orientation.act([0, 0, -0.9])
            if bolts[i].age > 1.6 || hitTest(tip) {
                bolts[i].alive = false
                e.isEnabled = false
            }
        }
        for i in explosions.indices where explosions[i].timer > 0 {
            explosions[i].timer -= dt
            if explosions[i].timer <= 0.34 { explosions[i].light.isEnabled = false }
            if explosions[i].timer <= 0, var p = explosions[i].entity.components[ParticleEmitterComponent.self] {
                p.isEmitting = false
                explosions[i].entity.components.set(p)
            }
        }
    }

    func explode(at p: SIMD3<Float>) {
        guard let i = explosions.firstIndex(where: { $0.timer <= 0 }) ?? explosions.indices.first else { return }
        explosions[i].entity.position = p
        explosions[i].timer = 0.45
        explosions[i].light.isEnabled = true
        if var pe = explosions[i].entity.components[ParticleEmitterComponent.self] {
            pe.isEmitting = true
            explosions[i].entity.components.set(pe)
        }
    }

    func setEnabled(_ on: Bool) { root.isEnabled = on }
}
