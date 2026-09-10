# Kickoff prompt used for the "Grid" light-cycle world (done 10 Sep 2026)

This prompt was run; the result is documented in `../README.md` (section "The Grid").
Suggested next steps: measure fps on the iPhone 12 over a long run, tune handling on the
Backbone (snap cooldown, turn rate, jump timing), add a second opponent, zones.

---

Paste the block below as the first message of a new Claude Code thread opened in
`/Users/markbailey/Desktop/GS - GamenCtr/GS - Racer`.

---

Read `CLAUDE.md` in this workspace first, then `SpeederProto/docs/lightcycle-research.md`.

Build a third world for SpeederProto: a Tron-style light-cycle arena called **The Grid**. It is a
different challenge from the two corridor worlds, so it needs a new game mode, not just a theme.

**Keep unchanged**: the Neon City and Sunset Canyon worlds, their look defaults, the HUD pickers,
controller mapping, the build/verify/deploy workflow, and the rule that meaningful builds get pushed
to my iPhone over Wi-Fi without asking.

**Mode**: an arena where the vehicle really moves (kinematic, deterministic: speed, heading, position),
instead of the scrolling corridor. Reuse the existing speeder model, chase camera rig (make it a
spring follow with look-ahead and speed FOV), post pass, input, HUD and Theme system. Add
`GameMode` (corridor vs arena) so the world picker can switch into it and back.

**Look**: dark grid floor with glowing lines that recede into fog, arena walls as tall luminous
panels, the existing role-colour discipline: player trail one colour family, opponent trails
another, hazards stay lime. Reflective floor via the existing IBL trick plus reflection decals.

**Build in this order, verifying each step with captured frames** (`SPEEDER_DEMO=1` plus a scripted
arena drive; add a `SPEEDER_VARIANT=grid` preset so captures land in the arena):

1. `TrailSystem`: logical trail as line segments sampled every 20 to 35 percent of vehicle length,
   spatial hash grid, swept-line collision from previous nose to current nose, ignore the newest few
   self segments. Arena boundary collision.
2. Trail renderer with `LowLevelMesh` (iOS 18 / macOS 15 API): chunked ribbons of about 256 segments,
   bright unlit core plus translucent glow ribbon, white-to-colour fade near the bike. Never one
   entity per segment.
3. Handling: velocity steering with lean, 90-degree snap turns as an option alongside analog
   steering (try both, capture both), brake, boost from the existing R2.
4. Collision as an event: flash, camera kick, derez particles, trail pulse, slow orbit, then restart.
5. Grinding: riding parallel and close to a trail builds speed and an energy meter; sparks and arcs
   escalate with proximity. A near-miss "edge" meter that drains on contact and recharges.
6. Jump on the existing climb axis: decide and implement one rule (trail gap vs elevated trail);
   implement the elevated trail if it holds up.
7. Finite, decaying trails (fade from the oldest end). One or two trail pickups (Phase, Pulse).
8. One AI opponent using the spatial hash to pick the heading with the most open space.

Keep the physics simple; spend the budget on speed, glow, trail behaviour and collision drama.
Hold 60 fps on the iPhone 12; measure with the HUD. Document the mode in the README, update
`CLAUDE.md` with anything the next thread must know, and commit to the local git repo as you go.

---

Notes for whoever runs this:

- `LowLevelMesh` has not been used in this project yet; probe it with a small `main.swift` script
  first (see the toolchain memory for the multi-file swiftc pattern) before wiring it into the app.
- The corridor's `WorldScroller` assumes the world moves past a fixed vehicle. The arena inverts
  that; do not try to bend the scroller, add a sibling `ArenaWorld` and switch on `GameMode`.
- The user's phone tests use a Backbone. Menu opens settings; keep that.
