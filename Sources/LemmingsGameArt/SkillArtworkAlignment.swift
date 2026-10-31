import CoreGraphics
import Foundation

@MainActor public enum SkillArtworkAlignment {
    private static var cached: [ObjectIdentifier: (CGImage, Range<Int>)] = [:]

    public static func visibleRows(_ image: CGImage) -> Range<Int> {
        let key = ObjectIdentifier(image)
        if let entry = cached[key] { return entry.1 }
        var rows = 0..<image.height
        if image.bitsPerComponent == 8, image.bitsPerPixel == 32,
           image.alphaInfo == .last || image.alphaInfo == .premultipliedLast,
           let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data),
           CFDataGetLength(data) >= image.bytesPerRow * image.height {
            var first = image.height, last = -1
            for y in 0..<image.height {
                for x in 0..<image.width where bytes[y * image.bytesPerRow + x * 4 + 3] != 0 {
                    first = min(first, y)
                    last = max(last, y)
                }
            }
            if last >= first { rows = first..<(last + 1) }
        }
        if cached.count >= 128 { cached.removeAll() }
        cached[key] = (image, rows)
        return rows
    }

    public static func originY(for image: CGImage, scale: CGFloat, centredIn area: CGRect) -> CGFloat {
        let rows = visibleRows(image)
        return floor(area.midY - CGFloat(rows.lowerBound + rows.upperBound) * scale / 2)
    }
}
