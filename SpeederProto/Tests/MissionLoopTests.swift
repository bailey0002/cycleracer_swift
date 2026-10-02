import XCTest
@testable import SpeederProto

/// A rider for the headless loop: how fast it cruises, how often it hits something, how much it
/// boosts, how many beacons and targets it takes. The loop steps `MissionRunner` at 60 Hz with the
/// game's own speed model (`GameController.tick`: damp to the target, a hit takes 40 % of the speed
/// and 70 ms of hit-stop), so the numbers are the ones the HUD would show.
struct Rider {
    var name: String
    var cruise: Float = 45
    var hitEvery: Float = 0          // metres between hits; 0 = never
    var boostShare: Float = 0        // fraction of each 400 m block spent boosting (when allowed)
    var beaconShare: Float = 1       // fraction of the job's beacons flown through
    var killShare: Float = 1         // fraction of a salvage job's targets destroyed
    var duelWins = true
    var branch = 0                   // the split taken where the track has one: -1 tunnel, +1 skyway

    static let cruise = Rider(name: "cruise")                                        // never boosts: the window check
    static let clean = Rider(name: "clean", boostShare: 0.15)
    static let cleanBoost = Rider(name: "clean+boost", boostShare: 0.35)
    static let fewHits = Rider(name: "1-2 hits", hitEvery: 1500, boostShare: 0.2)
    static let sloppy = Rider(name: "sloppy", hitEvery: 600, boostShare: 0.1)
    static let reckless = Rider(name: "reckless", hitEvery: 300, boostShare: 0.5)
}

/// One job's outcome from the loop.
struct RunReport: CustomStringConvertible {
    var code = "", kind = ""
    var phase: MissionState.Phase = .running
    var elapsed: Float = 0, timeLeft: Float = 0, timeLimit: Float = 0
    var hits = 0, respawns = 0
    var score = 0, goldScore = 0, silverScore = 0
    var rank: Mission.Rank = .none
    var payout = 0, energy: Float = 0
    var failReason = ""
    var flags: Mission.Flags = []
    var description: String {
        String(format: "%-11@ %-8@ %-7@ %5.1fs of %3.0fs (%4.1fs left)  hits %2d  resp %d  score %5d / gold %5d  %-6@  pay %5d  hull %.2f %@",
               code, kind, phase == .success ? "OK" : "FAIL", elapsed, timeLimit, timeLeft, hits, respawns, score, goldScore, rank.text, payout, energy, failReason)
    }
}

/// Drives one job of a `MissionRunner` from its briefing to the card at a fixed 60 Hz.
enum HeadlessLoop {
    static let dt: Float = 1.0 / 60.0

