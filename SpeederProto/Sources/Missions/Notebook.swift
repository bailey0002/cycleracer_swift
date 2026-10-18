import Foundation

/// The notebook (assessment-2026-10-17-rd.md step 2, KERB's `Notebook.swift` ported): Thimbleweed Park's to-do list and
/// THPS's goal card merged. Each chapter carries five lines (`narrative.json` `notebook`, the Swift table below as the
/// fallback); a line ticks itself from state the game already persists and stays ticked (`note.<chapter>.<id>`).
/// Auto rules: `rank:<job>:<bronze|silver|gold>`, `flag:<job>:<clean|fast|gold>`, `offer:<id>` (a side offer paid),
/// `goal:<world>:<id>` (one goal-card line), `goals:<world>:<n>` (n lines of a world's card), `cleared:<job>`.
///
/// The goose rule (Untitled Goose Game's list): chapter n + 1 opens once chapter n is cleared **and** `need` of its lines
/// are ticked. It sits in `MissionRunner.isUnlocked` behind `notebookGate` (off in the game until Mark decides;
/// `SPEEDER_NOTE_GATE=1` and the headless test turn it on), so the side content is not optional in name only.
///
/// The hint line (Thimbleweed's 4468): CALL <contact> on the notebook page gives the first open line's hint, one step
/// plainer on each call (three per line, counter `hint.<chapter>.<id>`). Never offers a line for a chapter not reached.
/// Log lines: `NOTE tick ch=n id=… (k/m)`, `NOTE ch n complete`, `HINT ch=n id=… level=k`.
struct NoteSpec: Codable, Equatable {
    var id: String
    var text: String
    /// Three lines from the chapter's contact, vaguer to plainer.
    var hints: [String]? = nil
    var auto: String? = nil
}

struct NotebookChapter: Codable {
    var need: Int?
    var lines: [NoteSpec]?
}

