import Foundation

/// Barks (assessment-2026-10-17-rd.md step 2, KERB's `Barks.swift` finished on top of step 1's `LinePicker` and
/// `GameController.say`): one-line rider and board lines keyed to run events, on the comms lane behind the contact
/// and the rival. Every line comes from a named voice: the rider (lines per rider id, else the shared ones), the board
/// (ASTRO, the Kerbie Astro, only on the hoverboard). Bastion's rule: never play-by-play, so every event has a cooldown,
/// a per-run cap and sometimes a chance, and variants never repeat the last one (`LinePicker`). A bark with a
/// `chapter` wins over the generic one in that chapter. The tuning lives in `narrative.json` (`barks`); the lines of
/// the step 1 events (launch, hit, trick, boost, derez, respawn) stay in `board` / `riders`, and the table below is the
/// fallback. `BARK <id> <voice>: <text>` log lines; `SPEEDER_BARKS=0` mutes.
struct BarkSpec: Codable, Equatable {
    var id: String
    var voice: String               // "rider" | "board"
    var chapter: Int? = nil
    var cooldown: Float? = nil
    var perRun: Int? = nil
    var chance: Float? = nil
    var lines: [String]? = nil
    /// Rider voice: lines per rider id ("cal", "dude1", ...); `lines` (then the riders' table) is the fallback.
    var riders: [String: [String]]? = nil
}

final class Barks {
    private let picker = LinePicker()
    private let specs: [BarkSpec]
    var muted = ProcessInfo.processInfo.environment["SPEEDER_BARKS"] == "0"
    var logging = false
    /// The chance roll, replaceable in tests.
    var roll: () -> Float = { Float.random(in: 0..<1) }

    init(specs: [BarkSpec]? = nil) {
        self.specs = specs ?? Narrative.file?.barks ?? Self.fallback
    }

    func startRun() { picker.startRun() }

    /// The spec for `id` in `chapter`: the chapter's own, else the generic one.
    func spec(_ id: String, chapter: Int) -> BarkSpec? {
        specs.first { $0.id == id && $0.chapter == chapter } ?? specs.first { $0.id == id && $0.chapter == nil }
    }

    /// The speaker and line for `id` if one may be said now. `now` = scene time (cooldowns), `onBoard` = the board can talk.
    func fire(_ id: String, chapter: Int, rider: String, riderName: String, onBoard: Bool, now: Float) -> (speaker: String, text: String)? {
        guard !muted, let b = spec(id, chapter: chapter) else { return nil }
        var pool: [String]
        let speaker: String
        switch b.voice {
        case "board":
            guard onBoard else { return nil }
            speaker = Narrative.boardName
            pool = b.lines ?? Narrative.boardLines(id)
        default:
            speaker = riderName
            pool = b.riders?[rider] ?? b.lines ?? Narrative.riderLines(rider, id)
            if pool.isEmpty { pool = Narrative.riderLines(rider, id) }
        }
        guard !pool.isEmpty else { return nil }
        if let c = b.chance, c < 1, roll() > c { return nil }
        let key = "\(id)#\(b.chapter ?? 0)"
        guard let text = picker.pick(key, from: pool, now: now, cooldown: b.cooldown ?? 8, cap: b.perRun ?? 2) else { return nil }
        if logging { print("BARK \(id) \(b.voice): \(text)") }
        return (speaker, text)
    }

    // MARK: Fallback (narrative.json carries the same table)

    static let fallback: [BarkSpec] = [
        BarkSpec(id: "launch", voice: "rider", cooldown: 1, perRun: 1),
        BarkSpec(id: "launch", voice: "rider", chapter: 3, cooldown: 1, perRun: 1,
                 lines: ["The core. Nobody's provisional in here.", "Last district. Ride it like it's yours."]),
        BarkSpec(id: "hit", voice: "board", cooldown: 14, perRun: 2),
        BarkSpec(id: "trick", voice: "rider", cooldown: 10, perRun: 3),
        BarkSpec(id: "boost", voice: "board", cooldown: 20, perRun: 1),
        BarkSpec(id: "derez", voice: "rider", cooldown: 1, perRun: 1),
        BarkSpec(id: "respawn", voice: "board", cooldown: 1, perRun: 1),
        BarkSpec(id: "streak", voice: "rider", cooldown: 30, perRun: 1,
                 lines: ["Five clean. Don't jinx it.", "That's a line. Keep it.", "Nobody touch me."]),
        BarkSpec(id: "beacon", voice: "board", cooldown: 12, perRun: 2, chance: 0.5,
                 lines: ["Ring's in.", "Counted.", "Red one. Got it."]),
        BarkSpec(id: "kill", voice: "board", cooldown: 15, perRun: 2, chance: 0.4,
                 lines: ["Scrap.", "That one won't block anybody.", "Photons work."]),
        BarkSpec(id: "hull_low", voice: "board", cooldown: 30, perRun: 1,
                 lines: ["We're riding on paint now.", "One more and I'm a coaster."]),
        BarkSpec(id: "time_low", voice: "rider", cooldown: 30, perRun: 1,
                 lines: ["Clock's eating me.", "Gates. I need gates."]),
        BarkSpec(id: "goal", voice: "rider", cooldown: 20, perRun: 2,
                 lines: ["That's one for the card.", "Put that on the list."]),
        BarkSpec(id: "round_won", voice: "rider", cooldown: 20, perRun: 2,
                 lines: ["One down.", "Didn't see the turn, did you."]),
    ]
}
