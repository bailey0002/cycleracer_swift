# Polish log (11 Sep 2026)

One line per rough edge: what was wrong, what changed, which capture shows it. Captures live
under `Captures/polish/` (`baseline/` is the state before this pass; `p1/`, `p2/`... are the
verification runs; the helper `Captures/polish/capture.sh <dir> <seconds> ENV=...` runs the Mac
app in demo mode and kills it, and scene time starts about 8 s of wall-clock after launch).

## Corridor section transitions

| Was wrong | Changed | Capture |
|---|---|---|
| Entering the conduit snapped the vehicle from the flat lane limit (x up to 6.9) into the cylinder (x within ~1.9 at hover height) on one frame; leaving it snapped a high vehicle down to the 5.6 m altitude cap. | `WorldScroller.tubeBlend` eases 0 to 1 over the 24 m before the mouth and back over the last 24 m inside; `SpeederController` clamps against both constraint sets and mixes the results by the blend. The wall roll and the camera's tube gains use the same blend. | `p1/conduit/frame-4` .. `frame-5` (entry), `frame-8.5` (exit ahead) |
| The conduit, the undercity tunnel and the skyway started at a bare segment edge: the pipe wall simply began, the tunnel walls began, the deck rails began. | `RoadSegment.buildPortals`: an entry and an exit frame per style (pipe collar + lit rim + flange + hood and pillars; tunnel arch with lit inner edge and a light pool outside; skyway gate arch). `setNeighbours` enables the entry frame when the previous segment has a different style and the exit frame when the next one does. | `p1/conduit/frame-4` (pipe mouth), `p3/conduit-exit/frame-9` (mouth from inside), `p1/fork-tunnel/frame-4.5` (tunnel arch ahead), `p3/canyon-fork/frame-10` (canyon tunnel) |
| No lighting change between the open city and an enclosed section. | `WorldScroller.enclosure` (0 open, 1 tunnel/conduit, 20 m lead) feeds `PostProcessor.enclosure`: fog density x2.5, fog colour darkened, the horizon glow removed and the vignette tightened, all blended over the lead-in. Neon City and Sunset Canyon in the open are untouched. | `p1/conduit/frame-5` vs `baseline/default/frame-9` |
| The fork decided the branch on the frame the split passed the player and re-placed the fork segment (7 deg yaw) and the four branch segments (up to 9 m sideways) at once: a visible pop 30 m ahead, and the tunnel/skyway geometry appeared 40 m ahead at that moment. | Soft decision: from 30 m before the split the side is sampled from the player's x and the branch is styled then (so its mouth is 60 m out, in the fog); the road's divergence `forkBlend` ramps with distance over 24 m of travel and the fork plus downstream segments are re-placed every frame while it moves; the side locks when the split passes. Changing side before the lock ramps back. | `p2/fork-over/frame-4.5` .. `frame-6` |
| The fork segment's building rows (built at the city's 11.5 m) overhang the branch roads, which slide 5 m + 4 m outward: the vehicle and the camera drove through lit towers right after the split. | The fork segment's `buildingGroup` is scaled 1.7x in x, so its rows stand at 19.5 m and clear both branches. | `p1/fork-skyway/frame-5.5` (before) vs `p2/fork-skyway/frame-5.5` |
| The V divider had no collision: the vehicle passed through the wedge and the camera went inside it. | `WorldScroller.wedgeLimit`: past the nose the divider's face on the player's side is a lane limit (plus 1.3 m), so the vehicle scrapes along it with sparks and speed bleed like the roadside barrier. | `p3/fork-over/frame-5` |

## Vehicle motion and camera

