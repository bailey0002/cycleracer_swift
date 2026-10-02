import Foundation
import simd

/// Which screen owns the display. `GameController.screens` is a stack: its first entry says what is
/// underneath (`.title`, the front end over the parked job world, or `.game`, a pause over the run).
enum Screen: Equatable {
    case loading      // the splash while the first world builds
    case title        // wordmark, rider, CONTINUE / FREE PLAY / SETTINGS
    case worlds       // free play: pick a world
    case settings     // the player's settings
    case rider        // callsign and livery (the first run asks here before the first briefing)
    case riders       // the rider roster: who's on the board (profile cards)
    case story        // the Griptap & Co opening (first run, and replay from SETTINGS)
    case paused       // over a run: RESUME / SETTINGS / QUIT TO TITLE
    case messages     // the message log (from the title, the pause menu and the briefing)
    case game         // the HUD and the job cards
}

/// The player's settings. Unlike the developer panel's `FXSettings` (per session), these persist and
/// are re-applied over each world's own look.
struct PlayerPrefs: Equatable {
    var music = 8            // 0 ... 10
    var effects = 10         // 0 ... 10
    var haptics = true
    var quality = 0          // 0 high, 1 balanced, 2 battery
    var gridSteering = 0     // 0 smooth (analog), 1 snap 90
    var vehicle = 0          // 0 speeder, 1 hoverboard (test build; `SPEEDER_VEHICLE=` overrides)
    /// The developer panel: five taps on the version line in SETTINGS (always on for the Mac).
    var devUnlocked = PlayerPrefs.devDefault

    #if os(macOS)
    static let devDefault = true
    #else
    static let devDefault = false
    #endif
    static let qualityNames = ["HIGH", "BALANCED", "BATTERY"]
    static let qualityDetail = ["FULL POST PASS", "NO MOTION BLUR OR LENS FX", "ALSO NO RAIN, REFLECTIONS, STOREFRONTS"]
    static let steeringNames = ["SMOOTH", "SNAP 90"]
    static let vehicleNames = ["SPEEDER", "HOVERBOARD"]

    static func load(_ d: UserDefaults) -> PlayerPrefs {
        var p = PlayerPrefs()
        if d.object(forKey: "prefs.music") != nil { p.music = max(0, min(10, d.integer(forKey: "prefs.music"))) }
        if d.object(forKey: "prefs.effects") != nil { p.effects = max(0, min(10, d.integer(forKey: "prefs.effects"))) }
        if d.object(forKey: "prefs.haptics") != nil { p.haptics = d.bool(forKey: "prefs.haptics") }
        p.quality = max(0, min(2, d.integer(forKey: "prefs.quality")))
        p.gridSteering = max(0, min(1, d.integer(forKey: "prefs.gridSteering")))
        p.vehicle = max(0, min(1, d.integer(forKey: "prefs.vehicle")))
        p.devUnlocked = devDefault || d.bool(forKey: "prefs.devUnlocked")
        return p
    }
    func save(_ d: UserDefaults) {
        d.set(music, forKey: "prefs.music"); d.set(effects, forKey: "prefs.effects"); d.set(haptics, forKey: "prefs.haptics")
        d.set(quality, forKey: "prefs.quality"); d.set(gridSteering, forKey: "prefs.gridSteering"); d.set(devUnlocked, forKey: "prefs.devUnlocked")
        d.set(vehicle, forKey: "prefs.vehicle")
    }

    /// Graphics quality and Grid steering over the world's look (call after `Theme.adjust`).
    func apply(to s: inout FXSettings) {
        s.steeringMode = gridSteering
        switch quality {
        case 1: s.motionBlur = false; s.lensFX = false; s.weather = true; s.storefronts = true
        case 2: s.motionBlur = false; s.lensFX = false; s.weather = false; s.storefronts = false; s.reflections = false
        default: s.motionBlur = true; s.lensFX = true; s.weather = true; s.storefronts = true
        }
    }
}

