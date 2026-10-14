#if os(iOS) || os(tvOS)
import LemmingsAppCore
import NxlvKit
import LemmingsGameArt
import LemmingsMobileCore
import LemmingsTVCore
import UIKit
import GameController

@MainActor enum MobileGameExitAction {
    case library
    case retry
    case next
}

/// Who is playing a shared Hot Seat attempt, and what each result can lead to.
struct MobileGameTurn {
    let scope: String
    let owner: String
    let ownerName: String
    let ownerPortrait: Int
    /// The result buttons for a win or a loss, each naming the player who acts next.
    let choices: (Bool) -> [(label: String, choice: MobileHotSeat.Choice)]
}

@MainActor final class MobileGameViewController: UIViewController, UIScrollViewDelegate {
    lazy var inputAdapter = makeInputAdapter()
    override var canBecomeFirstResponder: Bool { true }
    var onExit: ((MobileGameExitAction) -> Void)?
    /// Called with the player who acts next, before the game leaves for a retry or the next level.
    var onHandover: ((String) -> Bool)?
    var soloOwnerID: String?
    var canDefer = false
    var onSkipLevel: (() -> Bool)?
    var onResultAwards: (() -> (stars: Int, ornament: Bool))?
    private var celebrationTask: Task<Void, Never>?
    var onRecordCompletion: ((MobileGameSnapshot) -> (details: [String], error: String?))?
    var onHints: (() -> Void)?
    var onControlsHelp: (() -> Void)?
    private var completionActions: [(String, () -> Void)] = []
    private var completionTitle = ""
    private var completionDetails: [String] = []
    private var recordSaveError: String?
    private var achievementTask: Task<Void, Never>?
    private var achievementIndex = 0
    private var resultAchievements: [(title: String, detail: String)] {
        completionDetails.compactMap { title in
            if let award = ArcadeLevelAchievement.allCases.first(where: { $0.title == title }) { return (title, award.detail) }
            if let award = TrolleyAchievement.allCases.first(where: { $0.title == title }) { return (title, award.detail) }
            if let award = ClassicAchievement.catalog.first(where: { $0.title == title }) { return (title, award.detail) }
            switch title {
            case "New rescue record": return (title, "Your best rescue count on this level.")
            case "New skill record": return (title, "Your fewest skills used to complete this level.")
            case "Level skip earned": return (title, "A level skip is now available for a later attempt.")
            default: return nil
            }
        }
    }

    private func showResultAchievement() {
        let awards = resultAchievements
        guard !awards.isEmpty else { return }
        achievementIndex %= awards.count
        let award = awards[achievementIndex]
        var actions: [(String, () -> Void)] = [("BACK", { [weak self] in self?.returnToResult() })]
        if awards.count > 1 {
            actions.append(("NEXT AWARD", { [weak self] in
                guard let self else { return }
                self.achievementIndex = (self.achievementIndex + 1) % awards.count
                self.showResultAchievement()
            }))
        }
        showCustomOverlay(title: award.title, details: [award.detail], actions: actions)
    }

