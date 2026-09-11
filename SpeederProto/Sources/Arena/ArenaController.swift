import Foundation
import RealityKit
import simd

/// The Grid game loop: cycles, trails, collision, grinding, jumps, pickups, the AI and
/// the crash sequence. `GameController` feeds it input and reads its outputs for the
/// camera, post pass and HUD.
@MainActor
final class ArenaController {
    enum Phase { case countdown(Float), running, crashed(Float) }
    enum Pickup: String { case phase = "PHASE", pulse = "PULSE" }

    let root = Entity()
    let world: ArenaWorld
    let trails: TrailSystem
    let player: LightCycle
    let opponent: LightCycle
    private var renderers: [TrailRenderer] = []
    private let playerVehicle: SpeederController
    private var opponentVehicle: SpeederController?
    private let materials: SceneMaterials
    private var settings: FXSettings
    private let ai: ArenaAI
    private(set) var phase: Phase = .countdown(1.2)
    private var runTime: Float = 0
    private var time: Float = 0

    // colour roles: player cyan/white family, opponent orange/amber family, hazards lime
    static let playerColor = SIMD3<Float>(0.12, 0.72, 1.0)
    static let opponentColor = SIMD3<Float>(1.0, 0.42, 0.06)
    static let hazardColor = SIMD3<Float>(0.55, 1.0, 0.12)
    static let pickupColor = SIMD3<Float>(0.85, 0.7, 1.0)

    // meters (0...1)
    private(set) var energy: Float = 0.6
    private(set) var edge: Float = 1
    private(set) var grind: Float = 0
    private var speedBonus: Float = 0
    private var opponentBonus: Float = 0
    private var lastNose: [SIMD2<Float>] = [.zero, .zero]
    private var emitBlock: [SIMD3<Float>?] = [nil, nil]     // pivot while the tail has not passed it yet
    private var wasAirborne = [false, false]
    private var opponentRespawn: Float = 0
    private var opponentDead = false

    // outputs
    private(set) var flash: Float = 0
    private(set) var shake: Float = 0
    private(set) var speedNorm: Float = 0
    private(set) var cameraOrbit: (center: SIMD3<Float>, progress: Float)? = nil
    private(set) var stateText = "READY"
    private(set) var wins = 0
    private(set) var losses = 0
    private(set) var heldPickup: Pickup? = nil
    private var phaseTimer: Float = 0
    var rumble: ((Float, Float) -> Void)? = nil
    /// Held by a mission briefing: nothing moves, the countdown waits.
    var paused = false

    // fx
    private let sparks = Entity()
    private var sparkTimer: Float = 0
    private let arc: ModelEntity
    private let derez = Entity()
    private let derezLight = PointLight()
    private var derezTimer: Float = 0
    private var shards: [(ModelEntity, SIMD3<Float>, simd_quatf)] = []
    private var shardTimer: Float = 0
    private var pulseOrigin: (owner: Int, s: Float, t: Float)? = nil
    private var pulseCut: (owner: Int, s: Float, t: Float)? = nil
    private struct PickupSlot { let entity: Entity; var kind: Pickup; var pos: SIMD2<Float>; var active: Bool; var timer: Float }
    private var pickups: [PickupSlot] = []
    private var rng = SeededRNG(seed: 99)

