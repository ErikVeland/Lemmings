import AppKit
import GameController
import NxlvKit

@MainActor enum ControllerDevicePresentation {
    static func element(_ button: ControllerBindings.Button) -> GCControllerElement? {
        guard let pad = GCController.controllers().first(where: { $0.extendedGamepad != nil })?.extendedGamepad else { return nil }
        switch button {
        case .a: return pad.buttonA
        case .b: return pad.buttonB
        case .x: return pad.buttonX
        case .y: return pad.buttonY
        case .leftShoulder: return pad.leftShoulder
        case .rightShoulder: return pad.rightShoulder
        case .leftTrigger: return pad.leftTrigger
        case .rightTrigger: return pad.rightTrigger
        case .menu: return pad.buttonMenu
        case .options: return pad.buttonOptions
        case .leftStick: return pad.leftThumbstickButton
        case .rightStick: return pad.rightThumbstickButton
        case .up: return pad.dpad.up
        case .down: return pad.dpad.down
        case .left: return pad.dpad.left
        case .right: return pad.dpad.right
        }
    }
    static func name(_ button: ControllerBindings.Button) -> String {
        if let name = element(button)?.localizedName, !name.isEmpty { return name }
        switch button {
        case .a, .b, .x, .y: return button.rawValue.uppercased()
        case .leftShoulder: return "LB / left shoulder"
        case .rightShoulder: return "RB / right shoulder"
        case .leftTrigger: return "LT / left trigger"
        case .rightTrigger: return "RT / right trigger"
        case .menu: return "Menu"
        case .options: return "View / Options"
        case .leftStick: return "Left stick click"
        case .rightStick: return "Right stick click"
        case .up, .down, .left, .right: return "D-pad " + button.rawValue
        }
    }
    static func help(mapping: [String: String], variableSpeed: Bool = true, tapSpeed: Bool = true,
                     rewind: Bool = true, stepping: Bool = true, hints: Bool = true) -> String {
        let mapping = ControllerBindings.validatedMapping(mapping)
        func physical(_ role: ControllerBindings.Button) -> String {
            name(ControllerBindings.Button.allCases.first { (mapping[$0.rawValue] ?? $0.rawValue) == role.rawValue }!)
        }
        let device = GCController.controllers().first(where: { $0.extendedGamepad != nil })?.vendorName ?? "Extended gamepad"
        let rows = ControllerBindings.Button.allCases.map { button in
            let action = button == .rightTrigger
                ? ((tapSpeed ? "Tap: toggle fast-forward; " : "") + (variableSpeed ? "hold: ramp up; release: previous speed" : "hold: fixed fast-forward"))
                : ControllerBindings.roleName(button)
            return "\(physical(button)): \(action)"
        }
        let modifier = physical(.leftTrigger)
        return ([device, "Sticks: aim and pan, following the Swap sticks setting."] + rows + [
            hints ? "\(modifier) + \(physical(.y)): level hints" : "",
            "\(modifier) + \(physical(.x)): reset speed",
            variableSpeed ? "\(modifier) + \(physical(.left)) / \(physical(.right)): decrease / increase speed" : "",
            "\(modifier) + \(physical(.up)) / \(physical(.down)): entrance / exit",
            stepping ? "\(modifier) + \(physical(.leftShoulder)) / \(physical(.rightShoulder)): step back / forward where supported" : "",
            rewind ? "\(modifier) + \(physical(.b)): rewind" : "",
            "\(modifier) + \(physical(.menu)): retry",
            "\(modifier) + \(physical(.a)): end run / undo nuke",
            "\(modifier) + \(physical(.options)): settings",
            "Menus always use standard controls: D-pad selects, \(name(.a)) confirms, \(name(.b)) returns.",
            "Shoulder buttons change tabs. Right stick scrolls. Release buttons when changing pages."
        ]).filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
