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
