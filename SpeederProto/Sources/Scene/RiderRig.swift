import Foundation
import RealityKit
import simd

/// The hoverboard rider: a compact port of KERB's `SkaterRig` (kerb_skate_game, 29 Sep 2026) without the
/// foot IK. A pose is a set of world-space rotation deltas per joint, expressed in the character's rest
/// frame and composed through the rest hierarchy into local joint transforms every frame. The rest pose of
/// the converted Character Creator riders is "arms hanging, knees slightly bent" (not a T-pose), so the
/// calibrated signs from KERB hold: `+F` raises the LEFT arm outward (right mirrors), `-L` swings a limb
/// forward, `-L` on a forearm bends the elbow, `+U` turns the head / spine toward the nose, `+L` on the
/// spine leans the chest forward.
///
/// Root space: the character faces +X (regular stance, chest toward board-right), the nose is -Z (the
/// character's left), the deck top is y = 0.
@MainActor
final class RiderRig {
    let root = Entity()
    let model: ModelEntity
    private let names: [String]
    private let parent: [Int]
    private let rest: [Transform]
    private let restWorldRot: [simd_quatf]
    private let index: [String: Int]
    private let hipsIndex: Int
    /// Character axes in skeleton space at rest.
    let F: SIMD3<Float>
    let L: SIMD3<Float>
    let U: SIMD3<Float>
    let height: Float
    /// Thigh + shin (metres, root space): `drop(forKnee:)` lowers the hips so bent knees keep the feet down.
    let legLength: Float

    private var current: [simd_quatf]
    private var target: [simd_quatf]
    private var hipsOffset = SIMD3<Float>.zero
    private var hipsTarget = SIMD3<Float>.zero
    private var scratch: [Transform]

    init?(entity loaded: Entity) {
        guard let m = Self.findSkinned(loaded) else { print("RiderRig: no skinned mesh found"); return nil }
        let names = m.jointNames
        let rest = m.jointTransforms
        let shortNames = names.map { String($0.split(separator: "/").last ?? "") }
        var pathIndex: [String: Int] = [:]
        for (i, n) in names.enumerated() { pathIndex[n] = i }
        var par = [Int](repeating: -1, count: names.count)
        for (i, n) in names.enumerated() {
            if let slash = n.lastIndex(of: "/") { par[i] = pathIndex[String(n[..<slash])] ?? -1 }
        }
        var shortIndex: [String: Int] = [:]
        for (i, s) in shortNames.enumerated() where shortIndex[s] == nil { shortIndex[s] = i }
        var rw = [simd_float4x4](repeating: simd_float4x4(1), count: names.count)
        for i in 0..<names.count {
            let local = rest[i].matrix
            rw[i] = par[i] >= 0 ? rw[par[i]] * local : local
        }
        func pos(_ n: String) -> SIMD3<Float>? {
            guard let i = shortIndex[n] else { return nil }
            let c = rw[i].columns.3
            return SIMD3<Float>(c.x, c.y, c.z)
        }
        // Joint transforms live in the skeleton's own frame (Blender exports Z-up skeletons under a rotated
        // SkelRoot), so the character axes come from the mesh: the wide axis of the bounds is left-right and
        // the toe direction picks forward; both are converted back into skeleton space for posing.
        let up = SIMD3<Float>(0, 1, 0)
        let bounds = m.visualBounds(relativeTo: nil)
        let ext = bounds.extents
        let fwdAxis: SIMD3<Float> = ext.x >= ext.z ? [0, 0, 1] : [1, 0, 0]
        let ankleS = pos("LeftFoot") ?? .zero, toeS = pos("LeftToeBase") ?? (ankleS + [0, 0, 1])
        let ankleM = m.convert(position: ankleS, to: loaded), toeM = m.convert(position: toeS, to: loaded)
        let facingModel = fwdAxis * (simd_dot(toeM - ankleM, fwdAxis) >= 0 ? 1 : -1)
        let leftModel = simd_normalize(simd_cross(up, facingModel))
        F = Self.safeNormalize(loaded.convert(direction: facingModel, to: m), fallback: [0, 0, 1])
        L = Self.safeNormalize(loaded.convert(direction: leftModel, to: m), fallback: [1, 0, 0])
        U = Self.safeNormalize(loaded.convert(direction: up, to: m), fallback: up)

        // stance wrapper: the character faces +X, feet on y = 0, centred
        let yaw = atan2(simd_dot(simd_cross(facingModel, [1, 0, 0]), up), simd_dot(facingModel, [1, 0, 0]))
        loaded.orientation = simd_quatf(angle: yaw, axis: up)
        loaded.position = [-bounds.center.x, -bounds.min.y, -bounds.center.z]
        root.addChild(loaded)
        root.name = "RiderRig"

        var leg: Float = 0.85
        if let hip = pos("LeftUpLeg"), let knee = pos("LeftLeg"), let ankle = pos("LeftFoot") {
            let h = m.convert(position: hip, to: loaded), k = m.convert(position: knee, to: loaded), a = m.convert(position: ankle, to: loaded)
            leg = simd_length(h - k) + simd_length(k - a)
        }

        model = m
        self.names = names
        self.rest = rest
        parent = par
        index = shortIndex
        hipsIndex = shortIndex["Hips"] ?? 0
        restWorldRot = rw.map { simd_quatf($0) }
        height = ext.y
        legLength = leg
        current = [simd_quatf](repeating: simd_quatf(angle: 0, axis: [0, 1, 0]), count: names.count)
        target = current
        scratch = rest
        print("RiderRig: \(names.count) joints, height \(height), leg \(leg), skel F \(F) L \(L) U \(U), model facing \(facingModel), yaw \(yaw * 180 / .pi)")
    }

