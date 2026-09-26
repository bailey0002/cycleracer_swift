# Research reports, 26 Sep 2026 (appendix to `assessment-2026-09-26-market.md`)

Six agents ran in parallel: a codebase inventory (so the gap analysis is against what is
actually built), viewing space (art direction of contemporary futuristic racers), non-action
layers (characters, story, sound between and during runs), HUD/UI, RealityKit/Metal
architecture, and the Character Creator 5 / iClone 8 pipeline. Reports are reproduced lightly
edited; the synthesis is in the assessment document.

---

## Report 0: what SpeederProto implements today (codebase inventory)

### 1. Rendering

**Material types** (`Rendering/MaterialFactory.swift`)
- `PhysicallyBasedMaterial`: road (albedo + normal + roughness maps, `textureCoordinateTransform` 2x4.5, specular 1, metallic 0), `barrier`, `concrete`, `tunnelWall` (rock facade by day), 3 `facades` + `skyline` (base + emissive window maps), `tubeWall` (faceCulling .none), arena `gridFloor` / `gridWall` (emissive grid, emissiveIntensity 2.2 / 2.6, roughness 0.2). `neon(color, intensity)` cached emissive factory.
- `UnlitMaterial`: 16 billboard `signs`, 6 `glyphSigns`, `holoPanel` (alpha 0.42), `glow` (glow sprite, alpha-blended halo), `reflection` (streak sprite = fake wet-road pool), trail fallback, rival name tag.
- `CustomMaterial` surface shaders (`Rendering/Shaders.metal`): `hologramSurface` (rolling dark band, 380-line scanlines, two-frequency flicker, unlit); `trailSurface` (light ribbon with head whiteness, tail fade, crash pulse, boost gain; core/glow/floor parts).
- No reflection probes: reflections are IBL from the procedural equirect environment on the glossy road/grid floor plus alpha-blended `reflection()` streak quads under every light source.

**Procedural textures** (`ProceduralTextures.swift`, Core Graphics, seeded, generated at launch): `roadAlbedo` / `roadAlbedoDay`, `roadNormalAndRoughness` (puddle mask), `flatRoughness`; `facade(seed:)` base + emissive (16x24 lit windows, blinds, grime), `skylineFacade`, `rockFacade`, `tubePanel`; `billboard(text:)` 1024x512 with Avenir-Heavy text, `glyphStrip`, `nameTag`, `portrait` (helmet + visor + temper glyph + name); sprites `glowSprite`, `reflectionStreak`; equirect environments 1024x512 (`environment` night with haze band, 70 neon spikes, clouds, sub-horizon mirror; `environmentSunset` with sun disc + halo; `environmentGrid` black zenith, cold band, pulse); arena `gridFloor`, `gridWall`.

**Meshes**: RealityKit primitives (`generateBox`, `generatePlane`) plus `Meshes.tube` (inward cylinder) and `Meshes.ring` (flat annulus). Trails: `LowLevelMesh` chunks of 256 segments x 12 verts.

**Lights**: 5 when `realLights` is on: sun `DirectionalLight` with shadow (max distance 30 / 70 by theme), rim directional (city), camera-mounted fill `SpotLight` (city), vehicle `engineLight` + `underLight` point lights. Transient: explosion, derez (160 000), pursuer point + spot. Only the sun casts shadows; there is no vehicle shadow, only the magenta glow pool quad under the bike.

**Sky/backdrop**: `arView.environment.background = .skybox(procedural equirect)` doubling as IBL. No star field, no dome geometry; the horizon is the painted haze band plus a `SkylineLayer` of 22 wrapping box towers (28 far box "data towers" in the arena).

**Particles** (`ParticleEmitterComponent`): engine trail (box, additive, birthRate 30 to 190 with speed, cyan to magenta); speed motes past the camera (birthRate 80 to 440, stretch 7); sparks (collision and barrier scrape, 900, gravity); 3 pooled explosions (1600 + point light); arena grind sparks and derez burst (2400 + 14 flying shards).

**Post pass** (`PostProcessor.swift` + `PostFX.metal`): bright pass at quarter res, MPS Gaussian sigma 4.5, eighth downscale, sigma 7, composite: chromatic aberration `0.0007 + speed*0.0025 + kick*0.0015`; exponential depth fog with a screen-space radial fallback when the depth probe fails (density `[0.002, 0.006, 0.014] x theme x (1 + 1.5 enclosure)`, horizon glow, darkened in tunnels); bloom `(HDR ? 0.6 : 0.72) x [0.5, 1, 2]`, threshold `[0.84, 0.74, 0.56]`; 14-tap radial streaks from the projected vanishing point (`0.12 + speed*0.5 + kick*0.35`, length `0.07 + speed*0.22 + kick*0.06`, centre kept sharp); ACES + saturation + cool shadow lift / magenta mids, per-theme exposure; collision flash; vignette (x1.6 enclosed); curtain. Vanishing point reprojected each frame.

**Per-frame shader params**: one `custom.value` use, the trail fade `(headS, tailS, pulseS, boost)`. Hologram uses `uniforms().time()`.

**Placeholders**: all buildings / mesas / towers / podiums / decks are boxes; every sign, halo, reflection pool and pad is a flat quad (several tilted 0.01 to 0.03 rad to defeat culling); obstacles are box assemblies; the pursuer is a box + fin + bar.

### 2. World dressing

**Corridor segment** = 40 m, 8 pooled, groups toggled per style. Road plane (18 m, 36 m at the fork); lane group (cyan edges, magenta centre dashes, lane dashes, studs); roadside (barriers + neon caps + reflection strips, light poles with tube + arm + pool); buildings per side (8 to 16 m wide, 16 to 95 m tall, alternating rows, masts + red beacons, neon strips, billboards, glyph signs, hologram signs) + second row (55 to 150 m) + storefront strips and podiums; gantry every third segment; tunnel (walls, ceiling, guide lights, glyph panels, light rings); elevated skyway (rails, underside glow, deck slabs, arches, 60 m pylons, floating billboards); fork (V divider on a pivot, wedge, nose, chevrons, hologram sign, guide posts); tube conduit (R = 6, coloured + white rings, running strips, floor guide); portals per enclosed style; landmarks (overpass, gateway). Canyon swaps buildings for tiered mesas + boulders + distant mesas. Obstacle pool: 4 blocks (4 skins), 2 energy gates, 2 drones, 2 beams, 2 pillars, 1 hatch, each with hazard stripes and a reflection pool.
**Animated**: drones bob, strobes at 5 Hz, hologram signs in-shader, billboards re-texture on recycle, skyline scrolls at 0.22x. Textures do not scroll; segments move.

**Arena**: 340 m glossy grid floor; 4 wall slabs + rail + base line + reflection strip; 4 corner pylons with pulsing caps; 28 far data towers; upper deck at h = 9 over the north half with under-deck lamps and a column grid; 2 ramps; 10 pads (8 boost, 2 slow) with glow pool + frame + posts, breathing; 3 pickup props (PHASE / PULSE / CHARGE); sumo zone (64 box segments + disc); rival locator beam (34 m) and camera-facing name tag. Static hazards are registered as trail 0 and drawn by the trail renderer.

### 3. Vehicle and camera

`SpeederController`: USDZ in a holder; bank `-steer*0.24 - vx*0.02 + wallBank` with a collision jolt; yaw / pitch with idle wander and speed pitch; hover bob and a 23 Hz vibration at speed; 4 thruster glow quads pulsing `1 + 0.08 sin(27t) + speed*0.5`; engine light 14 000 to 32 000; exhaust birth rate scales with speed; `recoil(direction:)` 0.45 s; tube mode blends a cylinder constraint; `tint()` recolours for the rival.

`CameraRig`: corridor damped follow, roll = bank x 0.3, dolly `5.8 - speed*0.8 + kick*0.45`, height + speed x 0.25, FOV `52 + speed*14 + kick*9`, two-frequency shake, frame shift during briefings; boost kick 150 ms attack / 400 ms release, exported to the post pass. Arena: spring follow, snap on round start, crash orbit for the player derez, rival freeze-cam, match-over hold. Capture-only overview and side cameras.

### 4. Feel / feedback

