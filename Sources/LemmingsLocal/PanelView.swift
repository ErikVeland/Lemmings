import AppKit
import NxlvKit

/// The buttons along the bottom of the classic screen.
enum PanelButton: Equatable {
  case rateDown
  case rateUp
  case skill(ClassicSkill)
  case pause
  case nuke
}

@MainActor final class PanelView: NSView {
  var simulation: ClassicDOSSimulation?
  var selectedSkill: ClassicSkill = .builder
  var isPaused = false
  var statusText = ""
  var levelSize = CGSize(width: 1, height: 1)
  var visibleLevelRect = CGRect.zero

  var onButton: ((PanelButton) -> Void)?
  var onMinimapScroll: ((Double) -> Void)?

  private var buttonFrames: [(PanelButton, CGRect)] = []
  private var minimapFrame = CGRect.zero

  override var isFlipped: Bool { true }

  private let buttonHeight = 34.0
  private let inset = 8.0
  private let gap = 4.0

  // MARK: - Layout

  private func layoutButtons() {
    var order: [PanelButton] = [.rateDown, .rateUp]
    order.append(contentsOf: ClassicSkill.allCases.map(PanelButton.skill))
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
    NSColor(calibratedWhite: 0.11, alpha: 1).setFill()
    dirtyRect.fill()
    layoutButtons()

    for (button, frame) in buttonFrames { draw(button, in: frame) }
    drawMinimap()
    drawStatus()
  }

  private func draw(_ button: PanelButton, in frame: CGRect) {
    let title: String
    let subtitle: String
    var highlighted = false

    switch button {
    case .rateDown:
      title = "◀"
      subtitle = "rate"
    case .rateUp:
      title = "▶"
      subtitle = "rate"
    case let .skill(skill):
      title = String(skill.rawValue.prefix(5)).capitalized
      subtitle = simulation.map { "\($0.remainingSkillCount(skill))" } ?? "0"
      highlighted = skill == selectedSkill
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
      .font: NSFont.systemFont(ofSize: 11, weight: .medium),
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
    NSColor(calibratedWhite: 0.05, alpha: 1).setFill()
    NSBezierPath(roundedRect: minimapFrame, xRadius: 3, yRadius: 3).fill()
    guard levelSize.width > 0, levelSize.height > 0, let simulation else { return }

    let scale = min(
      minimapFrame.width / levelSize.width, minimapFrame.height / levelSize.height)
    let drawn = CGSize(width: levelSize.width * scale, height: levelSize.height * scale)
    let origin = CGPoint(
      x: minimapFrame.minX + (minimapFrame.width - drawn.width) / 2,
      y: minimapFrame.minY + (minimapFrame.height - drawn.height) / 2)

    NSColor.systemGreen.setFill()
    for lemming in simulation.lemmings where lemming.isActive {
      let dot = CGRect(
        x: origin.x + CGFloat(lemming.foot.x) * scale - 1,
        y: origin.y + CGFloat(lemming.foot.y) * scale - 1,
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
    (statusText as NSString).draw(
      at: CGPoint(x: inset, y: inset + buttonHeight + 6), withAttributes: attributes)
  }

  var intrinsicHeight: CGFloat { inset * 2 + buttonHeight + 22 }
}
