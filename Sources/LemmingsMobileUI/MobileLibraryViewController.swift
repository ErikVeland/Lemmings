#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import LemmingsTVCore
import NxlvKit
import UIKit
import UniformTypeIdentifiers
import GameController

#if os(iOS)
extension MobileLibraryViewController: UIDocumentPickerDelegate {}
#endif

@MainActor final class MobileLibraryViewController: UIViewController {
    enum Route: Equatable {
        case home, support, family(MobileFamily), fanGroup([String]), levels, settings, settingsGroup(MobileSettingsGroup), language, controllerMappings, playInsights, soundtrack, data
        case whatsNew, effectsWelcome, telemetryConsent, insightsToken, insightsClear, familiarNames
        case journey, progression, techniques, rankings
        case collections, shortGames, l2Practice, playlists, playlist(UUID), addToPlaylist, players, cloudSaves, shuffleAll, hotSeat, hotSeats, progress, progressPlayer(String), progressLevel(String, String?), records, achievements, recordLevel(String), recordHint(String)
    }
    #if os(tvOS)
    override var preferredFocusEnvironments: [any UIFocusEnvironment] {
        if let game { return [game] }
        return browserShown ? [browser] : [canvas]
    }
    #endif
    #if os(iOS)
    var deskClockBlocksInput: Bool { deskClock != nil }
    let deskClockEntry = DeskClockAutomaticEntry()
    private weak var deskClockWindow: UIWindow?
    nonisolated(unsafe) private var deskClockTimer: Timer?
    #else
    var deskClockBlocksInput: Bool { false }
    #endif
    let scrollView = MobileMenuScrollView()
    #if os(iOS)
    private var menuBackGesture: UIScreenEdgePanGestureRecognizer?
    #endif
    private let homeBackdropView = MobileHomeBackdropView()
    private let menuBackdropView = UIView()
    private let homeBackdropLoader = MobileHomeBackdropLoader()
    private var homeBackdropTask: Task<Void, Never>?
    private var homeBackdropKey: String?
    #if os(tvOS)
    private var topShelfTask: Task<Void, Never>?
    #endif
    private var lastBookPanes: (size: CGSize, panes: [MobileRect]) = (.zero, [])
    private var usesMenuOverlay: Bool {
        #if os(iOS)
        usesHomeBox
        #else
        false
        #endif
    }
    private var usesHomeBox: Bool {
        #if os(tvOS)
        true
        #else
        // iPad and Duo share the tablet menu box. Its compact layout fits the folded Duo below
        // the camera without scrolling. Other phones keep the full-width menu.
        // Duo uses it folded and spanned, so the moving scenery shows behind both layouts.
        UIDevice.current.userInterfaceIdiom == .pad || min(view.bounds.width, view.bounds.height) >= 700
            || MobileSystemRegions.isFoldable(in: view)
        #endif
    }
    private var homeBackdropName: String { "home-scenery-" + (hotSeat?.scope ?? "solo") }
    let canvas = MobileMenuCanvas()
    let globalNavigation = MobileNavigationView()
    let settingsTabs = MobileSettingsTabsView()
    var selectedSettingsGroup = MobileSettingsGroup.gameplay
    private var settingsLandscape = false
    let listTools = MobileListToolsView()
    private let unfold = MobileUnfoldView()
    private var previousSize = CGSize.zero
    let browser = MobileLevelBrowserView()
    var browserShown = false
    var route = Route.home
    struct NavigationPosition {
        let route: Route
        let offset: CGPoint
        let focus: String?
    }
    private var navigationHistory: [NavigationPosition] = []
    private var detailReturnPosition: NavigationPosition?

    func showLibraryDetail(_ page: GameFrontEnd.Page) {
        detailReturnPosition = NavigationPosition(route: route, offset: scrollView.contentOffset, focus: canvas.focusedID)
        canvas.page = page
        scrollView.setContentOffset(.zero, animated: false)
        view.setNeedsLayout()
    }
    var settingsReturn: (route: Route, offset: CGPoint, focus: String?)?
    var languageSelectionOriginal: InterfaceLanguage?
    var confirmingRecordsReset = false
    #if os(tvOS)
    let tvBuildInfo = MobileBuildInfo.current()
    #endif
    var mobileInsights = MobileInsightsState()
    var progressMetric = "stars"
    var progressProfileID: String?
    var progressLevelMetric = "full"
    var familiarNames = MobileFamiliarNamesState()
    var fanCountsTask: Task<Void, Never>?
    var fanCountGeneration = UUID()
    var shuffleTask: Task<Void, Never>?
    var learningTask: Task<Void, Never>?
    var learningPreparing = false
    lazy var mobileRankings = MobileRankingsController(presenter: self, store: arcadeStore)
    lazy var libraryInput = makeLibraryInput()
    nonisolated(unsafe) private var inputLink: CADisplayLink?
    private var viewIsVisible = false
    private var sceneIsActive = false
    private let activityObservers = MobileNotificationObserverBag()
    override var canBecomeFirstResponder: Bool { game == nil && !deskClockShown && !searchField.isFirstResponder && mobileInsights.field?.isFirstResponder != true && familiarNames.field?.isFirstResponder != true }
    var store: MobileContentStore?
    private var hasLemmings2Data: Bool {
        store?.resolvedDataDirectory(for: .lemmings2) != nil
    }
    private var hasLemmings3Data: Bool {
        store?.resolvedDataDirectory(for: .lemmings3) != nil
    }
    private var hasNeoLemmixData: Bool {
        store?.resolvedDataDirectory(for: .neoLemmix) != nil
    }
    private var selectedImportKind: MobileGameDataKind = .classic
    var checkpointStore: MobileCheckpointStore?
    var library: (any MobileGameLibrary)?
    var catalogue: MobileCatalogue?
    var currentPack: MobileContentPack?
    var levelsBackRoute = Route.home
    var dataBackRoute = Route.home
    /// The players on this device. Each has their own collections and progress.
    var profiles = MobileStorage.standard(profile: "_players").load(MobileProfiles.self, name: "players") ?? MobileProfiles()
    lazy var arcadeStore = ArcadeStore(storage: .current(), bundledProofs: nil)
    #if os(iOS)
    private let cloudTransport = AppleGameProgressTransport()
    private var cloudAuthentication: UIViewController?
    lazy var cloudProgress = GameCenterProgressSync(store: arcadeStore, transport: cloudTransport)
    #endif
    let libraryCloudTransport = AppleCloudLibraryTransport()
    lazy var libraryCloud = CloudLibrarySync(store: arcadeStore, transport: libraryCloudTransport)
    var syncBackRoute: Route = .players
    /// Play Insights opens from Progress and from Settings > Privacy; Back returns to its source.
    var insightsBackID = "settingsGroup.privacy"
    /// Progression and Shuffle all open from Playlists as well as from Journey and the fan library.
    var progressionBackID = "journey"
    var shuffleBackID = "fanBack"
    var practiceChoice = 0
    var practiceSkills: [Lemmings2Runtime.Skill] = [.jumper, .runner, .builder, .basher, .digger, .climber, .floater, .roper]
    var tribesShortGamesEntries: [MobileFavourites.Entry]?
    var shortGamesEntries: [MobileFavourites.Entry]?
    var shortGamesSelection = "classic"
    var shortGamesPreparing = false
    var savedSeatsBackID = "hotSeat"
    /// The open record card's artwork, hints and catalogue location.
    var recordDetail: MobileRecordDetail?
    var syncMessage = ""
    var syncBusy = false
    #if os(tvOS)
    var tvBackupDraft: TVSaveBackup?
    #endif
    var collectionsBridge: MobileCollectionsBridge?
    var creatingPlayer = false
    var editingPlayerID: String?
    var draftPortrait = 0
    var storage: MobileStorage { .standard(profile: profiles.active.id) }
    lazy var favourites = MobileFavourites.load(from: storage, legacy: profiles.active.id == MobileProfiles.defaultID)
    lazy var recents = MobileRecents.load(from: storage, legacy: profiles.active.id == MobileProfiles.defaultID)
    lazy var playlists = MobilePlaylistStore.load(from: storage, legacy: profiles.active.id == MobileProfiles.defaultID)
    /// Set while the Players page keyboard edits a name, and while Shuffle all scans the packs.
    var renamingPlayer = false
    var hotSeats = MobileHotSeatStore.load(from: MobileStorage.standard(profile: "_players"))
    var hotSeatBackRoute: Route = .players
    var hotSeatRoster: MobileHotSeatRoster?
    var confirmingRestart = false
    var shufflePool: (entries: [MobileFavourites.Entry], packs: Int)?
    var shuffleScanning = false
    var playlistSelection: Int?
    var confirmingDelete = false
    /// Non-nil while the keyboard edits a playlist name.
    var nameDraft: String?
    /// Set while a playlist run is the library being played.
    var activeRun: MobilePlaylistRun?
    var searchQuery = ""
    let searchField = UITextField()
    private var fanUpdateStatus = ""
    private var fanUpdating = false
    var pendingCheckpoint: MobileCheckpointEnvelope?
    var selectedIndex = 0
    var previewLoader: MobileMenuPreviewLoader?
    private var previewTask: Task<Void, Never>?
    private var previewGeneration = UUID()
    private var previewDrain: Task<Void, Never>?
    private let libraryLoader = MobileLibraryLoader()
    private var libraryTask: Task<Void, Never>?
    private var libraryGeneration = UUID()
    var selectedPreview: MobileMenuPreview?
    var notice = ""
    private var loading = false
    private var preparingLevel = false
    var preparingCloudLevel: Bool { preparingLevel }
    var game: MobileGameViewController?
    #if os(iOS)
    /// The Desk Clock over the menu. The library stays underneath, paused.
    var deskClock: MobileDeskClockController?
    #endif
    private var deskClockShown: Bool {
        #if os(iOS)
        deskClock != nil
        #else
        false
        #endif
    }
    private var solved: Set<Int> {
        // Favourites mirror the progress of the packs their levels belong to.
        if let list = library as? MobileFavouritesLibrary {
            // Resolving a level opens its pack, so only packs with progress are resolved.
            var progress: [String: Set<Int>] = [:]
            return Set(list.levels.indices.filter { index in
                let pack = String(list.levelKey(at: index).split(separator: "|", maxSplits: 1).first ?? "")
                if progress[pack] == nil { progress[pack] = solvedLevels(for: pack) }
                guard progress[pack]?.isEmpty == false else { return false }
                return list.origin(of: index).map { progress[$0.pack]?.contains($0.index) ?? false } ?? false
            })
        }
        return solvedLevels(for: currentPack?.id)
    }
    private func progressKey(for pack: String?, fallback: String) -> String {
        "mobile.completed." + (pack ?? fallback) + progressSuffix
    }
    func solvedLevels(for pack: String?) -> Set<Int> {
        let defaults = UserDefaults.standard
        var all = Set(defaults.array(forKey: progressKey(for: pack, fallback: library?.displayName ?? "classic")) as? [Int] ?? [])
        // Builds before the catalogue stored Classic progress under the release name.
        if pack == "release/lemmings", profiles.active.id == MobileProfiles.defaultID, hotSeat == nil {
            all.formUnion(defaults.array(forKey: "mobile.completed.Lemmings") as? [Int] ?? [])
        }
        if let pack {
            all.formUnion(GameProgressPreferences.completed(pack: pack,
                profileID: hotSeat.map { "hotseat." + $0.id } ?? profiles.activeID))
        }
        if let fan = library as? ClassicFanMobileLibrary, pack == fan.catalogueID {
            let passed = GameProgressPreferences.fanLevels(profileID: profiles.activeID, sessionID: hotSeat?.id)
            let previous = all
            all.formUnion(fan.entries.indices.filter {
                passed.contains(GameProgressPreferences.fanIdentifier(pack: fan.pack.url, label: fan.entries[$0].label))
            })
            if all != previous {
                defaults.set(all.sorted(), forKey: progressKey(for: pack, fallback: fan.displayName))
            }
        }
        return all
    }

