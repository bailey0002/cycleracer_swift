import Foundation
import simd

// MARK: - Data

/// One wall segment of a light trail. `a`/`b` are the bottom-centre points; the wall
/// spans `[a.y, a.y + height]`. A non-live segment is a gap (jump with the gap rule,
/// or a phase) and never collides.
struct TrailSegment {
    var a: SIMD3<Float>
    var b: SIMD3<Float>
    var heightA: Float
    var heightB: Float
    /// Arc length at a / b, measured from the trail origin (shader fade uses it).
    var sA: Float
    var sB: Float
    var live: Bool
    var owner: Int
    /// Ground height under each end (the renderer's floor reflection strip sits there).
    var floorA: Float = 0
    var floorB: Float = 0

    var dir2: SIMD2<Float> {
        let d = SIMD2<Float>(b.x - a.x, b.z - a.z)
        let l = simd_length(d)
        return l > 1e-5 ? d / l : SIMD2<Float>(0, -1)
    }
    var length: Float { simd_length(SIMD2<Float>(b.x - a.x, b.z - a.z)) }
    var yMin: Float { min(a.y, b.y) }
    var yMax: Float { max(a.y + heightA, b.y + heightB) }
}

struct SegRef: Hashable {
    let trail: Int
    let index: Int      // global segment index within the trail
}

/// Result of a swept collision test.
struct TrailHit {
    let ref: SegRef
    let t: Float                 // 0...1 along the sweep
    let point: SIMD2<Float>      // xz
    let wallDir: SIMD2<Float>    // unit direction of the wall segment
    let normal: SIMD2<Float>     // unit normal facing the sweep origin
    let boundary: Bool
}

// MARK: - Trail

/// The logical trail of one cycle: an append-only list of segments with a global index
/// (`offset` + array index) that stays stable across compaction. Decay kills from the
/// oldest end by moving `firstAlive` forward.
final class Trail {
    let owner: Int
    var color: SIMD3<Float>
    /// Static walls (hazards, rails) never decay.
    var isStatic = false
    private(set) var segments: [TrailSegment] = []
    private(set) var offset = 0
    private(set) var firstAlive = 0
    private(set) var lastPoint: (pos: SIMD3<Float>, height: Float, s: Float, floor: Float)? = nil
    private var breakPending = false
    /// Increments each time the trail is reset so renderers can tell a fresh trail apart.
    private(set) var generation = 0

    init(owner: Int, color: SIMD3<Float>) {
        self.owner = owner
        self.color = color
    }

    var count: Int { segments.count }
    var newestIndex: Int { offset + segments.count - 1 }
    var headS: Float { lastPoint?.s ?? 0 }
    /// Arc length of the alive part of the trail.
    var aliveLength: Float {
        guard let s = segment(global: firstAlive), let last = lastPoint else { return 0 }
        return last.s - s.sA
    }
    var tailS: Float { segment(global: firstAlive)?.sA ?? headS }

    func segment(global i: Int) -> TrailSegment? {
        let k = i - offset
        guard k >= 0, k < segments.count else { return nil }
        return segments[k]
    }

    func isAlive(_ i: Int) -> Bool { i >= firstAlive && i <= newestIndex }

    /// Append a sample; returns the new segment's global index (nil for the first point).
    func append(_ pos: SIMD3<Float>, height: Float, floor: Float? = nil) -> Int? {
        let floorY = floor ?? pos.y
        guard let last = lastPoint else {
            lastPoint = (pos, height, 0, floorY)
            return nil
        }
        let s = last.s + simd_length(SIMD2<Float>(pos.x - last.pos.x, pos.z - last.pos.z))
        segments.append(TrailSegment(a: last.pos, b: pos, heightA: last.height, heightB: height,
                                     sA: last.s, sB: s, live: !breakPending, owner: owner, floorA: last.floor, floorB: floorY))
        breakPending = false
        lastPoint = (pos, height, s, floorY)
        return newestIndex
    }

