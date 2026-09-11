import Foundation
import RealityKit
import simd

// MARK: - Obstacles

enum ObstacleKind { case block, gate, drone, beam, pillar, hatch }

/// A pooled obstacle living inside a segment. Collision is a simple AABB test in
/// world space performed by the controller.
final class Obstacle {
    let entity: Entity
    let kind: ObstacleKind
    let halfWidth: Float
    let halfLength: Float
    let halfHeight: Float
    let centerY: Float          // centre height relative to the entity position
    var active = false
    var destructible: Bool { kind == .drone || kind == .block }
    init(entity: Entity, kind: ObstacleKind, halfWidth: Float, halfLength: Float, halfHeight: Float, centerY: Float) {
        self.entity = entity; self.kind = kind; self.halfWidth = halfWidth; self.halfLength = halfLength
        self.halfHeight = halfHeight; self.centerY = centerY
    }
}

// MARK: - Segment

/// One recyclable 40 m slice of the corridor. All style variants (city, tunnel,
/// elevated, fork) are built once; `configure` only toggles groups and lays out
/// pooled obstacles, so nothing is allocated at speed.
@MainActor
final class RoadSegment {
    let root = Entity()
    let index: Int
    let length: Float

    // toggle groups (brief §37)
    let laneGroup = Entity()          // lane lines + studs
    let roadsideGroup = Entity()      // barriers + light posts (city/elevated)
    let buildingGroup = Entity()
    let signGroup = Entity()
    let reflectionGroup = Entity()    // fake wet reflections for roadside lights
    // style groups
    let tunnelGroup = Entity()
    let elevatedGroup = Entity()
    let forkGroup = Entity()
    let tubeGroup = Entity()
    let obstacleGroup = Entity()
    let portalGroup = Entity()        // section mouths (entry / exit frames per style)
    private var entryPortals: [SegmentStyle: Entity] = [:]
    private var exitPortals: [SegmentStyle: Entity] = [:]
    private var strobes: [Entity] = []
    private let storefrontGroup = Entity()
    private let secondRowGroup = Entity()
    private let altRowGroup = Entity()
    private var denseRings: [Entity] = []
    private var facadeEntities: [(ModelEntity, PhysicallyBasedMaterial)] = []
    private var skinGroups: [[Entity]] = [[], [], [], []]
    private var hazardTrim: [(ModelEntity, Float)] = []
    // colour roles for the palette picker: (entity, intensity or opacity)
    private var roadPrimary: [(ModelEntity, Float)] = []
    private var roadSecondary: [(ModelEntity, Float)] = []
    private var roadReflections: [(ModelEntity, Float)] = []
    private var cityNeon: [(ModelEntity, Float)] = []
    private var ringNeon: [(ModelEntity, Float)] = []
    private var ringReflections: [(ModelEntity, Float)] = []
    private var hazardNeon: [(ModelEntity, Float)] = []
    private var hazardPanels: [ModelEntity] = []
    private var hazardGlows: [(ModelEntity, Float)] = []
    private var hazardReflections: [(ModelEntity, Float)] = []
    private var hazardMarks: [Entity] = []
    private var lastPalette: (Int, Int)? = nil
    private var lastWindowsBright: Bool? = nil
    private let surface: ModelEntity
    private let wideSurface: ModelEntity

    private(set) var block = TrackBlock.city()
    var startOffset: Float = 0
    var endOffset: Float = 0
    private(set) var obstacles: [Obstacle] = []
    private var optionalProps: [Entity] = []
    private var billboards: [ModelEntity] = []
    private var drones: [Entity] = []
    private var variant = 0
    private let materials: SceneMaterials

    init(index: Int, length: Float, materials: SceneMaterials) {
        self.index = index
        self.length = length
        self.materials = materials
        root.name = "Segment\(index)"
        surface = ModelEntity(mesh: .generatePlane(width: 18, depth: length + 2), materials: [materials.road])
        surface.position = [0, 0, -length / 2]
        wideSurface = ModelEntity(mesh: .generatePlane(width: 36, depth: length + 2), materials: [materials.road])
        wideSurface.position = [0, 0, -length / 2]
        buildingGroup.addChild(storefrontGroup)
        buildingGroup.addChild(secondRowGroup)
        buildingGroup.addChild(altRowGroup)
        [surface, wideSurface, laneGroup, roadsideGroup, buildingGroup, signGroup, reflectionGroup,
         tunnelGroup, elevatedGroup, forkGroup, tubeGroup, obstacleGroup, portalGroup].forEach { root.addChild($0) }
        var rng = SeededRNG(seed: UInt64(1000 + index * 7919))
        buildLanes()
        buildBarriers()
        buildLights(&rng)
        buildBuildings(&rng)
        if index % 3 == 1 { buildGantry(&rng) }
        buildTunnel(&rng)
        buildElevated(&rng)
        buildFork()
        buildTube()
        buildPortals()
        buildObstaclePool()
    }

    /// Enable the entry frame when the segment before has a different style and the exit frame
    /// when the one after does, so every section change has a designed mouth.
    func setNeighbours(prev: SegmentStyle?, next: SegmentStyle?) {
        let s = block.style
        for (style, e) in entryPortals { e.isEnabled = s == style && prev != nil && prev != style }
        for (style, e) in exitPortals { e.isEnabled = s == style && next != nil && next != style }
    }

    private var mid: Float { -length / 2 }

    // MARK: Style switching

    func configure(block: TrackBlock, settings: FXSettings) {
        self.block = block
        var rng = SeededRNG(seed: UInt64(index * 31 + variant * 7 + 11))
        layoutObstacles(rows: block.obstacleRows, style: block.style, rng: &rng)
        apply(settings)
    }

    /// Enable groups according to both the diagnostic toggles and the current style.
    func apply(_ s: FXSettings) {
        let style = block.style
        let city = style == .city || style == .branch
        surface.isEnabled = style != .fork && style != .tube
        tubeGroup.isEnabled = style == .tube
        wideSurface.isEnabled = style == .fork
        laneGroup.isEnabled = s.neon && style != .fork && style != .tube
        roadsideGroup.isEnabled = city
        buildingGroup.isEnabled = s.buildings && (city || style == .fork)
        // the fork's road is twice as wide and its branches slide outward, so its building rows stand further back
        buildingGroup.scale.x = style == .fork ? 1.7 : 1
        signGroup.isEnabled = s.signs && (city || style == .fork) && materials.theme == .neonCity
        reflectionGroup.isEnabled = s.reflections && city
        tunnelGroup.isEnabled = style == .tunnel
        elevatedGroup.isEnabled = style == .elevated
        forkGroup.isEnabled = style == .fork
        obstacleGroup.isEnabled = s.obstacles
        for m in hazardMarks { m.isEnabled = s.hazardX }
        storefrontGroup.isEnabled = s.storefronts
        secondRowGroup.isEnabled = s.secondRow
        altRowGroup.isEnabled = s.secondRow || s.storefronts   // sparse preset removes every other near tower too
        for r in denseRings { r.isEnabled = s.tunnelDense }
        for (i, g) in skinGroups.enumerated() { for e in g { e.isEnabled = i == s.obstacleSkin } }
        if lastPalette == nil || lastPalette! != (s.palette, s.ringColor * 100 + s.hazardColor * 10 + s.obstacleSkin) {
            lastPalette = (s.palette, s.ringColor * 100 + s.hazardColor * 10 + s.obstacleSkin)
            applyPalette(s)
        }
        if lastWindowsBright != s.windowsBright {
            lastWindowsBright = s.windowsBright
            for (e, base) in facadeEntities {
                var m = base
                m.emissiveIntensity = s.windowsBright ? 3.2 : 1.0
                if var model = e.model { model.materials = [m]; e.model = model }
            }
        }
    }

