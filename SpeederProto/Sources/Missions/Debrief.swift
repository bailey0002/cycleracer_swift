import Foundation

/// The story between runs, Hades' way: one line that proves the game saw what you just did.
/// Priority is essential (the job's own debrief, always shown) > reactive (chosen from the run's
/// outcome) > evergreen. A reactive line is not repeated until the contact's others have been said.
enum Debrief {
    /// What the run looked like, in the order the lines care about.
    struct Outcome {
        var kind: Mission.Kind
        var hits = 0
        var respawnsUsed = 0
        var hullLeft: Float = 1
        var rank: Mission.Rank = .none
        var newBest = false
        var fast = false
        var timeLeftFraction: Float = 0
        var derezCause = ""          // duels: the last cause of the player's derez ("BOXED YOURSELF", "CUT OFF BY KADE")
        var duelScore = (wins: 0, losses: 0)
        var branch = 0               // the split, when the track had one: -1 tunnel, +1 skyway
    }

    /// The fork acknowledged (assessment 5.5): the contact saw which branch you took.
    private static func branchLine(_ contact: String, tunnel: Bool) -> String {
        switch (contact, tunnel) {
        case ("VESS", true): return "The tunnel. Kade saw that."
        case ("VESS", false): return "The skyway. Half the city saw that."
        case ("KADE", true): return "You took the tunnel. Good instinct."
        case ("KADE", false): return "The skyway. Orin watches the skyway."
        case ("ORIN", true): return "The tunnel. Quieter."
        case ("ORIN", false): return "The skyway. Showy."
        case (_, true): return "The tunnel. As agreed."
        case (_, false): return "The skyway. Not what I paid for."
        }
    }

    private enum Key: String, CaseIterable {
        case respawnsTwo, respawnsOne, hullLow, cleanFast, gold, newBest, fast, sloppy, clean, duelSweep, duelClose, duelBoxed, evergreen
    }

    /// Which line the outcome earns, highest priority first.
    private static func key(for o: Outcome) -> Key {
        if o.kind == .duel {
            if o.duelScore.losses == 0 { return .duelSweep }
            if o.derezCause.hasPrefix("BOXED") { return .duelBoxed }
            return .duelClose
        }
        if o.respawnsUsed >= 2 { return .respawnsTwo }
        if o.respawnsUsed == 1 { return .respawnsOne }
        if o.hullLeft < 0.25 { return .hullLow }
        if o.hits == 0 && o.fast { return .cleanFast }
        if o.rank == .gold { return .gold }
        if o.newBest { return .newBest }
        if o.fast { return .fast }
        if o.hits >= 4 { return .sloppy }
        if o.hits == 0 { return .clean }
        return .evergreen
    }

