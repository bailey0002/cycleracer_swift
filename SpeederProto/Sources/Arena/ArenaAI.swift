import Foundation
import simd

/// One opponent brain: every tick it measures how far each candidate heading stays
/// open (walls, trails, boundary) through the spatial hash and commits to the best one.
final class ArenaAI {
    private var tick: Float = 0
    private var targetHeading: Float
    private var pendingSnap: Int = 0          // -1 left, +1 right, 0 none
    private var rng = SeededRNG(seed: 4242)
    let cycleID: Int

    init(cycleID: Int, heading: Float) {
        self.cycleID = cycleID
        targetHeading = heading
    }

    func reset(heading: Float) { targetHeading = heading; pendingSnap = 0; tick = 0 }

    func decide(dt: Float, cycle: LightCycle, trails: TrailSystem, player: LightCycle, snapMode: Bool) -> CycleInput {
        var input = CycleInput()
        tick -= dt
        let ahead = trails.openDistance(from: cycle.nose, dir: cycle.forward2, maxDistance: 60, yBand: cycle.yBand, ignoreOwner: cycle.id)
        let urgent = ahead < 14 + cycle.speed * 0.25
        if tick <= 0 || urgent {
            tick = urgent ? 0.08 : 0.16
            choose(cycle: cycle, trails: trails, player: player, snapMode: snapMode, ahead: ahead)
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
        input.boost = ahead > 45 && simd_length(player.xz - cycle.xz) > 40
        return input
    }

    private func choose(cycle: LightCycle, trails: TrailSystem, player: LightCycle, snapMode: Bool, ahead: Float) {
        let options: [Float] = snapMode ? [0, .pi / 2, -.pi / 2] : [0, 0.5, -0.5, .pi / 2, -.pi / 2, 1.2, -1.2]
        var best: Float = 0
        var bestScore: Float = -1
        let toPlayer = player.xz - cycle.xz
        for opt in options {
            let h = cycle.heading + opt
            let dir = SIMD2<Float>(-sin(h), -cos(h))
            // look from slightly ahead of the nose so a turn does not clip the wall we are next to
            let origin = cycle.nose + dir * 1.5
            var open = trails.openDistance(from: origin, dir: dir, maxDistance: 80, yBand: cycle.yBand, ignoreOwner: cycle.id, ignoreNewest: 6)
            // a second probe a little to each side keeps it out of dead-end pockets
            let side = SIMD2<Float>(-dir.y, dir.x)
            open = min(open, trails.openDistance(from: origin + side * 1.2, dir: dir, maxDistance: 80, yBand: cycle.yBand, ignoreOwner: cycle.id, ignoreNewest: 6) + 6)
            open = min(open, trails.openDistance(from: origin - side * 1.2, dir: dir, maxDistance: 80, yBand: cycle.yBand, ignoreOwner: cycle.id, ignoreNewest: 6) + 6)
            var score = open
            if opt == 0 { score += 8 }                                // prefer straight
            score += simd_dot(simd_normalize(toPlayer), dir) * 6      // mild aggression: cut toward the player
            score += rng.float(0, 5)
            if score > bestScore { bestScore = score; best = opt }
        }
        if best != 0 || ahead < 14 {
            targetHeading = cycle.heading + best
            if snapMode && best != 0 { pendingSnap = best > 0 ? -1 : 1 }
        } else {
            targetHeading = cycle.heading
        }
    }
}
