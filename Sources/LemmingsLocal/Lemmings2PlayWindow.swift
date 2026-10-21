#if os(macOS)
import AppKit
import LemmingsAppCore
import LemmingsAudio
import NxlvKit

@MainActor final class Lemmings2PlayWindow: NSWindowController, NSWindowDelegate {
    struct LevelSelection: Equatable, Sendable {
        let tribe: Int
        let level: Int
    }

    struct BrowserLevel: Sendable {
        let selection: LevelSelection
        let levelID: String
        let sourceRevision: String
        let title: String
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
    var learningResultActions: LearningJourneyResultActions?
    var sequenceContinueTitle = L10n.text("Next level")
    /**
     * Controls whether this run can update campaign, replay and verified records.
     */
    var recordsCampaignProgress = true
    var sequenceRecovery: SequenceRunRecovery?
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
        host.contentView = content
        host.makeFirstResponder(content)
    }

    override func close() {
        if usesSharedWindow { onReturnToLibrary?() }
        else { super.close() }
    }

    private enum Screen { case menu, intro, practice, map, briefing, playing, results, preferences, save, load, talisman, ending, message }
    private let canvas = Lemmings2Canvas()
    private let front = Lemmings2MenuCanvas()
    private let assets: Lemmings2FrontEnd
    private let root: URL
    private let sprites: Lemmings2Sprites
    private let intern: Lemmings2SpecialGraphics
    private let walker: Lemmings2Walker?
    private let explosion: Lemmings2Explosion
    private let practice: Lemmings2Practice
    private var practiceLevel: Lemmings2Level?
    private var practiceChoice = 0
    private var practiceSkills: [Lemmings2Runtime.Skill] = [.jumper,.runner,.builder,.basher,.digger,.climber,.floater,.roper]
    private var hoverPracticeSkill: Int?
    private let masks: Lemmings2TerrainMasks
    private let music = ModuleMusicPlayer()
    private let failureMood = FailureMoodTransition()
    private let completionGlow = RescueCelebrationTransition()
    private let failureMusic = FailureMusicTransition()
    private let nukeMood = NukeMusicSweep()
    private var audioSettings = ClassicSettings()
    private var audioConfigured = false
    private var globallyMuted = false
    private let sounds: Lemmings2SoundPlayer
    private var campaign: Lemmings2Campaign
    private var game: Lemmings2Runtime?
    private var initial: Lemmings2Runtime? { didSet { arcadeLevelSnapshot = nil } }
    private var style: Lemmings2Style?
    private var preview: NSImage?
    private var screen: Screen = .menu
    private var previousScreen: Screen = .menu
    private var message = ""
    private var introduction: Lemmings2Introduction?
    private var timer: Timer?
    private var lastTime = ProcessInfo.processInfo.systemUptime
    private var accumulator = 0.0
    private var frontTicks = 0
    private var paused = false
    private var userPausedMusic = false
    private var assignmentFocus = AssignmentFocus()
    private var gameplayKeyboard: GameplayKeyboard?
    func showKeyboardCommands() { gameplayKeyboard?.showHelp() }
    private let speedControl = GameSpeedControl(legacyMultiplier: 3)
    private var fastForward: Bool {
        get { speedControl.isFast }
        set { speedControl.setFast(newValue) }
    }
    private var countdownWarning = LastSecondsWarning()
    private let dj = AdaptiveDJPlayer()
    private let manualDJHandoff = LegacyDJCrossfade()
    private var settingsProfileID: String?
    private let runMovie = RunMovie()
    private var replaySize = CGSize(width: 1280, height: 960)
    private var arcadeRunID = UUID()
    private var arcadeProfileID = ArcadeProfile.legacyID
    private var arcadeHotSeatID: String?
    private var arcadeReport: ArcadeReport?
    private var usedRewind = false
    private var nukeCount = 0
    private var undoCount = 0
    var canSwitchProfile: Bool { game == nil || game?.tick == 0 || game?.isComplete == true }
    var hasCompletedAttempt: Bool { game?.isComplete == true }
    private var arcadeLevelSnapshot: ArcadeLevel?
    private var arcadeLevel: ArcadeLevel? {
        if let arcadeLevelSnapshot { return ExtraSkillMac.level(arcadeLevelSnapshot, attemptID: arcadeRunID, profileID: arcadeProfileID) }
        guard let game else { return nil }
        let c = game.configuration
        let skills = Dictionary(zip(c.skills, c.supplies).map { (TrolleyCapture.skillKey($0.0.name), $0.1) }, uniquingKeysWith: +)
        let rules = practiceLevel == nil ? "l2-native-v1" : "l2-practice-v1"
        let fingerprint = level.fingerprint + ":" + TrolleyCapture.contentFingerprint(root: root)
        let conditions = TrolleyConditions(gameID: "lemmings2", packID: "tribes", levelID: practiceLevel == nil ? "\(campaign.tribe):\(campaign.level)" : "practice-\(practiceChoice)",
            levelFingerprint: fingerprint, rulesetVersion: rules, physicsMode: rules,
            population: c.total, rescueRequirement: 1, startingSkills: skills, timeLimitSeconds: Double(c.timeLimit),
            modifiers: ["practice": String(c.isPractice), "releaseInterval": String(c.releaseInterval),
                        "firstReleaseTick": String(c.firstReleaseTick), "goldRequirement": String(max(1, c.total - level.allowedLossesForGold))])
        return ArcadeLevel(id: "l2:" + level.fingerprint, title: level.title,
            game: L10n.text("Lemmings 2 - \(Lemmings2Campaign.tribeNames[level.style])"), rules: rules,
            total: c.total, required: 1, conditions: conditions)
    }
    private var fanSelected = false
    private var selected = 0
    private var nukeGesture = NukeClickGesture()
    private let recoveryStore = RunRecoveryStore()
    private var recoveryInputs: [L2RunRecovery.Input] = []
    private var recoveryPractice: L2RunRecovery.Practice?
    private var recoveryProgress: Lemmings2Campaign.Progress?
    private var recoveryInitialHash = ""
    private var lastFanInput: L2RunRecovery.Input.Action?
    private var lastAimInput: L2RunRecovery.Input.Action?
    private var beforeNukeInputCount = 0
    private var lastCheckpointTime = 0.0
    private var restoringRun = false
    private var beforeNuke: Lemmings2Runtime?
    private var rewindTimer: Timer?
    private var rewindHeld = false
    private var forwardTimer: Timer?
    private var forwardHeld = false
    private var timelineTransport: TimelineKeyTransport?
    private var rewindOriginState: Lemmings2Runtime?
    private var rewindOriginInputs: [L2RunRecovery.Input] = []
    private var rewindOriginNukeCount = 0
    private var rewindOriginBeforeNuke: Lemmings2Runtime?
    private var rewindOriginBeforeNukeInputCount = 0
    private var selectedSlot = 0
    private var ending: Lemmings2Ending?
    private var award: Lemmings2Award?
    private var hoverTribe: Int?
    private let progressKey: String
    private var level: Lemmings2Level { practiceLevel ?? campaign.current }

    private struct DecodedAssets: Sendable {
        let practice: Lemmings2Practice
        let front: Lemmings2FrontEnd
        let campaign: Lemmings2Campaign
        let sprites: Lemmings2Sprites
        let masks: Lemmings2TerrainMasks
        let intern: Lemmings2SpecialGraphics
        let explosion: Lemmings2Explosion
        let walker: Lemmings2Walker?
        let sound: Lemmings2SoundBank
    }
    nonisolated private static let decodedCache = GameAssetCache<DecodedAssets>(capacity: 2)

    nonisolated private static func decodedAssets(root: URL) throws -> DecodedAssets {
        try Task.checkCancellation()
        let key = GameAssetCache<DecodedAssets>.bundledKey(root)
        if let key, let cached = decodedCache.value(for: key) { return cached }
        let practice = try Lemmings2Practice(root: root)
        let front = try Lemmings2FrontEnd(root: root)
        try Task.checkCancellation()
        let campaign = try Lemmings2Campaign(root: root)
        let sprites = try Lemmings2Sprites(data: Data(contentsOf: root.appendingPathComponent("VLEMMS.DAT")))
        try Task.checkCancellation()
        let masks = try Lemmings2TerrainMasks(root: root)
        let intern = try Lemmings2SpecialGraphics(data: Data(contentsOf: root.appendingPathComponent("INTERN.DAT")))
        let explosion = try Lemmings2Explosion(root: root)
        let walker = (try? Data(contentsOf: root.appendingPathComponent("WALKER.DAT")))
            .flatMap { try? Lemmings2Walker(data: $0) }
        let sound = try Lemmings2SoundBank(data: Data(contentsOf: root.appendingPathComponent("MUSIC/SBLAST.VOC")))
        try Task.checkCancellation()
        let assets = DecodedAssets(practice: practice, front: front, campaign: campaign, sprites: sprites,
            masks: masks, intern: intern, explosion: explosion, walker: walker, sound: sound)
        if let key { decodedCache.insert(assets, for: key) }
        return assets
    }

    nonisolated static func warmAssets(root: URL) throws {
        guard GameAssetCache<DecodedAssets>.bundledKey(root) != nil else { return }
        _ = try decodedAssets(root: root)
    }