    /// One register per contact: VESS clipped, KADE blunt and warm, ORIN sharp.
    private static func lines(_ contact: String, _ k: Key, _ o: Outcome) -> [String] {
        switch (contact, k) {
        case ("VESS", .respawnsTwo): return ["Two respawns. The client noticed. So did I.", "Two cores. The route pays for one."]
        case ("VESS", .respawnsOne): return ["One respawn. Do not make it a habit.", "A core burned. It comes off the fee."]
        case ("VESS", .hullLow): return ["Hull under a quarter. Riders like that stop being riders.", "You arrived on fumes. Arrive."]
        case ("VESS", .cleanFast): return ["Clean and early. Keep that.", "Untouched, ahead of the window. That is the job."]
        case ("VESS", .gold): return ["Gold. Do not let it go to your head.", "A gold run. The route noticed."]
        case ("VESS", .newBest): return ["Better than last time. That is all I ask.", "A new best. Do it again."]
        case ("VESS", .fast): return ["Early. The relay was not ready for you.", "Ahead of the window. Good."]
        case ("VESS", .sloppy): return ["You hit \(o.hits) things. None of them were moving.", "\(o.hits) impacts. The packet felt every one."]
        case ("VESS", .clean): return ["Not a scratch. Noted.", "Clean. Nothing to say."]
        case ("VESS", .evergreen): return ["Delivered. Next.", "The packet is in. That is all I need.", "Acceptable."]
        case ("KADE", .respawnsTwo): return ["Two cores burned. The bike forgives. I count.", "Twice down. Out here that is once too many."]
        case ("KADE", .respawnsOne): return ["One core. Happens. Do not let it happen twice.", "Burned a core. The canyon does that."]
        case ("KADE", .hullLow): return ["You limped in. Next time boost less and steer more.", "Hull nearly gone. Ride the middle of the road."]
        case ("KADE", .cleanFast): return ["Clean and fast. That is how I would have ridden it.", "Not a mark on it and early. Good."]
        case ("KADE", .gold): return ["Gold. You ride like you mean it.", "That was a gold run. Vess never paid me for one of those."]
        case ("KADE", .newBest): return ["Faster than last time. Keep pushing.", "A better run. The road is learning you."]
        case ("KADE", .fast): return ["Early. The window was generous anyway.", "Fast. Now do it clean."]
        case ("KADE", .sloppy): return ["\(o.hits) hits. The rocks are not going anywhere; go around them.", "You took \(o.hits). Ease off the boost in the fields."]
        case ("KADE", .clean): return ["Clean. Good.", "Not a scratch. I noticed."]
        case ("KADE", .evergreen): return ["Done. Have a drink.", "Delivered. The canyon is yours tonight.", "Job's done."]
        case ("ORIN", .respawnsTwo): return ["Twice. I have seen drones do better.", "Two respawns. Sable would have laughed."]
        case ("ORIN", .respawnsOne): return ["One respawn. Sloppy, but alive.", "A core down. Sharpen up."]
        case ("ORIN", .hullLow): return ["Hull in the red. The core does not do mercy.", "You crawled in. Boost is not a plan."]
        case ("ORIN", .cleanFast): return ["Clean and early. Fine. I am impressed. Do not quote me.", "Untouched and ahead. That is core pace."]
        case ("ORIN", .gold): return ["Gold. The fastest riders in the system would nod.", "A gold. Sable will hate that."]
        case ("ORIN", .newBest): return ["Better. Keep it up.", "A new best. Good. Again."]
        case ("ORIN", .fast): return ["Fast. Now stop hitting things.", "Early. The core likes early."]
        case ("ORIN", .sloppy): return ["\(o.hits) impacts. The fields were not that dense.", "You hit \(o.hits). Read the lanes earlier."]
        case ("ORIN", .clean): return ["Clean. Adequate.", "Not a scratch. Fine."]
        case ("ORIN", .evergreen): return ["Done. Next job.", "Delivered. The core does not care how.", "Adequate."]
        case (_, .duelSweep): return ["A sweep. Not one derez. The Grid will remember that.", "Clean sweep. They never got a wall in front of you."]
        case (_, .duelBoxed): return ["You won, but you boxed yourself once. Watch your own trail.", "Won. Your own wall nearly cost it."]
        case (_, .duelClose): return ["Close. \(o.duelScore.wins) to \(o.duelScore.losses). The next one will be closer.", "\(o.duelScore.wins) - \(o.duelScore.losses). You took the hit and came back. Good."]
        default: return ["Done."]
        }
    }

    /// Pick the reactive line for this contact and outcome, skipping lines said before until all are spent.
    static func reactive(contact: String, outcome: Outcome, defaults: UserDefaults = .standard) -> String {
        let k = key(for: outcome)
        let candidates = lines(contact, k, outcome)
        let saidKey = "said.\(contact).\(k.rawValue)"
        var said = Set(defaults.stringArray(forKey: saidKey) ?? [])
        var unsaid = candidates.enumerated().filter { !said.contains(String($0.offset)) }
        if unsaid.isEmpty { said = []; unsaid = Array(candidates.enumerated()) }
        let pick = unsaid[Int(defaults.integer(forKey: "cleared") + outcome.hits) % max(1, unsaid.count)]
        said.insert(String(pick.offset))
        defaults.set(Array(said), forKey: saidKey)
        if outcome.branch != 0 { return branchLine(contact, tunnel: outcome.branch < 0) + " " + pick.element }
        return pick.element
    }

