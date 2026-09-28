# Kickoff prompt for the next thread: the phone pass (sound, feel, balance), then the message log and the title screen

Paste the block below as the first message of a new Claude Code thread opened in
`/Users/markbailey/Desktop/GS - GamenCtr/GS - Racer`. On 18 Sep 2026 three passes landed on branch
`claude/game-prototype-assessment-chlzto` (PR #2, https://github.com/bailey0002/cycleracer_swift/pull/2):
the assessment pass and the second pass (written blind on Linux) and a third pass on the Mac that
built them, verified them with captures (`Captures/polish/p6/`, `docs/polish-log.md` third-pass
section) and fixed what the captures showed. Everything that needs a phone is still owed.

---

Read `CLAUDE.md` in this workspace first, then `SpeederProto/README.md` ("Assessment pass" and
"The game"), the last two sections of `SpeederProto/docs/polish-log.md`, and
`SpeederProto/docs/assessment-2026-09-18.md` ("Still owed" lists).

**0. Branch and build.** `git checkout claude/game-prototype-assessment-chlzto` (merge master into
it if master moved), `cd SpeederProto && xcodegen generate`, the Mac build from `CLAUDE.md`. A
device binary from the last thread is in `build-device/` but rebuild after any change. Ask the
user to wake and unlock the phone, then install and launch (command in the README).

**1. The phone pass with the Backbone** (nothing here can be verified from the Mac):
- Sound: the engine loop must sit under the cues; hit / kill / gate / tick / section entry audible;
  the alarm loop only when hull is low, the pursuer is close or the edge is low. If the `.ambient`
  session category is buried under other audio, switch to `.soloAmbient`. Tune the `gain`
  constants in `SoundEngine.synthesise()` and `renderMusic()`; the pad under the cards, the bass
  on the run, the arp on boost / streak x4 / a close pursuer / a grind / the zone. The layers must
  swell in over a bar and never click at the loop point; drop the pad's saw component if it is
  muddy on the speaker.
- Input on the briefing: stick left / right browses the inbox (the chip scrolls into view), up /
  down highlights the garage, Y buys; tap on chips and rows does the same. A quick still tap fires
  on the run. Replay a cleared job: it pays half and the card says so.
- Play DUEL 01 to the end by hand (the capture proves the rebuild into the canyon, not the feel);
  free play on The Grid afterwards must be first to three; try to get a double derez and read
  VOID ROUND; a cut-off must read `CUT OFF BY KADE`, an own-trail death `BOXED YOURSELF`.
- The HELMET stamp, the `+1.5 s` on gates, the one-tap retry on the failed card, SALVAGE 01
  failing on missed targets, DIVE 01 with no bolts and the double bruise.

**2. Balance from the phone** (first guesses, all in `Mission.deliveries`, `Upgrades.items` and
`Rival.Skill`): chapter-3 density 1.3, the dive windows 62 / 68 s, garage prices assuming about
1,000 credits per chapter, the KEEN tier's 0.10 s tick. A clean run should be gold, a sloppy one
bronze. Log the numbers you change in `docs/polish-log.md`.

**3. If there is time**: a contact message log (the debriefs, reread from the briefing);
controller glyph chips from `sfSymbolsName` on first relevance; a title screen with the last
job's card; the round clock and the zone spin-up on The Grid; a headless 60 Hz test loop over
`MissionRunner` and `ArenaController` (the pure parts) so the boost flicker / accept-edge class
of bug is caught without captures.

Capture aids from the last thread: `Captures/polish/capture.sh` (Mac), `Captures/polish/simshot.sh`
(simulator, delays from launch), `SPEEDER_ARENA_KILL_RIVAL=<s>` to win duels in a demo,
`SPEEDER_ARENA_IMMORTAL=1` to watch the rival for a whole run, `SPEEDER_MISSION=<n>` now unlocks
the chain up to n. Run long arena logs one at a time (parallel instances starve the frame rate).

Keep the two corridor looks unchanged unless a change is clearly a fix. Push every meaningful build
to the phone. Log in `docs/polish-log.md`, keep `README.md` and `CLAUDE.md` current, update the
memory files, and finish by writing the next kickoff prompt into this file.

---

## After the phone pass: the presentation foundation (added 26 Sep 2026)

Read `docs/assessment-2026-09-26-market.md` (sections 6 to 8). Build pass 1 in that order: C1 (display
face, hairlines, debug block and hint line off the run, Island insets), C2 (controller glyphs from
`sfSymbolsName`, 56 pt touch buttons with press states), B1 (the boost scalar reaches vignette,
exhaust and HUD; centre-weighted grade), A2 (edge cadence strips, road decals), A3 (blob shadow,
ground glow, scrape sparks, thruster haze), D2 (callsign + livery accent), D5 (comms stamps), D8
(continuous haptic engine). Run the five proofs in section 8 first where they gate a choice; keep the
frozen Neon City frame as the A/B baseline; verify with `Captures/polish/capture.sh` and
`simshot.sh` at the p6 times; log in `docs/polish-log.md`; push to the phone.

---

## Status 26 Sep 2026 (later the same day): pass 1 is built

Pass 1 above is done and verified (`docs/polish-log.md`, pass 1 section). The phone was locked, so the
device binary in `build-device/` was not installed: install and launch it first (README command). Then
the phone checks pass 1 needs: the touch BOOST / FIRE buttons without the Backbone, the engine hum and
the hit / boost rumble through the phone with the Backbone, the callsign keyboard, the livery tint on
The Grid. Then pass 2 (assessment section 7): A1 layered horizon and sky dome, A4 brand typography,
A5 Neon City rain, B2 the post-pass prologue (linear depth, velocity, previous frame), B3 outer-ring
motion blur, lens dirt, dithering, LUT, then A7 hot Grid trails and the dissolve derez. Keep the frozen
Neon City frame as the A/B baseline (`Captures/polish/p7/cruise/`).

---

## Status 26 Sep 2026 (end of day): passes 1 to 4 are built

All four passes of `docs/assessment-2026-09-26-market.md` are built, capture-verified and on the phone
(`docs/polish-log.md`, pass 1 to pass 4 sections; `Captures/polish/p7/`), except the parts that need
Mark or another thread: D4 (the cast through Character Creator 5 / iClone 8, on Windows; report E in
`docs/research-2026-09-26-reports.md` has the pipeline and the two-day proof), B4 (RealityView
migration), A6 (building archetypes and batching), D9 (Game Center, needs App Store Connect).

Next thread, in order:
1. The phone pass with the Backbone: the title screen and the START prompt, touch buttons without the
   pad, the engine hum and the rumble through the phone, the mix (pad / bass / arp / drums levels,
   the final-stretch lift, the ambience beds, the tunnel reverb; knobs in `SoundEngine.renderMusic`,
   `ambienceLoop`, `setAmbience`), frame time with `motionBlur` and `lensFX` on an iPhone 12, the rival
   card's timing by hand, the callsign keyboard, the livery tint on The Grid.
2. Balance (unchanged from the earlier kickoff): chapter-3 density, the dive windows, garage prices.
3. D4 proof on the player character, then the four contacts / rivals; the portrait PNGs replace
   `ProceduralTextures.portrait` through `Rival.portrait(for:)`.
4. Then B4 on its own branch with the capture sweep as the gate, A6 behind an iOS 26 check, D9.

---

## Status 26 Sep 2026 (evening): the front end is built

PR #2 is merged into master. The front end (splash with launch screen and app icon, title menu with
CONTINUE / FREE PLAY / SETTINGS, persisted player settings, first-run rider step, pause menu, the
developer panel hidden behind five taps on the version line) is on branch `claude/front-end`
(`docs/polish-log.md` last section, README "Front end"). The phone now gets a Release build (README
command); it was installed and launched on the iPhone 12 (ready 3.9 s after launch).