    init(materials: SceneMaterials, settings: FXSettings, vehicle: SpeederController) {
        self.materials = materials
        self.settings = settings
        playerVehicle = vehicle
        world = ArenaWorld(materials: materials, halfSize: 110)
        root.addChild(world.root)
        trails = TrailSystem(halfSize: world.halfSize)
        let hazards = trails.addTrail(color: Self.hazardColor)
        hazards.isStatic = true
        Self.registerHazards(hazards, terrain: world.terrain, trails: trails)
        let playerTrail = trails.addTrail(color: Self.playerColor)
        let opponentTrail = trails.addTrail(color: Self.opponentColor)
        for t in [hazards, playerTrail, opponentTrail] {
            let r = TrailRenderer(trail: t, library: materials.library)
            r.isStatic = t === hazards
            root.addChild(r.root)
            renderers.append(r)
        }
        if let give = ProcessInfo.processInfo.environment["SPEEDER_ARENA_GIVE"] { heldPickup = Pickup(rawValue: give.uppercased()) }
        let start = Self.startOverride() ?? (SIMD3<Float>(-world.halfSize * 0.25, 0, world.halfSize * 0.6), 0)
        player = LightCycle(id: 1, position: start.0, heading: start.1, speed: 0)
        opponent = LightCycle(id: 2, position: [world.halfSize * 0.25, 0, -world.halfSize * 0.6], heading: .pi, speed: 0)
        ai = ArenaAI(cycleID: 2, heading: .pi)
        lastNose = [player.nose, opponent.nose]

        // sparks + arc for grinding
        var e = ParticleEmitterComponent()
        e.emitterShape = .sphere
        e.emitterShapeSize = [0.25, 0.25, 0.25]
        e.birthLocation = .volume
        e.emissionDirection = [0, 1, 0]
        e.speed = 7
        e.speedVariation = 4
        e.mainEmitter.birthRate = 0
        e.mainEmitter.lifeSpan = 0.4
        e.mainEmitter.lifeSpanVariation = 0.2
        e.mainEmitter.size = 0.05
        e.mainEmitter.sizeVariation = 0.03
        e.mainEmitter.stretchFactor = 5
        e.mainEmitter.acceleration = [0, -14, 0]
        e.mainEmitter.spreadingAngle = 1.4
        e.mainEmitter.blendMode = .additive
        e.mainEmitter.opacityCurve = .linearFadeOut
        e.mainEmitter.color = .evolving(start: .single(.rgb(1.0, 0.95, 0.8, 1.0)), end: .single(.rgb(0.4, 0.8, 1.0, 0.0)))
        e.isEmitting = true
        sparks.components.set(e)
        root.addChild(sparks)
        arc = ModelEntity(mesh: .generatePlane(width: 1, height: 0.25), materials: [materials.neon(SIMD3(0.8, 0.95, 1.0), intensity: 8)])
        arc.isEnabled = false
        root.addChild(arc)

        // derez burst
        var d = ParticleEmitterComponent()
        d.emitterShape = .box
        d.emitterShapeSize = [2.0, 1.2, 4.0]
        d.birthLocation = .volume
        d.birthDirection = .normal
        d.speed = 9
        d.speedVariation = 6
        d.mainEmitter.birthRate = 2400
        d.mainEmitter.lifeSpan = 1.4
        d.mainEmitter.lifeSpanVariation = 0.6
        d.mainEmitter.size = 0.11
        d.mainEmitter.sizeVariation = 0.06
        d.mainEmitter.stretchFactor = 1.5
        d.mainEmitter.dampingFactor = 2
        d.mainEmitter.acceleration = [0, -5, 0]
        d.mainEmitter.blendMode = .additive
        d.mainEmitter.opacityCurve = .linearFadeOut
        d.mainEmitter.color = .evolving(start: .single(.rgb(1.0, 1.0, 1.0, 1.0)), end: .single(.rgb(Self.playerColor, 0.0)))
        d.isEmitting = false
        derez.components.set(d)
        derezLight.light.color = .rgb(0.8, 0.95, 1.0)
        derezLight.light.intensity = 160000
        derezLight.light.attenuationRadius = 22
        derezLight.isEnabled = false
        derez.addChild(derezLight)
        root.addChild(derez)
        let shardMat = materials.neon(SIMD3(0.8, 0.95, 1.0), intensity: 4)
        for i in 0..<14 {
            let s = ModelEntity(mesh: .generateBox(size: [0.5, 0.06, 0.25 + Float(i % 3) * 0.2]), materials: [shardMat])
            s.isEnabled = false
            root.addChild(s)
            shards.append((s, .zero, simd_quatf(angle: 0, axis: [0, 1, 0])))
        }
        buildPickups()
        apply(settings)
    }

    func attachOpponent(_ v: SpeederController) {
        opponentVehicle = v
        v.tint(Self.opponentColor, materials: materials)
        root.addChild(v.root)
    }

    func apply(_ s: FXSettings) {
        settings = s
        world.apply(s)
        for r in renderers { r.reflections = s.reflections }
        sparks.isEnabled = s.particles
        derez.isEnabled = s.particles
        for p in pickups { p.entity.isEnabled = p.active }
        opponentVehicle?.root.isEnabled = s.opponent && !opponentDead
    }

