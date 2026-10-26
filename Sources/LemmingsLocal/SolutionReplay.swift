#if os(macOS)
import AppKit
import CryptoKit
import LemmingsAppCore
import LemmingsAudio
import NxlvKit
import LemmingsGameArt

/// Playback owns its simulation and never calls the campaign, saves or result handlers.
@MainActor final class SolutionPlayback {
    let solution: VerifiedSolution
    private(set) var session: ClassicSession
    private let events: [Int: [ClassicDOSReplayEvent]]
    private(set) var lastAssignment: (id: Int, skill: ClassicSkill)?
    private(set) var skillUses: [ReplaySkillUse] = []

    init(_ solution: VerifiedSolution, width: Int, height: Int) {
        self.solution = solution
        var simulation = solution.initial
        for event in solution.replay.events where event.afterTick != true {
            if case let .assign(id, skill) = event.action {
                precondition(simulation.schedule(.init(tick: event.tick, lemmingID: id, skill: skill)))
            }
        }
        events = Dictionary(grouping: solution.replay.events, by: \.tick)
        session = ClassicSession(simulation: simulation, width: width, height: height)
        for event in events[0] ?? [] { apply(event.action) }
    }

    /// Moves the read-only replay to a nearby recorded tick.
    func seek(by delta: Int) {
        let target = max(0, min(solution.replay.expected?.ticks ?? 0, session.currentTick + delta))
        guard target != session.currentTick else { return }
        var simulation = solution.initial
        for event in solution.replay.events where event.afterTick != true {
            if case let .assign(id, skill) = event.action {
                precondition(simulation.schedule(.init(tick: event.tick, lemmingID: id, skill: skill)))
            }
        }
        session = ClassicSession(simulation: simulation, width: session.levelWidth, height: session.levelHeight)
        lastAssignment = nil; skillUses.removeAll(keepingCapacity: true)
        for event in events[0] ?? [] { apply(event.action) }
        for _ in 0..<target { tick() }
    }

    func tick() {
        guard !session.isComplete else { return }
        lastAssignment = nil
        let next = session.currentTick + 1
        for event in events[next] ?? [] where event.afterTick != true {
            if case .assign = event.action {} else { apply(event.action) }
        }
        session.tick()
        for event in session.simulation.lastTickEvents {
            if case let .skillAssigned(id, skill) = event { record(id: id, skill: skill) }
        }
        for event in events[next] ?? [] where event.afterTick == true { apply(event.action) }
    }

    private func record(id: Int, skill: ClassicSkill) {
        lastAssignment = (id, skill)
        skillUses.append(.init(tick: session.currentTick, name: skill.rawValue.capitalized))
    }

    private func apply(_ action: ClassicDOSReplayAction) {
        switch action {
        case let .assign(id, skill):
            if let index = ClassicSkill.allCases.firstIndex(of: skill), session.assign(skillIndex: index, to: id) == nil {
                record(id: id, skill: skill)
            }
        case let .releaseRate(value): session.adjustRate(by: value - session.rate)
        case let .bonusSkill(skill):
            if let index = ClassicSkill.allCases.firstIndex(of: skill) { session.grantExtraSkill(at: index) }
        case .nuke: session.nuke()
        }
    }
}

/// A read-only playfield fills the current game window. Controls never reach the live run.
@MainActor final class SolutionReplayWindow {
    let page = SolutionReplayPage()
    private(set) var playback: SolutionPlayback
    let field = PlayfieldView(frame: .zero)
    let speedControl = GameSpeedControl()
    let effects: SoundEffectPlayer?
    let selector = SolutionSwitchView(frame: .zero)
    var onReturnToGame: (() -> Void)?
    let moveNavigation: ReplayMoveNavigation
    var onSoundCues: (([PositionedSoundCue]) -> Void)?
    private let marker = SolutionMarker(frame: .zero)
    private let status = HintBitmapText()
    private let skillPanel = ReplaySkillPanel(frame: .zero)
    private var timer: Timer?
    private var monitor: Any?
    private(set) var paused = false
    private var hasPresented = false
    private var tickCredit = 0.0
    private var assignmentUntil = 0.0
    private var followedID: Int?
    private var lastAssignedID: Int?
    private var assignmentFocus = AssignmentFocus()
    private var automaticTracking = true
    private var zoomFactor = 1.0
    private var pressedF = false
    private var buttons: [GameActionButton] = []
    private let controlsScroll = NSScrollView()
    private let controlsDocument = GameMenuListDocument()
    private weak var transport: NSButton?
    private weak var speedButton: NSButton?
    private weak var trackingButton: NSButton?
    private weak var zoomButton: NSButton?
    private weak var previousMoveButton: NSButton?
    private weak var nextMoveButton: NSButton?

