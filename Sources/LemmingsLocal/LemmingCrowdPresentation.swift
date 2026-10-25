#if os(macOS)
import AppKit
import LemmingsGameArt

/// Separates overlapping silhouettes without moving their feet or changing physics.
@MainActor final class LemmingCrowdPresentation {
    @MainActor private final class Mask {
        let source: CGImage
        let bytes: [UInt8]
        let stride: Int
        let path: CGPath
        init?(sprite: NSImage) {
            guard let source = sprite.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  let mask = LemmingSelectionRenderer.mask(source) else { return nil }
            self.source = source; bytes = mask.bytes; stride = mask.width
            let path = CGMutablePath()
            let padding = LemmingSelectionRenderer.padding
            for y in 0..<source.height {
                var x = 0
                while x < source.width {
                    if bytes[((y + padding) * stride + x + padding) * 2] < 128 { x += 1; continue }
                    let start = x
                    repeat { x += 1 } while x < source.width && bytes[((y + padding) * stride + x + padding) * 2] >= 128
                    path.addRect(CGRect(x: start, y: y, width: x - start, height: 1))
                }
            }
            self.path = path
        }
        func contains(_ point: CGPoint, in rect: CGRect, mirrored: Bool) -> Bool {
            guard rect.contains(point) else { return false }
            var x = Int((point.x - rect.minX) / rect.width * CGFloat(source.width))
            let y = Int((point.y - rect.minY) / rect.height * CGFloat(source.height))
            if mirrored { x = source.width - 1 - x }
            let padding = LemmingSelectionRenderer.padding
            return bytes[((y + padding) * stride + x + padding) * 2] >= 128
        }
    }
    private struct Actor {
        let id: Int, mask: Mask
        let rect: CGRect
        let mirrored: Bool
    }
    private let masks = NSCache<NSImage, Mask>()
    private var actors: [Actor] = []
    private var presented: [Actor] = []
    private var presentedTick = -1
    private var tick = -1
    private var strength: CGFloat = 0
    init() { masks.countLimit = 128 }

    func begin(tick: Int, zoom: CGFloat, enabled: Bool) {
        self.tick = tick
        let amount = enabled ? min(1, max(0, (zoom - 2) / 2)) : 0
        strength = amount * amount * (3 - 2 * amount)
        actors.removeAll(keepingCapacity: true)
    }

    func finish() { presented = actors; presentedTick = tick }
    func reset() { actors.removeAll(); presented.removeAll(); presentedTick = -1; tick = -1 }

    /// Records the same native mask used for drawing, in level coordinates.
    func drawBehind(_ sprite: NSImage, id: Int, rect: CGRect, worldRect: CGRect,
                    mirrored: Bool = false) {
        guard strength > 0, rect.width > 0, rect.height > 0 else { return }
        let mask: Mask
        if let cached = masks.object(forKey: sprite) { mask = cached }
        else {
            guard let made = Mask(sprite: sprite) else { return }
            masks.setObject(made, forKey: sprite); mask = made
        }
        let overlaps = actors.contains { $0.rect.intersects(worldRect) }
        actors.append(Actor(id: id, mask: mask, rect: worldRect, mirrored: mirrored))
        guard overlaps, let context = NSGraphicsContext.current?.cgContext else { return }
        var transform = CGAffineTransform(translationX: mirrored ? rect.maxX : rect.minX, y: rect.minY)
        transform = transform.scaledBy(x: rect.width / CGFloat(mask.source.width) * (mirrored ? -1 : 1),
                                      y: rect.height / CGFloat(mask.source.height))
        guard let path = mask.path.copy(using: &transform) else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        // The solid sprite covers the inner half of this one-output-pixel rim.
        let pixel = context.convertToDeviceSpace(CGSize(width: 1, height: 0))
        context.setLineWidth(2 / max(1, hypot(pixel.width, pixel.height)))
        context.setLineJoin(.miter)
        context.setStrokeColor(CGColor(srgbRed: 0.025, green: 0.035, blue: 0.07, alpha: strength * 0.85))
        context.addPath(path)
        context.strokePath()
    }

    /// Frontmost ink wins. Transparent margins never hide a visible neighbour.
    func target(at point: CGPoint, tick: Int, enabled: Bool) -> Int? {
        guard enabled, (presentedTick...presentedTick + 1).contains(tick), strength > 0 else { return nil }
        return presented.reversed().first { $0.mask.contains(point, in: $0.rect, mirrored: $0.mirrored) }?.id
    }
}
#endif