/// One row of a front-end list. The same rows drive the pad (up / down to move, left / right to change,
/// A to run, B to go back), the keyboard (arrows, return, escape) and touch (tap a row or a value).
struct MenuRow: Identifiable, Equatable {
    enum Kind: Equatable {
        case action
        case choice([String], Int)
        case level(Int)            // 0 ... 10
        case toggle(Bool)
        case callsign(String)
        case livery(Int)
        case roster(Int)           // the rider roster card, left / right to choose
    }
    let id: String
    var label: String
    var detail: String = ""
    var kind: Kind = .action
    var tint: SIMD3<Float>? = nil
}

/// Arcade initials entry for the pad: up / down change the letter under the cursor, left / right move it.
struct CallsignEdit: Equatable {
    static let slots = 8
    static let charset: [Character] = Array(" ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    var chars: [Character]
    var cursor = 0
    init(_ callsign: String) {
        let c = Array(callsign.prefix(Self.slots))
        chars = c + Array(repeating: " ", count: Self.slots - c.count)
    }
    mutating func step(_ d: Int) {
        let n = Self.charset.count
        let i = Self.charset.firstIndex(of: chars[cursor]) ?? 0
        chars[cursor] = Self.charset[((i + d) % n + n) % n]
    }
    mutating func move(_ d: Int) { cursor = max(0, min(Self.slots - 1, cursor + d)) }
    var text: String { String(chars.filter { $0 != " " }) }
}

/// The splash loader's current stage: the fill runs to `to` over `seconds` (the time this stage took on
/// the last launch), so it creeps on while the main thread is busy building.
struct LoadStage: Equatable {
    var id = 0
    var label = ""
    var to: Float = 0
    var seconds: Double = 0.3
}

// MARK: - The front end's behaviour

extension GameController {
    var screen: Screen { screens.last ?? .game }
    /// The front end over the parked job world (loading, title and its sub screens).
    var onTitle: Bool { screens.first == .title || screens.first == .loading }
    /// A pause is somewhere in the stack: the run holds.
    var simFrozen: Bool { screens.contains(.paused) }

    func push(_ s: Screen) {
        indexStack.append(menuIndex)
        screens.append(s)
        menuIndex = 0
        callsignEdit = nil; resetArmed = false
        sound.play(.tick, volume: 0.5, pitch: 1.15)
    }
    func pop() {
        guard screens.count > 1 else { return }
        screens.removeLast()
        menuIndex = indexStack.popLast() ?? 0
        callsignEdit = nil; resetArmed = false
        sound.play(.tick, volume: 0.45, pitch: 0.8)
    }
    func setRoot(_ s: Screen) {
        screens = [s]; indexStack = []; menuIndex = 0
        callsignEdit = nil; resetArmed = false
    }

    /// Pause a run (pad Menu, Escape, the touch pause button). Not while the world is rebuilding.
    func pause() {
        guard screen == .game, worldReady else { return }
        push(.paused)
        gamepad.rumble(intensity: 0.2, sharpness: 0.3)
    }

    // MARK: Rows

