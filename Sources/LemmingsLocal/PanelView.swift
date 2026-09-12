import AppKit
import NxlvKit

/// The buttons along the bottom of the classic screen.
enum PanelButton: Equatable {
  case rateDown
  case rateUp
  /// Index into the session's skill list. NeoLemmix levels expose a different
  /// set and count of skills than the DOS ruleset does.
  case skill(Int)
  case pause
  case nuke
  case fastForward
}

@MainActor final class PanelView: NSView {
  var session: (any GameSession)? {
    didSet {
      if oldValue !== session { nukeGesture.reset() }
      let names = session?.skills.map(\.name) ?? []
      toolTip = SkillShortcuts(names: names).hint(names: names, modern: modernControlsEnabled) + "\n" + SpeedPanelControls.help
    }
  }
  private var nukeGesture = NukeClickGesture()
  var selectedSkillIndex = 0
  var isPaused = false
  var isFastForward = false
  var modernControlsEnabled = true
  var speedLabel = "1×" { didSet { if oldValue != speedLabel { needsDisplay = true } } }
  var speedChoiceLabel = "2×"
    var variableSpeedEnabled = true
  var onSpeedPress: ((TimeInterval, Int) -> Void)?
  var onSpeedRelease: ((TimeInterval) -> Void)?
  var onSpeedStep: ((Int, TimeInterval) -> Void)?
  private var speedPointerDown = false
  var onSpeedClick: ((TimeInterval, Int) -> Void)?
  var statusText = ""
  /// Right-hand half of the status strip. Tells the player where they are in the
  /// journey at a glance: rank position, rescue progress against the target and
  /// the best known result, and the play style the run is shaping into.
  var progressText = ""
  var levelSize = CGSize(width: 1, height: 1)
  var visibleLevelRect = CGRect.zero

  /// The original status bar, when the imported data provides it.
  var macArtwork: ClassicMacArtwork?
  /// The release's own character set, used for every label on the bar. It
  /// outlives a level, because the bar shows status on the menus too.
  var interfaceArtwork: ClassicMacArtwork? {
    didSet {
      macInterface = interfaceArtwork
        .flatMap(ClassicMacUserInterface.init(artwork:))
        .map(MacInterfaceRenderer.init(interface:))
    }
  }
  private var macInterface: MacInterfaceRenderer?
  var panelImage: CGImage?
  var terrainImage: CGImage?
  /// The skill bar belongs to a level in progress, not to a menu.
  var isMenuMode = false
  /// The CRT source reserves exactly 80 pixels for the controls.
  var isCRTSource = false
  var onButton: ((PanelButton) -> Void)?
  var onMinimapScroll: ((Double) -> Void)?

  var speedControlBounds: CGRect { buttonFrames.first(where: { $0.0 == .fastForward })?.1 ?? .zero }
  private let accessibleElements = GameAccessibleElements()
  override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityChildren() -> [Any]? { accessibleControls(owner: self) }
  func accessibleControls(owner: NSView, transform: (CGRect) -> CGRect = { $0 }) -> [Any] {
    guard !isMenuMode else { return [] }
    if usesClassicSkin { layoutClassicButtons() } else { layoutButtons() }
    var result: [Any] = []
    for (index, item) in buttonFrames.enumerated() {
      let label: String
      switch item.0 {
      case .rateDown: label = "Decrease release rate"
      case .rateUp: label = "Increase release rate"
      case .skill(let skill):
        guard let value = session?.skills[safe: skill] else { continue }
        label = "\(value.name), \(value.isInfinite ? "unlimited" : String(value.count)) remaining" + (selectedSkillIndex == skill ? ", selected" : "")
      case .pause: label = isPaused ? "Resume" : "Pause"
      case .nuke: label = session?.canUndoNuke == true ? "Undo end run" : "End run"
      case .fastForward: label = isFastForward ? "Return to normal speed" : "Start fast-forward at " + speedChoiceLabel
      }
      let action = item.0
      result.append(accessibleElements.element(id: "button-\(index)", owner: owner, label: label, frame: transform(item.1)) { [weak self] in
        guard let self else { return }
        if action == .fastForward { self.onSpeedClick?(ProcessInfo.processInfo.systemUptime, 1) }
        else { self.onButton?(action) }
      })
      if action == .fastForward, variableSpeedEnabled {
        for direction in [-1, 1] {
          let rect = CGRect(x: direction < 0 ? item.1.minX : item.1.maxX - item.1.width * 0.22,
            y: item.1.minY, width: item.1.width * 0.22, height: item.1.height)
          result.append(accessibleElements.element(id: "speed-\(direction)", owner: owner,
            label: direction < 0 ? "Decrease fast speed" : "Increase fast speed", frame: transform(rect)) { [weak self] in
              self?.onSpeedStep?(direction, ProcessInfo.processInfo.systemUptime)
            })
        }
      }
    }
    return result
  }
  private var buttonFrames: [(PanelButton, CGRect)] = []
  private var minimapFrame = CGRect.zero
  private var panelFrame = CGRect.zero
  private var panelScale = 1.0

