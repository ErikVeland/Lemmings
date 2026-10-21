#if os(macOS)
import AppKit
import NxlvKit
import LemmingsGameArt

/// Afterimages follow moving actors. Solid sprites stay sharp.
@MainActor final class SpeedTrails {
  static let maximumTrails = 24
  var multiplier: Double = 3
  private struct TrailKey: Hashable {
    let direction: Int, pixelX: Int, pixelY: Int, tier: Int, echoes: Int
    let mirrored: Bool
    let sharp: Bool
    var motion: CGVector {
      let angle = CGFloat(direction) * .pi / 8
      let dx = cos(angle), dy = sin(angle)
      return CGVector(dx: abs(dx) < 0.0001 ? 0 : dx, dy: abs(dy) < 0.0001 ? 0 : dy)
    }
  }
  private static let tiers: [Double] = [2, 3, 5, 10]
  private static let distances: [[CGFloat]] = [[2, 6], [2, 6, 10], [2, 7, 12, 17], [2, 8, 14, 20, 26]]

  private struct TrailImage {
    let image: CGImage
    let bounds: CGRect
    let origin: CGPoint
  }
  struct Actor: Equatable {
    let id: Int
    let position: CGPoint
    var movement: String = "moving"
  }
  private struct MotionSample {
    let actor: Actor
    let steps: [CGVector]
    let motion: CGVector
    let direction: Int?
  }
  private final class SpriteTrails {
    let source: CGImage
    var images: [TrailKey: TrailImage] = [:]
    var order: [TrailKey] = []
    var byteCost = 0
    init(source: CGImage) { self.source = source }
  }
  private let sprites = NSCache<NSImage, SpriteTrails>()
  private var drawingContext: CGContext?
  private var clip = CGRect.zero
  private var occupiedCells: UInt64 = 0
  private var lastTick: Int?
  private var rewindOrigin: [Int: Actor] = [:]
  private var rewindUntil: TimeInterval = 0
  private var rewindExpiry: Task<Void, Never>?
  var isRewinding: Bool { ProcessInfo.processInfo.systemUptime < rewindUntil }

  /// Capture positions, without rendering or copying the playfield.
  func prepareRewind(actors: [Actor]) {
    rewindOrigin = Dictionary(uniqueKeysWithValues: actors.map { ($0.id, $0) })
  }

