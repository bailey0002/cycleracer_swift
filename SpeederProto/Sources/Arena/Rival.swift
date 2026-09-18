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

    /// How sharp the AI is: reaction time, not speed (GLtron's difficulty table, Armagetron's AI_IQ).
    /// Every tier rides the same physics as the player.
    enum Skill: Int {
        case steady = 0, sharp, keen
        /// Seconds between decisions (and the urgent tick when a wall is close).
        var tick: Float { switch self { case .steady: return 0.30; case .sharp: return 0.16; case .keen: return 0.10 } }
        var urgentTick: Float { switch self { case .steady: return 0.14; case .sharp: return 0.08; case .keen: return 0.05 } }
        /// How far the probes look, and how much noise blurs the choice.
        var range: Float { switch self { case .steady: return 55; case .sharp: return 80; case .keen: return 100 } }
        var noise: Float { switch self { case .steady: return 8; case .sharp: return 5; case .keen: return 2 } }
        /// Chance per tick of a blink (skipping the decision), so a steady rival makes readable mistakes.
        var blink: Float { switch self { case .steady: return 0.12; case .sharp: return 0.04; case .keen: return 0 } }
        var text: String { switch self { case .steady: return "STEADY"; case .sharp: return "SHARP"; case .keen: return "KEEN" } }
    }

    let name: String
    let temper: Temper
    /// Identity colour for the tag, portrait and badge (the trail keeps the orange opponent role).
    let color: SIMD3<Float>
    var skill: Skill = .sharp

    static let kade = Rival(name: "KADE", temper: .hunter, color: SIMD3(1.0, 0.42, 0.06), skill: .steady)
    static let orin = Rival(name: "ORIN", temper: .boxer, color: SIMD3(1.0, 0.22, 0.55), skill: .sharp)
    static let sable = Rival(name: "SABLE", temper: .runner, color: SIMD3(1.0, 0.80, 0.15), skill: .keen)
    /// The dispatcher, on a cycle for the last duel: rides like Kade taught it, at Sable's sharpness.
    static let vess = Rival(name: "VESS", temper: .hunter, color: SIMD3(0.35, 0.9, 1.0), skill: .keen)
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
