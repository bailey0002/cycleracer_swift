import Foundation

/// Guidance (assessment-2026-10-17-rd.md step 2, KERB's `Guidance.swift` ported). Two layers over the briefing card:
///
/// - **Rule cards**: a short card (a title and up to three plain sentences) the first time something is met: the first
///   briefing, each kind of job, the Grid, the first respawn, the first lost round, the goal card, the notebook, the
///   first side offer, the garage. The world waits under the card (`MissionRunner.allowsMotion`); A / a tap dismisses
///   it. Shown once each (`guide.<id>`, a progress key, so a fresh start teaches again and a save remembers).
/// - **Cues**: one-line reminders during a run on their own HUD lane under the comms line ("WINDOW CLOSING  //  GATES
///   ADD TIME"), each with a cooldown and a per-run cap so they never nag.
///
/// `GuidanceLevel`: FULL = cards + cues, LIGHT = cues only, OFF = neither. `prefs.guidance` persists it (SETTINGS and
/// the pause); `SPEEDER_GUIDANCE=0|1|2` forces it for a session. The demo defaults to OFF so no capture waits under a
/// card, unless `SPEEDER_GUIDANCE` asks for them; `SPEEDER_GUIDE_CARD=<id>` raises one card for a simulator sheet.
/// Every card and cue line lives in `narrative.json` (`guidance`); the Swift tables below are the fallback.
/// Log lines: `GUIDE card <id>`, `GUIDE cue <id>: <text>`.
enum GuidanceLevel: Int, CaseIterable {
    case off = 0, light, full
    var label: String { ["OFF", "LIGHT", "FULL"][rawValue] }
    static let names = GuidanceLevel.allCases.map(\.label)
}

struct RuleCard: Equatable {
    let id: String
    let title: String
    let lines: [String]
}

final class Guidance {
    static let levelKey = "prefs.guidance"
    static let prefix = "guide."
    private let defaults: UserDefaults
    /// Persisted choice; `sessionOverride` (env, demo) wins without being saved.
    private(set) var level: GuidanceLevel
    private var sessionOverride: GuidanceLevel? = nil
    var effective: GuidanceLevel { sessionOverride ?? level }
    var logging = false

    init(defaults: UserDefaults = .standard, demo: Bool = false) {
        self.defaults = defaults
        let saved = defaults.object(forKey: Self.levelKey) as? Int
        level = saved.flatMap { GuidanceLevel(rawValue: $0) } ?? .full
        let env = ProcessInfo.processInfo.environment["SPEEDER_GUIDANCE"].flatMap { Int($0) }.flatMap { GuidanceLevel(rawValue: $0) }
        if let env { sessionOverride = env } else if demo { sessionOverride = .off }
    }

    func setLevel(_ l: GuidanceLevel) {
        level = l
        sessionOverride = nil
        defaults.set(l.rawValue, forKey: Self.levelKey)
    }

    // MARK: Rule cards

    func seen(_ id: String) -> Bool { defaults.bool(forKey: Self.prefix + id) }

    /// The card for `id` if it should show now (FULL and never shown before); marks it shown.
    func card(_ id: String) -> RuleCard? {
        guard effective == .full, !seen(id), let c = Self.card(for: id) else { return nil }
        defaults.set(true, forKey: Self.prefix + id)
        if logging { print("GUIDE card \(id)") }
        return c
    }

    /// The card's copy: the narrative file's, else the Swift table's.
    static func card(for id: String) -> RuleCard? {
        if let f = Narrative.file?.guidance?.cards?[id], let t = f.title, let l = f.lines, !l.isEmpty { return RuleCard(id: id, title: t, lines: l) }
        return cards[id]
    }

    /// The kind card a job raises on launch (the duel's before its intro).
    static func kindCard(_ k: Mission.Kind) -> String {
        switch k {
        case .delivery: return "relay"
        case .search: return "sweep"
        case .escape: return "run"
        case .salvage: return "salvage"
        case .dive: return "dive"
        case .duel: return "duel"
        }
    }

