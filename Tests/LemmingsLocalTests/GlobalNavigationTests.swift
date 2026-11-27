#if os(macOS)
import AppKit
import XCTest
import LemmingsGameArt
import NxlvKit
@testable import LemmingsLocal

final class GlobalNavigationTests: XCTestCase {
    @MainActor func testShortMenuUsesTheLargeDisplayAndKeepsTheFooterClose() throws {
        _ = NSApplication.shared
        let screen = GameScreen.shared
        let previous = screen.onMainMenu
        screen.onMainMenu = {}
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 2560, height: 1400),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { screen.dismissAll(); screen.onMainMenu = previous; window.close() }
        let page = GameMenuPage(title: "Profile", subtitle: "LEM")
        let records = page.addListAction("Records", at: 0) {}
        let players = page.addListAction("Players", at: 1, section: "All players") {}
        XCTAssertTrue(screen.present(page, owner: window, focus: records))
        let row = players.convert(players.bounds, to: page)
        let footer = page.controllerBackButton.convert(page.controllerBackButton.bounds, to: page)
        XCTAssertGreaterThanOrEqual(row.height, 112)
        XCTAssertGreaterThan(row.width, page.bounds.width * 0.7)
        XCTAssertGreaterThan(footer.minY - row.maxY, 0)
        XCTAssertLessThanOrEqual(footer.minY - row.maxY, 52)
    }

    @MainActor func testScrollWheelCanPanWithoutZoom() throws {
        let scroll = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
            wheelCount: 1, wheel1: 48, wheel2: 0, wheel3: 0))
        scroll.flags = []
        let event = try XCTUnwrap(NSEvent(cgEvent: scroll))
        var gesture = PrecisionZoomScrollGesture()
        XCTAssertEqual(gesture.handle(event, zoomEnabled: false), .pan)
        guard case .zoom = gesture.handle(event, zoomEnabled: true) else {
            return XCTFail("The default wheel input did not zoom")
        }
    }

    @MainActor func testPlayGamePageKeepsFocusAndInputTargetsAcrossDisplayUpdates() throws {
        _ = NSApplication.shared
        let screen = GameScreen.shared
        let previous = screen.onMainMenu
        var presses: [String] = []
        screen.onMainMenu = { presses.append("Main menu") }
        let size = CGSize(width: 1700, height: 960)
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { screen.dismissAll(); screen.onMainMenu = previous; window.close() }
        let page = GameMenuPage(title: "Lemmings", subtitle: "Ratings")
        let fun = page.addListAction("Fun", at: 0) { presses.append("Fun") }
        let tricky = page.addListAction("Tricky", at: 1) { presses.append("Tricky") }
        XCTAssertTrue(screen.present(page, owner: window, focus: fun))
        XCTAssertTrue(window.makeFirstResponder(tricky))

        for _ in 0..<3 { screen.reattach() }
        XCTAssertTrue(window.firstResponder === tricky)
        screen.reattach(relayout: true)

        XCTAssertTrue(window.firstResponder === tricky)
        let root = try XCTUnwrap(window.contentView)
        let navigation = try XCTUnwrap(screen.controllerNavigationRoot(in: window))
        let controls = screen.keyboardNavigation.controls(in: navigation).compactMap { $0 as? NSButton }
        let home = try XCTUnwrap(controls.first { $0.accessibilityIdentifier() == "navigation.home" })
        for control in [fun, tricky, page.controllerBackButton, home] {
            let centre = CGPoint(x: control.bounds.midX, y: control.bounds.midY)
            XCTAssertTrue(root.hitTest(control.convert(centre, to: root)) === control)
        }
        let enter = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "\r",
            charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        XCTAssertTrue(screen.handleDialogKey(enter))
        XCTAssertEqual(presses, ["Tricky"])
        let quit = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
            timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "q",
            charactersIgnoringModifiers: "q", isARepeat: false, keyCode: 12))
        XCTAssertFalse(screen.handleDialogKey(quit))
        home.performClick(nil)
        XCTAssertEqual(presses, ["Tricky", "Main menu"])
        page.controllerBackButton.performClick(nil)
        XCTAssertFalse(screen.isPresented)
    }

    @MainActor func testMainMenuStaysOutsideNestedScrollingPagesAndControllerCanReachIt() throws {
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let artwork = try? ClassicMacArtwork(directory: repository.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        if let artwork, let interface = ClassicMacUserInterface(artwork: artwork) {
            try GameMenuArtwork.withRenderer(MacInterfaceRenderer(interface: interface)) { try verifyNavigation() }
        } else { try verifyNavigation() }
    }

    @MainActor private func verifyNavigation() throws {
        _ = NSApplication.shared
        let screen = GameScreen.shared
        let previous = screen.onMainMenu
        var homePresses = 0, readyPresses = 0
        screen.onMainMenu = { homePresses += 1; screen.dismissAll() }
        defer { screen.dismissAll(); screen.onMainMenu = previous }
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/global-navigation-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for size in [CGSize(width: 900, height: 620), .init(width: 1120, height: 720)] {
            let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = NSView(frame: CGRect(origin: .zero, size: size))
            defer { window.close() }
            let ready = GameMenuPage(title: "Ready")
            ready.controllerBackButton.isHidden = true
            ready.addPrimaryAction("Ready") { readyPresses += 1 }
            XCTAssertTrue(screen.present(ready, owner: window))
            let settings = GameMenuPage(title: "Gameplay")
            XCTAssertTrue(screen.present(settings, owner: window))
            let root = try XCTUnwrap(screen.controllerNavigationRoot(in: window))
            func descendants(_ view: NSView) -> [NSView] {
                view.subviews.flatMap { [$0] + descendants($0) }
            }
            let back = try XCTUnwrap(descendants(root).compactMap { $0 as? NSButton }.first {
                $0.accessibilityIdentifier() == "navigation.back"
            })
            back.performClick(nil)
            XCTAssertTrue(screen.controllerPage(in: window) === ready)
            XCTAssertEqual(readyPresses, 0)
            XCTAssertTrue(screen.present(settings, owner: window))
            let visibleRoot = try XCTUnwrap(screen.controllerNavigationRoot(in: window))
            let home = try XCTUnwrap(descendants(visibleRoot).compactMap { $0 as? NSButton }.first {
                $0.accessibilityIdentifier() == "navigation.home"
            })
            let scroll = try XCTUnwrap(visibleRoot.subviews.compactMap { $0 as? NSScrollView }.first)
            let original = home.frame
            let canvas = try XCTUnwrap(home.superview)
            XCTAssertTrue(back.superview === canvas)
            XCTAssertGreaterThan(home.frame.midY, canvas.bounds.midY)
            scroll.contentView.scroll(to: CGPoint(x: 0, y: 200))
            visibleRoot.layoutSubtreeIfNeeded()
            XCTAssertEqual(home.frame, original)
            XCTAssertGreaterThanOrEqual(home.frame.height, 44)
            XCTAssertFalse(home.frame.intersects(settings.body.frame))
            let point = home.convert(CGPoint(x: home.bounds.midX, y: home.bounds.midY), to: visibleRoot.superview)
            XCTAssertTrue(visibleRoot.hitTest(point) === home)
            scroll.contentView.scroll(to: .zero)
            visibleRoot.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(visibleRoot.bitmapImageRepForCachingDisplay(in: visibleRoot.bounds))
            visibleRoot.cacheDisplay(in: visibleRoot.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(
                to: output.appendingPathComponent("mac-\(Int(size.width)).png"))
            let navigator = ControllerMenuNavigator()
            for _ in 0..<12 where navigator.selected !== home { navigator.handle(.rate(1), in: visibleRoot) }
            XCTAssertTrue(navigator.selected === home)
            navigator.handle(.assign, in: visibleRoot)
            XCTAssertFalse(screen.isPresented)
            XCTAssertEqual(readyPresses, 0)
        }
        XCTAssertEqual(homePresses, 2)
    }
}
#endif
