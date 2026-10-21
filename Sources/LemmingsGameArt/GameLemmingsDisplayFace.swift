import Foundation
import NxlvKit

/// The 2× display cut keeps the original colour clusters, with finer contours and retouched facets.
public enum GameLemmingsDisplayFace {
    public struct Glyph: Sendable {
        public let x: Int, y: Int, width: Int, height: Int
        public let rgba: Data
        public init(_ source: ClassicMacArtwork.Frame) {
            x = source.x; y = source.y; width = source.width; height = source.height; rgba = source.rgba
        }
        init(x: Int, y: Int, width: Int, height: Int, rgba: Data) {
            self.x = x; self.y = y; self.width = width; self.height = height; self.rgba = rgba
        }
    }
    private static let glyphs = GameAssetCache<Glyph>(capacity: 1024)
    private static let outline: UInt32 = 0x000040ff
    private static let shadow: UInt32 = 0x003090ff
    private static let middle: UInt32 = 0x0060c0ff
    private static let light: UInt32 = 0x70a0d1ff
    private static let highlight: UInt32 = 0xb0c0e0ff
    private static let glint: UInt32 = 0xffddddff

    private struct Retouch {
        let glint: (Int, Int)
        let facet: (Int, Int)
    }

    // Art direction on a 32×40 cell: each pair follows a particular cap, shoulder or terminal.
    // Accented forms inherit their base letter's retouch without moving the accent.
    private static let retouches: [Character: Retouch] = [
        "A": .init(glint: (12, 5), facet: (24, 27)), "B": .init(glint: (7, 5), facet: (23, 25)),
        "C": .init(glint: (13, 5), facet: (7, 29)), "D": .init(glint: (7, 5), facet: (24, 29)),
        "E": .init(glint: (8, 5), facet: (19, 22)), "F": .init(glint: (8, 5), facet: (17, 20)),
        "G": .init(glint: (13, 5), facet: (25, 24)), "H": .init(glint: (5, 7), facet: (23, 26)),
        "I": .init(glint: (10, 5), facet: (14, 29)), "J": .init(glint: (18, 5), facet: (8, 31)),
        "K": .init(glint: (5, 7), facet: (20, 26)), "L": .init(glint: (5, 7), facet: (18, 33)),
        "M": .init(glint: (5, 7), facet: (24, 27)), "N": .init(glint: (5, 7), facet: (20, 24)),
        "O": .init(glint: (12, 5), facet: (24, 28)), "P": .init(glint: (8, 5), facet: (23, 17)),
        "Q": .init(glint: (12, 5), facet: (25, 31)), "R": .init(glint: (8, 5), facet: (20, 27)),
        "S": .init(glint: (15, 5), facet: (19, 26)), "T": .init(glint: (12, 5), facet: (15, 30)),
        "U": .init(glint: (5, 7), facet: (22, 31)), "V": .init(glint: (5, 7), facet: (17, 31)),
        "W": .init(glint: (5, 7), facet: (23, 30)), "X": .init(glint: (5, 7), facet: (21, 28)),
        "Y": .init(glint: (5, 7), facet: (15, 27)), "Z": .init(glint: (11, 5), facet: (12, 28)),
        "0": .init(glint: (12, 5), facet: (24, 28)), "1": .init(glint: (14, 5), facet: (16, 29)),
        "2": .init(glint: (13, 5), facet: (11, 29)), "3": .init(glint: (14, 5), facet: (23, 25)),
        "4": .init(glint: (21, 5), facet: (17, 25)), "5": .init(glint: (10, 5), facet: (23, 28)),
        "6": .init(glint: (13, 5), facet: (23, 29)), "7": .init(glint: (12, 5), facet: (16, 28)),
        "8": .init(glint: (12, 5), facet: (23, 27)), "9": .init(glint: (12, 5), facet: (21, 29)),
        "Æ": .init(glint: (13, 5), facet: (23, 25)), "Œ": .init(glint: (12, 5), facet: (25, 28)),
        "ẞ": .init(glint: (11, 5), facet: (22, 28))
    ]