| Was wrong | Changed | Capture |
|---|---|---|
| The collision jolt started at a random phase (`sin(recoilTimer * 40)` with recoilTimer = 0.45 gives -0.75 on the first frame) and rolled the vehicle *against* the sideways push. | `jolt = sin((0.45 - t) * 40) * t * 0.35` starts at zero and rolls with the push; amplitude 0.5 -> 0.35 rad. The camera follows `smoothBank` (steer + lateral speed + wall roll) and only 40 % of the jolt. | play test on the phone |
| Corridor and arena cameras had different roll gains (0.35 / 0.28), roll damping (3.0 / 4.0), FOV widening (14 / 16) and shake formulas. | `CameraRig` shares `rollGain` 0.3, `rollDamp` 3.5, `fovDamp` 3.0, `speedFov` 14 and one `shakeOffset` between both rigs. | `p2/grid-snap` vs `p1/conduit` |
| Boost had no onset: the FOV drifted wider with speed and that was all. | `CameraRig.punch`: a kick with a ~150 ms attack and ~400 ms release adds 9 deg of FOV and 0.45 m of camera pull-back; the post pass adds streaks and aberration from the same envelope; a haptic fires on the same frame. Used for boost onset (both modes) and the mission launch. | `p1/launch/frame-2` |
| Obstacle hits: flash + shake + speed loss but no hit-stop. | 70 ms hit-stop (simulation at 15 %, camera at full rate) on the corridor hits. | play test |
| Hover bob was the same at rest and at speed; the parked vehicle looked frozen. | Bob is slow and deep at rest (0.05 m at 2.2 rad/s), quick and shallow at speed; a small idle yaw sway; the engine trail idles at 30 particles/s and 6 m/s instead of blasting at full rate; the speed motes stop below 4 m/s. | `p1/launch/frame-0.3` vs `baseline/mission1/frame-1` |
| Arena: every opponent snap turn shook the player's camera. | Shake, haptic and the HUD pip fire only for the player's corners. | `p2/grid-snap` |
| The arena round-start camera appeared already in place. | The spring starts 6 m further back and 4 m higher on READY and zooms in. | `p2/grid-snap/frame-3` |

## Actions: visible + haptic + HUD on the same frame

| Action | Before | Now |
|---|---|---|
| Fire (corridor) | shake 0.08 only | shake, haptic (0.25 / sharp), FIRE pip lit 150 ms |
| Boost (both) | nothing at onset | camera kick, haptic, BOOST pip while held, post streaks |
| Jump (arena) | nothing | shake 0.08, haptic, JUMP pip; landing: shake 0.15, haptic |
| Pickup take / use (arena) | flash on take, shake on pulse | take: haptic + PICKUP pip; use: haptic, flash, pip, centre stamp PHASE / PULSE |
| Snap turn (arena) | shake (also for the opponent) | player only: shake, haptic, SNAP pip |
| Beacon (search) | showed the red HIT text (flash > 0.25) | violet BEACON +1 stamp, haptic |
| Obstacle hit | flash + HIT text from the flash level | HIT stamp from the acknowledgement, hit-stop |
| Section entry | nothing | centre stamp: CONDUIT / UNDERCITY / SKYWAY / SPLIT, 0.7 s |
| Mission launch | nothing | GO stamp, camera kick, haptic |

Implementation: `GameController.ack` (`ActionAck`) is published only when a flag changes; timers
decay in `publishAck`. The HUD's pip row and `stampOverlay` read it.

## Mission flow

| Was wrong | Changed | Capture |
|---|---|---|
| Accepting a result rebuilt the world in view: the anchor emptied, the speeder and avatar reloaded, and the new world appeared piecemeal behind the card. | A curtain in the post pass: `requestRebuild()` closes it (0.1 s), the rebuild runs behind black, `build()` opens it (0.2 s). The same curtain covers the first launch. | `p1/launch/frame-0.3` (opening) |
| The contact stood at a fixed yaw and looked past the camera. | `AvatarActor.face(cameraRig.position)` every frame while the card is up. | `p1/launch/frame-0.3` |
| Parked bike: exhaust at full rate, speed motes streaming past a stationary vehicle. | see vehicle motion above | `p1/launch/frame-0.3` |
| Firing while parked launched bolts into the briefing. | Fire is ignored while parked. | – |
| On the phone the centred briefing card sat on top of the bike and hid the contact behind its right edge. | While parked the camera frames 2.2 m to the left (`frameShift`, eased out on launch through the same lateral damping) and the card is anchored 40 pt from the left edge, so bike and contact fill the right two thirds. | `p3/briefing/frame-3`, `sim/briefing` |
| The V divider's wedge core was 8 m wide and the branches diverged 5 m + 4 m, so the inner half of each branch road ran through the core. | Divider half-spread 6 -> 3 m, core 4.8 m wide, divergence 7 m + 3 m: the outer lanes clear the core and the camera stays 8 m from its face (the road still reads as splitting around a building). | `p3/fork-tunnel/frame-5.5`, `p3/fork-skyway/frame-5.5`, `p3/canyon-fork/frame-9` |

