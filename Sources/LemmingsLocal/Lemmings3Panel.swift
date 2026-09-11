import AppKit
import NxlvKit

/// Original Mode-X panel pixels and the shipped fixed-width FONT bank.
@MainActor struct Lemmings3Panel {
    static let edges = [0, 35, 70, 105, 140, 175, 214, 249, 284, 320]
    static let names = ["Walker", "Blocker", "Jumper", "Use tool", "Drop tool", "Time remaining", "Fast forward", "Pause", "End run"]
    let normal: NSImage
    let pressed: NSImage
    let glyphs: [NSImage]

    init(root: URL, tribe: Int, renderer: SequelArtworkRenderer) throws {
        let folder = root.appendingPathComponent("GRAPHICS")
        func read(_ name: String) throws -> [UInt8] { Array(try Data(contentsOf: folder.appendingPathComponent(name))) }
        let source = try read(String(format: "TRIBE%03d.PAL", tribe))
        guard source.count == 96 else { throw SequelDataError.invalid("Invalid L3 panel palette.") }
        var palette = [UInt8](repeating: 0, count: 1024)
        for i in 0..<32 {
            for channel in 0..<3 { palette[i * 4 + channel] = UInt8(Int(source[i * 3 + channel] & 63) * 255 / 63) }
            palette[i * 4 + 3] = 255
        }
        func panel(_ suffix: String) throws -> NSImage {
            let bytes = try read(String(format: "PAN%03d%@.RAW", tribe, suffix))
            guard bytes.count == 12800 else { throw SequelDataError.invalid("Invalid L3 panel dimensions.") }
            var pixels = [UInt8](repeating: 0, count: 12800)
            for y in 0..<40 { for x in 0..<320 {
                let sourceIndex = (x % 4) * 3200 + y * 80 + x / 4
                pixels[y * 320 + x] = bytes[sourceIndex]
            } }
            return try renderer.image(width: 320, height: 40, pixels: pixels, palette: palette, category: .architectural)
        }
        normal = try panel(""); pressed = try panel("X")
        let index = try read("FONT.DIN"), data = try read("FONT.DEL")
        guard index.count == 136 else { throw SequelDataError.invalid("Invalid L3 font index.") }
        // Small glyphs use terrain palette slots in the original. Give menu text
        // stable light and shadow colours independent of the current terrain.
        for i in [132, 135] {
            palette[i * 4] = i == 132 ? 220 : 93
            palette[i * 4 + 1] = i == 132 ? 238 : 123
            palette[i * 4 + 2] = i == 132 ? 186 : 78
            palette[i * 4 + 3] = 255
        }
        var offset = 0, decoded: [NSImage] = []
        for i in 0..<68 {
            let count = Int(index[i * 2]) | Int(index[i * 2 + 1]) << 8
            guard count == (i < 30 ? 110 : 64), offset + count <= data.count else { throw SequelDataError.invalid("Invalid L3 font glyph.") }
            if i >= 30 {
                // FONT rows are stored bottom-up; panel planes are top-down.
                var pixels = [UInt8](repeating: 0, count: 64)
                for y in 0..<8 { for x in 0..<8 { pixels[y * 8 + x] = data[offset + (7 - y) * 8 + x] } }
                decoded.append(try renderer.image(width: 8, height: 8, pixels: pixels, palette: palette,
                    opaque: pixels.map { $0 != 0 }, category: .architectural))
            }
            offset += count
        }
        guard offset == data.count else { throw SequelDataError.invalid("Trailing L3 font data.") }
        glyphs = decoded
    }
    func text(_ value: String, x: CGFloat, y: CGFloat, scale: CGFloat = 1) {
        for (position, scalar) in value.uppercased().unicodeScalars.enumerated() {
            let code = Int(scalar.value)
            let index = (48...57).contains(code) ? code - 48 : (65...90).contains(code) ? code - 65 + 10 : 36
            glyphs[index].draw(in: CGRect(x: x + CGFloat(position) * 8 * scale, y: y, width: 8 * scale, height: 8 * scale),
                from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
        }
    }
    static func slot(at x: CGFloat) -> Int? {
        guard x >= 0 && x < 320 else { return nil }
        return (0..<9).first { x < CGFloat(edges[$0 + 1]) }
    }
}
