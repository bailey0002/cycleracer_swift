import SwiftUI
import CoreText

/// The game's HUD and cards. One visual language: a display face (Chakra Petch), no boxes, hairlines
/// and gradients, the world's road colour as the accent, controller glyphs read from the pad.
/// Layout zones (spec in docs/research-2026-09-26-reports.md, report C): timer top-left, hull and the
/// objective top-centre, score and streak top-right, speed bottom-left, "coming up" bottom-centre,
/// the action buttons or pad pips bottom-right, stamps in the centre band.
struct HUDView: View {
    @ObservedObject var controller: GameController

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    topLeft.allowsHitTesting(false)
                    Spacer(minLength: 8)
                    topCentre.allowsHitTesting(false)
                    Spacer(minLength: 8)
                    topRight
                }
                Spacer()
                HStack(alignment: .bottom, spacing: 12) {
                    if !cardUp { bottomLeft.allowsHitTesting(false) }
                    Spacer(minLength: 8)
                    if !cardUp { upcomingChip.allowsHitTesting(false) }
                    Spacer(minLength: 8)
                    bottomRight
                }
            }
            .padding(.horizontal, HUDStyle.sideInset)
            .padding(.top, HUDStyle.topInset)
            .padding(.bottom, HUDStyle.bottomInset)
            // boost state: the readouts breathe outward and brighten with the frame
            .scaleEffect(controller.ack.boost && !cardUp ? 1.025 : 1)
            .brightness(controller.ack.boost && !cardUp ? 0.1 : 0)
            .animation(.easeOut(duration: controller.ack.boost ? 0.15 : 0.4), value: controller.ack.boost)
            if !controller.titleVisible { missionOverlay }
            stampOverlay
            if controller.titleVisible { titleScreen }
        }
        .font(HUDStyle.body(HUDStyle.bodySize))
        #if os(iOS)
        .controlSize(.mini)
        #endif
        .foregroundStyle(.white.opacity(0.92))
    }

    // MARK: - State helpers

    private var theme: Theme { Theme(rawValue: controller.settings.environment) ?? .neonCity }
    private var isArena: Bool { theme.mode == .arena }
    private var accent: Color { HUDStyle.color(theme.hudAccent) }
    private var glyphs: ControllerGlyphs { controller.glyphs }
    /// Touch play: no pad connected (the on-screen buttons show, the pad pips hide).
    private var touchPlay: Bool {
        #if os(iOS)
        return !glyphs.connected
        #else
        return false
        #endif
    }

    /// A card (briefing, result, match) owns the screen: the run readouts mean nothing while parked.
    private var cardUp: Bool {
        if controller.matchResult != nil || controller.titleVisible { return true }
        switch controller.mission.phase {
        case .briefing, .rivalIntro, .success, .failed: return true
        default: return false
        }
    }
    private var running: Bool { controller.mission.phase == .running }

    // MARK: - Top row

    /// Job code over the timer (corridor jobs); round and match score on The Grid.
    @ViewBuilder private var topLeft: some View {
        let m = controller.mission
        let s = controller.stats
        if running && m.kind != .duel {
            VStack(alignment: .leading, spacing: 0) {
                Text(m.code).font(HUDStyle.label(HUDStyle.labelSize)).tracking(1.2).foregroundStyle(.white.opacity(0.55))
                Text(String(format: "%02d:%02d", Int(m.timeLeft) / 60, Int(m.timeLeft) % 60))
                    .font(HUDStyle.display(HUDStyle.timerSize)).monospacedDigit()
                    .foregroundStyle(m.timeLeft < 10 ? Color.red : (m.timeLeft < 20 ? HUDStyle.amber : .white))
                    .scaleEffect(m.timeLeft < 5 ? 1.12 : 1, anchor: .leading)
                    .animation(.easeOut(duration: 0.2), value: Int(m.timeLeft))
                    .contentTransition(.numericText(countsDown: true))
            }
        } else if isArena && !cardUp {
            VStack(alignment: .leading, spacing: 0) {
                Text(running && m.kind == .duel ? "DUEL  //  FIRST TO \(m.duelTarget)" : (s.matchTarget == Int.max ? "FREE PLAY" : "ROUND \(s.round)  //  FIRST TO \(s.matchTarget)"))
                    .font(HUDStyle.label(HUDStyle.labelSize)).tracking(1.2).foregroundStyle(.white.opacity(0.55))
                HStack(spacing: 6) {
                    Text(controller.player.callsign).font(HUDStyle.label(HUDStyle.labelSize)).tracking(1).foregroundStyle(HUDStyle.color(controller.player.liveryColor)).padding(.trailing, 2)
                    Text("\(s.wins)").font(HUDStyle.display(HUDStyle.timerSize)).monospacedDigit().foregroundStyle(accent)
                    Text("-").font(HUDStyle.display(HUDStyle.timerSize - 6)).foregroundStyle(.white.opacity(0.5))
                    Text("\(s.losses)").font(HUDStyle.display(HUDStyle.timerSize)).monospacedDigit().foregroundStyle(HUDStyle.rival)
                    Text(s.rival).font(HUDStyle.label(HUDStyle.labelSize)).tracking(1).foregroundStyle(HUDStyle.rival).padding(.leading, 2)
                }
                .contentTransition(.numericText())
            }
        } else {
            Color.clear.frame(width: 1, height: 1)
        }
    }

    /// The hull bar and the job's objective line, near the road's centre so the eye barely moves.
    @ViewBuilder private var topCentre: some View {
        let m = controller.mission
        if running && m.kind != .duel {
            VStack(spacing: 4) {
                bar("HULL", m.energy, m.energy > 0.5 ? accent : (m.energy > 0.25 ? HUDStyle.amber : .red), width: 180, low: m.energy <= 0.25)
                objectiveLine(m)
                if m.helmetArmed { chip("HELMET", HUDStyle.amber) }
                commsLine
            }
        } else if isArena && !cardUp, let z = controller.stats.zone {
            VStack(spacing: 2) {
                Text(z).font(HUDStyle.display(HUDStyle.headingSize)).foregroundStyle(.white)
                Text("STAY INSIDE").font(HUDStyle.label(HUDStyle.labelSize)).tracking(1.5).foregroundStyle(.white.opacity(0.6))
            }
        } else {
            Color.clear.frame(width: 1, height: 1)
        }
    }

    /// The contact's line in the ear: speaker in their colour, the words in white, a hairline under it.
    @ViewBuilder private var commsLine: some View {
        let a = controller.ack
        if !a.commsText.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 10, weight: .semibold))
                Text(a.commsSpeaker).font(HUDStyle.display(HUDStyle.labelSize + 1)).tracking(1.5)
                Text(a.commsText).font(HUDStyle.label(HUDStyle.labelSize + 2)).tracking(0.6).foregroundStyle(.white)
            }
            .foregroundStyle(HUDStyle.color(Rival.named(a.commsSpeaker)?.color ?? Rival.vessColor))
            .padding(.top, 2)
            .id(a.commsText)
            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
            .animation(.easeOut(duration: 0.2), value: a.commsText)
        }
    }

    @ViewBuilder private func objectiveLine(_ m: MissionState) -> some View {
        switch m.kind {
        case .delivery:
            objective(String(format: "%.0f m", m.distanceLeft), "TO DROP", accent)
        case .search:
            HStack(spacing: 10) {
                objective("\(m.beaconsHit)/\(m.beaconsTotal)", "BEACONS  NEED \(m.beaconsRequired)", HUDStyle.pickup)
                objective(String(format: "%.0f m", m.distanceLeft), "", accent)
            }
        case .escape:
            VStack(spacing: 3) {
                HStack(spacing: 10) {
                    objective(String(format: "%.0f m", m.gap), "PURSUER", m.gap < 20 ? .red : HUDStyle.rival)
                    objective(String(format: "%.0f m", m.distanceLeft), "", accent)
                }
                bar("GAP", m.gap / max(1, m.startGap), m.gap < 20 ? .red : HUDStyle.rival, width: 180, low: m.gap < 20)
            }
        case .duel:
            EmptyView()
        case .salvage:
            HStack(spacing: 10) {
                objective("\(m.kills)/\(m.killsRequired)", "TARGETS", m.kills >= m.killsRequired ? accent : HUDStyle.rival)
                objective(String(format: "%.0f m", m.distanceLeft), "", accent)
            }
        case .dive:
            objective(String(format: "%.0f m", m.distanceLeft), "NO WEAPONS", accent)
        }
    }

    private func objective(_ value: String, _ label: String, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(value).font(HUDStyle.display(HUDStyle.headingSize - 2)).monospacedDigit().foregroundStyle(color)
                .contentTransition(.numericText())
            if !label.isEmpty { Text(label).font(HUDStyle.label(HUDStyle.labelSize)).tracking(1.2).foregroundStyle(.white.opacity(0.6)) }
        }
        .animation(.linear(duration: 0.15), value: value)
    }

    /// Score with the streak chip, the respawn pips, then the gear (or the settings panel).
    @ViewBuilder private var topRight: some View {
        let m = controller.mission
        HStack(alignment: .top, spacing: 10) {
            if running && m.kind != .duel {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(m.score)").font(HUDStyle.display(HUDStyle.headingSize)).monospacedDigit()
                            .foregroundStyle(.white).contentTransition(.numericText()).animation(.easeOut(duration: 0.35), value: m.score)
                        streakChip(m.streak)
                    }
                    HStack(spacing: 3) {
                        ForEach(0..<max(0, m.respawnsLeft), id: \.self) { _ in
                            Rectangle().fill(accent.opacity(0.9)).frame(width: 10, height: 3)
                        }
                        if m.respawnsLeft == 0 { Text("NO RESPAWN").font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1).foregroundStyle(.red.opacity(0.9)) }
                    }
                }
            }
            if controller.panelVisible { panel } else { gear }
        }
    }

    private func streakChip(_ streak: Int) -> some View {
        Text("x\(streak)")
            .font(HUDStyle.display(HUDStyle.labelSize + 2)).monospacedDigit()
            .foregroundStyle(.black)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(streak >= 4 ? HUDStyle.reward : accent)
            .clipShape(CutCorner(cut: 4))
            .scaleEffect(streak > 1 ? 1 : 0.9)
            .opacity(streak > 1 ? 1 : 0.5)
            .animation(.spring(duration: 0.22, bounce: 0.4), value: streak)
    }

    // MARK: - Bottom row

    /// Speed, the altitude ladder, and the section name; on The Grid the three meters.
    private var bottomLeft: some View {
        let s = controller.stats
        return VStack(alignment: .leading, spacing: 3) {
            if isArena {
                VStack(alignment: .leading, spacing: 5) {
                    bar("ENERGY", s.energy, s.energy > 0.5 ? accent : (s.energy > 0.25 ? HUDStyle.amber : .red), width: 150, low: s.energy <= 0.25)
                    bar("EDGE", s.edge, s.edge < 0.3 ? .red : HUDStyle.rival, width: 150, low: s.edge < 0.3)
                    bar("GRIND", s.grind, HUDStyle.reward, width: 150)
                }
                .padding(.bottom, 4)
            }
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(String(format: "%.0f", s.speed * 3.6)).font(HUDStyle.display(HUDStyle.speedSize)).monospacedDigit().foregroundStyle(.white)
                Text("KM/H").font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1.5).foregroundStyle(.white.opacity(0.5))
                if !isArena { altitudeLadder(s.altitude).padding(.leading, 6) }
            }
            HStack(spacing: 8) {
                Text(s.section.uppercased()).font(HUDStyle.label(HUDStyle.labelSize)).tracking(1.5).foregroundStyle(accent)
                if isArena { Text(String(format: "%.1f m", s.altitude)).font(HUDStyle.label(HUDStyle.labelSize)).foregroundStyle(.white.opacity(0.5)) }
                if let d = s.decision { Text("ROUTE \(d.uppercased())").font(HUDStyle.label(HUDStyle.labelSize)).tracking(1).foregroundStyle(HUDStyle.pickup) }
            }
            if isArena {
                if let p = s.pickup {
                    HStack(spacing: 6) {
                        Image(systemName: touchPlay ? "hand.tap" : glyphs.a).font(.system(size: 11))
                        Text("\(p)  \(pickupHelp(p))").font(HUDStyle.label(HUDStyle.labelSize)).tracking(0.5)
                    }
                    .foregroundStyle(HUDStyle.pickup)
                }
                if !s.state.isEmpty { Text(s.state).font(HUDStyle.label(HUDStyle.labelSize)).tracking(1).foregroundStyle(s.state.hasPrefix("DEREZZED") ? .red : accent) }
            }
        }
    }

    /// Three ticks that fill with altitude (road hover, mid, ceiling).
    private func altitudeLadder(_ alt: Float) -> some View {
        let t = max(0, min(1, (alt - 1.05) / 4.55))
        return HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Rectangle()
                    .fill(t > Float(i) / 3 + 0.05 ? accent : .white.opacity(0.2))
                    .frame(width: 3, height: 5 + CGFloat(i) * 3)
            }
        }
        .padding(.bottom, 4)
    }

    private func pickupHelp(_ p: String) -> String {
        switch p {
        case "PHASE": return "pass through one wall"
        case "PULSE": return "erase your newest trail"
        default: return ""
        }
    }

    /// "Coming up": the next section change and how far away its mouth is (corridor only).
    @ViewBuilder private var upcomingChip: some View {
        let s = controller.stats
        if !isArena, let u = s.upcoming {
            HStack(spacing: 6) {
                Text(u).font(HUDStyle.display(HUDStyle.labelSize + 2)).tracking(1.2)
                Text("\(Int(s.upcomingDistance)) m").font(HUDStyle.label(HUDStyle.labelSize)).monospacedDigit()
            }
            .foregroundStyle(s.upcomingDistance < 40 ? .black : .white)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(s.upcomingDistance < 40 ? accent : .black.opacity(0.35))
            .overlay(CutCorner(cut: 6).stroke(accent.opacity(0.8), lineWidth: 1))
            .clipShape(CutCorner(cut: 6))
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeOut(duration: 0.18), value: s.upcomingDistance < 40)
        }
    }

    /// Touch: BOOST and FIRE buttons. Pad: glyph pips lit while the action happens. Plus the hint.
    private var bottomRight: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if controller.hintVisible && !cardUp { hint.allowsHitTesting(false) }
            if touchPlay && !cardUp {
                HStack(spacing: 12) {
                    touchButton("BOOST", on: controller.ack.boost) { controller.arView.input.buttonBoost = $0 }
                    touchButton(isArena ? "USE" : "FIRE", on: isArena ? controller.ack.pickup : controller.ack.fire) { controller.arView.input.buttonFire = $0 }
                }
            } else if !cardUp {
                pips.allowsHitTesting(false)
            }
        }
    }

    private func touchButton(_ label: String, on: Bool, press: @escaping (Bool) -> Void) -> some View {
        TouchButton(label: label, on: on, accent: accent, press: press)
    }

    /// Action pips with the pad's own button art: lit while the action is happening.
    private var pips: some View {
        let a = controller.ack
        return HStack(spacing: 8) {
            pip(glyphs.boost, "BOOST", a.boost)
            if isArena {
                pip("arrow.up", "JUMP", a.jump)
                pip("arrow.left.and.right", "SNAP", a.snap)
                pip(glyphs.a, "USE", a.pickup)
            } else {
                pip(glyphs.a, "FIRE", a.fire)
            }
        }
    }

    private func pip(_ symbol: String, _ label: String, _ on: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
            Text(label).font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1)
        }
        .foregroundStyle(on ? .black : .white.opacity(0.6))
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(on ? accent : .black.opacity(0.3))
        .overlay(CutCorner(cut: 5).stroke(on ? accent : .white.opacity(0.25), lineWidth: 1))
        .clipShape(CutCorner(cut: 5))
        .animation(.easeOut(duration: 0.12), value: on)
    }

    // MARK: - Stamps

    /// Centre stamps: section entry, launch, score, pickup use, hit, beacon. Spring in, fade out.
    @ViewBuilder private var stampOverlay: some View {
        let a = controller.ack
        VStack(spacing: 6) {
            if !a.stamp.isEmpty && !cardUp {
                Text(a.stamp)
                    .font(HUDStyle.display(HUDStyle.stampSize)).tracking(2)
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.75), radius: 10)
                    .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                    .id(a.stamp)
                    .transition(.asymmetric(insertion: .scale(scale: 1.5).combined(with: .opacity), removal: .opacity))
            }
            if a.hit {
                Text("HIT")
                    .font(HUDStyle.display(HUDStyle.stampSize)).tracking(3)
                    .foregroundStyle(.red.opacity(0.95))
                    .shadow(color: .red.opacity(0.7), radius: 10)
                    .transition(.scale(scale: 1.4).combined(with: .opacity))
            }
            if a.beacon {
                Text("BEACON +1")
                    .font(HUDStyle.display(HUDStyle.headingSize)).tracking(2)
                    .foregroundStyle(HUDStyle.pickup)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: -40)
        .animation(.spring(duration: 0.25, bounce: 0.35), value: a)
        .allowsHitTesting(false)
    }

    // MARK: - Missions

    @ViewBuilder private var missionOverlay: some View {
        let m = controller.mission
        if let r = controller.matchResult {
            matchCard(r, credits: m.credits)
        }
        switch m.phase {
        case .briefing:
            card(footer: m.browsing ? "LOAD THIS JOB" : "ACCEPT") {
                HStack(alignment: .firstTextBaseline) {
                    Text("CHAPTER \(m.chapter)  //  \(m.chapterTitle)").font(HUDStyle.label(HUDStyle.labelSize)).tracking(2).foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    identityRow(m)
                }
                HStack(alignment: .top, spacing: 14) {
                    // left: the job
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(m.code)  //  \(m.title)").font(HUDStyle.display(HUDStyle.titleSize)).tracking(1).foregroundStyle(accent)
                        row("JOB", "\(m.index + 1)/\(m.count)", "PAY", "\(m.kind == .duel ? "DUEL" : "HULL PAYS")", "CREDITS", "\(m.credits)")
                        if m.cleared { Text("CLEARED  //  REPLAY PAYS HALF").font(HUDStyle.label(HUDStyle.labelSize)).tracking(1).foregroundStyle(HUDStyle.amber) }
                        Text(m.brief).font(HUDStyle.body(HUDStyle.bodySize)).lineSpacing(2).foregroundStyle(.white.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
                        Text(m.goalText).font(HUDStyle.label(HUDStyle.labelSize + 1)).tracking(1).foregroundStyle(accent)
                        if m.kind != .duel {
                            HStack(spacing: 10) {
                                row("BEST", m.bestRank.text, "SILVER", "\(m.silverScore)", "GOLD", "\(m.goldScore)", valueColor: rankColor(m.bestRank))
                            }
                            flagsRow(m.flags, new: [])
                        }
                    }
                    Spacer(minLength: 0)
                    // right: who is talking (and who you will face)
                    VStack(alignment: .center, spacing: 3) {
                        portrait(m.contact, tint: HUDStyle.color(Rival.named(m.contact)?.color ?? Rival.vessColor), size: 52)
                        Text(m.contact).font(HUDStyle.display(HUDStyle.labelSize + 2)).tracking(1.5).foregroundStyle(HUDStyle.color(Rival.named(m.contact)?.color ?? Rival.vessColor))
                        Text(m.contactRole).font(HUDStyle.label(HUDStyle.labelSize - 2)).tracking(1).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                        if m.kind == .duel && !m.rivalName.isEmpty {
                            Text("VS").font(HUDStyle.display(10)).tracking(2).foregroundStyle(.red).padding(.top, 2)
                            portrait(m.rivalName, tint: HUDStyle.color(m.rivalColor), size: 44)
                            Text(m.rivalName).font(HUDStyle.display(HUDStyle.labelSize + 1)).tracking(1.5).foregroundStyle(HUDStyle.color(m.rivalColor))
                            Text("\(m.rivalTemper)  \(m.rivalWins)-\(m.rivalLosses)").font(HUDStyle.label(HUDStyle.labelSize - 2)).tracking(1).monospacedDigit().foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .frame(width: 112)
                }
                loadoutRow(m)
                garage(m)
                inbox(m)
            }
        case .rivalIntro:
            rivalIntroCard(m)
        case .running, .freePlay:
            EmptyView()
        case .success:
            StagedCard(steps: 6) { step in
                card(footer: "NEXT JOB") {
                    Text(m.successTitle).font(HUDStyle.display(HUDStyle.cardTitleSize)).tracking(2).foregroundStyle(accent)
                        .scaleEffect(step >= 1 ? 1 : 1.4, anchor: .leading).opacity(step >= 1 ? 1 : 0)
                    HStack(spacing: 8) {
                        Text(m.callsign).font(HUDStyle.display(HUDStyle.labelSize + 1)).tracking(1.5).foregroundStyle(HUDStyle.color(m.liveryColor))
                        Text("\(m.code)  //  \(m.title)").font(HUDStyle.label(HUDStyle.labelSize + 1)).tracking(1).foregroundStyle(.white.opacity(0.7))
                    }
                    .opacity(step >= 1 ? 1 : 0)
                    if m.kind != .duel {
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text(m.rank.text).font(HUDStyle.display(HUDStyle.cardTitleSize + 8)).tracking(3).foregroundStyle(rankColor(m.rank))
                                .scaleEffect(step >= 2 ? 1 : 1.6, anchor: .leading)
                            stat("SCORE", "\(step >= 3 ? m.score : 0)", .white)
                            if m.rank > .none && m.rank >= m.bestRank { Text("NEW BEST").font(HUDStyle.label(HUDStyle.labelSize)).tracking(1.5).foregroundStyle(HUDStyle.reward).opacity(step >= 3 ? 1 : 0) }
                        }
                        .opacity(step >= 2 ? 1 : 0)
                        flagsRow(m.flags, new: m.newFlags).opacity(step >= 4 ? 1 : 0)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        stat("PAYOUT", "+\(step >= 5 ? m.payout : 0)", accent)
                        stat("CREDITS", "\(step >= 5 ? m.credits : m.credits - m.payout)", .white)
                        if m.kind != .duel { stat("HULL", "\(Int(m.energy * 100))%", .white) }
                        if m.kind == .search { stat("BEACONS", "\(m.beaconsHit)/\(m.beaconsTotal)", HUDStyle.pickup) }
                    }
                    .opacity(step >= 4 ? 1 : 0)
                    if !m.reactiveLine.isEmpty || !m.debrief.isEmpty {
                        hairline(accent.opacity(0.35)).opacity(step >= 5 ? 1 : 0)
                        if !m.reactiveLine.isEmpty {
                            Text("\(m.contact): \(m.reactiveLine)").font(HUDStyle.body(HUDStyle.bodySize)).lineSpacing(2)
                                .foregroundStyle(HUDStyle.color(Rival.named(m.contact)?.color ?? Rival.vessColor)).fixedSize(horizontal: false, vertical: true)
                                .opacity(step >= 5 ? 1 : 0)
                        }
                        if !m.debrief.isEmpty {
                            Text(m.debrief).font(HUDStyle.body(HUDStyle.bodySize)).lineSpacing(2).foregroundStyle(.white.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
                                .opacity(step >= 6 ? 1 : 0)
                        }
                    }
                }
            }
        case .failed:
            card(footer: "RETRY NOW") {
                Text("RUN FAILED").font(HUDStyle.display(HUDStyle.cardTitleSize)).tracking(2).foregroundStyle(.red)
                Text(m.failReason).font(HUDStyle.label(HUDStyle.labelSize + 1)).tracking(1).foregroundStyle(.white.opacity(0.8))
                if !m.reactiveLine.isEmpty {
                    Text("\(m.contact): \(m.reactiveLine)").font(HUDStyle.body(HUDStyle.bodySize)).lineSpacing(2)
                        .foregroundStyle(HUDStyle.color(Rival.named(m.contact)?.color ?? Rival.vessColor)).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Callsign, title and livery swatch. Tap the callsign to type a new one; tap the swatch to cycle the livery.
    @State private var editingCallsign = false
    @State private var callsignDraft = ""
    @FocusState private var callsignFocus: Bool
    private func identityRow(_ m: MissionState) -> some View {
        HStack(spacing: 8) {
            if editingCallsign {
                TextField("CALLSIGN", text: $callsignDraft)
                    .textFieldStyle(.plain)
                    .font(HUDStyle.display(HUDStyle.labelSize + 2)).tracking(1.5)
                    .foregroundStyle(HUDStyle.color(m.liveryColor))
                    .frame(width: 96)
                    .focused($callsignFocus)
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    #endif
                    .onSubmit { controller.setCallsign(callsignDraft); editingCallsign = false }
                    .onChange(of: callsignFocus) { _, f in if !f && editingCallsign { controller.setCallsign(callsignDraft); editingCallsign = false } }
            } else {
                Text(m.callsign).font(HUDStyle.display(HUDStyle.labelSize + 2)).tracking(1.5).foregroundStyle(HUDStyle.color(m.liveryColor))
                    .contentShape(Rectangle())
                    .onTapGesture { callsignDraft = m.callsign; editingCallsign = true; callsignFocus = true }
            }
            Text(m.playerTitle).font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1.5).foregroundStyle(.white.opacity(0.5))
            Rectangle().fill(HUDStyle.color(m.liveryColor)).frame(width: 12, height: 12)
                .overlay(Rectangle().stroke(.white.opacity(0.5), lineWidth: 1))
                .contentShape(Rectangle().inset(by: -8))
                .onTapGesture { controller.cycleLivery() }
        }
    }

    /// Owned upgrades as small chips (the loadout), so the garage list can stay compact.
    @ViewBuilder private func loadoutRow(_ m: MissionState) -> some View {
        let owned = m.upgrades.items.filter { $0.level > 0 }
        if !owned.isEmpty {
            HStack(spacing: 5) {
                Text("LOADOUT").font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(2).foregroundStyle(.white.opacity(0.5))
                ForEach(Array(owned.enumerated()), id: \.offset) { _, item in
                    chip("\(item.title) \(item.level > 1 ? "II" : "I")", accent.opacity(0.85))
                }
            }
        }
    }

    /// The rival's card before a duel: portrait, name, temper, tier, the head-to-head record and a taunt.
    /// The rival's colour takes over; it slams in from the right and the duel starts when it leaves.
    private func rivalIntroCard(_ m: MissionState) -> some View {
        let color = HUDStyle.color(m.rivalColor)
        return HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("DUEL  //  FIRST TO \(m.duelTarget)").font(HUDStyle.label(HUDStyle.labelSize)).tracking(2).foregroundStyle(.white.opacity(0.55))
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(m.rivalName).font(HUDStyle.display(HUDStyle.stampSize)).tracking(4).foregroundStyle(color)
                            .shadow(color: color.opacity(0.7), radius: 10)
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { i in Rectangle().fill(i < (m.rivalSkill == "KEEN" ? 3 : (m.rivalSkill == "SHARP" ? 2 : 1)) ? color : .white.opacity(0.2)).frame(width: 14, height: 3) }
                            Text("\(m.rivalTemper)  //  \(m.rivalSkill)").font(HUDStyle.label(HUDStyle.labelSize)).tracking(1.5).foregroundStyle(.white.opacity(0.75))
                        }
                        Text(m.rivalLine.uppercased()).font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1).foregroundStyle(.white.opacity(0.5))
                    }
                    portrait(m.rivalName, tint: color, size: 96)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(m.callsign).font(HUDStyle.label(HUDStyle.labelSize + 1)).tracking(1.5).foregroundStyle(HUDStyle.color(m.liveryColor))
                    Text("\(m.rivalWins)").font(HUDStyle.display(HUDStyle.headingSize + 4)).monospacedDigit().foregroundStyle(accent)
                    Text("-").font(HUDStyle.display(HUDStyle.headingSize)).foregroundStyle(.white.opacity(0.5))
                    Text("\(m.rivalLosses)").font(HUDStyle.display(HUDStyle.headingSize + 4)).monospacedDigit().foregroundStyle(color)
                    Text(m.rivalName).font(HUDStyle.label(HUDStyle.labelSize + 1)).tracking(1.5).foregroundStyle(color)
                }
                Text(m.rivalTaunt).font(HUDStyle.body(HUDStyle.bodySize + 1)).italic().foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.trailing)
                    .frame(maxWidth: 360, alignment: .trailing)
                // countdown hairline
                ZStack(alignment: .trailing) {
                    Rectangle().fill(.white.opacity(0.15)).frame(width: 200, height: 2)
                    Rectangle().fill(color).frame(width: 200 * CGFloat(max(0, min(1, m.introLeft / MissionRunner.introDuration))), height: 2)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(LinearGradient(colors: [.black.opacity(0.4), .black.opacity(0.78)], startPoint: .leading, endPoint: .trailing))
            .clipShape(CutCorner(cut: 16))
            .overlay(alignment: .top) { hairline(color.opacity(0.9)) }
            .overlay(alignment: .bottom) { hairline(color.opacity(0.4)) }
            .padding(.trailing, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        .animation(.spring(duration: 0.35, bounce: 0.25), value: m.phase)
        .allowsHitTesting(false)
    }

    /// The title screen: the world behind, the wordmark, who you are, the next job, one prompt.
    private var titleScreen: some View {
        let m = controller.mission
        let p = controller.player
        return ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [.black.opacity(0.75), .black.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                Spacer()
                Text("SPEEDER").font(HUDStyle.display(HUDStyle.wordmarkSize)).tracking(10).foregroundStyle(.white)
                    .shadow(color: accent.opacity(0.8), radius: 14)
                Text("COURIER RUNS  //  THE GRID").font(HUDStyle.label(HUDStyle.labelSize + 1)).tracking(3).foregroundStyle(accent)
                hairline(accent.opacity(0.6)).frame(width: 220)
                HStack(spacing: 10) {
                    Text(p.callsign).font(HUDStyle.display(HUDStyle.headingSize)).tracking(2).foregroundStyle(HUDStyle.color(p.liveryColor))
                    Text(m.playerTitle).font(HUDStyle.label(HUDStyle.labelSize)).tracking(1.5).foregroundStyle(.white.opacity(0.55))
                    stat("CREDITS", "\(m.credits)", .white, small: true)
                }
                if !m.code.isEmpty {
                    HStack(spacing: 6) {
                        Text("NEXT").font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(2).foregroundStyle(.white.opacity(0.5))
                        Text("\(m.code)  //  \(m.title)").font(HUDStyle.label(HUDStyle.labelSize + 1)).tracking(1).foregroundStyle(.white.opacity(0.85))
                    }
                }
                PulsingPrompt(glyph: touchPlay ? "hand.tap" : glyphs.a, text: "START", accent: accent)
                    .padding(.top, 8)
            }
            .padding(.leading, HUDStyle.sideInset + 28)
            .padding(.bottom, HUDStyle.bottomInset + 24)
        }
        .contentShape(Rectangle())
        .onTapGesture { controller.startFromTitle() }
        .transition(.opacity)
        .animation(.easeOut(duration: 0.4), value: controller.titleVisible)
    }

    /// The inbox: every unlocked job as a chip (cleared ones ticked), the shown one lit.
    private func inbox(_ m: MissionState) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(m.jobs, id: \.id) { j in
                        let shown = j.id == m.index
                        HStack(spacing: 3) {
                            if j.cleared { Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)) }
                            Text(j.code).font(HUDStyle.label(HUDStyle.labelSize)).tracking(0.5)
                        }
                        .foregroundStyle(shown ? .black : (j.cleared ? .white.opacity(0.6) : .white))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(shown ? accent : .white.opacity(j.cleared ? 0.06 : 0.14))
                        .clipShape(CutCorner(cut: 4))
                        .contentShape(Rectangle())
                        .onTapGesture { controller.browseJob(to: j.id) }
                        .id(j.id)
                    }
                    if !touchPlay {
                        HStack(spacing: 3) {
                            Image(systemName: glyphs.stick).font(.system(size: 10))
                            Text("BROWSE").font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1)
                        }
                        .foregroundStyle(.white.opacity(0.4)).padding(.leading, 4)
                    }
                }
            }
            .onAppear { proxy.scrollTo(m.index, anchor: .center) }
            .onChange(of: m.index) { _, i in withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(i, anchor: .center) } }
        }
    }

    /// The garage: four upgrades with prices, the highlighted row bought with Y or a tap.
    private func garage(_ m: MissionState) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text("GARAGE").font(HUDStyle.label(HUDStyle.labelSize)).tracking(2).foregroundStyle(.white.opacity(0.5))
                if touchPlay {
                    Text("TAP A ROW TO BUY").font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1).foregroundStyle(.white.opacity(0.35))
                } else {
                    Image(systemName: glyphs.y).font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                    Text("BUY").font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1).foregroundStyle(.white.opacity(0.35))
                }
            }
            ForEach(Array(m.upgrades.items.enumerated()), id: \.offset) { i, item in
                let hot = i == m.shopSelection
                let can = !item.owned && m.credits >= item.price
                HStack(spacing: 8) {
                    Rectangle().fill(hot ? accent : .clear).frame(width: 2, height: 10)
                    Text(item.title).font(HUDStyle.label(HUDStyle.labelSize)).tracking(0.8)
                        .frame(width: 96, alignment: .leading)
                    if item.owned {
                        Text("OWNED").font(HUDStyle.label(HUDStyle.labelSize)).tracking(1).foregroundStyle(.white.opacity(0.4))
                    } else {
                        Text(item.level > 0 ? "II" : "I").font(HUDStyle.label(HUDStyle.labelSize)).foregroundStyle(.white.opacity(0.5)).frame(width: 14)
                        Text("\(item.price)").font(HUDStyle.display(HUDStyle.labelSize + 1)).monospacedDigit().foregroundStyle(can ? HUDStyle.amber : .white.opacity(0.5)).frame(width: 40, alignment: .trailing)
                        Text(item.detail).font(HUDStyle.body(HUDStyle.labelSize + 1)).foregroundStyle(.white.opacity(0.6))
                    }
                }
                .foregroundStyle(item.owned ? .white.opacity(0.45) : (hot ? .white : .white.opacity(0.8)))
                .contentShape(Rectangle())
                .onTapGesture { controller.buyUpgrade(at: i) }
            }
            if !m.shopNote.isEmpty { Text(m.shopNote).font(HUDStyle.label(HUDStyle.labelSize)).tracking(0.5).foregroundStyle(HUDStyle.amber) }
        }
    }

    /// Free-play match result on The Grid.
    private func matchCard(_ r: ArenaController.MatchResult, credits: Int) -> some View {
        card(footer: "NEXT MATCH") {
            Text(r.won ? "MATCH WON" : "MATCH LOST").font(HUDStyle.display(HUDStyle.cardTitleSize)).tracking(2).foregroundStyle(r.won ? accent : .red)
            HStack(spacing: 12) {
                portrait(r.rival, tint: HUDStyle.color(Rival.named(r.rival)?.color ?? Rival.vessColor))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(controller.player.callsign).font(HUDStyle.label(HUDStyle.labelSize + 1)).tracking(1.5).foregroundStyle(HUDStyle.color(controller.player.liveryColor))
                        Text("\(r.wins)").font(HUDStyle.display(HUDStyle.titleSize + 4)).foregroundStyle(accent)
                        Text("-").font(HUDStyle.display(HUDStyle.titleSize)).foregroundStyle(.white.opacity(0.5))
                        Text("\(r.losses)").font(HUDStyle.display(HUDStyle.titleSize + 4)).foregroundStyle(HUDStyle.rival)
                        Text(r.rival).font(HUDStyle.label(HUDStyle.labelSize + 1)).tracking(1.5).foregroundStyle(HUDStyle.rival)
                    }
                    Text("\(r.rounds) ROUNDS").font(HUDStyle.label(HUDStyle.labelSize)).tracking(1).foregroundStyle(.white.opacity(0.6))
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                stat("BEST GRIND", String(format: "%.1f s", r.bestGrind), .white)
                stat("LONGEST TRAIL", String(format: "%.0f m", r.longestTrail), .white)
                stat("ENERGY", "\(Int(r.energyLeft * 100))%", .white)
            }
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                stat("CREDITS", "+\(r.credits)", accent)
                stat("TOTAL", "\(credits)", .white)
            }
        }
    }

    // MARK: - Card furniture

    /// Label / value pairs on one line.
    private func row(_ l1: String, _ v1: String, _ l2: String, _ v2: String, _ l3: String, _ v3: String, valueColor: Color = .white) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            stat(l1, v1, valueColor, small: true)
            stat(l2, v2, .white, small: true)
            stat(l3, v3, .white, small: true)
        }
    }

    private func stat(_ label: String, _ value: String, _ color: Color, small: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label).font(HUDStyle.label(HUDStyle.labelSize - (small ? 1 : 0))).tracking(1).foregroundStyle(.white.opacity(0.5))
            Text(value).font(HUDStyle.display(small ? HUDStyle.labelSize + 1 : HUDStyle.headingSize - 2)).monospacedDigit().foregroundStyle(color)
        }
    }

    private func flagsRow(_ flags: Mission.Flags, new: Mission.Flags) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(Mission.Flags.all.enumerated()), id: \.offset) { _, f in
                let has = flags.contains(f.0), isNew = new.contains(f.0)
                Text(f.1).font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1)
                    .foregroundStyle(has ? .black : .white.opacity(0.45))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(has ? (isNew ? HUDStyle.reward : HUDStyle.amber) : .white.opacity(0.08))
                    .clipShape(CutCorner(cut: 3))
            }
        }
    }

    private func chip(_ text: String, _ color: Color) -> some View {
        Text(text).font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1.5).foregroundStyle(.black)
            .padding(.horizontal, 6).padding(.vertical, 2).background(color).clipShape(CutCorner(cut: 3))
    }

    private func hairline(_ color: Color) -> some View { Rectangle().fill(color).frame(height: 1) }

    /// The button prompt at the foot of every card: the pad's button art, or TAP on touch.
    private func prompt(_ action: String) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: touchPlay ? "hand.tap" : glyphs.a).font(.system(size: 13, weight: .semibold))
                Text(action).font(HUDStyle.display(HUDStyle.labelSize + 3)).tracking(1.5)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(accent)
            .clipShape(CutCorner(cut: 7))
            if !touchPlay {
                Text("or F / return").font(HUDStyle.label(HUDStyle.labelSize - 1)).foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.top, 4)
    }

    private func card<Content: View>(footer: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) { content() }
                    .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 6)
            }
            .frame(maxHeight: HUDStyle.cardMaxHeight)
            .fixedSize(horizontal: false, vertical: true)
            prompt(footer).padding(.horizontal, 14).padding(.bottom, 10)
        }
            .frame(width: HUDStyle.cardWidth, alignment: .leading)
            .background(LinearGradient(colors: [.black.opacity(0.72), .black.opacity(0.5)], startPoint: .top, endPoint: .bottom))
            .clipShape(CutCorner(cut: 14))
            .overlay(alignment: .top) { hairline(accent.opacity(0.85)) }
            .overlay(alignment: .bottom) { hairline(accent.opacity(0.4)) }
            .contentShape(Rectangle())
            .onTapGesture { controller.acceptMission() }
            .padding(.leading, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func rankColor(_ r: Mission.Rank) -> Color {
        switch r {
        case .gold: return Color(red: 1.0, green: 0.85, blue: 0.3)
        case .silver: return Color(red: 0.85, green: 0.9, blue: 1.0)
        case .bronze: return Color(red: 0.9, green: 0.6, blue: 0.35)
        case .none: return .white.opacity(0.6)
        }
    }

    /// Portrait badge (Core Text to a texture, cached per name) in a cut-corner frame tinted with the character's colour.
    private func portrait(_ name: String, tint: Color, size: CGFloat = 52) -> some View {
        Image(decorative: Rival.portrait(for: name), scale: 1)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(CutCorner(cut: 8))
            .overlay(CutCorner(cut: 8).stroke(tint.opacity(0.8), lineWidth: 1))
    }

    /// The one meter used everywhere: a label and a 4 pt line, no box.
    private func bar(_ label: String, _ value: Float, _ color: Color, width: CGFloat, low: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(label).font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(1.2).frame(width: 46, alignment: .trailing).foregroundStyle(low ? color : .white.opacity(0.6))
            ZStack(alignment: .leading) {
                Rectangle().fill(.white.opacity(0.14)).frame(width: width, height: 4)
                Rectangle().fill(color).frame(width: CGFloat(max(0, min(1, value))) * width, height: 4)
                    .animation(.linear(duration: 0.1), value: value)
                // hairline ticks at the quarters
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { i in
                        Rectangle().fill(.black.opacity(0.5)).frame(width: 1, height: 4).frame(width: width / 4, alignment: i == 0 ? .leading : .leading)
                    }
                }
                .frame(width: width, alignment: .leading)
                .opacity(0.6)
            }
            .modifier(PulseWhenLow(low: low))
        }
    }

    private var gear: some View {
        Image(systemName: controller.glyphs.connected ? controller.glyphs.menu : "gearshape")
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .onTapGesture { controller.panelVisible = true }
    }

    // MARK: - Settings panel

    private var panel: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("SETTINGS").font(HUDStyle.display(HUDStyle.labelSize + 2)).tracking(2)
                Spacer()
                Image(systemName: "xmark").frame(width: 32, height: 32).contentShape(Rectangle()).onTapGesture { controller.panelVisible = false }
            }
            ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 4) {
            statsBlock
            Divider().overlay(.white.opacity(0.3))
            Text("ENVIRONMENT").bold().foregroundStyle(accent)
            picker("world", \.environment, ["neon city", "canyon", "the grid"])
            toggle("missions (corridor)", \.missions)
            toggle("sound", \.sound)
            toggle("music", \.music)
            if isArena {
                Divider().overlay(.white.opacity(0.3))
                Text("THE GRID").bold().foregroundStyle(accent)
                picker("steering", \.steeringMode, ["analog", "snap 90"])
                picker("jump", \.jumpRule, ["elevated trail", "trail gap"])
                picker("trail", \.trailLength, ["short", "long", "endless"])
                toggle("opponent", \.opponent)
                toggle("grinding", \.grinding)
            }
            Divider().overlay(.white.opacity(0.3))
            Text("VISUAL TOGGLES").bold()
            toggle("road motion", \.roadMotion)
            toggle("buildings", \.buildings)
            toggle("signs", \.signs)
            toggle("emissive neon", \.neon)
            toggle("real lights", \.realLights)
            toggle("reflection fakes", \.reflections)
            toggle("particles", \.particles)
            toggle("camera shake", \.cameraShake)
            toggle("obstacles", \.obstacles)
            Divider().overlay(.white.opacity(0.3))
            toggle("post FX (master)", \.postFX)
            toggle("  fog", \.fog)
            toggle("  bloom", \.bloom)
            toggle("  streaks", \.streaks)
            toggle("  color grade", \.colorGrade)
            toggle("  motion blur", \.motionBlur)
            toggle("  lens FX", \.lensFX)
            toggle("weather", \.weather)
            Divider().overlay(.white.opacity(0.3))
            Text("LOOK VARIANTS").bold()
            picker("obstacles", \.obstacleSkin, ["solid", "holo", "wire", "body+trim"])
            picker("fog", \.fogLevel, ["thin", "normal", "thick"])
            picker("bloom", \.bloomLevel, ["low", "normal", "high"])
            toggle("2nd building row", \.secondRow)
            toggle("storefronts", \.storefronts)
            toggle("bright windows", \.windowsBright)
            toggle("dense tunnel rings", \.tunnelDense)
            picker("rings", \.ringColor, ["mixed", "blue", "red", "amber"])
            picker("palette", \.palette, ["mixed", "cyan/warm", "amber/cool", "painted"])
            picker("hazards", \.hazardColor, ["magenta", "lime", "orange", "white"])
            toggle("red X on barriers", \.hazardX)
            Divider().overlay(.white.opacity(0.3))
            HStack {
                Text("cruise")
                Slider(value: $controller.settings.cruiseSpeed, in: 15...110)
                Text(String(format: "%3.0f", controller.settings.cruiseSpeed))
            }
            }
            }
            #if os(iOS)
            .frame(maxHeight: 300)
            #else
            .frame(maxHeight: 640)
            #endif
        }
        .font(.system(size: HUDStyle.labelSize, weight: .medium, design: .monospaced))
        .padding(10)
        .frame(width: 250)
        .background(.black.opacity(0.6))
        .clipShape(CutCorner(cut: 10))
        .overlay(alignment: .top) { hairline(accent.opacity(0.7)) }
        #if os(macOS)
        .controlSize(.mini)
        #endif
    }

    /// Frame stats, diagnostic: inside the settings panel only.
    private var statsBlock: some View {
        let s = controller.stats
        return VStack(alignment: .leading, spacing: 2) {
            Text(String(format: "%3.0f fps  %5.2f ms", s.fps, s.frameMs))
            Text(String(format: "%.0f m   hits %d   kills %d", s.distance, s.hits, s.kills))
            Text("entities \(s.entities)   lights \(s.lights)")
            Text("post \(controller.settings.postFX ? "on" : "off")  src \(s.sourceFormat)")
            Text("world: \(theme.name)").foregroundStyle(accent)
            if let c = s.controller { Text("pad: \(c)").foregroundStyle(.green.opacity(0.8)) }
            if let err = controller.loadError { Text("error: \(err)").foregroundStyle(.red) }
        }
        .foregroundStyle(.white.opacity(0.7))
    }

    private func toggle(_ label: String, _ key: WritableKeyPath<FXSettings, Bool>) -> some View {
        Toggle(label, isOn: Binding(get: { controller.settings[keyPath: key] },
                                    set: { controller.settings[keyPath: key] = $0 }))
            .toggleStyle(.switch)
    }

    private func picker(_ label: String, _ key: WritableKeyPath<FXSettings, Int>, _ names: [String]) -> some View {
        HStack {
            Text(label)
            Picker("", selection: Binding(get: { controller.settings[keyPath: key] },
                                          set: { controller.settings[keyPath: key] = $0 })) {
                ForEach(0..<names.count, id: \.self) { Text(names[$0]).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    /// Controls hint with the pad's glyphs (first seconds, after a pad connects, and while the panel is open).
    private var hint: some View {
        HStack(spacing: 10) {
            if touchPlay {
                hintItem("hand.draw", isArena ? "LEFT / RIGHT STEER, TOP JUMP" : "POSITION STEERS + CLIMBS")
                hintItem("hand.tap", isArena ? "TAP = PICKUP" : "TAP = FIRE")
            } else {
                hintItem(glyphs.stick, isArena ? "STEER, UP JUMP, DOWN BRAKE" : "STEER + CLIMB")
                hintItem(glyphs.boost, "BOOST")
                hintItem(glyphs.a, isArena ? "PICKUP" : "FIRE")
                hintItem(glyphs.menu, "SETTINGS")
            }
        }
        .foregroundStyle(.white.opacity(0.5))
        .transition(.opacity)
    }

    private func hintItem(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
            Text(text).font(HUDStyle.label(HUDStyle.labelSize - 1)).tracking(0.8)
        }
    }
}

/// Reveals a card in steps 150 ms apart (rank, score, flags, pay, the lines), Alto-style.
private struct StagedCard<Content: View>: View {
    let steps: Int
    @ViewBuilder let content: (Int) -> Content
    @State private var step = 0
    var body: some View {
        content(step)
            .animation(.spring(duration: 0.25, bounce: 0.3), value: step)
            .task {
                step = 0
                for i in 1...steps {
                    try? await Task.sleep(nanoseconds: i == 1 ? 120_000_000 : 170_000_000)
                    step = i
                }
            }
    }
}

/// The start prompt pulsing at the music's tempo (112 bpm).
private struct PulsingPrompt: View {
    let glyph: String
    let text: String
    let accent: Color
    @State private var lit = false
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: glyph).font(.system(size: 14, weight: .semibold))
            Text(text).font(HUDStyle.display(HUDStyle.labelSize + 4)).tracking(2)
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(accent)
        .clipShape(CutCorner(cut: 8))
        .opacity(lit ? 1 : 0.55)
        .onAppear { withAnimation(.easeInOut(duration: 0.536).repeatForever(autoreverses: true)) { lit = true } }
    }
}

