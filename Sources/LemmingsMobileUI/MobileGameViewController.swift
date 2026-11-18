#if os(iOS) || os(tvOS)
import LemmingsMobileCore
import UIKit

@MainActor enum MobileGameExitAction {
    case library
    case retry
    case next
}

@MainActor final class MobileGameViewController: UIViewController {
    var onExit: ((MobileGameExitAction) -> Void)?

    private let summary: ClassicMobileLevelSummary
    private let session: any MobileGameSession
    private let checkpointStore: MobileCheckpointStore
    private let runID: UUID

    private let metalView: MobileMetalView
    private let hud = MobileHUDView()
    private let overlay = UIView()
    private let overlayTitle = MobilePixelLabel()
    private var overlayButtons: [MobilePixelButton] = []

    private var selectedControl: Int
    private var lifecycle = MobileLifecycleState()
    private var clock: MobileTickClock
    private var displayLink: CADisplayLink?
    private var paused = true
    private var speed = 1.0
    private var previewPoint: MobilePoint?
    private var highlightedTarget: MobileTargetSelection?
    private var lastRenderedTick = -1
    private var lastCheckpointTick = -1
    private var endRunArmedUntil = 0.0
    private var completionPresented = false
    private let observers = MobileNotificationObserverBag()
    private let audio = MobileAudioSessionController()
    private let music: MobileLixMusicPlayer?
    private let controllers = MobileControllerInput()
    private var remoteTargetID: Int?
    private var lastCameraTimestamp = 0.0

