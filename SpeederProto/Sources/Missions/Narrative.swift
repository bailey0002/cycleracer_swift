import Foundation

/// Every line of story text, from `Resources/narrative.json` (assessment-2026-10-17-rd.md, step 1): job briefs and
/// debriefs, side offers, chapter intros, the unseen sender, the contacts' comms and reactive lines, failures,
/// taunts, round lines, roles, the board's lines (the Kerbie Astro, Cloudpunk's talking car) and the riders' own
/// lines. The Swift tables in `Mission.swift`, `Debrief.swift` and `MessageLog.swift` stay as the fallback: every
/// lookup here returns nil when the key is missing, so a half-written file never blanks a card and the headless
/// tests run with or without the bundle. `{hits}`, `{section}`, `{wins}`, `{losses}` are filled by `fill`.
/// `SPEEDER_NARRATIVE=0` ignores the file (the Swift tables alone, for A / B captures).
struct NarrativeFile: Codable {
    struct Job: Codable { var brief: String?; var debrief: String? }
    struct Offer: Codable { var line: String?; var debrief: String? }
    struct Chapter: Codable { var intro: String?; var `static`: String?; var interlude: [String]?; var ending: String? }
    struct Board: Codable {
        var name: String?
        var launch: [String]?; var hit: [String]?; var trick: [String]?; var boost: [String]?; var derez: [String]?; var respawn: [String]?
    }
    struct RiderLines: Codable { var launch: [String]?; var hit: [String]?; var trick: [String]?; var derez: [String]? }
    /// A round line is one string or a rotation of several.
    enum Lines: Codable {
        case one(String), many([String])
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let s = try? c.decode(String.self) { self = .one(s) } else { self = .many(try c.decode([String].self)) }
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self { case .one(let s): try c.encode(s); case .many(let a): try c.encode(a) }
        }
        var all: [String] { switch self { case .one(let s): return [s]; case .many(let a): return a } }
    }

    var version: Int?
    var nouns: [String: String]?
    var jobs: [String: Job]?
    var offers: [String: Offer]?
    var chapters: [String: Chapter]?
    var comms: [String: [String: String]]?
    var reactive: [String: [String: [String]]]?
    var branch: [String: [String: String]]?
    var failure: [String: [String: String]]?
    var taunts: [String: [String: String]]?
    var roundLines: [String: [String: Lines]]?
    var roles: [String: String]?
    var board: Board?
    var riders: [String: RiderLines]?
    // step 2: guidance, the notebook, the goal cards, the barks
    struct GuideCard: Codable { var title: String?; var lines: [String]? }
    struct GuidanceText: Codable { var cards: [String: GuideCard]?; var cues: [String: String]? }
    var guidance: GuidanceText?
    var notebook: [String: NotebookChapter]?
    var goals: [String: [GoalSpec]]?
    var barks: [BarkSpec]?
}

