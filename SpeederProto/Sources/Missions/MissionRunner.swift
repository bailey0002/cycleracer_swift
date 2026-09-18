import Foundation

/// One line of the inbox: a job the player can pick (or has cleared).
struct JobEntry: Equatable {
    let id: Int
    let code: String
    let title: String
    let kindText: String
    let contact: String
    let chapter: Int
    let cleared: Bool
    let rank: Mission.Rank
}

/// Bike upgrades bought with credits in the garage (Alto's workshop): small, visible, repeatable.
struct Upgrades: Equatable {
    var hull = 0        // 0...2: hit damage 25 % / 20 % / 16 %
    var boost = 0       // 0...2: boost drain 12 / 9 / 7 % per second
    var respawn = 0     // 0...1: one more checkpoint respawn per job
    var helmet = 0      // 0...1: the first hit of every job is free

    struct Item: Equatable {
        let key: String, title: String, detail: String, price: Int, level: Int, max: Int
        var owned: Bool { level >= max }
        var text: String { owned ? "\(title)  OWNED" : "\(title) \(level + 1 > 1 ? "II" : "I")  \(price)  \(detail)" }
    }
    var items: [Item] {
        [Item(key: "hull", title: "HULL PLATING", detail: "hits cost less", price: hull == 0 ? 600 : 1200, level: hull, max: 2),
         Item(key: "boost", title: "BOOST COIL", detail: "boost burns less", price: boost == 0 ? 500 : 1000, level: boost, max: 2),
         Item(key: "respawn", title: "SPARE CORE", detail: "+1 respawn per job", price: 900, level: respawn, max: 1),
         Item(key: "helmet", title: "HELMET", detail: "first hit free", price: 700, level: helmet, max: 1)]
    }
    var hitDamage: Float { [0.25, 0.20, 0.16][min(2, hull)] }
    var boostDrain: Float { [0.12, 0.09, 0.07][min(2, boost)] }
    var respawns: Int { MissionRunner.respawnsPerJob + respawn }

    static let key = "upgrades"
    static func load(_ d: UserDefaults) -> Upgrades {
        let v = d.integer(forKey: key)
        return Upgrades(hull: v & 3, boost: (v >> 2) & 3, respawn: (v >> 4) & 1, helmet: (v >> 5) & 1)
    }
    func save(_ d: UserDefaults) { d.set(hull | (boost << 2) | (respawn << 4) | (helmet << 5), forKey: Upgrades.key) }
}

/// Snapshot of the mission state for the HUD.
struct MissionState: Equatable {
    enum Phase: Equatable { case briefing, running, success, failed, freePlay }
    var phase: Phase = .freePlay
    var code = ""
    var title = ""
    var contact = ""
    var brief = ""
    var debrief = ""
    var chapter = 1
    var chapterTitle = ""
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
    var rivalSkill = ""
    // salvage
    var kills = 0
    var killsRequired = 0
    // streak scoring
    var score = 0
    var streak = 1
    var rank: Mission.Rank = .none
    var bestRank: Mission.Rank = .none
    var silverScore = 0
    var goldScore = 0
    var respawnsLeft = 0
    var helmetArmed = false
    /// Side objectives: the flags earned on this job so far, and the ones earned by this run.
    var flags: Mission.Flags = []
    var newFlags: Mission.Flags = []
    // inbox and garage (briefing only)
    var cleared = false            // this job was cleared before: a replay pays half
    var browsing = false           // the card shows a job other than the loaded one
    var jobs: [JobEntry] = []      // every unlocked job
    var upgrades = Upgrades()
    var shopSelection = 0
    var shopNote = ""
}

/// The job loop: briefing -> running (timer, hull energy, distance) -> success / failed -> next.
/// One energy bar is both hull and boost fuel (F-Zero / Wipeout): hits, scrapes and boost drain it,
/// beacons and kills refill it, a trickle recharges it, and what is left at the drop pays out.
/// Owned by `GameController`, which feeds it distance and hits and rebuilds the world when
/// the mission changes. The briefing is also the inbox (browse any unlocked job) and the garage
/// (buy upgrades with the purse).
final class MissionRunner {
    private(set) var missions: [Mission]
    private(set) var index: Int
    /// The job the briefing card shows; differs from `index` while browsing the inbox.
    private(set) var previewIndex: Int
    private(set) var phase: MissionState.Phase = .briefing
    private(set) var credits: Int
    private(set) var upgrades: Upgrades
    private(set) var shopSelection = 0
    private var shopNote = ""
    /// Set when a retry should start the run as soon as the world is rebuilt (one-tap retry).
    var autoStart = false
    private var elapsed: Float = 0
    private var travelled: Float = 0
    private var energy: Float = 1
    private var payout = 0
    private var failReason = ""
    private var beaconsHit = 0
    private var killsTaken = 0
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
    private var helmetArmed = false
    private(set) var helmetUsedNow = false
    /// Boost hysteresis: an empty bar disarms boost until it has recovered a little, so holding
    /// the trigger on an empty hull does not flicker the boost on and off every few frames.
    private var boostArmed = true
    /// Set on the frame a gate or beacon scores (HUD stamp), cleared next update.
    private(set) var scoredNow: (value: Int, streak: Int, time: Float)? = nil
    private let defaults = UserDefaults.standard
    static let scrapeDrain: Float = 0.08      // per second against a barrier
    static let recharge: Float = 0.035        // per second when not boosting or scraping
    static let beaconCharge: Float = 0.2
    static let killCharge: Float = 0.05
    /// Escape: the pursuer cruises a little faster than the player; boost outruns it but burns hull.
    static let pursuerSpeed: Float = 47

