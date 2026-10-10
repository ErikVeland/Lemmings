import AppKit

/**
 * Recreates the sequel effects that have no decoded sprite frames.
 * The backing pixels are 2×, while every image keeps its original game size.
 */
@MainActor enum SequelEffectArtwork {
    enum Mark: Hashable {
        case rope, particle, pole
    }

    struct Frame {
        let width: Int
        let height: Int
        let rgba: [UInt8]
    }

    private struct MarkKey: Hashable {
        let kind: Mark
        let red: UInt8
        let green: UInt8
        let blue: UInt8
    }

    private static var markImages: [MarkKey: NSImage] = [:]
    static let blastRingImage = image(blastRing())
    static let fireballImage = image(fireball())

    static func markImage(palette: [UInt8], colourIndex: Int, kind: Mark) -> NSImage? {
        let offset = colourIndex * 4
        guard palette.count >= offset + 3 else { return nil }
        let key = MarkKey(kind: kind, red: palette[offset], green: palette[offset + 1],
            blue: palette[offset + 2])
        if let cached = markImages[key] { return cached }
        guard let result = image(mark(red: key.red, green: key.green, blue: key.blue, kind: kind)) else {
            return nil
        }
        markImages[key] = result
        return result
    }

    /**
     * Keeps all four subpixels inside one original effect pixel.
     */
    static func mark(red: UInt8, green: UInt8, blue: UInt8, kind: Mark) -> Frame {
        let base: [UInt8] = [red, green, blue, 255]
        let light: [UInt8] = [shade(red, up: true), shade(green, up: true),
            shade(blue, up: true), 255]
        let dark: [UInt8] = [shade(red, up: false), shade(green, up: false),
            shade(blue, up: false), 255]
        let pixels: [[UInt8]]
        switch kind {
        case .rope: pixels = [light, base, base, dark]
        case .particle: pixels = [light, base, dark, base]
        case .pole: pixels = [light, light, base, dark]
        }
        return Frame(width: 2, height: 2, rgba: pixels.flatMap { $0 })
    }

    /**
     * Uses square pixels for the 40×40 blast bound that the game already draws.
     */
    static func blastRing() -> Frame {
        let size = 80
        let gaps: Set<Int> = [0, 1, 23, 24, 39, 52, 53]
        let highlights: Set<Int> = [4, 5, 6, 9, 10, 11, 14, 15, 18, 19, 27, 28]
        let shadows: Set<Int> = [31, 32, 35, 36, 42, 43, 44, 49, 50, 57, 58, 61]
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        for y in 0..<size { for x in 0..<size {
            let dx = x * 2 - 79, dy = y * 2 - 79
            let distance = dx * dx + dy * dy
            let sector = Int((atan2(Double(dy), Double(dx)) + Double.pi) * 64 / (2 * Double.pi)) % 64
            guard !gaps.contains(sector) else { continue }
            let inner = highlights.contains(sector) ? 70 : 71
            let outer = shadows.contains(sector) ? 78 : 77
            guard distance >= inner * inner && distance <= outer * outer else { continue }
            let colour: [UInt8]
            if highlights.contains(sector) && distance < 76 * 76 {
                colour = [255, 209, 85, 255]
            } else if shadows.contains(sector) {
                colour = [165, 55, 24, 255]
            } else {
                colour = [255, 133, 34, 255]
            }
            let index = (y * size + x) * 4
            pixels[index..<index + 4] = colour[0..<4]
        } }
        return Frame(width: size, height: size, rgba: pixels)
    }

    /**
     * Keeps the 6×4 source footprint and adds a bright core and cool rim.
     */
    static func fireball() -> Frame {
        let rows = [
            "....bbbb....",
            "..bboooobb..",
            ".bbooyyoobb.",
            "bbooywwyoobb",
            "bbooywwyoobb",
            ".bbooyyoobb.",
            "..bboooobb..",
            "....bbbb...."
        ]
        let palette: [Character: [UInt8]] = [
            "b": [0, 120, 184, 255],
            "o": [0, 230, 255, 255],
            "y": [142, 255, 255, 255],
            "w": [255, 255, 238, 255]
        ]
        let pixels = rows.flatMap { row in row.flatMap { palette[$0] ?? [0, 0, 0, 0] } }
        return Frame(width: 12, height: 8, rgba: pixels)
    }

    private static func shade(_ value: UInt8, up: Bool) -> UInt8 {
        let number = Int(value)
        return UInt8(up ? min(255, number + max(12, (255 - number) / 5))
            : max(0, number - max(12, number / 4)))
    }

    private static func image(_ frame: Frame) -> NSImage? {
        guard let provider = CGDataProvider(data: Data(frame.rgba) as CFData),
              let bitmap = CGImage(width: frame.width, height: frame.height,
                bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: frame.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent) else { return nil }
        return NSImage(cgImage: bitmap,
            size: NSSize(width: frame.width / 2, height: frame.height / 2))
    }
}
