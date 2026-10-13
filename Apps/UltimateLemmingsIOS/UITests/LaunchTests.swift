import UIKit
import XCTest

final class LaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor func testMenuNavigationAndRotationKeepControlsAvailable() throws {
        let device = XCUIDevice.shared
        let originalOrientation = device.orientation
        defer { device.orientation = originalOrientation }

        let app = XCUIApplication()
        app.launchEnvironment["LEMMINGS_TEST_AUDIO"] = "muted"
        app.launch()

        // A data-free install starts on Game Data; bundled builds start at Home.
        let dataButton = app.buttons["menu.data"]
        let importButton = app.buttons["menu.import"]
        XCTAssertTrue(dataButton.waitForExistence(timeout: 5) || importButton.waitForExistence(timeout: 5))
        if importButton.exists {
            assertTarget(importButton)
            tap(app.buttons["menu.home"])
        }

        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            device.orientation = orientation
            capture(app, name: "Home After Orientation \(orientation.rawValue)")
            tap(app.buttons["menu.data"])
            assertTarget(importButton)
            capture(app, name: "Game Data \(orientation.rawValue)")
            tap(app.buttons["menu.home"])

            tap(app.buttons["menu.settings"])
            assertTarget(app.buttons["menu.planning"])
            assertTarget(app.buttons["menu.music"])
            capture(app, name: "Settings \(orientation.rawValue)")
            tap(app.buttons["menu.home"])
            assertTarget(app.buttons["menu.settings"])
            assertTarget(app.buttons["menu.data"])
            capture(app, name: "Home \(orientation.rawValue)")
        }
    }

    @MainActor func testGameDataOffersSeparateImportRoutes() {
        let app = XCUIApplication()
        app.launchEnvironment["LEMMINGS_TEST_AUDIO"] = "muted"
        app.launch()

        let data = app.buttons["menu.data"]
        let classicImport = app.buttons["menu.import.classic"]
        XCTAssertTrue(data.waitForExistence(timeout: 5) || classicImport.waitForExistence(timeout: 5))
        if data.exists { tap(data) }

        for game in ["classic", "lemmings2", "lemmings3", "neoLemmix"] {
            assertTarget(app.buttons["menu.import.\(game)"])
        }
        capture(app, name: "Independent Game Data Import Routes")
    }

    @MainActor func testClassicReadyPauseRotationAndForegroundResume() throws {
        let device = XCUIDevice.shared
        let originalOrientation = device.orientation
        defer { device.orientation = originalOrientation }
        device.orientation = .portrait

        let app = XCUIApplication()
        app.launchEnvironment["LEMMINGS_TEST_AUDIO"] = "muted"
        app.launch()
        let family = app.buttons["menu.family.classic"]
        let classic = app.buttons["menu.classic"]
        let importButton = app.buttons["menu.import"]
        XCTAssertTrue(family.waitForExistence(timeout: 5)
                      || classic.waitForExistence(timeout: 5)
                      || importButton.waitForExistence(timeout: 5))
        if importButton.exists { tap(app.buttons["menu.home"]) }

        if family.exists {
            tap(family)
            let originalPack = app.buttons["menu.pack.release/lemmings"]
            if originalPack.waitForExistence(timeout: 2) {
                tap(originalPack)
            }
        } else {
            try XCTSkipUnless(classic.exists && classic.isEnabled,
                              "Classic gameplay requires imported or bundled DOS game data; no playable Classic library is available.")
            tap(classic)
        }

        // The wide carousel and narrow page expose different, source-defined controls.
        let narrowPlay = app.buttons["menu.play"]
        let widePlay = app.buttons["PLAY"]
        XCTAssertTrue(narrowPlay.waitForExistence(timeout: 10) || widePlay.waitForExistence(timeout: 10))
        tap(narrowPlay.exists ? narrowPlay : widePlay)
        let start = app.buttons["START"]
        assertTarget(start)
        capture(app, name: "Classic Ready")
        tap(start)

        let pause = app.buttons["Pause"]
        let resume = app.buttons["Resume"]
        assertTarget(pause)
        capture(app, name: "Classic Playing")
        tap(pause)
        assertTarget(resume)
        capture(app, name: "Classic Planning Pause")
        tap(resume)
        assertTarget(pause)

        device.orientation = .landscapeLeft
        assertTarget(pause)
        assertTarget(app.buttons["Menu"])
        capture(app, name: "Classic Landscape")
        tap(pause)
        assertTarget(resume)
        tap(resume)

        // Switching apps stays inside the simulator. Duo's synthesized Home button
        // can target a different display and leave this app in the foreground.
        XCUIApplication(bundleIdentifier: "com.apple.Preferences").activate()
        let backgrounded = app.wait(for: .runningBackground, timeout: 5)
            || app.wait(for: .runningBackgroundSuspended, timeout: 5)
        XCTAssertTrue(backgrounded, "Expected background or suspended state after switching apps; actual state: \(app.state.rawValue)")
        app.activate()
        let resumeOverlay = app.buttons["RESUME"]
        assertTarget(resumeOverlay)
        capture(app, name: "Classic Returned Foreground Paused")
        // The lifecycle boundary must remain paused until the explicit action.
        XCTAssertTrue(resumeOverlay.isHittable)
        tap(resumeOverlay)
        assertTarget(pause)
        tap(app.buttons["Menu"])
        tap(app.buttons["LIBRARY"])
        XCTAssertTrue(narrowPlay.waitForExistence(timeout: 10) || widePlay.waitForExistence(timeout: 10))
        capture(app, name: "Classic Returned To Library")
    }

    @MainActor private func assertTarget(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let exists = element.waitForExistence(timeout: 5)
        let app = XCUIApplication()
        if exists, !element.isHittable, element.identifier.hasPrefix("menu.") {
            let scrollView = app.scrollViews.containing(.button, identifier: element.identifier).firstMatch
            for _ in 0..<4 {
                guard !element.isHittable, scrollView.exists, scrollView.isHittable,
                      !element.frame.isEmpty, !scrollView.frame.isEmpty else { break }
                if element.frame.maxY > scrollView.frame.maxY {
                    scrollView.swipeUp()
                } else if element.frame.minY < scrollView.frame.minY {
                    scrollView.swipeDown()
                } else {
                    break
                }
            }
        }
        if !exists || !element.isHittable {
            capture(app, name: "Unavailable Target " + element.identifier)
        }
        XCTAssertTrue(exists, file: file, line: line)
        XCTAssertTrue(element.isHittable, "\(element.identifier) must be tappable", file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.width, 44, file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.height, 44, file: file, line: line)
    }

    @MainActor private func tap(_ element: XCUIElement) {
        assertTarget(element)
        element.tap()
    }

    @MainActor private func capture(_ app: XCUIApplication, name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = name + " hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }
}
