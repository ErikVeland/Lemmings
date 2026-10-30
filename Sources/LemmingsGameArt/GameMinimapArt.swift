import CoreGraphics
import Foundation

/// The Mac panel's map with its current camera window. Coordinates start at the top left.
public enum GameMinimapArt {
    /// Match the joined HUD outline while retaining the map's full input target.
    public static func drawingFrame(in bounds: CGRect, displayBounds: CGRect?) -> CGRect {
        guard let displayBounds else { return bounds }
        let left: CGFloat = abs(bounds.minX - displayBounds.minX) < 0.01 ? 2 : 0
        let right: CGFloat = abs(bounds.maxX - displayBounds.maxX) < 0.01 ? 2 : 0
        return CGRect(x: bounds.minX + left, y: bounds.minY, width: bounds.width - left - right, height: bounds.height)
    }

    public static func content(in bounds: CGRect, levelSize: CGSize) -> CGRect {
        guard levelSize.width > 0, levelSize.height > 0 else { return .zero }
        let scale = min(bounds.width / levelSize.width, bounds.height / levelSize.height)
        let size = CGSize(width: levelSize.width * scale, height: levelSize.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }

    public static func draw(in context: CGContext, bounds: CGRect, image: CGImage?, visible: CGRect, levelSize: CGSize, overlay: Bool = false,
                            thumbnail: GameMinimapThumbnail? = nil, displayBounds: CGRect? = nil) {
        let bounds = drawingFrame(in: bounds, displayBounds: displayBounds)
        if overlay { GameDisplayArt.draw(in: context, frame: bounds) }
        let map = content(in: overlay ? bounds.insetBy(dx: 4, dy: 4) : bounds, levelSize: levelSize)
        guard !map.isEmpty else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.interpolationQuality = .none
        if let image {
            context.setAlpha(0.8)
            GameStoneArt.drawImage(thumbnail?.image(for: image, in: map, context: context) ?? image, in: map, context: context)
            context.setAlpha(1)
        }
        let scale = map.width / levelSize.width
        let window = CGRect(x: map.minX + visible.minX * scale, y: map.minY + visible.minY * scale,
                            width: visible.width * scale, height: visible.height * scale).intersection(map)
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.8))
        context.setLineWidth(1)
        context.stroke(window)
    }
}

/// Shrinks each new level frame once, in its own colour space and pixel format.
/// Colour matching then covers only the map's pixels, not the whole level.
public final class GameMinimapThumbnail {
    private var source: CGImage?
    private var size = (width: 0, height: 0)
    private var thumbnail: CGImage?

    public init() {}

    /// The thumbnail at the device-pixel size of `rect`, or nil to draw the source unchanged.
    public func image(for source: CGImage, in rect: CGRect, context: CGContext) -> CGImage? {
        let device = context.convertToDeviceSpace(rect)
        return image(for: source, width: Int(abs(device.width).rounded()), height: Int(abs(device.height).rounded()))
    }

    /// Nearest-neighbour samples at pixel centres, which matches unfiltered scaling.
    public func image(for source: CGImage, width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0, width < source.width || height < source.height else { return nil }
        if self.source === source, size == (width, height) { return thumbnail }
        let alpha = source.alphaInfo
        guard source.bitsPerComponent == 8, source.bitsPerPixel == 32,
              source.bitmapInfo.intersection(.byteOrderMask).rawValue == 0,
              [.last, .premultipliedLast, .noneSkipLast].contains(alpha),
              let space = source.colorSpace, let data = source.dataProvider?.data,
              CFDataGetLength(data) >= source.bytesPerRow * (source.height - 1) + source.width * 4,
              let bytes = CFDataGetBytePtr(data) else { return nil }
        let sourceRow = source.bytesPerRow
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let columns = (0..<width).map { min(source.width - 1, Int((Double($0) + 0.5) * Double(source.width) / Double(width))) * 4 }
        pixels.withUnsafeMutableBytes { output in
            for y in 0..<height {
                let row = bytes + min(source.height - 1, Int((Double(y) + 0.5) * Double(source.height) / Double(height))) * sourceRow
                let target = output.baseAddress! + y * width * 4
                for (x, column) in columns.enumerated() { memcpy(target + x * 4, row + column, 4) }
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let made = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                  space: space, bitmapInfo: source.bitmapInfo, provider: provider, decode: nil,
                  shouldInterpolate: false, intent: source.renderingIntent) else { return nil }
        self.source = source; size = (width, height); thumbnail = made
        return made
    }
}
