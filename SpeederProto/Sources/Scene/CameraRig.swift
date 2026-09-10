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
}
