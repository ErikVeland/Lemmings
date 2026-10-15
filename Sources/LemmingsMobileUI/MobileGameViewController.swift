#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsAudio
import NxlvKit
import LemmingsGameArt
import LemmingsMobileCore
import LemmingsTVCore
import UIKit
import GameController

@MainActor enum MobileGameExitAction {
    case library
    case menu
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

#if os(tvOS)
typealias MobileGameControllerBase = GCEventViewController
@MainActor final class MobileGameOverlay: UIScrollView {
    var onVisibilityChanged: (() -> Void)?
    override var isHidden: Bool { didSet { if oldValue != isHidden { onVisibilityChanged?() } } }
}
#else
typealias MobileGameControllerBase = UIViewController
typealias MobileGameOverlay = UIScrollView
#endif

@MainActor final class MobileGameViewController: MobileGameControllerBase, UIScrollViewDelegate {
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
            if let award = TrolleyAchievement.allCases.first(where: { $0.title == title }) { return (title, ResultAwards.explanation(for: award)) }
            if let award = ClassicAchievement.catalog.first(where: { $0.title == title }) { return (title, award.detail) }
            if title == L10n.text("New rescue record") { return (title, L10n.text("Your best rescue count on this level.")) }
            if title == L10n.text("New skill record") { return (title, L10n.text("Your fewest skills used to complete this level.")) }
            if title == L10n.text("Level skip earned") { return (title, L10n.text("A level skip is now available for a later attempt.")) }
            return nil
        }
    }

    private func showResultAchievement() {
        let awards = resultAchievements
        guard !awards.isEmpty else { return }
        achievementIndex %= awards.count
        let award = awards[achievementIndex]
        var actions: [(String, () -> Void)] = [(L10n.text("BACK"), { [weak self] in self?.returnToResult() })]
        if awards.count > 1 {
            actions.append((L10n.text("NEXT AWARD"), { [weak self] in
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
            overlayCanvas.actionHelp = ["resultAward": awards[achievementIndex].detail]
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
                guard self.overlayCanvas.hoveredActionID != "resultAward" else { continue }
                self.achievementIndex = (self.achievementIndex + 1) % awards.count
                self.overlayCanvas.actionHelp = ["resultAward": awards[self.achievementIndex].detail]
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
    private let playerProfile: MobileProfile

    let playfieldView: MobilePlayfieldView
    let hud = MobileHUDView()
    private let touchLoupe = MobileTouchLoupe()
    let overlay = MobileGameOverlay()
    let overlayCanvas = MobileMenuCanvas()
    private var overlayActions: [() -> Void] = []
    private var latestFrame: MobilePixelFrame?

    private var lastHUDLayout: MobileHUDLayout?
    private var hudArtworkSource: ClassicGraphicsSource?
    private var playfieldAccessibilityActionNames: [String]?
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
    private var leaveRequestID = UUID()
    var playState = MobilePlayState()
    var paused: Bool { playState.isPaused }
    var speed = 1.0
    var fastSpeed = 2.0
    var controllerSpeedResetConsumed = false
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
    private var controllerHUDPending = false
    private var controllerCheckpointPending = false
    private var lastCheckpointTick = -1
    private var endRunArmedUntil = 0.0
    var isChoosingToolDirection: Bool { pendingL3Use != nil }
    #if os(tvOS)
    private var tvControllerBackPress = false
    var tvPointerPoint: CGPoint?
    let tvPointerView = MobileTVPointerView()
    var tvCameraMode = false
    var tvTargetLock = TVTargetLock()
    override var preferredFocusEnvironments: [any UIFocusEnvironment] {
        if !solutionSelector.isHidden, solutionSelector.focusedIndex != nil { return [solutionSelector] }
        if !overlay.isHidden { return [overlayCanvas] }
        return isChoosingToolDirection ? [hud] : [playfieldView]
    }
    #endif
    private var pendingL3Use: (target: Int, control: Int, selection: MobileTargetSelection)? {
        didSet {
            #if os(tvOS)
            if isViewLoaded { updateTVInputRouting() }
            #endif
        }
    }
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
    private var solutionPanelContentFrame: CGRect?
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
        let profiles = MobileStorage.standard(profile: "_players").load(MobileProfiles.self, name: "players") ?? MobileProfiles()
        playerProfile = profiles.players.first { $0.id == settingsProfileID } ?? profiles.active
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
        #if os(tvOS)
        overlay.onVisibilityChanged = { [weak self] in self?.updateTVInputRouting() }
        updateTVInputRouting()
        #endif
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
        hud.playerName = turn?.ownerName ?? playerProfile.name
        hud.playerPortrait = MobileGameArt.portraits?.image(turn?.ownerPortrait ?? playerProfile.portrait)
        overlayCanvas.playerName = turn?.ownerName ?? playerProfile.name
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
        #if os(tvOS)
        tvPointerView.isUserInteractionEnabled = false
        view.addSubview(tvPointerView)
        #endif
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
                (session.isReadOnly ? L10n.text("PLAY") : (turn == nil ? L10n.text("START") : L10n.text("READY")), { [weak self] in self?.resumePlay() }),
                (session.isReadOnly ? L10n.text("BACK") : L10n.text("LIBRARY"), { [weak self] in self?.leaveToLibrary() }),
            ]
        )

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
        #if os(tvOS)
        updateTVInputRouting()
        #endif
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        #if os(tvOS)
        if presses.contains(where: { $0.type == .playPause }) {
            if !controllerUserInteractionEnabled { return }
            if GCController.controllers().contains(where: { $0.microGamepad?.buttonX.isPressed == true }) { return }
            if overlay.isHidden { handle(.pause) }
            else if overlayCanvas.page.pause != nil { resumeSelectedView() }
            return
        }
        if presses.contains(where: { $0.type == .menu }) {
            if !controllerUserInteractionEnabled {
                tvControllerBackPress = true
                return
            }
            // tvOS also delivers Circle as a native Back press. Gameplay polling owns it.
            if overlay.isHidden, GCController.controllers().contains(where: { $0.extendedGamepad?.buttonB.isPressed == true }) {
                tvControllerBackPress = true
                return
            }
            if GCController.controllers().contains(where: { $0.extendedGamepad?.buttonMenu.isPressed == true || $0.microGamepad?.buttonMenu.isPressed == true }) {
                tvControllerBackPress = true
                return
            }
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
        #if os(tvOS)
        if tvControllerBackPress, presses.contains(where: { $0.type == .menu }) {
            tvControllerBackPress = false
            let remaining = presses.filter { $0.type != .menu }
            if !remaining.isEmpty { super.pressesEnded(remaining, with: event) }
            return
        }
        #endif
        let handled = inputAdapter.ended(presses)
        super.pressesEnded(presses.subtracting(handled), with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        #if os(tvOS)
        tvControllerBackPress = false
        // Game Controller owns gameplay buttons and their release events.
        if overlay.isHidden && !isChoosingToolDirection && presses.allSatisfy({ $0.key == nil }) { return }
        #endif
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
            print(L10n.text("[MobileHUD] mode=\(mode) bounds=\(view.bounds) safeInsets=\(insets) controls=\(layout.interface.controlsFrame) reserved=\(layout.reservedRegions)"))
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
                showOverlay(title: L10n.text("Paused"), actions: [(L10n.text("LIBRARY"), { [weak self] in self?.leaveToLibrary() })], pauseOverview: true)
            }
        } else if layoutSuspended {
            layoutSuspended = false
            showOverlay(title: L10n.text("Paused"), actions: [
                (L10n.text("RESUME"), { [weak self] in self?.resumePlay() }),
                (L10n.text("LIBRARY"), { [weak self] in self?.leaveToLibrary() }),
            ], pauseOverview: true)
        }
        playfieldView.frame = Self.cgRect(layout.interface.playfieldFrame)
        playfieldView.blockedInputFrames = layout.reservedRegions.map { playfieldView.convert(Self.cgRect($0.frame), from: view) }
        layoutSolutionSelector()
        layoutReplayMoves()
        replayTitle.position(in: playfieldView.frame)
        if !solutionSelector.isHidden { replayTitle.frame.origin.y = max(replayTitle.frame.minY, solutionSelector.frame.maxY + 8) }
        if session.isReadOnly, layout.portrait != nil { replayTitle.frame.origin.y += 48 }
        countdownLabel.frame = CGRect(x: playfieldView.frame.midX - 44, y: playfieldView.frame.midY - 44, width: 88, height: 88)
        let replayWidth = min(MobileReplaySkillArt.size.width, max(0, playfieldView.frame.width - 16))
        replaySkillInfo.frame = CGRect(x: playfieldView.frame.maxX - replayWidth - 8, y: session.isReadOnly ? replayTitle.frame.maxY + 8 : playfieldView.frame.minY + (layout.portrait != nil ? 56 : 8),
            width: replayWidth, height: replayWidth * MobileReplaySkillArt.size.height / MobileReplaySkillArt.size.width)
        var musicArea = playfieldView.frame
        if session.isReadOnly || hasSolutionPair {
            let top = min(musicArea.maxY, max(musicArea.minY, replayTitle.frame.maxY + 8))
            musicArea.size.height = musicArea.maxY - top
            musicArea.origin.y = top
        }
        if session.isReadOnly {
            musicArea.size.width = max(0, replaySkillInfo.frame.minX - musicArea.minX - 8)
        }
        nowPlaying.position(in: musicArea)
        hud.frame = view.bounds
        updateHUD(layout: layout)
        overlay.frame = view.bounds
        layoutOverlay()
        if previewPoint != nil { renderCurrentFrame(force: true) }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        #if os(tvOS)
        inputAdapter.reset()
        controllerUserInteractionEnabled = true
        #endif
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
        #if os(tvOS)
        updateTVInputRouting()
        #endif
        let frameStarted = ProcessInfo.processInfo.systemUptime
        defer {
            #if os(tvOS)
            pollingController = false
            playfieldView.deferFrameUpdates = false
            #endif
            flushControllerFrameUpdates()
            MobileDevicePerformance.recordCPU(ProcessInfo.processInfo.systemUptime - frameStarted, source: "frame")
            framePacing.observe(at: link.timestamp, cpuSeconds: MobileDevicePerformance.cpuFrameCost,
                gpuSeconds: MobileDevicePerformance.gpuFrameCost,
                active: !paused && !countdown.isActive && overlay.isHidden && lifecycle.isForeground && !lifecycle.isInterrupted)
            if framePacing.framesPerSecond != appliedFrameRate { updatePerformanceBudget() }
        }
        pollingController = true
        playfieldView.deferFrameUpdates = true
        inputAdapter.poll(context: ObjectIdentifier(overlay.isHidden ? playfieldView : overlayCanvas), at: link.timestamp)
        #if !os(tvOS)
        pollingController = false
        playfieldView.deferFrameUpdates = false
        #endif
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
        #if os(tvOS)
        if !countdown.isActive { advanceTVPointerScrolling(seconds: elapsed) }
        #endif
        if countdown.isActive {
            _ = countdown.advance(seconds: elapsed, visible: overlay.isHidden && lifecycle.isForeground && !lifecycle.isInterrupted && !paused)
            countdownLabel.text = countdown.number.map(String.init) ?? ""
            countdownLabel.isHidden = !countdown.isActive
            clock.suspend()
            if countdown.isActive { return }
        }
        MobileMusic.shared.setGameplayState(paused: paused, speed: speed, rewinding: rewindHeld)
        var snapshot = session.snapshot
        if session.isReadOnly {
            replaySkillInfo.update(session.replaySkillUses, tick: snapshot.tick, visible: overlay.isHidden)
            replayMoves.update(previous: session.replayMoveNavigation.target(from: snapshot.tick, direction: -1) != nil,
                next: session.replayMoveNavigation.target(from: snapshot.tick, direction: 1) != nil)
        }
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
        guard !paused, !snapshot.isComplete else { return }
        let ticks = clock.advance(at: link.timestamp)
        guard ticks > 0 else { return }
        let deadline = frameStarted + min(0.012, 0.6 / Double(max(1, appliedFrameRate)))
        var advanced = 0
        for _ in 0..<ticks {
            session.tick(); advanced += 1
            snapshot = session.snapshot
            if snapshot.isComplete || ProcessInfo.processInfo.systemUptime >= deadline { break }
        }
        if !snapshot.isComplete { clock.deferTicks(ticks - advanced) }
        // Catch-up ticks accumulate cues; spatial placement and scheduling run once per frame.
        effects.update(session: session, viewport: playfieldView.gameViewport)
        let candidates = renderCurrentFrame(force: true)
        updateHUD(snapshot: snapshot, candidates: candidates)
        if snapshot.isComplete {
            presentCompletion()
        } else if snapshot.tick - lastCheckpointTick >= Int(ceil(session.ticksPerSecond * 5)) {
            saveCheckpoint(reason: .periodic)
        }
    }

    private func hudLayout(insets: UIEdgeInsets) -> MobileHUDLayout {
        #if os(tvOS)
        let showsMenuButton = false
        let television = true
        #else
        let showsMenuButton = true
        let television = false
        #endif
        return MobileHUDLayout.make(
            container: MobileSize(width: view.bounds.width, height: view.bounds.height),
            safeArea: MobileInsets(top: insets.top, left: insets.left, bottom: insets.bottom, right: insets.right),
            hasRate: session.snapshot.releaseRate != nil,
            skillCount: session.snapshot.skills.count,
            reservedRegions: MobileSystemRegions.read(in: view),
            supportsRewind: session.supportsRewind,
            hasPlayer: true,
            engineIdentifier: session.engineIdentifier,
            showsMenuButton: showsMenuButton, television: television
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
            #if os(tvOS)
            renderCurrentFrame(force: true)
            #endif
        case .pause:
            if speed > 1 || inputSpeed.isHeld {
                inputSpeed.reset(at: ProcessInfo.processInfo.systemUptime)
                updateInputSpeed(at: ProcessInfo.processInfo.systemUptime)
                #if !os(tvOS)
                return
                #endif
            }
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
            if rewound {
                MobileMusic.shared.playRewind()
                effects.update(session: session, viewport: playfieldView.gameViewport, rewinding: true)
            }
            clock.suspend()
            highlightedTarget = nil
            #if os(tvOS)
            tvTargetLock.clear()
            ensureTVPointer()
            #else
            previewPoint = nil
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
        if session.snapshot.isComplete, !session.isReadOnly { presentCompletion() }
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
        #if os(tvOS)
        if let retained = TVTargetLock.retain(highlightedTarget, at: point, candidates: candidates, viewport: playfieldView.gameViewport) { return retained }
        let favourApproaching = false
        #else
        let favourApproaching = settings.favorApproachingLemmings
        #endif
        return MobileTargetSelector.select(
            candidates: candidates,
            touch: point,
            viewport: playfieldView.gameViewport,
            radius: 30,
            preference: preference,
            favourApproaching: favourApproaching,
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

    @discardableResult func renderCurrentFrame(force: Bool) -> [MobileTargetCandidate]? {
        #if os(tvOS)
        ensureTVPointer()
        updateTVPointer()
        #endif
        if pollingController { controllerRenderPending = controllerRenderPending || force; return nil }
        let snapshot = session.snapshot
        let tick = snapshot.tick
        guard force || tick != lastRenderedTick else { return nil }
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
                // The actor highlight follows the lock. The reticule stays at the input position.
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
            #if os(tvOS)
            updateTVPointer()
            #endif
            playfieldView.cursorPoint = previewPoint.map { playfieldView.gameViewport.levelPoint(fromView: $0) }
            playfieldView.cursorIcon = hudArtworkSource == gameSettings.classic.graphics && hud.skillIcons.indices.contains(selectedControl)
                ? hud.skillIcons[selectedControl] : session.skillCursorFrame(control: selectedControl).flatMap(MobileBitmapRenderer.image)
            let cursorSkill = snapshot.skills.indices.contains(selectedControl) ? snapshot.skills[selectedControl] : nil
            playfieldView.cursorSkillName = cursorSkill?.name ?? ""
            if fanMode { playfieldView.cursorIcon = nil; playfieldView.cursorSkillName = L10n.text("Fan") }
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
            playfieldView.assignmentSprite = session.assignmentSprite
            playfieldView.assignmentProgress = session.assignmentProgress
            playfieldView.setRescueFeedback(saved: snapshot.saved, required: snapshot.required, total: snapshot.total,
                isComplete: snapshot.isComplete, didWin: snapshot.didWin)
            playfieldView.failed = snapshot.isComplete ? !snapshot.didWin : (snapshot.saved + session.activeLemmingCount + max(0, snapshot.total - snapshot.released) < snapshot.required)
            try playfieldView.update(frame: frame)
            if !overlay.isHidden, overlayCanvas.page.preview {
                overlayCanvas.preview = playfieldView.bitmap
                let visible = playfieldView.gameViewport.visibleLevelRect
                overlayCanvas.previewSource = CGRect(x: visible.x * session.renderScale, y: visible.y * session.renderScale, width: visible.width * session.renderScale, height: visible.height * session.renderScale)
            }
            hud.updateMinimap(frame: frame, visible: playfieldView.gameViewport.visibleLevelRect,
                              levelSize: session.levelSize, image: playfieldView.bitmap)
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
            return needsCandidates ? candidates : nil
        } catch {
            pausePlay(showControls: false)
            showOverlay(
                title: error.localizedDescription,
                actions: [(L10n.text("LIBRARY"), { [weak self] in self?.leaveToLibrary() })]
            )
            return nil
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
        #if !os(tvOS)
        previewPoint = nil
        #endif
        highlightedTarget = nil
        touchLoupe.isHidden = true
        clock.suspend()
        pauseGameplayAudio()
        updateHUD()
        guard showControls else { return }
        if session.snapshot.isComplete, !session.isReadOnly {
            if completionPresented { returnToResult() }
            else { presentCompletion() }
            return
        }
        if playState.phase == .ready {
            showOverlay(title: summary.title, actions: [
                (session.isReadOnly ? L10n.text("PLAY") : turn == nil ? L10n.text("START") : L10n.text("READY"), { [weak self] in self?.resumePlay() }),
                (L10n.text("BACK"), { [weak self] in self?.leaveToLibrary() }),
            ])
            return
        }
        #if os(tvOS)
        tvCameraMode = false
        showOverlay(title: L10n.text("PAUSED"), actions: [
            (session.isReadOnly ? (session.snapshot.isComplete ? L10n.text("REPLAY") : L10n.text("PLAY")) : L10n.text("RESUME"), { [weak self] in self?.resumeSelectedView() }),
            (session.isReadOnly ? L10n.text("BACK") : L10n.text("LIBRARY"), { [weak self] in self?.leaveToLibrary() }),
        ] + (session.isReadOnly ? [] : [
            (L10n.text("RESTART LEVEL"), { [weak self] in self?.showRestartLevel() }),
        ]) + [(L10n.text("GAME CONTROLS"), { [weak self] in self?.showTVControls() })], pauseOverview: true)
        #else
        showOverlay(
            title: L10n.text("PAUSED"),
            actions: [
                (session.isReadOnly ? (session.snapshot.isComplete ? L10n.text("REPLAY") : L10n.text("PLAY")) : L10n.text("RESUME"), { [weak self] in self?.resumeSelectedView() }),
                (session.isReadOnly ? L10n.text("BACK") : L10n.text("LIBRARY"), { [weak self] in self?.leaveToLibrary() }),
            ] + (session.isReadOnly ? [] : [
                (L10n.text("RESTART LEVEL"), { [weak self] in self?.showRestartLevel() }),
                (L10n.text("GAME CONTROLS"), { [weak self] in self?.showPauseTools() }),
            ]),
            pauseOverview: true
        )
        #endif
        let settingsAction = overlayActions.count
        overlayActions.append { [weak self] in self?.showInGameSettings() }
        overlayCanvas.page.footer.append(.init(String(settingsAction), L10n.text("SETTINGS")))
        layoutOverlay()
        if session.isReadOnly, !session.replayMoveNavigation.ticks.isEmpty {
            let previous = overlayActions.count
            overlayActions += [{ [weak self] in self?.seekSolutionMove(-1) }, { [weak self] in self?.seekSolutionMove(1) }]
            overlayCanvas.page.footer += [
                .init(String(previous), L10n.text("PREVIOUS MOVE"), enabled: session.replayMoveNavigation.target(from: session.snapshot.tick, direction: -1) != nil),
                .init(String(previous + 1), L10n.text("NEXT MOVE"), enabled: session.replayMoveNavigation.target(from: session.snapshot.tick, direction: 1) != nil),
            ]
        }
    }

    private func showPauseTools() {
        var actions: [(String, () -> Void)] = [
            (L10n.text("BACK"), { [weak self] in self?.pausePlay(showControls: true) }),
            (L10n.text("HINT"), { [weak self] in self?.onHints?() }),
            (L10n.text("CONTROLS HELP"), { [weak self] in self?.onControlsHelp?() }),
            (L10n.text("SETTINGS"), { [weak self] in self?.showInGameSettings() }),
        ]
        if session is Lemmings2MobileSession {
            actions.append((fanMode ? L10n.text("SKILL MODE") : L10n.text("FAN"), { [weak self] in
                guard let self else { return }
                self.fanMode.toggle()
                self.resumePlay()
            }))
        }
        showCustomOverlay(title: L10n.text("Game controls"), details: [], actions: actions)
        overlayCanvas.page.footerColumns = 1
    }

    func showRestartLevel() {
        guard !session.isReadOnly else { return }
        pausePlay(showControls: false)
        showCustomOverlay(title: L10n.text("Restart level?"), details: [summary.locationLabel, summary.title], actions: [
            (L10n.text("CANCEL"), { [weak self] in self?.pausePlay(showControls: true) }),
            (L10n.text("RESTART LEVEL"), { [weak self] in self?.finish(.retry) }),
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
        // Controller aiming keeps its current position while the game is paused.
        if hoverAimActive { restoreHoverAim() }
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
            showOverlay(title: L10n.text("Skill selection"), actions: [
                (L10n.text("Turn off"), { [weak self] in self?.chooseSkillSelectionPause(false) }),
                (L10n.text("Keep pausing"), { [weak self] in self?.chooseSkillSelectionPause(true) }),
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
        layoutSolutionSelector()
        overlay.accessibilityViewIsModal = false
        playfieldView.isUserInteractionEnabled = true
        hud.isUserInteractionEnabled = true
        playfieldView.accessibilityElementsHidden = false
        hud.accessibilityElementsHidden = false
        updateHUD()
        #if os(tvOS)
        renderCurrentFrame(force: true)
        #endif
        UIAccessibility.post(notification: .announcement, argument: L10n.text("Game resumed"))
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
            ? L10n.text("LEVEL COMPLETE\n\(snapshot.saved) SAVED")
            : L10n.text("LEVEL ENDED\n\(snapshot.saved) SAVED")
        var actions: [(String, () -> Void)]
        if let turn {
            actions = turn.choices(snapshot.didWin).map { entry in
                (entry.label, { [weak self] in
                    self?.finish(entry.choice.kind == .next ? .next : .retry, handingTo: entry.choice.player)
                })
            }
            // The level is over, so the turn passes by the house rule even when the player leaves.
            let following = turn.choices(snapshot.didWin).first(where: { $0.choice.primary })?.choice.player
            actions.append((L10n.text("BACK"), { [weak self] in self?.finish(.library, handingTo: following) }))
        } else if snapshot.didWin {
            actions = [
                (L10n.text("NEXT LEVEL"), { [weak self] in self?.finish(.next) }),
                (L10n.text("RETRY"), { [weak self] in self?.finish(.retry) }),
                (L10n.text("BACK"), { [weak self] in self?.finish(.library) }),
            ]
        } else {
            actions = [
                (L10n.text("RETRY"), { [weak self] in self?.finish(.retry) }),
                (L10n.text("BACK"), { [weak self] in self?.finish(.library) }),
            ]
        }
        if !snapshot.didWin, canDefer {
            actions.append((L10n.text("LATER"), { [weak self] in
                guard let self else { return }
                self.finish(.next, handingTo: self.turn?.choices(false).first?.choice.player)
            }))
        }
        if !snapshot.didWin, onSkipLevel != nil {
            actions.append((L10n.text("SKIP LEVEL"), { [weak self] in
                guard let self, !self.transitionInFlight, self.onSkipLevel?() == true else { return }
                self.finish(.next, handingTo: self.turn?.choices(false).first?.choice.player)
            }))
        }
        if let data = try? session.replayDocument() {
            actions.append((L10n.text("REVIEW"), { [weak self] in self?.showReplay(document: data) }))
            actions.append((L10n.text("SHARE MOVIE"), { [weak self] in self?.shareReplayMovie(document: data) }))
        }
        let following = turn?.choices(snapshot.didWin).first(where: { $0.choice.primary })?.choice.player
        actions.append((L10n.text("MENU"), { [weak self] in self?.finish(.menu, handingTo: following) }))
        completionTitle = result
        completionActions = actions
        if let recordSaveError {
            completionTitle = recordSaveError
            completionActions = [
                (L10n.text("TRY AGAIN"), { [weak self] in
                    guard let self else { return }
                    self.completionPresented = false
                    self.presentCompletion()
                }),
                (L10n.text("BACK"), { [weak self] in self?.finish(.library, handingTo: following) }),
                (L10n.text("MENU"), { [weak self] in self?.finish(.menu, handingTo: following) }),
            ]
            returnToResult()
            return
        }
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
        guard !transitionInFlight else { return }
        if recordSaveError != nil {
            if action == .library || action == .menu { leaveKeepingCheckpoint(action) }
            return
        }
        if action == .retry { MobileMusic.shared.vinylStop() }
        transitionInFlight = true
        celebrationTask?.cancel(); celebrationTask = nil
        displayLink?.isPaused = true
        suspendAudio()
        effects.stop()
        if action == .library || action == .menu { MobileMusic.shared.stop() }
        Task { [self] in
            do {
                await checkpointSaveTask?.value
                try await checkpointStore.retire(runID: runID)
                if let player, onHandover?(player) == false {
                    resetTransition()
                    showRecoveryOverlay(title: L10n.text("HOT SEAT WAS NOT SAVED")) { [weak self] in self?.finish(action, handingTo: player) }
                    return
                }
                onExit?(action)
            } catch {
                resetTransition()
                showRecoveryOverlay(title: L10n.text("RUN WAS NOT CLOSED")) { [weak self] in self?.finish(action, handingTo: player) }
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
        let request = UUID()
        leaveRequestID = request
        showOverlay(title: L10n.text("SAVING..."), actions: [(L10n.text("CANCEL"), { [weak self] in
            guard let self else { return }
            self.leaveRequestID = UUID()
            self.displayLink?.isPaused = false
            self.pausePlay(showControls: true)
        })])
        do {
            let encoding = try makeCheckpoint()
            let previousSave = checkpointSaveTask
            Task { [self] in
                do {
                    await previousSave?.value
                    let envelope = try await encoding.value
                    guard leaveRequestID == request else { return }
                    try await checkpointStore.save(envelope)
                    guard leaveRequestID == request else { return }
                    MobileMusic.shared.stop()
                    onExit?(.library)
                } catch {
                    guard leaveRequestID == request else { return }
                    showRecoveryOverlay(title: error.localizedDescription) { [weak self] in self?.leaveToLibrary() }
                }
            }
        } catch {
            showRecoveryOverlay(title: error.localizedDescription) { [weak self] in self?.leaveToLibrary() }
        }
    }

    private func saveCheckpoint(reason: MobileCheckpointReason) {
        guard !session.isReadOnly, !session.snapshot.isComplete else { return }
        #if os(tvOS)
        if reason == .periodic, pollingController { controllerCheckpointPending = true; return }
        #endif
        controllerCheckpointPending = false
        if reason == .periodic, checkpointSaveTask != nil { return }
        do {
            let encoding = try makeCheckpoint()
            let previousSave = checkpointSaveTask
            let generation = UUID()
            checkpointSaveGeneration = generation
            lastCheckpointTick = session.snapshot.tick
            let backgroundTask: UIBackgroundTaskIdentifier
            if reason == .suspension || reason == .sceneDisconnect || reason == .audioInterruption {
                backgroundTask = UIApplication.shared.beginBackgroundTask(withName: L10n.text("Save Lemmings run"))
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
        if event == .memoryWarning {
            MobileDevicePerformance.memoryWarning()
            updatePerformanceBudget()
            playfieldView.releaseEffectResources()
        }
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
        effects.setVoiceLimit(budget.audioVoiceLimit)
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

    func applyGameSettings(_ settings: MobileSettings) {
        applyPresentationSettings(settings)
        (retainedSolution ?? solutionGame)?.applyPresentationSettings(settings)
    }

    private func applyPresentationSettings(_ settings: MobileSettings) {
        gameSettings = settings
        session.applySettings(settings.classic)
        playfieldView.displaySettings = settings.classic
        hudArtworkSource = nil
        renderCurrentFrame(force: true)
        updateHUD()
        view.setNeedsLayout()
    }

    func flushControllerFrameUpdates() {
        let candidates = controllerRenderPending ? renderCurrentFrame(force: true) : nil
        if controllerHUDPending {
            controllerHUDPending = false
            updateHUD(candidates: candidates)
        }
        if controllerCheckpointPending {
            controllerCheckpointPending = false
            saveCheckpoint(reason: .periodic)
        }
    }

    func updateHUD(layout: MobileHUDLayout? = nil, snapshot: MobileGameSnapshot? = nil, candidates: [MobileTargetCandidate]? = nil) {
        #if os(tvOS)
        if pollingController { controllerHUDPending = true; return }
        #endif
        let snapshot = snapshot ?? session.snapshot
        MobileMusic.shared.update(snapshot, active: session.activeLemmingCount, nukeRemainingTicks: session.nukeRemainingTicks, allNukePopped: session.allNukeExplosionsPlayed, ticksPerSecond: session.ticksPerSecond)
        MobileMusic.shared.setGameplayState(paused: paused, speed: speed, rewinding: rewindHeld)
        let resolved = layout ?? lastHUDLayout ?? hudLayout(insets: view.safeAreaInsets)
        if hudArtworkSource != gameSettings.classic.graphics {
            hud.skillIcons = snapshot.skills.indices.map { session.skillCursorFrame(control: $0).flatMap(MobileBitmapRenderer.image) }
            hudArtworkSource = gameSettings.classic.graphics
        }
        hud.counterStyle = gameSettings.classic.counterStyle
        #if os(tvOS)
        hud.statusDetails = .init(lostCount: session.lostLemmingCount,
            deathCounter: FailureMoodDecision.deathCounter(saved: snapshot.saved,
                active: session.activeLemmingCount, unreleased: snapshot.total - snapshot.released,
                required: snapshot.required, total: snapshot.total,
                isComplete: snapshot.isComplete, didWin: snapshot.didWin))
        #endif
        hud.update(
            layout: resolved,
            snapshot: snapshot,
            selectedSkill: selectedControl,
            paused: paused,
            speed: speed,
            endRunArmed: endRunArmedUntil > ProcessInfo.processInfo.systemUptime,
            panel: session.panelFrame,
            readOnly: session.isReadOnly
        )
        updatePlayfieldAccessibility(snapshot: snapshot, candidates: candidates)
    }

    /** Keeps non-visual target selection and assignment available to assistive input. */
    private func updatePlayfieldAccessibility(snapshot: MobileGameSnapshot? = nil, candidates: [MobileTargetCandidate]? = nil) {
        let snapshot = snapshot ?? session.snapshot
        let candidates = (candidates ?? session.targetCandidates(for: selectedControl))
            .filter { $0.assignment == .eligible }
            .sorted { $0.id < $1.id }
        let skillName = snapshot.skills.indices.contains(selectedControl)
            ? SkillVocabulary.title(snapshot.skills[selectedControl].name) : L10n.text("selected skill")
        let selectedIndex = highlightedTarget.flatMap { selection in
            candidates.firstIndex { $0.id == selection.id }
        }
        if let selectedIndex {
            playfieldView.accessibilityValue = L10n.text("Eligible lemming \(selectedIndex + 1) of \(candidates.count). Skill: \(skillName).")
        } else {
            playfieldView.accessibilityValue = L10n.text("\(candidates.count) eligible lemmings. Skill: \(skillName).")
        }

        let canAssign = !session.isReadOnly && !snapshot.isComplete && playState.canEdit
            && highlightedTarget.map { selection in
                selection.state == .eligible && candidates.contains { $0.id == selection.id }
            } == true
        var actionNames = candidates.isEmpty ? [] : ["Previous eligible lemming", "Next eligible lemming"]
        if canAssign { actionNames.append("Assign \(skillName)") }
        guard actionNames != playfieldAccessibilityActionNames else { return }
        playfieldAccessibilityActionNames = actionNames
        var actions: [UIAccessibilityCustomAction] = []
        if !candidates.isEmpty {
            actions.append(UIAccessibilityCustomAction(name: L10n.text("Previous eligible lemming")) { [weak self] _ in
                self?.moveAccessibleTarget(-1) ?? false
            })
            actions.append(UIAccessibilityCustomAction(name: L10n.text("Next eligible lemming")) { [weak self] _ in
                self?.moveAccessibleTarget(1) ?? false
            })
        }
        if canAssign {
            actions.append(UIAccessibilityCustomAction(name: L10n.text("Assign \(skillName)")) { [weak self] _ in
                self?.assignAccessibleTarget() ?? false
            })
        }
        playfieldView.accessibilityCustomActions = actions.isEmpty ? nil : actions
    }

    /** Selects an eligible target and announces its position in the current skill's target list. */
    func moveAccessibleTarget(_ direction: Int) -> Bool {
        let candidates = session.targetCandidates(for: selectedControl).filter { $0.assignment == .eligible }
        guard overlay.isHidden, playState.canEdit, lifecycle.isForeground, !lifecycle.isInterrupted,
              !session.snapshot.isComplete, !candidates.isEmpty else { return false }
        performCommand(.focusUnassigned(direction))
        updatePlayfieldAccessibility()
        UIAccessibility.post(notification: .announcement, argument: playfieldView.accessibilityValue)
        return highlightedTarget?.state == .eligible
    }

    /** Runs the same typed assignment command as touch, keyboard and controller input. */
    func assignAccessibleTarget() -> Bool {
        guard !session.isReadOnly, !session.snapshot.isComplete, playState.canEdit,
              lifecycle.isForeground, !lifecycle.isInterrupted,
              let selection = highlightedTarget, selection.state == .eligible,
              session.targetCandidates(for: selectedControl).contains(where: {
                  $0.id == selection.id && $0.assignment == .eligible
              }) else { return false }
        performCommand(.assign)
        return true
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
        guard completionPresented else { pausePlay(showControls: true); return }
        guard !completionActions.isEmpty else {
            showRecoveryOverlay(title: L10n.text("SAVE FAILED")) { [weak self] in
                self?.completionPresented = false
                self?.presentCompletion()
            }
            return
        }
        if recordSaveError != nil { showCustomOverlay(title: completionTitle, details: [], actions: completionActions) }
        else { showOverlay(title: completionTitle, actions: completionActions, results: true) }
    }

    func showRecoveryOverlay(title: String, retry: @escaping () -> Void) {
        displayLink?.isPaused = false
        showCustomOverlay(title: title, details: [], actions: [])
        overlayCanvas.page = GameRecoveryArt.page(title: title)
        overlayCanvas.onAction = { [weak self] id in
            guard let self else { return }
            switch id {
            case "retry": retry()
            case "back": self.pausePlay(showControls: true)
            case "menu": self.leaveKeepingCheckpoint(.menu)
            default: break
            }
        }
        layoutOverlay()
    }

    private func leaveKeepingCheckpoint(_ destination: MobileGameExitAction) {
        leaveRequestID = UUID()
        displayLink?.isPaused = true
        suspendAudio()
        MobileMusic.shared.stop()
        onExit?(destination)
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
                actions: [(L10n.text("BACK"), { [weak self] in self?.pausePlay(showControls: true) })])
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
        replay.applyPresentationSettings(gameSettings)
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
                    (game.turn == nil ? L10n.text("START") : L10n.text("READY"), { [weak game] in game?.resumePlay() }),
                    (L10n.text("LIBRARY"), { [weak game] in game?.leaveToLibrary() }),
                ])
            } else { game.pausePlay(showControls: true) }
            game.view.setNeedsLayout()
        }
    }

    func toggleGhostSolution() {
        guard !solutionSelector.isHidden, solutionGame == nil,
              let classic = session as? ClassicMobileSession, classic.hasGhostSolution else { return }
        classic.ghostSolutionEnabled.toggle()
        solutionSelector.ghostEnabled = classic.ghostSolutionEnabled
        renderCurrentFrame(force: true)
    }

    private func layoutSolutionSelector() {
        let visible = hasSolutionPair && !overlay.isHidden
            && (overlayCanvas.page.pause != nil || playState.phase == .ready)
        solutionSelector.isHidden = !visible
        solutionSelector.accessibilityElementsHidden = !visible
        guard visible else {
            solutionSelector.focusedIndex = nil; solutionSelector.resetActivation()
            solutionPanelContentFrame = nil
            return
        }
        let region = MobileSystemRegions.menuFrame(in: view)
        let classic = session as? ClassicMobileSession
        solutionSelector.showsGhost = solutionGame == nil && classic?.hasGhostSolution == true
        solutionSelector.ghostEnabled = classic?.ghostSolutionEnabled == true
        let presentation = MobileSolutionSelectorArt.presentation(in: region,
            showsGhost: solutionSelector.showsGhost, style: MobileSolutionSwitchView.style)
        solutionSelector.apply(presentation)
        solutionPanelContentFrame = presentation.content
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
            overlay.isHidden = true; layoutSolutionSelector(); overlay.accessibilityViewIsModal = false
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
            highlightedTarget = nil
            #if !os(tvOS)
            previewPoint = nil
            #endif
            if session.rewind(seconds: 0.4) { MobileMusic.shared.playRewind() }
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
        showOverlay(title: message, actions: [(L10n.text("LIBRARY"), { [weak self] in MobileMusic.shared.stop(); self?.onExit?(.library) })])
    }

    private func pauseSummary() -> MobilePauseSummary {
        let music = MobileMusic.shared
        let c = gameSettings.classic
        let musicState = !music.isEnabled ? L10n.text("Music off") : c.musicVolume == 0 ? L10n.text("Music muted")
            : lifecycle.isInterrupted || !lifecycle.isForeground ? L10n.text("Audio suspended")
            : c.pauseMusicBeatOnly ? L10n.text("Music: beat only") : L10n.text("Music paused")
        let soundState = c.sound == .silent ? L10n.text("SFX off") : c.soundVolume == 0 ? L10n.text("SFX muted") : L10n.text("SFX \(Int(c.soundVolume * 100))%")
        return MobilePauseSummary(level: summary, snapshot: session.snapshot,
            activeCount: session.activeLemmingCount, ticksPerSecond: session.ticksPerSecond,
            speed: speed, assignedSkills: session.assignedSkillCount, supportsRewind: session.supportsRewind,
            usedRewind: session.usedRewind, isReplay: session.isReadOnly,
            soundtrack: music.currentSoundtrackName ?? music.soundtrack,
            track: music.currentTrackTitle, audio: musicState + "   /   " + soundState)
    }

    func showOverlay(title: String, actions: [(String, () -> Void)], results: Bool = false, pauseOverview: Bool = false) {
        hintRequestID = UUID()
        replayMoves.isHidden = true
        cancelPendingL3ToolDirection()
        playfieldView.suspendVisualEffects()
        selectionFade.reset()
        playfieldView.selectionSprite = nil
        hud.cancelHeldControls()
        nowPlaying.hide()
        achievementTask?.cancel(); achievementTask = nil
        overlayCanvas.actionHelp = [:]
        if !results { celebrationTask?.cancel(); celebrationTask = nil }
        overlayCanvas.resultStars = results ? onResultAwards?().stars : nil
        overlayCanvas.onAction = { [weak self] id in
            if id == "resultAward" { self?.showResultAchievement(); return }
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
            details = [L10n.text("\(snapshot.total) Lemmings   Save \(snapshot.required)"),
                       snapshot.remainingSeconds.map { L10n.text("Time \($0 / 60):\(String(format: "%02d", $0 % 60))") } ?? L10n.text("No time limit")]
        } else if completed {
            let awards = Set(resultAchievements.map(\.title))
            let elapsed = Double(snapshot.tick) / session.ticksPerSecond
            let time = "\(Int(elapsed) / 60):\(String(format: "%05.2f", elapsed.truncatingRemainder(dividingBy: 60)))"
            let recordTime = completionDetails.first { $0.hasPrefix(L10n.text("New time record")) }
            details = [L10n.text("Saved \(snapshot.saved)/\(snapshot.total)   Goal \(snapshot.required)"), recordTime ?? L10n.text("Time ") + time]
                + completionDetails.filter { !awards.contains($0) && !$0.hasPrefix(L10n.text("New time record")) }
        } else { details = [] }
        let heading = completed ? (snapshot.didWin ? L10n.text("Level complete") : L10n.text("Try again")) : (ready ? (turn?.ownerName ?? title) : title)
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
        let isPause = pauseOverview && !ready && !completed
        if isPause {
            overlayCanvas.page = MobilePauseArt.page(pauseSummary(), actions: overlayCanvas.page.footer)
        }
        overlay.bounces = !isPause
        #if os(tvOS)
        // The overview has one Back target, so arrows scroll its noninteractive
        // statistics directly. Action menus retain normal directional focus.
        overlay.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        overlay.panGestureRecognizer.isEnabled = isPause && actions.count == 1
        #endif
        overlay.setContentOffset(.zero, animated: false)
        if let frame = latestFrame {
            overlayCanvas.preview = MobileBitmapRenderer.image(frame)
            let visible = playfieldView.gameViewport.visibleLevelRect
            overlayCanvas.previewSource = CGRect(x: visible.x * session.renderScale, y: visible.y * session.renderScale, width: visible.width * session.renderScale, height: visible.height * session.renderScale)
        }
        overlay.isHidden = false
        if wasHidden {
            solutionSelector.focusedIndex = nil
            solutionSelector.resetActivation()
        }
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
        #if os(tvOS)
        updateTVPointer()
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
        layoutSolutionSelector()
        overlay.accessibilityViewIsModal = solutionSelector.isHidden
        if let content = solutionPanelContentFrame { region = content }
        overlay.frame = region
        let size = overlayCanvas.size(width: max(280, region.width), minimumHeight: region.height)
        overlayCanvas.frame = CGRect(origin: .zero, size: size)
        overlay.contentSize = size
        #if os(tvOS)
        overlay.isScrollEnabled = !overlayCanvas.page.televisionGrid
        if !overlay.isScrollEnabled { overlay.contentOffset = .zero }
        #endif
    }

    private static func cgRect(_ rect: MobileRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }
}
#endif