    init(solution: VerifiedSolution, source: PlayfieldView, width: Int, height: Int, effects: SoundEffectPlayer? = nil) {
        self.effects = effects?.replayPlayer()
        playback = SolutionPlayback(solution, width: width, height: height)
        moveNavigation = .classic(initial: solution.initial, replay: solution.replay)
        field.classicScene = source.classicScene; field.macScene = source.macScene
        field.macArtwork = source.macArtwork; field.assets = source.assets; field.palette = source.palette
        field.levelImage = source.levelImage; field.imageScale = source.imageScale
        field.presentsHDR = false; field.session = playback.session
        field.viewport = source.viewport
        field.viewport.levelSize = CGSize(width: width, height: height)
        marker.field = field
        page.setAccessibilityLabel(L10n.text("Solution replay: \(solution.replay.title)"))
        page.addSubview(field); page.addSubview(marker); page.addSubview(status); page.addSubview(skillPanel)
        selector.mode = .solution
        selector.onSelect = { [weak self] mode in if mode == .game { self?.close() } }
        page.addSubview(selector)
        page.onReturnToGame = { [weak self] in self?.close() }
        func button(_ title: String, _ help: String, primary: Bool = false, speed: Bool = false, action: @escaping () -> Void) -> GameActionButton {
            let value: GameActionButton = speed
                ? SolutionSpeedButton(title: title, primary: primary, onPress: action)
                : GameActionButton(title: title, primary: primary, onPress: action)
            (value as? SolutionSpeedButton)?.speed = speedControl
            value.setAccessibilityLabel(help); value.toolTip = help
            page.addSubview(value); buttons.append(value); return value
        }
        page.navigationBackButton = button(L10n.text("Back to game"), L10n.text("Back to your paused game. Escape.")) { [weak self] in self?.close() }
        previousMoveButton = button(L10n.text("Previous move"), L10n.text("Previous successful skill use. Control-Left.")) { [weak self] in self?.seekMove(-1) }
        nextMoveButton = button(L10n.text("Next move"), L10n.text("Next successful skill use. Control-Right.")) { [weak self] in self?.seekMove(1) }
        _ = button(L10n.text("Back 1s"), L10n.text("Rewind one second.")) { [weak self] in self?.seek(-ClassicDOSRules.ticksPerSecond) }
        _ = button(L10n.text("Step +1"), L10n.text("Advance one tick.")) { [weak self] in self?.seek(1) }
        transport = button(L10n.text("Pause"), L10n.text("Play or pause. Space or P."), primary: true) { [weak self] in self?.togglePause() }
        _ = button(L10n.text("Speed -"), L10n.text("Slower. Shift+[.")) { [weak self] in self?.speedControl.step(-1, at: ProcessInfo.processInfo.systemUptime) }
        speedButton = button("1×", L10n.text("Toggle fast forward. Hold F to ramp speed. Hold Shift for a temporary boost."), speed: true) { [weak self] in self?.speedControl.tap() }
        _ = button(L10n.text("Speed +"), L10n.text("Faster. Shift+].")) { [weak self] in self?.speedControl.step(1, at: ProcessInfo.processInfo.systemUptime) }
        _ = button(L10n.text("Entrance"), L10n.text("Centre entrance. H or Home.")) { [weak self] in self?.centre(entrance: true) }
        _ = button(L10n.text("Goal"), L10n.text("Centre exit. G or End.")) { [weak self] in self?.centre(entrance: false) }
        _ = button(L10n.text("Previous lemming"), L10n.text("Track previous unassigned lemming. [.")) { [weak self] in self?.focusUnassigned(-1) }
        _ = button(L10n.text("Next lemming"), L10n.text("Track next unassigned lemming. ].")) { [weak self] in self?.focusUnassigned(1) }
        _ = button(L10n.text("Last skill"), L10n.text("Track last assignment. Backslash.")) { [weak self] in
            guard let self else { return }; self.follow(self.lastAssignedID)
        }
        trackingButton = button(L10n.text("Follow: on"), L10n.text("Follow skill assignments automatically. Drag or scroll to use a free camera.")) { [weak self] in
            guard let self else { return }
            self.automaticTracking.toggle(); self.followedID = nil; self.refresh()
        }
        zoomButton = button(L10n.text("Zoom 1×"), L10n.text("Zoom. Z: 2×. Shift+Z: 4×. Click to cycle.")) { [weak self] in
            guard let self else { return }; self.setZoom(self.zoomFactor == 1 ? 2 : self.zoomFactor == 2 ? 4 : 1)
        }
        controlsScroll.drawsBackground = false
        controlsScroll.hasVerticalScroller = true
        controlsScroll.autohidesScrollers = true
        controlsScroll.scrollerStyle = .overlay
        controlsScroll.verticalScrollElasticity = .none
        controlsScroll.documentView = controlsDocument
        page.addSubview(controlsScroll)
        for (index, button) in buttons.enumerated() where index != 0 && button !== transport {
            button.wrapsTitle = true
            controlsDocument.addSubview(button)
        }
        speedControl.onChange = { [weak self] in self?.refresh() }
        page.onLayout = { [weak self] in self?.layout() }
        page.onKey = { [weak self] in self?.handleKey($0) ?? false }
        marker.onPan = { [weak self] dx, dy in self?.pan(dx, dy) }
        marker.onPick = { [weak self] point in
            guard let self else { return }
            let level = self.field.viewport.levelPoint(from: point)
            let nearest = self.playback.session.lemmings.min {
                hypot(Double($0.x) - level.x, Double($0.y) - level.y) < hypot(Double($1.x) - level.x, Double($1.y) - level.y)
            }
            if let nearest, hypot(Double(nearest.x) - level.x, Double(nearest.y) - level.y) < 20 { self.follow(nearest.id) }
        }
        refresh()
    }

