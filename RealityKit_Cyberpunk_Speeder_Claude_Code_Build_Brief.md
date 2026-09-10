# RealityKit Cyberpunk Speeder Graphics Prototype
## Claude Code Build Brief for Swift / iOS

**Purpose:** Build a small, visually ambitious iOS prototype in Swift using RealityKit that tests whether a short cyberpunk speeder sequence can approach the cinematic visual quality of the previously discussed reference images.

**Primary objective:** Prove the graphics and motion concept first. Do **not** build a full racing game. The prototype should be a short, tightly controlled visual simulation in which the speeder appears to travel at high speed while remaining near a fixed Z position and the environment moves toward the camera.

**Target platform:** iPhone, landscape orientation  
**Language:** Swift  
**Renderer / 3D framework:** RealityKit  
**Optional advanced rendering:** Metal / Metal Performance Shaders for post-processing  
**UI:** SwiftUI or UIKit, whichever integrates most cleanly with RealityKit for the chosen deployment target.

---

# 1. Visual Target

The intended visual style is:

- third-person camera behind and slightly above a futuristic speeder
- dark cyberpunk city at night
- black / charcoal road
- wet or glossy road appearance
- strong cyan, magenta, red, orange and blue emissive accents
- bright lane markers and roadside illumination
- city structures framing a central vanishing point
- atmospheric haze / fog
- strong impression of speed
- light streaks and selective motion blur
- reflective-looking pavement
- slight camera vibration
- subtle hover motion and banking of the vehicle
- high contrast between dark geometry and luminous accents

The target is **not photorealistic simulation accuracy**. It is to make the rendered screen look convincing at gameplay speed.

This distinction is important.

Where RealityKit cannot cheaply reproduce physically accurate global illumination, reflections, or volumetric rendering, use visual approximations:

- emissive materials
- reflection/environment textures
- pre-lit or baked environment elements
- duplicated glow geometry
- screen-space effects
- strategically placed lights
- fog cards or particle systems
- Metal post-processing
- motion and darkness to conceal reduced geometric complexity

The prototype should prioritize **perceived image quality** over physically correct lighting.

---

# 2. Important Expectation About Visual Fidelity

RealityKit should be treated as capable of producing a high-quality mobile 3D result, but the reference images are **art-direction targets**, not screenshots of RealityKit.

Do not assume RealityKit will automatically provide Unreal Engine-style:

- Lumen global illumination
- dense dynamic reflections
- complex volumetric fog
- high-end cinematic motion blur
- automatic bloom-heavy cyberpunk rendering

Instead, reproduce the appearance deliberately.

The prototype should determine how close RealityKit can get using:

1. high-quality PBR assets,
2. constrained camera composition,
3. emissive lighting,
4. repeated modular geometry,
5. selective real lights,
6. baked visual detail,
7. moving-world simulation,
8. GPU post-processing where worthwhile.

---

# 3. Uploaded Speeder Asset

The source asset is:

`cyberpunk_speeder-Piotr_Pisiak 3.glb`

Observed model characteristics:

- approximate extents: **2.01 × 1.15 × 1.27 model units**
- approximately **4 geometry objects**
- compact enough for a focused prototype

RealityKit's native loading pipeline supports USD-family assets and Reality files, including:

- `.usd`
- `.usda`
- `.usdc`
- `.usdz`
- `.reality`

Therefore convert the supplied `.glb` to `.usdz` before using it in the final RealityKit scene.

Expected asset pipeline:

```text
cyberpunk_speeder.glb
        ↓
inspect / correct scale and orientation
        ↓
convert to USDZ
        ↓
verify materials and textures
        ↓
add to Xcode project bundle
        ↓
load asynchronously in RealityKit
```

Do not manipulate the imported model's mesh hierarchy directly for gameplay if avoidable.

Create a parent/root entity:

```text
SpeederRoot
│
├── ImportedSpeeder
├── EngineGlowLeft
├── EngineGlowRight
├── CollisionProxy
├── OptionalParticles
└── OptionalLightEntities
```

Move, steer, bank, and animate `SpeederRoot`.

---

# 4. Core Illusion: The Vehicle Barely Travels Forward

