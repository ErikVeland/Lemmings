import AppKit
import NxlvKit

// The DOS game advances logic in fixed 17 Hz ticks. The display refreshes far
// faster, so the run loop accumulates real time and steps whole ticks only.
// Any drift here desynchronises release intervals and hatch timing.
private let logicTickInterval = 1.0 / Double(ClassicDOSRules.ticksPerSecond)
private let displayInterval = 1.0 / 60.0
private let contentPathKey = "ClassicDataDirectory"

private func spritePose(for action: ClassicDOSAction) -> ClassicLemmingPose {
  switch action {
  case .walking: return .walking
  case .falling: return .falling
  case .jumping: return .jumping
  case .climbing: return .climbing
  case .hoisting: return .postClimb
  case .floating: return .floating
  case .splatting: return .splatting
  case .exiting: return .exiting
  case .drowning: return .drowning
  case .vaporizing: return .frying
  case .blocking: return .blocking
  case .building: return .building
  case .shrugging: return .shrugging
  case .bashing: return .bashing
  case .mining: return .mining
  case .digging: return .digging
  case .ohNo: return .ohNo
  case .exploding: return .explosion
  }
}

@MainActor final class GameView: NSView {
  var image: NSImage?
  var simulation: ClassicDOSSimulation?
  var assets: ClassicMainDATAssets?
  var palette: [ClassicRGBColor] = []
  var onClick: ((Int) -> Void)?

  private var spriteCache: [String: NSImage] = [:]

  /// Maps the rendered level onto the view, preserving aspect ratio.
  private func layout() -> (origin: NSPoint, scale: CGFloat)? {
    guard let image, image.size.width > 0, image.size.height > 0 else { return nil }
    let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
    let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
    let origin = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
    return (origin, scale)
  }

  override func draw(_ rect: NSRect) {
    NSColor.black.setFill()
    rect.fill()
    guard let image, let (origin, scale) = layout() else { return }
    let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
    NSGraphicsContext.current?.imageInterpolation = .none
    image.draw(in: NSRect(origin: origin, size: size))

    guard let simulation else { return }
    for lemming in simulation.lemmings where lemming.isActive {
      draw(lemming, origin: origin, scale: scale, levelHeight: image.size.height)
    }
  }

  private func draw(
    _ lemming: ClassicDOSLemming, origin: NSPoint, scale: CGFloat, levelHeight: CGFloat
  ) {
    guard let assets, !palette.isEmpty else { return }
    let spriteDirection: ClassicSpriteDirection = lemming.direction == .left ? .left : .right
    let wanted = spritePose(for: lemming.action)
    guard
      let animation = assets.animation(for: wanted, direction: spriteDirection)
        ?? assets.animation(for: wanted, direction: .none),
      !animation.frames.isEmpty
    else { return }

    let index = lemming.animationFrame % animation.frames.count
    let key = "\(wanted.rawValue)-\(spriteDirection.rawValue)-\(index)"
    let sprite: NSImage
    if let cached = spriteCache[key] {
      sprite = cached
    } else {
      guard let made = makeImage(animation.frames[index]) else { return }
      spriteCache[key] = made
      sprite = made
    }

    // DOS positions sprites from the lemming's foot point using the per-pose
    // offsets stored in MAIN.DAT.
    let x = CGFloat(lemming.foot.x + animation.offsetX)
    let y = CGFloat(lemming.foot.y + animation.offsetY)
    let drawRect = NSRect(
      x: origin.x + x * scale,
      y: origin.y + (levelHeight - y - sprite.size.height) * scale,
      width: sprite.size.width * scale,
      height: sprite.size.height * scale
    )
    sprite.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
  }

