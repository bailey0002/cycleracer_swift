# Research reports, 17 Oct 2026 (R&D deep dive)

Four agents ran in parallel for `assessment-2026-10-17-rd.md`: A the "inside the machine" lineage and arena /
anti-gravity design; B narrative-game devices and cheap depth for a procedural city; C objective, hazard,
rival-ladder and clue catalogues for a sole rider; D an audit of this codebase for where each candidate feature
plugs in and what it costs. Their reports follow, lightly trimmed. Sources are the URLs inline; every plot or rule
detail came from web searches on the day and from wikis and reviews, so treat specifics as "as commonly summarised".

---

## Report A: story lineage, arena combat, anti-gravity runners

### A.1 The "inside the machine" story lineage

**Tron (1982).** Frame: Flynn, a fired ENCOM coder, breaks in to prove Dillinger stole his games; the MCP digitises him by laser into the mainframe. Rules: programs resemble their Users; Sark gives captured programs a choice: renounce the Users and join the MCP, or play games until derezzed. Currency: the identity disc (weapon and memory), energy, and access to the I/O Tower (forbidden; the only link to a User). Villain: the MCP wants to absorb every program and system. Exit: Flynn learns a User has god-like powers inside, rides the solar sailer with Tron and Yori, and sacrifices himself into the MCP's beam so Tron can throw his disc through the gap. Set pieces: the disc duel, the light-cycle break-out, the tank chase, Ram's derez, the solar sailer, the I/O Tower. https://tron.fandom.com/wiki/TRON

**Tron: Legacy (2010).** Frame: a pager message from a shuttered arcade pulls Sam into his father's Grid. Rules: Sam is immediately thrown into the Games (Disc Wars elimination in breakable-tile cells, then a light-cycle grid); striking a program with a disc derezzes it permanently. Villain: Clu, Kevin's copy, who wants to invade the real world through the portal while it is open. Exit: the portal, a timed window; Quorra swaps discs with Kevin so Sam leaves with his father's disc. Set pieces: Disc Wars, the light-cycle grid, the End of Line Club betrayal (Castor / Zuse), Rinzler revealed as Tron, the light-jet dogfight. https://en.wikipedia.org/wiki/Tron:_Legacy

**Tron 2.0 (2003, game).** Alan is kidnapped; the AI Ma3a digitises his son Jet. Jet is accused of being the corruption and sentenced to the light-cycle arena, where winning matches is the way out; permissions, subroutines and build-version numbers are the economy. Villain: Thorne, an executive who digitised himself and became a virus; behind him the fCon takeover. Light cycles are campaign interludes plus a super light cycle unlock. https://tron.fandom.com/wiki/List_of_TRON_2.0_Levels

