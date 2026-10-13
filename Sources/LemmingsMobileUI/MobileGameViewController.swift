#if os(iOS)
import LemmingsGameArt
import LemmingsMobileCore
import UIKit

@MainActor enum MobileGameExitAction {
    case library
    case retry
    case next
}

@MainActor final class MobileGameViewController: UIViewController {
    var onExit: ((MobileGameExitAction) -> Void)?
    var onCompleted: ((MobileGameSnapshot) -> Void)?

    private let summary: MobileLevelSummary
    private let session: any MobileGameSession
    private let checkpointStore: MobileCheckpointStore
    private let runID: UUID

    private let playfieldView: MobilePlayfieldView
    private let hud = MobileHUDView()
    private let touchLoupe = MobileTouchLoupe()
    private let overlay = UIScrollView()
    private let overlayCanvas = MobileMenuCanvas()
    private var overlayActions: [() -> Void] = []
    private var latestFrame: MobilePixelFrame?

    private var selectedControl: Int
    private var lifecycle = MobileLifecycleState()
    private var clock: MobileTickClock
    private var displayLink: CADisplayLink?
    private var playState = MobilePlayState()
    private var paused: Bool { playState.isPaused }
    private var speed = 1.0
    private var fastSpeed = 2.0
    private var previewPoint: MobilePoint?
    private var highlightedTarget: MobileTargetSelection?
    private var lastRenderedTick = -1
    private var lastCheckpointTick = -1
    private var endRunArmedUntil = 0.0
    private var completionPresented = false
    private var lastPlayfieldFrame: CGRect?
    private let observers = MobileNotificationObserverBag()
    private let audio = MobileAudioSessionController()