This prototype should use an **endless moving-world technique**.

The speeder remains near a fixed Z coordinate.

The world moves toward the camera.

Conceptually:

```text
                    DISTANT CITY

          Segment D
          Segment C
          Segment B
          Segment A

              ↑
              ↑ world motion

          [ SPEEEDER ]

              CAMERA
```

The player perceives forward travel because:

- road texture and geometry rush backward,
- roadside objects approach,
- buildings move at different relative speeds,
- obstacles approach,
- lane markers accelerate toward the screen,
- post-processing reinforces velocity.

The actual vehicle can remain near:

```text
Z ≈ constant
```

This is desirable because it:

- avoids a large world,
- reduces floating-point / world-scale issues,
- simplifies collision logic,
- makes recycling assets easy,
- allows very dense visual composition in a tiny scene,
- reduces CPU and GPU load.

---

# 5. Prototype Scope

Build only enough to answer:

> Can RealityKit produce a visually impressive cyberpunk speeder sequence on a modern iPhone?

The first prototype should contain:

- 1 speeder
- 1 camera rig
- 5–8 reusable road segments
- 6–12 modular building assets
- 10–30 roadside light / signage entities
- simple background skyline
- emissive lane markers
- optional fog / haze
- optional particle effects
- moving road/environment
- left/right steering
- vehicle banking
- hover bob
- camera lag / vibration
- speed adjustment
- optional post-processing toggle

Do **not** initially build:

- races
- AI opponents
- complex physics
- open-world driving
- complex collision response
- inventory
- missions
- scoring
- procedural city generation
- large streaming worlds

---

# 6. Suggested Project Architecture

```text
SpeederPrototypeApp
│
├── App/
│   └── SpeederPrototypeApp.swift
│
├── Views/
│   └── SpeederGameView.swift
│
├── Scene/
│   ├── SpeederScene.swift
│   ├── SceneCoordinator.swift
│   ├── CameraRig.swift
│   └── LightingSetup.swift
│
├── Entities/
│   ├── SpeederController.swift
│   ├── RoadSegment.swift
│   ├── WorldScroller.swift
│   └── ObstacleController.swift
│
├── Rendering/
│   ├── MaterialFactory.swift
│   ├── PostProcessing.swift
│   └── SpeedEffects.metal
│
├── Assets/
│   ├── Speeder.usdz
│   ├── Road/
│   ├── Buildings/
│   ├── Signs/
│   └── Textures/
│
└── Utilities/
    ├── Math.swift
    └── PerformanceMonitor.swift
```

Keep the initial implementation simpler if needed, but preserve separation between:

- scene creation
- player input
- world scrolling
- visual effects
- rendering
- asset loading

---

# 7. RealityKit Scene Skeleton

A SwiftUI-based scene can use `RealityView`.

Example conceptual structure:

```swift
import SwiftUI
import RealityKit

struct SpeederGameView: View {

    @State private var speederRoot = Entity()
    @State private var worldRoot = Entity()
    @State private var cameraRoot = Entity()

    var body: some View {
        RealityView { content in

            speederRoot.name = "SpeederRoot"
            worldRoot.name = "WorldRoot"
            cameraRoot.name = "CameraRoot"

            content.add(worldRoot)
            content.add(speederRoot)
            content.add(cameraRoot)

            await configureScene()

        } update: { content in
            // Use RealityKit systems / subscriptions / timer-driven
            // state rather than placing a heavy game loop here.
        }
        .ignoresSafeArea()
    }

    @MainActor
    private func configureScene() async {
        // Load model, create road, lights, camera, etc.
    }
}
```

Claude Code should verify the most appropriate RealityKit update architecture for the current Xcode / iOS SDK rather than blindly treating `RealityView.update` as a 60 FPS game loop.

Prefer RealityKit components/systems, scene update subscriptions, or an appropriate render/update callback mechanism.

---

# 8. Asynchronous Speeder Loading

Use current asynchronous loading APIs.

Example:

```swift
@MainActor
func loadSpeeder() async throws -> Entity {

    let model = try await Entity(
        named: "Speeder",
        in: Bundle.main
    )

    let root = Entity()
    root.name = "SpeederRoot"

    model.name = "SpeederModel"

    root.addChild(model)

    return root
}
```

