import UIKit
import XCTest

final class LaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor func testSettingsShowsOfflineAboutVersionAndCredits() throws {
        let app = XCUIApplication()
        app.launchEnvironment["LEMMINGS_TEST_AUDIO"] = "muted"
        app.launchEnvironment["LEMMINGS_TEST_LANGUAGE"] = "en"
        app.launchArguments = ["-FirstLaunchProfileCompleteV1", "YES"]
        app.launch()
        tap(app.buttons["menu.settings"])
        let about = app.buttons["menu.about"]
        for _ in 0..<4 where !about.isHittable { app.swipeUp() }
        tap(about)
        let version = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@",
            "Version ", " - Build ")).firstMatch
        XCTAssertTrue(version.waitForExistence(timeout: 5))
        let heritage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "DMA Design")).firstMatch
        XCTAssertTrue(heritage.exists)
    }

    @MainActor func testReturningPlayerSeesHomeBeforeGameFilesAreReady() {
        let app = XCUIApplication()
        app.launchEnvironment["LEMMINGS_TEST_AUDIO"] = "muted"
        app.launchEnvironment["LEMMINGS_TEST_LANGUAGE"] = "en"
        app.launchEnvironment["LEMMINGS_TEST_SLOW_STARTUP"] = "1"
        app.launchArguments = ["-FirstLaunchProfileCompleteV1", "YES"]
        app.launch()

        let checking = app.descendants(matching: .any)["startup.checkingGameFiles"].firstMatch
        let play = app.buttons["menu.play"]
        XCTAssertTrue(checking.waitForExistence(timeout: 3))
        XCTAssertTrue(checking.label.contains("Checking game files"))
        XCTAssertFalse(play.exists)
        XCTAssertFalse(app.buttons["level.cracktro.cancel"].exists)
        capture(app, name: "Startup file check with cracktro backdrop")
        XCTAssertTrue(play.waitForExistence(timeout: 30))
        XCTAssertTrue(play.isEnabled)
        XCTAssertFalse(checking.exists)
    }

    @MainActor func testFirstPlayerStartsLevelAndReturnsHomeOnRelaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["LEMMINGS_TEST_AUDIO"] = "muted"
        app.launchEnvironment["LEMMINGS_TEST_LANGUAGE"] = "en"
        app.launchArguments = ["-FirstLaunchProfileCompleteV1", "NO"]
        app.launch()

        let portrait = app.buttons["menu.playerPortrait"]
        let initials = app.buttons["menu.nameField"]
        let play = app.buttons["menu.firstPlay"]
        let total = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "saved worldwide")).firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Create profile"].exists)
        assertTarget(portrait)
        let originalPortrait = portrait.label
        tap(portrait)
        XCTAssertNotEqual(portrait.label, originalPortrait)
        tap(initials)
        app.typeText("LEM\n")
        capture(app, name: "First player")
        tap(play)
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 30))
        app.terminate()
        app.launchArguments = []
        app.launch()
        assertTarget(app.buttons["menu.settings"])
        XCTAssertFalse(portrait.exists)
        let homeCount = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@ AND label CONTAINS[c] %@", "saved here", "Worldwide")).firstMatch
        XCTAssertTrue(homeCount.exists)
    }

    @MainActor func testNoDataButtonOffersAssetDownload() throws {
        try XCTSkipUnless(Bundle(for: Self.self).bundleIdentifier?.contains("ultimatelemmix") == true)
        let app = XCUIApplication()
        app.launchEnvironment["LEMMINGS_TEST_AUDIO"] = "muted"
        app.launchEnvironment["LEMMINGS_TEST_LANGUAGE"] = "en"
        app.launchArguments = ["-FirstLaunchProfileCompleteV1", "YES"]
        app.launch()
        let missing = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "No data")).firstMatch
        XCTAssertTrue(missing.waitForExistence(timeout: 30))
        let source = app.buttons[missing.identifier]
        tap(source)
        assertTarget(app.buttons["menu.gameAssets.agree"])
        let cancel = app.buttons["menu.gameAssets.cancel"]
        assertTarget(cancel)
        capture(app, name: "Download from No data")
        tap(cancel)
        assertTarget(source)
        XCTAssertFalse(cancel.exists)
    }

    /// Downloads the real asset pack. Set LEMMINGS_TEST_ASSET_DOWNLOAD=1 in the test plan environment to run it.
    @MainActor func testGameAssetDownloadInstallsAndSurvivesRelaunch() throws {
        try XCTSkipUnless(Bundle(for: Self.self).bundleIdentifier?.contains("ultimatelemmix") == true)
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LEMMINGS_TEST_ASSET_DOWNLOAD"] == "1")
        let app = XCUIApplication()
        app.launchEnvironment["LEMMINGS_TEST_AUDIO"] = "muted"
        app.launchEnvironment["LEMMINGS_TEST_LANGUAGE"] = "en"
        app.launchArguments = ["-FirstLaunchProfileCompleteV1", "YES"]
        app.launch()
        let missing = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "No data")).firstMatch
        XCTAssertTrue(missing.waitForExistence(timeout: 30))
        tap(app.buttons["menu.settings"])
        tap(app.buttons.matching(NSPredicate(format: "identifier IN %@", ["menu.data", "data"])).firstMatch)
        tap(app.buttons["menu.download.gameAssets"])
        tap(app.buttons["menu.gameAssets.agree"])
        let progress = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Downloading")).firstMatch
        XCTAssertTrue(progress.waitForExistence(timeout: 30))
        capture(app, name: "Asset Download Progress")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "Next:", "Turn:")).firstMatch.exists, "Game Data shows a player turn")
        let settings = app.buttons["menu.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 900), "The asset install did not return Home")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "failed verification")).firstMatch.exists)
        XCTAssertFalse(missing.waitForExistence(timeout: 5), "A game still reports No data after the install")
        capture(app, name: "Home After Asset Install")
        app.terminate()
        app.launch()
        XCTAssertTrue(settings.waitForExistence(timeout: 30))
        XCTAssertFalse(missing.waitForExistence(timeout: 5), "The installed assets did not survive a relaunch")
        capture(app, name: "Home After Relaunch")
    }

    @MainActor func testGameAssetDownloadRequiresALicence() throws {
        try XCTSkipUnless(Bundle(for: Self.self).bundleIdentifier?.contains("ultimatelemmix") == true)
        let app = XCUIApplication()
        app.launchEnvironment["LEMMINGS_TEST_AUDIO"] = "muted"
        app.launchEnvironment["LEMMINGS_TEST_LANGUAGE"] = "en"
        app.launchArguments = ["-FirstLaunchProfileCompleteV1", "YES"]
        app.launch()
        tap(app.buttons["menu.settings"])
        let data = app.buttons.matching(NSPredicate(format: "identifier IN %@", ["menu.data", "data"])).firstMatch
        tap(data)
        let download = app.buttons["menu.download.gameAssets"]
        let cancel = app.buttons["menu.gameAssets.cancel"]
        let agree = app.buttons["menu.gameAssets.agree"]
        let notice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@",
            "valid licence for the original game “Lemmings” on at least one platform")).firstMatch
        for _ in 0..<2 {
            tap(download)
            XCTAssertTrue(notice.waitForExistence(timeout: 5))
            XCTAssertTrue(notice.label.contains("By selecting “Agree and download”, you confirm that you hold that licence."))
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Next:")).firstMatch.exists)
            assertTarget(agree)
            assertTarget(cancel)
            XCTAssertFalse(download.exists)
            capture(app, name: "Game Assets Licence")
            tap(cancel)
            XCTAssertTrue(download.waitForExistence(timeout: 5))
            XCTAssertTrue(download.isEnabled)
        }
    }

    @MainActor func testMenuNavigationAndRotationKeepControlsAvailable() throws {
        let device = XCUIDevice.shared
        let originalOrientation = device.orientation
        defer { device.orientation = originalOrientation }

        let app = XCUIApplication()
        app.launchEnvironment["LEMMINGS_TEST_AUDIO"] = "muted"
        app.launchArguments = ["-FirstLaunchProfileCompleteV1", "YES"]
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

    @MainActor func testClassicReadyPauseRotationAndForegroundResume() throws {
        let device = XCUIDevice.shared
        let originalOrientation = device.orientation
        defer { device.orientation = originalOrientation }
        device.orientation = .portrait

        let app = XCUIApplication()
        app.launchEnvironment["LEMMINGS_TEST_AUDIO"] = "muted"
        app.launchArguments = ["-FirstLaunchProfileCompleteV1", "YES"]
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
