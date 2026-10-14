#if os(macOS)
import AppKit

/// Routes standard editing commands to the active text field, including secure fields.
@MainActor enum TextEditingMenu {
    static func populate(_ menu: NSMenu) {
        let commands: [(String, Selector, String)] = [
            ("Cut", #selector(NSText.cut(_:)), "x"),
            ("Copy", #selector(NSText.copy(_:)), "c"),
            ("Paste", #selector(NSText.paste(_:)), "v"),
            ("Select All", #selector(NSText.selectAll(_:)), "a"),
        ]
        for (title, action, key) in commands {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = [.command]
            // A nil target lets AppKit use the current field editor and validate the action.
            item.target = nil
            menu.addItem(item)
        }
    }
}
#endif
