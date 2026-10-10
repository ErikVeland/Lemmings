import AppKit
import XCTest
import NxlvKit
@testable import LemmingsLocal

final class ProgressionMenuTests: XCTestCase {
    @MainActor func testRenderedPolicyControlsAndTargets() throws {
        _ = NSApplication.shared
        var selected: ProgressionPolicy?
        let page = ProgressionMenu.policies { selected = $0 }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 1120, height: 720))
        GameScreen.shared.gameWindow = window
        defer { GameScreen.shared.dismissAll(); GameScreen.shared.gameWindow = nil }
        GameScreen.shared.present(page, owner: window)
        window.contentView?.layoutSubtreeIfNeeded(); page.layoutSubtreeIfNeeded()
        func buttons(_ view: NSView) -> [NSButton] {
            (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(buttons)
        }
        let controls = buttons(page)
        for policy in ProgressionPolicy.allCases {
            let control = try XCTUnwrap(controls.first { $0.title == policy.name })
            let rect = control.convert(control.bounds, to: page)
            XCTAssertTrue(page.bounds.contains(rect), "Clipped: \(policy.name)")
            let hit = page.hitTest(NSPoint(x: rect.midX, y: rect.midY))
            XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true)
            XCTAssertTrue(window.makeFirstResponder(control))
            control.performClick(nil)
            XCTAssertEqual(selected, policy)
        }
        if let path = ProcessInfo.processInfo.environment["LEMMINGS_PROGRESSION_SCREENSHOT"] {
            let bitmap = try XCTUnwrap(page.bitmapImageRepForCachingDisplay(in: page.bounds))
            page.displayIgnoringOpacity(page.bounds, in: NSGraphicsContext(bitmapImageRep: bitmap)!)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                .write(to: URL(fileURLWithPath: path))
        }
    }
}
