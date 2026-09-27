import Foundation

/// The story channel (NFS Underground 2's SMS inbox, GTA III's pager, Hotline Miami's machine): every
/// brief and debrief is kept as a message from its contact, the game posts its own notices (a job
/// unlocked, a part fitted, a chapter opened), and an unseen sender leaves one line per chapter. Read
/// from the title, the pause menu and the briefing, so a player who plays two jobs a day keeps the plot.
struct Message: Identifiable, Equatable {
    enum Kind: String { case brief, debrief, notice, chapter, `static` }
    let id: Int
    let sender: String        // "VESS", "KADE", "GARAGE", "??"
    let kind: Kind
    let code: String          // job code the message belongs to ("RELAY 01"), or ""
    let chapter: Int
    let text: String

    /// The unseen sender: its lines arrive as static and are signed with nothing.
    static let unknownSender = "??"
    static let routeSender = "THE ROUTE"
    var isStatic: Bool { kind == .static }
}

struct MessageLog {
    private(set) var messages: [Message] = []
    private let defaults: UserDefaults
    static let key = "messages"
    static let readKey = "messages.read"
    static let cap = 160

    init(_ defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var count: Int { messages.count }
    var latest: Message? { messages.last }
    /// Messages posted since the log was last opened.
    var unread: Int { max(0, messages.count - defaults.integer(forKey: Self.readKey)) }
    mutating func markRead() { defaults.set(messages.count, forKey: Self.readKey) }

    /// Append one message (deduplicated on sender + text, so a replayed brief is not posted twice).
    @discardableResult
    mutating func post(_ sender: String, _ kind: Message.Kind, code: String = "", chapter: Int, _ text: String) -> Bool {
        guard !text.isEmpty, !messages.contains(where: { $0.sender == sender && $0.text == text }) else { return false }
        let id = (messages.last?.id ?? 0) + 1
        messages.append(Message(id: id, sender: sender, kind: kind, code: code, chapter: chapter, text: text))
        if messages.count > Self.cap { messages.removeFirst(messages.count - Self.cap) }
        save()
        return true
    }

    mutating func clear() {
        messages = []
        defaults.removeObject(forKey: Self.key)
        defaults.removeObject(forKey: Self.readKey)
    }

    private mutating func load() {
        guard let raw = defaults.array(forKey: Self.key) as? [[String: Any]] else { return }
        messages = raw.enumerated().compactMap { i, d in
            guard let sender = d["s"] as? String, let text = d["t"] as? String else { return nil }
            return Message(id: i + 1, sender: sender, kind: Message.Kind(rawValue: d["k"] as? String ?? "") ?? .notice,
                           code: d["c"] as? String ?? "", chapter: d["ch"] as? Int ?? 1, text: text)
        }
    }
    private func save() {
        defaults.set(messages.map { ["s": $0.sender, "k": $0.kind.rawValue, "c": $0.code, "ch": $0.chapter, "t": $0.text] as [String: Any] }, forKey: Self.key)
    }
}

extension Mission {
    /// The chapter card's paragraph: where the route is, who is on your side, who is not (Art of Rally's
    /// era text, Wipeout 2048's seasons). Forty words or fewer.
    static func chapterIntro(_ c: Int) -> String {
        switch c {
        case 1: return "The downtown grid at night. Every program on it rides a route: its name, its right to ride. Yours is provisional. VESS dispatches, holds the licence, and pays. Ride clean and the route becomes yours."
        case 2: return "Daylight. The canyon road out past the last relay. KADE rides out here and owes you one. ORIN runs the canyon relays for someone in the core. Nobody dispatches you here; nobody watches either."
        default: return "The core: the densest grid in the system, where the packets end up. SABLE buys routes and derezzes the riders who held them. VESS has been selling. ORIN rides with you. Yours is the last line in the ledger."
        }
    }

    /// The cast's standing at the start of each chapter, for the chapter card.
    enum Standing: String { case contact = "CONTACT", rival = "RIVAL", unknown = "UNKNOWN", ally = "WITH YOU" }
    static func chapterCast(_ c: Int) -> [(name: String, standing: Standing)] {
        switch c {
        case 1: return [("VESS", .contact), ("KADE", .rival), ("ORIN", .unknown), ("SABLE", .unknown)]
        case 2: return [("KADE", .contact), ("ORIN", .rival), ("VESS", .unknown), ("SABLE", .unknown)]
        default: return [("ORIN", .contact), ("SABLE", .rival), ("VESS", .rival), ("KADE", .ally)]
        }
    }

    /// The unseen sender's line for each chapter (Tron 2.0's "Guest": static, cryptic, resolved by the
    /// reveal). It signs nothing until the route is the player's.
    static func staticLine(_ c: Int) -> String {
        switch c {
        case 1: return "-- carrier. the packet you hold is not cargo. --"
        case 2: return "-- carrier. it has your name in it. they do not know you can read. --"
        case 3: return "-- carrier. a route remembers who rode it. finish this. --"
        default: return "-- route-holder. nobody dispatches you now. this line closes. --"
        }
    }
    /// The last message, from KADE, once the arc is done.
    static let endingLine = "KADE: Heard the licence is void. The canyon relay is yours whenever you want it. Ride it however you like."
}
