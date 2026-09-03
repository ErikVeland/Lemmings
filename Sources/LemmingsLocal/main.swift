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

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
  private var window: NSWindow!
  private let playfield = PlayfieldView()
  private let panel = PanelView()
  private let picker = NSPopUpButton()

  private var campaign: ClassicCampaign?
  private var grounds: [Int: ClassicGroundSet] = [:]
  private var specials: [Int: ClassicSpecialGraphic] = [:]
  /// Every imported game, in the order they were added.
  private var dataSets: [(set: ClassicDataSet, directory: URL)] = []
  private let gamePicker = NSPopUpButton()
  private var assets: ClassicMainDATAssets?
  private var contentDirectory: URL?
  private var stylesDirectory: URL?

  private var session: (any GameSession)?
  private var timer: Timer?
  private var accumulator = 0.0
  private var isPaused = false
  private var phase: GamePhase = .briefing
  /// The whole game, from title to end.
  private var flow: ClassicGameFlow?
  private var rankChoice = 0
  private var progress = ModernCampaignProgress()
  private let music = ModuleMusicPlayer()
  private let effects = SoundEffectPlayer()
  private var muteButton: NSButton!
  private var presetButton: NSButton!
  /// Set while an unofficial level is loaded, so retry reloads that file.
  private var currentNxlvURL: URL?

  func applicationDidFinishLaunching(_ notification: Notification) {
    buildInterface()
    installKeyboardShortcuts()

    if let saved = UserDefaults.standard.string(forKey: contentPathKey) {
      contentDirectory = URL(fileURLWithPath: saved, isDirectory: true)
    }
    if let saved = UserDefaults.standard.string(forKey: stylesPathKey) {
      stylesDirectory = URL(fileURLWithPath: saved, isDirectory: true)
    }
    if let data = UserDefaults.standard.data(forKey: progressKey),
      let saved = try? ModernCampaignProgress(encoded: data) {
      progress = saved
    }
    if let saved = UserDefaults.standard.string(forKey: musicPathKey) {
      music.loadLibrary(at: URL(fileURLWithPath: saved, isDirectory: true))
    }
    if UserDefaults.standard.bool(forKey: musicPresetKey) {
      music.setEnhancements(.modern)
    }
    do {
      try effects.start()
      if let saved = UserDefaults.standard.string(forKey: macImageKey) {
        loadSoundEffects(from: URL(fileURLWithPath: saved))
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
  }

  // MARK: - Interface

  private func buildInterface() {
    let root = NSView()
    let importButton = NSButton(
      title: "Add game…", target: self, action: #selector(chooseContent))
    let openNxlv = NSButton(
      title: "Open .nxlv…", target: self, action: #selector(chooseNxlvLevel))
    let zoomOut = NSButton(title: "−", target: self, action: #selector(zoomOut))
    let zoomIn = NSButton(title: "+", target: self, action: #selector(zoomIn))
    let musicButton = NSButton(
      title: "Music…", target: self, action: #selector(chooseMusic))
    let soundButton = NSButton(
      title: "Sounds…", target: self, action: #selector(chooseSounds))
    let mute = NSButton(title: "Mute", target: self, action: #selector(toggleMute))
    let preset = NSButton(
      title: "Faithful", target: self, action: #selector(toggleMusicPreset))
    muteButton = mute
    presetButton = preset

    let views: [NSView] = [
      gamePicker, picker, importButton, openNxlv, zoomOut, zoomIn,
      musicButton, soundButton, mute, preset, playfield, panel,
    ]
    for view in views {
      view.translatesAutoresizingMaskIntoConstraints = false
      root.addSubview(view)
    }

    NSLayoutConstraint.activate([
      gamePicker.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
      gamePicker.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
      gamePicker.widthAnchor.constraint(equalToConstant: 210),
      picker.leadingAnchor.constraint(equalTo: gamePicker.trailingAnchor, constant: 8),
      picker.centerYAnchor.constraint(equalTo: gamePicker.centerYAnchor),
      picker.widthAnchor.constraint(equalToConstant: 260),
      importButton.leadingAnchor.constraint(equalTo: picker.trailingAnchor, constant: 8),
      importButton.centerYAnchor.constraint(equalTo: picker.centerYAnchor),
      openNxlv.leadingAnchor.constraint(equalTo: importButton.trailingAnchor, constant: 6),
      openNxlv.centerYAnchor.constraint(equalTo: picker.centerYAnchor),
      zoomOut.leadingAnchor.constraint(equalTo: openNxlv.trailingAnchor, constant: 12),
      zoomOut.centerYAnchor.constraint(equalTo: picker.centerYAnchor),
      zoomIn.leadingAnchor.constraint(equalTo: zoomOut.trailingAnchor, constant: 4),
      zoomIn.centerYAnchor.constraint(equalTo: picker.centerYAnchor),
      musicButton.leadingAnchor.constraint(equalTo: zoomIn.trailingAnchor, constant: 12),
      musicButton.centerYAnchor.constraint(equalTo: picker.centerYAnchor),
      soundButton.leadingAnchor.constraint(equalTo: musicButton.trailingAnchor, constant: 6),
      soundButton.centerYAnchor.constraint(equalTo: picker.centerYAnchor),
      mute.leadingAnchor.constraint(equalTo: soundButton.trailingAnchor, constant: 6),
      mute.centerYAnchor.constraint(equalTo: picker.centerYAnchor),
      preset.leadingAnchor.constraint(equalTo: mute.trailingAnchor, constant: 6),
      preset.centerYAnchor.constraint(equalTo: picker.centerYAnchor),

      playfield.leadingAnchor.constraint(equalTo: root.leadingAnchor),
      playfield.trailingAnchor.constraint(equalTo: root.trailingAnchor),
      playfield.topAnchor.constraint(equalTo: picker.bottomAnchor, constant: 10),
      playfield.bottomAnchor.constraint(equalTo: panel.topAnchor),

      panel.leadingAnchor.constraint(equalTo: root.leadingAnchor),
      panel.trailingAnchor.constraint(equalTo: root.trailingAnchor),
      panel.bottomAnchor.constraint(equalTo: root.bottomAnchor),
      panel.heightAnchor.constraint(equalToConstant: panel.intrinsicHeight),
    ])

    picker.target = self
    picker.action = #selector(levelChanged)
    gamePicker.target = self
    gamePicker.action = #selector(selectDataSet)
    playfield.onAssign = { [weak self] id in self?.assign(id) }
    playfield.onViewportChanged = { [weak self] in self?.syncPanelViewport() }
    playfield.onAdvancePhase = { [weak self] in self?.advancePhase() }
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
    window.title = "Lemmings — Native macOS Port"
    window.contentView = root
    window.center()
    window.makeKeyAndOrderFront(nil)
    window.makeFirstResponder(playfield)
  }

  // MARK: - Content

  @objc private func chooseContent() {
    guard let url = pickDirectory("Choose the directory holding LEVEL000.DAT and MAIN.DAT.")
    else { return }
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
    guard !directories.isEmpty else {
      setStatus("Add a game folder, or open a .nxlv level.")
      return
    }

    // A folder is identified rather than assumed, so any title in this
    // format loads without a hand-written order table.
    dataSets = []
    var problems: [String] = []
    for directory in directories {
      do {
        let set = try ClassicDataSet.detect(directory: directory)
        dataSets.append((set, directory))
      } catch {
        problems.append("\(directory.lastPathComponent): \(error)")
      }
    }

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
  }

  @objc private func selectDataSet() {
    let index = max(0, min(gamePicker.indexOfSelectedItem, dataSets.count - 1))
    guard index < dataSets.count else { return }
    let entry = dataSets[index]
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

      campaign = entry.set.campaign
      var built = ClassicGameFlow(campaign: entry.set.campaign)
      if let data = UserDefaults.standard.data(
        forKey: "\(flowProgressKey).\(entry.set.identifierKey)"),
        let saved = try? JSONDecoder().decode(ClassicGameFlow.Progress.self, from: data) {
        built.restore(saved)
      }
      flow = built
      rankChoice = 0
      picker.removeAllItems()
      for (offset, level) in entry.set.campaign.levels.enumerated() {
        picker.addItem(withTitle: "\(offset + 1). \(level.rank) — \(level.level.title)")
      }
      picker.selectItem(at: 0)
      showTitle()
    } catch {
      setStatus("\(entry.set.name): \(error)")
    }
  }

  // MARK: - Official levels

  /// Loads the level at a campaign index without changing the flow.
  private func loadLevel(at index: Int) {
    guard let campaign, index < campaign.levels.count else { return }
    picker.selectItem(at: index)
    buildLevel(campaign.levels[index])
  }

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
      playfield.levelImage = image
      if let palette = try? ClassicLemmingPalette.inLevelVGA(terrainPalette: ground.terrainPalette) {
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
    } catch {
      setStatus("Level error: \(error)")
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
    // Start the view over the first hatch, as the original game does.
    if let entrance = new.entranceX { playfield.viewport.center(on: Double(entrance)) }
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
    guard let flow, gamePicker.indexOfSelectedItem < dataSets.count else { return }
    let key = "\(flowProgressKey).\(dataSets[gamePicker.indexOfSelectedItem].set.identifierKey)"
    if let data = try? JSONEncoder().encode(flow.progress) {
      UserDefaults.standard.set(data, forKey: key)
    }
  }

  /// Draws whichever screen the game is on.
  private func renderScreen() {
    guard let flow else { return }
    playfield.overlayHighlight = nil

    switch flow.screen {
    case .title:
      phase = .briefing
      playfield.phase = .briefing
      let name = dataSets.indices.contains(gamePicker.indexOfSelectedItem)
        ? dataSets[gamePicker.indexOfSelectedItem].set.name : "Lemmings"
      playfield.overlayTitle = name
      playfield.overlayLines = ["A native macOS port", "Data supplied by the player"]
      playfield.overlayFooter = "Click or press space to begin   •   Q to quit"

    case .rankSelect:
      phase = .briefing
      playfield.phase = .briefing
      playfield.overlayTitle = "Choose a rating"
      playfield.overlayLines = flow.ranks.map { rank in
        let done = flow.passedCount(inRank: rank.name)
        return "\(rank.name)  \(done)/\(rank.levelIndices.count)"
      }
      playfield.overlayHighlight = rankChoice
      playfield.overlayFooter = "Up and down to choose   •   Enter to start"

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
        ? "Click or press Enter to continue"
        : "Click or press Enter to try again"

    case let .rankComplete(rank):
      phase = .results
      playfield.phase = .results
      playfield.overlayTitle = "\(rank) complete"
      playfield.overlayLines = ["Every level in this rating is done."]
      playfield.overlayFooter = "Click or press Enter to continue"

    case .gameComplete:
      phase = .results
      playfield.phase = .results
      playfield.overlayTitle = "Game complete"
      playfield.overlayLines = ["Every rating is finished."]
      playfield.overlayFooter = "Click or press Enter to return to the title"

    case .quitConfirm:
      phase = .results
      playfield.phase = .results
      playfield.overlayTitle = "Quit?"
      playfield.overlayLines = ["Progress is saved."]
      playfield.overlayFooter = "Q again to quit   •   Escape to stay"
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
    case .title: current.startGame()
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
    case .gameComplete: current.acknowledgeGameComplete()
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
    guard let flow, flow.screen == .rankSelect, !flow.ranks.isEmpty else { return }
    rankChoice = (rankChoice + delta + flow.ranks.count) % flow.ranks.count
    renderScreen()
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
    applyEdgeScroll()
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
    guard let delta = playfield.edgeScrollDelta, delta != 0 else { return }
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
    if session.supportsRewind { parts.append("t\(session.currentTick)") }
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
    updateMusicButtons()
  }

  @objc private func toggleMusicPreset() {
    let useModern = !music.usesModernPreset
    music.setEnhancements(useModern ? .modern : .faithful)
    UserDefaults.standard.set(useModern, forKey: musicPresetKey)
    updateMusicButtons()
  }

  private func updateMusicButtons() {
    muteButton?.title = music.muted ? "Unmute" : "Mute"
    presetButton?.title = music.usesModernPreset ? "Modern" : "Faithful"
  }

  /// The original cycles through its tunes as the campaign advances.
  private func playMusicForCurrentLevel() {
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
    guard next < campaign.levels.count else { return }
    picker.selectItem(at: next)
    levelChanged()
  }

  private func installKeyboardShortcuts() {
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self else { return event }
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
