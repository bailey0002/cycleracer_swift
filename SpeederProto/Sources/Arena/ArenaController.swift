import Foundation
import RealityKit
import simd

/// The Grid game loop: cycles, trails, collision, grinding, jumps, pickups, the AI and
/// the crash sequence. `GameController` feeds it input and reads its outputs for the
/// camera, post pass and HUD.
@MainActor
final class ArenaController {
    /// `crashed` is the player's derez (slow-motion orbit, then a new round); `rivalDerezzed` is the
    /// rival's (freeze-orbit on the wreck, then a new round); `matchOver` holds the last orbit while
    /// the match stamp shows, then resets the score.
    enum Phase { case countdown(Float), running, crashed(Float), rivalDerezzed(Float), matchOver(Float, won: Bool), result }

    /// What a match was, for the result card. Credits are paid into the same purse as the jobs.
    struct MatchResult: Equatable {
        var won = false
        var wins = 0, losses = 0, rounds = 0
        var bestGrind: Float = 0        // longest continuous grind, seconds
        var longestTrail: Float = 0     // longest alive trail, metres
        var energyLeft: Float = 0
        var credits = 0
        var rival = ""
    }
    /// Phase and pulse are held and used with A / F; charge is taken on contact (full energy and a
    /// burst) and only ever spawns on the upper deck.
    enum Pickup: String { case phase = "PHASE", pulse = "PULSE", charge = "CHARGE" }

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
    private var playerBoosting = false
    private var grindAccel: Float = 0
    private var opponentAccel: Float = 0
    /// Armagetron's proximity term: accel / (offset + d) - accel / (offset + near), zero beyond `near`.
    static let grindGain: Float = 22, grindOffset: Float = 1.2, grindNear: Float = 5.0
    static func proximityAccel(_ clearance: Float) -> Float {
        guard clearance < grindNear else { return 0 }
        return grindGain / (grindOffset + clearance) - grindGain / (grindOffset + grindNear)
    }
    private var lastNose: [SIMD2<Float>] = [.zero, .zero]
    private var emitBlock: [SIMD3<Float>?] = [nil, nil]     // pivot while the tail has not passed it yet
    private var wasAirborne = [false, false]
    private var opponentRespawn: Float = 0
    private var opponentDead = false
    /// The rival spends the same energy budget on boost as the player, so a burst is a burst.
    private var opponentEnergy: Float = 0.6
    private(set) var lastRivalCause = ""

