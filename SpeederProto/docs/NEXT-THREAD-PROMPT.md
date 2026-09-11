# Kickoff prompt for the next thread: research pass + polish pass

Paste the block below as the first message of a new Claude Code thread opened in
`/Users/markbailey/Desktop/GS - GamenCtr/GS - Racer`. The previous kickoff (The Grid) and the
mission runner are done; see `../README.md` and `game-direction.md`.

---

Read `CLAUDE.md` in this workspace first, then `SpeederProto/README.md` and
`SpeederProto/docs/game-direction.md`. Build the Mac app and run one capture per world
(`SPEEDER_VARIANT=grid`, `canyon`, default) plus one mission (`SPEEDER_MISSION=1`) so you have
seen the current state before changing anything.

State: three worlds (Neon City, Sunset Canyon corridors; The Grid light-cycle arena with
parking-garage levels), a mission runner (delivery, search, escape, duel), a briefing avatar from
the Character Creator / Avaturn pipeline, all on the iPhone 12 over Wi-Fi. Tron-clean tone, single
player, mission-runner structure.

Two pieces of work, in this order:

**1. Research pass (spawn agents, in parallel).** Launch several research agents, each on a
different set of comparable games, and have each return a short list of concrete features or
visual elements we could leverage, with a one-line note on how it would map onto our engine
(corridor scroller, arena trails, mission runner). Suggested split:

- Light-cycle and arena games: Tron: Legacy game, Armagetron Advanced, 3dLightCycles, LightRider.
- Corridor / anti-gravity racers: Wipeout (2048, Omega), Redout, BallisticNG, Distance, Rollcage/GRIP.
- Mission-structured and story-light racers: Distance adventure mode, Need for Speed Underground
  job structure, Burnout, Sayonara Wild Hearts, Thumper, Rez.
- Presentation and feel: Trackmania, F-Zero GX, Star Fox (rail sections), Mirror's Edge (flow).

Ask each agent for: the three most transferable mechanics, the three most transferable visual
or audio-visual tricks, what those games do at transitions (section changes, speed changes,
hits), and what they do for a hub or between-run screen. Merge the results into
`docs/research-comparables.md` with a ranked shortlist of what to build next, and stop there
for the research: do not implement it in this thread unless it is a one-liner.

**2. Polish and clean-up pass (the main work).** Go through the game as a player and make the
motion, actions, controls and visuals feel like one system. Known rough edges to start from:

- Section transitions in the corridor: street to conduit, conduit back to street, fork entry and
  merge, tunnel and skyway entry. They should read as continuous: ease the altitude clamp and the
  tube roll in and out, blend the lighting and fog over a few metres, bring the light rings and
  the walls in with a lead-in, and never pop geometry or snap the camera.
- Vehicle motion: lean, yaw, pitch, hover bob and camera lag should all respond to the same
  inputs with consistent timing; check boost, brake, hits and scrapes for jolts that fight each
  other. The arena camera and the corridor camera should feel like the same rig.
- Actions: fire, boost, jump, pickup use, snap turns. Each needs a visible and haptic response
  within the same frame, and the HUD should acknowledge it.
- Mission flow: briefing to run to result to next job should be a clean sequence with no
  dead frames, the parked bike should idle convincingly, the avatar should face the camera and
  the world should not rebuild visibly behind the card.
- HUD: one visual language (the mission cards, the arena meters, the stats block, the settings
  panel); check phone legibility at 390 pt.
- Anything else you notice. Keep a list in `docs/polish-log.md`: what was wrong, what changed,
  which capture shows it.

Verify every change with captured frames (Mac captures for the world, simulator screenshots
for the HUD), commit as you go, push to GitHub, and push meaningful builds to the phone.
Keep the two corridor looks (Neon City, Sunset Canyon) as they are unless a change is clearly a
fix. Update `README.md` and `CLAUDE.md` with anything the thread after you must know.

---

Notes for whoever runs this:

- The mission `runSeconds` clock and the arena countdown are the timing sources for scripted
  captures; `SPEEDER_HOLD_BRIEFING=1` keeps a briefing on screen.
- Transitions live in `WorldScroller` / `RoadSegment.apply` (style groups toggle per segment),
  `SpeederController.update` (tube clamp, wall roll) and `CameraRig.update` (inTube). The conduit
  entry is currently a hard switch when `currentBlock.style == .tube`.
- The phone must be unlocked for `devicectl install`; a locked phone fails with error 12040.
