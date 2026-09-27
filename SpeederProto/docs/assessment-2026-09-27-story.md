# Story assessment (27 Sep 2026): where the narrative stands and how to weave an "adventure" into the runner

Question asked: how does the game go beyond steering a vehicle around objects and opponents, what
thinking about the storyline exists from earlier threads, what do narrative-driven vehicle games
(GTA, Driver, NFS, and the short-session comparables) do that fits here, and what should change in
the planned build order. Method: a read of `docs/game-direction.md`, both market and mechanics
assessments, the research reports, `Missions/Mission.swift`, `Missions/Debrief.swift`,
`Arena/Rival.swift`, `Missions/Player.swift`, and one research agent on story-in-vehicle-games
(report appended in section 6). No code was changed.

## 1. The game as it stands (orientation)

- **Loop**: title -> briefing card (contact, brief, goal line, inbox chips, garage rows) -> GO ->
  a 60 to 100 s corridor job (delivery, sweep, escape, salvage, dive) or a Grid duel (first to two
  or three derezzes) -> result card (rank, flags, payout, the contact's debrief line and one reactive
  line) -> next job. Cleared jobs replay at half pay. Free play on any of the three worlds.
- **Meta**: credits, a four-item garage, per-job flags and ranks, rank titles (ROOKIE, COURIER,
  GATE-RUNNER, UNBOXED), a callsign and livery, head-to-head records per rival, a rival intro
  card with a taunt from the record, comms stamps in the run (three per job at most), a music state
  machine and per-world ambience beds.
- **Cast**: VESS (dispatcher, clipped), KADE (outlands rider, blunt and warm, HUNTER, STEADY),
  ORIN (relay runner, sharp, BOXER, SHARP), SABLE (the buyer, RUNNER, KEEN). Each contact has one
  register and a pool of reactive lines. Portraits are procedural glyphs; the briefing avatar is the
  Avaturn test character.

## 2. The current storyline, as written in the eighteen jobs

**Arc**: a new courier rides packets for VESS across Downtown. KADE plants beacons, sends a drone,
books the Grid, loses DUEL 01 and turns contact ("come out to the canyon and I will show you what
the packets are"). In the Outlands the player opens a crate: addresses in the core, so VESS is
selling, not delivering. ORIN runs the canyon relays for "someone in the core", loses DUEL 02 and
turns contact: VESS sells to SABLE. In the Core, VESS's drones hunt the player from the first metre,
the player wrecks SABLE's shipment, sets a time on the deep line, sweeps VESS's ledger for proof,
derezzes SABLE, and VESS rides its own cycle for the last duel. Ending line: "The route is yours."

**What works** (keep): a clean three-act betrayal shape with each act's rival becoming the next
act's contact (the "each boss turns ally" ladder; the research shows Most Wanted, Death Rally and
F-Zero GX all end on the boss the ladder pointed at). Distinct registers per voice. The Hades rule
on the result card, so the game visibly saw the run. Records that make the rival remember. Every
mechanic showcase (conduit, split, salvage, dive) has a story reason in its brief.

**What is missing** (the gaps the rest of this document addresses):

1. **The player has no want.** The player is "new rider" and rides because jobs pay. No reason to
   take VESS's first packet, no reason to care who buys them. Every comparable that lands gives the
   protagonist a personal stake in the first ten minutes (a stolen car, a coma, a debt, a sibling).
2. **The MacGuffin is never revealed.** RELAY 01: "Do not ask what is in them." Nothing ever
   answers. "Addresses in the core" and "every packet, every buyer" describe a ledger, not a stake.
   The one line that comes close is SABLE's "Vess picked the wrong rider to sell out" and ORIN's
   "Sable has booked the Grid and named you": the packets have something to do with the player.
   That thread should be pulled: it is the cheapest possible personal stake and it is half written.
3. **The story is not re-readable.** Debriefs appear once on a result card and are gone. A player
   who plays two jobs a day on the phone has lost the plot by chapter 2. The message log has been
   on the owed list since 18 Sep (three kickoff prompts) and is the single biggest fix.
