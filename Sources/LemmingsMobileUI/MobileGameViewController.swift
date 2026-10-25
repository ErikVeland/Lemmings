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
#else
typealias MobileGameControllerBase = UIViewController
#endif
@MainActor final class MobileGameOverlay: MobileMenuScrollView {
    var onVisibilityChanged: (() -> Void)?
    override var isHidden: Bool { didSet { if oldValue != isHidden { onVisibilityChanged?() } } }
}

@MainActor final class MobileGameViewController: MobileGameControllerBase, UIScrollViewDelegate {
    lazy var inputAdapter = makeInputAdapter()
    override var canBecomeFirstResponder: Bool { true }
    var onExit: ((MobileGameExitAction) -> Void)?
    let globalNavigation = MobileNavigationView()
    #if os(iOS)
    private var menuBackGesture: UIScreenEdgePanGestureRecognizer?
    #endif
    /// Called with the player who acts next, before the game leaves for a retry or the next level.
    var onHandover: ((String) -> Bool)?
    var soloOwnerID: String?
    var journeyContext = MobileCheckpointEnvelope.JourneyContext()
    var canDefer = false
    var onSkipLevel: (() -> Bool)?
    var onSkipBalance: (() -> Int)?
    var onRefundSkip: (() -> Bool)?
    private var skipPending = false
    var onExtraSkillBalance: (() -> Int)?
    var onSpendExtraSkill: ((MobileExtraSkillChoice) -> Bool)?
    var onExtraSkillUse: (() -> ExtraSkillUse?)?
    var onResultRewards: (() -> [ResultAwards.EarnedReward])?
    var onResultAchievements: (() -> [MobileResultAchievementsArt.Item])?
    private let achievementScroll = MobileMenuScrollView()
    private let achievementCanvas = MobileMenuCanvas()
    private var showsSplitResult = false
    var onResultAwards: (() -> (stars: Int, ornament: Bool))?
    private var celebrationTask: Task<Void, Never>?
    var onRecordCompletion: ((MobileGameSnapshot) -> (details: [String], error: String?))?
    var onHints: (() -> Void)?
    var onHotSeatGhostsVisible: ((Bool) -> Void)?
    var onControlsHelp: (() -> Void)?
    private var completionActions: [(String, () -> Void)] = []
    private var completionTitle = ""
    private var completionDetails: [String] = []
    private var recordSaveError: String?
    private var resultReceiptTitles: [String] { onResultRewards?().filter(\.isConsumable).map(\.title) ?? [] }
    private var achievementTask: Task<Void, Never>?
    private var achievementIndex = 0
    private var resultAchievements: [(title: String, detail: String)] {
        let rewards = onResultRewards?().map { (title: $0.title, detail: $0.reason) } ?? []
        let rewardTitles = Set(rewards.map(\.title))
        return rewards + completionDetails.compactMap { title in
            if rewardTitles.contains(title) { return nil }
            if let award = ArcadeLevelAchievement.allCases.first(where: { $0.title == title }) { return (title, award.detail) }
            if let award = TrolleyAchievement.allCases.first(where: { $0.title == title }) { return (title, ResultAwards.explanation(for: award)) }
            if let award = ClassicAchievement.catalog.first(where: { $0.title == title }) { return (title, award.detail) }
            if title == L10n.text("New rescue record") { return (title, L10n.text("Your best rescue count on this level.")) }
            if title == L10n.text("New skill record") { return (title, L10n.text("Your fewest skills used to complete this level.")) }
            if title == L10n.text("Level skip earned") { return (title, L10n.text("A level skip is now available for a later attempt.")) }
            if title == L10n.text("Bonus skill earned") { return (title, L10n.text("One extra use of an existing level skill is available for a later attempt.")) }
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
        showCustomOverlay(title: award.title, details: [award.detail], reading: true, actions: actions)
    }

    private func updateResultAchievements() {
        achievementTask?.cancel(); achievementTask = nil
        guard !showsSplitResult else { return }
        let awards = resultAchievements
        guard !awards.isEmpty else { return }
        achievementIndex = 0
        overlayCanvas.actionHelp = ["resultAward": L10n.text("View awards from this attempt.")]
        overlayCanvas.page.rows = [.init("resultAward", L10n.text("Awards (\(awards.count))"))]
    }
    private var rewindHeld = false
    private var rewindStartedAt = 0.0
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
    var onOriginalMovies: (() -> Void)?
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
    private var resumeFramePending = false
    nonisolated(unsafe) private var displayLink: CADisplayLink?
    private var viewIsVisible = false
    private var displayUpdatesSuspended = false
    private(set) var deskClockVisible = false

    /// Keep the exact screen and Ready boundary underneath the clock. Returning never resumes play.
    func setDeskClockVisible(_ visible: Bool) {
        guard deskClockVisible != visible else { return }
        loadViewIfNeeded()
        deskClockVisible = visible
        // Replays and retained solutions can be presented above the live attempt.
        (presentedViewController as? MobileGameViewController)?.setDeskClockVisible(visible)
        if visible {
            if overlay.isHidden && presentedViewController == nil { pausePlay(showControls: true) }
            else { pausePlay(showControls: false) }
            inputAdapter.reset()
            resignFirstResponder()
            suspendAudio()
        }
        view.isUserInteractionEnabled = !visible
        view.accessibilityElementsHidden = visible
        updateDisplayLinkState()
    }
    var isDisplayLinkPaused: Bool { displayLink?.isPaused ?? true }
    private var framePacing = MobileFramePacing()
    private var appliedFrameRate = 0
    private var checkpointSaveTask: Task<Void, Never>?
    private var checkpointSaveGeneration = UUID()
    private var leaveRequestID = UUID()
    var playState = MobilePlayState()
    var paused: Bool { playState.isPaused }
    #if os(iOS)
    /// What the Desk Clock trigger sees. A paused Hot Seat turn counts as a handover.
    var deskClockScreen: DeskClockScreen {
        if session.isReadOnly { return .replay }
        guard paused else { return .level }
        return turn == nil ? .pause : .handover
    }
    #endif
    var speed = 1.0
    var fastSpeed = 2.0
    var controllerSpeedResetConsumed = false
    var inputSpeed = GameplaySpeed(legacyMultiplier: 3)
    var hintRequestID = UUID()
    var replayExportRequestID = UUID()
    var lastAssignmentControl: Int?
    var lastInputAssignment: MobileTargetSelection?
    var previewPoint: MobilePoint?
    var previewInput: MobileTargetInput = .touch
    var hoverAimActive = false
    var highlightedTarget: MobileTargetSelection?
    var touchSelection: MobileTouchSelection?
    var browsingTouchSelection = false
    var fanMode = false
    var l2PrimaryHeld = false

    func updateL2Aim(at point: MobilePoint?, held: Bool) {
        guard !session.isReadOnly, let tribes = session as? Lemmings2MobileSession else { return }
        guard !fanMode, overlay.isHidden, lifecycle.isForeground, !lifecycle.isInterrupted,
              let point else { tribes.releasePointerInput(); return }
        tribes.setAim(at: playfieldView.gameViewport.levelPoint(fromView: point),
            held: held && playState.phase == .running)
    }

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
        inputSpeed = GameplaySpeed(legacyMultiplier: min(10, fastSpeed))
        inputSpeed.ridiculousEnabled = settings.classic.ridiculousSpeedEnabled
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

    deinit { displayLink?.invalidate() }

    #if os(iOS)
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    #endif
    override var keyCommands: [UIKeyCommand]? { gameplayKeyCommands }

    override func viewDidLoad() {
        super.viewDidLoad()
        overlay.contentInsetAdjustmentBehavior = .never
        achievementScroll.contentInsetAdjustmentBehavior = .never
        overlay.onVisibilityChanged = { [weak self] in
            self?.updateDisplayLinkState()
            self?.globalNavigation.isHidden = self?.overlay.isHidden ?? true
            #if os(iOS)
            self?.menuBackGesture?.isEnabled = self?.overlay.isHidden == false
            #endif
            if let self, self.overlay.isHidden { self.clearSplitResult() }
            #if os(tvOS)
            self?.updateTVInputRouting()
            #endif
        }
        #if os(tvOS)
        updateTVInputRouting()
        #endif
        view.backgroundColor = .black
        view.addSubview(playfieldView)
        view.addSubview(hud)
        view.addSubview(touchLoupe)
        view.addSubview(nowPlaying)
        view.addSubview(replaySkillInfo)
        countdownLabel.palette = .green
        countdownLabel.maximumScale = 6
        countdownLabel.face = .large
        countdownLabel.displayHeight = 80
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
        hud.onRewindRepeat = { [weak self] in self?.repeatHeldRewind() }
        hud.onStepBatch = { [weak self] action, count in self?.handleSteps(action, count: count) }
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
        playfieldView.canHoldSelection = { [weak self] point in
            guard let self, !self.session.isReadOnly, self.overlay.isHidden, self.playState.canEdit,
                  self.lifecycle.isForeground, !self.lifecycle.isInterrupted, !self.fanMode,
                  !self.session.snapshot.isComplete else { return false }
            return MobileTargetSelector.select(candidates: self.session.targetCandidates(for: self.selectedControl),
                touch: point, viewport: self.playfieldView.gameViewport, radius: 30, input: .touch) != nil
        }
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
        viewIsVisible = true
        synchronizeSceneActivity()
        installTrackNoticeCallback()
        startDisplayLink()
        updateDisplayLinkState()
        updatePerformanceBudget()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewIsVisible = false
        pausePlay(showControls: false)
        updateDisplayLinkState()
        suspendAudio()
        achievementTask?.cancel(); achievementTask = nil
        celebrationTask?.cancel(); celebrationTask = nil
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        synchronizeSceneActivity()
        let insets = MobileSystemRegions.contentInsets(in: view)
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
            playfieldView.cancelInteraction(clearHover: true)
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
            pausePlay(showControls: true)
        }
        playfieldView.frame = Self.cgRect(layout.interface.playfieldFrame)
        playfieldView.blockedInputFrames = layout.reservedRegions.map { playfieldView.convert(Self.cgRect($0.frame), from: view) }
        layoutSolutionSelector()
        layoutReplayMoves(layout: layout)
        countdownLabel.frame = CGRect(x: floor(playfieldView.frame.midX - 40), y: floor(playfieldView.frame.midY - 48), width: 80, height: 96)
        let replayTargets = MobileHUDRenderer.targets(layout: layout, snapshot: session.snapshot,
            selectedSkill: selectedControl, paused: paused, speed: speed,
            endRunArmed: endRunArmedUntil > ProcessInfo.processInfo.systemUptime)
        replaySkillInfo.frame = MobileReplaySkillArt.frame(in: playfieldView.frame,
            below: playfieldView.frame.minY,
            avoiding: replayTargets.map(\.inputFrame) + layout.reservedRegions.map { Self.cgRect($0.frame) }
                + [hud.replayMapFrame ?? layout.minimapFrame].compactMap { $0 }
                + (replayMoves.isHidden ? [] : ReplayMoveArt.frames(in: replayMoves.frame))) ?? .zero
        var musicArea = playfieldView.frame
        if session.isReadOnly || hasSolutionPair {
            let top = min(musicArea.maxY, max(musicArea.minY, solutionSelector.isHidden ? musicArea.minY : solutionSelector.frame.maxY + 8))
            musicArea.size.height = musicArea.maxY - top
            musicArea.origin.y = top
        }
        if session.isReadOnly {
            musicArea.size.width = max(0, replaySkillInfo.frame.minX - musicArea.minX - 8)
        }
        nowPlaying.position(in: musicArea)
        hud.frame = view.bounds
        updateHUD(layout: layout)
        layoutOverlay()
        if previewPoint != nil { renderCurrentFrame(force: true) }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewIsVisible = false
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
        let target = MobileDisplayLinkTarget { [weak self] in self?.displayFrame($0) }
        let link = CADisplayLink(target: target, selector: #selector(MobileDisplayLinkTarget.frame(_:)))
        link.isPaused = true
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func updateDisplayLinkState() {
        let active = viewIsVisible && lifecycle.acceptsInput(menuVisible: !overlay.isHidden) && !displayUpdatesSuspended && !deskClockVisible
        displayLink?.isPaused = !active || (!overlay.isHidden && GCController.controllers().isEmpty)
        if isDisplayLinkPaused {
            clock.suspend()
            lastVisibleTimestamp = nil
        }
    }

    private func synchronizeSceneActivity() {
        guard let scene = viewIfLoaded?.window?.windowScene else { return }
        owningScene = scene
        // Level preparation can finish after the scene's deactivation notification.
        if scene.activationState != .foregroundActive, lifecycle.isForeground {
            applyLifecycle(.becameInactive)
        }
    }

    @objc func displayFrame(_ link: CADisplayLink) {
        synchronizeSceneActivity()
        guard viewIsVisible, lifecycle.acceptsInput(menuVisible: !overlay.isHidden), !displayUpdatesSuspended, !deskClockVisible else {
            updateDisplayLinkState()
            return
        }
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
            if resumeFramePending {
                resumeFramePending = false
                // Include deferred controller draws and layout before restarting simulation time.
                view.layoutIfNeeded()
                if !paused, overlay.isHidden, !countdown.isActive {
                    clock.resume(at: CACurrentMediaTime())
                } else {
                    clock.suspend()
                }
            }
        }
        pollingController = true
        playfieldView.deferFrameUpdates = true
        inputAdapter.poll(context: ObjectIdentifier(overlay.isHidden ? playfieldView : overlayCanvas), at: link.timestamp)
        #if !os(tvOS)
        pollingController = false
        playfieldView.deferFrameUpdates = false
        #endif
        guard !isDisplayLinkPaused, !lifecycle.isInterrupted else { return }
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
        if overlay.isHidden { playfieldView.advanceVisualEffects() }
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
            return
        }
        if endRunArmedUntil > 0, link.timestamp > endRunArmedUntil {
            endRunArmedUntil = 0
            updateHUD()
        }
        guard !paused, overlay.isHidden, !snapshot.isComplete else { return }
        // Present the frozen tick before counting time toward the next simulation step.
        guard !resumeFramePending else { return }
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
            showsMenuButton: showsMenuButton, television: television,
            topBarInsets: MobileSystemRegions.topBarInsets(in: view),
            navigationRail: MobileSystemRegions.navigationRail(in: view),
            fillsDisplayWidth: MobileSystemRegions.usesFullDisplay(in: view)
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
            if playfieldView.hasActiveTouch { playfieldView.cancelInteraction() }
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
            handleSteps(.step, count: 1)
            return
        case .stepBackward:
            handleSteps(.stepBackward, count: 1)
            return
        case .rewind:
            if session.isReadOnly { completionPresented = false }
            pauseForPlanning()
            playfieldView.cancelInteraction()
            let rewound = session.rewind(seconds: 2)
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
            inputSpeed.ridiculousEnabled = gameSettings.classic.ridiculousSpeedEnabled
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

    func handle(_ touchEffects: [MobileTouchEffect], input: MobileTargetInput? = nil) {
        if touchEffects.contains(.cancelPreview) {
            (session as? Lemmings2MobileSession)?.releasePointerInput()
            touchSelection = nil
            browsingTouchSelection = false
        }
        guard overlay.isHidden, lifecycle.isForeground, !lifecycle.isInterrupted else { return }
        if session.isReadOnly {
            for case let .pan(delta) in touchEffects {
                playfieldView.stopAutomaticFitting()
                playfieldView.gameViewport.pan(viewDelta: delta)
            }
            return
        }
        guard playState.canEdit, !session.snapshot.isComplete else { return }
        var needsFrame = false
        let touchInput = input ?? playfieldView.touchInput
        for effect in touchEffects {
            switch effect {
            case let .preview(point), let .movePreview(point):
                updateL2Aim(at: point, held: true)
                hoverAimActive = false
                previewInput = touchInput
                previewPoint = point
                if !browsingTouchSelection { highlightedTarget = target(at: point) }
                needsFrame = true
            case let .holdSelection(point):
                updateL2Aim(at: point, held: false)
                browsingTouchSelection = true
                let candidates = session.targetCandidates(for: selectedControl)
                touchSelection = target(at: point).flatMap {
                    MobileTouchSelection(candidates: candidates, touch: point,
                        viewport: playfieldView.gameViewport, selectedID: $0.id)
                }
                highlightedTarget = touchSelection?.selection(in: candidates)
                needsFrame = true
            case let .browseSelection(steps):
                let candidates = session.targetCandidates(for: selectedControl)
                let previous = highlightedTarget
                touchSelection?.browse(by: steps, candidates: candidates)
                highlightedTarget = touchSelection?.selection(in: candidates)
                needsFrame = needsFrame || highlightedTarget != previous
            case let .commit(point):
                previewInput = touchInput
                commitTouch(at: point, held: false)
                needsFrame = true
            case .commitSelection:
                if let point = previewPoint { commitTouch(at: point, held: true) }
                else { restoreHoverAim() }
                needsFrame = true
            case let .panHoldingSelection(delta):
                guard browsingTouchSelection else { continue }
                playfieldView.stopAutomaticFitting()
                let oldViewport = playfieldView.gameViewport
                playfieldView.gameViewport.pan(viewDelta: delta)
                needsFrame = playfieldView.gameViewport == oldViewport
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

    private func commitTouch(at point: MobilePoint, held: Bool) {
        defer { updateL2Aim(at: point, held: false) }
        if fanMode {
            previewPoint = point
            updateFan(at: point, active: (session as? Lemmings2MobileSession)?.isFanActive != true)
            restoreHoverAim()
            return
        }
        if !held, let tribes = session as? Lemmings2MobileSession,
           tribes.interact(at: playfieldView.gameViewport.levelPoint(fromView: point)) {
            effects.update(session: session, viewport: playfieldView.gameViewport)
            saveCheckpoint(reason: .periodic)
            restoreHoverAim()
            return
        }
        let selection = held
            ? touchSelection?.selection(in: session.targetCandidates(for: selectedControl)) : target(at: point)
        if let selection, selection.state == .eligible {
            if !beginL3ToolDirectionSelection(control: selectedControl,
                target: selection.id, selection: selection) {
                let accepted = session.assign(control: selectedControl, to: selection.id)
                if accepted {
                    lastInputAssignment = selection; lastAssignmentControl = selectedControl
                    effects.update(session: session, viewport: playfieldView.gameViewport)
                } else { effects.rejectedAssignment() }
                saveCheckpoint(reason: .periodic)
            }
        }
        highlightedTarget = selection
        restoreHoverAim()
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
        let retained = TVTargetLock.retain(highlightedTarget, at: point, candidates: candidates,
                                           viewport: playfieldView.gameViewport)?.id
        #else
        let retained: Int? = nil
        #endif
        return MobileTargetSelector.select(
            candidates: candidates,
            touch: point,
            viewport: playfieldView.gameViewport,
            radius: 30,
            preference: preference,
            favourApproaching: settings.favorApproachingLemmings,
            input: previewInput,
            retaining: retained,
            wallDirectionForTarget: session.targetWallDirection
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
            else { highlightedTarget = nil }
            #else
            if browsingTouchSelection { highlightedTarget = touchSelection?.selection(in: candidates) }
            else if let previewPoint { highlightedTarget = selectTarget(at: previewPoint, candidates: candidates) }
            else { highlightedTarget = nil }
            #endif
        }
        if tick < lastRenderedTick { selectionFade.reset(); playfieldView.resetTransientEffects(preservingTrails: true) }
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
            playfieldView.cursorOccupied = highlightedTarget != nil
            playfieldView.cursorEligible = highlightedTarget?.state == .eligible
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
            playfieldView.captureSpriteTrails(session: session)
            try playfieldView.update(frame: frame)
            if !overlay.isHidden, overlayCanvas.page.preview {
                overlayCanvas.preview = playfieldView.bitmap
                overlayCanvas.previewSource = menuPreviewSource(frame: frame)
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
        (session as? Lemmings2MobileSession)?.releasePointerInput()
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
            guard let self, succeeded, self.viewIsVisible, self.lifecycle.isForeground,
                  !self.lifecycle.isInterrupted, !self.displayUpdatesSuspended, !self.deskClockVisible, !self.paused else { return }
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
            appendExtraSkillAction()
            return
        }
        #if os(tvOS)
        tvCameraMode = false
        showOverlay(title: L10n.text("PAUSED"), actions: [
            (session.isReadOnly ? (session.snapshot.isComplete ? L10n.text("REPLAY") : L10n.text("PLAY")) : L10n.text("RESUME"), { [weak self] in self?.resumeSelectedView() }),
            (session.isReadOnly ? L10n.text("BACK") : L10n.text("Back to library"), { [weak self] in self?.leaveToLibrary() }),
        ] + (session.isReadOnly ? [] : [
            (L10n.text("HINT"), { [weak self] in self?.onHints?() }),
            (L10n.text("RESTART LEVEL"), { [weak self] in self?.showRestartLevel() }),
        ]) + [(L10n.text("GAME CONTROLS"), { [weak self] in self?.showTVControls() })], pauseOverview: true)
        #else
        showOverlay(
            title: L10n.text("PAUSED"),
            actions: [
                (session.isReadOnly ? (session.snapshot.isComplete ? L10n.text("REPLAY") : L10n.text("PLAY")) : L10n.text("RESUME"), { [weak self] in self?.resumeSelectedView() }),
                (session.isReadOnly ? L10n.text("BACK") : L10n.text("Back to library"), { [weak self] in self?.leaveToLibrary() }),
            ] + (session.isReadOnly ? [(L10n.text("CONTROLS HELP"), { [weak self] in self?.onControlsHelp?() })] : pauseShelfTools()),
            pauseOverview: true
        )
        #endif
        let help = session.isReadOnly ? 2 : 4
        if overlayCanvas.page.footer.indices.contains(help) { overlayCanvas.page.footer[help].group = .preferences }
        appendExtraSkillAction()
        appendLevelSkipAction()
        if !session.isReadOnly, gameSettings.classic.inspectWhilePaused, ["classic-dos", "lemmings2", "lemmings3"].contains(session.engineIdentifier) {
            let inspectAction = overlayActions.count
            overlayActions.append { [weak self] in self?.showLemmingInspection() }
            overlayCanvas.page.footer.append(.init(String(inspectAction), L10n.text("INSPECT LEMMINGS")))
            overlayCanvas.page.footer[overlayCanvas.page.footer.count - 1].group = .inspection
        }
        if !session.isReadOnly, let ghosts = session.hotSeatGhosts, ghosts.count > 0 {
            let ghostsAction = overlayActions.count
            overlayActions.append { [weak self] in self?.toggleHotSeatGhosts() }
            overlayCanvas.page.footer.append(.init(String(ghostsAction),
                L10n.text("Hot Seat ghosts"), selected: !ghosts.hidden))
            overlayCanvas.page.footer[overlayCanvas.page.footer.count - 1].toggleValue = !ghosts.hidden
            overlayCanvas.page.footer[overlayCanvas.page.footer.count - 1].group = .inspection
        }
        if !session.isReadOnly, let classic = session as? ClassicMobileSession, classic.hasGhostSolution {
            let action = overlayActions.count
            overlayActions.append { [weak self] in
                guard let self, let classic = self.session as? ClassicMobileSession else { return }
                classic.ghostSolutionEnabled.toggle()
                self.renderCurrentFrame(force: true)
                self.pausePlay(showControls: true)
            }
            var toggle = GameFrontEnd.Action(String(action), L10n.text("Ghost solution"), selected: classic.ghostSolutionEnabled)
            toggle.toggleValue = classic.ghostSolutionEnabled
            toggle.group = .inspection
            overlayCanvas.page.footer.append(toggle)
        }
        if let onOriginalMovies {
            let movieAction = overlayActions.count
            overlayActions.append(onOriginalMovies)
            overlayCanvas.page.footer.append(.init(String(movieAction), L10n.text("Original movies")))
        }
        let settingsAction = overlayActions.count
        overlayActions.append { [weak self] in self?.showInGameSettings() }
        overlayCanvas.page.footer.append(.init(String(settingsAction), L10n.text("SETTINGS")))
        overlayCanvas.page.footer[overlayCanvas.page.footer.count - 1].group = .preferences
        if session.isReadOnly, !session.replayMoveNavigation.ticks.isEmpty {
            let previous = overlayActions.count
            overlayActions += [{ [weak self] in self?.seekSolutionMove(-1) }, { [weak self] in self?.seekSolutionMove(1) }]
            overlayCanvas.page.footer += [
                .init(String(previous), L10n.text("PREVIOUS MOVE"), enabled: session.replayMoveNavigation.target(from: session.snapshot.tick, direction: -1) != nil),
                .init(String(previous + 1), L10n.text("NEXT MOVE"), enabled: session.replayMoveNavigation.target(from: session.snapshot.tick, direction: 1) != nil),
            ]
            for index in overlayCanvas.page.footer.indices.suffix(2) { overlayCanvas.page.footer[index].group = .playback }
        }
        overlayCanvas.page = MobilePauseArt.organizingActions(overlayCanvas.page)
        layoutOverlay()
    }

    var levelSkipTitle: String {
        let balance = onSkipBalance?() ?? 0
        return turn.map { L10n.text("Skip as \($0.ownerName) (\(balance))") }
            ?? L10n.text("Skip level (\(balance))")
    }
    var canSpendLevelSkip: Bool {
        !session.isReadOnly && !session.snapshot.didWin && onSkipLevel != nil
            && (onSkipBalance?() ?? 0) > 0 && !transitionInFlight && !skipPending && recordSaveError == nil
    }
    private func appendLevelSkipAction() {
        guard !session.isReadOnly, onSkipLevel != nil else { return }
        let index = overlayActions.count
        overlayActions.append { [weak self] in self?.performLevelSkip() }
        overlayCanvas.page.footer.append(.init(String(index), levelSkipTitle, enabled: canSpendLevelSkip))
    }
    func performLevelSkip() {
        guard canSpendLevelSkip else { return }
        guard onSkipLevel?() == true else {
            showRecoveryOverlay(title: L10n.text("Skip was not saved")) { [weak self] in self?.performLevelSkip() }
            return
        }
        skipPending = true
        finish(.next, handingTo: turn?.choices(false).first?.choice.player)
    }
    private func recoverLevelSkip(_ message: String) {
        let returned = onRefundSkip?() ?? false
        skipPending = false
        resetTransition()
        if returned {
            showRecoveryOverlay(title: message) { [weak self] in self?.performLevelSkip() }
        } else {
            showCustomOverlay(title: L10n.text("Skip could not be returned"), details: [],
                actions: [(L10n.text("BACK"), { [weak self] in self?.pausePlay(showControls: true) })])
        }
    }

    private func appendExtraSkillAction() {
        guard !session.isReadOnly, session.bonusSkillID == nil,
              let available = onExtraSkillBalance?(), available > 0,
              !session.extraSkillChoices.isEmpty else { return }
        let index = overlayActions.count
        overlayActions.append { [weak self] in self?.showExtraSkillChoices() }
        overlayCanvas.page.footer.append(.init(String(index), L10n.text("BONUS SKILL ×\(available)")))
        layoutOverlay()
    }

    private func showExtraSkillChoices() {
        guard paused, !session.isReadOnly, session.bonusSkillID == nil,
              (onExtraSkillBalance?() ?? 0) > 0 else { return }
        let choices = session.extraSkillChoices
        guard !choices.isEmpty else { return }
        showOverlay(title: L10n.text("BONUS SKILL"),
            actions: [(L10n.text("BACK"), { [weak self] in self?.pausePlay(showControls: true) })])
        overlayCanvas.page = MobileExtraSkillArt.page(choices)
        for choice in choices {
            overlayActions.append { [weak self] in
                guard let self, self.session.extraSkillChoices.contains(choice),
                      self.onSpendExtraSkill?(choice) == true,
                      self.session.grantExtraSkill(choice) else { return }
                self.selectedControl = choice.control
                self.lastRenderedTick = -1
                self.renderCurrentFrame(force: true)
                self.updateHUD()
                self.saveCheckpoint(reason: .rewardUse)
                self.pausePlay(showControls: true)
                UIAccessibility.post(notification: .announcement,
                    argument: L10n.text("+1 \(choice.title). Bonus skill used."))
            }
        }
        layoutOverlay()
    }

    private func showLemmingInspection(_ retained: LemmingInspection? = nil, index requested: Int = 0, historyPage: Int = 0) {
        guard paused, playState.phase != .ready, !session.isReadOnly,
              let snapshot = retained ?? session.lemmingInspection else { return }
        let index = min(max(0, requested), max(0, snapshot.individuals.count - 1))
        let page = LemmingInspectionArt.page(snapshot, index: index, historyPage: historyPage)
        let callbacks: [() -> Void] = [
            { [weak self] in self?.pausePlay(showControls: true) },
            { [weak self] in self?.showLemmingInspection(snapshot, index: index - 1) },
            { [weak self] in self?.showLemmingInspection(snapshot, index: index + 1) },
            { [weak self] in
                self?.showLemmingInspection(snapshot, index: index, historyPage: historyPage - 1)
            },
            { [weak self] in
                self?.showLemmingInspection(snapshot, index: index, historyPage: historyPage + 1)
            }
        ]
        showOverlay(title: page.title, actions: page.footer.enumerated().map { ($0.element.title, callbacks[$0.offset]) })
        overlayCanvas.page = page
        layoutOverlay()
    }

    /// Pause tools sit on the pinned shelf beside Resume, one tap from gameplay.
    /// Settings is appended by the caller so every pause variant keeps it.
    private func pauseShelfTools() -> [(String, () -> Void)] {
        var actions: [(String, () -> Void)] = [
            (L10n.text("HINT"), { [weak self] in self?.onHints?() }),
            (L10n.text("RESTART LEVEL"), { [weak self] in self?.showRestartLevel() }),
            (L10n.text("CONTROLS HELP"), { [weak self] in self?.onControlsHelp?() }),
        ]
        if session is Lemmings2MobileSession {
            actions.append((fanMode ? L10n.text("SKILL MODE") : L10n.text("FAN"), { [weak self] in
                guard let self else { return }
                self.fanMode.toggle()
                self.resumePlay()
            }))
        }
        return actions
    }

    func showRestartLevel() {
        guard !session.isReadOnly else { return }
        let returnToPreviousPage = overlayReturnAction()
        pausePlay(showControls: false)
        showCustomOverlay(title: L10n.text("Restart level?"), details: [summary.locationLabel, summary.title], actions: [
            (L10n.text("CANCEL"), returnToPreviousPage),
            (L10n.text("RESTART LEVEL"), { [weak self] in self?.finish(.retry) }),
        ])
        overlayCanvas.page.footer[0].primary = false
        overlayCanvas.page.footer[1].primary = true
        overlayCanvas.page.footerColumns = 2
        overlayCanvas.page.detailTitles = [1]
    }

    func pauseForPlanning() {
        (session as? Lemmings2MobileSession)?.releasePointerInput()
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
              playState.phase != .completed, lifecycle.isForeground, !deskClockVisible else { return }
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
        let needsLifecycleResume = lifecycle.requiresPlayerResume
        let resumeEffects = lifecycle.handle(.playerRequestedResume)
        guard playState.resume(isForeground: lifecycle.isForeground, isInterrupted: lifecycle.isInterrupted) else { return }
        if wasReady {
            readyCuePending = true
            if freshStart { countdown.arm(); countdownLabel.text = "3"; countdownLabel.isHidden = false }
        }
        if needsLifecycleResume {
            applyEffects(resumeEffects)
        }
        guard lifecycle.isForeground, !lifecycle.isInterrupted else { return }
        overlay.isHidden = true
        if !needsLifecycleResume { resumeAudio() }
        session.resumeFromCurrentTick()
        clock.suspend()
        resumeFramePending = true
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
        if session.bonusSkillID != nil, !completionDetails.contains(L10n.text("Bonus skill used")) {
            completionDetails.insert(L10n.text("Bonus skill used"), at: 0)
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
            actions.append((levelSkipTitle, { [weak self] in self?.performLevelSkip() }))
        }
        if let data = try? session.replayDocument() {
            actions.append((L10n.text("REVIEW"), { [weak self] in self?.showReplay(document: data) }))
            actions.append((L10n.text("SHARE MOVIE"), { [weak self] in self?.shareReplayMovie(document: data) }))
        }
        let following = turn?.choices(snapshot.didWin).first(where: { $0.choice.primary })?.choice.player
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
    func resetTransition() {
        transitionInFlight = false
        displayUpdatesSuspended = false
        updateDisplayLinkState()
    }

    private func finish(_ action: MobileGameExitAction, handingTo player: String? = nil) {
        guard !transitionInFlight else { return }
        if recordSaveError != nil {
            if action == .library || action == .menu { leaveKeepingCheckpoint(action) }
            return
        }
        if action == .retry { MobileMusic.shared.vinylStop() }
        transitionInFlight = true
        celebrationTask?.cancel(); celebrationTask = nil
        displayUpdatesSuspended = true
        updateDisplayLinkState()
        suspendAudio()
        effects.stop()
        if action == .library || action == .menu { MobileMusic.shared.stop() }
        Task { [self] in
            do {
                await checkpointSaveTask?.value
                try await checkpointStore.retire(runID: runID)
                if let player, onHandover?(player) == false {
                    if skipPending { recoverLevelSkip(L10n.text("Hot Seat was not saved")); return }
                    resetTransition()
                    showRecoveryOverlay(title: L10n.text("HOT SEAT WAS NOT SAVED")) { [weak self] in self?.finish(action, handingTo: player) }
                    return
                }
                onExit?(action)
            } catch {
                if skipPending { recoverLevelSkip(L10n.text("Run was not closed")); return }
                resetTransition()
                showRecoveryOverlay(title: L10n.text("RUN WAS NOT CLOSED")) { [weak self] in self?.finish(action, handingTo: player) }
            }
        }
    }

    func leaveToMainMenu() {
        if let game = solutionGame {
            pausePlay(showControls: false)
            dismiss(animated: false) { [weak game] in game?.leaveToMainMenu() }
            return
        }
        if session.isReadOnly {
            pausePlay(showControls: false)
            let sourceGame = presentingViewController as? MobileGameViewController
            let library = presentingViewController as? MobileLibraryViewController
                ?? parent as? MobileLibraryViewController
            if parent is MobileLibraryViewController { onExit?(.menu); return }
            dismiss(animated: false) { [weak library, weak sourceGame] in
                if let sourceGame { sourceGame.leaveToMainMenu() }
                else { library?.navigate(.home) }
            }
            return
        }
        leaveToLibrary(destination: .menu)
    }

    func leaveToLibrary(destination: MobileGameExitAction = .library) {
        if solutionGame != nil { returnToSolutionGame(); return }
        if session.isReadOnly { dismiss(animated: false); return }
        let returnToPreviousPage = overlayReturnAction()
        playState.suspend()
        clock.suspend()
        displayUpdatesSuspended = true
        updateDisplayLinkState()
        suspendAudio()
        guard !session.snapshot.isComplete else {
            let following = turn?.choices(session.snapshot.didWin).first(where: { $0.choice.primary })?.choice.player
            finish(destination, handingTo: following)
            return
        }
        let request = UUID()
        leaveRequestID = request
        showOverlay(title: L10n.text("SAVING..."), actions: [(L10n.text("CANCEL"), { [weak self] in
            guard let self else { return }
            self.leaveRequestID = UUID()
            self.displayUpdatesSuspended = false
            self.updateDisplayLinkState()
            returnToPreviousPage()
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
                    onExit?(destination)
                } catch {
                    guard leaveRequestID == request else { return }
                    showRecoveryOverlay(title: error.localizedDescription) { [weak self] in self?.leaveToLibrary(destination: destination) }
                }
            }
        } catch {
            showRecoveryOverlay(title: error.localizedDescription) { [weak self] in self?.leaveToLibrary(destination: destination) }
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
            owner: turn?.owner ?? soloOwnerID,
            extraSkillUse: onExtraSkillUse?(), journeyContext: journeyContext
        )
        return Task.detached(priority: .utility) {
            MobileCheckpointEnvelope(runID: metadata.runID, engine: metadata.engine,
                engineFingerprint: metadata.engineFingerprint, levelIdentifier: metadata.levelIdentifier,
                levelIndex: metadata.levelIndex, levelFingerprint: metadata.levelFingerprint,
                tick: metadata.tick, selectedControl: metadata.selectedControl, camera: metadata.camera,
                payload: try payload.encode(), savedAt: metadata.savedAt, scope: metadata.scope, owner: metadata.owner,
                extraSkillUse: metadata.extraSkillUse, journeyContext: metadata.journeyContext)
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
        for name in [Notification.Name.GCControllerDidConnect, .GCControllerDidDisconnect] {
            observers.append(centre.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateDisplayLinkState() }
            })
        }
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

    func applyLifecycle(_ event: MobileLifecycleEvent) {
        if event == .memoryWarning {
            MobileDevicePerformance.memoryWarning()
            updatePerformanceBudget()
            playfieldView.releaseEffectResources()
        }
        inputAdapter.reset()
        applyEffects(lifecycle.handle(event))
        updateDisplayLinkState()
        if !lifecycle.isForeground || lifecycle.isInterrupted {
            achievementTask?.cancel(); achievementTask = nil
            celebrationTask?.cancel(); celebrationTask = nil
        } else if viewIsVisible, !overlay.isHidden, overlayCanvas.page.result {
            updateResultAchievements()
        }
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
                if viewIsVisible {
                    audio.prepare()
                    renderCurrentFrame(force: true)
                }
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
        hud.replayLevel = session.isReadOnly ? summary : nil
        hud.counterStyle = gameSettings.classic.counterStyle
        hud.statusDetails = .init(lostCount: session.lostLemmingCount,
            deathCounter: FailureMoodDecision.deathCounter(saved: snapshot.saved,
                active: session.activeLemmingCount, unreleased: snapshot.total - snapshot.released,
                required: snapshot.required, total: snapshot.total,
                isComplete: snapshot.isComplete, didWin: snapshot.didWin), engineIdentifier: session.engineIdentifier)
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
        achievementScroll.backgroundColor = .black
        achievementScroll.isHidden = true
        achievementScroll.addSubview(achievementCanvas)
        view.addSubview(achievementScroll)
        globalNavigation.onHome = { [weak self] in self?.leaveToMainMenu() }
        globalNavigation.onBack = { [weak self] in self?.overlayCanvas.goBack() }
        overlayCanvas.globalNavigation = globalNavigation
        globalNavigation.onSecondary = { [weak self] in self?.pausePlay(showControls: true) }
        view.addSubview(globalNavigation)
        #if os(iOS)
        let backGesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(menuEdgeBack(_:)))
        backGesture.edges = .left
        backGesture.isEnabled = !overlay.isHidden
        view.addGestureRecognizer(backGesture)
        menuBackGesture = backGesture
        #endif
    }

    #if os(iOS)
    @objc private func menuEdgeBack(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .ended, !overlay.isHidden, !displayUpdatesSuspended,
              gesture.translation(in: view).x > 60 || gesture.velocity(in: view).x > 500 else { return }
        overlayCanvas.goBack()
    }
    #endif

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
        displayUpdatesSuspended = false
        updateDisplayLinkState()
        showCustomOverlay(title: title, details: [], actions: [])
        overlayCanvas.page = GameRecoveryArt.page(title: title, includesMenu: false)
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
        displayUpdatesSuspended = true
        updateDisplayLinkState()
        suspendAudio()
        MobileMusic.shared.stop()
        onExit?(destination)
    }

    /// `ghostOnly` reveals the solution as a ghost over the live attempt and stays in the game.
    func showReplay(document: Data, solution: Bool = false, ghostOnly: Bool = false) {
        do {
            if solution, ghostOnly, retainedSolution != nil { showGhostSolution(); return }
            if solution, retainedSolution != nil { selectSolutionMode(.solution); return }
            guard let replay = try session.makeReplaySession(document: document) else { return }
            // Watching an attempt keeps the Hot Seat ghosts it was played against. Solutions have none.
            if !solution { replay.hotSeatGhosts = session.hotSeatGhosts }
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
                if ghostOnly { showGhostSolution() } else { selectSolutionMode(.solution) }
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

    /// Turns the ghost on and returns to the paused game, where the selector shows its state.
    func showGhostSolution() {
        guard solutionGame == nil, let classic = session as? ClassicMobileSession, classic.hasGhostSolution else {
            pausePlay(showControls: true); return
        }
        classic.ghostSolutionEnabled = true
        pausePlay(showControls: true)
        renderCurrentFrame(force: true)
    }

    /// Shows or hides earlier Hot Seat turns. The choice is shared with the Hot Seat page and the Mac.
    func toggleHotSeatGhosts() {
        guard session.hotSeatGhosts != nil else { return }
        session.hotSeatGhosts?.hidden.toggle()
        onHotSeatGhostsVisible?(session.hotSeatGhosts?.hidden == false)
        renderCurrentFrame(force: true)
        if overlayCanvas.page.pause != nil { pausePlay(showControls: true) }
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

    private func layoutReplayMoves(layout: MobileHUDLayout) {
        hud.replayMapFrame = nil
        #if os(tvOS)
        replayMoves.isHidden = true
        #else
        replayMoves.isHidden = !session.isReadOnly || !overlay.isHidden || session.replayMoveNavigation.ticks.isEmpty
        guard !replayMoves.isHidden else { return }
        guard let frame = ReplayMoveArt.frame(layout: layout) else { replayMoves.isHidden = true; return }
        replayMoves.frame = frame
        hud.replayMapFrame = ReplayMoveArt.mapFrame(in: frame)
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
            rewindStartedAt = ProcessInfo.processInfo.systemUptime
            if session.rewind(seconds: MobileHUDPress.rewindSeconds(heldFor: 0)) { MobileMusic.shared.playRewind() }
            renderCurrentFrame(force: true)
        }
        rewindHeld = held
        MobileMusic.shared.setGameplayState(paused: paused, speed: speed, rewinding: held)
        if !held { saveCheckpoint(reason: .periodic) }
        updateHUD()
    }

    private func repeatHeldRewind() {
        guard rewindHeld, session.supportsRewind, overlay.isHidden, playState.canEdit,
              lifecycle.isForeground, !lifecycle.isInterrupted else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - rewindStartedAt
        if session.rewind(seconds: MobileHUDPress.rewindSeconds(heldFor: elapsed)) {
            MobileMusic.shared.playRewind()
            effects.update(session: session, viewport: playfieldView.gameViewport, rewinding: true)
            clock.suspend()
            renderCurrentFrame(force: true)
            updateHUD()
        }
    }

    private func handleSteps(_ action: MobileHUDAction, count: Int) {
        guard count > 0, overlay.isHidden, playState.canEdit,
              lifecycle.isForeground, !lifecycle.isInterrupted,
              !session.snapshot.isComplete || (session.isReadOnly && action == .stepBackward) else { return }
        cancelPendingL3ToolDirection()
        switch action {
        case .step:
            guard playState.canStep else { return }
            playfieldView.cancelInteraction()
            var advanced = false
            for _ in 0..<count { guard session.stepForward() else { break }; advanced = true }
            guard advanced else { return }
            effects.update(session: session, viewport: playfieldView.gameViewport)
            clock.suspend()
            renderCurrentFrame(force: true)
            saveCheckpoint(reason: .periodic)
            updateHUD()
            if session.snapshot.isComplete { presentCompletion() }
        case .stepBackward:
            if session.isReadOnly { completionPresented = false }
            if !paused { pauseForPlanning() }
            playfieldView.cancelInteraction()
            var rewound = false
            for _ in 0..<count { guard session.stepBackward() else { break }; rewound = true }
            guard rewound else { return }
            MobileMusic.shared.playRewind()
            effects.update(session: session, viewport: playfieldView.gameViewport, rewinding: true)
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
            updateHUD()
        default: break
        }
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
            track: music.currentTrackTitle, audio: musicState + "   /   " + soundState,
            usedBonusSkill: session.bonusSkillID != nil)
    }

    func showOverlay(title: String, actions: [(String, () -> Void)], results: Bool = false, pauseOverview: Bool = false) {
        hintRequestID = UUID()
        replayExportRequestID = UUID()
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
                + (session.bonusSkillID == nil ? [] : [L10n.text("Bonus skill used")])
        } else if completed {
            let awards = Set(resultAchievements.map(\.title))
            let elapsed = Double(snapshot.tick) / session.ticksPerSecond
            let time = "\(Int(elapsed) / 60):\(String(format: "%05.2f", elapsed.truncatingRemainder(dividingBy: 60)))"
            let recordTime = completionDetails.first { $0.hasPrefix(L10n.text("New time record")) }
            details = [L10n.text("Saved \(snapshot.saved)/\(snapshot.total)   Goal \(snapshot.required)"), recordTime ?? L10n.text("Time ") + time]
                + resultReceiptTitles
                + completionDetails.filter { !awards.contains($0) && !$0.hasPrefix(L10n.text("New time record")) }
        } else { details = [] }
        let heading = completed ? (snapshot.didWin ? L10n.text("Level complete") : L10n.text("Try again")) : (ready ? (turn?.ownerName ?? title) : title)
        let subtitle = summary.caption
        let wasHidden = overlay.isHidden
        overlayCanvas.page = .init(title: heading, subtitle: subtitle,
                                   details: (ready && turn == nil ? [] : [summary.title]) + details,
                                   footer: actions.enumerated().map { .init(String($0.offset), $0.element.0, enabled: $0.element.0 != levelSkipTitle || canSpendLevelSkip,
                                       primary: $0.offset == 0) },
                                   preview: ready || completed)
        if !(ready && turn == nil) && !completed { overlayCanvas.page.detailTitles = [0] }
        overlayCanvas.page.result = completed
        if completed {
            overlayCanvas.page.detailHeadings = [0]
            updateResultAchievements()
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
            overlayCanvas.previewSource = menuPreviewSource(frame: frame)
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

    private func menuPreviewSource(frame: MobilePixelFrame) -> CGRect {
        if playState.phase == .ready {
            let source = MobileMenuPreview.sourceRect(frame: frame, origin: session.menuPreviewOrigin,
                                                     renderScale: session.renderScale)
            return CGRect(x: source.x, y: source.y, width: source.width, height: source.height)
        }
        let visible = playfieldView.gameViewport.visibleLevelRect
        return CGRect(x: visible.x * session.renderScale, y: visible.y * session.renderScale,
                      width: visible.width * session.renderScale, height: visible.height * session.renderScale)
    }

    /// Keep the caller's page and actions together when opening a temporary page.
    func overlayReturnAction() -> () -> Void {
        guard !overlay.isHidden else { return { [weak self] in self?.pausePlay(showControls: true) } }
        let page = overlayCanvas.page
        let actions = overlayActions
        let onAction = overlayCanvas.onAction
        let help = overlayCanvas.actionHelp
        let focus = overlayCanvas.focusedID
        let stars = overlayCanvas.resultStars
        let preview = overlayCanvas.preview
        let previewSource = overlayCanvas.previewSource
        let offset = overlay.contentOffset
        return { [weak self] in
            guard let self else { return }
            self.showOverlay(title: page.title, actions: [])
            self.overlayActions = actions
            self.overlayCanvas.page = page
            self.overlayCanvas.onAction = onAction
            self.overlayCanvas.actionHelp = help
            self.overlayCanvas.focusedID = focus
            self.overlayCanvas.resultStars = stars
            self.overlayCanvas.preview = preview
            self.overlayCanvas.previewSource = previewSource
            self.overlay.bounces = page.pause == nil
            #if os(tvOS)
            self.overlay.panGestureRecognizer.isEnabled = page.pause != nil && page.footer.count == 1
            #endif
            self.layoutOverlay()
            let maximum = max(0, self.overlay.contentSize.height - self.overlay.bounds.height)
            self.overlay.setContentOffset(CGPoint(x: offset.x, y: min(offset.y, maximum)), animated: false)
            #if os(tvOS)
            self.setNeedsFocusUpdate()
            self.updateFocusIfNeeded()
            #endif
            UIAccessibility.post(notification: .screenChanged, argument: self.overlayCanvas)
        }
    }

    func showCustomOverlay(title: String, details: [String], reading: Bool = false, list: Bool = false,
                           headings: Set<Int> = [], actions: [(String, () -> Void)]) {
        showOverlay(title: title, actions: actions)
        var page = GameFrontEnd.Page(title: title, details: details,
            footer: actions.enumerated().map { .init(String($0.offset), $0.element.0, primary: $0.offset == 0) })
        page.reading = reading; page.listDetails = list; page.detailHeadings = headings
        overlayCanvas.page = page
        layoutOverlay()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === overlay, overlayCanvas.page.pause != nil {
            overlayCanvas.setNeedsLayout()
        }
    }

    private func clearSplitResult() {
        if showsSplitResult, overlayCanvas.page.result {
            overlayCanvas.resultStars = onResultAwards?().stars
            setResultReceiptsVisible(true)
        }
        achievementScroll.isHidden = true
        showsSplitResult = false
        overlayCanvas.splitResult = false
        hud.isHidden = false
        view.accessibilityElements = nil
    }

    private func setResultReceiptsVisible(_ visible: Bool) {
        let receipts = resultReceiptTitles
        guard overlayCanvas.page.result, !receipts.isEmpty else { return }
        let titles = Set(receipts)
        overlayCanvas.page.details.removeAll { titles.contains($0) }
        if visible { overlayCanvas.page.details.insert(contentsOf: receipts, at: min(3, overlayCanvas.page.details.count)) }
    }

    private func layoutSplitResult(navigationBottom: CGFloat) -> CGRect? {
        guard overlayCanvas.page.result, !session.isReadOnly else { clearSplitResult(); return nil }
        let safe = view.safeAreaLayoutGuide.layoutFrame
        let panes = MobileDisplayRegions.resultPanes(in: .init(x: safe.minX, y: safe.minY,
            width: safe.width, height: safe.height), avoiding: MobileSystemRegions.read(in: view)).map { pane in
                let top = max(pane.minY, min(pane.maxY, navigationBottom))
                return MobileRect(x: pane.minX, y: top, width: pane.width, height: pane.maxY - top)
            }
        guard panes.count == 2 else {
            let wasSplit = showsSplitResult
            clearSplitResult()
            if wasSplit { updateResultAchievements() }
            return nil
        }
        let firstPresentation = !showsSplitResult
        showsSplitResult = true
        setResultReceiptsVisible(false)
        overlayCanvas.splitResult = true
        overlayCanvas.resultStars = nil
        achievementTask?.cancel(); achievementTask = nil
        if !overlayCanvas.page.rows.isEmpty { overlayCanvas.page.rows = [] }
        overlayCanvas.actionHelp = [:]
        var items = onResultAchievements?() ?? []
        let titles = Set(items.map(\.title))
        let covered = titles.union([
            titles.contains(L10n.text("+1 LEVEL SKIP")) ? L10n.text("Level skip earned") : "",
            titles.contains(ArcadeLevelAchievement.betterRescue.title) ? L10n.text("New rescue record") : "",
            titles.contains(ArcadeLevelAchievement.fewerSkills.title) ? L10n.text("New skill record") : ""
        ])
        items += resultAchievements.filter { !covered.contains($0.title) }.map { .init($0.title, detail: $0.detail) }
        let page = MobileResultAchievementsArt.page(items)
        if achievementCanvas.page != page { achievementCanvas.page = page }
        achievementScroll.setViewportFrame(Self.cgRect(panes[1]))
        let size = achievementCanvas.size(width: achievementScroll.bounds.width, minimumHeight: achievementScroll.bounds.height)
        achievementCanvas.frame = CGRect(origin: .zero, size: size)
        achievementScroll.contentSize = size
        if firstPresentation { achievementScroll.contentOffset = .zero }
        achievementScroll.isHidden = false
        hud.isHidden = true
        overlay.accessibilityViewIsModal = false
        view.accessibilityElements = [globalNavigation, overlay, achievementScroll]
        return Self.cgRect(panes[0])
    }

    func layoutOverlay() {
        guard !overlay.isHidden else { return }
        var region = MobileSystemRegions.menuFrame(in: view)
        layoutSolutionSelector()
        overlay.accessibilityViewIsModal = solutionSelector.isHidden
        if let content = solutionPanelContentFrame { region = content }
        globalNavigation.isHidden = false
        globalNavigation.isUserInteractionEnabled = !displayUpdatesSuspended
        globalNavigation.secondaryTitle = playState.phase == .ready || session.snapshot.isComplete
            || overlayCanvas.page.pause != nil ? nil : L10n.text("Pause menu")
        let navigationHeight = globalNavigation.height(for: region.width)
        globalNavigation.frame = CGRect(x: region.minX, y: region.minY, width: region.width, height: navigationHeight)
        view.bringSubviewToFront(globalNavigation)
        region.origin.y += navigationHeight
        region.size.height -= navigationHeight
        if let resultPane = layoutSplitResult(navigationBottom: region.minY) { region = resultPane }
        overlay.setViewportFrame(region)
        let size = overlayCanvas.size(width: max(280, region.width), minimumHeight: region.height)
        overlayCanvas.frame = CGRect(origin: .zero, size: size)
        overlay.contentSize = size
        #if os(tvOS)
        overlay.isScrollEnabled = !overlayCanvas.page.televisionGrid
        if !overlay.isScrollEnabled { overlay.contentOffset = .zero }
        #endif
        overlay.accessibilityViewIsModal = false
        view.accessibilityElements = [globalNavigation]
            + (solutionSelector.isHidden ? [] : [solutionSelector]) + [overlay]
            + (achievementScroll.isHidden ? [] : [achievementScroll])
    }

    private static func cgRect(_ rect: MobileRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }
}
#endif
