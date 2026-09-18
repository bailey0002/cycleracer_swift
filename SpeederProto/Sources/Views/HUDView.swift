import SwiftUI

/// Diagnostic overlay: frame stats plus the technique toggles from brief §37.
struct HUDView: View {
    @ObservedObject var controller: GameController

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showStats {
                statsBlock
                    .padding(12)
                    .padding(.top, 4)
            }
            VStack {
                HStack {
                    Spacer()
                    if controller.panelVisible { panel } else { gear }
                }
                Spacer()
                HStack(alignment: .bottom) {
                    raceBlock
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        upcomingChip
                        pips
                        if controller.hintVisible { hint }
                    }
                }
                .allowsHitTesting(false)
            }
            .padding(12)
            missionOverlay
            stampOverlay
        }
        .font(.system(size: HUDStyle.baseSize, weight: .medium, design: .monospaced))
        #if os(iOS)
        .controlSize(.mini)
        #endif
        .foregroundStyle(.white.opacity(0.9))
    }

    /// The frame-stats block is diagnostic: always on the Mac, only with the settings panel on the phone.
    private var showStats: Bool {
        #if os(iOS)
        return controller.panelVisible
        #else
        return true
        #endif
    }

    /// "Coming up" chip: the next section change and how far away its mouth is (corridor only).
    @ViewBuilder private var upcomingChip: some View {
        let s = controller.stats
        if !isArena, let u = s.upcoming {
            Text("\(u)  IN \(Int(s.upcomingDistance)) m")
                .font(.system(size: HUDStyle.baseSize + 1, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(HUDStyle.accent.opacity(s.upcomingDistance < 40 ? 1 : 0.75)))
                .transition(.opacity)
        }
    }

    /// What a held pickup does, next to its name.
    private func pickupHelp(_ p: String) -> String {
        switch p {
        case "PHASE": return "pass through one wall"
        case "PULSE": return "erase your newest trail"
        default: return ""
        }
    }

    // MARK: - Acknowledgement (same frame as the action)

    /// Action pips: lit while the action is happening, dim otherwise. Only the actions of the current mode.
    private var pips: some View {
        let a = controller.ack
        return HStack(spacing: 6) {
            pip("BOOST", a.boost)
            if isArena {
                pip("JUMP", a.jump)
                pip("SNAP", a.snap)
                pip("PICKUP", a.pickup)
            } else {
                pip("FIRE", a.fire)
            }
        }
    }

    private func pip(_ label: String, _ on: Bool) -> some View {
        Text(label)
            .font(.system(size: HUDStyle.baseSize - 1, weight: .bold, design: .monospaced))
            .foregroundStyle(on ? .black : .white.opacity(0.5))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 4).fill(on ? HUDStyle.accent : .black.opacity(0.45)))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(on ? HUDStyle.accent : .white.opacity(0.25), lineWidth: 1))
            .animation(.easeOut(duration: 0.12), value: on)
    }

    /// Centre stamps: section entry, launch, pickup use, hit, beacon.
    @ViewBuilder private var stampOverlay: some View {
        let a = controller.ack
        VStack(spacing: 6) {
            if !a.stamp.isEmpty {
                Text(a.stamp)
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .foregroundStyle(HUDStyle.accent)
                    .shadow(color: HUDStyle.accent.opacity(0.7), radius: 8)
                    .transition(.opacity.combined(with: .scale(scale: 1.15)))
            }
            if a.hit {
                Text("HIT")
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundStyle(.red.opacity(0.95))
                    .transition(.opacity)
            }
            if a.beacon {
                Text("BEACON +1")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(HUDStyle.pickup)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: -40)
        .animation(.easeOut(duration: 0.15), value: a)
        .allowsHitTesting(false)
    }

    private var statsBlock: some View {
        let s = controller.stats
        return VStack(alignment: .leading, spacing: 2) {
            Text(String(format: "%3.0f fps  %5.2f ms", s.fps, s.frameMs))
            Text(String(format: "speed %4.0f km/h  (%3.0f m/s)", s.speed * 3.6, s.speed))
            Text("entities \(s.entities)   lights \(s.lights)")
            Text("post \(controller.settings.postFX ? "on" : "off")  src \(s.sourceFormat)")
            Text("world: \((Theme(rawValue: controller.settings.environment) ?? .neonCity).name)").foregroundStyle(.cyan)
            if let c = s.controller { Text("pad: \(c)").foregroundStyle(.green.opacity(0.8)) }
            if let err = controller.loadError { Text("error: \(err)").foregroundStyle(.red) }
        }
        .hudPanel()
    }

    private var isArena: Bool { (Theme(rawValue: controller.settings.environment) ?? .neonCity).mode == .arena }

    private var raceBlock: some View {
        let s = controller.stats
        return VStack(alignment: .leading, spacing: 2) {
            if isArena {
                Text(String(format: "%4.0f km/h", s.speed * 3.6)).font(.system(size: HUDStyle.bigSize, weight: .bold, design: .monospaced))
                meter("ENERGY", s.energy, s.energy > 0.5 ? HUDStyle.accent : (s.energy > 0.25 ? HUDStyle.amber : .red), low: s.energy <= 0.25)
                meter("EDGE", s.edge, s.edge < 0.3 ? .red : .orange, low: s.edge < 0.3)
                meter("GRIND", s.grind, .yellow)
                if s.matchTarget == Int.max {
                    Text("YOU \(s.wins)  -  \(s.losses) \(s.rival)").font(.system(size: HUDStyle.baseSize + 2, weight: .bold, design: .monospaced))
                } else {
                    Text("ROUND \(s.round)   FIRST TO \(s.matchTarget)").foregroundStyle(.white.opacity(0.75))
                    Text("YOU \(s.wins)  -  \(s.losses) \(s.rival)").font(.system(size: HUDStyle.baseSize + 2, weight: .bold, design: .monospaced))
                }
                Text("\(s.section.uppercased())   \(String(format: "%.1f", s.altitude)) m").foregroundStyle(HUDStyle.accent)
                if let p = s.pickup { Text("PICKUP \(p)   A / F / TAP: \(pickupHelp(p))").foregroundStyle(HUDStyle.pickup) }
                if let z = s.zone { Text("\(z)   STAY INSIDE").foregroundStyle(.white).bold() }
                if !s.state.isEmpty { Text(s.state).foregroundStyle(s.state.hasPrefix("DEREZZED") ? .red : HUDStyle.accent).bold() }
            } else {
                Text(String(format: "%4.0f km/h", s.speed * 3.6)).font(.system(size: HUDStyle.bigSize, weight: .bold, design: .monospaced))
                Text(String(format: "%6.0f m   HITS %d   KILLS %d   ALT %.1f m", s.distance, s.hits, s.kills, s.altitude)).foregroundStyle(.white.opacity(0.75))
                Text(s.section.uppercased()).foregroundStyle(HUDStyle.accent)
                if let d = s.decision { Text("ROUTE \(d.uppercased())").foregroundStyle(HUDStyle.pickup) }
            }
        }
        .hudPanel()
    }

    // MARK: - Missions

    @ViewBuilder private var missionOverlay: some View {
        let m = controller.mission
        if let r = controller.matchResult {
            matchCard(r, credits: m.credits)
        }
        switch m.phase {
        case .briefing:
            missionCard {
                HStack(spacing: 10) {
                    portrait(m.contact)
                    if m.kind == .duel && !m.rivalName.isEmpty {
                        Text("VS").font(.system(size: 12, weight: .black, design: .monospaced)).foregroundStyle(.red)
                        portrait(m.rivalName)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(m.code)  //  \(m.title)").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundStyle(HUDStyle.accent)
                        Text("CONTACT \(m.contact)   JOB \(m.index + 1)/\(m.count)   CREDITS \(m.credits)").foregroundStyle(.white.opacity(0.7))
                        if m.kind != .duel {
                            Text("BEST RANK \(m.bestRank.text)   SILVER \(m.silverScore)   GOLD \(m.goldScore)").foregroundStyle(rankColor(m.bestRank))
                            Text("FLAGS \(m.flags.text)").foregroundStyle(HUDStyle.amber)
                        }
                        if m.kind == .duel && !m.rivalName.isEmpty {
                            Text("RIVAL \(m.rivalName)  //  \(m.rivalTemper): \(m.rivalLine)").foregroundStyle(.orange)
                        }
                    }
                }
                Text(m.brief).font(.system(size: HUDStyle.baseSize + 1, design: .monospaced)).fixedSize(horizontal: false, vertical: true)
                Text(m.goalText).foregroundStyle(HUDStyle.accent)
                prompt("ACCEPT")
            }
        case .running:
            VStack {
                HStack(spacing: 14) {
                    if m.kind != .duel {
                        Text(String(format: "%3.0f s", m.timeLeft)).font(.system(size: HUDStyle.bigSize, weight: .bold, design: .monospaced))
                            .foregroundStyle(m.timeLeft < 10 ? .red : (m.timeLeft < 20 ? HUDStyle.amber : .white))
                            .scaleEffect(m.timeLeft < 5 ? 1.15 : 1)
                            .animation(.easeOut(duration: 0.2), value: Int(m.timeLeft))
                    }
                    if m.kind != .duel { meter("HULL", m.energy, m.energy > 0.5 ? HUDStyle.accent : (m.energy > 0.25 ? HUDStyle.amber : .red), low: m.energy <= 0.25) }
                    if m.kind != .duel {
                        Text("\(m.score)  x\(m.streak)").font(.system(size: HUDStyle.baseSize + 3, weight: .bold, design: .monospaced)).foregroundStyle(m.streak >= 4 ? .yellow : .white)
                        Text("RESPAWN \(m.respawnsLeft)").foregroundStyle(m.respawnsLeft > 0 ? .white.opacity(0.6) : .red)
                    }
                    switch m.kind {
                    case .delivery:
                        Text(String(format: "%4.0f m TO DROP", m.distanceLeft)).font(.system(size: HUDStyle.baseSize + 2, weight: .bold, design: .monospaced)).foregroundStyle(HUDStyle.accent)
                    case .search:
                        Text("BEACONS \(m.beaconsHit)/\(m.beaconsTotal)   NEED \(m.beaconsRequired)").font(.system(size: HUDStyle.baseSize + 3, weight: .bold, design: .monospaced)).foregroundStyle(HUDStyle.pickup)
                        Text(String(format: "%4.0f m", m.distanceLeft)).font(.system(size: HUDStyle.baseSize + 2, weight: .bold, design: .monospaced)).foregroundStyle(HUDStyle.accent)
                    case .escape:
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "PURSUER %3.0f m", m.gap)).font(.system(size: HUDStyle.baseSize + 3, weight: .bold, design: .monospaced)).foregroundStyle(m.gap < 20 ? .red : .orange)
                            meter("GAP", m.gap / max(1, m.startGap), m.gap < 20 ? .red : .orange, low: m.gap < 20)
                        }
                        Text(String(format: "%4.0f m", m.distanceLeft)).font(.system(size: HUDStyle.baseSize + 2, weight: .bold, design: .monospaced)).foregroundStyle(HUDStyle.accent)
                    case .duel:
                        Text("FIRST TO \(m.duelTarget)    YOU \(m.duelWins)  -  \(m.duelLosses) \(m.rivalName)").font(.system(size: HUDStyle.baseSize + 4, weight: .bold, design: .monospaced)).foregroundStyle(HUDStyle.accent)
                    }
                }
                .padding(.horizontal, 4)
                .hudPanel()
                .padding(.top, 8)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .center)
        case .success:
            missionCard {
                Text(m.successTitle).font(.system(size: 22, weight: .black, design: .monospaced)).foregroundStyle(HUDStyle.accent)
                Text("\(m.code)  //  \(m.title)").foregroundStyle(.white.opacity(0.8))
                Text("PAYOUT +\(m.payout)   CREDITS \(m.credits)" + (m.kind == .duel ? "" : "   HULL \(Int(m.energy * 100))%") + (m.kind == .search ? "   BEACONS \(m.beaconsHit)/\(m.beaconsTotal)" : "")).foregroundStyle(.white)
                if m.kind != .duel {
                    Text("SCORE \(m.score)   RANK \(m.rank.text)" + (m.rank > .none && m.rank >= m.bestRank ? "   NEW BEST" : "")).font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(rankColor(m.rank))
                    Text("FLAGS \(m.flags.text)" + (m.newFlags.isEmpty ? "" : "   NEW: \(m.newFlags.text)")).foregroundStyle(HUDStyle.amber)
                }
                prompt("NEXT JOB")
            }
        case .failed:
            missionCard {
                Text("RUN FAILED").font(.system(size: 22, weight: .black, design: .monospaced)).foregroundStyle(.red)
                Text(m.failReason).foregroundStyle(.white.opacity(0.8))
                prompt("RETRY")
            }
        case .freePlay:
            EmptyView()
        }
    }

    /// Free-play match result on The Grid, in the mission card style: the score line, what the
    /// match was made of, and the credits it paid into the same purse as the jobs.
    private func matchCard(_ r: ArenaController.MatchResult, credits: Int) -> some View {
        missionCard {
            Text(r.won ? "MATCH WON" : "MATCH LOST").font(.system(size: 22, weight: .black, design: .monospaced)).foregroundStyle(r.won ? HUDStyle.accent : .red)
            HStack(spacing: 10) {
                portrait(r.rival)
                VStack(alignment: .leading, spacing: 2) {
                    Text("YOU \(r.wins)  -  \(r.losses) \(r.rival)").font(.system(size: 16, weight: .black, design: .monospaced))
                    Text("ROUNDS \(r.rounds)").foregroundStyle(.white.opacity(0.7))
                }
            }
            Text(String(format: "BEST GRIND %.1f s   LONGEST TRAIL %.0f m   ENERGY %d%%", r.bestGrind, r.longestTrail, Int(r.energyLeft * 100))).foregroundStyle(.white.opacity(0.85))
            Text("CREDITS +\(r.credits)   TOTAL \(credits)").foregroundStyle(HUDStyle.accent)
            prompt("NEXT MATCH")
        }
    }

    /// The button prompt at the foot of every card, in the accent colour so it reads as the one thing to do.
    private func prompt(_ action: String) -> some View {
        HStack(spacing: 8) {
            Text("A / F / TAP").font(.system(size: HUDStyle.baseSize, weight: .bold, design: .monospaced)).foregroundStyle(.black)
                .padding(.horizontal, 6).padding(.vertical, 2).background(RoundedRectangle(cornerRadius: 4).fill(HUDStyle.accent))
            Text(action).font(.system(size: HUDStyle.baseSize + 2, weight: .bold, design: .monospaced)).foregroundStyle(.white)
        }
        .padding(.top, 2)
    }

    private func missionCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) { content() }
            .padding(6)
            .frame(width: 360)
            .hudPanel(opacity: 0.7)
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

    /// Portrait badge rendered through the sign pipeline (Core Text to a texture, cached per name):
    /// a helmet with a visor in the character's colour, the temper glyph for rivals.
    private func portrait(_ name: String) -> some View {
        Image(decorative: Rival.portrait(for: name), scale: 1)
            .resizable()
            .interpolation(.high)
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// The one meter used everywhere: label, 110 x 6 bar, coloured fill.
    private func meter(_ label: String, _ value: Float, _ color: Color, low: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.system(size: HUDStyle.baseSize - 1, weight: .bold, design: .monospaced)).frame(width: 48, alignment: .leading).foregroundStyle(low ? color : .white.opacity(0.75))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.15)).frame(width: 110, height: 6)
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: CGFloat(max(0, min(1, value))) * 110, height: 6)
            }
            .modifier(PulseWhenLow(low: low))
        }
    }

    private var gear: some View {
        Image(systemName: "gearshape.fill")
            .font(.system(size: 22))
            .frame(width: 48, height: 48)
            .hudPanel()
            .contentShape(Rectangle())
            .onTapGesture { controller.panelVisible = true }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("SETTINGS").bold()
                Spacer()
                Text("scroll").foregroundStyle(.white.opacity(0.5))
                Image(systemName: "xmark").frame(width: 32, height: 32).contentShape(Rectangle()).onTapGesture { controller.panelVisible = false }
            }
            ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 4) {
            Divider().overlay(.white.opacity(0.3))
            Text("ENVIRONMENT").bold().foregroundStyle(HUDStyle.accent)
            picker("world", \.environment, ["neon city", "canyon", "the grid"])
            toggle("missions (corridor)", \.missions)
            toggle("sound", \.sound)
            if isArena {
                Divider().overlay(.white.opacity(0.3))
                Text("THE GRID").bold().foregroundStyle(HUDStyle.accent)
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
        .padding(2)
        .frame(width: 250)
        .hudPanel()
        #if os(macOS)
        .controlSize(.mini)
        #endif
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

    private var hint: some View {
        Group {
            if isArena {
                #if os(macOS)
                Text("grid: L-stick / arrows steer (snap mode: flick), up = jump, down = brake, R2 / shift boost (uses energy), A / F = use pickup")
                #else
                Text("grid: stick steers (snap mode: flick), up = jump, down = brake, R2 boost (uses energy), A = pickup, Menu = settings  •  touch: left/right steer, top jump, two fingers boost, tap = pickup")
                #endif
            } else {
                #if os(macOS)
                Text("pad: L-stick steer/climb, R2 boost, A fire  •  keys: arrows/WASD steer+climb, [ ] cruise, shift boost, F fire, P screenshot")
                #else
                Text("pad: L-stick steer/climb, R2 boost, A fire, Menu = settings  •  touch: position steers/climbs, two fingers boost, tap = fire, gear = settings")
                #endif
            }
        }
        .font(.system(size: HUDStyle.baseSize - 2, design: .monospaced))
        .foregroundStyle(.white.opacity(0.45))
        .multilineTextAlignment(.trailing)
        .frame(maxWidth: 420, alignment: .trailing)
    }
}

/// The HUD's one visual language: dark panel, thin accent stroke, monospaced type, cyan accent,
/// violet for pickups and beacons, red for danger. Sizes are tuned for a 390 pt tall phone.
enum HUDStyle {
    static let accent = Color(red: 0.35, green: 0.9, blue: 1.0)
    static let pickup = Color(red: 0.85, green: 0.7, blue: 1.0)
    static let amber = Color(red: 1.0, green: 0.75, blue: 0.25)
    #if os(iOS)
    static let baseSize: CGFloat = 11
    static let bigSize: CGFloat = 22
    #else
    static let baseSize: CGFloat = 10
    static let bigSize: CGFloat = 20
    #endif
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

private struct HUDPanel: ViewModifier {
    var opacity: Double
    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(.black.opacity(opacity), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(HUDStyle.accent.opacity(0.35), lineWidth: 1))
    }
}

extension View {
    func hudPanel(opacity: Double = 0.55) -> some View { modifier(HUDPanel(opacity: opacity)) }
}
