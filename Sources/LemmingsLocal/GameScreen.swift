import AppKit
import NxlvKit

/// Menus stay in the game window and return to the screen beneath them.
@MainActor final class GameScreen {
    static let shared = GameScreen()
    weak var gameWindow: NSWindow?
    var onPresent: (() -> Void)?
    private struct Page {
        let view: NSView
        var focus: NSResponder?
        let dismiss: (() -> Void)?
        let container: GamePageContainer
    }
    private var pages: [Page] = []
    let keyboardNavigation = DialogKeyboardNavigation()
    private var keyboardMonitor: Any?
    private var sheetObservers: [NSObjectProtocol] = []
    private var wasAccessibilityModal = false
    private init() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleDialogKey(event) == true ? nil : event
        }
        for name in [NSWindow.willBeginSheetNotification, NSWindow.didEndSheetNotification] {
            sheetObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let window = notification.object as? NSWindow
                let beginning = notification.name == NSWindow.willBeginSheetNotification
                MainActor.assumeIsolated {
                    if let window, window === self?.gameWindow, beginning {
                        self?.updateCursor(suppressed: true)
                    }
                }
                DispatchQueue.main.async { self?.updateAccessibility() }
            })
        }
    }
    @discardableResult func handleDialogKey(_ event: NSEvent) -> Bool {
        guard let window = gameWindow else { return false }
        if let sheet = window.attachedSheet, event.window === sheet, !(sheet is NSSavePanel), let root = sheet.contentView {
            return keyboardNavigation.handle(event, in: root, window: sheet) {
                let buttons = self.keyboardNavigation.controls(in: root).compactMap { $0 as? NSButton }
                if let cancel = buttons.first(where: { $0.keyEquivalent == "\u{1b}" || ["Cancel", "Close", "Resume", "Back"].contains($0.title) }) {
                    cancel.performClick(nil)
                } else { sheet.cancelOperation(nil) }
            }
        }
        guard event.window === window, window.attachedSheet == nil, let current = pages.last else { return false }
        return keyboardNavigation.handle(event, in: current.view, window: window) {
            if let page = current.view as? GameMenuPage { page.onBack?() }
            else { self.dismiss(current.view) }
        }
    }
    private func updateCursor(suppressed: Bool) {
        GameCursor.gameplaySuppressed = suppressed
        if suppressed { NSCursor.arrow.set() }
        func refresh(_ view: NSView) {
            view.needsDisplay = true
            gameWindow?.invalidateCursorRects(for: view)
            view.subviews.forEach(refresh)
        }
        if let root = gameWindow?.contentView { refresh(root) }
    }
    private func updateAccessibility() {
        updateCursor(suppressed: isPresented)
        guard let window = gameWindow else { return }
        if let sheet = window.attachedSheet, !pages.isEmpty { window.setAccessibilityChildren([sheet]) }
        else if let current = pages.last {
            window.setAccessibilityChildren([current.container])
            window.setAccessibilityModal(true)
        } else {
            // Clearing the override with nil leaves the window without children.
            // Restore the current game view, which can change beneath a dialog.
            window.setAccessibilityChildren(window.contentView.map { NSAccessibility.unignoredChildren(from: [$0]) })
            window.setAccessibilityModal(wasAccessibilityModal)
        }
        NSAccessibility.post(element: window, notification: .layoutChanged)
    }
    private let pointerCapture = GamePointerCapture()
    func capturePointer(in window: NSWindow?, enabled: Bool) {
        guard let root = window?.contentView else { pointerCapture.reset(); return }
        _ = pointerCapture.update(in: root, active: enabled)
    }
    private weak var gameFocus: NSResponder?
    var isPresented: Bool { !pages.isEmpty || gameWindow?.attachedSheet != nil }
    func contains(_ view: NSView) -> Bool { pages.contains { $0.view === view } }
    func controllerPage(in window: NSWindow) -> NSView? { gameWindow === window ? pages.last?.view : nil }

    @discardableResult func present(_ view: NSView, owner: NSWindow? = nil,
        focus: NSResponder? = nil, onDismiss: (() -> Void)? = nil) -> Bool {
        guard let window = owner ?? gameWindow ?? NSApp.mainWindow ?? NSApp.keyWindow,
              window.contentView != nil else { return false }
        if !pages.isEmpty, gameWindow !== window { dismissAll() }
        gameWindow = window
        updateCursor(suppressed: true)
        onPresent?()
        if let page = view as? GameMenuPage { page.captureBackdrop(window.contentView!) }
        if let index = pages.firstIndex(where: { $0.view === view }) {
            while pages.count > index + 1 { dismiss(pages.last!.view) }
        } else {
            if pages.isEmpty {
                gameFocus = window.firstResponder
                wasAccessibilityModal = window.isAccessibilityModal()
            } else { pages[pages.count - 1].focus = window.firstResponder }
            pages.last?.view.isHidden = true
            pages.last?.container.isHidden = true
            pages.append(Page(view: view, focus: focus ?? (view as? GameMenuPage)?.controllerInitialControl ?? keyboardNavigation.controls(in: view).first(where: { $0 is NSButton }) ?? view, dismiss: onDismiss, container: GamePageContainer(page: view)))
        }
        reattach()
        keyboardNavigation.focus(focus ?? pages.last?.focus, in: window)
        updateAccessibility()
        return true
    }
    func reattach() {
        guard let root = gameWindow?.contentView, let current = pages.last else { return }
        let container = current.container
        if container.superview !== root {
            container.removeFromSuperview()
            container.frame = root.bounds
            container.autoresizingMask = [.width, .height]
            root.addSubview(container, positioned: .above, relativeTo: nil)
            gameWindow?.makeFirstResponder(current.focus)
        }
        container.isHidden = false
        container.needsLayout = true
        container.layoutSubtreeIfNeeded()
        current.view.isHidden = false
    }
    func dismiss(_ view: NSView) {
        guard let index = pages.firstIndex(where: { $0.view === view }) else { return }
        while pages.count > index {
            let page = pages.removeLast()
            page.view.removeFromSuperview()
            page.container.removeFromSuperview()
            page.dismiss?()
        }
        reattach()
        if let window = gameWindow {
            keyboardNavigation.focus(pages.last?.focus ?? gameFocus ?? window.contentView, in: window)
        }
        updateAccessibility()
    }
    func dismissAll() { if let first = pages.first { dismiss(first.view) } }
    func chooseFile(_ panel: NSOpenPanel) async -> URL? {
        guard let gameWindow else { return nil }
        onPresent?()
        return await withCheckedContinuation { continuation in
            panel.beginSheetModal(for: gameWindow) { response in
                continuation.resume(returning: response == .OK ? panel.url : nil)
            }
        }
    }
    func confirm(_ title: String, detail: String, actionTitle: String, owner: NSWindow? = nil, action: @escaping () -> Void) {
        let page = GameMenuPage(title: title, subtitle: "")
        page.setDetail(detail)
        page.onBack = { [weak page] in if let page { self.dismiss(page) } }
        page.addPrimaryAction(actionTitle) { [weak page] in
            if let page { self.dismiss(page) }
            action()
        }
        // A confirmation starts on Back. Return, Space and controller A must
        // not accept the action without a deliberate move to it.
        page.preferControllerControl(page.controllerBackButton)
        present(page, owner: owner, focus: page.controllerBackButton)
    }
    func message(_ title: String, detail: String) {
        let page = GameMenuPage(title: title)
        page.setDetail(detail)
        page.onBack = { [weak page] in if let page { self.dismiss(page) } }
        present(page)
    }
}

