# Research: comparable games (11 Sep 2026)

Four research agents ran in parallel, one per family of games, each asked for the three most
transferable mechanics, the three most transferable visual or audio-visual tricks, what the
games do at transitions (section changes, speed changes, hits) and what they do between runs.
Their reports are merged below, lightly edited; the ranked shortlist at the top is the
synthesis. Nothing here was implemented in the thread that produced it (the polish pass that
followed took only the one-line rules of thumb).

## Ranked shortlist: what to build next

Ranked by (value to the mission-runner direction) / (effort), with the effort guess in brackets.

1. **Section-change stamp + HUD element toggle on one frame** (Star Fox 64, F-Zero "Boost OK").
   One centre-screen stamp per section change and per meter unlock; the HUD element for the
   mode appears with it. Reuses the mission strip. [S]
2. **Single energy bar: shield + boost fuel** (F-Zero GX, Wipeout HD). Hits, scrapes and boost
   all draw from one bar; rings/checkpoints refill it; what is left at the finish multiplies
   the payout. Replaces cargo integrity and the escape boost meter with one rule. [M]
3. **Streak-value scoring with reset on hit** (Sayonara Wild Hearts). Each ring/beacon is worth
   more than the last until a hit resets the value; result card shows a rank. One score rule
   for every corridor mission. [S]
4. **Checkpoint respawn with retained speed** (Trackmania, Thumper). Each track block boundary
   stores lane, altitude, speed; a fatal state rewinds there instead of ending the job. Fixes
   the "one mistake ends 90 s of play" problem on the phone. [M]
5. **Armagetron accel curve for grinding**: continuous proximity term, tunnel bonus between
   two walls, break-away kick on leaving, turn tax, decay to base. Our surge is a threshold. [M]
6. **Speed-driven chase camera + round-start zoom** (Armagetron custom cam: back 6 + 0.5 v,
   rise 4 + 0.4 v). Both rigs already scale with speed; add the zoom-in on READY. [S]
7. **Heat boost with red vignette + haptic at 85 %** (Redout 2, Distance) for the escape kind,
   later for all kinds if (2) is not built. [S]
8. **Takedown freeze-cam + boost extension** (Burnout 3) for the duel and escape kinds: a 0.6 s
   orbit when the rival derezzes, then snap back. Our crash orbit already exists for the player. [S-M]
9. **Colour-wave palette sweep on boost or tier-up** (Wipeout Zone) using the role palettes. [S]
10. **SMS-style inbox as the hub** (NFS Underground 2): contacts text jobs in, colour-coded by
    kind; the avatar briefing becomes a call from the inbox. Fits the "thin story via contacts"
    direction. [M]
11. **Explosion breaches nearby trails; lingering dead tail; poly-scatter derez** (Armagetron,
    GLtron). [M]
12. **Honeycomb job board with Pass / Elite Pass and adjacent unlocks** (Wipeout 2048), plus
    "skip after N fails" (Sayonara). [M]
13. **Beat-quantised bolts + per-block music layer** (Rez). Needs a beat clock and stems. [M]
14. **Airbrake lane drift + jump barrel-roll** at the fork/skyway (Wipeout, BallisticNG). [M]
15. **Speed zones (floor patches) + brake reservoir** as arena level tools (Tron 2.0, Armagetron). [S]

Rules of thumb adopted in the polish pass (sourced in the feel report): hit-stop 50-100 ms;
shake from noise, not random; chase-camera settle 100-200 ms; FOV widens with speed, +8-12 deg
at boost, ramp in ~150 ms and out ~400 ms; every action visible + audible + haptic on the
same frame; a stable anchor on screen while the world rolls.

---

## Report A: light-cycle and arena games


### 1. Mechanics (most transferable)
1. Proximity acceleration with a break-away boost (Armagetron). accel = CYCLE_ACCEL/(OFFSET+D) - CYCLE_ACCEL/(OFFSET+WALL_NEAR) (defaults 15, offset 2, near 6 m, base 20 m/s); between two walls the TUNNEL/SLINGSHOT multipliers stack; leaving a wall applies a boost factor then adds a boost; speed decays back to base at 0.1/s above and 5/s below; every turn multiplies speed by 0.95; turns rate-limited to 0.1 s. Map: the grind surge should be a continuous curve, not a threshold, with a tunnel bonus and an exit kick; corridor: same formula against the conduit walls.
2. Rubber as a readable resource (Armagetron). Approach speed to a wall capped at RUBBER_SPEED*d (40); the reserve (default 1.0, sumo 5) drains while touching, kills at zero, refills over RUBBER_TIME 10 s; players deliberately "dig". Map: expose the edge meter drain/refill timings and make spending it a skill (tighter grind), not just a safety net.
3. Cycle as a summonable state plus trail-pass rules (Tron: Evolution MP; Battle Grids). Pass through own/allied trails; two turn styles (arc vs right-angle on the D-pad); jump over trails; discs thrown from the bike. Tron 2.0 adds green/red speed zones that override turbo pickups. Map: escape/duel jobs can use floor patches that set speed as cheap level tools; snap turn on D-pad alongside stick arcs.