    // outputs
    private(set) var flash: Float = 0
    private(set) var shake: Float = 0
    private(set) var speedNorm: Float = 0
    private(set) var cameraOrbit: (center: SIMD3<Float>, progress: Float)? = nil
    private(set) var stateText = "READY"
    private(set) var wins = 0
    private(set) var losses = 0
    private(set) var heldPickup: Pickup? = nil
    /// What the player did this frame (cleared every update), for the HUD and haptics.
    struct Events {
        var snapped = false, jumped = false, landed = false, pickupTaken = false
        var pickupUsed: Pickup? = nil
        var roundStart = false, go = false, roundWon = false, roundLost = false
        var matchWon = false, matchLost = false
        var padBoost = false, padSlow = false
        var matchResult = false
        var charged = false
        var zoneOpened = false
        var voidRound = false
    }
    private(set) var events = Events()
    /// Match: first to `matchTarget` derezzes of the other cycle. A duel mission sets it out of
    /// reach and decides the job itself from `wins` / `losses`.
    var matchTarget = 3
    private(set) var round = 1
    /// The named opponent: its temper drives the AI, its name and colour the tag and the stamps.
    var rival: Rival = .kade {
        didSet { if rival != oldValue { applyRival() } }
    }
    var rivalName: String { rival.name }
    private var rosterIndex = 0
    /// Sumo zone (Armagetron): after a quiet stretch a circle appears at the arena centre and
    /// shrinks; outside it energy drains and an empty bar derezzes, inside it charges. Ends the
    /// stalemate rounds and gives the AI a target.
    private(set) var zoneRadius: Float? = nil
    static let zoneCenter = SIMD2<Float>(0, 30)
    static let zoneStart: Float = 70, zoneEnd: Float = 16, zoneShrink: Float = 20
    private let zoneAt: Float = ProcessInfo.processInfo.environment["SPEEDER_ARENA_ZONE_AT"].flatMap { Float($0) } ?? 25
    private let zoneRing = Entity()
    private let zoneDisc: ModelEntity
    /// Set when a free-play match ends; cleared by `restartMatch()`.
    private(set) var matchResult: MatchResult? = nil
    private var grindRun: Float = 0
    private var bestGrind: Float = 0
    private var longestTrail: Float = 0
    var awaitingRestart: Bool { if case .result = phase { return true } else { return false } }
    /// Name tag over the rival: a thin box (flat quads on moving entities get culled) with the
    /// tag texture, turned to face the camera every frame.
    private let rivalTag: ModelEntity
    private let rivalTagHolder = Entity()
    /// Capture hook: SPEEDER_ARENA_KILL_RIVAL=<run seconds> force-derezzes the rival.
    private let killRivalAt: Float? = ProcessInfo.processInfo.environment["SPEEDER_ARENA_KILL_RIVAL"].flatMap { Float($0) }
    /// Capture hook: SPEEDER_ARENA_IMMORTAL=1 lets the player drive through walls, so a scripted
    /// drive can watch the rival for a whole run (the AI logs).
    private let immortal = ProcessInfo.processInfo.environment["SPEEDER_ARENA_IMMORTAL"] == "1"
    private var padCooldown: [Float] = []
    private var prevGrind: Float = 0
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
        // the rival's burst is shorter than the player's: its 0.16 s decisions cannot handle more
        opponent.boostSpeed = 54
        opponent.boostAccel = 24
        opponent.maxSpeed = 62            // grinds must not take it into the regime where it boxes itself in
        ai = ArenaAI(cycleID: 2, heading: .pi)
        lastNose = [player.nose, opponent.nose]
        // sumo zone ring: 64 box segments on a unit circle (a scaled thin shell gets culled; boxes draw),
        // the holder is scaled to the radius per frame; plus a faint disc. Hidden until the zone opens.
        let zoneColor = SIMD3<Float>(0.95, 0.95, 1.0)
        let zoneMat = materials.neon(zoneColor, intensity: 2.8)
        let n = 64
        for i in 0..<n {
            let a = Float(i) / Float(n) * 2 * .pi
            let seg = ModelEntity(mesh: .generateBox(size: [2 * .pi / Float(n) * 1.03, 1.1, 0.004]), materials: [zoneMat])
            seg.position = [cos(a), 0.55, sin(a)]
            // the box's long axis must run along the tangent (-sin a, cos a)
            seg.orientation = simd_quatf(angle: -a - .pi / 2, axis: [0, 1, 0])
            zoneRing.addChild(seg)
        }
        zoneDisc = ModelEntity(mesh: .generatePlane(width: 2, depth: 2), materials: [materials.glow(zoneColor, opacity: 0.12)])
        zoneDisc.orientation = simd_quatf(angle: 0.01, axis: [1, 0, 0])
        zoneDisc.position.y = 0.05
        zoneRing.position = [Self.zoneCenter.x, 0, Self.zoneCenter.y]
        zoneRing.isEnabled = false
        root.addChild(zoneRing)
        root.addChild(zoneDisc)
        zoneDisc.isEnabled = false
        rivalTag = ModelEntity(mesh: .generateBox(size: [3.4, 1.06, 0.02]), materials: [materials.glow(Self.opponentColor, opacity: 0.0)])
        rivalTagHolder.addChild(rivalTag)
        rivalTagHolder.isEnabled = false
        root.addChild(rivalTagHolder)

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
        padCooldown = Array(repeating: 0, count: world.pads.count)
        apply(settings)
        ai.pads = world.pads.filter { $0.boost }.map { $0.entity.position }
        ai.ramps = world.terrain.ramps.map { r in
            let cx = (r.xMin + r.xMax) / 2
            let (bz, tz) = r.h0 < r.h1 ? (r.z0, r.z1) : (r.z1, r.z0)
            let dir: Float = tz > bz ? 1 : -1
            return (bottom: SIMD3<Float>(cx, min(r.h0, r.h1), bz - dir * 6), top: SIMD3<Float>(cx, max(r.h0, r.h1), tz + dir * 8))
        }
        if let name = ProcessInfo.processInfo.environment["SPEEDER_ARENA_RIVAL"], let r = Rival.named(name.uppercased()) { rival = r }
        applyRival()
    }

    /// Rebuild what depends on the rival: the AI temper and the tag texture.
    private func applyRival() {
        ai.temper = rival.temper
        ai.skill = rival.skill
        let tex = try? SceneMaterials.texture(ProceduralTextures.nameTag(name: rival.name, temper: rival.temper.rawValue, color: rival.color), .color)
        if let tex {
            var m = UnlitMaterial()
            m.color = .init(tint: .white, texture: .init(tex))
            m.blending = .transparent(opacity: .init(texture: .init(tex)))
            rivalTag.model?.materials = [m]
        }
    }

    /// Turn the tag toward the camera and hang it over the rival (hidden while the rival is dead).
    func placeRivalTag(camera: SIMD3<Float>) {
        let visible = settings.opponent && !opponentDead
        rivalTagHolder.isEnabled = visible
        guard visible else { return }
        let p = opponent.position + [0, 3.3, 0]
        rivalTagHolder.position = p
        let d = camera - p
        rivalTagHolder.orientation = simd_quatf(angle: atan2(d.x, d.z), axis: [0, 1, 0])
        // constant apparent size (like a screen-space label), within limits
        let dist = simd_length(d)
        rivalTagHolder.scale = SIMD3<Float>(repeating: max(0.7, min(4.0, dist / 18)))
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
        let chargeMat = materials.neon(SIMD3(1.0, 0.70, 0.22), intensity: 5)
        for i in 0..<3 {
            let e = Entity()
            let core = ModelEntity(mesh: .generateBox(size: i == 2 ? [1.2, 1.2, 1.2] : [0.9, 0.9, 0.9]), materials: [i == 2 ? chargeMat : m])
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
            // the charge's pillar is taller and warm so it reads from the ground through the deck edge
            let pillar = ModelEntity(mesh: .generateBox(size: [0.12, i == 2 ? 16 : 8, 0.12]), materials: [i == 2 ? chargeMat : materials.neon(Self.pickupColor, intensity: 2)])
            pillar.position = [0, i == 2 ? 8 : 4, 0]
            e.addChild(pillar)
            world.pickupGroup.addChild(e)
            pickups.append(PickupSlot(entity: e, kind: [.phase, .pulse, .charge][i], pos: .zero, active: false, timer: 0.5 + Float(i) * 3))
        }
    }

    private func spawnPickup(_ i: Int) {
        let h = world.halfSize * 0.7
        // the charge only ever spawns on the upper deck (inside its rails), the others anywhere open
        func candidate() -> SIMD2<Float> {
            if pickups[i].kind == .charge, let d = world.terrain.decks.first {
                return SIMD2<Float>(rng.float(d.min.x + 8, d.max.x - 8), rng.float(d.min.y + 8, d.max.y - 8))
            }
            return SIMD2<Float>(rng.float(-h, h), rng.float(-h, h))
        }
        var p = candidate()
        // keep clear of walls
        for _ in 0..<8 {
            let g = topSurface(p)
            if trails.nearest(to: p, radius: 6, yBand: g...(g + 3), ignoreOwner: nil) == nil && simd_length(p - player.xz) > 25 { break }
            p = candidate()
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
        energy = 0.6; edge = 1; grind = 0; grindAccel = 0; opponentAccel = 0; opponentEnergy = 0.6
        heldPickup = ProcessInfo.processInfo.environment["SPEEDER_ARENA_GIVE"].flatMap { Pickup(rawValue: $0.uppercased()) }; phaseTimer = 0
        opponentDead = false
        opponentVehicle?.root.isEnabled = settings.opponent
        playerVehicle.setVisible(true)
        cameraOrbit = nil
        pulseOrigin = nil
        runTime = 0
        prevGrind = 0
        for i in padCooldown.indices { padCooldown[i] = 0 }
        for i in pickups.indices { pickups[i].active = false; pickups[i].entity.isEnabled = false; pickups[i].timer = 1.5 + Float(i) * 4 }
        zoneRadius = nil; ai.zone = nil; zoneRing.isEnabled = false; zoneDisc.isEnabled = false
        phase = .countdown(demo ? 0.3 : 1.2)
        stateText = "READY"
        events.roundStart = true
    }

    /// A / F / tap on the result card: next match (next rival in free play).
    func restartMatch() {
        guard awaitingRestart else { return }
        matchResult = nil
        resetMatch()
        startRound()
    }

    private func resetMatch() {
        wins = 0; losses = 0; round = 1
        bestGrind = 0; longestTrail = 0; grindRun = 0
        // free play meets the roster in turn: the next match brings the next rival
        if matchTarget != Int.max {
            rosterIndex = (rosterIndex + 1) % Rival.roster.count
            rival = Rival.roster[rosterIndex]
        }
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
        events = Events()
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
            if left <= 0 { player.speed = player.baseSpeed; opponent.speed = opponent.baseSpeed; events.go = true }
            pose()
            return
        case .crashed(let t):
            let tt = t + dt
            dt *= 0.35                                            // slow-motion orbit
            cameraOrbit = (derez.position, clamp01(tt / 3.2))
            if tt > 3.4 { endRound(); return }
            phase = .crashed(tt)
            // the opponent keeps riding in slow motion
            if settings.opponent && !opponentDead { stepOpponent(dt: dt, aiInput: aiInput) }
            pose()
            return
        case .rivalDerezzed(let t):
            // freeze-cam on the wreck: nothing moves but the debris and the trail pulse
            let tt = t + dt
            cameraOrbit = (derez.position, clamp01(tt / 2.4))
            if tt > 2.6 { endRound(); return }
            phase = .rivalDerezzed(tt)
            pose()
            return
        case .matchOver(let t, let won):
            let tt = t + dt
            cameraOrbit = (derez.position, clamp01(tt / 3.6))
            if tt > 3.8 {
                // hold on the wreck with the result card up until the player restarts
                let pay = wins * 40 + (won ? 150 : 0) + Int(bestGrind * 10)
                matchResult = MatchResult(won: won, wins: wins, losses: losses, rounds: wins + losses, bestGrind: bestGrind,
                                          longestTrail: longestTrail, energyLeft: energy, credits: pay, rival: rival.name)
                events.matchResult = true
                phase = .result
                return
            }
            phase = .matchOver(tt, won: won)
            pose()
            return
        case .result:
            cameraOrbit = (derez.position, 1)
            pose()
            return
        case .running:
            break
        }
        runTime += dt
        if let k = killRivalAt, runTime >= k, settings.opponent, !opponentDead {
            crashOpponent(at: TrailHit(ref: SegRef(trail: 0, index: 0), t: 0, point: opponent.xz, wallDir: .zero, normal: .zero, boundary: false))
            return
        }

        // --- player
        var pin = input
        if pin.boost && energy <= 0.02 { pin.boost = false }
        if pin.boost { energy = max(0, energy - dt * 0.22) } else { energy = min(1, energy + dt * 0.03) }
        playerBoosting = pin.boost
        if pin.jump && player.airborne { pin.jump = false }
        updatePads(dt: dt)
        stepCycle(player, input: pin, dt: dt, accel: settings.grinding ? grindAccel : 0)
        // --- opponent
        if settings.opponent && !opponentDead { stepOpponent(dt: dt, aiInput: aiInput) }

        // --- collisions (both tested on the same frame: a double derez is a void round, Armagetron style)
        let rivalHit: TrailHit? = (settings.opponent && !opponentDead) ? collide(opponent) : nil
        var playerCrashed = false
        if let hit = collide(player) {
            if phaseTimer > 0 && !hit.boundary {
                // phase: pass through one wall (already consumed)
                phaseTimer = 0
                flash = max(flash, 0.25)
            } else if let deflected = tryDeflect(player, hit: hit) {
                _ = deflected
            } else if !immortal {
                crashPlayer(at: hit)
                playerCrashed = true
            }
        }
        if let hit = rivalHit {
            crashOpponent(at: hit)
            if playerCrashed {
                wins -= 1; losses -= 1
                events.roundWon = false; events.roundLost = false; events.voidRound = true
                stateText = "VOID ROUND - BOTH DEREZZED"
                phase = .crashed(0)
            }
        }
        if playerCrashed { return }

        // --- grinding / edge (player only; the AI has no rubber)
        updateGrinding(dt: dt)
        if settings.grinding {
            // the rival rides the same curve (a little weaker) so its grinds read the same way
            let near = trails.nearest(to: opponent.xz, radius: 5.5, yBand: opponent.yBand, ignoreOwner: opponent.id)
            let a = near.map { Self.proximityAccel(max(0, $0.distance - opponent.halfWidth)) * clamp01((abs(simd_dot($0.dir, opponent.forward2)) - 0.85) / 0.1) } ?? 0
            opponentAccel = damp(opponentAccel, a * 0.8, 6, dt)
        }

        // --- sumo zone
        updateZone(dt: dt)
        if !player.alive { return }
        // --- trails
        trails.decay(maxLength: trailMaxLength)
        if let cut = pulseCut, time - cut.t > 1.2 { pulseCut = nil }

        // --- pickups
        updatePickups(dt: dt, action: input.action)
        phaseTimer = max(0, phaseTimer - dt)

        speedNorm = clamp01((player.speed - 10) / 75)
        // match stats for the result card
        if grind > 0.3 { grindRun += dt; bestGrind = max(bestGrind, grindRun) } else { grindRun = 0 }
        longestTrail = max(longestTrail, trails.trails[player.id].aliveLength)
        pose()
    }

    /// Open the zone after the quiet period, shrink it, and settle energy in and out of it.
    private func updateZone(dt: Float) {
        guard runTime >= zoneAt else { return }
        if zoneRadius == nil {
            zoneRadius = Self.zoneStart
            events.zoneOpened = true
            flash = max(flash, 0.2)
            rumble?(0.6, 0.5)
            zoneRing.isEnabled = true
            zoneDisc.isEnabled = true
        }
        let r = max(Self.zoneEnd, Self.zoneStart - (runTime - zoneAt) / Self.zoneShrink * (Self.zoneStart - Self.zoneEnd))
        zoneRadius = r
        ai.zone = (Self.zoneCenter, r)
        // player
        if simd_length(player.xz - Self.zoneCenter) < r {
            energy = min(1, energy + dt * 0.08)
        } else {
            energy = max(0, energy - dt * 0.07)
            if energy <= 0 {
                crashPlayer(at: TrailHit(ref: SegRef(trail: -2, index: 0), t: 0, point: player.xz, wallDir: .zero, normal: .zero, boundary: false))
                return
            }
        }
        // rival
        if settings.opponent && !opponentDead {
            if simd_length(opponent.xz - Self.zoneCenter) < r {
                opponentEnergy = min(1, opponentEnergy + dt * 0.08)
            } else {
                opponentEnergy = max(0, opponentEnergy - dt * 0.07)
                if opponentEnergy <= 0 {
                    crashOpponent(at: TrailHit(ref: SegRef(trail: -2, index: 0), t: 0, point: opponent.xz, wallDir: .zero, normal: .zero, boundary: false))
                }
            }
        }
    }

    /// The rival's step: the AI decides, boost is gated by its own energy budget (so a burst is a
    /// burst, in every phase), then the same kinematics as the player.
    private func stepOpponent(dt: Float, aiInput: CycleInput?) {
        var ai = aiInput ?? self.ai.decide(dt: dt, cycle: opponent, trails: trails, player: player, snapMode: snapMode)
        if ai.boost && opponentEnergy <= 0.02 { ai.boost = false }
        if ai.boost { opponentEnergy = max(0, opponentEnergy - dt * 0.22) }
        else { opponentEnergy = min(1, opponentEnergy + dt * 0.03 + max(0, opponentAccel) * dt * 0.02) }
        stepCycle(opponent, input: ai, dt: dt, accel: opponentAccel)
    }

    /// Floor pads: a boost pad kicks the cycle (+22 m/s, then the decay curve) and charges energy; a
    /// slow pad cuts speed by 40 %. One trigger per crossing.
    private func updatePads(dt: Float) {
        for (i, pad) in world.pads.enumerated() {
            padCooldown[i] = max(0, padCooldown[i] - dt)
            guard padCooldown[i] <= 0, !player.airborne, simd_length(player.xz - pad.pos) < ArenaWorld.padRadius,
                  abs(pad.entity.position.y - player.position.y) < 1.5 else { continue }
            padCooldown[i] = 1.5
            if pad.boost {
                player.speed = min(player.maxSpeed, player.speed + 22)
                energy = min(1, energy + 0.15)
                flash = max(flash, 0.12)
                shake = max(shake, 0.1)
                events.padBoost = true
                rumble?(0.5, 0.6)
            } else {
                player.speed *= 0.6
                flash = max(flash, 0.15)
                shake = max(shake, 0.2)
                events.padSlow = true
                rumble?(0.6, 0.3)
            }
        }
    }

    /// The round is over (either cycle derezzed): score the match or start the next round.
    private func endRound() {
        if wins >= matchTarget { phase = .matchOver(0, won: true); events.matchWon = true; stateText = "MATCH WON"; return }
        if losses >= matchTarget { phase = .matchOver(0, won: false); events.matchLost = true; stateText = "MATCH LOST"; return }
        round += 1
        startRound()
    }

    private func stepCycle(_ c: LightCycle, input: CycleInput, dt: Float, accel: Float) {
        let k = c.id - 1
        let pivot = c.position
        let wasAir = c.airborne
        let corner = c.step(dt: dt, input: input, snapMode: snapMode, accel: accel, ground: ground)
        if c === player {
            // every action answers on the same frame: shake, haptic, HUD
            if corner { events.snapped = true; shake = max(shake, 0.12); rumble?(0.35, 1.0) }
            if c.airborne && !wasAir { events.jumped = true; shake = max(shake, 0.08); rumble?(0.45, 0.7) }
            if !c.airborne && wasAir { events.landed = true; shake = max(shake, 0.15); rumble?(0.5, 0.4) }
        }
        // jump rule: elevated trail follows the bike; gap rule breaks the strand while airborne
        let gapRule = settings.jumpRule == 1
        if c.airborne && !wasAirborne[k] && gapRule { trails.breakStrand(owner: c.id) }
        wasAirborne[k] = c.airborne
        if corner {
            // extend the old line to the pivot, then hold emission until the tail has passed it
            trails.emit(owner: c.id, position: [pivot.x, pivot.y, pivot.z], height: c.trailHeight, floor: ground(SIMD2(pivot.x, pivot.z), c.position.y), force: true)
            emitBlock[k] = pivot
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
        guard player.alive, !immortal else { return }
        losses += 1
        events.roundLost = true
        let p = player.position + [0, 0.9, 0]
        derezAt(p, color: Self.playerColor)
        breachTrails(at: player.xz)
        playerVehicle.setVisible(false)
        player.alive = false
        flash = 1.0
        shake = 1.0
        rumble?(1.0, 0.3)
        pulseOrigin = (player.id, trails.trails[player.id].headS, time)
        cameraOrbit = (p, 0)
        phase = .crashed(0)
        // attribution: the rival's name on a cut-off, and an own-trail death reads as your own doing
        stateText = hit.boundary ? "DEREZZED - BOUNDARY" : (hit.ref.trail == -2 ? "DEREZZED - OUTSIDE THE ZONE" : (hit.ref.trail == player.id ? "BOXED YOURSELF" : (hit.ref.trail == 0 ? "DEREZZED - HAZARD" : "CUT OFF BY \(rival.name)")))
    }

    private func crashOpponent(at hit: TrailHit) {
        wins += 1
        events.roundWon = true
        opponentDead = true
        let p = opponent.position + [0, 0.9, 0]
        derezAt(p, color: Self.opponentColor)
        breachTrails(at: opponent.xz)
        opponentVehicle?.root.isEnabled = false
        pulseOrigin = (opponent.id, trails.trails[opponent.id].headS, time)
        shake = max(shake, 0.5)
        flash = max(flash, 0.5)
        stateText = "\(rivalName) DEREZZED"
        lastRivalCause = hit.boundary ? "boundary" : (hit.ref.trail == -2 ? "zone" : (hit.ref.trail == opponent.id ? "own trail" : (hit.ref.trail == 0 ? "hazard" : "player trail")))
        rumble?(0.8, 0.6)
        cameraOrbit = (p, 0)
        phase = .rivalDerezzed(0)
    }

    /// A derez explosion opens every dynamic trail within 4 m (Armagetron's breach), so the
    /// wreck leaves a gap you can ride through.
    private func breachTrails(at p: SIMD2<Float>) {
        let changed = trails.breach(at: p, radius: 4)
        guard !changed.isEmpty else { return }
        rebuildHash()
        for owner in changed where owner < renderers.count { renderers[owner].invalidate(from: trails.trails[owner].firstAlive) }
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
        guard settings.grinding else { grind = 0; grindAccel = 0; arc.isEnabled = false; return }
        let near = trails.nearest(to: player.xz, radius: Self.grindNear + 1.5, yBand: player.yBand, ignoreOwner: player.id, ignoreNewest: 6)
        var g: Float = 0          // 0...1 grind meter (the acceleration, normalised)
        var accel: Float = 0
        if let near {
            let clearance = max(0, near.distance - player.halfWidth)
            let parallel = abs(simd_dot(near.dir, player.forward2))
            // continuous proximity term, faded in over the last few degrees of alignment
            accel = Self.proximityAccel(clearance) * clamp01((parallel - 0.85) / 0.10)
            g = clamp01(accel / 14)
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
        // Armagetron's tunnel: a wall on the other side too multiplies the term
        if g > 0.05, let near, trails.nearest(to: player.xz - (near.point - player.xz), radius: 4.0, yBand: player.yBand, ignoreOwner: player.id, ignoreNewest: 6) != nil {
            accel *= 1.5
            g = min(1, g * 1.5)
        }
        // break-away kick: leaving a hard grind gives a burst that the decay curve then bleeds off
        if prevGrind > 0.45 && g < 0.1 && grindRun > 0.6 { player.speed = min(player.maxSpeed, player.speed + 10) }
        prevGrind = g
        grind = damp(grind, g, 8, dt)
        grindAccel = accel
        // a grind refills energy, but slower while boost is spending it, so a tunnel grind cannot fund an endless boost
        if g > 0.1 { energy = min(1, energy + dt * g * (playerBoosting ? 0.12 : 0.35)) }
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
            if simd_length(pickups[i].pos - player.xz) < 2.6 && abs(pickups[i].entity.position.y - player.position.y) < 3 {
                if pickups[i].kind == .charge {
                    // taken on contact: the deck pays in energy and a burst
                    energy = 1
                    player.speed = min(player.maxSpeed, player.speed + 20)
                    pickups[i].active = false
                    pickups[i].entity.isEnabled = false
                    pickups[i].timer = 14
                    flash = max(flash, 0.25)
                    shake = max(shake, 0.15)
                    events.charged = true
                    rumble?(0.7, 0.7)
                } else if heldPickup == nil {
                    heldPickup = pickups[i].kind
                    pickups[i].active = false
                    pickups[i].entity.isEnabled = false
                    pickups[i].timer = 9
                    flash = max(flash, 0.15)
                    events.pickupTaken = true
                    rumble?(0.4, 0.8)
                }
            }
        }
        if action, let held = heldPickup {
            heldPickup = nil
            events.pickupUsed = held
            rumble?(0.5, 0.8)
            switch held {
            case .phase:
                phaseTimer = 5.0
                flash = max(flash, 0.15)
            case .charge:
                break
            case .pulse:
                flash = max(flash, 0.2)
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
        if let r = zoneRadius {
            // the ring pulses a little faster as it closes
            let pulse = 1 + 0.02 * sin(time * (4 + (Self.zoneStart - r) * 0.1))
            zoneRing.scale = [r * pulse, 1, r * pulse]
            zoneDisc.position = [Self.zoneCenter.x, 0.05, Self.zoneCenter.y]
            zoneDisc.scale = [r, 1, r]
        }
        world.placeRivalBeam(at: opponent.position, visible: settings.opponent && !opponentDead && simd_length(opponent.xz - player.xz) > 22)
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
    var roundNumber: Int { round }
    var groundHeight: (SIMD2<Float>, Float) -> Float { ground }
    var levelName: String { world.terrain.deckName(at: player.xz, y: player.position.y) }
    var trailSegmentCount: Int { trails.trails.reduce(0) { $0 + max(0, $1.newestIndex - $1.firstAlive + 1) } }
    var phaseActive: Bool { phaseTimer > 0 }
    var zoneText: String? { zoneRadius.map { "ZONE \(Int($0)) m" } }
}