Avoid synchronous file loading on the main actor for runtime app content because it can hitch the UI.

After loading:

- inspect model orientation
- normalize scale
- center the visual mesh on the gameplay root
- ensure forward direction is consistent with the scene's coordinate system
- preserve original materials where possible

---

# 9. Vehicle Motion

The speeder should have very little Z movement.

Primary variables:

```swift
struct SpeederState {
    var steering: Float = 0
    var horizontalPosition: Float = 0
    var speed: Float = 25
    var hoverPhase: Float = 0
}
```

Suggested motion:

```swift
func updateSpeeder(
    root: Entity,
    steering: Float,
    time: Float,
    deltaTime: Float
) {
    let maxHorizontalOffset: Float = 2.5

    let targetX = steering * maxHorizontalOffset

    root.position.x +=
        (targetX - root.position.x)
        * min(deltaTime * 6.0, 1.0)

    let hoverAmplitude: Float = 0.04
    let hoverFrequency: Float = 4.5

    root.position.y =
        1.1 + sin(time * hoverFrequency) * hoverAmplitude

    let maxBank: Float = 0.18

    let targetBank =
        -steering * maxBank

    let targetOrientation = simd_quatf(
        angle: targetBank,
        axis: SIMD3<Float>(0, 0, 1)
    )

    root.orientation = simd_slerp(
        root.orientation,
        targetOrientation,
        min(deltaTime * 5.0, 1.0)
    )
}
```

Initial tuning target:

```text
horizontal travel:   ±2 to ±3 m equivalent
bank angle:          ±8° to ±15°
hover movement:      2–8 cm
pitch movement:      very subtle
forward Z movement:  approximately zero
```

---

# 10. Recycled Road Segments

Create several road segments of identical length.

Example conceptual representation:

```swift
final class RoadSegmentManager {

    var segments: [Entity] = []

    let segmentLength: Float = 30
    let speed: Float = 35

    func update(deltaTime: Float) {

        let travel =
            speed * deltaTime

        for segment in segments {

            segment.position.z += travel

            if segment.position.z > 15 {
                recycle(segment)
            }
        }
    }

    private func recycle(_ segment: Entity) {

        guard let minimumZ =
            segments.map({ $0.position.z }).min()
        else {
            return
        }

        segment.position.z =
            minimumZ - segmentLength
    }
}
```

Claude Code should harden the recycling logic so it remains seamless at high speed and does not accumulate spacing drift.

---

# 11. Hide Repetition

Do not let the repeated-road technique become visually obvious.

Each segment may include interchangeable child slots:

```text
RoadSegment
│
├── RoadSurface
├── LaneMarkers
├── LeftBarrier
├── RightBarrier
├── LeftPropSlots
├── RightPropSlots
├── SignSlots
└── LightSlots
```

On recycle:

- rotate among building combinations
- change sign layouts
- enable/disable props
- vary light intensity
- vary emissive colors within the art direction
- move objects between predefined slots
- occasionally leave a segment sparse
- change distant skyline inserts

Avoid fully random placement. Curated variation looks better.

---

# 12. Parallax

Not every environmental object should move at the same apparent rate.

Suggested layers:

```text
Lane markings          1.00 × base speed
Road barriers          1.00 × base speed
Foreground lights      0.90–1.00 ×
Near buildings         0.70–0.90 ×
Mid buildings          0.40–0.65 ×
Far skyline            0.10–0.30 ×
Sky / distant haze     almost stationary
```

This is not intended to be physically exact.

It is an artistic tool to exaggerate depth.

---

# 13. PBR Materials

Use `PhysicallyBasedMaterial` for the speeder, road, barriers, and important buildings.

Conceptual road material:

```swift
import RealityKit
import UIKit

func makeRoadMaterial() -> PhysicallyBasedMaterial {

    var material = PhysicallyBasedMaterial()

    material.baseColor = .init(
        tint: UIColor(
            red: 0.025,
            green: 0.03,
            blue: 0.04,
            alpha: 1.0
        )
    )

    material.roughness =
        .init(floatLiteral: 0.16)

    material.metallic =
        .init(floatLiteral: 0.05)

    return material
}
```

