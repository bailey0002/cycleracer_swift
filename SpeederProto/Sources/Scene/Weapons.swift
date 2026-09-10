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
    let boltSpeed: Float = 95
    let fireInterval: Float = 0.14

    init(materials: SceneMaterials) {
        root.name = "Weapons"
        let core = materials.neon(SIMD3(0.75, 1.0, 1.0), intensity: 6)
        let halo = materials.glow(Neon.cyan, opacity: 0.55)
        for _ in 0..<16 {
            let e = Entity()
            let body = ModelEntity(mesh: .generateBox(size: [0.14, 0.14, 1.8], cornerRadius: 0.06), materials: [core])
            let g = ModelEntity(mesh: .generatePlane(width: 0.9, height: 0.9), materials: [halo])
            g.position = [0, 0, 0.6]
            e.addChild(body); e.addChild(g)
            e.isEnabled = false
            root.addChild(e)
            bolts.append(Bolt(entity: e))
        }
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
        return true
    }

    /// Advance bolts; `hitTest` receives the bolt tip position and returns true when it consumed the bolt.
    func update(dt: Float, hitTest: (SIMD3<Float>) -> Bool) {
        cooldown -= dt
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
