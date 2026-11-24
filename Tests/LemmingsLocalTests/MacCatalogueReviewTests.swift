#if os(macOS)
import AppKit
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class MacCatalogueReviewTests: XCTestCase {
    @MainActor func testPackSearchResetAndLevelFilterTargets() throws {
        _ = NSApplication.shared
        let packs = [FanLevelOrganisation.Pack(id: "one", title: "First Steps"), .init(id: "two", title: "Second Steps")]
        let page = FanLevelGroupPage(root: FanLevelOrganisation.library(packs), path: [])
        page.onSearch = { [weak page] query in page?.reload(FanLevelOrganisation.library(packs, query: query)) }
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 900, height: 620),
                              styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = page
        page.layoutSubtreeIfNeeded()
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let output = root.appendingPathComponent(".build/catalogue-review")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let artwork = try ClassicMacArtwork(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        let renderer = MacInterfaceRenderer(interface: try XCTUnwrap(ClassicMacUserInterface(artwork: artwork)))
        func capture(_ name: String) throws {
            page.layoutSubtreeIfNeeded()
            try GameMenuArtwork.withRenderer(renderer) {
                let bitmap = try XCTUnwrap(page.bitmapImageRepForCachingDisplay(in: page.bounds))
                @MainActor func invalidate(_ view: NSView) {
                    view.needsDisplay = true
                    view.subviews.forEach(invalidate)
                }
                invalidate(page)
                if let context = NSGraphicsContext(bitmapImageRep: bitmap) { page.displayIgnoringOpacity(page.bounds, in: context) }
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent(name + ".png"))
            }
        }
        try capture("mac-fan-packs")
        let bar = page.searchBar
        bar.search.stringValue = "missing"
        bar.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        XCTAssertTrue(page.groupButtons.isEmpty)
        XCTAssertTrue(bar.clear.isEnabled)
        try capture("mac-empty-packs")
        bar.clear.performClick(nil)
        XCTAssertEqual(page.groups.flatMap(\.packIDs).count, 2)
        page.layoutSubtreeIfNeeded()
        bar.layoutSubtreeIfNeeded()
        let point = bar.search.convert(CGPoint(x: bar.search.bounds.midX, y: bar.search.bounds.midY), to: page.superview)
        XCTAssertTrue(page.hitTest(point) === bar.search)
        for button in page.groupButtons {
            let centre = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: page.superview)
            XCTAssertTrue(page.hitTest(centre) === button)
        }
        let levels = CatalogueFilterBar(searchTitle: "Search levels", progressEnabled: true)
        levels.frame = CGRect(x: 0, y: 0, width: 760, height: 48)
        window.contentView = levels
        levels.layoutSubtreeIfNeeded()
        var filters: [CatalogueProgressFilter] = []
        levels.onChange = { _, filter in filters.append(filter) }
        for _ in 0..<3 { levels.filter.performClick(nil) }
        XCTAssertEqual(filters, [.incomplete, .cleared, .all])
        for control in [levels.search, levels.filter, levels.clear] as [NSControl] {
            XCTAssertGreaterThanOrEqual(control.frame.width, 44)
            XCTAssertGreaterThanOrEqual(control.frame.height, 44)
            XCTAssertTrue(levels.hitTest(CGPoint(x: control.frame.midX, y: control.frame.midY)) === control)
        }
    }
}
#endif
