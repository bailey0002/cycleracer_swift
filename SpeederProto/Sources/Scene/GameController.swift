import Foundation
import Combine
import RealityKit
import simd
import SwiftUI

/// Owns the ARView, builds the scene and runs the per-frame update (brief §33).
@MainActor
final class GameController: ObservableObject {
    let arView: GameARView
    let post = PostProcessor()

    @Published var settings = FXSettings() {
        didSet {
            if settings.environment != oldValue.environment, world != nil {
                var s = settings
                (Theme(rawValue: s.environment) ?? .neonCity).adjust(&s)
                settings = s
                requestRebuild()
                return
            }
            applySettings()
        }
    }
    @Published var stats = FrameStats()
    @Published var loadError: String? = nil
    /// Same-frame action acknowledgement for the HUD.
    @Published var ack = ActionAck()
    private var ackTimers = (fire: Float(0), jump: Float(0), pickup: Float(0), snap: Float(0), beacon: Float(0), hit: Float(0), stamp: Float(0), boost: Float(0))
    private var stampText = ""
    private var lastStyle: SegmentStyle? = nil
    private var boostPrev = false
    /// Hit-stop: the simulation runs at 15 % for a few frames after an obstacle hit.
    private var hitStop: Float = 0
    /// Fade to black that covers scene rebuilds (and the launch). 0 clear ... 1 black.
    private var curtain: Float = 1
    private var curtainTarget: Float = 0
    private var pendingRebuild = false
    /// Job loop (delivery missions) for the corridor worlds.
    let missions = MissionRunner()
    @Published var mission = MissionState()
    /// Free-play match result card on The Grid (nil while playing).
    @Published var matchResult: ArenaController.MatchResult? = nil
    private var missionFirePrev = false
    /// The contact, standing by the parked bike during briefings (avatar pipeline test).
    private var contactAvatar: AvatarActor?
    private var beacons: BeaconLayer?
    private var beaconProbe: SIMD3<Float> { beacons?.nearestWorldPosition ?? .zero }
    private var pursuer: PursuerActor?
    private let holdBriefing = ProcessInfo.processInfo.environment["SPEEDER_HOLD_BRIEFING"] == "1"
    /// SPEEDER_HOLD_RESULT=1: the demo accepts the briefing but leaves the result card up (screenshots).
    private let holdResult = ProcessInfo.processInfo.environment["SPEEDER_HOLD_RESULT"] == "1"
    private var missionHitsSeen = 0
    private var missionKillsSeen = 0
    #if os(macOS)
    @Published var panelVisible = true
    #else
    @Published var panelVisible = ProcessInfo.processInfo.environment["SPEEDER_PANEL"] == "1"
    #endif

    private var materials: SceneMaterials?
    private let worldAnchor = AnchorEntity(world: .zero)
    private var world: WorldScroller?
    private var arena: ArenaController?
    /// Edge detection for the arena's snap turns, jump and pickup action.
    private var arenaPrev = (steer: Float(0), climb: Float(0), fire: false)
    private var speeder: SpeederController?
    private var cameraRig: CameraRig?
    private let sun = DirectionalLight()
    private let fill = SpotLight()
    private var theme: Theme = .neonCity
    private var rebuilding = false
    private let rim = DirectionalLight()
    private let speedParticles = Entity()
    private var updateSub: Cancellable?

    private var time: Float = 0
    private var speed: Float = 0
    private var maxSpeed: Float = 110
    private var fpsSmoothed: Double = 60
    private var statsAccumulator: Float = 0
    private var entityCount = 0
    // gameplay
    private var distance: Float = 0
    private var hits = 0
    private var flash: Float = 0
    private var invulnerable: Float = 0
    private var shakeBurst: Float = 0
    private let sparks = Entity()
    private let gamepad = GamepadInput()
    private var weapons: WeaponSystem?
    private var kills = 0
    private var sparkTimer: Float = 0
    /// SPEEDER_DEMO=1 scripts steering/boost; SPEEDER_CAPTURE_DIR=<dir> saves frames at fixed times.
    private let demoMode = ProcessInfo.processInfo.environment["SPEEDER_DEMO"] == "1"
    private let captureDir = ProcessInfo.processInfo.environment["SPEEDER_CAPTURE_DIR"]
    private var captureTimes: [Float] = (ProcessInfo.processInfo.environment["SPEEDER_CAPTURE_TIMES"] ?? "4,7,10").split(separator: ",").compactMap { Float($0) }
    /// SPEEDER_SWEEP=1: capture a frame per disabled technique for A/B comparison.
    private let sweepMode = ProcessInfo.processInfo.environment["SPEEDER_SWEEP"] == "1"
    /// SPEEDER_ARENA_CAMERA=overview: fixed high view for layout captures.
    private let overviewCamera = ProcessInfo.processInfo.environment["SPEEDER_ARENA_CAMERA"] == "overview"
    private let sideCamera = ProcessInfo.processInfo.environment["SPEEDER_ARENA_CAMERA"] == "side"
    /// SPEEDER_CAMERA=overview: a high camera behind the vehicle for corridor layout captures.
    private let corridorOverview = ProcessInfo.processInfo.environment["SPEEDER_CAMERA"] == "overview"
    private var sweepSteps: [(Float, String, (inout FXSettings) -> Void)] = [
        (4.0, "all", { _ in }),
        (5.5, "source", { $0.postFX = false }),
        (7.0, "nofog", { $0.postFX = true; $0.fog = false }),
        (8.5, "nobloom", { $0.fog = true; $0.bloom = false }),
        (10.0, "nostreaks", { $0.bloom = true; $0.streaks = false }),
        (11.5, "nograde", { $0.streaks = true; $0.colorGrade = false }),
        (13.0, "nolights", { $0.colorGrade = true; $0.realLights = false }),
        (14.5, "noreflect", { $0.realLights = true; $0.reflections = false }),
    ]

