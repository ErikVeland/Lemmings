#if os(macOS)
import AppKit
import LemmingsAppCore
import NxlvKit

@MainActor final class GameSpeedControl {
    private(set) var state: GameplaySpeed
    private var musicPitch = GameplayMusicPitch()
    var bulletTimeActive = false { didSet { if oldValue != bulletTimeActive { onChange() } } }
    var onMusicPitchChange: (Double) -> Void = { _ in }
    var onChange: () -> Void = {}
    init(legacyMultiplier: Double = 3) { state = GameplaySpeed(legacyMultiplier: legacyMultiplier) }
    var variableEnabled: Bool {
        get { state.variableEnabled }
        set {
            guard newValue != state.variableEnabled else { return }
            state.cancelInput(at: ProcessInfo.processInfo.systemUptime)
            state.variableEnabled = newValue; onChange()
        }
    }
    var ridiculousEnabled: Bool {
        get { state.ridiculousEnabled }
        set {
            guard newValue != state.ridiculousEnabled else { return }
            state.ridiculousEnabled = newValue; onChange()
        }
    }
    var isFast: Bool { !bulletTimeActive && state.isFast }
    var multiplier: Double {
        PrecisionZoomLedger.effectiveSpeed(normal: state.multiplier,
            active: bulletTimeActive ? .superzoom : nil)
    }
    var label: String { bulletTimeActive ? "0.5×" : state.label }
    var target: Double { state.target }
    var panelLabel: String { label }
    var choiceLabel: String { "\(Int(state.cruise))×" }
    func pointerDown(at now: TimeInterval, clickCount: Int) {
        state.press(.mouse, at: now)
        onChange()
    }
    func update(at now: TimeInterval, active: Bool) {
        if active { state.update(at: now) } else { state.suspend(at: now) }
        let previous = musicPitch.cents
        musicPitch.update(speed: active && variableEnabled && !bulletTimeActive
            ? state.musicPitchSpeed(at: now) : 1, at: now)
        if musicPitch.cents != previous { onMusicPitchChange(musicPitch.cents) }
    }
    func tap(at now: TimeInterval = ProcessInfo.processInfo.systemUptime, clickCount: Int = 1) {
        state.tap(at: now, clickCount: clickCount); onChange()
    }
    func step(_ direction: Int, at now: TimeInterval) { state.step(direction, at: now); onChange() }
    func press(_ key: GameplaySpeed.Hold, at now: TimeInterval, tapEnabled: Bool = true) { state.press(key, at: now, tapEnabled: tapEnabled); onChange() }
    func release(_ key: GameplaySpeed.Hold, at now: TimeInterval, allowTap: Bool = true) { state.release(key, at: now, allowTap: allowTap); onChange() }
    func newLevel() { state.newLevel(at: ProcessInfo.processInfo.systemUptime); onChange() }
    func reset(at now: TimeInterval = ProcessInfo.processInfo.systemUptime) { state.reset(at: now); onChange() }
    func cancelInput() { state.cancelInput(at: ProcessInfo.processInfo.systemUptime); onChange() }
    func setFast(_ enabled: Bool) { state.setFast(enabled, at: ProcessInfo.processInfo.systemUptime); onChange() }
    var help: String {
        if variableEnabled && ridiculousEnabled {
            return L10n.text("F / Speed: toggle fast-forward\nHold F: ramp up to 25×; release: keep speed\nHold Shift, Speed or RT: temporary boost; release: previous speed\nSpeed arrows or Shift+[ / Shift+]: apply 1×, 2×, 3×, 5×, 10× or 25×\nF or controller B: immediately return to 1×")
        }
        return variableEnabled
            ? L10n.text("F / Speed: toggle fast-forward\nHold F: ramp up to 10×; release: keep speed\nHold Shift, Speed or RT: temporary boost; release: previous speed\nSpeed arrows or Shift+[ / Shift+]: apply 1×, 2×, 3×, 5× or 10×\nF or controller B: immediately return to 1×")
            : L10n.text("F / Speed: toggle fast-forward")
    }
}

