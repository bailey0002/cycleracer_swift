# Market assessment: lifting SpeederProto to contemporary quality (26 Sep 2026)

Written after six parallel research streams (codebase inventory, viewing space, characters /
story / sound, HUD and screens, RealityKit / Metal architecture, Character Creator 5 / iClone 8
pipeline). The full reports with sources are in `research-2026-09-26-reports.md`; this
document is the synthesis: where the game stands, what the comparables do, the gaps, a ranked
set of recommendations and a build order. Nothing here was implemented in the thread that
produced it. The earlier mechanics-focused research (11 Sep 2026) is in
`research-comparables.md`; this pass is about look, presentation and the non-action layers.

## 1. The question

The brief: make the current design match the graphics, aesthetics and features of
contemporary futuristic games, and turn it into an end-to-end entertainment experience where
characters, story, soundscape and the other non-action elements are woven in, not bolted on.

## 2. Where the game stands

The engine is further along than a first frame suggests. Measured against the corpus, it
already has most of the mechanical and feel layers a premium arcade racer needs:

- A run engine with speed, boost, altitude, hazards, weapons, a route choice, three worlds
  swapped by one rebuild, composed full-length tracks, section transitions as blends.
- A post pass (depth fog with horizon glow, bloom, radial streaks from the vanishing point,
  ACES grade, chromatic aberration, vignette, collision flash, curtain) that already keys
  several effects to one boost scalar (camera kick drives FOV, dolly, streaks and aberration).
- Feel rules from the first research pass: hit-stop, noise-driven shake, same-frame action
  acknowledgement, haptics per action, stamps, freeze-cam, crash orbit.
- A mission frame with three chapters and eighteen jobs, a one-line debrief per job, an
  inbox, a garage, ranks, flags, streak scoring, checkpoint respawn, named rivals with tempers
  and skill tiers, and a synthesised sound and music layer with three stems per world.

What says "prototype" at a glance is narrower than the whole game, and it is the same three
things in every capture:

1. **The frame is under-dressed at the edges and empty above the horizon.** All buildings,
   mesas, towers and decks are boxes; signs, halos and pads are flat quads; the sky is a
   painted haze band with 22 box towers; there is no vehicle shadow, no weather, no far
   layer, no in-world brand typography beyond the billboards. The road, rings and obstacles
   (the gameplay layer) read well; everything around them is placeholder.
2. **The HUD reads as a debug overlay.** Monospaced system font, translucent rounded boxes,
   an fps / entity block, distance / hits / kills next to the speed, a grey control-hint line,
   text-list cards, no controller glyphs, no motion language beyond the stamps.
3. **The cast is not yet on screen.** Story is one line per job; portraits are procedural
   glyph badges; the avatar beside the bike is a test character with one clip; there is no
   title screen, no player identity, no rival introduction, no message log, no ambience.

Everything below targets those three.

## 3. The corpus

Games studied, and the one thing each contributes to this design.

| Game | Platform | Takes for SpeederProto |
|---|---|---|
| Asphalt Legends Unite | iOS / Mac | One boost scalar drives blur, FOV, streaks, vignette, HUD; the mobile ceiling for dressing density |
| Redout 2 | PC / Switch | One hue per biome; the track ribbon is the landmark; HUD arcs around a huge speed numeral; RGB-split glitch on hit |
| Wipeout 2048 / Omega | Vita / PS4 | In-world typography as world-building; blue / red pad code; team liveries; hairline HUD |
| Fast RMX | Switch | Two-hue functional colour code; rain as spectacle at 60 fps |
| Distance | PC | The car is the light; emissive-only world; fully diegetic HUD |
| Horizon Chase 2 | Apple Arcade | Painted parallax sky; edge cadence; "less is more" HUD; colour roles must not collide |
| Thumper | PC / mobile | Centre-weighted grading; empty space as composition; rank as one huge letter |
| Sayonara Wild Hearts | Apple Arcade | Category colour; camera choreography; title cards on the beat; music-first structure |
| Race the Sun / Hyperburner | iOS | One huge horizon light source; long shadows read speed |
| Rocket League Sideswipe | iOS | Identity (avatar, banner, title) shown at every peak moment; three scalable buttons |
| Tron: Ares (2025) / Tron: Catalyst (2025) | Film / PC | Hot, refractive trails; mirror floor; faction hue as identity; angled-line UI, type-in text |
| Cyberpunk 2077 | PC | Sign layers with haze between; per-district ambience; fixers brief by call; one glitch effect per view |
| Hades | PC / Switch | The gold standard for story between short runs: reactive lines that see what you did, one exchange per visit |
| Ridge Racer Type 4 | PS1 | A manager portrait with a few expressions before and after every race |
| F-Zero GX / 99 | GC / Switch | Pilot cards with a theme and a tell; rivals picked from your history |
| NFS Unbound / CSR2 / DATA WING | PC / iOS | Jobs arrive as calls or texts; the text thread is the hub; an AI voice texting mid-race |
| Alto's Odyssey, Subway Surfers | iOS | A character is one stat tell + one look + one line |
| Hi-Fi Rush, Persona 5 | Console | UI that pulses to the tempo; one colour and one line of sight per menu |

