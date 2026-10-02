import Foundation

/// Manual save (2 Oct 2026). Every launch is a fresh start: the live progress keys are cleared before the
/// mission runner reads them, so the riders page and the Griptap & Co opening play every time. SAVE GAME
/// (the pause menu, SETTINGS) snapshots the live progress into one slot; CONTINUE on the title loads it
/// back. Player settings (`prefs.*`) are not progress and never move.
enum SaveSlot {
    static let slotKey = "save.slot"
    static let timeKey = "save.time"
    /// Exact keys that make up a run's progress (identity included: the save is the whole rider).
    private static let exactKeys = ["credits", "missionIndex", "cleared", MissionRunner.clearedMaskKey, Upgrades.key,
                                    "callsign", "livery", Roster.key, "story.seen", MessageLog.key, MessageLog.readKey]
    private static let prefixes = ["rank.", "flags.", "record.", "said.", "chapter.seen.", "offer."]

    static func isProgressKey(_ k: String) -> Bool { exactKeys.contains(k) || prefixes.contains { k.hasPrefix($0) } }

    /// `SPEEDER_KEEP_PROGRESS=1` (and the capture hooks that set progress themselves) skip the fresh start.
    static var freshStartAtLaunch: Bool {
        let env = ProcessInfo.processInfo.environment
        if env["SPEEDER_KEEP_PROGRESS"] == "1" { return false }
        if env["SPEEDER_MISSION"] != nil || env["SPEEDER_FLAGS"] != nil || env["SPEEDER_DEMO"] == "1" { return false }
        return true
    }

    static func clearLive(_ d: UserDefaults) {
        for k in d.dictionaryRepresentation().keys where isProgressKey(k) { d.removeObject(forKey: k) }
    }

    static func exists(_ d: UserDefaults) -> Bool { d.dictionary(forKey: slotKey) != nil }
    static func savedAt(_ d: UserDefaults) -> Date? { d.object(forKey: timeKey) as? Date }

    /// Snapshot the live progress into the slot.
    static func save(_ d: UserDefaults) {
        var slot: [String: Any] = [:]
        for (k, v) in d.dictionaryRepresentation() where isProgressKey(k) { slot[k] = v }
        d.set(slot, forKey: slotKey)
        d.set(Date(), forKey: timeKey)
    }

    /// Replace the live progress with the slot's. Returns false when there is nothing saved.
    @discardableResult
    static func load(_ d: UserDefaults) -> Bool {
        guard let slot = d.dictionary(forKey: slotKey) else { return false }
        clearLive(d)
        for (k, v) in slot { d.set(v, forKey: k) }
        return true
    }

    static func savedText(_ d: UserDefaults) -> String {
        guard let t = savedAt(d) else { return "" }
        let f = DateFormatter(); f.dateFormat = "d MMM HH:mm"
        return f.string(from: t).uppercased()
    }
}