    /// Assign colours by role so each family of lights reads as one thing.
    private func applyPalette(_ s: FXSettings) {
        let warm: [SIMD3<Float>] = [Neon.orange, Neon.magenta, SIMD3(1.0, 0.85, 0.2), Neon.red]
        let cool: [SIMD3<Float>] = [Neon.cyan, Neon.blue, Neon.violet, SIMD3(0.6, 0.9, 1.0)]
        let mixed: [SIMD3<Float>] = Neon.all
        let amber = SIMD3<Float>(1.0, 0.62, 0.15)
        let roadP: [SIMD3<Float>], roadS: SIMD3<Float>, city: [SIMD3<Float>]
        switch s.palette {
        case 1:  roadP = [Neon.cyan];  roadS = SIMD3(0.8, 0.95, 1.0); city = warm
        case 2:  roadP = [amber];      roadS = SIMD3(1.0, 0.95, 0.8); city = cool
        case 3:  roadP = [SIMD3(1.0, 0.98, 0.9)]; roadS = SIMD3(1.0, 0.85, 0.3); city = [amber, SIMD3(1.0, 0.9, 0.7)]   // painted white edges, yellow centre
        default: roadP = [Neon.cyan, Neon.magenta]; roadS = Neon.magenta; city = mixed
        }
        let ring: [SIMD3<Float>]
        let ringGain: Float
        switch s.ringColor {
        case 1:  ring = [SIMD3(0.30, 0.50, 1.0)]; ringGain = 0.7
        case 2:  ring = [SIMD3(1.0, 0.12, 0.18)]; ringGain = 0.75
        case 3:  ring = [SIMD3(1.0, 0.70, 0.35)]; ringGain = 0.9
        default: ring = [Neon.magenta, Neon.cyan, Neon.blue]; ringGain = 1.0
        }
        func set(_ e: ModelEntity, _ m: any Material) { if var model = e.model { model.materials = [m]; e.model = model } }
        for (i, (e, k)) in roadPrimary.enumerated() { set(e, materials.neon(roadP[i % roadP.count], intensity: k)) }
        for (e, k) in roadSecondary { set(e, materials.neon(roadS, intensity: k)) }
        for (i, (e, k)) in roadReflections.enumerated() { set(e, materials.reflection(roadP[i % roadP.count], opacity: k)) }
        for (i, (e, k)) in cityNeon.enumerated() { set(e, materials.neon(city[(i * 7 + index) % city.count], intensity: k)) }
        for (i, (e, k)) in ringNeon.enumerated() { set(e, materials.neon(ring[i % ring.count], intensity: k * ringGain)) }
        for (i, (e, k)) in ringReflections.enumerated() { set(e, materials.reflection(ring[i % ring.count], opacity: k)) }
        let hazard: SIMD3<Float>
        switch s.hazardColor {
        case 1:  hazard = SIMD3(0.75, 1.0, 0.18)
        case 2:  hazard = Neon.orange
        case 3:  hazard = SIMD3(1.0, 1.0, 0.95)
        default: hazard = Neon.magenta
        }
        for (e, k) in hazardNeon { set(e, materials.neon(hazard, intensity: k * 0.75)) }
        for e in hazardPanels { set(e, materials.holoPanel(hazard)) }
        for (e, k) in hazardGlows { set(e, materials.glow(hazard, opacity: k)) }
        for (e, k) in hazardReflections { set(e, materials.reflection(hazard, opacity: k)) }
        for (e, k) in hazardTrim { set(e, materials.neon(hazard, intensity: k * 0.85)) }
        // X marks: red normally; white on the red-bodied trim skin so they stay visible
        let xColor: SIMD3<Float> = s.obstacleSkin == 3 ? SIMD3(1.0, 1.0, 0.95) : SIMD3(1.0, 0.1, 0.12)
        for m in hazardMarks { for case let bar as ModelEntity in m.children { set(bar, materials.neon(xColor, intensity: 5)) } }
    }

    /// Called when the segment wraps to the far end.
    func recycle() {
        variant += 1
        for (i, p) in optionalProps.enumerated() { p.isEnabled = (i + variant) % 3 != 0 }
        if !billboards.isEmpty {
            let b = billboards[variant % billboards.count]
            if var model = b.model {
                model.materials = [materials.signs[(variant * 3 + index) % materials.signs.count]]
                b.model = model
            }
        }
    }

    func animate(time: Float) {
        for (i, d) in drones.enumerated() where d.isEnabled {
            d.position.y = 2.4 + sin(time * 2.2 + Float(i) * 1.7) * 0.18
        }
        let on = Int(time * 5) % 2 == 0
        for s in strobes { s.isEnabled = on }
    }

    /// Road centre offset (relative to startOffset frame) at a parametric position
    /// t in 0 (near edge) ... 1 (far edge).
    func offset(at t: Float) -> Float {
        if block.style == .fork {
            let split: Float = 0.25
            if t < split { return startOffset }
            let u = (t - split) / (1 - split)
            return startOffset + (endOffset - startOffset) * (u * u * (3 - 2 * u))
        }
        return startOffset + (endOffset - startOffset) * t
    }

    /// Position + yaw so the far edge lands on `endOffset`.
    func placeTransform() {
        let dx = endOffset - startOffset
        root.position.x = startOffset
        root.orientation = simd_quatf(angle: -atan2(dx, length), axis: [0, 1, 0])
    }

    // MARK: Lanes / roadside (city)

    private func buildLanes() {
        for x in [-7.6, 7.6] as [Float] {
            let line = ModelEntity(mesh: .generateBox(size: [0.12, 0.02, length + 1]), materials: [materials.neon(Neon.cyan, intensity: 3.5)])
            line.position = [x, 0.015, mid]
            laneGroup.addChild(line)
            roadPrimary.append((line, 3.5))
        }
        let dashMat = materials.neon(Neon.magenta, intensity: 2.4)
        for k in 0..<5 {
            let dash = ModelEntity(mesh: .generateBox(size: [0.16, 0.02, 3.2]), materials: [dashMat])
            dash.position = [0, 0.015, -4 - Float(k) * 8]
            laneGroup.addChild(dash)
            roadSecondary.append((dash, 2.4))
        }
        let laneMat = materials.neon(SIMD3(0.75, 0.8, 1.0), intensity: 0.9)
        for x in [-3.8, 3.8] as [Float] {
            for k in 0..<5 {
                let dash = ModelEntity(mesh: .generateBox(size: [0.1, 0.015, 2.0]), materials: [laneMat])
                dash.position = [x, 0.012, -8 - Float(k) * 8]
                laneGroup.addChild(dash)
            }
        }
    }

    private func buildBarriers() {
        for (side, color) in [(-1, Neon.cyan), (1, Neon.orange)] as [(Float, SIMD3<Float>)] {
            let wall = ModelEntity(mesh: .generateBox(size: [0.5, 0.9, length + 1]), materials: [materials.barrier])
            wall.position = [side * 9.0, 0.45, mid]
            roadsideGroup.addChild(wall)
            let strip = ModelEntity(mesh: .generateBox(size: [0.52, 0.06, length + 1]), materials: [materials.neon(color, intensity: 2.5)])
            strip.position = [side * 9.0, 0.93, mid]
            roadsideGroup.addChild(strip)
            roadPrimary.append((strip, 2.5))
            let refl = ModelEntity(mesh: .generatePlane(width: 2.2, depth: length), materials: [materials.reflection(color, opacity: 0.22)])
            refl.position = [side * 7.4, 0.02, mid]
            reflectionGroup.addChild(refl)
            roadReflections.append((refl, 0.22))
        }
    }

    private func buildLights(_ rng: inout SeededRNG) {
        for k in 0..<4 {
            let z = -5 - Float(k) * 10
            for side in [-1, 1] as [Float] {
                let color = (k + (side > 0 ? 1 : 0)) % 2 == 0 ? Neon.cyan : Neon.magenta
                let pole = ModelEntity(mesh: .generateBox(size: [0.18, 6.0, 0.18]), materials: [materials.concrete])
                pole.position = [side * 10.2, 3.0, z]
                roadsideGroup.addChild(pole)
                let tube = ModelEntity(mesh: .generateBox(size: [0.10, 4.2, 0.10]), materials: [materials.neon(color, intensity: 4)])
                tube.position = [side * 10.2 - side * 0.14, 3.4, z]
                roadsideGroup.addChild(tube)
                roadPrimary.append((tube, 4))
                let arm = ModelEntity(mesh: .generateBox(size: [2.4, 0.09, 0.09]), materials: [materials.neon(color, intensity: 4)])
                arm.position = [side * 9.1, 6.0, z]
                roadsideGroup.addChild(arm)
                roadPrimary.append((arm, 4))
                let refl = ModelEntity(mesh: .generatePlane(width: 1.8, depth: 13), materials: [materials.reflection(color, opacity: 0.32)])
                refl.position = [side * 7.9, 0.025, z + 4.5]
                reflectionGroup.addChild(refl)
                roadReflections.append((refl, 0.32))
            }
        }
        if rng.chance(0.6) {
            let studMat = materials.neon(Neon.white, intensity: 2)
            for k in 0..<4 {
                let stud = ModelEntity(mesh: .generateBox(size: [0.25, 0.05, 0.25]), materials: [studMat])
                stud.position = [rng.chance(0.5) ? -3.8 : 3.8, 0.03, -3 - Float(k) * 10]
                laneGroup.addChild(stud)
                optionalProps.append(stud)
            }
        }
    }

    /// Canyon: stepped sandstone mesas and boulders instead of towers.
    private func buildMesas(_ rng: inout SeededRNG) {
        for side in [-1, 1] as [Float] {
            var z: Float = -2
            var slot = 0
            while z > -length + 4 {
                let w = rng.float(14, 30)
                let d = rng.float(14, 34)
                let h = rng.float(10, 48)
                let setback = rng.float(2, 12)
                let x = side * (11.5 + setback + d / 2)
                var mat = rng.pick(materials.facades)
                mat.textureCoordinateTransform = .init(offset: SIMD2(rng.float(), rng.float()), scale: SIMD2(max(w, d) / 18, h / 18), rotation: 0)
                let host: Entity = slot % 2 == 1 ? altRowGroup : buildingGroup
                var tierW = d, tierD = w, tierH = h, baseY: Float = 0
                let tiers = Int(rng.float(1, 3.99))
                for _ in 0..<tiers {
                    let b = ModelEntity(mesh: .generateBox(width: tierW, height: tierH, depth: tierD, cornerRadius: 0.6), materials: [mat])
                    b.position = [x + rng.float(-1.5, 1.5), baseY + tierH / 2, z - w / 2 + rng.float(-1.5, 1.5)]
                    host.addChild(b)
                    baseY += tierH
                    tierW *= rng.float(0.55, 0.8); tierD *= rng.float(0.55, 0.8); tierH *= rng.float(0.35, 0.6)
                }
                // boulders near the road
                if rng.chance(0.6) {
                    let r = rng.float(1.2, 3.0)
                    let rock = ModelEntity(mesh: .generateBox(width: r * 1.6, height: r, depth: r * 1.3, cornerRadius: r * 0.4), materials: [mat])
                    rock.position = [side * (10.5 + rng.float(0.5, 4)), r / 2 - 0.2, z - rng.float(0, w)]
                    rock.orientation = simd_quatf(angle: rng.float(-0.4, 0.4), axis: [0, 1, 0])
                    storefrontGroup.addChild(rock)
                }
                z -= w + rng.float(2, 10)
                slot += 1
            }
            // distant, taller mesas
            z = rng.float(-2, 4)
            while z > -length - 10 {
                let w = rng.float(30, 60), d = rng.float(30, 70), h = rng.float(40, 110)
                let x = side * (11.5 + rng.float(30, 70) + d / 2)
                var mat = rng.pick(materials.facades)
                mat.textureCoordinateTransform = .init(offset: .zero, scale: SIMD2(max(w, d) / 40, h / 40), rotation: 0)
                let b = ModelEntity(mesh: .generateBox(width: d, height: h, depth: w, cornerRadius: 1.5), materials: [mat])
                b.position = [x, h / 2 - 2, z - w / 2]
                secondRowGroup.addChild(b)
                z -= w + rng.float(4, 14)
            }
        }
    }

