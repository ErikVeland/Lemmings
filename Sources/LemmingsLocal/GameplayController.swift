import AppKit
import GameController
import NxlvKit

/// Polls connected extended gamepads without taking over input in other apps.
@MainActor final class GameplayController {
    private weak var keyboard: GameplayKeyboard?
    private var timer: Timer?
    private var bindings = ControllerBindings()
    private var previousMapping: [String: String] = [:]
    private var device: ObjectIdentifier?
    private var context: ObjectIdentifier?
    private var wasActive = false
    private var previousTime = ProcessInfo.processInfo.systemUptime
    private var boostPrevious: Bool?
    private var boostWasVariable = false
    private var boostStartedAt = 0.0
    private var boostCanTap = false
    private var receivedInput = false

    init(keyboard: GameplayKeyboard, pollsAutomatically: Bool = true) {
        self.keyboard = keyboard
        guard pollsAutomatically else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }
    private func stopBoost(at now: TimeInterval = ProcessInfo.processInfo.systemUptime, interrupted: Bool = true) {
        guard let previous = boostPrevious else { return }
        boostPrevious = nil
        if boostWasVariable {
            keyboard?.speedControl?.release(.controller, at: now, allowTap: !interrupted)
        } else if keyboard?.controllerEnabled() == true {
            let tapped = !interrupted && boostCanTap && now - boostStartedAt < GameplaySpeed.holdDelay
            keyboard?.speedControl?.setFast(tapped ? !previous : previous)
        }
    }
    func disconnect() {
        stopBoost(); keyboard?.speedControl?.cancelInput()
        if receivedInput { keyboard?.handleInterruption() }
        receivedInput = false
        keyboard?.controllerRewindHeld(false)
        bindings.reset(); device = nil; context = nil; wasActive = false
    }
    private func poll() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.05, max(0, now - previousTime)); previousTime = now
        guard let keyboard, keyboard.controllerAvailable,
              let controller = GCController.controllers().first(where: { $0.extendedGamepad != nil }),
              let pad = controller.extendedGamepad else {
            if device != nil { disconnect() }
            return
        }
        let identity = ObjectIdentifier(controller)
        let playing = keyboard.controllerPlaying
        if identity != device { stopBoost(at: now); bindings.reset() }
        device = identity
        var pressed: Set<ControllerBindings.Button> = []
        let buttons: [(ControllerBindings.Button, GCControllerButtonInput?)] = [
            (.a,pad.buttonA), (.b,pad.buttonB), (.x,pad.buttonX), (.y,pad.buttonY),
            (.leftShoulder,pad.leftShoulder), (.rightShoulder,pad.rightShoulder),
            (.leftTrigger,pad.leftTrigger), (.rightTrigger,pad.rightTrigger),
            (.menu,pad.buttonMenu), (.options,pad.buttonOptions),
            (.leftStick,pad.leftThumbstickButton), (.rightStick,pad.rightThumbstickButton),
            (.up,pad.dpad.up), (.down,pad.dpad.down), (.left,pad.dpad.left), (.right,pad.dpad.right)]
        for (key, button) in buttons where button?.isPressed == true { pressed.insert(key) }
        processButtons(pressed, at: now, playing: playing)
        func axis(_ value: Float) -> Double {
            let magnitude = abs(Double(value))
            return magnitude > 0.18 ? (magnitude - 0.18) / 0.82 * (value < 0 ? -1 : 1) : 0
        }
        guard keyboard.controllerPlaying else {
            stopBoost(at: now); keyboard.controllerMenuScroll(-axis(pad.rightThumbstick.yAxis.value) * dt * 360); return
        }
        let aim = keyboard.controllerSwapSticks() ? pad.rightThumbstick : pad.leftThumbstick
        let camera = keyboard.controllerSwapSticks() ? pad.leftThumbstick : pad.rightThumbstick
        let x = axis(aim.xAxis.value), y = -axis(aim.yAxis.value)
        let cx = axis(camera.xAxis.value), cy = -axis(camera.yAxis.value)
        if x != 0 || y != 0 { receivedInput = true; keyboard.movePointer(x * dt * 220, y * dt * 220) }
        if cx != 0 || cy != 0 { receivedInput = true; keyboard.panCamera(cx * dt * 240, cy * dt * 240) }
    }

    // The hardware reader and deterministic input checks use this same dispatch path.
    func processButtons(_ pressed: Set<ControllerBindings.Button>, at now: TimeInterval, playing: Bool) {
        guard let keyboard else { return }
        let mapping = playing ? ControllerBindings.validatedMapping(keyboard.controllerMappings()) : [:]
        if playing != wasActive || context != keyboard.controllerContext || mapping != previousMapping {
            stopBoost(at: now); bindings.reset()
        }
        previousMapping = mapping
        let pressed = ControllerBindings.remap(pressed, using: mapping)
        keyboard.controllerRewindHeld(playing && pressed.contains(.leftTrigger) && pressed.contains(.b))
        wasActive = playing; context = keyboard.controllerContext
        let wasFast = keyboard.speedControl?.isFast == true
        for action in bindings.update(pressed: pressed, inMenu: !playing) {
            guard keyboard.controllerEnabled(), keyboard.ownsController() else { stopBoost(at: now); break }
            if action != .boost(false) { receivedInput = true }
            if !playing {
                stopBoost(at: now); keyboard.controllerMenuAction(action); break
            }
            switch action {
            case .speedReset, .speedStep, .cancel, .retry, .rewind, .step: stopBoost(at: now)
            default: break
            }
            switch action {
            case let .boost(down):
                if down {
                    boostPrevious = keyboard.speedControl?.isFast ?? false
                    boostWasVariable = keyboard.speedControl?.variableEnabled == true
                    boostStartedAt = now; boostCanTap = keyboard.controllerTapSpeed()
                    if keyboard.speedControl?.variableEnabled == true {
                        keyboard.speedControl?.press(.controller, at: now, tapEnabled: keyboard.controllerTapSpeed())
                    }
                    else { keyboard.speedControl?.setFast(true) }
                } else { stopBoost(at: now, interrupted: false) }
            default: keyboard.controllerAction(action == .cancel && wasFast ? .speedReset : action)
            }
            if context != keyboard.controllerContext || !keyboard.active() { stopBoost(at: now); break }
        }
    }
    isolated deinit { timer?.invalidate() }
}
