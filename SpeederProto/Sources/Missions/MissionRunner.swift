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
    private let defaults = UserDefaults.standard
    static let hitDamage: Float = 0.25

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

    /// Advance the live job. `travel` is metres moved this frame, `newHits` the collisions since last frame.
    func update(dt: Float, travel: Float, newHits: Int) {
        guard phase == .running else { return }
        elapsed += dt
        travelled += travel
        if newHits > 0 {
            cargo = max(0, cargo - Float(newHits) * Self.hitDamage)
            if cargo <= 0 { fail("CARGO CORRUPTED") ; return }
        }
        if travelled >= current.distance {
            let m = current
            let timeBonus = Int(max(0, m.timeLimit - elapsed)) * 5
            let cargoBonus = Int(cargo * 100) * 2
            payout = m.basePay + timeBonus + cargoBonus
            credits += payout
            defaults.set(credits, forKey: "credits")
            phase = .success
            return
        }
        if elapsed >= current.timeLimit { fail("TIME OUT") }
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
                            index: index, count: missions.count)
    }
}
