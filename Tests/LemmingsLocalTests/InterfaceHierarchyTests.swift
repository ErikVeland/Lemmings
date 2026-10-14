#if os(macOS)
import AppKit
import LemmingsGameArt
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class InterfaceHierarchyTests: XCTestCase {
    @MainActor func testWrappedBrowserStatesAndNativeTargets() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let art = root.appendingPathComponent(".build/mac-artwork/export/lemmings")
        guard let artwork = try? ClassicMacArtwork(directory: art), let interface = ClassicMacUserInterface(artwork: artwork) else {
            throw XCTSkip("Export the shipped Macintosh artwork for this render check")
        }
        try GameMenuArtwork.withRenderer(MacInterfaceRenderer(interface: interface)) {
            let title = "Let's be careful out there with a very long level title that wraps"
            let page = GameMenuPage(title: "Choose your next adventure with a long page title that wraps", subtitle: "Mixed collection")
            page.frame = CGRect(x: 0, y: 0, width: 1120, height: 720)
            let host = NSView(frame: page.bounds)
            host.addSubview(page)
            let carousel = LevelCoverFlowView(frame: page.body.bounds)
            carousel.autoresizingMask = [.width, .height]
            page.body.addSubview(carousel)
            var activated = false
            let play = page.addPrimaryAction("Play") { activated = true }
            let items = [LevelCoverFlowItem(id: "official", title: title, subtitle: "Official / Lemmings", detail: "Fun 27", isAvailable: true),
                         LevelCoverFlowItem(id: "fan", title: title, subtitle: "Fan-made / Community adventure", detail: "Level 32", isAvailable: true),
                         LevelCoverFlowItem(id: "locked", title: title, subtitle: "Official / Lemmings 2", detail: "Locked", isAvailable: false)]
            let output = ProcessInfo.processInfo.environment["LEMMINGS_HIERARCHY_SCREENSHOTS"].map { URL(fileURLWithPath: $0) }
            if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
            for reduced in [false, true] {
                for item in items {
                    carousel.configure(items: items, selectedID: item.id, reduceMotion: reduced)
                    page.layoutSubtreeIfNeeded(); carousel.layoutSubtreeIfNeeded()
                    XCTAssertGreaterThan(carousel.selectedTitleFrame.height, 26)
                    XCTAssertTrue(carousel.bounds.contains(carousel.selectedTitleFrame))
                    XCTAssertTrue(carousel.bounds.contains(carousel.selectedSourceFrame))
                    XCTAssertLessThanOrEqual(carousel.selectedTitleFrame.maxY, carousel.selectedSourceFrame.minY)
                    XCTAssertLessThanOrEqual(page.body.frame.maxY, 634)
                    let target = play.convert(play.bounds, to: page)
                    XCTAssertTrue(page.bounds.contains(target))
                    XCTAssertTrue(page.hitTest(page.convert(CGPoint(x: target.midX, y: target.midY), to: host)) === play)
                    play.performClick(nil); XCTAssertTrue(activated); activated = false
                    if let output {
                        let bitmap = try XCTUnwrap(page.bitmapImageRepForCachingDisplay(in: page.bounds))
                        page.displayIgnoringOpacity(page.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)))
                        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                            .write(to: output.appendingPathComponent("\(reduced ? "list" : "carousel")-\(item.id).png"))
                    }
                }
        }
        }
    }
}
#endif
