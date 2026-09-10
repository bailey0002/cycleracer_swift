import Foundation
import RealityKit
import GameController
import CoreHaptics
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Normalised input shared between the platform view, the gamepad poller and the controller.
final class InputState {
    // keyboard
    var left = false, right = false, up = false, down = false, boost = false, fire = false
    var speedUp = false, speedDown = false
    // pointer / touch
    var pointerSteer: Float? = nil
    var pointerClimb: Float? = nil
    var pointerBoost = false
    // gamepad (polled each frame)
    var padSteer: Float? = nil
    var padClimb: Float = 0
    var padBoost = false
    var padFire = false
    var screenshotRequested = false
    var panelToggleRequested = false
    var menuWasDown = false

    var steering: Float {
        if let p = padSteer { return p }
        if let p = pointerSteer { return p }
        return (right ? 1 : 0) - (left ? 1 : 0)
    }
    /// -1 dive ... +1 climb
    var climb: Float {
        if padSteer != nil { return padClimb }
        if let p = pointerClimb { return p }
        return (up ? 1 : 0) - (down ? 1 : 0)
    }
    var boosting: Bool { boost || pointerBoost || padBoost }
    var firing: Bool { fire || padFire }
}

/// Polls the first connected extended gamepad (Backbone, PlayStation, Xbox...) and
/// drives controller haptics when available.
final class GamepadInput {
    private var hapticEngine: CHHapticEngine?
    private var hapticController: GCController?
    private(set) var connectedName: String? = nil

    init() {
        NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] n in
            if let c = n.object as? GCController { self?.connectedName = c.vendorName ?? "controller" }
        }
        NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            self?.connectedName = GCController.controllers().first?.vendorName
            self?.hapticEngine = nil
            self?.hapticController = nil
        }
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
        connectedName = GCController.controllers().first?.vendorName
    }

    func poll(into input: InputState) {
        guard let controller = GCController.current ?? GCController.controllers().first,
              let gp = controller.extendedGamepad else {
            input.padSteer = nil
            input.padClimb = 0
            input.padBoost = false
            input.padFire = false
            return
        }
        func dz(_ v: Float) -> Float { abs(v) < 0.12 ? 0 : v }
        var steer = dz(gp.leftThumbstick.xAxis.value)
        var climb = dz(gp.leftThumbstick.yAxis.value)
        if gp.dpad.left.isPressed { steer = -1 }
        if gp.dpad.right.isPressed { steer = 1 }
        if gp.dpad.up.isPressed { climb = 1 }
        if gp.dpad.down.isPressed { climb = -1 }
        input.padSteer = steer
        input.padClimb = climb
        input.padBoost = gp.rightTrigger.value > 0.3 || gp.rightShoulder.isPressed
        input.padFire = gp.buttonA.isPressed || gp.leftTrigger.value > 0.3 || gp.buttonX.isPressed
        input.speedUp = gp.buttonY.isPressed
        input.speedDown = gp.buttonB.isPressed
        let menu = gp.buttonMenu.isPressed || gp.buttonOptions?.isPressed == true
        if menu && !input.menuWasDown { input.panelToggleRequested = true }
        input.menuWasDown = menu
    }

    /// Short rumble on the controller (and the phone when touch-only).
    func rumble(intensity: Float, sharpness: Float = 0.5) {
        #if os(iOS)
        if GCController.controllers().isEmpty {
            let gen = UIImpactFeedbackGenerator(style: intensity > 0.6 ? .heavy : .medium)
            gen.impactOccurred(intensity: CGFloat(intensity))
            return
        }
        #endif
        guard let controller = GCController.current ?? GCController.controllers().first else { return }
        if hapticController !== controller || hapticEngine == nil {
            hapticController = controller
            hapticEngine = controller.haptics?.createEngine(withLocality: .default)
            try? hapticEngine?.start()
        }
        guard let engine = hapticEngine else { return }
        do {
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ], relativeTime: 0)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // haptics are best-effort
        }
    }
}

#if os(macOS)
/// Non-AR RealityKit view with keyboard + mouse. Arrows/WASD steer & climb,
/// [ ] cruise speed, shift/space boost, F or return fires, P screenshot.
final class GameARView: ARView {
    let input = InputState()

    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
    override func keyDown(with event: NSEvent) {
        if !handle(event.keyCode, true) { super.keyDown(with: event) }
    }
    override func keyUp(with event: NSEvent) {
        if !handle(event.keyCode, false) { super.keyUp(with: event) }
    }
    override func flagsChanged(with event: NSEvent) {
        input.boost = event.modifierFlags.contains(.shift)
    }
    override func mouseDown(with event: NSEvent) { steer(with: event) }
    override func mouseDragged(with event: NSEvent) { steer(with: event) }
    override func mouseUp(with event: NSEvent) { input.pointerSteer = nil; input.pointerClimb = nil }

