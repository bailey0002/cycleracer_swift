# The Grid: rounds, depth and visuals (13 Sep 2026)

Written after the polish pass, when the arena played well but a rival crash "just kept playing"
and a match had no end. This note records what was added and the proposals that were not.

## Added

- **Rounds and a match.** Either derez ends the round. The player's derez keeps the slow-motion
  orbit (3.4 s); the rival's derez is a freeze-cam: everything stops, the camera orbits the
  wreck for 2.6 s, then both cycles restart with `ROUND n` and `GO` stamps. Free play is first to
  three (`ArenaController.matchTarget`); the score reads `YOU w - l RIVAL` in the arena block and
  the match ends with a `MATCH WON w - l` / `MATCH LOST` stamp over a longer orbit, then resets. A
  duel mission sets the target out of reach and decides the job from the same counters, so the
  rival gets the contact's name (`KADE DEREZZED`).
- **Derez breach** (Armagetron's explosion radius): a derez kills every dynamic wall segment
  within 4 m, so a wreck leaves a gap you can ride through. `TrailSystem.breach`, then the
  hash is rebuilt and the renderers rewrite from `firstAlive`.
- **Speed pads** (Tron 2.0 zones): four boost pads (cyan chevrons: +22 m/s surge, +15 % energy,
  SURGE stamp) and two slow pads (red X: speed x0.6, HIT feedback) on open ground, one trigger
  per crossing. `ArenaWorld.pads`; positions in `buildPads`.
- **Tunnel bonus and break-away kick** (Armagetron): grinding with a wall on the other side too
  multiplies the surge by 1.5; leaving a hard grind gives a 10 m/s kick that decays in about a
  second, so grinds have an exit as well as an entry.
- **Rival locator beam**: an orange column over the rival whenever it is more than 22 m away.

Capture hooks: `SPEEDER_ARENA_KILL_RIVAL=<run seconds>` force-derezzes the rival for round
captures; the `garage` script from `SPEEDER_ARENA_START=-82,60,0` crosses the west boost pad.

## Proposed next

Ordered by how much play they add per day of work. Items 1, 2, 4 and 5 were built on 13 Sep 2026
(second pass; see `polish-log.md`): the rival roster with tempers and portraits, the accel curve,
the deck pads and CHARGE pickup, and the match result card. Items 3 and 6-10 are still open.

1. **Rival with a face and a temper.** Name tag rendered through the sign pipeline (Core Text
   to texture) as a billboard over the rival; three AI temperaments (boxer, runner, hunter)
   picked per job; the duel briefing shows the rival's portrait. Turns the opponent into a
   character, which the mission-runner direction needs. [M]
2. **Armagetron accel curve.** Replace the threshold grind with the continuous
   `accel/(offset + d)` term, the turn tax (x0.95 per corner) and decay-to-base, so speed is a
   line the player draws rather than a bonus that switches on. [M]
3. **Sumo zone.** A circle that shrinks after a quiet period; outside it you lose energy, inside
   it you gain. Forces engagement late in a long round and gives the AI a target. [S]
4. **Second level on the deck.** The garage deck exists; give it a reason: a pickup that only
   spawns up there, or a pad chain along the deck edge, so ramps are routes and not scenery. [S]
5. **Match result card.** After MATCH WON / LOST, a card like the mission result: rounds, best
   grind, longest trail, energy left, with credits in free play too. Uses `missionCard`. [S]
6. **Trail wall shading.** The white-to-colour ramp exists along the length; add the vertical
   ramp and the top curl from 3dLightCycles, and vertical strips every 10 m as a length cue.
   Shader-only. [S]
7. **Speed zones as level tools.** Extend pads to long floor strips (green fast lane, red slow
   lane) so a level author can shape routes. [S]
8. **Lingering dead tail.** A derezzed cycle's trail stays as a dim ghost for 8 s (Armagetron)
   instead of clearing on the round reset, so the wreck's shape marks the arena. [S]
9. **Jump-roll.** Wiggle the stick during a jump for a barrel roll that lands with a surge at an
   energy cost (Wipeout). Reuses the jump and the boost kick. [M]
10. **Takedown-style boost extension** (Burnout): a round won by cutting the rival off within
    2 s of a corner extends the energy bar for the next round. Needs the cause of the crash. [M]
