import AppKit
import NxlvKit

/// Maps between level pixels and view points for a scrolled, zoomed playfield.
struct Viewport {
  var scrollX = 0.0
  var scrollY = 0.0
  var zoom = 3.0
  var levelSize = CGSize(width: 1, height: 1)
  var viewSize = CGSize(width: 1, height: 1)

  /// Level pixels visible across the view.
  var visibleSize: CGSize {
    CGSize(width: viewSize.width / zoom, height: viewSize.height / zoom)
  }

  var maximumScrollX: Double { max(0, levelSize.width - visibleSize.width) }
  var maximumScrollY: Double { max(0, levelSize.height - visibleSize.height) }

  mutating func clamp() {
    scrollX = min(max(0, scrollX), maximumScrollX)
    scrollY = min(max(0, scrollY), maximumScrollY)
  }

  mutating func scroll(dx: Double, dy: Double) {
    scrollX += dx
    scrollY += dy
    clamp()
  }

  mutating func center(on x: Double) {
    scrollX = x - visibleSize.width / 2
    clamp()
  }

  /// Centers the level when it does not fill the view.
  ///
  /// Classic levels are 160 pixels tall, so at most zoom levels they leave
  /// space above and below.
  var contentOffset: CGPoint {
    let drawn = CGSize(width: levelSize.width * zoom, height: levelSize.height * zoom)
    return CGPoint(
      x: drawn.width < viewSize.width ? (viewSize.width - drawn.width) / 2 : 0,
      y: drawn.height < viewSize.height ? (viewSize.height - drawn.height) / 2 : 0)
  }

  /// Converts a view point to level pixels. The view is flipped, so both
  /// coordinate systems increase downward.
  func levelPoint(from viewPoint: CGPoint) -> CGPoint {
    let offset = contentOffset
    return CGPoint(
      x: scrollX + (viewPoint.x - offset.x) / zoom,
      y: scrollY + (viewPoint.y - offset.y) / zoom)
  }

  func viewPoint(fromLevel point: CGPoint) -> CGPoint {
    let offset = contentOffset
    return CGPoint(
      x: (point.x - scrollX) * zoom + offset.x,
      y: (point.y - scrollY) * zoom + offset.y)
  }

  var visibleLevelRect: CGRect {
    CGRect(x: scrollX, y: scrollY, width: visibleSize.width, height: visibleSize.height)
  }
}

/// What the screen is showing between levels.
enum GamePhase: Equatable {
  case briefing
  case playing
  case results
}

@MainActor final class PlayfieldView: NSView {
  /// Lines drawn over the level before it starts or after it ends.
  var overlayTitle: String?
  var overlayLines: [String] = []
  var overlayFooter: String?
  var phase: GamePhase = .playing
  var levelImage: CGImage?
  var session: (any GameSession)?
  var assets: ClassicMainDATAssets?
  var palette: [ClassicRGBColor] = []
  var viewport = Viewport()
  var onAssign: ((Int) -> Void)?
  var onViewportChanged: (() -> Void)?
  /// Called when a click should dismiss a briefing or a result.
  var onAdvancePhase: (() -> Void)?

  private var spriteCache: [String: NSImage] = [:]
  private var cursorLevelPoint: CGPoint?
  private var cursorViewPoint: CGPoint?
  private var trackingArea: NSTrackingArea?

  override var isFlipped: Bool { true }
  override var acceptsFirstResponder: Bool { true }