/// On-screen action button for touch play: 56 pt, press state, light impact on touch-down.
private struct TouchButton: View {
    let label: String
    let on: Bool
    let accent: Color
    let press: (Bool) -> Void
    @State private var pressed = false
    @State private var presses = 0

    var body: some View {
        ZStack {
            Circle().fill(pressed || on ? accent : .black.opacity(0.35))
            Circle().stroke(accent.opacity(pressed || on ? 1 : 0.7), lineWidth: 1.5)
            Text(label).font(HUDStyle.display(HUDStyle.labelSize)).tracking(1.2).foregroundStyle(pressed || on ? .black : .white.opacity(0.85))
        }
        .frame(width: 56, height: 56)
        .scaleEffect(pressed ? 0.94 : 1)
        .animation(.easeOut(duration: 0.08), value: pressed)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in if !pressed { pressed = true; presses += 1; press(true) } }
            .onEnded { _ in pressed = false; press(false) })
        .sensoryFeedback(.impact(weight: .light), trigger: presses)
    }
}

/// The HUD's type and colour system. Chakra Petch (SIL OFL, bundled) for display and labels; the
/// system face for body copy; tabular digits everywhere a number moves.
enum HUDStyle {
    static let pickup = Color(red: 0.85, green: 0.7, blue: 1.0)
    static let amber = Color(red: 1.0, green: 0.75, blue: 0.25)
    static let rival = Color(red: 1.0, green: 0.55, blue: 0.2)
    static let reward = Color(red: 0.75, green: 1.0, blue: 0.3)
    /// Legacy accent (Neon City's road cyan); the HUD reads the world's accent through `Theme.hudAccent`.
    static let accent = Color(red: 0.35, green: 0.9, blue: 1.0)
    static func color(_ c: SIMD3<Float>) -> Color { Color(red: Double(c.x), green: Double(c.y), blue: Double(c.z)) }