    init(
        summary: MobileLevelSummary,
        session: any MobileGameSession,
        checkpointStore: MobileCheckpointStore,
        restoredCheckpoint: MobileCheckpointEnvelope?
    ) {
        self.summary = summary
        self.session = session
        self.checkpointStore = checkpointStore
        runID = restoredCheckpoint?.runID ?? UUID()
        selectedControl = min(
            max(0, restoredCheckpoint?.selectedControl ?? 0),
            max(0, session.snapshot.skills.count - 1)
        )
        clock = MobileTickClock(ticksPerSecond: session.ticksPerSecond)
        let savedSpeed = UserDefaults.standard.integer(forKey: "mobile.fastSpeed")
        fastSpeed = [2, 3, 5, 10].contains(savedSpeed) ? Double(savedSpeed) : 2
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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(playfieldView)
        view.addSubview(hud)
        view.addSubview(touchLoupe)
        configureOverlay()

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
        observeSystemState()
        startDisplayLink()
        updatePerformanceBudget()
        updateHUD()
        renderCurrentFrame(force: true)
        showOverlay(
            title: summary.title,
            actions: [
                ("START", { [weak self] in self?.resumePlay() }),
                ("LIBRARY", { [weak self] in self?.leaveToLibrary() }),
            ]
        )

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startDisplayLink()
        updatePerformanceBudget()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let insets = view.safeAreaInsets
        let layout = hudLayout(insets: insets)
        playfieldView.frame = Self.cgRect(layout.interface.playfieldFrame)
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
        audio.suspend()
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(displayFrame(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func displayFrame(_ link: CADisplayLink) {
        if endRunArmedUntil > 0, link.timestamp > endRunArmedUntil {
            endRunArmedUntil = 0
            updateHUD()
        }
        guard !paused, !session.snapshot.isComplete else { return }
        let ticks = clock.advance(at: link.timestamp)
        guard ticks > 0 else { return }
        for _ in 0..<ticks where !session.snapshot.isComplete { session.tick() }
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
            skillCount: session.snapshot.skills.count
        )
    }

    private func handle(_ action: MobileHUDAction) {
        guard overlay.isHidden, playState.canEdit,
              lifecycle.isForeground, !lifecycle.isInterrupted,
              !session.snapshot.isComplete else { return }
        switch action {
        case let .releaseRate(delta):
            _ = session.adjustReleaseRate(by: delta)
            saveCheckpoint(reason: .periodic)
        case let .skill(index):
            guard session.snapshot.skills.indices.contains(index) else { return }
            selectedControl = index
            if !UserDefaults.standard.bool(forKey: "mobile.continuousSkillSelection") { pauseForPlanning() }
            highlightedTarget = previewPoint.flatMap(target)
            saveCheckpoint(reason: .periodic)
        case .pause:
            paused ? resumePlay() : pauseForPlanning()
        case .step:
            guard playState.canStep else { return }
            playfieldView.cancelInteraction()
            session.tick()
            clock.suspend()
            renderCurrentFrame(force: true)
            saveCheckpoint(reason: .periodic)
            if session.snapshot.isComplete { presentCompletion() }
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
            // A tap holds fast-forward and returns to normal, as on the Mac.
            if speed > 1 { fastSpeed = speed; speed = 1 } else { speed = fastSpeed }
            clock.speed = speed
            updatePerformanceBudget()
        case let .speedStep(direction):
            let speeds = [1.0, 2.0, 3.0, 5.0, 10.0]
            let current = speeds.firstIndex(of: speed) ?? 0
            speed = speeds[min(speeds.count - 1, max(0, current + direction))]
            if speed > 1 { fastSpeed = speed }
            clock.speed = speed
            updatePerformanceBudget()
        }
        updateHUD()
    }

    private func handle(_ effects: [MobileTouchEffect]) {
        guard overlay.isHidden, playState.canEdit,
              lifecycle.isForeground, !lifecycle.isInterrupted,
              !session.snapshot.isComplete else { return }
        var needsFrame = false
        for effect in effects {
            switch effect {
            case let .preview(point), let .movePreview(point):
                previewPoint = point
                highlightedTarget = target(at: point)
                needsFrame = true
            case let .commit(point):
                previewPoint = nil
                if let selection = target(at: point), selection.state == .eligible {
                    _ = session.assign(control: selectedControl, to: selection.id)
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

    private func target(at point: MobilePoint) -> MobileTargetSelection? {
        let preference: MobileTargetPreference = session.engineIdentifier == "lemmings3"
            && selectedControl >= 3 ? .toolHolder : .assignable
        return MobileTargetSelector.select(
            candidates: session.targetCandidates(for: selectedControl),
            touch: point,
            viewport: playfieldView.gameViewport,
            radius: 30,
            preference: preference
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

    private func renderCurrentFrame(force: Bool) {
        let tick = session.snapshot.tick
        guard force || tick != lastRenderedTick else { return }
        do {
            let frame = try session.render(highlight: highlightedTarget)
            latestFrame = frame
            try playfieldView.update(frame: frame)
            if !overlay.isHidden, overlayCanvas.page.preview {
                overlayCanvas.preview = MobileBitmapRenderer.image(frame)
                let visible = playfieldView.gameViewport.visibleLevelRect
                overlayCanvas.previewSource = CGRect(x: visible.x, y: visible.y, width: visible.width, height: visible.height)
            }
            hud.updateMinimap(frame: frame, visible: playfieldView.gameViewport.visibleLevelRect,
                              levelSize: session.levelSize)
            if let point = previewPoint, let target = highlightedTarget {
                touchLoupe.update(bitmap: frame, target: target.point,
                                  finger: playfieldView.convert(CGPoint(x: point.x, y: point.y), to: view),
                                  bounds: playfieldView.frame,
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

    private func pausePlay(showControls: Bool) {
        playState.suspend()
        playfieldView.cancelInteraction()
        previewPoint = nil
        highlightedTarget = nil
        touchLoupe.isHidden = true
        clock.suspend()
        audio.suspend()
        updateHUD()
        guard showControls else { return }
        showOverlay(
            title: "PAUSED",
            actions: [
                ("RESUME", { [weak self] in self?.resumePlay() }),
                ("LIBRARY", { [weak self] in self?.leaveToLibrary() }),
            ]
        )
    }

    private func pauseForPlanning() {
        guard playState.pauseForPlanning() else { return }
        playfieldView.cancelInteraction()
        previewPoint = nil
        highlightedTarget = nil
        touchLoupe.isHidden = true
        clock.suspend()
        audio.suspend()
        renderCurrentFrame(force: true)
        updateHUD()
    }

    private func resumePlay() {
        guard !session.snapshot.isComplete,
              playState.resume(isForeground: lifecycle.isForeground, isInterrupted: lifecycle.isInterrupted) else { return }
        let needsLifecycleResume = lifecycle.requiresPlayerResume
        if needsLifecycleResume {
            applyEffects(lifecycle.handle(.playerRequestedResume))
        }
        guard lifecycle.isForeground, !lifecycle.isInterrupted else { return }
        if !needsLifecycleResume { try? audio.resume() }
        clock.suspend()
        playfieldView.cancelInteraction()
        overlay.isHidden = true
        overlay.accessibilityViewIsModal = false
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
        Task { try? await checkpointStore.retire(runID: runID) }
        let snapshot = session.snapshot
        onCompleted?(snapshot)
        let result = snapshot.didWin
            ? "LEVEL COMPLETE\n\(snapshot.saved) SAVED"
            : "LEVEL ENDED\n\(snapshot.saved) SAVED"
        let actions: [(String, () -> Void)]
        if snapshot.didWin {
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
        showOverlay(title: result, actions: actions, results: true)
    }

    private func finish(_ action: MobileGameExitAction) {
        displayLink?.isPaused = true
        audio.suspend()
        Task {
            try? await checkpointStore.retire(runID: runID)
            onExit?(action)
        }
    }

    private func leaveToLibrary() {
        playState.suspend()
        clock.suspend()
        displayLink?.isPaused = true
        audio.suspend()
        guard !session.snapshot.isComplete else {
            finish(.library)
            return
        }
        showOverlay(title: "SAVING...", actions: [])
        do {
            let envelope = try makeCheckpoint()
            Task { [self] in
                do {
                    try await checkpointStore.save(envelope)
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
        guard !session.snapshot.isComplete else { return }
        do {
            let envelope = try makeCheckpoint()
            lastCheckpointTick = envelope.tick
            let backgroundTask: UIBackgroundTaskIdentifier
            if reason == .suspension || reason == .sceneDisconnect || reason == .audioInterruption {
                backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Save Lemmings run")
            } else {
                backgroundTask = .invalid
            }
            Task {
                defer {
                    if backgroundTask != .invalid {
                        UIApplication.shared.endBackgroundTask(backgroundTask)
                    }
                }
                try? await checkpointStore.save(envelope)
            }
        } catch {
            // The current run stays in memory. A later lifecycle save can retry.
        }
    }

    private func makeCheckpoint() throws -> MobileCheckpointEnvelope {
        let viewport = playfieldView.gameViewport
        return MobileCheckpointEnvelope(
            runID: runID,
            engine: session.engineIdentifier,
            engineFingerprint: session.engineFingerprint,
            levelIdentifier: session.levelIdentifier,
            levelIndex: session.levelIndex,
            levelFingerprint: session.levelFingerprint,
            tick: session.snapshot.tick,
            selectedControl: selectedControl,
            camera: MobileCameraState(origin: viewport.origin, zoom: viewport.zoom),
            payload: try session.checkpointPayload()
        )
    }

    private func observeSystemState() {
        let centre = NotificationCenter.default
        func observe(_ name: Notification.Name, _ event: MobileLifecycleEvent) {
            observers.append(centre.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.applyLifecycle(event) }
            })
        }
        observe(UIApplication.willResignActiveNotification, .becameInactive)
        observe(UIApplication.didEnterBackgroundNotification, .enteredBackground)
        observe(UIApplication.didBecomeActiveNotification, .becameActive)
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
                audio.suspend()
            case .prepareAudio:
                try? audio.prepare()
                renderCurrentFrame(force: true)
            case .resumeAudio:
                try? audio.resume()
            case .showResumeControl:
                if overlay.isHidden { pausePlay(showControls: true) }
            case .purgeTransientResources:
                session.releaseTransientResources()
                // The visible bitmap is the current frame, not a transient cache.
            }
        }
        updateHUD()
    }

    private func updatePerformanceBudget() {
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
            reduceFlashes: UIAccessibility.isReduceMotionEnabled
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

    private func updateHUD(layout: MobileHUDLayout? = nil) {
        let resolved = layout ?? hudLayout(insets: view.safeAreaInsets)
        hud.update(
            layout: resolved,
            snapshot: session.snapshot,
            selectedSkill: selectedControl,
            paused: paused,
            speed: speed,
            endRunArmed: endRunArmedUntil > ProcessInfo.processInfo.systemUptime,
            panel: session.panelFrame
        )
    }

    private func makeInterfaceLayout() -> MobileInterfaceLayout {
        let insets = view.safeAreaInsets
        let direction: MobileLayoutDirection = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
            ? .rightToLeft
            : .leftToRight
        return MobileLayoutEngine.make(
            container: MobileSize(width: view.bounds.width, height: view.bounds.height),
            safeArea: MobileInsets(top: insets.top, left: insets.left,
                                   bottom: insets.bottom, right: insets.right),
            controlCount: controlCount,
            direction: direction
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

    func showPreparationError(_ message: String) {
        showOverlay(title: message, actions: [("LIBRARY", { [weak self] in self?.onExit?(.library) })])
    }

    private func showOverlay(title: String, actions: [(String, () -> Void)], results: Bool = false) {
        overlayActions = actions.map { $0.1 }
        let snapshot = session.snapshot
        let ready = playState.phase == .ready
        let completed = results
        let details: [String]
        if ready {
            details = ["\(snapshot.total) Lemmings   Save \(snapshot.required)",
                       snapshot.remainingSeconds.map { "Time \($0 / 60):\(String(format: "%02d", $0 % 60))" } ?? "No time limit"]
        } else if completed {
            details = ["Saved \(snapshot.saved) of \(snapshot.total)", "Required \(snapshot.required)"]
        } else { details = [] }
        let heading = completed ? (snapshot.didWin ? "Level complete" : "Try again") : title
        let subtitle = ready ? "\(summary.rank) \(summary.number)" : "\(summary.rank) \(summary.number)  \(summary.title)"
        overlayCanvas.page = .init(title: heading, subtitle: subtitle,
                                   details: details,
                                   footer: actions.enumerated().map { .init(String($0.offset), $0.element.0, primary: $0.offset == 0) },
                                   preview: ready || completed)
        if let frame = latestFrame {
            overlayCanvas.preview = MobileBitmapRenderer.image(frame)
            let visible = playfieldView.gameViewport.visibleLevelRect
            overlayCanvas.previewSource = CGRect(x: visible.x, y: visible.y, width: visible.width, height: visible.height)
        }
        overlay.isHidden = false
        overlay.accessibilityViewIsModal = true
        playfieldView.accessibilityElementsHidden = true
        hud.accessibilityElementsHidden = true
        layoutOverlay()
        UIAccessibility.post(notification: .screenChanged, argument: overlayCanvas)
    }

    private func layoutOverlay() {
        guard !overlay.isHidden else { return }
        let insets = view.safeAreaInsets
        let width = max(280, overlay.bounds.width - insets.left - insets.right)
        let size = overlayCanvas.size(width: width, minimumHeight: overlay.bounds.height - insets.top - insets.bottom)
        overlayCanvas.frame = CGRect(x: insets.left, y: insets.top, width: size.width, height: size.height)
        overlay.contentSize = CGSize(width: overlay.bounds.width, height: size.height + insets.top + insets.bottom)
    }

    private static func cgRect(_ rect: MobileRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }
}
#endif