/// Shared gameplay keys follow the active window, including an attached sequel.
@MainActor final class GameplayKeyboard {
    nonisolated(unsafe) private var monitor: Any?
    nonisolated(unsafe) private var focusObserver: NSObjectProtocol?
    nonisolated(unsafe) private var appFocusObserver: NSObjectProtocol?
    private weak var window: NSWindow?
    private var controller: GameplayController?
    private var pressedF = false
    private var fKeyCode: UInt16 = 3
    private let menuNavigator = ControllerMenuNavigator()
    var active: () -> Bool = { false }
    var ownsController: () -> Bool = { true }
    var pauseOnInterruption: () -> Bool = { true }
    var onInterruption: () -> Void = {}
    private(set) var interruptionCount = 0
    var controllerEnabled: () -> Bool = { true }
    var controllerTapSpeed: () -> Bool = { true }
    var controllerMappings: () -> [String: String] = { [:] }
    var controllerSwapSticks: () -> Bool = { false }
    var modern: () -> Bool = { true }
    var speedControl: GameSpeedControl?
    var assignSelected: () -> Void = {}
    var togglePause: () -> Void = {}
    var inspectionAvailable: () -> Bool = { false }
    var inspectLemmings: (() -> Void)?
    var inspectionHoverID: () -> Int? = { nil }
    var inspectionHoverRevision: () -> String = { "" }
    var inspectionHoverSnapshot: () -> LemmingInspection? = { nil }
    private let inspectionHover = LemmingInspectionHover(frame: .zero)
    private var hoverRevision: String?
    private var hoverSnapshot: LemmingInspection?
    var movePointer: (Double, Double) -> Void = { _, _ in }
    var panCamera: (Double, Double) -> Void = { _, _ in }
    var menuActive: () -> Bool = { false }
    var menuKey: (String) -> Void = { _ in }
    var cycle: (Int) -> Void = { _ in }
    var centre: (Bool) -> Void = { _ in }
    /// L2 gives Glider the first G press. Return false to centre the goal.
    var selectGliderBeforeGoal: (() -> Bool)?
    var rate: ((Int) -> Void)?
    /// A double tap of + or - moves the release rate to its maximum or minimum.
    var rateLimit: ((Int) -> Void)?
    /// N nukes, or undoes the nuke while that is still possible.
    var nukeToggle: (() -> Void)?
    private var rateTap = DoubleTap()
    var focusUnassigned: (Int) -> Void = { _ in }
    var focusLast: () -> Void = {}
    var repeatAssignment: () -> Void = {}
    var djShuffle: (() -> Void)?
    var escape: () -> Void = {}
    var mainMenu: (() -> Void)?
    var navigationAvailable: () -> Bool = { true }
    var playingTrack: () -> PlayingTrack? = { nil }
    /// The rendered playfield in the content view's coordinates, excluding the HUD.
    var musicDisplayArea: () -> CGRect? = { nil }
    private let nowPlayingNotice = NowPlayingNotice(frame: .zero)
    var navigationReduceMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var showSongInfo: () -> Bool = { true }
    var fadeMenuButton: () -> Bool = { true }
    var navigationArtworkOpacityChanged: (CGFloat) -> Void = { _ in }
    /// Badge bounds use the content view's coordinates, including while faded.
    var rewardDisplayArea: () -> CGRect? = { nil }
    var extraSkill: (() -> Void)?
    var extraSkillTitle: () -> String = { L10n.text("Extra skill") }
    var extraSkillHelp: () -> String = { "" }
    var extraSkillAvailable: () -> Bool = { false }
    private lazy var navigationButton: GameplayMenuButton = {
        let button = GameplayMenuButton(frame: .zero)
        button.title = L10n.text("Menu"); button.target = self; button.action = #selector(openMainMenu)
        button.setAccessibilityLabel(L10n.text("Save run and return to library"))
        button.toolTip = L10n.text("Return to library (Esc or Q)")
        return button
    }()
    private lazy var settingsButton: GameplayMenuButton = {
        let button = GameplayMenuButton(frame: .zero)
        button.title = L10n.text("Settings"); button.glyph = .settings
        button.target = self; button.action = #selector(openSettings)
        button.setAccessibilityLabel(L10n.text("Settings"))
        button.toolTip = L10n.text("Settings (⌘,)")
        return button
    }()
    private lazy var graphicsButton: GameplayMenuButton = {
        let button = GameplayMenuButton(frame: .zero)
        button.title = L10n.text("Graphics"); button.target = self; button.action = #selector(cycleGraphics)
        button.setAccessibilityLabel(L10n.text("Next graphics"))
        return button
    }()
    private lazy var ghostsButton: GameplayMenuButton = {
        let button = GameplayMenuButton(frame: .zero)
        button.target = self; button.action = #selector(toggleHotSeatGhosts)
        button.toolTip = L10n.text("Show or hide Hot Seat ghosts (⌘G)")
        return button
    }()
    private lazy var extraSkillButton: GameplayMenuButton = {
        let button = GameplayMenuButton(frame: .zero)
        button.target = self; button.action = #selector(useExtraSkill)
        return button
    }()
    @objc private func useExtraSkill() {
        guard active(), modern(), extraSkillAvailable(), ArcadeStore.shared.profilesAreWritable,
              ArcadeStore.shared.storageError == nil else { return }
        extraSkill?()
        revealRewards()
    }
    func revealRewards(at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        navigationButtons.forEach { $0.revealArtwork(at: now) }
        navigationArtworkOpacityChanged(1)
    }
    @objc private func toggleHotSeatGhosts() {
        guard ArcadeStore.shared.hotSeatIsActive else { return }
        ArcadeStore.shared.hotSeatGhostsVisible.toggle()
        func redraw(_ view: NSView) {
            view.needsDisplay = true
            view.subviews.forEach(redraw)
        }
        if let root = window?.contentView { redraw(root) }
        refreshNavigationControl()
    }
    func handleGhostKey(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, ownsController(), navigationAvailable(), ArcadeStore.shared.hotSeatIsActive,
              event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command,
              event.charactersIgnoringModifiers?.lowercased() == "g" else { return false }
        if !event.isARepeat { toggleHotSeatGhosts() }
        return true
    }
    private var navigationButtons: [GameplayMenuButton] { [navigationButton, settingsButton, graphicsButton, ghostsButton, extraSkillButton] }
    @objc private func openInspection() {
        guard inspectionAvailable() else { return }
        inspectLemmings?()
    }
    @objc private func openMainMenu() { mainMenu?() }
    @objc private func openSettings() { settings?() }
    @objc private func cycleGraphics() {
        guard graphicsAvailable() else { return }
        nextGraphics?()
        refreshNavigationControl()
    }
    func removeNavigationControl() {
        inspectionHover.removeFromSuperview(); hoverSnapshot = nil; hoverRevision = nil
        navigationButtons.forEach { $0.resetAppearance(); $0.removeFromSuperview() }
        nowPlayingNotice.removeFromSuperview()
    }
    func navigationFrame(in view: NSView) -> CGRect? {
        navigationButtons.compactMap { button -> CGRect? in
            guard !button.isHidden, let root = button.superview, view.window === root.window else { return nil }
            return view.convert(button.frame, from: root)
        }.reduce(nil) { $0?.union($1) ?? $1 }
    }
    func refreshNavigationControl(at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard let root = window?.contentView else { return }
        let visible = mainMenu != nil && ownsController() && navigationAvailable()
            && window?.attachedSheet == nil && !GameScreen.shared.isPresented
        let menuFrame = CGRect(x: max(0, root.bounds.maxX - 100),
            y: root.isFlipped ? 64 : max(0, root.bounds.maxY - 108), width: 88, height: 44)
        settingsButton.frame = CGRect(x: menuFrame.minX - 52, y: menuFrame.minY, width: 44, height: 44)
        graphicsButton.frame = CGRect(x: settingsButton.frame.minX - 120, y: menuFrame.minY, width: 112, height: 44)
        navigationButton.frame = menuFrame
        ghostsButton.frame = CGRect(x: menuFrame.maxX - 176,
            y: menuFrame.minY + (root.isFlipped ? 52 : -52), width: 176, height: 44)
        extraSkillButton.frame = CGRect(x: ArcadeStore.shared.hotSeatIsActive ? ghostsButton.frame.minX - 232 : menuFrame.maxX - 224,
            y: ghostsButton.frame.minY, width: 224, height: 44)
        extraSkillButton.title = extraSkillTitle()
        extraSkillButton.toolTip = extraSkillHelp()
        extraSkillButton.setAccessibilityLabel(extraSkillTitle())
        extraSkillButton.setAccessibilityHelp(extraSkillHelp())
        extraSkillButton.isEnabled = extraSkillAvailable() && ArcadeStore.shared.profilesAreWritable
            && ArcadeStore.shared.storageError == nil
        let showsGhosts = ArcadeStore.shared.hotSeatGhostsVisible
        ghostsButton.title = showsGhosts ? L10n.text("Ghosts on") : L10n.text("Ghosts off")
        ghostsButton.state = showsGhosts ? .on : .off
        ghostsButton.setAccessibilityLabel(L10n.text("Show Hot Seat ghosts"))
        ghostsButton.setAccessibilityValue(showsGhosts ? 1 : 0)
        let controlsFrame = menuFrame.union(settingsButton.frame).union(graphicsButton.frame)
            .union(ArcadeStore.shared.hotSeatIsActive ? ghostsButton.frame : .null)
            .union(extraSkill != nil && modern() ? extraSkillButton.frame : .null)
        let pointer = root.convert(window!.mouseLocationOutsideOfEventStream, from: nil)
        if visible, rewardDisplayArea()?.contains(pointer) == true { revealRewards(at: now) }
        var noticeArea = (musicDisplayArea() ?? root.bounds).intersection(root.bounds)
        if visible, noticeArea.intersects(controlsFrame) {
            noticeArea.size.width = max(0, min(noticeArea.maxX, controlsFrame.minX - 8) - noticeArea.minX)
        }
        if nowPlayingNotice.superview !== root { nowPlayingNotice.removeFromSuperview(); root.addSubview(nowPlayingNotice) }
        nowPlayingNotice.update(track: playingTrack(), at: now,
            visible: active() && ownsController() && !GameScreen.shared.isPresented && window?.attachedSheet == nil,
            reduceMotion: navigationReduceMotion(), enabled: showSongInfo(),
            area: noticeArea, flipped: root.isFlipped)
        for button in navigationButtons {
            let available = button === extraSkillButton ? extraSkill != nil && modern() && active()
                : button === ghostsButton ? ArcadeStore.shared.hotSeatIsActive
                : button === navigationButton || (active() && (button === settingsButton ? settings != nil : nextGraphics != nil))
            guard visible && available else { button.isHidden = true; button.resetAppearance(); continue }
            if button.superview !== root {
                button.removeFromSuperview(); root.addSubview(button); button.resetAppearance()
            }
            button.isHidden = false
            button.updateAppearance(at: now, autoHide: active() && fadeMenuButton(), reduceMotion: navigationReduceMotion())
        }
        navigationArtworkOpacityChanged(navigationButtons.filter { !$0.isHidden }.map(\.artworkOpacity).max() ?? 0)
        let canCycle = graphicsAvailable()
        if graphicsButton.isEnabled != canCycle { graphicsButton.isEnabled = canCycle }
        let name = graphicsName()
        let tooltip = L10n.text("Next graphics (F2)") + ": " + name
        if graphicsButton.toolTip != tooltip {
            graphicsButton.setAccessibilityValue(name)
            graphicsButton.toolTip = tooltip
        }
        updateInspectionHover(in: root, available: visible && active() && inspectionAvailable() && window?.isKeyWindow == true,
            area: musicDisplayArea() ?? root.bounds, pointer: root.convert(window!.mouseLocationOutsideOfEventStream, from: nil))
    }
    func updateInspectionHover(in root: NSView, available: Bool, area: CGRect, pointer: CGPoint) {
        guard available else {
            inspectionHover.isHidden = true; hoverSnapshot = nil; hoverRevision = nil; return
        }
        guard area.contains(pointer), let id = inspectionHoverID() else { inspectionHover.isHidden = true; return }
        let revision = inspectionHoverRevision()
        if hoverRevision != revision {
            hoverSnapshot = inspectionHoverSnapshot(); hoverRevision = revision
        }
        guard let individual = hoverSnapshot?.individuals.first(where: { $0.id == id }) else {
            inspectionHover.isHidden = true; return
        }
        inspectionHover.show(individual, in: root, area: area, pointer: pointer)
    }
    var engineCommands: () -> [KeyboardCommand] = { [] }
    var skillNames: () -> [String] = { [] }
    var cyclesSharedSkillLetters = true
    var overlayControls: () -> [Any] = { [] }
    var contextCommands: () -> [KeyboardCommand] = { [] }
    var hints: (() -> Void)?
    var settings: (() -> Void)?
    var nextGraphics: (() -> Void)?
    var graphicsAvailable: () -> Bool = { true }
    var graphicsName: () -> String = { "" }
    var retry: (() -> Void)?
    var openRetainedSolution: () -> Bool = { false }
    var precisionZoom: ((PrecisionZoomKind) -> Void)?
    var rewind: (() -> Void)?
    var controllerRewindHeld: (Bool) -> Void = { _ in }
    var step: ((Int) -> Void)?
    var endRun: (() -> Void)?
    var pauseForHelp: () -> (() -> Void) = { {} }