    private var trailMaxLength: Float { [220, 420, 1e9][max(0, min(2, settings.trailLength))] }
    private var snapMode: Bool { settings.steeringMode == 1 }

    // MARK: - Pickups

    private func buildPickups() {
        let m = materials.neon(Self.pickupColor, intensity: 4)
        for i in 0..<2 {
            let e = Entity()
            let core = ModelEntity(mesh: .generateBox(size: [0.9, 0.9, 0.9]), materials: [m])
            core.orientation = simd_quatf(angle: .pi / 4, axis: [1, 0, 0]) * simd_quatf(angle: .pi / 4, axis: [0, 0, 1])
            core.position = [0, 1.6, 0]
            e.addChild(core)
            // flat quads on an entity that is repositioned later can be culled for good (see CLAUDE.md); tilt them a hair
            let halo = ModelEntity(mesh: .generatePlane(width: 3.2, height: 3.2), materials: [materials.glow(Self.pickupColor, opacity: 0.5)])
            halo.position = [0, 1.6, 0]
            halo.orientation = simd_quatf(angle: 0.03, axis: [1, 0, 0])
            e.addChild(halo)
            let pool = ModelEntity(mesh: .generatePlane(width: 4, depth: 4), materials: [materials.glow(Self.pickupColor, opacity: 0.3)])
            pool.position = [0, 0.04, 0]
            pool.orientation = simd_quatf(angle: 0.01, axis: [1, 0, 0])
            e.addChild(pool)
            let pillar = ModelEntity(mesh: .generateBox(size: [0.12, 8, 0.12]), materials: [materials.neon(Self.pickupColor, intensity: 2)])
            pillar.position = [0, 4, 0]
            e.addChild(pillar)
            world.pickupGroup.addChild(e)
            pickups.append(PickupSlot(entity: e, kind: i == 0 ? .phase : .pulse, pos: .zero, active: false, timer: 0.5 + Float(i) * 3))
        }
    }

    private func spawnPickup(_ i: Int) {
        let h = world.halfSize * 0.7
        var p = SIMD2<Float>(rng.float(-h, h), rng.float(-h, h))
        // keep clear of walls
        for _ in 0..<8 {
            let g = topSurface(p)
            if trails.nearest(to: p, radius: 6, yBand: g...(g + 3), ignoreOwner: nil) == nil && simd_length(p - player.xz) > 25 { break }
            p = SIMD2<Float>(rng.float(-h, h), rng.float(-h, h))
        }
        pickups[i].pos = p
        pickups[i].active = true
        pickups[i].entity.position = [p.x, topSurface(p), p.y]
        pickups[i].entity.isEnabled = true
    }

    // MARK: - Round control

    /// Static walls (hazard walls, deck rails, ramp rails, columns) live in trail 0.
    private static func registerHazards(_ hazards: Trail, terrain: ArenaTerrain, trails: TrailSystem) {
        for strand in terrain.strands {
            for p in strand.points { _ = hazards.append(p, height: strand.wallHeight, floor: p.y) }
            hazards.breakStrand()
        }
        for i in 0...hazards.newestIndex where hazards.segment(global: i)?.live == true {
            trails.hash.insert(SegRef(trail: 0, index: i), hazards.segment(global: i)!)
        }
    }

    /// Ground under a point for a body at height y (see `ArenaTerrain.height`).
    private var ground: (SIMD2<Float>, Float) -> Float { { [terrain = world.terrain] p, y in terrain.height(at: p, below: y) } }
    /// Topmost surface (pickups, spawns).
    private var topSurface: (SIMD2<Float>) -> Float { { [terrain = world.terrain] p in terrain.height(at: p) } }

