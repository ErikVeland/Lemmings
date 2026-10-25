#if os(macOS)
import AppKit
import NxlvKit
import LemmingsGameArt

/// A status inside the current screen. Navigation keeps its existing input targets.
@MainActor final class GameLoadingIndicator: NSView {
    override var isFlipped: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(L10n.text("Loading"))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        GameStyle.fill(bounds, .black)
        GameControlText.draw(L10n.text("Loading..."), in: bounds.insetBy(dx: 8, dy: 2), alignment: .center, role: .heading)
    }
}

@MainActor protocol GameFullWindowPage: AnyObject {}

/// Menus stay in the game window and return to the screen beneath them.
@MainActor final class GameScreen {
    static let shared = GameScreen()
    weak var gameWindow: NSWindow?
    var onPresent: (() -> Void)?
    var onNavigate: (() -> Void)?
    var onMainMenu: (() -> Void)?
    private struct Page {
        let view: NSView
        var focus: NSResponder?
        let dismiss: (() -> Void)?
        let container: GamePageContainer
    }
    private var pages: [Page] = []
    /// Retains the actual browsing pages, including their scroll views and focus.
    final class NavigationReturn {
        fileprivate var restore: (() -> Void)?
        fileprivate var discard: (() -> Void)?
        func cancel() {
            let action = discard
            restore = nil; discard = nil
            action?()
        }
    }
    func retainNavigation() -> NavigationReturn? {
        guard !pages.isEmpty, let window = gameWindow else { return nil }
        pages[pages.count - 1].focus = window.firstResponder
        let retained = pages
        let focus = gameFocus
        let modal = wasAccessibilityModal
        let result = NavigationReturn()
        result.restore = { [weak self, weak window] in
            guard let self, let window else { return }
            self.dismissAll()
            self.gameWindow = window
            self.pages = retained
            self.gameFocus = focus
            self.wasAccessibilityModal = modal
            self.onPresent?()
            self.reattach()
            self.keyboardNavigation.focus(retained.last?.focus, in: window)
            self.updateAccessibility()
        }
        result.discard = { retained.reversed().forEach { $0.dismiss?() } }
        for page in pages { page.container.removeFromSuperview() }
        pages.removeAll()
        updateAccessibility()
        return result
    }
    func restoreNavigation(_ navigation: NavigationReturn) {
        let action = navigation.restore
        navigation.restore = nil; navigation.discard = nil
        action?()
    }
    private var loadingID: UUID?
    private var loadingView: GameLoadingIndicator?
    @discardableResult func beginLoading(owner: NSWindow) -> UUID {
        clearLoading()
        let id = UUID()
        loadingID = id
        let indicator = GameLoadingIndicator(frame: .zero)
        if let page = pages.last?.view as? GameMenuPage {
            page.installLoadingIndicator(indicator)
        } else if let root = owner.contentView {
            indicator.frame = CGRect(x: max(8, (root.bounds.width - 192) / 2),
                y: root.isFlipped ? 12 : max(0, root.bounds.height - 44), width: 192, height: 32)
            indicator.autoresizingMask = [.minXMargin, .maxXMargin, root.isFlipped ? .maxYMargin : .minYMargin]
            root.addSubview(indicator)
        }
        loadingView = indicator
        NSAccessibility.post(element: indicator, notification: .valueChanged)
        return id
    }
    func endLoading(_ id: UUID) {
        guard loadingID == id else { return }
        clearLoading()
    }
    func clearLoading() {
        loadingView?.removeFromSuperview()
        loadingView = nil
        loadingID = nil
    }
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
                MainActor.assumeIsolated { [weak self] in
                    if let window, window === self?.gameWindow, beginning {
                        self?.onNavigate?()
                        self?.updateCursor(suppressed: true)
                    }
                }
                DispatchQueue.main.async { [weak self] in self?.updateAccessibility() }
            })
        }
    }
    @discardableResult func handleDialogKey(_ event: NSEvent) -> Bool {
        guard let window = gameWindow else { return false }
        if let sheet = window.attachedSheet, event.window === sheet, !(sheet is NSSavePanel), let root = sheet.contentView {
            return keyboardNavigation.handle(event, in: root, window: sheet) {
                let buttons = self.keyboardNavigation.controls(in: root).compactMap { $0 as? NSButton }
                if let cancel = buttons.first(where: { $0.keyEquivalent == "\u{1b}" || [L10n.text("Cancel"), L10n.text("Close"), L10n.text("Resume"), L10n.text("Back")].contains($0.title) }) {
                    cancel.performClick(nil)
                } else { sheet.cancelOperation(nil) }
            }
        }
        guard event.window === window, window.attachedSheet == nil, let current = pages.last else { return false }
        return keyboardNavigation.handle(event, in: current.container, window: window) {
            self.goBack(from: current.view)
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
    func controllerNavigationRoot(in window: NSWindow) -> NSView? { gameWindow === window ? pages.last?.container : nil }
    func pageForNavigationRoot(_ root: NSView) -> NSView? {
        pages.first { $0.container === root }?.view
    }
    func goBack(from page: NSView) {
        if let menu = page as? GameMenuPage { menu.onBack?() }
        else if let arcade = page as? ArcadeView { arcade.back() }
        else if let help = page as? KeyboardOverlayView { help.onClose() }
        else if let replay = page as? SolutionReplayPage, let back = replay.onReturnToGame { back() }
        else { dismiss(page) }
    }

    @discardableResult func present(_ view: NSView, owner: NSWindow? = nil,
        focus: NSResponder? = nil, onDismiss: (() -> Void)? = nil) -> Bool {
        guard let window = owner ?? gameWindow ?? NSApp.mainWindow ?? NSApp.keyWindow,
              window.contentView != nil else { return false }
        if !pages.isEmpty, gameWindow !== window { dismissAll() }
        gameWindow = window
        if let page = view as? GameMenuPage, page.onBack == nil, !page.controllerBackButton.isHidden {
            page.onBack = { [weak page] in if let page { self.dismiss(page) } }
        }
        updateCursor(suppressed: true)
        onNavigate?()
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
    /**
     * Rebuild one translated page while retaining the modal stack and the paused game beneath it.
     */
    @discardableResult func replace(_ current: NSView, with replacement: NSView,
        focus: NSResponder? = nil, onDismiss: (() -> Void)? = nil) -> Bool {
        guard let index = pages.firstIndex(where: { $0.view === current }), let window = gameWindow else { return false }
        let previous = pages[index]
        let selected = focus ?? (replacement as? GameMenuPage)?.controllerInitialControl
            ?? keyboardNavigation.controls(in: replacement).first(where: { $0 is NSButton }) ?? replacement
        let container = GamePageContainer(page: replacement)
        let visible = index == pages.count - 1
        replacement.isHidden = !visible
        container.isHidden = !visible
        pages[index] = Page(view: replacement, focus: selected, dismiss: onDismiss, container: container)
        previous.view.removeFromSuperview()
        previous.container.removeFromSuperview()
        if visible {
            reattach()
            keyboardNavigation.focus(selected, in: window)
        }
        updateAccessibility()
        return true
    }
    func dismiss(_ view: NSView) {
        guard let index = pages.firstIndex(where: { $0.view === view }) else { return }
        onNavigate?()
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
        onNavigate?()
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
@MainActor private final class GamePageContainer: NSView {
    private let scroll: GamePageScrollView
    private let home = GameActionButton(title: L10n.text("Main menu"), primary: false)
    private let back: GameActionButton
    private let page: NSView
    override var isFlipped: Bool { true }
    init(page: NSView) {
        self.page = page
        back = GameScreen.shared.onMainMenu != nil
            ? ((page as? GameMenuPage)?.controllerBackButton as? GameActionButton
                ?? (page as? SolutionReplayPage)?.navigationBackButton
                ?? GameActionButton(title: L10n.text("Back"), primary: false))
            : GameActionButton(title: L10n.text("Back"), primary: false)
        scroll = GamePageScrollView(page: page)
        super.init(frame: .zero)
        addSubview(scroll)
        home.setAccessibilityIdentifier("navigation.home")
        home.wrapsTitle = true
        home.onPress = { GameScreen.shared.onMainMenu?() }
        addSubview(home)
        back.setAccessibilityIdentifier("navigation.back")
        back.wrapsTitle = true
        back.onPress = { [weak page] in if let page { GameScreen.shared.goBack(from: page) } }
        addSubview(back)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilitySubrole(.dialog)
        setAccessibilityLabel(page.accessibilityLabel() ?? L10n.text("Game dialog"))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func draw(_ dirtyRect: NSRect) { GameStyle.fill(bounds, .black) }
    override func mouseDown(with event: NSEvent) {}
    override func swipe(with event: NSEvent) {
        if !back.isHidden, event.deltaX > 0 { GameScreen.shared.goBack(from: page) }
        else { super.swipe(with: event) }
    }
    override func layout() {
        super.layout()
        let visible = GameScreen.shared.onMainMenu != nil
        home.isHidden = !visible
        let showsBack = (page as? GameMenuPage)?.controllerBackButton.isHidden != true
        back.title = (page as? GameMenuPage)?.backTitle ?? (page as? SolutionReplayPage)?.navigationBackButton?.title ?? L10n.text("Back")
        back.isHidden = !visible || !showsBack
        let layout = GameNavigationArt.layout(width: bounds.width, actions: GameNavigationArt.actions(back: showsBack, backTitle: back.title))
        for target in layout.targets {
            if target.action.id == "navigation.back" { back.frame = target.frame }
            else if target.action.id == "navigation.home" { home.frame = target.frame }
        }
        let height = visible ? layout.size.height : 0
        scroll.frame = CGRect(x: 0, y: height, width: bounds.width, height: max(0, bounds.height - height))
        scroll.layoutSubtreeIfNeeded()
    }
}

@MainActor private final class GamePageScrollView: NSScrollView {
    private let page: NSView
    init(page: NSView) {
        self.page = page
        super.init(frame: .zero)
        drawsBackground = false
        // Dialog edges stay fixed instead of bouncing away from the underlying game.
        horizontalScrollElasticity = .none
        verticalScrollElasticity = .none
        documentView = page
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilitySubrole(.dialog)
        setAccessibilityLabel(page.accessibilityLabel() ?? L10n.text("Game dialog"))
        setAccessibilityChildren([page])
        page.autoresizingMask = []
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .arrow) }
    override func cursorUpdate(with event: NSEvent) { NSCursor.arrow.set() }
    override func scrollWheel(with event: NSEvent) {
        guard hasHorizontalScroller || hasVerticalScroller else { return }
        super.scrollWheel(with: event)
    }
    override func layout() {
        super.layout()
        scrollerStyle = .overlay
        autohidesScrollers = true
        let size = contentSize
        let documentSize = (page is KeyboardOverlayView || page is GameFullWindowPage || (page as? GameMenuPage)?.adaptsToViewport == true) ? size : GamePageLayout.documentSize(in: size)
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
@MainActor class GameMenuPage: NSView {
    func installLoadingIndicator(_ indicator: NSView) {
        indicator.frame = CGRect(x: 864, y: 110, width: 192, height: 32)
        canvas.addSubview(indicator)
    }
    var onBack: (() -> Void)?
    var onHorizontalNavigation: ((Int) -> Void)?
    let body = NSView()
    var listMinimumHeight: CGFloat = 56
    private var listActions: [(index: Int, button: GameActionButton)] = []
    var adaptsToViewport: Bool { !listActions.isEmpty }
    private var listHeadings: [Int: String] = [:]
    private var footerActions: [NSView] = []
    private let listScroll = NSScrollView()
    private let listDocument = GameMenuListDocument()
    private let canvas: GameMenuCanvas
    private let back = GameActionButton(title: L10n.text("Back"), primary: false)
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
        body.frame = CGRect(x: 64, y: canvas.headerBottom, width: 992, height: max(120, 632 - canvas.headerBottom))
        canvas.addSubview(body)
        back.onPress = { [weak self] in self?.onBack?() }
        back.frame = CGRect(x: 64, y: 634, width: 240, height: 48)
        canvas.addSubview(back)
        footerActions = [back]
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func layout() {
        super.layout()
        if adaptsToViewport {
            let scale = max(1, min(GameAccessibility.scale, bounds.width / 320, bounds.height / 400))
            canvas.frame = bounds
            canvas.bounds = CGRect(x: 0, y: 0, width: bounds.width / scale, height: bounds.height / scale)
            canvas.adaptive = true
            body.frame = CGRect(x: 32, y: canvas.headerBottom, width: max(1, canvas.bounds.width - 64),
                height: max(0, canvas.bounds.height - canvas.headerBottom - 88))
        } else {
            let scale = GamePageLayout.scale(in: bounds.size)
            canvas.frame = CGRect(x: (bounds.width - 1120 * scale) / 2, y: (bounds.height - 720 * scale) / 2,
                                  width: 1120 * scale, height: 720 * scale)
            canvas.bounds = CGRect(x: 0, y: 0, width: 1120, height: 720)
        }
        layoutFooterActions()
        layoutListActions()
        canvas.layoutSubtreeIfNeeded()
    }
    override func draw(_ dirtyRect: NSRect) {
        GameStyle.fill(bounds, .black)
        if let background {
            let image = NSImage(cgImage: background, size: CGSize(width: background.width, height: background.height))
            image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 0.6, respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.none.rawValue])
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
        canvas.setAccessibilityLabel(canvas.title + ". " + detail)
    }
    var backTitle: String {
        get { back.title }
        set { back.title = newValue; back.needsDisplay = true }
    }
    @discardableResult func addPrimaryAction(_ title: String, action: @escaping () -> Void) -> NSButton {
        let button = GameActionButton(title: title, onPress: action)
        button.frame = CGRect(x: 688, y: 634, width: 368, height: 48)
        canvas.addSubview(button)
        primaryAction = button
        footerActions.append(button)
        needsLayout = true
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
        footerActions.insert(button, at: max(1, footerActions.count - (primaryAction == nil ? 0 : 1)))
        needsLayout = true
        return button
    }
    func preferControllerControl(_ control: NSControl) {
        preferredControllerControl = control
    }
    func addFavouriteAction(at slot: Int = 0) -> GameFavouriteButton {
        let button = GameFavouriteButton()
        button.frame = CGRect(x: slot == 0 ? 316 : 502, y: 634, width: 174, height: 48)
        canvas.addSubview(button)
        footerActions.insert(button, at: max(1, footerActions.count - (primaryAction == nil ? 0 : 1)))
        needsLayout = true
        return button
    }
    private func layoutFooterActions() {
        footerActions.removeAll { $0.superview !== canvas }
        let visible = footerActions.filter { !$0.isHidden }
        guard !visible.isEmpty else { return }
        let left: CGFloat = adaptsToViewport ? 32 : 64
        let inner = canvas.bounds.width - left * 2
        let width = (inner - CGFloat(visible.count - 1) * 12) / CGFloat(visible.count)
        let height = max(48, visible.compactMap { $0 as? GameActionButton }.map {
            GameTextLayout.height($0.title, width: width - 24, font: GameMenuArtwork.renderer()?.font(.small)) + 12
        }.max() ?? 48)
        let y = canvas.bounds.height - 38 - height
        for (index, button) in visible.enumerated() {
            (button as? GameActionButton)?.wrapsTitle = true
            button.frame = CGRect(x: left + CGFloat(index) * (width + 12), y: y, width: width, height: height)
        }
        if adaptsToViewport { body.frame.size.height = max(0, y - body.frame.minY - 12) }
    }
    @discardableResult func addListAction(
        _ title: String,
        at index: Int,
        section: String? = nil,
        action: @escaping () -> Void
    ) -> NSButton {
        let button = GameActionButton(title: title, primary: false, onPress: action)
        button.wrapsTitle = true
        if listScroll.superview == nil {
            listScroll.drawsBackground = false
            listScroll.scrollerStyle = .overlay
            listScroll.verticalScrollElasticity = .none
            listScroll.horizontalScrollElasticity = .none
            listScroll.documentView = listDocument
            body.addSubview(listScroll)
        }
        listActions.removeAll { $0.button.superview == nil }
        listActions.append((index, button))
        if let section { listHeadings[index] = section }
        listDocument.addSubview(button)
        needsLayout = true
        return button
    }
    private func layoutListActions() {
        guard listScroll.superview != nil else { return }
        listActions.removeAll { $0.button.superview == nil }
        let ordered = listActions.sorted { $0.index < $1.index }
        listScroll.frame = body.bounds
        let viewport = listScroll.contentSize
        let grid = GameListGrid(actions: ordered.enumerated().map { .init(String($0.offset), $0.element.button.title) },
            width: max(1, viewport.width - 24), columnsEnabled: ordered.count >= 2,
            minimumHeight: listMinimumHeight, captionInset: 24,
            rowHeadings: Dictionary(uniqueKeysWithValues: ordered.enumerated().compactMap { item in
                listHeadings[item.element.index].map { (String(item.offset), $0) }
            }), font: GameMenuArtwork.renderer()?.font(.small))
        listDocument.headings = grid.headings.map { ($0.0, $0.1.offsetBy(dx: 12, dy: 12)) }
        let size = CGSize(width: viewport.width, height: max(viewport.height, grid.height + 24))
        listScroll.hasVerticalScroller = size.height > viewport.height + 0.5
        listDocument.frame = CGRect(origin: .zero, size: size)
        for (item, target) in zip(ordered, grid.targets) { item.button.frame = target.frame.offsetBy(dx: 12, dy: 12) }
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

@MainActor final class GameMenuListDocument: NSView {
    override var isFlipped: Bool { true }
    var headings: [(String, CGRect)] = [] { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        for (title, frame) in headings { GameControlText.draw(title, in: frame, alignment: .left, role: .heading) }
    }
}

@MainActor private final class GameMenuCanvas: NSView {
    let title: String
    let subtitle: String
    var adaptive = false
    var headerBottom: CGFloat {
        let width = adaptive ? max(1, bounds.width - 64) : 928
        let headingHeight = max(40, GameTextLayout.height(title, width: width, face: .large))
        let subtitleHeight = subtitle.isEmpty && adaptive ? 0 : max(24, GameTextLayout.height(subtitle, width: width))
        return max(adaptive ? 100 : 152, (adaptive ? 28 : 48) + headingHeight + 12 + subtitleHeight + 12)
    }
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
        let panel = adaptive ? bounds.insetBy(dx: 14, dy: 12) : CGRect(x: 44, y: 20, width: 1032, height: 676)
        GameStyle.fill(panel, NSColor.black.withAlphaComponent(0.94))
        GameMenuFrame.draw(panel)
        let headingWidth: CGFloat = adaptive ? max(1, bounds.width - 64) : isMessage ? 768 : 928
        let headingHeight = max(40, GameTextLayout.height(title, width: headingWidth, face: .large))
        let heading = CGRect(x: adaptive ? 32 : isMessage ? 176 : 96, y: adaptive ? 28 : isMessage ? 206 : 48, width: headingWidth, height: headingHeight)
        let subheading = CGRect(x: adaptive ? 32 : 96, y: heading.maxY + 12, width: headingWidth, height: max(24, GameTextLayout.height(subtitle, width: headingWidth)))
        let explanationY = max(280, heading.maxY + 16)
        let explanation = CGRect(x: 176, y: explanationY, width: 768, height: max(24, 424 - explanationY))
        if let font {
            font.menuParagraph(title, in: heading, face: .large, palette: .green)
            font.menuParagraph(subtitle, in: subheading)
            font.menuParagraph(detail, in: explanation)
        } else {
            GamePixelText.draw(title, in: heading)
            GamePixelText.draw(subtitle, in: subheading)
            GamePixelText.draw(detail, in: explanation)
        }
    }
}

@MainActor class GameActionButton: NSButton {
    var wrapsTitle = false
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
    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        performClick(nil)
        return true
    }
    override var acceptsFirstResponder: Bool { isEnabled }
    override func becomeFirstResponder() -> Bool { needsDisplay = true; return super.becomeFirstResponder() }
    override func resignFirstResponder() -> Bool { needsDisplay = true; return super.resignFirstResponder() }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let chosen = isEnabled && (primary || isHighlighted)
        GameStoneButton.draw(bounds, selected: chosen, pixel: 1)
        GameControlText.focus(self)
        if wrapsTitle, let renderer {
            let height = min(bounds.height - 12,
                GameTextLayout.height(title, width: bounds.width - 24, face: .small, font: renderer.font(.small)))
            renderer.menuParagraph(title, in: CGRect(x: 12, y: (bounds.height - height) / 2,
                width: bounds.width - 24, height: height), alignment: .center,
                face: .small, palette: .blue, alpha: isEnabled ? 1 : 0.45)
            return
        }
        let height = max(20, renderer?.height(of: title, face: .small, scale: 1) ?? 20)
        let caption = CGRect(x: 12, y: bounds.midY - height / 2, width: bounds.width - 24, height: height)
        if let renderer {
            renderer.menuLine(title, in: caption, face: .small, alpha: isEnabled ? 1 : 0.45, palette: .blue)
        } else { GamePixelText.draw(title, in: caption) }
    }
    @objc private func invoke() { onPress?() }
}
#endif