    /// Returns the report; the runner is left on its success / failed card.
    @discardableResult
    static func play(_ runner: MissionRunner, as rider: Rider, maxSeconds: Float = 400) -> RunReport {
        if runner.phase == .chapter { _ = runner.accept() }
        XCTAssertEqual(runner.phase, .briefing, "play needs a briefing")
        let m = runner.current
        var report = RunReport(code: m.code, kind: m.kindText, timeLimit: m.timeLimit)
        _ = runner.accept()
        var t: Float = 0
        if m.kind == .duel {
            while runner.phase == .rivalIntro { runner.tickIntro(dt: dt); t += dt }
            XCTAssertEqual(runner.phase, .running)
            // a scripted match: a round every 12 s, the rider's way or the rival's
            var wins = 0, losses = 0
            while runner.phase == .running && t < maxSeconds {
                t += dt
                if Int(t / 12) > wins + losses { if rider.duelWins { wins += 1 } else { losses += 1 } }
                runner.updateDuel(dt: dt, wins: wins, losses: losses)
            }
        } else {
            var speed: Float = 0, travelled: Float = 0, hitStop: Float = 0
            var nextHit = rider.hitEvery > 0 ? rider.hitEvery : Float.infinity
            let beaconSpacing = m.beacons > 0 ? m.distance / Float(m.beacons + 1) : Float.infinity
            let beaconsToTake = Int((Float(m.beacons) * rider.beaconShare).rounded())
            var beaconsTaken = 0, nextBeacon = beaconSpacing
            let killSpacing = m.killsRequired > 0 ? m.distance / Float(m.killsRequired + 1) : Float.infinity
            let killsToTake = Int((Float(m.killsRequired) * rider.killShare).rounded())
            var killsTaken = 0, nextKill = killSpacing
            var hits = 0, respawns = 0
            while runner.phase == .running && t < maxSeconds {
                t += dt
                hitStop = max(0, hitStop - dt)
                let simDt = hitStop > 0 ? dt * 0.15 : dt
                let inBoostWindow = (travelled.truncatingRemainder(dividingBy: 400)) < 400 * rider.boostShare
                let boosting = inBoostWindow && runner.boostAllowed && runner.snapshot().energy > 0.3
                let target = rider.cruise * (boosting ? 1.8 : 1.0)
                speed = damp(speed, target, target > speed ? 1.6 : 2.0, simDt)
                let travel = speed * simDt
                travelled += travel
                var newHits = 0
                if travelled >= nextHit { newHits = 1; hits += 1; nextHit += rider.hitEvery; speed *= 0.6; hitStop = 0.07 }
                var beaconsNow = 0
                if travelled >= nextBeacon {
                    if beaconsTaken < beaconsToTake { beaconsNow = 1; beaconsTaken += 1 }
                    nextBeacon += beaconSpacing
                }
                var killsNow = 0
                if travelled >= nextKill {
                    if killsTaken < killsToTake { killsNow = 1; killsTaken += 1 }
                    nextKill += killSpacing
                }
                runner.update(dt: simDt, travel: travel, speed: speed, newHits: newHits, boosting: boosting, newKills: killsNow, beaconsHitNow: beaconsNow,
                              branch: travelled > m.distance * 0.5 ? rider.branch : 0)
                if runner.respawnedNow { respawns += 1 }
            }
            report.hits = hits; report.respawns = respawns
        }
        let s = runner.snapshot()
        report.phase = s.phase
        report.elapsed = t
        report.timeLeft = s.timeLeft
        report.score = s.score; report.goldScore = s.goldScore; report.silverScore = s.silverScore
        report.rank = s.rank; report.payout = s.payout; report.energy = s.energy
        report.failReason = s.failReason
        report.flags = s.newFlags
        return report
    }

    /// A fresh runner on its own defaults suite, at the first briefing (chapter card skipped).
    static func freshRunner(at index: Int = 0) -> MissionRunner {
        let suite = "speeder.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        for c in 1...3 { d.set(true, forKey: "chapter.seen.\(c)") }
        if index > 0 { d.set(index, forKey: "cleared"); d.set(index, forKey: "missionIndex") }
        return MissionRunner(defaults: d)
    }

    /// Plays the whole arc with one rider, moving on through each card. Returns one report per job.
    static func playArc(as rider: Rider) -> [RunReport] {
        let runner = freshRunner()
        var reports: [RunReport] = []
        for _ in Mission.deliveries {
            let r = play(runner, as: rider)
            reports.append(r)
            if runner.phase == .failed {
                // a failed rider never advances: retry the job with a rider that clears it
                _ = runner.accept()
                runner.autoStart = false
                play(runner, as: .cleanBoost)
            }
            XCTAssertEqual(runner.phase, .success, "\(r.code) should have cleared")
            _ = runner.accept()
        }
        return reports
    }
}

final class MissionLoopTests: XCTestCase {

    // MARK: - The classes of bug the captures used to catch

