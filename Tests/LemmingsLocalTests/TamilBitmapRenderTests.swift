#if os(macOS)
import AppKit
import LemmingsGameArt
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class TamilBitmapRenderTests: XCTestCase {
    private var output: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/tamil-font-renders")
    }

    private func typography() throws -> GameMenuTypography {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var banks: [String: [Any]] = [:]
        for (bank, width, height) in [("1301", 12, 18), ("1302", 16, 20)] {
            var records: [Any] = [NSNull()]
            for value in 33...126 {
                let character = Character(String(Unicode.Scalar(value)!))
                let source = GamePixelTypography.bitmapGlyph(for: character)
                    ?? GamePixelTypography.bitmapGlyph(for: "?")!
                var pixels = [UInt8](repeating: 0, count: width * height * 4)
                let scaleX = width == 12 ? 2 : 3
                for y in 0..<min(7, source.height) {
                    for x in 0..<min(5, source.width) where source.rgba[(y * source.width + x) * 4 + 3] != 0 {
                        for dy in 0..<2 {
                            for dx in 0..<scaleX {
                                let p = ((1 + y * 2 + dy) * width + x * scaleX + dx) * 4
                                pixels[p] = 48; pixels[p + 1] = 128; pixels[p + 2] = 208; pixels[p + 3] = 255
                            }
                        }
                    }
                }
                let file = "\(bank)-\(value).rgba"
                try Data(pixels).write(to: folder.appendingPathComponent(file))
                records.append(["x": 0, "y": 0, "width": width, "height": height, "file": file])
            }
            banks[bank] = records
        }
        let manifest: [String: Any] = ["version": 1, "banks": banks, "objects": [:],
                                       "names": ["1301": "Charset1", "1302": "Charset2"]]
        try JSONSerialization.data(withJSONObject: manifest).write(to: folder.appendingPathComponent("manifest.json"))
        return try XCTUnwrap(GameMenuTypography(directory: folder))
    }

    private func context(width: Int, height: Int) throws -> CGContext {
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
        return context
    }

    private func alphaCount(_ context: CGContext, outside box: CGRect? = nil) -> Int {
        guard let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else { return 0 }
        var count = 0
        for y in 0..<context.height {
            for x in 0..<context.width where pixels[y * context.bytesPerRow + x * 4 + 3] != 0 {
                if box == nil || !box!.contains(CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)) { count += 1 }
            }
        }
        return count
    }

    private func save(_ context: CGContext, name: String) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(context.makeImage()))
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent(name))
    }

    func testCompleteSyllablesSurviveWrappingTruncationAndCanonicalForms() throws {
        let typography = try typography()
        let text = "தமிழ் க்ஷௌ ஸ்ரீ"
        XCTAssertEqual(GameMenuTypography.menuText(text), text)
        XCTAssertEqual(GameMenuTypography.menuText("கெ\u{0BBE}"), "கொ")
        XCTAssertEqual(BitmapTamilGlyphs.sequences(in: "க்ஷௌ"), ["க்ஷௌ"])
        XCTAssertEqual(BitmapTamilGlyphs.sequences(in: "ஸ்ரீ"), ["ஸ்ரீ"])
        XCTAssertEqual(GamePixelTypography.lines("தமிழ்…", width: 300), ["தமிழ்..."])
        for face in GameMenuTypography.Face.allCases {
            let font = try XCTUnwrap(typography.font(face))
            XCTAssertTrue(font.covers(text))
            XCTAssertEqual(font.width(of: "ABC XYZ"), 7 * font.cellWidth)
            XCTAssertEqual(font.layout("க்ஷௌ").count, 1)
            let word = "க்ஷௌஸ்ரீதமிழ்க்ஷௌஸ்ரீதமிழ்"
            let width = CGFloat(max(font.width(of: "க்ஷௌ"), font.width(of: "ஸ்ரீ")) + 4)
            let lines = GameTextLayout.lines(word, width: width, face: face, font: font)
            XCTAssertGreaterThan(lines.count, 1)
            XCTAssertEqual(lines.joined(), word)
            for line in lines {
                XCTAssertLessThanOrEqual(font.width(of: line), Int(width))
                XCTAssertTrue(font.covers(line))
                XCTAssertTrue(BitmapTamilGlyphs.sequences(in: line).allSatisfy(BitmapTamilGlyphs.supports))
            }
            let limit = CGFloat(font.width(of: "க்ஷௌ..."))
            let truncated = GameTextLayout.truncated(word, width: limit, face: face, font: font)
            XCTAssertTrue(truncated.hasSuffix("..."))
            XCTAssertLessThanOrEqual(font.width(of: truncated), Int(limit))
            let prefix = String(truncated.dropLast(3))
            let source = BitmapTamilGlyphs.sequences(in: word)
            XCTAssertEqual(prefix, source.prefix(BitmapTamilGlyphs.sequences(in: prefix).count).joined())
        }
    }

    func testTamilInkAndSplitSemanticRunsRemainInsideExactBounds() throws {
        let typography = try typography()
        let sample = "தமிழ் கௌ க்ஷௌ ஸ்ரீ"
        for face in GameMenuTypography.Face.allCases {
            let font = try XCTUnwrap(typography.font(face))
            let horizontal = font.horizontalBounds(of: sample), vertical = font.verticalBounds(of: sample)
            let width = horizontal.right - horizontal.left, height = vertical.bottom - vertical.top
            var opaque: Set<Int> = []
            for item in font.layout(sample) {
                guard let glyph = item.glyph else { continue }
                for y in 0..<glyph.height {
                    for x in 0..<glyph.width where glyph.rgba[(y * glyph.width + x) * 4 + 3] != 0 {
                        let px = item.x + glyph.x + x - horizontal.left
                        let py = glyph.y + y - vertical.top
                        XCTAssertTrue((0..<width).contains(px)); XCTAssertTrue((0..<height).contains(py))
                        opaque.insert(py * width + px)
                    }
                }
            }
            let box = CGRect(x: 24, y: 24, width: width, height: height)
            let render = try context(width: width + 48, height: height + 48)
            typography.menuLine(sample, in: box, context: render, face: face, alignment: .left)
            XCTAssertEqual(alphaCount(render), opaque.count)
            XCTAssertEqual(alphaCount(render, outside: box), 0)
            try save(render, name: "tamil-exact-\(face.rawValue).png")
            let single = try context(width: 300, height: 100)
            let split = try context(width: 300, height: 100)
            let region = CGRect(x: 20, y: 20, width: 260, height: 60)
            GameSemanticText.draw([.init("க்ஷௌ", .green)], in: region, typography: typography, face: face, context: single)
            GameSemanticText.draw([.init("க்ஷ", .green), .init("ௌ", .blue)], in: region, typography: typography, face: face, context: split)
            XCTAssertGreaterThan(alphaCount(single), 0)
            XCTAssertEqual(alphaCount(single), alphaCount(split))
        }
    }

    func testCompactFallbackDrawsFullTamilSequencesWithoutCommercialAssets() throws {
        let sample = "தமிழ் க்ஷௌ ஸ்ரீ"
        let layout = GamePixelTypography.layout(sample)
        XCTAssertTrue(layout.contains { $0.sequence == "க்ஷௌ" && $0.glyph != nil })
        XCTAssertTrue(layout.filter { $0.sequence != " " }.allSatisfy { $0.glyph != nil })
        XCTAssertNotEqual(GamePixelTypography.width(of: "க்ஷௌ"), "க்ஷௌ".count * 6 - 1)
        let bounds = GamePixelTypography.verticalBounds(of: sample)
        let width = GamePixelTypography.width(of: sample)
        let horizontal = GamePixelTypography.horizontalBounds(of: sample)
        var opaque: Set<Int> = []
        for item in layout {
            guard let glyph = item.glyph, let mask = GamePixelTypography.monochromeMask(forSequence: item.sequence) else { continue }
            for y in 0..<glyph.height {
                for x in 0..<glyph.width where mask[y * glyph.width + x] != 0 {
                    opaque.insert((glyph.y + y - bounds.top) * width + item.x + glyph.x + x - horizontal.left)
                }
            }
        }
        let box = CGRect(x: 16, y: 16, width: width, height: bounds.bottom - bounds.top)
        let render = try context(width: width + 32, height: bounds.bottom - bounds.top + 32)
        GamePixelTypography.draw(sample, in: box, context: render, typography: nil, maximumScale: 1, bitmapOnly: true)
        XCTAssertGreaterThan(alphaCount(render), 0)
        XCTAssertEqual(alphaCount(render), opaque.count)
        XCTAssertEqual(alphaCount(render, outside: box), 0)
        try save(render, name: "tamil-compact-fallback.png")
    }

    func testCompactTamilTintExcludesTheOutlineAndPreservesLatinInk() throws {
        var excluded = 0, retained = 0
        for sequence in BitmapTamilGlyphs.sequences(in: "தமிழ்க்ஷௌஸ்ரீ") {
            let glyph = try XCTUnwrap(GamePixelTypography.bitmapGlyph(forSequence: sequence))
            let mask = try XCTUnwrap(GamePixelTypography.monochromeMask(forSequence: sequence))
            for pixel in 0..<(glyph.width * glyph.height) {
                let index = pixel * 4
                let outline = glyph.rgba[index + 3] != 0 && glyph.rgba[index] == 0
                    && glyph.rgba[index + 1] == 0 && glyph.rgba[index + 2] == 64
                if outline { XCTAssertEqual(mask[pixel], 0); excluded += 1 }
                else { XCTAssertEqual(mask[pixel], glyph.rgba[index + 3]); retained += mask[pixel] == 0 ? 0 : 1 }
            }
        }
        XCTAssertGreaterThan(excluded, 0)
        XCTAssertGreaterThan(retained, 0)
        let latin = try XCTUnwrap(GamePixelTypography.bitmapGlyph(for: "A"))
        let mask = try XCTUnwrap(GamePixelTypography.monochromeMask(forSequence: "A"))
        XCTAssertEqual(Array(mask), stride(from: 3, to: latin.rgba.count, by: 4).map { latin.rgba[$0] })
    }

    func testSharedTamilMenusRetainStatesCaptionsAndTargetsAtThreeWidths() throws {
        let typography = try typography()
        let actions: [GameFrontEnd.Action] = [.init("back", "திரும்பு", backNavigation: true),
            .init("retry", "மீண்டும் முயற்சி", selected: true), .init("disabled", "தொடர்", enabled: false),
            .init("ready", "தயார், தமிழ்", primary: true)]
        for width: CGFloat in [390, 834, 1280] {
            for result in [false, true] {
                var page = GameFrontEnd.Page(title: "தமிழ்", subtitle: "க்ஷௌ ஸ்ரீ தமிழ்", details: ["கா கி கீ கு கூ கெ கே கை கொ கோ கௌ க்"],
                    footer: actions, footerColumns: 2)
                page.result = result
                let layout = GameFrontEnd.layout(page, width: width, minimumHeight: 700)
                let canvas = CGRect(origin: .zero, size: layout.size)
                for target in layout.targets {
                    XCTAssertTrue(canvas.contains(target.frame))
                    XCTAssertEqual(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)),
                        target.action.enabled ? target.action.id : nil)
                    XCTAssertEqual(target.action.title, actions.first { $0.id == target.action.id }?.title)
                    let font = try XCTUnwrap(typography.font(.small))
                    let captionWidth = target.frame.width - (target.action.primary ? 48 : 24)
                    let lines = GameTextLayout.lines(target.action.title, width: captionWidth, font: font)
                    XCTAssertLessThanOrEqual(CGFloat(lines.count * font.height(of: target.action.title)), target.frame.height - 4)
                    XCTAssertTrue(lines.allSatisfy { CGFloat(font.width(of: $0)) <= captionWidth })
                }
                for (index, first) in layout.targets.enumerated() {
                    for second in layout.targets.dropFirst(index + 1) { XCTAssertFalse(first.frame.intersects(second.frame)) }
                }
                let render = try context(width: Int(layout.size.width), height: Int(layout.size.height))
                GameFrontEnd.draw(page, layout: layout, typography: typography, highlighted: "retry", in: render)
                try save(render, name: "tamil-\(Int(width))-\(result ? "result" : "menu").png")
            }
        }
    }

    func testRealMacFontsReserveTamilMarksAndKeepInkInsideControls() throws {
        let root = output.deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appendingPathComponent(".build/mac-artwork/export/lemmings")
        guard FileManager.default.fileExists(atPath: folder.appendingPathComponent("manifest.json").path) else {
            throw XCTSkip("Local original Macintosh artwork is absent. Data-independent Tamil render checks remain available.")
        }
        let typography = try XCTUnwrap(GameMenuTypography(directory: folder))
        let sample = "தமிழ் ஊ ஈ கௌ க்ஷௌ ஸ்ரீ"
        for face in GameMenuTypography.Face.allCases {
            let font = try XCTUnwrap(typography.font(face))
            XCTAssertGreaterThanOrEqual(GameTextLayout.glyphHeight(of: sample, face: face), CGFloat(font.height(of: sample)))
            XCTAssertGreaterThanOrEqual(GameTextLayout.width(of: sample, face: face), CGFloat(font.width(of: sample)))
            let width = font.width(of: sample, scale: 2), height = font.height(of: sample, scale: 2)
            let box = CGRect(x: 24, y: 24, width: width, height: height)
            let ink = try context(width: width + 48, height: height + 48)
            typography.menuLine(sample, in: box, context: ink, face: face, scale: 2, alignment: .left)
            XCTAssertGreaterThan(alphaCount(ink), 0)
            XCTAssertEqual(alphaCount(ink, outside: box), 0)
            try save(ink, name: "tamil-real-mac-\(face.rawValue).png")
        }
        let page = GameFrontEnd.Page(title: sample, subtitle: sample,
            footer: [.init("back", "திரும்பு", backNavigation: true), .init("ready", sample, primary: true)], footerColumns: 2)
        let large = try XCTUnwrap(typography.font(.large)), small = try XCTUnwrap(typography.font(.small))
        for width: CGFloat in [390, 834, 1280] {
            let layout = GameFrontEnd.layout(page, width: width, minimumHeight: 700)
            let titleScale = layout.heading.width >= 580 && layout.heading.height >= 52 ? 2 : 1
            XCTAssertLessThanOrEqual(GameTextLayout.height(sample, width: layout.heading.width, face: .large,
                scale: titleScale, font: large), layout.heading.height)
            for target in layout.targets {
                let caption = target.frame.insetBy(dx: target.action.primary ? 24 : 12, dy: 2)
                let lines = GameTextLayout.lines(target.action.title, width: caption.width, font: small)
                XCTAssertLessThanOrEqual(CGFloat(lines.count * small.height(of: target.action.title)), caption.height)
            }
            let render = try context(width: Int(layout.size.width), height: Int(layout.size.height))
            GameFrontEnd.draw(page, layout: layout, typography: typography, in: render)
            try save(render, name: "tamil-real-mac-menu-\(Int(width)).png")
        }
    }

    func testInstalledTamilHelpAndActionsRenderFromTheBundle() throws {
        let root = output.deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appendingPathComponent(".build/mac-artwork/export/lemmings")
        guard let typography = GameMenuTypography(directory: folder) else {
            throw XCTSkip("Local original Macintosh artwork is absent.")
        }
        let resource = root.appendingPathComponent("Sources/NxlvKit/Resources/Localization.bundle")
        let language = InterfaceLocalisation(bundle: try XCTUnwrap(Bundle(url: resource)), preferredLanguages: ["ta-IN"])
        XCTAssertEqual(language.language, "ta")
        let help = language.text("Tap a lemming to assign the selected skill. Drag a finger to pan. Pinch to zoom.")
        let page = GameFrontEnd.Page(title: language.text("Help"), subtitle: language.text("Paused"),
            details: [help], footer: [.init("back", language.text("Back"), backNavigation: true),
                .init("retry", language.text("Retry"), selected: true),
                .init("continue", language.text("Continue"), enabled: false),
                .init("ready", language.text("Ready"), primary: true)], footerColumns: 2)
        let font = try XCTUnwrap(typography.font(.small))
        XCTAssertTrue(font.covers(GameMenuTypography.menuText(help)))
        for width: CGFloat in [390, 834, 1280] {
            let layout = GameFrontEnd.layout(page, width: width, minimumHeight: 700)
            for target in layout.targets {
                let caption = target.frame.insetBy(dx: target.action.primary ? 24 : 12, dy: 2)
                XCTAssertLessThanOrEqual(GameTextLayout.height(target.action.title, width: caption.width, font: font), caption.height)
                XCTAssertEqual(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)),
                    target.action.enabled ? target.action.id : nil)
            }
            let render = try context(width: Int(layout.size.width), height: Int(layout.size.height))
            GameFrontEnd.draw(page, layout: layout, typography: typography, in: render)
            try save(render, name: "tamil-installed-help-\(Int(width)).png")
        }
    }

    @MainActor func testClassicTamilOverlayTargetsAndPanelStatusRenderAtThreeWidths() throws {
        _ = NSApplication.shared
        let root = output.deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appendingPathComponent(".build/mac-artwork/export/lemmings")
        guard FileManager.default.fileExists(atPath: folder.appendingPathComponent("manifest.json").path) else {
            throw XCTSkip("Local original Macintosh artwork is absent.")
        }
        let artwork = try ClassicMacArtwork(directory: folder)
        for width: CGFloat in [390, 834, 1280] {
            let field = PlayfieldView(frame: CGRect(x: 0, y: 0, width: width, height: 700))
            field.interfaceArtwork = artwork
            field.phase = .briefing
            field.overlayTitle = "தமிழ் க்ஷௌ ஸ்ரீ"
            field.overlayLines = ["தயார், க்ஷௌ ஸ்ரீ", "மீண்டும் முயல்", "தொடர்"]
            field.overlayTurnInitials = "க்ஷௌ ஸ்ரீ"
            field.overlayHighlight = 0
            var selected: Int?
            field.onSelectOverlayLine = { selected = $0 }
            let bitmap = try XCTUnwrap(field.bitmapImageRepForCachingDisplay(in: field.bounds))
            field.displayIgnoringOpacity(field.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)))
            let targets = field.accessibleControls(owner: field).compactMap { $0 as? GameAccessibleElement }.filter { $0.press != nil }
            XCTAssertEqual(targets.count, 3)
            XCTAssertEqual(targets.map { $0.accessibilityLabel() }, field.overlayLines)
            for target in targets { XCTAssertTrue(field.bounds.contains(target.localFrame)) }
            targets[1].press?()
            XCTAssertEqual(selected, 1)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("tamil-native-classic-\(Int(width)).png"))
            let panel = PanelView(frame: CGRect(x: 0, y: 0, width: width, height: 160))
            panel.interfaceArtwork = artwork
            panel.isMenuMode = true
            panel.statusText = "தமிழ் க்ஷௌ ஸ்ரீ"
            panel.progressText = "தயார்"
            let bar = try XCTUnwrap(panel.bitmapImageRepForCachingDisplay(in: panel.bounds))
            panel.displayIgnoringOpacity(panel.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bar)))
            try XCTUnwrap(bar.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("tamil-native-classic-panel-\(Int(width)).png"))
        }
    }

    @MainActor func testNativeTamilControlKeepsAccessibleCaptionAndClickTarget() throws {
        _ = NSApplication.shared
        let typography = try typography()
        try GameMenuArtwork.withRenderer(MacInterfaceRenderer(interface: typography.interface)) {
            let page = GameMenuPage(title: "தமிழ்", subtitle: "க்ஷௌ ஸ்ரீ")
            page.frame = CGRect(x: 0, y: 0, width: 900, height: 700)
            let host = NSView(frame: page.bounds); host.addSubview(page)
            var activated = false
            let button = page.addPrimaryAction("தயார், தமிழ்") { activated = true }
            let back = page.addSecondaryAction("திரும்பு") {}
            page.layoutSubtreeIfNeeded()
            let target = button.convert(button.bounds, to: page)
            XCTAssertTrue(page.bounds.contains(target))
            XCTAssertTrue(page.hitTest(page.convert(CGPoint(x: target.midX, y: target.midY), to: host)) === button)
            XCTAssertEqual(button.title, "தயார், தமிழ்")
            XCTAssertEqual(button.accessibilityLabel(), "தயார், தமிழ்")
            XCTAssertGreaterThanOrEqual(target.height, typography.height(of: button.title, face: .small, scale: 1) + 4)
            XCTAssertLessThan(back.convert(back.bounds, to: page).minX, target.minX)
            button.performClick(nil); XCTAssertTrue(activated)
            let bitmap = try XCTUnwrap(page.bitmapImageRepForCachingDisplay(in: page.bounds))
            page.displayIgnoringOpacity(page.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)))
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("tamil-native-controls.png"))
        }
    }

    @MainActor func testTamilEditorCaretHitPositionsAndLargeHintWrappingShareBitmapMetrics() throws {
        _ = NSApplication.shared
        let typography = try typography()
        try GameMenuArtwork.withRenderer(MacInterfaceRenderer(interface: typography.interface)) {
            let font = try XCTUnwrap(typography.font(.small))
            let editor = GameFieldEditor(frame: CGRect(x: 0, y: 0, width: 600, height: 48))
            editor.prepare()
            editor.string = "Aக்ஷௌதமிழ்"
            let plain = GameMenuTypography.menuText(editor.string)
            let bearing = font.horizontalBounds(of: plain).left
            let advance = font.layout(plain).reduce(0) { $0 + $1.advance }
            XCTAssertEqual(editor.bitmapInsertionX(atUTF16: (editor.string as NSString).length), CGFloat(advance))
            var offset = 0, previous: CGFloat = -1
            for character in editor.string {
                let x = editor.bitmapInsertionX(atUTF16: offset)
                XCTAssertGreaterThan(x, previous)
                XCTAssertEqual(editor.bitmapInsertionIndex(atX: x), offset)
                XCTAssertEqual(editor.characterIndexForInsertion(at: CGPoint(x: editor.textContainerOrigin.x - CGFloat(bearing) + x, y: 24)), offset)
                previous = x
                offset += String(character).utf16.count
            }
            let range = NSRange(location: 1, length: "க்ஷௌ".utf16.count)
            var actual = NSRange(location: NSNotFound, length: 0)
            let caret = editor.firstRect(forCharacterRange: range, actualRange: &actual)
            XCTAssertEqual(actual, range)
            XCTAssertEqual(caret.width, editor.bitmapInsertionX(atUTF16: NSMaxRange(range)) - editor.bitmapInsertionX(atUTF16: range.location))
            editor.setSelectedRange(range)
            let image = try XCTUnwrap(editor.bitmapImageRepForCachingDisplay(in: editor.bounds))
            editor.displayIgnoringOpacity(editor.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: image)))
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try XCTUnwrap(image.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("tamil-native-editor.png"))

            let hint = HintBitmapText(face: .large)
            hint.stringValue = "தமிழ் க்ஷௌ ஸ்ரீ தமிழ் க்ஷௌ ஸ்ரீ"
            let large = try XCTUnwrap(typography.font(.large))
            let width: CGFloat = 180
            let expected = GameTextLayout.lines(hint.stringValue, width: width, face: .large, font: large)
            XCTAssertGreaterThan(expected.count, 1)
            XCTAssertEqual(hint.lines(width: width), expected)
            XCTAssertGreaterThanOrEqual(hint.requiredHeight(width: width), CGFloat(expected.count * large.height(of: hint.stringValue)))
            XCTAssertEqual(hint.accessibilityValue() as? String, hint.stringValue)
        }
    }

    @MainActor func testTamilReplayRowsReserveTheWholeFontHeight() throws {
        _ = NSApplication.shared
        let typography = try typography()
        try GameMenuArtwork.withRenderer(MacInterfaceRenderer(interface: typography.interface)) {
            let panel = ReplaySkillPanel(frame: .zero)
            panel.update(stocks: [.init(name: "BUILDER", count: "7")], uses: [.init(tick: 7, name: "BUILDER")], tick: 7)
            let latin = panel.logicalSize
            panel.update(stocks: [.init(name: "கூ கீ க்ஷௌ", count: "7")], uses: [.init(tick: 7, name: "கூ கீ க்ஷௌ")], tick: 7, title: "தமிழ்")
            let tamil = panel.logicalSize
            let font = try XCTUnwrap(typography.font(.small))
            if font.height(of: "கூ கீ க்ஷௌ") > 18 { XCTAssertGreaterThan(tamil.height, latin.height) }
            XCTAssertGreaterThanOrEqual(tamil.width, CGFloat(font.width(of: "கூ கீ க்ஷௌ") + 42))
            panel.frame = CGRect(origin: .zero, size: tamil)
            let bitmap = try XCTUnwrap(panel.bitmapImageRepForCachingDisplay(in: panel.bounds))
            panel.displayIgnoringOpacity(panel.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)))
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("tamil-replay-panel.png"))
        }
    }
}
#endif
