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

## 18 Sep 2026: assessment pass (see `assessment-2026-09-18.md`; built and verified the same day, third pass below)

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

## 18 Sep 2026 (second pass): the game (verified in the third pass below)

| Was thin | Changed | Verify with |
|---|---|---|
| Nine jobs in a row, no story, credits with no use, a passed job finished. | Three chapters, eighteen jobs, a debrief line per job; salvage and dive kinds; inbox with replay at half pay; garage with four upgrades; flags kept. | `SPEEDER_MISSION=8` (salvage), `=10` (dive), `=17` (VESS); simulator screenshots of the briefing with the inbox and garage |
| Time only counted down; a failure was a card round-trip. | Gates add 1.5 s; the failed card's A relaunches after the rebuild. | play |
| The rival died in its own pockets; one competence level; a double derez was a player loss. | Occupancy grid + flood fill area term, loop guard, skill tiers by reaction, void round. | `drive` script from `-40,40,0` against KADE / ORIN / SABLE: rounds survived before vs after |
| No music. | Three generative layers per world, intensity-driven. | phone |

## 18 Sep 2026 (third pass): built, verified, fixed (captures in `Captures/polish/p6/`)

The two blind passes compiled first time on Xcode 26.6 (Mac and iOS simulator), no compiler
fixes needed. Verification, what it showed, and what changed:

| Checked | Result | Capture |
|---|---|---|
| RELAY 01 stays varied over its length. | Overpass with a hanging hologram at 9 s, gateway + obstacle rows at 20 s, gateway (NEXUS) + bend + rows at 40 s (1.7 km). | `p6/m0-overview/frame-9,20`, `p6/m0-overview-40/frame-40` |
| RELAY 03 has two conduits. | Portal at 6 s, inside the tube at 10 s, second tube at 20 s, gateway between. | `p6/m4-conduits/frame-6,10,20,26` |
| RELAY 04: canyon undercity, rock-arch overpass, split. | Undercity roof at 12 s, arch at 18 s and 30 s, the split's skyway branch (hoops, billboards) at 24 s. | `p6/m6-canyon/frame-12,18,24,30,38` |
| SWEEP 02 skyway and beacons. | Skyway lead-in at 10 s, beacon rings on the canyon road at 15 / 26 s. | `p6/m7-skyway/frame-10,15,26` |
| SALVAGE 01, DIVE 01, DUEL 04. | Canyon rows with the arch; the dive's conduit-first track (rock-pipe look) and a checkpoint respawn in the log; DUEL 04 vs VESS runs rounds and ends MATCH LOST 0-3 for the scripted drive. | `p6/m8-salvage`, `p6/m10-dive`, `p6/m17-vess` |
| DUEL 01 -> RELAY 04 (the old dead end). | `SPEEDER_ARENA_KILL_RIVAL=2`: match won 2-0, the success card accepted, the world rebuilt into the canyon (entities 4467), RELAY 04 briefing accepted and running at t=15. | `p6/duel01-flow/log.txt` |
| The rival's own-trail deaths. | New hook `SPEEDER_ARENA_IMMORTAL=1` (the player drives through walls) so the rival is watched for a whole run: KADE 3 derezzes (player trail), ORIN 3 (boundary x2, player trail), SABLE 3 (player trail); no own-trail death in nine. Rounds last 20-30 s in a trail maze. `p5/temper-*` had one hazard death in three short rounds, so the numbers are not comparable; the own-trail cause is what mattered. | `p6/immortal-*/log.txt` |
| Simulator HUD: briefing with chapter line, inbox chips, garage rows. | All present. Two fixes: the card overlapped the race block on the 390 pt phone (the block is now hidden while any card is up); with a forced `SPEEDER_MISSION` the inbox showed only RELAY 01 (a forced job now counts as reached, so the chain up to it is listed and the chip scrolls into view). | `p6/sim/briefing-m8-20`, `briefing-m12-18` |
| Running strip: hull amber / red, streak, respawns, gate stamp with `+1.5 s`. | Reads on the phone. | `p6/sim/relay01-22`, `run01-26` |
| Escape GAP bar. | Present, but the strip ran into the gear button; the pursuer block is now two lines (pursuer + distance, gap bar) and the strip spacing is 12. | `p6/sim/probe-m3-34` |
| Failed card with RETRY NOW; result card with flags and debrief; the CONDUIT chip. | Failed card (HULL BREACHED, race block hidden); result card DELIVERED with payout, SILVER + NEW BEST, flags with the new ones bracketed, VESS's debrief line; `CONDUIT IN 66 m` chip above the pips at 193 m. | `p6/sim/dive01-failed-110`, `relay01-result-180`, `relay03-chip-20` |
| Demo accept. | In demo mode the accept was a held button, so a result card in the arena never got its edge and the corridor loop stalled after a rebuild; the demo now pulses the accept (0.5 s on, 1 s off), which also fixes DUEL -> next job in captures. | `p6/duel01-flow` |
| Death attribution on The Grid (kickoff step 3). | The centre state reads `CUT OFF BY KADE` / `BOXED YOURSELF` instead of `DEREZZED - OPPONENT TRAIL` / `OWN TRAIL`. | log `state=` |

Not verified here: sound and music levels, the Backbone browse / buy on the briefing, and the
balance numbers (all need the phone; the phone was asleep during this pass). The void round is
verified by reading (`ArenaController` tests both collisions on the same frame) but not by a
capture: the scripted drives cannot make both bikes hit a wall on the same frame.

## Still open (noted, not done)

- The camera up-vector stays world-up in the conduit; F-Zero-style surface-normal tracking would
  read better on the pipe walls but changes the reference look.
- Tunnel and conduit lighting is a post-pass blend only; the tunnel's own emissive rings do not
  fade in.
- The result card ends the run on the frame the distance is reached; a short coast-down with the
  drop marker in view would be the next step (research shortlist item 1).

## Pass 1 of the market assessment: the presentation foundation (26 Sep 2026)

Built from `docs/assessment-2026-09-26-market.md` section 7, pass 1 (C1, C2, B1, A2, A3, D2, D5, D8).
Mac captures in `Captures/polish/p7/`, simulator HUD shots in `Captures/polish/p7/sim/`. The device
binary is in `build-device/` (the phone was locked; install pending).

