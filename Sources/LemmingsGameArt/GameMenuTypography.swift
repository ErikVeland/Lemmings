import CoreGraphics
import Foundation
import NxlvKit

/// Menu lettering drawn from the Macintosh release's own character sets.
///
/// Rectangles use a top-left origin, as in `GameStoneArt`. Every glyph lands on a
/// whole-number scale with no smoothing, as in the original.
public final class GameMenuTypography {
    public enum Palette: String, Sendable { case blue, green }
    public enum Alignment: Sendable { case left, center, right }
    public typealias Face = ClassicMacUserInterface.Face

    public let interface: ClassicMacUserInterface
    public let menuLogo: CGImage?
    public let homeLogos: GameHomeLogoArt
    private var glyphs: [String: CGImage] = [:]

    public init(interface: ClassicMacUserInterface, homeLogos: GameHomeLogoArt = .bundled) {
        self.interface = interface
        menuLogo = interface.logo.flatMap { GameMenuLogo.image(for: $0) }
        self.homeLogos = homeLogos
    }

    /// Reads the bundled `MacArtwork/lemmings` banks, or nil when they are absent.
    public convenience init?(directory: URL) {
        guard let artwork = try? ClassicMacArtwork(directory: directory),
              let interface = ClassicMacUserInterface(artwork: artwork) else { return nil }
        self.init(interface: interface)
    }

