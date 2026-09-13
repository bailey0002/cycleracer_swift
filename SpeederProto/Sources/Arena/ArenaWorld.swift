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
    let terrain: ArenaTerrain
    private var pylonTops: [ModelEntity] = []
    let pickupGroup = Entity()
    private(set) var pickupEntities: [Entity] = []
    /// Floor pads: boost pads (cyan-white chevrons) surge the cycle, slow pads (red) cut its speed.
    struct Pad { let pos: SIMD2<Float>; let boost: Bool; let entity: Entity }
    private(set) var pads: [Pad] = []
    static let padRadius: Float = 4.2
    /// Orange locator column over the rival so it can be found across the arena.
    let rivalBeam: ModelEntity

    init(materials: SceneMaterials, halfSize: Float) {
        self.halfSize = halfSize
        terrain = ArenaTerrain.garage(halfSize: halfSize)
        root.name = "Arena"
        rivalBeam = ModelEntity(mesh: .generateBox(size: [0.22, 34, 0.22]), materials: [materials.glow(ArenaController.opponentColor, opacity: 0.32)])
        rivalBeam.isEnabled = false
        root.addChild(rivalBeam)
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
        buildDecks(materials: materials)
        buildPads(materials: materials)
        root.addChild(pickupGroup)
    }

    /// Six pads on open ground (clear of the deck, ramps and hazard walls): four boost, two slow.
    private func buildPads(materials: SceneMaterials) {
        let layout: [(SIMD2<Float>, Bool)] = [([0, 62], true), ([-82, 10], true), ([82, 10], true), ([0, -100], true), ([-40, 85], false), ([40, 85], false)]
        let boostColor = SIMD3<Float>(0.6, 0.95, 1.0), slowColor = SIMD3<Float>(1.0, 0.2, 0.25)
        for (pos, boost) in layout {
            let color = boost ? boostColor : slowColor
            let e = Entity()
            let y = terrain.height(at: pos)
            e.position = [pos.x, y, pos.y]
            let r = Self.padRadius
            // pool + frame, tilted a hair so RealityKit never culls the flat quad
            let pool = ModelEntity(mesh: .generatePlane(width: r * 2, depth: r * 2), materials: [materials.glow(color, opacity: 0.6)])
            pool.position.y = 0.03
            pool.orientation = simd_quatf(angle: 0.01, axis: [1, 0, 0])
            e.addChild(pool)
            let frameMat = materials.neon(color, intensity: 5)
            for (dx, dz, sx, sz) in [(-r, 0, 0.25, r * 2), (r, 0, 0.25, r * 2), (0, -r, r * 2, 0.25), (0, r, r * 2, 0.25)] as [(Float, Float, Float, Float)] {
                let bar = ModelEntity(mesh: .generateBox(size: [sx, 0.12, sz]), materials: [frameMat])
                bar.position = [dx, 0.06, dz]
                e.addChild(bar)
            }
            // corner posts so the pad reads from the chase camera before it is underfoot
            for (dx, dz) in [(-r, -r), (r, -r), (-r, r), (r, r)] as [(Float, Float)] {
                let post = ModelEntity(mesh: .generateBox(size: [0.2, 1.6, 0.2]), materials: [frameMat])
                post.position = [dx, 0.8, dz]
                e.addChild(post)
            }
            // chevrons: boost pads point every way (any approach works), slow pads carry an X
            let mark = materials.neon(color, intensity: 5)
            if boost {
                for k in 0..<3 {
                    let z = -r * 0.55 + Float(k) * r * 0.55
                    for side in [-1, 1] as [Float] {
                        let bar = ModelEntity(mesh: .generateBox(size: [r * 0.7, 0.1, 0.3]), materials: [mark])
                        bar.position = [side * r * 0.3, 0.07, z]
                        bar.orientation = simd_quatf(angle: side * 0.6, axis: [0, 1, 0])
                        e.addChild(bar)
                    }
                }
            } else {
                for a in [Float.pi / 4, -Float.pi / 4] {
                    let bar = ModelEntity(mesh: .generateBox(size: [r * 1.4, 0.1, 0.35]), materials: [mark])
                    bar.position.y = 0.07
                    bar.orientation = simd_quatf(angle: a, axis: [0, 1, 0])
                    e.addChild(bar)
                }
            }
            root.addChild(e)
            pads.append(Pad(pos: pos, boost: boost, entity: e))
        }
    }

    /// Parking-garage levels: deck floors with a dark slab underneath and an edge strip, inclined
    /// ramps in the same grid material, and columns. Rails are drawn by the hazard trail renderer.
    private func buildDecks(materials: SceneMaterials) {
        let bandMat = materials.neon(SIMD3(0.30, 0.80, 1.0), intensity: 3.5)
        // decks and ramps read as lighter steel slabs with a coarser grid so they separate from the ground
        var deckMat = materials.gridFloor ?? materials.road
        deckMat.baseColor = .init(tint: .rgb(0.42, 0.50, 0.60), texture: deckMat.baseColor.texture)
        deckMat.emissiveIntensity = 1.6
        deckMat.roughness = .init(floatLiteral: 0.35)
        var slabMat = PhysicallyBasedMaterial()
        slabMat.baseColor = .init(tint: .rgb(0.16, 0.20, 0.26))
        slabMat.roughness = .init(floatLiteral: 0.6)
        slabMat.metallic = .init(floatLiteral: 0.3)
        let thick: Float = 1.2
        for d in terrain.decks {
            let w = d.max.x - d.min.x, l = d.max.y - d.min.y
            let c = (d.min + d.max) / 2
            var top = deckMat
            top.textureCoordinateTransform = .init(offset: .zero, scale: SIMD2(w / 32, l / 32), rotation: 0)
            let floor = ModelEntity(mesh: .generatePlane(width: w, depth: l), materials: [top])
            floor.position = [c.x, d.height + 0.01, c.y]
            root.addChild(floor)
            let slab = ModelEntity(mesh: .generateBox(size: [w, thick, l]), materials: [slabMat])
            slab.position = [c.x, d.height - thick / 2, c.y]
            root.addChild(slab)
            // bright band around the slab face
            for (sx, sz, ex, ez) in [(0, -1, w, 0.2), (0, 1, w, 0.2), (-1, 0, 0.2, l), (1, 0, 0.2, l)] as [(Float, Float, Float, Float)] {
                let e = ModelEntity(mesh: .generateBox(size: [ex + 0.2, 0.45, ez + 0.2]), materials: [bandMat])
                e.position = [c.x + sx * w / 2, d.height - 0.35, c.y + sz * l / 2]
                root.addChild(e)
            }
            // ceiling lights under the deck
            let lampMat = materials.neon(SIMD3(0.7, 0.9, 1.0), intensity: 2.2)
            for k in stride(from: d.min.y + 10, to: d.max.y, by: 20) {
                let lamp = ModelEntity(mesh: .generateBox(size: [w * 0.9, 0.12, 0.3]), materials: [lampMat])
                lamp.position = [c.x, d.height - thick - 0.1, k]
                root.addChild(lamp)
            }
        }
        for r in terrain.ramps {
            let w = r.xMax - r.xMin
            let run = r.length
            let hyp = sqrt(run * run + r.rise * r.rise)
            var top = deckMat
            top.textureCoordinateTransform = .init(offset: .zero, scale: SIMD2(w / 32, hyp / 32), rotation: 0)
            let holder = Entity()
            let cz = (r.z0 + r.z1) / 2
            holder.position = [(r.xMin + r.xMax) / 2, (r.h0 + r.h1) / 2, cz]
            // the surface rises toward the end with the greater height; rotate about X accordingly
            let angle = atan2(r.h1 - r.h0, r.z1 - r.z0)
            holder.orientation = simd_quatf(angle: -angle, axis: [1, 0, 0])
            let surface = ModelEntity(mesh: .generatePlane(width: w, depth: hyp), materials: [top])
            surface.position = [0, 0.01, 0]
            holder.addChild(surface)
            let slab = ModelEntity(mesh: .generateBox(size: [w, thick, hyp]), materials: [slabMat])
            slab.position = [0, -thick / 2, 0]
            holder.addChild(slab)
            for x in [-w / 2, w / 2] {
                let e = ModelEntity(mesh: .generateBox(size: [0.2, 0.45, hyp]), materials: [bandMat])
                e.position = [x, -0.35, 0]
                holder.addChild(e)
            }
            root.addChild(holder)
        }
        for (p, h) in terrain.columns {
            let col = ModelEntity(mesh: .generateBox(size: [1.6, h, 1.6]), materials: [slabMat])
            col.position = [p.x, h / 2, p.y]
            root.addChild(col)
        }
    }

    func apply(_ s: FXSettings) {
        for r in reflections { r.isEnabled = s.reflections }
        towerGroup.isEnabled = s.buildings
    }

    func animate(time: Float) {
        for (i, t) in pylonTops.enumerated() { t.scale = SIMD3(repeating: 1 + 0.15 * sin(time * 3 + Float(i))) }
        for (i, p) in pads.enumerated() { p.entity.children[0].scale = SIMD3(repeating: 1 + 0.06 * sin(time * 4 + Float(i) * 1.3)) }
    }

    /// Place the rival's locator beam (hidden when the rival is close enough to see anyway).
    func placeRivalBeam(at p: SIMD3<Float>, visible: Bool) {
        rivalBeam.isEnabled = visible
        rivalBeam.position = [p.x, p.y + 17, p.z]
    }
}