Hit-stop 0.07 s at 15 % sim speed; arena crash slow-motion `dt *= 0.35` for 3.4 s. Flash decays x3.5/s (1.0 hit / respawn, 0.5 helmet, 0.2 beacon; arena pads, grind, snap, derez). Haptics: CoreHaptics transient events via `gamepad.rumble(intensity:sharpness:)` or `UIImpactFeedbackGenerator` on touch (hit 1.0/0.4, respawn 0.8/0.3, boost 0.5/0.5, launch 0.6/0.4, fire 0.25/1.0, kill 0.5/0.9, beacon 0.5/0.9, scrape 0.3/0.8 every third tick, purchase 0.4/0.6; arena snap, jump, land, wall, derez). Stamps: section labels, GO, HELMET, HULL RESTORED, score `+v xN +t s`, PHASE / PULSE / SURGE / CHARGE / ZONE, `<RIVAL> DEREZZED`, DEREZZED, VOID ROUND, MATCH WON / LOST, ROUND n / READY. `ActionAck` pips on change. Boost = camera punch + FOV + streak / aberration + rumble + surge cue; hit = flash + hit-stop + shake + recoil + sparks + explosion + speed x0.6 + 1 s invulnerability; derez = flash + shake + burst + shards + orbit; rebuild = curtain.

### 5. HUD / UI (`Views/HUDView.swift`)

