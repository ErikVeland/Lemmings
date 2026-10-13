#if os(iOS)
import LemmingsAppCore
import NxlvKit
import LemmingsGameArt
import LemmingsMobileCore
import UIKit

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
    /// The result buttons for a win or a loss, each naming the player who acts next.
    let choices: (Bool) -> [(label: String, choice: MobileHotSeat.Choice)]
}

@MainActor final class MobileGameViewController: UIViewController {
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
    private var rewindHeld = false
    private var lastRewindTime = 0.0
    var onCompleted: ((MobileGameSnapshot) -> Void)?

    let summary: MobileLevelSummary
    private let gameSettings: MobileSettings
    let session: any MobileGameSession
    let checkpointStore: MobileCheckpointStore
    let runID: UUID
    var recordRunID: UUID { runID }
    var musicContext = MobileMusicContext()
    private let turn: MobileGameTurn?
    private let turnBadge = MobilePixelLabel()

    let playfieldView: MobilePlayfieldView
    let hud = MobileHUDView()
    private let touchLoupe = MobileTouchLoupe()
    let overlay = UIScrollView()
    let overlayCanvas = MobileMenuCanvas()
    private var overlayActions: [() -> Void] = []
    private var latestFrame: MobilePixelFrame?

    private var lastHUDLayout: MobileHUDLayout?
    private var layoutSuspended = false
    var selectedControl: Int
    var lifecycle = MobileLifecycleState()
    private weak var owningScene: UIWindowScene?
    var clock: MobileTickClock
    private var displayLink: CADisplayLink?
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
    var highlightedTarget: MobileTargetSelection?
    private var lastRenderedTick = -1
    private var lastCheckpointTick = -1
    private var endRunArmedUntil = 0.0
    private var completionPresented = false
    private let observers = MobileNotificationObserverBag()
    private let audio = MobileAudioSessionController()
    let effects = MobileEffects()
    private let nowPlaying = MobileNowPlayingView()
    private let replaySkillInfo = MobileReplaySkillView()
    private var countdown = GameplayStartCountdown()
    private let countdownLabel = MobilePixelLabel()
    private let freshStart: Bool
    private var lastVisibleTimestamp: Double?

    init(
        summary: MobileLevelSummary,
        session: any MobileGameSession,
        checkpointStore: MobileCheckpointStore,
        restoredCheckpoint: MobileCheckpointEnvelope?,
        turn: MobileGameTurn? = nil
    ) {
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
        let settings = MobileSettings.load(from: .standard)
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
        playfieldView = MobilePlayfieldView(viewport: viewport, automaticallyFitsViewport: camera == nil)
        super.init(nibName: nil, bundle: nil)
        modalPresentationCapturesStatusBarAppearance = true
    }

    required init?(coder: NSCoder) { nil }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var keyCommands: [UIKeyCommand]? { gameplayKeyCommands }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(playfieldView)
        view.addSubview(hud)
        view.addSubview(touchLoupe)
        view.addSubview(nowPlaying)
        view.addSubview(replaySkillInfo)
        countdownLabel.palette = .green
        countdownLabel.maximumScale = 6
        countdownLabel.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        countdownLabel.isHidden = true
        countdownLabel.isUserInteractionEnabled = false
        view.addSubview(countdownLabel)
        MobileMusic.shared.onTrackChange = { [weak self] title, soundtrack in
            guard let self, !self.paused, !self.session.snapshot.isComplete, self.overlay.isHidden else { return }
            self.nowPlaying.show(title: title, soundtrack: soundtrack)
        }
        if let turn {
            turnBadge.text = turn.ownerName.uppercased()
            turnBadge.palette = .green
            turnBadge.alignment = .left
            turnBadge.maximumScale = 2
            turnBadge.isUserInteractionEnabled = false
            view.addSubview(turnBadge)
        }
        playfieldView.displaySettings = gameSettings.classic
        configureOverlay()

