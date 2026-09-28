import Foundation
import simd

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
    var offer = false             // a side offer chip (id = MissionRunner.offerChipBase + offer id)
    var bonus = 0
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
        // Prices (27 Sep 2026, headless loop): a clean chapter 1 pays about 5,700 credits, a sloppy one
        // 4,300; the set costs 9,800, so chapter 1 buys two pieces and the set is complete late in chapter 3.
        [Item(key: "hull", title: "HULL PLATING", detail: "hits cost less", price: hull == 0 ? 1200 : 2400, level: hull, max: 2),
         Item(key: "boost", title: "BOOST COIL", detail: "boost burns less", price: boost == 0 ? 1000 : 2000, level: boost, max: 2),
         Item(key: "respawn", title: "SPARE CORE", detail: "+1 respawn per job", price: 1800, level: respawn, max: 1),
         Item(key: "helmet", title: "HELMET", detail: "first hit free", price: 1400, level: helmet, max: 1)]
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
    enum Phase: Equatable { case chapter, briefing, rivalIntro, running, success, failed, freePlay }
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
    var jobs: [JobEntry] = []      // every unlocked job, then the side offers on the table
    var shownChip = 0              // the inbox chip the card shows (a job index or an offer chip id)
    var offerBonus = 0             // the shown job is a side offer: its bonus
    var offerDone = false          // ... already paid
    var upgrades = Upgrades()
    var shopSelection = 0
    var shopNote = ""
    // identity
    var callsign = Player.defaultCallsign
    var playerTitle = "ROOKIE"
    var liveryName = "CYAN"
    var liveryColor = SIMD3<Float>(0.12, 0.72, 1.0)
    /// The job's total distance (for the comms triggers).
    var distanceTotal: Float = 0
    // story lines and the rival card
    var reactiveLine = ""          // the contact's reaction to this run (success and failed cards)
    var rivalWins = 0
    var rivalLosses = 0
    var rivalTaunt = ""
    var rivalColor = SIMD3<Float>(1, 0.5, 0.2)
    var contactRole = ""
    var introLeft: Float = 0       // rival intro card countdown
    // the message log (title, pause and briefing)
    var messageCount = 0
    var unreadMessages = 0
    var latestSender = ""
    // the chapter card
    var chapterIntro = ""
    var chapterCast: [(name: String, standing: Mission.Standing)] = []
    var finished = false          // the arc is done (the ending's title and roster)

    static func == (a: MissionState, b: MissionState) -> Bool {
        a.phase == b.phase && a.code == b.code && a.contact == b.contact && a.brief == b.brief && a.debrief == b.debrief
        && a.timeLeft == b.timeLeft && a.distanceLeft == b.distanceLeft && a.energy == b.energy && a.payout == b.payout
        && a.credits == b.credits && a.failReason == b.failReason && a.index == b.index && a.beaconsHit == b.beaconsHit
        && a.gap == b.gap && a.duelWins == b.duelWins && a.duelLosses == b.duelLosses && a.kills == b.kills && a.score == b.score
        && a.streak == b.streak && a.rank == b.rank && a.respawnsLeft == b.respawnsLeft && a.helmetArmed == b.helmetArmed
        && a.flags == b.flags && a.newFlags == b.newFlags && a.cleared == b.cleared && a.browsing == b.browsing && a.jobs == b.jobs
        && a.upgrades == b.upgrades && a.shopSelection == b.shopSelection && a.shopNote == b.shopNote && a.callsign == b.callsign
        && a.playerTitle == b.playerTitle && a.liveryName == b.liveryName && a.reactiveLine == b.reactiveLine
        && a.rivalWins == b.rivalWins && a.rivalLosses == b.rivalLosses && a.rivalTaunt == b.rivalTaunt && a.introLeft == b.introLeft
        && a.messageCount == b.messageCount && a.unreadMessages == b.unreadMessages && a.chapter == b.chapter && a.finished == b.finished
        && a.shownChip == b.shownChip && a.offerBonus == b.offerBonus && a.offerDone == b.offerDone
    }
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
    /// The side offer loaded on the job (`current` is the job under its rule), and the one the inbox shows.
    private(set) var activeOffer: Int? = nil
    private(set) var previewOffer: Int? = nil
    /// The split taken on this run (-1 tunnel, +1 skyway, 0 none yet), from the world.
    private(set) var branchTaken = 0
    static let offerChipBase = 100
    private(set) var phase: MissionState.Phase = .briefing
    private(set) var credits: Int
    private(set) var upgrades: Upgrades
    private(set) var player: Player
    private(set) var shopSelection = 0
    private var shopNote = ""
    /// The story channel: briefs, debriefs, notices and the unseen sender's lines.
    private(set) var log: MessageLog
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
    private var reactiveLine = ""
    private var introLeft: Float = 0
    /// The last cause of the player's derez in a duel (from the arena), for the debrief.
    var lastDerezCause = ""
    private var hitsTaken = 0
    private var newFlags: Mission.Flags = []
    private var helmetArmed = false
    private(set) var helmetUsedNow = false
    /// Boost hysteresis: an empty bar disarms boost until it has recovered a little, so holding
    /// the trigger on an empty hull does not flicker the boost on and off every few frames.
    private var boostArmed = true
    /// Set on the frame a gate or beacon scores (HUD stamp), cleared next update.
    private(set) var scoredNow: (value: Int, streak: Int, time: Float)? = nil
    private let defaults: UserDefaults
    static let scrapeDrain: Float = 0.08      // per second against a barrier
    static let recharge: Float = 0.035        // per second when not boosting or scraping
    static let beaconCharge: Float = 0.2
    static let killCharge: Float = 0.05
    /// Escape: the pursuer cruises a little faster than the player; boost outruns it but burns hull.
    static let pursuerSpeed: Float = 47

    /// `defaults` is where progress lives; the headless tests pass their own suite.
    init(missions: [Mission] = Mission.deliveries, defaults: UserDefaults = .standard) {
        self.missions = missions
        self.defaults = defaults
        let env = ProcessInfo.processInfo.environment
        if env["SPEEDER_RESET_PROGRESS"] == "1" { Self.clearStoredProgress(defaults, missions: missions) }
        credits = defaults.integer(forKey: "credits")
        upgrades = Upgrades.load(defaults)
        player = Player.load(defaults)
        log = MessageLog(defaults)
        index = abs(defaults.integer(forKey: "missionIndex")) % max(1, missions.count)
        var forced: Int? = nil
        if let m = env["SPEEDER_MISSION"], let i = Int(m) { index = abs(i) % max(1, missions.count); forced = index }
        previewIndex = index
        // a forced job counts as reached: everything before it is cleared, the inbox lists the chain
        if let f = forced, !isUnlocked(f) { clearedMask |= (1 << f) - 1 }
        if env["SPEEDER_CHAPTER_CARDS"] == "0" { for c in 1...3 { defaults.set(true, forKey: "chapter.seen.\(c)") } }
        // captures: SPEEDER_FLAGS=2:1,9:2 sets a job's flags (1 clean, 2 fast, 4 gold), which puts its side offer on the table
        if let f = env["SPEEDER_FLAGS"] {
            for pair in f.split(separator: ",") {
                let kv = pair.split(separator: ":")
                if kv.count == 2, let j = Int(kv[0]), let v = Int(kv[1]), missions.indices.contains(j) { defaults.set(v, forKey: "flags.\(j)") }
            }
        }
        if needsChapterCard(index) { phase = .chapter }
    }

    /// Jobs, credits, the garage, ranks, flags, head-to-head records and the said-line sets. The callsign
    /// and livery are identity, not progress: they stay.
    private static func clearStoredProgress(_ defaults: UserDefaults, missions: [Mission]) {
        for k in ["credits", "missionIndex", "cleared", clearedMaskKey, Upgrades.key] { defaults.removeObject(forKey: k) }
        for m in missions { defaults.removeObject(forKey: "rank.\(m.id)"); defaults.removeObject(forKey: "flags.\(m.id)") }
        for k in defaults.dictionaryRepresentation().keys where k.hasPrefix("record.") || k.hasPrefix("said.") || k.hasPrefix("chapter.seen.") || k.hasPrefix("offer.") { defaults.removeObject(forKey: k) }
        defaults.removeObject(forKey: MessageLog.key); defaults.removeObject(forKey: MessageLog.readKey)
    }

    /// The settings screen's RESET PROGRESS: back to the first job's briefing with an empty purse.
    func resetProgress() {
        Self.clearStoredProgress(defaults, missions: missions)
        credits = 0
        upgrades = Upgrades.load(defaults)
        log.clear()
        index = 0; previewIndex = 0; activeOffer = nil; previewOffer = nil
        phase = needsChapterCard(0) ? .chapter : .briefing
        shopSelection = 0; shopNote = ""; autoStart = false
    }

    /// Quit to the title: a live, failed or intro'd job goes back to its briefing; a success banks and
    /// briefs the next job (as its NEXT JOB press would).
    func abandon() {
        switch phase {
        case .success: _ = accept()
        case .running, .rivalIntro, .failed: phase = .briefing
        default: break
        }
        if phase == .briefing && needsChapterCard(index) { phase = .chapter }
        previewIndex = index; previewOffer = activeOffer
        autoStart = false
        shopNote = ""
    }

    /// No callsign was ever confirmed on this device: the title's START asks who is riding first.
    var isFirstRun: Bool { defaults.object(forKey: "callsign") == nil }
    /// Anything to continue from (a cleared job, credits, or a later job chosen).
    var hasProgress: Bool { clearedCount > 0 || credits > 0 || index > 0 }

    /// The loaded job, under its side offer's rule when one is loaded.
    var current: Mission { activeOffer.flatMap { Mission.offer($0) }.map { missions[index].applying($0) } ?? missions[index] }
    var preview: Mission { previewOffer.flatMap { Mission.offer($0) }.map { missions[previewIndex].applying($0) } ?? missions[previewIndex] }
    var isRunning: Bool { phase == .running }
    /// The arc is done: every job cleared at least once.
    var finished: Bool { clearedCount >= missions.count }
    /// The briefing or the chapter card is up (the inbox and the garage take input on the briefing only).
    var isParked: Bool { phase == .briefing || phase == .chapter }
    /// The vehicle only moves while the job is live.
    var allowsMotion: Bool { phase == .running }

    // MARK: - Chapter cards and the message log

    /// The first job of a chapter shows the chapter card once (the paragraph, the cast's standing).
    private func needsChapterCard(_ i: Int) -> Bool {
        guard missions.indices.contains(i) else { return false }
        let m = missions[i]
        let first = !missions.contains { $0.chapter == m.chapter && $0.id < m.id }
        return first && !defaults.bool(forKey: "chapter.seen.\(m.chapter)")
    }
    /// Leaving the chapter card: remember it, post the chapter to the log with the unseen sender's line.
    private func openChapter() {
        let m = current
        defaults.set(true, forKey: "chapter.seen.\(m.chapter)")
        log.post("CHAPTER \(m.chapter)", .chapter, chapter: m.chapter, "\(Mission.chapterTitle(m.chapter)). \(Mission.chapterIntro(m.chapter))")
        log.post(Message.unknownSender, .static, chapter: m.chapter, Mission.staticLine(m.chapter))
    }
    /// The log is open: everything in it counts as read.
    func markMessagesRead() { log.markRead() }
    var messages: [Message] { log.messages }

    // MARK: - Progress

    /// Cleared jobs are a bitmask (`cleared.mask`); `cleared` keeps the count for the readers that only
    /// need one (the free-play roster, the titles, the debrief picker). Two jobs can be open at once
    /// (assessment 5.5), so a count alone no longer says which. A pre-5.5 save (count only) migrates.
    static let clearedMaskKey = "cleared.mask"
    private var clearedMask: Int {
        get {
            let m = defaults.integer(forKey: Self.clearedMaskKey)
            let count = defaults.integer(forKey: "cleared")
            return m == 0 && count > 0 ? (1 << count) - 1 : m
        }
        set {
            defaults.set(newValue, forKey: Self.clearedMaskKey)
            defaults.set(newValue.nonzeroBitCount, forKey: "cleared")
        }
    }
    private var clearedCount: Int { clearedMask.nonzeroBitCount }
    func isCleared(_ i: Int) -> Bool { clearedMask & (1 << i) != 0 }
    private func markCleared(_ i: Int) { clearedMask |= 1 << i }
    /// A chapter opens when the one before it is fully cleared. Inside a chapter the first job opens the
    /// next two at once, each job after that needs one more cleared, and a duel waits for every job
    /// before it (the inbox has a choice in it; the duel stays the chapter's gate).
    func isUnlocked(_ i: Int) -> Bool {
        guard missions.indices.contains(i) else { return false }
        let m = missions[i]
        guard missions.allSatisfy({ $0.chapter >= m.chapter || isCleared($0.id) }) else { return false }
        let before = missions.filter { $0.chapter == m.chapter && $0.id < m.id }
        if m.kind == .duel { return before.allSatisfy { isCleared($0.id) } }
        let position = before.count
        if position == 0 { return true }
        let clearedBefore = before.filter { $0.kind != .duel && isCleared($0.id) }.count
        return clearedBefore >= max(1, position - 1)
    }
    var unlockedJobs: [Int] { missions.indices.filter { isUnlocked($0) } }
    /// After a success: the next open, uncleared job in order, else the first such job, else the first
    /// job (the arc is done: ride it again).
    private func nextJob(after i: Int) -> Int {
        let open = missions.indices.filter { isUnlocked($0) && !isCleared($0) }
        return open.first { $0 > i } ?? open.first ?? 0
    }

    // MARK: - Side offers

    /// An offer is on the table once its flag is earned on the base job; it stays listed when paid.
    func isOfferShown(_ o: SideOffer) -> Bool { flags(for: missions[o.requires.job]).contains(o.requires.flag) }
    func isOfferDone(_ id: Int) -> Bool { defaults.bool(forKey: "offer.\(id).done") }
    var offersShown: [SideOffer] { Mission.offers.filter { isOfferShown($0) } }

    /// What the inbox lists, in order: every unlocked job, then the side offers on the table.
    enum Chip: Equatable { case job(Int), offer(Int) }
    var chips: [Chip] { unlockedJobs.map { .job($0) } + offersShown.map { .offer($0.id) } }
    private var shownChip: Chip { previewOffer.map { .offer($0) } ?? .job(previewIndex) }
    private func show(_ c: Chip) {
        switch c {
        case .job(let i): previewIndex = i; previewOffer = nil
        case .offer(let o): previewOffer = o; previewIndex = Mission.offer(o)?.job ?? previewIndex
        }
        shopNote = ""
    }

    /// Inbox: move the briefing to the previous / next chip (wraps).
    func browse(_ delta: Int) {
        guard phase == .briefing else { return }
        let list = chips
        guard !list.isEmpty else { return }
        let i = list.firstIndex(of: shownChip) ?? 0
        let n = list.count
        show(list[((i + delta) % n + n) % n])
    }
    /// Inbox: a tap on a chip (a job index, or `offerChipBase` + the offer id).
    func browse(to id: Int) {
        guard phase == .briefing else { return }
        if id >= Self.offerChipBase {
            if let o = Mission.offer(id - Self.offerChipBase), isOfferShown(o) { show(.offer(o.id)) }
        } else if isUnlocked(id) { show(.job(id)) }
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
        log.post("GARAGE", .notice, chapter: current.chapter, "\(item.title) \(item.level + 1 > 1 ? "II" : "I") fitted: \(item.detail). \(credits) credits left.")
        return true
    }

    /// Accept the briefing, or continue past a result. Returns true when the world must be
    /// rebuilt for a new (or retried) mission.
    func accept() -> Bool {
        switch phase {
        case .chapter:
            openChapter()
            phase = .briefing
            return false
        case .briefing:
            if previewIndex != index || previewOffer != activeOffer {
                // the inbox chose another job (or an offer on it): load it (the world rebuilds), then brief it
                index = previewIndex
                activeOffer = previewOffer
                defaults.set(index, forKey: "missionIndex")
                shopNote = ""
                return true
            }
            if current.kind == .duel { phase = .rivalIntro; introLeft = Self.introDuration; return false }
            startRun()
            return false
        case .rivalIntro:
            // A again skips the card
            startRun()
            return false
        case .success:
            activeOffer = nil
            index = nextJob(after: index)
            previewIndex = index; previewOffer = nil
            defaults.set(index, forKey: "missionIndex")
            phase = needsChapterCard(index) ? .chapter : .briefing
            return true
        case .failed:
            phase = .briefing
            previewIndex = index; previewOffer = activeOffer
            autoStart = true
            return true
        case .running, .freePlay:
            return false
        }
    }

    // MARK: - Identity

    func setCallsign(_ raw: String) {
        player.callsign = Player.sanitise(raw)
        player.save(defaults)
    }
    func cycleLivery() { setLivery(player.livery + 1) }
    func setLivery(_ i: Int) {
        let n = Player.liveries.count
        player.livery = ((i % n) + n) % n
        player.save(defaults)
    }
    var golds: Int { missions.filter { bestRank(for: $0) == .gold }.count }
    var playerTitle: String { Player.title(golds: golds, cleared: clearedCount, finished: finished) }

    static let introDuration: Float = 3.6

    private func startRun() {
        phase = .running
        elapsed = 0; travelled = 0; energy = 1; payout = 0
        beaconsHit = 0; killsTaken = 0; gap = current.startGap; duelWins = 0; duelLosses = 0
        score = 0; streak = 1; nextGate = Mission.gateSpacing; rank = .none; scoredNow = nil
        respawnsLeft = upgrades.respawns; respawnedNow = false
        hitsTaken = 0; newFlags = []; boostArmed = true
        helmetArmed = upgrades.helmet > 0; helmetUsedNow = false
        reactiveLine = ""; lastDerezCause = ""; introLeft = 0; failReason = ""; branchTaken = 0
        if !isCleared(index) { log.post(current.contact, .brief, code: current.code, chapter: current.chapter, current.brief) }
    }

    /// The rival intro card counts down, then the duel starts.
    func tickIntro(dt: Float) {
        guard phase == .rivalIntro else { return }
        introLeft -= dt
        if introLeft <= 0 { startRun() }
    }

    // MARK: - Records (head to head)

    func record(for rival: String) -> (wins: Int, losses: Int) {
        (defaults.integer(forKey: "record.\(rival).w"), defaults.integer(forKey: "record.\(rival).l"))
    }
    func recordMatch(rival: String, won: Bool) {
        let k = won ? "record.\(rival).w" : "record.\(rival).l"
        defaults.set(defaults.integer(forKey: k) + 1, forKey: k)
    }

    /// Flags earned per job, remembered across launches.
    func flags(for m: Mission) -> Mission.Flags { Mission.Flags(rawValue: defaults.integer(forKey: "flags.\(m.id)")) }

    /// Tests and captures: give a job its flags (which can put a side offer on the table).
    func testSetFlags(_ f: Mission.Flags, for job: Int) { defaults.set(f.rawValue, forKey: "flags.\(job)") }
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
    func update(dt: Float, travel: Float, speed: Float, newHits: Int, boosting: Bool, scraping: Bool = false, newKills: Int = 0, beaconsHitNow: Int = 0, branch: Int = 0) {
        guard phase == .running else { return }
        let m = current
        if branch != 0 { branchTaken = branch }
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
            if m.offer?.modifier == .tunnelBranch && branchTaken >= 0 { fail("TOOK THE SKYWAY"); return }
            // the purse (27 Sep 2026, headless loop): base pay carries it; the bonuses are a third of it at
            // best, and the streak score pays a twentieth (a fifth made the garage free by chapter 1)
            let timeBonus = Int(max(0, m.timeLimit - elapsed)) * 3
            let hullBonus = Int(energy * 100) * 2
            var bonus = 0
            switch m.kind {
            case .search: bonus = beaconsHit * 40
            case .escape: bonus = Int(gap) * 2
            case .salvage: bonus = killsTaken * 30
            case .dive: bonus = hullBonus          // precision pays twice
            default: break
            }
            succeed(m.basePay + timeBonus + hullBonus + bonus + score / 20)
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
        let offer = current.offer
        let bonus = offer.map { isOfferDone($0.id) ? 0 : $0.bonus } ?? 0
        payout = (replay ? pay / 2 : pay) + bonus
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
        let openBefore = Set(unlockedJobs), wasFinished = finished
        if !replay { markCleared(index) }
        if let offer { defaults.set(true, forKey: "offer.\(offer.id).done") }
        // the payout is banked with the job, so a relaunch on the result card cannot replay it
        defaults.set(nextJob(after: index), forKey: "missionIndex")
        if current.kind == .duel, let r = current.rival { recordMatch(rival: r.name, won: true) }
        reactiveLine = Debrief.reactive(contact: current.contact, outcome: outcome(), defaults: defaults)
        phase = .success
        // the story channel: the debrief (once), the reaction, the unlocks, the offers, the ending
        if !replay || bonus > 0 {
            let d = current.debrief
            let sender = d.split(separator: ":").first.map(String.init) ?? current.contact
            let body = d.contains(":") ? String(d.drop { $0 != ":" }.dropFirst()).trimmingCharacters(in: .whitespaces) : d
            log.post(sender, .debrief, code: current.code, chapter: current.chapter, body)
        }
        for i in unlockedJobs where !openBefore.contains(i) {
            let n = missions[i]
            log.post("INBOX", .notice, code: n.code, chapter: n.chapter, "New job from \(n.contact): \(n.code) // \(n.title) (\(n.kindText.lowercased())).")
        }
        for o in Mission.offers where o.requires.job == current.id && newFlags.contains(o.requires.flag) {
            log.post(o.sender, .brief, code: o.code, chapter: current.chapter, "\(o.line) (+\(o.bonus) credits.)")
        }
        if finished && !wasFinished {
            log.post(Message.routeSender, .static, chapter: current.chapter, Mission.staticLine(4))
            log.post("KADE", .debrief, code: current.code, chapter: current.chapter, String(Mission.endingLine.dropFirst(6)))
        }
        log.post(current.contact, .notice, code: current.code, chapter: current.chapter, "\(current.code): \(reactiveLine)")
    }

    private func outcome() -> Debrief.Outcome {
        var o = Debrief.Outcome(kind: current.kind)
        o.hits = hitsTaken
        o.respawnsUsed = max(0, upgrades.respawns - respawnsLeft)
        o.hullLeft = energy
        o.rank = rank
        o.newBest = rank > .none && rank >= bestRank(for: current)
        o.fast = current.timeLimit > 0 && current.timeLimit - elapsed >= current.timeLimit / 3
        o.timeLeftFraction = current.timeLimit > 0 ? (current.timeLimit - elapsed) / current.timeLimit : 0
        o.derezCause = lastDerezCause
        o.duelScore = (duelWins, duelLosses)
        o.branch = branchTaken
        return o
    }

    private func fail(_ reason: String) {
        failReason = reason
        if current.kind == .duel, let r = current.rival { recordMatch(rival: r.name, won: false) }
        reactiveLine = Debrief.failure(contact: current.contact, reason: reason)
        phase = .failed
    }

    func snapshot() -> MissionState {
        let shown = phase == .briefing ? preview : current
        let m = shown
        let jobs: [JobEntry] = phase == .briefing ? chips.map { c in
            switch c {
            case .job(let i):
                let j = missions[i]
                return JobEntry(id: j.id, code: j.code, title: j.title, kindText: j.kindText, contact: j.contact, chapter: j.chapter,
                                cleared: isCleared(i), rank: bestRank(for: j))
            case .offer(let id):
                let o = Mission.offer(id)!
                return JobEntry(id: Self.offerChipBase + o.id, code: o.code, title: o.title, kindText: "SIDE OFFER", contact: o.sender,
                                chapter: missions[o.job].chapter, cleared: isOfferDone(o.id), rank: .none, offer: true, bonus: o.bonus)
            }
        } : []
        return MissionState(phase: phase, code: m.code, title: m.title, contact: m.contact, brief: m.brief, debrief: m.debrief,
                            chapter: m.chapter, chapterTitle: Mission.chapterTitle(m.chapter),
                            distanceText: m.distanceText, timeText: m.timeText,
                            timeLeft: max(0, m.timeLimit - elapsed), distanceLeft: max(0, m.distance - travelled),
                            energy: energy, payout: payout, credits: credits, failReason: failReason,
                            index: previewIndex, count: missions.count, kind: m.kind, goalText: m.goalLine, successTitle: m.successTitle,
                            beaconsHit: beaconsHit, beaconsTotal: m.beacons, beaconsRequired: m.beaconsRequired,
                            gap: gap, startGap: m.startGap, duelWins: duelWins, duelLosses: duelLosses, duelTarget: m.duelTarget,
                            rivalName: m.rival?.name ?? "", rivalTemper: m.rival?.temper.rawValue ?? "", rivalLine: m.rival?.temper.line ?? "",
                            rivalSkill: m.rival?.skill.text ?? "",
                            kills: killsTaken, killsRequired: m.killsRequired,
                            score: score, streak: streak, rank: rank, bestRank: bestRank(for: m), silverScore: m.silverScore, goldScore: m.goldScore,
                            respawnsLeft: respawnsLeft, helmetArmed: helmetArmed, flags: flags(for: m), newFlags: newFlags,
                            cleared: isCleared(previewIndex), browsing: previewIndex != index || previewOffer != activeOffer, jobs: jobs,
                            shownChip: previewOffer.map { Self.offerChipBase + $0 } ?? previewIndex,
                            offerBonus: m.offer?.bonus ?? 0, offerDone: m.offer.map { isOfferDone($0.id) } ?? false,
                            upgrades: upgrades, shopSelection: shopSelection, shopNote: shopNote,
                            callsign: player.callsign, playerTitle: playerTitle, liveryName: player.liveryName, liveryColor: player.liveryColor,
                            distanceTotal: m.distance,
                            reactiveLine: reactiveLine,
                            rivalWins: m.rival.map { record(for: $0.name).wins } ?? 0, rivalLosses: m.rival.map { record(for: $0.name).losses } ?? 0,
                            rivalTaunt: m.rival.map { Debrief.taunt(rival: $0.name, record: record(for: $0.name)) } ?? "",
                            rivalColor: m.rival?.color ?? SIMD3<Float>(1, 0.5, 0.2),
                            contactRole: Debrief.role(m.contact), introLeft: introLeft,
                            messageCount: log.count, unreadMessages: log.unread, latestSender: log.latest?.sender ?? "",
                            chapterIntro: Mission.chapterIntro(m.chapter), chapterCast: Mission.chapterCast(m.chapter), finished: finished)
    }
}
