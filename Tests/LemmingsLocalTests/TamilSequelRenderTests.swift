#if os(macOS)
import AppKit
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class TamilSequelRenderTests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private var output: URL { root.appendingPathComponent(".build/tamil-font/sequels") }

    private func data(_ path: String) throws -> Data {
        let url = root.appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Local sequel artwork is required for the native Tamil render checks.")
        }
        return try Data(contentsOf: url)
    }

    @MainActor private func capture(width: Int, height: Int, draw: () throws -> Void) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        NSColor.black.setFill()
        CGRect(x: 0, y: 0, width: width, height: height).fill()
        try draw()
        return try XCTUnwrap(context.makeImage())
    }

    private func save(_ image: CGImage, _ name: String) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let data = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try data.write(to: output.appendingPathComponent(name))
    }

    @MainActor func testNativeL2TamilActionKeepsAccessibilityAndTarget() throws {
        _ = NSApplication.shared
        let font = try Lemmings2FrontEndFont(data: data("Sources/Ports/Lemm2/FONT.DAT"))
        let palette = try Lemmings2FrontEnd.Bank(data: data("Sources/Ports/Lemm2/FRONTEND/GFXIFFS/INFO.IFF")).palettes[1]
        let caption = "மீண்டும் முயற்சி"
        XCTAssertTrue(font.bitmap.covers(caption))
        let canvas = Lemmings2MenuCanvas(frame: CGRect(x: 0, y: 0, width: 960, height: 720))
        let window = NSWindow(contentRect: canvas.bounds, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = canvas
        defer { window.close() }
        let target = CGRect(x: 24, y: 100, width: 272, height: 24)
        var activated = false
        canvas.menuActions = { [(caption, target, { activated = true })] }
        canvas.onDraw = {
            canvas.fittedText("தமிழ் க்ஷீ ஸ்ரீ ஶ்ரீ", font: font, palette: palette,
                rect: CGRect(x: 24, y: 30, width: 272, height: 42))
            canvas.text(caption, font: font, palette: palette, x: 24, y: 100)
        }
        let accessible = try XCTUnwrap(canvas.accessibilityChildren()?.first as? GameAccessibleElement)
        XCTAssertEqual(accessible.accessibilityLabel(), caption)
        XCTAssertTrue(accessible.accessibilityPerformPress())
        XCTAssertTrue(activated)
        var coordinates: (Int, Int)?
        canvas.onClick = { coordinates = ($0, $1) }
        let point = canvas.convert(CGPoint(x: target.midX * 3, y: target.midY * 3.6), to: nil)
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point,
            modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        canvas.mouseDown(with: event)
        XCTAssertEqual(coordinates?.0, Int(target.midX))
        XCTAssertEqual(coordinates?.1, Int(target.midY))
        let bitmap = try XCTUnwrap(canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds))
        canvas.displayIgnoringOpacity(canvas.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)))
        try save(try XCTUnwrap(bitmap.cgImage), "l2-tamil-action.png")
    }

    @MainActor func testNativeL3CanonicalAndShriiAliasesRenderAlike() throws {
        _ = try data("Sources/Ports/LEM3CD/GRAPHICS/FONT.DIN")
        let panel = try Lemmings3Panel(root: root.appendingPathComponent("Sources/Ports/LEM3CD"),
            tribe: 4, renderer: SequelArtworkRenderer())
        XCTAssertTrue(panel.font.bitmap.covers("தமிழ் க்ஷீ ஸ்ரீ ஶ்ரீ"))
        func render(_ text: String) throws -> CGImage {
            try capture(width: 900, height: 160) { panel.text(text, x: 16, y: 16, scale: 4) }
        }
        let composed = try render("தமிழ் கொ ஸ்ரீ")
        let equivalent = try render("தமிழ் கொ ஶ்ரீ")
        XCTAssertEqual(composed.dataProvider?.data as Data?, equivalent.dataProvider?.data as Data?)
        try save(composed, "l3-tamil-font.png")
        for slot in 0..<9 {
            let centre = CGFloat(Lemmings3Panel.edges[slot] + Lemmings3Panel.edges[slot + 1]) / 2
            XCTAssertEqual(Lemmings3Panel.slot(at: centre), slot)
        }
    }

    @MainActor func testCompactL2TamilHeaderPreservesPanelControlsAndCounters() throws {
        _ = try data("Sources/Ports/Lemm2/PANEL.DAT")
        let panel = try Lemmings2Panel(root: root.appendingPathComponent("Sources/Ports/Lemm2"))
        let source = try Lemmings2FrontEnd.Bank(data: data("Sources/Ports/Lemm2/FRONTEND/GFXIFFS/INFO.IFF"))
        let palette = Lemmings2Panel.palette(over: source.palettes[1])
        func render(_ caption: String) throws -> SequelIndexedImage {
            try panel.render(skills: [Int](repeating: 1, count: 8), supplies: [Int](repeating: 10, count: 8),
                selected: 0, saved: 2, remaining: 8, seconds: 60, label: caption, palette: palette)
        }
        let sourcePanel = try render("WALKER")
        let tamil = try render("நடப்பவர் க்ஷீ ஸ்ரீ")
        XCTAssertNotEqual(sourcePanel.pixels, tamil.pixels)
        for y in 0..<40 {
            let start = y * 320 + (y < 9 ? 104 : 0)
            XCTAssertEqual(Array(sourcePanel.pixels[start..<(y + 1) * 320]),
                           Array(tamil.pixels[start..<(y + 1) * 320]))
        }
        let line = panel.font.truncated("நடப்பவர் க்ஷீ ஸ்ரீ", toWidth: 104)
        XCTAssertFalse(line.isEmpty)
        XCTAssertTrue(panel.font.covers(line))
        XCTAssertLessThanOrEqual(panel.font.width(of: line), 104)
        let row = panel.font.raster(line, fittingHeight: 8)
        XCTAssertEqual(row.height, 8)
        XCTAssertTrue(row.opaque.contains(true))
        let renderer = SequelArtworkRenderer()
        let image = try renderer.image(width: tamil.width, height: tamil.height, pixels: tamil.pixels,
            palette: tamil.palette, category: .architectural)
        try save(try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil)), "l2-tamil-panel.png")
    }
}
#endif