  /// The authentic skin fits the eight DOS skills only. A NeoLemmix level can
  /// grant far more, so those fall back to the drawn panel.
  private var usesClassicSkin: Bool {
    panelImage != nil && session?.skills.count == 8
  }

  override var isFlipped: Bool { true }

  private let buttonHeight = 34.0
  private let inset = 8.0
  private let gap = 4.0

  // MARK: - Layout

  /// Places the original controls and speed button over the status bar.
  private func layoutClassicButtons() {
    guard let panelImage else { return }
    let statusHeight: CGFloat = isCRTSource || bounds.height <= 40 ? 0 : statusStripHeight
    let scale = max(1, floor(min(bounds.width / CGFloat(panelImage.width),
      (bounds.height - statusHeight) / CGFloat(panelImage.height))))
    panelScale = Double(scale)
    let size = CGSize(
      width: CGFloat(panelImage.width) * scale, height: CGFloat(panelImage.height) * scale)
    panelFrame = CGRect(
      x: (bounds.width - size.width) / 2, y: 0, width: size.width, height: size.height)
    _ = statusStripHeight

    let order: [PanelButton] = [.rateDown, .rateUp]
      + (0..<8).map(PanelButton.skill) + [.pause, .nuke, .fastForward]
    let cell = CGFloat(ClassicPanelGraphics.buttonWidth) * scale
    buttonFrames = order.enumerated().map { index, button in
      (button, CGRect(
        x: panelFrame.minX + cell * CGFloat(index), y: panelFrame.minY + 16 * scale,
        width: cell, height: 24 * scale))
    }
    if variableSpeedEnabled, let index = buttonFrames.firstIndex(where: { $0.0 == .fastForward }) {
      buttonFrames[index].1.size.width = cell * 3
    }
    // Leave space for the speed arrows before the map.
    let mapLeft = panelFrame.minX + cell * CGFloat(order.count + (variableSpeedEnabled ? 2 : 0)) + 16 * scale
    minimapFrame = CGRect(
      x: mapLeft,
      y: panelFrame.minY + 18 * scale,
      width: max(0, panelFrame.maxX - mapLeft - 4 * scale),
      height: 20 * scale)
  }

  private func layoutButtons() {
    let skillCount = session?.skills.count ?? 0
    var order: [PanelButton] = [.rateDown, .rateUp]
    order.append(contentsOf: (0..<skillCount).map(PanelButton.skill))
    order.append(contentsOf: [.pause, .nuke, .fastForward])

    // The minimap takes the right quarter, as it does in the original panel.
    let minimapWidth = max(120, bounds.width * 0.24)
    minimapFrame = CGRect(
      x: bounds.width - minimapWidth - inset, y: inset,
      width: minimapWidth, height: buttonHeight)

    let available = minimapFrame.minX - inset * 2
    let width = (available - gap * Double(order.count - 1)) / Double(order.count)
    buttonFrames = order.enumerated().map { index, button in
      let frame = CGRect(
        x: inset + (width + gap) * Double(index), y: inset,
        width: width, height: buttonHeight)
      return (button, frame)
    }
  }

  // MARK: - Input