## HUD

| Was wrong | Changed |
|---|---|
| Four panel styles (stats 0.45/6 pt radius, race block the same, mission cards 0.62/10 pt with a cyan stroke, settings 0.5/8 pt). | One `hudPanel()` modifier: black 0.55, 8 pt radius, thin accent stroke; cards use 0.7. |
| Two meter components (`meter` in the arena block, `stripMeter` in the mission strip) with different label treatment. | One `meter`: 48 pt bold label, 110 x 6 bar. |
| Cyan came from `.cyan`, pickups from `.purple`, prompts were plain text. | `HUDStyle.accent` / `.pickup`; every card ends in the same `prompt()` (accent key cap + action). |
| 10 pt monospaced everywhere on the phone. | `HUDStyle.baseSize` 11 on iOS (10 on the Mac), big numbers 22, brief text 12. |
| The diagnostic fps/entities block always sat top-left on the phone. | On iOS it shows only while the settings panel is open. |
| No acknowledgement of actions. | Pip row bottom-right, centre stamps (see above). |

## 13 Sep 2026: energy bar, arena rounds, arena depth

| Was wrong | Changed | Capture |
|---|---|---|
| Three different resources in the corridor jobs: cargo integrity (delivery only), an escape-only boost meter, free boost elsewhere. | One `HULL` bar (`MissionRunner.energy`): hits, scrapes and boost drain it, beacons, kills and a trickle refill it, empty fails the run, the remainder pays on every kind. | `sim/hull-running`, `p4/hull/log.txt` (hull column) |
| A rival crash on The Grid just respawned it after 4 s while play continued; nothing said who won, and free play never ended. | Rounds: either derez ends the round; the rival's derez is a 2.6 s freeze-orbit with a `<RIVAL> DEREZZED` stamp; `ROUND n` / `GO` on restart; free play is a match to three with `MATCH WON / LOST` over a longer orbit. Duel missions keep their own target and name the rival. | `p4/rival-derez/frame-3.6` .. `frame-6.4`, `sim/arena-rival-derez`, `sim/arena-next-round` |
| Nothing marked where the rival was across a 220 m arena. | Orange locator beam over the rival beyond 22 m. | `p4/rival-derez/frame-3.2` |
| A derez left the trails intact around the wreck. | Explosion breaches every dynamic wall within 4 m (`TrailSystem.breach`). | `p4/rival-derez/frame-6.4` |
| The floor was uniform: no reason to route anywhere. | Four boost pads and two slow pads on open ground; `SURGE` stamp and a boost pip on a boost pad, hit feedback on a slow pad. | `p4/pads-over/frame-1.0`, `p4/pads/frame-1.7` |
| Grinding was one flat surge. | Two-wall tunnel bonus x1.5 and a 10 m/s break-away kick when leaving a hard grind. | play test |

## 13 Sep 2026 (second pass): a rival you know, the match card, the accel curve, the deck, streak ranks

Captures in `Captures/polish/p5/` (Mac frames) and `p5/sim/` (simulator, for the SwiftUI cards).

