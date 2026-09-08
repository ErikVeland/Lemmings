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
  private var hdrOverlay: ExplosionHDRView?
  private(set) var hdrFlashes: [ExplosionFlash] = []
  private var hdrBirths: [Int:(tick:Int,expires:TimeInterval)] = [:]
  private var hdrLastTick = 0
  var presentsHDR = true {
    didSet {
      hdrOverlay?.isHidden = !presentsHDR
      hdrOverlay?.update(presentsHDR ? hdrFlashes : [],force:true)
    }
  }
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window != nil, hdrOverlay == nil {
      let overlay = ExplosionHDRView(frame:bounds)
      overlay.autoresizingMask = [.width,.height]
      overlay.isHidden = !presentsHDR
      addSubview(overlay)
      hdrOverlay = overlay
    }
    hdrOverlay?.update(presentsHDR ? hdrFlashes : [],force:true)
  }
  /// Lines drawn over the level before it starts or after it ends.
  var overlayTitle: String?
  var overlayLines: [String] = []
  var overlayFooter: String?
  /// Which overlay line is currently chosen, when the screen offers a choice.
  var overlayHighlight: Int?
  /// Marches real lemmings along the foot of the screen.
  var overlayShowsLemmings = false
  /// Advanced by the run loop so the march animates while a menu is up.
  var overlayFrame = 0
  var phase: GamePhase = .playing {
    didSet {
      if phase != oldValue { cursorViewPoint = nil; cursorLevelPoint = nil }
    }
  }
  var levelImage: CGImage?
  var imageScale = 1.0
  var macArtwork: ClassicMacArtwork? { didSet { invalidateSprites() } }
  /// Artwork for the menus, which outlives any level.
  ///
  /// A level's artwork is chosen in the settings and is thrown away between
  /// levels. The menus need lettering before a level is loaded and after one
  /// ends, so the front end holds its own reference.
  var interfaceArtwork: ClassicMacArtwork? {
    didSet {
      macInterface = interfaceArtwork
        .flatMap(ClassicMacUserInterface.init(artwork:))
        .map(MacInterfaceRenderer.init(interface:))
    }
  }
  private var macInterface: MacInterfaceRenderer?
  var macScene: ClassicMacScene? { didSet { sceneTick = nil } }
  var classicScene: ClassicRenderedLevel? {
    didSet { sceneTick = nil }
  }
  private var sceneTick: Int?

  private func refreshClassicScene() {
    guard let classicScene, let session = session as? ClassicSession,
          sceneTick != session.currentTick else { return }
    let rgba = macScene?.rgba(simulation: session.simulation)
      ?? ClassicSceneFrame.rgba(classicScene, simulation: session.simulation)
    imageScale = macScene == nil ? 1 : 2
    let width = macScene?.width ?? classicScene.width
    let height = macScene?.height ?? classicScene.height
    guard let provider = CGDataProvider(data: rgba as CFData),
          let image = CGImage(width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return }
    levelImage = image
    sceneTick = session.currentTick
  }
  var session: (any GameSession)? {
    didSet { if oldValue !== session { hdrBirths.removeAll(); hdrLastTick = 0 } }
  }
  var assets: ClassicMainDATAssets?
  var palette: [ClassicRGBColor] = []
  var viewport = Viewport()
  var onAssign: ((Int) -> Void)?
  var onViewportChanged: (() -> Void)?
  /// Called when a click should dismiss a briefing or a result.
  var onAdvancePhase: (() -> Void)?
  var onSelectOverlayLine: ((Int) -> Void)?
  private var overlayLineRects: [CGRect] = []

  private var spriteCache: [String: NSImage] = [:]
  private var cursorLevelPoint: CGPoint?
  private var cursorViewPoint: CGPoint?
  private var trackingArea: NSTrackingArea?

  override var isFlipped: Bool { true }
  override var acceptsFirstResponder: Bool { true }

  override func setFrameSize(_ newSize: NSSize) {
    let center = viewport.scrollX + viewport.visibleSize.width / 2
    let hadSize = viewport.viewSize.width > 1
    super.setFrameSize(newSize)
    viewport.viewSize = newSize
    if hadSize { viewport.center(on: center) }
    onViewportChanged?()
  }

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

  /// Takes a cursor position directly.
  ///
  /// When the picture is drawn through the tube the events land on that view,
  /// not this one, so a point arrives already converted.
  func handleMove(to point: CGPoint) {
    cursorViewPoint = point
    cursorLevelPoint = viewport.levelPoint(from: point)
    needsDisplay = true
  }

  /// Takes a click position directly.
  func handleClick(at point: CGPoint) {
    guard phase == .playing else {
      if overlayHighlight != nil {
        if let index = overlayLineRects.firstIndex(where: { $0.contains(point) }) { onSelectOverlayLine?(index) }
      } else { onAdvancePhase?() }
      return
    }
    cursorViewPoint = point
    cursorLevelPoint = viewport.levelPoint(from: point)
    if let target = lemming(at: viewport.levelPoint(from: point)) { onAssign?(target.id) }
  }

  override func mouseMoved(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    cursorViewPoint = point
    cursorLevelPoint = viewport.levelPoint(from: point)
    needsDisplay = true
  }

  override func mouseExited(with event: NSEvent) {
    clearPointer()
  }

  func clearPointer() {
    cursorLevelPoint = nil
    cursorViewPoint = nil
    needsDisplay = true
  }

  /// Level pixels to scroll this frame when the cursor rests near an edge.
  ///
  /// The classic game scrolls while the cursor sits in the outer margin. The
  /// speed rises closer to the edge.
  var edgeScrollDelta: Double? {
    guard let point = cursorViewPoint, bounds.width > 0, bounds.contains(point) else { return nil }
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
    handleClick(at: convert(event.locationInWindow, from: nil))
  }

  override func scrollWheel(with event: NSEvent) {
    // A trackpad swipe scrolls the level sideways, as the classic game does.
    viewport.scroll(dx: -Double(event.scrollingDeltaX), dy: -Double(event.scrollingDeltaY))
    onViewportChanged?()
    needsDisplay = true
  }

  /// The box around a lemming that the cursor must be inside to pick it.
  ///
  /// The anchor is the foot, so the box reaches upwards over the body. These
  /// bounds follow the original: a little narrower than the drawn sprite,
  /// because the sprite includes swinging arms and a pick area that wide makes
  /// neighbouring lemmings impossible to tell apart.
  private static let pickBox = (halfWidth: CGFloat(4), top: CGFloat(12), bottom: CGFloat(4))

  /// Returns the lemming under the point, or nothing when the cursor is clear.
  ///
  /// The cursor does not snap. Picking the nearest lemming within a radius
  /// looks like the cursor sticking to a lemming it is not over, and it makes
  /// two lemmings standing side by side impossible to choose between. Only a
  /// lemming the cursor is actually inside can be picked.
  ///
  /// When several overlap, the last one wins. That is the one drawn on top, so
  /// the choice matches what the player sees.
  func lemming(at point: CGPoint) -> SessionLemming? {
    guard let session else { return nil }
    return session.lemmings.last { contains($0, point) }
  }

  private func contains(_ lemming: SessionLemming, _ point: CGPoint) -> Bool {
    let box = Self.pickBox
    let x = CGFloat(lemming.x)
    let y = CGFloat(lemming.y)
    return point.x >= x - box.halfWidth && point.x <= x + box.halfWidth
      && point.y >= y - box.top && point.y <= y + box.bottom
  }

  func invalidateSprites() { spriteCache.removeAll() }

  // MARK: - Drawing

  override func draw(_ dirtyRect: NSRect) {
    hdrFlashes.removeAll(keepingCapacity:true)
    let tick = session?.currentTick ?? 0
    if tick < hdrLastTick { hdrBirths.removeAll() }
    hdrLastTick = tick
    defer { hdrOverlay?.update(presentsHDR ? hdrFlashes : []) }
    refreshClassicScene()
    // Fill the view's own area, not the dirty rectangle. AppKit passes a
    // rectangle that can cover the whole window, because these views share one
    // backing layer.
    NSColor.black.setFill()
    bounds.fill()

    // A menu can appear before any level is loaded, so the overlay must not
    // depend on there being a picture behind it.
    if let levelImage {
      viewport.viewSize = bounds.size
      viewport.levelSize = CGSize(width: Double(levelImage.width) / imageScale, height: Double(levelImage.height) / imageScale)
      viewport.clamp()

      NSGraphicsContext.current?.imageInterpolation = .none
      if phase != .playing, overlayShowsLemmings {
        // The backdrop behind a menu is decoration, not a view onto a level,
        // so it ignores the viewport. Feeding zoom into the crop width and the
        // scroll position into the crop origin made zooming on a menu move the
        // picture sideways, and change its size only past a threshold.
        // The picture fills the height and is centred on its own width.
        let scale = bounds.height / CGFloat(levelImage.height)
        let width = min(CGFloat(levelImage.width), bounds.width / scale)
        let x = (CGFloat(levelImage.width) - width) / 2
        if let cropped = levelImage.cropping(to: CGRect(x: x, y: 0,
          width: width, height: CGFloat(levelImage.height))) {
          NSImage(cgImage: cropped, size: .zero).draw(in: bounds, from: .zero,
            operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
      } else {
        drawLevel(levelImage)
        drawLemmings()
      }
      if phase == .playing { drawCursor() }
    }
    if phase != .playing { drawOverlay() }
  }

  /// Dims the level and shows the briefing or the result over it.
  ///
  /// The original put these on their own screens. Keeping the level visible
  /// behind them means the player can already read the terrain while the
  /// briefing is up, which is the one thing the original made you wait for.
  /// A colour from the level palette, so menus and levels share one table.
  ///
  /// Using system colours here is what makes a menu read as an application
  /// rather than as the game. Everything on screen comes from the same
  /// sixteen entries the terrain uses.
  private func paletteColor(_ index: Int, fallback: NSColor) -> NSColor {
    guard palette.indices.contains(index) else { return fallback }
    let entry = palette[index]
    return NSColor(
      calibratedRed: CGFloat(entry.red) / 255,
      green: CGFloat(entry.green) / 255,
      blue: CGFloat(entry.blue) / 255,
      alpha: 1)
  }

  private func drawOverlay() {
    overlayLineRects = []
    NSColor.black.withAlphaComponent(0.42).setFill()
    bounds.fill()
    let scale = min(2.5, bounds.width / 1100,
      bounds.height / CGFloat(190 + overlayLines.count * 42))
    let rowHeight = 42 * scale
    let width = min(bounds.width - 28 * scale, 820 * scale)
    // The release's title art needs a deeper band than a line of text does.
    let showsLogo = overlayTitle == "LEMMINGS" && macInterface?.interface.logo != nil
    let headerHeight = (showsLogo ? 116 : 62) * scale
    let height = CGFloat(88 + overlayLines.count * 42) * scale + headerHeight
    let board = CGRect(x: (bounds.width - width) / 2, y: (bounds.height - height) / 2,
      width: width, height: height)

    // Chunky stone edging and a moss cap echo the level terrain.
    (macInterface == nil ? NSColor(calibratedRed: 0.09, green: 0.12, blue: 0.16, alpha: 0.97)
      : NSColor(calibratedWhite: 0.015, alpha: 0.96)).setFill()
    board.fill()
    NSColor(calibratedRed: 0.36, green: 0.39, blue: 0.43, alpha: 1).setFill()
    for x in stride(from: board.minX, to: board.maxX, by: 28 * scale) {
      CGRect(x: x, y: board.minY, width: min(26 * scale, board.maxX - x), height: 7 * scale).fill()
      CGRect(x: x, y: board.maxY - 7 * scale,
        width: min(26 * scale, board.maxX - x), height: 7 * scale).fill()
    }
    NSColor(calibratedRed: 0.27, green: 0.62, blue: 0.12, alpha: 1).setFill()
    CGRect(x: board.minX, y: board.minY - 3 * scale, width: board.width, height: 4 * scale).fill()
    for x in stride(from: board.minX, to: board.maxX - 8 * scale, by: 19 * scale) {
      CGRect(x: x, y: board.minY, width: 6 * scale, height: 5 * scale).fill()
    }

    let titleAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 38 * scale, weight: .black),
      .foregroundColor: NSColor(calibratedRed: 0.48, green: 0.92, blue: 0.20, alpha: 1),
      .kern: 2 * scale]
    let lineAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedSystemFont(ofSize: 13 * scale, weight: .bold),
      .foregroundColor: NSColor(calibratedRed: 0.90, green: 0.89, blue: 0.77, alpha: 1)]
    let footerAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedSystemFont(ofSize: 10 * scale, weight: .medium),
      .foregroundColor: NSColor(calibratedRed: 0.68, green: 0.75, blue: 0.64, alpha: 1)]

    var y = board.minY + 19 * scale
    if showsLogo, let macInterface {
      _ = macInterface.drawLogo(
        centerX: bounds.midX, top: y - 4 * scale,
        maximumWidth: board.width - 40 * scale, maximumHeight: headerHeight - 26 * scale)
    } else if let overlayTitle {
      let text = overlayTitle.uppercased() as NSString
      let heading = CGRect(x: board.minX + 18 * scale, y: y,
        width: board.width - 36 * scale, height: headerHeight - 18 * scale)
      if !drawMacText(overlayTitle, in: heading, minimumScale: 2) {
        let size = text.size(withAttributes: titleAttributes)
        let point = CGPoint(x: bounds.midX - size.width / 2, y: y)
        var shadow = titleAttributes
        shadow[.foregroundColor] = NSColor.black
        text.draw(
          at: CGPoint(x: point.x + 3 * scale, y: point.y + 3 * scale), withAttributes: shadow)
        text.draw(at: point, withAttributes: titleAttributes)
      }
    }
    y += headerHeight
    for (index, line) in overlayLines.enumerated() {
      let row = CGRect(x: board.minX + 18 * scale, y: y,
        width: board.width - 36 * scale, height: rowHeight - 5 * scale)
      overlayLineRects.append(row)
      let chosen = index == overlayHighlight
      var attributes = lineAttributes
      if overlayHighlight != nil {
        (chosen
          ? (macInterface == nil
            ? NSColor(calibratedRed: 0.23, green: 0.32, blue: 0.17, alpha: 1)
            : NSColor(calibratedRed: 0.78, green: 0.82, blue: 0.88, alpha: 1))
          : NSColor(calibratedWhite: macInterface == nil ? 0.17 : 0.025, alpha: 1)).setFill()
        row.fill()
        (chosen
          ? (macInterface == nil
            ? NSColor(calibratedRed: 0.70, green: 0.84, blue: 0.29, alpha: 1)
            : NSColor(calibratedWhite: 0.96, alpha: 1))
          : NSColor(calibratedWhite: 0.29, alpha: 1)).setStroke()
        let outline = NSBezierPath(rect: row.insetBy(dx: 0.5, dy: 0.5))
        outline.lineWidth = max(1, scale)
        outline.stroke()
      }
      if chosen { attributes[.foregroundColor] = NSColor(calibratedRed: 1, green: 0.93, blue: 0.53, alpha: 1) }
      let text = line as NSString
      let size = text.size(withAttributes: attributes)
      if !drawMacText(line, in: row.insetBy(dx: 14 * scale, dy: 5 * scale)) {
        text.draw(at: CGPoint(x: bounds.midX - size.width / 2, y: row.midY - size.height / 2),
          withAttributes: attributes)
      }
      y += rowHeight
    }
    if let overlayFooter {
      let top = y + 13 * scale
      if let macInterface, macInterface.font(.small)?.covers(overlayFooter) == true {
        macInterface.drawCentered(
          overlayFooter, face: .small, centerX: bounds.midX, top: top, scale: 1, alpha: 0.9)
      } else {
        let text = overlayFooter as NSString
        let size = text.size(withAttributes: footerAttributes)
        text.draw(at: CGPoint(x: bounds.midX - size.width / 2, y: top),
          withAttributes: footerAttributes)
      }
    }
    if overlayShowsLemmings { drawMarchingLemmings() }
  }

  /// Draws a menu line in the release's own character set.
  ///
  /// Both Macintosh character sets are monospaced, so every glyph advances one
  /// cell no matter how wide its own pixels are. The scale stays a whole
  /// number, because a fraction blurs pixels the original never blurred.
  private func drawMacText(
    _ text: String, in rect: CGRect, minimumScale: Int = 1
  ) -> Bool {
    guard let macInterface else { return false }
    // The original menus are upper case throughout.
    let normalized = text.uppercased()
      .replacingOccurrences(of: "—", with: "-")
      .replacingOccurrences(of: "’", with: "'")

    for face in [ClassicMacUserInterface.Face.large, .small] {
      guard let font = macInterface.font(face), font.covers(normalized) else { continue }
      let wide = font.cellWidth * max(1, normalized.count)
      let fit = min(Int(rect.height) / max(1, font.cellHeight), Int(rect.width) / max(1, wide))
      guard fit >= minimumScale else { continue }
      macInterface.drawCentered(
        normalized, face: face, centerX: rect.midX,
        top: rect.midY - macInterface.height(face: face, scale: fit) / 2, scale: fit)
      return true
    }
    return false
  }

  private func drawLevel(_ image: CGImage) {
    // Crop in image pixels. CGImage uses a top-left origin, which matches the
    // level coordinate system, so no vertical flip is needed here.
    let logical = viewport.visibleLevelRect
    let visible = CGRect(x: logical.minX * imageScale, y: logical.minY * imageScale,
      width: logical.width * imageScale, height: logical.height * imageScale)
    let crop = CGRect(
      x: floor(visible.minX), y: floor(visible.minY),
      width: min(ceil(visible.width) + 1, CGFloat(image.width) - floor(visible.minX)),
      height: min(ceil(visible.height) + 1, CGFloat(image.height) - floor(visible.minY)))
    guard crop.width > 0, crop.height > 0, let cropped = image.cropping(to: crop) else { return }

    let origin = viewport.viewPoint(fromLevel: CGPoint(x: crop.minX / imageScale, y: crop.minY / imageScale))
    let destination = CGRect(
      x: origin.x, y: origin.y,
      width: crop.width * viewport.zoom / imageScale, height: crop.height * viewport.zoom / imageScale)
    NSImage(cgImage: cropped, size: crop.size)
      .draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
  }

  private func drawLemmings() {
    guard let session else { return }
    for lemming in session.lemmings { draw(lemming) }
  }

  /// Four opaque ticks, then an immediate cut. The engine's longer explosion
  /// state still controls terrain damage and removal timing.
  static func bombPopIsVisible(tick: Int) -> Bool { (0..<4).contains(tick) }

  private func bombPop(_ rect: CGRect, tick: Int) -> (rect: CGRect, alpha: CGFloat) {
    (rect, Self.bombPopIsVisible(tick: tick) ? 1 : 0)
  }

  /// A short white-hot core, followed by one yellow tick. Solid pixel blocks
  /// keep the pop sharp without a screen-wide flash or a translucent tail.
  private func drawBombCore(in rect: CGRect, tick: Int, actor: Int) {
    guard (0..<2).contains(tick) else { return }
    let pixel = max(1, floor(viewport.zoom))
    let x = floor(rect.midX/pixel)*pixel, y = floor(rect.midY/pixel)*pixel
    (tick == 0 ? NSColor.white : NSColor.yellow).setFill()
    CGRect(x:x-3*pixel,y:y-pixel,width:6*pixel,height:2*pixel).fill()
    CGRect(x:x-pixel,y:y-3*pixel,width:2*pixel,height:6*pixel).fill()
    if phase == .playing {
      let birthTick = (session?.currentTick ?? 0)-tick
      if hdrBirths[actor]?.tick != birthTick {
        hdrBirths[actor] = (birthTick,ProcessInfo.processInfo.systemUptime+0.14)
      }
      let expires = hdrBirths[actor]!.expires
      let strength: Float = tick == 0 ? 1 : 0.5
      hdrFlashes.append(.init(rect:CGRect(x:x-3*pixel,y:y-pixel,width:6*pixel,height:2*pixel).intersection(bounds),strength:strength,expiresAt:expires))
      hdrFlashes.append(.init(rect:CGRect(x:x-pixel,y:y-3*pixel,width:2*pixel,height:6*pixel).intersection(bounds),strength:strength,expiresAt:expires))
    }
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

    if let frame = macArtwork?.lemming(pose: pose, left: lemming.facingLeft, tick: lemming.animationFrame) {
      let key = "mac-\(pose.rawValue)-\(direction.rawValue)-\(lemming.animationFrame)"
      let sprite = spriteCache[key] ?? frame.makeNSImage()
      if let sprite {
        if spriteCache.count < 1500 { spriteCache[key] = sprite }
        let origin = viewport.viewPoint(fromLevel: CGPoint(
          x: Double(lemming.x + animation.offsetX) + Double(frame.x) / 2,
          y: Double(lemming.y + animation.offsetY) + Double(frame.y) / 2))
        var rect = CGRect(x: origin.x, y: origin.y,
          width: Double(frame.width) * viewport.zoom / 2, height: Double(frame.height) * viewport.zoom / 2)
        var fraction: CGFloat = 1
        if pose == .explosion { (rect, fraction) = bombPop(rect, tick: lemming.animationFrame) }
        guard fraction > 0.01 else { return }
        sprite.draw(in: rect, from: .zero, operation: .sourceOver, fraction: fraction, respectFlipped: true, hints: nil)
        if pose == .explosion { drawBombCore(in: rect, tick: lemming.animationFrame, actor:lemming.id) }
        if let countdown = lemming.countdown { drawCountdown(countdown, above: rect) }
        return
      }
    }

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
    var rect = CGRect(
      x: origin.x, y: origin.y,
      width: sprite.size.width * viewport.zoom, height: sprite.size.height * viewport.zoom)
    var fraction: CGFloat = 1
    if pose == .explosion { (rect, fraction) = bombPop(rect, tick: lemming.animationFrame) }
    guard rect.intersects(bounds), fraction > 0.01 else { return }
    sprite.draw(in: rect, from: .zero, operation: .sourceOver, fraction: fraction, respectFlipped: true, hints: nil)
    if pose == .explosion { drawBombCore(in: rect, tick: lemming.animationFrame, actor:lemming.id) }

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

  /// Walks a row of real lemmings across the foot of a menu.
  ///
  /// These are the decoded walking frames the game uses in play, not artwork
  /// made for the menu, so the screen is built from the same sprites.
  private func drawMarchingLemmings() {
    if let macArtwork {
      let scale = max(1.5, min(3, bounds.width / 900))
      let spacing = 32 * scale
      var x = -spacing + (CGFloat(overlayFrame) * scale / 3).truncatingRemainder(dividingBy: spacing)
      var index = 0
      while x < bounds.width {
        if let frame = macArtwork.lemming(pose: .walking, left: false, tick: overlayFrame / 4 + index * 3),
          let image = frame.makeNSImage() {
          image.draw(in: CGRect(x: x + CGFloat(frame.x) * scale,
            y: bounds.height - CGFloat(20 - frame.y) * scale,
            width: CGFloat(frame.width) * scale, height: CGFloat(frame.height) * scale),
            from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        x += spacing; index += 1
      }
      return
    }
    guard let assets, !palette.isEmpty,
      let walk = assets.animation(for: .walking, direction: .right),
      !walk.frames.isEmpty
    else { return }

    let scale: CGFloat = 3
    let spacing: CGFloat = 46
    let baseline = bounds.height - 34 * scale / 3
    let drift = CGFloat(overlayFrame) * 0.6
    var x = -spacing + drift.truncatingRemainder(dividingBy: spacing)

    var index = 0
    while x < bounds.width + spacing {
      // Stagger the frames so they are not all in step, as a crowd would be.
      let frame = walk.frames[(overlayFrame / 4 + index * 3) % walk.frames.count]
      let key = "menu-\(frame.width)x\(frame.height)-\((overlayFrame / 4 + index * 3) % walk.frames.count)"
      let sprite: NSImage
      if let cached = spriteCache[key] {
        sprite = cached
      } else if let made = image(from: frame) {
        spriteCache[key] = made
        sprite = made
      } else {
        return
      }
      sprite.draw(
        in: NSRect(
          x: x, y: baseline,
          width: sprite.size.width * scale, height: sprite.size.height * scale),
        from: .zero, operation: .sourceOver, fraction: 0.85, respectFlipped: true, hints: nil)
      x += spacing
      index += 1
    }
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

@MainActor extension ClassicMacArtwork.Frame {
  func makeNSImage() -> NSImage? {
    guard let provider = CGDataProvider(data: rgba as CFData),
      let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
    return NSImage(cgImage: image, size: CGSize(width: width, height: height))
  }
}