  /// Takes a click position directly, for input arriving from the tube view.
  func handleClick(at point: CGPoint, time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
    if let match = buttonFrames.first(where: { $0.1.contains(point) }) {
      press(match.0, time: time)
      return
    }
    nukeGesture.reset()
    if minimapFrame.contains(point) { scrollFromMinimap(point) }
  }

  override func mouseDown(with event: NSEvent) {
    handlePointerDown(at: convert(event.locationInWindow, from: nil), time: event.timestamp, clickCount: event.clickCount)
  }

  func handlePointerDown(at point: CGPoint, time: TimeInterval = ProcessInfo.processInfo.systemUptime, clickCount: Int = 1) {
    stopRepeating()
    pointerIsDown = true
    if let match = buttonFrames.first(where: { $0.1.contains(point) }) {
      if match.0 == .fastForward, variableSpeedEnabled, let part = SpeedPanelControls.part(at: point, in: match.1) {
        nukeGesture.reset()
        if part == 0 { speedPointerDown = true; onSpeedPress?(time, clickCount) }
        else { onSpeedStep?(part, time) }
        return
      }
      press(match.0, time: time, clickCount: clickCount)
      // The release rate is the one control a player holds rather than taps.
      // Stepping it one at a time makes crossing the whole range a chore.
      if match.0 == .rateDown || match.0 == .rateUp { startRepeating(match.0) }
      return
    }
    nukeGesture.reset()
    if minimapFrame.contains(point) { scrollFromMinimap(point) }
  }

  override func mouseUp(with event: NSEvent) { handlePointerUp(time: event.timestamp) }

  func resetNukeGesture() { nukeGesture.reset() }

  private func press(_ button: PanelButton, time: TimeInterval, clickCount: Int = 1) {
    if button == .nuke {
      let action = nukeGesture.click(canUndo: session?.canUndoNuke == true,
        time: time, interval: NSEvent.doubleClickInterval)
      if action != .none { onButton?(button) }
    } else {
      nukeGesture.reset()
      if button == .fastForward, let onSpeedClick { onSpeedClick(time, clickCount) }
      else { onButton?(button) }
    }
    needsDisplay = true
  }

  func handlePointerUp(time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
    if speedPointerDown { speedPointerDown = false; onSpeedRelease?(time) }
    pointerIsDown = false
    stopRepeating()
  }

  // MARK: - Held buttons

  /// Wait before a held button starts repeating, so a tap stays a single step.
  private static let repeatDelay = 0.3
  /// Gap between repeats. Fifty a second crosses the whole rate range in about
  /// a second, which is how fast the original moves.
  private static let repeatInterval = 0.02

  private var repeatTimer: Timer?
  private var pointerIsDown = false

