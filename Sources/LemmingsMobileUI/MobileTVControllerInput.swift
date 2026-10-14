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
    private var bindings = TVControllerBindings()
    private var timeline = TVTimelineTransport()
    private var rewindHeld = false
    private var pausePressed = false
    private var menuPressed = false
    private var touchpadClick = ControllerButtonEdge()
    private var preferenceKey: String?
    private var feedbackPad: GCDualSenseGamepad?
    private var feedbackTier: Double?
    private var lastTime = 0.0
    private var wasMenu = true
    private var inputPreferences = TVPreferences()
    private var preferenceBytes: Data?

    init(adapter: MobileInputAdapter) { self.adapter = adapter }
    func reset() {
        applyTimeline(timeline.reset())
        bindings.reset(); lastTime = 0
        touchpadClick.reset()
        if rewindHeld { rewindHeld = false; adapter?.onRewindHeld?(false) }
        clearFeedback()
    }
    private func clearFeedback() {
        feedbackPad?.rightTrigger.setModeOff()
        feedbackPad = nil; feedbackTier = nil
    }

    func poll(at time: Double) {
        guard let adapter else { return }
        let settings = adapter.settings()
        let profileID = adapter.settingsProfileID()
        let key = TVPreferences.inputKey(profileID)
        let bytes = UserDefaults.standard.data(forKey: key)
        if key != preferenceKey || bytes != preferenceBytes {
            preferenceKey = key
            preferenceBytes = bytes
            inputPreferences = TVPreferences.inputPreferences(from: .standard, profileID: profileID)
        }
        let devices = GCController.controllers().filter {
            $0.microGamepad != nil || ($0.extendedGamepad != nil && settings.controllerEnabled)
        }
        guard adapter.isActive() else { reset(); return }
        if let owner, !devices.contains(where: { $0 === owner }) {
            self.owner = nil
            reset()
            if !adapter.isMenu() { adapter.onForcedPause?() }
            return
        }
        if adapter.isMenu() {
            let pause = devices.contains { ControllerBindings.remap(pressed($0), using: settings.controllerMappings).contains(.b) }
            let menu = devices.contains { $0.extendedGamepad?.buttonMenu.isPressed == true }
            if menu && !menuPressed { adapter.onGameMenu?() }
            menuPressed = menu
            if pause && !pausePressed { adapter.onMenuPause?() }
            pausePressed = pause
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
        pausePressed = ControllerBindings.remap(pressed(owner), using: settings.controllerMappings).contains(.b)
        menuPressed = owner.extendedGamepad?.buttonMenu.isPressed == true
        let shuffleTouchpad = touchpadClick.update(pressed: MobileInputAdapter.touchpadPressed(on: owner), active: true)
        owner.microGamepad?.allowsRotation = false
        owner.microGamepad?.reportsAbsoluteDpadValues = true
        let elapsed = min(0.05, max(0, lastTime == 0 ? 0 : time - lastTime))
        lastTime = time
        let roles = ControllerBindings.remap(pressed(owner), using: settings.controllerMappings)
        let actions = bindings.update(pressed: roles)
        applyTimeline(timeline.update(pressed: roles, at: time, speed: adapter.controllerSpeed()))
        if bindings.menuRequested { adapter.onGameMenu?(); reset(); return }
        if bindings.shuffleRequested || shuffleTouchpad { adapter.onDJShuffle?() }
        for action in actions {
            if case .boost = action { continue }
            if action == .pause { applyTimeline(timeline.reset()) }
            adapter.perform(action)
            if adapter.isMenu() { reset(); return }
        }
        if let pad = owner.extendedGamepad {
            updateFeedback(pad: pad, settings: settings)
            let aim = settings.controllerSwapSticks ? pad.rightThumbstick : pad.leftThumbstick
            let pan = settings.controllerSwapSticks ? pad.leftThumbstick : pad.rightThumbstick
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

    private func applyTimeline(_ events: [TVTimelineTransport.Event]) {
        for event in events {
            switch event {
            case .resetSpeed: adapter?.onCommand?(.speedReset)
            case .park: adapter?.onTimelinePark?()
            case .step(let direction): adapter?.onCommand?(.step(direction))
            case .scrub(let direction, let held):
                if direction < 0 { rewindHeld = held; adapter?.onRewindHeld?(held) }
                else { adapter?.onForwardScrub?(held) }
            }
        }
    }

    private func updateFeedback(pad: GCExtendedGamepad, settings: ClassicSettings) {
        guard ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] != "muted",
              adapter?.triggerFeedbackEnabled() == true, inputPreferences.triggerFeedback != false, settings.variableSpeedEnabled,
              (settings.controllerMappings[ControllerBindings.Button.rightTrigger.rawValue] ?? "rightTrigger") == "rightTrigger",
              let dual = pad as? GCDualSenseGamepad else { clearFeedback(); return }
        let tier = adapter?.controllerSpeed() ?? 1
        guard feedbackPad !== dual || feedbackTier != tier else { return }
        feedbackPad = dual; feedbackTier = tier
        dual.rightTrigger.setModeFeedbackWithStartPosition(0.2, resistiveStrength: Float(0.15 + min(9, max(0, tier - 1)) / 9 * 0.55))
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
            let result = Set(inputs.compactMap { $0.1?.isPressed == true ? $0.0 : nil })
            return result
        }
        guard let pad = controller.microGamepad else { return [] }
        let centre = controller.physicalInputProfile.buttons[GCInputDirectionalCenterButton] ?? pad.buttonA
        var result = Set<ControllerBindings.Button>()
        if centre.isPressed { result.insert(.a) }
        if pad.buttonX.isPressed { result.insert(.b) }
        if pad.buttonMenu.isPressed { result.insert(.menu) }
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
