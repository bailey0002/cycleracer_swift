import Foundation
import simd

/// Drivable surfaces of the arena: the ground, flat decks and inclined ramps, plus the
/// rails and columns that come with them. `height(at:)` is the only thing the cycles
/// need; the world builds the visible geometry from the same lists.
struct ArenaTerrain {
    /// Flat rectangle at a height (parking-garage floor).
    struct Deck {
        var min: SIMD2<Float>
        var max: SIMD2<Float>
        var height: Float
        var name: String
        func contains(_ p: SIMD2<Float>) -> Bool { p.x >= min.x && p.x <= max.x && p.y >= min.y && p.y <= max.y }
    }
    /// A curved ramp (4 Oct 2026): a lane of width `width` along a circular arc about `centre` with
    /// centreline radius `radius`, from `a0` to `a1` (radians, signed sweep), rising linearly from
    /// `h0` to `h1` along the sweep. Parking-garage helix quarter / half turns.
    struct Ramp {
        var centre: SIMD2<Float>
        var radius: Float
        var width: Float
        var a0: Float
        var a1: Float
        var h0: Float
        var h1: Float
        /// 0 ... 1 along the sweep, or nil when the point is off the lane.
        func fraction(_ p: SIMD2<Float>) -> Float? {
            let d = p - centre
            let r = simd_length(d)
            guard abs(r - radius) <= width / 2 + 0.3 else { return nil }
            var a = atan2(d.y, d.x)
            // unwrap into the sweep's direction
            let sweep = a1 - a0
            var rel = a - a0
            while rel > .pi { rel -= 2 * .pi }
            while rel < -.pi { rel += 2 * .pi }
            if sweep >= 0 { if rel < -0.02 { rel += 2 * .pi } } else { if rel > 0.02 { rel -= 2 * .pi } }
            let t = rel / sweep
            a = 0
            guard t >= -0.01, t <= 1.01 else { return nil }
            return max(0, min(1, t))
        }
        func contains(_ p: SIMD2<Float>) -> Bool { fraction(p) != nil }
        func height(at p: SIMD2<Float>) -> Float { h0 + (h1 - h0) * (fraction(p) ?? 0) }
        func point(_ t: Float, offset: Float = 0) -> SIMD3<Float> {
            let a = a0 + (a1 - a0) * t
            let r = radius + offset
            return SIMD3(centre.x + cos(a) * r, h0 + (h1 - h0) * t, centre.y + sin(a) * r)
        }
        var length: Float { abs(a1 - a0) * radius }
        var rise: Float { h1 - h0 }
        var bottom: SIMD3<Float> { point(0) }
        var top: SIMD3<Float> { point(1) }
    }
    /// A lime wall strand: points with heights, the wall height above them, and whether it is a
    /// low rail (deck edge) or a full hazard wall.
    struct Strand {
        var points: [SIMD3<Float>]
        var wallHeight: Float
    }

    var decks: [Deck] = []
    var ramps: [Ramp] = []
    var strands: [Strand] = []
    var columns: [(SIMD2<Float>, Float)] = []     // position, height

    /// Ground height under a point for something currently at height `y`: the highest surface
    /// covering the point that is no more than a step above it, so a bike under a deck stays on
    /// the ground and a bike on the deck stays up. Pass no `y` for the topmost surface.
    func height(at p: SIMD2<Float>, below y: Float = .greatestFiniteMagnitude) -> Float {
        let limit = y + 1.5
        var h: Float = 0
        for d in decks where d.contains(p) && d.height <= limit { h = max(h, d.height) }
        for r in ramps where r.contains(p) {
            let rh = r.height(at: p)
            if rh <= limit { h = max(h, rh) }
        }
        return h
    }

    func deckName(at p: SIMD2<Float>, y: Float) -> String {
        for r in ramps where r.contains(p) && abs(r.height(at: p) - y) < 1.5 { return "ramp" }
        for d in decks where d.contains(p) && abs(d.height - y) < 1.5 { return d.name }
        return "ground"
    }