    private func startRound() {
        trails.clearAll()
        Self.registerHazards(trails.trails[0], terrain: world.terrain, trails: trails)
        let start = Self.startOverride() ?? (SIMD3<Float>(-world.halfSize * 0.25, 0, world.halfSize * 0.6), 0)
        player.reset(position: start.0, heading: start.1)
        opponent.reset(position: [world.halfSize * 0.25, 0, -world.halfSize * 0.6], heading: .pi)
        ai.reset(heading: .pi)
        lastNose = [player.nose, opponent.nose]
        emitBlock = [nil, nil]
        wasAirborne = [false, false]
        energy = 0.6; edge = 1; grind = 0; speedBonus = 0; opponentBonus = 0
        heldPickup = ProcessInfo.processInfo.environment["SPEEDER_ARENA_GIVE"].flatMap { Pickup(rawValue: $0.uppercased()) }; phaseTimer = 0
        opponentDead = false
        opponentVehicle?.root.isEnabled = settings.opponent
        playerVehicle.setVisible(true)
        cameraOrbit = nil
        pulseOrigin = nil
        runTime = 0
        for i in pickups.indices { pickups[i].active = false; pickups[i].entity.isEnabled = false; pickups[i].timer = 1.5 + Float(i) * 4 }
        phase = .countdown(demo ? 0.3 : 1.2)
        stateText = "READY"
    }

    /// SPEEDER_ARENA_START=x,z,heading positions the player for scripted captures.
    private static func startOverride() -> (SIMD3<Float>, Float)? {
        guard let s = ProcessInfo.processInfo.environment["SPEEDER_ARENA_START"] else { return nil }
        let v = s.split(separator: ",").compactMap { Float($0) }
        guard v.count == 3 else { return nil }
        return (SIMD3<Float>(v[0], 0, v[1]), v[2])
    }
    var demo = false

    // MARK: - Update

    func update(dt rawDt: Float, time: Float, input: CycleInput, aiInput: CycleInput? = nil) {
        self.time = time
        var dt = rawDt
        if paused { world.animate(time: time); pose(); return }
        flash = max(0, flash - dt * 3.0)
        shake = max(0, shake - dt * 2.5)
        world.animate(time: time)
        updateFX(dt: dt)

        switch phase {
        case .countdown(let t):
            let left = t - dt
            phase = left <= 0 ? .running : .countdown(left)
            stateText = left <= 0 ? "" : "READY"
            if left <= 0 { player.speed = player.baseSpeed; opponent.speed = opponent.baseSpeed }
            pose()
            return
        case .crashed(let t):
            let tt = t + dt
            dt *= 0.35                                            // slow-motion orbit
            cameraOrbit = (derez.position, clamp01(tt / 3.2))
            if tt > 3.4 { startRound(); return }
            phase = .crashed(tt)
            // the opponent keeps riding in slow motion
            if settings.opponent && !opponentDead {
                let ai = aiInput ?? self.ai.decide(dt: dt, cycle: opponent, trails: trails, player: player, snapMode: snapMode)
                stepCycle(opponent, input: ai, dt: dt, bonus: 0)
            }
            pose()
            return
        case .running:
            break
        }
        runTime += dt

        // --- player
        var pin = input
        if pin.boost && energy <= 0.02 { pin.boost = false }
        if pin.boost { energy = max(0, energy - dt * 0.22) } else { energy = min(1, energy + dt * 0.03) }
        if pin.jump && player.airborne { pin.jump = false }
        stepCycle(player, input: pin, dt: dt, bonus: settings.grinding ? speedBonus : 0)
        // --- opponent
        if settings.opponent && !opponentDead {
            let ai = aiInput ?? self.ai.decide(dt: dt, cycle: opponent, trails: trails, player: player, snapMode: snapMode)
            stepCycle(opponent, input: ai, dt: dt, bonus: opponentBonus)
        } else if opponentDead {
            opponentRespawn -= dt
            if opponentRespawn <= 0 { respawnOpponent() }
        }

        // --- collisions
        if let hit = collide(player) {
            if heldPickup == nil && phaseTimer > 0 && !hit.boundary {
                // phase: pass through one wall (already consumed)
                phaseTimer = 0
                flash = max(flash, 0.25)
            } else if let deflected = tryDeflect(player, hit: hit) {
                _ = deflected
            } else {
                crashPlayer(at: hit)
                return
            }
        }
        if settings.opponent && !opponentDead, let hit = collide(opponent) {
            crashOpponent(at: hit)
        }

        // --- grinding / edge (player only; the AI has no rubber)
        updateGrinding(dt: dt)
        if settings.grinding {
            let near = trails.nearest(to: opponent.xz, radius: 3.5, yBand: opponent.yBand, ignoreOwner: opponent.id)
            let g = near.map { clamp01(1 - max(0, $0.distance - opponent.halfWidth) / 3.0) * (abs(simd_dot($0.dir, opponent.forward2)) > 0.92 ? 1 : 0) } ?? 0
            opponentBonus = damp(opponentBonus, g * 16, 3, dt)
        }

        // --- trails
        trails.decay(maxLength: trailMaxLength)
        if let cut = pulseCut, time - cut.t > 1.2 { pulseCut = nil }

        // --- pickups
        updatePickups(dt: dt, action: input.action)
        phaseTimer = max(0, phaseTimer - dt)

        speedNorm = clamp01((player.speed - 10) / 60)
        pose()
    }

