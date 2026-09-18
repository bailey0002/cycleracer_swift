import Foundation

/// One job. A mission picks the world and the track blocks, sets a goal and pays out.
struct Mission: Identifiable {
    /// Delivery: reach the drop inside the window. Search: fly through N of M beacons. Escape: keep
    /// the pursuer behind you. Duel: The Grid. Salvage: destroy N marked targets before the drop.
    /// Dive: a conduit time trial with no weapons and a hull that bruises twice as hard.
    enum Kind { case delivery, search, escape, duel, salvage, dive }
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
    // story
    var chapter: Int = 1
    /// What the contact says on the result card when the job is done: the story, one line at a time.
    var debrief: String = ""
    // search
    var beacons: Int = 0
    var beaconsRequired: Int = 0
    // escape
    var startGap: Float = 70
    // duel
    var duelTarget: Int = 2
    var rival: Rival? = nil
    // salvage
    var killsRequired: Int = 0

    var weaponsAllowed: Bool { kind != .dive }
    /// Dive jobs: hits cost twice as much hull (precision is the point).
    var hullFactor: Float { kind == .dive ? 2 : 1 }

    /// Streak scoring: a gate every `gateSpacing` metres, beacons and kills, each worth its base
    /// times the streak; a hit resets the streak. Rank thresholds are fractions of the job's
    /// theoretical maximum, so they are per job without hand tuning.
    static let gateSpacing: Float = 200
    static let gateValue = 50, beaconValue = 150, killValue = 25, maxStreak = 8
    /// Every gate adds a little time to the window (Crazy Taxi: arriving fast buys time).
    static let gateTime: Float = 1.5
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
        case .salvage:  return "SALVAGE \(distanceText)   WINDOW \(timeText)   DESTROY \(killsRequired) TARGETS"
        case .dive:     return "DIVE \(distanceText)   WINDOW \(timeText)   NO WEAPONS   HULL BRUISES x2"
        }
    }
    var successTitle: String {
        switch kind {
        case .delivery: return "DELIVERED"; case .search: return "SWEEP COMPLETE"; case .escape: return "ESCAPED"
        case .duel: return "DUEL WON"; case .salvage: return "SALVAGE SECURED"; case .dive: return "DIVE CLEAN"
        }
    }
    var kindText: String {
        switch kind {
        case .delivery: return "DELIVERY"; case .search: return "SWEEP"; case .escape: return "ESCAPE"
        case .duel: return "DUEL"; case .salvage: return "SALVAGE"; case .dive: return "DIVE"
        }
    }

    /// Chapter titles: the three districts of the story.
    static func chapterTitle(_ c: Int) -> String {
        switch c { case 1: return "DOWNTOWN"; case 2: return "OUTLANDS"; default: return "THE CORE" }
    }

    /// Track blocks for a corridor job: composed from the recipe over the whole distance. `density`
    /// scales the obstacle rows (chapter 1 light, chapter 3 dense).
    static func track(_ distance: Float, _ recipe: [TrackComposer.Phrase], theme: Theme, finish: String, seed: UInt64, density: Float = 1) -> [TrackBlock] {
        TrackComposer.compose(distance: distance, recipe: recipe, place: theme == .sunsetCanyon ? "canyon road" : "downtown",
                              finish: finish, seed: seed, density: density)
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

    /// The job list: three chapters, eighteen jobs, Tron-clean and terse. Every corridor track is
    /// composed over its full length (`TrackComposer`); the chapter sets the obstacle density.
    ///
    /// The story in one breath: VESS dispatches packets across the downtown grid; KADE wants them
    /// and loses the duel; out in the canyon KADE becomes the contact and ORIN is the rival; in the
    /// core it turns out VESS has been selling the packets to SABLE all along, ORIN rides with you,
    /// and the last duels settle it.
    static let deliveries: [Mission] = {
        let d1: Float = 0.8, d2: Float = 1.0, d3: Float = 1.3
        return [
        // --- chapter 1: downtown (VESS)
        Mission(id: 0, kind: .delivery, code: "RELAY 01", title: "FIRST PACKET", contact: "VESS",
                brief: "New rider. Packet for the downtown relay. Impacts and boost burn the hull; what is left pays. Do not stop.",
                theme: .neonCity,
                blocks: track(2400, [.straight(2), .bend, .straight(1), .landmark, .field, .bend, .straight(2), .sBend, .landmark, .straight(1)],
                              theme: .neonCity, finish: "relay", seed: 101, density: d1),
                distance: 2400, timeLimit: 66, basePay: 200, chapter: 1,
                debrief: "VESS: Clean enough. There is more where that came from. Do not ask what is in them."),
        Mission(id: 1, kind: .search, code: "SWEEP 01", title: "BEACONS", contact: "VESS",
                brief: "Someone seeded the grid with beacons. Fly through them; some sit high. Five of seven and the map is ours.",
                theme: .neonCity,
                blocks: track(3000, [.straight(2), .bend, .field, .sBend, .landmark, .skyway, .bend, .straight(2), .field, .landmark],
                              theme: .neonCity, finish: "sweep end", seed: 102, density: d1),
                distance: 3000, timeLimit: 80, basePay: 250, chapter: 1,
                debrief: "VESS: The beacons were Kade's. Now Kade knows your trail colour.", beacons: 7, beaconsRequired: 5),
        Mission(id: 2, kind: .delivery, code: "RELAY 02", title: "THE SPLIT", contact: "VESS",
                brief: "Relay sits past the split. Tunnel or skyway, your call. Heavier traffic this time.",
                theme: .neonCity,
                blocks: track(3600, [.straight(1), .bend, .field, .split, .landmark, .sBend, .field, .bend, .landmark, .straight(1), .field],
                              theme: .neonCity, finish: "relay", seed: 103, density: d1),
                distance: 3600, timeLimit: 90, basePay: 300, chapter: 1,
                debrief: "VESS: Delivered. A rider named Kade asked about you at the relay. I said nothing."),
        Mission(id: 3, kind: .escape, code: "RUN 01", title: "TAIL", contact: "VESS",
                brief: "You picked up a tail. It is faster than your cruise. Boost opens the gap and burns hull. Reach the relay with it still behind you.",
                theme: .neonCity,
                blocks: track(2800, [.straight(2), .bend, .undercity, .sBend, .landmark, .field, .bend, .straight(2), .landmark],
                              theme: .neonCity, finish: "relay", seed: 104, density: d1),
                distance: 2800, timeLimit: 76, basePay: 350, chapter: 1,
                debrief: "VESS: That was Kade's drone. It will not be a drone next time.", startGap: 70),
        Mission(id: 4, kind: .delivery, code: "RELAY 03", title: "DEEP CONDUIT", contact: "VESS",
                brief: "The relay is below the city. Conduit sections: fly the tube, thread the beams. The hull does not like walls.",
                theme: .neonCity,
                blocks: track(3000, [.straight(1), .bend, .conduit, .field, .landmark, .sBend, .conduit, .bend, .straight(1), .landmark],
                              theme: .neonCity, finish: "relay", seed: 105, density: d1),
                distance: 3000, timeLimit: 76, basePay: 400, chapter: 1,
                debrief: "VESS: Kade has booked the Grid. It wants the packet. Settle it there or lose the route."),
        Mission(id: 5, kind: .duel, code: "DUEL 01", title: "KADE", contact: "VESS",
                brief: "Kade wants the packet and will not ask twice. Settle it on the Grid. Light cycles, first to two derezzes. Kade hunts: expect a wheel on your tail.",
                theme: .theGrid, blocks: [], distance: 0, timeLimit: 0, basePay: 500, chapter: 1,
                debrief: "KADE: You ride clean. Vess does not. Come out to the canyon and I will show you what the packets are.",
                duelTarget: 2, rival: .kade),
        // --- chapter 2: outlands (KADE)
        Mission(id: 6, kind: .delivery, code: "RELAY 04", title: "OUTLANDS", contact: "KADE",
                brief: "Carry it out of the city. Canyon road, long bends, a rock-cut tunnel, a split. Daylight. Nobody is watching out there.",
                theme: .sunsetCanyon,
                blocks: track(4200, [.straight(1), .bend, .bend, .landmark, .undercity, .sBend, .field, .split, .landmark, .bend, .straight(2), .field],
                              theme: .sunsetCanyon, finish: "relay", seed: 106, density: d2),
                distance: 4200, timeLimit: 100, basePay: 500, chapter: 2,
                debrief: "KADE: The relay out here is mine. Every packet Vess sends passes through it. Open one."),
        Mission(id: 7, kind: .search, code: "SWEEP 02", title: "CANYON", contact: "KADE",
                brief: "Beacons in the canyon, high and low. Six of eight. The bends hide them until late.",
                theme: .sunsetCanyon,
                blocks: track(3400, [.straight(1), .bend, .sBend, .landmark, .skyway, .bend, .field, .undercity, .landmark, .bend, .straight(1)],
                              theme: .sunsetCanyon, finish: "sweep end", seed: 107, density: d2),
                distance: 3400, timeLimit: 90, basePay: 350, chapter: 2,
                debrief: "KADE: Orin planted those. Orin runs the canyon relays for someone in the core.", beacons: 8, beaconsRequired: 6),
        Mission(id: 8, kind: .salvage, code: "SALVAGE 01", title: "CONVOY", contact: "KADE",
                brief: "A convoy went down on the canyon road. Its drones and crates are still live. Destroy eight before the drop and the cargo is ours.",
                theme: .sunsetCanyon,
                blocks: track(3200, [.straight(1), .field, .bend, .field, .landmark, .sBend, .field, .bend, .field, .landmark],
                              theme: .sunsetCanyon, finish: "salvage drop", seed: 108, density: d2),
                distance: 3200, timeLimit: 88, basePay: 450, chapter: 2,
                debrief: "KADE: Packets in every crate. Addresses in the core. Vess is not delivering these. Vess is selling them.", killsRequired: 8),
        Mission(id: 9, kind: .escape, code: "RUN 02", title: "ORIN'S TAIL", contact: "KADE",
                brief: "Orin is behind you and it is not a drone. Keep the gap through the tunnel. The skyway is faster than it looks.",
                theme: .sunsetCanyon,
                blocks: track(3200, [.straight(1), .bend, .undercity, .field, .skyway, .landmark, .sBend, .bend, .straight(1)],
                              theme: .sunsetCanyon, finish: "relay", seed: 109, density: d2),
                distance: 3200, timeLimit: 84, basePay: 450, chapter: 2,
                debrief: "KADE: Orin does not lose tails. Orin will want the Grid. Fly the pipe first; you will need the precision.", startGap: 60),
        Mission(id: 10, kind: .dive, code: "DIVE 01", title: "ROCK PIPE", contact: "KADE",
                brief: "The old pipe under the mesa. No weapons, a hull that bruises twice as hard, and a window that does not forgive. Thread it.",
                theme: .sunsetCanyon,
                blocks: track(2600, [.conduit, .straight(1), .conduit, .bend, .conduit, .straight(1)],
                              theme: .sunsetCanyon, finish: "pipe end", seed: 110, density: d2),
                distance: 2600, timeLimit: 62, basePay: 500, chapter: 2,
                debrief: "KADE: Clean. Now Orin. Orin boxes: it will cut across your line and close the door."),
        Mission(id: 11, kind: .duel, code: "DUEL 02", title: "ORIN", contact: "KADE",
                brief: "Orin runs the canyon relays and wants them back. Kade owes you one: the Grid is booked. Orin boxes: it will cut across your line and close the door.",
                theme: .theGrid, blocks: [], distance: 0, timeLimit: 0, basePay: 650, chapter: 2,
                debrief: "ORIN: Fine. You win. But you are working for the wrong dispatcher. Vess sells to Sable. Come to the core and I will prove it.",
                duelTarget: 2, rival: .orin),
        // --- chapter 3: the core (ORIN)
        Mission(id: 12, kind: .escape, code: "RUN 03", title: "DOUBLE CROSS", contact: "ORIN",
                brief: "Vess knows. Its drones are on you from the first metre and they are close. Boost early, thread the fields, reach the core relay.",
                theme: .neonCity,
                blocks: track(3400, [.straight(1), .field, .bend, .landmark, .conduit, .field, .sBend, .skyway, .field, .landmark, .bend],
                              theme: .neonCity, finish: "core relay", seed: 112, density: d3),
                distance: 3400, timeLimit: 86, basePay: 600, chapter: 3,
                debrief: "ORIN: Still alive. Sable's crates move through the core at night. Let us take them apart.", startGap: 50),
        Mission(id: 13, kind: .salvage, code: "SALVAGE 02", title: "SABLE'S CRATES", contact: "ORIN",
                brief: "Sable's shipment runs the core grid tonight: crates and escort drones in every field. Twelve targets before the drop.",
                theme: .neonCity,
                blocks: track(3800, [.straight(1), .field, .bend, .field, .landmark, .field, .sBend, .field, .undercity, .field, .landmark, .field],
                              theme: .neonCity, finish: "core drop", seed: 113, density: d3),
                distance: 3800, timeLimit: 96, basePay: 650, chapter: 3,
                debrief: "ORIN: That was a month of Sable's income. Sable will come to the Grid now. First we take the deep line.", killsRequired: 12),
        Mission(id: 14, kind: .dive, code: "DIVE 02", title: "DEEP LINE", contact: "ORIN",
                brief: "The core's data conduit: three pipes back to back, no weapons, twice the bruise. The fastest riders in the system set their times here.",
                theme: .neonCity,
                blocks: track(3000, [.conduit, .conduit, .straight(1), .landmark, .conduit, .bend, .conduit],
                              theme: .neonCity, finish: "line end", seed: 114, density: d3),
                distance: 3000, timeLimit: 68, basePay: 650, chapter: 3,
                debrief: "ORIN: A core time. Vess has hidden its ledger in beacons across the core. Sweep them and we have proof."),
        Mission(id: 15, kind: .search, code: "SWEEP 03", title: "THE LEDGER", contact: "ORIN",
                brief: "Vess's ledger, split across ten beacons in the densest grid in the system. Eight of ten. Some sit high over the fields.",
                theme: .neonCity,
                blocks: track(4000, [.straight(1), .bend, .field, .landmark, .sBend, .skyway, .field, .bend, .undercity, .field, .landmark, .bend],
                              theme: .neonCity, finish: "sweep end", seed: 115, density: d3),
                distance: 4000, timeLimit: 100, basePay: 700, chapter: 3,
                debrief: "ORIN: It is all there. Every packet, every buyer. Sable has booked the Grid and named you.", beacons: 10, beaconsRequired: 8),
        Mission(id: 16, kind: .duel, code: "DUEL 03", title: "SABLE", contact: "ORIN",
                brief: "Sable does not box and does not hunt. Sable runs: open ground, the pads, the deck, and it will out-speed you if you let it. First to three.",
                theme: .theGrid, blocks: [], distance: 0, timeLimit: 0, basePay: 900, chapter: 3,
                debrief: "SABLE: Derezzed twice by a courier. Vess picked the wrong rider to sell out. Vess is on the Grid. Go.",
                duelTarget: 3, rival: .sable),
        Mission(id: 17, kind: .duel, code: "DUEL 04", title: "VESS", contact: "ORIN",
                brief: "Vess rides its own cycle tonight, and it rides like Kade taught it: on your tail, grinding your line. First to three. End it.",
                theme: .theGrid, blocks: [], distance: 0, timeLimit: 0, basePay: 1200, chapter: 3,
                debrief: "ORIN: The route is yours. Every relay from downtown to the canyon. Ride it however you like.",
                duelTarget: 3, rival: .vess),
        ]
    }()
}
