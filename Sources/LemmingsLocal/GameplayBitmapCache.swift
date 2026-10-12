#if os(macOS)
import AppKit

/// Reuse decoded bitmap pixels for the native sequel artwork.
@MainActor final class GameplayBitmapCache {
    private final class Pixels {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }
    private let cache = NSCache<NSImage, Pixels>()

    init() {
        cache.countLimit = 384
        cache.totalCostLimit = 16 * 1024 * 1024
    }

    func pixels(_ image: NSImage) -> CGImage? {
        if let pixels = cache.object(forKey: image) { return pixels.image }
        guard let pixels = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        cache.setObject(Pixels(pixels), forKey: image, cost: pixels.bytesPerRow * pixels.height)
        return pixels
    }

    func draw(_ image: NSImage, in rect: CGRect, mirrored: Bool = false) {
        guard let context = NSGraphicsContext.current?.cgContext,
              rect.intersects(context.boundingBoxOfClipPath), let pixels = pixels(image) else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.interpolationQuality = .none
        context.translateBy(x: mirrored ? rect.maxX : rect.minX, y: rect.maxY)
        context.scaleBy(x: mirrored ? -1 : 1, y: -1)
        context.draw(pixels, in: CGRect(origin: .zero, size: rect.size))
    }
}
#endif