/// Menu size is measured in points. Large windows do not enlarge the base controls.
@MainActor enum GamePageLayout {
    static let reference = CGSize(width: 1120, height: 720)
    static func scale(in size: CGSize) -> CGFloat {
        max(0.01, min(GameAccessibility.scale, size.width / reference.width, size.height / reference.height))
    }
    static func documentSize(in viewport: CGSize) -> CGSize {
        let fit = max(0.01, min(1, viewport.width / reference.width, viewport.height / reference.height))
        let scale = fit * GameAccessibility.scale
        return CGSize(width: max(viewport.width, reference.width * scale),
                      height: max(viewport.height, reference.height * scale))
    }
}

/// Enlarged pages retain their full layout and scroll instead of clipping controls.
@MainActor private final class GamePageContainer: NSScrollView {
    private let page: NSView
    init(page: NSView) {
        self.page = page
        super.init(frame: .zero)
        drawsBackground = false
        documentView = page
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilitySubrole(.dialog)
        setAccessibilityLabel(page.accessibilityLabel() ?? "Game dialog")
        setAccessibilityChildren([page])
        page.autoresizingMask = []
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .arrow) }
    override func cursorUpdate(with event: NSEvent) { NSCursor.arrow.set() }
    override func layout() {
        super.layout()
        scrollerStyle = .overlay
        autohidesScrollers = true
        let size = contentSize
        let documentSize = page is KeyboardOverlayView ? size : GamePageLayout.documentSize(in: size)
        hasHorizontalScroller = documentSize.width > size.width + 0.5
        hasVerticalScroller = documentSize.height > size.height + 0.5
        page.frame = CGRect(origin: .zero, size: documentSize)
        page.needsLayout = true
        if !hasHorizontalScroller && !hasVerticalScroller { contentView.scroll(to: .zero) }
    }
}

