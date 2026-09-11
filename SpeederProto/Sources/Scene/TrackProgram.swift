import Foundation

/// Visual/gameplay style of one 40 m segment.
enum SegmentStyle: String {
    case city, tunnel, elevated, fork, branch, tube
}

/// One entry of the scripted track. `curvature` is the lateral distance (m) the road
/// gains over the segment: positive bends right. `obstacleRows` is 0...3.
struct TrackBlock {
    var style: SegmentStyle
    var curvature: Float = 0
    var obstacleRows: Int = 0
    var name: String

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
