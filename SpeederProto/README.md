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

To push straight to a paired iPhone over Wi‑Fi without opening Xcode (device id from `xcrun devicectl list devices`).
The phone gets a **Release** build: the procedural textures are Swift pixel loops, and Debug took
four times as long to load (the iPhone 12 is ready 3.9 s after launch in Release):

```bash
cd "SpeederProto" && export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && xcodebuild -project SpeederProto.xcodeproj -scheme SpeederProto-iOS -configuration Release -derivedDataPath build-device -destination 'platform=iOS,id=1438FC4B-510E-5302-9AAE-0833BC5A856F' -allowProvisioningUpdates build && xcrun devicectl device install app --device 1438FC4B-510E-5302-9AAE-0833BC5A856F build-device/Build/Products/Release-iphoneos/SpeederProto.app && xcrun devicectl device process launch --device 1438FC4B-510E-5302-9AAE-0833BC5A856F com.markbailey.speeder.ios
```

`--console` on the launch streams the app's stdout (the `load:` lines give the build stages).

Or open `SpeederProto.xcodeproj` in Xcode, choose the `SpeederProto-macOS` or
`SpeederProto-iOS` scheme and run. The iOS target has been verified in the
iPhone 16e simulator and on a physical iPhone (Sept 2026), where it rendered the same
as the Mac build with working touch steering and two-finger boost.

### Controls

| Input | Steer / climb | Boost | Fire | Cruise speed | Screenshot |
|---|---|---|---|---|---|
| Gamepad (Backbone, PS, Xbox) | left stick or d-pad | R2 or R1 | A, X or L2 | Y / B | – |
| macOS keyboard | ← → ↑ ↓ or WASD, or drag the mouse | Shift or Space | F or Return | ] / [ | P (PNG to Desktop) |
| iOS touch | position left/right and up/down | two fingers | quick tap | – | – |

The vehicle climbs while you push up and settles back toward hover height when you let go.
Inside a conduit there is no floor pull: you fly anywhere in the cross-section.

Pause: the pad's Menu button, Escape, or the pause button top right. Menus (see "Front end"
below): stick / d-pad / arrows move, left / right change a value, A / Return select, B / Escape back.

