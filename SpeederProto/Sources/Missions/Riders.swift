import Foundation

/// The rider roster (1 Oct 2026), mirrored from KERB's `Characters.swift` so the two games share a cast:
/// the same four people who skate Griptap & Co's town, now pulled into the cabinet a second time and
/// riding the Kerbie Astro. Each rider is a USDZ in Resources (`Rider_<id>.usdz`, converted by KERB's
/// `Tools/convert_cc.py`), a profile card (still + two lines + four handling bars) and handling
/// multipliers that `SpeederController` applies to the hoverboard.
struct RiderHandling: Equatable {
    var steer: Float = 1      // lateral steering speed
    var climb: Float = 1      // vertical speed
    var boost: Float = 1      // boost kick (the post pass and the engine hum follow it)
    var hull: Float = 1       // hull energy drained per hit is divided by this
    static let neutral = RiderHandling()
    /// 0 ... 1 for the card bars (0.85 -> 0, 1.15 -> 1).
    static func bar(_ v: Float) -> Double { Double(max(0, min(1, (v - 0.85) / 0.3))) }
}

struct RiderProfile: Identifiable, Equatable {
    let id: String
    let asset: String          // USDZ resource name (no extension)
    let name: String
    let tag: String            // nickname / role, all caps on the card
    let home: String           // the spot they own, back in town
    let bio: [String]          // two short lines
    let handling: RiderHandling
    let signature: String      // what they are known for on the board
    let still: String          // jpg resource
}

enum Roster {
    static let all: [RiderProfile] = [
        RiderProfile(id: "cal", asset: "Rider_cal", name: "CAL REYES", tag: "THE RUNNER", home: "Marlow Street",
                     bio: ["KERB FM's courier since the station's first night.",
                           "First through the cabinet, first back for more."],
                     handling: RiderHandling(steer: 1.0, climb: 1.0, boost: 1.0, hull: 1.0),
                     signature: "CLEAN LINES", still: "rider_cal"),
        RiderProfile(id: "dude1", asset: "Rider_dude1", name: "JONAH VANCE", tag: "BLEACH  //  BOWL LOCAL", home: "Cannery Bowl",
                     bio: ["Learned the Cannery Bowl before it had coping.",
                           "Says nothing in the Grid is taller than his airs."],
                     handling: RiderHandling(steer: 0.94, climb: 1.12, boost: 1.06, hull: 0.95),
                     signature: "BIG AIR", still: "rider_dude1"),
        RiderProfile(id: "dude2", asset: "Rider_dude2", name: "DOMINIC ROOK", tag: "ROOK  //  STREET", home: "Dex's Block",
                     bio: ["Rode for Dex's crew until Dex started charging for the ledges.",
                           "Rails, conduits, anything with an edge on it."],
                     handling: RiderHandling(steer: 1.12, climb: 0.92, boost: 0.96, hull: 1.08),
                     signature: "TIGHT STEER", still: "rider_dude2"),
        RiderProfile(id: "girl1", asset: "Rider_girl1", name: "MIRA SABLE", tag: "SABLE  //  PLAZA", home: "Cannery plaza",
                     bio: ["Cannery's little sister and the plaza's manual queen.",
                           "Filmed the last KERB FM show. Wants the next one."],
                     handling: RiderHandling(steer: 1.04, climb: 0.98, boost: 1.12, hull: 0.9),
                     signature: "LONG BOOST", still: "rider_girl1"),
    ]

    static let key = "rider.id"

    /// The chosen rider: `SPEEDER_RIDER=<id>` in the harness, else the persisted choice, else Cal.
    static func current(_ d: UserDefaults = .standard) -> RiderProfile {
        if let env = ProcessInfo.processInfo.environment["SPEEDER_RIDER"], let r = all.first(where: { $0.id == env }) { return r }
        let saved = d.string(forKey: key)
        return all.first { $0.id == saved } ?? all[0]
    }

    static func select(_ r: RiderProfile, _ d: UserDefaults = .standard) { d.set(r.id, forKey: key) }

    static func index(of r: RiderProfile) -> Int { all.firstIndex { $0.id == r.id } ?? 0 }
}
