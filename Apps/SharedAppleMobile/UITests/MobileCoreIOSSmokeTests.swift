import LemmingsMobileCore
import UIKit
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
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-FirstLaunchProfileCompleteV1", "YES"]
        app.launch()

        let settings = app.buttons["menu.settings"]
        let classicImport = app.buttons["menu.import.classic"]
        let welcomeAction = app.buttons.matching(NSPredicate(
            format: "identifier == %@ AND label IN %@", "navigation.back", ["Continue", "Not now"]
        )).firstMatch
        for _ in 0..<3 {
            let ready = NSPredicate { _, _ in
                settings.exists || classicImport.exists || welcomeAction.exists
            }
            guard XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: app)], timeout: 15) == .completed else {
                XCTFail("Startup must show the main menu, import routes or a welcome action")
                return
            }
            if settings.exists || classicImport.exists { break }
            welcomeAction.tap()
        }

        if !classicImport.waitForExistence(timeout: 2) {
            XCTAssertTrue(settings.waitForExistence(timeout: 5))
            settings.tap()
            let data = app.buttons.matching(NSPredicate(
                format: "identifier IN %@", ["menu.data", "data"]
            )).firstMatch
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

    @MainActor func testAboutSectionsAndReleaseNavigationRemainReachableAfterRotation() {
        let device = XCUIDevice.shared
        let originalOrientation = device.orientation
        let app = XCUIApplication()
        defer {
            app.terminate()
            device.orientation = originalOrientation
        }
        device.orientation = .portrait
        app.launchEnvironment["LEMMINGS_TEST_AUDIO"] = "muted"
        app.launchEnvironment["LEMMINGS_TEST_LANGUAGE"] = "en"
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-FirstLaunchProfileCompleteV1", "YES"]
        app.launch()

        let settings = app.buttons["menu.settings"]
        let welcomeAction = app.buttons.matching(NSPredicate(
            format: "identifier == %@ AND label IN %@", "navigation.back", ["Continue", "Not now"]
        )).firstMatch
        let mainMenu = app.buttons["navigation.home"]
        for _ in 0..<4 {
            let ready = NSPredicate { _, _ in settings.exists || welcomeAction.exists || mainMenu.exists }
            guard XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: app)], timeout: 15) == .completed else {
                XCTFail("Startup must expose the main menu or a welcome action")
                return
            }
            if settings.exists { break }
            if welcomeAction.exists { welcomeAction.tap() }
            else { mainMenu.tap() }
        }
        guard settings.waitForExistence(timeout: 5) else {
            XCTFail("Settings must be reachable before opening About")
            return
        }
        settings.tap()
        let about = app.buttons["menu.about"]
        guard about.waitForExistence(timeout: 5) else {
            XCTFail("Settings must offer About")
            return
        }
        for _ in 0..<6 where !about.isHittable { app.swipeUp() }
        guard about.isHittable else {
            XCTFail("About must have a reachable input target")
            return
        }
        about.tap()

        func selectSection(_ section: String) -> Bool {
            let button = app.buttons["aboutSection." + section]
            guard button.waitForExistence(timeout: 5) else {
                XCTFail("Missing About section: \(section)")
                return false
            }
            let shelf = app.scrollViews.containing(.button, identifier: "aboutSection.overview").firstMatch
            for _ in 0..<3 where !button.isHittable {
                if section == "overview" { shelf.swipeRight() }
                else { shelf.swipeLeft() }
            }
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            guard button.isHittable else {
                XCTFail("About section must be reachable: \(section)")
                return false
            }
            button.tap()
            return true
        }

        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            device.orientation = orientation
            guard selectSection("overview") else { return }
            let heading = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "About Ultimate Lemm")).firstMatch
            XCTAssertTrue(heading.waitForExistence(timeout: 5))
            let heritage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "DMA Design")).firstMatch
            XCTAssertTrue(heritage.exists, "About must retain the original game credits")
            guard selectSection("history") else { return }
            let release = app.buttons["menu.aboutRelease.0"]
            guard release.waitForExistence(timeout: 5) else {
                XCTFail("Bundled version history must contain a selectable release")
                return
            }
            XCTAssertTrue(release.isHittable)
            release.tap()
            XCTAssertFalse(release.exists, "Selecting a release must open its notes")
            let back = app.buttons["navigation.back"]
            XCTAssertTrue(back.waitForExistence(timeout: 5))
            XCTAssertTrue(back.isHittable)
            let notes = XCTAttachment(screenshot: app.screenshot())
            notes.name = "About release notes \(orientation.rawValue)"
            notes.lifetime = .keepAlways
            add(notes)
            back.tap()
            XCTAssertTrue(release.waitForExistence(timeout: 5), "Back must return to the release list")
            guard selectSection("contributors") else { return }
            XCTAssertTrue(app.staticTexts["Contributors"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.staticTexts["No contributors listed yet."].exists,
                "The bundled supporter list must remain available before a refresh completes")
            let credits = XCTAttachment(screenshot: app.screenshot())
            credits.name = "About contributors \(orientation.rawValue)"
            credits.lifetime = .keepAlways
            add(credits)
        }
        app.buttons["navigation.back"].tap()
        XCTAssertFalse(app.buttons["aboutSection.overview"].exists)
        XCTAssertTrue(about.waitForExistence(timeout: 5), "Back must return to the originating Settings page")
    }

    @MainActor func testLemmings3DirectionPickerHasReachableAccessibleTargets() {
        let app = XCUIApplication()
        app.launchEnvironment["LEMMINGS_TEST_AUDIO"] = "muted"
        app.launchArguments.append("--ui-test-l3-direction-picker")
        app.launch()

        let directions = [
            ("upleft", "Up-left"), ("up", "Up"), ("upright", "Up-right"),
            ("left", "Left"), ("right", "Right"),
            ("downleft", "Down-left"), ("down", "Down"), ("downright", "Down-right"),
            ("cancel", "Cancel tool direction")
        ]
        for (identifier, label) in directions {
            let button = app.buttons["game.l3.direction.\(identifier)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing L3 direction target \(identifier)")
            XCTAssertTrue(button.isHittable, "L3 direction target \(identifier) must be reachable")
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertEqual(button.label, label)
        }

        let down = app.buttons["game.l3.direction.down"]
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "L3 Direction Picker"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        down.tap()
        XCTAssertTrue(down.waitForExistence(timeout: 2), "An invalid tool direction must keep the picker open")

        let cancel = app.buttons["game.l3.direction.cancel"]
        cancel.tap()
        XCTAssertFalse(cancel.waitForExistence(timeout: 1), "Cancel must close the direction picker")

        app.terminate()
        app.launch()
        let up = app.buttons["game.l3.direction.up"]
        XCTAssertTrue(up.waitForExistence(timeout: 5))
        up.tap()
        XCTAssertFalse(up.waitForExistence(timeout: 1), "An accepted tool direction must close the picker")
    }

    @MainActor func testLemmings3PlayfieldExposesAccessibleTargetAndSkillState() {
        let app = XCUIApplication()
        app.launchEnvironment["LEMMINGS_TEST_AUDIO"] = "muted"
        app.launchArguments.append("--ui-test-accessible-targeting")
        app.launch()

        let playfield = app.descendants(matching: .any).matching(identifier: "game.playfield").firstMatch
        XCTAssertTrue(playfield.waitForExistence(timeout: 5))
        XCTAssertEqual(playfield.label, "Game playfield")
        XCTAssertTrue((playfield.value as? String)?.contains("Eligible lemming 1 of 1") == true)
        XCTAssertTrue((playfield.value as? String)?.contains("Skill: Use") == true)
    }

    @MainActor func testLemmings3AccessibleAssignmentOpensNativeDirectionPicker() {
        let app = XCUIApplication()
        app.launchEnvironment["LEMMINGS_TEST_AUDIO"] = "muted"
        app.launchArguments.append("--ui-test-accessible-assignment")
        app.launch()

        let up = app.buttons["game.l3.direction.up"]
        XCTAssertTrue(up.waitForExistence(timeout: 5))
        XCTAssertTrue(up.isHittable)
        XCTAssertGreaterThanOrEqual(up.frame.width, 44)
        XCTAssertGreaterThanOrEqual(up.frame.height, 44)
    }

    @MainActor func testLemmings3DirectionPickerCancelsAfterRotation() {
        let device = XCUIDevice.shared
        let originalOrientation = device.orientation
        defer { device.orientation = originalOrientation }

        let app = XCUIApplication()
        app.launchEnvironment["LEMMINGS_TEST_AUDIO"] = "muted"
        app.launchArguments.append("--ui-test-l3-direction-picker")
        app.launch()

        let up = app.buttons["game.l3.direction.up"]
        XCTAssertTrue(up.waitForExistence(timeout: 5))
        device.orientation = .landscapeLeft
        XCTAssertFalse(up.waitForExistence(timeout: 2), "A layout change must close a picker anchored to the old playfield")
    }
}
