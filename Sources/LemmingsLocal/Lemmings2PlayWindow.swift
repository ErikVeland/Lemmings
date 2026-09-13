import AppKit
import NxlvKit

@MainActor final class Lemmings2PlayWindow: NSWindowController, NSWindowDelegate {
    var onReturnToLibrary: (() -> Void)?
    var onProgressChanged: (() -> Void)?
    var onCampaignCompleted: (() -> Void)?
    var onShowSettings: (() -> Void)?
    private var usesSharedWindow = false

    /// Attach the engine after loading succeeds, so a failed load leaves the current game intact.
    func attach(to host: NSWindow) {
        let content = window?.contentView
        window?.delegate = nil
        window?.contentView = nil
        window = host
        gameplayKeyboard?.bind(to: host)
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
    private var audioSettings = ClassicSettings()
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
    private var arcadeLevelSnapshot: ArcadeLevel?
    private var arcadeLevel: ArcadeLevel? {
        if let arcadeLevelSnapshot { return arcadeLevelSnapshot }
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
            game: "Lemmings 2 - " + Lemmings2Campaign.tribeNames[level.style], rules: rules,
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
    private var selectedSlot = 0
    private var ending: Lemmings2Ending?
    private var award: Lemmings2Award?
    private var hoverTribe: Int?
    private let progressKey: String
    private var level: Lemmings2Level { practiceLevel ?? campaign.current }

    init(root: URL, recovery: RunRecovery? = nil, expectedRecoveryEngine: String = RunRecovery.bundledEngine) throws {
        if let recovery {
            _ = try recovery.validated()
            guard recovery.l2 != nil, recovery.profileID == ArcadeStore.shared.playingProfileID, recovery.hotSeatID == ArcadeStore.shared.hotSeatID,
                recovery.engine == expectedRecoveryEngine else { throw RunRecoveryError.differentGame }
        }
        self.root = root
        practice = try Lemmings2Practice(root:root)
        assets = try Lemmings2FrontEnd(root: root)
        sounds = try Lemmings2SoundPlayer(root: root)
        campaign = try Lemmings2Campaign(root: root)
        sprites = try Lemmings2Sprites(data: Data(contentsOf: root.appendingPathComponent("VLEMMS.DAT")))
        masks = try Lemmings2TerrainMasks(root: root)
        intern = try Lemmings2SpecialGraphics(data:Data(contentsOf:root.appendingPathComponent("INTERN.DAT")))
        explosion = try Lemmings2Explosion(root:root)
        walker = (try? Data(contentsOf:root.appendingPathComponent("WALKER.DAT"))).flatMap { try? Lemmings2Walker(data:$0) }
        let bundled = (try? BundledGameResources.lemmings2())?.standardizedFileURL == root.standardizedFileURL
        progressKey = ArcadeStore.shared.progressKey("nativeL2Campaign.v1." + (bundled ? "bundled" : root.standardizedFileURL.path))
        if let data = UserDefaults.standard.data(forKey: progressKey),
           let saved = try? JSONDecoder().decode(Lemmings2Campaign.Progress.self, from: data) {
            try? campaign.restore(saved)
        }
        super.init(window: NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false))
        guard let window else { return }
        NotificationCenter.default.addObserver(self, selector: #selector(artworkChanged),
            name: SequelArtworkPreference.changed, object: nil)
        window.title = "Lemmings 2 — The Tribes"
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
        canvas.onClick = { [weak self] x, y in self?.assign(x, y) }
        canvas.onRelease = { [weak self] in self?.releasePointerInput() }
        canvas.onPointer = { [weak self] x, y, held in
            guard let self else { return }
            self.performRecoveryInput(.fan(x:x,y:y,active:held && self.fanSelected && !self.paused))
            self.performRecoveryInput(.aim(x:x,y:y,held:held && !self.fanSelected && !self.paused))
        }
        canvas.onPanel = { [weak self] slot, count, time in self?.panelAction(slot, clickCount: count, time: time) }
        canvas.onHover = { [weak self] in self?.refreshGame() }
        canvas.pointers = assets.pointers
        canvas.onKey = { [weak self] key in self?.key(key) }
        let keyboard = GameplayKeyboard(window: window)
        gameplayKeyboard = keyboard
        keyboard.active = { [weak self] in self?.screen == .playing && self?.game?.isComplete == false }
        keyboard.assignSelected = { [weak self] in
            guard let self, let id = self.canvas.assignmentHighlight.target ?? self.canvas.pointerTarget(slot: self.selected) else { return }
            if self.performRecoveryInput(.assign(slot: self.selected, lemming: id)) {
                self.assignmentFocus.record(id: id, skill: self.selected, tick: self.game?.tick ?? 0)
            }
            self.sounds.play(self.game?.drainSoundEvents() ?? []); self.refreshGame()
        }
        keyboard.togglePause = { [weak self] in self?.panelAction(8) }
        keyboard.movePointer = { [weak self] dx, dy in self?.canvas.moveControllerPointer(dx, dy) }
        keyboard.panCamera = { [weak self] dx, dy in self?.canvas.controllerPan(dx, dy) }
        keyboard.menuActive = { [weak self] in self?.screen == .menu && self?.game != nil }
        keyboard.menuKey = { [weak self] key in
            guard let self else { return }
            if key == "\u{1b}" { self.playFromMenu() } else { self.key(key) }
        }
        keyboard.focusUnassigned = { [weak self] direction in
            guard let self, let game = self.game else { return }
            guard let id = self.assignmentFocus.next(activeIDs: game.lemmings.filter(\.active).map(\.id), direction: direction) else {
                self.canvas.setAccessibilityLabel("No unassigned lemmings")
                self.canvas.showFocusNotice("No unassigned lemmings"); return
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
            }
            self.sounds.play(self.game?.drainSoundEvents() ?? []); self.refreshGame()
        }
        canvas.onSpeedPress = { [weak self] time, count in self?.speedControl.pointerDown(at: time, clickCount: count) }
        canvas.onSpeedRelease = { [weak self] time in self?.speedControl.release(.mouse, at: time) }
        canvas.onSpeedStep = { [weak self] direction, time in self?.speedControl.step(direction, at: time) }
        keyboard.speedControl = speedControl
        keyboard.modern = { [weak self] in self?.audioSettings.modernControlsEnabled ?? true }
        speedControl.onChange = { [weak self] in self?.accumulator = 0; self?.refreshGame() }
        keyboard.cycle = { [weak self] direction in
            guard let self, let game = self.game,
                  let index = SkillShortcuts.cycle(from: self.selected, direction: direction, available: game.supplies.map { $0 > 0 }) else { return }
            self.panelAction(index)
        }
        keyboard.centre = { [weak self] entrance in self?.canvas.centre(onEntrance: entrance) }
        keyboard.mainMenu = { [weak self] in
            guard let self else { return }
            self.paused = true; self.fanSelected = false; self.releasePointerInput()
            self.saveCheckpoint(immediately: true)
            if let exit = self.onReturnToLibrary { exit() } else { self.show(.menu) }
        }
        keyboard.escape = { [weak self] in
            guard let self else { return }
            if self.fanSelected { self.fanSelected = false; self.releasePointerInput(); self.refreshGame() }
            else { self.releasePointerInput(); self.key("\u{1b}") }
        }
        keyboard.cyclesSharedSkillLetters = false
        keyboard.overlayControls = { [weak self] in self?.canvas.accessibilityChildren() ?? [] }
        keyboard.skillNames = { [weak self] in self?.game?.configuration.skills.map(\.name) ?? [] }
        keyboard.help = { [weak self] in
            let names = self?.game?.configuration.skills.map(\.name) ?? []
            return SkillShortcuts(names: names).hint(names: names, modern: self?.audioSettings.modernControlsEnabled ?? false) + "\n\nSpace / P: pause\nR: retry\n.: single step"
        }
        keyboard.contextCommands = {
            [KeyboardCommand(keys: "← / → / ↑ / ↓", action: "Pan the level", group: "Camera"),
             KeyboardCommand(keys: "V / S", action: "Review / save replay after a result", group: "Menus & results"),
             KeyboardCommand(keys: "Return / Space", action: "Activate selected menu choice", group: "Menus & results"),
             KeyboardCommand(keys: "P / M / I", action: "From L2 menu: practice / tribe map / introduction", group: "Menus & results"),
             KeyboardCommand(keys: "1–4", action: "Choose practice level", group: "L2 practice"),
             KeyboardCommand(keys: "Arrow keys", action: "Choose practice skill", group: "L2 practice"),
             KeyboardCommand(keys: "Space / Return", action: "Toggle practice skill / start practice", group: "L2 practice"),
             KeyboardCommand(keys: "← / →", action: "Choose tribe on map", group: "Menus & results"),
             KeyboardCommand(keys: "R / B", action: "After a result: retry / records", group: "Menus & results")]
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
        keyboard.step = { [weak self] direction in if direction > 0 { self?.singleStep() } }
        keyboard.endRun = { [weak self] in
            guard let self else { return }
            let nuke = Lemmings2Control.nuke.rawValue
            if self.beforeNuke != nil { self.panelAction(nuke); return }
            GameScreen.shared.confirm("End this run?", detail: "Start the nuke countdown for the remaining lemmings.",
                actionTitle: "Start nuke", owner: self.window) { [weak self] in
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

        let musicRoot = root.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Music/lemmings_2_music_mod_tsyu")
        music.loadLibrary(at: musicRoot)
        music.setMuted(UserDefaults.standard.bool(forKey: progressKey + ".musicMuted"))
        try? music.start()
        sounds.setMuted(UserDefaults.standard.bool(forKey: progressKey + ".soundsMuted"))
        try sounds.start()
        playMusic("Maintune")
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
            guard let initial, let fingerprint = arcadeLevel?.conditions?.levelFingerprint,
                fingerprint == recovery.levelFingerprint else { throw RunRecoveryError.differentGame }
            let restored = try saved.restore(initial: initial, checkpoint: recovery)
            game = restored.0; beforeNuke = restored.1; beforeNukeInputCount = restored.2
            recoveryInputs = saved.inputs; recoveryProgress = saved.progress; recoveryPractice = saved.practice
            recoveryInitialHash = recovery.initialStateHash
            arcadeRunID = recovery.runID; arcadeProfileID = recovery.profileID; arcadeHotSeatID = recovery.hotSeatID
            usedRewind = recovery.usedRewind; nukeCount = recovery.nukeCount; undoCount = recovery.undoCount
            selected = recovery.selectedSkill; paused = true; fanSelected = false
            canvas.cameraX = CGFloat(recovery.scrollX); canvas.cameraY = CGFloat(recovery.scrollY)
            arcadeLevelSnapshot = arcadeLevel
            restoringRun = false
            releasePointerInput(); refreshGame()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func present() { showWindow(nil); window?.makeKeyAndOrderFront(nil); window?.makeFirstResponder(front) }
    func showLevelHints() {
        guard let window, !GameScreen.shared.isPresented, screen == .playing || screen == .briefing else { return }
        let names = game?.configuration.skills.map(\.name) ?? []
        let deck = LevelHintDeck.practice(title: level.title, skills: names)
        let wasPaused = paused
        let interruption = gameplayKeyboard?.interruptionCount
        paused = true; accumulator = 0; releasePointerInput(); saveCheckpoint(immediately: true); refreshGame()
        LevelHintWindow.shared.show(deck, owner: window) { [weak self] in
            guard let self else { return }
            self.paused = wasPaused || self.gameplayKeyboard?.interruptionCount != interruption
            self.accumulator = 0; self.lastTime = ProcessInfo.processInfo.systemUptime; self.refreshGame()
        }
    }
    @objc private func windowLostFocus(_ notification: Notification) {
        guard let resigned = notification.object as? NSWindow, resigned === window else { return }
        releasePointerInput()
    }
    private func interruptGameplay() {
        guard screen == .playing, game?.isComplete == false else { return }
        paused = true; accumulator = 0; lastTime = ProcessInfo.processInfo.systemUptime
        canvas.capturePointer(active: false)
        releasePointerInput(); saveCheckpoint(immediately: true); sounds.silence(); refreshGame()
    }
    func windowWillClose(_ notification: Notification) {
        stop()
    }
    @objc private func artworkChanged() {
        do { try canvas.refreshArtwork() }
        catch { message = "Artwork could not be loaded: \(error)" }
        if screen == .briefing { prepareBriefing() }
        if screen == .playing { refreshGame() }
        front.needsDisplay = true
    }
    func stop() {
        saveCheckpoint(immediately: true)
        canvas.capturePointer(active: false)
        NotificationCenter.default.removeObserver(self, name: SequelArtworkPreference.changed, object: nil)
        NotificationCenter.default.removeObserver(self,name:NSWindow.didResignKeyNotification,object:nil)
        timer?.invalidate(); timer = nil; runMovie.discard(); music.stop(); dj.stop(); sounds.stop(); persist()
    }
    func setMuted(_ muted: Bool) { setAudioSettings(audioSettings, muted: muted) }
    func suspendAudioOutput() { saveCheckpoint(immediately: true); music.suspendOutput(); dj.suspendOutput(); sounds.suspendOutput() }
    func resumeAudioOutput() throws { try music.resumeOutput(); dj.resumeOutput(); try sounds.resumeOutput() }
    func setAudioSettings(_ settings: ClassicSettings, muted: Bool) {
        let musicChanged = audioSettings.music != settings.music
        audioSettings = settings
        speedControl.variableEnabled = settings.modernControlsEnabled && settings.variableSpeedEnabled
        canvas.reduceMotion = settings.reduceMotion
        canvas.reduceFlashes = settings.reduceFlashes
        canvas.hdEffectsEnabled = settings.hdEffectsEnabled
        canvas.fullScreenHDRFlashes = settings.cinematicExplosionsEnabled
        if let root = Bundle.main.resourceURL?.appendingPathComponent("Music") {
            dj.load(soundtracks: SoundtrackPlayer.djSoundtracks(at: root, includeOtherSoundtracks: settings.djIncludesOtherSoundtracks))
        }
        dj.setVolume(settings.musicVolume)
        dj.setMuted(muted || settings.music == .silent || UserDefaults.standard.bool(forKey: progressKey + ".musicMuted"))
        globallyMuted = muted
        music.setVolume(settings.musicVolume)
        sounds.setVolume(settings.soundVolume)
        sounds.setBottomFallSounds(settings.bottomFallSounds)
        music.setMuted(muted || settings.music == .silent || UserDefaults.standard.bool(forKey: progressKey + ".musicMuted"))
        sounds.setMuted(muted || settings.sound == .silent || UserDefaults.standard.bool(forKey: progressKey + ".soundsMuted"))
        if musicChanged { if screen == .playing { playTribeMusic() } else { playMusic("Maintune") } }
    }
    static func savedCompletion(root: URL) -> Int {
        guard var campaign = try? Lemmings2Campaign(root: root) else { return 0 }
        let bundled = (try? BundledGameResources.lemmings2())?.standardizedFileURL == root.standardizedFileURL
        let key = ArcadeStore.shared.progressKey("nativeL2Campaign.v1." + (bundled ? "bundled" : root.standardizedFileURL.path))
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(Lemmings2Campaign.Progress.self, from: data) {
            try? campaign.restore(saved)
        }
        return campaign.results.count
    }
    private func playMusic(_ name: String) {
        if audioSettings.music == .adaptiveDJ, dj.hasTracks { music.stop(); dj.start(); return }
        dj.stop()
        try? music.start()
        if let index = music.library.firstIndex(where: { $0.deletingPathExtension().lastPathComponent.lowercased() == name.lowercased() }) {
            _ = music.play(index: index)
        }
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(campaign.progress) { UserDefaults.standard.set(data, forKey: progressKey) }
    }
    private func show(_ screen: Screen) {
        saveCheckpoint(immediately: true)
        if self.screen == .intro && screen != .intro { introduction = nil; try? music.resumeOutput() }
        if screen == .talisman {
            do { award = try Lemmings2Award(root:root,assets:assets,campaign:campaign,
                                          newPiece:self.screen == .results && game?.didWin == true) }
            catch { message = "Could not show the talisman: \(error)"; previousScreen = .map; show(.message); return }
        }
        if screen == .practice { practiceLevel = nil; game = nil; initial = nil }
        nukeGesture.reset()
        if screen != .playing { sounds.silence(); releasePointerInput() }
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
        if screen == .menu { playMusic("Maintune") }
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
            guard width > 0, height > 0 else { throw SequelDataError.invalid("Invalid level camera bounds.") }
            let pixels = (0..<height).flatMap { y in
                Array(terrain.image.pixels[((top + y) * terrain.image.width + left)..<((top + y) * terrain.image.width + left + width)])
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
            selected = 0; paused = false; speedControl.newLevel(); fanSelected = false; nukeGesture.reset()
            sounds.silence()
            show(.playing)
            beginReplay()
            playTribeMusic()
            refreshGame()
        } catch { explain(String(describing: error), returnTo: .briefing) }
    }
    private func restart() {
        saveCheckpoint(immediately: true)
        guard let initial else { return }
        let wasPlaying = screen == .playing
        game = initial; beginReplay(); dj.resetLevel(); canvas.resetCamera(level: level)
        countdownWarning.reset(seconds: initial.remainingSeconds)
        beforeNuke = nil
        paused = ArcadeStore.shared.hotSeatIsActive; speedControl.newLevel(); accumulator = 0; nukeGesture.reset(); sounds.silence()
        show(.playing)
        if !wasPlaying { playTribeMusic() }
        refreshGame()
    }
    private func beginReplay() {
        if restoringRun { return }
        lastFanInput = nil; lastAimInput = nil
        recoveryInputs = []; recoveryProgress = campaign.progress
        recoveryPractice = practiceLevel == nil ? nil
            : L2RunRecovery.Practice(choice: practiceChoice, skills: practiceSkills.map(\.rawValue))
        recoveryInitialHash = initial.flatMap { try? L2RunRecovery.stateHash($0, includeConfiguration: true) } ?? ""
        lastCheckpointTime = 0
        assignmentFocus = AssignmentFocus(); canvas.assignmentHighlight.clear()
        let previousAttemptID = arcadeRunID
        arcadeRunID = UUID(); arcadeProfileID = ArcadeStore.shared.playingProfileID; arcadeHotSeatID = ArcadeStore.shared.hotSeatID
        arcadeReport = nil; usedRewind = false; nukeCount = 0; undoCount = 0
        arcadeLevelSnapshot = arcadeLevel
        if let arcadeLevel { ArcadeStore.shared.beginAttempt(id: arcadeRunID, profileID: arcadeProfileID,
            level: arcadeLevel, previousID: previousAttemptID) }
        runMovie.begin(ticksPerSecond: Lemmings2Runtime.ticksPerSecond, title: "Lemmings 2 - " + level.title)
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
            paused = false; show(.playing); playTribeMusic(); refreshGame()
        } else { prepareBriefing() }
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
            case .pause: paused.toggle(); accumulator = 0
            case .fan: fanSelected.toggle()
            case .nuke:
                if nukeAction == .undo, let beforeNuke {
                    usedRewind = true; undoCount += 1
                    lastFanInput = nil; lastAimInput = nil
                    recoveryInputs = Array(recoveryInputs.prefix(beforeNukeInputCount))
                    game = beforeNuke; assignmentFocus.rewind(to: beforeNuke.tick); canvas.assignmentHighlight.clear(); self.beforeNuke = nil; sounds.silence(); accumulator = 0
                } else if nukeAction == .activate {
                    beforeNukeInputCount = recoveryInputs.count
                    beforeNuke = game; nukeCount += 1
                    performRecoveryInput(.nuke); paused = false; fanSelected = false; accumulator = 0
                }
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
            events: [], stateHash: try L2RunRecovery.stateHash(game), usedRewind: usedRewind,
            nukeCount: nukeCount, rewindCount: 0, undoCount: undoCount, selectedSkill: selected,
            scrollX: Double(canvas.cameraX), scrollY: Double(canvas.cameraY))
        checkpoint.sourcePath = root.path
        checkpoint.l2 = L2RunRecovery(progress: progress, inputs: recoveryInputs, practice: recoveryPractice)
        checkpoint.hotSeatID = arcadeHotSeatID
        return checkpoint
    }
    func saveCheckpoint(immediately: Bool = false) {
        let now = ProcessInfo.processInfo.systemUptime
        guard immediately || now - lastCheckpointTime >= 5 else { return }
        do {
            guard let checkpoint = try makeCheckpoint(engine: RunRecovery.bundledEngine) else { return }
            lastCheckpointTime = now
            recoveryStore.save(checkpoint, immediately: immediately) { [weak self] error in self?.message = error }
        } catch { message = error.localizedDescription }
    }

    private func assign(_ x: Int, _ y: Int) {
        nukeGesture.reset()
        if !fanSelected, performRecoveryInput(.machine(x:x,y:y)) { refreshGame(); return }
        if !fanSelected, performRecoveryInput(.chain(x:x,y:y)) { refreshGame(); return }
        if !fanSelected, let lem = game?.target(slot: selected, x: x, y: y) {
            if performRecoveryInput(.assign(slot: selected, lemming: lem.id)) {
                assignmentFocus.record(id: lem.id, skill: selected, tick: game?.tick ?? 0)
            }
        }
        sounds.play(game?.drainSoundEvents() ?? [])
        refreshGame()
    }
    private func refreshGame() {
        guard let game else { return }
        let turn = ArcadeStore.shared.hotSeatIsActive ? ArcadeStore.shared.records.profile(arcadeProfileID) : nil
        canvas.turnBadge.show(initials: turn?.initials, portrait: turn.flatMap { ArcadeWindow.shared.arcadeView.portraitImage($0.portrait) })
        canvas.speedMultiplier = speedControl.multiplier
        canvas.speedChoiceLabel = speedControl.choiceLabel
        canvas.speedLabel = speedControl.panelLabel
        canvas.variableSpeedEnabled = speedControl.variableEnabled
        canvas.isFastForward = fastForward && !paused && screen == .playing && !game.isComplete
        canvas.update(game)
        let palette = Lemmings2Panel.palette(over: game.configuration.palette, phase: frontTicks / 4)
        let hover = canvas.updateSelection(slot: selected, fan: fanSelected, palette: palette)
        var controls: Set<Lemmings2Control> = []
        if paused { controls.insert(.pause) }
        if fastForward { controls.insert(.fastForward) }
        if fanSelected { controls.insert(.fan) }
        let armed = nukeGesture.armedAt.map { ProcessInfo.processInfo.systemUptime - $0 <= NSEvent.doubleClickInterval } ?? false
        if armed || game.isNuking { controls.insert(.nuke) }
        let label = game.isNuking || armed ? "NUKE" : fanSelected ? "FAN" : hover ?? (fastForward ? "SPEED " + speedControl.label.replacingOccurrences(of: "×", with: "X") : game.configuration.skills[selected].name)
        if let rendered = try? assets.panel.render(skills: game.configuration.skills.map(\.rawValue), supplies: game.supplies,
            selected: selected, saved: game.saved, remaining: game.lemmings.filter(\.active).count,
            seconds: game.remainingSeconds, label: label, palette: palette, highlightedControls: controls) {
            canvas.setPanel(rendered)
        }
        canvas.toolTip = SkillShortcuts(names: game.configuration.skills.map(\.name)).hint(names: game.configuration.skills.map(\.name), modern: audioSettings.modernControlsEnabled) + "\n" + SpeedPanelControls.help
        canvas.setAccessibilityLabel("Lemmings 2. \(game.configuration.skills[selected].name) selected. \(label). \(paused ? "Paused." : "Running.") \(game.isNuking ? "Nuke active." : "") \(game.released) released, \(game.saved) saved.")
    }
    private func update() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = min(0.25, now - lastTime); lastTime = now
        let playing = screen == .playing && !paused && game?.isComplete == false && !GameScreen.shared.isPresented
        speedControl.update(at: now, active: screen == .playing && game?.isComplete == false && !GameScreen.shared.isPresented)
        let turn = ArcadeStore.shared.hotSeatIsActive ? ArcadeStore.shared.records.profile(arcadeProfileID) : nil
        canvas.turnBadge.show(initials: turn?.initials, portrait: turn.flatMap { ArcadeWindow.shared.arcadeView.portraitImage($0.portrait) })
        canvas.speedMultiplier = speedControl.multiplier
        canvas.speedChoiceLabel = speedControl.choiceLabel
        canvas.speedLabel = speedControl.panelLabel
        canvas.variableSpeedEnabled = speedControl.variableEnabled
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
            } catch { explain("Could not play the introduction: \(error)",returnTo:.menu) }
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
            } catch { explain("Could not animate the talisman: \(error)",returnTo:.map) }
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
            } catch { explain("Could not play the ending: \(error)",returnTo:.map) }
            return
        }
        if screen != .playing {
            if (screen == .map || screen == .results) && frontTicks.isMultiple(of: 4) { front.needsDisplay = true }
            return
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
            if countdownWarning.update(seconds: game.remainingSeconds) { sounds.play([.init(.builderWarning)]) }
            sounds.play(game.drainSoundEvents())
            canvas.flashExplosions(game)
            self.game = game; refreshGame(); captureReplayFrame()
            dj.updateTelemetry(.init(savedCount: game.saved, requiredCount: max(1, game.configuration.total - level.allowedLossesForGold), isNuking: game.isNuking))
            if speedControl.variableEnabled && speedControl.multiplier > 1 && ProcessInfo.processInfo.systemUptime >= inputDeadline { break }
        }
        guard game.tick != previousTick else {
            if frontTicks.isMultiple(of: 4) { refreshGame() }
            return
        }
        sounds.play(game.drainSoundEvents())
        self.game = game; refreshGame(); saveCheckpoint()
        finishIfComplete(game)
    }
    private func finishIfComplete(_ game: Lemmings2Runtime) {
        if game.isComplete {
            do { try recoveryStore.clear(arcadeRunID) } catch { message = error.localizedDescription }
            runMovie.finish()
            if practiceLevel == nil { _ = campaign.record(game); persist(); onProgressChanged?() }
            show(.results)
            recordArcadeResult(game)
        }
    }
    private func singleStep() {
        guard screen == .playing, var game, !game.isComplete, !GameScreen.shared.isPresented else { return }
        paused = true; accumulator = 0; releasePointerInput()
        // Release held fan/aim input before taking the single physics step.
        game = self.game!
        countdownWarning.reset(seconds: game.remainingSeconds)
        game.step()
        if countdownWarning.update(seconds: game.remainingSeconds) { sounds.play([.init(.builderWarning)]) }
        sounds.play(game.drainSoundEvents()); canvas.flashExplosions(game)
        self.game = game; refreshGame(); captureReplayFrame(); saveCheckpoint(immediately: true)
        finishIfComplete(game)
    }
    private func startIntroduction() {
        do {
            introduction = try Lemmings2Introduction(root:root,font:assets.font)
            music.suspendOutput(); show(.intro)
        } catch { explain("Could not load the introduction: \(error)",returnTo:.menu) }
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
            if let game, let index = SkillShortcuts(names: game.configuration.skills.map(\.name)).index(for: key, modern: audioSettings.modernControlsEnabled) { panelAction(index) }
            else if key == " " || key.lowercased() == "p" { panelAction(8) }

            else if key.lowercased() == "r" { restart() }
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
        if (try? campaign.select(tribe: campaign.tribe, level: campaign.level + direction)) != nil { prepareBriefing() }
    }
    private func continueResult() {
        if practiceLevel != nil { show(.practice); return }
        guard let game else { return }
        if game.didWin && campaign.level == 9 { show(.talisman) }
        else if campaign.advance(after: game) { persist(); prepareBriefing() }
        else { prepareBriefing() }
    }
    func releasePointerForMenu() { canvas.capturePointer(active: false); releasePointerInput(); saveCheckpoint(immediately: true) }
    func showLevelRecords() {
        if screen == .playing { releasePointerInput() }
        ArcadeWindow.shared.showRecords(level: arcadeLevel, owner: window, background: arcadeBackdrop)
    }
    var arcadeBackdrop: CGImage? { ArcadeWindow.captureScene(canvas) }
    private func recordArcadeResult(_ game: Lemmings2Runtime) {
        guard arcadeReport == nil else { return }
        guard let arcadeLevel else { return }
        var used: [String: Int] = [:]
        for slot in game.supplies.indices {
            let count = game.configuration.supplies[slot] - game.supplies[slot]
            if count > 0 { used[TrolleyCapture.skillKey(game.configuration.skills[slot].name), default: 0] += count }
        }
        arcadeReport = ArcadeStore.shared.record(ArcadeRun(id: arcadeRunID, profileID: arcadeProfileID,
            level: arcadeLevel, saved: game.saved, didWin: game.didWin, skills: used,
            seconds: Double(game.tick) / Lemmings2Runtime.ticksPerSecond, assisted: usedRewind,
            telemetry: TrolleyTelemetry(released: game.released, nukeCount: nukeCount, undoCount: undoCount,
                destructiveSkillCount: TrolleyCapture.destructiveCount(used), buildVersion: TrolleyCapture.buildVersion,
                additionalStatistics: ["goldRequirement": Double(max(1, game.configuration.total - level.allowedLossesForGold))])))
        guard let arcadeReport else { return }
        runMovie.preserveRecord(arcadeReport)
        ArcadeWindow.shared.showResult(arcadeReport, owner: window, retry: { [weak self] in self?.restart() },
            next: { [weak self] in self?.continueResult() }, replay: { [weak self] save in self?.runMovie.review(save: save) },
            continueTitle: practiceLevel != nil ? "Practice levels" : campaign.level == 9 ? "Continue" : "Next level", background: arcadeBackdrop, rewardVolume: sounds.muted ? 0 : audioSettings.soundVolume)
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
            entries = [("Play", CGRect(x: 10, y: 125, width: 70, height: 22)), ("Choose tribe", CGRect(x: 10, y: 150, width: 70, height: 22)), ("Preferences", CGRect(x: 10, y: 175, width: 70, height: 22)),
                ("Load game", CGRect(x: 240, y: 125, width: 70, height: 22)), ("Save game", CGRect(x: 240, y: 150, width: 70, height: 22)), ("Return to library", CGRect(x: 240, y: 175, width: 70, height: 22)),
                ("Introduction", CGRect(x: 120, y: 150, width: 70, height: 22)), ("Practice", CGRect(x: 100, y: 175, width: 110, height: 22))]
        case .map:
            entries = tribePoints.enumerated().map { index, point in (Lemmings2Campaign.tribeNames[index], CGRect(x: point.0 - 5, y: point.1 - 5, width: 10, height: 10)) }
        case .practice:
            entries = (1...51).compactMap { id in Lemmings2Runtime.Skill(rawValue: id).map { ($0.name, CGRect(x: 4 + (id - 1) % 13 * 24, y: 28 + (id - 1) / 13 * 20, width: 24, height: 20)) } }
            for (index, tribe) in Lemmings2Practice.tribes.enumerated() { entries.append((Lemmings2Campaign.tribeNames[tribe], CGRect(x: index * 80, y: 133, width: 80, height: 36))) }
            if practiceSkills.count == 8 { entries.append(("Start practice", CGRect(x: 100, y: 180, width: 120, height: 18))) }
        case .load, .save:
            entries = (0..<8).map { ("Slot \($0 + 1)", CGRect(x: 20, y: 40 + $0 * 16, width: 280, height: 16)) }
            entries += [(screen == .load ? "Load selected slot" : "Save to selected slot", CGRect(x: 10, y: 180, width: 140, height: 18)), ("Cancel", CGRect(x: 170, y: 180, width: 140, height: 18))]
        case .preferences:
            entries = [("Toggle music", CGRect(x: 20, y: 110, width: 135, height: 24)), ("Toggle sounds", CGRect(x: 160, y: 110, width: 135, height: 24)), ("Toggle enhanced artwork", CGRect(x: 20, y: 148, width: 280, height: 24)), ("Back", CGRect(x: 20, y: 180, width: 280, height: 18))]
        case .playing: break
        default: entries = [("Continue", CGRect(x: 100, y: 180, width: 120, height: 18))]
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
            if inside(0, 178, 100, 22) { restart() }
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
                    } catch { explain("This saved game cannot be loaded.", returnTo: .load) }
                }
            } else if (40..<168).contains(y) { selectedSlot = (y - 40) / 16; front.needsDisplay = true }
        case .talisman:
            if campaign.isComplete {
                do {
                    ending = try Lemmings2Ending(root:root,assets:assets,golden:campaign.canLaunchArk)
                    playMusic("endtune"); show(.ending)
                } catch { explain("Could not load the ending: \(error)",returnTo:.map) }
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
            text("Select 8 skills to practice",160,8,"PRACTICE",centered:true)
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
            let label = hoverPracticeSkill.flatMap(Lemmings2Runtime.Skill.init(rawValue:))?.name ?? "\(practiceSkills.count) of 8 selected"
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
            text(practiceSkills.count == 8 ? "Click or Return to practise" : "Choose eight different skills",160,186,"PRACTICE",centered:true)
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
                if (1...51).contains(skill) { text(bank("INFO").strings[skill - 1], 32, i * 25 + 13) }
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
            front.fittedText(practiceLevel != nil ? "Practice" : "\(Lemmings2Campaign.tribeNames[campaign.tribe]) \(campaign.level + 1)",
                             font: assets.font, palette: palette("INFO"),
                             rect: NSRect(x: 145, y: 135, width: 173, height: 13))
            front.fittedText(level.title, font: assets.font, palette: palette("INFO"),
                             rect: NSRect(x: 145, y: 150, width: 173, height: 24))
            text("\(practiceLevel != nil ? 60 : campaign.population) Lemmings", 231, 176, centered: true)
            text(String(format: "TIME %d:%02d", level.timeLimitSeconds / 60, level.timeLimitSeconds % 60), 231, 187, centered: true)
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
                text("You saved \(game.saved) lemmings", 160, 8, "MEDALS", centered: true)
                text(medal == .none ? "Oh dear!" : medal.name + " medal", 220, 42, "MEDALS", centered: true)
                front.wrappedText(game.didWin ? "Click to continue. Your survivors will go on to the next level."
                    : bank("MEDALS").strings[4], font: assets.font, palette: palette("MEDALS"), x: 135, y: 70, width: 170)
                text("V Replay  S Save movie", 160, 153, "MEDALS", centered: true)
                text("Retry", 35, 182, "MEDALS", centered: true)
                text("Continue", 160, 182, "MEDALS", centered: true)
                text("Menu", 285, 182, "MEDALS", centered: true)
            }
        case .preferences:
            picture("ROCKWALL", palette("PREFS"))
            text("Control Method", 160, 24, "PREFS", centered: true)
            text("Mouse", 160, 44, "PREFS", centered: true)
            text("Music", 52, 124, "PREFS")
            sprite("PREFS", music.muted ? 5 : 6, 38, 114)
            text("Sound FX", 189, 124, "PREFS")
            sprite("PREFS", sounds.muted ? 5 : 6, 175, 114)
            text(SequelArtworkPreference.enabled ? "Artwork: Macintosh-style 2x" : "Artwork: Original PC",
                 160, 154, "PREFS", centered: true)
            text("OK", 160, 184, "PREFS", centered: true)
        case .load, .save:
            picture("ROCKWALL", palette("LOAD"))
            text(screen == .save ? "Save Game" : "Select a game to load", 160, 12, "LOAD", centered: true)
            for i in 0..<8 {
                let key = progressKey + ".slot.\(i)"
                let data = UserDefaults.standard.data(forKey: key)
                let saved = data.flatMap { data -> Lemmings2Campaign.Progress? in
                    guard let progress = try? JSONDecoder().decode(Lemmings2Campaign.Progress.self, from: data) else { return nil }
                    var checked = campaign
                    do { try checked.restore(progress); return progress }
                    catch { return nil }
                }
                let name = saved.map { "\(Lemmings2Campaign.tribeNames[$0.tribe]) - Level \($0.level + 1)" }
                    ?? (data == nil ? "<Unsaved Position>" : "<Invalid saved game>")
                text("\(i == selectedSlot ? ">" : " ") \(i + 1). \(name)", 34, 40 + i * 16, "LOAD")
            }
            text(screen == .save ? "Save" : "Load", 80, 184, "LOAD", centered: true)
            text("Cancel", 240, 184, "LOAD", centered: true)
        case .talisman:
            if let award {
                front.draw(award.animation.pixels,width:320,height:200,palette:award.animation.palette,x:0,y:0)
                if frontTicks > 120 { text("Click to continue",160,184,"AWARD",centered:true) }
            }
        case .ending:
            if let ending {
                front.draw(ending.pixels,width:320,height:200,palette:ending.palette,x:0,y:0)
            }
        case .message:
            picture("ROCKWALL", palette("INFO"))
            front.wrappedText(message, font: assets.font, palette: palette("INFO"), x: 24, y: 55, width: 272)
            text("Click to return", 160, 182, centered: true)
        case .playing: break
        }
    }
}

