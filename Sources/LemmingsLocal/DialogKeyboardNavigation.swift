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
        struct Target {
            let view: NSView
            let frame: CGRect
            let rowY: CGFloat
        }
        let flipped = root.isFlipped
        let positions: [Target] = result.map { view in
            let frame = view.convert(view.bounds, to: root)
            let rowY: CGFloat = flipped ? frame.midY : -frame.midY
            return Target(view: view, frame: frame, rowY: rowY)
        }
        let ordered = positions.sorted { a, b in
            a.rowY == b.rowY ? a.frame.minX < b.frame.minX : a.rowY < b.rowY
        }
        var rows: [[Target]] = []
        for target in ordered {
            if let first = rows.last?.first, target.rowY - first.rowY <= 8 {
                rows[rows.count - 1].append(target)
            } else {
                rows.append([target])
            }
        }
        return rows.flatMap { row in
            row.sorted { a, b in
                a.frame.minX == b.frame.minX ? a.rowY < b.rowY : a.frame.minX < b.frame.minX
            }.map(\.view)
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
