import CoreGraphics
import Foundation
import NxlvKit

/// Rounded contours follow Duo's display while retaining crisp bitmap edges.
/// Shape affects drawing only. Input and accessibility retain the full rectangle.
public enum GameControlShape: Sendable {
    case square, rounded

    public func path(in frame: CGRect, inset: CGFloat = 0) -> CGPath {
        let box = frame.insetBy(dx: inset, dy: inset)
        guard box.width > 0, box.height > 0 else { return CGMutablePath() }
        let radius = self == .rounded ? max(0, min(20, min(frame.width, frame.height) / 4) - inset) : 0
        return CGPath(roundedRect: box, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    public func fill(_ frame: CGRect, inset: CGFloat = 0, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        context.addPath(path(in: frame, inset: inset))
        context.fillPath()
    }

    public func stroke(_ frame: CGRect, inset: CGFloat = 0, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        context.addPath(path(in: frame, inset: inset))
        context.strokePath()
    }
}

/// The stone socket every game control shares, drawn the same way on every platform.
///
/// Colours are sRGB equivalents of the Mac app's calibrated values, so both look alike.
///
/// Rectangles use a top-left origin, so a context must already be flipped to that
/// orientation. AppKit views that return `isFlipped` and UIKit views both are.
public enum GameStoneArt {
    private struct TextOutline: @unchecked Sendable {
        let source: CGImage
        let image: CGImage
        var bytes: Int { image.bytesPerRow * image.height }
    }
    private final class TextOutlineCache: @unchecked Sendable {
        private let lock = NSLock()
        private let limit = 8 * 1024 * 1024
        private var bytes = 0
        private var entries: [String: TextOutline] = [:]
        private var order: [String] = []

        func value(for key: String) -> TextOutline? {
            lock.lock(); defer { lock.unlock() }
            return entries[key]
        }

        func insert(_ value: TextOutline, for key: String) {
            lock.lock(); defer { lock.unlock() }
            guard value.bytes <= limit, entries[key] == nil else { return }
            while bytes + value.bytes > limit, !order.isEmpty {
                if let removed = entries.removeValue(forKey: order.removeFirst()) { bytes -= removed.bytes }
            }
            entries[key] = value; order.append(key); bytes += value.bytes
        }
    }
    private static let textOutlines = TextOutlineCache()

    /// Draw a one-device-pixel outside border without changing the bitmap ink.
    public static func drawTextOutline(_ image: CGImage, in rect: CGRect, context: CGContext) {
        let device = context.convertToDeviceSpace(CGSize(width: 1, height: 1))
        let sx = max(1, abs(device.width)), sy = max(1, abs(device.height))
        let width = max(1, Int((rect.width * sx).rounded()))
        let height = max(1, Int((rect.height * sy).rounded()))
        guard width <= 4096, height <= 4096, width * height <= 262_144 else { return }
        let key = "\(ObjectIdentifier(image)):\(width):\(height)"
        let cached = textOutlines.value(for: key)
        let outline: CGImage
        if let cached { outline = cached.image }
        else {
            let w = width + 2, h = height + 2
            var pixels = [UInt8](repeating: 0, count: w * h * 4)
            let success = pixels.withUnsafeMutableBytes { bytes -> Bool in
                guard let bitmap = CGContext(data: bytes.baseAddress, width: w, height: h,
                    bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
                bitmap.interpolationQuality = .none
                bitmap.draw(image, in: CGRect(x: 1, y: 1, width: width, height: height))
                return true
            }
            guard success else { return }
            let alpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
            var border = [UInt8](repeating: 0, count: pixels.count)
            for y in 0..<h { for x in 0..<w where alpha[y * w + x] == 0 {
                var opaque = false
                for dy in -1...1 { for dx in -1...1 {
                    let nx = x + dx, ny = y + dy
                    if nx >= 0 && nx < w && ny >= 0 && ny < h && alpha[ny * w + nx] > 0 { opaque = true }
                } }
                if opaque { border[(y * w + x) * 4 + 3] = 204 }
            } }
            guard let provider = CGDataProvider(data: Data(border) as CFData),
                  let made = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32,
                    bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
                    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return }
            outline = made
            textOutlines.insert(TextOutline(source: image, image: made), for: key)
        }
        context.saveGState()
        context.setBlendMode(.overlay)
        context.interpolationQuality = .none
        drawImage(outline, in: rect.insetBy(dx: -1 / sx, dy: -1 / sy), context: context)
        context.restoreGState()
    }
    private struct RockFrame: Decodable {
        let width: Int, height: Int
        let file: String
    }
    private struct RockManifest: Decodable {
        let names: [String: String]
        let banks: [String: [RockFrame?]]
    }

    /// The Macintosh background rock also supplies the original 1-bit button texture.
    /// Cache its colour pixels with restrained opacity, using the existing artwork bank.
    private static let rock: CGImage? = {
        guard let directory = Bundle.main.resourceURL?.appendingPathComponent("MacArtwork/lemmings"),
              let data = try? Data(contentsOf: directory.appendingPathComponent("manifest.json")),
              let manifest = try? JSONDecoder().decode(RockManifest.self, from: data),
              let bank = manifest.names.first(where: { $0.value == "Charset2" })?.key,
              let frames = manifest.banks[bank], frames.indices.contains(95), let frame = frames[95],
              frame.width > 0, frame.height > 0, frame.width <= 4096, frame.height <= 4096,
              !frame.file.contains("/"), !frame.file.contains(".."),
              var pixels = try? Data(contentsOf: directory.appendingPathComponent(frame.file)),
              pixels.count == frame.width * frame.height * 4 else { return nil }
        // Keep the authored grain and palette. Opacity blends it into the original socket colours
        // and still respects a caller's disabled alpha.
        for offset in stride(from: 3, to: pixels.count, by: 4) {
            pixels[offset] = UInt8(Double(pixels[offset]) * 0.35)
        }
        guard let provider = CGDataProvider(data: pixels as CFData) else { return nil }
        return CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: frame.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }()

    /// Grain stays at one source pixel per logical pixel, independent of button size and bevel.
    /// Continue the original background tile across large wells without enlarging its pixels.
    public static func drawDetailedRock(in context: CGContext, frame: CGRect, pixel: CGFloat, selected: Bool = false) {
        let inner = well(frame, pixel: pixel)
        guard inner.width.isFinite, inner.height.isFinite, inner.minX.isFinite, inner.minY.isFinite,
              inner.width > 0, inner.height > 0, let image = rock else { return }
        let width = CGFloat(image.width), height = CGFloat(image.height)
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: inner)
        context.interpolationQuality = .none
        context.setShouldAntialias(false)
        for y in 0..<Int(ceil(inner.height / height)) {
            for x in 0..<Int(ceil(inner.width / width)) {
                drawImage(image, in: CGRect(x: inner.minX + CGFloat(x) * width,
                    y: inner.minY + CGFloat(y) * height, width: width, height: height), context: context)
            }
        }
    }

    private static let light = CGColor(srgbRed: 0.7084, green: 0.7154, blue: 0.6550, alpha: 1)
    private static let stone = CGColor(srgbRed: 0.4245, green: 0.4435, blue: 0.3937, alpha: 1)
    private static let shadow = CGColor(srgbRed: 0.1457, green: 0.1718, blue: 0.1325, alpha: 1)
    private static let wellIdle = CGColor(srgbRed: 0.0876, green: 0.1166, blue: 0.0728, alpha: 1)
    private static let wellSelected = CGColor(srgbRed: 0.2211, green: 0.3123, blue: 0.1319, alpha: 1)
    private static let selectedHighlight = CGColor(srgbRed: 0.78, green: 0.79, blue: 0.70, alpha: 1)
    private static let selectedShadow = CGColor(srgbRed: 0.24, green: 0.29, blue: 0.19, alpha: 1)

    /// The recessed area inside the bevel, where a glyph belongs.
    public static func well(_ frame: CGRect, pixel: CGFloat) -> CGRect {
        frame.insetBy(dx: 4 * pixel, dy: 4 * pixel)
    }

    /// Bevel, rim and well. A caller may paint artwork into the well before `drawAccent`.
    public static func drawSocket(in context: CGContext, frame: CGRect, selected: Bool, pixel: CGFloat, monochrome: Bool = false, shape: GameControlShape = .square) {
        let light = monochrome ? CGColor(gray: 1, alpha: 1) : Self.light
        let stone = monochrome ? CGColor(gray: 1, alpha: 1) : Self.stone
        let shadow = monochrome ? CGColor(gray: 0, alpha: 1) : Self.shadow
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        if shape == .rounded {
            let upper = selected ? shadow : light
            let lower = selected ? light : shadow
            context.setFillColor(lower)
            shape.fill(frame, inset: pixel, in: context)
            context.saveGState()
            context.move(to: CGPoint(x: frame.minX, y: frame.maxY))
            context.addLine(to: CGPoint(x: frame.minX, y: frame.minY))
            context.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
            context.closePath()
            context.clip()
            context.setFillColor(upper)
            shape.fill(frame, inset: pixel, in: context)
            context.restoreGState()
            context.setFillColor(stone)
            shape.fill(frame, inset: 2 * pixel, in: context)
            context.setFillColor(shadow)
            shape.fill(frame, inset: 3 * pixel, in: context)
            context.setFillColor(monochrome ? CGColor(gray: 0, alpha: 1) : selected ? wellSelected : wellIdle)
            shape.fill(frame, inset: 4 * pixel, in: context)
            context.addPath(shape.path(in: frame, inset: 4 * pixel))
            context.clip()
            if !monochrome { drawDetailedRock(in: context, frame: frame, pixel: pixel, selected: selected) }
            return
        }
        func fill(_ rect: CGRect, _ color: CGColor) {
            context.setFillColor(color)
            context.fill(rect)
        }
        let rim = frame.insetBy(dx: pixel, dy: pixel)
        fill(rim, stone)
        // Top and left catch the light; the selected button sinks into its socket.
        let upper = selected ? shadow : light
        let lower = selected ? light : shadow
        for step in 0..<2 {
            let edge = rim.insetBy(dx: CGFloat(step) * pixel, dy: CGFloat(step) * pixel)
            fill(CGRect(x: edge.minX, y: edge.minY, width: edge.width, height: pixel), upper)
            fill(CGRect(x: edge.minX, y: edge.minY, width: pixel, height: edge.height), upper)
            fill(CGRect(x: edge.minX, y: edge.maxY - pixel, width: edge.width, height: pixel), lower)
            fill(CGRect(x: edge.maxX - pixel, y: edge.minY, width: pixel, height: edge.height), lower)
        }
        let inner = well(frame, pixel: pixel)
        fill(inner.insetBy(dx: -pixel, dy: -pixel), shadow)
        fill(CGRect(x: inner.minX, y: inner.maxY, width: inner.width, height: pixel), light)
        fill(CGRect(x: inner.maxX, y: inner.minY, width: pixel, height: inner.height), light)
        fill(inner, monochrome ? CGColor(gray: 0, alpha: 1) : selected ? wellSelected : wellIdle)
        if !monochrome { drawDetailedRock(in: context, frame: frame, pixel: pixel, selected: selected) }
    }

    /// Draws an original panel tile at the scale that fills the whole button, cropped to the
    /// well. The tile keeps its size, and its textured edge gives way to the stone bevel.
    /// A button wider than the tile repeats it side by side.
    public static func drawTile(in context: CGContext, image: CGImage, logicalSize: CGSize,
                                frame: CGRect, pixel: CGFloat) {
        let width = logicalSize.width
        guard width > 0 else { return }
        let copies = max(1, Int(ceil(well(frame, pixel: pixel).width / width)))
        let left = floor(frame.midX - CGFloat(copies) * width / 2)
        let top = floor(frame.midY - logicalSize.height / 2)
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: well(frame, pixel: pixel))
        context.interpolationQuality = .none
        for copy in 0..<copies {
            drawImage(image, in: CGRect(x: left + CGFloat(copy) * width, y: top,
                                        width: width, height: logicalSize.height), context: context)
        }
    }

