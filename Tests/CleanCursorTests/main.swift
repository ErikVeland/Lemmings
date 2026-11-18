import AppKit

private func check(_ value: @autoclosure () -> Bool, _ message: String) {
    guard value() else { FileHandle.standardError.write(Data(("FAIL " + message + "\n").utf8)); exit(1) }
}

@MainActor private func bitmap(original: Bool, occupied: Bool, zoom: CGFloat) -> NSBitmapImageRep {
    let context = CGContext(data: nil, width: 192, height: 192, bitsPerComponent: 8,
        bytesPerRow: 768, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x: 0, y: 192); context.scaleBy(x: 2, y: -2)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    GameCursor.drawPlayfieldPointer(at: CGPoint(x: 48, y: 48), scale: zoom, tint: .white,
                                    original: original, occupied: occupied)
    NSGraphicsContext.restoreGraphicsState()
    return NSBitmapImageRep(cgImage: context.makeImage()!)
}

MainActor.assumeIsolated {
    _ = NSApplication.shared
    for zoom: CGFloat in [1, 2, 3] {
        let cross = bitmap(original: true, occupied: false, zoom: zoom)
        let square = bitmap(original: true, occupied: true, zoom: zoom)
        check(cross.representation(using: .png, properties: [:]) != square.representation(using: .png, properties: [:]),
              "The clean Original cursor lost its empty/occupied shapes")
        let source = NSBitmapImageRep(data: try! Data(contentsOf: Bundle.main.resourceURL!
            .appendingPathComponent("AlternativeAssets/Lix/assets/data/images/mouse.png")))!.retagging(with: .sRGB)!
        let step = Int(zoom)
        let origin = 96 - 16 * step
        for (actual, row) in [(cross, 0), (square, 1)] {
            for y in 0..<32 { for x in 0..<32 {
                check(source.bitsPerSample == 8 && !source.isPlanar && source.samplesPerPixel >= 3,
                      "The source cursor's direct RGB witness format changed")
                let offset = (y + 1 + row * 33) * source.bytesPerRow + (x + 1) * source.samplesPerPixel
                let bytes = source.bitmapData!
                let red = CGFloat(bytes[offset]) / 255, green = CGFloat(bytes[offset + 1]) / 255, blue = CGFloat(bytes[offset + 2]) / 255
                let magenta = red == 1 && green == 0 && blue == 1
                let actualOffset = (origin + y * step) * actual.bytesPerRow + (origin + x * step) * actual.samplesPerPixel
                let actualBytes = actual.bitmapData!
                let firstColour = actual.bitmapFormat.contains(.alphaFirst) ? 1 : 0
                let alpha = actualBytes[actualOffset + (firstColour == 1 ? 0 : 3)]
                check(alpha == (magenta ? 0 : 255), "The clean Original cursor differs from the authored Lix transparency")
                if !magenta {
                    check(actualBytes[actualOffset + firstColour] == bytes[offset]
                        && actualBytes[actualOffset + firstColour + 1] == bytes[offset + 1]
                        && actualBytes[actualOffset + firstColour + 2] == bytes[offset + 2],
                        "Lix cursor RGB differs at (\(x),\(y)), row \(row), zoom \(zoom)")
                }
            } }
        }
        check(bitmap(original: false, occupied: false, zoom: zoom).representation(using: .png, properties: [:])
              == bitmap(original: false, occupied: true, zoom: zoom).representation(using: .png, properties: [:]),
              "The Modern cursor unexpectedly changed over occupied terrain")
        if zoom == 3 {
            let output = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LEMMIX_CURSOR_CAPTURES"]!)
            try! cross.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("lix-cross.png"))
            try! square.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("lix-target.png"))
        }
    }
    print("PASS clean Original cursor: exact licensed Lix cross/target pixels at 1×/2×/3×, unchanged Modern shape")
}