    #if os(iOS)
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    #endif
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        MobileDevicePerformance.memoryWarning()
        guard let previewLoader else { return }
        Task { await previewLoader.releaseCaches() }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        deskClockEntry.onPoseChange = { [weak self] in self?.checkDeskClock() }
        let activity = UITapGestureRecognizer()
        activity.delegate = deskClockEntry
        activity.cancelsTouchesInView = false
        view.addGestureRecognizer(activity)
        deskClockTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkDeskClock() }
        }
        #endif
        view.backgroundColor = .black
        view.addSubview(homeBackdropView)
        scrollView.backgroundColor = .black
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = false
        menuBackdropView.backgroundColor = UIColor.black.withAlphaComponent(GameMenuBackdropArt.opacity)
        menuBackdropView.layer.compositingFilter = "overlayBlendMode"
        menuBackdropView.isOpaque = false
        menuBackdropView.isUserInteractionEnabled = false
        menuBackdropView.isAccessibilityElement = false
        menuBackdropView.isHidden = true
        scrollView.addSubview(menuBackdropView)
        scrollView.addSubview(canvas)
        view.addSubview(scrollView)
        canvas.onAction = { [weak self] in self?.handle($0) }
        canvas.onHoldAction = { [weak self] id in
            guard let self, self.route == .players, !self.renamingPlayer, id.hasPrefix("player.") else { return }
            self.beginRenamingPlayer(String(id.dropFirst(7)))
        }
        browser.isHidden = true
        browser.onBack = { [weak self] in self?.handle("back") }
        browser.onPlay = { [weak self] index in self?.selectedIndex = index; self?.startLevel(index, checkpoint: nil) }
        browser.onSelect = { [weak self] index in
            guard let self else { return }
            self.selectedIndex = index
            self.browser.setFavourite(self.isFavourite(index))
            self.view.setNeedsLayout()
        }
        browser.onFavourite = { [weak self] index in self?.toggleFavourite(index) }
        browser.onPlaylist = { [weak self] index in
            guard let self else { return }
            self.selectedIndex = index
            _ = self.handleCollections("addPlaylist")
        }
        browser.artworkLoader = { [weak self] index in await self?.coverArtwork(index) }
        view.addSubview(browser)
        view.addSubview(unfold)
        globalNavigation.onHome = { [weak self] in self?.navigate(.home) }
        globalNavigation.onBack = { [weak self] in self?.goBack() }
        canvas.globalNavigation = globalNavigation
        canvas.listTools = listTools
        listTools.onAction = { [weak self] in self?.handle($0) }
        view.addSubview(listTools)
        globalNavigation.onSecondary = { [weak self] in self?.openGlobalSettings() }
        globalNavigation.secondaryTitle = L10n.text("Settings")
        view.addSubview(globalNavigation)
        settingsTabs.onAction = { [weak self] in self?.handle($0) }
        canvas.settingsTabs = settingsTabs
        view.addSubview(settingsTabs)
        #if os(iOS)
        let backGesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(edgeBack(_:)))
        backGesture.edges = .left
        view.addGestureRecognizer(backGesture)
        menuBackGesture = backGesture
        #endif
        #if os(iOS)
        for direction in [UISwipeGestureRecognizer.Direction.left, .right] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
            swipe.direction = direction
            swipe.cancelsTouchesInView = false
            if let menuBackGesture { swipe.require(toFail: menuBackGesture) }
            canvas.addGestureRecognizer(swipe)
        }
        #endif
        _ = saveProfiles()
        reloadPlayerData()
        catalogue = Self.makeCatalogue()
        let target = MobileDisplayLinkTarget { [weak self] in self?.pollLibraryInput($0) }
        inputLink = CADisplayLink(target: target, selector: #selector(MobileDisplayLinkTarget.frame(_:)))
        inputLink?.isPaused = true
        inputLink?.preferredFramesPerSecond = 30
        inputLink?.add(to: .main, forMode: .common)
        observeFrameActivity()
        searchField.autocorrectionType = .no
        searchField.spellCheckingType = .no
        searchField.textContentType = nil
        #if os(iOS)
        if #available(iOS 17.0, *) { searchField.inlinePredictionType = .no }
        #endif
        searchField.autocapitalizationType = .none
        searchField.returnKeyType = .done
        searchField.alpha = 0.01
        searchField.frame = CGRect(x: -100, y: -100, width: 10, height: 10)
        searchField.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            if self.nameDraft != nil { self.nameDraft = String((self.searchField.text ?? "").prefix(40)) }
            else {
                self.searchQuery = self.searchField.text ?? ""
                if case .fanGroup = self.route { self.route = .family(.fan); self.canvas.focusedID = "search" }
                self.scrollView.setContentOffset(.zero, animated: false)
            }
            self.rebuild()
        }, for: .editingChanged)
        searchField.addAction(UIAction { [weak self] _ in self?.searchField.resignFirstResponder(); self?.rebuild() }, for: .editingDidEndOnExit)
        view.addSubview(searchField)
        do {
            let configured = try MobileContentStore()
            store = configured
            checkpointStore = MobileCheckpointStore(url: configured.checkpointURL)
            reloadLibrary()
        } catch { notice = error.localizedDescription; rebuild() }
        beginWelcomeIfNeeded()
        measureMobileFanPacks()
        AnonymousTelemetry.shared.recordActiveDay()
        AnonymousTelemetry.shared.onSharingChanged = { [weak self] in self?.mobileRankings.community.countSharingChanged() }
        mobileRankings.community.countSharingChanged()
        #if os(iOS)
        cloudProgress.canImport = { [weak self] in self?.game == nil && self?.preparingLevel == false }
        cloudProgress.captureExtra = { profileID in
            let saved = MobileStorage.standard(profile: profileID).load(MobileLearningState.self, name: "learning")
            return saved.map { .init(values: ["LearningJourneyProgress": .learning($0.progress)]) } ?? .init()
        }
        cloudProgress.onImported = { [weak self] in self?.rebuild() }
        #endif
        configureLibraryCloud()
        arcadeStore.onProgressChanged = { [weak self] in
            self?.libraryCloud.requestSync()
            #if os(iOS)
            if self?.libraryCloud.enabled == true { self?.cloudProgress.requestSync() }
            #endif
        }
        NotificationCenter.default.addObserver(self, selector: #selector(cloudForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(cloudBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        #if os(iOS)
        cloudTransport.onChange = { [weak self] in self?.cloudProgress.requestSync() }
        cloudTransport.start { [weak self] controller in
            self?.cloudAuthentication = controller
            self?.presentCloudAuthentication()
        }
        #endif
    }
    private var deskClockAvailable: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    #if os(iOS)
    func presentDeskClock(reason: DeskClockReason) {
        guard deskClock == nil else { return }
        if reason != .tent {
            guard game == nil, presentedViewController == nil,
                  !preparingLevel, !learningPreparing, !shortGamesPreparing else { return }
        }
        let clock = MobileDeskClockController(reason: reason, resumeMusic: { [weak self] in
            guard let self, self.game == nil else { return }
            self.syncMenuMusic()
        })
        clock.onClose = { [weak self, weak clock] in
            guard let self, self.deskClock === clock else { return }
            self.deskClock = nil
            self.deskClockEntry.noteDismissal(reason: reason)
            self.libraryInput.reset()
            self.game?.setDeskClockVisible(false)
            if let game = self.game { game.becomeFirstResponder() }
            else { self.becomeFirstResponder() }
            self.syncPages()
        }
        deskClock = clock
        // Hold the clock before pausing gameplay or ending editing: either operation can lay out
        // the library and recheck the hinge while presentation is in progress.
        view.endEditing(true)
        game?.setDeskClockVisible(true)
        libraryInput.reset()
        resignFirstResponder()
        clock.present(in: self, surface: deskClockWindow)
        syncPages()
    }

    func dismissDeskClock() { deskClock?.close() }

    /// Runs every 5 s. A shown automatic clock is also checked on each layout change.
    private func checkDeskClock() {
        let window = view.window ?? deskClockWindow
        #if DEBUG
        let sceneState = String(describing: window?.windowScene?.activationState)
        if UserDefaults.standard.string(forKey: "DeskClockSceneState") != sceneState {
            UserDefaults.standard.set(sceneState, forKey: "DeskClockSceneState")
            var history = UserDefaults.standard.stringArray(forKey: "DeskClockSceneHistory") ?? []
            history.append("\(Date().timeIntervalSince1970) \(sceneState)")
            UserDefaults.standard.set(Array(history.suffix(32)), forKey: "DeskClockSceneHistory")
        }
        #endif
        guard let window, window.windowScene?.activationState == .foregroundActive else { return }
        deskClockWindow = window
        if deskClockEntry.hinge != .unavailable { MobileSystemRegions.noteHinge(in: window) }
        deskClockEntry.observePose(in: window)
        deskClockEntry.check(self)
    }
    #endif

    private func presentCloudAuthentication() {
        #if os(iOS)
        guard game == nil, presentedViewController == nil, view.window != nil, let controller = cloudAuthentication else { return }
        cloudAuthentication = nil
        present(controller, animated: true)
        #endif
    }
    private var cloudBackgroundTask: Task<Void, Never>?
    private var cloudBackgroundID: UIBackgroundTaskIdentifier = .invalid

    @objc private func cloudBackground() {
        guard ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] != "muted",
              libraryCloud.enabled, cloudBackgroundTask == nil else { return }
        arcadeStore.flushPendingSaves()
        cloudBackgroundID = UIApplication.shared.beginBackgroundTask(withName: "Cloud library sync") { [weak self] in
            Task { @MainActor in
                self?.cloudBackgroundTask?.cancel()
                self?.endCloudBackgroundTime()
            }
        }
        cloudBackgroundTask = Task { [weak self] in
            guard let self else { return }
            await libraryCloud.syncForLifecycle()
            finishCloudBackground()
        }
    }
    private func endCloudBackgroundTime() {
        if cloudBackgroundID != .invalid {
            UIApplication.shared.endBackgroundTask(cloudBackgroundID)
            cloudBackgroundID = .invalid
        }
    }
    private func finishCloudBackground() {
        endCloudBackgroundTime()
        cloudBackgroundTask = nil
    }

    @objc private func cloudForeground() {
        // Calendar access may have changed in iOS Settings.
        if route == .settingsGroup(.deskClock) { rebuild() }
        libraryCloud.requestSync(immediately: true)
        #if os(iOS)
        if libraryCloud.enabled { cloudProgress.requestSync(); presentCloudAuthentication() }
        #endif
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewIsVisible = true
        #if os(iOS)
        if let window = view.window {
            deskClockWindow = window
            deskClockEntry.observePose(in: view)
            deskClockEntry.observePose(in: window)
        }
        #endif
        sceneIsActive = view.window?.windowScene?.activationState == .foregroundActive
        syncPages()
        if game == nil { becomeFirstResponder() }
        #if os(iOS)
        cloudProgress.requestSync()
        #endif
        libraryCloud.requestSync()
        presentCloudAuthentication()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewIsVisible = false
        syncPages()
    }

    deinit {
        inputLink?.invalidate()
        #if os(iOS)
        deskClockTimer?.invalidate()
        #endif
    }

    private func observeFrameActivity() {
        let centre = NotificationCenter.default
        for name in [UIScene.willDeactivateNotification, UIScene.didEnterBackgroundNotification,
                     UIScene.didDisconnectNotification, UIScene.didActivateNotification] {
            activityObservers.append(centre.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let scene = notification.object as? UIWindowScene
                MainActor.assumeIsolated {
                    guard let self, let scene, scene === self.viewIfLoaded?.window?.windowScene else { return }
                    self.sceneIsActive = name == UIScene.didActivateNotification
                    #if os(iOS)
                    self.deskClockEntry.noteInput()
                    #endif
                    self.libraryInput.reset()
                    self.syncPages()
                    #if os(iOS)
                    if name == UIScene.didActivateNotification { self.checkDeskClock() }
                    #endif
                }
            })
        }
        for name in [Notification.Name.GCControllerDidConnect, .GCControllerDidDisconnect,
                     UIAccessibility.reduceMotionStatusDidChangeNotification] {
            activityObservers.append(centre.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateLibraryDisplayLink() }
            })
        }
    }

    private func updateLibraryDisplayLink() {
        let active = viewIsVisible && sceneIsActive && game == nil && !deskClockShown
        if !active { unfold.stop() }
        let animatedBackdrop = usesHomeBox && route == .home && homeBackdropView.canAnimate
            && !mobileSettings.classic.staticHomeScreen && !mobileSettings.classic.reduceMotion
            && !UIAccessibility.isReduceMotionEnabled
        inputLink?.isPaused = deskClockBlocksInput || !active || (!animatedBackdrop && GCController.controllers().isEmpty)
        if inputLink?.isPaused == true {
            libraryInput.reset()
            homeBackdropView.advance(at: 0, active: false, reduceMotion: true)
        }
    }
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        #if os(tvOS)
        if game == nil, presentedViewController == nil, presses.contains(where: { $0.type == .menu }), route != .home {
            if browserShown { navigate(levelsBackRoute) } else { canvas.goBack() }
            return
        }
        #endif
        let handled = libraryInput.began(presses)
        super.pressesBegan(presses.subtracting(handled), with: event)
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let handled = libraryInput.ended(presses)
        super.pressesEnded(presses.subtracting(handled), with: event)
    }
    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        libraryInput.reset()
        super.pressesCancelled(presses, with: event)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        #if os(iOS)
        checkDeskClock()
        #endif
        let expanded = previousSize.width > 0 && view.bounds.width > previousSize.width * 1.25
        let division = MobileSystemRegions.read(in: view).contains { $0.kind == .division && $0.frame.height > $0.frame.width }
        if previousSize != view.bounds.size {
            unfold.stop()
            if game == nil, expanded, division { unfold.play(in: MobileSystemRegions.menuFrame(in: view)) }
        }
        previousSize = view.bounds.size
        browser.frame = view.bounds
        homeBackdropView.frame = view.bounds
        canvas.boxesHome = usesHomeBox
        if settingsLandscape != usesSettingsTabs {
            settingsLandscape = usesSettingsTabs
            switch route {
            case .settings:
                let page = settingsGroupsPage()
                if canvas.page != page { canvas.page = page }
            case let .settingsGroup(group):
                let page = settingsPage(group)
                if canvas.page != page { canvas.page = page }
            default: break
            }
        }
        syncPages()
        let safe = view.safeAreaLayoutGuide.layoutFrame
        var book = route == .home && canvas.page.home ? MobileDisplayRegions.bookPanes(
            in: MobileRect(x: safe.minX, y: safe.minY, width: safe.width, height: safe.height),
            avoiding: MobileSystemRegions.read(in: view)) : []
        // The hinge region can drop out for a moment on periodic layout passes.
        // Keep the spanned panes until the window size actually changes.
        if route == .home && canvas.page.home {
            if book.isEmpty, lastBookPanes.size == view.bounds.size { book = lastBookPanes.panes }
            else { lastBookPanes = (view.bounds.size, book) }
        }
        var menuRegion = book.isEmpty ? MobileSystemRegions.menuFrame(in: view) : safe
        canvas.usesMenuBackdrop = usesMenuOverlay
        globalNavigation.isHidden = game != nil || route == .home || deskClockShown
        browser.showsBack = globalNavigation.isHidden
        switch route {
        case .settings, .settingsGroup, .language, .controllerMappings, .soundtrack:
            globalNavigation.secondaryTitle = nil
        default: globalNavigation.secondaryTitle = L10n.text("Settings")
        }
        if menuRegion.width < 440 || !canvas.page.listTools.isEmpty { globalNavigation.secondaryTitle = nil }
        let bottomSettingsNavigation = !globalNavigation.isHidden && usesSettingsTabs && {
            switch route {
            case .settings, .settingsGroup, .language, .controllerMappings, .soundtrack: true
            default: false
            }
        }()
        #if os(iOS)
        let staticHeading = MobileSystemRegions.isFoldable(in: view)
            && view.bounds.height > view.bounds.width && !globalNavigation.isHidden
            && !bottomSettingsNavigation
        #else
        let staticHeading = false
        #endif
        globalNavigation.headingTitle = staticHeading ? (browserShown ? browser.headingText : canvas.staticHeadingTitle) : nil
        canvas.showsStaticHeading = staticHeading && !browserShown
        browser.showsStaticHeading = staticHeading && browserShown
        canvas.usesBottomSettingsNavigation = bottomSettingsNavigation
        #if os(iOS)
        menuBackGesture?.isEnabled = !globalNavigation.isHidden
        #endif
        if !globalNavigation.isHidden {
            globalNavigation.showsBack = browserShown || canvas.page.backAction != nil
            globalNavigation.backTitle = browserShown ? L10n.text("Back") : canvas.page.backAction?.title ?? L10n.text("Back")
            let navigationHeight = globalNavigation.height(for: menuRegion.width)
            globalNavigation.frame = CGRect(x: menuRegion.minX, y: menuRegion.minY,
                width: menuRegion.width, height: navigationHeight)
            if bottomSettingsNavigation { globalNavigation.frame.origin.y = menuRegion.maxY - navigationHeight }
            else { menuRegion.origin.y += navigationHeight }
            menuRegion.size.height -= navigationHeight
            browser.frame = CGRect(x: 0, y: menuRegion.minY, width: view.bounds.width, height: menuRegion.height)
            view.bringSubviewToFront(globalNavigation)
        }
        settingsTabs.isHidden = !bottomSettingsNavigation || canvas.page.settingsTabs == nil
        settingsTabs.tabs = canvas.page.settingsTabs ?? []
        if !settingsTabs.isHidden {
            let height = settingsTabs.height(for: menuRegion.width)
            settingsTabs.frame = CGRect(x: menuRegion.minX, y: menuRegion.minY, width: menuRegion.width, height: height)
            menuRegion.origin.y += height
            menuRegion.size.height = max(0, menuRegion.height - height)
            view.bringSubviewToFront(settingsTabs)
        }
        view.accessibilityElements = bottomSettingsNavigation
            ? (settingsTabs.isHidden ? [] : [settingsTabs]) + [scrollView, globalNavigation] : nil
        listTools.actions = canvas.page.listTools
        listTools.searchQuery = searchQuery
        listTools.isHidden = globalNavigation.isHidden || listTools.actions.isEmpty
        if !listTools.isHidden {
            listTools.frame = CGRect(x: menuRegion.minX, y: menuRegion.minY, width: menuRegion.width, height: 0)
            listTools.frame.size.height = listTools.shelfHeight
            menuRegion.origin.y += listTools.shelfHeight
            menuRegion.size.height -= listTools.shelfHeight
            view.bringSubviewToFront(listTools)
        }
        var scrollFrame = menuRegion
        #if os(iOS)
        let extendsPortraitViewport = view.bounds.height > view.bounds.width
            && view.bounds.width < 600 && book.isEmpty
            && !MobileSystemRegions.read(in: view).contains { $0.kind == .division }
        if extendsPortraitViewport {
            let top = staticHeading ? globalNavigation.frame.maxY : view.bounds.minY
            scrollFrame.origin.y = top
            scrollFrame.size.height = max(0, view.bounds.maxY - top)
        }
        #endif
        scrollView.setViewportFrame(scrollFrame)
        canvas.bookHomePanes = book.map {
            CGRect(x: $0.minX - safe.minX, y: $0.minY - safe.minY, width: $0.width, height: $0.height)
        }
        let size = canvas.size(width: scrollView.bounds.width, minimumHeight: menuRegion.height)
        let contentTop = max(0, menuRegion.minY - scrollFrame.minY)
        let contentBottom = max(0, scrollFrame.maxY - menuRegion.maxY)
        scrollView.unobscuredInsets = UIEdgeInsets(top: contentTop, left: 0, bottom: contentBottom, right: 0)
        canvas.frame = CGRect(x: 0, y: contentTop, width: size.width, height: size.height)
        #if os(tvOS)
        scrollView.isScrollEnabled = !canvas.page.home && !canvas.page.televisionGrid
        if !scrollView.isScrollEnabled { scrollView.contentOffset = .zero }
        #endif
        // Commit the background, artwork and targets in this layout transaction.
        // Overlay belongs only to the background; lettering and controls stay unblended.
        menuBackdropView.isHidden = !usesMenuOverlay || canvas.isHidden || browserShown
        let backdrop = canvas.menuBackdropGeometry
        menuBackdropView.frame = backdrop.frame.offsetBy(dx: canvas.frame.minX, dy: canvas.frame.minY)
        menuBackdropView.layer.cornerRadius = backdrop.radius
        let contentHeight = max(contentTop + size.height + contentBottom,
            menuBackdropView.isHidden ? 0 : menuBackdropView.frame.maxY + contentBottom)
        let contentSize = CGSize(width: size.width, height: contentHeight)
        if scrollView.contentSize != contentSize { scrollView.contentSize = contentSize }
        canvas.layoutIfNeeded()
        globalNavigation.layoutIfNeeded()
        settingsTabs.layoutIfNeeded()
        listTools.layoutIfNeeded()
        game?.view.frame = view.bounds
    }
    private func rememberHomeBackdrop(_ session: any MobileGameSession, at index: Int) {
        let kind: MobileGameDataKind = session.engineIdentifier == "lemmings2" ? .lemmings2
            : session.engineIdentifier == "lemmings3" ? .lemmings3
            : session.engineIdentifier == "neolemmix" ? .neoLemmix : .classic
        let identity = favouriteIdentity(index)
        let reference = MobileHomeBackdropReference(kind: kind, pack: identity?.pack,
            level: identity?.level ?? session.levelIdentifier)
        try? storage.save(reference, name: homeBackdropName)
    }

    private func refreshHomeBackdrop() {
        let shown = usesHomeBox && (route == .home || usesMenuOverlay) && game == nil
        homeBackdropView.isHidden = !shown
        scrollView.backgroundColor = shown ? .clear : .black
        scrollView.isOpaque = !shown
        canvas.backgroundColor = shown ? .clear : .black
        canvas.isOpaque = !shown
        guard shown, viewIsVisible, sceneIsActive else {
            homeBackdropView.advance(at: 0, active: false, reduceMotion: true)
            if homeBackdropTask != nil { homeBackdropTask?.cancel(); homeBackdropTask = nil; homeBackdropKey = nil }
            return
        }
        let preferred = storage.load(MobileHomeBackdropReference.self, name: homeBackdropName)
            ?? pendingCheckpoint.flatMap { saved -> MobileHomeBackdropReference? in
                guard checkpointMatchesSession(saved), recents.entries.isEmpty || ["lemmings2", "lemmings3", "neolemmix"].contains(saved.engine) else { return nil }
                return MobileHomeBackdropReference(kind: saved.engine == "lemmings2" ? .lemmings2
                    : saved.engine == "lemmings3" ? .lemmings3 : saved.engine == "neolemmix" ? .neoLemmix : .classic,
                    pack: catalogue?.pack(forLevelIdentifier: saved.levelIdentifier)?.id, level: saved.levelIdentifier)
            }
        let recent = recents.entries.first
        let native = Dictionary(uniqueKeysWithValues: MobileGameDataKind.allCases.filter { $0 != .classic }.compactMap { kind in
            store?.resolvedDataDirectory(for: kind).map { (kind, $0) }
        })
        let classic = (library as? ClassicMobileLibrary)?.directory ?? store?.resolvedDataDirectory(for: .classic)
        let key = profiles.activeID + ":" + homeBackdropName + ":" + (preferred.map { "\($0.kind.rawValue):\($0.pack ?? ""): \($0.level)" }
            ?? recent.map { $0.pack + ":" + $0.level } ?? "random")
            + String(describing: mobileSettings.classic.graphics) + String(describing: mobileSettings.classic.colorDepth)
            + (catalogue?.portsRoot.path ?? "") + (classic?.path ?? "") + native.values.map(\.path).sorted().joined(separator: ":")
        guard homeBackdropKey != key else { return }
        homeBackdropTask?.cancel(); homeBackdropKey = key
        homeBackdropView.show(nil)
        let ports = catalogue?.portsRoot, fan = catalogue?.fanFolders ?? [], storage = storage, settings = mobileSettings.classic
        homeBackdropTask = Task { [weak self, homeBackdropLoader] in
            let scenery = try? await homeBackdropLoader.load(preferred: preferred, recent: recent, ports: ports,
                fanFolders: fan, native: native, classicDirectory: classic, storage: storage, settings: settings,
                neoLibrary: { try NeoLemmixMobileLibrary(directory: $0, storage: $1) })
            guard !Task.isCancelled, let self, self.homeBackdropKey == key else { return }
            self.homeBackdropTask = nil
            self.homeBackdropView.show(scenery)
            self.updateLibraryDisplayLink()
            #if os(tvOS)
            // Top Shelf picks one of the two Macintosh looks for each newly exported level.
            var shelfSettings = settings
            shelfSettings.graphics = Bool.random() ? .macintosh : .macintoshMonochrome
            let shelfKey = MobileTopShelfScenery.seasonalKey(key)
            if scenery != nil, self.topShelfTask == nil, MobileTopShelfScenery.needsExport(key: shelfKey) {
                self.topShelfTask = Task.detached(priority: .utility) { [weak self, homeBackdropLoader] in
                    if let shelf = try? await homeBackdropLoader.load(preferred: preferred, recent: recent, ports: ports,
                        fanFolders: fan, native: native, classicDirectory: classic, storage: storage, settings: shelfSettings,
                        neoLibrary: { try NeoLemmixMobileLibrary(directory: $0, storage: $1) }) {
                        try? await MobileTopShelfScenery.export(shelf, key: shelfKey)
                    }
                    await MainActor.run { self?.topShelfTask = nil }
                }
            }
            #endif
        }
    }

    func advanceHomeBackdrop(at now: TimeInterval) {
        homeBackdropView.advance(at: now,
            active: usesHomeBox && route == .home && game == nil && presentedViewController == nil
                && view.window?.windowScene?.activationState == .foregroundActive,
            reduceMotion: mobileSettings.classic.staticHomeScreen || mobileSettings.classic.reduceMotion || UIAccessibility.isReduceMotionEnabled)
    }

    func rebuild() {
        let keptOffset = scrollView.contentOffset
        defer {
            // A download tick or a tap rebuilds the list in place, so the player keeps their place in it.
            if route == .soundtrack, keptOffset.y > 0 {
                scrollView.layoutIfNeeded()
                let maximum = max(0, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
                scrollView.setContentOffset(CGPoint(x: keptOffset.x, y: min(keptOffset.y, maximum)), animated: false)
            }
        }
        canvas.fitsSupportPage = route == .support
        canvas.sessionName = hotSeat.map { $0.players.map(playerName).joined(separator: " v ") }
        canvas.playerRole = .next
        canvas.playerName = route == .players && renamingPlayer ? nil : playerName(hotSeat?.turn ?? profiles.activeID)
        unfold.stop()
        let count = library?.levels.count ?? 0
        let subtitle = loading ? L10n.text("Loading...") : notice
        switch route {
        case .home:
            var resume: [GameFrontEnd.Action] = []
            let savedLevel = pendingCheckpoint.flatMap { checkpointMatchesSession($0) ? $0 : nil }
            if let saved = savedLevel, !checkpointResumesLearningRun(saved) {
                resume.append(.init("resume", L10n.text("Resume level - \(playerName(saved.owner ?? profiles.activeID))")))
            }
            if catalogue != nil, let saved = resumableLearningRun {
                let session = saved.seat?.id != hotSeat?.id ? saved.seat.map { " - " + $0.players.map(playerName).joined(separator: " vs ") } ?? " - " + profiles.active.name : ""
                resume.append(.init("learningRunResume", saved.resumeTitle + session))
            }
            if resume.isEmpty, catalogue != nil, let run = playlists.run {
                resume.append(.init("runResume", L10n.text("Resume \(run.name)  \(run.position + 1)/\(run.entries.count)")))
            }
            let families: [GameFrontEnd.Action] = MobileFamily.allCases.map { family in
                let packs = catalogue?.packs(in: family) ?? []
                if catalogue == nil, family == .classic {
                    return .init("classic", L10n.text("Classic Lemmings  \(solved.count)/\(count)"), enabled: count > 0)
                }
                let total = packs.reduce(0) { $0 + ($1.levelCount ?? 0) }
                let passed = packs.reduce(0) { $0 + solvedLevels(for: $1.id).count }
                let title = family.title + (packs.isEmpty ? L10n.text(" - No data") : "  \(passed)/\(total)")
                return .init("family." + family.rawValue, title, enabled: !packs.isEmpty)
            } + [.init("neolemmix", hasNeoLemmixData ? L10n.text("NeoLemmix Preview") : L10n.text("Import NeoLemmix data")),
                 .init("l2", hasLemmings2Data ? L10n.text("Lemmings 2") : L10n.text("Import Lemmings 2 data"), gameLogo: .lemmings2),
                 .init("l3", hasLemmings3Data ? Lemmings3Brand.current.displayName : L10n.text("Import \(Lemmings3Brand.current.displayName) data"), enabled: true, gameLogo: .lemmings3)]
            let journey = bundledJourney
            let initials = hotSeat.map { $0.players.map(playerName).joined(separator: " v ") } ?? profiles.active.name
            let nextPlayerIndex = hotSeat.flatMap { $0.players.firstIndex(of: $0.turn) }
            #if os(tvOS)
            let homeSubtitle = [tvBuildInfo.label, tvBuildInfo.dateLabel, subtitle].filter { !$0.isEmpty }.joined(separator: "\n")
            #else
            let homeSubtitle = subtitle
            #endif
            canvas.page = MobileHomeArt.page(resume: resume,
                journey: resumableLearningJourney != nil || savedLevel != nil || playlists.run != nil ? MobileHomeArt.journeyMap(completed: completedJourneyLevelCount, enabled: catalogue != nil)
                    : canStartJourney ? .init("journey", L10n.text("Start journey"), enabled: catalogue != nil && journey != nil) : nil,
                families: families, initials: initials, nextPlayerIndex: nextPlayerIndex,
                subtitle: homeSubtitle, collectionsAvailable: catalogue != nil,
                deskClock: deskClockAvailable)
            canvas.preview = nil
        case .support:
            canvas.page = GameSupport.page
            canvas.preview = GameSupport.qrCode
            canvas.previewSource = nil
        case .family(.fan):
            canvas.page = fanLibraryPage(path: [], subtitle: subtitle); canvas.preview = nil
        case let .fanGroup(path):
            canvas.page = fanLibraryPage(path: path, subtitle: subtitle); canvas.preview = nil
        case let .family(family):
            let packs = catalogue?.packs(in: family) ?? []
            let rows = packs.map { pack in
                GameFrontEnd.Action("pack." + pack.id, pack.title + (pack.levelCount.map { "  \($0)" } ?? "") + solvedMark(pack))
            }
            canvas.page = .init(title: family.title, subtitle: subtitle,
                                rows: rows, footer: [.init("home", L10n.text("Back"))])
            canvas.preview = nil
        case .levels:
            guard let library, library.levels.indices.contains(selectedIndex) else { route = .home; rebuild(); return }
            let level = library.levels[selectedIndex]
            let rank = library is MobileJourneyLibrary ? library.levels : library.levels.filter { $0.rank == level.rank }
            let rankIndex = rank.firstIndex(where: { $0.index == selectedIndex }) ?? 0
            let ranksCount = library is MobileJourneyLibrary ? 1 : Set(library.levels.map(\.rank)).count
            var stats: [String] = selectedPreview.map {
                let s = $0.snapshot
                return [L10n.text("\(s.total) Lemmings   Save \(s.required)"),
                        s.remainingSeconds.map { L10n.text("Time \($0 / 60):\(String(format: "%02d", $0 % 60))") } ?? L10n.text("No time limit")]
            } ?? []
            if let requirement = AmigaVersusCampaign.controllerRequirement(rank: level.rank) {
                stats.append(requirement)
            }
            canvas.page = .init(title: level.title,
                                subtitle: level.selectionSubtitle(rankCount: rank.count, status: subtitle),
                                details: stats,
                                footer: (ranksCount > 1 ? [.init("rankPrevious", L10n.text("< Rank")), .init("rankNext", L10n.text("Rank >"))] : [])
                                    + [.init("previous", L10n.text("< Level"), enabled: rankIndex > 0),
                                         .init("next", L10n.text("Level >"), enabled: rankIndex + 1 < rank.count && canSelectJourneyLevel(selectedIndex + 1)),
                                         .init("favourite", isFavourite(selectedIndex) ? L10n.text("Remove favourite") : L10n.text("Add favourite"), selected: isFavourite(selectedIndex), icon: .favourite),
                                         .init("addPlaylist", L10n.text("Playlist"), enabled: catalogue != nil && favouriteIdentity(selectedIndex) != nil)]
                                    + (library is Lemmings2MobileLibrary || library is Lemmings3MobileLibrary ? [.init("originalMovies", L10n.text("Original movies"))] : [])
                                    + (library is Lemmings2MobileLibrary ? [.init("l2Practice", L10n.text("Practice"))] : [])
                                    + (currentPack != nil && activeRun == nil && library.levels.count > 1 ? [.init("random", L10n.text("Random 10"))] : [])
                                    + [.init("back", L10n.text("Back")),
                                         .init("play", solved.contains(selectedIndex) ? L10n.text("Play again") : L10n.text("Play"), enabled: !loading, primary: true)],
                                preview: true, footerColumns: 2)
            if let preview = selectedPreview {
                canvas.preview = MobileBitmapRenderer.image(preview.frame)
                let source = preview.sourceRect
                canvas.previewSource = CGRect(x: source.x, y: source.y, width: source.width, height: source.height)
            }
        case .journey:
            canvas.page = learningPage(subtitle: subtitle); canvas.preview = nil
        case .l2Practice:
            canvas.page = l2PracticePage(subtitle: subtitle); canvas.preview = nil
        case .shortGames:
            canvas.page = shortGamesPage(subtitle: subtitle); canvas.preview = nil
        case .progression:
            canvas.page = progressionPage(subtitle: subtitle); canvas.preview = nil
        case .techniques:
            canvas.page = techniquePage(subtitle: subtitle); canvas.preview = nil
        case .rankings:
            canvas.page = rankingsPage(subtitle: subtitle); canvas.preview = nil
        case .whatsNew:
            canvas.page = whatsNewPage(); canvas.preview = nil
        case .effectsWelcome:
            canvas.page = effectsWelcomePage(); canvas.preview = nil
        case .telemetryConsent:
            canvas.page = telemetryConsentPage(); canvas.preview = nil
        case .familiarNames:
            canvas.page = familiarNamesPage(); canvas.preview = nil
        case .insightsToken:
            canvas.page = insightsTokenPage(); canvas.preview = nil
        case .insightsClear:
            canvas.page = insightsClearPage(); canvas.preview = nil
        case .settings:
            canvas.page = settingsGroupsPage(); canvas.preview = nil
        case let .settingsGroup(group):
            canvas.page = settingsPage(group); canvas.preview = nil
        case .language:
            canvas.page = languagePage(); canvas.preview = nil
        case .controllerMappings:
            canvas.page = controllerMappingsPage(); canvas.preview = nil
        case .playInsights:
            canvas.page = insightsDashboardPage(); canvas.preview = nil
        case .hotSeat:
            canvas.page = hotSeatPage(subtitle: subtitle); canvas.preview = nil
        case .hotSeats:
            canvas.page = savedHotSeatsPage(subtitle: subtitle); canvas.preview = nil
        case .cloudSaves:
            canvas.page = CloudSyncArt.page(testerEnabled: libraryCloud.testerSyncEnabled, busy: syncBusy, message: syncMessage, status: libraryCloud.status); canvas.preview = nil
        case .progress:
            canvas.page = progressPage(subtitle: subtitle); canvas.preview = nil
        case let .progressPlayer(profileID):
            canvas.page = MobileCareerArt.progressPlayerPage(records: arcadeStore.records, profileID: profileID, metric: progressMetric); canvas.preview = nil
        case let .progressLevel(key, parentProfileID):
            canvas.page = MobileCareerArt.progressLevelPage(records: arcadeStore.records, key: key,
                metric: progressLevelMetric, parentProfileID: parentProfileID); canvas.preview = nil
        case .records:
            canvas.page = recordsPage(subtitle: subtitle); canvas.preview = nil
        case .achievements:
            canvas.page = achievementsPage(subtitle: subtitle); canvas.preview = nil
        case let .recordLevel(board):
            canvas.page = recordLevelPage(board, subtitle: subtitle); showRecordPreview(board)
        case let .recordHint(board):
            canvas.page = recordHintPage(board); showRecordPreview(board)
        case .players:
            canvas.page = playersPage(subtitle: subtitle); canvas.preview = nil
        case .shuffleAll:
            canvas.page = shuffleAllPage(subtitle: subtitle); canvas.preview = nil
        case .collections:
            canvas.page = collectionsPage(subtitle: subtitle); canvas.preview = nil
        case .playlists:
            canvas.page = playlistsPage(subtitle: subtitle); canvas.preview = nil
        case let .playlist(id):
            canvas.page = playlistPage(id, subtitle: subtitle); canvas.preview = nil
        case .addToPlaylist:
            canvas.page = addToPlaylistPage(subtitle: subtitle); canvas.preview = nil
        case .soundtrack:
            canvas.page = soundtrackPage()
            canvas.preview = nil
        case .data:
            canvas.page = .init(title: L10n.text("Game Data"), subtitle: subtitle,
                                rows: MobileGameDataKind.allCases.map { kind in
                                    let installed = store.map { FileManager.default.fileExists(atPath: $0.dataDirectory(for: kind).path) } ?? false
                                    let action = installed ? L10n.text("Replace") : L10n.text("Import")
                                    return .init("import." + kind.rawValue,
                                                 "\(action) \(kind.displayTitle)", enabled: !loading)
                                },
                                details: library.map { ["\($0.displayName)", L10n.plural("count.levels", count: $0.levels.count, one: "%ld level", other: "%ld levels")] } ?? [],
                                footer: [.init("dataBack", L10n.text("Back"))])
            canvas.preview = nil
        }
        if !{ switch route { case .levels, .recordLevel, .recordHint: true; default: false } }() { canvas.previewSource = nil }
        view.setNeedsLayout()
        syncPages()
    }

    /// iPad keeps the Mac carousel in both orientations. Narrow panes use the stacked page.
    private func syncPages() {
        refreshHomeBackdrop()
        updateLibraryDisplayLink()
        browser.playerName = playerName(hotSeat?.turn ?? profiles.activeID)
        browser.statusText = loading ? "" : notice
        browser.isLoading = loading
        let available = MobileSystemRegions.menuFrame(in: view)
        let coverBrowser = available.width >= 600 && available.height >= 300
        let show = game == nil && route == .levels && coverBrowser && library != nil
        scrollView.isHidden = game != nil || show
        browser.isHidden = !show
        browser.artworkLoadingEnabled = show && viewIsVisible && sceneIsActive && !preparingLevel && libraryTask == nil
        if show, !browserShown, let library {
            browser.frame = view.bounds
            browser.configure(levels: library.levels.filter { canSelectJourneyLevel($0.index) }, selected: selectedIndex)
        }
        browserShown = show
        syncMenuMusic()
    }

    func syncMenuMusic() {
        #if os(iOS)
        if deskClock != nil { MobileMusic.shared.suspend(); return }
        #endif
        MobileMusic.shared.selectProfile(settingsProfileID)
        MobileMusic.shared.setMenu(visible: game == nil && !deskClockShown && viewIsVisible, active: sceneIsActive)
    }

    private func coverArtwork(_ index: Int) async -> CGImage? {
        guard game == nil, !preparingLevel, route == .levels, !Task.isCancelled,
              let loader = previewLoader, let preview = try? await loader.load(index, settings: mobileSettings.classic),
              !Task.isCancelled, game == nil, !preparingLevel,
              let image = MobileBitmapRenderer.image(preview.frame) else { return nil }
        let source = preview.sourceRect
        return image.cropping(to: CGRect(x: source.x, y: source.y, width: source.width, height: source.height))
    }
    func openGlobalSettings() {
        settingsReturn = (route, scrollView.contentOffset, canvas.focusedID)
        navigate(.settings)
    }

    func navigate(_ next: Route) {
        let position = NavigationPosition(route: route, offset: scrollView.contentOffset, focus: canvas.focusedID)
        let returning = navigationHistory.lastIndex { $0.route == next }
        let restore: NavigationPosition?
        if next == .home {
            restore = nil
            navigationHistory.removeAll()
        } else if next == route {
            restore = detailReturnPosition ?? position
        } else if let returning {
            restore = navigationHistory[returning]
            navigationHistory.removeSubrange(returning...)
        } else {
            restore = nil
            navigationHistory.append(position)
        }
        detailReturnPosition = nil
        if case .home = next { progressProfileID = nil }
        if next == .home { settingsReturn = nil }
        if next == .data, route != .data { dataBackRoute = route }
        if next != .familiarNames { familiarNames.clear() }
        if route == .language && next != .language { finishLanguageSelection(apply: false) }
        confirmingRecordsReset = false
        #if os(tvOS)
        // The launch notice must not cancel the library and saved-run load beneath it.
        let welcomeRoutes: [Route] = [.home, .support, .whatsNew, .effectsWelcome, .telemetryConsent]
        let preserveWelcomeLoad = library == nil && libraryTask != nil
            && welcomeRoutes.contains(route) && welcomeRoutes.contains(next)
        #else
        let preserveWelcomeLoad = false
        #endif
        if next == .hotSeat, hotSeatRoster == nil {
            hotSeatRoster = MobileHotSeatRoster(host: profiles.activeID, players: defaultHotSeatPlayers)
        }
        if next != .insightsToken {
            mobileInsights.field?.resignFirstResponder(); mobileInsights.field?.text = nil
            mobileInsights.field?.removeFromSuperview(); mobileInsights.field = nil; mobileInsights.token = ""
        }
        if next != .playInsights {
            mobileInsights.task?.cancel(); mobileInsights.loading = false
        }
        learningTask?.cancel(); learningPreparing = false
        if !preserveWelcomeLoad {
            libraryTask?.cancel(); libraryTask = nil; libraryGeneration = UUID()
        }
        if next != .shuffleAll { shuffleTask?.cancel(); shuffleTask = nil; shuffleScanning = false }
        searchField.resignFirstResponder()
        if nameDraft != nil, !{ if case .playlist = next { return true }; return next == .players }() { nameDraft = nil; renamingPlayer = false; creatingPlayer = false; editingPlayerID = nil; searchField.text = searchQuery }
        confirmingDelete = false
        stopMenuPreviews(); previewGeneration = UUID()
        if !preserveWelcomeLoad { loading = false }
        preparingLevel = false
        if route != next { canvas.focusedID = nil }
        globalNavigation.focusedID = nil
        route = next; notice = ""
        libraryInput.reset()
        if game == nil { becomeFirstResponder() }
        scrollView.setContentOffset(.zero, animated: false)
        rebuild()
        if let restore {
            view.layoutIfNeeded()
            let maximum = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            scrollView.setContentOffset(CGPoint(x: restore.offset.x, y: min(maximum, max(0, restore.offset.y))), animated: false)
            if let focus = restore.focus { canvas.focusAction(focus) }
        }
    }
    func handle(_ id: String) {
        if handleL2Practice(id) { return }
        if handleCloudSync(id) { return }
        if handleWelcome(id) || handleInsights(id) { return }
        if handleLearning(id) || handleRankings(id) { return }
        if handleSettings(id) { return }
        switch id {
        case "classic": levelsBackRoute = .home; navigate(.levels); selectLevel(selectedIndex)
        case "originalMovies": showOriginalMovies(); return
        case "l2":
            if hasLemmings2Data { openLemmings2() } else { navigate(.data) }
        case "l3":
            if hasLemmings3Data { openLemmings3() } else { navigate(.data) }
        case "neolemmix":
            if hasNeoLemmixData { openNeoLemmix() } else { navigate(.data) }
        case "home": navigate(.home)
        case "back": navigate(levelsBackRoute)
        case "dataBack": navigate(dataBackRoute)
        case "addPlaylistBack": navigate(.levels); selectLevel(selectedIndex)
        case "favourite": toggleFavourite(selectedIndex)
        case "favourites": openFavourites()
        case "fanGroupBack":
            if case let .fanGroup(path) = route {
                navigate(path.count > 1 ? .fanGroup(Array(path.dropLast())) : .family(.fan))
            }
        case "fanUpdate": checkForFanPacks()
        case "search":
            if searchField.isFirstResponder { searchField.resignFirstResponder() } else { searchField.becomeFirstResponder() }
            rebuild()
        case "searchClear":
            searchQuery = ""
            searchField.text = ""
            canvas.focusedID = "search"
            scrollView.setContentOffset(.zero, animated: false)
            rebuild()
        case "settings": navigate(.settings)
        case "settingsBack":
            let source = settingsReturn
            settingsReturn = nil
            navigate(source?.route ?? .home)
            view.layoutIfNeeded()
            if let source {
                let maximum = max(0, scrollView.contentSize.height - scrollView.bounds.height)
                scrollView.setContentOffset(CGPoint(x: source.offset.x, y: min(source.offset.y, maximum)), animated: false)
                if let focus = source.focus { canvas.focusAction(focus) }
            }
        #if os(iOS)
        case "deskClock": presentDeskClock(reason: .menu)
        #endif
        case "donate":
            #if os(tvOS)
            navigate(.support)
            #else
            UIApplication.shared.open(GameSupport.coffeeURL, options: [:]) { [weak self] opened in
                guard !opened else { return }
                Task { @MainActor [weak self] in
                    if self?.route == .home { self?.navigate(.support) }
                }
            }
            #endif
        case "data": navigate(.data)
        case "import": chooseGameData(for: .classic)
        case "import.classic": chooseGameData(for: .classic)
        case "import.lemmings2": chooseGameData(for: .lemmings2)
        case "import.lemmings3": chooseGameData(for: .lemmings3)
        case "import.neoLemmix": chooseGameData(for: .neoLemmix)
        case "resume": resumeSavedRun()
        case "previous": moveLevel(-1)
        case "next": moveLevel(1)
        case "rankPrevious": moveRank(-1)
        case "rankNext": moveRank(1)
        case "play": startLevel(selectedIndex, checkpoint: nil)
        case "soundtrack":
            let libraries = MobileMusicLibraries.shared
            libraries.onChange = { [weak self] in
                guard let self, self.route == .soundtrack else { return }
                self.rebuild()
            }
            navigate(.soundtrack)
        default:
            if handleRecords(id) || handleHotSeat(id) || handleCollections(id) { return }
            if id.hasPrefix("lib."), let pack = MobileMusicLibraries.shared.catalogue?.packs.first(where: { $0.id == String(id.dropFirst(4)) }) {
                let libraries = MobileMusicLibraries.shared
                if libraries.progress[pack.id] != nil { libraries.cancel(pack) }
                else if libraries.isInstalled(pack) { libraries.remove(pack) }
                else { libraries.download(pack) }
                rebuild()
            } else if id.hasPrefix("family."), let family = MobileFamily(rawValue: String(id.dropFirst(7))) {
                openFamily(family)
            } else if id.hasPrefix("fanGroup.") {
                let path: [String]
                if case let .fanGroup(current) = route { path = current } else { path = [] }
                let childID = String(id.dropFirst(9))
                if fanLibraryRoot().group(at: path)?.children.contains(where: { $0.id == childID && $0.packID == nil }) == true {
                    navigate(.fanGroup(path + [childID]))
                }
            } else if id.hasPrefix("pack."), let pack = catalogue?.pack(id: String(id.dropFirst(5))) {
                openPack(pack, back: route)
            }
        }
    }

    /// The pack and level key that identify the selected level in the favourites store.
    func favouriteIdentity(_ index: Int) -> (pack: String, level: String)? {
        guard let library else { return nil }
        if let list = library as? MobileFavouritesLibrary, let origin = list.origin(of: index),
           let source = catalogue?.pack(id: origin.pack), let real = try? catalogue?.library(for: source) {
            return (origin.pack, real.levelKey(at: origin.index))
        }
        if let journey = library as? MobileJourneyLibrary, let origin = try? journey.origin(of: index) {
            return (origin.pack, origin.library.levelKey(at: origin.index))
        }
        guard let pack = currentPack else { return nil }
        return (pack.id, library.levelKey(at: index))
    }

    func isFavourite(_ index: Int) -> Bool {
        favouriteIdentity(index).map { favourites.contains(pack: $0.pack, level: $0.level) } ?? false
    }

    private func toggleFavourite(_ index: Int) {
        guard let identity = favouriteIdentity(index) else { return }
        favourites.toggle(pack: identity.pack, level: identity.level)
        saveSharedCollections()
        browser.setFavourite(isFavourite(index))
        rebuild()
    }

    private func openFavourites() {
        openList(favourites.entries, name: "Favourites", back: route)
    }

    private func checkForFanPacks() {
        guard !fanUpdating, let catalogue else { return }
        fanUpdating = true
        fanUpdateStatus = "CHECKING..."
        rebuild()
        let existing = catalogue.packs(in: .fan).compactMap { pack -> URL? in
            if case let .fan(file) = pack.source { return file } else { return nil }
        }
        guard let support = try? FileManager.default.url(for: MobileStorage.localDirectory, in: .userDomainMask,
                                                         appropriateFor: nil, create: true) else { return }
        let destination = support.appendingPathComponent("Fan Levels", isDirectory: true)
        Task {
            let outcome = await FanPackUpdater().check(existing: existing, destination: destination)
            fanUpdating = false
            fanUpdateStatus = outcome.status
            measureMobileFanPacks()
            rebuild()
        }
    }

    private func solvedMark(_ pack: MobileContentPack) -> String {
        let done = solvedLevels(for: pack.id).count
        guard done > 0 else { return "" }
        return pack.levelCount.map { "  \(done)/\($0)" } ?? "  \(done)"
    }

    private static func makeCatalogue() -> MobileCatalogue? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let ports = resources.appendingPathComponent("Ports", isDirectory: true)
        guard FileManager.default.fileExists(atPath: ports.path) else { return nil }
        var fan = [resources.appendingPathComponent("LevelPacks", isDirectory: true)]
        if let support = try? FileManager.default.url(for: MobileStorage.localDirectory, in: .userDomainMask,
                                                      appropriateFor: nil, create: false) {
            fan.append(support.appendingPathComponent("Fan Levels", isDirectory: true))
        }
        return MobileCatalogue(portsRoot: ports, fanFolders: fan)
    }

    func fanLibraryRoot() -> FanLevelOrganisation.Group {
        FanLevelOrganisation.library((catalogue?.packs(in: .fan) ?? []).map { .init(id: $0.id, title: $0.title) }, query: searchQuery)
    }

    private func fanLibraryPage(path: [String], subtitle: String) -> GameFrontEnd.Page {
        let packs = catalogue?.packs(in: .fan) ?? []
        let details = Dictionary(packs.map { ($0.id, ($0.levelCount.map { "  \($0)" } ?? "") + solvedMark($0)) }, uniquingKeysWith: { first, _ in first })
        return FanLevelLibraryArt.page(root: fanLibraryRoot(), path: path, query: searchQuery,
            editing: searchField.isFirstResponder, status: subtitle.isEmpty ? fanUpdateStatus : subtitle,
            updating: fanUpdating, packDetails: details)
    }

    private func openFamily(_ family: MobileFamily) {
        guard let catalogue else { return }
        let packs = catalogue.packs(in: family)
        if family == .fan { searchQuery = ""; searchField.text = ""; navigate(.family(.fan)) }
        else if packs.count == 1, let pack = packs.first { openPack(pack, back: .home) }
        else { navigate(.family(family)) }
    }

    /// Makes a pack the current library and shows its levels.
    func openPack(_ pack: MobileContentPack, back: Route, checkpoint: MobileCheckpointEnvelope? = nil,
                  play index: Int? = nil, browse browseIndex: Int = 0) {
        guard let catalogue else { return }
        let ports = catalogue.portsRoot, fan = catalogue.fanFolders
        openLibrary({ try MobileCatalogue(portsRoot: ports, fanFolders: fan).library(for: pack) }) { [self] loaded in
            guard let loaded else { navigate(.data); return }
            library = loaded
            activeRun = nil
            currentPack = pack
            previewLoader = MobileMenuPreviewLoader { try MobileCatalogue(portsRoot: ports, fanFolders: fan).library(for: pack) }
            selectedIndex = 0; selectedPreview = nil; browserShown = false
            levelsBackRoute = back
            navigate(.levels)
            if let checkpoint {
                do { startLevel(try loaded.checkpointLevelIndex(for: checkpoint), checkpoint: checkpoint) }
                catch { notice = error.localizedDescription; rebuild() }
            }
            else if let index, loaded.levels.indices.contains(index) { selectedIndex = index; startLevel(index, checkpoint: nil) }
            else { selectLevel(loaded.levels.indices.contains(browseIndex) ? browseIndex : 0) }
        }
    }

    /// Opens content on a worker. Only the current request can change the menu.
    func openLibrary(_ makeLibrary: @escaping @Sendable () throws -> (any MobileGameLibrary)?,
                             completion: @escaping @MainActor ((any MobileGameLibrary)?) -> Void) {
        libraryTask?.cancel()
        stopMenuPreviews(); previewGeneration = UUID()
        preparingLevel = false
        let cancelledPreviews = previewDrain
        let generation = UUID(); libraryGeneration = generation
        loading = true
        libraryTask = Task {
            do {
                await cancelledPreviews?.value
                try Task.checkCancellation()
                let opened = try await libraryLoader.open(makeLibrary)
                guard !Task.isCancelled, libraryGeneration == generation, game == nil else { return }
                libraryTask = nil; loading = false
                completion(opened.library)
            } catch {
                guard !Task.isCancelled, libraryGeneration == generation else { return }
                libraryTask = nil; loading = false; notice = error.localizedDescription; rebuild()
            }
        }
        rebuild()
    }

    private func stopMenuPreviews() {
        let previous = previewTask
        previous?.cancel(); previewTask = nil
        let covers = browser.stopArtworkLoading()
        let draining = previewDrain
        previewDrain = Task {
            await draining?.value
            await previous?.value
            await covers?.value
        }
    }

    @objc private func swiped(_ gesture: UISwipeGestureRecognizer) {
        guard route == .levels, game == nil else { return }
        moveLevel(gesture.direction == .left ? 1 : -1)
    }
    func goBack() {
        guard game == nil, !deskClockBlocksInput else { return }
        if searchField.isFirstResponder { searchField.resignFirstResponder(); rebuild(); return }
        if browserShown { navigate(levelsBackRoute) } else { canvas.goBack() }
    }
    #if os(iOS)
    @objc private func edgeBack(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .ended, game == nil, !globalNavigation.isHidden,
              gesture.translation(in: view).x > 60 || gesture.velocity(in: view).x > 500 else { return }
        goBack()
    }
    #endif
    private func moveLevel(_ offset: Int) {
        guard let library else { return }
        let index = selectedIndex + offset
        guard library.levels.indices.contains(index),
              (library is MobileJourneyLibrary || library.levels[index].rank == library.levels[selectedIndex].rank) else { return }
        selectLevel(index)
    }
    private func moveRank(_ offset: Int) {
        guard let library else { return }
        var ranks: [String] = []
        for level in library.levels where !ranks.contains(level.rank) { ranks.append(level.rank) }
        guard let current = ranks.firstIndex(of: library.levels[selectedIndex].rank) else { return }
        let next = (current + offset + ranks.count) % ranks.count
        if let level = library.levels.first(where: { $0.rank == ranks[next] }) { selectLevel(level.index) }
    }
    func canSelectJourneyLevel(_ index: Int) -> Bool {
        guard library is MobileJourneyLibrary, let run = learning.run else { return true }
        return index <= run.currentIndex || mobileSettings.classic.unlockAllClassicLevels
    }
    func selectLevel(_ index: Int) {
        guard game == nil, !preparingLevel, libraryTask == nil, canSelectJourneyLevel(index) else { return }
        guard let previewLoader else { selectedIndex = index; rebuild(); return }
        let previous = previewTask, draining = previewDrain
        previous?.cancel()
        previewDrain = Task {
            await draining?.value
            await previous?.value
        }
        let generation = UUID(); previewGeneration = generation
        notice = ""; loading = true; rebuild()
        previewTask = Task {
            do {
                let preview = try await previewLoader.load(index, settings: mobileSettings.classic)
                guard !Task.isCancelled, previewGeneration == generation, route == .levels else { return }
                selectedIndex = index; selectedPreview = preview; loading = false
                rebuild()
            } catch {
                guard !Task.isCancelled, previewGeneration == generation else { return }
                loading = false; notice = error.localizedDescription
                rebuild()
            }
        }
    }
    private func reloadLibrary() {
        homeBackdropTask?.cancel(); homeBackdropTask = nil; homeBackdropKey = nil
        let store = store
        let directory = Bundle.main.resourceURL?.appendingPathComponent("BetaGameData", isDirectory: true)
        openLibrary({ try store?.loadLibrary(bundledDirectory: directory) }) { [self] loaded in
            library = loaded
            if let classic = loaded as? ClassicMobileLibrary {
                let directory = classic.directory
                previewLoader = MobileMenuPreviewLoader { try ClassicMobileLibrary(directory: directory) }
            }
            selectedIndex = 0; selectedPreview = nil
            if library == nil, catalogue == nil { route = .data }
            rebuild(); loadCheckpoint()
        }
    }
    private func openLemmings2(at requestedIndex: Int? = nil,
                               checkpoint: MobileCheckpointEnvelope? = nil) {
        guard let store else { navigate(.data); return }
        let progressStorage = learningStorage
        do { try MobileCampaignProgress.reconcile(sharedCampaignProgress, storage: progressStorage) }
        catch { notice = error.localizedDescription; rebuild(); return }
        openLibrary({ try store.loadLemmings2Library(storage: progressStorage) }) { [self] opened in
            guard let loaded = opened as? Lemmings2MobileLibrary else { navigate(.data); return }
            if let checkpoint, let practice = try? Lemmings2PracticeMobileLibrary.restoring(checkpoint.levelIdentifier, source: loaded) {
                library = practice
                currentPack = nil; activeRun = nil; levelsBackRoute = .l2Practice
                selectedIndex = 0; selectedPreview = nil
                let directory = loaded.directory, choice = practice.choice, skills = practice.skills
                previewLoader = MobileMenuPreviewLoader {
                    try Lemmings2PracticeMobileLibrary(source: Lemmings2MobileLibrary(directory: directory, storage: progressStorage), choice: choice, skills: skills)
                }
                navigate(.levels); startLevel(0, checkpoint: checkpoint)
                return
            }
            library = loaded
            currentPack = nil
            activeRun = nil
            levelsBackRoute = .home
            selectedIndex = requestedIndex ?? loaded.currentLevelIndex
            selectedPreview = nil
            browserShown = false
            let directory = loaded.directory
            previewLoader = MobileMenuPreviewLoader {
                try Lemmings2MobileLibrary(directory: directory, storage: progressStorage)
            }
            navigate(.levels)
            if let checkpoint {
                startLevel(checkpoint.levelIndex, checkpoint: checkpoint)
            } else {
                selectLevel(selectedIndex)
            }
        }
    }
    private func openLemmings3(at requestedIndex: Int? = nil,
                               checkpoint: MobileCheckpointEnvelope? = nil) {
        guard let store else { navigate(.data); return }
        let progressStorage = learningStorage
        do { try MobileCampaignProgress.reconcile(sharedCampaignProgress, storage: progressStorage) }
        catch { notice = error.localizedDescription; rebuild(); return }
        openLibrary({ try store.loadLemmings3Library(storage: progressStorage) }) { [self] opened in
            guard let loaded = opened as? Lemmings3MobileLibrary else { navigate(.data); return }
            library = loaded
            currentPack = nil
            activeRun = nil
            levelsBackRoute = .home
            selectedIndex = requestedIndex ?? loaded.currentLevelIndex
            selectedPreview = nil
            browserShown = false
            let directory = loaded.directory
            previewLoader = MobileMenuPreviewLoader {
                try Lemmings3MobileLibrary(directory: directory, storage: progressStorage)
            }
            navigate(.levels)
            if let checkpoint {
                startLevel(checkpoint.levelIndex, checkpoint: checkpoint)
            } else {
                selectLevel(selectedIndex)
            }
        }
    }
    private func openNeoLemmix(at requestedIndex: Int? = nil,
                               checkpoint: MobileCheckpointEnvelope? = nil) {
        guard let directory = store?.resolvedDataDirectory(for: .neoLemmix) else {
            navigate(.data)
            return
        }
        let progressStorage = storage
        openLibrary({ try NeoLemmixMobileLibrary(directory: directory, storage: progressStorage) }) { [self] opened in
            guard let loaded = opened as? NeoLemmixMobileLibrary else { navigate(.data); return }
            let restoredIndex = checkpoint.flatMap { saved in
                loaded.levels.indices.first { index in
                    guard let identifier = try? loaded.checkpointLevelIdentifier(at: index) else { return false }
                    return identifier == saved.levelIdentifier
                }
            }
            if checkpoint != nil, restoredIndex == nil {
                navigate(.home)
                notice = L10n.text("The saved NeoLemmix level is no longer available.")
                rebuild()
                return
            }
            library = loaded
            currentPack = nil
            activeRun = nil
            levelsBackRoute = .home
            selectedIndex = restoredIndex ?? requestedIndex ?? loaded.currentLevelIndex
            selectedPreview = nil
            browserShown = false
            let progressStorage = storage
            previewLoader = MobileMenuPreviewLoader {
                try NeoLemmixMobileLibrary(directory: directory, storage: progressStorage)
            }
            navigate(.levels)
            if let checkpoint {
                startLevel(restoredIndex ?? checkpoint.levelIndex, checkpoint: checkpoint)
            } else {
                selectLevel(selectedIndex)
            }
        }
    }
    private func chooseGameData(for kind: MobileGameDataKind) {
        selectedImportKind = kind
        #if os(tvOS)
        MobileTVFileTransfer.importFiles(from: self, directory: true) { [weak self] url in self?.receiveGameData(url) }
        #else
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = self; picker.allowsMultipleSelection = false
        present(picker, animated: true)
        #endif
    }
    #if os(iOS)
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let source = urls.first else { return }
        receiveGameData(source)
    }
    #endif
    func receiveGameData(_ source: URL) {
        guard let store else { return }
        let kind = selectedImportKind
        loading = true; rebuild()
        let accessed = source.startAccessingSecurityScopedResource()
        Task {
            defer {
                if accessed { source.stopAccessingSecurityScopedResource() }
                #if os(tvOS)
                MobileTVFileTransfer.removeImportedFiles(source)
                #endif
            }
            let result = await Task.detached(priority: .userInitiated) {
                Result { try store.install(directory: source, for: kind) }
            }.value
            loading = false
            switch result {
            case .success: notice = ""; reloadLibrary()
            case let .failure(error): notice = error.localizedDescription; rebuild()
            }
        }
    }
    func loadCheckpoint() {
        pendingCheckpoint = nil
        guard let checkpointStore else { return }
        let owner = profiles.activeID, scope = hotSeat?.scope
        Task {
            do {
                let checkpoint = try await checkpointStore.load(owner: owner, scope: scope)
                guard profiles.activeID == owner, hotSeat?.scope == scope else { return }
                pendingCheckpoint = checkpoint; rebuild()
            }
            catch {
                guard profiles.activeID == owner, hotSeat?.scope == scope else { return }
                pendingCheckpoint = nil; notice = error.localizedDescription; rebuild()
            }
        }
    }
    func resumeSavedRun() {
        guard let checkpoint = pendingCheckpoint, checkpointMatchesSession(checkpoint) else { return }
        if let run = playlists.run, Lemmings2ShortPlayMobileLibrary.matches(run.entries),
           checkpoint.matchesJourney(runID: run.id, position: run.position, levelIdentifier: checkpoint.levelIdentifier) {
            openTribesShortRun(run, back: .collections, position: run.position, checkpoint: checkpoint, startImmediately: true)
            return
        }
        if checkpoint.engine == "lemmings2" {
            openLemmings2(at: checkpoint.levelIndex, checkpoint: checkpoint)
            return
        }
        if checkpoint.engine == "lemmings3" {
            openLemmings3(at: checkpoint.levelIndex, checkpoint: checkpoint)
            return
        }
        if checkpoint.engine == "neolemmix" {
            openNeoLemmix(at: checkpoint.levelIndex, checkpoint: checkpoint)
            return
        }
        if checkpointResumesLearningRun(checkpoint) {
            openLearningRun(checkpoint: checkpoint); return
        }
        if let run = playlists.run, let catalogue {
            let queue = MobileListLibrary(entries: run.entries, name: run.name, catalogue: catalogue, lazy: true)
            if checkpoint.matchesJourney(runID: run.id, position: run.position,
                levelIdentifier: try? queue.checkpointLevelIdentifier(at: run.position)) {
                openList(run.entries, name: run.name, back: .collections, run: run, position: run.position,
                         checkpoint: checkpoint, startImmediately: true)
                return
            }
        }
        activeRun = nil
        if let catalogue, let pack = catalogue.pack(forLevelIdentifier: checkpoint.levelIdentifier) {
            openPack(pack, back: .home, checkpoint: checkpoint)
            return
        }
        startLevel(checkpoint.levelIndex, checkpoint: checkpoint)
    }

    /// Browsing a saved attempt leaves its checkpoint, player and turn unchanged.
    func browseSavedRun() {
        guard let checkpoint = pendingCheckpoint, checkpointMatchesSession(checkpoint) else {
            if let run = playlists.run {
                openList(run.entries, name: run.name, back: .home, run: run, position: run.position)
            }
            return
        }
        if checkpointResumesLearningRun(checkpoint) { openLearningRun(); return }
        switch checkpoint.engine {
        case "lemmings2": openLemmings2(at: checkpoint.levelIndex)
        case "lemmings3": openLemmings3(at: checkpoint.levelIndex)
        case "neolemmix": openNeoLemmix(at: checkpoint.levelIndex)
        default:
            if let run = playlists.run, let catalogue {
                let queue = MobileListLibrary(entries: run.entries, name: run.name, catalogue: catalogue, lazy: true)
                if checkpoint.matchesJourney(runID: run.id, position: run.position,
                    levelIdentifier: try? queue.checkpointLevelIdentifier(at: run.position)) {
                    openList(run.entries, name: run.name, back: .home, run: run, position: run.position)
                    return
                }
            }
            if let pack = catalogue?.pack(forLevelIdentifier: checkpoint.levelIdentifier) {
                openPack(pack, back: .home, browse: checkpoint.levelIndex)
            }
        }
    }
    func startLevel(_ index: Int, checkpoint: MobileCheckpointEnvelope?, restoringMatchingCheckpoint: Bool = false) {
        guard !preparingLevel, libraryTask == nil, canSelectJourneyLevel(index), let library, let checkpointStore else { return }
        guard let previewLoader else { return }
        let settings = MobileSettings.load(from: .standard, profileID: checkpoint?.owner ?? settingsProfileID).classic
        stopMenuPreviews()
        let cancelledPreviews = previewDrain
        let generation = UUID(); previewGeneration = generation
        #if os(iOS)
        dismissDeskClock()
        #endif
        notice = ""; preparingLevel = true; loading = true; rebuild()
        let menuTasks = [fanCountsTask, shuffleTask, learningTask].compactMap { $0 }
        menuTasks.forEach { $0.cancel() }
        fanCountGeneration = UUID(); fanCountsTask = nil
        shuffleTask = nil; shuffleScanning = false
        learningTask = nil; learningPreparing = false
        previewTask = Task {
            do {
                await cancelledPreviews?.value
                for task in menuTasks { await task.value }
                try Task.checkCancellation()
                let prepared = try await previewLoader.prepare(index, settings: settings,
                    checkpoint: checkpoint, allowUnrelatedCheckpoint: restoringMatchingCheckpoint)
                guard !Task.isCancelled, previewGeneration == generation else { return }
                loading = false; preparingLevel = false
                let matching = restoringMatchingCheckpoint && checkpoint?.levelIdentifier != prepared.content.session.levelIdentifier
                    ? nil : checkpoint
                if library is MobileJourneyLibrary {
                    var saved = learning
                    try saved.select(index)
                    try saveLearningState(saved)
                }
                presentPreparedLevel(index, checkpoint: matching, library: library,
                                     checkpointStore: checkpointStore, content: prepared.content)
            } catch {
                guard !Task.isCancelled, previewGeneration == generation else { return }
                loading = false; preparingLevel = false
                if let game { game.showPreparationError(error.localizedDescription) }
                else { notice = error.localizedDescription; rebuild() }
            }
        }
    }
    private func presentPreparedLevel(_ index: Int, checkpoint: MobileCheckpointEnvelope?, library: any MobileGameLibrary,
                                      checkpointStore: MobileCheckpointStore, content: MobileLevelContent) {
        do {
            if let checkpoint {
                guard checkpoint.engine == content.session.engineIdentifier,
                      checkpoint.engineFingerprint == content.session.engineFingerprint,
                      checkpoint.levelIdentifier == content.session.levelIdentifier,
                      checkpoint.levelFingerprint == content.session.levelFingerprint else { throw MobileSessionError.changedLevel }
                // A shared run resumes only in its own session, with the player who started it.
                guard checkpointMatchesSession(checkpoint) else { throw MobileSessionError.changedLevel }
                if let owner = checkpoint.owner, hotSeat?.players.contains(owner) == true {
                    guard handOver(to: owner) else {
                        if let game { game.showPreparationError(notice) }
                        else { rebuild() }
                        return
                    }
                }
            }
            levelStarted(index)
            // Playlist and shuffle results do not advance campaign or pack progress.
            let inLearning = library is MobileJourneyLibrary
            let inRun = activeRun != nil || inLearning
            let next = MobileGameViewController(summary: content.summary, session: content.session,
                                               checkpointStore: checkpointStore, restoredCheckpoint: checkpoint,
                                               turn: currentTurn(), settingsProfileID: checkpoint?.owner ?? settingsProfileID)
            if inLearning, let run = learning.run {
                next.journeyContext = .init(runID: run.id, position: index)
            } else if let run = activeRun {
                next.journeyContext = .init(runID: run.id, position: index)
            }
            let journeyMusic = inLearning && self.learning.run?.pool.id.hasPrefix("learning-") == true
            var sourceTitles = library.levels.map(\.title)
            if let queue = library as? MobileJourneyLibrary, let origin = try? queue.origin(of: index) { sourceTitles = origin.library.levels.map(\.title) }
            else if let queue = library as? MobileFavouritesLibrary, let origin = queue.origin(of: index),
                    let pack = catalogue?.pack(id: origin.pack), let source = try? catalogue?.library(for: pack) { sourceTitles = source.levels.map(\.title) }
            let fullJourney = self.bundledJourney
            let fullPosition = journeyMusic ? (library as? MobileJourneyLibrary).flatMap { queue in
                fullJourney?.lessons.firstIndex { $0.entry.identity == queue.entries[index].identity }
            } : nil
            next.musicContext = MobileMusicContext(scorePosition: fullPosition, titles: journeyMusic ? (fullJourney?.lessons.map { $0.entry.levelNameSnapshot } ?? sourceTitles) : sourceTitles,
                isFan: content.session.levelIdentifier.hasPrefix("fan/"), isLearningJourney: journeyMusic)
            next.canDefer = inLearning
            next.soloOwnerID = profiles.activeID
            let attemptID = checkpoint?.runID ?? next.recordRunID
            let ownerID = checkpoint?.owner ?? hotSeat?.turn ?? profiles.activeID
            let recordLevel = mobileArcadeLevel(session: content.session, summary: content.summary,
                pack: favouriteIdentity(index)?.pack ?? library.displayName)
            if checkpoint != nil, let use = checkpoint?.extraSkillUse
                ?? arcadeStore.records.extraSkillUse(attemptID: attemptID, profileID: ownerID) {
                guard use.attemptID == attemptID, use.originalConditions == recordLevel.conditions,
                      content.session.retainExtraSkillUse(use.skill),
                      arcadeStore.recoverExtraSkillUse(use, profileID: ownerID) else {
                    throw MobileSessionError.invalidCheckpoint
                }
            }
            var skipRollback: (() throws -> Void)?
            var skippedJourneyAdvance: Bool?
            if inLearning || (!inRun && library.canSkipLevel(at: index)) {
                next.onSkipBalance = { [weak self] in
                    guard let self, !self.arcadeStore.records.hasSkipped(recordLevel, profileID: ownerID),
                          self.arcadeStore.profilesAreWritable, self.arcadeStore.storageError == nil else { return 0 }
                    return self.arcadeStore.records.levelSkips(profileID: ownerID).available
                }
                next.onSkipLevel = { [weak self] in
                    guard let self, self.arcadeStore.spendLevelSkip(on: recordLevel, profileID: ownerID) else { return false }
                    do {
                        if inLearning {
                            let previous = self.learning
                            skipRollback = { [weak self] in try self?.saveLearningState(previous) }
                            var saved = previous
                            saved.record(won: false)
                            let advanced = saved.advance()
                            try self.saveLearningState(saved)
                            skippedJourneyAdvance = advanced
                        } else { skipRollback = try library.prepareLevelSkip(at: index) }
                        return true
                    } catch {
                        try? skipRollback?()
                        skipRollback = nil; skippedJourneyAdvance = nil
                        _ = self.arcadeStore.returnLevelSkip(on: recordLevel, profileID: ownerID)
                        self.notice = error.localizedDescription
                        return false
                    }
                }
                next.onRefundSkip = { [weak self] in
                    guard let self else { return false }
                    do {
                        try skipRollback?()
                        guard self.arcadeStore.returnLevelSkip(on: recordLevel, profileID: ownerID) else { return false }
                        skipRollback = nil; skippedJourneyAdvance = nil
                        return true
                    } catch { self.notice = error.localizedDescription; return false }
                }
            }
            if checkpoint == nil {
                guard arcadeStore.beginAttempt(id: attemptID, profileID: ownerID, level: recordLevel,
                                               previousID: game?.recordRunID) else {
                    throw NSError(domain: "MobileRecords", code: 1, userInfo: [NSLocalizedDescriptionKey:
                        arcadeStore.storageError ?? L10n.text("The attempt was not saved.")])
                }
            }
            next.onExtraSkillBalance = { [weak self] in
                guard let self, self.arcadeStore.records.extraSkillSpent(attemptID: attemptID, profileID: ownerID) == nil else { return 0 }
                return self.arcadeStore.records.extraSkills(profileID: ownerID).available
            }
            next.onExtraSkillUse = { [weak self] in
                self?.arcadeStore.records.extraSkillUse(attemptID: attemptID, profileID: ownerID)
            }
            next.onSpendExtraSkill = { [weak self, weak session = content.session] choice in
                guard let self, let session, let conditions = recordLevel.conditions else { return false }
                return self.arcadeStore.spendExtraSkill(attemptID: attemptID, profileID: ownerID,
                    skill: choice.skillID, conditions: conditions, existingLevelSkills: session.existingLevelSkills)
            }
            AnonymousTelemetry.shared.start(recordLevel, hotSeat: hotSeat != nil, attemptID: attemptID)
            let ghostSeat = hotSeat
            if let ghostSeat, let initial = content.session.actionReplayInitial {
                content.session.hotSeatGhosts = arcadeStore.hotSeatGhosts(initial: initial, level: recordLevel,
                    playerID: ownerID, sessionID: ghostSeat.id, players: ghostSeat.players)
                content.session.hotSeatGhosts?.hidden = !arcadeStore.hotSeatGhostsVisible
            }
            next.onHotSeatGhostsVisible = { [weak self] in self?.arcadeStore.hotSeatGhostsVisible = $0 }
            next.onRecordCompletion = { [weak self, weak session = content.session] snapshot in
                guard let self, let session else { return ([], L10n.text("Records are not available.")) }
                if snapshot.didWin {
                    let origin: (ClassicFanMobileLibrary, Int)?
                    if let fan = library as? ClassicFanMobileLibrary { origin = (fan, index) }
                    else if let list = library as? MobileFavouritesLibrary, let source = list.resolvedOrigin(of: index),
                            let fan = source.library as? ClassicFanMobileLibrary { origin = (fan, source.index) }
                    else if let journey = library as? MobileJourneyLibrary, let source = try? journey.origin(of: index),
                            let fan = source.library as? ClassicFanMobileLibrary { origin = (fan, source.index) }
                    else { origin = nil }
                    if let (fan, level) = origin, fan.entries.indices.contains(level) {
                        GameProgressPreferences.saveFanLevel(pack: fan.pack.url, label: fan.entries[level].label,
                            profileID: ownerID, sessionID: ghostSeat?.id)
                    }
                }
                if let sequence = library as? Lemmings2ShortPlayMobileLibrary, let run = self.activeRun {
                    do {
                        guard let bridge = self.collectionsBridge else { throw MobileSessionError.invalidCheckpoint }
                        _ = try sequence.record(session) { progress in
                            try bridge.store.setL2Progress(progress, key: Lemmings2ShortPlayMobileLibrary.progressKey, runID: run.id)
                        }
                    } catch { return ([], error.localizedDescription) }
                }
                if inLearning {
                    do { try self.recordLearningResult(snapshot) }
                    catch { return ([], error.localizedDescription) }
                }
                let conditions = self.arcadeStore.records.extraSkillUse(attemptID: attemptID, profileID: ownerID)?.conditions
                    ?? self.arcadeStore.records.trolley.starts.first {
                    $0.id == attemptID && $0.profileID == ownerID
                }?.conditions ?? recordLevel.conditions
                let completedLevel = ArcadeLevel(id: recordLevel.id, title: recordLevel.title,
                    game: recordLevel.game, rules: recordLevel.rules, total: recordLevel.total,
                    required: recordLevel.required, conditions: conditions)
                let run = MobileGameResult.capture(id: attemptID, profileID: ownerID,
                    level: completedLevel, session: session)
                return self.recordMobileCompletion(run, session: session, hotSeat: ghostSeat)
            }
            if ["lemmings2", "lemmings3"].contains(content.session.engineIdentifier),
               let directory = store?.resolvedDataDirectory(for: content.session.engineIdentifier == "lemmings2" ? .lemmings2 : .lemmings3) {
                let engine = content.session.engineIdentifier
                next.onOriginalMovies = { [weak next] in
                    guard let next else { return }
                    next.pausePlay(showControls: true)
                    next.present(MobileOriginalMediaController(engine: engine, directory: directory), animated: false)
                }
            }
            next.onResultAchievements = { [weak self] in self?.mobileResultAchievements(runID: attemptID) ?? [] }
            next.onResultAwards = { [weak self] in self?.mobileResultAwards(runID: attemptID) ?? (0, false) }
            next.onResultRewards = { [weak self] in self?.mobileResultRewards(runID: attemptID) ?? [] }
            next.onLevelLeaderboard = { [weak self] in self?.mobileLevelLeaderboard() }
            next.onLevelLeaderboardMetric = { [weak self] in
                guard let community = self?.mobileRankings.community else { return }
                community.refreshLevel(conditions: community.levelConditions, category: community.levelCategory.next())
            }
            mobileRankings.community.onLevelChange = { [weak next] in next?.refreshLevelLeaderboard() }
            next.onHandover = { [weak self] player in self?.handOver(to: player) ?? false }
            next.onCompleted = { [weak self] snapshot in
                guard let self else { return }
                if inLearning { return }
                guard snapshot.didWin else { return }
                if inRun { self.finishRunIfNeeded(afterLast: index); return }
                var pack = self.currentPack?.id, real = index
                if let list = library as? MobileFavouritesLibrary, let origin = list.origin(of: index) {
                    pack = origin.pack; real = origin.index
                }
                var completed = self.solvedLevels(for: pack); completed.insert(real)
                UserDefaults.standard.set(completed.sorted(),
                                          forKey: self.progressKey(for: pack, fallback: self.library?.displayName ?? "classic"))
                self.arcadeStore.notifyProgressChanged()
            }
            next.onExit = { [weak self] action in
                guard let self else { return }
                switch action {
                case .library, .menu:
                    self.previewTask?.cancel(); self.previewGeneration = UUID()
                    self.loading = false; self.preparingLevel = false
                    self.game?.willMove(toParent: nil); self.game?.view.removeFromSuperview(); self.game?.removeFromParent()
                    self.game = nil
                    if action == .menu { self.navigate(.home) }
                    self.loadCheckpoint(); self.rebuild(); self.presentCloudAuthentication()
                    self.syncMenuMusic()
                    self.measureMobileFanPacks()
                    #if os(iOS)
                    self.cloudProgress.requestSync()
                    self.setNeedsUpdateOfHomeIndicatorAutoHidden()
                    #endif
                case .retry: self.startLevel(index, checkpoint: nil)
                case .next:
                    if inLearning {
                        do {
                            let advanced: Bool
                            if let skipped = skippedJourneyAdvance {
                                advanced = skipped; skippedJourneyAdvance = nil; skipRollback = nil
                            } else { advanced = try self.advanceLearningRun() }
                            if !advanced {
                                self.navigate(.journey); self.game?.onExit?(.library); return
                            }
                        } catch { self.game?.showPreparationError(error.localizedDescription); return }
                    }
                    if library.levels.indices.contains(index + 1) { self.startLevel(index + 1, checkpoint: nil) }
                    else { self.finishRunIfNeeded(afterLast: index); self.handle("home"); self.game?.onExit?(.library) }
                }
            }
            let previous = game
            if let previous { next.inheritSolution(from: previous) }
            #if os(iOS)
            if let deskClock, deskClock.reason == .tent {
                next.setDeskClockVisible(true)
                MobileDeskClockController.attach(next, to: self, closing: nil)
                deskClock.view.superview?.bringSubviewToFront(deskClock.view)
            } else {
                MobileDeskClockController.attach(next, to: self, closing: deskClock)
            }
            #else
            addChild(next); next.view.frame = view.bounds
            next.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(next.view); next.didMove(toParent: self)
            #endif
            game = next
            rememberHomeBackdrop(content.session, at: index)
            syncPages()
            previous?.willMove(toParent: nil); previous?.view.removeFromSuperview(); previous?.removeFromParent()
            #if os(iOS)
            setNeedsUpdateOfHomeIndicatorAutoHidden()
            #endif
        } catch {
            if let game { game.showPreparationError(error.localizedDescription) }
            else { notice = error.localizedDescription; rebuild() }
        }
    }
}
#endif

#if os(iOS)
extension MobileLibraryViewController: DeskClockHost {
    /// Only Home counts as the menu. A level, a sheet, a loading level, a moving scroll view or an active
    /// text field blocks the clock.
    var deskClockScreen: DeskClockScreen {
        DeskClockAutomaticEntry.screen(game: game?.deskClockScreen, home: route == .home,
            textEditing: searchField.isFirstResponder || mobileInsights.field?.isFirstResponder == true
                || familiarNames.field?.isFirstResponder == true,
            blocked: presentedViewController != nil || preparingLevel || learningPreparing || shortGamesPreparing
                || scrollView.isTracking || scrollView.isDecelerating)
    }
    var deskClockSettings: DeskClockSettings { mobileSettings.deskClock }
    var deskClockRegionView: UIView { deskClockWindow ?? view }
}
#endif
