import Foundation
import simd

/// One opponent brain: every tick it measures how far each candidate heading stays
/// open (walls, trails, boundary) through the spatial hash and commits to the best one.
/// The rival's temper adds a goal on top of survival: the boxer steers for the point
/// ahead of the player, the runner for open ground and the next boost pad, the hunter
/// for the player's tail and a grind along the player's trail.
final class ArenaAI {
    private var tick: Float = 0
    private var targetHeading: Float
    private var pendingSnap: Int = 0          // -1 left, +1 right, 0 none
    private var rng = SeededRNG(seed: 4242)
    let cycleID: Int
    var temper: Rival.Temper = .hunter
    /// Reaction tier: tick length, probe range, noise and blink chance (never speed).
    var skill: Rival.Skill = .sharp
    /// Loop guard (Armagetron LOOPLEVEL, GLtron's spiral counter): the last turn direction and how
    /// many turns in a row went that way.
    private var lastTurn = 0
    private var sameTurns = 0
    /// Occupancy grid cell: about one tick of travel at base speed.
    static let gridCell: Float = 6
    /// Boost pads the runner chains (same-level pads only, filtered per tick).
    var pads: [SIMD3<Float>] = []
    /// Ramps (bottom point, top point) the hunter takes when the player is on the deck.
    var ramps: [(bottom: SIMD3<Float>, top: SIMD3<Float>)] = []
    private var rampLeg: Int = 0
    /// Sumo zone (centre, radius): outside or near the edge, the zone is the goal for every temper.
    var zone: (center: SIMD2<Float>, radius: Float)? = nil
    private(set) var goal: SIMD2<Float>? = nil
    private var wantBoost = false

    init(cycleID: Int, heading: Float) {
        self.cycleID = cycleID
        targetHeading = heading
    }

    func reset(heading: Float) { targetHeading = heading; pendingSnap = 0; tick = 0; rampLeg = 0; goal = nil; lastTurn = 0; sameTurns = 0 }

    func decide(dt: Float, cycle: LightCycle, trails: TrailSystem, player: LightCycle, snapMode: Bool) -> CycleInput {
        var input = CycleInput()
        tick -= dt
        let ahead = trails.openDistance(from: cycle.nose, dir: cycle.forward2, maxDistance: 60, yBand: cycle.yBand, ignoreOwner: cycle.id)
        let urgent = ahead < 14 + cycle.speed * 0.25
        if tick <= 0 || urgent {
            tick = urgent ? skill.urgentTick : skill.tick
            // a steady rival blinks now and then: it keeps its heading for one more tick (readable mistakes)
            if urgent || rng.float() >= skill.blink {
                choose(cycle: cycle, trails: trails, player: player, snapMode: snapMode, ahead: ahead)
            }
        }
        if snapMode {
            if pendingSnap < 0 { input.snapLeft = true }
            if pendingSnap > 0 { input.snapRight = true }
            if cycle.snapCooldown <= 0 { pendingSnap = 0 }
        } else {
            var dh = targetHeading - cycle.heading
            while dh > .pi { dh -= 2 * .pi }
            while dh < -.pi { dh += 2 * .pi }
            // heading decreases with positive steer, so steer right (positive) when dh is negative
            input.steer = max(-1, min(1, -dh * 3))
        }
        // boost only on clear ground: a long straight ahead and nothing close on either side
        input.boost = wantBoost && ahead > 40 && trails.nearest(to: cycle.xz, radius: 10, yBand: cycle.yBand, ignoreOwner: cycle.id, ignoreNewest: 8) == nil
        return input
    }