    init() {
        #if os(macOS)
        arView = GameARView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720))
        #else
        arView = GameARView()
        #endif
        configureView()
        applyVariantPreset()
        if settings.missions && ProcessInfo.processInfo.environment["SPEEDER_VARIANT"] == nil {
            // the current job decides the world
            settings.environment = missions.current.theme.rawValue
            missions.current.theme.adjust(&settings)
        }
        mission = missionActive ? missions.snapshot() : MissionState()
        Task { await build() }
    }

    /// SPEEDER_VARIANT=<name> applies a look preset at launch (used by the comparison sweep).
    private func applyVariantPreset() {
        guard let name = ProcessInfo.processInfo.environment["SPEEDER_VARIANT"] else { return }
        var s = settings
        switch name {
        case "dense-city":     s.secondRow = true; s.storefronts = true; s.windowsBright = true
        case "sparse-city":    s.secondRow = false; s.storefronts = false
        case "no-second-row":  s.secondRow = false
        case "windows-bright": s.windowsBright = true
        case "thin-fog":       s.fogLevel = 0
        case "thick-fog":      s.fogLevel = 2
        case "bloom-low":      s.bloomLevel = 0
        case "bloom-high":     s.bloomLevel = 2
        case "tunnel-dense":   s.tunnelDense = true
        case "obstacles-holo": s.obstacleSkin = 1
        case "obstacles-wire": s.obstacleSkin = 2
        case "obstacles-trim": s.obstacleSkin = 3
        case "no-reflections": s.reflections = false
        case "no-streaks":     s.streaks = false
        case "rings-red":      s.ringColor = 2
        case "rings-mixed":    s.ringColor = 0
        case "palette-mixed":  s.palette = 0
        case "palette-amber":  s.palette = 2
        case "hazard-magenta": s.hazardColor = 0
        case "hazard-orange":  s.hazardColor = 2
        case "canyon":         s.environment = Theme.sunsetCanyon.rawValue; Theme.sunsetCanyon.adjust(&s)
        case "grid":           s.environment = Theme.theGrid.rawValue; Theme.theGrid.adjust(&s)
        case "grid-snap":      s.environment = Theme.theGrid.rawValue; Theme.theGrid.adjust(&s); s.steeringMode = 1
        case "grid-gap":       s.environment = Theme.theGrid.rawValue; Theme.theGrid.adjust(&s); s.jumpRule = 1
        case "baseline":       break
        default: break
        }
        // arena capture hooks
        if ProcessInfo.processInfo.environment["SPEEDER_ARENA_AI"] == "0" { s.opponent = false }
        if let t = ProcessInfo.processInfo.environment["SPEEDER_ARENA_TRAIL"], let v = Int(t) { s.trailLength = v }
        settings = s
    }

    private func configureView() {
        arView.environment.background = .color(.rgb(0.01, 0.01, 0.02))
        #if os(iOS)
        arView.renderOptions.insert(.disableDepthOfField)
        arView.renderOptions.insert(.disableCameraGrain)
        arView.renderOptions.insert(.disableFaceMesh)
        arView.renderOptions.insert(.disablePersonOcclusion)
        arView.renderOptions.insert(.disableGroundingShadows)
        #endif
        let post = self.post
        arView.renderCallbacks.prepareWithDevice = { device in post.prepare(device: device) }
        arView.renderCallbacks.postProcess = { ctx in post.process(ctx) }
    }

    /// Ask for a rebuild: the curtain closes first, the rebuild runs behind it, then it opens.
    private func requestRebuild() {
        curtainTarget = 1
        pendingRebuild = true
    }

    /// Tear down and rebuild the world for the selected theme (behind the curtain).
    private func rebuildScene() async {
        guard !rebuilding else { return }
        rebuilding = true
        lastStyle = nil
        world = nil; arena = nil; speeder = nil; cameraRig = nil; weapons = nil; contactAvatar = nil; beacons = nil; pursuer = nil
        for child in worldAnchor.children.map({ $0 }) { child.removeFromParent() }
        entityCount = 0
        post.captureRequest = nil
        await build()
        rebuilding = false
    }

    private func build() async {
        do {
            theme = Theme(rawValue: settings.environment) ?? .neonCity
            post.theme = theme
            let device = MTLCreateSystemDefaultDevice()
            let materials = try SceneMaterials(device: device, theme: theme)
            self.materials = materials

            arView.environment.lighting.resource = materials.environment
            arView.environment.lighting.intensityExponent = theme.iblExponent
            arView.environment.background = .skybox(materials.environment)

            let speeder = try await SpeederController.load(materials: materials)
            worldAnchor.addChild(speeder.root)
            self.speeder = speeder

            if theme.mode == .arena {
                let arena = ArenaController(materials: materials, settings: settings, vehicle: speeder)
                arena.demo = demoMode
                arena.rumble = { [weak self] i, s in self?.gamepad.rumble(intensity: i, sharpness: s) }
                worldAnchor.addChild(arena.root)
                self.arena = arena
                let rival = try await SpeederController.load(materials: materials)
                arena.attachOpponent(rival)
            } else {
                let program = missionActive ? TrackProgram(blocks: missions.current.blocks) : TrackProgram()
                let world = WorldScroller(materials: materials, settings: settings, program: program)
                distance = 0; hits = 0; missionHitsSeen = 0; kills = 0; missionKillsSeen = 0
                if missionActive {
                    let m = missions.current
                    if m.kind == .search {
                        let layer = BeaconLayer(materials: materials, count: m.beacons, trackLength: m.distance, seed: UInt64(m.id * 131 + 7))
                        worldAnchor.addChild(layer.root)
                        beacons = layer
                    }
                    if m.kind == .escape {
                        let p = PursuerActor(materials: materials)
                        worldAnchor.addChild(p.root)
                        pursuer = p
                    }
                    // the contact waits beside the bike; hidden once the job is live
                    do {
                        let avatar = try await AvatarActor.load()
                        avatar.root.position = [2.6, 0, -1.5]
                        avatar.face([0, 1.5, 6])
                        worldAnchor.addChild(avatar.root)
                        contactAvatar = avatar
                    } catch { print("avatar load failed: \(error)") }
                }
                worldAnchor.addChild(world.root)
                self.world = world
            }

            let rig = CameraRig()
            worldAnchor.addChild(rig.root)
            self.cameraRig = rig

            // key light per theme: cool moonlight for the city, low warm sun ahead for the canyon
            sun.light.color = .rgb(theme.sunColor)
            sun.light.intensity = theme.sunIntensity
            sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: theme.shadowDistance, depthBias: 2.5)
            sun.look(at: [0, 0, -6], from: theme.sunFrom, relativeTo: nil)
            worldAnchor.addChild(sun)

            // rim + camera fill only matter at night; the canyon sun does the work by day
            rim.removeFromParent(); fill.removeFromParent()
            if theme.useFillSpot {
                rim.light.color = .rgb(0.45, 0.85, 1.0)
                rim.light.intensity = 900
                rim.look(at: [0, 1, 0], from: [-4, 5, -12], relativeTo: nil)
                worldAnchor.addChild(rim)
                fill.light.color = .rgb(1.0, 0.92, 0.85)
                fill.light.intensity = 9000
                fill.light.innerAngleInDegrees = 30
                fill.light.outerAngleInDegrees = 50
                fill.light.attenuationRadius = 16
                fill.position = [0, 0.6, 0.5]
                rig.root.addChild(fill)
            }

            speedParticles.removeFromParent()
            buildSpeedParticles()
            rig.root.addChild(speedParticles)
            sparks.removeFromParent()
            buildSparks()
            worldAnchor.addChild(sparks)
            if theme.mode == .corridor {
                let weapons = WeaponSystem(materials: materials)
                worldAnchor.addChild(weapons.root)
                self.weapons = weapons
            }

            arView.scene.addAnchor(worldAnchor)
            applySettings()
            curtainTarget = 0
            updateSub = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] ev in
                self?.update(dt: Float(ev.deltaTime))
            }
        } catch {
            loadError = "\(error)"
            print("Scene build failed: \(error)")
        }
    }

    /// Fine bright motes streaming past the camera. Their speed follows vehicle speed.
    private func buildSpeedParticles() {
        var e = ParticleEmitterComponent()
        e.emitterShape = .box
        e.emitterShapeSize = [24, 10, 6]
        e.birthLocation = .volume
        e.emissionDirection = [0, 0, 1]
        e.speed = 40
        e.speedVariation = 10
        e.mainEmitter.birthRate = 220
        e.mainEmitter.lifeSpan = 0.45
        e.mainEmitter.lifeSpanVariation = 0.15
        e.mainEmitter.size = theme.speedParticleSize
        e.mainEmitter.sizeVariation = 0.02
        e.mainEmitter.stretchFactor = theme == .neonCity ? 7 : 3
        e.mainEmitter.blendMode = theme == .neonCity ? .additive : .alpha
        e.mainEmitter.opacityCurve = .quickFadeInOut
        let (c0, c1) = theme.speedParticleColor
        e.mainEmitter.color = .evolving(start: .single(.rgb(SIMD3(c0.x, c0.y, c0.z), c0.w)), end: .single(.rgb(SIMD3(c1.x, c1.y, c1.z), c1.w)))
        speedParticles.components.set(e)
        speedParticles.position = [0, -0.5, -16]
    }

    /// One-shot spark burst used for collisions and barrier scraping.
    private func buildSparks() {
        var e = ParticleEmitterComponent()
        e.emitterShape = .sphere
        e.emitterShapeSize = [0.3, 0.3, 0.3]
        e.birthLocation = .volume
        e.emissionDirection = [0, 1, 1]
        e.speed = 9
        e.speedVariation = 5
        e.mainEmitter.birthRate = 900
        e.mainEmitter.lifeSpan = 0.5
        e.mainEmitter.lifeSpanVariation = 0.2
        e.mainEmitter.size = 0.06
        e.mainEmitter.sizeVariation = 0.03
        e.mainEmitter.stretchFactor = 4
        e.mainEmitter.acceleration = [0, -12, 8]
        e.mainEmitter.spreadingAngle = 1.2
        e.mainEmitter.blendMode = .additive
        e.mainEmitter.opacityCurve = .linearFadeOut
        e.mainEmitter.color = .evolving(start: .single(.rgb(1.0, 0.85, 0.5, 1.0)), end: .single(.rgb(1.0, 0.3, 0.1, 0.0)))
        e.isEmitting = false
        sparks.components.set(e)
    }

    private func emitSparks(at p: SIMD3<Float>, duration: Float) {
        sparks.position = p
        if var e = sparks.components[ParticleEmitterComponent.self] {
            e.isEmitting = true
            sparks.components.set(e)
        }
        sparkTimer = max(sparkTimer, duration)
    }

    private func applySettings() {
        post.settings = settings
        print("settings applied: fog=\(settings.fogLevel) bloom=\(settings.bloomLevel) skin=\(settings.obstacleSkin) secondRow=\(settings.secondRow) storefronts=\(settings.storefronts) windowsBright=\(settings.windowsBright) world=\(world != nil)")
        world?.apply(settings)
        arena?.apply(settings)
        speeder?.setLights(settings.realLights)
        speeder?.setParticles(settings.particles)
        sun.isEnabled = settings.realLights
        rim.isEnabled = settings.realLights
        fill.isEnabled = settings.realLights
        speedParticles.isEnabled = settings.particles
        weapons?.setEnabled(settings.obstacles)
    }

    // MARK: - Frame update

    private func update(dt rawDt: Float) {
        guard let speeder, let cameraRig else { return }
        let dt: Float = demoMode ? 1.0 / 60.0 : min(max(rawDt, 1.0 / 240.0), 1.0 / 20.0)
        time += dt
        updateCurtain(dt: dt)
        let input = arView.input
        gamepad.poll(into: input)
        if let arena {
            updateArena(arena, dt: dt, rawDt: rawDt, input: input, cameraRig: cameraRig)
            publishAck(dt: dt)
            return
        }
        guard let world else { return }
        // hit-stop: a few frames at 15 % after an impact; the camera keeps its own time
        hitStop = max(0, hitStop - dt)
        let simDt: Float = hitStop > 0 ? dt * 0.15 : dt
        if demoMode {
            let bias = Float(ProcessInfo.processInfo.environment["SPEEDER_DEMO_BIAS"] ?? "0") ?? 0
            input.pointerSteer = max(-1, min(1, sin(time * 0.9) * 0.5 + bias))
            input.pointerClimb = max(-1, min(1, sin(time * 0.6 + 1.0) * 0.9))
            // weapons pulse during a run; while parked the only "fire" is the scripted accept
            input.fire = (missionActive && missions.phase != .running) ? (time > 1.5 && !holdBriefing && !(holdResult && missions.phase != .briefing)) : Int(time * 2) % 3 == 0
            let demoBoost = ProcessInfo.processInfo.environment["SPEEDER_DEMO_BOOST"]
            input.pointerBoost = demoBoost == "always" || (time > 6.5 && time < 11 && demoBoost != "0")
        }
        handleCommonInput(input)
        handleCaptures()

        // throttle: cruise speed adjusted with up/down, boost multiplies
        if input.speedUp { settings.cruiseSpeed = min(110, settings.cruiseSpeed + 30 * dt) }
        if input.speedDown { settings.cruiseSpeed = max(15, settings.cruiseSpeed - 30 * dt) }
        // missions: A / F / tap accepts a briefing or a result; the vehicle only moves during a live job
        if missionActive {
            let fire = input.firing
            if fire && !missionFirePrev && missions.phase != .running { acceptMission() }
            missionFirePrev = fire
            var beaconHits = 0
            if let beacons, missions.isRunning {
                beaconHits = beacons.update(distance: distance, roadX: { world.offset(atWorldZ: $0) - world.playerOffset }, playerX: speeder.x, playerY: speeder.altitude, time: time)
                if beaconHits > 0 { flash = max(flash, 0.2); ackTimers.beacon = 0.6; gamepad.rumble(intensity: 0.5, sharpness: 0.9) }
            }
            missions.update(dt: simDt, travel: speed * simDt, speed: speed, newHits: hits - missionHitsSeen, boosting: input.boosting && missions.boostAllowed,
                            scraping: speeder.scraping && speed > 5, newKills: kills - missionKillsSeen, beaconsHitNow: beaconHits)
            missionHitsSeen = hits
            missionKillsSeen = kills
            if missions.isRunning, let s = missions.scoredNow { stamp(s.streak > 1 ? "+\(s.value)  x\(s.streak)" : "+\(s.value)", seconds: 0.6) }
            if missions.respawnedNow {
                let left = missions.snapshot().respawnsLeft
                stamp("HULL RESTORED  \(left) LEFT", seconds: 1.4)
                flash = 1.0; invulnerable = 1.5
                gamepad.rumble(intensity: 0.8, sharpness: 0.3)
            }
            if let pursuer {
                if missions.isRunning { pursuer.update(gap: missions.snapshot().gap, playerX: speeder.x, time: time) } else { pursuer.hide() }
            }
            if missions.phase != mission.phase || missions.phase == .running && statsAccumulator > 0.2 { mission = missions.snapshot() }
            contactAvatar?.root.isEnabled = missions.phase != .running
            if missions.phase != .running { contactAvatar?.face(cameraRig.position) }
            if demoMode && Int(time * 4) % 4 == 0 && statsAccumulator > 0.2, let a = contactAvatar { print("avatar \(a.debugBounds())") }
        }
        let moving = settings.roadMotion && (!missionActive || missions.allowsMotion)
        let boosting = moving && input.boosting && (!missionActive || missions.boostAllowed)
        if boosting && !boostPrev {
            // boost onset: camera kick, haptic and the HUD pip on the same frame
            cameraRig.punch(1.0)
            gamepad.rumble(intensity: 0.5, sharpness: 0.5)
        }
        boostPrev = boosting
        let target = moving ? settings.cruiseSpeed * (boosting ? 1.8 : 1.0) : 0
        speed = damp(speed, target, target > speed ? 1.6 : 2.0, simDt)
        let speedNorm = clamp01(speed / maxSpeed)

        let travel = speed * simDt
        world.advance(travel, playerX: speeder.x, time: time)
        distance += travel
        speeder.tube = WorldScroller.tubeGeometry
        speeder.tubeBlend = world.tubeBlend
        speeder.wedgeLimit = world.wedgeLimit
        post.enclosure = world.enclosure
        // section stamp when the player crosses into a new kind of section
        let style = world.currentBlock.style
        if style != lastStyle {
            if lastStyle != nil, let label = Self.sectionStamp(style) { stamp(label) }
            lastStyle = style
        }
        let parked = missionActive && !missions.allowsMotion
        speeder.update(dt: simDt, time: time, steerInput: parked ? 0 : input.steering, climbInput: parked ? 0 : input.climb, speedNorm: speedNorm, roadShift: world.lastShift * world.tugFactor / 0.6)

        // barrier scraping: bleed speed, sparks, shake
        if speeder.scraping && speed > 5 {
            speed *= 1 - 0.7 * dt
            shakeBurst = max(shakeBurst, 0.25)
            let sparkPos: SIMD3<Float> = world.tubeBlend < 0.5
                ? [speeder.root.position.x + (speeder.x > 0 ? 1.0 : -1.0), 0.6, 0.5]
                : speeder.root.position + simd_normalize(SIMD3<Float>(speeder.x, speeder.altitude - RoadSegment.tubeCenterY, 0)) * 1.1
            emitSparks(at: sparkPos, duration: 0.1)
            if Int(time * 10) % 3 == 0 { gamepad.rumble(intensity: 0.3, sharpness: 0.8) }
        }
        // obstacle collisions (AABB in world space; speeder half extents 0.95 x 1.6)
        invulnerable = max(0, invulnerable - dt)
        if settings.obstacles && invulnerable <= 0 {
            for (o, p) in world.nearbyObstacles() {
                if abs(p.x - speeder.x) < o.halfWidth + 0.95 && abs(p.z) < o.halfLength + 1.6
                    && abs(p.y + o.centerY - speeder.altitude) < o.halfHeight + speeder.halfHeight {
                    o.active = false
                    o.entity.isEnabled = false
                    hits += 1
                    invulnerable = 1.0
                    flash = 1.0
                    shakeBurst = 1.0
                    speed *= 0.6
                    hitStop = 0.07
                    ackTimers.hit = 0.5
                    speeder.recoil(direction: speeder.x >= p.x ? 1 : -1)
                    emitSparks(at: [p.x, p.y + o.centerY, p.z], duration: 0.18)
                    weapons?.explode(at: [p.x, p.y + o.centerY, p.z])
                    gamepad.rumble(intensity: 1.0, sharpness: 0.4)
                    break
                }
            }
        }
        // weapons
        if let weapons {
            if input.firing && settings.obstacles && !parked {
                if weapons.fire(from: speeder.root.position, orientation: speeder.root.orientation) {
                    shakeBurst = max(shakeBurst, 0.08)
                    ackTimers.fire = 0.15
                    gamepad.rumble(intensity: 0.25, sharpness: 1.0)
                }
            }
            let targets = world.nearbyObstacles(segments: 4)
            weapons.update(dt: simDt) { tip in
                for (o, p) in targets where o.active {
                    let c = SIMD3<Float>(p.x, p.y + o.centerY, p.z)
                    if abs(tip.x - c.x) < o.halfWidth + 0.3 && abs(tip.y - c.y) < o.halfHeight + 0.3 && abs(tip.z - c.z) < o.halfLength + 1.2 {
                        if o.destructible {
                            o.active = false
                            o.entity.isEnabled = false
                            weapons.explode(at: c)
                            kills += 1
                            shakeBurst = max(shakeBurst, 0.2)
                            gamepad.rumble(intensity: 0.5, sharpness: 0.9)
                        } else {
                            emitSparks(at: tip, duration: 0.08)
                        }
                        return true
                    }
                }
                return false
            }
        }
        flash = max(0, flash - dt * 3.5)
        shakeBurst = max(0, shakeBurst - dt * 2.5)
        sparkTimer -= dt
        if sparkTimer <= 0, var e = sparks.components[ParticleEmitterComponent.self], e.isEmitting {
            e.isEmitting = false
            sparks.components.set(e)
        }
        post.flash = flash
        if flash > 0 && stats.flash != flash { stats.flash = flash }

        let curveAhead = world.offset(atWorldZ: -14) - world.playerOffset
        // the camera follows the smooth bank and only a little of the collision jolt
        let camBank = speeder.smoothBank + (speeder.bank - speeder.smoothBank) * 0.4
        if corridorOverview {
            cameraRig.overviewCorridor(speederX: speeder.x)
        } else {
            cameraRig.update(dt: dt, time: time, speederX: speeder.x, speederY: speeder.altitude, bank: camBank, speedNorm: speedNorm,
                             shake: settings.cameraShake, curveAhead: curveAhead, extraShake: shakeBurst, inTube: world.tubeBlend,
                             frameShift: parked ? -2.2 : 0)
        }

        // speed particles follow the vehicle speed (none while parked)
        if settings.particles, var e = speedParticles.components[ParticleEmitterComponent.self] {
            e.speed = 20 + speed * 0.9
            e.mainEmitter.birthRate = speed < 4 ? 0 : 80 + speedNorm * 360
            speedParticles.components.set(e)
        }

        // post-process uniforms
        post.speedNorm = speedNorm
        post.kick = cameraRig.kickLevel
        ackBoost = boosting
        if let vp = arView.project([cameraRig.position.x, cameraRig.position.y, -900]) {
            let size = arView.bounds.size
            if size.width > 0 && size.height > 0 {
                post.vanishing = [Float(vp.x / size.width), Float(vp.y / size.height)]
            }
        }

        // stats (cheap, quarter-second cadence)
        fpsSmoothed = fpsSmoothed * 0.9 + (1.0 / Double(max(rawDt, 1e-4))) * 0.1
        statsAccumulator += dt
        if statsAccumulator > 0.25 {
            statsAccumulator = 0
            if demoMode && Int(time * 4) % 4 == 0 {
                let ms = missions.snapshot()
                print(String(format: "t=%.1f fps=%.0f speed=%.0f m/s entities=%d dist=%.0f mission=%@ beacons=%d/%d gap=%.0f hull=%.2f", time, fpsSmoothed, speed, entityCount, distance, "\(ms.phase)", ms.beaconsHit, ms.beaconsTotal, ms.gap, ms.energy) + " beacon " + (beacons?.debugNearest ?? "-") + String(format: " player x=%.1f alt=%.1f", speeder.x, speeder.altitude) + " proj=\(beacons.flatMap { _ in arView.project(beaconProbe) }.map { "\($0)" } ?? "-") view=\(arView.bounds.size)")
            }
            if entityCount == 0 { entityCount = count(worldAnchor) }
            stats = FrameStats(fps: fpsSmoothed, frameMs: Double(rawDt) * 1000, speed: speed,
                               entities: entityCount, lights: settings.realLights ? 5 : 0,
                               sourceFormat: post.sourceFormat, distance: distance, hits: hits,
                               section: world.currentBlock.name, flash: flash, decision: world.lastDecision,
                               kills: kills, altitude: speeder.altitude, controller: gamepad.connectedName)
        }
        publishAck(dt: dt)
    }

    private var ackBoost = false

    /// Centre-screen stamp text for a section entry.
    private static func sectionStamp(_ style: SegmentStyle) -> String? {
        switch style {
        case .tube: return "CONDUIT"
        case .tunnel: return "UNDERCITY"
        case .elevated: return "SKYWAY"
        case .fork: return "SPLIT"
        default: return nil
        }
    }

    private func stamp(_ text: String, seconds: Float = 0.7) {
        stampText = text
        ackTimers.stamp = seconds
    }

    /// Decay the action timers and publish the HUD acknowledgement only when it changed.
    private func publishAck(dt: Float) {
        ackTimers.fire = max(0, ackTimers.fire - dt); ackTimers.jump = max(0, ackTimers.jump - dt)
        ackTimers.pickup = max(0, ackTimers.pickup - dt); ackTimers.snap = max(0, ackTimers.snap - dt)
        ackTimers.beacon = max(0, ackTimers.beacon - dt); ackTimers.hit = max(0, ackTimers.hit - dt)
        ackTimers.stamp = max(0, ackTimers.stamp - dt); ackTimers.boost = max(0, ackTimers.boost - dt)
        let a = ActionAck(boost: ackBoost || ackTimers.boost > 0, fire: ackTimers.fire > 0, jump: ackTimers.jump > 0, pickup: ackTimers.pickup > 0,
                          snap: ackTimers.snap > 0, beacon: ackTimers.beacon > 0, hit: ackTimers.hit > 0,
                          stamp: ackTimers.stamp > 0 ? stampText : "")
        if a != ack { ack = a }
    }

    /// The curtain closes before a rebuild, the rebuild runs behind it, and it opens after `build()`.
    private func updateCurtain(dt: Float) {
        curtain = damp(curtain, curtainTarget, curtainTarget > curtain ? 9 : 5, dt)
        if curtainTarget > 0.5 && curtain > 0.97 { curtain = 1 }
        if curtainTarget < 0.5 && curtain < 0.01 { curtain = 0 }
        post.curtain = curtain
        if pendingRebuild && curtain >= 1 {
            pendingRebuild = false
            Task { await rebuildScene() }
        }
    }

    #if os(iOS)
    /// Touch steering from SwiftUI: leftmost active touch steers/climbs, two fingers boost.
    func handleTouches(_ events: SpatialEventCollection, in size: CGSize) {
        let active = events.filter { $0.phase == .active }
        let input = arView.input
        guard let first = active.min(by: { $0.location.x < $1.location.x }), size.width > 0, size.height > 0 else {
            input.pointerSteer = nil
            input.pointerClimb = nil
            input.pointerBoost = false
            return
        }
        let nx = Float(first.location.x / size.width) - 0.5
        let ny = 0.5 - Float(first.location.y / size.height)
        input.pointerSteer = max(-1, min(1, nx * 2.6))
        input.pointerClimb = max(-1, min(1, ny * 2.6))
        input.pointerBoost = active.count >= 2
    }
    #endif

    func saveScreenshot(to url: URL) {
        post.captureRequest = { image in
            guard let image else { print("screenshot failed"); return }
            let ok = FrameCapture.writePNG(image, to: url)
            print("screenshot \(ok ? "saved" : "FAILED"): \(url.path)")
        }
    }

    private func count(_ e: Entity) -> Int { 1 + e.children.reduce(0) { $0 + count($1) } }

    /// Missions run in the corridor worlds when the toggle is on.
    private var missionActive: Bool { settings.missions && missions.current.theme.rawValue == settings.environment }

    /// Free play: the result card's A / F / tap restarts the match against the next rival.
    private func restartArenaMatch(_ arena: ArenaController) {
        matchResult = nil
        arena.restartMatch()
        cameraRig?.resetArena()
    }

    /// Accept the briefing or continue past a result (also called by the HUD tap).
    func acceptMission() {
        if let arena, arena.awaitingRestart, !missionActive { restartArenaMatch(arena); return }
        guard missionActive else { return }
        let wasBriefing = missions.phase == .briefing
        let rebuild = missions.accept()
        mission = missions.snapshot()
        if wasBriefing && missions.phase == .running {
            // launch: the same kick as a boost, plus the stamp
            cameraRig?.punch(0.8)
            gamepad.rumble(intensity: 0.6, sharpness: 0.4)
            stamp("GO", seconds: 0.6)
        }
        if rebuild {
            let theme = missions.current.theme
            if theme.rawValue != settings.environment {
                var s = settings
                s.environment = theme.rawValue
                theme.adjust(&s)
                settings = s          // didSet closes the curtain and rebuilds
            } else {
                requestRebuild()
            }
        }
    }

    private func handleCommonInput(_ input: InputState) {
        if input.panelToggleRequested {
            input.panelToggleRequested = false
            panelVisible.toggle()
        }
        if input.screenshotRequested {
            input.screenshotRequested = false
            saveScreenshot(to: FrameCapture.defaultURL())
        }
    }

    private func handleCaptures() {
        if let captureDir {
            if sweepMode {
                if let step = sweepSteps.first, time >= step.0 {
                    sweepSteps.removeFirst()
                    let url = URL(fileURLWithPath: captureDir).appendingPathComponent("\(step.1).png")
                    if step.1 == "source" {
                        post.captureSourceRequest = { image in
                            if let image { FrameCapture.writePNG(image, to: url); print("saved \(url.path)") }
                        }
                    } else {
                        saveScreenshot(to: url)
                    }
                    var s = settings; step.2(&s); settings = s
                }
            } else if let next = captureTimes.first, time >= next {
                captureTimes.removeFirst()
                let name = next == next.rounded() ? "frame-\(Int(next))" : String(format: "frame-%.1f", next)
                saveScreenshot(to: URL(fileURLWithPath: captureDir).appendingPathComponent("\(name).png"))
            }
        }
    }

    // MARK: - The Grid

    /// Arena frame: map input to cycle commands (with edge detection), run the arena,
    /// drive the spring camera, post uniforms and stats.
    private func updateArena(_ arena: ArenaController, dt: Float, rawDt: Float, input: InputState, cameraRig: CameraRig) {
        var cmd = CycleInput()
        var aiCmd: CycleInput? = nil
        if demoMode {
            cmd = arenaDemoInput(arena: arena)
        } else {
            let steer = input.steering
            let climb = input.climb
            cmd.steer = steer
            cmd.snapLeft = steer < -0.5 && arenaPrev.steer >= -0.5
            cmd.snapRight = steer > 0.5 && arenaPrev.steer <= 0.5
            cmd.boost = input.boosting
            cmd.brake = climb < -0.5
            cmd.jump = climb > 0.5 && arenaPrev.climb <= 0.5
            cmd.action = input.firing && !arenaPrev.fire
            arenaPrev = (steer, climb, input.firing)
        }
        handleCommonInput(input)
        handleCaptures()
        if demoMode, let script = ProcessInfo.processInfo.environment["SPEEDER_DEMO_SCRIPT"], script == "noai" { aiCmd = CycleInput() }
        if missionActive {
            // duel: the briefing holds the arena; A / F / tap accepts, the arena's score decides the job
            let fire = input.firing || (demoMode && time > 1.5 && !holdBriefing)
            if fire && !missionFirePrev && missions.phase != .running { acceptMission() }
            missionFirePrev = fire
            arena.paused = missions.phase != .running
            arena.matchTarget = Int.max
            if let r = missions.current.rival { arena.rival = r }
            missions.updateDuel(dt: dt, wins: arena.wins, losses: arena.losses)
            if missions.phase != mission.phase || statsAccumulator > 0.2 { mission = missions.snapshot() }
            if missions.phase != .running { cmd = CycleInput() }
        }
        if arena.awaitingRestart && cmd.action && !missionActive { restartArenaMatch(arena) }
        if cmd.boost && !boostPrev && arena.energy > 0.02 { cameraRig.punch(1.0); gamepad.rumble(intensity: 0.5, sharpness: 0.5) }
        boostPrev = cmd.boost && arena.energy > 0.02
        arena.update(dt: dt, time: time, input: cmd, aiInput: aiCmd)
        let ev = arena.events
        if ev.snapped { ackTimers.snap = 0.2 }
        if ev.jumped { ackTimers.jump = 0.35 }
        if ev.pickupUsed != nil { ackTimers.pickup = 0.4; stamp(ev.pickupUsed == .phase ? "PHASE" : "PULSE", seconds: 0.6) }
        if ev.pickupTaken { ackTimers.pickup = 0.3 }
        if ev.padBoost { ackTimers.boost = 0.3; stamp("SURGE", seconds: 0.5) }
        if ev.padSlow { ackTimers.hit = 0.4 }
        if ev.charged { ackTimers.boost = 0.4; stamp("CHARGE", seconds: 0.6) }
        if ev.zoneOpened { stamp("ZONE", seconds: 1.2) }
        // round and match beats: one stamp each, on the frame they happen
        if ev.roundWon { stamp("\(arena.rivalName) DEREZZED", seconds: 2.2) }
        if ev.roundLost { stamp("DEREZZED", seconds: 2.2) }
        if ev.matchWon { stamp("MATCH WON  \(arena.wins) - \(arena.losses)", seconds: 3.4) }
        if ev.matchLost { stamp("MATCH LOST  \(arena.wins) - \(arena.losses)", seconds: 3.4) }
        if ev.roundStart && !ev.matchWon && !ev.matchLost { stamp(arena.matchTarget == Int.max ? "READY" : "ROUND \(arena.roundNumber)", seconds: 1.0) }
        if ev.go { stamp("GO", seconds: 0.5) }
        if ev.matchResult, let r = arena.matchResult {
            missions.award(r.credits)
            matchResult = r
            mission.credits = missions.credits      // free play: only the purse changes, no job card
        }
        ackBoost = boostPrev

        let player = arena.player
        let speedNorm = arena.speedNorm
        speed = player.speed
        shakeBurst = max(shakeBurst, arena.shake)
        flash = arena.flash
        post.flash = flash
        if flash > 0 && stats.flash != flash { stats.flash = flash }
        shakeBurst = max(0, shakeBurst - dt * 2.5)
        cameraRig.followArena(dt: dt, time: time, position: player.position + [0, 1.05, 0], forward: player.forward, lean: player.lean,
                              speedNorm: speedNorm, shake: settings.cameraShake, extraShake: shakeBurst, orbit: arena.cameraOrbit,
                              overview: overviewCamera, ground: arena.groundHeight, side: sideCamera)
        arena.placeRivalTag(camera: cameraRig.position)
        if settings.particles, var e = speedParticles.components[ParticleEmitterComponent.self] {
            e.speed = 20 + player.speed * 0.9
            e.mainEmitter.birthRate = 40 + speedNorm * 300
            speedParticles.components.set(e)
        }
        post.speedNorm = speedNorm * 0.8
        post.kick = cameraRig.kickLevel
        // vanishing point for the streaks: where the cycle is heading, far ahead
        if let vp = arView.project(player.position + player.forward * 400 + [0, 1.0, 0]) {
            let size = arView.bounds.size
            if size.width > 0 && size.height > 0 {
                post.vanishing = [Float(max(0.1, min(0.9, vp.x / size.width))), Float(max(0.1, min(0.9, vp.y / size.height)))]
            }
        }
        distance += player.speed * dt
        fpsSmoothed = fpsSmoothed * 0.9 + (1.0 / Double(max(rawDt, 1e-4))) * 0.1
        statsAccumulator += dt
        if statsAccumulator > 0.25 {
            statsAccumulator = 0
            if demoMode && Int(time * 4) % 2 == 0 {
                let o = arena.opponent
                print(String(format: "t=%.2f fps=%.0f speed=%.0f m/s pos=(%.1f,%.1f) y=%.2f grind=%.2f edge=%.2f energy=%.2f segs=%d rival=(%.1f,%.1f) ry=%.1f rspeed=%.0f state=%@ %@", time, fpsSmoothed, player.speed, player.position.x, player.position.z, player.position.y, arena.grind, arena.edge, arena.energy, arena.trailSegmentCount, o.position.x, o.position.z, o.position.y, o.speed, arena.stateText, arena.lastRivalCause))
            }
            if entityCount == 0 { entityCount = count(worldAnchor) }
            var st = FrameStats(fps: fpsSmoothed, frameMs: Double(rawDt) * 1000, speed: player.speed,
                                entities: entityCount, lights: settings.realLights ? 5 : 0,
                                sourceFormat: post.sourceFormat, distance: distance, hits: arena.losses,
                                section: "the grid - \(arena.levelName)", flash: flash, decision: nil,
                                kills: arena.wins, altitude: player.position.y, controller: gamepad.connectedName)
            st.energy = arena.energy; st.edge = arena.edge; st.grind = arena.grind
            st.state = arena.phaseActive ? "PHASE ACTIVE" : arena.stateText
            st.zone = arena.zoneText
            st.pickup = arena.heldPickup?.rawValue
            st.wins = arena.wins; st.losses = arena.losses; st.trailSegments = arena.trailSegmentCount
            st.round = arena.roundNumber; st.rival = arena.rivalName; st.matchTarget = arena.matchTarget
            stats = st
        }
    }

    /// Scripted arena drives for captures. SPEEDER_DEMO_SCRIPT selects one; times are
    /// seconds since the round started running.
    private func arenaDemoInput(arena: ArenaController) -> CycleInput {
        var c = CycleInput()
        let t = arena.runSeconds
        let script = ProcessInfo.processInfo.environment["SPEEDER_DEMO_SCRIPT"] ?? "drive"
        func snapAt(_ times: [(Float, Bool)]) {
            for (when, right) in times where t >= when && arenaPrev.steer < when {
                if right { c.snapRight = true } else { c.snapLeft = true }
            }
            arenaPrev.steer = t
        }
        switch script {
        case "snap":
            snapAt([(2.0, true), (3.2, true), (4.2, false), (5.0, false), (6.4, true), (7.6, true), (9.0, false), (10.5, true), (12.0, true)])
            c.boost = t > 8.5 && t < 11
        case "crash":
            // (snap mode) a closed box: the fourth leg meets the first wall square on
            snapAt([(2.0, true), (2.6, true), (3.2, true), (3.8, true)])
        case "grind":
            // start beside the western hazard wall (SPEEDER_ARENA_START=-44,22,0) and hug it
            c.steer = 0
        case "jumpback":
            // jump, then a U-turn so the camera sees the jumped section of trail from the side
            c.jump = t > 1.55 && t < 1.65
            c.steer = t > 2.4 && t < 4.0 ? 1 : 0
        case "pulse", "phase":
            // U-turn, then use the held pickup (SPEEDER_ARENA_GIVE) when facing the own trail
            c.steer = t > 2.4 && t < 4.0 ? 1 : 0
            c.action = t > 4.4 && t < 4.5
        case "uturn":
            c.steer = t > 2.4 && t < 4.0 ? 1 : 0
        case "ramp":
            // (start -52,70,0) straight up the west on-ramp onto the deck, right along it, down the east off-ramp
            snapAt([(3.3, true), (6.2, true)])
            c.boost = t > 6.5
        case "garage":
            // (start -20,60,0) straight under the deck between the columns
            c.steer = 0
        case "jump":
            c.jump = t > 1.55 && t < 1.65
            c.steer = 0
        case "jumpover":
            c.jump = t > 0.72 && t < 0.8
        case "wall":
            c.steer = 0
            c.boost = t > 1
        default:
            c.steer = t < 1.5 ? 0 : (t < 4.0 ? 0.6 : (t < 6.5 ? -0.75 : (t < 8 ? 0 : 0.5 * sin(t * 1.3))))
            c.boost = t > 6.5 && t < 9.5
            c.brake = t > 11 && t < 12
        }
        return c
    }
}