    private func buildBuildings(_ rng: inout SeededRNG) {
        if materials.theme == .sunsetCanyon { buildMesas(&rng); return }
        for side in [-1, 1] as [Float] {
            var z: Float = -2
            var slot = 0
            while z > -length + 4 {
                let w = rng.float(8, 16)
                let d = rng.float(9, 22)
                let h = rng.float(16, 95)
                let setback = rng.float(0, 5)
                let x = side * (11.5 + setback + d / 2)
                var mat = rng.pick(materials.facades)
                mat.textureCoordinateTransform = .init(offset: SIMD2(rng.float(), rng.float()), scale: SIMD2(max(w, d) / 24, h / 36), rotation: 0)
                let b = ModelEntity(mesh: .generateBox(width: d, height: h, depth: w), materials: [mat])
                b.position = [x, h / 2, z - w / 2]
                let host: Entity = slot % 2 == 1 ? altRowGroup : buildingGroup
                host.addChild(b)
                facadeEntities.append((b, mat))

                if rng.chance(0.45) {
                    let ah = rng.float(5, 14)
                    let mast = ModelEntity(mesh: .generateBox(size: [0.35, ah, 0.35]), materials: [materials.concrete])
                    mast.position = [x + rng.float(-d / 3, d / 3), h + ah / 2, z - w / 2]
                    buildingGroup.addChild(mast)
                    let beacon = ModelEntity(mesh: .generateBox(size: [0.5, 0.5, 0.5]), materials: [materials.neon(Neon.red, intensity: 5)])
                    beacon.position = mast.position + [0, ah / 2 + 0.2, 0]
                    buildingGroup.addChild(beacon)
                }
                if rng.chance(0.65) {
                    let color = rng.pick(Neon.all)
                    let sh = h * rng.float(0.35, 0.8)
                    let strip = ModelEntity(mesh: .generateBox(size: [0.2, sh, 0.35]), materials: [materials.neon(color, intensity: 3)])
                    strip.position = [x - side * (d / 2 + 0.1), sh / 2 + 2, z - w * rng.float(0.2, 0.8)]
                    buildingGroup.addChild(strip)
                    cityNeon.append((strip, 3))
                }
                if rng.chance(0.5) && h > 22 {
                    let bw = rng.float(7, 11), bh = bw * 0.5
                    let sign = ModelEntity(mesh: .generatePlane(width: bw, height: bh), materials: [rng.pick(materials.signs)])
                    sign.position = [x - side * (d / 2 + 0.15), rng.float(9, h - bh), z - w / 2]
                    sign.orientation = simd_quatf(angle: side < 0 ? .pi / 2 : -.pi / 2, axis: [0, 1, 0])
                    signGroup.addChild(sign)
                    billboards.append(sign)
                }
                if rng.chance(0.4) && h > 30 {
                    let gh = rng.float(10, 22)
                    let g = ModelEntity(mesh: .generatePlane(width: gh / 4, height: gh), materials: [rng.pick(materials.glyphSigns)])
                    g.position = [x - side * (d / 2 + 0.2), gh / 2 + rng.float(4, 12), z - w * rng.float(0.15, 0.85)]
                    g.orientation = simd_quatf(angle: side < 0 ? .pi / 2 : -.pi / 2, axis: [0, 1, 0])
                    signGroup.addChild(g)
                }
                if slot == 1 && rng.chance(0.7) && h > 24 {
                    let bw = rng.float(9, 14), bh = bw * 0.5
                    let sign = ModelEntity(mesh: .generatePlane(width: bw, height: bh), materials: [rng.pick(materials.hologramSigns)])
                    sign.position = [x, rng.float(12, h - bh), z + 0.2]
                    signGroup.addChild(sign)
                    billboards.append(sign)
                }
                let shop = ModelEntity(mesh: .generateBox(size: [0.25, 0.18, w * 0.9]), materials: [materials.neon(rng.pick(Neon.all), intensity: 2.5)])
                shop.position = [x - side * (d / 2 + 0.12), 4.2, z - w / 2]
                storefrontGroup.addChild(shop)
                cityNeon.append((shop, 2.5))
                if rng.chance(0.6) {
                    let ph = rng.float(4, 9)
                    let podium = ModelEntity(mesh: .generateBox(width: d * 0.8, height: ph, depth: w + 5), materials: [materials.concrete])
                    podium.position = [x + side * 1.5, ph / 2, z - w / 2 - 2.5]
                    storefrontGroup.addChild(podium)
                }
                z -= w + rng.float(1, 6)
                slot += 1
            }
            // second, taller row
            z = rng.float(-2, 4)
            while z > -length - 10 {
                let w = rng.float(16, 30)
                let d = rng.float(16, 34)
                let h = rng.float(55, 150)
                let x = side * (11.5 + rng.float(24, 42) + d / 2)
                var mat = rng.pick(materials.facades)
                mat.textureCoordinateTransform = .init(offset: SIMD2(rng.float(), rng.float()), scale: SIMD2(max(w, d) / 24, h / 36), rotation: 0)
                let b = ModelEntity(mesh: .generateBox(width: d, height: h, depth: w), materials: [mat])
                b.position = [x, h / 2, z - w / 2]
                secondRowGroup.addChild(b)
                facadeEntities.append((b, mat))
                if rng.chance(0.5) {
                    let color = rng.pick(Neon.all)
                    let sh = h * rng.float(0.3, 0.7)
                    let strip = ModelEntity(mesh: .generateBox(size: [0.5, sh, 0.5]), materials: [materials.neon(color, intensity: 3)])
                    strip.position = [x - side * (d / 2 + 0.2), sh / 2 + 10, z - w * rng.float(0.2, 0.8)]
                    secondRowGroup.addChild(strip)
                    cityNeon.append((strip, 3))
                }
                if rng.chance(0.35) {
                    let beacon = ModelEntity(mesh: .generateBox(size: [0.8, 0.8, 0.8]), materials: [materials.neon(Neon.red, intensity: 5)])
                    beacon.position = [x, h + 0.4, z - w / 2]
                    secondRowGroup.addChild(beacon)
                }
                z -= w + rng.float(2, 8)
            }
        }
    }

    private func buildGantry(_ rng: inout SeededRNG) {
        let z: Float = mid
        let beam = ModelEntity(mesh: .generateBox(size: [22, 1.4, 1.8]), materials: [materials.barrier])
        beam.position = [0, 9.5, z]
        roadsideGroup.addChild(beam)
        for side in [-1, 1] as [Float] {
            let pillar = ModelEntity(mesh: .generateBox(size: [1.0, 9.5, 1.0]), materials: [materials.concrete])
            pillar.position = [side * 10.5, 4.75, z]
            roadsideGroup.addChild(pillar)
        }
        let under = ModelEntity(mesh: .generateBox(size: [20, 0.12, 0.12]), materials: [materials.neon(Neon.magenta, intensity: 4)])
        under.position = [0, 8.75, z + 0.9]
        roadsideGroup.addChild(under)
        roadPrimary.append((under, 4))
        let top = ModelEntity(mesh: .generateBox(size: [22, 0.1, 0.1]), materials: [materials.neon(Neon.cyan, intensity: 4)])
        top.position = [0, 10.25, z + 0.9]
        roadsideGroup.addChild(top)
        roadPrimary.append((top, 4))
        let sign = ModelEntity(mesh: .generatePlane(width: 9, height: 4.5), materials: [rng.pick(materials.hologramSigns)])
        sign.position = [rng.float(-4, 4), 12.6, z + 0.5]
        signGroup.addChild(sign)
        billboards.append(sign)
        let refl = ModelEntity(mesh: .generatePlane(width: 16, depth: 10), materials: [materials.reflection(Neon.magenta, opacity: 0.25)])
        refl.position = [0, 0.03, z + 5]
        reflectionGroup.addChild(refl)
    }

    // MARK: Tunnel

