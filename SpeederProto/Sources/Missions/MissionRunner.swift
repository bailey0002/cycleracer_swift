import Foundation

/// Snapshot of the mission state for the HUD.
struct MissionState: Equatable {
    enum Phase: Equatable { case briefing, running, success, failed, freePlay }
    var phase: Phase = .freePlay
    var code = ""
    var title = ""
    var contact = ""
    var brief = ""
    var distanceText = ""
    var timeText = ""
    var timeLeft: Float = 0
    var distanceLeft: Float = 0
    var energy: Float = 1         // 0...1 hull + boost fuel (one bar)
    var payout = 0
    var credits = 0
    var failReason = ""
    var index = 0
    var count = 0
    var kind: Mission.Kind = .delivery
    var goalText = ""
    var successTitle = ""
    // search
    var beaconsHit = 0
    var beaconsTotal = 0
    var beaconsRequired = 0
    // escape
    var gap: Float = 0
    var startGap: Float = 70
    // duel
    var duelWins = 0
    var duelLosses = 0
    var duelTarget = 0
    var rivalName = ""
    var rivalTemper = ""
    var rivalLine = ""
    // streak scoring
    var score = 0
    var streak = 1
    var rank: Mission.Rank = .none
    var bestRank: Mission.Rank = .none
    var silverScore = 0
    var goldScore = 0
    var respawnsLeft = 0
    /// Side objectives: the flags earned on this job so far, and the ones earned by this run.
    var flags: Mission.Flags = []
    var newFlags: Mission.Flags = []
}

/// The job loop: briefing -> running (timer, hull energy, distance) -> success / failed -> next.
/// One energy bar is both hull and boost fuel (F-Zero / Wipeout): hits, scrapes and boost drain it,
/// beacons and kills refill it, a trickle recharges it, and what is left at the drop pays out.
/// Owned by `GameController`, which feeds it distance and hits and rebuilds the world when
/// the mission changes.
final class MissionRunner {
    private(set) var missions: [Mission]
    private(set) var index: Int
    private(set) var phase: MissionState.Phase = .briefing
    private(set) var credits: Int
    private var elapsed: Float = 0
    private var travelled: Float = 0
    private var energy: Float = 1
    private var payout = 0
    private var failReason = ""
    private var beaconsHit = 0
    private var gap: Float = 0
    private var duelWins = 0
    private var duelLosses = 0
    private var score = 0
    private var streak = 1
    private var nextGate: Float = 0
    private var rank: Mission.Rank = .none
    /// Checkpoint respawns: a breached hull restores in place (speed kept) at a time cost, twice per job.
    static let respawnsPerJob = 2
    static let respawnPenalty: Float = 4
    private var respawnsLeft = 0
    private(set) var respawnedNow = false
    private var hitsTaken = 0
    private var newFlags: Mission.Flags = []
    /// Boost hysteresis: an empty bar disarms boost until it has recovered a little, so holding
    /// the trigger on an empty hull does not flicker the boost on and off every few frames.
    private var boostArmed = true
    /// Set on the frame a gate or beacon scores (HUD stamp), cleared next update.
    private(set) var scoredNow: (value: Int, streak: Int)? = nil
    private let defaults = UserDefaults.standard
    static let hitDamage: Float = 0.25
    static let scrapeDrain: Float = 0.08      // per second against a barrier
    static let boostDrain: Float = 0.12       // per second of boost (about 8 s from full)
    static let recharge: Float = 0.035        // per second when not boosting or scraping
    static let beaconCharge: Float = 0.2
    static let killCharge: Float = 0.05
    /// Escape: the pursuer cruises a little faster than the player; boost outruns it but burns hull.
    static let pursuerSpeed: Float = 47

    init(missions: [Mission] = Mission.deliveries) {
        self.missions = missions
        let env = ProcessInfo.processInfo.environment
        if env["SPEEDER_RESET_PROGRESS"] == "1" {
            defaults.removeObject(forKey: "credits"); defaults.removeObject(forKey: "missionIndex")
            for m in missions { defaults.removeObject(forKey: "rank.\(m.id)"); defaults.removeObject(forKey: "flags.\(m.id)") }
        }
        credits = defaults.integer(forKey: "credits")
        index = abs(defaults.integer(forKey: "missionIndex")) % max(1, missions.count)
        if let m = env["SPEEDER_MISSION"], let i = Int(m) { index = abs(i) % max(1, missions.count) }
    }

