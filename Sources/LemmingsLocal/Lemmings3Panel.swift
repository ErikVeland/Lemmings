#if os(macOS)
import AppKit
import NxlvKit

/// Original Mode-X panel pixels and the shipped fixed-width FONT bank.
@MainActor struct Lemmings3Panel {
    static let edges = [0, 35, 70, 105, 140, 175, 214, 249, 284, 320]
    static let canonicalNames = ["Walker", "Blocker", "Jumper", "Use tool", "Drop tool", "Time remaining", "Fast forward", "Pause", "End run"]
    static let names = [L10n.text("Walker"), L10n.text("Blocker"), L10n.text("Jumper"), L10n.text("Use tool"), L10n.text("Drop tool"), L10n.text("Time remaining"), L10n.text("Fast forward"), L10n.text("Pause"), L10n.text("End run")]
    static let directionAnimation = 91
    let normal: NSImage
    let pressed: NSImage
    let glyphs: [NSImage]
    let font: Lemmings3Font
    private let extendedGlyphs: [Character: NSImage]

    init(root: URL, tribe: Int, renderer: SequelArtworkRenderer) throws {
        let folder = root.appendingPathComponent("GRAPHICS")
        func read(_ name: String) throws -> [UInt8] { Array(try Data(contentsOf: folder.appendingPathComponent(name))) }
        let source = try read(String(format: "TRIBE%03d.PAL", tribe))
        guard source.count == 96 else { throw SequelDataError.invalid(L10n.text("Invalid L3 panel palette.")) }
        var palette = [UInt8](repeating: 0, count: 1024)
        for i in 0..<32 {
            for channel in 0..<3 { palette[i * 4 + channel] = UInt8(Int(source[i * 3 + channel] & 63) * 255 / 63) }
            palette[i * 4 + 3] = 255
        }
        func panel(_ suffix: String) throws -> NSImage {
            let bytes = try read(String(format: "PAN%03d%@.RAW", tribe, suffix))
            guard bytes.count == 12800 else { throw SequelDataError.invalid(L10n.text("Invalid L3 panel dimensions.")) }
            var pixels = [UInt8](repeating: 0, count: 12800)
            for y in 0..<40 { for x in 0..<320 {
                let sourceIndex = (x % 4) * 3200 + y * 80 + x / 4
                pixels[y * 320 + x] = bytes[sourceIndex]
            } }
            return try renderer.image(width: 320, height: 40, pixels: pixels, palette: palette, category: .architectural)
        }
        normal = try panel(""); pressed = try panel("X")
        font = try Lemmings3Font(index: Data(read("FONT.DIN")), data: Data(read("FONT.DEL")))
        // Small glyphs use terrain palette slots in the original. Give menu text
        // stable light and shadow colours independent of the current terrain.
        for i in [132, 135] {
            palette[i * 4] = i == 132 ? 220 : 93
            palette[i * 4 + 1] = i == 132 ? 238 : 123
            palette[i * 4 + 2] = i == 132 ? 186 : 78
            palette[i * 4 + 3] = 255
        }
        glyphs = try font.glyphs.map { pixels in
            try renderer.image(width: 8, height: 8, pixels: pixels, palette: palette,
                opaque: pixels.map { $0 != 0 }, category: .architectural)
        }
        var extended: [Character: NSImage] = [:]
        for character in BitmapLatinGlyphs.characters + [Character("?")] {
            guard let glyph = font.bitmap.glyph(for: character) else { continue }
            extended[character] = try renderer.image(width: glyph.width, height: glyph.height, pixels: glyph.pixels,
                palette: palette, opaque: glyph.opaque, category: .architectural)
        }
        extendedGlyphs = extended
    }
    func text(_ value: String, x: CGFloat, y: CGFloat, scale: CGFloat = 1) {
        let text = BitmapLatinGlyphs.uppercase(value, locale: L10n.interface.locale)
        let top = font.bitmap.verticalBounds(of: text).top
        var cursor = x
        for character in text {
            defer { cursor += CGFloat(font.bitmap.advance(for: character)) * scale }
            if character == "%" {
                NSGraphicsContext.saveGraphicsState()
                let transform = NSAffineTransform()
                transform.translateX(by: cursor, yBy: y)
                transform.scale(by: scale)
                transform.concat()
                GamePixelText.draw("%", in: CGRect(x: 0, y: 0, width: 8, height: 8), maxScale: 1, palette: .green)
                NSGraphicsContext.restoreGraphicsState()
                continue
            }
            if character == "💀" {
                GamePixelText.draw("💀", in: CGRect(x: cursor, y: y, width: 8 * scale, height: 8 * scale), maxScale: scale, palette: .green)
                continue
            }
            if let code = character.asciiValue, character != "?" {
                let index = (48...57).contains(code) ? Int(code) - 48 : (65...90).contains(code) ? Int(code) - 65 + 10 : character == "!" ? 37 : 36
                glyphs[index].draw(in: CGRect(x: cursor, y: y - CGFloat(top) * scale, width: 8 * scale, height: 8 * scale),
                    from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
            } else if let glyph = font.bitmap.glyph(for: character), let image = extendedGlyphs[character] {
                image.draw(in: CGRect(x: cursor + CGFloat(glyph.x) * scale, y: y + CGFloat(glyph.y - top) * scale,
                    width: CGFloat(glyph.width) * scale, height: CGFloat(glyph.height) * scale),
                    from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
            } else if let image = extendedGlyphs["?"] {
                image.draw(in: CGRect(x: cursor, y: y, width: 8 * scale, height: 8 * scale),
                    from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
            }
        }
    }
    static func slot(at x: CGFloat) -> Int? {
        guard x >= 0 && x < 320 else { return nil }
        return (0..<9).first { x < CGFloat(edges[$0 + 1]) }
    }

    /**
     * Maps a tool direction to its frame in the original green arrow bank.
     */
    static func directionFrame(_ direction: Lemmings3Runtime.Direction) -> Int {
        switch direction {
        case .up: 0
        case .upRight: 1
        case .right: 2
        case .downRight: 3
        case .down: 4
        case .downLeft: 5
        case .left: 6
        case .upLeft: 7
        }
    }
}
#endif
