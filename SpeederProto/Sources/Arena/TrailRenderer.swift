import Foundation
import RealityKit
import Metal
import simd

/// Draws one `Trail` as chunked `LowLevelMesh` ribbons. Each chunk is one entity holding
/// up to 256 segments (plus one provisional head segment) in three parts: the opaque
/// core wall, a translucent halo quad and a floor reflection strip. Only the growing
/// chunk is written to; sealed chunks are never touched again except for the per-frame
/// fade uniforms, which live in the material.
@MainActor
final class TrailRenderer {
    struct Vertex {
        var position: SIMD3<Float>
        var uv: SIMD2<Float>
        var color: SIMD4<Float>
    }
    static let segmentsPerChunk = 256
    static let slots = segmentsPerChunk + 1          // + provisional head
    static let vertsPerSegment = 12
    static let indicesPerPart = 6

    private final class Chunk {
        let entity: ModelEntity
        let mesh: LowLevelMesh
        let start: Int              // global index of slot 0
        var filled = 0              // committed segments
        var bmin = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var bmax = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        init(entity: ModelEntity, mesh: LowLevelMesh, start: Int) { self.entity = entity; self.mesh = mesh; self.start = start }
    }

    let root = Entity()
    let trail: Trail
    private var chunks: [Int: Chunk] = [:]
    private var generation: Int
    private var coreMat: any Material
    private var glowMat: any Material
    private var floorMat: any Material
    private var custom: CustomMaterial? = nil
    private var fallback: Bool
    private var lastCommitted = -1
    /// Arc length where the crash pulse currently is (far negative = off).
    var pulseS: Float = -1e6
    var boost: Float = 0
    /// Static walls (hazards) have no head or tail fade.
    var isStatic = false
    var reflections = true { didSet { for c in chunks.values { applyParts(c) } } }

    init(trail: Trail, library: MTLLibrary?) {
        self.trail = trail
        generation = trail.generation
        root.name = "Trail\(trail.owner)"
        if let library, let cm = try? CustomMaterial(surfaceShader: .init(named: "trailSurface", in: library), lightingModel: .unlit) {
            var core = cm
            core.blending = .transparent(opacity: .init(floatLiteral: 1))
            core.faceCulling = .none
            core.writesDepth = true
            var glow = cm
            glow.blending = .transparent(opacity: .init(floatLiteral: 1))
            glow.faceCulling = .none
            glow.writesDepth = false
            var floor = glow
            floor.writesDepth = false
            coreMat = core; glowMat = glow; floorMat = floor
            custom = cm
            fallback = false
        } else {
            var m = UnlitMaterial()
            m.color = .init(tint: .rgb(trail.color))
            var g = UnlitMaterial()
            g.color = .init(tint: .rgb(trail.color))
            g.blending = .transparent(opacity: .init(floatLiteral: 0.3))
            coreMat = m; glowMat = g; floorMat = g
            fallback = true
        }
    }

    // MARK: Per-frame

    /// Sync with the trail: append newly committed segments, drop dead chunks, refresh the
    /// provisional head segment and the fade uniforms.
    func update(headPosition: SIMD3<Float>, headHeight: Float) {
        if trail.generation != generation {
            generation = trail.generation
            for c in chunks.values { c.entity.removeFromParent() }
            chunks.removeAll()
            lastCommitted = -1
        }
        // new committed segments
        let newest = trail.newestIndex
        if newest >= 0 && newest > lastCommitted {
            let from = max(lastCommitted + 1, trail.firstAlive, trail.offset)
            if from <= newest {
                for g in from...newest {
                    guard let seg = trail.segment(global: g) else { continue }
                    let c = chunk(for: g)
                    write(seg, into: c, slot: g - c.start, provisional: false)
                    c.filled = max(c.filled, g - c.start + 1)
                    applyParts(c)
                }
            }
            lastCommitted = newest
        }
        // provisional head: from the last sample to the bike's current tail position
        if let last = trail.lastPoint, newest >= -1 {
            let g = newest + 1
            let c = chunk(for: g)
            let seg = TrailSegment(a: last.pos, b: headPosition, heightA: last.height, heightB: headHeight,
                                   sA: last.s, sB: last.s + simd_length(SIMD2<Float>(headPosition.x - last.pos.x, headPosition.z - last.pos.z)),
                                   live: true, owner: trail.owner)
            write(seg, into: c, slot: g - c.start, provisional: true)
            applyParts(c, provisional: true)
        }
        // dead chunks
        let firstAlive = trail.firstAlive
        for (k, c) in chunks where c.start + Self.segmentsPerChunk <= firstAlive && c.start + Self.segmentsPerChunk <= newest {
            c.entity.removeFromParent()
            chunks[k] = nil
        }
        // fade uniforms
        guard var cm = custom, !fallback else { return }
        let head = (trail.lastPoint?.s ?? 0) + (trail.lastPoint.map { simd_length(SIMD2<Float>(headPosition.x - $0.pos.x, headPosition.z - $0.pos.z)) } ?? 0)
        cm.custom.value = isStatic ? SIMD4<Float>(1e6, -1e6, pulseS, 0) : SIMD4<Float>(head, trail.tailS, pulseS, boost)
        var core = cm; core.faceCulling = .none; core.writesDepth = true; core.blending = .transparent(opacity: .init(floatLiteral: 1))
        var glow = cm; glow.faceCulling = .none; glow.writesDepth = false; glow.blending = .transparent(opacity: .init(floatLiteral: 1))
        coreMat = core; glowMat = glow; floorMat = glow
        for c in chunks.values {
            if var model = c.entity.model { model.materials = [coreMat, glowMat, floorMat]; c.entity.model = model }
        }
    }