    private static func findSkinned(_ e: Entity) -> ModelEntity? {
        if let m = e as? ModelEntity, !m.jointNames.isEmpty { return m }
        for c in e.children { if let m = findSkinned(c) { return m } }
        return nil
    }

    private static func safeNormalize(_ v: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
        let l = simd_length(v)
        return l > 1e-5 ? v / l : fallback
    }

    /// The Grid lights nothing but its own lines, so a PBR rider goes black there. Light the rider from
    /// within: the base colour texture doubles as the emissive map (the Tron suit look). 0 restores the
    /// plain materials.
    func selfLight(_ intensity: Float) {
        guard var m = model.model else { return }
        var out: [any Material] = []
        for mat in m.materials {
            guard var pbm = mat as? PhysicallyBasedMaterial else { out.append(mat); continue }
            if intensity > 0, let tex = pbm.baseColor.texture {
                pbm.emissiveColor = .init(color: .black, texture: tex)       // .black: the colour would add to the texture
                pbm.emissiveIntensity = intensity
            } else {
                pbm.emissiveColor = .init(color: .black)
                pbm.emissiveIntensity = 0
            }
            out.append(pbm)
        }
        m.materials = out
        model.model = m
    }

    // MARK: - Pose authoring

    func beginPose() {
        for i in 0..<target.count { target[i] = simd_quatf(angle: 0, axis: [0, 1, 0]) }
        hipsTarget = .zero
    }

    /// Rotate a joint by `degrees` about a character-space axis (applied in the rest world frame).
    func rotate(_ name: String, axis: SIMD3<Float>, degrees: Float) {
        guard let i = index[name], abs(degrees) > 1e-4 else { return }
        let q = simd_quatf(angle: degrees * .pi / 180, axis: simd_normalize(axis))
        target[i] = q * target[i]
    }

    /// Move the hips (skeleton space, metres).
    func offsetHips(_ v: SIMD3<Float>) { hipsTarget += v }

    /// How far the hips fall when both knees bend by `degrees`.
    func drop(forKnee degrees: Float) -> Float { legLength * (1 - cos(degrees * .pi / 180)) }

    /// Blend toward the authored pose and write the joint transforms.
    func apply(dt: Float, rate: Float = 12) {
        let t = 1 - exp(-rate * dt)
        for i in 0..<current.count { current[i] = simd_normalize(simd_slerp(current[i], target[i], t)) }
        hipsOffset += (hipsTarget - hipsOffset) * t
        for i in 0..<names.count {
            var tr = rest[i]
            let p = parent[i]
            let parentRot = p >= 0 ? restWorldRot[p] : simd_quatf(angle: 0, axis: [0, 1, 0])
            let localDelta = parentRot.inverse * current[i] * parentRot
            tr.rotation = simd_normalize(localDelta * rest[i].rotation)
            if i == hipsIndex { tr.translation = rest[i].translation + parentRot.inverse.act(hipsOffset) }
            scratch[i] = tr
        }
        model.jointTransforms = scratch
    }