    init(
        summary: ClassicMobileLevelSummary,
        session: any MobileGameSession,
        checkpointStore: MobileCheckpointStore,
        restoredCheckpoint: MobileCheckpointEnvelope?,
        configuration: LemmingsMobileConfiguration = .current,
        musicEnabled: Bool = false
    ) {
        self.summary = summary
        self.session = session
        MobileLixArtwork.activate()
        MobileLixArtwork.install(on: session)
        self.checkpointStore = checkpointStore
        runID = restoredCheckpoint?.runID ?? UUID()
        selectedControl = min(
            max(0, restoredCheckpoint?.selectedControl
                ?? session.snapshot.skills.firstIndex(where: { $0.isUnlimited || $0.count > 0 }) ?? 0),
            max(0, session.snapshot.skills.count - 1)
        )
        clock = MobileTickClock(ticksPerSecond: session.ticksPerSecond)
        let camera = restoredCheckpoint?.camera
        let viewport = MobileViewport(
            levelSize: session.levelSize,
            viewSize: MobileSize(width: 1, height: 1),
            origin: camera?.origin ?? MobilePoint(x: 0, y: 0),
            zoom: camera?.zoom,
            pixelAspect: session.engineIdentifier == "classic-dos" ? 1.2 : 1
        )
        metalView = MobileMetalView(viewport: viewport, automaticallyFitsViewport: camera == nil)
        music = configuration == .ultimateLemmix
            ? MobileLixMusicPlayer(resources: Bundle.main.resourceURL, enabled: musicEnabled) : nil
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

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if !overlay.isHidden, let button = overlayButtons.first { return [button] }
        return [metalView]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(metalView)
        view.addSubview(hud)
        configureOverlay()

        hud.onAction = { [weak self] action in self?.handle(action) }
        metalView.onTouchEffects = { [weak self] effects in self?.handle(effects) }
        metalView.onViewportChanged = { [weak self] _ in self?.renderCurrentFrame(force: true) }
        metalView.onRemoteAction = { [weak self] in self?.handleController($0) }
        controllers.onAction = { [weak self] in self?.handleController($0) }
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
            title: "\(summary.rank) \(summary.number)\n\(summary.title)",
            actions: [
                ("START", { [weak self] in self?.resumePlay() }),
                ("LIBRARY", { [weak self] in self?.leaveToLibrary() }),
            ]
        )

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        controllers.start()
        startDisplayLink()
        updatePerformanceBudget()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let insets = view.safeAreaInsets
        let layout = MobileLayoutEngine.make(
            container: MobileSize(width: view.bounds.width, height: view.bounds.height),
            safeArea: MobileInsets(
                top: insets.top,
                left: insets.left,
                bottom: insets.bottom,
                right: insets.right
            ),
            controlCount: controlCount
        )
        metalView.frame = Self.cgRect(layout.playfieldFrame)
        hud.frame = view.bounds
        updateHUD(layout: layout)
        overlay.frame = view.bounds
        layoutOverlay()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        displayLink?.invalidate()
        displayLink = nil
        audio.suspend()
        music?.pause()
        controllers.stop()
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
        let cameraDelta = min(0.05, max(0, link.timestamp - lastCameraTimestamp))
        lastCameraTimestamp = link.timestamp
        guard !paused, !session.snapshot.isComplete else { return }
        let direction = controllers.cameraDirection
        if direction.x != 0 || direction.y != 0 {
            metalView.stopAutomaticFitting()
            metalView.gameViewport.pan(viewDelta: MobilePoint(x: -direction.x * cameraDelta * 280,
                y: -direction.y * cameraDelta * 280))
        }
        let ticks = clock.advance(at: link.timestamp)
        guard ticks > 0 else { return }
        for _ in 0..<ticks where !session.snapshot.isComplete { session.tick() }
        if remoteTargetID != nil || traitCollection.userInterfaceIdiom == .tv {
            refreshRemoteTarget()
        } else if let previewPoint { highlightedTarget = target(at: previewPoint) }
        renderCurrentFrame(force: true)
        updateHUD()
        if session.snapshot.isComplete {
            presentCompletion()
        } else if session.snapshot.tick - lastCheckpointTick >= Int(ceil(session.ticksPerSecond * 5)) {
            saveCheckpoint(reason: .periodic)
        }
    }

    private var controlCount: Int {
        (session.snapshot.releaseRate == nil ? 0 : 2) + session.snapshot.skills.count + 3
    }

    private func handle(_ action: MobileHUDAction) {
        switch action {
        case let .releaseRate(delta):
            _ = session.adjustReleaseRate(by: delta)
            saveCheckpoint(reason: .periodic)
        case let .skill(index):
            selectedControl = index
            highlightedTarget = previewPoint.flatMap(target)
            if remoteTargetID != nil || traitCollection.userInterfaceIdiom == .tv { refreshRemoteTarget() }
            #if os(tvOS)
            UIFocusSystem.focusSystem(for: view)?.requestFocusUpdate(to: metalView)
            UIFocusSystem.focusSystem(for: view)?.updateFocusIfNeeded()
            #endif
        case .pause:
            paused ? resumePlay() : pausePlay(showControls: true)
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
            let speeds = [1.0, 2.0, 3.0, 5.0, 10.0]
            let current = speeds.firstIndex(of: speed) ?? 0
            speed = speeds[(current + 1) % speeds.count]
            clock.speed = speed
            updatePerformanceBudget()
        }
        updateHUD()
    }

    private func handle(_ effects: [MobileTouchEffect]) {
        guard !paused, !session.snapshot.isComplete else { return }
        var needsFrame = false
        for effect in effects {
            switch effect {
            case let .preview(point), let .movePreview(point):
                remoteTargetID = nil
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
                metalView.stopAutomaticFitting()
                metalView.gameViewport.pan(viewDelta: delta)
                needsFrame = true
            case .cancelPreview:
                previewPoint = nil
                highlightedTarget = nil
                needsFrame = true
            }
        }
        if needsFrame { renderCurrentFrame(force: true) }
    }

    private func handleController(_ action: MobileControllerInput.Action) {
        if case .pause = action {
            paused ? resumePlay() : pausePlay(showControls: true)
            return
        }
        guard overlay.isHidden, !session.snapshot.isComplete else { return }
        switch action {
        case let .target(direction):
            let candidates = session.targetCandidates(for: selectedControl).sorted {
                $0.point.x == $1.point.x ? $0.id < $1.id : $0.point.x < $1.point.x
            }
            guard !candidates.isEmpty else { return }
            let current = candidates.firstIndex(where: { $0.id == remoteTargetID })
                ?? (direction < 0 ? 0 : -1)
            let index = (current + direction + candidates.count) % candidates.count
            remoteTargetID = candidates[index].id
            refreshRemoteTarget()
            if let highlightedTarget {
                let point = metalView.gameViewport.viewPoint(fromLevel: highlightedTarget.point)
                let size = metalView.gameViewport.viewSize
                if point.x < 32 || point.x > size.width - 32 || point.y < 24 || point.y > size.height - 24 {
                    metalView.stopAutomaticFitting()
                    metalView.gameViewport.pan(viewDelta: MobilePoint(x: size.width / 2 - point.x,
                        y: size.height / 2 - point.y))
                }
            }
        case let .skill(delta):
            let count = session.snapshot.skills.count
            guard count > 0 else { return }
            selectedControl = (selectedControl + delta + count) % count
            refreshRemoteTarget()
            updateHUD()
        case .assign:
            guard !paused else { return }
            refreshRemoteTarget()
            if let selected = highlightedTarget, selected.state == .eligible {
                _ = session.assign(control: selectedControl, to: selected.id)
                saveCheckpoint(reason: .periodic)
                refreshRemoteTarget()
                updateHUD()
            }
        case .pause: break
        }
        renderCurrentFrame(force: true)
    }

    private func refreshRemoteTarget() {
        let candidates = session.targetCandidates(for: selectedControl)
        guard let candidate = candidates.first(where: { $0.id == remoteTargetID }) ?? candidates.first else {
            remoteTargetID = nil
            highlightedTarget = nil
            return
        }
        remoteTargetID = candidate.id
        previewPoint = nil
        highlightedTarget = MobileTargetSelection(id: candidate.id, point: candidate.point, state: candidate.assignment)
    }

    #if os(tvOS)
    override func shouldUpdateFocus(in context: UIFocusUpdateContext) -> Bool {
        if overlay.isHidden, context.previouslyFocusedView === metalView,
           context.focusHeading.contains(.left) || context.focusHeading.contains(.right) {
            return false
        }
        return super.shouldUpdateFocus(in: context)
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .playPause || $0.type == .menu }) { return }
        super.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .playPause }) {
            handleController(.pause)
        } else if presses.contains(where: { $0.type == .menu }) {
            if overlay.isHidden { pausePlay(showControls: true) }
            else { leaveToLibrary() }
        } else { super.pressesEnded(presses, with: event) }
    }
    #endif

    private func target(at point: MobilePoint) -> MobileTargetSelection? {
        let preference: MobileTargetPreference = session.engineIdentifier == "lemmings3"
            && selectedControl >= 3 ? .toolHolder : .assignable
        return MobileTargetSelector.select(
            candidates: session.targetCandidates(for: selectedControl),
            touch: point,
            viewport: metalView.gameViewport,
            radius: 30,
            preference: preference
        )
    }

    private func renderCurrentFrame(force: Bool) {
        let tick = session.snapshot.tick
        guard force || tick != lastRenderedTick else { return }
        do {
            metalView.update(frame: try session.render(highlight: highlightedTarget))
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
        paused = true
        clock.suspend()
        audio.suspend()
        music?.pause()
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

    private func resumePlay() {
        let needsLifecycleResume = lifecycle.requiresPlayerResume
        if needsLifecycleResume {
            applyEffects(lifecycle.handle(.playerRequestedResume))
        }
        guard lifecycle.isForeground, !lifecycle.isInterrupted else { return }
        if !needsLifecycleResume { try? audio.resume() }
        paused = false
        clock.suspend()
        overlay.isHidden = true
        overlay.accessibilityViewIsModal = false
        metalView.accessibilityElementsHidden = false
        hud.accessibilityElementsHidden = false
        metalView.isUserInteractionEnabled = true
        hud.isUserInteractionEnabled = true
        music?.play(menu: false, level: session.levelIndex)
        updateHUD()
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        UIAccessibility.post(notification: .announcement, argument: "Game resumed")
    }

    private func presentCompletion() {
        guard !completionPresented else { return }
        completionPresented = true
        paused = true
        clock.suspend()
        music?.pause()
        Task { try? await checkpointStore.remove() }
        let snapshot = session.snapshot
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
        showOverlay(title: result, actions: actions)
    }

    private func finish(_ action: MobileGameExitAction) {
        displayLink?.isPaused = true
        audio.suspend()
        music?.pause()
        Task {
            try? await checkpointStore.remove()
            onExit?(action)
        }
    }

    private func leaveToLibrary() {
        displayLink?.isPaused = true
        audio.suspend()
        music?.pause()
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
            #if os(iOS)
            let backgroundTask: UIBackgroundTaskIdentifier
            if reason == .suspension || reason == .sceneDisconnect || reason == .audioInterruption {
                backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Save Lemmings run")
            } else {
                backgroundTask = .invalid
            }
            #endif
            Task {
                #if os(iOS)
                defer {
                    if backgroundTask != .invalid {
                        UIApplication.shared.endBackgroundTask(backgroundTask)
                    }
                }
                #endif
                try? await checkpointStore.save(envelope)
            }
        } catch {
            // The current run stays in memory. A later lifecycle save can retry.
        }
    }

    private func makeCheckpoint() throws -> MobileCheckpointEnvelope {
        let viewport = metalView.gameViewport
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
        for name in [GameResources.changed, GameArtworkSkin.changed] {
            observers.append(centre.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.latestFrame = nil; self.minimapFrame = nil; self.lastRenderedTick = -1
                    self.session.releaseTransientResources()
                    self.applyPresentationSettings(self.gameSettings)
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
        #if os(iOS)
        observers.append(centre.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.updatePerformanceBudget() } })
        #endif
    }

    private func applyLifecycle(_ event: MobileLifecycleEvent) {
        applyEffects(lifecycle.handle(event))
    }

    private func applyEffects(_ effects: [MobileLifecycleEffect]) {
        for effect in effects {
            switch effect {
            case .pauseSimulation:
                paused = true
                clock.suspend()
            case .resumeSimulation:
                paused = false
                clock.suspend()
            case .cancelInput:
                previewPoint = nil
                highlightedTarget = nil
                remoteTargetID = nil
            case let .saveCheckpoint(reason):
                saveCheckpoint(reason: reason)
            case .suspendAudio:
                audio.suspend()
                music?.pause()
            case .prepareAudio:
                try? audio.prepare()
                renderCurrentFrame(force: true)
            case .resumeAudio:
                try? audio.resume()
                music?.resume()
            case .showResumeControl:
                pausePlay(showControls: true)
            case .purgeTransientResources:
                session.releaseTransientResources()
                metalView.purgeTexture()
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
        #if os(iOS)
        let lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        #else
        let lowPowerMode = false
        #endif
        let budget = MobileThermalPolicy.budget(
            for: level,
            lowPowerMode: lowPowerMode,
            reduceMotion: UIAccessibility.isReduceMotionEnabled,
            reduceFlashes: UIAccessibility.isReduceMotionEnabled
        )
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: Float(min(20, budget.framesPerSecond)),
            maximum: Float(budget.framesPerSecond),
            preferred: Float(budget.framesPerSecond)
        )
        metalView.preferredFramesPerSecond = budget.framesPerSecond
        let speedCatchUp = Int(ceil(
            session.ticksPerSecond * speed / Double(max(1, budget.framesPerSecond)) * 2
        ))
        clock.maximumCatchUpTicks = max(budget.maximumCatchUpTicks, speedCatchUp)
    }

    private func updateHUD(layout: MobileInterfaceLayout? = nil) {
        let resolved: MobileInterfaceLayout
        if let layout {
            resolved = layout
        } else {
            let insets = view.safeAreaInsets
            resolved = MobileLayoutEngine.make(
                container: MobileSize(width: view.bounds.width, height: view.bounds.height),
                safeArea: MobileInsets(top: insets.top, left: insets.left,
                                       bottom: insets.bottom, right: insets.right),
                controlCount: controlCount
            )
        }
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

    private func configureOverlay() {
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.90)
        overlay.accessibilityViewIsModal = true
        view.addSubview(overlay)
        overlayTitle.palette = .green
        overlayTitle.maximumScale = 3
        overlay.addSubview(overlayTitle)
    }

    private func showOverlay(title: String, actions: [(String, () -> Void)]) {
        overlayTitle.text = title.replacingOccurrences(of: "\n", with: "  ")
        overlayButtons.forEach { $0.removeFromSuperview() }
        overlayButtons = actions.enumerated().map { index, action in
            let button = MobilePixelButton()
            button.title = action.0
            button.isPrimary = index == 0
            button.onPress = action.1
            overlay.addSubview(button)
            return button
        }
        overlay.isHidden = false
        overlay.accessibilityViewIsModal = true
        metalView.accessibilityElementsHidden = true
        hud.accessibilityElementsHidden = true
        metalView.isUserInteractionEnabled = false
        hud.isUserInteractionEnabled = false
        layoutOverlay()
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        UIAccessibility.post(notification: .screenChanged, argument: overlayTitle)
    }

    private func layoutOverlay() {
        guard !overlay.isHidden else { return }
        let safe = overlay.safeAreaLayoutGuide.layoutFrame
        let width = min(520, max(200, safe.width - 32))
        let total = 70 + Double(overlayButtons.count) * 54
        var y = safe.midY - total / 2
        overlayTitle.frame = CGRect(x: safe.midX - width / 2, y: y, width: width, height: 58)
        y = overlayTitle.frame.maxY + 12
        for button in overlayButtons {
            button.frame = CGRect(x: safe.midX - width / 2, y: y, width: width, height: 46)
            y = button.frame.maxY + 8
        }
    }

    private static func cgRect(_ rect: MobileRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }
}
#endif