        onHints = { [weak self] in self?.showHints() }
        onControlsHelp = { [weak self] in self?.showControlsHelp() }
        hud.onRewindHold = { [weak self] held in self?.setRewindHeld(held) }
        hud.onAction = { [weak self] action in self?.handle(action) }
        playfieldView.onTouchEffects = { [weak self] effects in self?.handle(effects) }
        hud.onMinimap = { [weak self] point in self?.scrollToLevelX(point.x) }
        playfieldView.onViewportChanged = { [weak self] _ in self?.renderCurrentFrame(force: true) }
        audio.onEvent = { [weak self] event in
            switch event {
            case .interruptionBegan, .outputRouteLost:
                self?.applyLifecycle(.audioInterruptionBegan)
            case .interruptionEnded:
                self?.applyLifecycle(.audioInterruptionEnded)
            }
        }
        try? audio.prepare()
        effects.prepare()
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
        startDisplayLink()
        updatePerformanceBudget()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let scene = view.window?.windowScene { owningScene = scene }
        let insets = view.safeAreaInsets
        let layout = hudLayout(insets: insets)
        if let previous = lastHUDLayout, previous != layout {
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
        nowPlaying.frame = CGRect(x: playfieldView.frame.minX + 8, y: playfieldView.frame.minY + 8,
                                  width: min(320, playfieldView.frame.width - 16), height: 60)
        countdownLabel.frame = CGRect(x: playfieldView.frame.midX - 44, y: playfieldView.frame.midY - 44, width: 88, height: 88)
        let replayWidth = min(MobileReplaySkillArt.size.width, max(0, playfieldView.frame.width - 16))
        replaySkillInfo.frame = CGRect(x: playfieldView.frame.maxX - replayWidth - 8, y: playfieldView.frame.minY + 8,
            width: replayWidth, height: replayWidth * MobileReplaySkillArt.size.height / MobileReplaySkillArt.size.width)
        hud.frame = view.bounds
        if turn != nil {
            let field = playfieldView.frame
            turnBadge.frame = CGRect(x: field.minX + 6, y: field.minY + 4, width: min(field.width - 12, 220), height: 20)
        }
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
        inputAdapter.poll(context: ObjectIdentifier(overlay.isHidden ? playfieldView : overlayCanvas), at: link.timestamp)
        updateInputSpeed(at: link.timestamp)
        MobileMusic.shared.advance()
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
        if rewindHeld {
            guard lifecycle.isForeground, !lifecycle.isInterrupted, overlay.isHidden else { setRewindHeld(false); return }
            if link.timestamp - lastRewindTime >= 0.08 {
                lastRewindTime = link.timestamp
                _ = session.rewind(seconds: 0.4)
                effects.update(session: session, viewport: playfieldView.gameViewport, rewinding: true)
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
        for _ in 0..<ticks where !session.snapshot.isComplete {
            session.tick()
            effects.update(session: session, viewport: playfieldView.gameViewport)
        }
        if let previewPoint { highlightedTarget = target(at: previewPoint) }
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
            supportsRewind: session.supportsRewind
        )
    }

    func handle(_ action: MobileHUDAction) {
        guard overlay.isHidden, playState.canEdit,
              lifecycle.isForeground, !lifecycle.isInterrupted,
              !session.snapshot.isComplete || (session.isReadOnly && [.pause, .rewind, .stepBackward, .menu].contains(action)) else { return }
        switch action {
        case let .releaseRate(delta):
            if session.adjustReleaseRate(by: delta), let rate = session.snapshot.releaseRate { effects.releaseRate(rate) }
            saveCheckpoint(reason: .periodic)
        case let .skill(index):
            guard session.snapshot.skills.indices.contains(index) else { return }
            selectedControl = index
            if gameSettings.pauseToAssign { pauseForPlanning() }
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
            if action == .rewind { _ = session.rewind(seconds: 2) }
            else { _ = session.stepBackward() }
            clock.suspend()
            highlightedTarget = nil
            previewPoint = nil
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

    private func handle(_ touchEffects: [MobileTouchEffect]) {
        guard !session.isReadOnly, overlay.isHidden, playState.canEdit,
              lifecycle.isForeground, !lifecycle.isInterrupted,
              !session.snapshot.isComplete else { return }
        var needsFrame = false
        for effect in touchEffects {
            switch effect {
            case let .preview(point), let .movePreview(point):
                previewPoint = point
                highlightedTarget = target(at: point)
                needsFrame = true
            case let .commit(point):
                previewPoint = nil
                if let selection = target(at: point), selection.state == .eligible {
                    let accepted = session.assign(control: selectedControl, to: selection.id)
                    effects.assignment(accepted: accepted)
                    if accepted { lastInputAssignment = selection; lastAssignmentControl = selectedControl }
                    highlightedTarget = selection
                    saveCheckpoint(reason: .periodic)
                } else {
                    highlightedTarget = target(at: point)
                }
                needsFrame = true
            case let .pan(delta):
                previewPoint = nil
                highlightedTarget = nil
                playfieldView.stopAutomaticFitting()
                playfieldView.gameViewport.pan(viewDelta: delta)
                needsFrame = true
            case .cancelPreview:
                previewPoint = nil
                highlightedTarget = nil
                needsFrame = true
            }
        }
        if needsFrame {
            renderCurrentFrame(force: true)
            updateHUD()
        }
    }

    func target(at point: MobilePoint) -> MobileTargetSelection? {
        let settings = gameSettings.classic
        let preference: MobileTargetPreference
        if session.engineIdentifier == "classic-dos", selectedControl == 4, settings.favorBuilders { preference = .builder }
        else if session.engineIdentifier == "classic-dos", selectedControl == 2, settings.favorBombBlockers { preference = .bombBlocker }
        else if session.engineIdentifier == "lemmings3", selectedControl >= 3 { preference = .toolHolder }
        else { preference = .assignable }
        return MobileTargetSelector.select(
            candidates: session.targetCandidates(for: selectedControl),
            touch: point,
            viewport: playfieldView.gameViewport,
            radius: 30,
            preference: preference,
            favourApproaching: settings.favorApproachingLemmings
        )
    }

    private func scrollToLevelX(_ x: CGFloat) {
        guard overlay.isHidden else { return }
        var viewport = playfieldView.gameViewport
        viewport.origin = MobilePoint(x: Double(x) - viewport.visibleLevelSize.width / 2, y: viewport.origin.y)
        viewport.clamp()
        playfieldView.stopAutomaticFitting()
        playfieldView.gameViewport = viewport
        renderCurrentFrame(force: true)
    }

    func renderCurrentFrame(force: Bool) {
        let tick = session.snapshot.tick
        guard force || tick != lastRenderedTick else { return }
        do {
            let frame = try session.render(highlight: highlightedTarget)
            latestFrame = frame
            playfieldView.renderScale = session.renderScale
            playfieldView.explosions = session.explosions
            playfieldView.selectionPoint = highlightedTarget?.point
            playfieldView.cursorPoint = previewPoint.map { playfieldView.gameViewport.levelPoint(fromView: $0) }
            playfieldView.cursorIcon = session.skillCursorFrame(control: selectedControl).flatMap(MobileBitmapRenderer.image)
            playfieldView.cursorRemaining = session.snapshot.skills.indices.contains(selectedControl) ? session.snapshot.skills[selectedControl].count : nil
            if let point = playfieldView.cursorPoint {
                playfieldView.cursorCount = session.targetCandidates(for: selectedControl).filter { abs($0.point.x - point.x) <= 8 && abs($0.point.y - point.y) <= 8 }.count
            } else { playfieldView.cursorCount = nil }
            playfieldView.selectionSprite = session.selectionSprite
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
            if let point = previewPoint, let target = highlightedTarget {
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
                                  pixelAspect: session.engineIdentifier == "classic-dos" ? 1.2 : 1)
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
        setRewindHeld(false)
        effects.suspend()
        audio.suspend()
        MobileMusic.shared.suspend()
    }

    private func pauseGameplayAudio() {
        setRewindHeld(false)
        effects.pause()
        MobileMusic.shared.setGameplayState(paused: true, speed: speed)
    }

    /// Reactivates the session, then starts this level's tune or lifts its pause.
    private func resumeAudio() {
        effects.resume()
        try? audio.resume()
        MobileMusic.shared.play(identifier: session.levelIdentifier, index: session.levelIndex, title: summary.title,
                                attemptID: runID, context: musicContext)
        MobileMusic.shared.resume()
    }

    func pausePlay(showControls: Bool) {
        playState.suspend()
        playfieldView.cancelInteraction()
        previewPoint = nil
        highlightedTarget = nil
        touchLoupe.isHidden = true
        clock.suspend()
        pauseGameplayAudio()
        updateHUD()
        guard showControls else { return }
        showOverlay(
            title: "PAUSED",
            actions: [
                ("RESUME", { [weak self] in self?.resumePlay() }),
                (session.isReadOnly ? "BACK" : "LIBRARY", { [weak self] in self?.leaveToLibrary() }),
            ] + (session.isReadOnly ? [] : [
                ("HINT", { [weak self] in self?.onHints?() }),
                ("CONTROLS", { [weak self] in self?.onControlsHelp?() }),
            ])
        )
    }

    func pauseForPlanning() {
        countdown.cancel()
        countdownLabel.isHidden = true
        guard playState.pauseForPlanning() else { return }
        playfieldView.cancelInteraction()
        previewPoint = nil
        highlightedTarget = nil
        touchLoupe.isHidden = true
        clock.suspend()
        pauseGameplayAudio()
        renderCurrentFrame(force: true)
        updateHUD()
    }

    func resumePlay() {
        let wasReady = playState.phase == .ready
        guard hudLayout(insets: view.safeAreaInsets).canPlay, !session.snapshot.isComplete,
              playState.resume(isForeground: lifecycle.isForeground, isInterrupted: lifecycle.isInterrupted) else { return }
        if wasReady {
            effects.ready()
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
                self.finish(.next)
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
                try? audio.prepare()
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
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: Float(min(20, budget.framesPerSecond)),
            maximum: Float(budget.framesPerSecond),
            preferred: Float(budget.framesPerSecond)
        )
        let speedCatchUp = Int(ceil(
            session.ticksPerSecond * speed / Double(max(1, budget.framesPerSecond)) * 2
        ))
        clock.maximumCatchUpTicks = max(budget.maximumCatchUpTicks, speedCatchUp)
    }

    func updateHUD(layout: MobileHUDLayout? = nil) {
        MobileMusic.shared.update(session.snapshot, active: session.activeLemmingCount, nukeRemainingTicks: session.nukeRemainingTicks, allNukePopped: session.allNukeExplosionsPlayed, ticksPerSecond: session.ticksPerSecond)
        MobileMusic.shared.setGameplayState(paused: paused, speed: speed, rewinding: rewindHeld)
        let resolved = layout ?? hudLayout(insets: view.safeAreaInsets)
        hud.skillIcons = session.renderScale > 1 ? session.snapshot.skills.indices.map { session.skillCursorFrame(control: $0).flatMap(MobileBitmapRenderer.image) } : []
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
        overlay.backgroundColor = .black
        overlay.accessibilityViewIsModal = true
        overlay.addSubview(overlayCanvas)
        overlayCanvas.onAction = { [weak self] id in
            guard let self, let index = Int(id), self.overlayActions.indices.contains(index) else { return }
            self.overlayActions[index]()
        }
        view.addSubview(overlay)
    }

    func returnToResult() {
        showOverlay(title: completionTitle, actions: completionActions, results: true)
    }

    func showReplay(document: Data) {
        do {
            guard let replay = try session.makeReplaySession(document: document) else { return }
            pausePlay(showControls: false)
            let player = MobileGameViewController(summary: summary, session: replay,
                checkpointStore: checkpointStore, restoredCheckpoint: nil)
            player.modalPresentationStyle = .fullScreen
            present(player, animated: false)
        } catch {
            showOverlay(title: error.localizedDescription,
                actions: [("BACK", { [weak self] in self?.pausePlay(showControls: true) })])
        }
    }

    private func setRewindHeld(_ held: Bool) {
        if held {
            guard session.supportsRewind, overlay.isHidden, playState.canEdit,
                  lifecycle.isForeground, !lifecycle.isInterrupted else { return }
            pauseForPlanning()
            _ = session.rewind(seconds: 2)
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

    func showOverlay(title: String, actions: [(String, () -> Void)], results: Bool = false) {
        nowPlaying.hide()
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
        let details: [String]
        if ready {
            details = ["\(snapshot.total) Lemmings   Save \(snapshot.required)",
                       snapshot.remainingSeconds.map { "Time \($0 / 60):\(String(format: "%02d", $0 % 60))" } ?? "No time limit"]
        } else if completed {
            details = ["Saved \(snapshot.saved) of \(snapshot.total)", "Required \(snapshot.required)"] + completionDetails
        } else { details = [] }
        let heading = completed ? (snapshot.didWin ? "Level complete" : "Try again") : (ready ? (turn?.ownerName ?? title) : title)
        let subtitle = ready && turn == nil ? "\(summary.rank) \(summary.number)" : "\(summary.rank) \(summary.number)  \(summary.title)"
        overlayCanvas.page = .init(title: heading, subtitle: subtitle,
                                   details: details,
                                   footer: actions.enumerated().map { .init(String($0.offset), $0.element.0, primary: $0.offset == 0) },
                                   preview: ready || completed)
        if let frame = latestFrame {
            overlayCanvas.preview = MobileBitmapRenderer.image(frame)
            let visible = playfieldView.gameViewport.visibleLevelRect
            overlayCanvas.previewSource = CGRect(x: visible.x * session.renderScale, y: visible.y * session.renderScale, width: visible.width * session.renderScale, height: visible.height * session.renderScale)
        }
        overlay.isHidden = false
        overlay.accessibilityViewIsModal = true
        playfieldView.isUserInteractionEnabled = false
        hud.isUserInteractionEnabled = false
        playfieldView.accessibilityElementsHidden = true
        hud.accessibilityElementsHidden = true
        layoutOverlay()
        UIAccessibility.post(notification: .screenChanged, argument: overlayCanvas)
    }

    func showCustomOverlay(title: String, details: [String], actions: [(String, () -> Void)]) {
        showOverlay(title: title, actions: actions)
        overlayCanvas.page = .init(title: title, details: details,
            footer: actions.enumerated().map { .init(String($0.offset), $0.element.0, primary: $0.offset == 0) })
        layoutOverlay()
    }

    private func layoutOverlay() {
        guard !overlay.isHidden else { return }
        let region = MobileSystemRegions.menuFrame(in: view)
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