    /// Where this temper wants to be right now (xz), or nil for pure survival.
    private func goalPoint(cycle: LightCycle, player: LightCycle) -> SIMD2<Float>? {
        let toPlayer = player.xz - cycle.xz
        let dist = simd_length(toPlayer)
        switch temper {
        case .boxer:
            // ahead of the player: cross its line where it will be when we get there (our travel time
            // times its speed) plus a margin. Beside or behind: run a lane 18 m to the side and gain,
            // so the cut comes from in front, never through the trail the player is laying now.
            let rel = cycle.xz - player.xz
            let aheadBy = simd_dot(rel, player.forward2)
            if aheadBy > 15 {
                let eta = dist / max(12, cycle.speed)
                let lead = min(70, 12 + player.speed * eta)
                return player.xz + player.forward2 * lead
            }
            let sideSign: Float = simd_dot(rel, player.right2) >= 0 ? 1 : -1
            return player.xz + player.forward2 * 30 + player.right2 * sideSign * 18
        case .runner:
            // the nearest same-level boost pad that is not behind us; otherwise the far open side
            let level = pads.filter { abs($0.y - cycle.position.y) < 1.5 }.map { SIMD2<Float>($0.x, $0.z) }
            let candidates = level.filter { simd_dot(simd_normalize($0 - cycle.xz), cycle.forward2) > -0.2 && simd_length($0 - cycle.xz) > 6 }
            if let best = candidates.min(by: { simd_length($0 - cycle.xz) < simd_length($1 - cycle.xz) }) { return best }
            return cycle.xz - simd_normalize(toPlayer) * 60
        case .hunter:
            // the player is on the deck and we are not: take the nearest ramp, bottom then top
            if player.position.y > 5, cycle.position.y < 5, !ramps.isEmpty {
                let r = ramps.min(by: { simd_length(SIMD2($0.bottom.x, $0.bottom.z) - cycle.xz) < simd_length(SIMD2($1.bottom.x, $1.bottom.z) - cycle.xz) })!
                let bottom = SIMD2<Float>(r.bottom.x, r.bottom.z), top = SIMD2<Float>(r.top.x, r.top.z)
                if rampLeg == 0 && simd_length(bottom - cycle.xz) < 7 { rampLeg = 1 }
                return rampLeg == 0 ? bottom : top
            }
            rampLeg = 0
            // shadow: a point behind the player's tail, so we end up riding its trail
            return player.xz - player.forward2 * 14
        }
    }

    /// Distance along a ray (xz) to a segment, or nil when it misses.
    private static func rayHitsSegment(origin: SIMD2<Float>, dir: SIMD2<Float>, a: SIMD2<Float>, b: SIMD2<Float>) -> Float? {
        let e = b - a
        let denom = dir.x * e.y - dir.y * e.x
        guard abs(denom) > 1e-6 else { return nil }
        let ao = a - origin
        let t = (ao.x * e.y - ao.y * e.x) / denom
        let u = (ao.x * dir.y - ao.y * dir.x) / denom
        return (t >= 0 && u >= 0 && u <= 1) ? t : nil
    }