  /// Both timers are scheduled from a mouse event, so they fire on the main
  /// run loop and their work is already where it belongs. The compiler cannot
  /// see that through a `Sendable` closure, which is what the assertion states.
  /// The timer itself stays out of the assertion, because it is not `Sendable`
  /// and passing it in would be sending it across an isolation boundary.
  private func startRepeating(_ button: PanelButton) {
    stopRepeating()
    repeatTimer = Timer.scheduledTimer(
      withTimeInterval: Self.repeatDelay, repeats: false
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, self.pointerIsDown else { return }
        self.beginRepeats(button)
      }
    }
  }

  /// Starts the fast phase, once a hold has outlasted the delay.
  private func beginRepeats(_ button: PanelButton) {
    repeatTimer = Timer.scheduledTimer(
      withTimeInterval: Self.repeatInterval, repeats: true
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        // A button held past the end of its range stops rather than spinning.
        guard let self, self.pointerIsDown else { self?.stopRepeating(); return }
        self.onButton?(button)
      }
    }
  }

  private func stopRepeating() {
    repeatTimer?.invalidate()
    repeatTimer = nil
  }

  /// A bar torn down while a button is held would otherwise leave a timer
  /// firing for the life of the run loop, with nothing left to clear it: the
  /// closure holds the bar weakly, so it cannot stop the timer once the bar
  /// has gone.
  isolated deinit { repeatTimer?.invalidate() }

  override func mouseDragged(with event: NSEvent) {
    handlePointerDrag(at: convert(event.locationInWindow, from: nil))
  }

  func handlePointerDrag(at point: CGPoint) {
    if minimapFrame.contains(point) { scrollFromMinimap(point) }
  }

  private func scrollFromMinimap(_ point: CGPoint) {
    guard minimapFrame.width > 0, levelSize.width > 0 else { return }
    let fraction = (point.x - minimapFrame.minX) / minimapFrame.width
    onMinimapScroll?(Double(fraction) * levelSize.width)
  }

  // MARK: - Drawing

  override func draw(_ dirtyRect: NSRect) {
    // Fill the view's own area, not the dirty rectangle. These views share one
    // window-sized backing layer, so AppKit passes a rectangle that covers the
    // whole window. A fill of that rectangle paints over the playfield above.
    NSColor.black.setFill()
    bounds.fill()

    // A menu shows no skills, no counts and no map.
    if isMenuMode {
      drawStatus()
      return
    }

    if usesClassicSkin {
      layoutClassicButtons()
      drawClassicPanel()
      drawClassicCounts()
      drawMinimap()
      drawStatus()
      drawSpeedControls()
      return
    }

    NSColor(calibratedWhite: 0.11, alpha: 1).setFill()
    bounds.fill()
    layoutButtons()
    for (button, frame) in buttonFrames { draw(button, in: frame) }
    drawMinimap()
    drawStatus()
    drawSpeedControls()
  }

  private func drawSpeedControls() {
    guard variableSpeedEnabled, let frame = buttonFrames.first(where: { $0.0 == .fastForward })?.1 else { return }
    SpeedPanelControls.draw(in: frame, label: speedLabel, active: isFastForward, next: speedChoiceLabel)
  }

  private func drawClassicPanel() {
    guard let panelImage else { return }
    NSGraphicsContext.current?.imageInterpolation = .none
    if let macArtwork { drawMacPanel(macArtwork); return }
    NSImage(cgImage: panelImage, size: NSSize(width: panelImage.width, height: panelImage.height))
      .draw(in: panelFrame, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)

    for (button, frame) in buttonFrames {
      guard let glyph = PanelGlyph.forButton(button, isPaused: isPaused, canUndoNuke: session?.canUndoNuke == true) else { continue }
      let active = (button == .pause && isPaused) || (button == .fastForward && isFastForward)
        || (button == .nuke && session?.canUndoNuke == true)
      drawStoneButton(frame, selected: active)
      if let image = glyph.image(fitting: frame.insetBy(dx: 2 * panelScale, dy: 2 * panelScale).size) {
        image.draw(in: CGRect(x: frame.midX - image.size.width / 2, y: frame.midY - image.size.height / 2,
          width: image.size.width, height: image.size.height), from: .zero, operation: .sourceOver,
          fraction: 1, respectFlipped: true, hints: nil)
      }
    }

    // Mark the armed skill, which the original showed with a lit border.
    guard let match = buttonFrames.first(where: { $0.0 == .skill(selectedSkillIndex) })
    else { return }
    // The art occupies the upper rows of each cell, so the marker follows it.
    let art = CGRect(
      x: match.1.minX, y: match.1.minY,
      width: match.1.width, height: match.1.height)
    NSColor.white.setStroke()
    let outline = NSBezierPath(rect: art.insetBy(dx: 1, dy: 1))
    outline.lineWidth = 2
    outline.stroke()
  }

  private func drawMacPanel(_ artwork: ClassicMacArtwork) {
    let poses: [ClassicLemmingPose] = [.climbing, .floating, .ohNo, .blocking,
      .building, .bashing, .mining, .digging]
    for (button, frame) in buttonFrames {
      let selected = button == .skill(selectedSkillIndex) || (button == .pause && isPaused)
        || (button == .fastForward && isFastForward) || (button == .nuke && session?.canUndoNuke == true)
      drawStoneButton(frame, selected: selected)
      if case let .skill(index) = button, let source = artwork.lemming(
        pose: poses[index], left: false, tick: index == 2 ? 12 : 0), let image = source.makeNSImage() {
        let box = CGRect(x: frame.minX + 2 * panelScale, y: frame.minY + 2 * panelScale,
          width: frame.width - 4 * panelScale, height: frame.height - 4 * panelScale)
        let scale = min(box.width / image.size.width, box.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: CGRect(x: box.midX - size.width / 2, y: box.maxY - size.height,
          width: size.width, height: size.height), from: .zero, operation: .sourceOver,
          fraction: 1, respectFlipped: true, hints: nil)
      } else if let glyph = PanelGlyph.forButton(button, isPaused: isPaused, canUndoNuke: session?.canUndoNuke == true),
        // Rasterise the control glyph to fit the recessed well.
        let image = glyph.image(
          fitting: frame.insetBy(
            dx: 4 * max(1, panelScale / 2), dy: 4 * max(1, panelScale / 2)).size) {
        image.draw(
          in: CGRect(x: frame.midX - image.size.width / 2,
            y: frame.midY - image.size.height / 2,
            width: image.size.width, height: image.size.height),
          from: .zero, operation: .sourceOver, fraction: 1,
          respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
      } else {
        let symbol: String
        switch button {
        case .rateDown: symbol = "−"
        case .rateUp: symbol = "+"
        case .pause, .nuke, .fastForward, .skill: symbol = ""
        }
        let attributes: [NSAttributedString.Key: Any] = [
          .font: NSFont.systemFont(ofSize: 10 * panelScale, weight: .black),
          .foregroundColor: NSColor.systemGreen]
        let text = symbol as NSString
        let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2),
          withAttributes: attributes)
      }
    }
    NSColor(calibratedWhite: 0.42, alpha: 1).setStroke()
    NSBezierPath(rect: minimapFrame).stroke()
  }

  /// Pixel bevels keep the controls in the same visual period as the sprites.
  private func drawStoneButton(_ frame: CGRect, selected: Bool) {
    let pixel = max(1, panelScale / 2)
    let rim = frame.insetBy(dx: pixel, dy: pixel)
    func fill(_ rect: CGRect, _ color: NSColor) {
      color.setFill()
      rect.fill()
    }
    let light = NSColor(calibratedRed: 0.65, green: 0.66, blue: 0.59, alpha: 1)
    let stone = NSColor(calibratedRed: 0.35, green: 0.37, blue: 0.32, alpha: 1)
    let shadow = NSColor(calibratedRed: 0.11, green: 0.13, blue: 0.10, alpha: 1)
    fill(rim, stone)
    // Top and left catch the light; the selected button sinks into its socket.
    let upper = selected ? shadow : light
    let lower = selected ? light : shadow
    for step in 0..<2 {
      let edge = rim.insetBy(dx: CGFloat(step) * pixel, dy: CGFloat(step) * pixel)
      fill(CGRect(x: edge.minX, y: edge.minY, width: edge.width, height: pixel), upper)
      fill(CGRect(x: edge.minX, y: edge.minY, width: pixel, height: edge.height), upper)
      fill(CGRect(x: edge.minX, y: edge.maxY - pixel, width: edge.width, height: pixel), lower)
      fill(CGRect(x: edge.maxX - pixel, y: edge.minY, width: pixel, height: edge.height), lower)
    }
    let well = rim.insetBy(dx: 3 * pixel, dy: 3 * pixel)
    fill(well.insetBy(dx: -pixel, dy: -pixel), shadow)
    fill(CGRect(x: well.minX, y: well.maxY, width: well.width, height: pixel), light)
    fill(CGRect(x: well.maxX, y: well.minY, width: pixel, height: well.height), light)
    fill(well, selected
      ? NSColor(calibratedRed: 0.17, green: 0.25, blue: 0.10, alpha: 1)
      : NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.06, alpha: 1))
    if selected {
      fill(CGRect(x: well.minX + pixel, y: well.maxY - 2 * pixel,
        width: well.width - 2 * pixel, height: pixel),
        NSColor(calibratedRed: 0.62, green: 0.85, blue: 0.22, alpha: 1))
    }
  }

  private func drawClassicCounts() {
    guard let session else { return }
    for (button, frame) in buttonFrames {
      let value: String
      switch button {
      case .rateDown, .rateUp:
        value = "\(session.rate)"
      case let .skill(index):
        guard let skill = session.skills[safe: index] else { continue }
        value = skill.isInfinite ? "∞" : "\(skill.count)"
      case .pause, .nuke, .fastForward:
        continue
      }
      // Keep quantities in a separate strip above the skill artwork.
      let box = CGRect(x: frame.minX, y: panelFrame.minY + panelScale,
        width: frame.width, height: 9 * panelScale)
      NSColor.black.setFill()
      box.fill()
      if drawMacLabel(value, centeredIn: box) { continue }
      GamePixelText.draw(value, in: box)
    }
  }

  private func draw(_ button: PanelButton, in frame: CGRect) {
    let title: String
    let subtitle: String
    var highlighted = false

    switch button {
    case .rateDown:
      title = "◀"
      subtitle = session.map { "\($0.rate)" } ?? "—"
    case .rateUp:
      title = "▶"
      subtitle = session.map { "\($0.rate)" } ?? "—"
    case let .skill(index):
      let skill = session?.skills[safe: index]
      title = skill?.name ?? "—"
      subtitle = skill.map { $0.isInfinite ? "∞" : "\($0.count)" } ?? "0"
      highlighted = index == selectedSkillIndex
    case .pause:
      title = ""
      subtitle = ""
      highlighted = isPaused
    case .fastForward:
      title = ""
      subtitle = speedLabel
      highlighted = isFastForward
    case .nuke:
      title = ""
      subtitle = ""
      highlighted = session?.canUndoNuke == true
    }

    let path = NSBezierPath(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
    (highlighted ? NSColor.systemGreen.withAlphaComponent(0.30) : NSColor(calibratedWhite: 0.20, alpha: 1))
      .setFill()
    path.fill()
    (highlighted ? NSColor.systemGreen : NSColor(calibratedWhite: 0.34, alpha: 1)).setStroke()
    path.lineWidth = highlighted ? 2 : 1
    path.stroke()

    if let glyph = PanelGlyph.forButton(button, isPaused: isPaused, canUndoNuke: session?.canUndoNuke == true),
       let image = glyph.image(fitting: CGSize(width: frame.width - 10, height: subtitle.isEmpty ? frame.height - 10 : 14)) {
      image.draw(in: CGRect(x: frame.midX - image.size.width / 2,
        y: subtitle.isEmpty ? frame.midY - image.size.height / 2 : frame.minY + 3,
        width: image.size.width, height: image.size.height), from: .zero, operation: .sourceOver,
        fraction: 1, respectFlipped: true, hints: nil)
    }

    let titleAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 10, weight: .medium),
      .foregroundColor: NSColor.white,
    ]
    let titleSize = (title as NSString).size(withAttributes: titleAttributes)
    (title as NSString).draw(
      at: CGPoint(x: frame.midX - titleSize.width / 2, y: frame.minY + 4),
      withAttributes: titleAttributes)

    guard !subtitle.isEmpty else { return }
    let subtitleAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold),
      .foregroundColor: highlighted ? NSColor.systemGreen : NSColor(calibratedWhite: 0.72, alpha: 1),
    ]
    let subtitleSize = (subtitle as NSString).size(withAttributes: subtitleAttributes)
    (subtitle as NSString).draw(
      at: CGPoint(x: frame.midX - subtitleSize.width / 2, y: frame.minY + 18),
      withAttributes: subtitleAttributes)
  }

  private func drawMinimap() {
    // The original bar already draws the map surround, so only the dots and
    // the view rectangle go on top of it.
    if !usesClassicSkin {
      NSColor(calibratedWhite: 0.05, alpha: 1).setFill()
      NSBezierPath(roundedRect: minimapFrame, xRadius: 3, yRadius: 3).fill()
    }
    guard levelSize.width > 0, levelSize.height > 0, let session else { return }

    let scale = min(
      minimapFrame.width / levelSize.width, minimapFrame.height / levelSize.height)
    let drawn = CGSize(width: levelSize.width * scale, height: levelSize.height * scale)
    let origin = CGPoint(
      x: minimapFrame.minX + (minimapFrame.width - drawn.width) / 2,
      y: minimapFrame.minY + (minimapFrame.height - drawn.height) / 2)

    if let terrainImage {
      NSGraphicsContext.current?.imageInterpolation = .none
      NSImage(cgImage: terrainImage, size: levelSize).draw(
        in: CGRect(origin: origin, size: drawn), from: .zero,
        operation: .sourceOver, fraction: 0.8, respectFlipped: true, hints: nil)
    }
    NSColor.systemGreen.setFill()
    for lemming in session.lemmings {
      let dot = CGRect(
        x: origin.x + CGFloat(lemming.x) * scale - 1,
        y: origin.y + CGFloat(lemming.y) * scale - 1,
        width: 2, height: 2)
      dot.fill()
    }

    let window = CGRect(
      x: origin.x + visibleLevelRect.minX * scale,
      y: origin.y + visibleLevelRect.minY * scale,
      width: visibleLevelRect.width * scale,
      height: visibleLevelRect.height * scale).intersection(CGRect(origin: origin, size: drawn))
    NSColor.white.withAlphaComponent(0.8).setStroke()
    let outline = NSBezierPath(rect: window)
    outline.lineWidth = 1
    outline.stroke()
  }

  /// Draws a label in the release's small face, centered in a box.
  ///
  /// Returns false when the release has no character set or the text does not
  /// fit, so the caller can fall back to a system font.
  /// Punctuation the character set does not carry, mapped to what it does.
  private func gameText(_ text: String) -> String {
    text.uppercased()
      .replacingOccurrences(of: "—", with: "-")
      .replacingOccurrences(of: "–", with: "-")
      .replacingOccurrences(of: "’", with: "'")
      .replacingOccurrences(of: "∞", with: "*")
      .replacingOccurrences(of: "×", with: "X")
      .replacingOccurrences(of: "•", with: "*")
  }

  private func drawMacLabel(_ text: String, centeredIn box: CGRect, scale wanted: Int = 0) -> Bool {
    guard let macInterface, let font = macInterface.font(.small) else { return false }
    let upper = gameText(text)
    guard font.covers(upper) else { return false }
    let fit = min(
      Int(box.width) / max(1, font.cellWidth * max(1, upper.count)),
      Int(box.height) / max(1, font.cellHeight))
    let scale = wanted > 0 ? wanted : fit
    guard scale >= 1 else { return false }
    macInterface.drawCentered(
      upper, face: .small, centerX: box.midX,
      top: box.midY - macInterface.height(face: .small, scale: scale) / 2, scale: scale)
    return true
  }

  private func drawStatus() {
    let y = usesClassicSkin ? panelFrame.maxY + 4 : inset + buttonHeight + 6
    let box = CGRect(x: inset, y: y, width: bounds.width - inset * 2, height: 20)
    if let macInterface, let font = macInterface.font(.small), font.covers(gameText(statusText)) {
      macInterface.draw(gameText(statusText), face: .small, at: CGPoint(x: inset, y: y), scale: 1)
    } else {
      GamePixelText.draw(gameText(statusText), in: box)
    }
    drawProgress(in: box, y: y)
  }

  /// Drawn from the right edge inward, so it cannot collide with the status text
  /// on the left however long either grows. It is dropped rather than truncated
  /// when the panel is too narrow to hold both.
  private func drawProgress(in box: CGRect, y: CGFloat) {
    guard !progressText.isEmpty else { return }
    let text = gameText(progressText)
    if let macInterface, let font = macInterface.font(.small), font.covers(text) {
      let width = macInterface.width(of: text, face: .small, scale: 1)
      let statusWidth = macInterface.width(of: gameText(statusText), face: .small, scale: 1)
      let x = bounds.width - inset - width
      guard x > inset + statusWidth + 12 else { return }
      macInterface.draw(text, face: .small, at: CGPoint(x: x, y: y), scale: 1)
      return
    }
    // The original artwork has no Macintosh interface font. Without this the
    // whole field silently drew nothing for every player using it, which is
    // most of them. Fall back to the same glyphs the status line uses.
    GamePixelText.draw(text, in: CGRect(
      x: box.midX, y: box.minY, width: box.width / 2, height: box.height))
  }

  /// Tall enough for the original bar at 3x, plus a status strip beneath it.
  var intrinsicHeight: CGFloat {
    CGFloat(ClassicPanelGraphics.height) * 3 + statusStripHeight
  }

  private let statusStripHeight: CGFloat = 22
}


extension Array {
  /// Panel layout can lag a session swap by one frame, so index safely.
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
