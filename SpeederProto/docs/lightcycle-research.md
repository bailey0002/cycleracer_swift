# Light-cycle world research (ChatGPT, 9 Sep 2026)

Saved verbatim from the user's ChatGPT session as reference for the third world. Sources are at
the end. The companion kickoff prompt is `NEXT-THREAD-PROMPT.md`.

---

Yes. I think this is a very good fit for native Swift/RealityKit, particularly because you already
have the hardest visual element (the 3D racer and chase-camera presentation) working.

The research turned up relatively few mature Swift-specific light-cycle games, but several excellent
sources for the mechanics, rendering strategy, and collision architecture. The most useful
combination is: RealityKit's newer dynamic-mesh APIs for the visual trail, a lightweight custom
collision representation for the actual game rules, and mechanics borrowed from projects such as
Armagetron Advanced rather than trying to make RealityKit's general-purpose physics engine do everything.

## What I found

| Source | Particularly useful idea |
|---|---|
| `metal-by-example/metal-spatial-dynamic-mesh` | Swift/RealityKit reference for a mesh whose vertices change continuously without recreating the `MeshResource`. Almost exactly the technology for the trail. [1] |
| Apple's `LowLevelMesh` examples | Apple positions `LowLevelMesh` for geometry that must be updated frequently, on CPU or GPU. [2] |
| `3dLightCycles` | Real 3D jet wall, white-to-colour gradient near the bike, curved attachment to the back wheel, acceleration, bike disintegration on collision. [3] |
| `LightRider` | Adds jump, acceleration, steering, and a "look at opponent" action; jump immediately makes a more three-dimensional game than classic Tron. [4] |
| `TronLightCycle` | Development notes explore reflective floor, glowing strip lighting, bike lean, ramps, second floors, pickups, trail-clearing, temporary no-collision and AI. [5] |
| Armagetron Advanced | Richest source for depth: grinding, wall-based acceleration, finite trails, braking, "rubber" near-collision tolerance, zones, multiple physics configurations. [6] |

## Architecture

Do not make the visible light trail the primary collision object. Separate:

```
RACER -> collision proxy (capsule) + trail emitter
TRAIL -> visual trail (LowLevelMesh ribbon) + logical trail (line segments in a spatial grid)
```

RealityKit static collision meshes need preprocessing that grows with vertex count and only work for
static bodies, a poor fit for a trail that grows every frame. [7] The trail is known mathematically;
no need for a 3D physics solver to rediscover it.

### 1. Trail as line segments

```swift
struct TrailSegment {
    let start: SIMD3<Float>
    let end: SIMD3<Float>
    let ownerID: Int
    let bottomY: Float
    let topY: Float
    let radius: Float
}
```

Append a point when the racer has moved a minimum distance (start at 20 to 35 percent of racer
length), so sampling is frame-rate independent.

### 2. One growing ribbon

`LowLevelMesh` keeps buffers you update as geometry changes. Each vertical segment adds 4 vertices,
2 triangles, 6 indices (bottomStart, topStart, bottomEnd, topEnd; triangles 0-1-2 and 2-1-3).
Render two ribbons: a bright unlit core and a slightly larger translucent glow. Fade the newest
portion from near-white to the player's colour (from `3dLightCycles`).

### 3. Chunking

Never one entity per segment (draw-call cost, [8]). Use trail chunks of about 256 segments; only the
current chunk changes; seal it when full and create a new one.

## Collision

The game is 2.5D. Use a swept line from the previous nose position to the current one, intersected
against nearby trail segments (avoids tunnelling at speed). [9] Spatial-hash the arena into cells;
register each segment with the cells it crosses; test the 8 to 20 nearby segments per frame instead
of all of them. The same grid serves AI later.

RealityKit collision still fits ordinary 3D objects: arena boundaries, ramps, pillars, moving
obstacles, pickups, enemy bikes, jump pads, hazards, with simplified shapes and collision groups. [10]
Use a capsule or elongated box for the racer, never the detailed mesh. [11]

## Kinematic racer

Game controls the bike: `speed += accel*dt; heading += steer*turnRate*dt; position += forward*speed*dt`,
with visual lean, suspension, shake and particles layered on top. Kinematic bodies are driven by the
velocities you specify. [12]