    private func choose(cycle: LightCycle, trails: TrailSystem, player: LightCycle, snapMode: Bool, ahead: Float) {
        let options: [Float] = snapMode ? [0, .pi / 2, -.pi / 2] : [0, 0.5, -0.5, .pi / 2, -.pi / 2, 1.2, -1.2]
        var best: Float = 0
        var bestScore: Float = -1
        let toPlayer = player.xz - cycle.xz
        let dist = simd_length(toPlayer)
        goal = goalPoint(cycle: cycle, player: player)
        var goalWeight: Float
        switch temper {
        case .boxer: goalWeight = 9
        case .runner: goalWeight = 8
        case .hunter: goalWeight = dist > 30 ? 10 : 6
        }
        if let zone, simd_length(cycle.xz - zone.center) > zone.radius - 12 {
            goal = zone.center
            goalWeight = 14
        }
        let toGoal = goal.map { $0 - cycle.xz }
        var bestOpen: Float = 0
        // space sense (a1k0n's flood fill, Armagetron's SPACELEVEL): how many cells can be reached
        // from one tick ahead on each heading; a pocket is rejected outright
        let grid = trails.occupancy(cell: Self.gridCell, yBand: cycle.yBand)
        let areaCap = 90
        var areas: [Float] = []
        for opt in options {
            let h = cycle.heading + opt
            let dir = SIMD2<Float>(-sin(h), -cos(h))
            areas.append(Float(grid.reachable(from: cycle.nose + dir * (Self.gridCell * 1.2), limit: areaCap)))
        }
        for (k, opt) in options.enumerated() {
            let h = cycle.heading + opt
            let dir = SIMD2<Float>(-sin(h), -cos(h))
            // look from slightly ahead of the nose so a turn does not clip the wall we are next to
            let origin = cycle.nose + dir * 1.5
            var open = trails.openDistance(from: origin, dir: dir, maxDistance: skill.range, yBand: cycle.yBand, ignoreOwner: cycle.id, ignoreNewest: 6)
            // the player's next second of trail counts as a wall already: probes run 0.16 s ahead of the
            // world, and a cut that arrives late meets the trail head
            if abs(player.position.y - cycle.position.y) < 2, let t = Self.rayHitsSegment(origin: origin, dir: dir, a: player.nose, b: player.nose + player.forward2 * max(8, player.speed * 1.2)) {
                open = min(open, t)
            }
            // a second probe a little to each side keeps it out of dead-end pockets
            let side = SIMD2<Float>(-dir.y, dir.x)
            let leftOpen = trails.openDistance(from: origin + side * 1.2, dir: dir, maxDistance: 80, yBand: cycle.yBand, ignoreOwner: cycle.id, ignoreNewest: 6)
            let rightOpen = trails.openDistance(from: origin - side * 1.2, dir: dir, maxDistance: 80, yBand: cycle.yBand, ignoreOwner: cycle.id, ignoreNewest: 6)
            open = min(open, leftOpen + 6, rightOpen + 6)
            var score = open
            if opt == 0 { score += 8 }                                // prefer straight
            let area = areas[k]
            score += min(area, 60) * 0.5
            if area < 8 && area < (areas.max() ?? 0) { score -= 200 }   // a dead-end pocket, when there is anything better
            // loop guard: a fourth turn the same way is only worth it if the inside is the bigger space
            if opt != 0 {
                let sgn = opt > 0 ? 1 : -1
                if sgn == lastTurn && sameTurns >= 3 {
                    let mirror = options.firstIndex(of: -opt).map { areas[$0] } ?? 0
                    if area <= mirror { score -= 25 }
                }
            }
            // the goal only counts where the heading is open: survival first, temper second
            if let toGoal, simd_length(toGoal) > 1 { score += simd_dot(simd_normalize(toGoal), dir) * goalWeight * clamp01(open / 30) }
            switch temper {
            case .boxer:
                // never let the player get a clean straight: a little raw aggression too
                score += simd_dot(simd_normalize(toPlayer), dir) * 2 * clamp01(open / 30)
            case .runner:
                // open ground is the point: weight the longest run and keep away from the player
                score += open * 0.35 - simd_dot(simd_normalize(toPlayer), dir) * 4
            case .hunter:
                // grind bonus: a heading that runs parallel and close to the player's trail
                if let near = trails.nearest(to: origin + dir * 6, radius: 4.5, yBand: cycle.yBand, ignoreOwner: cycle.id, ignoreNewest: 6),
                   near.ref.trail == player.id, abs(simd_dot(near.dir, dir)) > 0.9, open > 20 {
                    score += 9
                }
            }
            score += rng.float(0, skill.noise)
            if score > bestScore { bestScore = score; best = opt; bestOpen = open }
        }
        if best != 0 {
            let sgn = best > 0 ? 1 : -1
            if sgn == lastTurn { sameTurns += 1 } else { lastTurn = sgn; sameTurns = 1 }
        }
        if best != 0 || ahead < 14 {
            targetHeading = cycle.heading + best
            if snapMode && best != 0 { pendingSnap = best > 0 ? -1 : 1 }
        } else {
            targetHeading = cycle.heading
        }
        // boost policy per temper
        switch temper {
        case .boxer: wantBoost = bestOpen > 55 && dist > 25 && dist < 70
        case .runner: wantBoost = bestOpen > 60
        case .hunter: wantBoost = bestOpen > 55 && dist > 40
        }
    }
}
