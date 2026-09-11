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
                        pips
                        hint
                    }
                }
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
                meter("ENERGY", s.energy, HUDStyle.accent)
                meter("EDGE", s.edge, s.edge < 0.3 ? .red : .orange)
                meter("GRIND", s.grind, .yellow)
                Text("DEREZZED \(s.losses)   RIVAL \(s.wins)   WALLS \(s.trailSegments)").foregroundStyle(.white.opacity(0.75))
                Text("\(s.section.uppercased())   \(String(format: "%.1f", s.altitude)) m").foregroundStyle(HUDStyle.accent)
                if let p = s.pickup { Text("PICKUP \(p)   A / F TO USE").foregroundStyle(HUDStyle.pickup) }
                if let c = s.controller { Text("PAD \(c.uppercased())").foregroundStyle(.green.opacity(0.8)) }
                if !s.state.isEmpty { Text(s.state).foregroundStyle(s.state.hasPrefix("DEREZZED") ? .red : HUDStyle.accent).bold() }
            } else {
                Text(String(format: "%6.0f m", s.distance)).font(.system(size: HUDStyle.bigSize, weight: .bold, design: .monospaced))
                Text("HITS \(s.hits)   KILLS \(s.kills)   ALT \(String(format: "%.1f", s.altitude)) m").foregroundStyle(.white.opacity(0.75))
                if let c = s.controller { Text("PAD \(c.uppercased())").foregroundStyle(.green.opacity(0.8)) }
                Text(s.section.uppercased()).foregroundStyle(HUDStyle.accent)
                if let d = s.decision { Text("ROUTE \(d.uppercased())").foregroundStyle(HUDStyle.pickup) }
            }
        }
        .hudPanel()
    }

    // MARK: - Missions

    @ViewBuilder private var missionOverlay: some View {
        let m = controller.mission
        switch m.phase {
        case .briefing:
            missionCard {
                HStack(spacing: 10) {
                    contactBadge(m.contact)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(m.code)  //  \(m.title)").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundStyle(HUDStyle.accent)
                        Text("CONTACT \(m.contact)   JOB \(m.index + 1)/\(m.count)   CREDITS \(m.credits)").foregroundStyle(.white.opacity(0.7))
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
                            .foregroundStyle(m.timeLeft < 10 ? .red : .white)
                    }
                    switch m.kind {
                    case .delivery:
                        meter("CARGO", m.cargo, m.cargo > 0.5 ? HUDStyle.accent : .red)
                        Text(String(format: "%4.0f m TO DROP", m.distanceLeft)).font(.system(size: HUDStyle.baseSize + 2, weight: .bold, design: .monospaced)).foregroundStyle(HUDStyle.accent)
                    case .search:
                        Text("BEACONS \(m.beaconsHit)/\(m.beaconsTotal)   NEED \(m.beaconsRequired)").font(.system(size: HUDStyle.baseSize + 3, weight: .bold, design: .monospaced)).foregroundStyle(HUDStyle.pickup)
                        Text(String(format: "%4.0f m", m.distanceLeft)).font(.system(size: HUDStyle.baseSize + 2, weight: .bold, design: .monospaced)).foregroundStyle(HUDStyle.accent)
                    case .escape:
                        Text(String(format: "PURSUER %3.0f m", m.gap)).font(.system(size: HUDStyle.baseSize + 3, weight: .bold, design: .monospaced)).foregroundStyle(m.gap < 20 ? .red : .orange)
                        meter("BOOST", m.boostMeter, m.boostMeter > 0.3 ? HUDStyle.accent : .red)
                        Text(String(format: "%4.0f m", m.distanceLeft)).font(.system(size: HUDStyle.baseSize + 2, weight: .bold, design: .monospaced)).foregroundStyle(HUDStyle.accent)
                    case .duel:
                        Text("FIRST TO \(m.duelTarget)    YOU \(m.duelWins)  -  \(m.duelLosses) \(m.contact)").font(.system(size: HUDStyle.baseSize + 4, weight: .bold, design: .monospaced)).foregroundStyle(HUDStyle.accent)
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
                Text("PAYOUT +\(m.payout)   CREDITS \(m.credits)" + (m.kind == .delivery ? "   CARGO \(Int(m.cargo * 100))%" : m.kind == .search ? "   BEACONS \(m.beaconsHit)/\(m.beaconsTotal)" : "")).foregroundStyle(.white)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { controller.acceptMission() }
    }

    /// Placeholder for the avatar portrait: initials in a ring. Replaced by a rendered avatar later.
    private func contactBadge(_ name: String) -> some View {
        Text(String(name.prefix(2)))
            .font(.system(size: 14, weight: .black, design: .monospaced))
            .frame(width: 40, height: 40)
            .background(Circle().fill(HUDStyle.accent.opacity(0.15)))
            .overlay(Circle().stroke(HUDStyle.accent, lineWidth: 1.5))
    }

    /// The one meter used everywhere: label, 110 x 6 bar, coloured fill.
    private func meter(_ label: String, _ value: Float, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.system(size: HUDStyle.baseSize - 1, weight: .bold, design: .monospaced)).frame(width: 48, alignment: .leading).foregroundStyle(.white.opacity(0.75))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.15)).frame(width: 110, height: 6)
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: CGFloat(max(0, min(1, value))) * 110, height: 6)
            }
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
                Text("grid: stick steers (snap mode: flick), up = jump, down = brake, R2 boost (uses energy), A = pickup, Menu = settings  •  touch: left/right steer, top jump, two fingers boost")
                #endif
            } else {
                #if os(macOS)
                Text("pad: L-stick steer/climb, R2 boost, A fire  •  keys: arrows/WASD steer+climb, [ ] cruise, shift boost, F fire, P screenshot")
                #else
                Text("pad: L-stick steer/climb, R2 boost, A fire, Menu = settings  •  touch: position steers/climbs, two fingers boost, tap top-right corner = settings")
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
    #if os(iOS)
    static let baseSize: CGFloat = 11
    static let bigSize: CGFloat = 22
    #else
    static let baseSize: CGFloat = 10
    static let bigSize: CGFloat = 20
    #endif
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
