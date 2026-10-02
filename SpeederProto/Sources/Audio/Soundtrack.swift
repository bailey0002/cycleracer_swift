import Foundation
import AVFoundation

/// File-based audio next to the synthesised `SoundEngine` (1 Oct 2026, mirroring KERB's `AudioSystem`):
/// Mark's music (`Resources/Audio/music_*.m4a`, AAC 128 kbps, his own), the cabinet announcer (`vo_*.wav`,
/// Kenney CC0 voiceover packs, a stand-in until the real voices are recorded) and the story cues (`sfx_*.wav`,
/// Kenney CC0). Two music slots crossfade by `mood` (the menu bed vs the in-run playlist) and duck under a
/// line. The generative music mutes while a track plays (`hasMusic`).
@MainActor
final class Soundtrack {
    enum Mood { case off, menu, run }

    private var clips: [String: AVAudioPlayer] = [:]
    private var playlists: [[URL]] = [[], []]
    private var trackIndex = [0, 0]
    private var slots: [AVAudioPlayer?] = [nil, nil]
    private var level: [Float] = [0, 0]
    private var active = -1
    var mood: Mood = .off {
        didSet { if mood != oldValue { select() } }
    }
    /// A pause holds the music down without stopping it.
    var held = false
    private var duckTime: Float = 0
    private var announceGap: Float = 0
    private var lastLines: [String] = []
    private var cooldowns: [String: Float] = [:]
    private var queue: [(name: String, at: Float)] = []
    private var clock: Float = 0

    let enabled: Bool
    var hasMusic: Bool { !(playlists[0].isEmpty && playlists[1].isEmpty) }
    /// The player's MUSIC and EFFECTS levels (0 ... 1).
    var musicVolume: Float = 0.8
    var effectsVolume: Float = 1

    init(enabled: Bool) {
        self.enabled = enabled && ProcessInfo.processInfo.environment["SPEEDER_TRACKS"] != "0"
        guard self.enabled else { return }
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil) else { return }
        for url in urls {
            let name = url.deletingPathExtension().lastPathComponent
            guard name.hasPrefix("vo_") || name.hasPrefix("sfx_"), let p = try? AVAudioPlayer(contentsOf: url) else { continue }
            p.prepareToPlay()
            clips[name] = p
        }
        func open(_ n: String) -> URL? { Bundle.main.url(forResource: n, withExtension: "m4a") }
        playlists[0] = ["music_hideaway"].compactMap(open)
        playlists[1] = ["music_firstplace", "music_toolate"].compactMap(open)
        print("Soundtrack: \(clips.count) clips, music \(playlists[0].count)+\(playlists[1].count) tracks")
    }

    // MARK: - Music

    private func select() {
        let want = mood == .menu ? 0 : (mood == .run ? 1 : -1)
        guard want != active else { return }
        active = want
        if want >= 0, slots[want] == nil { startTrack(want) }
    }

    private func startTrack(_ i: Int) {
        let list = playlists[i]
        guard !list.isEmpty else { return }
        let url = list[trackIndex[i] % list.count]
        trackIndex[i] += 1
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.numberOfLoops = list.count == 1 ? -1 : 0        // a one-track list loops, a playlist plays through
        p.volume = 0
        p.prepareToPlay()
        p.play()
        slots[i] = p
        print("Soundtrack: playing \(url.lastPathComponent) in slot \(i)")
    }

    /// Per frame: fades, the duck, the announcer queue, the playlist's next song.
    func update(dt: Float) {
        guard enabled else { return }
        clock += dt
        duckTime = max(0, duckTime - dt)
        announceGap = max(0, announceGap - dt)
        for k in cooldowns.keys { cooldowns[k] = max(0, (cooldowns[k] ?? 0) - dt) }
        while let next = queue.first, next.at <= clock {
            queue.removeFirst()
            fire(next.name)
        }
        let duck: Float = duckTime > 0 ? 0.4 : 1
        for i in 0..<2 {
            let target: Float = (i == active && !held) ? musicVolume * duck : (i == active ? musicVolume * 0.35 : 0)
            let rate: Float = target < level[i] ? (duckTime > 0 ? 3.0 : 0.9) : 0.9
            level[i] += (target - level[i]) * min(1, rate * dt)
            if let p = slots[i] {
                p.volume = level[i]
                if !p.isPlaying, i == active {
                    // the song ended: the next one in the list (a one-track list loops by itself)
                    slots[i] = nil
                    startTrack(i)
                } else if !p.isPlaying, i != active, level[i] < 0.001 {
                    slots[i] = nil
                } else if i != active, level[i] < 0.001 {
                    p.pause()
                    slots[i] = nil
                }
            }
        }
    }

    // MARK: - The announcer and the cues

    /// Play `names` back to back (`gap` s apart). `key` + `cooldown` rate-limit a moment; `chance` thins it;
    /// `pool` picks one of several lines, never one of the last two said. Lines in progress are interrupted
    /// only by `priority` lines (round start, finish). A 3 s gap keeps the voice from nagging.
    func announce(_ names: [String], gap: Float = 0.12, key: String? = nil, cooldown: Float = 0, chance: Float = 1, priority: Bool = false) {
        guard enabled, !names.isEmpty else { return }
        if let key, (cooldowns[key] ?? 0) > 0 { return }
        if !priority && announceGap > 0 { return }
        if chance < 1 && Float.random(in: 0..<1) > chance { return }
        if let key, cooldown > 0 { cooldowns[key] = cooldown }
        if priority { queue.removeAll(); for p in clips.values where p.isPlaying && p.numberOfLoops == 0 && p.duration > 0.45 { p.stop() } }
        var at: Float = 0
        for n in names {
            queue.append((n, clock + at))
            at += Float(clips[n]?.duration ?? 0.6) + gap
        }
        duckTime = at + 0.3
        announceGap = at + 3.0
        lastLines.append(contentsOf: names); if lastLines.count > 2 { lastLines.removeFirst(lastLines.count - 2) }
    }

    /// One line out of several, avoiding the two most recent.
    func announcePool(_ pool: [String], key: String? = nil, cooldown: Float = 0, chance: Float = 1, priority: Bool = false) {
        let fresh = pool.filter { !lastLines.contains($0) }
        guard let pick = (fresh.isEmpty ? pool : fresh).randomElement() else { return }
        announce([pick], key: key, cooldown: cooldown, chance: chance, priority: priority)
    }

    /// A story / interface cue, right now.
    func cue(_ name: String, volume: Float = 1) { fire(name, volume: volume) }

    private func fire(_ name: String, volume: Float = 1) {
        guard let p = clips[name] else { return }
        p.volume = volume * effectsVolume
        p.currentTime = 0
        p.play()
        if name != "sfx_bubble" { print("CUE \(name)") }
    }
}
