import Foundation

/// Visual/gameplay style of one 40 m segment.
enum SegmentStyle: String {
    case city, tunnel, elevated, fork, branch, tube
}

/// One entry of the scripted track. `curvature` is the lateral distance (m) the road
/// gains over the segment: positive bends right. `obstacleRows` is 0...3.
struct TrackBlock {
    /// Landmark dressing on a city block: an overpass crossing the road, or a lit gateway.
    enum Dressing { case none, overpass, gateway }
    var style: SegmentStyle
    var curvature: Float = 0
    var obstacleRows: Int = 0
    var name: String
    var dressing: Dressing = .none

    static func city(_ c: Float = 0, rows: Int = 0, _ name: String = "downtown") -> TrackBlock { .init(style: .city, curvature: c, obstacleRows: rows, name: name) }
    static func tunnel(_ c: Float = 0, rows: Int = 0) -> TrackBlock { .init(style: .tunnel, curvature: c, obstacleRows: rows, name: "undercity tunnel") }
    static func elevated(_ c: Float = 0, rows: Int = 0) -> TrackBlock { .init(style: .elevated, curvature: c, obstacleRows: rows, name: "skyway") }
    static func tube(rows: Int = 0) -> TrackBlock { .init(style: .tube, curvature: 0, obstacleRows: rows, name: "conduit - fly the tube") }
}

/// Deterministic, endless sequence of blocks with one fork whose branch is chosen by
/// the player at the split. The four blocks after a fork are `.branch` placeholders
/// that the scroller re-styles once the choice is made.
final class TrackProgram {
    private let main: [TrackBlock]
    /// Endless free-play track.
    init() { main = TrackProgram.freePlay }
    /// A mission's track. The list is followed once, then the last block repeats.
    init(blocks: [TrackBlock]) { main = blocks.isEmpty ? TrackProgram.freePlay : blocks; loops = false }
    private var loops = true
    static let freePlay: [TrackBlock] = [
        .city(0, rows: 0, "downtown"),
        .city(0, rows: 1, "downtown"),
        .city(3, rows: 1, "downtown - right bend"),
        .city(5, rows: 2, "downtown - right bend"),
        .city(3, rows: 1, "downtown"),
        .city(0, rows: 2, "downtown"),
        .city(-4, rows: 1, "downtown - left bend"),
        .city(-4, rows: 2, "downtown - left bend"),
        .city(0, rows: 1, "approaching split"),
        .init(style: .fork, curvature: 0, obstacleRows: 0, name: "SPLIT - choose a side"),
        .init(style: .branch, name: "branch"),
        .init(style: .branch, name: "branch"),
        .init(style: .branch, name: "branch"),
        .init(style: .branch, name: "branch"),
        .city(0, rows: 1, "merge"),
        .city(0, rows: 0, "conduit ahead"),
        .tube(rows: 1), .tube(rows: 2), .tube(rows: 2), .tube(rows: 1),
        .city(2, rows: 2, "downtown"),
        .city(4, rows: 2, "downtown - right bend"),
        .city(0, rows: 3, "downtown - obstacle field"),
        .city(-3, rows: 2, "downtown - left bend"),
        .city(0, rows: 1, "downtown"),
    ]
    static let leftBranch: [TrackBlock] = [
        .tunnel(-2, rows: 1), .tunnel(-3, rows: 2), .tunnel(0, rows: 2), .tunnel(2, rows: 1),
    ]
    static let rightBranch: [TrackBlock] = [
        .elevated(2, rows: 1), .elevated(3, rows: 1), .elevated(0, rows: 2), .elevated(-2, rows: 2),
    ]
    private var index = 0

    func next() -> TrackBlock {
        let b = loops ? main[index % main.count] : main[min(index, main.count - 1)]
        index += 1
        return b
    }
}

/// Composes a job's whole track from phrases, so the authored variety (bends, fields, a split,
/// a conduit, an undercity run, a skyway, landmarks) covers the full distance instead of the
/// first 320 m. Deterministic per job: the same recipe and seed give the same track.
struct TrackComposer {
    enum Phrase {
        case straight(Int)          // n quiet-to-light blocks
        case bend                   // a three-block bend, direction chosen to keep the road centred
        case sBend                  // left-right-left (or mirrored)
        case field                  // a dense obstacle field
        case split                  // fork + four branch placeholders + merge
        case conduit                // lead-in, four tube blocks, exit
        case undercity              // lead-in, four tunnel blocks, exit
        case skyway                 // lead-in, four elevated blocks, exit
        case landmark               // one straight block under an overpass or through a gateway
    }