4. **Zero agency.** Jobs unlock strictly in order; the only choice in the game is the fork branch,
   and no line ever acknowledges it. The research is clear that plot branches are not needed, but
   order, side offers and acknowledged choices are the cheap way players feel authorship.
5. **Chapters have no threshold.** A chapter change is a world rebuild; there is no title card, no
   "where we are" paragraph, no cast recap (Art of Rally's era text, Wipeout 2048's seasons).
6. **The ending is a payout line.** No consequence in the world, the inbox or the title screen after
   DUEL 04; the rank title UNBOXED is the only lasting mark and it is earned by golds, not by the story.
7. **The rival is silent during the duel.** Records and taunts live on the intro card. The Grid, the
   most character-driven mode, has no in-run voice from the opponent (a cut-off, a lead change, a
   near miss) beyond the death attribution.

## 3. What has been thought about the story in earlier threads

| Date | Where | What was decided or proposed |
|---|---|---|
| 11 Sep | `docs/game-direction.md` | Mission runner with a light story; the player as a courier program in a fractured system; a **hub** (the garage deck with avatars and a job board); a story beat every few jobs told by one line and an avatar; five contacts, one twist, three districts, text only. Open questions: avatar style, tone, single player. Tone was later fixed as Tron-clean; single player, yes. The hub was dropped in favour of the briefing card (the parked bike with the contact beside it). |
| 13 Sep | `docs/research-comparables.md` report C, shortlist 10 | The SMS inbox as the hub (NFS Underground 2): contacts text jobs in, colour-coded by kind; the avatar briefing becomes a call from the inbox. Ranked 10 of 15; the inbox chips built on 18 Sep are the reduced form (jobs only, no messages). |
| 18 Sep | `assessment-2026-09-18.md`, README "The game" | The three-chapter arc and eighteen jobs with one debrief each; "an inbox that carries the contacts' story" listed as owed. |
| 26 Sep | `assessment-2026-09-26-market.md` 4.4 and workstream D; `research-2026-09-26-reports.md` report B | Hades' rule, one voice one line, cast escalation, identity at the peak; D1 reactive debriefs, D3 rival card, D5 comms (built); D4 the cast through CC5 / iClone 8 (owed, Mark's, Windows); report B items 9 (contact mood states), 10 (garage as story) and 8 (postcard) not built. Decisions for Mark left open: talk delivery (video-in-HUD vs blend shapes), helmeted or faced player character. |
| 26 Sep | `research-2026-09-26-reports.md` report E | The CC5 -> iClone -> Blender -> USDZ pipeline, budgets, the blend-shape-during-clip bug, alpha PNG portraits, licensing. First character 2 to 3 days, then a day each. |

Not thought about anywhere yet: the player's motivation, what the packets are, a re-readable log,
player agency, chapter thresholds, the ending's consequence, the rival's in-duel voice. These are
the seven gaps above; the earlier work built the delivery devices and skipped the spine.

## 4. What the comparables say (the research in one paragraph; full report in section 6)

Story in vehicle games is delivered without stopping the wheels: a handler or radio voice (GTA,
Burnout, Pacific Drive, Ghostrunner), a passenger who reacts (Driver: San Francisco, Mad Max), or
reactive one-liners that can be ignored (Into the Breach, Hades). Missions are framed by givers:
concurrent contacts make order feel chosen (GTA III), or a linear ladder with optional side offers
and sponsors (Death Rally, NFS Underground 2). Rivals are a visible ladder to a boss with a personal
stake, and a hidden boss above the visible one (Most Wanted's Razor, F-Zero GX's Deathborn). The job
board is a pager, an SMS inbox or an answering machine, and it doubles as tutorial and unlock notice.
Short games end on the single payoff the ladder pointed at. Agency is faked with order, economy and
acknowledged choices, never plot branches. Voice-less indies do it with portraits, short text, team
bios and era paragraphs; Simogo added the narrator to Sayonara Wild Hearts last and it defined the
game. Failure modes: barks that repeat, a narrator on every vista (Solar Ash), lore that is only
flavour (Redout 2, Riptide), and chapter titles with no people in them (Asphalt).