| Item | What changed | Capture |
|---|---|---|
| C1 type and chrome | Chakra Petch (SIL OFL, `Resources/Fonts`, registered at launch by `HUDStyle.registerFonts`) for display and labels; no translucent boxes: hairlines, gradients, cut-corner chips and cards (`CutCorner`); HUD zones per the spec: job code + timer top-left, HULL bar + objective top-centre, score + streak chip + respawn pips top-right, speed + altitude ladder + section bottom-left, "coming up" chip bottom-centre, actions bottom-right; distance / hits / kills and the fps block moved into the settings panel; the HUD accent is the world's road colour (`Theme.hudAccent`); numeric roll on score, timer and objective; the streak chip springs on increase | `p7/sim/relay01-22`, `relay01-30`, `panel-22` |
| C2 glyphs and touch | Button art from `GCControllerElement.sfSymbolsName` (`ControllerGlyphs`, published by the game controller) on pips, prompts, garage and hint; touch play (no pad) gets 56 pt BOOST / FIRE buttons with a press state and a light impact (`TouchButton`), feeding `InputState.buttonBoost / buttonFire`; the hint shows for 8 s, again when a pad connects, and while the panel is open | `p7/sim/relay01-22` (the simulator exposes a virtual "Gamepad", so it shows pad pips) |
| B1 boost scalar | `GameController.boostLevel` (150 ms in, 400 ms out) reaches the post pass (`PostUniforms.section.w`): vignette tightens, the outer ring desaturates and darkens while the centre lifts (Thumper), streaks and aberration rise; the exhaust lengthens and the thruster glow and engine light rise with it; the HUD scales 2.5 % and brightens | `p7/boost/frame-9` vs `p7/cruise/frame-9` |
| A3 vehicle contact | A contact shadow (black glow sprite) under the bike that shrinks with altitude; the ground glow grows with throttle; thruster heat haze in the composite pass (`PostUniforms.haze`, value-noise refraction around the projected nozzle, radius and strength with boost) | `p7/cruise/frame-4` |
| A2 edge cadence | Emissive studs every 5 m on both road edges (in `roadPrimary`, so they follow the palette) and two chevrons per segment on the road centre (`roadSecondary`); painted in the canyon | `p7/lanes/frame-4`, `p7/canyon/frame-12` |
| D2 identity | `Missions/Player.swift`: callsign (typed once on the briefing, tap the name; `callsign` in UserDefaults), livery (tap the swatch to cycle; tints the bike's glows and lights and the arena trail via `ArenaController.playerColor`), a rank title (ROOKIE / COURIER / GATE-RUNNER / UNBOXED); shown on the briefing header, the result card, the duel score and the match card | `p7/sim/brief2-18` |
| D5 comms | `Mission.comms(contact:kind:trigger:)`: one register per contact (VESS clipped, KADE blunt, ORIN sharp), at most three lines per job (launch at 1.6 s, one event: section ahead / pursuer close / halfway, the last 320 m), eight words or fewer, shown under the objective with a comms blip (`ActionAck.commsSpeaker / commsText`) | `p7/sim/comms2-17` |
| D8 haptics | `GamepadInput.activeEngine()`: a pad's own actuators, else the phone's `CHHapticEngine` (touch play and pads without rumble such as the Backbone, which had no haptics at all before); `engineHum` is one continuous event restarted every 18 s and steered with dynamic intensity / sharpness from speed and boost; off while parked | phone only |

Not verified here: the haptics and the on-screen buttons (need the phone), the callsign keyboard on
the phone, the livery tint on The Grid by play. Pad browsing of the livery / callsign is not built
(touch or click only); a pad flow belongs with the title screen in pass 3.

## Pass 2 of the market assessment: the world (26 Sep 2026)

Assessment section 7, pass 2 (A1, A4, A5, B2 in its lightweight form, B3, A7). Captures in
`Captures/polish/p7/world-*`, `rain2`, `grid-side`, `grid-crash2`.

| Item | What changed | Capture |
|---|---|---|
| A1 sky and far layer | Night sky gains a hash-grid star field and a moon with a halo (also in the IBL); the Grid sky faint stars. `SkylineLayer` is theme-aware and has two parallax rings: the mid ring (towers, or wide mesas in the canyon) and a new far ring of dark wide silhouettes (150 to 380 m tall city slabs with antenna tips and neon strips; 90 to 200 m mesas) scrolling at a third of the mid ring's rate; the depth fog is the haze between them | `world-overview2/frame-6`, `world-canyon/frame-6` (far mesas replace the city towers the canyon used to show) |
| A4 brand typography | Brand mega-signs (up to 70 m wide, the existing procedural sign atlas) on the road-facing faces of far-ring slabs | `world-overview2/frame-6` (top right) |
| A5 weather | Screen-space rain in the composite pass (two hashed streak layers, slanted, faster and wider near; strength eases out inside the tunnels and the conduit; `weather` toggle) and lightning every 9 to 17 s (a cool lift on the haze and the frame for ~150 ms, a soft rumble; `SPEEDER_LIGHTNING_AT=<s>` for captures). A particle-emitter version was tried first and produced almost nothing on screen; the post pass version is deterministic and also shows in the simulator | `rain2/frame-5`, `rain3/frame-9.0` |
| B2 / B3 post pass | Linear depth is computed once per pixel and shared. Motion blur by reprojection: the world moves rigidly toward the camera, so last frame's position of a pixel is `travel` further away; six taps from here toward there, weighted to the outer ring, never on the vehicle (a mask around its projected centre and a depth test) with a shutter that opens with boost. The chromatic offset is applied inside every sample (`fetchCA`), which fixed a first cut where red and blue were re-sampled unblurred and fringed every blurred pixel. Ghost flares (three mirrored samples of the wide bloom, tinted) and a procedural lens-dirt mask lit by the bloom (`Theme.lensScale`); interleaved-gradient dither before the 8-bit write. The thruster haze now only refracts what is behind the bike | `world-neon2/frame-9` (cruise), `world-boost2/frame-9` (boost) |
| A7 The Grid | Trail walls are hot, not glass: a bright rim along the top edge, a heat flicker along the length, a translucent body; the glow skirt shimmers. Derez is a dissolve: the cycle's materials are swapped for `dissolveSurface` (a `CustomMaterial(from:)` per PBR material, so textures and tints survive) and burn away along a 3D noise front with a rim in the trail colour over 0.55 s, then the model hides; the shard burst and the light remain. `SpeederController.beginDissolve / updateDissolve / endDissolve`; `setVisible(true)` restores the originals | `grid-side/frame-8`, `grid-crash2/frame-5.2` |

Not built from pass 2: A6 (building archetypes and batching) is deferred to pass 4 with the
instancing gate; the volumetric fog slices and the datamosh glitch from the technique table were not
started. Not verified here: phone frame time with the blur (six full-resolution taps in the outer
ring; `motionBlur` and `lensFX` are HUD toggles so the phone pass can turn them off).

## Pass 3 of the market assessment: the cast, the code half (26 Sep 2026)

Assessment section 7, pass 3 items that are code (D1, D3, C4, C5, C6). D4 (the cast through
Character Creator 5 / iClone 8) needs the Windows machine and is Mark's; the pipeline and the proof
are in `docs/research-2026-09-26-reports.md`, report E. Simulator shots in `Captures/polish/p7/sim/`.

| Item | What changed | Capture |
|---|---|---|
| D1 reactive debrief | `Missions/Debrief.swift`: a reactive line per contact chosen from the run's outcome (two respawns > one > hull low > clean and fast > gold > new best > fast > sloppy > clean > evergreen; duels: sweep / boxed yourself / close), never repeated until the contact's others are spent (`said.<contact>.<key>` in UserDefaults); the job's own debrief stays as the essential beat under it. Failed cards get a per-contact, per-cause line (`Debrief.failure`) | `sim/result-93` ("A core burned. It comes off the fee."), `sim/intro-18` (failed card) |
| D3 rival card | A `.rivalIntro` phase between the duel briefing and the run (3.6 s, A skips it after 2.8 s, not in the demo): the rival's name huge in its colour, temper and tier ticks, its line, the head-to-head record (`record.<rival>.w/.l`, updated by duels and free-play matches), a taunt from the record (`Debrief.taunt`), a countdown hairline; slams in from the right; ROUND 1 stamps when it leaves. The briefing's right column shows contact and rival with the record | `sim/intro2-22` |
| C4 result reveal | `StagedCard`: title, then the rank letter (large), score and NEW BEST, flags, payout and credits, the reactive line, the debrief, 150 ms apart with springs | `sim/result-92`, `result-93` |
| C5 title screen | `titleVisible` at launch (off for the demo and with `SPEEDER_TITLE=0`): the parked scene behind a left gradient, the wordmark, the tagline, callsign / title / credits, the next job, a START prompt pulsing at 112 bpm; A / F / tap starts (the same press does not also accept the briefing) | `sim/title-17` |
| C6 briefing | Two columns: the job (title, job / pay / credits, brief, goal, ranks, flags) left and the contact (portrait, name, role) right, with VS + rival + record on duels; a LOADOUT row of owned upgrades; the inbox strip above a footer with ACCEPT pinned under a scrolling body (`HUDStyle.cardMaxHeight`), so a tall duel card never hides the button; the duel HUD reads DUEL // FIRST TO n with the callsign and the rival's name in their colours; stamps no longer draw over cards | `sim/duel-brief3-17`, `sim/intro2-17.5` |

`SPEEDER_RESET_PROGRESS=1` now also clears the records and the said-line sets (the callsign and
livery stay). Not verified here: the title on the phone with the Backbone, the rival card's sting.

## Pass 4 of the market assessment: the audio systems (26 Sep 2026)

Assessment section 7, pass 4, the audio items (D6, D7). B4 (RealityView migration), A6 (building
archetypes and batching) and D9 (Game Center) were not started: the migration carries touch and
capture-pipeline risk that wants its own thread, batching is gated on the iOS 26 instancing path,
and Game Center needs App Store Connect leaderboards that only Mark can create.

| Item | What changed |
|---|---|
| D6 music state machine | A fourth generative layer, drums (kick on 1 and 3 plus the "and" of 4 on the last bar, hats on the eighths, a clap on 2 and 4), rendered with the other three. All four layers sum into one mixer and one varispeed. `setMusic(intensity:lead:finalStretch:gated:)`: the arp waits for the first gate, the drums enter while boosting, on a streak of four, or when leading a duel; the final quarter of a job (or match point either way on The Grid) lifts the rate by 5.4 % (tempo and about a semitone together); every change lands on a bar line (the player time modulo the bar). `musicSlam()` on a finish: a one-bar duck and the slam back. `musicCut()` on a fail or a derez: the layers drop to the pad, detuned to 0.94 for 1.6 s |
| D7 ambience and room | An `ambience` loop per world, four seconds and crossfaded: Neon City hum with rain hiss and a muffled murmur, the canyon a breathing wind with gusts, The Grid a pure tone bed with a drifting whine; level 0.5 in the open, less in enclosed sections (`setAmbience`). The engine, boost and scrape loops pass through a large-hall reverb whose wet mix follows the enclosure (`setEnclosure`), so tunnels and the conduit are audible before they are seen |

Verified: both worlds run with sound on, through a Grid crash, without engine errors in the log
(`Captures/polish/p7/audio-*`). Two graph gotchas cost a bisect: a sub-mixer must have its sources
connected before it is connected forward, and `AVAudioUnitReverb` must be connected with `format: nil`
(forcing the mono format raises an ObjC exception that SwiftUI swallows, so the app sits idle with no
scene and no log).
Not verified: the mix itself (levels, the drum layer against the pad, the lift at the final stretch,
the beds under the music) needs the phone and ears; the `gain` constants in `renderMusic`,
`ambienceLoop` and the `setAmbience` levels are the knobs.

## Front end: splash, title menu, settings, rider, pause (26 Sep 2026, evening)

Asked for after the passes: the splash and the introductory settings. PR #2 was merged into master
first; this work is on `claude/front-end`. Simulator shots in `Captures/polish/p8/sim/`.

Findings that shaped it: the launch screen was empty (black) and there was no app icon; the title
text sat on black for the whole world build, and START could be tapped before the world existed (the
briefing then came up over black); the only settings were the developer panel (about 40 toggles, not
persisted, the gear on the title); a new player was RIDER with no prompt; the phone ran a Debug build.

Load timings (`load:` log lines, from launch to a ready world, Neon City):

| Build | Materials | Vehicle | Track (+ contact) | Ready |
|---|---|---|---|---|
| Mac Debug | 8.1 s | 0.7 s | 1.9 s | 11.9 s |
| Mac Release | 0.55 s | 0.47 s | 1.9 s | 3.3 s |
| iPhone 12 Release | 0.71 s | 0.41 s | 2.0 s | 3.9 s |

The track stage (`WorldScroller` init, synchronous on the main thread) is now the biggest block;
batching (A6) is where it would shrink.

| Item | What changed | Shot |
|---|---|---|
| Launch and splash | `UILaunchScreen` with `LaunchBackground` and `LaunchLogo` (the title's wordmark rendered by `Tools/render-brand.swift`); the SwiftUI splash shows the same image, so the hand-off is invisible; a Core Animation loader line (fill per stage, a sheen that keeps sweeping while the main thread builds) with the stage name; each stage animates over the time it took last launch; the wordmark flies low-left to the title as the curtain opens (`matchedGeometryEffect`) | `p8/sim/launch-1`, `launch-6` (sheen moved, stage unchanged), `launch-15` |
| App icon | Neon road into a skyline under a magenta horizon, the S of the wordmark; iOS single size + the macOS set | `Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png` |
| Title menu | CONTINUE / START with the next job, FREE PLAY, SETTINGS; select glyph pulses at 112 bpm; camera drift behind the parked bike (two slow sines, push in and out, bike right of centre), orbit on The Grid; pad and bass under it | `launch-15`, `launch-22` (drift) |
| Free play | Neon City, Sunset Canyon, The Grid (row tinted in the world's accent); always rebuilt (endless track or a match to three) | `worlds-16`, `flow-grid` |
| Settings | MUSIC / EFFECTS (0 to 10), HAPTICS, GRAPHICS (HIGH / BALANCED / BATTERY), GRID STEERING, RIDER, RESET PROGRESS (armed by the first press), DEVELOPER PANEL once unlocked; persisted as `prefs.*`; the graphics preset re-applies over each world's `Theme.adjust`; never applied in the demo | `settings2-16` |
| Rider and first run | WHO'S RIDING? on the first START (no stored callsign); pad arcade entry or the keyboard; livery swatches re-tint the bike live; RIDE goes to the briefing | `rider-16`, flow run |
| Pause | Menu / Escape / the pause button (touch); RESUME, SETTINGS, QUIT TO TITLE (the job returns to its briefing, `MissionRunner.abandon`), the dev panel once unlocked; the simulation holds, loops go silent, pad only | `paused-16`, flow run |
| Developer panel | Hidden: five taps on the version line in SETTINGS unlock it (Mac always unlocked, ` toggles); drawn over the menus when open | – |
| Fix: rain on The Grid | `post.rain` / `post.lightning` were only written in worlds with rain, so The Grid and the canyon kept Neon City's rain after any in-app world change (a job chain into DUEL 01 would have shown it too; fresh-launch captures never did). Reset in `build()` | `flow-grid` (before the fix) |

Verified by driving the simulator by touch (the MCP simulator tool; tool point = (390 - y, x) of the
landscape app point): title -> FREE PLAY -> THE GRID (match started) -> pause -> QUIT TO TITLE (Neon City
rebuilt, title up) -> CONTINUE -> WHO'S RIDING? -> magenta swatch -> RIDE -> briefing with the magenta
bike. Demo captures are unchanged: master vs this branch at t = 2 / 4 / 9 differ by 8.9 / 8.4 / 9.6 % of
pixels, master vs master by 8.2 / 8.5 / 41 % (rain streaks differ run to run since pass 2, and a lightning
flash lands on some runs), and the frames match by eye. One catch on the way: the title camera blend
started at 1, which would have pulled the demo's first seconds toward the title framing.

Not verified here (the phone): the launch screen on the device (iOS caches launch screens; reboot the
phone if the old black one shows), Backbone navigation and the callsign letter entry, the keyboard
callsign in landscape, the haptics switch, the music / effects levels by ear.

## Story pass: the spine, the message log, chapter cards, the rival's voice (27 Sep 2026)

From `docs/assessment-2026-09-27-story.md` (sections 5.1 to 5.4). Branch `claude/story` off master
after PR #3 (the front end) was merged. Simulator shots in `Captures/polish/p9/sim/`, the Mac A/B
frames in `Captures/polish/p9/cruise/`, the duel log in `Captures/polish/p9/duel/log.txt`.

Findings that shaped it: the player had no want and the packets were never revealed ("do not ask what
is in them" was never answered); debriefs flashed once on a card and were gone; a chapter change was a
world rebuild with no threshold; the ending was a payout line; the rival was silent during the duel.

| Item | What changed | Shot / proof |
|---|---|---|
| 5.1 The spine | `Mission.deliveries`: every program rides a route (its name, its right to ride); the player's is provisional and VESS holds the licence; the packets are riders' routes, SABLE buys them and derezzes the rider; the last chapter-1 packet carried the player's own; the ledger's last line is the player's. About a dozen brief / debrief lines rewritten, nothing contradicted. The ending is true: `Player.title(finished:)` gives ROUTE-HOLDER once every job is cleared (earned by the story, not by golds), a last message from KADE and a signed-off line from the unseen sender post to the log, and VESS joins the free-play roster (`Rival.freePlayRoster`) | `tap-a` (RELAY 01's brief) |
| 5.2 The message log | `Missions/MessageLog.swift`: briefs (posted on launch, once per job), debriefs and the reactive line (on the card), garage purchases and unlock notices (INBOX), chapter openings, and the unseen sender `??` (one static line per chapter, Tron 2.0's "Guest", resolved by the reveal; `Mission.staticLine`). Persisted as one array (`messages`, capped at 160, deduplicated on sender + text; `messages.read` for the unread count; cleared by RESET PROGRESS). Read from the title (MESSAGES row, "n NEW // LAST FROM x"), the pause menu (in a job), and the briefing (the envelope chip next to the chapter line, a tap opens it). `Screen.messages`, `openMessages()`, `SPEEDER_SCREEN=messages` | `messages-briefing`, `msgscreen-22`, `title-22` |
| 5.3 Chapter cards | `MissionState.Phase.chapter`: the first job of a chapter shows a card once (`chapter.seen.<n>`): district, a forty-word paragraph (`Mission.chapterIntro`), the cast's standing (CONTACT / RIVAL / WITH YOU, unknowns greyed, blurred and `????`), the rider's callsign, title and purse. OPEN CHAPTER (A / tap) goes to the briefing and posts the chapter and the static line. Shown on launch, after a success into a new chapter, after a reset, and after quitting to the title. `SPEEDER_CHAPTER_CARDS=0` marks all seen (captures); `SPEEDER_HOLD_BRIEFING=1` holds the card too | `chapter1`, `duel-29` (chapter 2 over the canyon rebuild) |
| 5.4 The rival's voice | `Debrief.rivalLine` and `GameController.rivalSay`: one line per round at most, chosen from the round's outcome (won, cut off, boxed yourself, other), the lead, match point, and the record at match start ("Again? 2 - 1."), shown as the comms stamp in the rival's colour 2.4 s after the derez, once the attribution stamp has cleared; never on the derez frame, never after the match beat. `Debrief.taunt` gains a third-meeting tier per rival | `duel/log.txt`: `comms: KADE: ONE MORE AND I WILL REMEMBER IT. at 14.5 s` (match point, 1-0) |

Verified: the simulator by touch (fresh slate: chapter card -> OPEN CHAPTER -> RELAY 01 briefing with the
new brief and "2 NEW" -> the log with the static line and the chapter; one tap moves one step); the demo
duel on the Mac (DUEL 01 with `SPEEDER_ARENA_KILL_RIVAL=6 SPEEDER_ARENA_IMMORTAL=1`: the comms line at
match point, the match won, the chapter 2 card, RELAY 04 running in the canyon at t=33); the Mac
cruise frames (`p9/cruise`, RELAY 01 at t = 4 / 9, `SPEEDER_MISSION=0 SPEEDER_CHAPTER_CARDS=0`): the
Neon City look is unchanged by eye (nothing in this pass touches rendering); a pixel diff against
`p7/cruise` is not meaningful because that baseline predates pass 2's rain and blur and ran the endless
track, so the next thread should refresh the baseline from master before its own A/B. The phone got the
Release build (installed and launched on the iPhone 12).
Not verified (the phone): the log on the Backbone (Menu -> MESSAGES), the chapter card's read on a
390 pt screen (it scrolls like every card), the rival's line by eye mid-duel.
Not built from the assessment: 5.5 (agency: two jobs unlocked at once, side offers, the fork
acknowledged) is owed after the phone pass, and D4 (the cast) is Mark's.

## Headless loop, balance, agency (27 Sep 2026, evening)

Branch `claude/phone-pass` off master (PRs #3 and #4 merged). The phone was locked for the whole
thread: the Release build was installed on the iPhone 12 but never launched (`devicectl` refuses a
launch on a locked phone), so the phone pass with the Backbone is still Mark's. What could be done
from the Mac was done: the headless test loop the kickoff's item 3 asked for, the balance numbers
from it (item 2), and assessment 5.5 (agency). Captures in `Captures/polish/p10/`.

### The headless loop (`Tests/MissionLoopTests.swift`, target `SpeederProtoTests`)

A macOS unit-test bundle hosted by the Mac app (`SPEEDER_TESTS=1` makes the app a bare window with
no world build, so the suite runs in about three seconds after the build):

```bash
cd SpeederProto && export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && xcodebuild test -project SpeederProto.xcodeproj -scheme SpeederProto-macOS -configuration Debug -derivedDataPath build-tests CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|Test Case.*(passed|failed)|Executed|credits per"
```

`HeadlessLoop.play` steps `MissionRunner.update` at 60 Hz with the game's own speed model (damp to
the target at 1.6 / 2.0, a hit takes 40 % of the speed and 70 ms of hit-stop, boost at 1.8x) for a
`Rider` (cruise, hits every n metres, boost share, beacon and target shares, the split taken).
`MissionRunner` takes its `UserDefaults` suite in `init` now, so every test has a fresh slate.
Fourteen tests: the boost hysteresis at an empty hull (the flicker class), one accept on the success
card advances once, a gate refunds 1.5 s, a replay pays half, salvage fails on missed targets, a
sweep fails short of the quota, the dive's double bruise, the helmet takes the first hit, inbox wrap
and garage refusal, the unlock order, the cleared-count migration, the tunnel offer end to end, the
offer rules, and the balance table (asserting the rank shape below).

### Balance (item 2) from the loop, not the phone

The table (`Captures/polish/p10/balance-table.txt`) plays the whole arc with six riders. Before:

| Finding (before) | Number |
|---|---|
| Every window left 30 to 50 s at plain cruise (the gates refund 1.5 s each, 12 to 20 per job) | RELAY 01: 30 s of 66 left; DIVE 01: 30 s of 62 |
| The FAST flag (a third of the window left) came free at cruise | every corridor job |
| A fifth of the streak score went into the purse | SWEEP 03 paid 5,085 credits, 3,540 of it score |
| Income per chapter for a rider with one or two hits per job | 11,011 / 13,681 / 15,652 |
| The garage (4,900) was bought outright in chapter 1 | – |
| Salvage kills were not in the gold ceiling | a sloppy SALVAGE run ranked silver |

Changed (`Mission.deliveries`, `Mission.maxScore`, `MissionRunner.update`, `Upgrades.items`):

| Knob | Was | Now | Rule |
|---|---|---|---|
| Windows (s), RELAY 01 / SWEEP 01 / RELAY 02 / RUN 01 / RELAY 03 | 66 / 80 / 90 / 76 / 76 | 50 / 63 / 76 / 59 / 63 | net cruise time (distance at 45 m/s minus the gate refunds) with a 30 % margin |
| RELAY 04 / SWEEP 02 / SALVAGE 01 / RUN 02 / DIVE 01 | 100 / 90 / 88 / 84 / 62 | 88 / 72 / 67 / 67 / 50 | same |
| RUN 03 / SALVAGE 02 / DIVE 02 / SWEEP 03 | 86 / 96 / 68 / 100 | 72 / 80 / 58 / 84 | same |
| Purse: time bonus per second left | 5 | 3 | |
| Purse: streak score share | score / 5 | score / 20 | |
| Gold ceiling | gates + beacons | + salvage targets at the capped streak | |
| Garage: HULL I / II, BOOST I / II, SPARE CORE, HELMET | 600 / 1200, 500 / 1000, 900, 700 | 1200 / 2400, 1000 / 2000, 1800, 1400 | the set (9,800) is about 1.7 chapters of a clean rider's income |

After (the same riders; "clean" boosts 15 % of the time, "sloppy" hits every 600 m, "reckless"
every 300 m with half the run boosted):

| Rider | Corridor ranks | Credits per chapter | Notes |
|---|---|---|---|
| cruise (never boosts) | gold | 4,441 / 5,998 / 7,965 | 11 to 25 s left, never FAST; caught on every escape (by design: boost opens the gap) |
| clean | gold everywhere | 5,729 / 7,452 / 9,603 | 16 to 39 s left |
| 1-2 hits | silver (gold on the sweeps) | 5,237 / 6,745 / 8,845 | |
| sloppy | bronze everywhere | 4,285 / 5,564 / 7,874 | 11 to 35 s left, one respawn on DIVE 02 |
| reckless | bronze; both dives fail (HULL BREACHED) | 3,489 / 4,095 / 6,262 | |

So a clean run is gold, a sloppy one bronze, the FAST flag takes boost, a dive punishes recklessness,
and the garage is two pieces in chapter 1 and complete late in chapter 3. Not measurable here and
still owed on the phone: the chapter-3 density (1.3), the KEEN tier's 0.10 s tick, and whether the
30 % margin feels tight or mean with real steering (the loop has no lateral cost; if the phone says
mean, raise the margin in one place, the comment over `Mission.gateSpacing`).

### Agency (assessment 5.5)

| Item | What changed | Proof |
|---|---|---|
| Order inside a chapter | Cleared jobs are a bitmask (`cleared.mask`; the `cleared` count stays for the roster, the titles and the debrief picker, and a count-only save migrates). The first job of a chapter opens the next two, each job after that needs one more cleared, a duel waits for every job before it, a chapter waits for the duel. After a success the runner moves to the next open job in order. Unlock notices per newly opened job | `testUnlockOrderInsideAChapter`, `testClearedCountMigrates` |
| Side offers | `SideOffer` in `Mission.swift`: a cleared job ridden again under one rule for a sender from the other side, opened by a flag on the base job, listed after the jobs as an amber chip with its bonus, posted to the log by the sender when the flag is earned. SIDE 01 THE TUNNEL LINE (KADE, CLEAN on RELAY 02: the split through the tunnel, +150; the skyway fails `TOOK THE SKYWAY`), SIDE 02 THE PIPE, DARK (ORIN, FAST on RUN 02: DIVE 01 with ten seconds less, +300), SIDE 03 THE WHOLE LEDGER (SABLE, GOLD on SALVAGE 02: SWEEP 03 with all ten beacons, +500). The bonus pays once on top of the replay rule; the offer's debrief goes to the log; a retry keeps the offer; the arc resumes after | `testSideOfferTunnelLine`, `testSideOfferRules`; simulator shot `p10/sim/offer-*` |
| The fork acknowledged | `WorldScroller.lastDecision` reaches `MissionRunner.update(branch:)`; `Debrief.Outcome.branch` prefixes the reactive line per contact ("The tunnel. Kade saw that." / "The skyway. Half the city saw that." for VESS; KADE, ORIN and a default for the offers) | `testSideOfferTunnelLine` |

Hooks: `SPEEDER_FLAGS=2:1,9:2` gives jobs their flags at launch (1 clean, 2 fast, 4 gold), which puts
the offers on the table for a capture; `MissionRunner.testSetFlags` does the same in a test.

## Generated art, first pass (28 Sep 2026)

Mark generated the first samples against `docs/art-brief.md` (five Neon City facade tiles, two
billboards, one skyline strip, two storefronts, two arena bowls, one jumbotron; source files in
`../new_images_per_Art_Brief_20260927/`). They are prepared into `Resources/Art/` (sips crop and
resize: facades 1024², billboards and storefronts centre-cropped to 1024 x 512 to lose the generated
bezels and street, the skyline cropped to its building band at 2048 x 614, the bowl with the crowd at
2048 x 683, the screen at 1024 x 512) and wired in by `Sources/Rendering/ArtLibrary.swift` (`Art`):
a missing file keeps the procedural look, `SPEEDER_ART=0` keeps every image out. Captures in
`Captures/polish/p11/` (`cruise` is the A/B against `p10/cruise`).

| Where | How | Result |
|---|---|---|
| Facades | each tile is both the albedo (tinted 0.5) and the emissive (1.25) of a `PhysicallyBasedMaterial`, appended to `materials.facades`, so five of eight buildings pick a generated tile with the existing UV scales (18 m and 24 x 36 m per tile) | the near towers read as balconies, pipes, air units and lit rooms (`p11/cruise/frame-4`); the frozen look otherwise holds |
| Billboards | unlit, appended to `materials.signs`, so the mega-signs and the building billboards pick them | KERB on a tower face at t = 9 |
| Storefronts | new 2:1 quads under the shop strip on the road-facing face (55 % of buildings), `materials.artShops` | a shop at street level on the right at t = 9 |
| Skyline strip | four thin boxes 620 m out around the corridor, alpha-faded top and bottom (`Art.faded`), `materials.artSkyline`; the fog cap `Theme.fogMax` went 0.92 -> 0.88 for Neon City so the strip keeps 12 % | a faint skyline in the haze past the gateway; the A/B frames differ by eye only in the facades and the horizon |
| Arena bowl | four thin boxes at `halfSize + 360`, black keyed to alpha with a tone lift (`Art.keyedBlack(lift: 4)`), `Theme.fogMax` 0.35 on The Grid | tiers, pylons and crowd lights behind the data towers (`p11/grid/frame-3`), still dim: tune `fogMax` and the lift on the phone |
| Jumbotron | four faces of a thin box over the arena centre at 46 m | not in the chase frames (it needs the bike to face the centre); check on the phone |

Two bugs on the way, both in `ArtLibrary`: a `CGContext(data: &array ...)` with a Swift array is a
dangling pointer (the context drew into a temporary; the keyed bowl came out as speckles) and flat
`generatePlane` quads this far from the origin never drew (the RealityKit zero-thickness cull from 11
Sep again; the backdrops are 0.5 m boxes now). The depth fog also takes 92 % of anything at sky depth,
so a backdrop needs the cap (`fogMax`, new `weather.z` in the post uniforms).

What the samples taught for the next batch: the generator ignores "no frame" (both billboards came
with a bezel and a building around them; the crop handles it) and "transparent sky" (the skyline came
with a painted sky and a fog band; the fade handles it, but a black sky would key cleanly). The
facades and the bowl were right first time. Still wanted from the brief: the canyon set, the crowd
strip, the far / mid skyline variants, more billboards with faces.

## Street polish from the reference render (28 Sep 2026, second pass)

Five items from Mark against the Unreal-vs-RealityKit reference image. Captures in `Captures/polish/p12/`.

| Item | What changed | Proof |
|---|---|---|
| 1. Grid colours | `FXSettings.gridPalette` (dev panel row "grid"; `SPEEDER_GRID_PALETTE=cyan|red|amber|violet`): `Theme.gridAccent` drives the floor lines, wall panels, rails, base lines, pylons, tower edges, deck bands, lamps, the fog colour, the environment map's horizon band and the bowl's tint (`ProceduralTextures.gridFloor/gridWall/environmentGrid(accent:)`, `ArenaWorld`). In a duel the accent follows the rival: KADE cyan, ORIN violet, SABLE amber, VESS red; free play uses the setting. A change rebuilds the arena | `p12/grid-cyan`, `-red`, `-amber`, `-violet` (frame-3): red reads strongest against the lime decks and the white trail; the bowl takes the accent |
| 2. Rain direction | The streak phase was `uv.y * rows + t * speed`; texture y runs down the screen, so the streaks climbed. Now `- t * speed` | by formula (a still frame cannot show it) |
| 3. Showers | `GameController.rainMode`: `SPEEDER_RAIN=always|showers|heavy|0`; the demo keeps `always` so captures align. Otherwise light showers (18 to 34 s on, 22 to 48 s off, swelling in at rate 0.35) in chapters 1 and 2 and free play, heavy showers in chapter 3 (strength 1.7, and `post.rainFog` thickens the depth fog by up to 110 % while it rains, so the streets close in). Lightning only while it rains | `p12/heavy/frame-9` against `p12/street/frame-9` |
| 4. Wider, darker street | Near-black asphalt aprons 12 m wide either side of the road (`materials.asphalt`, `SPEEDER_APRON=0` for the A/B), the near and tall building rows pushed 2.5 m further out, the far ring's tint 0.45 -> 0.30, the generated facades' albedo 0.5 -> 0.38. The driveable road, the barriers and the lane limit are unchanged (the fork geometry depends on them) | `p12/street/frame-4` vs `p12/noapron/frame-4`: the buildings stand on black instead of the violet void, the street reads wider |
| 5. Crossroads | `TrackBlock.Dressing.crossroad`, on 65 % of the composer's bend leads: a dark cross street 16 m deep through both building rows at the segment's middle (`RoadSegment.crossroadHidden`: anything whose bounds overlap the street is hidden on that block), lane dashes and three pairs of lights receding down each side street, red-and-white chevron barricades with red hazard lamps across each mouth just beyond the barrier, and a signal gantry 9 m before the crossing with three red arrow panels (`ProceduralTextures.arrowSign`, swapped per block to point left, ahead or right with the bend). The block is named "crossroads, left / right" | `p12/street/frame-5` (the gantry and barricades at the first bend of RELAY 01, arrows left, the road bends left), `p12/street-over/frame-5.5` |

Not changed: the driveable width (18 m; widening it means the barriers, studs, lights, the lane limit and the
fork's ±11.5 m rows all move together, a pass of its own), the Grid's default (cyan; the rival mapping
is the way in). On the phone: pick the Grid accent by eye (the dev panel row rebuilds), judge the showers'
timing and the heavy mode's visibility in chapter 3, and the crossroads at speed.

Follow-up (same day): the crossroads now forces the turn. A chevron barricade with a red rail and three
hazard lamps closes the half of the road the bend turns away from, 10 m past the crossing
(`RoadSegment.crossBarricade`, an `Obstacle` of kind `.barricade`, active on crossroad blocks only). Hitting
it costs a hit like any obstacle but the barricade stays up (`GameController`: only non-barricade obstacles
are hidden on contact). The app icon is now Mark's GRDRNNR: QUANTIS art (`AppIcon.appiconset`, all sizes
from the 1080 px source). `p12/junction/frame-5.6` shows the demo bike taking the hit on the closed half.

## The hoverboard: an alternative vehicle (29 Sep 2026)

Mark's question: could the skater and board from `kerb_skate_game` (the sibling project under GamenCtr) ride
this game as a flying board, same movement as the speeder, a rider with limited animation, glow on the board?
Assessment: low to medium, because the vehicle already sits behind one class (`SpeederController`) and KERB
ships RealityKit-ready USDZs. Built the same day as a **test build that leaves the speeder untouched**.

- **Assets** copied from KERB: `Resources/Board.usdz` (the skateboard, 8.7k tri) and `Resources/Rider.usdz`
  (`skater_dude1`, a Character Creator 5 export through KERB's `Tools/convert_cc.py`: 44 joints, no clips,
  rest pose = arms hanging). Both stay in KERB's frame: Y up, forward -Z, 1 unit = 1 m.
- **`VehicleKind`** (`Scene/SpeederController.swift`): `SPEEDER_VEHICLE=board` or the new SETTINGS row
  **VEHICLE: SPEEDER / HOVERBOARD** (`PlayerPrefs.vehicle`, `prefs.vehicle`; the change rebuilds the world).
  The speeder path is the original initializer unchanged; the board has its own `init(board:rider:materials:)`
  and shares every hook (`update`, `poseArena`, `tint`, `setVisible`, dissolve, lights, trail).
- **The board**: longest axis to Z, fitted to 1.7 m, deck top at the holder's origin, floating 0.35 m below the
  gameplay root (the deck rides 0.7 m over the road; `halfHeight` 0.9 for the taller box). KERB's board is one
  mesh with nine material subsets in file order, so the urethane wheels and bearing shields get a fully
  transparent material and the aluminium trucks an emissive cyan PBR: they read as hover pods. Edge light
  strips along both rails, a tail thruster core + halo, front / rear pod glows, a tight hover pool and
  contact shadow, the same particle exhaust at the tail.
- **`Scene/RiderRig.swift`**: a compact port of KERB's `SkaterRig` without the foot IK. Joint deltas are
  world-space rotations in the character's rest frame composed through the rest hierarchy into local joint
  transforms (`apply`), slerped toward the authored pose. The character axes come from the mesh (wide axis =
  left-right, toe direction = forward) and are converted into skeleton space, so KERB's calibrated signs hold
  (`+F` raises the left arm, `-L` swings a limb forward, `+U` turns toward the nose, `+L` on the spine leans
  the chest). `pose(bank:speedNorm:boost:climb:time:dt:)` is the surf stance: feet apart along the deck,
  knees 16 to 46 degrees (deeper with speed and boost, the hips drop by `legLength (1 - cos knee)`), hips and
  spine opened toward the nose, head turned down the board, arms out, a spine dive with speed that backs off
  when climbing, hips sliding into the turn and the spine countering part of the roll, an idle sway.
- **Camera**: `CameraRig.lift` (height, distance) from `SpeederController.cameraLift` (0.7, 1.4 for the
  board). `SPEEDER_CAMERA=side|side-front` adds a side elevation for pose checks.

Captures in `Captures/polish/p13/`: `side2/frame-6` (the stance from the right, the rider leaning down the
nose, pods glowing where the wheels were), `chase2/frame-12` (the tunnel), `front/frame-6` (the earlier
pass, wheels still on), `speeder/frame-6` (the default vehicle, unchanged). The rider rides goofy from the
chase camera (back to the right barrier); a `regular` flag is a one-line yaw if wanted.

Not built / owed: a rider choice (dude2, girl1 convert the same way), a riding clip from iClone (the rig
would play it through `AvatarActor`'s path), foot planting (the feet float a little at deep knees without
KERB's IK), the rider in the light-cycle arena (the board rides there through `poseArena`, unverified),
the phone feel (the taller camera on the 6.1-inch screen).

Follow-up (30 Sep 2026, Mark's two refinements after the first phone look): the board and rider are scaled
1.35x (`big` in the board initializer: deck 2.3 m, rider 2.4 m tall; `halfHeight` 1.1, camera lift 0.9 /
1.9) so they read on the phone. **Tricks**: pad X = 360 spin, pad Y = barrel roll (keyboard Z / C);
`SpeederController.startTrick` runs one at a time over 0.85 s with a smoothstep angle (soft launch and
landing), a hop of 0.9 / 1.2 m, the rider tucked (knees to full crouch, arms pulled in and down to the deck,
`pose(... tuck:)`), a centre stamp "360" / "BARREL ROLL", the section chime and a rumble. The trick rotation
is composed after the bank so the camera does not roll with it. Cruise speed on Y is disabled while the
board rides (Y is the roll); buying on the briefing still uses Y (parked). **Fire on the left bumper** (L1
joins A / L2 / X was moved off fire to the spin): `RiderRig.shoot()` snaps the nose-side arm straight down
the board for 0.38 s and turns the head after it (`aim` in `pose`). `SPEEDER_TRICK_AT=4:spin,7:roll` forces
tricks for captures. Frames: `p13/tricks/frame-4.4` (mid-360 from the side, the post pass's reprojection
blur ghosting the spin), `p13/chase3/frame-6.4` (upside down mid-roll in the chase view), `p13/chase3/frame-9`
(the 1.35x rider), `p13/fire/frame-3.3` and `frame-4.6` (the shot pose).

## KERB: GALACTIC, the companion frame (1 Oct 2026)

With the hoverboard in, this game pairs with KERB (the skate game in the sibling folder): same shop, same
four riders, the second trip through the cabinet. Mark's four shop renders are in
`skateboard (hoverboard) shop scene/` at the repo root; the game carries them as `Resources/story_1..4.jpg`.

- **Title.** "KERB: GALACTIC" everywhere the wordmark was SPEEDER: the title (`HUDStyle.wordmarkSize - 12`,
  tracking 6), the launch logo (`Tools/render-brand.swift`, now `--logo-only` so Mark's app icon is kept),
  the sub-screen over-heading, the window title and `CFBundleDisplayName` on both targets. The product
  name, bundle id and scheme stay `SpeederProto` so the phone install and every script are unchanged.
- **Opening** (`Views/StoryIntroView.swift`, `Screen.story`): KERB's motion-comic device in this game's
  chrome (Chakra Petch, cyan bubbles on near-black, magenta shout, cyan caption bar, scanlines on the
  cabinet beat). Four panels: the counter ("You kids back again? Ha! It's been a while."), the board
  held up ("Well, if you're looking for the board to own, this one's it… the Kerbie Astro." + "No wheels.
  Doesn't need 'em where it's going."), the point at the cabinet ("Oh, I see you eyeing that game again."
  / "Didn't you learn your lesson the first time?"), the vortex (shout "DIDN'T WASTE ANY TIME, HUH?!?!",
  flash + shake, caption "…and the cabinet takes another one. Only this time the machine is bigger."),
  then the black card "You were at the cabinet. / Now you're in it. Again. / The routes are the currency
  here. / Run them." with the wordmark. A hurries a beat, B / Menu skips; auto-advances. Plays once
  (`story.seen`), replay from SETTINGS > STORY. `SPEEDER_SCREEN=story SPEEDER_STORYBEAT=<n>` freezes a beat.
- **Riders** (`Missions/Riders.swift`, `Screen.riders`, `MenuRow.Kind.roster`): KERB's roster mirrored
  (Cal Reyes, Jonah Vance, Dominic Rook, Mira Sable; stills copied from KERB, USDZs as
  `Resources/Rider_<id>.usdz`, 4 to 32 MB each). The card: portrait, name, tag, two lines, four handling
  bars (STEER, CLIMB, BOOST, HULL: 0.85 to 1.15 multipliers that are live on the hoverboard: steer and
  climb speed in `SpeederController`, the boost gain in `GameController`, hit damage divided by hull in
  `MissionRunner.hullScale`), signature and home spot. Left / right choose, persisted as `rider.id`
  (`SPEEDER_RIDER=<id>` for captures). Changing the rider rebuilds the world when the board is the vehicle.
  The speeder ignores the handling.
- **Launch order** follows KERB: title -> RIDERS -> story -> callsign and livery -> the first briefing
  (the briefing keeps the mission story: the routes, the ledger, the rival). After the first run RIDERS
  is a title row and STORY a settings row.

Shots: `Captures/polish/p14/sim/` (title, story beats 1 / 3 / 6 / 7 / 9, riders page with Mira on the board
behind it, settings); `p14/cal|dude2|girl1/frame-5` (the three other rigs riding: 54 / 42 / 44 joints,
all pose with the same axes). Not built: rider intro clips on the card (KERB loops a 5 s mp4; the stills
are used here), a shop / garage tie-in, the story's audio.
