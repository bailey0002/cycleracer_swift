import Foundation

/// The goal card (assessment-2026-10-17-rd.md step 2, KERB's `GoalCard.swift` ported): THPS's per-level list, one card
/// per world (Neon City, Sunset Canyon, The Grid), nine lines each, in `narrative.json` `goals` with the Swift table below
/// as the fallback. A line is done once and stays done (`goal.<world>.<id>`, a progress key), and pays its credits once.
/// Jobs and free play share the card, so the endless run and a free match count too.
///
/// Two shapes of line: an **event** line counts `count` events with id `event` inside one run (a kill, a ring, the
/// tunnel at the split, a SURGE pad, a round won), and a **measure** line is done when one run's `measure` reaches
/// `value` (score, streak, metres, grind seconds). Runs start at a job's launch, a free run's card, a match's first round.
/// Log lines: `GOAL done world=<w> id=<id> +<credits> (k/9)`, `GOAL near world=<w> id=<id> k/n`.
struct GoalSpec: Codable, Equatable {
    var id: String
    var text: String
    var event: String? = nil
    var count: Int? = nil
    var measure: String? = nil
    var value: Int? = nil
    var credits: Int? = nil
    var need: Int { max(1, count ?? 1) }
    var pay: Int { credits ?? 100 }
    var eventID: String { event ?? id }
}

enum GoalEvent: Equatable {
    case progress(goal: GoalSpec, n: Int)
    case done(goal: GoalSpec, credits: Int)
}

final class GoalCard {
    static let prefix = "goal."
    static let worlds = ["city", "canyon", "grid"]
    let world: String
    let goals: [GoalSpec]
    private let defaults: UserDefaults
    /// Per-run event counts (THPS: "grind three times" is inside one run).
    private var counts: [Int]
    var logging = false

    init(world: String, defaults: UserDefaults = .standard) {
        self.world = world
        self.defaults = defaults
        goals = Self.specs(world)
        counts = Array(repeating: 0, count: goals.count)
    }

    static func world(for theme: Theme) -> String {
        switch theme {
        case .neonCity: return "city"
        case .sunsetCanyon: return "canyon"
        case .theGrid: return "grid"
        }
    }
    static func title(_ world: String) -> String { ["city": "NEON CITY", "canyon": "SUNSET CANYON", "grid": "THE GRID"][world] ?? world.uppercased() }

    static func specs(_ world: String) -> [GoalSpec] {
        if let g = Narrative.file?.goals?[world], !g.isEmpty { return g }
        return fallback[world] ?? []
    }
    /// Done lines of a world's card, from the stored keys (the notebook's `goals:` rule reads this).
    static func doneCount(world: String, defaults: UserDefaults) -> Int {
        specs(world).filter { defaults.bool(forKey: "\(prefix)\(world).\($0.id)") }.count
    }

    func isDone(_ i: Int) -> Bool { defaults.bool(forKey: "\(Self.prefix)\(world).\(goals[i].id)") }
    var doneCount: Int { goals.indices.filter { isDone($0) }.count }
    var earned: Int { goals.indices.filter { isDone($0) }.map { goals[$0].pay }.reduce(0, +) }

    /// (text, done, progress, credits) per line for the briefing strip and the pause page.
    var items: [(text: String, done: Bool, progress: String, credits: Int)] {
        goals.enumerated().map { i, g in
            let done = isDone(i)
            let progress = !done && g.measure == nil && g.need > 1 && counts[i] > 0 ? "\(min(counts[i], g.need))/\(g.need)" : ""
            return (g.text, done, progress, g.pay)
        }
    }
    /// The first open line (the briefing's NEXT).
    var nextOpen: GoalSpec? { goals.indices.first { !isDone($0) }.map { goals[$0] } }

    func startRun() { counts = Array(repeating: 0, count: goals.count) }

    private func complete(_ i: Int) -> GoalEvent {
        defaults.set(true, forKey: "\(Self.prefix)\(world).\(goals[i].id)")
        if logging { print("GOAL done world=\(world) id=\(goals[i].id) +\(goals[i].pay) (\(doneCount)/\(goals.count))") }
        return .done(goal: goals[i], credits: goals[i].pay)
    }

