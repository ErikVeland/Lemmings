import AppKit
import CryptoKit
import NxlvKit

@MainActor enum SequelArtworkPreference {
    static let key = "SequelMacArtworkEnabledV1"
    static let changed = Notification.Name("SequelMacArtworkChanged")
    static var enabled: Bool { UserDefaults.standard.bool(forKey: key) }
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

    func image(width: Int, height: Int, pixels: [UInt8], palette: [UInt8],
               opaque: [Bool]? = nil, category: SequelMacCategory) throws -> NSImage {
        var digest = SHA256()
        digest.update(data: Data("\(SequelMacArtwork.revision)/\(SequelArtworkPreference.enabled)/\(width)/\(height)/\(category.rawValue)".utf8))
        digest.update(data: Data(pixels)); digest.update(data: Data(palette))
        if let opaque { digest.update(data: Data(opaque.map { $0 ? 1 : 0 })) }
        else { digest.update(data: Data([2])) }
        let key = digest.finalize().map { String(format: "%02x", $0) }.joined() as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let source = try SequelMacFrame(width: width, height: height, pixels: pixels, palette: palette, opaque: opaque)
        let frame = try SequelArtworkPreference.enabled ? SequelMacArtwork.reconstruct(source, category: category) : source
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
