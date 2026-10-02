import SwiftUI
import ImageIO

/// The Griptap & Co opening (1 Oct 2026): four of Mark's shop panels told as a motion comic, the same
/// device as KERB's `StoryIntroView` (the shop owner is the front door of the game, one absurd incident,
/// attract-mode pacing) with the racer's own look: Chakra Petch lettering, cyan and magenta chrome, a
/// scanline over the cabinet beats. The kids have been through the cabinet once (KERB); this is the
/// second time, and the machine is bigger. Each beat types out, holds, and moves on by itself; A / tap
/// hurries a beat, B / Menu skips the lot. `SPEEDER_STORYBEAT=<n>` starts at beat n, text fully shown,
/// frozen (screenshots).
struct StoryIntroView: View {
    @ObservedObject var controller: GameController

    @State private var beat = 0
    @State private var shown = 0
    @State private var beatStart = Date()
    @State private var panelStart = Date()
    @State private var seenNudge = 0
    private let frozen: Bool
    private let beats = StoryScript.beats

    init(controller: GameController) {
        self.controller = controller
        let start = ProcessInfo.processInfo.environment["SPEEDER_STORYBEAT"].flatMap(Int.init)
        frozen = start != nil
        _beat = State(initialValue: min(max(start ?? 0, 0), StoryScript.beats.count - 1))
    }