    private func stepCycle(_ c: LightCycle, input: CycleInput, dt: Float, bonus: Float) {
        let k = c.id - 1
        let pivot = c.position
        let corner = c.step(dt: dt, input: input, snapMode: snapMode, speedBonus: bonus, ground: ground)
        // jump rule: elevated trail follows the bike; gap rule breaks the strand while airborne
        let gapRule = settings.jumpRule == 1
        if c.airborne && !wasAirborne[k] && gapRule { trails.breakStrand(owner: c.id) }
        wasAirborne[k] = c.airborne
        if corner {
            // extend the old line to the pivot, then hold emission until the tail has passed it
            trails.emit(owner: c.id, position: [pivot.x, pivot.y, pivot.z], height: c.trailHeight, floor: ground(SIMD2(pivot.x, pivot.z), c.position.y), force: true)
            emitBlock[k] = pivot
            shake = max(shake, 0.12)
        }
        if let block = emitBlock[k] {
            if simd_dot(SIMD2<Float>(c.tail.x - block.x, c.tail.z - block.z), c.forward2) > 0 { emitBlock[k] = nil }
        }
        if emitBlock[k] == nil && !(c.airborne && gapRule) {
            let t = c.tail
            trails.emit(owner: c.id, position: [t.x, c.position.y, t.z], height: c.trailHeight, floor: ground(SIMD2(t.x, t.z), c.position.y))
        }
        // keep the cycle inside the arena (the boundary test below decides whether that costs a life)
        let h = world.halfSize - 0.2
        c.position.x = max(-h, min(h, c.position.x))
        c.position.z = max(-h, min(h, c.position.z))
    }

    private func collide(_ c: LightCycle) -> TrailHit? {
        let k = c.id - 1
        let prev = lastNose[k]
        let nose = c.nose
        lastNose[k] = nose
        let h = world.halfSize
        if abs(nose.x) >= h || abs(nose.y) >= h {
            let nx: Float = abs(nose.x) >= h ? (nose.x > 0 ? -1 : 1) : 0
            let nz: Float = abs(nose.y) >= h ? (nose.y > 0 ? -1 : 1) : 0
            let n = simd_normalize(SIMD2<Float>(nx, nz))
            return TrailHit(ref: SegRef(trail: -1, index: 0), t: 0, point: nose, wallDir: SIMD2<Float>(-n.y, n.x), normal: n, boundary: true)
        }
        return trails.sweep(from: prev, to: nose, yBand: c.yBand, ignoreOwner: c.id, ignoreNewest: 5)
    }

    /// Armagetron-style rubber: a shallow contact with edge left slides along the wall instead of killing.
    private func tryDeflect(_ c: LightCycle, hit: TrailHit) -> Bool? {
        let along = simd_dot(c.forward2, hit.wallDir)
        guard abs(along) > 0.86, edge > 0.3 else { return nil }
        edge = max(0, edge - 0.45)
        let wall = along > 0 ? hit.wallDir : -hit.wallDir
        c.heading = atan2(-wall.x, -wall.y)
        // push the body clear of the wall
        let push = hit.normal * (c.halfWidth + 0.35)
        let base = hit.point - c.forward2 * c.noseOffset
        c.position.x = base.x + push.x
        c.position.z = base.y + push.y
        lastNose[c.id - 1] = c.nose
        c.speed *= 0.82
        shake = max(shake, 0.35)
        flash = max(flash, 0.2)
        emitSparks(at: [hit.point.x, 0.8, hit.point.y], rate: 1200, duration: 0.15)
        rumble?(0.7, 0.9)
        return true
    }

