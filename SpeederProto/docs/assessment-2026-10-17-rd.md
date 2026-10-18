# R&D assessment: a deeper world, story and play for KERB: GALACTIC (17 Oct 2026)

Research and design pass, no code changed. Baseline: `GDD_2026-10-17.md` (the state of the game, read from the code
the same day) and its map `docs/gdd-map.html`. Companions: `assessment-2026-09-27-story.md` (the spine), `game-direction.md`
(why a mission runner), `arena-next.md` (the Grid's open proposals), and the sibling's depth pass
`../kerb_skate_game/RESEARCH_STORY_2026-10-17.md`, which this document mirrors in method and borrows from in substance.
The four research reports this draws on are in `research-2026-10-17-reports.md` (A lineage and arena design, B
narrative devices, C objective / hazard / rival / clue catalogues, D the code audit). The brief: settle the world,
state, goals, heroes and villains; deepen gameplay and flow (objectives, rewards, actions, hazards, AI); and give the
graphics, UI and cards cohesion, on the existing architecture, with KERB Skate's work ported where it fits.

## 0. Verdict in ten lines

1. **The spine holds; the world is under-named.** Routes as identity, VESS the broker, SABLE the buyer, the last line of
   the ledger being yours: that is the Tron lineage's best device (the disc as memory and weapon) already in place. What
   is missing is the two props and one taboo every Tron story runs on: name the packet a **disc**, name the forbidden
   way out (**the I/O Line**), and name the rule that was broken (**"every program rides a route" became "every route is
   owned"**). Three nouns, one afternoon, and every existing line lands harder (§2).
2. **KERB Skate's four systems port as-is.** Guidance (rule cards + a cue lane), the Notebook (per-chapter to-do lines
   with a hint ladder), the GoalCard (nine persistent goals per world) and Barks (named-voice lines from JSON) are
   1,000 lines in the sibling, data-shaped, and this game has the seams for all four (§3, §7). They are the biggest
   depth-per-day on the list and they fix the two things KERB's user rule demanded: cards that explain in plain words,
   and cues during play.
3. **The sibling's cast is this game's cast.** The four riders, Griptap & Co's owner and the red-singlet braggart the
   cabinet swallowed ("the Donny") are shared canon. Here the Donny is the first route SABLE ever bought: his gold
   board is the arena's reigning ghost and the end-of-arc livery. One ghost script and a name (§2.3).
4. **Objectives: five new shapes, not twenty.** Letters on the climb line, checkpoint stars with a ghost, trick-over-
   object on the board, heat escape with a hideout, and a persistent goal trio per world. All five reuse `BeaconLayer`,
   `PursuerActor` and the streak score (§4.1). Hover's lesson from report A: vary jobs by rule, not by map.
5. **The Grid becomes a ladder.** A `MatchRules` struct (sumo-only, no-boost, trail length, deck-only, first-to-N) and an
   `ArenaLayout` struct (pads, hazards, zone timing) turn one arena into ten matches; the four rivals become a Blacklist
   with two gating jobs each, a posted time on every corridor job, a stake (your livery until the rematch) and Heat
   mutators on rematches (§4.3). Team play is the one L item and stays off the list.
6. **Clues and people fit a corridor you cannot stop in.** Four beats cost S each: a fork branch to a clerk's storefront
   with a one-button pass-by, a billboard clue you shoot, lane-as-dialogue at a gate, and mutually exclusive side
   offers. A true mid-run stop is L and is not needed (§4.4).
7. **Graphics: a colour script per chapter, posters that carry story, one landmark per district.** `Theme` grows
   variants (dusk, storm, blackout), the sign pipeline takes a chapter parameter, the composer places a monument every
   N blocks. The crowd strip and commentator give the Grid an audience through the announcer system that exists (§5).
8. **The economy stays; the rewards that carry story are added.** Credits and the garage are balanced (GDD §8.5). Add
   per-contact trust shown on the result card, a roster / ledger page that fills in, route tags on alternate branches,
   chapter clocks on the briefing, and the ending choice (which rival's colour you ride out in). None is a currency (§4.5).
9. **Architecture: one narrative file, two arena structs, one dressing, one layer.** `narrative.json` for every line,
   `MatchRules` + `ArenaLayout`, a `.kiosk` dressing, a `ShardLayer` cloned from `BeaconLayer`. Every new progress key
   goes into `SaveSlot` or the save drops it; every new kind gets a headless test (§7).
10. **Build order:** the three nouns and the narrative file → Guidance + Notebook + GoalCard + Barks ported → the five
    objective shapes and four clue beats → the Grid ladder (`MatchRules`, `ArenaLayout`, stakes) → the colour script,
    posters, landmarks, crowd → the ending, the roster page, photo mode → daily job and classes. Seven steps, each
    playable and capture-provable, run as five workstreams with one integration pass per step (§8, §9).

## 1. Where the game stands (from the GDD, 17 Oct 2026)

| Layer | Built | Gap against the brief |
|---|---|---|
| Story frame | Griptap & Co opening (10 beats, Mark's four panels), three chapters, 18 briefs and debriefs, reactive lines per contact, comms, chapter cards, the message log, the unseen sender, side offers, an ending title | The world has no proper nouns beyond VESS / KADE / ORIN / SABLE and three district names; the shop owner never speaks after the opening; the riders have no lines; the Donny is not here |
| Objectives | Six kinds (delivery, search, escape, salvage, dive, duel), streak score, ranks, flags, three side offers | No persistent goals per world, no collectibles, no clue or people beats, nothing to find off the line, free play has no goal |
| Rewards | Credits, a 9,800 garage, ranks, flags, titles, records | No reward that is a story object; no trust per contact; no ending choice |
| The Grid | Light cycle on Armagetron's curve, trails, grind, edge, jump, pads, pickups, sumo zone, rounds, four rivals with tempers and skills, records and taunts | One rule set, one layout, no ladder, no stakes, no crowd, one opponent hard-wired |
| World | Three themes, composed tracks, Mark's art in the city and the Grid, landmark dressings | One look per world (not per chapter), no story on the signs, no monuments, no extras that react |
| Guidance / HUD | The OBJECTIVES block, a controls hint, comms, stamps, pips | No rule cards, no cue lane, no notebook, no map, no roster page |
| Audio | Synth cues, generative music, Mark's seven tracks, the Kenney announcer | The announcer is the cabinet; nobody commentates the Grid; the board is mute |

Read against the brief: a complete loop with a thin skin. KERB's conclusion applies word for word: what is missing is not
another system, it is density: faces, places, reasons, and things to find.

## 2. The world, settled

### 2.1 Frame and tone (stays)

The cabinet frame (Griptap & Co, the second trip, "the machine is bigger"), the Tron-clean tone, single player, no
cutscenes, every line from a named voice in a known register. The three districts stay: **DOWNTOWN** (Neon City at night),
the **OUTLANDS** (Sunset Canyon by day), **THE CORE** (Neon City dense, in the storm). The Grid is the fourth place: not a
district but the court.

### 2.2 Three nouns the lineage says the world needs

Report A's reading of twelve "inside the machine" stories gives the same recipe every time: two props and one taboo.

| Noun | What it is | Where it lands |
|---|---|---|
| **The disc** | The packet, renamed. A rider's disc is their route: name, memory, right to ride. Deliver it and they keep who they are; it is also what you duel with. "PACKET" on RELAY 01's card becomes "DISC: ?" and on RUN 03 "DISC: YOURS". | One noun on six job cards, the briefing's goal line, the ending |
| **The I/O Line** | The one route no program may ride: the line out of the system, which VESS's licence forbids and the finale rides against a closing window. The skyline's spire is where it goes. | A landmark in the core, DUEL 04's stakes line, the end card |
| **The broken rule** | "Every program rides a route" was the rule. VESS and SABLE rewrote it: "every route is owned". Winning the last duel restores the rule, not kills a boss. | The chapter 3 card, the unseen sender's last line, KADE's ending message |

These give the arc a *state* (the rule is broken), a *goal* (restore it by owning your route), *heroes* (the four riders,
programs or not, who ride for the rule) and *villains* with wants (VESS wants the licence fees, SABLE wants the routes).

### 2.3 Cast, shared with KERB Skate

| Who | In KERB Skate | Here | Status |
|---|---|---|---|
| The four riders | the roster, bios, stats, signature tricks | the same four, handling on the board; each gets **one line per event class** (launch, hit, trick, derez) in the board's voice, per rider | riders mute today: GAP → S |
| Griptap & Co's owner | the comic's narrator | the **interlude voice**: a static panel and three lines between chapters ("the kid's still in there, I can see the screen"), and the shop as the cover body left behind (Starfighter's Beta) | S |
| The Donny (the red-singlet braggart) | the top of the high-score table, the final rival | **the first route SABLE ever bought**: his gold board rides the Grid as a reigning ghost (the Legacy champion), DUEL 03 is held on his line, and his gold livery is the end-of-arc reward | DESIGNED → M |
| VESS, KADE, ORIN, SABLE | — | unchanged, plus trust counters and Blacklist positions | built |
| **The Kerbie Astro** | the shop's board | **the talking board** (Cloudpunk's Camus): a synth beep and a one-line text per event class, the cheapest companion possible; "No wheels. Doesn't need 'em where it's going." is already its first line | S |
| Clerks | twelve storefronts with clerks | **six kiosks**, one per district pair: a hologram storefront on a fork branch with a one-button pass-by (§4.4); the brand names come from KERB's town (MARLOW DELI, CANNERY RECORDS, BODEGA 24 … as the downtown's signs) | DESIGNED → M |

### 2.4 The arc, deepened (what changes in the eighteen jobs)

Chapter 1 stays the setup. Two changes: SWEEP 01's beacons become the first **route tags** (the discs KADE seeded carry
names), and DUEL 01's intro card says what a duel costs ("lose and your colour is Kade's until you take it back").
Chapter 2 gains the Donny: SALVAGE 01's crates hold "a gold route, old, sold twice"; the Grid ghost appears in free play.
Chapter 3 gains the I/O Line: the core's spire is the landmark every job rides toward; SWEEP 03's beacons are the
ledger's lines and the last one is yours; DUEL 04 is ridden "for the I/O Line", first to three, no pads, no pickups
(report A's fair duel after a rigged game). The ending gains a choice (§4.5).

The dependency chart, Gilbert's way (narrow → bushy → collapse), per chapter: the chapter's duel is the collapse; the
three parallel threads are the notebook's lines (§3.2).

## 3. What ports from KERB Skate

The sibling built four data-shaped systems on 17 Oct 2026. Each has a seam here (report D).

| KERB system | What it is | GALACTIC seam | Cost |
|---|---|---|---|
| `Guidance.swift` | rule cards once each (the world waits, Ⓐ dismisses), a cue lane with cooldown and per-run cap, FULL / LIGHT / OFF persisted | `MissionRunner.allowsMotion` already parks the world; the chapter card is a once-card; `commsSlots` is a three-slot lane; `prefs.*` for the level | S–M |
| `Notebook.swift` | per-act lines auto-ticked from persisted state, `needNotes` of them plus the medal to open the next act, a hint ladder (three lines, vaguer to plainer) | `isUnlocked` is the gate to extend; `flags.<job>` and `rank.<job>` are the auto rules; MESSAGES is the pause page to put it on | M |
| `GoalCard.swift` | nine persistent goals per level (score tiers, a combo, three of an event, letters, named gaps, five stickers), each paying once | `Mission.Flags` and `offer.<id>.done` are the once-only pattern; `BeaconLayer` is the sticker; the briefing has room for a card | M |
| `Barks.swift` + `barks.json` | event → variants per named voice, per-act overrides, cooldown / cap / chance, no repeat of the last | `Debrief.swift` is the same shape as Swift switches; `Soundtrack.announcePool` has the picker | M (with the narrative file, §7.1) |
| Clerks as door stops | a storefront door becomes a four-second card | the kiosk pass-by (§4.4) | M |
| The colour script | five `Tuning.Daylight` presets, one per act | `Theme` variants per chapter (§5.1) | M |
| Workstreams with owners | five streams, one artefact each, a cohesion check per step | §9 | — |

Not ported: the park's judged / best-trick / SKATE formats (the Grid's ladder is the competitive layer here), stickers
on trickable props (route tags on branches do the job), the heat meter as police (the pursuer is the heat).

## 4. Gameplay and flow

### 4.1 Objective shapes to add (five, from report C's catalogue of 36)

| Shape | Dressing here | Reuses | Cost |
|---|---|---|---|
| **Letters on the line** (THPS S-K-A-T-E) | five glyphs spelling R-O-U-T-E placed on the climb and boost lines of a job; all five in one run pays a flag and a notebook tick | `BeaconLayer` with letters, `Flags` | S |
| **Checkpoint stars + ghost** (Mirror's Edge, Trackmania) | three times per job (bronze / silver / gold are KADE's, ORIN's and SABLE's posted times, the author medal is the cast's); the retry races your own ghost | the fixed 60 Hz step; a `GhostActor` from `SpeederController.tint` | M–L (ghost) / S (times) |
| **Trick over object** (Skate 3 Photo) | "barrel roll the overpass", "360 through the gateway": board jobs only; tricks feed the hull (Rollerdrome's reload) with repeat decay | `startTrick`, `trickLandedNow`, the landmark dressings as volumes | M |
| **Heat escape with a hideout** (JSR, BRC) | hits raise the pursuer's speed; a kiosk branch sheds heat; the gap bar gains a heat tint | the escape kind, `PursuerActor` | S |
| **Persistent goal trio per world** (Alto, THPS) | three goals per district on the briefing, progress kept across runs, paying once; the GoalCard port | GoalCard (§3) | M |

Also cheap and worth it: **tag the district** (search with any-order markers spread laterally; S) and the **daily job**
(a seeded corridor from the date, one scored attempt, after the arc; S).

### 4.2 Hazards to add (five of 28)

| Hazard | Tests | Telegraph | Need |
|---|---|---|---|
| Sweeping laser | timing | emitter charge pulse, a beam trace a second before it fires | a new `ObstacleKind` with a phase |
| Lane gate (one open slot) | lane choice | the open slot lit, the closed ones dark | a row variant |
| Phase wall on the music bar | rhythm | pulses to `SoundEngine`'s bar clock (the only runner that already quantises music) | the bar phase exposed to the scroller |
| The barrel-roll bargain (Wipeout) | risk | a HUD prompt on air; the roll costs hull and pays a landing boost | `trickLandedNow` → a speed kick |
| Time gates + checkpoints | pacing | a hologram clock ring; portal frames restore hull | gates exist; checkpoints = respawn points made visible |

Chapter density (0.8 / 1.0 / 1.3) stays the dial; new hazards enter by chapter, one per chapter, so the vocabulary
grows with the story (F-Zero GX: the chapter's rule is the story beat).

### 4.3 The Grid as a ladder

- **`MatchRules`** (report D 11a): `target`, `zoneAt`, `trailLength`, `boostAllowed`, `spawnDeck`, `mirror`, `pickups`.
  Ten named matches from one arena: CLASSIC (first to 3), SUMO (zone from 5 s), FORTRESS (hold a pad 8 s), CUTS (first
  to 3 cuts), SURVIVE (60 s against a 2× rival), TAG (touch the tail), DECK (deck-only spawns), DARK (your trail the
  only light), SNAP (snap turns only), THE LINE (DUEL 04: no pads, no pickups, no boost).
- **`ArenaLayout`** (12): pads, hazard strands, zone timing, pickup timers as data; the garage stays the terrain.
- **The Blacklist** (report C): KADE → ORIN → SABLE → the Donny's ghost → VESS, each behind two gating jobs in their
  district; every corridor job carries a **rival of the job** with a posted time and a taunt that changes when beaten.
- **Stakes**: lose a duel and your livery is the rival's until the rematch (Burnout's claim-the-car inverted); win and
  their trail colour joins your liveries; a "MARKED" flag spawns the beaten rival as the pursuer in the next job.
- **Heat on rematches** (Hades' Pact): replay a duel with mutators (fast decay, no boost, half hull) for a bigger purse
  and the rival's colour.
- **The ladder card**: a bracket on the briefing for duel jobs (M, a HUD card).
- **Not built**: team of two (the controller's two-cycle assumption, the one true L item), discs as weapons (a second
  weapon system; the bolt is enough).

### 4.4 Clues and people in a corridor (four beats, S each)

| Beat | Mechanism | Need |
|---|---|---|
| **The kiosk pass-by** | a hologram storefront on one branch of the fork; press Ⓐ in a three-second window to log the clerk's line (and shed heat); the clerk's line is a rule card in costume (KERB's rule) | a `.kiosk` dressing on branch blocks, a trigger window, a line table |
| **The billboard clue** | a hologram billboard shows a glyph for 3 s; shoot the right one (Rez lock, Spider-Man's green frame) to add a fragment to the ledger | the billboard pool, the bolt hit test |
| **Lane as dialogue** | the witness talks on comms; at the next gate the left lane asks about the route, the right about KADE; no reply is its own answer (Oxenfree) | the gate volumes, a flag, one later line |
| **One informant per chapter** | two amber side offers, only one takeable before the chapter card (Night in the Woods) | a mutual lock on `SideOffer` |

Verification (Obra Dinn): three fragments (who sold it, where, when) must match before DUEL 03's accusation card unlocks.
The bounded set makes the city a detective's city without a dialogue tree.

### 4.5 Rewards that carry story (none a currency)

- **Trust per contact** on the result card with their one-liner (Death Stranding's Likes, Hades' keepsakes): `rep.<contact>`
  gates side offers and the chapter card's standing.
- **The roster / ledger page** (Obra Dinn): a page that fills in as programs' names, routes and fates are learned, fed by
  the rival records and the fragments.
- **Route tags** on alternate branches (JSR Graffiti Souls): a `ShardLayer` clone of `BeaconLayer`, counted per job.
- **Chapter clocks and drives** on the briefing (Citizen Sleeper): "SABLE's offer expires in 2 jobs", a filling ring per
  chapter.
- **The ending choice** (Sable's mask): ride out in your own colour, or in the Donny's gold; the title screen keeps it.
- **Trick Book**: every trick and section first-done, with the board's line for each.

## 5. Graphics, UI and cards

### 5.1 A colour script per chapter
`Theme` gains variants: DOWNTOWN stays the reference night; the OUTLANDS gets **dusk** for its last two jobs (the sun
dropping with the clock, KERB's curfew lerp); THE CORE gets the **storm** (heavy rain + rain fog, exists) and a
**blackout** for DUEL 04's approach (lamps off, the spire the only light). Implementation: new enum cases with a `.world`
accessor (report D 5, M), the rain rule as the precedent.

### 5.2 Story on the signs
The sign pipeline takes a chapter parameter: one story set per chapter (a wanted poster for the route-holder, SABLE's
buyer's mark, "ROUTES BOUGHT · FAIR PRICE", KERB FM leaking in from the real world), progress-gated so the city visibly
changes (report D 14, S). Murals as emissive glyph panels at section mouths (wordless story, Hyper Light Drifter).

### 5.3 Landmarks and extras
One monument per district visible from the skyline (the relay tower, the mesa arch, the spire with the I/O Line),
placed by the composer every N blocks (report D 15, M). Extras with a reason: parked cycles that light as you pass,
drones that follow for three seconds, a sign that reads your callsign (report D 16, M; entity count on the phone first).

### 5.4 The Grid's audience
A crowd strip above the 16 m wall (the brief item 9 already owed) and a **commentator**: lines keyed to
`ArenaController.Events` through the announcer's cooldown / priority / chance (report D 13, M). The rival's record on
the strip's screen.

### 5.5 Cards and screens
Rule cards and the cue lane (§3), the notebook on the pause and the briefing, a **district diagram** (not geography: the
three hubs, who is where, the clocks; S–M), the roster page, the ladder card, **photo mode** from the pause with a
postcard composite (callsign, rank, the job; report D 18, M), CC5 portraits through the `Rival.portrait` seam when
Mark's faces exist (S).

## 6. What not to build

An open hub to walk around (the briefing card does its job; the shop stays a panel and a voice), a mid-run stop (the
scroll model; the pass-by does it), team duels, a second weapon system, dialogue trees, voice acting before the mix is
settled on the phone, any plot branch (choices change lines and offers, never the arc), and more than one new hazard
per chapter.

## 7. Architecture: where each piece lives

### 7.1 One narrative file
`Resources/narrative.json` (`Codable`, the first JSON in the repo): briefs, debriefs, comms, reactive lines, taunts,
round lines, the board's lines, the riders' lines, the kiosks' lines, posters by chapter, rule cards, cues. Loaded like
`ArtLibrary` with the Swift tables as the fallback so the headless tests keep compiling; interpolations (`{hits}`,
`{section}`) and rotations (`[wins % 3]`) as a small template rule. `xcodegen generate` after adding it.

### 7.2 Systems and files
| Piece | New / touched | Notes |
|---|---|---|
| `Missions/Guidance.swift` | new | KERB's file, keys `guide.<id>`, `prefs.guidance`; cards fire on events via `MissionRunner`; `demo` dismisses |
| `Missions/Notebook.swift` | new | per-chapter lines with `auto` rules on `flags.` / `rank.` / `shards.` / `rep.`; `isUnlocked` gains `needNotes` |
| `Missions/GoalCard.swift` | new | per-world goals with predicates on `MissionState` and `MatchResult`; keys `goal.<world>.<id>` |
| `Missions/Barks.swift` | new | the picker over the narrative file; feeds the comms lane and `Soundtrack.announcePool` |
| `Missions/Mission.swift` | touched | the disc nouns, `Kind.trick`, letters / tags / heat fields, rival-of-the-job, more offers with a mutual lock |
| `Missions/MissionRunner.swift` | touched | trust, shards, heat, checkpoint times, the ending choice; every new key into `SaveSlot` |
| `Missions/MissionProps.swift` | touched | `ShardLayer` (letters, tags), `GhostActor`, kiosk window |
| `Scene/TrackProgram.swift` | touched | `.kiosk` and `.monument` dressings, `Phrase.monument` every N blocks |
| `Scene/WorldScroller.swift` | touched | the kiosk storefront on branch blocks, lasers / lane gates / phase walls as `ObstacleKind`s, the bar phase |
| `Scene/Theme.swift` | touched | variants with a `.world` accessor; `SceneMaterials(device:theme:chapter:)` |
| `Arena/MatchRules.swift`, `Arena/ArenaLayout.swift` | new | replace the statics; set where `matchTarget` is set |
| `Arena/ArenaController.swift` | touched | reads the two structs; the commentator bus |
| `Arena/ArenaWorld.swift` | touched | the crowd strip; pads from the layout |
| `Views/HUDView.swift` | touched | rule cards, the cue lane, the notebook, the goal card, the ladder card, trust on the result, the ledger page, the map |
| `Views/FrontEndView.swift` | touched | the map and roster screens (the `StoryIntroView` pattern), PHOTO on the pause |
| `Tests/MissionLoopTests.swift` | touched | one test per new kind, the notebook gate, the trust rules, the ladder |

### 7.3 Guardrails
Every new progress key into `SaveSlot.exactKeys / prefixes`. Scene changes only through `requestRebuild()`. Corridor
props verified with `capture.sh` + `SPEEDER_CAMERA=overview`; HUD cards with simulator sheets; arena variants with
`SPEEDER_ARENA_CAMERA=overview`, one run at a time. The AI's boost cap stays at 54 m/s. Entity count on the phone before
extras. The goal stays on the HUD until done; every sub-step confirms on the frame it registers; nothing gates on one
recognition; repeats never farm; story never stops the wheels (a pass-by is three seconds and skippable).

## 8. Build order (each step playable and provable on the harness)

| # | Step | Sessions | Proof |
|---|---|---|---|
| 1 | **The nouns and the narrative file**: disc / I/O Line / the broken rule on the cards, `narrative.json` with every existing line moved in, the board's and the riders' lines, the owner's interludes | 1–2 | `SPEEDER_MISSION=n SPEEDER_HOLD_BRIEFING=1` sheets; 14 tests green against the JSON |
| 2 | **Guidance, Notebook, GoalCard, Barks** ported; rule cards for every kind and the Grid; the notebook on the pause and the briefing; nine goals per world | 2–3 | `GUIDE` / `NOTE` / `GOAL` log lines; simulator sheets of the cards; the goose gate in a test |
| 3 | **Objectives and clues**: letters, checkpoint stars with posted times, trick-over-object, heat escape, tag the district; the kiosk pass-by, the billboard clue, lane-as-dialogue, exclusive offers, the three-fragment gate | 2–3 | headless tests per kind; `capture.sh` of the kiosk branch and the letters; `SPEEDER_FLAGS` for offers |
| 4 | **The Grid ladder**: `MatchRules`, `ArenaLayout`, ten named matches, the Blacklist, stakes, Heat rematches, the ladder card, the Donny's ghost | 3 | `SPEEDER_ARENA_CAMERA=overview` runs per rule set, one at a time; `MATCH` log lines; the stake in a test |
| 5 | **The look**: `Theme` variants (dusk, storm, blackout), story posters per chapter, one monument per district, the crowd strip and commentator, two new hazards | 2–3 | frames per chapter at 4 / 9 / 17 s; the crowd from the arena side camera |
| 6 | **Rewards and screens**: trust, the roster / ledger page, route tags, chapter clocks, the district diagram, the ending choice, photo mode, portraits through the seam | 2 | sheets per screen; `SPEEDER_SCREEN=map|roster` |
| 7 | **After the arc**: the daily job, classes (replay at gold raises windows 15 %), the ghost actor | 1–2 | `SPEEDER_DAILY=<date>` seeds; a ghost frame |

Steps 1–3 need no new art. Step 4 needs the Donny's gold livery. Step 5 needs Mark's poster and crowd panels through
the existing GPT-render route. Everything is judged on the phone before the next step; PR #7 (the garage) is judged
first, since steps 4 and 5 build on it.

## 9. Workstreams and the agents that run them

Five streams, each owned by one agent brief per session, one artefact kept current, one cohesion question. An
integration pass (the sixth hat) runs the full loop on the phone at the end of every step.

| Workstream | Owns | Keeps current | Cohesion check | Agent brief (first session) |
|---|---|---|---|---|
| **Story & voice** | the nouns, the cast, every line (`narrative.json`), the interludes, the ending | `narrative.json` + a script table (speaker, chapter, trigger, text) | Does every line come from a named voice in a known register? Is the Donny set up before he pays off? | Move every Swift line into the JSON with the loader and fallback; add the three nouns to the six cards; write the board's and riders' event lines (four riders × four events) and three interludes |
| **Missions & rules** | kinds, hazards, the notebook, the gates, the clue beats | `Mission.deliveries` + the dependency chart + `MissionLoopTests` | Can every chapter be finished three ways? Does every rule a card states match the code? | Port Notebook and GoalCard; add letters, checkpoint times, heat and the kiosk window; one test each |
| **The Grid** | `MatchRules`, `ArenaLayout`, the ladder, stakes, the AI on the helix, the crowd | the match table (ten rows) + arena captures | Does every match read from the chase camera? Does the rival survive its own rules? | Replace the statics with the two structs; ten rows; the stake and Heat in `MissionRunner`; overview captures per row |
| **World & look** | `Theme` variants, posters, monuments, extras, the colour script | a per-chapter look sheet (`Captures/polish/p19/`) | Is the chapter readable from a still: time, poster, landmark? | Variants with a `.world` accessor; the chapter parameter into the sign pool; a `.monument` dressing; frames per chapter |
| **Guidance & HUD** | rule cards, cues, the goal card, the map, the roster page, photo mode, the result and ladder cards | `Guidance.cards` / `cues` + a HUD sheet per screen | Can a first-time player say what to do from the card alone? One job and one place per HUD element? | Port Guidance; write the cards for six kinds and the Grid; the cue lane over `commsSlots`; simulator sheets |

Rules for the agents: branch per workstream off master after step 1 lands (the narrative file is shared ground, so it
goes first and alone); never two writers on one file (the HUD stream owns `HUDView`, the missions stream owns
`MissionRunner`, everything else negotiates through `MissionState`); every PR carries its proof; the GDD's tags and the
map's `ELEMENTS` are updated by the integration pass, not by the streams.

## 10. Decisions for Mark

1. The three nouns (disc, the I/O Line, the broken rule): yes / rename.
2. The Donny as the first bought route and the gold livery: yes / no.
3. The talking board (text + beep): yes / no.
4. Stakes on duels (your livery until the rematch): yes / soften to a cosmetic only.
5. Step 1 (the narrative file) before step 2: go.
6. The ending choice (your colour or the gold): yes / later.
7. Photo mode's Photos permission: fine / keep it to the capture folder.

## Appendix: method
Four agents ran on 17 Oct 2026 (reports in `research-2026-10-17-reports.md`): A the lineage and arena / runner design
(37 sources), B narrative devices and cheap depth (37), C objective, hazard, rival and clue catalogues (44), D the code
audit (read-only over `Sources/` against the GDD). The author read KERB Skate's `RESEARCH_STORY_2026-10-17.md`,
`STORY_2026-09-27.md`, `DECISIONS.md`, `GDD_2026-10-17.md` and its `Guidance`, `Notebook`, `GoalCard`, `Barks` and
`Mission` sources. No page fetches were blocked this time; specifics from wikis and reviews are marked in the reports.
