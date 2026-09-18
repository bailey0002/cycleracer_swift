import Foundation

/// One job. A mission picks the world and the track blocks, sets a goal and pays out.
struct Mission: Identifiable {
    enum Kind { case delivery, search, escape, duel }
    let id: Int
    let kind: Kind
    let code: String            // "RELAY 01"
    let title: String           // "DOWNTOWN"
    let contact: String
    let brief: String
    let theme: Theme
    let blocks: [TrackBlock]
    let distance: Float         // metres to the drop
    let timeLimit: Float        // seconds
    let basePay: Int
    // search
    var beacons: Int = 0
    var beaconsRequired: Int = 0
    // escape
    var startGap: Float = 70
    // duel
    var duelTarget: Int = 2
    var rival: Rival? = nil

    /// Streak scoring: a gate every `gateSpacing` metres, beacons and kills, each worth its base
    /// times the streak; a hit resets the streak. Rank thresholds are fractions of the job's
    /// theoretical maximum, so they are per job without hand tuning.
    static let gateSpacing: Float = 200
    static let gateValue = 50, beaconValue = 150, killValue = 25, maxStreak = 8
    var gates: Int { kind == .duel ? 0 : Int(distance / Mission.gateSpacing) }
    /// The best possible streak score: every gate and beacon clean, streak climbing to the cap.
    var maxScore: Int {
        var s = 0, streak = 1
        for _ in 0..<(gates + beacons) { s += Mission.gateValue * streak; streak = min(Mission.maxStreak, streak + 1) }
        // beacons taken on a capped streak: the ceiling assumes the clean run, so gold is earned
        s += beacons * (Mission.beaconValue - Mission.gateValue) * Mission.maxStreak
        return s
    }
    var silverScore: Int { Int(Float(maxScore) * 0.40) }
    var goldScore: Int { Int(Float(maxScore) * 0.70) }
    func rank(for score: Int, success: Bool) -> Rank {
        guard success, kind != .duel else { return success ? .gold : .none }
        return score >= goldScore ? .gold : (score >= silverScore ? .silver : .bronze)
    }

    enum Rank: Int, Comparable {
        case none = 0, bronze, silver, gold
        static func < (a: Rank, b: Rank) -> Bool { a.rawValue < b.rawValue }
        var text: String { switch self { case .none: return "-"; case .bronze: return "BRONZE"; case .silver: return "SILVER"; case .gold: return "GOLD" } }
    }

    var timeText: String { "\(Int(timeLimit)) s" }
    var distanceText: String { String(format: "%.1f km", distance / 1000) }
    /// The goal line on the briefing card.
    var goalText: String {
        switch kind {
        case .delivery: return "DROP \(distanceText)   WINDOW \(timeText)   HULL PAYS"
        case .search:   return "SWEEP \(distanceText)   WINDOW \(timeText)   BEACONS \(beaconsRequired) OF \(beacons)"
        case .escape:   return "RUN \(distanceText)   WINDOW \(timeText)   PURSUER AT \(Int(startGap)) m"
        case .duel:     return "THE GRID   FIRST TO \(duelTarget) DEREZZES   VS \(rival?.name ?? "RIVAL") // \(rival?.temper.rawValue ?? "")"
        }
    }
    var successTitle: String {
        switch kind { case .delivery: return "DELIVERED"; case .search: return "SWEEP COMPLETE"; case .escape: return "ESCAPED"; case .duel: return "DUEL WON" }
    }

    /// Track blocks for a corridor job: composed from the recipe over the whole distance.
    static func track(_ distance: Float, _ recipe: [TrackComposer.Phrase], theme: Theme, finish: String, seed: UInt64) -> [TrackBlock] {
        TrackComposer.compose(distance: distance, recipe: recipe, place: theme == .sunsetCanyon ? "canyon road" : "downtown", finish: finish, seed: seed)
    }

    /// Side objectives on every corridor job (Asphalt 9 flags, Alto's goals): earned once, kept forever.
    struct Flags: OptionSet {
        let rawValue: Int
        static let clean = Flags(rawValue: 1)      // no hits
        static let fast = Flags(rawValue: 2)       // finished with a third of the window left
        static let gold = Flags(rawValue: 4)       // gold rank
        static let all: [(Flags, String)] = [(.clean, "CLEAN"), (.fast, "FAST"), (.gold, "GOLD")]
        var text: String { Flags.all.map { contains($0.0) ? "[\($0.1)]" : " \($0.1) " }.joined(separator: " ") }
    }