    private func crashPlayer(at hit: TrailHit) {
        losses += 1
        let p = player.position + [0, 0.9, 0]
        derezAt(p, color: Self.playerColor)
        playerVehicle.setVisible(false)
        player.alive = false
        flash = 1.0
        shake = 1.0
        rumble?(1.0, 0.3)
        pulseOrigin = (player.id, trails.trails[player.id].headS, time)
        cameraOrbit = (p, 0)
        phase = .crashed(0)
        stateText = hit.boundary ? "DEREZZED - BOUNDARY" : (hit.ref.trail == player.id ? "DEREZZED - OWN TRAIL" : (hit.ref.trail == 0 ? "DEREZZED - HAZARD" : "DEREZZED - OPPONENT TRAIL"))
    }

    private func crashOpponent(at hit: TrailHit) {
        wins += 1
        opponentDead = true
        opponentRespawn = 4.0
        derezAt(opponent.position + [0, 0.9, 0], color: Self.opponentColor)
        opponentVehicle?.root.isEnabled = false
        pulseOrigin = (opponent.id, trails.trails[opponent.id].headS, time)
        shake = max(shake, 0.3)
        flash = max(flash, 0.3)
        stateText = "OPPONENT DEREZZED"
        rumble?(0.6, 0.6)
    }

    private func respawnOpponent() {
        // find an open spot far from the player
        var best = SIMD2<Float>(0, 0), bestOpen: Float = -1
        for _ in 0..<10 {
            let h = world.halfSize * 0.75
            let p = SIMD2<Float>(rng.float(-h, h), rng.float(-h, h))
            guard simd_length(p - player.xz) > 45 else { continue }
            let heading = rng.float(0, 2 * .pi)
            let dir = SIMD2<Float>(-sin(heading), -cos(heading))
            let g = topSurface(p)
            let open = trails.openDistance(from: p, dir: dir, maxDistance: 80, yBand: (g + 0.15)...(g + 2), ignoreOwner: nil)
            if open > bestOpen { bestOpen = open; best = p; opponent.heading = heading }
        }
        opponent.reset(position: [best.x, topSurface(best), best.y], heading: opponent.heading)
        opponent.speed = opponent.baseSpeed
        ai.reset(heading: opponent.heading)
        trails.trails[opponent.id].reset()
        // dead segments must leave the hash: cheapest is a rebuild of that trail's entries
        rebuildHash()
        lastNose[1] = opponent.nose
        emitBlock[1] = nil
        opponentDead = false
        opponentVehicle?.root.isEnabled = settings.opponent
        stateText = ""
    }

    private func rebuildHash() {
        trails.hash.removeAll()
        for t in trails.trails {
            guard t.newestIndex >= t.firstAlive, t.count > 0 else { continue }
            for i in t.firstAlive...t.newestIndex {
                if let seg = t.segment(global: i), seg.live { trails.hash.insert(SegRef(trail: t.owner, index: i), seg) }
            }
        }
    }

    // MARK: - Grinding

