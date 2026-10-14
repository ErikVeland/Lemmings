#if os(tvOS)
import GameController
import LemmingsTVCore
import NxlvKit
import UIKit

/// UIKit owns menu focus. Polling owns gameplay, with one physical device per attempt.
@MainActor final class TVInputAdapter {
    var onAction: ((ControllerBindings.Action) -> Void)?
    var onAim: ((Double, Double) -> Void)?
    var onPan: ((Double, Double) -> Void)?
    var onDisconnect: (() -> Void)?
    var onMenuNeutral: (() -> Void)?
    var preferences = TVPreferences()
    private var owner: GCController?
    private var lastMenuDevice: GCController?
    private var context: UUID?
    private var bindings = ControllerBindings()
    private var lastTime = 0.0
    private var wasMenu = true
    private var observer: NSObjectProtocol?
    var isRemote: Bool { owner?.microGamepad != nil }

    init() {
        observer = NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] notification in
            guard let pad = notification.object as? GCController else { return }
            let identity = ObjectIdentifier(pad)
            MainActor.assumeIsolated {
                guard let self, let owner = self.owner, identity == ObjectIdentifier(owner) else { return }
                self.owner = nil; self.reset(); self.onDisconnect?()
            }
        }
    }

    func reset() { bindings.reset(); lastTime = 0 }
    func releaseOwner() { owner = nil; reset() }
    func claimMenuDevice() {
        let devices = GCController.controllers()
        if let candidate = lastMenuDevice, devices.contains(where: { $0 === candidate }) { owner = candidate }
        else if let current = GCController.current { owner = current }
        else if devices.count == 1 { owner = devices[0] }
        configureRemote()
        reset()
    }

    func poll(at now: Double, context newContext: UUID, menu: Bool) {
        let devices = GCController.controllers()
        if menu {
            if let active = devices.first(where: { !pressed($0).isEmpty || hasMovement($0) }) { lastMenuDevice = active }
            if devices.allSatisfy({ pressed($0).isEmpty }) { onMenuNeutral?() }
            if !wasMenu || context != newContext { reset() }
            context = newContext; wasMenu = true; return
        }
        if wasMenu || context != newContext { reset() }
        context = newContext; wasMenu = false
        if owner == nil {
            // First active device wins. Spectator inputs cannot steal ownership.
            owner = devices.first { !pressed($0).isEmpty || hasMovement($0) }
            if owner != nil { configureRemote(); bindings.reset() }
        }
        guard let owner else { return }
        let elapsed = min(0.05, max(0, lastTime == 0 ? 0 : now - lastTime)); lastTime = now
        let actions = bindings.update(pressed: ControllerBindings.remap(pressed(owner), using: preferences.mappings))
        for action in actions {
            onAction?(action)
            // Navigation may invalidate the remaining buttons in this frame.
            if [.pause, .help, .hints, .retry, .settings, .cancel].contains(action) { return }
        }
        if let pad = owner.extendedGamepad {
            let aim = preferences.swapSticks ? pad.rightThumbstick : pad.leftThumbstick
            let pan = preferences.swapSticks ? pad.leftThumbstick : pad.rightThumbstick
            onAim?(preferences.stickVelocity(Double(aim.xAxis.value)) * elapsed,
                   -preferences.stickVelocity(Double(aim.yAxis.value)) * elapsed)
            onPan?(preferences.stickVelocity(Double(pan.xAxis.value), maximum: 800) * elapsed,
                   -preferences.stickVelocity(Double(pan.yAxis.value), maximum: 800) * elapsed)
        } else if let micro = owner.microGamepad {
            // Both touch surfaces and digital clickpad directions provide continuous aiming.
            onAim?(preferences.stickVelocity(Double(micro.dpad.xAxis.value)) * elapsed,
                   -preferences.stickVelocity(Double(micro.dpad.yAxis.value)) * elapsed)
        }
    }

    private func configureRemote() {
        owner?.microGamepad?.allowsRotation = false
        owner?.microGamepad?.reportsAbsoluteDpadValues = true
    }

    private func pressed(_ controller: GCController) -> Set<ControllerBindings.Button> {
        if let pad = controller.extendedGamepad {
            let inputs: [(ControllerBindings.Button, GCControllerButtonInput?)] = [
                (.a, pad.buttonA), (.b, pad.buttonB), (.x, pad.buttonX), (.y, pad.buttonY),
                (.leftShoulder, pad.leftShoulder), (.rightShoulder, pad.rightShoulder),
                (.leftTrigger, pad.leftTrigger), (.rightTrigger, pad.rightTrigger),
                (.up, pad.dpad.up), (.down, pad.dpad.down), (.left, pad.dpad.left), (.right, pad.dpad.right),
                (.menu, pad.buttonMenu), (.options, pad.buttonOptions),
                (.leftStick, pad.leftThumbstickButton), (.rightStick, pad.rightThumbstickButton)
            ]
            return Set(inputs.compactMap { $0.1?.isPressed == true ? $0.0 : nil })
        }
        guard let micro = controller.microGamepad else { return [] }
        var result = Set<ControllerBindings.Button>()
        let centre = controller.physicalInputProfile.buttons[GCInputDirectionalCenterButton] ?? micro.buttonA
        if centre.isPressed { result.insert(.a) }
        if micro.buttonX.isPressed { result.insert(.menu) }
        if micro.buttonMenu.isPressed { result.insert(.b) }
        return result
    }

    private func hasMovement(_ controller: GCController) -> Bool {
        if let pad = controller.extendedGamepad {
            return abs(pad.leftThumbstick.xAxis.value) > 0.2 || abs(pad.leftThumbstick.yAxis.value) > 0.2
                || abs(pad.rightThumbstick.xAxis.value) > 0.2 || abs(pad.rightThumbstick.yAxis.value) > 0.2
        }
        guard let pad = controller.microGamepad?.dpad else { return false }
        return abs(pad.xAxis.value) > 0.2 || abs(pad.yAxis.value) > 0.2
    }
}
#endif