## 4. Findings by layer

### 4.1 Viewing space

The corpus agrees on four rules, and the current worlds break two of them.

- **Fill the frame in three depths.** Every premium racer has a near layer (edge furniture at
  a regular pitch), a mid layer (hero props, signs, crowds) and a far layer (skyline or
  landform silhouettes on a gradient sky), with haze between the layers brighter than the
  layer behind it. Neon City has the near and mid layers; the far layer is 22 boxes and a
  haze band. Sunset Canyon has mesas but a flat sky. The Grid has the data towers, which is
  right for Tron.
- **One identity hue per role or faction, category contrast before detail.** The game already
  does this (road cyan, obstacles lime, rings red, rival orange). Keep it and extend it to
  pads, decals and the HUD accent per world.
- **The vehicle is a light source and has contact.** Distance and Asphalt sell contact with a
  shadow, a throttle-driven ground glow and sparks on scrape; the speeder has the engine
  light and thruster quads but no shadow (only a magenta pool) and no scrape sparks against
  the barriers beyond the existing particle.
- **Enclosure sells speed.** The tunnel, conduit and skyway are already the strongest frames;
  the open canyon stretches are the weakest. Edge cadence strips fix the open stretches
  cheaply: repeating emissive posts at 8 to 12 m pitch whose strobe rate is the speedometer
  the player feels.

Signature tricks worth taking whole: Thumper's centre-weighted grade (contrast up at the
centre, desaturate and soften the outer 30 %); Tron: Ares' hot trails (semi-transparent core,
bright edge line, a small heat-shimmer offset, white-hot then steam on derez); Fast RMX and
Asphalt's weather (rain streaks near the camera, a lightning flash that lights the far layer
for two frames); Race the Sun's single horizon light (a sun disc with a halo and god rays from
the mesa gaps in the canyon, a moon or planet behind the skyline at night); Wipeout's in-world
typography at section mouths and portal frames.

### 4.2 Speed, vehicle and feel

Already competitive: hit-stop, shake, FOV and dolly with speed, the boost kick envelope,
streaks, aberration. Missing against the corpus: velocity motion blur in the outer ring (the
world moves rigidly past a fixed vehicle, so per-pixel velocity is a reprojection from depth,
no G-buffer), heat haze on the thrusters, lens dirt and ghost flares from the bright pass,
dithering to hide banding in the dark worlds, MSAA (ARView exposes no anti-aliasing switch;
RealityView does), and a boost state that reaches the HUD and the exhaust length as well as
the camera.

### 4.3 HUD and screens

The corpus is unanimous: restraint plus one motion language beats decoration. Wipeout's
hairline gauges and big numerals, Redout 2's speed numeral framed by arcs, Horizon Chase 2's
"less is more", Thumper's near-absence of HUD. Apple's own guidance (WWDC24 Design advanced
games, HIG Game Controls) adds hard numbers: 44 pt targets, body 17 pt, labels 11 pt minimum,
controller glyphs from `sfSymbolsName` so a Backbone shows the right button art, 59 to 62 pt
side insets for the Dynamic Island in landscape, a press state and haptic on every touch
control. The HUD/UI report contains a full zone-by-zone spec for the run HUD and every
between-run screen; the short version of what changes:

