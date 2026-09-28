import Foundation
import QuartzCore
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
            if settings.gridPalette != oldValue.gridPalette, arena != nil { requestRebuild() }
            if settings.environment != oldValue.environment, world != nil || arena != nil {
                var s = settings
                (Theme(rawValue: s.environment) ?? .neonCity).adjust(&s)
                if !demoMode { prefs.apply(to: &s) }
                settings = s
                requestRebuild()
                return
            }
            // a cruise-speed nudge is per frame while the key is held: it does not re-apply the world
            var a = settings, b = oldValue
            a.cruiseSpeed = 0; b.cruiseSpeed = 0
            if a == b { return }
            applySettings()
        }
    }
    /// Synthesised sound: cues on the same frame as the visual and haptic acks, loops per frame.
    let sound = SoundEngine()
    /// The controls hint shows for the first half minute and whenever the settings panel opens.
    @Published var hintVisible = true
    var hintTimer: Float = 0
    /// Button art for the connected pad (published when it changes).
    @Published var glyphs = ControllerGlyphs()
    private var lastTickSecond = -1
    /// Edge detection for the briefing's inbox (steer) and garage (climb, buy) controls.
    private var briefPrev = (steer: Float(0), climb: Float(0), buy: false)
    private var lastUpcoming: String? = nil
    #if os(iOS)
    private var touchStarts: [SpatialEventCollection.Event.ID: (CGPoint, Double)] = [:]
    #endif
    @Published var stats = FrameStats()
    @Published var loadError: String? = nil
    /// Same-frame action acknowledgement for the HUD.
    @Published var ack = ActionAck()
    private var ackTimers = (fire: Float(0), jump: Float(0), pickup: Float(0), snap: Float(0), beacon: Float(0), hit: Float(0), stamp: Float(0), boost: Float(0))
    private var stampText = ""
    /// Comms: the contact's line in the ear, at most three per job (launch, one event, the last stretch).
    private var commsTimer: Float = 0
    private var commsSpeaker = "", commsText = ""
    private var commsSlots = (launch: false, event: false, last: false)
    /// The rival's line in a duel, queued until the derez stamp has cleared (one per round at most).
    private var rivalComms: (speaker: String, text: String, delay: Float)? = nil
    private var rivalCommsRound = -1
    private var runClock: Float = 0
    /// The rider's identity, published for the HUD.
    @Published var player = Player()
    /// The screen stack (see `Screen`, `FrontEnd.swift`): the splash, then the title, its sub screens,
    /// the game, a pause. The demo and `SPEEDER_TITLE=0` start in the game (captures); `SPEEDER_TITLE=1`
    /// keeps the front end in the demo.
    @Published var screens: [Screen] = {
        let env = ProcessInfo.processInfo.environment
        if env["SPEEDER_TITLE"] == "0" || (env["SPEEDER_DEMO"] == "1" && env["SPEEDER_TITLE"] != "1" && env["SPEEDER_SCREEN"] == nil) { return [.game] }
        return [.loading]
    }()
    /// The highlighted row of the current screen's list (restored when a screen is popped).
    @Published var menuIndex = 0
    var indexStack: [Int] = []
    /// The player's persisted settings (music / effects / haptics / graphics / steering).
    @Published var prefs = PlayerPrefs.load(.standard)
    /// The world is built and the curtain is opening (false while building or rebuilding).
    @Published var worldReady = false
    /// The splash loader's stage (label, target fill, expected seconds).
    @Published var loadStage = LoadStage()
    /// A pad callsign edit in progress on the rider screen.
    @Published var callsignEdit: CallsignEdit? = nil
    /// RESET PROGRESS was pressed once; the next press resets.
    @Published var resetArmed = false
    /// The rider screen was opened by the first START (RIDE goes on to the first briefing).
    @Published var riderFirstRun = false
    var devTaps = 0
    var navHold: (dir: Int, t: Float) = (0, 0)
    var navPrev: (select: Bool, back: Bool) = (false, false)
    /// The world was built for the job loop (its track, contact and props), not for free play.
    var builtForJobs = false
    /// 0 ... 1: the title camera drift's share of the framing.
    private var titleMix: Float = 0
    private var lastStyle: SegmentStyle? = nil
    private var boostPrev = false
    /// Held boost, eased: 150 ms in, 400 ms out. One scalar for the post pass, the exhaust and the HUD.
    private var boostLevel: Float = 0
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
    /// The developer panel: hidden from players (five taps on the version line in SETTINGS unlock it;
    /// the Mac has it unlocked, with ` as a toggle). `SPEEDER_PANEL=1` opens it at launch.
    @Published var panelVisible = ProcessInfo.processInfo.environment["SPEEDER_PANEL"] == "1"

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
    /// Rain (screen-space, in the post pass) and the lightning clock.
    private var rainLevel: Float = 0
    /// Showers: the rain comes and goes. `SPEEDER_RAIN=always|showers|heavy|0`; the demo keeps `always` so
    /// captures align. Otherwise chapter 3 gets heavy showers that also thicken the fog (the streets
    /// close in), everything else light showers.
    private enum RainMode { case off, always, showers, heavy }
    private var showerOn = true
    private var showerTimer: Float = 12
    private var rainMode: RainMode {
        switch ProcessInfo.processInfo.environment["SPEEDER_RAIN"] {
        case "0": return .off
        case "always": return .always
        case "showers": return .showers
        case "heavy": return .heavy
        default: break
        }
        if demoMode { return .always }
        return missionActive && missions.current.chapter >= 3 ? .heavy : .showers
    }
    /// SPEEDER_LIGHTNING_AT=<s> forces the first flash at that scene time (captures).
    private var lightningTimer: Float = Float(ProcessInfo.processInfo.environment["SPEEDER_LIGHTNING_AT"] ?? "") ?? 7
    private var lightning: Float = 0
    private var weatherRNG = SeededRNG(seed: 4242)
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
    let gamepad = GamepadInput()
    private var weapons: WeaponSystem?
    private var kills = 0
    private var sparkTimer: Float = 0
    /// SPEEDER_DEMO=1 scripts steering/boost; SPEEDER_CAPTURE_DIR=<dir> saves frames at fixed times.
    let demoMode = ProcessInfo.processInfo.environment["SPEEDER_DEMO"] == "1"
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
        if !demoMode { prefs.apply(to: &settings) }
        titleMix = onTitle ? 1 : 0             // the demo starts in the game: no drift in the first frames
        sound.musicVolume = Float(prefs.music) / 10
        sound.effectsVolume = Float(prefs.effects) / 10
        gamepad.enabled = prefs.haptics
        mission = missionActive ? missions.snapshot() : MissionState()
        Task { await build() }
    }

    /// SPEEDER_VARIANT=<name> applies a look preset at launch (used by the comparison sweep).
    private func applyVariantPreset() {
        if let g = ProcessInfo.processInfo.environment["SPEEDER_GRID_PALETTE"], let i = Theme.gridPaletteNames.firstIndex(of: g) { settings.gridPalette = i }
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
    func requestRebuild() {
        curtainTarget = 1
        pendingRebuild = true
    }

    /// Tear down and rebuild the world for the selected theme (behind the curtain).
    private func rebuildScene() async {
        guard !rebuilding else { return }
        rebuilding = true
        worldReady = false
        lastStyle = nil
        world = nil; arena = nil; speeder = nil; cameraRig = nil; weapons = nil; contactAvatar = nil; beacons = nil; pursuer = nil
        for child in worldAnchor.children.map({ $0 }) { child.removeFromParent() }
        entityCount = 0
        post.captureRequest = nil
        await build()
        rebuilding = false
        if missions.autoStart {
            // one-tap retry: the failed card's accept rebuilt the job; launch it as the curtain opens
            missions.autoStart = false
            acceptMission()
        }
    }

    private func build() async {
        let t0 = CACurrentMediaTime()
        func mark(_ stage: String) { print(String(format: "load: %@ %.2f s (%.2f s since launch)", stage, CACurrentMediaTime() - t0, CACurrentMediaTime() - SpeederApp.launchTime)) }
        worldReady = false
        let buildTheme = Theme(rawValue: settings.environment) ?? .neonCity
        // the splash loader: three stages, each expected to take what it took last time on this device
        let d = UserDefaults.standard
        let keys = ["surfaces", "vehicle", "world"]
        let fallback: [Double] = [1.0, 0.6, buildTheme == .theGrid ? 0.6 : 2.2]
        let expected = keys.indices.map { i -> Double in
            let k = "load.\(buildTheme.rawValue).\(keys[i])"
            return d.object(forKey: k) == nil ? fallback[i] : max(0.05, d.double(forKey: k))
        }
        let total = expected.reduce(0, +)
        var stageStart = CACurrentMediaTime()
        var stageIndex = -1
        func stage(_ i: Int, _ label: String) async {
            if stageIndex >= 0 { d.set(CACurrentMediaTime() - stageStart, forKey: "load.\(buildTheme.rawValue).\(keys[stageIndex])") }
            stageIndex = i
            stageStart = CACurrentMediaTime()
            guard i < keys.count else { loadStage = LoadStage(id: loadStage.id + 1, label: "READY", to: 1, seconds: 0.25); return }
            let to = Float(expected[0...i].reduce(0, +) / total) * 0.96
            loadStage = LoadStage(id: loadStage.id + 1, label: label, to: to, seconds: expected[i] * 1.1)
            // let the splash draw the stage (and start its fill) before the next block of main-thread work
            if screens.first == .loading { try? await Task.sleep(nanoseconds: 30_000_000) }
        }
        do {
            theme = buildTheme
            post.theme = theme
            // weather belongs to the world: without this the canyon and The Grid kept Neon City's rain
            // (post.rain is only written where it rains) after any in-app world change
            rainLevel = 0; lightning = 0
            post.rain = 0; post.lightning = 0
            await stage(0, "SURFACES")
            sound.setMusic(world: theme.rawValue)
            let device = MTLCreateSystemDefaultDevice()
            mark("start")
            // the arena's accent: the rival's colour family in a duel (KADE cyan, ORIN violet, SABLE amber, VESS
            // red), the developer setting otherwise; SPEEDER_GRID_PALETTE forces one
            Theme.gridPalette = settings.gridPalette
            if theme == .theGrid, missionActive, let r = missions.current.rival, ProcessInfo.processInfo.environment["SPEEDER_GRID_PALETTE"] == nil {
                Theme.gridPalette = ["KADE": 0, "ORIN": 3, "SABLE": 2, "VESS": 1][r.name] ?? settings.gridPalette
            }
            let materials = try SceneMaterials(device: device, theme: theme)
            self.materials = materials
            mark("materials")
            await stage(1, "VEHICLE")

            arView.environment.lighting.resource = materials.environment
            arView.environment.lighting.intensityExponent = theme.iblExponent
            arView.environment.background = .skybox(materials.environment)

            let speeder = try await SpeederController.load(materials: materials)
            mark("vehicle")
            await stage(2, theme.displayName)
            worldAnchor.addChild(speeder.root)
            self.speeder = speeder
            player = missions.player
            if player.tintsBike { speeder.tint(player.liveryColor, materials: materials) }
            ArenaController.playerColor = player.liveryColor

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
                mark("track")
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
                        mark("contact")
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

            mark("world")
            await stage(3, "")
            arView.scene.addAnchor(worldAnchor)
            applySettings()
            curtainTarget = 0
            builtForJobs = missionActive
            worldReady = true
            updateSub = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] ev in
                self?.update(dt: Float(ev.deltaTime))
            }
            if screens.first == .loading {
                // the splash hands over as the curtain opens: the wordmark flies to its place on the title
                try? await Task.sleep(nanoseconds: 350_000_000)
                screens = initialScreens()
                menuIndex = 0
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
        sound.enabled = settings.sound
        sound.musicEnabled = settings.music
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
        updateCurtain(dt: dt)
        let input = arView.input
        gamepad.poll(into: input)
        if gamepad.glyphs != glyphs { glyphs = gamepad.glyphs; hintVisible = true; hintTimer = 0 }
        // the front end owns the pad and the keys; in a run, Menu / Escape pauses
        if screen != .game {
            if demoMode { input.menuRequested = false } else { frontEndInput(input, dt: dt) }
        } else if input.menuRequested {
            input.menuRequested = false
            pause()
        }
        titleMix = damp(titleMix, onTitle ? 1 : 0, onTitle ? 0.9 : 1.8, dt)
        if simFrozen {
            // paused: the frame holds, the loops fall silent (they need re-asserting each frame), the pad plays
            missionFirePrev = input.firing
            arenaPrev.fire = input.firing
            sound.setMusic(intensity: 0.4)
            gamepad.engineHum(intensity: 0, sharpness: 0)
            handleCommonInput(input)
            publishAck(dt: dt)
            return
        }
        time += dt
        hintTimer += dt
        if hintVisible && hintTimer > 8 && !panelVisible { hintVisible = false }
        // no job loop here (free play, or a world the current job does not use): no stale card
        if !missionActive && mission.phase != .freePlay { mission = MissionState() }
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
            input.fire = (missionActive && missions.phase != .running) ? (time > 1.5 && !holdBriefing && !(holdResult && !missions.isParked) && Int(time * 2) % 3 == 0) : Int(time * 2) % 3 == 0
            let demoBoost = ProcessInfo.processInfo.environment["SPEEDER_DEMO_BOOST"]
            input.pointerBoost = demoBoost == "always" || (time > 6.5 && time < 11 && demoBoost != "0")
        }
        handleCommonInput(input)
        handleCaptures()

        // throttle: cruise speed adjusted with up/down, boost multiplies
        // (locked while the job loop is on: the timers and the pursuer are tuned to the job's cruise,
        // and Y / ] is the garage's buy button on the briefing)
        let cruiseLocked = missionActive
        if input.speedUp && !cruiseLocked { settings.cruiseSpeed = min(110, settings.cruiseSpeed + 30 * dt) }
        if input.speedDown && !cruiseLocked { settings.cruiseSpeed = max(15, settings.cruiseSpeed - 30 * dt) }
        // missions: A / F / tap accepts a briefing or a result; the vehicle only moves during a live job
        if missionActive {
            // the job loop runs under the title too (parked, briefed); only the game takes the accept
            let fire = input.firing
            if screen == .game {
                if fire && !missionFirePrev && missions.phase != .running { acceptMission() }
                briefingInput(input)
            }
            missionFirePrev = fire
            var beaconHits = 0
            if let beacons, missions.isRunning {
                beaconHits = beacons.update(distance: distance, roadX: { world.offset(atWorldZ: $0) - world.playerOffset }, playerX: speeder.x, playerY: speeder.altitude, time: time)
                if beaconHits > 0 { flash = max(flash, 0.2); ackTimers.beacon = 0.6; gamepad.rumble(intensity: 0.5, sharpness: 0.9); sound.play(.beacon) }
            }
            missions.update(dt: simDt, travel: speed * simDt, speed: speed, newHits: hits - missionHitsSeen, boosting: input.boosting && missions.boostAllowed,
                            scraping: speeder.scraping && speed > 5, newKills: kills - missionKillsSeen, beaconsHitNow: beaconHits,
                            branch: world.lastDecision == "tunnel" ? -1 : (world.lastDecision == "skyway" ? 1 : 0))
            missionHitsSeen = hits
            missionKillsSeen = kills
            if missions.isRunning, let s = missions.scoredNow {
                let timeText = s.time > 0 ? String(format: "  +%.1f s", s.time) : ""
                stamp((s.streak > 1 ? "+\(s.value)  x\(s.streak)" : "+\(s.value)") + timeText, seconds: 0.6)
                sound.play(.gate, volume: 0.7, pitch: 0.85 + Float(s.streak) * 0.06)
            }
            if missions.helmetUsedNow { stamp("HELMET", seconds: 0.9); flash = max(flash, 0.5); sound.play(.respawn, volume: 0.6) }
            if missions.respawnedNow {
                let left = missions.snapshot().respawnsLeft
                stamp("HULL RESTORED  \(left) LEFT", seconds: 1.4)
                flash = 1.0; invulnerable = 1.5
                gamepad.rumble(intensity: 0.8, sharpness: 0.3)
                sound.play(.respawn)
            }
            let ms = missions.snapshot()
            updateComms(ms, dt: simDt, upcoming: world.upcoming?.label)
            if let pursuer {
                if missions.isRunning { pursuer.update(gap: ms.gap, playerX: speeder.x, time: time) } else { pursuer.hide() }
            }
            if missions.isRunning {
                // the last five seconds tick (rising on the last two); low hull and a closing pursuer share the alarm loop
                let secLeft = Int(ceil(ms.timeLeft))
                if secLeft <= 5 && secLeft != lastTickSecond { lastTickSecond = secLeft; sound.play(.tick, volume: 0.8, pitch: secLeft <= 2 ? 1.35 : 1) }
                let low: Float = ms.energy < 0.25 ? 0.45 : 0
                let close: Float = ms.kind == .escape ? clamp01((25 - ms.gap) / 20) * 0.7 : 0
                sound.set(.alarm, volume: max(low, close), pitch: close > low ? 1.4 : 1)
            } else {
                lastTickSecond = -1
            }
            if missions.phase != mission.phase {
                switch missions.phase {
                case .success: sound.play(.success)
                case .failed: sound.play(.fail)
                default: break
                }
            }
            if missions.phase != mission.phase || missions.phase == .running && statsAccumulator > 0.2 { mission = ms }
            // music: the pad under the cards, bass on the run, the arp when it gets hot
            let hot = (input.boosting && missions.boostAllowed) || ms.streak >= 4 || (ms.kind == .escape && ms.gap < 25)
            let lead = (input.boosting && missions.boostAllowed) || ms.streak >= 4
            let final = missions.isRunning && ms.distanceTotal > 0 && ms.distanceLeft < ms.distanceTotal * 0.25
            sound.setMusic(intensity: missions.isRunning ? (hot ? 2 : 1) : 0.4, lead: lead, finalStretch: final, gated: ms.score > 0)
            if missions.phase != mission.phase {
                if missions.phase == .success { sound.musicSlam() }
                if missions.phase == .failed { sound.musicCut() }
            }
            contactAvatar?.root.isEnabled = missions.phase != .running
            if missions.phase != .running { contactAvatar?.face(cameraRig.position) }
            if demoMode && Int(time * 4) % 4 == 0 && statsAccumulator > 0.2, let a = contactAvatar { print("avatar \(a.debugBounds())") }
        }
        if !missionActive { sound.setMusic(intensity: input.boosting ? 2 : 1, lead: input.boosting, gated: true) }
        if onTitle { sound.setMusic(intensity: 1) }         // the title: pad and bass
        sound.setAmbience((0.5 - world.enclosure * 0.3) * (settings.weather || theme != .neonCity ? 1 : 0.7))
        sound.setEnclosure(world.enclosure)
        let moving = settings.roadMotion && (!missionActive || missions.allowsMotion)
        let boosting = moving && input.boosting && (!missionActive || missions.boostAllowed)
        if boosting && !boostPrev {
            // boost onset: camera kick, haptic and the HUD pip on the same frame
            cameraRig.punch(1.0)
            gamepad.rumble(intensity: 0.5, sharpness: 0.5)
            sound.play(.surge, volume: 0.5)
        }
        boostPrev = boosting
        boostLevel = damp(boostLevel, boosting ? 1 : 0, boosting ? 13 : 5, dt)
        let target = moving ? settings.cruiseSpeed * (boosting ? 1.8 : 1.0) : 0
        speed = damp(speed, target, target > speed ? 1.6 : 2.0, simDt)
        let speedNorm = clamp01(speed / maxSpeed)
        sound.set(.engine, volume: moving ? 0.3 + speedNorm * 0.5 : 0.12, pitch: 0.7 + speedNorm * 1.1)
        gamepad.engineHum(intensity: speed > 3 ? 0.08 + speedNorm * 0.22 + boostLevel * 0.3 : 0, sharpness: 0.15 + boostLevel * 0.5)
        sound.set(.boost, volume: boosting ? 0.9 : 0, pitch: 0.9 + speedNorm * 0.4)

        let travel = speed * simDt
        world.advance(travel, playerX: speeder.x, time: time)
        distance += travel
        speeder.tube = WorldScroller.tubeGeometry
        speeder.tubeBlend = world.tubeBlend
        speeder.wedgeLimit = world.wedgeLimit
        post.enclosure = world.enclosure
        // weather: rain off in enclosed sections; lightning every 9 to 17 s with a rumble
        if theme.rain {
            let mode = rainMode
            var target: Float = 0
            switch mode {
            case .off: target = 0
            case .always: target = 1
            case .showers, .heavy:
                showerTimer -= dt
                if showerTimer <= 0 { showerOn.toggle(); showerTimer = showerOn ? weatherRNG.float(18, 34) : weatherRNG.float(22, 48) }
                target = showerOn ? (mode == .heavy ? 1.7 : 1.0) : 0
            }
            let wet: Float = settings.weather ? target * (1 - world.enclosure) : 0
            rainLevel = damp(rainLevel, wet, mode == .always ? 3 : 0.35, dt)   // showers swell in over a few seconds
            post.rain = rainLevel
            post.rainFog = mode == .heavy ? rainLevel / 1.7 : 0
            if settings.weather && rainLevel > 0.3 {
                lightningTimer -= dt
                if lightningTimer <= 0 { lightning = 1; lightningTimer = weatherRNG.float(9, 17); gamepad.rumble(intensity: 0.2, sharpness: 0.2) }
            }
            lightning = max(0, lightning - dt * 7)
            post.lightning = lightning * (1 - world.enclosure) * (settings.weather ? 1 : 0)
        }
        // section stamp when the player crosses into a new kind of section
        let style = world.currentBlock.style
        if style != lastStyle {
            if lastStyle != nil, let label = WorldScroller.sectionLabel(style) { stamp(label); sound.play(.section) }
            lastStyle = style
        }
        // "coming up" cue: one tone when a section change comes into range
        if let u = world.upcoming {
            if u.label != lastUpcoming { sound.play(.approach, volume: 0.6) }
            lastUpcoming = u.label
        } else {
            lastUpcoming = nil
        }
        let parked = missionActive && !missions.allowsMotion
        speeder.update(dt: simDt, time: time, steerInput: parked ? 0 : input.steering, climbInput: parked ? 0 : input.climb, speedNorm: speedNorm, roadShift: world.lastShift * world.tugFactor / 0.6, boost: boostLevel)

        // barrier scraping: bleed speed, sparks, shake
        if speeder.scraping && speed > 5 {
            speed *= 1 - 0.7 * dt
            shakeBurst = max(shakeBurst, 0.25)
            let sparkPos: SIMD3<Float> = world.tubeBlend < 0.5
                ? [speeder.root.position.x + (speeder.x > 0 ? 1.0 : -1.0), 0.6, 0.5]
                : speeder.root.position + simd_normalize(SIMD3<Float>(speeder.x, speeder.altitude - RoadSegment.tubeCenterY, 0)) * 1.1
            emitSparks(at: sparkPos, duration: 0.1)
            if Int(time * 10) % 3 == 0 { gamepad.rumble(intensity: 0.3, sharpness: 0.8) }
            sound.set(.scrape, volume: 0.7)
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
                    sound.play(.hit)
                    break
                }
            }
        }
        // weapons
        if let weapons {
            if input.firing && settings.obstacles && !parked && (!missionActive || missions.current.weaponsAllowed) {
                if weapons.fire(from: speeder.root.position, orientation: speeder.root.orientation) {
                    shakeBurst = max(shakeBurst, 0.08)
                    ackTimers.fire = 0.15
                    gamepad.rumble(intensity: 0.25, sharpness: 1.0)
                    sound.play(.fire, volume: 0.5)
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
                            sound.play(.kill, volume: 0.8)
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

        let curveAhead = world.offset(atWorldZ: -14) - world.playerOffset
        // the camera follows the smooth bank and only a little of the collision jolt
        let camBank = speeder.smoothBank + (speeder.bank - speeder.smoothBank) * 0.4
        if corridorOverview {
            cameraRig.overviewCorridor(speederX: speeder.x)
        } else {
            cameraRig.update(dt: dt, time: time, speederX: speeder.x, speederY: speeder.altitude, bank: camBank, speedNorm: speedNorm,
                             shake: settings.cameraShake, curveAhead: curveAhead, extraShake: shakeBurst, inTube: world.tubeBlend,
                             frameShift: parked ? -2.2 : 0, title: titleMix)
        }

        // speed particles follow the vehicle speed (none while parked)
        if settings.particles, var e = speedParticles.components[ParticleEmitterComponent.self] {
            e.speed = 20 + speed * 0.9
            e.mainEmitter.birthRate = speed < 4 ? 0 : 80 + speedNorm * 360
            speedParticles.components.set(e)
        }

        // post-process uniforms
        post.speedNorm = speedNorm
        post.speed = speed
        post.kick = cameraRig.kickLevel
        post.boost = boostLevel
        ackBoost = boosting
        let size = arView.bounds.size
        if size.width > 0 && size.height > 0 {
            if let vp = arView.project([cameraRig.position.x, cameraRig.position.y, -900]) {
                post.vanishing = [Float(vp.x / size.width), Float(vp.y / size.height)]
            }
            if let tp = arView.project(speeder.thrusterWorldPosition) {
                post.thrusterUV = [Float(tp.x / size.width), Float(tp.y / size.height)]
            }
            if let cp = arView.project(speeder.root.position) {
                post.vehicleUV = [Float(cp.x / size.width), Float(cp.y / size.height)]
                post.vehicleDistance = simd_length(speeder.root.position - cameraRig.position)
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
            var st = FrameStats(fps: fpsSmoothed, frameMs: Double(rawDt) * 1000, speed: speed,
                                entities: entityCount, lights: settings.realLights ? 5 : 0,
                                sourceFormat: post.sourceFormat, distance: distance, hits: hits,
                                section: world.currentBlock.name, flash: flash, decision: world.lastDecision,
                                kills: kills, altitude: speeder.altitude, controller: gamepad.connectedName)
            st.upcoming = world.upcoming?.label
            st.upcomingDistance = world.upcoming?.distance ?? 0
            stats = st
        }
        publishAck(dt: dt)
    }

    private var ackBoost = false

    /// Centre-screen stamp text for a section entry.
    private static func sectionStamp(_ style: SegmentStyle) -> String? { WorldScroller.sectionLabel(style) }

    /// One line from the contact, with a comms blip. Never while a stamp is up (it would fight it).
    private func comms(_ trigger: Mission.CommsTrigger, section: String = "") {
        let m = missions.current
        commsSpeaker = m.contact
        commsText = Mission.comms(contact: m.contact, kind: m.kind, trigger: trigger, section: section).uppercased()
        commsTimer = 2.8
        sound.play(.approach, volume: 0.35, pitch: 1.7)
    }

    /// The rival speaks on the Grid: queued on the round's event, shown once the stamp has cleared.
    private func rivalSay(_ arena: ArenaController, _ event: Debrief.DuelEvent, delay: Float = 2.4) {
        let r = arena.rival
        let text = Debrief.rivalLine(rival: r.name, event: event, record: missions.record(for: r.name), wins: arena.wins, losses: arena.losses)
        guard !text.isEmpty else { return }
        rivalComms = (r.name, text.uppercased(), delay)
    }
    private func updateRivalComms(dt: Float) {
        guard var p = rivalComms else { return }
        p.delay -= dt
        if p.delay <= 0 {
            if ackTimers.stamp <= 0 && commsTimer <= 0 {
                commsSpeaker = p.speaker; commsText = p.text; commsTimer = 2.6
                if demoMode { print("comms: \(p.speaker): \(p.text) at \(String(format: "%.1f", time)) s") }
                sound.play(.approach, volume: 0.3, pitch: 1.2)
                rivalComms = nil
                return
            }
            p.delay = 0
        }
        rivalComms = p
    }

    /// Comms triggers for a live corridor job: launch, one mid-run event (a section ahead, the pursuer
    /// closing, or halfway), the last stretch. Reset when the job is not running.
    private func updateComms(_ ms: MissionState, dt: Float, upcoming: String?) {
        guard missions.isRunning, ms.kind != .duel else { runClock = 0; commsSlots = (false, false, false); return }
        runClock += dt
        if !commsSlots.launch && runClock > 1.6 { commsSlots.launch = true; comms(.launch); return }
        if !commsSlots.event && runClock > 6 && ackTimers.stamp <= 0 && commsTimer <= 0 {
            if ms.kind == .escape && ms.gap < 30 { commsSlots.event = true; comms(.pursuerClose); return }
            if let u = upcoming, ms.kind != .escape { commsSlots.event = true; comms(.sectionAhead, section: u); return }
            if ms.distanceLeft < ms.distanceTotal * 0.5 { commsSlots.event = true; comms(.midway); return }
        }
        if !commsSlots.last && ms.distanceLeft < 320 && ms.distanceLeft > 0 && ackTimers.stamp <= 0 { commsSlots.last = true; comms(.lastStretch) }
    }

    /// The rival card can be skipped with A once it has been up for a moment.
    private static let introSkipAfter = MissionRunner.introDuration - 0.8

    // MARK: - Identity

    func setCallsign(_ raw: String) {
        missions.setCallsign(raw)
        player = missions.player
        mission = missions.snapshot()
        sound.play(.tick, volume: 0.5, pitch: 1.2)
    }
    func cycleLivery() { setLivery(player.livery + 1) }
    /// Pick a livery (wraps): the bike, the trail colour and the HUD tint follow on the same frame.
    func setLivery(_ i: Int) {
        missions.setLivery(i)
        player = missions.player
        mission = missions.snapshot()
        if let speeder, let materials {
            if player.tintsBike { speeder.tint(player.liveryColor, materials: materials) } else { speeder.tint(Neon.cyan, materials: materials) }
        }
        ArenaController.playerColor = player.liveryColor
        sound.play(.pickupTaken, volume: 0.5)
        gamepad.rumble(intensity: 0.3, sharpness: 0.7)
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
        commsTimer = max(0, commsTimer - dt)
        let a = ActionAck(boost: ackBoost || ackTimers.boost > 0, fire: ackTimers.fire > 0, jump: ackTimers.jump > 0, pickup: ackTimers.pickup > 0,
                          snap: ackTimers.snap > 0, beacon: ackTimers.beacon > 0, hit: ackTimers.hit > 0,
                          stamp: ackTimers.stamp > 0 ? stampText : "",
                          commsSpeaker: commsTimer > 0 ? commsSpeaker : "", commsText: commsTimer > 0 ? commsText : "")
        if a != ack { ack = a }
        sound.update(dt: dt)
        arView.input.tapFire = false
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
        // a quick, still tap is the touch player's A button (fire, pickup, accept)
        let now = Date().timeIntervalSinceReferenceDate
        for e in events {
            switch e.phase {
            case .active:
                if touchStarts[e.id] == nil { touchStarts[e.id] = (e.location, now) }
            default:
                if let st = touchStarts.removeValue(forKey: e.id), now - st.1 < 0.22, hypot(st.0.x - e.location.x, st.0.y - e.location.y) < 18 {
                    input.tapFire = true
                }
            }
        }
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
    var missionActive: Bool { settings.missions && missions.current.theme.rawValue == settings.environment }

    /// Free play: the result card's A / F / tap restarts the match against the next rival.
    private func restartArenaMatch(_ arena: ArenaController) {
        matchResult = nil
        arena.restartMatch()
        cameraRig?.resetArena()
    }

    /// Inbox: browse the unlocked jobs from the briefing (stick left / right, or a tap on a chip).
    func browseJob(_ delta: Int) {
        guard missionActive, missions.phase == .briefing else { return }
        missions.browse(delta)
        mission = missions.snapshot()
        sound.play(.tick, volume: 0.5)
    }
    func browseJob(to id: Int) {
        guard missionActive, missions.phase == .briefing else { return }
        missions.browse(to: id)
        mission = missions.snapshot()
        sound.play(.tick, volume: 0.5)
    }
    /// Garage: move the highlight (stick up / down) and buy (Y / ] / tap on the row).
    func shopMove(_ delta: Int) {
        guard missionActive, missions.phase == .briefing else { return }
        missions.shopMove(delta)
        mission = missions.snapshot()
        sound.play(.tick, volume: 0.4, pitch: 1.3)
    }
    func buyUpgrade(at row: Int? = nil) {
        guard missionActive, missions.phase == .briefing else { return }
        if let row { while missions.shopSelection != row { missions.shopMove(1) } }
        let ok = missions.buySelected()
        mission = missions.snapshot()
        sound.play(ok ? .pickupTaken : .streakLost, volume: 0.6)
        if ok { gamepad.rumble(intensity: 0.4, sharpness: 0.6) }
    }

    /// Pad and keyboard edges while a briefing is up: steer browses the inbox, climb moves the
    /// garage highlight, Y / ] buys. Touch never browses (a tap on the card accepts).
    private func briefingInput(_ input: InputState) {
        guard missions.phase == .briefing, !demoMode else { briefPrev = (0, 0, false); return }
        let steer: Float = input.padSteer ?? ((input.right ? 1 : 0) - (input.left ? 1 : 0))
        let climb: Float = input.padSteer != nil ? input.padClimb : ((input.up ? 1 : 0) - (input.down ? 1 : 0))
        if steer > 0.5 && briefPrev.steer <= 0.5 { browseJob(1) }
        if steer < -0.5 && briefPrev.steer >= -0.5 { browseJob(-1) }
        if climb > 0.5 && briefPrev.climb <= 0.5 { shopMove(-1) }
        if climb < -0.5 && briefPrev.climb >= -0.5 { shopMove(1) }
        if input.speedUp && !briefPrev.buy { buyUpgrade() }
        briefPrev = (steer, climb, input.speedUp)
    }

    /// Accept the briefing or continue past a result (also called by the HUD tap).
    func acceptMission() {
        if let arena, arena.awaitingRestart, !missionActive { restartArenaMatch(arena); return }
        guard missionActive, !pendingRebuild, !rebuilding else { return }
        let wasBriefing = missions.phase == .briefing
        let rebuild = missions.accept()
        mission = missions.snapshot()
        sound.play(.accept)
        if wasBriefing && missions.phase == .rivalIntro { sound.play(.warn, volume: 0.8, pitch: 0.7); gamepad.rumble(intensity: 0.5, sharpness: 0.3) }
        if wasBriefing && missions.phase == .running {
            // launch: the same kick as a boost, plus the stamp
            cameraRig?.punch(0.8)
            gamepad.rumble(intensity: 0.6, sharpness: 0.4)
            stamp("GO", seconds: 0.6)
            sound.play(.go)
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
            if prefs.devUnlocked {
                panelVisible.toggle()
                if panelVisible { hintVisible = true; hintTimer = 0 }
            }
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
            // the demo pulses its accept (a held button has no edge, so the result card would stay up)
            let fire = input.firing || (demoMode && time > 1.5 && !holdBriefing && !(holdResult && !missions.isParked) && Int(time * 2) % 3 == 0)
            if screen != .game {
                // the front end has the buttons
            } else if fire && !missionFirePrev && missions.phase != .running && missions.phase != .rivalIntro { acceptMission() }
            else if fire && !missionFirePrev && missions.phase == .rivalIntro && !demoMode && missions.snapshot().introLeft < Self.introSkipAfter { acceptMission() }
            missionFirePrev = fire
            if screen == .game { briefingInput(input) }
            if missions.phase == .rivalIntro { missions.tickIntro(dt: dt); if missions.phase == .running { stamp("ROUND 1", seconds: 1.0); sound.play(.roundStart, volume: 0.6) } }
            missions.lastDerezCause = arena.stateText
            arena.paused = missions.phase != .running
            arena.matchTarget = Int.max
            if missions.phase != mission.phase {
                switch missions.phase {
                case .success: sound.play(.success)
                case .failed: sound.play(.fail)
                default: break
                }
            }
            if let r = missions.current.rival { arena.rival = r }
            missions.updateDuel(dt: dt, wins: arena.wins, losses: arena.losses)
            if missions.phase != mission.phase || statsAccumulator > 0.2 { mission = missions.snapshot() }
            if missions.phase != .running { cmd = CycleInput() }
        }
        if !missionActive && arena.matchTarget == Int.max { arena.matchTarget = 3 }   // free play again after a duel
        if arena.awaitingRestart && cmd.action && !missionActive { restartArenaMatch(arena); sound.play(.accept) }
        if cmd.boost && !boostPrev && arena.energy > 0.02 { cameraRig.punch(1.0); gamepad.rumble(intensity: 0.5, sharpness: 0.5); sound.play(.surge, volume: 0.5) }
        boostPrev = cmd.boost && arena.energy > 0.02
        arena.update(dt: dt, time: time, input: cmd, aiInput: aiCmd)
        let ev = arena.events
        if ev.snapped { ackTimers.snap = 0.2; sound.play(.snap, volume: 0.6) }
        if ev.jumped { ackTimers.jump = 0.35; sound.play(.jump) }
        if ev.landed { sound.play(.land, volume: 0.6) }
        if ev.pickupUsed != nil { ackTimers.pickup = 0.4; stamp(ev.pickupUsed == .phase ? "PHASE" : "PULSE", seconds: 0.6); sound.play(.pickup) }
        if ev.pickupTaken { ackTimers.pickup = 0.3; sound.play(.pickupTaken, volume: 0.6) }
        if ev.padBoost { ackTimers.boost = 0.3; stamp("SURGE", seconds: 0.5); sound.play(.surge) }
        if ev.padSlow { ackTimers.hit = 0.4; sound.play(.slow) }
        if ev.charged { ackTimers.boost = 0.4; stamp("CHARGE", seconds: 0.6); sound.play(.charge) }
        if ev.zoneOpened { stamp("ZONE", seconds: 1.2); sound.play(.zone) }
        // round and match beats: one stamp each, on the frame they happen
        if ev.roundWon { stamp("\(arena.rivalName) DEREZZED", seconds: 2.2); sound.play(.rivalDerez) }
        if ev.roundLost { stamp("DEREZZED", seconds: 2.2); sound.play(.derez) }
        // the rival's voice: one line per round, after the attribution has had its frame
        if (ev.roundWon || ev.roundLost) && !ev.matchWon && !ev.matchLost && rivalCommsRound != arena.roundNumber {
            rivalCommsRound = arena.roundNumber
            let target = arena.matchTarget == Int.max ? (missionActive ? missions.current.duelTarget : 3) : arena.matchTarget
            let matchPoint = arena.wins == target - 1 || arena.losses == target - 1
            if matchPoint { rivalSay(arena, .matchPoint) }
            else if ev.roundWon { rivalSay(arena, arena.wins > arena.losses + 1 ? .playerLeads : .wonRound) }
            else if arena.stateText.hasPrefix("BOXED") { rivalSay(arena, .lostRoundBoxed) }
            else if arena.stateText.hasPrefix("CUT OFF") { rivalSay(arena, arena.losses > arena.wins + 1 ? .rivalLeads : .lostRoundCutOff) }
            else { rivalSay(arena, .lostRoundOther) }
        }
        if ev.roundStart && arena.roundNumber == 1 && !ev.matchWon && !ev.matchLost { rivalCommsRound = -1; rivalSay(arena, .matchStart, delay: 1.4) }
        if ev.matchWon || ev.matchLost { rivalComms = nil }
        updateRivalComms(dt: dt)
        if ev.voidRound { stamp("VOID ROUND", seconds: 2.2); sound.play(.derez) }
        if ev.matchWon { stamp("MATCH WON  \(arena.wins) - \(arena.losses)", seconds: 3.4); sound.play(.matchWon) }
        if ev.matchLost { stamp("MATCH LOST  \(arena.wins) - \(arena.losses)", seconds: 3.4); sound.play(.matchLost) }
        if ev.roundStart && !ev.matchWon && !ev.matchLost { stamp(arena.matchTarget == Int.max ? "READY" : "ROUND \(arena.roundNumber)", seconds: 1.0); sound.play(.roundStart, volume: 0.6) }
        if ev.go { stamp("GO", seconds: 0.5); sound.play(.go) }
        let arenaLive = arena.stateText.isEmpty && !arena.paused
        sound.set(.engine, volume: arenaLive ? 0.25 + arena.speedNorm * 0.5 : 0.1, pitch: 0.75 + arena.speedNorm * 1.0)
        sound.set(.boost, volume: (arenaLive && cmd.boost && arena.energy > 0.02) ? 0.8 : 0, pitch: 1.1)
        sound.set(.grind, volume: arenaLive ? arena.grind * 0.9 : 0, pitch: 0.8 + arena.grind * 0.7)
        let zoneOut: Float = (arena.zoneRadius != nil && arena.energy < 0.3) ? 0.4 : 0
        sound.set(.alarm, volume: arenaLive ? max(arena.edge < 0.3 ? 0.3 : 0, zoneOut) : 0)
        let hot = (cmd.boost && arena.energy > 0.02) || arena.grind > 0.5 || arena.zoneRadius != nil
        let target = arena.matchTarget == Int.max ? (missionActive ? missions.current.duelTarget : 3) : arena.matchTarget
        let final = arenaLive && (arena.wins == target - 1 || arena.losses == target - 1)
        sound.setMusic(intensity: arenaLive ? (hot ? 2 : 1) : 0.4, lead: arena.wins > arena.losses || (cmd.boost && arena.energy > 0.02), finalStretch: final, gated: true)
        if onTitle { sound.setMusic(intensity: 1) }
        if ev.roundLost || ev.voidRound { sound.musicCut() }
        if ev.matchWon { sound.musicSlam() }
        sound.setAmbience(0.35)
        sound.setEnclosure(0)
        if ev.matchResult, let r = arena.matchResult {
            missions.award(r.credits)
            missions.recordMatch(rival: r.rival, won: r.won)
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
        shakeBurst = max(0, shakeBurst - dt * 2.5)
        cameraRig.followArena(dt: dt, time: time, position: player.position + [0, 1.05, 0], forward: player.forward, lean: player.lean,
                              speedNorm: speedNorm, shake: settings.cameraShake, extraShake: shakeBurst,
                              orbit: onTitle ? (center: player.position, progress: 0.25) : arena.cameraOrbit,
                              overview: overviewCamera, ground: arena.groundHeight, side: sideCamera)
        arena.placeRivalTag(camera: cameraRig.position)
        if settings.particles, var e = speedParticles.components[ParticleEmitterComponent.self] {
            e.speed = 20 + player.speed * 0.9
            e.mainEmitter.birthRate = 40 + speedNorm * 300
            speedParticles.components.set(e)
        }
        post.speedNorm = speedNorm * 0.8
        post.speed = 0   // the arena camera moves with the bike; reprojection blur does not apply
        post.kick = cameraRig.kickLevel
        boostLevel = damp(boostLevel, (cmd.boost && arena.energy > 0.02) ? 1 : 0, cmd.boost ? 13 : 5, dt)
        post.boost = boostLevel
        gamepad.engineHum(intensity: speedNorm > 0.05 ? 0.08 + speedNorm * 0.2 + boostLevel * 0.3 : 0, sharpness: 0.2 + boostLevel * 0.5)
        if arView.bounds.width > 0, let sp = speeder, let tp = arView.project(sp.thrusterWorldPosition) {
            post.thrusterUV = [Float(tp.x / arView.bounds.width), Float(tp.y / arView.bounds.height)]
        }
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
