import AppKit
import NxlvKit

/// Energy wakes and afterimages follow moving actors. Solid sprites stay sharp.
@MainActor final class SpeedTrails {
  static let maximumTrails = 24
  var multiplier: Double = 3
  private struct TrailKey: Hashable {
    let direction: Int, pixelX: Int, pixelY: Int
    let mirrored: Bool
    var motion: CGVector {
      let angle = CGFloat(direction) * .pi / 8
      let dx = cos(angle), dy = sin(angle)
      return CGVector(dx: abs(dx) < 0.0001 ? 0 : dx, dy: abs(dy) < 0.0001 ? 0 : dy)
    }
  }
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
    init(source: CGImage) { self.source = source }
  }
  private let sprites = NSCache<NSImage, SpriteTrails>()
  private var drawingContext: CGContext?
  private var clip = CGRect.zero
  private var occupiedCells: UInt64 = 0
  private var lastTick: Int?
  private var currentPositions: [Int: MotionSample] = [:]
  private(set) var drawnTrailCount = 0

  init() { sprites.countLimit = 128 }

  func reset() {
    drawingContext = nil
    occupiedCells = 0
    drawnTrailCount = 0
    lastTick = nil
    currentPositions.removeAll(keepingCapacity: true)
  }

  /// Sample once per game tick, independently of live redraws and movie capture.
  func update(tick: Int, enabled: Bool, actors: [Actor]) {
    guard enabled else { reset(); return }
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
    guard let context = drawingContext, drawnTrailCount < Self.maximumTrails,
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
    // Original and Macintosh artwork use one or two source pixels per level pixel.
    let key = TrailKey(direction: direction,
      pixelX: max(1, Int((pixelSize.width * CGFloat(cached.source.width) / rect.width).rounded())),
      pixelY: max(1, Int((pixelSize.height * CGFloat(cached.source.height) / rect.height).rounded())),
      mirrored: mirrored)
    let trail: TrailImage
    if let existing = cached.images[key] { trail = existing }
    else {
      guard let image = Self.makeTrail(source: cached.source, key: key) else { return }
      cached.images[key] = image
      trail = image
    }
    occupiedCells |= cell
    drawnTrailCount += 1
    let scaleX = rect.width / CGFloat(cached.source.width)
    let scaleY = rect.height / CGFloat(cached.source.height)
    let tail = CGRect(x: rect.minX + (trail.bounds.minX - trail.origin.x) * scaleX,
      y: rect.minY + (trail.bounds.minY - trail.origin.y) * scaleY,
      width: trail.bounds.width * scaleX, height: trail.bounds.height * scaleY)
    context.clip(to: clip)
    context.setBlendMode(.plusLighter)
    context.setAlpha(0.7 * CGFloat(min(1.3, sqrt(max(0, multiplier - 1) / 2))))
    context.interpolationQuality = .none
    context.translateBy(x: tail.minX, y: tail.maxY)
    context.scaleBy(x: 1, y: -1)
    context.draw(trail.image, in: CGRect(origin: .zero, size: tail.size))
  }

  /// Bake the energy wake and three echoes into one texture per pose and direction.
  /// This runs only on a cache miss, at the sprite's own artwork resolution.
  private static func makeTrail(source: CGImage, key: TrailKey) -> TrailImage? {
    // Leave room for the longer wake and its soft electrical glow.
    let motion = key.motion
    let dx = motion.dx * CGFloat(key.pixelX), dy = motion.dy * CGFloat(key.pixelY)
    let paddingX = CGFloat(key.pixelX)*2, paddingY = CGFloat(key.pixelY)*2
    let width = source.width + Int(ceil(abs(dx) * 18) + 2 * paddingX)
    let height = source.height + Int(ceil(abs(dy) * 18) + 2 * paddingY)
    guard let context = CGContext(data: nil, width: width, height: height,
      bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    context.setBlendMode(.plusLighter)
    context.interpolationQuality = .low
    let origin = CGPoint(x: ceil(max(0, dx) * 18) + paddingX, y: ceil(max(0, dy) * 18) + paddingY)
    let centre = CGPoint(x:origin.x+CGFloat(source.width)/2,y:origin.y+CGFloat(source.height)/2)
    let nx = -motion.dy*CGFloat(key.pixelX), ny = motion.dx*CGFloat(key.pixelY)
    func point(_ distance: CGFloat, _ across: CGFloat = 0) -> CGPoint {
      CGPoint(x:centre.x-dx*distance+nx*across,y:centre.y-dy*distance+ny*across)
    }
    let ribbon = CGMutablePath()
    ribbon.move(to:point(1,0.4))
    ribbon.addQuadCurve(to:point(18),control:point(9,2))
    ribbon.addQuadCurve(to:point(1,-0.4),control:point(9,-2))
    ribbon.closeSubpath()
    context.saveGState()
    context.addPath(ribbon); context.clip()
    let colours = [CGColor(red:0.02,green:0.3,blue:1,alpha:0),
      CGColor(red:0.03,green:0.6,blue:1,alpha:0.32),
      CGColor(red:0.55,green:1,blue:1,alpha:0.64)]
    if let gradient = CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colours as CFArray,locations:[0,0.6,1]) {
      context.drawLinearGradient(gradient,start:point(18),end:point(1),options:[])
    }
    context.restoreGState()
    // The amber filament gives the wake a sharp core beneath its cyan glow.
    context.saveGState()
    let bolt = CGMutablePath()
    bolt.move(to:point(16))
    for (distance, offset): (CGFloat,CGFloat) in [(12,-0.35),(10,0.5),(8,-0.5),(5,0.3),(2,0)] {
      bolt.addLine(to:point(distance,offset))
    }
    context.addPath(bolt)
    context.setLineWidth(CGFloat(min(key.pixelX,key.pixelY))*0.75)
    context.setLineCap(.round); context.setLineJoin(.round)
    context.setStrokeColor(CGColor(red:1,green:0.8,blue:0.22,alpha:0.78))
    context.setShadow(offset:.zero,blur:CGFloat(max(key.pixelX,key.pixelY)),
      color:CGColor(red:0.15,green:0.65,blue:1,alpha:0.65))
    context.strokePath()
    context.restoreGState()
    func echo(distance: CGFloat, stretch: CGFloat, alpha: CGFloat) {
      let rect = CGRect(x: origin.x - dx * distance - max(0, dx * stretch),
        y: origin.y - dy * distance - max(0, dy * stretch),
        width: CGFloat(source.width) + abs(dx * stretch),
        height: CGFloat(source.height) + abs(dy * stretch))
      context.saveGState()
      context.setAlpha(alpha)
      context.setShadow(offset:.zero,blur:CGFloat(max(key.pixelX,key.pixelY))*0.7,
        color:CGColor(red:0.1,green:0.7,blue:1,alpha:0.65))
      context.translateBy(x: key.mirrored ? rect.maxX : rect.minX, y: rect.maxY)
      context.scaleBy(x: key.mirrored ? -1 : 1, y: -1)
      context.draw(source, in: CGRect(origin: .zero, size: rect.size))
      context.restoreGState()
    }
    // A half-pixel directional blur softens only the ghosts. The weights keep
    // their total brightness unchanged, and this work runs only on a cache miss.
    let samples: [(CGFloat, CGFloat)] = [(-1, 0.0625), (-0.5, 0.25), (0, 0.375), (0.5, 0.25), (1, 0.0625)]
    for (offset, weight) in samples {
      echo(distance: 12 + offset, stretch: 3, alpha: 0.035 * weight)
      echo(distance: 7 + offset, stretch: 2, alpha: 0.075 * weight)
      echo(distance: 3 + offset, stretch: 1, alpha: 0.16 * weight)
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
  private static let columns: [Character: [UInt8]] = [
    "A":[126,9,9,9,126], "B":[127,73,73,73,54], "C":[62,65,65,65,34],
    "D":[127,65,65,34,28], "E":[127,73,73,73,65], "F":[127,9,9,9,1],
    "G":[62,65,73,73,122], "H":[127,8,8,8,127], "I":[0,65,127,65,0],
    "J":[32,64,65,63,1], "K":[127,8,20,34,65], "L":[127,64,64,64,64],
    "M":[127,2,12,2,127], "N":[127,4,8,16,127], "O":[62,65,65,65,62],
    "P":[127,9,9,9,6], "Q":[62,65,81,33,94], "R":[127,9,25,41,70],
    "S":[70,73,73,73,49], "T":[1,1,127,1,1], "U":[63,64,64,64,63],
    "V":[31,32,64,32,31], "W":[63,64,56,64,63], "X":[99,20,8,20,99],
    "Y":[3,4,120,4,3], "Z":[97,81,73,69,67],
    "0":[62,81,73,69,62], "1":[0,66,127,64,0], "2":[98,81,73,73,70],
    "3":[34,65,73,73,54], "4":[24,20,18,127,16], "5":[39,69,69,69,57],
    "6":[60,74,73,73,48], "7":[1,113,9,5,3], "8":[54,73,73,73,54],
    "9":[6,73,73,41,30], ":":[0,54,54,0,0], ".":[0,96,96,0,0],
    "-" :[8,8,8,8,8], "+":[8,8,62,8,8], "/":[32,16,8,4,2],
    "*" :[20,8,62,8,20], "%":[99,19,8,100,99], "(" :[0,28,34,65,0],
    ")":[0,65,34,28,0], "'" :[0,3,0,0,0], "!" :[0,0,95,0,0],
    ",":[0,64,48,0,0], "<":[8,20,34,65,0], ">":[0,65,34,20,8],
    "∞" :[28,34,28,34,28], "?" :[2,1,81,9,6], "=" :[20,20,20,20,20]]
  static func draw(_ text: String, in rect: CGRect) {
    let normalized = text.uppercased().replacingOccurrences(of: "×", with: "X")
    let scale = max(1, min(3, floor(min(rect.height / 7, rect.width / CGFloat(max(1, normalized.count * 6))))))
    let start = floor(rect.midX - CGFloat(normalized.count * 6 - 1) * scale / 2)
    let top = floor(rect.midY - 3.5 * scale)
    let context = NSGraphicsContext.current?.cgContext
    context?.saveGState()
    context?.setShouldAntialias(false)
    defer { context?.restoreGState() }
    NSColor(calibratedRed: 0.75, green: 0.94, blue: 0.62, alpha: 1).setFill()
    for (index, character) in normalized.enumerated() {
      for (x, column) in (columns[character] ?? []).enumerated() {
        for y in 0..<7 where column & (1 << y) != 0 {
          CGRect(x: start + CGFloat(index * 6 + x) * scale,
            y: top + CGFloat(y) * scale, width: scale, height: scale).fill()
        }
      }
    }
  }
}