    // MARK: - The riding stance

    /// Surf stance on a fast board: feet apart along the deck, knees bent (deeper at speed and on boost),
    /// chest toward board-right with the head turned down the board, arms out for balance. `bank` is the
    /// board's roll (radians, positive = left side down), `climb` the vertical speed (m/s).
    private var shootTimer: Float = 0
    /// The phaser shot: the nose-side arm snaps out down the board for a third of a second.
    func shoot() { shootTimer = 0.38 }

    func pose(bank: Float, speedNorm: Float, boost: Float, climb: Float, time: Float, dt: Float, tuck: Float = 0) {
        beginPose()
        shootTimer = max(0, shootTimer - dt)
        let aim = shootTimer > 0 ? min(1, shootTimer / 0.1) * min(1, (0.38 - shootTimer) / 0.06 + 0.2) : 0
        let crouch = min(1, 0.25 + speedNorm * 0.35 + boost * 0.45 + tuck * 0.8)
        let knee = 16 + 30 * crouch
        let sway = sin(time * 1.3) * 1.5 * (1 - speedNorm) + sin(time * 5.5) * 0.6 * speedNorm
        for side in ["Left", "Right"] {
            let sign: Float = side == "Left" ? 1 : -1
            rotate("\(side)UpLeg", axis: F, degrees: 14 * sign)             // feet apart along the deck
            rotate("\(side)UpLeg", axis: L, degrees: -knee)
            rotate("\(side)Leg", axis: L, degrees: 2 * knee)
            rotate("\(side)Foot", axis: L, degrees: -knee)
        }
        // lean into the turn: the hips slide toward the inside and the spine counters part of the roll
        let leanDeg = bank * 180 / .pi
        offsetHips(-U * drop(forKnee: knee) + F * (bank * 0.35))
        rotate("Hips", axis: U, degrees: 22)                                 // hips open a little toward the nose
        rotate("Hips", axis: L, degrees: leanDeg * 0.25)
        rotate("Spine", axis: L, degrees: 6 + 10 * crouch + sway - leanDeg * 0.3)
        rotate("Spine1", axis: L, degrees: 4 + 6 * crouch - leanDeg * 0.2)
        rotate("Spine", axis: U, degrees: 14)
        rotate("Spine1", axis: U, degrees: 10)
        // lean down the board with speed, back off it when climbing
        let dive = 8 + 14 * crouch - climb * 1.5
        rotate("Spine", axis: F, degrees: dive * 0.6)
        rotate("Spine1", axis: F, degrees: dive * 0.4)
        rotate("Neck", axis: U, degrees: 24)
        rotate("Head", axis: U, degrees: 30)
        rotate("Head", axis: F, degrees: -dive * 0.5)                        // eyes level again
        // arms: out for balance; pulled in and down to grab the deck in a trick; the nose-side (left) arm
        // straight out down the board for the shot
        var out = 12 + 26 * crouch, fwd = 8 + 12 * crouch, elbow = 22 + 20 * crouch
        out -= 30 * tuck; fwd += 30 * tuck; elbow -= 10 * tuck
        rotate("LeftArm", axis: F, degrees: (out + leanDeg * 0.4) * (1 - aim) + 88 * aim)
        rotate("RightArm", axis: F, degrees: -(out - leanDeg * 0.4))
        rotate("LeftArm", axis: L, degrees: -fwd * (1 - aim) - 6 * aim)
        rotate("RightArm", axis: L, degrees: -fwd)
        rotate("LeftForeArm", axis: L, degrees: -elbow * (1 - aim))
        rotate("RightForeArm", axis: L, degrees: -elbow)
        if aim > 0 { rotate("Head", axis: U, degrees: 12 * aim); rotate("Spine1", axis: U, degrees: 10 * aim) }
        apply(dt: dt, rate: aim > 0 || tuck > 0 ? 22 : 12)
    }
}