### 2. Visual / audio-visual tricks
1. Trail wall shading (3dLightCycles): vertex colour blends white -> cycle colour from wheel to top, the wall curves upward from the rear wheel, vertical strips every 10 units. Map: TrailRenderer colour ramp + a subtle top curl, strips as a cheap length cue.
2. Grind feedback (Armagetron): sparks and a sustained sound only when actually rubbing; the HUD gauge turns red at penalty. Map: tie the spark emitter and a filtered loop to the same proximity term as the surge; recolour the edge meter.
3. Speed-coupled chase camera (Armagetron custom/smart cam): back 6 + 0.5*speed, rise 4 + 0.4*speed, pitch -0.58, turn-follow rate 4 (x4 after a reversal), a round-start zoom-in. Map: parameterise the chase cam by speed and add the round-start zoom.

### 3. Transitions
- Crash/derez. Armagetron: instant elimination, explosion breaches trails a short distance (EXPLOSION_RADIUS 2 in sumo, 0.75 competitive), dead tails linger 8 s. GLtron: crash paints a bitmap onto the wall hit and the cycle's polygons fly apart. 3dLightCycles: cycle explodes into its primitives then fades. Evolution/Legacy canon: collapse into cubic particles (spec.).
- Respawn. Evolution campaign cycle sections are checkpointed; Tron 2.0 tournaments retry the last track; Armagetron has no mid-round respawn.
- Speed changes. Armagetron brake is a reservoir (30 m/s^2 decel, depletes 1.0/s, refills 0.1/s); 1982 arcade uses the trigger as an analogue throttle; Evolution requires enough speed to clear jump gaps.
- Section changes. Evolution enters cycle sections via a drop/cutscene and exits at a fixed station; tracks offer a ramp to an upper tunnel as an alternate route.

### 4. Hub / between-run
- Battle Grids: isometric hub city with NPC quests as excuses to play the next game type; Bits currency buys cycles, discs, cosmetics; after each match the overall score is plotted on a graph.
- Evolution: persistent version levels (to v50) with memory-upgrade unlocks shared across SP and MP.
- Tron 2.0: ladder of circuits, winning unlocks faster bikes; retry from the current track.
- Armagetron: round -> score table (win +10, kill +3, die -2, suicide -4), match to 100 pts/10 rounds; sumo zone collapse pays survivors.

### 5. Build next (ranked)
1. Armagetron accel curve + tunnel bonus + break-away kick, turn tax, decay-to-base. M
2. Speed-driven chase cam (back/rise from speed) + round-start zoom. S
3. Explosion breaches nearby trails; lingering dead tail; poly-scatter derez. M
4. Speed zones (green/red floor patches) + brake reservoir as arena level tools. S
5. Post-run score graph and credit-based bike/trail unlocks (Battle Grids loop). M

Sources: wiki.armagetronad.org (Rubber, Grinding, Sumo, Custom Camera, Glossary), armagetronad settings.cfg and config doc, Wikipedia (Armagetron, GLtron, Tron 2.0, Tron: Evolution), Codex Gamicus GLtron, github erichlof/3dLightCycles, github MackinnonBuck/light-rider, christcenteredgamer Tron 2.0 review, GameSpot Evolution MP hands-on, GamersTemple guide, Nintendo World Report Battle Grids review, Push Square Evolution review, tron.fandom arcade.

---

## Report B: corridor and anti-gravity racers