final class Notebook {
    static let prefix = "note."
    static let hintPrefix = "hint."
    private let defaults: UserDefaults
    var logging = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let pre = ProcessInfo.processInfo.environment["SPEEDER_NOTE"] {
            for id in pre.split(separator: ",").map(String.init) {
                for c in 1...3 where Self.notes(chapter: c).contains(where: { $0.id == id }) { defaults.set(true, forKey: "\(Self.prefix)\(c).\(id)") }
            }
        }
    }

    // MARK: The lines

    static func notes(chapter c: Int) -> [NoteSpec] {
        if let l = Narrative.file?.notebook?["\(c)"]?.lines, !l.isEmpty { return l }
        return fallback[c]?.lines ?? []
    }
    static func need(chapter c: Int) -> Int { min(Narrative.file?.notebook?["\(c)"]?.need ?? fallback[c]?.need ?? 0, notes(chapter: c).count) }

    func isTicked(chapter c: Int, id: String) -> Bool { defaults.bool(forKey: "\(Self.prefix)\(c).\(id)") }
    func tickedCount(chapter c: Int) -> Int { Self.notes(chapter: c).filter { isTicked(chapter: c, id: $0.id) }.count }
    /// The chapter's lines are good enough for the gate.
    func satisfied(chapter c: Int) -> Bool { tickedCount(chapter: c) >= Self.need(chapter: c) }
    func items(chapter c: Int) -> [(text: String, done: Bool)] { Self.notes(chapter: c).map { ($0.text, isTicked(chapter: c, id: $0.id)) } }

    /// Tick a line by hand; true when it was open.
    @discardableResult
    func tick(chapter c: Int, id: String) -> Bool {
        guard Self.notes(chapter: c).contains(where: { $0.id == id }), !isTicked(chapter: c, id: id) else { return false }
        defaults.set(true, forKey: "\(Self.prefix)\(c).\(id)")
        if logging { print("NOTE tick ch=\(c) id=\(id) (\(tickedCount(chapter: c))/\(Self.notes(chapter: c).count))") }
        return true
    }

    /// Re-evaluate every auto rule of chapters 1...`upTo` against the stored progress; returns the lines that just
    /// ticked, and logs a chapter's completion (its `need` reached) once.
    @discardableResult
    func sync(upTo chapter: Int) -> [(chapter: Int, note: NoteSpec)] {
        var out: [(Int, NoteSpec)] = []
        for c in 1...max(1, min(3, chapter)) {
            let wasSatisfied = satisfied(chapter: c)
            for n in Self.notes(chapter: c) where !isTicked(chapter: c, id: n.id) {
                guard let rule = n.auto, isMet(rule) else { continue }
                tick(chapter: c, id: n.id)
                out.append((c, n))
            }
            if !wasSatisfied && satisfied(chapter: c) && logging { print("NOTE ch \(c) complete (\(tickedCount(chapter: c))/\(Self.need(chapter: c)) needed)") }
        }
        return out
    }

    /// One auto rule against the stored progress keys (the runner's, the goal card's, the offers').
    func isMet(_ rule: String) -> Bool {
        let p = rule.split(separator: ":").map(String.init)
        guard let kind = p.first else { return false }
        switch kind {
        case "rank":
            guard p.count == 3, let job = Int(p[1]) else { return false }
            let need = ["bronze": 1, "silver": 2, "gold": 3][p[2]] ?? 1
            return defaults.integer(forKey: "rank.\(job)") >= need
        case "flag":
            guard p.count == 3, let job = Int(p[1]) else { return false }
            let bit = ["clean": 1, "fast": 2, "gold": 4][p[2]] ?? 0
            return bit != 0 && defaults.integer(forKey: "flags.\(job)") & bit != 0
        case "offer":
            guard p.count == 2 else { return false }
            return defaults.bool(forKey: "offer.\(p[1]).done")
        case "goal":
            guard p.count == 3 else { return false }
            return defaults.bool(forKey: "\(GoalCard.prefix)\(p[1]).\(p[2])")
        case "goals":
            guard p.count == 3, let n = Int(p[2]) else { return false }
            return GoalCard.doneCount(world: p[1], defaults: defaults) >= n
        case "cleared":
            guard p.count == 2, let job = Int(p[1]) else { return false }
            return defaults.integer(forKey: MissionRunner.clearedMaskKey) & (1 << job) != 0
        default:
            return false
        }
    }

    // MARK: The hint line

    /// The contact's line for the first open note of `chapter`; each call moves one step plainer.
    func hint(chapter c: Int) -> (note: NoteSpec, text: String, level: Int)? {
        guard let n = Self.notes(chapter: c).first(where: { !isTicked(chapter: c, id: $0.id) && !($0.hints ?? []).isEmpty }),
              let hints = n.hints else { return nil }
        let key = "\(Self.hintPrefix)\(c).\(n.id)"
        let level = min(defaults.integer(forKey: key), hints.count - 1)
        defaults.set(level + 1, forKey: key)
        if logging { print("HINT ch=\(c) id=\(n.id) level=\(level)") }
        return (n, hints[level], level)
    }

    // MARK: Fallback (narrative.json carries the same lines)

    static let fallback: [Int: NotebookChapter] = [
        1: NotebookChapter(need: 3, lines: [
            NoteSpec(id: "first_goal", text: "Tick a goal on the Neon City card.",
                     hints: ["The city keeps a list. Read it.", "Pause. GOAL CARD. Pick the easy one.", "Shoot ten targets in one run. That is a goal."], auto: "goals:city:1"),
            NoteSpec(id: "clean_disc", text: "Carry the first disc without a scratch.",
                     hints: ["The first job. Again. Better.", "No hits on RELAY 01. Not one.", "Replay RELAY 01 from the inbox. Hug the middle lane, shoot what blocks it."], auto: "flag:0:clean"),
            NoteSpec(id: "sweep_silver", text: "Silver or better on the beacon sweep.",
                     hints: ["The rings remember who missed them.", "SWEEP 01. Silver needs the streak.", "Take every ring on SWEEP 01 without a hit between them."], auto: "rank:1:silver"),
            NoteSpec(id: "tail_fast", text: "Shake the tail with a third of the window left.",
                     hints: ["Being ahead is not the same as being fast.", "RUN 01, FAST flag. Boost early.", "Boost off the line on RUN 01 and again past halfway. Keep a third of the clock."], auto: "flag:3:fast"),
            NoteSpec(id: "tunnel_line", text: "Ride Kade's tunnel line.",
                     hints: ["Someone wants THE SPLIT done their way.", "Clean on RELAY 02 puts an offer in the inbox.", "Clear RELAY 02 with no hits, then take SIDE 01 and stay left at the split."], auto: "offer:0"),
        ]),
        2: NotebookChapter(need: 3, lines: [
            NoteSpec(id: "outlands_clean", text: "Cross the Outlands without a scratch.",
                     hints: ["The canyon forgives nothing. Forgive it back.", "RELAY 04, no hits.", "Replay RELAY 04. Stay low under the arches, shoot what blocks the lane."], auto: "flag:6:clean"),
            NoteSpec(id: "canyon_silver", text: "Silver on the canyon sweep.",
                     hints: ["The high rings pay.", "SWEEP 02, silver. Climb for the red ones.", "Climb before each high ring on SWEEP 02; a hit between rings resets the streak."], auto: "rank:7:silver"),
            NoteSpec(id: "convoy_gold", text: "Gold on the convoy.",
                     hints: ["Kade counts the wrecks.", "SALVAGE 01, gold. Every target.", "Fire early on SALVAGE 01: all eight targets, no hits, the streak does the rest."], auto: "flag:8:gold"),
            NoteSpec(id: "pipe_dark", text: "Run Orin's pipe, dark.",
                     hints: ["Orin has a faster idea.", "FAST on RUN 02 opens SIDE 02.", "Clear RUN 02 with a third of the window left, then take SIDE 02 from the inbox."], auto: "offer:1"),
            NoteSpec(id: "canyon_goals", text: "Four goals on the Sunset Canyon card.",
                     hints: ["The canyon has its own list.", "Pause. GOAL CARD in the canyon.", "Free play counts: ride the canyon and do the easy four."], auto: "goals:canyon:4"),
        ]),
        3: NotebookChapter(need: 3, lines: [
            NoteSpec(id: "double_fast", text: "Out-run the double cross with time to spare.",
                     hints: ["Speed is the only alibi.", "RUN 03, FAST.", "Boost through the first conduit on RUN 03 and keep a third of the clock."], auto: "flag:12:fast"),
            NoteSpec(id: "crates_silver", text: "Silver on Sable's crates.",
                     hints: ["Sable counts too.", "SALVAGE 02, silver.", "Twelve crates on SALVAGE 02 with the streak unbroken by hits."], auto: "rank:13:silver"),
            NoteSpec(id: "deep_clean", text: "Dive the deep line without a scratch.",
                     hints: ["The pipe bruises double.", "DIVE 02, no hits.", "Replay DIVE 02; ride the centre of each pipe and do not boost into the bends."], auto: "flag:14:clean"),
            NoteSpec(id: "whole_ledger", text: "Take the whole ledger.",
                     hints: ["Ten beacons. Sable wants ten.", "GOLD on SALVAGE 02 opens SIDE 03.", "Gold on SALVAGE 02, then SIDE 03: all ten rings on SWEEP 03."], auto: "offer:2"),
            NoteSpec(id: "grid_goals", text: "Five goals on The Grid card.",
                     hints: ["The Grid keeps score of more than rounds.", "Pause on the Grid. GOAL CARD.", "Free play on The Grid counts. Grind a wall, take three pads, win a round."], auto: "goals:grid:5"),
        ]),
    ]
}
