#if canImport(CoreGraphics)
import CoreGraphics
import Foundation

/// Reuses source pixels for CRT composition without an intermediate image conversion.
public final class MobileBitmapSurface {
    public private(set) var context: CGContext?

    public init() {}

    public func prepare(width: Int, height: Int) -> CGContext? {
        guard width > 0, height > 0 else { return nil }
        if context?.width != width || context?.height != height {
            context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        }
        guard let context else { return nil }
        // Retained storage must not retain pixels outside the current camera clip.
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        return context
    }
}

/// Presents the engine's RGBA pixels with the same camera used for touch input.
public enum MobileBitmapRenderer {
    public static func image(_ frame: MobilePixelFrame) -> CGImage? {
        guard let provider = CGDataProvider(data: frame.rgba as CFData) else { return nil }
        return CGImage(
            width: frame.width, height: frame.height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: frame.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    /// The context uses view coordinates, with its origin at the top left.
    public static func draw(_ image: CGImage, viewport: MobileViewport, in context: CGContext) {
        let content = viewport.contentFrame
        guard content.width > 0, content.height > 0 else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.interpolationQuality = .none
        context.setShouldAntialias(false)
        context.clip(to: CGRect(x: content.x, y: content.y, width: content.width, height: content.height))
        // Draw the full image under the camera clip. Fractional pan keeps its pixel alignment.
        let scaleX = viewport.zoom * viewport.pixelAspect
        let scaleY = viewport.zoom
        let x = content.x - viewport.origin.x * scaleX
        let y = content.y - viewport.origin.y * scaleY
        let width = viewport.levelSize.width * scaleX
        let height = viewport.levelSize.height * scaleY
        context.translateBy(x: x, y: y + height)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
}
#endif