    init(root: URL, recovery: RunRecovery? = nil, selection: LevelSelection? = nil,
         sequenceProgress: Data? = nil,
         expectedLevelID: String? = nil,
         expectedSourceRevision: String? = nil,
         recordsCampaignProgress: Bool = true,
         expectedRecoveryEngine: String = RunRecovery.bundledEngine) throws {
        if let recovery {
            _ = try recovery.validated()
            // A newer engine must not strand a saved run; the replay below checks the state.
            guard recovery.l2 != nil else { throw RunRecoveryError.differentGame }
            guard recovery.profileID == ArcadeStore.shared.playingProfileID,
                recovery.hotSeatID == ArcadeStore.shared.hotSeatID else { throw RunRecoveryError.differentSession }
        }
        if let expectedSourceRevision {
            guard let selection else {
                throw SequelDataError.invalid(L10n.text("The selected Lemmings 2 level is no longer available."))
            }
            let source = LevelPreviewSource.lemmings2(
                root: root, selection: selection, expectedLevelID: expectedLevelID ?? "")
            guard try source.sourceRevision() == expectedSourceRevision else {
                throw SequelDataError.invalid(
                    L10n.text("The selected Lemmings 2 level data changed. Open Level Select and choose it again."))
            }
        }
        self.root = root
        let decoded = try Self.decodedAssets(root: root)
        practice = decoded.practice; assets = decoded.front
        sounds = try Lemmings2SoundPlayer(root: root, bank: decoded.sound)
        campaign = decoded.campaign; sprites = decoded.sprites; masks = decoded.masks
        intern = decoded.intern; explosion = decoded.explosion; walker = decoded.walker
        self.recordsCampaignProgress = recordsCampaignProgress
        progressKey = Self.campaignProgressKey(root: root)
        if !recordsCampaignProgress, let sequenceProgress {
            try campaign.restore(JSONDecoder().decode(Lemmings2Campaign.Progress.self, from: sequenceProgress))
        } else if let data = UserDefaults.standard.data(forKey: progressKey),
           let saved = try? JSONDecoder().decode(Lemmings2Campaign.Progress.self, from: data) {
            try? campaign.restore(saved)
        }
        if recovery == nil, let selection {
            let index = selection.tribe * 10 + selection.level
            guard campaign.levels.indices.contains(index),
                  expectedLevelID == nil || campaign.levels[index].fingerprint == expectedLevelID else {
                throw SequelDataError.invalid(
                    L10n.text("The selected Lemmings 2 level changed. Open Level Select and choose it again."))
            }
            try campaign.select(tribe: selection.tribe, level: selection.level)
        }
        super.init(window: NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false))
        guard let window else { return }
        nukeMood.onChange = { [weak self] amount in
            guard let self else { return }
            self.music.setNukeAmount(Float(amount))
            self.dj.setNukeAmount(Float(amount))
        }
        completionGlow.onChange = { [weak self] amount in
            self?.canvas.completionGlowAmount = amount
            self?.canvas.needsDisplay = true
        }
        failureMood.onChange = { [weak self] amount in
            guard let self else { return }
            self.canvas.failureMoodAmount = amount
            self.canvas.needsDisplay = true
        }
        failureMusic.onChange = { [weak self] tempo in
            self?.music.setTempoScale(tempo)
            self?.dj.setPlaybackRate(tempo)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(artworkChanged),
            name: SequelArtworkPreference.changed, object: nil)
        window.title = L10n.text("Lemmings 2 — The Tribes")
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 640, height: 502)
        window.contentView = front
        front.onDraw = { [weak self] in self?.drawFront() }
        front.menuActions = { [weak self] in self?.accessibleFrontActions() ?? [] }
        front.onClick = { [weak self] x, y in self?.clickFront(x, y) }
        front.onMove = { [weak self] x, y in
            guard let self else { return }
            if self.screen == .practice {
                self.hoverPracticeSkill = self.practiceSkillAt(x,y); self.front.needsDisplay = true; return
            }
            guard self.screen == .map else { return }
            self.hoverTribe = self.tribeAt(x, y); self.front.needsDisplay = true
        }
        front.onKey = { [weak self] key in self?.key(key) }
        canvas.onCameraChanged = { [weak self] in
            guard let self else { return }
            self.sounds.setViewport(self.canvas.soundViewport)
        }
        canvas.onClick = { [weak self] x, y in self?.assign(x, y) }
        canvas.onRelease = { [weak self] in self?.releasePointerInput() }
        canvas.onPointer = { [weak self] x, y, held in
            guard let self else { return }
            self.performRecoveryInput(.fan(x:x,y:y,active:held && self.fanSelected && !self.paused))
            self.performRecoveryInput(.aim(x:x,y:y,held:held && !self.fanSelected && !self.paused))
        }
        canvas.onPanel = { [weak self] slot, count, time in self?.panelAction(slot, clickCount: count, time: time) }
        canvas.onHover = { [weak self] in self?.refreshGame() }
        canvas.onPrecisionScroll = { [weak self] action, point in self?.scrollPrecisionZoom(action, at: point) }
        canvas.onKey = { [weak self] key in self?.key(key) }
        let keyboard = GameplayKeyboard(window: window)
        gameplayKeyboard = keyboard
        canvas.timeline.enabled = { [weak self] action in
            guard let self, self.screen == .playing, let game = self.game else { return false }
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
        keyboard.active = { [weak self] in self?.screen == .playing && self?.game?.isComplete == false }
        keyboard.musicDisplayArea = { [weak self] in self?.canvas.gameplayRect }
        keyboard.playingTrack = { [weak self] in
            guard let self, self.audioSettings.music != .silent else { return nil }
            let url = self.dj.currentURL ?? (self.music.isRunning ? self.music.currentURL : nil)
            return url.map { PlayingTrackMetadata.track(url: $0, fallbackTitle: self.music.currentURL == $0 ? self.music.currentTitle : nil) }
        }
        keyboard.assignSelected = { [weak self] in
            guard let self, let id = self.canvas.assignmentHighlight.target ?? self.canvas.pointerTarget(slot: self.selected) else { return }
            if self.performRecoveryInput(.assign(slot: self.selected, lemming: id)) {
                self.assignmentFocus.record(id: id, skill: self.selected, tick: self.game?.tick ?? 0)
                self.canvas.didAssign(to: id)
            } else {
                self.playAssignmentRejection(id)
            }
            self.sounds.play(self.game?.drainSoundEvents() ?? []); self.refreshGame()
        }
        keyboard.togglePause = { [weak self] in self?.panelAction(8) }
        keyboard.movePointer = { [weak self] dx, dy in self?.canvas.moveControllerPointer(dx, dy) }
        keyboard.panCamera = { [weak self] dx, dy in self?.canvas.controllerPan(dx, dy) }
        keyboard.menuActive = { [weak self] in self?.screen == .menu && self?.game != nil }
        keyboard.nukeToggle = { [weak self] in self?.toggleNukeFromKeyboard() }
        keyboard.menuKey = { [weak self] key in
            guard let self else { return }
            if key == "\u{1b}" { self.playFromMenu() } else { self.key(key) }
        }
        keyboard.focusUnassigned = { [weak self] direction in
            guard let self, let game = self.game else { return }
            guard let id = self.assignmentFocus.next(activeIDs: game.lemmings.filter(\.active).map(\.id), direction: direction) else {
                self.canvas.setAccessibilityLabel(L10n.text("No unassigned lemmings"))
                self.canvas.showFocusNotice(L10n.text("No unassigned lemmings")); return
            }
            self.canvas.focusLemming(id)
        }
        keyboard.focusLast = { [weak self] in
            guard let self, let id = self.assignmentFocus.lastID else { return }
            self.canvas.focusLemming(id)
        }
        keyboard.repeatAssignment = { [weak self] in
            guard let self, let skill = self.assignmentFocus.lastSkill,
                  let id = self.canvas.assignmentHighlight.target ?? self.canvas.pointerTarget(slot: skill) else { return }
            if self.performRecoveryInput(.assign(slot: skill, lemming: id)) {
                self.assignmentFocus.record(id: id, skill: skill, tick: self.game?.tick ?? 0)
                self.canvas.didAssign(to: id)
            } else {
                self.playAssignmentRejection(id)
            }
            self.sounds.play(self.game?.drainSoundEvents() ?? []); self.refreshGame()
        }
        canvas.onSpeedPress = { [weak self] time, count in self?.speedControl.pointerDown(at: time, clickCount: count) }
        canvas.onSpeedRelease = { [weak self] time in self?.speedControl.release(.mouse, at: time) }
        canvas.onSpeedStep = { [weak self] direction, time in self?.speedControl.step(direction, at: time) }
        keyboard.speedControl = speedControl
        keyboard.precisionZoom = { [weak self] kind in self?.togglePrecisionZoom(kind) }
        keyboard.extraSkill = { [weak self] in self?.useExtraSkill() }
        keyboard.extraSkillTitle = { [weak self] in
            guard let self else { return L10n.text("Bonus skill") }
            return self.canvas.precisionStatus.bonusSkillUsed ? L10n.text("Bonus skill used")
                : L10n.text("Bonus skill (\(self.canvas.precisionStatus.extraSkills))")
        }
        keyboard.extraSkillHelp = { L10n.text("Choose one extra use of a level skill. One per attempt. (⌘E)") }
        keyboard.extraSkillAvailable = { [weak self] in self?.extraSkillAvailable ?? false }
        speedControl.onMusicPitchChange = { [weak self] cents in
            self?.music.setSpeedPitch(cents)
            self?.dj.setSpeedPitch(cents)
        }
        keyboard.modern = { [weak self] in self?.audioSettings.modernControlsEnabled ?? true }
        speedControl.onChange = { [weak self] in self?.accumulator = 0; self?.refreshGame() }
        keyboard.cycle = { [weak self] direction in
            guard let self, let game = self.game,
                  let index = SkillShortcuts.cycle(from: self.selected, direction: direction, available: game.supplies.map { $0 > 0 }) else { return }
            self.panelAction(index)
        }
        keyboard.selectGliderBeforeGoal = { [weak self] in
            guard let self, let slot = self.game?.configuration.skills.firstIndex(of: .hangGlider), self.selected != slot else { return false }
            self.selected = slot; self.fanSelected = false; self.refreshGame(); return true
        }
        keyboard.centre = { [weak self] entrance in self?.canvas.centre(onEntrance: entrance) }
        keyboard.navigationReduceMotion = { [weak self] in
            self?.audioSettings.reduceMotion == true || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }
        keyboard.showSongInfo = { [weak self] in self?.audioSettings.showSongInfo ?? true }
        keyboard.navigationArtworkOpacityChanged = { [weak self] in self?.canvas.precisionStatusOpacity = $0 }
        keyboard.rewardStatus = { [weak self] in self?.canvas.precisionStatus }
        keyboard.rewardDisplayArea = { [weak self] in
            guard let self, let root = self.window?.contentView else { return nil }
            return root.convert(self.canvas.rewardBadgeRect, from: self.canvas)
        }
        keyboard.fadeMenuButton = { [weak self] in self?.audioSettings.fadeMenuButton ?? true }
        keyboard.mainMenu = { [weak self] in
            guard let self else { return }
            self.paused = true; self.fanSelected = false; self.releasePointerInput()
            self.saveCheckpoint(immediately: true)
            if let exit = self.onReturnToLibrary { exit() } else { self.show(.menu) }
        }
        keyboard.escape = { [weak self] in
            guard let self else { return }
            if self.cancelRewindToOrigin() { return }
            if self.fanSelected { self.fanSelected = false; self.releasePointerInput(); self.refreshGame() }
            else { self.releasePointerInput(); self.key("\u{1b}") }
        }
        keyboard.cyclesSharedSkillLetters = false
        keyboard.overlayControls = { [weak self] in self?.canvas.accessibilityChildren() ?? [] }
        keyboard.skillNames = { [weak self] in self?.game?.configuration.skills.map(\.name) ?? [] }
        keyboard.engineCommands = { GameplayKeyboard.playCommands(pauseKey: "Space / P", retry: true, nuke: false) }
        keyboard.inspectionAvailable = { [weak self] in
            guard let self else { return false }
            return self.audioSettings.inspectWhilePaused && self.screen == .playing && self.paused && !self.canvas.startCountdown.isActive
        }
        canvas.inspectionSelectionAvailable = keyboard.inspectionAvailable
        keyboard.inspectionHoverID = { [weak self] in self?.canvas.inspectionPointerID }
        keyboard.inspectionHoverRevision = { [weak self] in
            guard let self else { return "" }
            return "\(self.arcadeRunID):\(self.game?.tick ?? 0):\(self.recoveryInputs.count)"
        }
        keyboard.inspectionHoverSnapshot = { [weak self] in
            guard let self, let initial = self.initial, let game = self.game else { return nil }
            return try? LemmingInspection(initial: .lemmings2(initial), current: .lemmings2(game),
                commands: self.recoveryInputs.map(LeaderboardActionReplay.Command.l2))
        }
        keyboard.inspectLemmings = { [weak self] in
            guard let self, self.screen == .playing, self.paused, !self.canvas.startCountdown.isActive,
                  let initial = self.initial, let game = self.game,
                  let snapshot = try? LemmingInspection(initial: .lemmings2(initial), current: .lemmings2(game),
                    commands: self.recoveryInputs.map(LeaderboardActionReplay.Command.l2)) else { return }
            GameScreen.shared.present(LemmingInspectionPage(snapshot: snapshot,
                selectedID: self.canvas.inspectionPointerID ?? self.assignmentFocus.lastID), owner: self.window)
        }
        keyboard.contextCommands = {
            [KeyboardCommand(keys: L10n.text("Arrow keys"), action: L10n.text("Pan the level"), group: L10n.text("Camera")),
             KeyboardCommand(keys: L10n.text("V / S"), action: L10n.text("Review / save replay after a result"), group: L10n.text("Menus & results")),
             KeyboardCommand(keys: L10n.text("Return / Space"), action: L10n.text("Activate selected menu choice"), group: L10n.text("Menus & results")),
             KeyboardCommand(keys: ", / LT + B", action: L10n.text("Rewind the current run"), group: L10n.text("Gameplay")),
             KeyboardCommand(keys: ", / .", action: L10n.text("Step one tick; hold to scrub; release to pause"), group: L10n.text("Gameplay")),
             KeyboardCommand(keys: L10n.text("P / M / I"), action: L10n.text("From L2 menu: practice / tribe map / introduction"), group: L10n.text("Menus & results")),
             KeyboardCommand(keys: "1–4", action: L10n.text("Choose practice level"), group: L10n.text("L2 practice")),
             KeyboardCommand(keys: L10n.text("Arrow keys"), action: L10n.text("Choose practice skill"), group: L10n.text("L2 practice")),
             KeyboardCommand(keys: L10n.text("Space / Return"), action: L10n.text("Toggle practice skill / start practice"), group: L10n.text("L2 practice")),
             KeyboardCommand(keys: "← / →", action: L10n.text("Choose tribe on map"), group: L10n.text("Menus & results")),
             KeyboardCommand(keys: L10n.text("R / B"), action: L10n.text("After a result: retry / records"), group: L10n.text("Menus & results"))]
        }
        keyboard.hints = { [weak self] in self?.showLevelHints() }
        keyboard.settings = { [weak self] in self?.onShowSettings?() }
        keyboard.nextGraphics = { SequelArtworkPreference.setEnabled(!SequelArtworkPreference.enabled) }
        keyboard.graphicsName = {
            SequelArtworkPreference.enabled ? L10n.text("Macintosh-style 2x") : L10n.text("Original PC")
        }
        keyboard.djShuffle = { [weak self] in self?.shuffleMusic() }
        keyboard.pauseOnInterruption = { [weak self] in self?.audioSettings.pauseOnInterruption ?? true }
        keyboard.onInterruption = { [weak self] in self?.interruptGameplay() }
        keyboard.controllerEnabled = { [weak self] in self?.audioSettings.controllerEnabled ?? false }
        keyboard.controllerTapSpeed = { [weak self] in self?.audioSettings.controllerTapSpeed ?? true }
        keyboard.controllerMappings = { [weak self] in self?.audioSettings.controllerMappings ?? [:] }
        keyboard.controllerSwapSticks = { [weak self] in self?.audioSettings.controllerSwapSticks ?? false }
        keyboard.retry = { [weak self] in self?.retryLevel() }
        keyboard.rewind = { [weak self] in _ = self?.rewind(seconds: 2) }
        keyboard.controllerRewindHeld = { [weak self] held in
            guard let self else { return }
            if held { _ = self.beginContinuousRewind(advanceImmediately: false) }
            else if self.rewindHeld { self.endContinuousRewind() }
        }
        keyboard.step = { [weak self] direction in
            guard let self else { return }
            if direction < 0 { _ = self.rewind(seconds: 1.0 / Lemmings2Runtime.ticksPerSecond) }
            else if !self.stepForward(seconds: 1.0 / Lemmings2Runtime.ticksPerSecond) { self.singleStep() }
        }
        keyboard.endRun = { [weak self] in
            guard let self else { return }
            let nuke = Lemmings2Control.nuke.rawValue
            if self.beforeNuke != nil { self.panelAction(nuke); return }
            GameScreen.shared.confirm(L10n.text("End this run?"), detail: L10n.text("Start the nuke countdown for the remaining lemmings."),
                actionTitle: L10n.text("Start nuke"), owner: self.window) { [weak self] in
                guard let self else { return }
                let now = ProcessInfo.processInfo.systemUptime
                self.nukeGesture.reset(); self.panelAction(nuke, time: now); self.panelAction(nuke, time: now + 0.01)
            }
        }
        keyboard.pauseForHelp = { [weak self] in
            guard let self else { return {} }
            let interruption = self.gameplayKeyboard?.interruptionCount
            let wasPaused = self.paused
            self.paused = true; self.releasePointerInput(); self.saveCheckpoint(immediately: true); self.refreshGame()
            return { [weak self] in
                guard let self else { return }
                self.paused = wasPaused || self.gameplayKeyboard?.interruptionCount != interruption
                self.accumulator = 0; self.refreshGame()
            }
        }
        timelineTransport = makeTimelineTransport(for: window)

        let musicRoot = root.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Music/lemmings_2_music_mod_tsyu")
        music.loadLibrary(at: musicRoot)
        music.setMuted(UserDefaults.standard.bool(forKey: progressKey + ".musicMuted"))
        sounds.setMuted(UserDefaults.standard.bool(forKey: progressKey + ".soundsMuted"))
        try sounds.start()
        NotificationCenter.default.addObserver(self,selector:#selector(windowLostFocus(_:)),
            name:NSWindow.didResignKeyNotification,object:nil)
        window.center()
        if let recovery, let saved = recovery.l2 {
            if let savedPractice = saved.practice {
                practiceChoice = savedPractice.choice
                practiceSkills = savedPractice.skills.compactMap(Lemmings2Runtime.Skill.init(rawValue:))
                practiceLevel = practice.levels[practiceChoice]
            } else {
                try campaign.restore(saved.progress)
            }
            restoringRun = true
            prepareBriefing(); startLevel()
            // Compare the level only. Other data files may change between builds;
            // the replay below still requires the exact saved state.
            guard let initial, let fingerprint = arcadeLevel?.conditions?.levelFingerprint,
                fingerprint.split(separator: ":").first == recovery.levelFingerprint.split(separator: ":").first
            else { throw RunRecoveryError.differentGame }
            let restored = try saved.restore(initial: initial, checkpoint: recovery)
            game = restored.0; beforeNuke = restored.1; beforeNukeInputCount = restored.2
            recoveryInputs = saved.inputs; recoveryProgress = saved.progress; recoveryPractice = saved.practice
            recoveryInitialHash = recovery.initialStateHash
            arcadeRunID = recovery.runID; arcadeProfileID = recovery.profileID; arcadeHotSeatID = recovery.hotSeatID
            try ExtraSkillMac.restore(recovery, level: arcadeLevel)
            PrecisionZoomController.shared.start(attemptID: arcadeRunID, profileID: arcadeProfileID)
            syncPrecisionZoom()
            recordCollectionVisit()
            usedRewind = recovery.usedRewind; nukeCount = recovery.nukeCount; undoCount = recovery.undoCount
            canvas.startCountdown.cancel()
            selected = recovery.selectedSkill; paused = true; fanSelected = false
            canvas.cameraX = CGFloat(recovery.scrollX); canvas.cameraY = CGFloat(recovery.scrollY)
            arcadeLevelSnapshot = arcadeLevel
            restoringRun = false
            releasePointerInput(); refreshGame()
        } else if selection != nil { prepareBriefing() }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    #if HOT_SEAT_GHOST_TESTS
    func hotSeatGhostTestContext() -> LeaderboardReplayContext? {
        timer?.invalidate(); timer = nil
        prepareBriefing(); startLevel(); canvas.startCountdown.cancel()
        return leaderboardReplayContext()
    }
    #endif
    #if APP_INTEGRATION_TESTS
    func testGameplayQuickControls() throws {
        timer?.invalidate(); timer = nil; paused = true
        startLevel(); paused = true; canvas.startCountdown.cancel(); refreshGame()
        let before = try L2RunRecovery.stateHash(game!)
        let selectedBefore = selected
        try validateGameplayQuickControls(gameplayKeyboard!, owner: window!, name: "lemmings2", statusFrames: {
            [self.canvas.convert(self.canvas.statusReadoutFrame, to: self.window!.contentView!)]
        })
        try checkGameplayQuickControl(try L2RunRecovery.stateHash(game!) == before && selected == selectedBefore && paused,
            "Lemmings 2 quick controls changed the run")
    }
    func testExtraSkillGrant() throws {
        func require(_ value: Bool, _ message: String) throws {
            if !value { throw SequelDataError.invalid(message) }
        }
        func buttons(_ view: NSView) -> [NSButton] {
            (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(buttons)
        }
        GameScreen.shared.dismissAll()
        timer?.invalidate(); timer = nil
        prepareBriefing(); startLevel(); paused = true; canvas.startCountdown.cancel()
        guard let base = initial, let slot = base.configuration.skills.indices.first(where: {
            base.canGrantBonusSkill(slot: $0)
        }), let window else { throw SequelDataError.invalid("L2 extra-skill fixture has no supplied slot") }
        selected = slot
        singleStep(); singleStep(); paused = true
        syncPrecisionZoom()
        let store = ArcadeStore.shared, attemptID = arcadeRunID, owner = arcadeProfileID
        let balance = store.records.extraSkills(profileID: owner).available
        try require(balance > 0 && extraSkillAvailable, "L2 earned bonus skill was unavailable")
        let originalStock = game!.supplies
        let skill = TrolleyCapture.skillKey(base.configuration.skills[slot].name)
        useExtraSkill()
        guard let page = GameScreen.shared.controllerPage(in: window),
              let use = buttons(page).first(where: { $0.title == L10n.text("Use bonus skill") }) else {
            throw SequelDataError.invalid("L2 did not open the extra-skill chooser")
        }
        try require(use.accessibilityPerformPress(), "L2 extra-skill action did not activate")
        try require(game!.supplies[slot] == originalStock[slot] + 1 && game!.bonusSkillSlot == slot
            && arcadeLevel?.conditions?.bonusSkillID == skill && paused,
            "L2 chooser did not grant exactly one selected skill while paused")
        try require(store.records.extraSkills(profileID: owner).available == balance - 1
            && store.records.extraSkillSpent(attemptID: attemptID, profileID: owner) == skill
            && !extraSkillAvailable && canvas.precisionStatus.bonusSkillUsed,
            "L2 grant did not spend once or retain its bonus marker")
        let grantCount = recoveryInputs.filter { if case .bonusSkill = $0.action { return true }; return false }.count
        try require(grantCount == 1, "L2 grant was missing from its replay inputs")
        let replayed = try L2RunRecovery.replay(initial: base, inputs: recoveryInputs, through: game!.tick)
        try require(try L2RunRecovery.stateHash(replayed) == L2RunRecovery.stateHash(game!),
            "L2 extra-skill replay changed the runtime")
        guard var checkpoint = try makeCheckpoint(engine: "extra-skill-test"), let saved = checkpoint.l2 else {
            throw SequelDataError.invalid("L2 extra-skill checkpoint was unavailable")
        }
        checkpoint.stateHash = try L2RunRecovery.stateHash(game!)
        let decoded = try JSONDecoder().decode(RunRecovery.self, from: JSONEncoder().encode(checkpoint))
        let restored = try saved.restore(initial: base, checkpoint: decoded).0
        try require(restored.bonusSkillSlot == slot && decoded.extraSkillUse?.skill == skill,
            "L2 checkpoint lost the bonus skill or spending evidence")
        useExtraSkill()
        try require(GameScreen.shared.controllerPage(in: window) == nil
            && store.records.extraSkills(profileID: owner).available == balance - 1,
            "L2 offered or spent a second bonus skill")
        try require(rewind(seconds: 1), "L2 bonus attempt could not rewind before its grant")
        syncPrecisionZoom()
        try require(game?.bonusSkillUsed == false && arcadeLevel?.conditions?.bonusSkillID == skill
            && !extraSkillAvailable && canvas.precisionStatus.bonusSkillUsed,
            "L2 rewind lost bonus provenance or allowed another grant")
        guard var branch = try makeCheckpoint(engine: "extra-skill-test") else {
            throw SequelDataError.invalid("L2 rewound bonus checkpoint was unavailable")
        }
        branch.stateHash = try L2RunRecovery.stateHash(game!)
        try require(try branch.validated().extraSkillUse?.skill == skill,
            "L2 rewound checkpoint lost irreversible spending evidence")
        restart()
        try require(arcadeRunID != attemptID && game!.supplies == base.supplies
            && game?.bonusSkillUsed == false && arcadeLevel?.conditions?.bonusSkillID == nil && paused
            && !canStepForward && !stepForward(seconds: 1)
            && store.records.extraSkills(profileID: owner).available == balance - 1,
            "L2 retry retained its bonus stock, changed its pause, or refunded the reward")
        print("PASS native L2 chooser grant, one spend, replay/checkpoint, rewind provenance and paused clean retry")
    }
    var testRecoveryIsPaused: Bool { paused }
    func testRecoveryAdvance(ticks: Int) {
        timer?.invalidate(); timer = nil
        if screen == .briefing { startLevel() }
        canvas.startCountdown.cancel(); selected = 1
        for _ in 0..<ticks { singleStep() }
    }

    func testLeaderboardContext() -> LeaderboardReplayContext? {
        timer?.invalidate(); timer = nil; prepareBriefing(); startLevel(); canvas.startCountdown.cancel()
        return leaderboardReplayContext()
    }
    func testExitAndSequenceResult(won: Bool) throws {
        timer?.invalidate(); startLevel(); paused = true; canvas.startCountdown.cancel()
        try validateExitControl(gameplayKeyboard!, owner: window!, name: "lemmings2")
        try validateRecordNavigation(recordLevelChoices(), current: arcadeLevel!, owner: window!, name: "lemmings2-pack")
        let configuration = Lemmings2Runtime.Configuration(width: 128, height: 96,
            pixels: Array(repeating: 0, count: 128 * 96), solid: Array(repeating: false, count: 128 * 96),
            palette: Array(repeating: 0, count: 1024), entrance: .init(x: 32, y: 32, width: 1, height: 1),
            exits: [.init(x: won ? 0 : 100, y: won ? 0 : 80, width: won ? 128 : 8, height: won ? 96 : 8)],
            skills: game!.configuration.skills, supplies: game!.configuration.supplies,
            total: 1, timeLimit: 1, releaseInterval: 1, terrainMasks: masks, firstReleaseTick: 1)
        var fixture = try Lemmings2Runtime(configuration: configuration)
        for _ in 0..<100 where !fixture.isComplete { fixture.step() }
        try validateMusicRouting(fixture.isComplete && fixture.didWin == won, L10n.text("L2 completion fixture failed"))
        game = fixture; arcadeLevelSnapshot = rewardFixtureLevel("lemmings2"); arcadeReport = nil; arcadeRunID = UUID()
        finishIfComplete(fixture)
        try validateMusicRouting(ArcadeStore.shared.records.trolley.attempts.contains { $0.id == arcadeRunID }, L10n.text("L2 sequence result did not persist career stars"))
        refreshGame()
        completionGlow.advance(at: ProcessInfo.processInfo.systemUptime + 0.7)
        try validateMusicRouting(canvas.completionGlowAmount == (won ? 1 : 0), L10n.text("L2 result celebration state is wrong"))
        try validateCompletionGlow(canvas, name: "lemmings2-\(won)") { self.canvas.completionGlowAmount = $0 }
        canvas.completionGlowAmount = won ? 1 : 0
    }
    func testCollectionVisitAndRetry() throws {
        timer?.invalidate()
        startLevel()
        guard let entry = LevelCollections.entry(attemptID: arcadeRunID), entry.identity.engine == .lemmings2,
              paused else { throw SequelDataError.invalid(L10n.text("L2 did not record its paused start")) }
        restart()
        guard LevelCollections.entry(attemptID: arcadeRunID)?.identity == entry.identity,
              paused, speedControl.multiplier == 1 else {
            throw SequelDataError.invalid(L10n.text("L2 retry lost its collection identity or pause"))
        }
        print(L10n.text("PASS native L2 visit and paused retry"))
    }
    func testInitialMusicRouting() throws {
        timer?.invalidate()
        try validateMusicRouting(!music.isRunning && !dj.isPlaying, L10n.text("L2 played music before audio configuration"))
        var settings = ClassicSettings()
        settings.music = .adaptiveDJ; settings.musicVolume = 0; settings.soundVolume = 0
        setAudioSettings(settings, muted: true)
        try validateMusicRouting(dj.isPlaying && dj.currentURL != nil &&
            dj.currentURL?.lastPathComponent.lowercased().contains("maintune") == false,
            L10n.text("L2 selected menu music during a level handover"))
        let track = dj.currentURL
        playTribeMusic()
        try validateMusicRouting(dj.currentURL == track && !dj.isCrossfading,
            L10n.text("L2 repeated a handover track selection"))
    }

    func testRidiculousSpeed() throws {
        timer?.invalidate()
        prepareBriefing(); startLevel()
        canvas.startCountdown.cancel()
        runMovie.discard()
        var settings = ClassicSettings()
        settings.music = .silent; settings.musicVolume = 0; settings.soundVolume = 0
        settings.ridiculousSpeedEnabled = true
        setAudioSettings(settings, muted: true)
        let now = ProcessInfo.processInfo.systemUptime
        for _ in 0..<5 { speedControl.step(1, at: now - 1) }
        speedControl.update(at: now, active: true)
        refreshGame()
        guard speedControl.multiplier == 25, canvas.speedLabel == "25×" else {
            throw SequelDataError.invalid("L2 did not apply the 25× preference")
        }
        let output = URL(fileURLWithPath: ".build/ridiculous-speed-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let bitmap = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds)!
        canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("l2-25x.png"))
        settings.ridiculousSpeedEnabled = false
        setAudioSettings(settings, muted: true)
        guard speedControl.multiplier <= 10 else {
            throw SequelDataError.invalid("L2 retained 25× after disabling the preference")
        }
        print("PASS L2 optional 25× preference, canvas label and disable clamp")
    }

    func testPauseKeyboard() throws {
        timer?.invalidate()
        prepareBriefing(); startLevel(); canvas.startCountdown.cancel(); paused = false
        defer { if let window { gameplayKeyboard?.bind(to: window) } }
        try validatePauseKeyboard(gameplayKeyboard!, name: "Lemmings 2", paused: { self.paused })
        try validateCursorPresets(name: "Lemmings 2",
            apply: { self.setAudioSettings($0, muted: true) }, current: { self.canvas.gameplayCursorStyle })
    }
    func testSelectionRendering() async throws {
        let inspectionSelection = canvas.inspectionSelectionAvailable
        defer { canvas.inspectionSelectionAvailable = inspectionSelection }
        canvas.inspectionSelectionAvailable = { false }
        timer?.invalidate(); audioSettings.confinePointer = false
        prepareBriefing(); startLevel(); paused = true; canvas.startCountdown.cancel()
        for _ in 0..<120 { game?.step() }
        refreshGame()
        if let id = game?.lemmings.first(where: { $0.active })?.id { canvas.focusLemming(id) }
        present()
        try await validateSelectionCanvas(canvas, name: "lemmings2", effect: { self.canvas.selectionEffect },
            reduce: { self.canvas.reduceMotion = $0; self.canvas.reduceFlashes = $0 },
            hdEffects: { self.canvas.hdEffectsEnabled = $0 },
            style: { choice in
                var settings = self.audioSettings; settings.lemmingSelectionStyle = choice
                self.setAudioSettings(settings, muted: true)
            }, refocus: { if let id = self.game?.lemmings.first(where: { $0.active })?.id { self.canvas.focusLemming(id) } },
            advance: { self.game?.step(); self.game?.step(); self.refreshGame() })
    }
    func testTimelinePanel() throws {
        prepareBriefing(); startLevel()
        if let keyboard = gameplayKeyboard {
            try validateCameraKeyboard(keyboard, name: "lemmings2")
            if let window { keyboard.bind(to: window) }
        }
        try validateTimelineCanvas(canvas, timeline: canvas.timeline, name: "lemmings2",
            tick: { self.game?.tick ?? -1 }, paused: { self.paused })
    }
    #endif

    func present() { showWindow(nil); window?.makeKeyAndOrderFront(nil); window?.makeFirstResponder(front) }
    func showLearningHints() {
        if game?.isComplete == true { retryLevel() }
        paused = true; accumulator = 0
        showLevelHints()
    }
    func showLevelHints() {
        guard let window, !GameScreen.shared.isPresented, screen == .playing || screen == .briefing else { return }
        let names = game?.configuration.skills.map(\.name) ?? []
        let deck = LevelHintDeck.practice(title: level.title, skills: names)
        let wasPaused = paused
        let interruption = gameplayKeyboard?.interruptionCount
        paused = true; accumulator = 0; releasePointerInput(); saveCheckpoint(immediately: true); refreshGame()
        LevelHintWindow.shared.show(deck, owner: window, onDismiss: { [weak self] in
            guard let self else { return }
            self.paused = wasPaused || self.gameplayKeyboard?.interruptionCount != interruption
            self.accumulator = 0; self.lastTime = ProcessInfo.processInfo.systemUptime; self.refreshGame()
        })
    }
    @objc private func windowLostFocus(_ notification: Notification) {
        guard let resigned = notification.object as? NSWindow, resigned === window else { return }
        releasePointerInput()
    }
    private func interruptGameplay() {
        guard screen == .playing, game?.isComplete == false else { return }
        paused = true; accumulator = 0; lastTime = ProcessInfo.processInfo.systemUptime
        userPausedMusic = false; music.suspendOutput(); dj.suspendOutput()
        canvas.capturePointer(active: false)
        releasePointerInput(); saveCheckpoint(immediately: true); sounds.silence(); refreshGame()
    }
    func windowWillClose(_ notification: Notification) {
        stop()
    }
    @objc private func artworkChanged() {
        do { try canvas.refreshArtwork() }
        catch { message = L10n.text("Artwork could not be loaded: \(error)") }
        if screen == .briefing { prepareBriefing() }
        if screen == .playing { refreshGame() }
        front.needsDisplay = true
    }
    func stop() {
        manualDJHandoff.cancel()
        gameplayKeyboard?.removeNavigationControl()
        saveCheckpoint(immediately: true)
        canvas.capturePointer(active: false)
        NotificationCenter.default.removeObserver(self, name: SequelArtworkPreference.changed, object: nil)
        NotificationCenter.default.removeObserver(self,name:NSWindow.didResignKeyNotification,object:nil)
        timer?.invalidate(); timer = nil; forwardTimer?.invalidate(); forwardTimer = nil
        runMovie.discard(); music.stop(); dj.stop(); sounds.stop(); persist()
    }
    func setMuted(_ muted: Bool) { setAudioSettings(audioSettings, muted: muted) }
    func suspendAudioOutput() { saveCheckpoint(immediately: true); music.suspendOutput(); dj.suspendOutput(); sounds.suspendOutput() }
    func resumeAudioOutput() throws {
        try sounds.resumeOutput()
        if paused && !canvas.startCountdown.isActive && screen == .playing && game?.isComplete == false {
            music.suspendOutput(rhythmOnly: userPausedMusic && audioSettings.pauseMusicBeatOnly)
            dj.suspendOutput(rhythmOnly: userPausedMusic && audioSettings.pauseMusicBeatOnly)
        } else { try music.resumeOutput(); dj.resumeOutput() }
    }
    private func updateUserMusicPause() {
        userPausedMusic = paused
        if paused {
            music.suspendOutput(rhythmOnly: audioSettings.pauseMusicBeatOnly)
            dj.suspendOutput(rhythmOnly: audioSettings.pauseMusicBeatOnly)
        } else {
            try? music.resumeOutput(); dj.resumeOutput()
        }
    }
    func setAudioSettings(_ settings: ClassicSettings, muted: Bool) {
        ArcadeWindow.shared.arcadeView.onReadySound = { [weak self] in self?.playReadySound() }
        let musicChanged = !audioConfigured || audioSettings.music != settings.music
        audioConfigured = true
        audioSettings = settings
        speedControl.variableEnabled = settings.modernControlsEnabled && settings.variableSpeedEnabled
        speedControl.ridiculousEnabled = settings.ridiculousSpeedEnabled
        canvas.reduceMotion = settings.reduceMotion
        canvas.reduceFlashes = settings.reduceFlashes
        canvas.hdEffectsEnabled = settings.hdEffectsEnabled
        canvas.gameplayCursorStyle = settings.gameplayCursorStyle
        canvas.showReticleCount = settings.showReticleCount
        canvas.skillCursorIconSize = settings.skillCursorIconSize
        canvas.lemmingSelectionStyle = settings.lemmingSelectionStyle
        canvas.favorApproachingLemmings = settings.favorApproachingLemmings
        canvas.favorBombBlockers = settings.favorBombBlockers
        canvas.favorBuilders = settings.favorBuilders
        canvas.fullScreenHDRFlashes = settings.cinematicExplosionsEnabled
        if let root = Bundle.main.resourceURL?.appendingPathComponent("Music") {
            dj.load(soundtracks: SoundtrackPlayer.djSoundtracks(at: root), catalogueRoot: root)
        }
        dj.setEnhancements(settings.musicStyle == .modern ? .modern : .faithful)
        dj.setVolume(settings.musicVolume)
        dj.setMuted(muted || settings.music == .silent || UserDefaults.standard.bool(forKey: progressKey + ".musicMuted"))
        globallyMuted = muted
        music.setVolume(settings.musicVolume)
        sounds.setVolume(settings.soundVolume)
        sounds.setBottomFallSounds(settings.bottomFallSounds)
        music.setMuted(muted || settings.music == .silent || UserDefaults.standard.bool(forKey: progressKey + ".musicMuted"))
        if music.usesModernPreset != (settings.musicStyle == .modern) {
            music.setEnhancements(settings.musicStyle == .modern ? .modern : .faithful)
        }
        sounds.setMuted(muted || settings.sound == .silent || UserDefaults.standard.bool(forKey: progressKey + ".soundsMuted"))
        if musicChanged {
            if screen == .playing || screen == .briefing || screen == .results { playTribeMusic() }
            else { playMusic(L10n.text("Maintune")) }
        }
        if userPausedMusic && paused { updateUserMusicPause() }
    }
    static func savedCompletion(root: URL, journeyWins: Set<LevelCatalogueIdentity> = []) -> Int {
        guard var campaign = try? Lemmings2Campaign(root: root) else { return 0 }
        let key = campaignProgressKey(root: root)
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(Lemmings2Campaign.Progress.self, from: data) {
            try? campaign.restore(saved)
        }
        return campaign.levels.indices.filter { index in
            campaign.results[index] != nil || journeyWins.contains(.init(engine: .lemmings2,
                packID: "tribes-\(index / 10)", levelID: "\(index % 10):\(campaign.levels[index].fingerprint)"))
        }.count
    }

    static func browserLevels(root: URL) throws -> [BrowserLevel] {
        try browserLevels(root: root, progressData: browserProgressData(root: root))
    }

    static func browserProgressData(root: URL) -> Data? {
        UserDefaults.standard.data(forKey: campaignProgressKey(root: root))
    }

    nonisolated private static let browserCampaignCache = GameAssetCache<Lemmings2Campaign>(capacity: 4)
    nonisolated private static let browserMetadataCache = GameAssetCache<[BrowserLevel]>(capacity: 4)

    nonisolated static func browserLevels(root: URL, progressData: Data?) throws -> [BrowserLevel] {
        try Task.checkCancellation()
        guard let rootRevision = FanLevelLibrary.directoryFingerprint(root) else {
            throw SequelDataError.invalid(L10n.text("The Lemmings 2 game data could not be verified."))
        }
        let cacheKey = root.standardizedFileURL.path + ":" + rootRevision
        var campaign: Lemmings2Campaign
        if let cached = browserCampaignCache.value(for: cacheKey) { campaign = cached }
        else {
            campaign = try Lemmings2Campaign(root: root)
            browserCampaignCache.insert(campaign, for: cacheKey)
        }
        if let progressData,
           let saved = try? JSONDecoder().decode(
            Lemmings2Campaign.Progress.self, from: progressData) {
            try? campaign.restore(saved)
        }

        if let cached = browserMetadataCache.value(for: cacheKey) {
            return cached.map { level in
                BrowserLevel(selection: level.selection, levelID: level.levelID,
                    sourceRevision: level.sourceRevision, title: level.title,
                    isAvailable: level.selection.level <= campaign.unlockedLevel(in: level.selection.tribe))
            }
        }
        let result = try campaign.levels.enumerated().map { index, level in
            try Task.checkCancellation()
            let tribe = index / 10
            let position = index % 10
            let selection = LevelSelection(tribe: tribe, level: position)
            let sourceRevision = try LevelPreviewSource.lemmings2(
                root: root, selection: selection, expectedLevelID: level.fingerprint)
                .sourceRevision(rootRevision: rootRevision)
            return BrowserLevel(
                selection: selection,
                levelID: level.fingerprint,
                sourceRevision: sourceRevision,
                title: level.title,
                isAvailable: position <= campaign.unlockedLevel(in: tribe))
        }
        browserMetadataCache.insert(result, for: cacheKey)
        return result
    }

    private static func campaignProgressKey(root: URL) -> String {
        ArcadeStore.shared.progressKey("nativeL2Campaign.v1." + playlistProgressID(root: root))
    }
    static func playlistProgressID(root: URL) -> String {
        let bundled = (try? BundledGameResources.lemmings2())?.standardizedFileURL == root.standardizedFileURL
        return bundled ? "bundled" : root.standardizedFileURL.path
    }
    static func playlistProgress(root: URL, startingAt selections: [LevelSelection]) throws -> Data {
        var campaign = try Lemmings2Campaign(root: root)
        if let data = UserDefaults.standard.data(forKey: campaignProgressKey(root: root)) {
            try campaign.restore(JSONDecoder().decode(Lemmings2Campaign.Progress.self, from: data))
        }
        // A playlist may explicitly start partway through a tribe. Retain only
        // the predecessors needed to supply that level's starting population.
        var first: [Int: Int] = [:]
        for selection in selections where first[selection.tribe] == nil { first[selection.tribe] = selection.level }
        let initial = try Lemmings2Campaign(root: root).progress
        let fresh = Lemmings2Campaign.Progress(tribe: initial.tribe, level: initial.level,
            results: campaign.results.filter { $0.key % 10 < (first[$0.key / 10] ?? 0) },
            skipped: campaign.skipped.filter { $0.key % 10 < (first[$0.key / 10] ?? 0) })
        try campaign.restore(fresh)
        return try JSONEncoder().encode(campaign.progress)
    }
    private func refreshPlayerControls() {
        let owner = ArcadeStore.shared.playingProfileID
        guard settingsProfileID != owner else { return }
        settingsProfileID = owner
        let baseline = UserDefaults.standard.data(forKey: "ClassicSettings").flatMap { try? JSONDecoder().decode(ClassicSettings.self, from: $0) } ?? ClassicSettings()
        let updated = PlayerControlSettings.load(from: .standard, profileID: owner, legacy: baseline).applying(to: audioSettings)
        GameAccessibility.interfaceSize = updated.interfaceSize
        if audioConfigured { setAudioSettings(updated, muted: globallyMuted) }
        else { audioSettings = updated }
    }

    private func shuffleMusic() {
        guard screen == .playing, !paused, game?.isComplete == false, !userPausedMusic, !globallyMuted,
              !music.muted, audioSettings.music != .silent, audioSettings.musicVolume > 0,
              NSApp.isActive, !GameScreen.shared.isPresented else { return }
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("Music") else { return }
        var pools = SoundtrackPlayer.djSoundtracks(at: root, seasonal: false)
        for (name, urls) in SoundtrackPlayer.djSoundtracks(at: root, seasonal: true) { pools[name, default: []].append(contentsOf: urls) }
        dj.load(soundtracks: pools, catalogueRoot: root)
        if dj.isPlaying { _ = dj.shuffle(scope: audioSettings.djShuffleScope); return }
        guard let source = music.currentURL else { return }
        dj.setVolume(0)
        guard dj.shuffle(from: source, scope: audioSettings.djShuffleScope, identity: arcadeRunID.uuidString,
            fallbackTrackID: "lemmings2." + source.deletingPathExtension().lastPathComponent.lowercased()) else {
            dj.setVolume(audioSettings.musicVolume); return
        }
        manualDJHandoff.start(volume: { [weak self] in self?.audioSettings.musicVolume ?? 0 },
            suspended: { [weak self] in self?.paused != false || !NSApp.isActive },
            legacyGain: { [weak self] in self?.music.setVolume($0) },
            incomingGain: { [weak self] in self?.dj.setVolume($0) },
            stopLegacy: { [weak self] in self?.music.stop() })
    }

    private func playMusic(_ name: String) {
        manualDJHandoff.cancel()
        music.setVolume(audioSettings.musicVolume)
        dj.setVolume(audioSettings.musicVolume)
        guard audioConfigured else { return }
        if audioSettings.music == .adaptiveDJ,
           let url = music.library.first(where: { $0.deletingPathExtension().lastPathComponent.lowercased() == name.lowercased() }) {
            let musicRoot = root.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Music")
            dj.load(soundtracks: SoundtrackPlayer.djSoundtracks(at: musicRoot), catalogueRoot: musicRoot)
            music.stop()
            dj.startJourney(trackID: "lemmings2." + name.lowercased(), cycle: campaign.level,
                identity: arcadeRunID.uuidString + ":" + name.lowercased(), fallback: url,
                includeAlternates: audioSettings.djIncludesOtherSoundtracks)
            return
        }
        dj.stop()
        try? music.start()
        if let index = music.library.firstIndex(where: { $0.deletingPathExtension().lastPathComponent.lowercased() == name.lowercased() }) {
            _ = music.play(index: index)
        }
    }
    private func persist() {
        guard recordsCampaignProgress else { return }
        if let data = try? JSONEncoder().encode(campaign.progress) { UserDefaults.standard.set(data, forKey: progressKey) }
        ArcadeStore.shared.notifyProgressChanged()
    }
    private func show(_ screen: Screen) {
        if onSequenceContinue != nil {
            switch screen {
            case .map, .practice, .load, .save:
                explain(
                    L10n.text("Return to the library before choosing another level or saved game."),
                    returnTo: self.screen)
                return
            default: break
            }
        }
        saveCheckpoint(immediately: true)
        if self.screen == .intro && screen != .intro { introduction = nil; try? music.resumeOutput() }
        if screen == .talisman {
            do { award = try Lemmings2Award(root:root,assets:assets,campaign:campaign,
                                          newPiece:self.screen == .results && game?.didWin == true) }
            catch { message = L10n.text("Could not show the talisman: \(error)"); previousScreen = .map; show(.message); return }
        }
        if screen == .practice { practiceLevel = nil; game = nil; initial = nil }
        nukeGesture.reset()
        if screen != .playing {
            if screen != .results { nukeMood.reset() }
            sounds.setNukeActive(false)
            if screen == .results { sounds.silencePreservingRescues() }
            else { sounds.silence() }
            releasePointerInput()
        }
        self.screen = screen; frontTicks = 0
        let incoming = screen == .briefing && ArcadeStore.shared.hotSeatIsActive
            ? ArcadeStore.shared.records.profile(ArcadeStore.shared.playingProfileID) : nil
        front.turnBadge.show(initials: incoming?.initials,
            portrait: incoming.flatMap { ArcadeWindow.shared.arcadeView.portraitImage($0.portrait) })
        front.needsLayout = true
        accumulator = 0; lastTime = ProcessInfo.processInfo.systemUptime
        let view: NSView = screen == .playing ? canvas : front
        window?.contentView = view; window?.makeFirstResponder(view)
        front.needsDisplay = true
        if screen == .menu { playMusic(L10n.text("Maintune")) }
    }
    private func explain(_ text: String, returnTo: Screen) {
        message = text; previousScreen = returnTo; show(.message)
    }
    private func prepareBriefing() {
        do {
            let decoded = try Lemmings2Style(data: Data(contentsOf:
                root.appendingPathComponent("STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))
            style = decoded
            let terrain = try Lemmings2Terrain(level: level, style: decoded)
            let left = max(0, level.minimumScreenX), top = max(0, level.minimumScreenY)
            let width = min(terrain.image.width - left, level.maximumScreenX + 320 - left)
            let height = min(terrain.image.height - top, level.maximumScreenY + 160 - top)
            guard width > 0, height > 0 else { throw SequelDataError.invalid(L10n.text("Invalid level camera bounds.")) }
            var pixels: [UInt8] = []
            pixels.reserveCapacity(width * height)
            for y in 0..<height {
                let start = (top + y) * terrain.image.width + left
                pixels.append(contentsOf: terrain.image.pixels[start..<(start + width)])
            }
            preview = front.makeImage(pixels, width: width, height: height, palette: decoded.palette, category: .lemmings2Terrain(tribe: level.style), frontEnd: false)
            show(.briefing)
        } catch { explain(String(describing: error), returnTo: .menu) }
    }
    private func startLevel() {
        saveCheckpoint(immediately: true)
        guard let style else { return }
        do {
            let replacement = try practiceLevel != nil
                ? Lemmings2Practice.runtime(level:level,style:style,masks:masks,skills:practiceSkills)
                : Lemmings2Runtime(level:level,style:style,masks:masks,total:campaign.population)
            try canvas.load(level: level, style: style, sprites: sprites, intern: intern, explosion: explosion, walker: walker)
            game = replacement; initial = replacement
            dj.resetLevel()
            countdownWarning.reset(seconds: replacement.remainingSeconds)
            beforeNuke = nil
            selected = 0; canvas.startCountdown.arm(); paused = true; speedControl.newLevel(); fanSelected = false; nukeGesture.reset()
            sounds.silence()
            show(.playing)
            beginReplay()
            userPausedMusic = false
            playTribeMusic()
            try? music.resumeOutput(); dj.resumeOutput()
            refreshGame()
        } catch { explain(String(describing: error), returnTo: .briefing) }
    }
    /// A retry brakes the music like a record stopped by hand, then restarts.
    private func retryLevel() {
        music.vinylStop()
        dj.vinylStop()
        restart()
        music.vinylRelease()
        dj.vinylRelease()
    }
    private func restart() {
        saveCheckpoint(immediately: true, waitForDisk: false)
        guard let initial else { return }
        game = initial; beginReplay(); dj.resetLevel(); canvas.resetCamera(level: level)
        countdownWarning.reset(seconds: initial.remainingSeconds)
        beforeNuke = nil
        canvas.startCountdown.arm(); paused = true; speedControl.newLevel(); accumulator = 0; nukeGesture.reset(); sounds.silence()
        show(.playing)
        userPausedMusic = false
        playTribeMusic()
        try? music.resumeOutput(); dj.resumeOutput()
        refreshGame()
    }
    private func recordCollectionVisit() {
        if practiceLevel == nil {
            let selection = LevelSelection(tribe: campaign.tribe, level: campaign.level)
            let source = LevelPreviewSource.lemmings2(root: root, selection: selection, expectedLevelID: level.fingerprint)
            if let revision = try? source.sourceRevision(),
               let entry = try? LevelPlaylistEntry(identity: .init(engine: .lemmings2,
                 packID: "tribes-\(campaign.tribe)", levelID: "\(campaign.level):\(level.fingerprint)"),
                 catalogueRevision: LevelCollections.catalogueRevision, sourceRevision: revision,
                 packNameSnapshot: L10n.text("The Tribes - \(Lemmings2Campaign.tribeNames[campaign.tribe])"),
                 levelNameSnapshot: level.title, levelNumberSnapshot: campaign.level + 1) {
                LevelCollections.record(entry, profileID: arcadeProfileID, attemptID: arcadeRunID)
            }
        }
    }
    private func beginReplay() {
        if restoringRun { return }
        discardRewindOrigin()
        lastFanInput = nil; lastAimInput = nil
        recoveryInputs = []; recoveryProgress = campaign.progress
        recoveryPractice = practiceLevel == nil ? nil
            : L2RunRecovery.Practice(choice: practiceChoice, skills: practiceSkills.map(\.rawValue))
        recoveryInitialHash = initial.flatMap { try? L2RunRecovery.stateHash($0, includeConfiguration: true) } ?? ""
        lastCheckpointTime = 0
        assignmentFocus = AssignmentFocus(); canvas.assignmentHighlight.clear()
        let previousAttemptID = arcadeRunID
        arcadeRunID = UUID(); arcadeProfileID = ArcadeStore.shared.playingProfileID; arcadeHotSeatID = ArcadeStore.shared.hotSeatID
        arcadeLevelSnapshot = nil
        refreshPlayerControls()
        PrecisionZoomController.shared.start(attemptID: arcadeRunID, profileID: arcadeProfileID)
        syncPrecisionZoom()
        arcadeReport = nil; usedRewind = false; nukeCount = 0; undoCount = 0
        arcadeLevelSnapshot = arcadeLevel
        recordCollectionVisit()
        if let arcadeLevel { AnonymousTelemetry.shared.start(arcadeLevel, hotSeat: arcadeHotSeatID != nil, attemptID: arcadeRunID) }
        if recordsCampaignProgress, let arcadeLevel { ArcadeStore.shared.beginAttempt(id: arcadeRunID, profileID: arcadeProfileID,
            level: arcadeLevel, previousID: previousAttemptID) }
        runMovie.begin(ticksPerSecond: Lemmings2Runtime.ticksPerSecond, title: L10n.text("Lemmings 2 - \(level.title)"))
        runMovie.onWillReview = { [weak self] in self?.suspendAudioOutput() }
        runMovie.onDidReview = { [weak self] in try? self?.resumeAudioOutput() }
        if let recorder = runMovie.recorder {
            sounds.onPlay = { [weak recorder] samples, rate, gain in recorder?.sound(samples: samples, rate: rate, gain: gain) }
        }
        // Record at the doubled artwork scale, keeping fast-forward responsive.
        let scale = min(480 / max(1, canvas.bounds.height), 1280 / max(1, canvas.bounds.width))
        replaySize = CGSize(width: max(2, floor(canvas.bounds.width * scale / 2) * 2),
                            height: max(2, floor(canvas.bounds.height * scale / 2) * 2))
    }
    private func togglePrecisionZoom(_ kind: PrecisionZoomKind) {
        guard screen == .playing, game?.isComplete == false else { return }
        gameplayKeyboard?.revealRewards()
        let wallet = PrecisionZoomController.shared
        guard wallet.toggle(kind) else {
            if kind == .superzoom {
                message = wallet.storageError ?? L10n.text("No Superzoom uses. Earn one for every 3 no-Rewind three-star levels.")
                canvas.showFocusNotice(message)
            }
            return
        }
        syncPrecisionZoom()
        refreshGame()
    }

    private func scrollPrecisionZoom(_ action: PrecisionZoomScrollAction, at point: CGPoint) {
        guard screen == .playing, game?.isComplete == false else { return }
        let wallet = PrecisionZoomController.shared
        switch wallet.applyScroll(action) {
        case .changed:
            gameplayKeyboard?.revealRewards()
            syncPrecisionZoom(at: point)
            refreshGame()
        case .unavailable: break
        case .unchanged: break
        }
    }

    private func syncPrecisionZoom(at point: CGPoint? = nil) {
        let wallet = PrecisionZoomController.shared
        canvas.setPrecisionZoom(wallet.active != nil, magnification: CGFloat(wallet.magnification), at: point)
        speedControl.bulletTimeActive = wallet.active == .superzoom
        canvas.precisionStatus = PrecisionZoomStatus(superzoom: wallet.remainingSuperzoom(),
            skips: ArcadeStore.shared.records.levelSkips(profileID: arcadeProfileID).available,
            extraSkills: ArcadeStore.shared.records.extraSkills(profileID: arcadeProfileID).available,
            bonusSkillUsed: ArcadeStore.shared.records.extraSkillSpent(attemptID: arcadeRunID, profileID: arcadeProfileID) != nil,
            active: wallet.active, isEmpty: false)
    }

    private var extraSkillAvailable: Bool {
        guard screen == .playing, let game, !game.isComplete, canvas.precisionStatus.extraSkills > 0,
              ArcadeStore.shared.records.extraSkillSpent(attemptID: arcadeRunID, profileID: arcadeProfileID) == nil else { return false }
        return game.configuration.skills.indices.contains { game.canGrantBonusSkill(slot: $0) }
    }
    private func useExtraSkill() {
        guard extraSkillAvailable, let game else { return }
        let attemptID = arcadeRunID
        let choices = game.configuration.skills.indices.filter { game.canGrantBonusSkill(slot: $0) }.map {
            ExtraSkillMac.Choice(id: $0, title: SkillVocabulary.title(game.configuration.skills[$0].name))
        }
        let resume = gameplayKeyboard?.pauseForHelp() ?? {}
        ExtraSkillMac.choose(choices, selected: selected, owner: window, onDismiss: resume) { [weak self] slot in
            guard let self, self.arcadeRunID == attemptID, self.extraSkillAvailable,
                  self.game?.canGrantBonusSkill(slot: slot) == true,
                  let conditions = self.arcadeLevel?.conditions else { return }
            let skill = TrolleyCapture.skillKey(game.configuration.skills[slot].name)
            guard ArcadeStore.shared.spendExtraSkill(attemptID: attemptID, profileID: self.arcadeProfileID,
                skill: skill, conditions: conditions) else {
                self.canvas.showFocusNotice(ArcadeStore.shared.storageError ?? L10n.text("Bonus skill unavailable")); return
            }
            guard self.performRecoveryInput(.bonusSkill(slot: slot)) else { return }
            self.selected = slot; self.fanSelected = false
            self.syncPrecisionZoom(); self.gameplayKeyboard?.revealRewards()
            self.canvas.showFocusNotice("+1 " + SkillVocabulary.title(game.configuration.skills[slot].name))
            self.refreshGame(); self.saveCheckpoint(immediately: true)
        }
    }

    private func captureReplayFrame() {
        runMovie.recorder?.setMusic(url: dj.isPlaying ? dj.currentURL : music.currentURL,
            gain: globallyMuted || audioSettings.music == .silent || music.muted ? 0 : Float(audioSettings.musicVolume))
        runMovie.capture(ReplayFrameCapture.image(size: replaySize) {
            ReplayFrameCapture.draw(canvas, in: CGRect(origin: .zero, size: replaySize))
        })
    }
    func suspendForReplay() -> () -> Void {
        let interruption = gameplayKeyboard?.interruptionCount
        let wasPaused = paused
        paused = true; releasePointerInput(); suspendAudioOutput(); refreshGame()
        return { [weak self] in
            guard let self else { return }
            self.paused = wasPaused || self.gameplayKeyboard?.interruptionCount != interruption
            try? self.resumeAudioOutput(); self.lastTime = ProcessInfo.processInfo.systemUptime; self.refreshGame()
        }
    }
    func reviewReplay() { if game?.isComplete == true { runMovie.review() } }
    private func playTribeMusic() {
        let names = ["classic", "beach", "cavelem", "circus", "egyptian", "highland",
                     "medieval", "outdoor", "polar", "shadow", "space", "sports"]
        playMusic(names[level.style])
    }
    private func playFromMenu() {
        if let game, !game.isComplete,
           (practiceLevel != nil && game.configuration.isPractice) || game.configuration.levelFingerprint == level.fingerprint {
            paused = false; updateUserMusicPause(); show(.playing); playTribeMusic(); refreshGame()
        } else { prepareBriefing() }
    }
    private func undoNuke() {
        guard let beforeNuke else { return }
        usedRewind = true; undoCount += 1
        lastFanInput = nil; lastAimInput = nil
        recoveryInputs = Array(recoveryInputs.prefix(beforeNukeInputCount))
        game = beforeNuke; assignmentFocus.rewind(to: beforeNuke.tick); canvas.assignmentHighlight.clear(); self.beforeNuke = nil; sounds.silence(); accumulator = 0
    }
    private func activateNuke() {
        beforeNukeInputCount = recoveryInputs.count
        beforeNuke = game; nukeCount += 1
        canvas.startCountdown.cancel()
        performRecoveryInput(.nuke); paused = false; updateUserMusicPause(); fanSelected = false; accumulator = 0
    }
    /// N is a deliberate key press, so it needs no double-click like the panel button.
    private func toggleNukeFromKeyboard() {
        guard screen == .playing, let game, !game.isComplete, beforeNuke != nil || !game.isNuking else { return }
        nukeGesture.reset()
        if beforeNuke != nil { undoNuke() } else { activateNuke() }
        if paused { releasePointerInput(); saveCheckpoint(immediately: true) }
        else if !fanSelected { performRecoveryInput(.fan(x:0,y:0,active:false)) }
        refreshGame()
    }
    private func panelAction(_ slot: Int, clickCount: Int = 1, time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard (0..<12).contains(slot), screen == .playing, game?.isComplete == false else { return }
        if let click = Lemmings2SoundRequest.panel(slot: slot) { sounds.play([click]) }
        let nukeAction: NukeClickGesture.Action
        if slot == Lemmings2Control.nuke.rawValue {
            nukeAction = nukeGesture.click(canUndo: beforeNuke != nil, time: time, interval: NSEvent.doubleClickInterval)
        } else { nukeGesture.reset(); nukeAction = .none }
        if slot < 8 {
            selected = slot; fanSelected = false
        } else {
            switch Lemmings2Control(rawValue: slot) {
            case .pause:
                if canvas.startCountdown.isActive {
                    canvas.startCountdown.cancel(); paused = true; accumulator = 0; updateUserMusicPause(); refreshGame(); return
                }
                let wasPaused = paused; paused.toggle(); accumulator = 0
                updateUserMusicPause()
                if wasPaused { discardRewindOrigin() }
            case .fan: fanSelected.toggle()
            case .nuke:
                if nukeAction == .undo { undoNuke() } else if nukeAction == .activate { activateNuke() }
            case .fastForward: speedControl.tap(at: time, clickCount: clickCount)
            case nil: break
            }
        }
        if paused { releasePointerInput(); saveCheckpoint(immediately: true) }
        else if !fanSelected { performRecoveryInput(.fan(x:0,y:0,active:false)) }
        refreshGame()
    }
    @discardableResult private func performRecoveryInput(_ action: L2RunRecovery.Input.Action) -> Bool {
        guard var current = game else { return false }
        if rewindOriginState != nil { discardRewindOrigin() }
        switch action {
        case .fan: if action == lastFanInput { return true }
        case .aim: if action == lastAimInput { return true }
        case .releasePointer: if recoveryInputs.last?.action == .releasePointer { return true }
        default: break
        }
        let input = L2RunRecovery.Input(tick: current.tick, action: action)
        do { try L2RunRecovery.apply(input, to: &current) } catch { return false }
        game = current
        switch action {
        case .fan: lastFanInput = action
        case .aim: lastAimInput = action
        case .releasePointer, .nuke: lastFanInput = nil; lastAimInput = nil
        default: break
        }
        recoveryInputs.append(input)
        return true
    }
    private func releasePointerInput() { performRecoveryInput(.releasePointer) }

    private func makeCheckpoint(engine: String) throws -> RunRecovery? {
        guard !restoringRun, !engine.isEmpty, let game, game.tick >= 0, !game.isComplete,
            let progress = recoveryProgress, !recoveryInitialHash.isEmpty,
            let fingerprint = arcadeLevelSnapshot?.conditions?.levelFingerprint else { return nil }
        var checkpoint = RunRecovery(engine: engine, profileID: arcadeProfileID, runID: arcadeRunID,
            dataSetID: "lemmings2", levelIndex: recoveryPractice?.choice ?? progress.level,
            levelFingerprint: fingerprint, initialStateHash: recoveryInitialHash, tick: game.tick,
            events: [], stateHash: "", usedRewind: usedRewind,
            nukeCount: nukeCount, rewindCount: 0, undoCount: undoCount, selectedSkill: selected,
            scrollX: Double(canvas.cameraX), scrollY: Double(canvas.cameraY))
        checkpoint.sourcePath = root.path
        checkpoint.l2 = L2RunRecovery(progress: progress, inputs: recoveryInputs, practice: recoveryPractice)
        checkpoint.hotSeatID = arcadeHotSeatID
        checkpoint.extraSkillUse = ArcadeStore.shared.records.extraSkillUse(attemptID: arcadeRunID, profileID: arcadeProfileID)
        checkpoint.sequence = sequenceRecovery
        return checkpoint
    }
    func saveCheckpoint(immediately: Bool = false, waitForDisk: Bool = true) {
        guard recordsCampaignProgress || sequenceRecovery != nil else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard immediately || now - lastCheckpointTime >= 5 else { return }
        do {
            guard let game, let checkpoint = try makeCheckpoint(engine: RunRecovery.bundledEngine) else { return }
            lastCheckpointTime = now
            recoveryStore.save(checkpoint, immediately: immediately && waitForDisk, coalescing: !immediately,
                prepareStateHash: { try L2RunRecovery.stateHash(game) }) { [weak self] error in self?.message = error }
        } catch { message = error.localizedDescription }
    }

    func saveBeforeSessionChange() throws {
        guard recordsCampaignProgress || sequenceRecovery != nil else { return }
        if let game, let checkpoint = try makeCheckpoint(engine: RunRecovery.bundledEngine) {
            recoveryStore.save(checkpoint, immediately: true,
                prepareStateHash: { try L2RunRecovery.stateHash(game) }) { [weak self] error in self?.message = error }
        }
        try recoveryStore.checkSaveSucceeded()
    }

    private func assign(_ x: Int, _ y: Int) {
        nukeGesture.reset()
        if !fanSelected, performRecoveryInput(.machine(x:x,y:y)) { sounds.play(game?.drainSoundEvents() ?? []); refreshGame(); return }
        if !fanSelected, performRecoveryInput(.chain(x:x,y:y)) { sounds.play(game?.drainSoundEvents() ?? []); refreshGame(); return }
        if !fanSelected, let lem = game?.target(slot: selected, x: x, y: y, preferApproaching: audioSettings.favorApproachingLemmings,
            preferBombBlockers: audioSettings.favorBombBlockers, preferBuilders: audioSettings.favorBuilders) {
            if performRecoveryInput(.assign(slot: selected, lemming: lem.id)) {
                assignmentFocus.record(id: lem.id, skill: selected, tick: game?.tick ?? 0)
                canvas.didAssign(to: lem.id)
            } else {
                playAssignmentRejection(lem.id)
            }
        }
        sounds.play(game?.drainSoundEvents() ?? [])
        refreshGame()
    }
    private func playAssignmentRejection(_ id: Int) {
        guard let lem = game?.lemmings.first(where: { $0.id == id && $0.active }) else { return }
        sounds.play([Lemmings2SoundRequest(supplemental: .actionRejected).positioned(x: lem.x, y: lem.y)])
    }
    func playReadySound() { sounds.playInterface(.ready) }
    private var ghostAttemptID: UUID?
    private func refreshHotSeatGhosts() {
        guard ghostAttemptID != arcadeRunID, let initial else { return }
        ghostAttemptID = arcadeRunID
        canvas.hotSeatGhosts = ArcadeStore.shared.hotSeatGhosts(initial: .lemmings2(initial),
            level: arcadeLevel, playerID: arcadeProfileID, sessionID: arcadeHotSeatID)
    }
    private func refreshGame(at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        refreshHotSeatGhosts()
        let nuking = (screen == .playing || screen == .results) && game?.isNuking == true && canvas.hdEffectsEnabled
        let allPopped = game.map { game in
            game.isComplete || game.lemmings.filter(\.active).allSatisfy {
                // The pop runs at age 15, then the tick increments age to 16.
                $0.state == .exiting || ($0.state == .exploding && $0.age >= 16)
            }
        } ?? false
        nukeMood.update(active: nuking, tick: game?.tick ?? 0, durationTicks: 75,
            remainingTicks: game?.lemmings.compactMap(\.bombTicks).min(), allPopped: allPopped, now: now)
        sounds.setNukeActive(nuking && game?.isComplete == false)
        guard let game else { return }
        let impossible = (screen == .playing || screen == .results) && (game.isComplete ? !game.didWin : FailureMoodDecision.isUnrecoverable(
            saved: game.saved, active: game.lemmings.filter(\.active).count,
            unreleased: game.configuration.total - game.released, required: 1))
        completionGlow.set(active: (screen == .playing || screen == .results) &&
            RescueCelebration.isSecured(saved: game.saved, required: 1, isComplete: game.isComplete, didWin: game.didWin),
            brief: RescueCelebration.requiresAll(required: 1, total: game.configuration.total),
            now: now)
        failureMood.set(active: impossible, now: now)
        failureMusic.update(failed: impossible,
            isNuking: (screen == .playing || screen == .results) && game.isNuking,
            allPopped: allPopped, remainingTicks: game.lemmings.filter(\.active).compactMap(\.bombTicks).min(),
            oneCountTicks: 15, tick: game.tick, now: now)
        let turn = ArcadeStore.shared.hotSeatIsActive ? ArcadeStore.shared.records.profile(arcadeProfileID) : nil
        canvas.turnBadge.show(initials: turn?.initials, portrait: turn.flatMap { ArcadeWindow.shared.arcadeView.portraitImage($0.portrait) })
        canvas.speedMultiplier = speedControl.multiplier
        canvas.speedChoiceLabel = speedControl.choiceLabel
        canvas.speedLabel = speedControl.panelLabel
        canvas.variableSpeedEnabled = speedControl.variableEnabled
        canvas.isFastForward = fastForward && !paused && screen == .playing && !game.isComplete
        let deathCounter = FailureMoodDecision.deathCounter(
            saved: game.saved, active: game.lemmings.filter(\.active).count,
            unreleased: game.configuration.total - game.released, required: 1, total: game.configuration.total,
            isComplete: game.isComplete, didWin: game.didWin)
        canvas.deathCountdownText = screen == .playing ? deathCounter.visible : ""
        canvas.update(game)
        let palette = Lemmings2Panel.palette(over: game.configuration.palette, phase: frontTicks / 4)
        let skillFrame: Lemmings2SpriteFrame? = {
            let identifier = game.configuration.skills[selected].rawValue
            guard identifier > 0, assets.panel.skills.indices.contains(identifier - 1) else { return nil }
            return assets.panel.skills[identifier - 1]
        }()
        let hover = canvas.updateSelection(slot: selected, fan: fanSelected, palette: palette, skillFrame: skillFrame)
        var controls: Set<Lemmings2Control> = []
        if paused { controls.insert(.pause) }
        if fastForward { controls.insert(.fastForward) }
        if fanSelected { controls.insert(.fan) }
        let armed = nukeGesture.armedAt.map { ProcessInfo.processInfo.systemUptime - $0 <= NSEvent.doubleClickInterval } ?? false
        if armed || game.isNuking { controls.insert(.nuke) }
        let label = game.isNuking || armed ? L10n.text("NUKE") : fanSelected ? L10n.text("FAN") : hover ?? (fastForward ? L10n.text("SPEED \(speedControl.label.replacingOccurrences(of: "×", with: "X"))") : SkillVocabulary.title(game.configuration.skills[selected].name))
        canvas.rewindOriginTick = rewindOriginState?.tick
        canvas.rewindCurrentTick = game.tick
        if let rendered = try? assets.panel.render(skills: game.configuration.skills.map(\.rawValue), supplies: game.supplies,
            selected: selected, saved: game.saved, remaining: game.lemmings.filter(\.active).count,
            seconds: game.remainingSeconds, label: label, palette: palette, highlightedControls: controls) {
            canvas.setPanel(rendered)
        }
        canvas.toolTip = nil
        let transport = rewindOriginState.map { L10n.text("Rewind active, \($0.tick - game.tick) ticks back. Hold full stop scrubs forward. Escape cancels.") } ?? ""
        let deathCounterAccessibility = screen == .playing ? deathCounter.accessibility : ""
        canvas.setAccessibilityLabel(L10n.text("Lemmings 2. \(SkillVocabulary.title(game.configuration.skills[selected].name)) selected. \(label). \(paused ? L10n.text("Paused.") : L10n.text("Running.")) \(game.isNuking ? L10n.text("Nuke active.") : "") \(game.released) released, \(game.saved) saved. \(deathCounterAccessibility). \(canvas.precisionStatus.accessibility). \(transport)"))
    }
    private func update() {
        let frameStarted = ProcessInfo.processInfo.systemUptime
        defer {
            if screen == .playing, !paused, game?.isComplete == false, !GameScreen.shared.isPresented {
                MacFXPerformance.shared.recordCPU(ProcessInfo.processInfo.systemUptime - frameStarted)
            }
        }
        gameplayKeyboard?.refreshNavigationControl()
        canvas.navigationFrame = gameplayKeyboard?.navigationFrame(in: canvas)
        let now = ProcessInfo.processInfo.systemUptime
        completionGlow.advance(at: now)
        nukeMood.advanceReturn(at: now)
        let elapsed = min(0.25, now - lastTime); lastTime = now
        let playing = screen == .playing && !paused && game?.isComplete == false && !GameScreen.shared.isPresented
        speedControl.update(at: now, active: screen == .playing && game?.isComplete == false && !GameScreen.shared.isPresented)
        canvas.advanceSelectionFade(at: now)
        let turn = ArcadeStore.shared.hotSeatIsActive ? ArcadeStore.shared.records.profile(arcadeProfileID) : nil
        canvas.turnBadge.show(initials: turn?.initials, portrait: turn.flatMap { ArcadeWindow.shared.arcadeView.portraitImage($0.portrait) })
        canvas.speedMultiplier = speedControl.multiplier
        canvas.speedChoiceLabel = speedControl.choiceLabel
        canvas.speedLabel = speedControl.panelLabel
        canvas.variableSpeedEnabled = speedControl.variableEnabled
        GameScreen.shared.capturePointer(in: window, enabled: audioSettings.confinePointer && !playing)
        canvas.capturePointer(active: playing && audioSettings.confinePointer)
        guard !GameScreen.shared.isPresented else { accumulator = 0; return }
        frontTicks += 1
        if screen == .playing { canvas.advanceEdgeScrolling(elapsed: elapsed) }
        if screen == .intro, var introduction {
            accumulator += elapsed
            do {
                while accumulator >= introduction.animation.frameDuration && !introduction.isComplete {
                    accumulator -= introduction.animation.frameDuration
                    try introduction.step()
                    if !introduction.isComplete { sounds.play(introduction.animation.soundSamples.compactMap { Lemmings2SoundRequest.introduction(sample:$0) }) }
                }
                self.introduction = introduction
                if introduction.isComplete { show(.menu) }
                else { front.needsDisplay = true }
            } catch { explain(L10n.text("Could not play the introduction: \(error)"),returnTo:.menu) }
            return
        }
        if screen == .talisman, var award {
            accumulator += elapsed
            do {
                while accumulator >= award.animation.frameDuration && !award.animation.isComplete {
                    accumulator -= award.animation.frameDuration; try award.step()
                    sounds.play(award.animation.soundSamples.compactMap { Lemmings2SoundRequest.introduction(sample:$0) })
                }
                self.award = award; front.needsDisplay = true
            } catch { explain(L10n.text("Could not animate the talisman: \(error)"),returnTo:.map) }
            return
        }
        if screen == .ending, var ending {
            accumulator += elapsed
            do {
                while accumulator >= ending.frameDuration && !ending.isComplete {
                    accumulator -= ending.frameDuration; try ending.step()
                }
                self.ending = ending
                if ending.isComplete {
                    if campaign.canLaunchArk, let onCampaignCompleted { onCampaignCompleted() }
                    else { show(.map) }
                } else { front.needsDisplay = true }
            } catch { explain(L10n.text("Could not play the ending: \(error)"),returnTo:.map) }
            return
        }
        if screen != .playing {
            if (screen == .map || screen == .results) && frontTicks.isMultiple(of: 4) { front.needsDisplay = true }
            return
        }
        if canvas.startCountdown.isActive {
            if canvas.startCountdown.advance(seconds: elapsed, visible: window?.isKeyWindow == true) { paused = false; playReadySound() }
            accumulator = 0; refreshGame(); return
        }
        guard !paused, var game, !game.isComplete else {
            if frontTicks.isMultiple(of: 4) { refreshGame() }
            return
        }
        let previousTick = game.tick
        // Original fast-forward performs three physics updates per displayed frame.
        accumulator += elapsed * speedControl.multiplier
        let inputDeadline = ProcessInfo.processInfo.systemUptime + 0.012
        while accumulator >= 1 / Lemmings2Runtime.ticksPerSecond && !game.isComplete {
            accumulator -= 1 / Lemmings2Runtime.ticksPerSecond
            countdownWarning.reset(seconds: game.remainingSeconds)
            game.step()
            if countdownWarning.update(seconds: game.remainingSeconds) { sounds.play([.init(supplemental: .timerWarning)]) }
            sounds.play(game.drainSoundEvents())
            canvas.flashExplosions(game)
            self.game = game; refreshGame(); captureReplayFrame()
            dj.updateTelemetry(.init(totalCount: game.configuration.total, savedCount: game.saved, requiredCount: 1, isNuking: game.isNuking))
            if ProcessInfo.processInfo.systemUptime >= inputDeadline { break }
        }
        guard game.tick != previousTick else {
            if frontTicks.isMultiple(of: 4) { refreshGame() }
            return
        }
        sounds.play(game.drainSoundEvents())
        self.game = game; refreshGame(); saveCheckpoint()
        finishIfComplete(game)
    }
    var onSequenceResult: ((Bool) -> Void)?
    private func finishIfComplete(_ game: Lemmings2Runtime) {
        if game.isComplete {
            onSequenceResult?(game.didWin)
            if game.didWin && paused {
                userPausedMusic = false
                try? music.resumeOutput(); dj.resumeOutput()
            }
            if let arcadeLevel {
                AnonymousTelemetry.shared.finish(arcadeLevel, hotSeat: arcadeHotSeatID != nil,
                                                 attemptID: arcadeRunID, won: game.didWin, saved: game.saved)
            }
            PrecisionZoomController.shared.finish(attemptID: arcadeRunID, didWin: game.didWin)
            syncPrecisionZoom()
            dj.updateTelemetry(.init(totalCount: game.configuration.total, savedCount: game.saved, requiredCount: 1, didWin: game.didWin, isComplete: true))
            if recordsCampaignProgress || sequenceRecovery != nil {
                do { try recoveryStore.clear(arcadeRunID) } catch { message = error.localizedDescription }
            }
            runMovie.finish()
            if practiceLevel == nil && recordsCampaignProgress { recordRoute(game) }
            if practiceLevel == nil && recordsCampaignProgress {
                _ = campaign.record(game); persist(); onProgressChanged?()
            }
            show(.results)
            recordArcadeResult(game)
        }
    }
    /// Saves a campaign level that saved at least one lemming as a seed route for the solver.
    /// It runs before the campaign records the result, which can move to the next level.
    private func recordRoute(_ game: Lemmings2Runtime) {
        guard game.saved > 0, let style else { return }
        let level = self.level, masks = self.masks
        let route = Lemmings2RouteRecorder.route(level: level, game: game, inputs: recoveryInputs)
        let tribe = level.style == 2 ? "cavelem" : Lemmings2Campaign.tribeNames[level.style].lowercased()
        let number = campaign.level + 1
        DispatchQueue.global(qos: .utility).async {
            _ = try? Lemmings2RouteRecorder.save(route, tribe: tribe, number: number, level: level, style: style, masks: masks)
        }
    }
    private func singleStep() {
        canvas.startCountdown.cancel()
        guard screen == .playing, var game, !game.isComplete, !GameScreen.shared.isPresented else { return }
        paused = true; accumulator = 0; releasePointerInput(); updateUserMusicPause()
        // Release held fan/aim input before taking the single physics step.
        game = self.game!
        countdownWarning.reset(seconds: game.remainingSeconds)
        game.step()
        if countdownWarning.update(seconds: game.remainingSeconds) { sounds.play([.init(supplemental: .timerWarning)]) }
        sounds.play(game.drainSoundEvents()); canvas.flashExplosions(game)
        self.game = game; refreshGame(); captureReplayFrame(); saveCheckpoint(immediately: true)
        finishIfComplete(game)
    }
    private func beginContinuousRewind(advanceImmediately: Bool = true) -> Bool {
        guard screen == .playing, game?.tick ?? 0 > 0, !rewindHeld else { return false }
        captureRewindOrigin()
        rewindHeld = true
        rewindTimer?.invalidate()
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
    }
    private var canStepForward: Bool {
        guard screen == .playing, let game, let origin = rewindOriginState else { return false }
        return game.tick < origin.tick && !rewindHeld
    }
    private func beginContinuousStepForward(advanceImmediately: Bool = true) -> Bool {
        guard canStepForward, !forwardHeld else { return false }
        forwardHeld = true
        forwardTimer?.invalidate()
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
    }

    private func makeTimelineTransport(for window: NSWindow) -> TimelineKeyTransport {
        TimelineKeyTransport(window: window,
            canStartBackward: { [weak self] in
                guard let self else { return false }
                return self.screen == .playing && (self.game?.tick ?? 0) > 0
            },
            stepBackward: { [weak self] in self?.rewind(seconds: 1.0 / Lemmings2Runtime.ticksPerSecond) ?? false },
            beginBackward: { [weak self] in self?.beginContinuousRewind(advanceImmediately: false) ?? false },
            endBackward: { [weak self] in self?.endContinuousRewind() },
            canStartForward: { [weak self] in self?.canStepForward ?? false },
            stepForward: { [weak self] in self?.stepForward(seconds: 1.0 / Lemmings2Runtime.ticksPerSecond) ?? false },
            beginForward: { [weak self] in self?.beginContinuousStepForward(advanceImmediately: false) ?? false },
            endForward: { [weak self] in self?.endContinuousStepForward() })
    }
    private func discardRewindOrigin() {
        endContinuousStepForward()
        rewindOriginState = nil
        rewindOriginInputs = []
    }
    private func playRewindMusic() {
      music.playRewind(); dj.playRewind()
    }

    private func captureRewindOrigin() {
        guard rewindOriginState == nil, let game else { return }
        rewindOriginState = game
        rewindOriginInputs = recoveryInputs
        rewindOriginNukeCount = nukeCount
        rewindOriginBeforeNuke = beforeNuke
        rewindOriginBeforeNukeInputCount = beforeNukeInputCount
    }
    private func cancelRewindToOrigin() -> Bool {
        guard let origin = rewindOriginState, game?.tick != origin.tick else { return false }
        endContinuousRewind()
        game = origin; recoveryInputs = rewindOriginInputs
        nukeCount = rewindOriginNukeCount; beforeNuke = rewindOriginBeforeNuke
        beforeNukeInputCount = rewindOriginBeforeNukeInputCount
        rewindOriginState = nil; rewindOriginInputs = []
        assignmentFocus.rewind(to: origin.tick); canvas.assignmentHighlight.clear(); sounds.silence()
        paused = true; accumulator = 0; updateUserMusicPause(); refreshGame(); saveCheckpoint(immediately: true)
        return true
    }
    @discardableResult
    private func rewind(seconds: Double) -> Bool {
        guard screen == .playing, let initial, let current = game, current.tick > 0 else { return false }
        captureRewindOrigin()
        let target = max(0, current.tick - Int((seconds * Lemmings2Runtime.ticksPerSecond).rounded()))
        guard target < current.tick else { return false }
        let prefix = recoveryInputs.prefix { $0.tick <= target }
        canvas.prepareRewindEffects()
        do { game = try L2RunRecovery.replay(initial: initial, inputs: Array(prefix), through: target) }
        catch {
            message = L10n.text("Could not rewind this run: \(error)")

            return false
        }
        canvas.finishRewindEffects(game!)
        recoveryInputs = Array(prefix)
        lastFanInput = nil; lastAimInput = nil; beforeNuke = nil
        nukeCount = recoveryInputs.reduce(into: 0) { count, input in
            if case .nuke = input.action { count += 1 }
        }
        usedRewind = true; paused = true; accumulator = 0; updateUserMusicPause()
        assignmentFocus.rewind(to: target); canvas.assignmentHighlight.clear(); sounds.silence(); sounds.playRewindScrub(); playRewindMusic()
        refreshGame(); saveCheckpoint(immediately: true)

        return true
    }
    @discardableResult
    private func stepForward(seconds: Double) -> Bool {
        guard let initial, let current = game, let origin = rewindOriginState,
              current.tick < origin.tick else { return false }
        let target = min(origin.tick, current.tick + Int((seconds * Lemmings2Runtime.ticksPerSecond).rounded()))
        guard target > current.tick else { return false }
        let prefix = rewindOriginInputs.prefix { $0.tick <= target }
        do { game = try L2RunRecovery.replay(initial: initial, inputs: Array(prefix), through: target) }
        catch {
            message = L10n.text("Could not move forward through this run: \(error)")

            return false
        }
        recoveryInputs = Array(prefix)
        lastFanInput = nil; lastAimInput = nil; beforeNuke = nil
        nukeCount = recoveryInputs.reduce(into: 0) { count, input in
            if case .nuke = input.action { count += 1 }
        }
        usedRewind = true; paused = true; accumulator = 0; updateUserMusicPause()
        assignmentFocus.rewind(to: target); canvas.assignmentHighlight.clear(); sounds.silence()
        refreshGame(); saveCheckpoint(immediately: true)

        return true
    }
    private func startIntroduction() {
        do {
            introduction = try Lemmings2Introduction(root:root,font:assets.font)
            music.suspendOutput(); show(.intro)
        } catch { explain(L10n.text("Could not load the introduction: \(error)"),returnTo:.menu) }
    }
    private func key(_ key: String) {
        if screen == .results {
            if key.lowercased() == "r" { prepareBriefing(); return }
            if key.lowercased() == "b" { showLevelRecords(); return }
            if key.lowercased() == "v" { runMovie.review(); return }
            if key.lowercased() == "s" { runMovie.review(save: true); return }
        }
        if screen == .intro { show(.menu); return }
        if screen == .menu && key.lowercased() == "i" { startIntroduction(); return }
        if key == "\u{1b}" {
            if screen == .playing { paused = true; show(.menu) }
            else if screen == .message { show(previousScreen) }
            else { show(.menu) }
            return
        }
        if screen == .menu {
            if key.lowercased() == "p" { show(.practice); return }
            if key.lowercased() == "m" { practiceLevel = nil; show(.map); return }
        }
        if screen == .practice {
            if let choice = Int(key), (1...4).contains(choice) { practiceChoice = choice-1 }
            else if ["left","right","up","down"].contains(key) {
                let delta = ["left":-1,"right":1,"up":-13,"down":13][key] ?? 0
                hoverPracticeSkill = max(1,min(51,(hoverPracticeSkill ?? 1)+delta))
            } else if key == " ", let id = hoverPracticeSkill {
                clickFront(4+(id-1)%13*24,28+(id-1)/13*20)
            } else if key == "\r" { clickFront(160,186) }
            front.needsDisplay = true; return
        }
        if screen == .map {
            if key == "left" || key == "right" {
                hoverTribe = ((hoverTribe ?? campaign.tribe)+(key == "left" ? 11 : 1))%12
                front.needsDisplay = true; return
            }
            if key == "\r" || key == " " {
                try? campaign.select(tribe:hoverTribe ?? campaign.tribe); persist(); prepareBriefing(); return
            }
        }
        if screen == .playing {
            if key == "." { singleStep() }
            else if let game, let index = SkillShortcuts(names: game.configuration.skills.map(\.name)).index(for: key, modern: audioSettings.modernControlsEnabled) { panelAction(index) }
            else if key == " " || key.lowercased() == "p" { panelAction(8) }
            else if key.lowercased() == "r" { retryLevel() }
        } else if key == "\r" || key == " " {
            if screen == .menu { playFromMenu() }
            else if screen == .briefing { startLevel() }
            else if screen == .results { continueResult() }
            else if screen == .message { show(previousScreen) }
            else if screen == .talisman || screen == .ending || screen == .preferences { clickFront(160,186) }
            else if screen == .save || screen == .load { clickFront(80,186) }
        } else if screen == .briefing && (key == "left" || key == "right") {
            changeLevel(key == "left" ? -1 : 1)
        } else if (screen == .save || screen == .load) && (key == "up" || key == "down") {
            selectedSlot = max(0,min(7,selectedSlot+(key == "up" ? -1 : 1))); front.needsDisplay = true
        }
    }
    private func changeLevel(_ direction: Int) {
        guard practiceLevel == nil else { return }
        guard onSequenceContinue == nil else {
            explain(
                L10n.text("Return to the library before choosing another level."),
                returnTo: .briefing)
            return
        }
        if (try? campaign.select(tribe: campaign.tribe, level: campaign.level + direction)) != nil { prepareBriefing() }
    }
    private func continueResult() {
        if practiceLevel != nil { show(.practice); return }
        guard let game else { return }
        if onSequenceContinue != nil, !game.didWin {
            retryLevel()
            return
        }
        if onSequenceContinue?(game.didWin) == true { return }
        guard recordsCampaignProgress else { prepareBriefing(); return }
        if game.didWin && campaign.level == 9 { show(.talisman) }
        else if campaign.advance(after: game) { persist(); prepareBriefing() }
        else { prepareBriefing() }
    }
    func releasePointerForMenu() { canvas.capturePointer(active: false); releasePointerInput(); saveCheckpoint(immediately: true) }
    private func recordLevelChoices() -> [ArcadeLevel] {
        guard let current = arcadeLevel, practiceLevel == nil else { return RecordLevelNavigation.savedLevels(current: arcadeLevel) }
        let first = campaign.tribe * 10
        let entries = (0..<10).map { (id: "\(campaign.tribe):\($0)", title: campaign.levels[first + $0].title) }
        return RecordLevelNavigation.levels(current: current, entries: entries)
    }
    func showLevelRecords() {
        if screen == .playing { releasePointerInput() }
        ArcadeWindow.shared.actionReplayContext = { [weak self] in self?.leaderboardReplayContext() }
        ArcadeWindow.shared.showRecords(level: arcadeLevel, owner: window, background: arcadeBackdrop, levels: recordLevelChoices())
    }
    var arcadeBackdrop: CGImage? { ArcadeWindow.captureScene(canvas) }
    func leaderboardReplayContext() -> LeaderboardReplayContext? {
        guard let initial, let style, let conditions = arcadeLevel?.conditions else { return nil }
        let level = level, sprites = sprites, intern = intern, explosion = explosion, walker = walker, panel = assets.panel
        return LeaderboardReplayContext(conditions: conditions.fingerprint, initial: .lemmings2(initial), makeField: {
            let field = Lemmings2Canvas()
            field.readOnlyReplay = true; field.hdEffectsEnabled = false; field.variableSpeedEnabled = false
            try field.load(level: level, style: style, sprites: sprites, intern: intern, explosion: explosion, walker: walker)
            return (field, { state in
                guard case .lemmings2(let game) = state else { return }
                field.update(game)
                if let image = try? panel.render(skills: game.configuration.skills.map(\.rawValue), supplies: game.supplies,
                    selected: 0, saved: game.saved, remaining: game.lemmings.filter(\.active).count,
                    seconds: game.remainingSeconds, label: L10n.text("REPLAY"), palette: Lemmings2Panel.palette(over: game.configuration.palette, phase: game.tick / 4), highlightedControls: []) {
                    field.setPanel(image)
                }
            })
        }, suspend: { [weak self] in self?.suspendForReplay() ?? {} })
    }
    private func recordArcadeResult(_ game: Lemmings2Runtime) {
        guard arcadeReport == nil else { return }
        guard let arcadeLevel else { return }
        var used: [String: Int] = [:]
        for slot in game.supplies.indices {
            let count = game.configuration.supplies[slot] + (game.bonusSkillSlot == slot ? 1 : 0) - game.supplies[slot]
            if count > 0 { used[TrolleyCapture.skillKey(game.configuration.skills[slot].name), default: 0] += count }
        }
        let run = ArcadeRun(id: arcadeRunID, profileID: arcadeProfileID,
            level: arcadeLevel, saved: game.saved, didWin: game.didWin, skills: used,
            seconds: Double(game.tick) / Lemmings2Runtime.ticksPerSecond, assisted: usedRewind,
            telemetry: TrolleyTelemetry(released: game.released, nukeCount: nukeCount, rewindCount: usedRewind && undoCount == 0 ? 1 : 0, undoCount: undoCount,
                destructiveSkillCount: TrolleyCapture.destructiveCount(used), buildVersion: TrolleyCapture.buildVersion,
                additionalStatistics: ["goldRequirement": Double(max(1, game.configuration.total - level.allowedLossesForGold))]))
        if let initial { ArcadeStore.shared.preserveHotSeatGhost(run: run, sessionID: arcadeHotSeatID,
            initial: .lemmings2(initial), final: .lemmings2(game),
            commands: recoveryInputs.map(LeaderboardActionReplay.Command.l2)) }
        arcadeReport = (recordsCampaignProgress || onSequenceContinue != nil)
            ? ArcadeStore.shared.record(run)
            : ArcadeStore.shared.previewReport(for: run)
        syncPrecisionZoom()
        guard let arcadeReport else { return }
        if recordsCampaignProgress {
            runMovie.preserveRecord(arcadeReport)
            if let initial { ArcadeStore.shared.preserveActions(run: run, initial: .lemmings2(initial),
                final: .lemmings2(game), commands: recoveryInputs.map(LeaderboardActionReplay.Command.l2)) }
        }
        ArcadeWindow.shared.actionReplayContext = { [weak self] in self?.leaderboardReplayContext() }
        ArcadeWindow.shared.showResult(arcadeReport, owner: window, retry: { [weak self] in self?.retryLevel() },
            next: { [weak self] in self?.continueResult() }, replay: { [weak self] save in self?.runMovie.review(save: save) },
            storedReplay: { [weak self] url, title in self?.runMovie.reviewStored(url, title: title) },
            continueTitle: resultContinueTitle, background: arcadeBackdrop,
            rewardVolume: sounds.muted ? 0 : audioSettings.soundVolume,
            rewardVolumeProvider: { [weak self] in self?.sounds.effectiveVolume ?? 0 },
            continueHandlesHandover: onSequenceContinue != nil,
            skip: audioSettings.modernControlsEnabled && learningResultActions != nil
                ? learningResultActions?.skip : canSkipLevel ? { [weak self] in self?.skipLevel() } : nil,
            prepareSkip: learningResultActions?.prepareSkip,
            later: learningResultActions?.later, hints: learningResultActions?.hints,
            menu: { [weak self] in self?.gameplayKeyboard?.mainMenu?() })
    }
    /// Level skips apply to a failed campaign level, not practice or playlists.
    /// Old school turns them off with the other modern controls.
    private var canSkipLevel: Bool {
        audioSettings.modernControlsEnabled && practiceLevel == nil && onSequenceContinue == nil && recordsCampaignProgress
            && game?.didWin == false && campaign.canSkipLevel
    }
    /// The result screen has already spent the skip. This only moves the campaign.
    private func skipLevel() {
        guard canSkipLevel, campaign.skipLevel() else { return }
        persist(); prepareBriefing()
    }
    private var resultContinueTitle: String {
        if practiceLevel != nil { return L10n.text("Practice levels") }
        if onSequenceContinue != nil { return game?.didWin == false ? L10n.text("Retry level") : sequenceContinueTitle }
        return campaign.level == 9 ? L10n.text("Continue") : L10n.text("Next level")
    }
    // Region centres follow the original map artwork; the nearest tribe owns
    // the intervening land. The ark has its own hit region at the top.
    private let tribePoints = [(82,42), (82,153), (135,50), (254,81), (166,145), (105,76),
                              (279,166), (218,151), (168,54), (255,42), (78,91), (78,123)]
    private func tribeAt(_ x: Int, _ y: Int) -> Int? {
        guard (18..<306).contains(x), (15..<181).contains(y) else { return nil }
        return tribePoints.indices.min { a, b in
            let p = tribePoints[a], q = tribePoints[b]
            return (p.0-x)*(p.0-x)+(p.1-y)*(p.1-y) < (q.0-x)*(q.0-x)+(q.1-y)*(q.1-y)
        }
    }
    private func practiceSkillAt(_ x: Int, _ y: Int) -> Int? {
        guard (4..<316).contains(x), (28..<108).contains(y) else { return nil }
        let id = (y-28)/20*13+(x-4)/24+1
        return id <= 51 ? id : nil
    }
    private func accessibleFrontActions() -> [(String, CGRect, () -> Void)] {
        var entries: [(String, CGRect)] = []
        switch screen {
        case .menu:
            entries = [(L10n.text("Play"), CGRect(x: 10, y: 125, width: 70, height: 22)), (L10n.text("Choose tribe"), CGRect(x: 10, y: 150, width: 70, height: 22)), (L10n.text("Preferences"), CGRect(x: 10, y: 175, width: 70, height: 22)),
                (L10n.text("Load game"), CGRect(x: 240, y: 125, width: 70, height: 22)), (L10n.text("Save game"), CGRect(x: 240, y: 150, width: 70, height: 22)), (L10n.text("Return to library"), CGRect(x: 240, y: 175, width: 70, height: 22)),
                (L10n.text("Introduction"), CGRect(x: 120, y: 150, width: 70, height: 22)), (L10n.text("Practice"), CGRect(x: 100, y: 175, width: 110, height: 22))]
        case .map:
            entries = tribePoints.enumerated().map { index, point in (Lemmings2Campaign.tribeNames[index], CGRect(x: point.0 - 5, y: point.1 - 5, width: 10, height: 10)) }
        case .practice:
            entries = (1...51).compactMap { id -> (String, CGRect)? in
                guard let skill = Lemmings2Runtime.Skill(rawValue: id) else { return nil }
                let column = (id - 1) % 13
                let row = (id - 1) / 13
                let rect = CGRect(x: 4 + column * 24, y: 28 + row * 20, width: 24, height: 20)
                return (SkillVocabulary.title(skill.name), rect)
            }
            for (index, tribe) in Lemmings2Practice.tribes.enumerated() { entries.append((Lemmings2Campaign.tribeNames[tribe], CGRect(x: index * 80, y: 133, width: 80, height: 36))) }
            if practiceSkills.count == 8 { entries.append((L10n.text("Start practice"), CGRect(x: 100, y: 180, width: 120, height: 18))) }
        case .load, .save:
            entries = (0..<8).map { (L10n.text("Slot \($0 + 1)"), CGRect(x: 20, y: 40 + $0 * 16, width: 280, height: 16)) }
            entries += [(screen == .load ? L10n.text("Load selected slot") : L10n.text("Save to selected slot"), CGRect(x: 10, y: 180, width: 140, height: 18)), (L10n.text("Cancel"), CGRect(x: 170, y: 180, width: 140, height: 18))]
        case .preferences:
            entries = [(L10n.text("Toggle music"), CGRect(x: 20, y: 110, width: 135, height: 24)), (L10n.text("Toggle sounds"), CGRect(x: 160, y: 110, width: 135, height: 24)), (L10n.text("Toggle enhanced artwork"), CGRect(x: 20, y: 148, width: 280, height: 24)), (L10n.text("Back"), CGRect(x: 20, y: 180, width: 280, height: 18))]
        case .playing: break
        default: entries = [(L10n.text("Continue"), CGRect(x: 100, y: 180, width: 120, height: 18))]
        }
        let current = screen
        return entries.map { title, rect in (title, rect, { [weak self] in
            guard let self, self.screen == current else { return }
            self.clickFront(Int(rect.midX), Int(rect.midY))
        }) }
    }
    private func clickFront(_ x: Int, _ y: Int) {
        func inside(_ a: Int, _ b: Int, _ w: Int, _ h: Int) -> Bool { x >= a && x < a+w && y >= b && y < b+h }
        switch screen {
        case .intro: show(.menu)
        case .menu:
            if inside(10, 125, 70, 22) { playFromMenu() }
            else if inside(10, 150, 70, 22) { practiceLevel = nil; show(.map) }
            else if inside(10, 175, 70, 22) { show(.preferences) }
            else if inside(240, 125, 70, 22) { show(.load) }
            else if inside(240, 150, 70, 22) { show(.save) }
            else if inside(240, 175, 70, 22) { close() }
            else if inside(120, 150, 70, 22) {
                startIntroduction()
            } else if inside(100, 175, 110, 22) {
                show(.practice)
            }
        case .practice:
            if let id = practiceSkillAt(x,y), let skill = Lemmings2Runtime.Skill(rawValue:id) {
                if let index = practiceSkills.firstIndex(of:skill) { practiceSkills.remove(at:index) }
                else if practiceSkills.count < 8 { practiceSkills.append(skill) }
                front.needsDisplay = true
            } else if (133..<169).contains(y) {
                practiceChoice = max(0,min(3,x/80)); front.needsDisplay = true
            } else if y >= 178 && practiceSkills.count == 8 {
                practiceLevel = practice.levels[practiceChoice]; game = nil; initial = nil; prepareBriefing()
            }
        case .map:
            if inside(106, 5, 40, 20) { show(.talisman) }
            else if let tribe = tribeAt(x, y) {
                try? campaign.select(tribe: tribe); persist(); prepareBriefing()
            }
        case .briefing:
            if inside(148, 120, 40, 31) { changeLevel(-1) }
            else if inside(273, 120, 40, 31) { changeLevel(1) }
            else { startLevel() }
        case .results:
            if (145..<172).contains(y) { runMovie.review(save: x >= 160); return }
            if inside(0, 178, 100, 22) { retryLevel() }
            else if inside(220, 178, 100, 22) { show(.menu) }
            else { continueResult() }
        case .preferences:
            if inside(25, 110, 100, 24) {
                let key = progressKey + ".musicMuted"
                UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: key), forKey: key)
                setAudioSettings(audioSettings, muted: globallyMuted)
                front.needsDisplay = true
            } else if inside(160, 110, 135, 24) {
                let key = progressKey + ".soundsMuted"
                UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: key), forKey: key)
                setAudioSettings(audioSettings, muted: globallyMuted)
                if let click = Lemmings2SoundRequest.panel(slot: 0) { sounds.play([click]) }
                front.needsDisplay = true
            } else if inside(20, 148, 280, 24) {
                SequelArtworkPreference.setEnabled(!SequelArtworkPreference.enabled)
            } else if y >= 180 { show(.menu) }
        case .save, .load:
            if y >= 178 {
                if x >= 160 { show(.menu); return }
                let key = progressKey + ".slot.\(selectedSlot)"
                if screen == .save {
                    if let data = try? JSONEncoder().encode(campaign.progress) {
                        UserDefaults.standard.set(data, forKey: key); show(.menu)
                    }
                } else if let data = UserDefaults.standard.data(forKey: key) {
                    do {
                        try campaign.restore(JSONDecoder().decode(Lemmings2Campaign.Progress.self, from: data))
                        game = nil; initial = nil; practiceLevel = nil
                        persist(); prepareBriefing()
                    } catch { explain(L10n.text("This saved game cannot be loaded."), returnTo: .load) }
                }
            } else if (40..<168).contains(y) { selectedSlot = (y - 40) / 16; front.needsDisplay = true }
        case .talisman:
            if campaign.isComplete {
                do {
                    ending = try Lemmings2Ending(root:root,assets:assets,golden:campaign.canLaunchArk)
                    playMusic("endtune"); show(.ending)
                } catch { explain(L10n.text("Could not load the ending: \(error)"),returnTo:.map) }
            }
            else { show(.map) }
        case .ending:
            ending?.requestContinue()
        case .message: show(previousScreen)
        case .playing: break
        }
    }

    private func drawFront() {
        func bank(_ name: String) -> Lemmings2FrontEnd.Bank { assets.banks[name]! }
        func palette(_ name: String) -> [UInt8] { bank(name).palettes[1] }
        func picture(_ name: String, _ pal: [UInt8]) {
            if let pixels = assets.pictures[name] { front.draw(pixels, width: 320, height: 200, palette: pal, x: 0, y: 0) }
        }
        func sprite(_ name: String, _ id: Int, _ x: Int, _ y: Int, frame: Int = 0, pal: [UInt8]? = nil) {
            let frames = bank(name).sprites[id], f = frames[max(0, frame) % frames.count]
            front.draw(f.pixels, width: f.width, height: f.height, palette: pal ?? palette(name),
                       x: x + f.x, y: y + f.y, opaque: f.opaque)
        }
        func text(_ string: String, _ x: Int, _ y: Int, _ name: String = "INFO", centered: Bool = false) {
            front.text(string, font: assets.font, palette: palette(name), x: centered ? x - assets.font.width(string) / 2 : x, y: y)
        }
        switch screen {
        case .menu: picture("MENU", palette("MENU"))
        case .practice:
            picture("ROCKWALL",palette("PRACTICE"))
            text(L10n.text("Select 8 skills to practice"),160,8,"PRACTICE",centered:true)
            for id in 1...51 {
                let x = 4+(id-1)%13*24, y = 28+(id-1)/13*20
                let f = bank("PRACTICE").sprites[3][id-1]
                let scale = min(1,min(22/CGFloat(f.width),18/CGFloat(f.height)))
                let image = front.makeImage(f.pixels,width:f.width,height:f.height,palette:palette("PRACTICE"),opaque:f.opaque)
                image.draw(in:NSRect(x:CGFloat(x)+(24-CGFloat(f.width)*scale)/2,
                    y:CGFloat(y)+(18-CGFloat(f.height)*scale)/2,width:CGFloat(f.width)*scale,height:CGFloat(f.height)*scale),
                    from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,
                    hints:[.interpolation:NSImageInterpolation.none.rawValue])
                if let skill = Lemmings2Runtime.Skill(rawValue:id), let order = practiceSkills.firstIndex(of:skill) {
                    NSColor.black.withAlphaComponent(0.85).setFill()
                    NSRect(x:x+15,y:y+9,width:9,height:10).fill()
                    text(String(order+1),x+16,y+9,"PRACTICE")
                    NSColor.yellow.setStroke()
                    let outline = NSBezierPath(rect:NSRect(x:x,y:y,width:24,height:18))
                    outline.lineWidth = 0.5; outline.stroke()
                }
                if hoverPracticeSkill == id {
                    NSColor.white.setStroke()
                    let outline = NSBezierPath(rect:NSRect(x:x,y:y,width:24,height:18))
                    outline.lineWidth = 0.5; outline.stroke()
                }
            }
            let label = hoverPracticeSkill.flatMap(Lemmings2Runtime.Skill.init(rawValue:)).map { SkillVocabulary.title($0.name) } ?? L10n.text("\(practiceSkills.count) of 8 selected")
            text(label,160,112,"PRACTICE",centered:true)
            for (choice,tribe) in Lemmings2Practice.tribes.enumerated() {
                let f = bank("INFO").sprites[8+tribe][0]
                let portrait = front.makeImage(f.pixels,width:f.width,height:f.height,
                    palette:palette("INFO"),opaque:f.opaque)
                portrait.draw(in:NSRect(x:choice*80+24,y:136,width:32,height:24),
                    from:NSRect(x:96,y:0,width:64,height:48),operation:.sourceOver,fraction:1,
                    respectFlipped:true,hints:[.interpolation:NSImageInterpolation.none.rawValue])
                if choice == practiceChoice {
                    sprite("PRACTICE",6,choice*80+24,135,frame:frontTicks/6)
                    text("*",choice*80+14,144,"PRACTICE")
                }
            }
            text(Lemmings2Campaign.tribeNames[Lemmings2Practice.tribes[practiceChoice]],160,168,"PRACTICE",centered:true)
            text(practiceSkills.count == 8 ? L10n.text("Click or Return to practise") : L10n.text("Choose eight different skills"),160,186,"PRACTICE",centered:true)
        case .map:
            picture("MAP", palette("MAP"))
            for (id, x, y) in [(2,232,59),(4,117,144),(3,288,141),(5,44,151),(6,47,104)] {
                sprite("MAP", id, x, y, frame: frontTicks / 6)
            }
            text(Lemmings2Campaign.tribeNames[hoverTribe ?? campaign.tribe], 165, 183, "MAP", centered: true)
        case .intro:
            if let introduction {
                front.draw(introduction.animation.pixels,width:320,height:200,
                           palette:introduction.animation.palette,x:0,y:0)
            }
        case .briefing:
            picture("ROCKWALL", palette("INFO"))
            // INFO.GAL uses the left 140 pixels for eight 25-pixel skill rows.
            for i in 0..<8 {
                let skill = practiceLevel != nil ? practiceSkills[i].rawValue : level.skills[i].identifier
                sprite("INFO", 0, 0, i * 25)
                if (1...51).contains(skill) { sprite("INFO", 7, 0, i * 25, frame: skill - 1) }
                text(String(format: "%02d", practiceLevel != nil ? 99 : level.skills[i].count), 32, i * 25 + 2)
                if (1...51).contains(skill) { text(SkillVocabulary.title(bank("INFO").strings[skill - 1]), 32, i * 25 + 13) }
            }
            // All tribe cards use the shared INFO palette, including their portraits.
            sprite("INFO", 8 + level.style, 150, 10)
            sprite("INFO", 3, 144, 64)
            if let preview {
                let scale = min(160 / preview.size.width, 64 / preview.size.height)
                let width = preview.size.width * scale, height = preview.size.height * scale
                front.drawImage(preview, rect: NSRect(x: 232 - width / 2, y: 99 - height / 2, width: width, height: height))
            }
            if practiceLevel == nil && campaign.level > 0 { sprite("INFO", 5, 152, 127) }
            if practiceLevel == nil && campaign.level < campaign.unlockedLevel(in: campaign.tribe) { sprite("INFO", 4, 279, 127) }
            front.fittedText(practiceLevel != nil ? L10n.text("Practice") : "\(Lemmings2Campaign.tribeNames[campaign.tribe]) \(campaign.level + 1)",
                             font: assets.font, palette: palette("INFO"),
                             rect: NSRect(x: 145, y: 135, width: 173, height: 13))
            front.fittedText(level.title, font: assets.font, palette: palette("INFO"),
                             rect: NSRect(x: 145, y: 150, width: 173, height: 24))
            text(L10n.text("\(practiceLevel != nil ? 60 : campaign.population) Lemmings"), 231, 176, centered: true)
            text(L10n.text("TIME \(level.timeLimitSeconds / 60):\(String(format: "%02d", level.timeLimitSeconds % 60))"), 231, 187, centered: true)
        case .results:
            picture("ROCKWALL", palette("MEDALS"))
            if let game {
                let medal = Lemmings2Campaign.medal(saved: game.saved, total: game.configuration.total, allowedLosses: level.allowedLossesForGold)
                sprite("MEDALS", 2, 30, 25)
                if medal != .none {
                    let locations = [(0,0),(43,64),(85,54),(64,44)]
                    let p = locations[medal.rawValue]
                    sprite("MEDALS", medal == .gold ? 3 : medal == .silver ? 4 : 5, p.0, p.1, frame: min(20, frontTicks / 4))
                }
                text(L10n.plural("count.savedLemmings", count: game.saved, one: "You saved %ld lemming", other: "You saved %ld lemmings"), 160, 8, "MEDALS", centered: true)
                text(medal == .none ? L10n.text("Oh dear!") : L10n.text("\(medal.name) medal"), 220, 42, "MEDALS", centered: true)
                front.wrappedText(game.didWin ? L10n.text("Click to continue. Your survivors will go on to the next level.")
                    : L10n.originalL2Text(bank("MEDALS").strings[4]), font: assets.font, palette: palette("MEDALS"), x: 135, y: 70, width: 170)
                text(L10n.text("V Replay  S Save movie"), 160, 153, "MEDALS", centered: true)
                text(L10n.text("Retry"), 35, 182, "MEDALS", centered: true)
                text(L10n.text("Continue"), 160, 182, "MEDALS", centered: true)
                text(L10n.text("Menu"), 285, 182, "MEDALS", centered: true)
            }
        case .preferences:
            picture("ROCKWALL", palette("PREFS"))
            text(L10n.text("Control Method"), 160, 24, "PREFS", centered: true)
            text(L10n.text("Mouse"), 160, 44, "PREFS", centered: true)
            text(L10n.text("Music"), 52, 124, "PREFS")
            sprite("PREFS", music.muted ? 5 : 6, 38, 114)
            text(L10n.text("Sound FX"), 189, 124, "PREFS")
            sprite("PREFS", sounds.muted ? 5 : 6, 175, 114)
            text(SequelArtworkPreference.enabled ? L10n.text("Artwork: Macintosh-style 2x") : L10n.text("Artwork: Original PC"),
                 160, 154, "PREFS", centered: true)
            text("OK", 160, 184, "PREFS", centered: true)
        case .load, .save:
            picture("ROCKWALL", palette("LOAD"))
            text(screen == .save ? L10n.text("Save Game") : L10n.text("Select a game to load"), 160, 12, "LOAD", centered: true)
            for i in 0..<8 {
                let key = progressKey + ".slot.\(i)"
                let data = UserDefaults.standard.data(forKey: key)
                let saved = data.flatMap { data -> Lemmings2Campaign.Progress? in
                    guard let progress = try? JSONDecoder().decode(Lemmings2Campaign.Progress.self, from: data) else { return nil }
                    var checked = campaign
                    do { try checked.restore(progress); return progress }
                    catch { return nil }
                }
                let name = saved.map { L10n.text("\(Lemmings2Campaign.tribeNames[$0.tribe]) - Level \($0.level + 1)") }
                    ?? (data == nil ? L10n.text("<Unsaved Position>") : L10n.text("<Invalid saved game>"))
                text("\(i == selectedSlot ? ">" : " ") \(i + 1). \(name)", 34, 40 + i * 16, "LOAD")
            }
            text(screen == .save ? L10n.text("Save") : L10n.text("Load"), 80, 184, "LOAD", centered: true)
            text(L10n.text("Cancel"), 240, 184, "LOAD", centered: true)
        case .talisman:
            if let award {
                front.draw(award.animation.pixels,width:320,height:200,palette:award.animation.palette,x:0,y:0)
                if frontTicks > 120 { text(L10n.text("Click to continue"),160,184,L10n.text("AWARD"),centered:true) }
            }
        case .ending:
            if let ending {
                front.draw(ending.pixels,width:320,height:200,palette:ending.palette,x:0,y:0)
            }
        case .message:
            picture("ROCKWALL", palette("INFO"))
            front.wrappedText(message, font: assets.font, palette: palette("INFO"), x: 24, y: 55, width: 272)
            text(L10n.text("Click to return"), 160, 182, centered: true)
        case .playing: break
        }
    }
}

