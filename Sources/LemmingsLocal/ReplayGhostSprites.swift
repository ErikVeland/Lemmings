#if os(macOS)
import AppKit
import LemmingsAppCore
import NxlvKit

@MainActor protocol HotSeatGhostRendering: AnyObject {
    var hotSeatGhosts: HotSeatGhostPlayback? { get set }
}

extension HotSeatGhostRendering {
    func visibleHotSeatFrames(at tick: Int) -> [HotSeatGhostPlayback.Frame] {
        guard ArcadeStore.shared.hotSeatGhostsVisible else { return [] }
        return hotSeatGhosts?.frames(at: tick) ?? []
    }
}

/// Reuses the shipped sprite silhouette without labels, effects or input targets.
@MainActor final class ReplayGhostSprites {
    private var cache: [String: CGImage] = [:]
    func clear() { cache.removeAll(keepingCapacity: true) }
    func draw(_ sprite: NSImage, key: String, colour: ReplayGhostColour, in rect: CGRect,
              pixelScale: Int = 1, mirrored: Bool = false) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let scale = max(1, pixelScale)
        let cacheKey = "\(key)|\(colour.rawValue)|\(scale)"
        if cache[cacheKey] == nil {
            guard let image = sprite.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  let buffer = CGContext(data: nil, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let bytes = buffer.data else { return }
            buffer.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            let frame = SolutionGhostPixels(rgba: Data(bytes: bytes, count: image.width * image.height * 4),
                width: image.width, height: image.height, pixelScale: scale, colour: colour)
            guard let provider = CGDataProvider(data: frame.rgba as CFData),
                  let ghost = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32,
                    bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                    decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return }
            if cache.count >= 1024 { cache.removeAll(keepingCapacity: true) }
            cache[cacheKey] = ghost
        }
        guard let image = cache[cacheKey] else { return }
        let dx = rect.width * CGFloat(scale) / CGFloat(image.width - 2 * scale)
        let dy = rect.height * CGFloat(scale) / CGFloat(image.height - 2 * scale)
        let padded = rect.insetBy(dx: -dx, dy: -dy)
        context.saveGState()
        context.interpolationQuality = .none
        context.translateBy(x: mirrored ? padded.maxX : padded.minX, y: padded.maxY)
        context.scaleBy(x: mirrored ? -1 : 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: padded.size))
        context.restoreGState()
    }
}
#endif