Next thread, in order:
1. The phone pass with the Backbone, now including the front end: the launch screen and splash on the
   device (reboot the phone if the old black launch screen is cached), menu navigation and the pad
   callsign entry, the keyboard callsign in landscape, the haptics switch, MUSIC / EFFECTS levels by
   ear, GRAPHICS presets against the frame rate (BALANCED if HIGH drops frames on the iPhone 12), then
   everything in the earlier list (touch buttons, hum and rumble, the mix, the rival card, livery tint).
2. Balance (unchanged): chapter-3 density, the dive windows, garage prices.
3. D4 proof on the player character (CC5 / iClone 8), then the contacts; the title screen can then show
   the rider beside the bike.
4. Front-end follow-ups if wanted: an attract run after 20 s idle on the title (the demo drive with the
   HUD hidden), a message log (the debriefs, reread from the title), controls remapping, the
   `WorldScroller` build (1.6 to 2 s on the main thread) moved into smaller steps so the splash is shorter.
5. B4 on its own branch with the capture sweep as the gate, A6 behind an iOS 26 check, D9.

---

## Status 27 Sep 2026: the story pass is built

Read `docs/assessment-2026-09-27-story.md` first (the narrative assessment, the research on GTA / Driver /
NFS / Hades-class comparables, and the recommendations). Sections 5.1 to 5.4 are built on branch
`claude/story` (off master after PR #3 was merged): the spine (routes as the MacGuffin, the player's own
route in the ledger, a real ending), the message log (`Missions/MessageLog.swift`; MESSAGES on the title
and pause, the envelope chip on the briefing), chapter cards (`Phase.chapter`), and the rival's voice in
the duel (`Debrief.rivalLine`). Logged in `docs/polish-log.md` (story pass), shots in `Captures/polish/p9/`.