| Was wrong | Changed | Capture |
|---|---|---|
| The opponent was an unnamed orange cycle with one behaviour; the duel briefing showed initials in a ring. | `Arena/Rival.swift`: a roster (KADE hunter, ORIN boxer, SABLE runner) with a colour and a temper. A name tag over the rival goes through the sign pipeline (`ProceduralTextures.nameTag`, Core Text to a texture with alpha) on a thin box that turns to the camera each frame at a constant apparent size. Portraits (`ProceduralTextures.portrait`: helmet, glowing visor, temper glyph, name band) are rendered once per name and shown on the briefing card as contact VS rival, with the temper line. | `p5/sim/arena-tag`, `p5/sim/duel-briefing-kade`, `p5/sim/duel-briefing-orin`, `p5/rival-tag/frame-2.8` |
| One AI. | `ArenaAI.temper`: the boxer steers for a point ahead of the player's nose, the runner for the nearest same-level boost pad and the far open side, the hunter for a point behind the player's tail with a bonus for headings that grind the player's trail, and the ramp (bottom, then top) when the player is on the deck. Boost per temper, gated by the rival's own energy budget and by clear ground; the rival's burst tops out at 54 m/s so its 0.16 s decisions can keep up. | `p5/temper-KADE`, `p5/temper-ORIN`, `p5/temper-SABLE` (overview); `p5/hunter-ramp/frame-7` (the hunter's orange trail up the east ramp and along the deck: its log shows y 0 -> 7.7 -> 9.0 between 3.7 and 4.5 s; capture logs are not in git) |
| Only KADE ever duelled. | `DUEL 02 // ORIN` (job 9, contact KADE); DUEL 01's contact is now VESS with KADE as the rival; free play meets the roster in turn (`SPEEDER_ARENA_RIVAL=<name>` picks one). | `p5/sim/duel-briefing-orin` |
| MATCH WON / LOST was a stamp, then the score reset. | The last orbit holds with a result card in the `missionCard` style: score line with the rival's portrait, rounds, best grind, longest trail, energy left, credits (40 per round won, 150 for the match, 10 per second of best grind) paid into the same purse as the jobs. A / F / tap restarts against the next rival. | `p5/sim/match-result`, `p5/match-result/frame-19` (the hold) |
| The grind was a threshold surge damped toward a target. | Armagetron's curve: `accel = 22 / (1.2 + d) - 22 / (1.2 + 5)` against the nearest wall, x1.5 with a wall on the other side, applied as acceleration; boost is a burst (34 m/s^2 up to 68) that decays back to base at 0.3/s; below base it recovers at 5/s; every quarter turn costs 5 %; pads and the break-away kick are impulses on the same curve. Speed is a line the player draws. | `p5/grind-curve/log.txt` (36 -> 45 m/s along a 28 m wall, then 44, 43, 42 over the next seconds) |
| The deck was scenery. | A chain of four boost pads along the deck's north edge and a CHARGE pickup (amber, taller pillar) that only spawns on the deck: taken on contact, it fills energy and gives a burst. The hunter takes the nearest ramp when the player is up there. | `p5/deck-route/frame-4` (pads and charge on the deck), `p5/deck-route/frame-8` |
| A corridor run had no score and no rank. | Streak scoring (Sayonara Wild Hearts): a gate every 200 m (50), a beacon (150) and a kill (25, no climb) are worth base x streak; the streak climbs to x8 and a hit resets it. The strip shows `score xN`, the stamp `+400 x8` on the frame. Rank per job from fractions of the job's maximum (silver 40 %, gold 70 %), remembered in UserDefaults (`rank.<id>`) and shown on the briefing (`BEST RANK GOLD  SILVER 1,360  GOLD 2,380`) and on the result card (`SCORE  RANK  NEW BEST`). The score also pays credits (score / 5). | `p5/sim/streak-running`, `p5/sim/streak-result`, `p5/sim/streak-briefing-best` |
| HULL BREACHED ended 90 s of play. | Checkpoint respawn: twice per job the hull restores to 50 % in place (speed kept), the streak resets, 4 s go on the clock, `HULL RESTORED n LEFT` stamps, 1.5 s invulnerable. The strip shows `RESPAWN n`. The third breach fails the job. | `p5/hull-respawn` log: hull 0.12 -> 0.44 at 9.1 s and again later, third breach fails; `p5/sim/hull-respawn` |

| Long rounds stalled: two careful riders could circle for a minute. | Sumo zone (Armagetron): 25 s into a round a white ring appears at (0, 30) at 70 m radius and shrinks to 16 m over 20 s; inside it energy charges 8 %/s, outside it drains 7 %/s and an empty bar derezzes (`DEREZZED - OUTSIDE THE ZONE`; the rival too). The ring is a unit tube band scaled per frame plus a faint disc; `ZONE` stamps when it opens and the arena block reads `ZONE 42 m  STAY INSIDE`. The zone is every temper's goal once it is within 12 m of the edge. `SPEEDER_ARENA_ZONE_AT=<s>` brings it forward for captures. | `p5/sumo-zone/frame-3` (overview, ring at 63 m), `p5/sumo-zone-chase/frame-2`, `p5/sumo-zone-drain` log (energy 0.60 -> 0.40 outside, 0.60 -> 0.82 inside), `p5/sim/sumo-zone` (strip) |

