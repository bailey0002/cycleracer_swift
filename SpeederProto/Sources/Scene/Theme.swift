import Foundation
import simd

/// A complete environment: lighting regime, sky, materials family, atmosphere and grade.
/// Everything that is not gameplay reads from here so a new world is a new preset.
enum Theme: Int, CaseIterable {
    case neonCity = 0
    case sunsetCanyon = 1

    var name: String {
        switch self {
        case .neonCity: return "Neon City (night)"
        case .sunsetCanyon: return "Sunset Canyon"
        }
    }

    /// Multiplier on every emissive "neon" material. Daylight turns neon into painted or lit plastic.
    var neonScale: Float { self == .neonCity ? 1.0 : 0.28 }
    /// Image-based light strength (2^x).
    var iblExponent: Float { self == .neonCity ? 0.6 : 0.75 }

    var sunColor: SIMD3<Float> { self == .neonCity ? SIMD3(0.80, 0.85, 1.0) : SIMD3(1.0, 0.72, 0.45) }
    var sunIntensity: Float { self == .neonCity ? 2600 : 9000 }
    /// Where the key light shines from (world space, relative to the vehicle).
    var sunFrom: SIMD3<Float> { self == .neonCity ? SIMD3(5, 14, 9) : SIMD3(-40, 12, -70) }
    var shadowDistance: Float { self == .neonCity ? 30 : 70 }
    var useFillSpot: Bool { self == .neonCity }

    var fogColor: SIMD4<Float> { self == .neonCity ? SIMD4(0.075, 0.045, 0.150, 0.8) : SIMD4(0.78, 0.50, 0.32, 0.25) }
    var fogDensityScale: Float { self == .neonCity ? 1.0 : 0.5 }
    /// Cool lift in the shadows (neon) vs. none (daylight).
    var gradeStrength: Float { self == .neonCity ? 1.0 : 0.15 }
    var exposure: Float { self == .neonCity ? 1.0 : 0.82 }
    var saturation: Float { self == .neonCity ? 1.18 : 1.08 }
    var vignette: Float { self == .neonCity ? 0.45 : 0.30 }
    var streakScale: Float { self == .neonCity ? 1.0 : 0.35 }

    var speedParticleColor: (SIMD4<Float>, SIMD4<Float>) {
        self == .neonCity ? (SIMD4(0.6, 0.9, 1.0, 0.55), SIMD4(1.0, 0.4, 0.9, 0.0))
                          : (SIMD4(1.0, 0.85, 0.6, 0.35), SIMD4(0.9, 0.7, 0.5, 0.0))
    }
    var speedParticleSize: Float { self == .neonCity ? 0.035 : 0.06 }

    /// Defaults that make sense for the environment (applied when switching).
    func adjust(_ s: inout FXSettings) {
        switch self {
        case .neonCity:
            s.reflections = true; s.fogLevel = 0; s.bloomLevel = 0; s.ringColor = 2; s.palette = 1; s.streaks = true
        case .sunsetCanyon:
            s.reflections = false; s.fogLevel = 0; s.bloomLevel = 0; s.ringColor = 3; s.palette = 3; s.streaks = false
        }
    }
}
