#if os(iOS)
import GameController
import LemmingsAppCore
import LemmingsMobileCore
import NxlvKit
import UIKit

/// Polling retains input ownership across Ready pages, scene changes and held buttons.
@MainActor final class MobileInputAdapter {
    var onCommand: ((GameplayCommand) -> Void)?
    var onMenuMove: ((Int) -> Void)?
    var onMenuActivate: (() -> Void)?
    var onMenuBack: (() -> Void)?
    var onAim: ((Double, Double) -> Void)?
    var onPan: ((Double, Double) -> Void)?
    var onMenuScroll: ((Double) -> Void)?
    var onBoost: ((Bool) -> Void)?
    var onSpeedKey: ((Bool) -> Void)?
    var settings: () -> ClassicSettings = { MobileSettings.load(from: .standard).classic }
    var isMenu: () -> Bool = { false }
    var isActive: () -> Bool = { true }
    private var bindings = ControllerBindings()
    private var pressedKeys: Set<UIKeyboardHIDUsage> = []
    private var context: ObjectIdentifier?
    private var lastPoll = 0.0

    func reset() { onBoost?(false); onSpeedKey?(false); bindings.reset(); pressedKeys.removeAll(); lastPoll = 0 }

    /// A page transition primes from the held state before it accepts another press.
    func poll(context newContext: ObjectIdentifier?, at now: Double) {
        if context != newContext { context = newContext; reset() }
        guard isActive(), settings().controllerEnabled,
              let pad = GCController.controllers().first?.extendedGamepad else { reset(); return }
        let elapsed = min(0.05, max(0, lastPoll == 0 ? 0 : now - lastPoll))
        lastPoll = now
        var pressed = Set<ControllerBindings.Button>()
        let buttons: [(ControllerBindings.Button, GCControllerButtonInput?)] = [
            (.a, pad.buttonA), (.b, pad.buttonB), (.x, pad.buttonX), (.y, pad.buttonY),
            (.leftShoulder, pad.leftShoulder), (.rightShoulder, pad.rightShoulder),
            (.leftTrigger, pad.leftTrigger), (.rightTrigger, pad.rightTrigger),
            (.menu, pad.buttonMenu), (.options, pad.buttonOptions),
            (.leftStick, pad.leftThumbstickButton), (.rightStick, pad.rightThumbstickButton),
            (.up, pad.dpad.up), (.down, pad.dpad.down), (.left, pad.dpad.left), (.right, pad.dpad.right),
        ]
        for (button, input) in buttons where input?.isPressed == true { pressed.insert(button) }
        pressed = ControllerBindings.remap(pressed, using: settings().controllerMappings)
        for action in bindings.update(pressed: pressed, inMenu: isMenu()) { perform(action) }
        let left = settings().controllerSwapSticks ? pad.rightThumbstick : pad.leftThumbstick
        let right = settings().controllerSwapSticks ? pad.leftThumbstick : pad.rightThumbstick
        if isMenu() {
            if abs(right.yAxis.value) > 0.15 { onMenuScroll?(-Double(right.yAxis.value) * elapsed * 500) }
        } else {
            if abs(left.xAxis.value) > 0.15 || abs(left.yAxis.value) > 0.15 {
                onAim?(Double(left.xAxis.value) * elapsed * 420, -Double(left.yAxis.value) * elapsed * 420)
            }
            if abs(right.xAxis.value) > 0.15 || abs(right.yAxis.value) > 0.15 {
                onPan?(Double(right.xAxis.value) * elapsed * 500, -Double(right.yAxis.value) * elapsed * 500)
            }
        }
    }

    private func perform(_ action: ControllerBindings.Action) {
        if isMenu() {
            switch action {
            case .assign: onMenuActivate?()
            case .cancel, .pause: onMenuBack?()
            case .focusUnassigned(let delta), .cycle(let delta): onMenuMove?(delta)
            case .rate(let delta): onMenuMove?(-delta)
            default: break
            }
            return
        }
        switch action {
        case .assign: onCommand?(.assign)
        case .repeatAssignment: onCommand?(.repeatAssignment)
        case .cancel: onCommand?(.speedReset)
        case .pause: onCommand?(.pause)
        case .help: onCommand?(.help)
        case .hints: onCommand?(.hints)
        case .retry: onCommand?(.retry)
        case .rewind: onCommand?(.rewind)
        case .step(let direction): onCommand?(.step(direction))
        case .cycle(let direction): onCommand?(.cycle(direction))
        case .focusUnassigned(let direction): onCommand?(.focusUnassigned(direction))
        case .focusLast: onCommand?(.focusLast)
        case .centre(let entrance): onCommand?(.centre(entrance))
        case .rate(let direction): onCommand?(.rate(direction))
        case .speedStep(let direction): onCommand?(.speedStep(direction))
        case .speedReset: onCommand?(.speedReset)
        case .boost(let held): onBoost?(held)
        case .endRun: onCommand?(.endRun)
        case .settings: onCommand?(.settings)
        }
    }

    func began(_ presses: Set<UIPress>) -> Set<UIPress> {
        var unhandled = Set<UIPress>()
        for press in presses {
            guard let key = press.key, key.modifierFlags.intersection([.command, .control, .alternate]).isEmpty else {
                unhandled.insert(press); continue
            }
            guard pressedKeys.insert(key.keyCode).inserted else { continue }
            let name = Self.name(key)
            if isMenu() {
                switch name {
                case "return", " ": onMenuActivate?()
                case "escape": onMenuBack?()
                case "tab": onMenuMove?(key.modifierFlags.contains(.shift) ? -1 : 1)
                case "down", "right": onMenuMove?(1)
                case "up", "left": onMenuMove?(-1)
                default: unhandled.insert(press)
                }
            } else if let command = GameplayCommands.command(key: name, shift: key.modifierFlags.contains(.shift)) {
                if command == .speed { onSpeedKey?(true) }
                else { onCommand?(command) }
            } else { unhandled.insert(press) }
        }
        return presses.subtracting(unhandled)
    }
    func ended(_ presses: Set<UIPress>) -> Set<UIPress> {
        for press in presses { if let key = press.key {
            pressedKeys.remove(key.keyCode)
            if Self.name(key) == "f" { onSpeedKey?(false) }
        } }
        return presses.filter { $0.key != nil }
    }
    private static func name(_ key: UIKey) -> String {
        switch key.keyCode {
        case .keyboardEscape: "escape"
        case .keyboardReturnOrEnter, .keypadEnter: "return"
        case .keyboardTab: "tab"
        case .keyboardHome: "home"
        case .keyboardEnd: "end"
        case .keyboardLeftArrow: "left"
        case .keyboardRightArrow: "right"
        case .keyboardUpArrow: "up"
        case .keyboardDownArrow: "down"
        case .keyboardF1: "f1"
        default: key.charactersIgnoringModifiers.lowercased()
        }
    }
}
#endif