    /// Rewrite every segment from `global` to the newest (after a Pulse cut marks them dead).
    func invalidate(from global: Int) {
        let newest = trail.newestIndex
        guard newest >= global else { return }
        for g in global...newest {
            guard let seg = trail.segment(global: g), let c = chunks[g / Self.segmentsPerChunk] else { continue }
            write(seg, into: c, slot: g - c.start, provisional: false)
        }
    }

    // MARK: Chunks

    private func chunk(for global: Int) -> Chunk {
        let k = global / Self.segmentsPerChunk
        if let c = chunks[k] { return c }
        let c = makeChunk(start: k * Self.segmentsPerChunk)
        chunks[k] = c
        root.addChild(c.entity)
        return c
    }

    private func makeChunk(start: Int) -> Chunk {
        var desc = LowLevelMesh.Descriptor()
        desc.vertexCapacity = Self.slots * Self.vertsPerSegment
        desc.indexCapacity = Self.slots * Self.indicesPerPart * 3
        desc.vertexAttributes = [
            .init(semantic: .position, format: .float3, offset: MemoryLayout<Vertex>.offset(of: \.position)!),
            .init(semantic: .uv0, format: .float2, offset: MemoryLayout<Vertex>.offset(of: \.uv)!),
            .init(semantic: .color, format: .float4, offset: MemoryLayout<Vertex>.offset(of: \.color)!),
        ]
        desc.vertexLayouts = [.init(bufferIndex: 0, bufferStride: MemoryLayout<Vertex>.stride)]
        desc.indexType = .uint32
        let mesh = try! LowLevelMesh(descriptor: desc)
        // index pattern is fixed: three contiguous regions (core, glow, floor), six indices per slot
        mesh.withUnsafeMutableIndices { raw in
            let idx = raw.bindMemory(to: UInt32.self)
            for slot in 0..<Self.slots {
                let base = UInt32(slot * Self.vertsPerSegment)
                for part in 0..<3 {
                    let o = part * Self.slots * Self.indicesPerPart + slot * Self.indicesPerPart
                    let b = base + UInt32(part * 4)
                    idx[o] = b; idx[o + 1] = b + 1; idx[o + 2] = b + 2
                    idx[o + 3] = b + 2; idx[o + 4] = b + 1; idx[o + 5] = b + 3
                }
            }
        }
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { raw in
            let v = raw.bindMemory(to: Vertex.self)
            for i in 0..<(Self.slots * Self.vertsPerSegment) { v[i] = Vertex(position: .zero, uv: .zero, color: .zero) }
        }
        let resource = try! MeshResource(from: mesh)
        let entity = ModelEntity(mesh: resource, materials: [coreMat, glowMat, floorMat])
        entity.name = "chunk\(start)"
        return Chunk(entity: entity, mesh: mesh, start: start)
    }