    var menuRows: [MenuRow] {
        let m = missions.current
        switch screen {
        case .loading, .game:
            return []
        case .title:
            return [
                MenuRow(id: "continue", label: missions.hasProgress ? "CONTINUE" : "START", detail: "\(m.code)  //  \(m.title)"),
                MenuRow(id: "riders", label: "RIDERS", detail: "\(rider.name)  //  \(rider.tag)"),
                MenuRow(id: "freeplay", label: "FREE PLAY", detail: "ANY WORLD, NO JOB"),
            ] + messagesRow + [
                MenuRow(id: "settings", label: "SETTINGS", detail: "SOUND, GRAPHICS, CALLSIGN, STORY"),
            ]
        case .worlds:
            return [
                MenuRow(id: "world.0", label: "NEON CITY", detail: "ENDLESS RUN  //  NIGHT, RAIN", tint: Theme.neonCity.hudAccent),
                MenuRow(id: "world.1", label: "SUNSET CANYON", detail: "ENDLESS RUN  //  DAYLIGHT", tint: Theme.sunsetCanyon.hudAccent),
                MenuRow(id: "world.2", label: "THE GRID", detail: "LIGHT CYCLES  //  FIRST TO THREE", tint: Theme.theGrid.hudAccent),
                MenuRow(id: "back", label: "BACK"),
            ]
        case .settings:
            var rows = [
                MenuRow(id: "music", label: "MUSIC", kind: .level(prefs.music)),
                MenuRow(id: "effects", label: "EFFECTS", kind: .level(prefs.effects)),
                MenuRow(id: "haptics", label: "HAPTICS", kind: .toggle(prefs.haptics)),
                MenuRow(id: "quality", label: "GRAPHICS", detail: PlayerPrefs.qualityDetail[prefs.quality], kind: .choice(PlayerPrefs.qualityNames, prefs.quality)),
                MenuRow(id: "steering", label: "GRID STEERING", kind: .choice(PlayerPrefs.steeringNames, prefs.gridSteering)),
                MenuRow(id: "vehicle", label: "VEHICLE", detail: "TEST BUILD  //  REBUILDS THE WORLD", kind: .choice(PlayerPrefs.vehicleNames, prefs.vehicle)),
                MenuRow(id: "rider", label: "CALLSIGN", detail: "\(player.callsign)  //  \(player.liveryName)"),
            ]
            if onTitle {
                rows.append(MenuRow(id: "story", label: "STORY", detail: "GRIPTAP & CO  //  REPLAY THE OPENING"))
                rows.append(MenuRow(id: "reset", label: resetArmed ? "PRESS AGAIN TO RESET" : "RESET PROGRESS", detail: "JOBS, CREDITS, GARAGE, RECORDS"))
            }
            if prefs.devUnlocked { rows.append(MenuRow(id: "dev", label: "DEVELOPER PANEL", kind: .toggle(panelVisible))) }
            rows.append(MenuRow(id: "back", label: "BACK"))
            return rows
        case .rider:
            return [
                MenuRow(id: "callsign", label: "CALLSIGN", detail: "3 TO 8 LETTERS OR DIGITS", kind: .callsign(player.callsign)),
                MenuRow(id: "livery", label: "LIVERY", detail: player.liveryName, kind: .livery(player.livery)),
                MenuRow(id: "confirm", label: riderFirstRun ? "RIDE" : "DONE", detail: riderFirstRun ? "\(m.code)  //  \(m.title)" : ""),
                MenuRow(id: "back", label: "BACK"),
            ]
        case .riders:
            return [
                MenuRow(id: "roster", label: "RIDER", kind: .roster(Roster.index(of: rider))),
                MenuRow(id: "rideon", label: riderFirstRun ? "NEXT" : "DONE", detail: riderFirstRun ? (storySeen ? "CALLSIGN AND LIVERY" : "GRIPTAP & CO") : ""),
                MenuRow(id: "back", label: "BACK"),
            ]
        case .story:
            return []
        case .messages:
            return [MenuRow(id: "back", label: "BACK")]
        case .paused:
            var rows = [
                MenuRow(id: "resume", label: "RESUME"),
            ] + (missionActive ? messagesRow : []) + [
                MenuRow(id: "settings", label: "SETTINGS"),
                MenuRow(id: "title", label: "QUIT TO TITLE", detail: missionActive && !missions.isParked ? "THE JOB STARTS OVER" : ""),
            ]
            if prefs.devUnlocked { rows.append(MenuRow(id: "dev", label: "DEVELOPER PANEL", kind: .toggle(panelVisible))) }
            return rows
        }
    }

    /// MESSAGES: the log, once there is anything in it; the detail names the newest sender and the unread count.
    private var messagesRow: [MenuRow] {
        let n = missions.messages.count
        guard n > 0 else { return [] }
        let unread = missions.log.unread
        let last = missions.messages.last?.sender ?? ""
        return [MenuRow(id: "messages", label: "MESSAGES", detail: unread > 0 ? "\(unread) NEW  //  LAST FROM \(last)" : "\(n)  //  LAST FROM \(last)")]
    }