- A display face (Chakra Petch or Rajdhani, SIL OFL) for labels and numerals, SF Mono only
  where tabular digits matter; no translucent boxes, hairlines and gradients instead; the
  debug block, distance / hits / kills and the hint line leave the run.
- One motion language reused everywhere: draw-on lines, 220 ms pulses on any increase,
  numeric roll on score and credits, a spring-in / hold / glitch-out stamp quantised to the
  music, a 3-frame RGB-split glitch shared by hit, derez, curtain and card transitions.
- Cards become screens: a title / attract screen, a briefing split into brief-left and
  portrait-right with the garage as a loadout row, a rival card that slams in before a duel
  and hands its colour to the HUD, a result card that reveals rank, score, flags, debrief
  and credits 150 ms apart with sounds.

### 4.4 Characters, story, sound (the end-to-end layer)

The pattern that works for 60 to 150 s sessions is Hades' rule: one voice, one line, right
now, and the line proves the game saw what you just did. Story hangs on the job (NFS Unbound,
Cyberpunk, DATA WING), a fixed cast escalates (Ridge Racer Type 4's manager, Wipeout's
four-trait pilot card), a character is one tell + one look + one line, identity is shown at
the emotional peak (Sideswipe on every goal), and music switches state on bar lines (Mario
Kart's final-lap lift, Forza Horizon's finish duck and slam). What fails: repeating barks,
unskippable intros, calls at the wrong moment, chapter titles with no people in them, story so
faint reviewers call it "barely worth mentioning".

Against that, the game has the skeleton (contacts, rivals with tempers, a debrief line, a
briefing avatar, per-world stems) and none of the flesh: the debrief is static, contacts
have no voice, rivals have no card, the player has no name, the music has no state machine,
the worlds have no ambience beds. This is the cheapest layer to lift because it is mostly
text and rules over systems that exist.

**Character Creator 5 and iClone 8** change the character plan. The research confirms a
working route to RealityKit (FBX with the Blender preset, cc_blender_tools, USD export with
armature and shape keys, one USDZ per clip, exactly the Blender step already in use), a
budget (Game Base body plus suit and helmet at 20 to 35k triangles, one 2K atlas, two
materials), AccuLIPS lip sync from text without a capture rig, and alpha-PNG portrait renders
that will always beat a runtime RealityKit portrait on an iPhone 12. Two constraints shape
the plan: RealityKit stops applying blend-shape weights while a skeletal clip plays on the
same entity (Apple forum, unresolved), so a talking head must either be an iClone-rendered
HEVC-with-alpha video in the HUD or a blend-shape-only state with a procedural neck sway; and
licensing is Standard per purchased component for one character each, Extended only if one
suit is reused across the cast. CC5 and iClone are Windows-only, so the character work is a
Windows session feeding the Mac pipeline.

### 4.5 Engine and architecture

Verified against Apple's documentation for iOS 18 to 26 (deployment target 18, SDK 26.5,
phone is an iPhone 12): the current ARView post hook stays; RealityView adds MSAA 4x and
`dynamicRange` on iOS 18 and its own post hook on iOS 26; `MeshInstancesComponent` is iOS 26
(not 18), so dense city geometry below 26 means merged `LowLevelMesh` batches; bloom and
tone-mapping components and LOD are iOS 27, outside the window; `RealityRenderer` (iOS 18) is
the offscreen route if runtime portraits are ever wanted; particles have bursts, sub-emitters
and sprite sheets but no ribbons (trails stay in the `LowLevelMesh` renderer); `PortalComponent`
(iOS 18) could sell the corridor-to-Grid transition literally. MetalFX and Metal 4 buy nothing
at 60 Hz on an iPhone 12 and are only reachable by owning the drawable; skip them.

