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
}

@MainActor final class PanelView: NSView {
  var session: (any GameSession)?
  var selectedSkillIndex = 0
  var isPaused = false
  var statusText = ""
  var levelSize = CGSize(width: 1, height: 1)
  var visibleLevelRect = CGRect.zero

  /// The original status bar, when the imported data provides it.
  var panelImage: CGImage?
  var onButton: ((PanelButton) -> Void)?
  var onMinimapScroll: ((Double) -> Void)?

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

  /// Places the twelve original buttons over the drawn status bar.
  private func layoutClassicButtons() {
    guard let panelImage else { return }
    let scale = max(1, floor(bounds.width / CGFloat(panelImage.width)))
    panelScale = Double(scale)
    let size = CGSize(
      width: CGFloat(panelImage.width) * scale, height: CGFloat(panelImage.height) * scale)
    panelFrame = CGRect(
      x: (bounds.width - size.width) / 2, y: 0, width: size.width, height: size.height)
    _ = statusStripHeight

    let order: [PanelButton] = [.rateDown, .rateUp]
      + (0..<8).map(PanelButton.skill) + [.pause, .nuke]
    let cell = CGFloat(ClassicPanelGraphics.buttonWidth) * scale
    buttonFrames = order.enumerated().map { index, button in
      (button, CGRect(
        x: panelFrame.minX + cell * CGFloat(index), y: panelFrame.minY,
        width: cell, height: panelFrame.height))
    }
    // The original reserves the right of the bar for the level map.
    let mapLeft = panelFrame.minX + cell * CGFloat(order.count) + 16 * scale
    minimapFrame = CGRect(
      x: mapLeft,
      y: panelFrame.minY + 4 * scale,
      width: max(0, panelFrame.maxX - mapLeft - 4 * scale),
      height: panelFrame.height - 8 * scale)
  }

  private func layoutButtons() {
    let skillCount = session?.skills.count ?? 0
    var order: [PanelButton] = [.rateDown, .rateUp]
    order.append(contentsOf: (0..<skillCount).map(PanelButton.skill))
    order.append(contentsOf: [.pause, .nuke])

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

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    if let match = buttonFrames.first(where: { $0.1.contains(point) }) {
      onButton?(match.0)
      return
    }
    if minimapFrame.contains(point) { scrollFromMinimap(point) }
  }

  override func mouseDragged(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    if minimapFrame.contains(point) { scrollFromMinimap(point) }
  }

  private func scrollFromMinimap(_ point: CGPoint) {
    guard minimapFrame.width > 0, levelSize.width > 0 else { return }
    let fraction = (point.x - minimapFrame.minX) / minimapFrame.width
    onMinimapScroll?(Double(fraction) * levelSize.width)
  }

  // MARK: - Drawing

  override func draw(_ dirtyRect: NSRect) {
    NSColor.black.setFill()
    dirtyRect.fill()

    if usesClassicSkin {
      layoutClassicButtons()
      drawClassicPanel()
      drawClassicCounts()
      drawMinimap()
      drawStatus()
      return
    }

    NSColor(calibratedWhite: 0.11, alpha: 1).setFill()
    dirtyRect.fill()
    layoutButtons()
    for (button, frame) in buttonFrames { draw(button, in: frame) }
    drawMinimap()
    drawStatus()
  }

  private func drawClassicPanel() {
    guard let panelImage else { return }
    NSGraphicsContext.current?.imageInterpolation = .none
    NSImage(cgImage: panelImage, size: NSSize(width: panelImage.width, height: panelImage.height))
      .draw(in: panelFrame, from: .zero, operation: .sourceOver, fraction: 1)

    // Mark the armed skill, which the original showed with a lit border.
    guard let match = buttonFrames.first(where: { $0.0 == .skill(selectedSkillIndex) })
    else { return }
    // The art occupies the upper rows of each cell, so the marker follows it.
    let art = CGRect(
      x: match.1.minX, y: match.1.minY,
      width: match.1.width, height: match.1.height * 0.72)
    NSColor.white.setStroke()
    let outline = NSBezierPath(rect: art.insetBy(dx: 1, dy: 1))
    outline.lineWidth = 2
    outline.stroke()
  }

  /// Draws the live counts into the boxes above each button.
  private func drawClassicCounts() {
    guard let session else { return }
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedDigitSystemFont(
        ofSize: max(8, 8 * panelScale / 2), weight: .bold),
      .foregroundColor: NSColor.white,
    ]
    for (button, frame) in buttonFrames {
      guard case let .skill(index) = button, let skill = session.skills[safe: index] else {
        continue
      }
      let text = (skill.isInfinite ? "∞" : "\(skill.count)") as NSString
      let size = text.size(withAttributes: attributes)
      text.draw(
        at: CGPoint(x: frame.midX - size.width / 2, y: frame.minY + 2),
        withAttributes: attributes)
    }
  }

  private func draw(_ button: PanelButton, in frame: CGRect) {
    let title: String
    let subtitle: String
    var highlighted = false

    switch button {
    case .rateDown:
      title = "◀"
      subtitle = session?.rateLabel.lowercased() ?? "rate"
    case .rateUp:
      title = "▶"
      subtitle = session?.rateLabel.lowercased() ?? "rate"
    case let .skill(index):
      let skill = session?.skills[safe: index]
      title = skill?.name ?? "—"
      subtitle = skill.map { $0.isInfinite ? "∞" : "\($0.count)" } ?? "0"
      highlighted = index == selectedSkillIndex
    case .pause:
      title = isPaused ? "Play" : "Pause"
      subtitle = ""
    case .nuke:
      title = "Nuke"
      subtitle = ""
    }

    let path = NSBezierPath(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
    (highlighted ? NSColor.systemGreen.withAlphaComponent(0.30) : NSColor(calibratedWhite: 0.20, alpha: 1))
      .setFill()
    path.fill()
    (highlighted ? NSColor.systemGreen : NSColor(calibratedWhite: 0.34, alpha: 1)).setStroke()
    path.lineWidth = highlighted ? 2 : 1
    path.stroke()

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
      height: visibleLevelRect.height * scale)
    NSColor.white.withAlphaComponent(0.8).setStroke()
    let outline = NSBezierPath(rect: window)
    outline.lineWidth = 1
    outline.stroke()
  }

  private func drawStatus() {
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
      .foregroundColor: NSColor(calibratedWhite: 0.85, alpha: 1),
    ]
    let y = usesClassicSkin ? panelFrame.maxY + 4 : inset + buttonHeight + 6
    (statusText as NSString).draw(
      at: CGPoint(x: inset, y: y), withAttributes: attributes)
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
