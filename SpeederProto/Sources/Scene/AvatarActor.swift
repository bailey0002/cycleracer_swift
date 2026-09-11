import Foundation
import RealityKit
import simd

/// A character from the avatar pipeline (Character Creator / Avaturn GLB -> USDZ via Blender).
/// Loads async, normalises the pose so the feet sit at y = 0 facing -Z, and loops the first
/// animation clip it finds. Used for hub contacts and briefing cameos.
@MainActor
final class AvatarActor {
    let root = Entity()
    private let holder = Entity()
    private(set) var height: Float = 1.8
    private(set) var clipNames: [String] = []

    static func load(named name: String = "Avatar") async throws -> AvatarActor {
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz") else {
            throw NSError(domain: "Avatar", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(name).usdz missing from bundle"])
        }
        let model = try await Entity(contentsOf: url)
        return AvatarActor(model: model, name: name)
    }

    init(model: Entity, name: String) {
        root.name = "Avatar-\(name)"
        model.name = "AvatarModel"
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
        clipNames = model.availableAnimations.compactMap { $0.name }
        print("Avatar \(name): bounds \(ext) height \(height) clips \(clipNames) children \(model.children.count)")
        if ProcessInfo.processInfo.environment["SPEEDER_AVATAR_ANIM"] != "0", let clip = model.availableAnimations.first {
            model.playAnimation(clip.repeat(), transitionDuration: 0.2, startsPaused: false)
        }
    }

    func debugBounds() -> String {
        let b = root.visualBounds(relativeTo: nil)
        return "min \(b.min) max \(b.max) pos \(root.position(relativeTo: nil)) enabled \(root.isEnabled)"
    }

    /// Face a world point (yaw only).
    func face(_ target: SIMD3<Float>) {
        let p = root.position(relativeTo: nil)
        let d = target - p
        // Avaturn / Character Creator rigs face +Z
        root.orientation = simd_quatf(angle: atan2(-d.x, -d.z) + .pi, axis: [0, 1, 0])
    }
}