    private func layout() {
        let size = page.bounds.size
        let scale = max(1, min(2, size.width / 1120, size.height / 720))
        let gap = 6.0 * scale, margin = 8.0 * scale
        let rowHeight = 44.0 * scale
        let controlsHeight = min(220 * scale, size.height * 0.34)
        selector.frame = CGRect(x: max(margin, (size.width - 320 * scale) / 2), y: 8 * scale, width: 320 * scale, height: 48 * scale)
        selector.bounds.size = SolutionSwitchArt.size
        field.frame = CGRect(x: 0, y: 90 * scale, width: size.width,
            height: max(1, size.height - 90 * scale - controlsHeight - rowHeight - 4 * gap))
        marker.frame = field.frame
        layoutSkillPanel(scale: scale)
        status.frame = CGRect(x: margin, y: 60 * scale, width: size.width - 2 * margin, height: 26 * scale)
        status.bounds.size = CGSize(width: status.frame.width / scale, height: 26)
        controlsScroll.frame = CGRect(x: margin, y: field.frame.maxY + gap, width: size.width - 2 * margin, height: controlsHeight)
        let tools = buttons.enumerated().filter { $0.element.superview === controlsDocument }
        let toolsWidth = controlsScroll.contentSize.width / scale
        let toolsGrid = GameListGrid(actions: tools.map { .init(String($0.offset), $0.element.title) }, width: toolsWidth - 24,
            maximumColumns: 4, minimumColumnWidth: 180, minimumHeight: 44, captionInset: 24,
            rowHeadings: ["1": L10n.text("Replay"), "6": L10n.text("Speed"), "9": L10n.text("Camera")],
            font: GameMenuArtwork.renderer()?.font(.small))
        let contentHeight = max(controlsHeight / scale, toolsGrid.height + 24)
        controlsDocument.frame = CGRect(x: 0, y: 0, width: toolsWidth * scale, height: contentHeight * scale)
        controlsDocument.bounds = CGRect(x: 0, y: 0, width: toolsWidth, height: contentHeight)
        controlsDocument.headings = toolsGrid.headings.map { ($0.0, $0.1.offsetBy(dx: 12, dy: 12)) }
        for target in toolsGrid.targets { buttons[Int(target.action.id)!].frame = target.frame.offsetBy(dx: 12, dy: 12) }
        let actions = buttons.enumerated().filter { $0.element.superview === page }.map {
            GameFrontEnd.Action(String($0.offset), $0.element.title, primary: $0.element === transport, backNavigation: $0.offset == 0)
        }
        let grid = GameFooterGrid(actions: actions, columns: 2)
        for slot in grid.slots {
            let button = buttons[Int(slot.action.id)!]
            button.frame = grid.frame(for: slot, x: margin, y: size.height - rowHeight - gap,
                width: size.width - 2 * margin, height: rowHeight, gap: gap, rowGap: gap)
            button.bounds.size = CGSize(width: button.frame.width / scale, height: rowHeight / scale)
        }
        let center = field.viewport.levelPoint(from: CGPoint(x: field.bounds.midX, y: field.bounds.midY))
        field.viewport.viewSize = field.bounds.size
        field.viewport.zoom = max(1, field.bounds.height / Double(playback.session.levelHeight)) * zoomFactor
        centerCamera(center)
    }

