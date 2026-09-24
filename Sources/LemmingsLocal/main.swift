import AppKit
import AVFoundation
import NxlvKit
import Sparkle

let displayInterval = 1.0 / 60.0
let contentPathKey = "ClassicDataDirectory"
let gamePathsKey = "ClassicGameDirectories"
let stylesPathKey = "NeoLemmixStylesDirectory"
let progressKey = "ModernCampaignProgress"
let musicPathKey = "MusicDirectory"
let musicPresetKey = "MusicUsesModernPreset"
let macImageKey = "MacintoshDiskImage"
let flowProgressKey = "ClassicGameProgress"
let settingsKey = "ClassicSettings"
let achievementProgressKey = "ClassicAchievementProgress"

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  private static let allLemmingsMenuTitle = "Oh My! ALL Lemmings!"
  private lazy var updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil)
  private var window: NSWindow!
  private let playfield = PlayfieldView()
  private let panel = PanelView()
  private let crtView = CRTView()
  /// The plain view hierarchy, used when the tube is off.
  private var plainRoot: NSView?
  private var panelHeightConstraint: NSLayoutConstraint?
  private var tubeIsActive = false
  private let picker = GamePopUpButton()

  private var campaign: ClassicCampaign?
  private var grounds: [Int: ClassicGroundSet] = [:]
  private var specials: [Int: ClassicSpecialGraphic] = [:]
  private var loadedArtworkDirectory: URL?
  private var portArtworkFamily: String?
  /// Every imported game, in the order they were added.
  private var dataSets: [(set: ClassicDataSet, directory: URL)] = []
  private var dataSetIdentityCache: [String: String] = [:]
  private let gamePicker = GamePopUpButton()
  private var assets: ClassicMainDATAssets?
  private var macArtworkCache: [String: ClassicMacArtwork] = [:]
  private var contentDirectory: URL?
  private var stylesDirectory: URL?

  private var session: (any GameSession)?
  private var timer: Timer?
  private var rewindTimer: Timer?
  private var rewindHeld = false
  private var backwardKeyTimer: Timer?
  private var backwardKeyHeld = false
  private var rewindOriginTick: Int?
  private var rewindAudioDucked = false
  private var forwardTimer: Timer?
  private var forwardHeld = false
  private var forwardKeyTimer: Timer?
  private var forwardKeyHeld = false
  private var accumulator = 0.0
  private var lastStepTime: TimeInterval?
  private var isPaused = false
  private let speedControl = GameSpeedControl()
  private var isFastForward: Bool {
    get { speedControl.isFast }
    set { speedControl.setFast(newValue) }
  }
  private var countdownWarning = LastSecondsWarning()
  private let runMovie = RunMovie()
  private var replaySize = CGSize(width: 1280, height: 720)
  private let pointerCapture = GamePointerCapture()
  private let screenFlash = ExplosionHDRView(frame: .zero)
  /// True only for the transition that takes the launch straight to full screen.
  private var launchingFullScreen = false
  private var phase: GamePhase = .briefing {
    didSet { if phase != oldValue && phase != .playing { screenFlash.clear() } }
  }
  /// The whole game, from title to end.
  private var flow: ClassicGameFlow?
  private var classicSelectionRecordsCampaignProgress = true
  private var launchChoice = 0
  private var launchMode: UnifiedGameLibrary.Mode = .quest
  private var library = UnifiedGameLibrary(entries: [])
  /// The player-facing families on the home screen. These group releases for
  /// browsing only. Saved progress and quest order keep their ClassicTitle
  /// identities.
  private enum HomeContentFamily: CaseIterable, Equatable {
    case classic
    case ohNo
    case holiday
    case ohYes
    case fan
    case lemmings2
    case lemmings3

    var displayName: String {
      switch self {
      case .classic: return "Classic Lemmings"
      case .ohNo: return "Oh No! More Lemmings"
      case .holiday: return "Holiday Lemmings"
      case .ohYes: return "Oh Yes! More Lemmings"
      case .fan: return "Fan Lemmings"
      case .lemmings2: return "Lemmings 2"
      case .lemmings3: return "Lemmings 3"
      }
    }

    var titles: [ClassicTitle] {
      switch self {
      case .classic: return [.lemmings]
      case .ohNo: return [.ohNoMoreLemmings]
      case .holiday:
        return [.xmasLemmings1991, .xmasLemmings1992,
          .holidayLemmings1993, .holidayLemmings1994]
      case .ohYes: return [.ohYesMoreLemmings]
      case .fan: return []
      case .lemmings2: return [.lemmings2TheTribes]
      case .lemmings3: return [.lemmings3TheChronicles]
      }
    }

    static func family(
      for title: ClassicTitle?,
      kind: ClassicDataSet.Kind? = nil
    ) -> HomeContentFamily {
      if title == .ohYesMoreLemmings { return .ohYes }
      if let kind, case .scanned = kind { return .fan }
      guard let title else { return .fan }
      switch title {
      case .lemmings: return .classic
      case .ohNoMoreLemmings: return .ohNo
      case .xmasLemmings1991, .xmasLemmings1992,
           .holidayLemmings1993, .holidayLemmings1994:
        return .holiday
      case .ohYesMoreLemmings: return .ohYes
      case .lemmings2TheTribes: return .lemmings2
      case .lemmings3TheChronicles: return .lemmings3
      }
    }
  }
  private enum HomeMenuAction {
    case resume
    case fullQuest
    case browse(HomeContentFamily)
  }
  private struct HomeMenuItem {
    let title: String
    let action: HomeMenuAction
  }
  private var activeTitle: ClassicTitle?
  private var sequelIsActive: Bool { nativeL2Window != nil || nativeL3Window != nil }
  private var classicContent: NSView?
  private var sequelCompletion: [ClassicTitle: Int] = [:]
  private let effectsWelcome = EffectsWelcome()
  private var settingsWindow: SettingsWindow?
  private var settings = ClassicSettings()
  private var audioMuted = false
  private var audioIsSleeping = false
  private var previousDepth = ClassicColorDepth.full
  private var rankChoice = 0
  private var progress = ModernCampaignProgress()
  private var achievements = ClassicAchievementProgress()
  private let achievementsWindow = AchievementsWindow()
  private var arcadeLevel: ArcadeLevel?
  private var hintMap: CGImage?
  private var arcadeProfileID = ArcadeProfile.legacyID
  private var arcadeHotSeatID: String?
  private var arcadeRunID = UUID()
  private var arcadeReport: ArcadeReport?
  private var arcadeAutoPresent = true
  private let music = ModuleMusicPlayer()
  private let failureMood = FailureMoodTransition()
  /// Plays recordings the player supplied, as an alternative to the modules.
  private let soundtrack = SoundtrackPlayer()
  /// Mixes across the supplied soundtracks, moving on what the game does.
  private let dj = AdaptiveDJPlayer()
  /// Soundtracks found next to the modules, keyed by folder name.
  private var soundtrackLibrary: [String: [URL]] = [:]
  /// The artwork this level is drawn with. It differs from the chosen setting
  /// only while shuffle is on.
  private var levelGraphics: ClassicGraphicsSource?
  /// The soundtrack this level plays, on the same basis.
  private var levelMusic: ClassicMusicSource?
  private let effects = SoundEffectPlayer()

  /// Which fan level screen is showing, if any.
  ///
  /// Browsing sits on top of the title screen rather than inside the game
  /// flow. The flow tracks progress through the finished releases and is
  /// saved; wandering through hundreds of fan packs is not progress and does
  /// not belong in it.
  private enum FanScreen { case off, packs, levels }
  private var fanScreen: FanScreen = .off
  private var fanPacks: [URL] = []
  private var fanUpdateStatus = "CHECKING FOR NEW PACKS"
  private var fanUpdateTask: Task<Void, Never>?
  private var fanEntries: [FanLevelLibrary.Entry] = []
  private var fanPack: URL?
  private var fanChoice = 0
  /// First row of the visible window, so a click maps back to the right item.
  private var fanWindowStart = 0
  /// Rows on screen at once. The menu font shrinks to fit whatever it is
  /// given, and hundreds of rows would shrink it to nothing.
  private static let fanRowsPerScreen = 12
  /// True while a fan level is on screen, which keeps the campaign flow from
  /// redrawing over it. A fan level has no flow: it is not part of any run.
  private var fanPlaying = false
  /// Levels still to play, when a whole pack was started at once.
  private var fanQueue: [FanLevelLibrary.Entry] = []
  private var fanQueueIndex = 0
  private enum LevelBrowserRoute {
    case classic(
      dataSetDirectory: URL,
      dataSet: ClassicDataSet,
      levelIndex: Int,
      sourceFingerprint: String?,
      sourceRevision: String)
    case fan(pack: URL, entry: FanLevelLibrary.Entry, archiveFingerprint: String)
    case lemmings2(
      root: URL,
      selection: Lemmings2PlayWindow.LevelSelection,
      expectedLevelID: String,
      sourceRevision: String)
    case lemmings3(
      root: URL,
      selection: Lemmings3PlayWindow.LevelSelection,
      expectedLevelID: String,
      sourceRevision: String)
  }
  private struct LevelBrowserClassicSource: Sendable {
    let dataSet: ClassicDataSet
    let directory: URL
    let sourceFingerprint: String?
    let sourceRevision: String?
    let isVerified: Bool
  }
  private struct LevelBrowserDiscovery: Sendable {
    let classic: [LevelBrowserClassicSource]
    let lemmings2Root: URL?
    let lemmings2: [Lemmings2PlayWindow.BrowserLevel]
    let lemmings3Root: URL?
    let lemmings3: [Lemmings3PlayWindow.BrowserLevel]
  }
  private struct LevelBrowserFanDiscovery: Sendable {
    let fingerprint: String
    let entries: [FanLevelLibrary.Entry]
  }
  private struct LevelBrowserFanPackDiscovery: Sendable {
    let packID: String
    let fingerprint: String
    let entries: [FanLevelLibrary.Entry]
  }
  private struct PreparedClassicArtwork: Sendable {
    let grounds: [Int: ClassicGroundSet]
    let specials: [Int: ClassicSpecialGraphic]
    let assets: ClassicMainDATAssets
    let directory: URL
    let portArtworkFamily: String?
  }
  private enum LevelBrowserClassicPreparation: Sendable {
    case ready(PreparedClassicArtwork)
    case failed(String)
  }
  private struct PreparedFanLevel: Sendable {
    let level: ClassicLevel
    let ground: ClassicGroundSet
    let special: ClassicSpecialGraphic?
    let assets: ClassicMainDATAssets
  }
  private enum LevelBrowserFanPreparation: Sendable {
    case ready(PreparedFanLevel)
    case failed(String)
  }
  private enum PlaylistEntryResolution {
    case available(LevelCatalogueEntry)
    case locked(LevelCatalogueEntry)
    case unavailable(LevelCatalogueEntry)
    case changed
    case missing

    var canStart: Bool {
      if case .available = self { return true }
      return false
    }
  }
  private static let levelCatalogueRevision = "1.2-runtime-v2"
  private var levelCatalogue = LevelCatalogue(revision: "1.2-runtime-v2", packs: [])
  private var levelBrowserRoutes: [LevelCatalogueIdentity: LevelBrowserRoute] = [:]
  private var levelPreviewRequests: [LevelCatalogueIdentity: LevelPreviewRequest] = [:]
  private var levelBrowserPackFamilies: [String: HomeContentFamily] = [:]
  private var levelBrowserFanPacks: [String: URL] = [:]
  private var levelBrowserFanEntries: [String: [FanLevelLibrary.Entry]] = [:]
  private var levelBrowserInvalidFanPacks: Set<String> = []
  private var levelBrowserInvalidFanPackRevisions: [String: String] = [:]
  private var levelBrowserPackSelection: String?
  private var levelBrowserLevelSelections: [String: String] = [:]
  private var levelBrowserLoadTask: Task<Void, Never>?
  private var levelBrowserDiscoveryTask: Task<LevelBrowserDiscovery?, Never>?
  private var levelBrowserFanLoadTask: Task<Void, Never>?
  private var levelBrowserFanDiscoveryTask: Task<LevelBrowserFanDiscovery?, Never>?
  private var levelBrowserLaunchTask: Task<Void, Never>?
  private var levelBrowserLaunchID: UUID?
  private weak var levelBrowserLoadingPage: GameMenuPage?
  private weak var levelBrowserFanLoadingPage: GameMenuPage?
  private weak var levelBrowserLaunchPage: GameMenuPage?
  private weak var levelBrowserCurrentLevelPage: GameMenuPage?
  private weak var levelBrowserPackPage: GameMenuPage?
  private weak var levelBrowserPackCarousel: LevelCoverFlowView?
  private var levelBrowserVisiblePackKeys: Set<String> = []
  private var playlistFanLoadTask: Task<Void, Never>?
  private var playlistFanDiscoveryTask: Task<([LevelBrowserFanPackDiscovery], Set<String>), Never>?
  private weak var playlistFanLoadingPage: GameMenuPage?
  private weak var playlistLibraryPage: GameMenuPage?
  private weak var playlistEditorPage: GameMenuPage?
  private var playlistEditorID: UUID?
  private var playlistLibrarySelection: String?
  private var playlistStoreCache: (profileID: String, store: LevelPlaylistStore)?
  private var playlistEntrySelections: [UUID: UUID] = [:]
  private var sequencePlaylistStore: LevelPlaylistStore?
  private var sequenceLaunchRunID: UUID?
  private var sequencePlayingIdentity: LevelCatalogueIdentity?
  private var muteItem: NSMenuItem?
  private var presetItem: NSMenuItem?
  private var resumeSavedRunItem: NSMenuItem?
  private var gamesMenu: NSMenu?
  private var levelsMenu: NSMenu?
  /// Set while an unofficial level is loaded, so retry reloads that file.
  private var currentNxlvURL: URL?
  private var nativeL2Window: Lemmings2PlayWindow?
  private var nativeL3Window: Lemmings3PlayWindow?

  private let recoveryStore = RunRecoveryStore()
  private var lastCheckpointTime = 0.0
  private var restoringCheckpoint = false
  #if PERFORMANCE_TESTS
  private var replayCaptureSeconds = 0.0
  #endif
  private var checkpointFan: FanRunRecovery?
  private var fanPackGraphics = true
  private var fanTextSteel = true
  private var fanLocalStyles = true
  private var fanHolidayStyles = true
  private var checkpointSourceURL: URL?
  private var checkpointLocation: (dataSetID: String, levelIndex: Int)?

  private var recoveryEngine: String { RunRecovery.bundledEngine }

  private func saveRunCheckpoint(immediately: Bool = false) {
    guard !sequenceIsActive else { return }
    if let nativeL2Window { nativeL2Window.saveCheckpoint(immediately: immediately); return }
    if let nativeL3Window { nativeL3Window.saveCheckpoint(immediately: immediately); return }
    let atBriefing: Bool
    if case .briefing? = flow?.screen { atBriefing = true } else { atBriefing = false }
    guard !restoringCheckpoint, !sequelIsActive, (phase == .playing || atBriefing),
      let session, !session.isComplete, session.currentTick >= 0, !recoveryEngine.isEmpty,
      let fingerprint = arcadeLevel?.conditions?.levelFingerprint else { return }
    let now = ProcessInfo.processInfo.systemUptime
    guard immediately || now - lastCheckpointTime >= 5 else { return }
    var checkpoint: RunRecovery
    if let classic = session as? ClassicSession, let location = checkpointLocation {
      checkpoint = RunRecovery(engine: recoveryEngine, profileID: arcadeProfileID, runID: arcadeRunID,
        dataSetID: location.dataSetID, levelIndex: location.levelIndex,
        levelFingerprint: fingerprint, initialStateHash: classic.initialStateHash, tick: classic.currentTick,
        events: classic.recoveryEvents, stateHash: ClassicDOSReplayRecorder.stateHash(of: classic.simulation),
        usedRewind: classic.usedRewind, nukeCount: classic.nukeCount, rewindCount: classic.rewindCount,
        undoCount: classic.undoCount, selectedSkill: panel.selectedSkillIndex,
        scrollX: playfield.viewport.scrollX, scrollY: playfield.viewport.scrollY)
      checkpoint.classicState = classic.simulation
      checkpoint.fan = checkpointFan
      if checkpointFan != nil {
        checkpoint.fanPackGraphics = fanPackGraphics
        checkpoint.fanTextSteel = fanTextSteel
        checkpoint.fanLocalStyles = fanLocalStyles
        checkpoint.fanHolidayStyles = fanHolidayStyles
      }
      if checkpointFan != nil { checkpoint.sourcePath = checkpointSourceURL?.path }
    } else if let neo = session as? NeoLemmixSession, let url = checkpointSourceURL {
      checkpoint = RunRecovery(engine: recoveryEngine, profileID: arcadeProfileID, runID: arcadeRunID,
        dataSetID: "neolemmix", levelIndex: 0, levelFingerprint: fingerprint,
        initialStateHash: "verified-by-state-equality", tick: neo.currentTick, events: [], stateHash: "verified-by-state-equality",
        usedRewind: neo.usedRewind, nukeCount: neo.nukeCount, rewindCount: neo.rewindCount,
        undoCount: neo.undoCount, selectedSkill: panel.selectedSkillIndex,
        scrollX: playfield.viewport.scrollX, scrollY: playfield.viewport.scrollY)
      checkpoint.neo = neo.recovery; checkpoint.sourcePath = url.path
    } else { return }
    lastCheckpointTime = now
    checkpoint.hotSeatID = arcadeHotSeatID
    checkpoint.fullQuest = launchMode == .quest
    recoveryStore.save(checkpoint, immediately: immediately) { [weak self] message in
      self?.setStatus("Run recovery save failed: " + message)
    }
  }

  private var menuRecovery: RunRecovery?

  @objc private func resumeSavedRun() {
    guard allowNavigationAwayFromSequence() else { return }
    saveRunCheckpoint(immediately: true)
    do {
      guard let checkpoint = try recoveryStore.latest(profileID: ArcadeStore.shared.playingProfileID, hotSeatID: ArcadeStore.shared.hotSeatID) else {
        GameScreen.shared.message("No saved run", detail: "A checkpoint is saved every five seconds during Classic, fan-level, NeoLemmix, sequel campaign or L2 practice play.")
        return
      }
      if phase == .playing && session?.isComplete == false && !panel.isMenuMode {
        GameScreen.shared.confirm("Resume saved run?", detail: "Your current attempt stays saved. The restored run starts paused.",
          actionTitle: "Resume run", owner: window) { [weak self] in self?.restoreRun(checkpoint) }
      } else { restoreRun(checkpoint) }
    } catch RunRecoveryError.busy {
      GameScreen.shared.message("Cannot read saved run", detail: RunRecoveryError.busy.localizedDescription)
    } catch {
      // A run that can never load must not block Resume forever. Its bytes are moved aside, not deleted.
      GameScreen.shared.confirm("Cannot read saved run", detail: error.localizedDescription,
        actionTitle: "Discard saved run", owner: window) { [weak self] in
          guard let self else { return }
          do { try self.recoveryStore.setAsideUnreadable() }
          catch { GameScreen.shared.message("Cannot discard saved run", detail: error.localizedDescription) }
          self.renderScreen()
        }
    }
  }

  private func restoreRun(_ checkpoint: RunRecovery) {
    do {
      _ = try checkpoint.validated()
      // A newer engine must not strand a saved run. The session restores from
      // the saved inputs or state, and rejects only a state it cannot reproduce.
      guard checkpoint.profileID == ArcadeStore.shared.playingProfileID,
        checkpoint.hotSeatID == ArcadeStore.shared.hotSeatID else { throw RunRecoveryError.differentGame }
      if checkpoint.l2 != nil {
        guard let path = checkpoint.sourcePath else { throw RunRecoveryError.invalid }
        let next = try Lemmings2PlayWindow(root: URL(fileURLWithPath: path), recovery: checkpoint)
        saveRunCheckpoint(immediately: true)
        openNativeL2(recovered: next)
        return
      }
      if checkpoint.l3 != nil {
        guard let path = checkpoint.sourcePath else { throw RunRecoveryError.invalid }
        let next = try Lemmings3PlayWindow(root: URL(fileURLWithPath: path), recovery: checkpoint)
        saveRunCheckpoint(immediately: true)
        openNativeL3(recovered: next)
        return
      }
      let classicIndex = dataSetIndex(matching: checkpoint.dataSetID)
      if let fan = checkpoint.fan {
        if let base = fan.baseDataSetID, dataSetIndex(matching: base) == nil {
          throw RunRecoveryError.differentGame
        }
        guard let path = checkpoint.sourcePath, FileManager.default.fileExists(atPath: path) else {
          throw RunRecoveryError.differentGame
        }
        let entry = fan.queue[fan.index]
        _ = try FanLevelLibrary.level(.init(file: entry.file, section: entry.section, label: entry.label),
            in: URL(fileURLWithPath: path), includeTextSteel: checkpoint.fanTextSteel ?? false)
      } else if checkpoint.neo == nil {
        guard let index = classicIndex,
          dataSets[index].set.campaign.levels.indices.contains(checkpoint.levelIndex) else { throw RunRecoveryError.differentGame }
      } else {
        guard let path = checkpoint.sourcePath, FileManager.default.fileExists(atPath: path),
          stylesDirectory != nil else { throw RunRecoveryError.differentGame }
      }
      saveRunCheckpoint(immediately: true)
      restoringCheckpoint = true
      defer {
        restoringCheckpoint = false
        refreshClassicLevelPickerAvailability()
      }
      returnToLibrary()
      if let fan = checkpoint.fan, let path = checkpoint.sourcePath {
        if let base = fan.baseDataSetID, let index = dataSetIndex(matching: base) {
          gamePicker.selectItem(at: index); selectDataSet()
        }
        fanPack = URL(fileURLWithPath: path)
        let retained = try FanLevelLibrary.restoredQueue(
          fan.queue.map { .init(file: $0.file, section: $0.section, label: $0.label) },
          index: fan.index, in: fanPack!)
        fanQueue = retained.entries
        fanQueueIndex = retained.index
        fanEntries = FanLevelLibrary.entries(in: fanPack!)
        fanScreen = .off
        fanPackGraphics = checkpoint.fanPackGraphics ?? false
        fanTextSteel = checkpoint.fanTextSteel ?? false
        fanLocalStyles = checkpoint.fanLocalStyles ?? false
        fanHolidayStyles = checkpoint.fanHolidayStyles ?? false
        loadCurrentFanLevel()
        guard fanPlaying, phase == .briefing, let classic = session as? ClassicSession else { throw RunRecoveryError.differentGame }
        guard arcadeLevel?.conditions?.levelFingerprint == checkpoint.levelFingerprint
        else { throw RunRecoveryError.differentGame }
        _ = advanceFanPlay()
        try classic.restore(checkpoint)
      } else if checkpoint.neo != nil, let path = checkpoint.sourcePath {
        loadNxlv(URL(fileURLWithPath: path))
        guard let neo = session as? NeoLemmixSession else { throw RunRecoveryError.differentGame }
        try neo.restore(checkpoint)
      } else if let index = classicIndex {
        launchMode = .singleTitle; activeTitle = dataSets[index].set.title
        gamePicker.selectItem(at: index); selectDataSet()
        picker.selectItem(at: checkpoint.levelIndex); levelChanged()
        guard arcadeLevel?.conditions?.levelFingerprint == checkpoint.levelFingerprint
        else { throw RunRecoveryError.differentGame }
        if phase == .briefing { advancePhase() }
        guard let classic = session as? ClassicSession else { throw RunRecoveryError.differentGame }
        try classic.restore(checkpoint)
      }
      guard let restored = session else { throw RunRecoveryError.invalid }
      runMovie.discard()
      launchMode = checkpoint.fullQuest == true ? .quest : .singleTitle
      arcadeRunID = checkpoint.runID; arcadeProfileID = checkpoint.profileID; arcadeHotSeatID = checkpoint.hotSeatID
      panel.selectedSkillIndex = checkpoint.selectedSkill
      playfield.viewport.scrollX = max(0, min(checkpoint.scrollX, Double(restored.levelWidth)))
      playfield.viewport.scrollY = max(0, min(checkpoint.scrollY, Double(restored.levelHeight)))
      isPaused = true; panel.isPaused = true; accumulator = 0; lastStepTime = nil
      lastCheckpointTime = 0
      syncPanelViewport(); playfield.needsDisplay = true; panel.needsDisplay = true
      updateStatus()
      window.makeFirstResponder(playfield)
    } catch {
      isPaused = true; panel.isPaused = true
      if case RunRecoveryError.busy = error {
        GameScreen.shared.message("Cannot restore run", detail: error.localizedDescription)
        return
      }
      GameScreen.shared.confirm("Cannot restore run", detail: error.localizedDescription,
        actionTitle: "Discard saved run", owner: window) { [weak self] in
          guard let self else { return }
          do { try self.recoveryStore.setAside(checkpoint.runID) }
          catch { GameScreen.shared.message("Cannot discard saved run", detail: error.localizedDescription) }
          self.renderScreen()
        }
    }
  }

  func applicationWillTerminate(_ notification: Notification) { saveRunCheckpoint(immediately: true); ClassicRouteRecorder.flush() }

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Start scheduled update checks without waiting for the menu action.
    _ = updaterController
    migrateStandaloneSaves()
    buildMenu()
    buildInterface()
    installKeyboardShortcuts()
    NotificationCenter.default.addObserver(self, selector: #selector(resumeAudioOutput),
      name: .AVAudioEngineConfigurationChange, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(suspendAudioOutput),
      name: NSWorkspace.willSleepNotification, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wakeAudioOutput),
      name: NSWorkspace.didWakeNotification, object: nil)

    if let saved = UserDefaults.standard.string(forKey: contentPathKey) {
      contentDirectory = URL(fileURLWithPath: saved, isDirectory: true)
    }
    if let saved = UserDefaults.standard.string(forKey: stylesPathKey) {
      stylesDirectory = URL(fileURLWithPath: saved, isDirectory: true)
    }
    restoreSettings()
    if !UserDefaults.standard.bool(forKey: "PreferMacArtworkV1") {
      settings.graphics = .macintosh
      UserDefaults.standard.set(true, forKey: "PreferMacArtworkV1")
      if let data = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(data, forKey: settingsKey) }
    }
    if let data = UserDefaults.standard.data(forKey: ArcadeStore.shared.progressKey(progressKey)),
      let saved = try? ModernCampaignProgress(encoded: data) {
      progress = saved
    }
    if let data = UserDefaults.standard.data(forKey: ArcadeStore.shared.progressKey(achievementProgressKey)),
      let saved = try? JSONDecoder().decode(ClassicAchievementProgress.self, from: data) {
      achievements = saved
    }
    if let saved = UserDefaults.standard.string(forKey: musicPathKey) {
      music.loadLibrary(at: URL(fileURLWithPath: saved, isDirectory: true))
    } else if let bundled = BundledGameResources.music("lemmings_music_mod") {
      music.loadLibrary(at: bundled)
    }
    loadSoundtracks()
    applyAudioSettings()
    do {
      try effects.start()
      loadSoundEffects(for: settings.sound)
    } catch {
      setStatus("Sound unavailable: \(error.localizedDescription)")
    }
    updateMusicButtons()

    FanLevelLibrary.Progress.seedBundledCounts()
    loadContent()
    startFanUpdates()
    startTimer()
    // Enter full screen while the window is still unordered, so the player never
    // sees the windowed state. launchingFullScreen makes this one transition
    // instant; a later toggle by the player keeps the normal animation.
    if !window.styleMask.contains(.fullScreen) {
      launchingFullScreen = true
      window.toggleFullScreen(nil)
    }
    if let index = CommandLine.arguments.firstIndex(of: "--native-l2") {
      let path = index + 1 < CommandLine.arguments.count ? CommandLine.arguments[index + 1] : nil
      openNativeL2(path.flatMap { $0.hasPrefix("--") ? nil : URL(fileURLWithPath: $0) })
    }
    if let index = CommandLine.arguments.firstIndex(of: "--native-l3") {
      let path = index + 1 < CommandLine.arguments.count ? CommandLine.arguments[index + 1] : nil
      openNativeL3(path.flatMap { $0.hasPrefix("--") ? nil : URL(fileURLWithPath: $0) })
    }
    effectsWelcome.showIfNeeded(in: window) { [weak self] enabled in
      self?.setExperiencePreset(enabled)
    }
  }

  private func setExperiencePreset(_ enabled: Bool) {
    var updated = settings
    updated.applyExperiencePreset(modern: enabled)
    SequelArtworkPreference.setEnabled(enabled)
    apply(updated)
  }

  private func migrateStandaloneSaves() {
    LegacySaveMigration.migrate(bundleIdentifier: Bundle.main.bundleIdentifier)
  }

  // MARK: - Interface

  private func buildMenu() {
    let mainMenu = NSMenu()
    let appItem = NSMenuItem()
    mainMenu.addItem(appItem)

    let appMenu = NSMenu()
    let aboutItem = NSMenuItem(title: "About Ultimate Lemmings",
      action: #selector(showAbout), keyEquivalent: "")
    aboutItem.target = self
    appMenu.addItem(aboutItem)
    appMenu.addItem(.separator())
    let updatesItem = NSMenuItem(
      title: "Check for Updates…",
      action: #selector(checkForUpdates),
      keyEquivalent: "")
    updatesItem.target = self
    appMenu.addItem(updatesItem)
    appMenu.addItem(.separator())
    let achievementsItem = NSMenuItem(
      title: "Achievements…", action: #selector(showAchievements), keyEquivalent: "a")
    achievementsItem.keyEquivalentModifierMask = [.command, .shift]
    achievementsItem.target = self
    appMenu.addItem(achievementsItem)
    let profiles = NSMenuItem(title: "Player Profiles…", action: #selector(showProfiles), keyEquivalent: "p")
    profiles.keyEquivalentModifierMask = [.command, .shift]; profiles.target = self; appMenu.addItem(profiles)
    let hotSeat = NSMenuItem(title: "Hot Seat…", action: #selector(showHotSeat), keyEquivalent: "")
    hotSeat.target = self; appMenu.addItem(hotSeat)
    let records = NSMenuItem(title: "Level Records…", action: #selector(showLevelRecords), keyEquivalent: "b")
    records.keyEquivalentModifierMask = [.command, .shift]; records.target = self; appMenu.addItem(records)
    let replay = NSMenuItem(title: "Replay Last Game", action: #selector(reviewLastGame), keyEquivalent: "v")
    replay.keyEquivalentModifierMask = [.command, .shift]; replay.target = self
    appMenu.addItem(replay)
    let openReplay = NSMenuItem(title: "Open Replay Movie…", action: #selector(openReplayMovie), keyEquivalent: "o")
    openReplay.keyEquivalentModifierMask = [.command, .shift]; openReplay.target = self
    appMenu.addItem(openReplay)
    let nativeL2 = NSMenuItem(title: "Play Lemmings 2…", action: #selector(chooseNativeL2), keyEquivalent: "2")
    nativeL2.keyEquivalentModifierMask = [.command, .shift]
    nativeL2.target = self
    appMenu.addItem(nativeL2)
    let recordedRoutes = NSMenuItem(title: "Show Recorded Routes", action: #selector(showRecordedRoutes), keyEquivalent: "")
    recordedRoutes.target = self
    appMenu.addItem(recordedRoutes)
    let nativeL3 = NSMenuItem(title: "Play Lemmings 3 Native Preview…", action: #selector(chooseNativeL3), keyEquivalent: "3")
    nativeL3.keyEquivalentModifierMask = [.command, .shift]
    nativeL3.target = self
    appMenu.addItem(nativeL3)
    appMenu.addItem(.separator())
    let settingsItem = NSMenuItem(
      title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
    settingsItem.target = self
    appMenu.addItem(settingsItem)
    appMenu.addItem(.separator())
    appMenu.addItem(
      withTitle: "Quit Ultimate Lemmings",
      action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    appItem.submenu = appMenu

    func addMenu(_ title: String) -> NSMenu {
      let item = NSMenuItem()
      let menu = NSMenu(title: title)
      item.submenu = menu
      mainMenu.addItem(item)
      return menu
    }
    func add(
      _ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "",
      modifiers: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
      let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
      item.keyEquivalentModifierMask = modifiers
      item.target = self
      menu.addItem(item)
      return item
    }

    let fileMenu = addMenu("File")
    resumeSavedRunItem = add(
      fileMenu,
      "Resume Saved Run…",
      #selector(resumeSavedRun),
      "r",
      modifiers: [.command, .shift])
    _ = add(fileMenu, "Game Library", #selector(returnToLibrary), "l", modifiers: [.command, .shift])
    fileMenu.addItem(.separator())
    _ = add(fileMenu, "Add Game…", #selector(chooseContent), "o")
    _ = add(fileMenu, "Level Select…", #selector(showLevelBrowser), "")
    // Not Shift-Command-L: that already returns to the game library, and the
    // two chords are the same once AppKit has folded the shift in.
    _ = add(fileMenu, "Fan Levels…", #selector(showFanLevels), "f",
      modifiers: [.command, .shift])
    _ = add(fileMenu, "Add Fan Level Folder…", #selector(chooseFanFolder), "")
    _ = add(fileMenu, "Open Level File…", #selector(chooseNxlvLevel), "O",
            modifiers: [.command, .shift])
    fileMenu.addItem(.separator())
    let games = NSMenu(title: "Games")
    let gamesItem = NSMenuItem(title: "Game", action: nil, keyEquivalent: "")
    gamesItem.submenu = games
    fileMenu.addItem(gamesItem)
    gamesMenu = games
    let levels = NSMenu(title: "Levels")
    let levelsItem = NSMenuItem(title: "Level", action: nil, keyEquivalent: "")
    levelsItem.submenu = levels
    fileMenu.addItem(levelsItem)
    levelsMenu = levels
    fileMenu.autoenablesItems = false

    let viewMenu = addMenu("View")
    _ = add(viewMenu, "Zoom In", #selector(zoomIn), "+")
    _ = add(viewMenu, "Zoom Out", #selector(zoomOut), "-")

    let audioMenu = addMenu("Audio")
    _ = add(audioMenu, "Choose Music Folder…", #selector(chooseMusic))
    _ = add(audioMenu, "Choose Sound Effects…", #selector(chooseSounds))
    audioMenu.addItem(.separator())
    muteItem = add(audioMenu, "Mute", #selector(toggleMute), "m")
    presetItem = add(audioMenu, "Modern Sound", #selector(toggleMusicPreset))

    let helpMenu = addMenu("Help")
    _ = add(helpMenu, "Keyboard commands…", #selector(showKeyboardCommands), "?", modifiers: [.command])
    _ = add(helpMenu, "Level hints…", #selector(showLevelHints), "/")
    NSApplication.shared.helpMenu = helpMenu

    NSApplication.shared.mainMenu = mainMenu
  }

  @objc private func checkForUpdates(_ sender: Any?) {
    updaterController.checkForUpdates(sender)
  }

  // MARK: - Display path

  /// Puts the playfield and panel back into a container under Auto Layout.
  ///
  /// The tube takes these views out of the window and gives them fixed frames.
  /// Removing a view from its superview throws away every constraint that
  /// mentioned it, so coming back to the flat screen has to build them again.
  /// Without this the flat setting showed an empty window.
  private func layOutPlainViews(in root: NSView) {
    for view in [playfield, panel] as [NSView] {
      view.removeFromSuperview()
      view.translatesAutoresizingMaskIntoConstraints = false
      root.addSubview(view)
    }
    let panelHeight = panel.heightAnchor.constraint(equalToConstant: panel.intrinsicHeight)
    panelHeightConstraint = panelHeight
    NSLayoutConstraint.activate([
      playfield.leadingAnchor.constraint(equalTo: root.leadingAnchor),
      playfield.trailingAnchor.constraint(equalTo: root.trailingAnchor),
      playfield.topAnchor.constraint(equalTo: root.topAnchor),
      playfield.bottomAnchor.constraint(equalTo: panel.topAnchor),

      panel.leadingAnchor.constraint(equalTo: root.leadingAnchor),
      panel.trailingAnchor.constraint(equalTo: root.trailingAnchor),
      panel.bottomAnchor.constraint(equalTo: root.bottomAnchor),
      panelHeight,
    ])
  }

  /// Chooses between drawing straight to the window and drawing through the
  /// tube.
  ///
  /// The tube needs the game drawn at its own size first. Feeding it an
  /// already enlarged picture produces one scan line per screen row instead of
  /// one per game row, which is both wrong and invisible.
  private func applyDisplayMode() {
    defer { GameScreen.shared.reattach() }
    guard !sequelIsActive else { return }
    // The tube stands in for the screen the game was played on, so it applies
    // to the game. Menus stay flat.
    //
    // A menu is drawn with text laid out for a large view, and the tube is fed
    // a fixed 640 by 400 picture, so routing menus through it renders that text a
    // few pixels tall and then magnifies it. The result is unreadable however
    // gentle the tube settings are: it is a resolution problem, not a
    // brightness one.
    let wantsTube = settings.display != .flat && crtView.isAvailable
      && phase == .playing && playfield.phase == .playing && !panel.isMenuMode
    crtView.gameplayCursorRect = wantsTube
      ? CGRect(x: 0, y: 0, width: 640, height: 320)
      : nil
    guard wantsTube != tubeIsActive else {
      if wantsTube { crtView.settings = tubeSettings() }
      return
    }
    tubeIsActive = wantsTube
    playfield.presentsHDR = !wantsTube
    panel.handlePointerUp()
    playfield.clearPointer()

    if wantsTube {
      crtView.settings = tubeSettings()
      // The game views leave the window and draw at their own size.
      playfield.removeFromSuperview()
      panel.removeFromSuperview()
      playfield.translatesAutoresizingMaskIntoConstraints = true
      panel.translatesAutoresizingMaskIntoConstraints = true
      // A menu hides the panel, and the picture should use those rows rather
      // than leaving a black band where the panel would be.
      panel.isCRTSource = true
      panel.frame = CGRect(x: 0, y: 0, width: 640, height: 80)
      playfield.frame = CGRect(
        x: 0, y: 0, width: 640, height: 320)
      playfield.viewport.zoom = 2
      crtView.accessibleContent = { [weak self] in
        guard let self else { return [] }
        @MainActor func convert(_ rect: CGRect, panel: Bool = false) -> CGRect {
          let shift: CGFloat = panel ? 320 : 0
          let points = [CGPoint(x: rect.minX, y: rect.minY + shift), CGPoint(x: rect.maxX, y: rect.maxY + shift)]
            .compactMap { self.crtView.viewPoint(fromSource: $0) }
          guard points.count == 2 else { return .zero }
          return CGRect(x: min(points[0].x, points[1].x), y: min(points[0].y, points[1].y),
            width: abs(points[1].x - points[0].x), height: abs(points[1].y - points[0].y))
        }
        return self.playfield.accessibleControls(owner: self.crtView, transform: { convert($0) })
          + self.panel.accessibleControls(owner: self.crtView, transform: { convert($0, panel: true) })
      }
      crtView.onMouseDown = { [weak self] point, time, count in
        self?.tubeClick(point, time: time, clickCount: count)
      }
      crtView.onMouseUp = { [weak self] in self?.panel.handlePointerUp() }
      crtView.onMouseDragged = { [weak self] point in
        guard let self, point.y >= 320 else { return }
        self.panel.handlePointerDrag(at: CGPoint(x: point.x, y: point.y - 320))
      }
      crtView.onMouseExited = { [weak self] in self?.playfield.clearPointer() }
      crtView.onMouseMoved = { [weak self] point in self?.tubeMove(point) }
      crtView.onScroll = { [weak self] dx, _ in
        guard let self else { return }
        self.playfield.viewport.scroll(dx: -Double(dx), dy: 0)
        self.syncPanelViewport()
      }
      window.contentView = crtView
      window.makeFirstResponder(crtView)
    } else {
      guard let root = plainRoot else { return }
      panel.isCRTSource = false
      layOutPlainViews(in: root)
      window.contentView = root
      window.makeFirstResponder(playfield)
      fitClassicDisplay()
    }
  }

  /// Turns the chosen settings into tube settings.
  private func tubeSettings() -> CRTSettings {
    var tube = settings.display == .television
      ? CRTSettings.television : CRTSettings.amiga1084
    let strength = Float(min(1, max(0, settings.displayIntensity)))
    tube.scanlineDepth *= strength
    tube.maskStrength *= strength
    tube.bloomAmount *= strength
    tube.curvature = tube.curvature / max(0.15, strength)
    tube.curvatureY = tube.curvatureY / max(0.15, strength)
    tube.cornerRadius *= strength
    tube.cornerSoftness *= strength
    tube.convergence *= strength
    tube.convergenceY *= strength
    tube.vignette *= strength
    tube.saturation = 1 + (tube.saturation - 1) * strength
    tube.brightBoostDark = 1 + (tube.brightBoostDark - 1) * strength
    tube.brightBoostBright = 1 + (tube.brightBoostBright - 1) * strength
    tube.pixelAspect = Float(settings.pixelAspect)
    tube.colorLevels = Float(settings.colorDepth.levels)
    return tube
  }

  /// Draws the game at its own size for the tube to enlarge.
  private func composeNativeFrame() -> CGImage? {
    guard let playfieldRep = playfield.bitmapImageRepForCachingDisplay(in: playfield.bounds),
      let panelRep = panel.bitmapImageRepForCachingDisplay(in: panel.bounds)
    else { return nil }
    playfield.cacheDisplay(in: playfield.bounds, to: playfieldRep)
    panel.cacheDisplay(in: panel.bounds, to: panelRep)

    guard let context = CGContext(data: nil, width: 640, height: 400,
      bitsPerComponent: 8, bytesPerRow: 640 * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
      let fieldImage = playfieldRep.cgImage, let barImage = panelRep.cgImage else { return nil }
    context.interpolationQuality = .none
    if panel.isMenuMode {
      // No panel on a menu, so the picture fills the screen.
      context.draw(fieldImage, in: CGRect(x: 0, y: 0, width: 640, height: 400))
    } else {
      context.draw(barImage, in: CGRect(x: 0, y: 0, width: 640, height: 80))
      context.draw(fieldImage, in: CGRect(x: 0, y: 80, width: 640, height: 320))
    }
    return context.makeImage()
  }

  /// Sends a click through the tube to whichever part it landed on.
  private func tubeClick(_ point: CGPoint, time: TimeInterval = ProcessInfo.processInfo.systemUptime, clickCount: Int = 1) {
    if point.y >= 320 {
      panel.handlePointerDown(at: CGPoint(x: point.x, y: point.y - 320), time: time, clickCount: clickCount)
    } else {
      panel.resetNukeGesture()
      playfield.handleClick(at: point)
    }
  }

  private func tubeMove(_ point: CGPoint) {
    guard point.y < 320 else { playfield.clearPointer(); return }
    playfield.handleMove(to: point)
  }

  // MARK: - Settings

  /// What the installed data actually supports.
  private func settingsOptions() -> ClassicSettingsOptions {
    let macImage = UserDefaults.standard.string(forKey: macImageKey)
    let hasMac = (macImage.map { FileManager.default.fileExists(atPath: $0) } ?? false)
      || Bundle.main.resourceURL.map { FileManager.default.fileExists(atPath: $0.appendingPathComponent("MacArtwork/lemmings/manifest.json").path) } == true
    return ClassicSettingsOptions.available(
      hasDOSData: !dataSets.isEmpty,
      hasAmigaDisk: Bundle.main.resourceURL.map { FileManager.default.fileExists(atPath: $0.appendingPathComponent("AmigaArtwork/lemmings/manifest.json").path) } == true,
      hasMacintoshDisk: hasMac,
      moduleCount: music.library.count,
      remixFolders: soundtrackLibrary.keys.sorted(),
      hasSoundtracks: dj.hasTracks)
  }

  @objc private func showSettings() {
    let options = settingsOptions()
    if settingsWindow == nil {
      let created = SettingsWindow(settings: settings, options: options)
      created.videoIsConnected = crtView.isAvailable
      created.onChange = { [weak self] updated in self?.apply(updated) }
      settingsWindow = created
    } else {
      settingsWindow?.update(options: options, settings: settings)
    }
    settingsWindow?.show()
  }

  /// Puts a settings change into effect and remembers it.
  ///
  /// Only the parts the engine can honour today are acted on. A control that
  /// changed nothing would be worse than one that is absent.
  private func apply(_ updated: ClassicSettings) {
    let artworkChanged = settings.graphics != updated.graphics
    let musicChanged = settings.music != updated.music || settings.shuffleMusic != updated.shuffleMusic
    let djPoolChanged = settings.djIncludesOtherSoundtracks != updated.djIncludesOtherSoundtracks
    let classicUnlockChanged = settings.unlockAllClassicLevels != updated.unlockAllClassicLevels
    let reduceMotionChanged = settings.reduceMotion != updated.reduceMotion
    let previousSound = settings.sound
    settings = updated
    GameAccessibility.interfaceSize = settings.interfaceSize
    GameScreen.shared.reattach()
    if let data = try? JSONEncoder().encode(updated) {
      UserDefaults.standard.set(data, forKey: settingsKey)
    }

    if djPoolChanged { reloadDJLibrary() }
    if classicUnlockChanged {
      refreshClassicCatalogueAvailability()
      refreshClassicLevelPickerAvailability()
      rebuildNavigationMenus()
      let availabilityPages = [levelBrowserCurrentLevelPage, playlistLibraryPage].compactMap { $0 }
      levelBrowserCurrentLevelPage = nil
      playlistLibraryPage = nil
      for page in availabilityPages where GameScreen.shared.contains(page) {
        GameScreen.shared.dismiss(page)
      }
    }
    if reduceMotionChanged { updateLevelSelectionReducedMotion() }
    speedControl.variableEnabled = settings.modernControlsEnabled && settings.variableSpeedEnabled
    panel.modernControlsEnabled = settings.modernControlsEnabled
    playfield.reduceMotion = settings.reduceMotion
    playfield.reduceFlashes = settings.reduceFlashes
    playfield.hdEffectsEnabled = settings.hdEffectsEnabled
    playfield.favorApproachingLemmings = settings.favorApproachingLemmings
    if !settings.hdEffectsEnabled { screenFlash.clear() }
    else if !settings.cinematicExplosionsEnabled { screenFlash.clearExplosions() }
    applyAudioSettings()
    if updated.sound != previousSound { loadSoundEffects(for: updated.sound) }
    updateMusicButtons()

    if musicChanged, !sequelIsActive {
      levelMusic = nil
      playMusicForCurrentLevel()
    }

    applyDisplayMode()
    if artworkChanged, !sequelIsActive, let level = artworkLevel,
      let rendered = playfield.classicScene {
      configureArtwork(level, rendered: rendered)
      panel.needsDisplay = true
      playfield.needsDisplay = true
    }

    // Colour depth changes the palette, so the level has to be rebuilt.
    if !sequelIsActive, updated.colorDepth != previousDepth {
      previousDepth = updated.colorDepth
      if let flow, let level = flow.currentLevelIndex { loadLevel(at: level) }
      playfield.needsDisplay = true
    }
  }

  private func restoreSettings() {
    audioMuted = UserDefaults.standard.bool(forKey: "AudioMuted")
    if let data = UserDefaults.standard.data(forKey: settingsKey),
      let stored = try? JSONDecoder().decode(ClassicSettings.self, from: data) {
      settings = stored
    } else if UserDefaults.standard.bool(forKey: musicPresetKey) {
      settings.musicStyle = .modern
    }
    GameAccessibility.interfaceSize = settings.interfaceSize
    previousDepth = settings.colorDepth
    speedControl.variableEnabled = settings.modernControlsEnabled && settings.variableSpeedEnabled
    panel.modernControlsEnabled = settings.modernControlsEnabled
    playfield.reduceMotion = settings.reduceMotion
    playfield.reduceFlashes = settings.reduceFlashes
    playfield.hdEffectsEnabled = settings.hdEffectsEnabled
    playfield.favorApproachingLemmings = settings.favorApproachingLemmings
  }

  private func applyAudioSettings() {
    if music.usesModernPreset != (settings.musicStyle == .modern) {
      music.setEnhancements(settings.musicStyle == .modern ? .modern : .faithful)
    }
    music.setVolume(settings.musicVolume)
    soundtrack.setVolume(settings.musicVolume)
    dj.setVolume(settings.musicVolume)
    effects.setVolume(settings.soundVolume)
    effects.setBottomFallSounds(settings.bottomFallSounds)
    music.setMuted(audioMuted || settings.music == .silent)
    soundtrack.setMuted(audioMuted || settings.music == .silent)
    dj.setMuted(audioMuted || settings.music == .silent)
    effects.setMuted(audioMuted || settings.sound == .silent)
    nativeL2Window?.setAudioSettings(settings, muted: audioMuted)
    nativeL3Window?.setAudioSettings(settings, muted: audioMuted)
  }

  @objc private func showAbout() {
    let info = Bundle.main.infoDictionary ?? [:]
    let version = info["CFBundleShortVersionString"] as? String ?? "Unknown"
    let build = info["CFBundleVersion"] as? String ?? "Unknown"
    GameScreen.shared.message("Ultimate Lemmings", detail: "Version \(version) · Beta \(build)\nA rescue worth another try.")
  }

  @objc private func showAchievements() {
    achievementsWindow.show(progress: achievements)
  }

  /// Opens the preserved Classic and Lemmings 2 input routes.
  @objc private func showRecordedRoutes() {
    let folders = [ClassicRouteRecorder.folder, Lemmings2RouteRecorder.folder]
    for folder in folders { try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
    NSWorkspace.shared.activateFileViewerSelecting(folders)
  }

  @objc private func chooseNativeL2() {
    guard allowNavigationAwayFromSequence() else { return }
    launchMode = .singleTitle
    openNativeL2()
  }

  private func suspendCurrentEngine(savesProgress: Bool = true) {
    panel.handlePointerUp()
    playfield.clearPointer()
    if savesProgress { saveProgress() }
    runMovie.discard()
    nativeL2Window?.stop()
    nativeL3Window?.stop()
    nativeL2Window = nil
    nativeL3Window = nil
    music.stop()
    soundtrack.stop()
    dj.stop()
    effects.stop()
    accumulator = 0
  }

  @discardableResult
  private func openNativeL2(_ root: URL? = nil, recovered: Lemmings2PlayWindow? = nil,
                            selection: Lemmings2PlayWindow.LevelSelection? = nil,
                            expectedLevelID: String? = nil,
                            expectedSourceRevision: String? = nil,
                            sequenceRunID: UUID? = nil,
                            sequenceIdentity: LevelCatalogueIdentity? = nil) -> Bool {
    GameScreen.shared.dismissAll()
    do {
      let next = try recovered ?? Lemmings2PlayWindow(
        root: root ?? BundledGameResources.lemmings2(),
        selection: selection,
        expectedLevelID: expectedLevelID,
        expectedSourceRevision: expectedSourceRevision,
        recordsCampaignProgress: sequenceRunID == nil)
      if !sequelIsActive { classicContent = window.contentView }
      suspendCurrentEngine()
      nativeL2Window = next
      activeTitle = .lemmings2TheTribes
      next.onReturnToLibrary = { [weak self] in self?.returnToLibrary() }
      next.onProgressChanged = { [weak self] in self?.refreshSequelProgress() }
      next.onCampaignCompleted = { [weak self] in self?.finishNativeTitle() }
      next.onShowSettings = { [weak self] in self?.showSettings() }
      if let sequenceRunID, let sequenceIdentity {
        next.recordsCampaignProgress = false
        if let run = sequencePlaylistStore?.activeRun, run.id == sequenceRunID {
          next.sequenceContinueTitle = run.currentIndex + 1 < run.entries.count
            ? "Next level" : "Finish run"
        }
        next.onSequenceContinue = { [weak self] didWin in
          guard didWin else { return false }
          return self?.continueActiveSequence(
            completed: sequenceIdentity,
            runID: sequenceRunID) ?? true
        }
        setSequencePlayingIdentity(sequenceIdentity)
      }
      next.attach(to: window)
      next.setAudioSettings(settings, muted: audioMuted)
      window.title = "Lemmings 2 — The Tribes"
      window.resizeIncrements = NSSize(width: 1, height: 1)
      window.minSize = NSSize(width: 640, height: 502)
      next.present()
      rebuildNavigationMenus()
      return true
    } catch {
      showLaunchError("Cannot open Lemmings 2", error)
      return false
    }
  }

  @objc private func chooseNativeL3() {
    guard allowNavigationAwayFromSequence() else { return }
    launchMode = .singleTitle
    openNativeL3()
  }

  @discardableResult
  private func openNativeL3(_ root: URL? = nil, recovered: Lemmings3PlayWindow? = nil,
                            selection: Lemmings3PlayWindow.LevelSelection? = nil,
                            expectedLevelID: String? = nil,
                            expectedSourceRevision: String? = nil,
                            sequenceRunID: UUID? = nil,
                            sequenceIdentity: LevelCatalogueIdentity? = nil) -> Bool {
    GameScreen.shared.dismissAll()
    do {
      let next = try recovered ?? Lemmings3PlayWindow(
        root: root ?? BundledGameResources.lemmings3(),
        selection: selection,
        expectedLevelID: expectedLevelID,
        expectedSourceRevision: expectedSourceRevision,
        recordsCampaignProgress: sequenceRunID == nil)
      if !sequelIsActive { classicContent = window.contentView }
      suspendCurrentEngine()
      nativeL3Window = next
      activeTitle = .lemmings3TheChronicles
      next.onReturnToLibrary = { [weak self] in self?.returnToLibrary() }
      next.onProgressChanged = { [weak self] in self?.refreshSequelProgress() }
      next.onCampaignCompleted = { [weak self] in self?.finishNativeTitle() }
      next.onShowSettings = { [weak self] in self?.showSettings() }
      if let sequenceRunID, let sequenceIdentity {
        next.recordsCampaignProgress = false
        if let run = sequencePlaylistStore?.activeRun, run.id == sequenceRunID {
          next.sequenceContinueTitle = run.currentIndex + 1 < run.entries.count
            ? "Next level" : "Finish run"
        }
        next.onSequenceContinue = { [weak self] didWin in
          guard didWin else { return false }
          return self?.continueActiveSequence(
            completed: sequenceIdentity,
            runID: sequenceRunID) ?? true
        }
        setSequencePlayingIdentity(sequenceIdentity)
      }
      next.attach(to: window)
      next.setAudioSettings(settings, muted: audioMuted)
      window.title = "Lemmings 3 — The Chronicles"
      window.resizeIncrements = NSSize(width: 1, height: 1)
      window.minSize = NSSize(width: 1050, height: 680)
      next.present()
      rebuildNavigationMenus()
      return true
    } catch {
      showLaunchError("Cannot open Lemmings 3", error)
      return false
    }
  }

  private func showLaunchError(_ title: String, _ error: Error) {
    GameScreen.shared.message(title, detail: String(describing: error))
  }

  private func setSequencePlayingIdentity(_ identity: LevelCatalogueIdentity?) {
    sequencePlayingIdentity = identity
    refreshSequenceNavigationAvailability()
  }

  private func refreshSequenceNavigationAvailability() {
    let allowsLevelNavigation = !sequenceIsActive
    gamePicker.isEnabled = allowsLevelNavigation
    picker.isEnabled = allowsLevelNavigation
    resumeSavedRunItem?.isEnabled = allowsLevelNavigation
    refreshClassicLevelPickerAvailability()
    rebuildNavigationMenus()
  }

  private func clearSequenceLaunch(_ runID: UUID?) {
    guard let runID, sequenceLaunchRunID == runID else { return }
    sequenceLaunchRunID = nil
    refreshSequenceNavigationAvailability()
  }

  private var sequenceIsActive: Bool {
    sequenceLaunchRunID != nil || sequencePlayingIdentity != nil
  }

  private func allowNavigationAwayFromSequence() -> Bool {
    guard sequenceIsActive else {
      cancelLevelSelectionLoading()
      return true
    }
    if sequenceLaunchRunID != nil {
      setStatus("A playlist level is loading. Cancel it before choosing another game or level.")
      NSSound.beep()
      return false
    }
    GameScreen.shared.message(
      "Run in progress",
      detail: "Return to the game library before choosing another game, level, saved run or Hot Seat session.")
    return false
  }

  @objc private func returnToLibrary() {
    launchChoice = 0
    handoverRetry = nil
    let wasSequenceActive = sequenceIsActive
    if !wasSequenceActive { saveRunCheckpoint(immediately: true) }
    sequenceLaunchRunID = nil
    setSequencePlayingIdentity(nil)
    GameScreen.shared.dismissAll()
    fanScreen = .off
    fanPlaying = false
    fanQueue = []
    suspendCurrentEngine(savesProgress: !wasSequenceActive)
    activeTitle = nil
    currentNxlvURL = nil
    window.contentView = classicContent ?? plainRoot
    window.resizeIncrements = NSSize(width: 1, height: 1)
    window.minSize = NSSize(width: 900, height: 620)
    window.title = "Ultimate Lemmings"
    window.makeFirstResponder(playfield)
    applyAudioSettings()
    try? effects.start()
    refreshSequelProgress()
    flow?.acknowledgeGameComplete()
    rebuildLibrary()
    // Put the saved screen setting into force. Without this the tube only
    // engages when the setting is next touched, so a player who chose a
    // monitor last time comes back to a flat picture.
    applyDisplayMode()
    renderScreen()
    playMusicForCurrentLevel()
    window.makeKeyAndOrderFront(nil)
  }

  private func refreshSequelProgress() {
    if let root = try? BundledGameResources.lemmings2() {
      sequelCompletion[.lemmings2TheTribes] = Lemmings2PlayWindow.savedCompletion(root: root)
    }
    if let root = try? BundledGameResources.lemmings3() {
      sequelCompletion[.lemmings3TheChronicles] = Lemmings3PlayWindow.savedCompletion(root: root)
    }
    rebuildLibrary()
    measureFanPacks()
  }

  private func rebuildLibrary() {
    library = UnifiedGameLibrary(entries: ClassicTitle.allCases.map { title in
      if let index = nonFanQuestDataSetIndex(for: title) {
        let entry = dataSets[index]
        var savedFlow = ClassicGameFlow(campaign: entry.set.campaign)
        if let data = savedClassicProgressData(for: entry),
           let saved = try? JSONDecoder().decode(ClassicGameFlow.Progress.self, from: data) { savedFlow.restore(entry.set.migrateProgress(saved)) }
        let count = savedFlow.ranks.reduce(0) { $0 + savedFlow.passedCount(inRank: $1.name) }
        return .init(title: title, total: entry.set.campaign.levels.count, passed: count)
      }
      let available = title == .lemmings2TheTribes ? (try? BundledGameResources.lemmings2()) != nil
        : title == .lemmings3TheChronicles ? (try? BundledGameResources.lemmings3()) != nil : false
      // The menu is set in the game's own fixed-width font, so a row holds
      // only a short note. One word says as much as a sentence here.
      let detail = title == .lemmings2TheTribes ? "PREVIEW"
        : title == .lemmings3TheChronicles ? "PREVIEW" : "NO DATA"
      return .init(title: title, total: title.expectedLevelCount ?? 0,
        passed: sequelCompletion[title] ?? 0, available: available, detail: detail)
    })
    rebuildNavigationMenus()
  }

  private func launchTitle(_ title: ClassicTitle) {
    guard library.entries.contains(where: { $0.title == title && $0.available }) else { return }
    switch title {
    case .lemmings2TheTribes: openNativeL2()
    case .lemmings3TheChronicles: openNativeL3()
    default:
      if sequelIsActive { returnToLibrary() }
      do { try openChapter(title) }
      catch {
        setStatus("Cannot open \(title.displayName): \(error.localizedDescription)")
        return
      }
      activeTitle = title
      rebuildNavigationMenus()
      flow?.startGame()
      if launchMode == .quest { flow?.resumeCampaign() }
      renderScreen()
    }
  }

  private func finishNativeTitle() {
    guard let title = activeTitle else { return }
    refreshSequelProgress()
    let destination = library.next(after: title, mode: launchMode)
    returnToLibrary()
    if case let .title(next) = destination { launchTitle(next) }
  }

  private func refreshClassicLevelPickerAvailability() {
    guard let campaign, let flow else { return }
    for index in campaign.levels.indices {
      picker.item(at: index)?.isEnabled = settings.unlockAllClassicLevels
        || sequenceIsActive
        || flow.isLevelUnlocked(index)
    }
  }

  private func rebuildNavigationMenus() {
    gamesMenu?.removeAllItems()
    for entry in library.entries {
      let item = NSMenuItem(title: entry.title.displayName + (entry.available ? "" : " — Import needed"),
        action: #selector(selectGameFromMenu(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = entry.title.rawValue
      item.isEnabled = entry.available && !sequenceIsActive
      item.state = activeTitle == entry.title ? .on : .off
      gamesMenu?.addItem(item)
    }
    gamesMenu?.autoenablesItems = false
    levelsMenu?.removeAllItems()
    guard !sequelIsActive, let campaign else { return }
    for rank in campaign.ranks {
      let submenu = NSMenu(title: rank)
      for (index, entry) in campaign.levels.enumerated() where entry.rank == rank {
        let item = NSMenuItem(title: "\(entry.number). \(entry.level.title)",
          action: #selector(selectLevelFromMenu(_:)), keyEquivalent: "")
        item.target = self
        item.tag = index
        item.isEnabled = !sequenceIsActive
          && (settings.unlockAllClassicLevels || flow?.isLevelUnlocked(index) == true)
        submenu.addItem(item)
      }
      let item = NSMenuItem(title: rank, action: nil, keyEquivalent: "")
      item.submenu = submenu
      levelsMenu?.addItem(item)
    }
  }

  @objc private func selectGameFromMenu(_ sender: NSMenuItem) {
    guard allowNavigationAwayFromSequence() else { return }
    guard let value = sender.representedObject as? String, let title = ClassicTitle(rawValue: value) else { return }
    launchMode = .singleTitle
    saveProgress()
    launchTitle(title)
  }

  @objc private func selectLevelFromMenu(_ sender: NSMenuItem) {
    guard allowNavigationAwayFromSequence() else { return }
    guard !sequelIsActive else { return }
    guard settings.unlockAllClassicLevels || flow?.isLevelUnlocked(sender.tag) == true else {
      GameScreen.shared.message(
        "Level locked",
        detail: "Complete the preceding level, or enable Unlock all Classic levels in Settings.")
      return
    }
    launchMode = .singleTitle
    activeTitle = dataSets.indices.contains(gamePicker.indexOfSelectedItem) ? dataSets[gamePicker.indexOfSelectedItem].set.title : nil
    picker.selectItem(at: sender.tag)
    levelChanged()
  }

  private func buildInterface() {
    // The window holds the playfield and the status bar, nothing else.
    // Everything a player configures lives in the menu bar, so the game fills
    // the window the way it always did.
    let root = NSView()
    layOutPlainViews(in: root)

    picker.target = self
    picker.action = #selector(levelChanged)
    gamePicker.target = self
    gamePicker.action = #selector(selectDataSet)
    playfield.selectedSkill = { [weak self] in self?.panel.selectedSkillIndex ?? 0 }
    playfield.onAssign = { [weak self] id in self?.assign(id) }
    playfield.onViewportChanged = { [weak self] in self?.syncPanelViewport() }
    playfield.onAdvancePhase = { [weak self] in self?.advancePhase() }
    playfield.onHandoverRetry = { [weak self] in self?.retryPreviousHandoverLevel() }
    playfield.onReplay = { [weak self] save in self?.runMovie.review(save: save) }
    playfield.onRetry = { [weak self] in self?.retry() }
    playfield.onProfiles = { [weak self] in self?.showProfiles() }
    playfield.onRecords = { [weak self] in self?.showLevelRecords() }
    playfield.onSettings = { [weak self] in self?.showSettings() }
    playfield.onSelectOverlayLine = { [weak self] index in
      guard let self else { return }
      if self.fanScreen != .off {
        // The visible rows are a window onto a longer list.
        self.fanChoice = self.fanWindowStart + index
        self.advancePhase()
        return
      }
      if self.flow?.screen == .title { self.launchChoice = index }
      else if self.flow?.screen == .rankSelect { self.rankChoice = index }
      self.advancePhase()
    }
    panel.onButton = { [weak self] button in self?.handle(button) }
    panel.onMinimapScroll = { [weak self] centerX in
      guard let self else { return }
      self.playfield.viewport.center(on: centerX)
      self.playfield.needsDisplay = true
      self.syncPanelViewport()
    }

    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1000, height: 620),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered, defer: false)
    failureMood.onChange = { [weak self] amount in
      guard let self else { return }
      self.playfield.failureMoodAmount = amount
      let tempo = 1 - 0.28 * Double(amount)
      self.music.setTempoScale(tempo)
      self.soundtrack.setPlaybackRate(tempo)
      self.dj.setPlaybackRate(tempo)
      self.playfield.needsDisplay = true
    }
    window.isReleasedWhenClosed = false
    window.delegate = self
    GameScreen.shared.gameWindow = window
    GameScreen.shared.onPresent = { [weak self] in
      self?.cancelCoveredLevelSelectionLoading()
      self?.pointerCapture.reset()
      self?.panel.handlePointerUp(); self?.playfield.clearPointer()
      self?.nativeL2Window?.releasePointerForMenu()
    }
    window.title = "Ultimate Lemmings"
    plainRoot = root
    window.contentView = root
    // Size the window to its screen and mark it full-screen capable before it is
    // ever shown. Ordering a small window front here and animating afterwards is
    // what made the launch flash a window and reshuffle the displays.
    window.collectionBehavior.insert(.fullScreenPrimary)
    if let frame = (window.screen ?? NSScreen.main)?.frame {
      window.setFrame(frame, display: false)
    } else {
      window.center()
    }
    window.makeFirstResponder(playfield)
  }

  /// Skips the launch transition. AppKit animates into full screen over about a
  /// second, and on a multi-display Mac every screen redraws while it does. The
  /// player asked for the game, not for the animation.
  func customWindows(toEnterFullScreenFor window: NSWindow) -> [NSWindow]? {
    launchingFullScreen ? [window] : nil
  }

  func window(_ window: NSWindow, startCustomAnimationToEnterFullScreenWithDuration duration: TimeInterval) {
    window.setFrame(window.screen?.frame ?? window.frame, display: true)
  }

  func windowDidEnterFullScreen(_ notification: Notification) {
    launchingFullScreen = false
  }

  func windowDidFailToEnterFullScreen(_ window: NSWindow) {
    // Leave the window usable rather than hidden if the transition is refused.
    launchingFullScreen = false
    window.makeKeyAndOrderFront(nil)
  }

  func windowDidResize(_ notification: Notification) {
    fitClassicDisplay()
  }

  func windowDidResignKey(_ notification: Notification) {
    panel.handlePointerUp()
    playfield.clearPointer()
  }

  @objc private func suspendAudioOutput() {
    saveRunCheckpoint(immediately: true)
    audioIsSleeping = true
    music.suspendOutput()
    soundtrack.suspendOutput()
    dj.suspendOutput()
    effects.suspendOutput()
    nativeL2Window?.suspendAudioOutput()
    nativeL3Window?.suspendAudioOutput()
    lastStepTime = nil
  }

  @objc nonisolated private func resumeAudioOutput() {
    Task { @MainActor [weak self] in
      guard let self, !self.audioIsSleeping else { return }
      do {
        try self.music.resumeOutput()
        self.soundtrack.resumeOutput()
        self.dj.resumeOutput()
        try self.effects.resumeOutput()
        try self.nativeL2Window?.resumeAudioOutput()
        try self.nativeL3Window?.resumeAudioOutput()
      } catch { self.setStatus("Audio unavailable: \(error.localizedDescription)") }
    }
  }

  @objc private func wakeAudioOutput() {
    audioIsSleeping = false
    lastStepTime = nil
    resumeAudioOutput()
  }

  private func fitClassicDisplay() {
    guard !tubeIsActive, !sequelIsActive, let root = plainRoot,
      window.contentView === root else { return }
    let center = playfield.viewport.visibleLevelRect.midX
    let scale = max(1, floor(min(root.bounds.width / 320, (root.bounds.height - 20) / 200)))
    playfield.viewport.zoom = scale
    panelHeightConstraint?.constant = panel.isMenuMode ? 0 : 40 * scale + 22
    root.layoutSubtreeIfNeeded()
    playfield.viewport.viewSize = playfield.bounds.size
    playfield.viewport.center(on: center)
    syncPanelViewport()
    playfield.needsDisplay = true
  }

  // MARK: - Content

  @objc private func chooseContent() {
    guard allowNavigationAwayFromSequence() else { return }
    Task { @MainActor in
      guard let url = await pickDirectory("Choose the directory holding LEVEL000.DAT and MAIN.DAT.")
      else { return }
      if sequelIsActive { returnToLibrary() }
      var directories = gameDirectories
      if !directories.contains(where: { $0.path == url.path }) {
        directories.append(url)
        gameDirectories = directories
      }
      loadContent()
      // Show the game that was just added.
      if let index = dataSets.firstIndex(where: { $0.directory.path == url.path }) {
        gamePicker.selectItem(at: index)
        selectDataSet()
      }
    }
  }

  private func pickDirectory(_ message: String) async -> URL? {
    let openPanel = NSOpenPanel()
    openPanel.canChooseDirectories = true
    openPanel.canChooseFiles = false
    openPanel.allowsMultipleSelection = false
    openPanel.message = message
    return await GameScreen.shared.chooseFile(openPanel)
  }

  /// Directories the player has imported, newest last.
  private var gameDirectories: [URL] {
    get {
      (UserDefaults.standard.array(forKey: gamePathsKey) as? [String] ?? [])
        .map { URL(fileURLWithPath: $0, isDirectory: true) }
    }
    set {
      UserDefaults.standard.set(newValue.map(\.path), forKey: gamePathsKey)
    }
  }

  private func dataSetDirectoryKey(_ directory: URL) -> String {
    directory.resolvingSymlinksInPath().standardizedFileURL.path
  }

  /// Bundled releases retain their historic save keys. Imported sources add
  /// source and content identities so separate or replaced packs cannot share
  /// progress or recovery state.
  private func dataSetID(_ entry: (set: ClassicDataSet, directory: URL)) -> String {
    let directory = entry.directory.resolvingSymlinksInPath().standardizedFileURL
    if let resources = Bundle.main.resourceURL?
        .resolvingSymlinksInPath().standardizedFileURL,
       directory == resources || directory.path.hasPrefix(resources.path + "/") {
      return entry.set.identifierKey
    }
    if let cached = dataSetIdentityCache[directory.path] { return cached }
    let source = ArcadeStore.fingerprint(Data(directory.path.utf8))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let revision = (try? encoder.encode(entry.set.campaign))
      .map(ArcadeStore.fingerprint) ?? "unavailable"
    let identity = entry.set.identifierKey
      + ":source-" + source
      + ":revision-" + revision
    dataSetIdentityCache[directory.path] = identity
    return identity
  }

  private func dataSetIndex(matching identity: String) -> Int? {
    if let exact = dataSets.firstIndex(where: { dataSetID($0) == identity }) {
      return exact
    }
    let legacyMatches = dataSets.indices.filter {
      dataSets[$0].set.identifierKey == identity
        || dataSets[$0].set.legacyIdentifierKey == identity
    }
    return legacyMatches.count == 1 ? legacyMatches[0] : nil
  }

  private func dataSetClaimCount(for legacyIdentity: String) -> Int {
    dataSets.count {
      $0.set.identifierKey == legacyIdentity
        || $0.set.legacyIdentifierKey == legacyIdentity
    }
  }

  private func savedClassicProgressData(
    for entry: (set: ClassicDataSet, directory: URL)
  ) -> Data? {
    let store = UserDefaults.standard
    let scoped = ArcadeStore.shared.progressKey(
      "\(flowProgressKey).\(dataSetID(entry))")
    if let data = store.data(forKey: scoped) { return data }
    let identifierKey = ArcadeStore.shared.progressKey(
      "\(flowProgressKey).\(entry.set.identifierKey)")
    if dataSetClaimCount(for: entry.set.identifierKey) == 1,
       let data = store.data(forKey: identifierKey) {
      store.set(data, forKey: scoped)
      store.removeObject(forKey: identifierKey)
      return data
    }
    guard dataSetClaimCount(for: entry.set.legacyIdentifierKey) == 1 else { return nil }
    let legacyKey = ArcadeStore.shared.progressKey(
      "\(flowProgressKey).\(entry.set.legacyIdentifierKey)")
    guard let data = store.data(forKey: legacyKey) else { return nil }
    store.set(data, forKey: scoped)
    store.removeObject(forKey: legacyKey)
    return data
  }

  private func showLibraryWithoutClassicData(_ status: String) {
    dataSets = []
    dataSetIdentityCache = [:]
    campaign = nil
    session = nil
    gamePicker.removeAllItems()
    picker.removeAllItems()
    flow = ClassicGameFlow(ranks: [])
    rebuildLibrary()
    renderScreen()
    setStatus(status)
  }

  /**
   * Returns true for a repeated official release, but never for a scanned pack.
   */
  private static func shouldSkipDetectedDataSet(
    kind: ClassicDataSet.Kind,
    title: ClassicTitle?,
    identifierKey: String,
    loadedOfficialKeys: Set<String>
  ) -> Bool {
    kind != .scanned && title != nil
      && loadedOfficialKeys.contains(identifierKey)
  }

  /**
   * Finds the non-fan data set for one release in candidate order.
   */
  private static func nonFanQuestDataSetIndex(
    for requestedTitle: ClassicTitle,
    in candidates: [(title: ClassicTitle?, kind: ClassicDataSet.Kind)]
  ) -> Int? {
    candidates.firstIndex { candidate in
      candidate.title == requestedTitle
        && (candidate.kind != .scanned
          || requestedTitle == .ohYesMoreLemmings)
    }
  }

  /**
   * Finds the installed data set used by the all-level run.
   */
  private func nonFanQuestDataSetIndex(for title: ClassicTitle) -> Int? {
    Self.nonFanQuestDataSetIndex(
      for: title,
      in: dataSets.map { (title: $0.set.title, kind: $0.set.kind) })
  }

  private func loadContent() {
    // Accept the older single-directory preference so nothing is lost.
    var directories = gameDirectories
    if directories.isEmpty, let legacy = contentDirectory {
      directories = [legacy]
      gameDirectories = directories
    }
    let bundled = BundledGameResources.classicDirectories()
    directories = bundled + directories.filter { !bundled.contains($0) }
    guard !directories.isEmpty else {
      showLibraryWithoutClassicData(
        "Add a game folder, or open a .nxlv level.")
      return
    }

    // A folder is identified rather than assumed, so any title in this
    // format loads without a hand-written order table.
    dataSets = []
    dataSetIdentityCache = [:]
    var problems: [String] = []
    var loaded: [(offset: Int, set: ClassicDataSet, directory: URL)] = []
    var loadedOfficialKeys: Set<String> = []
    for (offset, directory) in directories.enumerated() {
      do {
        let set = try ClassicDataSet.detect(directory: directory)
        // Prefer the embedded copy when the same official release appears
        // twice. A scanned fan campaign can resemble an official release by
        // level count, so it must keep its own Fan Lemmings entry.
        if Self.shouldSkipDetectedDataSet(
          kind: set.kind,
          title: set.title,
          identifierKey: set.identifierKey,
          loadedOfficialKeys: loadedOfficialKeys
        ) { continue }
        loaded.append((offset, set, directory))
        if set.kind != .scanned, set.title != nil {
          loadedOfficialKeys.insert(set.identifierKey)
        }
      } catch {
        problems.append("\(directory.lastPathComponent): \(error)")
      }
    }

    // Imported folders may be added in any order. The game list is always the
    // authored canon; unknown/custom data follows it in import order.
    loaded.sort { lhs, rhs in
      let left = lhs.set.title?.canonOrder ?? Int.max
      let right = rhs.set.title?.canonOrder ?? Int.max
      return left == right ? lhs.offset < rhs.offset : left < right
    }
    dataSets = loaded.map { ($0.set, $0.directory) }

    // The port-exclusive pack is built from levels held in memory rather than
    // scanned from a folder, so it is appended after the scan instead of being
    // discovered by it. Each rank resolves artwork from its source release.
    if let root = Bundle.main.resourceURL?.appendingPathComponent("Ports", isDirectory: true) {
      let amigaRoot = root.appendingPathComponent("amiga_extracted", isDirectory: true)
      if let pack = try? PortExclusivePack.dataSet(amigaRoot: amigaRoot, portsRoot: root),
        pack.campaign.levels.count > 0 {
        dataSets.append((pack, root))
      }
    }

    gamePicker.removeAllItems()
    for entry in dataSets {
      gamePicker.addItem(
        withTitle: "\(entry.set.name) (\(entry.set.campaign.levels.count))")
    }
    guard !dataSets.isEmpty else {
      showLibraryWithoutClassicData(
        "No Lemmings data found. \(problems.first ?? "")")
      return
    }
    gamePicker.selectItem(at: 0)
    selectDataSet()
    returnToLibrary()
  }

  /// Points the app at the release a launch choice refers to.
  private func openChapter(_ title: ClassicTitle) throws {
    guard let index = nonFanQuestDataSetIndex(for: title) else {
      throw NSError(
        domain: "UnifiedGameLibrary",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "The selected release is not available."])
    }
    let previousIndex = gamePicker.indexOfSelectedItem
    gamePicker.selectItem(at: index)
    do { try applyDataSetSelection(at: index) }
    catch {
      if dataSets.indices.contains(previousIndex) {
        gamePicker.selectItem(at: previousIndex)
        configureFrontEndArtwork()
      }
      throw error
    }
  }

  /// The Macintosh artwork folder a release uses.
  private func macArtworkFamily(for title: ClassicTitle) -> String? {
    switch title {
    case .lemmings: return "lemmings"
    case .ohNoMoreLemmings: return "ohno"
    case .xmasLemmings1991, .xmasLemmings1992: return "xmas"
    case .holidayLemmings1993, .holidayLemmings1994: return "holiday"
    default: return nil
    }
  }

  /// Gives the menus the release's own lettering, logo and icons.
  ///
  /// This does not depend on the artwork chosen for levels. The Macintosh
  /// release is the only one whose character set is decoded, so its lettering
  /// is what every menu uses. Without it the menus fall back to a system font.
  private func configureFrontEndArtwork() {
    guard let resources = Bundle.main.resourceURL else { return }
    // The menus keep their lettering whatever is selected, which is the whole
    // point of holding this separately from the level artwork. Selecting a pack
    // with no Macintosh artwork of its own, or a release whose data is missing,
    // used to drop the menus back to a system font and lose the logo with them.
    let selected = dataSets.indices.contains(gamePicker.indexOfSelectedItem)
      ? dataSets[gamePicker.indexOfSelectedItem].set.title : nil
    let family = selected.flatMap(macArtworkFamily(for:)) ?? "lemmings"
    let key = "MacArtwork/" + family
    let art: ClassicMacArtwork
    if let cached = macArtworkCache[key] {
      art = cached
    } else {
      guard let loaded = try? ClassicMacArtwork(
        directory: resources.appendingPathComponent("MacArtwork").appendingPathComponent(family))
      else { return }
      macArtworkCache[key] = loaded
      art = loaded
    }
    playfield.interfaceArtwork = art
    panel.interfaceArtwork = art
  }

  @objc private func selectDataSet() {
    let index = max(0, min(gamePicker.indexOfSelectedItem, dataSets.count - 1))
    guard index < dataSets.count else { return }
    do { try applyDataSetSelection(at: index) }
    catch { setStatus("\(dataSets[index].set.name): \(error)") }
  }

  private func applyDataSetSelection(
    at index: Int,
    using replacement: (set: ClassicDataSet, directory: URL)? = nil,
    preparedArtwork: PreparedClassicArtwork? = nil
  ) throws {
    guard dataSets.indices.contains(index) else {
      throw NSError(domain: "LevelBrowser", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "The selected game data is no longer available."])
    }
    defer { configureFrontEndArtwork() }
    let entry = replacement ?? dataSets[index]
    if replacement != nil {
      dataSetIdentityCache.removeValue(
        forKey: dataSetDirectoryKey(entry.directory))
    }
    let prepared: PreparedClassicArtwork
    if let preparedArtwork {
      prepared = preparedArtwork
    } else if entry.set.title == .ohYesMoreLemmings,
              let first = entry.set.campaign.levels.first {
      prepared = try Self.readPortArtwork(
        first, dataSet: entry.set, portsRoot: entry.directory)
    } else {
      prepared = try Self.readClassicArtwork(
        directory: entry.directory,
        styles: entry.set.groundStyles,
        specialIndices: entry.set.specialIndices)
    }
    installClassicArtwork(prepared)
    currentNxlvURL = nil
    if replacement != nil {
      dataSets[index] = entry
      gamePicker.item(at: index)?.title =
        "\(entry.set.name) (\(entry.set.campaign.levels.count))"
    }
    if UserDefaults.standard.string(forKey: musicPathKey) == nil {
      let folder: String
      switch entry.set.title {
      case .ohNoMoreLemmings: folder = "oh_no_more_lemmings_music_mod"
      case .xmasLemmings1991, .xmasLemmings1992, .holidayLemmings1993, .holidayLemmings1994:
        folder = "holiday_lemmings_music_mod"
      default: folder = "lemmings_music_mod"
      }
      if let bundled = BundledGameResources.music(folder) { music.loadLibrary(at: bundled) }
    }

    campaign = entry.set.campaign
    classicSelectionRecordsCampaignProgress = true
    var built = ClassicGameFlow(campaign: entry.set.campaign)
    let savedData = savedClassicProgressData(for: entry)
    if let data = savedData,
      let saved = try? JSONDecoder().decode(ClassicGameFlow.Progress.self, from: data) {
      built.restore(entry.set.migrateProgress(saved))
    }
    flow = built
    saveProgress()
    rankChoice = 0
    picker.removeAllItems()
    for (offset, level) in entry.set.campaign.levels.enumerated() {
      picker.addItem(withTitle: "\(offset + 1). \(level.rank) — \(level.level.title)")
    }
    refreshClassicLevelPickerAvailability()
    picker.selectItem(at: 0)
    showTitle()
    rebuildLibrary()
  }

  // MARK: - Official levels

  /// Loads the level at a campaign index without changing the flow.
  private func loadLevel(at index: Int) {
    guard let campaign, index < campaign.levels.count else { return }
    picker.selectItem(at: index)
    chooseShuffledSources()
    buildLevel(campaign.levels[index])
  }

  /// Draws the artwork and soundtrack for a level when shuffle is on.
  ///
  /// The choice is made once per level rather than once per frame, so a level
  /// keeps one look and one tune from beginning to end. Sources the data does
  /// not provide never come up, because the list comes from what is installed.
  private func chooseShuffledSources() {
    let options = settingsOptions()
    levelGraphics = settings.shuffleGraphics ? options.graphics.randomElement() : nil
    if settings.shuffleMusic {
      // Silence is a valid setting but a poor thing to shuffle into.
      let playable = options.music.filter {
        if case let .remix(name) = $0 { return SoundtrackPlayer.isSeasonal(name) == seasonalMusic }
        return $0 != .silent
      }
      levelMusic = playable.randomElement()
    } else {
      levelMusic = nil
    }
  }

  /// The artwork in force, which is the shuffled choice when there is one.
  private var activeGraphics: ClassicGraphicsSource { levelGraphics ?? settings.graphics }
  private var musicTitle: ClassicTitle? {
    guard !fanPlaying, currentNxlvURL == nil,
      dataSets.indices.contains(gamePicker.indexOfSelectedItem) else { return nil }
    return dataSets[gamePicker.indexOfSelectedItem].set.title
  }
  private var seasonalMusic: Bool { SoundtrackPlayer.isSeasonal(musicTitle) }
  private var activeMusic: ClassicMusicSource {
    let source = levelMusic ?? settings.music
    if seasonalMusic, source != .silent, source != .adaptiveDJ { return .amigaModules }
    return source
  }

  @objc private func levelChanged() {
    guard var current = flow, let campaign,
      picker.indexOfSelectedItem < campaign.levels.count else { return }
    // Choosing from the list jumps there, keeping the run intact.
    let target = picker.indexOfSelectedItem
    let isUnlocked = current.isLevelUnlocked(target)
    let continuesAuthorisedAttempt: Bool
    switch current.screen {
    case .briefing, .playing, .results:
      continuesAuthorisedAttempt = !classicSelectionRecordsCampaignProgress
        && current.currentLevelIndex == target
    default:
      continuesAuthorisedAttempt = false
    }
    guard settings.unlockAllClassicLevels || sequenceIsActive
            || restoringCheckpoint || continuesAuthorisedAttempt || isUnlocked else {
      picker.selectItem(at: current.currentLevelIndex ?? 0)
      setStatus("Level locked. Complete the preceding level or change the Classic unlock setting.")
      NSSound.beep()
      return
    }
    let recordsCampaignProgress = sequencePlayingIdentity == nil && isUnlocked
    classicSelectionRecordsCampaignProgress = recordsCampaignProgress
    for (rankIndex, rank) in current.ranks.enumerated() {
      if let position = rank.levelIndices.firstIndex(of: target) {
        current.selectLevel(
          rank: rankIndex,
          position: position,
          recordsCampaignProgress: recordsCampaignProgress)
        flow = current
        renderScreen()
        return
      }
    }
  }

  private var artworkLevel: ClassicLevel?

  nonisolated private static func readClassicArtwork(
    directory: URL,
    styles: [Int],
    specialIndices: [Int],
    fallbackDirectory: URL? = nil,
    portArtworkFamily: String? = nil
  ) throws -> PreparedClassicArtwork {
    var newGrounds: [Int: ClassicGroundSet] = [:]
    var newSpecials: [Int: ClassicSpecialGraphic] = [:]
    for style in styles { newGrounds[style] = try ClassicGroundSet.load(style: style, from: directory, fallbackDirectory: fallbackDirectory) }
    for index in specialIndices { newSpecials[index + 1] = try ClassicSpecialGraphic.load(index: index, from: directory, fallbackDirectory: fallbackDirectory) }
    let newAssets = try ClassicMainDATAssets.load(from: fallbackDirectory ?? directory)
    return PreparedClassicArtwork(
      grounds: newGrounds,
      specials: newSpecials,
      assets: newAssets,
      directory: directory,
      portArtworkFamily: portArtworkFamily)
  }

  private func installClassicArtwork(_ prepared: PreparedClassicArtwork) {
    grounds = prepared.grounds
    specials = prepared.specials
    assets = prepared.assets
    loadedArtworkDirectory = prepared.directory
    portArtworkFamily = prepared.portArtworkFamily
    playfield.assets = prepared.assets
    playfield.invalidateSprites()
  }

  private func loadClassicArtwork(directory: URL, styles: [Int], specialIndices: [Int], fallbackDirectory: URL? = nil) throws {
    installClassicArtwork(try Self.readClassicArtwork(
      directory: directory,
      styles: styles,
      specialIndices: specialIndices,
      fallbackDirectory: fallbackDirectory))
  }

  nonisolated private static func readPortArtwork(
    _ entry: ClassicCampaignLevel,
    dataSet: ClassicDataSet,
    portsRoot: URL
  ) throws -> PreparedClassicArtwork {
    let directory = PortExclusivePack.artworkDirectory(for: entry, portsRoot: portsRoot)
    let levels = dataSet.campaign.levels.filter {
      PortExclusivePack.artworkDirectory(for: $0, portsRoot: portsRoot) == directory
    }
    return try readClassicArtwork(
      directory: directory,
      styles: Set(levels.map { $0.level.groundStyle }).sorted(),
      specialIndices: Set(levels.map { $0.level.specialStyle - 1 }).filter { $0 >= 0 }.sorted(),
      fallbackDirectory: PortExclusivePack.fallbackArtworkDirectory(for: entry, portsRoot: portsRoot),
      portArtworkFamily: entry.rank == "Oh No! More Lemmings Versus" ? "ohno" : "lemmings")
  }

  private func preparePortArtwork(_ entry: ClassicCampaignLevel, dataSet: ClassicDataSet, portsRoot: URL) throws {
    let directory = PortExclusivePack.artworkDirectory(for: entry, portsRoot: portsRoot)
    guard directory != loadedArtworkDirectory else { return }
    installClassicArtwork(try Self.readPortArtwork(
      entry, dataSet: dataSet, portsRoot: portsRoot))
  }

  /// Builds and starts a level.
  ///
  /// `groundOverride` is for levels that do not belong to the loaded game. A
  /// fan level names its own ground set, which is usually from a different
  /// release than the one currently open, so it arrives with the set already
  /// resolved rather than being looked up in this game's styles.
  @discardableResult
  private func buildLevel(
    _ entry: ClassicCampaignLevel, groundOverride: ClassicGroundSet? = nil,
    specialOverride: ClassicSpecialGraphic? = nil, assetsOverride: ClassicMainDATAssets? = nil
  ) -> Bool {
    currentNxlvURL = nil
    let level = entry.level
    do {
      if groundOverride == nil, dataSets.indices.contains(gamePicker.indexOfSelectedItem) {
        let dataSet = dataSets[gamePicker.indexOfSelectedItem]
        if dataSet.set.title == .ohYesMoreLemmings {
          try preparePortArtwork(entry, dataSet: dataSet.set, portsRoot: dataSet.directory)
        }
      }
      guard let ground = groundOverride ?? grounds[level.groundStyle] else {
        setStatus("Level error: missing graphics style \(level.groundStyle)")
        return false
      }
      let rendered = try ClassicLevelRenderer.render(
        level, groundSet: ground, specialGraphic: groundOverride == nil ? specials[level.specialStyle] : specialOverride)

      // The DOS engine derives entrances, exits and hazards from the level's
      // own trigger zones, so nothing is positioned by hand here. Fan levels
      // (with a ground override) keep the original rules.
      var title: ClassicTitle?
      if groundOverride == nil, dataSets.indices.contains(gamePicker.indexOfSelectedItem) {
        title = dataSets[gamePicker.indexOfSelectedItem].set.title
      }
      let mechanics = ClassicDOSMechanics(title: title, rank: entry.rank)
      let simulation: ClassicDOSSimulation
      if let assets = assetsOverride ?? assets {
        simulation = try ClassicDOSSimulation(
          level: level, renderedLevel: rendered, mainDATAssets: assets, mechanics: mechanics)
      } else {
        simulation = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mechanics: mechanics)
      }
      guard let image = makeImage(
        width: rendered.width, height: rendered.height, rgba: [UInt8](rendered.rgba))
      else {
        setStatus("Level error: could not create the level image")
        return false
      }
      playfield.assets = assetsOverride ?? assets
      playfield.invalidateSprites()
      playfield.classicScene = rendered
      playfield.levelImage = image
      configureArtwork(level, rendered: rendered)
      if var palette = try? ClassicLemmingPalette.inLevelVGA(
        terrainPalette: ground.terrainPalette) {
        // Reducing the palette rather than the pixels means terrain, sprites
        // and the status bar all shift together, as a palette change did.
        if settings.colorDepth == .amigaOCS { palette = palette.quantizedToAmigaOCS }
        playfield.palette = palette
        playfield.invalidateSprites()
        panel.panelImage = makePanelImage()
      }

      adopt(
        ClassicSession(
          simulation: simulation, width: rendered.width, height: rendered.height))
      // startX is the authored left edge of the original 320-pixel view.
      playfield.viewport.center(on: Double(level.startX) + 160)
      syncPanelViewport()
      return true
    } catch {
      setStatus("Level error: \(error)")
      return false
    }
  }

  private func configureArtwork(_ level: ClassicLevel, rendered: ClassicRenderedLevel) {
    playfield.macScene = nil
    playfield.macArtwork = nil
    playfield.imageScale = 1
    panel.macArtwork = nil
    artworkLevel = level
    guard [.macintosh, .amiga].contains(activeGraphics),
      dataSets.indices.contains(gamePicker.indexOfSelectedItem),
      let resources = Bundle.main.resourceURL else { return }
    let source = activeGraphics == .amiga ? "AmigaArtwork" : "MacArtwork"
    let root = resources.appendingPathComponent(source)
    let family: String
    switch dataSets[gamePicker.indexOfSelectedItem].set.title {
    case .lemmings: family = "lemmings"
    case .ohNoMoreLemmings: family = "ohno"
    case .xmasLemmings1991, .xmasLemmings1992: family = "xmas"
    case .holidayLemmings1993, .holidayLemmings1994: family = "holiday"
    case .ohYesMoreLemmings: guard let portArtworkFamily else { return }; family = portArtworkFamily
    default: return
    }
    do {
      let key = source + "/" + family
      let art: ClassicMacArtwork
      if let cached = macArtworkCache[key] { art = cached }
      else {
        art = try ClassicMacArtwork(directory: root.appendingPathComponent(family))
        macArtworkCache[key] = art
      }
      playfield.macArtwork = art
      panel.macArtwork = art
      playfield.macScene = try ClassicMacScene(level: level, rendered: rendered, artwork: art, groundSet: grounds[level.groundStyle])
    } catch {
      setStatus("\(settings.graphics.displayName) artwork unavailable for this level: \(error)")
    }
  }

  // MARK: - Level browser

  private func cancelCoveredLevelSelectionLoading() {
    guard let topPage = GameScreen.shared.controllerPage(in: window) else { return }
    let loadingPages = [
      levelBrowserLoadingPage,
      levelBrowserFanLoadingPage,
      levelBrowserLaunchPage,
      playlistFanLoadingPage,
    ].compactMap { $0 }
    guard loadingPages.contains(where: { $0 === topPage }) else { return }
    cancelLevelSelectionLoading()
  }

  private func cancelLevelSelectionLoading() {
    let pendingSequenceRunID = sequenceLaunchRunID
    let pages = [
      levelBrowserLoadingPage,
      levelBrowserFanLoadingPage,
      levelBrowserLaunchPage,
    ].compactMap { $0 }
    levelBrowserLoadTask?.cancel()
    levelBrowserDiscoveryTask?.cancel()
    levelBrowserFanLoadTask?.cancel()
    levelBrowserFanDiscoveryTask?.cancel()
    levelBrowserLaunchTask?.cancel()
    levelBrowserLoadTask = nil
    levelBrowserDiscoveryTask = nil
    levelBrowserFanLoadTask = nil
    levelBrowserFanDiscoveryTask = nil
    levelBrowserLaunchTask = nil
    levelBrowserLoadingPage = nil
    levelBrowserFanLoadingPage = nil
    levelBrowserLaunchPage = nil
    levelBrowserLaunchID = nil
    for page in pages where GameScreen.shared.contains(page) {
      GameScreen.shared.dismiss(page)
    }
    cancelPlaylistFanLoading()
    clearSequenceLaunch(pendingSequenceRunID)
  }

  @objc private func showLevelBrowser() {
    openLevelBrowser(family: nil)
  }

  private func openLevelBrowser(family: HomeContentFamily?) {
    guard allowNavigationAwayFromSequence() else { return }
    // Keep one pack browser root so live catalogue refreshes always update the
    // page the player can return to.
    if let page = levelBrowserPackPage, GameScreen.shared.contains(page) {
      GameScreen.shared.dismiss(page)
    }
    let browserTitle = family?.displayName ?? "Level Select"
    let loadingPage = GameMenuPage(title: browserTitle)
    levelBrowserLoadingPage = loadingPage
    loadingPage.setDetail("Loading the level catalogue.")
    loadingPage.backTitle = "Cancel"
    loadingPage.onBack = { [weak self, weak loadingPage] in
      guard let self, let loadingPage,
            self.levelBrowserLoadingPage === loadingPage else { return }
      self.levelBrowserLoadTask?.cancel()
      self.levelBrowserDiscoveryTask?.cancel()
      self.levelBrowserLoadTask = nil
      self.levelBrowserDiscoveryTask = nil
      self.levelBrowserLoadingPage = nil
      GameScreen.shared.dismiss(loadingPage)
    }
    GameScreen.shared.present(loadingPage, owner: window, onDismiss: { [weak self, weak loadingPage] in
      guard let self, let loadingPage,
            self.levelBrowserLoadingPage === loadingPage else { return }
      self.levelBrowserLoadTask?.cancel()
      self.levelBrowserDiscoveryTask?.cancel()
      self.levelBrowserLoadTask = nil
      self.levelBrowserDiscoveryTask = nil
      self.levelBrowserLoadingPage = nil
    })

    let bundledClassic = Set(BundledGameResources.classicDirectories().map {
      $0.resolvingSymlinksInPath().standardizedFileURL
    })
    let bundledPorts = Bundle.main.resourceURL?
      .appendingPathComponent("Ports", isDirectory: true)
      .resolvingSymlinksInPath().standardizedFileURL
    let classic = dataSets.map {
      let directory = $0.directory.resolvingSymlinksInPath().standardizedFileURL
      let verified = bundledClassic.contains(directory)
        || ($0.set.title == .ohYesMoreLemmings && directory == bundledPorts)
      return LevelBrowserClassicSource(dataSet: $0.set, directory: $0.directory,
        sourceFingerprint: nil, sourceRevision: nil, isVerified: verified)
    }
    let lemmings2Root = try? BundledGameResources.lemmings2()
    let lemmings2Progress = lemmings2Root.flatMap {
      Lemmings2PlayWindow.browserProgressData(root: $0)
    }
    let lemmings3Root = try? BundledGameResources.lemmings3()
    let lemmings3Progress = lemmings3Root.map {
      Lemmings3PlayWindow.browserProgressData(root: $0)
    } ?? [:]

    let discoveryTask = Task.detached(priority: .userInitiated) {
      () -> LevelBrowserDiscovery? in
        guard !Task.isCancelled else { return nil }
        let refreshedClassic = classic.compactMap { source -> LevelBrowserClassicSource? in
          guard !Task.isCancelled else { return nil }
          guard let before = FanLevelLibrary.directoryFingerprint(source.directory) else {
            return nil
          }
          if source.isVerified {
            return LevelBrowserClassicSource(
              dataSet: source.dataSet,
              directory: source.directory,
              sourceFingerprint: nil,
              sourceRevision: before,
              isVerified: true)
          }
          guard
                let dataSet = try? ClassicDataSet.detect(directory: source.directory),
                let fingerprint = FanLevelLibrary.directoryFingerprint(source.directory),
                fingerprint == before
          else { return nil }
          return LevelBrowserClassicSource(
            dataSet: dataSet,
            directory: source.directory,
            sourceFingerprint: fingerprint,
            sourceRevision: fingerprint,
            isVerified: false)
        }
        guard !Task.isCancelled else { return nil }
        let lemmings2 = lemmings2Root.flatMap {
          try? Lemmings2PlayWindow.browserLevels(
            root: $0, progressData: lemmings2Progress)
        } ?? []
        guard !Task.isCancelled else { return nil }
        let lemmings3 = lemmings3Root.flatMap {
          try? Lemmings3PlayWindow.browserLevels(
            root: $0, progressData: lemmings3Progress)
        } ?? []
        guard !Task.isCancelled else { return nil }
        return LevelBrowserDiscovery(
          classic: refreshedClassic,
          lemmings2Root: lemmings2Root,
          lemmings2: lemmings2,
          lemmings3Root: lemmings3Root,
          lemmings3: lemmings3)
    }
    levelBrowserDiscoveryTask = discoveryTask
    levelBrowserLoadTask = Task { [weak self, weak loadingPage] in
      guard let discovery = await discoveryTask.value,
            !Task.isCancelled, let self, let loadingPage,
            self.levelBrowserLoadingPage === loadingPage,
            GameScreen.shared.controllerPage(in: self.window) === loadingPage,
            self.window.attachedSheet == nil else { return }
      levelBrowserLoadTask = nil
      levelBrowserDiscoveryTask = nil
      rebuildLevelCatalogue(discovery)
      levelBrowserLoadingPage = nil
      GameScreen.shared.dismiss(loadingPage)
      let packs = levelBrowserPacks(for: family)
      guard !packs.isEmpty else {
        GameScreen.shared.message(browserTitle,
          detail: "No \(browserTitle) level packs are available in this build.")
        return
      }
      if packs.count == 1, let pack = packs.first {
        presentLevelBrowser(for: pack)
      } else {
        presentLevelPackBrowser(packs: packs, title: browserTitle)
      }
    }
  }

  private func rebuildLevelCatalogue(_ discovery: LevelBrowserDiscovery) {
    levelBrowserRoutes = [:]
    levelPreviewRequests = [:]
    levelBrowserPackFamilies = [:]
    levelBrowserFanPacks = [:]
    levelBrowserFanEntries = [:]
    var packs: [LevelCataloguePack] = []

    for source in discovery.classic {
      let dataSet = source.dataSet
      let sourceFingerprint = source.sourceFingerprint
      guard let sourceRevision = source.sourceRevision else { continue }
      let sourceID = ArcadeStore.fingerprint(
        Data(source.directory.standardizedFileURL.path.utf8))
      let packID = sourceFingerprint.map { "imported:" + $0 + ":" + sourceID }
        ?? dataSet.identifierKey
      let status: LevelContentStatus = source.isVerified ? .complete : .unverified
      var browserFlow = ClassicGameFlow(campaign: dataSet.campaign)
      if let data = savedClassicProgressData(for: (set: dataSet, directory: source.directory)),
         let saved = try? JSONDecoder().decode(ClassicGameFlow.Progress.self, from: data) {
        browserFlow.restore(dataSet.migrateProgress(saved))
      }
      let levels = dataSet.campaign.levels.enumerated().map { index, level in
        let identity = LevelCatalogueIdentity(
          engine: .classic,
          packID: packID,
          levelID: "\(index):\(level.rank):\(level.number):\(level.archiveFile):\(level.archiveSection)")
        levelBrowserRoutes[identity] = .classic(
          dataSetDirectory: source.directory,
          dataSet: dataSet,
          levelIndex: index,
          sourceFingerprint: sourceFingerprint,
          sourceRevision: sourceRevision)
        registerLevelPreview(
          identity: identity,
          source: .classic(
            dataSet: dataSet,
            root: source.directory,
            levelIndex: index,
            sourceFingerprint: sourceRevision))
        return LevelCatalogueEntry(
          identity: identity,
          packName: dataSet.name,
          levelName: level.level.title.isEmpty ? "Level \(index + 1)" : level.level.title,
          number: index + 1,
          status: status,
          availability: settings.unlockAllClassicLevels || browserFlow.isLevelUnlocked(index)
            ? .available : .locked)
      }
      let pack = LevelCataloguePack(
        engine: .classic, id: packID, name: dataSet.name,
        status: status, levels: levels)
      packs.append(pack)
      levelBrowserPackFamilies[browserPackKey(pack)] =
        HomeContentFamily.family(for: dataSet.title, kind: dataSet.kind)
    }

    if let root = discovery.lemmings2Root, !discovery.lemmings2.isEmpty {
      for tribe in Lemmings2Campaign.tribeNames.indices {
        let packID = "tribes-\(tribe)"
        let tribeLevels = discovery.lemmings2.filter { $0.selection.tribe == tribe }.map { level in
          let identity = LevelCatalogueIdentity(
            engine: .lemmings2, packID: packID,
            levelID: "\(level.selection.level):\(level.levelID)")
          levelBrowserRoutes[identity] = .lemmings2(
            root: root,
            selection: level.selection,
            expectedLevelID: level.levelID,
            sourceRevision: level.sourceRevision)
          registerLevelPreview(
            identity: identity,
            source: .lemmings2(
              root: root,
              selection: level.selection,
              expectedLevelID: level.levelID))
          return LevelCatalogueEntry(
            identity: identity,
            packName: "The Tribes - \(Lemmings2Campaign.tribeNames[tribe])",
            levelName: level.title.isEmpty ? "Level \(level.selection.level + 1)" : level.title,
            number: level.selection.level + 1,
            status: .preview,
            isAvailable: level.isAvailable)
        }
        let pack = LevelCataloguePack(
          engine: .lemmings2,
          id: packID,
          name: "The Tribes - \(Lemmings2Campaign.tribeNames[tribe])",
          status: .preview,
          levels: tribeLevels)
        packs.append(pack)
        levelBrowserPackFamilies[browserPackKey(pack)] = .lemmings2
      }
    }

    if let root = discovery.lemmings3Root, !discovery.lemmings3.isEmpty {
      for tribe in Lemmings3ClassicCampaign.Tribe.allCases {
        let packID = "chronicles-\(tribe.rawValue)"
        let tribeLevels = discovery.lemmings3.filter { $0.selection.tribe == tribe }.map { level in
          let identity = LevelCatalogueIdentity(
            engine: .lemmings3, packID: packID,
            levelID: "\(level.selection.level):\(level.levelID)")
          levelBrowserRoutes[identity] = .lemmings3(
            root: root,
            selection: level.selection,
            expectedLevelID: level.levelID,
            sourceRevision: level.sourceRevision)
          registerLevelPreview(
            identity: identity,
            source: .lemmings3(
              root: root,
              selection: level.selection,
              expectedLevelID: level.levelID))
          return LevelCatalogueEntry(
            identity: identity,
            packName: "The Chronicles - \(tribe.title)",
            levelName: "\(tribe.title) \(level.selection.level + 1)",
            number: level.selection.level + 1,
            status: .preview,
            isAvailable: level.isAvailable)
        }
        let pack = LevelCataloguePack(
          engine: .lemmings3,
          id: packID,
          name: "The Chronicles - \(tribe.title)",
          status: .preview,
          levels: tribeLevels)
        packs.append(pack)
        levelBrowserPackFamilies[browserPackKey(pack)] = .lemmings3
      }
    }

    for url in FanLevelLibrary.packs() {
      let packID = "fan:" + FanLevelLibrary.catalogueID(url)
      if let failedRevision = levelBrowserInvalidFanPackRevisions[packID],
         failedRevision != Self.fanPackFileRevision(url) {
        levelBrowserInvalidFanPacks.remove(packID)
        levelBrowserInvalidFanPackRevisions[packID] = nil
      }
      let status = FanLevelLibrary.catalogueStatus(url)
      levelBrowserFanPacks[packID] = url
      let pack = LevelCataloguePack(
        engine: .classic,
        id: packID,
        name: FanLevelLibrary.displayName(of: url),
        status: status,
        levels: [])
      packs.append(pack)
      levelBrowserPackFamilies[browserPackKey(pack)] = .fan
    }
    let installedFanPackIDs = Set(levelBrowserFanPacks.keys)
    levelBrowserInvalidFanPacks.formIntersection(installedFanPackIDs)
    levelBrowserInvalidFanPackRevisions = levelBrowserInvalidFanPackRevisions.filter {
      installedFanPackIDs.contains($0.key)
    }
    levelCatalogue = LevelCatalogue(revision: Self.levelCatalogueRevision, packs: packs)
  }

  private static func fanPackFileRevision(_ url: URL) -> String {
    guard let values = try? url.resourceValues(
      forKeys: [.fileSizeKey, .contentModificationDateKey]) else {
      return "missing"
    }
    return "\(values.fileSize ?? -1):\(values.contentModificationDate?.timeIntervalSince1970 ?? -1)"
  }

  private func registerLevelPreview(
    identity: LevelCatalogueIdentity,
    source: LevelPreviewSource
  ) {
    levelPreviewRequests[identity] = LevelPreviewRequest(
      identity: identity,
      catalogueRevision: Self.levelCatalogueRevision,
      source: source)
  }

  private func configureLevelPreviewLoader(_ carousel: LevelCoverFlowView) {
    let requests = Dictionary(
      levelPreviewRequests.values.map { ($0.artworkKey, $0) },
      uniquingKeysWith: { first, _ in first })
    carousel.artworkLoader = { key in
      guard let request = requests[key] else { return nil }
      return try? await LevelPreviewStore.shared.bitmap(for: request)
    }
  }

  private func browserPackKey(_ pack: LevelCataloguePack) -> String {
    pack.engine.rawValue + ":" + pack.id
  }

  private func levelBrowserPacks(
    for family: HomeContentFamily?
  ) -> [LevelCataloguePack] {
    guard let family else { return levelCatalogue.packs }
    return levelCatalogue.packs.filter {
      levelBrowserPackFamilies[browserPackKey($0)] == family
    }
  }

  private func levelPackItems(
    for packs: [LevelCataloguePack]
  ) -> [LevelCoverFlowItem] {
    let total = packs.count
    return packs.enumerated().map { index, pack in
      let fanURL = levelBrowserFanPacks[pack.id]
      let invalidFanPack = levelBrowserInvalidFanPacks.contains(pack.id)
      let knownFanCount = invalidFanPack
        ? nil : fanURL.flatMap { FanLevelLibrary.knownLevelCount(in: $0) }
      let count = invalidFanPack ? 0 : knownFanCount ?? pack.levels.count
      let levels = invalidFanPack ? "Unavailable"
        : knownFanCount == nil && fanURL != nil
          ? "Levels" : count == 1 ? "1 level" : "\(count) levels"
      let artworkKey = pack.levels.lazy.compactMap {
        self.levelPreviewRequests[$0.identity]?.artworkKey
      }.first
      return LevelCoverFlowItem(
        id: browserPackKey(pack),
        title: pack.name,
        subtitle: pack.engine.displayName + " / " + pack.status.displayName,
        detail: "\(levels)  \(index + 1)/\(total)",
        isAvailable: !invalidFanPack && (fanURL != nil || count > 0),
        artworkKey: artworkKey)
    }
  }

  private func refreshOpenLevelPackBrowser() {
    guard let page = levelBrowserPackPage,
          let carousel = levelBrowserPackCarousel,
          GameScreen.shared.contains(page) else { return }
    let packs = levelCatalogue.packs.filter {
      levelBrowserVisiblePackKeys.contains(browserPackKey($0))
    }
    configureLevelPreviewLoader(carousel)
    carousel.configure(
      items: levelPackItems(for: packs),
      selectedID: levelBrowserPackSelection,
      reduceMotion: settings.reduceMotion
        || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
  }

  private func presentLevelPackBrowser(
    packs: [LevelCataloguePack],
    title: String
  ) {
    let page = GameMenuPage(title: title, subtitle: "Packs")
    let carousel = LevelCoverFlowView(frame: page.body.bounds)
    carousel.autoresizingMask = [.width, .height]
    page.body.addSubview(carousel)

    let permittedPackKeys = Set(packs.map(browserPackKey))
    let primary = page.addPrimaryAction("Browse levels") { [weak self, weak carousel] in
      guard let self, let id = carousel?.selectedItem?.id,
            permittedPackKeys.contains(id),
            let pack = self.levelCatalogue.packs.first(where: {
              self.browserPackKey($0) == id
            }) else { return }
      self.presentLevelBrowser(for: pack)
    }
    primary.keyEquivalent = "\r"
    primary.keyEquivalentModifierMask = []
    page.preferControllerControl(primary)
    page.addSecondaryAction("Playlists") { [weak self] in
      self?.presentPlaylistLibrary()
    }
    page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
    carousel.onSelectionChanged = { [weak self, weak primary] item in
      self?.levelBrowserPackSelection = item.id
      primary?.isEnabled = item.isAvailable
      primary?.needsDisplay = true
    }
    carousel.onStart = { [weak primary] _ in primary?.performClick(nil) }

    configureLevelPreviewLoader(carousel)
    carousel.configure(
      items: levelPackItems(for: packs),
      selectedID: levelBrowserPackSelection,
      reduceMotion: settings.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    levelBrowserPackPage = page
    levelBrowserPackCarousel = carousel
    levelBrowserVisiblePackKeys = permittedPackKeys
    GameScreen.shared.present(
      page,
      owner: window,
      focus: carousel,
      onDismiss: { [weak self, weak page] in
        guard let self, let page, self.levelBrowserPackPage === page else { return }
        self.levelBrowserPackPage = nil
        self.levelBrowserPackCarousel = nil
        self.levelBrowserVisiblePackKeys = []
      })
  }

  private func presentLevelBrowser(for unresolvedPack: LevelCataloguePack) {
    guard unresolvedPack.levels.isEmpty,
          let url = levelBrowserFanPacks[unresolvedPack.id] else {
      presentResolvedLevelBrowser(unresolvedPack)
      return
    }
    levelBrowserFanLoadTask?.cancel()
    levelBrowserFanDiscoveryTask?.cancel()
    levelBrowserFanLoadTask = nil
    levelBrowserFanDiscoveryTask = nil
    if let oldPage = levelBrowserFanLoadingPage {
      levelBrowserFanLoadingPage = nil
      GameScreen.shared.dismiss(oldPage)
    }

    let loadingPage = GameMenuPage(title: unresolvedPack.name, subtitle: "Levels")
    levelBrowserFanLoadingPage = loadingPage
    loadingPage.setDetail("Loading the level list.")
    loadingPage.backTitle = "Cancel"
    loadingPage.onBack = { [weak self, weak loadingPage] in
      guard let self, let loadingPage,
            self.levelBrowserFanLoadingPage === loadingPage else { return }
      self.levelBrowserFanLoadTask?.cancel()
      self.levelBrowserFanDiscoveryTask?.cancel()
      self.levelBrowserFanLoadTask = nil
      self.levelBrowserFanDiscoveryTask = nil
      self.levelBrowserFanLoadingPage = nil
      GameScreen.shared.dismiss(loadingPage)
    }
    GameScreen.shared.present(loadingPage, owner: window, onDismiss: { [weak self, weak loadingPage] in
      guard let self, let loadingPage,
            self.levelBrowserFanLoadingPage === loadingPage else { return }
      self.levelBrowserFanLoadTask?.cancel()
      self.levelBrowserFanDiscoveryTask?.cancel()
      self.levelBrowserFanLoadTask = nil
      self.levelBrowserFanDiscoveryTask = nil
      self.levelBrowserFanLoadingPage = nil
    })

    let discoveryTask = Task.detached(priority: .userInitiated) {
      () -> LevelBrowserFanDiscovery? in
      guard !Task.isCancelled,
            let before = FanLevelLibrary.archiveFingerprint(url) else { return nil }
      guard let entries = try? FanLevelLibrary.validatedEntries(in: url) else {
        return nil
      }
      guard !Task.isCancelled,
            let after = FanLevelLibrary.archiveFingerprint(url),
            before == after else { return nil }
      return LevelBrowserFanDiscovery(fingerprint: before, entries: entries)
    }
    levelBrowserFanDiscoveryTask = discoveryTask
    levelBrowserFanLoadTask = Task { [weak self, weak loadingPage] in
      let discovery = await discoveryTask.value
      guard !Task.isCancelled, let self, let loadingPage,
            self.levelBrowserFanLoadingPage === loadingPage,
            GameScreen.shared.controllerPage(in: self.window) === loadingPage,
            self.window.attachedSheet == nil else { return }
      levelBrowserFanLoadTask = nil
      levelBrowserFanDiscoveryTask = nil
      levelBrowserFanLoadingPage = nil
      GameScreen.shared.dismiss(loadingPage)
      guard let discovery else {
        self.invalidateResolvedFanPack(id: unresolvedPack.id)
        GameScreen.shared.message(unresolvedPack.name,
          detail: "The archive changed or could not be read. Repair or replace it, then open Level Select and try again.")
        return
      }
      FanLevelLibrary.Progress.setCount(discovery.entries.count, for: url)
      presentResolvedLevelBrowser(resolveBrowserPack(unresolvedPack, discovery: discovery))
    }
  }

  private func presentResolvedLevelBrowser(_ pack: LevelCataloguePack) {
    guard !pack.levels.isEmpty else {
      GameScreen.shared.message(pack.name, detail: "This pack has no playable levels.")
      return
    }
    let page = GameMenuPage(
      title: pack.name,
      subtitle: pack.engine.displayName + " / " + pack.status.displayName)
    let carousel = LevelCoverFlowView(frame: page.body.bounds)
    carousel.autoresizingMask = [.width, .height]
    page.body.addSubview(carousel)

    let identities = Dictionary(pack.levels.map { ($0.identity.levelID, $0.identity) },
      uniquingKeysWith: { first, _ in first })
    let primary = page.addPrimaryAction("Start") { [weak self, weak carousel] in
      guard let item = carousel?.selectedItem,
            let identity = identities[item.id] else { return }
      self?.startBrowserLevel(identity)
    }
    primary.keyEquivalent = "\r"
    primary.keyEquivalentModifierMask = []
    page.preferControllerControl(primary)
    let add = page.addSecondaryAction("Add") { [weak self, weak carousel] in
      guard let item = carousel?.selectedItem,
            let identity = identities[item.id] else { return }
      self?.addToSelectedPlaylist(identity)
    }
    page.addSecondaryAction("Playlists", at: 1) { [weak self] in
      self?.presentPlaylistLibrary()
    }
    page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
    carousel.onSelectionChanged = { [weak self, weak primary, weak add] item in
      self?.levelBrowserLevelSelections[pack.id] = item.id
      primary?.isEnabled = item.isAvailable
      primary?.needsDisplay = true
      add?.isEnabled = item.isAvailable
      add?.needsDisplay = true
    }
    carousel.onStart = { [weak primary] _ in primary?.performClick(nil) }

    let total = pack.levels.count
    let items = pack.levels.enumerated().map { index, entry in
      LevelCoverFlowItem(
        id: entry.identity.levelID,
        title: entry.levelName,
        subtitle: entry.packName + " / " + entry.identity.engine.displayName,
        detail: "Level \(entry.number)  \(entry.status.displayName)  \(index + 1)/\(total)",
        isAvailable: entry.isAvailable,
        artworkKey: levelPreviewRequests[entry.identity]?.artworkKey,
        availability: entry.availability)
    }
    configureLevelPreviewLoader(carousel)
    carousel.configure(
      items: items,
      selectedID: levelBrowserLevelSelections[pack.id],
      reduceMotion: settings.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    add.isEnabled = carousel.selectedItem?.isAvailable == true
    levelBrowserCurrentLevelPage = page
    GameScreen.shared.present(
      page,
      owner: window,
      focus: carousel,
      onDismiss: { [weak self, weak page] in
        guard let self, let page, self.levelBrowserCurrentLevelPage === page else { return }
        self.levelBrowserCurrentLevelPage = nil
      })
  }

  private func resolveBrowserPack(
    _ pack: LevelCataloguePack,
    discovery: LevelBrowserFanDiscovery
  ) -> LevelCataloguePack {
    guard let url = levelBrowserFanPacks[pack.id] else { return pack }
    levelBrowserInvalidFanPacks.remove(pack.id)
    levelBrowserInvalidFanPackRevisions[pack.id] = nil
    for identity in pack.levels.map(\.identity) {
      levelBrowserRoutes[identity] = nil
      levelPreviewRequests[identity] = nil
    }
    levelBrowserFanEntries[pack.id] = discovery.entries
    let portsRoot = Bundle.main.resourceURL?.appendingPathComponent("Ports")
    let levels = discovery.entries.enumerated().map { index, entry in
      let identity = LevelCatalogueIdentity(
        engine: .classic,
        packID: pack.id,
        levelID: entry.file + "#\(entry.section ?? -1)")
      levelBrowserRoutes[identity] = .fan(
        pack: url, entry: entry, archiveFingerprint: discovery.fingerprint)
      if let portsRoot {
        registerLevelPreview(
          identity: identity,
          source: .fanClassic(
            pack: url,
            entry: entry,
            archiveFingerprint: discovery.fingerprint,
            portsRoot: portsRoot))
      }
      return LevelCatalogueEntry(
        identity: identity,
        packName: pack.name,
        levelName: entry.label,
        number: index + 1,
        status: pack.status)
    }
    let resolved = LevelCataloguePack(
      engine: pack.engine, id: pack.id, name: pack.name,
      status: pack.status, levels: levels)
    var packs = levelCatalogue.packs
    if let index = packs.firstIndex(where: { $0.engine == pack.engine && $0.id == pack.id }) {
      packs[index] = resolved
      levelCatalogue = LevelCatalogue(revision: levelCatalogue.revision, packs: packs)
      refreshOpenLevelPackBrowser()
    }
    return resolved
  }

  // MARK: - Player playlists and shuffled runs

  private func playlistStore() throws -> LevelPlaylistStore {
    let profileID = ArcadeStore.shared.records.activeProfileID
    if let cached = playlistStoreCache, cached.profileID == profileID {
      return cached.store
    }
    let store = try LevelPlaylistStore(profileID: profileID)
    playlistStoreCache = (profileID, store)
    return store
  }

  private func playlistSourceRevision(
    for identity: LevelCatalogueIdentity
  ) -> String? {
    guard let route = levelBrowserRoutes[identity] else { return nil }
    switch route {
    case let .classic(_, _, _, _, sourceRevision):
      return sourceRevision
    case let .fan(_, _, archiveFingerprint):
      return archiveFingerprint
    case let .lemmings2(_, _, _, sourceRevision):
      return sourceRevision
    case let .lemmings3(_, _, _, sourceRevision):
      return sourceRevision
    }
  }

  private func playlistEntry(
    for identity: LevelCatalogueIdentity
  ) throws -> LevelPlaylistEntry {
    guard let entry = levelCatalogue.resolve(identity),
          liveLevelAvailability(entry) == .available,
          let sourceRevision = playlistSourceRevision(for: identity) else {
      throw LevelPlaylistError.invalidEntry
    }
    return try LevelPlaylistEntry(
      identity: identity,
      catalogueRevision: levelCatalogue.revision,
      sourceRevision: sourceRevision,
      packNameSnapshot: entry.packName,
      levelNameSnapshot: entry.levelName,
      levelNumberSnapshot: entry.number)
  }

  private func playlistResolution(
    for saved: LevelPlaylistEntry
  ) -> PlaylistEntryResolution {
    guard let current = levelCatalogue.resolve(saved.identity),
          levelBrowserRoutes[saved.identity] != nil else { return .missing }
    guard saved.catalogueRevision == levelCatalogue.revision,
          saved.sourceRevision == playlistSourceRevision(for: saved.identity) else {
      return .changed
    }
    switch liveLevelAvailability(current) {
    case .available: return .available(current)
    case .locked: return .locked(current)
    case .unavailable: return .unavailable(current)
    }
  }

  private func liveLevelAvailability(_ entry: LevelCatalogueEntry) -> LevelAvailability {
    guard case let .classic(dataSetDirectory, dataSet, levelIndex, _, _)? =
            levelBrowserRoutes[entry.identity] else {
      return entry.availability
    }
    return settings.unlockAllClassicLevels
      || classicBrowserLevelIsUnlocked(
        dataSet: dataSet,
        directory: dataSetDirectory,
        levelIndex: levelIndex)
      ? .available : .locked
  }

  private func refreshClassicCatalogueAvailability() {
    guard !levelCatalogue.packs.isEmpty else { return }
    let packs = levelCatalogue.packs.map { pack in
      let levels = pack.levels.map { entry in
        guard case .classic? = levelBrowserRoutes[entry.identity] else { return entry }
        return LevelCatalogueEntry(
          identity: entry.identity,
          packName: entry.packName,
          levelName: entry.levelName,
          number: entry.number,
          status: entry.status,
          availability: liveLevelAvailability(entry))
      }
      return LevelCataloguePack(
        engine: pack.engine,
        id: pack.id,
        name: pack.name,
        status: pack.status,
        levels: levels)
    }
    levelCatalogue = LevelCatalogue(revision: levelCatalogue.revision, packs: packs)
  }

  private func updateLevelSelectionReducedMotion() {
    let enabled = settings.reduceMotion
      || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    func update(_ view: NSView) {
      (view as? LevelCoverFlowView)?.setReducedMotion(enabled)
      view.subviews.forEach(update)
    }
    if let contentView = window.contentView { update(contentView) }
  }

  private func playlistMutationDate(_ playlist: LevelPlaylist) -> Date {
    Date(timeIntervalSinceReferenceDate: max(
      Date().timeIntervalSinceReferenceDate,
      playlist.updatedAt.timeIntervalSinceReferenceDate + 0.001))
  }

  private func nextPlaylistName(prefix: String, store: LevelPlaylistStore) -> String {
    let existing = Set(store.playlists.map { $0.name.lowercased() })
    var index = 1
    while existing.contains("\(prefix) \(index)".lowercased()) { index += 1 }
    return "\(prefix) \(index)"
  }

  private func addToSelectedPlaylist(
    _ identity: LevelCatalogueIdentity,
    validatesFanSource: Bool = true
  ) {
    if validatesFanSource, levelBrowserFanPacks[identity.packID] != nil {
      ensureFanPacksResolved(
        forPackIDs: [identity.packID],
        title: "Add to playlist",
        reloadResolved: true
      ) { [weak self] failures in
        guard let self else { return }
        guard !failures.contains(identity.packID) else {
          GameScreen.shared.message(
            "Level not added",
            detail: "The fan level pack changed or could not be read.")
          return
        }
        self.addToSelectedPlaylist(identity, validatesFanSource: false)
      }
      return
    }
    do {
      let store = try playlistStore()
      var playlist: LevelPlaylist
      if let selected = store.selectedPlaylist() {
        playlist = selected
      } else {
        playlist = try LevelPlaylist(name: nextPlaylistName(prefix: "Playlist", store: store))
        try store.add(playlist)
      }
      let entry = try playlistEntry(for: identity)
      try playlist.add(entry, updatedAt: playlistMutationDate(playlist))
      try store.update(playlist)
      GameScreen.shared.message("Added to \(playlist.name)", detail: entry.levelNameSnapshot)
    } catch LevelPlaylistError.duplicateEntry {
      GameScreen.shared.message("Already in playlist", detail: "Choose another level or open Playlists to change the order.")
    } catch {
      GameScreen.shared.message("Playlist not saved", detail: error.localizedDescription)
    }
  }

  private func presentPlaylistLibrary() {
    if let previous = playlistLibraryPage, GameScreen.shared.contains(previous) {
      GameScreen.shared.dismiss(previous)
    }
    let store: LevelPlaylistStore
    do {
      store = try playlistStore()
    } catch {
      GameScreen.shared.message("Playlists unavailable", detail: error.localizedDescription)
      return
    }
    let page = GameMenuPage(title: "Playlists", subtitle: "Saved level sequences")
    let carousel = LevelCoverFlowView(frame: page.body.bounds)
    carousel.autoresizingMask = [.width, .height]
    page.body.addSubview(carousel)

    let primary = page.addPrimaryAction("Open") { [weak self, weak carousel] in
      guard let id = carousel?.selectedItem?.id else { return }
      self?.activatePlaylistLibraryItem(id)
    }
    primary.keyEquivalent = "\r"
    primary.keyEquivalentModifierMask = []
    page.preferControllerControl(primary)
    page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
    carousel.onSelectionChanged = { [weak self, weak primary] item in
      self?.playlistLibrarySelection = item.id
      primary?.title = item.id == "playlist:new" ? "Create"
        : item.id == "playlist:random" ? "Choose pool"
        : item.id == "playlist:shuffle-all" ? "Shuffle"
        : item.id == "playlist:resume" ? "Resume" : "Open"
      primary?.isEnabled = item.isAvailable
      primary?.needsDisplay = true
    }
    carousel.onStart = { [weak primary] _ in primary?.performClick(nil) }

    var items: [LevelCoverFlowItem] = []
    if let run = store.activeRun {
      items.append(LevelCoverFlowItem(
        id: "playlist:resume",
        title: "Resume run",
        subtitle: run.pool.summary,
        detail: "Level \(run.currentIndex + 1) of \(run.entries.count)",
        artworkKey: levelPreviewRequests[run.currentEntry.identity]?.artworkKey))
    }
    items.append(LevelCoverFlowItem(
      id: "playlist:new",
      title: "New playlist",
      subtitle: "Choose and order levels",
      detail: "Manual"))
    items.append(LevelCoverFlowItem(
      id: "playlist:random",
      title: "Random 10",
      subtitle: "Choose one level pack",
      detail: "Saved and editable",
      isAvailable: !levelCatalogue.packs.isEmpty))
    items.append(LevelCoverFlowItem(
      id: "playlist:shuffle-all",
      title: "Shuffle all",
      subtitle: "Eligible fan levels",
      detail: "No repeats",
      isAvailable: !levelBrowserFanPacks.isEmpty))
    items += store.playlists.map { playlist in
      LevelCoverFlowItem(
        id: "playlist:saved:\(playlist.id.uuidString)",
        title: playlist.name,
        subtitle: playlist.entries.count == 1 ? "1 level" : "\(playlist.entries.count) levels",
        detail: "Manual order",
        artworkKey: playlist.entries.first.flatMap {
          levelPreviewRequests[$0.identity]?.artworkKey
        })
    }
    configureLevelPreviewLoader(carousel)
    carousel.configure(
      items: items,
      selectedID: playlistLibrarySelection,
      reduceMotion: settings.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    primary.isEnabled = carousel.selectedItem?.isAvailable == true
    playlistLibraryPage = page
    GameScreen.shared.present(
      page,
      owner: window,
      focus: carousel,
      onDismiss: { [weak self, weak page] in
        guard let self, let page, self.playlistLibraryPage === page else { return }
        self.playlistLibraryPage = nil
      })
  }

  private func activatePlaylistLibraryItem(_ id: String) {
    switch id {
    case "playlist:new":
      do {
        let store = try playlistStore()
        let playlist = try LevelPlaylist(
          name: nextPlaylistName(prefix: "Playlist", store: store))
        try store.add(playlist)
        playlistLibrarySelection = "playlist:saved:\(playlist.id.uuidString)"
        presentPlaylistEditor(id: playlist.id)
      } catch {
        GameScreen.shared.message("Playlist not created", detail: error.localizedDescription)
      }
    case "playlist:random":
      presentRandomPlaylistPool()
    case "playlist:shuffle-all":
      prepareShuffleAllFanLevels()
    case "playlist:resume":
      guard let run = try? playlistStore().activeRun else { return }
      ensureFanPacksResolved(for: run.entries, title: "Resume run") { [weak self] _ in
        self?.startActiveSequence()
      }
    default:
      let prefix = "playlist:saved:"
      guard id.hasPrefix(prefix),
            let playlistID = UUID(uuidString: String(id.dropFirst(prefix.count))) else { return }
      do {
        let store = try playlistStore()
        guard let playlist = store.playlist(id: playlistID) else { return }
        try store.selectPlaylist(id: playlistID)
        ensureFanPacksResolved(for: playlist.entries, title: playlist.name) { [weak self] _ in
          self?.presentPlaylistEditor(id: playlistID)
        }
      } catch {
        GameScreen.shared.message("Playlist not opened", detail: error.localizedDescription)
      }
    }
  }

  private func playlistCoverItem(
    _ saved: LevelPlaylistEntry,
    position: Int,
    total: Int
  ) -> LevelCoverFlowItem {
    let suffix = "\(position + 1)/\(total)"
    switch playlistResolution(for: saved) {
    case let .available(current):
      return LevelCoverFlowItem(
        id: saved.id.uuidString,
        title: current.levelName,
        subtitle: current.packName + " / " + current.identity.engine.displayName,
        detail: "Level \(current.number)  \(suffix)",
        artworkKey: levelPreviewRequests[current.identity]?.artworkKey)
    case let .locked(current):
      return LevelCoverFlowItem(
        id: saved.id.uuidString,
        title: current.levelName,
        subtitle: current.packName + " / " + current.identity.engine.displayName,
        detail: "Locked  \(suffix)",
        artworkKey: levelPreviewRequests[current.identity]?.artworkKey,
        availability: .locked)
    case let .unavailable(current):
      return LevelCoverFlowItem(
        id: saved.id.uuidString,
        title: current.levelName,
        subtitle: current.packName + " / " + current.identity.engine.displayName,
        detail: "Unavailable  \(suffix)",
        artworkKey: levelPreviewRequests[current.identity]?.artworkKey,
        availability: .unavailable)
    case .changed:
      return LevelCoverFlowItem(
        id: saved.id.uuidString,
        title: saved.levelNameSnapshot,
        subtitle: saved.packNameSnapshot + " / " + saved.identity.engine.displayName,
        detail: "Changed - replace or remove  \(suffix)",
        availability: .unavailable)
    case .missing:
      return LevelCoverFlowItem(
        id: saved.id.uuidString,
        title: saved.levelNameSnapshot,
        subtitle: saved.packNameSnapshot + " / " + saved.identity.engine.displayName,
        detail: "Missing - replace or remove  \(suffix)",
        availability: .unavailable)
    }
  }

  private func presentPlaylistEditor(id: UUID) {
    guard let store = try? playlistStore(), let playlist = store.playlist(id: id) else {
      GameScreen.shared.message("Playlist unavailable", detail: "The selected playlist is no longer available.")
      return
    }
    let page = GameMenuPage(
      title: playlist.name,
      subtitle: playlist.entries.count == 1 ? "1 level" : "\(playlist.entries.count) levels")
    let carousel = LevelCoverFlowView(frame: CGRect(x: 0, y: 0, width: page.body.bounds.width, height: 360))
    carousel.autoresizingMask = [.width]
    page.body.addSubview(carousel)

    func editorButton(_ title: String, x: CGFloat, action: @escaping () -> Void) -> GameActionButton {
      let button = GameActionButton(title: title, primary: false, onPress: action)
      button.frame = CGRect(x: x, y: 380, width: 182, height: 44)
      page.body.addSubview(button)
      return button
    }

    var selectedEntryID: UUID? = playlistEntrySelections[id]
    let earlier = editorButton("Earlier", x: 10) { [weak self, weak page, weak carousel] in
      guard let self, let page, let selected = carousel?.selectedItem,
            let entryID = UUID(uuidString: selected.id),
            var current = try? self.playlistStore().playlist(id: id),
            let source = current.entries.firstIndex(where: { $0.id == entryID }), source > 0 else { return }
      do {
        _ = try current.move(
          id: entryID, to: source - 1, updatedAt: self.playlistMutationDate(current))
        try self.playlistStore().update(current)
        self.playlistEntrySelections[id] = entryID
        GameScreen.shared.dismiss(page)
        self.presentPlaylistEditor(id: id)
      } catch {
        GameScreen.shared.message("Playlist not changed", detail: error.localizedDescription)
      }
    }
    let later = editorButton("Later", x: 208) { [weak self, weak page, weak carousel] in
      guard let self, let page, let selected = carousel?.selectedItem,
            let entryID = UUID(uuidString: selected.id),
            var current = try? self.playlistStore().playlist(id: id),
            let source = current.entries.firstIndex(where: { $0.id == entryID }),
            source + 1 < current.entries.count else { return }
      do {
        _ = try current.move(
          id: entryID, to: source + 1, updatedAt: self.playlistMutationDate(current))
        try self.playlistStore().update(current)
        self.playlistEntrySelections[id] = entryID
        GameScreen.shared.dismiss(page)
        self.presentPlaylistEditor(id: id)
      } catch {
        GameScreen.shared.message("Playlist not changed", detail: error.localizedDescription)
      }
    }
    let remove = editorButton("Remove", x: 406) { [weak self, weak page, weak carousel] in
      guard let self, let page, let selected = carousel?.selectedItem,
            let entryID = UUID(uuidString: selected.id) else { return }
      GameScreen.shared.confirm(
        "Remove level",
        detail: "Remove \(selected.title) from this playlist?",
        actionTitle: "Remove") { [weak self, weak page] in
          guard let self, let page,
                var current = try? self.playlistStore().playlist(id: id) else { return }
          do {
            _ = try current.remove(
              id: entryID, updatedAt: self.playlistMutationDate(current))
            try self.playlistStore().update(current)
            self.playlistEntrySelections[id] = nil
            GameScreen.shared.dismiss(page)
            self.presentPlaylistEditor(id: id)
          } catch {
            GameScreen.shared.message("Level not removed", detail: error.localizedDescription)
          }
        }
    }
    let replace = editorButton("Replace", x: 604) { [weak self, weak page, weak carousel] in
      guard let self, let page, let selected = carousel?.selectedItem,
            let entryID = UUID(uuidString: selected.id) else { return }
      self.presentPlaylistLevelPicker(
        playlistID: id,
        replacing: entryID,
        editorPage: page)
    }
    let rename = editorButton("Rename", x: 802) { [weak self, weak page] in
      guard let self, let page else { return }
      self.presentPlaylistRename(id: id, editorPage: page)
    }

    let play = page.addPrimaryAction("Play") { [weak self] in
      self?.startPlaylist(id: id, shuffled: false)
    }
    play.keyEquivalent = "\r"
    play.keyEquivalentModifierMask = []
    let add = page.addSecondaryAction("Add level") { [weak self, weak page] in
      guard let self, let page else { return }
      self.presentPlaylistLevelPicker(
        playlistID: id,
        replacing: nil,
        editorPage: page)
    }
    let shuffle = page.addSecondaryAction("Shuffle", at: 1) { [weak self] in
      self?.startPlaylist(id: id, shuffled: true)
    }
    page.preferControllerControl(playlist.entries.isEmpty ? add : play)
    page.onBack = { [weak self, weak page] in
      guard let self, let page else { return }
      GameScreen.shared.dismiss(page)
      self.presentPlaylistLibrary()
    }

    let items = playlist.entries.enumerated().map {
      playlistCoverItem($0.element, position: $0.offset, total: playlist.entries.count)
    }
    let allPlayable = !playlist.entries.isEmpty
      && playlist.entries.allSatisfy { playlistResolution(for: $0).canStart }
    func updateButtons(_ item: LevelCoverFlowItem?) {
      selectedEntryID = item.flatMap { UUID(uuidString: $0.id) }
      if let selectedEntryID { playlistEntrySelections[id] = selectedEntryID }
      let index = selectedEntryID.flatMap { selectedID in
        playlist.entries.firstIndex(where: { $0.id == selectedID })
      }
      earlier.isEnabled = (index ?? 0) > 0
      later.isEnabled = index.map { $0 + 1 < playlist.entries.count } ?? false
      remove.isEnabled = selectedEntryID != nil
      replace.isEnabled = selectedEntryID != nil
      rename.isEnabled = true
      [earlier, later, remove, replace, rename].forEach { $0.needsDisplay = true }
    }
    carousel.onSelectionChanged = { item in updateButtons(item) }
    carousel.onStart = { [weak play] _ in play?.performClick(nil) }
    configureLevelPreviewLoader(carousel)
    carousel.configure(
      items: items,
      selectedID: selectedEntryID?.uuidString,
      reduceMotion: settings.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    updateButtons(carousel.selectedItem)
    play.isEnabled = allPlayable
    shuffle.isEnabled = allPlayable
    play.needsDisplay = true
    shuffle.needsDisplay = true
    if playlist.entries.isEmpty {
      let empty = GameLabel(labelWithString: "No levels yet")
      empty.alignment = .center
      empty.role = .heading
      empty.frame = carousel.frame
      empty.autoresizingMask = [.width]
      page.body.addSubview(empty, positioned: .above, relativeTo: carousel)
    }
    let initialFocus: NSResponder = playlist.entries.isEmpty ? add : carousel
    playlistEditorPage = page
    playlistEditorID = id
    GameScreen.shared.present(
      page,
      owner: window,
      focus: initialFocus,
      onDismiss: { [weak self, weak page] in
        guard let self, let page, self.playlistEditorPage === page else { return }
        self.playlistEditorPage = nil
        self.playlistEditorID = nil
      })
  }

  private func refreshOpenPlaylistEditor(id: UUID) {
    guard playlistEditorID == id,
          let page = playlistEditorPage,
          GameScreen.shared.contains(page) else { return }
    GameScreen.shared.dismiss(page)
    presentPlaylistEditor(id: id)
  }

  private func presentPlaylistRename(id: UUID, editorPage: GameMenuPage) {
    guard let playlist = try? playlistStore().playlist(id: id) else { return }
    let page = GameMenuPage(title: "Rename playlist")
    let label = GameLabel(labelWithString: "Playlist name")
    label.role = .heading
    label.frame = CGRect(x: 156, y: 120, width: 680, height: 32)
    page.body.addSubview(label)
    let field = GameSearchField(frame: CGRect(x: 156, y: 166, width: 680, height: 48))
    field.placeholderString = "Playlist name"
    field.stringValue = playlist.name
    page.body.addSubview(field)
    let save = page.addPrimaryAction("Save") { [weak self, weak page, weak editorPage, weak field] in
      guard let self, let page, let editorPage, let field,
            var current = try? self.playlistStore().playlist(id: id) else { return }
      do {
        _ = try current.rename(
          field.stringValue, updatedAt: self.playlistMutationDate(current))
        try self.playlistStore().update(current)
        GameScreen.shared.dismiss(editorPage)
        self.presentPlaylistEditor(id: id)
      } catch {
        GameScreen.shared.message("Playlist not renamed", detail: error.localizedDescription)
      }
      if GameScreen.shared.contains(page) { GameScreen.shared.dismiss(page) }
    }
    save.keyEquivalent = "\r"
    save.keyEquivalentModifierMask = []
    page.addSecondaryAction("Delete playlist") { [weak self, weak page, weak editorPage] in
      guard let self, let page, let editorPage,
            let store = try? self.playlistStore(),
            let current = store.playlist(id: id) else { return }
      let deletesActiveRun: Bool
      if case let .playlist(activeID)? = store.activeRun?.source {
        deletesActiveRun = activeID == id
      } else {
        deletesActiveRun = false
      }
      let detail = deletesActiveRun
        ? "Delete \(current.name) and discard its saved run?"
        : "Delete \(current.name)?"
      GameScreen.shared.confirm(
        "Delete playlist",
        detail: detail,
        actionTitle: "Delete",
        owner: self.window) { [weak self, weak page, weak editorPage] in
          guard let self, let page, let editorPage else { return }
          do {
            try store.removePlaylist(id: id)
            self.playlistEntrySelections[id] = nil
            self.playlistLibrarySelection = "playlist:new"
            if deletesActiveRun && self.sequencePlayingIdentity != nil {
              self.returnToLibrary()
            } else {
              GameScreen.shared.dismiss(page)
              GameScreen.shared.dismiss(editorPage)
            }
            self.presentPlaylistLibrary()
          } catch {
            GameScreen.shared.message("Playlist not deleted", detail: error.localizedDescription)
          }
        }
    }
    page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
    GameScreen.shared.present(page, owner: window, focus: field)
  }

  private func startPlaylist(id: UUID, shuffled: Bool) {
    do {
      guard let playlist = try playlistStore().playlist(id: id),
            !playlist.entries.isEmpty else {
        throw LevelPlaylistError.emptyPool
      }
      ensureFanPacksResolved(
        for: playlist.entries,
        title: "Start \(playlist.name)"
      ) { [weak self] failures in
        guard let self else { return }
        guard failures.isEmpty else {
          self.refreshOpenPlaylistEditor(id: id)
          GameScreen.shared.message(
            "Playlist not started",
            detail: "A fan level pack changed or could not be read.")
          return
        }
        self.startResolvedPlaylist(id: id, shuffled: shuffled)
      }
    } catch {
      GameScreen.shared.message("Playlist not started", detail: error.localizedDescription)
    }
  }

  private func startResolvedPlaylist(id: UUID, shuffled: Bool) {
    do {
      let store = try playlistStore()
      guard let playlist = store.playlist(id: id), !playlist.entries.isEmpty else {
        throw LevelPlaylistError.emptyPool
      }
      guard playlist.entries.allSatisfy({ playlistResolution(for: $0).canStart }) else {
        refreshOpenPlaylistEditor(id: id)
        GameScreen.shared.message(
          playlist.name,
          detail: "Replace or remove each locked, missing or changed level before starting.")
        return
      }
      let pool = try LevelPool(
        id: "playlist:\(playlist.id.uuidString):\(playlist.updatedAt.timeIntervalSinceReferenceDate)",
        summary: "\(playlist.name) - \(playlist.entries.count) levels")
      let run = try LevelSequenceRun.playlist(
        playlist,
        pool: pool,
        seed: shuffled ? UInt64.random(in: UInt64.min...UInt64.max) : nil)
      installActiveSequence(run, in: store)
    } catch {
      GameScreen.shared.message("Playlist not started", detail: error.localizedDescription)
    }
  }

  private func installActiveSequence(
    _ run: LevelSequenceRun,
    in store: LevelPlaylistStore
  ) {
    guard !ArcadeStore.shared.hotSeatIsActive else {
      GameScreen.shared.message(
        "Playlist unavailable",
        detail: "End Hot Seat before starting a playlist or shuffle.")
      return
    }
    let ownerProfileID = ArcadeStore.shared.records.activeProfileID
    let begin = { [weak self] in
      guard let self else { return }
      guard !ArcadeStore.shared.hotSeatIsActive,
            ArcadeStore.shared.records.activeProfileID == ownerProfileID,
            self.playlistStoreCache?.profileID == ownerProfileID,
            self.playlistStoreCache?.store === store else {
        GameScreen.shared.message(
          "Run not started",
          detail: "The player or Hot Seat session changed while the run was being prepared.")
        return
      }
      do {
        self.returnToLibrary()
        try store.setActiveRun(run)
        self.sequencePlaylistStore = store
        self.startActiveSequence()
      } catch {
        GameScreen.shared.message("Run not started", detail: error.localizedDescription)
      }
    }
    guard let active = store.activeRun else {
      begin()
      return
    }
    GameScreen.shared.confirm(
      "Replace current run?",
      detail: "The saved position at level \(active.currentIndex + 1) of \(active.entries.count) will be discarded.",
      actionTitle: "Replace run",
      owner: window) { [weak self] in
        guard let self else { return }
        self.ensureFanPacksResolved(
          for: run.entries,
          title: "Replace run"
        ) { [weak self] failures in
          guard let self else { return }
          guard failures.isEmpty,
                run.entries.allSatisfy({
                  self.playlistResolution(for: $0).canStart
                }) else {
            if case let .playlist(id) = run.source {
              self.refreshOpenPlaylistEditor(id: id)
            }
            GameScreen.shared.message(
              "Run not started",
              detail: "A level was locked, removed or changed while the confirmation was open.")
            return
          }
          begin()
        }
      }
  }

  private func sequenceRunMatches(
    _ runID: UUID,
    identity: LevelCatalogueIdentity
  ) -> Bool {
    guard !ArcadeStore.shared.hotSeatIsActive,
          playlistStoreCache?.profileID == ArcadeStore.shared.records.activeProfileID,
          let store = sequencePlaylistStore,
          playlistStoreCache?.store === store,
          let run = store.activeRun else { return false }
    return run.id == runID && run.currentEntry.identity == identity
  }

  private func beginSequenceLaunch(
    runID: UUID?,
    identity: LevelCatalogueIdentity
  ) -> Bool {
    guard let runID else { return true }
    guard sequenceRunMatches(runID, identity: identity) else {
      GameScreen.shared.message(
        "Run not started",
        detail: "The player, Hot Seat session or saved run changed before the level loaded.")
      return false
    }
    sequenceLaunchRunID = runID
    refreshSequenceNavigationAvailability()
    return true
  }

  private func sequenceLaunchCanCommit(
    runID: UUID?,
    identity: LevelCatalogueIdentity
  ) -> Bool {
    guard let runID else { return true }
    guard sequenceLaunchRunID == runID,
          sequenceRunMatches(runID, identity: identity) else {
      clearSequenceLaunch(runID)
      GameScreen.shared.message(
        "Run not started",
        detail: "The player, Hot Seat session or saved run changed while the level was loading.")
      return false
    }
    return true
  }

  private func presentPlaylistLevelPicker(
    playlistID: UUID,
    replacing entryID: UUID?,
    editorPage: GameMenuPage
  ) {
    let page = GameMenuPage(
      title: entryID == nil ? "Add level" : "Replace level",
      subtitle: "Choose a pack")
    let carousel = LevelCoverFlowView(frame: page.body.bounds)
    carousel.autoresizingMask = [.width, .height]
    page.body.addSubview(carousel)
    let primary = page.addPrimaryAction("Browse levels") { [weak self, weak carousel, weak editorPage] in
      guard let self, let editorPage, let selected = carousel?.selectedItem,
            let pack = self.levelCatalogue.packs.first(where: {
              self.browserPackKey($0) == selected.id
            }) else { return }
      self.ensureFanPacksResolved(
        forPackIDs: [pack.id],
        title: pack.name,
        reloadResolved: self.levelBrowserFanPacks[pack.id] != nil
      ) { [weak self, weak editorPage] _ in
        guard let self, let editorPage,
              let resolved = self.levelCatalogue.packs.first(where: {
                $0.engine == pack.engine && $0.id == pack.id
              }) else { return }
        self.presentPlaylistLevelChoice(
          pack: resolved,
          playlistID: playlistID,
          replacing: entryID,
          editorPage: editorPage)
      }
    }
    primary.keyEquivalent = "\r"
    primary.keyEquivalentModifierMask = []
    page.preferControllerControl(primary)
    page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
    carousel.onSelectionChanged = { [weak primary] item in
      primary?.isEnabled = item.isAvailable
      primary?.needsDisplay = true
    }
    carousel.onStart = { [weak primary] _ in primary?.performClick(nil) }
    let items = levelCatalogue.packs.enumerated().map { index, pack in
      let fanURL = levelBrowserFanPacks[pack.id]
      let count = fanURL.flatMap { FanLevelLibrary.knownLevelCount(in: $0) }
        ?? pack.levels.count
      return LevelCoverFlowItem(
        id: browserPackKey(pack),
        title: pack.name,
        subtitle: pack.engine.displayName + " / " + pack.status.displayName,
        detail: fanURL != nil && count == 0 ? "Levels  \(index + 1)/\(levelCatalogue.packs.count)"
          : "\(count) levels  \(index + 1)/\(levelCatalogue.packs.count)",
        isAvailable: fanURL != nil || pack.levels.contains(where: \.isAvailable),
        artworkKey: pack.levels.lazy.compactMap {
          self.levelPreviewRequests[$0.identity]?.artworkKey
        }.first)
    }
    configureLevelPreviewLoader(carousel)
    carousel.configure(
      items: items,
      reduceMotion: settings.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    GameScreen.shared.present(page, owner: window, focus: carousel)
  }

  private func presentPlaylistLevelChoice(
    pack: LevelCataloguePack,
    playlistID: UUID,
    replacing entryID: UUID?,
    editorPage: GameMenuPage
  ) {
    guard !pack.levels.isEmpty else {
      GameScreen.shared.message(pack.name, detail: "This pack has no playable levels.")
      return
    }
    let page = GameMenuPage(
      title: pack.name,
      subtitle: entryID == nil ? "Add to playlist" : "Choose replacement")
    let carousel = LevelCoverFlowView(frame: page.body.bounds)
    carousel.autoresizingMask = [.width, .height]
    page.body.addSubview(carousel)
    let primary = page.addPrimaryAction(entryID == nil ? "Add" : "Replace") {
      [weak self, weak carousel, weak editorPage] in
      guard let self, let editorPage, let selected = carousel?.selectedItem,
            let identity = pack.levels.first(where: {
              $0.identity.levelID == selected.id
            })?.identity else { return }
      self.updatePlaylist(
        playlistID,
        replacing: entryID,
        with: identity,
        editorPage: editorPage)
    }
    primary.keyEquivalent = "\r"
    primary.keyEquivalentModifierMask = []
    page.preferControllerControl(primary)
    page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
    carousel.onSelectionChanged = { [weak primary] item in
      primary?.isEnabled = item.isAvailable
      primary?.needsDisplay = true
    }
    carousel.onStart = { [weak primary] _ in primary?.performClick(nil) }
    let items = pack.levels.enumerated().map { index, entry in
      LevelCoverFlowItem(
        id: entry.identity.levelID,
        title: entry.levelName,
        subtitle: entry.packName + " / " + entry.identity.engine.displayName,
        detail: "Level \(entry.number)  \(index + 1)/\(pack.levels.count)",
        artworkKey: levelPreviewRequests[entry.identity]?.artworkKey,
        availability: entry.availability)
    }
    configureLevelPreviewLoader(carousel)
    carousel.configure(
      items: items,
      reduceMotion: settings.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    primary.isEnabled = carousel.selectedItem?.isAvailable == true
    GameScreen.shared.present(page, owner: window, focus: carousel)
  }

  private func updatePlaylist(
    _ playlistID: UUID,
    replacing entryID: UUID?,
    with identity: LevelCatalogueIdentity,
    editorPage: GameMenuPage,
    validatesFanSource: Bool = true
  ) {
    if validatesFanSource, levelBrowserFanPacks[identity.packID] != nil {
      ensureFanPacksResolved(
        forPackIDs: [identity.packID],
        title: "Save playlist",
        reloadResolved: true
      ) { [weak self, weak editorPage] failures in
        guard let self, let editorPage else { return }
        guard !failures.contains(identity.packID) else {
          GameScreen.shared.message(
            "Playlist not changed",
            detail: "The fan level pack changed or could not be read.")
          return
        }
        self.updatePlaylist(
          playlistID,
          replacing: entryID,
          with: identity,
          editorPage: editorPage,
          validatesFanSource: false)
      }
      return
    }
    do {
      let store = try playlistStore()
      guard var playlist = store.playlist(id: playlistID) else {
        throw LevelPlaylistStore.Failure.missingPlaylist
      }
      let replacement = try playlistEntry(for: identity)
      if let entryID {
        guard let index = playlist.entries.firstIndex(where: { $0.id == entryID }) else {
          throw LevelPlaylistStore.Failure.missingPlaylist
        }
        _ = try playlist.remove(
          id: entryID, updatedAt: playlistMutationDate(playlist))
        try playlist.add(
          replacement, at: index, updatedAt: playlistMutationDate(playlist))
        playlistEntrySelections[playlistID] = replacement.id
      } else {
        try playlist.add(replacement, updatedAt: playlistMutationDate(playlist))
        playlistEntrySelections[playlistID] = replacement.id
      }
      try store.update(playlist)
      GameScreen.shared.dismiss(editorPage)
      presentPlaylistEditor(id: playlistID)
    } catch LevelPlaylistError.duplicateEntry {
      GameScreen.shared.message("Already in playlist", detail: "Choose a different level.")
    } catch {
      GameScreen.shared.message("Playlist not changed", detail: error.localizedDescription)
    }
  }

  private func presentRandomPlaylistPool() {
    let page = GameMenuPage(title: "Random 10", subtitle: "Choose one level pack")
    let carousel = LevelCoverFlowView(frame: page.body.bounds)
    carousel.autoresizingMask = [.width, .height]
    page.body.addSubview(carousel)
    let primary = page.addPrimaryAction("Create") { [weak self, weak carousel, weak page] in
      guard let self, let page, let selected = carousel?.selectedItem,
            let pack = self.levelCatalogue.packs.first(where: {
              self.browserPackKey($0) == selected.id
            }) else { return }
      self.ensureFanPacksResolved(
        forPackIDs: [pack.id],
        title: pack.name,
        reloadResolved: self.levelBrowserFanPacks[pack.id] != nil
      ) { [weak self, weak page] _ in
        guard let self, let page,
              let resolved = self.levelCatalogue.packs.first(where: {
                $0.engine == pack.engine && $0.id == pack.id
              }) else { return }
        self.createRandomPlaylist(from: resolved, poolPage: page)
      }
    }
    primary.keyEquivalent = "\r"
    primary.keyEquivalentModifierMask = []
    page.preferControllerControl(primary)
    page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
    carousel.onSelectionChanged = { [weak primary] item in
      primary?.isEnabled = item.isAvailable
      primary?.needsDisplay = true
    }
    carousel.onStart = { [weak primary] _ in primary?.performClick(nil) }
    let items = levelCatalogue.packs.enumerated().map { index, pack in
      let fanURL = levelBrowserFanPacks[pack.id]
      let count = fanURL.flatMap { FanLevelLibrary.knownLevelCount(in: $0) }
        ?? pack.availableLevelCount
      return LevelCoverFlowItem(
        id: browserPackKey(pack),
        title: pack.name,
        subtitle: pack.engine.displayName + " / " + pack.status.displayName,
        detail: "\(count == 0 && fanURL != nil ? "Levels" : "\(count) eligible")  \(index + 1)/\(levelCatalogue.packs.count)",
        isAvailable: fanURL != nil || count > 0,
        artworkKey: pack.levels.lazy.compactMap {
          self.levelPreviewRequests[$0.identity]?.artworkKey
        }.first)
    }
    configureLevelPreviewLoader(carousel)
    carousel.configure(
      items: items,
      reduceMotion: settings.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    GameScreen.shared.present(page, owner: window, focus: carousel)
  }

  private func createRandomPlaylist(
    from pack: LevelCataloguePack,
    poolPage: GameMenuPage
  ) {
    do {
      let store = try playlistStore()
      let candidates = try pack.levels.filter(\.isAvailable).map {
        try playlistEntry(for: $0.identity)
      }
      guard !candidates.isEmpty else { throw LevelPlaylistError.emptyPool }
      let playlist = try LevelPlaylist.randomTen(
        name: nextPlaylistName(prefix: "Random 10", store: store),
        candidates: candidates,
        seed: UInt64.random(in: UInt64.min...UInt64.max))
      try store.add(playlist)
      playlistLibrarySelection = "playlist:saved:\(playlist.id.uuidString)"
      GameScreen.shared.dismiss(poolPage)
      presentPlaylistEditor(id: playlist.id)
    } catch {
      GameScreen.shared.message("Random playlist not created", detail: error.localizedDescription)
    }
  }

  private func ensureFanPacksResolved(
    for entries: [LevelPlaylistEntry],
    title: String,
    completion: @escaping @MainActor (Set<String>) -> Void
  ) {
    let packIDs = Set(entries.map(\.identity.packID).filter {
      levelBrowserFanPacks[$0] != nil
    })
    ensureFanPacksResolved(
      forPackIDs: packIDs,
      title: title,
      reloadResolved: true,
      completion: completion)
  }

  private func invalidateResolvedFanPack(id: String) {
    guard let packIndex = levelCatalogue.packs.firstIndex(where: { $0.id == id }) else {
      return
    }
    let pack = levelCatalogue.packs[packIndex]
    for identity in pack.levels.map(\.identity) {
      levelBrowserRoutes[identity] = nil
      levelPreviewRequests[identity] = nil
    }
    levelBrowserFanEntries[id] = nil
    levelBrowserInvalidFanPacks.insert(id)
    if let url = levelBrowserFanPacks[id] {
      levelBrowserInvalidFanPackRevisions[id] = Self.fanPackFileRevision(url)
      FanLevelLibrary.Progress.removeCount(for: url)
    }
    var packs = levelCatalogue.packs
    packs[packIndex] = LevelCataloguePack(
      engine: pack.engine,
      id: pack.id,
      name: pack.name,
      status: pack.status,
      levels: [])
    levelCatalogue = LevelCatalogue(revision: levelCatalogue.revision, packs: packs)
    refreshOpenLevelPackBrowser()
  }

  private func cancelPlaylistFanLoading() {
    playlistFanLoadTask?.cancel()
    playlistFanDiscoveryTask?.cancel()
    playlistFanLoadTask = nil
    playlistFanDiscoveryTask = nil
    if let page = playlistFanLoadingPage {
      playlistFanLoadingPage = nil
      if GameScreen.shared.contains(page) { GameScreen.shared.dismiss(page) }
    }
  }

  private func ensureFanPacksResolved(
    forPackIDs packIDs: Set<String>,
    title: String,
    reloadResolved: Bool = false,
    completion: @escaping @MainActor (Set<String>) -> Void
  ) {
    let requests = packIDs.sorted().compactMap { packID -> (String, URL)? in
      guard (reloadResolved
              || levelCatalogue.packs.first(where: { $0.id == packID })?.levels.isEmpty == true),
            let url = levelBrowserFanPacks[packID] else { return nil }
      return (packID, url)
    }
    guard !requests.isEmpty else {
      completion([])
      return
    }

    playlistFanLoadTask?.cancel()
    playlistFanDiscoveryTask?.cancel()
    if let oldPage = playlistFanLoadingPage {
      playlistFanLoadingPage = nil
      GameScreen.shared.dismiss(oldPage)
    }
    let page = GameMenuPage(title: title, subtitle: "Loading fan levels")
    page.setDetail("Reading \(requests.count) fan \(requests.count == 1 ? "pack" : "packs").")
    page.backTitle = "Cancel"
    playlistFanLoadingPage = page
    page.onBack = { [weak self, weak page] in
      guard let self, let page, self.playlistFanLoadingPage === page else { return }
      self.playlistFanLoadTask?.cancel()
      self.playlistFanDiscoveryTask?.cancel()
      self.playlistFanLoadTask = nil
      self.playlistFanDiscoveryTask = nil
      self.playlistFanLoadingPage = nil
      GameScreen.shared.dismiss(page)
    }
    GameScreen.shared.present(page, owner: window, onDismiss: { [weak self, weak page] in
      guard let self, let page, self.playlistFanLoadingPage === page else { return }
      self.playlistFanLoadTask?.cancel()
      self.playlistFanDiscoveryTask?.cancel()
      self.playlistFanLoadTask = nil
      self.playlistFanDiscoveryTask = nil
      self.playlistFanLoadingPage = nil
    })
    let discoveryTask = Task.detached(priority: .userInitiated) {
      () -> ([LevelBrowserFanPackDiscovery], Set<String>) in
      var discoveries: [LevelBrowserFanPackDiscovery] = []
      var failures: Set<String> = []
      discoveries.reserveCapacity(requests.count)
      for (packID, url) in requests {
        guard !Task.isCancelled else { return (discoveries, failures) }
        guard let before = FanLevelLibrary.archiveFingerprint(url) else {
          failures.insert(packID)
          continue
        }
        let entries: [FanLevelLibrary.Entry]
        do {
          entries = try FanLevelLibrary.validatedEntries(in: url)
        } catch {
          failures.insert(packID)
          continue
        }
        guard !Task.isCancelled,
              let after = FanLevelLibrary.archiveFingerprint(url),
              before == after else {
          failures.insert(packID)
          continue
        }
        discoveries.append(LevelBrowserFanPackDiscovery(
          packID: packID,
          fingerprint: before,
          entries: entries))
      }
      return (discoveries, failures)
    }
    playlistFanDiscoveryTask = discoveryTask
    playlistFanLoadTask = Task { [weak self, weak page] in
      let (discoveries, failures) = await discoveryTask.value
      guard !Task.isCancelled, let self, let page,
            self.playlistFanLoadingPage === page,
            GameScreen.shared.controllerPage(in: self.window) === page,
            self.window.attachedSheet == nil else { return }
      self.playlistFanLoadTask = nil
      self.playlistFanDiscoveryTask = nil
      self.playlistFanLoadingPage = nil
      GameScreen.shared.dismiss(page)
      for packID in failures {
        self.invalidateResolvedFanPack(id: packID)
      }
      for discovery in discoveries {
        guard let pack = self.levelCatalogue.packs.first(where: {
          $0.id == discovery.packID
        }), let url = self.levelBrowserFanPacks[discovery.packID] else { continue }
        FanLevelLibrary.Progress.setCount(discovery.entries.count, for: url)
        _ = self.resolveBrowserPack(
          pack,
          discovery: LevelBrowserFanDiscovery(
            fingerprint: discovery.fingerprint,
            entries: discovery.entries))
      }
      completion(failures)
    }
  }

  private func prepareShuffleAllFanLevels() {
    let packIDs = Set(levelBrowserFanPacks.keys)
    guard !packIDs.isEmpty else {
      GameScreen.shared.message("Shuffle all", detail: "No fan level packs are available.")
      return
    }
    ensureFanPacksResolved(
      forPackIDs: packIDs,
      title: "Shuffle all",
      reloadResolved: true
    ) { [weak self] failures in
      guard let self else { return }
      guard failures.isEmpty else {
        let names = failures.compactMap { id in
          self.levelCatalogue.packs.first(where: { $0.id == id })?.name
        }.sorted().joined(separator: ", ")
        GameScreen.shared.message(
          "Shuffle not started",
          detail: "Could not read every installed fan pack. Check \(names.isEmpty ? "the unavailable packs" : names) and try again.")
        return
      }
      self.confirmShuffleAllFanLevels()
    }
  }

  private func confirmShuffleAllFanLevels() {
    do {
      let input = try shuffleAllRunInput()
      GameScreen.shared.confirm(
        "Shuffle all",
        detail: input.summary + ". Each level appears once before the run ends.",
        actionTitle: "Start shuffle") { [weak self] in
          self?.startConfirmedShuffleAllFanLevels(
            expectedPoolID: input.pool.id)
        }
    } catch {
      GameScreen.shared.message("Shuffle not started", detail: error.localizedDescription)
    }
  }

  private func shuffleAllRunInput() throws -> (
    candidates: [LevelPlaylistEntry],
    pool: LevelPool,
    summary: String
  ) {
    var candidates: [LevelPlaylistEntry] = []
    for pack in levelCatalogue.packs where levelBrowserFanPacks[pack.id] != nil {
      for entry in pack.levels where entry.isAvailable {
        candidates.append(try playlistEntry(for: entry.identity))
      }
    }
    guard !candidates.isEmpty else { throw LevelPlaylistError.emptyPool }
    let signature = candidates.sorted {
      $0.identity.packID + "\u{0}" + $0.identity.levelID
        < $1.identity.packID + "\u{0}" + $1.identity.levelID
    }.map {
      $0.identity.packID + "\u{0}" + $0.identity.levelID + "\u{0}" + $0.sourceRevision
    }.joined(separator: "\u{1f}")
    let poolID = "fan-all:" + ArcadeStore.fingerprint(Data(signature.utf8))
    let packCount = Set(candidates.map(\.identity.packID)).count
    let summary = "All eligible fan levels - \(candidates.count) levels from \(packCount) packs"
    return (candidates, try LevelPool(id: poolID, summary: summary), summary)
  }

  private func startConfirmedShuffleAllFanLevels(expectedPoolID: String) {
    let packIDs = Set(levelBrowserFanPacks.keys)
    guard !packIDs.isEmpty else {
      GameScreen.shared.message("Shuffle not started", detail: "No fan level packs are available.")
      return
    }
    ensureFanPacksResolved(
      forPackIDs: packIDs,
      title: "Shuffle all",
      reloadResolved: true
    ) { [weak self] failures in
      guard let self else { return }
      guard failures.isEmpty else {
        GameScreen.shared.message(
          "Shuffle not started",
          detail: "A fan level pack changed or could not be read.")
        return
      }
      do {
        let input = try self.shuffleAllRunInput()
        guard input.pool.id == expectedPoolID else {
          self.confirmShuffleAllFanLevels()
          return
        }
        let run = try LevelSequenceRun.fullShuffle(
          from: input.candidates,
          pool: input.pool,
          seed: UInt64.random(in: UInt64.min...UInt64.max))
        self.installActiveSequence(run, in: try self.playlistStore())
      } catch {
        GameScreen.shared.message("Shuffle not started", detail: error.localizedDescription)
      }
    }
  }

  private func startActiveSequence() {
    guard !ArcadeStore.shared.hotSeatIsActive else {
      GameScreen.shared.message(
        "Playlist unavailable",
        detail: "End Hot Seat before starting or resuming this run.")
      return
    }
    do {
      let store = try playlistStore()
      guard let run = store.activeRun else { return }
      switch playlistResolution(for: run.currentEntry) {
      case .available:
        sequencePlaylistStore = store
        startBrowserLevel(run.currentEntry.identity, sequenceRunID: run.id)
      case .locked:
        GameScreen.shared.message(
          "Run paused",
          detail: "\(run.currentEntry.levelNameSnapshot) is locked for this player.")
      case .unavailable:
        presentInvalidSequenceEntry(run, reason: "is not available")
      case .changed:
        presentInvalidSequenceEntry(run, reason: "changed after this run was created")
      case .missing:
        presentInvalidSequenceEntry(run, reason: "is missing")
      }
    } catch {
      GameScreen.shared.message("Run unavailable", detail: error.localizedDescription)
    }
  }

  private func presentInvalidSequenceEntry(_ run: LevelSequenceRun, reason: String) {
    GameScreen.shared.confirm(
      "Run paused",
      detail: "\(run.currentEntry.levelNameSnapshot) \(reason). No replacement was chosen.",
      actionTitle: "Discard run") { [weak self] in
        guard let self else { return }
        do {
          try self.playlistStore().setActiveRun(nil)
          self.setSequencePlayingIdentity(nil)
          self.presentPlaylistLibrary()
        } catch {
          GameScreen.shared.message("Run not discarded", detail: error.localizedDescription)
        }
      }
  }

  @discardableResult
  private func continueActiveSequence(
    completed identity: LevelCatalogueIdentity,
    runID: UUID
  ) -> Bool {
    do {
      let store = try sequencePlaylistStore ?? playlistStore()
      guard let run = store.activeRun,
            run.id == runID,
            run.currentEntry.identity == identity else { return false }
      if try store.advanceActiveRun(), let next = store.activeRun {
        returnToLibrary()
        sequencePlaylistStore = store
        startBrowserLevel(next.currentEntry.identity, sequenceRunID: runID)
      } else {
        try store.setActiveRun(nil)
        returnToLibrary()
        presentPlaylistLibrary()
        GameScreen.shared.message(
          "Run complete",
          detail: "Finished \(run.entries.count) \(run.entries.count == 1 ? "level" : "levels") from \(run.pool.summary).")
      }
      return true
    } catch {
      GameScreen.shared.message("Run could not continue", detail: error.localizedDescription)
      return true
    }
  }

  private func continuePlayingSequenceIfNeeded() -> Bool {
    guard let identity = sequencePlayingIdentity,
          let run = sequencePlaylistStore?.activeRun,
          session?.didWin == true else { return false }
    return continueActiveSequence(completed: identity, runID: run.id)
  }

  nonisolated private static func prepareClassicBrowserLevel(
    directory: URL,
    dataSet: ClassicDataSet,
    levelIndex: Int,
    expectedFingerprint: String?
  ) -> LevelBrowserClassicPreparation {
    do {
      try Task.checkCancellation()
      if let expectedFingerprint,
         FanLevelLibrary.directoryFingerprint(directory) != expectedFingerprint {
        return .failed("The imported game data changed. Open Level Select and choose the level again.")
      }
      guard dataSet.campaign.levels.indices.contains(levelIndex) else {
        return .failed("The selected level is no longer available.")
      }
      let campaignLevel = dataSet.campaign.levels[levelIndex]
      let prepared: PreparedClassicArtwork
      if dataSet.title == .ohYesMoreLemmings {
        prepared = try readPortArtwork(
          campaignLevel, dataSet: dataSet, portsRoot: directory)
      } else {
        prepared = try readClassicArtwork(
          directory: directory,
          styles: dataSet.groundStyles,
          specialIndices: dataSet.specialIndices)
      }
      try Task.checkCancellation()
      guard let ground = prepared.grounds[campaignLevel.level.groundStyle] else {
        return .failed("The selected level's graphics style is missing.")
      }
      let rendered = try ClassicLevelRenderer.render(
        campaignLevel.level,
        groundSet: ground,
        specialGraphic: prepared.specials[campaignLevel.level.specialStyle])
      _ = try ClassicDOSSimulation(
        level: campaignLevel.level,
        renderedLevel: rendered,
        mainDATAssets: prepared.assets,
        mechanics: ClassicDOSMechanics(title: dataSet.title, rank: campaignLevel.rank))
      try Task.checkCancellation()
      if let expectedFingerprint,
         FanLevelLibrary.directoryFingerprint(directory) != expectedFingerprint {
        return .failed("The imported game data changed. Open Level Select and choose the level again.")
      }
      return .ready(prepared)
    } catch is CancellationError {
      return .failed("The level load was cancelled.")
    } catch {
      return .failed("The selected game data could not load: \(error)")
    }
  }

  nonisolated private static func prepareFanBrowserLevel(
    pack: URL,
    entry: FanLevelLibrary.Entry,
    packName: String,
    expectedFingerprint: String,
    portsRoot: URL
  ) -> LevelBrowserFanPreparation {
    do {
      try Task.checkCancellation()
      guard FanLevelLibrary.archiveMatches(pack, fingerprint: expectedFingerprint) else {
        return .failed("The selected archive changed. Open Level Select and choose the level again.")
      }
      let (level, styleName) = try FanLevelLibrary.level(entry, in: pack)
      let ground = try FanLevelLibrary.groundSet(
        for: level,
        styleName: styleName,
        portsRoot: portsRoot,
        pack: pack,
        entry: entry)
      let special = try FanLevelLibrary.specialGraphic(
        for: level, entry: entry, pack: pack, portsRoot: portsRoot)
      let assets = try ClassicMainDATAssets.load(
        from: portsRoot.appendingPathComponent("lemmings_dos_1991-07-30"))
      let rendered = try ClassicLevelRenderer.render(
        level, groundSet: ground, specialGraphic: special)
      _ = try ClassicDOSSimulation(
        level: level,
        renderedLevel: rendered,
        mainDATAssets: assets,
        mechanics: ClassicDOSMechanics(title: nil, rank: packName))
      try Task.checkCancellation()
      guard FanLevelLibrary.archiveMatches(pack, fingerprint: expectedFingerprint) else {
        return .failed("The selected archive changed. Open Level Select and choose the level again.")
      }
      return .ready(PreparedFanLevel(
        level: level, ground: ground, special: special, assets: assets))
    } catch is CancellationError {
      return .failed("The level load was cancelled.")
    } catch {
      return .failed("The selected fan level could not load: \(error)")
    }
  }

  private func levelBrowserLaunchLoadingPage(
    title: String,
    sequenceRunID: UUID?
  ) -> (GameMenuPage, UUID) {
    levelBrowserLaunchTask?.cancel()
    levelBrowserLaunchTask = nil
    levelBrowserLaunchID = nil
    if let oldPage = levelBrowserLaunchPage {
      levelBrowserLaunchPage = nil
      GameScreen.shared.dismiss(oldPage)
    }
    let page = GameMenuPage(title: title)
    page.setDetail("Loading the selected level.")
    page.backTitle = "Cancel"
    let launchID = UUID()
    levelBrowserLaunchPage = page
    levelBrowserLaunchID = launchID
    page.onBack = { [weak self, weak page] in
      guard let self, let page, self.levelBrowserLaunchID == launchID,
            self.levelBrowserLaunchPage === page else { return }
      self.levelBrowserLaunchTask?.cancel()
      self.levelBrowserLaunchTask = nil
      self.levelBrowserLaunchPage = nil
      self.levelBrowserLaunchID = nil
      self.clearSequenceLaunch(sequenceRunID)
      GameScreen.shared.dismiss(page)
    }
    GameScreen.shared.present(page, owner: window, onDismiss: { [weak self, weak page] in
      guard let self, let page, self.levelBrowserLaunchID == launchID,
            self.levelBrowserLaunchPage === page else { return }
      self.levelBrowserLaunchTask?.cancel()
      self.levelBrowserLaunchTask = nil
      self.levelBrowserLaunchPage = nil
      self.levelBrowserLaunchID = nil
      self.clearSequenceLaunch(sequenceRunID)
    })
    return (page, launchID)
  }

  private func startBrowserLevel(
    _ identity: LevelCatalogueIdentity,
    sequenceRunID: UUID? = nil
  ) {
    if let sequenceRunID {
      let sequenceStore = sequencePlaylistStore ?? (try? playlistStore())
      guard let run = sequenceStore?.activeRun,
            run.id == sequenceRunID,
            run.currentEntry.identity == identity else {
        GameScreen.shared.message(
          "Run unavailable",
          detail: "The saved sequence changed before this level started.")
        return
      }
    }
    guard let entry = levelCatalogue.resolve(identity),
          let route = levelBrowserRoutes[identity] else {
      GameScreen.shared.message("Level unavailable", detail: "The selected catalogue entry changed. Open Level Select and choose it again.")
      return
    }
    let canStart = entry.isAvailable || {
      guard settings.unlockAllClassicLevels,
            case .classic = route else { return false }
      return true
    }()
    guard canStart else {
      GameScreen.shared.message(entry.levelName, detail: "Complete the preceding level or choose an available level.")
      return
    }
    switch route {
    case let .classic(
      dataSetDirectory, browserDataSet, levelIndex, _, sourceRevision):
      guard settings.unlockAllClassicLevels
              || classicBrowserLevelIsUnlocked(
                dataSet: browserDataSet,
                directory: dataSetDirectory,
                levelIndex: levelIndex) else {
        GameScreen.shared.message(entry.levelName,
          detail: "Complete the preceding level, or enable Unlock all Classic levels in Settings.")
        return
      }
      guard let dataSetIndex = dataSets.firstIndex(where: {
              $0.directory.standardizedFileURL == dataSetDirectory.standardizedFileURL
            }),
            browserDataSet.campaign.levels.indices.contains(levelIndex) else {
        GameScreen.shared.message(entry.levelName, detail: "The selected game data is no longer available.")
        return
      }
      guard beginSequenceLaunch(runID: sequenceRunID, identity: identity) else { return }
      let (_, launchID) = levelBrowserLaunchLoadingPage(
        title: entry.levelName,
        sequenceRunID: sequenceRunID)
      levelBrowserLaunchTask = Task.detached(priority: .userInitiated) { [weak self] in
        let preparation = Self.prepareClassicBrowserLevel(
          directory: dataSetDirectory,
          dataSet: browserDataSet,
          levelIndex: levelIndex,
          expectedFingerprint: sourceRevision)
        guard !Task.isCancelled else { return }
        await MainActor.run {
          guard let self, self.levelBrowserLaunchID == launchID,
                let loadingPage = self.levelBrowserLaunchPage,
                GameScreen.shared.controllerPage(in: self.window) === loadingPage,
                self.window.attachedSheet == nil else { return }
          self.levelBrowserLaunchTask = nil
          self.levelBrowserLaunchID = nil
          self.levelBrowserLaunchPage = nil
          GameScreen.shared.dismiss(loadingPage)
          switch preparation {
          case let .failed(message):
            self.clearSequenceLaunch(sequenceRunID)
            GameScreen.shared.message(entry.levelName, detail: message)
          case let .ready(prepared):
            self.commitClassicBrowserLevel(
              identity: identity,
              entry: entry,
              dataSetDirectory: dataSetDirectory,
              browserDataSet: browserDataSet,
              dataSetIndex: dataSetIndex,
              levelIndex: levelIndex,
              preparedArtwork: prepared,
              sequenceRunID: sequenceRunID)
          }
        }
      }
    case let .fan(pack, fanEntry, archiveFingerprint):
      guard let portsRoot = Bundle.main.resourceURL?.appendingPathComponent("Ports") else {
        GameScreen.shared.message(entry.levelName,
          detail: "The Classic graphics library is not available.")
        return
      }
      guard beginSequenceLaunch(runID: sequenceRunID, identity: identity) else { return }
      let (_, launchID) = levelBrowserLaunchLoadingPage(
        title: entry.levelName,
        sequenceRunID: sequenceRunID)
      levelBrowserLaunchTask = Task.detached(priority: .userInitiated) { [weak self] in
        let preparation = Self.prepareFanBrowserLevel(
          pack: pack,
          entry: fanEntry,
          packName: entry.packName,
          expectedFingerprint: archiveFingerprint,
          portsRoot: portsRoot)
        guard !Task.isCancelled else { return }
        await MainActor.run {
          guard let self, self.levelBrowserLaunchID == launchID,
                let loadingPage = self.levelBrowserLaunchPage,
                GameScreen.shared.controllerPage(in: self.window) === loadingPage,
                self.window.attachedSheet == nil else { return }
          self.levelBrowserLaunchTask = nil
          self.levelBrowserLaunchID = nil
          self.levelBrowserLaunchPage = nil
          GameScreen.shared.dismiss(loadingPage)
          switch preparation {
          case let .failed(message):
            self.clearSequenceLaunch(sequenceRunID)
            GameScreen.shared.message(entry.levelName, detail: message)
          case let .ready(prepared):
            self.commitFanBrowserLevel(
              identity: identity,
              entry: entry,
              pack: pack,
              fanEntry: fanEntry,
              archiveFingerprint: archiveFingerprint,
              prepared: prepared,
              sequenceRunID: sequenceRunID)
          }
        }
      }
    case let .lemmings2(root, selection, expectedLevelID, sourceRevision):
      guard beginSequenceLaunch(runID: sequenceRunID, identity: identity) else { return }
      saveRunCheckpoint(immediately: true)
      if openNativeL2(
        root,
        selection: selection,
        expectedLevelID: expectedLevelID,
        expectedSourceRevision: sourceRevision,
        sequenceRunID: sequenceRunID,
        sequenceIdentity: sequenceRunID == nil ? nil : identity) {
        if sequenceRunID == nil {
          setSequencePlayingIdentity(nil)
          sequencePlaylistStore = nil
        } else { clearSequenceLaunch(sequenceRunID) }
        launchMode = .singleTitle
      } else { clearSequenceLaunch(sequenceRunID) }
    case let .lemmings3(root, selection, expectedLevelID, sourceRevision):
      guard beginSequenceLaunch(runID: sequenceRunID, identity: identity) else { return }
      saveRunCheckpoint(immediately: true)
      if openNativeL3(
        root,
        selection: selection,
        expectedLevelID: expectedLevelID,
        expectedSourceRevision: sourceRevision,
        sequenceRunID: sequenceRunID,
        sequenceIdentity: sequenceRunID == nil ? nil : identity) {
        if sequenceRunID == nil {
          setSequencePlayingIdentity(nil)
          sequencePlaylistStore = nil
        } else { clearSequenceLaunch(sequenceRunID) }
        launchMode = .singleTitle
      } else { clearSequenceLaunch(sequenceRunID) }
    }
  }

  private func classicBrowserLevelIsUnlocked(
    dataSet: ClassicDataSet,
    directory: URL,
    levelIndex: Int
  ) -> Bool {
    var browserFlow = ClassicGameFlow(campaign: dataSet.campaign)
    if let data = savedClassicProgressData(for: (set: dataSet, directory: directory)),
       let saved = try? JSONDecoder().decode(ClassicGameFlow.Progress.self, from: data) {
      browserFlow.restore(dataSet.migrateProgress(saved))
    }
    return browserFlow.isLevelUnlocked(levelIndex)
  }

  private func commitClassicBrowserLevel(
    identity: LevelCatalogueIdentity,
    entry: LevelCatalogueEntry,
    dataSetDirectory: URL,
    browserDataSet: ClassicDataSet,
    dataSetIndex: Int,
    levelIndex: Int,
    preparedArtwork: PreparedClassicArtwork,
    sequenceRunID: UUID?
  ) {
    guard levelCatalogue.resolve(identity) == entry,
          dataSets.indices.contains(dataSetIndex),
          dataSets[dataSetIndex].directory.standardizedFileURL
            == dataSetDirectory.standardizedFileURL,
          browserDataSet.campaign.levels.indices.contains(levelIndex) else {
      clearSequenceLaunch(sequenceRunID)
      GameScreen.shared.message(entry.levelName,
        detail: "The selected game data is no longer available.")
      return
    }
    guard sequenceLaunchCanCommit(runID: sequenceRunID, identity: identity) else { return }
    saveRunCheckpoint(immediately: true)
    if sequelIsActive || fanPlaying || fanScreen != .off { returnToLibrary() }
    else { GameScreen.shared.dismissAll() }
    if sequenceRunID == nil {
      setSequencePlayingIdentity(nil)
      sequencePlaylistStore = nil
    }
    gamePicker.selectItem(at: dataSetIndex)
    do {
      try applyDataSetSelection(
        at: dataSetIndex,
        using: (set: browserDataSet, directory: dataSetDirectory),
        preparedArtwork: preparedArtwork)
    } catch {
      clearSequenceLaunch(sequenceRunID)
      GameScreen.shared.message(entry.levelName,
        detail: "The selected game data could not load: \(error)")
      return
    }
    activeTitle = browserDataSet.title
    launchMode = .singleTitle
    picker.selectItem(at: levelIndex)
    if let sequenceRunID {
      setSequencePlayingIdentity(identity)
      clearSequenceLaunch(sequenceRunID)
    }
    levelChanged()
  }

  private func commitFanBrowserLevel(
    identity: LevelCatalogueIdentity,
    entry: LevelCatalogueEntry,
    pack: URL,
    fanEntry: FanLevelLibrary.Entry,
    archiveFingerprint: String,
    prepared: PreparedFanLevel,
    sequenceRunID: UUID?
  ) {
    guard levelCatalogue.resolve(identity) == entry,
          case let .fan(currentPack, currentEntry, currentFingerprint)? = levelBrowserRoutes[identity],
          currentPack.standardizedFileURL == pack.standardizedFileURL,
          currentEntry.file == fanEntry.file,
          currentEntry.section == fanEntry.section,
          currentFingerprint == archiveFingerprint else {
      clearSequenceLaunch(sequenceRunID)
      GameScreen.shared.message(entry.levelName,
        detail: "The selected catalogue entry changed. Open Level Select and choose it again.")
      return
    }
    guard sequenceLaunchCanCommit(runID: sequenceRunID, identity: identity) else { return }
    saveRunCheckpoint(immediately: true)
    let previousLaunchMode = launchMode
    returnToLibrary()
    if sequenceRunID == nil {
      setSequencePlayingIdentity(nil)
      sequencePlaylistStore = nil
    }
    fanPack = pack
    fanEntries = levelBrowserFanEntries[identity.packID] ?? [fanEntry]
    fanChoice = (fanEntries.firstIndex {
      $0.file == fanEntry.file && $0.section == fanEntry.section
    } ?? 0) + 2
    fanScreen = .levels
    launchMode = .singleTitle
    if let sequenceRunID {
      setSequencePlayingIdentity(identity)
      clearSequenceLaunch(sequenceRunID)
    }
    startFanRun([fanEntry], prepared: prepared)
    if !fanPlaying {
      setSequencePlayingIdentity(nil)
      launchMode = previousLaunchMode
    }
  }

  // MARK: - Unofficial levels

  /// The home screen's fan content row.
  ///
  /// The total counts only the packs measured so far, because measuring means
  /// opening every archive. While that is still running the row says so rather
  /// than showing a total that keeps changing under the player.
  private func fanHomeRow() -> String {
    let packs = fanPacks.isEmpty ? FanLevelLibrary.packs() : fanPacks
    let imported = dataSets.filter {
      $0.set.kind == .scanned && $0.set.title != .ohYesMoreLemmings
    }.reduce(
      into: (passed: 0, total: 0)
    ) { result, entry in
      var savedFlow = ClassicGameFlow(campaign: entry.set.campaign)
      if let data = savedClassicProgressData(for: entry),
         let saved = try? JSONDecoder().decode(
          ClassicGameFlow.Progress.self, from: data) {
        savedFlow.restore(entry.set.migrateProgress(saved))
      }
      result.total += entry.set.campaign.levels.count
      result.passed += savedFlow.ranks.reduce(0) {
        $0 + savedFlow.passedCount(inRank: $1.name)
      }
    }
    guard !packs.isEmpty || imported.total > 0 else {
      return "FAN LEMMINGS  — NO PACKS"
    }
    let passed = FanLevelLibrary.Progress.passedCount(for: packs) + imported.passed
    let total = FanLevelLibrary.Progress.total(for: packs) + imported.total
    if FanLevelLibrary.Progress.isComplete(for: packs) {
      return "FAN LEMMINGS  \(passed)/\(total)"
    }
    return "FAN LEMMINGS  \(passed)/\(total)  — COUNTING"
  }

  private func homeContentRow(_ family: HomeContentFamily) -> String {
    if family == .fan { return fanHomeRow() }
    let installed = library.entries.filter {
      family.titles.contains($0.title) && $0.available
    }
    guard !installed.isEmpty else {
      return family.displayName.uppercased() + "  — NO DATA"
    }
    let passed = installed.reduce(0) { $0 + $1.passed }
    let total = installed.reduce(0) { $0 + $1.total }
    let preview = family == .lemmings2 || family == .lemmings3 ? "  — PREVIEW" : ""
    return "\(family.displayName.uppercased())  \(passed)/\(total)\(preview)"
  }

  private func homeMenuItems() -> [HomeMenuItem] {
    var items: [HomeMenuItem] = []
    if menuRecovery != nil {
      let initials = menuRecovery.flatMap {
        ArcadeStore.shared.records.profile($0.profileID)?.initials
      } ?? "LEM"
      items.append(HomeMenuItem(title: "RESUME - " + initials, action: .resume))
    }
    items.append(HomeMenuItem(
      title: "\(Self.allLemmingsMenuTitle)  \(library.passed)/\(library.total)",
      action: .fullQuest))
    items += HomeContentFamily.allCases.map {
      HomeMenuItem(title: homeContentRow($0), action: .browse($0))
    }
    return items
  }

  /// Measures any unmeasured packs, refreshing the front screen as it goes.
  private func measureFanPacks() {
    let packs = fanPacks.isEmpty ? FanLevelLibrary.packs() : fanPacks
    guard !packs.isEmpty, !FanLevelLibrary.Progress.isComplete(for: packs) else { return }
    FanLevelLibrary.Progress.measure(packs) { [weak self] in
      guard let self, self.flow?.screen == .title, self.fanScreen == .off,
        !self.fanPlaying else { return }
      self.renderScreen()
    }
  }

  private func startFanUpdates() {
    guard fanUpdateTask == nil else { return }
    fanPacks = FanLevelLibrary.packs()
    measureFanPacks()
    let existing = fanPacks, destination = FanLevelLibrary.downloadFolder
    fanUpdateTask = Task { [weak self] in
      let outcome = await FanLevelUpdates().check(existing: existing, destination: destination)
      guard let self else { return }
      FanLevelLibrary.Progress.mergeCounts(outcome.counts)
      self.fanUpdateStatus = outcome.status
      let selected = self.fanPacks.indices.contains(self.fanChoice) ? self.fanPacks[self.fanChoice] : nil
      self.fanPacks = FanLevelLibrary.packs()
      if self.fanScreen == .packs {
        self.fanChoice = selected.flatMap { self.fanPacks.firstIndex(of: $0) } ?? 0
        self.renderFanScreen()
      } else if self.flow?.screen == .title && self.fanScreen == .off && !self.fanPlaying {
        self.renderScreen()
      }
      self.measureFanPacks()
    }
  }

  /// Shows the fan level packs as a menu screen.
  @objc private func showFanLevels() {
    guard allowNavigationAwayFromSequence() else { return }
    fanPacks = FanLevelLibrary.packs()
    fanChoice = 0
    fanScreen = .packs
    renderScreen()
  }

  /// Adds an optional local folder alongside the automatic collection.
  @objc private func chooseFanFolder() {
    guard allowNavigationAwayFromSequence() else { return }
    Task { @MainActor in
      let panel = NSOpenPanel()
      panel.canChooseFiles = false
      panel.canChooseDirectories = true
      panel.message = "Choose the folder holding the level packs."
      guard let url = await GameScreen.shared.chooseFile(panel) else { return }
      UserDefaults.standard.set(url.path, forKey: FanLevelLibrary.folderKey)
      showFanLevels()
    }
  }

  /// Draws whichever fan screen is showing.
  private func renderFanScreen() {
    playfield.overlayShowsSettingsButton = false
    phase = .briefing
    playfield.phase = .briefing
    playfield.overlayShowsLemmings = true

    let heading: String
    let rows: [String]
    switch fanScreen {
    case .off: return
    case .packs:
      heading = "FAN LEVELS"
      rows = fanPacks.map { FanLevelLibrary.displayName(of: $0).uppercased() }
    case .levels:
      heading = fanPack.map { FanLevelLibrary.displayName(of: $0).uppercased() } ?? "LEVELS"
      // Two ways to take the whole pack, then the levels themselves.
      // A passed level keeps a mark, so a long pack shows what is left.
      let pack = fanPack
      rows = ["PLAY ALL", "SHUFFLE"] + fanEntries.map { entry in
        let done = pack.map {
          FanLevelLibrary.Progress.hasPassed(pack: $0, label: entry.label)
        } ?? false
        return (done ? "* " : "") + entry.label.uppercased()
      }
    }

    if rows.isEmpty {
      fanWindowStart = 0
      playfield.overlayTitle = heading
      playfield.overlayLines = ["NOTHING HERE"]
      playfield.overlayHighlight = 0
    } else {
      // Keep the highlight near the middle of the window, so a long list
      // scrolls under the cursor rather than jumping a page at a time.
      let size = min(Self.fanRowsPerScreen, rows.count)
      fanWindowStart = max(0, min(fanChoice - size / 2, rows.count - size))
      playfield.overlayTitle = "\(heading)   \(fanChoice + 1)/\(rows.count)"
      playfield.overlayLines = Array(rows[fanWindowStart..<(fanWindowStart + size)])
      playfield.overlayHighlight = fanChoice - fanWindowStart
    }
    playfield.overlayFooter = fanScreen == .packs
      ? fanUpdateStatus + "  ·  ESC BACK" : "UP DOWN ENTER  *  ESC BACK"
    playfield.needsDisplay = true
  }

  /// Moves within a fan screen. Returns false when no fan screen is showing.
  private func moveFanChoice(_ delta: Int) -> Bool {
    guard fanScreen != .off else { return false }
    let count = fanScreen == .packs ? fanPacks.count : fanEntries.count + 2
    guard count > 0 else { return true }
    fanChoice = (fanChoice + delta + count) % count
    renderFanScreen()
    return true
  }

  /// Acts on the highlighted row. Returns false when no fan screen is showing.
  private func advanceFanScreen() -> Bool {
    switch fanScreen {
    case .off:
      return false
    case .packs:
      guard fanPacks.indices.contains(fanChoice) else { return true }
      let pack = fanPacks[fanChoice]
      fanPack = pack
      fanEntries = FanLevelLibrary.entries(in: pack)
      FanLevelLibrary.Progress.setCount(fanEntries.count, for: pack)
      fanChoice = 0
      fanScreen = .levels
      renderFanScreen()
      return true
    case .levels:
      guard fanPack != nil else { return true }
      switch fanChoice {
      case 0:
        startFanRun(fanEntries)
      case 1:
        startFanRun(fanEntries.shuffled())
      default:
        let index = fanChoice - 2
        guard fanEntries.indices.contains(index) else { return true }
        startFanRun([fanEntries[index]])
      }
      return true
    }
  }

  /// Starts a run of one or more fan levels.
  ///
  /// Checkpoints retain the chosen order. Completed levels keep their pack progress.
  private func startFanRun(
    _ entries: [FanLevelLibrary.Entry],
    prepared: PreparedFanLevel? = nil
  ) {
    guard !entries.isEmpty else { return }
    fanQueue = entries
    fanQueueIndex = 0
    fanScreen = .off
    loadCurrentFanLevel(prepared: prepared)
  }

  /// Builds the level the run is up to and shows its briefing.
  private func loadCurrentFanLevel(prepared: PreparedFanLevel? = nil) {
    guard let pack = fanPack, fanQueue.indices.contains(fanQueueIndex) else {
      endFanRun()
      return
    }
    let entry = fanQueue[fanQueueIndex]
    do {
      if !restoringCheckpoint { fanPackGraphics = true; fanTextSteel = true; fanLocalStyles = true; fanHolidayStyles = true }
      let level: ClassicLevel
      let ground: ClassicGroundSet
      let special: ClassicSpecialGraphic?
      let fanAssets: ClassicMainDATAssets
      if let prepared {
        level = prepared.level
        ground = prepared.ground
        special = prepared.special
        fanAssets = prepared.assets
      } else {
        let loaded = try FanLevelLibrary.level(
          entry, in: pack, includeTextSteel: fanTextSteel)
        level = loaded.0
        guard let ports = Bundle.main.resourceURL?.appendingPathComponent("Ports") else { return }
        ground = try FanLevelLibrary.groundSet(
          for: level,
          styleName: loaded.1,
          portsRoot: ports,
          pack: fanPackGraphics ? pack : nil,
          entry: entry,
          useLocalStyles: fanLocalStyles,
          useHolidayStyles: fanHolidayStyles)
        let directory = ports.appendingPathComponent("lemmings_dos_1991-07-30")
        if fanPackGraphics {
          special = try FanLevelLibrary.specialGraphic(
            for: level, entry: entry, pack: pack, portsRoot: ports)
        } else {
          special = level.specialStyle == 0 ? nil : try ClassicSpecialGraphic.load(
            index: level.specialStyle - 1, from: directory)
        }
        fanAssets = try ClassicMainDATAssets.load(from: directory)
      }
      let packName = FanLevelLibrary.displayName(of: pack)
      fanPlaying = true
      guard buildLevel(
        ClassicCampaignLevel.standalone(level, rank: packName), groundOverride: ground,
        specialOverride: special, assetsOverride: fanAssets) else {
        fanPlaying = false
        fanScreen = .levels
        renderFanScreen()
        return
      }
      showFanBriefing(title: level.title, pack: packName)
    } catch {
      setStatus("\(entry.label): \(error)")
      fanPlaying = false
      fanScreen = .levels
      renderFanScreen()
    }
  }

  /// The briefing before a fan level, which cannot use the campaign one
  /// because that reads the level's position in a run that does not exist.
  private func showFanBriefing(title: String, pack: String) {
    guard let session else { return }
    playfield.overlayShowsSettingsButton = false
    phase = .briefing
    playfield.phase = .briefing
    playfield.overlayShowsLemmings = false
    // The skill panel is collapsed to nothing while a menu is up, and only
    // `fitClassicDisplay` gives it its height back. A fan level skips the
    // usual redraw, so it has to ask for that itself or it plays with no
    // controls at all.
    panel.isMenuMode = false
    fitClassicDisplay()
    let percent = session.total > 0
      ? Int((Double(session.required) / Double(session.total) * 100).rounded()) : 0
    var lines = [
      "\(session.total) LEMMINGS",
      "SAVE \(session.required)  (\(percent)%)",
      "RELEASE RATE \(session.rate)",
    ]
    if fanQueue.count > 1 {
      lines.append("LEVEL \(fanQueueIndex + 1) OF \(fanQueue.count)")
    }
    playfield.overlayTitle = title.isEmpty ? pack.uppercased() : title.uppercased()
    playfield.overlayLines = lines
    playfield.overlayHighlight = nil
    playfield.overlayFooter = "ENTER TO START  *  ESC BACK"
    playfield.needsDisplay = true
    panel.needsDisplay = true
  }

  /// Shows how a fan level ended, and what happens next.
  private func showFanResults() {
    guard let session else { return }
    playfield.overlayShowsSettingsButton = false
    panel.isMenuMode = false
    let passed = session.saved >= session.required
    if passed, sequencePlayingIdentity == nil,
       let pack = fanPack, fanQueue.indices.contains(fanQueueIndex) {
      FanLevelLibrary.Progress.record(pack: pack, label: fanQueue[fanQueueIndex].label)
    }
    phase = .results
    playfield.phase = .results
    var lines = ["SAVED \(session.saved) OF \(session.required)"]
    let more = fanQueueIndex + 1 < fanQueue.count
    if sequencePlayingIdentity != nil, !passed {
      lines.append("ENTER TO RETRY LEVEL")
    } else {
      lines.append(more ? "ENTER FOR THE NEXT LEVEL" : "ENTER TO GO BACK")
    }
    playfield.overlayTitle = passed ? "LEVEL COMPLETE" : "NOT THIS TIME"
    playfield.overlayLines = lines
    playfield.overlayHighlight = nil
    playfield.overlayReplayLine = playfield.overlayLines.count
    playfield.overlayLines.append("V WATCH REPLAY  *  S SAVE MOVIE")
    playfield.overlayRetryLine = playfield.overlayLines.count
    playfield.overlayLines.append("R RETRY - SAVE MORE, USE LESS")
    playfield.overlayFooter = "ENTER  *  ESC BACK"
    playfield.needsDisplay = true
  }

  /// Enter, while a fan level is on screen. Returns false when none is.
  private func advanceFanPlay() -> Bool {
    guard fanPlaying else { return false }
    switch phase {
    case .briefing:
      phase = .playing
      playfield.phase = .playing
      playfield.overlayTitle = nil
      playfield.overlayLines = []
      playfield.overlayFooter = nil
      panel.isMenuMode = false
      fitClassicDisplay()
      effects.play(.levelStart)
      playfield.needsDisplay = true
      panel.needsDisplay = true
    case .results:
      if sequencePlayingIdentity != nil, session?.didWin != true {
        retry()
        return true
      }
      if continuePlayingSequenceIfNeeded() { return true }
      if fanQueueIndex + 1 < fanQueue.count {
        fanQueueIndex += 1
        loadCurrentFanLevel()
      } else {
        endFanRun()
      }
    case .playing:
      break
    }
    return true
  }

  /// Leaves a fan run and returns to the pack's level list.
  private func endFanRun() {
    if sequencePlayingIdentity != nil {
      returnToLibrary()
      return
    }
    saveRunCheckpoint(immediately: true)
    fanPlaying = false
    panel.isMenuMode = true
    fitClassicDisplay()
    fanQueue = []
    fanQueueIndex = 0
    fanScreen = .levels
    renderFanScreen()
  }

  /// Steps back out of the fan screens. Returns false when none is showing.
  private func retreatFanScreen() -> Bool {
    if fanPlaying {
      endFanRun()
      return true
    }
    switch fanScreen {
    case .off: return false
    case .levels:
      fanScreen = .packs
      fanChoice = fanPacks.firstIndex(where: { $0 == fanPack }) ?? 0
      renderFanScreen()
      return true
    case .packs:
      fanScreen = .off
      renderScreen()
      return true
    }
  }

  @objc private func chooseNxlvLevel() {
    guard allowNavigationAwayFromSequence() else { return }
    Task { @MainActor in
      let openPanel = NSOpenPanel()
      openPanel.canChooseFiles = true
      openPanel.canChooseDirectories = false
      openPanel.allowedFileTypes = ["nxlv"]
      openPanel.message = "Choose a NeoLemmix level file."
      guard let url = await GameScreen.shared.chooseFile(openPanel) else { return }
      if sequelIsActive { returnToLibrary() }
      loadNxlv(url)
    }
  }

  private func loadNxlv(_ url: URL) {
    // A NeoLemmix level draws every piece from a style pack, so the styles
    // directory must be known before the level can render.
    if stylesDirectory == nil {
      Task { @MainActor [weak self] in
        guard let self else { return }
        guard let styles = await self.pickDirectory("Choose the NeoLemmix 'styles' directory.") else {
          self.setStatus("A styles directory is needed to draw NeoLemmix levels.")
          return
        }
        self.stylesDirectory = styles
        UserDefaults.standard.set(styles.path, forKey: stylesPathKey)
        self.loadNxlv(url)
      }
      return
    }
    guard let stylesDirectory else { return }

    do {
      let text = try String(contentsOf: url, encoding: .utf8)
      guard let level = NxlvLevel(text: text) else {
        setStatus("Could not parse \(url.lastPathComponent).")
        return
      }
      let resolution = NxlvStyleResolver(stylesRootURL: stylesDirectory).resolve(level: level)
      let missing = resolution.diagnostics.filter { $0.severity == .error }
      guard resolution.isComplete else {
        setStatus("Missing style data: \(missing.first?.message ?? "unknown")")
        return
      }
      let result = NxlvRenderer().render(level: level, resolution: resolution)
      guard let rendered = result.renderedLevel, !result.hasErrors else {
        setStatus("Could not render \(url.lastPathComponent).")
        return
      }
      guard let image = makeImage(
        width: rendered.width, height: rendered.height, rgba: rendered.rgba)
      else { return }
      let simulation = try NeoLemmixSimulation(level: level, renderedLevel: rendered)

      returnToLibrary()
      flow = nil
      activeTitle = nil
      playfield.classicScene = nil
      playfield.macScene = nil
      playfield.macArtwork = nil
      panel.macArtwork = nil
      playfield.imageScale = 1
      playfield.levelImage = image
      currentNxlvURL = url
      adopt(
        NeoLemmixSession(
          simulation: simulation, width: rendered.width, height: rendered.height))
      phase = .playing; playfield.phase = .playing
      playfield.overlayTitle = nil; playfield.overlayLines = []; playfield.overlayFooter = nil
      panel.isMenuMode = false
      playfield.needsDisplay = true; panel.needsDisplay = true
      window.title = "Ultimate Lemmings — \(level.title)"
    } catch {
      setStatus("NeoLemmix error: \(error)")
    }
  }

  // MARK: - Session handling

  private func adopt(_ new: any GameSession) {
    saveRunCheckpoint(immediately: true)
    lastCheckpointTime = 0
    screenFlash.clear()
    assignmentFocus = AssignmentFocus()
    playfield.assignmentHighlight.clear()
    session = new
    checkpointFan = fanPlaying && new is ClassicSession && fanQueue.indices.contains(fanQueueIndex)
      ? FanRunRecovery(queue: fanQueue.map { .init(file: $0.file, section: $0.section, label: $0.label) }, index: fanQueueIndex,
          baseDataSetID: dataSets.indices.contains(gamePicker.indexOfSelectedItem)
            ? dataSetID(dataSets[gamePicker.indexOfSelectedItem]) : nil) : nil
    checkpointSourceURL = checkpointFan != nil ? fanPack : new is NeoLemmixSession ? currentNxlvURL : nil
    checkpointLocation = checkpointFan != nil ? ("fan-classic", fanQueueIndex)
      : !fanPlaying && currentNxlvURL == nil && dataSets.indices.contains(gamePicker.indexOfSelectedItem)
        ? (dataSetID(dataSets[gamePicker.indexOfSelectedItem]), picker.indexOfSelectedItem) : nil
    hintMap = playfield.levelImage
    let previousAttemptID = arcadeRunID
    arcadeRunID = UUID(); arcadeProfileID = ArcadeStore.shared.playingProfileID; arcadeHotSeatID = ArcadeStore.shared.hotSeatID; arcadeReport = nil
    let source = currentNxlvURL.flatMap { try? Data(contentsOf: $0) }
    let fingerprint = TrolleyCapture.sessionFingerprint(new, source: source)
    let gameID = fanPlaying || currentNxlvURL != nil ? "fan" : activeTitle?.rawValue ?? "lemmings"
    let packID = fanPlaying ? (fanPack?.lastPathComponent ?? "fan")
      : (dataSets.indices.contains(gamePicker.indexOfSelectedItem)
        ? dataSetID(dataSets[gamePicker.indexOfSelectedItem]) : gameID)
    let stableID: String
    if fanPlaying, fanQueue.indices.contains(fanQueueIndex) {
      let entry = fanQueue[fanQueueIndex]
      stableID = entry.file + ":" + (entry.section.map(String.init) ?? "whole-file")
    } else { stableID = currentNxlvURL?.lastPathComponent ?? "level-\(picker.indexOfSelectedItem)" }
    let rules = new is ClassicSession ? "classic-dos-v1" : "neolemmix-v1"
    let conditions = TrolleyConditions(gameID: gameID, packID: packID, levelID: stableID, levelFingerprint: fingerprint,
        rulesetVersion: rules, physicsMode: rules, population: new.total, rescueRequirement: new.required,
        startingSkills: TrolleyCapture.skills(new.skills), timeLimitSeconds: new.remainingSeconds.map(Double.init))
    arcadeLevel = ArcadeLevel(id: gameID + ":" + stableID,
        title: currentNxlvURL?.deletingPathExtension().lastPathComponent ?? artworkLevel?.title ?? "Lemmings",
        game: fanPlaying || currentNxlvURL != nil ? "Fan levels" : activeTitle?.displayName ?? campaign?.name ?? "Lemmings",
        rules: rules, total: new.total, required: new.required, conditions: conditions)
    if !restoringCheckpoint {
      if sequencePlayingIdentity == nil {
        ArcadeStore.shared.beginAttempt(
          id: arcadeRunID,
          profileID: arcadeProfileID,
          level: arcadeLevel!,
          previousID: previousAttemptID)
      }
      runMovie.begin(ticksPerSecond: Double(new.ticksPerSecond), title: artworkLevel?.title ?? "Lemmings")
    }
    runMovie.onWillReview = { [weak self] in
      self?.music.suspendOutput(); self?.soundtrack.suspendOutput(); self?.dj.suspendOutput(); self?.effects.suspendOutput()
    }
    runMovie.onDidReview = { [weak self] in
      try? self?.music.resumeOutput(); self?.soundtrack.resumeOutput(); self?.dj.resumeOutput(); try? self?.effects.resumeOutput()
    }
    if let recorder = runMovie.recorder {
      effects.onPlay = { [weak recorder] samples, rate, gain in recorder?.sound(samples: samples, rate: rate, gain: gain) }
    }
    let rootSize = window.contentView?.bounds.size ?? CGSize(width: 1280, height: 720)
    replaySize = CGSize(width: 1280, height: max(240, min(960, floor(1280 * rootSize.height / max(1, rootSize.width) / 2) * 2)))
    accumulator = 0
    isPaused = false
    panel.isPaused = false
    isFastForward = false
    panel.isFastForward = false
    lastStepTime = nil
    panel.session = new
    panel.selectedSkillIndex = new.skills.firstIndex { $0.count > 0 || $0.isInfinite } ?? 0
    panel.levelSize = CGSize(width: new.levelWidth, height: new.levelHeight)
    playfield.session = new
    playfield.viewport.levelSize = panel.levelSize
    window.contentView?.layoutSubtreeIfNeeded()
    playfield.viewport.viewSize = playfield.bounds.size
    playfield.viewport.scrollY = 0
    if let entrance = new.entranceX { playfield.viewport.center(on: Double(entrance)) }
    panel.terrainImage = playfield.levelImage
    syncPanelViewport()
    updateStatus()
    playMusicForCurrentLevel()
  }

  // MARK: - The game shell

  private func showTitle() {
    flow?.screen == .title ? () : flow?.acknowledgeGameComplete()
    renderScreen()
  }

  /// Saves progress for the game currently loaded.
  private func saveProgress() {
    guard !sequenceIsActive else { return }
    guard let flow, dataSets.indices.contains(gamePicker.indexOfSelectedItem) else { return }
    let key = ArcadeStore.shared.progressKey(
      "\(flowProgressKey).\(dataSetID(dataSets[gamePicker.indexOfSelectedItem]))")
    if let data = try? JSONEncoder().encode(flow.progress) {
      UserDefaults.standard.set(data, forKey: key)
    }
    refreshClassicLevelPickerAvailability()
    rebuildLibrary()
  }

  /// Draws whichever screen the game is on.
  private func renderScreen() {
    defer { applyDisplayMode() }
    guard let flow else { return }
    playfield.overlayShowsSettingsButton = false
    if !sequelIsActive {
      window.title = flow.screen == .title ? "Ultimate Lemmings"
        : activeTitle?.displayName ?? campaign?.name ?? "Lemmings"
    }
    if fanPlaying { return }
    playfield.overlayHighlight = nil
    playfield.overlayReplayLine = nil
    playfield.overlayRetryLine = nil
    panel.isMenuMode = !flow.screen.isPlaying
    fitClassicDisplay()

    switch flow.screen {
    case .title:
      if playfield.levelImage == nil, let entry = campaign?.levels.first {
        buildLevel(entry)
      }
      // Fan browsing sits over the title screen rather than replacing it.
      if fanScreen != .off {
        renderFanScreen()
        return
      }
      playfield.overlayShowsSettingsButton = true
      setStatus("")
      phase = .briefing
      playfield.phase = .briefing
      playfield.overlayShowsLemmings = true
      playfield.overlayTitle = "LEMMINGS"
      menuRecovery = try? recoveryStore.latest(profileID: ArcadeStore.shared.playingProfileID, hotSeatID: ArcadeStore.shared.hotSeatID)
      let homeItems = homeMenuItems()
      playfield.overlayLines = homeItems.map(\.title)
      launchChoice = max(0, min(launchChoice, homeItems.count - 1))
      playfield.overlayHighlight = launchChoice
      playfield.overlayFooter = nil
      // A hot seat names everyone in turn order, so the menu shows who is playing
      // rather than only whose campaign it is.
      playfield.overlayProfileInitials = ArcadeStore.shared.hotSeatIsActive
        ? ArcadeStore.shared.sessionProfiles.map(\.initials).joined(separator: " v ")
        : ArcadeStore.shared.records.activeProfile.initials

    case .rankSelect:
      phase = .briefing
      playfield.phase = .briefing
      playfield.overlayShowsLemmings = false
      playfield.overlayTitle = "Choose a rating"
      playfield.overlayLines = flow.ranks.map { rank in
        let done = flow.passedCount(inRank: rank.name)
        return "\(rank.name)  \(done)/\(rank.levelIndices.count)"
      }
      playfield.overlayHighlight = rankChoice
      playfield.overlayFooter = "UP AND DOWN TO CHOOSE  *  ENTER TO START"

    case let .briefing(level):
      loadLevel(at: level)
      showBriefingOverlay()

    case .playing:
      phase = .playing
      playfield.phase = .playing
      playfield.overlayTitle = nil
      playfield.overlayLines = []
      playfield.overlayFooter = nil
      updateStatus()

    case let .results(_, saved, required, total):
      phase = .results
      playfield.phase = .results
      let rescued = total > 0 ? Int((Double(saved) / Double(total) * 100).rounded()) : 0
      let needed = total > 0 ? Int((Double(required) / Double(total) * 100).rounded()) : 0
      let passed = saved >= required
      playfield.overlayTitle = passed ? "Level complete" : "Not this time"
      playfield.overlayLines = [
        "Rescued \(saved) of \(total)  (\(rescued)%)",
        "Needed \(required)  (\(needed)%)",
        "V WATCH REPLAY  *  S SAVE MOVIE",
        "R RETRY - SAVE MORE, USE LESS",
      ]
      playfield.overlayReplayLine = 2
      playfield.overlayRetryLine = 3
      playfield.overlayFooter = passed
        ? "CLICK OR PRESS ENTER TO CONTINUE"
        : "Click or press Enter to try again"

    case let .rankComplete(rank):
      phase = .results
      playfield.phase = .results
      let total = flow.ranks.first(where: { $0.name == rank })?.levelIndices.count ?? 0
      let passed = flow.passedCount(inRank: rank)
      playfield.overlayTitle = passed == total ? "\(rank) complete" : "\(rank) run finished"
      playfield.overlayLines = ["\(passed)/\(total) levels passed in this rating."]
      playfield.overlayFooter = "CLICK OR PRESS ENTER TO CONTINUE"

    case .gameComplete:
      phase = .results
      playfield.phase = .results
      let current = gamePicker.indexOfSelectedItem
      let name = dataSets.indices.contains(current) ? dataSets[current].set.name : "Game"
      playfield.overlayTitle = "\(name) complete"
      if launchMode == .quest, let title = activeTitle,
         case let .title(next) = library.next(after: title, mode: launchMode) {
        playfield.overlayLines = ["Every rating is finished.", "Next: \(next.displayName)"]
        playfield.overlayFooter = "CLICK OR PRESS ENTER TO CONTINUE"
      } else {
        playfield.overlayLines = ["Every rating is finished."]
        playfield.overlayFooter = "CLICK OR PRESS ENTER FOR THE GAME LIBRARY"
      }

    case .quitConfirm:
      phase = .results
      playfield.phase = .results
      playfield.overlayTitle = "Quit?"
      playfield.overlayLines = ["Progress is saved."]
      playfield.overlayFooter = "Q AGAIN TO QUIT  *  ESCAPE TO STAY"
    }
    playfield.needsDisplay = true
    panel.needsDisplay = true
  }

  private struct HandoverRetry {
    let hotSeatID: String
    let profileID: String
    let dataSetID: String
    let levelIndex: Int
  }
  private var handoverRetry: HandoverRetry?

  private var availableHandoverRetry: HandoverRetry? {
    guard let retry = handoverRetry, ArcadeStore.shared.hotSeatIsActive,
      retry.hotSeatID == ArcadeStore.shared.hotSeatID,
      retry.profileID == ArcadeStore.shared.playingProfileID else { return nil }
    return retry
  }

  private func retryPreviousHandoverLevel() {
    guard phase == .briefing, let retry = availableHandoverRetry,
      let dataSet = dataSetIndex(matching: retry.dataSetID),
      dataSets[dataSet].set.campaign.levels.indices.contains(retry.levelIndex) else { return }
    handoverRetry = nil
    if gamePicker.indexOfSelectedItem != dataSet {
      gamePicker.selectItem(at: dataSet)
      selectDataSet()
    }
    picker.selectItem(at: retry.levelIndex)
    levelChanged()
    if phase == .briefing { advancePhase() }
    isPaused = true; panel.isPaused = true; accumulator = 0; lastStepTime = nil
  }

  private func showBriefingOverlay() {
    guard let session, let flow else { return }
    phase = .briefing
    playfield.phase = .briefing
    let percent = session.total > 0
      ? Int((Double(session.required) / Double(session.total) * 100).rounded())
      : 0
    var lines = [
      "\(session.total) lemmings",
      "Save \(session.required)  (\(percent)%)",
      "Release rate \(session.rate)",
    ]
    if let seconds = session.remainingSeconds {
      lines.append(String(format: "Time %d:%02d", seconds / 60, seconds % 60))
    }
    let title = campaign.flatMap { campaign -> String? in
      guard let index = flow.currentLevelIndex, index < campaign.levels.count else { return nil }
      return campaign.levels[index].level.title.trimmingCharacters(in: .whitespaces)
    }
    playfield.overlayTitle = title ?? "Level"
    // A hot seat changes hands between levels, so the briefing has to say who is
    // holding the mouse before the level starts, not after the result. Solo play
    // shows nothing: there is nobody to tell apart.
    if ArcadeStore.shared.hotSeatIsActive,
       let turn = ArcadeStore.shared.playingProfile {
      lines.insert("YOUR TURN, \(turn.initials)", at: 0)
      playfield.overlayTurnInitials = turn.initials
      if availableHandoverRetry != nil {
        playfield.overlayHandoverRetryTitle = "Retry last level as \(turn.initials)"
      }
    }
    playfield.overlayLines = lines
    playfield.overlayFooter =
      "\(flow.currentRank?.name ?? "") \(flow.currentNumber)   •   Click or space to begin   •   i: goals and hints"
    setStatus("")
  }

  /// Moves past whichever screen is showing.
  private func advancePhase() {
    if advanceFanPlay() { return }
    if advanceFanScreen() { return }
    guard var current = flow else { return }
    switch current.screen {
    case .title:
      if sequenceIsActive {
        returnToLibrary()
        return
      }
      let homeItems = homeMenuItems()
      guard homeItems.indices.contains(launchChoice) else { return }
      switch homeItems[launchChoice].action {
      case .resume:
        if let checkpoint = menuRecovery { restoreRun(checkpoint) }
      case .fullQuest:
        launchMode = .quest
        if let title = library.questStart { launchTitle(title) }
      case let .browse(family):
        openLevelBrowser(family: family)
      }
      return
    case .rankSelect:
      classicSelectionRecordsCampaignProgress = true
      current.selectRank(rankChoice)
    case .briefing:
      handoverRetry = nil
      current.beginPlaying()
      flow = current
      renderScreen()
      effects.play(.levelStart)
      return
    case let .results(_, saved, required, _):
      if sequencePlayingIdentity != nil, saved < required {
        retry()
        return
      }
      if continuePlayingSequenceIfNeeded() { return }
      handoverRetry = nil
      if saved >= required, let hotSeatID = ArcadeStore.shared.hotSeatID, ArcadeStore.shared.hotSeatIsActive,
        let levelIndex = current.currentLevelIndex,
        dataSets.indices.contains(gamePicker.indexOfSelectedItem) {
        handoverRetry = HandoverRetry(hotSeatID: hotSeatID, profileID: ArcadeStore.shared.playingProfileID,
          dataSetID: dataSetID(dataSets[gamePicker.indexOfSelectedItem]), levelIndex: levelIndex)
      }
      current.acknowledgeResults(
        recordsCampaignProgress: classicSelectionRecordsCampaignProgress)
    case .rankComplete:
      current.acknowledgeRankComplete(
        recordsCampaignProgress: classicSelectionRecordsCampaignProgress)
    case .gameComplete:
      if advanceToNextTitle() { return }
      returnToLibrary()
      return
    case .quitConfirm: NSApplication.shared.terminate(nil)
    case .playing: return
    }
    flow = current
    saveProgress()
    renderScreen()
  }

  private func requestQuit() {
    guard var current = flow else { return }
    current.requestQuit()
    flow = current
    renderScreen()
  }

  private func cancelQuit() {
    guard var current = flow else { return }
    current.cancelQuit()
    flow = current
    renderScreen()
  }

  private func moveRankChoice(_ delta: Int) {
    if fanPlaying { return }
    if moveFanChoice(delta) { return }
    if let flow, flow.screen == .title {
      let count = homeMenuItems().count
      guard count > 0 else { return }
      launchChoice = (launchChoice + delta + count) % count
      renderScreen()
      return
    }
    guard let flow, flow.screen == .rankSelect, !flow.ranks.isEmpty else { return }
    rankChoice = (rankChoice + delta + flow.ranks.count) % flow.ranks.count
    renderScreen()
  }

  /// Carries a completed release into the first rating of the next installed
  /// release. The game picker remains a direct chapter selector at all times.
  private func advanceToNextTitle() -> Bool {
    saveProgress()
    guard let title = activeTitle,
          case let .title(next) = library.next(after: title, mode: launchMode) else { return false }
    launchTitle(next)
    return true
  }

  /// Builds the status bar image from the imported panel graphics.
  private func makePanelImage() -> CGImage? {
    guard let graphics = assets?.panel else { return nil }
    let bytes = graphics.rgba(using: ClassicLemmingPalette.panelVGA)
    guard !bytes.isEmpty, let provider = CGDataProvider(data: bytes as CFData) else { return nil }
    return CGImage(
      width: graphics.width, height: graphics.height, bitsPerComponent: 8, bitsPerPixel: 32,
      bytesPerRow: graphics.width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
      provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
  }

  private func makeImage(width: Int, height: Int, rgba: [UInt8]) -> CGImage? {
    guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
    return CGImage(
      width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
      provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
  }

  private func syncPanelViewport() {
    panel.terrainImage = playfield.levelImage
    panel.visibleLevelRect = playfield.viewport.visibleLevelRect
    panel.needsDisplay = true
  }

  private func setStatus(_ text: String) {
    panel.statusText = text
    panel.needsDisplay = true
  }

  // MARK: - Run loop

  private func startTimer() {
    timer?.invalidate()
    lastStepTime = nil
    timer = Timer.scheduledTimer(withTimeInterval: displayInterval, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.step() }
    }
  }

  /// Show the attempt owner, even when another player is queued for the next turn.
  private func refreshTurnDisplay() {
    let store = ArcadeStore.shared
    let turn = store.hotSeatIsActive ? store.records.profile(arcadeProfileID) : nil
    playfield.turnInitials = turn?.initials
    playfield.turnPortrait = turn?.portrait
  }

  /// Where the player is in the journey, on the right of the status strip.
  /// Rank position, rescue progress against the target, the best known result
  /// for this level, and the play style the run is shaping into.
  private func refreshProgressText() {
    guard phase == .playing, let session, !sequelIsActive else {
      panel.progressText = ""
      return
    }
    var parts: [String] = []
    if let flow, let rank = flow.currentRank {
      parts.append("\(rank.name.uppercased()) \(flow.currentNumber)/\(rank.levelIndices.count)")
    }
    parts.append("SAVED \(session.saved)/\(session.required)")
    if let conditions = arcadeLevel?.conditions {
      let best = ArcadeStore.shared.records.trolley.maximum(
        conditions: conditions, assisted: session.usedRewind)
      if best.isRescueTarget, let value = best.value {
        // Proven maximum and merely best observed are different claims, so the
        // panel does not present one as the other.
        let proven = best.status == TrolleyMaximumStatus.verified
        parts.append("\(proven ? "BEST" : "KNOWN") \(value)")
      }
    }
    if session.released < session.total { parts.append("OUT \(session.released)/\(session.total)") }
    panel.progressText = parts.joined(separator: "   ")
  }

  private func step(at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
    updateFailureMood()
    refreshTurnDisplay()
    refreshProgressText()
    // Limit catch-up after sleep or a long modal interaction.
    let elapsed = min(0.25, max(0, lastStepTime.map { now - $0 } ?? displayInterval))
    lastStepTime = now
    speedControl.update(at: now, active: phase == .playing && !sequelIsActive && !GameScreen.shared.isPresented && session?.isComplete == false)
    panel.isFastForward = isFastForward
    panel.speedChoiceLabel = speedControl.choiceLabel
    panel.speedLabel = speedControl.panelLabel
    panel.variableSpeedEnabled = speedControl.variableEnabled
    playfield.speedMultiplier = speedControl.multiplier
    // Settle the display before an open page can suspend the simulation.
    applyDisplayMode()
    guard !sequelIsActive, !GameScreen.shared.isPresented else {
      screenFlash.setSuperSpeed(false,in:screenFlash.bounds,immediate:true)
      pointerCapture.reset()
      accumulator = 0; return
    }
    if let root = window.contentView, screenFlash.superview !== root {
      screenFlash.removeFromSuperview()
      screenFlash.frame = root.bounds
      screenFlash.autoresizingMask = [.width, .height]
      root.addSubview(screenFlash)
    }
    let superSpeed = settings.speedEffectsEnabled && isFastForward && !isPaused && phase == .playing && session?.isComplete == false
    playfield.isFastForward = superSpeed
    playfield.updateSpeedTrails()
    let speedField = tubeIsActive
      ? CGRect(x:0,y:0,width:screenFlash.bounds.width,height:screenFlash.bounds.height*0.8)
      : screenFlash.convert(playfield.bounds,from:playfield)
    screenFlash.setSuperSpeed(superSpeed,in:speedField,immediate:!superSpeed, multiplier: speedControl.multiplier)
    updatePointerCapture()
    applyEdgeScroll()
    // Menus animate even though the level clock is stopped.
    if phase != .playing, playfield.overlayShowsLemmings {
      playfield.overlayFrame &+= 1
      playfield.needsDisplay = true
    }
    if tubeIsActive {
      let wanted = CGRect(
        x: 0, y: 0, width: 640, height: 320)
      if playfield.frame != wanted {
        playfield.frame = wanted
        playfield.viewport.viewSize = wanted.size
      }
      if let frame = composeNativeFrame() { crtView.setSource(frame, flashes: playfield.hdrFlashes) }
    }
    if let session, phase == .playing { dj.updateTelemetry(djTelemetry(session)) }
    guard phase == .playing, !isPaused, let session, !session.isComplete else { return }

    // Each ruleset states its own logic rate. Whole ticks only, so timing does
    // not drift with the display.
    let interval = 1.0 / Double(session.ticksPerSecond)
    accumulator += elapsed * speedControl.multiplier
    var advanced = false
    let inputDeadline = ProcessInfo.processInfo.systemUptime + 0.012
    while accumulator >= interval {
      accumulator -= interval
      let before = session.remainingSeconds
      let previousExplosions = settings.cinematicExplosionsEnabled
        ? Set(session.lemmings.filter { $0.pose == .explosion }.map(\.id)) : []
      session.tick()
      updateFailureMood()
      playfield.updateSpeedTrails()
      countdownWarning.reset(seconds: before)
      if countdownWarning.update(seconds: session.remainingSeconds) { effects.play(.builderWarning) }
      flashExplosions(previous: previousExplosions)
      dj.updateTelemetry(djTelemetry(session))
      effects.play(session.lastCues)
      captureReplayFrame()
      advanced = true
      if session.isComplete { break }
      if speedControl.variableEnabled && speedControl.multiplier > 1 && ProcessInfo.processInfo.systemUptime >= inputDeadline { break }
    }
    guard advanced else { return }
    saveRunCheckpoint()

    panel.terrainImage = playfield.levelImage
    playfield.needsDisplay = true
    panel.needsDisplay = true
    updateStatus()
    finishSessionIfNeeded()
  }

  private func flashExplosions(previous: Set<Int>) {
    guard settings.cinematicExplosionsEnabled, let session else { return }
    let fresh = session.lemmings.filter { $0.pose == .explosion && !previous.contains($0.id) }
    let cores: [CGRect] = fresh.compactMap { lemming in
      let point = playfield.viewport.viewPoint(fromLevel: CGPoint(x:lemming.x,y:lemming.y-6))
      guard playfield.bounds.contains(point) else { return nil }
      let centre: CGPoint
      if tubeIsActive {
        guard let curved = crtView.viewPoint(fromSource:point) else { return nil }
        centre = screenFlash.convert(curved,from:crtView)
      } else { centre = screenFlash.convert(point,from:playfield) }
      return CGRect(x:centre.x-3,y:centre.y-3,width:6,height:6)
    }
    if !cores.isEmpty { screenFlash.pulse(cores:cores,fullScreen:true) }
  }

  private func captureReplayFrame() {
    guard phase == .playing, runMovie.recorder != nil else { return }
    #if PERFORMANCE_TESTS
    let captureStarted = ProcessInfo.processInfo.systemUptime
    defer { replayCaptureSeconds += ProcessInfo.processInfo.systemUptime - captureStarted }
    #endif
    updateStatus()
    let musicURL = dj.isPlaying ? dj.currentURL : soundtrack.isPlaying ? soundtrack.currentURL : music.isRunning ? music.currentURL : nil
    runMovie.recorder?.setMusic(url: musicURL, gain: audioMuted || settings.music == .silent ? 0 : Float(settings.musicVolume))
    let fieldHeight = tubeIsActive ? replaySize.height * 0.8
      : replaySize.height * playfield.bounds.height / max(1, playfield.bounds.height + panel.bounds.height)
    runMovie.capture(ReplayFrameCapture.image(size: replaySize) {
      ReplayFrameCapture.draw(playfield, in: CGRect(x: 0, y: 0, width: replaySize.width, height: fieldHeight))
      ReplayFrameCapture.draw(panel, in: CGRect(x: 0, y: fieldHeight, width: replaySize.width, height: replaySize.height - fieldHeight))
    })
  }

  @objc private func reviewLastGame() {
    if let nativeL2Window { nativeL2Window.reviewReplay(); return }
    if let nativeL3Window { nativeL3Window.reviewReplay(); return }
    guard phase == .results, session?.isComplete == true else { return }
    runMovie.review()
  }
  @objc private func openReplayMovie() {
    let paused = isPaused
    let interruption = gameplayKeyboard?.interruptionCount
    let previousSession = session
    var resumeSequel: (() -> Void)?
    ReplayMovieWindow.shared.openMovie(onOpen: { [weak self] in
      guard let self else { return }
      self.isPaused = true; self.panel.isPaused = true
      self.music.suspendOutput(); self.soundtrack.suspendOutput(); self.dj.suspendOutput(); self.effects.suspendOutput()
      resumeSequel = self.nativeL2Window?.suspendForReplay() ?? self.nativeL3Window?.suspendForReplay()
    }, onClose: { [weak self] in
      guard let self else { return }
      resumeSequel?()
      if self.session === previousSession {
        self.isPaused = paused || self.gameplayKeyboard?.interruptionCount != interruption
        self.panel.isPaused = self.isPaused
      }
      try? self.music.resumeOutput(); self.soundtrack.resumeOutput(); self.dj.resumeOutput(); try? self.effects.resumeOutput()
      self.lastStepTime = nil
    })
  }

  private func finishSessionIfNeeded() {
    guard phase == .playing, let session, session.isComplete else { return }
    let recordsPlayerArtifacts = sequencePlayingIdentity == nil
    runMovie.finish()
    do { try recoveryStore.clear(arcadeRunID) } catch { setStatus("Could not clear completed checkpoint: " + error.localizedDescription) }
    if let arcadeLevel {
      if recordsPlayerArtifacts,
         let classic = session as? ClassicSession, classic.didWin {
        let index = picker.indexOfSelectedItem
        let entry = !fanPlaying && currentNxlvURL == nil && campaign?.levels.indices.contains(index) == true
          ? campaign?.levels[index] : nil
        ClassicRouteRecorder.record(session: classic, level: arcadeLevel,
          title: entry?.level.title.trimmingCharacters(in: .whitespaces) ?? arcadeLevel.title, rank: entry?.rank ?? "Fan", number: entry?.number ?? max(1, index + 1)) { [weak self] error in
            self?.setStatus("Could not save the input route: " + error)
          }
      }
      let run = ArcadeRun(id: arcadeRunID, profileID: arcadeProfileID,
        level: arcadeLevel, saved: session.saved, didWin: session.didWin, skills: session.skillAssignments,
        seconds: Double(session.currentTick) / Double(session.ticksPerSecond), assisted: session.usedRewind,
        telemetry: TrolleyCapture.telemetry(session))
      arcadeReport = recordsPlayerArtifacts
        ? ArcadeStore.shared.record(run)
        : ArcadeStore.shared.previewReport(for: run)
      if recordsPlayerArtifacts, let report = arcadeReport {
        runMovie.preserveRecord(report)
      }
    }
    defer { presentArcadeResult() }
    if fanPlaying {
      showFanResults()
      return
    }
    if currentNxlvURL != nil {
      showFanResults()
      return
    }
    let recordsCampaignProgress = recordsPlayerArtifacts
      && classicSelectionRecordsCampaignProgress
    if recordsCampaignProgress { recordCompletion(session) }
    if var current = flow {
      current.finishLevel(
        saved: session.saved,
        required: session.required,
        total: session.total,
        recordsCampaignProgress: recordsCampaignProgress)
      flow = current
      if recordsCampaignProgress { saveProgress() }
      renderScreen()
    }
  }

  private func updatePointerCapture() {
    guard let root = window.contentView else { pointerCapture.reset(); return }
    let active = settings.confinePointer && !playfield.usesControllerPointer && phase == .playing && !isPaused
      && session?.isComplete == false && !GameScreen.shared.isPresented
    guard let point = pointerCapture.update(in: root, active: active) else { return }
    if tubeIsActive {
      let viewPoint = crtView.convert(point, from: root)
      crtView.updateSystemCursor(at: viewPoint)
      if let source = crtView.sourcePoint(from: viewPoint, clampingToImage: true) {
        tubeMove(source)
      }
    } else {
      let gameplayRect = playfield.phase == .playing
        ? root.convert(playfield.bounds, from: playfield)
        : nil
      GameCursor.update(at: point, hidingInside: gameplayRect)
      let local = playfield.convert(point, from: root)
      if playfield.bounds.contains(local) { playfield.handleMove(to: local) }
      else { playfield.clearPointer() }
    }
  }

  private func applyEdgeScroll() {
    guard phase == .playing, window.isKeyWindow, NSApp.isActive, let delta = playfield.edgeScrollDelta, delta != 0 else { return }
    playfield.viewport.scroll(dx: delta, dy: 0)
    playfield.needsDisplay = true
    syncPanelViewport()
  }

  private func recordCompletion(_ session: any GameSession) {
    guard currentNxlvURL == nil else { return }
    progress.record(
      levelIndex: picker.indexOfSelectedItem, saved: session.saved, required: session.required)
    if let data = try? progress.encoded() {
      UserDefaults.standard.set(data, forKey: ArcadeStore.shared.progressKey(progressKey))
    }
    guard session.didWin,
      dataSets.indices.contains(gamePicker.indexOfSelectedItem),
      let title = dataSets[gamePicker.indexOfSelectedItem].set.title,
      let campaign
    else { return }
    let earned = achievements.recordWin(
      title: title,
      levelIndex: picker.indexOfSelectedItem,
      levelCount: campaign.levels.count)
    if let data = try? JSONEncoder().encode(achievements) {
      UserDefaults.standard.set(data, forKey: ArcadeStore.shared.progressKey(achievementProgressKey))
    }
    achievementsWindow.update(progress: achievements)
    if !earned.isEmpty {
      setStatus("Achievement unlocked: \(earned.map(\.title).joined(separator: ", "))")
    }
  }

  private func updateStatus() {
    guard let session else { return }
    var parts = [
      "Out \(session.released)/\(session.total)",
      "Home \(session.saved)/\(session.required)",
      "\(session.rateLabel) \(session.rate)",
    ]
    if let seconds = session.remainingSeconds {
      parts.append(String(format: "Time %d:%02d", seconds / 60, seconds % 60))
    }
    if isFastForward { parts.append("SPEED " + speedControl.label.replacingOccurrences(of: "×", with: "X")) }
    if session.isNuking { parts.append("NUKING") }
    if session.isComplete {
      parts.append(session.didWin ? "COMPLETE — press N" : "FAILED — press R")
    }
    setStatus(parts.joined(separator: "   "))
  }

  // MARK: - Commands

  private func handle(_ button: PanelButton) {
    guard let session else { return }
    switch button {
    case .rateDown: session.adjustRate(by: -1)
    case .rateUp: session.adjustRate(by: 1)
    case let .skill(index):
      panel.selectedSkillIndex = index
      // The gameplay reticle owns the selected-skill artwork. Redraw it as
      // soon as the panel selection changes, including while the run is paused.
      playfield.needsDisplay = true
      panel.needsDisplay = true
    case .pause: togglePause()
    case .fastForward: toggleFastForward()
    case .nuke:
      if session.canUndoNuke {
        session.undoNuke()
        screenFlash.clear()
        accumulator = 0; lastStepTime = nil
      } else {
        session.nuke()
        effects.play(session.lastCues)
      }
      playfield.needsDisplay = true
      panel.needsDisplay = true
    }
    updateStatus()
  }

  private func toggleFastForward() {
    guard phase == .playing, let session, !session.isComplete else { return }
    speedControl.tap()
    panel.isFastForward = isFastForward
    lastStepTime = nil
    panel.needsDisplay = true
    updateStatus()
  }

  private func interruptGameplay() {
    saveRunCheckpoint(immediately: true)
    guard phase == .playing, !sequelIsActive, session?.isComplete == false else { return }
    isPaused = true; panel.isPaused = true; accumulator = 0; lastStepTime = nil
    pointerCapture.reset(); panel.handlePointerUp(); playfield.clearPointer()
    screenFlash.clear(); effects.silence(); panel.needsDisplay = true; updateStatus()
  }

  private func togglePause() {
    saveRunCheckpoint(immediately: true)
    isPaused.toggle()
    panel.isPaused = isPaused
    panel.needsDisplay = true
    if isPaused {
      music.suspendOutput()
      soundtrack.suspendOutput()
      dj.suspendOutput()
      effects.suspendOutput()
    } else {
      rewindOriginTick = nil
      playfield.endRewindCue()
      do {
        try music.resumeOutput()
        soundtrack.resumeOutput()
        dj.resumeOutput()
        try effects.resumeOutput()
      } catch {
        setStatus("Audio unavailable: \(error.localizedDescription)")
      }
      lastStepTime = nil
    }
  }

  private func assign(_ id: Int) {
    panel.resetNukeGesture()
    guard let session else { return }
    let rejection = session.assign(skillIndex: panel.selectedSkillIndex, to: id)
    playfield.needsDisplay = true
    panel.needsDisplay = true
    if let rejection {
      setStatus("Cannot assign: \(rejection)")
    } else {
      playfield.didAssign(to: id)
      assignmentFocus.record(id: id, skill: panel.selectedSkillIndex, tick: session.currentTick)
      // The click is acknowledged straight away rather than on the next tick,
      // so the sound lands with the press.
      effects.play(session.lastCues)
      updateStatus()
    }
  }

  // MARK: - Music

  @objc private func chooseMusic() {
    cancelLevelSelectionLoading()
    Task { @MainActor in
      guard let url = await pickDirectory("Choose a folder of ProTracker .mod files.") else { return }
      UserDefaults.standard.set(url.path, forKey: musicPathKey)
      music.loadLibrary(at: url)
      if music.library.isEmpty {
        setStatus("No .mod files were found in that folder.")
      } else {
        playMusicForCurrentLevel()
      }
    }
  }

  @objc private func chooseSounds() {
    cancelLevelSelectionLoading()
    Task { @MainActor in
      let openPanel = NSOpenPanel()
      openPanel.canChooseFiles = true
      openPanel.canChooseDirectories = false
      openPanel.allowedFileTypes = ["dsk", "img", "dmg", "hfs"]
      openPanel.message = "Choose a Macintosh Lemmings disk image."
      guard let url = await GameScreen.shared.chooseFile(openPanel) else { return }
      UserDefaults.standard.set(url.path, forKey: macImageKey)
      loadSoundEffects(from: url)
    }
  }

  /// The Macintosh release names its sounds, so they bind without guessing.
  private func loadSoundEffects(from url: URL) {
    do {
      let loaded = try effects.loadMacintoshSounds(imageURL: url)
      setStatus("Loaded \(loaded.count) sound effects.")
    } catch {
      setStatus("Sound effects: \(error)")
    }
  }

  /// Loads the bank the chosen sound source names.
  ///
  /// Each source owns the whole set, so switching replaces every effect rather
  /// than mixing two machines together.
  private func loadSoundEffects(for source: ClassicSoundSource) {
    switch source {
    case .macintoshResources:
      let custom = UserDefaults.standard.string(forKey: macImageKey).map { URL(fileURLWithPath: $0) }
      guard let image = custom ?? BundledGameResources.macintoshSoundImage() else { return }
      loadSoundEffects(from: image)
    case .amigaVoices:
      guard let root = Bundle.main.resourceURL else { return }
      let directory = root.appendingPathComponent("Ports/amiga_extracted/lemmings")
      do {
        let loaded = try effects.loadAmigaSounds(directory: directory, deathFallbackImage: BundledGameResources.macintoshSoundImage())
        setStatus("Loaded \(loaded.count) Amiga sound effects.")
      } catch {
        setStatus("Amiga sound effects: \(error)")
      }
    default:
      break
    }
  }

  @objc private func toggleMute() {
    audioMuted.toggle()
    UserDefaults.standard.set(audioMuted, forKey: "AudioMuted")
    applyAudioSettings()
    updateMusicButtons()
  }

  @objc private func toggleMusicPreset() {
    var updated = settings
    updated.musicStyle = settings.musicStyle == .modern ? .faithful : .modern
    apply(updated)
  }

  private func updateMusicButtons() {
    muteItem?.state = audioMuted ? .on : .off
    presetItem?.state = music.usesModernPreset ? .on : .off
  }

  /// Every folder of recordings beside the modules is one soundtrack.
  ///
  /// The player adds these. A folder of Amiga rips, a console version or a
  /// remix all work the same way, and each appears in the settings by name.
  private func loadSoundtracks() {
    guard let root = Bundle.main.resourceURL?.appendingPathComponent("Music") else { return }
    soundtrackLibrary = SoundtrackPlayer.soundtracks(at: root)
    reloadDJLibrary()
    dj.onTrackChange = { [weak self] name in self?.setStatus("* \(name)") }
  }

  private func reloadDJLibrary() {
    guard let root = Bundle.main.resourceURL?.appendingPathComponent("Music") else { return }
    dj.load(soundtracks: SoundtrackPlayer.djSoundtracks(at: root,
      includeOtherSoundtracks: settings.djIncludesOtherSoundtracks, seasonal: seasonalMusic))
  }

  /// Describes the level to the mix, so it can decide when to move.
  private func djTelemetry(_ session: any GameSession) -> AdaptiveDJEngine.Telemetry {
    AdaptiveDJEngine.Telemetry(
      releasedCount: session.released,
      totalCount: session.total,
      savedCount: session.saved,
      requiredCount: session.required,
      releaseRate: session.rate,
      // A lemming counting down is the clearest danger the session exposes.
      dangerCount: session.lemmings.filter { $0.countdown != nil }.count,
      remainingSeconds: session.remainingSeconds,
      isNuking: session.isNuking,
      didWin: session.saved >= session.required)
  }

  /// The original cycles through its tunes as the campaign advances.
  private func playMusicForCurrentLevel() {
    guard !sequelIsActive else { return }
    if settings.music == .silent {
      music.stop()
      soundtrack.stop()
      dj.stop()
      return
    }
    // The mix runs across every supplied soundtrack and moves on its own.
    if activeMusic == .adaptiveDJ { reloadDJLibrary() }
    if activeMusic == .adaptiveDJ, dj.hasTracks {
      music.stop()
      soundtrack.stop()
      dj.resetLevel()
      dj.start()
      return
    }
    dj.stop()

    // A chosen soundtrack replaces the modules for the whole session.
    if case let .remix(name) = activeMusic, let tracks = soundtrackLibrary[name] {
      music.stop()
      soundtrack.load(tracks)
      let index = settings.shuffleMusic
        ? Int.random(in: 0..<max(1, tracks.count))
        : (currentNxlvURL == nil ? max(0, picker.indexOfSelectedItem) : 0)
      if let title = soundtrack.play(index: index) { setStatus("* \(title)") }
      return
    }
    soundtrack.stop()
    // Refresh on every level so leaving a seasonal campaign cannot retain its library.
    let folder = seasonalMusic ? "holiday_lemmings_music_mod"
      : musicTitle == .ohNoMoreLemmings ? "oh_no_more_lemmings_music_mod" : "lemmings_music_mod"
    let directory = !seasonalMusic ? UserDefaults.standard.string(forKey: musicPathKey)
      .map { URL(fileURLWithPath: $0, isDirectory: true) } : nil
    guard let root = directory ?? BundledGameResources.music(folder) else { music.stop(); return }
    music.loadLibrary(at: root)
    guard !music.library.isEmpty else { music.stop(); return }
    do {
      try music.start()
    } catch {
      setStatus("Audio unavailable: \(error.localizedDescription)")
      return
    }
    let index = currentNxlvURL == nil ? max(0, picker.indexOfSelectedItem) : 0
    if let title = music.play(index: index) {
      setStatus("♪ \(title)")
    }
  }

  @objc private func zoomIn() { setZoom(playfield.viewport.zoom + 1) }
  @objc private func zoomOut() { setZoom(playfield.viewport.zoom - 1) }

  private func setZoom(_ value: Double) {
    // Zoom applies to a level being played. On a menu there is nothing to zoom,
    // and changing it there would only surprise the player when the next level
    // opened at a size they did not choose.
    guard playfield.phase == .playing else { return }
    playfield.viewport.zoom = min(8, max(1, value))
    playfield.viewport.clamp()
    playfield.needsDisplay = true
    syncPanelViewport()
  }

  private func retry() {
    if phase == .briefing, availableHandoverRetry != nil { retryPreviousHandoverLevel(); return }
    let skills = session?.skills ?? []
    let selectedSkill = skills.indices.contains(panel.selectedSkillIndex)
      ? skills[panel.selectedSkillIndex].name : nil
    ArcadeWindow.shared.close()
    if fanPlaying, fanQueue.indices.contains(fanQueueIndex) {
      loadCurrentFanLevel()
    } else if let url = currentNxlvURL {
      loadNxlv(url)
    } else {
      levelChanged()
    }
    if phase == .briefing { advancePhase() }
    if ArcadeStore.shared.hotSeatIsActive {
      isPaused = true; panel.isPaused = true; accumulator = 0; lastStepTime = nil
    }
    if let selectedSkill, let index = session?.skills.firstIndex(where: { $0.name == selectedSkill }) {
      panel.selectedSkillIndex = index
      panel.needsDisplay = true
    }
  }

  private func presentArcadeResult() {
    guard arcadeAutoPresent, let arcadeReport else { return }
    if sequencePlayingIdentity != nil,
       let run = sequencePlaylistStore?.activeRun {
      let title = session?.didWin == true
        ? (run.currentIndex + 1 < run.entries.count ? "Next level" : "Finish run")
        : "Retry level"
      ArcadeWindow.shared.showResult(
        arcadeReport,
        owner: window,
        retry: { [weak self] in self?.retry() },
        next: { [weak self] in self?.advancePhase() },
        replay: { [weak self] save in self?.runMovie.review(save: save) },
        continueTitle: title,
        background: playfield.levelImage,
        rewardVolume: effects.muted ? 0 : effects.volume)
      return
    }
    let hasNext = fanPlaying ? fanQueueIndex + 1 < fanQueue.count
      : flow.map { $0.currentNumber < ($0.currentRank?.levelIndices.count ?? 0) } ?? false
    ArcadeWindow.shared.showResult(arcadeReport, owner: window, retry: { [weak self] in self?.retry() },
      next: { [weak self] in self?.advancePhase() }, replay: { [weak self] save in self?.runMovie.review(save: save) },
      continueTitle: hasNext ? "Next level" : fanPlaying ? "Level select" : "Continue", background: playfield.levelImage, rewardVolume: effects.muted ? 0 : effects.volume)
  }

  @objc private func showLevelRecords() {
    if let nativeL2Window { nativeL2Window.showLevelRecords(); return }
    if let nativeL3Window { nativeL3Window.showLevelRecords(); return }
    ArcadeWindow.shared.showRecords(level: arcadeLevel, owner: window, background: playfield.levelImage)
  }

  @objc private func showHotSeat() {
    guard allowNavigationAwayFromSequence() else { return }
    ArcadeWindow.shared.showSession(owner: window)
  }

  @objc private func showProfiles() {
    let canSwitch = !sequenceIsActive && !ArcadeStore.shared.hotSeatIsActive && (nativeL2Window?.canSwitchProfile ?? nativeL3Window?.canSwitchProfile
      ?? (phase != .playing || session == nil || session?.isComplete == true))
    ArcadeWindow.shared.showProfiles(canSwitch: canSwitch, owner: window, beforeSwitch: { [weak self] in
        ReplayMovieWindow.shared.close(); self?.returnToLibrary()
      },
      afterSwitch: { [weak self] in
        guard let self else { return }
        self.progress = UserDefaults.standard.data(forKey: ArcadeStore.shared.progressKey(progressKey))
          .flatMap { try? ModernCampaignProgress(encoded: $0) } ?? ModernCampaignProgress()
        self.achievements = UserDefaults.standard.data(forKey: ArcadeStore.shared.progressKey(achievementProgressKey))
          .flatMap { try? JSONDecoder().decode(ClassicAchievementProgress.self, from: $0) } ?? ClassicAchievementProgress()
        self.achievementsWindow.update(progress: self.achievements)
        self.arcadeLevel = nil; self.arcadeReport = nil
        if self.dataSets.indices.contains(self.gamePicker.indexOfSelectedItem) { self.selectDataSet() }
        self.refreshSequelProgress(); self.renderScreen()
      }, background: nativeL2Window?.arcadeBackdrop ?? nativeL3Window?.arcadeBackdrop ?? playfield.levelImage)
  }

  private func nextLevel() {
    guard allowNavigationAwayFromSequence() else { return }
    guard currentNxlvURL == nil, let campaign else { return }
    let next = picker.indexOfSelectedItem + 1
    guard next < campaign.levels.count else {
      _ = advanceToNextTitle()
      return
    }
    picker.selectItem(at: next)
    levelChanged()
  }

  private var assignmentFocus = AssignmentFocus()
  private var gameplayKeyboard: GameplayKeyboard?

  @objc private func showLevelHints() {
    guard !GameScreen.shared.isPresented else { return }
    if let nativeL2Window { nativeL2Window.showLevelHints(); return }
    if let nativeL3Window { nativeL3Window.showLevelHints(); return }
    guard let session, phase == .playing || phase == .briefing else {
      GameScreen.shared.message("Level hints", detail: "Start a level, then choose Help > Level hints or press i.")
      return
    }
    let checked = LevelHintCatalogue.load().flatMap { catalogue, engine in
      catalogue.level(for: arcadeLevel?.conditions?.levelFingerprint ?? "", engine: engine)
    }
    let deck = checked?.deck ?? .practice(title: arcadeLevel?.title ?? "Current level",
      skills: session.skills.filter { $0.count > 0 || $0.isInfinite }.map(\.name))
    let wasPaused = isPaused
    let interruption = gameplayKeyboard?.interruptionCount
    isPaused = true; panel.isPaused = true; accumulator = 0
    screenFlash.clear(); pointerCapture.reset(); panel.needsDisplay = true
    LevelHintWindow.shared.show(deck, image: hintMap, owner: window,
      solutionSession: session as? ClassicSession, solutionSource: playfield) { [weak self, weak session] in
      guard let self, let session, self.session === session else { return }
      self.isPaused = wasPaused || self.gameplayKeyboard?.interruptionCount != interruption
      self.panel.isPaused = self.isPaused
      self.accumulator = 0; self.lastStepTime = nil; self.panel.needsDisplay = true
    }
  }

  @objc private func showKeyboardCommands() {
    if let nativeL2Window { nativeL2Window.showKeyboardCommands(); return }
    if let nativeL3Window { nativeL3Window.showKeyboardCommands(); return }
    gameplayKeyboard?.showHelp()
  }

  private func installKeyboardShortcuts() {
    ArcadeWindow.shared.confirmSessionChange = { [weak self] proceed in
      guard let self else { return }
      guard self.allowNavigationAwayFromSequence() else { return }
      let playing = !(self.nativeL2Window?.canSwitchProfile ?? self.nativeL3Window?.canSwitchProfile
        ?? (self.phase != .playing || self.session == nil || self.session?.isComplete == true))
      let sharedRun = ArcadeStore.shared.hotSeatIsActive && (self.session != nil || self.sequelIsActive)
      guard playing || sharedRun else { proceed(); return }
      GameScreen.shared.confirm("Change Hot Seat players?",
        detail: "Return to the library to change players. The current attempt keeps its owner and is saved for later.",
        actionTitle: "Save and return to library", owner: self.window, action: proceed)
    }
    ArcadeWindow.shared.prepareSession = { [weak self] in
      guard let self else { return nil }
      self.returnToLibrary()
      return self.window
    }
    ArcadeWindow.shared.finishSession = { [weak self] in
      guard let self else { return }
      self.progress = UserDefaults.standard.data(forKey: ArcadeStore.shared.progressKey(progressKey))
        .flatMap { try? ModernCampaignProgress(encoded: $0) } ?? ModernCampaignProgress()
      self.achievements = UserDefaults.standard.data(forKey: ArcadeStore.shared.progressKey(achievementProgressKey))
        .flatMap { try? JSONDecoder().decode(ClassicAchievementProgress.self, from: $0) } ?? ClassicAchievementProgress()
      self.achievementsWindow.update(progress: self.achievements)
      self.refreshSequelProgress(); self.rebuildLibrary()
    }
    let keyboard = GameplayKeyboard(window: window)
    gameplayKeyboard = keyboard
    keyboard.hints = { [weak self] in self?.showLevelHints() }
    keyboard.settings = { [weak self] in self?.showSettings() }
    keyboard.pauseOnInterruption = { [weak self] in self?.settings.pauseOnInterruption ?? true }
    keyboard.onInterruption = { [weak self] in self?.interruptGameplay() }
    keyboard.controllerEnabled = { [weak self] in self?.settings.controllerEnabled ?? false }
    keyboard.controllerTapSpeed = { [weak self] in self?.settings.controllerTapSpeed ?? true }
    keyboard.controllerMappings = { [weak self] in self?.settings.controllerMappings ?? [:] }
    keyboard.controllerSwapSticks = { [weak self] in self?.settings.controllerSwapSticks ?? false }
    keyboard.ownsController = { [weak self] in self?.sequelIsActive == false }
    keyboard.retry = { [weak self] in self?.retry() }
    keyboard.rewind = { [weak self] in self?.rewind(seconds: 2) }
    keyboard.controllerRewindHeld = { [weak self] held in
      guard let self else { return }
      if held { self.beginContinuousRewind() }
      else if self.rewindHeld { self.endContinuousRewind() }
    }
    keyboard.step = { [weak self] direction in
      if direction < 0 { self?.stepBackward() } else { self?.stepForward() }
    }
    keyboard.endRun = { [weak self] in
      guard let self, self.session?.isComplete == false else { return }
      if self.session?.canUndoNuke == true { self.handle(.nuke); return }
      GameScreen.shared.confirm("End this run?", detail: "Start the nuke countdown for the remaining lemmings.",
        actionTitle: "Start nuke", owner: self.window) { [weak self] in self?.handle(.nuke) }
    }
    keyboard.menuActive = { [weak self] in self?.sequelIsActive == false && self?.phase != .playing }
    keyboard.menuKey = { [weak self] key in
      guard let self else { return }
      switch key {
      case "\r": self.advancePhase()
      case "up", "left": self.moveRankChoice(-1)
      case "down", "right": self.moveRankChoice(1)
      case "\u{1b}":
        if !self.retreatFanScreen() { self.returnToLibrary() }
      default: break
      }
    }
    keyboard.active = { [weak self] in
      guard let self else { return false }
      return self.phase == .playing && !GameScreen.shared.isPresented && !self.sequelIsActive && self.session?.isComplete == false
    }
    keyboard.assignSelected = { [weak self] in
      guard let self, let id = self.playfield.assignmentHighlight.target ?? self.playfield.pointerLemmingID else { return }
      self.assign(id)
    }
    keyboard.togglePause = { [weak self] in self?.togglePause() }
    keyboard.movePointer = { [weak self] dx, dy in self?.playfield.moveControllerPointer(dx, dy) }
    keyboard.panCamera = { [weak self] dx, dy in
      guard let self else { return }
      self.playfield.assignmentHighlight.clear()
      self.playfield.viewport.scroll(dx: dx, dy: dy); self.playfield.needsDisplay = true; self.syncPanelViewport()
    }
    keyboard.focusUnassigned = { [weak self] direction in
      guard let self, let session = self.session else { return }
      guard let id = self.assignmentFocus.next(activeIDs: session.lemmings.map(\.id), direction: direction) else {
        self.setStatus("No unassigned lemmings"); return
      }
      self.focusLemming(id)
    }
    keyboard.focusLast = { [weak self] in
      guard let self, let id = self.assignmentFocus.lastID else { return }
      self.focusLemming(id)
    }
    keyboard.repeatAssignment = { [weak self] in
      guard let self, let skill = self.assignmentFocus.lastSkill,
        let id = self.playfield.assignmentHighlight.target ?? self.playfield.pointerLemmingID else { return }
      let previous = self.panel.selectedSkillIndex
      self.panel.selectedSkillIndex = skill; self.assign(id); self.panel.selectedSkillIndex = previous
    }
    keyboard.speedControl = speedControl
    keyboard.modern = { [weak self] in self?.settings.modernControlsEnabled ?? true }
    speedControl.onChange = { [weak self] in
      guard let self else { return }
      self.accumulator = 0
      self.panel.isFastForward = self.isFastForward
      self.panel.speedChoiceLabel = self.speedControl.choiceLabel
      self.panel.speedLabel = self.speedControl.panelLabel
      self.panel.needsDisplay = true; self.updateStatus()
    }
    panel.onSpeedPress = { [weak self] time, count in
      guard let self, self.phase == .playing, self.session?.isComplete == false else { return }
      self.speedControl.pointerDown(at: time, clickCount: count)
    }
    panel.onSpeedRelease = { [weak self] time in self?.speedControl.release(.mouse, at: time) }
    panel.onSpeedStep = { [weak self] direction, time in self?.speedControl.step(direction, at: time) }
    panel.onSpeedClick = { [weak self] time, count in
      guard let self, self.phase == .playing, self.session?.isComplete == false else { return }
      self.speedControl.tap(at: time, clickCount: count)
    }
    keyboard.cycle = { [weak self] direction in
      guard let self, let session = self.session,
        let index = SkillShortcuts.cycle(from: self.panel.selectedSkillIndex, direction: direction,
          available: session.skills.map { $0.isInfinite || $0.count > 0 }) else { return }
      self.handle(.skill(index))
    }
    keyboard.rate = { [weak self] delta in
      guard let self else { return }
      let adjustment = self.session?.rateLabel == "Interval" ? -delta : delta
      self.handle(adjustment < 0 ? .rateDown : .rateUp)
    }
    keyboard.centre = { [weak self] entrance in
      guard let self, let session = self.session, let x = entrance ? session.entranceX : session.exitX else { return }
      if let y = entrance ? session.entranceY : session.exitY {
        self.playfield.viewport.scroll(dx: 0, dy: Double(y) - self.playfield.viewport.scrollY - self.playfield.viewport.visibleSize.height / 2)
      }
      self.scrollBy(Double(x) - self.playfield.viewport.scrollX - self.playfield.viewport.visibleSize.width / 2)
    }
    keyboard.overlayControls = { [weak self] in
      guard let self else { return [] }
      return self.tubeIsActive ? (self.crtView.accessibleContent?() ?? []) : self.panel.accessibleControls(owner: self.panel)
    }
    keyboard.skillNames = { [weak self] in self?.session?.skills.map(\.name) ?? [] }
    keyboard.contextCommands = {
      [KeyboardCommand(keys: "← / →", action: "Pan the level", group: "Camera"),
       KeyboardCommand(keys: "N", action: "Next level", group: "Gameplay"),
       KeyboardCommand(keys: "Q", action: "Abandon level", group: "Gameplay"),
       KeyboardCommand(keys: "↑ / ↓", action: "Choose rank", group: "Menus & results"),
       KeyboardCommand(keys: "Return / Space", action: "Continue or start level", group: "Menus & results"),
       KeyboardCommand(keys: "V / S", action: "Review / save replay after a result", group: "Menus & results")]
    }
    keyboard.help = { [weak self] in
      let names = self?.session?.skills.map(\.name) ?? []
      return SkillShortcuts(names: names).hint(names: names, modern: self?.settings.modernControlsEnabled ?? true) + "\n\nSpace / P: play or pause\nHold , / <: scrub backward\nHold . / >: scrub forward\nTap , / .: step one tick\nZ: rewind 2 seconds\nX: nuke"
    }
    keyboard.pauseForHelp = { [weak self] in
      guard let self else { return {} }
      let wasPaused = self.isPaused
      let interruption = self.gameplayKeyboard?.interruptionCount
      if !wasPaused { self.togglePause() }
      return { [weak self] in
        guard let self, !wasPaused, self.isPaused, self.gameplayKeyboard?.interruptionCount == interruption else { return }
        self.togglePause()
      }
    }
    keyboard.mainMenu = { [weak self] in self?.returnToLibrary() }
    keyboard.escape = { [weak self, weak keyboard] in
      guard let self else { return }
      if self.cancelRewindToOrigin() { return }
      let resume = keyboard?.pauseForHelp() ?? {}
      let alert = NSAlert(); alert.messageText = "Paused"
      alert.addButton(withTitle: "Resume"); alert.addButton(withTitle: "Retry level")
      alert.addButton(withTitle: "Level hints")
      alert.addButton(withTitle: "Quit to main menu")
      let quitResponse = NSApplication.ModalResponse(
        rawValue: NSApplication.ModalResponse.alertThirdButtonReturn.rawValue + 1)
      alert.beginSheetModal(for: self.window) { [weak self] response in
        if response == .alertSecondButtonReturn { self?.retry() }
        else if response == quitResponse {
          // Leave the run rather than resume it. Its normal checkpoint or
          // saved sequence position remains available.
          guard let self else { return }
          if self.sequenceIsActive { self.returnToLibrary() }
          else { self.showTitle() }
        }
        else {
          resume()
          if response == .alertThirdButtonReturn {
            DispatchQueue.main.async { [weak self] in self?.showLevelHints() }
          }
        }
      }
    }

    NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
      guard let self else { return event }
      guard !GameScreen.shared.isPresented, !self.sequelIsActive, event.window === self.window, self.window?.attachedSheet == nil,
        event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
      if self.window?.firstResponder is NSTextView { return event }

      if event.type == .keyUp, event.keyCode == 6 {
        guard self.rewindHeld else { return event }
        self.endContinuousRewind()
        return nil
      }
      if event.type == .keyUp, event.charactersIgnoringModifiers == "," {
        self.backwardKeyHeld = false
        self.backwardKeyTimer?.invalidate()
        self.backwardKeyTimer = nil
        if self.rewindHeld { self.endContinuousRewind() }
        return nil
      }
      if event.type == .keyUp, event.charactersIgnoringModifiers == "." {
        self.forwardKeyHeld = false
        self.forwardKeyTimer?.invalidate()
        self.forwardKeyTimer = nil
        if self.forwardHeld { self.endContinuousStepForward() }
        return nil
      }

      if event.keyCode == 122 || event.charactersIgnoringModifiers?.lowercased() == "i" {
        if !event.isARepeat { self.showLevelHints() }
        return nil
      }

      let scrollStep = 24.0
      switch event.keyCode {
      case 123:
        if event.modifierFlags.contains(.shift) { self.stepBackward() }
        else { self.scrollBy(-scrollStep) }
        return nil
      case 124:
        if event.modifierFlags.contains(.shift) { self.stepForward() }
        else { self.scrollBy(scrollStep) }
        return nil
      default: break
      }

      guard let characters = event.charactersIgnoringModifiers?.lowercased() else { return event }
      if self.phase == .results, self.session?.isComplete == true {
        if characters == "v" { self.runMovie.review(); return nil }
        if characters == "s" { self.runMovie.review(save: true); return nil }
      }
      if self.phase == .playing, let session = self.session,
        let index = SkillShortcuts(names: session.skills.map(\.name)).index(for: characters, current: self.panel.selectedSkillIndex, modern: self.settings.modernControlsEnabled) {
        self.handle(.skill(index))
        return nil
      }
      // Screen keys come first, so they are not eaten by gameplay bindings.
      if let screen = self.flow?.screen, !screen.isPlaying {
        switch event.keyCode {
        case 125: self.moveRankChoice(1); return nil     // down
        case 126: self.moveRankChoice(-1); return nil    // up
        case 36, 76: self.advancePhase(); return nil     // return, enter
        case 53:                                          // escape
          if self.retreatFanScreen() { return nil }
          if screen == .quitConfirm { self.cancelQuit() }
          else { self.returnToLibrary() }
          return nil
        default: break
        }
        if characters == " " { self.advancePhase(); return nil }
        if characters == "q" { self.requestQuit(); return nil }
      }

      switch characters {
      case "z":
        if !event.isARepeat { self.beginContinuousRewind() }
      case ",":
        if !event.isARepeat {
          self.backwardKeyHeld = true
          guard self.stepBackward() else {
            self.backwardKeyHeld = false
            return nil
          }
          self.backwardKeyTimer?.invalidate()
          self.backwardKeyTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
              guard let self, self.backwardKeyHeld else { return }
              _ = self.beginContinuousRewind(preservingOrigin: true, advanceImmediately: false)
            }
          }
        }
      case ".":
        if !event.isARepeat {
          self.forwardKeyHeld = true
          guard self.stepForward() else {
            self.forwardKeyHeld = false
            return nil
          }
          self.forwardKeyTimer?.invalidate()
          self.forwardKeyTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
              guard let self, self.forwardKeyHeld else { return }
              self.beginContinuousStepForward(advanceImmediately: false)
            }
          }
        }
      case "\r":
        if self.phase == .playing { return event }
        self.advancePhase()
      case "q":
        if var current = self.flow {
          current.abandonLevel()
          self.flow = current
          self.renderScreen()
        }
      case "n": self.nextLevel()
      case "r": self.retry()
      case " ":
        if self.phase == .playing { self.togglePause() } else { self.advancePhase() }
      case "p": self.togglePause()
      case "f": return event
      case "x": self.handle(.nuke)
      default: return event
      }
      return nil
    }
  }

  // MARK: - Rewind

  private func beginContinuousRewind(preservingOrigin: Bool = false, advanceImmediately: Bool = true) -> Bool {
    guard let session, session.supportsRewind else {
      setStatus("This ruleset cannot rewind yet.")
      return false
    }
    guard !rewindHeld else { return false }
    if !preservingOrigin { rewindOriginTick = session.currentTick }
    rewindHeld = true
    rewindTimer?.invalidate()
    setRewindAudioDucked(true)
    playfield.beginRewindCue(at: session.currentTick)
    rewindTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { _ = self?.performRewind(seconds: 0.20) }
    }
    guard advanceImmediately else { return true }
    return performRewind(seconds: 0.20)
  }

  private func endContinuousRewind() {
    rewindHeld = false
    rewindTimer?.invalidate()
    rewindTimer = nil
    effects.silence()
    setRewindAudioDucked(false)
    playfield.endRewindCue()
  }

  /// Restores the point where the current transport gesture started.
  private func cancelRewindToOrigin() -> Bool {
    guard let origin = rewindOriginTick, let session, session.currentTick != origin else { return false }
    if rewindHeld { endContinuousRewind() }
    while session.currentTick < origin, session.stepForward() {}
    while session.currentTick > origin, session.stepBackward() {}
    guard session.currentTick == origin else { return false }
    rewindOriginTick = nil
    isPaused = true; panel.isPaused = true; accumulator = 0
    effects.silence(); setRewindAudioDucked(false); refreshAfterSeek()
    return true
  }

  private func setRewindAudioDucked(_ active: Bool) {
    guard rewindAudioDucked != active else { return }
    rewindAudioDucked = active
    if active {
      let level = settings.musicVolume * 0.18
      music.setVolume(level); soundtrack.setVolume(level); dj.setVolume(level)
    } else {
      music.setVolume(settings.musicVolume)
      soundtrack.setVolume(settings.musicVolume)
      dj.setVolume(settings.musicVolume)
    }
  }

  private func beginContinuousStepForward(advanceImmediately: Bool = true) {
    guard phase == .playing, session?.supportsRewind == true else { return }
    guard !forwardHeld else { return }
    forwardHeld = true
    forwardTimer?.invalidate()
    forwardTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, self.stepForward() else { self?.endContinuousStepForward(); return }
      }
    }
    guard !advanceImmediately || stepForward() else {
      endContinuousStepForward()
      return
    }
  }

  private func endContinuousStepForward() {
    forwardHeld = false
    forwardTimer?.invalidate()
    forwardTimer = nil
  }

  @discardableResult
  private func performRewind(seconds: Double) -> Bool {
    guard let session, session.supportsRewind, session.rewind(seconds: seconds) else {
      if rewindHeld { endContinuousRewind() }
      return false
    }
    effects.playRewindScrub()
    isPaused = true
    panel.isPaused = true
    refreshAfterSeek()
    return true
  }

  private func rewind(seconds: Double) {
    guard let session, session.supportsRewind else {
      setStatus("This ruleset cannot rewind yet.")
      return
    }
    rewindOriginTick = rewindOriginTick ?? session.currentTick
    setRewindAudioDucked(true)
    playfield.beginRewindCue(at: session.currentTick)
    guard performRewind(seconds: seconds) else {
      setRewindAudioDucked(false)
      playfield.endRewindCue()
      setStatus("Already at the start of the history.")
      return
    }
    setRewindAudioDucked(false)
    playfield.endRewindCue()
  }

  @discardableResult
  private func stepBackward() -> Bool {
    guard let session, session.supportsRewind else { return false }
    rewindOriginTick = rewindOriginTick ?? session.currentTick
    setRewindAudioDucked(true)
    playfield.beginRewindCue(at: session.currentTick)
    guard session.stepBackward() else {
      setRewindAudioDucked(false)
      playfield.endRewindCue()
      return false
    }
    isPaused = true
    panel.isPaused = true
    refreshAfterSeek()
    effects.playRewindScrub()
    setRewindAudioDucked(false)
    playfield.endRewindCue()
    return true
  }

  @discardableResult
  private func stepForward() -> Bool {
    guard phase == .playing, let session else { return false }
    let previousExplosions = Set(session.lemmings.filter { $0.pose == .explosion }.map(\.id))
    countdownWarning.reset(seconds: session.remainingSeconds)
    guard session.stepForward() else { return false }
    if countdownWarning.update(seconds: session.remainingSeconds) { effects.play(.builderWarning) }
    effects.play(session.lastCues)
    dj.updateTelemetry(djTelemetry(session))
    captureReplayFrame()
    isPaused = true
    panel.isPaused = true
    refreshAfterSeek()
    flashExplosions(previous: previousExplosions)
    finishSessionIfNeeded()
    return true
  }

  /// Redraws after moving through history, without playing sounds again.
  private func refreshAfterSeek() {
    updateFailureMood()
    if let session { assignmentFocus.rewind(to: session.currentTick) }
    if let session { playfield.updateRewindCue(at: session.currentTick) }
    playfield.assignmentHighlight.clear()
    screenFlash.clear()
    accumulator = 0
    playfield.needsDisplay = true
    panel.needsDisplay = true
    updateStatus()
  }

  private func updateFailureMood() {
    guard phase == .playing, let session else {
      failureMood.set(active: false)
      return
    }
    failureMood.set(active: !session.isComplete && !session.canStillReachRequirement)
  }

  private func focusLemming(_ id: Int) {
    guard let lem = session?.lemmings.first(where: { $0.id == id }) else { return }
    playfield.viewport.scroll(dx: Double(lem.x) - playfield.viewport.scrollX - playfield.viewport.visibleSize.width / 2,
      dy: Double(lem.y) - playfield.viewport.scrollY - playfield.viewport.visibleSize.height / 2)
    playfield.assignmentHighlight.show(id); playfield.needsDisplay = true; syncPanelViewport()
  }

  private func scrollBy(_ dx: Double) {
    playfield.viewport.scroll(dx: dx, dy: 0)
    playfield.needsDisplay = true
    syncPanelViewport()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

#if !APP_INTEGRATION_TESTS
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
#endif