    /// The next appended point creates a gap instead of a wall.
    func breakStrand() { breakPending = true }

    /// Move the alive window so no more than `maxLength` metres of wall remain.
    /// Returns the global indices that just died.
    func decay(maxLength: Float) -> [Int] {
        guard let last = lastPoint else { return [] }
        var died: [Int] = []
        while let seg = segment(global: firstAlive), firstAlive < newestIndex, last.s - seg.sB > maxLength {
            died.append(firstAlive)
            firstAlive += 1
        }
        return died
    }

    /// Kill the newest `length` metres of wall (Pulse pickup). Returns the indices that died and
    /// starts a fresh strand so the next segment does not connect to the erased part.
    func cutNewest(length: Float) -> [Int] {
        guard let last = lastPoint else { return [] }
        var died: [Int] = []
        var i = newestIndex
        while i >= firstAlive, let seg = segment(global: i), last.s - seg.sA < length {
            died.append(i); i -= 1
        }
        // rebuild without the cut segments: they stay in the array as dead (non-live) so indices hold
        for g in died { segments[g - offset].live = false }
        breakPending = true
        return died
    }

    /// Kill one segment (a derez breach); the index stays valid, the wall becomes a gap.
    func kill(global i: Int) {
        let k = i - offset
        guard k >= 0, k < segments.count else { return }
        segments[k].live = false
    }

    /// Drop dead segments at the front of the array once enough have accumulated.
    func compact(keep: Int = 512) -> Bool {
        let dead = firstAlive - offset
        guard dead > keep else { return false }
        segments.removeFirst(dead)
        offset += dead
        return true
    }

    func reset() {
        segments.removeAll(keepingCapacity: true)
        offset = 0
        firstAlive = 0
        lastPoint = nil
        breakPending = false
        generation += 1
    }
}

// MARK: - Spatial hash

/// Uniform grid over the arena; every live segment is registered in the cells its
/// bounding box covers (segments are short, so that is one to four cells).
final class TrailSpatialHash {
    let halfSize: Float
    let cellSize: Float
    let n: Int
    private var cells: [[SegRef]]

    init(halfSize: Float, cellSize: Float) {
        self.halfSize = halfSize
        self.cellSize = cellSize
        n = Int((halfSize * 2 / cellSize).rounded(.up)) + 1
        cells = Array(repeating: [], count: n * n)
    }

    @inline(__always) private func coord(_ v: Float) -> Int {
        max(0, min(n - 1, Int((v + halfSize) / cellSize)))
    }

    private func forEachCell(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ body: (Int) -> Void) {
        let x0 = coord(min(a.x, b.x)), x1 = coord(max(a.x, b.x))
        let y0 = coord(min(a.y, b.y)), y1 = coord(max(a.y, b.y))
        for y in y0...y1 { for x in x0...x1 { body(y * n + x) } }
    }

    func insert(_ ref: SegRef, _ seg: TrailSegment) {
        forEachCell([seg.a.x, seg.a.z], [seg.b.x, seg.b.z]) { cells[$0].append(ref) }
    }

    func remove(_ ref: SegRef, _ seg: TrailSegment) {
        forEachCell([seg.a.x, seg.a.z], [seg.b.x, seg.b.z]) { i in
            if let k = cells[i].firstIndex(of: ref) { cells[i].remove(at: k) }
        }
    }

    /// Refs in every cell touched by the box (may contain duplicates).
    func query(min lo: SIMD2<Float>, max hi: SIMD2<Float>, _ body: (SegRef) -> Void) {
        forEachCell(lo, hi) { i in for r in cells[i] { body(r) } }
    }

    func removeAll() { for i in cells.indices { cells[i].removeAll(keepingCapacity: true) } }
}

// MARK: - System