The developer panel (one toggle per visual technique, the look variants, the world picker, fps) is
hidden from players: five taps on the version line in SETTINGS unlock it on a phone (the Mac has it
unlocked), then it is a row in SETTINGS and the pause menu, and ` toggles it from a keyboard.
`SPEEDER_PANEL=1` opens it at launch. On iOS the RealityKit view does not take touches at all:
SwiftUI owns them (steering via `SpatialEventGesture`), which is what keeps the HUD interactive.

### Automation env vars

- `SPEEDER_DEMO=1` — scripted steering and a boost burst, no input needed. The demo starts in the
  game (no splash, no title); `SPEEDER_TITLE=1` keeps the front end, `SPEEDER_TITLE=0` skips it outside
  the demo, `SPEEDER_SCREEN=title|worlds|settings|rider|paused|game` opens that screen once the world is
  built (rider opens as the first run).
- `SPEEDER_CAPTURE_DIR=<dir>` — saves the final post-processed frame at t = 4, 7, 10 s
  (`SPEEDER_CAPTURE_TIMES=3.5,4,9` overrides; decimals allowed). Scene time starts once the
  world is built, about 8 s of wall-clock after launch, and the app does not quit by itself:
  `Captures/polish/capture.sh <dir> <seconds> ENV=VAL ...` runs and kills it.
- `SPEEDER_CAMERA=overview` — high camera behind the vehicle (corridor layout captures).
- `SPEEDER_SWEEP=1` (with capture dir) — one frame per disabled technique, plus `source.png`, the raw render before the post pass.
- `SPEEDER_MISSION=<n>` also marks the jobs before `n` as cleared (the inbox lists the chain and
  the loop continues from `n`); `SPEEDER_RESET_PROGRESS=1` first for a clean slate.
- In demo mode the accept button pulses (0.5 s on, 1 s off) so cards are accepted on their edge;
  `SPEEDER_HOLD_BRIEFING=1` / `SPEEDER_HOLD_RESULT=1` keep a card up for screenshots.
- Simulator HUD screenshots: `Captures/polish/simshot.sh <outprefix> "<delays>" ENV=VAL ...`
  launches the installed simulator build with `SIMCTL_CHILD_` env vars and screenshots at each
  delay from launch. The simulator runs slower than wall clock (about 25 m of track per second,
  scene time starts ~14 s after launch); take several delays.

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
`Missions/Mission.swift` is the catalogue of nine jobs in four kinds, each with its own track
blocks, goal, time window and pay; `Missions/MissionRunner.swift` is the loop: briefing (vehicle
parked, the contact avatar beside it) -> running -> a result card with payout -> next job or
retry. A / F / tap accepts.

- **Delivery** (RELAY 01-04): reach the drop inside the window; the hull bar loses 25 % per
  impact and an empty bar fails the run. Pay: base + 5 per second left + 2 per hull percent.
- **Search** (SWEEP 01-02): fly through beacon rings placed along the track (`BeaconLayer`,
  some at altitude), N of M required by the end of the sweep. Pay adds 40 per beacon.
- **Escape** (RUN 01): a pursuer sits behind you at a gap shown on the HUD; it cruises 2 m/s
  faster than you, so boost (which burns the hull bar) is how you keep it back.
  Under ~18 m it pulls alongside on the right with a red searchlight; at 4 m you are caught.
- **Duel** (DUEL 01 vs KADE, DUEL 02 vs ORIN): The Grid with a named rival whose temper is on the
  card; first to two derezzes. The briefing holds the arena; the arena's score decides the job.
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
| iOS touch | left / right half | touch top | – | two fingers | quick tap | gear |

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

## Polish pass (11 Sep 2026)

`docs/polish-log.md` lists every rough edge that was fixed, with the capture that shows it;
`docs/research-comparables.md` is the merged comparable-games research with a ranked shortlist
of what to build next. The pieces the code now has:

- **Eased section transitions**: `WorldScroller.tubeBlend` (24 m lead) mixes the flat lane/altitude
  clamp with the conduit cylinder so nothing snaps at the pipe mouth; `enclosure` (20 m lead)
  darkens and thickens the post-pass fog and tightens the vignette inside the tunnel and conduit;
  every enclosed section has an entry and an exit portal frame (`RoadSegment.buildPortals`,
  enabled by `setNeighbours`).
- **Soft fork**: the branch is chosen from the player's side 30 m before the split, the road's
  divergence ramps over 24 m of travel (`forkBlend`, re-placing the fork and downstream segments
  each frame), and the side locks when the split passes. The V divider is a scraping wall past the
  nose (`wedgeLimit`), the fork's building rows stand 1.7x further out, and the branches diverge
  7 m + 3 m.
- **One camera rig**: corridor chase and arena spring share roll gain/damping, FOV widening and
  the shake formula (`CameraRig`); `punch()` is the boost/launch kick (150 ms in, 400 ms out,
  +9 deg FOV, camera pull-back, extra streaks) used by both modes.
- **Vehicle**: the collision jolt starts from zero and rolls with the push, the camera follows
  the smooth bank plus 40 % of the jolt, 70 ms hit-stop on obstacle hits, speed-scaled hover bob,
  idle sway, idling exhaust and no speed motes while parked.
- **Same-frame acknowledgement**: `GameController.ack` (`ActionAck`) drives the HUD's pip row
  (BOOST / FIRE, BOOST / JUMP / SNAP / PICKUP) and centre stamps (CONDUIT, UNDERCITY, SKYWAY,
  SPLIT, GO, PHASE, PULSE, HIT, BEACON +1); every action also rumbles on the frame it happens.
- **Curtain**: scene rebuilds (job change, world picker) run behind a fade to black in the post
  pass (`PostProcessor.curtain`); the contact avatar faces the camera during briefings.
- **HUD**: one panel style (`hudPanel()`), one meter, `HUDStyle` sizes for the phone (11 pt
  base), diagnostics only with the settings panel on iOS.
- Capture aids: `Captures/polish/capture.sh <dir> <seconds> ENV=...`, `SPEEDER_CAMERA=overview`
  for a high corridor camera, `SIMCTL_CHILD_*` env vars for simulator HUD screenshots.

## Hull energy and arena rounds (13 Sep 2026)

- **One bar for the corridor jobs**: `MissionRunner.energy` is hull and boost fuel at once. Hits
  cost 25 %, scraping 8 %/s, boost 12 %/s; it trickles back at 3.5 %/s, beacons give 20 % and
  kills 5 %. Empty means `HULL BREACHED`; what is left at the drop pays 2 credits per percent on
  every kind. The strip shows `HULL` for every job; the escape kind no longer has its own boost
  meter and deliveries no longer track cargo separately.
- **The Grid** now plays in rounds with a match (see `docs/arena-next.md`): a rival derez is a
  freeze-cam with a stamp, a match is first to three in free play, derez explosions breach
  nearby trails, six floor pads (four boost, two slow) sit on open ground, grinding between two
  walls surges harder and leaving a grind gives a kick, and an orange beam marks a distant rival.

## Rival, match card, accel curve, deck, streak ranks (13 Sep 2026, second pass)

- **A rival with a face and a temper** (`Arena/Rival.swift`): KADE (hunter: shadows you and grinds
  your trail, takes the ramp after you), ORIN (boxer: cuts across your line), SABLE (runner: open
  ground and the pads). A name tag billboard over the rival and portrait badges on the briefing
  card come from the sign pipeline (Core Text to texture). Duels name the rival and its temper;
  free play meets the roster in turn. `DUEL 02 // ORIN` is job 9.
