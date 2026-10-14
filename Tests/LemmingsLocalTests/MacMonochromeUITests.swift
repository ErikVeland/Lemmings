#if os(macOS)
import AppKit
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class MacMonochromeUITests: XCTestCase {
    @MainActor func testArtworkChoiceAndRenderedGameplay() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let artworkRoot = root.appendingPathComponent(".build/mac-artwork/export")
        let colour = try ClassicMacArtwork(directory: artworkRoot.appendingPathComponent("lemmings"))
        let mono = try ClassicMacArtwork(directory: artworkRoot.appendingPathComponent("monochrome/lemmings"))
        let renderer = MacInterfaceRenderer(interface: try XCTUnwrap(ClassicMacUserInterface(artwork: colour)))
        try GameMenuArtwork.withRenderer(renderer) {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1280, height: 800),
                styleMask: [], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 1280, height: 800))
            let previous = GameScreen.shared.gameWindow
            GameScreen.shared.gameWindow = window
            defer {
                GameScreen.shared.dismissAll()
                GameScreen.shared.gameWindow = previous
                window.close()
            }
            let options = ClassicSettingsOptions.available(hasDOSData: true, hasAmigaDisk: true,
                hasMacintoshDisk: true, moduleCount: 0, hasMacintoshMonochromeArtwork: true)
            let page = SettingsWindow(settings: ClassicSettings(), options: options)
            page.show()
            let host = try XCTUnwrap(window.contentView)
            func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
            host.layoutSubtreeIfNeeded()
            let tab = try XCTUnwrap(descendants(host).compactMap { $0 as? GameTabButton }
                .first { $0.title.lowercased() == "graphics" })
            tab.performClick(nil)
            host.layoutSubtreeIfNeeded()
            let picker = try XCTUnwrap(descendants(host).compactMap { $0 as? GamePopUpButton }
                .first { $0.itemTitles.contains("Macintosh (1-bit)") })
            picker.performClick(nil)
            host.layoutSubtreeIfNeeded()
            let choice = try XCTUnwrap(descendants(host).compactMap { $0 as? GameActionButton }
                .first { $0.title == "Macintosh (1-bit)" })
            XCTAssertGreaterThanOrEqual(choice.bounds.height, 28)
            XCTAssertTrue(host.hitTest(choice.convert(CGPoint(x: choice.bounds.midX, y: choice.bounds.midY), to: host)) === choice)
            choice.performClick(nil)
            XCTAssertEqual(page.current.graphics, .macintoshMonochrome)
            host.layoutSubtreeIfNeeded()
            let output = root.appendingPathComponent(".build/mac-monochrome-captures")
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try capture(host, to: output.appendingPathComponent("settings.png"))

            let directory = root.appendingPathComponent("Content/lemming1.pc")
            let campaign = try ClassicDataSet.detect(directory: directory).campaign
            let level = try XCTUnwrap(campaign.levels.first).level
            let assets = try ClassicMainDATAssets.load(from: directory)
            let ground = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
            let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: nil)
            var simulation = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets)
            for _ in 0..<140 { _ = simulation.tick() }
            let playfield = PlayfieldView(frame: CGRect(x: 0, y: 0, width: 960, height: 480))
            playfield.interfaceArtwork = colour
            playfield.classicScene = rendered
            playfield.macArtwork = mono
            playfield.macScene = try ClassicMacScene(level: level, rendered: rendered, artwork: mono, groundSet: ground)
            playfield.assets = assets
            playfield.palette = try ClassicLemmingPalette.inLevelVGA(terrainPalette: ground.terrainPalette)
            playfield.session = ClassicSession(simulation: simulation, width: rendered.width, height: rendered.height)
            playfield.viewport.zoom = 3
            playfield.viewport.levelSize = CGSize(width: rendered.width, height: rendered.height)
            playfield.viewport.viewSize = playfield.bounds.size
            playfield.viewport.center(on: Double(level.startX) + 160)
            try capture(playfield, to: output.appendingPathComponent("gameplay.png"))
        }
    }

    @MainActor private func capture(_ view: NSView, to output: URL) throws {
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.displayIgnoringOpacity(view.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)))
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output)
    }
}
#endif
