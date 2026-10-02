import SwiftUI
import QuartzCore
import AVFoundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The front end, over the RealityKit view: the splash while the first world builds (the launch
/// screen's wordmark, pixel for pixel, with a loader under it), then the title over the parked world
/// (the wordmark flies to its place low-left), free play, settings, the rider, and the pause over a run.
/// Every list is `GameController.menuRows`: the pad and keys move through it in the frame loop, taps
/// land here.
struct FrontEndView: View {
    @ObservedObject var controller: GameController
    @Namespace private var brand
    @State private var editingCallsign = false
    @State private var callsignDraft = ""
    @FocusState private var callsignFocus: Bool

    private var theme: Theme { Theme(rawValue: controller.settings.environment) ?? .neonCity }
    private var accent: Color { HUDStyle.color(theme.hudAccent) }
    private var glyphs: ControllerGlyphs { controller.glyphs }
    private var screen: Screen { controller.screen }
    private var touchPlay: Bool {
        #if os(iOS)
        return !glyphs.connected
        #else
        return false
        #endif
    }
    /// The select / back art: the pad's buttons, else the keyboard's keys.
    private var selectSymbol: String { glyphs.connected ? glyphs.a : "return" }
    private var backSymbol: String { glyphs.connected ? glyphs.b : "escape" }
    private var compactList: Bool { screen == .settings || screen == .rider || screen == .messages || screen == .riders }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if screen == .loading {
                splash.transition(.opacity)
            } else if screen == .story {
                StoryIntroView(controller: controller).transition(.opacity)
            } else if controller.onTitle {
                titleFrame.transition(.opacity)
            } else {
                pauseFrame.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: screen == .loading)
        .animation(.easeOut(duration: 0.22), value: screen)
        .onChange(of: screen) { _, _ in endKeyboardEdit(save: false) }
    }

    // MARK: - Splash

    /// Same background and the same image as the iOS launch screen, so the hand-off is invisible; the
    /// loader's fill and sheen are Core Animation, so they keep moving while the world builds on the
    /// main thread.
    private var splash: some View {
        ZStack {
            Color(red: 0.01, green: 0.01, blue: 0.02).ignoresSafeArea()
            Image("LaunchLogo")
                .matchedGeometryEffect(id: "wordmark", in: brand, properties: .position)
            VStack(spacing: 9) {
                LoaderLine(stage: controller.loadStage, accent: theme.hudAccent)
                    .frame(width: 220, height: 2)
                Text(controller.loadError.map { "LOAD FAILED  //  \($0)" } ?? controller.loadStage.label)
                    .font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(3)
                    .foregroundStyle(controller.loadError == nil ? Color.white.opacity(0.45) : Color.red)
                    .lineLimit(2).multilineTextAlignment(.center).frame(width: 320)
            }
            .offset(y: 64)
        }
        .contentShape(Rectangle())
        .onTapGesture {}
    }

    // MARK: - Title

    private var titleFrame: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [.black.opacity(compactList ? 0.88 : 0.78), .black.opacity(compactList ? 0.55 : 0.36), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.3), value: compactList)
            VStack(alignment: .leading, spacing: compactList ? 5 : 8) {
                Spacer(minLength: 0)
                if compactList {
                    heading(screen == .settings ? "SETTINGS" : (screen == .messages ? "MESSAGES" : (screen == .riders ? (controller.riderFirstRun ? "WHO'S RIDING?" : "RIDERS") : "CALLSIGN")), over: "KERB: GALACTIC")
                    if screen == .messages { messageList }
                } else {
                    Text("KERB: GALACTIC").font(HUDStyle.display(HUDStyle.wordmarkSize - 12)).tracking(6).foregroundStyle(.white)
                        .shadow(color: accent.opacity(0.8), radius: 14)
                        .matchedGeometryEffect(id: "wordmark", in: brand, properties: .position)
                    Text("COURIER RUNS  //  THE GRID").font(HUDStyle.label(HUDStyle.labelSize + 1)).tracking(3).foregroundStyle(accent)
                    hairline(accent.opacity(0.6)).frame(width: 220)
                    riderLine.padding(.bottom, 4)
                    if screen == .worlds { subheading("FREE PLAY") }
                }
                rows
                footer.padding(.top, 2)
            }
            .padding(.leading, HUDStyle.sideInset + 28)
            .padding(.bottom, HUDStyle.bottomInset + 14)
            .padding(.top, HUDStyle.topInset + 4)
        }
        .contentShape(Rectangle())
        .onTapGesture {}
    }

    /// Callsign (in the livery), the earned title, the purse. A tap opens the rider screen.
    private var riderLine: some View {
        let p = controller.player
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(p.callsign).font(HUDStyle.display(HUDStyle.headingSize)).tracking(2).foregroundStyle(HUDStyle.color(p.liveryColor))
            Text(controller.mission.playerTitle).font(HUDStyle.label(HUDStyle.labelSize)).tracking(1.5).foregroundStyle(.white.opacity(0.55))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("CREDITS").font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1).foregroundStyle(.white.opacity(0.5))
                Text("\(controller.mission.credits)").font(HUDStyle.display(HUDStyle.labelSize + 1)).monospacedDigit().foregroundStyle(.white)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if screen == .title { controller.activate("rider") } }
    }

    // MARK: - Pause

    private var pauseFrame: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black.opacity(0.45).ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.8), .black.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 8) {
                Spacer(minLength: 0)
                heading(screen == .paused ? "PAUSED" : (screen == .settings ? "SETTINGS" : (screen == .messages ? "MESSAGES" : "RIDER")), over: pauseContext)
                if screen == .messages { messageList }
                rows
                footer.padding(.top, 2)
            }
            .padding(.leading, HUDStyle.sideInset + 28)
            .padding(.bottom, HUDStyle.bottomInset + 14)
            .padding(.top, HUDStyle.topInset + 4)
        }
        .contentShape(Rectangle())
        .onTapGesture {}
    }

    private var pauseContext: String {
        if controller.missionActive { return "\(controller.mission.code)  //  \(controller.mission.title)" }
        return "FREE PLAY  //  \(theme.displayName)"
    }

    // MARK: - Messages

    /// The message log, newest first, grouped under chapter lines: the contact's brief and debrief per job,
    /// the game's notices, and the unseen sender's static. Scrolls; the BACK row sits under it.
    private var messageList: some View {
        let msgs = controller.missions.messages.reversed()
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(msgs), id: \.id) { m in messageRow(m) }
            }
            .padding(.trailing, 12)
        }
        .frame(width: 440)
        .frame(maxHeight: HUDStyle.cardMaxHeight - 60)
    }

    private func messageRow(_ m: Message) -> some View {
        let tint: Color = m.isStatic ? .white.opacity(0.45) : (m.kind == .notice || m.kind == .chapter ? .white.opacity(0.6) : HUDStyle.color(Rival.named(m.sender)?.color ?? Rival.vessColor))
        return HStack(alignment: .top, spacing: 8) {
            Rectangle().fill(m.isStatic ? Color.white.opacity(0.2) : tint.opacity(0.8)).frame(width: 2).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(m.sender).font(HUDStyle.display(HUDStyle.labelSize)).tracking(1.5).foregroundStyle(tint)
                    if !m.code.isEmpty { Text(m.code).font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1).foregroundStyle(.white.opacity(0.4)) }
                    if m.kind == .brief { Text("BRIEF").font(HUDStyle.label(HUDStyle.labelSize - 2)).tracking(1).foregroundStyle(.white.opacity(0.3)) }
                }
                Text(m.isStatic ? m.text : m.text)
                    .font(m.isStatic ? .system(size: HUDStyle.bodySize - 1, design: .monospaced) : HUDStyle.body(HUDStyle.bodySize))
                    .lineSpacing(2)
                    .foregroundStyle(m.isStatic ? .white.opacity(0.55) : .white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Lists

    @ViewBuilder private var rows: some View {
        let rows = controller.menuRows
        if compactList {
            // a tall list scrolls on a short phone; it never clips
            ViewThatFits(in: .vertical) {
                compactStack(rows)
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) { compactStack(rows) }
                        .onChange(of: controller.menuIndex) { _, i in withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(i, anchor: .center) } }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in bigRow(row, i) }
            }
        }
    }

    private func compactStack(_ rows: [MenuRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                if !editingCallsign || row.id == "callsign" { compactRow(row, i).id(i) }
            }
        }
    }

    /// Title, free play and pause rows: the label large, a detail line, the highlighted row lit with a
    /// bar, a wash in the row's colour and the select button.
    private func bigRow(_ row: MenuRow, _ i: Int) -> some View {
        let hot = i == controller.menuIndex
        let tint = row.tint.map { HUDStyle.color($0) } ?? accent
        return HStack(alignment: .center, spacing: 12) {
            Rectangle().fill(hot ? tint : .white.opacity(0.18)).frame(width: 3, height: hot ? 30 : 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.label).font(HUDStyle.display(20)).tracking(hot ? 3.5 : 2)
                    .foregroundStyle(hot ? Color.white : Color.white.opacity(0.62))
                if !row.detail.isEmpty {
                    Text(row.detail).font(HUDStyle.label(HUDStyle.labelSize)).tracking(1.3)
                        .foregroundStyle(hot ? tint : Color.white.opacity(0.36)).lineLimit(1)
                }
            }
            if case .toggle(let on) = row.kind { onOff(on, hot: hot) }
            if hot && !touchPlay {
                Image(systemName: selectSymbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
                    .modifier(TempoPulse())
            }
        }
        .padding(.trailing, 24)
        .frame(minHeight: 42, alignment: .leading)
        .background(alignment: .leading) {
            if hot {
                LinearGradient(colors: [tint.opacity(0.3), tint.opacity(0)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 320).transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { controller.tapRow(i) }
        .animation(.spring(duration: 0.22, bounce: 0.25), value: hot)
    }

    /// Settings and rider rows: a label column and the row's control; values take their own taps.
    @ViewBuilder private func compactRow(_ row: MenuRow, _ i: Int) -> some View {
        if case .roster(let sel) = row.kind {
            rosterCard(sel, hot: i == controller.menuIndex)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture { controller.tapRow(i) }
        } else {
            compactValueRow(row, i)
        }
    }

    private func compactValueRow(_ row: MenuRow, _ i: Int) -> some View {
        let hot = i == controller.menuIndex
        return HStack(spacing: 10) {
            Rectangle().fill(hot ? accent : .clear).frame(width: 2, height: 16)
            Text(row.label).font(HUDStyle.label(HUDStyle.labelSize + 1)).tracking(1.4)
                .foregroundStyle(row.id == "reset" && controller.resetArmed ? HUDStyle.amber : (hot ? Color.white : Color.white.opacity(0.65)))
                .frame(width: row.id == "reset" && controller.resetArmed ? 190 : 130, alignment: .leading)
            control(row, i, hot: hot)
            Spacer(minLength: 0)
        }
        .frame(height: 28)
        .padding(.trailing, 12)
        .background(alignment: .leading) {
            if hot { LinearGradient(colors: [accent.opacity(0.2), accent.opacity(0)], startPoint: .leading, endPoint: .trailing).frame(width: 360) }
        }
        .contentShape(Rectangle())
        .onTapGesture { controller.tapRow(i) }
    }

    @ViewBuilder private func control(_ row: MenuRow, _ i: Int, hot: Bool) -> some View {
        switch row.kind {
        case .level(let v):
            HStack(spacing: 3) {
                stepper("chevron.left") { controller.adjust(row.id, by: -1) }
                ForEach(0..<10, id: \.self) { b in
                    Rectangle().fill(b < v ? accent : Color.white.opacity(0.16))
                        .frame(width: 7, height: 5 + CGFloat(b) * 1.1)
                        .frame(width: 11, height: 26, alignment: .bottom)
                        .contentShape(Rectangle())
                        .onTapGesture { controller.setValue(row.id, b + 1 == v ? b : b + 1) }
                }
                stepper("chevron.right") { controller.adjust(row.id, by: 1) }
                Text("\(v)").font(HUDStyle.display(HUDStyle.labelSize + 1)).monospacedDigit().foregroundStyle(.white.opacity(0.8)).frame(width: 20)
            }
        case .choice(let names, let sel):
            HStack(spacing: 4) {
                ForEach(Array(names.enumerated()), id: \.offset) { j, name in
                    segment(name, on: j == sel) { controller.setValue(row.id, j) }
                }
                if hot && !row.detail.isEmpty {
                    Text(row.detail).font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1).foregroundStyle(.white.opacity(0.45)).lineLimit(1).padding(.leading, 6)
                }
            }
        case .toggle(let on):
            HStack(spacing: 4) {
                segment("ON", on: on) { if !on { controller.activate(row.id) } }
                segment("OFF", on: !on) { if on { controller.activate(row.id) } }
            }
        case .callsign(let text):
            callsignField(text, hot: hot)
        case .roster(let sel):
            rosterCard(sel, hot: hot)
        case .livery(let sel):
            HStack(spacing: 6) {
                ForEach(0..<Player.liveries.count, id: \.self) { j in
                    Rectangle().fill(HUDStyle.color(Player.liveries[j].color))
                        .frame(width: 16, height: 16)
                        .overlay(Rectangle().stroke(.white, lineWidth: j == sel ? 2 : 0).padding(-3))
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                        .onTapGesture { controller.setValue("livery", j) }
                }
                Text(row.detail).font(HUDStyle.label(HUDStyle.labelSize)).tracking(1.5).foregroundStyle(HUDStyle.color(Player.liveries[sel].color)).padding(.leading, 4)
            }
        case .action:
            HStack(spacing: 6) {
                if !row.detail.isEmpty {
                    Text(row.detail).font(HUDStyle.label(HUDStyle.labelSize)).tracking(1.2)
                        .foregroundStyle(row.id == "reset" ? HUDStyle.amber.opacity(hot ? 0.9 : 0.5) : (hot ? accent : Color.white.opacity(0.4))).lineLimit(1)
                }
                if hot && row.id != "back" {
                    Image(systemName: touchPlay ? "chevron.right" : selectSymbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(accent)
                }
            }
        }
    }

    /// Eight letter boxes. The pad edits them in place (arcade initials, the cursor lit, up / down
    /// change it); a tap (touch, mouse) opens the keyboard instead.
    @ViewBuilder private func callsignField(_ text: String, hot: Bool) -> some View {
        if editingCallsign {
            HStack(spacing: 8) {
                TextField("CALLSIGN", text: $callsignDraft)
                    .textFieldStyle(.plain)
                    .font(HUDStyle.display(16)).tracking(3)
                    .foregroundStyle(HUDStyle.color(controller.player.liveryColor))
                    .frame(width: 170)
                    .focused($callsignFocus)
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    #endif
                    .onSubmit { endKeyboardEdit(save: true) }
                    .onChange(of: callsignDraft) { _, v in
                        let clean = String(v.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(CallsignEdit.slots))
                        if clean != v { callsignDraft = clean }
                    }
                    .onChange(of: callsignFocus) { _, f in if !f && editingCallsign { endKeyboardEdit(save: true) } }
                hairline(accent).frame(width: 40)
            }
        } else {
            let edit = controller.callsignEdit
            let chars: [Character] = edit?.chars ?? Array(text.padding(toLength: CallsignEdit.slots, withPad: " ", startingAt: 0))
            HStack(spacing: 3) {
                ForEach(0..<CallsignEdit.slots, id: \.self) { k in
                    let cursor = edit?.cursor == k
                    VStack(spacing: 0) {
                        if cursor { Image(systemName: "chevron.up").font(.system(size: 7, weight: .bold)).foregroundStyle(accent) }
                        Text(String(chars[k])).font(HUDStyle.display(15))
                            .foregroundStyle(HUDStyle.color(controller.player.liveryColor))
                            .frame(width: 17, height: 20)
                            .background(cursor ? accent.opacity(0.35) : Color.white.opacity(0.07))
                            .overlay(alignment: .bottom) { hairline(cursor ? accent : Color.white.opacity(0.25)) }
                        if cursor { Image(systemName: "chevron.down").font(.system(size: 7, weight: .bold)).foregroundStyle(accent) }
                    }
                }
                if hot && edit == nil {
                    Text(touchPlay ? "TAP TO TYPE" : "EDIT").font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1).foregroundStyle(.white.opacity(0.4)).padding(.leading, 6)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { beginKeyboardEdit(text) }
        }
    }

    private func beginKeyboardEdit(_ text: String) {
        controller.callsignEdit = nil
        callsignDraft = text
        editingCallsign = true
        callsignFocus = true
    }

    private func endKeyboardEdit(save: Bool) {
        guard editingCallsign else { return }
        editingCallsign = false
        callsignFocus = false
        if save { controller.setCallsign(callsignDraft) }
        controller.refocusGame()
    }

    // MARK: - Rider roster card (1 Oct 2026, mirrors KERB's profile card in this game's chrome)

    private func rosterCard(_ sel: Int, hot: Bool) -> some View {
        let r = Roster.all[max(0, min(Roster.all.count - 1, sel))]
        let h: CGFloat = 172
        return HStack(alignment: .top, spacing: 16) {
            stepper("chevron.left") { controller.adjust("roster", by: -1) }.frame(height: h)
            // portrait: the profile clip looping silently when the rider has one, over the still
            ZStack(alignment: .bottomLeading) {
                Rectangle().fill(Color.white.opacity(0.06))
                if let img = BundledImage.load(r.still, ext: "jpg") {
                    Image(decorative: img, scale: 1).resizable().aspectRatio(contentMode: .fill)
                }
                if let clip = r.clip, let url = Bundle.main.url(forResource: clip, withExtension: "mp4") {
                    LoopingClipView(url: url)
                }
                Text("\(sel + 1) OF \(Roster.all.count)").font(HUDStyle.label(HUDStyle.labelSize - 2)).tracking(1.5)
                    .foregroundStyle(.white.opacity(0.85)).padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.black.opacity(0.55)).clipShape(CutCorner(cut: 3)).padding(8)
            }
            .frame(width: 140, height: h).clipShape(CutCorner(cut: 10))
            .overlay(CutCorner(cut: 10).stroke(hot ? accent : Color.white.opacity(0.25), lineWidth: 1.5))
            .shadow(color: hot ? accent.opacity(0.35) : .clear, radius: 12)
            .id(r.id)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(r.name).font(HUDStyle.display(HUDStyle.cardTitleSize)).tracking(3).foregroundStyle(.white)
                    Text(r.tag).font(HUDStyle.label(HUDStyle.labelSize)).tracking(2).foregroundStyle(accent)
                }
                ForEach(r.bio, id: \.self) { line in
                    Text(line).font(HUDStyle.body(HUDStyle.bodySize)).foregroundStyle(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) {
                    Text("HOME").font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1.5).foregroundStyle(.white.opacity(0.45))
                    Text(r.home.uppercased()).font(HUDStyle.label(HUDStyle.labelSize)).tracking(1.2).foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, 2)
                HStack(spacing: 8) {
                    Text("SIGNATURE").font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1.5).foregroundStyle(accent)
                    Text(r.signature).font(HUDStyle.display(HUDStyle.labelSize + 2)).tracking(1.5).foregroundStyle(.white)
                }
                // handling, two by two, inside the dark gradient where it reads
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) { bar("STEER", r.handling.steer); bar("CLIMB", r.handling.climb) }
                    VStack(alignment: .leading, spacing: 5) { bar("BOOST", r.handling.boost); bar("HULL", r.handling.hull) }
                }
                .padding(.top, 4)
            }
            .frame(width: 420, alignment: .leading)
            stepper("chevron.right") { controller.adjust("roster", by: 1) }.frame(height: h)
        }
    }

    private func bar(_ label: String, _ v: Float) -> some View {
        let f = RiderHandling.bar(v)
        return HStack(spacing: 8) {
            Text(label).font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1.2).foregroundStyle(.white.opacity(0.6)).frame(width: 46, alignment: .leading)
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.14)).frame(width: 96, height: 5)
                Rectangle().fill(accent).frame(width: 96 * CGFloat(0.12 + 0.88 * f), height: 5)
            }
            Text(v >= 1 ? "+\(Int((v - 1) * 100))" : "\(Int((v - 1) * 100))").font(HUDStyle.display(HUDStyle.labelSize)).monospacedDigit()
                .foregroundStyle(v > 1.001 ? accent : (v < 0.999 ? Color.white.opacity(0.45) : Color.white.opacity(0.7))).frame(width: 30, alignment: .trailing)
        }
    }

    // MARK: - Pieces

    private func heading(_ text: String, over: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(over).font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(3).foregroundStyle(.white.opacity(0.45))
            Text(text).font(HUDStyle.display(HUDStyle.cardTitleSize)).tracking(3).foregroundStyle(.white)
                .shadow(color: accent.opacity(0.6), radius: 8)
            hairline(accent.opacity(0.6)).frame(width: 220)
        }
        .padding(.bottom, 2)
    }

    private func subheading(_ text: String) -> some View {
        Text(text).font(HUDStyle.label(HUDStyle.labelSize)).tracking(3).foregroundStyle(.white.opacity(0.5))
    }

    private func segment(_ name: String, on: Bool, action: @escaping () -> Void) -> some View {
        Text(name).font(HUDStyle.label(HUDStyle.labelSize)).tracking(1)
            .foregroundStyle(on ? Color.black : Color.white.opacity(0.7))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(on ? accent : Color.white.opacity(0.08))
            .clipShape(CutCorner(cut: 4))
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }

    private func onOff(_ on: Bool, hot: Bool) -> some View {
        Text(on ? "ON" : "OFF").font(HUDStyle.label(HUDStyle.labelSize)).tracking(1)
            .foregroundStyle(on ? Color.black : Color.white.opacity(0.7))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(on ? accent : Color.white.opacity(0.1))
            .clipShape(CutCorner(cut: 4))
    }

    private func stepper(_ symbol: String, action: @escaping () -> Void) -> some View {
        Image(systemName: symbol).font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.55))
            .frame(width: 22, height: 26).contentShape(Rectangle())
            .onTapGesture(perform: action)
    }

    private func hairline(_ color: Color) -> some View { Rectangle().fill(color).frame(height: 1) }

    /// The button legend under a list (pad and keyboard); the version line on SETTINGS (five taps unlock
    /// the developer panel).
    private var footer: some View {
        HStack(spacing: 14) {
            if !touchPlay {
                if controller.callsignEdit != nil {
                    legend("arrow.up.arrow.down", "LETTER")
                    legend("arrow.left.arrow.right", "MOVE")
                    legend(selectSymbol, "KEEP")
                    legend(backSymbol, "CANCEL")
                } else {
                    legend(glyphs.connected ? glyphs.stick : "arrow.up.arrow.down", compactList ? "MOVE, CHANGE" : "MOVE")
                    legend(selectSymbol, "SELECT")
                    if controller.screens.count > 1 { legend(backSymbol, screen == .paused ? "RESUME" : "BACK") }
                }
            }
            if screen == .settings {
                Text(versionLine).font(HUDStyle.label(HUDStyle.labelSize - 2)).tracking(1.5).foregroundStyle(.white.opacity(0.3))
                    .padding(.vertical, 6).padding(.horizontal, 4)
                    .contentShape(Rectangle())
                    .onTapGesture { controller.versionTapped() }
            }
        }
        .foregroundStyle(.white.opacity(0.45))
    }

    private func legend(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
            Text(text).font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1)
        }
    }

    private var versionLine: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = info?["CFBundleVersion"] as? String ?? "1"
        return "SPEEDER \(v) (\(b))" + (controller.prefs.devUnlocked ? "  //  DEV" : "")
    }
}