    /// A tap on a row: select it and run it (value rows take their taps on the values instead).
    func tapRow(_ i: Int) {
        let rows = menuRows
        guard rows.indices.contains(i) else { return }
        if menuIndex != i { menuIndex = i }
        switch rows[i].kind {
        case .action, .toggle: activate(rows[i].id)
        default: sound.play(.tick, volume: 0.4, pitch: 1.3)
        }
    }

    /// A / return / tap on the highlighted row.
    func activate(_ id: String) {
        switch id {
        case "continue":
            guard worldReady else { return }
            // first run: riders -> story -> callsign -> the first briefing (KERB's order: title, riders, story, world)
            if missions.isFirstRun { riderFirstRun = true; push(.riders) } else { startJobs() }
        case "riders": riderFirstRun = false; push(.riders)
        case "roster": adjust("roster", by: 1)
        case "rideon":
            if riderFirstRun { pop(); push(storySeen ? .rider : .story) } else { pop() }
        case "story": push(.story)
        case "freeplay": push(.worlds)
        case "messages": openMessages()
        case "settings": push(.settings)
        case "rider": riderFirstRun = false; push(.rider)
        case "back": pop()
        case "resume": pop()
        case "title": returnToTitle()
        case "world.0", "world.1", "world.2":
            guard worldReady, let n = Int(id.suffix(1)) else { return }
            startFreePlay(world: n)
        case "haptics": adjust(id, by: 1)
        case "quality", "steering": adjust(id, by: 1)
        case "dev":
            panelVisible.toggle()
            sound.play(.tick, volume: 0.5)
        case "reset":
            guard worldReady else { return }
            if resetArmed { resetArmed = false; resetProgress() } else { resetArmed = true; sound.play(.warn, volume: 0.5) }
        case "callsign":
            callsignEdit = CallsignEdit(player.callsign)
            sound.play(.tick, volume: 0.5, pitch: 1.2)
        case "livery": adjust(id, by: 1)
        case "confirm":
            setCallsign(player.callsign)       // stores it: the first run is over
            if riderFirstRun { riderFirstRun = false; startJobs() } else { pop() }
        default: break
        }
    }

    /// Left / right on a value row (and the taps on its values, through `setValue`).
    func adjust(_ id: String, by d: Int) {
        switch id {
        case "music": setValue(id, prefs.music + d)
        case "effects": setValue(id, prefs.effects + d)
        case "haptics": setValue(id, prefs.haptics ? 0 : 1)
        case "quality": setValue(id, ((prefs.quality + d) % 3 + 3) % 3)
        case "steering": setValue(id, ((prefs.gridSteering + d) % 2 + 2) % 2)
        case "vehicle": setValue(id, ((prefs.vehicle + d) % 2 + 2) % 2)
        case "livery": setLivery(player.livery + d)
        case "roster": selectRider(Roster.index(of: rider) + d)
        default: break
        }
    }

    // MARK: Riders and the story

    /// The chosen rider (Riders.swift); the hoverboard loads this rider's USDZ.
    var rider: RiderProfile { Roster.current() }

    /// Left / right on the roster card: wraps, persists, and the board reloads the rider on the next build.
    func selectRider(_ i: Int) {
        let n = Roster.all.count
        let r = Roster.all[((i % n) + n) % n]
        guard r.id != rider.id else { return }
        Roster.select(r)
        objectWillChange.send()
        sound.play(.tick, volume: 0.45, pitch: 1.25)
        if VehicleKind.current == .board { requestRebuild() }
    }

    static let storySeenKey = "story.seen"
    var storySeen: Bool { UserDefaults.standard.bool(forKey: Self.storySeenKey) }