## Camera

Spring-follow rig, target slightly ahead of the bike (`racer + forward*4 + up*0.7`), desired camera
`racer - forward*followDistance + up*followHeight`. FOV 60 to 64 normal, 66 to 70 fast, 72 to 76 boost.

## Mechanics worth building

- **Grinding**: riding almost parallel to a trail increases speed; closer is faster. Trail becomes
  danger plus opportunity. Visual escalation: sparks, arcs, speed surge, FOV change. [13]
- **Near-miss meter** ("shield / edge"): proximity drains it instead of killing instantly; recharges
  when away. Precision driving becomes speed advantage at higher risk (Armagetron's rubber as a
  deliberate single-player resource). [14]
- **Jump**: decide whether airborne movement leaves a trail gap, keeps the trail, or lifts the trail
  into a 3D barrier. The third option creates real above/below play. [4]
- **Ramps and a second level**: trails only collide with racers in the same vertical band
  (`racerY` overlaps `bottomY...topY`). [5]
- **Trail as the weapon system**: Phase, Cut, Pulse, Breach, Overcharge, Fade, EMP, Fork, Ghost, Surge.
- **Trail decay before infinite trails**: finite trails force interaction and solve performance,
  congestion and pacing at once; fade from the oldest end. [15]
- **Collision as an event**: flash at 20 ms, camera kick at 50 ms, derez at 80 ms, fragments at 100 ms,
  trail pulse propagating backward at 300 ms, camera slow/orbit at 500 ms. Fake shards with particles,
  wireframe fragments and arcs rather than breaking the mesh. [3]
- **Grind + jump loop**: proximity -> risk -> energy -> speed -> jump/attack -> escape.
- **Zones**: capture areas that trails gradually wall in, creating traps without scripting. [16]

## Build order

1. TrailManager with 3D points and logical segments; swept collision; ignore the newest few self segments.
2. LowLevelMesh ribbon renderer with chunking.
3. Racer-versus-trail collision plus simple static arena boundaries.
4. Chase-camera springing, look-ahead, lean, speed FOV, subtle shake.
5. Grinding as the primary advanced mechanic.
6. Jump, then the trail-gap versus elevated-trail decision.
7. Finite/decaying trails and a few trail pickups.
8. AI last, using the spatial hash to test headings for open space.

```
GameWorld
├── RacerSystem
├── CameraSystem
├── TrailSystem (TrailMeshRenderer, TrailSpatialGrid, TrailCollision)
├── ArenaSystem
├── PickupSystem
└── GameState
```

Keep physics simple and deterministic; spend the complexity budget on speed, camera, glow, trail
behaviour, verticality and collision drama. Apple's guidance is to measure the 16.6 ms frame budget
and control mesh/draw-call complexity. [17]

## Sources

1. https://github.com/metal-by-example/metal-spatial-dynamic-mesh
2. https://developer.apple.com/documentation/RealityKit/LowLevelMesh
3. https://github.com/erichlof/3dLightCycles
4. https://github.com/MackinnonBuck/light-rider
5. https://github.com/andrewparlane/TronLightCycle
6. https://wiki.armagetronad.org/index.php/The_Basics
7. https://developer.apple.com/documentation/realitykit/shaperesource/generatestaticmesh(from:)
8. https://developer.apple.com/documentation/realitykit/reducing-cpu-utilization-in-your-realitykit-app
9. https://gamedev.stackexchange.com/questions/36011/how-to-implement-the-light-trails-for-a-tron-game
10. https://developer.apple.com/documentation/RealityKit/configuring-collision-in-realitykit
11. https://developer.apple.com/documentation/realitykit/shaperesource/generateconvex(from:)
12. https://developer.apple.com/documentation/realitykit/physicsmotioncomponent
13. https://wiki.armagetronad.net/index.php?title=Grinding
14. https://wiki.armagetronad.org/index.php/Rubber
15. https://wiki.armagetronad.org/?title=Building_Your_Skillset
16. https://wiki.armagetronad.org/index.php/PlayingGettingStarted
17. https://developer.apple.com/documentation/realitykit/improving-the-performance-of-a-realitykit-app
