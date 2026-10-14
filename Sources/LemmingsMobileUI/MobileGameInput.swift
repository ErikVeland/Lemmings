#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsMobileCore
import LemmingsGameArt
import NxlvKit
import LemmingsTVCore
import UIKit

extension MobileGameViewController {
    var gameplayKeyCommands: [UIKeyCommand] {
        GameplayCommands.bindings.compactMap { chord, command in
            let input: String
            switch chord.key {
            case "escape": input = UIKeyCommand.inputEscape
            case "left": input = UIKeyCommand.inputLeftArrow
            case "right": input = UIKeyCommand.inputRightArrow
            case "up": input = UIKeyCommand.inputUpArrow
            case "down": input = UIKeyCommand.inputDownArrow
            case "return": input = "\r"
            case "tab": input = "\t"
            case "home", "end", "f1": return nil
            default: input = chord.key
            }
            let title: String
            switch command {
            case .pause: title = "Pause / resume"
            case .library: title = "Library"
            case .hints: title = "Hints"
            case .help: title = "Controls"
            case .settings: title = "Settings"
            case .rewind: title = "Rewind"
            case .retry: title = "Retry"
            case .endRun: title = "End run / undo"
            case .djShuffle: title = "DJ shuffle"
            case .skill(let index): title = "Skill \(index + 1)"
            case .step(let direction): title = direction < 0 ? "Step back" : "Step forward"
            case .cycle(let direction): title = direction < 0 ? "Previous skill" : "Next skill"
            case .focusUnassigned(let direction): title = direction < 0 ? "Previous unassigned lemming" : "Next unassigned lemming"
            case .focusLast: title = "Focus last assignment"
            case .assign: title = "Assign skill"
            case .repeatAssignment: title = "Repeat last skill"
            case .centre(let entrance): title = entrance ? "Entrance" : "Exit"
            case .rate(let direction): title = direction < 0 ? "Decrease release rate" : "Increase release rate"
            case .speed: title = "Fast speed"
            case .speedStep(let direction): title = direction < 0 ? "Decrease speed" : "Increase speed"
            case .speedReset: title = "Reset speed"
            case .zoom(let superzoom): title = superzoom ? "Superzoom" : "Zoom"
            case .pan: title = "Pan"
            }
            var modifiers: UIKeyModifierFlags = chord.shift ? .shift : []
            if chord.command { modifiers.insert(.command) }
            let key = UIKeyCommand(input: input, modifierFlags: modifiers, action: #selector(discoveredCommand(_:)))
            key.discoverabilityTitle = title
            return key
        }.sorted { ($0.discoverabilityTitle ?? "") < ($1.discoverabilityTitle ?? "") }
    }
    @objc func discoveredCommand(_ key: UIKeyCommand) {
        guard let input = key.input else { return }
        let names = [UIKeyCommand.inputEscape: "escape", UIKeyCommand.inputLeftArrow: "left",
                     UIKeyCommand.inputRightArrow: "right", UIKeyCommand.inputUpArrow: "up",
                     UIKeyCommand.inputDownArrow: "down", "\r": "return", "\t": "tab"]
        if let command = GameplayCommands.command(key: names[input] ?? input, shift: key.modifierFlags.contains(.shift),
            command: key.modifierFlags.contains(.command)) { performCommand(command) }
    }

    func makeInputAdapter() -> MobileInputAdapter {
        let adapter = MobileInputAdapter()
        adapter.settings = { [weak self] in self?.gameSettings.classic ?? ClassicSettings() }
        adapter.settingsProfileID = { [weak self] in self?.settingsProfileID ?? MobileProfiles.defaultID }
        adapter.onDJShuffle = { [weak self] in self?.shuffleMusic() }
        playfieldView.onDJShuffle = { [weak self] in self?.shuffleMusic() ?? false }
        adapter.controllerSpeed = { [weak self] in self?.inputSpeed.target ?? 1 }
        adapter.triggerFeedbackEnabled = { [weak self] in self?.playState.phase == .running && self?.gameSettings.classic.reduceMotion != true }
        adapter.onRewindHeld = { [weak self] in self?.setRewindHeld($0) }
        adapter.onMenuPause = { [weak self] in
            guard let self else { return }
            if self.isChoosingToolDirection { self.performCommand(.pause); return }
            if !self.overlay.isHidden, self.overlayCanvas.page.pause != nil, self.playState.phase != .ready { self.resumeSelectedView() }
        }
        adapter.onGameMenu = { [weak self] in
            guard let self else { return }
            if self.session.isReadOnly, self.hasSolutionPair { self.selectSolutionMode(.game); return }
            if self.overlay.isHidden { self.handle(.menu) }
            else if self.overlayCanvas.page.pause != nil { self.resumeSelectedView() }
            else { self.overlayCanvas.goBack() }
        }
        #if os(tvOS)
        overlayCanvas.requiresNeutralActivation = true
        adapter.onMenuNeutral = { [weak self] in
            self?.overlayCanvas.armTVActivation()
            self?.solutionSelector.observeNeutral()
        }
        #endif
        adapter.isActive = { [weak self] in self?.lifecycle.isForeground == true && self?.lifecycle.isInterrupted == false }
        adapter.isMenu = { [weak self] in self?.overlay.isHidden == false || self?.isChoosingToolDirection == true }
        adapter.onCommand = { [weak self] in self?.performCommand($0) }
        adapter.onMenuMove = { [weak self] in self?.moveSolutionMenuFocus($0) }
        adapter.onMenuActivate = { [weak self] in
            guard let self else { return }
            if self.solutionSelector.focusedGhost { self.solutionSelector.activateGhost() }
            else if let mode = self.solutionSelector.focusedMode { self.solutionSelector.activate(mode) }
            else { self.overlayCanvas.activateFocused() }
        }
        adapter.onMenuBack = { [weak self] in
            guard let self else { return }
            if self.session.isReadOnly, self.hasSolutionPair { self.selectSolutionMode(.game) }
            else { self.overlayCanvas.goBack() }
        }
        adapter.onAim = { [weak self] dx, dy in
            guard let self else { return }
            #if os(tvOS)
            if self.tvCameraMode { self.panInput(dx: dx, dy: dy); return }
            self.tvTargetLock.clear()
            #endif
            let centre = self.previewPoint ?? MobilePoint(x: self.playfieldView.bounds.midX, y: self.playfieldView.bounds.midY)
            self.aim(at: MobilePoint(x: min(self.playfieldView.bounds.width, max(0, centre.x + dx)),
                                   y: min(self.playfieldView.bounds.height, max(0, centre.y + dy))))
        }
        overlayCanvas.onPageChanged = { [weak adapter] in adapter?.reset() }
        adapter.onMenuScroll = { [weak self] in self?.overlayCanvas.scrollInput(delta: $0) }
        adapter.onBoost = { [weak self] in self?.setControllerSpeedInput(held: $0) }
        adapter.onSpeedKey = { [weak self] in self?.setSpeedInput(.key, held: $0) }
        adapter.onPan = { [weak self] dx, dy in self?.panInput(dx: dx, dy: dy) }
        playfieldView.onHover = { [weak self] in self?.aim(at: $0, hover: true) }
        return adapter
    }

    func aim(at point: MobilePoint?, hover: Bool = false) {
        guard overlay.isHidden, playState.canEdit, lifecycle.isForeground, !lifecycle.isInterrupted else { return }
        hoverAimActive = hover
        previewInput = .precision
        previewPoint = point
        if !pollingController { highlightedTarget = point.flatMap { self.target(at: $0) } }
        if fanMode, (session as? Lemmings2MobileSession)?.isFanActive == true { updateFan(at: point, active: true) }
        renderCurrentFrame(force: true)
    }
    func restoreHoverAim() {
        hoverAimActive = true
        previewInput = .precision
        previewPoint = playfieldView.hoverInputPoint
        highlightedTarget = previewPoint.flatMap(target)
    }
    func panInput(dx: Double, dy: Double) {
        #if os(tvOS)
        tvTargetLock.clear()
        #endif
        playfieldView.stopAutomaticFitting()
        playfieldView.gameViewport.pan(viewDelta: MobilePoint(x: -dx, y: -dy))
    }

    func performCommand(_ command: GameplayCommand) {
        guard overlay.isHidden, lifecycle.isForeground, !lifecycle.isInterrupted else { return }
        #if os(tvOS)
        if tvCameraMode && [.assign, .pause, .speedReset].contains(command) {
            tvCameraMode = false; pausePlay(showControls: true); return
        }
        #endif
        if command == .speedReset, session.isReadOnly, hasSolutionPair { selectSolutionMode(.game); return }
        switch command {
        case .pause:
            handle(.pause)
        case .library: leaveToLibrary()
        case .hints: pauseForPlanning(); showHints()
        case .help: pauseForPlanning(); showControlsHelp()
        case .settings: pauseForPlanning(); showInGameSettings()
        case .djShuffle: shuffleMusic()
        case .rewind: handle(.rewind)
        case .step(let direction):
            pauseForPlanning(); handle(direction < 0 ? .stepBackward : .step)
        case .retry: showRestartLevel()
        case .endRun:
            guard !session.isReadOnly else { return }
            handle(.endRun)
        case .skill(let index): handle(.skill(index))
        case .cycle(let delta):
            let count = session.snapshot.skills.count
            guard count > 0 else { return }
            handle(.skill((selectedControl + delta + count) % count))
        case .rate(let delta): handle(.releaseRate(delta))
        case .speed: handle(.speed)
        case .speedStep(let delta): handle(.speedStep(delta))
        case .speedReset:
            if speed == 1 && !inputSpeed.isHeld { pausePlay(showControls: true) }
            else { inputSpeed.reset(at: ProcessInfo.processInfo.systemUptime); updateInputSpeed(at: ProcessInfo.processInfo.systemUptime) }
        case .zoom(let superzoom):
            let viewport = playfieldView.gameViewport
            let requested = superzoom ? 4.0 : 2.0
            let scale = abs(viewport.zoom - requested) < 0.01 ? viewport.fittedGameplayZoom : requested
            playfieldView.gameViewport.magnify(by: scale / viewport.zoom,
                around: MobilePoint(x: playfieldView.bounds.midX, y: playfieldView.bounds.midY))
        case .pan(let x, let y): panInput(dx: Double(x) * 40, dy: Double(y) * 40)
        case .centre(let entrance):
            let point = entrance ? session.entrancePoint : session.goalPoint
            var viewport = playfieldView.gameViewport
            viewport.origin = MobilePoint(x: point.x - viewport.visibleLevelSize.width / 2,
                                          y: point.y - viewport.visibleLevelSize.height / 2)
            viewport.resize(viewport.viewSize)
            playfieldView.gameViewport = viewport
        case .focusUnassigned(let direction):
            let candidates = session.targetCandidates(for: selectedControl).filter { $0.assignment == .eligible }.sorted { $0.id < $1.id }
            guard !candidates.isEmpty else { return }
            let current = candidates.firstIndex { $0.id == highlightedTarget?.id } ?? (direction > 0 ? -1 : 0)
            let candidate = candidates[(current + direction + candidates.count) % candidates.count]
            let point = playfieldView.gameViewport.viewPoint(fromLevel: candidate.point)
            aim(at: point)
            #if os(tvOS)
            tvTargetLock.select(candidate.id)
            #endif
        case .focusLast:
            if let previous = lastInputAssignment {
                aim(at: playfieldView.gameViewport.viewPoint(fromLevel: previous.point))
                #if os(tvOS)
                tvTargetLock.select(previous.id)
                #endif
            }
        case .assign, .repeatAssignment:
            guard !session.isReadOnly, playState.canEdit else { return }
            let control = command == .repeatAssignment ? (lastAssignmentControl ?? selectedControl) : selectedControl
            #if os(tvOS)
            refreshTVTarget(control: control)
            #endif
            if fanMode, let tribes = session as? Lemmings2MobileSession {
                updateFan(at: nil, active: !tribes.isFanActive)
                renderCurrentFrame(force: true); updateHUD()
                return
            }
            if let selection = highlightedTarget,
               !beginL3ToolDirectionSelection(control: control, target: selection.id, selection: selection) {
                guard session.assign(control: control, to: selection.id) else {
                    effects.rejectedAssignment()
                    return
                }
                lastInputAssignment = selection; lastAssignmentControl = control
                effects.update(session: session, viewport: playfieldView.gameViewport)
                #if os(tvOS)
                tvTargetLock.clear()
                #endif
                renderCurrentFrame(force: true); updateHUD()
            }
        }
    }

    private func moveSolutionMenuFocus(_ delta: Int) {
        guard hasSolutionPair else { overlayCanvas.moveFocus(delta); return }
        let actions = (overlayCanvas.page.rows + overlayCanvas.page.orderedFooter).filter(\.enabled)
        let selectorCount = solutionSelector.showsGhost ? 3 : 2
        let current = solutionSelector.focusedIndex
            ?? (actions.firstIndex(where: { $0.id == overlayCanvas.focusedID }).map { $0 + selectorCount } ?? selectorCount)
        let next = (current + delta + actions.count + selectorCount) % (actions.count + selectorCount)
        if next < selectorCount {
            solutionSelector.focusedIndex = next
            #if os(tvOS)
            setNeedsFocusUpdate(); updateFocusIfNeeded()
            #endif
            solutionSelector.setNeedsDisplay()
        } else {
            solutionSelector.focusedIndex = nil
            let index = actions.firstIndex(where: { $0.id == overlayCanvas.focusedID }) ?? 0
            overlayCanvas.moveFocus(next - selectorCount - index)
        }
    }

    func setControllerSpeedInput(held: Bool) {
        #if os(tvOS)
        if held {
            guard overlay.isHidden, playState.canEdit, lifecycle.isForeground, !lifecycle.isInterrupted else { return }
            if playState.phase == .planning {
                setRewindHeld(false)
                resumePlay()
                guard playState.phase == .running, overlay.isHidden else { return }
            }
        }
        #endif
        setSpeedInput(.controller, held: held)
    }

    @discardableResult func shuffleMusic() -> Bool {
        guard overlay.isHidden, playState.phase == .running, lifecycle.isForeground, !lifecycle.isInterrupted else { return false }
        return MobileMusic.shared.shuffle(scope: gameSettings.djShuffleScope)
    }

    func setSpeedInput(_ input: GameplaySpeed.Hold, held: Bool, allowTap: Bool = true) {
        let now = ProcessInfo.processInfo.systemUptime
        inputSpeed.variableEnabled = gameSettings.classic.variableSpeedEnabled
        if held {
            guard overlay.isHidden, lifecycle.isForeground, !lifecycle.isInterrupted else { return }
            if input == .key && !inputSpeed.variableEnabled { inputSpeed.tap(at: now) }
            else { inputSpeed.press(input, at: now, tapEnabled: input != .controller || gameSettings.classic.controllerTapSpeed) }
        } else {
            let validRelease = allowTap && overlay.isHidden && lifecycle.isForeground && !lifecycle.isInterrupted
            inputSpeed.release(input, at: now, allowTap: validRelease,
                               retainReachedSpeed: input == .mouse && validRelease)
        }
        updateInputSpeed(at: now)
    }
    func updateInputSpeed(at now: Double) {
        inputSpeed.variableEnabled = gameSettings.classic.variableSpeedEnabled
        if !overlay.isHidden || !lifecycle.isForeground || lifecycle.isInterrupted { inputSpeed.suspend(at: now) }
        inputSpeed.update(at: now)
        let changed = speed != inputSpeed.multiplier
        speed = inputSpeed.multiplier; clock.speed = speed
        if changed { updatePerformanceBudget(); updateHUD() }
    }
    func showInGameSettings(_ group: MobileSettingsGroup? = nil, mappings: Bool = false) {
        guard let library = parent as? MobileLibraryViewController else { return }
        showCustomOverlay(title: "Settings", details: [], actions: [])
        overlayCanvas.page = mappings ? library.controllerMappingsPage()
            : group.map { library.settingsPage($0) } ?? MobileSettingsArt.groups()
        overlayCanvas.onAction = { [weak self, weak library] id in
            guard let self, let library else { return }
            if id == "home" { self.pausePlay(showControls: true) }
            else if id == "settings" { self.showInGameSettings() }
            else if id.hasPrefix("settingsGroup."), let next = MobileSettingsGroup(rawValue: String(id.dropFirst(14))) { self.showInGameSettings(next) }
            else if id == "controllerMappings" { self.showInGameSettings(.controller, mappings: true) }
            else if id == "soundtrack" || id == "playInsights" {
                let route: MobileLibraryViewController.Route = id == "soundtrack" ? .soundtrack : .playInsights
                let exit = self.onExit
                self.onExit = { [weak library] action in
                    exit?(action)
                    if action == .library { library?.navigate(route) }
                }
                self.leaveToLibrary()
            } else if library.handleSettings(id) {
                self.gameSettings = library.mobileSettings
                if id == "setting.speed" { self.inputSpeed.setCruise(Double(library.mobileSettings.fastSpeed)) }
                self.session.applySettings(library.mobileSettings.classic)
                self.renderCurrentFrame(force: true)
                self.showInGameSettings(group, mappings: mappings)
            }
        }
        view.setNeedsLayout()
    }

    func showControlsHelp() {
        #if os(tvOS)
        let help = TVControllerBindings.help.components(separatedBy: "\n")
        #else
        let help = GameplayCommands.help + ["Two-finger tap on the playfield: DJ shuffle", "L2 / LT + L3: DJ shuffle", "DualSense touchpad click: DJ shuffle"]
        #endif
        showCustomOverlay(title: "Controls", details: help,
                          actions: [("BACK", { [weak self] in self?.pausePlay(showControls: true) })])
    }
}
#endif
