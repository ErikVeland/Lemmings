import AppKit
import NxlvKit

// Development-only contact sheet. No game assets are copied into the source.
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
func image(_ pixels: [UInt8], width: Int, height: Int, palette: [UInt8], opaque: [Bool]? = nil) -> NSImage {
    var rgba = [UInt8](repeating: 0, count: width * height * 4)
    for i in pixels.indices {
        for c in 0..<3 { rgba[i * 4 + c] = palette[Int(pixels[i]) * 4 + c] }
        rgba[i * 4 + 3] = (opaque?[i] ?? true) ? 255 : 0
    }
    let cg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: CGDataProvider(data: Data(rgba) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    return NSImage(cgImage: cg, size: NSSize(width: width, height: height))
}
do {
    let assets = try Lemmings2FrontEnd(root: root)
    let name = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "MENU"
    let bank = assets.banks[name]!
    let palette = bank.palettes[min(1, bank.palettes.count - 1)]
    let picture = assets.pictures[name] ?? assets.pictures["ROCKWALL"]!
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 960, pixelsHigh: 800, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context.cgContext, flipped: true)
    let transform = NSAffineTransform(); transform.translateX(by: 0, yBy: 800); transform.scaleX(by: 1, yBy: -1); transform.concat()
    NSColor.darkGray.setFill(); NSRect(x: 0, y: 0, width: 960, height: 800).fill()
    image(picture, width: 320, height: 200, palette: palette).draw(in: NSRect(x: 0, y: 0, width: 640, height: 400),
        from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
    for (i, frames) in bank.sprites.enumerated() {
        let f = frames[0], x = i % 6 * 160, y = 420 + i / 6 * 76
        image(f.pixels, width: f.width, height: f.height, palette: palette, opaque: f.opaque).draw(
            in: NSRect(x: x, y: y, width: min(150, f.width), height: min(65, f.height)), from: .zero,
            operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        print(i, frames.count, "\(f.width)x\(f.height)")
    }
    for (i, glyph) in assets.font.glyphs.prefix(91).enumerated() {
        image(glyph, width: 16, height: 11, palette: palette, opaque: glyph.map { $0 != 0 }).draw(
            in: NSRect(x: 650 + i % 16 * 16, y: 10 + i / 16 * 15, width: 16, height: 11), from: .zero,
            operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: output)
    print(bank.strings.enumerated().map { "\($0.offset): \($0.element)" }.joined(separator: "\n"))
} catch { print(error); exit(1) }
