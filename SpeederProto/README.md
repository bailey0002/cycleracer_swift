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

## Next: third world (light-cycle arena)

Research and the kickoff prompt for the next thread are in `docs/lightcycle-research.md` and
`docs/NEXT-THREAD-PROMPT.md`. Workspace-level notes for Claude are in `../CLAUDE.md`.

## Next steps (brief milestones 7–8)

1. Measure fps and thermals on the phone over a longer run (the HUD shows fps).
2. Tune boost strength / bloom threshold / exposure for the phone's display.
3. Optional: obstacle proxies, a rain particle layer, more sign art.