    /// `place` names the plain blocks ("downtown", "canyon road"); `finish` names the goal.
    static func compose(distance: Float, recipe: [Phrase], place: String, finish: String, seed: UInt64, density: Float = 1) -> [TrackBlock] {
        var rng = SeededRNG(seed: seed)
        var out: [TrackBlock] = [.city(0, rows: 0, place), .city(0, rows: 1, place)]
        // the last block repeats past the goal, so the list needs the goal plus what is visible ahead
        let needed = Int(distance / 40) + 10
        let tail = 3
        var offset: Float = 0        // cumulative lateral offset, kept bounded by bend direction
        var i = 0
        var landmarkToggle = 0
        while out.count < needed - tail {
            let phrase = recipe.isEmpty ? Phrase.straight(2) : recipe[i % recipe.count]
            i += 1
            switch phrase {
            case .straight(let n):
                for _ in 0..<max(1, n) { out.append(.city(0, rows: rng.chance(0.35) ? 2 : 1, place)) }
            case .bend:
                let dir: Float = abs(offset) > 12 ? (offset > 0 ? -1 : 1) : (rng.chance(0.5) ? 1 : -1)
                let label = dir > 0 ? "\(place) - right bend" : "\(place) - left bend"
                let amp = rng.float(3, 5)
                out.append(.city(dir * amp, rows: 1, label))
                out.append(.city(dir * (amp + 1), rows: 1, label))
                out.append(.city(dir * amp * 0.6, rows: 0, label))
                offset += dir * (amp * 2.6 + 1)
            case .sBend:
                let dir: Float = offset > 0 ? -1 : 1
                out.append(.city(dir * 4, rows: 1, "\(place) - \(dir > 0 ? "right" : "left") bend"))
                out.append(.city(0, rows: 2, place))
                out.append(.city(-dir * 4, rows: 1, "\(place) - \(dir > 0 ? "left" : "right") bend"))
                out.append(.city(dir * 2, rows: 1, place))
                offset += dir * 2
            case .field:
                out.append(.city(0, rows: 2, "\(place) - obstacle field"))
                out.append(.city(0, rows: 3, "\(place) - obstacle field"))
                out.append(.city(0, rows: 2, "\(place) - obstacle field"))
                out.append(.city(0, rows: 0, place))
            case .split:
                out.append(.city(0, rows: 1, "approaching split"))
                out.append(.init(style: .fork, curvature: 0, obstacleRows: 0, name: "SPLIT - choose a side"))
                for _ in 0..<4 { out.append(.init(style: .branch, name: "branch")) }
                out.append(.city(0, rows: 1, "merge"))
            case .conduit:
                out.append(.city(0, rows: 0, "conduit ahead"))
                out.append(.tube(rows: 1)); out.append(.tube(rows: 2)); out.append(.tube(rows: 2)); out.append(.tube(rows: 1))
                out.append(.city(0, rows: 0, place))
            case .undercity:
                out.append(.city(0, rows: 0, "undercity ahead"))
                out.append(.tunnel(-2, rows: 1)); out.append(.tunnel(-3, rows: 2)); out.append(.tunnel(0, rows: 2)); out.append(.tunnel(2, rows: 1))
                out.append(.city(3, rows: 0, place))
            case .skyway:
                out.append(.city(0, rows: 0, "skyway ahead"))
                out.append(.elevated(2, rows: 1)); out.append(.elevated(3, rows: 1)); out.append(.elevated(0, rows: 2)); out.append(.elevated(-2, rows: 2))
                out.append(.city(-3, rows: 0, place))
            case .landmark:
                landmarkToggle += 1
                var b = TrackBlock.city(0, rows: 1, landmarkToggle % 2 == 1 ? "\(place) - overpass" : "\(place) - gateway")
                b.dressing = landmarkToggle % 2 == 1 ? .overpass : .gateway
                out.append(b)
            }
        }
        out.append(.city(0, rows: 1, "\(finish) ahead"))
        out.append(.city(0, rows: 0, finish))
        out.append(.city(0, rows: 0, finish))
        // chapter density: scale the obstacle rows (the first two blocks stay quiet for the launch)
        if density != 1 {
            for i in 2..<out.count where out[i].obstacleRows > 0 {
                out[i].obstacleRows = max(1, min(3, Int((Float(out[i].obstacleRows) * density).rounded())))
            }
        }
        return out
    }
}
