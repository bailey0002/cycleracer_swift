# Prototype assessment (18 Sep 2026)

Question asked: is the prototype aligned with sound game mechanics, does the UI give enough
information and cues to guide play, are the actions and their sequencing intuitive, and what is
the overall quality against the game's stated purpose (a Tron-clean, single-player mission runner
for the phone with a Backbone). Method: a read of the whole code base, the captures in
`Captures/`, three research agents on comparables (short-session mission runners, HUD and
game-feel norms, single-player light-cycle duels) and three code-review agents (arena, corridor
and missions, views and rendering). The build was not run: the session ran on Linux without
Xcode, so every code change in this pass still needs the Mac build and a phone install.

## Verdict in one paragraph

The engine is strong and the direction is right: a run engine with a real feel layer (same-frame
acks, hit-stop, camera kick, haptics), a duel engine with a legible opponent, one energy bar,
streak ranks and checkpoint respawns are all genre-correct choices, and the code respects its own
gotchas. What was not right, as of 17 Sep, was the content and the information layer: every
corridor job authored only its first 8-14 blocks (320-560 m) and then repeated its last block for
the remaining 85 % of the distance, so "HULL PAYS" was decided in the first seven seconds and a
scripted demo earned gold; the game had no audio at all; the HUD had no speedometer, two-state
meters, a timer that only turned red, a pursuer that was a number, no "coming up" cue, and a
permanent 9 pt control paragraph instead of prompts; touch could not fire or use a pickup; credits
bought nothing; and the job loop dead-ended after every duel because a theme change from The Grid
never rebuilt the scene. Most of these are fixed in this pass (see "What changed"); the rest is
listed as owed work with the source that argues for it.

## 1. Mechanics: is the logic sound and does it lead to quality play?

Aligned with the genre (kept):

- One bar for hull and boost (F-Zero GX, Wipeout HD): hits 25 %, scrape 8 %/s, boost 12 %/s,
  trickle 3.5 %/s, beacon +20, kill +5. Bounded, readable, no exploit found.
- Streak scoring with a reset on hit (Sayonara Wild Hearts), bronze/silver/gold from per-job
  ceilings, two checkpoint respawns at 50 % with a 4 s penalty (Trackmania, Thumper).
- The escape pursuer as a speed differential (2 m/s faster than cruise, catches at 4 m) with a
  diegetic craft that pulls alongside under 18 m.
- The Grid: kinematic cycles with the Armagetron accel curve, an energy-budgeted rival on the same
  physics, finite trails with decay, breach and Pulse, rounds and a match, a sumo zone. Reviewers
  confirmed the arena math (sweeps, ray hits, steer signs, height queries with `below:`).

Not sound (found, fixed):

- Authored track covered 13 % of every job (`TrackProgram` repeats the last block; one block per
  40 m segment). Fixed by `TrackComposer`: every job now composes bends, S-bends, obstacle fields,
  a split, conduits, undercity runs, skyways and landmarks over its whole distance from a recipe
  and a seed.
- Theme change from The Grid did nothing (`settings.didSet` guarded on `world != nil`, which is nil
  in the arena), so DUEL 01 -> RELAY 04 drew a canyon briefing over the arena and the job could
  never finish. Fixed (guard on world or arena).
- Boost at an empty bar flickered on and off every few frames (punch + rumble spam). Fixed with
  hysteresis: empty disarms boost until 15 %.
- Cruise speed was adjustable during a live job (Y/B), which neutralised the pursuer (cap 47 m/s)
  and the timers. Locked while a job is live.
- `SPEEDER_RESET_PROGRESS` left ranks behind; a relaunch on the result card replayed the payout;
  a respawn in the last 4 s stamped HULL RESTORED on a failed run; a negative `SPEEDER_MISSION`
  crashed. All fixed.
- Search ceilings under-counted beacons, so gold on a sweep was ~55 % of the achievable score.
  Beacons now count at the capped streak.
