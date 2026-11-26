#if os(macOS)
import AppKit
import LemmingsAppCore
import LemmingsAudio
import NxlvKit
import LemmingsGameArt

/// A status inside the current screen. Navigation keeps its existing input targets.
@MainActor final class GameLoadingIndicator: NSView {
    static let height: CGFloat = 32
    private static let horizontalPadding: CGFloat = 8
    private let message: String
    var preferredWidth: CGFloat {
        let font = GameMenuArtwork.renderer()?.font(.small)
        return max(192, ceil(GameTextLayout.width(of: message, font: font)) + 2 * Self.horizontalPadding)
    }
    override var isFlipped: Bool { true }
    init(frame: NSRect, message: String = L10n.text("Loading...")) {
        self.message = message
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(GamePresentationText.display(message))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        GameStyle.fill(bounds, .black)
        GameControlText.draw(message, in: bounds.insetBy(dx: Self.horizontalPadding, dy: 2),
            alignment: .center, role: .heading)
    }
}

@MainActor private final class GameLoadingIntroView: NSView {
    private let message: String
    private let reducesMotion: Bool
    private let startedAt = ProcessInfo.processInfo.systemUptime
    private var timer: Timer?

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }

    init(frame: CGRect, message: String, reducesMotion: Bool) {
        self.message = message
        self.reducesMotion = reducesMotion
        super.init(frame: frame)
        autoresizingMask = [.width, .height]
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { nil }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        timer?.invalidate()
        timer = nil
        guard window != nil, !reducesMotion else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                if self.window?.isVisible == true { self.needsDisplay = true }
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let reduced = reducesMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let elapsed = reduced ? 0 : ProcessInfo.processInfo.systemUptime - startedAt
        GameLoadingIntroArt.draw(in: bounds, title: AppDistribution.name, message: message,
            elapsed: elapsed, context: context)
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
    private weak var loadingPage: GameMenuPage?
    private var loadingIntroTask: Task<Void, Never>?
    private var loadingIntroView: GameLoadingIntroView?
    private let loadingIntroMusic = GameLoadingIntroMusic()
    private var isLoadingIntroMusicPlaying = false
    var loadingIntroReducesMotion: (() -> Bool)?
    var loadingIntroMusicVolume: (() -> Double)?
    var loadingIntroMusicChanged: ((Bool) -> Void)?

    @discardableResult func beginLoading(owner: NSWindow, message: String = L10n.text("Loading..."),
                                        gameLaunch: Bool = false) -> UUID {
        clearLoading()
        let id = UUID()
        loadingID = id
        let indicator = GameLoadingIndicator(frame: .zero, message: message)
        if let page = pages.last?.view as? GameMenuPage {
            page.setLoadingIndicator(indicator)
            loadingPage = page
        } else if let root = owner.contentView {
            indicator.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(indicator)
            let preferredWidth = indicator.widthAnchor.constraint(equalToConstant: indicator.preferredWidth)
            preferredWidth.priority = .defaultHigh
            NSLayoutConstraint.activate([
                preferredWidth,
                indicator.leadingAnchor.constraint(greaterThanOrEqualTo: root.leadingAnchor, constant: 8),
                indicator.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -8),
                indicator.centerXAnchor.constraint(equalTo: root.centerXAnchor),
                indicator.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
                indicator.heightAnchor.constraint(equalToConstant: GameLoadingIndicator.height),
            ])
        }
        loadingView = indicator
        NSAccessibility.post(element: indicator, notification: .valueChanged)
        if gameLaunch {
            loadingIntroTask = Task { [weak self, weak owner] in
                try? await Task.sleep(nanoseconds: GameLoadingIntroArt.visualDelay)
                guard !Task.isCancelled, let self, self.loadingID == id, let owner,
                      owner.isVisible, owner.attachedSheet == nil, let root = owner.contentView else { return }
                let intro = GameLoadingIntroView(frame: root.bounds, message: message,
                    reducesMotion: self.loadingIntroReducesMotion?() == true
                        || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
                self.loadingIntroView = intro
                root.addSubview(intro, positioned: .above, relativeTo: nil)
                try? await Task.sleep(nanoseconds: GameLoadingIntroArt.musicDelay)
                guard !Task.isCancelled, self.loadingID == id, owner.isKeyWindow, NSApp.isActive,
                      intro.window === owner,
                      let volume = self.loadingIntroMusicVolume?(), self.loadingIntroMusic.play(volume: volume) else { return }
                self.isLoadingIntroMusicPlaying = true
                self.loadingIntroMusicChanged?(true)
            }
        }
        return id
    }
    func endLoading(_ id: UUID) {
        guard loadingID == id else { return }
        clearLoading()
    }
    func stopLoadingIntroMusic() {
        guard isLoadingIntroMusicPlaying else { return }
        loadingIntroMusic.stop()
        isLoadingIntroMusicPlaying = false
        loadingIntroMusicChanged?(false)
    }
    func clearLoading() {
        loadingIntroTask?.cancel()
        loadingIntroTask = nil
        loadingIntroView?.removeFromSuperview()
        loadingIntroView = nil
        stopLoadingIntroMusic()
        if let loadingPage { loadingPage.setLoadingIndicator(nil) }
        else { loadingView?.removeFromSuperview() }
        loadingPage = nil
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
    func reattach(relayout: Bool = false) {
        guard let root = gameWindow?.contentView, let current = pages.last else { return }
        let container = current.container
        let needsAttachment = container.superview !== root
        let needsReveal = needsAttachment || container.isHidden || current.view.isHidden
        guard needsReveal || relayout else { return }
        if needsReveal {
            container.isHidden = true
            current.view.isHidden = false
        }
        if needsAttachment {
            container.removeFromSuperview()
            container.frame = root.bounds
            container.autoresizingMask = [.width, .height]
            root.addSubview(container, positioned: .above, relativeTo: nil)
        }
        container.needsLayout = true
        container.layoutSubtreeIfNeeded()
        current.view.layoutSubtreeIfNeeded()
        if needsReveal {
            container.isHidden = false
            gameWindow?.makeFirstResponder(current.focus)
        }
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
        await chooseSave(panel)
    }
    func chooseSave(_ panel: NSSavePanel) async -> URL? {
        guard let gameWindow else { return nil }
        onNavigate?()
        onPresent?()
        return await withCheckedContinuation { continuation in
            panel.beginSheetModal(for: gameWindow) { response in
                continuation.resume(returning: response == .OK ? panel.url : nil)
            }
        }
    }
    func confirm(_ title: String, detail: String, actionTitle: String, cancelTitle: String = L10n.text("Back"),
                 owner: NSWindow? = nil, action: @escaping () -> Void) {
        let page = GameMenuPage(title: title, subtitle: "")
        page.setDetail(detail)
        page.backTitle = cancelTitle
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
    private var pageHasNavigation: Bool { (page as? SolutionReplayPage)?.hasOwnNavigation == true }
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
        if GameScreen.shared.onMainMenu != nil, let menu = page as? GameMenuPage {
            menu.installNavigationFooter(home: home, back: back)
        }
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilitySubrole(.dialog)
        setAccessibilityLabel(GamePresentationText.display(page.accessibilityLabel() ?? L10n.text("Game dialog")))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func draw(_ dirtyRect: NSRect) { GameStyle.fill(bounds, .black) }
    override func mouseDown(with event: NSEvent) {}
    override func swipe(with event: NSEvent) {
        if !back.isHidden || pageHasNavigation, event.deltaX > 0 { GameScreen.shared.goBack(from: page) }
        else { super.swipe(with: event) }
    }
    override func layout() {
        super.layout()
        let visible = !pageHasNavigation && GameScreen.shared.onMainMenu != nil && (page as? ArcadeView)?.onFirstPlay == nil
        home.isHidden = !visible
        let showsBack = (page as? GameMenuPage)?.controllerBackButton.isHidden != true
        back.title = (page as? GameMenuPage)?.backTitle ?? (page as? SolutionReplayPage)?.navigationBackButton?.title ?? L10n.text("Back")
        back.isHidden = !visible || !showsBack
        if home.superview !== self {
            scroll.frame = bounds
        } else {
            let buttons = [back, home].filter { !$0.isHidden }
            let inset: CGFloat = 24
            let gap: CGFloat = 12
            let width = max(1, (bounds.width - inset * 2 - CGFloat(max(0, buttons.count - 1)) * gap) / CGFloat(max(1, buttons.count)))
            let height = max(48, buttons.map {
                GameTextLayout.height($0.title, width: max(1, width - 24), font: GameMenuArtwork.renderer()?.font(.small)) + 12
            }.max() ?? 48)
            let shelfHeight = visible ? height + inset * 2 : 0
            for (index, button) in buttons.enumerated() {
                button.frame = CGRect(x: inset + CGFloat(index) * (width + gap),
                    y: bounds.height - inset - height, width: width, height: height)
            }
            scroll.frame = CGRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - shelfHeight))
        }
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
        setAccessibilityLabel(GamePresentationText.display(page.accessibilityLabel() ?? L10n.text("Game dialog")))
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
        page.layoutSubtreeIfNeeded()
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
    private weak var loadingIndicator: GameLoadingIndicator?
    func setLoadingIndicator(_ indicator: GameLoadingIndicator?) {
        loadingIndicator?.removeFromSuperview()
        loadingIndicator = indicator
        if let indicator { canvas.addSubview(indicator) }
        needsLayout = true
    }
    var onBack: (() -> Void)?
    var onHorizontalNavigation: ((Int) -> Void)?
    let body = NSView()
    var listTopInset: CGFloat = 0
    var listMinimumHeight: CGFloat = 56
    var listColumnsEnabled = true
    private var listActions: [(index: Int, button: NSButton)] = []
    var adaptsToViewport: Bool { !listActions.isEmpty || !canvas.statisticsRows.isEmpty }
    private var listHeadings: [Int: String] = [:]
    private var footerActions: [NSView] = []
    weak var sidebarTabs: GameTabs?
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
        setAccessibilityLabel(GamePresentationText.display(title))
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
        canvas.compactHeading = sidebarTabs != nil
        if adaptsToViewport {
            canvas.adaptive = true
            let loadingHeight = loadingIndicator == nil ? 0 : GameLoadingIndicator.height
            func preferredContentHeight(at width: CGFloat) -> CGFloat {
                canvas.statisticsRows.isEmpty ? listGrid(width: width - 88).height + 24 + listTopInset
                    : canvas.statisticsHeight
            }
            var scale = max(1, min(GameAccessibility.scale, bounds.width / 320, bounds.height / 400))
            if scale < 2, bounds.width >= 1760 {
                let width = min(1120, bounds.width / 2)
                let footerWidth = max(1, width - 64)
                let visible = footerActions.filter { !$0.isHidden }
                let footerHeight = footerMetrics(visible, width: footerWidth).height
                let height = canvas.headerBottom(at: width) + loadingHeight + preferredContentHeight(at: width) + footerHeight + 50
                if height * 2 <= bounds.height { scale = 2 }
            }
            let width = min(1120, bounds.width / scale)
            let height = bounds.height / scale
            canvas.frame = CGRect(x: floor((bounds.width - width * scale) / 2), y: 0,
                                  width: width * scale, height: bounds.height)
            canvas.bounds = CGRect(x: 0, y: 0, width: width, height: height)
            let bodyTop = canvas.headerBottom + loadingHeight
            body.frame = CGRect(x: 32, y: bodyTop, width: max(1, width - 64), height: max(0, height - bodyTop - 88))
            layoutFooterActions()
            let contentHeight = preferredContentHeight(at: width)
            let excess = max(0, body.frame.height - contentHeight)
            if excess > 0 {
                canvas.frame.origin.y = floor(excess * scale / 2)
                canvas.frame.size.height = (height - excess) * scale
                canvas.bounds.size.height = height - excess
                body.frame.size.height = contentHeight
            }
        } else {
            let scale = GamePageLayout.scale(in: bounds.size)
            canvas.frame = CGRect(x: (bounds.width - 1120 * scale) / 2, y: (bounds.height - 720 * scale) / 2,
                                  width: 1120 * scale, height: 720 * scale)
            canvas.bounds = CGRect(x: 0, y: 0, width: 1120, height: 720)
            if sidebarTabs != nil {
                body.frame.origin.y = canvas.headerBottom
                body.frame.size.height = max(0, 676 - canvas.headerBottom)
            }
        }
        if let indicator = loadingIndicator {
            let inset: CGFloat = adaptsToViewport ? 32 : 64
            let width = min(indicator.preferredWidth, max(0, canvas.bounds.width - 2 * inset))
            indicator.frame = CGRect(x: canvas.bounds.maxX - inset - width, y: adaptsToViewport ? canvas.headerBottom : 110,
                width: width, height: GameLoadingIndicator.height)
        }
        if sidebarTabs == nil { layoutFooterActions() }
        layoutListActions()
        canvas.layoutSubtreeIfNeeded()
        if let sidebarTabs {
            layoutFooterActions(at: sidebarTabs.convert(sidebarTabs.sidebarFooterFrame, to: canvas))
        }
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
        canvas.setAccessibilityLabel(GamePresentationText.display(canvas.title + ". " + detail))
    }
    func setStatistics(_ rows: [String]) {
        canvas.statisticsRows = rows
        canvas.setAccessibilityLabel(GamePresentationText.display(([canvas.title, canvas.subtitle] + rows).joined(separator: ". ")))
        canvas.needsDisplay = true
        needsLayout = true
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
    func installNavigationFooter(home: GameActionButton, back: GameActionButton) {
        for button in footerActions where button.accessibilityIdentifier() == "navigation.home" {
            button.removeFromSuperview()
        }
        footerActions.removeAll { $0.superview !== canvas && $0 !== back }
        canvas.addSubview(back)
        canvas.addSubview(home)
        if !footerActions.contains(where: { $0 === back }) { footerActions.insert(back, at: 0) }
        footerActions.insert(home, at: min(1, footerActions.count))
        needsLayout = true
    }
    private func layoutFooterActions(at sidebar: CGRect? = nil) {
        footerActions.removeAll { $0.superview !== canvas }
        let visible = footerActions.filter { !$0.isHidden }
        guard !visible.isEmpty else { return }
        let left = sidebar?.minX ?? (adaptsToViewport ? 32 : 64)
        let inner = sidebar?.width ?? (canvas.bounds.width - left * 2)
        let (widths, height) = footerMetrics(visible, width: inner, usesPreferredWidths: sidebar != nil)
        let y = sidebar?.minY ?? (canvas.bounds.height - 38 - height)
        var x = left
        for (button, width) in zip(visible, widths) {
            (button as? GameActionButton)?.wrapsTitle = true
            button.frame = CGRect(x: x, y: y, width: width, height: height)
            x += width + 12
        }
        if adaptsToViewport { body.frame.size.height = max(0, y - body.frame.minY - 12) }
    }
    private func footerMetrics(_ visible: [NSView], width inner: CGFloat, usesPreferredWidths: Bool = false)
        -> (widths: [CGFloat], height: CGFloat) {
        guard !visible.isEmpty else { return ([], 0) }
        let space = inner - CGFloat(visible.count - 1) * 12
        let width = space / CGFloat(visible.count)
        let font = GameMenuArtwork.renderer()?.font(.small)
        let preferred = visible.map { view in
            (view as? GameActionButton).map { ceil(GameTextLayout.width(of: $0.title, font: font)) + 24 } ?? width
        }
        let extra = (space - preferred.reduce(0, +)) / CGFloat(visible.count)
        let widths = usesPreferredWidths && extra >= 0 ? preferred.map { $0 + extra } : visible.map { _ in width }
        let height = max(48, zip(visible, widths).compactMap { view, width in
            (view as? GameActionButton).map { GameTextLayout.height($0.title, width: width - 24, font: font) + 12 }
        }.max() ?? 48)
        return (widths, height)
    }
    func isSidebarControl(_ view: NSView) -> Bool {
        guard sidebarTabs != nil else { return false }
        return view is GameTabButton || footerActions.contains { $0 === view }
    }
    @discardableResult func addListAction(
        _ title: String,
        at index: Int,
        section: String? = nil,
        action: @escaping () -> Void
    ) -> NSButton {
        let button = GameActionButton(title: title, primary: false, onPress: action)
        button.wrapsTitle = true
        addListAction(button, at: index, section: section)
        return button
    }
    func addListAction(_ button: NSButton, at index: Int, section: String? = nil) {
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
    }
    private func listGrid(width: CGFloat) -> GameListGrid {
        let ordered = listActions.sorted { $0.index < $1.index }
        return GameListGrid(actions: ordered.enumerated().map { .init(String($0.offset), $0.element.button.title) },
            width: max(1, width), columnsEnabled: listColumnsEnabled && ordered.count >= 2,
            minimumHeight: listMinimumHeight, captionInset: 24,
            rowHeadings: Dictionary(uniqueKeysWithValues: ordered.enumerated().compactMap { item in
                listHeadings[item.element.index].map { (String(item.offset), $0) }
            }), font: GameMenuArtwork.renderer()?.font(.small))
    }
    private func layoutListActions() {
        guard listScroll.superview != nil else { return }
        listActions.removeAll { $0.button.superview == nil }
        let ordered = listActions.sorted { $0.index < $1.index }
        listScroll.frame = CGRect(x: 0, y: 0, width: body.bounds.width, height: max(0, body.bounds.height - listTopInset))
        let viewport = listScroll.contentSize
        let grid = listGrid(width: viewport.width - 24)
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
    var compactHeading = false
    var headerBottom: CGFloat { headerBottom(at: bounds.width) }
    func headerBottom(at canvasWidth: CGFloat) -> CGFloat {
        let width = adaptive ? max(1, canvasWidth - 64) : 928
        let headingHeight = max(40, GameTextLayout.height(title, width: width, face: .large))
        if compactHeading { return 48 + headingHeight + 20 }
        let subtitleHeight = subtitle.isEmpty && adaptive ? 0 : max(24, GameTextLayout.height(subtitle, width: width))
        return max(adaptive ? 100 : 152, (adaptive ? 28 : 48) + headingHeight + 12 + subtitleHeight + 12)
    }
    var detail = ""
    var statisticsRows: [String] = []
    var statisticsHeight: CGFloat {
        statisticsRows.reduce(20) { $0 + GameTextLayout.linePitch($1, font: font?.font(.small)) + 4 }
    }
    var isMessage = false
    private var font: MacInterfaceRenderer? { GameMenuArtwork.renderer() }
    override var isFlipped: Bool { true }
    init(title: String, subtitle: String) {
        self.title = title; self.subtitle = subtitle
        super.init(frame: CGRect(x: 0, y: 0, width: 1120, height: 720))
        setAccessibilityRole(.group)
        setAccessibilityLabel(GamePresentationText.display(title + ". " + subtitle))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func draw(_ dirtyRect: NSRect) {
        if !compactHeading {
            let panel = adaptive ? bounds.insetBy(dx: 14, dy: 12) : CGRect(x: 44, y: 20, width: 1032, height: 676)
            GameStyle.fill(panel, NSColor.black.withAlphaComponent(0.94))
            GameMenuFrame.draw(panel)
        }
        let headingWidth: CGFloat = adaptive ? max(1, bounds.width - 64) : isMessage ? 768 : 928
        let headingHeight = max(40, GameTextLayout.height(title, width: headingWidth, face: .large))
        let heading = CGRect(x: adaptive ? 32 : isMessage ? 176 : 96, y: adaptive ? 28 : isMessage ? 206 : 48, width: headingWidth, height: headingHeight)
        let subheading = CGRect(x: heading.minX, y: heading.maxY + 12, width: headingWidth, height: max(24, GameTextLayout.height(subtitle, width: headingWidth)))
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
        if !statisticsRows.isEmpty { drawStatistics() }
    }
    private func drawStatistics() {
        let bitmapFont = font?.font(.small)
        let rows = statisticsRows.map { row -> (label: String, value: String) in
            guard let colon = row.lastIndex(of: ":") else { return (row, "") }
            let value = row[row.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            return (String(row[...colon]), value)
        }
        let valueWidth = rows.map { GameTextLayout.width(of: $0.value, font: bitmapFont) }.max() ?? 0
        let available = bounds.width - 64
        let gap: CGFloat = valueWidth > 0 ? 20 : 0
        let labelWidth = min(max(1, available - gap - valueWidth),
            rows.map { GameTextLayout.width(of: $0.label, font: bitmapFont) }.max() ?? 0)
        let left = floor((bounds.width - labelWidth - gap - valueWidth) / 2)
        var y = headerBottom + 8
        for (index, row) in rows.enumerated() {
            let height = GameTextLayout.linePitch(statisticsRows[index], font: bitmapFont)
            let label = CGRect(x: left, y: y, width: labelWidth, height: height)
            let value = CGRect(x: label.maxX + gap, y: y, width: valueWidth, height: height)
            if let font {
                font.menuLine(row.label, in: label, alignment: .left)
                font.menuLine(row.value, in: value, alignment: .right)
            } else {
                GamePixelText.draw(row.label, in: label, alignment: .left)
                GamePixelText.draw(row.value, in: value, alignment: .right)
            }
            y += height + 4
        }
    }
}

@MainActor class GameActionButton: NSButton {
    var wrapsTitle = false
    var onPress: (() -> Void)?
    private let primary: Bool
    private var renderer: MacInterfaceRenderer? { GameMenuArtwork.renderer() }
    init(title: String, primary: Bool = true, onPress: (() -> Void)? = nil) {
        self.onPress = onPress
        self.primary = primary
        super.init(frame: .zero)
        self.title = title; target = self; action = #selector(invoke)
        setButtonType(.momentaryPushIn)
        focusRingType = .none
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        performClick(nil)
        return true
    }
    override var acceptsFirstResponder: Bool { isEnabled }
    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { scrollToVisible(bounds) }
        needsDisplay = true
        return accepted
    }
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
