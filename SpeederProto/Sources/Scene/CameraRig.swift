import Foundation
import RealityKit
import simd

/// Third-person chase camera with lateral inertia, speed-driven FOV and vibration.
@MainActor
final class CameraRig {
    let root = Entity()
    let camera = PerspectiveCamera()
    private var x: Float = 0
    private var fov: Float = 52
    let baseHeight: Float = 2.5
    let baseDistance: Float = 5.8

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

    private var y: Float = 0
    private var roll: Float = 0

    func update(dt: Float, time: Float, speederX: Float, speederY: Float, bank: Float, speedNorm: Float, shake: Bool, curveAhead: Float, extraShake: Float, inTube: Bool) {
        x = damp(x, speederX * (inTube ? 0.75 : 0.5), 3.5, dt)
        y = damp(y, (speederY - 1.05) * (inTube ? 0.95 : 0.85), 4.0, dt)
        roll = damp(roll, bank * 0.35, 3.0, dt)
        var offset = SIMD3<Float>(0, 0, 0)
        if shake || extraShake > 0 {
            let amp = (shake ? 0.003 + speedNorm * 0.016 : 0) + extraShake * 0.12
            offset = [sin(time * 31.0) * amp, sin(time * 27.0) * amp, 0]
        }
        let from = SIMD3<Float>(x, baseHeight + y + speedNorm * 0.25, baseDistance - speedNorm * 0.8) + offset
        let target = SIMD3<Float>(speederX * 0.55 + curveAhead * 0.35, 1.0 + y * 0.9, -7)
        let up = simd_quatf(angle: roll, axis: [0, 0, 1]).act([0, 1, 0])
        root.look(at: target, from: from, upVector: up, relativeTo: nil)
        fov = damp(fov, 52 + speedNorm * 14, 3.0, dt)
        camera.camera.fieldOfViewInDegrees = fov
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
        var offset = SIMD3<Float>(0, 0, 0)
        if shake || extraShake > 0 {
            let amp = (shake ? 0.002 + speedNorm * 0.012 : 0) + extraShake * 0.14
            offset = [sin(time * 31.0) * amp, sin(time * 27.0) * amp, cos(time * 23.0) * amp * 0.5]
        }
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
        let desired = position - forward * (6.4 + speedNorm * 1.6) + up * (2.7 + speedNorm * 0.35)
        let desiredTarget = position + forward * 5.0 + up * 1.0
        if camPos == nil || snap { camPos = desired; camTarget = desiredTarget; orbitAngle = 0 }
        // critically-damped-ish springs: position lags more than the look target, so turns swing the view
        camPos = camPos! + (desired - camPos!) * min(1, dt * 7.5)
        camTarget = camTarget! + (desiredTarget - camTarget!) * min(1, dt * 12)
        // keep the camera from sinking into the deck
        camPos!.y = max(camPos!.y, ground(SIMD2<Float>(camPos!.x, camPos!.z), position.y) + 1.4)
        roll = damp(roll, lean * 0.28, 4.0, dt)
        let upVec = simd_quatf(angle: roll, axis: simd_normalize(camTarget! - camPos!)).act(up)
        root.look(at: camTarget!, from: camPos! + offset, upVector: upVec, relativeTo: nil)
        fov = damp(fov, 60 + speedNorm * 16, 3.5, dt)
        camera.camera.fieldOfViewInDegrees = fov
    }

    func resetArena() { camPos = nil; camTarget = nil }
}