### 1. Most transferable mechanics
1. Shield-as-currency economy (Wipeout HD/2048, BallisticNG). One energy bar pays for wall hits, weapon hits, out-of-bounds and barrel rolls (15% per attempt); unwanted pickups are absorbed back into energy. Zero energy = explosion. Mapping: a single shield bar that boost, scrapes and bolt hits draw from, plus an absorb input (hold Fire) that converts an unused pickup into shield; shield left at the finish is a payout multiplier.
2. Overheat boost with health as overflow (Redout 2, Distance). Past the OVERHEAT line boosting drains hull; a few seconds without boosting repairs and cools. Distance: boost/wings/wall-ride build heat; checkpoints reset heat; mid-air tricks refund cooldown; wings auto-close at 95% heat. Mapping: replace the escape-mission boost meter with a heat bar for all modes; checkpoints/rings dump heat; arena jump and grind refund heat.
3. Airbrake drift + barrel-roll boost (Wipeout, BallisticNG). Corners taken with the airbrake, not the stick; L-R-L on the stick during a jump = boost on landing at a shield cost. Mapping: L1/R1 airbrakes shift the lane with a visible yaw; at fork/skyway jumps a stick wiggle triggers a roll for a boost.

### 2. Most transferable audio-visual tricks
1. Speed-class colour wave (Wipeout HD Zone). On each class-up a wave of light sweeps down the track from the ship and recolours walls, sky and track; equalisers on billboards driven by the music. Mapping: on a boost or a mission tier-up, sweep a palette swap outward along the track instead of cutting.
2. Peripheral blur + subtle shake at top speed (Redout). Shaking camera that blurs the edges leaving a pinhole in the centre, sparks on contact, chromatic aberration (divisive). BallisticNG exposes FOV 40-170, dynamic FOV for chase cams, separate blur/shake toggles. Mapping: radial blur weighted by speed, FOV widening on boost, both behind a HUD toggle.
3. Music-pulsing geometry + red-screen overheat warning (Distance). Scenery pulses to the beat; the rear lights are the boost meter; near max heat the screen tints red with a warning tone. Mapping: emissive strength of obstacles/rings from an audio envelope; heat warning = red vignette + haptic + tone at 85%.

### 3. Transitions
- Speed pads: Wipeout pads give a burst that decays; consecutive pads chain. Zone class-up = the colour wave. Redout overheat is a ramp, not a switch.
- Hits / scrapes: Wipeout wall contact = energy loss + sparks; Redout scrape has a dedicated "painful" sound; GRIP camera flipping with the car after a crash is the most-complained-about element.
- Crash / elimination: Wipeout HD ship hurled along the track with a small explosion; Distance obstacles kill instantly, lasers slice the car, respawn after a few seconds or instantly on reset; Redout 2 offers rewind. (Exact respawn durations not sourced; spec. ~3 s.)
- Tunnels: no source gives a specific tunnel-entry effect; all rely on lighting change and audio reverb (spec.).

### 4. Hub / between-run screens
- Wipeout 2048: honeycomb grid of 60 events over three seasons; clearing a node unlocks adjacent nodes; Pass vs Elite Pass; failing an event repeatedly lets you skip it.
- Wipeout HD: bronze/silver/gold = 1/2/3 points, grids have thresholds; Photo Mode after a race.
- Redout 2: tiers B -> A -> S; 12 chassis, 7 part slots feeding six stats; load times criticised.
- GRIP: 11 tiers of tournaments, each ending in a rival duel; boost regenerates faster when trailing.
- Distance: medals bronze -> gold -> hidden Diamond; ghosts and leaderboards.
- BallisticNG 1.4: time-trial medals scale with how much you beat your own record.

### 5. Build-next ranking
1. Shield economy + absorb (Wipeout): unifies scrapes, bolts, boost cost; result-card multiplier. M
2. Heat boost replacing the escape meter (Redout 2/Distance), red vignette + tone + haptic. S
3. Colour-wave palette sweep on boost / tier-up (Wipeout Zone) using the role palettes. S
4. Airbrake lane drift + jump barrel-roll at fork/skyway (Wipeout/BallisticNG). M
5. Honeycomb job board with Pass/Elite Pass and adjacent unlocks (2048), plus skip after N fails. M

Sources: wipeout.wiki (2048, Zone), Wipeout HD Wikipedia, WipeoutZone forum, wipeout.fandom campaigns, gamepressure Omega guide, gamerant Redout 2 tips, lifeisxbox Redout 2 review, Worthplaying Redout review, redout.fandom upgrades, neognosis BallisticNG 1.4 notes, speedrun.com Distance guide, Steam Distance guide, Traxion Distance, DualShockers/Neowin GRIP reviews, GRIP Wikipedia, retro-replay Rollcage Stage II, Rollcage Wikipedia.

---

## Report C: mission-structured and story-light racers