    static let cyan = Color(red: 0.25, green: 0.95, blue: 1.0)
    static let magenta = Color(red: 1.0, green: 0.25, blue: 0.85)
    static let ink = Color(red: 0.03, green: 0.03, blue: 0.07)
    /// Panel art aspect (the renders are 1672 x 941).
    private static let aspect: CGFloat = 1672.0 / 941.0

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { ctx in
                frame(size: geo.size, safe: geo.safeAreaInsets, now: ctx.date)
            }
        }
        .ignoresSafeArea()
        .background(Color.black)
        .contentShape(Rectangle())
        .onTapGesture { nudge() }
        .onChange(of: controller.storyNudge) { _, n in if n != seenNudge { seenNudge = n; nudge() } }
        .task(id: beat) { await play() }
    }

    // MARK: Layout

    @ViewBuilder
    private func frame(size: CGSize, safe: EdgeInsets, now: Date) -> some View {
        let b = beats[beat]
        let tBeat = now.timeIntervalSince(beatStart)
        let tPanel = now.timeIntervalSince(panelStart)
        let cw = max(size.width, size.height * Self.aspect)
        let ch = cw / Self.aspect
        // crop mostly from the bottom (the counter) so the shop sign survives on wide phones
        let origin = CGPoint(x: (size.width - cw) / 2, y: (size.height - ch) * 0.22)
        let kb = b.panel > 0 ? StoryScript.kenBurns[b.panel - 1] : (1, 1, UnitPoint.center)
        let scale = kb.0 + (kb.1 - kb.0) * min(1, tPanel / 14)
        let shake = b.shake ? max(0, 1 - tBeat / 0.7) : 0
        let jitter = CGSize(width: sin(tBeat * 71) * 9 * shake, height: cos(tBeat * 53) * 6 * shake)
        let map: (CGPoint) -> CGPoint = { p in
            let a = CGPoint(x: origin.x + kb.2.x * cw, y: origin.y + kb.2.y * ch)
            let q = CGPoint(x: origin.x + p.x * cw, y: origin.y + p.y * ch)
            return CGPoint(x: a.x + (q.x - a.x) * scale + jitter.width, y: a.y + (q.y - a.y) * scale + jitter.height)
        }
        let side = max(24, safe.leading, safe.trailing) + 8

        ZStack {
            Color.black
            if b.panel > 0 {
                panelImage(b.panel)
                    .frame(width: cw, height: ch)
                    .scaleEffect(scale, anchor: kb.2)
                    .offset(jitter)
                    .position(x: size.width / 2, y: origin.y + ch / 2)
                    .id(b.panel)
                    .transition(.opacity)
            }
            if b.panel == 4 || b.panel == 0 { Scanlines().allowsHitTesting(false) }

            beatView(b, map: map, size: size, side: side)
                .id("beat\(beat)")
                .transition(.opacity)

            if b.flash {
                Color.white.opacity(max(0, 1 - tBeat / 0.9)).allowsHitTesting(false)
            }
            chrome(size: size, side: side)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    @ViewBuilder
    private func panelImage(_ n: Int) -> some View {
        if let img = BundledImage.load("story_\(n)", ext: "jpg") {
            Image(decorative: img, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Self.ink
        }
    }

    @ViewBuilder
    private func beatView(_ b: StoryScript.Beat, map: (CGPoint) -> CGPoint, size: CGSize, side: CGFloat) -> some View {
        switch b.kind {
        case .caption(let corner):
            CaptionBox(text: b.text, shown: shown, width: b.width)
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: corner == .top ? .topLeading : .bottomLeading)
                .padding(.leading, side)
                .padding(.vertical, 22)
        case .bubble(let at, let mouth), .shout(let at, let mouth):
            let w = b.width
            let c = map(at)
            let cx = min(max(c.x, side + w / 2), size.width - side - w / 2)
            let cy = min(max(c.y, 70), size.height - 70)
            let m = map(mouth)
            SpeechBubble(text: b.text, shown: shown, width: w,
                         tail: CGSize(width: m.x - cx, height: m.y - cy),
                         shout: { if case .shout = b.kind { return true } else { return false } }())
                .position(x: cx, y: cy)
        case .card:
            VStack(spacing: 20) {
                Typed(text: b.text, shown: shown)
                    .font(HUDStyle.display(22))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .frame(width: min(size.width - 2 * side, 600))
                if shown >= b.text.count {
                    Text("KERB: GALACTIC")
                        .font(HUDStyle.display(HUDStyle.wordmarkSize - 12)).tracking(6)
                        .foregroundStyle(.white)
                        .shadow(color: Self.cyan.opacity(0.9), radius: 14)
                        .transition(.scale(scale: 1.3).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.35), value: shown >= b.text.count)
        }
    }

    /// Panel pips and the skip hint.
    private func chrome(size: CGSize, side: CGFloat) -> some View {
        let panel = beats[beat].panel
        let pad = controller.glyphs.connected
        return VStack {
            HStack {
                Spacer()
                Text(pad ? "A  NEXT     B  SKIP" : "RETURN  NEXT     ESC  SKIP")
                    .font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(2)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.black.opacity(0.45))
                    .clipShape(CutCorner(cut: 4))
                    .onTapGesture { controller.finishStory() }
            }
            Spacer()
            HStack(spacing: 7) {
                ForEach(1...4, id: \.self) { i in
                    Rectangle()
                        .fill(i == panel ? Self.cyan : Color.white.opacity(i < panel || panel == 0 ? 0.7 : 0.3))
                        .frame(width: i == panel ? 22 : 8, height: 3)
                }
            }
            .animation(.easeOut(duration: 0.25), value: panel)
        }
        .padding(.horizontal, side)
        .padding(.vertical, 14)
    }

    // MARK: Pacing

    private func play() async {
        let n = beats[beat].text.count
        if frozen { shown = n; return }
        shown = 0
        let rate: Duration = beats[beat].kind.isCard ? .milliseconds(45) : .milliseconds(24)
        while shown < n {
            try? await Task.sleep(for: rate)
            if Task.isCancelled { return }
            shown += 1
        }
        try? await Task.sleep(for: .seconds(beats[beat].hold))
        if Task.isCancelled { return }
        advance()
    }

    private func nudge() {
        guard !frozen else { return }
        if shown < beats[beat].text.count { shown = beats[beat].text.count } else { advance() }
    }

    private func advance() {
        guard beat + 1 < beats.count else { controller.finishStory(); return }
        let now = Date()
        let newPanel = beats[beat + 1].panel != beats[beat].panel
        withAnimation(.easeInOut(duration: newPanel ? 0.6 : 0.25)) {
            beat += 1
            shown = 0
        }
        beatStart = now
        if newPanel { panelStart = now }
    }
}

// MARK: - The script

enum StoryScript {
    enum Corner { case top, bottom }
    enum Kind {
        case caption(Corner)
        /// Speech bubble centred at `at`, tail to `mouth`; both in panel coordinates (0 ... 1 of the painting).
        case bubble(at: CGPoint, mouth: CGPoint)
        case shout(at: CGPoint, mouth: CGPoint)
        case card
        var isCard: Bool { if case .card = self { return true } else { return false } }
    }
    struct Beat {
        var panel: Int          // 1 ... 4, 0 = black card
        var kind: Kind
        var text: String
        var width: CGFloat = 250
        var flash = false
        var shake = false
        var holdOverride: Double? = nil
        var hold: Double { holdOverride ?? min(4.2, 1.3 + Double(text.count) * 0.03) }
    }

    /// Per panel: scale from, scale to, anchor (a slow push toward the owner, or the vortex).
    static let kenBurns: [(CGFloat, CGFloat, UnitPoint)] = [
        (1.0, 1.07, UnitPoint(x: 0.62, y: 0.40)),
        (1.02, 1.10, UnitPoint(x: 0.55, y: 0.40)),
        (1.0, 1.08, UnitPoint(x: 0.45, y: 0.42)),
        (1.03, 1.12, UnitPoint(x: 0.30, y: 0.45)),
    ]

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    // The owner's mouth: panel 1 (0.635, 0.33), panel 2 (0.60, 0.325), panel 3 (0.63, 0.325), panel 4 (0.865, 0.40).
    static let beats: [Beat] = [
        // 1 — the counter, rain on the glass
        Beat(panel: 1, kind: .caption(.top), text: "Night. The same corner shop, the same cabinet by the window. The rain has not let up since last time.", width: 340),
        Beat(panel: 1, kind: .bubble(at: p(0.83, 0.25), mouth: p(0.635, 0.33)), text: "You kids back again? Ha! It's been a while.", width: 230),

        // 2 — the board of boards
        Beat(panel: 2, kind: .bubble(at: p(0.33, 0.18), mouth: p(0.60, 0.325)), text: "Well, if you're looking for the board to own, this one's it…", width: 250),
        Beat(panel: 2, kind: .bubble(at: p(0.33, 0.18), mouth: p(0.60, 0.325)), text: "…the Kerbie Astro.", width: 200),
        Beat(panel: 2, kind: .bubble(at: p(0.33, 0.18), mouth: p(0.60, 0.325)), text: "No wheels. Doesn't need 'em where it's going.", width: 230),

        // 3 — the cabinet again
        Beat(panel: 3, kind: .bubble(at: p(0.83, 0.25), mouth: p(0.63, 0.325)), text: "Oh, I see you eyeing that game again.", width: 220),
        Beat(panel: 3, kind: .bubble(at: p(0.83, 0.25), mouth: p(0.63, 0.325)), text: "Didn't you learn your lesson the first time?", width: 230),

        // 4 — the vortex takes another one
        Beat(panel: 4, kind: .shout(at: p(0.66, 0.24), mouth: p(0.865, 0.40)), text: "DIDN'T WASTE ANY TIME, HUH?!?!", width: 240, flash: true, shake: true, holdOverride: 1.8),
        Beat(panel: 4, kind: .caption(.bottom), text: "…and the cabinet takes another one. Only this time the machine is bigger. A whole city of it, and a Grid past that.", width: 360),

        // out — the hand-off to the title
        Beat(panel: 0, kind: .card, text: "You were at the cabinet.\nNow you're in it. Again.\n\nThe routes are the currency here.\nRun them.", holdOverride: 2.8),
    ]
}

// MARK: - Lettering

/// Types `text` out without re-wrapping: the unrevealed tail is laid out but drawn clear.
private struct Typed: View {
    let text: String
    let shown: Int
    var body: some View {
        var a = AttributedString(text)
        let n = min(shown, text.count)
        if n < text.count {
            let start = a.characters.index(a.startIndex, offsetBy: n)
            a[start..<a.endIndex].foregroundColor = .clear
        }
        return Text(a)
    }
}

private struct SpeechBubble: View {
    let text: String
    let shown: Int
    let width: CGFloat
    let tail: CGSize
    let shout: Bool

    var body: some View {
        let line = shout ? StoryIntroView.magenta : StoryIntroView.cyan
        Typed(text: text.uppercased(), shown: shown)
            .font(HUDStyle.label(shout ? 17 : 13))
            .tracking(0.8)
            .lineSpacing(3)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(width: width - 32)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, shout ? 18 : 12)
            .background {
                GeometryReader { g in
                    let r = CGRect(origin: .zero, size: g.size)
                    let c = CGPoint(x: r.midX, y: r.midY)
                    let tip = CGPoint(x: c.x + tail.width * 0.86, y: c.y + tail.height * 0.86)
                    let body: AnyShape = shout ? AnyShape(Burst()) : AnyShape(CutCorner(cut: 10))
                    ZStack {
                        Tail(from: c, to: tip, base: shout ? 30 : 22).stroke(line, lineWidth: 3)
                        body.stroke(line, lineWidth: 3)
                        Tail(from: c, to: tip, base: shout ? 30 : 22).fill(StoryIntroView.ink.opacity(0.94))
                        body.fill(StoryIntroView.ink.opacity(0.94))
                    }
                    .shadow(color: line.opacity(0.55), radius: 10)
                }
            }
            .transition(.scale(scale: 0.6).combined(with: .opacity))
    }
}

