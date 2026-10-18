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
        case .up: return L10n.text("D-pad up")
        case .down: return L10n.text("D-pad down")
        case .left: return L10n.text("D-pad left")
        case .right: return L10n.text("D-pad right")
        }
    }
    static func help(mapping: [String: String]) -> String {
        let device = GCController.controllers().first(where: { $0.extendedGamepad != nil })?.vendorName ?? L10n.text("Extended gamepad")
        return ([device] + commands(mapping: mapping).map { $0.keys.isEmpty ? $0.action : "\($0.keys): \($0.action)" }).joined(separator: "\n")
    }

    static func commands(mapping: [String: String], variableSpeed: Bool = true, tapSpeed: Bool = true,
                         rewind: Bool = true, stepping: Bool = true, hints: Bool = true) -> [KeyboardCommand] {
        let mapping = ControllerBindings.validatedMapping(mapping)
        func physical(_ role: ControllerBindings.Button) -> String {
            name(ControllerBindings.Button.allCases.first { (mapping[$0.rawValue] ?? $0.rawValue) == role.rawValue }!)
        }
        let group = L10n.text("Controller")
        var rows = ControllerBindings.Button.allCases.map { button -> KeyboardCommand in
            let action: String
            if button == .rightTrigger {
                if variableSpeed {
                    action = tapSpeed ? L10n.text("Tap: toggle fast-forward; hold: ramp up; release: previous speed")
                        : L10n.text("Hold: ramp up; release: previous speed")
                } else {
                    action = tapSpeed ? L10n.text("Tap: toggle fast-forward; hold: fixed fast-forward") : L10n.text("Hold: fixed fast-forward")
                }
            } else { action = ControllerBindings.roleName(button) }
            return KeyboardCommand(keys: physical(button), action: action, group: group)
        }
        let modifier = physical(.leftTrigger)
        func append(_ key: String, _ action: String) { rows.append(.init(keys: key, action: action, group: group)) }
        if hints { append("\(modifier) + \(physical(.y))", L10n.text("Level hints")) }
        append("\(modifier) + \(physical(.x))", L10n.text("Reset speed"))
        if variableSpeed { append("\(modifier) + \(physical(.left)) / \(physical(.right))", L10n.text("Decrease / increase speed")) }
        append("\(modifier) + \(physical(.up)) / \(physical(.down))", L10n.text("Entrance / exit"))
        if stepping { append("\(modifier) + \(physical(.leftShoulder)) / \(physical(.rightShoulder))", L10n.text("Step one tick; hold to scrub; release to pause")) }
        if rewind { append("\(modifier) + \(physical(.b))", L10n.text("Rewind")) }
        append("\(modifier) + \(physical(.menu))", L10n.text("Retry"))
        append("\(modifier) + \(physical(.a))", L10n.text("Repeat last assignment"))
        append("\(modifier) + \(physical(.options))", L10n.text("Settings"))
        append("\(modifier) + \(physical(.leftStick))", L10n.text("DJ shuffle"))
        append("\(modifier) + \(physical(.rightStick))", L10n.text("Focus last assignment"))
        append(L10n.text("DualSense touchpad click"), L10n.text("DJ shuffle"))
        if stepping { append("", L10n.text("DualSense touchpad swipe: step back / forward")) }
        append("", L10n.text("Sticks: aim and pan, following the Swap sticks setting."))
        append("", L10n.text("Menus always use standard controls: D-pad selects, \(name(.a)) confirms, \(name(.b)) returns."))
        append("", L10n.text("Shoulder buttons change tabs. Right stick scrolls. Release buttons when changing pages."))
        return rows
    }
}
#endif