    private func buildTunnel(_ rng: inout SeededRNG) {
        let L = length + 2
        for side in [-1, 1] as [Float] {
            let wall = ModelEntity(mesh: .generateBox(size: [1.2, 11, L]), materials: [materials.tunnelWall])
            wall.position = [side * 10.2, 5.5, mid]
            tunnelGroup.addChild(wall)
            // low guide light along the wall base
            let base = ModelEntity(mesh: .generateBox(size: [0.12, 0.12, L]), materials: [materials.neon(Neon.blue, intensity: 2.5)])
            base.position = [side * 9.55, 0.35, mid]
            tunnelGroup.addChild(base)
            // glyph panels
            for k in 0..<3 {
                let g = ModelEntity(mesh: .generatePlane(width: 2.2, height: 6), materials: [materials.glyphSigns[(index + k * 2) % materials.glyphSigns.count]])
                g.position = [side * 9.55, 5, -8 - Float(k) * 13 - rng.float(0, 3)]
                g.orientation = simd_quatf(angle: side < 0 ? .pi / 2 : -.pi / 2, axis: [0, 1, 0])
                tunnelGroup.addChild(g)
            }
        }
        let ceiling = ModelEntity(mesh: .generateBox(size: [22, 1, L]), materials: [materials.tunnelWall])
        ceiling.position = [0, 11.5, mid]
        tunnelGroup.addChild(ceiling)
        for x in [-4.5, 4.5] as [Float] {
            let strip = ModelEntity(mesh: .generateBox(size: [0.25, 0.08, L]), materials: [materials.neon(SIMD3(0.5, 0.6, 1.0), intensity: 1.6)])
            strip.position = [x, 10.95, mid]
            tunnelGroup.addChild(strip)
        }
        // light rings every 8 m, alternating colours
        for k in 0..<5 {
            let z = -4 - Float(k) * 8
            let color = (k + index) % 2 == 0 ? Neon.cyan : Neon.magenta
            let m = materials.neon(color, intensity: 3.5)
            let top = ModelEntity(mesh: .generateBox(size: [19.2, 0.18, 0.18]), materials: [m])
            top.position = [0, 10.6, z]
            tunnelGroup.addChild(top)
            ringNeon.append((top, 3.5))
            for side in [-1, 1] as [Float] {
                let bar = ModelEntity(mesh: .generateBox(size: [0.18, 10.4, 0.18]), materials: [m])
                bar.position = [side * 9.5, 5.4, z]
                tunnelGroup.addChild(bar)
                ringNeon.append((bar, 3.5))
            }
            let refl = ModelEntity(mesh: .generatePlane(width: 17, depth: 7), materials: [materials.reflection(color, opacity: 0.22)])
            refl.position = [0, 0.03, z + 2.5]
            tunnelGroup.addChild(refl)
            ringReflections.append((refl, 0.22))
            // extra ring between (dense variant)
            let m2 = materials.neon(Neon.white, intensity: 2.2)
            let top2 = ModelEntity(mesh: .generateBox(size: [19.2, 0.12, 0.12]), materials: [m2])
            top2.position = [0, 10.6, z - 4]
            tunnelGroup.addChild(top2); denseRings.append(top2); ringNeon.append((top2, 2.4))
            for side in [-1, 1] as [Float] {
                let bar2 = ModelEntity(mesh: .generateBox(size: [0.12, 10.4, 0.12]), materials: [m2])
                bar2.position = [side * 9.5, 5.4, z - 4]
                tunnelGroup.addChild(bar2); denseRings.append(bar2); ringNeon.append((bar2, 2.4))
            }
        }
        // own lane edges (the city lane group is shared, tunnel keeps it enabled too)
    }

    // MARK: Elevated skyway

    private func buildElevated(_ rng: inout SeededRNG) {
        let L = length + 2
        for side in [-1, 1] as [Float] {
            let rail = ModelEntity(mesh: .generateBox(size: [0.15, 1.1, L]), materials: [materials.barrier])
            rail.position = [side * 8.9, 0.55, mid]
            elevatedGroup.addChild(rail)
            let top = ModelEntity(mesh: .generateBox(size: [0.18, 0.08, L]), materials: [materials.neon(SIMD3(0.7, 0.85, 1.0), intensity: 2.2)])
            top.position = [side * 8.9, 1.12, mid]
            elevatedGroup.addChild(top)
            // deck edge underside glow
            let edge = ModelEntity(mesh: .generateBox(size: [0.3, 0.12, L]), materials: [materials.neon(Neon.violet, intensity: 2)])
            edge.position = [side * 9.4, -0.3, mid]
            elevatedGroup.addChild(edge)
            // deck slab
            let slab = ModelEntity(mesh: .generateBox(size: [1.2, 1.4, L]), materials: [materials.concrete])
            slab.position = [side * 9.6, -0.7, mid]
            elevatedGroup.addChild(slab)
            // floating billboards far to the sides, facing the driver
            if rng.chance(0.7) {
                let bw = rng.float(14, 22), bh = bw * 0.5
                let sign = ModelEntity(mesh: .generatePlane(width: bw, height: bh), materials: [rng.pick(materials.signs)])
                sign.position = [side * rng.float(24, 40), rng.float(14, 30), -length * rng.float(0.3, 0.9)]
                elevatedGroup.addChild(sign)
                let frame = ModelEntity(mesh: .generateBox(size: [bw + 0.6, bh + 0.6, 0.3]), materials: [materials.neon(rng.pick(Neon.all), intensity: 2)])
                frame.position = sign.position - [0, 0, 0.2]
                elevatedGroup.addChild(frame)
            }
        }
        // light arches every 20 m
        for k in 0..<2 {
            let z = -10 - Float(k) * 20
            let color = (k + index) % 2 == 0 ? Neon.orange : Neon.cyan
            let m = materials.neon(color, intensity: 3.5)
            let top = ModelEntity(mesh: .generateBox(size: [20, 0.2, 0.2]), materials: [m])
            top.position = [0, 8.5, z]
            elevatedGroup.addChild(top)
            for side in [-1, 1] as [Float] {
                let post = ModelEntity(mesh: .generateBox(size: [0.25, 8.5, 0.25]), materials: [m])
                post.position = [side * 9.9, 4.25, z]
                elevatedGroup.addChild(post)
            }
            let refl = ModelEntity(mesh: .generatePlane(width: 17, depth: 8), materials: [materials.reflection(color, opacity: 0.2)])
            refl.position = [0, 0.03, z + 3]
            elevatedGroup.addChild(refl)
        }
        // support pylons dropping below the deck, spaced out
        for k in 0..<2 {
            let pylon = ModelEntity(mesh: .generateBox(size: [2.5, 60, 2.5]), materials: [materials.concrete])
            pylon.position = [Float(k == 0 ? -1 : 1) * 12, -31, -8 - Float(k) * 20]
            elevatedGroup.addChild(pylon)
        }
    }

    // MARK: Fork

    private func buildFork() {
        // wide road markings
        for x in [-16.6, 16.6] as [Float] {
            let line = ModelEntity(mesh: .generateBox(size: [0.12, 0.02, length + 1]), materials: [materials.neon(Neon.cyan, intensity: 3.5)])
            line.position = [x, 0.015, mid]
            forkGroup.addChild(line)
        }
        let dashMat = materials.neon(Neon.magenta, intensity: 4)
        for x in [-9.0, 9.0] as [Float] {
            for k in 0..<3 {
                let dash = ModelEntity(mesh: .generateBox(size: [0.16, 0.02, 3.2]), materials: [dashMat])
                dash.position = [x, 0.015, -14 - Float(k) * 9]
                forkGroup.addChild(dash)
            }
        }
        // V-shaped divider: two angled walls from a narrow nose at z = -9 to +-6 m at the far end
        let halfSpread = Self.forkHalfSpread
        let wallLen: Float = 31
        let angle = atan2(halfSpread, wallLen)
        for side in [-1, 1] as [Float] {
            var mat = materials.facades[1]
            mat.textureCoordinateTransform = .init(offset: .zero, scale: SIMD2(wallLen / 24, 14 / 36), rotation: 0)
            let wall = ModelEntity(mesh: .generateBox(width: 0.8, height: 14, depth: wallLen), materials: [mat])
            let pivot = Entity()
            pivot.position = [0, 7, -9]
            pivot.orientation = simd_quatf(angle: -side * angle, axis: [0, 1, 0])
            wall.position = [side * 0.4, 0, -wallLen / 2]
            pivot.addChild(wall)
            let strip = ModelEntity(mesh: .generateBox(size: [0.9, 0.15, wallLen]), materials: [materials.neon(side < 0 ? Neon.cyan : Neon.magenta, intensity: 3.5)])
            strip.position = [side * 0.4, 7.05, -wallLen / 2]
            pivot.addChild(strip)
            let low = ModelEntity(mesh: .generateBox(size: [0.9, 0.12, wallLen]), materials: [materials.neon(side < 0 ? Neon.cyan : Neon.magenta, intensity: 3)])
            low.position = [side * 0.5, -6.3, -wallLen / 2]
            pivot.addChild(low)
            forkGroup.addChild(pivot)
        }
        let core = ModelEntity(mesh: .generateBox(width: 2 * halfSpread - 1.2, height: 20, depth: 15), materials: [materials.facades[0]])
        core.position = [0, 10, -32.5]
        forkGroup.addChild(core)
        let nose = ModelEntity(mesh: .generateBox(width: 1.2, height: 6, depth: 2), materials: [materials.barrier])
        nose.position = [0, 3, -9]
        forkGroup.addChild(nose)
        // chevrons: cyan "<" left, magenta ">" right
        func chevron(x: Float, dir: Float, color: SIMD3<Float>) {
            let m = materials.neon(color, intensity: 5)
            let a = ModelEntity(mesh: .generateBox(size: [2.4, 0.35, 0.3]), materials: [m])
            a.position = [x, 4.6, -9.8]
            a.orientation = simd_quatf(angle: dir * 0.7, axis: [0, 0, 1])
            let b = ModelEntity(mesh: .generateBox(size: [2.4, 0.35, 0.3]), materials: [m])
            b.position = [x, 3.2, -9.8]
            b.orientation = simd_quatf(angle: -dir * 0.7, axis: [0, 0, 1])
            forkGroup.addChild(a); forkGroup.addChild(b)
        }
        chevron(x: -3.2, dir: 1, color: Neon.cyan)
        chevron(x: 3.2, dir: -1, color: Neon.magenta)
        let sign = ModelEntity(mesh: .generatePlane(width: 10, height: 5), materials: [materials.hologramSigns[3 % materials.hologramSigns.count]])
        sign.position = [0, 11, -9.5]
        forkGroup.addChild(sign)
        // guide lights along both branches
        for k in 0..<4 {
            let z = -14 - Float(k) * 7
            for (x, color) in [(-16.6, Neon.cyan), (16.6, Neon.magenta)] as [(Float, SIMD3<Float>)] {
                let post = ModelEntity(mesh: .generateBox(size: [0.15, 4, 0.15]), materials: [materials.neon(color, intensity: 4)])
                post.position = [x + (x < 0 ? -0.6 : 0.6), 2, z]
                forkGroup.addChild(post)
                roadPrimary.append((post, 4))
            }
        }
    }

