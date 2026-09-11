import AppKit
import CryptoKit
import NxlvKit

@MainActor enum SequelArtworkPreference {
    // Start the default-on release enabled, including installs with the old opt-in setting.
    static let key = "SequelMacArtworkEnabledV2"
    static let changed = Notification.Name("SequelMacArtworkChanged")
    static var enabled: Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: key)
        NotificationCenter.default.post(name: changed, object: nil)
    }
}

/// Bounded, disposable visual cache. Logical NSImage sizes retain PC anchors.
/// Content keys include palette, opacity, category and the reconstruction revision.
@MainActor final class SequelArtworkRenderer {
    private let cache = NSCache<NSString, NSImage>()
    init() { cache.totalCostLimit = 64 * 1024 * 1024 }

    /// Presentation-only contours can refine glyph and illustration silhouettes.
    /// Gameplay masks never pass through this treatment. Colours remain discrete.
    private static func frontEndContours(_ source: SequelMacFrame, reconstructed: SequelMacFrame) throws -> SequelMacFrame {
        let w = source.width, h = source.height
        var rgba = reconstructed.rgba
        func colour(_ x: Int, _ y: Int) -> UInt32 {
            let p = (max(0, min(h - 1, y)) * w + max(0, min(w - 1, x))) * 4
            guard source.rgba[p + 3] != 0 else { return 0 }
            return UInt32(source.rgba[p]) << 24 | UInt32(source.rgba[p + 1]) << 16
                | UInt32(source.rgba[p + 2]) << 8 | 255
        }
        for y in 0..<h { for x in 0..<w {
            let b = colour(x, y - 1), d = colour(x - 1, y)
            let f = colour(x + 1, y), lower = colour(x, y + 1)
            guard b != lower && d != f else { continue }
            let corners: [UInt32?] = [d == b ? d : nil, b == f ? f : nil,
                                      d == lower ? d : nil, lower == f ? f : nil]
            for (corner, value) in corners.enumerated() {
                guard let value else { continue }
                let p = ((y * 2 + corner / 2) * w * 2 + x * 2 + corner % 2) * 4
                rgba[p] = UInt8(truncatingIfNeeded: value >> 24)
                rgba[p + 1] = UInt8(truncatingIfNeeded: value >> 16)
                rgba[p + 2] = UInt8(truncatingIfNeeded: value >> 8)
                rgba[p + 3] = UInt8(truncatingIfNeeded: value)
            }
        } }
        return try SequelMacFrame(width: w * 2, height: h * 2, x: reconstructed.x,
                                  y: reconstructed.y, rgba: rgba, sourcePalette: source.sourcePalette)
    }

    func image(width: Int, height: Int, pixels: [UInt8], palette: [UInt8],
               opaque: [Bool]? = nil, category: SequelMacCategory, frontEnd: Bool = false) throws -> NSImage {
        var digest = SHA256()
        digest.update(data: Data("\(SequelMacArtwork.revision)/\(SequelArtworkPreference.enabled)/\(width)/\(height)/\(category.rawValue)/front-end-1/\(frontEnd)".utf8))
        digest.update(data: Data(pixels)); digest.update(data: Data(palette))
        if let opaque { digest.update(data: Data(opaque.map { $0 ? 1 : 0 })) }
        else { digest.update(data: Data([2])) }
        let key = digest.finalize().map { String(format: "%02x", $0) }.joined() as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let source = try SequelMacFrame(width: width, height: height, pixels: pixels, palette: palette, opaque: opaque)
        var frame = try SequelArtworkPreference.enabled ? SequelMacArtwork.reconstruct(source, category: category) : source
        if SequelArtworkPreference.enabled && frontEnd {
            frame = try Self.frontEndContours(source, reconstructed: frame)
        }
        guard let provider = CGDataProvider(data: Data(frame.rgba) as CFData),
              let cg = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8,
                bitsPerPixel: 32, bytesPerRow: frame.width*4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            throw SequelDataError.invalid("Cannot create sequel artwork.")
        }
        let image = NSImage(cgImage: cg, size: NSSize(width: width, height: height))
        cache.setObject(image, forKey: key, cost: frame.rgba.count)
        return image
    }
}