  /// A fresh impulse replaces the previous one, including during rapid key repeats.
  func finishRewind(tick: Int, actors: [Actor], redraw: @escaping @MainActor () -> Void) {
    let origin = rewindOrigin
    reset()
    lastTick = tick
    for actor in actors {
      guard let previous = origin[actor.id] else { continue }
      let delta = CGVector(dx: actor.position.x - previous.position.x,
                           dy: actor.position.y - previous.position.y)
      guard delta != .zero else { continue }
      currentPositions[actor.id] = MotionSample(actor: actor, steps: [], motion: delta,
        direction: Self.direction(for: delta, retaining: nil))
    }
    rewindUntil = ProcessInfo.processInfo.systemUptime + 0.16
    rewindExpiry = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 160_000_000)
      guard !Task.isCancelled else { return }
      self?.reset()
      redraw()
    }
  }
  private var currentPositions: [Int: MotionSample] = [:]
  private(set) var drawnTrailCount = 0

  init() { sprites.countLimit = 128; sprites.totalCostLimit = 32 * 1024 * 1024 }

  func reset() {
    rewindExpiry?.cancel()
    rewindExpiry = nil
    rewindUntil = 0
    rewindOrigin.removeAll(keepingCapacity: true)
    drawingContext = nil
    occupiedCells = 0
    drawnTrailCount = 0
    lastTick = nil
    currentPositions.removeAll(keepingCapacity: true)
  }

  /// Sample once per game tick, independently of live redraws and movie capture.
  func update(tick: Int, enabled: Bool, actors: [Actor]) {
    guard enabled else { reset(); return }
    if isRewinding && tick == lastTick { return }
    if rewindUntil > 0 { reset() }
    if let lastTick, tick < lastTick || tick - lastTick > 8 { reset() }
    if tick == lastTick {
      if actors.count == currentPositions.count,
        actors.allSatisfy({ currentPositions[$0.id]?.actor == $0 }) { return }
      // Skills can change a pose between ticks. Drop its old wake immediately.
      currentPositions = Dictionary(uniqueKeysWithValues: actors.map { actor in
        if let existing = currentPositions[actor.id], existing.actor == actor { return (actor.id, existing) }
        return (actor.id, MotionSample(actor: actor, steps: [], motion: .zero, direction: nil))
      })
      return
    }
    let elapsed = max(1, tick - (lastTick ?? tick))
    var samples: [Int: MotionSample] = [:]
    samples.reserveCapacity(actors.count)
    for actor in actors {
      var steps: [CGVector] = []
      var motion = CGVector.zero
      var direction: Int?
      if let previous = currentPositions[actor.id] {
        let delta = CGVector(dx: actor.position.x - previous.actor.position.x,
                             dy: actor.position.y - previous.actor.position.y)
        // A stop or teleport ends the wake. A turn starts a fresh direction.
        if delta != .zero && hypot(delta.dx, delta.dy) <= 64 {
          let last = previous.steps.last ?? .zero
          let reversal = delta.dx * last.dx < 0 || delta.dx * last.dx + delta.dy * last.dy <= 0
          if elapsed == 1 && actor.movement == previous.actor.movement && !reversal {
            steps = Array(previous.steps.suffix(2))
          }
          steps.append(CGVector(dx: delta.dx / CGFloat(elapsed), dy: delta.dy / CGFloat(elapsed)))
          // Three ticks soften pixel stair steps without delaying a reversal.
          motion = CGVector(dx: steps.reduce(0) { $0 + $1.dx } / CGFloat(steps.count),
                            dy: steps.reduce(0) { $0 + $1.dy } / CGFloat(steps.count))
          direction = Self.direction(for: motion, retaining: steps.count > 1 ? previous.direction : nil)
        }
      }
      samples[actor.id] = MotionSample(actor: actor, steps: steps, motion: motion, direction: direction)
    }
    currentPositions = samples
    lastTick = tick
  }

  private static func direction(for motion: CGVector, retaining previous: Int?) -> Int {
    let angle = atan2(motion.dy, motion.dx)
    if let previous {
      let difference = angle - CGFloat(previous) * .pi / 8
      let distance = abs(atan2(sin(difference), cos(difference)))
      // Five extra degrees prevent adjacent cached angles alternating on pixel steps.
      if distance <= .pi / 16 + .pi / 36 { return previous }
    }
    return (Int((angle * 8 / .pi).rounded()) + 16) % 16
  }

  func direction(actor: Int) -> Int? { currentPositions[actor]?.direction }

  func draw(enabled: Bool, in rect: CGRect, content: () -> Void) {
    occupiedCells = 0
    drawnTrailCount = 0
    guard enabled, rect.width > 0, rect.height > 0,
      let context = NSGraphicsContext.current?.cgContext else { content(); return }
    clip = rect
    drawingContext = context
    defer { drawingContext = nil }
    content()
  }

  /// Every render of a tick uses the same world-space direction.
  func motion(actor: Int) -> CGVector {
    currentPositions[actor]?.motion ?? .zero
  }

  func drawBehind(actor: Int, sprite: NSImage, in rect: CGRect, motion: CGVector,
    pixelSize: CGSize, mirrored: Bool = false) {
    guard let context = drawingContext, drawnTrailCount < MacFXPerformance.shared.presentation.trailLimit,
      rect.width > 0, rect.height > 0, rect.intersects(clip),
      pixelSize.width > 0, pixelSize.height > 0,
      motion.dx != 0 || motion.dy != 0 else { return }
    // Limit overlap in crowds and keep the extra sprite draws bounded.
    let column = min(15, max(0, Int((rect.midX - clip.minX) / clip.width * 16)))
    let row = min(3, max(0, Int((rect.midY - clip.minY) / clip.height * 4)))
    let cell = UInt64(1) << (row * 16 + column)
    guard occupiedCells & cell == 0 else { return }
    // Preserve AppKit's graphics state as well as Core Graphics state.
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    let cached: SpriteTrails
    if let existing = sprites.object(forKey: sprite) { cached = existing }
    else {
      guard let source = sprite.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
      cached = SpriteTrails(source: source)
      sprites.setObject(cached, forKey: sprite)
    }
    // Sixteen cached angles retain slopes without generating a texture for every velocity.
    let direction = currentPositions[actor]?.direction ?? Self.direction(for: motion, retaining: nil)
    let sharp = isRewinding
    let speed = sharp ? 3 : min(10, max(2, multiplier))
    let upper = Self.tiers.firstIndex(where: { $0 >= speed }) ?? 3
    let lower = max(0, upper - 1)
    let blend = upper == lower ? 1 : (speed - Self.tiers[lower]) / (Self.tiers[upper] - Self.tiers[lower])
    context.clip(to: clip)
    context.setBlendMode(.plusLighter)
    context.interpolationQuality = .none
    // Blend only the two neighbouring tiers. Stable speeds use one texture draw.
    for (tier, weight) in [(lower, 1 - blend), (upper, blend)] where weight > 0 {
      // Original and Macintosh artwork use one or two source pixels per level pixel.
      let key = TrailKey(direction: direction,
        pixelX: max(1, Int((pixelSize.width * CGFloat(cached.source.width) / rect.width).rounded())),
        pixelY: max(1, Int((pixelSize.height * CGFloat(cached.source.height) / rect.height).rounded())),
        tier: tier, echoes: MacFXPerformance.shared.presentation.trailEchoLimit, mirrored: mirrored, sharp: sharp)
      let trail: TrailImage
      if let existing = cached.images[key] { trail = existing }
      else {
        guard let image = Self.makeTrail(source: cached.source, key: key) else { continue }
        if cached.order.count == 96, let removed = cached.images.removeValue(forKey: cached.order.removeFirst()) {
          cached.byteCost -= removed.image.bytesPerRow * removed.image.height
        }
        cached.images[key] = image; cached.order.append(key)
        cached.byteCost += image.image.bytesPerRow * image.image.height
        sprites.setObject(cached, forKey: sprite, cost: cached.byteCost)
        trail = image
      }
      let scaleX = rect.width / CGFloat(cached.source.width)
      let scaleY = rect.height / CGFloat(cached.source.height)
      let tail = CGRect(x: rect.minX + (trail.bounds.minX - trail.origin.x) * scaleX,
        y: rect.minY + (trail.bounds.minY - trail.origin.y) * scaleY,
        width: trail.bounds.width * scaleX, height: trail.bounds.height * scaleY)
      context.saveGState()
      context.setAlpha(CGFloat(weight) * 0.85)
      context.translateBy(x: tail.minX, y: tail.maxY)
      context.scaleBy(x: 1, y: -1)
      context.draw(trail.image, in: CGRect(origin: .zero, size: tail.size))
      context.restoreGState()
    }
    occupiedCells |= cell
    drawnTrailCount += 1
  }

  /// Bake each speed tier at the sprite's artwork resolution on a cache miss.
  private static func makeTrail(source: CGImage, key: TrailKey) -> TrailImage? {
    let motion = key.motion
    let dx = motion.dx * CGFloat(key.pixelX), dy = motion.dy * CGFloat(key.pixelY)
    let distances = Array((key.sharp ? [CGFloat(3), 8, 14] : Self.distances[key.tier]).prefix(key.echoes))
    let reach = distances.last! + 2 + CGFloat(key.tier)
    let paddingX = CGFloat(key.pixelX) * 5, paddingY = CGFloat(key.pixelY) * 5
    let width = source.width + Int(ceil(abs(dx) * reach) + 2 * paddingX)
    let height = source.height + Int(ceil(abs(dy) * reach) + 2 * paddingY)
    guard let context = CGContext(data: nil, width: width, height: height,
      bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    context.setBlendMode(.plusLighter)
    context.interpolationQuality = key.sharp ? .none : .low
    let origin = CGPoint(x: ceil(max(0, dx) * reach) + paddingX, y: ceil(max(0, dy) * reach) + paddingY)
    func echo(distance: CGFloat, stretch: CGFloat, alpha: CGFloat, offset: CGPoint) {
      var rect = CGRect(x: origin.x - dx * distance - max(0, dx * stretch) + offset.x,
        y: origin.y - dy * distance - max(0, dy * stretch) + offset.y,
        width: CGFloat(source.width) + abs(dx * stretch),
        height: CGFloat(source.height) + abs(dy * stretch))
      if key.sharp { rect.origin.x = rect.origin.x.rounded(); rect.origin.y = rect.origin.y.rounded() }
      context.saveGState()
      context.setAlpha(alpha)
      if !key.sharp {
        context.setShadow(offset: .zero, blur: CGFloat(max(key.pixelX, key.pixelY)) * 0.7,
          color: CGColor(red: 0.1, green: 0.7, blue: 1, alpha: 0.65))
      }
      context.translateBy(x: key.mirrored ? rect.maxX : rect.minX, y: rect.maxY)
      context.scaleBy(x: key.mirrored ? -1 : 1, y: -1)
      context.draw(source, in: CGRect(origin: .zero, size: rect.size))
      context.restoreGState()
    }
    // A small two-dimensional kernel softens the distant echoes progressively.
    // Its weights preserve brightness while each higher tier adds fainter tails.
    let samples: [(CGFloat, CGFloat)] = [(-1, 0.25), (0, 0.5), (1, 0.25)]
    let farAlpha: CGFloat = [0.18, 0.13, 0.09, 0.055][key.tier]
    for (index, distance) in distances.enumerated().reversed() {
      let progress = CGFloat(index) / CGFloat(max(1, distances.count - 1))
      if key.sharp {
        echo(distance: distance, stretch: 0, alpha: [CGFloat(0.22), 0.12, 0.05][index], offset: .zero)
        continue
      }
      let blur = 0.25 + progress * (0.5 + CGFloat(key.tier) * 0.5)
      let alpha = 0.46 * pow(farAlpha / 0.46, progress)
      let stretch = 0.5 + progress * (1.5 + CGFloat(key.tier))
      for (x, xWeight) in samples { for (y, yWeight) in samples {
        echo(distance: distance, stretch: stretch, alpha: alpha * xWeight * yWeight,
          offset: CGPoint(x: x * blur * CGFloat(key.pixelX), y: y * blur * CGFloat(key.pixelY)))
      } }
    }
    // Remove transparent margins so additive blending touches fewer screen pixels.
    let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
    var left = width, top = height, right = -1, bottom = -1
    for y in 0..<height { for x in 0..<width where pixels[(y * width + x) * 4 + 3] != 0 {
      left = min(left, x); top = min(top, y)
      right = max(right, x); bottom = max(bottom, y)
    } }
    guard right >= left, bottom >= top else { return nil }
    let bounds = CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
    guard let image = context.makeImage()?.cropping(to: bounds) else { return nil }
    return TrailImage(image: image, bounds: bounds, origin: origin)
  }
}

