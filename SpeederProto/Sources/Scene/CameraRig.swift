import Foundation
import RealityKit
import simd

/// One camera rig for both games. The corridor chase and the arena spring-follow share the
/// same timing (roll and FOV damping, speed widening, boost kick, shake), so a hit, a boost or
/// a turn feels the same in Neon City and on The Grid.
@MainActor
final class CameraRig {
    let root = Entity()
    let camera = PerspectiveCamera()
    private var x: Float = 0
    private var fov: Float = 52
    let baseHeight: Float = 2.5
    let baseDistance: Float = 5.8

    // shared rig timing (see docs/polish-log.md)
    static let rollGain: Float = 0.3
    static let rollDamp: Float = 3.5
    static let fovDamp: Float = 3.0
    static let speedFov: Float = 14
    /// Boost kick: fast attack (~150 ms), slow release (~400 ms); widens the FOV and pulls the camera back.
    private var kick: Float = 0
    private var kickEnv: Float = 0

    init() {
        root.name = "CameraRoot"
        camera.camera.fieldOfViewInDegrees = fov
        camera.camera.near = 0.2
        camera.camera.far = 900
        root.addChild(camera)
        root.look(at: [0, 1.0, -10], from: [0, baseHeight, baseDistance], relativeTo: nil)
    }

    /// World position of the camera for the current frame (used to place the speed particles).
    var position: SIMD3<Float> { root.position }

    /// Punch the camera (boost onset, launch). `amount` 0...1.
    func punch(_ amount: Float) { kick = max(kick, amount) }
    /// Current kick envelope (0...1), for the post pass.
    var kickLevel: Float { kickEnv }

    private func advanceKick(dt: Float) {
        kickEnv = damp(kickEnv, kick, 14, dt)
        kick = max(0, kick - dt * 2.5)
    }

    /// Two-frequency shake, the same in both modes: a fine speed tremor plus impulse bursts.
    private func shakeOffset(time: Float, speedNorm: Float, shake: Bool, extra: Float) -> SIMD3<Float> {
        guard shake || extra > 0 else { return .zero }
        let amp = (shake ? 0.002 + speedNorm * 0.014 : 0) + extra * 0.12
        return [sin(time * 31.0) * amp, sin(time * 27.0) * amp, cos(time * 23.0) * amp * 0.5]
    }

    private var y: Float = 0
    private var roll: Float = 0

    /// `frameShift` slides the whole framing sideways (metres): the briefing uses -2.2 so the bike
    /// and the contact sit in the right two thirds, clear of the card; it eases out on launch.
    func update(dt: Float, time: Float, speederX: Float, speederY: Float, bank: Float, speedNorm: Float, shake: Bool, curveAhead: Float, extraShake: Float, inTube: Float, frameShift: Float = 0) {
        advanceKick(dt: dt)
        x = damp(x, speederX * (0.5 + 0.25 * inTube) + frameShift, 3.5, dt)
        y = damp(y, (speederY - 1.05) * (0.85 + 0.10 * inTube), 4.0, dt)
        roll = damp(roll, bank * Self.rollGain, Self.rollDamp, dt)
        let offset = shakeOffset(time: time, speedNorm: speedNorm, shake: shake, extra: extraShake)
        let back = baseDistance - speedNorm * 0.8 + kickEnv * 0.45
        let from = SIMD3<Float>(x, baseHeight + y + speedNorm * 0.25, back) + offset
        let target = SIMD3<Float>(speederX * 0.55 + curveAhead * 0.35 + (x - speederX * (0.5 + 0.25 * inTube)) * 0.9, 1.0 + y * 0.9, -7)
        let up = simd_quatf(angle: roll, axis: [0, 0, 1]).act([0, 1, 0])
        root.look(at: target, from: from, upVector: up, relativeTo: nil)
        fov = damp(fov, 52 + speedNorm * Self.speedFov + kickEnv * 9, Self.fovDamp, dt)
        camera.camera.fieldOfViewInDegrees = fov
    }

