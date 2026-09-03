import AppKit
import NxlvKit

// The DOS game advances logic in fixed 17 Hz ticks. The display refreshes far
// faster, so the run loop accumulates real time and steps whole ticks only.
// Any drift here desynchronises release intervals and hatch timing.
let logicTickInterval = 1.0 / Double(ClassicDOSRules.ticksPerSecond)
let displayInterval = 1.0 / 60.0
let contentPathKey = "ClassicDataDirectory"
let progressKey = "ModernCampaignProgress"

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
  private var window: NSWindow!
  private let playfield = PlayfieldView()
  private let panel = PanelView()
  private let picker = NSPopUpButton()

  private var campaign: ClassicCampaign?
  private var grounds: [Int: ClassicGroundSet] = [:]
  private var specials: [Int: ClassicSpecialGraphic] = [:]
  private var assets: ClassicMainDATAssets?
  private var simulation: ClassicDOSSimulation?
  private var contentDirectory: URL?

  private var timer: Timer?
  private var accumulator = 0.0
  private var isPaused = false
  private var progress = ModernCampaignProgress()

  func applicationDidFinishLaunching(_ notification: Notification) {
    buildInterface()
    installKeyboardShortcuts()

    if let saved = UserDefaults.standard.string(forKey: contentPathKey) {
      contentDirectory = URL(fileURLWithPath: saved, isDirectory: true)
    }
    if let data = UserDefaults.standard.data(forKey: progressKey),
      let saved = try? ModernCampaignProgress(encoded: data) {
      progress = saved
    }
    loadContent()
    startTimer()
  }

  // MARK: - Interface

  private func buildInterface() {
    let root = NSView()
    let importButton = NSButton(
      title: "Import original DOS data…", target: self, action: #selector(chooseContent))
    let zoomOut = NSButton(title: "−", target: self, action: #selector(zoomOut))
    let zoomIn = NSButton(title: "+", target: self, action: #selector(zoomIn))

    for view in [picker, importButton, zoomOut, zoomIn, playfield, panel] {
      view.translatesAutoresizingMaskIntoConstraints = false
      root.addSubview(view)
    }

    NSLayoutConstraint.activate([
      picker.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
      picker.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
      picker.widthAnchor.constraint(equalToConstant: 340),
      importButton.leadingAnchor.constraint(equalTo: picker.trailingAnchor, constant: 8),
      importButton.centerYAnchor.constraint(equalTo: picker.centerYAnchor),
      zoomOut.leadingAnchor.constraint(equalTo: importButton.trailingAnchor, constant: 12),
      zoomOut.centerYAnchor.constraint(equalTo: picker.centerYAnchor),
      zoomIn.leadingAnchor.constraint(equalTo: zoomOut.trailingAnchor, constant: 4),
      zoomIn.centerYAnchor.constraint(equalTo: picker.centerYAnchor),

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
      self?.playfield.viewport.center(on: centerX)
      self?.playfield.needsDisplay = true
      self?.syncPanelViewport()
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
    let openPanel = NSOpenPanel()
    openPanel.canChooseDirectories = true
    openPanel.canChooseFiles = false
    openPanel.allowsMultipleSelection = false
    openPanel.message = "Choose the directory containing LEVEL000.DAT, GROUND0O.DAT and MAIN.DAT."
    guard openPanel.runModal() == .OK, let url = openPanel.url else { return }
    contentDirectory = url
    UserDefaults.standard.set(url.path, forKey: contentPathKey)
    loadContent()
  }

  private func loadContent() {
    guard let directory = contentDirectory else {
      panel.statusText = "Choose a DOS data directory to begin."
      panel.needsDisplay = true
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
      panel.statusText = "Content error: \(error)"
      panel.needsDisplay = true
    }
  }

  // MARK: - Level

  @objc private func levelChanged() {
    guard let campaign, picker.indexOfSelectedItem < campaign.levels.count else { return }
    let entry = campaign.levels[picker.indexOfSelectedItem]
    let level = entry.level
    do {
      guard let ground = grounds[level.groundStyle] else { return }
      let rendered = try ClassicLevelRenderer.render(
        level, groundSet: ground, specialGraphic: specials[level.specialStyle])

      guard let provider = CGDataProvider(data: rendered.rgba as CFData),
        let image = CGImage(
          width: rendered.width, height: rendered.height, bitsPerComponent: 8, bitsPerPixel: 32,
          bytesPerRow: rendered.width * 4, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
          provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
      else { return }

      playfield.levelImage = image
      if let palette = try? ClassicLemmingPalette.inLevelVGA(terrainPalette: ground.terrainPalette) {
        playfield.palette = palette
        playfield.invalidateSprites()
      }

      // The DOS engine derives entrances, exits and hazards from the level's
      // own trigger zones, so nothing is positioned by hand here.
      let built: ClassicDOSSimulation
      if let assets {
        built = try ClassicDOSSimulation(
          level: level, renderedLevel: rendered, mainDATAssets: assets)
      } else {
        built = try ClassicDOSSimulation(level: level, renderedLevel: rendered)
      }
      simulation = built
      accumulator = 0
      isPaused = false
      panel.isPaused = false

      playfield.simulation = built
      playfield.viewport.levelSize = CGSize(width: rendered.width, height: rendered.height)
      panel.levelSize = playfield.viewport.levelSize
      // Start the view over the first hatch, as the original game does.
      if let entrance = built.configuration.entrances.first {
        playfield.viewport.center(on: Double(entrance.x))
      }
      panel.simulation = built
      // Arm the first skill the level actually provides.
      if let first = ClassicSkill.allCases.first(where: { built.remainingSkillCount($0) > 0 }) {
        panel.selectedSkill = first
      }
      syncPanelViewport()
      updateStatus()
      playfield.needsDisplay = true
    } catch {
      panel.statusText = "Level error: \(error)"
      panel.needsDisplay = true
    }
  }

  private func syncPanelViewport() {
    panel.visibleLevelRect = playfield.viewport.visibleLevelRect
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
    guard !isPaused, var simulation, !simulation.isComplete else { return }

    accumulator += displayInterval
    var advanced = false
    while accumulator >= logicTickInterval {
      accumulator -= logicTickInterval
      _ = simulation.tick()
      advanced = true
      if simulation.isComplete { break }
    }
    guard advanced else { return }

    self.simulation = simulation
    playfield.simulation = simulation
    panel.simulation = simulation
    playfield.needsDisplay = true
    updateStatus()

    if simulation.isComplete { recordCompletion(simulation) }
  }

  private func applyEdgeScroll() {
    guard let delta = playfield.edgeScrollDelta, delta != 0 else { return }
    playfield.viewport.scroll(dx: delta, dy: 0)
    playfield.needsDisplay = true
    syncPanelViewport()
  }

  private func recordCompletion(_ simulation: ClassicDOSSimulation) {
    progress.record(
      levelIndex: picker.indexOfSelectedItem,
      saved: simulation.savedCount,
      required: simulation.configuration.requiredToSave)
    if let data = try? progress.encoded() {
      UserDefaults.standard.set(data, forKey: progressKey)
    }
  }

  private func updateStatus() {
    guard let simulation else { return }
    let time = simulation.remainingTimeSeconds.map { String(format: "%d:%02d", $0 / 60, $0 % 60) }
    var parts = [
      "Out \(simulation.releasedCount)/\(simulation.configuration.totalLemmings)",
      "Home \(simulation.savedCount)/\(simulation.configuration.requiredToSave)",
      "Rate \(simulation.releaseRate)",
    ]
    if let time { parts.append("Time \(time)") }
    if simulation.isNuking { parts.append("NUKING") }
    if simulation.isComplete {
      parts.append(simulation.didWin ? "COMPLETE — press N" : "FAILED — press R")
    }
    panel.statusText = parts.joined(separator: "   ")
    panel.needsDisplay = true
  }

  // MARK: - Commands

  private func handle(_ button: PanelButton) {
    switch button {
    case .rateDown: adjustReleaseRate(-1)
    case .rateUp: adjustReleaseRate(1)
    case let .skill(skill):
      panel.selectedSkill = skill
      panel.needsDisplay = true
    case .pause: togglePause()
    case .nuke:
      guard var simulation else { return }
      simulation.beginNuke()
      self.simulation = simulation
      playfield.simulation = simulation
      panel.simulation = simulation
      updateStatus()
    }
  }

  private func adjustReleaseRate(_ delta: Int) {
    guard var simulation else { return }
    simulation.setReleaseRate(simulation.releaseRate + delta)
    self.simulation = simulation
    panel.simulation = simulation
    updateStatus()
  }

  private func togglePause() {
    isPaused.toggle()
    panel.isPaused = isPaused
    panel.needsDisplay = true
  }

  private func assign(_ id: Int) {
    guard var simulation else { return }
    let result = simulation.assign(panel.selectedSkill, to: id)
    self.simulation = simulation
    playfield.simulation = simulation
    panel.simulation = simulation
    playfield.needsDisplay = true
    if result == .assigned {
      updateStatus()
    } else {
      panel.statusText = "Cannot assign \(panel.selectedSkill.rawValue): \(result.rawValue)"
      panel.needsDisplay = true
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

  private func retry() { levelChanged() }

  private func nextLevel() {
    guard let campaign else { return }
    let next = picker.indexOfSelectedItem + 1
    guard next < campaign.levels.count else { return }
    picker.selectItem(at: next)
    levelChanged()
  }

  private func installKeyboardShortcuts() {
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self else { return event }
      // Let text fields and the level popup keep their own key handling.
      if self.window?.firstResponder is NSTextView { return event }

      let scrollStep = 24.0
      switch event.keyCode {
      case 123: self.scrollBy(-scrollStep); return nil
      case 124: self.scrollBy(scrollStep); return nil
      default: break
      }

      switch event.charactersIgnoringModifiers?.lowercased() {
      case "n": self.nextLevel()
      case "r": self.retry()
      case "p", " ": self.togglePause()
      case "x": self.handle(.nuke)
      case "1": self.handle(.skill(.climber))
      case "2": self.handle(.skill(.floater))
      case "3": self.handle(.skill(.bomber))
      case "4": self.handle(.skill(.blocker))
      case "5": self.handle(.skill(.builder))
      case "6": self.handle(.skill(.basher))
      case "7": self.handle(.skill(.miner))
      case "8": self.handle(.skill(.digger))
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