/// A compact pixel face for installations without the Macintosh menu artwork.
@MainActor enum GamePixelText {
  static func draw(_ text: String, in rect: CGRect, maxScale: CGFloat = 3,
                   highlighted: Character? = nil, palette: MacInterfaceRenderer.Palette = .blue,
                   preservesCase: Bool = false, color: NSColor? = nil,
                   numberPalette: MacInterfaceRenderer.Palette? = nil) {
    let source = text.replacingOccurrences(of: "×", with: "X")
    let normalized = preservesCase ? source.precomposedStringWithCanonicalMapping : BitmapLatinGlyphs.uppercase(source, locale: L10n.interface.locale)
    let bounds = GamePixelTypography.verticalBounds(of: normalized)
    let height = CGFloat(bounds.bottom - bounds.top)
    let horizontal = GamePixelTypography.horizontalBounds(of: normalized)
    let width = max(1, horizontal.right - horizontal.left)
    let scale = max(1, min(maxScale, floor(min(rect.height / height, rect.width / CGFloat(width + 1)))))
    let start = floor(rect.midX - CGFloat(width) * scale / 2) - CGFloat(horizontal.left) * scale
    let top = floor(rect.midY - height * scale / 2) - CGFloat(bounds.top) * scale
    let context = NSGraphicsContext.current?.cgContext
    context?.saveGState()
    context?.setShouldAntialias(false)
    context?.clip(to: rect)
    defer { context?.restoreGState() }
    (color ?? (palette == .monochrome ? .white : palette == .green ? NSColor(calibratedRed: 0.45, green: 1, blue: 0.1, alpha: 1)
      : NSColor(calibratedRed: 0.2, green: 0.5, blue: 1, alpha: 1))).setFill()
    let layout = GamePixelTypography.layout(normalized)
    let highlightedIndex = highlighted.flatMap { character in layout.firstIndex { $0.sequence.contains(character) } }
    for (index, item) in layout.enumerated() {
      if let numberPalette {
        let ink = item.sequence.allSatisfy { $0.isNumber || $0 == "," } ? numberPalette : palette
        (ink == .green ? NSColor(calibratedRed: 0.45, green: 1, blue: 0.1, alpha: 1)
          : ink == .monochrome ? .white : NSColor(calibratedRed: 0.2, green: 0.5, blue: 1, alpha: 1)).setFill()
      }
      if highlighted != nil && palette != .monochrome {
        (index == highlightedIndex
          ? NSColor(calibratedRed: 0.45, green: 1, blue: 0.1, alpha: 1)
          : NSColor(calibratedRed: 0.2, green: 0.5, blue: 1, alpha: 1)).setFill()
      }
      guard let glyph = item.glyph, let mask = GamePixelTypography.monochromeMask(forSequence: item.sequence) else { continue }
      for x in 0..<glyph.width {
        for y in 0..<glyph.height where mask[y * glyph.width + x] != 0 {
          CGRect(x: start + CGFloat(item.x + glyph.x + x) * scale,
            y: top + CGFloat(glyph.y + y) * scale, width: scale, height: scale).fill()
        }
      }
    }
    if palette == .monochrome, let highlightedIndex {
      let item = layout[highlightedIndex]
      NSColor.white.setFill()
      CGRect(x: start + CGFloat(item.x) * scale,
        y: min(rect.maxY - 1, top + height * scale + 1), width: CGFloat(max(1, item.advance - 1)) * scale, height: 1).fill()
    }
  }
}