    /// One event by id: "kill", "beacon", "tunnel", "skyway", "conduit", "undercity", "clean", "gold", "round", "match",
    /// "flawless", "pad", "charge", "pickup", "jump", "duel".
    func note(event id: String) -> [GoalEvent] {
        var out: [GoalEvent] = []
        for (i, g) in goals.enumerated() where g.measure == nil && g.eventID == id && !isDone(i) {
            counts[i] += 1
            if counts[i] >= g.need { out.append(complete(i)) }
            else {
                out.append(.progress(goal: g, n: counts[i]))
                if logging && counts[i] == g.need - 1 { print("GOAL near world=\(world) id=\(g.id) \(counts[i])/\(g.need)") }
            }
        }
        return out
    }

    /// A run's measure reached `value`: "score", "streak", "metres", "grind" (seconds).
    func note(measure id: String, value: Int) -> [GoalEvent] {
        goals.enumerated().compactMap { i, g in
            g.measure == id && !isDone(i) && value >= (g.value ?? Int.max) ? complete(i) : nil
        }
    }

    // MARK: Fallback (narrative.json carries the same lines)

    static let fallback: [String: [GoalSpec]] = [
        "city": [
            GoalSpec(id: "score", text: "Score 2,000 in one job", measure: "score", value: 2000, credits: 100),
            GoalSpec(id: "streak", text: "Build a x8 streak", measure: "streak", value: 8, credits: 100),
            GoalSpec(id: "kills", text: "Destroy 10 targets in one run", event: "kill", count: 10, credits: 100),
            GoalSpec(id: "rings", text: "Fly through 5 rings in one run", event: "beacon", count: 5, credits: 100),
            GoalSpec(id: "tunnel", text: "Take the tunnel at the split", event: "tunnel", credits: 75),
            GoalSpec(id: "skyway", text: "Take the skyway at the split", event: "skyway", credits: 75),
            GoalSpec(id: "conduits", text: "Ride two conduits in one run", event: "conduit", count: 2, credits: 125),
            GoalSpec(id: "clean", text: "Clear a job without a hit", event: "clean", credits: 150),
            GoalSpec(id: "gold", text: "Gold on any city job", event: "gold", credits: 200),
        ],
        "canyon": [
            GoalSpec(id: "score", text: "Score 2,500 in one job", measure: "score", value: 2500, credits: 100),
            GoalSpec(id: "distance", text: "Ride 3 km in one run", measure: "metres", value: 3000, credits: 100),
            GoalSpec(id: "kills", text: "Destroy 12 targets in one run", event: "kill", count: 12, credits: 100),
            GoalSpec(id: "rings", text: "Fly through 6 rings in one run", event: "beacon", count: 6, credits: 100),
            GoalSpec(id: "undercity", text: "Ride under the canyon floor", event: "undercity", credits: 75),
            GoalSpec(id: "low_road", text: "Take the low road at the split", event: "tunnel", credits: 75),
            GoalSpec(id: "pipes", text: "Ride three rock pipes in one run", event: "conduit", count: 3, credits: 125),
            GoalSpec(id: "clean", text: "Clear a canyon job without a hit", event: "clean", credits: 150),
            GoalSpec(id: "gold", text: "Gold on any canyon job", event: "gold", credits: 200),
        ],
        "grid": [
            GoalSpec(id: "round", text: "Win a round", event: "round", credits: 75),
            GoalSpec(id: "match", text: "Win a match", event: "match", credits: 150),
            GoalSpec(id: "flawless", text: "Win a match without losing a round", event: "flawless", credits: 250),
            GoalSpec(id: "pads", text: "Take three SURGE pads in one match", event: "pad", count: 3, credits: 100),
            GoalSpec(id: "charge", text: "Pick up a CHARGE", event: "charge", credits: 75),
            GoalSpec(id: "pickup", text: "Use a PULSE or a PHASE", event: "pickup", credits: 75),
            GoalSpec(id: "jumps", text: "Jump three times in one match", event: "jump", count: 3, credits: 75),
            GoalSpec(id: "grind", text: "Grind a wall for 3 seconds", measure: "grind", value: 3, credits: 125),
            GoalSpec(id: "duel", text: "Win a duel job", event: "duel", credits: 150),
        ],
    ]
}
