import Foundation

/// The FONT bank's three original digit sets and its shaded eight-pixel alphabet.
public struct Lemmings3Font: Sendable {
    public let digits: [[UInt8]]
    public let glyphs: [[UInt8]]
    public let bitmap: SequelBitmapFont

    public init(index: Data, data: Data) throws {
        guard index.count == 136 else { throw SequelDataError.invalid(L10n.text("Invalid L3 font index.")) }
        var offset = 0, digits: [[UInt8]] = [], glyphs: [[UInt8]] = []
        for i in 0..<68 {
            let count = Int(index[i * 2]) | Int(index[i * 2 + 1]) << 8
            let width = i < 30 ? 10 : 8, height = i < 30 ? 11 : 8
            guard count == width * height, offset + count <= data.count else { throw SequelDataError.invalid(L10n.text("Invalid L3 font glyph.")) }
            var pixels = [UInt8](repeating: 0, count: count)
            for y in 0..<height { for x in 0..<width { pixels[y * width + x] = data[offset + (height - y - 1) * width + x] } }
            if i < 30 { digits.append(pixels) } else { glyphs.append(pixels) }
            offset += count
        }
        guard offset == data.count else { throw SequelDataError.invalid(L10n.text("Trailing L3 font data.")) }
        self.digits = digits; self.glyphs = glyphs
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ !")
        bitmap = SequelBitmapFont(originals: Dictionary(uniqueKeysWithValues: zip(alphabet, glyphs)),
            sourceWidth: 8, height: 8, transparent: 0, shades: [135, 132], style: .sequelPanel)
    }
}
