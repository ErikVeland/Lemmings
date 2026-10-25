#if os(macOS)
import AppKit
import XCTest
import NxlvKit
@testable import LemmingsLocal

final class AdaptiveListLayoutTests: XCTestCase {
    @MainActor func testNativeListRendersAtCompactAndWideSizes() throws {
        _ = NSApplication.shared
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard let artwork = try? ClassicMacArtwork(directory: repository.appendingPathComponent(".build/mac-artwork/export/lemmings")),
              let interface = ClassicMacUserInterface(artwork: artwork) else { throw XCTSkip("The Macintosh artwork export is unavailable") }
        let output = repository.appendingPathComponent(".build/list-reflow-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let previous = GameScreen.shared.onMainMenu
        GameScreen.shared.onMainMenu = {}
        defer { GameScreen.shared.dismissAll(); GameScreen.shared.onMainMenu = previous }
        try GameMenuArtwork.withRenderer(MacInterfaceRenderer(interface: interface)) {
            for size in [CGSize(width: 900, height: 620), .init(width: 1120, height: 720)] {
                let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.contentView = NSView(frame: CGRect(origin: .zero, size: size))
                defer { window.close() }
                let page = GameMenuPage(title: "Techniques")
                for (index, name) in ["Builder", "Basher", "Miner", "Digger", "Blocker", "Climber", "Floater", "Skill cancellation"].enumerated() {
                    page.addListAction(name, at: index) {}
                }
                GameScreen.shared.present(page, owner: window)
                let root = try XCTUnwrap(window.contentView)
                let bitmap = try XCTUnwrap(root.bitmapImageRepForCachingDisplay(in: root.bounds))
                root.cacheDisplay(in: root.bounds, to: bitmap)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(
                    to: output.appendingPathComponent("mac-list-\(Int(size.width)).png"))
                GameScreen.shared.dismiss(page)
            }
        }
    }

    @MainActor func testLongNativeListsReflowAndScrollInsideTheirNavigation() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1120, height: 720),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 1120, height: 720))
        defer { GameScreen.shared.dismissAll(); window.close() }
        for count in [8, 35, 200] {
            let page = GameMenuPage(title: "Techniques")
            var selected = -1
            let buttons = (0..<count).map { index in
                page.addListAction("Technique \(index + 1)", at: index) { selected = index }
            }
            GameScreen.shared.present(page, owner: window)
            let scroll = try XCTUnwrap(page.body.subviews.compactMap { $0 as? NSScrollView }.first)
            let document = try XCTUnwrap(scroll.documentView)
            XCTAssertTrue(document.isFlipped)
            XCTAssertEqual(buttons.prefix(3).map { $0.frame.minY }, [12, 12, 12])
            XCTAssertGreaterThan(buttons[3].frame.minY, buttons[0].frame.minY)
            let back = page.controllerBackButton.frame
            for button in buttons {
                XCTAssertTrue(document.bounds.contains(button.frame))
                XCTAssertGreaterThanOrEqual(button.frame.width, 44)
                XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            }
            let last = try XCTUnwrap(buttons.last)
            last.scrollToVisible(last.bounds)
            XCTAssertEqual(page.controllerBackButton.frame, back)
            if count > 8 {
                XCTAssertTrue(scroll.hasVerticalScroller)
                XCTAssertGreaterThan(scroll.contentView.bounds.minY, 0)
            }
            let point = last.convert(CGPoint(x: last.bounds.midX, y: last.bounds.midY), to: page.superview)
            XCTAssertTrue(page.hitTest(point) === last)
            last.performClick(nil)
            XCTAssertEqual(selected, count - 1)
            GameScreen.shared.dismiss(page)
        }
    }
}
#endif
