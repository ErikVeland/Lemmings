import GameController
import NxlvKit

/// Capture button edges between display frames. Stick movement stays in the frame loop.
@MainActor public final class TVControllerButtonEvents {
    private var controller: GCController?
    private var inputs: [(ControllerBindings.Button, GCControllerButtonInput)] = []
    private var generation = 0
    private var systemGestures: [(GCControllerButtonInput, GCControllerElement.SystemGestureState)] = []
    public private(set) var pressedButtons: Set<ControllerBindings.Button> = []
    public init() {}

    public func stop() {
        generation += 1
        for (_, input) in inputs { input.pressedChangedHandler = nil }
        for (input, state) in systemGestures { input.preferredSystemGestureState = state }
        systemGestures = []
        inputs = []
        controller = nil
        pressedButtons = []
    }

    public func observe(_ controller: GCController,
                        onChange: @escaping @MainActor (Set<ControllerBindings.Button>) -> Void) {
        guard self.controller !== controller else { return }
        stop()
        self.controller = controller
        inputs = Self.buttons(controller)
        pressedButtons = Self.pressed(controller)
        controller.handlerQueue = .main
        let ticket = generation
        for (button, input) in inputs {
            systemGestures.append((input, input.preferredSystemGestureState))
            input.preferredSystemGestureState = .disabled
            input.pressedChangedHandler = { [weak self, weak controller] _, _, pressed in
                MainActor.assumeIsolated {
                    guard let self, let controller, self.controller === controller,
                          self.generation == ticket else { return }
                    // Preserve edge order instead of reading ahead into the live state.
                    if pressed { self.pressedButtons.insert(button) } else { self.pressedButtons.remove(button) }
                    onChange(self.pressedButtons)
                }
            }
        }
    }

    public static func pressed(_ controller: GCController) -> Set<ControllerBindings.Button> {
        Set(buttons(controller).compactMap { $0.1.isPressed ? $0.0 : nil })
    }

    private static func buttons(_ controller: GCController) -> [(ControllerBindings.Button, GCControllerButtonInput)] {
        if let pad = controller.extendedGamepad {
            let inputs: [(ControllerBindings.Button, GCControllerButtonInput?)] = [
                (.a, pad.buttonA), (.b, pad.buttonB), (.x, pad.buttonX), (.y, pad.buttonY),
                (.leftShoulder, pad.leftShoulder), (.rightShoulder, pad.rightShoulder),
                (.leftTrigger, pad.leftTrigger), (.rightTrigger, pad.rightTrigger),
                (.up, pad.dpad.up), (.down, pad.dpad.down), (.left, pad.dpad.left), (.right, pad.dpad.right),
                (.menu, pad.buttonMenu), (.options, pad.buttonOptions),
                (.leftStick, pad.leftThumbstickButton), (.rightStick, pad.rightThumbstickButton)
            ]
            return inputs.compactMap { role, input in input.map { (role, $0) } }
        }
        guard let pad = controller.microGamepad else { return [] }
        let centre = controller.physicalInputProfile.buttons[GCInputDirectionalCenterButton] ?? pad.buttonA
        return [(.a, centre), (.b, pad.buttonX), (.menu, pad.buttonMenu)]
    }
}