    /// Half width of the divider at the fork's far end and of the wedge core: narrow, so the branch
    /// roads (which slide `forkDiverge` m by the far end) keep their outer lanes clear of it.
    static let forkHalfSpread: Float = 3
    static let forkDiverge: Float = 7

    // MARK: Tube conduit

    static let tubeRadius: Float = 6.0
    static let tubeCenterY: Float = 6.0

    private func buildTube() {
        let R = Self.tubeRadius, cy = Self.tubeCenterY
        do {
            let mesh = try Meshes.tube(radius: R, length: length + 2, uRepeat: 12, vRepeat: 14)
            let wall = ModelEntity(mesh: mesh, materials: [materials.tubeWall])
            wall.position = [0, cy, 1]
            tubeGroup.addChild(wall)
            let ringMesh = try Meshes.ring(inner: R - 0.45, outer: R - 0.1)
            for k in 0..<5 {
                let color = (k + index) % 3 == 0 ? Neon.magenta : ((k + index) % 3 == 1 ? Neon.cyan : Neon.blue)
                let ring = ModelEntity(mesh: ringMesh, materials: [materials.neon(color, intensity: 3.2)])
                ring.position = [0, cy, -4 - Float(k) * 8]
                tubeGroup.addChild(ring)
                ringNeon.append((ring, 3.2))
                let ring2 = ModelEntity(mesh: ringMesh, materials: [materials.neon(Neon.white, intensity: 2.0)])
                ring2.position = [0, cy, -8 - Float(k) * 8]
                ring2.scale = [0.98, 0.98, 1]
                tubeGroup.addChild(ring2); denseRings.append(ring2); ringNeon.append((ring2, 2.2))
            }
        } catch {
            print("tube mesh failed: \(error)")
        }
        // four running light strips along the wall
        for a in [Float.pi / 4, 3 * .pi / 4, 5 * .pi / 4, 7 * .pi / 4] {
            let strip = ModelEntity(mesh: .generateBox(size: [0.16, 0.16, length + 2]), materials: [materials.neon(SIMD3(0.5, 0.65, 1.0), intensity: 1.8)])
            strip.position = [cos(a) * (R - 0.2), cy + sin(a) * (R - 0.2), mid]
            tubeGroup.addChild(strip)
        }
        // floor guide line so "down" still reads
        let guide = ModelEntity(mesh: .generateBox(size: [0.12, 0.05, length + 2]), materials: [materials.neon(Neon.cyan, intensity: 2.5)])
        guide.position = [0, 0.05, mid]
        tubeGroup.addChild(guide)
    }

    // MARK: Portals (section lead-ins)

    /// One entry and one exit frame per enclosed style, centred on the segment edge so the
    /// same geometry serves both ends (the exit is the entry turned around).
    private func buildPortals() {
        for style in [SegmentStyle.tube, .tunnel, .elevated] {
            let entry = Entity(), exit = Entity()
            buildPortal(style, into: entry)
            buildPortal(style, into: exit)
            exit.position.z = -length
            exit.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
            entry.isEnabled = false; exit.isEnabled = false
            portalGroup.addChild(entry); portalGroup.addChild(exit)
            entryPortals[style] = entry; exitPortals[style] = exit
        }
    }

    private func buildPortal(_ style: SegmentStyle, into host: Entity) {
        let ringColor = Neon.cyan
        switch style {
        case .tube:
            // collar around the pipe mouth, a lit rim, and a flange wall so the pipe has thickness
            let R = Self.tubeRadius, cy = Self.tubeCenterY
            if let collar = try? Meshes.tube(radius: R + 0.55, length: 2.8, uRepeat: 12, vRepeat: 1) {
                let c = ModelEntity(mesh: collar, materials: [materials.tubeWall])
                c.position = [0, cy, 1.4]
                host.addChild(c)
            }
            if let rim = try? Meshes.tube(radius: R + 0.22, length: 0.5, uRepeat: 1, vRepeat: 1) {
                let r = ModelEntity(mesh: rim, materials: [materials.neon(ringColor, intensity: 3.2)])
                r.position = [0, cy, 0.25]
                host.addChild(r)
                ringNeon.append((r, 3.2))
            }
            if let flange = try? Meshes.ring(inner: R + 0.5, outer: R + 3.0) {
                let f = ModelEntity(mesh: flange, materials: [materials.tunnelWall])
                f.position = [0, cy, 0]
                f.orientation = simd_quatf(angle: 0.02, axis: [1, 0, 0])
                host.addChild(f)
            }
            let hood = ModelEntity(mesh: .generateBox(size: [2 * R + 6, 2.6, 3.2]), materials: [materials.tunnelWall])
            hood.position = [0, cy + R + 1.6, 0]
            host.addChild(hood)
            for side in [-1, 1] as [Float] {
                let pillar = ModelEntity(mesh: .generateBox(size: [2.4, cy + R + 0.4, 3.2]), materials: [materials.tunnelWall])
                pillar.position = [side * (R + 2.4), (cy + R + 0.4) / 2, 0]
                host.addChild(pillar)
                let post = ModelEntity(mesh: .generateBox(size: [0.16, cy + R, 0.18]), materials: [materials.neon(ringColor, intensity: 2.6)])
                post.position = [side * (R + 1.1), (cy + R) / 2, 1.5]
                host.addChild(post)
                ringNeon.append((post, 2.6))
            }
            let refl = ModelEntity(mesh: .generatePlane(width: 14, depth: 8), materials: [materials.reflection(ringColor, opacity: 0.25)])
            refl.position = [0, 0.03, 4]
            host.addChild(refl)
            ringReflections.append((refl, 0.25))
        case .tunnel:
            // heavy arch frame with a lit inner edge and a pool of its light on the road outside
            for side in [-1, 1] as [Float] {
                let pillar = ModelEntity(mesh: .generateBox(size: [2.2, 13.5, 2.6]), materials: [materials.tunnelWall])
                pillar.position = [side * 11.3, 6.75, 0]
                host.addChild(pillar)
                let bar = ModelEntity(mesh: .generateBox(size: [0.2, 11.2, 0.3]), materials: [materials.neon(ringColor, intensity: 3.5)])
                bar.position = [side * 10.1, 5.6, 1.3]
                host.addChild(bar)
                ringNeon.append((bar, 3.5))
            }
            let lintel = ModelEntity(mesh: .generateBox(size: [24.8, 3.0, 2.6]), materials: [materials.tunnelWall])
            lintel.position = [0, 13.0, 0]
            host.addChild(lintel)
            let top = ModelEntity(mesh: .generateBox(size: [20.4, 0.2, 0.3]), materials: [materials.neon(ringColor, intensity: 3.5)])
            top.position = [0, 11.3, 1.3]
            host.addChild(top)
            ringNeon.append((top, 3.5))
            let crown = ModelEntity(mesh: .generateBox(size: [24.8, 0.14, 0.14]), materials: [materials.neon(SIMD3(0.5, 0.6, 1.0), intensity: 2.0)])
            crown.position = [0, 14.6, 1.3]
            host.addChild(crown)
            let refl = ModelEntity(mesh: .generatePlane(width: 17, depth: 9), materials: [materials.reflection(ringColor, opacity: 0.25)])
            refl.position = [0, 0.03, 4.5]
            host.addChild(refl)
            ringReflections.append((refl, 0.25))
        case .elevated:
            // gate arch at the deck edge, the same family as the skyway's light arches
            let m = materials.neon(ringColor, intensity: 3.5)
            for side in [-1, 1] as [Float] {
                let post = ModelEntity(mesh: .generateBox(size: [0.6, 10, 0.6]), materials: [materials.barrier])
                post.position = [side * 10.3, 5, 0]
                host.addChild(post)
                let strip = ModelEntity(mesh: .generateBox(size: [0.16, 9.6, 0.18]), materials: [m])
                strip.position = [side * 9.9, 4.8, 0.4]
                host.addChild(strip)
                roadPrimary.append((strip, 3.5))
            }
            let top = ModelEntity(mesh: .generateBox(size: [21.2, 0.7, 0.7]), materials: [materials.barrier])
            top.position = [0, 10, 0]
            host.addChild(top)
            let strip = ModelEntity(mesh: .generateBox(size: [20.4, 0.16, 0.18]), materials: [m])
            strip.position = [0, 9.55, 0.4]
            host.addChild(strip)
            roadPrimary.append((strip, 3.5))
            let refl = ModelEntity(mesh: .generatePlane(width: 17, depth: 8), materials: [materials.reflection(ringColor, opacity: 0.2)])
            refl.position = [0, 0.03, 3.5]
            host.addChild(refl)
            roadReflections.append((refl, 0.2))
        default:
            break
        }
    }

