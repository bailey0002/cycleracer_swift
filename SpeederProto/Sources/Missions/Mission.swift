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
        s += beacons * (Mission.beaconValue - Mission.gateValue) * Mission.maxStreak / 2
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

    /// The job list, Tron-clean and terse. Deliveries, sweeps, runs and duels interleave.
    static let deliveries: [Mission] = {
        let fork: [TrackBlock] = [.init(style: .fork, curvature: 0, obstacleRows: 0, name: "SPLIT - choose a side"),
                                  .init(style: .branch, name: "branch"), .init(style: .branch, name: "branch"),
                                  .init(style: .branch, name: "branch"), .init(style: .branch, name: "branch")]
        return [
        Mission(id: 0, kind: .delivery, code: "RELAY 01", title: "DOWNTOWN", contact: "VESS",
                brief: "Packet for the downtown relay. Straight run, light traffic. Impacts and boost burn the hull; what is left pays. Do not stop.",
                theme: .neonCity,
                blocks: [.city(0, rows: 0, "downtown"), .city(0, rows: 1, "downtown"), .city(3, rows: 1, "downtown - right bend"),
                         .city(2, rows: 1, "downtown"), .city(-3, rows: 1, "downtown - left bend"), .city(0, rows: 2, "downtown"),
                         .city(0, rows: 1, "relay ahead"), .city(0, rows: 0, "relay")],
                distance: 2400, timeLimit: 70, basePay: 200),
        Mission(id: 1, kind: .search, code: "SWEEP 01", title: "BEACONS", contact: "VESS",
                brief: "Someone seeded the downtown grid with beacons. Fly through them; some sit high. Five of seven and the map is ours.",
                theme: .neonCity,
                blocks: [.city(0, rows: 0, "downtown"), .city(2, rows: 1, "downtown"), .city(-3, rows: 1, "downtown - left bend"),
                         .city(0, rows: 1, "downtown"), .city(4, rows: 1, "downtown - right bend"), .city(0, rows: 1, "downtown"),
                         .city(-2, rows: 1, "downtown"), .city(0, rows: 0, "sweep end")],
                distance: 3000, timeLimit: 85, basePay: 250, beacons: 7, beaconsRequired: 5),
        Mission(id: 2, kind: .delivery, code: "RELAY 02", title: "THE SPLIT", contact: "VESS",
                brief: "Relay sits past the split. Tunnel or skyway, your call. Heavier traffic this time.",
                theme: .neonCity,
                blocks: [.city(0, rows: 1, "downtown"), .city(4, rows: 2, "downtown - right bend"), .city(0, rows: 2, "approaching split")] + fork +
                        [.city(0, rows: 2, "merge"), .city(-3, rows: 2, "downtown - left bend"), .city(0, rows: 1, "relay ahead")],
                distance: 3600, timeLimit: 95, basePay: 300),
        Mission(id: 3, kind: .escape, code: "RUN 01", title: "TAIL", contact: "KADE",
                brief: "You picked up a tail. It is faster than your cruise. Boost opens the gap and burns hull. Reach the relay with it still behind you.",
                theme: .neonCity,
                blocks: [.city(0, rows: 1, "downtown"), .city(3, rows: 1, "downtown - right bend"), .city(0, rows: 2, "downtown"),
                         .city(-4, rows: 1, "downtown - left bend"), .city(0, rows: 2, "downtown"), .city(2, rows: 1, "downtown"),
                         .city(0, rows: 1, "relay ahead"), .city(0, rows: 0, "relay")],
                distance: 2800, timeLimit: 80, basePay: 350, startGap: 70),
        Mission(id: 4, kind: .delivery, code: "RELAY 03", title: "DEEP CONDUIT", contact: "VESS",
                brief: "The relay is below the city. Conduit section: fly the tube, thread the beams. The hull does not like walls.",
                theme: .neonCity,
                blocks: [.city(0, rows: 1, "downtown"), .city(2, rows: 2, "downtown"), .city(0, rows: 0, "conduit ahead"),
                         .tube(rows: 1), .tube(rows: 2), .tube(rows: 2), .tube(rows: 1),
                         .city(0, rows: 2, "downtown"), .city(0, rows: 1, "relay ahead")],
                distance: 3000, timeLimit: 80, basePay: 400),
        Mission(id: 5, kind: .duel, code: "DUEL 01", title: "KADE", contact: "VESS",
                brief: "Kade wants the packet and will not ask twice. Settle it on the Grid. Light cycles, first to two derezzes. Kade hunts: expect a wheel on your tail.",
                theme: .theGrid, blocks: [], distance: 0, timeLimit: 0, basePay: 500, duelTarget: 2, rival: .kade),
        Mission(id: 6, kind: .delivery, code: "RELAY 04", title: "OUTLANDS", contact: "KADE",
                brief: "Carry it out of the city. Canyon road, long bends, a rock-cut tunnel. Daylight. Nobody is watching out there.",
                theme: .sunsetCanyon,
                blocks: [.city(0, rows: 0, "canyon road"), .city(4, rows: 1, "canyon - right bend"), .city(5, rows: 2, "canyon - right bend"),
                         .city(0, rows: 1, "canyon road"), .city(-4, rows: 2, "canyon - left bend"), .city(0, rows: 2, "approaching split")] + fork +
                        [.city(0, rows: 1, "merge"), .city(3, rows: 2, "canyon road"), .city(0, rows: 1, "relay ahead")],
                distance: 4200, timeLimit: 105, basePay: 500),
        Mission(id: 7, kind: .search, code: "SWEEP 02", title: "CANYON", contact: "KADE",
                brief: "Beacons in the canyon, high and low. Six of eight. The bends hide them until late.",
                theme: .sunsetCanyon,
                blocks: [.city(0, rows: 0, "canyon road"), .city(3, rows: 1, "canyon - right bend"), .city(-3, rows: 1, "canyon - left bend"),
                         .city(0, rows: 1, "canyon road"), .city(5, rows: 1, "canyon - right bend"), .city(0, rows: 1, "canyon road"),
                         .city(-4, rows: 1, "canyon - left bend"), .city(0, rows: 0, "sweep end")],
                distance: 3400, timeLimit: 95, basePay: 350, beacons: 8, beaconsRequired: 6),
        Mission(id: 8, kind: .duel, code: "DUEL 02", title: "ORIN", contact: "KADE",
                brief: "Orin runs the canyon relays and wants them back. Kade owes you one: the Grid is booked. Orin boxes: it will cut across your line and close the door.",
                theme: .theGrid, blocks: [], distance: 0, timeLimit: 0, basePay: 650, duelTarget: 2, rival: .orin),
        ]
    }()
}