/// The select glyph breathing at the music's tempo (112 bpm).
private struct TempoPulse: ViewModifier {
    @State private var lit = false
    func body(content: Content) -> some View {
        content.opacity(lit ? 1 : 0.45)
            .onAppear { withAnimation(.easeInOut(duration: 0.536).repeatForever(autoreverses: true)) { lit = true } }
    }
}

// MARK: - The loader line (Core Animation, so it moves while the main thread builds the world)

struct LoaderLine: View {
    let stage: LoadStage
    let accent: SIMD3<Float>
}

#if os(macOS)
extension LoaderLine: NSViewRepresentable {
    func makeNSView(context: Context) -> LoaderLineView { LoaderLineView() }
    func updateNSView(_ v: LoaderLineView, context: Context) { v.apply(stage, accent: accent) }
}
#else
extension LoaderLine: UIViewRepresentable {
    func makeUIView(context: Context) -> LoaderLineView { LoaderLineView() }
    func updateUIView(_ v: LoaderLineView, context: Context) { v.apply(stage, accent: accent) }
}
#endif

#if os(macOS)
typealias LoaderHostView = NSView
#else
typealias LoaderHostView = UIView
#endif

/// A hairline track, a fill that runs to each stage's target over that stage's expected time, and a
/// sheen sweeping along it. All three are layer animations on the render server.
final class LoaderLineView: LoaderHostView {
    private let track = CALayer()
    private let fill = CALayer()
    private let sheen = CAGradientLayer()
    private var stageID = -1
    private var progress: CGFloat = 0
    private var host: CALayer {
        #if os(macOS)
        return layer!
        #else
        return layer
        #endif
    }

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 220, height: 2))
        #if os(macOS)
        wantsLayer = true
        #else
        isUserInteractionEnabled = false
        #endif
        host.masksToBounds = false
        track.backgroundColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.14)
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        sheen.startPoint = CGPoint(x: 0, y: 0.5)
        sheen.endPoint = CGPoint(x: 1, y: 0.5)
        sheen.colors = [CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0), CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.9), CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0)]
        track.masksToBounds = true
        host.addSublayer(track)
        host.addSublayer(fill)
        track.addSublayer(sheen)
    }
    required init?(coder: NSCoder) { fatalError("not supported") }

    #if os(macOS)
    override func layout() { super.layout(); relayout() }
    #else
    override func layoutSubviews() { super.layoutSubviews(); relayout() }
    #endif

    private func relayout() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        track.frame = bounds
        fill.bounds = CGRect(x: 0, y: 0, width: bounds.width * progress, height: bounds.height)
        fill.position = CGPoint(x: 0, y: bounds.midY)
        sheen.frame = CGRect(x: -70, y: 0, width: 70, height: bounds.height)
        CATransaction.commit()
        if sheen.animation(forKey: "sweep") == nil && bounds.width > 0 {
            let a = CABasicAnimation(keyPath: "position.x")
            a.fromValue = -35
            a.toValue = bounds.width + 35
            a.duration = 1.15
            a.repeatCount = .infinity
            a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            sheen.add(a, forKey: "sweep")
        }
    }

    func apply(_ stage: LoadStage, accent: SIMD3<Float>) {
        fill.backgroundColor = CGColor(srgbRed: CGFloat(accent.x), green: CGFloat(accent.y), blue: CGFloat(accent.z), alpha: 0.95)
        fill.shadowColor = fill.backgroundColor
        fill.shadowOpacity = 0.9
        fill.shadowRadius = 3
        fill.shadowOffset = .zero
        guard stage.id != stageID else { return }
        stageID = stage.id
        let from = (fill.presentation() ?? fill).bounds.width
        progress = CGFloat(max(0, min(1, stage.to)))
        let to = bounds.width * progress
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.bounds = CGRect(x: 0, y: 0, width: to, height: bounds.height)
        CATransaction.commit()
        let a = CABasicAnimation(keyPath: "bounds.size.width")
        a.fromValue = from
        a.toValue = to
        a.duration = max(0.15, stage.seconds)
        a.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.6, 0.35, 1)
        fill.add(a, forKey: "fill")
    }
}