    #if os(iOS)
    static let labelSize: CGFloat = 11
    static let bodySize: CGFloat = 13
    static let headingSize: CGFloat = 20
    static let timerSize: CGFloat = 26
    static let speedSize: CGFloat = 34
    static let stampSize: CGFloat = 40
    static let titleSize: CGFloat = 17
    static let cardTitleSize: CGFloat = 24
    static let cardWidth: CGFloat = 470
    static let cardMaxHeight: CGFloat = 356
    static let wordmarkSize: CGFloat = 56
    static let sideInset: CGFloat = 16
    static let topInset: CGFloat = 12
    static let bottomInset: CGFloat = 10
    #else
    static let labelSize: CGFloat = 11
    static let bodySize: CGFloat = 13
    static let headingSize: CGFloat = 20
    static let timerSize: CGFloat = 28
    static let speedSize: CGFloat = 36
    static let stampSize: CGFloat = 44
    static let titleSize: CGFloat = 18
    static let cardTitleSize: CGFloat = 26
    static let cardWidth: CGFloat = 490
    static let cardMaxHeight: CGFloat = 700
    static let wordmarkSize: CGFloat = 64
    static let sideInset: CGFloat = 16
    static let topInset: CGFloat = 12
    static let bottomInset: CGFloat = 12
    #endif

