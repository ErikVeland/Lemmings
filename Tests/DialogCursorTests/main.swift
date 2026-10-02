import AppKit

@MainActor final class GameMenuPage: NSView {
    var onHorizontalNavigation: ((Int) -> Void)?
    var controllerInitialControl: NSView?
}

private final class FlippedRoot: NSView {
    override var isFlipped: Bool { true }
}

@MainActor private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { FileHandle.standardError.write(Data((message + "\n").utf8)); exit(1) }
}

@MainActor private func checkOrder(in root: NSView, positions: [CGFloat]) {
    let buttons = ["A", "B", "C"].enumerated().map { index, title in
        let button = NSButton(title: title, target: nil, action: nil)
        button.frame = CGRect(x: [100, 0, -10][index], y: positions[index], width: 70, height: 20)
        root.addSubview(button)
        return button
    }
    let navigation = DialogKeyboardNavigation()
    let ordered = navigation.controls(in: root)
    check(ordered.count == 3 && ordered[0] === buttons[1]
        && ordered[1] === buttons[0] && ordered[2] === buttons[2],
        "Nearby controls did not keep a stable left-to-right row order")
    buttons[1].isEnabled = false
    check(navigation.controls(in: root).count == 2, "A disabled control remained in the focus order")
    buttons[1].isEnabled = true
    buttons[2].isHidden = true
    check(navigation.controls(in: root).count == 2, "A hidden control remained in the focus order")
}

@MainActor private func cursorBitmap(original: Bool, occupied: Bool, zoom: CGFloat, backing: Int) -> NSBitmapImageRep {
    let side = 96 * backing
    let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
        bytesPerRow: side * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x: 0, y: CGFloat(side))
    context.scaleBy(x: CGFloat(backing), y: -CGFloat(backing))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    GameCursor.drawPlayfieldPointer(at: CGPoint(x: 48, y: 48), scale: zoom, tint: .white,
        original: original, occupied: occupied)
    NSGraphicsContext.restoreGraphicsState()
    return NSBitmapImageRep(cgImage: context.makeImage()!)
}