- **Match result card** after MATCH WON / LOST in free play: rounds, best grind, longest trail,
  energy left, credits into the same purse as the jobs; A / F / tap starts the next match.
- **Armagetron acceleration curve**: grinding is a continuous `22 / (1.2 + d)` acceleration against
  the nearest wall (x1.5 in a tunnel), boost a burst to 68 m/s that decays to base at 0.3/s, every
  quarter turn costs 5 %, pads and the break-away kick are impulses. Ceiling 96 m/s. The rival rides
  the same curve with a 54 m/s burst and its own energy budget. Tune on the phone: `LightCycle`
  `boostAccel`, `decayAbove`, `turnTax`; `ArenaController.grindGain / grindOffset / grindNear`.
- **The deck has a purpose**: four boost pads along its north edge and the CHARGE pickup (amber)
  that only spawns up there (full energy plus a burst on contact).
- **Streak scoring for the corridor jobs**: gates every 200 m, beacons and kills are worth base x
  streak (to x8), a hit resets it; rank bronze / silver / gold from per-job thresholds (40 % / 70 %
  of the job's maximum), remembered per job and shown on the briefing and result cards.
- **Checkpoint respawn**: two per job; a breached hull restores to 50 % in place with a 4 s penalty.
- **Sumo zone**: 25 s into an arena round a ring appears and shrinks over 20 s; inside charges energy,
  outside drains it and an empty bar derezzes (rival included). The AI heads for the zone.

Capture hooks: `SPEEDER_ARENA_RIVAL=<name>`, `SPEEDER_HOLD_RESULT=1`, `SPEEDER_DEMO_BOOST=always`,
`SPEEDER_ARENA_ZONE_AT=<s>`, `SPEEDER_ARENA_KILL_RIVAL=<run s>` (force-derez the rival each round,
wins a mission duel for the demo), `SPEEDER_ARENA_IMMORTAL=1` (the player drives through walls, for
watching the rival over a whole run).
Captures: `Captures/polish/p5/`, `Captures/polish/p6/` (18 Sep verification).

## Assessment pass (18 Sep 2026)

`docs/assessment-2026-09-18.md` is the mechanics / UI / sequencing / code assessment (six agent
reports merged; round-2 research appended to `docs/research-comparables.md`). What it changed
(built and verified on the Mac and the simulator later the same day; `docs/polish-log.md`, third
pass, and `Captures/polish/p6/`):

- **Full-length tracks**: `TrackComposer` (in `Scene/TrackProgram.swift`) composes every corridor
  job from phrases (straight, bend, S-bend, obstacle field, split, conduit, undercity, skyway,
  landmark) over the whole distance, seeded per job, keeping the road centred. Before, a job
  authored 8-14 blocks and repeated its last one for the remaining 85 %. Two new landmark
  dressings on city blocks (`TrackBlock.dressing`): an **overpass** (deck on piers, lit
  underneath, a hologram hanging from it; a rock arch in the canyon) and a **gateway** (twin
  pylons, lit crossbar, glyph panels). `.tunnel` and `.elevated` blocks now appear directly in
  mission tracks, not only behind a fork.
- **Sound** (`Sources/Audio/SoundEngine.swift`): everything synthesised at launch, no assets.
  Cues on the same frame as the pips and haptics (accept, GO, hit, fire, kill, beacon, gate with
  pitch by streak, section entry, approach, respawn, success, fail, last-five-seconds ticks,
  snap, jump, land, derez, pickups, surge, zone, round and match beats) and five loops (engine
  by speed, boost, grind, scrape, alarm for low hull / closing pursuer / low edge). HUD `sound`
  toggle; `SPEEDER_SOUND=0` or `SPEEDER_DEMO=1` keeps captures silent (`SPEEDER_SOUND=1` to hear a demo).
- **HUD**: km/h in the corridor block; HULL / ENERGY / EDGE in three states (accent, amber under
  50 %, red under 25 %) with a breathing low state; the timer goes amber under 20 s, red under
  10 s and pulses with a tick under 5 s; the escape kind shows a GAP bar; a "CONDUIT IN 84 m"
  chip from 140 m before a section change; pickups say what they do; three **flags** per job
  (CLEAN, FAST, GOLD) on the briefing and result cards, remembered per job; the controls hint
  shows for the first 30 s and with the settings panel; cards no longer block the gear.
- **Input**: a quick still **tap fires** (corridor), uses the pickup (arena) and accepts cards;
  an idle pad no longer disables touch and keyboard; the phone's idle timer is off.
- **Logic fixes**: a theme change from The Grid now rebuilds (the loop dead-ended after every
  duel); boost has hysteresis at an empty hull; cruise is locked during a live job;
  `SPEEDER_RESET_PROGRESS` clears ranks and flags; payouts are banked with the job index; a
  respawn in the last 4 s no longer stamps on a failed run; search score ceilings count beacons
  at the capped streak. Arena: PHASE survives picking up another item, the break-away kick needs
  a real grind, grinds pay less energy while boosting, the rival's ceiling is 62 m/s, a player
  cannot derez twice in one frame, free play gets its match target back after a duel.

## The game (18 Sep 2026, second pass): an arc, an inbox, a garage, a sharper rival, music

Built on the assessment pass (verified with the assessment pass; see the third-pass section of
`docs/polish-log.md`):

- **Three chapters, eighteen jobs** (`Missions/Mission.swift`): DOWNTOWN with VESS (five corridor
  jobs and the duel with KADE), OUTLANDS with KADE as the contact (the canyon, a salvage run, a
  dive, the duel with ORIN), THE CORE with ORIN (VESS has been selling the packets to SABLE; an
  escape from the first metre, a twelve-target salvage, the deep-line dive, the ledger sweep, the
  duel with SABLE to three and the last duel with VESS on a cycle). Every job has a `debrief`,
  the contact's line on the result card, which is how the story is told. Two new kinds:
  **salvage** (destroy N targets before the drop; `TARGETS k/N` on the strip) and **dive** (no
  weapons, hull bruises twice as hard, precision pays twice). Chapter density scales the
  obstacle rows 0.8 / 1.0 / 1.3.
- **Inbox**: the briefing card lists every unlocked job as a chip (cleared ones ticked); stick
  left / right or a tap browses, A loads the chosen job (the world rebuilds) and A again launches.
  Jobs unlock in order; cleared jobs can be replayed for flags and gold at half pay.
- **Garage**: four upgrades bought with credits on the briefing card (stick up / down highlights,
  Y / `]` / tap buys): HULL PLATING I/II (hits cost 20 / 16 %), BOOST COIL I/II (boost burns 9 /
  7 %/s), SPARE CORE (+1 respawn), HELMET (the first hit of every job is free, with a HELMET
  stamp). Persisted as one integer (`upgrades`); `SPEEDER_RESET_PROGRESS` clears it.
- **Time as a resource**: every 200 m gate adds 1.5 s to the window (`+50 x3  +1.5 s`), so a
  clean fast run keeps buying time; the windows were tightened by about 6 %.
- **One-tap retry**: A on the failed card rebuilds the job and launches it as the curtain opens.
- **The rival** (`Arena/ArenaAI.swift`, `Arena/TrailSystem.swift`): a 6 m occupancy grid of
  every live wall and a flood fill from one tick ahead give each candidate heading a
  reachable-space term, and a pocket is rejected outright; a loop guard penalises a fourth turn
  the same way unless the inside is the bigger space; **skill tiers** on `Rival.skill` set the
  tick (0.30 / 0.16 / 0.10 s), probe range, noise and a blink chance, never speed: KADE is STEADY,
  ORIN SHARP, SABLE and VESS KEEN. A **double derez is a void round** (no score either way).
- **Music** (`Audio/SoundEngine.swift`): three generative layers per world (pad, bass, arp) at
  112 bpm over four bars, rendered at launch from a chord progression per world (Am F C G neon,
  Dm F C Am canyon, Em C D Bm grid); the pad plays under the cards, the bass on the run, the
  arp when it gets hot (boost, streak x4, a close pursuer, a grind, the zone). HUD `music` toggle.

## Market assessment (26 Sep 2026)

`docs/assessment-2026-09-26-market.md` compares the game with contemporary futuristic racers and
short-session mobile games (Asphalt, Redout 2, Wipeout, Fast RMX, Distance, Horizon Chase 2, Thumper,
Sayonara Wild Hearts, Tron: Ares / Catalyst, Hades, Ridge Racer Type 4, F-Zero 99 and others), lists the
gaps by layer and ranks the fixes in four workstreams: the viewing space (layered horizon, edge cadence,
vehicle contact, brand typography, rain, hot Grid trails), the post pass (one boost scalar, depth +
velocity prologue, outer-ring blur, lens dirt, LUT, MSAA via RealityView), HUD and screens (display face,
no boxes, controller glyphs, motion language, title screen, briefing and result redesign) and the cast /
story / sound layer (reactive debrief lines, callsign and livery, rival cards, Character Creator 5 +
iClone 8 characters, comms stamps, a bar-quantised music state machine, ambience beds, continuous
haptics, Game Center). The full research reports are in `docs/research-2026-09-26-reports.md`.

## Pass 1 of the assessment: presentation foundation (26 Sep 2026)

Built and capture-verified the same day (`docs/polish-log.md`, `Captures/polish/p7/`): the HUD type
system (Chakra Petch, bundled under the SIL OFL in `Resources/Fonts`), the box-free HUD layout by zone
with the world's road colour as the accent, controller glyphs from the pad (`sfSymbolsName`) and touch
BOOST / FIRE buttons with press states, one boost scalar driving the post pass (vignette, centre-weighted
grade, streaks, aberration, thruster heat haze), the exhaust and the HUD, a contact shadow and throttle
ground glow under the bike, edge studs and road chevrons, the rider's identity (`Missions/Player.swift`:
callsign, livery, rank title; tap the name or the swatch on the briefing), contact comms lines in the
run (`Mission.comms`), and a haptics director with a continuous engine hum that falls back to the
phone's own haptics for pads without rumble.