**Tron: Uprising (2012).** A native program, Beck, a mechanic in occupied Argon City, turns rebel after a friend is derezzed; Tron trains him as the "Renegade". Identity discs hold memory (a stolen disc makes Beck's memory fade); the Coliseum games are punishment; a bounty turns neighbours informant. No exit: a liberation story. https://en.wikipedia.org/wiki/Tron:_Uprising

**Tron: Identity (2023).** A detective program investigates a vault explosion; memory is literal data; a "defrag" mini-game repairs damaged identity discs to recover what witnesses lost. A Tron story can be a conversation-and-choices story with no fighting. https://www.rpgfan.com/review/tron-identity/

**Ready Player One.** Three keys behind three gates built from Halliday's favourite things; gunters hunt, IOI's numbered Sixers are the corporate opposition; the hunt is a scoreboard everyone can see. https://en.wikipedia.org/wiki/Ready_Player_One_(film)

**Wreck-It Ralph.** Die outside your own game and you do not regenerate; "going Turbo" (jumping games) is taboo; King Candy is Turbo in disguise, who rewrote Sugar Rush's code and made Vanellope a glitch; if she crosses a finish line the game resets. https://en.wikipedia.org/wiki/Wreck-It_Ralph

**Jumanji (1995 / 2017).** The game cannot be put down, only finished; 2017: avatars with three lives each, visible on the wrist; levels must be completed in order. https://intofilm.org/films/reviews/867437/print

**Captain N.** The player is the prophesied outsider whose game skills are literal abilities. **Spy Kids 3-D.** Nine lives; beta-testers believe in "The Guy" who can beat unwinnable Level 5; a friend sacrifices her last life. **Sword Art Online.** Clearing all 100 floors frees everyone; death is real; the villain is the top guild's leader, Heathcliff; the finale is a fair one-on-one duel. **The Last Starfighter.** The cabinet is a recruitment test; a "Beta" covers the hero's absence. **Dragon's Lair / Space Ace.** The attract-mode cabinet as a lure is itself a story device.

**Reusable devices for the courier who learns the packets are riders' identities**

1. The disc as memory and weapon (Tron, Uprising, Identity): a rider's packet is literally their disc; deliver it and they keep who they are; it is also what you duel with. Steal it and memory fades over a countdown.
2. The ultimatum from the regime (Sark): the arena is punishment and recruitment at once.
3. The forbidden tower / the one link out (I/O Tower, Legacy's portal timer): a route no program may ride; the finale rides it against a closing window.
4. The outsider whose skill is literal power (Flynn, Captain N, Starfighter): the skater's board tricks do things programs cannot; the villain wants the ability, not the courier.
5. The clock on your own identity (Jumanji's lives, SAO's real death): a visible fragment count that falls when you lose; a rival can wager a fragment.
6. The friendly face who sells you (Castor / Zuse; Heathcliff): the dispatcher who hands out jobs is the broker; reveal through a job that goes wrong.
7. Code rewritten against the rules (Turbo; the Legacy Code): the villain's crime is a rule change ("every program rides a route" became "every route is owned"); winning restores a rule, not kills a boss.
8. The glitch who crosses the line (Vanellope): a rival the system calls broken is restored by finishing one race.
9. Keys and gates with a public scoreboard (RPO): three chapters, three keys; rivals' records visible.
10. Fair duel after a rigged game (SAO, Legacy): the last fight is 1v1, no pads, no help.
11. The cover body left behind (Starfighter's Beta, Jumanji's frozen world): the shop as a bookend; time does not pass out there until the cabinet resets.
12. The sacrificial ally (Ram, Quorra's disc swap): a named rider gives up their disc for you before the duel.

Verdict for a 1–2 minute phone session: deliver the frame in the job card and the debrief line, never a scene longer than a sentence: the disc-as-packet reveal is one changed noun on a job card ("PACKET" becomes "DISC: ORIN"); the broker twist is a job whose pickup is a rival you have beaten; the final duel's stakes are the rival's visible record and your own fragment count.

### A.2 Light-cycle and arena combat design

**Armagetron Advanced.** Trail walls, "rubber" (how long you can grind a wall before dying), speed from riding close to walls; a match is won by a score limit, a round cap, or points at a time limit. Modes: Sumo (shrinking zones), Fortress (two teams each defending a zone), Death Match, Capture the Flag, Race, Team Gauntlet, Wild Fortress; rubber flavours (No / Low / High) as distinct sub-games; AI IQ grades. https://wiki.armagetronad.org/index.php/PlayingGettingStarted

**GLtron.** Speed styles Booster (button turbo), Wall ride (speed grows with proximity to an opponent's wall), or both; arena sizes tiny to vast; bots in tiers. https://en.wikipedia.org/wiki/GLtron

**Tron (arcade, 1982).** Four sub-games per level, next chosen at random; twelve difficulty tiers named after programming languages (BASIC … USER). **Discs of Tron.** 1v1 vs Sark on ring platforms; the boss has weapons the player lacks. **Tron 2.0 mobile.** Five arenas and a tournament of progressively harder opponents with power-ups. **Tron: Evolution.** Reviewers found the chase camera made trail mazes unreadable. **Tron RUN/r.** Disc (runner), Cycle (timed race, gates add seconds), Stream (endless); three stars per level from total score with thresholds on an in-level bar. **Kingdom Hearts II.** A 90-second cycle minigame as a story gate. **Tron: Legacy's Games.** Bracket elimination with a reigning champion unbeatable until the hero cheats the format.

Devices: round formats (Sumo, Fortress, Race, Deathmatch, Zones, Void); rubber as a knob per rival or round; wall-ride speed as an AI personality axis; arena size as difficulty; breakable tiles; each named rival gets one unfair tool; a named difficulty ladder on the result card; round points toward a match limit; the arena as sentence; a bracket with a reigning champion.

Verdict: one round is 20–40 s; a best-of-three with a format drawn from three or four fits 1–2 minutes, like the arcade's random next-game pick. Progression should be labels and one unlocked tool per chapter, not new arenas.

### A.3 Anti-gravity racing and run games with a story frame

**Wipeout 2048 / Omega.** Career across seasons in one hub; Race, Combat, Time Trial, Speed Lap, Zone; pass vs Elite Pass; HD Fury's Zone Battle, Eliminator, Detonator. **F-Zero GX story.** Nine chapters, each one bespoke rule set (capsule collection in a time limit, a canyon duel, a bomb-on-board chase); each chapter's rule is the story beat. **F-Zero 99.** Collisions release Super Sparks that fill a meter opening the Skyway; a rising minimum safe rank eliminates stragglers. **Redout.** Eleven event types including Last Man Standing and Boss (five tracks joined by teleporters). **Distance.** Point-to-point survival; abilities drip-fed; car-splitting lasers and collapsing roads; story by environment and glitch text. **Thumper.** Bosses are learned patterns; C/B/A/S ranks; checkpoints preserve score. **Alto's Odyssey.** ~180 goals in sets of three that unlock items; one-button trick grammar; Zen Mode. **Subway Surfers.** Five power-ups upgradable in six steps; hoverboard as a one-crash shield. **Hover.** Every mission a variation of two features: a warning. **Jet Set Radio / Bomb Rush Cyberfunk.** One crew per district; beat them and the turf is yours; REP unlocks the crew battle; police escalate. **Rollerdrome.** Tricks reload ammo; kills heal; trick value decays with repetition; ten challenges per match gate the next tier; story from notes in waiting rooms.

Verdict: one job = one GX-style bespoke rule plus Alto's three goals; tricks should feed something (boost or hull, as Rollerdrome feeds ammo) with repeat decay; districts should flip colour when a rival is beaten. Avoid Hover's trap: cap job kinds at five and vary them by rule, not by map.

---

## Report B: narrative devices and cheap depth

Cost tags: S a day or two of data + SwiftUI; M a week, some new systems or art; L multi-week.

### B.1 Narrative adventures: world, goals, guidance

- **Thimbleweed Park / Monkey Island.** Per-character to-do list (the inbox made explicit: open jobs, cleared jobs, what people asked for; S). Hint line as diegetic help, state-aware, filters spoilers (a dispatcher channel on pause; S). Gilbert's rules: clear goals and sub-goals, puzzles advance the story, no cheap deaths; the Three Trials shape (one headline goal, three parallel sub-goals on a map; S). https://www.hardcoregaming101.net/thimbleweed-park/ https://www.filfre.net/2017/03/monkey-island-or-how-ron-gilbert-made-an-adventure-game-that-didnt-suck
- **Night in the Woods.** The daily loop as structure; the town is the protagonist. Devices: "who's out today" (two or three rotating NPC chips per hub visit), a message log that grows by day, extras who comment on your last job (M; S text-only). https://www.dualshockers.com/night-in-the-woods-review/
- **Oxenfree.** Walk-and-talk, silence is a valid answer. Port: in-run comms with a two-option reply on D-pad during straights, no reply its own branch (M). https://en.wikipedia.org/wiki/Oxenfree
- **Kentucky Route Zero.** The delivery as the whole plot: one parcel deferred by every act, each stop adds a passenger; interludes in a different format (S each). https://en.wikipedia.org/wiki/Kentucky_Route_Zero
- **A Short Hike.** One soft summit, many optional goals; feathers from favours as well as climbing (S).
- **Untitled Goose Game.** The to-do list is the design document shown to the player; specific verbs each implying a character ("make KADE eat a wall"; S).
- **Hades.** The hub speaks to what you just did: a line pool with conditions and a priority / cooldown (M selector, S per line); portrait + name + one line is the whole presentation; keepsakes as a relationship counter (S). https://gdcvault.com/play/1026975/Breathing-Life-into-Greek-Myth
- **Hypnospace Outlaw.** The world is documents: route boards, notices, rival fan pages as sign textures readable later (M). https://mcvuk.com/?p=210624
- **Return of the Obra Dinn.** The book is the structure: a roster page that fills in as you learn programs' names, routes and fates (S). https://emshort.blog/2019/06/06/return-of-the-obra-dinn-lucas-pope/
- **Disco Elysium.** Thought cabinet: internalise a line from a rival into a routine with a small handling effect (M).
- **Citizen Sleeper.** A station of clerks and clocks; visible clocks on the briefing ("SABLE's job expires in 2 runs"), drives as a filling ring per chapter (S); faction lean (M). https://www.rascal.news/tracing-citizen-sleepers-circuitous-vector-from-tabletop-to-hit-video-game/

### B.2 Courier games and the job board

- **Death Stranding.** Orders at hubs; Likes as a non-spendable second score with the recipient's one-liner; standard vs premium order of the same delivery (S). https://gameinformer.com/2019/09/16/likes-in-death-stranding-are-unconditional-love-not-currency
- **Cloudpunk.** The talking vehicle (the dog AI) as the cheapest companion; the dispatcher as a second voice with a register; the parcel has a story (a line on pickup, a line on delivery, occasionally a choice; S). https://blog.playstation.com/archive/2020/02/13/explore-a-sci-fi-metropolis-as-a-delivery-driver-working-the-nightshift-in-cloudpunk
- **Neo Cab.** Choosing which fare to accept on a map is the branching; the unchosen client's attitude shifts (S).
- **Lake.** A calendar as chapter clock; the same addresses revisited until a recipient is a character (S).
- **Paradise Killer.** An empty world justified in fiction and a cast of ~12 named characters instead of a crowd (S). https://gamesradar.com/the-making-of-paradise-killer
- **Sayonara Wild Hearts.** One card per rival / chapter, a narrator in two sentences, levels timed to the song (S / M). https://www.simogo.com/sayonara-wild-hearts/
- **Sable.** Badges from three trades unlock a mask; choosing which mask to wear is the ending (S–M). https://news.xbox.com/en-us/2021/09/23/sable-the-inspiration-behind-the-game-and-how-to-get-started/

End states that fit a job runner: Sable's chosen mask, Lake's stay or go, Cloudpunk's deliver or don't, KRZ's arrival at the address: one choice at the end of a chain, foreshadowed by small ones.

### B.3 Cheap depth for a procedural neon city

Posters and billboards that carry story, progress-gated per chapter (S–M; Cyberpunk shards, Hypnospace). A named radio / dispatcher voice with chapter idents and a reply option (S; JSR's Professor K, Firewatch's walkie-talkie). Weather and time of day named on the chapter card, the title reflecting the chapter's sky (S). One hero landmark per chapter visible from the skyline strip (M; Mirror's Edge Catalyst's district colour). Extras with a reason (M; Paradise Killer): parked cycles that light as you pass, drones that follow for 3 s, a sign that reads your callsign. A hub with a shopkeeper as one screen with 3–4 portrait chips and one new line per return (S–M). Collectible route tags on alternate branches unlocking roster pages (S; JSR Graffiti Souls). Wordless murals as emissive glyph panels at section mouths and ghost replays of a rival's past run (M; Hyper Light Drifter). Zones named on a card with three goals each (S; Tetris Effect, Alto). Photo mode with a callsign stamp (M). A district diagram, not geography (S–M). Interludes as a static panel plus 3–5 lines from the shop owner (S).

Recommended first batch (all S): per-client trust on the result card with a one-liner; chapter clocks and drives on the briefing; Goose-style specific to-do entries per chapter; one story billboard set per chapter; a board AI voice; a roster page that fills in.

---

## Report C: objectives, hazards, rival ladders, clue beats

### C.1 Objective shapes (36)

Type: R run goal, P persistent, C collectible, X competitive.

| # | Shape | Needs | Type | Lineage |
|---|---|---|---|---|
| 1 | Hit score tier (3 thresholds) in one run | counter, clock | R | THPS High / Pro / Sick |
| 2 | Single combo over N | combo timer | R | THPS |
| 3 | Spell a word from placed letters | 5 markers | R/C | S-K-A-T-E |
| 4 | Collect N themed items on hard lines | counter + markers | R/C | hall passes, Sonic rings |
| 5 | Secret tape: one item at the hardest reachable spot | marker + altitude | C | THPS |
| 6 | Named gap: cross between two volumes airborne | 2 trigger volumes | P/C | THPS gaps |
| 7 | Grind / ride N specific objects | tagged surfaces | R | THPS |
| 8 | Do trick T over object O | trick event + volume | R | Skate 3 Photo / Film |
| 9 | Own the Spot: score S inside one zone | zone + counter | P | Skate 3 |
| 10 | Hall of Meat: crash for points | ragdoll scoring | R | Skate 3 |
| 11 | Deliver A to B before the clock | clock, carry flag | R | Crazy Taxi, THUG |
| 12 | Chain deliveries, each adding time | clock + queue | R | Crazy Taxi |
| 13 | Checkpoint time trial, stars at 3 times | ordered volumes | R | Mirror's Edge |
| 14 | Beat your own ghost | replay record | X | Mirror's Edge, Trackmania |
| 15 | Beat an NPC's posted score | stored threshold | P | OlliOlli locals |
| 16 | Take the Gnarly Route and finish | branch flag | R | OlliOlli |
| 17 | No-X run (no boost, no checkpoint) | input flags | R | OlliOlli |
| 18 | High-five / pass-by an NPC marker | trigger volume | R | OlliOlli |
| 19 | Tag N spots to raise REP in a district | markers + counter | P | JSR, BRC |
| 20 | Escape heat; shed it at a hideout | pursuer, meter, safe zone | R | JSR, BRC |
| 21 | Tag the pursuer to stun him | hit volume | R | JSR Onishima |
| 22 | Crew battle: your 3 tricks vs theirs | AI score sequence | X | BRC |
| 23 | Collect every floating point on a line | many markers | R | Sunset Overdrive |
| 24 | Smash N objects | counter | R | Sunset Overdrive |
| 25 | Shoot N floating mines while gliding | targets + weapon | R | Sunset Overdrive |
| 26 | Hold a point against waves | spawner + timer | R | Sunset Overdrive |
| 27 | Long jump past distance D | ramp + meter | R | Crazy Jump |
| 28 | Pop N balloons in 45 s | targets + clock | R | Crazy Balloons |
| 29 | Drift / trick combo points over N | combo meter | R | Crazy Drift |
| 30 | Three goals per level, persistent | per-goal counters | P | Alto |
| 31 | Daily world / daily trio | seed + reset | P/X | Race the Sun, Subway Surfers |
| 32 | Hidden warp ring to a bonus stage | hidden marker | C | Sonic |
| 33 | Lore set unlocking a cosmetic | fixed collectibles | C | Spider-Man |
| 34 | Landmark photo: frame it right | camera volume | C | Spider-Man |
| 35 | Kill enemy E with weapon W from position P | enemy + weapon + volume | R | Rollerdrome |
| 36 | Time-clear a combat stage | clock + enemies | R | Rollerdrome |

Pick five for a 1–2 minute controller job: #3 letters placed on the climb / boost lines, #13 checkpoint stars with #14 ghost on retry, #8 trick-over-object ("barrel roll the overpass"), #20 escape with a hideout exit, #30 Alto-style persistent trio.

### C.2 Hazards and course tools (28)

| # | Hazard / tool | Tests | Telegraph |
|---|---|---|---|
| 1 | Low gate (stay low) | altitude, timing | lower bar red |
| 2 | High gate (climb over) | altitude | floor-level glow strip |
| 3 | Lane gate (one open slot) | lane choice | open slot lit |
| 4 | Sweeping laser | timing | emitter charge pulse, beam trace |
| 5 | Laser grid (fixed pattern) | memory | pattern on a billboard a block ahead |
| 6 | Phase wall (solid on the beat) | rhythm | pulses to the music bar |
| 7 | Breakable barrier | aim, risk | cracked texture |
| 8 | Avoid-vs-destroy pair (colour decides) | recognition | role palette |
| 9 | Collapsing span | commitment | flicker + dust |
| 10 | Gravity flip / ceiling run | orientation | arrows on the conduit wall |
| 11 | Buzz saw on a rail | lane timing | sparks + whine |
| 12 | Drone that strafes | aim or dodge | reticle on you |
| 13 | Searchlight cone (raises heat) | stealth routing | visible cone, siren |
| 14 | Proximity mine | spacing | blink rate |
| 15 | Shadow zone (power drains) | route | darker floor |
| 16 | Dark section with trigger lights | memory, aim | shooting a node lights 50 m |
| 17 | Speed pad chain | lane precision | chevrons |
| 18 | Weapon / charge pad | pickup choice | colour by role |
| 19 | Time gate (+N s) | routing | hologram clock ring |
| 20 | Checkpoint ring (restores hull) | pacing | portal frame |
| 21 | Jump ramp with gap | speed | void below |
| 22 | Spring mark | timing | floor glyph |
| 23 | Zip-line / grind rail | balance | rail lit |
| 24 | Narrowing conduit (3 lanes to 1) | precision | wall lights converge |
| 25 | Turn bank (Thumper red turn) | hold + steer | red arc |
| 26 | Boss pattern wall | pattern reading | core exposes on cycle |
| 27 | Grey-block field (clean pass bonus) | restraint | dull grey |
| 28 | Barrel-roll boost (roll costs hull, pays speed) | risk | HUD prompt on air |

Pick five: #4 sweeping laser, #3 lane gate, #6 phase wall on the music bar, #28 the barrel-roll bargain, #19 / #20 time gates and checkpoints.

### C.3 Competitive formats with a CPU cast

Ghost tiers (Trackmania's bronze / silver / gold / author ghosts; Mario Kart staff ghosts; Mirror's Edge racing your own ghost). Rival of the race (F-Zero 99 assigns rivals per race; Star Rivals pay a one-time badge). Takedowns and Shutdown rivals that spawn in free roam after N wins; take them down to claim the car (Burnout Paradise). The Blacklist (NFS Most Wanted: each rival behind races plus bounty milestones; beating them unlocks their car). Canyon duels (NFS Carbon: chase for proximity points, then be chased; crews with roles). Armagetron Fortress and Sumo, every variable tunable. Rocket League Sideswipe ranks. Furi's one phase per life square; Hades' Pact of Punishment summing modifiers into Heat with a bounty for a higher Heat.

How to turn 4–6 named riders into a ladder: Blacklist ordering with gating jobs per rival, winning takes their livery; rival-of-the-job posted time with a taunt; ghost tiers per job as the cast's recorded times; Pact-style Heat on rematches for a bigger purse; phase duels (three rounds with distinct rule sets).

Reusing one arena for 10+ matches: rule sets (last rider standing, Sumo, Fortress hold-a-pad, first to 3 cuts, survive 60 s against a 2× rival, tag the tail, score attack on pads with the rival blocking, breach race to the deck, no-boost, snap-turn only); mutators (trails decay fast or never, dark arena with your trail the only light, ramps removed, phase walls on the beat, mirrored controls, one life); handicaps (longer rival trail, half hull, Furi-style life squares on first attempts); stakes (lose your colour until the rematch, win their trail colour, a "Marked" flag that spawns them as a pursuer in the next three jobs).

Pick five: Blacklist order with two gating jobs per rival; rival-of-the-job posted time; Sumo and Fortress as the two duel rule sets; Heat mutators for rematches paying the trail colour; losing your colour as the stake.

### C.4 Clue and people beats in a corridor you cannot stop in

Principles from Thimbleweed, Night in the Woods, Paradise Killer, Obra Dinn, GTA V Strangers & Freaks, Yakuza substories: a visible checklist the player owns; a bounded, verifiable answer set; evidence as an any-order collectible; a chapter window that makes a lead missable; choosing one informant per night.

| Beat | Corridor mechanism | Need |
|---|---|---|
| Find the clerk | the kiosk is one branch of the fork; a pass-by press of A in the window logs the testimony | branch flag, storefront quad, trigger volume |
| Spot the clue | hologram billboards show the clue for 3 s; shoot the right one | billboard pool, hit test |
| Interview over comms | the witness talks on comms; the question is a two-option prompt at the next gate (left lane asks about the route, right about KADE) | lane choice as dialogue, message log |
| Side door branch stubs | doors glow when a lead is live; steering in is a 5 s stub then a portal rejoin | sub-segment, portal frame |
| Kiosk stop | a time gate adds +N s and the board idles 3 s at a counter | pause-in-run state, HUD card |
| Missable window | the informant only appears in a chapter-3 heavy-rain job | job flags, rain mode |
| Evidence as collectible | fragments across jobs assemble a route in the ledger | markers, persistent counter |
| One informant per night | two amber offers, only one takeable before the chapter card | mutual lock on SideOffer |
| Verify the answer | three fragments (who, where, when) must match before the accusation duel unlocks | three persisted enums |
| Escape after the tip | talking to the clerk raises heat; the back half is the pursuer | pursuer, safe volume |

Pick five: fork branch to the clerk with a one-button pass-by; billboard clue to shoot; lane-as-dialogue at a gate; mutually exclusive side offers; three-fragment verification gating the accusation duel.

Caveats: Tron 2.0's single-player arena rules, Temple Run 2's full objective list and Sunset Overdrive's traversal details were thin in the sources.

---

## Report D: code audit, where each feature plugs in

Base path `SpeederProto/Sources/`.

### D.0 The three extension points today

**Mission kinds.** `Mission.Kind` has six cases; no JSON anywhere, every table is a Swift literal. A new kind touches: `Mission.swift` (the enum and the exhaustive switches `goalText`, `successTitle`, `kindText`, the midway comms branch, `weaponsAllowed` / `hullFactor`, `maxScore`, a row in `deliveries`); `MissionRunner.update` (fail checks at ~600–608, the payout switch at ~615) and `MissionState` / `snapshot()`; `HUDView` (`objectiveLine`, run-card lines, result stats, briefing row); `GameController.build` (props: `BeaconLayer` for search, `PursuerActor` for escape, in `MissionProps.swift`) and the per-frame feed. A kind that reuses existing props is S, one needing a new prop class is M.

**Screens.** `Screen` has ten cases on a stack with `push / pop / setRoot`; `menuRows` returns rows per screen; `activate(id)` handles ids; `initialScreens()` maps `SPEEDER_SCREEN`. `FrontEndView` renders rows generically with bespoke branches for `.story`, `.messages` and the roster card. A list screen is S; a non-list screen (a map, a hub) follows the `StoryIntroView` pattern with its own view driven by `frontEndInput` (M).

**Arena rules.** `matchTarget` is the only runtime knob; the zone (`zoneCenter`, 70 → 16 m, `zoneAt` 25 s from env), grind constants, `trailMaxLength` from `FXSettings.trailLength`, pads as a literal layout in `ArenaWorld.buildPads`, hazards as strands re-registered every round, terrain `ArenaTerrain.garage`, speeds as `var`s on `LightCycle`. The controller is hard-wired to one opponent (singular `opponent`, `ai`, two-element arrays, a `dissolve` tuple) in about forty places; `TrailSystem.addTrail` is N-ary already.

### D.A Story and world

| # | Feature | Touches | Reuses | Needs | Cost | Risk |
|---|---|---|---|---|---|---|
| 1 | Narrative JSON | `Mission.swift` lines, `Debrief.swift`, `MessageLog` chapter text, `Rival.Temper.line`, `project.yml` | the `Bundle.main.url` loading in `ArtLibrary` / `Soundtrack`; the `(contact, key)` switch shape maps to a dictionary | a `Codable` schema (first in repo), a loader with the Swift tables as fallback, interpolation for `\(o.hits)` and the `[wins % 3]` rotations | M | the tests load `Mission.deliveries` directly: keep the Swift catalogue, move lines first; `xcodegen generate` after adding the file |
| 2 | District map screen | `FrontEnd` Screen + rows + `activate` + `initialScreens`; `FrontEndView` bespoke branch; the briefing footer | `JobEntry` from `snapshot()`, `Theme`, `Rival.portrait`, `chapterTitle` | a map image or vector per world, pin coordinates on `Mission`, a `MapView` driven by `frontEndInput` | M | the briefing is HUDView, so opening from it is a `screens.push` from `briefingInput`; HUD panels must scroll at 390 pt |
| 3 | Kiosk beats | `TrackBlock.Dressing`, `TrackComposer.Phrase`, `RoadSegment` dressing groups, comms triggers, `AvatarActor`, `SideOffer` | the crossroad dressing + hidden-set pattern, `hologramSigns`, the contact avatar, `CommsTrigger` | a `.kiosk` dressing with a pass-by window, a clue chip, a branch stub | L for a stop, S for a pass-by with a line | stopping mid-run fights the scroll model; zero-thickness quads on repositioned entities never draw; nothing survives at x = 0 / ± 11.5 in a fork segment |
| 4 | Collectible lore shards | a `ShardLayer` after `BeaconLayer`, `GameController.build` + feed, `MissionRunner` counters, `SaveSlot.prefixes`, HUD counter | `BeaconLayer` is exactly this; the `Flags` bitmask persistence | a `shards.<job>` key, a HUD stat, a briefing row | S | add the prefix to `SaveSlot` or the save drops it; copy BeaconLayer's mesh choice |
| 5 | Theme per chapter | `Theme` (an enum, every property a switch), `Mission.theme`, `rainMode` (already chapter ≥ 3 heavy), `MaterialFactory`, `WorldScroller.configure` | the chapter-3 rain rule; `FXSettings.environment` rebuilds on change | new cases (`neonCityDusk`…) or a `(world, variant)` split | M (cases) / L (refactor) | many `== .neonCity` comparisons need a `.world` accessor; weather resets in `build()`; fog near scene luminance vanishes |
| 6 | Hub screen | card: a Screen + bespoke view, stills / clips, story panels. Scene: a fourth `GameController.build` branch, `GameMode.hub`, `AvatarActor`, rider USDZs | the roster card, `LoopingClipView`, the briefing avatar | card: layout only; scene: a static set, idle poses, a camera, a rebuild path | S–M card / L scene | the scene costs load time (a 32 MB rider); the GDD lists the hub as a decision |

### D.B Objectives and rewards

| # | Feature | Touches | Reuses | Needs | Cost | Risk |
|---|---|---|---|---|---|---|
| 7a | Trick-score run | kind sites; `startTrick / trickLandedNow`; the obstacle loop for a near-miss test | the streak score, `ActionAck.trick` | `trickValue`, a near-miss event, `Kind.trick`; board-only | M | the speeder has no tricks, so the kind forces the hoverboard |
| 7b | Tag the district | kind sites; `BeaconLayer` any-order | search is 90 % of it | markers spread laterally, a loose window | S | low |
| 7c | Time trial + ghost | kind sites; a 60 Hz `(t, x, altitude)` recording, a `GhostActor`, a `best.<id>` key, a file in Application Support | the fixed 60 Hz step guarantees determinism; `SpeederController.tint` | recording, storage, the ghost actor placed at `(ghostDistance − playerDistance)` via `world.offset(atWorldZ:)` | M–L | the fork branch must be recorded |
| 7d | Heat escape | the escape block, `PursuerActor.update(gap:)`, `startGap` | escape is the base | a heat scalar raising pursuer speed per hit, a HUD bar | S | balance via the headless loop |
| 7e | Photo / spot | `saveScreenshot`, `PostProcessor.captureRequest`, `FrameCapture`, `screenshotRequested` | the capture path works in-game | a target volume, a framed test via `arView.project`, Photos save on iOS | M | Photos permission is new surface |
| 8 | Per-world goal cards | `MissionRunner` (a `goals.<world>` bitmask), result card `StagedCard`, briefing, a GARAGE-style notice, `SaveSlot` | `Flags`, `award()`, the once-only `offer.<id>.done` pattern, `JobEntry` chips | a `Goal` table with predicates on `MissionState`, a card view | M | arena goals need `MatchResult` routed through `GameController` |
| 9 | Best table + ghost | `succeed` (beside `rank.<id>`), `best.time / best.score`, briefing BEST row, `SaveSlot` | `bestRank`, the NEW BEST stamp | two keys per job; the ghost as 7c | S table / M–L ghost | |
| 10 | Reputation / standing | `rep.<contact>`, `SideOffer.requires` (now `(job, flag)`), `isOfferShown`, `Standing`, chapter card, `Debrief.reactive` | `said.*`, `record.*`, the `Standing` enum | a requirement enum (`.flag` / `.rep(contact, min)`), rep deltas, more offer rows | S–M | the unlock tests need rows |

### D.C The Grid

| # | Feature | Touches | Reuses | Needs | Cost | Risk |
|---|---|---|---|---|---|---|
| 11a | Rule variants (sumo-only, no-boost, trail length, deck-only, mirror) | `zoneAt` → var, `updateZone`, `trailMaxLength`, the boost gate in `stepCycle`, `startRound` spawn points, `ArenaAI.zone`, the HUD arena label | the `matchTarget` precedent, the `FXSettings` bits, the zone constants | a `MatchRules` struct replacing the statics, set per match where `matchTarget` is set | M | deck-only needs `height(below:)` spawn care and AI ramp logic; never raise the AI's 54 m/s cap |
| 11b | Team of two | the whole controller (singular opponent in ~40 places), `GameController.build` (one rival vehicle), `rivalBeam`, the score line | `TrailSystem` is N-owner; `ArenaAI(cycleID:)` is per cycle | a `[Combatant]` refactor, team scoring, an ally temper, 3 more vehicle loads | L | the biggest refactor on the list |
| 11c | Tournament ladder with stakes | `MissionRunner` (a ladder chain), `freePlayRoster` rotation, `MatchResult.credits`, `record.<rival>` | the duel kind, `recordMatch`, the match card | a `Ladder` struct, a bracket card, stake deduction before `startRound` | M | low |
| 12 | Arena mutators as data | `buildPads` (literal), `ArenaTerrain.garage`, `registerHazards`, the zone statics, `ArenaAI.pads / ramps` | pads and hazards rebuild per round; `SPEEDER_ARENA_ZONE_AT` shows the knob shape | an `ArenaLayout` struct consumed by `ArenaWorld.init` and `startRound`; pads re-placed not rebuilt | M | `ai.pads` must refresh; static strands re-register each round (already) |
| 13 | Crowd strip + commentator | `ArenaWorld` (a ring above the 16 m wall), an animated `CustomMaterial`, `Soundtrack.announce / announcePool`, `Debrief.rivalLine` shape | the announcer's cooldown / priority / chance is a commentator; `ArenaController.Events` is the bus | a commentary table keyed by `Events`, a crowd texture, an emissive animated material | M (strip S, lines S) | per-frame `CustomMaterial` values must be re-assigned each frame |

### D.D Graphics and UI

| # | Feature | Touches | Reuses | Needs | Cost | Risk |
|---|---|---|---|---|---|---|
| 14 | Story posters per chapter | `ProceduralTextures.billboard` + `signTexts`, the `MaterialFactory` sign pool, `RoadSegment.recycle` | the whole sign pipeline; `Art.images("neon-sign")` joins it | a chapter parameter into `SceneMaterials(device:theme:)`, a story text list per chapter, optionally Mark's PNGs | S | texture build is a pixel loop at launch; emissive texture + colour adds, pass `.black` |
| 15 | District landmarks every N blocks | `Phrase.landmark`, `Dressing`, `buildLandmarks` + the hidden-set pattern, `MaterialFactory` | overpass / gateway / crossroad are this at small scale | a `.monument` dressing with an authored USDZ or a big procedural prop; a composer rule per world | M | the fork exclusion zone; far props must be thin boxes |
| 16 | Reactive NPC extras | `RoadSegment.drones` (animate), `ObstacleKind`, `PursuerActor`, `SkylineLayer` | drones animate per segment; the pursuer is a lateral-tracking actor | a `TrafficLayer` of passing riders at `speed ± delta`, a swerve rule | M | entity count on the phone; batching (A6) is not built |
| 17 | Rule cards + cue lane | `allowsMotion / isParked` already hold the world; `StagedCard`; the "coming up" chip and `commsSlots` as a cue-lane prototype; `SaveSlot`; `MissionState` | the chapter card is a once-the-world-waits card; `updateComms` is a 3-slot lane | a `Guidance` table (trigger → card), a once-bitmask, a cue queue with priority | S–M | demo mode's pulsed accept must dismiss cards; the HUD VStack clips at 390 pt |
| 18 | Photo mode / postcard | `saveScreenshot`, `captureRequest`, `FrameCapture`, `CameraRig.side*`, the pause rows, the result card | pose cameras exist; the Metal frame is a `CGImage` | a PHOTO pause row that hides the HUD, orbit input, a CoreGraphics postcard composite, Photos save | M | the HUD is SwiftUI and not in the captured texture (a plus: clean plates) |
| 19 | CC5 portraits | `ProceduralTextures.portrait`, `Rival.portrait(for:)` (the single seam), `HUDView.portrait`, `ArtLibrary.image` | `Art.image` falls back to procedural when a PNG is missing | `Resources/Art/portrait_<name>.png` from CC5, a lookup with the glyph as fallback | S | none technical; the faces are D4 (Mark) |

### D.E Cross-cutting

- Persistence: every new progress key must be added to `SaveSlot.exactKeys / prefixes` or the manual save silently omits it and the fresh-start clear leaves it behind (items 4, 8, 9, 10, 17).
- Tests: `MissionLoopTests` constructs `MissionRunner(missions:defaults:)` and plays `Mission.deliveries`; items 1, 7, 8, 10 should land with a test each, and item 1 must keep the Swift catalogue compiling.
- Rebuild path: anything that changes the world (5, 6-scene, 12, 15) goes through `requestRebuild()`; `SceneMaterials` is built once per `build()` with only `theme` as input, so chapter- or match-dependent materials (5, 14) need a second parameter.
- Capture verification: corridor props with `capture.sh` and `SPEEDER_CAMERA=overview`; HUD cards only in simulator sheets; arena variants with `SPEEDER_ARENA_CAMERA=overview`, one run at a time.
- Ordering by leverage: 19 (seam exists), 14 (pipeline exists), 4 and 9 (copy BeaconLayer / the rank key), 11a and 12 together as one `MatchRules + ArenaLayout` refactor. The two genuine L items are 11b (team play) and 3 (a real mid-run stop).
