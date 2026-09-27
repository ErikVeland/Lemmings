import XCTest

final class LaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor func testFirstLaunchAndRotationKeepImportAvailable() throws {
        let app = XCUIApplication()
        app.launch()

        let importButton = app.buttons["IMPORT GAME DATA"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5))
        XCTAssertTrue(importButton.isHittable)

        if XCUIDevice.shared.orientation.isLandscape {
            XCUIDevice.shared.orientation = .portrait
        } else {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
        XCTAssertTrue(importButton.waitForExistence(timeout: 3))
        XCTAssertTrue(importButton.isHittable)
    }
}
