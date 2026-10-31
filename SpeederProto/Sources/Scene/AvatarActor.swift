import Foundation
import RealityKit
import simd

/// A character from the avatar pipeline (Character Creator 5 FBX -> USDZ via KERB's `Tools/convert_cc.py`).
/// Loads async, drops any camera / light the exporter left inside the file, normalises the pose so the feet
/// sit at y = 0 facing +Z, and, when the file carries a skinned rig, poses it every frame with the riders'
/// idle (breathing, weight shift, a head look-at) through `RiderRig`. Used for the briefing contact.
///
/// 2026-10-31: the contact is Marlow (`Resources/Marlow.usdz`, the same export KERB Skate uses as its park
/// actor). `SPEEDER_AVATAR=<name>` loads another `<name>.usdz` (the old Avaturn test figure is `Avatar`).
@MainActor
final class AvatarActor {
    let root = Entity()
    private let holder = Entity()
    private(set) var height: Float = 1.8
    private(set) var clipNames: [String] = []
    private(set) var rig: RiderRig?
    private var idleTime: Float = 0

    static let defaultName = ProcessInfo.processInfo.environment["SPEEDER_AVATAR"] ?? "Marlow"

    static func load(named name: String = AvatarActor.defaultName) async throws -> AvatarActor {
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz") else {
            throw NSError(domain: "Avatar", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(name).usdz missing from bundle"])
        }
        let model = try await Entity(contentsOf: url)
        return AvatarActor(model: model, name: name)
    }

    init(model: Entity, name: String) {
        root.name = "Avatar-\(name)"
        model.name = "AvatarModel"
        Self.stripCameras(model)
        clipNames = model.availableAnimations.compactMap { $0.name }
        if let rig = RiderRig(entity: model) {
            // The rig's stance wrapper faces +X with the feet at y 0; -90° about Y turns it to +Z, the facing
            // `face()` assumes. Centimetre exports come in tiny: scale them to a person.
            if rig.height > 0.01, rig.height < 0.5 { rig.root.scale = SIMD3<Float>(repeating: 1.7 / rig.height) }
            holder.orientation = simd_quatf(angle: -.pi / 2, axis: [0, 1, 0])
            holder.addChild(rig.root)
            root.addChild(holder)
            self.rig = rig
            rig.beginPose()
            rig.apply(dt: 1, rate: 100)
            let b = holder.visualBounds(relativeTo: root)
            height = b.max.y - b.min.y
            print("Avatar \(name): rig \(rig.height) -> height \(height) feet \(b.min.y) clips \(clipNames)")
        } else {
            let bounds = model.visualBounds(relativeTo: nil)
            let ext = bounds.extents
            // the tall axis tells us the up axis after Blender's export (z-up files come in on their side)
            if ext.z > ext.y * 1.5 {
                holder.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
                height = ext.z
            } else {
                height = ext.y
            }
            holder.addChild(model)
            root.addChild(holder)
            // feet on the ground, centred
            let b2 = holder.visualBounds(relativeTo: root)
            holder.position += [-b2.center.x, -b2.min.y, -b2.center.z]
            print("Avatar \(name): bounds \(ext) height \(height) clips \(clipNames) children \(model.children.count)")
            // no rig to pose: loop the first clip if the file has one (Marlow's export has none)
            if ProcessInfo.processInfo.environment["SPEEDER_AVATAR_ANIM"] != "0", let clip = model.availableAnimations.first {
                model.playAnimation(clip.repeat(), transitionDuration: 0.2, startsPaused: false)
            }
        }
    }

    /// A camera inside a loaded USDZ becomes the scene camera (KERB, 2026-10-31: the Marlow export's
    /// Preview_Camera hijacked the view); drop any camera or light entity in the subtree.
    private static func stripCameras(_ e: Entity) {
        for c in Array(e.children) {
            if c.components.has(PerspectiveCameraComponent.self) || c.components.has(PointLightComponent.self)
                || c.components.has(DirectionalLightComponent.self) || c.components.has(SpotLightComponent.self) {
                print("Avatar dropped \(c.name) (camera / light in the USDZ)"); c.removeFromParent()
            } else { stripCameras(c) }
        }
    }

    func debugBounds() -> String {
        let b = root.visualBounds(relativeTo: nil)
        return "min \(b.min) max \(b.max) pos \(root.position(relativeTo: nil)) enabled \(root.isEnabled)"
    }

    /// Face a world point (yaw only). The model's rest facing is +Z.
    func face(_ target: SIMD3<Float>) {
        let p = root.position(relativeTo: nil)
        let d = target - p
        root.orientation = simd_quatf(angle: atan2(d.x, d.z), axis: [0, 1, 0])
    }

    /// Per frame: the riders' idle on the rig (KERB `ActorCast.update`). Breathing and a slow weight shift, plus
    /// the head (and a little neck) turning to `lookAt` (world space) inside `lookRadius`. In the rig's root the
    /// character faces +X and its left is -Z, so a point's bearing to the left is atan2(-z, x); `+U` turns the
    /// head toward the character's left.
    static let lookRadius: Float = 9
    func update(dt: Float, lookAt: SIMD3<Float>) {
        guard let r = rig else { return }
        idleTime += dt
        let t = idleTime
        let breath = sin(t * 2 * .pi / 3.6)
        let sway = sin(t * 2 * .pi / 7.5)
        r.beginPose()
        r.rotate("Spine1", axis: r.L, degrees: 0.8 * breath)
        r.offsetHips(-r.U * 0.004 * (0.5 + 0.5 * breath))
        r.offsetHips(r.L * 0.012 * sway)
        r.rotate("Spine", axis: r.U, degrees: 2.5 * sway)
        r.rotate("Spine2", axis: r.U, degrees: -1.5 * sway)
        r.rotate("Hips", axis: r.F, degrees: 1.2 * sway)
        let p = r.root.convert(position: lookAt, from: nil)
        let d = simd_length(SIMD2<Float>(p.x, p.z))
        if d < Self.lookRadius {
            let bearing = atan2(-p.z, p.x) * 180 / .pi
            let w = min(1, max(0, (Self.lookRadius - d) / 2))
            let yaw = min(70, max(-70, bearing)) * w
            let pitch = min(15, max(-25, atan2(p.y - height * 0.92, max(d, 0.5)) * 180 / .pi)) * w
            r.rotate("Head", axis: r.U, degrees: yaw * 0.7)
            r.rotate("Neck", axis: r.U, degrees: yaw * 0.3)
            r.rotate("Head", axis: r.L, degrees: -pitch * 0.8)
        }
        r.apply(dt: dt, rate: 5)
    }
}