    /// Bounds and bearings are exactly doubled. The new pixels never change text layout.
    public static func frame(_ source: ClassicMacArtwork.Frame, sequence: String,
        cellWidth: Int, cellHeight: Int) -> Glyph {
        let key = "\(source.rgba.hashValue):\(source.x):\(source.y):\(source.width):\(cellWidth):\(cellHeight):\(sequence)"
        if let cached = glyphs.value(for: key) { return cached }
        let bytes = [UInt8](source.rgba)
        let original: [UInt32] = stride(from: 0, to: bytes.count, by: 4).map { i -> UInt32 in
            guard bytes[i + 3] != 0 else { return 0 }
            let red = UInt32(bytes[i]) << 24, green = UInt32(bytes[i + 1]) << 16
            let blue = UInt32(bytes[i + 2]) << 8, alpha = UInt32(bytes[i + 3])
            return red | green | blue | alpha
        }
        let width = source.width * 2, height = source.height * 2
        var pixels = [UInt32](repeating: 0, count: width * height)
        func at(_ x: Int, _ y: Int) -> UInt32 {
            original[min(source.height - 1, max(0, y)) * source.width + min(source.width - 1, max(0, x))]
        }
        for y in 0..<source.height { for x in 0..<source.width {
            let b = at(x, y - 1), d = at(x - 1, y), e = at(x, y), f = at(x + 1, y), h = at(x, y + 1)
            let corner = b != h && d != f
            let positions = [(y * 2) * width + x * 2, (y * 2) * width + x * 2 + 1,
                (y * 2 + 1) * width + x * 2, (y * 2 + 1) * width + x * 2 + 1]
            let colours = [corner && d == b ? d : e, corner && b == f ? f : e,
                corner && d == h ? d : e, corner && h == f ? f : e]
            for index in positions.indices { pixels[positions[index]] = colours[index] }
            // A doubled sparkle becomes a small cluster, rather than a four-pixel white square.
            if e == glint {
                var keptSparkle = false
                for position in positions where pixels[position] == glint {
                    pixels[position] = keptSparkle ? highlight : glint
                    keptSparkle = true
                }
            }
        } }
        let base = sequence.decomposedStringWithCanonicalMapping.uppercased().first
        if let base, let retouch = retouches[base] {
            func nearest(_ anchor: (Int, Int), bright: Bool) -> Int? {
                let x = Int((Double(anchor.0 * cellWidth * 2) / 32).rounded()) - source.x * 2
                let y = Int((Double(anchor.1 * cellHeight * 2) / 40).rounded()) - source.y * 2
                var match: (position: Int, distance: Int)?
                for dy in -5...5 { for dx in -5...5 {
                    let px = x + dx, py = y + dy
                    guard px >= 0, py >= 0, px < width, py < height else { continue }
                    let colour = pixels[py * width + px]
                    let suitable = bright ? colour == highlight || colour == light : colour == shadow || colour == middle
                    let distance = dx * dx + dy * dy
                    if suitable, distance < (match?.distance ?? Int.max) { match = (py * width + px, distance) }
                } }
                return match?.position
            }
            if let position = nearest(retouch.glint, bright: true) {
                pixels[position] = glint
                let below = position + width
                if below < pixels.count, pixels[below] != 0, pixels[below] != outline { pixels[below] = light }
            }
            if let position = nearest(retouch.facet, bright: false) {
                pixels[position] = middle
                let diagonal = position + width + 1
                if position % width < width - 1, diagonal < pixels.count,
                   pixels[diagonal] != 0, pixels[diagonal] != outline { pixels[diagonal] = shadow }
            }
        }
        let rgba = Data(pixels.flatMap { pixel in
            [UInt8(truncatingIfNeeded: pixel >> 24), UInt8(truncatingIfNeeded: pixel >> 16),
             UInt8(truncatingIfNeeded: pixel >> 8), UInt8(truncatingIfNeeded: pixel)]
        })
        let result = Glyph(x: source.x * 2, y: source.y * 2,
            width: width, height: height, rgba: rgba)
        glyphs.insert(result, for: key)
        return result
    }
}