    private func updateGrinding(dt: Float) {
        guard settings.grinding else { grind = 0; speedBonus = 0; arc.isEnabled = false; return }
        let near = trails.nearest(to: player.xz, radius: 4.5, yBand: player.yBand, ignoreOwner: player.id, ignoreNewest: 6)
        var g: Float = 0
        if let near {
            let clearance = max(0, near.distance - player.halfWidth)
            let parallel = abs(simd_dot(near.dir, player.forward2))
            if parallel > 0.90 {
                g = pow(clamp01(1 - clearance / 3.2), 1.4) * clamp01((parallel - 0.90) / 0.06)
            }
            // edge: nearly touching drains, distance recharges
            if clearance < 0.45 {
                edge = max(0, edge - dt * 1.4 * (1 - clearance / 0.45))
                if edge <= 0 {
                    crashPlayer(at: TrailHit(ref: near.ref, t: 0, point: near.point, wallDir: near.dir, normal: .zero, boundary: false))
                    return
                }
            } else if clearance > 1.2 {
                edge = min(1, edge + dt * 0.15)
            }
            // sparks and arc escalate with proximity
            if g > 0.05 {
                let side = SIMD2<Float>(near.point - player.xz)
                let sparkPos = SIMD3<Float>(player.position.x + side.x * 0.8, player.position.y + 0.5, player.position.z + side.y * 0.8)
                emitSparks(at: sparkPos, rate: 150 + g * g * 1400, duration: 0.05)
                if clearance < 1.6 {
                    arc.isEnabled = Int(time * 37) % 3 != 0
                    let a = SIMD3<Float>(player.position.x, player.position.y + 0.9, player.position.z)
                    let b = SIMD3<Float>(near.point.x, player.position.y + 0.9 + sin(time * 53) * 0.3, near.point.y)
                    let mid = (a + b) / 2
                    arc.position = mid
                    arc.scale = [max(0.3, simd_length(b - a)), 0.6 + g * 0.8, 1]
                    let dir = simd_normalize(b - a)
                    arc.orientation = simd_quatf(from: [1, 0, 0], to: dir)
                } else { arc.isEnabled = false }
            } else { arc.isEnabled = false }
        } else {
            edge = min(1, edge + dt * 0.15)
            arc.isEnabled = false
        }
        grind = damp(grind, g, 6, dt)
        speedBonus = damp(speedBonus, g * 20, 2.5, dt)
        if g > 0.1 { energy = min(1, energy + dt * g * 0.35) }
    }

    // MARK: - Pickups

    private func updatePickups(dt: Float, action: Bool) {
        for i in pickups.indices {
            if !pickups[i].active {
                pickups[i].timer -= dt
                if pickups[i].timer <= 0 { spawnPickup(i) }
                continue
            }
            pickups[i].entity.children[0].orientation = simd_quatf(angle: time * 1.6, axis: [0, 1, 0]) * simd_quatf(angle: .pi / 4, axis: [1, 0, 0])
            pickups[i].entity.children[0].position.y = 1.6 + sin(time * 2.5 + Float(i)) * 0.25
            if simd_length(pickups[i].pos - player.xz) < 2.6 && abs(pickups[i].entity.position.y - player.position.y) < 3 && heldPickup == nil {
                heldPickup = pickups[i].kind
                pickups[i].active = false
                pickups[i].entity.isEnabled = false
                pickups[i].timer = 9
                flash = max(flash, 0.15)
                rumble?(0.4, 0.8)
            }
        }
        if action, let held = heldPickup {
            heldPickup = nil
            switch held {
            case .phase:
                phaseTimer = 5.0
            case .pulse:
                let s = trails.trails[player.id].headS
                trails.cutNewest(owner: player.id, length: 60)
                renderers[player.id].invalidate(from: trails.trails[player.id].firstAlive)
                pulseCut = (player.id, s, time)
                shake = max(shake, 0.25)
            }
        }
    }

    // MARK: - FX

    private func emitSparks(at p: SIMD3<Float>, rate: Float, duration: Float) {
        sparks.position = p
        if var e = sparks.components[ParticleEmitterComponent.self] {
            e.mainEmitter.birthRate = rate
            sparks.components.set(e)
        }
        sparkTimer = max(sparkTimer, duration)
    }

    private func derezAt(_ p: SIMD3<Float>, color: SIMD3<Float>) {
        derez.position = p
        if var d = derez.components[ParticleEmitterComponent.self] {
            d.mainEmitter.color = .evolving(start: .single(.rgb(1.0, 1.0, 1.0, 1.0)), end: .single(.rgb(color, 0.0)))
            d.isEmitting = true
            derez.components.set(d)
        }
        derezLight.light.color = .rgb(color)
        derezLight.isEnabled = true
        derezTimer = 0.5
        shardTimer = 1.8
        for i in shards.indices {
            let (s, _, _) = shards[i]
            s.isEnabled = true
            s.position = p + [rng.float(-1, 1), rng.float(-0.4, 0.6), rng.float(-2, 2)]
            let v = SIMD3<Float>(rng.float(-9, 9), rng.float(3, 11), rng.float(-9, 9))
            let spin = simd_quatf(angle: rng.float(2, 7), axis: simd_normalize(SIMD3<Float>(rng.float(-1, 1), rng.float(-1, 1), rng.float(-1, 1))))
            shards[i] = (s, v, spin)
        }
    }

