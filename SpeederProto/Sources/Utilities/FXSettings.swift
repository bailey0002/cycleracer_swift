import Foundation

/// Diagnostic toggles (brief §37). Each one isolates a visual technique so its
/// contribution to look and frame time can be judged independently.
struct FXSettings: Equatable {
    var roadMotion  = true
    var buildings   = true
    var signs       = true
    var neon        = true      // emissive lane / roadside / building strips
    var realLights  = true      // point + directional lights
    var reflections = true      // fake wet-road reflection decals
    var particles   = true
    var cameraShake = true
    var obstacles   = true
    // look variants (compared in the variant sweep)
    var obstacleSkin = 1        // 0 solid hazard, 1 hologram, 2 neon wireframe, 3 solid body + trim
    var tunnelDense = true      // light rings every 4 m instead of 8 m
    var secondRow   = true      // taller second row of buildings
    var storefronts = true      // ground-floor neon strips + podiums
    var windowsBright = true    // brighter lit windows
    var fogLevel    = 0         // 0 thin, 1 normal, 2 thick
    var bloomLevel  = 0         // 0 low, 1 normal, 2 high
    var ringColor   = 2         // 0 mixed, 1 blue, 2 red, 3 amber
    var hazardColor = 1         // 0 magenta, 1 yellow-green, 2 orange, 3 white
    var hazardX     = false     // red X mark on blocks, gates and hatches
    var environment = 0         // Theme rawValue; changing it rebuilds the scene
    var palette     = 1         // 0 mixed neon, 1 road cyan / city warm, 2 road amber / city cool, 3 painted road (daylight)
    var postFX      = true      // master switch for the Metal post pass
    var fog         = true
    var bloom       = true
    var streaks     = true
    var colorGrade  = true
    var cruiseSpeed: Float = 45  // m/s
    // The Grid (arena mode)
    var steeringMode = 0        // 0 analog velocity steering, 1 ninety-degree snap turns
    var jumpRule     = 0        // 0 elevated trail follows the jump, 1 the trail gaps while airborne
    var trailLength  = 1        // 0 short (220 m), 1 long (420 m), 2 endless
    var opponent     = true     // AI light cycle
    var grinding     = true     // proximity speed surge + energy
}

struct FrameStats {
    var fps: Double = 0
    var frameMs: Double = 0
    var speed: Float = 0
    var entities: Int = 0
    var lights: Int = 0
    var sourceFormat: String = "-"
    var distance: Float = 0
    var hits: Int = 0
    var section: String = ""
    var flash: Float = 0
    var decision: String? = nil
    var kills: Int = 0
    var altitude: Float = 0
    var controller: String? = nil
    // arena
    var energy: Float = 0
    var edge: Float = 1
    var grind: Float = 0
    var state: String = ""
    var pickup: String? = nil
    var wins = 0
    var losses = 0
    var trailSegments = 0
}