@MainActor final class Lemmings2MenuCanvas: NSView {
    let turnBadge = TurnBadgeView()
    private var turnHeader: CGFloat { turnBadge.isHidden ? 0 : 40 }
    override func layout() {
        super.layout()
        if turnBadge.superview == nil { addSubview(turnBadge) }
        turnBadge.place(in: CGRect(x: 0, y: 0, width: bounds.width, height: 42))
    }
    private let artworkRenderer = SequelArtworkRenderer()
    var menuActions: (() -> [(String, CGRect, () -> Void)])?
    private let accessibleElements = GameAccessibleElements()
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityChildren() -> [Any]? {
        (turnBadge.isHidden ? [] : [turnBadge] as [Any]) + (menuActions?() ?? []).enumerated().map { index, item in
            accessibleElements.element(id: "action-\(index)", owner: self, label: item.0,
                frame: CGRect(x: origin.x + item.1.minX * zoom, y: origin.y + item.1.minY * zoom * 1.2, width: item.1.width * zoom, height: item.1.height * zoom * 1.2), press: item.2)
        }
    }
    var onDraw: (() -> Void)?
    var onClick: ((Int, Int) -> Void)?
    var onMove: ((Int, Int) -> Void)?
    var onKey: ((String) -> Void)?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    private var zoom: CGFloat { max(0.1, min(bounds.width / 320, (bounds.height - turnHeader) / 240)) }
    private var origin: NSPoint { NSPoint(x: (bounds.width - 320 * zoom) / 2, y: turnHeader + (bounds.height - turnHeader - 240 * zoom) / 2) }
    override func updateTrackingAreas() {
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self))
        super.updateTrackingAreas()
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); bounds.fill()
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: origin.x, yBy: origin.y); transform.scaleX(by: zoom, yBy: zoom * 1.2); transform.concat()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 320, height: 200)).addClip()
        onDraw?()
        NSGraphicsContext.restoreGraphicsState()
    }
    func makeImage(_ pixels: [UInt8], width: Int, height: Int, palette: [UInt8], opaque: [Bool]? = nil,
                   category: SequelMacCategory = .architectural, frontEnd: Bool = true) -> NSImage {
        return try! artworkRenderer.image(width: width, height: height, pixels: pixels,
            palette: palette, opaque: opaque ?? Array(repeating: true, count: pixels.count), category: category, frontEnd: frontEnd)
    }
    func drawImage(_ image: NSImage, rect: NSRect) {
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                   hints: [.interpolation: NSImageInterpolation.none.rawValue])
    }
    func draw(_ pixels: [UInt8], width: Int, height: Int, palette: [UInt8], x: Int, y: Int, opaque: [Bool]? = nil) {
        drawImage(makeImage(pixels, width: width, height: height, palette: palette, opaque: opaque),
                  rect: NSRect(x: x, y: y, width: width, height: height))
    }
    func text(_ text: String, font: Lemmings2FrontEndFont, palette: [UInt8], x: Int, y: Int) {
        let top = font.bitmap.verticalBounds(of: text).top
        let left = font.bitmap.horizontalBounds(of: text).left
        for placed in font.bitmap.layout(text) {
            guard let glyph = placed.glyph else { continue }
            draw(glyph.pixels, width: glyph.width, height: glyph.height, palette: palette,
                 x: x + placed.x + glyph.x - left, y: y + glyph.y - top, opaque: glyph.opaque)
        }
    }
    func wrappedText(_ text: String, font: Lemmings2FrontEndFont, palette: [UInt8], x: Int, y: Int, width: Int) {
        let pitch = max(13, font.bitmap.height(of: text) + 2)
        for (row, line) in font.bitmap.wrapped(text, toWidth: width).enumerated() {
            self.text(line, font: font, palette: palette, x: x, y: y + row * pitch)
        }
    }
    func fittedText(_ text: String, font: Lemmings2FrontEndFont, palette: [UInt8], rect: NSRect) {
        let lines = font.bitmap.wrapped(text, toWidth: Int(rect.width))
        guard !lines.isEmpty else { return }
        let width = max(1, lines.map(font.width).max() ?? 1)
        let pitch = max(13, font.bitmap.height(of: text) + 2)
        let height = lines.count * pitch - 2
        let scale = min(1, rect.width / CGFloat(width), rect.height / CGFloat(height))
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rect.midX, yBy: rect.minY)
        transform.scale(by: scale); transform.concat()
        for (row, line) in lines.enumerated() {
            self.text(line, font: font, palette: palette, x: -font.width(line) / 2, y: row * pitch)
        }
        NSGraphicsContext.restoreGraphicsState()
    }
    private func point(_ event: NSEvent) -> (Int, Int)? {
        let p = convert(event.locationInWindow, from: nil)
        let x = (p.x - origin.x) / zoom, y = (p.y - origin.y) / (zoom * 1.2)
        return x >= 0 && x < 320 && y >= 0 && y < 200 ? (Int(x), Int(y)) : nil
    }
    override func mouseDown(with event: NSEvent) { if let p = point(event) { onClick?(p.0, p.1) } }
    override func mouseMoved(with event: NSEvent) { if let p = point(event) { onMove?(p.0, p.1) } }
    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { super.keyDown(with: event); return }
        if event.isARepeat, [" ", "p"].contains(event.charactersIgnoringModifiers ?? "") { return }
        if event.keyCode == 123 { onKey?("left") }
        else if event.keyCode == 124 { onKey?("right") }
        else if event.keyCode == 125 { onKey?("down") }
        else if event.keyCode == 126 { onKey?("up") }
        else if let text = event.charactersIgnoringModifiers { onKey?(text) }
    }
}