### 1. Most transferable mechanics
1. Streak-scored collectibles with death reset (Sayonara Wild Hearts). Each heart is worth more than the last as long as you don't die; a death resets the value to 1. Ranks bronze/silver/gold per level. Map: score rings/cargo along the scripted track with a climbing per-item value; a hit resets the value, not the run. Result card shows rank.
2. Takedown fills and extends boost; aftertouch recovery (Burnout 3). Each takedown refills the boost meter and adds a segment (up to 4x); boost usable at any fill; a crash enters slow-mo "Impact Time" where you steer the wreck into a rival. Map: arena, cutting off the rival refills/extends boost; escape mission, pursuer takedowns extend the meter; corridor, a hit gives a brief slow-mo window to salvage a lane.
3. Sub-level checkpoints, per-section rating, two-hit health (Thumper). Levels split into short sub-levels rated C/B/A/S; a shell absorbs one hit, restored by the checkpoint bonus-thump; second hit = instant sub-level restart. Map: treat each TrackProgram block as a rated sub-section; result card lists section grades; a shield that a checkpoint ring restores.
Runner-up: NFSU2 sponsor contracts, required events marked on the map, hidden races found only by driving. Maps to required vs optional jobs and hidden jobs.

### 2. Most transferable audio-visual tricks
1. Quantized actions become music layers (Rez). Lock-on shots snap to the beat; destroying nodes raises the layer level 1-10, which swaps music, layout and enemies. Map: bolts fire on the next beat subdivision; each corridor block bumps a music layer; arena pickups add a layer.
2. Audio telegraphing before visual (Thumper). Each obstacle type has a distinctive sound a few hundred ms before it is visible; perfect hits glow + haptic ping; a hit cuts the percussion, red dust and sparks. Map: pre-cue the fork/conduit/obstacle lane with a sound; on collision duck the music and flash red ~0.3 s.
3. Takedown camera (Burnout 3). The action freezes and the camera swings around the crash before snapping back at full speed. Map: on rival crash, 0.6 s frozen orbit, then snap back to the chase cam; also the duel result moment.

### 3. Transitions
- Sayonara: vehicle/perspective changes happen while still moving; a hit rewinds level and song a few seconds (no cut); after repeated fails a skip prompt appears.
- Thumper: checkpoints are a bonus-thump you play through; death respawns instantly; speed scales with the multiplier.
- Distance: boost/jump/fly/wall-ride build heat; a checkpoint ring cools and clears damage; self-destruct respawns at the last checkpoint. (spec.: whole level resident, no loads.)
- Burnout 3: crash = Impact Time slow-mo, then resume; Paradise repair/gas forecourts fix and refill without stopping.
- Rez: layer-ups change the environment in place; being hit devolves your form rather than killing.

### 4. Hub / between-run screens
- NFSU1: menu-driven career; contacts each introduce an event type; story is a ranking board you climb, pink-slip races as beats.
- NFSU2: free-roam Bayview; the SMS inbox is the menu: Rachel and sponsors text race invites, new parts, cover shoots; envelope colour codes the subject; comic-style cutscenes.
- Burnout Paradise: events start at intersections; DJ Atomika delivers hints; restart was absent at launch and had to be patched in (a documented pain point).
- Burnout 3: 173 events across 10 locations, medals unlock cars.
- Sayonara: tarot-card level select; narrator; replay any level.
- Thumper: per-sub-level rating screen; Play+ as the hard remix.

### 5. Build next (ranked)
1. Streak-value scoring + instant rewind on hit (Sayonara): one score rule for all corridor missions, result card shows rank. S
2. SMS-style inbox as the hub (NFSU2): contacts text jobs in, colour-coded by kind; the avatar briefing becomes a call from the inbox. M
3. Beat-quantized bolts + per-block music layer (Rez): needs a beat clock and stemmed track. M
4. Takedown freeze-cam + boost extension (Burnout 3): arena duel and escape kinds. S-M
5. Section grades + one-hit shield restored at checkpoint rings (Thumper): per TrackProgram block. M

Sources: Wikipedia (Distance, NFSU, NFSU2, Burnout 3, Burnout Paradise, Sayonara Wild Hearts, Thumper, Rez), DigiPen on Distance, needforspeed.miraheze SMS, GameFAQs NFSU2, GameSpot Burnout 3 preview and Paradise update, Simogo, Nintendo Life, Pixel Poppers, thumpergame.com manual, SuperJump, Game Developer Q&A.

---

## Report D: presentation and feel


