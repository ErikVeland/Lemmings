import AppKit
import Foundation

enum PanelButton: Equatable {
    case nuke, pause, fastForward, rateDown, rateUp, skill(Int)
}

@MainActor enum GamePixelText {
    static func draw(_ text: String, in rect: CGRect, maxScale: CGFloat) {}
}

func require(_ value: @autoclosure () -> Bool, _ message: String) {
    if !value() { fatalError(message) }
}

@MainActor func pixels(_ image: NSImage) -> (width: Int, height: Int, rgba: [UInt8]) {
    guard let bitmap = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let data = bitmap.dataProvider?.data,
          bitmap.bytesPerRow == bitmap.width * 4 else { fatalError("Missing bitmap pixels") }
    return (bitmap.width, bitmap.height, [UInt8](data as Data))
}

@MainActor func run() throws {
    let glyphs: [PanelGlyph] = [.rock, .pause, .nuke, .play, .undo, .fastForward]
    var comparisons: [(name: String, original: [UInt8], recreated: [UInt8], width: Int, height: Int)] = []
    for glyph in glyphs {
        let logical = glyph.pixelSize
        require(glyph.macImage(fitting: CGSize(width: logical.width - 1,
            height: logical.height)) == nil, "\(glyph.rawValue) overflows a compact control")
        guard let before = glyph.image(scale: 1),
              let after = glyph.macImage(fitting: CGSize(width: logical.width, height: logical.height))
        else { fatalError("Could not render \(glyph.rawValue)") }
        let source = pixels(before), result = pixels(after)
        require(before.size == after.size, "\(glyph.rawValue) changed its control bounds")
        require(result.width == logical.width * 2 && result.height == logical.height * 2,
            "\(glyph.rawValue) is not at Macintosh pixel scale")
        var original = [UInt8](repeating: 0, count: result.rgba.count)
        for y in 0..<result.height { for x in 0..<result.width {
            let sourceX = glyph.isOriginalTile ? x : x / 2
            let sourceY = y / 2
            let from = (sourceY * source.width + sourceX) * 4
            let to = (y * result.width + x) * 4
            original[to..<to + 4] = source.rgba[from..<from + 4]
            require(result.rgba[to + 3] == original[to + 3],
                "\(glyph.rawValue) changed the visible control shape")
        } }
        require(result.rgba != original, "\(glyph.rawValue) has only doubled source pixels")
        comparisons.append((glyph.rawValue, original, result.rgba, result.width, result.height))
    }

    let width = 400, height = 930
    var sheet = [UInt8](repeating: 0, count: width * height * 4)
    for offset in stride(from: 0, to: sheet.count, by: 4) {
        sheet[offset..<offset + 4] = [24, 28, 34, 255]
    }
    func blit(_ rgba: [UInt8], width sourceWidth: Int, height sourceHeight: Int,
              x: Int, y: Int, scale: Int) {
        for sy in 0..<sourceHeight { for sx in 0..<sourceWidth {
            let from = (sy * sourceWidth + sx) * 4
            guard rgba[from + 3] != 0 else { continue }
            for dy in 0..<scale { for dx in 0..<scale {
                let to = ((y + sy * scale + dy) * width + x + sx * scale + dx) * 4
                sheet[to..<to + 4] = rgba[from..<from + 4]
            } }
        } }
    }
    for (index, item) in comparisons.enumerated() {
        let top = 20 + index * 150
        blit(item.original, width: item.width, height: item.height, x: 50, y: top, scale: 3)
        blit(item.recreated, width: item.width, height: item.height, x: 240, y: top, scale: 3)
    }
    guard let provider = CGDataProvider(data: Data(sheet) as CFData),
          let bitmap = CGImage(width: width, height: height, bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
          let png = NSBitmapImageRep(cgImage: bitmap).representation(using: .png, properties: [:])
    else { fatalError("Could not create panel proof") }
    let path = URL(fileURLWithPath: ".build/classic-mac-panel-art/proof.png")
    try png.write(to: path, options: .atomic)
    print("PASS six panel glyphs preserve bounds and alpha with recreated 2× pixels: \(path.path)")
}

try run()
