import SwiftUI

/// Diagnostic overlay: frame stats plus the technique toggles from brief §37.
struct HUDView: View {
    @ObservedObject var controller: GameController

    var body: some View {
        ZStack(alignment: .topLeading) {
            statsBlock
                .padding(12)
                .padding(.top, 4)
            VStack {
                HStack {
                    Spacer()
                    if controller.panelVisible { panel } else { gear }
                }
                Spacer()
                HStack(alignment: .bottom) {
                    raceBlock
                    Spacer()
                    hint
                }
            }
            .padding(12)
            if controller.stats.flash > 0.25 {
                Text("HIT")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.red.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        #if os(iOS)
        .controlSize(.mini)
        #endif
        .foregroundStyle(.white.opacity(0.9))
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
        .padding(8)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
    }

    private var isArena: Bool { (Theme(rawValue: controller.settings.environment) ?? .neonCity).mode == .arena }

    private var raceBlock: some View {
        let s = controller.stats
        return VStack(alignment: .leading, spacing: 2) {
            if isArena {
                Text(String(format: "%4.0f km/h", s.speed * 3.6)).font(.system(size: 20, weight: .bold, design: .monospaced))
                meter("energy", s.energy, .cyan)
                meter("edge", s.edge, s.edge < 0.3 ? .red : .orange)
                meter("grind", s.grind, .yellow)
                Text("derezzed \(s.losses)   opponent derezzed \(s.wins)   walls \(s.trailSegments)")
                if let p = s.pickup { Text("pickup: \(p)  (A / F to use)").foregroundStyle(.purple) }
                if let c = s.controller { Text("pad: \(c)").foregroundStyle(.green) }
                if !s.state.isEmpty { Text(s.state).foregroundStyle(s.state.hasPrefix("DEREZZED") ? .red : .cyan).bold() }
            } else {
                Text(String(format: "%6.0f m", s.distance)).font(.system(size: 20, weight: .bold, design: .monospaced))
                Text("hits \(s.hits)   kills \(s.kills)   alt \(String(format: "%.1f", s.altitude)) m")
                if let c = s.controller { Text("pad: \(c)").foregroundStyle(.green) }
                Text(s.section.uppercased()).foregroundStyle(.cyan)
                if let d = s.decision { Text("route: \(d)").foregroundStyle(.pink) }
            }
        }
        .padding(8)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
    }

    private func meter(_ label: String, _ value: Float, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label).frame(width: 44, alignment: .leading)
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
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
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
            Text("ENVIRONMENT").bold().foregroundStyle(.cyan)
            picker("world", \.environment, ["neon city", "canyon", "the grid"])
            if isArena {
                Divider().overlay(.white.opacity(0.3))
                Text("THE GRID").bold().foregroundStyle(.cyan)
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
        .padding(10)
        .frame(width: 250)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
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
    }
}