### 1. Most transferable mechanics
1. One-meter economy (F-Zero GX). Energy is both health and boost fuel: collisions, rival attacks and every boost drain it; zero = retire; pit strips refill; boost only unlocks from lap 2 ("Boost OK" flash), dash plates boost for free. Mapping: merge boost meter and hull into one bar; hits and boost both pull from it, rings/pickups refill it. Cheapest HUD win on a 390-pt phone.
2. Respawn-at-checkpoint with speed retained (Trackmania 2020). Respawn puts you at the last checkpoint at the speed you crossed it; separate respawn / give-up keys; no loading between attempts. Mapping: each TrackProgram block boundary is a checkpoint (t, lane, altitude, speed); a fatal hit rewinds in place instead of ending the mission.
3. Brake/boost on one recharging gauge + barrel roll as the parry (Star Fox 64). Boost and brake share a gauge that must recover before reuse; double-tap roll deflects lasers; somersault/U-turn only in All-Range Mode. Mapping: R2 boost / L2 brake on one gauge; double-tap steer = roll that deflects bolts. Arena: snap turns already play the mode-only-move role.

### 2. Most transferable visual / AV tricks
1. Runner Vision red (Mirror's Edge). Sparse palette, red reserved for the next traversal affordance. Mapping: add a single "next objective" tint (fork branch, beacon, delivery gate) and never use that hue elsewhere.
2. Camera motion scaled by speed, eye not head (Mirror's Edge). Bob rate rises with speed, camera rolls on somersaults; head-bob removed; a centre dot anchors the eye. Mapping: hover bob amplitude/frequency as a function of speed; keep a fixed nose marker as a stable anchor while the world rolls in the conduit.
3. Big text + narrator for state changes (F-Zero GX / Star Fox 64). "Boost OK" centre flash; gauge colour change and radar appearing at mode change. Mapping: one centre-screen stamp (<= 0.6 s) per section change and per meter unlock; HUD element appears/disappears with the mode.

### 3. Transitions
- Star Fox 64 corridor -> All-Range: wings shift, radar appears, U-turn/somersault unlock, all on one frame, not a fade. Rule: vehicle animation + HUD element + control unlock fire together.
- F-Zero GX pipe/cylinder/half-pipe: no cut; geometry rotates gravity and the camera follows the surface normal; falls only at entry/exit. Our conduit should keep the camera up-vector tracking the surface, not world-up.
- Trackmania checkpoint: split-time delta on crossing, no pause; respawn instant, speed restored. F-Zero GX death is a 60 fps explosion, no respawn in GP. No published durations for camera moves (spec.: <= 0.3 s for any transition camera slide).

### 4. Hub / between-run screens
- Trackmania: 25-track seasonal campaign in 5 tiers, 4 medals per track, tier trophies. Grid of tiles + medal icons is the whole hub.
- F-Zero GX: tickets earned in GP/Time Attack/Story buy machines, parts and chapters; Garage = 3-part custom machine. Credits -> unlock next job/cosmetic mirrors this.
- Star Fox 64: Lylat map draws the route taken; end card "Mission Accomplished" vs "Mission Complete" with hit count; medal = hit target with all wingmen alive. One binary rank + one number is enough for the phone result card.

### 5. Game-feel rules of thumb
- Hit-stop 50-100 ms (3-6 frames); Final Fight used 6 frames, SF2 ~10.
- Screen shake from Perlin noise, not random; colour-flash the hit object white for a frame or two (Juice It or Lose It).
- Chase-camera damping factor 0.1-0.25 (~100-200 ms settle).
- Widen FOV with speed; "less is more" for shake/FOV/post. (spec.) +8-12 deg at boost, ramp in ~150 ms, out ~400 ms.
- Sound: pitch-step repeated hits. (spec.) pickup chime rises per consecutive pickup.
- Every action = visible + audible + haptic on the same frame.

### 6. Build next (ranked)
1. Section-change stamp: centre text + HUD element toggle + control unlock on one frame (Star Fox) - S.
2. Hit-stop 4 frames + white flash + Perlin shake on obstacle hit, pickup, snap turn - S.
3. Speed-scaled hover bob + boost FOV kick with asymmetric ease - S/M.
4. Checkpoint respawn with retained speed at block boundaries (Trackmania) - M.
5. Single energy bar (hull + boost) with pit-strip refills and "Boost OK" unlock - M.

Sources: Wikipedia F-Zero GX; SDA F-Zero GX; GamingTrend Trackmania preview; Star Fox 64 manual; StrategyWiki; Engadget Mirror's Edge colour and sim-sickness pieces; Game Anim first-person movement; Arwingpedia; mutecity Pipe/Cylinder; doc.trackmania.com; Juice It or Lose It (GDC); Cinemachine notes; elliotdev feeling of speed.
