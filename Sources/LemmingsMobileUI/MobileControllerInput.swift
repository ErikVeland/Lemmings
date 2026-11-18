#if os(iOS) || os(tvOS)
import GameController
import LemmingsMobileCore

/**
 * Converts supported controller buttons into the game's existing input actions.
 */
@MainActor final class MobileControllerInput {
    enum Action: Sendable {
        case target(Int)
        case skill(Int)
        case assign
        case pause
    }

    var onAction: ((Action) -> Void)?
    private let observers = MobileNotificationObserverBag()
    private var controllers: [GCController] = []
    private var active = false

    init() {
        for name in [Notification.Name.GCControllerDidConnect, .GCControllerDidDisconnect] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in MainActor.assumeIsolated { self?.refresh() }
            })
        }
    }

    func start() { active = true; refresh() }

    func stop() {
        active = false
        for controller in controllers {
            guard let pad = controller.extendedGamepad else { continue }
            [pad.buttonA, pad.buttonB, pad.buttonX, pad.buttonY,
             pad.leftShoulder, pad.rightShoulder, pad.buttonMenu].forEach { $0.pressedChangedHandler = nil }
            pad.dpad.valueChangedHandler = nil
        }
        controllers = []
    }

    var cameraDirection: MobilePoint {
        #if os(tvOS)
        let stick = controllers.first?.extendedGamepad?.rightThumbstick
        #else
        let stick = controllers.first?.extendedGamepad?.leftThumbstick
        #endif
        guard active, let stick else {
            return MobilePoint(x: 0, y: 0)
        }
        let x = Double(stick.xAxis.value), y = Double(stick.yAxis.value)
        return MobilePoint(x: abs(x) > 0.2 ? x : 0, y: abs(y) > 0.2 ? -y : 0)
    }

    private func refresh() {
        guard active else { return }
        stop()
        active = true
        controllers = GCController.controllers().filter { $0.extendedGamepad != nil }
        for controller in controllers {
            guard let pad = controller.extendedGamepad else { continue }
            bind(pad.buttonX, to: .skill(-1))
            bind(pad.buttonY, to: .skill(1))
            bind(pad.leftShoulder, to: .target(-1))
            bind(pad.rightShoulder, to: .target(1))
            #if os(iOS)
            bind(pad.buttonA, to: .assign)
            bind(pad.buttonB, to: .pause)
            bind(pad.buttonMenu, to: .pause)
            pad.dpad.valueChangedHandler = { [weak self] _, x, y in
                guard abs(x) > 0.5 || abs(y) > 0.5 else { return }
                let action: Action = abs(x) >= abs(y) ? .target(x < 0 ? -1 : 1) : .skill(y > 0 ? -1 : 1)
                Task { @MainActor in self?.onAction?(action) }
            }
            #endif
        }
    }

    private func bind(_ button: GCControllerButtonInput, to action: Action) {
        button.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.onAction?(action) }
        }
    }
}
#endif