For actual production quality, use texture maps:

- base color / albedo
- normal
- roughness
- metallic where appropriate
- emissive

The road should look wet primarily through:

- low roughness
- environment contribution
- reflected-looking texture detail
- moving/emissive highlight elements
- selective real lighting
- post-process bloom

Do not assume a physically perfect real-time reflection solution is required.

---

# 14. Emissive Neon

Neon is central to the art direction because it provides a large visual return at modest geometry cost.

Use emissive materials for:

- lane lights
- rear engines
- edge lights
- signage
- building strips
- road markings
- tunnel lights

Example:

```swift
func makeNeonMaterial(
    color: UIColor
) -> PhysicallyBasedMaterial {

    var material = PhysicallyBasedMaterial()

    material.baseColor =
        .init(tint: color)

    material.emissiveColor =
        .init(color: color)

    material.roughness =
        .init(floatLiteral: 0.25)

    return material
}
```

If the emissive material does not produce enough perceived glow by itself, combine:

1. emissive surface
2. small nearby point/spot light where justified
3. bloom or glow post-processing

Do not use a real dynamic light for every neon object.

That is unnecessarily expensive.

---

# 15. Engine Glow

For the speeder:

```text
Rear engine mesh
    +
emissive pink/red material
    +
optional small light
    +
transparent/additive glow geometry
    +
post-process bloom
```

Consider placing a slightly larger translucent plane or geometry behind the true emitter to create a fake halo.

At high speed, a short particle trail can also strengthen the effect.

---

# 16. Lighting Strategy

The scene should be mostly dark.

This reduces the number of lighting calculations required and focuses attention on:

- speeder silhouette
- rear lights
- wet road
- lane lights
- nearby signage

Suggested lighting hierarchy:

```text
1 primary environment / directional source
        +
a few important local lights
        +
many emissive materials
        +
baked / textured apparent lighting
        +
post-process glow
```

Avoid hundreds of active lights.

Use lighting selectively.

---

# 17. Camera

Target composition:

```text
          CITY / VANISHING POINT
                  |
                  |
             [SPEEDER]
                  |
             CAMERA
```

Recommended initial camera:

- behind vehicle
- elevated
- pitched downward slightly
- moderate field of view
- vehicle occupying lower-middle area of screen
- visible road stretching into distance

Camera should follow horizontal steering only partially.

Example logic:

```swift
func updateCamera(
    cameraRoot: Entity,
    speeder: Entity,
    deltaTime: Float
) {
    let desiredX =
        speeder.position.x * 0.25

    cameraRoot.position.x +=
        (desiredX - cameraRoot.position.x)
        * min(deltaTime * 2.5, 1.0)
}
```

This creates visual inertia.

---

# 18. Camera Shake

Keep shake subtle.

Example:

```swift
func cameraShake(
    time: Float,
    speedNormalized: Float
) -> SIMD3<Float> {

    let amplitude =
        0.003 + speedNormalized * 0.012

    return SIMD3<Float>(
        sin(time * 31.0) * amplitude,
        sin(time * 27.0) * amplitude,
        0
    )
}
```

Do not create violent handheld motion.

The target is vibration associated with speed.

---

# 19. Speed Perception

Visual speed should come from several signals simultaneously.

Use:

1. increasing world translation speed
2. rapidly passing foreground lights
3. lane marker frequency
4. camera FOV adjustment
5. subtle vehicle vibration
6. motion streaks
7. particles
8. environment blur
9. brighter engine emission
10. increased road highlights

A useful speed curve may change more than just world velocity.

Example:

```swift
struct VisualSpeedState {
    var worldSpeed: Float
    var cameraFOV: Float
    var shakeAmount: Float
    var engineIntensity: Float
    var streakIntensity: Float
}
```

---

# 20. FOV Speed Effect

A subtle FOV change can dramatically reinforce acceleration.

Conceptually:

```text
Cruise       55°
Fast         60°
Boost        65–70°
```

Do not overdo this because excessive FOV distortion can make the speeder look stretched.

Interpolate smoothly.

---

# 21. Wet Road Strategy

The reference visual relies heavily on a wet reflective roadway.

