# Kickoff prompt for the next thread: make The Grid a game with a rival, then close the corridor loop

Paste the block below as the first message of a new Claude Code thread opened in
`/Users/markbailey/Desktop/GS - GamenCtr/GS - Racer`. The previous threads built the three worlds, the
mission runner, the polish pass (`docs/polish-log.md`), the HULL energy bar, and the arena's
rounds and match (`docs/arena-next.md`); everything is on GitHub and on the phone.

---

Read `CLAUDE.md` in this workspace first, then `SpeederProto/README.md`,
`SpeederProto/docs/arena-next.md` and `SpeederProto/docs/research-comparables.md` (the ranked
shortlist at the top). Build the Mac app and run one capture per world plus one arena round
capture (`SPEEDER_VARIANT=grid SPEEDER_DEMO_SCRIPT=garage SPEEDER_ARENA_START=-82,60,0
SPEEDER_ARENA_KILL_RIVAL=2`, times 2.6, 4.2, 6.4) so you have seen the current state before
changing anything. Use `Captures/polish/capture.sh` for every Mac capture and the simulator for
HUD screenshots; build the device binary early and install it whenever the phone is available.

State: three worlds (Neon City, Sunset Canyon corridors; The Grid light-cycle arena with the
parking-garage deck), a mission runner (delivery, search, escape, duel) with one HULL energy bar,
a briefing avatar, The Grid playing in rounds and a match to three with a rival freeze-cam, derez
breach, speed pads, tunnel grinds and a rival beam. Tron-clean tone, single player, phone +
Backbone. The arena is the strongest part; the direction is to make it a game with a rival you
know, then close the corridor loop so every run scores and ranks.

Do these in order, each one built, captured, committed, pushed and on the phone before the next:

**1. A rival with a face and a temper** (`docs/arena-next.md` item 1). A name tag over the rival
rendered through the sign pipeline (`ProceduralTextures` / `materials.signs` Core Text path) as a
billboard that faces the camera; three AI temperaments in `ArenaAI` (boxer: cuts you off, runner:
open ground and pads, hunter: shadows you and grinds your trail) chosen per job and named in the
duel briefing; the briefing card shows the rival's portrait (render the avatar or a colour badge to
a texture) next to the contact. Add a second named rival to the mission catalogue so a duel is
not always KADE.

**2. Match result card and credits in free play** (item 5). After MATCH WON / LOST, a card in the
`missionCard` style: rounds, best grind, longest trail, energy left, credits earned; A / F / tap
restarts. Free play then pays into the same persistent credits as the jobs.

**3. Armagetron acceleration curve** (item 2). Replace the threshold grind with the continuous
`accel / (offset + d)` term against the nearest wall, the tunnel term for two walls, the turn tax
(speed x0.95 per corner), boost as a burst that decays to base, and decay-to-base rates. Tune it
on the phone with the Backbone; the feel target is that speed is a line the player draws.

**4. Give the deck a purpose** (item 4). A pickup that only spawns on the upper deck and a pad
chain along the deck edge, so the ramps are routes; the hunter AI should take the ramp when the
player is up there.

**5. Streak scoring with reset on hit for the corridor jobs** (research shortlist item 3, Sayonara
Wild Hearts). Each ring, beacon or drop gate is worth more than the last until a hit resets the
value; the result card shows a rank (bronze / silver / gold by score thresholds per job) and the
rank is remembered per job in UserDefaults and shown on the briefing card. This is the "close the
loop" piece: every run scores and ranks.

**6. If there is time**: checkpoint respawn with retained speed at block boundaries (shortlist
item 4) so a HULL BREACHED does not end 90 s of play, and the sumo zone (arena item 3).

Keep the two corridor looks unchanged unless a change is clearly a fix. Log what changed and the
capture that shows it in `docs/polish-log.md` (new dated section), keep `README.md` and
`CLAUDE.md` current, update the memory files, and finish by writing the next kickoff prompt into
this file.
