import CoreGraphics
import Foundation
import NxlvKit

/// Size-specific lettering made from the extended Macintosh character sets.
/// Tiny HUD text keeps its compact face. Larger text keeps the Lemmings shapes and bevel.
public enum GameLemmingsTypography {
    public enum Ink: String, Sendable { case blue, green, warning, monochrome }

    private struct Raster: @unchecked Sendable {
        let image: CGImage
        let x: Int, y: Int
    }
    private static let rasters = GameAssetCache<Raster>(capacity: 1024)
    private static let bundledInterface: ClassicMacUserInterface? = {
        guard let directory = Bundle.main.resourceURL?.appendingPathComponent("MacArtwork/lemmings"),
              let artwork = try? ClassicMacArtwork(directory: directory) else { return nil }
        return ClassicMacUserInterface(artwork: artwork)
    }()

    /// Returns false when the complete line needs the tiny HUD face or artwork is unavailable.
    /// Height is a role's chosen size, rather than permission to enlarge a short label.
    @discardableResult public static func draw(_ text: String, in rect: CGRect, height: CGFloat,
        interface: ClassicMacUserInterface? = nil, face: GameMenuTypography.Face? = nil,
        palette: Ink = .blue, alignment: GameMenuTypography.Alignment = .center,
        alpha: CGFloat? = nil, color: CGColor? = nil, highlighted: Character? = nil,
        numberPalette: Ink? = nil, preservesCase: Bool = false, context: CGContext) -> Bool {
        guard !text.isEmpty, !text.contains("∞"), rect.width.isFinite, rect.height.isFinite,
              rect.width > 0, rect.height >= 12, height >= 12,
              let source = interface ?? bundledInterface else { return false }
        let plain = preservesCase ? text.precomposedStringWithCanonicalMapping : GameMenuTypography.menuText(text)
        let chosenFace = face ?? (height >= 32 ? .large : .small)
        guard let font = source.font(chosenFace) ?? source.font(.small), font.covers(plain) else { return false }
        let bounds = font.verticalBounds(of: plain)
        let horizontal = font.horizontalBounds(of: plain)
        let cellHeight = min(192, height, rect.height * CGFloat(font.cellHeight) / CGFloat(bounds.bottom - bounds.top),
            rect.width * CGFloat(font.cellHeight) / CGFloat(max(1, horizontal.right - horizontal.left)))
        let pixels = Int(floor(cellHeight + 0.00001))
        guard pixels >= 12 else { return false }
        let scale = CGFloat(pixels) / CGFloat(font.cellHeight)
        let width = CGFloat(horizontal.right - horizontal.left) * scale
        let x: CGFloat
        switch alignment {
        case .left: x = rect.minX
        case .center: x = rect.midX - width / 2
        case .right: x = rect.maxX - width
        }
        let origin = CGPoint(x: (x - CGFloat(horizontal.left) * scale).rounded(),
            y: (rect.midY - CGFloat(bounds.bottom - bounds.top) * scale / 2 - CGFloat(bounds.top) * scale).rounded())
        let items = font.layout(plain)
        let selected = highlighted.flatMap { key in items.firstIndex { $0.sequence.contains(key) } }
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: rect)
        context.setShouldAntialias(false)
        context.interpolationQuality = .none
        if let alpha { context.setAlpha(alpha) }
        for (index, item) in items.enumerated() {
            guard let glyph = item.glyph else { continue }
            var ink = item.sequence.allSatisfy({ $0.isNumber || $0 == "," }) ? numberPalette ?? palette : palette
            if highlighted != nil, palette != .monochrome { ink = index == selected ? .green : .blue }
            guard let raster = raster(glyph, sequence: item.sequence, cellWidth: font.cellWidth,
                cellHeight: font.cellHeight, pixels: pixels, ink: ink, color: color) else { continue }
            let frame = CGRect(x: origin.x + (CGFloat(item.x) * scale).rounded() + CGFloat(raster.x),
                y: origin.y + CGFloat(raster.y), width: CGFloat(raster.image.width), height: CGFloat(raster.image.height))
            GameStoneArt.drawImage(raster.image, in: frame, context: context)
        }
        if palette == .monochrome, let selected {
            let item = items[selected]
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: origin.x + (CGFloat(item.x) * scale).rounded(), y: rect.maxY - 1,
                width: max(1, CGFloat(item.advance - 1) * scale), height: 1))
        }
        return true
    }

    private static func raster(_ original: ClassicMacArtwork.Frame, sequence: String, cellWidth: Int, cellHeight: Int, pixels: Int,
        ink: Ink, color: CGColor?) -> Raster? {
        let tint = color?.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)?.components
        let key = "\(original.rgba.hashValue):\(original.x):\(original.y):\(original.width):\(cellWidth):\(cellHeight):\(sequence):\(pixels):\(ink.rawValue):\(tint ?? [])"
        if let cached = rasters.value(for: key) { return cached }
        let countdown = cellWidth == 16 && cellHeight == 20 && pixels >= 80
            ? GameLemmingsCountdownFace.frame(original, sequence: sequence) : nil
        let display = pixels > cellHeight
        let glyph = countdown ?? (display ? GameLemmingsDisplayFace.frame(original, sequence: sequence,
            cellWidth: cellWidth, cellHeight: cellHeight) : GameLemmingsDisplayFace.Glyph(original))
        let cutScale = countdown != nil ? 4 : display ? 2 : 1
        let factor = Double(pixels) / Double(cellHeight * cutScale)
        let exact = pixels == cellHeight * cutScale
        let source = [UInt8](glyph.rgba)
        let width = max(1, Int((Double(glyph.width) * factor).rounded()))
        let height = max(1, Int((Double(glyph.height) * factor).rounded()))
        var result = [UInt8](repeating: 0, count: width * height * 4)
        if exact {
            // Draw the original, 2× display or 4× countdown pixels without resampling.
            for y in 0..<height { for x in 0..<width {
                let offset = (min(glyph.height - 1, Int(Double(y) / factor)) * glyph.width
                    + min(glyph.width - 1, Int(Double(x) / factor))) * 4
                let rgb = Array(source[offset..<offset + 3])
                let opacity = UInt8((CGFloat(source[offset + 3]) * (tint?.last ?? 1)).rounded())
                let pixel = coloured(rgb, ink: ink, tint: tint) + [opacity]
                result.replaceSubrange((y * width + x) * 4..<(y * width + x + 1) * 4, with: pixel)
            } }
        } else {
            // Rebuild the silhouette on the target grid. Edge-directed enlargement keeps diagonals
            // connected; coverage sampling retains counters when making a smaller cut.
            let body = stride(from: 0, to: source.count, by: 4).map { i in
                source[i + 3] > 0 && (source[i] != 0 || source[i + 1] != 0 || source[i + 2] > 64)
            }
            let doubled = enlarge(body, width: glyph.width, height: glyph.height)
            let enlarged = enlarge(doubled, width: glyph.width * 2, height: glyph.height * 2)
            let sourceWidth = glyph.width * 4, sourceHeight = glyph.height * 4
            var mask = [Bool](repeating: false, count: width * height)
            for y in 0..<height { for x in 0..<width {
                var covered = 0
                for sy in 0..<4 { for sx in 0..<4 {
                    let px = min(sourceWidth - 1, Int((Double(x) + (Double(sx) + 0.5) / 4) * Double(sourceWidth) / Double(width)))
                    let py = min(sourceHeight - 1, Int((Double(y) + (Double(sy) + 0.5) / 4) * Double(sourceHeight) / Double(height)))
                    if enlarged[py * sourceWidth + px] { covered += 1 }
                } }
                mask[y * width + x] = covered >= 8
            } }
            func inside(_ x: Int, _ y: Int) -> Bool {
                x >= 0 && y >= 0 && x < width && y < height && mask[y * width + x]
            }
            let bevel = max(1, min(3, pixels / 20))
            for y in 0..<height { for x in 0..<width {
                let rgb: [UInt8]
                if inside(x, y) {
                    if display {
                        let sx = min(glyph.width - 1, Int(Double(x) / factor))
                        let sy = min(glyph.height - 1, Int(Double(y) / factor))
                        let offset = (sy * glyph.width + sx) * 4
                        let painted = Array(source[offset..<offset + 3])
                        rgb = painted.max()! > 64 ? painted : [48, 128, 208]
                    } else if !inside(x - bevel, y - bevel) { rgb = [176, 192, 224] }
                    else if !inside(x + bevel, y + bevel) { rgb = [0, 48, 144] }
                    else if !inside(x - bevel * 2, y - bevel * 2) { rgb = [112, 160, 209] }
                    else { rgb = [48, 128, 208] }
                } else if (-1...1).contains(where: { dy in (-1...1).contains { dx in inside(x + dx, y + dy) } }) {
                    rgb = [0, 0, 64]
                } else { continue }
                result.replaceSubrange((y * width + x) * 4..<(y * width + x + 1) * 4,
                    with: coloured(rgb, ink: ink, tint: tint) + [UInt8((255 * (tint?.last ?? 1)).rounded())])
            } }
        }
        guard let provider = CGDataProvider(data: Data(result) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        let raster = Raster(image: image, x: Int((Double(glyph.x) * factor).rounded()),
            y: Int((Double(glyph.y) * factor).rounded()))
        rasters.insert(raster, for: key)
        return raster
    }

    /// Scale2x smooths pixel-art corners without inventing a different letter skeleton.
    private static func enlarge(_ pixels: [Bool], width: Int, height: Int) -> [Bool] {
        var result = [Bool](repeating: false, count: width * height * 4)
        func at(_ x: Int, _ y: Int) -> Bool { pixels[min(height - 1, max(0, y)) * width + min(width - 1, max(0, x))] }
        for y in 0..<height { for x in 0..<width {
            let b = at(x, y - 1), d = at(x - 1, y), e = at(x, y), f = at(x + 1, y), h = at(x, y + 1)
            let edge = b != h && d != f
            result[(y * 2) * width * 2 + x * 2] = edge && d == b ? d : e
            result[(y * 2) * width * 2 + x * 2 + 1] = edge && b == f ? f : e
            result[(y * 2 + 1) * width * 2 + x * 2] = edge && d == h ? d : e
            result[(y * 2 + 1) * width * 2 + x * 2 + 1] = edge && h == f ? f : e
        } }
        return result
    }

    private static func coloured(_ rgb: [UInt8], ink: Ink, tint: [CGFloat]?) -> [UInt8] {
        if let tint, tint.count >= 3 {
            let light = CGFloat(rgb.max() ?? 0) / 255
            return tint.prefix(3).map { UInt8(clamping: Int(($0 * light * 255).rounded())) }
        }
        switch ink {
        case .blue: return rgb
        case .green: return [rgb[1], rgb[2], rgb[0]]
        case .warning: return [rgb[2], UInt8(Double(rgb[2]) * 0.42), UInt8(Double(rgb[2]) * 0.12)]
        case .monochrome: let white = rgb.max() ?? 0; return [white, white, white]
        }
    }
}
