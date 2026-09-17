import SwiftUI

@main
struct SpeederApp: App {
    @StateObject private var controller = GameController()
    init() { setvbuf(stdout, nil, _IOLBF, 0) }
    /// SPEEDER_WINDOW=1920x1080 fixes the Mac window size (video captures at a known resolution).
    private static let windowSize: CGSize? = {
        let parts = (ProcessInfo.processInfo.environment["SPEEDER_WINDOW"] ?? "")
            .split(whereSeparator: { $0 == "x" || $0 == "," }).compactMap { Double($0) }
        return parts.count == 2 ? CGSize(width: parts[0], height: parts[1]) : nil
    }()

    var body: some Scene {
        WindowGroup("Speeder") {
            ContentView(controller: controller)
                #if os(macOS)
                .frame(minWidth: 960, minHeight: 540)
                .frame(width: Self.windowSize?.width, height: Self.windowSize?.height)
                #endif
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
        #endif
    }
}