    private func steer(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let nx = Float(p.x / max(bounds.width, 1)) - 0.5
        let ny = Float(p.y / max(bounds.height, 1)) - 0.5
        input.pointerSteer = max(-1, min(1, nx * 2.6))
        input.pointerClimb = max(-1, min(1, ny * 2.6))
    }

    private func handle(_ code: UInt16, _ down: Bool) -> Bool {
        switch code {
        case 123, 0:  input.left = down
        case 124, 2:  input.right = down
        case 126, 13: input.up = down
        case 125, 1:  input.down = down
        case 49:      input.boost = down
        case 3, 36:   input.fire = down          // F, return
        case 30:      input.speedUp = down       // ]
        case 33:      input.speedDown = down     // [
        case 35:      if down { input.screenshotRequested = true }
        default: return false
        }
        return true
    }
}
#else
/// Non-AR RealityKit view. Touch: horizontal position steers, vertical climbs,
/// two fingers boost. Hardware keyboard mirrors the Mac bindings.
final class GameARView: ARView {
    let input = InputState()

    init() {
        super.init(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        isMultipleTouchEnabled = true
    }
    @MainActor required dynamic init(frame frameRect: CGRect) {
        super.init(frame: frameRect, cameraMode: .nonAR, automaticallyConfigureSession: false)
        isMultipleTouchEnabled = true
    }
    @MainActor required dynamic init?(coder decoder: NSCoder) { fatalError("not supported") }

    override var canBecomeFirstResponder: Bool { true }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        becomeFirstResponder()
    }

    private var cornerTouchStart: (CGPoint, TimeInterval)? = nil
    private func isCorner(_ p: CGPoint) -> Bool { p.x > bounds.width - 90 && p.y < 90 }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let t = touches.first, isCorner(t.location(in: self)) {
            // toggle on touch-down: SwiftUI's overlay gesture cancels the touch before it ends
            cornerTouchStart = (t.location(in: self), t.timestamp)
            input.panelToggleRequested = true
            return                      // corner taps never steer
        }
        track(event)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if cornerTouchStart != nil { return }
        track(event)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let start = cornerTouchStart, let t = touches.first {
            let p = t.location(in: self)
            _ = (p, start)
            cornerTouchStart = nil
            return
        }
        track(event)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { cornerTouchStart = nil; track(event) }

    private func track(_ event: UIEvent?) {
        let active = (event?.allTouches ?? []).filter { $0.phase != .ended && $0.phase != .cancelled && !isCorner($0.location(in: self)) }
        guard let first = active.min(by: { $0.location(in: self).x < $1.location(in: self).x }) else {
            input.pointerSteer = nil
            input.pointerClimb = nil
            input.pointerBoost = false
            return
        }
        let p = first.location(in: self)
        let nx = Float(p.x / max(bounds.width, 1)) - 0.5
        let ny = 0.5 - Float(p.y / max(bounds.height, 1))
        input.pointerSteer = max(-1, min(1, nx * 2.6))
        input.pointerClimb = max(-1, min(1, ny * 2.6))
        input.pointerBoost = active.count >= 2
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !handle(presses, true) { super.pressesBegan(presses, with: event) }
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !handle(presses, false) { super.pressesEnded(presses, with: event) }
    }
    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        _ = handle(presses, false)
    }

    private func handle(_ presses: Set<UIPress>, _ down: Bool) -> Bool {
        var handled = false
        for press in presses {
            guard let key = press.key else { continue }
            switch key.keyCode {
            case .keyboardLeftArrow, .keyboardA:  input.left = down; handled = true
            case .keyboardRightArrow, .keyboardD: input.right = down; handled = true
            case .keyboardUpArrow, .keyboardW:    input.up = down; handled = true
            case .keyboardDownArrow, .keyboardS:  input.down = down; handled = true
            case .keyboardSpacebar, .keyboardLeftShift, .keyboardRightShift: input.boost = down; handled = true
            case .keyboardF, .keyboardReturnOrEnter: input.fire = down; handled = true
            case .keyboardCloseBracket: input.speedUp = down; handled = true
            case .keyboardOpenBracket: input.speedDown = down; handled = true
            case .keyboardP: if down { input.screenshotRequested = true }; handled = true
            default: break
            }
        }
        return handled
    }
}
#endif