struct PrecisionZoomStatus: Equatable {
  var superzoom = 0
  var skips = 0
  var extraSkills = 0
  var bonusSkillUsed = false
  var active: PrecisionZoomKind?
  var isEmpty = true

  init(superzoom: Int = 0, skips: Int = 0, extraSkills: Int = 0, bonusSkillUsed: Bool = false, active: PrecisionZoomKind? = nil,
       isEmpty: Bool = true) {
    self.superzoom = superzoom
    self.skips = skips
    self.extraSkills = extraSkills
    self.bonusSkillUsed = bonusSkillUsed
    self.active = active
    self.isEmpty = isEmpty
  }

  var accessibility: String {
    guard !isEmpty else { return "" }
    let state = active.map { $0 == .zoom ? L10n.text("Zoom active") : L10n.text("Superzoom active") } ?? L10n.text("Zoom off")
    return L10n.text("Superzoom, \(superzoom) remaining. \(skips) Level Skips. \(extraSkills) Bonus skills. \(state)")
      + (bonusSkillUsed ? ". " + L10n.text("Bonus skill used") : "")
  }

  enum Badge: String, CaseIterable {
    case superzoom, skips, bonusSkill

    var glyph: PanelGlyph {
      switch self {
      case .superzoom: return .superzoom
      case .skips: return .levelSkip
      case .bonusSkill: return .bonusSkill
      }
    }
    var title: String {
      switch self {
      case .superzoom: return L10n.text("Superzoom")
      case .skips: return L10n.text("Level Skips")
      case .bonusSkill: return L10n.text("Bonus skill")
      }
    }
  }