    /// The opening ended or was skipped: mark it seen and carry on (the first run goes to the riders).
    func finishStory() {
        guard screen == .story else { return }
        UserDefaults.standard.set(true, forKey: Self.storySeenKey)
        pop()
        if riderFirstRun { push(.rider) }
        sound.play(.accept, volume: 0.5)
    }

    func setValue(_ id: String, _ v: Int) {
        var p = prefs
        switch id {
        case "music": p.music = max(0, min(10, v))
        case "effects": p.effects = max(0, min(10, v))
        case "haptics": p.haptics = v != 0
        case "quality": p.quality = max(0, min(2, v))
        case "steering": p.gridSteering = max(0, min(1, v))
        case "vehicle": p.vehicle = max(0, min(1, v))
        case "livery": setLivery(v); return
        default: return
        }
        guard p != prefs else { return }
        prefs = p
        prefs.save(.standard)
        applyPrefs()
        if id == "vehicle" { requestRebuild() }       // the vehicle is loaded with the world
        // a preview at the new level: the tick for effects, the pad swells for music
        sound.play(.tick, volume: id == "effects" ? 0.8 : 0.45, pitch: 1.25)
        if id == "haptics" && p.haptics { gamepad.rumble(intensity: 0.6, sharpness: 0.5) }
    }

    /// Sound levels, haptics, and graphics / steering over the current world's look.
    func applyPrefs() {
        sound.musicVolume = Float(prefs.music) / 10
        sound.effectsVolume = Float(prefs.effects) / 10
        gamepad.enabled = prefs.haptics
        guard !demoMode else { return }        // captures keep the reference look
        var s = settings
        (Theme(rawValue: s.environment) ?? .neonCity).adjust(&s)
        prefs.apply(to: &s)
        if s != settings { settings = s }
    }

    /// Five taps on the version line unlock the developer panel (the pause menu and SETTINGS list it).
    func versionTapped() {
        devTaps += 1
        if devTaps >= 5 && !prefs.devUnlocked {
            prefs.devUnlocked = true
            prefs.save(.standard)
            sound.play(.pickupTaken, volume: 0.6)
            gamepad.rumble(intensity: 0.5, sharpness: 0.8)
        }
    }

    // MARK: Pad and keyboard

    /// Menu navigation from the pad and the keyboard, with auto-repeat on a held direction.
    func frontEndInput(_ input: InputState, dt: Float) {
        let steer: Float = input.padSteer ?? ((input.right ? 1 : 0) - (input.left ? 1 : 0))
        let climb: Float = input.padSteer != nil ? input.padClimb : ((input.up ? 1 : 0) - (input.down ? 1 : 0))
        let dir = climb > 0.5 ? 1 : (climb < -0.5 ? 2 : (steer < -0.5 ? 3 : (steer > 0.5 ? 4 : 0)))
        var fireDir = 0
        if dir != navHold.dir { navHold = (dir, 0); fireDir = dir }
        else if dir != 0 {
            navHold.t += dt
            if navHold.t > 0.38 { navHold.t -= 0.1; fireDir = dir }
        }
        let select = input.firing && !navPrev.select
        let back = (input.padBack && !navPrev.back) || input.menuRequested
        let menuPressed = input.menuRequested
        input.menuRequested = false
        navPrev = (input.firing, input.padBack)

        if screen == .story {
            if select { storyNudge += 1 }
            if back { finishStory() }
            return
        }
        let rows = menuRows
        if var e = callsignEdit {
            // letters: up / down change, left / right move, A keeps, B drops the edit
            switch fireDir {
            case 1: e.step(1)
            case 2: e.step(-1)
            case 3: e.move(-1)
            case 4: e.move(1)
            default: break
            }
            if fireDir != 0 { callsignEdit = e; sound.play(.tick, volume: 0.35, pitch: 1.3) }
            if select { setCallsign(e.text); callsignEdit = nil }
            else if back { callsignEdit = nil; sound.play(.tick, volume: 0.4, pitch: 0.8) }
            return
        }
        if !rows.isEmpty {
            switch fireDir {
            case 1, 2:
                let n = rows.count
                menuIndex = ((menuIndex + (fireDir == 1 ? -1 : 1)) % n + n) % n
                sound.play(.tick, volume: 0.4, pitch: 1.3)
            case 3, 4:
                if rows.indices.contains(menuIndex) { adjust(rows[menuIndex].id, by: fireDir == 3 ? -1 : 1) }
            default: break
            }
            if select, rows.indices.contains(menuIndex) { activate(rows[menuIndex].id) }
        }
        if back {
            if screen == .paused || (menuPressed && simFrozen) {
                // Menu closes the whole pause; B steps back one screen
                if menuPressed { while screens.count > 1 && screens.last != .game { pop() } } else { pop() }
            } else if screens.count > 1 {
                pop()
            }
        }
    }