@MainActor private final class Lemmings2MenuCanvas: NSView {
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
        var cursor = x
        for byte in text.utf8 where (32..<123).contains(byte) {
            let glyph = font.glyphs[Int(byte) - 32]
            draw(glyph, width: 16, height: 11, palette: palette, x: cursor, y: y, opaque: glyph.map { $0 != 0 })
            cursor += font.advances[Int(byte) - 32]
        }
    }
    func wrappedText(_ text: String, font: Lemmings2FrontEndFont, palette: [UInt8], x: Int, y: Int, width: Int) {
        var line = "", row = y
        for word in text.split(whereSeparator: { $0.isWhitespace }) {
            let next = line.isEmpty ? String(word) : line + " " + word
            if font.width(next) > width && !line.isEmpty {
                self.text(line, font: font, palette: palette, x: x, y: row); row += 13; line = String(word)
            } else { line = next }
        }
        self.text(line, font: font, palette: palette, x: x, y: row)
    }
    func fittedText(_ text: String, font: Lemmings2FrontEndFont, palette: [UInt8], rect: NSRect) {
        var lines: [String] = [], line = ""
        for word in text.split(whereSeparator: { $0.isWhitespace }) {
            let next = line.isEmpty ? String(word) : line + " " + word
            if font.width(next) > Int(rect.width) && !line.isEmpty {
                lines.append(line); line = String(word)
            } else { line = next }
        }
        if !line.isEmpty { lines.append(line) }
        guard !lines.isEmpty else { return }
        let width = max(1, lines.map(font.width).max() ?? 1)
        let height = lines.count * 13 - 2
        let scale = min(1, rect.width / CGFloat(width), rect.height / CGFloat(height))
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rect.midX, yBy: rect.minY)
        transform.scale(by: scale); transform.concat()
        for (row, line) in lines.enumerated() {
            self.text(line, font: font, palette: palette, x: -font.width(line) / 2, y: row * 13)
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
        if event.keyCode == 123 { onKey?("left") }
        else if event.keyCode == 124 { onKey?("right") }
        else if event.keyCode == 125 { onKey?("down") }
        else if event.keyCode == 126 { onKey?("up") }
        else if let text = event.charactersIgnoringModifiers { onKey?(text) }
    }
}

