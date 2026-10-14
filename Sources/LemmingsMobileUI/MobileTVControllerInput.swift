#if os(tvOS)
import GameController
import NxlvKit
import LemmingsTVCore
import UIKit

/// UIKit handles menu focus; only the owning controller can edit a running attempt.
@MainActor final class MobileTVControllerInput {
    private weak var adapter: MobileInputAdapter?
    private var owner: GCController?
    private var lastMenuDevice: GCController?
    private var bindings = ControllerBindings()
    private var lastTime = 0.0
    private var wasMenu = true
    private var inputPreferences = TVPreferences()
    private var preferenceBytes: Data?

    init(adapter: MobileInputAdapter) { self.adapter = adapter }
    func reset() { bindings.reset(); lastTime = 0 }

    func poll(at time: Double) {
        guard let adapter else { return }
        let bytes = UserDefaults.standard.data(forKey: TVPreferences.inputDefaultsKey)
        if bytes != preferenceBytes {
            preferenceBytes = bytes
            inputPreferences = TVPreferences.inputPreferences(from: .standard)
        }
        let devices = GCController.controllers().filter {
            $0.microGamepad != nil || ($0.extendedGamepad != nil && adapter.settings().controllerEnabled)
        }
        guard adapter.isActive() else { reset(); return }
        if let owner, !devices.contains(where: { $0 === owner }) {
            self.owner = nil
            reset()
            if !adapter.isMenu() { adapter.onCommand?(.pause) }
            return
        }
        if adapter.isMenu() {
            if let active = devices.first(where: { !pressed($0).isEmpty || moving($0) }) { lastMenuDevice = active }
            if devices.allSatisfy({ pressed($0).isEmpty }) { adapter.onMenuNeutral?() }
            reset()
            wasMenu = true
            return
        }
        if wasMenu {
            if owner == nil {
                if let lastMenuDevice, devices.contains(where: { $0 === lastMenuDevice }) { owner = lastMenuDevice }
                else if let current = GCController.current, devices.contains(where: { $0 === current }) { owner = current }
            }
            wasMenu = false
            reset()
        }
        if owner == nil {
            owner = devices.first(where: { !pressed($0).isEmpty || moving($0) })
            reset()
        }
        guard let owner else { return }
        owner.microGamepad?.allowsRotation = false
        owner.microGamepad?.reportsAbsoluteDpadValues = true
        let elapsed = min(0.05, max(0, lastTime == 0 ? 0 : time - lastTime))
        lastTime = time
        for action in bindings.update(pressed: ControllerBindings.remap(pressed(owner), using: adapter.settings().controllerMappings)) {
            adapter.perform(action)
            if adapter.isMenu() { reset(); return }
        }
        if let pad = owner.extendedGamepad {
            let aim = adapter.settings().controllerSwapSticks ? pad.rightThumbstick : pad.leftThumbstick
            let pan = adapter.settings().controllerSwapSticks ? pad.leftThumbstick : pad.rightThumbstick
            if abs(aim.xAxis.value) > Float(inputPreferences.deadZone) || abs(aim.yAxis.value) > Float(inputPreferences.deadZone) {
                adapter.onAim?(velocity(aim.xAxis.value) * elapsed, -velocity(aim.yAxis.value) * elapsed)
            }
            if abs(pan.xAxis.value) > Float(inputPreferences.deadZone) || abs(pan.yAxis.value) > Float(inputPreferences.deadZone) {
                adapter.onPan?(velocity(pan.xAxis.value) * elapsed, -velocity(pan.yAxis.value) * elapsed)
            }
        } else if let pad = owner.microGamepad {
            if abs(pad.dpad.xAxis.value) > Float(inputPreferences.deadZone) || abs(pad.dpad.yAxis.value) > Float(inputPreferences.deadZone) {
                adapter.onAim?(velocity(pad.dpad.xAxis.value) * elapsed, -velocity(pad.dpad.yAxis.value) * elapsed)
            }
        }
    }

    private func velocity(_ input: Float) -> Double {
        inputPreferences.stickVelocity(Double(input))
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
        guard let pad = controller.microGamepad else { return [] }
        let centre = controller.physicalInputProfile.buttons[GCInputDirectionalCenterButton] ?? pad.buttonA
        var result = Set<ControllerBindings.Button>()
        if centre.isPressed { result.insert(.a) }
        if pad.buttonX.isPressed { result.insert(.menu) }
        if pad.buttonMenu.isPressed { result.insert(.b) }
        return result
    }

    private func moving(_ controller: GCController) -> Bool {
        if let pad = controller.extendedGamepad {
            return [pad.leftThumbstick.xAxis.value, pad.leftThumbstick.yAxis.value,
                    pad.rightThumbstick.xAxis.value, pad.rightThumbstick.yAxis.value].contains { abs($0) > Float(inputPreferences.deadZone) }
        }
        guard let pad = controller.microGamepad else { return false }
        return abs(pad.dpad.xAxis.value) > Float(inputPreferences.deadZone) || abs(pad.dpad.yAxis.value) > Float(inputPreferences.deadZone)
    }
}
#endif