The one structural change that unlocks most of the visual list is a shared prologue in the
post pass: half-resolution linear depth, a velocity buffer by reprojection, the previous
frame's colour, and the bright pass. Motion blur, heat haze, god rays, glitch and volumetric
fog slices all consume those. The second is a presentation state machine (title / attract,
briefing, run, debrief, inbox / garage) above the game controller so screens stop living
inside the run loop. The third is a narrative data file (JSON: speaker, lines, conditions on
flags, triggers) instead of Swift string literals in the mission table.

## 5. Gap analysis

| Layer | Contemporary standard | SpeederProto today | Gap |
|---|---|---|---|
| Far layer / sky | Gradient sky, stars or sun, silhouette cards at 2 to 3 depths, haze between | Painted haze band, 22 box towers | Large: the most visible prototype tell |
| Edge and mid dressing | Regular edge cadence, hero props, brand typography, weather | Poles, barriers, box buildings, billboards; no cadence rhythm, no weather | Medium |
| Vehicle contact | Shadow, ground glow with throttle, scrape sparks, heat haze | Glow pool, thruster quads, engine light | Medium, cheap |
| Speed package | Boost scalar to every output; blur in the outer ring; lens dirt; MSAA | Kick drives FOV, dolly, streaks, aberration; no blur, dirt or MSAA | Small to medium |
| Grid look | Hot refractive trails, mirror floor, voxel derez | Ribbon trails with head / tail fade, glossy floor, shard burst | Small |
| HUD | Display face, hairlines, one motion language, glyphs, safe areas | Monospace, boxes, debug block, hint line | Large, cheap |
| Screens | Title / attract, briefing split, rival card, staged result | Text-list cards, no title screen | Large |
| Story delivery | Reactive lines, contact voices, comms mid-run, message log | One static debrief per job | Large, cheap |
| Cast | Portraits with a look, live character with idle and talk, tells | Glyph badges, test avatar with one clip | Large; CC5 / iClone closes it |
| Identity | Callsign, livery, title shown at peaks | None | Medium, cheap |
| Music | Bar-quantised state machine, entry / pressure / finale / finish | Three stems gated by intensity | Medium |
| Ambience | Per-world beds ducked under music | None; no reverb or filters in the graph | Medium |
| Haptics | Continuous engine player with per-frame parameters | Transient events per action | Small |
| Meta | Leaderboards, achievements, share | None | Small |

## 6. Recommendations

Ranked by visible result per effort inside each workstream. Effort: S under a day, M one to
three days, L a week or more. "Result" is what the player sees or hears.

### Workstream A: the viewing space

| # | Recommendation | Result | Effort |
|---|---|---|---|
| A1 | Layered horizon and sky dome per world: a gradient sky with stars (night), a sun disc with halo and god-ray cards (canyon), a moon or planet behind the skyline; three parallax silhouette rings with sparse window dots scrolled at 0.2 / 0.5 / 0.8, haze between layers brighter than the layer behind | The empty upper third of every frame becomes a place | M |
| A2 | Edge cadence strips and road decals: emissive posts at 8 to 12 m pitch, role-coloured; cyan chevron speed pads and amber charge pads as thin depth-reading quads | Speed is felt in the open stretches; the floor carries a second information layer | S |
| A3 | Vehicle contact: a blob shadow, a throttle-driven ground glow, barrier scrape sparks, thruster heat haze in the post pass | The bike sits on the road instead of floating in front of it | S to M |
| A4 | In-world brand typography: a procedural sign atlas of fictional brands, oriented to the road, at section mouths and portal frames; the same atlas feeds the far layer | The city reads as designed, not generated | S to M |
| A5 | Weather for Neon City: rain streak particles near the camera, a lightning flash uniform that lights the far layer for two frames, the wet road already exists | The biggest perceived jump per line of code in the night world | M |
| A6 | Building silhouettes: setbacks, crowns, antenna clusters, a few tower archetypes merged into `LowLevelMesh` batches; instancing on iOS 26 | Mid layer stops being boxes | M to L |
| A7 | The Grid: hot trails (semi-transparent core, bright edge, heat-shimmer offset in the surface shader, white-hot then steam on derez), a dissolve derez on the cycle via `CustomMaterial` discard by noise threshold | Tron: Ares trails; the derez becomes the signature moment | M |

### Workstream B: the post pass and speed package