    /// The failed card's line, per contact and cause.
    static func failure(contact: String, reason: String) -> String {
        let cause = reason.split(separator: " ").first.map(String.init) ?? reason
        switch (contact, cause) {
        case (_, "TOOK"): return "That was the skyway. The deal was the tunnel. Again."
        case ("VESS", "CAUGHT"): return "Caught. The packet is gone. So is the fee."
        case ("VESS", "HULL"): return "Hull breached. The packet is scrap. Try again."
        case ("VESS", "TIME"): return "Late. The relay closed. Ride the window next time."
        case ("VESS", "DEREZZED"): return "Derezzed. Kade keeps the route for now. Again."
        case ("VESS", _): return "Incomplete. The route does not pay for almost."
        case ("KADE", "CAUGHT"): return "They got you. Boost in the open, not in the bends."
        case ("KADE", "HULL"): return "Hull gone. The canyon wins one. Go again."
        case ("KADE", "TIME"): return "Out of time. Cut the corners, not the bike."
        case ("KADE", "DEREZZED"): return "Derezzed. Watch the walls, then watch mine."
        case ("KADE", _): return "Not enough. Once more."
        case ("ORIN", "CAUGHT"): return "Caught. Vess's drones do not miss twice."
        case ("ORIN", "HULL"): return "Breached. The core eats the careless."
        case ("ORIN", "TIME"): return "Late. In the core, late is dead."
        case ("ORIN", "DEREZZED"): return "Derezzed. Sable will have watched that. Again."
        case ("ORIN", _): return "Incomplete. Do it properly."
        default: return "Run failed. Again."
        }
    }

    /// The rival's line on the intro card, from the head-to-head record (F-Zero 99: rivals from history).
    /// The record deepens the memory: a third meeting and a streak either way get their own lines.
    static func taunt(rival: String, record: (wins: Int, losses: Int)) -> String {
        let first = record.wins + record.losses == 0
        let leads = record.losses > record.wins
        let meetings = record.wins + record.losses
        if meetings >= 3 {
            switch rival {
            case "KADE": return leads ? "\"Third time. You keep coming back to lose.\"" : "\"Third time, courier. I have been counting.\""
            case "ORIN": return leads ? "\"Again. The door will be where it always is.\"" : "\"You have read my line. Let us see if you can read a new one.\""
            case "SABLE": return leads ? "\"You are becoming a habit. A cheap one.\"" : "\"Nobody beats me \(record.wins) times. Not for long.\""
            case "VESS": return leads ? "\"I still hold the licence. Ride for it.\"" : "\"You want the route so badly? Take it from me again.\""
            default: break
            }
        }
        switch rival {
        case "KADE":
            if first { return "\"Hunter, they call me. Do not look back.\"" }
            return leads ? "\"Still riding? I left you in pieces last time.\"" : "\"You got lucky. The Grid does not do luck twice.\""
        case "ORIN":
            if first { return "\"I close doors. You will find that out.\"" }
            return leads ? "\"Boxed you once. The walls remember.\"" : "\"You cut a good line. Cut it again if you can.\""
        case "SABLE":
            if first { return "\"A courier. On my Grid. This will be brief.\"" }
            return leads ? "\"Slow. Still slow.\"" : "\"You out-ran me once. Once.\""
        case "VESS":
            if first { return "\"I taught Kade. Kade taught you. Let us see what is left.\"" }
            return leads ? "\"I dispatched better riders than you.\"" : "\"You should have stayed a courier.\""
        default:
            return first ? "\"Let us see.\"" : (leads ? "\"Again?\"" : "\"Not this time.\"")
        }
    }