## Pass 2 of the assessment: the world (26 Sep 2026)

Stars and a moon in the night sky, a theme-aware two-ring parallax skyline with brand mega-signs
(mesas in the canyon), screen-space rain with lightning in Neon City, a post pass that computes linear
depth once and adds reprojection motion blur in the outer ring (never on the bike), ghost flares, lens
dirt and dither, hot translucent trail walls on The Grid and a dissolve derez on the cycles
(`dissolveSurface`). Log and captures: `docs/polish-log.md` pass 2, `Captures/polish/p7/`.

## Pass 3 of the assessment, code half: the cast on screen (26 Sep 2026)

A title screen, a rival card before every duel (record, temper, tier, a taunt from the record), a
staged result card with a reactive debrief line per contact (`Missions/Debrief.swift`, Hades' rule:
essential beat, then a line that saw what you did, never repeated until the rest are spent), failed
cards with a cause line, and a two-column briefing with the contact and the rival. Head-to-head records
persist (`record.<rival>`). The cast itself (Character Creator 5 / iClone 8) is the owed half: see
`docs/research-2026-09-26-reports.md`, report E, for the pipeline and the first proof.

## Pass 4 of the assessment, audio half (26 Sep 2026)

A music state machine on the synthesised stems: a drum layer that enters while boosting, on a streak or
when leading a duel, the arp held back until the first gate, a tempo-and-pitch lift in the final
stretch, a one-bar duck and slam on the finish, a detuned cut on a fail or a derez, every change on a
bar line. Per-world ambience beds (hum and rain, wind, a pure tone) and a reverb on the vehicle's own
sounds that opens in tunnels and the conduit. Not built from pass 4: the RealityView migration,
building batching, Game Center.