RealityKit does not need to produce perfect ray-traced wet-road reflections for this prototype.

Build the visual from layers:

```text
dark asphalt base
        +
low roughness PBR material
        +
normal map
        +
environment lighting
        +
elongated colored reflection decals / textures
        +
emissive lane lights
        +
post-process bloom
```

A reflection texture can contain stretched cyan / magenta / orange features aligned with the road.

At speed, this can look more convincing than trying to compute every reflection dynamically.

---

# 22. Fog / Atmospheric Perspective

Fog serves several functions:

- hides geometry repetition
- softens distant LOD
- creates depth
- makes neon appear brighter
- masks the edge of the constrained world
- reduces need for distant detail

Possible RealityKit-friendly implementations:

1. layered transparent fog planes
2. low-density particles
3. billboard cards
4. post-process depth fog if available through the chosen rendering path
5. custom Metal effect if necessary

Prefer the cheapest visually acceptable technique first.

---

# 23. Buildings

Do not model a full city.

Use modular façade pieces.

Example:

```text
Building_A
Building_B
Building_C
Tower_A
Tower_B
Billboard_A
Billboard_B
Bridge_A
```

Place them in repeated combinations.

Use:

- dark façades
- emissive windows
- emissive signage
- texture atlases
- simple silhouettes
- fog to hide repetition

The scene is viewed at speed; silhouette and light placement matter more than fine geometry.

---

# 24. Signs and Billboards

These can provide enormous visual richness cheaply.

Use planes with textures or simple geometry.

Possible art:

- fake corporate logos
- abstract glyphs
- cyberpunk advertisements
- animated color blocks
- caution symbols
- route markers

Avoid creating many live text-rendering surfaces unless necessary.

Pre-rendered textures are cheaper and visually predictable.

---

# 25. Particles

Useful optional effects:

- mist
- rain
- sparks
- road dust
- speed particles
- small engine trails

Keep particle counts mobile-friendly.

Particles close to camera can create stronger speed sensation than huge numbers of distant particles.

---

# 26. Metal and Custom Materials

RealityKit supports `CustomMaterial` using Metal shader functions.

Use custom materials only where they provide a clear visible benefit.

Possible uses:

- animated UV distortion
- moving energy patterns
- road shimmer
- engine distortion
- animated scanline neon
- surface pulsing

Conceptual Metal surface shader:

```metal
#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

[[visible]]
void neonPulse(
    realitykit::surface_parameters params
) {
    float time = params.uniforms().time();

    half pulse =
        half(0.75 + 0.25 * sin(time * 5.0));

    params.surface().set_emissive_color(
        half3(1.0h, 0.05h, 0.45h) * pulse
    );
}
```

Claude Code should verify syntax against the current RealityKit Metal API and deployment target before committing the implementation.

---

# 27. RealityKit Post-Processing

Current RealityKit supports post-processing of rendered frames.

Apple exposes a post-process context that can be used with GPU-capable techniques such as:

- Metal
- Metal Performance Shaders
- Core Image
- SpriteKit overlays

Potential effects for this prototype:

- bloom
- highlight glow
- color grading
- vignette
- chromatic distortion
- directional speed streaks
- selective blur
- lens-style flare approximations

Do not implement every effect initially.

Priority:

```text
1. glow / bloom
2. color grade
3. speed streaks
4. subtle vignette
5. optional distortion
```

---

# 28. Bloom / Glow Concept

A classic bloom pipeline is:

```text
Rendered scene
     ↓
Extract bright pixels
     ↓
Blur
     ↓
Composite over original
```

Pseudo-code:

```swift
func applyBloom(
    source: MTLTexture,
    destination: MTLTexture,
    commandBuffer: MTLCommandBuffer
) {
    // 1. isolate high-luminance pixels
    // 2. Gaussian blur
    // 3. add blurred image back over source
}
```

Metal Performance Shaders may be preferable to writing all blur kernels manually.

---

# 29. Directional Speed Streaks

A strong cyberpunk effect is to stretch bright pixels away from the center / vanishing point.

Conceptual algorithm:

```text
For each screen pixel:

vector = pixelPosition - vanishingPoint

sample several points backward along vector

combine bright samples

strength scales with vehicle speed
```