Monospaced system font throughout; accent cyan, pickup violet, amber, danger red; base 11 pt iOS / 10 pt macOS, big 22 / 20; panels are black 0.55 with 8 pt radius and a 0.35 accent stroke. Top-left stats block (fps, ms, speed, entities, lights, post state, world, pad, load error; Mac always, iOS with the panel). Top-right settings panel or gear. Bottom-left race block: speed (big), distance / hits / kills / alt, section, ROUTE; arena: ENERGY / EDGE / GRIND meters, round + score, deck + altitude, PICKUP + help, ZONE, state. Bottom-right: "coming up" chip, action pips, controls hint (first 30 s and whenever the panel opens). Centre: stamp (30 pt, glow shadow, opacity + scale transition), HIT (34 pt red), BEACON +1. Top-centre while running: timer (colour shift, 1.15 scale under 5 s), HULL meter, score x streak, respawns, per-kind line (m TO DROP / BEACONS / PURSUER + GAP / FIRST TO n / TARGETS / NO WEAPONS), HELMET chip. Cards 430 pt wide, tappable, prompt row `A / F / TAP`: briefing (chapter, inbox chips, portrait (+ VS + rival for duels), code // title, contact / job index / credits / replay note, best rank + thresholds, flags, rival temper / skill / line, brief, goal line, garage list, prompt); success (title, code // title, payout / credits / hull / beacons, score + rank + NEW BEST, flags, debrief); failed (RUN FAILED + reason + RETRY NOW); match result (won / lost, rival portrait, score, rounds, best grind / longest trail / energy, credits). Settings panel 250 pt, scrollable, with the world picker, missions / sound / music, Grid options, visual toggles, post group, look variants, cruise slider.

### 6. Audio (`Audio/SoundEngine.swift`)

Fully synthesised at launch, no assets. `AVAudioSession.ambient` + `.mixWithOthers`. Graph: 8 one-shot player + varispeed pairs, 5 loop players, 3 music players, straight to the main mixer (0.8). No reverb, no filters beyond the synthesis-time lowpass, no spatial audio. 29 cues (accept, go, success, fail, respawn, tick, warn, hit, fire, kill, beacon, gate, section, approach, streakLost, snap, jump, land, derez, rivalDerez, pickup, pickupTaken, surge, slow, zone, roundStart, matchWon, matchLost, charge) built from tone / blip / sweep / arpeggio / noise / mix. 5 one-second loops (engine, boost, grind, scrape, alarm) with smoothed volume. Music: 3 generative layers (pad / bass / arp), 4 bars at 112 bpm, one chord per bar, per world (Am F C G neon, Dm F C Am canyon, Em C D Bm grid); layers share a start time; intensity gates them (pad under cards, + bass running, + arp when hot: boost, streak >= 4, pursuer < 25 m, grind, zone) with volumes swelling over about a bar.

### 7. Narrative / meta

`Mission` fields: id, kind, code, title, contact, brief, theme, blocks, distance, timeLimit, basePay, chapter, debrief, beacons, startGap, duelTarget, rival, killsRequired; derived weaponsAllowed, hullFactor, gates, maxScore, silver (40 %) and gold (70 %) thresholds, goalText, successTitle, kindText. 18 jobs in 3 chapters (DOWNTOWN / OUTLANDS / THE CORE), contacts VESS, KADE, ORIN. One `debrief` line per job on the success card carries the story. Rivals: name, temper (BOXER / RUNNER / HUNTER with a line each), colour, skill (STEADY / SHARP / KEEN: tick, urgent tick, range, noise, blink), roster KADE / ORIN / SABLE + VESS; portraits are procedural (helmet, visor, glyph, scanlines), cached per name, reused for contact badges and the in-world name tag. Avatar: one USDZ character loaded async, up-axis corrected, first clip looped, standing at `[2.6, 0, -1.5]` beside the parked bike during briefings, facing the camera, hidden once the job is live. UserDefaults: `credits`, `missionIndex`, `cleared`, `upgrades` (bit-packed), `rank.<id>`, `flags.<id>`. Garage: HULL PLATING I/II, BOOST COIL I/II, SPARE CORE, HELMET at 500 to 1200. Flags CLEAN / FAST / GOLD; ranks bronze / silver / gold; replays pay half.

### 8. Input

Pad: left stick steer / climb, d-pad overrides, R2 (> 0.3) or R1 boost, A / L2 / X fire, Y cruise up (and garage buy), B cruise down, Menu / Options panel. Keyboard: arrows / WASD, space / shift boost, F / Return fire, `[` `]` cruise, P screenshot. Touch: leftmost touch steers and climbs, two fingers boost, a short still tap is A, top-right corner toggles the panel; cards, chips and rows are tappable. Arena: steer, snap edges at +-0.5, boost, climb < -0.5 brake, climb > 0.5 edge jump, fire edge uses the pickup.

### 9. Env hooks

`SPEEDER_DEMO`, `_DEMO_BIAS`, `_DEMO_BOOST`, `_DEMO_SCRIPT`, `_CAPTURE_DIR`, `_CAPTURE_TIMES`, `_SWEEP`, `_VARIANT`, `_CAMERA`, `_ARENA_CAMERA`, `_ARENA_START`, `_ARENA_GIVE`, `_ARENA_RIVAL`, `_ARENA_AI`, `_ARENA_TRAIL`, `_ARENA_ZONE_AT`, `_ARENA_KILL_RIVAL`, `_ARENA_IMMORTAL`, `_MISSION`, `_RESET_PROGRESS`, `_HOLD_BRIEFING`, `_HOLD_RESULT`, `_PANEL`, `_SOUND`, `_AVATAR_ANIM`.

---

## Report A: viewing space of futuristic vehicle games on phone / Switch-class hardware

Scope note: developer-sourced facts are cited; per-game visual observations are from published footage, reviews and store pages.

### Corpus

**Asphalt Legends Unite (Gameloft, iOS/Mac).** Daylight-dominant, saturated warm/cool split (golden sun + cyan sky, wet-asphalt nights). Viewing space filled aggressively: guardrails and lamp posts at road edge, hero props mid-distance, skyline cards far, sun disc and volumetric shafts in the sky. Speed: heavy radial blur + chromatic fringe on nitro, FOV push, speed lines from the corners, scrolling road decals, dust and sparks. Vehicle: real-time planar/cube reflections; nitro flames, drift smoke, contact sparks. Digital Foundry called it "console quality" on iPhone. Signature trick: the nitro "tunnel", every effect keyed to one boost scalar so the frame reads as one event.

**Redout 2 (34BigThings, Switch port).** Low-poly terrain with UE4 lighting; one biome one hue (magenta / orange / teal skies). Edges: ribbon walls with emissive strips, floating gates, banners. Far: giant low-poly landforms and a huge sky sun or planet. Speed sold by extreme FOV widening, strong radial blur, camera tilt on banked track, and the track itself twisting. Ship: exhaust ribbons, hull heat glow, banking. Signature: the track is the landmark; the sky is the fill light.

**Wipeout 2048 / Omega.** City streets as tracks: far plane skyline, mid plane billboard walls and crowd stands. Dark levels sometimes hurt readability. Palette: cool concrete + one team colour + sponsor neon; blue / red chevron pads. Signature: dense in-world typography (branding as world-building) and hard colour-coded track furniture (blue = speed, red = weapon).

**Fast RMX / Fast Fusion (Shin'en).** 1080p60 with dynamic res; a rain night track singled out for droplets and shimmering lighting. Blue / orange phase: pads and gates are one of two hues and the ship must match, so all track furniture is a two-colour code. Linzner: 60 fps first, effects tuned to keep it. Signature: two-hue functional code + weather as spectacle.

**Aero GPX (2025).** "Bright colors and simple shapes that work cohesively at high speeds." Flat skies, gradient horizon, saturated edges, particle streaks on boost. Signature: no texture detail, all value contrast.

**Distance (Refract, Unity).** Neon city at night; black voids, magenta / cyan / orange emissive strips, lasers, saw blades. The car is the light source: wing glow when flying, boost heat that reddens and burns off, wheel trails. Signature: emissive-only world with car-centred lighting; hazard colour uniform.

**Horizon Chase 2 (Aquiris, Apple Arcade).** Low-poly foreground over illustrated backgrounds; "all about the colors." Parallax backgrounds and layered depth make speed; painted gradient skies with time of day and weather; rows of stylised trees or posts at the road edge give a strobing cadence. Signature: postcard sky + edge cadence, no post effects.

**Hyperburner / Race the Sun.** Race the Sun: greyscale low-poly with one warm sun and long moving shadows; the sun on the horizon is the whole art direction and the mechanic. Hyperburner: cel-shaded colour zones, god rays, debris fields. Signature: one huge light source on the horizon.

**Sayonara Wild Hearts (Simogo, Apple Arcade).** "Very simple shapes and distinctive colors because it's just swooshing by"; contrast between dangerous, positive, character and vehicle categories. Constant camera zooms and orbits; each level is an animation with a road surface. Signature: camera choreography and strict category colour.

**Thumper (Drool).** Track "just wider than your shoulders"; deep FOV, shake, motion blur. "Post-processing tricks to direct your eye": brightness and contrast rise toward screen centre, radial blur outside. "Empty spaces are a necessary part of a good composition." Signature: centre-weighted grading on a void background.

**Warp Drive (Supergonk, Apple Arcade).** Cel shading with black outlines, comic boost and explosion effects; criticised for "a lot going on" during boost. Lesson: outline + flash colour is cheap but must be rationed.

**Rocket League Sideswipe.** Minimalist arenas rich in colour, 60 fps cap; emissive floor lines + goal glow + boost trails carry the look.

**Tron: Catalyst (Bithell, 2025) and Tron: Ares (ILM, 2025).** Character neon as identity colour (blue hero, green informant). Ares trails are semi-transparent red with a little heat distortion ("we want it to feel hot"), explicitly not glassy; the Dillinger Grid is "dark, shiny, almost wet", circuit-board patterned; practical LED bikes for wet-road reflections; cut edges glow and steam. One identity hue per faction; the floor is a mirror.

**Cyberpunk 2077 driving.** District colour schemes, lighting as a guide, "dramatic contrast and nice gradients, avoiding flooding / flattening", large-scale volumetric fog. Vehicle sequences read as sign layers (near / mid / far) plus haze between them.

**Ghostrunner 2 bike.** Fast inside tubes and corridors; slow and criticised in the open wasteland. Enclosure sells speed; open plains kill it.

**Sky Gamblers.** Volumetric clouds, god rays, sun glare; sky is 70 % of the frame and cheap cloud cards sell scale.

**Trackmania Turbo / GRIP.** Turbo: arcade palette, stadium floodlights. GRIP: grit filter, furnace exhausts, wall and ceiling driving.

**Recent mobile (2024 to 2026).** Ace Racer (NetEase): neon-soaked, ultimate-skill spectacles with full-screen flashes. Star Racer (2025): HD-2D pixel ships over 3D tracks. No new AAA futuristic racer on Apple Arcade in 2026; Sonic Racing CrossWorlds rumoured.

### Corpus table

| Game | Palette / regime | Signature trick | Mobile-viable |
|---|---|---|---|
| Asphalt Legends | Warm sun + cyan sky; wet night | One boost scalar drives blur, FOV, streaks, vignette | Yes (is mobile) |
| Redout 2 | One hue per biome, huge sky | Track ribbon as landmark; emissive edge strips | Switch |
| Wipeout 2048 | Concrete + sponsor neon | Blue / red pad code; in-world typography | Vita |
| Fast RMX | Blue / orange phase | Two-hue functional code; rain lighting | Switch |
| Aero GPX | Flat saturated, gradient sky | Value contrast, zero texture | Yes |
| Distance | Black + magenta / cyan emissive | Car is the light; heat glow | Yes |
| Horizon Chase 2 | Painted skies per region | Parallax layers; edge cadence | Yes (Arcade) |
| Race the Sun / Hyperburner | Greyscale + one sun | Horizon sun, long shadows | Yes |
| Sayonara Wild Hearts | Purple / pink / blue | Category colour; camera choreography | Yes (Arcade) |
| Thumper | Chrome + red on void | Centre-weighted grade, radial blur | Yes |
| Warp Drive | Cel + outline | Comic boost flashes (over-used) | Yes (Arcade) |
| RL Sideswipe | Emissive floor lines | Minimal arena, glow trails | Yes |
| Tron Ares / Catalyst | Faction hue on wet black | Hot, refractive trails; mirror floor | Concept only |
| Cyberpunk 2077 | District schemes, haze | Sign layers + volumetric fog | Partial |

### Ranked transferable upgrades (impact per effort)

1. **One boost scalar, many outputs** (Asphalt, Thumper). Bind FOV (+8 to 12 deg), streak intensity, vignette, chromatic fringe, exhaust length and HUD pulse to one eased `boost` value. The frame breathes outward on R2 and snaps back.
2. **Centre-weighted grade** (Thumper). Raise contrast and brightness toward screen centre; desaturate and slightly blur the outer 30 %. One extra radial term in the composite.
3. **Edge cadence strips** (Horizon Chase, Wipeout). Repeating emissive posts or bars at 8 to 12 m pitch at both edges, role-coloured. The strobe rate is the speedometer the player feels.
4. **Layered horizon** (Horizon Chase, Cyberpunk). Three parallax silhouette cards behind the corridor: far skyline on a gradient, mid towers with sparse window dots, near rooftops with a few signs; haze between layers brighter than the layer behind. Canyon: mesa silhouettes + amber gradient. Fills the empty sky, the biggest premium gap.
5. **Two-hue functional code** (Fast RMX, Wipeout pads). Keep obstacle lime, ring red, road cyan, and add road decals: cyan chevron speed pads, amber weapon / charge pads.
6. **Hot refractive trails for The Grid** (Tron: Ares). Semi-transparent core, bright edge line, a small vertical heat-shimmer offset in the surface shader, orange for the rival, mirrored in the floor. On derez the edge goes white-hot then steams.
7. **Weather as spectacle** (Fast RMX, Asphalt). Neon City rain: diagonal streak particles near camera, wet specular already in place, occasional lightning that lights the far layer for two frames.
8. **Vehicle contact and shadow** (Asphalt, Distance). Blob shadow plus a throttle-driven ground glow disc; sparks on wall scrape.
9. **Sky light source** (Race the Sun, Sky Gamblers). Canyon: one big sun disc with a lens halo and god-ray cards from the mesa gaps, long shadow stripes across the road. Night: a moon or planet behind the skyline.
10. **In-world typography** (Wipeout). Procedural sign atlases with fictional brands at section mouths and portal frames.

### Cheap wins

Skybox as vertical gradient + horizon band, never flat black; distance fog brighter than the scene plus a ground-haze band 0 to 3 m above the road; parallax silhouette cards at three depths scrolled at 0.2 / 0.5 / 0.8; screen-space road decals (arrows, lane numbers, pad glyphs); lens dirt / halo texture additively blended at low alpha, brightening with bloom; subtle vignette + film grain to hide banding; radial blur only in the outer ring at half res. Rules: one identity hue per faction / role; category contrast before detail; empty space is composition.

### Sources

Unreal Engine Redout 2 blog; 34BigThings; Red Bull Redout 2 interview; Wikipedia Wipeout 2048; GamesRadar evolution of Wipeout; Nintendo Life Fast RMX; Nintendo Everything Shin'en interviews; DSOGaming and Gameindustry.com on Aero GPX; Distance press kit; 80.lv The Creation of Horizon Chase and the HC2 art blog; Race the Sun postmortem (Game Developer); TapSmart Hyperburner; Apple Developer Behind the Design: Sayonara Wild Hearts; Game Developer on Thumper visuals, PS Blog GDC 17, GDC Vault Thumper postmortem; Nintendo Life Warp Drive; TouchArcade Speed Demons; Android Police / GamingOnPhone RL Sideswipe; ILM and VFX Voice on Tron: Ares; Game Developer and GamesHub on Tron: Catalyst; 80.lv Cyberpunk 2077 lighting; Game Informer Ghostrunner 2; Tech-Gaming Sky Gamblers and GRIP; GameWatcher Trackmania Turbo; Gamer Matters and Digital Foundry on Asphalt 9; Gameloft lead vehicle artist; Pocket Gamer Ace Racer; Nintendo Life Star Racer; Space Ape motion blur for mobile; Game Developer arcade track design fundamentals.

---

## Report B: characters, story and sound between and during runs

### How the comparables do it

| Game | Characters and story | Sound and music | Between-run screens |
|---|---|---|---|
| NFS Unbound | Weekly qualifiers; beats arrive as crew phone calls that trigger jobs; rivals have tier badges and one-liners; Obi is memorable because he does not trash-talk | Rival lines repeat and grate; manager calls interrupt | Garage hub, bets vs rivals |
| NFS Heat | Sibling crew plus one named cop; story in garage scenes and calls | Day / night mood split | Garage |
| NFS No Limits | Event roadmap per chapter ending in a rival race vs a named crew leader | Stock EDM | Event map; portrait + two lines before a boss |
| CSR Racing 2 | Five tier bosses plus a mentor; story in text-message threads and wagers | Engine sound is the feel | Text-thread inbox |
| Asphalt Legends | Career chapters with names but no characters; chapter titles without story feel like a menu | Licensed pop | Career grid |
| Horizon Chase 2 | No story; identity from world-tour countries; works because the loop is 2 min and the music carries it | Barry Leitch synth score | World map |
| Sayonara Wild Hearts | 22 tarot characters; each level is one song; a spoken narrator frames acts | Music first | Album track list |
| Hades | Dialogue priority (essential > reactive > evergreen), one exchange per NPC per visit; failure rewarded with lines that see what you did; keepsakes make the giver react in-run | Voiced one-liners on boons | Hub, Codex |
| Tron: Identity | Visual novel, graphic-novel portraits; ally / spurn / derez choices; rain and neon | Sparse | Dialogue screens |
| Tron: Catalyst | Courier protagonist, time loop; repeated dialogue found draggy | Homage score | Faction hubs |
| Distance | Wordless environmental story; players asked for "a clear story" | Track-synced synth | Level list |
| Art of Rally | No characters; the postcard is the story (photo mode) | Lo-fi | Photo mode |
| Alto's Odyssey | Six riders each with one stat tell; goals in trios; no text story | Ambient, weather-reactive | Goal card, workshop |
| Subway Surfers / Sonic Dash | Cosmetic characters with a one-line bio; identity without stats | Loop | Character shop |
| RL Sideswipe | Identity = avatar + banner + title, shown on every goal | Goal explosions | Profile |
| Wipeout | Teams with corporate lore; pilot archive: age, origin, rank, four trait words, bio; liveries are the brand; Zone swaps to harder music | Licensed electronica | Team select, pilot archive |
| Star Wars Racer | 23 pilots with stats; winning unlocks the track champion; Watto's shop | Film score | Hangar |
| F-Zero GX / 99 | Pilot Data (backstory, illustration, theme song, video); Mr. Zero interviews the winner; 99 picks five rivals from your history | Per-pilot themes | Pilot profiles, interview |
| Ridge Racer Type 4 | Four teams with managers; a portrait shuffling expressions delivers a monologue before and after every race; tone tracks results | House / jazz | Manager screen |
| Burnout Paradise | DJ Atomika radio voice; unskippable intro and chatter is the cited annoyance | Radio | None |
| Mirror's Edge / Ghostrunner | Handler voice on radio ("plot without slowing the action") | Ambient tension / synthwave | Chapter cards |
| Cyberpunk 2077 | Fixers brief gigs by holo-call; six districts each with a distinct ambience mix | Layered ambience by geometry, time, weather | Journal |
| DATA WING (mobile, Tron-clean) | An AI "Mother" texts you during and between neon races; the story "almost trumps the action" | Chiptune synth | Level list |
| Riptide GP: Renegade | Revenge arc; rivals appear with quick jabs; "barely worth mentioning" (too thin) | Stock | Career map |

### Patterns for 60 to 150 s sessions

Works: one voice, one line, right now (Hades: reactive beats evergreen; Ghostrunner: no slowing); story hangs on jobs (Unbound, Cyberpunk, DATA WING); a fixed cast with an escalating relationship (R4's manager, Wipeout's four-trait pilot card); character = one stat tell + one look + one line; identity displayed at the emotional peak (Sideswipe on every goal; here the derez cam and result card); music-led mood per world with documented state switches (Mario Kart final-lap lift, first-place percussion layer, Wipeout Zone, Forza Horizon 5 finish duck and slam); rivals chosen from history (F-Zero 99).

Fails: repeating rival barks (Unbound), unskippable DJ intros (Burnout), calls at the wrong moment (Cyberpunk), loops that replay dialogue (Catalyst), chapter titles without people (Asphalt), story too faint to mention (Riptide), pure environmental story (Distance).

### Recommendations, ranked by entertainment per effort

| # | Recommendation | Player sees / hears | Lands at |
|---|---|---|---|
| 1 | Reactive debrief lines (Hades rule): 4 to 6 variants per job keyed to what happened; essential > reactive > evergreen; never repeat until spent | "Two respawns. The client noticed. So did I." | Result card |
| 2 | Contact roster with a voice each: three fixers, fixed badge, two-word temper, a signature sign-off | Badge + name + brief + sign-off | Briefing, inbox |
| 3 | Rival card before every duel: portrait, temper icon, skill tier, head-to-head record, one taunt from the record | 3 to 4 s card with a two-note sting | Duel intro |
| 4 | Callsign + livery = player identity: 3 to 6 letters at first launch on name tag, freeze-cam and result card; a livery accent tints trail and HUD | "VESS CUT OFF <callsign>" | Title, freeze-cam, result |
| 5 | Music state machine: arp muted until the first gate; a percussive layer while leading or boosting; final-25 % tempo lift to 118 and a semitone up; one-bar duck and slam on the finish gate | Music tightens as the job tightens | In-run |
| 6 | Voice-in-ear as text stamps: at most three fixer lines per job, <= 8 words, event-triggered, with a comms blip; never at the objective | "Skyway. Trust me." | In-run |
| 7 | Title screen as the world's front door: current world's music low, avatar beside the bike, callsign, credits, next job's chip; no menu tree | Cheap wow on launch | Title |
| 8 | Postcard on the result card (Art of Rally): freeze the last frame, letterbox, stamp job / time / rank / callsign; share sheet | One tap to save | Result card |
| 9 | Manager expressions (R4): three badge states (neutral / pleased / cold) driven by rank | Contact's mood tracks your streak | Briefing, result |
| 10 | Garage as story: seller line and "why this now" per upgrade; buying earns one inbox message | Text under each upgrade | Garage |
| 11 | Rival record and temper on the freeze-cam: "KADE (boxer) 4-2 vs you"; beating a higher tier is called out | Cam caption | Duel result |
| 12 | Per-world ambience beds: Neon City hum + distant adverts + rain hiss; Canyon wind band + rock ticks; Grid pure tone bed + trail whine; ducked under the music | The world sounds different before you see it | In-run, title |

### Three notes

**Rival / contact card content.** Name, glyph portrait, temper, skill tier, cycle colour, record vs you, one taunt, one "tell" (KADE cuts inside on the second turn). Four trait words and a paragraph are the ceiling; a stat sheet is a floor. Badge at three sizes (chip, card, freeze-cam) framed in the rival's trail colour. Show before a duel and on the derez cam; never mid-job.

**Player identity, cheaply.** Callsign (typed once, uppercase, UserDefaults), a livery accent (one hue for trail, HUD accent and bike emissive), a title earned from rank ("GATE-RUNNER", "UNBOXED"). Show on the title screen, the duel name tag and the result card. No avatar editor.

**Adaptive music on synthesised stems.** Keep three stems, add rules: entry (pad on the briefing, bass on accept, arp on the first gate); a fourth percussive line gated by lead / boost, faded over one bar; pressure (filter cutoff and arp density follow the escape GAP bar or the zone radius); final stretch (112 to 118 bpm and a semitone lift at 75 %, on a bar with a two-beat stinger); finish (one-bar duck then slam); derez (hard cut to a detuned pad); per-world scales (Neon City minor pentatonic, Canyon mixolydian, Grid whole-tone). All transitions on bar lines.

### Sources

Christi Kerr and Game Developer on the Hades dialogue system; NFS Unbound, Heat and No Limits wikis and forums; Game Informer Unbound review; CSR2 wiki; Asphalt career guide and GamingBolt review; Nintendo Life and WayTooManyGames on Horizon Chase 2; Apple Developer and Backlog Crusader on Sayonara Wild Hearts; RPGFan and GameSpot on Tron: Identity; GamingTrend and TheGamer on Tron: Catalyst; Refract and Steam on Distance; The Fourth Focus and God is a Geek on Art of Rally; Alto's Odyssey wiki and press; Subway Surfers and Sonic Dash character pages; RL Sideswipe avatar wiki and Epic help; WipeoutZone and Wipeout wikis; Outsider Gaming on Star Wars Racer; F-Zero wiki, MuteCity and Nintendo Life on F-Zero 99; Ridge Racer wiki and Digital Chumps R4 retrospective; Burnout wiki; Mirror's Edge and Ghostrunner wikis, Shacknews; A Sound Effect on Cyberpunk 2077 sound; Hyper Light Breaker wiki; Gamezebo and TapSmart on DATA WING; TouchArcade on Riptide GP Renegade; Splice on Mario Kart 8 audio; ResetEra on dynamic racing soundtracks; AudioGameJam on adaptive music; GDC Vault "Storytelling in Small Spaces"; GameRefinery on mobile narrative.

---

## Report C: HUD and UI

### Per-game notes

| Game | Layout / type / colour | Motion and diegesis |
|---|---|---|
| Wipeout Omega / 2048 | Designers Republic: one condensed geometric sans, caps, tight tracking; every team a brand; thin HUD band; hairline gauges, big numbers | Restraint; weapon icon snaps in with a chime; energy flickers red |
| Redout 2 | HUD redesigned in 1.1 for speed: huge speed numeric bottom-centre, energy and heat as arcs framing it; single accent on near-black; gauges later pulled toward the vanishing point | RGB split and jitter for 2 to 3 frames on hit or hyperboost; boost = edge bloom + speed lines |
| Asphalt Legends | Nitro bar bottom-centre with the button under the right thumb; 44 pt+ targets; three control schemes | Nitro is the hero: fill, ready pulse, shockwave burst; stunt stamps fly in, count up, exit fast |
| Horizon Chase 2 | Flat 2.0; mini-map to the edge to protect the horizon; "less is more"; coin colour changed so it would not collide with track arrows | Colour-coded medals; snappy ~200 ms ease-out |
| Distance | Whole HUD diegetic on the car's rear window; thin neon lines | HUD pitches with the car, flickers when damaged |
| Sayonara Wild Hearts | Bold geometric sans; title cards are the song name set huge in the level palette | Cards slam in on the beat; wipes in the level colour |
| Thumper | Nearly HUD-less: score + multiplier chip | Feedback in-world; rank is a single huge letter with a bass hit |
| Hyperburner / Race the Sun | Thin sans, one accent per course, score alone at the top | Instant cut + tap to retry |
| RL Sideswipe | Three scalable movable buttons; boost arc around the button | Goal = full-screen stamp + slow-mo |
| Fast RMX / Aero GPX | F-Zero lineage: big speed bottom-right, energy doubles as boost fuel; phase chip large and colour-only | Boost pad = colour flash; low energy strobes |
| Tron: Identity / Catalyst | Angled lines, hex motif, neon on near-black, thin geometric type, single accent (orange for antagonists); white line controller glyphs; dialogue strip with speaker in caps | Panels draw on as lines then fill; text types in; quick, not bouncy |
| Cyberpunk 2077 | Yellow / cyan on dark, slight perspective, optional aberration; critique: too much information | One glitch effect per view; scanlines only where a screen exists |
| Ghostrunner | Minimal; ability cooldowns as thin arcs; black with red accents | Death = red glitch cut + one-tap retry |
| Hi-Fi Rush | Everything pulses to the global tempo; a metronome bar | Animations land on the beat |
| Persona 5 | One colour, sharp boxes; a line drawn across the screen guides the eye | Motion directs attention |
| Hades | Portrait left, name in caps, strip bottom; run summary lists boons with icons | One-liners, then a list |
| Alto's Odyssey | Three goals before a run; result: score, distance, coins, goals with ticks | Count-ups, gentle easing, world keeps moving behind |

Apple guidance (WWDC24 "Design advanced games", HIG Game Controls): 44 pt targets (28 pt minimum), body 17 pt+, less-essential 11 pt+, controls near the thumbs, hide unused controls, visible press state plus touch-down / up haptics, controller glyphs from `GCControllerElement.sfSymbolsName` (Xbox-layout Backbone shows A / B, the PlayStation edition cross / circle). Dynamic Island in landscape gives 59 to 62 pt side insets; home indicator ~21 pt; an unreported ~20 pt touch dead zone along the top edge in landscape. iOS 26's Game Overlay handles brightness, volume, Game Center and controller settings, so the in-game gear can shrink to game options.

### In-run HUD spec (390 x 844 pt landscape)

Insets 62 pt left / right, 24 pt top, 21 pt bottom, symmetric.

| Zone | Elements | Notes |
|---|---|---|
| Top-left | Job name (11 pt caps, dim) over timer (24 pt tabular) | Red under 10 s, digit roll |
| Top-centre | HULL as a 4 pt line, 180 pt wide, hairline ticks; ZONE in the Grid | No box; empty = 4 Hz strobe |
| Top-right | Score (20 pt) + streak chip, respawn pips, gear glyph | Chip scales 1.0 to 1.25 to 1.0 |
| Bottom-left | Speed 36 pt + "KM/H" 9 pt; altitude as a 3-tick ladder | Drop distance / hits / kills from the run |
| Bottom-centre | "Coming up" chip and section name (12 pt caps, letterspaced) | Slide up, hold 1.5 s, slide down |
| Bottom-right | BOOST and FIRE (touch only): 56 pt circles, boost arc around BOOST | Hidden with a controller |
| Centre band (y 35 to 55 %) | Stamps | Never persistent; one at a time |
| Edges | Boost vignette, damage flash, glitch on derez | Full bleed |

Hierarchy: speed and hull primary; score / streak secondary; the rest at 60 % opacity. Type scale: display 36 / 28 (stamps 44 to 56), heading 20, body 14, label 11 caps at +8 % tracking, tabular numerals. Colour roles: accent = the world's road colour, danger = ring red, reward = obstacle lime, rival = orange, text 90 % white, backgrounds none or a hairline + 30 % gradient over bright sky.

Motion language: enter = draw-on line (180 ms ease-out) then text fade 120 ms; exit = 100 ms fade + 4 pt slide; pulse = 1.0 to 1.15 to 1.0 over 220 ms on any increase; count-up via `contentTransition(.numericText)` 300 to 600 ms; glitch = 2 px RGB split + one or two slice offsets for 3 frames, one effect per moment; stamp = spring 1.6 to 1.0 (0.25 s), hold 0.6 s, glitch out, quantised to the next eighth; boost = elements slide 6 pt outward, accent brightens, edge aberration.

Controller glyphs: SF Symbols from `sfSymbolsName` (`r2.button.roundedtop.horizontal`, `a.circle` / `xmark.circle`, `l.joystick`, `line.3.horizontal.circle`), 14 pt, white 70 %, in hint chips and on ACCEPT. Touch: steering across the left half; BOOST / FIRE 56 pt with a 12 pt gap, press state = fill flash + light impact.

### Between-run screens

| Screen | Spec |
|---|---|
| Title / attract | Scene loops behind (demo camera); wordmark large and low-left; "PRESS A / TAP TO START" pulsing at tempo; credits and world chips top-right; no boxes; idle 20 s = attract run with the HUD hidden |
| Job briefing | Left 55 %: chapter, title (28 pt), brief (3 lines max), goal line with icon, pay in accent. Right 45 %: portrait in an angled frame, name, role; garage as a LOADOUT row of four icons. Bottom: inbox strip (id + medal), wide ACCEPT with the A glyph. Enter: draw-on lines, text types in over 400 ms, portrait fades with a one-frame glitch |
| Rival card | Full-height portrait right, name huge, temper as three ticks, W-L record, one taunt; rival colour takes the accent; slams in on DUEL start, holds 1.2 s, the HUD name tag inherits the colour |
| Result / debrief | Reveal 150 ms apart: rank letter (56 pt, spring + bass hit), score count-up, flag chips, debrief typed in, credits count-up with delta; RETRY left, NEXT right; "REPLAY 50 %" tag; scene keeps moving |
| Garage | Four tiles with icon, level pips, price; selected tile expands with a one-line effect; buy = tile fills with a credit count-down; stick moves, A buys, B backs |
| Inbox / message log | Rows: sender initial in a hex, subject, time-ago, unread dot; split view opens the brief; new row draws on with a glitch and a tick |

Common frame: black 60 % gradient with 1 px accent hairlines top and bottom, one corner cut at 45 degrees; no rounded frosted boxes.

### Ranked upgrades

1. Typeface swap + type scale (low): Chakra Petch or Rajdhani for display and labels, SF Mono only for timers.
2. Kill the boxes (low): bare text, hairlines, gradients; drop distance / hits / kills / hint line from the run.
3. Numeric roll and pulse (low).
4. Controller glyphs from `sfSymbolsName` (low).
5. Stamp choreography (medium): one `StampView`, spring in, hold, glitch out, beat-quantised.
6. Result card reveal sequence (medium).
7. Boost state in the HUD (medium).
8. Shared glitch shader (medium) for hit, derez, curtain and card transitions.
9. Diegetic hull / boost arcs behind the vehicle (medium-high).
10. Rival card slam + coloured name tag (medium).
11. Beat-synced UI clock (medium-high).
12. Touch press states + haptics (low).

### SwiftUI notes

Fonts (SIL OFL, bundle via `UIAppFonts`): Chakra Petch (square, tapered corners, holds at 11 pt; closest to Tron / Wipeout), Rajdhani (condensed), Exo 2 (all-rounder), Orbitron and Michroma (display only). `.monospacedDigit()` for tabular numbers. Animation: `withAnimation(.spring(duration:bounce:))`, `contentTransition(.numericText(countsDown:))`, `PhaseAnimator`, `KeyframeAnimator`, `TimelineView(.animation)` + `Canvas` for arcs and beat pulses, `symbolEffect(.bounce)`, `sensoryFeedback`. Shaders (iOS 17+): `.colorEffect` for RGB split, `.layerEffect` for slice glitch and edge bloom, `.distortionEffect` for the curtain; twostraws/Inferno has ready-made aberration, noise and CRT shaders; `TextRenderer` (iOS 18) for type-in and per-letter glitch. Avoid `.ultraThinMaterial` boxes; use gradients and 1 px hairlines; `.blendMode(.screen)` for neon accents. Layout: `ignoresSafeArea()` for vignette layers only; HUD inside the safe area plus a manual 20 pt top buffer.

### Sources

WWDC24 10085 Design advanced games; HIG Game Controls; GCControllerElement docs; WWDC21 10081; Apple Newsroom on the Games app (2025) and Apple Design Awards 2025 / 2026; the landscape safe-area gist; Interface In Game and HUDs and GUIs on Cyberpunk 2077 and Tron: Legacy; Game Developer and Akiiira on Horizon Chase UI; Wipeout logo history; Game UI Database entries for Wipeout Omega, Redout 2, Tron: Identity, Hi-Fi Rush, Hades, Sayonara; Redout 2 1.1 patch notes; Game Rant Redout 2; TV Tropes Distance; Apple on Sayonara; Thumper scoring guide; AppSpy Hyperburner; Ginx on RL Sideswipe controls; Wikipedia Fast RMX and Asphalt Legends Unite; Behance Ghostrunner UI; Unreal on Hi-Fi Rush; Siliconera and Persona Central on Persona 5 UI; Interface In Game Hades; AppUnwrapper Alto's Odyssey; GDC Vault Juice It or Lose It; Google Fonts Chakra Petch, Oxanium; SwiftCrafted on contentTransition and animations; twostraws/Inferno; Jacob's Tech Tavern on Metal in SwiftUI.

---

## Report D: RealityKit / Metal architecture

Scope: Swift + RealityKit (ARView) + Metal post pass, iPhone 12 (A14, 60 Hz) floor, iOS 18 to 26. Effort: S under a day, M 1 to 3 days, L 1 to 2 weeks.

### Feature availability (Apple doc metadata, Sept 2026)

| Feature | API | Min OS (iOS / macOS) | visionOS-only | Note |
|---|---|---|---|---|
| Post hook on ARView | `ARView.renderCallbacks.postProcess` (`PostProcessContext`: device, commandBuffer, source colour / depth, target, projection, time) | 15 / 12 | No | In use today |
| Post hook on RealityView | `content.renderingEffects.customPostProcessing = .effect(...)` | 26 / 26 | No | Same context shape; DTS confirms `sourceDepthTexture` is populated (reversed, non-linear) and the simulator's depth is poor |
| Built-in effect toggles (RealityView) | `RealityViewRenderingEffects`: `antialiasing` (`.none` / `.multisample4X`), `dynamicRange`, `motionBlur`, `depthOfField`, `cameraGrain` | 18 / 15 | No | The only public MSAA switch; ARView has only `renderOptions` disables. Whether built-in motion blur is per-object is uncertain: test on a moving world |
| Bloom / tone-mapping components | `BloomComponent`, `BloomOptionsComponent`, `ToneMappingComponent` | 27 / 27 | No | Outside the window; keep the custom bloom |
| Metal custom materials | `CustomMaterial` (surface shader, geometry modifier, `custom.value/.texture`, depth flags, blending); WWDC25 adds a `LowLevelBuffer` per-instance path | 15 / 12 | Absent on visionOS | The right tool on iOS / macOS |
| ShaderGraph | `ShaderGraphMaterial`, `setParameter` | 18 / 15 | No | Per-frame parameters are slower than `custom.value` |
| GPU instancing | `MeshInstancesComponent` + `LowLevelInstanceData` | 26 / 26 | No | Below 26: merged `LowLevelMesh` batches |
| Per-frame geometry / textures | `LowLevelMesh`, `LowLevelTexture` | 18 / 15 | No | `LowLevelTexture` can replace launch-time CGImage generation with compute |
| LOD | `LevelOfDetailComponent` | 27 / 27 | No | Roll your own by scroll distance |
| Environment lighting | `ImageBasedLightComponent`, `EnvironmentResource.generate(fromEquirectangular:)`, skybox | 18 / 15 | No | iOS 18.0 to 18.1 IBL regressions, fixed 18.2 |
| Lights and shadows | Directional and spot cast shadows; point lights do not; `DynamicLightShadowComponent` per entity | 13; opt-out 18 | No | Community says 8 dynamic lights max; soft shadows and projective spot textures in 27 |
| EDR | `RealityRenderer.extendedDynamicRangeOutput`, `RealityViewRenderingEffects.dynamicRange` | 18 / 15 | No | iPhone 12 has little headroom |
| Particles | shapes, `burst()`, `spawnedEmitter`, `imageSequence`, `stretchFactor`, noise / vortex / attraction fields | 18 / 15 | No | No ribbons, no custom shader |
| Occlusion / video materials | `OcclusionMaterial`, `VideoMaterial` | 13 to 14 | No | Video material for animated ad-boards |
| Portals | `PortalComponent`, `PortalCrossingComponent` | 18 / 15 | No | Could sell corridor-to-Grid |
| Offscreen render | `RealityRenderer` into your own `MTLTexture` | 18 / 15 | No | The route for runtime portraits |
| SwiftUI attachments on entities | `ViewAttachmentComponent`, `PresentationComponent` | 26 | visionOS-only | Keep SwiftUI as an overlay on iOS |
| Animation | `BlendTreeAnimation`, `playAnimation(transitionDuration:blendLayerOffset:)`, `AnimationLibraryComponent`, IK | 15 / 18 | No | Bug: blend shapes stop updating during a skeletal clip |
| MetalFX | spatial scaler 16; temporal A14+; frame interpolation 26 | 26 | Unavailable on visionOS | Only via `RealityRenderer`; A14 interpolation support unverified |
| Metal 4 | | 26; A14+ | No | Ray tracing A17 Pro+ |
| Game Mode | automatic for the Games category | 18 | No | Set `LSApplicationCategoryType` |
| RealityView on iOS / macOS | `RealityView` + `RealityViewCameraContent` | 18 / 15 | No | The gate to MSAA, `dynamicRange` and the 26 post hook |

### Technique map

Shared enabler: a half-resolution linear depth + velocity buffer each frame. Because the world moves rigidly past a fixed vehicle, per-pixel velocity is reprojection: reconstruct view-space position from depth, transform by (previous world x current inverse), take the screen delta (GPU Gems 3 ch. 27). The vehicle stays sharp for free.

| Technique | Lives in | iPhone 12 @ 60 | Effort | Depends on |
|---|---|---|---|---|
| Speed lines / radial blur | Post | Yes | done | |
| Camera-motion blur (velocity) | Post | Half res, 6 to 8 taps | M | Depth + velocity; linearise reversed depth |
| Per-object blur | RealityView built-in | Unknown; test | S | RealityView |
| Heat haze / thruster distortion | Post: UV offset from scrolling noise masked by projected thruster positions x boost, depth-tested | Yes | S | Thruster clip-space positions as uniforms |
| God rays | Post: GPU Gems 3 ch. 13 radial from the projected sun / sign, bright pass as occlusion, half res, 48 to 64 taps | Yes | S-M | Bright pass |
| Wet-road reflection | Mirrored near geometry under a semi-transparent road (S) or planar SSR on the road plane (M) | Yes | S / M | Depth; roughness mask |
| Lens flare / dirt | Post: ghost chain from the bright pass + dirt mask x bloom | Yes | S | Bloom chain |
| Sky dome, stars, aurora | Inverted sphere with unlit `CustomMaterial` or per-world `EnvironmentResource` | Yes | S-M | IBL |
| Distance layering | 2 to 3 parallax billboard rings with emissive silhouettes (tilt 0.01 rad) | Yes | S | |
| Crowd / traffic impostors | Sprite-sheet quads; `MeshInstancesComponent` on 26 | Yes | M | |
| Decals | Thin quads `readsDepth` true / `writesDepth` false, additive; or baked into a per-segment `LowLevelTexture` | Yes | S | No decal projector exists |
| Emissive-driven bloom | Emissive > 1.0 as the only bloom source; threshold ~1.0 | Yes | S | HDR intermediate |
| Dithering | Interleaved-gradient or blue noise before the 8-bit write | Free | S | |
| Anti-aliasing | RealityView `.multisample4X` | Yes | S after migration | RealityView |
| Grading LUT | 32^3 3D LUT baked from ACES + per-world grade | Cheaper than now | S | Offline bake |
| Glitch / scanline / datamosh | Post: block-quantised velocity, previous frame reuse, line dropouts | Yes | M | Velocity + previous colour |
| Derez | `CustomMaterial` dissolve (discard by 3D noise threshold from `custom.value`) + `burst()` with a cube sprite; voxel shatter via `LowLevelMesh` cubes | Yes | M | |
| Volumetric fog slices | Post: height + noise over 4 to 6 depth steps | Yes | M | Linear depth |

### Architecture recommendation (in order)

1. **Post pass v2 first.** A small graph with a shared prologue (linear depth, velocity, previous colour, half-res bright pass) behind a `PostPipeline` protocol so the iOS 26 RealityView hook drops in later. ACES + grade to a LUT, add dithering, per-world effect stacks in `Theme`.
2. **Scene lighting and batching.** One `EnvironmentResource` per world (sky + IBL), emissive discipline, merged `LowLevelMesh` city batches with a `MeshInstancesComponent` path gated on 26. Consider the RealityView migration for MSAA 4x and `dynamicRange`; the ARView touch gotcha disappears.
3. **Presentation layer.** An `AppFlow` state machine (title / attract, briefing, run, debrief, inbox / garage) in SwiftUI over the persistent RealityKit view; attract mode is the demo camera behind a dimmed overlay. Portraits via `RealityRenderer` into a `MTLTexture`, cached. Avatar animation via `AnimationLibraryComponent` crossfades and `BlendTreeAnimation` weights; do not rely on blend shapes during clips.
4. **Narrative data layer.** A JSON DSL (node id, speaker, lines, conditions on flags, triggers) is enough for eighteen jobs; `InkSwift` is a native pure-Swift Ink runtime if branching grows; no official Yarn Spinner Swift runtime.
5. **Audio director.** Stay on `AVAudioEngine`: one `AVAudioTime` start, bar-quantised layer changes via `lastRenderTime`, sidechain by animating mixer volumes on `ActionAck`. FMOD / Wwise not needed yet.
6. **Haptics director.** One `CHHapticAdvancedPatternPlayer` continuous engine event with `sendParameters` per frame; AHAP files for hits, boost, derez.
7. **Game Center.** `GKAccessPoint`, classic and recurring leaderboards per job; challenges come free on iOS 26.
8. **Skip for now:** MetalFX and Metal 4 (only reachable via `RealityRenderer`; interpolation buys nothing at 60 Hz on an iPhone 12).

### Worth studying

`dabit3/macos-experiments` (Drift Picnic, Starcap Circuit: SwiftUI + SceneKit racers with synthesised audio and XcodeGen); `rwrife/neon-racer` (adaptive synthwave stems, reduced-flash options); `metal-by-example/metal-spatial-dynamic-mesh`; `artyommihailovich/RealityKitPostProcessMetal`; Apple's "Implementing special rendering effects with RealityKit postprocessing"; Redout 2 Unreal blog; GPU Gems 3 ch. 13 and 27; Playdead INSIDE (dithering); School of Motion's Tron rezzing breakdown.

Uncertain: built-in `motionBlur` on a moving world; A14 MetalFX interpolation; the 8-light limit (community); whether ARView preserves alpha in the colour texture.

### Sources

WWDC25 287 What's new in RealityKit; WWDC26 279 Explore advances in RealityKit; WWDC24 10103; Apple docs for postprocessing effects, RealityViewRenderingEffects, RealityRenderer, MeshInstancesComponent, LowLevelMesh / LowLevelTexture, ParticleEmitterComponent, CustomMaterial, ShaderGraphMaterial, ImageBasedLightComponent, EnvironmentResource, shadows, DynamicLightShadowComponent, PortalComponent, BlendTreeAnimation, ARView.RenderOptions, BloomComponent, MTLFXFrameInterpolatorDescriptor, GKAccessPoint, Core Haptics; forum threads 806524 (RealityView depth) and 793431 (blend shapes); WWDC25 211 Go further with Metal 4; tech talk 111372 on MetalFX tiers; Apple support 102894; 9to5Mac on Game Mode; WWDC25 214 Game Center; WWDC21 10278 audio haptic design; Medium on AVAudioPlayerNode timing; InkSwift, SwiftInk, YarnSpinnerTool; Bugnet FMOD vs Wwise; GPU Gems 3 ch. 27 and 13, GPU Gems 2 ch. 24; Playdead publications; Unreal Redout 2 blog; School of Motion Tron; the open-source repos above.

---

## Report E: Character Creator 5 / iClone 8 to RealityKit pipeline

### Export paths that end in RealityKit-loadable USDZ

| Path | Skeleton + skin anim | Facial morphs | Materials | Verdict |
|---|---|---|---|---|
| CC5 "Export USD" (Omniverse Connector plug-in) | Yes (clips selectable) | Not documented | Omniverse RTX / MDL-style | Not a RealityKit path as-is; unverified for CC5 |
| FBX to Blender (cc_blender_tools) to USD / USDZ | Yes (Blender >= 4.1 exports UsdSkel) | Yes if "Shape Keys" is ticked under Rigging | Rebuilt as Principled BSDF to UsdPreviewSurface | Recommended; it is the route already in use |
| FBX to Blender to GLB to Reality Converter | | | | Dead: Reality Converter is no longer downloadable (Apple forum, June 2025) |
| FBX to fbx2usd (apparata) | Yes, <= 4 influences, one USD per take | No blend shapes | UsdPreviewSurface / MaterialX | Body-only clips; no talk |

Caveats on the recommended route: the Digital Human shader features that do not survive PBR (SSS masks, micro-normal overlay, anisotropic hair flow, tear-line and eye-occlusion shaders); base colour / normal / roughness / metallic survive, and for helmets and suits that is enough. Delete the tear-line and eye-occlusion overlay meshes before export (layered transparency flickers in RealityKit). Hair cards should be cutout (`opacityThreshold`), or use a helmet. CC FBX is centimetres Y-up; export USD Y-up with metersPerUnit 1 and check the character is ~1.8 m. Pack roughness / metallic / AO into one RGB. cc_blender_tools 2.4.x supports CC5 and Blender 4.5 to 5.1; Apple's Blender 4.2 advice: tick Shape Keys under Rigging, untick "Convert World Material"; only the Armature modifier is honoured on export.

### Budgets for a phone-rendered character

| Item | CC5 tool | Notes |
|---|---|---|
| Base topology | Game Base conversion (~10k-triangle base) | Single-material option merges skin, tongue, eyelashes, nails |
| Reduction | InstaLOD polygon reduction by wearable or element | Cloth, hair, shoes, accessories |
| LODs | Remesher: multiple LODs, merge meshes | One LOD is enough for a briefing card |
| Textures | Merge materials + bake, 512 to 4K | One 2K atlas per character |

Estimate (not a published number): hero character 20 to 35k triangles, one 2048 atlas plus a 512 emissive strip map, two materials (opaque, cutout). One live character beside the bike is comfortable, two is fine; rivals should be 2D portraits, not live models.

### iClone 8 animation

- Idle / gesture: Motion Director idle and perform behaviours; Motion Puppet records upper-body talking-with-hands over an existing stance; ActorCore idle and conversation packs.
- Lip sync: AccuLIPS from audio + text (no capture rig). AccuFACE captures from webcam / video but needs an NVIDIA RTX GPU; CC5 / iClone are Windows-only. CC characters carry the ARKit 52 set (63 with tongue) in the Standard profile, 140 in Extended / ExPlus.
- Clips: iClone FBX "Save One Take per File" gives one FBX per clip; bake facial animation via MotionPlus with "Convert Skinned Expressions to Morphs" and "Delete Unused Morphs".
- Several clips in one USDZ: Blender exports one animation per USD file. Apple's answer is NLA end-to-end and cutting in Reality Composer Pro's AnimationLibraryComponent; simplest for this code base is one USDZ per clip and `availableAnimations[0]` from each (clip names come from the SkelAnimation prim, so name the Blender action).
- The blend-shape bug: Apple forum thread 793431 confirms RealityKit stops applying `BlendShapeWeightsComponent` weights while a skeletal clip plays on the same entity; unresolved.
- Talking portrait (3 to 6 s loop), in order of safety: (1) render the talk in iClone to HEVC-with-alpha video and play it in the SwiftUI HUD (exact lip sync, zero RealityKit risk); (2) live 3D with no skeletal clip during the talk, blend-shape weights driven per frame from a baked weight table (ARKit curves exported as JSON from Blender) plus a small procedural neck sway via `skeletalPoses`, then back to the skeletal idle; (3) uncertain: whether a USD clip animating `blendShapeWeights` inside SkelAnimation plays at all in RealityKit (thread 770449 says RCP did not import such animation); test in the proof, do not plan on it.

### Portrait rendering

iClone renders 32-bit PNG (and EXR) with alpha when no background image is active; cameras are keyframable so a 12-frame turntable is one render. Badge spec: 1024 x 1024 PNG, alpha background, head and shoulders, helmet on, eye line at 55 % height, key + cool rim light matching the world palette (cyan Neon City, amber Canyon, white Grid), shipped at 512 pt; a 2048 master for the briefing card. Runtime RealityKit portraits cost a second lit pass on an iPhone 12 and never match an iClone render; pre-render badges, keep the live model only beside the bike.

### Licensing

Standard licence covers commercial games; for CC Components (ccAvatar, ccHair, ccCloth, ccShoes, ccGloves, ccSliders, ccProjects) it covers one character output per component; Extended (about 3x the price, not upgradeable) allows unlimited characters; Enterprise is negotiated. Base content embedded in iClone 8 / CC4 carries the Extended licence (the policy page does not yet name CC5). What bites: no in-app purchase of Reallusion-derived content; no player-driven character customisation without Enterprise (automatic outfit swaps are fine); no redistribution of source assets (a USDZ in the bundle is incorporated output, allowed, but never expose it as a download). Avoid the iContent licence (cannot be exported). ActorCore uses the same EULA (updated 1 Aug 2025). With four named characters, Standard licences on purchased components suffice; Extended only if one purchased suit or helmet is reused across rivals.

### Recommended pipeline and effort

1. CC5 (Windows): build from a CC5 base, convert to Game Base, single-material skin, helmet and suit as props, ARKit facial profile, InstaLOD on wearables, merge textures to a 2K atlas.
2. iClone 8: idle (ActorCore or Motion Director), talk gesture (Motion Puppet), AccuLIPS from text + audio; bake to MotionPlus; FBX export with the Blender preset, one take per file, morphs on, textures <= 2048.
3. Blender 5 + cc_blender_tools: import, delete tear-line / occlusion meshes, bake to Principled, apply modifiers, name actions; USD export with Armature + Shape Keys, Y-up, no world material; one USDZ per clip.
4. Verify in RealityKit: scale, `availableAnimations`, `BlendShapeWeightsComponent` names; test blend shapes with and without a playing clip.
5. Portraits from iClone: alpha PNG 1024^2, turntable optional.

Effort: the first character (proof: one idle, one talk clip, one portrait) 2 to 3 days, mostly discovering the blend-shape behaviour and the material rebuild; each further character roughly one day. Do the proof on the player character and decide video-vs-live talk from step 4 before building rivals.

### Sources

CG Channel on the CC5 release; Reallusion manuals for the Omniverse Export USD panel, CC5 Game Base, iClone FBX export and batch export, ARKit profile, Motion Director, Motion Puppet, AccuFACE course, transparent video export, PNG alpha render; soupday/cc_blender_tools and issue 230; Blender 4.1 release notes (USD skeletons); Apple forum threads 766484 (USDZ blend shapes), 793431 (blend shapes stop during clips), 797061 (multiple animations), 788633 (Blender armatures, Reality Converter), 806872 (transparency flicker), 807893 (Reality Converter status), 770449; apparata/fbx2usd; Reallusion game pipeline and Digital Human shader pages; WWDC24 10186 asset budgets; Reallusion content licence policy, EULA, staff forum posts on licences and the Extended multiplier, iContent licence announcement.