## Front end: splash, title menu, settings, rider, pause (26 Sep 2026)

- **Splash.** The iOS launch screen (`UILaunchScreen`: `LaunchBackground` colour and the `LaunchLogo`
  wordmark from `Resources/Assets.xcassets`) hands over to a SwiftUI splash with the same image, so the
  switch is invisible; a loader under it (`LoaderLine`, Core Animation, so it keeps moving while the
  main thread builds the world) runs through three stages (SURFACES, VEHICLE, the world's name), each
  animated over the time it took on the last launch (`load.<theme>.<stage>` in UserDefaults). When the
  world is up, the wordmark flies to its place low-left as the curtain opens. START cannot be pressed
  before the world exists (it could before: a tap during the load put the briefing over black).
- **App icon.** A neon road into a night skyline under a magenta horizon, the wordmark's S above it.
  `swift Tools/render-brand.swift` (from `SpeederProto/`) re-renders the icon (iOS + macOS sizes), the
  launch wordmark and the launch colour with Chakra Petch.
- **Title menu.** CONTINUE (START with no progress; the next job under it), FREE PLAY (Neon City,
  Sunset Canyon or The Grid, no job, the endless track or a match to three), SETTINGS. The callsign line
  opens the rider screen. The camera drifts slowly behind the parked bike (`CameraRig.update(title:)`,
  blended in and out), the arena orbits; the music is pad and bass.
- **Settings** (persisted as `prefs.*`, `Scene/FrontEnd.swift` `PlayerPrefs`): MUSIC and EFFECTS
  levels (0 to 10, the music mixer and every cue and loop), HAPTICS, GRAPHICS (HIGH; BALANCED drops
  motion blur and lens FX; BATTERY also drops rain, reflections and storefronts), GRID STEERING (smooth
  or snap 90), RIDER, RESET PROGRESS (press twice; keeps callsign and livery), the developer panel once
  unlocked. The demo never applies them, so captures keep the reference look.
- **Rider / first run.** The first START on a device asks WHO'S RIDING? before the first briefing:
  callsign (a tap opens the keyboard; on a pad A edits in place, up / down change the letter, left /
  right move) and livery swatches (the bike re-tints live); RIDE goes on to the briefing.
- **Pause.** RESUME, SETTINGS, QUIT TO TITLE (a live job goes back to its briefing, the world rebuilds
  from its start), the developer panel once unlocked. The simulation holds and the loops fall silent.
- One list model drives everything: `GameController.screens` (a stack), `menuRows`, `menuIndex`,
  `activate` / `adjust` / `setValue`; the frame loop feeds pad and keys (`frontEndInput`, auto-repeat on
  a held direction), the views feed taps (`Views/FrontEndView.swift`).

## Story pass: the spine, the message log, chapter cards, the rival's voice (27 Sep 2026)

`docs/assessment-2026-09-27-story.md` assessed the narrative (the game had the delivery devices and no
spine) against twenty-three narrative-driven vehicle games; this pass built its sections 5.1 to 5.4
(`docs/polish-log.md`, story pass; `Captures/polish/p9/`).

- **The spine.** Every program rides a route: its name, its right to ride. The player's is provisional
  and VESS holds the licence. The packets are riders' routes; SABLE buys them and derezzes the rider;
  the last packet of chapter 1 carried the player's own, and the ledger's last line is the player's.
  Told in the same briefs and debriefs (`Mission.deliveries`), about a dozen lines rewritten. The ending
  is real: the title ROUTE-HOLDER once every job is cleared, a last message from KADE, and VESS in the
  free-play roster (`Rival.freePlayRoster`).
- **The message log** (`Missions/MessageLog.swift`): every brief and debrief kept as a message from its
  contact, the game's notices (a job unlocked, a part fitted, a chapter opened) and the unseen sender
  `??`, one static line per chapter that the reveal resolves. MESSAGES on the title and the pause menu,
  the envelope chip on the briefing; unread counts; `SPEEDER_SCREEN=messages`.
- **Chapter cards** (`MissionState.Phase.chapter`): once, before the first briefing of each chapter:
  the district, a forty-word paragraph, the cast's standing (unknowns blurred), the rider's callsign,
  title and purse. `SPEEDER_CHAPTER_CARDS=0` skips them for captures.
- **The rival's voice** (`Debrief.rivalLine`): one comms line per round at most, in the rival's colour,
  from the round's outcome, the lead, match point and the record at match start; shown 2.4 s after the
  derez once the attribution has cleared. The intro taunt gains a third-meeting tier.

## Headless tests, balance, agency (27 Sep 2026, evening)

Branch `claude/phone-pass` (`docs/polish-log.md`, last section; `Captures/polish/p10/`).

- **Tests** (`Tests/MissionLoopTests.swift`, target `SpeederProtoTests`, hosted by the Mac app with
  `SPEEDER_TESTS=1` so no world is built): a 60 Hz headless loop over `MissionRunner` with the game's
  speed model and a `Rider` profile (cruise, hits, boost, beacons, targets, the split). Fourteen tests
  cover the boost hysteresis, the accept edge, gate time, replay pay, salvage and sweep failure, the
  dive bruise, the helmet, the inbox and garage, the unlock order, the save migration, the side offers
  and the balance table. Run:

  ```bash
  cd SpeederProto && export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && xcodebuild test -project SpeederProto.xcodeproj -scheme SpeederProto-macOS -configuration Debug -derivedDataPath build-tests CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|Test Case.*(passed|failed)|Executed|credits per"
  ```
- **Balance** from that loop: windows are the net cruise time (distance at 45 m/s less the gate refunds)
  plus 30 % (RELAY 01 66 -> 50 s, DIVE 01 62 -> 50 s, every job in the log's table), so plain cruise
  keeps a quarter of the window and FAST needs boost; the purse takes score / 20 (was / 5) and 3 per
  second left (was 5); salvage targets count in the gold ceiling; the garage doubled (HULL 1,200 /
  2,400, BOOST 1,000 / 2,000, SPARE CORE 1,800, HELMET 1,400) against a clean chapter of about 5,700
  credits. A clean run is gold, a sloppy one bronze, a reckless dive fails.
- **Agency** (assessment 5.5): cleared jobs are a bitmask, so the first job of a chapter opens the next
  two, each further job needs one more cleared, the duel waits for all, and the runner moves to the next
  open job. Three **side offers** (`SideOffer`, `Mission.offers`) sit after the jobs as amber chips once
  their flag is earned: KADE's tunnel line (CLEAN on RELAY 02: the split through the tunnel, +150),
  ORIN's dark pipe (FAST on RUN 02: DIVE 01 with ten seconds less, +300), SABLE's whole ledger (GOLD on
  SALVAGE 02: every beacon of SWEEP 03, +500); the sender briefs it, the bonus pays once, the rule can
  fail the run (`TOOK THE SKYWAY`). The contact acknowledges the **fork** on the result card
  ("The tunnel. Kade saw that."). `SPEEDER_FLAGS=2:1` puts an offer on the table for a capture.

## Generated art (28 Sep 2026)

`docs/art-brief.md` is the brief for AI-generated environment images (palettes per world with hex
values, one paste-ready prompt per asset). The first batch is prepared into `Resources/Art/` and
loaded by `Rendering/ArtLibrary.swift`: generated facade tiles join the facade pool (albedo + emissive),
billboards join the sign pool, storefront quads sit at street level, a skyline strip stands 620 m out
behind the rings, and The Grid gets a stadium bowl and a hanging screen. `SPEEDER_ART=0` keeps every
image out (the A/B baseline); a missing file keeps the procedural look. `Theme.fogMax` caps the depth
fog per world so a backdrop survives it (`docs/polish-log.md`, "Generated art").

## Street polish (28 Sep 2026)

From the reference render: The Grid's accent is a palette (`gridPalette`: cyan, red, amber, violet; a duel
takes the rival's), the rain falls (it climbed), rain comes in showers and closes the streets in chapter 3
(`SPEEDER_RAIN=always|showers|heavy|0`), the street has black asphalt aprons with the buildings set further
back, and bends open onto **crossroads**: a cross street through the towers, chevron barricades, and a red
arrow gantry pointing the way (`docs/polish-log.md`, "Street polish").

## KERB: GALACTIC (1 Oct 2026)

The game is titled **KERB: GALACTIC**, the companion to KERB (the skate game in `../kerb_skate_game`): the same
Griptap & Co shop, the same four riders, the second trip through the cabinet. First run: title -> RIDERS
(profile cards, live handling bars on the hoverboard) -> STORY (Mark's four shop panels as a motion comic;
replay from SETTINGS) -> CALLSIGN -> the first briefing. `SPEEDER_SCREEN=story|riders`, `SPEEDER_STORYBEAT=<n>`,
`SPEEDER_RIDER=cal|dude1|dude2|girl1`. Product name and bundle id stay `SpeederProto`. Details:
`docs/polish-log.md` "KERB: GALACTIC".

## The hoverboard (alternative vehicle, 29 Sep 2026, test build)

SETTINGS > VEHICLE: SPEEDER / HOVERBOARD (or `SPEEDER_VEHICLE=board`) swaps the speeder for KERB's
skateboard with a Character Creator rider standing on it (`Resources/Board.usdz`, `Resources/Rider.usdz`,
copied from `../kerb_skate_game`). Same steering, altitude, conduit, collisions and effects; the wheels are
hidden and the trucks glow as hover pods; the rider is posed procedurally every frame by
`Scene/RiderRig.swift` (surf stance, deeper crouch with speed and boost, leans into turns and down the nose).
Board and rider are 1.35x for the phone. Tricks: pad X = 360, pad Y = barrel roll (keyboard Z / C); the
rider tucks and a stamp names the trick. Fire is also on L1 with a shooting arm. `SPEEDER_TRICK_AT=4:spin,7:roll`
forces tricks for captures. The speeder path is unchanged. `SPEEDER_CAMERA=side` is the pose-check camera. Details and captures:
`docs/polish-log.md` "The hoverboard", `Captures/polish/p13/`.

## Next steps (brief milestones 7–8)

1. Measure fps and thermals on the phone over a longer run (the HUD shows fps).
2. Tune boost strength / bloom threshold / exposure for the phone's display.
3. Optional: obstacle proxies, a rain particle layer, more sign art.