    /// Boost hysteresis: holding the trigger on an empty hull must not flicker boost on and off.
    func testBoostDoesNotFlickerAtEmptyHull() {
        let runner = HeadlessLoop.freshRunner()
        _ = runner.accept()
        XCTAssertEqual(runner.phase, .running)
        var last = runner.boostAllowed
        var edges: [Float] = []
        var t: Float = 0
        while t < 40 && runner.phase == .running {
            t += HeadlessLoop.dt
            // no travel: the timer alone runs (66 s window), the trigger is held the whole time
            runner.update(dt: HeadlessLoop.dt, travel: 0, speed: 0, newHits: 0, boosting: runner.boostAllowed)
            if runner.boostAllowed != last { edges.append(t); last = runner.boostAllowed }
        }
        XCTAssertGreaterThanOrEqual(edges.count, 2, "boost should disarm at an empty hull and re-arm later")
        for (a, b) in zip(edges, edges.dropFirst()) {
            XCTAssertGreaterThan(b - a, 1.0, "boost re-armed \(b - a) s after disarming: that is the flicker")
        }
    }

    /// One accept on the success card moves to the next job exactly once, and lands on its briefing.
    func testAcceptOnSuccessAdvancesOnce() {
        let runner = HeadlessLoop.freshRunner()
        HeadlessLoop.play(runner, as: .clean)
        XCTAssertEqual(runner.phase, .success)
        XCTAssertTrue(runner.accept(), "moving to the next job rebuilds the world")
        XCTAssertEqual(runner.index, 1)
        XCTAssertEqual(runner.phase, .briefing)
        XCTAssertTrue(runner.isCleared(0))
        XCTAssertFalse(runner.isCleared(1))
    }

    /// A gate refunds 1.5 s of the window.
    func testGateBuysTime() {
        let runner = HeadlessLoop.freshRunner()
        _ = runner.accept()
        let limit = runner.current.timeLimit
        var t: Float = 0
        while runner.snapshot().score == 0 {
            t += HeadlessLoop.dt
            runner.update(dt: HeadlessLoop.dt, travel: 45 * HeadlessLoop.dt, speed: 45, newHits: 0, boosting: false)
            XCTAssertLessThan(t, 10)
        }
        let left = runner.snapshot().timeLeft
        XCTAssertEqual(left, limit - t + Mission.gateTime, accuracy: 0.05)
        XCTAssertEqual(runner.scoredNow?.time, Mission.gateTime)
    }

    /// A cleared job replayed pays half, and says so on the card.
    func testReplayPaysHalf() {
        let runner = HeadlessLoop.freshRunner()
        let first = HeadlessLoop.play(runner, as: .clean)
        _ = runner.accept()
        runner.browse(to: 0)
        XCTAssertTrue(runner.accept(), "loading a browsed job rebuilds")
        XCTAssertTrue(runner.snapshot().cleared)
        let again = HeadlessLoop.play(runner, as: .clean)
        XCTAssertEqual(again.payout, first.payout / 2)
    }

    func testSalvageFailsOnMissedTargets() {
        let runner = HeadlessLoop.freshRunner(at: 8)
        XCTAssertEqual(runner.current.kind, .salvage)
        var rider = Rider.clean; rider.killShare = 0.5
        let r = HeadlessLoop.play(runner, as: rider)
        XCTAssertEqual(r.phase, .failed)
        XCTAssertTrue(r.failReason.hasPrefix("TARGETS MISSED"), r.failReason)
    }

    func testSweepFailsShortOfTheQuota() {
        let runner = HeadlessLoop.freshRunner(at: 1)
        var rider = Rider.clean; rider.beaconShare = 0.5
        let r = HeadlessLoop.play(runner, as: rider)
        XCTAssertEqual(r.phase, .failed)
        XCTAssertTrue(r.failReason.hasPrefix("SWEEP INCOMPLETE"), r.failReason)
    }