@MainActor private func testOriginalCursor() {
    func lit(_ bitmap: NSBitmapImageRep) -> Int {
        var result = 0
        for y in 0..<bitmap.pixelsHigh { for x in 0..<bitmap.pixelsWide {
            if bitmap.colorAt(x: x, y: y)!.alphaComponent > 0.5 { result += 1 }
        } }
        return result
    }
    for backing in [1, 2] {
        for zoom: CGFloat in [1, 2, 3, 2.5] {
            let empty = cursorBitmap(original: true, occupied: false, zoom: zoom, backing: backing)
            let target = cursorBitmap(original: true, occupied: true, zoom: zoom, backing: backing)
            let nativePixel = Int(floor(zoom)) * backing
            check(lit(empty) == 28 * nativePixel * nativePixel, "Original cross lost its dotted pixel pattern")
            check(lit(target) == 36 * nativePixel * nativePixel, "Original target lost its square corners")
            let frame = GameCursor.playfieldPointerFrame(at: CGPoint(x: 48, y: 48), scale: zoom)
            let x = Int(frame.minX) * backing, y = Int(frame.minY) * backing
            check(target.colorAt(x: x, y: y)!.greenComponent > 0.6 && target.colorAt(x: x, y: y)!.redComponent < 0.01,
                "Original target lost its green corners")
            check(empty.colorAt(x: x, y: y)!.alphaComponent == 0,
                "Empty terrain retained the square target")
            check(empty.colorAt(x: x + 6 * nativePixel, y: y)!.greenComponent > 0.6,
                "Original cross lost its top arm")
            check(empty.colorAt(x: 48 * backing, y: 48 * backing)!.alphaComponent == 1,
                "Original cross lost its centre marker")
            check(target.colorAt(x: 48 * backing, y: 48 * backing)!.alphaComponent == 0,
                "Original target filled its transparent centre")
            for (bitmap, name) in [(empty, "amiga-cursor"), (target, "amiga-reticule")] {
                let sourceURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                    .appendingPathComponent("Fixtures/\(name).png")
                let reference = NSBitmapImageRep(data: try! Data(contentsOf: sourceURL))!.retagging(with: .sRGB)!
                for row in 0..<Int(frame.height) * backing {
                    for column in 0..<Int(frame.width) * backing {
                        let sourceX = Int((CGFloat(column) + 0.5) * 2 / CGFloat(nativePixel))
                        let sourceY = Int((CGFloat(row) + 0.5) * 2 / CGFloat(nativePixel))
                        let expected = reference.colorAt(x: sourceX, y: sourceY)!.usingColorSpace(.sRGB)!
                        let actual = bitmap.colorAt(x: x + column, y: y + row)!.usingColorSpace(.sRGB)!
                        check(abs(actual.alphaComponent - expected.alphaComponent) < 0.001,
                            "\(name) transparency changed at zoom \(zoom), backing \(backing)")
                        if expected.alphaComponent > 0 {
                            // At integer source scaling, every supplied colour must match exactly.
                            if nativePixel % 2 == 0 {
                                check(abs(actual.redComponent - expected.redComponent) < 1.1 / 255
                                    && abs(actual.greenComponent - expected.greenComponent) < 1.1 / 255
                                    && abs(actual.blueComponent - expected.blueComponent) < 1.1 / 255,
                                    "\(name) colour changed at (\(sourceX), \(sourceY)), zoom \(zoom), backing \(backing)")
                            }
                        }
                    }
                }
            }
            let modernEmpty = cursorBitmap(original: false, occupied: false, zoom: zoom, backing: backing)
            let modernTarget = cursorBitmap(original: false, occupied: true, zoom: zoom, backing: backing)
            check(modernEmpty.representation(using: .png, properties: [:]) == modernTarget.representation(using: .png, properties: [:]),
                "Hovering changed the Modern cursor's shape")
        }
    }
    GameCursor.gameplaySuppressed = true
    for original in [false, true] {
        check(lit(cursorBitmap(original: original, occupied: true, zoom: 2, backing: 2)) == 0,
            "A modal dialog retained a gameplay cursor")
    }
    GameCursor.gameplaySuppressed = false
    let preview = NSImage(size: CGSize(width: 288, height: 96), flipped: true) { _ in
        NSColor(calibratedRed: 0, green: 0, blue: 0.2, alpha: 1).setFill()
        CGRect(x: 0, y: 0, width: 288, height: 96).fill()
        for (i, state) in [(true, false), (true, true), (false, true)].enumerated() {
            GameCursor.drawPlayfieldPointer(at: CGPoint(x: 48 + i * 96, y: 48), scale: 3,
                tint: .white, original: state.0, occupied: state.1)
        }
        return true
    }
    let bitmap = NSBitmapImageRep(data: preview.tiffRepresentation!)!
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    try! bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent(".build/dialog-cursor-tests/cursor-styles.png"))
    print("PASS Original cross/target pixels, colour, zoom/Retina scaling, Modern stability and dialog suppression")
}

@MainActor private func run() {
    _ = NSApplication.shared
    checkOrder(in: NSView(frame: CGRect(x: 0, y: 0, width: 300, height: 300)),
        positions: [200, 195, 190])
    checkOrder(in: FlippedRoot(frame: CGRect(x: 0, y: 0, width: 300, height: 300)),
        positions: [0, 5, 10])

    let playfield = CGRect(x: 10, y: 10, width: 100, height: 80)
    GameCursor.gameplaySuppressed = false
    check(GameCursor.hidesSystemCursor(at: CGPoint(x: 20, y: 20), inside: playfield),
        "Gameplay did not use the drawn pointer")
    check(!GameCursor.hidesSystemCursor(at: CGPoint(x: 1, y: 1), inside: playfield),
        "A control area hid the system cursor")
    GameCursor.gameplaySuppressed = true
    check(!GameCursor.hidesSystemCursor(at: CGPoint(x: 20, y: 20), inside: playfield),
        "A dialog retained the drawn gameplay pointer")
    GameCursor.gameplaySuppressed = false
    testOriginalCursor()
    print("PASS dialog focus rows, hidden controls and gameplay cursor policy")
}

MainActor.assumeIsolated { run() }
