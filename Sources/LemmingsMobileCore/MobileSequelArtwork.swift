import Foundation
import NxlvKit

/// Bounds reconstructed artwork independently of camera zoom and simulation state.
final class MobileSequelArtworkCache: @unchecked Sendable {
    private struct Key: Hashable {
        let width: Int, height: Int
        let rgba: Data
        let palette: Data
        let category: SequelMacCategory
    }
    private let lock = NSLock()
    private let capacity: Int
    private let lease = RuntimePixelCacheLease()
    private var last: (pixels: [UInt8], palette: [UInt8], category: SequelMacCategory, frame: MobilePixelFrame)?
    private var frames: [Key: MobilePixelFrame] = [:]
    private var bytes = 0
    init(capacity: Int = 256) { self.capacity = capacity }

    func frame(width: Int, height: Int, rgba: [UInt8], palette: [UInt8], category: SequelMacCategory) throws -> MobilePixelFrame {
        return try lock.withLock {
            if !lease.reserve(bytes: bytes) { frames.removeAll(); bytes = 0; last = nil }
            if let last, last.pixels == rgba, last.palette == palette, last.category == category,
               last.frame.width == width * 2, last.frame.height == height * 2 { return last.frame }
            let key = Key(width: width, height: height, rgba: Data(rgba), palette: Data(palette), category: category)
            if let cached = frames[key] { return cached }
            let source = try SequelMacFrame(width: width, height: height, rgba: rgba,
                sourcePalette: palette.count == 1024 ? palette : nil)
            let result = try SequelMacArtwork.reconstruct(source, category: category)
            let frame = try MobilePixelFrame(width: result.width, height: result.height, rgba: Data(result.rgba))
            if frames.count >= capacity || bytes + frame.rgba.count + key.rgba.count > 32 * 1024 * 1024 {
                frames.removeAll(keepingCapacity: true); bytes = 0
            }
            let storage = frame.rgba.count + key.rgba.count
            if lease.reserve(bytes: bytes + storage) {
                frames[key] = frame; bytes += storage
                last = (rgba, palette, category, frame)
            } else { frames.removeAll(); bytes = 0; last = nil }
            return frame
        }
    }

    static func blend(_ frame: MobilePixelFrame, x: Int, y: Int, width: Int, height: Int,
                      mirrored: Bool = false, into pixels: inout [UInt8]) {
        let region = SceneRasterContext.region(width: width, height: height)
        for sy in 0..<frame.height where (0..<height).contains(y + sy) {
            for sx in 0..<frame.width where (0..<width).contains(x + sx) {
                let source = (sy * frame.width + (mirrored ? frame.width - sx - 1 : sx)) * 4
                let alpha = Int(frame.rgba[source + 3])
                guard alpha > 0 else { continue }
                guard let target = region.offset(x: x + sx, y: y + sy) else { continue }
                for channel in 0..<3 {
                    pixels[target + channel] = UInt8((Int(frame.rgba[source + channel]) * alpha + Int(pixels[target + channel]) * (255 - alpha)) / 255)
                }
                pixels[target + 3] = max(pixels[target + 3], frame.rgba[source + 3])
            }
        }
    }

    func sprite(_ value: MobileSpriteHighlight?, category: SequelMacCategory = .sprite) -> MobileSpriteHighlight? {
        guard let value, let result = try? frame(width: value.frame.width, height: value.frame.height,
            rgba: [UInt8](value.frame.rgba), palette: [], category: category) else { return nil }
        return .init(frame: result, rect: value.rect, cacheKey: "mac/" + value.cacheKey, time: value.time)
    }
}