    // MARK: Obstacles

    /// Red X mark: two crossed emissive bars on the face of a barrier.
    private func makeX(size: Float, thickness: Float = 0.12) -> Entity {
        let x = Entity()
        let m = materials.neon(SIMD3(1.0, 0.1, 0.12), intensity: 5)
        for angle in [Float.pi / 4, -Float.pi / 4] {
            let bar = ModelEntity(mesh: .generateBox(size: [size, thickness, 0.06]), materials: [m])
            bar.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
            x.addChild(bar)
        }
        hazardMarks.append(x)
        return x
    }

    private func buildObstaclePool() {
        let hazard = materials.neon(Neon.orange, intensity: 3)
        let red = materials.neon(Neon.red, intensity: 5)
        for _ in 0..<4 {
            let e = Entity()
            let body = ModelEntity(mesh: .generateBox(size: [2.2, 1.5, 1.2]), materials: [materials.barrier])
            body.position = [0, 0.75, 0]
            let stripe = ModelEntity(mesh: .generateBox(size: [2.2, 0.3, 0.06]), materials: [hazard])
            stripe.position = [0, 0.95, 0.62]
            let stripe2 = ModelEntity(mesh: .generateBox(size: [2.2, 0.12, 0.06]), materials: [hazard])
            stripe2.position = [0, 0.35, 0.62]
            let lamp = ModelEntity(mesh: .generateBox(size: [1.6, 0.18, 0.3]), materials: [red])
            lamp.position = [0, 1.6, 0]
            let pool = ModelEntity(mesh: .generatePlane(width: 3.2, depth: 5), materials: [materials.reflection(Neon.red, opacity: 0.55)])
            pool.position = [0, 0.03, 1.6]
            let solid = Entity()
            solid.addChild(body); solid.addChild(stripe); solid.addChild(stripe2)
            e.addChild(solid); e.addChild(lamp); e.addChild(pool)
            skinGroups[0].append(solid)
            let mark = makeX(size: 1.5)
            mark.position = [0, 0.75, 0.68]
            e.addChild(mark)
            hazardNeon.append((stripe, 3)); hazardNeon.append((stripe2, 3)); hazardNeon.append((lamp, 5))
            hazardReflections.append((pool, 0.55))
            // skin 1: hologram barrier - translucent magenta panel in a thin frame
            let holo = Entity()
            let panel = ModelEntity(mesh: .generatePlane(width: 2.2, height: 1.5), materials: [materials.holoPanel(Neon.magenta)])
            panel.position = [0, 0.75, 0]
            hazardPanels.append(panel)
            let frameMat = materials.neon(Neon.magenta, intensity: 4)
            for (px, py, sx, sy) in [(-1.1, 0.75, 0.08, 1.5), (1.1, 0.75, 0.08, 1.5), (0, 1.5, 2.2, 0.08), (0, 0.02, 2.2, 0.08)] as [(Float, Float, Float, Float)] {
                let f = ModelEntity(mesh: .generateBox(size: [sx, sy, 0.08]), materials: [frameMat])
                f.position = [px, py, 0]
                holo.addChild(f)
                hazardNeon.append((f, 4))
            }
            holo.addChild(panel)
            holo.isEnabled = false
            e.addChild(holo)
            skinGroups[1].append(holo)
            // skin 2: neon wireframe crate - twelve emissive edges, see-through
            let wire = Entity()
            let wm = materials.neon(Neon.orange, intensity: 4)
            let hw: Float = 1.1, hh: Float = 0.75, hd: Float = 0.6
            for sx in [-hw, hw] { for sy in [0, 2 * hh] as [Float] {
                let eZ = ModelEntity(mesh: .generateBox(size: [0.07, 0.07, hd * 2]), materials: [wm]); eZ.position = [sx, sy, 0]; wire.addChild(eZ); hazardNeon.append((eZ, 4)) } }
            for sx in [-hw, hw] { for sz in [-hd, hd] {
                let eY = ModelEntity(mesh: .generateBox(size: [0.07, hh * 2, 0.07]), materials: [wm]); eY.position = [sx, hh, sz]; wire.addChild(eY); hazardNeon.append((eY, 4)) } }
            for sy in [0, 2 * hh] as [Float] { for sz in [-hd, hd] {
                let eX = ModelEntity(mesh: .generateBox(size: [hw * 2, 0.07, 0.07]), materials: [wm]); eX.position = [0, sy, sz]; wire.addChild(eX); hazardNeon.append((eX, 4)) } }
            let inner = ModelEntity(mesh: .generateBox(size: [1.0, 0.6, 0.6]), materials: [materials.barrier])
            inner.position = [0, hh, 0]
            wire.addChild(inner)
            wire.isEnabled = false
            e.addChild(wire)
            skinGroups[2].append(wire)
            // skin 3: solid coloured body (dim emissive red so it reads at night) with hazard-colour trim edges
            let trimSkin = Entity()
            let bodyMat = materials.neon(SIMD3(0.95, 0.12, 0.10), intensity: 0.75)
            let body3 = ModelEntity(mesh: .generateBox(size: [2.2, 1.5, 1.2], cornerRadius: 0.08), materials: [bodyMat])
            body3.position = [0, 0.75, 0]
            trimSkin.addChild(body3)
            let trimMat = materials.neon(SIMD3(0.80, 1.0, 0.25), intensity: 3.5)
            let tw: Float = 1.1, th: Float = 0.75, td: Float = 0.6
            for sx in [-tw, tw] { for sy in [0, 2 * th] as [Float] {
                let t = ModelEntity(mesh: .generateBox(size: [0.09, 0.09, td * 2 + 0.05]), materials: [trimMat]); t.position = [sx, sy, 0]; trimSkin.addChild(t); hazardTrim.append((t, 3.5)) } }
            for sx in [-tw, tw] { for sz in [-td, td] {
                let t = ModelEntity(mesh: .generateBox(size: [0.09, th * 2 + 0.05, 0.09]), materials: [trimMat]); t.position = [sx, th, sz]; trimSkin.addChild(t); hazardTrim.append((t, 3.5)) } }
            for sy in [0, 2 * th] as [Float] { for sz in [-td, td] {
                let t = ModelEntity(mesh: .generateBox(size: [tw * 2 + 0.05, 0.09, 0.09]), materials: [trimMat]); t.position = [0, sy, sz]; trimSkin.addChild(t); hazardTrim.append((t, 3.5)) } }
            trimSkin.isEnabled = false
            e.addChild(trimSkin)
            skinGroups[3].append(trimSkin)
            strobes.append(lamp)
            e.isEnabled = false
            obstacleGroup.addChild(e)
            obstacles.append(Obstacle(entity: e, kind: .block, halfWidth: 1.1, halfLength: 0.6, halfHeight: 0.75, centerY: 0.75))
        }
        let energy = materials.neon(Neon.magenta, intensity: 4.5)
        for _ in 0..<2 {
            let e = Entity()
            for side in [-1, 1] as [Float] {
                let post = ModelEntity(mesh: .generateBox(size: [0.3, 3.0, 0.3]), materials: [materials.barrier])
                post.position = [side * 1.7, 1.5, 0]
                let tip = ModelEntity(mesh: .generateBox(size: [0.34, 0.3, 0.34]), materials: [energy])
                tip.position = [side * 1.7, 3.1, 0]
                e.addChild(post); e.addChild(tip)
                hazardNeon.append((tip, 4.5))
            }
            let bar = ModelEntity(mesh: .generateBox(size: [3.4, 0.28, 0.08]), materials: [energy])
            bar.position = [0, 1.0, 0]
            let bar2 = ModelEntity(mesh: .generateBox(size: [3.4, 0.12, 0.08]), materials: [energy])
            bar2.position = [0, 2.0, 0]
            let pool = ModelEntity(mesh: .generatePlane(width: 3.6, depth: 4), materials: [materials.reflection(Neon.magenta, opacity: 0.5)])
            pool.position = [0, 0.03, 1.2]
            e.addChild(bar); e.addChild(bar2); e.addChild(pool)
            let gmark = makeX(size: 1.6)
            gmark.position = [0, 1.5, 0.08]
            e.addChild(gmark)
            hazardNeon.append((bar, 4.5)); hazardNeon.append((bar2, 4.5)); hazardReflections.append((pool, 0.5))
            e.isEnabled = false
            obstacleGroup.addChild(e)
            obstacles.append(Obstacle(entity: e, kind: .gate, halfWidth: 1.85, halfLength: 0.3, halfHeight: 1.0, centerY: 1.5))
        }
        for _ in 0..<2 {
            let e = Entity()
            let body = ModelEntity(mesh: .generateBox(size: [1.1, 0.45, 1.1]), materials: [materials.barrier])
            let eye = ModelEntity(mesh: .generateBox(size: [0.35, 0.16, 0.2]), materials: [red])
            eye.position = [0, 0, 0.55]
            let under = ModelEntity(mesh: .generatePlane(width: 2.0, depth: 2.0), materials: [materials.glow(Neon.red, opacity: 0.6)])
            under.position = [0, -0.28, 0]
            let pool = ModelEntity(mesh: .generatePlane(width: 2.6, depth: 4), materials: [materials.reflection(Neon.red, opacity: 0.45)])
            pool.position = [0, -2.35, 0.8]
            e.addChild(body); e.addChild(eye); e.addChild(under); e.addChild(pool)
            strobes.append(eye)
            hazardNeon.append((eye, 5)); hazardGlows.append((under, 0.6)); hazardReflections.append((pool, 0.45))
            e.position.y = 2.4
            e.isEnabled = false
            obstacleGroup.addChild(e)
            drones.append(e)
            obstacles.append(Obstacle(entity: e, kind: .drone, halfWidth: 0.7, halfLength: 0.6, halfHeight: 0.35, centerY: 0))
        // tube obstacles: beams, pillars, half hatches
        let edge = materials.neon(Neon.orange, intensity: 3.5)
        for _ in 0..<2 {
            let e = Entity()
            let body = ModelEntity(mesh: .generateBox(size: [11.6, 0.5, 0.5]), materials: [materials.barrier])
            let a = ModelEntity(mesh: .generateBox(size: [11.6, 0.12, 0.56]), materials: [edge]); a.position = [0, 0.3, 0]
            let b = ModelEntity(mesh: .generateBox(size: [11.6, 0.12, 0.56]), materials: [edge]); b.position = [0, -0.3, 0]
            e.addChild(body); e.addChild(a); e.addChild(b)
            hazardNeon.append((a, 3.5)); hazardNeon.append((b, 3.5))
            e.isEnabled = false
            obstacleGroup.addChild(e)
            obstacles.append(Obstacle(entity: e, kind: .beam, halfWidth: 5.8, halfLength: 0.3, halfHeight: 0.35, centerY: 0))
        }
        for _ in 0..<2 {
            let e = Entity()
            let body = ModelEntity(mesh: .generateBox(size: [0.5, 11.6, 0.5]), materials: [materials.barrier])
            let a = ModelEntity(mesh: .generateBox(size: [0.12, 11.6, 0.56]), materials: [edge]); a.position = [0.3, 0, 0]
            let b = ModelEntity(mesh: .generateBox(size: [0.12, 11.6, 0.56]), materials: [edge]); b.position = [-0.3, 0, 0]
            e.addChild(body); e.addChild(a); e.addChild(b)
            hazardNeon.append((a, 3.5)); hazardNeon.append((b, 3.5))
            e.isEnabled = false
            obstacleGroup.addChild(e)
            obstacles.append(Obstacle(entity: e, kind: .pillar, halfWidth: 0.35, halfLength: 0.3, halfHeight: 5.8, centerY: 0))
        }
        do {
            let e = Entity()
            let body = ModelEntity(mesh: .generateBox(size: [12.4, 6.0, 0.4]), materials: [materials.facades[2]])
            let lip = ModelEntity(mesh: .generateBox(size: [12.4, 0.2, 0.5]), materials: [materials.neon(Neon.red, intensity: 4)])
            lip.position = [0, -3.0, 0]
            hazardNeon.append((lip, 4))
            let warn = ModelEntity(mesh: .generatePlane(width: 5, height: 2.5), materials: [materials.signs[7 % materials.signs.count]])
            warn.position = [0, 0, 0.25]
            e.addChild(body); e.addChild(lip); e.addChild(warn)
            for hx in [-4.0, 4.0] as [Float] {
                let hm = makeX(size: 3.2, thickness: 0.22)
                hm.position = [hx, 0, 0.28]
                e.addChild(hm)
            }
            e.isEnabled = false
            obstacleGroup.addChild(e)
            obstacles.append(Obstacle(entity: e, kind: .hatch, halfWidth: 6.2, halfLength: 0.25, halfHeight: 3.0, centerY: 0))
        }
        }
    }

