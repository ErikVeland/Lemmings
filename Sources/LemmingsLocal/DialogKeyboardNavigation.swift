import AppKit

/// Bitmap views with their own virtual controls retain their internal focus loop.
@MainActor protocol GameDialogCustomNavigation: AnyObject {}

/// Keeps keyboard focus inside the current dialog without changing macOS preferences.
@MainActor final class DialogKeyboardNavigation {
    func controls(in root: NSView) -> [NSView] {
        var result: [NSView] = []
        func visit(_ view: NSView) {
            guard !view.isHiddenOrHasHiddenAncestor, view.alphaValue > 0 else { return }
            if let tabs = view as? NSTabView {
                if let selected = tabs.selectedTabViewItem?.view { visit(selected) }
                return
            }
            if let control = view as? NSControl {
                guard control.isEnabled else { return }
                if let field = control as? NSTextField {
                    if field.isEditable || field.isSelectable { result.append(field) }
                } else if control is NSButton || control is NSSlider || control is NSTableView {
                    result.append(control)
                    return
                }
            } else if view.acceptsFirstResponder, (view !== root || view is GameDialogCustomNavigation), !(view is NSScrollView), !(view is NSClipView), !(view is GameMenuPage) {
                result.append(view)
                if view is GameDialogCustomNavigation { return }
            }
            view.subviews.forEach(visit)
        }
        visit(root)
        return result.sorted {
            let a = $0.convert($0.bounds, to: root), b = $1.convert($1.bounds, to: root)
            let ay = root.isFlipped ? a.midY : -a.midY, by = root.isFlipped ? b.midY : -b.midY
            return abs(ay - by) > 8 ? ay < by : a.minX < b.minX
        }
    }

    func focus(_ responder: NSResponder?, in window: NSWindow) {
        (window.firstResponder as? NSView)?.needsDisplay = true
        guard let responder, window.makeFirstResponder(responder) else { return }
        if let view = responder as? NSView {
            view.needsDisplay = true
            view.scrollToVisible(view.bounds)
            NSAccessibility.post(element: view, notification: .focusedUIElementChanged)
        }
    }

    @discardableResult func handle(_ event: NSEvent, in root: NSView, window: NSWindow,
                                  dismiss: () -> Void) -> Bool {
        guard event.type == .keyDown,
              event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return false }
        let responder = window.firstResponder
        let editor = responder as? NSTextView
        let editing = editor?.isEditable == true
        let current = (editor?.isFieldEditor == true ? editor?.delegate as? NSView : responder as? NSView)
        if event.keyCode == 53, current is GameDialogCustomNavigation { return event.isARepeat }
        if event.keyCode == 53 {
            if !event.isARepeat { dismiss() }
            return true
        }
        if !editing, [36, 76, 49].contains(event.keyCode), event.isARepeat { return true }
        if !editing, [123, 124].contains(event.keyCode),
           let navigate = (root as? GameMenuPage)?.onHorizontalNavigation {
            if !event.isARepeat { navigate(event.keyCode == 123 ? -1 : 1) }
            return true
        }
        if current is GameDialogCustomNavigation { return false }
        let choices = controls(in: root)
        guard !choices.isEmpty else { return false }
        let index = choices.firstIndex { $0 === current }
        if event.keyCode == 48 || (!editing && current is NSButton && [123, 124, 125, 126].contains(event.keyCode)) {
            // Popups own arrows. Tab still leaves the popup and stays in this dialog.
            if event.keyCode != 48, current is NSPopUpButton { return false }
            let backward = event.keyCode == 48 ? event.modifierFlags.contains(.shift) : [123, 126].contains(event.keyCode)
            let next = ((index ?? (backward ? 0 : -1)) + (backward ? -1 : 1) + choices.count) % choices.count
            focus(choices[next], in: window)
            return true
        }
        if !editing, [36, 76, 49].contains(event.keyCode), let button = current as? NSButton, button.isEnabled {
            button.performClick(nil)
            return true
        }
        let defaultButton = (root as? GameMenuPage)?.controllerInitialControl as? NSButton
            ?? window.defaultButtonCell?.controlView as? NSButton
            ?? choices.compactMap { $0 as? NSButton }.first(where: { ["Close", "Close (Esc)", "Back", "Resume", "Cancel"].contains($0.title) })
        if [36, 76].contains(event.keyCode), (!editing || editor?.isFieldEditor == true),
           let button = defaultButton,
           button.isEnabled, !button.isHiddenOrHasHiddenAncestor {
            if !event.isARepeat { button.performClick(nil) }
            return true
        }
        return false
    }
}
