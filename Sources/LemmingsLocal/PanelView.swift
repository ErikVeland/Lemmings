#if os(macOS)
import AppKit
import NxlvKit
import LemmingsMobileCore
import LemmingsGameArt

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
  private(set) var presentationRevision: UInt64 = 0
  override var needsDisplay: Bool {
    get { super.needsDisplay }
    set { if newValue { presentationRevision &+= 1 }; super.needsDisplay = newValue }
  }

  var session: (any GameSession)? {
    didSet {
      if oldValue !== session { nukeGesture.reset(); needsDisplay = true; window?.invalidateCursorRects(for: self) }
      toolTip = nil
    }
  }
  private var nukeGesture = NukeClickGesture()
  var selectedSkillIndex = 0 { didSet { if oldValue != selectedSkillIndex { needsDisplay = true } } }
  var isPaused = false { didSet { if oldValue != isPaused { needsDisplay = true } } }
  var isFastForward = false { didSet { if oldValue != isFastForward { needsDisplay = true } } }
  var modernControlsEnabled = true { didSet { if oldValue != modernControlsEnabled { needsDisplay = true } } }
  var speedLabel = "1×" { didSet { if oldValue != speedLabel { needsDisplay = true } } }
  var speedChoiceLabel = "2×" { didSet { if oldValue != speedChoiceLabel { needsDisplay = true } } }
  var variableSpeedEnabled = true { didSet { if oldValue != variableSpeedEnabled { needsDisplay = true } } }
  var onSpeedPress: ((TimeInterval, Int) -> Void)?
  var onSpeedRelease: ((TimeInterval) -> Void)?
  var onSpeedStep: ((Int, TimeInterval) -> Void)?
  private var speedPointerDown = false
  var onSpeedClick: ((TimeInterval, Int) -> Void)?
  var statusText = "" { didSet { if oldValue != statusText { needsDisplay = true } } }
  /// Right-hand half of the status strip. Tells the player where they are in the
  /// journey at a glance: rank position, rescue progress against the target and
  /// the best known result, and the play style the run is shaping into.
  var progressText = "" { didSet { if oldValue != progressText { needsDisplay = true } } }
  var levelSize = CGSize(width: 1, height: 1) { didSet { if oldValue != levelSize { needsDisplay = true } } }
  var visibleLevelRect = CGRect.zero { didSet { if oldValue != visibleLevelRect { needsDisplay = true } } }

  /// The original status bar, when the imported data provides it.
  var macArtwork: ClassicMacArtwork? {
    didSet { cacheMacSkillImages(); cacheMonochromeRock(); needsDisplay = true }
  }
  private var macSkillImages: [NSImage?] = []
  private var monochromeRock: CGImage?
  private var monochromeRockImages: [Int: NSImage] = [:]
  private var isMonochrome: Bool { macArtwork?.monochrome == true }
  private var panelPalette: MacInterfaceRenderer.Palette { isMonochrome ? .monochrome : .blue }

  private func cacheMonochromeRock() {
    monochromeRock = nil
    monochromeRockImages.removeAll()
    guard isMonochrome, let art = macArtwork, let bank = art.bank(named: "Charset0"),
      let source = art.frame(bank, 95), source.width >= 66, source.height >= 44,
      let image = source.makeNSImage()?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
    // A dark part of the original rock leaves the white skill silhouettes readable.
    monochromeRock = image.cropping(to: CGRect(x: 38, y: 0, width: 28, height: 44))
  }

  private func rockImage(fitting size: CGSize) -> NSImage? {
    if isMonochrome {
      let steps = max(1, min(Int(size.width) / 14, Int(size.height) / 22))
      if let hit = monochromeRockImages[steps] { return hit }
      guard let monochromeRock else { return PanelGlyph.rock.monochromeImage(fitting: size) }
      let image = NSImage(cgImage: monochromeRock, size: CGSize(width: 14 * steps, height: 22 * steps))
      monochromeRockImages[steps] = image
      return image
    }
    return nil
  }

  private func controlImage(_ glyph: PanelGlyph, fitting size: CGSize) -> NSImage? {
    if isMonochrome { return glyph.monochromeImage(fitting: size) }
    return usesMacStyleControls ? glyph.macImage(fitting: size, transparentRock: true)
      : glyph.image(fitting: size, transparentRock: true)
  }

  private func cacheMacSkillImages() {
    let poses: [ClassicLemmingPose] = [.climbing, .floating, .ohNo, .blocking,
      .building, .bashing, .mining, .digging]
    macSkillImages = poses.enumerated().map { index, pose in
      guard let source = macArtwork?.lemming(pose: pose, left: false, tick: index == 2 ? 12 : 0),
        let image = source.makeNSImage(),
        let bitmap = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
      // The 1-bit frames pad their rows to different widths. Centre visible pixels.
      var left = source.width, top = source.height, right = -1, bottom = -1
      source.rgba.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
        for y in 0..<source.height { for x in 0..<source.width {
          guard bytes[(y * source.width + x) * 4 + 3] > 0 else { continue }
          left = min(left, x); right = max(right, x)
          top = min(top, y); bottom = max(bottom, y)
        } }
      }
      guard right >= left, bottom >= top,
        let crop = bitmap.cropping(to: CGRect(x: left, y: top,
          width: right - left + 1, height: bottom - top + 1)) else { return nil }
      if isMonochrome {
        // A one-pixel black edge separates the shipped sprite from white rock dots.
        let width = crop.width + 2, height = crop.height + 2
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        source.rgba.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
          for y in top...bottom { for x in left...right {
            let from = (y * source.width + x) * 4
            guard bytes[from + 3] > 0 else { continue }
            for dy in 0...2 { for dx in 0...2 {
              pixels[((y - top + dy) * width + x - left + dx) * 4 + 3] = 255
            } }
          } }
          for y in top...bottom { for x in left...right {
            let from = (y * source.width + x) * 4
            guard bytes[from + 3] > 0 else { continue }
            let to = ((y - top + 1) * width + x - left + 1) * 4
            for channel in 0..<4 { pixels[to + channel] = bytes[from + channel] }
          } }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
          let outlined = CGImage(width: width, height: height, bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        return NSImage(cgImage: outlined, size: CGSize(width: width, height: height))
      }
      return NSImage(cgImage: crop, size: CGSize(width: crop.width, height: crop.height))
    }
  }
  var usesMacStyleControls = false { didSet { needsDisplay = true } }
  var counterStyle: ClassicCounterStyle = .game { didSet { needsDisplay = true } }
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
  var neoSprites: NeoLemmixSpriteSet?
  var terrainImage: CGImage?
  private let minimapThumbnail = GameMinimapThumbnail()
  /// The skill bar belongs to a level in progress, not to a menu.
  var isMenuMode = false {
    didSet { if oldValue != isMenuMode { needsDisplay = true; window?.invalidateCursorRects(for: self) } }
  }
  /// The CRT source reserves exactly 80 pixels for the controls.
  var isCRTSource = false
  var onButton: ((PanelButton) -> Void)?
  var onMinimapScroll: ((Double) -> Void)?
  var onMinimapPosition: ((CGPoint) -> Void)?

  var speedControlBounds: CGRect { buttonFrames.first(where: { $0.0 == .fastForward })?.1 ?? .zero }
  let timeline = TimelinePanelControls()
  private let accessibleElements = GameAccessibleElements()
  override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityChildren() -> [Any]? { accessibleControls(owner: self) }
  func accessibleControls(owner: NSView, transform: (CGRect) -> CGRect = { $0 }) -> [Any] {
    guard !isMenuMode else { return [] }
    layoutControls()
    var result: [Any] = []
    for (index, item) in buttonFrames.enumerated() {
      let label: String
      switch item.0 {
      case .rateDown: label = session is NeoLemmixSession ? L10n.text("Decrease spawn interval") : L10n.text("Decrease release rate")
      case .rateUp: label = session is NeoLemmixSession ? L10n.text("Increase spawn interval") : L10n.text("Increase release rate")
      case .skill(let skill):
        guard let value = session?.skills[safe: skill] else { continue }
        let remaining = value.isInfinite ? L10n.text("unlimited") : L10n.text("\(value.count) remaining")
        label = L10n.text("\(SkillVocabulary.title(value.name)), \(remaining)\((selectedSkillIndex == skill ? L10n.text(", selected") : ""))")
      case .pause: label = isPaused ? L10n.text("Resume") : L10n.text("Pause")
      case .nuke: label = session?.canUndoNuke == true ? L10n.text("Undo end run") : L10n.text("End run")
      case .fastForward: label = isFastForward ? L10n.text("Return to normal speed") : L10n.text("Start fast-forward at ") + speedChoiceLabel
      }
      let action = item.0
      let element = accessibleElements.element(id: "button-\(index)", owner: owner, label: label, frame: transform(item.1)) { [weak self] in
        guard let self, self.isEnabled(action) else { return }
        if action == .fastForward { self.onSpeedClick?(ProcessInfo.processInfo.systemUptime, 1) }
        else { self.onButton?(action) }
      }
      element.setAccessibilityEnabled(isEnabled(action))
      result.append(element)
      if action == .fastForward, variableSpeedEnabled {
        for direction in [-1, 1] {
          let rect = CGRect(x: direction < 0 ? item.1.minX : item.1.maxX - item.1.width * 0.22,
            y: item.1.minY, width: item.1.width * 0.22, height: item.1.height)
          result.append(accessibleElements.element(id: "speed-\(direction)", owner: owner,
            label: direction < 0 ? L10n.text("Decrease fast speed") : L10n.text("Increase fast speed"), frame: transform(rect)) { [weak self] in
              self?.onSpeedStep?(direction, ProcessInfo.processInfo.systemUptime)
            })
        }
      }
    }
    return result + timeline.accessibleControls(owner: owner, transform: transform)
  }
  var controlBounds: CGRect {
    layoutControls()
    return buttonFrames.first(where: { if case .skill = $0.0 { return true }; return false })?.1 ?? .zero
  }

  private var buttonFrames: [(PanelButton, CGRect)] = []
  private var minimapFrame = CGRect.zero
  private var rateValueFrame = CGRect.zero
  /// The minimap's drag area, below the timeline controls.
  var minimapBounds: CGRect { minimapFrame }
  private var panelFrame = CGRect.zero
  private var panelScale = 1.0

  /// The baked artwork describes DOS skill identities, not just eight slots.
  private var usesClassicSkin: Bool {
    panelImage != nil && session is ClassicSession
  }

  override var isFlipped: Bool { true }

  /// The skill bar shows the Amiga cross in place of the system cursor. Menus keep the arrow.
  var controlCursorScale: CGFloat? { isMenuMode ? nil : panelScale }

  override func resetCursorRects() {
    addCursorRect(bounds, cursor: controlCursorScale.map { GameCursor.controlCursor(scale: $0) } ?? .arrow)
  }

  override func cursorUpdate(with event: NSEvent) {
    GameCursor.update(at: nil, hidingInside: nil, controlScale: controlCursorScale)
  }

  private let inset = 8.0
  private var usesWideDeck: Bool { !isCRTSource && !isMenuMode }

  private func wideDeckMetrics(for width: CGFloat) -> (rows: Int, inline: Bool, height: CGFloat) {
    let available = min(1920, max(1, width - inset * 2))
    let skillCount = session?.skills.count ?? 8
    let transportWidth: CGFloat = 104 + 24 + 44 + 32 + 44 + 100 + 132 + 64
    let inline = skillCount > 0 && skillCount <= 8
      && available - transportWidth >= CGFloat(skillCount) * 58
    let columns = max(1, Int(available / 64))
    let rows = inline ? 1 : max(1, (skillCount + columns - 1) / columns)
    return (rows, inline, 60 + CGFloat(rows) * 104 + (inline ? 0 : 64) + statusStripHeight)
  }

  // MARK: - Layout

  private func layoutControls() {
    if usesWideDeck { layoutWideButtons() }
    else if usesClassicSkin { layoutClassicButtons() }
    else { layoutButtons() }
  }

  private var adaptivePanelWidth: CGFloat {
    // Wider skill sockets keep NeoLemmix names readable at the same row scale.
    max(320, CGFloat(session?.skills.count ?? 0) * 20 + (variableSpeedEnabled ? 112 : 80) + 80)
  }

  func height(for width: CGFloat, maximumScale: CGFloat) -> CGFloat {
    if usesWideDeck { return wideDeckMetrics(for: width).height }
    let sourceWidth = usesClassicSkin ? CGFloat(panelImage?.width ?? 320) : adaptivePanelWidth
    return 40 * max(1, floor(min(maximumScale, width / sourceWidth))) + statusStripHeight
  }

  private func layoutWideButtons() {
    let available = min(1920, max(1, bounds.width - inset * 2))
    let deckX = floor((bounds.width - available) / 2)
    let metrics = wideDeckMetrics(for: bounds.width)
    let skillCount = session?.skills.count ?? 0
    panelScale = 2
    panelFrame = CGRect(x: deckX, y: 0, width: available, height: metrics.height - statusStripHeight)
    let timelineInRow = available >= 504
    let mapWidth = min(800, max(0, available - (timelineInRow ? 0 : 140)))
    minimapFrame = CGRect(x: deckX, y: 4, width: mapWidth, height: 44)
    let skillY: CGFloat = 60
    let nukeWidth: CGFloat = metrics.inline ? 104 : 64
    let transportWidth: CGFloat = nukeWidth + 24 + 44 + 32 + 44 + 100 + (timelineInRow ? 132 : 0) + 64
    let skillBankWidth = metrics.inline ? available - transportWidth : available
    let columns = metrics.inline ? max(1, skillCount) : max(1, Int(available / 64))
    buttonFrames = (0..<skillCount).map { index in
      let row = index / columns, column = index % columns
      let rowCount = min(columns, skillCount - row * columns)
      let cell = skillBankWidth / CGFloat(max(1, rowCount))
      let left = floor(deckX + CGFloat(column) * cell)
      let right = column == rowCount - 1 ? deckX + skillBankWidth : floor(deckX + CGFloat(column + 1) * cell)
      return (.skill(index), CGRect(x: left, y: skillY + CGFloat(row) * 104,
                                  width: right - left, height: 104))
    }
    let transportY = metrics.inline ? skillY : skillY + CGFloat(metrics.rows) * 104
    let transportHeight: CGFloat = metrics.inline ? 104 : 64
    let factor = min(1, max(0, (available - nukeWidth - 24) / (transportWidth - nukeWidth - 24)))
    let usedWidth = nukeWidth + 24 + (transportWidth - nukeWidth - 24) * factor
    let transportX = metrics.inline ? deckX + skillBankWidth : deckX + max(0, (available - usedWidth) / 2)
    let nuke = CGRect(x: transportX + 12, y: transportY, width: nukeWidth, height: transportHeight)
    let down = CGRect(x: nuke.maxX + 12, y: transportY, width: 44 * factor, height: transportHeight)
    rateValueFrame = CGRect(x: down.maxX, y: transportY, width: 32 * factor, height: transportHeight)
    let up = CGRect(x: rateValueFrame.maxX, y: transportY, width: 44 * factor, height: transportHeight)
    let speed = CGRect(x: up.maxX, y: transportY, width: 100 * factor, height: transportHeight)
    timeline.frame = timelineInRow
      ? CGRect(x: speed.maxX, y: transportY, width: 132 * factor, height: transportHeight)
      : CGRect(x: deckX + available - 132, y: 0, width: 132, height: 52)
    let pause = CGRect(x: timelineInRow ? timeline.frame.maxX : speed.maxX,
                       y: transportY, width: 64 * factor, height: transportHeight)
    timeline.groupFrame = timelineInRow ? down.union(rateValueFrame).union(up).union(speed).union(timeline.frame).union(pause) : nil
    buttonFrames += [(.nuke, nuke), (.rateDown, down), (.rateUp, up),
                     (.fastForward, speed), (.pause, pause)]
  }

  /// Places the original controls and speed button over the status bar.
  private func layoutClassicButtons() {
    guard let panelImage else { return }
    timeline.groupFrame = nil
    rateValueFrame = .zero
    let statusHeight: CGFloat = isCRTSource || bounds.height <= 40 ? 0 : statusStripHeight
    let scale = max(1, floor(min(bounds.width / CGFloat(panelImage.width),
      (bounds.height - statusHeight) / CGFloat(panelImage.height))))
    panelScale = Double(scale)
    let size = CGSize(
      width: CGFloat(panelImage.width) * scale, height: CGFloat(panelImage.height) * scale)
    panelFrame = CGRect(
      x: (bounds.width - size.width) / 2, y: 0, width: size.width, height: size.height)

    let order: [PanelButton] = (0..<8).map(PanelButton.skill)
      + [.nuke, .rateDown, .rateUp, .fastForward, .pause]
    let cell = CGFloat(ClassicPanelGraphics.buttonWidth) * scale
    let controlHeight = min(panelFrame.height, GameHUDControlGroup.desktopHeight(forWidth: bounds.width))
    var x = panelFrame.minX
    buttonFrames = order.map { button in
      if button == .nuke || button == .rateDown { x += GameHUDControlGroup.spacing }
      let width = button == .fastForward && variableSpeedEnabled ? cell * 3 : cell
      let frame = CGRect(x: x, y: panelFrame.maxY - controlHeight, width: width, height: controlHeight)
      x = frame.maxX
      return (button, frame)
    }
    let mapLeft = x + 16 * scale
    minimapFrame = CGRect(
      x: mapLeft,
      y: panelFrame.minY + 18 * scale,
      width: max(0, panelFrame.maxX - mapLeft - 4 * scale),
      height: 20 * scale)
    layoutTimeline()
  }

  private func layoutTimeline() {
    let height = min(24 * max(1, panelScale / 2), minimapFrame.height * 0.6)
    timeline.frame = CGRect(x: minimapFrame.minX, y: minimapFrame.maxY - height, width: minimapFrame.width, height: height)
    minimapFrame.size.height -= height + 2
  }

  private func layoutButtons() {
    timeline.groupFrame = nil
    rateValueFrame = .zero
    let skillCount = session?.skills.count ?? 0
    var order: [PanelButton] = (0..<skillCount).map(PanelButton.skill)
    order.append(contentsOf: [.nuke, .rateDown, .rateUp, .fastForward, .pause])

    let statusHeight: CGFloat = isCRTSource || bounds.height <= 40 ? 0 : statusStripHeight
    let scale = max(1, floor(min(bounds.width / adaptivePanelWidth, (bounds.height - statusHeight) / 40)))
    panelScale = scale
    panelFrame = CGRect(x: floor((bounds.width - adaptivePanelWidth * scale) / 2), y: 0,
      width: adaptivePanelWidth * scale, height: 40 * scale)
    var x = panelFrame.minX
    buttonFrames = order.map { button in
      let units: CGFloat
      switch button {
      case .skill: units = 20
      case .fastForward: units = variableSpeedEnabled ? 48 : 16
      default: units = 16
      }
      if button == .nuke || button == .rateDown { x += GameHUDControlGroup.spacing }
      let height = min(panelFrame.height, GameHUDControlGroup.desktopHeight(forWidth: bounds.width))
      let frame = CGRect(x: x, y: panelFrame.maxY - height, width: units * scale, height: height)
      x = frame.maxX
      return (button, frame)
    }
    minimapFrame = CGRect(x: x + 16 * scale, y: 18 * scale,
      width: max(0, panelFrame.maxX - x - 20 * scale), height: 20 * scale)
    layoutTimeline()
  }

  // MARK: - Input

  /// Takes a click position directly, for input arriving from the tube view.
  func handleClick(at point: CGPoint, time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
    guard !isMenuMode else { return }
    layoutControls()
    if timeline.click(at: point) { return }
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
    guard !isMenuMode else { return }
    layoutControls()
    pointerIsDown = true
    if timeline.click(at: point) { return }
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
      if isEnabled(match.0), match.0 == .rateDown || match.0 == .rateUp { startRepeating(match.0) }
      return
    }
    nukeGesture.reset()
    if minimapFrame.contains(point) { scrollFromMinimap(point) }
  }

  override func mouseUp(with event: NSEvent) { handlePointerUp(time: event.timestamp) }

  func resetNukeGesture() { nukeGesture.reset() }

  private func press(_ button: PanelButton, time: TimeInterval, clickCount: Int = 1) {
    guard isEnabled(button) else { return }
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

  nonisolated(unsafe) private var repeatTimer: Timer?
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
  deinit { repeatTimer?.invalidate() }

  override func mouseDragged(with event: NSEvent) {
    handlePointerDrag(at: convert(event.locationInWindow, from: nil))
  }

  func handlePointerDrag(at point: CGPoint) {
    guard !isMenuMode else { return }
    layoutControls()
    if minimapFrame.contains(point) { scrollFromMinimap(point) }
  }

  private func scrollFromMinimap(_ point: CGPoint) {
    let map = minimapContentFrame
    guard map.width > 0, map.height > 0, levelSize.width > 0 else { return }
    let fraction = max(0, min(1, (point.x - map.minX) / map.width))
    onMinimapScroll?(Double(fraction) * levelSize.width)
    let vertical = max(0, min(1, (point.y - map.minY) / map.height))
    onMinimapPosition?(CGPoint(x: fraction * levelSize.width, y: vertical * levelSize.height))
  }

  // MARK: - Drawing

  override func draw(_ dirtyRect: NSRect) {
    let context = NSGraphicsContext.current?.cgContext
    context?.saveGState()
    defer { context?.restoreGState() }
    if isMonochrome { context?.setShouldAntialias(false) }
    timeline.monochrome = isMonochrome
    timeline.rock = isMonochrome ? { [weak self] size in self?.rockImage(fitting: size) } : nil
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
      layoutControls()
      drawClassicPanel()
      drawClassicCounts()
      drawSkillLabels()
      drawMinimap()
      drawStatus()
      drawSpeedControls()
      timeline.draw()
      return
    }

    layoutControls()
    for (button, frame) in buttonFrames { draw(button, in: frame) }
    drawClassicCounts()
    drawSkillLabels()
    drawMinimap()
    drawStatus()
    drawSpeedControls()
    timeline.draw()
  }

  private func drawSingleControlGlyph(_ image: NSImage, in frame: CGRect) {
    let box = controlIconBox(frame)
    image.draw(in: CGRect(x: floor(box.midX - image.size.width / 2),
                          y: floor(box.midY - image.size.height / 2),
                          width: image.size.width, height: image.size.height),
               from: .zero, operation: .sourceOver, fraction: 1,
               respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
  }

  private func controlIconBox(_ frame: CGRect) -> CGRect {
    if usesWideDeck && abs(frame.width - frame.height) < 0.01 {
      return frame.insetBy(dx: 6, dy: 6)
    }
    return frame.insetBy(dx: min(12, frame.width * 0.18), dy: min(10, frame.height * 0.15))
  }

  private func drawRateValue() {
    guard usesWideDeck, rateValueFrame.width > 0, let session else { return }
    drawGameLabel("\(session.rate)", in: rateValueFrame.insetBy(dx: 2, dy: 8))
  }

  private func drawSpeedControls() {
    guard variableSpeedEnabled, let frame = buttonFrames.first(where: { $0.0 == .fastForward })?.1 else { return }
    // Match the skill sockets' bevel so the speed box reads as the same stone.
    SpeedPanelControls.draw(in: frame, label: speedLabel, active: isFastForward,
      bevelPixel: max(1, panelScale / 2), backdrop: rockImage(fitting: frame.size), monochrome: isMonochrome,
      drawBackground: { [self] in drawStoneButton(frame, selected: isFastForward, button: .fastForward) },
      textInset: 2,
      text: { [self] text, box in drawGameLabel(text, in: box, maxPixelScale: .greatestFiniteMagnitude) })
  }

  private func drawClassicPanel() {
    guard let panelImage else { return }
    NSGraphicsContext.current?.imageInterpolation = .none
    if macArtwork != nil { drawMacPanel(); return }
    NSColor.black.setFill(); panelFrame.fill()
    for (button, frame) in buttonFrames where button == .rateDown || button == .rateUp {
      draw(button, in: frame)
    }

    for (button, frame) in buttonFrames {
      NSGraphicsContext.saveGraphicsState()
      defer { NSGraphicsContext.restoreGraphicsState() }
      clipControl(button, frame: frame)
      guard let glyph = PanelGlyph.forButton(button, isPaused: isPaused, canUndoNuke: session?.canUndoNuke == true) else { continue }
      let active = (button == .pause && isPaused) || (button == .fastForward && isFastForward)
        || (button == .nuke && session?.canUndoNuke == true)
      drawStoneButton(frame, selected: active, button: button)
      if glyph.isOriginalTile, let image = glyph.image(fitting: controlIconBox(frame).size, transparentRock: true) {
        drawSingleControlGlyph(image, in: frame)
      } else if let image = glyph.image(fitting: frame.insetBy(dx: 2 * panelScale, dy: 2 * panelScale).size) {
        image.draw(in: CGRect(x: frame.midX - image.size.width / 2, y: frame.midY - image.size.height / 2,
          width: image.size.width, height: image.size.height), from: .zero, operation: .sourceOver,
          fraction: 1, respectFlipped: true, hints: nil)
      }
    }

    for (button, frame) in buttonFrames {
      guard case let .skill(index) = button else { continue }
      drawStoneButton(frame, selected: index == selectedSkillIndex, button: button)
      guard let icon = panelImage.cropping(to: CGRect(x: (index + 2) * 16 + 1, y: 17, width: 14, height: 22)) else { continue }
      let well = skillArtworkFrame(frame)
      let fit = min(well.width / 14, well.height / 22)
      let scale = fit >= 1 ? floor(fit) : 1 / ceil(1 / fit)
      let image = NSImage(cgImage: icon, size: CGSize(width: 14 * scale, height: 22 * scale))
      image.draw(in: CGRect(x: floor(well.midX - image.size.width / 2), y: floor(well.midY - image.size.height / 2),
        width: image.size.width, height: image.size.height), from: .zero, operation: .sourceOver,
        fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
    }
    drawRateValue()
  }

  private func skillArtworkFrame(_ frame: CGRect) -> CGRect {
    let top: CGFloat = usesWideDeck ? 26 : 20
    let bottom: CGFloat = usesWideDeck ? 26 : panelScale >= 2 ? 14 : 4
    return CGRect(x: frame.minX + 4, y: frame.minY + top, width: max(0, frame.width - 8),
      height: max(1, frame.height - top - bottom))
  }

  private func drawMacPanel() {
    // All poses use the same source-pixel scale. Tools and the umbrella must
    // fit without making their lemmings smaller than the compact poses.
    let images = macSkillImages.enumerated().compactMap { index, image in index == 0 || index == 1 ? nil : image }
    let largest = CGSize(width: images.map(\.size.width).max() ?? 1,
      height: images.map(\.size.height).max() ?? 1)
    let fit = buttonFrames.compactMap { button, frame -> CGFloat? in
      guard case .skill = button else { return nil }
      let box = skillArtworkFrame(frame)
      return min(box.width / largest.width, box.height / largest.height)
    }.min() ?? 1
    let deviceScale = max(1, abs(NSGraphicsContext.current?.cgContext.convertToDeviceSpace(
      CGSize(width: 1, height: 0)).width ?? 1))
    let scale = fit * deviceScale >= 1 ? floor(fit * deviceScale) / deviceScale : fit
    let allImages = macSkillImages.compactMap { $0 }
    let oldLargest = CGSize(width: allImages.map(\.size.width).max() ?? 1,
      height: allImages.map(\.size.height).max() ?? 1)
    let oldFit = buttonFrames.compactMap { button, frame -> CGFloat? in
      guard case .skill = button else { return nil }
      let box = skillArtworkFrame(frame)
      return min(box.width / oldLargest.width, box.height / oldLargest.height)
    }.min() ?? 1
    let floaterScale = oldFit * deviceScale >= 1 ? floor(oldFit * deviceScale) / deviceScale : oldFit
    for (button, frame) in buttonFrames {
      NSGraphicsContext.saveGraphicsState()
      defer { NSGraphicsContext.restoreGraphicsState() }
      clipControl(button, frame: frame)
      let selected = button == .skill(selectedSkillIndex) || (button == .pause && isPaused)
        || (button == .fastForward && isFastForward) || (button == .nuke && session?.canUndoNuke == true)
      drawStoneButton(frame, selected: selected, button: button)
      if case let .skill(index) = button, let image = macSkillImages[safe: index] ?? nil {
        let box = skillArtworkFrame(frame)
        let preferredScale = index == 1 ? floaterScale : scale
        let iconScale = index == 0 || index == 1 ? min(preferredScale, box.width / image.size.width, box.height / image.size.height) : scale
        let size = CGSize(width: image.size.width * iconScale, height: image.size.height * iconScale)
        let top = box.midY - size.height / 2
        if let context = NSGraphicsContext.current?.cgContext,
           let bitmap = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
          GameSkillSelectionArt.drawSprite(bitmap, in: CGRect(x: floor(box.midX - size.width / 2),
            y: floor(top), width: size.width, height: size.height),
            selected: selected, context: context)
        }
      } else if let glyph = PanelGlyph.forButton(button, isPaused: isPaused, canUndoNuke: session?.canUndoNuke == true),
        glyph.isOriginalTile,
        let image = controlImage(glyph, fitting: controlIconBox(frame).size) {
        drawSingleControlGlyph(image, in: frame)
      } else if let glyph = PanelGlyph.forButton(button, isPaused: isPaused, canUndoNuke: session?.canUndoNuke == true),
        // Rasterise the control glyph to fit the recessed well.
        let image = controlImage(glyph,
          fitting: frame.insetBy(
            dx: 4 * max(1, panelScale / 2), dy: 4 * max(1, panelScale / 2)).size) {
        image.draw(
          in: CGRect(x: frame.midX - image.size.width / 2,
            y: frame.midY - image.size.height / 2,
            width: image.size.width, height: image.size.height),
          from: .zero, operation: .sourceOver, fraction: 1,
          respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
      } else {
        let symbol: String
        switch button {
        case .rateDown: symbol = "−"
        case .rateUp: symbol = "+"
        case .pause, .nuke, .fastForward, .skill: symbol = ""
        }
        drawGameLabel(symbol.replacingOccurrences(of: "−", with: "-"), in: frame.insetBy(dx: 4 * panelScale, dy: 4 * panelScale))
      }
    }
    drawRateValue()
    (isMonochrome ? NSColor.white : NSColor(calibratedWhite: 0.42, alpha: 1)).setStroke()
    NSBezierPath(rect: minimapFrame).stroke()
  }

  /// Pixel bevels keep the controls in the same visual period as the sprites.
  /// Joined controls retain their own Macintosh panel face inside one contour.
  private func drawStoneButton(_ frame: CGRect, selected: Bool, button: PanelButton) {
    if usesWideDeck, button == .rateUp { return }
    let face: GamePlayButtonArt.Face
    switch button {
    case .skill(let index): face = .skill(index)
    case .rateDown: face = .rateDown
    case .rateUp: face = .rateUp
    case .pause: face = .pause
    case .nuke: face = .endRun
    case .fastForward: face = .speed
    }
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    let group = controlGroupFrame(button, frame: frame)
    let drawnFrame: CGRect
    if usesWideDeck, button == .rateDown,
       let up = buttonFrames.first(where: { $0.0 == .rateUp })?.1 {
      drawnFrame = frame.union(rateValueFrame).union(up)
    } else { drawnFrame = frame }
    GameControlGroupArt.draw(in: context, frame: drawnFrame, group: group, selected: selected,
      face: face, monochrome: isMonochrome)
  }

  private func controlGroupFrame(_ button: PanelButton, frame: CGRect) -> CGRect {
    if usesWideDeck && button != .nuke {
      switch button {
      case .rateDown, .rateUp, .fastForward, .pause:
        let transport = buttonFrames.filter { item, _ in
          item == .rateDown || item == .rateUp || item == .fastForward || item == .pause
        }.map(\.1)
        return transport.reduce(rateValueFrame) { $0.union($1) }
      default: break
      }
    }
    let family = buttonFrames.filter { candidate, _ in
      switch button {
      case .skill: if case .skill = candidate { return true }; return false
      case .nuke: return candidate == .nuke
      default: return candidate == .rateDown || candidate == .rateUp || candidate == .pause || candidate == .fastForward
      }
    }.map(\.1)
    return GameHUDControlGroup.bounds(containing: frame, in: family)
  }

  private func clipControl(_ button: PanelButton, frame: CGRect) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    context.addPath(GameControlGroupArt.path(in: controlGroupFrame(button, frame: frame)))
    context.clip()
  }

  private func drawSkillLabels() {
    guard panelScale >= 2 else { return }
    let shortNames = ["walker": L10n.text("WALK"), "jumper": L10n.text("JUMP"), "shimmier": L10n.text("SHIM"), "slider": L10n.text("SLIDE"),
      "climber": L10n.text("CLIMB"), "swimmer": L10n.text("SWIM"), "floater": L10n.text("FLOAT"), "glider": L10n.text("GLIDE"),
      "disarmer": L10n.text("DISARM"), "bomber": L10n.text("BOMB"), "stoner": L10n.text("STONE"), "blocker": L10n.text("BLOCK"),
      "platformer": L10n.text("PLAT"), "builder": L10n.text("BUILD"), "stacker": L10n.text("STACK"), "laserer": L10n.text("LASER"),
      "basher": L10n.text("BASH"), "fencer": L10n.text("FENCE"), "miner": L10n.text("MINE"), "digger": L10n.text("DIG"), "cloner": L10n.text("CLONE")]
    let baseNames = session?.skills.map { shortNames[$0.name.lowercased()] ?? SkillVocabulary.title($0.name).uppercased() } ?? []
    let shortcuts = SkillShortcuts(names: session?.skills.map(\.name) ?? [])
    let names = baseNames.enumerated().map { index, name in
      guard let key = skillShortcut(index, shortcuts: shortcuts), !name.contains(key) else { return name }
      return String(key) + " " + name
    }
    let labelWidth = buttonFrames.compactMap { button, frame -> CGFloat? in
      if case .skill = button { return max(0, frame.width - 8) }
      return nil
    }.min() ?? 0
    let labelHeight: CGFloat = usesWideDeck ? 20 : 10
    let macScale: Int
    if let font = (macInterface ?? GameMenuArtwork.renderer())?.font(.small), names.allSatisfy({ font.covers($0) }) {
      let longest = names.map { font.width(of: $0) }.max() ?? 1
      macScale = min(Int(labelWidth) / max(1, longest),
                     Int(labelHeight) / max(1, font.height(of: names.joined())))
    } else { macScale = 0 }
    let pixelBounds = GamePixelTypography.verticalBounds(of: names.joined())
    let longestPixels = names.map { GamePixelTypography.width(of: $0) }.max() ?? 1
    let pixelScale = max(1, min(3, floor(min(labelHeight / CGFloat(pixelBounds.bottom - pixelBounds.top), labelWidth / CGFloat(longestPixels)))))
    for (button, frame) in buttonFrames {
      guard case let .skill(index) = button, let name = names[safe: index] else { continue }
      let box = CGRect(x: frame.minX + 4, y: frame.maxY - labelHeight - 4,
        width: frame.width - 8, height: labelHeight)
      let key = skillShortcut(index, shortcuts: shortcuts)
      // Choose one face and scale for the whole row, including the fallback.
      if macScale > 0 {
        _ = drawMacLabel(name, centeredIn: box, scale: macScale, highlighted: key)
      } else {
        GamePixelText.draw(name, in: box, maxScale: pixelScale, highlighted: key, palette: panelPalette)
      }
    }
  }

  private func skillShortcut(_ index: Int, shortcuts: SkillShortcuts) -> Character? {
    guard modernControlsEnabled, shortcuts.letters.indices.contains(index) else { return nil }
    let initial = shortcuts.initials[index]
    let shared = initial.map { letter in shortcuts.initials.filter { $0 == letter }.count > 1 } ?? false
    return (shared ? initial : shortcuts.letters[index])?.uppercased().first
  }

  private func drawClassicCounts() {
    guard let session else { return }
    for (button, frame) in buttonFrames {
      let value: String
      switch button {
      case .rateDown, .rateUp:
        if usesWideDeck { continue }
        value = "\(session.rate)"
      case let .skill(index):
        guard let skill = session.skills[safe: index] else { continue }
        value = skill.isInfinite ? "∞" : "\(skill.count)"
      case .pause, .nuke, .fastForward:
        continue
      }
      let isSkill: Bool
      if case .skill = button { isSkill = true } else { isSkill = false }
      let box = isSkill ? CGRect(x: frame.minX + 4, y: frame.minY + 4, width: frame.width - 8, height: usesWideDeck ? 18 : 14)
        : CGRect(x: frame.minX + 2, y: frame.minY + 2, width: frame.width - 4, height: min(18, frame.height / 3))
      if !isSkill { NSColor.black.setFill(); box.fill() }
      if !isMonochrome, counterStyle == .macintosh,
        (macInterface ?? GameMenuArtwork.renderer())?.drawCounter(value, in: box, panelScale: isSkill ? (usesWideDeck ? 4 : 1) : panelScale) == true { continue }
      if drawMacLabel(value, centeredIn: box) { continue }
      GamePixelText.draw(value, in: box, palette: panelPalette)
    }
    if !usesClassicSkin { drawRateValue() }
  }

  private func isEnabled(_ button: PanelButton) -> Bool {
    switch button {
    case .rateDown, .rateUp:
      return (session as? NeoLemmixSession)?.simulation.configuration.spawnIntervalLocked != true
    default: return true
    }
  }

  private func draw(_ button: PanelButton, in frame: CGRect) {
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    clipControl(button, frame: frame)
    let selected = button == .skill(selectedSkillIndex) || (button == .pause && isPaused)
      || (button == .nuke && session?.canUndoNuke == true) || (button == .fastForward && isFastForward)
    let pixel = max(1, panelScale / 2)
    drawStoneButton(frame, selected: selected, button: button)
    let well: CGRect
    if case .skill = button { well = skillArtworkFrame(frame) }
    else { well = GameStoneButton.well(frame, pixel: pixel) }
    switch button {
    case .skill(let index):
      guard let skill = session?.skills[safe: index] else { return }
      if let image = neoSprites?.skillIcon(named: skill.name) {
        let fit = min(well.width / image.size.width, well.height / image.size.height)
        let scale = fit >= 1 ? floor(fit) : fit
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        NSGraphicsContext.saveGraphicsState()
        well.clip()
        if let context = NSGraphicsContext.current?.cgContext,
           let bitmap = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
          context.setAlpha(skill.isInfinite || skill.count > 0 ? 1 : 0.35)
          GameSkillSelectionArt.drawSprite(bitmap, in: CGRect(x: floor(well.midX - size.width / 2),
            y: floor(well.midY - size.height / 2), width: size.width, height: size.height),
            selected: selected, context: context)
        }
        NSGraphicsContext.restoreGraphicsState()
      } else {
        drawGameLabel(SkillVocabulary.title(skill.name), in: well)
      }

    case .rateDown, .rateUp:
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current?.cgContext.setAlpha(isEnabled(button) ? 1 : 0.3)
      drawGameLabel(button == .rateDown ? "-" : "+", in: well)
      NSGraphicsContext.restoreGraphicsState()
    case .fastForward where variableSpeedEnabled:
      break
    default:
      guard let glyph = PanelGlyph.forButton(button, isPaused: isPaused, canUndoNuke: session?.canUndoNuke == true),
            let image = usesMacStyleControls
              ? glyph.macImage(fitting: glyph.isOriginalTile ? controlIconBox(frame).size : well.size, transparentRock: true)
              : glyph.image(fitting: glyph.isOriginalTile ? controlIconBox(frame).size : well.size, transparentRock: true) else { return }
      if glyph.isOriginalTile {
        drawSingleControlGlyph(image, in: frame)
      } else {
        image.draw(in: CGRect(x: floor(well.midX - image.size.width / 2), y: floor(well.midY - image.size.height / 2),
          width: image.size.width, height: image.size.height), from: .zero, operation: .sourceOver,
          fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
      }
    }
  }

  private var minimapContentFrame: CGRect {
    guard levelSize.width > 0, levelSize.height > 0 else { return .zero }
    let scale = min(minimapFrame.width / levelSize.width, minimapFrame.height / levelSize.height)
    let size = CGSize(width: levelSize.width * scale, height: levelSize.height * scale)
    return CGRect(x: minimapFrame.midX - size.width / 2, y: minimapFrame.midY - size.height / 2,
      width: size.width, height: size.height)
  }

  private func drawMinimap() {
    // The original bar already draws the map surround, so only the dots and
    // the view rectangle go on top of it.
    if !usesClassicSkin {
      NSColor(calibratedWhite: 0.05, alpha: 1).setFill()
      minimapFrame.fill()
      NSColor(calibratedWhite: 0.42, alpha: 1).setStroke()
      NSBezierPath(rect: minimapFrame).stroke()
    }
    guard levelSize.width > 0, levelSize.height > 0, let session else { return }

    let scale = min(
      minimapFrame.width / levelSize.width, minimapFrame.height / levelSize.height)
    let drawn = minimapContentFrame.size
    let origin = minimapContentFrame.origin

    if let terrainImage, let context = NSGraphicsContext.current?.cgContext {
      NSGraphicsContext.current?.imageInterpolation = .none
      let map = minimapThumbnail.image(for: terrainImage, in: CGRect(origin: origin, size: drawn), context: context) ?? terrainImage
      NSImage(cgImage: map, size: levelSize).draw(
        in: CGRect(origin: origin, size: drawn), from: .zero,
        operation: .sourceOver, fraction: isMonochrome ? 1 : 0.8, respectFlipped: true, hints: nil)
    }
    (isMonochrome ? NSColor.white : NSColor.systemGreen).setFill()
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
    NSColor.white.withAlphaComponent(isMonochrome ? 1 : 0.8).setStroke()
    let outline = NSBezierPath(rect: window)
    outline.lineWidth = 1
    outline.stroke()
  }

  /// Draws a label in the release's small face, centered in a box.
  ///
  /// Returns false when the release has no character set or the text does not
  /// fit, so the caller can use the compact pixel face.
  /// Punctuation the character set does not carry, mapped to what it does.
  private func gameText(_ text: String) -> String {
    BitmapLatinGlyphs.uppercase(text, locale: L10n.interface.locale)
      .replacingOccurrences(of: "—", with: "-")
      .replacingOccurrences(of: "–", with: "-")
      .replacingOccurrences(of: "’", with: "'")
      .replacingOccurrences(of: "∞", with: "*")
      .replacingOccurrences(of: "×", with: "X")
      .replacingOccurrences(of: "•", with: "*")
  }

  /// Draws panel text in the game font, and in the pixel font only when the game font is missing a character.
  private func drawGameLabel(_ text: String, in box: CGRect, maxPixelScale: CGFloat = 3) {
    if !drawMacLabel(text, centeredIn: box) { GamePixelText.draw(text, in: box, maxScale: maxPixelScale, palette: panelPalette) }
  }

  private func drawMacLabel(_ text: String, centeredIn box: CGRect, scale wanted: Int = 0, highlighted: Character? = nil) -> Bool {
    guard let macInterface = macInterface ?? GameMenuArtwork.renderer(),
          let font = macInterface.font(.small) else { return false }
    let upper = gameText(text)
    guard font.covers(upper) else { return false }
    let fit = min(
      Int(box.width) / max(1, font.width(of: upper)),
      Int(box.height) / max(1, font.height(of: upper)))
    let scale = wanted > 0 ? wanted : fit
    guard scale >= 1, scale <= fit else { return false }
    let top = box.midY - CGFloat(font.height(of: upper, scale: scale)) / 2 - CGFloat(font.verticalBounds(of: upper).top * scale)
    macInterface.drawCentered(
      upper, face: .small, centerX: box.midX, top: top, scale: scale, palette: panelPalette)
    if let highlighted, let index = upper.firstIndex(of: highlighted) {
      let prefix = font.layout(String(upper[..<index]))
      let offset = prefix.last.map { $0.x + $0.advance } ?? 0
      let x = box.midX - macInterface.width(of: upper, face: .small, scale: scale) / 2
        + CGFloat((offset - font.horizontalBounds(of: upper).left) * scale)
      macInterface.draw(String(highlighted), face: .small,
        at: CGPoint(x: x, y: top),
        scale: scale, palette: isMonochrome ? .monochrome : .green)
      if isMonochrome {
        NSColor.white.setFill()
        CGRect(x: x, y: box.maxY - 1, width: CGFloat(font.cellWidth * scale - 1), height: 1).fill()
      }
    }
    return true
  }

  private func drawStatus() {
    let y = isMenuMode ? inset : panelFrame.maxY + 4
    let box = CGRect(x: inset, y: y, width: bounds.width - inset * 2, height: 20)
    let text = gameText(statusText)
    if let macInterface, let font = macInterface.font(.small), font.covers(text), font.height(of: text) <= Int(box.height) {
      macInterface.menuLine(text, in: box, alignment: .left, palette: panelPalette)
    } else {
      NSGraphicsContext.saveGraphicsState()
      NSBezierPath(rect: box).addClip()
      GamePixelText.draw(text, in: CGRect(x: inset, y: y, width: statusTextWidth(), height: 20),
        maxScale: pixelStatusScale(text), palette: panelPalette)
      NSGraphicsContext.restoreGraphicsState()
    }
    drawProgress(in: box, y: y)
  }

  /// GamePixelText fits `width + 1` columns per scale step, so the box must too.
  private func pixelStatusScale(_ text: String) -> CGFloat {
    let columns = CGFloat(GamePixelTypography.width(of: text) + 1)
    return max(1, min(2, floor((bounds.width - inset * 2) / columns)))
  }

  private func statusTextWidth() -> CGFloat {
    let text = gameText(statusText)
    if let macInterface, let font = macInterface.font(.small), font.covers(text), font.height(of: text) <= 20 {
      return macInterface.width(of: text, face: .small, scale: 1)
    }
    return CGFloat(GamePixelTypography.width(of: text) + 1) * pixelStatusScale(text)
  }

  /// Drawn from the right edge inward, so it cannot collide with the status text
  /// on the left however long either grows. It is dropped rather than truncated
  /// when the panel is too narrow to hold both.
  private func drawProgress(in box: CGRect, y: CGFloat) {
    guard !progressText.isEmpty else { return }
    let text = gameText(progressText)
    if let macInterface, let font = macInterface.font(.small), font.covers(text), font.height(of: text) <= Int(box.height) {
      let width = macInterface.width(of: text, face: .small, scale: 1)
      let x = bounds.width - inset - width
      guard x > inset + statusTextWidth() + 12 else { return }
      macInterface.menuLine(text, in: CGRect(x: x, y: y, width: width, height: box.height), alignment: .left, palette: panelPalette)
      return
    }
    // The original artwork has no Macintosh interface font. Without this the
    // whole field silently drew nothing for every player using it, which is
    // most of them. Fall back to the same glyphs the status line uses.
    let width = CGFloat(GamePixelTypography.width(of: text))
    let x = bounds.width - inset - width
    guard x > inset + statusTextWidth() + 12 else { return }
    GamePixelText.draw(text, in: CGRect(x: x, y: box.minY, width: width, height: box.height), maxScale: 1, palette: panelPalette)
  }

  /// Tall enough for the original bar at 3x, plus a status strip beneath it.
  var intrinsicHeight: CGFloat {
    wideDeckMetrics(for: 900).height
  }

  private let statusStripHeight: CGFloat = 28
}


extension Array {
  /// Panel layout can lag a session swap by one frame, so index safely.
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
#endif