  func count(for badge: Badge) -> Int {
    switch badge {
    case .superzoom: return superzoom
    case .skips: return skips
    case .bonusSkill: return extraSkills
    }
  }

  func help(for badge: Badge, bonusSkillHelp: String) -> String {
    var lines = [L10n.text("\(count(for: badge)) remaining")]
    switch badge {
    case .superzoom:
      if active == .superzoom { lines.append(L10n.text("Superzoom active")) }
      lines += [L10n.text("2× Superzoom at cursor, 0.5× time"),
        L10n.text("Each start spends one Superzoom use") + " (Shift-Z)"]
    case .skips:
      lines.append(L10n.text("Spend one Level Skip in the journey menu to move past a level."))
    case .bonusSkill:
      if bonusSkillUsed { lines.append(L10n.text("Bonus skill used")) }
      lines.append(bonusSkillHelp)
    }
    return lines.filter { !$0.isEmpty }.joined(separator: "\n")
  }

  /// Drawing and hover help use the same counter bounds.
  func badgeFrames(scale: CGFloat = 1) -> [(badge: Badge, frame: CGRect)] {
    guard !isEmpty else { return [] }
    let scale = max(1, floor(scale))
    var x: CGFloat = 0
    return Badge.allCases.map { badge in
      let width = CGFloat(max(56, 36 + GamePixelTypography.width(of: String(count(for: badge))) * 2)) * scale
      let frame = CGRect(x: x, y: 0, width: width, height: 32 * scale)
      x = frame.maxX + 4 * scale
      return (badge, frame)
    }
  }

