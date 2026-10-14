#if os(macOS)
import AppKit
import NxlvKit

/// Routes standard editing commands to the active text field, including secure fields.
@MainActor enum TextEditingMenu {
    static func populate(_ menu: NSMenu) {
        let commands: [(String, Selector, String)] = [
            (L10n.text("Cut"), #selector(NSText.cut(_:)), "x"),
            (L10n.text("Copy"), #selector(NSText.copy(_:)), "c"),
            (L10n.text("Paste"), #selector(NSText.paste(_:)), "v"),
            (L10n.text("Select All"), #selector(NSText.selectAll(_:)), "a"),
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