    /// The message log over the title, the pause or the briefing.
    func openMessages() {
        guard missions.messages.count > 0 else { return }
        push(.messages)
        missions.markMessagesRead()
        mission = missions.snapshot()
    }

    // MARK: Transitions

    /// START / CONTINUE: the job loop in the job's world (rebuilt when free play or another world is up).
    func startJobs() {
        let theme = missions.current.theme
        let rebuild = !builtForJobs || settings.environment != theme.rawValue
        var s = settings
        s.missions = true
        s.environment = theme.rawValue
        settings = s                           // a world change rebuilds by itself
        if rebuild { requestRebuild() }
        setRoot(.game)
        hintVisible = true; hintTimer = 0
        sound.play(.accept)
        gamepad.rumble(intensity: 0.3, sharpness: 0.5)
    }

    /// FREE PLAY: no job, the chosen world (always rebuilt: free play uses the endless track).
    func startFreePlay(world n: Int) {
        var s = settings
        s.missions = false
        s.environment = n
        settings = s
        requestRebuild()
        matchResult = nil
        setRoot(.game)
        hintVisible = true; hintTimer = 0
        sound.play(.accept)
        gamepad.rumble(intensity: 0.3, sharpness: 0.5)
    }

    /// QUIT TO TITLE: the job goes back to its briefing and the title sits over its world, parked.
    func returnToTitle() {
        let theme = missions.current.theme
        let clean = builtForJobs && missions.isParked && missions.previewIndex == missions.index && settings.environment == theme.rawValue
        missions.abandon()
        mission = missions.snapshot()
        matchResult = nil
        var s = settings
        s.missions = true
        s.environment = theme.rawValue
        settings = s
        if !clean { requestRebuild() }
        setRoot(.title)
        sound.play(.tick, volume: 0.5, pitch: 0.8)
    }

    /// RESET PROGRESS (armed by the first press): the first job's briefing, rebuilt behind the settings.
    func resetProgress() {
        missions.resetProgress()
        mission = missions.snapshot()
        player = missions.player
        let theme = missions.current.theme
        var s = settings
        s.missions = true
        s.environment = theme.rawValue
        settings = s
        requestRebuild()
        sound.play(.fail, volume: 0.5)
        gamepad.rumble(intensity: 0.6, sharpness: 0.3)
    }

    /// After a text field (the callsign), give the keys back to the game view (Mac).
    func refocusGame() {
        #if os(macOS)
        arView.window?.makeFirstResponder(arView)
        #endif
    }

    /// The first screen once the world is up: the title, or `SPEEDER_SCREEN=<name>` for screenshots.
    func initialScreens() -> [Screen] {
        switch ProcessInfo.processInfo.environment["SPEEDER_SCREEN"] {
        case "worlds": return [.title, .worlds]
        case "settings": return [.title, .settings]
        case "rider": riderFirstRun = true; return [.title, .rider]
        case "paused": return [.game, .paused]
        case "messages": return [.title, .messages]
        case "riders": riderFirstRun = true; return [.title, .riders]
        case "story": return [.title, .story]
        case "game": return [.game]
        default: return [.title]
        }
    }
}
