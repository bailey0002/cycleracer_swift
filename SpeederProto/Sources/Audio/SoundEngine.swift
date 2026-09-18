import Foundation
import AVFoundation

/// The game's sound layer. Everything is synthesised at launch (Tron-clean tones, filtered noise),
/// so there are no audio assets: one-shot cues play from a small pool of player nodes, and five
/// loops (engine, boost, grind, scrape, alarm) run permanently with their volume and pitch driven
/// per frame. Wired from `GameController` on the same frame as the visual and haptic feedback.
/// `SPEEDER_SOUND=0` (or `SPEEDER_DEMO=1` without `SPEEDER_SOUND=1`) keeps it silent for captures.
final class SoundEngine {
    enum Cue: CaseIterable {
        case accept, go, success, fail, respawn, tick, warn
        case hit, fire, kill, beacon, gate, section, approach, streakLost
        case snap, jump, land, derez, rivalDerez, pickup, pickupTaken, surge, slow, zone, roundStart, matchWon, matchLost, charge
    }
    enum Loop: Int, CaseIterable { case engine, boost, grind, scrape, alarm }

    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44100
    private let format: AVAudioFormat
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var shots: [(player: AVAudioPlayerNode, pitch: AVAudioUnitVarispeed)] = []
    private var nextShot = 0
    private var loops: [(player: AVAudioPlayerNode, pitch: AVAudioUnitVarispeed, buffer: AVAudioPCMBuffer)] = []
    private var loopTargets: [Float] = Array(repeating: 0, count: Loop.allCases.count)
    private var loopVolumes: [Float] = Array(repeating: 0, count: Loop.allCases.count)
    private var running = false
    private(set) var available = false
    /// Master switch (the HUD `sound` toggle). Loops fade out when off.
    var enabled = true {
        didSet { engine.mainMixerNode.outputVolume = enabled ? masterVolume : 0 }
    }
    private let masterVolume: Float = 0.8

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let env = ProcessInfo.processInfo.environment
        let silent = env["SPEEDER_SOUND"] == "0" || (env["SPEEDER_DEMO"] == "1" && env["SPEEDER_SOUND"] != "1")
        if silent { enabled = false; return }
        synthesise()
        #if os(iOS)
        // ambient: mixes with the player's own music and respects the silent switch
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
            guard let raw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt, let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            if type == .ended { self?.restart() }
        }
        #endif
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            self?.restart()
        }
        attach()
        start()
    }

    // MARK: - Graph

    private func attach() {
        for _ in 0..<8 {
            let p = AVAudioPlayerNode(), v = AVAudioUnitVarispeed()
            engine.attach(p); engine.attach(v)
            engine.connect(p, to: v, format: format)
            engine.connect(v, to: engine.mainMixerNode, format: format)
            shots.append((p, v))
        }
        let loopBuffers: [AVAudioPCMBuffer] = [engineLoop(), boostLoop(), grindLoop(), scrapeLoop(), alarmLoop()]
        for b in loopBuffers {
            let p = AVAudioPlayerNode(), v = AVAudioUnitVarispeed()
            engine.attach(p); engine.attach(v)
            engine.connect(p, to: v, format: format)
            engine.connect(v, to: engine.mainMixerNode, format: format)
            p.volume = 0
            loops.append((p, v, b))
        }
        engine.mainMixerNode.outputVolume = enabled ? masterVolume : 0
    }

    private func start() {
        engine.prepare()
        do {
            try engine.start()
            running = true
            available = true
            for l in loops {
                l.player.scheduleBuffer(l.buffer, at: nil, options: [.loops], completionHandler: nil)
                l.player.play()
            }
        } catch {
            print("sound: engine start failed: \(error)")
            running = false
        }
    }

    private func restart() {
        guard available else { return }
        engine.stop()
        for l in loops { l.player.stop() }
        for s in shots { s.player.stop() }
        start()
    }

    // MARK: - Playback

    /// Play a cue once. `pitch` is a playback-rate multiplier (0.5 ... 2).
    func play(_ cue: Cue, volume: Float = 1, pitch: Float = 1) {
        guard running, enabled, let b = buffers[cue] else { return }
        let s = shots[nextShot]
        nextShot = (nextShot + 1) % shots.count
        s.player.stop()
        s.pitch.rate = max(0.25, min(4, pitch))
        s.player.volume = max(0, min(1, volume))
        s.player.scheduleBuffer(b, at: nil, options: [], completionHandler: nil)
        s.player.play()
    }

    /// Set a loop's target volume (0 ... 1) and pitch; call every frame, then `update(dt:)`.
    func set(_ loop: Loop, volume: Float, pitch: Float = 1) {
        guard running else { return }
        loopTargets[loop.rawValue] = max(0, min(1, volume))
        loops[loop.rawValue].pitch.rate = max(0.25, min(4, pitch))
    }

    /// Smooth the loop volumes toward their targets (fast attack, slower release).
    func update(dt: Float) {
        guard running else { return }
        for i in loops.indices {
            let t = loopTargets[i]
            let v = loopVolumes[i]
            let rate: Float = t > v ? 18 : 6
            loopVolumes[i] = damp(v, t, rate, dt)
            loops[i].player.volume = loopVolumes[i]
            loopTargets[i] = 0        // callers re-assert every frame; silence otherwise
        }
    }

    // MARK: - Synthesis

    private func synthesise() {
        buffers[.accept] = make(blip(freq: 880, seconds: 0.09) + blip(freq: 1320, seconds: 0.12), gain: 0.5)
        buffers[.go] = make(sweep(f0: 440, f1: 1320, seconds: 0.35, wave: .square), gain: 0.45)
        buffers[.success] = make(arpeggio([523, 659, 784, 1047], step: 0.11, ring: 0.5), gain: 0.55)
        buffers[.fail] = make(arpeggio([392, 311, 262, 196], step: 0.16, ring: 0.6, wave: .saw), gain: 0.5)
        buffers[.respawn] = make(sweep(f0: 200, f1: 880, seconds: 0.5, wave: .saw) , gain: 0.5)
        buffers[.tick] = make(blip(freq: 1760, seconds: 0.05), gain: 0.5)
        buffers[.warn] = make(tone(freq: 660, seconds: 0.18, wave: .square, attack: 0.005, release: 0.08), gain: 0.35)
        buffers[.hit] = make(mix(noise(seconds: 0.28, lowpass: 0.25, decay: 12), tone(freq: 70, seconds: 0.3, wave: .sine, attack: 0.002, release: 0.25)), gain: 0.9)
        buffers[.fire] = make(sweep(f0: 1800, f1: 500, seconds: 0.09, wave: .square), gain: 0.28)
        buffers[.kill] = make(mix(noise(seconds: 0.45, lowpass: 0.4, decay: 7), sweep(f0: 300, f1: 60, seconds: 0.4, wave: .saw)), gain: 0.7)
        buffers[.beacon] = make(blip(freq: 1047, seconds: 0.08) + blip(freq: 1568, seconds: 0.18), gain: 0.5)
        buffers[.gate] = make(blip(freq: 784, seconds: 0.07) + blip(freq: 1175, seconds: 0.1), gain: 0.4)
        buffers[.section] = make(mix(sweep(f0: 120, f1: 60, seconds: 0.6, wave: .saw), noise(seconds: 0.6, lowpass: 0.08, decay: 4)), gain: 0.55)
        buffers[.approach] = make(tone(freq: 440, seconds: 0.14, wave: .sine, attack: 0.01, release: 0.1) + tone(freq: 440, seconds: 0.14, wave: .sine, attack: 0.01, release: 0.1), gain: 0.3)
        buffers[.streakLost] = make(sweep(f0: 600, f1: 220, seconds: 0.25, wave: .square), gain: 0.35)
        buffers[.snap] = make(blip(freq: 2200, seconds: 0.03) + noise(seconds: 0.05, lowpass: 0.6, decay: 40), gain: 0.4)
        buffers[.jump] = make(sweep(f0: 300, f1: 900, seconds: 0.25, wave: .sine), gain: 0.4)
        buffers[.land] = make(mix(noise(seconds: 0.15, lowpass: 0.2, decay: 20), tone(freq: 90, seconds: 0.15, wave: .sine, attack: 0.002, release: 0.12)), gain: 0.6)
        buffers[.derez] = make(mix(noise(seconds: 0.7, lowpass: 0.5, decay: 5), sweep(f0: 1200, f1: 80, seconds: 0.7, wave: .square)), gain: 0.85)
        buffers[.rivalDerez] = make(mix(noise(seconds: 0.6, lowpass: 0.45, decay: 6), sweep(f0: 900, f1: 120, seconds: 0.6, wave: .saw)) + arpeggio([784, 1047], step: 0.1, ring: 0.3), gain: 0.7)
        buffers[.pickup] = make(sweep(f0: 500, f1: 2000, seconds: 0.3, wave: .square), gain: 0.4)
        buffers[.pickupTaken] = make(blip(freq: 1320, seconds: 0.06) + blip(freq: 1760, seconds: 0.06) + blip(freq: 2200, seconds: 0.1), gain: 0.4)
        buffers[.surge] = make(sweep(f0: 200, f1: 1400, seconds: 0.4, wave: .saw), gain: 0.5)
        buffers[.charge] = make(arpeggio([659, 880, 1175, 1568], step: 0.06, ring: 0.35), gain: 0.5)
        buffers[.slow] = make(sweep(f0: 700, f1: 150, seconds: 0.4, wave: .saw), gain: 0.45)
        buffers[.zone] = make(tone(freq: 330, seconds: 0.5, wave: .square, attack: 0.02, release: 0.3) + tone(freq: 330, seconds: 0.5, wave: .square, attack: 0.02, release: 0.3), gain: 0.4)
        buffers[.roundStart] = make(blip(freq: 660, seconds: 0.12) + blip(freq: 660, seconds: 0.12) + blip(freq: 880, seconds: 0.2), gain: 0.45)
        buffers[.matchWon] = make(arpeggio([523, 659, 784, 1047, 1319], step: 0.12, ring: 0.9), gain: 0.6)
        buffers[.matchLost] = make(arpeggio([440, 370, 311, 220], step: 0.2, ring: 0.9, wave: .saw), gain: 0.55)
    }

    private enum Wave { case sine, square, saw }

    private func osc(_ wave: Wave, _ phase: Float) -> Float {
        let p = phase - floor(phase)          // 0 ... 1
        switch wave {
        case .sine: return sin(p * 2 * .pi)
        case .square: return p < 0.5 ? 1 : -1
        case .saw: return 2 * p - 1
        }
    }

    /// A tone with attack/release envelope; a touch of the octave above keeps it from sounding flat.
    private func tone(freq: Float, seconds: Float, wave: Wave, attack: Float, release: Float) -> [Float] {
        let n = Int(Float(sampleRate) * seconds)
        var out = [Float](repeating: 0, count: n)
        var phase: Float = 0
        let step = freq / Float(sampleRate)
        for i in 0..<n {
            let t = Float(i) / Float(sampleRate)
            let env = min(1, t / max(attack, 1e-4)) * min(1, (seconds - t) / max(release, 1e-4))
            out[i] = (osc(wave, phase) * 0.8 + osc(.sine, phase * 2) * 0.2) * env
            phase += step
        }
        return out
    }

    private func blip(freq: Float, seconds: Float) -> [Float] {
        tone(freq: freq, seconds: seconds, wave: .sine, attack: 0.004, release: seconds * 0.6)
    }

    private func sweep(f0: Float, f1: Float, seconds: Float, wave: Wave) -> [Float] {
        let n = Int(Float(sampleRate) * seconds)
        var out = [Float](repeating: 0, count: n)
        var phase: Float = 0
        for i in 0..<n {
            let t = Float(i) / Float(n)
            let f = f0 * pow(f1 / f0, t)          // exponential glide
            let env = min(1, Float(i) / 200) * (1 - t) * (1 - t)
            out[i] = osc(wave, phase) * env
            phase += f / Float(sampleRate)
        }
        return out
    }

    private func arpeggio(_ freqs: [Float], step: Float, ring: Float, wave: Wave = .sine) -> [Float] {
        var out: [Float] = []
        for (k, f) in freqs.enumerated() {
            let last = k == freqs.count - 1
            out += tone(freq: f, seconds: last ? ring : step, wave: wave, attack: 0.004, release: last ? ring * 0.7 : step * 0.5)
        }
        return out
    }

    /// Filtered noise burst. `lowpass` is the one-pole coefficient (1 = white, 0.05 = rumble),
    /// `decay` the exponential rate per second.
    private func noise(seconds: Float, lowpass: Float, decay: Float) -> [Float] {
        let n = Int(Float(sampleRate) * seconds)
        var out = [Float](repeating: 0, count: n)
        var rng = SeededRNG(seed: 99)
        var y: Float = 0
        for i in 0..<n {
            let w = rng.float(-1, 1)
            y += (w - y) * lowpass
            let t = Float(i) / Float(sampleRate)
            out[i] = y * exp(-decay * t) * (lowpass < 0.3 ? 3 : 1.2)
        }
        return out
    }

    private func mix(_ a: [Float], _ b: [Float]) -> [Float] {
        var out = [Float](repeating: 0, count: max(a.count, b.count))
        for i in a.indices { out[i] += a[i] }
        for i in b.indices { out[i] += b[i] }
        return out
    }

    /// Loops are exactly one second so their base frequencies (multiples of 1 Hz) wrap seamlessly.
    private func loopSamples(_ f: (Float) -> Float) -> [Float] {
        let n = Int(sampleRate)
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n { out[i] = f(Float(i) / Float(sampleRate)) }
        return out
    }

    private func engineLoop() -> AVAudioPCMBuffer {
        make(loopSamples { t in
            let p = t * 55
            return (osc(.saw, p) * 0.5 + osc(.saw, p * 1.5 + 0.1) * 0.25 + osc(.sine, p * 3) * 0.15 + osc(.sine, p * 0.5) * 0.2) * 0.35
        }, gain: 1)
    }

    private func boostLoop() -> AVAudioPCMBuffer {
        var rng = SeededRNG(seed: 7)
        var y: Float = 0
        let n = Int(sampleRate)
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let w = rng.float(-1, 1)
            y += (w - y) * 0.12
            let t = Float(i) / Float(sampleRate)
            out[i] = y * 1.8 + osc(.saw, t * 110) * 0.18
        }
        return make(crossfadeLoop(out), gain: 0.6)
    }

    private func grindLoop() -> AVAudioPCMBuffer {
        make(loopSamples { t in
            (osc(.square, t * 220) * 0.5 + osc(.saw, t * 221) * 0.5) * (0.7 + 0.3 * osc(.sine, t * 14))
        }, gain: 0.35)
    }

    private func scrapeLoop() -> AVAudioPCMBuffer {
        var rng = SeededRNG(seed: 11)
        var y: Float = 0
        let n = Int(sampleRate)
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let w = rng.float(-1, 1)
            y += (w - y) * 0.7
            let t = Float(i) / Float(sampleRate)
            out[i] = y * (0.6 + 0.4 * osc(.sine, t * 37)) * 0.8
        }
        return make(crossfadeLoop(out), gain: 0.6)
    }

    private func alarmLoop() -> AVAudioPCMBuffer {
        make(loopSamples { t in
            let gate: Float = (t * 4).truncatingRemainder(dividingBy: 1) < 0.35 ? 1 : 0
            return osc(.square, t * 880) * 0.4 * gate
        }, gain: 0.45)
    }

    private func crossfadeLoop(_ a: [Float]) -> [Float] {
        var out = a
        let n = min(2048, a.count / 4)
        for i in 0..<n {
            let t = Float(i) / Float(n)
            out[a.count - n + i] = a[a.count - n + i] * (1 - t) + a[i] * t
        }
        return out
    }

    private func make(_ samples: [Float], gain: Float) -> AVAudioPCMBuffer {
        let count = AVAudioFrameCount(max(1, samples.count))
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count)!
        buffer.frameLength = count
        let peak = max(1e-4, samples.map { abs($0) }.max() ?? 1)
        let norm = min(1, 1 / peak) * gain
        if let data = buffer.floatChannelData?[0] {
            for i in samples.indices { data[i] = max(-1, min(1, samples[i] * norm)) }
        }
        return buffer
    }
}