    func show(owner: NSWindow) {
        suspend()
        guard GameScreen.shared.present(page, owner: owner, focus: page, onDismiss: { [weak self] in self?.stop() }) else { return }
        try? effects?.start()
        if !hasPresented { centre(entrance: true); automaticTracking = true; hasPresented = true }
        refresh()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self, weak owner] event in
            guard let self, event.window === owner, owner?.isKeyWindow == true,
                  GameScreen.shared.controllerPage(in: owner!) === self.page else { return event }
            return self.handleKey(event) ? nil : event
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1 / Double(ClassicDOSRules.ticksPerSecond), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advance() }
        }
    }

    func stop() {
        suspend()
        effects?.stop()
        timer?.invalidate(); timer = nil
        if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil
        speedControl.cancelInput(); pressedF = false
    }
    func suspend() {
        paused = true; tickCredit = 0
        speedControl.cancelInput(); pressedF = false
        effects?.silence()
        refresh()
    }
    private func close() {
        suspend()
        if let onReturnToGame { onReturnToGame() } else { GameScreen.shared.dismiss(page) }
    }
    func seekMove(_ direction: Int) {
        guard let tick = moveNavigation.target(from: playback.session.currentTick, direction: direction) else { return }
        seek(tick - playback.session.currentTick)
    }
    private func togglePause() {
        if playback.session.isComplete {
            playback = SolutionPlayback(playback.solution, width: playback.session.levelWidth, height: playback.session.levelHeight)
            assignmentFocus = AssignmentFocus(); lastAssignedID = nil; followedID = nil
            assignmentUntil = 0; paused = false; tickCredit = 0
            centre(entrance: true); automaticTracking = true
        } else { paused.toggle() }
        if paused { effects?.silence() }
        refresh()
    }
    private func seek(_ delta: Int) {
        paused = true; tickCredit = 0
        effects?.silence()
        let previousTick = playback.session.currentTick
        playback.seek(by: delta)
        assignmentFocus = AssignmentFocus(); lastAssignedID = nil
        for event in playback.solution.replay.events where event.tick <= playback.session.currentTick {
            if case let .assign(id, skill) = event.action {
                assignmentFocus.record(id: id, skill: ClassicSkill.allCases.firstIndex(of: skill) ?? 0, tick: event.tick)
                lastAssignedID = id
            }
        }
        marker.point = nil; assignmentUntil = 0
        if automaticTracking { followedID = lastAssignedID }
        updateTracking(); refresh()
        if delta == 1, playback.session.currentTick == previousTick + 1 { playTickSounds() }
    }
    private func playTickSounds() {
        let cues = playback.session.lastPositionedCues
        effects?.setViewport(field.soundViewport)
        effects?.play(cues)
        onSoundCues?(cues)
    }
    func advance() {
        let visible = !page.isHiddenOrHasHiddenAncestor && (page.window == nil || GameScreen.shared.controllerPage(in: page.window!) === page)
        if page.window?.isKeyWindow == false { speedControl.cancelInput(); pressedF = false }
        speedControl.update(at: ProcessInfo.processInfo.systemUptime, active: visible)
        guard visible, !paused, !playback.session.isComplete else {
            if !visible { effects?.silence() }
            return
        }
        tickCredit += speedControl.multiplier
        while tickCredit >= 1, !playback.session.isComplete {
            tickCredit -= 1; playback.tick()
            if let assignment = playback.lastAssignment,
               let lemming = playback.session.lemmings.first(where: { $0.id == assignment.id }) {
                lastAssignedID = lemming.id
                assignmentFocus.record(id: lemming.id, skill: ClassicSkill.allCases.firstIndex(of: assignment.skill) ?? 0, tick: playback.session.currentTick)
                if automaticTracking { followedID = lemming.id }
                marker.point = CGPoint(x: lemming.x, y: lemming.y)
                assignmentUntil = ProcessInfo.processInfo.systemUptime + 1.5
            }
            updateTracking(); playTickSounds()
        }
        updateTracking(); refresh()
    }
    private func updateTracking() {
        let lemmings = playback.session.lemmings
        if let lemming = lemmings.first(where: { $0.id == followedID }) ?? (automaticTracking ? lemmings.first : nil) {
            centerCamera(CGPoint(x: lemming.x, y: lemming.y))
        }
    }
    private func centerCamera(_ point: CGPoint) {
        field.viewport.scrollX = point.x - field.viewport.visibleSize.width / 2
        field.viewport.scrollY = point.y - field.viewport.visibleSize.height / 2
        field.viewport.clamp(); field.needsDisplay = true; marker.needsDisplay = true
    }
    private func centre(entrance: Bool) {
        let session = playback.session
        if let x = entrance ? session.entranceX : session.exitX {
            automaticTracking = false; followedID = nil
            centerCamera(CGPoint(x: x, y: (entrance ? session.entranceY : session.exitY) ?? session.levelHeight / 2))
        }
        refresh()
    }
    private func follow(_ id: Int?) {
        guard let id else { return }; automaticTracking = false; followedID = id; updateTracking(); refresh()
    }
    private func focusUnassigned(_ direction: Int) {
        follow(assignmentFocus.next(activeIDs: playback.session.lemmings.map(\.id), direction: direction))
    }
    private func pan(_ dx: Double, _ dy: Double) {
        automaticTracking = false; followedID = nil
        field.viewport.scroll(dx: dx / field.viewport.zoom, dy: dy / field.viewport.zoom); refresh()
    }
    private func setZoom(_ factor: Double) { zoomFactor = factor; layout(); updateTracking(); refresh() }

    @discardableResult func handleKey(_ event: NSEvent) -> Bool {
        if event.type == .keyDown, event.modifierFlags.intersection([.command, .control, .option, .shift]) == .control {
            if event.keyCode == 123 || event.keyCode == 124 {
                if !event.isARepeat { seekMove(event.keyCode == 123 ? -1 : 1) }
                return true
            }
        }
        if event.type == .keyUp, event.keyCode == 3, pressedF {
            pressedF = false; speedControl.release(.key, at: event.timestamp); return true
        }
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
            speedControl.cancelInput(); pressedF = false; return false
        }
        if event.type == .flagsChanged {
            if event.modifierFlags.contains(.shift) { speedControl.press(.shift, at: event.timestamp) }
            else { speedControl.release(.shift, at: event.timestamp) }
            return false
        }
        guard event.type == .keyDown else { return false }
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        if [123, 124, 125, 126].contains(event.keyCode), page.window?.firstResponder === page {
            pan(event.keyCode == 123 ? -32 : event.keyCode == 124 ? 32 : 0,
                event.keyCode == 126 ? -32 : event.keyCode == 125 ? 32 : 0); return true
        }
        guard !event.isARepeat else { return ["f", "p", " ", "z", "h", "g", "[", "]", "\\"].contains(key) }
        if key == "f" { pressedF = true; speedControl.press(.key, at: event.timestamp); return true }
        if key == "p" || event.keyCode == 49 { togglePause(); return true }
        if key == "z" {
            if event.modifierFlags.contains(.shift) { speedControl.release(.shift, at: event.timestamp, allowTap: false) }
            let factor = event.modifierFlags.contains(.shift) ? 4.0 : 2.0; setZoom(zoomFactor == factor ? 1 : factor); return true }
        if key == "h" || event.keyCode == 115 { centre(entrance: true); return true }
        if key == "g" || event.keyCode == 119 { centre(entrance: false); return true }
        if event.characters == "{" || event.characters == "}" {
            speedControl.release(.shift, at: event.timestamp, allowTap: false)
            speedControl.step(event.characters == "{" ? -1 : 1, at: event.timestamp); return true
        }
        if event.characters == "|" { speedControl.reset(); return true }
        if key == "[" || key == "]" { focusUnassigned(key == "[" ? -1 : 1); return true }
        if key == "\\" { follow(lastAssignedID); return true }
        if event.keyCode == 53 { close(); return true }
        return false
    }
    private func layoutSkillPanel(scale: CGFloat) {
        let logical = skillPanel.logicalSize
        skillPanel.frame = CGRect(x: max(8, page.bounds.width - logical.width * scale - 8 * scale),
            y: field.frame.minY + 8 * scale, width: logical.width * scale, height: logical.height * scale)
        skillPanel.bounds.size = logical
    }
    private func refresh() {
        skillPanel.update(stocks: ReplaySkillPresentation.stocks(.classic(playback.session.simulation)),
            uses: playback.skillUses, tick: playback.session.currentTick)
        layoutSkillPanel(scale: max(1, min(2, page.bounds.width / 1120, page.bounds.height / 720)))
        effects?.setViewport(field.soundViewport)
        field.session = playback.session
        if playback.session.isComplete {
            status.stringValue = L10n.text("\(playback.session.simulation.savedCount) rescued"); marker.point = nil
        } else {
            status.stringValue = "\(playback.solution.replay.title)   \(playback.session.currentTick) / \(playback.solution.replay.expected?.ticks ?? 0)"
            if ProcessInfo.processInfo.systemUptime > assignmentUntil { marker.point = nil }
        }
        transport?.title = playback.session.isComplete ? L10n.text("Replay") : paused ? L10n.text("Play") : L10n.text("Pause")
        previousMoveButton?.isEnabled = moveNavigation.target(from: playback.session.currentTick, direction: -1) != nil
        nextMoveButton?.isEnabled = moveNavigation.target(from: playback.session.currentTick, direction: 1) != nil
        speedButton?.title = speedControl.label
        trackingButton?.title = automaticTracking ? L10n.text("Follow: on") : followedID != nil ? L10n.text("Tracking") : L10n.text("Free view")
        zoomButton?.title = L10n.text("Zoom \(Int(zoomFactor))×")
        buttons.forEach { $0.needsDisplay = true }
        field.needsDisplay = true; marker.needsDisplay = true
    }
}

