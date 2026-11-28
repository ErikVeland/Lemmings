#if os(macOS)
import AppKit
import CryptoKit
import LemmingsAppCore
import LemmingsAudio
import NxlvKit
import LemmingsGameArt
import LemmingsMobileCore

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

    /// Moves the read-only replay to a recorded tick.
    func seek(by delta: Int) {
        let target = max(0, min(solution.replay.expected?.ticks ?? 0, session.currentTick + delta))
        guard target != session.currentTick else { return }
        if target > session.currentTick {
            while session.currentTick < target, !session.isComplete { tick() }
            return
        }
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
@MainActor final class SolutionReplayWindow: NSObject {
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
    private var clock = MobileTickClock(ticksPerSecond: Double(ClassicDOSRules.ticksPerSecond), maximumCatchUpTicks: 24)
    private var assignmentUntil = 0.0
    private var followedID: Int?
    private var lastAssignedID: Int?
    private var assignmentFocus = AssignmentFocus()
    private var automaticTracking = true
    private var zoomFactor = 1.0
    private var pressedF = false
    private let timeline = GameSlider()
    private let elapsed = GameLabel(labelWithString: "")
    private let end = GameLabel(labelWithString: "")
    private let transport = SolutionTransportButton(title: L10n.text("Play"), glyph: .play, primary: true)
    private let speedButton = GameActionButton(title: "1×", primary: false)
    private let optionsButton = GameActionButton(title: L10n.text("Options"), primary: false)
    private let previousMoveButton = SolutionTransportButton(title: L10n.text("Previous move"), glyph: .stepBackward)
    private let nextMoveButton = SolutionTransportButton(title: L10n.text("Next move"), glyph: .stepForward)
    private var endTick: Int { playback.solution.replay.expected?.ticks ?? 0 }

    init(solution: VerifiedSolution, source: PlayfieldView, width: Int, height: Int, effects: SoundEffectPlayer? = nil) {
        self.effects = effects?.replayPlayer()
        playback = SolutionPlayback(solution, width: width, height: height)
        moveNavigation = .classic(initial: solution.initial, replay: solution.replay)
        super.init()
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
        page.hasOwnNavigation = true
        skillPanel.fitsContents = true
        previousMoveButton.toolTip = L10n.text("Previous successful skill use. Control-Left.")
        nextMoveButton.toolTip = L10n.text("Next successful skill use. Control-Right.")
        transport.toolTip = L10n.text("Play or pause. Space or P.")
        speedButton.toolTip = L10n.text("Playback speed. Hold F to ramp speed. Hold Shift for a temporary boost.")
        optionsButton.toolTip = L10n.text("Camera and replay controls")
        previousMoveButton.onPress = { [weak self] in self?.seekMove(-1) }
        nextMoveButton.onPress = { [weak self] in self?.seekMove(1) }
        transport.onPress = { [weak self] in self?.togglePause() }
        speedButton.onPress = { [weak self] in self?.showSpeedChoices() }
        optionsButton.onPress = { [weak self] in self?.showOptions() }
        for button in [previousMoveButton, transport, nextMoveButton, speedButton, optionsButton] {
            button.setAccessibilityHelp(button.toolTip)
            page.addSubview(button)
        }
        timeline.minValue = 0
        timeline.maxValue = Double(endTick)
        timeline.isContinuous = false
        timeline.target = self
        timeline.action = #selector(seekTimeline)
        timeline.setAccessibilityLabel(L10n.text("Replay position"))
        (timeline.cell as? GameSliderCell)?.trackMarks = moveNavigation.ticks.map { Double($0) / Double(max(1, endTick)) }
        page.addSubview(timeline)
        page.addSubview(elapsed)
        page.addSubview(end)
        end.alignment = .right
        elapsed.setAccessibilityElement(false)
        end.setAccessibilityElement(false)
        end.stringValue = ReplayGameTime.clock(tick: endTick, rate: Double(ClassicDOSRules.ticksPerSecond))
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
        let width = size.width / scale
        let gap: CGFloat = 6
        let margin: CGFloat = 8
        let buttonHeight: CGFloat = 44
        let switchWidth = min(SolutionSwitchArt.size.width, max(1, width - 2 * margin))
        let narrowHeader = width < 620
        let headerHeight: CGFloat = narrowHeader ? 88 : 60
        let compact = width < 560
        let barHeight: CGFloat = compact ? 116 : 68
        func place(_ view: NSView, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
            view.frame = CGRect(x: floor(x * scale), y: floor(y * scale), width: w * scale, height: h * scale)
            view.bounds.size = CGSize(width: w, height: h)
        }

        place(selector, x: narrowHeader ? (width - switchWidth) / 2 : width - margin - switchWidth,
            y: margin, w: switchWidth, h: 48)
        place(status, x: margin, y: narrowHeader ? 58 : 18,
            w: max(1, width - 2 * margin - (narrowHeader ? 0 : switchWidth + gap)), h: 26)
        field.frame = CGRect(x: 0, y: headerHeight * scale, width: size.width,
            height: max(1, size.height - (headerHeight + barHeight) * scale))
        marker.frame = field.frame
        layoutSkillPanel(scale: scale)

        let barWidth = min(1000, max(1, width - 2 * margin))
        let left = (width - barWidth) / 2
        let top = size.height / scale - barHeight
        let buttonY = top + (compact ? 64 : 12)
        let toolWidth = min(124, barWidth * 0.28)
        let speedWidth: CGFloat = 64
        let moveWidth: CGFloat = 44
        let playWidth: CGFloat = 54
        let transportWidth = 2 * moveWidth + playWidth + 2 * gap
        let toolsWidth = toolWidth + speedWidth + gap
        let buttonLeft = compact ? max(left, (width - transportWidth - gap - toolsWidth) / 2) : left
        let right = compact ? buttonLeft + transportWidth + gap + toolsWidth : left + barWidth
        place(previousMoveButton, x: buttonLeft, y: buttonY, w: moveWidth, h: buttonHeight)
        place(transport, x: buttonLeft + moveWidth + gap, y: buttonY, w: playWidth, h: buttonHeight)
        place(nextMoveButton, x: buttonLeft + moveWidth + playWidth + 2 * gap, y: buttonY, w: moveWidth, h: buttonHeight)
        place(speedButton, x: right - toolsWidth, y: buttonY, w: speedWidth, h: buttonHeight)
        place(optionsButton, x: right - toolWidth, y: buttonY, w: toolWidth, h: buttonHeight)

        let trackLeft = compact ? left : buttonLeft + transportWidth + 2 * gap
        let trackRight = compact ? left + barWidth : right - toolsWidth - 2 * gap
        let trackWidth = max(1, trackRight - trackLeft)
        place(timeline, x: trackLeft, y: top, w: trackWidth, h: 44)
        let textWidth = max(1, min(112, trackWidth / 2))
        place(elapsed, x: trackLeft + 4, y: top + 44, w: textWidth, h: 18)
        place(end, x: trackRight - textWidth - 4, y: top + 44, w: textWidth, h: 18)
        let center = field.viewport.levelPoint(from: CGPoint(x: field.bounds.midX, y: field.bounds.midY))
        field.viewport.viewSize = field.bounds.size
        field.viewport.zoom = max(1, field.bounds.height / Double(playback.session.levelHeight)) * zoomFactor
        centerCamera(center)
    }

    @objc private func seekTimeline() {
        seek(Int(timeline.doubleValue.rounded()) - playback.session.currentTick)
    }

    private func showSpeedChoices() {
        let menu = GameMenuPage(title: L10n.text("Playback speed"))
        for (index, value) in speedControl.state.selectableSteps.enumerated() {
            let choice = menu.addListAction("\(Int(value))×", at: index) { [weak self, weak menu] in
                guard let self, let menu else { return }
                self.speedControl.select(value, at: ProcessInfo.processInfo.systemUptime)
                GameScreen.shared.dismiss(menu)
            }
            if value == speedControl.state.selected { menu.preferControllerControl(choice) }
        }
        GameScreen.shared.present(menu, owner: page.window)
    }

    private func showOptions() {
        let menu = GameMenuPage(title: L10n.text("Options"))
        let camera = L10n.text("Camera")
        let options: [(String, String?, (SolutionReplayWindow) -> Void)] = [
            (L10n.text("Back 1s"), L10n.text("Playback"), { $0.seek(-ClassicDOSRules.ticksPerSecond) }),
            (L10n.text("Step forward"), nil, { $0.seek(1, audibleStep: true) }),
            (L10n.text("Zoom \(Int(zoomFactor))×"), camera, { $0.setZoom($0.zoomFactor == 1 ? 2 : $0.zoomFactor == 2 ? 4 : 1) }),
            (L10n.text("Entrance"), nil, { $0.centre(entrance: true) }),
            (L10n.text("Goal"), nil, { $0.centre(entrance: false) }),
            (L10n.text("Previous lemming"), nil, { $0.focusUnassigned(-1) }),
            (L10n.text("Next lemming"), nil, { $0.focusUnassigned(1) }),
            (L10n.text("Last skill"), nil, { $0.follow($0.lastAssignedID) }),
            (automaticTracking ? L10n.text("Turn off auto-follow") : L10n.text("Turn on auto-follow"), nil, {
                $0.automaticTracking.toggle()
                $0.followedID = nil
                $0.updateTracking()
                $0.refresh()
            }),
        ]
        for (index, option) in options.enumerated() {
            menu.addListAction(option.0, at: index, section: option.1) { [weak self, weak menu] in
                guard let self, let menu else { return }
                GameScreen.shared.dismiss(menu)
                option.2(self)
            }
        }
        GameScreen.shared.present(menu, owner: page.window)
    }

    func show(owner: NSWindow) {
        suspend()
        guard GameScreen.shared.present(page, owner: owner, focus: transport, onDismiss: { [weak self] in self?.stop() }) else { return }
        try? effects?.start()
        if !hasPresented { centre(entrance: true); automaticTracking = true; hasPresented = true }
        refresh()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self, weak owner] event in
            guard let self, event.window === owner, owner?.isKeyWindow == true,
                  GameScreen.shared.controllerPage(in: owner!) === self.page else { return event }
            return self.handleKey(event) ? nil : event
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
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
        paused = true; clock.suspend()
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
        clock.suspend()
        if playback.session.isComplete {
            playback = SolutionPlayback(playback.solution, width: playback.session.levelWidth, height: playback.session.levelHeight)
            assignmentFocus = AssignmentFocus(); lastAssignedID = nil; followedID = nil
            assignmentUntil = 0; paused = false
            centre(entrance: true); automaticTracking = true
        } else { paused.toggle() }
        if paused { effects?.silence() }
        refresh()
    }
    private func seek(_ delta: Int, audibleStep: Bool = false) {
        paused = true; clock.suspend()
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
        if audibleStep, playback.session.currentTick == previousTick + 1 { playTickSounds() }
    }
    private func playTickSounds() {
        let cues = playback.session.lastPositionedCues
        effects?.setViewport(field.soundViewport)
        effects?.play(cues)
        onSoundCues?(cues)
    }
    func advance(at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        let visible = !page.isHiddenOrHasHiddenAncestor && (page.window == nil || GameScreen.shared.controllerPage(in: page.window!) === page)
        if page.window?.isKeyWindow == false { speedControl.cancelInput(); pressedF = false }
        let priorTarget = speedControl.target
        speedControl.update(at: now, active: visible)
        guard visible, !paused, !playback.session.isComplete else {
            clock.suspend()
            if !visible { effects?.silence() }
            if speedControl.target != priorTarget { refresh() }
            return
        }
        clock.speed = speedControl.multiplier
        let ticks = clock.advance(at: now)
        guard ticks > 0 else {
            speedControl.observeThroughput(elapsed: clock.lastAdvanceElapsed, ticks: 0,
                ticksPerSecond: clock.ticksPerSecond)
            if speedControl.target != priorTarget { refresh() }
            return
        }
        let deadline = ProcessInfo.processInfo.systemUptime + speedControl.simulationBudget
        var advanced = 0
        while advanced < ticks, !playback.session.isComplete {
            playback.tick(); advanced += 1
            if let assignment = playback.lastAssignment,
               let lemming = playback.session.lemmings.first(where: { $0.id == assignment.id }) {
                lastAssignedID = lemming.id
                assignmentFocus.record(id: lemming.id, skill: ClassicSkill.allCases.firstIndex(of: assignment.skill) ?? 0, tick: playback.session.currentTick)
                if automaticTracking { followedID = lemming.id }
                marker.point = CGPoint(x: lemming.x, y: lemming.y)
                assignmentUntil = ProcessInfo.processInfo.systemUptime + 1.5
            }
            playTickSounds()
            if ProcessInfo.processInfo.systemUptime >= deadline { break }
        }
        if !playback.session.isComplete {
            clock.deferTicks(ticks - advanced)
            speedControl.observeThroughput(elapsed: clock.lastAdvanceElapsed, ticks: advanced,
                ticksPerSecond: clock.ticksPerSecond)
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
        let lemmings = playback.session.lemmings
        follow(assignmentFocus.next(
            activeIDs: lemmings.map(\.id),
            facingLeftIDs: Set(lemmings.filter(\.facingLeft).map(\.id)),
            direction: direction))
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
        guard !event.isARepeat else { return ["f", "p", " ", "z", "h", "g", "[", "]", "\\", ",", "."].contains(key) }
        if key == "f" { pressedF = true; speedControl.press(.key, at: event.timestamp); return true }
        if key == "p" || event.keyCode == 49 { togglePause(); return true }
        if key == "." { seek(1, audibleStep: true); return true }
        if key == "," { seek(-ClassicDOSRules.ticksPerSecond); return true }
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
        let rate = Double(ClassicDOSRules.ticksPerSecond)
        skillPanel.update(stocks: ReplaySkillPresentation.stocks(.classic(playback.session.simulation)),
            uses: playback.skillUses, tick: playback.session.currentTick, rate: rate)
        layoutSkillPanel(scale: max(1, min(2, page.bounds.width / 1120, page.bounds.height / 720)))
        effects?.setViewport(field.soundViewport)
        field.session = playback.session
        let complete = playback.session.isComplete
        let title = playback.solution.replay.title
        status.stringValue = complete ? title + "   " + L10n.text("\(playback.session.simulation.savedCount) rescued") : title
        if complete || ProcessInfo.processInfo.systemUptime > assignmentUntil { marker.point = nil }
        let time = ReplayGameTime.clock(tick: playback.session.currentTick, rate: rate)
        elapsed.stringValue = time
        timeline.doubleValue = Double(playback.session.currentTick)
        timeline.setAccessibilityValueDescription(L10n.text("\(time) of \(end.stringValue)"))
        let action = complete ? L10n.text("Replay") : paused ? L10n.text("Play") : L10n.text("Pause")
        if transport.title != action {
            transport.title = action
            transport.toolTip = complete ? L10n.text("Restart replay") : L10n.text("Play or pause. Space or P.")
            transport.setAccessibilityHelp(transport.toolTip)
        }
        transport.glyph = complete ? .undo : paused ? .play : .pause
        previousMoveButton.isEnabled = moveNavigation.target(from: playback.session.currentTick, direction: -1) != nil
        nextMoveButton.isEnabled = moveNavigation.target(from: playback.session.currentTick, direction: 1) != nil
        speedButton.title = speedControl.label
        speedButton.setAccessibilityLabel(L10n.text("Speed \(speedControl.label)"))
        field.needsDisplay = true; marker.needsDisplay = true
    }
}

@MainActor final class SolutionReplayPage: NSView, GameFullWindowPage {
    var navigationBackButton: GameActionButton?
    var hasOwnNavigation = false
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

@MainActor private final class SolutionTransportButton: GameActionButton {
    var glyph: PanelGlyph { didSet { if glyph != oldValue { needsDisplay = true } } }
    private let primary: Bool

    init(title: String, glyph: PanelGlyph, primary: Bool = false) {
        self.glyph = glyph
        self.primary = primary
        super.init(title: title, primary: primary)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func draw(_ dirtyRect: NSRect) {
        GameStoneButton.draw(bounds, selected: isEnabled && (primary || isHighlighted), pixel: 1)
        let box = CGSize(width: 28, height: 28)
        if glyph == .pause {
            NSColor(srgbRed: 0.76, green: 0.88, blue: 0.62, alpha: 1).setFill()
            let x = floor(bounds.midX), y = floor(bounds.midY) - 10
            CGRect(x: x - 8, y: y, width: 5, height: 20).fill()
            CGRect(x: x + 3, y: y, width: 5, height: 20).fill()
        } else if let image = glyph.image(fitting: box, transparentRock: true) {
            let rect = CGRect(x: floor(bounds.midX - image.size.width / 2),
                y: floor(bounds.midY - image.size.height / 2), width: image.size.width, height: image.size.height)
            NSGraphicsContext.current?.imageInterpolation = .none
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: isEnabled ? 1 : 0.35,
                respectFlipped: true, hints: nil)
        }
        GameControlText.focus(self)
    }
}
#endif
