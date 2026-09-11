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
    var cargo: Float = 1          // 0...1 integrity
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
    var boostMeter: Float = 1
    // duel
    var duelWins = 0
    var duelLosses = 0
    var duelTarget = 0
}

/// The job loop: briefing -> running (timer, cargo, distance) -> success / failed -> next.
/// Owned by `GameController`, which feeds it distance and hits and rebuilds the world when
/// the mission changes.
final class MissionRunner {
    private(set) var missions: [Mission]
    private(set) var index: Int
    private(set) var phase: MissionState.Phase = .briefing
    private(set) var credits: Int
    private var elapsed: Float = 0
    private var travelled: Float = 0
    private var cargo: Float = 1
    private var payout = 0
    private var failReason = ""
    private var beaconsHit = 0
    private var gap: Float = 0
    private var boostMeter: Float = 1
    private var duelWins = 0
    private var duelLosses = 0
    private let defaults = UserDefaults.standard
    static let hitDamage: Float = 0.25
    /// Escape: the pursuer cruises a little faster than the player; boost outruns it but overheats.
    static let pursuerSpeed: Float = 47
    static let boostDrain: Float = 1 / 3.5
    static let boostRecharge: Float = 0.28

    init(missions: [Mission] = Mission.deliveries) {
        self.missions = missions
        let env = ProcessInfo.processInfo.environment
        if env["SPEEDER_RESET_PROGRESS"] == "1" { defaults.removeObject(forKey: "credits"); defaults.removeObject(forKey: "missionIndex") }
        credits = defaults.integer(forKey: "credits")
        index = defaults.integer(forKey: "missionIndex") % max(1, missions.count)
        if let m = env["SPEEDER_MISSION"], let i = Int(m) { index = i % max(1, missions.count) }
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
            elapsed = 0; travelled = 0; cargo = 1; payout = 0
            beaconsHit = 0; gap = current.startGap; boostMeter = 1; duelWins = 0; duelLosses = 0
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

    /// Boost is free except on an escape run, where it drains the meter.
    var boostAllowed: Bool { current.kind != .escape || boostMeter > 0.02 }

    /// Advance a live corridor job. `travel` is metres moved this frame, `speed` the vehicle speed,
    /// `newHits` collisions since last frame, `beaconsHitNow` rings flown through this frame.
    func update(dt: Float, travel: Float, speed: Float, newHits: Int, boosting: Bool, beaconsHitNow: Int = 0) {
        guard phase == .running else { return }
        let m = current
        elapsed += dt
        travelled += travel
        beaconsHit += beaconsHitNow
        switch m.kind {
        case .delivery:
            if newHits > 0 {
                cargo = max(0, cargo - Float(newHits) * Self.hitDamage)
                if cargo <= 0 { fail("CARGO CORRUPTED"); return }
            }
        case .escape:
            if boosting && boostMeter > 0 { boostMeter = max(0, boostMeter - dt * Self.boostDrain) }
            else { boostMeter = min(1, boostMeter + dt * Self.boostRecharge) }
            // the pursuer launches with you: its speed ramps up over the first seconds
            let pursuer = min(Self.pursuerSpeed, elapsed * 22)
            gap += (speed - pursuer) * dt
            if gap <= 4 { fail("CAUGHT"); return }
        default:
            break
        }
        if travelled >= m.distance {
            if m.kind == .search && beaconsHit < m.beaconsRequired { fail("SWEEP INCOMPLETE \(beaconsHit)/\(m.beaconsRequired)"); return }
            let timeBonus = Int(max(0, m.timeLimit - elapsed)) * 5
            var bonus = 0
            switch m.kind {
            case .delivery: bonus = Int(cargo * 100) * 2
            case .search: bonus = beaconsHit * 40
            case .escape: bonus = Int(gap) * 2
            case .duel: break
            }
            succeed(m.basePay + timeBonus + bonus)
            return
        }
        if elapsed >= m.timeLimit { fail("TIME OUT") }
    }

    /// Advance a live duel from the arena's score.
    func updateDuel(dt: Float, wins: Int, losses: Int) {
        guard phase == .running, current.kind == .duel else { return }
        elapsed += dt
        duelWins = wins; duelLosses = losses
        if wins >= current.duelTarget { succeed(current.basePay + max(0, wins - losses) * 100); return }
        if losses >= current.duelTarget { fail("DEREZZED \(losses) TIMES") }
    }

    private func succeed(_ pay: Int) {
        payout = pay
        credits += payout
        defaults.set(credits, forKey: "credits")
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
                            cargo: cargo, payout: payout, credits: credits, failReason: failReason,
                            index: index, count: missions.count, kind: m.kind, goalText: m.goalText, successTitle: m.successTitle,
                            beaconsHit: beaconsHit, beaconsTotal: m.beacons, beaconsRequired: m.beaconsRequired,
                            gap: gap, boostMeter: boostMeter, duelWins: duelWins, duelLosses: duelLosses, duelTarget: m.duelTarget)
    }
}
