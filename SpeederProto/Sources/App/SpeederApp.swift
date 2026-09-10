import SwiftUI

@main
struct SpeederApp: App {
    @StateObject private var controller = GameController()
    init() { setvbuf(stdout, nil, _IOLBF, 0) }

    var body: some Scene {
        WindowGroup("Speeder") {
            ContentView(controller: controller)
                #if os(macOS)
                .frame(minWidth: 960, minHeight: 540)
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
