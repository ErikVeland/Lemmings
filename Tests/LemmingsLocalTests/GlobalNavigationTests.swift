#if os(macOS)
import AppKit
import XCTest
import LemmingsGameArt
import NxlvKit
@testable import LemmingsLocal

final class GlobalNavigationTests: XCTestCase {
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