    private func layoutObstacles(rows: Int, style: SegmentStyle, rng: inout SeededRNG) {
        for o in obstacles { o.active = false; o.entity.isEnabled = false }
        guard rows > 0, style != .fork, style != .branch else { return }
        if style == .tube {
            let cy = Self.tubeCenterY
            var usedT = Set<Int>()
            let rowZ: [Float] = [-12, -28]
            for r in 0..<min(rows, 2) {
                let roll = rng.float()
                let kind: ObstacleKind = roll < 0.4 ? .beam : (roll < 0.75 ? .pillar : .hatch)
                guard let idx = obstacles.indices.first(where: { !usedT.contains($0) && obstacles[$0].kind == kind }) else { continue }
                usedT.insert(idx)
                let o = obstacles[idx]
                o.active = true
                o.entity.isEnabled = true
                switch kind {
                case .beam:   o.entity.position = [0, cy + rng.pick([-3.5, -1.5, 1.0, 3.0]), rowZ[r]]
                case .pillar: o.entity.position = [rng.pick([-3.0, -1.0, 1.0, 3.0]), cy, rowZ[r]]
                default:      o.entity.position = [0, cy + (rng.chance(0.5) ? 3.0 : -3.0), rowZ[r]]
                }
                // a beam and a pillar together make a cross with four gaps
                if kind != .hatch && rng.chance(0.5), r == 0 {
                    let other: ObstacleKind = kind == .beam ? .pillar : .beam
                    if let j = obstacles.indices.first(where: { !usedT.contains($0) && obstacles[$0].kind == other }) {
                        usedT.insert(j)
                        let p = obstacles[j]
                        p.active = true
                        p.entity.isEnabled = true
                        p.entity.position = other == .beam ? [0, cy + rng.pick([-2.0, 2.0]), rowZ[r]] : [rng.pick([-2.0, 2.0]), cy, rowZ[r]]
                    }
                }
            }
            return
        }
        let lanes: [Float] = [-5.7, -1.9, 1.9, 5.7]
        var used = Set<Int>()
        let rowZ: [Float] = [-9, -21, -33]
        for r in 0..<min(rows, 3) {
            let count = rng.chance(0.4) ? 2 : 1
            var blocked = Set<Int>()
            while blocked.count < count { blocked.insert(Int(rng.next() % 4)) }
            for lane in blocked {
                let preferred: ObstacleKind = style == .tunnel ? .gate : (rng.chance(0.35) ? .drone : .block)
                guard let idx = obstacles.indices.first(where: { !used.contains($0) && obstacles[$0].kind == preferred })
                        ?? obstacles.indices.first(where: { !used.contains($0) && [.block, .gate, .drone].contains(obstacles[$0].kind) }) else { continue }
                used.insert(idx)
                let o = obstacles[idx]
                o.active = true
                o.entity.isEnabled = true
                o.entity.position = [lanes[lane] + rng.float(-0.3, 0.3), o.kind == .drone ? 2.4 : 0, rowZ[r] + rng.float(-2, 2)]
            }
        }
    }
}

// MARK: - Skyline

@MainActor
final class SkylineLayer {
    let root = Entity()
    private var towers: [Entity] = []
    private let wrapLength: Float = 260
    private let nearZ: Float = -140

    init(materials: SceneMaterials) {
        var rng = SeededRNG(seed: 555)
        for i in 0..<22 {
            let side: Float = i % 2 == 0 ? -1 : 1
            let w = rng.float(14, 40), d = rng.float(14, 40), h = rng.float(70, 230)
            var mat = materials.skyline
            mat.textureCoordinateTransform = .init(offset: .zero, scale: SIMD2(w / 12, h / 12), rotation: 0)
            let t = ModelEntity(mesh: .generateBox(width: w, height: h, depth: d), materials: [mat])
            t.position = [side * rng.float(30, 170), h / 2 - 2, nearZ - rng.float(0, wrapLength)]
            root.addChild(t)
            towers.append(t)
            if rng.chance(0.5) {
                let tip = ModelEntity(mesh: .generateBox(size: [1.2, 1.2, 1.2]), materials: [materials.neon(rng.chance(0.5) ? Neon.red : Neon.cyan, intensity: 3)])
                tip.position = [0, h / 2 + 0.6, 0]
                t.addChild(tip)
            }
        }
    }

    func advance(_ travel: Float) {
        for t in towers {
            t.position.z += travel
            if t.position.z > nearZ { t.position.z -= wrapLength }
        }
    }
}

// MARK: - Scroller

