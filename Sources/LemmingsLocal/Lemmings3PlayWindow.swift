import AppKit
import CryptoKit
import NxlvKit

@MainActor final class Lemmings3PlayWindow: NSWindowController, NSWindowDelegate {
    struct LevelSelection: Equatable, Sendable {
        let tribe: Lemmings3ClassicCampaign.Tribe
        let level: Int
    }

    struct BrowserLevel: Sendable {
        let selection: LevelSelection
        let levelID: String
        let sourceRevision: String
        let isAvailable: Bool
    }

    var onReturnToLibrary: (() -> Void)?
    var onProgressChanged: (() -> Void)?
    var onCampaignCompleted: (() -> Void)?
    var onShowSettings: (() -> Void)?
    /**
     * Handles Continue for a level sequence. The argument reports whether the level was won.
     */
    var onSequenceContinue: ((Bool) -> Bool)?
    var sequenceContinueTitle = "Next level"
    /**
     * Controls whether this run can update campaign, recovery, replay and verified records.
     */
    var recordsCampaignProgress = true
    private var usesSharedWindow = false

    /// Attach the engine after loading succeeds, so a failed load leaves the current game intact.
    func attach(to host: NSWindow) {
        let content = window?.contentView
        window?.delegate = nil
        window?.contentView = nil
        window = host
        gameplayKeyboard?.bind(to: host)
        timelineTransport = makeTimelineTransport(for: host)
        usesSharedWindow = true
        campaignFinished = Self.savedCompletion(root: dataRoot) == 90
        host.contentView = content
        host.makeFirstResponder(content)
    }

    override func close() {
        if usesSharedWindow { onReturnToLibrary?() }
        else { super.close() }
    }

    private var game: Lemmings3Runtime
    private var initial: Lemmings3Runtime { didSet { arcadeLevelSnapshot = nil } }
    private let dataRoot: URL
    private var style: Lemmings3Style
    private var sprites: Lemmings3Sprites
    private var campaign: Lemmings3ClassicCampaign
    private var availability: [String?]
    private var progressKey: String
    private let recoveryStore = RunRecoveryStore()
    private var recoveryInputs: [L3RunRecovery.Input] = []
    private var recoveryProgress: Lemmings3ClassicCampaign.Progress?
    private var recoveryInitialHash = ""
    private var lastCheckpointTime = 0.0
    private var recorded = false
    private var arcadeRunID = UUID()
    private var arcadeProfileID = ArcadeProfile.legacyID
    private var arcadeHotSeatID: String?
    private var skillAssignments: [String: Int] = [:]
    private var toolUses: [String: Int] = [:]
    private var arcadeReport: ArcadeReport?
    var canSwitchProfile: Bool { game.isComplete || (game.tick == 0 && skillAssignments.isEmpty) }
    private var arcadeLevelSnapshot: ArcadeLevel?
    private var arcadeLevel: ArcadeLevel {
        if let arcadeLevelSnapshot { return arcadeLevelSnapshot }
        let number = campaign.tribe.firstLevel + campaign.index
        let path = dataRoot.appendingPathComponent(String(format: "LEVELS/LEVEL%03d.DAT", number))
        let hash = (try? Data(contentsOf: path)).map(ArcadeStore.fingerprint) ?? "\(number)"
        let c = game.configuration
        let conditions = TrolleyConditions(gameID: "lemmings3", packID: "chronicles", levelID: String(number),
            levelFingerprint: hash + ":" + TrolleyCapture.contentFingerprint(root: dataRoot),
            rulesetVersion: "l3-native-preview-v1", physicsMode: "l3-native-preview-v1",
            population: c.total + c.extras.count, rescueRequirement: 1, startingSkills: [:], timeLimitSeconds: Double(c.timeLimit),
            modifiers: ["releaseInterval": String(c.releaseInterval), "releaseDelay": String(c.releaseDelay),
                        "reserves": String(c.total), "extras": String(c.extras.count)])
        return ArcadeLevel(id: "l3:" + hash, title: "\(campaign.tribe.title) \(campaign.index + 1)",
            game: "Lemmings 3", rules: "L3 native preview v1",
            total: c.total + c.extras.count, required: 1, conditions: conditions)
    }
    private let warningSound = SoundEffectPlayer()
    private let music = ModuleMusicPlayer()
    private let dj = AdaptiveDJPlayer()
    private let failureMood = FailureMoodTransition()
    private var musicGain: Float = 0.8
    private var audioSettings = ClassicSettings()
    private let runMovie = RunMovie()
    private var originalMovie: OriginalMoviePlayer?
    private var countdownWarning = LastSecondsWarning()
    private var campaignFinished = false
    private let canvas = Lemmings3Canvas()
    private var canAdvance = false
    private var menuTribe = 0
    private var menuLevel = 0
    private var pendingTool: Int?
    private var selected = 0
    private var paused = true
    private var assignmentFocus = AssignmentFocus()
    private var gameplayKeyboard: GameplayKeyboard?
    func showKeyboardCommands() { gameplayKeyboard?.showHelp() }
    private let speedControl = GameSpeedControl(legacyMultiplier: 8)
    private var fast: Bool {
        get { speedControl.isFast }
        set { speedControl.setFast(newValue) }
    }
    private var timer: Timer?
    private var lastTime = ProcessInfo.processInfo.systemUptime
    private var accumulator = 0.0
    private var message = "Choose an action, then click a lemming. Walker turns or releases a blocker."
    private var rewindTimer: Timer?
    private var rewindHeld = false
    private var forwardTimer: Timer?
    private var forwardHeld = false
    private var timelineTransport: TimelineKeyTransport?
    private var rewindAudioDucked = false
    private var rewindOriginState: Lemmings3Runtime?
    private var rewindOriginInputs: [L3RunRecovery.Input] = []
    private var rewindOriginAssignments: [String: Int] = [:]
    private var rewindOriginToolUses: [String: Int] = [:]