    private func write(_ seg: TrailSegment, into c: Chunk, slot: Int, provisional: Bool) {
        let col = trail.color
        let a = seg.a, b = seg.b
        let n2 = SIMD2<Float>(-seg.dir2.y, seg.dir2.x)
        let n = SIMD3<Float>(n2.x, 0, n2.y)
        let glowPad: Float = 0.35
        let floorHalf: Float = 1.6
        c.mesh.withUnsafeMutableBytes(bufferIndex: 0) { raw in
            let v = raw.bindMemory(to: Vertex.self)
            let base = slot * Self.vertsPerSegment
            if !seg.live {
                for i in 0..<Self.vertsPerSegment { v[base + i] = Vertex(position: a, uv: [seg.sA, 0], color: [col.x, col.y, col.z, 0]) }
                return
            }
            // core
            v[base + 0] = Vertex(position: a, uv: [seg.sA, 0], color: [col.x, col.y, col.z, 0])
            v[base + 1] = Vertex(position: a + [0, seg.heightA, 0], uv: [seg.sA, 1], color: [col.x, col.y, col.z, 0])
            v[base + 2] = Vertex(position: b, uv: [seg.sB, 0], color: [col.x, col.y, col.z, 0])
            v[base + 3] = Vertex(position: b + [0, seg.heightB, 0], uv: [seg.sB, 1], color: [col.x, col.y, col.z, 0])
            // glow (same plane, taller)
            v[base + 4] = Vertex(position: a - [0, seg.heightA * glowPad, 0], uv: [seg.sA, -glowPad], color: [col.x, col.y, col.z, 1])
            v[base + 5] = Vertex(position: a + [0, seg.heightA * (1 + glowPad), 0], uv: [seg.sA, 1 + glowPad], color: [col.x, col.y, col.z, 1])
            v[base + 6] = Vertex(position: b - [0, seg.heightB * glowPad, 0], uv: [seg.sB, -glowPad], color: [col.x, col.y, col.z, 1])
            v[base + 7] = Vertex(position: b + [0, seg.heightB * (1 + glowPad), 0], uv: [seg.sB, 1 + glowPad], color: [col.x, col.y, col.z, 1])
            // floor strip (reflection / light pool) just above the deck
            let fa = SIMD3<Float>(a.x, 0.03, a.z), fb = SIMD3<Float>(b.x, 0.03, b.z)
            v[base + 8]  = Vertex(position: fa - n * floorHalf, uv: [seg.sA, -1], color: [col.x, col.y, col.z, 2])
            v[base + 9]  = Vertex(position: fa + n * floorHalf, uv: [seg.sA, 1], color: [col.x, col.y, col.z, 2])
            v[base + 10] = Vertex(position: fb - n * floorHalf, uv: [seg.sB, -1], color: [col.x, col.y, col.z, 2])
            v[base + 11] = Vertex(position: fb + n * floorHalf, uv: [seg.sB, 1], color: [col.x, col.y, col.z, 2])
        }
        if !provisional {
            c.bmin = simd_min(c.bmin, simd_min(a, b) - [floorHalf, 0.5, floorHalf])
            c.bmax = simd_max(c.bmax, simd_max(a, b) + [floorHalf, max(seg.heightA, seg.heightB) * 1.4 + 0.5, floorHalf])
        }
    }

    private func applyParts(_ c: Chunk, provisional: Bool = false) {
        let count = c.filled + (provisional ? 1 : 0)
        guard count > 0 else { return }
        var bmin = c.bmin, bmax = c.bmax
        if bmin.x > bmax.x { bmin = [-200, -1, -200]; bmax = [200, 10, 200] }
        // the provisional segment may poke past the sealed bounds; pad generously
        let bounds = BoundingBox(min: bmin - [4, 0, 4], max: bmax + [4, 4, 4])
        let n = Self.indicesPerPart * count
        let region = Self.slots * Self.indicesPerPart
        var parts = [
            LowLevelMesh.Part(indexOffset: 0, indexCount: n, topology: .triangle, materialIndex: 0, bounds: bounds),
            LowLevelMesh.Part(indexOffset: region * MemoryLayout<UInt32>.stride, indexCount: n, topology: .triangle, materialIndex: 1, bounds: bounds),
        ]
        if reflections {
            parts.append(LowLevelMesh.Part(indexOffset: region * 2 * MemoryLayout<UInt32>.stride, indexCount: n, topology: .triangle, materialIndex: 2, bounds: bounds))
        }
        c.mesh.parts.replaceAll(parts)
    }
}