/// Owns the ordered ring of segments, feeds them blocks from the track program,
/// lays out curves as lateral offsets, and slides the world so the road centre
/// at the player's position stays at x = 0.
@MainActor
final class WorldScroller {
    let root = Entity()
    let segmentLength: Float = 40
    let segmentCount = 8
    private(set) var segments: [RoadSegment] = []   // near -> far
    let skyline: SkylineLayer
    private let program: TrackProgram
    private var settings = FXSettings()
    private let recycleZ: Float = 60
    private let startZ: Float = 20
    private var lastRecycledStyle: SegmentStyle? = nil

    /// Lateral shift the road centre made at the player's z during the last advance.
    private(set) var lastShift: Float = 0
    private(set) var playerOffset: Float = 0
    private(set) var lastDecision: String? = nil

    // Fork: the side is sampled from `forkLead` metres before the split and locked when the
    // split passes; the road's divergence ramps in over `forkRamp` metres of travel so nothing
    // ahead of the player ever jumps sideways.
    private var forkTarget: Float = 0          // -1 tunnel, +1 skyway, 0 undecided
    private var forkBlend: Float = 0
    private var forkLocked = false
    private var forkStyled: Float = 0
    static let forkLead: Float = 30
    static let forkRamp: Float = 24
    /// Lead-in distances (metres) over which the section constraints ease in and out.
    static let tubeLead: Float = 24
    static let enclosureLead: Float = 20

    var currentBlock: TrackBlock { segmentAt(worldZ: 0)?.block ?? .city() }
    /// How strongly a sliding road tugs the vehicle: the fork diverges the road itself, so barely.
    var tugFactor: Float { currentBlock.style == .fork ? 0.12 : 0.5 }
    /// Conduit geometry (constant) and how much of it applies right now (0 open road, 1 inside).
    static let tubeGeometry: (centerY: Float, radius: Float) = (RoadSegment.tubeCenterY, RoadSegment.tubeRadius - 0.7)
    private(set) var tubeBlend: Float = 0
    /// 0 in the open, 1 inside a tunnel or conduit, eased over `enclosureLead` metres.
    private(set) var enclosure: Float = 0
    /// Past the fork's nose the V divider is a wall: (side the player is on, minimum |x| from the
    /// road centre on that side). The vehicle scrapes along it instead of passing through.
    private(set) var wedgeLimit: (side: Float, limit: Float)? = nil

    init(materials: SceneMaterials, settings: FXSettings, program: TrackProgram = TrackProgram()) {
        root.name = "WorldRoot"
        self.settings = settings
        self.program = program
        skyline = SkylineLayer(materials: materials)
        root.addChild(skyline.root)
        var prev: RoadSegment? = nil
        for i in 0..<segmentCount {
            let seg = RoadSegment(index: i, length: segmentLength, materials: materials)
            seg.root.position.z = startZ - Float(i) * segmentLength
            root.addChild(seg.root)
            segments.append(seg)
            assign(seg, after: prev)
            prev = seg
        }
        updateNeighbours()
        updateSectionBlends()
    }

    private func assign(_ seg: RoadSegment, after prev: RoadSegment?) {
        let block = program.next()
        seg.startOffset = prev?.endOffset ?? 0
        seg.endOffset = seg.startOffset + (block.style == .fork ? 0 : block.curvature)
        seg.configure(block: block, settings: settings)
        seg.placeTransform()
        if block.style == .fork { forkTarget = 0; forkBlend = 0; forkLocked = false; forkStyled = 0 }
    }

    private func updateNeighbours() {
        for (i, seg) in segments.enumerated() {
            let prev: SegmentStyle? = i > 0 ? segments[i - 1].block.style : lastRecycledStyle
            let next: SegmentStyle? = i + 1 < segments.count ? segments[i + 1].block.style : nil
            seg.setNeighbours(prev: prev, next: next)
        }
    }

    func segmentAt(worldZ z: Float) -> RoadSegment? {
        segments.first { $0.root.position.z >= z && $0.root.position.z - segmentLength < z }
    }

    /// Road centre offset at a world z (piecewise per segment).
    func offset(atWorldZ z: Float) -> Float {
        guard let seg = segmentAt(worldZ: z) else { return playerOffset }
        let t = (seg.root.position.z - z) / segmentLength
        return seg.offset(at: t)
    }

    func advance(_ travel: Float, playerX: Float, time: Float) {
        let loop = Float(segmentCount) * segmentLength
        for seg in segments { seg.root.position.z += travel }
        // recycle from the near end; keep the ring ordered near -> far
        var recycled = false
        while let first = segments.first, first.root.position.z > recycleZ {
            first.root.position.z -= loop
            lastRecycledStyle = first.block.style
            first.recycle()
            segments.removeFirst()
            assign(first, after: segments.last)
            segments.append(first)
            recycled = true
        }
        if recycled { updateNeighbours() }
        updateFork(travel: travel, playerX: playerX)
        let newOffset = offset(atWorldZ: 0)
        lastShift = newOffset - playerOffset
        playerOffset = newOffset
        root.position.x = -newOffset
        for seg in segments.prefix(3) { seg.animate(time: time) }
        skyline.advance(travel * 0.22)
        updateSectionBlends()
    }

    private func updateFork(travel: Float, playerX: Float) {
        guard let fi = segments.firstIndex(where: { $0.block.style == .fork }) else { return }
        let fork = segments[fi]
        let splitZ = fork.root.position.z - segmentLength * 0.25      // where the road starts to diverge
        if !forkLocked {
            if splitZ >= -Self.forkLead {
                forkTarget = playerX >= 0 ? 1 : -1
                if forkStyled != forkTarget { restyleBranches(after: fi, right: forkTarget > 0); forkStyled = forkTarget }
            }
            if splitZ >= 0 { forkLocked = true; lastDecision = forkTarget > 0 ? "skyway" : "tunnel" }
        }
        guard forkTarget != 0, forkBlend != forkTarget else { return }
        let step = travel / Self.forkRamp
        forkBlend = forkBlend < forkTarget ? min(forkTarget, forkBlend + step) : max(forkTarget, forkBlend - step)
        relayout(from: fi)
    }

    /// The four placeholder segments after the fork become the chosen branch.
    private func restyleBranches(after fi: Int, right: Bool) {
        let branch = right ? TrackProgram.rightBranch : TrackProgram.leftBranch
        var b = 0
        for seg in segments[(fi + 1)...] where b < branch.count {
            guard [.branch, .tunnel, .elevated].contains(seg.block.style) else { break }
            seg.configure(block: branch[b], settings: settings)
            b += 1
        }
        relayout(from: fi)
        updateNeighbours()
    }

    /// Re-place the fork and everything beyond it for the current divergence blend.
    private func relayout(from fi: Int) {
        let fork = segments[fi]
        fork.endOffset = fork.startOffset + forkBlend * RoadSegment.forkDiverge
        fork.placeTransform()
        var prev = fork
        for (j, seg) in segments[(fi + 1)...].enumerated() {
            let extra: Float = j == 0 ? forkBlend * 3 : 0      // the first branch segment keeps curving away
            seg.startOffset = prev.endOffset
            seg.endOffset = seg.startOffset + seg.block.curvature + extra
            seg.placeTransform()
            prev = seg
        }
    }

    /// 1 inside a segment of one of `styles`, easing in over `lead` metres before its mouth and
    /// out over the last `lead` metres before its exit.
    private func blend(for styles: Set<SegmentStyle>, lead: Float) -> Float {
        guard let ci = segments.firstIndex(where: { $0.root.position.z >= 0 && $0.root.position.z - segmentLength < 0 }) else { return 0 }
        let cur = segments[ci]
        let next: RoadSegment? = ci + 1 < segments.count ? segments[ci + 1] : nil
        if styles.contains(cur.block.style) {
            if let next, !styles.contains(next.block.style) {
                return clamp01((segmentLength - cur.root.position.z) / lead)
            }
            return 1
        }
        if let next, styles.contains(next.block.style) {
            return clamp01(1 + next.root.position.z / lead)
        }
        return 0
    }

    private func updateSectionBlends() {
        tubeBlend = blend(for: [.tube], lead: Self.tubeLead)
        enclosure = blend(for: [.tube, .tunnel], lead: Self.enclosureLead)
        wedgeLimit = nil
        if forkTarget != 0, let fork = segmentAt(worldZ: 0), fork.block.style == .fork {
            let t = fork.root.position.z / segmentLength            // 0 near edge ... 1 far edge
            let noseT: Float = 9 / segmentLength
            if t > noseT {
                let wedgeHalf = RoadSegment.forkHalfSpread * min(1, (t - noseT) / (31 / segmentLength))
                let roadRel = fork.offset(at: t) - fork.startOffset  // how far the road centre has slid toward the branch
                wedgeLimit = (forkTarget, wedgeHalf + 1.3 - roadRel * forkTarget)
            }
        }
    }

    /// Active obstacles in the two nearest segments, with world-space positions.
    func nearbyObstacles(segments count: Int = 2) -> [(Obstacle, SIMD3<Float>)] {
        var out: [(Obstacle, SIMD3<Float>)] = []
        for seg in segments.prefix(count) {
            for o in seg.obstacles where o.active {
                out.append((o, o.entity.position(relativeTo: nil)))
            }
        }
        return out
    }

    func apply(_ s: FXSettings) {
        settings = s
        for seg in segments { seg.apply(s) }
        skyline.root.isEnabled = s.buildings
    }
}