    /// A dive has no weapons and a hull that bruises twice as hard.
    func testDiveDoubleBruise() {
        let runner = HeadlessLoop.freshRunner(at: 10)
        XCTAssertEqual(runner.current.kind, .dive)
        XCTAssertFalse(runner.current.weaponsAllowed)
        _ = runner.accept()
        runner.update(dt: HeadlessLoop.dt, travel: 0.75, speed: 45, newHits: 1, boosting: false)
        XCTAssertEqual(runner.snapshot().energy, 1 - runner.upgrades.hitDamage * 2, accuracy: 0.01)
    }

    /// The helmet takes the first hit of a job for free and stamps it.
    func testHelmetTakesTheFirstHit() {
        let runner = HeadlessLoop.freshRunner()
        let d = UserDefaults(suiteName: "speeder.tests.helmet")!
        d.removePersistentDomain(forName: "speeder.tests.helmet")
        for c in 1...3 { d.set(true, forKey: "chapter.seen.\(c)") }
        d.set(1 << 5, forKey: Upgrades.key)     // helmet owned
        let helmeted = MissionRunner(defaults: d)
        XCTAssertEqual(helmeted.upgrades.helmet, 1)
        _ = helmeted.accept(); _ = runner.accept()
        helmeted.update(dt: HeadlessLoop.dt, travel: 0.75, speed: 45, newHits: 1, boosting: false)
        runner.update(dt: HeadlessLoop.dt, travel: 0.75, speed: 45, newHits: 1, boosting: false)
        XCTAssertTrue(helmeted.helmetUsedNow)
        XCTAssertEqual(helmeted.snapshot().energy, 1, accuracy: 0.001)
        XCTAssertEqual(runner.snapshot().energy, 1 - runner.upgrades.hitDamage, accuracy: 0.001)
        helmeted.update(dt: HeadlessLoop.dt, travel: 0.75, speed: 45, newHits: 1, boosting: false)
        XCTAssertFalse(helmeted.helmetUsedNow)
        XCTAssertEqual(helmeted.snapshot().energy, 1 - helmeted.upgrades.hitDamage, accuracy: 0.001)
    }

    /// The inbox wraps over the unlocked jobs; the garage refuses what the purse cannot pay.
    func testInboxAndGarage() {
        let runner = HeadlessLoop.freshRunner(at: 3)
        XCTAssertEqual(runner.unlockedJobs, [0, 1, 2, 3, 4], "three cleared: RELAY 03 is open beside RUN 01")
        XCTAssertEqual(runner.snapshot().jobs.count, 5)
        runner.browse(1)
        XCTAssertEqual(runner.previewIndex, 4)
        runner.browse(1)
        XCTAssertEqual(runner.previewIndex, 0, "browsing past the last chip wraps to the first")
        runner.browse(-1)
        XCTAssertEqual(runner.previewIndex, 4)
        XCTAssertFalse(runner.buySelected())
        XCTAssertTrue(runner.snapshot().shopNote.contains("NEED"))
        runner.award(10_000)
        XCTAssertTrue(runner.buySelected())
        XCTAssertEqual(runner.upgrades.hull, 1)
    }

    // MARK: - Agency (assessment 5.5): two jobs open at once, side offers, the fork acknowledged