  func size(scale: CGFloat = 1) -> CGSize {
    guard let last = badgeFrames(scale: scale).last else { return .zero }
    return CGSize(width: last.frame.maxX, height: last.frame.height)
  }

  /// The owner converts the full badge row, including CRT projection, to its root view.
  func badge(at point: CGPoint, in area: CGRect) -> (badge: Badge, frame: CGRect)? {
    let size = size()
    guard area.contains(point), size.width > 0 else { return nil }
    return badgeFrames().compactMap { item in
      let frame = CGRect(x: area.minX + item.frame.minX / size.width * area.width,
        y: area.minY, width: item.frame.width / size.width * area.width, height: area.height)
      return frame.contains(point) ? (item.badge, frame) : nil
    }.first
  }

  @MainActor @discardableResult
  func draw(at origin: CGPoint, scale: CGFloat = 1, opacity: CGFloat = 1) -> CGSize {
    let scale = max(1, floor(scale)), badgeSize = size(scale: scale)
    guard !isEmpty, opacity > 0, let context = NSGraphicsContext.current?.cgContext else { return badgeSize }
    context.saveGState()
    context.setAlpha(opacity)
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    defer { context.endTransparencyLayer(); context.restoreGState() }
    for item in badgeFrames(scale: scale) {
      let rect = item.frame.offsetBy(dx: origin.x, dy: origin.y)
      let selected = item.badge == .superzoom ? active == .superzoom : item.badge == .bonusSkill && bonusSkillUsed
      context.setFillColor(CGColor(gray: 0, alpha: 0.75))
      context.fill(rect)
      if selected {
        context.setFillColor(CGColor(srgbRed: 0.6755, green: 0.8639, blue: 0.2804, alpha: 1))
        context.fill(CGRect(x: rect.minX + 2 * scale, y: rect.midY - 4 * scale, width: 2 * scale, height: 8 * scale))
      }
      let iconBox = CGRect(x: rect.minX + 6 * scale, y: rect.minY + 8 * scale, width: 16 * scale, height: 16 * scale)
      if let image = item.badge.glyph.image(fitting: iconBox.size) {
        image.draw(in: CGRect(x: floor(iconBox.midX - image.size.width / 2), y: floor(iconBox.midY - image.size.height / 2),
          width: image.size.width, height: image.size.height), from: .zero, operation: .sourceOver,
          fraction: count(for: item.badge) > 0 || selected ? 1 : 0.45, respectFlipped: true,
          hints: [.interpolation: NSImageInterpolation.none.rawValue])
      }
      GamePixelText.draw(String(count(for: item.badge)),
        in: CGRect(x: rect.minX + 28 * scale, y: rect.minY + 6 * scale,
          width: rect.width - 34 * scale, height: 20 * scale), maxScale: 2 * scale,
        palette: selected ? .green : .blue)
    }
    return badgeSize
  }

}