    init(missions: [Mission] = Mission.deliveries) {
        self.missions = missions
        let env = ProcessInfo.processInfo.environment
        if env["SPEEDER_RESET_PROGRESS"] == "1" {
            for k in ["credits", "missionIndex", "cleared", Upgrades.key] { defaults.removeObject(forKey: k) }
            for m in missions { defaults.removeObject(forKey: "rank.\(m.id)"); defaults.removeObject(forKey: "flags.\(m.id)") }
        }
        credits = defaults.integer(forKey: "credits")
        upgrades = Upgrades.load(defaults)
        index = abs(defaults.integer(forKey: "missionIndex")) % max(1, missions.count)
        if let m = env["SPEEDER_MISSION"], let i = Int(m) { index = abs(i) % max(1, missions.count) }
        previewIndex = index
    }

    var current: Mission { missions[index] }
    var preview: Mission { missions[previewIndex] }
    var isRunning: Bool { phase == .running }
    /// The vehicle only moves while the job is live.
    var allowsMotion: Bool { phase == .running }

    // MARK: - Progress

    /// Jobs are cleared in order; `clearedCount` is one past the highest cleared index.
    private var clearedCount: Int { defaults.integer(forKey: "cleared") }
    func isCleared(_ i: Int) -> Bool { i < clearedCount }
    /// A job is unlocked once the one before it is cleared (the first always is).
    func isUnlocked(_ i: Int) -> Bool { i <= clearedCount }
    private var lastUnlocked: Int { min(missions.count - 1, clearedCount) }

    /// Inbox: move the briefing to the previous / next unlocked job (wraps).
    func browse(_ delta: Int) {
        guard phase == .briefing else { return }
        let n = lastUnlocked + 1
        previewIndex = ((previewIndex + delta) % n + n) % n
        shopNote = ""
    }
    func browse(to i: Int) {
        guard phase == .briefing, isUnlocked(i) else { return }
        previewIndex = i
        shopNote = ""
    }

    /// Garage: move the highlight, buy the highlighted upgrade.
    func shopMove(_ delta: Int) {
        guard phase == .briefing else { return }
        let n = upgrades.items.count
        shopSelection = ((shopSelection + delta) % n + n) % n
    }
    @discardableResult
    func buySelected() -> Bool {
        guard phase == .briefing else { return false }
        let item = upgrades.items[shopSelection]
        if item.owned { shopNote = "\(item.title): OWNED"; return false }
        guard credits >= item.price else { shopNote = "\(item.title): NEED \(item.price - credits) MORE"; return false }
        credits -= item.price
        switch item.key {
        case "hull": upgrades.hull += 1
        case "boost": upgrades.boost += 1
        case "respawn": upgrades.respawn += 1
        default: upgrades.helmet += 1
        }
        upgrades.save(defaults)
        defaults.set(credits, forKey: "credits")
        shopNote = "\(item.title): BOUGHT"
        return true
    }

