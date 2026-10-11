#if os(macOS)
import AppKit

/// Help stays inside the game canvas, so it never opens a window or takes focus.
@MainActor final class GameSettingsHelp {
    static let hoverDelay: UInt64 = 800_000_000
    private var targets: [GameSettingsHelpTarget] = []
    private var pending: Task<Void, Never>?
    private(set) var panel: GameSettingsHelpPanel?
    private var inputMonitor: Any?
    private var focusObserver: NSObjectProtocol?

    func reset() {
        dismiss()
        for target in targets {
            guard let view = target.view else { continue }
            for area in view.trackingAreas where (area.owner as? GameSettingsHelpTarget) === target {
                view.removeTrackingArea(area)
            }
        }
        targets.removeAll()
    }

    func attach(_ text: String, to view: NSView, title: String) {
        view.toolTip = nil
        view.setAccessibilityHelp(text)
        let target = GameSettingsHelpTarget(view: view, help: self, title: title, text: text)
        targets.append(target)
        view.addTrackingArea(NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: target, userInfo: nil))
    }

    func hover(_ view: NSView, title: String, text: String) {
        guard panel?.pinned != true else { return }
        dismiss()
        if let window = view.window { observeInput(in: window) }
        pending = Task { [weak self, weak view] in
            try? await Task.sleep(nanoseconds: Self.hoverDelay)
            guard !Task.isCancelled, let self, let view else { return }
            self.show(text, title: title, relativeTo: view)
        }
    }

    func show(_ text: String, title: String, relativeTo view: NSView, pinned: Bool = false) {
        dismiss()
        var ancestor: NSView? = view
        while let candidate = ancestor, !(candidate is GameMenuPage) { ancestor = candidate.superview }
        guard let page = ancestor as? GameMenuPage, let canvas = page.body.superview, let window = page.window,
              !view.isHiddenOrHasHiddenAncestor,
              GameScreen.shared.controllerPage(in: window) === page else { return }
        let panel = GameSettingsHelpPanel(title: title, text: text, pinned: pinned)
        panel.onClose = { [weak self] in self?.dismiss() }
        let anchor = view.convert(view.bounds, to: canvas)
        let width = min(560, canvas.bounds.width - 48)
        let height = panel.height(for: width)
        let below = anchor.maxY + 8
        panel.frame = CGRect(x: max(24, min(anchor.minX, canvas.bounds.maxX - width - 24)),
            y: below + height <= 628 ? below : max(100, anchor.minY - height - 8), width: width, height: height)
        canvas.addSubview(panel, positioned: .above, relativeTo: nil)
        self.panel = panel
        observeInput(in: window)
    }

    private func observeInput(in window: NSWindow) {
        inputMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown, .scrollWheel]) { [weak self] event in
            guard let self, event.window === window else { return event }
            if event.type == .leftMouseDown, let panel = self.panel, panel.pinned,
               panel.bounds.contains(panel.convert(event.locationInWindow, from: nil)) { return event }
            let visible = self.panel != nil
            self.dismiss()
            return visible && event.type == .keyDown && event.keyCode == 53 ? nil : event
        }
        focusObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
            object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss() }
        }
    }

    func exit() {
        if panel?.pinned != true { dismiss() }
    }

    func dismiss() {
        pending?.cancel(); pending = nil
        panel?.removeFromSuperview(); panel = nil
        if let inputMonitor { NSEvent.removeMonitor(inputMonitor); self.inputMonitor = nil }
        if let focusObserver { NotificationCenter.default.removeObserver(focusObserver); self.focusObserver = nil }
    }
}

@MainActor private final class GameSettingsHelpTarget: NSObject {
    weak var view: NSView?
    weak var help: GameSettingsHelp?
    let title: String
    let text: String
    init(view: NSView, help: GameSettingsHelp, title: String, text: String) {
        self.view = view; self.help = help; self.title = title; self.text = text
    }
    @objc(mouseEntered:) func mouseEntered(with event: NSEvent) {
        if let view { help?.hover(view, title: title, text: text) }
    }
    @objc(mouseExited:) func mouseExited(with event: NSEvent) { help?.exit() }
}

@MainActor final class GameSettingsHelpPanel: NSView {
    let pinned: Bool
    var onClose: (() -> Void)?
    private let heading: GameLabel
    private let detail: GameLabel
    private var close: GameActionButton?
    override var isFlipped: Bool { true }
    init(title: String, text: String, pinned: Bool) {
        self.pinned = pinned
        heading = GameLabel(labelWithString: title)
        detail = GameLabel(wrappingLabelWithString: text)
        super.init(frame: .zero)
        heading.role = .heading
        heading.alignment = .left; detail.alignment = .left
        addSubview(heading); addSubview(detail)
        setAccessibilityRole(.group)
        setAccessibilityLabel(title)
        if pinned {
            let button = GameActionButton(title: "Close", primary: false) { [weak self] in self?.onClose?() }
            close = button; addSubview(button)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    func height(for width: CGFloat) -> CGFloat {
        detail.preferredMaxLayoutWidth = width - 24
        return 44 + detail.intrinsicContentSize.height + (pinned ? 42 : 0)
    }
    override func layout() {
        super.layout()
        heading.frame = CGRect(x: 12, y: 10, width: bounds.width - 24, height: 20)
        detail.frame = CGRect(x: 12, y: 36, width: bounds.width - 24, height: bounds.height - 44 - (pinned ? 42 : 0))
        close?.frame = CGRect(x: bounds.width - 116, y: bounds.height - 38, width: 104, height: 28)
    }
    override func hitTest(_ point: NSPoint) -> NSView? { pinned ? super.hitTest(point) : nil }
    override func draw(_ dirtyRect: NSRect) { GameStoneButton.draw(bounds, selected: false, pixel: 1) }
}

@MainActor final class GameSettingsDocument: NSView {
    override var isFlipped: Bool { true }
}

/// Every setting remains reachable when menu size or window size requires scrolling.
@MainActor final class GameSettingsScrollView: NSScrollView {
    var onScroll: (() -> Void)?
    override func layout() {
        super.layout()
        guard let documentView else { return }
        documentView.setFrameSize(NSSize(width: contentSize.width, height: max(contentSize.height, documentView.fittingSize.height)))
    }
    override func reflectScrolledClipView(_ clipView: NSClipView) {
        super.reflectScrolledClipView(clipView)
        onScroll?()
    }
}
#endif