## 5. Determinations and recommendations

### 5.1 The spine first: give the courier a stake (text only, one afternoon)

The fix is a rewrite of about a dozen lines, not a system.

- **What the packets are**: rider records. Every program on the grid has a route (its identity and
  its right to ride); VESS's "packets" are riders' routes, and SABLE buys them to derez the rider
  and take the route. The player's own route is in the ledger: the last packet the player carries
  in chapter 1 is their own. This is already implied ("named you", "sold out") and makes every
  existing line land harder without contradicting one.
- **The want**: the player is a new program with a provisional route; VESS holds the licence. Ride
  and it becomes permanent. Line it in RELAY 01's brief and VESS's first debrief. The chapter 3
  reversal then reads as: VESS was always going to sell the route the player was earning.
- **The ending**: DUEL 04's debrief already says "the route is yours". Make it true: the title
  screen's callsign line carries a new rank title (say ROUTE-HOLDER, earned by the story and not by
  golds), the inbox gets one last message from KADE, and free play's rival roster adds VESS. Three
  small changes and the game has a consequence.

### 5.2 The message log as the pager (S to M, already owed; promote it)

Turn the inbox from a list of job chips into the story channel (NFS Underground 2, GTA III's pager,
Hotline Miami's machine): every brief and debrief is kept as a message from its contact, unlock
notices and garage purchases post a line, and the log is readable from the briefing and the title
(the "message log" in the kickoff prompt's item 4). Add one unseen sender: three cryptic messages,
one per chapter, from someone signing as the route itself (Tron 2.0's degraded "Guest"), resolved by
the reveal in 5.1. This is the item that fixes gap 3 and half of gap 5, and it is where the CC5
portraits will be seen most.

### 5.3 Chapter cards (S)

A title card on entering each chapter: the district name, one 40-word paragraph (where the route is,
who is on your side, who is not), the cast's portraits with their current standing (contact / rival /
unknown). Art of Rally's era text and Wipeout 2048's seasons show a paragraph is enough. Hook it on
the first job of each chapter in the runner, hold it like `SPEEDER_HOLD_BRIEFING`.

### 5.4 The rival's voice in the duel and memory across duels (S)

Two or three lines per rival per event (cut you off, got cut off, lead change, round won, round
lost), shown as the existing comms stamp with the rival's colour, at most one per round, never at
the derez itself (the attribution owns that frame). Taunts keyed to the record already exist on the
intro card; extend the record states ("third time, Kade") so the rival's memory is felt. This is
the Hades pattern applied to the mode that has the most character and the least text.

### 5.5 Cheap agency (M, after the phone pass)

- **Order inside a chapter**: after a chapter's first job, unlock its next two at once; the chapter's
  duel stays gated on all of them. The inbox then has a choice in it.
- **Side offers**: optional one-line offers in the inbox, flag-gated (CLEAN on RELAY 02 opens "KADE
  wants the split ridden through the tunnel, +150"). They reuse existing jobs with a modifier and a
  different sender, so they cost text and a rule each.
- **Acknowledge the fork**: one debrief variant per branch ("You took the skyway. Kade saw that.").
  The fork is the only choice in the run today and nobody notices it.

### 5.6 The cast through CC5 / iClone 8 (D4, Mark's, unchanged in scope, changed in order)

Do 5.1 and 5.2 before the character sessions, so the portraits and clips are made against a locked
script and a known set of moments. Portraits first (alpha PNG at three sizes, replacing
`ProceduralTextures.portrait` through `Rival.portrait(for:)`); they land in the inbox, the chapter
card, the briefing, the rival card and the freeze-cam. Talk clips at three moments only (briefing
accept, result card, chapter card), under four seconds, so nothing gates a two-minute job; the
video-in-HUD route is the safe one per report E. The player character: helmeted (no face pipeline)
unless Mark wants the face; the rider screen and the title can then show the rider beside the bike.

### 5.7 What not to build

An open hub to walk around (the 11 Sep hub idea; the briefing card does its job and phone sessions do
not want a walk), dialogue trees, cutscenes longer than a card, voice acting before the mix on the
phone is settled, and any plot branch. A passenger or handler voice with real VO is the only item on
the research list that needs a budget and it is last.

### 5.8 How this changes the kickoff prompt

The kickoff prompt's order stands with three edits:

1. **Branch**: the prompt still says to check out `claude/game-prototype-assessment-chlzto`; that
   branch is merged. Current work is `claude/front-end`, one commit ahead of master and not merged.
   Merge it (or open the PR), then branch `claude/story` off master for the items above.
2. **Item 1 (phone pass) and item 2 (balance) unchanged.** They are verification and numbers and do
   not depend on the story.
3. **Item 3 (D4) moves after a new item: the story pass** (5.1 spine rewrite, 5.2 message log with
   the unseen sender, 5.3 chapter cards, 5.4 the rival's voice), all text and SwiftUI over systems that
   exist, one thread, capture-verified on the simulator with `SPEEDER_MISSION` and the hold hooks.
   Then D4 with the script locked. 5.5 (agency) is the "if there is time" item; the message log leaves
   item 4 because it is now in the story pass. B4, A6, D9 unchanged at the end.

## 6. Research report: story and "adventure" in vehicle-action games (27 Sep 2026)

Web sources only; where a source is thin (wiki, forum) it is flagged. Cases with no usable source are omitted and named at the end.

### 6.1 Case studies

**Grand Theft Auto III / Vice City (2001/2002).** Core action: drive-to, chase, escape. Missions come from a web of contacts (Luigi, Joey, Salvatore, etc.; Ken, Lance, Sonny in Vice City); several contacts are open at once, so order is partly the player's, which is also why GTA III has 10 missable missions ([GTA Wiki](https://gta.fandom.com/wiki/Missions_in_GTA_III), [gtabase](https://www.gtabase.com/gta-3/missions/)). Delivery devices: a cutscene at the giver's marker, the pager for "meet a new contact / mid-mission info" ([GTA Wiki: Communication](https://gta.fandom.com/wiki/Communication#Pagers)), 17 payphone side jobs, and radio that became "one of the series' main storytelling tools" ([GenerationAmiga](https://www.generationamiga.com/2026/06/19/gta-radio-stations-explained-the-feature-that-made-grand-theft-auto-iconic/)). Cast: employer(s), a partner who turns betrayer (Lance) and a boss who turns enemy (Sonny), resolved in one final mission ([GTA Wiki: Keep Your Friends Close](https://gta.fandom.com/wiki/Keep_Your_Friends_Close...)). Copyable: contacts as menu entries, a pager line that hands you the next job, betrayal by the friendly mid-tier contact.

**Driver: San Francisco (2011).** Core: chase, ram, take-down. The story (Tanner in a coma hunting Jericho; hospital TV news bleeds into the dream) is the excuse for the *shift* mechanic, possessing any driver ([PopMatters](https://www.popmatters.com/153101--2495898969.html), [Wikipedia](https://en.wikipedia.org/wiki/Driver:_San_Francisco)). Nearly all character work happens in-car: Tanner and Jones bickering, and comic passenger exchanges every time you shift ([TV Tropes Funny](https://tvtropes.org/pmwiki/pmwiki.php/Funny/DriverSanFrancisco)). Copyable: make the story explain the mechanic; a two-voice banter partner who reacts to what you just did.

**Need for Speed: Most Wanted (2005).** Core: sprint/circuit races plus police pursuits. Frame: a 15-name Blacklist, Razor at the top having stolen your BMW M3 GTR; each rival is a boss you unlock by racking up bounty and milestones ([NFS Wiki: Blacklist](https://nfs.fandom.com/wiki/Need_for_Speed:_Most_Wanted_(2005)/Blacklist), [Wikipedia](https://en.wikipedia.org/wiki/Need_for_Speed:_Most_Wanted_(2005_video_game))). Delivery: live-action FMV with real actors and CG-enhanced cars ([EA Wiki](https://electronicarts.fandom.com/wiki/Need_for_Speed:_Most_Wanted_(2005_video_game))). Cast: helper/informant (Mia, who turns out to be police), the rival, the cop antagonist. Copyable: a ranked rival ladder is a story; one revenge stake carries 15 boss races.

**Need for Speed Underground 2 (2004).** Core: street races. Story arrives as SMS from Rachel (unlocks, tips, "you made a DVD cover, get to the shoot before the photographer leaves") and sponsor contracts that require specific race types and media clauses ([NFS Wiki: Sponsors](https://nfs.fandom.com/wiki/Need_for_Speed:_Underground_2/Sponsors), [GameRevolution FAQ](https://www.gamerevolution.com/guides/30546-need-for-speed-underground-2need-for-speed-underground-2-need-for-speed-underground-2-faq)). Antagonist Caleb rigs sponsorship deals ([Wikipedia](https://en.wikipedia.org/wiki/Need_for_Speed:_Underground_2)). Copyable: a text inbox as the whole narrative channel; sponsors as employers with conditions.

**Burnout Paradise (2008).** Core: open-world events. No story; DJ Atomika on Crash FM presents each licence, comments when you fail or free-drive, and how often you hear him scales with progression ([Burnout Wiki: DJ Atomika](https://burnout.fandom.com/wiki/DJ_Atomika), [Nintendo World Report](http://www.nintendoworldreport.com/review/54219/burnout-paradise-remastered-switch-review)). Copyable: one voice tying licences to milestones is enough "narrative" for many players.

**F-Zero GX (2003).** Core: hover racing. Story mode is nine chapters of bespoke challenges (train, chase, rescue, final duel), FMV between them; Deathborn threatens Black Shadow in the prologue and challenges Falcon for both belts in the finale ([F-Zero Wiki](https://fzero.fandom.com/wiki/F-Zero_GX/Story_mode), [mutecity.org](https://mutecity.org/wiki/Story_(F-Zero_GX))). Copyable: chapters as one-off rule variants, a bounty-hunter hero with a rival (Goroh) and a hidden boss above the visible boss.

**Wipeout series.** Lore lives in team bios and a timeline (FEISAR founded 2024, AG Systems moving to Japan) and in the framing of leagues (F5000; the 2048/2049/2050 seasons of Wipeout 2048 at C/B/A class) ([Wipeout Central: FEISAR](https://wipeout.fandom.com/wiki/FEISAR), [Wikipedia: 2097](https://en.wikipedia.org/wiki/Wipeout_2097), [Wipeout 2048 campaign](https://wipeout.fandom.com/wiki/Wipeout_2048/Single_Player_Campaign)). Copyable: seasons as chapters, team identity as characterisation, no dialogue at all.

**Redout 2 / BallisticNG.** Redout 2: 26th-century SRRL, lore via loading screens, flyover voiceover and one-time cutscenes on buying a ship; reviewers found it lighter than Redout 1 ([Saving Content](https://www.savingcontent.com/2022/06/16/redout-2-review/), [VideoGameLizard](https://videogamelizard.com/redout-ii-review/)). BallisticNG: a 2159 AGL with sixteen teams, campaign as modes and leagues, no narrative ([BallisticNG wiki, Miraheze](https://ballisticng.miraheze.org/wiki/Main_Page)). Copyable: "lore on the flyover" and team bios; both show the ceiling of lore-only framing.

**Tron 2.0 (2003) / Tron: Evolution (2010).** Tron 2.0: Jet is thrown into the light-cycle arena as a bot after being judged corrupt, escapes with Mercury's help; instructions from "Guest" and Ma3a are static-laden and misleading for most of the game, a deliberate comms-as-mystery device ([Wikipedia](https://en.wikipedia.org/wiki/Tron_2.0), [Tron Wiki](https://tron.fandom.com/wiki/TRON_2.0)). Evolution: Anon and Quorra vs Clu and Abraxas; cycles mostly serve as transit ([Wikipedia](https://en.wikipedia.org/wiki/Tron:_Evolution), [Kotaku review](https://kotaku.com/review-tron-evolutions-glow-quickly-fades-5710987)). Copyable: the arena as punishment/ordeal rather than sport; a handler whose signal degrades.

**Art of Rally (2020).** Career split by decade with a short text summary of where the sport was heading each era; reviewers call it "no real story" beyond that skeleton ([PlayStationTrophies review](https://www.playstationtrophies.org/game/art-of-rally/review/), [No Escape](https://noescapevg.com/zen-and-the-art-of-rally/)). Copyable: one paragraph of era text per chapter costs nothing and reads as a world.

**Pacific Drive (2024).** Core: driving runs into the Zone. Story is radio chatter from three holdouts (Oppy the garage owner, Tobias and Francis as straight man / wise guy), plus Oppy's stories in the garage between runs ([TV Tropes Characters](https://tvtropes.org/pmwiki/pmwiki.php/Characters/PacificDrive), [Wikipedia](https://en.wikipedia.org/wiki/Pacific_Drive_(video_game))). Copyable: three voices with fixed temperaments, a garage hub, backstory dispensed between runs.

**Mad Max (2015).** Core: car combat. Chumbucket rides along, repairs on the fly, fires the harpoon and talks constantly; his zealot arc offsets Max's silence; Scrotus is the warlord boss ([TV Tropes Characters](https://tvtropes.org/pmwiki/pmwiki.php/Characters/MadMax2015), [Wikipedia](https://en.wikipedia.org/wiki/Mad_Max_(2015_video_game))). Copyable: a passenger character is the cheapest constant presence.

**Star Wars Episode I: Racer (1999).** Tournament: top four unlocks the next course, prize money with three payout schemes, parts from Watto's shop and junkyard, pit droids repair between races, Sebulba as the marquee rival ([Star Wars Games wiki](https://swgames.fandom.com/wiki/Star_Wars_Episode_I:_Racer), [GameFAQs guide](https://gamefaqs.gamespot.com/n64/198780-star-wars-episode-i-racer/faqs/2521)). Copyable: shop + payout choice + one named rival; no cutscenes needed because the licence supplied the story.

**Sayonara Wild Hearts (2019).** About an hour; structured on the Major Arcana; a narrator (Queen Latifah) was the very last addition to production ([Simogo interview, DualShockers](https://www.dualshockers.com/wild-hearts-never-die-an-interview-with-sayonara-wild-hearts-developer-simogo/), [SYFY](https://www.syfy.com/syfy-wire/sayonara-wild-hearts-is-a-coming-out-story-within-a-female-focused-pop-music-game)). Copyable: an external structuring frame (cards, chapters) and a single narrator voice bolted on late.

**Death Rally (1996).** Career ladder to the Adversary; between races gamblers pay you to wreck an opponent, loan sharks fund upgrades, and True Tom gives cryptic speeches ([TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/DeathRally), [Bloody Disgusting](https://bloody-disgusting.com/video-games/3966500/death-rally-turns-30-looking-back-at-remedys-bloody-vehicular-combat-debut/)). Copyable: side offers between races as the whole "web".

**Rollcage Stage II (2000).** Brief pre-race intros for rivals with corporate teams (Patriot, Unity, Subsonic...); thin sourcing (a retro DB page and a Steam thread) ([Retro Replay](https://retro-replay.com/db/playstation/rollcage-stage-ii/), [Steam discussion](https://steamcommunity.com/groups/rollcage/discussions/1/616189106627570701/)).

**Mirror's Edge (2008).** Merc as radio handler during runs; story in 2D Flash cutscenes made by an external agency, judged to lack the gameplay's drama ([Wikipedia](https://en.wikipedia.org/wiki/Mirror's_Edge)). Lesson: outsourced storyboards are cheap but tonal mismatch shows.

**Ghostrunner (2020).** Two voices in the ear, the Architect (AI) and Zoe (rebel), who disagree; the plot is meant to run "without slowing down the action" ([TechRaptor](https://techraptor.net/gaming/reviews/ghostrunner-review), [TV Tropes Characters](https://tvtropes.org/pmwiki/pmwiki.php/Characters/Ghostrunner)). **Solar Ash (2021)** shows the failure case: reviewers split on Rei narrating every vista before you can ask ([PC Gamer](https://www.pcgamer.com/solar-ash-review/), [Kotaku](https://kotaku.com/solar-ash-the-kotaku-review-1848143937)).

**Rez / Thumper.** Rez tells its theme with almost no words; Thumper has "essentially no narrative" but still ships a recurring boss head that escalates each stage ([TV Tropes: Thumper](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/Thumper), [Wikipedia: Rez](https://en.wikipedia.org/wiki/Rez_(video_game))). Copyable: a recurring antagonist silhouette is narrative enough for an abstract game.

**Distance (2018).** Tron-like survival racer; Adventure mode is 1 to 1.5 hours, a "minimalist narrative" of atmosphere and a countdown on the rear window, alternating fast sectors with creepy strolls ([TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/Distance2018), [Young Folks review](https://www.theyoungfolks.com/video-games/125593/refract-studios-distance-ver-1-0-review-early-access-game-release-kickstarter/)). Directly comparable tone to this project.

**Hades (2020).** Bosses remember who won last time; the game checks mid-run conditions (e.g. low health when meeting a character) and picks a pre-written line; Kasavin: "reactivity... those moments where you feel the game is paying attention" ([Game Developer](https://www.gamedeveloper.com/design/how-supergiant-weaves-narrative-rewards-into-i-hades-i-cycle-of-perpetual-death), [GDC podcast](https://gdconf.com/article/roguelikes-and-narrative-design-with-hades-creative-director-greg-kasavin-gdc-podcast-ep-16/)).

**Hotline Miami (2012).** Answering-machine messages assign each job in euphemism; the apartment changes between levels; short post-level errands (pizza, video store) do the unreliable-narrator work ([Wikipedia](https://en.wikipedia.org/wiki/Hotline_Miami), [Game Developer](https://www.gamedeveloper.com/design/why-hotline-miami-is-an-important-game)).

**Road 96 (2021).** Procedural road trip built from character-centred "building blocks" over two years; "the story is sustained by them" ([Game Developer](https://www.gamedeveloper.com/design/road-96-the-narrative-system-history-of-the-development-and-inspirations), [Vice](https://www.vice.com/en/article/the-building-block-storytelling-of-road-96/)).

**Mario Kart (contrast).** No story mode in any entry; the cup/Grand Prix ladder is the entire frame ([GameFAQs Q&A](https://gamefaqs.gamespot.com/switch/200276-mario-kart-8-deluxe/answers/612570-is-there-a-story)). **Slay the Spire (contrast):** Mega Crit cut loosely planned story because the fun was the loop ([Game Developer](https://www.gamedeveloper.com/game-platforms/road-to-the-igf-mega-crit-games-i-slay-the-spire-i-)).

### 6.2 Cross-cutting patterns

- **(a) Story without stopping.** Radio/handler voice (GTA, Burnout, Pacific Drive, Ghostrunner), passenger banter (Driver SF, Mad Max), degraded or misleading comms as mystery (Tron 2.0), and reactive one-liners triggered by game state that vanish unread (Into the Breach: "you don't have to read it to understand the game", [Cloudfall](https://www.cloudfallstudios.com/blog/2018/3/3/what-i-learned-into-the-breach-and-narrative-through-dialogue), [Kotaku](https://kotaku.com/into-the-breach-tells-its-story-through-its-characters-1824159682)). Overuse is the documented failure (Solar Ash).
- **(b) Contact webs vs chapters.** GTA runs several givers concurrently so order feels chosen; F-Zero GX, Wipeout 2048 and Art of Rally use strictly linear chapters/seasons. Death Rally and NFSU2 sit between: a linear ladder with optional side offers/sponsors.
- **(c) Rival arcs and boss races.** Most Wanted's Blacklist, Death Rally's Adversary, F-Zero's Goroh then Deathborn, Sebulba, Thumper's head. The pattern: a visible ladder, a personal theft/insult as stake, a hidden boss above the boss, and bosses that remember (Hades).
- **(d) Job board / phone.** Pager (GTA III), SMS (NFSU2), answering machine (Hotline Miami), garage radio (Pacific Drive). The device doubles as tutorial and unlock notice, so it pays for itself.
- **(e) Between-run scenes.** Hotline Miami's apartment drift, Pacific Drive's garage, Hades' house. Hades demonstrates the strongest form (state-aware lines); Slay the Spire shows a loop that survives without any.
- **(f) Voice-less indie narrative.** Portraits + short text (Into the Breach), team bios and era text (Wipeout, Art of Rally, BallisticNG), a late-added narrator (Sayonara). Simogo's narrator came last and still defined the game's feel.
- **(g) Endings in 1-4 hour games.** Distance and Sayonara end on one structural payoff (the countdown source, the last card); Death Rally and Most Wanted end on the boss race the whole ladder pointed at. Hotline Miami's short scenes reframe what you did.
- **(h) Cheap agency.** Concurrent givers (GTA), sponsors you sign (NFSU2), payout schemes and shop choices (Racer), betting offers (Death Rally), the fork branch in Driver-style chases. None branch the plot; they branch the order and the economy.

### 6.3 Ranked devices for this project (impact per effort, as ranked by the research)

1. **Reactive comms lines keyed to game state** (Into the Breach / Hades model): 2-3 second HUD lines from the employer/rival on gate hit, near-miss, hull low, checkpoint respawn, rival lead change. The game has `ActionAck` stamps, `Debrief.swift` reactive lines and comms lines from pass 1; the gap is *mid-run* rival and employer reactions with a portrait chip. Text only, no audio.
2. **Rival memory across duels** (Hades): the rival intro already shows head-to-head records; add 2-3 lines per rival per record state ("third time, Kade") and a temper-driven taunt when you cut them off. Pure data.
3. **The inbox as the pager** (GTA III / NFSU2): unlock notices, sponsor-style optional side offers ("wreck ORIN this round for +200") and one cryptic message per chapter from an unseen "Guest"-style sender (Tron 2.0) that resolves in the finale. Reuses the inbox and credits.
4. **Chapter cards with one paragraph of era/league text** (Art of Rally / Wipeout 2048): three chapters already exist; add a title card and a 40-word line each, plus a rear-of-briefing "league standings".
5. **Portrait talk clips from iClone 8** at three moments only: briefing accept, result card, chapter end. Blend-shape-only or video-in-HUD as already noted; keep them under 4 s so they never gate a 2-5 minute job.
6. **A visible ladder to a hidden boss** (Most Wanted / F-Zero): show the three rivals' rank on the title/inbox; reveal a fourth (the employer, or the Grid itself) for the last duel. One extra rival config plus a reveal line.
7. **Between-job hub drift** (Hotline Miami apartment): let the briefing screen's background change per chapter (lighting, one prop, the rival's portrait state). Cheap in a procedural scene.
8. **A passenger/handler voice with degrading signal** (Mad Max / Tron 2.0) as a later, optional layer once phone mixing is settled; highest cost because it needs real VO and mix time.

Not sourced well enough to include: Rollcage's fiction beyond team names (only a retro DB and a forum thread), Wipeout 2097's Designers Republic contribution to lore, and any Redout 1 story detail. Mirror's Edge's in-run comms design is asserted only via Wikipedia's character summary.