    var current: Mission { missions[index] }
    var isRunning: Bool { phase == .running }
    /// The vehicle only moves while the job is live.
    var allowsMotion: Bool { phase == .running }

    /// Accept the briefing, or continue past a result. Returns true when the world must be
    /// rebuilt for a new (or retried) mission.
    func accept() -> Bool {
        switch phase {
        case .briefing:
            phase = .running
            elapsed = 0; travelled = 0; energy = 1; payout = 0
            beaconsHit = 0; gap = current.startGap; duelWins = 0; duelLosses = 0
            score = 0; streak = 1; nextGate = Mission.gateSpacing; rank = .none; scoredNow = nil
            respawnsLeft = Self.respawnsPerJob; respawnedNow = false
            hitsTaken = 0; newFlags = []; boostArmed = true
            return false
        case .success:
            index = (index + 1) % missions.count
            defaults.set(index, forKey: "missionIndex")
            phase = .briefing
            return true
        case .failed:
            phase = .briefing
            return true
        case .running, .freePlay:
            return false
        }
    }

    /// Flags earned per job, remembered across launches.
    func flags(for m: Mission) -> Mission.Flags { Mission.Flags(rawValue: defaults.integer(forKey: "flags.\(m.id)")) }

    /// Best rank per job, remembered across launches.
    func bestRank(for m: Mission) -> Mission.Rank { Mission.Rank(rawValue: defaults.integer(forKey: "rank.\(m.id)")) ?? .none }
    private func remember(_ r: Mission.Rank, for m: Mission) {
        if r > bestRank(for: m) { defaults.set(r.rawValue, forKey: "rank.\(m.id)") }
    }

    /// One scored event: worth its base times the streak, then the streak climbs (to a cap).
    private func scoreEvent(base: Int, climbs: Bool = true) {
        let v = base * streak
        score += v
        scoredNow = (v, streak)
        if climbs { streak = min(Mission.maxStreak, streak + 1) }
    }

    /// Free play on The Grid pays into the same purse.
    func award(_ amount: Int) {
        credits += amount
        defaults.set(credits, forKey: "credits")
    }

    /// Boost burns hull, so it needs some left (with hysteresis: empty disarms it until 15 %).
    var boostAllowed: Bool { phase != .running || boostArmed }

    /// Advance a live corridor job. `travel` is metres moved this frame, `speed` the vehicle speed,
    /// `newHits` collisions and `newKills` obstacle kills since last frame, `beaconsHitNow` rings
    /// flown through this frame.
    func update(dt: Float, travel: Float, speed: Float, newHits: Int, boosting: Bool, scraping: Bool = false, newKills: Int = 0, beaconsHitNow: Int = 0) {
        guard phase == .running else { return }
        let m = current
        elapsed += dt
        travelled += travel
        beaconsHit += beaconsHitNow
        hitsTaken += newHits
        // streak scoring: a hit resets the ladder; gates, beacons and kills climb it
        scoredNow = nil
        if newHits > 0 { streak = 1 }
        while travelled >= nextGate && nextGate <= m.distance { scoreEvent(base: Mission.gateValue); nextGate += Mission.gateSpacing }
        for _ in 0..<beaconsHitNow { scoreEvent(base: Mission.beaconValue) }
        for _ in 0..<newKills { scoreEvent(base: Mission.killValue, climbs: false) }
        // the one bar
        if newHits > 0 { energy -= Float(newHits) * Self.hitDamage }
        if scraping { energy -= dt * Self.scrapeDrain }
        if boosting { energy -= dt * Self.boostDrain }
        else if !scraping { energy += dt * Self.recharge }
        energy += Float(beaconsHitNow) * Self.beaconCharge + Float(newKills) * Self.killCharge
        energy = max(0, min(1, energy))
        if energy <= 0.02 { boostArmed = false } else if energy > 0.15 { boostArmed = true }
        respawnedNow = false
        if energy <= 0 {
            // checkpoint respawn (Trackmania / Thumper): the run goes on from here with the hull restored,
            // the streak reset and a time penalty, until the respawns are spent
            if respawnsLeft > 0 {
                respawnsLeft -= 1
                energy = 0.5
                streak = 1
                elapsed += Self.respawnPenalty
                respawnedNow = true
                if elapsed >= m.timeLimit { respawnedNow = false; fail("TIME OUT"); return }
            } else {
                fail("HULL BREACHED"); return
            }
        }
        if m.kind == .escape {
            // the pursuer launches with you: its speed ramps up over the first seconds
            let pursuer = min(Self.pursuerSpeed, elapsed * 22)
            gap += (speed - pursuer) * dt
            if gap <= 4 { fail("CAUGHT"); return }
        }
        if travelled >= m.distance {
            if m.kind == .search && beaconsHit < m.beaconsRequired { fail("SWEEP INCOMPLETE \(beaconsHit)/\(m.beaconsRequired)"); return }
            let timeBonus = Int(max(0, m.timeLimit - elapsed)) * 5
            let hullBonus = Int(energy * 100) * 2
            var bonus = 0
            switch m.kind {
            case .search: bonus = beaconsHit * 40
            case .escape: bonus = Int(gap) * 2
            default: break
            }
            succeed(m.basePay + timeBonus + hullBonus + bonus + score / 5)
            return
        }
        if elapsed >= m.timeLimit { fail("TIME OUT") }
    }

