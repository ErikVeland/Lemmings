import LemmingsMobileCore
import XCTest

final class MobileCoreIOSSmokeTests: XCTestCase {
    func testProductionPortraitHUDOnOriginalIPadPro() {
        for size in [MobileSize(width: 768, height: 1024), .init(width: 1024, height: 1366)] {
            let layout = MobileHUDLayout.make(container: size, safeArea: MobileInsets(top: 20),
                hasRate: true, skillCount: 8, supportsRewind: true)
            XCTAssertNotNil(layout.portrait)
            XCTAssertEqual(layout.interface.controlsFrame.height, 176)
            XCTAssertEqual(layout.interface.statusFrame.height, 44)
            XCTAssertEqual(layout.interface.playfieldFrame.minY, 64)
            XCTAssertEqual(layout.interface.playfieldFrame.height, size.height - 240)
            XCTAssertEqual(layout.interface.playfieldFrame.maxY, layout.interface.controlsFrame.minY)
            XCTAssertEqual(layout.interface.controlsFrame.maxY, size.height)
            XCTAssertEqual(layout.portrait?.skills.height, 80)
            XCTAssertEqual(layout.portrait?.minimap.height, 44)
            XCTAssertTrue(layout.interface.controlFrames.allSatisfy {
                $0.width >= 44 && $0.height >= 44
                    && $0.minX >= 0 && $0.maxX <= size.width
                    && $0.minY >= 20 && $0.maxY <= size.height
            })
            XCTAssertEqual(layout.interface.controlFrames.last?.width, 44)
        }
    }

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

    @MainActor func testGameDataOffersSeparateImportRoutes() {
        let app = XCUIApplication()
        app.launchEnvironment["LEMMINGS_TEST_AUDIO"] = "muted"
        app.launch()

        let classicImport = app.buttons["menu.import.classic"]
        if !classicImport.waitForExistence(timeout: 2) {
            let settings = app.buttons["menu.settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 5))
            settings.tap()
            let data = app.buttons["menu.data"]
            XCTAssertTrue(data.waitForExistence(timeout: 5))
            data.tap()
        }

        for game in ["classic", "lemmings2", "lemmings3", "neoLemmix"] {
            let button = app.buttons["menu.import.\(game)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing import route for \(game)")
            XCTAssertTrue(button.isHittable, "Import route for \(game) must be reachable")
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        }
    }
}