// MARK: - Looping profile clip (AVQueuePlayer + AVPlayerLooper, muted, aspect-fill; Mac and iOS)

#if os(macOS)
final class PlayerHostView: NSView {
    let playerLayer = AVPlayerLayer()
    override init(frame: NSRect) { super.init(frame: frame); wantsLayer = true; layer?.addSublayer(playerLayer) }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() { super.layout(); playerLayer.frame = bounds }
}
struct LoopingClipView: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> PlayerHostView { let v = PlayerHostView(); context.coordinator.attach(v.playerLayer, url); return v }
    func updateNSView(_ v: PlayerHostView, context: Context) {}
    static func dismantleNSView(_ v: PlayerHostView, coordinator: Coordinator) { coordinator.detach(v.playerLayer) }
    func makeCoordinator() -> ClipCoordinator { ClipCoordinator() }
}
#else
final class PlayerHostView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
struct LoopingClipView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PlayerHostView { let v = PlayerHostView(); v.backgroundColor = .clear; context.coordinator.attach(v.playerLayer, url); return v }
    func updateUIView(_ v: PlayerHostView, context: Context) {}
    static func dismantleUIView(_ v: PlayerHostView, coordinator: Coordinator) { coordinator.detach(v.playerLayer) }
    func makeCoordinator() -> ClipCoordinator { ClipCoordinator() }
}
#endif

final class ClipCoordinator {
    var looper: AVPlayerLooper?
    func attach(_ layer: AVPlayerLayer, _ url: URL) {
        let player = AVQueuePlayer()
        player.isMuted = true
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        layer.player = player
        layer.videoGravity = .resizeAspectFill
        player.play()
    }
    func detach(_ layer: AVPlayerLayer) { layer.player?.pause(); layer.player = nil; looper = nil }
}