| # | Recommendation | Result | Effort |
|---|---|---|---|
| B1 | One boost scalar to every output: extend the kick to vignette, exhaust length, HUD slide-out and accent brightness; add Thumper's centre-weighted grade term | Boost reads as one event across camera, world and HUD | S |
| B2 | Post pass v2 prologue: half-res linear depth, velocity by reprojection, previous colour, behind a `PostPipeline` protocol so the iOS 26 RealityView hook drops in later | Enables B3, A3 haze, A7 glitch | M |
| B3 | Velocity motion blur in the outer ring, ghost flares and lens dirt from the bright pass, dithering before the 8-bit write, grade as a baked 3D LUT per world | The frame stops banding, gains flare and motion without losing centre sharpness | M |
| B4 | RealityView migration for MSAA 4x and `dynamicRange`; also removes the ARView touch workaround | Edges stop crawling on the phone | M, with risk |

### Workstream C: HUD and screens

| # | Recommendation | Result | Effort |
|---|---|---|---|
| C1 | Type and chrome: Chakra Petch or Rajdhani, the type scale from the spec, hairlines and gradients instead of boxes, the debug block and hint line off the run, safe-area insets for the Island | The HUD stops looking like a debugger in one pass | S |
| C2 | Controller glyphs from `sfSymbolsName` on every prompt and hint; touch buttons at 56 pt with press states and haptics | Reads as a shipped console game on a Backbone | S |
| C3 | Motion language: numeric roll, pulses on increase, a `StampView` with spring-in / hold / glitch-out, one shared glitch `layerEffect` for hit, derez, curtain and cards | Every score, section and attribution lands with weight | M |
| C4 | Result card reveal sequence: rank letter with a bass hit, score roll, flag chips, debrief typed in, credits delta, RETRY / NEXT | The pay-off becomes the memorable screen | M |
| C5 | Title / attract screen: the world's demo camera behind the wordmark, callsign, credits, next job chip, attract run after 20 s idle | A front door; the first thing anyone sees stops being a settings gear | M |
| C6 | Briefing redesign: brief left, portrait right, loadout row, inbox strip with medals; rival card slam before duels handing its colour to the HUD | The cast is on screen every time a job starts | M |

### Workstream D: characters, story, sound

| # | Recommendation | Result | Effort |
|---|---|---|---|
| D1 | Reactive debrief lines: four to six variants per job keyed to what happened (clean, respawned, gate bonus, boxed yourself, cut off by whom), priority essential then reactive then evergreen, never repeat until spent; contact voices (a two-word temper and a sign-off each); all in a JSON narrative file | "Two respawns. The client noticed. So did I." | M |
| D2 | Player identity: a callsign typed once, a livery accent that tints trail, HUD accent and bike emissive, a title earned from rank; shown on the title screen, the duel name tag, the freeze-cam and the result card | "VESS CUT OFF <callsign>" | S to M |
| D3 | Rival card and record: before every duel, portrait, temper, skill tier, head-to-head record, one taunt from the record; the freeze-cam caption carries the record | Every duel has stakes | S to M |
| D4 | The cast through CC5 / iClone 8: a player character and four contacts / rivals, Game Base plus suit and helmet, one idle and one talk clip each, AccuLIPS from the debrief text, alpha-PNG portraits at three sizes; the first character is the proof of the blend-shape decision (video-in-HUD versus live) | Real faces on the briefing, a real body beside the bike, portraits that match the world | L (2 to 3 days for the first, a day each after) |
| D5 | Comms in the run: at most three contact lines per job, eight words or fewer, event-triggered (fork, pursuer closing, last gate), shown as a stamp with a blip, never at the objective | "Skyway. Trust me." | S |
| D6 | Music state machine on the existing stems: pad on the briefing, bass on accept, arp on the first gate; a percussive layer while boosting or leading; filter and arp density follow the GAP bar or the zone radius; tempo 112 to 118 and a semitone lift at 75 % on a bar; a one-bar duck and slam on the finish; hard cut to a detuned pad on derez; per-world scales; every change on a bar line via `lastRenderTime` | The music tightens as the job tightens | M |
| D7 | Ambience beds per world (Neon City hum, distant adverts, rain hiss; canyon wind band and rock ticks; Grid pure tone and trail whine) ducked under the music; a reverb send that opens in tunnels and the conduit | The world sounds different before it is seen; enclosure is audible | M |
| D8 | A continuous haptic engine player with per-frame intensity from speed and sharpness from boost; AHAP patterns for hit, boost, derez | The Backbone hums with the engine | S |
| D9 | Game Center: leaderboards per job, achievements for flags; a postcard on the result card with a share sheet | The run has an audience | S to M |

