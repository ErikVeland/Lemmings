import LemmingsMobileCore
import XCTest

final class MobileCoreIOSSmokeTests: XCTestCase {
    func testLayoutTouchAndLifecycleContractsOnIOS() {
        let layout = MobileLayoutEngine.make(
            container: MobileSize(width: 390, height: 844),
            safeArea: MobileInsets(top: 47, bottom: 34),
            controlCount: 13
        )
        XCTAssertEqual(layout.controlFrames.count, 13)
        XCTAssertTrue(layout.controlFrames.allSatisfy {
            $0.width >= MobileLayoutEngine.minimumControlExtent
                && $0.height >= MobileLayoutEngine.minimumControlExtent
        })

        let duoClosed = MobileLayoutEngine.make(
            container: MobileSize(width: 330, height: 460),
            safeArea: MobileInsets(top: 12, bottom: 12),
            controlCount: 16
        )
        let duoOpen = MobileLayoutEngine.make(
            container: MobileSize(width: 650, height: 465),
            safeArea: MobileInsets(top: 12, bottom: 12),
            controlCount: 16
        )
        XCTAssertEqual(duoClosed.controlsPlacement, .trailingRail)
        XCTAssertEqual(duoOpen.controlsPlacement, .trailingRail)
        XCTAssertGreaterThan(duoOpen.playfieldFrame.width, duoClosed.playfieldFrame.width)

        var touch = MobileTouchRouter(movementThreshold: 8)
        _ = touch.began(id: 1, at: MobilePoint(x: 10, y: 10), time: 1)
        XCTAssertTrue(touch.moved(id: 1, to: MobilePoint(x: 30, y: 10)).contains(.cancelPreview))
        XCTAssertEqual(
            touch.ended(id: 1, at: MobilePoint(x: 30, y: 10), time: 1.2),
            [.cancelPreview]
        )

        var lifecycle = MobileLifecycleState()
        XCTAssertTrue(lifecycle.handle(.becameInactive).contains(.saveCheckpoint(.suspension)))
        XCTAssertTrue(lifecycle.handle(.becameActive).contains(.showResumeControl))
        XCTAssertTrue(lifecycle.isPaused)
    }
}
