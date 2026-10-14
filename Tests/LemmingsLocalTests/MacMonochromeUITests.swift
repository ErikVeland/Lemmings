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
            @MainActor func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
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
            let initial = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets)
            let config = initial.configuration
            var simulation = try ClassicDOSSimulation(terrain: initial.terrain,
                configuration: .init(totalLemmings: config.totalLemmings, requiredToSave: config.requiredToSave,
                    timeLimitTicks: config.timeLimitTicks, initialReleaseRate: config.initialReleaseRate,
                    entrances: config.entrances, triggers: config.triggers,
                    initialSkills: Dictionary(uniqueKeysWithValues: ClassicSkill.allCases.map { ($0, 20) }),
                    maximumX: config.maximumX, maximumY: config.maximumY, mechanics: config.mechanics),
                destructionMasks: initial.comparisonDestructionMasks)
            for _ in 0..<140 { _ = simulation.tick() }
            let playfield = PlayfieldView(frame: CGRect(x: 0, y: 0, width: 960, height: 480))
            playfield.interfaceArtwork = colour
            playfield.classicScene = rendered
            playfield.macArtwork = mono
            playfield.macScene = try ClassicMacScene(level: level, rendered: rendered, artwork: mono, groundSet: ground)
            playfield.assets = assets
            playfield.selectedSkill = { 7 }
            playfield.palette = try ClassicLemmingPalette.inLevelVGA(terrainPalette: ground.terrainPalette)
            playfield.session = ClassicSession(simulation: simulation, width: rendered.width, height: rendered.height)
            playfield.viewport.zoom = 3
            playfield.viewport.levelSize = CGSize(width: rendered.width, height: rendered.height)
            playfield.viewport.viewSize = playfield.bounds.size
            playfield.viewport.center(on: Double(level.startX) + 160)
            try capture(playfield, to: output.appendingPathComponent("gameplay.png"))
            let original = try bitmap(playfield)
            let target = try XCTUnwrap(simulation.lemmings.first(where: \.isActive))
            let point = CGPoint(x: target.foot.x, y: target.foot.y)
            let inputTarget = playfield.lemming(at: point)?.id
            XCTAssertNotNil(inputTarget)
            var patterns = Set<Data>()
            for kind in ClassicMonochromeBackpack.Kind.allCases {
                var marked = simulation
                if kind != .floater { XCTAssertEqual(marked.assign(.climber, to: target.id), .assigned) }
                if kind != .climber { XCTAssertEqual(marked.assign(.floater, to: target.id), .assigned) }
                playfield.session = ClassicSession(simulation: marked, width: rendered.width, height: rendered.height)
                playfield.showClassicSkillBackpacks = true
                let visible = try bitmap(playfield)
                XCTAssertNotEqual(visible, original)
                patterns.insert(visible)
                XCTAssertEqual(playfield.lemming(at: point)?.id, inputTarget)
                try capture(playfield, to: output.appendingPathComponent("gameplay-\(kind.rawValue).png"))
                playfield.showClassicSkillBackpacks = false
                XCTAssertEqual(try bitmap(playfield), original)
                playfield.showClassicSkillBackpacks = true
                XCTAssertEqual(try bitmap(playfield), visible)
            }
            XCTAssertEqual(patterns.count, 3)
            playfield.session = ClassicSession(simulation: simulation, width: rendered.width, height: rendered.height)
            XCTAssertEqual(try bitmap(playfield), original)
            try backpackSheet(artwork: mono, to: output.appendingPathComponent("backpacks.png"))
            try backpackSheet(artwork: mono, to: output.appendingPathComponent("backpack-poses.png"), extended: true)
            let santa = try ClassicMacArtwork(directory: artworkRoot.appendingPathComponent("monochrome/xmas"))
            try backpackSheet(artwork: santa, to: output.appendingPathComponent("backpack-santa.png"), extended: true)
        }
    }

    @MainActor private func backpackSheet(artwork: ClassicMacArtwork, to output: URL, extended: Bool = false) throws {
        let poses: [(ClassicLemmingPose, Bool)] = extended
            ? [(.walking, false), (.walking, true), (.climbing, false), (.floating, false), (.digging, false), (.postClimb, true)]
            : [(.walking, false), (.walking, true)]
        let height = poses.count * 160 + 40
        let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 760, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.current?.imageInterpolation = .none
        NSColor.black.setFill()
        CGRect(x: 0, y: 0, width: 760, height: height).fill()
        let kinds: [ClassicMonochromeBackpack.Kind?] = [nil, .climber, .floater, .both]
        for (column, kind) in kinds.enumerated() {
            GameControlText.draw(kind?.rawValue.uppercased() ?? "NONE",
                in: CGRect(x: column * 190, y: height - 32, width: 190, height: 28), alignment: .center)
            for (row, entry) in poses.enumerated() {
                let (pose, left) = entry
                let source = try XCTUnwrap(artwork.lemming(pose: pose, left: left, tick: 0))
                let frame = ClassicMonochromeBackpack.render(source, kind: kind, pose: pose, left: left)
                let image = try XCTUnwrap(frame.makeNSImage())
                let centre = CGFloat(column * 190 + 95)
                let scale = floor(min(6, 120 / CGFloat(frame.height), 180 / CGFloat(frame.width)))
                let size = CGSize(width: CGFloat(frame.width) * scale, height: CGFloat(frame.height) * scale)
                let bottom = CGFloat(height - 40 - (row + 1) * 160)
                let rect = CGRect(x: centre - size.width / 2, y: bottom + 24 + (132 - size.height) / 2,
                    width: size.width, height: size.height)
                image.draw(in: rect, from: .zero,
                    operation: .sourceOver, fraction: 1, respectFlipped: false,
                    hints: [.interpolation: NSImageInterpolation.none.rawValue])
                if column == 0 {
                    GameControlText.draw(pose.rawValue.uppercased() + (left ? " LEFT" : " RIGHT"),
                        in: CGRect(x: 0, y: bottom, width: 760, height: 20), alignment: .center)
                }
            }
        }
        try XCTUnwrap(rep.representation(using: .png, properties: [:])).write(to: output)
    }

    @MainActor private func bitmap(_ view: NSView) throws -> Data {
        let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.displayIgnoringOpacity(view.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: rep)))
        return try XCTUnwrap(rep.representation(using: .png, properties: [:]))
    }

    @MainActor private func capture(_ view: NSView, to output: URL) throws {
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.displayIgnoringOpacity(view.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)))
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output)
    }
}
#endif
