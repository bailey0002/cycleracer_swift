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
    /// Rectangle whose height varies linearly along z from `z0` (height `h0`) to `z1` (height `h1`).
    struct Ramp {
        var xMin: Float
        var xMax: Float
        var z0: Float
        var h0: Float
        var z1: Float
        var h1: Float
        func contains(_ p: SIMD2<Float>) -> Bool {
            p.x >= xMin && p.x <= xMax && p.y >= Swift.min(z0, z1) && p.y <= Swift.max(z0, z1)
        }
        func height(atZ z: Float) -> Float { h0 + (h1 - h0) * (z - z0) / (z1 - z0) }
        var length: Float { abs(z1 - z0) }
        var rise: Float { h1 - h0 }
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
            let rh = r.height(atZ: p.y)
            if rh <= limit { h = max(h, rh) }
        }
        return h
    }

    func deckName(at p: SIMD2<Float>, y: Float) -> String {
        for r in ramps where r.contains(p) && abs(r.height(atZ: p.y) - y) < 1.5 { return "ramp" }
        for d in decks where d.contains(p) && abs(d.height - y) < 1.5 { return d.name }
        return "ground"
    }

    // MARK: - Layout

    /// Two levels like a parking garage: an upper deck over the north half of the arena with an
    /// on-ramp and an off-ramp on its south edge, rails everywhere a bike could drop off, columns
    /// under the deck, and the four lime hazard walls on the ground.
    static func garage(halfSize: Float) -> ArenaTerrain {
        var t = ArenaTerrain()
        let deckH: Float = 9
        let deckMin = SIMD2<Float>(-60, -90), deckMax = SIMD2<Float>(60, -10)
        t.decks = [Deck(min: deckMin, max: deckMax, height: deckH, name: "upper deck")]
        let rampLen: Float = 40
        let west = Ramp(xMin: -60, xMax: -44, z0: deckMax.y + rampLen, h0: 0, z1: deckMax.y, h1: deckH)
        let east = Ramp(xMin: 44, xMax: 60, z0: deckMax.y + rampLen, h0: 0, z1: deckMax.y, h1: deckH)
        t.ramps = [west, east]
        let rail: Float = 1.3
        func pt(_ x: Float, _ z: Float, _ y: Float) -> SIMD3<Float> { SIMD3(x, y, z) }
        // deck edges (south edge only between the ramps)
        t.strands.append(Strand(points: [pt(-44, deckMax.y, deckH), pt(44, deckMax.y, deckH)], wallHeight: rail))
        t.strands.append(Strand(points: [pt(deckMin.x, deckMin.y, deckH), pt(deckMax.x, deckMin.y, deckH)], wallHeight: rail))
        t.strands.append(Strand(points: [pt(deckMin.x, deckMin.y, deckH), pt(deckMin.x, deckMax.y, deckH)], wallHeight: rail))
        t.strands.append(Strand(points: [pt(deckMax.x, deckMin.y, deckH), pt(deckMax.x, deckMax.y, deckH)], wallHeight: rail))
        // ramp sides, split so each segment's vertical band stays tight
        for r in t.ramps {
            for x in [r.xMin, r.xMax] {
                var pts: [SIMD3<Float>] = []
                for i in 0...5 {
                    let z = r.z0 + (r.z1 - r.z0) * Float(i) / 5
                    pts.append(pt(x, z, r.height(atZ: z)))
                }
                t.strands.append(Strand(points: pts, wallHeight: rail))
            }
        }
        // ground hazards (as before)
        let q = halfSize * 0.42
        t.strands.append(Strand(points: [pt(-q, -q * 0.3, 0), pt(-q, q * 0.3, 0)], wallHeight: 3))
        t.strands.append(Strand(points: [pt(q, -q * 0.3, 0), pt(q, q * 0.3, 0)], wallHeight: 3))
        t.strands.append(Strand(points: [pt(-q * 0.3, q, 0), pt(q * 0.3, q, 0)], wallHeight: 3))
        t.strands.append(Strand(points: [pt(-q * 0.3, -q, 0), pt(q * 0.3, -q, 0)], wallHeight: 3))
        // columns under the deck: a grid, skipping the ramp lanes
        for x in stride(from: Float(-60), through: 60, by: 40) {
            for z in stride(from: Float(-90), through: -10, by: 40) {
                t.columns.append((SIMD2(x, z), deckH))
            }
        }
        for c in t.columns {
            let s: Float = 0.8
            t.strands.append(Strand(points: [pt(c.0.x - s, c.0.y - s, 0), pt(c.0.x + s, c.0.y - s, 0), pt(c.0.x + s, c.0.y + s, 0), pt(c.0.x - s, c.0.y + s, 0), pt(c.0.x - s, c.0.y - s, 0)], wallHeight: c.1))
        }
        return t
    }
}