    private func rotateResultAchievements() {
        achievementTask?.cancel()
        let awards = resultAchievements
        guard !awards.isEmpty else { return }
        achievementIndex %= awards.count
        func update() {
            overlayCanvas.page.rows = [.init("resultAward", awards[achievementIndex].title + "  (\(achievementIndex + 1)/\(awards.count))")]
        }
        update()
        guard awards.count > 1, !gameSettings.classic.reduceMotion, !UIAccessibility.isReduceMotionEnabled,
              !UIAccessibility.isVoiceOverRunning else { return }
        achievementTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(4)) } catch { return }
                guard let self, !self.overlay.isHidden, self.overlayCanvas.page.result else { return }
                guard self.lifecycle.isForeground, !self.lifecycle.isInterrupted else { continue }
                self.achievementIndex = (self.achievementIndex + 1) % awards.count
                self.overlayCanvas.page.rows = [.init("resultAward", awards[self.achievementIndex].title + "  (\(self.achievementIndex + 1)/\(awards.count))")]
                self.layoutOverlay()
            }
        }
    }
    private var rewindHeld = false
    private var lastRewindTime = 0.0
    var onCompleted: ((MobileGameSnapshot) -> Void)?

    let summary: MobileLevelSummary
    var gameSettings: MobileSettings
    let settingsProfileID: String
    let session: any MobileGameSession
    let checkpointStore: MobileCheckpointStore
    let runID: UUID
    var recordRunID: UUID { runID }
    var musicContext = MobileMusicContext()
    private let turn: MobileGameTurn?

    let playfieldView: MobilePlayfieldView
    let hud = MobileHUDView()
    private let touchLoupe = MobileTouchLoupe()
    let overlay = UIScrollView()
    let overlayCanvas = MobileMenuCanvas()
    private var overlayActions: [() -> Void] = []
    private var latestFrame: MobilePixelFrame?

    private var lastHUDLayout: MobileHUDLayout?
    private var hudArtworkSource: ClassicGraphicsSource?
    private var layoutSuspended = false
    var selectedControl: Int
    var lifecycle = MobileLifecycleState()
    private weak var owningScene: UIWindowScene?
    var clock: MobileTickClock
    private var displayLink: CADisplayLink?
    private var framePacing = MobileFramePacing()
    private var appliedFrameRate = 0
    private var checkpointSaveTask: Task<Void, Never>?
    private var checkpointSaveGeneration = UUID()
    var playState = MobilePlayState()
    var paused: Bool { playState.isPaused }
    var speed = 1.0
    var fastSpeed = 2.0
    var inputSpeed = GameplaySpeed(legacyMultiplier: 3)
    var hintRequestID = UUID()
    var lastAssignmentControl: Int?
    var lastInputAssignment: MobileTargetSelection?
    var previewPoint: MobilePoint?
    var previewInput: MobileTargetInput = .touch
    var hoverAimActive = false
    var highlightedTarget: MobileTargetSelection?
    var fanMode = false

    func updateFan(at point: MobilePoint?, active: Bool) {
        guard let tribes = session as? Lemmings2MobileSession else { return }
        let aim = point ?? previewPoint ?? MobilePoint(x: playfieldView.bounds.midX, y: playfieldView.bounds.midY)
        tribes.setFan(at: playfieldView.gameViewport.levelPoint(fromView: aim), active: active)
    }
    private var lastRenderedTick = -1
    var pollingController = false
    private var controllerRenderPending = false
    private var lastCheckpointTick = -1
    private var endRunArmedUntil = 0.0
    var isChoosingToolDirection: Bool { pendingL3Use != nil }
    #if os(tvOS)
    var tvCameraMode = false
    var tvTargetLock = TVTargetLock()
    override var preferredFocusEnvironments: [any UIFocusEnvironment] {
        if hasSolutionPair, solutionSelector.focusedIndex != nil { return [solutionSelector] }
        if !overlay.isHidden { return [overlayCanvas] }
        return isChoosingToolDirection ? [hud] : [playfieldView]
    }
    #endif
    private var pendingL3Use: (target: Int, control: Int, selection: MobileTargetSelection)?
    private var selectionFade = SelectionFade<Int>()
    private var completionPresented = false
    private var lastPlayfieldFrame: CGRect?
    private let observers = MobileNotificationObserverBag()
    private let audio = MobileAudioSessionController()
    private var readyCuePending = false
    let effects = MobileEffects()
    private let nowPlaying = MobileNowPlayingView()
    private let replaySkillInfo = MobileReplaySkillView()
    private let replayTitle = MobileReplayTitleView()
    private let replayMoves = MobileReplayMoveView()
    let solutionSelector = MobileSolutionSwitchView()
    private var retainedSolution: MobileGameViewController?
    private weak var solutionGame: MobileGameViewController?
    private var solutionReturnReady = false
    var hasSolutionPair: Bool { retainedSolution != nil || solutionGame != nil }
    private var countdown = GameplayStartCountdown()
    private let countdownLabel = MobilePixelLabel()
    private let freshStart: Bool
    private var lastVisibleTimestamp: Double?

    init(
        summary: MobileLevelSummary,
        session: any MobileGameSession,
        checkpointStore: MobileCheckpointStore,
        restoredCheckpoint: MobileCheckpointEnvelope?,
        turn: MobileGameTurn? = nil,
        settingsProfileID: String = MobileProfiles.defaultID
    ) {
        self.settingsProfileID = settingsProfileID
        MobileSettings.activateProfile(settingsProfileID, in: .standard)
        freshStart = restoredCheckpoint == nil && !session.isReadOnly
        self.turn = turn
        self.summary = summary
        self.session = session
        self.checkpointStore = checkpointStore
        runID = restoredCheckpoint?.runID ?? UUID()
        selectedControl = min(
            max(0, restoredCheckpoint?.selectedControl ?? 0),
            max(0, session.snapshot.skills.count - 1)
        )
        clock = MobileTickClock(ticksPerSecond: session.ticksPerSecond)
        let settings = MobileSettings.load(from: .standard, profileID: settingsProfileID)
        gameSettings = settings
        fastSpeed = Double(settings.fastSpeed)
        inputSpeed = GameplaySpeed(legacyMultiplier: fastSpeed)
        inputSpeed.setCruise(fastSpeed)
        session.applySettings(settings.classic)
        let camera = restoredCheckpoint?.camera
        let viewport = MobileViewport(
            levelSize: session.levelSize,
            viewSize: MobileSize(width: 1, height: 1),
            origin: camera?.origin ?? session.initialCameraOrigin,
            zoom: camera?.zoom,
            pixelAspect: session.engineIdentifier == "classic-dos" ? 1.2 : 1
        )
        playfieldView = MobilePlayfieldView(viewport: viewport, automaticallyFitsViewport: camera == nil, initialCameraFocus: session.entrancePoint)
        super.init(nibName: nil, bundle: nil)
        #if os(iOS)
        modalPresentationCapturesStatusBarAppearance = true
        #endif
    }

    required init?(coder: NSCoder) { nil }

    #if os(iOS)
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    #endif
    override var keyCommands: [UIKeyCommand]? { gameplayKeyCommands }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(playfieldView)
        view.addSubview(hud)
        view.addSubview(touchLoupe)
        view.addSubview(nowPlaying)
        view.addSubview(replaySkillInfo)
        view.addSubview(replayTitle)
        replayTitle.level = session.isReadOnly ? summary : nil
        countdownLabel.palette = .green
        countdownLabel.maximumScale = 6
        countdownLabel.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        countdownLabel.isHidden = true
        countdownLabel.isUserInteractionEnabled = false
        view.addSubview(countdownLabel)
        installTrackNoticeCallback()
        hud.playerName = turn?.ownerName
        hud.playerPortrait = turn.flatMap { MobileGameArt.portraits?.image($0.ownerPortrait) }
        overlayCanvas.playerName = turn?.ownerName
        playfieldView.displaySettings = gameSettings.classic
        configureOverlay()
        view.addSubview(solutionSelector)
        view.addSubview(replayMoves)
        replayMoves.onMove = { [weak self] direction in self?.seekSolutionMove(direction, showPlayfield: true) }
        solutionSelector.onSelect = { [weak self] mode in self?.selectSolutionMode(mode) }
        solutionSelector.onToggleGhost = { [weak self] in self?.toggleGhostSolution() }
        hud.onRewindHold = { [weak self] held in self?.setRewindHeld(held) }
        hud.onSpeedHold = { [weak self] held, allowTap in self?.setSpeedInput(.mouse, held: held, allowTap: allowTap) }
        onHints = { [weak self] in self?.showHints() }
        onControlsHelp = { [weak self] in self?.showControlsHelp() }
        configureGameplay()
    }

    private func installTrackNoticeCallback() {
        MobileMusic.shared.onTrackChange = { [weak self] title, soundtrack in
            guard let self else { return }
            if self.overlayCanvas.page.pause != nil, !self.overlay.isHidden {
                self.overlayCanvas.page = MobilePauseArt.page(self.pauseSummary(), actions: self.overlayCanvas.page.footer)
                self.layoutOverlay()
                return
            }
            guard !self.paused, !self.session.snapshot.isComplete, self.overlay.isHidden else { return }
            self.nowPlaying.show(title: title, soundtrack: soundtrack)
        }
    }

    private func configureGameplay() {
        hud.onHold = { [weak self] action in
            guard let self, self.overlay.isHidden, self.playState.canEdit,
                  self.lifecycle.isForeground, !self.lifecycle.isInterrupted else { return }
            if action == .pause { self.handle(.menu) }
            else if action == .endRun {
                if !self.session.snapshot.isEndingRun { self.endRunArmedUntil = ProcessInfo.processInfo.systemUptime + 1.5 }
                self.handle(.endRun)
            }
        }
        hud.onAction = { [weak self] action in self?.handle(action) }
        hud.onToolDirection = { [weak self] direction in self?.completeL3ToolDirection(direction) }
        hud.onRateDoubleTap = { [weak self] wasMaximum in
            self?.handle(.releaseRate(wasMaximum ? -99 : 99))
        }
        playfieldView.onTouchEffects = { [weak self] effects in self?.handle(effects) }
        hud.onMinimap = { [weak self] point in self?.scrollToLevelX(point.x) }
        playfieldView.onViewportChanged = { [weak self] viewport in
            guard let self else { return }
            if let frame = self.latestFrame, !self.pollingController {
                self.hud.updateMinimap(frame: frame, visible: viewport.visibleLevelRect, levelSize: self.session.levelSize)
            }
            self.renderCurrentFrame(force: true)
        }
        audio.onEvent = { [weak self] event in
            switch event {
            case .interruptionBegan, .outputRouteLost:
                self?.applyLifecycle(.audioInterruptionBegan)
            case .interruptionEnded:
                self?.applyLifecycle(.audioInterruptionEnded)
            }
        }
        audio.prepare()
        observeSystemState()
        startDisplayLink()
        updatePerformanceBudget()
        updateHUD()
        renderCurrentFrame(force: true)
        showOverlay(
            title: summary.title,
            actions: [
                (session.isReadOnly ? "PLAY" : (turn == nil ? "START" : "READY"), { [weak self] in self?.resumePlay() }),
                (session.isReadOnly ? "BACK" : "LIBRARY", { [weak self] in self?.leaveToLibrary() }),
            ]
        )

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        #if os(tvOS)
        if presses.contains(where: { $0.type == .playPause }) {
            if GCController.controllers().contains(where: { $0.microGamepad?.buttonX.isPressed == true }) { return }
            if overlay.isHidden { handle(.pause) }
            else if overlayCanvas.page.pause != nil { resumeSelectedView() }
            return
        }
        if presses.contains(where: { $0.type == .menu }) {
            if GCController.controllers().contains(where: { $0.extendedGamepad?.buttonMenu.isPressed == true || $0.microGamepad?.buttonMenu.isPressed == true }) { return }
            if solutionGame != nil { returnToSolutionGame(); return }
            if isChoosingToolDirection { completeL3ToolDirection(nil) }
            else if !overlay.isHidden { overlayCanvas.goBack() }
            else { pausePlay(showControls: true) }
            return
        }
        if overlay.isHidden && !isChoosingToolDirection && presses.allSatisfy({ $0.key == nil }) { return }
        #endif
        let handled = inputAdapter.began(presses)
        super.pressesBegan(presses.subtracting(handled), with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let handled = inputAdapter.ended(presses)
        super.pressesEnded(presses.subtracting(handled), with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        _ = inputAdapter.ended(presses)
        inputAdapter.reset()
        super.pressesCancelled(presses, with: event)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        installTrackNoticeCallback()
        startDisplayLink()
        updatePerformanceBudget()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let scene = view.window?.windowScene { owningScene = scene }
        let insets = view.safeAreaInsets
        let layout = hudLayout(insets: insets)
#if DEBUG
        if lastHUDLayout != layout {
            let mode = layout.portrait != nil ? "portrait-two-rows" : layout.panel != nil ? "desktop-panel" : "compact-grid"
            print("[MobileHUD] mode=\(mode) bounds=\(view.bounds) safeInsets=\(insets) controls=\(layout.interface.controlsFrame) reserved=\(layout.reservedRegions)")
        }
#endif
        if let previous = lastHUDLayout, previous != layout {
            cancelPendingL3ToolDirection()
            hud.cancelHeldControls()
            playfieldView.cancelInteraction()
            previewPoint = nil
            highlightedTarget = nil
            touchLoupe.isHidden = true
        }
        lastHUDLayout = layout
        // A layout transition changes the viewport, never the session or its Ready boundary.
        if !layout.canPlay, !session.snapshot.isComplete {
            if !layoutSuspended {
                layoutSuspended = true
                pausePlay(showControls: false)
                showOverlay(title: "Paused", actions: [("LIBRARY", { [weak self] in self?.leaveToLibrary() })])
            }
        } else if layoutSuspended {
            layoutSuspended = false
            showOverlay(title: "Paused", actions: [
                ("RESUME", { [weak self] in self?.resumePlay() }),
                ("LIBRARY", { [weak self] in self?.leaveToLibrary() }),
            ])
        }
        playfieldView.frame = Self.cgRect(layout.interface.playfieldFrame)
        playfieldView.blockedInputFrames = layout.reservedRegions.map { playfieldView.convert(Self.cgRect($0.frame), from: view) }
        layoutSolutionSelector()
        layoutReplayMoves()
        nowPlaying.position(in: playfieldView.frame)
        replayTitle.position(in: playfieldView.frame)
        if hasSolutionPair { replayTitle.frame.origin.y = max(replayTitle.frame.minY, solutionSelector.frame.maxY + 8) }
        if session.isReadOnly, layout.portrait != nil { replayTitle.frame.origin.y += 48 }
        countdownLabel.frame = CGRect(x: playfieldView.frame.midX - 44, y: playfieldView.frame.midY - 44, width: 88, height: 88)
        let replayWidth = min(MobileReplaySkillArt.size.width, max(0, playfieldView.frame.width - 16))
        replaySkillInfo.frame = CGRect(x: playfieldView.frame.maxX - replayWidth - 8, y: session.isReadOnly ? replayTitle.frame.maxY + 8 : playfieldView.frame.minY + (layout.portrait != nil ? 56 : 8),
            width: replayWidth, height: replayWidth * MobileReplaySkillArt.size.height / MobileReplaySkillArt.size.width)
        hud.frame = view.bounds
        updateHUD(layout: layout)
        overlay.frame = view.bounds
        layoutOverlay()
        if previewPoint != nil { renderCurrentFrame(force: true) }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        displayLink?.invalidate()
        displayLink = nil
        suspendAudio()
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(displayFrame(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func displayFrame(_ link: CADisplayLink) {
        let frameStarted = ProcessInfo.processInfo.systemUptime
        defer {
            if controllerRenderPending { renderCurrentFrame(force: true) }
            MobileDevicePerformance.recordCPU(ProcessInfo.processInfo.systemUptime - frameStarted, source: "frame")
            framePacing.observe(at: link.timestamp, cpuSeconds: MobileDevicePerformance.cpuFrameCost,
                gpuSeconds: MobileDevicePerformance.gpuFrameCost,
                active: !paused && !countdown.isActive && overlay.isHidden && lifecycle.isForeground && !lifecycle.isInterrupted)
            if framePacing.framesPerSecond != appliedFrameRate { updatePerformanceBudget() }
        }
        pollingController = true
        playfieldView.deferFrameUpdates = true
        inputAdapter.poll(context: ObjectIdentifier(overlay.isHidden ? playfieldView : overlayCanvas), at: link.timestamp)
        pollingController = false
        playfieldView.deferFrameUpdates = false
        updateInputSpeed(at: link.timestamp)
        MobileMusic.shared.advance()
        playfieldView.setSpeedEffects(multiplier: speed, active: !paused && overlay.isHidden && lifecycle.isForeground && !lifecycle.isInterrupted)
        if selectionFade.isFading(at: link.timestamp) {
            let sample = selectionFade.sample(at: link.timestamp)
            playfieldView.selectionSprite = sample.flatMap { session.spriteHighlight(for: $0.value) }
            playfieldView.selectionOpacity = sample?.opacity ?? 0
            playfieldView.redrawSelection()
        } else if highlightedTarget == nil, playfieldView.selectionSprite != nil, selectionFade.sample(at: link.timestamp) == nil {
            playfieldView.selectionSprite = nil
            playfieldView.selectionOpacity = 1
            playfieldView.redrawSelection()
        }
        playfieldView.advanceVisualEffects()
        let elapsed = lastVisibleTimestamp.map { min(0.1, max(0, link.timestamp - $0)) } ?? 0
        lastVisibleTimestamp = link.timestamp
        if countdown.isActive {
            _ = countdown.advance(seconds: elapsed, visible: overlay.isHidden && lifecycle.isForeground && !lifecycle.isInterrupted && !paused)
            countdownLabel.text = countdown.number.map(String.init) ?? ""
            countdownLabel.isHidden = !countdown.isActive
            clock.suspend()
            if countdown.isActive { return }
        }
        MobileMusic.shared.setGameplayState(paused: paused, speed: speed, rewinding: rewindHeld)
        replaySkillInfo.update(session.replaySkillUses, tick: session.snapshot.tick, visible: session.isReadOnly && overlay.isHidden)
        replayMoves.update(previous: session.replayMoveNavigation.target(from: session.snapshot.tick, direction: -1) != nil,
            next: session.replayMoveNavigation.target(from: session.snapshot.tick, direction: 1) != nil)
        if rewindHeld {
            guard lifecycle.isForeground, !lifecycle.isInterrupted, overlay.isHidden else { setRewindHeld(false); return }
            if link.timestamp - lastRewindTime >= 0.08 {
                lastRewindTime = link.timestamp
                if session.rewind(seconds: 0.4) {
                    MobileMusic.shared.playRewind()
                    effects.update(session: session, viewport: playfieldView.gameViewport, rewinding: true)
                }
                clock.suspend()
                renderCurrentFrame(force: true)
                updateHUD()
            }
            return
        }
        if endRunArmedUntil > 0, link.timestamp > endRunArmedUntil {
            endRunArmedUntil = 0
            updateHUD()
        }
        guard !paused, !session.snapshot.isComplete else { return }
        let ticks = clock.advance(at: link.timestamp)
        guard ticks > 0 else { return }
        for _ in 0..<ticks where !session.snapshot.isComplete { session.tick() }
        // Catch-up ticks accumulate cues; spatial placement and scheduling run once per frame.
        effects.update(session: session, viewport: playfieldView.gameViewport)
        renderCurrentFrame(force: true)
        updateHUD()
        if session.snapshot.isComplete {
            presentCompletion()
        } else if session.snapshot.tick - lastCheckpointTick >= Int(ceil(session.ticksPerSecond * 5)) {
            saveCheckpoint(reason: .periodic)
        }
    }

    private func hudLayout(insets: UIEdgeInsets) -> MobileHUDLayout {
        MobileHUDLayout.make(
            container: MobileSize(width: view.bounds.width, height: view.bounds.height),
            safeArea: MobileInsets(top: insets.top, left: insets.left, bottom: insets.bottom, right: insets.right),
            hasRate: session.snapshot.releaseRate != nil,
            skillCount: session.snapshot.skills.count,
            reservedRegions: MobileSystemRegions.read(in: view),
            supportsRewind: session.supportsRewind,
            hasPlayer: turn != nil,
            engineIdentifier: session.engineIdentifier
        )
    }

    func handle(_ action: MobileHUDAction) {
        guard overlay.isHidden, playState.canEdit,
              lifecycle.isForeground, !lifecycle.isInterrupted,
              !session.snapshot.isComplete || (session.isReadOnly && [.pause, .rewind, .stepBackward, .menu].contains(action)) else { return }
        cancelPendingL3ToolDirection()
        switch action {
        case let .releaseRate(delta):
            if session.adjustReleaseRate(by: delta), let rate = session.snapshot.releaseRate { effects.releaseRate(rate) }
            saveCheckpoint(reason: .periodic)
        case let .skill(index):
            guard session.snapshot.skills.indices.contains(index) else { return }
            updateFan(at: nil, active: false); fanMode = false
            selectedControl = index
            if gameSettings.pauseToAssign {
                let wasRunning = !paused
                pauseForPlanning()
                let previous = gameSettings
                gameSettings.recordSkillSelectionPause(wasRunning: wasRunning, isReadOnly: session.isReadOnly)
                if gameSettings != previous { gameSettings.save(to: .standard, profileID: settingsProfileID) }
            }
            highlightedTarget = previewPoint.flatMap(target)
            saveCheckpoint(reason: .periodic)
        case .pause:
            if session.isReadOnly, session.snapshot.isComplete {
                _ = session.rewind(seconds: Double(session.snapshot.tick) / session.ticksPerSecond)
                completionPresented = false
            }
            paused ? resumePlay() : pauseForPlanning()
        case .step:
            guard playState.canStep else { return }
            playfieldView.cancelInteraction()
            _ = session.stepForward()
            effects.update(session: session, viewport: playfieldView.gameViewport)
            clock.suspend()
            renderCurrentFrame(force: true)
            saveCheckpoint(reason: .periodic)
            if session.snapshot.isComplete { presentCompletion() }
        case .rewind, .stepBackward:
            if session.isReadOnly { completionPresented = false }
            pauseForPlanning()
            playfieldView.cancelInteraction()
            let rewound = action == .rewind ? session.rewind(seconds: 2) : session.stepBackward()
            if rewound { MobileMusic.shared.playRewind() }
            clock.suspend()
            highlightedTarget = nil
            previewPoint = nil
            #if os(tvOS)
            tvTargetLock.clear()
            #endif
            renderCurrentFrame(force: true)
            saveCheckpoint(reason: .periodic)
        case .menu:
            pausePlay(showControls: true)
        case .endRun:
            if session.snapshot.isEndingRun {
                _ = session.undoEndRun()
                endRunArmedUntil = 0
            } else {
                let now = ProcessInfo.processInfo.systemUptime
                if now <= endRunArmedUntil {
                    _ = session.beginEndRun()
                    endRunArmedUntil = 0
                } else {
                    endRunArmedUntil = now + 1.5
                }
            }
            renderCurrentFrame(force: true)
        case .speed:
            inputSpeed.variableEnabled = gameSettings.classic.variableSpeedEnabled
            inputSpeed.tap(at: ProcessInfo.processInfo.systemUptime)
            updateInputSpeed(at: ProcessInfo.processInfo.systemUptime)
        case let .speedStep(direction):
            inputSpeed.step(direction, at: ProcessInfo.processInfo.systemUptime)
            updateInputSpeed(at: ProcessInfo.processInfo.systemUptime)
        }
        updateHUD()
    }

    @discardableResult
    func beginL3ToolDirectionSelection(control: Int, target: Int,
                                       selection: MobileTargetSelection) -> Bool {
        guard let useIndex = Lemmings3Runtime.Action.allCases.firstIndex(of: .use),
              control == useIndex,
              let chronicles = session as? Lemmings3MobileSession,
              chronicles.directionPickerFrames.count == 8 else { return false }
        let point = playfieldView.gameViewport.viewPoint(fromLevel: selection.point)
        let targetPoint = playfieldView.convert(CGPoint(x: point.x, y: point.y), to: hud)
        let playfield = playfieldView.convert(playfieldView.bounds, to: hud)
        pendingL3Use = (target, control, selection)
        pauseForPlanning()
        guard hud.showToolDirectionPicker(frames: chronicles.directionPickerFrames,
            target: targetPoint, playfield: playfield) else {
            pendingL3Use = nil
            effects.rejectedAssignment()
            return true
        }
        view.bringSubviewToFront(hud)
        return true
    }

    func completeL3ToolDirection(_ direction: Lemmings3Runtime.Direction?) {
        guard let pendingL3Use,
              let chronicles = session as? Lemmings3MobileSession else { return }
        guard let direction else {
            self.pendingL3Use = nil
            hud.hideToolDirectionPicker()
            restoreGameplayOverlayOrder()
            updateHUD()
            return
        }
        let accepted = chronicles.useTool(direction: direction, to: pendingL3Use.target)
        guard accepted else { effects.rejectedAssignment(); return }
        self.pendingL3Use = nil
        hud.hideToolDirectionPicker()
        restoreGameplayOverlayOrder()
        lastInputAssignment = pendingL3Use.selection
        lastAssignmentControl = pendingL3Use.control
        highlightedTarget = pendingL3Use.selection
        effects.update(session: session, viewport: playfieldView.gameViewport)
        saveCheckpoint(reason: .periodic)
        renderCurrentFrame(force: true)
        updateHUD()
    }

    func cancelPendingL3ToolDirection() {
        guard pendingL3Use != nil else { return }
        pendingL3Use = nil
        hud.hideToolDirectionPicker()
        restoreGameplayOverlayOrder()
    }

    private func restoreGameplayOverlayOrder() {
        view.bringSubviewToFront(touchLoupe)
        view.bringSubviewToFront(nowPlaying)
        view.bringSubviewToFront(replaySkillInfo)
        view.bringSubviewToFront(countdownLabel)
        view.bringSubviewToFront(replayMoves)
        view.bringSubviewToFront(solutionSelector)
    }

    private func handle(_ touchEffects: [MobileTouchEffect]) {
        guard !session.isReadOnly, overlay.isHidden, playState.canEdit,
              lifecycle.isForeground, !lifecycle.isInterrupted,
              !session.snapshot.isComplete else { return }
        var needsFrame = false
        for effect in touchEffects {
            switch effect {
            case let .preview(point), let .movePreview(point):
                hoverAimActive = false
                previewInput = playfieldView.touchInput
                previewPoint = point
                highlightedTarget = target(at: point)
                needsFrame = true
            case let .commit(point):
                if fanMode {
                    previewPoint = point
                    updateFan(at: point, active: (session as? Lemmings2MobileSession)?.isFanActive != true)
                    needsFrame = true
                    continue
                }
                previewInput = playfieldView.touchInput
                previewPoint = previewInput == .precision ? point : nil
                if let selection = target(at: point), selection.state == .eligible {
                    if !beginL3ToolDirectionSelection(control: selectedControl,
                        target: selection.id, selection: selection) {
                        let accepted = session.assign(control: selectedControl, to: selection.id)
                        if accepted {
                            lastInputAssignment = selection; lastAssignmentControl = selectedControl
                            effects.update(session: session, viewport: playfieldView.gameViewport)
                        } else { effects.rejectedAssignment() }
                        saveCheckpoint(reason: .periodic)
                    }
                    highlightedTarget = selection
                } else {
                    highlightedTarget = target(at: point)
                }
                needsFrame = true
            case let .pan(delta):
                restoreHoverAim()
                playfieldView.stopAutomaticFitting()
                let oldViewport = playfieldView.gameViewport
                playfieldView.gameViewport.pan(viewDelta: delta)
                needsFrame = playfieldView.gameViewport == oldViewport
            case .cancelPreview:
                restoreHoverAim()
                needsFrame = true
            }
        }
        if needsFrame {
            renderCurrentFrame(force: true)
            updateHUD()
        }
    }

    func target(at point: MobilePoint) -> MobileTargetSelection? {
        target(at: point, control: selectedControl)
    }
    func target(at point: MobilePoint, control: Int) -> MobileTargetSelection? {
        selectTarget(at: point, candidates: session.targetCandidates(for: control), control: control)
    }
    private func selectTarget(at point: MobilePoint, candidates: [MobileTargetCandidate], control requestedControl: Int? = nil) -> MobileTargetSelection? {
        let control = requestedControl ?? selectedControl
        let settings = gameSettings.classic
        let preference: MobileTargetPreference
        if session.engineIdentifier == "classic-dos", control == 4, settings.favorBuilders { preference = .builder }
        else if session.engineIdentifier == "classic-dos", control == 2, settings.favorBombBlockers { preference = .bombBlocker }
        else if session.engineIdentifier == "lemmings3", control >= 3 { preference = .toolHolder }
        else { preference = .assignable }
        return MobileTargetSelector.select(
            candidates: candidates,
            touch: point,
            viewport: playfieldView.gameViewport,
            radius: 30,
            preference: preference,
            favourApproaching: settings.favorApproachingLemmings,
            input: previewInput
        )
    }

    private func scrollToLevelX(_ x: CGFloat) {
        guard overlay.isHidden else { return }
        var viewport = playfieldView.gameViewport
        viewport.origin = MobilePoint(x: Double(x) - viewport.visibleLevelSize.width / 2, y: viewport.origin.y)
        viewport.clamp()
        playfieldView.stopAutomaticFitting()
        playfieldView.gameViewport = viewport
    }

    func renderCurrentFrame(force: Bool) {
        if pollingController { controllerRenderPending = controllerRenderPending || force; return }
        let tick = session.snapshot.tick
        guard force || tick != lastRenderedTick else { return }
        controllerRenderPending = false
        var needsCandidates = previewPoint != nil || gameSettings.classic.showReticleCount
        #if os(tvOS)
        needsCandidates = needsCandidates || tvTargetLock.id != nil
        #endif
        let candidates = needsCandidates ? session.targetCandidates(for: selectedControl) : []
        if overlay.isHidden, playState.canEdit {
            if hoverAimActive { previewPoint = playfieldView.hoverInputPoint }
            #if os(tvOS)
            if tvTargetLock.id != nil {
                highlightedTarget = tvTargetLock.resolve(candidates: candidates,
                                                        visible: playfieldView.gameViewport.visibleLevelRect)
                if let highlightedTarget { previewPoint = playfieldView.gameViewport.viewPoint(fromLevel: highlightedTarget.point) }
            } else if let previewPoint { highlightedTarget = selectTarget(at: previewPoint, candidates: candidates) }
            else if hoverAimActive { highlightedTarget = nil }
            #else
            if let previewPoint { highlightedTarget = selectTarget(at: previewPoint, candidates: candidates) }
            else if hoverAimActive { highlightedTarget = nil }
            #endif
        }
        if tick < lastRenderedTick { selectionFade.reset(); playfieldView.resetTransientEffects() }
        do {
            let frame = try session.render(highlight: highlightedTarget)
            latestFrame = frame
            playfieldView.renderScale = session.renderScale
            playfieldView.explosions = session.explosions
            playfieldView.bombCountdowns = session.bombCountdowns
            playfieldView.selectionPoint = highlightedTarget?.point
            playfieldView.cursorPoint = previewPoint.map { playfieldView.gameViewport.levelPoint(fromView: $0) }
            playfieldView.cursorIcon = session.skillCursorFrame(control: selectedControl).flatMap(MobileBitmapRenderer.image)
            let cursorSkill = session.snapshot.skills.indices.contains(selectedControl) ? session.snapshot.skills[selectedControl] : nil
            playfieldView.cursorSkillName = cursorSkill?.name ?? ""
            if fanMode { playfieldView.cursorIcon = nil; playfieldView.cursorSkillName = "Fan" }
            playfieldView.cursorRemaining = session.skillCursorRemaining(control: selectedControl, target: highlightedTarget?.id)
            if fanMode { playfieldView.cursorRemaining = nil }
            playfieldView.cursorUnlimited = session.engineIdentifier != "lemmings3" && cursorSkill?.isUnlimited == true && playfieldView.cursorRemaining == nil
            if gameSettings.classic.showReticleCount, let point = playfieldView.cursorPoint {
                playfieldView.cursorCount = candidates.filter { abs($0.point.x - point.x) <= 8 && abs($0.point.y - point.y) <= 8 }.count
            } else { playfieldView.cursorCount = nil }
            if gameSettings.classic.lemmingSelectionStyle == .modern, overlay.isHidden {
                selectionFade.set(highlightedTarget?.id, at: ProcessInfo.processInfo.systemUptime)
            } else { selectionFade.reset() }
            let selection = selectionFade.sample(at: ProcessInfo.processInfo.systemUptime)
            playfieldView.selectionSprite = session.selectionSprite ?? selection.flatMap { session.spriteHighlight(for: $0.value) }
            playfieldView.selectionOpacity = selection?.opacity ?? 1
            playfieldView.rescueSprites = session.rescueSprites
            playfieldView.assignmentSprite = session.assignmentSprite
            playfieldView.assignmentProgress = session.assignmentProgress
            playfieldView.setRescueFeedback(saved: session.snapshot.saved, required: session.snapshot.required, total: session.snapshot.total,
                isComplete: session.snapshot.isComplete, didWin: session.snapshot.didWin)
            playfieldView.failed = session.snapshot.isComplete ? !session.snapshot.didWin : (session.snapshot.saved + session.activeLemmingCount + max(0, session.snapshot.total - session.snapshot.released) < session.snapshot.required)
            try playfieldView.update(frame: frame)
            if !overlay.isHidden, overlayCanvas.page.preview {
                overlayCanvas.preview = MobileBitmapRenderer.image(frame)
                let visible = playfieldView.gameViewport.visibleLevelRect
                overlayCanvas.previewSource = CGRect(x: visible.x * session.renderScale, y: visible.y * session.renderScale, width: visible.width * session.renderScale, height: visible.height * session.renderScale)
            }
            hud.updateMinimap(frame: frame, visible: playfieldView.gameViewport.visibleLevelRect,
                              levelSize: session.levelSize)
            if previewInput == .touch, let point = previewPoint, let target = highlightedTarget {
                let finger = playfieldView.convert(CGPoint(x: point.x, y: point.y), to: view)
                let field = playfieldView.frame
                let free = MobileDisplayRegions.freeFrames(
                    in: MobileRect(x: field.minX, y: field.minY, width: field.width, height: field.height),
                    avoiding: lastHUDLayout?.reservedRegions ?? [])
                let containing = free.filter { $0.contains(MobilePoint(x: finger.x, y: finger.y)) }
                let area = (containing.isEmpty ? free : containing).max { $0.width * $0.height < $1.width * $1.height }
                touchLoupe.update(bitmap: frame, target: .init(x: target.point.x * session.renderScale, y: target.point.y * session.renderScale),
                                  finger: finger,
                                  bounds: area.map(Self.cgRect) ?? .zero,
                                  pixelAspect: session.engineIdentifier == "classic-dos" ? 1.2 : 1,
                                  countdowns: session.bombCountdowns, renderScale: session.renderScale)
            } else {
                touchLoupe.isHidden = true
            }
            lastRenderedTick = tick
        } catch {
            pausePlay(showControls: false)
            showOverlay(
                title: error.localizedDescription,
                actions: [("LIBRARY", { [weak self] in self?.leaveToLibrary() })]
            )
        }
    }

    private func suspendAudio() {
        playfieldView.suspendVisualEffects()
        hud.cancelHeldControls()
        setRewindHeld(false)
        effects.suspend()
        MobileMusic.shared.suspend()
        audio.suspend()
    }

    private func pauseGameplayAudio() {
        setRewindHeld(false)
        effects.pause()
        MobileMusic.shared.setGameplayState(paused: true, speed: speed)
    }

    /// Reactivates the session, then starts this level's tune or lifts its pause.
    private func resumeAudio() {
        audio.resume { [weak self] succeeded in
            guard let self, succeeded, self.lifecycle.isForeground, !self.lifecycle.isInterrupted else { return }
            self.effects.prepare()
            self.effects.resume()
            if self.readyCuePending && !self.paused {
                self.readyCuePending = false
                self.effects.ready()
            }
            MobileMusic.shared.selectProfile(self.settingsProfileID)
            MobileMusic.shared.play(identifier: self.session.levelIdentifier, index: self.session.levelIndex,
                                    title: self.summary.title, attemptID: self.runID, context: self.musicContext)
            MobileMusic.shared.resume()
        }
    }

    func pausePlay(showControls: Bool) {
        updateFan(at: nil, active: false)
        hud.cancelHeldControls()
        playState.suspend()
        playfieldView.cancelInteraction()
        hoverAimActive = false
        previewPoint = nil
        highlightedTarget = nil
        touchLoupe.isHidden = true
        clock.suspend()
        pauseGameplayAudio()
        updateHUD()
        guard showControls else { return }
        #if os(tvOS)
        tvCameraMode = false
        showOverlay(title: "PAUSED", actions: [
            (session.isReadOnly ? (session.snapshot.isComplete ? "REPLAY" : "PLAY") : "RESUME", { [weak self] in self?.resumeSelectedView() }),
            (session.isReadOnly ? "BACK" : "LIBRARY", { [weak self] in self?.leaveToLibrary() }),
        ] + (session.isReadOnly ? [] : [
            ("RESTART LEVEL", { [weak self] in self?.showRestartLevel() }),
        ]) + [("GAME CONTROLS", { [weak self] in self?.showTVControls() })])
        #else
        showOverlay(
            title: "PAUSED",
            actions: [
                (session.isReadOnly ? (session.snapshot.isComplete ? "REPLAY" : "PLAY") : "RESUME", { [weak self] in self?.resumeSelectedView() }),
                (session.isReadOnly ? "BACK" : "LIBRARY", { [weak self] in self?.leaveToLibrary() }),
            ] + (session.isReadOnly ? [] : [
                ("RESTART LEVEL", { [weak self] in self?.showRestartLevel() }),
                ("GAME CONTROLS", { [weak self] in self?.showPauseTools() }),
            ])
        )
        #endif
        if session.isReadOnly, !session.replayMoveNavigation.ticks.isEmpty {
            let previous = overlayActions.count
            overlayActions += [{ [weak self] in self?.seekSolutionMove(-1) }, { [weak self] in self?.seekSolutionMove(1) }]
            overlayCanvas.page.footer += [
                .init(String(previous), "PREVIOUS MOVE", enabled: session.replayMoveNavigation.target(from: session.snapshot.tick, direction: -1) != nil),
                .init(String(previous + 1), "NEXT MOVE", enabled: session.replayMoveNavigation.target(from: session.snapshot.tick, direction: 1) != nil),
            ]
        }
    }

    private func showPauseTools() {
        var actions: [(String, () -> Void)] = [
            ("BACK", { [weak self] in self?.pausePlay(showControls: true) }),
            ("HINT", { [weak self] in self?.onHints?() }),
            ("CONTROLS HELP", { [weak self] in self?.onControlsHelp?() }),
            ("SETTINGS", { [weak self] in self?.showInGameSettings() }),
        ]
        if session is Lemmings2MobileSession {
            actions.append((fanMode ? "SKILL MODE" : "FAN", { [weak self] in
                guard let self else { return }
                self.fanMode.toggle()
                self.resumePlay()
            }))
        }
        showCustomOverlay(title: "Game controls", details: [], actions: actions)
        overlayCanvas.page.footerColumns = 1
    }

    func showRestartLevel() {
        guard !session.isReadOnly else { return }
        pausePlay(showControls: false)
        showCustomOverlay(title: "Restart level?", details: [summary.locationLabel, summary.title], actions: [
            ("CANCEL", { [weak self] in self?.pausePlay(showControls: true) }),
            ("RESTART LEVEL", { [weak self] in self?.finish(.retry) }),
        ])
        overlayCanvas.page.footer[0].primary = false
        overlayCanvas.page.footer[1].primary = true
        overlayCanvas.page.footerColumns = 1
        overlayCanvas.page.detailTitles = [1]
    }

    func pauseForPlanning() {
        updateFan(at: nil, active: false)
        countdown.cancel()
        countdownLabel.isHidden = true
        guard playState.pauseForPlanning() else { return }
        playfieldView.cancelInteraction()
        restoreHoverAim()
        touchLoupe.isHidden = true
        clock.suspend()
        pauseGameplayAudio()
        renderCurrentFrame(force: true)
        updateHUD()
    }

    func resumePlay() {
        cancelPendingL3ToolDirection()
        let wasReady = playState.phase == .ready
        guard hudLayout(insets: view.safeAreaInsets).canPlay, !session.snapshot.isComplete,
              lifecycle.isForeground, !lifecycle.isInterrupted else { return }
        // Let the tenth planning pause finish before asking on the player's next Play action.
        if !wasReady, !session.isReadOnly, gameSettings.shouldOfferSkillSelectionPauseChoice {
            showOverlay(title: "Skill selection", actions: [
                ("Turn off", { [weak self] in self?.chooseSkillSelectionPause(false) }),
                ("Keep pausing", { [weak self] in self?.chooseSkillSelectionPause(true) }),
            ])
            overlayCanvas.page = MobileSettingsArt.skillSelectionPauseChoice()
            layoutOverlay()
            return
        }
        guard
              playState.resume(isForeground: lifecycle.isForeground, isInterrupted: lifecycle.isInterrupted) else { return }
        if wasReady {
            readyCuePending = true
            if freshStart { countdown.arm(); countdownLabel.text = "3"; countdownLabel.isHidden = false }
        }
        let needsLifecycleResume = lifecycle.requiresPlayerResume
        if needsLifecycleResume {
            applyEffects(lifecycle.handle(.playerRequestedResume))
        }
        guard lifecycle.isForeground, !lifecycle.isInterrupted else { return }
        overlay.isHidden = true
        if !needsLifecycleResume { resumeAudio() }
        session.resumeFromCurrentTick()
        clock.suspend()
        playfieldView.cancelInteraction()
        overlay.isHidden = true
        overlay.accessibilityViewIsModal = false
        playfieldView.isUserInteractionEnabled = true
        hud.isUserInteractionEnabled = true
        playfieldView.accessibilityElementsHidden = false
        hud.accessibilityElementsHidden = false
        updateHUD()
        UIAccessibility.post(notification: .announcement, argument: "Game resumed")
        view.setNeedsLayout()
    }

    private func chooseSkillSelectionPause(_ enabled: Bool) {
        gameSettings.chooseSkillSelectionPause(enabled)
        gameSettings.save(to: .standard, profileID: settingsProfileID)
        resumePlay()
    }

    private func presentCompletion() {
        guard !completionPresented else { return }
        completionPresented = true
        playState.complete()
        clock.suspend()
        if session.isReadOnly {
            playState = MobilePlayState()
            _ = playState.resume(isForeground: lifecycle.isForeground, isInterrupted: lifecycle.isInterrupted)
            _ = playState.pauseForPlanning()
            updateHUD()
            return
        }
        let snapshot = session.snapshot
        if let report = onRecordCompletion?(snapshot) {
            completionDetails = report.details
            recordSaveError = report.error
        }
        nowPlaying.hide()
        effects.result(won: snapshot.didWin)
        onCompleted?(snapshot)
        let result = snapshot.didWin
            ? "LEVEL COMPLETE\n\(snapshot.saved) SAVED"
            : "LEVEL ENDED\n\(snapshot.saved) SAVED"
        var actions: [(String, () -> Void)]
        if let turn {
            actions = turn.choices(snapshot.didWin).map { entry in
                (entry.label, { [weak self] in
                    self?.finish(entry.choice.kind == .next ? .next : .retry, handingTo: entry.choice.player)
                })
            }
            // The level is over, so the turn passes by the house rule even when the player leaves.
            let following = turn.choices(snapshot.didWin).first(where: { $0.choice.primary })?.choice.player
            actions.append(("LIBRARY", { [weak self] in self?.finish(.library, handingTo: following) }))
        } else if snapshot.didWin {
            actions = [
                ("NEXT LEVEL", { [weak self] in self?.finish(.next) }),
                ("RETRY", { [weak self] in self?.finish(.retry) }),
                ("LIBRARY", { [weak self] in self?.finish(.library) }),
            ]
        } else {
            actions = [
                ("RETRY", { [weak self] in self?.finish(.retry) }),
                ("LIBRARY", { [weak self] in self?.finish(.library) }),
            ]
        }
        if !snapshot.didWin, canDefer {
            actions.append(("LATER", { [weak self] in
                guard let self else { return }
                self.finish(.next, handingTo: self.turn?.choices(false).first?.choice.player)
            }))
        }
        if !snapshot.didWin, onSkipLevel != nil {
            actions.append(("SKIP LEVEL", { [weak self] in
                guard let self, !self.transitionInFlight, self.onSkipLevel?() == true else { return }
                self.finish(.next, handingTo: self.turn?.choices(false).first?.choice.player)
            }))
        }
        if let data = try? session.replayDocument() {
            actions.append(("REVIEW", { [weak self] in self?.showReplay(document: data) }))
            actions.append(("SHARE MOVIE", { [weak self] in self?.shareReplayMovie(document: data) }))
        }
        if recordSaveError != nil {
            showOverlay(title: recordSaveError ?? "SAVE FAILED", actions: [("TRY AGAIN", { [weak self] in
                guard let self else { return }
                self.completionPresented = false
                self.presentCompletion()
            })])
            return
        }
        completionTitle = result
        completionActions = actions
        showOverlay(title: result, actions: actions, results: true)
        startResultCelebration()
    }

    private func startResultCelebration() {
        celebrationTask?.cancel()
        guard let award = onResultAwards?(), award.stars > 0 else { return }
        let reduced = gameSettings.classic.reduceMotion || UIAccessibility.isReduceMotionEnabled
        overlayCanvas.revealedStars = reduced ? 3 : 0
        celebrationTask = Task { @MainActor [weak self] in
            for star in 1...min(3, award.stars) {
                do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
                guard let self, !self.overlay.isHidden, self.lifecycle.isForeground, !self.lifecycle.isInterrupted else { return }
                if !reduced { self.overlayCanvas.revealedStars = star; self.overlayCanvas.stampedStar = star }
                self.effects.playChime(star: star, ornament: award.ornament && star == award.stars)
                do { try await Task.sleep(for: .milliseconds(90)) } catch { return }
                self.overlayCanvas.stampedStar = nil
            }
        }
    }

    private var transitionInFlight = false
    func resetTransition() { transitionInFlight = false }

    private func finish(_ action: MobileGameExitAction, handingTo player: String? = nil) {
        guard recordSaveError == nil, !transitionInFlight else { return }
        if action == .retry { MobileMusic.shared.vinylStop() }
        if let player, onHandover?(player) == false {
            showOverlay(title: "HOT SEAT WAS NOT SAVED", actions: [("TRY AGAIN", { [weak self] in self?.finish(action, handingTo: player) })])
            return
        }
        transitionInFlight = true
        celebrationTask?.cancel(); celebrationTask = nil
        displayLink?.isPaused = true
        suspendAudio()
        effects.stop()
        if action == .library { MobileMusic.shared.stop() }
        Task { [self] in
            do {
                try await checkpointStore.retire(runID: runID)
                onExit?(action)
            } catch {
                resetTransition()
                showCustomOverlay(title: "RUN WAS NOT CLOSED", details: [], actions: [
                    ("TRY AGAIN", { [weak self] in self?.finish(action) }),
                ])
            }
        }
    }

    func leaveToLibrary() {
        if solutionGame != nil { returnToSolutionGame(); return }
        if session.isReadOnly { dismiss(animated: false); return }
        playState.suspend()
        clock.suspend()
        displayLink?.isPaused = true
        suspendAudio()
        guard !session.snapshot.isComplete else {
            finish(.library)
            return
        }
        showOverlay(title: "SAVING...", actions: [])
        do {
            let encoding = try makeCheckpoint()
            let previousSave = checkpointSaveTask
            Task { [self] in
                do {
                    await previousSave?.value
                    let envelope = try await encoding.value
                    try await checkpointStore.save(envelope)
                    MobileMusic.shared.stop()
                    onExit?(.library)
                } catch {
                    displayLink?.isPaused = false
                    showOverlay(
                        title: error.localizedDescription,
                        actions: [
                            ("TRY AGAIN", { [weak self] in self?.leaveToLibrary() }),
                            ("RESUME", { [weak self] in self?.resumePlay() }),
                        ]
                    )
                }
            }
        } catch {
            displayLink?.isPaused = false
            showOverlay(title: error.localizedDescription,
                        actions: [("RESUME", { [weak self] in self?.resumePlay() })])
        }
    }

    private func saveCheckpoint(reason: MobileCheckpointReason) {
        guard !session.isReadOnly, !session.snapshot.isComplete else { return }
        if reason == .periodic, checkpointSaveTask != nil { return }
        do {
            let encoding = try makeCheckpoint()
            let previousSave = checkpointSaveTask
            let generation = UUID()
            checkpointSaveGeneration = generation
            lastCheckpointTick = session.snapshot.tick
            let backgroundTask: UIBackgroundTaskIdentifier
            if reason == .suspension || reason == .sceneDisconnect || reason == .audioInterruption {
                backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Save Lemmings run")
            } else {
                backgroundTask = .invalid
            }
            checkpointSaveTask = Task {
                defer {
                    if checkpointSaveGeneration == generation { checkpointSaveTask = nil }
                    if backgroundTask != .invalid {
                        UIApplication.shared.endBackgroundTask(backgroundTask)
                    }
                }
                await previousSave?.value
                do {
                    let envelope = try await encoding.value
                    try await checkpointStore.save(envelope)
                } catch {
                    // Retry on the next periodic or lifecycle save.
                    lastCheckpointTick = min(lastCheckpointTick, session.snapshot.tick - Int(session.ticksPerSecond * 5))
                }
            }
        } catch {
            // The current run stays in memory. A later lifecycle save can retry.
        }
    }

    private func makeCheckpoint() throws -> Task<MobileCheckpointEnvelope, Error> {
        let viewport = playfieldView.gameViewport
        let payload = try session.prepareCheckpointPayload()
        let metadata = MobileCheckpointEnvelope(
            runID: runID,
            engine: session.engineIdentifier,
            engineFingerprint: session.engineFingerprint,
            levelIdentifier: session.levelIdentifier,
            levelIndex: session.levelIndex,
            levelFingerprint: session.levelFingerprint,
            tick: session.snapshot.tick,
            selectedControl: selectedControl,
            camera: MobileCameraState(origin: viewport.origin, zoom: viewport.zoom),
            payload: Data(),
            scope: turn?.scope,
            owner: turn?.owner ?? soloOwnerID
        )
        return Task.detached(priority: .utility) {
            MobileCheckpointEnvelope(runID: metadata.runID, engine: metadata.engine,
                engineFingerprint: metadata.engineFingerprint, levelIdentifier: metadata.levelIdentifier,
                levelIndex: metadata.levelIndex, levelFingerprint: metadata.levelFingerprint,
                tick: metadata.tick, selectedControl: metadata.selectedControl, camera: metadata.camera,
                payload: try payload.encode(), savedAt: metadata.savedAt, scope: metadata.scope, owner: metadata.owner)
        }
    }

    private func observeSystemState() {
        let centre = NotificationCenter.default
        func observe(_ name: Notification.Name, _ event: MobileLifecycleEvent, sceneOnly: Bool = false) {
            observers.append(centre.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let scene = notification.object as? UIWindowScene
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if sceneOnly {
                        guard let scene,
                              scene === (self.viewIfLoaded?.window?.windowScene ?? self.owningScene) else { return }
                    }
                    self.applyLifecycle(event)
                }
            })
        }
        observe(UIScene.willDeactivateNotification, .becameInactive, sceneOnly: true)
        observe(UIScene.didEnterBackgroundNotification, .enteredBackground, sceneOnly: true)
        observe(UIScene.didActivateNotification, .becameActive, sceneOnly: true)
        observe(UIScene.didDisconnectNotification, .sceneDisconnected, sceneOnly: true)
        observe(UIApplication.didReceiveMemoryWarningNotification, .memoryWarning)
        observers.append(centre.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updatePerformanceBudget()
                self?.renderCurrentFrame(force: true)
            }
        })
        observers.append(centre.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.updatePerformanceBudget() } })
        observers.append(centre.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.updatePerformanceBudget() } })
    }

    private func applyLifecycle(_ event: MobileLifecycleEvent) {
        inputAdapter.reset()
        applyEffects(lifecycle.handle(event))
    }

    private func applyEffects(_ effects: [MobileLifecycleEffect]) {
        for effect in effects {
            switch effect {
            case .pauseSimulation:
                updateFan(at: nil, active: false)
                playState.suspend()
                clock.suspend()
            case .resumeSimulation:
                _ = playState.resume(isForeground: lifecycle.isForeground, isInterrupted: lifecycle.isInterrupted)
                clock.suspend()
            case .cancelInput:
                playfieldView.cancelInteraction()
                previewPoint = nil
                highlightedTarget = nil
                touchLoupe.isHidden = true
            case let .saveCheckpoint(reason):
                saveCheckpoint(reason: reason)
            case .suspendAudio:
                suspendAudio()
            case .prepareAudio:
                audio.prepare()
                renderCurrentFrame(force: true)
            case .resumeAudio:
                resumeAudio()
            case .showResumeControl:
                if overlay.isHidden { pausePlay(showControls: true) }
            case .purgeTransientResources:
                session.releaseTransientResources()
                // The visible bitmap is the current frame, not a transient cache.
            }
        }
        updateHUD()
    }

    func updatePerformanceBudget() {
        let level: MobileThermalLevel
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: level = .nominal
        case .fair: level = .fair
        case .serious: level = .serious
        case .critical: level = .critical
        @unknown default: level = .serious
        }
        let budget = MobileThermalPolicy.budget(
            for: level,
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            reduceMotion: UIAccessibility.isReduceMotionEnabled,
            reduceFlashes: UIAccessibility.isReduceMotionEnabled,
            constrainedDevice: MobileDevicePerformance.constrained
        )
        framePacing.setMaximumFramesPerSecond(min(budget.framesPerSecond, view.window?.screen.maximumFramesPerSecond ?? 60))
        let framesPerSecond = framePacing.framesPerSecond
        appliedFrameRate = framesPerSecond
        MobileDevicePerformance.update(framesPerSecond: framesPerSecond)
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: Float(framesPerSecond),
            maximum: Float(framesPerSecond),
            preferred: Float(framesPerSecond)
        )
        let speedCatchUp = Int(ceil(
            session.ticksPerSecond * speed / Double(max(1, framesPerSecond)) * 2
        ))
        clock.maximumCatchUpTicks = max(budget.maximumCatchUpTicks, speedCatchUp)
    }

    func updateHUD(layout: MobileHUDLayout? = nil) {
        MobileMusic.shared.update(session.snapshot, active: session.activeLemmingCount, nukeRemainingTicks: session.nukeRemainingTicks, allNukePopped: session.allNukeExplosionsPlayed, ticksPerSecond: session.ticksPerSecond)
        MobileMusic.shared.setGameplayState(paused: paused, speed: speed, rewinding: rewindHeld)
        let resolved = layout ?? lastHUDLayout ?? hudLayout(insets: view.safeAreaInsets)
        if hudArtworkSource != gameSettings.classic.graphics {
            hud.skillIcons = session.snapshot.skills.indices.map { session.skillCursorFrame(control: $0).flatMap(MobileBitmapRenderer.image) }
            hudArtworkSource = gameSettings.classic.graphics
        }
        hud.counterStyle = gameSettings.classic.counterStyle
        hud.update(
            layout: resolved,
            snapshot: session.snapshot,
            selectedSkill: selectedControl,
            paused: paused,
            speed: speed,
            endRunArmed: endRunArmedUntil > ProcessInfo.processInfo.systemUptime,
            panel: session.panelFrame,
            readOnly: session.isReadOnly
        )
    }

    private func configureOverlay() {
        overlay.delegate = self
        overlay.backgroundColor = .black
        overlay.accessibilityViewIsModal = true
        overlay.addSubview(overlayCanvas)
        overlayCanvas.onAction = { [weak self] id in
            if id == "resultAward" { self?.showResultAchievement(); return }
            guard let self, let index = Int(id), self.overlayActions.indices.contains(index) else { return }
            self.overlayActions[index]()
        }
        view.addSubview(overlay)
    }

    func returnToResult() {
        showOverlay(title: completionTitle, actions: completionActions, results: true)
    }

    func showReplay(document: Data, solution: Bool = false) {
        do {
            if solution, retainedSolution != nil { selectSolutionMode(.solution); return }
            guard let replay = try session.makeReplaySession(document: document) else { return }
            let player = MobileGameViewController(summary: summary, session: replay,
                checkpointStore: checkpointStore, restoredCheckpoint: nil, turn: turn, settingsProfileID: settingsProfileID)
            player.musicContext = musicContext
            if solution {
                if let classic = session as? ClassicMobileSession {
                    let verifiedReplay = try JSONDecoder().decode(ClassicDOSReplay.self, from: document)
                    _ = classic.installGhostSolution(verifiedReplay)
                }
                retainedSolution = player
                player.solutionGame = self
                selectSolutionMode(.solution)
                return
            }
            pausePlay(showControls: false)
            player.modalPresentationStyle = .fullScreen
            present(player, animated: false)
        } catch {
            showOverlay(title: error.localizedDescription,
                actions: [("BACK", { [weak self] in self?.pausePlay(showControls: true) })])
        }
    }

    func selectSolutionMode(_ mode: SolutionReplayMode) {
        if solutionGame != nil {
            if mode == .game { returnToSolutionGame() }
            return
        }
        guard mode == .solution, let replay = retainedSolution, presentedViewController == nil else { return }
        solutionReturnReady = playState.phase == .ready
        pausePlay(showControls: false)
        if solutionReturnReady { playState = MobilePlayState() }
        inputAdapter.reset()
        solutionSelector.resetActivation()
        replay.loadViewIfNeeded()
        replay.pausePlay(showControls: true)
        replay.inputAdapter.reset()
        replay.solutionSelector.resetActivation()
        replay.modalPresentationStyle = .fullScreen
        present(replay, animated: false)
        view.setNeedsLayout()
    }

    func inheritSolution(from previous: MobileGameViewController) {
        guard let replay = previous.retainedSolution,
              session.engineIdentifier == previous.session.engineIdentifier,
              session.levelIdentifier == previous.session.levelIdentifier,
              session.levelFingerprint == previous.session.levelFingerprint,
              soloOwnerID == previous.soloOwnerID,
              turn?.owner == previous.turn?.owner, turn?.scope == previous.turn?.scope else { return }
        previous.retainedSolution = nil
        retainedSolution = replay
        if let classic = session as? ClassicMobileSession, let previousClassic = previous.session as? ClassicMobileSession {
            classic.inheritGhostSolution(from: previousClassic)
        }
        replay.solutionGame = self
        replay.pausePlay(showControls: false)
        replay.gameSettings = gameSettings
        replay.musicContext = musicContext
        replay.inputAdapter.reset()
        replay.solutionSelector.resetActivation()
    }

    private func returnToSolutionGame() {
        guard let game = solutionGame else { return }
        pausePlay(showControls: false)
        inputAdapter.reset()
        solutionSelector.resetActivation()
        dismiss(animated: false) { [weak game] in
            guard let game else { return }
            game.inputAdapter.reset()
            game.solutionSelector.resetActivation()
            if game.solutionReturnReady {
                game.playState = MobilePlayState()
                game.showOverlay(title: game.summary.title, actions: [
                    (game.turn == nil ? "START" : "READY", { [weak game] in game?.resumePlay() }),
                    ("LIBRARY", { [weak game] in game?.leaveToLibrary() }),
                ])
            } else { game.pausePlay(showControls: true) }
            game.view.setNeedsLayout()
        }
    }

    func toggleGhostSolution() {
        guard solutionGame == nil, let classic = session as? ClassicMobileSession, classic.hasGhostSolution else { return }
        classic.ghostSolutionEnabled.toggle()
        solutionSelector.ghostEnabled = classic.ghostSolutionEnabled
        renderCurrentFrame(force: true)
    }

    private func layoutSolutionSelector() {
        solutionSelector.isHidden = !hasSolutionPair
        guard hasSolutionPair else { return }
        let region = MobileSystemRegions.menuFrame(in: view)
        #if os(tvOS)
        let scale: CGFloat = 2
        #else
        let scale: CGFloat = 1
        #endif
        let width = min(region.width - 16, SolutionSwitchArt.size.width * scale)
        let classic = session as? ClassicMobileSession
        solutionSelector.showsGhost = solutionGame == nil && classic?.hasGhostSolution == true
        solutionSelector.ghostEnabled = classic?.ghostSolutionEnabled == true
        let height: CGFloat = solutionSelector.showsGhost ? 100 : 48
        solutionSelector.frame = CGRect(x: region.midX - width / 2, y: region.minY + 8, width: width, height: height * scale)
        solutionSelector.bounds.size = CGSize(width: width / scale, height: height)
        solutionSelector.mode = solutionGame == nil ? .game : .solution
        playfieldView.blockedInputFrames.append(playfieldView.convert(solutionSelector.frame, from: view))
        view.bringSubviewToFront(solutionSelector)
    }

    private func layoutReplayMoves() {
        #if os(tvOS)
        replayMoves.isHidden = true
        #else
        replayMoves.isHidden = !session.isReadOnly || !overlay.isHidden || session.replayMoveNavigation.ticks.isEmpty
        guard !replayMoves.isHidden else { return }
        let area = playfieldView.frame
        let width = min(384, area.width - 16)
        let height = ReplayMoveArt.height(width: width)
        replayMoves.frame = CGRect(x: area.midX - width / 2, y: area.maxY - height - 8, width: width, height: height)
        replayMoves.update(previous: session.replayMoveNavigation.target(from: session.snapshot.tick, direction: -1) != nil,
            next: session.replayMoveNavigation.target(from: session.snapshot.tick, direction: 1) != nil)
        playfieldView.blockedInputFrames.append(playfieldView.convert(replayMoves.frame, from: view))
        view.bringSubviewToFront(replayMoves)
        #endif
    }

    func seekSolutionMove(_ direction: Int, showPlayfield: Bool = false) {
        guard session.isReadOnly, let tick = session.replayMoveNavigation.target(from: session.snapshot.tick, direction: direction) else { return }
        pausePlay(showControls: false)
        guard session.seekReplay(to: tick) else { pausePlay(showControls: true); return }
        completionPresented = false
        renderCurrentFrame(force: true)
        if showPlayfield {
            overlay.isHidden = true; overlay.accessibilityViewIsModal = false
            playfieldView.isUserInteractionEnabled = true; hud.isUserInteractionEnabled = true
            playfieldView.accessibilityElementsHidden = false; hud.accessibilityElementsHidden = false
            inputAdapter.reset()
            view.setNeedsLayout()
        } else { pausePlay(showControls: true) }
    }

    func resumeSelectedView() {
        if session.isReadOnly, session.snapshot.isComplete {
            _ = session.rewind(seconds: Double(session.snapshot.tick) / session.ticksPerSecond)
            completionPresented = false
        }
        resumePlay()
    }

    func setRewindHeld(_ held: Bool) {
        guard held != rewindHeld else { return }
        if held {
            guard session.supportsRewind, overlay.isHidden, playState.canEdit,
                  lifecycle.isForeground, !lifecycle.isInterrupted else { return }
            pauseForPlanning()
            #if os(tvOS)
            tvTargetLock.clear()
            #endif
            highlightedTarget = nil; previewPoint = nil
            if session.rewind(seconds: 2) { MobileMusic.shared.playRewind() }
            lastRewindTime = ProcessInfo.processInfo.systemUptime
            renderCurrentFrame(force: true)
        }
        rewindHeld = held
        MobileMusic.shared.setGameplayState(paused: paused, speed: speed, rewinding: held)
        if !held { saveCheckpoint(reason: .periodic) }
        updateHUD()
    }

    func showPreparationError(_ message: String) {
        resetTransition()
        showOverlay(title: message, actions: [("LIBRARY", { [weak self] in MobileMusic.shared.stop(); self?.onExit?(.library) })])
    }

    private func pauseSummary() -> MobilePauseSummary {
        let music = MobileMusic.shared
        let c = gameSettings.classic
        let musicState = !music.isEnabled ? "Music off" : c.musicVolume == 0 ? "Music muted"
            : lifecycle.isInterrupted || !lifecycle.isForeground ? "Audio suspended"
            : c.pauseMusicBeatOnly ? "Music: beat only" : "Music paused"
        let soundState = c.sound == .silent ? "SFX off" : c.soundVolume == 0 ? "SFX muted" : "SFX \(Int(c.soundVolume * 100))%"
        return MobilePauseSummary(level: summary, snapshot: session.snapshot,
            activeCount: session.activeLemmingCount, ticksPerSecond: session.ticksPerSecond,
            speed: speed, assignedSkills: session.assignedSkillCount, supportsRewind: session.supportsRewind,
            usedRewind: session.usedRewind, isReplay: session.isReadOnly,
            soundtrack: music.currentSoundtrackName ?? music.soundtrack,
            track: music.currentTrackTitle, audio: musicState + "   /   " + soundState)
    }

    func showOverlay(title: String, actions: [(String, () -> Void)], results: Bool = false) {
        replayMoves.isHidden = true
        cancelPendingL3ToolDirection()
        playfieldView.suspendVisualEffects()
        selectionFade.reset()
        playfieldView.selectionSprite = nil
        hud.cancelHeldControls()
        nowPlaying.hide()
        achievementTask?.cancel(); achievementTask = nil
        if !results { celebrationTask?.cancel(); celebrationTask = nil }
        overlayCanvas.resultStars = results ? onResultAwards?().stars : nil
        overlayCanvas.onAction = { [weak self] id in
            guard let self, let index = Int(id), self.overlayActions.indices.contains(index) else { return }
            self.overlayActions[index]()
        }
        overlayActions = actions.map { $0.1 }
        let snapshot = session.snapshot
        let ready = playState.phase == .ready
        let completed = results
        overlayCanvas.playerRole = completed ? .result : ready ? .next : .current
        let details: [String]
        if ready {
            details = ["\(snapshot.total) Lemmings   Save \(snapshot.required)",
                       snapshot.remainingSeconds.map { "Time \($0 / 60):\(String(format: "%02d", $0 % 60))" } ?? "No time limit"]
        } else if completed {
            let awards = Set(resultAchievements.map(\.title))
            let elapsed = Double(snapshot.tick) / session.ticksPerSecond
            let time = "\(Int(elapsed) / 60):\(String(format: "%05.2f", elapsed.truncatingRemainder(dividingBy: 60)))"
            let recordTime = completionDetails.first { $0.hasPrefix("New time record") }
            details = ["Saved \(snapshot.saved)/\(snapshot.total)   Goal \(snapshot.required)", recordTime ?? "Time " + time]
                + completionDetails.filter { !awards.contains($0) && !$0.hasPrefix("New time record") }
        } else { details = [] }
        let heading = completed ? (snapshot.didWin ? "Level complete" : "Try again") : (ready ? (turn?.ownerName ?? title) : title)
        let subtitle = summary.caption
        let wasHidden = overlay.isHidden
        overlayCanvas.page = .init(title: heading, subtitle: subtitle,
                                   details: (ready && turn == nil ? [] : [summary.title]) + details,
                                   footer: actions.enumerated().map { .init(String($0.offset), $0.element.0, primary: $0.offset == 0) },
                                   preview: ready || completed)
        if !(ready && turn == nil) && !completed { overlayCanvas.page.detailTitles = [0] }
        overlayCanvas.page.result = completed
        if completed {
            overlayCanvas.page.detailHeadings = [0]
            rotateResultAchievements()
        }
        let isPause = !ready && !completed && title.uppercased() == "PAUSED"
        if isPause {
            overlayCanvas.page = MobilePauseArt.page(pauseSummary(), actions: overlayCanvas.page.footer)
        }
        overlay.bounces = !isPause
        #if os(tvOS)
        // The overview has one Back target, so arrows scroll its noninteractive
        // statistics directly. Action menus retain normal directional focus.
        overlay.directionalPressGestureRecognizer.isEnabled = isPause && actions.count == 1
        overlay.panGestureRecognizer.isEnabled = isPause && actions.count == 1
        #endif
        overlay.setContentOffset(.zero, animated: false)
        if let frame = latestFrame {
            overlayCanvas.preview = MobileBitmapRenderer.image(frame)
            let visible = playfieldView.gameViewport.visibleLevelRect
            overlayCanvas.previewSource = CGRect(x: visible.x * session.renderScale, y: visible.y * session.renderScale, width: visible.width * session.renderScale, height: visible.height * session.renderScale)
        }
        overlay.isHidden = false
        overlay.accessibilityViewIsModal = !hasSolutionPair
        playfieldView.isUserInteractionEnabled = false
        hud.isUserInteractionEnabled = false
        playfieldView.accessibilityElementsHidden = true
        hud.accessibilityElementsHidden = true
        layoutOverlay()
        if isPause && wasHidden && !UIAccessibility.isReduceMotionEnabled
            && !gameSettings.classic.reduceMotion && !gameSettings.classic.reduceFlashes {
            overlay.layer.removeAllAnimations()
            overlay.alpha = 0
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
                self.overlay.alpha = 1
            }
        } else {
            overlay.layer.removeAllAnimations()
            overlay.alpha = 1
        }
        #if os(tvOS)
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        #endif
        UIAccessibility.post(notification: .screenChanged, argument: overlayCanvas)
    }

    func showCustomOverlay(title: String, details: [String], actions: [(String, () -> Void)]) {
        showOverlay(title: title, actions: actions)
        overlayCanvas.page = .init(title: title, details: details,
            footer: actions.enumerated().map { .init(String($0.offset), $0.element.0, primary: $0.offset == 0) })
        layoutOverlay()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === overlay, overlayCanvas.page.pause != nil { overlayCanvas.setNeedsLayout() }
    }

    private func layoutOverlay() {
        guard !overlay.isHidden else { return }
        var region = MobileSystemRegions.menuFrame(in: view)
        if hasSolutionPair {
            layoutSolutionSelector()
            let top = solutionSelector.frame.maxY + 8
            region.size.height = max(44, region.maxY - top)
            region.origin.y = top
        }
        overlay.frame = region
        let size = overlayCanvas.size(width: max(280, region.width), minimumHeight: region.height)
        overlayCanvas.frame = CGRect(origin: .zero, size: size)
        overlay.contentSize = size
    }

    private static func cgRect(_ rect: MobileRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }
}
#endif
