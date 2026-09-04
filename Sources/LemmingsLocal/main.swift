import AppKit
import NxlvKit

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
  private var window: NSWindow!
  private let playfield = PlayfieldView()
  private let panel = PanelView()
  private let crtView = CRTView()
  /// The plain view hierarchy, used when the tube is off.
  private var plainRoot: NSView?
  private var panelHeightConstraint: NSLayoutConstraint?
  private var tubeIsActive = false
  private let picker = NSPopUpButton()

  private var campaign: ClassicCampaign?
  private var grounds: [Int: ClassicGroundSet] = [:]
  private var specials: [Int: ClassicSpecialGraphic] = [:]
  /// Every imported game, in the order they were added.
  private var dataSets: [(set: ClassicDataSet, directory: URL)] = []
  private let gamePicker = NSPopUpButton()
  private var assets: ClassicMainDATAssets?
  private var macArtworkCache: [String: ClassicMacArtwork] = [:]
  private var contentDirectory: URL?
  private var stylesDirectory: URL?

  private var session: (any GameSession)?
  private var timer: Timer?
  private var accumulator = 0.0
  private var isPaused = false
  private var phase: GamePhase = .briefing
  /// The whole game, from title to end.
  private var flow: ClassicGameFlow?
  private var launchChoice = 0
  private var launchMode: UnifiedGameLibrary.Mode = .quest
  private var library = UnifiedGameLibrary(entries: [])
  private var activeTitle: ClassicTitle?
  private var sequelIsActive: Bool { nativeL2Window != nil || nativeL3Window != nil }
  private var classicContent: NSView?
  private var sequelCompletion: [ClassicTitle: Int] = [:]
  private var settingsWindow: SettingsWindow?
  private var settings = ClassicSettings()
  private var previousDepth = ClassicColorDepth.full
  private var rankChoice = 0
  private var progress = ModernCampaignProgress()
  private var achievements = ClassicAchievementProgress()
  private let music = ModuleMusicPlayer()
  /// Plays recordings the player supplied, as an alternative to the modules.
  private let soundtrack = SoundtrackPlayer()
  /// Soundtracks found next to the modules, keyed by folder name.
  private var soundtrackLibrary: [String: [URL]] = [:]
  /// The artwork this level is drawn with. It differs from the chosen setting
  /// only while shuffle is on.
  private var levelGraphics: ClassicGraphicsSource?
  /// The soundtrack this level plays, on the same basis.
  private var levelMusic: ClassicMusicSource?
  private let effects = SoundEffectPlayer()
  private var muteItem: NSMenuItem?
  private var presetItem: NSMenuItem?
  private var gamesMenu: NSMenu?
  private var levelsMenu: NSMenu?
  /// Set while an unofficial level is loaded, so retry reloads that file.
  private var currentNxlvURL: URL?
  private var nativeL2Window: Lemmings2PlayWindow?
  private var nativeL3Window: Lemmings3PlayWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    migrateStandaloneSaves()
    buildMenu()
    buildInterface()
    installKeyboardShortcuts()

    if let saved = UserDefaults.standard.string(forKey: contentPathKey) {
      contentDirectory = URL(fileURLWithPath: saved, isDirectory: true)
    }
    if let saved = UserDefaults.standard.string(forKey: stylesPathKey) {
      stylesDirectory = URL(fileURLWithPath: saved, isDirectory: true)
    }
    if let data = UserDefaults.standard.data(forKey: settingsKey),
      let stored = try? JSONDecoder().decode(ClassicSettings.self, from: data) {
      settings = stored
    }
    if !UserDefaults.standard.bool(forKey: "PreferMacArtworkV1") {
      settings.graphics = .macintosh
      UserDefaults.standard.set(true, forKey: "PreferMacArtworkV1")
      if let data = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(data, forKey: settingsKey) }
    }
    if let data = UserDefaults.standard.data(forKey: progressKey),
      let saved = try? ModernCampaignProgress(encoded: data) {
      progress = saved
    }
    if let data = UserDefaults.standard.data(forKey: achievementProgressKey),
      let saved = try? JSONDecoder().decode(ClassicAchievementProgress.self, from: data) {
      achievements = saved
    }
    if let saved = UserDefaults.standard.string(forKey: musicPathKey) {
      music.loadLibrary(at: URL(fileURLWithPath: saved, isDirectory: true))
    } else if let bundled = BundledGameResources.music("lemmings_music_mod") {
      music.loadLibrary(at: bundled)
    }
    loadSoundtracks()
    if UserDefaults.standard.bool(forKey: musicPresetKey) {
      music.setEnhancements(.modern)
    }
    do {
      try effects.start()
      if let saved = UserDefaults.standard.string(forKey: macImageKey) {
        loadSoundEffects(from: URL(fileURLWithPath: saved))
      } else if let bundled = BundledGameResources.macintoshSoundImage() {
        loadSoundEffects(from: bundled)
      }
    } catch {
      setStatus("Sound unavailable: \(error.localizedDescription)")
    }
    do {
      try music.start()
    } catch {
      // Audio is optional. The game stays playable without it.
      setStatus("Audio unavailable: \(error.localizedDescription)")
    }
    updateMusicButtons()

    loadContent()
    startTimer()
    window.collectionBehavior.insert(.fullScreenPrimary)
    DispatchQueue.main.async { [weak self] in
      guard let self, !self.window.styleMask.contains(.fullScreen) else { return }
      self.window.toggleFullScreen(nil)
    }
    if let index = CommandLine.arguments.firstIndex(of: "--native-l2") {
      let path = index + 1 < CommandLine.arguments.count ? CommandLine.arguments[index + 1] : nil
      openNativeL2(path.flatMap { $0.hasPrefix("--") ? nil : URL(fileURLWithPath: $0) })
    }
    if let index = CommandLine.arguments.firstIndex(of: "--native-l3") {
      let path = index + 1 < CommandLine.arguments.count ? CommandLine.arguments[index + 1] : nil
      openNativeL3(path.flatMap { $0.hasPrefix("--") ? nil : URL(fileURLWithPath: $0) })
    }
  }

  private func migrateStandaloneSaves() {
    guard Bundle.main.bundleIdentifier == "org.lemmingslocal.LemmingsLocal" else { return }
    for domain in ["org.lemmingslocal.NativeL2", "org.lemmingslocal.NativeL3Preview"] {
      let values = UserDefaults.standard.persistentDomain(forName: domain) ?? [:]
      for (key, value) in values where (key.hasPrefix("nativeL2") || key.hasPrefix("nativeL3"))
          && key.contains(".bundled") && UserDefaults.standard.object(forKey: key) == nil {
        UserDefaults.standard.set(value, forKey: key)
      }
    }
  }

  // MARK: - Interface

  private func buildMenu() {
    let mainMenu = NSMenu()
    let appItem = NSMenuItem()
    mainMenu.addItem(appItem)

    let appMenu = NSMenu()
    let achievementsItem = NSMenuItem(
      title: "Achievements…", action: #selector(showAchievements), keyEquivalent: "a")
    achievementsItem.keyEquivalentModifierMask = [.command, .shift]
    achievementsItem.target = self
    appMenu.addItem(achievementsItem)
    let nativeL2 = NSMenuItem(title: "Play Lemmings 2…", action: #selector(chooseNativeL2), keyEquivalent: "2")
    nativeL2.keyEquivalentModifierMask = [.command, .shift]
    nativeL2.target = self
    appMenu.addItem(nativeL2)
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
      withTitle: "Quit Lemmings Local",
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
    _ = add(fileMenu, "Game Library", #selector(returnToLibrary), "l", modifiers: [.command, .shift])
    fileMenu.addItem(.separator())
    _ = add(fileMenu, "Add Game…", #selector(chooseContent), "o")
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

    let viewMenu = addMenu("View")
    _ = add(viewMenu, "Zoom In", #selector(zoomIn), "+")
    _ = add(viewMenu, "Zoom Out", #selector(zoomOut), "-")

    let audioMenu = addMenu("Audio")
    _ = add(audioMenu, "Choose Music Folder…", #selector(chooseMusic))
    _ = add(audioMenu, "Choose Sound Effects…", #selector(chooseSounds))
    audioMenu.addItem(.separator())
    muteItem = add(audioMenu, "Mute", #selector(toggleMute), "m")
    presetItem = add(audioMenu, "Modern Sound", #selector(toggleMusicPreset))

    NSApplication.shared.mainMenu = mainMenu
  }

  // MARK: - Display path

  /// Chooses between drawing straight to the window and drawing through the
  /// tube.
  ///
  /// The tube needs the game drawn at its own size first. Feeding it an
  /// already enlarged picture produces one scan line per screen row instead of
  /// one per game row, which is both wrong and invisible.
  private func applyDisplayMode() {
    guard !sequelIsActive else { return }
    let wantsTube = settings.display != .flat && crtView.isAvailable
    guard wantsTube != tubeIsActive else {
      if wantsTube { crtView.settings = tubeSettings() }
      return
    }
    tubeIsActive = wantsTube

    if wantsTube {
      crtView.settings = tubeSettings()
      // The game views leave the window and draw at their own size.
      playfield.removeFromSuperview()
      panel.removeFromSuperview()
      playfield.translatesAutoresizingMaskIntoConstraints = true
      panel.translatesAutoresizingMaskIntoConstraints = true
      playfield.frame = CGRect(x: 0, y: 0, width: 320, height: 160)
      panel.frame = CGRect(x: 0, y: 0, width: 320, height: 40)
      playfield.viewport.zoom = 1
      crtView.onMouseDown = { [weak self] point in self?.tubeClick(point) }
      crtView.onMouseMoved = { [weak self] point in self?.tubeMove(point) }
      crtView.onScroll = { [weak self] dx, _ in
        guard let self else { return }
        self.playfield.viewport.scroll(dx: -Double(dx), dy: 0)
        self.syncPanelViewport()
      }
      window.contentView = crtView
      window.makeFirstResponder(crtView)
    } else {
      window.contentView = plainRoot
      window.makeFirstResponder(playfield)
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

    let size = CGSize(width: 320, height: 200)
    let composed = NSImage(size: size)
    composed.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .none
    NSColor.black.setFill()
    CGRect(origin: .zero, size: size).fill()
    panelRep.draw(in: CGRect(x: 0, y: 0, width: 320, height: 40))
    playfieldRep.draw(in: CGRect(x: 0, y: 40, width: 320, height: 160))
    composed.unlockFocus()

    var rect = CGRect(origin: .zero, size: size)
    return composed.cgImage(forProposedRect: &rect, context: nil, hints: nil)
  }

  /// Sends a click through the tube to whichever part it landed on.
  private func tubeClick(_ point: CGPoint) {
    if point.y < 40 {
      panel.handleClick(at: CGPoint(x: point.x, y: point.y))
    } else {
      playfield.handleClick(at: CGPoint(x: point.x, y: point.y - 40))
    }
  }

  private func tubeMove(_ point: CGPoint) {
    guard point.y >= 40 else { return }
    playfield.handleMove(to: CGPoint(x: point.x, y: point.y - 40))
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
      remixFolders: soundtrackLibrary.keys.sorted())
  }

  @objc private func showSettings() {
    let options = settingsOptions()
    if settingsWindow == nil {
      let created = SettingsWindow(settings: settings, options: options)
      created.videoIsConnected = crtView.isAvailable
      created.onChange = { [weak self] updated in self?.apply(updated) }
      settingsWindow = created
    } else {
      settingsWindow?.update(options: options)
    }
    settingsWindow?.show()
  }

  /// Puts a settings change into effect and remembers it.
  ///
  /// Only the parts the engine can honour today are acted on. A control that
  /// changed nothing would be worse than one that is absent.
  private func apply(_ updated: ClassicSettings) {
    let artworkChanged = settings.graphics != updated.graphics
    settings = updated
    if let data = try? JSONEncoder().encode(updated) {
      UserDefaults.standard.set(data, forKey: settingsKey)
    }

    music.setEnhancements(updated.musicStyle == .modern ? .modern : .faithful)
    music.setVolume(updated.musicVolume)
    soundtrack.setVolume(updated.musicVolume)
    effects.setVolume(updated.soundVolume)
    music.setMuted(updated.music == .silent)
    soundtrack.setMuted(updated.music == .silent)
    if case .remix = updated.music {} else { soundtrack.stop() }
    effects.setMuted(updated.sound == .silent)
    updateMusicButtons()

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

  @objc private func showAchievements() {
    let lines = ClassicAchievement.catalog.map { achievement in
      let mark = achievements.isUnlocked(achievement.id) ? "✓" : "○"
      return "\(mark)  \(achievement.title) — \(achievement.detail)"
    }
    let unlocked = achievements.unlocked.count
    let alert = NSAlert()
    alert.messageText = "Achievements  \(unlocked)/\(ClassicAchievement.catalog.count)"
    alert.informativeText = lines.joined(separator: "\n")
    alert.addButton(withTitle: "Done")
    alert.runModal()
  }

  @objc private func chooseNativeL2() {
    launchMode = .singleTitle
    openNativeL2()
  }

  private func suspendCurrentEngine() {
    saveProgress()
    nativeL2Window?.stop()
    nativeL3Window?.stop()
    nativeL2Window = nil
    nativeL3Window = nil
    music.stop()
    effects.stop()
    accumulator = 0
  }

  private func openNativeL2(_ root: URL? = nil) {
    do {
      let next = try Lemmings2PlayWindow(root: root ?? BundledGameResources.lemmings2())
      if !sequelIsActive { classicContent = window.contentView }
      suspendCurrentEngine()
      nativeL2Window = next
      activeTitle = .lemmings2TheTribes
      next.onReturnToLibrary = { [weak self] in self?.returnToLibrary() }
      next.onProgressChanged = { [weak self] in self?.refreshSequelProgress() }
      next.onCampaignCompleted = { [weak self] in self?.finishNativeTitle() }
      next.attach(to: window)
      if music.muted { next.setMuted(true) }
      window.title = "Lemmings 2 — The Tribes"
      window.contentAspectRatio = NSSize(width: 4, height: 3)
      window.minSize = NSSize(width: 640, height: 502)
      next.present()
      rebuildNavigationMenus()
    } catch { showLaunchError("Cannot open Lemmings 2", error) }
  }

  @objc private func chooseNativeL3() { launchMode = .singleTitle; openNativeL3() }

  private func openNativeL3(_ root: URL? = nil) {
    do {
      let next = try Lemmings3PlayWindow(root: root ?? BundledGameResources.lemmings3())
      if !sequelIsActive { classicContent = window.contentView }
      suspendCurrentEngine()
      nativeL3Window = next
      activeTitle = .lemmings3TheChronicles
      next.onReturnToLibrary = { [weak self] in self?.returnToLibrary() }
      next.onProgressChanged = { [weak self] in self?.refreshSequelProgress() }
      next.onCampaignCompleted = { [weak self] in self?.finishNativeTitle() }
      next.attach(to: window)
      window.title = "Lemmings 3 — The Chronicles"
      window.resizeIncrements = NSSize(width: 1, height: 1)
      window.minSize = NSSize(width: 1050, height: 680)
      next.present()
      rebuildNavigationMenus()
    } catch { showLaunchError("Cannot open Lemmings 3", error) }
  }

  private func showLaunchError(_ title: String, _ error: Error) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = String(describing: error)
    alert.runModal()
  }

  @objc private func returnToLibrary() {
    suspendCurrentEngine()
    activeTitle = nil
    currentNxlvURL = nil
    window.contentView = classicContent ?? plainRoot
    window.resizeIncrements = NSSize(width: 1, height: 1)
    window.minSize = NSSize(width: 900, height: 620)
    window.title = "Lemmings — Game Library"
    window.makeFirstResponder(playfield)
    try? music.start()
    try? effects.start()
    refreshSequelProgress()
    flow?.acknowledgeGameComplete()
    rebuildLibrary()
    renderScreen()
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
  }

  private func rebuildLibrary() {
    library = UnifiedGameLibrary(entries: ClassicTitle.allCases.map { title in
      if let entry = dataSets.first(where: { $0.set.title == title }) {
        var savedFlow = ClassicGameFlow(campaign: entry.set.campaign)
        if let data = UserDefaults.standard.data(forKey: "\(flowProgressKey).\(entry.set.identifierKey)")
            ?? UserDefaults.standard.data(forKey: "\(flowProgressKey).\(entry.set.legacyIdentifierKey)"),
           let saved = try? JSONDecoder().decode(ClassicGameFlow.Progress.self, from: data) { savedFlow.restore(entry.set.migrateProgress(saved)) }
        let count = savedFlow.ranks.reduce(0) { $0 + savedFlow.passedCount(inRank: $1.name) }
        return .init(title: title, total: entry.set.campaign.levels.count, passed: count)
      }
      let available = title == .lemmings2TheTribes ? (try? BundledGameResources.lemmings2()) != nil
        : title == .lemmings3TheChronicles ? (try? BundledGameResources.lemmings3()) != nil : false
      // The menu is set in the game's own fixed-width font, so a row holds
      // only a short note. One word says as much as a sentence here.
      let detail = title == .lemmings2TheTribes ? "PARTIAL"
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
      activeTitle = title
      openChapter(title)
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

  private func rebuildNavigationMenus() {
    gamesMenu?.removeAllItems()
    for entry in library.entries {
      let item = NSMenuItem(title: entry.title.displayName + (entry.available ? "" : " — Import needed"),
        action: #selector(selectGameFromMenu(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = entry.title.rawValue
      item.isEnabled = entry.available
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
        submenu.addItem(item)
      }
      let item = NSMenuItem(title: rank, action: nil, keyEquivalent: "")
      item.submenu = submenu
      levelsMenu?.addItem(item)
    }
  }

  @objc private func selectGameFromMenu(_ sender: NSMenuItem) {
    guard let value = sender.representedObject as? String, let title = ClassicTitle(rawValue: value) else { return }
    launchMode = .singleTitle
    saveProgress()
    launchTitle(title)
  }

  @objc private func selectLevelFromMenu(_ sender: NSMenuItem) {
    guard !sequelIsActive else { return }
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
    for view in [playfield, panel] as [NSView] {
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

    picker.target = self
    picker.action = #selector(levelChanged)
    gamePicker.target = self
    gamePicker.action = #selector(selectDataSet)
    playfield.onAssign = { [weak self] id in self?.assign(id) }
    playfield.onViewportChanged = { [weak self] in self?.syncPanelViewport() }
    playfield.onAdvancePhase = { [weak self] in self?.advancePhase() }
    playfield.onSelectOverlayLine = { [weak self] index in
      guard let self else { return }
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
    window.delegate = self
    window.title = "Lemmings — Native macOS Port"
    plainRoot = root
    window.contentView = root
    window.center()
    window.makeKeyAndOrderFront(nil)
    window.makeFirstResponder(playfield)
  }

  func windowDidResize(_ notification: Notification) {
    fitClassicDisplay()
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
    guard let url = pickDirectory("Choose the directory holding LEVEL000.DAT and MAIN.DAT.")
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

  private func pickDirectory(_ message: String) -> URL? {
    let openPanel = NSOpenPanel()
    openPanel.canChooseDirectories = true
    openPanel.canChooseFiles = false
    openPanel.allowsMultipleSelection = false
    openPanel.message = message
    guard openPanel.runModal() == .OK else { return nil }
    return openPanel.url
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
      setStatus("Add a game folder, or open a .nxlv level.")
      return
    }

    // A folder is identified rather than assumed, so any title in this
    // format loads without a hand-written order table.
    dataSets = []
    var problems: [String] = []
    var loaded: [(offset: Int, set: ClassicDataSet, directory: URL)] = []
    for (offset, directory) in directories.enumerated() {
      do {
        let set = try ClassicDataSet.detect(directory: directory)
        // Prefer the embedded copy of an official release over an old import.
        if set.title != nil, loaded.contains(where: { $0.set.identifierKey == set.identifierKey }) { continue }
        loaded.append((offset, set, directory))
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

    gamePicker.removeAllItems()
    for entry in dataSets {
      gamePicker.addItem(
        withTitle: "\(entry.set.name) (\(entry.set.campaign.levels.count))")
    }
    guard !dataSets.isEmpty else {
      setStatus("No Lemmings data found. \(problems.first ?? "")")
      return
    }
    gamePicker.selectItem(at: 0)
    selectDataSet()
    returnToLibrary()
  }

  /// Points the app at the release a launch choice refers to.
  private func openChapter(_ title: ClassicTitle) {
    guard let index = dataSets.firstIndex(where: { entry in
      entry.set.title == title
    }) else { return }
    gamePicker.selectItem(at: index)
    selectDataSet()
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
    guard let resources = Bundle.main.resourceURL,
      dataSets.indices.contains(gamePicker.indexOfSelectedItem),
      let title = dataSets[gamePicker.indexOfSelectedItem].set.title,
      let family = macArtworkFamily(for: title)
    else { return }
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
    defer { configureFrontEndArtwork() }
    let entry = dataSets[index]
    currentNxlvURL = nil
    do {
      // Titles ship different numbers of ground and special sets, so load
      // exactly what the folder holds instead of a fixed count.
      grounds = [:]
      specials = [:]
      for style in entry.set.groundStyles {
        grounds[style] = try ClassicGroundSet.load(style: style, from: entry.directory)
      }
      for special in entry.set.specialIndices {
        specials[special + 1] = try ClassicSpecialGraphic.load(
          index: special, from: entry.directory)
      }
      assets = try ClassicMainDATAssets.load(from: entry.directory)
      playfield.assets = assets
      playfield.invalidateSprites()
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
      var built = ClassicGameFlow(campaign: entry.set.campaign)
      let savedData = UserDefaults.standard.data(
        forKey: "\(flowProgressKey).\(entry.set.identifierKey)")
        ?? UserDefaults.standard.data(
          forKey: "\(flowProgressKey).\(entry.set.legacyIdentifierKey)")
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
      picker.selectItem(at: 0)
      showTitle()
      rebuildLibrary()
    } catch {
      setStatus("\(entry.set.name): \(error)")
    }
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
      let playable = options.music.filter { $0 != .silent }
      levelMusic = playable.randomElement()
    } else {
      levelMusic = nil
    }
  }

  /// The artwork in force, which is the shuffled choice when there is one.
  private var activeGraphics: ClassicGraphicsSource { levelGraphics ?? settings.graphics }
  private var activeMusic: ClassicMusicSource { levelMusic ?? settings.music }

  @objc private func levelChanged() {
    guard var current = flow, let campaign,
      picker.indexOfSelectedItem < campaign.levels.count else { return }
    // Choosing from the list jumps there, keeping the run intact.
    let target = picker.indexOfSelectedItem
    for (rankIndex, rank) in current.ranks.enumerated() {
      if let position = rank.levelIndices.firstIndex(of: target) {
        current.selectLevel(rank: rankIndex, position: position)
        flow = current
        renderScreen()
        return
      }
    }
  }

  private var artworkLevel: ClassicLevel?

  private func buildLevel(_ entry: ClassicCampaignLevel) {
    currentNxlvURL = nil
    let level = entry.level
    do {
      guard let ground = grounds[level.groundStyle] else { return }
      let rendered = try ClassicLevelRenderer.render(
        level, groundSet: ground, specialGraphic: specials[level.specialStyle])

      guard let image = makeImage(
        width: rendered.width, height: rendered.height, rgba: [UInt8](rendered.rgba))
      else { return }
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

      // The DOS engine derives entrances, exits and hazards from the level's
      // own trigger zones, so nothing is positioned by hand here.
      let simulation: ClassicDOSSimulation
      if let assets {
        simulation = try ClassicDOSSimulation(
          level: level, renderedLevel: rendered, mainDATAssets: assets)
      } else {
        simulation = try ClassicDOSSimulation(level: level, renderedLevel: rendered)
      }
      adopt(
        ClassicSession(
          simulation: simulation, width: rendered.width, height: rendered.height))
      // startX is the authored left edge of the original 320-pixel view.
      playfield.viewport.center(on: Double(level.startX) + 160)
      syncPanelViewport()
    } catch {
      setStatus("Level error: \(error)")
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

  // MARK: - Unofficial levels

  @objc private func chooseNxlvLevel() {
    let openPanel = NSOpenPanel()
    openPanel.canChooseFiles = true
    openPanel.canChooseDirectories = false
    openPanel.allowedFileTypes = ["nxlv"]
    openPanel.message = "Choose a NeoLemmix level file."
    guard openPanel.runModal() == .OK, let url = openPanel.url else { return }
    if sequelIsActive { returnToLibrary() }
    activeTitle = nil
    loadNxlv(url)
  }

  private func loadNxlv(_ url: URL) {
    // A NeoLemmix level draws every piece from a style pack, so the styles
    // directory must be known before the level can render.
    if stylesDirectory == nil {
      guard let styles = pickDirectory("Choose the NeoLemmix 'styles' directory.") else {
        setStatus("A styles directory is needed to draw NeoLemmix levels.")
        return
      }
      stylesDirectory = styles
      UserDefaults.standard.set(styles.path, forKey: stylesPathKey)
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

      playfield.classicScene = nil
      playfield.macScene = nil
      playfield.macArtwork = nil
      panel.macArtwork = nil
      playfield.imageScale = 1
      playfield.levelImage = image
      currentNxlvURL = url
      let simulation = try NeoLemmixSimulation(level: level, renderedLevel: rendered)
      adopt(
        NeoLemmixSession(
          simulation: simulation, width: rendered.width, height: rendered.height))
      window.title = "Lemmings — \(level.title)"
    } catch {
      setStatus("NeoLemmix error: \(error)")
    }
  }

  // MARK: - Session handling

  private func adopt(_ new: any GameSession) {
    session = new
    accumulator = 0
    isPaused = false
    panel.isPaused = false
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
    guard let flow, dataSets.indices.contains(gamePicker.indexOfSelectedItem) else { return }
    let key = "\(flowProgressKey).\(dataSets[gamePicker.indexOfSelectedItem].set.identifierKey)"
    if let data = try? JSONEncoder().encode(flow.progress) {
      UserDefaults.standard.set(data, forKey: key)
    }
    rebuildLibrary()
  }

  /// Draws whichever screen the game is on.
  private func renderScreen() {
    guard let flow else { return }
    if !sequelIsActive {
      window.title = flow.screen == .title ? "Lemmings — Game Library"
        : activeTitle?.displayName ?? campaign?.name ?? "Lemmings"
    }
    playfield.overlayHighlight = nil
    panel.isMenuMode = !flow.screen.isPlaying
    fitClassicDisplay()

    switch flow.screen {
    case .title:
      if playfield.levelImage == nil, let entry = campaign?.levels.first {
        buildLevel(entry)
      }
      setStatus("")
      phase = .briefing
      playfield.phase = .briefing
      playfield.overlayShowsLemmings = true
      playfield.overlayTitle = "LEMMINGS"
      playfield.overlayLines = ["FULL QUEST  \(library.passed)/\(library.total)"] + library.entries.map { entry in
        let progress = entry.available ? "  \(entry.passed)/\(entry.total)" : ""
        let detail = entry.detail.isEmpty ? "" : "  — \(entry.detail)"
        return entry.title.displayName + progress + detail
      }
      playfield.overlayHighlight = min(launchChoice, library.entries.count)
      playfield.overlayFooter = "CLICK TO PLAY  *  UP DOWN ENTER  *  LIBRARY CMD-SHIFT-L"

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
      ]
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
    playfield.overlayLines = lines
    playfield.overlayFooter =
      "\(flow.currentRank?.name ?? "") \(flow.currentNumber)   •   Click or space to begin"
    setStatus("")
  }

  /// Moves past whichever screen is showing.
  private func advancePhase() {
    guard var current = flow else { return }
    switch current.screen {
    case .title:
      if launchChoice == 0 {
        launchMode = .quest
        if let title = library.questStart { launchTitle(title) }
      } else if library.entries.indices.contains(launchChoice - 1) {
        let entry = library.entries[launchChoice - 1]
        guard entry.available else {
          let alert = NSAlert()
          alert.messageText = entry.title.displayName
          alert.informativeText = "This release is archived in the bundle but has no playable data import yet."
          alert.runModal()
          return
        }
        launchMode = .singleTitle
        launchTitle(entry.title)
      }
      return
    case .rankSelect: current.selectRank(rankChoice)
    case .briefing:
      current.beginPlaying()
      flow = current
      renderScreen()
      effects.play(.levelStart)
      return
    case .results:
      current.acknowledgeResults()
    case .rankComplete: current.acknowledgeRankComplete()
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
    if let flow, flow.screen == .title {
      let count = library.entries.count + 1
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
    timer = Timer.scheduledTimer(withTimeInterval: displayInterval, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.step() }
    }
  }

  private func step() {
    guard !sequelIsActive else { return }
    applyEdgeScroll()
    // Menus animate even though the level clock is stopped.
    if phase != .playing, playfield.overlayShowsLemmings {
      playfield.overlayFrame &+= 1
      playfield.needsDisplay = true
    }
    if tubeIsActive, let frame = composeNativeFrame() {
      crtView.setSource(frame)
    }
    guard phase == .playing, !isPaused, let session, !session.isComplete else { return }

    // Each ruleset states its own logic rate. Whole ticks only, so timing does
    // not drift with the display.
    let interval = 1.0 / Double(session.ticksPerSecond)
    accumulator += displayInterval
    var advanced = false
    while accumulator >= interval {
      accumulator -= interval
      session.tick()
      advanced = true
      if session.isComplete { break }
    }
    guard advanced else { return }

    effects.play(session.lastCues)
    panel.terrainImage = playfield.levelImage
    playfield.needsDisplay = true
    panel.needsDisplay = true
    updateStatus()
    if session.isComplete {
      recordCompletion(session)
      if var current = flow {
        current.finishLevel(
          saved: session.saved, required: session.required, total: session.total)
        flow = current
        saveProgress()
        renderScreen()
      }
    }
  }

  private func applyEdgeScroll() {
    guard phase == .playing, let delta = playfield.edgeScrollDelta, delta != 0 else { return }
    playfield.viewport.scroll(dx: delta, dy: 0)
    playfield.needsDisplay = true
    syncPanelViewport()
  }

  private func recordCompletion(_ session: any GameSession) {
    guard currentNxlvURL == nil else { return }
    progress.record(
      levelIndex: picker.indexOfSelectedItem, saved: session.saved, required: session.required)
    if let data = try? progress.encoded() {
      UserDefaults.standard.set(data, forKey: progressKey)
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
      UserDefaults.standard.set(data, forKey: achievementProgressKey)
    }
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
      panel.needsDisplay = true
    case .pause: togglePause()
    case .nuke: session.nuke()
    }
    updateStatus()
  }

  private func togglePause() {
    isPaused.toggle()
    panel.isPaused = isPaused
    panel.needsDisplay = true
  }

  private func assign(_ id: Int) {
    guard let session else { return }
    let rejection = session.assign(skillIndex: panel.selectedSkillIndex, to: id)
    playfield.needsDisplay = true
    panel.needsDisplay = true
    if let rejection {
      setStatus("Cannot assign: \(rejection)")
    } else {
      updateStatus()
    }
  }

  // MARK: - Music

  @objc private func chooseMusic() {
    guard let url = pickDirectory("Choose a folder of ProTracker .mod files.") else { return }
    UserDefaults.standard.set(url.path, forKey: musicPathKey)
    music.loadLibrary(at: url)
    if music.library.isEmpty {
      setStatus("No .mod files were found in that folder.")
    } else {
      playMusicForCurrentLevel()
    }
  }

  @objc private func chooseSounds() {
    let openPanel = NSOpenPanel()
    openPanel.canChooseFiles = true
    openPanel.canChooseDirectories = false
    openPanel.allowedFileTypes = ["dsk", "img", "dmg", "hfs"]
    openPanel.message = "Choose a Macintosh Lemmings disk image."
    guard openPanel.runModal() == .OK, let url = openPanel.url else { return }
    UserDefaults.standard.set(url.path, forKey: macImageKey)
    loadSoundEffects(from: url)
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

  @objc private func toggleMute() {
    let muted = !music.muted
    music.setMuted(muted)
    effects.setMuted(muted)
    nativeL2Window?.setMuted(muted)
    updateMusicButtons()
  }

  @objc private func toggleMusicPreset() {
    let useModern = !music.usesModernPreset
    music.setEnhancements(useModern ? .modern : .faithful)
    UserDefaults.standard.set(useModern, forKey: musicPresetKey)
    updateMusicButtons()
  }

  private func updateMusicButtons() {
    muteItem?.state = music.muted ? .on : .off
    presetItem?.state = music.usesModernPreset ? .on : .off
  }

  /// Every folder of recordings beside the modules is one soundtrack.
  ///
  /// The player adds these. A folder of Amiga rips, a console version or a
  /// remix all work the same way, and each appears in the settings by name.
  private func loadSoundtracks() {
    guard let root = Bundle.main.resourceURL?.appendingPathComponent("Music") else { return }
    soundtrackLibrary = SoundtrackPlayer.soundtracks(at: root)
  }

  /// The original cycles through its tunes as the campaign advances.
  private func playMusicForCurrentLevel() {
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
    guard !music.library.isEmpty else { return }
    let index = currentNxlvURL == nil ? max(0, picker.indexOfSelectedItem) : 0
    if let title = music.play(index: index) {
      setStatus("♪ \(title)")
    }
  }

  @objc private func zoomIn() { setZoom(playfield.viewport.zoom + 1) }
  @objc private func zoomOut() { setZoom(playfield.viewport.zoom - 1) }

  private func setZoom(_ value: Double) {
    playfield.viewport.zoom = min(8, max(1, value))
    playfield.viewport.clamp()
    playfield.needsDisplay = true
    syncPanelViewport()
  }

  private func retry() {
    if let url = currentNxlvURL {
      loadNxlv(url)
    } else {
      levelChanged()
    }
  }

  private func nextLevel() {
    guard currentNxlvURL == nil, let campaign else { return }
    let next = picker.indexOfSelectedItem + 1
    guard next < campaign.levels.count else {
      _ = advanceToNextTitle()
      return
    }
    picker.selectItem(at: next)
    levelChanged()
  }

  private func installKeyboardShortcuts() {
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self else { return event }
      guard !self.sequelIsActive, event.window === self.window,
        event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
      if self.window?.firstResponder is NSTextView { return event }

      let scrollStep = 24.0
      switch event.keyCode {
      case 123: self.scrollBy(-scrollStep); return nil
      case 124: self.scrollBy(scrollStep); return nil
      default: break
      }

      guard let characters = event.charactersIgnoringModifiers?.lowercased() else { return event }
      if let digit = Int(characters), digit >= 1, digit <= 9 {
        self.handle(.skill(digit - 1))
        return nil
      }
      // Screen keys come first, so they are not eaten by gameplay bindings.
      if let screen = self.flow?.screen, !screen.isPlaying {
        switch event.keyCode {
        case 125: self.moveRankChoice(1); return nil     // down
        case 126: self.moveRankChoice(-1); return nil    // up
        case 36, 76: self.advancePhase(); return nil     // return, enter
        case 53:                                          // escape
          if screen == .quitConfirm { self.cancelQuit() }
          else { self.returnToLibrary() }
          return nil
        default: break
        }
        if characters == " " { self.advancePhase(); return nil }
        if characters == "q" { self.requestQuit(); return nil }
      }

      switch characters {
      case "z": self.rewind(seconds: 2)
      case ",": self.stepBackward()
      case ".": self.stepForward()
      case "\r": self.advancePhase()
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
      case "x": self.handle(.nuke)
      default: return event
      }
      return nil
    }
  }

  // MARK: - Rewind

  private func rewind(seconds: Double) {
    guard let session, session.supportsRewind else {
      setStatus("This ruleset cannot rewind yet.")
      return
    }
    guard session.rewind(seconds: seconds) else {
      setStatus("Already at the start of the history.")
      return
    }
    isPaused = true
    panel.isPaused = true
    refreshAfterSeek()
  }

  private func stepBackward() {
    guard let session, session.supportsRewind, session.stepBackward() else { return }
    isPaused = true
    panel.isPaused = true
    refreshAfterSeek()
  }

  private func stepForward() {
    guard let session, session.stepForward() else { return }
    isPaused = true
    panel.isPaused = true
    refreshAfterSeek()
  }

  /// Redraws after moving through history, without playing sounds again.
  private func refreshAfterSeek() {
    accumulator = 0
    playfield.needsDisplay = true
    panel.needsDisplay = true
    updateStatus()
  }

  private func scrollBy(_ dx: Double) {
    playfield.viewport.scroll(dx: dx, dy: 0)
    playfield.needsDisplay = true
    syncPanelViewport()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