    /// Advance a live duel from the arena's score.
    func updateDuel(dt: Float, wins: Int, losses: Int) {
        guard phase == .running, current.kind == .duel else { return }
        elapsed += dt
        duelWins = wins; duelLosses = losses
        if wins >= current.duelTarget { score = (wins - losses) * 100; succeed(current.basePay + max(0, wins - losses) * 100); return }
        if losses >= current.duelTarget { fail("DEREZZED \(losses) TIMES") }
    }

    private func succeed(_ pay: Int) {
        payout = pay
        credits += payout
        defaults.set(credits, forKey: "credits")
        rank = current.rank(for: score, success: true)
        remember(rank, for: current)
        if current.kind != .duel {
            var earned: Mission.Flags = []
            if hitsTaken == 0 { earned.insert(.clean) }
            if current.timeLimit - elapsed >= current.timeLimit / 3 { earned.insert(.fast) }
            if rank == .gold { earned.insert(.gold) }
            let before = flags(for: current)
            newFlags = earned.subtracting(before)
            defaults.set(before.union(earned).rawValue, forKey: "flags.\(current.id)")
        }
        // the payout is banked with the job, so a relaunch on the result card cannot replay it
        defaults.set((index + 1) % missions.count, forKey: "missionIndex")
        phase = .success
    }

    private func fail(_ reason: String) {
        failReason = reason
        phase = .failed
    }

    func snapshot() -> MissionState {
        let m = current
        return MissionState(phase: phase, code: m.code, title: m.title, contact: m.contact, brief: m.brief,
                            distanceText: m.distanceText, timeText: m.timeText,
                            timeLeft: max(0, m.timeLimit - elapsed), distanceLeft: max(0, m.distance - travelled),
                            energy: energy, payout: payout, credits: credits, failReason: failReason,
                            index: index, count: missions.count, kind: m.kind, goalText: m.goalText, successTitle: m.successTitle,
                            beaconsHit: beaconsHit, beaconsTotal: m.beacons, beaconsRequired: m.beaconsRequired,
                            gap: gap, startGap: m.startGap, duelWins: duelWins, duelLosses: duelLosses, duelTarget: m.duelTarget,
                            rivalName: m.rival?.name ?? "", rivalTemper: m.rival?.temper.rawValue ?? "", rivalLine: m.rival?.temper.line ?? "",
                            score: score, streak: streak, rank: rank, bestRank: bestRank(for: m), silverScore: m.silverScore, goldScore: m.goldScore,
                            respawnsLeft: respawnsLeft, flags: flags(for: m), newFlags: newFlags)
    }
}
