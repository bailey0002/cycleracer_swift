# Kickoff prompt for the next thread: step 3 of the R&D plan (written 18 Oct 2026)

Paste the block below as the first message of a new Claude Code thread opened in
`/Users/markbailey/Desktop/GS - GamenCtr/GS - Racer`.

**State at close of the last thread (18 Oct 2026).** master = PR #13. Merged that day: PR #12 (step 2: KERB's
Guidance / Notebook / GoalCard / Barks ported, 19 headless tests; Mark's notes: the **hoverboard is the default
vehicle**, cards are **LIGHT, a muted grey with dark ink**) and PR #13 (TestFlight prep: bundle id
**`com.greystratum.kerbgalactic`**, version 0.1.0, encryption flag, opaque icon). Mark created the App Store Connect
record; the archive `testflight/build/SpeederProto-iOS-202610182141` waits for **his** upload with his API key (README
"TestFlight"), then the KERB Skate testers go into this app's own TestFlight group. PR #7 `claude/garage` is still open
and unjudged. Phones: iPhone 16e (EE203F95-3B89-57F4-94F6-2D6B5E209423) has the step 2 build under the old bundle id;
iPhone 12 (1438FC4B-510E-5302-9AAE-0833BC5A856F) is paired too. Nothing from steps 1–2 has been judged on a phone yet.
Mark's open calls: the goose gate (`MissionRunner.notebookGate`, off), and the seven decisions in PR #9's description.
Mark assumes a **controller** (the Backbone) for everything for now: no touch wording or touch controls.

---

Read `CLAUDE.md` in this workspace first, then `GDD_2026-10-17.md` §8–§9, then
`SpeederProto/docs/assessment-2026-10-17-rd.md` §4.1 (objective shapes), §4.2 (hazards), §4.4 (clues and people in a
corridor), §7 (where each piece lives) and §8 (step 3), then the last two sections of `SpeederProto/docs/polish-log.md`
("Step 2" and "TestFlight prep"). Ask Mark first how the step 2 build played on the phone; fold his notes in before
step 3, and update the GDD tags and the map's `ELEMENTS` / `data-s` / `chips()` together if any change.

**0. Branch and build.** `git checkout master && git pull --ff-only`, branch `claude/objectives` off master,
`cd SpeederProto && xcodegen generate`, the Mac build from `CLAUDE.md`, and the tests (19 green at close).

**1. Step 3: objectives and clues** (assessment §8 row 3, §4.1 / §4.4).
- **Letters on the line**: R-O-U-T-E glyphs on a job's climb and boost lines (a `BeaconLayer` variant); all five in one
  run earns a flag, a goal-card line and a notebook tick.
- **Checkpoint stars with posted times**: three split times per job (KADE / ORIN / SABLE's), shown on the briefing and
  stamped at each checkpoint; the ghost actor is optional this step.
- **Trick over object** (board jobs): "360 through the gateway", "barrel roll the overpass" against the landmark
  dressings; tricks feed the hull with repeat decay.
- **Heat escape**: hits raise the pursuer's speed, a kiosk branch sheds heat, the GAP bar takes a heat tint.
- **Tag the district**: a search with any-order markers spread laterally.
- The clue beats of §4.4: the kiosk pass-by (three seconds, skippable), the billboard clue, lane-as-dialogue,
  exclusive offers (a mutual lock between two side offers), the three-fragment gate.
- A rule card per new kind (`Guidance.cards` + `narrative.json`), goal-card and notebook lines where they fit; every
  line in `narrative.json`; every new progress key in `SaveSlot.prefixes`.

**2. Proof, the standing rule.** One headless test per new kind; `capture.sh` of the kiosk branch and the letters
(`SPEEDER_CAMERA=overview` for layout); simulator sheets of every new card (`Captures/polish/p20/sheets.sh` is the
pattern, copy it to `p21/`; `swift Tools/contact-sheet.swift` tiles them; commit the contact sheets, not the raw
3.5 MB shots); a Release build on the 16e (new bundle id); `docs/polish-log.md` "Step 3"; the GDD's tags and the map's
together; a commit on the branch, a PR. A TestFlight build only when Mark asks (`ship.sh`, then his upload).

**3. Gotchas from the last thread.** A rule card holds `MissionRunner.update`, so the headless balance loop rides with
guidance OFF (`HeadlessLoop.freshRunner(guidance:)`); one card per briefing look (`briefingCardShown`). Cards use
`HUDView`'s `ink` / `cardAccent` / `tone()` on the grey `paper`, never `.white` on black. The pause list scrolls; pages
must fit 390 pt (the goal page needed tighter lines). The demo rides the speeder unless `SPEEDER_VEHICLE=board`. A
capture log that stops early is usually GPU contention from another simulator app, not a hang. The Swift tables are a
fallback only; `narrative.json` is the source.

Work the way the previous threads did: build, verify with captures and the tests, push to the phone, document in
`docs/polish-log.md` and `CLAUDE.md`, keep the GDD and the map's tags in step, commit on a branch, open a PR.