@MainActor enum GameStyle {
    static let background = NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.085, alpha: 1)
    static let panel = NSColor(calibratedRed: 0.065, green: 0.10, blue: 0.14, alpha: 1)
    static let accent = NSColor(calibratedRed: 0.66, green: 0.93, blue: 0.32, alpha: 1)
    static let muted = NSColor(calibratedRed: 0.59, green: 0.68, blue: 0.75, alpha: 1)
    static let gold = NSColor(calibratedRed: 1, green: 0.76, blue: 0.30, alpha: 1)
    static func fill(_ rect: CGRect, _ color: NSColor, radius: CGFloat = 0) {
        color.setFill(); NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }

}

/// A full game page for settings, help and long lists.
@MainActor final class GameMenuPage: NSView {
    var onBack: (() -> Void)?
    var onHorizontalNavigation: ((Int) -> Void)?
    let body = NSView()
    private let canvas: GameMenuCanvas
    private let back = GameActionButton(title: "Back", primary: false)
    var controllerBackButton: NSButton { back }
    private weak var preferredControllerControl: NSControl?
    private weak var primaryAction: NSButton?
    var controllerInitialControl: NSControl { preferredControllerControl ?? primaryAction ?? back }
    private var background: CGImage?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    init(title: String, subtitle: String = "") {
        canvas = GameMenuCanvas(title: title, subtitle: subtitle)
        super.init(frame: .zero)
        setAccessibilityRole(.group)
        setAccessibilityLabel(title)
        addSubview(canvas)
        appearance = NSAppearance(named: .darkAqua)
        body.frame = CGRect(x: 64, y: 152, width: 992, height: 480)
        canvas.addSubview(body)
        back.onPress = { [weak self] in self?.onBack?() }
        back.frame = CGRect(x: 64, y: 634, width: 240, height: 48)
        canvas.addSubview(back)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func layout() {
        super.layout()
        let scale = GamePageLayout.scale(in: bounds.size)
        canvas.frame = CGRect(x: (bounds.width - 1120 * scale) / 2, y: (bounds.height - 720 * scale) / 2,
                              width: 1120 * scale, height: 720 * scale)
        canvas.bounds = CGRect(x: 0, y: 0, width: 1120, height: 720)
        canvas.layoutSubtreeIfNeeded()
    }
    override func draw(_ dirtyRect: NSRect) {
        GameStyle.fill(bounds, .black)
        if let background {
            let image = NSImage(cgImage: background, size: CGSize(width: background.width, height: background.height))
            image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 0.6, respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.none])
        }
    }
    // A menu owns pointer input until it closes, including gaps and disabled controls.
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func rightMouseUp(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
    override func otherMouseUp(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}
    override func rightMouseDragged(with event: NSEvent) {}
    override func otherMouseDragged(with event: NSEvent) {}

    func captureBackdrop(_ view: NSView) {
        if canvas.isMessage && background == nil { background = ArcadeWindow.captureScene(view) }
    }
    func setDetail(_ detail: String) {
        canvas.detail = detail; canvas.isMessage = true; canvas.needsDisplay = true
        back.frame = CGRect(x: 440, y: 466, width: 240, height: 48)
        canvas.setAccessibilityLabel(canvas.title + ". " + detail)
    }
    var backTitle: String {
        get { back.title }
        set { back.title = newValue; back.needsDisplay = true }
    }
    @discardableResult func addPrimaryAction(_ title: String, action: @escaping () -> Void) -> NSButton {
        let button = GameActionButton(title: title, onPress: action)
        if canvas.isMessage {
            back.frame = CGRect(x: 176, y: 466, width: 240, height: 48)
            button.frame = CGRect(x: 574, y: 466, width: 370, height: 48)
        } else { button.frame = CGRect(x: 688, y: 634, width: 368, height: 48) }
        canvas.addSubview(button)
        primaryAction = button
        return button
    }
    @discardableResult func addSecondaryAction(
        _ title: String,
        at slot: Int = 0,
        action: @escaping () -> Void
    ) -> NSButton {
        let button = GameActionButton(title: title, primary: false, onPress: action)
        let index = min(1, max(0, slot))
        button.frame = CGRect(x: index == 0 ? 316 : 502, y: 634, width: 174, height: 48)
        canvas.addSubview(button)
        return button
    }
    func preferControllerControl(_ control: NSControl) {
        preferredControllerControl = control
    }
    func addListAction(_ title: String, at index: Int, action: @escaping () -> Void) {
        let button = GameActionButton(title: title, primary: false, onPress: action)
        button.frame = CGRect(x: 40, y: 400 - index * 76, width: 860, height: 56)
        body.addSubview(button)
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.isARepeat, [36, 76, 49].contains(event.keyCode) { return true }
        if window?.firstResponder === self, activatePrimary(with: event) { return true }
        return super.performKeyEquivalent(with: event)
    }
    private func activatePrimary(with event: NSEvent) -> Bool {
        guard [36, 76, 49].contains(event.keyCode),
              event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
              let primaryAction, primaryAction.isEnabled, !primaryAction.isHidden else { return false }
        if !event.isARepeat { primaryAction.performClick(nil) }
        return true
    }
    override func cancelOperation(_ sender: Any?) { onBack?() }
    override func keyDown(with event: NSEvent) {
        if activatePrimary(with: event) { return }
        if event.keyCode == 53 { onBack?() } else { super.keyDown(with: event) }
    }
}