This should affect mostly bright highlights, not blur the entire image heavily.

The speeder itself should ideally remain comparatively sharp.

---

# 30. Color Grade

Desired general image characteristics:

- deep blacks
- cool blue / cyan shadows
- magenta accents
- warm orange practical lights
- high emissive contrast
- limited mid-tone gray
- slight saturation increase on luminous elements

A post-process LUT or equivalent color adjustment can unify otherwise mismatched assets.

---

# 31. Performance Target

Initial target:

```text
60 FPS on a modern iPhone
```

If necessary:

```text
30 FPS stable
```

is preferable to unstable 40–60 FPS.

Measure:

- frame time
- GPU load
- CPU load
- memory
- draw calls
- entity count
- texture memory

Prototype graphics should be tuned on-device, not only in the simulator.

---

# 32. Optimization Principles

Use:

- shared materials
- texture atlases
- reused meshes
- modular geometry
- LOD where useful
- fewer active lights
- fewer transparent layers
- limited shadow casters
- pooled / recycled objects
- predictable object counts

Avoid:

- thousands of independent entities
- excessive transparent geometry
- huge uncompressed textures
- large numbers of shadow-casting lights
- unnecessary high-poly geometry outside the camera focus
- allocating/deallocating entities every frame

---

# 33. Update Loop / Game Logic

The central update operation should remain simple.

Pseudo-code:

```swift
func update(
    deltaTime: Float,
    currentTime: Float
) {
    readInput()

    updateSpeeder(
        deltaTime: deltaTime,
        time: currentTime
    )

    updateRoad(
        deltaTime: deltaTime
    )

    updateScenery(
        deltaTime: deltaTime
    )

    updateCamera(
        deltaTime: deltaTime
    )

    updateVisualSpeedEffects(
        deltaTime: deltaTime
    )
}
```

---

# 34. Steering Input

For the prototype, support at least one of:

- drag left/right
- virtual left/right screen regions
- tilt
- keyboard arrows when testing on Mac/simulator

Suggested normalized steering value:

```text
-1.0 = full left
 0.0 = center
+1.0 = full right
```

Smooth input rather than snapping.

---

# 35. Collision Proxy

If obstacles are added, use simplified collision geometry rather than the full speeder mesh.

Example hierarchy:

```text
SpeederRoot
├── VisualMesh
└── CollisionProxy
```

A box / capsule approximation is sufficient for this experiment.

---

# 36. Prototype Milestones for Claude Code

## Milestone 1 — Render the Speeder

Goal:

- launch app
- load USDZ speeder
- camera behind/above
- black/neutral environment
- correct scale/orientation
- 60 FPS

Do nothing else until the model looks correct.

---

## Milestone 2 — Moving Road

Add:

- one road material
- five recycled road segments
- visible lane markers
- constant movement toward camera

Success criterion:

> Stationary speeder convincingly appears to travel forward.

---

## Milestone 3 — Steering

Add:

- horizontal input
- smooth left/right movement
- vehicle bank
- camera lag

Success criterion:

> Steering feels dynamic even though the speeder barely travels in world space.

---

## Milestone 4 — Neon Corridor

Add:

- modular buildings
- barriers
- signs
- emissive road lights
- engine lights

Success criterion:

> Scene begins to resemble the cyberpunk reference without post-processing.

---

## Milestone 5 — Wet Road

Add:

- dark glossy road
- normal map
- colored reflected-light textures / decals
- environment contribution

Success criterion:

> Pavement visually carries neon color.

---

## Milestone 6 — Atmosphere

Add:

- fog / haze
- selective particles
- distance masking

Success criterion:

> Background repetition becomes difficult to notice.

---

## Milestone 7 — Cinematic Effects

Add incrementally:

1. bloom
2. color grade
3. speed streaks
4. subtle camera vibration
5. optional distortion

Measure FPS after each.

---

## Milestone 8 — On-Device Evaluation

Test on physical iPhone.

Capture:

- normal-speed video
- slow motion / screen recording if useful
- FPS
- thermal behavior
- memory
- subjective visual quality

Compare against target image.

---

# 37. Diagnostic Toggles