    static func display(_ size: CGFloat) -> Font { Font.custom("ChakraPetch-Bold", size: size) }
    static func label(_ size: CGFloat) -> Font { Font.custom("ChakraPetch-SemiBold", size: size) }
    static func body(_ size: CGFloat) -> Font { Font.custom("ChakraPetch-Medium", size: size) }

    /// Register the bundled faces once at launch (no Info.plist keys needed on either platform).
    static func registerFonts() {
        for name in ["ChakraPetch-Regular", "ChakraPetch-Medium", "ChakraPetch-SemiBold", "ChakraPetch-Bold"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { print("HUD font missing: \(name)"); continue }
            var err: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &err) {
                print("HUD font \(name): \(err?.takeRetainedValue().localizedDescription ?? "register failed")")
            }
        }
    }
}

/// Tron card frame: one corner cut at 45 degrees.
struct CutCorner: Shape {
    var cut: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = min(cut, min(r.width, r.height) / 2)
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + c))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - c))
        p.closeSubpath()
        return p
    }
}

/// Meters in their low state breathe (a 0.35 s opacity pulse) so the warning reads in peripheral vision.
private struct PulseWhenLow: ViewModifier {
    var low: Bool
    @State private var dim = false
    func body(content: Content) -> some View {
        content
            .opacity(low && dim ? 0.45 : 1)
            .onChange(of: low) { _, on in
                if on { withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) { dim = true } }
                else { withAnimation(.easeOut(duration: 0.1)) { dim = false } }
            }
    }
}
