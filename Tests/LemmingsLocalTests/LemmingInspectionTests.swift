#if os(macOS)
import AppKit
import Foundation
import LemmingsAppCore
import LemmingsGameArt
import ImageIO
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class LemmingInspectionPageTests: XCTestCase {
    @MainActor func testPausedHoverIsImmediateCachedAndPassesInputThrough() throws {
        _ = NSApplication.shared
        var attributes = [UInt16](repeating: 0, count: 128 * 64)
        for y in 48..<64 { for x in 0..<128 { attributes[y * 128 + x] = 0x20 } }
        let initial = try Lemmings3Runtime(configuration: .init(width: 128, height: 64,
            attributes: attributes, entrance: .init(x: 20, y: 20), exits: [.init(x: 110, y: 46)],
            total: 3, releaseInterval: 10, releaseDelay: 0))
        var game = initial
        for _ in 0..<40 { game.step() }
        let id = try XCTUnwrap(game.lemmings.first?.id)
        let snapshot = try LemmingInspection(initial: .lemmings3(initial), current: .lemmings3(game), commands: [
            .init(tick: 20, action: "walker", lemming: id), .init(tick: 25, action: "jumper", lemming: id)
        ])
        let hash = L3RunRecovery.stateHash(game)
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/inspection-hover-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let artworkPath = try XCTUnwrap(ProcessInfo.processInfo.environment["LEMMINGS_TEST_MENU_ARTWORK"])
        let artwork = try ClassicMacArtwork(directory: URL(fileURLWithPath: artworkPath))
        let renderer = MacInterfaceRenderer(interface: try XCTUnwrap(ClassicMacUserInterface(artwork: artwork)))
        for size in [CGSize(width: 640, height: 480), CGSize(width: 900, height: 620), CGSize(width: 1120, height: 720)] {
            let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            defer { window.close() }
            let root = NSView(frame: CGRect(origin: .zero, size: size))
            let surface = NSView(frame: root.bounds)
            root.addSubview(surface); window.contentView = root
            let keyboard = GameplayKeyboard(window: window)
            defer { keyboard.removeNavigationControl() }
            var target: Int? = id, revision = "first", captures = 0
            keyboard.inspectionHoverID = { target }
            keyboard.inspectionHoverRevision = { revision }
            keyboard.inspectionHoverSnapshot = { captures += 1; return snapshot }
            for side in ["left", "right"] {
                let pointer = CGPoint(x: side == "left" ? 24 : size.width - 24, y: size.height / 2)
                GameMenuArtwork.withRenderer(renderer) {
                    keyboard.updateInspectionHover(in: root, available: true, area: root.bounds, pointer: pointer)
                }
                let hover = try XCTUnwrap(root.subviews.compactMap { $0 as? LemmingInspectionHover }.first)
                XCTAssertFalse(hover.isHidden)
                XCTAssertTrue(root.bounds.contains(hover.frame))
                XCTAssertFalse(hover.frame.contains(pointer))
                let centre = CGPoint(x: hover.frame.midX, y: hover.frame.midY)
                XCTAssertTrue(root.hitTest(root.convert(centre, to: root.superview)) === surface)
                XCTAssertFalse(hover.acceptsFirstResponder)
                let labels = hover.subviews.compactMap { $0 as? NSTextField }
                XCTAssertTrue(labels.contains { $0.stringValue.contains(snapshot.individuals[0].name) })
                XCTAssertTrue(labels.contains { $0.stringValue.contains("Walker") && $0.stringValue.contains("Jumper") })
                for label in labels { XCTAssertTrue(hover.bounds.contains(label.frame)) }
                try GameMenuArtwork.withRenderer(renderer) {
                    let bitmap = try XCTUnwrap(hover.bitmapImageRepForCachingDisplay(in: hover.bounds))
                    hover.cacheDisplay(in: hover.bounds, to: bitmap)
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to:
                        output.appendingPathComponent("hover-\(Int(size.width))-\(side).png"))
                }
            }
            XCTAssertEqual(captures, 1)
            revision = "changed"
            keyboard.updateInspectionHover(in: root, available: true, area: root.bounds, pointer: .init(x: 24, y: 200))
            XCTAssertEqual(captures, 2)
            target = nil
            keyboard.updateInspectionHover(in: root, available: true, area: root.bounds, pointer: .init(x: 24, y: 200))
            XCTAssertTrue(root.subviews.compactMap { $0 as? LemmingInspectionHover }.allSatisfy(\.isHidden))
            target = id
            keyboard.updateInspectionHover(in: root, available: false, area: root.bounds, pointer: .init(x: 24, y: 200))
            XCTAssertEqual(captures, 2)
            XCTAssertTrue(root.subviews.compactMap { $0 as? LemmingInspectionHover }.allSatisfy(\.isHidden))
        }
        XCTAssertEqual(L3RunRecovery.stateHash(game), hash)
        XCTAssertEqual(LemmingInspectionHover.nearestID(at: .init(x: 20, y: 35), actors: [(9, 20, 40), (2, 20, 40)]), 2)
        XCTAssertNil(LemmingInspectionHover.nearestID(at: .init(x: 20, y: 10), actors: [(0, 20, 40)]))
    }

    @MainActor func testPausedNavigationHasNoInspectButton() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let root = NSView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        window.contentView = root
        let keyboard = GameplayKeyboard(window: window)
        defer { keyboard.removeNavigationControl() }
        var paused = false
        keyboard.active = { true }; keyboard.mainMenu = {}
        keyboard.inspectionAvailable = { paused }
        keyboard.inspectLemmings = {}
        for value in [false, true] {
            paused = value
            keyboard.refreshNavigationControl()
            XCTAssertFalse(root.subviews.contains { ($0 as? NSButton)?.title == "Inspect" })
            for button in root.subviews.compactMap({ $0 as? NSButton }).filter({ !$0.isHidden }) {
                XCTAssertTrue(root.bounds.contains(button.frame))
                XCTAssertTrue(root.hitTest(CGPoint(x: button.frame.midX, y: button.frame.midY)) === button)
            }
        }
    }

    @MainActor func testInspectionSettingRendersAndTogglesFromCaptionAndBox() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let artwork = try ClassicMacArtwork(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        let renderer = MacInterfaceRenderer(interface: try XCTUnwrap(ClassicMacUserInterface(artwork: artwork)))
        try GameMenuArtwork.withRenderer(renderer) {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 900, height: 720), styleMask: [], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 900, height: 720))
            let previous = GameScreen.shared.gameWindow
            GameScreen.shared.gameWindow = window
            defer { GameScreen.shared.dismissAll(); GameScreen.shared.gameWindow = previous; window.close() }
            let settings = SettingsWindow(settings: .init(), options: .available(hasDOSData: true,
                hasAmigaDisk: true, hasMacintoshDisk: true, moduleCount: 1))
            settings.show()
            let host = try XCTUnwrap(window.contentView)
            @MainActor func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
            host.layoutSubtreeIfNeeded()
            let inspect = try XCTUnwrap(descendants(host).compactMap { $0 as? GameCheckButton }
                .first { $0.title == "Inspect lemmings while paused" })
            inspect.scrollToVisible(inspect.bounds)
            host.layoutSubtreeIfNeeded()
            let output = root.appendingPathComponent(".build/inspection-hover-renders")
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            for enabled in [true, false, true] {
                XCTAssertEqual(settings.current.inspectWhilePaused, enabled)
                XCTAssertEqual(inspect.state, enabled ? .on : .off)
                for x in [10.0, inspect.bounds.midX] {
                    XCTAssertTrue(host.hitTest(inspect.convert(CGPoint(x: x, y: inspect.bounds.midY), to: host)) === inspect)
                }
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to:
                    output.appendingPathComponent("settings-\(enabled ? "on" : "off").png"))
                inspect.performClick(nil)
                host.layoutSubtreeIfNeeded()
            }
        }
    }

    @MainActor func testRenderedPagesNavigationAndInputStayInsideInspection() throws {
        _ = NSApplication.shared
        var attributes = [UInt16](repeating: 0, count: 128 * 64)
        for y in 48..<64 { for x in 0..<128 { attributes[y * 128 + x] = 0x20 } }
        var initial = try Lemmings3Runtime(configuration: .init(width: 128, height: 64,
            attributes: attributes, entrance: .init(x: 20, y: 20),
            exits: [.init(x: 110, y: 46)], total: 3, releaseInterval: 10, releaseDelay: 0))
        let empty = try LemmingInspection(initial: .lemmings3(initial), current: .lemmings3(initial), commands: [])
        let start = initial
        for _ in 0..<40 { initial.step() }
        let id = try XCTUnwrap(initial.lemmings.first?.id)
        let commands = (1...12).map { LeaderboardActionReplay.Command(tick: $0, action: "walker", lemming: id) }
        let populated = try LemmingInspection(initial: .lemmings3(start), current: .lemmings3(initial), commands: commands)
        XCTAssertTrue(initial.lemmings.contains { $0.active })
        var rescued = initial
        for _ in 0..<160 { rescued.step() }
        XCTAssertGreaterThan(rescued.saved, 0)
        let saved = try LemmingInspection(initial: .lemmings3(start), current: .lemmings3(rescued), commands: commands)
        initial.abort()
        let lost = try LemmingInspection(initial: .lemmings3(start), current: .lemmings3(initial), commands: commands)
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/inspection-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var renderer: MacInterfaceRenderer?
        if let path = ProcessInfo.processInfo.environment["LEMMINGS_TEST_MENU_ARTWORK"],
           let interface = ClassicMacUserInterface(artwork: try ClassicMacArtwork(directory: URL(fileURLWithPath: path))) {
            renderer = MacInterfaceRenderer(interface: interface)
        }
        let classicStart = try ClassicDOSSimulation(terrain: .init(width: 128, height: 64,
            solidMask: Data(repeating: 0, count: 128 * 64), steelMask: Data(repeating: 0, count: 128 * 64)),
            configuration: .init(totalLemmings: 1, requiredToSave: 1, timeLimitTicks: 1_000,
                initialReleaseRate: 50, entrances: [.init(x: 40, y: 20)],
                initialSkills: [.climber: 1, .floater: 1], maximumX: 127, maximumY: 63))
        var adventurerGame = classicStart
        while adventurerGame.lemmings.isEmpty { _ = adventurerGame.tick() }
        let adventurerID = try XCTUnwrap(adventurerGame.lemmings.first?.id)
        let adventurer = try LemmingInspection(initial: .classic(classicStart), current: .classic(adventurerGame),
            commands: [.init(tick: adventurerGame.tickCount, action: "assign", lemming: adventurerID, skill: 0),
                       .init(tick: adventurerGame.tickCount, action: "assign", lemming: adventurerID, skill: 1)])
        for (state, snapshot) in [("empty", empty), ("active", populated), ("saved", saved), ("lost", lost), ("adventurer", adventurer)] {
            for size in [CGSize(width: 640, height: 480), CGSize(width: 900, height: 620), CGSize(width: 1120, height: 720)] {
                let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                defer { window.close() }
                let page = renderer.map { GameMenuArtwork.withRenderer($0) { LemmingInspectionPage(snapshot: snapshot) } }
                    ?? LemmingInspectionPage(snapshot: snapshot)
                window.contentView = page
                page.layoutSubtreeIfNeeded()
                let navigator = DialogKeyboardNavigation()
                let buttons = navigator.controls(in: page).compactMap { $0 as? NSButton }
                XCTAssertTrue(page.controllerInitialControl === page.controllerBackButton)
                let before = try initial.inspectionHash()
                for button in buttons where button.isEnabled && !button.isHidden {
                    let rect = button.convert(button.bounds, to: page)
                    XCTAssertTrue(page.bounds.contains(rect), "\(button.title) outside \(size)")
                    let point = CGPoint(x: rect.midX, y: rect.midY)
                    XCTAssertTrue(page.hitTest(page.convert(point, to: page.superview)) === button,
                        "\(button.title) has a different input target")
                }
                func capture(_ suffix: String) throws {
                    page.layoutSubtreeIfNeeded()
                    let bitmap = try XCTUnwrap(page.bitmapImageRepForCachingDisplay(in: page.bounds))
                    func invalidate(_ view: NSView) { view.needsDisplay = true; view.subviews.forEach(invalidate) }
                    invalidate(page)
                    page.cacheDisplay(in: page.bounds, to: bitmap)
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to:
                        output.appendingPathComponent("\(state)-\(Int(size.width))-\(suffix).png"))
                }
                if let renderer { try GameMenuArtwork.withRenderer(renderer) { try capture("first") } }
                else { try capture("first") }
                if state != "empty" && state != "adventurer" {
                    try XCTUnwrap(buttons.first { $0.title == "Later actions" }).performClick(nil)
                    let labels = page.body.subviews.flatMap(\.subviews).compactMap { $0 as? NSTextField }
                    XCTAssertTrue(labels.contains { $0.stringValue.contains("Walker") })
                    if let renderer { try GameMenuArtwork.withRenderer(renderer) { try capture("history") } }
                    else { try capture("history") }
                    try XCTUnwrap(buttons.first { $0.title == "Next" }).performClick(nil)
                    let updated = navigator.controls(in: page).compactMap { $0 as? NSButton }
                    try XCTUnwrap(updated.first { $0.title == "Previous" }).performClick(nil)
                }
                var closed = false
                page.onBack = { closed = true }
                page.cancelOperation(nil)
                XCTAssertTrue(closed)
                XCTAssertEqual(try initial.inspectionHash(), before)
            }
            let typography = try XCTUnwrap(GameMenuTypography(directory: URL(fileURLWithPath:
                ProcessInfo.processInfo.environment["LEMMINGS_TEST_MENU_ARTWORK"] ?? "", isDirectory: true)))
            for size in [CGSize(width: 320, height: 568), CGSize(width: 390, height: 844),
                         CGSize(width: 844, height: 390), CGSize(width: 1024, height: 768), CGSize(width: 1920, height: 1080)] {
                let page = LemmingInspectionArt.page(snapshot)
                let layout = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
                let bounds = CGRect(origin: .zero, size: layout.size)
                for target in layout.targets {
                    XCTAssertTrue(bounds.contains(target.frame))
                    XCTAssertEqual(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)),
                        target.action.enabled ? target.action.id : nil)
                    for detail in layout.details { XCTAssertFalse(detail.intersects(target.frame)) }
                }
                for detail in layout.details { XCTAssertTrue(bounds.contains(detail)) }
                let context = try XCTUnwrap(CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height),
                    bitsPerComponent: 8, bytesPerRow: Int(layout.size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.translateBy(x: 0, y: layout.size.height); context.scaleBy(x: 1, y: -1)
                GameFrontEnd.draw(page, layout: layout, typography: typography, highlighted: "0", in: context)
                let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
                    output.appendingPathComponent("shared-\(state)-\(Int(size.width)).png") as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
                XCTAssertTrue(CGImageDestinationFinalize(destination))
            }
        }
    }
}

private extension Lemmings3Runtime {
    func inspectionHash() throws -> String { try ActionReplayState.lemmings3(self).hash() }
}
#endif
