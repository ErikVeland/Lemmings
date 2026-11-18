import AppKit
import NxlvKit

@MainActor enum GamePixelText {
    static func draw(_ text: String, in rect: CGRect, maxScale: CGFloat,
                     palette: MacInterfaceRenderer.Palette) {
        preconditionFailure("The original-font proof used the synthetic fallback.")
    }
}

private enum ProofFailure: Error { case failed(String) }

private func check(_ value: Bool, _ message: String) throws {
    if !value { throw ProofFailure.failed(message) }
}

@MainActor func run() throws {
    if CommandLine.arguments.contains("--expect-disabled") {
        try check(GameMenuArtwork.renderer() == nil, "A clean app loaded the personal-only original font.")
        print("PASS original-font resource is ignored without the personal-preview flag")
        return
    }
    guard let renderer = GameMenuArtwork.renderer(),
          let small = renderer.font(.small), let large = renderer.font(.large) else {
        throw ProofFailure.failed("The personal preview did not load both original font faces.")
    }
    try check(small.cellWidth == 12 && small.cellHeight == 18
        && large.cellWidth == 16 && large.cellHeight == 20, "The original font metrics changed.")
    try check(small.glyphs.count == 95 && large.glyphs.count == 95, "The original font character range changed.")
    try check(renderer.interface.logo == nil && renderer.interface.publisher == nil
        && renderer.interface.icons.isEmpty, "The font pack contains unrelated original interface art.")

    let width = 1280, height = 720
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw ProofFailure.failed("The font proof could not create its bitmap.")
    }
    context.setFillColor(NSColor.black.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    renderer.drawCentered("ULTIMATE LEMMIX", face: .large, centerX: 640, top: 52, scale: 2, palette: .green)
    for (index, item) in ["PLAY STARTER", "IMPORT OWNED GAMES", "GET BYO BUNDLE"].enumerated() {
        renderer.menuLine(item, in: CGRect(x: 64, y: 180 + index * 90, width: 1152, height: 40),
                          face: .large, scale: 2, palette: index == 0 ? .green : .blue)
    }
    renderer.drawCentered("LIX CHARACTERS  0123456789", face: .small,
                          centerX: 640, top: 520, scale: 1, palette: .green)
    renderer.drawCentered("ABCDEFGHIJKLMNOPQRSTUVWXYZ", face: .small,
                          centerX: 640, top: 580, scale: 1, palette: .blue)
    NSGraphicsContext.restoreGraphicsState()
    guard let image = context.makeImage(),
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]),
          let destination = ProcessInfo.processInfo.environment["LEMMIX_FONT_PROOF"] else {
        throw ProofFailure.failed("The font proof could not encode its bitmap.")
    }
    let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
    var blue = 0, green = 0
    for offset in stride(from: 0, to: width * height * 4, by: 4) {
        if Int(pixels[offset + 2]) > Int(pixels[offset]) * 2
            && pixels[offset + 2] > pixels[offset + 1] { blue += 1 }
        if Int(pixels[offset + 1]) > Int(pixels[offset]) * 2
            && pixels[offset + 1] > pixels[offset + 2] { green += 1 }
    }
    try check(blue > 100 && green > 100, "The original blue and green glyph ramps did not render.")
    try png.write(to: URL(fileURLWithPath: destination), options: .atomic)
    print("PASS original 12x18/16x20 font faces, ASCII-only subset, green/blue ramps and menu sample")
}

do {
    try run()
} catch {
    print("FAIL \(error)")
    exit(1)
}