    /// The Macintosh panel's authored black digits and pink counter socket.
    public func drawCounter(_ text: String, in box: CGRect, panelScale: CGFloat, context: CGContext) -> Bool {
        guard interface.counterGlyphs.count == 11, interface.counterGlyphs.prefix(10).allSatisfy({ $0 != nil }),
            CGFloat(text.count * 6) <= box.width else { return false }
        let scale = max(1, floor(min(panelScale / 2, box.width / CGFloat(max(1, text.count * 6 + 4)), box.height / 9)))
        let width = min(box.width, max(24 * scale, CGFloat(text.count * 6 + 4) * scale))
        let socket = CGRect(x: floor(box.midX - width / 2), y: floor(box.minY), width: width, height: box.height)
        if let panel = interface.counterPanel, let image = bitmap(panel), image.width == 640,
            let crop = image.cropping(to: CGRect(x: 38, y: 2, width: 24, height: 18)) {
            GameStoneArt.drawImage(crop, in: socket, context: context)
        } else { context.setFillColor(CGColor(srgbRed: 1, green: 221.0 / 255, blue: 221.0 / 255, alpha: 1)); context.fill(socket) }
        if text == "∞" {
            GamePixelTypography.draw(text, in: socket, context: context, typography: nil, maximumScale: scale, bitmapOnly: true, color: CGColor(gray: 0, alpha: 1))
            return true
        }
        let left = floor(box.midX - CGFloat(text.count * 6) * scale / 2)
        for (offset, character) in text.enumerated() {
            guard let digit = character.wholeNumberValue, (0..<10).contains(digit),
                let glyph = interface.counterGlyphs[digit], let image = bitmap(glyph) else { return false }
            GameStoneArt.drawImage(image, in: CGRect(x: left + CGFloat(offset * 6) * scale,
                y: floor(box.midY - 4.5 * scale), width: 6 * scale, height: 9 * scale), context: context)
        }
        return true
    }
    private func bitmap(_ frame: ClassicMacArtwork.Frame) -> CGImage? {
        guard let provider = CGDataProvider(data: frame.rgba as CFData) else { return nil }
        return CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    public func font(_ face: Face) -> ClassicMacUserInterface.Font? { interface.font(face) }

    public func width(of text: String, face: Face, scale: Int) -> CGFloat {
        CGFloat(font(face)?.width(of: text, scale: scale) ?? 0)
    }

    public func height(face: Face, scale: Int) -> CGFloat {
        CGFloat(font(face)?.height(scale: scale) ?? 0)
    }

    public func height(of text: String, face: Face, scale: Int) -> CGFloat {
        CGFloat(font(face)?.height(of: Self.menuText(text), scale: scale) ?? 0)
    }

    /// Draws a line with its top-left corner at `origin`.
    public func draw(_ text: String, face: Face, at origin: CGPoint, scale: Int, in context: CGContext,
                     alpha: CGFloat = 1, palette: Palette = .blue) {
        guard let font = font(face) else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.interpolationQuality = .none
        context.setShouldAntialias(false)
        context.setAlpha(alpha)
        for item in font.layout(text) {
            guard let glyph = item.glyph,
                  let image = image(for: glyph, key: "\(face.rawValue)-\(item.sequence)", palette: palette) else { continue }
            let rect = CGRect(x: origin.x + CGFloat((item.x + glyph.x) * scale), y: origin.y + CGFloat(glyph.y * scale),
                              width: CGFloat(glyph.width * scale), height: CGFloat(glyph.height * scale))
            Self.draw(image, in: rect, context: context)
        }
    }

    /// Uses the original glyphs at a fixed size, with the same cell spacing on every page.
    public func menuLine(_ value: String, in rect: CGRect, context: CGContext, face: Face = .small, scale: Int = 1,
                         alignment: Alignment = .center, alpha: CGFloat = 1, palette: Palette = .blue) {
        guard let font = font(face) else { return }
        let line = GameTextLayout.truncated(value, width: rect.width, face: face, scale: scale, font: font)
        guard !line.isEmpty else { return }
        let width = width(of: line, face: face, scale: scale)
        let x: CGFloat
        switch alignment {
        case .left: x = rect.minX
        case .right: x = rect.maxX - width
        case .center: x = rect.midX - width / 2
        }
        let top = CGFloat(font.verticalBounds(of: line).top * scale)
        let left = CGFloat(font.horizontalBounds(of: line).left * scale)
        draw(line, face: face, at: CGPoint(x: (x - left).rounded(), y: (rect.minY - top).rounded()), scale: scale,
             in: context, alpha: alpha, palette: palette)
    }

    /// The largest whole-number scale whose cell fits the height.
    public func scale(face: Face, fitting height: CGFloat) -> Int {
        guard let font = font(face), font.cellHeight > 0 else { return 1 }
        return max(1, Int(height / CGFloat(font.cellHeight)))
    }

    public static func menuText(_ value: String) -> String {
        let plain = BitmapLatinGlyphs.uppercase(value.folding(options: [.widthInsensitive], locale: L10n.interface.locale), locale: L10n.interface.locale)
            .replacingOccurrences(of: "—", with: "-").replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'").replacingOccurrences(of: "ʼ", with: "'")
            .replacingOccurrences(of: "“", with: "\"").replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "„", with: "\"").replacingOccurrences(of: "«", with: "\"").replacingOccurrences(of: "»", with: "\"")
            .replacingOccurrences(of: "…", with: "...").replacingOccurrences(of: "‑", with: "-")
            .replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "·", with: "*").replacingOccurrences(of: "•", with: "*")
            .replacingOccurrences(of: "→", with: "->").replacingOccurrences(of: "←", with: "<-")
            .replacingOccurrences(of: "×", with: "X").replacingOccurrences(of: "↵", with: L10n.text("ENTER"))
            .replacingOccurrences(of: "‹", with: "<").replacingOccurrences(of: "›", with: ">")
        return BitmapTamilGlyphs.sequences(in: plain).map { sequence in
            if BitmapTamilGlyphs.supports(sequence) { return sequence }
            return sequence.count == 1 && sequence.allSatisfy { BitmapLatinGlyphs.supports($0) || $0 == "💀" } ? sequence : "?"
        }.joined()
    }

    private static func draw(_ image: CGImage, in rect: CGRect, context: CGContext) {
        // The context is top-left origin, and `draw(_:in:)` assumes bottom-left.
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        context.restoreGState()
    }

    private func image(for frame: ClassicMacArtwork.Frame, key: String, palette: Palette) -> CGImage? {
        let key = palette.rawValue + ":" + key
        if let cached = glyphs[key] { return cached }
        var pixels = frame.rgba
        if palette == .green {
            // Rotate the blue ramp into grass green. Preserve the original bevel,
            // neutral highlights, dark outline and alpha without filtering pixels.
            pixels.withUnsafeMutableBytes { raw in
                let bytes = raw.bindMemory(to: UInt8.self)
                for i in stride(from: 0, to: bytes.count, by: 4) {
                    let red = bytes[i], green = bytes[i + 1], blue = bytes[i + 2]
                    bytes[i] = green; bytes[i + 1] = blue; bytes[i + 2] = red
                }
            }
        }
        guard let provider = CGDataProvider(data: pixels as CFData),
              let image = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false,
                                  intent: .defaultIntent) else { return nil }
        glyphs[key] = image
        return image
    }
}