    private func updateFX(dt: Float) {
        sparkTimer -= dt
        if sparkTimer <= 0, var e = sparks.components[ParticleEmitterComponent.self], e.mainEmitter.birthRate > 0 {
            e.mainEmitter.birthRate = 0
            sparks.components.set(e)
        }
        if derezTimer > 0 {
            derezTimer -= dt
            derezLight.light.intensity = 160000 * clamp01(derezTimer / 0.5)
            if derezTimer <= 0.3, var d = derez.components[ParticleEmitterComponent.self], d.isEmitting {
                d.isEmitting = false
                derez.components.set(d)
            }
            if derezTimer <= 0 { derezLight.isEnabled = false }
        }
        if shardTimer > 0 {
            shardTimer -= dt
            for i in shards.indices {
                var (s, v, spin) = shards[i]
                v.y -= 14 * dt
                s.position += v * dt
                if s.position.y < 0.05 { s.position.y = 0.05; v.y = abs(v.y) * 0.3; v.x *= 0.8; v.z *= 0.8 }
                s.orientation = simd_slerp(s.orientation, s.orientation * spin, dt)
                s.scale = SIMD3<Float>(repeating: clamp01(shardTimer / 0.6))
                shards[i] = (s, v, spin)
                if shardTimer <= 0 { s.isEnabled = false }
            }
        }
        // trail pulse: a bright band running back from the crash point
        for (i, r) in renderers.enumerated() {
            var ps: Float = -1e6
            if let p = pulseOrigin, p.owner == i { ps = p.s - (time - p.t) * 140 }
            if let c = pulseCut, c.owner == i { ps = c.s - (time - c.t) * 90 }
            r.pulseS = ps
            r.boost = i == player.id ? grind : 0
        }
        if let p = pulseOrigin, time - p.t > 6 { pulseOrigin = nil }
    }

    private func pose() {
        let sp = clamp01((player.speed - 10) / 60)
        var pos = player.position
        if phaseTimer > 0 { pos.y += sin(time * 60) * 0.02 }
        playerVehicle.poseArena(position: pos, heading: player.visualHeading, lean: player.lean, pitch: player.pitch, time: time, speedNorm: sp, airborne: player.airborne)
        if phaseTimer > 0 { playerVehicle.setVisible(Int(time * 24) % 4 != 0) } else if player.alive { playerVehicle.setVisible(true) }
        if let ov = opponentVehicle {
            ov.poseArena(position: opponent.position, heading: opponent.visualHeading, lean: opponent.lean, pitch: opponent.pitch, time: time,
                         speedNorm: clamp01((opponent.speed - 10) / 60), airborne: opponent.airborne)
        }
        for (i, r) in renderers.enumerated() {
            switch i {
            case player.id:
                let h = headPoint(player, k: 0)
                r.update(headPosition: h, headHeight: player.trailHeight, headFloor: ground(SIMD2(h.x, h.z), player.position.y))
            case opponent.id:
                let h = headPoint(opponent, k: 1)
                r.update(headPosition: h, headHeight: opponent.trailHeight, headFloor: ground(SIMD2(h.x, h.z), opponent.position.y))
            default: r.update(headPosition: trails.trails[0].lastPoint?.pos ?? .zero, headHeight: 3.0)
            }
        }
    }

    private func headPoint(_ c: LightCycle, k: Int) -> SIMD3<Float> {
        if let block = emitBlock[k] { return block }
        if c.airborne && settings.jumpRule == 1, let last = trails.trails[c.id].lastPoint { return last.pos }
        let t = c.tail
        return [t.x, c.position.y, t.z]
    }

    var runSeconds: Float { runTime }
    var groundHeight: (SIMD2<Float>, Float) -> Float { ground }
    var levelName: String { world.terrain.deckName(at: player.xz, y: player.position.y) }
    var trailSegmentCount: Int { trails.trails.reduce(0) { $0 + max(0, $1.newestIndex - $1.firstAlive + 1) } }
    var phaseActive: Bool { phaseTimer > 0 }
}