/// Owns every trail plus the spatial hash and answers the three questions the game
/// asks: did this sweep hit a wall, how close is the nearest wall, how far is it open
/// in this direction.
final class TrailSystem {
    private(set) var trails: [Trail] = []
    let hash: TrailSpatialHash
    let halfSize: Float
    /// Minimum distance between samples. The speeder is ~4.6 m long; 1.2 m is ~26 %.
    let sampleDistance: Float

    init(halfSize: Float, sampleDistance: Float = 1.2) {
        self.halfSize = halfSize
        self.sampleDistance = sampleDistance
        hash = TrailSpatialHash(halfSize: halfSize + 4, cellSize: 10)
    }

    @discardableResult
    func addTrail(color: SIMD3<Float>) -> Trail {
        let t = Trail(owner: trails.count, color: color)
        trails.append(t)
        return t
    }

    /// Sample the emitter position if it moved far enough (or `force` for a corner).
    /// Returns true when a segment was added.
    @discardableResult
    func emit(owner: Int, position: SIMD3<Float>, height: Float, floor: Float? = nil, force: Bool = false) -> Bool {
        let trail = trails[owner]
        if let last = trail.lastPoint, !force {
            let d = simd_length(SIMD2<Float>(position.x - last.pos.x, position.z - last.pos.z))
            if d < sampleDistance { return false }
        }
        guard let idx = trail.append(position, height: height, floor: floor) else { return false }
        if let seg = trail.segment(global: idx), seg.live { hash.insert(SegRef(trail: owner, index: idx), seg) }
        return true
    }

    func breakStrand(owner: Int) { trails[owner].breakStrand() }

    func decay(maxLength: Float) {
        for t in trails where !t.isStatic {
            for i in t.decay(maxLength: maxLength) {
                if let seg = t.segment(global: i), seg.live { hash.remove(SegRef(trail: t.owner, index: i), seg) }
            }
            _ = t.compact()
        }
    }

    func cutNewest(owner: Int, length: Float) {
        let t = trails[owner]
        for i in t.cutNewest(length: length) {
            if let seg = t.segment(global: i) { hash.remove(SegRef(trail: owner, index: i), seg) }
        }
    }

    /// A derez explosion breaches every dynamic wall within `radius` of `p` (Armagetron's
    /// EXPLOSION_RADIUS). Returns the owners whose trails changed; their renderers must be
    /// rewritten from `firstAlive` and the hash rebuilt by the caller.
    func breach(at p: SIMD2<Float>, radius: Float) -> [Int] {
        var owners: [Int] = []
        for t in trails where !t.isStatic && t.newestIndex >= t.firstAlive && t.count > 0 {
            var changed = false
            for i in t.firstAlive...t.newestIndex {
                guard let seg = t.segment(global: i), seg.live else { continue }
                let a = SIMD2<Float>(seg.a.x, seg.a.z), b = SIMD2<Float>(seg.b.x, seg.b.z)
                let ab = b - a
                let len2 = simd_dot(ab, ab)
                let u = len2 > 1e-6 ? max(0, min(1, simd_dot(p - a, ab) / len2)) : 0
                if simd_length(p - (a + ab * u)) < radius { t.kill(global: i); changed = true }
            }
            if changed { owners.append(t.owner) }
        }
        return owners
    }

    func clearAll() {
        hash.removeAll()
        for t in trails { t.reset() }
    }

    // MARK: Queries

    private func isTestable(_ ref: SegRef, ignoreOwner: Int?, ignoreNewest: Int) -> TrailSegment? {
        let t = trails[ref.trail]
        guard let seg = t.segment(global: ref.index), seg.live, t.isAlive(ref.index) else { return nil }
        if ref.trail == ignoreOwner && ref.index > t.newestIndex - ignoreNewest { return nil }
        return seg
    }

