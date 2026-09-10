import Foundation
import RealityKit
import simd

/// The Grid: a square arena with a glossy grid floor, tall luminous boundary panels,
/// corner pylons, a far ring of data towers, a few lime hazard walls and pickup props.
/// Static; the cycles move through it.
@MainActor
final class ArenaWorld {
    let root = Entity()
    let halfSize: Float
    let wallHeight: Float = 11
    private var reflections: [Entity] = []
    private let towerGroup = Entity()
    private(set) var hazardWalls: [(a: SIMD2<Float>, b: SIMD2<Float>)] = []
    private var pylonTops: [ModelEntity] = []
    let pickupGroup = Entity()
    private(set) var pickupEntities: [Entity] = []

    init(materials: SceneMaterials, halfSize: Float) {
        self.halfSize = halfSize
        root.name = "Arena"
        let size = halfSize * 2
        // floor
        var floorMat = materials.gridFloor ?? materials.road
        let floorExtent = size + 120
        floorMat.textureCoordinateTransform = .init(offset: .zero, scale: SIMD2(floorExtent / 16, floorExtent / 16), rotation: 0)
        let floor = ModelEntity(mesh: .generatePlane(width: floorExtent, depth: floorExtent), materials: [floorMat])
        floor.position = [0, 0, 0]
        root.addChild(floor)

        // boundary walls: one slab per side, panelled by the texture, with a rail and base line
        let railMat = materials.neon(SIMD3(0.35, 0.85, 1.0), intensity: 4)
        let baseMat = materials.neon(SIMD3(0.20, 0.75, 1.0), intensity: 3)
        for side in 0..<4 {
            let holder = Entity()
            holder.orientation = simd_quatf(angle: Float(side) * .pi / 2, axis: [0, 1, 0])
            var wallMat = materials.gridWall ?? materials.barrier
            wallMat.textureCoordinateTransform = .init(offset: .zero, scale: SIMD2(size / 6, 1), rotation: 0)
            let slab = ModelEntity(mesh: .generateBox(width: size + 2, height: wallHeight, depth: 1.0), materials: [wallMat])
            slab.position = [0, wallHeight / 2, -halfSize - 0.5]
            holder.addChild(slab)
            let rail = ModelEntity(mesh: .generateBox(size: [size + 2, 0.18, 1.1]), materials: [railMat])
            rail.position = [0, wallHeight + 0.09, -halfSize - 0.5]
            holder.addChild(rail)
            let base = ModelEntity(mesh: .generateBox(size: [size + 2, 0.08, 0.14]), materials: [baseMat])
            base.position = [0, 0.04, -halfSize + 0.07]
            holder.addChild(base)
            let refl = ModelEntity(mesh: .generatePlane(width: size, depth: 7), materials: [materials.reflection(SIMD3(0.25, 0.8, 1.0), opacity: 0.30)])
            refl.position = [0, 0.02, -halfSize + 3.6]
            refl.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
            holder.addChild(refl)
            reflections.append(refl)
            root.addChild(holder)
        }
        // corner pylons
        let pylonMat = materials.neon(SIMD3(0.45, 0.9, 1.0), intensity: 3.5)
        for sx in [-1, 1] as [Float] { for sz in [-1, 1] as [Float] {
            let p = ModelEntity(mesh: .generateBox(size: [2.4, 26, 2.4]), materials: [materials.barrier])
            p.position = [sx * (halfSize + 1.2), 13, sz * (halfSize + 1.2)]
            root.addChild(p)
            let strip = ModelEntity(mesh: .generateBox(size: [0.3, 26, 0.3]), materials: [pylonMat])
            strip.position = [sx * (halfSize - 0.1), 13, sz * (halfSize - 0.1)]
            root.addChild(strip)
            let top = ModelEntity(mesh: .generateBox(size: [3.0, 0.6, 3.0]), materials: [pylonMat])
            top.position = [sx * (halfSize + 1.2), 26.3, sz * (halfSize + 1.2)]
            root.addChild(top)
            pylonTops.append(top)
        } }
        // far data towers: dark slabs with one lit edge, well outside the fog range so they read as silhouettes
        var rng = SeededRNG(seed: 7771)
        let edgeMat = materials.neon(SIMD3(0.2, 0.6, 1.0), intensity: 2.5)
        for i in 0..<28 {
            let a = Float(i) / 28 * 2 * .pi + rng.float(-0.08, 0.08)
            let r = halfSize + rng.float(120, 320)
            let w = rng.float(14, 40), h = rng.float(40, 190)
            let t = ModelEntity(mesh: .generateBox(width: w, height: h, depth: w), materials: [materials.barrier])
            t.position = [cos(a) * r, h / 2, sin(a) * r]
            t.orientation = simd_quatf(angle: rng.float(0, .pi), axis: [0, 1, 0])
            towerGroup.addChild(t)
            let e = ModelEntity(mesh: .generateBox(size: [0.8, h, 0.8]), materials: [edgeMat])
            e.position = [w / 2, 0, w / 2]
            t.addChild(e)
        }
        root.addChild(towerGroup)
        // hazard walls (lime): static obstacles in the field, registered with the trail system by the controller
        let q = halfSize * 0.42
        hazardWalls = [
            (SIMD2(-q, -q * 0.3), SIMD2(-q, q * 0.3)),
            (SIMD2(q, -q * 0.3), SIMD2(q, q * 0.3)),
            (SIMD2(-q * 0.3, q), SIMD2(q * 0.3, q)),
            (SIMD2(-q * 0.3, -q), SIMD2(q * 0.3, -q)),
        ]
        root.addChild(pickupGroup)
    }

    func apply(_ s: FXSettings) {
        for r in reflections { r.isEnabled = s.reflections }
        towerGroup.isEnabled = s.buildings
    }

    func animate(time: Float) {
        for (i, t) in pylonTops.enumerated() { t.scale = SIMD3(repeating: 1 + 0.15 * sin(time * 3 + Float(i))) }
    }
}
