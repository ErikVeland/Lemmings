#if os(macOS)
import AppKit
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class SequelLatinRenderTests: XCTestCase {
    private var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    private func requireLocalAssets(_ paths: String...) throws {
        let missing = paths.filter { !FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path) }
        guard missing.isEmpty else { throw XCTSkip("Original game assets are not present in this checkout: \(missing.joined(separator: ", "))") }
    }

    @MainActor func testL2FrontEndUnicodeAccessibilityAndActivation() throws {
        try requireLocalAssets("Sources/Ports/Lemm2/FONT.DAT", "Sources/Ports/Lemm2/FRONTEND/GFXIFFS/INFO.IFF")
        _ = NSApplication.shared
        let base = root.appendingPathComponent("Sources/Ports/Lemm2")
        let font = try Lemmings2FrontEndFont(data: Data(contentsOf: base.appendingPathComponent("FONT.DAT")))
        let palette = try Lemmings2FrontEnd.Bank(data: Data(contentsOf: base.appendingPathComponent("FRONTEND/GFXIFFS/INFO.IFF"))).palettes[1]
        let canvas = Lemmings2MenuCanvas(frame: CGRect(x: 0, y: 0, width: 960, height: 720))
        let window = NSWindow(contentRect: canvas.bounds, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = canvas
        defer { window.close() }
        let target = CGRect(x: 24, y: 100, width: 272, height: 22)
        var activated = false
        canvas.menuActions = { [("Prøv igjen, ÅȘÆØ", target, { activated = true })] }
        canvas.onDraw = {
            canvas.text("ÆØÅ – éñç œß", font: font, palette: palette, x: 24, y: 20)
            canvas.fittedText("Éric et Åsa, ÆØÅ", font: font, palette: palette, rect: CGRect(x: 24, y: 50, width: 272, height: 40))
            canvas.text("Prøv igjen, ÅȘÆØ", font: font, palette: palette, x: 24, y: 100)
        }
        let element = try XCTUnwrap(canvas.accessibilityChildren()?.first as? GameAccessibleElement)
        XCTAssertEqual(element.accessibilityLabel(), "Prøv igjen, ÅȘÆØ")
        XCTAssertTrue(element.accessibilityPerformPress()); XCTAssertTrue(activated)
        var coordinates: (Int, Int)?
        canvas.onClick = { coordinates = ($0, $1) }
        let point = canvas.convert(CGPoint(x: target.midX * 3, y: target.midY * 3.6), to: nil)
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point,
            modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        canvas.mouseDown(with: event)
        XCTAssertEqual(coordinates?.0, Int(target.midX)); XCTAssertEqual(coordinates?.1, Int(target.midY))
        let bitmap = try XCTUnwrap(canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds))
        canvas.displayIgnoringOpacity(canvas.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)))
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".build/sequel-latin"), withIntermediateDirectories: true)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: root.appendingPathComponent(".build/sequel-latin/l2-native-front.png"))
    }

    @MainActor func testNativeFacesAndPanelLettering() throws {
        try requireLocalAssets("Sources/Ports/Lemm2/FONT.DAT", "Sources/Ports/Lemm2/PANEL.DAT",
            "Sources/Ports/LEM3CD/GRAPHICS/FONT.DIN", "Sources/Ports/LEM3CD/GRAPHICS/FONT.DEL")
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let l2 = root.appendingPathComponent("Sources/Ports/Lemm2"), l3 = root.appendingPathComponent("Sources/Ports/LEM3CD")
        let output = root.appendingPathComponent(".build/sequel-latin")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let menu = try Lemmings2FrontEndFont(data: Data(contentsOf: l2.appendingPathComponent("FONT.DAT")))
        let panel = try Lemmings2Panel(root: l2)
        let font3 = try Lemmings3Font(index: Data(contentsOf: l3.appendingPathComponent("GRAPHICS/FONT.DIN")), data: Data(contentsOf: l3.appendingPathComponent("GRAPHICS/FONT.DEL")))
        let bank = try Lemmings2FrontEnd.Bank(data: Data(contentsOf: l2.appendingPathComponent("FRONTEND/GFXIFFS/INFO.IFF")))
        let palette2 = bank.palettes[1]
        var palette3 = [UInt8](repeating: 0, count: 1024)
        for (i, rgb) in [(132, [220, 238, 186]), (135, [93, 123, 78])] {
            for c in 0..<3 { palette3[i * 4 + c] = UInt8(rgb[c]) }; palette3[i * 4 + 3] = 255
        }
        let renderer = SequelArtworkRenderer()
        let samples = ["ABCDEFGHIJKLMNOPQRSTUVWXYZ", "ÆØÅ ÄÖÜ ÀÁÂÃ ÇÈÉÊË ÌÍÎÏ ÑÒÓÔÕ ÙÚÛÝ", "ŒÐÞŁĐĦŦŊẞİĲ ¡¿", "ĀĂĄĆĈĊČĎ ĒĖĘĚĞĢĨ ĶĹĻĽŃŅŇ ŐŔŘŚŞŠ ŢŤŰŲŹŻŽ ȘȚ", "æøå äöü àáâã çèéêë ìíîï ñòóôõ ùúûýÿ œðþłđħŧŋßı"]
        for (name, font, palette) in [("l2-menu", menu.bitmap, palette2), ("l2-panel", panel.font, Lemmings2Panel.palette(over: palette2)), ("l3-font", font3.bitmap, palette3)] {
            let context = try XCTUnwrap(CGContext(data: nil, width: 1500, height: 450, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            NSGraphicsContext.saveGraphicsState(); defer { NSGraphicsContext.restoreGraphicsState() }
            context.translateBy(x: 0, y: 450); context.scaleBy(x: 1, y: -1)
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            NSColor.black.setFill(); CGRect(x: 0, y: 0, width: 1500, height: 450).fill()
            var y: CGFloat = 12
            for text in samples {
                let top = font.verticalBounds(of: text).top
                var x: CGFloat = 16
                for character in text {
                    guard let glyph = font.glyph(for: character) else { continue }
                    let image = try renderer.image(width: glyph.width, height: glyph.height, pixels: glyph.pixels, palette: palette,
                        opaque: glyph.opaque, category: .architectural, frontEnd: name == "l2-menu")
                    image.draw(in: CGRect(x: x + CGFloat(glyph.x * 3), y: y + CGFloat((glyph.y - top) * 3),
                        width: CGFloat(glyph.width * 3), height: CGFloat(glyph.height * 3)), from: .zero, operation: .sourceOver,
                        fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
                    x += CGFloat(glyph.advance * 3)
                }
                y += CGFloat(font.height(of: text) * 3) + 16
            }
            let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(context.makeImage()))
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent(name + ".png"))
        }
        let native = try Lemmings3Panel(root: l3, tribe: 4, renderer: renderer)
        XCTAssertTrue(native.font.bitmap.covers("ÆØÅ éñç œß ȘȚ"))
        func renderNative(_ text: String) throws -> CGImage {
            let context = try XCTUnwrap(CGContext(data: nil, width: 640, height: 100, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.translateBy(x: 0, y: 100); context.scaleBy(x: 1, y: -1)
            NSGraphicsContext.saveGraphicsState(); defer { NSGraphicsContext.restoreGraphicsState() }
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            NSColor.black.setFill(); CGRect(x: 0, y: 0, width: 640, height: 100).fill()
            native.text(text, x: 12, y: 12, scale: 4)
            return try XCTUnwrap(context.makeImage())
        }
        let composed = try renderNative("ÅØÆ ÉÇȘȚ ¡¿")
        let combining = try renderNative("A\u{030A}ØÆ E\u{0301}C\u{0327}S\u{0326}T\u{0326} ¡¿")
        XCTAssertEqual(composed.dataProvider?.data as Data?, combining.dataProvider?.data as Data?)
        try XCTUnwrap(NSBitmapImageRep(cgImage: composed).representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("l3-native-font.png"))
        for slot in 0..<9 {
            let x = CGFloat(Lemmings3Panel.edges[slot] + Lemmings3Panel.edges[slot + 1]) / 2
            XCTAssertEqual(Lemmings3Panel.slot(at: x), slot)
        }
        for label in ["WALKER", "ÅSA ÆØÅ ÉÇȘ"] {
            let indexed = try panel.render(skills: [Int](repeating: 1, count: 8), supplies: [Int](repeating: 10, count: 8), selected: 0,
                saved: 2, remaining: 8, seconds: 60, label: label, palette: Lemmings2Panel.palette(over: palette2))
            let image = try renderer.image(width: indexed.width, height: indexed.height, pixels: indexed.pixels, palette: indexed.palette, category: .architectural)
            let cg = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
            try XCTUnwrap(NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])).write(to: output.appendingPathComponent(label == "WALKER" ? "l2-panel-ascii.png" : "l2-panel-latin.png"))
        }
    }
}
#endif
