import Foundation
import RealityKit
import simd

#if os(macOS)
import AppKit
public typealias PlatformColor = NSColor
#else
import UIKit
public typealias PlatformColor = UIColor
#endif

extension PlatformColor {
    static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> PlatformColor {
        #if os(macOS)
        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
        #else
        return UIColor(red: r, green: g, blue: b, alpha: a)
        #endif
    }
    static func rgb(_ v: SIMD3<Float>, _ a: Float = 1) -> PlatformColor {
        rgb(CGFloat(v.x), CGFloat(v.y), CGFloat(v.z), CGFloat(a))
    }
}

/// Art-direction palette (linear-ish sRGB values).
enum Neon {
    static let cyan    = SIMD3<Float>(0.10, 0.95, 1.00)
    static let magenta = SIMD3<Float>(1.00, 0.12, 0.70)
    static let red     = SIMD3<Float>(1.00, 0.10, 0.18)
    static let orange  = SIMD3<Float>(1.00, 0.55, 0.12)
    static let blue    = SIMD3<Float>(0.25, 0.45, 1.00)
    static let violet  = SIMD3<Float>(0.60, 0.25, 1.00)
    static let white   = SIMD3<Float>(0.95, 0.95, 1.00)
    static let all: [SIMD3<Float>] = [cyan, magenta, red, orange, blue, violet]
}

/// Deterministic seeded RNG so scene variation is curated and repeatable.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 &+ 0x2545F4914F6CDD1D }
    mutating func next() -> UInt64 {
        state ^= state >> 12; state ^= state << 25; state ^= state >> 27
        return state &* 2685821657736338717
    }
    mutating func float(_ lo: Float = 0, _ hi: Float = 1) -> Float {
        lo + (hi - lo) * Float(next() % 1_000_000) / 1_000_000
    }
    mutating func chance(_ p: Float) -> Bool { float() < p }
    mutating func pick<T>(_ a: [T]) -> T { a[Int(next() % UInt64(a.count))] }
}

@inline(__always) func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }
@inline(__always) func damp(_ current: Float, _ target: Float, _ rate: Float, _ dt: Float) -> Float {
    current + (target - current) * min(rate * dt, 1)
}
@inline(__always) func clamp01(_ v: Float) -> Float { max(0, min(1, v)) }
