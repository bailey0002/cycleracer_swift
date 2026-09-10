import Foundation
import RealityKit
import simd

/// Procedural meshes that RealityKit's generators don't cover.
enum Meshes {
    /// Open cylinder along -Z from z = 0 to z = -length, normals facing inward.
    static func tube(radius: Float, length: Float, segments: Int = 40, uRepeat: Float, vRepeat: Float) throws -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        for i in 0...segments {
            let a = Float(i) / Float(segments) * 2 * .pi
            let c = cos(a), s = sin(a)
            for (j, z) in [Float(0), -length].enumerated() {
                positions.append([c * radius, s * radius, z])
                normals.append([-c, -s, 0])
                uvs.append([Float(i) / Float(segments) * uRepeat, Float(j) * vRepeat])
            }
        }
        for i in 0..<segments {
            let a = UInt32(i * 2), b = a + 1, c = a + 2, d = a + 3
            indices += [a, b, c, b, d, c]
        }
        var desc = MeshDescriptor(name: "tube")
        desc.positions = .init(positions)
        desc.normals = .init(normals)
        desc.textureCoordinates = .init(uvs)
        desc.primitives = .triangles(indices)
        return try MeshResource.generate(from: [desc])
    }

    /// Flat annulus in the XY plane (a light ring seen head-on).
    static func ring(inner: Float, outer: Float, segments: Int = 48) throws -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        for i in 0...segments {
            let a = Float(i) / Float(segments) * 2 * .pi
            let c = cos(a), s = sin(a)
            positions.append([c * inner, s * inner, 0]); normals.append([0, 0, 1]); uvs.append([Float(i) / Float(segments), 0])
            positions.append([c * outer, s * outer, 0]); normals.append([0, 0, 1]); uvs.append([Float(i) / Float(segments), 1])
        }
        for i in 0..<segments {
            let a = UInt32(i * 2), b = a + 1, c = a + 2, d = a + 3
            indices += [a, c, b, b, c, d]
        }
        var desc = MeshDescriptor(name: "ring")
        desc.positions = .init(positions)
        desc.normals = .init(normals)
        desc.textureCoordinates = .init(uvs)
        desc.primitives = .triangles(indices)
        return try MeshResource.generate(from: [desc])
    }
}
