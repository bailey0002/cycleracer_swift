# Kickoff prompt for the next thread: build the assessment pass, then the shop, the rival's space sense and the inbox

Paste the block below as the first message of a new Claude Code thread opened in
`/Users/markbailey/Desktop/GS - GamenCtr/GS - Racer`. The previous threads built the three worlds, the
mission runner, the polish passes, the arena's rounds and rivals, and on 18 Sep 2026 an assessment
pass (`docs/assessment-2026-09-18.md`) that was written on a Linux machine **without Xcode**: full-
length composed tracks, landmark dressings, a synthesised sound layer, HUD states, tap-to-fire and
a batch of review fixes are all on the branch and on GitHub but have never been compiled.

---

Read `CLAUDE.md` in this workspace first, then `SpeederProto/README.md` ("Assessment pass" section),
`SpeederProto/docs/assessment-2026-09-18.md` in full, and the round-2 reports at the end of
`SpeederProto/docs/research-comparables.md`.

**0. Build it.** `xcodegen generate` (a new `Sources/Audio/` folder exists; the pbxproj was edited by
hand), then the Mac build. Expect compiler errors: the pass was written blind. Fix them with the
smallest change that keeps the intent. Then the phone build and install.

**1. Verify the pass with captures**, one job at a time, before any new work:
- `SPEEDER_MISSION=0 SPEEDER_CAMERA=overview` at 9, 20, 40 s: bends, a field and an overpass must
  still be arriving at 1.5 km. `SPEEDER_MISSION=4` for two conduits; `SPEEDER_MISSION=6` for the
  canyon undercity, the split and the rock-arch overpass; `SPEEDER_MISSION=7` for the skyway.
- Simulator HUD screenshots (`SIMCTL_CHILD_*`): the running strip under 5 s, hull under 25 %, the
  escape GAP bar, a "CONDUIT IN n m" chip, a briefing with flags, a result with NEW flags.
- Play DUEL 01 to the end on the phone and confirm RELAY 04 rebuilds into the canyon (the old
  dead end). Free play on The Grid must still be first to three after a duel.
- Sound on the phone with the Backbone: engine under the cues, hit / kill / gate / tick audible,
  the alarm loop only when hull is low or the pursuer is close. If it is buried under music,
  switch the session category to `.soloAmbient`. Tune the `gain` constants in `synthesise()`.
- Log the verified captures in `docs/polish-log.md` (18 Sep section), fix what the captures show.

**2. Give credits a use** (research E, Alto's workshop): a four-item shop on the briefing card,
bought with the purse: a helmet (one free hit per job), +20 % hull, +10 s window, +1 respawn.
Persist in UserDefaults; `SPEEDER_RESET_PROGRESS` clears it. Keep it Tron-clean: four lines and a
price, no art.

**3. The rival's space sense** (research G, item 1-3): a 6 m occupancy grid in `TrailSystem`
rasterised from the segments; per candidate heading a flood fill from one tick ahead adds a
reachable-area term and rejects pockets under ~8 s of travel; a loop guard after three same-
direction snaps; skill tiers by reaction time (0.40 / 0.25 / 0.16 / 0.10 s tick, probe range and
noise per tier) on `Rival`, KADE easy in DUEL 01, ORIN medium, free play climbing per match won.
Measure with the scripted `drive` from `-40,40,0`: rounds survived per rival before and after.

**4. The inbox** (research E, Data Wing; shortlist 10): replace "next job" with a message thread per
contact; a job is a message with the portrait; a job unlocks when the previous one of its contact
has a flag; the briefing card stays. Keep `SPEEDER_MISSION`.

**5. If there is time**: one-tap retry from the failed state; time as a refillable resource on
deliveries (Crazy Taxi: a checkpoint adds seconds, SPEEDY / NORMAL stamp); controller glyph chips
from `sfSymbolsName` on first relevance; a void round on a simultaneous derez.

Keep the two corridor looks unchanged unless a change is clearly a fix. Push every meaningful build
to the phone. Log in `docs/polish-log.md`, keep `README.md` and `CLAUDE.md` current, update the
memory files, and finish by writing the next kickoff prompt into this file.