    /// Capture aid: high behind the vehicle, looking down the road, so section layout reads at a glance.
    func overviewCorridor(speederX: Float) {
        root.look(at: [speederX * 0.3, 0, -40], from: [speederX * 0.3, 34, 30], upVector: [0, 1, 0], relativeTo: nil)
        camera.camera.fieldOfViewInDegrees = 60
    }

    // MARK: - Arena (spring follow)

    private var camPos: SIMD3<Float>? = nil
    private var camTarget: SIMD3<Float>? = nil
    private var orbitAngle: Float = 0

    /// Spring-follow rig for The Grid: the camera chases a point behind and above the
    /// cycle, looks at a point ahead of it, rolls slightly with the lean and widens with
    /// speed. `orbit` replaces all of that with a slow circle around a crash site.
    func followArena(dt: Float, time: Float, position: SIMD3<Float>, forward: SIMD3<Float>, lean: Float, speedNorm: Float,
                     shake: Bool, extraShake: Float, orbit: (center: SIMD3<Float>, progress: Float)?, snap: Bool = false, overview: Bool = false,
                     ground: (SIMD2<Float>, Float) -> Float = { _, _ in 0 }, side: Bool = false) {
        advanceKick(dt: dt)
        if side {
            // capture aid: side elevation, to check heights against ramps and decks
            let from = position + [38, 9, 0]
            root.look(at: position + [0, 1, 0], from: from, upVector: [0, 1, 0], relativeTo: nil)
            camera.camera.fieldOfViewInDegrees = 50
            return
        }
        if overview {
            // capture aid: high, behind and above the cycle, so trail layout reads at a glance
            let from = position + [0, 42, 34]
            root.look(at: position + [0, 0, -6], from: from, upVector: [0, 1, 0], relativeTo: nil)
            camera.camera.fieldOfViewInDegrees = 62
            return
        }
        let offset = shakeOffset(time: time, speedNorm: speedNorm, shake: shake, extra: extraShake)
        if let orbit {
            orbitAngle += dt * 0.55
            let r: Float = 9 + orbit.progress * 6
            let from = orbit.center + SIMD3<Float>(sin(orbitAngle) * r, 3.5 + orbit.progress * 2.5, cos(orbitAngle) * r) + offset
            camPos = from
            camTarget = orbit.center + [0, 1.0, 0]
            root.look(at: camTarget!, from: from, upVector: [0, 1, 0], relativeTo: nil)
            fov = damp(fov, 46, 2.0, dt)
            camera.camera.fieldOfViewInDegrees = fov
            return
        }
        let up = SIMD3<Float>(0, 1, 0)
        let desired = position - forward * (6.4 + speedNorm * 1.6 + kickEnv * 0.45) + up * (2.7 + speedNorm * 0.35)
        let desiredTarget = position + forward * 5.0 + up * 1.0
        if camPos == nil || snap {
            // round start: begin further back and higher and let the spring zoom in
            camPos = desired - forward * 6 + up * 4; camTarget = desiredTarget; orbitAngle = 0
        }
        // critically-damped-ish springs: position lags more than the look target, so turns swing the view
        camPos = camPos! + (desired - camPos!) * min(1, dt * 7.5)
        camTarget = camTarget! + (desiredTarget - camTarget!) * min(1, dt * 12)
        // keep the camera from sinking into the deck
        camPos!.y = max(camPos!.y, ground(SIMD2<Float>(camPos!.x, camPos!.z), position.y) + 1.4)
        roll = damp(roll, lean * Self.rollGain, Self.rollDamp, dt)
        let upVec = simd_quatf(angle: roll, axis: simd_normalize(camTarget! - camPos!)).act(up)
        root.look(at: camTarget!, from: camPos! + offset, upVector: upVec, relativeTo: nil)
        fov = damp(fov, 60 + speedNorm * Self.speedFov + kickEnv * 9, Self.fovDamp, dt)
        camera.camera.fieldOfViewInDegrees = fov
    }

    func resetArena() { camPos = nil; camTarget = nil }
}
