# Kickoff prompt for the next thread: make the rival smarter and the hub a place, then the arena's late game

Paste the block below as the first message of a new Claude Code thread opened in
`/Users/markbailey/Desktop/GS - GamenCtr/GS - Racer`. The previous threads built the three worlds, the
mission runner, the polish pass (`docs/polish-log.md`), the HULL energy bar, the arena's rounds and
match (`docs/arena-next.md`), and the second pass of 13 Sep 2026: a rival roster with tempers and
portraits, the free-play match result card, the Armagetron acceleration curve, the deck pads and
CHARGE pickup, streak scoring with ranks, checkpoint respawn and the sumo zone. Everything is on
GitHub and on the phone.

---

Read `CLAUDE.md` in this workspace first, then `SpeederProto/README.md`, the last section of
`SpeederProto/docs/polish-log.md` (13 Sep 2026, second pass), `SpeederProto/docs/arena-next.md` and
the ranked shortlist at the top of `SpeederProto/docs/research-comparables.md`. Build the Mac app and
run one capture per world plus these two arena captures so you have seen the current state:
`SPEEDER_VARIANT=grid-snap SPEEDER_DEMO_SCRIPT=ramp SPEEDER_ARENA_START=-52,70,0
SPEEDER_ARENA_RIVAL=KADE SPEEDER_ARENA_CAMERA=overview` (times 5, 7, 9: the hunter takes the ramp) and
`SPEEDER_VARIANT=grid SPEEDER_ARENA_RIVAL=ORIN SPEEDER_ARENA_START=-40,40,0 SPEEDER_ARENA_CAMERA=overview`
(times 5, 9, 13: the boxer). Read the demo log lines (rival position, speed, derez cause). Use
`Captures/polish/capture.sh` for every Mac capture and the simulator (`SIMCTL_CHILD_*`) for HUD
screenshots; build the device binary early and install it whenever the phone is available.

State: three worlds; nine jobs (delivery, search, escape, two duels) with one HULL bar, streak scoring
(gates every 200 m, beacons, kills; a hit resets), bronze/silver/gold per job remembered in
UserDefaults, two checkpoint respawns per job; The Grid with a rival roster (KADE hunter, ORIN boxer,
SABLE runner) that has a name tag, a portrait and a temper, rounds and a match to three with a result
card that pays credits, the Armagetron accel curve (`LightCycle.step`), the deck with a pad chain and
the CHARGE pickup, and a sumo zone that opens 25 s into a round. Tron-clean tone, single player,
phone + Backbone.

The feel of the accel curve has not been tuned by hand yet: the constants are `LightCycle.boostAccel /
boostSpeed / decayAbove / turnTax` and `ArenaController.grindGain / grindOffset / grindNear`. Ask the
user for a verdict from the phone before touching them.

Do these in order, each one built, captured, committed, pushed and on the phone before the next:

**1. Arc-aware AI probes.** The AI scores straight-line probes but drives arcs of 17-21 m radius in
analog mode, and it still dies on its own trail or a hazard when the goal pulls it into a turn (see
`p5/temper-ORIN/log.txt`, `p5/hunter-ramp/log.txt`: `own trail`, `hazard`). Sweep the actual arc
(sample the turning circle for the option's heading change, then the straight) through
`TrailSystem.sweep`, and give the boxer a "commit" rule: once it has crossed the player's line it
runs open for two seconds before the next intercept. Measure: rounds a rival survives against the
scripted `drive` from `-40,40,0` should go from about one to several.

**2. Lingering dead tail and trail wall shading** (`docs/arena-next.md` items 8 and 6, shader and
renderer only). A derezzed cycle's trail stays as a dim ghost for 8 s instead of clearing on the
round reset; add the vertical white-to-colour ramp, the top curl and a strip every 10 m in
`trailSurface`.

**3. Zone as a level tool.** The sumo zone exists (`ArenaController.updateZone`); make it move: pick
its centre from the open ground away from both cycles, and let a level place two zones in turn.
Add the collapse pay-out (Armagetron: survivors inside when it closes get energy).

**4. The hub as an inbox** (research shortlist item 10, NFS Underground 2). Replace "next job" with an
inbox card: contacts text jobs in, colour-coded by kind, the portrait on each message; the player
picks any unlocked job, and a job unlocks when the previous one of its contact is bronze or better.
The briefing card stays; the inbox is where it is chosen from. Keep the `SPEEDER_MISSION` hook.

**5. Takedown boost extension** (arena item 10). A round won within 2 s of the rival's last corner
(the cause is in `lastRivalCause` plus a corner timestamp) extends the energy bar for the next round
(`energy` starts at 1.0 instead of 0.6) with a `TAKEDOWN` stamp.

**6. If there is time**: speed lanes as level tools (item 7), and the result card coast-down in the
corridor (the run ends on the frame the distance is reached; let the drop marker come into view).

Keep the two corridor looks unchanged unless a change is clearly a fix. Log what changed and the
capture that shows it in `docs/polish-log.md` (new dated section), keep `README.md` and `CLAUDE.md`
current, update the memory files, and finish by writing the next kickoff prompt into this file.
