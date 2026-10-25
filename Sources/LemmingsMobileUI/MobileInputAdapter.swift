#if os(iOS) || os(tvOS)
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
    var onAssignHeld: ((Bool) -> Void)?
    private var assignmentHeld = false

    func updateAssignmentHeld(_ held: Bool) {
        guard assignmentHeld != held else { return }
        assignmentHeld = held
        onAssignHeld?(held)
    }
    var onPan: ((Double, Double) -> Void)?
    var onMenuScroll: ((Double) -> Void)?
    var onBoost: ((Bool) -> Void)?
    var onRewindHeld: ((Bool) -> Void)?
    var onMenuPause: (() -> Void)?
    var onForcedPause: (() -> Void)?
    var onTimelinePark: (() -> Void)?
    var onGameMenu: (() -> Void)?
    var onDJShuffle: (() -> Void)?
    var settingsProfileID: () -> String = { MobileProfiles.defaultID }
    var controllerSpeed: () -> Double = { 1 }
    var triggerFeedbackEnabled: () -> Bool = { true }
    var onSpeedKey: ((Bool) -> Void)?
    var settings: () -> ClassicSettings = { MobileSettings.current(from: .standard).classic }
    var isMenu: () -> Bool = { false }
    var isActive: () -> Bool = { true }
    #if os(tvOS)
    var onControllerButtonEvent: ((() -> Void) -> Void)?
    private lazy var tvInput = MobileTVControllerInput(adapter: self)
    #endif
    private var bindings = ControllerBindings()
    private var pressedKeys: Set<UIKeyboardHIDUsage> = []
    private var controllerConnection = MobileControllerConnection()
    private var activeController: GCController?
    private var context: ObjectIdentifier?
    private var lastPoll = 0.0
    private var touchpadClick = ControllerButtonEdge()
    let stepFeedback = ControllerStepFeedback()
    private var disabledMenuButton = ControllerButtonEdge()

    func reset() {
        updateAssignmentHeld(false)
        onBoost?(false); onRewindHeld?(false); onSpeedKey?(false); bindings.reset(); pressedKeys.removeAll(); lastPoll = 0
        touchpadClick.reset(); stepFeedback.reset()
        #if os(tvOS)
        tvInput.reset()
        #endif
    }

    /// A page transition primes from the held state before it accepts another press.
    func poll(context newContext: ObjectIdentifier?, at now: Double) {
        if context != newContext { context = newContext; reset() }
        #if os(tvOS)
        tvInput.poll(at: now)
        #else
        guard isActive() else {
            _ = disabledMenuButton.update(pressed: false, active: false)
            reset()
            activeController = nil
            controllerConnection.reset()
            return
        }
        if !isMenu(), !settings().controllerEnabled {
            let pressed = GCController.controllers().contains {
                $0.extendedGamepad?.buttonMenu.isPressed == true || $0.extendedGamepad?.buttonOptions?.isPressed == true
            }
            if disabledMenuButton.update(pressed: pressed, active: true) { onGameMenu?() }
            reset()
            return
        }
        _ = disabledMenuButton.update(pressed: false, active: false)
        let controllers = GCController.controllers().filter { $0.extendedGamepad != nil }
        if let activeController,
           !controllers.contains(where: { $0 === activeController }) {
            self.activeController = nil
            let shouldPause = controllerConnection.update(isConnected: false, isMenu: isMenu())
            reset()
            if shouldPause { onForcedPause?() }
            return
        }
        guard let controller = activeController ?? controllers.first,
              let pad = controller.extendedGamepad else {
            let shouldPause = controllerConnection.update(isConnected: false, isMenu: isMenu())
            activeController = nil
            reset()
            if shouldPause { onForcedPause?() }
            return
        }
        activeController = controller
        _ = controllerConnection.update(isConnected: true, isMenu: isMenu())
        let elapsed = min(0.05, max(0, lastPoll == 0 ? 0 : now - lastPoll))
        lastPoll = now
        let touchpad = Self.touchpadPressed(on: controller)
        if touchpadClick.update(pressed: touchpad, active: !isMenu()) { onDJShuffle?() }
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
        if !isMenu() { pressed = ControllerBindings.remap(pressed, using: settings().controllerMappings) }
        updateAssignmentHeld(!isMenu() && pressed.contains(.a))
        for action in bindings.update(pressed: pressed, inMenu: isMenu(), at: now) {
            perform(action)
            if case .step(let direction) = action, !isMenu() { stepFeedback.tick(direction, on: controller, at: now) }
        }
        let jog = stepFeedback.jogSteps(on: controller, active: !isMenu())
        if jog != 0 {
            for _ in 0..<abs(jog) where !isMenu() { perform(.step(jog < 0 ? -1 : 1)) }
            stepFeedback.tick(jog, on: controller, at: now)
        }
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
        #endif
    }

    static func touchpadPressed(on controller: GCController) -> Bool {
        if let button = controller.physicalInputProfile.buttons[GCInputDualShockTouchpadButton] {
            return button.isPressed
        }
        if let pad = controller.extendedGamepad as? GCDualSenseGamepad { return pad.touchpadButton.isPressed }
        if let pad = controller.extendedGamepad as? GCDualShockGamepad { return pad.touchpadButton.isPressed }
        return false
    }

    func perform(_ action: ControllerBindings.Action) {
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
        case .cancel: onGameMenu?()
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
        case .djShuffle: onDJShuffle?()
        }
    }

    func began(_ presses: Set<UIPress>) -> Set<UIPress> {
        var unhandled = Set<UIPress>()
        for press in presses {
            guard let key = press.key, key.modifierFlags.intersection([.control, .alternate]).isEmpty else {
                unhandled.insert(press); continue
            }
            if key.modifierFlags.contains(.command) {
                guard !isMenu(), isActive(), let command = GameplayCommands.command(key: Self.name(key),
                    shift: key.modifierFlags.contains(.shift), command: true) else {
                    unhandled.insert(press); continue
                }
                if pressedKeys.insert(key.keyCode).inserted { onCommand?(command) }
                continue
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