private struct CaptionBox: View {
    let text: String
    let shown: Int
    let width: CGFloat

    var body: some View {
        Typed(text: text.uppercased(), shown: shown)
            .font(HUDStyle.label(12))
            .tracking(1.2)
            .lineSpacing(3)
            .foregroundStyle(.white.opacity(0.92))
            .frame(width: width - 28, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 16).padding(.trailing, 12)
            .padding(.vertical, 10)
            .background {
                ZStack(alignment: .leading) {
                    Rectangle().fill(StoryIntroView.ink.opacity(0.88))
                    Rectangle().fill(StoryIntroView.cyan).frame(width: 3)
                }
                .shadow(color: .black.opacity(0.5), radius: 8)
            }
    }
}

private struct Tail: Shape {
    var from: CGPoint
    var to: CGPoint
    var base: CGFloat
    func path(in rect: CGRect) -> Path {
        let dx = to.x - from.x, dy = to.y - from.y
        let len = max(1, (dx * dx + dy * dy).squareRoot())
        let nx = -dy / len * base / 2, ny = dx / len * base / 2
        var p = Path()
        p.move(to: CGPoint(x: from.x + nx, y: from.y + ny))
        p.addQuadCurve(to: to, control: CGPoint(x: from.x + dx * 0.6 + nx * 0.2, y: from.y + dy * 0.6 + ny * 0.2))
        p.addQuadCurve(to: CGPoint(x: from.x - nx, y: from.y - ny), control: CGPoint(x: from.x + dx * 0.5 - nx * 0.6, y: from.y + dy * 0.5 - ny * 0.6))
        p.closeSubpath()
        return p
    }
}

private struct Burst: Shape {
    func path(in rect: CGRect) -> Path {
        let spikes = 14
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        for i in 0..<(spikes * 2) {
            let a = Double(i) / Double(spikes * 2) * 2 * .pi - .pi / 2
            let k: CGFloat = i % 2 == 0 ? 1.12 : 0.9
            let pt = CGPoint(x: c.x + cos(a) * rect.width / 2 * k, y: c.y + sin(a) * rect.height / 2 * k)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// CRT scanlines for the "inside the machine" beats.
private struct Scanlines: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black.opacity(0.18)))
                y += 3
            }
        }
    }
}

/// Bundled JPEG / PNG as a CGImage on both platforms (the front end runs on the Mac and the phone).
enum BundledImage {
    private static var cache: [String: CGImage] = [:]
    static func load(_ name: String, ext: String) -> CGImage? {
        if let c = cache[name] { return c }
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        cache[name] = img
        return img
    }
}
