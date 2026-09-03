import AppKit
import NxlvKit

let displayInterval = 1.0 / 60.0
let contentPathKey = "ClassicDataDirectory"
let stylesPathKey = "NeoLemmixStylesDirectory"
let progressKey = "ModernCampaignProgress"
let musicPathKey = "MusicDirectory"
let musicPresetKey = "MusicUsesModernPreset"

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
  private var window: NSWindow!
  private let playfield = PlayfieldView()
  private let panel = PanelView()
  private let picker = NSPopUpButton()

  private var campaign: ClassicCampaign?
  private var grounds: [Int: ClassicGroundSet] = [:]
  private var specials: [Int: ClassicSpecialGraphic] = [:]
  private var assets: ClassicMainDATAssets?
  private var contentDirectory: URL?
  private var stylesDirectory: URL?

  private var session: (any GameSession)?
  private var timer: Timer?
  private var accumulator = 0.0
  private var isPaused = false
  private var progress = ModernCampaignProgress()
  private let music = ModuleMusicPlayer()
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
      title: "Import DOS data…", target: self, action: #selector(chooseContent))
    let openNxlv = NSButton(
      title: "Open .nxlv…", target: self, action: #selector(chooseNxlvLevel))
    let zoomOut = NSButton(title: "−", target: self, action: #selector(zoomOut))
    let zoomIn = NSButton(title: "+", target: self, action: #selector(zoomIn))
    let musicButton = NSButton(
      title: "Music…", target: self, action: #selector(chooseMusic))
    let mute = NSButton(title: "Mute", target: self, action: #selector(toggleMute))
    let preset = NSButton(
      title: "Faithful", target: self, action: #selector(toggleMusicPreset))
    muteButton = mute
    presetButton = preset

    let views: [NSView] = [
      picker, importButton, openNxlv, zoomOut, zoomIn,
      musicButton, mute, preset, playfield, panel,
    ]
    for view in views {
      view.translatesAutoresizingMaskIntoConstraints = false
      root.addSubview(view)
    }

    NSLayoutConstraint.activate([
      picker.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
      picker.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
      picker.widthAnchor.constraint(equalToConstant: 300),
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
      mute.leadingAnchor.constraint(equalTo: musicButton.trailingAnchor, constant: 6),
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
    playfield.onAssign = { [weak self] id in self?.assign(id) }
    playfield.onViewportChanged = { [weak self] in self?.syncPanelViewport() }
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
    contentDirectory = url
    UserDefaults.standard.set(url.path, forKey: contentPathKey)
    loadContent()
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

  private func loadContent() {
    guard let directory = contentDirectory else {
      setStatus("Import DOS data, or open a .nxlv level.")
      return
    }
    do {
      let loaded = try ClassicCampaignDefinition.originalDOSLemmings.load(from: directory)
      campaign = loaded
      grounds = [:]
      specials = [:]
      for style in 0..<5 {
        grounds[style] = try ClassicGroundSet.load(style: style, from: directory)
      }
      for index in 0..<4 {
        specials[index + 1] = try ClassicSpecialGraphic.load(index: index, from: directory)
      }
      assets = try ClassicMainDATAssets.load(from: directory)
      playfield.assets = assets
      playfield.invalidateSprites()

      picker.removeAllItems()
      for (offset, entry) in loaded.levels.enumerated() {
        picker.addItem(withTitle: "\(offset + 1). \(entry.rank) — \(entry.level.title)")
      }
      picker.selectItem(at: 0)
      levelChanged()
    } catch {
      setStatus("Content error: \(error)")
    }
  }

  // MARK: - Official levels

  @objc private func levelChanged() {
    guard let campaign, picker.indexOfSelectedItem < campaign.levels.count else { return }
    currentNxlvURL = nil
    let entry = campaign.levels[picker.indexOfSelectedItem]
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
    playfield.needsDisplay = true
    playMusicForCurrentLevel()
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
    guard !isPaused, let session, !session.isComplete else { return }

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

    playfield.needsDisplay = true
    panel.needsDisplay = true
    updateStatus()
    if session.isComplete { recordCompletion(session) }
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

  @objc private func toggleMute() {
    music.setMuted(!music.muted)
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
      switch characters {
      case "n": self.nextLevel()
      case "r": self.retry()
      case "p", " ": self.togglePause()
      case "x": self.handle(.nuke)
      default: return event
      }
      return nil
    }
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