    /// The first job of a chapter opens the next two; each further job needs one more cleared; the
    /// duel waits for all of them; the next chapter waits for the duel.
    func testUnlockOrderInsideAChapter() {
        let runner = HeadlessLoop.freshRunner()
        XCTAssertEqual(runner.unlockedJobs, [0])
        HeadlessLoop.play(runner, as: .clean); _ = runner.accept()
        XCTAssertEqual(runner.unlockedJobs, [0, 1, 2], "the first job opens the next two (cleared jobs stay listed)")
        XCTAssertEqual(runner.index, 1)
        runner.browse(to: 2); XCTAssertTrue(runner.accept())
        HeadlessLoop.play(runner, as: .clean); _ = runner.accept()
        XCTAssertEqual(runner.unlockedJobs, [0, 1, 2, 3], "RELAY 02 cleared: RUN 01 opens, RELAY 03 still waits")
        XCTAssertEqual(runner.index, 3, "the next open job after the one just done")
        HeadlessLoop.play(runner, as: .clean); _ = runner.accept()
        XCTAssertEqual(runner.unlockedJobs, [0, 1, 2, 3, 4])
        XCTAssertFalse(runner.isUnlocked(5), "the duel waits for every job before it")
        XCTAssertEqual(runner.index, 4)
        HeadlessLoop.play(runner, as: .clean); _ = runner.accept()
        XCTAssertEqual(runner.index, 1, "the only open job left is SWEEP 01")
        XCTAssertFalse(runner.isUnlocked(5))
        HeadlessLoop.play(runner, as: .clean); _ = runner.accept()
        XCTAssertTrue(runner.isUnlocked(5)); XCTAssertFalse(runner.isUnlocked(6))
        XCTAssertEqual(runner.index, 5)
        HeadlessLoop.play(runner, as: .clean); _ = runner.accept()
        XCTAssertEqual(runner.unlockedJobs, [0, 1, 2, 3, 4, 5, 6], "the duel opens chapter 2")
        XCTAssertEqual(runner.snapshot().jobs.count, 8, "seven jobs and Kade's tunnel offer (CLEAN on RELAY 02)")
    }

    /// A pre-5.5 save (a cleared count only) reads as its first n jobs cleared.
    func testClearedCountMigrates() {
        let runner = HeadlessLoop.freshRunner(at: 4)
        XCTAssertEqual((0..<4).map { runner.isCleared($0) }, [true, true, true, true])
        XCTAssertFalse(runner.isCleared(4))
        XCTAssertEqual(runner.unlockedJobs, [0, 1, 2, 3, 4])
    }

    /// CLEAN on RELAY 02 puts Kade's tunnel offer on the table; it fails on the skyway, pays its bonus on
    /// top of the half replay pay through the tunnel, once, and the debrief acknowledges the branch.
    func testSideOfferTunnelLine() {
        let runner = HeadlessLoop.freshRunner(at: 2)
        XCTAssertTrue(runner.offersShown.isEmpty)
        var rider = Rider.clean; rider.branch = 1
        let plain = HeadlessLoop.play(runner, as: rider)
        XCTAssertTrue(plain.flags.contains(.clean))
        XCTAssertTrue(runner.snapshot().reactiveLine.hasPrefix("The skyway."), runner.snapshot().reactiveLine)
        XCTAssertEqual(runner.offersShown.map(\.id), [0], "CLEAN on RELAY 02 opens SIDE 01")
        XCTAssertTrue(runner.messages.contains { $0.sender == "KADE" && $0.text.contains("tunnel") }, "the offer is posted to the log")
        _ = runner.accept()
        XCTAssertEqual(runner.snapshot().jobs.last?.id, MissionRunner.offerChipBase)
        runner.browse(to: MissionRunner.offerChipBase)
        XCTAssertEqual(runner.preview.code, "SIDE 01")
        XCTAssertEqual(runner.preview.contact, "KADE")
        XCTAssertTrue(runner.snapshot().browsing)
        XCTAssertTrue(runner.accept(), "loading the offer rebuilds")
        XCTAssertEqual(runner.current.code, "SIDE 01")
        let wrong = HeadlessLoop.play(runner, as: rider)
        XCTAssertEqual(wrong.phase, .failed); XCTAssertEqual(wrong.failReason, "TOOK THE SKYWAY")
        _ = runner.accept()                       // retry keeps the offer
        XCTAssertEqual(runner.current.code, "SIDE 01")
        rider.branch = -1
        let right = HeadlessLoop.play(runner, as: rider)
        XCTAssertEqual(right.phase, .success)
        XCTAssertEqual(right.payout, plain.payout / 2 + 150, "half the replay pay plus the bonus")
        XCTAssertTrue(runner.snapshot().reactiveLine.hasPrefix("You took the tunnel."), runner.snapshot().reactiveLine)
        XCTAssertTrue(runner.isOfferDone(0))
        _ = runner.accept()
        XCTAssertNil(runner.activeOffer)
        XCTAssertEqual(runner.index, 3, "back to the arc")
        runner.browse(to: MissionRunner.offerChipBase); _ = runner.accept()
        let again = HeadlessLoop.play(runner, as: rider)
        XCTAssertEqual(again.payout, plain.payout / 2, "the bonus pays once")
    }

