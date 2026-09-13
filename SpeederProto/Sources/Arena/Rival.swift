import Foundation
import CoreGraphics
import simd

/// A named opponent on The Grid: a face (portrait texture), a colour and a temper that
/// picks the AI's behaviour. Duel jobs name one; free play rotates through the roster.
struct Rival: Equatable {
    /// How the AI plays. Named in the briefing so the player knows what is coming.
    enum Temper: String, CaseIterable {
        case boxer = "BOXER"      // cuts across your line to box you in
        case runner = "RUNNER"    // keeps to open ground and chains the pads
        case hunter = "HUNTER"    // shadows you and grinds your trail

        var line: String {
            switch self {
            case .boxer: return "cuts you off and boxes you in"
            case .runner: return "runs the open ground and the pads"
            case .hunter: return "shadows you and grinds your trail"
            }
        }
    }

    let name: String
    let temper: Temper
    /// Identity colour for the tag, portrait and badge (the trail keeps the orange opponent role).
    let color: SIMD3<Float>

    static let kade = Rival(name: "KADE", temper: .hunter, color: SIMD3(1.0, 0.42, 0.06))
    static let orin = Rival(name: "ORIN", temper: .boxer, color: SIMD3(1.0, 0.22, 0.55))
    static let sable = Rival(name: "SABLE", temper: .runner, color: SIMD3(1.0, 0.80, 0.15))
    /// Free-play roster, in the order a match sequence meets them.
    static let roster: [Rival] = [.kade, .orin, .sable]

    static func named(_ name: String) -> Rival? { roster.first { $0.name == name } }

    /// The contact who hands out jobs (not a rival, but drawn through the same portrait path).
    static let vessColor = SIMD3<Float>(0.35, 0.9, 1.0)

    // MARK: - Portraits (rendered once, cached)

    nonisolated(unsafe) private static var portraitCache: [String: CGImage] = [:]

    /// Portrait badge for a name: rivals get their temper glyph and colour, contacts a plain visor.
    static func portrait(for name: String) -> CGImage {
        if let c = portraitCache[name] { return c }
        let img: CGImage
        if let r = named(name) {
            img = ProceduralTextures.portrait(name: r.name, temper: r.temper, color: r.color)
        } else {
            img = ProceduralTextures.portrait(name: name, temper: nil, color: vessColor)
        }
        portraitCache[name] = img
        return img
    }
}
