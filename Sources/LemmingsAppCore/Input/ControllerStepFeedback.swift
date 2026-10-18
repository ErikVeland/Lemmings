#if canImport(GameController) && canImport(CoreHaptics)
import CoreHaptics
import Foundation
import GameController
import NxlvKit

/// Reads the DualSense or DualShock touchpad as a jog wheel and plays a short
/// haptic tick for each timeline step. Controllers without a touchpad or
/// haptics keep the button steps without feedback.
@MainActor public final class ControllerStepFeedback {
    private var jog = TouchpadJog()
    private var engine: CHHapticEngine?
    private weak var hapticController: GCController?
    private var players: [Int: CHHapticPatternPlayer] = [:]
    private var lastTick = -Double.infinity
    /// Fast scrubbing plays one tick each 30 ms, not one for each tick.
    private static let tickInterval = 0.03
    private static let muted = ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] == "muted"

    public init() {}

    /// Forget the finger position, for example after a menu or a controller change.
    public func reset() { jog.reset() }

    public func stop() {
        jog.reset()
        engine?.stop()
        engine = nil; players = [:]; hapticController = nil
    }

    /// Returns the signed number of ticks from a horizontal touchpad slide.
    /// A click, a menu or an inactive game resets the slide and returns zero.
    public func jogSteps(on controller: GCController, active: Bool) -> Int {
        guard active, !Self.touchpadClicked(on: controller), let point = Self.touchpad(on: controller) else {
            jog.reset(); return 0
        }
        return jog.update(x: point.x, y: point.y)
    }

    /// Plays one haptic tick. A backward step is softer than a forward step.
    public func tick(_ direction: Int, on controller: GCController?, at now: Double = ProcessInfo.processInfo.systemUptime) {
        guard !Self.muted, let controller, now - lastTick >= Self.tickInterval else { return }
        lastTick = now
        if hapticController !== controller { stop(); hapticController = controller }
        if engine == nil {
            guard let created = controller.haptics?.createEngine(withLocality: .default) else { return }
            created.isAutoShutdownEnabled = true
            created.resetHandler = { [weak self] in
                Task { @MainActor in self?.engine = nil; self?.players = [:] }
            }
            engine = created
        }
        guard let engine else { return }
        let key = direction < 0 ? -1 : 1
        if players[key] == nil {
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: key < 0 ? 0.45 : 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: key < 0 ? 0.4 : 0.8)
            ], relativeTime: 0)
            players[key] = (try? CHHapticPattern(events: [event], parameters: [])).flatMap { try? engine.makePlayer(with: $0) }
        }
        do {
            try engine.start()
            try players[key]?.start(atTime: CHHapticTimeImmediate)
        } catch {
            self.engine = nil; players = [:]
        }
    }

    /// The primary touch on a DualSense or DualShock pad, from -1 to 1 on each axis.
    public static func touchpad(on controller: GCController) -> (x: Double, y: Double)? {
        let pad: GCControllerDirectionPad?
        if let profile = controller.physicalInputProfile.dpads[GCInputDualShockTouchpadOne] { pad = profile }
        else if let dualSense = controller.extendedGamepad as? GCDualSenseGamepad { pad = dualSense.touchpadPrimary }
        else if let dualShock = controller.extendedGamepad as? GCDualShockGamepad { pad = dualShock.touchpadPrimary }
        else { pad = nil }
        guard let pad else { return nil }
        return (Double(pad.xAxis.value), Double(pad.yAxis.value))
    }

    public static func touchpadClicked(on controller: GCController) -> Bool {
        if let button = controller.physicalInputProfile.buttons[GCInputDualShockTouchpadButton] { return button.isPressed }
        if let pad = controller.extendedGamepad as? GCDualSenseGamepad { return pad.touchpadButton.isPressed }
        if let pad = controller.extendedGamepad as? GCDualShockGamepad { return pad.touchpadButton.isPressed }
        return false
    }
}
#endif