    // MARK: - Layout

    /// The garage (4 Oct 2026): a wide open floor, one deck high along the north wall on two corner
    /// columns, and two half-turn ramps that start on the west and east walls and curve up onto the
    /// deck's ends, so nothing crowds the floor. Four red hazard walls stay on the ground.
    static func garage(halfSize: Float) -> ArenaTerrain {
        var t = ArenaTerrain()
        let deckH: Float = 22
        let deckMin = SIMD2<Float>(-96, -halfSize + 10), deckMax = SIMD2<Float>(96, -78)
        t.decks = [Deck(min: deckMin, max: deckMax, height: deckH, name: "upper deck")]
        let laneW: Float = 16, R: Float = 44
        // west: along the west wall heading north, curving east onto the deck's west edge
        let west = Ramp(centre: SIMD2(deckMin.x, -60), radius: R, width: laneW, a0: .pi, a1: .pi * 1.5, h0: 0, h1: deckH)
        // east: mirror, heading north along the east wall, curving west
        let east = Ramp(centre: SIMD2(deckMax.x, -60), radius: R, width: laneW, a0: 0, a1: -.pi * 0.5, h0: 0, h1: deckH)
        t.ramps = [west, east]
        let rail: Float = 1.3
        func pt(_ x: Float, _ z: Float, _ y: Float) -> SIMD3<Float> { SIMD3(x, y, z) }
        // deck edges: south and north full length; west and east except where the ramps land
        let landZ = -60 - R      // the ramps' top at angle 270 deg: z = centre.y - R
        t.strands.append(Strand(points: [pt(deckMin.x, deckMax.y, deckH), pt(deckMax.x, deckMax.y, deckH)], wallHeight: rail))
        t.strands.append(Strand(points: [pt(deckMin.x, deckMin.y, deckH), pt(deckMax.x, deckMin.y, deckH)], wallHeight: rail))
        for x in [deckMin.x, deckMax.x] {
            t.strands.append(Strand(points: [pt(x, deckMin.y, deckH), pt(x, landZ - laneW / 2, deckH)], wallHeight: rail))
            t.strands.append(Strand(points: [pt(x, landZ + laneW / 2, deckH), pt(x, deckMax.y, deckH)], wallHeight: rail))
        }
        // ramp sides: sampled arcs, inner and outer edge, as polylines with heights
        for r in t.ramps {
            for side in [-laneW / 2, laneW / 2] {
                var pts: [SIMD3<Float>] = []
                for i in 0...16 { pts.append(r.point(Float(i) / 16, offset: side)) }
                t.strands.append(Strand(points: pts, wallHeight: rail))
            }
        }
        // ground hazards
        let q = halfSize * 0.38
        t.strands.append(Strand(points: [pt(-q, -q * 0.3 + 20, 0), pt(-q, q * 0.3 + 20, 0)], wallHeight: 3))
        t.strands.append(Strand(points: [pt(q, -q * 0.3 + 20, 0), pt(q, q * 0.3 + 20, 0)], wallHeight: 3))
        t.strands.append(Strand(points: [pt(-q * 0.3, q, 0), pt(q * 0.3, q, 0)], wallHeight: 3))
        t.strands.append(Strand(points: [pt(-q * 0.3, -q * 0.35, 0), pt(q * 0.3, -q * 0.35, 0)], wallHeight: 3))
        // two support columns at the deck's back corners
        for x in [deckMin.x + 4, deckMax.x - 4] { t.columns.append((SIMD2(x, deckMin.y + 4), deckH)) }
        for c in t.columns {
            let s: Float = 1.6
            t.strands.append(Strand(points: [pt(c.0.x - s, c.0.y - s, 0), pt(c.0.x + s, c.0.y - s, 0), pt(c.0.x + s, c.0.y + s, 0), pt(c.0.x - s, c.0.y + s, 0), pt(c.0.x - s, c.0.y - s, 0)], wallHeight: c.1))
        }
        return t
    }
}
