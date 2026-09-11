# SpeederProto — RealityKit cyberpunk speeder graphics prototype

A Swift / RealityKit / Metal experiment answering the question in the build brief:
*can RealityKit produce a visually convincing cyberpunk speeder sequence?*
It runs natively on macOS and on iPhone (landscape) from one code base.

Model: "Cyberpunk Speeder" by Piotr Pisiak (Sketchfab, CC-BY-4.0), converted from GLB
to USDZ with Blender. Everything else (road, buildings, signage, sky) is generated
procedurally at launch, so there are no other asset dependencies.

## Build and run

The project file is generated with [xcodegen](https://github.com/yonaskolb/XcodeGen)
from `project.yml` (`SpeederProto.xcodeproj` is already generated and checked in).

On this Mac the Xcode 27 beta is missing the Metal toolchain, so build with the
stable Xcode 26.6:

```bash
cd "SpeederProto" && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project SpeederProto.xcodeproj -scheme SpeederProto-macOS -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

```bash
open "SpeederProto/build/Build/Products/Release/SpeederProto.app"
```

To push straight to a paired iPhone over Wi‑Fi without opening Xcode (device id from `xcrun devicectl list devices`):

```bash
cd "SpeederProto" && export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && xcodebuild -project SpeederProto.xcodeproj -scheme SpeederProto-iOS -configuration Debug -derivedDataPath build-device -destination 'platform=iOS,id=1438FC4B-510E-5302-9AAE-0833BC5A856F' -allowProvisioningUpdates build && xcrun devicectl device install app --device 1438FC4B-510E-5302-9AAE-0833BC5A856F build-device/Build/Products/Debug-iphoneos/SpeederProto.app && xcrun devicectl device process launch --device 1438FC4B-510E-5302-9AAE-0833BC5A856F com.markbailey.speeder.ios
```

Or open `SpeederProto.xcodeproj` in Xcode, choose the `SpeederProto-macOS` or
`SpeederProto-iOS` scheme and run. The iOS target has been verified in the
iPhone 16e simulator and on a physical iPhone (Sept 2026), where it rendered the same
as the Mac build with working touch steering and two-finger boost.

### Controls

| Input | Steer / climb | Boost | Fire | Cruise speed | Screenshot |
|---|---|---|---|---|---|
| Gamepad (Backbone, PS, Xbox) | left stick or d-pad | R2 or R1 | A, X or L2 | Y / B | – |
| macOS keyboard | ← → ↑ ↓ or WASD, or drag the mouse | Shift or Space | F or Return | ] / [ | P (PNG to Desktop) |
| iOS touch | position left/right and up/down | two fingers | – | HUD slider | – |

The vehicle climbs while you push up and settles back toward hover height when you let go.
Inside a conduit there is no floor pull: you fly anywhere in the cross-section.

The HUD (top right; on iPhone tap the gear, the top-right corner, or the controller's Menu button)
has one toggle per visual technique so each effect's contribution to look and frame time can be
judged in isolation. On iOS the RealityKit view does not take touches at all: SwiftUI owns them
(steering via `SpatialEventGesture`), which is what keeps the HUD controls interactive on top of it.

### Automation env vars

- `SPEEDER_DEMO=1` — scripted steering and a boost burst, no input needed.
- `SPEEDER_CAPTURE_DIR=<dir>` — saves the final post-processed frame at t = 4, 7, 10 s.
- `SPEEDER_SWEEP=1` (with capture dir) — one frame per disabled technique, plus `source.png`, the raw render before the post pass.

## What is in the scene

- **Moving world**: the speeder stays at z ≈ 0; eight 40 m road segments scroll toward the camera and wrap exactly (no drift). A separate far skyline layer scrolls at 0.22× for parallax.
- **Speeder**: USDZ loaded async, centred and rotated under a gameplay root; hover bob, banking, yaw, speed vibration; engine halo quads, hover-glow pool, cyan/magenta point lights, additive particle trail.
- **Corridor**: two rows of buildings with procedurally generated lit-window facades, rooftop masts with red beacons, facade neon strips, storefront strips, podiums, light posts, barriers with emissive tops, gantries with hologram signs, billboards (Core Text rendered) and vertical glyph strips.
- **Wet road**: dark albedo, generated normal map with flat puddles, roughness map (puddles ≈ 0.06), image-based lighting from a generated night-sky equirect with a coloured horizon band, plus fake reflection decals under every light.
- **Lighting**: one directional key, one rim, one camera-mounted fill spot, two vehicle point lights; everything else is emissive.
- **Post pass (Metal, via `ARView.renderCallbacks.postProcess`)**: bright pass → two-radius Gaussian bloom (MPS) → composite kernel doing depth fog, radial speed streaks, ACES grade with cool shadows, chromatic aberration, vignette.
- **Camera**: chase rig with lateral inertia, FOV that widens with speed, subtle vibration.

## Gameplay layer

The scroller now runs a scripted **track program** (`Scene/TrackProgram.swift`) instead of
a plain loop:

- **Curves**: each block gives its segment a lateral offset; segments are yawed to join, and the
  world slides so the road centre under the player stays at x = 0. Curves tug the vehicle toward
  the outside, so you steer into them; the camera looks into the bend.
- **Fork**: a split segment with a wedge building, cyan `<` / magenta `>` chevrons and a
  hologram sign. Your side of the road when the split passes picks the branch: left goes into
  an **undercity tunnel** (walls, ceiling, alternating light rings, glyph panels), right onto the
  **skyway** (open elevated deck, railings, light arches, floating billboards). Four segments later
  both merge back into downtown.
- **Obstacles**: pooled per segment — hazard blocks, energy gates (tunnel) and hover drones —
  laid out in 1–3 rows across the four lanes with at least two lanes always open. Hitting one
  costs 40 % of your speed, knocks the vehicle sideways, flashes the screen, sparks, and counts a hit.
- **Barriers**: the lane limit is ±6.9 m; pressing against it scrapes (sparks, slow speed bleed).
- **Handling**: velocity steering (hold to keep moving), banking/yaw from steer, recoil jolt on hits.
- **Altitude**: second axis (hover 1 m ... 5.6 m). Blocks are jumped, drones ducked under or shot, gates flown over or passed sideways.
- **Conduit**: a full cylinder section (radius 6 m) with light rings, running strips and panelled walls. Movement is clamped to the pipe, the vehicle rolls toward the wall it hugs, and obstacles become beams, pillars and half-hatches you thread in 2D.
- **Weapons**: pooled plasma bolts (A / F). Drones and blocks explode (particle burst, one transient light, shake); gates and tube structures just spark. Kills count on the HUD.
- **Haptics**: controller rumble (Core Haptics) on hits, kills and scrapes; phone taptics when no pad is connected.
- **Readability pass**: bloom threshold and intensity lowered, lane dashes and reflection pools dimmed, obstacles got taller with hazard stripes, a red strobe and a red pool on the road.
- **HUD** (bottom left): distance, hits, kills, altitude, current section name, chosen route, connected pad.

Toggle `obstacles` in the HUD to turn the hazards off and just drive.

### Look variants

The HUD's *Look variants* section switches between alternatives at runtime so they can be
compared in place: obstacle skin (solid hazard / hologram / neon wireframe), fog level, bloom
level, second building row, storefronts, bright windows, dense tunnel rings. The same presets
can be applied at launch with `SPEEDER_VARIANT=<name>` (see `applyVariantPreset` in
`GameController.swift`), which is how the comparison sweep in `Captures/variants/` was produced.

### Current defaults (chosen 7 Sep 2026 from the variant sweep)

Hologram barriers, thin fog, low bloom, dense city (second row + storefronts + bright windows),
reflection pools on, dense tunnel rings in a single red, obstacles in a lime hazard colour (sRGB 0.75, 1.0, 0.18: hologram panels, frames, gate bars, drone eyes, tube beam edges and their road pools all share it), and the *cyan/warm* palette: every
road-side light (lane edges, posts, barrier tops, gantries, split guides) is cyan, centre dashes are
pale blue-white, and every cityscape strip is drawn from a warm set (orange, magenta, yellow, red).
The idea is that each family of lights reads as one thing. `rings`, `palette` and `hazards` pickers in the HUD
switch these live (`rings-red`, `palette-amber`, `palette-mixed` presets for the sweep).

### Environments

`Scene/Theme.swift` holds everything that is not gameplay: key light, sky, materials family,
atmosphere and grade. The HUD's *world* picker rebuilds the scene for the selected theme
(`SPEEDER_VARIANT=canyon` at launch does the same).

- **Neon City (night)** — the frozen reference: cool moonlight, IBL from a generated night sky,
  lit-window towers, cyan road / warm city palette, red tunnel rings, lime hazards, reflection pools.
- **Sunset Canyon** — low warm sun straight ahead with 70 m shadows, a generated sunset sky with a
  visible sun disc, stepped sandstone mesas and boulders, dry asphalt with painted white edges and a
  yellow centre line (the palette's *painted* mode dims every "neon" to paint), tan dust motes instead
  of light streaks, a rock-cut tunnel with amber work lights, and a rusted pipe with dim seams for the
  conduit. Hazards stay lime so the language carries across worlds.

### Handling notes

- Altitude holds when the stick is released; it only drifts back down when already near the deck.
- In the conduit the clamp radius is 5.3 m and the wall roll is gentler than the first cut.
- The fork now diverges over 70 m (fork segment + first branch segment) with an eased curve and a
  V-shaped divider, and the road's sideways slide barely tugs the vehicle while inside the fork.

## Findings so far

- RealityKit gets convincingly close to the reference look with cheap tricks: emissive + bloom does most of the work, and the IBL reflection on a low-roughness road sells "wet" without real reflections.
- Debug build on an Apple Silicon Mac at 2560×1440 holds 50–60 fps with ~880 entities and the full post pass.
- Gotcha: `PhysicallyBasedMaterial.EmissiveColor(color:texture:)` *adds* the colour to the texture; pass `.black` when you want the texture alone.
- Gotcha: the iOS simulator returns NaN when the post pass reads the depth buffer (and logs RealityKit shader limit errors); the post pass probes for this and falls back to a screen-space fog estimate. A physical iPhone behaves like macOS (depth fog works there).

## Missions (the job loop)

The game direction is a **mission runner** (see `docs/game-direction.md`): every run is a job.
`Missions/Mission.swift` is the catalogue of eight jobs in four kinds, each with its own track
blocks, goal, time window and pay; `Missions/MissionRunner.swift` is the loop: briefing (vehicle
parked, the contact avatar beside it) -> running -> a result card with payout -> next job or
retry. A / F / tap accepts.

- **Delivery** (RELAY 01-04): reach the drop inside the window; cargo integrity loses 25 % per
  impact and an empty bar fails the run. Pay: base + 5 per second left + 2 per cargo percent.
- **Search** (SWEEP 01-02): fly through beacon rings placed along the track (`BeaconLayer`,
  some at altitude), N of M required by the end of the sweep. Pay adds 40 per beacon.
- **Escape** (RUN 01): a pursuer sits behind you at a gap shown on the HUD; it cruises 2 m/s
  faster than you, so boost (which now drains a meter and recharges) is how you keep it back.
  Under ~18 m it pulls alongside on the right with a red searchlight; at 4 m you are caught.
- **Duel** (DUEL 01): The Grid with a named rival; first to two derezzes. The briefing holds the
  arena; the arena's score decides the job.
Credits and the job index persist in UserDefaults (`SPEEDER_RESET_PROGRESS=1` clears them,
`SPEEDER_MISSION=<n>` picks a job). The mission decides the world, so job changes rebuild the
scene; the HUD toggle *missions (corridor)* turns the loop off for free play. The Grid is free
play for now (duels come later). The contact badge is a placeholder for the avatar portrait.

### Avatars

`Scene/AvatarActor.swift` loads a character USDZ, puts its feet at y = 0, faces a point and loops
the first animation clip. The first test asset is `Resources/Avatar.usdz`, converted from
`../kerb_skate_game/avatar.glb` (an Avaturn export: 54-bone Mixamo-named rig, one clip, 28
textures) with the same Blender USD export as the speeder (`export_animation`,
`export_armatures`, `export_textures_mode='NEW'`; a stray icosphere was dropped). It comes in
y-up at 1.88 m, faces +Z, and RealityKit plays the clip. During a mission briefing the contact
stands beside the parked bike. Character Creator 5 exports (GLB/FBX) go through the same script.

## The Grid (light-cycle arena, third world)

The third world is a different game, not a theme: `Scene/GameMode.swift` splits the app into
the scrolling **corridor** (Neon City, Sunset Canyon) and the free-movement **arena** (The Grid).
`Theme.theGrid.mode == .arena`, and the HUD `world` picker switches between them by rebuilding
the scene (`SPEEDER_VARIANT=grid`, `grid-snap`, `grid-gap` at launch). Everything under
`Sources/Arena/` is arena-only; the corridor code is untouched.

Research behind the design is in `docs/lightcycle-research.md`; the kickoff prompt that was used
is `docs/NEXT-THREAD-PROMPT.md`.

### What is in the arena

- **Arena** (`ArenaWorld`): a 220 m square with a glossy near-black floor (grid lines in the
  emissive map, IBL from a generated cyan-horizon environment for the reflection), four tall
  luminous panel walls with a rail and a base line, corner pylons, a far ring of dark data
  towers that recede into fog, four static **lime hazard walls** in the field, and two pickup
  props. ~180 entities.
- **Cycle** (`LightCycle`): kinematic and deterministic (speed, heading, position). Cruise 36 m/s,
  brake 15, boost 60 (uses the energy meter), plus a grinding surge. Visual lean, pitch and a
  damped visual heading sit on top; the logic never sees them.
- **Steering** (HUD `steering` picker): *analog* velocity steering with lean, or *snap 90*:
  flicking the stick past half travel makes an instant 90-degree corner (0.16 s cooldown). The
  snap also drives the AI. Both are captured in `Captures/grid/drive` and `Captures/grid/snap`.
- **Trails** (`TrailSystem`): the logical trail is a list of wall segments sampled every 1.2 m
  (about 26 % of the vehicle length) at the tail emitter, with a forced sample at each snap
  corner so corners are square. Segments live in a spatial hash (10 m cells) with stable
  global indices, so decay only moves a `firstAlive` cursor. Collision is a swept line from
  the previous nose to the current nose against the segments in the cells it touches, with a
  vertical band test; the newest few own segments are ignored. The same system answers
  "nearest wall" (grinding, edge) and "how far is it open in this direction" (AI).
- **Trail renderer** (`TrailRenderer`): one `LowLevelMesh` per 256-segment chunk, three parts
  per chunk (opaque core wall, translucent halo, floor reflection strip) and one provisional
  head segment that tracks the bike between samples. A custom surface shader
  (`trailSurface` in `Shaders.metal`) reads arc length from `uv0` and the material's custom
  parameter to draw the white-to-colour fade behind the bike, the fade from the oldest end and
  the crash pulse, so sealed chunks are never rewritten. Never one entity per segment.
- **Colour roles**: player trail cyan (white at the head), opponent trail orange, hazards lime
  (the same lime as the corridor obstacles), pickups violet-white.
- **Crash** (`ArenaController`): a hit is an event: white flash, camera kick, derez particle
  burst plus fourteen flung shards and a short light, a bright pulse travelling back along the
  trail, then a slow-motion orbit around the wreck for ~3 s and a restart with a READY beat.
  Hitting the boundary, a hazard, your own trail or the opponent's are all reported on the HUD.
- **Grinding**: riding parallel (within ~25 degrees) and close to any wall builds a speed surge
  (up to +20 m/s) and fills the **energy** meter that boost spends. Sparks and a flickering
  arc between bike and wall escalate with proximity.
- **Edge meter**: Armagetron-style rubber. Near-contact drains it; a shallow-angle hit with edge
  left deflects the bike along the wall (sparks, speed loss, a big drain) instead of killing it;
  it recharges slowly when clear. Empty edge, or a square hit, derezzes.
- **Jump** (stick up / climb axis): 12.5 m/s launch, apex 3.3 m, clears a 2.2 m trail or a 3 m
  hazard wall with correct timing. Rule chosen: **elevated trail** (the wall follows the arc,
  and a bike underneath only collides if the vertical bands overlap). The *trail gap* rule
  (no wall while airborne) is kept as a HUD option; both are captured in
  `Captures/grid/jumpback-over` and `jumpgap-over`.
- **Decay**: trails are finite (HUD `trail`: short 220 m, long 420 m, endless) and fade from
  the oldest end; dead chunks are released.
- **Pickups**: *Phase* (A / F to use: pass through one wall within 5 s, the bike flickers) and
  *Pulse* (erases the newest 60 m of your own trail with a pulse running back along it).
- **Opponent** (`ArenaAI`): every 0.16 s (0.08 s when boxed in) it probes candidate headings
  through the spatial hash with three parallel rays each, prefers straight, leans toward the
  player, adds a little noise, and boosts on open ground. It uses snap turns in snap mode.
  A derezzed opponent respawns after 4 s at the most open spot far from the player.

### Levels: the parking garage (added 10 Sep 2026)

`Arena/ArenaTerrain.swift` is a height field made of flat **decks** and inclined **ramps**;
`height(at:below:)` returns the highest surface no more than a step above the asker, so a bike
under a deck stays on the ground and a bike on the deck stays up. The cycles, the trail floor
strips, pickups and the camera all ask it. The current layout (`ArenaTerrain.garage`) is an
upper deck 9 m up over the north half of the arena, an on-ramp and an off-ramp (16 m wide,
40 m long) on its south edge, lime rails along every deck and ramp edge (registered as static
hazard segments, split so their vertical bands stay tight), support columns (also hazards) and
ceiling lamps underneath. Trails laid on the deck only collide with bikes on the deck, because
every wall segment already carries a vertical band. Driving off a rail-less edge drops you to
the level below with the normal airborne logic. Capture scripts: `ramp` (up, along, down) and
`garage` (under the deck); `SPEEDER_ARENA_CAMERA=side` gives a side elevation to check heights.

### Controls in the arena

| Input | Steer | Jump | Brake | Boost | Use pickup | Settings |
|---|---|---|---|---|---|---|
| Gamepad | left stick / d-pad (flick in snap mode) | stick up | stick down | R2 / R1 | A | Menu |
| Mac keyboard | ← → / A D | ↑ / W | ↓ / S | shift / space | F / return | – |
| iOS touch | left / right half | touch top | – | two fingers | – | top-right corner |

### Capture hooks (arena)

`SPEEDER_DEMO=1` runs a scripted drive chosen by `SPEEDER_DEMO_SCRIPT` (`drive`, `snap`,
`crash`, `grind`, `jump`, `jumpover`, `jumpback`, `pulse`, `phase`, `uturn`), plus
`SPEEDER_ARENA_START=x,z,heading`, `SPEEDER_ARENA_AI=0`, `SPEEDER_ARENA_GIVE=pulse|phase`,
`SPEEDER_ARENA_TRAIL=0|1|2` and `SPEEDER_ARENA_CAMERA=overview` (a fixed high camera that shows
the trail layout). Each folder under `Captures/grid/` was produced this way; the log lines print
position, height, grind, edge and energy so mechanics can be checked numerically as well.

### Performance

Debug build, Mac 2560x1440: 50-60 fps with two trails plus the post pass. iPhone 16e simulator:
60 fps with ~180 entities. The iPhone 12 needs measuring with the HUD fps counter on a long run;
the trail meshes are cheap (one draw per chunk part) and the main cost is still the post pass.

## Next steps (brief milestones 7–8)

1. Measure fps and thermals on the phone over a longer run (the HUD shows fps).
2. Tune boost strength / bloom threshold / exposure for the phone's display.
3. Optional: obstacle proxies, a rain particle layer, more sign art.
