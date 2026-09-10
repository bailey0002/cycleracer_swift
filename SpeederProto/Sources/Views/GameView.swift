import SwiftUI
import RealityKit

#if os(macOS)
struct GameView: NSViewRepresentable {
    let controller: GameController
    func makeNSView(context: Context) -> GameARView { controller.arView }
    func updateNSView(_ nsView: GameARView, context: Context) {}
}
#else
struct GameView: UIViewRepresentable {
    let controller: GameController
    func makeUIView(context: Context) -> GameARView {
        let v = controller.arView
        // SwiftUI owns touches on iOS so the HUD controls stay interactive; steering
        // comes from the SpatialEventGesture attached in ContentView.
        v.isUserInteractionEnabled = false
        return v
    }
    func updateUIView(_ uiView: GameARView, context: Context) {}
}
#endif