    /// Plain words, three lines at most, buttons as the HUD names them. Fallback for `narrative.json`.
    static let cards: [String: RuleCard] = [
        "briefing": RuleCard(id: "briefing", title: "THE JOB CARD",
                             lines: ["This card is the job: who sent it, what it pays, what counts.",
                                     "Left and right browse the inbox. Y buys in the garage.",
                                     "A takes the job. The road waits until you do."]),
        "relay": RuleCard(id: "relay", title: "RELAY",
                          lines: ["Carry the disc to the drop before the window closes.",
                                  "Every gate you pass adds time. Hits and scrapes drain the hull.",
                                  "Hull left at the drop pays out."]),
        "sweep": RuleCard(id: "sweep", title: "SWEEP",
                          lines: ["Fly through the red rings. Some sit high: climb for them.",
                                  "A missed ring goes grey and is gone.",
                                  "Reach the end with enough rings, inside the window."]),
        "run": RuleCard(id: "run", title: "RUN",
                        lines: ["Something is behind you. Stay ahead of it to the relay.",
                                "Boost pulls away, but boost burns the same bar as the hull.",
                                "Caught at four metres."]),
        "salvage": RuleCard(id: "salvage", title: "SALVAGE",
                            lines: ["Shoot the marked targets before the drop.",
                                    "A or L1 fires. Each target refills a little hull.",
                                    "Miss too many and the job fails at the end."]),
        "dive": RuleCard(id: "dive", title: "DIVE",
                         lines: ["A conduit time trial. No weapons.",
                                 "Hits bruise the hull twice as hard.",
                                 "Thread the obstacles and keep the window."]),
        "duel": RuleCard(id: "duel", title: "THE GRID",
                         lines: ["Light cycles. Your trail is a wall, and so is theirs.",
                                 "Make the rival hit a trail or a wall. Hitting your own loses the round.",
                                 "Pads charge the boost. Win the rounds the card asks for."]),
        "respawn": RuleCard(id: "respawn", title: "HULL RESTORED",
                            lines: ["An empty hull costs a respawn, not the job.",
                                    "You ride on from here at half hull, four seconds down.",
                                    "Two per job. The count is under the hull bar."]),
        "derez": RuleCard(id: "derez", title: "DEREZZED",
                          lines: ["You lost a round, not the duel.",
                                  "Turn early: the rival cuts across your nose.",
                                  "Stay off your own trail. It kills you as well."]),
        "goals": RuleCard(id: "goals", title: "THE GOAL CARD",
                          lines: ["Every world has nine goals. Once done, they stay done.",
                                  "Each goal pays credits once, in jobs or in free play.",
                                  "The card is on the briefing and in the pause menu."]),
        "notebook": RuleCard(id: "notebook", title: "THE NOTEBOOK",
                             lines: ["Each chapter keeps a short list of things worth doing.",
                                     "Lines tick themselves when you do them.",
                                     "Stuck? Pause, open the notebook and call your contact."]),
        "offer": RuleCard(id: "offer", title: "SIDE OFFER",
                          lines: ["Someone wants a job done their way. It is in the inbox, in amber.",
                                  "Same road, one extra rule, a bonus on top.",
                                  "The bonus pays once."]),
        "garage": RuleCard(id: "garage", title: "THE GARAGE",
                           lines: ["You can afford a part. The garage is on this card.",
                                   "Up and down pick a part, Y buys it. On touch, tap the row.",
                                   "Parts stay fitted for every job after."]),
    ]

    // MARK: Cues

    struct Cue { let text: String; let cooldown: Float; let perRun: Int }
    static let cues: [String: Cue] = [
        "hull_low": Cue(text: "HULL LOW  //  EASE OFF THE BOOST", cooldown: 20, perRun: 2),
        "hull_refill": Cue(text: "HULL LOW  //  RINGS AND TARGETS REFILL IT", cooldown: 20, perRun: 2),
        "time_low": Cue(text: "WINDOW CLOSING  //  GATES ADD TIME", cooldown: 25, perRun: 1),
        "gap_close": Cue(text: "PURSUER CLOSE  //  BOOST PULLS AWAY", cooldown: 18, perRun: 2),
        "rings_short": Cue(text: "RINGS LEFT  //  {n} MORE NEEDED", cooldown: 30, perRun: 1),
        "targets_short": Cue(text: "TARGETS LEFT  //  {n} MORE TO DESTROY", cooldown: 30, perRun: 1),
        "streak": Cue(text: "STREAK x{n}  //  A HIT RESETS IT", cooldown: 60, perRun: 1),
        "boost_empty": Cue(text: "BOOST NEEDS HULL  //  LET IT RECHARGE", cooldown: 40, perRun: 1),
        "goal_near": Cue(text: "ONE MORE FOR THE GOAL", cooldown: 10, perRun: 3),
        "grid_energy": Cue(text: "ENERGY LOW  //  PADS RECHARGE IT", cooldown: 25, perRun: 2),
        "grid_edge": Cue(text: "TOO CLOSE  //  GIVE THE TRAIL ROOM", cooldown: 25, perRun: 2),
    ]

    private var lastShown: [String: Float] = [:]
    private var shownThisRun: [String: Int] = [:]

    func startRun() { shownThisRun = [:]; lastShown = [:] }

    /// The cue's text if it may show now (LIGHT or FULL, cooldown passed, under its per-run cap). `now` = run time.
    func cue(_ id: String, now: Float, n: Int = 0) -> String? {
        guard effective != .off, let c = Self.cues[id] else { return nil }
        if let t = lastShown[id], now - t < c.cooldown { return nil }
        if shownThisRun[id, default: 0] >= c.perRun { return nil }
        lastShown[id] = now
        shownThisRun[id, default: 0] += 1
        let text = Narrative.fill(Narrative.file?.guidance?.cues?[id] ?? c.text, ["n": "\(n)"])
        if logging { print("GUIDE cue \(id): \(text) at \(String(format: "%.1f", now)) s") }
        return text
    }
}