@MainActor final class SolutionReplayPage: NSView, GameFullWindowPage {
    var navigationBackButton: GameActionButton?
    var onReturnToGame: (() -> Void)?
    var onLayout: (() -> Void)?
    var onKey: ((NSEvent) -> Bool)?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func layout() { super.layout(); onLayout?() }
    override func draw(_ dirtyRect: NSRect) { NSColor.black.setFill(); bounds.fill() }
    override func cancelOperation(_ sender: Any?) {
        if let onReturnToGame { onReturnToGame() } else { GameScreen.shared.dismiss(self) }
    }
    override func keyDown(with event: NSEvent) { if onKey?(event) != true { super.keyDown(with: event) } }
}

@MainActor private final class SolutionMarker: NSView {
    weak var field: PlayfieldView?
    var point: CGPoint?
    var onPan: ((Double, Double) -> Void)?
    var onPick: ((CGPoint) -> Void)?
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { self }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(superview)
        onPick?(convert(event.locationInWindow, from: nil))
    }
    override func mouseDragged(with event: NSEvent) { onPan?(-event.deltaX, -event.deltaY) }
    override func scrollWheel(with event: NSEvent) { onPan?(-event.scrollingDeltaX, -event.scrollingDeltaY) }
    override func draw(_ dirtyRect: NSRect) {
        guard let field, let point else { return }
        let center = field.viewport.viewPoint(fromLevel: point)
        NSColor.green.setStroke()
        let path = NSBezierPath(rect: CGRect(x: center.x - 12, y: center.y - 18, width: 24, height: 30))
        path.lineWidth = 2; path.stroke()
    }
}

@MainActor private final class SolutionSpeedButton: GameActionButton {
    weak var speed: GameSpeedControl?
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self); highlight(true)
        speed?.pointerDown(at: event.timestamp, clickCount: event.clickCount)
    }
    override func mouseDragged(with event: NSEvent) { highlight(bounds.contains(convert(event.locationInWindow, from: nil))) }
    override func mouseUp(with event: NSEvent) {
        speed?.release(.mouse, at: event.timestamp, allowTap: bounds.contains(convert(event.locationInWindow, from: nil)))
        highlight(false)
    }
}
#endif
