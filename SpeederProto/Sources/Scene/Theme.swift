import Foundation
import simd

/// A complete environment: lighting regime, sky, materials family, atmosphere and grade.
/// Everything that is not gameplay reads from here so a new world is a new preset.
enum Theme: Int, CaseIterable {
    case neonCity = 0
    case sunsetCanyon = 1
    case theGrid = 2

    var name: String {
        switch self {
        case .neonCity: return "Neon City (night)"
        case .sunsetCanyon: return "Sunset Canyon"
        case .theGrid: return "The Grid (arena)"
        }
    }

    /// The Grid is a free-movement light-cycle arena; the other worlds are the scrolling corridor.
    var mode: GameMode { self == .theGrid ? .arena : .corridor }

    /// Multiplier on every emissive "neon" material. Daylight turns neon into painted or lit plastic.
    var neonScale: Float { self == .sunsetCanyon ? 0.28 : 1.0 }
    /// Image-based light strength (2^x).
    var iblExponent: Float {
        switch self { case .neonCity: return 0.6; case .sunsetCanyon: return 0.75; case .theGrid: return 0.45 }
    }

    var sunColor: SIMD3<Float> {
        switch self { case .neonCity: return SIMD3(0.80, 0.85, 1.0); case .sunsetCanyon: return SIMD3(1.0, 0.72, 0.45); case .theGrid: return SIMD3(0.55, 0.75, 1.0) }
    }
    var sunIntensity: Float {
        switch self { case .neonCity: return 2600; case .sunsetCanyon: return 9000; case .theGrid: return 450 }
    }
    /// Where the key light shines from (world space, relative to the vehicle).
    var sunFrom: SIMD3<Float> {
        switch self { case .neonCity: return SIMD3(5, 14, 9); case .sunsetCanyon: return SIMD3(-40, 12, -70); case .theGrid: return SIMD3(-8, 30, 6) }
    }
    var shadowDistance: Float { self == .sunsetCanyon ? 70 : 30 }
    /// The camera-mounted fill spot only helps the city; on the glossy grid floor it reads as a white blob.
    var useFillSpot: Bool { self == .neonCity }

    var fogColor: SIMD4<Float> {
        switch self {
        case .neonCity: return SIMD4(0.075, 0.045, 0.150, 0.8)
        case .sunsetCanyon: return SIMD4(0.78, 0.50, 0.32, 0.25)
        case .theGrid: return SIMD4(0.010, 0.028, 0.060, 0.7)
        }
    }
    var fogDensityScale: Float { self == .sunsetCanyon ? 0.5 : 1.0 }
    /// Cool lift in the shadows (neon) vs. none (daylight).
    var gradeStrength: Float { self == .sunsetCanyon ? 0.15 : 1.0 }
    var exposure: Float { self == .sunsetCanyon ? 0.82 : 1.0 }
    var saturation: Float {
        switch self { case .neonCity: return 1.18; case .sunsetCanyon: return 1.08; case .theGrid: return 1.12 }
    }
    var vignette: Float { self == .sunsetCanyon ? 0.30 : 0.45 }
    var streakScale: Float {
        switch self { case .neonCity: return 1.0; case .sunsetCanyon: return 0.35; case .theGrid: return 0.7 }
    }

    var speedParticleColor: (SIMD4<Float>, SIMD4<Float>) {
        switch self {
        case .neonCity: return (SIMD4(0.6, 0.9, 1.0, 0.55), SIMD4(1.0, 0.4, 0.9, 0.0))
        case .sunsetCanyon: return (SIMD4(1.0, 0.85, 0.6, 0.35), SIMD4(0.9, 0.7, 0.5, 0.0))
        case .theGrid: return (SIMD4(0.7, 0.95, 1.0, 0.5), SIMD4(0.3, 0.6, 1.0, 0.0))
        }
    }
    var speedParticleSize: Float { self == .sunsetCanyon ? 0.06 : 0.035 }

    /// Defaults that make sense for the environment (applied when switching).
    func adjust(_ s: inout FXSettings) {
        switch self {
        case .neonCity:
            s.reflections = true; s.fogLevel = 0; s.bloomLevel = 0; s.ringColor = 2; s.palette = 1; s.streaks = true
        case .sunsetCanyon:
            s.reflections = false; s.fogLevel = 0; s.bloomLevel = 0; s.ringColor = 3; s.palette = 3; s.streaks = false
        case .theGrid:
            s.reflections = true; s.fogLevel = 1; s.bloomLevel = 1; s.ringColor = 2; s.palette = 1; s.streaks = true
        }
    }
}