- Arena: PHASE was silently disabled by picking up another item; the break-away kick could be
  farmed by wiggling beside a wall; a tunnel grind out-earned boost, so boost was unbounded; the
  rival's `maxSpeed` was still 96 (its grinds took it into the self-boxing regime); `crashPlayer`
  could fire twice in one frame. All fixed (kick needs 0.6 s of grind, grind pays 0.12 while
  boosting, rival capped at 62, guard on `alive`).

Still owed (design, not bugs):

- Credits buy nothing. Every comparable has a two-to-six item shop (Alto's workshop: helmet =
  one free hit, timer extension) or an objective ladder that levels the bike (Race the Sun). The
  flags added in this pass give the credits a display but not a use yet. [M]
- The rival AI scores straight rays and has no space term, loop guard or lookahead, which is
  exactly why it dies on its own trail when a goal pulls it into a turn. The duel research ranks
  a 6 m occupancy grid with a flood-fill reachable-area term first (S-M), then a spiral guard,
  then skill tiers by reaction time rather than speed (GLtron's 600/400/200/100 ms table).
- Time is only a countdown. Crazy Taxi's "arrive fast = more time" and a SPEEDY/NORMAL stamp
  would make the clock a resource and fits the delivery kind. [S]
- Simultaneous derez is a player loss; Armagetron voids the round. [S]

## 2. UI: enough information and cues?

What it did well before this pass: same-frame pips and stamps, hit feel on spec (70 ms hit-stop,
flash and shake decays), one visual language, a mode-aware element set, safe-area correct, a
scrolling settings panel, a diegetic pursuer.

What was missing, ranked by the HUD research against Apple's game HUD guidance, Player Research's
peripheral-vision work, Redout, Wipeout, NFS and Data Wing:

| Gap | Now |
|---|---|
| No audio at all: no sound assets, no audio API. Every warning was a 6 pt bar. | `Sources/Audio/SoundEngine.swift`: synthesised cues (accept, GO, hit, fire, kill, beacon, gate with pitch by streak, section, approach, respawn, success, fail, ticks under 5 s, snap, jump, land, derez, pickups, surge, zone, round and match beats) and five loops (engine by speed, boost, grind, scrape, alarm for low hull / closing pursuer / low edge). HUD `sound` toggle; silent under `SPEEDER_DEMO=1`. |
| Meters were two-state and static; arena ENERGY had no low state. | Three states (accent > 50 %, amber > 25 %, red) and the low state breathes at 0.35 s. |
| Timer only turned red at 10 s. | Amber under 20 s, red under 10 s, scale pulse under 5 s, a tick each second (rising on the last two). |
| Pursuer was a number. | Number plus a GAP bar against the start gap, red and pulsing under 20 m, with the alarm loop rising as it closes. |
| No corridor speedometer. | km/h leads the race block; distance, hits, kills, altitude on one line. |
| No lead on section changes. | `WorldScroller.upcoming`: a chip ("CONDUIT IN 84 m") from 140 m out, brighter under 40 m, plus a two-note approach cue. |
| Controls were a permanent 9 pt paragraph. | Shown for the first 30 s and whenever the settings panel opens. (Controller glyphs via `sfSymbolsName` are still owed.) |
| Touch could not fire, use a pickup or restart a match. | A quick still tap is the A button (fire / pickup / accept). The corner-tap hint is gone (the ARView never took touches). |
| Cards were full-screen tap catchers, so the gear and panel were unreachable while a card was up; a stale card stayed on in free play. | The tap target is the card; the mission state is cleared when the loop is off. |
| Pickup names without meaning; PAD name in the race block. | "PHASE: pass through one wall", "PULSE: erase your newest trail"; the pad name moved to the stats block. |
| No side objectives, so a passed job was finished. | Three flags per job (CLEAN, FAST, GOLD) on the briefing and result cards, remembered per job. |

Still owed: controller glyph chips that appear on first relevance (Apple HIG), an arena compass
or edge arrow for a rival behind you, a next-beacon bearing on sweeps, essential text at 14 pt or
more on the phone (Apple's floor for essential information is 17 pt), the stamp stack limited to
one centre element, an inbox that carries the contacts' story (Data Wing, NFS Underground 2).

## 3. Sequencing: are the actions intuitive?

- The job loop (briefing -> GO -> run -> card -> next) is short and the button is always the same
  (A / F / tap), which is right. Retry goes through the card; a one-tap restart on failure is the
  norm (Data Wing, Race the Sun). [S, owed]
- Jobs unlock strictly in sequence. Fine for the first hour (Data Wing does the same); the inbox
  and flag-gated unlocks are the next step.
- The arena's READY -> GO -> round -> freeze-cam -> next round reads well; the cause line on a
  derez is the genre's answer. Owed: attribution ("CUT OFF BY KADE" vs "BOXED YOURSELF") and a
  4 s rewind on the orbit.
- Input: an idle pad no longer owns the steering (touch and keyboard work with a Backbone
  attached), and boost, jump, snap, fire and accept all ack on the frame.

## 4. Code quality

Reviewed by three agents; findings above were verified by reading. Overall: readable, dt-scaled,
no retain cycles, gotchas respected. Structural debts: `GameController` (900 lines) mixes scene
assembly, both frame loops, demo scripts and captures; `RoadSegment` is ~1000 lines of geometry
plus pooling plus palette; `ArenaController.update` inlines the phase machine. No tests exist,
but `Mission`, `MissionRunner`, `TrackProgram`/`TrackComposer`, `LightCycle`, `TrailSystem`,
`ArenaTerrain` and `ArenaAI` are pure enough to test today (a headless 60 Hz loop over
`MissionRunner` would have caught the boost flicker and the respawn/time-out order). Performance
notes left open: `SceneMaterials` generates every texture synchronously on the main actor at each
rebuild (the 8 s stall, repeated per job change); the arena's `ground` closure is rebuilt per
access; the settings `didSet` re-applies the whole world (cruise nudges no longer do).

## What changed in this pass (all unbuilt: verify on the Mac first, then the phone)

- `Scene/TrackProgram.swift`: `TrackBlock.dressing`, `TrackComposer` (phrases: straight, bend,
  sBend, field, split, conduit, undercity, skyway, landmark).
- `Missions/Mission.swift`: every corridor job composed over its full length; `Flags`; the
  beacon score ceiling.
- `Scene/WorldScroller.swift`: overpass and gateway dressing groups; `upcoming` lookahead;
  `sectionLabel`.
- `Audio/SoundEngine.swift` (new; registered in the project file by hand, `xcodegen generate`
  will produce the same).
- `Scene/GameController.swift`: sound wiring, the arena rebuild guard, stale-card clear, cruise
  lock, tap-to-fire, hint timer, accept guard during the curtain, free-play match target
  restored after a duel, `stats.flash` churn removed.
- `Missions/MissionRunner.swift`: boost hysteresis, flags, reset covers ranks and flags, payout
  banked with the job index, respawn/time-out order, abs on the mission env.
- `Views/HUDView.swift`: speedometer, three-state pulsing meters, timer states, pursuer bar,
  upcoming chip, pickup help, flags, card tap scope, bottom blocks pass touches through, sound
  toggle. `Views/Input.swift`: `tapFire`, idle pad does not own steering. `App/SpeederApp.swift`:
  idle timer off on iOS.
- `Arena/ArenaController.swift`: the five fixes listed under mechanics.

## Verification plan for the next thread

1. `xcodegen generate`, build the Mac app, fix whatever the compiler says (this pass had no
   compiler).
2. `SPEEDER_MISSION=0 SPEEDER_CAMERA=overview` capture at 9, 20, 40 s: the track must still be
   varied at 1.5 km (fields, a bend, an overpass); `SPEEDER_MISSION=4` for the second conduit;
   `SPEEDER_MISSION=6` for the canyon undercity and split.
3. Simulator HUD screenshots: running strip under 5 s, hull under 25 %, the escape GAP bar, the
   CONDUIT chip, the briefing with flags.
4. On the phone with sound on: the engine loop must sit under the cues; if the ambient category
   is too quiet under music, switch to `.soloAmbient`.
5. Play DUEL 01 to the end and confirm RELAY 04 rebuilds into the canyon.