enum Narrative {
    static let file: NarrativeFile? = {
        let env = ProcessInfo.processInfo.environment
        if env["SPEEDER_NARRATIVE"] == "0" { return nil }
        guard let url = Bundle.main.url(forResource: "narrative", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { print("Narrative: narrative.json missing, Swift tables only"); return nil }
        do {
            let f = try JSONDecoder().decode(NarrativeFile.self, from: data)
            print("Narrative: v\(f.version ?? 0), \(f.jobs?.count ?? 0) jobs, \(f.chapters?.count ?? 0) chapters, \(f.riders?.count ?? 0) riders, \(f.guidance?.cards?.count ?? 0) cards, \(f.goals?.count ?? 0) goal cards, \(f.barks?.count ?? 0) barks")
            return f
        } catch { print("Narrative: decode failed: \(error)"); return nil }
    }()

    /// `{key}` placeholders filled from `values`; unknown keys are left as they are.
    static func fill(_ s: String, _ values: [String: String]) -> String {
        var out = s
        for (k, v) in values { out = out.replacingOccurrences(of: "{\(k)}", with: v) }
        return out
    }

    /// A per-contact table with a `*` default: the contact's entry, else the default's.
    private static func pick<T>(_ table: [String: [String: T]]?, _ who: String, _ key: String) -> T? {
        table?[who]?[key] ?? table?["*"]?[key]
    }

    // MARK: Jobs, offers, chapters

    static func brief(_ job: Int) -> String? { file?.jobs?["\(job)"]?.brief }
    static func debrief(_ job: Int) -> String? { file?.jobs?["\(job)"]?.debrief }
    static func offerLine(_ id: Int) -> String? { file?.offers?["\(id)"]?.line }
    static func offerDebrief(_ id: Int) -> String? { file?.offers?["\(id)"]?.debrief }
    static func chapterIntro(_ c: Int) -> String? { file?.chapters?["\(c)"]?.intro }
    /// Chapters 1...3, or "end" for the line after the arc.
    static func staticLine(_ c: Int) -> String? { file?.chapters?[c > 3 ? "end" : "\(c)"]?.static }
    static func interlude(_ c: Int) -> [String]? { file?.chapters?[c > 3 ? "end" : "\(c)"]?.interlude }
    static var endingLine: String? { file?.chapters?["end"]?.ending }
    static func noun(_ key: String) -> String? { file?.nouns?[key] }

    // MARK: Contacts

    static func comms(_ contact: String, _ trigger: String, section: String) -> String? {
        pick(file?.comms, contact, trigger).map { fill($0, ["section": section]) }
    }
    static func midway(_ kind: String) -> String? { pick(file?.comms, "midway", kind) ?? file?.comms?["midway"]?["*"] }
    static func reactive(_ contact: String, _ key: String) -> [String]? { pick(file?.reactive, contact, key) }
    static func branch(_ contact: String, tunnel: Bool) -> String? { pick(file?.branch, contact, tunnel ? "tunnel" : "skyway") }
    static func failure(_ contact: String, cause: String) -> String? {
        file?.failure?["*"]?[cause] ?? file?.failure?[contact]?[cause] ?? file?.failure?[contact]?["*"] ?? file?.failure?["*"]?["*"]
    }
    static func taunt(_ rival: String, _ key: String) -> String? { pick(file?.taunts, rival, key) }
    static func roundLine(_ rival: String, _ key: String) -> [String]? { pick(file?.roundLines, rival, key)?.all }
    static func role(_ name: String) -> String? { file?.roles?[name] ?? file?.roles?["*"] }

    // MARK: The board and the riders

    static var boardName: String { file?.board?.name ?? "ASTRO" }
    static func boardLines(_ event: String) -> [String] {
        guard let b = file?.board else { return [] }
        switch event {
        case "launch": return b.launch ?? []
        case "hit": return b.hit ?? []
        case "trick": return b.trick ?? []
        case "boost": return b.boost ?? []
        case "derez": return b.derez ?? []
        case "respawn": return b.respawn ?? []
        default: return []
        }
    }
    static func riderLines(_ rider: String, _ event: String) -> [String] {
        guard let r = file?.riders?[rider] else { return [] }
        switch event {
        case "launch": return r.launch ?? []
        case "hit": return r.hit ?? []
        case "trick": return r.trick ?? []
        case "derez": return r.derez ?? []
        default: return []
        }
    }
}

/// Picks one line from a pool without repeating the last one said for that key, and rate-limits each key
/// (KERB's `Barks`): a cooldown in seconds and a cap per run.
final class LinePicker {
    private var last: [String: Int] = [:]
    private var lastAt: [String: Float] = [:]
    private var perRun: [String: Int] = [:]

    func startRun() { perRun = [:] }

    func pick(_ key: String, from pool: [String], now: Float, cooldown: Float, cap: Int) -> String? {
        // a bark's chance is rolled by the caller (`Barks.fire`) before the pick, so a miss spends no cooldown
        guard !pool.isEmpty else { return nil }
        if let t = lastAt[key], now - t < cooldown { return nil }
        if perRun[key, default: 0] >= cap { return nil }
        var i = Int.random(in: 0..<pool.count)
        if pool.count > 1, let l = last[key], l == i { i = (i + 1) % pool.count }
        last[key] = i; lastAt[key] = now; perRun[key, default: 0] += 1
        return pool[i]
    }
}
