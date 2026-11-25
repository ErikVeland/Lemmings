#if os(macOS)
import AppKit
import LemmingsMobileCore
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class RewindAccessibilityTests: XCTestCase {
    @MainActor func testPlayfieldReportsOneStepAtItsExistingStatusTarget() throws {
        _ = NSApplication.shared
        let view = PlayfieldView(frame: CGRect(x: 0, y: 0, width: 640, height: 320))
        let original = try XCTUnwrap(view.accessibilityChildren()?.first as? NSAccessibilityElement)
        let label = try XCTUnwrap(original.accessibilityLabel())
        let expected = try XCTUnwrap(RewindCue(currentTick: 19, originTick: 20,
            ticksPerSecond: Double(ClassicDOSRules.ticksPerSecond)))
        view.beginRewindCue(at: 20)
        defer { view.endRewindCue() }
        view.updateRewindCue(at: 19)
        let rewound = try XCTUnwrap(view.accessibilityChildren()?.first as? NSAccessibilityElement)
        XCTAssertTrue(rewound === original)
        XCTAssertEqual(rewound.accessibilityLabel(), label + ". " + expected.accessibilityLabel)
        view.updateRewindCue(at: 20)
        XCTAssertEqual((view.accessibilityChildren()?.first as? NSAccessibilityElement)?.accessibilityLabel(), label)
    }
}
#endif