@MainActor private final class Lemmings2Canvas: NSView, HotSeatGhostRendering {
    var hotSeatGhosts: HotSeatGhostPlayback?
    private let hotSeatGhostSprites = ReplayGhostSprites()
    var readOnlyReplay = false
    let timeline = TimelinePanelControls()
    private func layoutTimeline() {
        let width = min(260, bounds.width - 16)
        timeline.frame = CGRect(x: (bounds.width - width) / 2, y: bounds.height - 34, width: width, height: 30)
    }

    var navigationFrame: CGRect?
    private let pointerCapture = GamePointerCapture()
    private var capturedPointer: CGPoint?
    func capturePointer(active: Bool) {
        capturedPointer = pointerCapture.update(in: self, active: active && controllerPointer == nil)
        if let point = capturedPointer {
            trackPointer(at: point, held: NSEvent.pressedMouseButtons & 1 != 0)
        }
    }
    var onRelease: (() -> Void)?
    var onPointer: ((Int, Int, Bool) -> Void)?
    var onClick: ((Int, Int) -> Void)?
    private let accessibleElements = GameAccessibleElements()
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityChildren() -> [Any]? {
        guard !readOnlyReplay else { return [] }
        guard let game else { return [] }
        let names = game.configuration.skills.map { SkillVocabulary.title($0.name) } + [L10n.text("Pause"), L10n.text("End run"), L10n.text("Fan"), L10n.text("Fast-forward")]
        var children: [Any] = turnBadge.isHidden ? [] : [turnBadge]
        for slot in 0..<12 {
            let x = slot < 8 ? slot * 32 : 256 + (slot % 2) * 32
            let y = slot < 10 ? 160 : 180
            let height = slot < 8 ? 40 : 20
            let frame = CGRect(x: panelX + CGFloat(x) * zoom, y: origin.y + CGFloat(y) * zoom * 1.2, width: 32 * zoom, height: CGFloat(height) * zoom * 1.2)
            let label = game.supplies.indices.contains(slot)
                ? L10n.text("\(names[slot]), \(game.supplies[slot]) remaining\((slot == selectedSkillSlot ? L10n.text(", selected") : ""))")
                : names[slot]
            children.append(accessibleElements.element(id: "panel-\(slot)", owner: self, label: label, frame: frame) { [weak self] in
                let time = ProcessInfo.processInfo.systemUptime
                self?.onPanel?(slot, 1, time)
                if slot == 9 { self?.onPanel?(slot, 2, time + 0.01) }
            })
        }
        if variableSpeedEnabled {
            for direction in [-1, 1] {
                children.append(accessibleElements.element(id: "speed-\(direction)", owner: self, label: direction < 0 ? L10n.text("Decrease fast speed") : L10n.text("Increase fast speed"), frame: speedRect) { [weak self] in self?.onSpeedStep?(direction, ProcessInfo.processInfo.systemUptime) })
            }
        }
        layoutTimeline()
        return children + timeline.accessibleControls(owner: self)
    }
    var onPanel: ((Int, Int, TimeInterval) -> Void)?
    var onHover: (() -> Void)?
    var onKey: ((String) -> Void)?
    var cameraX: CGFloat = 0 { didSet { onCameraChanged?() } }
    var cameraY: CGFloat = 0 { didSet { onCameraChanged?() } }
    var onCameraChanged: (() -> Void)?
    var soundViewport: GameplaySoundViewport {
        let topLeft = precisionLens.source(gameplayRect.origin)
        let bottomRight = precisionLens.source(CGPoint(x: gameplayRect.maxX, y: gameplayRect.maxY))
        return GameplaySoundViewport(x: Double(cameraX + (topLeft.x - origin.x) / zoom),
          y: Double(cameraY + (topLeft.y - origin.y) / (zoom * 1.2)),
          width: Double((bottomRight.x - topLeft.x) / zoom), height: Double((bottomRight.y - topLeft.y) / (zoom * 1.2)))
    }
    private var precisionLens = AnimatedPrecisionZoomLens()
    private var precisionScroll = PrecisionZoomScrollGesture()
    private let precisionZoomAnimation = PrecisionZoomAnimation()
    var precisionStatus = PrecisionZoomStatus() { didSet { needsDisplay = true } }
    var rewardBadgeRect: CGRect {
        CGRect(origin: CGPoint(x: gameplayRect.minX + 12, y: gameplayRect.minY + 12),
            size: precisionStatus.size(scale: bounds.width >= 960 ? 2 : 1))
    }
    var precisionStatusOpacity: CGFloat = 1 { didSet { if oldValue != precisionStatusOpacity { needsDisplay = true } } }
    var deathCountdownText = "" { didSet { if oldValue != deathCountdownText { needsDisplay = true } } }
    var onPrecisionScroll: ((PrecisionZoomScrollAction, CGPoint) -> Void)?
    func setPrecisionZoom(_ enabled: Bool, magnification: CGFloat? = nil, at cursor: CGPoint? = nil) {
        let centre = CGPoint(x: gameplayRect.midX, y: gameplayRect.midY)
        let pointer = cursor ?? cursorPoint() ?? centre
        let anchor = gameplayRect.contains(pointer) ? pointer : centre
        precisionZoomAnimation.start(from: precisionLens.magnification, to: enabled ? (magnification ?? 2) : 1,
            reduceMotion: reduceMotion) { [weak self] magnification in
                guard let self else { return }
                let delta = self.precisionLens.transition(toMagnification: magnification, at: anchor,
                    scaleX: self.zoom, scaleY: self.zoom * 1.2)
                self.cameraX += delta.x; self.cameraY += delta.y
                self.clampCamera(); self.needsDisplay = true
            }
    }
    private var cameraBounds: (left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat) = (0, 0, 0, 0)
    private var game: Lemmings2Runtime?
    private var terrain: NSImage?
    private var terrainRevision: Int?
    private let bitmapCache = GameplayBitmapCache()
    private var panelSource: SequelIndexedImage?
    private var panel: NSImage?
    private var panelBackground = NSColor.black
    var rewindOriginTick: Int?
    var rewindCurrentTick = 0
    var failureMoodAmount: CGFloat = 0
    var completionGlowAmount: CGFloat = 0
    private var sprites: [String: [(image: NSImage, x: Int, y: Int)]] = [:]
    private var objects: [(id: Int, type: Int, x: Int, y: Int, entrance: Bool, animated: Bool, special: Bool,
                           frames: [(image: NSImage, x: Int, y: Int)])] = []
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    private var viewport: Lemmings2Viewport {
        Lemmings2Viewport(viewWidth: Double(bounds.width), viewHeight: Double(max(1, bounds.height - (readOnlyReplay ? 0 : 38))))
    }
    private var zoom: CGFloat { CGFloat(viewport.scale) }
    private var visibleWidth: CGFloat { CGFloat(viewport.width) }
    private var origin: NSPoint { NSPoint(x: 0, y: viewport.originY) }
    private var panelX: CGFloat { CGFloat(viewport.panelX) * zoom }

