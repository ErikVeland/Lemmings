#if os(macOS)
import AppKit
import LemmingsGameArt
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class BitmapLatinRenderTests: XCTestCase {
    @MainActor func testNativeUnicodeCaptionsAndTargets() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let artwork = try ClassicMacArtwork(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        let ui = try XCTUnwrap(ClassicMacUserInterface(artwork: artwork))
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".build/latin-glyphs"), withIntermediateDirectories: true)
        try GameMenuArtwork.withRenderer(MacInterfaceRenderer(interface: ui)) {
            let page = GameMenuPage(title: "ÆØÅ – FÉLICITATIONS", subtitle: "ÅSA v ÉRIC")
            page.frame = CGRect(x: 0, y: 0, width: 1120, height: 720)
            let host = NSView(frame: page.bounds); host.addSubview(page)
            var activated = false
            let button = page.addPrimaryAction("Klar, ÅȘÆØ") { activated = true }
            let back = page.addSecondaryAction("Tilbake") {}
            page.layoutSubtreeIfNeeded()
            let target = button.convert(button.bounds, to: page)
            XCTAssertTrue(page.bounds.contains(target))
            XCTAssertTrue(page.hitTest(page.convert(CGPoint(x: target.midX, y: target.midY), to: host)) === button)
            XCTAssertGreaterThanOrEqual(target.height, CGFloat(ui.font(.small)!.height(of: GameMenuTypography.menuText(button.title)) + 4))
            XCTAssertEqual(button.title, "Klar, ÅȘÆØ")
            XCTAssertEqual(button.accessibilityLabel(), "Klar, ÅȘÆØ")
            button.performClick(nil); XCTAssertTrue(activated)
            XCTAssertLessThan(back.convert(back.bounds, to: page).minX, target.minX)
            let bitmap = try XCTUnwrap(page.bitmapImageRepForCachingDisplay(in: page.bounds))
            page.displayIgnoringOpacity(page.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)))
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: root.appendingPathComponent(".build/latin-glyphs/western-native-controls.png"))
        }
    }

    func testWesternGlyphAtlasAndControlStates() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let typography = try XCTUnwrap(GameMenuTypography(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings")))
        let output = root.appendingPathComponent(".build/latin-glyphs")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let samples = ["ABCDEFGHIJKLMNOPQRSTUVWXYZ", "ÆØÅ ÄÖÜ ÀÁÂÃ ÇÈÉÊË ÌÍÎÏ ÑÒÓÔÕ ÙÚÛÝ", "Œ Ð Þ Ł Đ Ħ Ŧ Ŋ ẞ İ Ĳ ¡¿", "ĀĂĄĆĈĊČ ĎĒĖĘĚ ĞĢĨ ĶĹĻĽ ŃŅŇ ŐŔŘ ŚŞŠ ŢŤŰŲŹŻŽ ȘȚ",
                       "abcdefghijklmnopqrstuvwxyz", "æøå äöü àáâã çèéêë ìíîï ñòóôõ ùúûýÿ œðþłđħŧŋßı"]
        let width = 1800, height = 1000
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 0.035, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
        var y: CGFloat = 24
        for face in GameMenuTypography.Face.allCases {
            for text in samples {
                let font = try XCTUnwrap(typography.font(face))
                let bounds = font.verticalBounds(of: text)
                typography.draw(text, face: face, at: CGPoint(x: 24, y: y - CGFloat(bounds.top * 2)), scale: 2, in: context,
                                palette: face == .small ? .blue : .green)
                y += CGFloat(font.height(of: text, scale: 2)) + 14
            }
        }
        GamePixelTypography.draw("ÆØÅ Ç É Ñ Œ Ł Ð Þ ẞ ȘȚ", in: CGRect(x: 24, y: y, width: 1200, height: 50),
            context: context, typography: nil, maximumScale: 3, alignment: .left, bitmapOnly: true)
        let atlas = try XCTUnwrap(context.makeImage())
        try XCTUnwrap(NSBitmapImageRep(cgImage: atlas).representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("western-latin.png"))
        XCTAssertEqual(GameMenuTypography.menuText("Æøå naïve Straße A\u{030A}"), "ÆØÅ NAÏVE STRAẞE Å")
        XCTAssertEqual(GameMenuTypography.menuText("Ω"), "?")
        for character in BitmapLatinGlyphs.characters {
            XCTAssertNotNil(GamePixelTypography.bitmapGlyph(for: character), "Compact glyph: \(character)")
        }
        for width: CGFloat in [390, 834, 1280] {
            let actions: [GameFrontEnd.Action] = [.init("back", "Tilbake", backNavigation: true),
                .init("selected", "Prøv igjen", selected: true), .init("disabled", "Continuer", enabled: false),
                .init("ready", "Klar, ÆØÅ", primary: true)]
            let page = GameFrontEnd.Page(title: "ÆØÅ – FÉLICITATIONS", subtitle: "ÅSA v ÉRIC", footer: actions, footerColumns: 2)
            let layout = GameFrontEnd.layout(page, width: width, minimumHeight: 700)
            for target in layout.targets {
                XCTAssertEqual(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)), target.action.enabled ? target.action.id : nil)
                XCTAssertTrue(CGRect(origin: .zero, size: layout.size).contains(target.frame))
            }
            let render = try XCTUnwrap(CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height), bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            render.translateBy(x: 0, y: layout.size.height); render.scaleBy(x: 1, y: -1)
            GameFrontEnd.draw(page, layout: layout, typography: typography, highlighted: "selected", in: render)
            let image = try XCTUnwrap(render.makeImage())
            try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("western-controls-\(Int(width)).png"))
        }
    }
}
#endif
