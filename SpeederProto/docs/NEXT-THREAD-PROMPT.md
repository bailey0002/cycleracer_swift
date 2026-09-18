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

**2. Verify the second pass** the same way (README "The game"): the inbox and garage on the
briefing (pad: stick browses, up / down highlights, Y buys; touch: chips and rows), a replay of a
cleared job paying half, the HELMET stamp, the `+1.5 s` on gates, the one-tap retry, SALVAGE 01
(`SPEEDER_MISSION=8`) failing on missed targets, DIVE 01 (`=10`) with no bolts and the double
bruise, DUEL 04 against VESS (`=17`). Measure the rival: rounds survived per rival with the
scripted `drive` from `-40,40,0` before and after the space term (`git stash` the AI to compare),
and confirm ORIN no longer dies on its own trail in `p5/temper-ORIN`. Music: the layers must
swell in over a bar and never click at the loop point; if the pad is muddy on the phone speaker,
drop its saw component.

**3. Feel and balance from the phone**: the chapter-3 density (1.3) and the dive windows are
guesses; tune with the Backbone until a clean run is gold and a sloppy one is bronze. The garage
prices assume about 1,000 credits per chapter; adjust to that.

**4. If there is time**: a contact message log (the debriefs, reread from the briefing);
controller glyph chips from `sfSymbolsName` on first relevance; death attribution on the Grid
("CUT OFF BY KADE"); the round clock and the zone spin-up; a title screen with the last
job's card.

Keep the two corridor looks unchanged unless a change is clearly a fix. Push every meaningful build
to the phone. Log in `docs/polish-log.md`, keep `README.md` and `CLAUDE.md` current, update the
memory files, and finish by writing the next kickoff prompt into this file.