    /// The job list, Tron-clean and terse. Deliveries, sweeps, runs and duels interleave. Every
    /// corridor track is composed over its full length (`TrackComposer`), so the bends, fields,
    /// splits, conduits, undercity runs, skyways and landmarks keep coming until the drop.
    static let deliveries: [Mission] = {
        return [
        Mission(id: 0, kind: .delivery, code: "RELAY 01", title: "DOWNTOWN", contact: "VESS",
                brief: "Packet for the downtown relay. Straight run, light traffic. Impacts and boost burn the hull; what is left pays. Do not stop.",
                theme: .neonCity,
                blocks: Mission.track(2400, [.straight(2), .bend, .straight(1), .landmark, .field, .bend, .straight(2), .sBend, .landmark, .straight(1)],
                              theme: .neonCity, finish: "relay", seed: 101),
                distance: 2400, timeLimit: 70, basePay: 200),
        Mission(id: 1, kind: .search, code: "SWEEP 01", title: "BEACONS", contact: "VESS",
                brief: "Someone seeded the downtown grid with beacons. Fly through them; some sit high. Five of seven and the map is ours.",
                theme: .neonCity,
                blocks: Mission.track(3000, [.straight(2), .bend, .field, .sBend, .landmark, .skyway, .bend, .straight(2), .field, .landmark],
                              theme: .neonCity, finish: "sweep end", seed: 102),
                distance: 3000, timeLimit: 85, basePay: 250, beacons: 7, beaconsRequired: 5),
        Mission(id: 2, kind: .delivery, code: "RELAY 02", title: "THE SPLIT", contact: "VESS",
                brief: "Relay sits past the split. Tunnel or skyway, your call. Heavier traffic this time.",
                theme: .neonCity,
                blocks: Mission.track(3600, [.straight(1), .bend, .field, .split, .landmark, .sBend, .field, .bend, .landmark, .straight(1), .field],
                              theme: .neonCity, finish: "relay", seed: 103),
                distance: 3600, timeLimit: 95, basePay: 300),
        Mission(id: 3, kind: .escape, code: "RUN 01", title: "TAIL", contact: "KADE",
                brief: "You picked up a tail. It is faster than your cruise. Boost opens the gap and burns hull. Reach the relay with it still behind you.",
                theme: .neonCity,
                blocks: Mission.track(2800, [.straight(2), .bend, .undercity, .sBend, .landmark, .field, .bend, .straight(2), .landmark],
                              theme: .neonCity, finish: "relay", seed: 104),
                distance: 2800, timeLimit: 80, basePay: 350, startGap: 70),
        Mission(id: 4, kind: .delivery, code: "RELAY 03", title: "DEEP CONDUIT", contact: "VESS",
                brief: "The relay is below the city. Conduit sections: fly the tube, thread the beams. The hull does not like walls.",
                theme: .neonCity,
                blocks: Mission.track(3000, [.straight(1), .bend, .conduit, .field, .landmark, .sBend, .conduit, .bend, .straight(1), .landmark],
                              theme: .neonCity, finish: "relay", seed: 105),
                distance: 3000, timeLimit: 80, basePay: 400),
        Mission(id: 5, kind: .duel, code: "DUEL 01", title: "KADE", contact: "VESS",
                brief: "Kade wants the packet and will not ask twice. Settle it on the Grid. Light cycles, first to two derezzes. Kade hunts: expect a wheel on your tail.",
                theme: .theGrid, blocks: [], distance: 0, timeLimit: 0, basePay: 500, duelTarget: 2, rival: .kade),
        Mission(id: 6, kind: .delivery, code: "RELAY 04", title: "OUTLANDS", contact: "KADE",
                brief: "Carry it out of the city. Canyon road, long bends, a rock-cut tunnel, a split. Daylight. Nobody is watching out there.",
                theme: .sunsetCanyon,
                blocks: Mission.track(4200, [.straight(1), .bend, .bend, .landmark, .undercity, .sBend, .field, .split, .landmark, .bend, .straight(2), .field],
                              theme: .sunsetCanyon, finish: "relay", seed: 106),
                distance: 4200, timeLimit: 105, basePay: 500),
        Mission(id: 7, kind: .search, code: "SWEEP 02", title: "CANYON", contact: "KADE",
                brief: "Beacons in the canyon, high and low. Six of eight. The bends hide them until late.",
                theme: .sunsetCanyon,
                blocks: Mission.track(3400, [.straight(1), .bend, .sBend, .landmark, .skyway, .bend, .field, .undercity, .landmark, .bend, .straight(1)],
                              theme: .sunsetCanyon, finish: "sweep end", seed: 107),
                distance: 3400, timeLimit: 95, basePay: 350, beacons: 8, beaconsRequired: 6),
        Mission(id: 8, kind: .duel, code: "DUEL 02", title: "ORIN", contact: "KADE",
                brief: "Orin runs the canyon relays and wants them back. Kade owes you one: the Grid is booked. Orin boxes: it will cut across your line and close the door.",
                theme: .theGrid, blocks: [], distance: 0, timeLimit: 0, basePay: 650, duelTarget: 2, rival: .orin),
        ]
    }()
}