    init(window: NSWindow) {
        self.window = window
        controller = GameplayController(keyboard: self)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
        focusObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: .main) { [weak self] note in
            let identity = (note.object as? NSWindow).map(ObjectIdentifier.init)
            MainActor.assumeIsolated {
                guard let self, identity == self.window.map(ObjectIdentifier.init) else { return }
                if self.window?.attachedSheet == nil { self.handleInterruption() }
                else { self.pressedF = false; self.speedControl?.cancelInput() }
            }
        }
        appFocusObserver = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleInterruption() }
        }
    }
    func handleInterruption() {
        pressedF = false; speedControl?.cancelInput()
        guard ownsController(), pauseOnInterruption() else { return }
        interruptionCount += 1
        onInterruption()
    }
    func bind(to window: NSWindow) { speedControl?.cancelInput(); pressedF = false; self.window = window }

    /// Restore gameplay focus after AppKit finishes the menu action that started it.
    func focusGameplay(_ view: NSView) {
        func focus() {
            guard let window, view.window === window, active(), ownsController(),
                  window.attachedSheet == nil, !GameScreen.shared.isPresented else { return }
            window.makeFirstResponder(view)
        }
        focus()
        DispatchQueue.main.async { [weak self, weak view] in
            guard let self, let view, let window = self.window, view.window === window,
                  self.active(), self.ownsController(), window.attachedSheet == nil,
                  !GameScreen.shared.isPresented else { return }
            window.makeFirstResponder(view)
        }
    }

    // Kept separate from the monitor so input routing can be tested with real events.
    func handle(_ event: NSEvent) -> NSEvent? {
        let now = event.timestamp
        if event.type == .keyUp, event.keyCode == fKeyCode {
            guard pressedF else { return event }
            pressedF = false
            speedControl?.release(.key, at: now)
            return nil
        }
        if event.type == .flagsChanged, !event.modifierFlags.contains(.shift) {
            speedControl?.release(.shift, at: now)
        }
        if event.window === window, !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            pressedF = false; speedControl?.cancelInput()
        }
        guard let window, event.window === window, window.isKeyWindow,
              window.attachedSheet == nil, !GameScreen.shared.isPresented,
              !(window.firstResponder is NSTextView) else { return event }
        if event.type == .keyDown, active(), ownsController(),
           event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command,
           event.charactersIgnoringModifiers == ",", let settings {
            if !event.isARepeat { settings() }
            return nil
        }
        if event.type == .keyDown, active(), ownsController(),
           event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "z", let step {
            if !event.isARepeat { step(-1) }
            return nil
        }
        if event.type == .keyDown, active(), ownsController(), inspectionAvailable(), inspectLemmings != nil,
           event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "i" {
            if !event.isARepeat { openInspection() }
            return nil
        }
        if handleGhostKey(event) { return nil }
        if event.type == .keyDown, active(), ownsController(), modern(), extraSkill != nil,
           event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "e" {
            if !event.isARepeat { useExtraSkill() }
            return nil
        }
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
        if event.type == .keyDown, ownsController(), navigationAvailable(),
           event.keyCode == 53 || event.charactersIgnoringModifiers?.lowercased() == "q", let mainMenu {
            if !event.isARepeat {
                pressedF = false; speedControl?.reset(at: now); mainMenu()
            }
            return nil
        }
        guard active() else { return event }
        if event.type == .flagsChanged {
            if modern(), event.modifierFlags.contains(.shift) { speedControl?.press(.shift, at: now) }
            return event
        }
        guard event.type == .keyDown else { return event }
        if event.keyCode == 120, ownsController(), nextGraphics != nil {
            if !event.isARepeat { cycleGraphics() }
            return nil
        }
        // Handle pause before AppKit sends Space to the focused control or canvas.
        let sharedCommand = GameplayCommands.command(key: event.keyCode == 122 ? "f1" : (event.charactersIgnoringModifiers ?? ""),
            shift: event.modifierFlags.contains(.shift))
        if sharedCommand == .djShuffle, let djShuffle {
            if !event.isARepeat { djShuffle() }
            return nil
        }
        if sharedCommand == .pause || event.keyCode == 49 {
            if !event.isARepeat { togglePause() }
            return nil
        }
        if event.charactersIgnoringModifiers?.lowercased() == "z", let precisionZoom {
            if event.modifierFlags.contains(.shift) { speedControl?.release(.shift, at: now, allowTap: false) }
            if !event.isARepeat { precisionZoom(event.modifierFlags.contains(.shift) ? .superzoom : .zoom) }
            return nil
        }
        // Slash opens hints. Question mark keeps the controls guide.
        if sharedCommand == .hints,
           let hints {
            if !event.isARepeat { hints() }
            return nil
        }
        if modern(), let letter = event.charactersIgnoringModifiers?.lowercased(), ["h", "g"].contains(letter) {
            if !event.isARepeat {
                if letter == "h" { centre(true) }
                else if selectGliderBeforeGoal?() != true { centre(false) }
            }
            return nil
        }
        let key = event.characters ?? ""
        if event.charactersIgnoringModifiers?.lowercased() == "f" {
            if !event.isARepeat {
                pressedF = true; fKeyCode = event.keyCode
                if speedControl?.variableEnabled == true { speedControl?.press(.key, at: now) }
                else { speedControl?.tap(at: now) }
            }
            return nil
        }
        if speedControl?.variableEnabled == true,
           key == "|" {
            speedControl?.reset(at: now); return nil
        }
        if event.modifierFlags.contains(.shift) { speedControl?.release(.shift, at: now) }
        if speedControl?.variableEnabled == true {
            if key == "{" || key == "}" {
                if !event.isARepeat { speedControl?.step(key == "{" ? -1 : 1, at: now) }
                return nil
            }
        }
        if modern(), key == "[" || key == "]" {
            if !event.isARepeat { focusUnassigned(key == "[" ? -1 : 1) }
            return nil
        }
        if modern(), key == "\\" { if !event.isARepeat { focusLast() }; return nil }
        if modern(), event.keyCode == 36 || event.keyCode == 76 {
            if !event.isARepeat { repeatAssignment() }
            return nil
        }
        if modern() {
            switch event.keyCode {
            case 48: cycle(event.modifierFlags.contains(.shift) ? -1 : 1); return nil
            case 115: centre(true); return nil
            case 119: centre(false); return nil
            default: break
            }
        }
        if event.keyCode == 53 || event.charactersIgnoringModifiers?.lowercased() == "q" {
            if !event.isARepeat {
                pressedF = false
                speedControl?.reset(at: now)
                if let mainMenu { mainMenu() } else { escape() }
            }
            return nil
        }
        if key == "?" {
            if event.isARepeat { return nil }
            showHelp()
            return nil
        }
        if ["-", "−", "+", "="].contains(key), let rate {
            let direction = key == "-" || key == "−" ? -1 : 1
            if rateTap.press(direction < 0 ? "-" : "+", at: now, interval: NSEvent.doubleClickInterval,
                             isRepeat: event.isARepeat), let rateLimit {
                rateLimit(direction)
            } else {
                rate(direction)
            }
            return nil
        }
        if event.charactersIgnoringModifiers?.lowercased() == "n", let nukeToggle {
            if !event.isARepeat { nukeToggle() }
            return nil
        }
        return event
    }
    var controllerAvailable: Bool {
        controllerIsAvailable(applicationActive: NSApp.isActive)
    }
    func controllerIsAvailable(applicationActive: Bool) -> Bool {
        guard ownsController(), applicationActive, let window,
              window.isKeyWindow || window.attachedSheet?.isKeyWindow == true else { return false }
        return active() || menuActive() || window.attachedSheet != nil || GameScreen.shared.controllerPage(in: window) != nil
    }
    var controllerPlaying: Bool { controllerEnabled() && controllerAvailable && controllerMenuRoot == nil && active() }
    var controllerMenuRoot: NSView? {
        guard let window else { return nil }
        return window.attachedSheet?.contentView ?? GameScreen.shared.controllerPage(in: window)
    }
    var controllerContext: ObjectIdentifier? { (controllerMenuRoot ?? window?.contentView).map(ObjectIdentifier.init) }
    var focusedControllerControl: NSControl? { menuNavigator.selected }
    func controllerMenuScroll(_ delta: Double) { if let root = controllerMenuRoot { menuNavigator.scroll(delta, in: root) } }
    func controllerMenuAction(_ action: ControllerBindings.Action) {
        if let root = controllerMenuRoot {
            if let overlay = root as? KeyboardOverlayView, action == .cancel || action == .pause { overlay.onClose(); return }
            menuNavigator.handle(action, in: root, sheet: window?.attachedSheet)
            return
        }
        menuNavigator.reset()
        switch action {
        case .assign: menuKey("\r")
        case .cancel, .pause: menuKey("\u{1b}")
        case .focusUnassigned(-1): menuKey("left")
        case .focusUnassigned: menuKey("right")
        case .rate(1): menuKey("up")
        case .rate: menuKey("down")
        case .retry: retry?()
        case .hints: if !openRetainedSolution() { hints?() }
        case .settings: settings?()
        case .djShuffle: break
        case .help: showHelp()
        default: break
        }
    }
    func controllerAction(_ action: ControllerBindings.Action) {
        switch action {
        case .assign: assignSelected()
        case .repeatAssignment: repeatAssignment()
        case .cancel:
            if speedControl?.isFast == true || speedControl?.state.isHeld == true { speedControl?.reset() }
            else { speedControl?.cancelInput(); escape() }
        case .pause:
            if speedControl?.isFast == true || speedControl?.state.isHeld == true { speedControl?.reset() }
            else { togglePause() }
        case .help: showHelp()
        case .hints: if !openRetainedSolution() { hints?() }
        case .settings: settings?()
        case .djShuffle: djShuffle?()
        case .retry: retry?()
        case .rewind: rewind?()
        case let .step(direction): step?(direction)
        case .endRun: endRun?()
        case .focusLast: focusLast()
        case let .focusUnassigned(direction): focusUnassigned(direction)
        case let .cycle(direction): cycle(direction)
        case let .rate(delta): rate?(delta)
        case let .centre(entrance): centre(entrance)
        case let .speedStep(direction): speedControl?.step(direction, at: ProcessInfo.processInfo.systemUptime)
        case .speedReset: speedControl?.reset()
        case .boost: break
        }
    }
    static func playCommands(pauseKey: String, retry: Bool, nuke: Bool) -> [KeyboardCommand] {
        let gameplay = L10n.text("Gameplay"), camera = L10n.text("Camera")
        var rows = [
            KeyboardCommand(keys: pauseKey, action: L10n.text("Pause / resume"), group: gameplay),
            KeyboardCommand(keys: "Hold , / <", action: L10n.text("Scrub backward"), group: gameplay),
            KeyboardCommand(keys: "Hold . / >", action: L10n.text("Scrub forward after rewind"), group: gameplay),
            KeyboardCommand(keys: ", / .", action: L10n.text("Step one tick; hold to scrub; release to pause"), group: gameplay),
            KeyboardCommand(keys: "Z", action: L10n.text("2× Zoom at cursor"), group: camera),
            KeyboardCommand(keys: L10n.text("Scroll up / down"), action: L10n.text("Zoom on / off at cursor"), group: camera),
            KeyboardCommand(keys: "Shift-Z", action: L10n.text("2× Superzoom at cursor, 0.5× time"), group: camera),
            KeyboardCommand(keys: "Z / Shift-Z", action: L10n.text("Press again to switch off"), group: camera),
            KeyboardCommand(keys: "Shift-Z", action: L10n.text("Each start spends one Superzoom use"), group: camera),
            KeyboardCommand(keys: "", action: L10n.text("Earn Superzoom per 3 no-Rewind three-star levels"), group: camera)
        ]
        if retry { rows.append(.init(keys: "R", action: L10n.text("Retry"), group: gameplay)) }
        if nuke { rows.append(.init(keys: "X", action: L10n.text("Nuke"), group: gameplay)) }
        return rows
    }

    var commandRows: [KeyboardCommand] {
        var rows: [KeyboardCommand] = []
        let names = skillNames()
        let shortcuts = SkillShortcuts(names: names)
        for index in names.indices {
            var keys = index < 10 ? [String((index + 1) % 10)] : []
            if modern() {
                if let letter = shortcuts.letters[index] { keys.append(letter.uppercased()) }
                if cyclesSharedSkillLetters, let initial = shortcuts.initials[index], shortcuts.initials.filter({ $0 == initial }).count > 1,
                   !keys.contains(initial.uppercased()) { keys.append(initial.uppercased()) }
            }
            let shared = modern() && cyclesSharedSkillLetters && shortcuts.initials[index].map { initial in shortcuts.initials.filter { $0 == initial }.count > 1 } == true
            let detail = shared ? L10n.text(" (\(shortcuts.initials[index]!.uppercased()) cycles matching skills)") : ""
            rows.append(KeyboardCommand(keys: keys.joined(separator: " / "), action: L10n.text("Select \(SkillVocabulary.title(names[index]))\(detail)"), group: L10n.text("Skills"), skillTitle: SkillVocabulary.title(names[index])))
        }
        rows += engineCommands()
        if inspectLemmings != nil {
            rows.append(.init(keys: "⌘I", action: L10n.text("Inspect lemmings while paused"), group: L10n.text("Gameplay")))
        }
        if extraSkill != nil, modern() {
            rows.append(.init(keys: "⌘E", action: L10n.text("Use Extra skill on the selected skill or tool carrier"), group: L10n.text("Skills")))
        }
        let gameplay = L10n.text("Gameplay"), speed = L10n.text("Speed"), camera = L10n.text("Camera"), skills = L10n.text("Skills")
        if modern() {
            rows += [
                .init(keys: "Tab / Shift-Tab", action: L10n.text("Next / previous available skill"), group: skills),
                .init(keys: "H / Home", action: L10n.text("Centre entrance"), group: camera),
                .init(keys: "[ / ]", action: L10n.text("Next / previous unassigned lemming"), group: skills),
                .init(keys: "\\", action: L10n.text("Focus last assignment"), group: skills),
                .init(keys: "Return", action: L10n.text("Repeat last skill"), group: skills)
            ]
            if selectGliderBeforeGoal == nil {
                rows.append(.init(keys: "G / End", action: L10n.text("Centre goal"), group: camera))
            } else {
                rows += [.init(keys: "G", action: L10n.text("Glider, then goal"), group: camera),
                         .init(keys: "End", action: L10n.text("Centre goal"), group: camera)]
            }
        }
        if let speedControl {
            rows.append(.init(keys: "F", action: L10n.text("Toggle fast-forward"), group: speed))
            if speedControl.variableEnabled {
                rows += [.init(keys: "Hold F", action: (speedControl.ridiculousEnabled ? L10n.text("Ramp up to 25×; release to keep speed") : L10n.text("Ramp up to 10×; release to keep speed")), group: speed),
                         .init(keys: "Hold Shift", action: L10n.text("Temporary boost; release to restore speed"), group: speed),
                         .init(keys: "Shift+[ / Shift+]", action: L10n.text("Decrease / increase speed"), group: speed),
                         .init(keys: "Shift + \\ (|)", action: L10n.text("Immediately return to normal speed (1×)"), group: speed)]
            }
        }
        rows += [.init(keys: "Escape / Q", action: L10n.text("Save run and return to library"), group: gameplay),
                 .init(keys: "?", action: L10n.text("Controls help"), group: gameplay)]
        if step != nil { rows.append(.init(keys: "⌘Z", action: L10n.text("Rewind one tick"), group: gameplay)) }
        if settings != nil { rows.append(.init(keys: "⌘,", action: L10n.text("Settings"), group: gameplay)) }
        if nextGraphics != nil { rows.append(.init(keys: "F2", action: L10n.text("Next graphics"), group: gameplay)) }
        if djShuffle != nil { rows.append(.init(keys: "J", action: L10n.text("DJ shuffle"), group: gameplay)) }
        if hints != nil { rows.append(.init(keys: "Slash / I / F1", action: L10n.text("Level goals and tiered hints"), group: gameplay)) }
        if rate != nil { rows.append(.init(keys: "− / +", action: L10n.text("Release rate"), group: gameplay)) }
        if rateLimit != nil { rows.append(.init(keys: L10n.text("Double-tap − / +"), action: L10n.text("Minimum / maximum release rate"), group: gameplay)) }
        if nukeToggle != nil { rows.append(.init(keys: "N", action: L10n.text("Nuke; press again to undo"), group: gameplay)) }
        if controllerEnabled() {
            rows += ControllerDevicePresentation.commands(mapping: controllerMappings(), variableSpeed: speedControl?.variableEnabled == true,
                tapSpeed: controllerTapSpeed(), rewind: rewind != nil, stepping: step != nil, hints: hints != nil)
        }
        if ArcadeStore.shared.hotSeatIsActive {
            rows.append(.init(keys: "⌘G", action: L10n.text("Show / hide Hot Seat ghosts"), group: L10n.text("Hot Seat")))
        }
        rows += contextCommands()
        func menuRows(_ menu: NSMenu) {
            for item in menu.items {
                if let child = item.submenu { menuRows(child) }
                guard !item.keyEquivalent.isEmpty else { continue }
                let flags = item.keyEquivalentModifierMask
                let modifiers = (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "") + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "")
                rows.append(KeyboardCommand(keys: modifiers + item.keyEquivalent.uppercased(), action: item.title, group: L10n.text("App menus")))
            }
        }
        if let menu = NSApp.mainMenu { menuRows(menu) }
        return rows
    }

    private(set) var overlay: KeyboardOverlayView?
    func showHelp() {
        guard active() else { showCommandList(); return }
        guard let window, window.attachedSheet == nil, overlay == nil else { return }
        let resume = pauseForHelp()
        speedControl?.cancelInput()
        let view = KeyboardOverlayView(commands: commandRows, modern: modern(), hints: hints != nil)
        overlay = view
        view.anchors = { [weak self, weak view] in
            guard let self, let view else { return [] }
            let names = self.skillNames()
            return self.overlayControls().compactMap { raw in
                guard let element = raw as? GameAccessibleElement, let owner = element.owner else { return nil }
                let label = element.accessibilityLabel() ?? ""
                let key: String
                if let index = names.firstIndex(where: { label == SkillVocabulary.title($0) || label.hasPrefix(SkillVocabulary.title($0) + ",") }), index < 10 { key = String((index + 1) % 10) }
                else if label == L10n.text("Pause") || label == L10n.text("Resume") { key = "Space" }
                else if label.hasPrefix(L10n.text("Start fast-forward at ")) || label == L10n.text("Return to normal speed") { key = "F" }
                else if label == L10n.text("Decrease release rate") { key = "−" }
                else if label == L10n.text("Increase release rate") { key = "+" }
                else { return nil }
                return (key, owner.convert(element.localFrame, to: view))
            }
        }
        view.onClose = { [weak view] in if let view { GameScreen.shared.dismiss(view) } }
        view.onCommands = { [weak self] in self?.showCommandList() }
        view.onHints = { [weak self, weak view] in
            if let view { GameScreen.shared.dismiss(view) }
            self?.hints?()
        }
        if !GameScreen.shared.present(view, owner: window, onDismiss: { [weak self] in self?.overlay = nil; resume() }) {
            overlay = nil; resume()
        }
    }

    private func showCommandList() {
        guard let window, window.attachedSheet == nil else { return }
        let resume = pauseForHelp()
        let alert = NSAlert()
        alert.messageText = L10n.text("Keyboard commands")
        alert.informativeText = L10n.text("Find a command by key, action or category. Your game pauses while this guide is open.")
        let guide = KeyboardCommandsView(commands: commandRows, modern: modern())
        alert.accessoryView = guide
        alert.addButton(withTitle: L10n.text("Close")).keyEquivalent = "\u{1b}"
        alert.window.initialFirstResponder = guide.search
        if hints != nil { alert.addButton(withTitle: L10n.text("Level hints")) }
        alert.beginSheetModal(for: window) { [weak self] response in
            resume()
            if response == .alertSecondButtonReturn {
                DispatchQueue.main.async { [weak self] in
                    if let overlay = self?.overlay { GameScreen.shared.dismiss(overlay) }
                    self?.hints?()
                }
            }
        }
    }
    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) }
        if let appFocusObserver { NotificationCenter.default.removeObserver(appFocusObserver) }
    }
}
#endif