Add a developer overlay that can enable/disable:

```text
[ ] road motion
[ ] buildings
[ ] emissive lights
[ ] real lights
[ ] fog
[ ] particles
[ ] bloom
[ ] streaks
[ ] color grade
[ ] camera shake
[ ] reflections/fakes
```

This will make it much easier to determine which effects deliver the largest visual improvement per unit of performance.

Also display:

```text
FPS
world speed
entity count
active lights
post FX enabled
```

---

# 38. Visual Quality Priorities

If development time is limited, prioritize in this order:

1. camera composition
2. speeder material quality
3. road motion
4. emissive neon
5. wet-road appearance
6. foreground parallax
7. skyline composition
8. bloom
9. fog
10. speed streaks
11. particles
12. secondary environmental detail

The camera and lighting will matter more than raw polygon count.

---

# 39. What Not to Chase Initially

Do not spend early prototype time trying to reproduce:

- physically perfect reflections
- fully dynamic global illumination
- ray tracing
- giant procedural cities
- physically accurate rain
- complex soft-body physics
- advanced vehicle suspension
- detailed cockpit simulation

None is necessary to answer the prototype question.

---

# 40. Desired Final Prototype Experience

When the app launches:

1. Speeder appears on a dark road.
2. Camera is behind and elevated.
3. Road begins moving.
4. Lane lights streak past.
5. Buildings frame the vanishing point.
6. Neon reflects or appears to reflect from pavement.
7. Speeder subtly hovers.
8. Dragging left/right moves and banks the vehicle.
9. Camera follows with slight delay.
10. Speed can increase.
11. Bloom and streak effects strengthen with speed.
12. The scene maintains acceptable frame rate on a physical iPhone.

The visual should make the user think:

> "This looks like a real 3D chase sequence."

even though the underlying mechanics are essentially an endless runner.

---

# 41. Claude Code Instructions

Claude Code: treat this document as a build specification.

Before writing substantial code:

1. inspect the existing Xcode project,
2. identify the current deployment target,
3. identify whether the project uses SwiftUI or UIKit,
4. verify current RealityKit APIs against the installed Xcode SDK,
5. locate the converted speeder USDZ asset,
6. avoid deprecated APIs when a current API is available,
7. keep the prototype isolated so it can later be incorporated into a larger app.

When implementing:

- prefer small compiling increments,
- run/build after each milestone,
- report compile errors precisely,
- do not invent unavailable RealityKit APIs,
- use Apple-supported APIs where practical,
- maintain 60 FPS as the aspirational target,
- prioritize visual impact over physically accurate simulation,
- add performance instrumentation early,
- make visual features individually toggleable.

When an effect can be implemented either through RealityKit or a custom Metal path:

1. try the simplest RealityKit-native implementation first,
2. evaluate the result,
3. move to Metal only when the improvement justifies the added complexity.

Do not turn this into a general-purpose engine.

Build specifically for the camera angle, speed, lighting, and cyberpunk corridor described here.

---

# 42. First Coding Task

Start by producing the smallest runnable RealityKit prototype with:

- landscape presentation
- camera
- `SpeederRoot`
- asynchronously loaded `Speeder.usdz`
- one dark road plane
- two rows of emissive lane/edge lights
- simple directional/environment lighting
- speeder hover animation
- constant road movement

No buildings or post-processing yet.

After it builds successfully, provide:

1. project/file changes,
2. explanation of scene hierarchy,
3. instructions for running on a physical iPhone,
4. any asset orientation/scale issues found,
5. observed or expected performance issues,
6. next recommended visual improvement.

Then proceed milestone-by-milestone.

---

# 43. Starter Scene Constants

Suggested initial constants:

```swift
enum SceneConstants {

    static let roadWidth: Float = 12
    static let roadSegmentLength: Float = 30
    static let roadSegmentCount = 6

    static let speederHeight: Float = 1.1
    static let speederZ: Float = 2.0

    static let cruiseSpeed: Float = 30
    static let boostSpeed: Float = 55

    static let maxSteeringOffset: Float = 2.5
    static let maxBankRadians: Float = 0.20

    static let hoverAmplitude: Float = 0.045
    static let hoverFrequency: Float = 4.5
}
```

