import Foundation
import simd

/// The rider: a callsign typed once, a livery accent that tints the bike, the trail and the tag, and a
/// title earned from ranks. Identity is shown at the peak moments (the briefing, the result card, the
/// duel score, the derez cam), never edited mid-run (Rocket League Sideswipe's avatar / banner / title).
struct Player: Equatable {
    static let liveries: [(name: String, color: SIMD3<Float>)] = [
        ("CYAN", SIMD3(0.12, 0.72, 1.0)),
        ("MAGENTA", SIMD3(1.0, 0.28, 0.82)),
        ("LIME", SIMD3(0.72, 1.0, 0.25)),
        ("AMBER", SIMD3(1.0, 0.70, 0.20)),
        ("WHITE", SIMD3(0.95, 0.98, 1.0)),
    ]
    static let defaultCallsign = "RIDER"

    var callsign: String = Player.defaultCallsign
    var livery: Int = 0

    var liveryColor: SIMD3<Float> { Self.liveries[max(0, min(Self.liveries.count - 1, livery))].color }
    var liveryName: String { Self.liveries[max(0, min(Self.liveries.count - 1, livery))].name }
    /// The default livery keeps the bike's authored look (cyan core, magenta halo); the others tint it.
    var tintsBike: Bool { livery != 0 }

    /// Uppercase letters and digits, three to eight of them.
    static func sanitise(_ raw: String) -> String {
        let s = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        return s.count < 3 ? defaultCallsign : String(s.prefix(8))
    }

    /// A rank-earned title (F-Zero 99's ranks, Sideswipe's season titles).
    static func title(golds: Int, cleared: Int, finished: Bool = false) -> String {
        if finished { return "ROUTE-HOLDER" }      // earned by the story, not by golds
        if golds >= 9 { return "UNBOXED" }
        if golds >= 4 { return "GATE-RUNNER" }
        if cleared >= 3 { return "COURIER" }
        return "ROOKIE"
    }

    static func load(_ d: UserDefaults) -> Player {
        Player(callsign: sanitise(d.string(forKey: "callsign") ?? defaultCallsign), livery: d.integer(forKey: "livery"))
    }
    func save(_ d: UserDefaults) {
        d.set(callsign, forKey: "callsign")
        d.set(livery, forKey: "livery")
    }
}