    /// The rival's voice in the duel (Hades' rule on the Grid): one line per round at most, from the
    /// round's outcome and the record, shown as a comms stamp once the derez attribution has cleared.
    enum DuelEvent { case matchStart, wonRound, lostRoundCutOff, lostRoundBoxed, lostRoundOther, playerLeads, rivalLeads, matchPoint }
    static func rivalLine(rival: String, event: DuelEvent, record: (wins: Int, losses: Int), wins: Int, losses: Int) -> String {
        switch (rival, event) {
        case ("KADE", .wonRound): return ["Lucky wall.", "Fine. Ride.", "I felt that one."][wins % 3]
        case ("KADE", .lostRoundCutOff): return ["Told you not to look back.", "Hunted.", "Your tail is mine."][losses % 3]
        case ("KADE", .lostRoundBoxed): return "Your own wall. I did not even turn."
        case ("KADE", .lostRoundOther): return "Sloppy. Again."
        case ("KADE", .playerLeads): return "Do not get comfortable."
        case ("KADE", .rivalLeads): return "Feel that? That is a hunt."
        case ("KADE", .matchPoint): return wins > losses ? "One more and I will remember it." : "One more. Then the packet is mine."
        case ("ORIN", .wonRound): return ["Adequate.", "You cut well. Once.", "Noted."][wins % 3]
        case ("ORIN", .lostRoundCutOff): return ["Door closed.", "You never saw the wall.", "Boxed."][losses % 3]
        case ("ORIN", .lostRoundBoxed): return "You did my work for me."
        case ("ORIN", .lostRoundOther): return "Careless."
        case ("ORIN", .playerLeads): return "Enjoy it."
        case ("ORIN", .rivalLeads): return "This is what the canyon relays pay for."
        case ("ORIN", .matchPoint): return wins > losses ? "Close the door then. If you can." : "Last door."
        case ("SABLE", .wonRound): return ["Slow, but lucky.", "A courier. Really.", "Noise."][wins % 3]
        case ("SABLE", .lostRoundCutOff): return ["Bought and paid for.", "Too slow.", "Derezzed. As purchased."][losses % 3]
        case ("SABLE", .lostRoundBoxed): return "You are cheaper than I paid."
        case ("SABLE", .lostRoundOther): return "Dull."
        case ("SABLE", .playerLeads): return "Vess will refund me."
        case ("SABLE", .rivalLeads): return "The route is mine already."
        case ("SABLE", .matchPoint): return wins > losses ? "No. Not to a courier." : "Collecting."
        case ("VESS", .wonRound): return ["I dispatched better.", "Kade taught you that.", "Provisional."][wins % 3]
        case ("VESS", .lostRoundCutOff): return ["The licence is mine.", "Ride the window.", "Sold."][losses % 3]
        case ("VESS", .lostRoundBoxed): return "Your own trail. I taught Kade that."
        case ("VESS", .lostRoundOther): return "Acceptable. For Sable."
        case ("VESS", .playerLeads): return "You were a good rider. Were."
        case ("VESS", .rivalLeads): return "The route was never going to be yours."
        case ("VESS", .matchPoint): return wins > losses ? "Take it, then. Take it from me." : "Last packet."
        case (_, .matchStart):
            let n = record.wins + record.losses
            return n == 0 ? "" : (record.losses > record.wins ? "Again? \(record.losses) - \(record.wins)." : "\(record.wins) - \(record.losses). Not this time.")
        default: return ""
        }
    }

    /// A one-line role for the contact's card.
    static func role(_ name: String) -> String {
        switch name {
        case "VESS": return "DISPATCHER"
        case "KADE": return "OUTLANDS RIDER"
        case "ORIN": return "RELAY RUNNER"
        case "SABLE": return "THE BUYER"
        default: return "CONTACT"
        }
    }
}
