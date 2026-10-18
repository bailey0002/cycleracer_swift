# Kickoff prompt for the next thread: step 2 of the R&D plan (written 17 Oct 2026, late)

Paste the block below as the first message of a new Claude Code thread opened in
`/Users/markbailey/Desktop/GS - GamenCtr/GS - Racer`.

**State at close of the last thread (17 Oct 2026).** master = PR #10. Merged today, in order: PR #8 (the current-state
GDD `GDD_2026-10-17.md` + its interactive map `docs/gdd-map.html`), PR #9 (the R&D deep dive
`SpeederProto/docs/assessment-2026-10-17-rd.md` with the four research reports in `docs/research-2026-10-17-reports.md`),
PR #10 (step 1 of that plan: `Resources/narrative.json` holding every story line, `Missions/Narrative.swift` loading it
with the Swift tables as fallback; the three nouns on the cards: the **disc**, the **I/O Line**, the **broken rule**;
the board ASTRO and the four riders speak on the comms lane; GRIPTAP & CO's interludes in the message log).
PR #7 `claude/garage` (the helix garage, wider arena camera, aqua / blue trails) is still **open**, installed on the
iPhone 12 and not yet judged; its branch also carries `STATUS.md` and the `.gitignore` / CLAUDE.md workspace block.
Phones: the iPhone 12 (1438FC4B-510E-5302-9AAE-0833BC5A856F) was unreachable over Wi-Fi on 17 Oct; the Release build of
PR #10 went to the iPhone 16e (EE203F95-3B89-57F4-94F6-2D6B5E209423, paired). Nothing from PR #8–#10 has been judged
on a phone. The seven decisions in PR #9's description (the nouns, the Donny, the talking board, duel stakes, step
order, the ending choice, Photos permission) are still Mark's; step 1 assumed yes on the nouns and the board.

---

Read `CLAUDE.md` in this workspace first, then `GDD_2026-10-17.md` §2–§3 and §8–§9, then
`SpeederProto/docs/assessment-2026-10-17-rd.md` §3 (what ports from KERB Skate), §7 (where each piece lives), §8 (the
build order) and §9 (the workstreams), then the last section of `SpeederProto/docs/polish-log.md` ("Step 1 of the R&D
plan"). The sibling's code to port is readable from here: `../kerb_skate_game/KerbSkate/Game/Guidance.swift`,
`Notebook.swift`, `GoalCard.swift`, `Barks.swift` and `Assets/barks.json`, with its design in
`../kerb_skate_game/RESEARCH_STORY_2026-10-17.md` §3.3, §4.2, §10 and its `DECISIONS.md` entries of 2026-10-17.

**0. Branch and build.** `git checkout master && git pull`, then branch `claude/guidance` off master. `cd SpeederProto
&& xcodegen generate` (new files need it or the bundle silently lacks them), the Mac build from `CLAUDE.md`, and the
tests: `xcodebuild test -scheme SpeederProto-macOS -derivedDataPath build-tests ...` (15 tests, all green at close).
Decide PR #7 first if Mark has judged it: merge it (then rebase) or leave it; steps 4 and 5 build on its garage.

**1. Step 2: port KERB's four systems** (assessment §3, §7.2; report D in the research file for the seams).
- **Guidance** (`Missions/Guidance.swift`): rule cards once each, the world waits, Ⓐ dismisses (`MissionRunner.allowsMotion`
  already parks the world; the chapter card is the once-card precedent, `needsChapterCard` / `chapter.seen.<n>`); a cue
  lane with cooldown and per-run cap built over `GameController.commsSlots` / `sideComms`; FULL / LIGHT / OFF on the
  pause menu and SETTINGS, persisted as `prefs.guidance`. Cards for: how to ride (speeder and board), each of the six job
  kinds, the Grid, the first hit, the first respawn, the garage, the inbox, a side offer. Copy lives in
  `narrative.json` (add a `guidance` block), plain words, every line names a button the way the HUD shows it. Demo
  mode's pulsed accept must dismiss cards (a held accept has no edge).
- **Notebook** (`Missions/Notebook.swift`): per-chapter lines (four to six) auto-ticked from persisted state
  (`rank.<job>`, `flags.<job>`, `offer.<id>.done`, the new `goal.*` keys), `needNotes` of them plus the chapter's duel
  to open the next chapter (extend `MissionRunner.isUnlocked`; the headless `testUnlockOrderInsideAChapter` must still
  pass, so add the gate behind a flag the test sets); a hint ladder (three lines per note, vaguer to plainer) on the
  pause menu ("CALL <contact>", hold Ⓨ); the page on the pause menu and the briefing. Lines and hints in `narrative.json`.
- **GoalCard** (`Missions/GoalCard.swift`): nine persistent goals per world (score tiers, a combo-free equivalent: a
  gold on each kind, clean runs, a sweep with every beacon, a duel sweep, a match won in free play, credits earned),
  each paying once (`goal.<world>.<id>`), shown on the briefing under the garage and on the pause menu; arena goals read
  `ArenaController.MatchResult` through `GameController` (where `missions.award(r.credits)` runs).
- **Barks** are already half there: `LinePicker` and `GameController.say` (the board and the riders). Finish it as
  KERB's `Barks`: event ids in `narrative.json` for the contact too (gate streak, hull low, respawn, last stretch,
  beacon missed), per-chapter overrides, chance; the announcer's `announcePool` is the picker to reuse for voice later.
