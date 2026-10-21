#if os(macOS)
import AppKit

/// Gameplay uses the same flat popover as Settings, without another window or input target.
@MainActor final class GameplayControlHelp {
    struct Item: Equatable {
        var id: String
        var title: String
        var text: String
        var anchor: CGRect
    }
    private var candidate: Item?
    private var enteredAt: TimeInterval = 0
    private var displayed: Item?
    private var dismissedID: String?
    private(set) var panel: GameSettingsHelpPanel?
    private var inputMonitor: Any?
    private var focusObserver: NSObjectProtocol?

    func update(_ item: Item?, in root: NSView, at now: TimeInterval, focused: Bool = false) {
        guard let item, !item.text.isEmpty else { reset(); return }
        guard item.id != dismissedID else { return }
        dismissedID = nil
        if candidate?.id != item.id {
            reset(); candidate = item; enteredAt = now
        }
        guard focused || now - enteredAt >= Double(GameSettingsHelp.hoverDelay) / 1_000_000_000 else { return }
        if displayed != item {
            panel?.removeFromSuperview()
            let panel = GameSettingsHelpPanel(title: item.title, text: Self.bitmapText(item.text), pinned: false)
            panel.setAccessibilityHelp(item.text)
            self.panel = panel; displayed = item
        }
        guard let panel else { return }
        let width = min(380, root.bounds.width - 24)
        let height = panel.height(for: width)
        guard height <= root.bounds.height - 24 else { reset(); return }
        let below = root.isFlipped ? item.anchor.maxY + 8 : item.anchor.minY - height - 8
        let above = root.isFlipped ? item.anchor.minY - height - 8 : item.anchor.maxY + 8
        let y = below >= root.bounds.minY + 12 && below + height <= root.bounds.maxY - 12 ? below : above
        panel.frame = CGRect(x: max(root.bounds.minX + 12, min(item.anchor.midX - width / 2, root.bounds.maxX - width - 12)),
            y: max(root.bounds.minY + 12, min(y, root.bounds.maxY - height - 12)), width: width, height: height)
        if panel.superview !== root { root.addSubview(panel, positioned: .above, relativeTo: nil) }
        panel.layoutSubtreeIfNeeded()
        if inputMonitor == nil, let window = root.window {
            inputMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown, .scrollWheel]) { [weak self, weak window] event in
                if event.window === window { self?.dismissForInput() }
                return event
            }
            focusObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
                object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reset() }
            }
        }
    }

    private static func bitmapText(_ text: String) -> String {
        text.replacingOccurrences(of: "⌘", with: "Cmd-")
            .replacingOccurrences(of: "⇧", with: "Shift-")
            .replacingOccurrences(of: "⌥", with: "Option-")
            .replacingOccurrences(of: "⌃", with: "Ctrl-")
    }

    func dismissForInput() {
        let id = candidate?.id ?? dismissedID
        reset(); dismissedID = id
    }

    func reset() {
        candidate = nil; displayed = nil; dismissedID = nil
        panel?.removeFromSuperview(); panel = nil
        if let inputMonitor { NSEvent.removeMonitor(inputMonitor); self.inputMonitor = nil }
        if let focusObserver { NotificationCenter.default.removeObserver(focusObserver); self.focusObserver = nil }
    }
}
#endif
