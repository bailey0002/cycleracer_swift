# Kickoff prompt for the next thread (written 4 Oct 2026)

Paste the block below as the first message of a new Claude Code thread opened in
`/Users/markbailey/Desktop/GS - GamenCtr/GS - Racer`. State at close of the last thread: master = PR #6
(soundtrack, review fixes, run cards, saves, the Grid on GPT tiles); branch `claude/garage` = PR #7
(https://github.com/bailey0002/cycleracer_swift/pull/7, open): the garage relaid with helix ramps, the
wider arena camera, aqua / electric-blue trails. The PR #7 build is on the iPhone 12.

---

Read `CLAUDE.md` in this workspace first, then the last four sections of `SpeederProto/docs/polish-log.md`
("KERB: GALACTIC", "The Grid: rider visibility ...", "The garage relaid", and the follow-ups under each).

**0. Branch and build.** `git checkout claude/garage` (merge PR #7 into master first if Mark has approved
it, then branch anew off master), `cd SpeederProto && xcodegen generate`, the Mac build from `CLAUDE.md`.
Every meaningful build goes to the phone (Release; command in the README). The phone must be unlocked
for the launch; the install works locked.

**1. Mark's feedback on the garage.** He was about to test PR #7: the helix ramps (lane 16 m, radius
44 m, deck at 22 m) at speed, the solid barriers, the wider chase camera, the aqua and blue trails. Expect
tuning: lane width / radius / deck height in `ArenaTerrain.garage`, the camera constants in
`CameraRig.followArena`, the trail colours in `ArenaController` (`playerColor` default livery AQUA in
`Player.liveries`, `opponentColor`).

**2. Owed on The Grid.** The AI has never driven the helix: `ArenaAI` steers to the ramp's foot and top
points only, so a run of free-play rounds with `SPEEDER_ARENA_CAMERA=overview` should check it reaches the
deck and does not clip the ramp rails. The crowd strip (`grid-crowd-01.png`, brief item 9) is still not
generated. The floor still leans blue under the horizon band; the roughness map helped, a darker environment
band would finish it.

**3. Owed elsewhere.** The audio mix by ear (music 0.8 scale, 40 % duck, WRONG on every hit); rider intro
clips are KERB's 5 s mp4s; a shop / garage tie-in for the Kerbie Astro; real voices to replace Kenney;
`SPEEDER_CHECK_NAN` trace and the arena-size override are capture aids, leave them.

**4. Gotchas from the last thread** (also in `CLAUDE.md`): headless captures die silently after a crash (the
"restore windows?" modal) and when the display sleeps (RealityKit stops rendering); `capture.sh` handles both.
New files in `Resources/` need `xcodegen generate` or the bundle silently lacks them.

Work the way the previous threads did: build, verify with captures, push to the phone, document in
`docs/polish-log.md` and `CLAUDE.md`, commit on a branch, open a PR.