    /// Draws an image into a top-left-origin context without flipping it.
    public static func drawImage(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        context.restoreGState()
    }

    /// A small raised rim marks a selected socket without adding a bright colour patch.
    public static func drawAccent(in context: CGContext, frame: CGRect, selected: Bool, pixel: CGFloat, monochrome: Bool = false) {
        guard selected else { return }
        let inner = well(frame, pixel: pixel)
        guard inner.width > 2 * pixel, inner.height > 2 * pixel else { return }
        context.saveGState()
        context.setShouldAntialias(false)
        let highlight = monochrome ? CGColor(gray: 1, alpha: 1) : selectedHighlight
        let shadow = monochrome ? CGColor(gray: 0.45, alpha: 1) : selectedShadow
        context.setFillColor(highlight)
        context.fill(CGRect(x: inner.minX + pixel, y: inner.minY + pixel, width: inner.width - 2 * pixel, height: pixel))
        context.fill(CGRect(x: inner.minX + pixel, y: inner.minY + pixel, width: pixel, height: inner.height - 2 * pixel))
        context.setFillColor(shadow)
        context.fill(CGRect(x: inner.minX + pixel, y: inner.maxY - 2 * pixel, width: inner.width - 2 * pixel, height: pixel))
        context.fill(CGRect(x: inner.maxX - 2 * pixel, y: inner.minY + pixel, width: pixel, height: inner.height - 2 * pixel))
        context.restoreGState()
    }

    public static func draw(in context: CGContext, frame: CGRect, selected: Bool, pixel: CGFloat, shape: GameControlShape = .square) {
        drawSocket(in: context, frame: frame, selected: selected, pixel: pixel, shape: shape)
        drawAccent(in: context, frame: frame, selected: selected, pixel: pixel)
    }
}