  // MARK: - Tracking

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let trackingArea { removeTrackingArea(trackingArea) }
    let area = NSTrackingArea(
      rect: bounds,
      options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
      owner: self)
    addTrackingArea(area)
    trackingArea = area
  }

  override func mouseMoved(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    cursorViewPoint = point
    cursorLevelPoint = viewport.levelPoint(from: point)
    needsDisplay = true
  }

  override func mouseExited(with event: NSEvent) {
    cursorLevelPoint = nil
    cursorViewPoint = nil
    needsDisplay = true
  }

  /// Level pixels to scroll this frame when the cursor rests near an edge.
  ///
  /// The classic game scrolls while the cursor sits in the outer margin. The
  /// speed rises closer to the edge.
  var edgeScrollDelta: Double? {
    guard let point = cursorViewPoint, bounds.width > 0 else { return nil }
    let margin = 48.0
    if point.x < margin {
      return -((margin - Double(point.x)) / margin) * 8
    }
    if point.x > Double(bounds.width) - margin {
      return ((Double(point.x) - (Double(bounds.width) - margin)) / margin) * 8
    }
    return nil
  }

  override func mouseDown(with event: NSEvent) {
    guard phase == .playing else {
      onAdvancePhase?()
      return
    }
    let viewPoint = convert(event.locationInWindow, from: nil)
    let point = viewport.levelPoint(from: viewPoint)
    cursorViewPoint = viewPoint
    cursorLevelPoint = point
    if let target = lemming(at: point) { onAssign?(target.id) }
  }

  override func scrollWheel(with event: NSEvent) {
    // A trackpad swipe scrolls the level sideways, as the classic game does.
    viewport.scroll(dx: -Double(event.scrollingDeltaX), dy: -Double(event.scrollingDeltaY))
    onViewportChanged?()
    needsDisplay = true
  }

  /// Returns the lemming nearest the point, inside a small pick radius.
  func lemming(at point: CGPoint) -> SessionLemming? {
    guard let session else { return nil }
    let nearest = session.lemmings.min {
      distance(from: $0, to: point) < distance(from: $1, to: point)
    }
    guard let nearest, distance(from: nearest, to: point) <= 10 else { return nil }
    return nearest
  }

  private func distance(from lemming: SessionLemming, to point: CGPoint) -> CGFloat {
    // The pick point sits slightly above the foot, over the lemming's body.
    hypot(CGFloat(lemming.x) - point.x, CGFloat(lemming.y) - 5 - point.y)
  }

  func invalidateSprites() { spriteCache.removeAll() }

  // MARK: - Drawing

  override func draw(_ dirtyRect: NSRect) {
    NSColor.black.setFill()
    dirtyRect.fill()
    guard let levelImage else { return }

    viewport.viewSize = bounds.size
    viewport.levelSize = CGSize(width: levelImage.width, height: levelImage.height)
    viewport.clamp()

    NSGraphicsContext.current?.imageInterpolation = .none
    drawLevel(levelImage)
    drawLemmings()
    if phase == .playing { drawCursor() }
    if phase != .playing { drawOverlay() }
  }

  /// Dims the level and shows the briefing or the result over it.
  ///
  /// The original put these on their own screens. Keeping the level visible
  /// behind them means the player can already read the terrain while the
  /// briefing is up, which is the one thing the original made you wait for.
  private func drawOverlay() {
    NSColor.black.withAlphaComponent(0.72).setFill()
    bounds.fill()

    let titleAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 30, weight: .bold),
      .foregroundColor: NSColor.white,
    ]
    let lineAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .regular),
      .foregroundColor: NSColor(calibratedWhite: 0.92, alpha: 1),
    ]
    let footerAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 13, weight: .medium),
      .foregroundColor: NSColor.systemGreen,
    ]

    var height: CGFloat = 0
    if let overlayTitle {
      height += (overlayTitle as NSString).size(withAttributes: titleAttributes).height + 18
    }
    height += CGFloat(overlayLines.count) * 24
    if overlayFooter != nil { height += 34 }

    var y = (bounds.height - height) / 2
    if let overlayTitle {
      let text = overlayTitle as NSString
      let size = text.size(withAttributes: titleAttributes)
      text.draw(at: CGPoint(x: (bounds.width - size.width) / 2, y: y),
                withAttributes: titleAttributes)
      y += size.height + 18
    }
    for line in overlayLines {
      let text = line as NSString
      let size = text.size(withAttributes: lineAttributes)
      text.draw(at: CGPoint(x: (bounds.width - size.width) / 2, y: y),
                withAttributes: lineAttributes)
      y += 24
    }
    if let overlayFooter {
      y += 10
      let text = overlayFooter as NSString
      let size = text.size(withAttributes: footerAttributes)
      text.draw(at: CGPoint(x: (bounds.width - size.width) / 2, y: y),
                withAttributes: footerAttributes)
    }
  }

  private func drawLevel(_ image: CGImage) {
    // Crop in image pixels. CGImage uses a top-left origin, which matches the
    // level coordinate system, so no vertical flip is needed here.
    let visible = viewport.visibleLevelRect
    let crop = CGRect(
      x: floor(visible.minX), y: floor(visible.minY),
      width: min(ceil(visible.width) + 1, CGFloat(image.width) - floor(visible.minX)),
      height: min(ceil(visible.height) + 1, CGFloat(image.height) - floor(visible.minY)))
    guard crop.width > 0, crop.height > 0, let cropped = image.cropping(to: crop) else { return }

    let origin = viewport.viewPoint(fromLevel: CGPoint(x: crop.minX, y: crop.minY))
    let destination = CGRect(
      x: origin.x, y: origin.y,
      width: crop.width * viewport.zoom, height: crop.height * viewport.zoom)
    NSImage(cgImage: cropped, size: crop.size)
      .draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1)
  }

  private func drawLemmings() {
    guard let session else { return }
    for lemming in session.lemmings { draw(lemming) }
  }

  private func draw(_ lemming: SessionLemming) {
    guard let assets, !palette.isEmpty else { return }
    let direction: ClassicSpriteDirection = lemming.facingLeft ? .left : .right
    let pose = lemming.pose
    guard
      let animation = assets.animation(for: pose, direction: direction)
        ?? assets.animation(for: pose, direction: .none),
      !animation.frames.isEmpty
    else { return }

    let index = abs(lemming.animationFrame) % animation.frames.count
    let key = "\(pose.rawValue)-\(direction.rawValue)-\(index)"
    let sprite: NSImage
    if let cached = spriteCache[key] {
      sprite = cached
    } else {
      guard let made = image(from: animation.frames[index]) else { return }
      spriteCache[key] = made
      sprite = made
    }

    let levelOrigin = CGPoint(
      x: CGFloat(lemming.x + animation.offsetX),
      y: CGFloat(lemming.y + animation.offsetY))
    let origin = viewport.viewPoint(fromLevel: levelOrigin)
    let rect = CGRect(
      x: origin.x, y: origin.y,
      width: sprite.size.width * viewport.zoom, height: sprite.size.height * viewport.zoom)
    guard rect.intersects(bounds) else { return }
    sprite.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)

    if let countdown = lemming.countdown {
      drawCountdown(countdown, above: rect)
    }
  }

  private func drawCountdown(_ countdown: Int, above rect: CGRect) {
    let seconds = max(1, (countdown + ClassicDOSRules.ticksPerSecond - 1) / ClassicDOSRules.ticksPerSecond)
    let text = "\(seconds)" as NSString
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedDigitSystemFont(ofSize: 10 * viewport.zoom / 3, weight: .bold),
      .foregroundColor: NSColor.white,
    ]
    let size = text.size(withAttributes: attributes)
    text.draw(
      at: CGPoint(x: rect.midX - size.width / 2, y: rect.minY - size.height),
      withAttributes: attributes)
  }

  private func drawCursor() {
    guard let point = cursorLevelPoint else { return }
    let target = lemming(at: point)
    let center = viewport.viewPoint(
      fromLevel: target.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y) - 5) } ?? point)
    let side = 14 * viewport.zoom
    let box = CGRect(
      x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)

    let path = NSBezierPath()
    let arm = side / 3
    // Corner brackets read clearly over busy terrain.
    for (dx, dy) in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)] {
      let cx = box.minX + box.width * dx
      let cy = box.minY + box.height * dy
      let sx: CGFloat = dx == 0 ? 1 : -1
      let sy: CGFloat = dy == 0 ? 1 : -1
      path.move(to: CGPoint(x: cx + arm * sx, y: cy))
      path.line(to: CGPoint(x: cx, y: cy))
      path.line(to: CGPoint(x: cx, y: cy + arm * sy))
    }
    path.lineWidth = max(1, viewport.zoom / 2)
    (target == nil ? NSColor.white.withAlphaComponent(0.5) : NSColor.systemGreen).setStroke()
    path.stroke()
  }

  private func image(from frame: ClassicIndexedBitmap) -> NSImage? {
    guard
      let rgba = try? frame.rgba(using: palette),
      let provider = CGDataProvider(data: rgba as CFData),
      let cg = CGImage(
        width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    else { return nil }
    return NSImage(cgImage: cg, size: CGSize(width: frame.width, height: frame.height))
  }
}

func spritePose(for action: ClassicDOSAction) -> ClassicLemmingPose {
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