    private struct Session {
        var campaign: Lemmings3ClassicCampaign
        let style: Lemmings3Style, sprites: Lemmings3Sprites
        let availability: [String?], progressKey: String
    }
    private static func storageIdentity(_ root: URL) -> String {
        let bundled = (try? BundledGameResources.lemmings3())?.standardizedFileURL == root.standardizedFileURL
        return bundled ? "bundled" : root.standardizedFileURL.path
    }
    private static func session(root: URL, tribe: Lemmings3ClassicCampaign.Tribe) throws -> Session {
        var sequence = try Lemmings3ClassicCampaign(root: root, tribe: tribe)
        let key = ArcadeStore.shared.progressKey("nativeL3\(tribe.title)Preview.v1." + storageIdentity(root))
        if let data = UserDefaults.standard.data(forKey: key), let progress = try? JSONDecoder().decode(Lemmings3ClassicCampaign.Progress.self, from: data) { try? sequence.restore(progress) }
        let decodedStyle = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: tribe.rawValue)
        let availability: [String?] = sequence.levels.map { entry in
            do {
                let perm = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS", entry.permanentObjectsReference))))
                let temp = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS", entry.temporaryObjectsReference))))
                _ = try Lemmings3Runtime(level: entry, style: decodedStyle, permanent: perm, temporary: temp)
                return nil
            } catch { return String(describing: error) }
        }
        if availability[sequence.index] != nil {
            guard let available = availability.firstIndex(where: { $0 == nil }) else { throw SequelDataError.invalid("No supported levels in the \(tribe.title) tribe yet.") }
            try sequence.select(available)
        }
        let prefix = String(format: "GRAPHICS/TRIBE%03d", tribe.spriteStyle)
        let sprites = try Lemmings3Sprites(index: Data(contentsOf: root.appendingPathComponent(prefix + ".IND")),
            commands: Data(contentsOf: root.appendingPathComponent(prefix + ".CMP")))
        return Session(campaign: sequence, style: decodedStyle, sprites: sprites, availability: availability, progressKey: key)
    }
    init(root: URL, recovery: RunRecovery? = nil, selection: LevelSelection? = nil,
         expectedLevelID: String? = nil,
         expectedSourceRevision: String? = nil,
         recordsCampaignProgress: Bool = true,
         expectedRecoveryEngine: String = RunRecovery.bundledEngine) throws {
        if let recovery {
            _ = try recovery.validated()
            // A newer engine must not strand a saved run; the replay below checks the state.
            guard recovery.l3 != nil, recovery.profileID == ArcadeStore.shared.playingProfileID,
              recovery.hotSeatID == ArcadeStore.shared.hotSeatID else { throw RunRecoveryError.differentGame }
        }
        if let expectedSourceRevision {
            guard let selection else {
                throw SequelDataError.invalid("The selected Lemmings 3 level is no longer available.")
            }
            let source = LevelPreviewSource.lemmings3(
                root: root, selection: selection, expectedLevelID: expectedLevelID ?? "")
            guard try source.sourceRevision() == expectedSourceRevision else {
                throw SequelDataError.invalid(
                    "The selected Lemmings 3 level data changed. Open Level Select and choose it again.")
            }
        }
        dataRoot = root
        self.recordsCampaignProgress = recordsCampaignProgress
        let selectedTribe = recovery?.l3?.progress.tribe ?? selection?.tribe
            ?? Lemmings3ClassicCampaign.Tribe(rawValue: UserDefaults.standard.integer(
                forKey: ArcadeStore.shared.progressKey("nativeL3SelectedTribe.v1." + Self.storageIdentity(root))))
            ?? .classic
        let session = try Self.session(root: root, tribe: selectedTribe)
        var sequence = session.campaign
        if let saved = recovery?.l3 { try sequence.restore(saved.progress) }
        if recovery == nil, let selection {
            guard session.availability.indices.contains(selection.level),
                  session.availability[selection.level] == nil else {
                throw SequelDataError.invalid("This Lemmings 3 level is not available.")
            }
            let currentLevelID = SHA256.hash(data: sequence.levels[selection.level].rawData)
                .map { String(format: "%02x", $0) }.joined()
            guard expectedLevelID == nil || currentLevelID == expectedLevelID else {
                throw SequelDataError.invalid(
                    "The selected Lemmings 3 level changed. Open Level Select and choose it again.")
            }
            try sequence.select(selection.level)
        }
        style = session.style; sprites = session.sprites; availability = session.availability; progressKey = session.progressKey
        campaign = sequence
        let level = sequence.levels[sequence.index]
        let permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
        let temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
        game = try Lemmings3Runtime(level: level, style: style, permanent: permanent, temporary: temporary, total: sequence.population)
        initial = game
        if let recovery, let saved = recovery.l3 {
            let levelPath = root.appendingPathComponent(String(format: "LEVELS/LEVEL%03d.DAT", sequence.tribe.firstLevel + sequence.index))
            let fingerprint = ArcadeStore.fingerprint(try Data(contentsOf: levelPath)) + ":" + TrolleyCapture.contentFingerprint(root: root)
            // Compare the level only. Other data files may change between builds;
            // the replay still requires the exact saved state.
            guard fingerprint.split(separator: ":").first == recovery.levelFingerprint.split(separator: ":").first
            else { throw RunRecoveryError.differentGame }
            game = try saved.restore(initial: initial, checkpoint: recovery)
        }
        let scene = try Lemmings3Scene(level: level, style: style, permanent: permanent, temporary: temporary)
        super.init(window: NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1050, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false))
        guard let window else { return }
        failureMood.onChange = { [weak self] amount in
            guard let self else { return }
            self.canvas.failureMoodAmount = amount
            self.music.setTempoScale(1 - 0.28 * Double(amount))
            self.dj.setPlaybackRate(1 - 0.28 * Double(amount))
            self.canvas.needsDisplay = true
        }
        try warningSound.loadLemmings3Sounds(root: root)
        window.title = "Lemmings 3 — \(campaign.tribe.title) \(campaign.index + 1) — Experimental native preview"
        window.delegate = self; window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 850, height: 540)
        NotificationCenter.default.addObserver(self, selector: #selector(artworkChanged),
            name: SequelArtworkPreference.changed, object: nil)
        canvas.frame = window.contentView?.bounds ?? .zero
        canvas.autoresizingMask = [.width, .height]
        window.contentView = canvas
        canvas.onPanel = { [weak self] slot, clicks in
            guard let self else { return }
            self.pendingTool = nil; self.canvas.directionPoint = nil
            switch slot {
            case 0...4: self.selected = slot; self.refresh()
            case 6: self.speedControl.tap(clickCount: clicks)
            case 7: self.togglePause()
            case 8: if clicks >= 2 { self.confirmEndRun() }
            default: break
            }
        }
        canvas.onMenu = { [weak self] in self?.showGameMenu() }
        canvas.onMenuRow = { [weak self] row in self?.menuAction(row) }
        canvas.onCancelDirection = { [weak self] in self?.pendingTool = nil }
        canvas.onDirection = { [weak self] direction in
            guard let self, let id = self.pendingTool else { return }
            self.pendingTool = nil; self.canvas.directionPoint = nil
            self.applyAction(to: id, direction: direction)
        }
        try canvas.load(scene: scene, style: style, permanent: permanent, temporary: temporary, sprites: sprites, root: dataRoot, terrainStyle: level.style)
        canvas.resetCamera(level)
        canvas.onClick = { [weak self] x, y in self?.assign(x: x, y: y) }
        canvas.onKey = { [weak self] key in
            guard let self else { return }
            if self.game.isComplete, key.lowercased() == "v" { self.runMovie.review(); return }
            if self.game.isComplete, key.lowercased() == "s" { self.runMovie.review(save: true); return }
            if key.lowercased() == "z" { _ = self.rewind(seconds: 2) }
            else if let index = SkillShortcuts(names: Array(Lemmings3Panel.names.prefix(5))).index(for: key, current: self.selected, modern: self.audioSettings.modernControlsEnabled) { self.pendingTool = nil; self.canvas.directionPoint = nil; self.selected = index; self.refresh() }
            else if key == " " { self.togglePause() }
            else if key == "." { self.singleStep() }
            else if key.lowercased() == "r" { self.restart() }

            else if key == "\u{1b}" { self.showGameMenu() }
        }
        let keyboard = GameplayKeyboard(window: window)
        gameplayKeyboard = keyboard
        canvas.timeline.enabled = { [weak self] action in
            guard let self, self.canvas.menuRows == nil else { return false }
            let game = self.game
            switch action {
            case .rewind, .backward: return game.tick > 0
            case .forward: return !game.isComplete || self.canStepForward
            case .hints: return true
            }
        }
        canvas.timeline.perform = { [weak keyboard] action in
            switch action {
            case .rewind: keyboard?.rewind?()
            case .backward: keyboard?.step?(-1)
            case .forward: keyboard?.step?(1)
            case .hints: keyboard?.hints?()
            }
        }
        keyboard.active = { [weak self] in
            guard let self else { return false }
            return self.canvas.menuRows == nil && !self.game.isComplete
        }
        keyboard.assignSelected = { [weak self] in
            guard let self else { return }
            if self.pendingTool != nil { self.canvas.confirmControllerDirection(); return }
            guard let id = self.canvas.assignmentHighlight.target ?? self.canvas.pointerTarget,
                  let lem = self.game.lemmings.first(where: { $0.id == id && $0.active }) else { return }
            if self.selected == 3 && (lem.tool == .bricks || lem.tool == .spade) {
                self.pendingTool = id; self.canvas.directionPoint = CGPoint(x: lem.x, y: lem.y); self.refresh()
            } else { self.applyAction(to: id, direction: .right) }
        }
        keyboard.togglePause = { [weak self] in self?.togglePause() }
        keyboard.movePointer = { [weak self] dx, dy in self?.canvas.moveControllerPointer(dx, dy) }
        keyboard.panCamera = { [weak self] dx, dy in self?.canvas.controllerPan(dx, dy) }
        keyboard.menuActive = { [weak self] in self?.canvas.menuRows != nil }
        keyboard.menuKey = { [weak self] key in self?.canvas.controllerMenuKey(key) }
        keyboard.focusUnassigned = { [weak self] direction in
            guard let self, self.pendingTool == nil else { return }
            guard let id = self.assignmentFocus.next(activeIDs: self.game.lemmings.filter(\.active).map(\.id), direction: direction) else {
                self.message = "No unassigned lemmings"; self.canvas.assignmentHighlight.showNotice(self.message); self.refresh(); return
            }
            self.canvas.focusLemming(id)
        }
        keyboard.focusLast = { [weak self] in
            guard let self, self.pendingTool == nil, let id = self.assignmentFocus.lastID else { return }
            self.canvas.focusLemming(id)
        }
        keyboard.repeatAssignment = { [weak self] in
            guard let self, self.pendingTool == nil, let skill = self.assignmentFocus.lastSkill,
                  let id = self.canvas.assignmentHighlight.target ?? self.canvas.pointerTarget,
                  let lem = self.game.lemmings.first(where: { $0.id == id && $0.active }) else { return }
            let previous = self.selected
            self.selected = skill
            if skill == 3 && (lem.tool == .bricks || lem.tool == .spade) {
                self.pendingTool = id; self.canvas.directionPoint = CGPoint(x: lem.x, y: lem.y)
                self.refresh()
            } else { self.applyAction(to: id, direction: .right); self.selected = previous; self.refresh() }
        }
        canvas.onSpeedPress = { [weak self] time, count in self?.speedControl.pointerDown(at: time, clickCount: count) }
        canvas.onSpeedRelease = { [weak self] time in self?.speedControl.release(.mouse, at: time) }
        canvas.onSpeedStep = { [weak self] direction, time in self?.speedControl.step(direction, at: time) }
        keyboard.speedControl = speedControl
        speedControl.onMusicPitchChange = { [weak self] cents in
            self?.music.setSpeedPitch(cents)
            self?.dj.setSpeedPitch(cents)
        }
        keyboard.modern = { [weak self] in self?.audioSettings.modernControlsEnabled ?? true }
        speedControl.onChange = { [weak self] in self?.accumulator = 0; self?.refresh() }
        keyboard.cycle = { [weak self] direction in
            guard let self else { return }
            self.pendingTool = nil; self.canvas.directionPoint = nil
            self.selected = SkillShortcuts.cycle(from: self.selected, direction: direction, available: Array(repeating: true, count: 5)) ?? self.selected
            self.refresh()
        }
        keyboard.centre = { [weak self] entrance in self?.canvas.centre(onEntrance: entrance) }
        keyboard.mainMenu = { [weak self] in
            guard let self else { return }
            self.paused = true; self.pendingTool = nil; self.canvas.directionPoint = nil
            self.saveCheckpoint(immediately: true)
            if let exit = self.onReturnToLibrary { exit() } else { self.showGameMenu() }
        }
        keyboard.escape = { [weak self] in
            guard let self else { return }
            if self.cancelRewindToOrigin() { return }
            if self.pendingTool != nil || self.canvas.directionPoint != nil {
                self.pendingTool = nil; self.canvas.directionPoint = nil; self.refresh()
            } else { self.showGameMenu() }
        }
        keyboard.overlayControls = { [weak self] in self?.canvas.accessibilityChildren() ?? [] }
        keyboard.skillNames = { Array(Lemmings3Panel.names.prefix(5)) }
        keyboard.help = { [weak self] in
            let names = Array(Lemmings3Panel.names.prefix(5))
            return SkillShortcuts(names: names).hint(names: names, modern: self?.audioSettings.modernControlsEnabled ?? false) + "\n\nSpace: pause\nR: retry\nHold , / <: scrub backward\nHold . / >: scrub forward after rewind\nTap , / .: step one tick\nZ: rewind 2 seconds"
        }
        keyboard.contextCommands = {
            [KeyboardCommand(keys: "← / → / ↑ / ↓", action: "Pan the level", group: "Camera"),
             KeyboardCommand(keys: "V / S", action: "Review / save replay after a result", group: "Menus & results"),
             KeyboardCommand(keys: "Return / Space", action: "Activate selected menu choice", group: "Menus & results"),
             KeyboardCommand(keys: "Z / , / LT + B", action: "Rewind the current run", group: "Gameplay"),
             KeyboardCommand(keys: ", / .", action: "Step one tick; hold to scrub; release to pause", group: "Gameplay")]
        }
        keyboard.hints = { [weak self] in self?.showLevelHints() }
        keyboard.settings = { [weak self] in self?.onShowSettings?() }
        keyboard.pauseOnInterruption = { [weak self] in self?.audioSettings.pauseOnInterruption ?? true }
        keyboard.onInterruption = { [weak self] in self?.interruptGameplay() }
        keyboard.controllerEnabled = { [weak self] in self?.audioSettings.controllerEnabled ?? false }
        keyboard.controllerTapSpeed = { [weak self] in self?.audioSettings.controllerTapSpeed ?? true }
        keyboard.controllerMappings = { [weak self] in self?.audioSettings.controllerMappings ?? [:] }
        keyboard.controllerSwapSticks = { [weak self] in self?.audioSettings.controllerSwapSticks ?? false }
        keyboard.retry = { [weak self] in self?.restart() }
        keyboard.rewind = { [weak self] in _ = self?.rewind(seconds: 2) }
        keyboard.controllerRewindHeld = { [weak self] held in
            guard let self else { return }
            if held { _ = self.beginContinuousRewind(advanceImmediately: false) }
            else if self.rewindHeld { self.endContinuousRewind() }
        }
        keyboard.step = { [weak self] direction in
            guard let self else { return }
            if direction < 0 { _ = self.rewind(seconds: 1.0 / Lemmings3Runtime.ticksPerSecond) }
            else if !self.stepForward(seconds: 1.0 / Lemmings3Runtime.ticksPerSecond) { self.singleStep() }
        }
        keyboard.endRun = { [weak self] in self?.confirmEndRun() }
        keyboard.pauseForHelp = { [weak self] in
            guard let self else { return {} }
            let interruption = self.gameplayKeyboard?.interruptionCount
            let wasPaused = self.paused; self.paused = true; self.saveCheckpoint(immediately: true); self.refresh()
            return { [weak self] in
                guard let self else { return }
                self.paused = wasPaused || self.gameplayKeyboard?.interruptionCount != interruption
                self.accumulator = 0; self.refresh()
            }
        }
        timelineTransport = makeTimelineTransport(for: window)
        music.loadLibrary(at: dataRoot.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Music/lemmings_3_music_mod_tsyu"))
        try? music.start()
        window.center()
        if let recovery, let saved = recovery.l3 {
            arcadeRunID = recovery.runID; arcadeProfileID = recovery.profileID; arcadeHotSeatID = recovery.hotSeatID
            recoveryInputs = saved.inputs; recoveryProgress = saved.progress
            recoveryInitialHash = recovery.initialStateHash
            skillAssignments = saved.skillAssignments; toolUses = saved.toolUses
            selected = recovery.selectedSkill; paused = true
            canvas.restoreCamera(x: CGFloat(recovery.scrollX), y: CGFloat(recovery.scrollY))
            arcadeLevelSnapshot = arcadeLevel
            message = "Saved run restored. Press Space when you are ready."
        } else {
            beginReplay()
            if !ArcadeStore.shared.hotSeatIsActive { canvas.startCountdown.arm() }
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        if recordsCampaignProgress, recovery == nil, let selection {
            UserDefaults.standard.set(selection.tribe.rawValue,
                forKey: ArcadeStore.shared.progressKey(
                    "nativeL3SelectedTribe.v1." + Self.storageIdentity(root)))
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    #if APP_INTEGRATION_TESTS
    func testTimelinePanel() throws {
        canvas.menuRows = nil
        try validateTimelineCanvas(canvas, timeline: canvas.timeline, name: "lemmings3",
            tick: { self.game.tick }, paused: { self.paused })
    }
    #endif

    func present() { showWindow(nil); window?.makeKeyAndOrderFront(nil); window?.makeFirstResponder(canvas) }
    static func browserLevels(root: URL) throws -> [BrowserLevel] {
        try browserLevels(root: root, progressData: browserProgressData(root: root))
    }

    static func browserProgressData(root: URL) -> [Int: Data] {
        Dictionary(uniqueKeysWithValues: Lemmings3ClassicCampaign.Tribe.allCases.compactMap { tribe in
            let key = ArcadeStore.shared.progressKey(
                "nativeL3\(tribe.title)Preview.v1." + storageIdentity(root))
            return UserDefaults.standard.data(forKey: key).map { (tribe.rawValue, $0) }
        })
    }

    nonisolated private static let browserCache = GameAssetCache<[BrowserLevel]>(capacity: 4)

    nonisolated static func browserLevels(root: URL, progressData: [Int: Data]) throws -> [BrowserLevel] {
        var result: [BrowserLevel] = []
        guard let rootRevision = FanLevelLibrary.directoryFingerprint(root) else {
            throw SequelDataError.invalid("The Lemmings 3 game data could not be verified.")
        }
        let cacheKey = root.standardizedFileURL.path + ":" + rootRevision
        if let cached = browserCache.value(for: cacheKey) { return cached }
        for tribe in Lemmings3ClassicCampaign.Tribe.allCases {
            try Task.checkCancellation()
            var campaign = try Lemmings3ClassicCampaign(root: root, tribe: tribe)
            if let data = progressData[tribe.rawValue],
               let progress = try? JSONDecoder().decode(
                Lemmings3ClassicCampaign.Progress.self, from: data) {
                try? campaign.restore(progress)
            }
            let style = try Lemmings3Style(
                directory: root.appendingPathComponent("STYLES"), number: tribe.rawValue)
            var availability: [Bool] = []
            for entry in campaign.levels {
                try Task.checkCancellation()
                guard let permanent = try? Lemmings3Objects(data: Data(contentsOf:
                        root.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS",
                            entry.permanentObjectsReference)))),
                      let temporary = try? Lemmings3Objects(data: Data(contentsOf:
                        root.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS",
                            entry.temporaryObjectsReference)))),
                      (try? Lemmings3Runtime(
                        level: entry, style: style, permanent: permanent, temporary: temporary)) != nil
                else { availability.append(false); continue }
                availability.append(true)
            }
            for level in campaign.levels.indices {
                try Task.checkCancellation()
                let selection = LevelSelection(tribe: tribe, level: level)
                let levelID = SHA256.hash(data: campaign.levels[level].rawData)
                    .map { String(format: "%02x", $0) }.joined()
                let sourceRevision = try LevelPreviewSource.lemmings3(
                    root: root, selection: selection, expectedLevelID: levelID)
                    .sourceRevision(rootRevision: rootRevision)
                result.append(BrowserLevel(
                    selection: selection,
                    levelID: levelID,
                    sourceRevision: sourceRevision,
                    isAvailable: availability[level]))
            }
        }
        browserCache.insert(result, for: cacheKey)
        return result
    }
    func showLevelHints() {
        guard let window, !GameScreen.shared.isPresented, !game.isComplete else { return }
        let deck = LevelHintDeck.practice(title: "\(campaign.tribe.title) \(campaign.index + 1)", skills: [], chronicles: true)
        let wasPaused = paused
        let interruption = gameplayKeyboard?.interruptionCount
        paused = true; accumulator = 0; saveCheckpoint(immediately: true); refresh()
        LevelHintWindow.shared.show(deck, owner: window) { [weak self] in
            guard let self else { return }
            self.paused = wasPaused || self.gameplayKeyboard?.interruptionCount != interruption
            self.accumulator = 0; self.lastTime = ProcessInfo.processInfo.systemUptime; self.refresh()
        }
    }
    private func interruptGameplay() {
        saveCheckpoint(immediately: true)
        guard !game.isComplete else { return }
        paused = true; accumulator = 0; lastTime = ProcessInfo.processInfo.systemUptime
        canvas.capturePointer(active: false)
        refresh()
    }
    func windowWillClose(_ notification: Notification) { stop() }
    func stop() {
        saveCheckpoint(immediately: true)
        canvas.capturePointer(active: false)
        NotificationCenter.default.removeObserver(self, name: SequelArtworkPreference.changed, object: nil)
        timer?.invalidate(); timer = nil; forwardTimer?.invalidate(); forwardTimer = nil
        runMovie.discard(); warningSound.stop(); music.stop(); dj.stop(); save()
        originalMovie?.close(); originalMovie = nil
    }
    func suspendAudioOutput() {
        saveCheckpoint(immediately: true)
        music.suspendOutput()
        dj.suspendOutput()
        warningSound.suspendOutput()
        warningSound.silence()
    }
    func resumeAudioOutput() throws { try music.resumeOutput(); dj.resumeOutput(); try warningSound.resumeOutput() }
    func setAudioSettings(_ settings: ClassicSettings, muted: Bool) {
        let sourceChanged = audioSettings.music != settings.music
        audioSettings = settings
        speedControl.variableEnabled = settings.modernControlsEnabled && settings.variableSpeedEnabled
        warningSound.setMuted(muted || settings.sound == .silent)
        warningSound.setVolume(settings.soundVolume)
        warningSound.setBottomFallSounds(settings.bottomFallSounds)
        try? warningSound.start()
        musicGain = Float(settings.musicVolume)
        music.setVolume(settings.musicVolume)
        dj.setVolume(settings.musicVolume)
        dj.setMuted(muted || settings.music == .silent)
        music.setMuted(muted || settings.music == .silent)
        if music.usesModernPreset != (settings.musicStyle == .modern) {
            music.setEnhancements(settings.musicStyle == .modern ? .modern : .faithful)
        }
        if sourceChanged { playLevelMusic() }
        canvas.confinePointer = settings.confinePointer
        canvas.reduceMotion = settings.reduceMotion
        canvas.reduceFlashes = settings.reduceFlashes
        canvas.hdEffectsEnabled = settings.hdEffectsEnabled
        canvas.fullScreenHDRFlashes = settings.cinematicExplosionsEnabled
        canvas.showReticleCount = settings.showReticleCount
        canvas.skillCursorIconSize = settings.skillCursorIconSize
        canvas.favorApproachingLemmings = settings.favorApproachingLemmings
        canvas.favorBombBlockers = settings.favorBombBlockers
        canvas.favorBuilders = settings.favorBuilders
    }

    private func playLevelMusic() {
        let prefix: String
        switch campaign.tribe {
        case .classic: prefix = "CLASSIC"
        case .shadow: prefix = "SHADOW"
        case .egyptian: prefix = "EGYPT"
        }
        let tracks = music.library.filter { $0.lastPathComponent.uppercased().hasPrefix(prefix) }
        guard !tracks.isEmpty else { return }
        let url = tracks[campaign.index % tracks.count]
        if audioSettings.music == .adaptiveDJ {
            let musicRoot = url.deletingLastPathComponent().deletingLastPathComponent()
            dj.load(soundtracks: SoundtrackPlayer.djSoundtracks(at: musicRoot), catalogueRoot: musicRoot)
            music.stop()
            dj.startJourney(trackID: "lemmings3." + url.deletingPathExtension().lastPathComponent.lowercased(),
                cycle: campaign.index / tracks.count, identity: arcadeRunID.uuidString, fallback: url,
                includeAlternates: audioSettings.djIncludesOtherSoundtracks)
        } else {
            dj.stop()
            try? music.start()
            _ = music.play(url: url)
        }
    }
    @objc private func toggleArtwork() { SequelArtworkPreference.setEnabled(!SequelArtworkPreference.enabled) }
    @objc private func artworkChanged() {
        do { try canvas.refreshArtwork() }
        catch { message = "Artwork could not be loaded: \(error)" }
        refresh()
    }
    static func savedCompletion(root: URL) -> Int {
        Lemmings3ClassicCampaign.Tribe.allCases.reduce(0) { count, tribe in
            guard var campaign = try? Lemmings3ClassicCampaign(root: root, tribe: tribe) else { return count }
            let key = ArcadeStore.shared.progressKey("nativeL3\(tribe.title)Preview.v1." + storageIdentity(root))
            if let data = UserDefaults.standard.data(forKey: key),
               let saved = try? JSONDecoder().decode(Lemmings3ClassicCampaign.Progress.self, from: data) {
                try? campaign.restore(saved)
            }
            return count + campaign.completed.count
        }
    }

    @objc private func togglePause() {
        if canvas.startCountdown.isActive {
            canvas.startCountdown.cancel(); paused = true; accumulator = 0; refresh(); return
        }
        saveCheckpoint(immediately: true)
        let wasPaused = paused; paused.toggle(); accumulator = 0
        if wasPaused { discardRewindOrigin() }
        refresh()
    }
    @objc private func singleStep() { canvas.startCountdown.cancel(); paused = true; advanceTick(); refresh() }
    private func beginContinuousRewind(advanceImmediately: Bool = true) -> Bool {
        guard game.tick > 0, !rewindHeld else { return false }
        captureRewindOrigin()
        rewindHeld = true
        rewindTimer?.invalidate()
        setRewindAudioDucked(true)
        rewindTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.rewind(seconds: 0.20) else { self?.endContinuousRewind(); return }
            }
        }
        guard !advanceImmediately || rewind(seconds: 0.20) else { endContinuousRewind(); return false }
        return true
    }
    private func endContinuousRewind() {
        rewindHeld = false
        rewindTimer?.invalidate()
        rewindTimer = nil
        setRewindAudioDucked(false)
    }
    private var canStepForward: Bool {
        game.tick < (rewindOriginState?.tick ?? game.tick) && !rewindHeld
    }
    private func beginContinuousStepForward(advanceImmediately: Bool = true) -> Bool {
        guard canStepForward, !forwardHeld else { return false }
        forwardHeld = true
        forwardTimer?.invalidate()
        setRewindAudioDucked(true)
        forwardTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.stepForward(seconds: 0.20) else { self?.endContinuousStepForward(); return }
            }
        }
        guard !advanceImmediately || stepForward(seconds: 0.20) else {
            endContinuousStepForward()
            return false
        }
        return true
    }
    private func endContinuousStepForward() {
        forwardHeld = false
        forwardTimer?.invalidate()
        forwardTimer = nil
        setRewindAudioDucked(false)
    }

    private func makeTimelineTransport(for window: NSWindow) -> TimelineKeyTransport {
        TimelineKeyTransport(window: window,
            canStartBackward: { [weak self] in
                guard let self else { return false }
                return self.canvas.menuRows == nil && self.game.tick > 0
            },
            stepBackward: { [weak self] in self?.rewind(seconds: 1.0 / Lemmings3Runtime.ticksPerSecond) ?? false },
            beginBackward: { [weak self] in self?.beginContinuousRewind(advanceImmediately: false) ?? false },
            endBackward: { [weak self] in self?.endContinuousRewind() },
            canStartForward: { [weak self] in self?.canStepForward ?? false },
            stepForward: { [weak self] in self?.stepForward(seconds: 1.0 / Lemmings3Runtime.ticksPerSecond) ?? false },
            beginForward: { [weak self] in self?.beginContinuousStepForward(advanceImmediately: false) ?? false },
            endForward: { [weak self] in self?.endContinuousStepForward() })
    }
    private func discardRewindOrigin() {
        endContinuousStepForward()
        rewindOriginState = nil
        rewindOriginInputs = []
    }
    private func setRewindAudioDucked(_ active: Bool) {
        guard rewindAudioDucked != active else { return }
        rewindAudioDucked = active
        music.setVolume(Double(active ? musicGain * 0.18 : musicGain))
        dj.setVolume(Double(active ? musicGain * 0.18 : musicGain))
    }
    private func captureRewindOrigin() {
        guard rewindOriginState == nil else { return }
        rewindOriginState = game; rewindOriginInputs = recoveryInputs
        rewindOriginAssignments = skillAssignments; rewindOriginToolUses = toolUses
    }
    private func cancelRewindToOrigin() -> Bool {
        guard let origin = rewindOriginState, game.tick != origin.tick else { return false }
        endContinuousRewind()
        game = origin; recoveryInputs = rewindOriginInputs
        skillAssignments = rewindOriginAssignments; toolUses = rewindOriginToolUses
        rewindOriginState = nil; rewindOriginInputs = []
        pendingTool = nil; canvas.directionPoint = nil; assignmentFocus.rewind(to: origin.tick)
        canvas.assignmentHighlight.clear(); warningSound.silence()
        paused = true; accumulator = 0; refresh(); saveCheckpoint(immediately: true)
        return true
    }
    @discardableResult
    private func rewind(seconds: Double) -> Bool {
        guard game.tick > 0 else { return false }
        captureRewindOrigin()
        let target = max(0, game.tick - Int((seconds * Lemmings3Runtime.ticksPerSecond).rounded()))
        guard target < game.tick else { return false }
        let prefix = recoveryInputs.prefix { $0.tick <= target }
        setRewindAudioDucked(true)
        do {
            game = try L3RunRecovery.replay(initial: initial, inputs: Array(prefix), through: target)
            try rebuildReplayStatistics(Array(prefix))
        } catch {
            message = "Could not rewind this run: \(error)"
            if !rewindHeld { setRewindAudioDucked(false) }
            return false
        }
        recoveryInputs = Array(prefix)
        paused = true; accumulator = 0; pendingTool = nil; canvas.directionPoint = nil
        assignmentFocus.rewind(to: target); canvas.assignmentHighlight.clear(); warningSound.silence(); warningSound.playRewindScrub()
        refresh(); saveCheckpoint(immediately: true)
        if !rewindHeld { setRewindAudioDucked(false) }
        return true
    }
    @discardableResult
    private func stepForward(seconds: Double) -> Bool {
        guard let origin = rewindOriginState, game.tick < origin.tick else { return false }
        let target = min(origin.tick, game.tick + Int((seconds * Lemmings3Runtime.ticksPerSecond).rounded()))
        guard target > game.tick else { return false }
        let prefix = rewindOriginInputs.prefix { $0.tick <= target }
        setRewindAudioDucked(true)
        do {
            game = try L3RunRecovery.replay(initial: initial, inputs: Array(prefix), through: target)
            try rebuildReplayStatistics(Array(prefix))
        } catch {
            message = "Could not move forward through this run: \(error)"
            if !forwardHeld { setRewindAudioDucked(false) }
            return false
        }
        recoveryInputs = Array(prefix)
        paused = true; accumulator = 0; pendingTool = nil; canvas.directionPoint = nil
        assignmentFocus.rewind(to: target); canvas.assignmentHighlight.clear(); warningSound.silence(); warningSound.playRewindScrub()
        refresh(); saveCheckpoint(immediately: true)
        if !forwardHeld { setRewindAudioDucked(false) }
        return true
    }
    private func rebuildReplayStatistics(_ inputs: [L3RunRecovery.Input]) throws {
        var probe = initial
        var assignments: [String: Int] = [:]
        var tools: [String: Int] = [:]
        for input in inputs {
            while probe.tick < input.tick && !probe.isComplete { probe.step() }
            guard probe.tick == input.tick, !probe.isComplete else { throw RunRecoveryError.invalid }
            assignments[input.action, default: 0] += 1
            if input.action == "use", let id = input.lemming,
               let tool = probe.lemmings.first(where: { $0.id == id })?.tool {
                tools[String(describing: tool), default: 0] += 1
            }
            L3RunRecovery.apply(input, to: &probe)
        }
        skillAssignments = assignments
        toolUses = tools
    }
    @objc private func toggleFast() { speedControl.tap(); refresh() }
    @objc private func confirmEndRun() {
        guard !game.isComplete, !GameScreen.shared.isPresented else { return }
        GameScreen.shared.confirm("End this run?",
            detail: "Active lemmings will be lost. Rescued lemmings and reserves will be retained. You can retry the level.",
            actionTitle: "End run", owner: window) { [weak self] in
                guard let self else { return }
                self.game.abort(); self.paused = true; self.accumulator = 0; self.refresh()
            }
    }
    @objc private func restart() {
        saveCheckpoint(immediately: true, waitForDisk: false)
        speedControl.newLevel()
        canvas.menuRows = nil; pendingTool = nil; canvas.directionPoint = nil; game = initial; beginReplay(); recorded = false; canvas.startCountdown.arm(); paused = true; accumulator = 0; canvas.resetCamera(campaign.levels[campaign.index]); message = "Choose an action. Bricks and spades ask for a direction. Arrow keys move the camera."; refresh() }
    private func save() {
        guard recordsCampaignProgress else { return }
        if let data = try? JSONEncoder().encode(campaign.progress) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
    }
    @objc private func chooseTribe() {
        guard onSequenceContinue == nil else { return }
        guard let tribe = Lemmings3ClassicCampaign.Tribe(rawValue: menuTribe + 1), tribe != campaign.tribe else { return }
        do {
            var session = try Self.session(root: dataRoot, tribe: tribe)
            try session.campaign.select(menuLevel)
            let level = session.campaign.levels[session.campaign.index]
            let perm = try Lemmings3Objects(data: Data(contentsOf: dataRoot.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
            let temp = try Lemmings3Objects(data: Data(contentsOf: dataRoot.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
            let replacement = try Lemmings3Runtime(level: level, style: session.style, permanent: perm, temporary: temp, total: session.campaign.population)
            let scene = try Lemmings3Scene(level: level, style: session.style, permanent: perm, temporary: temp)
            try canvas.load(scene: scene, style: session.style, permanent: perm, temporary: temp, sprites: session.sprites, root: dataRoot, terrainStyle: level.style)
            save()
            style = session.style; sprites = session.sprites; availability = session.availability; progressKey = session.progressKey
            campaign = session.campaign; initial = replacement
            if recordsCampaignProgress {
                UserDefaults.standard.set(tribe.rawValue, forKey: ArcadeStore.shared.progressKey(
                    "nativeL3SelectedTribe.v1." + Self.storageIdentity(dataRoot)))
            }
            window?.title = "Lemmings 3 — \(tribe.title) \(campaign.index + 1) — Experimental native preview"
            restart()
        } catch {
            message = String(describing: error); refresh()
        }
    }
    @objc private func chooseLevel() {
        guard onSequenceContinue == nil else { return }
        var proposed = campaign
        do { try proposed.select(menuLevel); try load(proposed) }
        catch { message = String(describing: error); refresh() }
    }
    @objc private func advance() {
        guard recordsCampaignProgress else { return }
        if campaignFinished, let onCampaignCompleted { onCampaignCompleted(); return }
        var proposed = campaign
        guard proposed.advance(after: game), availability[proposed.index] == nil else { return }
        do { try load(proposed) } catch { message = String(describing: error); refresh() }
    }
    private func load(_ proposed: Lemmings3ClassicCampaign) throws {
        let level = proposed.levels[proposed.index]
        let perm = try Lemmings3Objects(data: Data(contentsOf: dataRoot.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
        let temp = try Lemmings3Objects(data: Data(contentsOf: dataRoot.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
        let replacement = try Lemmings3Runtime(level: level, style: style, permanent: perm, temporary: temp, total: proposed.population)
        let scene = try Lemmings3Scene(level: level, style: style, permanent: perm, temporary: temp)
        try canvas.load(scene: scene, style: style, permanent: perm, temporary: temp, sprites: sprites, root: dataRoot, terrainStyle: level.style)
        campaign = proposed; initial = replacement; save()
        window?.title = "Lemmings 3 — \(campaign.tribe.title) \(campaign.index + 1) — Experimental native preview"
        restart()
    }
    private func assign(x: Int, y: Int) {
        guard let picked = game.target(x: x, y: y, selected: selected,
            favorApproaching: audioSettings.favorApproachingLemmings,
            favorBombBlockers: audioSettings.favorBombBlockers, favorBuilders: audioSettings.favorBuilders) else { return }
        if selected == 3 && (picked.tool == .bricks || picked.tool == .spade) {
            pendingTool = picked.id
            canvas.directionPoint = CGPoint(x: picked.x, y: picked.y)
            canvas.needsDisplay = true
            return
        }
        applyAction(to: picked.id, direction: .right)
    }
    private func applyAction(to id: Int, direction: Lemmings3Runtime.Direction) {
        guard let lem = game.lemmings.first(where: { $0.id == id && $0.active }) else { return }
        let action = Lemmings3Runtime.Action.allCases[selected]
        let accepted = action == .use ? game.useTool(to: id, direction: direction) : game.assign(action, to: id)
        if accepted {
            if rewindOriginState != nil { discardRewindOrigin() }
            recoveryInputs.append(.init(tick: game.tick, action: action.rawValue, lemming: id,
                direction: action == .use ? direction.rawValue : nil))
            assignmentFocus.record(id: id, skill: selected, tick: game.tick)
            canvas.didAssign(to: id)
            warningSound.play(action == .use && lem.tool == .bomb ? .ohNo : .assignSkill)
            skillAssignments[action.rawValue, default: 0] += 1
            if action == .use, let tool = lem.tool { toolUses[String(describing: tool), default: 0] += 1 }
        }
        message = accepted ? "\(action.rawValue.capitalized) assigned to lemming \(id + 1)." : "That lemming cannot use this action now."
        refresh()
    }
    private func showGameMenu() {
        pendingTool = nil; canvas.directionPoint = nil
        if canvas.menuRows != nil { canvas.menuRows = nil; canvas.needsDisplay = true; return }
        canvas.menuNotice = "EXPERIMENTAL GAMEPLAY"
        menuTribe = campaign.tribe.rawValue - 1; menuLevel = campaign.index
        rebuildMenu()
    }
    private func rebuildMenu() {
        if onSequenceContinue != nil {
            canvas.menuRows = ["RESUME", "RETRY LEVEL",
                SequelArtworkPreference.enabled ? "ARTWORK  MAC STYLE" : "ARTWORK  ORIGINAL PC",
                "ORIGINAL MOVIES", "BACK TO LIBRARY"]
            canvas.needsDisplay = true
            return
        }
        let tribe = Lemmings3ClassicCampaign.Tribe.allCases[menuTribe]
        canvas.menuRows = ["RESUME", "RETRY LEVEL", "TRIBE  " + tribe.title.uppercased(),
            "PREVIOUS LEVEL", "NEXT LEVEL", "PLAY LEVEL \(menuLevel + 1)",
            SequelArtworkPreference.enabled ? "ARTWORK  MAC STYLE" : "ARTWORK  ORIGINAL PC", "ORIGINAL MOVIES", "BACK TO LIBRARY"]
        canvas.needsDisplay = true
    }
    private func menuAction(_ row: Int) {
        if onSequenceContinue != nil {
            switch row {
            case 0: canvas.menuRows = nil; paused = false; accumulator = 0; lastTime = ProcessInfo.processInfo.systemUptime; refresh()
            case 1: restart()
            case 2: toggleArtwork(); rebuildMenu()
            case 3: showOriginalMovies()
            case 4: canvas.menuRows = nil; close()
            default: break
            }
            canvas.needsDisplay = true
            return
        }
        switch row {
        case 0: canvas.menuRows = nil; paused = false; accumulator = 0; lastTime = ProcessInfo.processInfo.systemUptime; refresh()
        case 1: restart()
        case 2: menuTribe = (menuTribe + 1) % 3; menuLevel = 0; rebuildMenu()
        case 3: menuLevel = (menuLevel + 29) % 30; rebuildMenu()
        case 4: menuLevel = (menuLevel + 1) % 30; rebuildMenu()
        case 5:
            let selectedTribe = Lemmings3ClassicCampaign.Tribe.allCases[menuTribe]
            if let session = try? Self.session(root: dataRoot, tribe: selectedTribe), session.availability[menuLevel] != nil {
                canvas.menuNotice = "LEVEL NOT AVAILABLE"; rebuildMenu(); return
            }
            if menuTribe != campaign.tribe.rawValue - 1 { chooseTribe() }
            else if availability[menuLevel] == nil { chooseLevel() }
            else { canvas.menuNotice = "LEVEL NOT AVAILABLE"; rebuildMenu() }
        case 6: toggleArtwork(); rebuildMenu()
        case 7: showOriginalMovies()
        case 8: canvas.menuRows = nil; close()
        default: break
        }
        canvas.needsDisplay = true
    }
    private func showOriginalMovies() {
        let page = GameMenuPage(title: "Original movies", subtitle: "Lemmings 3")
        page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
        for (index, movie) in OriginalMoviePlayer.Movie.allCases.enumerated() {
            page.addListAction(movie.title, at: index) { [weak self] in self?.playOriginalMovie(movie) }
        }
        GameScreen.shared.present(page, owner: window)
    }
    private func playOriginalMovie(_ movie: OriginalMoviePlayer.Movie) {
        do {
            let player = try OriginalMoviePlayer(url: dataRoot.appendingPathComponent("MOVIE/" + movie.rawValue))
            suspendAudioOutput()
            player.onClose = { [weak self] in
                self?.originalMovie = nil
                try? self?.resumeAudioOutput()
                self?.lastTime = ProcessInfo.processInfo.systemUptime
            }
            originalMovie = player
            if !player.present(owner: window) {
                originalMovie = nil; try? resumeAudioOutput()
                message = "The movie could not open in the game window."
            }
        } catch { GameScreen.shared.message("Original movie", detail: String(describing: error)) }
    }
    private func update() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = min(0.1, now - lastTime); lastTime = now
        let playing = !paused && !game.isComplete && !GameScreen.shared.isPresented && canvas.menuRows == nil && pendingTool == nil
        speedControl.update(at: now, active: !game.isComplete && !GameScreen.shared.isPresented && canvas.menuRows == nil && pendingTool == nil)
        let turn = ArcadeStore.shared.hotSeatIsActive ? ArcadeStore.shared.records.profile(arcadeProfileID) : nil
        canvas.turnBadge.show(initials: turn?.initials, portrait: turn.flatMap { ArcadeWindow.shared.arcadeView.portraitImage($0.portrait) })
        canvas.speedMultiplier = speedControl.multiplier
        canvas.speedChoiceLabel = speedControl.choiceLabel
        canvas.speedLabel = speedControl.panelLabel
        canvas.variableSpeedEnabled = speedControl.variableEnabled
        GameScreen.shared.capturePointer(in: window, enabled: canvas.confinePointer && !playing)
        canvas.capturePointer(active: playing)
        guard !GameScreen.shared.isPresented, canvas.menuRows == nil, pendingTool == nil else { accumulator = 0; return }
        canvas.panAtPointer(seconds: elapsed)
        if canvas.startCountdown.isActive {
            if canvas.startCountdown.advance(seconds: elapsed, visible: window?.isKeyWindow == true) { paused = false }
            accumulator = 0; refresh(); return
        }
        guard !paused, !game.isComplete else { return }
        accumulator += elapsed * speedControl.multiplier
        let inputDeadline = ProcessInfo.processInfo.systemUptime + 0.012
        while accumulator >= 1 / Lemmings3Runtime.ticksPerSecond && !game.isComplete {
            accumulator -= 1 / Lemmings3Runtime.ticksPerSecond; advanceTick()
            if speedControl.variableEnabled && speedControl.multiplier > 1 && ProcessInfo.processInfo.systemUptime >= inputDeadline { break }
        }
        refresh()
    }
    private func beginReplay() {
        recoveryInputs = []; recoveryProgress = campaign.progress
        recoveryInitialHash = L3RunRecovery.stateHash(initial); lastCheckpointTime = 0
        assignmentFocus = AssignmentFocus(); canvas.assignmentHighlight.clear()
        warningSound.silence()
        let previousAttemptID = arcadeRunID
        arcadeRunID = UUID(); arcadeProfileID = ArcadeStore.shared.playingProfileID; arcadeHotSeatID = ArcadeStore.shared.hotSeatID
        arcadeReport = nil; skillAssignments = [:]; toolUses = [:]
        arcadeLevelSnapshot = arcadeLevel
        if recordsCampaignProgress {
            ArcadeStore.shared.beginAttempt(id: arcadeRunID, profileID: arcadeProfileID,
                level: arcadeLevel, previousID: previousAttemptID)
        }
        runMovie.begin(ticksPerSecond: Lemmings3Runtime.ticksPerSecond, title: "Lemmings 3 - \(campaign.tribe.title) \(campaign.index + 1)")
        playLevelMusic()
        runMovie.onWillReview = { [weak self] in self?.suspendAudioOutput() }
        runMovie.onDidReview = { [weak self] in try? self?.resumeAudioOutput() }
        if let recorder = runMovie.recorder {
            warningSound.onPlay = { [weak recorder] samples, rate, gain in recorder?.sound(samples: samples, rate: rate, gain: gain) }
        }
    }
    func suspendForReplay() -> () -> Void {
        let interruption = gameplayKeyboard?.interruptionCount
        let wasPaused = paused
        paused = true; suspendAudioOutput(); refresh()
        return { [weak self] in
            guard let self else { return }
            self.paused = wasPaused || self.gameplayKeyboard?.interruptionCount != interruption
            try? self.resumeAudioOutput(); self.lastTime = ProcessInfo.processInfo.systemUptime; self.refresh()
        }
    }
    func reviewReplay() { if game.isComplete { runMovie.review() } }
    func showLevelRecords() {
        ArcadeWindow.shared.showRecords(level: arcadeLevel, owner: window, background: arcadeBackdrop)
    }
    var arcadeBackdrop: CGImage? { ArcadeWindow.captureScene(canvas) }
    private func recordArcadeResult() {
        let run = ArcadeRun(id: arcadeRunID, profileID: arcadeProfileID,
            level: arcadeLevel, saved: game.saved, didWin: game.saved > 0, skills: skillAssignments,
            seconds: Double(game.tick) / Lemmings3Runtime.ticksPerSecond,
            telemetry: TrolleyTelemetry(released: game.released + game.configuration.extras.count,
                destructiveSkillCount: TrolleyCapture.destructiveCount(toolUses), buildVersion: TrolleyCapture.buildVersion,
                additionalStatistics: ["reserve": Double(game.reserve), "engineLost": Double(game.lost),
                                       "timeRemaining": Double(game.remainingSeconds)].merging(Dictionary(uniqueKeysWithValues: toolUses.map { ("tool." + $0.key, Double($0.value)) }), uniquingKeysWith: { _, b in b })))
        arcadeReport = recordsCampaignProgress
            ? ArcadeStore.shared.record(run)
            : ArcadeStore.shared.previewReport(for: run)
        guard let arcadeReport else { return }
        if recordsCampaignProgress { runMovie.preserveRecord(arcadeReport) }
        ArcadeWindow.shared.showResult(arcadeReport, owner: window, retry: { [weak self] in self?.restart() },
            next: { [weak self] in self?.continueArcadeResult() },
            replay: { [weak self] save in self?.runMovie.review(save: save) }, continueTitle: resultContinueTitle, background: arcadeBackdrop, rewardVolume: warningSound.muted ? 0 : warningSound.volume)
    }
    private var resultContinueTitle: String {
        if onSequenceContinue != nil { return game.saved == 0 ? "Retry level" : sequenceContinueTitle }
        if canAdvance { return campaignFinished ? "Continue" : "Next level" }
        return usesSharedWindow ? "Back to library" : "Choose level"
    }
    private func continueArcadeResult() {
        if onSequenceContinue != nil, game.saved == 0 {
            restart()
            return
        }
        if onSequenceContinue?(game.saved > 0) == true { return }
        if canAdvance { advance() }
        else if usesSharedWindow { onReturnToLibrary?() }
        else { showGameMenu() }
    }
    func saveCheckpoint(immediately: Bool = false, waitForDisk: Bool = true) {
        guard recordsCampaignProgress else { return }
        let engine = RunRecovery.bundledEngine
        let now = ProcessInfo.processInfo.systemUptime
        guard !engine.isEmpty, game.tick >= 0, !game.isComplete,
          let progress = recoveryProgress, !recoveryInitialHash.isEmpty,
          let fingerprint = arcadeLevel.conditions?.levelFingerprint,
          immediately || now - lastCheckpointTime >= 5 else { return }
        lastCheckpointTime = now
        var checkpoint = RunRecovery(engine: engine, profileID: arcadeProfileID, runID: arcadeRunID,
          dataSetID: "lemmings3", levelIndex: progress.index,
          levelFingerprint: fingerprint, initialStateHash: recoveryInitialHash,
          tick: game.tick, events: [], stateHash: L3RunRecovery.stateHash(game), usedRewind: false,
          nukeCount: 0, rewindCount: 0, undoCount: 0, selectedSkill: selected,
          scrollX: Double(canvas.cameraX), scrollY: Double(canvas.cameraY))
        checkpoint.sourcePath = dataRoot.path
        checkpoint.l3 = L3RunRecovery(progress: progress, inputs: recoveryInputs,
          skillAssignments: skillAssignments, toolUses: toolUses)
        checkpoint.hotSeatID = arcadeHotSeatID
        recoveryStore.save(checkpoint, immediately: immediately && waitForDisk) { [weak self] error in
            self?.message = "Run recovery save failed: " + error
        }
    }

    private func advanceTick() {
        countdownWarning.reset(seconds: game.remainingSeconds)
        let previousSoundState = Lemmings3SoundCue.Snapshot(game)
        game.step()
        saveCheckpoint()
        warningSound.play(Lemmings3SoundCue.cues(before: previousSoundState, after: .init(game)))
        if countdownWarning.update(seconds: game.remainingSeconds) { warningSound.play(.builderWarning) }
        canvas.flashExplosions(game)
        canvas.game = game
        runMovie.recorder?.setMusic(url: dj.isPlaying ? dj.currentURL : music.currentURL, gain: music.muted ? 0 : musicGain)
        runMovie.capture(ReplayFrameCapture.image(size: CGSize(width: 1280, height: 640)) {
            ReplayFrameCapture.draw(canvas, in: CGRect(x: 0, y: 0, width: 1280, height: 640))
        })
    }
    private func refresh() {
        let impossible = canvas.menuRows == nil && !game.isComplete && FailureMoodDecision.isUnrecoverable(
            saved: game.saved, active: game.lemmings.filter(\.active).count,
            unreleased: game.reserve, required: 1)
        failureMood.set(active: impossible)
        let justCompleted = game.isComplete && !recorded
        if justCompleted { dj.updateTelemetry(.init(didWin: game.saved > 0, isComplete: true)) }
        if justCompleted {
            if recordsCampaignProgress {
                do { try recoveryStore.clear(arcadeRunID) } catch { message = error.localizedDescription }
            }
            runMovie.finish(); recorded = true
            if recordsCampaignProgress, campaign.record(game) {
                save()
                campaignFinished = Self.savedCompletion(root: dataRoot) == 90
                onProgressChanged?()
            }
        }
        canAdvance = recordsCampaignProgress && game.isComplete && game.saved > 0
            && ((campaignFinished && usesSharedWindow)
            || (availability.indices.contains(campaign.index + 1) && availability[campaign.index + 1] == nil))
        canvas.selectedAction = selected; canvas.paused = paused; canvas.fast = fast
        canvas.updateSkillBadge()
        let transport = rewindOriginState.map { "Rewind active, \($0.tick - game.tick) ticks back. Hold full stop scrubs forward. Escape cancels." } ?? ""
        canvas.rewindOriginTick = rewindOriginState?.tick
        canvas.rewindCurrentTick = game.tick
        canvas.setAccessibilityLabel("Lemmings 3. \(campaign.tribe.title) level \(campaign.index + 1). \(game.saved) saved, \(game.reserve) in reserve, \(game.remainingSeconds) seconds. Selected \(Lemmings3Panel.names[selected]). \(message) Space pauses. F changes speed. Z rewinds. \(transport) Escape returns to the main menu. Double-click End Run to finish.")
        let turn = ArcadeStore.shared.hotSeatIsActive ? ArcadeStore.shared.records.profile(arcadeProfileID) : nil
        canvas.turnBadge.show(initials: turn?.initials, portrait: turn.flatMap { ArcadeWindow.shared.arcadeView.portraitImage($0.portrait) })
        canvas.speedMultiplier = speedControl.multiplier
        canvas.speedChoiceLabel = speedControl.choiceLabel
        canvas.speedLabel = speedControl.panelLabel
        canvas.variableSpeedEnabled = speedControl.variableEnabled
        canvas.isFastForward = fast && !paused && !game.isComplete
        canvas.game = game; canvas.needsDisplay = true
        if justCompleted { recordArcadeResult() }
    }
}

@MainActor private final class Lemmings3Canvas: NSView {
    let timeline = TimelinePanelControls()
    private func layoutTimeline() {
        let width = min(260, bounds.width - 16)
        timeline.frame = CGRect(x: (bounds.width - width) / 2, y: bounds.height - 34, width: width, height: 30)
    }

    var confinePointer = true
    private let pointerCapture = GamePointerCapture()
    func capturePointer(active: Bool) {
        layoutTimeline()
        let frame = CGRect(origin: screenOrigin, size: CGSize(width: 320 * zoom, height: 212 * zoom)).union(timeline.frame)
        if let point = pointerCapture.update(in: self, rect: frame, active: active && confinePointer && controllerPointer == nil) {
            updateSystemCursor(at: point)
            trackPointer(at: point)
        }
    }
    var hdEffectsEnabled = true {
        didSet {
            if !hdEffectsEnabled { hdrOverlay?.clear(); speedTrails.reset() }
            syncSpeedEffects(); needsDisplay = true
        }
    }
    var reduceMotion = false {
        didSet {
            assignmentHighlight.reduceMotion = reduceMotion
            if reduceMotion { speedTrails.reset() }
            syncSpeedEffects(); needsDisplay = true
        }
    }
    var reduceFlashes = false {
        didSet { if reduceFlashes { hdrOverlay?.clearExplosions() }; needsDisplay = true }
    }
    private var usesSpeedEffects: Bool { hdEffectsEnabled && !reduceMotion && isFastForward }
    var speedMultiplier: Double = 3 { didSet { speedTrails.multiplier = speedMultiplier; syncSpeedEffects() } }
    let turnBadge = TurnBadgeView()
    override init(frame: NSRect) {
        super.init(frame: frame)
        addSubview(turnBadge)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    var speedLabel = "2×"
    var speedChoiceLabel = "2×"
    var variableSpeedEnabled = true
    var onSpeedPress: ((TimeInterval, Int) -> Void)?
    var onSpeedRelease: ((TimeInterval) -> Void)?
    var onSpeedStep: ((Int, TimeInterval) -> Void)?
    var isFastForward = false { didSet { syncSpeedEffects() } }
    var fullScreenHDRFlashes = true { didSet { if !fullScreenHDRFlashes { hdrOverlay?.clearExplosions() } } }
    private let speedTrails = SpeedTrails()
    private var hdrOverlay: ExplosionHDRView?
    private var lastBlastTick = -1
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, hdrOverlay == nil {
            let overlay = ExplosionHDRView(frame: bounds)
            overlay.autoresizingMask = [.width, .height]
            addSubview(overlay, positioned: .below, relativeTo: turnBadge); hdrOverlay = overlay
        }
        syncSpeedEffects()
    }
    override func layout() { super.layout(); layoutTimeline(); syncSpeedEffects() }
    private func syncSpeedEffects() {
        let active = usesSpeedEffects && menuRows == nil && window != nil
        hdrOverlay?.setSuperSpeed(active,in:playfieldRect,immediate:!active, multiplier: speedMultiplier)
    }
    func flashExplosions(_ game: Lemmings3Runtime) {
        guard hdEffectsEnabled, !reduceFlashes else { return }
        guard game.tick != lastBlastTick else { return }
        lastBlastTick = game.tick
        let fresh = game.blasts.filter { $0.tick == game.tick }
        guard !fresh.isEmpty else { return }
        let cores = fresh.map { NSRect(x: origin.x + (CGFloat($0.x - 3) - cameraX) * zoom,
            y: origin.y + (CGFloat($0.y - 3) - cameraY) * zoom, width: 6 * zoom, height: 6 * zoom) }
        hdrOverlay?.pulse(cores: cores, fullScreen: fullScreenHDRFlashes)
    }
    var game: Lemmings3Runtime? { didSet { updateSpeedTrails() } }
    var rewindOriginTick: Int?
    var rewindCurrentTick = 0
    var onClick: ((Int, Int) -> Void)?
    var onKey: ((String) -> Void)?
    private let accessibleElements = GameAccessibleElements()
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityChildren() -> [Any]? {
        func rect(_ r: CGRect) -> CGRect { CGRect(x: screenOrigin.x + r.minX * zoom, y: screenOrigin.y + r.minY * zoom, width: r.width * zoom, height: r.height * zoom) }
        if let rows = menuRows {
            return rows.enumerated().map { index, title in
                accessibleElements.element(id: "menu-\(index)", owner: self, label: title,
                    frame: rect(CGRect(x: 32, y: 39 + index * 16, width: 256, height: 16))) { [weak self] in self?.onMenuRow?(index) }
            }
        }
        if directionPoint != nil {
            return Lemmings3Runtime.Direction.allCases.map { direction in
                let area = directionPickerRect
                let button = CGRect(x: area.minX + CGFloat(direction.dx + 1) * 14, y: area.minY + CGFloat(direction.dy + 1) * 14, width: 14, height: 14)
                return accessibleElements.element(id: "direction-" + direction.rawValue, owner: self, label: "Direction " + direction.rawValue, frame: rect(button)) { [weak self] in self?.onDirection?(direction) }
            }
        }
        var children: [Any] = []
        if !turnBadge.isHidden { children.append(turnBadge) }
        for slot in [0, 1, 2, 3, 4, 6, 7, 8] {
            let title = slot == 6 ? (fast ? "Return to normal speed" : "Start fast-forward") : slot == 7 ? (paused ? "Resume" : "Pause") : Lemmings3Panel.names[slot]
            children.append(accessibleElements.element(id: "panel-\(slot)", owner: self, label: title,
                frame: rect(CGRect(x: Lemmings3Panel.edges[slot], y: 172, width: Lemmings3Panel.edges[slot + 1] - Lemmings3Panel.edges[slot], height: 40))) { [weak self] in self?.onPanel?(slot, slot == 8 ? 2 : 1) })
        }
        if variableSpeedEnabled {
            for direction in [-1, 1] {
                children.append(accessibleElements.element(id: "speed-\(direction)", owner: self,
                    label: direction < 0 ? "Decrease fast speed" : "Increase fast speed", frame: rect(CGRect(x: direction < 0 ? 214 : 241, y: 172, width: 8, height: 40))) { [weak self] in self?.onSpeedStep?(direction, ProcessInfo.processInfo.systemUptime) })
            }
        }
        children.append(accessibleElements.element(id: "menu", owner: self, label: "Game menu", frame: rect(CGRect(x: 280, y: 0, width: 40, height: 12))) { [weak self] in self?.onMenu?() })
        layoutTimeline()
        return children + timeline.accessibleControls(owner: self)
    }
    var onPanel: ((Int, Int) -> Void)?
    var onMenu: (() -> Void)?
    var onMenuRow: ((Int) -> Void)?
    var onDirection: ((Lemmings3Runtime.Direction) -> Void)?
    var onCancelDirection: (() -> Void)?
    var selectedAction = 0
    let startCountdown = FreshLevelCountdown()
    var showReticleCount = false
    var skillCursorIconSize: SkillCursorIconSize = .one
    var favorApproachingLemmings = true
    var favorBombBlockers = true
    var favorBuilders = true
    var paused = true
    var fast = false
    var menuRows: [String]? {
        didSet {
            syncSpeedEffects()
            if oldValue != menuRows { window?.invalidateCursorRects(for: self) }
            if menuRows != nil { NSCursor.arrow.set() }
        }
    }
    var menuNotice = "EXPERIMENTAL GAMEPLAY"
    var directionPoint: CGPoint?
    private var pointerPosition: CGPoint?
    private var controllerPointer: CGPoint?
    func moveControllerPointer(_ dx: Double, _ dy: Double) {
        let p = controllerPointer ?? CGPoint(x: playfieldRect.midX, y: playfieldRect.midY)
        let next = CGPoint(x: max(bounds.minX, min(bounds.maxX - 1, p.x + dx * zoom)),
                           y: max(bounds.minY, min(bounds.maxY - 1, p.y + dy * zoom)))
        trackPointer(at: next); controllerPointer = next
    }
    func controllerPan(_ dx: Double, _ dy: Double) {
        guard directionPoint == nil else { return }
        assignmentHighlight.clear(); pan(dx, dy)
    }
    func confirmControllerDirection() {
        guard directionPoint != nil, let p = controllerPointer ?? pointerPosition else { return }
        let point = CGPoint(x: (p.x - screenOrigin.x) / zoom, y: (p.y - screenOrigin.y) / zoom)
        let rect = directionPickerRect
        guard rect.contains(point) else { return }
        let dx = Int((point.x - rect.minX) / 14) - 1, dy = Int((point.y - rect.minY) / 14) - 1
        if let direction = Lemmings3Runtime.Direction.allCases.first(where: { $0.dx == dx && $0.dy == dy }) { onDirection?(direction) }
    }
    func controllerMenuKey(_ key: String) {
        let code: UInt16 = ["up": 126, "down": 125, "left": 123, "right": 124, "\r": 36, "\u{1b}": 53][key] ?? 0
        if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window?.windowNumber ?? 0, context: nil, characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: code) { keyDown(with: event) }
    }
    let assignmentHighlight = LemmingFocusHighlight()
    private let assignmentPulse = LemmingAssignmentPulse()
    private var assignmentPulseTask: Task<Void, Never>?
    func didAssign(to id: Int) {
        assignmentPulse.show(id)
        needsDisplay = true
        scheduleAssignmentPulseRedraw()
    }
    private func scheduleAssignmentPulseRedraw() {
        assignmentPulseTask?.cancel()
        guard assignmentPulse.isActive else { return }
        assignmentPulseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled else { return }
            self?.needsDisplay = true
            self?.scheduleAssignmentPulseRedraw()
        }
    }
    var pointerTarget: Int? {
        guard let p = pointerPosition ?? controllerPointer, playfieldRect.contains(p), let game else { return nil }
        let x = (p.x - origin.x) / zoom + cameraX, y = (p.y - origin.y) / zoom + cameraY
        return game.target(x: Int(x), y: Int(y), selected: selectedAction,
            favorApproaching: favorApproachingLemmings,
            favorBombBlockers: favorBombBlockers, favorBuilders: favorBuilders)?.id
    }
    private var hoveredLemming: Int?
    private var tracking: NSTrackingArea?
    private var panelArt: Lemmings3Panel?
    private var skillBadge: NSImage?
    private var menuSelection = 0
    var failureMoodAmount: CGFloat = 0
    private var terrain: NSImage?
    private var sprites: [[NSImage]] = []
    private var objects: [(Int, Int, Int, Bool, [NSImage])] = []
    private var foreground: NSImage?
    private var foregroundPixels: [UInt8] = []
    private var palette: [UInt8] = []
    private var brickPixels: [UInt8] = []
    private var renderedEdits: [Int: Bool] = [:]
    private var pickupImages: [Int: NSImage] = [:]
    private var creatureImages: [Int: [[NSImage]]] = [:]
    private var mapWidth = 320
    private var mapHeight = 160
    private(set) var cameraX: CGFloat = 0
    private(set) var cameraY: CGFloat = 0
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    private var zoom: CGFloat { max(0.1, min(bounds.width / 320, (bounds.height - 38) / 212)) }
    private var screenOrigin: NSPoint { NSPoint(x: (bounds.width - 320 * zoom) / 2, y: (bounds.height - 38 - 212 * zoom) / 2) }
    private var origin: NSPoint { NSPoint(x: screenOrigin.x, y: screenOrigin.y + 12 * zoom) }
    var playfieldRect: CGRect { CGRect(x: origin.x, y: origin.y, width: 320 * zoom, height: 160 * zoom) }
    var panelRect: CGRect { CGRect(x: origin.x, y: origin.y + 160 * zoom, width: 320 * zoom, height: 40 * zoom) }
    private let artworkRenderer = SequelArtworkRenderer()
    private var terrainCategory: SequelMacCategory = .organic
    private var reloadArtwork: (() throws -> Void)?
    private func image(width: Int, height: Int, pixels: [UInt8], palette: [UInt8], opaque: [Bool]? = nil,
                       category: SequelMacCategory = .sprite) throws -> NSImage {
        try artworkRenderer.image(width: width, height: height, pixels: pixels,
            palette: palette, opaque: opaque, category: category)
    }
    func refreshArtwork() throws {
        let wasFastForward = isFastForward
        try reloadArtwork?()
        isFastForward = wasFastForward
        needsDisplay = true
    }

    func updateSkillBadge() {
        guard let art = panelArt, (0..<5).contains(selectedAction) else {
            skillBadge = nil
            return
        }
        let left = CGFloat(Lemmings3Panel.edges[selectedAction])
        let width = CGFloat(Lemmings3Panel.edges[selectedAction + 1]) - left
        let source = CGRect(x: left, y: 0, width: width, height: 40)
        skillBadge = NSImage(size: source.size, flipped: true) { rect in
            art.normal.draw(in: rect, from: source, operation: .sourceOver, fraction: 1,
                            respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
            return true
        }
    }

    func load(scene: Lemmings3Scene, style: Lemmings3Style, permanent: Lemmings3Objects, temporary: Lemmings3Objects, sprites bank: Lemmings3Sprites, root: URL, terrainStyle: Int, resetPresentation: Bool = true) throws {
        if resetPresentation {
            hdrOverlay?.clear()
            isFastForward = false
            lastBlastTick = -1
            speedTrails.reset()
        }
        panelArt = try Lemmings3Panel(root: root, tribe: [1: 4, 2: 10, 3: 5][terrainStyle] ?? 4, renderer: artworkRenderer)
        terrainCategory = .lemmings3Terrain(style: terrainStyle)
        reloadArtwork = { [weak self] in
            try self?.load(scene: scene, style: style, permanent: permanent, temporary: temporary,
                           sprites: bank, root: root, terrainStyle: terrainStyle, resetPresentation: false)
        }
        let staged = Lemmings3Canvas()
        staged.terrainCategory = terrainCategory
        try staged.populate(scene: scene, style: style, permanent: permanent, temporary: temporary, sprites: bank, root: root)
        terrain = staged.terrain; sprites = staged.sprites; objects = staged.objects
        foreground = staged.foreground; foregroundPixels = staged.foregroundPixels
        palette = staged.palette; brickPixels = staged.brickPixels; renderedEdits = [:]
        pickupImages = staged.pickupImages; creatureImages = staged.creatureImages
        mapWidth = staged.mapWidth; mapHeight = staged.mapHeight
    }
    private func populate(scene: Lemmings3Scene, style: Lemmings3Style, permanent: Lemmings3Objects, temporary: Lemmings3Objects, sprites bank: Lemmings3Sprites, root: URL) throws {
        objects = []; pickupImages = [:]; creatureImages = [:]; renderedEdits = [:]
        mapWidth = scene.image.width; mapHeight = scene.image.height; palette = style.palette
        terrain = try image(width: mapWidth, height: mapHeight, pixels: scene.background.pixels, palette: style.palette, category: terrainCategory)
        foregroundPixels = Array(repeating: 255, count: mapWidth * mapHeight)
        // Native 8x8 construction tile. Its placement rules remain experimental.
        brickPixels = try style.constructionTile().pixels
        sprites = try bank.animations.map { animation in
            try animation.frames.map { try image(width: animation.width, height: animation.height,
                pixels: $0.pixels, palette: style.palette, opaque: $0.opaque) }
        }
        for (placementIndex, placed) in permanent.placements.enumerated() {
            if let kind = Lemmings3Runtime.Creature.Kind(rawValue: placed.identifier / 2 * 2), creatureImages[kind.rawValue] == nil {
                let prefix = String(format: "GRAPHICS/CREAT%03d", (kind.rawValue - 10008) / 2)
                let creatureBank = try Lemmings3Sprites(index: Data(contentsOf: root.appendingPathComponent(prefix + ".IND")),
                    commands: Data(contentsOf: root.appendingPathComponent(prefix + ".CMP")))
                let colours = try Lemmings3Sprites.palette(Data(contentsOf: root.appendingPathComponent(prefix + ".PAL")), over: palette)
                creatureImages[kind.rawValue] = try creatureBank.animations.map { animation in
                    try animation.frames.map { try image(width: animation.width, height: animation.height,
                        pixels: $0.pixels, palette: colours, opaque: $0.opaque, category: .mechanical) }
                }
            }
            guard let object = style.permanent.objects[placed.identifier], placed.identifier < 5000, object.frameCount > 1 else { continue }
            let frames = try (0..<object.frameCount).map { index in
                let frame = try style.permanent.image(object: placed.identifier, frame: index, palette: style.palette)
                return try image(width: frame.width, height: frame.height, pixels: frame.pixels, palette: style.palette, opaque: frame.pixels.map { $0 != 255 }, category: object.flags == 0x4001 ? .liquid : .mechanical)
            }
            objects.append((placementIndex, placed.x, placed.y, object.flags == 0x0402, frames))
        }
        for placed in temporary.placements {
            let frame = try style.temporary.image(object: placed.identifier, palette: style.palette)
            for y in 0..<frame.height where placed.y + y < mapHeight {
                for x in 0..<frame.width where placed.x + x < mapWidth {
                    let colour = frame.pixels[y * frame.width + x]
                    if colour != 255 { foregroundPixels[(placed.y + y) * mapWidth + placed.x + x] = colour }
                }
            }
        }
        foreground = try image(width: mapWidth, height: mapHeight, pixels: foregroundPixels, palette: palette, opaque: foregroundPixels.map { $0 != 255 }, category: terrainCategory)
        for tool in Lemmings3Runtime.Tool.allCases {
            let frame = try style.permanent.image(object: tool.rawValue, palette: palette)
            pickupImages[tool.rawValue] = try image(width: frame.width, height: frame.height, pixels: frame.pixels, palette: palette, opaque: frame.pixels.map { $0 != 255 }, category: .mechanical)
        }
    }
    func resetCamera(_ level: Lemmings3Level) {
        terrainCategory = .lemmings3Terrain(style: level.style)
        cameraX = CGFloat(min(max(0, mapWidth - 320), level.screenX))
        cameraY = CGFloat(min(max(0, mapHeight - 160), level.screenY))
    }
    private func drawImage(_ image: NSImage, x: CGFloat, y: CGFloat) {
        image.draw(in: NSRect(x: origin.x + (x - cameraX) * zoom, y: origin.y + (y - cameraY) * zoom,
            width: image.size.width * zoom, height: image.size.height * zoom), from: .zero,
            operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
    }
    private func updateSpeedTrails() {
        let enabled = usesSpeedEffects && menuRows == nil
        let actors: [SpeedTrails.Actor] = enabled ? (game?.lemmings ?? []).compactMap { lem in
            guard lem.active else { return nil }
            switch lem.state {
            case .falling, .floating, .climbing, .walking, .swimming, .jumping, .shimmying:
                return .init(id: lem.id, position: CGPoint(x: lem.x, y: lem.y), movement: lem.state.rawValue)
            default: return nil
            }
        } : []
        speedTrails.update(tick: game?.tick ?? 0, enabled: enabled, actors: actors)
    }
    override func draw(_ dirtyRect: NSRect) {
        layoutTimeline()
        NSGraphicsContext.saveGraphicsState()
        defer {
            NSGraphicsContext.restoreGraphicsState()
            layoutTimeline()
            if menuRows == nil { timeline.draw() }
        }
        defer { if menuRows == nil { startCountdown.draw(in: playfieldRect) } }
        defer {
            // The shared corner reticle also represents the controller pointer.
            assignmentHighlight.drawNotice()
            if let id = assignmentHighlight.target ?? pointerTarget,
               let lem = game?.lemmings.first(where: { $0.id == id && $0.active }) {
                let focused = assignmentHighlight.target != nil
                let centre = CGPoint(x: origin.x + (CGFloat(lem.x) - cameraX) * zoom,
                    y: origin.y + (CGFloat(lem.y - 6) - cameraY) * zoom)
                if focused {
                    assignmentHighlight.draw(at: centre, scale: zoom, tint: .systemYellow, radius: 7)
                } else {
                    LemmingSelectionGlow.draw(at: centre, scale: zoom, radius: 7,
                        tint: .systemGreen, animated: !reduceMotion)
                }
            }
            if let origin = rewindOriginTick, origin > rewindCurrentTick {
                RewindTransportCue.draw(origin: CGPoint(x: screenOrigin.x + 8, y: screenOrigin.y + 14),
                    currentTick: rewindCurrentTick, originTick: origin, scale: zoom)
            }
        }
        updateSpeedTrails()
        NSColor.black.setFill(); bounds.fill()
        guard let game, let terrain else { return }
        speedTrails.draw(enabled: usesSpeedEffects && menuRows == nil, in: playfieldRect) {
            drawWorld(game, terrain: terrain)
        }
        FailureMoodOverlay.draw(in: playfieldRect, amount: failureMoodAmount)
    }
    private func drawLemmings(_ game: Lemmings3Runtime, ghostsOnly: Bool) {
        for lem in game.lemmings where lem.active {
            // Animation IDs and anchors remain provisional. The bytes are native.
            let animation = lem.direction > 0 ? 0 : 1
            guard sprites.indices.contains(animation), !sprites[animation].isEmpty else { continue }
            let frames = sprites[animation]
            let sprite = frames[(lem.state == .blocking ? 0 : lem.age) % frames.count]
            if ghostsOnly {
                let motion = speedTrails.motion(actor: lem.id)
                let rect = CGRect(x: origin.x + (CGFloat(lem.x) - sprite.size.width / 2 - cameraX) * zoom,
                    y: origin.y + (CGFloat(lem.y) - sprite.size.height - cameraY) * zoom,
                    width: sprite.size.width * zoom, height: sprite.size.height * zoom)
                speedTrails.drawBehind(actor: lem.id, sprite: sprite, in: rect, motion: motion,
                    pixelSize: CGSize(width: zoom, height: zoom))
                continue
            }
            drawImage(sprite, x: CGFloat(lem.x) - sprite.size.width / 2, y: CGFloat(lem.y) - sprite.size.height)
            let spriteRect = CGRect(x: origin.x + (CGFloat(lem.x) - sprite.size.width / 2 - cameraX) * zoom,
                y: origin.y + (CGFloat(lem.y) - sprite.size.height - cameraY) * zoom,
                width: sprite.size.width * zoom, height: sprite.size.height * zoom)
            if assignmentPulse.target == lem.id,
               let pixels = sprite.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                assignmentPulse.draw(sprite: pixels, in: spriteRect, scale: zoom,
                    reduceMotion: reduceMotion, reduceFlashes: reduceFlashes)
            }
            if lem.charmedBy != nil {
                GameTypography.annotation("Charmed", at: NSPoint(x: origin.x + (CGFloat(lem.x - 8) - cameraX) * zoom,
                    y: origin.y + (CGFloat(lem.y - 30) - cameraY) * zoom), palette: .green)
            }
            if let tool = lem.tool ?? lem.mobilityTool {
                let label = lem.tool == nil ? "\(tool.label) \((lem.mobilityTicks + 22) / 23)s" : "\(tool.label)\(lem.quantity)"
                GameTypography.annotation(label, at: NSPoint(x: origin.x + (CGFloat(lem.x - 4) - cameraX) * zoom, y: origin.y + (CGFloat(lem.y - 23) - cameraY) * zoom), palette: .blue)
            }
        }
    }
    private func drawWorld(_ game: Lemmings3Runtime, terrain: NSImage) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: playfieldRect).addClip()
        drawImage(terrain, x: 0, y: 0)
        for (id, x, y, entrance, frames) in objects {
            let isTrap = game.configuration.traps.contains { $0.id == id }
            let index = isTrap ? game.trapFrame(id: id) : (entrance ? min(frames.count - 1, game.tick / 3) : game.tick / 3 % frames.count)
            drawImage(frames[index], x: CGFloat(x), y: CGFloat(y))
        }
        if game.terrainEdits != renderedEdits {
            var pixels = foregroundPixels
            for (index, filled) in game.terrainEdits {
                pixels[index] = filled ? brickPixels[(index / mapWidth % 8) * 8 + index % mapWidth % 8] : 255
            }
            if let frame = try? image(width: mapWidth, height: mapHeight, pixels: pixels, palette: palette, opaque: pixels.map { $0 != 255 }, category: terrainCategory) {
                foreground = frame; renderedEdits = game.terrainEdits
            }
        }
        if let foreground { drawImage(foreground, x: 0, y: 0) }
        if usesSpeedEffects { drawLemmings(game, ghostsOnly: true) }
        for pickup in game.pickups where pickup.quantity > 0 {
            if let frame = pickupImages[pickup.tool.rawValue] { drawImage(frame, x: CGFloat(pickup.x), y: CGFloat(pickup.y)) }
        }
        // Native sprite banks and palettes; animation IDs and anchors remain provisional.
        for creature in game.creatures where creature.alive {
            let animation = creature.direction > 0 ? 0 : 1
            if let bank = creatureImages[creature.kind.rawValue], bank.indices.contains(animation), !bank[animation].isEmpty {
                let frame = bank[animation][creature.age / 3 % bank[animation].count]
                drawImage(frame, x: CGFloat(creature.x) - frame.size.width / 2, y: CGFloat(creature.y) - frame.size.height)
            }
        }
        // Tool icons and blast rings are preview art until effect sprites are mapped.
        for item in game.explosives {
            if let frame = pickupImages[item.tool.rawValue] { drawImage(frame, x: CGFloat(item.x - 4), y: CGFloat(item.y - 7)) }
            let seconds = (item.fuseTicks - item.age + 22) / 23
            GameTypography.annotation("\(seconds)", at: NSPoint(x: origin.x + (CGFloat(item.x - 2) - cameraX) * zoom,
                y: origin.y + (CGFloat(item.y - 14) - cameraY) * zoom), palette: .green)
        }
        for blast in game.blasts {
            if hdEffectsEnabled && !reduceFlashes {
                ExplosionHDR.drawCore(at: CGPoint(x: origin.x + (CGFloat(blast.x) - cameraX) * zoom,
                    y: origin.y + (CGFloat(blast.y) - cameraY) * zoom),
                    pixel: CGSize(width: zoom, height: zoom), phase: game.tick - blast.tick)
            }
            NSColor.orange.setStroke()
            let ring = NSBezierPath(ovalIn: NSRect(x: origin.x + (CGFloat(blast.x - 20) - cameraX) * zoom,
                y: origin.y + (CGFloat(blast.y - 20) - cameraY) * zoom, width: 40 * zoom, height: 40 * zoom))
            ring.lineWidth = 2; ring.stroke()
        }
        for shot in game.fireballs {
            NSColor.cyan.setFill()
            NSBezierPath(ovalIn: NSRect(x: origin.x + (CGFloat(shot.x - 3) - cameraX) * zoom,
                y: origin.y + (CGFloat(shot.y - 2) - cameraY) * zoom, width: 6 * zoom, height: 4 * zoom)).fill()
        }
        drawLemmings(game, ghostsOnly: false)
        NSGraphicsContext.restoreGraphicsState()
        drawInterface()
        if !GameCursor.gameplaySuppressed, let point = pointerPosition ?? controllerPointer, playfieldRect.contains(point) {
            if showReticleCount {
                let centres = game.lemmings.filter { $0.active }.map {
                    CGPoint(x: origin.x + (CGFloat($0.x) - cameraX) * zoom,
                            y: origin.y + (CGFloat($0.y - 8) - cameraY) * zoom)
                }
                let count = SkillCursorBadge.count(centres: centres, at: point, scale: zoom)
                SkillCursorBadge.drawCount(count, at: point, scale: zoom, size: skillCursorIconSize, icon: skillCursorIconSize == .none ? nil : skillBadge, in: playfieldRect)
            }
            let target = pointerTarget
            let eligible = Lemmings3Runtime.Action.allCases.indices.contains(selectedAction)
                && target.map { game.canAssign(Lemmings3Runtime.Action.allCases[selectedAction], to: $0) } == true
            GameCursor.drawPlayfieldPointer(at: point, scale: zoom,
                tint: GameCursor.targetTint(eligible: eligible, occupied: target != nil))
            if (0..<5).contains(selectedAction) {
                SkillCursorBadge.draw(icon: skillBadge, index: selectedAction, at: point,
                    scale: zoom, tint: .systemGreen, size: skillCursorIconSize, reduceMotion: reduceMotion, in: playfieldRect)
            }
        }
        if turnBadge.superview == nil { addSubview(turnBadge) }
        turnBadge.place(in: playfieldRect)
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        layoutTimeline()
        if menuRows == nil, timeline.click(at: point) { return }
        let sx = (point.x - screenOrigin.x) / zoom, sy = (point.y - screenOrigin.y) / zoom
        if let rows = menuRows {
            let row = Int((sy - 39) / 16)
            if sx >= 32 && sx < 288 && sy >= 39 && row >= 0 && row < rows.count { onMenuRow?(row) }
            return
        }
        if directionPoint != nil {
            let rect = directionPickerRect
            if rect.contains(CGPoint(x: sx, y: sy)) {
                let dx = Int((sx - rect.minX) / 14) - 1, dy = Int((sy - rect.minY) / 14) - 1
                if let direction = Lemmings3Runtime.Direction.allCases.first(where: { $0.dx == dx && $0.dy == dy }) { onDirection?(direction) }
            } else { directionPoint = nil; onCancelDirection?() }
            needsDisplay = true; return
        }
        if variableSpeedEnabled, let part = SpeedPanelControls.part(at: CGPoint(x: sx, y: sy), in: CGRect(x: 214, y: 172, width: 35, height: 40)) {
            if part == 0 { onSpeedPress?(event.timestamp, event.clickCount) }
            else { onSpeedStep?(part, event.timestamp) }
            return
        }
        if sy >= 172 && sy < 212, let slot = Lemmings3Panel.slot(at: sx) { onPanel?(slot, event.clickCount); return }
        if sy >= 0 && sy < 12 && sx >= 280 && sx < 320 { onMenu?(); return }
        guard playfieldRect.contains(point) else { return }
        onClick?(Int(sx + cameraX), Int(sy - 12 + cameraY))
    }
    override func mouseUp(with event: NSEvent) { onSpeedRelease?(event.timestamp) }
    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { super.keyDown(with: event); return }
        if event.isARepeat, [" ", "p"].contains(event.charactersIgnoringModifiers ?? "") { return }
        if let rows = menuRows {
            if event.keyCode == 125 { menuSelection = (menuSelection + 1) % rows.count }
            else if event.keyCode == 126 { menuSelection = (menuSelection + rows.count - 1) % rows.count }
            else if event.keyCode == 36 || event.keyCode == 49 { onMenuRow?(menuSelection) }
            else if event.keyCode == 53 { onMenu?() }
            needsDisplay = true; return
        }
        if directionPoint != nil {
            if event.keyCode == 53 { directionPoint = nil; onCancelDirection?(); needsDisplay = true }
            return
        }
        switch event.keyCode {
        case 123: pan(-24, 0); return
        case 124: pan(24, 0); return
        case 125: pan(0, 16); return
        case 126: pan(0, -16); return
        default: break
        }
        if let text = event.charactersIgnoringModifiers { onKey?(text) }
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect], owner: self)
        tracking = area; addTrackingArea(area)
    }
    override func resetCursorRects() {
        guard menuRows == nil else {
            addCursorRect(bounds, cursor: NSCursor.arrow)
            return
        }
        let gameplay = playfieldRect.intersection(bounds)
        guard !gameplay.isNull, !gameplay.isEmpty else {
            addCursorRect(bounds, cursor: NSCursor.arrow)
            return
        }
        addCursorRect(gameplay, cursor: GameCursor.gameplayCursor)
        let controls = [
            CGRect(x: bounds.minX, y: bounds.minY,
                width: bounds.width, height: max(0, gameplay.minY - bounds.minY)),
            CGRect(x: bounds.minX, y: gameplay.maxY,
                width: bounds.width, height: max(0, bounds.maxY - gameplay.maxY)),
            CGRect(x: bounds.minX, y: gameplay.minY,
                width: max(0, gameplay.minX - bounds.minX), height: gameplay.height),
            CGRect(x: gameplay.maxX, y: gameplay.minY,
                width: max(0, bounds.maxX - gameplay.maxX), height: gameplay.height),
        ]
        for rect in controls where rect.width > 0 && rect.height > 0 {
            addCursorRect(rect, cursor: NSCursor.arrow)
        }
    }
    override func cursorUpdate(with event: NSEvent) {
        updateSystemCursor(at: convert(event.locationInWindow, from: nil))
    }
    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        updateSystemCursor(at: point)
        trackPointer(at: point)
    }
    private func updateSystemCursor(at point: CGPoint) {
        GameCursor.update(
            at: point,
            hidingInside: menuRows == nil ? playfieldRect : nil)
    }
    private func trackPointer(at p: CGPoint) {
        controllerPointer = nil
        assignmentHighlight.clear()
        pointerPosition = p
        hoveredLemming = pointerTarget
        toolTip = nil
        needsDisplay = true
    }
    override func mouseExited(with event: NSEvent) {
        pointerPosition = nil
        hoveredLemming = nil
        NSCursor.arrow.set()
        needsDisplay = true
    }
    private var directionPickerRect: CGRect {
        let point = directionPoint ?? .zero
        return CGRect(x: max(1, min(277, point.x - cameraX - 21)), y: max(13, min(129, point.y - cameraY - 32)), width: 42, height: 42)
    }
    private func drawInterface() {
        guard let art = panelArt, let game else { return }
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform(); transform.translateX(by: screenOrigin.x, yBy: screenOrigin.y); transform.scale(by: zoom); transform.concat()
        NSGraphicsContext.current?.imageInterpolation = .none
        NSColor.black.setFill(); CGRect(x: 0, y: 0, width: 320, height: 12).fill()
        art.text("OUT \(game.released) SAVE \(game.saved) LEFT \(game.reserve) LOST \(game.lost)", x: 2, y: 3, scale: 0.65)
        art.text("MENU", x: 286, y: 3, scale: 0.8)
        art.normal.draw(in: CGRect(x: 0, y: 172, width: 320, height: 40), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
        for slot in [selectedAction] + (fast ? [6] : []) + (paused ? [7] : []) {
            let left = CGFloat(Lemmings3Panel.edges[slot]), width = CGFloat(Lemmings3Panel.edges[slot + 1]) - left
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: CGRect(x: left, y: 172, width: width, height: 40)).addClip()
            art.pressed.draw(in: CGRect(x: 0, y: 172, width: 320, height: 40), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
            NSGraphicsContext.restoreGraphicsState()
        }
        if variableSpeedEnabled { SpeedPanelControls.draw(in: CGRect(x: 214, y: 172, width: 35, height: 40), label: speedLabel, active: fast) }
        else if fast { art.text(speedLabel.replacingOccurrences(of: "×", with: "X"), x: 218, y: 198, scale: 0.7) }
        // Time stays inside its own panel cell, never above a lemming.
        let seconds = max(0, game.remainingSeconds)
        art.text(String(format: "%02d", seconds / 60), x: 187, y: 183, scale: 0.85)
        art.text(String(format: "%02d", seconds % 60), x: 187, y: 195, scale: 0.85)
        if let id = hoveredLemming, let lem = game.lemmings.first(where: { $0.id == id }),
           let tool = lem.tool ?? lem.mobilityTool, let icon = pickupImages[tool.rawValue] {
            NSColor.black.setFill(); CGRect(x: 108, y: 176, width: 29, height: 32).fill()
            icon.draw(in: CGRect(x: 114, y: 177, width: 16, height: 16), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
            art.text(String(lem.quantity), x: 116, y: 198, scale: 0.8)
        }
        if directionPoint != nil {
            let rect = directionPickerRect
            for direction in Lemmings3Runtime.Direction.allCases {
                let x = rect.minX + CGFloat(direction.dx + 1) * 14, y = rect.minY + CGFloat(direction.dy + 1) * 14
                NSColor(calibratedWhite: 0.12, alpha: 1).setFill(); CGRect(x: x, y: y, width: 13, height: 13).fill()
                NSColor(calibratedRed: 0.8, green: 0.92, blue: 0.6, alpha: 1).setStroke()
                let centre = CGPoint(x: x + 6, y: y + 6), dx = CGFloat(direction.dx), dy = CGFloat(direction.dy)
                let tip = CGPoint(x: centre.x + dx * 4, y: centre.y + dy * 4)
                let path = NSBezierPath(); path.move(to: CGPoint(x: centre.x - dx * 3, y: centre.y - dy * 3)); path.line(to: tip)
                path.move(to: CGPoint(x: tip.x - dx * 3 - dy * 2, y: tip.y - dy * 3 + dx * 2)); path.line(to: tip)
                path.line(to: CGPoint(x: tip.x - dx * 3 + dy * 2, y: tip.y - dy * 3 - dx * 2)); path.lineWidth = 1; path.stroke()
            }
        }
        if let rows = menuRows {
            NSColor.black.withAlphaComponent(0.86).setFill(); CGRect(x: 22, y: 16, width: 276, height: 184).fill()
            art.text("LEMMINGS 3", x: 112, y: 23)
            for (index, row) in rows.enumerated() {
                if index == menuSelection { NSColor(calibratedWhite: 0.22, alpha: 1).setFill(); CGRect(x: 30, y: 38 + index * 16, width: 260, height: 15).fill() }
                art.text(row, x: 39, y: CGFloat(42 + index * 16))
            }
            art.text(menuNotice, x: 36, y: 182, scale: 0.75)
        }
        NSGraphicsContext.restoreGraphicsState()
    }
    func panAtPointer(seconds: Double) {
        guard menuRows == nil, directionPoint == nil, window?.isKeyWindow == true,
              let p = pointerPosition, playfieldRect.contains(p) else { return }
        let x = (p.x - origin.x) / zoom, y = (p.y - origin.y) / zoom
        let dx: CGFloat = x < 5 ? -1 : x > 315 ? 1 : 0
        let dy: CGFloat = y < 5 ? -1 : y > 155 ? 1 : 0
        if dx != 0 || dy != 0 { pan(dx * seconds * 100, dy * seconds * 100) }
    }
    func focusLemming(_ id: Int) {
        guard let lem = game?.lemmings.first(where: { $0.id == id && $0.active }) else { return }
        pan(CGFloat(lem.x) - 160 - cameraX, CGFloat(lem.y) - 80 - cameraY)
        assignmentHighlight.show(id); needsDisplay = true
    }
    func centre(onEntrance: Bool) {
        guard let game, let point = onEntrance ? game.configuration.entrance : game.configuration.exits.first else { return }
        pan(CGFloat(point.x) - 160 - cameraX, CGFloat(point.y) - 80 - cameraY)
    }
    func restoreCamera(x: CGFloat, y: CGFloat) { pan(x - cameraX, y - cameraY) }
    fileprivate func pan(_ x: CGFloat, _ y: CGFloat) {
        cameraX = max(0, min(CGFloat(max(0, mapWidth - 320)), cameraX + x))
        cameraY = max(0, min(CGFloat(max(0, mapHeight - 160)), cameraY + y)); needsDisplay = true
    }
    override func scrollWheel(with event: NSEvent) {
        guard menuRows == nil, directionPoint == nil else { return }
        pan(event.modifierFlags.contains(.shift) ? event.scrollingDeltaY * 4 : event.scrollingDeltaX * 4,
            event.modifierFlags.contains(.shift) ? 0 : event.scrollingDeltaY * 4)
    }
}