    /// Sable's ledger offer wants every beacon; the window offer shortens the pipe's window.
    func testSideOfferRules() {
        let runner = HeadlessLoop.freshRunner(at: 15)
        runner.testSetFlags(.gold, for: 13)
        XCTAssertEqual(runner.offersShown.map(\.id), [2])
        runner.browse(to: MissionRunner.offerChipBase + 2); _ = runner.accept()
        XCTAssertEqual(runner.current.beaconsRequired, 10)
        var rider = Rider.clean; rider.beaconShare = 0.9
        let short = HeadlessLoop.play(runner, as: rider)
        XCTAssertEqual(short.failReason, "SWEEP INCOMPLETE 9/10")
        let pipe = HeadlessLoop.freshRunner(at: 10)
        pipe.testSetFlags(.fast, for: 9)
        pipe.browse(to: MissionRunner.offerChipBase + 1); _ = pipe.accept()
        XCTAssertEqual(pipe.current.timeLimit, Mission.deliveries[10].timeLimit - 10)
        XCTAssertTrue(pipe.current.goalLine.hasSuffix("WINDOW -10 s"))
    }

    // MARK: - Balance (the table goes into docs/polish-log.md)

    func testArcBalanceTable() {
        var garage = Upgrades(); var garageCost = garage.items.map(\.price).reduce(0, +)
        garage.hull = 1; garage.boost = 1
        garageCost += garage.items.filter { $0.key == "hull" || $0.key == "boost" }.map(\.price).reduce(0, +)
        var lines = ["", "rider        job         kind     result  time                          hits  resp  score / gold      rank    pay    hull"]
        var perChapter: [String: [Int]] = [:]
        for rider in [Rider.cruise, .clean, .cleanBoost, .fewHits, .sloppy, .reckless] {
            let reports = HeadlessLoop.playArc(as: rider)
            var chapter = [0, 0, 0]
            for (m, r) in zip(Mission.deliveries, reports) {
                lines.append(String(format: "%-12@ ", rider.name) + r.description)
                if r.phase == .success { chapter[m.chapter - 1] += r.payout }
                if m.kind != .duel {
                    if rider.name == "cruise" && m.kind != .escape {
                        XCTAssertEqual(r.phase, .success, "\(m.code): plain cruise must clear the window")
                        XCTAssertLessThan(r.timeLeft, m.timeLimit / 3, "\(m.code): the FAST flag should take some boost")
                        XCTAssertFalse(r.flags.contains(.fast), "\(m.code): FAST for free at cruise")
                    }
                    if rider.name == "clean" {
                        XCTAssertEqual(r.phase, .success, "\(m.code): a clean run must clear")
                        XCTAssertEqual(r.rank, .gold, "\(m.code): a clean run should be gold")
                    }
                    if rider.name == "sloppy" {
                        XCTAssertEqual(r.phase, .success, "\(m.code): a sloppy run still clears")
                        XCTAssertLessThan(r.rank, .gold, "\(m.code): a sloppy run should not be gold")
                    }
                }
            }
            perChapter[rider.name] = chapter
            lines.append(String(format: "%-12@ credits per chapter: %d / %d / %d  (total %d; the garage costs %d)", rider.name,
                                chapter[0], chapter[1], chapter[2], chapter.reduce(0, +), garageCost))
        }
        print(lines.joined(separator: "\n"))
    }
}
