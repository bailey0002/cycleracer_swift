# Game direction: from tech prototype to a game (11 Sep 2026)

Written after three worlds proved the visual baseline (Neon City, Sunset Canyon, The Grid with
the parking-garage levels). This is the recommendation and the reasoning; the short version is
in the thread that produced it.

## The question

Pure racer, or a mission-based game with more depth (find items, reach locations, layered
actions and spaces), possibly weaving in the GLB avatars and other assets.

## What the prototype is good at (and what it is not)

- It is an **endless corridor generator** with scripted blocks (curves, fork, tunnel, skyway,
  conduit), not a lap track. Lap racing against a pack needs a closed circuit, opponents on the
  same track, overtaking and a finish line: none of that exists and the scroller architecture
  (world moves past a fixed vehicle) makes pack racing awkward.
- It is a **strong run engine**: speed, boost, altitude, hazards, weapons, a route choice, and
  a look system that can swap a whole world in one rebuild.
- The Grid is a **duel engine**: trails, grinding, pickups, an AI rival, levels.
- Sessions on a phone with a Backbone are short. Two to three minute runs fit; twenty-minute
  races do not.

## Recommendation: a mission runner with a light story, not a pure racer

Keep the driving as the core verb but frame every run as a job. The player is a **courier
program** (or a smuggler, or a rider for hire) in a fractured system. Each world is a district;
each run is a delivery, a search or an escape with a clear goal and a clock. The Grid is where
disputes get settled: a rival wants the cargo, you duel for it.

Why this and not a pure racer:

- It uses what exists. A delivery run is the corridor plus a goal and a score. A search run is
  the corridor plus "take the tunnel branch, find the three beacons". A duel is the arena.
- It gives the worlds a reason to differ. Neon City is the downtown grid, Sunset Canyon is the
  outlands, The Grid is the arena. New districts are new themes (already cheap).
- Story can stay thin and cheap: a hub, a handful of characters, mission text, no cutscene
  pipeline. The avatars carry it.
- Depth comes from layering actions the engine already has (boost, altitude, fire, jump, phase,
  pulse, grind) into mission rules, not from new physics.

## The loop

1. **Hub**: the parking garage from The Grid, reused as a place. The bike sits on the deck,
   avatars stand around (contacts, a mechanic, a rival). Pick a job from a board.
2. **Run** (60 to 150 s): a corridor mission with a goal, or a Grid duel.
3. **Payout**: credits, cargo, reputation. Spend on bike upgrades (boost capacity, edge meter,
   trail length, weapon rate) and on unlocking districts. Small, visible, repeatable.
4. Every few jobs a **story beat**: a contact turns, a rival shows up in the arena, a district
   opens. Told with a line of dialogue and an avatar in the hub, nothing more.

## Mission types that fall out of the existing engine

| Mission | What it reuses | New |
|---|---|---|
| Delivery | corridor run, distance, hits | a timer and a cargo integrity bar (hits damage cargo) |
| Search | fork + branches, tunnel, skyway | beacons to fly through (existing ring/gate geometry), count on the HUD |
| Escape | corridor, drones | a pursuer that gains when you slow; boost windows |
| Salvage | obstacles, weapons | shoot marked crates, collect the drop by flying through it |
| Duel | The Grid | opponent with a name and a face (avatar portrait on the HUD) |
| Heist | The Grid levels | reach the upper deck, grab the item, get down the off-ramp before the rival |
| Conduit dive | the tube section | precision only, no weapons, time trial |

Each is a few dozen lines on top of `TrackProgram` (a mission chooses the block list) plus a
goal object and a HUD line.

## Where the GLB avatars fit

Avatars do not need to ride the bike (the speeder has no rider slot and a sitting rig is real
work). They work as:

- **Hub characters**: standing on the deck, idle animation if rigged, tap or Menu to talk.
- **Contacts on the HUD**: a portrait rendered from the GLB to a texture at launch (the sign
  pipeline already renders textures) next to mission text.
- **Holograms in the world**: the hologram sign shader already exists; a contact's face on a
  gantry billboard in Neon City is free once the portrait exists.
- **Rivals**: a name, a portrait and a trail colour make the Grid opponent a character.
- **The player**: choose an avatar in the hub; it is the face on the HUD and in the hub.

RealityKit loads USDZ, not GLB: the same Blender conversion used for the speeder applies.
Animated GLBs convert with their clips; a static pose is fine to start.

## What I would not do

- A full open world or free roaming between districts: the scroller cannot do it and the
  arena engine would need a real map. Districts as separate runs is the honest structure.
- Deep dialogue trees or cutscenes: expensive, and phone sessions do not want them.
- Pack racing with positions and laps: wrong engine.

## Build order (each step playable)

1. Mission frame: a `Mission` type (world, block list, goal, timer), start and end screens on
   the HUD, a payout. Delivery only.
2. Hub scene from the garage deck: job board, one avatar, upgrade shop with two upgrades.
3. Search and Escape missions. Beacons and a pursuer.
4. Avatar pipeline: GLB to USDZ, a portrait render, contacts on the HUD.
5. Duel and Heist missions on The Grid with a named rival.
6. Story beats: five contacts, one twist, three districts. Text only.

## Open questions for Mark

- What are the GLB avatars: humanoid, rigged, animated, how many, what style?
- Tone: Tron-clean, cyberpunk-grimy, or playful? It decides the writing and the hub dressing.
- Single player only, or is a local rival on a second phone something you want eventually?