Capture hooks added: `SPEEDER_ARENA_RIVAL=KADE|ORIN|SABLE`, `SPEEDER_HOLD_RESULT=1` (the demo accepts the
briefing but leaves the result card up), `SPEEDER_DEMO_BOOST=always`, `SPEEDER_ARENA_ZONE_AT=<s>`; the
arena log line now carries the rival's position, speed and its derez cause.

The rival's trail keeps the orange opponent role colour; only the tag, portrait and badge carry the
rival's own colour. Not done: feel tuning of the accel constants on the phone (the user's call).

## 18 Sep 2026: assessment pass (unbuilt; see `assessment-2026-09-18.md`)

| Was wrong | Changed | Verify with |
|---|---|---|
| Every corridor job authored 8-14 blocks (320-560 m) and repeated its last block for the rest: RELAY 01 had no obstacles for its last 2 km, all beacons sat on the empty "sweep end" block, and a scripted demo earned gold. | `TrackComposer` composes the whole distance from a per-job recipe (bends kept centred, fields, split, conduit, undercity, skyway, landmarks) plus a two-block finish. | `SPEEDER_MISSION=0 SPEEDER_CAMERA=overview` at 9 / 20 / 40 s |
| Only the fork could reach the tunnel and skyway; the canyon jobs had no landmarks. | `.undercity` and `.skyway` phrases place those blocks directly; `TrackBlock.dressing` adds the overpass (rock arch in the canyon) and the gateway on city blocks. | `SPEEDER_MISSION=6` at 12 / 30 s |
| No audio. | `SoundEngine`: synthesised cues and loops, wired on the same frame as the acks. | phone, sound toggle |
| Meters two-state, timer red-only, pursuer a number, no speed, no lead on sections. | Three-state pulsing meters, timer amber / red / pulse + ticks, GAP bar, km/h, "IN n m" chip with an approach tone. | simulator HUD screenshots |
| Touch could not fire or use a pickup; cards blocked the gear; a stale card stayed up in free play; an idle pad disabled touch. | Quick tap = A; tap target is the card; state cleared when the loop is off; idle pad yields. | simulator |
| Theme change from The Grid never rebuilt (`world != nil` guard), so the loop dead-ended after a duel. | Guard on world or arena. | play DUEL 01 to the end |
| Boost flickered at an empty hull; cruise adjustable mid-job; reset kept ranks; payout replayable; respawn stamped on a time-out; negative mission env crashed. | Hysteresis, cruise lock, full reset, payout banked with the index, order fixed, `abs`. | headless reasoning; play |
| Arena: PHASE lost on a second pickup, farmable kick, tunnel grind out-earned boost, rival ceiling 96, double derez. | Fixed in `ArenaController`. | `grind` and `wall` demo scripts |

## 18 Sep 2026 (second pass): the game

| Was thin | Changed | Verify with |
|---|---|---|
| Nine jobs in a row, no story, credits with no use, a passed job finished. | Three chapters, eighteen jobs, a debrief line per job; salvage and dive kinds; inbox with replay at half pay; garage with four upgrades; flags kept. | `SPEEDER_MISSION=8` (salvage), `=10` (dive), `=17` (VESS); simulator screenshots of the briefing with the inbox and garage |
| Time only counted down; a failure was a card round-trip. | Gates add 1.5 s; the failed card's A relaunches after the rebuild. | play |
| The rival died in its own pockets; one competence level; a double derez was a player loss. | Occupancy grid + flood fill area term, loop guard, skill tiers by reaction, void round. | `drive` script from `-40,40,0` against KADE / ORIN / SABLE: rounds survived before vs after |
| No music. | Three generative layers per world, intensity-driven. | phone |

## Still open (noted, not done)

- The camera up-vector stays world-up in the conduit; F-Zero-style surface-normal tracking would
  read better on the pipe walls but changes the reference look.
- Tunnel and conduit lighting is a post-pass blend only; the tunnel's own emissive rings do not
  fade in.
- The result card ends the run on the frame the distance is reached; a short coast-down with the
  drop marker in view would be the next step (research shortlist item 1).