## 7. Build order

Each pass is playable and capture-verifiable on its own. The phone pass still owed from the
last thread (sound levels, Backbone browse and buy, balance) comes first because two of the
passes below depend on hearing the game on the device.

**Pass 1, presentation foundation (about a week).** C1, C2, B1, A2, A3, D2, D5, D8. Cheap,
mostly SwiftUI and uniforms, and it removes the "debug overlay" impression before anything
expensive is built. Verify with simulator HUD shots and Mac captures at the same times as
`Captures/polish/p6/`.

**Pass 2, the world (one to two weeks).** A1, A4, A5, B2, B3, then A7. The far layer and the
weather are the two changes most likely to make a stranger say "that looks like a real game".
Keep the frozen Neon City look as the A/B baseline (`Captures/variants/` pattern) and compare
aligned frames.

**Pass 3, the cast (one to two weeks, needs the Windows machine).** D4 proof on the player
character first (idle, talk, portrait), then the four contacts / rivals, then D1, D3, C6, C5,
C4. The proof decides whether talk is video-in-HUD or live blend shapes; do not build rivals
before that decision.

**Pass 4, systems (one to two weeks).** D6, D7, B4, A6, D9. The RealityView migration is the
one item with regression risk (touch, post hook, capture pipeline); do it on a branch with the
capture sweep as the gate.

## 8. First proofs

Small experiments to run before committing to a pass, each answerable with a capture:

- **Far layer**: three silhouette rings behind Neon City with a gradient sky, one frame at
  t = 9 against `Captures/polish/p6/sim/relay01-22.png`. Decides how much of A1 is needed.
- **Boost scalar**: extend the kick to the vignette and the exhaust, capture at t = 4 and 9
  with `SPEEDER_DEMO_BOOST=always`. Decides whether B1 alone is enough before B3.
- **HUD type**: one build with Chakra Petch and no boxes, a simulator shot of the run and of
  the briefing. Decides the display face.
- **Blend shapes**: one CC5 character with an idle clip and a talk clip, loaded through the
  existing avatar path; test blend-shape weights with and without the clip playing. Decides
  video-in-HUD versus live talk for the whole cast.
- **Velocity blur**: the prologue plus a six-tap outer-ring blur, frame time on the phone
  with the fps block. Decides whether B3 fits the iPhone 12 budget.

## 9. Risks and uncertainties

- RealityView's built-in motion blur may be camera-only; the world moves and the camera does
  not, so it may do nothing. Test before relying on it.
- The blend-shape-during-clip bug is unresolved on Apple's forum; plan for the video route.
- Instancing is iOS 26 only; A6 below 26 is batching, which means rebuilding batches on each
  segment recycle or accepting a fixed skyline set.
- The 8-dynamic-light limit is community lore, not documented; the game is at five plus
  transients.
- CC5 licensing per component is Standard for one character each; reusing a purchased suit
  across rivals needs Extended. Confirm before buying content.
- Parallel captures starve the frame rate (known); pass 2 verification is one instance at a
  time.

## 10. Decisions for Mark

1. Display face: Chakra Petch (square, Tron-adjacent) or Rajdhani (condensed, denser HUD).
2. Talk delivery for the cast: iClone-rendered video in the HUD (exact, safe) or live blend
   shapes (one model, riskier). The proof in pass 3 informs this, but the tone preference
   (a "call" window versus a character turning to speak) is a design call.
3. Whether the player character is a helmeted courier (no face pipeline, fastest) or a face
   (needs the ARKit profile and the talk decision).
4. Pass order: the phone pass first as planned, or pass 1 first because it changes what the
   phone pass evaluates.