- **Every new progress key goes into `SaveSlot.exactKeys` / `prefixes`** or the manual save drops it and the fresh-start
  clear leaves it behind. One headless test per system (`Tests/MissionLoopTests.swift`).

**2. Proof, the standing rule.** Simulator sheets (`Captures/polish/simshot.sh`, `SPEEDER_SCREEN=` and
`SPEEDER_HOLD_BRIEFING=1`) of every card and the notebook page; `GUIDE` / `NOTE` / `GOAL` log lines in a
`SPEEDER_DEMO=1` capture (`Captures/polish/capture.sh`, folder `Captures/polish/p20/`); the tests green; a Release build
on whichever phone is reachable (`xcrun devicectl list devices`; the install succeeds on a locked phone, the launch
needs it unlocked). Then `docs/polish-log.md` (a "Step 2" section), the GDD's tags (§9 Guidance becomes BUILT CAPTURED,
§8.4 collectibles / goals), the map's `ELEMENTS` and `data-s` / `chips()` tags in `docs/gdd-map.html` (CLAUDE.md rule),
a commit on the branch, a PR.

**3. After step 2** (assessment §8): step 3 objectives and clue beats (letters, checkpoint stars with posted times,
trick-over-object, heat escape, tag the district; the kiosk pass-by, the billboard clue, lane-as-dialogue, exclusive
offers) → step 4 the Grid ladder (`MatchRules`, `ArenaLayout`, the Blacklist, stakes, Heat, the Donny's ghost; this is
where the two cut card promises return) → step 5 the look → step 6 rewards and screens → step 7 the daily job. From
step 3 on, the five workstreams of §9 can run as parallel sessions, one writer per file (the HUD stream owns
`HUDView`, the missions stream owns `MissionRunner`).

**4. Gotchas from the last thread.** `narrative.json` is the source of every line; the Swift tables are fallback only
(`SPEEDER_NARRATIVE=0` for A / B) and `Narrative.fill` handles `{hits}` / `{section}` / `{wins}` / `{losses}`. The comms
lane is one slot: the contact first, the rival second (`rivalComms`), the board and the riders behind both
(`sideComms`), never over a stamp. Cards must not promise rules the code lacks (two were cut from DUEL 01 / DUEL 04).
The HUD VStack clips silently at 390 pt: cards and pages must scroll. Everything else in `CLAUDE.md`.

Work the way the previous threads did: build, verify with captures and the tests, push to the phone, document in
`docs/polish-log.md` and `CLAUDE.md`, keep the GDD and the map's tags in step, commit on a branch, open a PR.