    override func setFrameSize(_ newSize: NSSize) {
        let center = cameraX + visibleWidth / 2
        super.setFrameSize(newSize)
        cameraX = center - visibleWidth / 2
        clampCamera()
        needsDisplay = true
    }

    func advanceEdgeScrolling(elapsed: Double) {
        guard let window, window.isKeyWindow, !isHidden else { return }
        let point = controllerPointer ?? capturedPointer ?? convert(window.mouseLocationOutsideOfEventStream, from: nil)
        guard bounds.contains(point) else { return }
        let velocity = viewport.edgeVelocity(x: Double((point.x - origin.x) / zoom),
            y: Double((point.y - origin.y) / (zoom * 1.2)))
        guard velocity.x != 0 || velocity.y != 0 else { return }
        pan(x: CGFloat(velocity.x * min(0.05, max(0, elapsed))),
            y: CGFloat(velocity.y * min(0.05, max(0, elapsed))))
    }

    override func updateTrackingAreas() {
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .activeInKeyWindow, .inVisibleRect], owner: self))
        super.updateTrackingAreas()
    }
    override func mouseMoved(with event: NSEvent) { trackPointer(event,held:false); onHover?() }
    override func mouseEntered(with event: NSEvent) { trackPointer(event,held:false); onHover?() }
    override func mouseExited(with event: NSEvent) {
        guard !pointerCapture.isCaptured else { return }
        onRelease?(); onHover?(); NSCursor.arrow.set()
    }
    override func cursorUpdate(with event: NSEvent) {
        updateSystemCursor(at: convert(event.locationInWindow, from: nil))
    }
    private func updateSystemCursor(at point: CGPoint) {
        GameCursor.update(at: point, hidingInside: navigationFrame?.contains(point) == true ? nil : gameplayRect,
            controlScale: zoom)
    }
    override func resetCursorRects() {
        GameCursor.addCursorRects(in: self, cursor: GameCursor.gameplayCursor, over: gameplayRect,
            elsewhere: GameCursor.controlCursor(scale: zoom))
    }
    var gameplayRect: CGRect {
        CGRect(x: origin.x, y: origin.y, width: visibleWidth * zoom, height: 160 * zoom * 1.2)
    }
    var statusReadoutFrame: CGRect {
        GameplayMenuLayout.readout(CGRect(x: gameplayRect.maxX - 120, y: gameplayRect.minY + 12,
            width: 108, height: 36), in: self)
    }
    func updateSelection(slot: Int, fan: Bool, palette: [UInt8], skillFrame: Lemmings2SpriteFrame? = nil) -> String? {
        selectedSkillSlot = slot
        pointerSelectionEnabled = !fan
        skillBadge = skillFrame.map { image(width: $0.width, height: $0.height, pixels: $0.pixels,
                                             palette: palette, opaque: $0.opaque, category: .sprite) }
        var label: String?
        if let window, let game {
            let point = controllerPointer ?? convert(window.mouseLocationOutsideOfEventStream, from: nil)
            let source = gameplayRect.contains(point) ? precisionLens.source(point) : point
            let x = (source.x - origin.x) / zoom, y = (source.y - origin.y) / (zoom * 1.2)
            if (0..<visibleWidth).contains(x), (0..<160).contains(y) {
                if !fan, let target = game.target(slot: slot, x: Int(x + cameraX), y: Int(y + cameraY), preferApproaching: favorApproachingLemmings,
            preferBombBlockers: favorBombBlockers, preferBuilders: favorBuilders) {
                    switch target.state {
                    case .walking: label = L10n.text("WALKER")
                    case .running: label = L10n.text("RUNNER")
                    case .teleporting: label = L10n.text("TELEPORTER")
                    case .switchingValve: label = L10n.text("VALVE")
                    case .trapDying: label = nil
                    case .cannonLoading, .cannonFlying: label = L10n.text("CANNON")
                    case .catapultLoading: label = L10n.text("CATAPULT")
                    case .chainRiding: label = L10n.text("CHAIN")
                    case .superFlying: label = L10n.text("SUPERLEM")
                    case .arching: label = L10n.text("ARCHER")
                    case .skiing, .skiingAir: label = L10n.text("SKIER")
                    case .poleVaulting, .poleShrugging: label = L10n.text("POLE VAULTER")
                    case .magnoBooting: label = L10n.text("MAGNO BOOTER")
                    case .throwing: label = L10n.text("THROWER")
                    case .spearing: label = L10n.text("SPEARER")
                    case .carpetFlying: label = L10n.text("MAGIC CARPET")
                    case .surfing: label = L10n.text("SURFER")
                    case .sliding: label = L10n.text("SLIDER")
                    case .hanging, .climbingTransfer: label = L10n.text("HANGING")
                    case .skating: label = L10n.text("SKATER")
                    case .slipping, .iceRecovering: label = L10n.text("SLIPPING")
                    case .twisting: label = L10n.text("TWISTER")
                    case .jetPacking: label = L10n.text("JET PACK")
                    case .rolling, .rollingAir: label = L10n.text("ROLLER")
                    case .shimmyJump, .shimming: label = L10n.text("SHIMMIER")
                    case .diving: label = L10n.text("DIVER")
                    case .drowning: label = L10n.text("DROWNING")
                    case .kayaking, .kayakPacking: label = L10n.text("KAYAKER")
                    case .flyingIcarus: label = L10n.text("ICARUS WINGS")
                    case .hangGliding: label = L10n.text("HANG GLIDER")
                    case .roping: label = L10n.text("ROPER")
                    case .firingBazooka: label = L10n.text("BAZOOKA")
                    case .firingMortar: label = L10n.text("MORTAR")
                    case .rockClimbing: label = L10n.text("ROCK CLIMBER")
                    case .hoisting: label = L10n.text("HOISTER")
                    case .planting: label = L10n.text("PLANTER")
                    case .ballooning: label = L10n.text("BALLOONER")
                    case .filling: label = L10n.text("FILLER")
                    case .sandPouring: label = L10n.text("SAND POURER")
                    case .gluePouring: label = L10n.text("GLUE POURER")
                    case .attracting: label = L10n.text("ATTRACTOR")
                    case .dancing: label = L10n.text("DANCER")
                    case .parachuting: label = L10n.text("PARACHUTER")
                    case .swimming, .leavingWater: label = L10n.text("SWIMMER")
                    case .blastBombing: label = L10n.text("BOMBER")
                    case .jumping: label = L10n.text("JUMPER")
                    case .hopping, .hopPreparing: label = L10n.text("HOPPER")
                    case .tumbling: label = L10n.text("FALLER")
                    case .stunned: label = L10n.text("STUNNED")
                    case .trapped: label = nil
                    case .falling: label = L10n.text("FALLER")
                    case .floating: label = L10n.text("FLOATER")
                    case .climbing: label = L10n.text("CLIMBER")
                    case .building: label = L10n.text("BUILDER")
                    case .bashing: label = L10n.text("BASHER")
                    case .mining: label = L10n.text("MINER")
                    case .digging: label = L10n.text("DIGGER")
                    case .stomping: label = L10n.text("STOMPER")
                    case .scooping: label = L10n.text("SCOOPER")
                    case .fencing: label = L10n.text("FENCER")
                    case .clubBashing: label = L10n.text("CLUB BASHER")
                    case .lasering: label = L10n.text("LASER BLASTER")
                    case .flaming: label = L10n.text("FLAME THROWER")
                    case .blocking: label = L10n.text("BLOCKER")
                    case .stacking: label = L10n.text("STACKER")
                    case .platforming: label = L10n.text("PLATFORMER")
                    case .exploding: label = L10n.text("BOMBER")
                    default: label = L10n.text("LEMMING")
                    }
                }
            }
            if window.isKeyWindow, bounds.contains(point) {
                updateSystemCursor(at: point)
            }
        }
        return label
    }

    private let artworkRenderer = SequelArtworkRenderer()
    private var terrainCategory: SequelMacCategory = .architectural
    private var reloadArtwork: (() throws -> Void)?
    private func image(width: Int, height: Int, pixels: [UInt8], palette: [UInt8], opaque: [Bool]? = nil,
                       category: SequelMacCategory = .sprite) -> NSImage {
        try! artworkRenderer.image(width: width, height: height, pixels: pixels,
            palette: palette, opaque: opaque ?? Array(repeating: true, count: pixels.count), category: category)
    }
    func refreshArtwork() throws {
        let previous = game, oldX = cameraX, oldY = cameraY
        let wasFastForward = isFastForward
        try reloadArtwork?()
        cameraX = oldX; cameraY = oldY
        isFastForward = wasFastForward
        if let previous { update(previous) }
        needsDisplay = true
    }

    var hdEffectsEnabled = true {
        didSet {
            if !hdEffectsEnabled { hdrOverlay?.clear(); speedTrails.reset() }
            syncSpeedEffects(); needsDisplay = true
        }
    }
    var reduceMotion = false {
        didSet {
            if reduceMotion { speedTrails.reset() }
            syncSpeedEffects(); needsDisplay = true
        }
    }
    var reduceFlashes = false {
        didSet {
            if reduceFlashes {
                hdrOverlay?.clearExplosions()
                if speedTrails.isRewinding { speedTrails.reset() }
            }
            needsDisplay = true
        }
    }
    private var usesSpeedEffects: Bool { hdEffectsEnabled && !reduceMotion && isFastForward }
    private var usesTrails: Bool {
        hdEffectsEnabled && !reduceMotion && (isFastForward || (!reduceFlashes && speedTrails.isRewinding))
    }
    private func rewindActors(_ game: Lemmings2Runtime?) -> [SpeedTrails.Actor] {
        (game?.lemmings ?? []).filter { $0.active }.map {
            .init(id: $0.id, position: CGPoint(x: $0.x, y: $0.y), movement: $0.state.rawValue)
        }
    }
    func prepareRewindEffects() { speedTrails.prepareRewind(actors: rewindActors(game)) }
    func finishRewindEffects(_ restored: Lemmings2Runtime) {
        guard hdEffectsEnabled, !reduceMotion, !reduceFlashes else { return }
        speedTrails.finishRewind(tick: restored.tick, actors: rewindActors(restored)) { [weak self] in
            self?.needsDisplay = true
        }
        needsDisplay = true
    }
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
    let startCountdown = FreshLevelCountdown()
    var gameplayCursorStyle: GameplayCursorStyle = .modern { didSet { needsDisplay = true } }
    var showReticleCount = false
    var lemmingSelectionStyle: LemmingSelectionStyle = .modern { didSet { needsDisplay = true } }
    var skillCursorIconSize: SkillCursorIconSize = .one
    var favorApproachingLemmings = true
    var favorBombBlockers = true
    var favorBuilders = true
    var onSpeedPress: ((TimeInterval, Int) -> Void)?
    var onSpeedRelease: ((TimeInterval) -> Void)?
    var onSpeedStep: ((Int, TimeInterval) -> Void)?
    var isFastForward = false { didSet { syncSpeedEffects() } }
    var fullScreenHDRFlashes = true { didSet { if !fullScreenHDRFlashes { hdrOverlay?.clearExplosions() } } }
    private let speedTrails = SpeedTrails()
    private var hdrOverlay: ExplosionHDRView?
    private(set) var selectionEffect: LemmingSelectionEffect?
    private var selectionFade = SelectionFade<Int>()
    private var selectionOpacity: CGFloat = 1
    private var selectionWasFading = false
    func advanceSelectionFade(at now: Double) {
        let fading = selectionFade.isFading(at: now)
        if fading || selectionWasFading { needsDisplay = true }
        selectionWasFading = fading
    }
    private(set) var rescueAuras: [LemmingSelectionEffect] = []
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
        let active = usesSpeedEffects && window != nil
        hdrOverlay?.setSuperSpeed(active,
            in: CGRect(x:origin.x,y:origin.y,width:visibleWidth*zoom,height:192*zoom),immediate:!active, multiplier: speedMultiplier)
    }
    private var explosionTimeline = PixelExplosionTimeline()
    func flashExplosions(_ game: Lemmings2Runtime) {
        explosionTimeline.update(tick: game.tick, bursts: PixelExplosion.lemmings2(game))
        guard hdEffectsEnabled, !reduceFlashes else { return }
        let points = game.blastFlashes.map { (x: $0.x + 17, y: $0.y + 20) }
            + game.lemmings.filter { $0.state == .exploding && $0.age == 16 }.map { (x: $0.x, y: $0.y - 6) }
        guard !points.isEmpty else { return }
        let cores = points.map { CGRect(x: $0.x - 3, y: $0.y - 3, width: 6, height: 6) }
        hdrOverlay?.pulse(cores: cores, fullScreen: fullScreenHDRFlashes) { [weak self] world in
            guard let self else { return nil }
            return self.precisionLens.display(CGRect(
                x: self.origin.x + (world.minX - self.cameraX) * self.zoom,
                y: self.origin.y + (world.minY - self.cameraY) * self.zoom * 1.2,
                width: world.width * self.zoom, height: world.height * self.zoom * 1.2))
        }
    }
    private var explosion: Lemmings2Explosion?
    func load(level: Lemmings2Level, style: Lemmings2Style, sprites bank: Lemmings2Sprites, intern: Lemmings2SpecialGraphics, explosion: Lemmings2Explosion, walker: Lemmings2Walker?, resetPresentation: Bool = true) throws {
        hotSeatGhostSprites.clear()
        if resetPresentation {
            explosionTimeline.reset()
            selectionFade.reset()
            hdrOverlay?.clear()
            isFastForward = false
            speedTrails.reset()
        }
        reloadArtwork = { [weak self] in
            try self?.load(level: level, style: style, sprites: bank, intern: intern,
                           explosion: explosion, walker: walker, resetPresentation: false)
        }
        terrainCategory = .lemmings2Terrain(tribe: level.style)
        self.explosion = explosion
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        let resolved = try Lemmings2Objects(level: level, style: style)
        terrainRevision = nil
        panelSource = nil
        objects = []
        for (name, frames) in bank.animations {
            sprites[name] = frames.map { frame in
                (image(width: frame.width, height: frame.height, pixels: frame.pixels, palette: style.palette, opaque: frame.opaque), frame.x, frame.y)
            }
        }
        for (name,index) in [(L10n.text("LASER"),16),(L10n.text("FLAME"),17),(L10n.text("ROCKET"),8),(L10n.text("JET"),22),(L10n.text("STONE"),7),(L10n.text("SPEAR"),6),(L10n.text("ARROW"),2),(L10n.text("CHAIN"),5),(L10n.text("HOOK"),11),(L10n.text("SMOKE"),21),(L10n.text("EXPLOSION"),10),(L10n.text("COUNTDOWN"),15)] {
            sprites[name] = try intern.animation(index).map { frame in
                (image(width:frame.width,height:frame.height,pixels:frame.pixels,palette:style.palette,opaque:frame.opaque,category:.mechanical),frame.x,frame.y)
            }
        }
        if let walker {
            sprites["WALKER"] = walker.frames.map { frame in
                (image(width:frame.width,height:frame.height,pixels:frame.pixels,palette:style.palette,opaque:frame.opaque,category:.lemmings2Walker),frame.x,frame.y)
            }
        }
        sprites["BALLOON"] = try intern.animation(0).map { frame in
            (image(width:frame.width,height:frame.height,pixels:frame.pixels,palette:style.palette,opaque:frame.opaque,category:.mechanical),frame.x,frame.y)
        }
        sprites["PARACHUTE"] = try intern.animation(19).map { frame in
            (image(width:frame.width,height:frame.height,pixels:frame.pixels,palette:style.palette,opaque:frame.opaque,category:.mechanical),frame.x,frame.y)
        }
        for part in resolved.parts where !part.frames.isEmpty {
                let frames = part.frames.map {
                    (image: image(width: $0.width, height: $0.height, pixels: $0.pixels, palette: style.palette,
                          opaque: $0.opaque, category: part.type == 6 ? .liquid : .mechanical), x: $0.x, y: $0.y)
                }
                objects.append((part.objectIndex, part.type, part.x, part.y, part.type == 2, part.component.graphicsFlags & 0x10 != 0, part.component.graphicsFlags & 0x20 != 0, frames))
        }
        game = nil
        resetCamera(level: level)
    }
    func resetCamera(level: Lemmings2Level) {
        cameraBounds = (CGFloat(level.minimumScreenX), CGFloat(level.minimumScreenY),
                        CGFloat(level.maximumScreenX), CGFloat(level.maximumScreenY))
        cameraX = min(cameraBounds.right, max(cameraBounds.left, CGFloat(level.screenX)))
        cameraY = min(cameraBounds.bottom, max(cameraBounds.top, CGFloat(level.screenY)))
    }
    func update(_ game: Lemmings2Runtime) {
        explosionTimeline.update(tick: game.tick, bursts: PixelExplosion.lemmings2(game))
        if game.tick < (self.game?.tick ?? 0) { selectionFade.reset() }
        if terrainRevision != game.terrainRevision || game.tick < (self.game?.tick ?? 0) {
            terrain = image(width: game.configuration.width, height: game.configuration.height,
                            pixels: game.pixels, palette: game.configuration.palette, category: terrainCategory)
            terrainRevision = game.terrainRevision
        }
        self.game = game
        updateSpeedTrails()
        clampCamera()
        needsDisplay = true
    }
    func setPanel(_ panel: SequelIndexedImage) {
        if let previous = panelSource, previous.width == panel.width, previous.height == panel.height,
            previous.pixels == panel.pixels, previous.palette == panel.palette { return }
        panelSource = panel
        let colour = Int(Lemmings2Panel.backgroundIndex) * 4
        panelBackground = NSColor(deviceRed: CGFloat(panel.palette[colour]) / 255,
            green: CGFloat(panel.palette[colour + 1]) / 255,
            blue: CGFloat(panel.palette[colour + 2]) / 255, alpha: 1)
        self.panel = image(width: panel.width, height: panel.height, pixels: panel.pixels, palette: panel.palette, category: .architectural)
        needsDisplay = true
    }
    private func drawImage(_ image: NSImage, x: CGFloat, y: CGFloat, mirrored: Bool = false) {
        let rect = NSRect(x: origin.x + (x - cameraX) * zoom, y: origin.y + (y - cameraY) * zoom * 1.2,
                          width: image.size.width * zoom, height: image.size.height * zoom * 1.2)
        bitmapCache.draw(image, in: rect, mirrored: mirrored)
    }
    private func updateSpeedTrails() {
        if speedTrails.isRewinding {
            speedTrails.update(tick: game?.tick ?? 0,
                enabled: hdEffectsEnabled && !reduceMotion && !reduceFlashes, actors: [])
            if speedTrails.isRewinding { return }
        }
        let actors: [SpeedTrails.Actor] = usesSpeedEffects ? (game?.lemmings ?? []).compactMap { lem in
            guard lem.active else { return nil }
            switch lem.state {
                case .falling, .floating, .parachuting, .climbing, .rockClimbing, .hoisting, .ballooning,
                     .walking, .running, .jumping, .hopping, .swimming, .skiing, .skiingAir,
                     .skating, .sliding, .rolling, .rollingAir, .superFlying, .jetPacking,
                     .flyingIcarus, .hangGliding, .carpetFlying, .surfing, .kayaking,
                     .cannonFlying, .diving, .poleVaulting, .magnoBooting, .shimming, .shimmyJump:
                    return .init(id: lem.id, position: CGPoint(x: lem.x, y: lem.y), movement: lem.state.rawValue)
                default: return nil
            }
        } : []
        speedTrails.update(tick: game?.tick ?? 0, enabled: usesSpeedEffects, actors: actors)
    }
    private func drawLemmings(_ game: Lemmings2Runtime, ghostsOnly: Bool, hotSeatColour: ReplayGhostColour? = nil) {
        let palette = game.configuration.palette
        var selectedID = !ghostsOnly && hotSeatColour == nil && !GameCursor.gameplaySuppressed
            ? highlightedLemmingID : nil
        if !ghostsOnly && hotSeatColour == nil {
            if lemmingSelectionStyle == .modern, !GameCursor.gameplaySuppressed {
                let now = ProcessInfo.processInfo.systemUptime
                selectionFade.set(selectedID, at: now)
                let selection = selectionFade.sample(at: now)
                selectedID = selection?.value
                selectionOpacity = selection?.opacity ?? 1
            } else { selectionFade.reset() }
        }
        var selectedSprite: (pixels: CGImage, rect: CGRect, mirrored: Bool)?
        for lem in game.lemmings where lem.active && lem.state != .trapped {
            let motion = ghostsOnly ? speedTrails.motion(actor: lem.id) : .zero
            if ghostsOnly && motion == .zero { continue }
            let name: String
            let offsetX: Int, offsetY: Int, phase: Int
            var directional = true
            var mirrored = false
            // PROCESS 7726 state geometry plus each native frame's L2VL
            // anchor. Cropped frames must not move the feet between frames.
            switch lem.state {
            case .walking where sprites["WALKER"] != nil:
                name = L10n.text("WALKER"); offsetX = -2; offsetY = -10
                phase = Lemmings2Walker.phase(x:lem.x,direction:lem.direction); directional = false
            case .exiting:
                let tribe = game.configuration.tribe
                name = String(format:"LM%02X",0x50+(tribe == 9 ? 8 : tribe))
                offsetX = -7; offsetY = -[13,10,12,13,13,11,15,9,11,9,13,10][tribe]
                phase = lem.age; directional = false
            case .teleporting:
                name = "LM81"; offsetX = -8; offsetY = -12; phase = min(26,lem.pose); directional = false
            case .switchingValve:
                name = "LM82"; offsetX = -8; offsetY = -9; phase = lem.age; directional = false
            case .trapDying:
                name = String(format:"LM%02X",lem.deathSprite); offsetX = -8
                offsetY = -([126:16,127:15,128:10][lem.deathSprite] ?? 10); phase = lem.age; directional = false
            case .cannonLoading, .cannonFlying:
                if lem.state == .cannonLoading && lem.pose == 44 { continue }
                name = "LM5C"; offsetX = -9; offsetY = -10; phase = lem.pose; directional = false
            case .catapultLoading:
                name = "LM6E"; offsetX = -7; offsetY = -12; phase = lem.pose; directional = false
            case .chainRiding:
                name = "LM4F"; offsetX = -7; offsetY = -12; phase = lem.pose
            case .superFlying:
                name = "LM25"; offsetX = lem.superFlight?.horizontal == true ? -7 : -9
                offsetY = lem.superFlight?.horizontal == true ? -8 : -16; phase = lem.pose; directional = false
            case .arching:
                name = "LM05"; offsetX = lem.age < 16 ? (lem.direction > 0 ? -6 : -11) : -8
                offsetY = -16; phase = lem.pose; directional = lem.age < 16
            case .skiing, .skiingAir:
                name = "LM1E"; offsetX = lem.direction > 0 ? -7 : -8; offsetY = -10; phase = lem.pose
            case .poleVaulting:
                name = "LM20"; offsetX = -7; offsetY = -11; phase = lem.pose
            case .poleShrugging:
                name = "LM6C"; offsetX = -7; offsetY = -9; phase = lem.age
            case .magnoBooting:
                name = "LM19"; offsetX = -7; offsetY = -16; phase = lem.pose
            case .throwing:
                name = "LM10"; offsetX = -7; offsetY = -10; phase = lem.pose
            case .spearing:
                name = "LM1B"; offsetX = -7; offsetY = -9; phase = lem.pose
            case .carpetFlying:
                name = "LM0E"; offsetX = -8; offsetY = -10; phase = lem.age < 16 ? lem.age : 16+(lem.age-16)%12
            case .surfing:
                name = "LM26"; offsetX = -8; offsetY = -14; phase = lem.pose
            case .sliding:
                name = "LM29"; offsetX = lem.direction > 0 ? -6 : -9
                offsetY = [-13,-13,-13,-13,-13,-12,-9,-7,-7,-9,-9,-9][min(11,lem.pose)]; phase = lem.pose
            case .hanging:
                name = "LM84"; offsetX = lem.direction > 0 ? -8 : -7; offsetY = -9; phase = lem.age
            case .climbingTransfer:
                name = "LM85"; offsetX = lem.direction > 0 ? -7 : -8; offsetY = -11; phase = lem.age
            case .skating:
                name = "LM0A"; offsetX = -7; offsetY = -9; phase = lem.pose
            case .slipping:
                name = "LM6F"; offsetX = lem.direction > 0 ? -8 : -7; offsetY = -10; phase = lem.age % 8
            case .iceRecovering:
                name = "LM6D"; offsetX = -7; offsetY = -10; phase = lem.pose
            case .twisting:
                name = "LM2E"; offsetX = -8; offsetY = -11; phase = lem.age % 16; directional = false
            case .jetPacking:
                name = "LM2B"; offsetX = -7; offsetY = -10; phase = lem.pose; directional = false
            case .rolling, .rollingAir:
                name = "LM0D"; offsetX = -8; offsetY = -10; phase = lem.pose
            case .shimmyJump, .shimming:
                name = "LM2C"; offsetX = lem.direction > 0 ? -7 : -8; offsetY = -9
                let sequence = lem.runner ? [0,0,1,1,2,2,2,3,3,3,4] : [0,1,2,2,3,3,4]
                phase = lem.state == .shimming ? lem.age : sequence[min(sequence.count-1,lem.age)]
            case .diving:
                name = "LM23"; offsetX = lem.direction > 0 ? -7 : -8; offsetY = -10
                let sequence = lem.runner ? [2,3,4,4,4,4,4,4,5,6,7,8] : [0,1,2,3,4,4,4,4,4,4,5,5,6,7,8]
                phase = sequence[min(sequence.count-1,lem.age)]
            case .drowning:
                name = "LM5D"; offsetX = -7; offsetY = -11; phase = lem.age; directional = false
            case .kayaking, .kayakPacking:
                name = "LM0B"; offsetX = -8; offsetY = -11
                phase = lem.state == .kayakPacking ? max(0,23-lem.age) : lem.age < 24 ? lem.age : 24+(lem.age-24)%16
            case .flyingIcarus:
                name = "LM31"; offsetX = -8; offsetY = -13; phase = lem.age % 16
            case .hangGliding:
                name = "LM32"; offsetX = lem.direction > 0 ? -8 : -7; offsetY = -7; phase = 0
            case .roping:
                name = "LM2D"; offsetX = -8; offsetY = -10; directional = false
                phase = lem.pose == 0 ? (lem.age < 9 ? lem.age : min(28,lem.age+9)) : lem.pose == 1 ? 33 : 44
            case .firingBazooka:
                name = "LM1A"; offsetX = -7; offsetY = -12; phase = lem.age
            case .firingMortar:
                name = "LM21"; offsetX = -7; offsetY = -9
                phase = lem.age < 13 ? lem.age : max(0,22-lem.age)
            case .rockClimbing:
                name = "LM2A"; offsetX = lem.direction > 0 ? -10 : -5; offsetY = -12
                phase = lem.pose * 16 + lem.age % 16
            case .hoisting:
                name = "LM7D"; offsetX = -8; offsetY = -9; phase = lem.age
            case .planting:
                name = "LM27"; offsetX = -8; offsetY = -10; phase = lem.age
            case .ballooning:
                name = "LM04"; offsetX = -7; offsetY = -10
                phase = lem.age < 17 ? lem.age : 9 + (lem.age - 9) % 8; directional = false
            case .filling, .sandPouring, .gluePouring:
                name = lem.state == .filling ? "LM03" : lem.state == .sandPouring ? "LM2F" : "LM30"
                offsetX = -8; offsetY = -15; phase = lem.age
            case .attracting:
                name = String(format:"LM%02X",95 + game.configuration.tribe)
                offsetX = -7; offsetY = -[10,12,9,10,9,13,10,10,9,9,9,12][game.configuration.tribe]
                phase = lem.age; directional = false
            case .dancing:
                name = String(format:"LM%02X",66 + game.configuration.tribe)
                offsetX = -7; offsetY = -[10,9,9,10,9,11,9,10,10,9,9,12][game.configuration.tribe]
                phase = lem.age; directional = false
            case .parachuting:
                name = "LM28"; offsetX = -8; offsetY = -12; phase = lem.age % 16; directional = false
            case .swimming:
                name = "LM0C"; offsetX = -8; offsetY = -6; phase = lem.age % 16
            case .leavingWater:
                name = "LM83"
                offsetX = lem.work == 1 ? (lem.direction > 0 ? -8 : -7) : (lem.direction > 0 ? -10 : -5)
                offsetY = (lem.age == 0 ? -3 : [-3,-3,-3,-4,-6,-8,-8,-8,-8,-8,-9,-9][min(11,lem.age-1)]) - (lem.work == 1 ? 8 : 0)
                phase = min(12, lem.age)
            case .blastBombing:
                name = "LM07"; offsetX = -7; offsetY = -10; phase = lem.age; directional = false
            case .lasering:
                name = "LM17"; offsetX = -8; offsetY = -16; phase = lem.age % 2
            case .flaming:
                name = "LM24"; offsetX = -8; offsetY = -16; phase = lem.age % 2
            case .scooping:
                name = "LM08"; offsetX = lem.direction > 0 ? -6 : -9; offsetY = -12; phase = lem.age % 20
            case .fencing:
                name = "LM1C"; offsetX = lem.direction > 0 ? -3 : -12; offsetY = -11; phase = lem.age % 16
            case .clubBashing:
                name = "LM0F"; offsetX = -7; offsetY = -10; phase = lem.age % 32
            case .stomping:
                name = "LM1D"; offsetX = -7
                // PROCESS 65cf adjusts the sprite anchor without moving its feet.
                offsetY = -9 - [0, 0, 1, 3, 3, 3, 1, 0][lem.age % 8]
                phase = lem.age % 8; directional = false
            case .running:
                name = "LM02"; offsetX = -7; offsetY = -11; phase = lem.age % 8
            case .hopping, .hopPreparing:
                name = lem.state == .hopPreparing ? "LM09" : "LM86"
                offsetX = -8; offsetY = lem.state == .hopPreparing ? -11 : -12
                phase = lem.state == .hopPreparing ? lem.age : [1,2,3,3,3,4][min(5, lem.age)]
            case .jumping:
                name = "LM01"; offsetX = -8; offsetY = -9
                let sequence = lem.runner ? [0, 0, 0, 0, 1, 2, 3, 3, 4] : [0, 0, 1, 2, 3, 4]
                phase = sequence[min(sequence.count - 1, lem.age)]
            case .tumbling:
                name = "LM41"; offsetX = -8; offsetY = -10; phase = lem.age % 8
            case .stunned:
                name = "LM42"; offsetX = -8; offsetY = -10; phase = lem.age
            case .digging:
                name = "LM11"; offsetX = -8; offsetY = -12; phase = lem.age % 16; directional = false
            case .climbing:
                name = "LM12"; offsetX = -8; offsetY = -13; phase = lem.age % 8
            case .building:
                name = "LM13"; offsetX = -8; offsetY = -13; phase = lem.age % 16
            case .stacking:
                name = "LM1F"; offsetX = lem.direction > 0 && (lem.work < 12 || lem.age >= 12) ? -9 : -8
                offsetY = lem.age % 16 >= 11 ? -9 : -11
                phase = lem.age % 32; directional = false
            case .platforming:
                name = "LM22"; offsetX = lem.direction > 0 ? -9 : -6; offsetY = -13; phase = lem.age
            case .platformerShrugging:
                name = "LM7C"; offsetX = lem.direction > 0 ? -9 : -7; offsetY = -13; phase = lem.age % 10
            case .bashing:
                name = "LM14"; offsetX = -7; offsetY = -10; phase = lem.age % 32
            case .mining:
                name = "LM15"; offsetX = -7; offsetY = -13; phase = lem.age % 24
            case .floating:
                name = "LM16"; offsetX = -7; offsetY = -16
                let frames = [1, 2, 3, 5, 5, 5, 5, 5, 5, 6, 7, 7, 6, 5, 4, 4]
                phase = frames[lem.age < 16 ? lem.age : 8 + (lem.age - 16) % 8]
            case .blocking:
                name = "LM33"; offsetX = -7; offsetY = -10; phase = lem.age % 16; directional = false
            case .falling:
                name = "LM40"; offsetX = -8; offsetY = -10; phase = lem.age % 4
            case .shrugging:
                name = "LM7B"; offsetX = lem.direction > 0 ? -9 : -8; offsetY = -13; phase = lem.age % 8
            case .exploding:
                if ghostsOnly || hotSeatColour != nil { continue }
                if lem.age >= 16 {
                    if lem.age == 16, let flash = sprites["EXPLOSION"]?.first {
                        drawImage(flash.image,x:CGFloat(lem.x-13+flash.x),y:CGFloat(lem.y-14+flash.y))
                    } else if let frames = explosion?.frames, frames.indices.contains(lem.age-17) {
                        for point in frames[lem.age-17] {
                            let colour = point.colour*4
                            NSColor(srgbRed:CGFloat(palette[colour])/255,green:CGFloat(palette[colour+1])/255,
                                    blue:CGFloat(palette[colour+2])/255,alpha:1).setFill()
                            NSRect(x:origin.x+(CGFloat(lem.x+point.x)-cameraX)*zoom,
                                   y:origin.y+(CGFloat(lem.y+point.y)-cameraY)*zoom*1.2,width:zoom,height:zoom*1.2).fill()
                        }
                    }
                    continue
                }
                name = "LM18"; offsetX = -7; offsetY = -10; phase = lem.age; directional = false
            default:
                // External installations without extracted walker images use
                // the walking poses in the original cannon animation.
                name = "LM5C"; offsetX = -9; offsetY = -10; phase = 6 + lem.age % 8
                directional = false; mirrored = lem.direction < 0
            }
            guard let frames = sprites[name], !frames.isEmpty else { continue }
            let framePhase = [.attracting, .dancing].contains(lem.state) ? phase % frames.count : phase
            let index = framePhase + (directional && lem.direction < 0 ? frames.count / 2 : 0)
            guard frames.indices.contains(index) else { continue }
            let sprite = frames[index]
            if ghostsOnly {
                let rect = CGRect(x: origin.x + (CGFloat(lem.x + offsetX + sprite.x) - cameraX) * zoom,
                    y: origin.y + (CGFloat(lem.y + offsetY + sprite.y) - cameraY) * zoom * 1.2,
                    width: sprite.image.size.width * zoom, height: sprite.image.size.height * zoom * 1.2)
                speedTrails.drawBehind(actor: lem.id, sprite: sprite.image, in: rect, motion: motion,
                    pixelSize: CGSize(width: zoom, height: zoom * 1.2), mirrored: mirrored)
                continue
            }
            if let hotSeatColour {
                let rect = CGRect(x: origin.x + (CGFloat(lem.x + offsetX + sprite.x) - cameraX) * zoom,
                    y: origin.y + (CGFloat(lem.y + offsetY + sprite.y) - cameraY) * zoom * 1.2,
                    width: sprite.image.size.width * zoom, height: sprite.image.size.height * zoom * 1.2)
                hotSeatGhostSprites.draw(sprite.image, key: "\(name)-\(index)", colour: hotSeatColour,
                    in: rect, mirrored: mirrored)
                continue
            }
            drawImage(sprite.image, x: CGFloat(lem.x + offsetX + sprite.x),
                y: CGFloat(lem.y + offsetY + sprite.y), mirrored: mirrored)
            let spriteRect = CGRect(x: origin.x + (CGFloat(lem.x + offsetX + sprite.x) - cameraX) * zoom,
                y: origin.y + (CGFloat(lem.y + offsetY + sprite.y) - cameraY) * zoom * 1.2,
                width: sprite.image.size.width * zoom, height: sprite.image.size.height * zoom * 1.2)
            let pixels = (assignmentPulse.target == lem.id || selectedID == lem.id)
                ? sprite.image.cgImage(forProposedRect: nil, context: nil, hints: nil) : nil
            if assignmentPulse.target == lem.id, let pixels {
                assignmentPulse.draw(sprite: pixels, in: spriteRect, scale: zoom,
                    reduceMotion: reduceMotion, reduceFlashes: reduceFlashes)
            }
            if selectedID == lem.id, let pixels {
                selectedSprite = (pixels, spriteRect, mirrored)
            }
            if let ticks = lem.bombTicks, let numbers = sprites["COUNTDOWN"], numbers.indices.contains(ticks >> 4) {
                let number = numbers[ticks >> 4]
                let x = [.walking,.running,.falling].contains(lem.state) ? -8 : offsetX
                drawImage(number.image,x:CGFloat(lem.x+x+number.x),y:CGFloat(lem.y+offsetY-7+number.y))
            }
            if let held = lem.heldProjectile,
               let frames = sprites[held.kind == .spear ? L10n.text("SPEAR") : L10n.text("STONE")], frames.indices.contains(held.frame) {
                let part = frames[held.frame], offset = held.kind == .spear ? 7 : 0
                drawImage(part.image,x:CGFloat(held.x-offset+part.x),y:CGFloat(held.y-offset+part.y))
            }
            if lem.state == .jetPacking, let jet = sprites["JET"], !jet.isEmpty {
                let part = jet[lem.age % jet.count]
                drawImage(part.image,x:CGFloat(lem.x-7+part.x),y:CGFloat(lem.y-2+part.y))
            }
            if lem.state == .lasering, let beam = sprites["LASER"], !beam.isEmpty, lem.work >= 0 {
                let part = beam[lem.age % beam.count]
                for segment in 0...lem.work {
                    drawImage(part.image,x:CGFloat(lem.x-8+2*lem.direction+part.x),
                              y:CGFloat(lem.y-17-segment*8+part.y))
                }
            }
            if lem.state == .flaming, let flame = sprites["FLAME"], flame.count == 8 {
                let part = flame[lem.age % 4 + (lem.direction < 0 ? 4 : 0)]
                drawImage(part.image,x:CGFloat(lem.x-(lem.direction < 0 ? 32 : 0)+part.x),y:CGFloat(lem.y-12+part.y))
            }
            if lem.state == .ballooning, let balloon = sprites["BALLOON"], !balloon.isEmpty {
                let part = balloon[min(6,lem.age) % balloon.count]
                drawImage(part.image,x:CGFloat(lem.x-7+part.x),y:CGFloat(lem.y-min(32,25+lem.age)+part.y))
            }
            if lem.state == .parachuting, let canopy = sprites["PARACHUTE"], !canopy.isEmpty {
                let part = canopy[lem.age % canopy.count]
                drawImage(part.image,x:CGFloat(lem.x-8+part.x),y:CGFloat(lem.y-17+part.y))
            }
            if let ticks = lem.bombTicks, sprites["COUNTDOWN"] == nil {
                let text = String(max(1, (ticks + 14) / 15))
                GameTypography.annotation(text, at: NSPoint(x: origin.x + (CGFloat(lem.x) - cameraX) * zoom,
                    y: origin.y + (CGFloat(lem.y - 16) - cameraY) * zoom * 1.2), palette: .blue)
            }
        }
        if hotSeatColour == nil, lemmingSelectionStyle == .modern, let selectedSprite {
            selectionEffect = LemmingSelectionEffect(sprite: selectedSprite.pixels,
                rect: precisionLens.display(selectedSprite.rect), clipRect: gameplayRect,
                mirrored: selectedSprite.mirrored,
                time: reduceMotion || reduceFlashes ? nil : Double(game.tick) / Lemmings2Runtime.ticksPerSecond)
            selectionEffect?.opacity = selectionOpacity
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        selectionEffect = nil
        defer {
            if let selectionEffect {
                LemmingSelectionRenderer.draw(selectionEffect)
            }
        }
        layoutTimeline()
        defer { if !readOnlyReplay { timeline.draw() } }
        defer { startCountdown.draw(in: gameplayRect) }
        defer {
            if lemmingSelectionStyle == .obvious, !GameCursor.gameplaySuppressed,
               let id = highlightedLemmingID,
               let lem = game?.lemmings.first(where: { $0.id == id && $0.active }) {
                let centre = precisionLens.display(CGPoint(x: origin.x + (CGFloat(lem.x) - cameraX) * zoom,
                    y: origin.y + (CGFloat(lem.y - 6) - cameraY) * zoom * 1.2))
                let tint = assignmentHighlight.target != nil ? NSColor.systemYellow
                    : GameCursor.targetTint(eligible: game?.canAssign(slot: selectedSkillSlot, to: id) == true, occupied: true)
                LemmingSelectionGlow.draw(at: centre, scale: zoom, tint: tint, animated: !reduceMotion && !reduceFlashes)
            }
            if !GameCursor.gameplaySuppressed, let point = cursorPoint(), gameplayRect.contains(point) {
                if showReticleCount {
                    let centres = (game?.lemmings ?? []).filter { $0.active }.map {
                        precisionLens.display(CGPoint(x: origin.x + (CGFloat($0.x) - cameraX) * zoom,
                                y: origin.y + (CGFloat($0.y - 5) - cameraY) * zoom * 1.2))
                    }
                    let count = SkillCursorBadge.count(centres: centres, at: point, scale: zoom)
                    SkillCursorBadge.drawCount(count, at: point, scale: zoom, size: skillCursorIconSize, icon: skillCursorIconSize == .none ? nil : skillBadge, in: gameplayRect)
                }
                let target = pointerTarget(slot: selectedSkillSlot)
                let eligible = pointerSelectionEnabled && target.map { game?.canAssign(slot: selectedSkillSlot, to: $0) == true } == true
                GameCursor.drawPlayfieldPointer(at: point, scale: zoom,
                    tint: GameCursor.targetTint(eligible: eligible, occupied: target != nil),
                    original: gameplayCursorStyle == .original, occupied: target != nil, eligible: eligible)
                if pointerSelectionEnabled {
                    let remaining = game.flatMap { game -> Int? in
                        guard game.supplies.indices.contains(selectedSkillSlot) else { return nil }
                        return game.supplies[selectedSkillSlot]
                    }
                    SkillCursorBadge.draw(icon: skillBadge, index: selectedSkillSlot, at: point,
                        scale: zoom, tint: .systemGreen, size: skillCursorIconSize, reduceMotion: reduceMotion || reduceFlashes,
                        remaining: remaining, in: gameplayRect)
                }
            }
            let badgeScale: CGFloat = bounds.width >= 960 ? 2 : 1
            let badgeSize = precisionStatus.draw(at: CGPoint(x: gameplayRect.minX + 12,
                y: gameplayRect.minY + 12), scale: badgeScale, opacity: precisionStatusOpacity)
            if let focusNotice { GameTypography.annotation(focusNotice,
                at: CGPoint(x: gameplayRect.minX + 12, y: gameplayRect.minY + 16 + badgeSize.height)) }
            if !deathCountdownText.isEmpty { GameTypography.annotation(deathCountdownText,
                at: statusReadoutFrame.origin, palette: .blue) }
            if let game {
                GameTypography.annotation(L10n.text("Saved \(game.saved * 100 / max(1, game.configuration.total))%"),
                    at: CGPoint(x: statusReadoutFrame.minX, y: statusReadoutFrame.minY + 18), palette: .blue)
            }
            if let origin = rewindOriginTick, origin > rewindCurrentTick {
                RewindTransportCue.draw(origin: CGPoint(x: gameplayRect.minX + 12,
                    y: gameplayRect.minY + 16 + badgeSize.height),
                    currentTick: rewindCurrentTick, originTick: origin, scale: zoom)
            }
        }
        if turnBadge.superview == nil { addSubview(turnBadge) }
        turnBadge.place(in: CGRect(x: origin.x, y: origin.y, width: visibleWidth * zoom, height: 192 * zoom))
        updateSpeedTrails()
        NSColor.black.setFill(); bounds.fill()
        guard let game, let terrain else { return }
        speedTrails.draw(enabled: usesTrails,
            in: NSRect(x: origin.x, y: origin.y, width: visibleWidth * zoom, height: 192 * zoom)) {
            drawWorld(game, terrain: terrain)
        }
        if let context = NSGraphicsContext.current?.cgContext {
            RescueCelebration.draw(in: CGRect(x: origin.x, y: origin.y, width: visibleWidth * zoom, height: 192 * zoom),
                                   amount: completionGlowAmount, context: context)
        }
        FailureMoodOverlay.draw(
            in: CGRect(x: origin.x, y: origin.y, width: visibleWidth * zoom, height: 192 * zoom),
            amount: failureMoodAmount)
        if let panel {
            panelBackground.setFill()
            NSRect(x: bounds.minX, y: origin.y + 192 * zoom, width: bounds.width, height: 48 * zoom).fill()
            panel.draw(in: NSRect(x: panelX, y: origin.y + 192 * zoom, width: 320 * zoom, height: 48 * zoom),
                       from: .zero, operation: .sourceOver, fraction: readOnlyReplay ? 0.45 : 1, respectFlipped: true,
                       hints: [.interpolation: NSImageInterpolation.none.rawValue])
            if variableSpeedEnabled { SpeedPanelControls.draw(in: speedRect, label: speedLabel, active: isFastForward) }
        }
    }
    private var speedRect: CGRect { CGRect(x: panelX + 288 * zoom, y: origin.y + 216 * zoom, width: 32 * zoom, height: 24 * zoom) }
    private func drawBackgroundImage(_ image: NSImage, x: CGFloat, y: CGFloat) {
        drawImage(image, x: x, y: y)
    }
    private func drawWorld(_ game: Lemmings2Runtime, terrain: NSImage) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: origin.x, y: origin.y, width: visibleWidth * zoom, height: 192 * zoom)).addClip()
        precisionLens.applyToCurrentGraphicsContext()
        drawBackgroundImage(terrain, x: 0, y: 0)
        if usesTrails { drawLemmings(game, ghostsOnly: true) }
        for object in objects where !object.frames.isEmpty {
            let machine = game.machines.first { $0.id == object.id }
            let movement = machine.map { object.special ? $0.displacement : 0 } ?? 0
            let frame = machine.map { object.special ? $0.frame % object.frames.count : (($0.displacement % object.frames.count) + object.frames.count) % object.frames.count }
                ?? ([4, 9, 10, 12].contains(object.type) ? (game.objectFrames[object.id] ?? 0) % object.frames.count
                : object.entrance ? min(object.frames.count - 1, max(0, game.tick - 20))
                : (object.animated ? game.tick / 2 % object.frames.count : 0))
            let sprite = object.frames[frame]
            drawBackgroundImage(sprite.image, x: CGFloat(object.x + movement + sprite.x), y: CGFloat(object.y + sprite.y))
        }
        if let smoke = sprites["SMOKE"] {
            for machine in game.machines where machine.kind == .cannon && machine.delay > 0 && smoke.count == 8 {
                let puff = smoke[machine.delay & 7]
                drawImage(puff.image,x:CGFloat(machine.x+1+puff.x),y:CGFloat(machine.y+14+puff.y))
            }
        }
        if let links = sprites["CHAIN"] {
            for chain in game.chains { for link in chain.links where links.indices.contains(link.frame) {
                let part = links[link.frame]
                drawImage(part.image,x:CGFloat(link.x+part.x),y:CGFloat(link.y+part.y))
            } }
        }
        for shot in game.projectiles {
            let name = shot.kind == .arrow ? L10n.text("ARROW") : shot.kind == .stone ? L10n.text("STONE") : shot.kind == .spear ? L10n.text("SPEAR") : L10n.text("ROCKET")
            if let frames = sprites[name], frames.indices.contains(shot.frame) {
                let part = frames[shot.frame]
                let offset = shot.kind == .stone ? 0 : (shot.kind == .spear || shot.kind == .arrow) ? 7 : 1
                drawImage(part.image,x:CGFloat(shot.x-offset+part.x),y:CGFloat(shot.y-offset+part.y))
            }
        }
        if let flash = sprites["EXPLOSION"]?.first {
            for point in game.blastFlashes {
                drawImage(flash.image,x:CGFloat(point.x+flash.x),y:CGFloat(point.y+flash.y))
            }
        }
        let palette = game.configuration.palette
        let macEffects = SequelArtworkPreference.enabled
        let ropeArt = macEffects ? SequelEffectArtwork.markImage(palette: palette, colourIndex: 4, kind: .rope) : nil
        let particleArt = macEffects ? SequelEffectArtwork.markImage(palette: palette, colourIndex: 3, kind: .particle) : nil
        let poleArt = macEffects ? SequelEffectArtwork.markImage(palette: palette, colourIndex: 4, kind: .pole) : nil
        func drawPoint(_ x: Int, _ y: Int, artwork: NSImage?) {
            let rect = NSRect(x: origin.x + (CGFloat(x) - cameraX) * zoom,
                y: origin.y + (CGFloat(y) - cameraY) * zoom * 1.2,
                width: zoom, height: zoom * 1.2)
            if let artwork {
                artwork.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1,
                    respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
            } else { rect.fill() }
        }
        NSColor(red:CGFloat(palette[12])/255,green:CGFloat(palette[13])/255,blue:CGFloat(palette[14])/255,alpha:1).setFill()
        if let rope = game.rope {
            if let frames = sprites["HOOK"], frames.indices.contains(rope.frame) {
                let hook = frames[rope.frame]
                drawImage(hook.image,x:CGFloat(rope.x-7+hook.x),y:CGFloat(rope.y-7+hook.y))
            }
            NSColor(red:CGFloat(palette[16])/255,green:CGFloat(palette[17])/255,blue:CGFloat(palette[18])/255,alpha:1).setFill()
            for point in rope.points {
                drawPoint(point.x, point.y, artwork: ropeArt)
            }
            NSColor(red:CGFloat(palette[12])/255,green:CGFloat(palette[13])/255,blue:CGFloat(palette[14])/255,alpha:1).setFill()
        }
        for particle in game.fillParticles {
            drawPoint(particle.x, particle.y, artwork: particleArt)
        }
        let poleColour = game.configuration.palette
        NSColor(srgbRed:CGFloat(poleColour[16])/255,green:CGFloat(poleColour[17])/255,
                blue:CGFloat(poleColour[18])/255,alpha:1).setFill()
        for lem in game.lemmings where lem.state == .poleVaulting {
            for point in lem.pole {
                drawPoint(point.x, point.y, artwork: poleArt)
            }
        }
        for frame in visibleHotSeatFrames(at: game.tick) {
            if case .lemmings2(let ghost) = frame.state {
                drawLemmings(ghost, ghostsOnly: false, hotSeatColour: frame.colour)
            }
        }
        drawLemmings(game, ghostsOnly: false)
        let bursts = game.blastFlashes.map { (x: $0.x + 17, y: $0.y + 20, phase: 0) }
            + game.lemmings.filter { $0.state == .exploding && (16..<18).contains($0.age) }.map { (x: $0.x, y: $0.y - 6, phase: $0.age - 16) }
        for burst in bursts where hdEffectsEnabled && !reduceFlashes {
            ExplosionHDR.drawCore(at: CGPoint(x: origin.x + (CGFloat(burst.x) - cameraX) * zoom,
                y: origin.y + (CGFloat(burst.y) - cameraY) * zoom * 1.2),
                pixel: CGSize(width: zoom, height: zoom * 1.2), phase: burst.phase)
        }
        // The bomber already draws its authored 52-frame point sequence above.
        // Other blast sources use the same shared pixel presentation as Classic/L3.
        for burst in explosionTimeline.bursts where burst.id < 0 {
            ExplosionHDR.drawSpray(burst, at: game.tick,
                origin: CGPoint(x: origin.x + (CGFloat(burst.x) - cameraX) * zoom,
                    y: origin.y + (CGFloat(burst.y) - cameraY) * zoom * 1.2),
                pixel: CGSize(width: zoom, height: zoom * 1.2))
        }
        NSGraphicsContext.restoreGraphicsState()
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let p = convert(event.locationInWindow, from: nil)
        layoutTimeline()
        if timeline.click(at: p) { return }
        let source = gameplayRect.contains(p) ? precisionLens.source(p) : p
        let x = (source.x - origin.x) / zoom
        let y = (source.y - origin.y) / (zoom * 1.2)
        guard x >= 0, x < visibleWidth, y >= 0, y < 200 else { return }
        if y < 160 { onClick?(Int(x + cameraX), Int(y + cameraY)); onPointer?(Int(x + cameraX), Int(y + cameraY), true) }
        else if variableSpeedEnabled, let part = SpeedPanelControls.part(at: p, in: speedRect) {
            if part == 0 { onSpeedPress?(event.timestamp, event.clickCount) }
            else { onSpeedStep?(part, event.timestamp) }
        }
        else if let slot = Lemmings2Control.slot(x: Int(floor(x - CGFloat(viewport.panelX))), y: Int(y)) { onPanel?(slot, event.clickCount, event.timestamp) }
    }
    private func trackPointer(_ event: NSEvent, held: Bool) {
        controllerPointer = nil
        assignmentHighlight.clear()
        trackPointer(at:convert(event.locationInWindow,from:nil),held:held)
    }
    private func trackPointer(at p: NSPoint, held: Bool) {
        if navigationFrame?.contains(p) == true { GameCursor.controlCursor(scale: zoom).set(); onRelease?(); return }
        guard gameplayRect.contains(p) else { onRelease?(); return }
        let source = precisionLens.source(p)
        let x = (source.x-origin.x)/zoom, y = (source.y-origin.y)/(zoom*1.2)
        guard x >= 0, x < visibleWidth, y >= 0, y < 160 else { onRelease?(); return }
        onPointer?(Int(x+cameraX),Int(y+cameraY),held)
    }
    override func mouseDragged(with event: NSEvent) { trackPointer(event,held:true); onHover?() }
    override func mouseUp(with event: NSEvent) { onSpeedRelease?(event.timestamp); trackPointer(event,held:false); onRelease?() }
    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { super.keyDown(with: event); return }
        if event.isARepeat, [" ", "p"].contains(event.charactersIgnoringModifiers ?? "") { return }
        switch event.keyCode {
        case 123: pan(x: -24, y: 0)
        case 124: pan(x: 24, y: 0)
        case 125: pan(x: 0, y: 16)
        case 126: pan(x: 0, y: -16)
        default: if let text = event.charactersIgnoringModifiers { onKey?(text) }
        }
    }
    private var controllerPointer: CGPoint?
    func moveControllerPointer(_ dx: Double, _ dy: Double) {
        let p = controllerPointer ?? CGPoint(x: origin.x + visibleWidth * zoom / 2, y: origin.y + 80 * zoom * 1.2)
        controllerPointer = CGPoint(x: max(origin.x, min(origin.x + visibleWidth * zoom - 1, p.x + dx * zoom)),
            y: max(origin.y, min(origin.y + 160 * zoom * 1.2 - 1, p.y + dy * zoom * 1.2)))
        assignmentHighlight.clear(); needsDisplay = true
    }
    func controllerPan(_ dx: Double, _ dy: Double) { assignmentHighlight.clear(); pan(x: dx, y: dy) }
    let assignmentHighlight = LemmingFocusHighlight()
    private let assignmentPulse = LemmingAssignmentPulse()
    private var assignmentPulseTask: Task<Void, Never>?
    private var selectedSkillSlot = 0
    private var skillBadge: NSImage?
    private var pointerSelectionEnabled = true
    private var focusNotice: String?
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
    func showFocusNotice(_ text: String) {
        focusNotice = text; needsDisplay = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.focusNotice = nil; self?.needsDisplay = true }
    }
    func pointerTarget(slot: Int) -> Int? {
        guard let game, let p = cursorPoint(), gameplayRect.contains(p) else { return nil }
        let source = precisionLens.source(p)
        let x = (source.x - origin.x) / zoom, y = (source.y - origin.y) / (zoom * 1.2)
        guard (0..<visibleWidth).contains(x), (0..<160).contains(y) else { return nil }
        return game.target(slot: slot, x: Int(x + cameraX), y: Int(y + cameraY), preferApproaching: favorApproachingLemmings,
            preferBombBlockers: favorBombBlockers, preferBuilders: favorBuilders)?.id
    }
    var inspectionSelectionAvailable: () -> Bool = { false }
    private var highlightedLemmingID: Int? {
        inspectionSelectionAvailable() ? inspectionPointerID
            : assignmentHighlight.target ?? (pointerSelectionEnabled ? pointerTarget(slot: selectedSkillSlot) : nil)
    }
    var inspectionPointerID: Int? {
        guard let game, let p = cursorPoint(), gameplayRect.contains(p) else { return nil }
        let source = precisionLens.source(p)
        let point = CGPoint(x: (source.x - origin.x) / zoom + cameraX,
            y: (source.y - origin.y) / (zoom * 1.2) + cameraY)
        return LemmingInspectionHover.nearestID(at: point,
            actors: game.lemmings.filter(\.active).map { ($0.id, $0.x, $0.y) })
    }
    private func cursorPoint() -> CGPoint? {
        guard let window else { return nil }
        let point = controllerPointer ?? capturedPointer ?? convert(window.mouseLocationOutsideOfEventStream, from: nil)
        return navigationFrame?.contains(point) == true ? nil : point
    }
    func focusLemming(_ id: Int) {
        guard let lem = game?.lemmings.first(where: { $0.id == id && $0.active }) else { return }
        cameraX = CGFloat(lem.x) - visibleWidth / 2; cameraY = CGFloat(lem.y) - 80
        clampCamera(); assignmentHighlight.show(id); needsDisplay = true
    }
    func centre(onEntrance: Bool) {
        guard let game, let target = onEntrance ? game.configuration.entrances.first : game.configuration.exits.first else { return }
        cameraX = CGFloat(target.x + target.width / 2) - CGFloat(visibleWidth) / 2
        cameraY = CGFloat(target.y + target.height / 2) - 80
        clampCamera(); needsDisplay = true
    }
    private func clampCamera() {
        guard let game else { return }
        if precisionLens.active {
            let camera = precisionLens.clampedCamera(CGPoint(x: cameraX, y: cameraY),
                playfield: gameplayRect, scaleX: zoom, scaleY: zoom * 1.2,
                level: CGRect(x: cameraBounds.left, y: cameraBounds.top,
                    width: max(0, min(cameraBounds.right + 320, CGFloat(game.configuration.width)) - cameraBounds.left),
                    height: max(0, min(cameraBounds.bottom + 160, CGFloat(game.configuration.height)) - cameraBounds.top)))
            cameraX = camera.x; cameraY = camera.y
            return
        }
        cameraX = CGFloat(viewport.clampedX(Double(cameraX), minimum: Double(cameraBounds.left),
            maximum: Double(cameraBounds.right), levelWidth: Double(game.configuration.width)))
        let bottom = max(cameraBounds.top, min(cameraBounds.bottom, CGFloat(game.configuration.height - 160)))
        cameraY = min(bottom, max(cameraBounds.top, cameraY))
    }
    private func pan(x: CGFloat, y: CGFloat) {
        guard game != nil else { return }
        cameraX += x
        cameraY += y
        clampCamera()
        if let window {
            trackPointer(at:capturedPointer ?? convert(window.mouseLocationOutsideOfEventStream,from:nil),
                         held:NSEvent.pressedMouseButtons & 1 != 0)
        }
        needsDisplay = true
        onHover?()
    }
    override func scrollWheel(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if gameplayRect.contains(point), game?.isComplete == false {
            switch precisionScroll.handle(event) {
            case .zoom(let action): onPrecisionScroll?(action, point); return
            case .consumed: return
            case .pan: break
            }
        }
        let horizontal = event.modifierFlags.contains(.shift) ? event.scrollingDeltaY : event.scrollingDeltaX
        pan(x: horizontal * 4, y: event.modifierFlags.contains(.shift) ? 0 : event.scrollingDeltaY * 4)
    }
}
#endif
