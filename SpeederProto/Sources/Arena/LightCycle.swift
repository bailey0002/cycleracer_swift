import Foundation
import simd

/// Per-frame commands for one cycle (from the player's input or the AI).
struct CycleInput {
    var steer: Float = 0          // -1 left ... 1 right (analog)
    var snapLeft = false          // edge-triggered 90 degree turns
    var snapRight = false
    var boost = false
    var brake = false
    var jump = false              // edge-triggered
    var action = false            // edge-triggered: use the held pickup
}

/// Kinematic light cycle: the game owns speed, heading and position outright; lean,
/// pitch and the damped visual heading are presentation only.
final class LightCycle {
    let id: Int
    var position: SIMD3<Float>          // ground contact point; y = height above the deck
    var heading: Float                  // radians about +Y, 0 = facing -Z
    var speed: Float
    var vy: Float = 0
    var airborne = false
    var alive = true
    // presentation
    private(set) var visualHeading: Float
    private(set) var lean: Float = 0
    private(set) var pitch: Float = 0
    private(set) var steer: Float = 0
    private var groundPitch: Float = 0
    // handling
    var baseSpeed: Float = 36
    var boostSpeed: Float = 60
    var brakeSpeed: Float = 15
    var turnRate: Float = 2.1            // rad/s at full analog steer
    var snapCooldown: Float = 0
    private var snapTarget: Float? = nil
    let noseOffset: Float = 2.3
    let tailOffset: Float = 2.1
    let halfWidth: Float = 0.9
    /// Height of the trail wall left behind (metres above the deck at the tail).
    let trailHeight: Float = 2.2
    let jumpVelocity: Float = 12.5
    let gravity: Float = 24

    init(id: Int, position: SIMD3<Float>, heading: Float, speed: Float) {
        self.id = id
        self.position = position
        self.heading = heading
        self.speed = speed
        self.visualHeading = heading
    }

    var forward: SIMD3<Float> { SIMD3<Float>(-sin(heading), 0, -cos(heading)) }
    var forward2: SIMD2<Float> { SIMD2<Float>(-sin(heading), -cos(heading)) }
    var right2: SIMD2<Float> { SIMD2<Float>(-forward2.y, forward2.x) }
    var xz: SIMD2<Float> { SIMD2<Float>(position.x, position.z) }
    var nose: SIMD2<Float> { xz + forward2 * noseOffset }
    var tail: SIMD3<Float> { position - forward * tailOffset }
    /// Vertical band the body occupies, for wall tests.
    var yBand: ClosedRange<Float> { (position.y + 0.15)...(position.y + 1.9) }
    var isSnapping: Bool { snapTarget != nil }

    /// Advance one step. `speedBonus` is the grinding surge. Returns true when a hard
    /// corner was made (the trail should sample immediately).
    @discardableResult
    func step(dt: Float, input: CycleInput, snapMode: Bool, speedBonus: Float, ground: (SIMD2<Float>, Float) -> Float = { _, _ in 0 }) -> Bool {
        var corner = false
        // speed: brake < cruise < boost, plus the grind surge
        let target = (input.brake ? brakeSpeed : (input.boost ? boostSpeed : baseSpeed)) + speedBonus
        let rate: Float = target > speed ? (input.boost ? 3.2 : 2.0) : 4.5
        speed = damp(speed, target, rate, dt)
        // heading
        snapCooldown = max(0, snapCooldown - dt)
        if snapMode {
            steer = damp(steer, 0, 10, dt)
            if snapCooldown <= 0 {
                if input.snapLeft { heading += .pi / 2; snapCooldown = 0.16; corner = true; steer = -1 }
                else if input.snapRight { heading -= .pi / 2; snapCooldown = 0.16; corner = true; steer = 1 }
            }
        } else {
            steer = damp(steer, max(-1, min(1, input.steer)), 9, dt)
            let rate = turnRate * (1.0 - 0.25 * clamp01((speed - baseSpeed) / (boostSpeed - baseSpeed)))
            heading -= steer * rate * dt
        }
        // jump
        if input.jump && !airborne {
            airborne = true
            vy = jumpVelocity
        }
        position += forward * speed * dt
        let g = ground(xz, position.y)
        if airborne {
            vy -= gravity * dt
            position.y += vy * dt
            if position.y <= g { position.y = g; vy = 0; airborne = false }
        } else if g < position.y - 1.0 {
            // drove off a deck edge: fall
            airborne = true
            vy = 0
        } else {
            position.y = g
        }
        // slope under the wheels drives the pitch (rise per metre along the heading)
        let slope = (ground(xz + forward2 * 2.5, position.y) - ground(xz - forward2 * 2.5, position.y)) / 5
        groundPitch = damp(groundPitch, max(-0.5, min(0.5, atan(slope))), 8, dt)
        // presentation: the visual heading chases the logical one so snap turns still show a lean
        var dh = heading - visualHeading
        while dh > .pi { dh -= 2 * .pi }
        while dh < -.pi { dh += 2 * .pi }
        visualHeading += dh * min(1, dt * 14)
        let leanTarget = snapMode ? -dh * 1.1 : -steer * 0.55
        lean = damp(lean, max(-0.7, min(0.7, leanTarget)), 8, dt)
        pitch = damp(pitch, (airborne ? vy * 0.025 : -clamp01((speed - baseSpeed) / 30) * 0.05) + groundPitch, 6, dt)
        return corner
    }

    func reset(position: SIMD3<Float>, heading: Float) {
        self.position = position
        self.heading = heading
        visualHeading = heading
        speed = 0
        vy = 0
        airborne = false
        alive = true
        lean = 0; pitch = 0; steer = 0; groundPitch = 0
        snapTarget = nil
        snapCooldown = 0
    }
}
