import CoreGraphics
import CoreText
import Foundation

/**
 * Rasterises the unmodified Lix UI font without a system-font fallback.
 */
public struct LixInterfaceText: Sendable {
    public struct Frame: Sendable {
        public let width: Int
        public let height: Int
        public let rgba: Data
    }

    public enum DecodeError: Error {
        case invalidFont
    }

    private let data: Data

    public init(directory: URL) throws {
        let file = directory.appendingPathComponent("djvusans.ttf")
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, (1...1_000_000).contains(size) else {
            throw DecodeError.invalidFont
        }
        try self.init(data: Data(contentsOf: file))
    }

    public init(data: Data) throws {
        guard !data.isEmpty, data.count <= 1_000_000,
              let provider = CGDataProvider(data: data as CFData), let font = CGFont(provider),
              font.postScriptName as String? == "DejaVuSansCondensed-Bold" else { throw DecodeError.invalidFont }
        self.data = data
    }

    /**
     * Keeps each line bounded and draws the supplied typeface at whole pixel sizes.
     */
    public func frame(_ text: String, pixelSize: Int, red: UInt8 = 255,
                      green: UInt8 = 255, blue: UInt8 = 255) -> Frame? {
        guard !text.isEmpty, text.utf16.count <= 1_024, (8...40).contains(pixelSize),
              let provider = CGDataProvider(data: data as CFData), let graphicsFont = CGFont(provider) else { return nil }
        let font = CTFontCreateWithGraphicsFont(graphicsFont, CGFloat(pixelSize), nil, nil)
        let units = Array(text.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: units.count)
        guard CTFontGetGlyphsForCharacters(font, units, &glyphs, units.count) else { return nil }
        let colourSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let colour = CGColor(colorSpace: colourSpace,
            components: [CGFloat(red) / 255, CGFloat(green) / 255, CGFloat(blue) / 255, 1])!
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): colour,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let advance = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        let width = Int(ceil(advance)) + 2, height = Int(ceil(ascent) + ceil(descent)) + 2
        guard (1...8_192).contains(width), (1...64).contains(height),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                  bytesPerRow: width * 4, space: colourSpace,
                  bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue),
              let bytes = context.data else { return nil }
        context.setShouldAntialias(false)
        context.setAllowsAntialiasing(false)
        context.setShouldSmoothFonts(false)
        context.setAllowsFontSmoothing(false)
        context.setShouldSubpixelPositionFonts(false)
        context.setAllowsFontSubpixelPositioning(false)
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: 1, y: ceil(descent) + 1)
        CTLineDraw(line, context)
        return Frame(width: width, height: height, rgba: Data(bytes: bytes, count: width * height * 4))
    }

    /**
     * Fits complete text with actual glyph widths. A failed fit never returns a partial paragraph.
     */
    public func paragraph(_ text: String, width: Int, height: Int, maximumLines: Int,
                          maximumPixelSize: Int, red: UInt8 = 255, green: UInt8 = 255,
                          blue: UInt8 = 255) -> [Frame]? {
        guard !text.isEmpty, text.utf16.count <= 1_024, (1...4_096).contains(width),
              (1...2_048).contains(height), (1...12).contains(maximumLines),
              (8...40).contains(maximumPixelSize) else { return nil }
        let rowHeight = height / maximumLines
        for size in stride(from: maximumPixelSize, through: 8, by: -1) {
            guard let sample = frame("Ag", pixelSize: size), sample.height <= rowHeight else { continue }
            var lines: [String] = [], current = ""
            var widths: [String: Int] = [:]
            func fits(_ value: String) -> Bool {
                if let cached = widths[value] { return cached <= width }
                guard let image = frame(value, pixelSize: size) else { return false }
                widths[value] = image.width
                return image.width <= width
            }
            for word in text.split(whereSeparator: \.isWhitespace).map(String.init) {
                let candidate = current.isEmpty ? word : current + " " + word
                if fits(candidate) { current = candidate; continue }
                if !current.isEmpty { lines.append(current); current = "" }
                if fits(word) { current = word; continue }
                for character in word {
                    if !current.isEmpty && !fits(current + String(character)) {
                        lines.append(current); current = ""
                    }
                    guard fits(String(character)) else { return nil }
                    current.append(character)
                }
            }
            if !current.isEmpty { lines.append(current) }
            guard lines.count <= maximumLines else { continue }
            let rendered = lines.compactMap { frame($0, pixelSize: size, red: red, green: green, blue: blue) }
            if rendered.count == lines.count { return rendered }
        }
        return nil
    }
}