    /// Swept test from `p0` to `p1` (xz) for a body occupying `yBand` vertically.
    func sweep(from p0: SIMD2<Float>, to p1: SIMD2<Float>, yBand: ClosedRange<Float>, ignoreOwner: Int?, ignoreNewest: Int = 4) -> TrailHit? {
        var best: TrailHit? = nil
        let lo = SIMD2<Float>(min(p0.x, p1.x) - 0.5, min(p0.y, p1.y) - 0.5)
        let hi = SIMD2<Float>(max(p0.x, p1.x) + 0.5, max(p0.y, p1.y) + 0.5)
        let d = p1 - p0
        hash.query(min: lo, max: hi) { ref in
            guard let seg = isTestable(ref, ignoreOwner: ignoreOwner, ignoreNewest: ignoreNewest) else { return }
            guard seg.yMax > yBand.lowerBound, seg.yMin < yBand.upperBound else { return }
            let a = SIMD2<Float>(seg.a.x, seg.a.z), b = SIMD2<Float>(seg.b.x, seg.b.z)
            let e = b - a
            let denom = d.x * e.y - d.y * e.x
            guard abs(denom) > 1e-7 else { return }
            let ap = a - p0
            let t = (ap.x * e.y - ap.y * e.x) / denom
            let u = (ap.x * d.y - ap.y * d.x) / denom
            guard t >= 0, t <= 1, u >= 0, u <= 1 else { return }
            if best == nil || t < best!.t {
                let wd = seg.dir2
                var nrm = SIMD2<Float>(-wd.y, wd.x)
                if simd_dot(nrm, -d) < 0 { nrm = -nrm }
                best = TrailHit(ref: ref, t: t, point: p0 + d * t, wallDir: wd, normal: nrm, boundary: false)
            }
        }
        return best
    }

    /// Nearest live wall to a point within `radius` (xz), for grinding, sparks and the edge meter.
    func nearest(to p: SIMD2<Float>, radius: Float, yBand: ClosedRange<Float>, ignoreOwner: Int?, ignoreNewest: Int = 4)
        -> (ref: SegRef, distance: Float, point: SIMD2<Float>, dir: SIMD2<Float>)? {
        var best: (SegRef, Float, SIMD2<Float>, SIMD2<Float>)? = nil
        hash.query(min: p - radius, max: p + radius) { ref in
            guard let seg = isTestable(ref, ignoreOwner: ignoreOwner, ignoreNewest: ignoreNewest) else { return }
            guard seg.yMax > yBand.lowerBound, seg.yMin < yBand.upperBound else { return }
            let a = SIMD2<Float>(seg.a.x, seg.a.z), b = SIMD2<Float>(seg.b.x, seg.b.z)
            let e = b - a
            let l2 = simd_length_squared(e)
            let t = l2 > 1e-8 ? max(0, min(1, simd_dot(p - a, e) / l2)) : 0
            let q = a + e * t
            let dist = simd_length(p - q)
            if dist < radius && (best == nil || dist < best!.1) { best = (ref, dist, q, seg.dir2) }
        }
        return best
    }

    /// Distance until a ray (xz) meets a wall or the arena boundary. Used by the AI.
    func openDistance(from p: SIMD2<Float>, dir: SIMD2<Float>, maxDistance: Float, yBand: ClosedRange<Float>, ignoreOwner: Int?, ignoreNewest: Int = 4) -> Float {
        // boundary first
        var limit = maxDistance
        for axis in 0..<2 {
            let v = dir[axis]
            if abs(v) > 1e-5 {
                let edge: Float = v > 0 ? halfSize : -halfSize
                let t = (edge - p[axis]) / v
                if t > 0 { limit = min(limit, t) }
            }
        }
        // march the ray cell by cell (cells are 10 m, so step 8 m and use the sweep test per step)
        var travelled: Float = 0
        let step: Float = 8
        while travelled < limit {
            let next = min(limit, travelled + step)
            if let hit = sweep(from: p + dir * travelled, to: p + dir * next, yBand: yBand, ignoreOwner: ignoreOwner, ignoreNewest: ignoreNewest) {
                return travelled + (next - travelled) * hit.t
            }
            travelled = next
        }
        return limit
    }
}
