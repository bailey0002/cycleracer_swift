# Polish log (11 Sep 2026)

One line per rough edge: what was wrong, what changed, which capture shows it. Captures live
under `Captures/polish/` (`baseline/` is the state before this pass; `p1/`, `p2/`... are the
verification runs; the helper `Captures/polish/capture.sh <dir> <seconds> ENV=...` runs the Mac
app in demo mode and kills it, and scene time starts about 8 s of wall-clock after launch).

## Corridor section transitions

| Was wrong | Changed | Capture |
|---|---|---|
| Entering the conduit snapped the vehicle from the flat lane limit (x up to 6.9) into the cylinder (x within ~1.9 at hover height) on one frame; leaving it snapped a high vehicle down to the 5.6 m altitude cap. | `WorldScroller.tubeBlend` eases 0 to 1 over the 24 m before the mouth and back over the last 24 m inside; `SpeederController` clamps against both constraint sets and mixes the results by the blend. The wall roll and the camera's tube gains use the same blend. | `p1/conduit/frame-4` .. `frame-5` (entry), `frame-8.5` (exit ahead) |
| The conduit, the undercity tunnel and the skyway started at a bare segment edge: the pipe wall simply began, the tunnel walls began, the deck rails began. | `RoadSegment.buildPortals`: an entry and an exit frame per style (pipe collar + lit rim + flange + hood and pillars; tunnel arch with lit inner edge and a light pool outside; skyway gate arch). `setNeighbours` enables the entry frame when the previous segment has a different style and the exit frame when the next one does. | `p1/conduit/frame-4` (pipe mouth), `p1/fork-tunnel/frame-4.5` (tunnel arch ahead) |
| No lighting change between the open city and an enclosed section. | `WorldScroller.enclosure` (0 open, 1 tunnel/conduit, 20 m lead) feeds `PostProcessor.enclosure`: fog density x2.5, fog colour darkened, the horizon glow removed and the vignette tightened, all blended over the lead-in. Neon City and Sunset Canyon in the open are untouched. | `p1/conduit/frame-5` vs `baseline/default/frame-9` |
| The fork decided the branch on the frame the split passed the player and re-placed the fork segment (7 deg yaw) and the four branch segments (up to 9 m sideways) at once: a visible pop 30 m ahead, and the tunnel/skyway geometry appeared 40 m ahead at that moment. | Soft decision: from 30 m before the split the side is sampled from the player's x and the branch is styled then (so its mouth is 60 m out, in the fog); the road's divergence `forkBlend` ramps with distance over 24 m of travel and the fork plus downstream segments are re-placed every frame while it moves; the side locks when the split passes. Changing side before the lock ramps back. | `p2/fork-over/frame-4.5` .. `frame-6` |
| The fork segment's building rows (built at the city's 11.5 m) overhang the branch roads, which slide 5 m + 4 m outward: the vehicle and the camera drove through lit towers right after the split. | The fork segment's `buildingGroup` is scaled 1.7x in x, so its rows stand at 19.5 m and clear both branches. | `p1/fork-skyway/frame-5.5` (before) vs `p2/fork-skyway/frame-5.5` |
| The V divider had no collision: the vehicle passed through the wedge and the camera went inside it. | `WorldScroller.wedgeLimit`: past the nose the divider's face on the player's side is a lane limit (plus 1.3 m), so the vehicle scrapes along it with sparks and speed bleed like the roadside barrier. | `p2/fork-over/frame-5` |

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

## HUD

| Was wrong | Changed |
|---|---|
| Four panel styles (stats 0.45/6 pt radius, race block the same, mission cards 0.62/10 pt with a cyan stroke, settings 0.5/8 pt). | One `hudPanel()` modifier: black 0.55, 8 pt radius, thin accent stroke; cards use 0.7. |
| Two meter components (`meter` in the arena block, `stripMeter` in the mission strip) with different label treatment. | One `meter`: 48 pt bold label, 110 x 6 bar. |
| Cyan came from `.cyan`, pickups from `.purple`, prompts were plain text. | `HUDStyle.accent` / `.pickup`; every card ends in the same `prompt()` (accent key cap + action). |
| 10 pt monospaced everywhere on the phone. | `HUDStyle.baseSize` 11 on iOS (10 on the Mac), big numbers 22, brief text 12. |
| The diagnostic fps/entities block always sat top-left on the phone. | On iOS it shows only while the settings panel is open. |
| No acknowledgement of actions. | Pip row bottom-right, centre stamps (see above). |

## Still open (noted, not done)

- The camera up-vector stays world-up in the conduit; F-Zero-style surface-normal tracking would
  read better on the pipe walls but changes the reference look.
- Tunnel and conduit lighting is a post-pass blend only; the tunnel's own emissive rings do not
  fade in.
- The result card ends the run on the frame the distance is reached; a short coast-down with the
  drop marker in view would be the next step (research shortlist item 1).