@MainActor private final class GameMenuCanvas: NSView {
    let title: String
    let subtitle: String
    var detail = ""
    var isMessage = false
    private let font = GameMenuArtwork.renderer()
    override var isFlipped: Bool { true }
    init(title: String, subtitle: String) {
        self.title = title; self.subtitle = subtitle
        super.init(frame: CGRect(x: 0, y: 0, width: 1120, height: 720))
        setAccessibilityRole(.group)
        setAccessibilityLabel(title + ". " + subtitle)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func draw(_ dirtyRect: NSRect) {
        let panel = isMessage ? CGRect(x: 144, y: 170, width: 832, height: 376) : CGRect(x: 44, y: 20, width: 1032, height: 676)
        GameStyle.fill(panel, NSColor.black.withAlphaComponent(0.94))
        GameMenuFrame.draw(panel)
        let heading = isMessage ? CGRect(x: 176, y: 206, width: 768, height: 40) : CGRect(x: 96, y: 48, width: 928, height: 40)
        let subheading = CGRect(x: 96, y: 106, width: 928, height: 42)
        let explanation = CGRect(x: 176, y: 280, width: 768, height: 144)
        if let font {
            let scale = font.width(of: MacInterfaceRenderer.menuText(title), face: .large, scale: 2) <= heading.width ? 2 : 1
            font.menuLine(title, in: heading, face: .large, scale: scale, palette: .green)
            font.menuParagraph(subtitle, in: subheading)
            font.menuParagraph(detail, in: explanation)
        } else {
            GamePixelText.draw(title, in: heading)
            GamePixelText.draw(subtitle, in: subheading)
            GamePixelText.draw(detail, in: explanation)
        }
    }
}

@MainActor final class GameActionButton: NSButton {
    var onPress: (() -> Void)?
    private let primary: Bool
    private let renderer = GameMenuArtwork.renderer()
    init(title: String, primary: Bool = true, onPress: (() -> Void)? = nil) {
        self.onPress = onPress
        self.primary = primary
        super.init(frame: .zero)
        self.title = title; target = self; action = #selector(invoke)
        setButtonType(.momentaryPushIn)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override var acceptsFirstResponder: Bool { isEnabled }
    override func becomeFirstResponder() -> Bool { needsDisplay = true; return super.becomeFirstResponder() }
    override func resignFirstResponder() -> Bool { needsDisplay = true; return super.resignFirstResponder() }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let chosen = isEnabled && (primary || isHighlighted)
        GameStoneButton.draw(bounds, selected: chosen, pixel: 1)
        GameControlText.focus(self)
        let caption = CGRect(x: 12, y: bounds.midY - 10, width: bounds.width - 24, height: 20)
        if let renderer {
            renderer.menuLine(title, in: caption, face: .small, alpha: isEnabled ? 1 : 0.45, palette: chosen ? .green : .blue)
        } else { GamePixelText.draw(title, in: caption) }
    }
    @objc private func invoke() { onPress?() }
}
