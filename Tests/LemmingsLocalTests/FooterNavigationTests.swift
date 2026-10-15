#if os(macOS)
import AppKit
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class FooterNavigationTests: XCTestCase {
    @MainActor func testDisabledGameplayControllersStillOperateMenus() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1120, height: 720),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 1120, height: 720))
        let keyboard = GameplayKeyboard(window: window)
        defer { keyboard.removeNavigationControl(); GameScreen.shared.dismissAll(); window.close() }
        keyboard.controllerEnabled = { false }
        keyboard.active = { false }
        keyboard.menuActive = { true }
        let page = GameMenuPage(title: "Settings")
        var changed = false
        let primary = page.addPrimaryAction("Change") { changed = true }
        page.preferControllerControl(primary)
        XCTAssertTrue(GameScreen.shared.present(page, owner: window))
        let driver = GameplayController(keyboard: keyboard, pollsAutomatically: false)
        driver.processButtons([], at: 0, playing: false)
        driver.processButtons([.a], at: 1, playing: false)
        XCTAssertTrue(changed)
        driver.processButtons([], at: 2, playing: false)
        driver.processButtons([.b], at: 3, playing: false)
        XCTAssertFalse(GameScreen.shared.contains(page))
        keyboard.active = { true }
        keyboard.menuActive = { false }
        var menus = 0
        keyboard.menuKey = { if $0 == "\u{1b}" { menus += 1 } }
        driver.processButtons([], at: 4, playing: false)
        driver.processButtons([.a], at: 5, playing: false)
        XCTAssertEqual(menus, 0)
        driver.processButtons([], at: 6, playing: false)
        driver.processButtons([.menu], at: 7, playing: false)
        XCTAssertEqual(menus, 1)
    }

    @MainActor func testVisibleBackGetsADismissActionAndHiddenReadyKeepsItsBoundary() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1120, height: 720),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 1120, height: 720))
        defer { GameScreen.shared.dismissAll(); window.close() }
        let page = GameMenuPage(title: "Recovery")
        XCTAssertNil(page.onBack)
        XCTAssertTrue(GameScreen.shared.present(page, owner: window))
        XCTAssertNotNil(page.onBack)
        page.controllerBackButton.performClick(nil)
        XCTAssertFalse(GameScreen.shared.contains(page))
        let ready = GameMenuPage(title: "PAL's turn")
        ready.controllerBackButton.isHidden = true
        var started = false
        let action = ready.addPrimaryAction("Ready") { started = true }
        XCTAssertTrue(GameScreen.shared.present(ready, owner: window))
        XCTAssertNil(ready.onBack)
        ready.cancelOperation(nil)
        XCTAssertTrue(GameScreen.shared.contains(ready))
        XCTAssertFalse(started)
        action.performClick(nil)
        XCTAssertTrue(started)
    }

    func testRequiredChoicesHaveSafeHardwareBackAndGameSettingsHaveNoUnwiredRoutes() {
        XCTAssertEqual(MobileInformationArt.telemetryConsent().backAction?.id, "telemetryNo")
        XCTAssertEqual(MobileInformationArt.effectsWelcome().backAction?.id, "welcomeOriginal")
        XCTAssertEqual(MobileInformationArt.whatsNew(version: "2.0").backAction?.id, "welcomeContinue")
        XCTAssertEqual(MobileSettingsArt.skillSelectionPauseChoice().backAction?.id, "1")
        XCTAssertFalse(MobileSettingsArt.groups(inGame: true).rows.contains { $0.id == "data" })
        XCTAssertTrue(MobileSettingsArt.groups().rows.contains { $0.id == "data" })
        XCTAssertFalse(MobileSettingsArt.page(.privacy, settings: .init(), inGame: true).rows.contains { $0.id == "cloudSaves" })
        XCTAssertTrue(MobileSettingsArt.page(.privacy, settings: .init()).rows.contains { $0.id == "cloudSaves" })
        let recovery = GameRecoveryArt.page(title: "Save failed")
        XCTAssertEqual(recovery.backAction?.id, "back")
        XCTAssertEqual(Set(recovery.footer.filter(\.enabled).map(\.id)), ["retry", "back", "menu"])
        XCTAssertEqual(GameRecoveryArt.recordsReset("Fixture").backAction?.id, "recordsResetCancel")
    }

    @MainActor func testNativeLossHasBackMenuAndWorkingRetryAcrossAllGames() throws {
        _ = NSApplication.shared
        let storage = try AppStorage.temporary(named: "result-navigation")
        let previous = ArcadeStore.shared
        let store = ArcadeStore(storage: storage, bundledProofs: nil)
        ArcadeStore.shared = store
        defer { ArcadeStore.shared = previous; storage.removeTemporaryFiles() }
        let host = store.records.activeProfileID
        let guest = try XCTUnwrap(store.addProfile(initials: "PAL", portrait: 2, select: false))
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let artwork = try ClassicMacArtwork(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        let font = MacInterfaceRenderer(interface: try XCTUnwrap(ClassicMacUserInterface(artwork: artwork)))
        let output = root.appendingPathComponent(".build/result-failure-native")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for game in ["Classic", "Lemmings 2", "Lemmings 3"] {
            let level = ArcadeLevel(id: game, title: "Failure navigation", game: game, rules: "fixture", total: 10, required: 5)
            let report = try XCTUnwrap(store.previewReport(for: .init(profileID: host, level: level, saved: 0, didWin: false, skills: [:], seconds: 20)))
            for hotSeat in [false, true] {
                if hotSeat {
                    store.prepareHotSeat()
                    if !store.sessionProfileIDs.contains(guest.id) { store.toggleSessionProfile(guest.id) }
                } else { store.endHotSeat() }
                for later in [false, true] {
                    let view = ArcadeView(frame: CGRect(x: 0, y: 0, width: 1120, height: 720))
                    let window = NSWindow(contentRect: view.bounds, styleMask: [.titled], backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false
                    window.contentView = view
                    defer { window.close() }
                    view.mode = .result; view.report = report; view.level = level; view.font = font
                    var backs = 0, menus = 0, retries = 0
                    view.onClose = { backs += 1 }; view.onMenu = { menus += 1 }; view.onRetry = { retries += 1 }
                    if later { view.onLater = {} }
                    let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                        .write(to: output.appendingPathComponent("\(game)-\(hotSeat)-\(later).png"))
                    let buttons = (view.accessibilityChildren() ?? []).compactMap { $0 as? GameAccessibleElement }
                        .filter { $0.accessibilityRole() == .button }
                    let back = try XCTUnwrap(buttons.first { ($0.accessibilityLabel() ?? "").hasPrefix("Back") })
                    let menu = try XCTUnwrap(buttons.first { $0.accessibilityLabel() == "Menu" })
                    XCTAssertTrue(view.bounds.contains(back.localFrame) && view.bounds.contains(menu.localFrame))
                    XCTAssertEqual(back.localFrame.minX, buttons.map { $0.localFrame.minX }.min())
                    XCTAssertTrue(buttons.filter { $0 !== back }.allSatisfy { !$0.localFrame.intersects(back.localFrame) })
                    XCTAssertTrue(back.accessibilityPerformPress()); XCTAssertEqual(backs, 1)
                    XCTAssertTrue(menu.accessibilityPerformPress()); XCTAssertEqual(menus, 1)
                    let point = view.convert(CGPoint(x: back.localFrame.midX, y: back.localFrame.midY), to: nil)
                    view.mouseDown(with: try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point,
                        modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
                        eventNumber: 0, clickCount: 1, pressure: 1)))
                    XCTAssertEqual(backs, 2)
                    view.keyDown(with: try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                        modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
                        characters: "q", charactersIgnoringModifiers: "q", isARepeat: false, keyCode: 12)))
                    XCTAssertEqual(menus, 2)
                    if !hotSeat {
                        let retry = try XCTUnwrap(buttons.first { $0.accessibilityLabel() == "Try again" })
                        XCTAssertTrue(retry.accessibilityPerformPress()); XCTAssertEqual(retries, 1)
                        view.keyDown(with: try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                            modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
                            characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36)))
                        XCTAssertEqual(retries, 2)
                    }
                }
            }
        }
    }

    func testResultFailureNavigationRendersAndKeepsBackAndRetryInTheirCorners() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let typography = try XCTUnwrap(GameMenuTypography(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings")))
        let output = root.appendingPathComponent(".build/result-failure-navigation")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for game in ["Classic", "Lemmings 2", "Lemmings 3"] {
            for state in ["loss", "hot-seat", "save-error"] {
                var footer: [GameFrontEnd.Action] = [
                    .init("0", state == "save-error" ? "TRY AGAIN" : state == "hot-seat" ? "RETRY AS PAL" : "RETRY", primary: true),
                    .init("1", "BACK"), .init("2", "MENU"),
                ]
                if state == "hot-seat" {
                    footer += [.init("3", "RETRY AS LEM"), .init("4", "LATER"), .init("5", "REVIEW")]
                }
                var page = GameFrontEnd.Page(title: state == "save-error" ? "Records were not saved" : "Try again",
                    subtitle: game, details: ["Saved 0/10   Goal 5"], footer: footer, preview: state != "save-error")
                page.result = state != "save-error"
                for size in [CGSize(width: 320, height: 568), .init(width: 390, height: 844), .init(width: 740, height: 330),
                             .init(width: 834, height: 1194), .init(width: 1194, height: 834), .init(width: 1920, height: 1080)] {
                    let layout = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
                    try verify(layout, page: page)
                    let menu = try XCTUnwrap(layout.targets.first { $0.action.id == "2" })
                    XCTAssertFalse(menu.action.isBackNavigation, "Remote Back must return to the library")
                    let context = try XCTUnwrap(CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height),
                        bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                    context.translateBy(x: 0, y: layout.size.height); context.scaleBy(x: 1, y: -1)
                    GameFrontEnd.draw(page, layout: layout, typography: typography, highlighted: "0", in: context)
                    let image = try XCTUnwrap(context.makeImage())
                    try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
                        .write(to: output.appendingPathComponent("\(game)-\(state)-\(Int(size.width)).png"))
                }
            }
        }
    }

    private func verify(_ layout: GameFrontEnd.Layout, page: GameFrontEnd.Page) throws {
        let footer = layout.targets.filter { page.footer.contains($0.action) }
        XCTAssertEqual(Set(footer.map { $0.action.id }), Set(page.footer.map(\.id)))
        let back = try XCTUnwrap(footer.first { $0.action.isBackNavigation })
        XCTAssertEqual(back.frame.minX, footer.map { $0.frame.minX }.min())
        XCTAssertEqual(back.frame.maxY, footer.map { $0.frame.maxY }.max())
        if let forward = footer.first(where: { $0.action.primary && !$0.action.isBackNavigation }) {
            XCTAssertEqual(forward.frame.maxY, back.frame.maxY)
            XCTAssertGreaterThan(forward.frame.minX, back.frame.maxX)
            XCTAssertEqual(forward.frame.maxX, footer.map { $0.frame.maxX }.max())
        }
        let ordered = footer.sorted { $0.frame.minY == $1.frame.minY ? $0.frame.minX < $1.frame.minX : $0.frame.minY < $1.frame.minY }
        XCTAssertEqual(footer.map(\.action), ordered.map(\.action))
        for (index, target) in layout.targets.enumerated() {
            XCTAssertTrue(CGRect(origin: .zero, size: layout.size).contains(target.frame))
            XCTAssertGreaterThanOrEqual(target.frame.width, 44)
            XCTAssertGreaterThanOrEqual(target.frame.height, 44)
            XCTAssertEqual(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)),
                           target.action.enabled ? target.action.id : nil)
            XCTAssertTrue(layout.targets.dropFirst(index + 1).allSatisfy { !$0.frame.intersects(target.frame) })
        }
    }

    func testBackKeepsItsCornerAsActionsAndColumnsChange() throws {
        for label in ["Back", "Back to game", "Cancel", "Library", "Close"] {
            for count in 1...8 {
                for columns in 1...3 {
                    for insertion in 0..<count {
                        var footer = (0..<count - 1).map { GameFrontEnd.Action("action.\($0)", "Action \($0)", enabled: $0 != 1) }
                        footer.insert(.init("back", label, enabled: insertion % 2 == 0), at: insertion)
                        if count > 1, let index = footer.lastIndex(where: { !$0.isBackNavigation }) { footer[index].primary = true }
                        let page = GameFrontEnd.Page(title: "Library", rows: [.init("item", "Level")], footer: footer, footerColumns: columns)
                        for width: CGFloat in [320, 900] {
                            try verify(GameFrontEnd.layout(page, width: width, minimumHeight: 620), page: page)
                        }
                    }
                }
            }
        }
    }

    func testResultHomeAndPinnedPauseUseTheSameNavigationRule() throws {
        let actions: [GameFrontEnd.Action] = [.init("retry", "Retry"), .init("hints", "Hints"),
            .init("later", "Try later"), .init("back", "Back"), .init("next", "Continue", primary: true)]
        let summary = MobilePauseSummary(level: .init(index: 0, rank: "Classic", number: 1, title: "Just Dig!"),
            snapshot: .init(tick: 0, released: 0, total: 10, saved: 0, required: 5, remainingSeconds: 120,
                releaseRate: 50, isComplete: false, didWin: false, isEndingRun: false, skills: []),
            activeCount: 0, ticksPerSecond: 17, speed: 1, assignedSkills: 0, supportsRewind: true,
            usedRewind: false, isReplay: false, soundtrack: "Original", track: "Intro", audio: "Music on")
        for width: CGFloat in [320, 390, 900, 1920] {
            var result = GameFrontEnd.Page(title: "Level complete", details: ["Saved 10 / 10"], footer: actions, preview: true)
            result.result = true
            try verify(GameFrontEnd.layout(result, width: width, minimumHeight: 720), page: result)
            let home = GameFrontEnd.Page(title: "Library", home: true, rows: [.init("classic", "Classic")], footer: actions)
            try verify(GameFrontEnd.layout(home, width: width, minimumHeight: 720), page: home)
            let pause = MobilePauseArt.page(summary, actions: actions)
            let base = GameFrontEnd.layout(pause, width: width, minimumHeight: 720)
            try verify(base, page: pause)
            for offset in [CGFloat(0), max(0, base.size.height - 720)] {
                let viewport = CGRect(x: 0, y: offset, width: width, height: 720)
                let pinned = MobilePauseArt.pinningFooter(base, viewport: viewport)
                try verify(pinned, page: pause)
                XCTAssertTrue(pinned.targets.allSatisfy { viewport.contains($0.frame) })
            }
        }
        let tv = TVMenuArt.layout(.init(title: "TV library", footer: actions))
        let back = try XCTUnwrap(tv.targets.first { $0.action.id == "back" })
        XCTAssertEqual(back.frame.minX, tv.targets.map { $0.frame.minX }.min())
    }

    @MainActor func testMacMessagesKeepBackFixedAndRetainKeyboardAndMouseTargets() throws {
        _ = NSApplication.shared
        var renderer: MacInterfaceRenderer?
        if let directory = ProcessInfo.processInfo.environment["LEMMINGS_TEST_MENU_ARTWORK"],
           let interface = ClassicMacUserInterface(artwork: try ClassicMacArtwork(directory: URL(fileURLWithPath: directory))) {
            renderer = MacInterfaceRenderer(interface: interface)
        }
        for size in [CGSize(width: 1120, height: 720), CGSize(width: 900, height: 620)] {
            let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let page = renderer.map { GameMenuArtwork.withRenderer($0) { GameMenuPage(title: "Return to the game?") } }
                ?? GameMenuPage(title: "Return to the game?")
            window.contentView = page
            page.layoutSubtreeIfNeeded()
            let back = page.controllerBackButton
            let original = back.convert(back.bounds, to: page)
            page.setDetail("Your saved run stays paused until you are ready.")
            XCTAssertEqual(back.convert(back.bounds, to: page), original)
            var forwardPresses = 0, backPresses = 0
            page.onBack = { backPresses += 1 }
            let forward = page.addPrimaryAction("Resume") { forwardPresses += 1 }
            page.layoutSubtreeIfNeeded()
            XCTAssertEqual(back.convert(back.bounds, to: page), original)
            let next = forward.convert(forward.bounds, to: page)
            XCTAssertGreaterThan(next.minX, original.maxX)
            XCTAssertEqual(original.maxY, next.maxY)
            for control in [back, forward] {
                let frame = control.convert(control.bounds, to: page)
                let point = page.convert(CGPoint(x: frame.midX, y: frame.midY), to: page.superview)
                XCTAssertTrue(page.hitTest(point) === control)
            }
            let navigation = DialogKeyboardNavigation()
            XCTAssertEqual(navigation.controls(in: page).compactMap { ($0 as? NSButton)?.title }, ["Back", "Resume"])
            back.performClick(nil); forward.performClick(nil)
            XCTAssertEqual(backPresses, 1); XCTAssertEqual(forwardPresses, 1)
            if let output = ProcessInfo.processInfo.environment["LEMMINGS_FOOTER_CAPTURES"] {
                func capture() throws {
                    let bitmap = try XCTUnwrap(page.bitmapImageRepForCachingDisplay(in: page.bounds))
                    func invalidate(_ view: NSView) { view.needsDisplay = true; view.subviews.forEach(invalidate) }
                    invalidate(page)
                    page.cacheDisplay(in: page.bounds, to: bitmap)
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(
                        to: URL(fileURLWithPath: output).appendingPathComponent("mac-message-\(Int(size.width)).png"))
                }
                if let renderer {
                    try GameMenuArtwork.withRenderer(renderer, capture)
                } else { try capture() }
            }
            window.close()
        }
    }

    @MainActor func testReplayAndMovieReturnControlsLeadTheirRows() throws {
        _ = NSApplication.shared
        let bar = ReplayBar(frame: CGRect(x: 0, y: 0, width: 900, height: 128))
        let window = NSWindow(contentRect: bar.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = bar
        defer { window.close() }
        var closed = false
        bar.onAction = { if case .close = $0 { closed = true } }
        let controls = try XCTUnwrap(bar.accessibilityChildren()).compactMap { $0 as? GameAccessibleElement }
        let back = try XCTUnwrap(controls.first { $0.accessibilityLabel() == "Back" })
        let play = try XCTUnwrap(controls.first { $0.accessibilityLabel() == "Play" })
        XCTAssertLessThan(back.localFrame.minX, play.localFrame.minX)
        XCTAssertTrue(back.accessibilityPerformPress()); XCTAssertTrue(closed)
        var bytes = Data(repeating: 0, count: 144)
        bytes[4] = 0x11; bytes[5] = 0xAF; bytes[6] = 1
        bytes[8] = 2; bytes[10] = 2; bytes[12] = 8
        bytes[128] = 16; bytes[132] = 0xFA; bytes[133] = 0xF1
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("footer-movie-\(UUID()).fli")
        try bytes.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let movie = try OriginalMoviePlayer(url: url)
        movie.frame = CGRect(x: 0, y: 0, width: 900, height: 620)
        movie.layoutSubtreeIfNeeded()
        let buttons = movie.subviews.compactMap { $0 as? NSButton }
        let movieBack = try XCTUnwrap(buttons.first { $0.title == "Back" })
        XCTAssertEqual(buttons.first?.title, "Back")
        XCTAssertEqual(movieBack.frame.minX, 12)
        XCTAssertTrue(buttons.filter { $0 !== movieBack }.allSatisfy { $0.frame.minX > movieBack.frame.maxX })
    }

    func testRenderedColumnFooters() throws {
        guard let directory = ProcessInfo.processInfo.environment["LEMMINGS_TEST_MENU_ARTWORK"],
              let output = ProcessInfo.processInfo.environment["LEMMINGS_FOOTER_CAPTURES"] else { return }
        let typography = try XCTUnwrap(GameMenuTypography(directory: URL(fileURLWithPath: directory)))
        for width: CGFloat in [390, 900, 1920] {
            for count in [3, 5, 7] {
                var footer = (0..<count - 2).map { GameFrontEnd.Action("action.\($0)", "Option \($0 + 1)", enabled: $0 != 1) }
                footer += [.init("back", "Back"), .init("continue", "Continue", primary: true)]
                let page = GameFrontEnd.Page(title: "Choose your next adventure", footer: footer)
                let layout = GameFrontEnd.layout(page, width: width, minimumHeight: 720)
                try verify(layout, page: page)
                let context = try XCTUnwrap(CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height),
                    bitsPerComponent: 8, bytesPerRow: Int(layout.size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.translateBy(x: 0, y: layout.size.height); context.scaleBy(x: 1, y: -1)
                GameFrontEnd.draw(page, layout: layout, typography: typography, in: context)
                let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(context.makeImage()))
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(
                    to: URL(fileURLWithPath: output).appendingPathComponent("columns-\(Int(width))-\(count).png"))
            }
        }
    }
}
#endif