  private func makeImage(_ frame: ClassicIndexedBitmap) -> NSImage? {
    guard
      let rgba = try? frame.rgba(using: palette),
      let provider = CGDataProvider(data: rgba as CFData),
      let cg = CGImage(
        width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    else { return nil }
    return NSImage(cgImage: cg, size: NSSize(width: frame.width, height: frame.height))
  }

  func invalidateSprites() { spriteCache.removeAll() }

  override func mouseDown(with event: NSEvent) {
    guard let simulation, let image, let (origin, scale) = layout() else { return }
    let point = convert(event.locationInWindow, from: nil)
    let levelX = (point.x - origin.x) / scale
    let levelY = image.size.height - (point.y - origin.y) / scale

    // DOS selects the lemming nearest the cursor within a small radius.
    let nearest = simulation.lemmings
      .filter(\.isActive)
      .min {
        hypot(CGFloat($0.foot.x) - levelX, CGFloat($0.foot.y) - levelY)
          < hypot(CGFloat($1.foot.x) - levelX, CGFloat($1.foot.y) - levelY)
      }
    guard let nearest,
      hypot(CGFloat(nearest.foot.x) - levelX, CGFloat(nearest.foot.y) - levelY) < 12
    else { return }
    onClick?(nearest.id)
  }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
  private var window: NSWindow!
  private let view = GameView(frame: .zero)
  private let picker = NSPopUpButton(frame: .zero)
  private let status = NSTextField(labelWithString: "Loading…")
  private let skillStack = NSStackView()

  private var campaign: ClassicCampaign?
  private var grounds: [Int: ClassicGroundSet] = [:]
  private var specials: [Int: ClassicSpecialGraphic] = [:]
  private var assets: ClassicMainDATAssets?
  private var simulation: ClassicDOSSimulation?
  private var contentDirectory: URL?

  private var timer: Timer?
  private var accumulator = 0.0
  private var skill: ClassicSkill = .builder
  private var progress = ModernCampaignProgress()
  private var skillButtons: [NSButton] = []

  func applicationDidFinishLaunching(_ notification: Notification) {
    buildInterface()
    installKeyboardShortcuts()
    if let saved = UserDefaults.standard.string(forKey: contentPathKey) {
      contentDirectory = URL(fileURLWithPath: saved, isDirectory: true)
    }
    if let data = UserDefaults.standard.data(forKey: "ModernCampaignProgress"),
      let saved = try? ModernCampaignProgress(encoded: data) {
      progress = saved
    }
    loadContent()
  }

  private func buildInterface() {
    let root = NSView()
    let importButton = NSButton(
      title: "Import original DOS data…", target: self, action: #selector(chooseContent))
    let pauseButton = NSButton(title: "Pause", target: self, action: #selector(togglePause(_:)))

    skillButtons = ClassicSkill.allCases.enumerated().map { offset, value in
      let button = NSButton(
        title: value.rawValue.capitalized, target: self, action: #selector(selectSkill(_:)))
      button.tag = offset
      return button
    }
    skillStack.setViews(skillButtons, in: .leading)
    skillStack.orientation = .horizontal
    skillStack.spacing = 4

    for subview in [picker, importButton, pauseButton, status, skillStack, view] {
      subview.translatesAutoresizingMaskIntoConstraints = false
      root.addSubview(subview)
    }

    NSLayoutConstraint.activate([
      picker.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
      picker.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),
      picker.widthAnchor.constraint(equalToConstant: 330),
      importButton.leadingAnchor.constraint(equalTo: picker.trailingAnchor, constant: 10),
      importButton.centerYAnchor.constraint(equalTo: picker.centerYAnchor),
      pauseButton.leadingAnchor.constraint(equalTo: importButton.trailingAnchor, constant: 8),
      pauseButton.centerYAnchor.constraint(equalTo: picker.centerYAnchor),
      status.leadingAnchor.constraint(equalTo: pauseButton.trailingAnchor, constant: 12),
      status.centerYAnchor.constraint(equalTo: picker.centerYAnchor),
      skillStack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
      skillStack.topAnchor.constraint(equalTo: picker.bottomAnchor, constant: 8),
      view.leadingAnchor.constraint(equalTo: root.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: root.trailingAnchor),
      view.topAnchor.constraint(equalTo: skillStack.bottomAnchor, constant: 8),
      view.bottomAnchor.constraint(equalTo: root.bottomAnchor),
    ])

    picker.target = self
    picker.action = #selector(levelChanged)
    view.onClick = { [weak self] id in self?.assign(id) }

    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1100, height: 650),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered, defer: false)
    window.title = "Lemmings — Native macOS Port"
    window.contentView = root
    window.center()
    window.makeKeyAndOrderFront(nil)
    startTimer()
  }

  // MARK: - Content

  @objc private func chooseContent() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.message = "Choose the directory containing LEVEL000.DAT, GROUND0O.DAT and MAIN.DAT."
    guard panel.runModal() == .OK, let url = panel.url else { return }
    contentDirectory = url
    UserDefaults.standard.set(url.path, forKey: contentPathKey)
    loadContent()
  }

