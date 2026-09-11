import AppKit
import NxlvKit

/// Operates the controls on the current page without generating keyboard events.
@MainActor final class ControllerMenuNavigator {
    static private(set) var isActivating = false
    private weak var root: NSView?
    private(set) weak var selected: NSControl?
    private let ring = ControllerSelectionRing()

    func reset() { root = nil; selected = nil; ring.removeFromSuperview() }

    @discardableResult func handle(_ action: ControllerBindings.Action, in view: NSView, sheet: NSWindow? = nil) -> Bool {
        if root !== view { reset(); root = view }
        if action == .cancel || action == .pause {
            reset()
            if let page = view as? GameMenuPage { page.onBack?() }
            else if let sheet {
                let cancel = controls(in: view).compactMap { $0 as? NSButton }.first {
                    $0.keyEquivalent == "\u{1b}" || ["Cancel", "Close", "Resume", "Back"].contains($0.title)
                }
                if let cancel { activate(cancel) } else { sheet.sheetParent?.endSheet(sheet, returnCode: .cancel) }
            }
            return true
        }
        if case let .cycle(direction) = action, let tabs = tabView(in: view), !tabs.tabViewItems.isEmpty {
            let current = tabs.selectedTabViewItem.flatMap { tabs.indexOfTabViewItem($0) } ?? 0
            tabs.selectTabViewItem(at: (current + direction + tabs.tabViewItems.count) % tabs.tabViewItems.count)
            selected = nil
        }
        let choices = controls(in: view)
        guard !choices.isEmpty else { return false }
        if !choices.contains(where: { $0 === selected }) {
            selected = (view as? GameMenuPage)?.controllerBackButton
                ?? (sheet?.defaultButtonCell?.controlView as? NSControl).flatMap { candidate in
                    choices.first(where: { $0 === candidate })
                }
                ?? choices.first(where: { ($0 as? NSButton)?.keyEquivalent == "\r" })
                ?? choices.first(where: { ["Close", "Cancel"].contains(($0 as? NSButton)?.title ?? "") })
                ?? choices.first
        }
        switch action {
        case let .rate(direction): select(-direction, choices: choices)
        case let .focusUnassigned(direction):
            if !adjust(direction) { select(direction, choices: choices) }
        case .assign:
            if let selected { activate(selected) }
        default: break
        }
        if root === view, view.window != nil, let selected, selected.isDescendant(of: view) {
            selected.scrollToVisible(selected.bounds)
            let frame = selected.convert(selected.bounds, to: view).insetBy(dx: -4, dy: -4)
            ring.frame = frame
            if ring.superview !== view { view.addSubview(ring, positioned: .above, relativeTo: nil) }
            ring.needsDisplay = true
        }
        return true
    }

    func scroll(_ delta: Double, in view: NSView) {
        if let scroll = scrollView(in: selected ?? view) ?? scrollView(in: view), let document = scroll.documentView {
            let clip = scroll.contentView
            let y = max(0, min(document.bounds.height - clip.bounds.height, clip.bounds.minY + delta))
            clip.scroll(to: CGPoint(x: clip.bounds.minX, y: y)); scroll.reflectScrolledClipView(clip)
        }
    }

    private func select(_ direction: Int, choices: [NSControl]) {
        let current = choices.firstIndex(where: { $0 === selected }) ?? 0
        selected = choices[(current + direction + choices.count) % choices.count]
    }
    private func activate(_ control: NSControl) {
        Self.isActivating = true
        defer { Self.isActivating = false }
        if let popup = control as? NSPopUpButton {
            _ = adjust(1, control: popup)
        } else if let button = control as? NSButton { button.performClick(nil) }
    }
    private func adjust(_ direction: Int, control: NSControl? = nil) -> Bool {
        guard let control = control ?? selected else { return false }
        if let slider = control as? NSSlider {
            slider.doubleValue = min(slider.maxValue, max(slider.minValue, slider.doubleValue + Double(direction) * (slider.maxValue - slider.minValue) / 20))
        } else if let popup = control as? NSPopUpButton, popup.numberOfItems > 0 {
            let step = direction < 0 ? -1 : 1
            var index = popup.indexOfSelectedItem + step
            while (0..<popup.numberOfItems).contains(index), popup.item(at: index)?.isEnabled != true { index += step }
            guard (0..<popup.numberOfItems).contains(index) else { return true }
            popup.selectItem(at: index)
        } else { return false }
        _ = control.sendAction(control.action, to: control.target)
        return true
    }
    private func controls(in view: NSView) -> [NSControl] {
        var result: [NSControl] = []
        func visit(_ item: NSView) {
            guard !item.isHidden, item.alphaValue > 0 else { return }
            if let tabs = item as? NSTabView { if let body = tabs.selectedTabViewItem?.view { visit(body) }; return }
            if let control = item as? NSControl, control.isEnabled,
               control is NSButton || control is NSSlider { result.append(control); return }
            for child in item.subviews { visit(child) }
        }
        visit(view)
        return result.sorted {
            let a = $0.convert($0.bounds, to: view), b = $1.convert($1.bounds, to: view)
            let ay = view.isFlipped ? a.midY : -a.midY, by = view.isFlipped ? b.midY : -b.midY
            return abs(ay - by) > 8 ? ay < by : a.minX < b.minX
        }
    }
    private func tabView(in view: NSView) -> NSTabView? {
        if let tabs = view as? NSTabView { return tabs }
        return view.subviews.lazy.filter { !$0.isHidden }.compactMap { self.tabView(in: $0) }.first
    }
    private func scrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        if let scroll = view.enclosingScrollView { return scroll }
        return view.subviews.lazy.filter { !$0.isHidden }.compactMap { self.scrollView(in: $0) }.first
    }
}

@MainActor private final class ControllerSelectionRing: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        GameStyle.accent.setStroke()
        let line = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), xRadius: 6, yRadius: 6)
        line.lineWidth = 3; line.stroke()
    }
}