These are starting values only.

Tune against the actual imported model and camera.

---

# 44. Starter Road Generator

Conceptual code:

```swift
import RealityKit

func makeRoadSegment(
    width: Float,
    length: Float
) -> ModelEntity {

    let mesh = MeshResource.generateBox(
        width: width,
        height: 0.05,
        depth: length
    )

    var material = PhysicallyBasedMaterial()

    material.baseColor =
        .init(tint: .init(
            white: 0.03,
            alpha: 1
        ))

    material.roughness =
        .init(floatLiteral: 0.16)

    return ModelEntity(
        mesh: mesh,
        materials: [material]
    )
}
```

Claude Code should adjust API syntax if required by the installed SDK.

---

# 45. Starter Neon Marker

```swift
func makeLaneLight(
    length: Float = 1.2
) -> ModelEntity {

    let mesh = MeshResource.generateBox(
        width: 0.06,
        height: 0.025,
        depth: length
    )

    var material = PhysicallyBasedMaterial()

    let cyan = UIColor(
        red: 0.05,
        green: 0.85,
        blue: 1.0,
        alpha: 1
    )

    material.baseColor =
        .init(tint: cyan)

    material.emissiveColor =
        .init(color: cyan)

    return ModelEntity(
        mesh: mesh,
        materials: [material]
    )
}
```

---

# 46. Starter Speeder Root

```swift
@MainActor
func makeSpeederRoot() async throws -> Entity {

    let root = Entity()
    root.name = "SpeederRoot"

    let model =
        try await Entity(
            named: "Speeder",
            in: Bundle.main
        )

    model.name = "SpeederModel"

    root.addChild(model)

    root.position = SIMD3<Float>(
        0,
        SceneConstants.speederHeight,
        SceneConstants.speederZ
    )

    return root
}
```

---

# 47. Prototype Success Criteria

The experiment is successful if:

- the model looks high quality on-device,
- the moving-world illusion is convincing,
- neon and wet-road treatment look attractive,
- speed feels strong,
- the scene feels 3D rather than like a scrolling 2D background,
- steering and camera motion feel polished,
- RealityKit can maintain an acceptable frame rate,
- visual quality is close enough to the concept image to justify continued Swift development.

If visual quality falls materially below the desired bar after:

- good PBR assets,
- good camera composition,
- emissive lighting,
- wet-road fakes,
- fog,
- bloom,
- speed streaks,

then reassess whether the minigame should move to a different renderer.

Do **not** make that decision before completing the visual prototype.

---

# 48. Apple Documentation References

Use the current Apple documentation as the authoritative API reference.

- RealityKit `CustomMaterial`  
  https://developer.apple.com/documentation/RealityKit/CustomMaterial

- Modifying RealityKit rendering using custom materials  
  https://developer.apple.com/documentation/realitykit/modifying-realitykit-rendering-using-custom-materials

- Loading entities from a file  
  https://developer.apple.com/documentation/realitykit/loading-entities-from-a-file

- RealityKit asynchronous `Entity.init(named:in:)`  
  https://developer.apple.com/documentation/realitykit/entity/init(named:in:)

- RealityKit postprocessing effects  
  https://developer.apple.com/documentation/realitykit/postprocessing-effects

- `PostProcessEffectContext`  
  https://developer.apple.com/documentation/realitykit/postprocesseffectcontext

- Metal Performance Shaders for RealityKit postprocessing  
  https://developer.apple.com/documentation/realitykit/using-metal-performance-shaders-to-create-custom-postprocess-effects

---

# Bottom Line

The experiment should **not** ask whether RealityKit can duplicate Unreal Engine's renderer feature-for-feature.

The useful question is:

> Can a deliberately constrained Swift + RealityKit scene reproduce the *screen appearance* of a cinematic cyberpunk chase closely enough for a short iOS minigame?

For this scene, there are several reasons to expect a strong result:

- fixed and highly controlled camera
- dark environment
- strong emissive art direction
- repeated geometry
- high motion
- constrained play area
- mobile screen size
- opportunity to fake reflections and atmosphere
- postprocessing available when necessary

Build the illusion rather than the entire world.