/// A non-interactive identity badge. The owner supplies the active attempt's player.
@MainActor final class TurnBadgeView: NSView {
    private(set) var initials: String?
    private var portrait: NSImage?
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    init() {
        super.init(frame: .zero)
        isHidden = true
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    func show(initials: String?, portrait: NSImage?) {
        guard self.initials != initials || self.portrait !== portrait else { return }
        self.initials = initials; self.portrait = portrait
        isHidden = initials == nil
        setAccessibilityLabel(initials.map { L10n.text("\($0)'s turn") })
        needsDisplay = true
        NSAccessibility.post(element: self, notification: .valueChanged)
    }
    func place(in area: CGRect) {
        let width = min(area.width, 132)
        frame = CGRect(x: area.maxX - width - 10, y: area.maxY - 42, width: width, height: 32)
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let initials else { return }
        NSColor.black.withAlphaComponent(0.8).setFill()
        bounds.fill()
        if let portrait {
            let width = min(28, portrait.size.width / portrait.size.height * 28)
            portrait.draw(in: CGRect(x: 4, y: 2, width: width, height: 28), from: .zero,
                operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
        }
        GamePixelText.draw(initials, in: CGRect(x: portrait == nil ? 4 : 36, y: 4,
            width: bounds.width - (portrait == nil ? 8 : 40), height: 24), palette: .green)
    }
}

@MainActor enum GameAccessibility {
    static var interfaceSize: ClassicInterfaceSize = .standard
    static var scale: CGFloat { CGFloat(interfaceSize.scale) }
}

/// Stable accessibility objects for controls drawn directly into a game view.
@MainActor final class GameAccessibleElement: NSAccessibilityElement, @unchecked Sendable {
    @MainActor private final class State {
        weak var owner: NSView?
        var localFrame = CGRect.zero
        var press: (() -> Void)?
        var onFocus: (() -> Void)?
        var readNumber: (() -> Double)?
        var adjustValue: ((Double) -> Void)?
        var readValue: (() -> String)?
        var writeValue: ((String) -> Void)?
    }
    private nonisolated let state: State
    var owner: NSView? { get { state.owner } set { state.owner = newValue } }
    var localFrame: CGRect { get { state.localFrame } set { state.localFrame = newValue } }
    var press: (() -> Void)? { get { state.press } set { state.press = newValue } }
    var onFocus: (() -> Void)? { get { state.onFocus } set { state.onFocus = newValue } }
    var readNumber: (() -> Double)? { get { state.readNumber } set { state.readNumber = newValue } }
    var adjustValue: ((Double) -> Void)? { get { state.adjustValue } set { state.adjustValue = newValue } }
    var readValue: (() -> String)? { get { state.readValue } set { state.readValue = newValue } }
    var writeValue: ((String) -> Void)? { get { state.writeValue } set { state.writeValue = newValue } }
    init(owner: NSView, label: String, frame: CGRect, press: (() -> Void)? = nil) {
        state = State()
        super.init()
        self.owner = owner; self.localFrame = frame; self.press = press
        setAccessibilityParent(owner)
        setAccessibilityEnabled(true)
        setAccessibilityRole(press == nil ? .staticText : .button)
        setAccessibilityLabel(label)
    }
    // AppKit accessibility overrides are nonisolated. All game-view state stays on the main actor.
    nonisolated private func onMain<T: Sendable>(_ operation: @MainActor @Sendable () -> T) -> T {
        if Thread.isMainThread { return MainActor.assumeIsolated(operation) }
        return DispatchQueue.main.sync { MainActor.assumeIsolated(operation) }
    }
    override func accessibilityFrame() -> NSRect {
        onMain { [state] in
            guard let owner = state.owner, let window = owner.window else { return .zero }
            return window.convertToScreen(owner.convert(state.localFrame, to: nil))
        }
    }
    override func accessibilityPerformPress() -> Bool {
        guard isAccessibilityEnabled() else { return false }
        return onMain { [state] in
            guard let owner = state.owner, owner.window != nil, !owner.isHiddenOrHasHiddenAncestor,
                let press = state.press else { return false }
            owner.scrollToVisible(state.localFrame)
            press()
            return true
        }
    }
    override func accessibilityValue() -> Any? {
        if let value = onMain({ [state] in state.readNumber?() }) { return value }
        let value: String? = onMain { [state] in state.readValue?() }
        return value ?? super.accessibilityValue()
    }
    override func setAccessibilityValue(_ value: Any?) {
        if let text = (value as? String) ?? (value as? NSNumber)?.stringValue, onMain({ [state] in
            guard let write = state.writeValue else { return false }
            write(text)
            return true
        }) { return }
        super.setAccessibilityValue(value)
    }
    override func accessibilityPerformIncrement() -> Bool {
        onMain { [state] in guard let adjust = state.adjustValue else { return false }; adjust(1); return true }
    }
    override func accessibilityPerformDecrement() -> Bool {
        onMain { [state] in guard let adjust = state.adjustValue else { return false }; adjust(-1); return true }
    }
    override func setAccessibilityFocused(_ focused: Bool) {
        super.setAccessibilityFocused(focused)
        guard focused else { return }
        onMain { [state] in
            guard let owner = state.owner, owner.window != nil, !owner.isHiddenOrHasHiddenAncestor else { return }
            owner.scrollToVisible(state.localFrame)
            state.onFocus?()
        }
    }

}

@MainActor final class GameAccessibleElements {
    private var elements: [String: GameAccessibleElement] = [:]
    func element(id: String, owner: NSView, label: String, frame: CGRect, press: (() -> Void)? = nil) -> GameAccessibleElement {
        let element = elements[id] ?? GameAccessibleElement(owner: owner, label: label, frame: frame, press: press)
        element.owner = owner; element.localFrame = frame; element.press = press
        element.setAccessibilityParent(owner); element.setAccessibilityLabel(label)
        element.setAccessibilityRole(press == nil ? .staticText : .button)
        elements[id] = element
        return element
    }
}

/// A fresh level starts after three visible seconds. Explicit pause cancels it.
@MainActor final class FreshLevelCountdown {
    private var countdown = GameplayStartCountdown()
    var remaining: Double? { countdown.remaining }
    var isActive: Bool { countdown.isActive }
    var number: Int? { countdown.number }
    func arm() { countdown.arm() }
    func cancel() { countdown.cancel() }
    @discardableResult func advance(seconds: Double, visible: Bool) -> Bool {
        countdown.advance(seconds: seconds, visible: visible)
    }
    func draw(in bounds: CGRect) {
        guard let number else { return }
        let rect = CGRect(x: floor(bounds.midX - 24), y: floor(bounds.midY - 28), width: 48, height: 56)
        NSColor.black.withAlphaComponent(0.75).setFill()
        rect.insetBy(dx: -8, dy: -8).fill()
        GamePixelText.draw(String(number), in: rect, maxScale: 6, palette: .green)
    }
}
#endif