  private func loadContent() {
    guard let directory = contentDirectory else {
      status.stringValue = "Choose a DOS data directory to begin."
      return
    }
    do {
      let loaded = try ClassicCampaignDefinition.originalDOSLemmings.load(from: directory)
      campaign = loaded
      grounds = [:]
      specials = [:]
      for style in 0..<5 { grounds[style] = try ClassicGroundSet.load(style: style, from: directory) }
      for index in 0..<4 {
        specials[index + 1] = try ClassicSpecialGraphic.load(index: index, from: directory)
      }
      assets = try ClassicMainDATAssets.load(from: directory)
      view.assets = assets
      view.invalidateSprites()

      picker.removeAllItems()
      for (offset, entry) in loaded.levels.enumerated() {
        picker.addItem(withTitle: "\(offset + 1). \(entry.rank) — \(entry.level.title)")
      }
      picker.selectItem(at: 0)
      levelChanged()
    } catch {
      status.stringValue = "Content error: \(error)"
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
        let cg = CGImage(
          width: rendered.width, height: rendered.height, bitsPerComponent: 8, bitsPerPixel: 32,
          bytesPerRow: rendered.width * 4, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
          provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
      else { return }
      view.image = NSImage(
        cgImage: cg, size: NSSize(width: rendered.width, height: rendered.height))

      if let palette = try? ClassicLemmingPalette.inLevelVGA(terrainPalette: ground.terrainPalette) {
        view.palette = palette
        view.invalidateSprites()
      }

      // The DOS engine derives entrances, exits and hazards from the rendered
      // level's own trigger zones, so nothing is positioned by hand here.
      if let assets {
        simulation = try ClassicDOSSimulation(
          level: level, renderedLevel: rendered, mainDATAssets: assets)
      } else {
        simulation = try ClassicDOSSimulation(level: level, renderedLevel: rendered)
      }
      accumulator = 0
      view.simulation = simulation
      updateSkillTitles()
      status.stringValue = "\(entry.rank) \(entry.number) — DOS engine"
      view.needsDisplay = true
    } catch {
      status.stringValue = "Level error: \(error)"
    }
  }

  // MARK: - Run loop

  private func startTimer() {
    timer = Timer.scheduledTimer(withTimeInterval: displayInterval, repeats: true) {
      [weak self] _ in
      MainActor.assumeIsolated { self?.step() }
    }
  }

  private func step() {
    guard var simulation, !simulation.isComplete else { return }
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
    view.simulation = simulation
    view.needsDisplay = true
    updateSkillTitles()

    if simulation.isComplete {
      let index = picker.indexOfSelectedItem
      progress.record(
        levelIndex: index, saved: simulation.savedCount,
        required: simulation.configuration.requiredToSave)
      if let data = try? progress.encoded() {
        UserDefaults.standard.set(data, forKey: "ModernCampaignProgress")
      }
      let outcome = simulation.didWin ? "Level complete" : "Level failed"
      status.stringValue =
        "\(outcome) — saved \(simulation.savedCount)/\(simulation.configuration.requiredToSave)"
        + " • N next • R retry"
    } else {
      let time = simulation.remainingTimeSeconds.map { " • \($0)s" } ?? ""
      status.stringValue =
        "Out \(simulation.releasedCount)/\(simulation.configuration.totalLemmings)"
        + " • Saved \(simulation.savedCount)/\(simulation.configuration.requiredToSave)"
        + " • Rate \(simulation.releaseRate)\(time)"
    }
  }

  private func updateSkillTitles() {
    guard let simulation else { return }
    for (offset, value) in ClassicSkill.allCases.enumerated() where offset < skillButtons.count {
      let count = simulation.remainingSkillCount(value)
      let marker = value == skill ? "▸ " : ""
      skillButtons[offset].title = "\(marker)\(value.rawValue.capitalized) \(count)"
    }
  }

  // MARK: - Commands

  @objc private func selectSkill(_ sender: NSButton) {
    skill = ClassicSkill.allCases[sender.tag]
    updateSkillTitles()
  }

  @objc private func togglePause(_ sender: NSButton) {
    if timer == nil {
      startTimer()
      sender.title = "Pause"
    } else {
      timer?.invalidate()
      timer = nil
      sender.title = "Resume"
    }
  }

  private func assign(_ id: Int) {
    guard var simulation else { return }
    let result = simulation.assign(skill, to: id)
    self.simulation = simulation
    view.simulation = simulation
    view.needsDisplay = true
    updateSkillTitles()
    if result != .assigned { status.stringValue = "Assignment: \(result.rawValue)" }
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
      switch event.charactersIgnoringModifiers?.lowercased() {
      case "n": self.nextLevel()
      case "r": self.retry()
      case "x":
        if var simulation = self.simulation {
          simulation.beginNuke()
          self.simulation = simulation
          self.view.simulation = simulation
        }
      default: return event
      }
      return nil
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
