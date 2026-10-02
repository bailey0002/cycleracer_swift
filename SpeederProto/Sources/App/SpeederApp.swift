import SwiftUI
import QuartzCore

@main
struct SpeederApp: App {
    /// Process start, as early as Swift sees it (the load log measures from here).
    static let launchTime = CACurrentMediaTime()
    @StateObject private var controller = GameController()
    init() { _ = Self.launchTime; setvbuf(stdout, nil, _IOLBF, 0); HUDStyle.registerFonts() }

    /// The unit-test host: no scene, no world build (the tests drive the pure game logic directly).
    static let testHost = ProcessInfo.processInfo.environment["SPEEDER_TESTS"] == "1"

    var body: some Scene {
        WindowGroup("Kerb: Galactic") {
            if Self.testHost {
                Text("SpeederProto tests").frame(width: 320, height: 120)
            } else {
                ContentView(controller: controller)
                    #if os(macOS)
                    .frame(minWidth: 960, minHeight: 540)
                    #endif
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject var controller: GameController
    var body: some View {
        ZStack {
            #if os(iOS)
            GeometryReader { geo in
                GameView(controller: controller)
                    .gesture(SpatialEventGesture(coordinateSpace: .local)
                        .onChanged { controller.handleTouches($0, in: geo.size) }
                        .onEnded { controller.handleTouches($0, in: geo.size) })
            }
            .ignoresSafeArea()
            #else
            GameView(controller: controller)
                .ignoresSafeArea()
            #endif
            HUDView(controller: controller)
        }
        .preferredColorScheme(.dark)
        #if os(iOS)
        .persistentSystemOverlays(.hidden)
        .statusBarHidden(true)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        #endif
    }
}