Next thread, in order:
1. The phone pass with the Backbone (unchanged from the 26 Sep list: launch screen, menu and callsign,
   haptics, MUSIC / EFFECTS by ear, GRAPHICS vs frame rate, touch buttons, hum and rumble, the mix, the
   rival card, livery tint), plus the story pass on the phone: the chapter card on a 390 pt screen,
   Menu -> MESSAGES from a briefing, the rival's line by eye mid-duel, the `??` static line's monospace
   face on the phone.
2. Balance (unchanged): chapter-3 density, the dive windows, garage prices.
3. Assessment 5.5, agency: after a chapter's first job unlock its next two at once (the chapter's duel
   stays gated on all of them); flag-gated side offers in the inbox reusing existing jobs with a modifier
   and a different sender; one debrief variant per fork branch (`WorldScroller` knows the branch taken).
4. D4, the cast through CC5 / iClone 8 (Mark, Windows): portraits first (alpha PNG, three sizes, replacing
   `ProceduralTextures.portrait` through `Rival.portrait(for:)`; the unknown state on the chapter card
   blurs them), then talk clips at three moments only (briefing accept, result card, chapter card), under
   four seconds, video-in-HUD per report E. The script is now locked in `Mission.deliveries`,
   `Debrief.swift` and `MessageLog.swift`.
5. B4 on its own branch with the capture sweep as the gate, A6 behind an iOS 26 check, D9.

## Status 27 Sep 2026 (evening): headless tests, balance, agency

Branch `claude/phone-pass` off master (PRs #3 and #4 merged). The phone was locked all thread: the
Release build is installed on the iPhone 12 but was never launched, so nothing on the phone list
below is verified. Built and verified on the Mac and the simulator (`docs/polish-log.md`, last
section; `Captures/polish/p10/`): the headless 60 Hz test loop (`Tests/MissionLoopTests.swift`,
fourteen tests, three seconds), the balance numbers from it (windows, purse, garage; the table is in
the log), and assessment 5.5 (two jobs open at once, three side offers, the fork acknowledged).

Step 0 for the next thread: branch off master once this PR is merged, `xcodegen generate`, the Mac
build, then `xcodebuild test` (the README's "Headless tests" command) before touching anything.
Install and launch the phone (README command; ask Mark to unlock it first).

Next thread, in order:

1. The phone pass with the Backbone, unchanged from the 27 Sep list (launch screen, menu and
   callsign, haptics, MUSIC / EFFECTS by ear, GRAPHICS vs frame rate, touch buttons, hum and rumble,
   the mix, the rival card, livery tint, the chapter card, Menu -> MESSAGES, the rival's line, the `??`
   line), plus this pass on the phone: the new windows by feel (if the 30 % margin feels mean with real
   steering, raise it in one place: the comment over `Mission.gateSpacing` gives the rule), the garage
   prices against the purse after chapter 1, the amber offer chip and its briefing on a 390 pt screen,
   the tunnel offer ridden both ways (the skyway must fail `TOOK THE SKYWAY`), the fork line on the card.
2. Balance still unmeasurable from the Mac: the chapter-3 density (1.3) and the KEEN tier's 0.10 s
   tick (`Rival.Skill`), by play.
3. D4, the cast through CC5 / iClone 8 (Mark, Windows), unchanged: portraits first, then the three
   talk moments. The script is locked in `Mission.deliveries`, `Mission.offers`, `Debrief.swift` and
   `MessageLog.swift`.
4. If there is time: extend the loop to the arena's pure parts (`LightCycle.step`, `TrailSystem`
   collision) so a rival's own-trail death and the accel curve are asserted without captures; the
   round clock and the zone spin-up on The Grid.
5. B4 on its own branch with the capture sweep as the gate, A6 behind an iOS 26 check, D9.

## Status 28 Sep 2026: generated art, first pass

Mark's first image batch (see `docs/art-brief.md`) is wired in on `claude/phone-pass` (`docs/polish-log.md`,
"Generated art"; `Captures/polish/p11/`) and on the phone. On the phone, check: the facades up close at
speed (tile scale, the emissive level 1.25), the storefronts at street level, the skyline strip in the haze,
the Grid bowl (dim by design at `fogMax` 0.35 and `lift` 4; raise or lower both) and the hanging screen,
and the frame rate with the extra textures (about 14 MB). Then the next batch from the brief: the canyon set,
the crowd strip, far / mid skyline variants with a black sky, more billboards with faces.

## Status 28 Sep 2026 (later): street polish

Built and on the phone: Grid palettes (rival-mapped in duels), the rain direction, showers and the heavy
chapter-3 weather, asphalt aprons, crossroads. On the phone: pick the Grid accent (dev panel "grid"), judge
the shower timing and chapter 3's visibility, and drive the crossroads at speed (the gantry at 9 m before the
crossing, the barricades). If the wider street is wanted for real, the driveable width is a pass of its own:
`RoadSegment.surface` 18 m, barriers ±9, studs ±8.35, lights ±10.2, `SpeederController.laneLimit` 6.9, the
fork's ±11.5 m rows and `wedgeLimit` all move together.
