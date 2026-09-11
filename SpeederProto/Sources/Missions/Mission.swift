import Foundation

/// One job. A mission picks the world and the track blocks, sets a goal and pays out.
struct Mission: Identifiable {
    enum Kind { case delivery }
    let id: Int
    let kind: Kind
    let code: String            // "RELAY 01"
    let title: String           // "DOWNTOWN"
    let contact: String
    let brief: String
    let theme: Theme
    let blocks: [TrackBlock]
    let distance: Float         // metres to the drop
    let timeLimit: Float        // seconds
    let basePay: Int

    var timeText: String { "\(Int(timeLimit)) s" }
    var distanceText: String { String(format: "%.1f km", distance / 1000) }

    /// The delivery run: Tron-clean, terse, system voice.
    static let deliveries: [Mission] = [
        Mission(id: 0, kind: .delivery, code: "RELAY 01", title: "DOWNTOWN", contact: "VESS",
                brief: "Packet for the downtown relay. Straight run, light traffic. Impacts corrupt the cargo. Do not stop.",
                theme: .neonCity,
                blocks: [.city(0, rows: 0, "downtown"), .city(0, rows: 1, "downtown"), .city(3, rows: 1, "downtown - right bend"),
                         .city(2, rows: 1, "downtown"), .city(-3, rows: 1, "downtown - left bend"), .city(0, rows: 2, "downtown"),
                         .city(0, rows: 1, "relay ahead"), .city(0, rows: 0, "relay")],
                distance: 2400, timeLimit: 70, basePay: 200),
        Mission(id: 1, kind: .delivery, code: "RELAY 02", title: "THE SPLIT", contact: "VESS",
                brief: "Relay sits past the split. Tunnel or skyway, your call. Heavier traffic this time.",
                theme: .neonCity,
                blocks: [.city(0, rows: 1, "downtown"), .city(4, rows: 2, "downtown - right bend"), .city(0, rows: 2, "approaching split"),
                         .init(style: .fork, curvature: 0, obstacleRows: 0, name: "SPLIT - choose a side"),
                         .init(style: .branch, name: "branch"), .init(style: .branch, name: "branch"),
                         .init(style: .branch, name: "branch"), .init(style: .branch, name: "branch"),
                         .city(0, rows: 2, "merge"), .city(-3, rows: 2, "downtown - left bend"), .city(0, rows: 1, "relay ahead")],
                distance: 3600, timeLimit: 95, basePay: 300),
        Mission(id: 2, kind: .delivery, code: "RELAY 03", title: "DEEP CONDUIT", contact: "VESS",
                brief: "The relay is below the city. Conduit section: fly the tube, thread the beams. Cargo does not like walls.",
                theme: .neonCity,
                blocks: [.city(0, rows: 1, "downtown"), .city(2, rows: 2, "downtown"), .city(0, rows: 0, "conduit ahead"),
                         .tube(rows: 1), .tube(rows: 2), .tube(rows: 2), .tube(rows: 1),
                         .city(0, rows: 2, "downtown"), .city(0, rows: 1, "relay ahead")],
                distance: 3000, timeLimit: 80, basePay: 400),
        Mission(id: 3, kind: .delivery, code: "RELAY 04", title: "OUTLANDS", contact: "KADE",
                brief: "Carry it out of the city. Canyon road, long bends, a rock-cut tunnel. Daylight. Nobody is watching out there.",
                theme: .sunsetCanyon,
                blocks: [.city(0, rows: 0, "canyon road"), .city(4, rows: 1, "canyon - right bend"), .city(5, rows: 2, "canyon - right bend"),
                         .city(0, rows: 1, "canyon road"), .city(-4, rows: 2, "canyon - left bend"), .city(0, rows: 2, "approaching split"),
                         .init(style: .fork, curvature: 0, obstacleRows: 0, name: "SPLIT - choose a side"),
                         .init(style: .branch, name: "branch"), .init(style: .branch, name: "branch"),
                         .init(style: .branch, name: "branch"), .init(style: .branch, name: "branch"),
                         .city(0, rows: 1, "merge"), .city(3, rows: 2, "canyon road"), .city(0, rows: 1, "relay ahead")],
                distance: 4200, timeLimit: 105, basePay: 500),
    ]
}
