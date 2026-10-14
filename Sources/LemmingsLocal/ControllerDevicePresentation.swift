#if os(macOS)
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
        case .leftShoulder: return L10n.text("LB / left shoulder")
        case .rightShoulder: return L10n.text("RB / right shoulder")
        case .leftTrigger: return L10n.text("LT / left trigger")
        case .rightTrigger: return L10n.text("RT / right trigger")
        case .menu: return L10n.text("Menu")
        case .options: return L10n.text("View / Options")
        case .leftStick: return L10n.text("Left stick click")
        case .rightStick: return L10n.text("Right stick click")
        case .up, .down, .left, .right: return L10n.text("D-pad \(button.rawValue)")
        }
    }
    static func help(mapping: [String: String], variableSpeed: Bool = true, tapSpeed: Bool = true,
                     rewind: Bool = true, stepping: Bool = true, hints: Bool = true) -> String {
        let mapping = ControllerBindings.validatedMapping(mapping)
        func physical(_ role: ControllerBindings.Button) -> String {
            name(ControllerBindings.Button.allCases.first { (mapping[$0.rawValue] ?? $0.rawValue) == role.rawValue }!)
        }
        let device = GCController.controllers().first(where: { $0.extendedGamepad != nil })?.vendorName ?? L10n.text("Extended gamepad")
        let rows = ControllerBindings.Button.allCases.map { button in
            let action = button == .rightTrigger
                ? ((tapSpeed ? L10n.text("Tap: toggle fast-forward; ") : "") + (variableSpeed ? L10n.text("hold: ramp up; release: previous speed") : L10n.text("hold: fixed fast-forward")))
                : ControllerBindings.roleName(button)
            return "\(physical(button)): \(action)"
        }
        let modifier = physical(.leftTrigger)
        return ([device, L10n.text("Sticks: aim and pan, following the Swap sticks setting.")] + rows + [
            hints ? L10n.text("\(modifier) + \(physical(.y)): level hints") : "",
            L10n.text("\(modifier) + \(physical(.x)): reset speed"),
            variableSpeed ? L10n.text("\(modifier) + \(physical(.left)) / \(physical(.right)): decrease / increase speed") : "",
            L10n.text("\(modifier) + \(physical(.up)) / \(physical(.down)): entrance / exit"),
            stepping ? L10n.text("\(modifier) + \(physical(.leftShoulder)) / \(physical(.rightShoulder)): step back / forward where supported") : "",
            rewind ? L10n.text("\(modifier) + \(physical(.b)): rewind") : "",
            L10n.text("\(modifier) + \(physical(.menu)): retry"),
            L10n.text("\(modifier) + \(physical(.a)): end run / undo nuke"),
            L10n.text("\(modifier) + \(physical(.options)): settings"),
            L10n.text("\(modifier) + \(physical(.leftStick)): DJ shuffle"),
            L10n.text("DualSense touchpad click: DJ shuffle"),
            L10n.text("Menus always use standard controls: D-pad selects, \(name(.a)) confirms, \(name(.b)) returns."),
            L10n.text("Shoulder buttons change tabs. Right stick scrolls. Release buttons when changing pages.")
        ]).filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
#endif