    /// Accept the briefing, or continue past a result. Returns true when the world must be
    /// rebuilt for a new (or retried) mission.
    func accept() -> Bool {
        switch phase {
        case .briefing:
            if previewIndex != index {
                // the inbox chose another job: load it (the world rebuilds), then brief it
                index = previewIndex
                defaults.set(index, forKey: "missionIndex")
                shopNote = ""
                return true
            }
            phase = .running
            elapsed = 0; travelled = 0; energy = 1; payout = 0
            beaconsHit = 0; killsTaken = 0; gap = current.startGap; duelWins = 0; duelLosses = 0
            score = 0; streak = 1; nextGate = Mission.gateSpacing; rank = .none; scoredNow = nil
            respawnsLeft = upgrades.respawns; respawnedNow = false
            hitsTaken = 0; newFlags = []; boostArmed = true
            helmetArmed = upgrades.helmet > 0; helmetUsedNow = false
            return false
        case .success:
            index = min(missions.count - 1, max(index + 1, lastUnlocked))
            if index == missions.count - 1 && isCleared(index) { index = 0 }   // the arc is done: ride it again
            previewIndex = index
            defaults.set(index, forKey: "missionIndex")
            phase = .briefing
            return true
        case .failed:
            phase = .briefing
            previewIndex = index
            autoStart = true
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
    private func scoreEvent(base: Int, climbs: Bool = true, time: Float = 0) {
        let v = base * streak
        score += v
        scoredNow = (v, streak, time)
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
        killsTaken += newKills
        // the helmet takes the first hit of the job
        var hits = newHits
        helmetUsedNow = false
        if hits > 0 && helmetArmed { helmetArmed = false; helmetUsedNow = true; hits -= 1 }
        hitsTaken += hits
        // streak scoring: a hit resets the ladder; gates, beacons and kills climb it
        scoredNow = nil
        if hits > 0 { streak = 1 }
        while travelled >= nextGate && nextGate <= m.distance {
            // a gate also buys time (the window is a resource you refill by riding clean and fast)
            scoreEvent(base: Mission.gateValue, time: Mission.gateTime)
            elapsed = max(0, elapsed - Mission.gateTime)
            nextGate += Mission.gateSpacing
        }
        for _ in 0..<beaconsHitNow { scoreEvent(base: Mission.beaconValue) }
        for _ in 0..<newKills { scoreEvent(base: Mission.killValue, climbs: false) }
        // the one bar
        if hits > 0 { energy -= Float(hits) * upgrades.hitDamage * m.hullFactor }
        if scraping { energy -= dt * Self.scrapeDrain * m.hullFactor }
        if boosting { energy -= dt * upgrades.boostDrain }
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
            if m.kind == .salvage && killsTaken < m.killsRequired { fail("TARGETS MISSED \(killsTaken)/\(m.killsRequired)"); return }
            let timeBonus = Int(max(0, m.timeLimit - elapsed)) * 5
            let hullBonus = Int(energy * 100) * 2
            var bonus = 0
            switch m.kind {
            case .search: bonus = beaconsHit * 40
            case .escape: bonus = Int(gap) * 2
            case .salvage: bonus = killsTaken * 30
            case .dive: bonus = hullBonus          // precision pays twice
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
        let replay = isCleared(index)
        payout = replay ? pay / 2 : pay
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
        if !replay { defaults.set(index + 1, forKey: "cleared") }
        // the payout is banked with the job, so a relaunch on the result card cannot replay it
        defaults.set(min(missions.count - 1, index + 1), forKey: "missionIndex")
        phase = .success
    }

    private func fail(_ reason: String) {
        failReason = reason
        phase = .failed
    }

    func snapshot() -> MissionState {
        let shown = phase == .briefing ? preview : current
        let m = shown
        let jobs: [JobEntry] = phase == .briefing ? (0...lastUnlocked).map { i in
            let j = missions[i]
            return JobEntry(id: j.id, code: j.code, title: j.title, kindText: j.kindText, contact: j.contact, chapter: j.chapter,
                            cleared: isCleared(i), rank: bestRank(for: j))
        } : []
        return MissionState(phase: phase, code: m.code, title: m.title, contact: m.contact, brief: m.brief, debrief: m.debrief,
                            chapter: m.chapter, chapterTitle: Mission.chapterTitle(m.chapter),
                            distanceText: m.distanceText, timeText: m.timeText,
                            timeLeft: max(0, m.timeLimit - elapsed), distanceLeft: max(0, m.distance - travelled),
                            energy: energy, payout: payout, credits: credits, failReason: failReason,
                            index: previewIndex, count: missions.count, kind: m.kind, goalText: m.goalText, successTitle: m.successTitle,
                            beaconsHit: beaconsHit, beaconsTotal: m.beacons, beaconsRequired: m.beaconsRequired,
                            gap: gap, startGap: m.startGap, duelWins: duelWins, duelLosses: duelLosses, duelTarget: m.duelTarget,
                            rivalName: m.rival?.name ?? "", rivalTemper: m.rival?.temper.rawValue ?? "", rivalLine: m.rival?.temper.line ?? "",
                            rivalSkill: m.rival?.skill.text ?? "",
                            kills: killsTaken, killsRequired: m.killsRequired,
                            score: score, streak: streak, rank: rank, bestRank: bestRank(for: m), silverScore: m.silverScore, goldScore: m.goldScore,
                            respawnsLeft: respawnsLeft, helmetArmed: helmetArmed, flags: flags(for: m), newFlags: newFlags,
                            cleared: isCleared(previewIndex), browsing: previewIndex != index, jobs: jobs,
                            upgrades: upgrades, shopSelection: shopSelection, shopNote: shopNote)
    }
}
