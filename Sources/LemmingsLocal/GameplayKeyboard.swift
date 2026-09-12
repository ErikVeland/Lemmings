import AppKit
import NxlvKit

@MainActor final class GameSpeedControl {
    private(set) var state: GameplaySpeed
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
    var isFast: Bool { state.isFast }
    var multiplier: Double { state.multiplier }
    var label: String { state.label }
    var target: Double { state.target }
    var panelLabel: String { state.label }
    var choiceLabel: String { "\(Int(state.cruise))×" }
    func pointerDown(at now: TimeInterval, clickCount: Int) {
        if clickCount > 1 { state.reset(at: now) }
        else { state.press(.mouse, at: now) }
        onChange()
    }
    func update(at now: TimeInterval, active: Bool) {
        if active { state.update(at: now) } else { state.suspend(at: now) }
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
        variableEnabled
            ? "F / Speed: toggle fast-forward\nHold Shift, Speed or RT: ramp up; release: previous speed\nSpeed arrows or Shift+[ / Shift+]: choose 2×, 3×, 5× or 10×\nF or controller B: immediately return to 1×"
            : "F / Speed: toggle fast-forward"
    }
}

/// Shared gameplay keys follow the active window, including an attached sequel.
@MainActor final class GameplayKeyboard {
    private var monitor: Any?
    private var focusObserver: NSObjectProtocol?
    private var appFocusObserver: NSObjectProtocol?
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
    var movePointer: (Double, Double) -> Void = { _, _ in }
    var panCamera: (Double, Double) -> Void = { _, _ in }
    var menuActive: () -> Bool = { false }
    var menuKey: (String) -> Void = { _ in }
    var cycle: (Int) -> Void = { _ in }
    var centre: (Bool) -> Void = { _ in }
    var rate: ((Int) -> Void)?
    var focusUnassigned: (Int) -> Void = { _ in }
    var focusLast: () -> Void = {}
    var repeatAssignment: () -> Void = {}
    var escape: () -> Void = {}
    var mainMenu: (() -> Void)?
    var help: () -> String = { "" }
    var skillNames: () -> [String] = { [] }
    var cyclesSharedSkillLetters = true
    var contextCommands: () -> [KeyboardCommand] = { [] }
    var hints: (() -> Void)?
    var settings: (() -> Void)?
    var retry: (() -> Void)?
    var rewind: (() -> Void)?
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
              window.attachedSheet == nil, !GameScreen.shared.isPresented, active(), !(window.firstResponder is NSTextView),
              event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
        if event.type == .flagsChanged {
            if modern(), event.modifierFlags.contains(.shift) { speedControl?.press(.shift, at: now) }
            return event
        }
        guard event.type == .keyDown else { return event }
        // F1 or i. The function key is easy to miss, and i is where a player
        // reaches for information.
        if event.keyCode == 122 || event.charactersIgnoringModifiers?.lowercased() == "i",
           let hints {
            if !event.isARepeat { hints() }
            return nil
        }
        let key = event.characters ?? ""
        if event.charactersIgnoringModifiers?.lowercased() == "f" {
            if !event.isARepeat {
                pressedF = true; fKeyCode = event.keyCode
                speedControl?.tap(at: now)
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
        if event.keyCode == 53 {
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
        if ["-", "−", "+", "="].contains(key), let rate { rate(key == "-" || key == "−" ? -1 : 1); return nil }
        return event
    }
    var controllerAvailable: Bool {
        controllerIsAvailable(applicationActive: NSApp.isActive)
    }
    func controllerIsAvailable(applicationActive: Bool) -> Bool {
        guard controllerEnabled(), ownsController(), applicationActive, let window,
              window.isKeyWindow || window.attachedSheet?.isKeyWindow == true else { return false }
        return active() || menuActive() || window.attachedSheet != nil || GameScreen.shared.controllerPage(in: window) != nil
    }
    var controllerPlaying: Bool { controllerAvailable && controllerMenuRoot == nil && active() }
    var controllerMenuRoot: NSView? {
        guard let window else { return nil }
        return window.attachedSheet?.contentView ?? GameScreen.shared.controllerPage(in: window)
    }
    var controllerContext: ObjectIdentifier? { (controllerMenuRoot ?? window?.contentView).map(ObjectIdentifier.init) }
    var focusedControllerControl: NSControl? { menuNavigator.selected }
    func controllerMenuScroll(_ delta: Double) { if let root = controllerMenuRoot { menuNavigator.scroll(delta, in: root) } }
    func controllerMenuAction(_ action: ControllerBindings.Action) {
        if let root = controllerMenuRoot {
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
        case .hints: hints?()
        case .settings: settings?()
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
        case .pause: togglePause()
        case .help: showHelp()
        case .hints: hints?()
        case .settings: settings?()
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
    var helpText: String {
        let speedHelp = (speedControl?.help ?? "").replacingOccurrences(of: " or RT", with: "").replacingOccurrences(of: "F or controller B", with: "F")
        var sections = [help(), speedHelp]
        if modern() {
            sections.append("Tab / Shift-Tab: next / previous available skill\nHome / End: entrance / exit\n[ / ]: previous / next unassigned lemming\n\\: focus last assignment\nReturn: repeat last skill")
        } else { sections.append("Modern keyboard shortcuts are off. Number keys select skills.") }
        sections.append("Escape: save run and return to main menu\n?: controls help")
        if hints != nil { sections.append("F1 or i: level goals and tiered hints") }
        if rate != nil { sections.append("− / +: release rate") }
        if controllerEnabled() {
            sections.append(ControllerDevicePresentation.help(mapping: controllerMappings(),
                variableSpeed: speedControl?.variableEnabled == true, tapSpeed: controllerTapSpeed(),
                rewind: rewind != nil, stepping: step != nil, hints: hints != nil))
        } else { sections.append("Controller support is off. Enable it in Settings > Controller.") }
        return sections.filter { !$0.isEmpty }.joined(separator: "\n\n")
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
            let detail = shared ? " (\(shortcuts.initials[index]!.uppercased()) cycles matching skills)" : ""
            rows.append(KeyboardCommand(keys: keys.joined(separator: " / "), action: "Select \(names[index])" + detail, group: "Skills"))
        }
        let controllerHeading = ControllerDevicePresentation.help(mapping: controllerMappings()).components(separatedBy: "\n").first
        var controllerSection = false
        for line in helpText.components(separatedBy: "\n") {
            if controllerEnabled(), line == controllerHeading { controllerSection = true; continue }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let keys = String(line[..<colon])
            let action = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            let lower = line.lowercased()
            let group = controllerSection ? "Controller"
                : ["speed", "fast-forward", "ramp", "1×"].contains(where: lower.contains) ? "Speed"
                : ["skill", "assignment", "unassigned"].contains(where: lower.contains) ? "Skills"
                : lower.contains("entrance") ? "Camera" : "Gameplay"
            rows.append(KeyboardCommand(keys: keys, action: action, group: group))
        }
        if speedControl?.variableEnabled == true {
            rows.append(KeyboardCommand(keys: "Shift + \\ (|)", action: "Immediately return to normal speed (1×)", group: "Speed"))
        }
        rows += contextCommands()
        func menuRows(_ menu: NSMenu) {
            for item in menu.items {
                if let child = item.submenu { menuRows(child) }
                guard !item.keyEquivalent.isEmpty else { continue }
                let flags = item.keyEquivalentModifierMask
                let modifiers = (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "") + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "")
                rows.append(KeyboardCommand(keys: modifiers + item.keyEquivalent.uppercased(), action: item.title, group: "App menus"))
            }
        }
        if let menu = NSApp.mainMenu { menuRows(menu) }
        return rows
    }

    func showHelp() {
        guard let window, window.attachedSheet == nil else { return }
        let resume = pauseForHelp()
        let alert = NSAlert()
        alert.messageText = "Keyboard commands"
        alert.informativeText = "Find a command by key, action or category. Your game pauses while this guide is open."
        let guide = KeyboardCommandsView(commands: commandRows, modern: modern())
        alert.accessoryView = guide
        alert.addButton(withTitle: "Close").keyEquivalent = "\u{1b}"
        alert.window.initialFirstResponder = guide.search
        if hints != nil { alert.addButton(withTitle: "Level hints") }
        alert.beginSheetModal(for: window) { [weak self] response in
            resume()
            if response == .alertSecondButtonReturn {
                DispatchQueue.main.async { [weak self] in self?.hints?() }
            }
        }
    }
    isolated deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) }
        if let appFocusObserver { NotificationCenter.default.removeObserver(appFocusObserver) }
    }
}