@MainActor private final class Lemmings2Canvas: NSView {
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
        guard let game else { return [] }
        let names = game.configuration.skills.map(\.name) + ["Pause", "End run", "Fan", "Fast-forward"]
        var children: [Any] = turnBadge.isHidden ? [] : [turnBadge]
        for slot in 0..<12 {
            let x = slot < 8 ? slot * 32 : 256 + (slot % 2) * 32
            let y = slot < 10 ? 160 : 180
            let height = slot < 8 ? 40 : 20
            let frame = CGRect(x: panelX + CGFloat(x) * zoom, y: origin.y + CGFloat(y) * zoom * 1.2, width: 32 * zoom, height: CGFloat(height) * zoom * 1.2)
            children.append(accessibleElements.element(id: "panel-\(slot)", owner: self, label: names[slot], frame: frame) { [weak self] in
                let time = ProcessInfo.processInfo.systemUptime
                self?.onPanel?(slot, 1, time)
                if slot == 9 { self?.onPanel?(slot, 2, time + 0.01) }
            })
        }
        if variableSpeedEnabled {
            for direction in [-1, 1] {
                children.append(accessibleElements.element(id: "speed-\(direction)", owner: self, label: direction < 0 ? "Decrease fast speed" : "Increase fast speed", frame: speedRect) { [weak self] in self?.onSpeedStep?(direction, ProcessInfo.processInfo.systemUptime) })
            }
        }
        return children
    }
    var onPanel: ((Int, Int, TimeInterval) -> Void)?
    var onHover: (() -> Void)?
    var onKey: ((String) -> Void)?
    var pointers: Lemmings2Pointers?
    private var cursorFrames: [NSCursor] = []
    private var cursorZoom: CGFloat = 0
    private var pointerFrame = 0
    var cameraX: CGFloat = 0
    var cameraY: CGFloat = 0
    private var cameraBounds: (left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat) = (0, 0, 0, 0)
    private var game: Lemmings2Runtime?
    private var terrain: NSImage?
    private var terrainRevision: Int?
    private var panel: NSImage?
    private var panelBackground = NSColor.black
    private var sprites: [String: [(image: NSImage, x: Int, y: Int)]] = [:]
    private var objects: [(id: Int, type: Int, x: Int, y: Int, entrance: Bool, animated: Bool, special: Bool,
                           frames: [(image: NSImage, x: Int, y: Int)])] = []
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    private var viewport: Lemmings2Viewport {
        Lemmings2Viewport(viewWidth: Double(bounds.width), viewHeight: Double(bounds.height))
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
        if cursorFrames.indices.contains(pointerFrame) { cursorFrames[pointerFrame].set() }
    }
    override func resetCursorRects() {
        if cursorFrames.indices.contains(pointerFrame) { addCursorRect(bounds, cursor: cursorFrames[pointerFrame]) }
    }
    func updateSelection(slot: Int, fan: Bool, palette: [UInt8]) -> String? {
        if let pointers, cursorFrames.isEmpty || zoom != cursorZoom {
            cursorZoom = zoom
            cursorFrames = pointers.frames.map { pixels in
                let original = image(width: 16, height: 16, pixels: pixels, palette: palette, opaque: pixels.map { $0 != 0 }, category: .architectural)
                let size = NSSize(width: 16 * zoom, height: 16 * zoom * 1.2)
                let scaled = NSImage(size: size, flipped: true) { rect in
                    original.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                                  hints: [.interpolation: NSImageInterpolation.none.rawValue])
                    return true
                }
                return NSCursor(image: scaled, hotSpot: NSPoint(x: 8 * zoom, y: 8 * zoom * 1.2))
            }
            window?.invalidateCursorRects(for: self)
        }
        var frame = 0, label: String?
        if let window, let game {
            let point = controllerPointer ?? convert(window.mouseLocationOutsideOfEventStream, from: nil)
            let x = (point.x - origin.x) / zoom, y = (point.y - origin.y) / (zoom * 1.2)
            if (0..<visibleWidth).contains(x), (0..<160).contains(y) {
                if fan { frame = 2 }
                else if let target = game.target(slot: slot, x: Int(x + cameraX), y: Int(y + cameraY)) {
                    frame = game.canAssign(slot: slot, to: target.id) ? 1 : 0
                    switch target.state {
                    case .walking: label = "WALKER"
                    case .running: label = "RUNNER"
                    case .teleporting: label = "TELEPORTER"
                    case .switchingValve: label = "VALVE"
                    case .trapDying: label = nil
                    case .cannonLoading, .cannonFlying: label = "CANNON"
                    case .catapultLoading: label = "CATAPULT"
                    case .chainRiding: label = "CHAIN"
                    case .superFlying: label = "SUPERLEM"
                    case .arching: label = "ARCHER"
                    case .skiing, .skiingAir: label = "SKIER"
                    case .poleVaulting, .poleShrugging: label = "POLE VAULTER"
                    case .magnoBooting: label = "MAGNO BOOTER"
                    case .throwing: label = "THROWER"
                    case .spearing: label = "SPEARER"
                    case .carpetFlying: label = "MAGIC CARPET"
                    case .surfing: label = "SURFER"
                    case .sliding: label = "SLIDER"
                    case .hanging, .climbingTransfer: label = "HANGING"
                    case .skating: label = "SKATER"
                    case .slipping, .iceRecovering: label = "SLIPPING"
                    case .twisting: label = "TWISTER"
                    case .jetPacking: label = "JET PACK"
                    case .rolling, .rollingAir: label = "ROLLER"
                    case .shimmyJump, .shimming: label = "SHIMMIER"
                    case .diving: label = "DIVER"
                    case .drowning: label = "DROWNING"
                    case .kayaking, .kayakPacking: label = "KAYAKER"
                    case .flyingIcarus: label = "ICARUS WINGS"
                    case .hangGliding: label = "HANG GLIDER"
                    case .roping: label = "ROPER"
                    case .firingBazooka: label = "BAZOOKA"
                    case .firingMortar: label = "MORTAR"
                    case .rockClimbing: label = "ROCK CLIMBER"
                    case .hoisting: label = "HOISTER"
                    case .planting: label = "PLANTER"
                    case .ballooning: label = "BALLOONER"
                    case .filling: label = "FILLER"
                    case .sandPouring: label = "SAND POURER"
                    case .gluePouring: label = "GLUE POURER"
                    case .attracting: label = "ATTRACTOR"
                    case .dancing: label = "DANCER"
                    case .parachuting: label = "PARACHUTER"
                    case .swimming, .leavingWater: label = "SWIMMER"
                    case .blastBombing: label = "BOMBER"
                    case .jumping: label = "JUMPER"
                    case .hopping, .hopPreparing: label = "HOPPER"
                    case .tumbling: label = "FALLER"
                    case .stunned: label = "STUNNED"
                    case .trapped: label = nil
                    case .falling: label = "FALLER"
                    case .floating: label = "FLOATER"
                    case .climbing: label = "CLIMBER"
                    case .building: label = "BUILDER"
                    case .bashing: label = "BASHER"
                    case .mining: label = "MINER"
                    case .digging: label = "DIGGER"
                    case .stomping: label = "STOMPER"
                    case .scooping: label = "SCOOPER"
                    case .fencing: label = "FENCER"
                    case .clubBashing: label = "CLUB BASHER"
                    case .lasering: label = "LASER BLASTER"
                    case .flaming: label = "FLAME THROWER"
                    case .blocking: label = "BLOCKER"
                    case .stacking: label = "STACKER"
                    case .platforming: label = "PLATFORMER"
                    case .exploding: label = "BOMBER"
                    default: label = "LEMMING"
                    }
                }
            }
            if frame != pointerFrame {
                pointerFrame = frame; window.invalidateCursorRects(for: self)
            }
            if window.isKeyWindow, bounds.contains(point), cursorFrames.indices.contains(frame) { cursorFrames[frame].set() }
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
        try reloadArtwork?()
        cameraX = oldX; cameraY = oldY
        cursorFrames = []; pointerFrame = -1
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
        didSet { if reduceMotion { speedTrails.reset() }; syncSpeedEffects(); needsDisplay = true }
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
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, hdrOverlay == nil {
            let overlay = ExplosionHDRView(frame: bounds)
            overlay.autoresizingMask = [.width, .height]
            addSubview(overlay, positioned: .below, relativeTo: turnBadge); hdrOverlay = overlay
        }
        syncSpeedEffects()
    }
    override func layout() { super.layout(); syncSpeedEffects() }
    private func syncSpeedEffects() {
        let active = usesSpeedEffects && window != nil
        hdrOverlay?.setSuperSpeed(active,
            in: CGRect(x:origin.x,y:origin.y,width:visibleWidth*zoom,height:192*zoom),immediate:!active, multiplier: speedMultiplier)
    }
    func flashExplosions(_ game: Lemmings2Runtime) {
        guard hdEffectsEnabled, !reduceFlashes else { return }
        let points = game.blastFlashes.map { (x: $0.x + 17, y: $0.y + 20) }
            + game.lemmings.filter { $0.state == .exploding && $0.age == 16 }.map { (x: $0.x, y: $0.y - 6) }
        guard !points.isEmpty else { return }
        let cores = points.map { NSRect(x: origin.x + (CGFloat($0.x - 3) - cameraX) * zoom,
            y: origin.y + (CGFloat($0.y - 3) - cameraY) * zoom * 1.2, width: 6 * zoom, height: 6 * zoom * 1.2) }
        hdrOverlay?.pulse(cores: cores, fullScreen: fullScreenHDRFlashes)
    }
    private var explosion: Lemmings2Explosion?
    func load(level: Lemmings2Level, style: Lemmings2Style, sprites bank: Lemmings2Sprites, intern: Lemmings2SpecialGraphics, explosion: Lemmings2Explosion, walker: Lemmings2Walker?) throws {
        hdrOverlay?.clear()
        isFastForward = false
        speedTrails.reset()
        reloadArtwork = { [weak self] in
            try self?.load(level: level, style: style, sprites: bank, intern: intern,
                           explosion: explosion, walker: walker)
        }
        terrainCategory = .lemmings2Terrain(tribe: level.style)
        self.explosion = explosion
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        let resolved = try Lemmings2Objects(level: level, style: style)
        terrainRevision = nil
        objects = []
        for (name, frames) in bank.animations {
            sprites[name] = frames.map { frame in
                (image(width: frame.width, height: frame.height, pixels: frame.pixels, palette: style.palette, opaque: frame.opaque), frame.x, frame.y)
            }
        }
        for (name,index) in [("LASER",16),("FLAME",17),("ROCKET",8),("JET",22),("STONE",7),("SPEAR",6),("ARROW",2),("CHAIN",5),("HOOK",11),("SMOKE",21),("EXPLOSION",10),("COUNTDOWN",15)] {
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
        NSGraphicsContext.saveGraphicsState()
        if mirrored {
            let transform = NSAffineTransform()
            transform.translateX(by: rect.midX * 2, yBy: 0); transform.scaleX(by: -1, yBy: 1); transform.concat()
        }
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                   hints: [.interpolation: NSImageInterpolation.none.rawValue])
        NSGraphicsContext.restoreGraphicsState()
    }
    private func updateSpeedTrails() {
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
    private func drawLemmings(_ game: Lemmings2Runtime, ghostsOnly: Bool) {
        let palette = game.configuration.palette
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
                name = "WALKER"; offsetX = -2; offsetY = -10
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
            drawImage(sprite.image, x: CGFloat(lem.x + offsetX + sprite.x),
                y: CGFloat(lem.y + offsetY + sprite.y), mirrored: mirrored)
            if let ticks = lem.bombTicks, let numbers = sprites["COUNTDOWN"], numbers.indices.contains(ticks >> 4) {
                let number = numbers[ticks >> 4]
                let x = [.walking,.running,.falling].contains(lem.state) ? -8 : offsetX
                drawImage(number.image,x:CGFloat(lem.x+x+number.x),y:CGFloat(lem.y+offsetY-7+number.y))
            }
            if let held = lem.heldProjectile,
               let frames = sprites[held.kind == .spear ? "SPEAR" : "STONE"], frames.indices.contains(held.frame) {
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
    }
    override func draw(_ dirtyRect: NSRect) {
        defer {
            ControllerPointer.draw(controllerPointer)
            if let id = assignmentHighlight.target, let lem = game?.lemmings.first(where: { $0.id == id && $0.active }) {
                assignmentHighlight.draw(at: CGPoint(x: origin.x + (CGFloat(lem.x) - cameraX) * zoom,
                    y: origin.y + (CGFloat(lem.y - 6) - cameraY) * zoom * 1.2), scale: zoom)
            }
            if let focusNotice { GameTypography.annotation(focusNotice, at: CGPoint(x: 12, y: 12)) }
        }
        if turnBadge.superview == nil { addSubview(turnBadge) }
        turnBadge.place(in: CGRect(x: origin.x, y: origin.y, width: visibleWidth * zoom, height: 192 * zoom))
        updateSpeedTrails()
        NSColor.black.setFill(); bounds.fill()
        guard let game, let terrain else { return }
        speedTrails.draw(enabled: usesSpeedEffects,
            in: NSRect(x: origin.x, y: origin.y, width: visibleWidth * zoom, height: 192 * zoom)) {
            drawWorld(game, terrain: terrain)
        }
        if let panel {
            panelBackground.setFill()
            NSRect(x: bounds.minX, y: origin.y + 192 * zoom, width: bounds.width, height: 48 * zoom).fill()
            panel.draw(in: NSRect(x: panelX, y: origin.y + 192 * zoom, width: 320 * zoom, height: 48 * zoom),
                       from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                       hints: [.interpolation: NSImageInterpolation.none.rawValue])
            if variableSpeedEnabled { SpeedPanelControls.draw(in: speedRect, label: speedLabel, active: isFastForward, next: speedChoiceLabel) }
        }
    }
    private var speedRect: CGRect { CGRect(x: panelX + 288 * zoom, y: origin.y + 216 * zoom, width: 32 * zoom, height: 24 * zoom) }
    private func drawWorld(_ game: Lemmings2Runtime, terrain: NSImage) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: origin.x, y: origin.y, width: visibleWidth * zoom, height: 192 * zoom)).addClip()
        drawImage(terrain, x: 0, y: 0)
        if usesSpeedEffects { drawLemmings(game, ghostsOnly: true) }
        for object in objects where !object.frames.isEmpty {
            let machine = game.machines.first { $0.id == object.id }
            let movement = machine.map { object.special ? $0.displacement : 0 } ?? 0
            let frame = machine.map { object.special ? $0.frame % object.frames.count : (($0.displacement % object.frames.count) + object.frames.count) % object.frames.count }
                ?? ([4, 9, 10, 12].contains(object.type) ? (game.objectFrames[object.id] ?? 0) % object.frames.count
                : object.entrance ? min(object.frames.count - 1, max(0, game.tick - 20))
                : (object.animated ? game.tick / 2 % object.frames.count : 0))
            let sprite = object.frames[frame]
            drawImage(sprite.image, x: CGFloat(object.x + movement + sprite.x), y: CGFloat(object.y + sprite.y))
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
            let name = shot.kind == .arrow ? "ARROW" : shot.kind == .stone ? "STONE" : shot.kind == .spear ? "SPEAR" : "ROCKET"
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
        NSColor(red:CGFloat(palette[12])/255,green:CGFloat(palette[13])/255,blue:CGFloat(palette[14])/255,alpha:1).setFill()
        if let rope = game.rope {
            if let frames = sprites["HOOK"], frames.indices.contains(rope.frame) {
                let hook = frames[rope.frame]
                drawImage(hook.image,x:CGFloat(rope.x-7+hook.x),y:CGFloat(rope.y-7+hook.y))
            }
            NSColor(red:CGFloat(palette[16])/255,green:CGFloat(palette[17])/255,blue:CGFloat(palette[18])/255,alpha:1).setFill()
            for point in rope.points {
                NSRect(x:origin.x+(CGFloat(point.x)-cameraX)*zoom,y:origin.y+(CGFloat(point.y)-cameraY)*zoom*1.2,width:zoom,height:zoom*1.2).fill()
            }
            NSColor(red:CGFloat(palette[12])/255,green:CGFloat(palette[13])/255,blue:CGFloat(palette[14])/255,alpha:1).setFill()
        }
        for particle in game.fillParticles {
            NSRect(x:origin.x + (CGFloat(particle.x)-cameraX)*zoom,
                   y:origin.y + (CGFloat(particle.y)-cameraY)*zoom*1.2,width:zoom,height:zoom*1.2).fill()
        }
        let poleColour = game.configuration.palette
        NSColor(srgbRed:CGFloat(poleColour[16])/255,green:CGFloat(poleColour[17])/255,
                blue:CGFloat(poleColour[18])/255,alpha:1).setFill()
        for lem in game.lemmings where lem.state == .poleVaulting {
            for point in lem.pole {
                NSRect(x:origin.x+(CGFloat(point.x)-cameraX)*zoom,
                       y:origin.y+(CGFloat(point.y)-cameraY)*zoom*1.2,width:zoom,height:zoom*1.2).fill()
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
        NSGraphicsContext.restoreGraphicsState()
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let p = convert(event.locationInWindow, from: nil)
        let x = (p.x - origin.x) / zoom
        let y = (p.y - origin.y) / (zoom * 1.2)
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
        let x = (p.x-origin.x)/zoom, y = (p.y-origin.y)/(zoom*1.2)
        guard x >= 0, x < visibleWidth, y >= 0, y < 160 else { onRelease?(); return }
        onPointer?(Int(x+cameraX),Int(y+cameraY),held)
    }
    override func mouseDragged(with event: NSEvent) { trackPointer(event,held:true); onHover?() }
    override func mouseUp(with event: NSEvent) { onSpeedRelease?(event.timestamp); trackPointer(event,held:false); onRelease?() }
    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { super.keyDown(with: event); return }
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
    private var focusNotice: String?
    func showFocusNotice(_ text: String) {
        focusNotice = text; needsDisplay = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.focusNotice = nil; self?.needsDisplay = true }
    }
    func pointerTarget(slot: Int) -> Int? {
        guard let window, let game else { return nil }
        let p = controllerPointer ?? capturedPointer ?? convert(window.mouseLocationOutsideOfEventStream, from: nil)
        let x = (p.x - origin.x) / zoom, y = (p.y - origin.y) / (zoom * 1.2)
        guard (0..<visibleWidth).contains(x), (0..<160).contains(y) else { return nil }
        return game.target(slot: slot, x: Int(x + cameraX), y: Int(y + cameraY))?.id
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
        let horizontal = event.modifierFlags.contains(.shift) ? event.scrollingDeltaY : event.scrollingDeltaX
        pan(x: horizontal * 4, y: event.modifierFlags.contains(.shift) ? 0 : event.scrollingDeltaY * 4)
    }
}
