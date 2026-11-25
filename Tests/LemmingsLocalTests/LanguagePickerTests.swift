#if os(macOS)
import LemmingsAppCore
import LemmingsGameArt
import AppKit
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class LanguagePickerTests: XCTestCase {
    @MainActor private func withSettings(_ body: (NSView, NSWindow) throws -> Void) throws {
        _ = NSApplication.shared
        let original = GameLocalisation.currentLanguagePreference
        let stored = UserDefaults.standard.object(forKey: InterfaceLanguagePreference.defaultsKey)
        let previousWindow = GameScreen.shared.gameWindow
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 1280, height: 800))
        GameScreen.shared.gameWindow = window
        defer {
            GameScreen.shared.dismissAll()
            GameScreen.shared.gameWindow = previousWindow
            window.close()
            UserDefaults.standard.set(stored, forKey: InterfaceLanguagePreference.defaultsKey)
            GameLocalisation.setLanguage(original)
        }
        GameLocalisation.setLanguage(.system)
        InterfaceLanguagePreference.save(.system, to: .standard)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let resources = ProcessInfo.processInfo.environment["LEMMINGS_TEST_APP"].map {
            URL(fileURLWithPath: $0).appendingPathComponent("Contents/Resources/MacArtwork/lemmings")
        } ?? root.appendingPathComponent(".build/mac-artwork/export/lemmings")
        let artwork = try ClassicMacArtwork(directory: resources)
        let renderer = MacInterfaceRenderer(interface: try XCTUnwrap(ClassicMacUserInterface(artwork: artwork)))
        try GameMenuArtwork.withRenderer(renderer) {
            let settings = SettingsWindow(settings: ClassicSettings(), options: .available(
                hasDOSData: true, hasAmigaDisk: false, hasMacintoshDisk: false, moduleCount: 0))
            settings.show()
            try withExtendedLifetime(settings) { try body(XCTUnwrap(window.contentView), window) }
        }
    }

    @MainActor func testSettingsSidebarGroupsNavigationBesideTheActivePane() throws {
        let previous = GameScreen.shared.onMainMenu
        GameScreen.shared.onMainMenu = {}
        defer { GameScreen.shared.onMainMenu = previous }
        try withSettings { host, window in
            let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent(".build/grouped-settings-renders")
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            let groups = [GameLocalisation.text("Gameplay"), GameLocalisation.text("Controls"),
                GameLocalisation.text("Accessibility"), GameLocalisation.text("Display"),
                GameLocalisation.text("Artwork"), GameLocalisation.text("Audio"), GameLocalisation.text("Privacy")]
            for width: CGFloat in [900, 1280] {
                window.setContentSize(CGSize(width: width, height: width == 900 ? 620 : 800))
                host.layoutSubtreeIfNeeded()
                let page = try XCTUnwrap(GameScreen.shared.controllerPage(in: window) as? GameMenuPage)
                let buttons = descendants(page).compactMap { $0 as? GameTabButton }
                XCTAssertEqual(buttons.map(\.title), groups)
                let frames = buttons.map { $0.convert($0.bounds, to: page) }
                XCTAssertEqual(Set(frames.map(\.minX)).count, 1)
                XCTAssertGreaterThan(frames[3].minY - frames[2].maxY, frames[1].minY - frames[0].maxY)
                XCTAssertGreaterThan(frames[6].minY - frames[5].maxY, frames[1].minY - frames[0].maxY)
                let back = page.controllerBackButton.convert(page.controllerBackButton.bounds, to: page)
                XCTAssertEqual(back.minX, frames[0].minX, accuracy: 0.5)
                XCTAssertLessThan(back.minY - frames[6].maxY, frames[6].height)
                let navigation = try XCTUnwrap(GameScreen.shared.controllerNavigationRoot(in: window))
                let keyboardOrder = GameScreen.shared.keyboardNavigation.controls(in: navigation)
                XCTAssertEqual(Array(keyboardOrder.prefix(buttons.count)), buttons)
                for (index, button) in buttons.enumerated() {
                    try click(button, in: host)
                    XCTAssertEqual(button.state, .on)
                    XCTAssertEqual(buttons.filter { $0.state == .on }.count, 1)
                    if [0, 3, 6].contains(index) {
                        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                        host.displayIgnoringOpacity(host.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)))
                        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                            .write(to: output.appendingPathComponent("mac-\(Int(width))-\(groups[index]).png"))
                    }
                    if index == 0 {
                        let last = try XCTUnwrap(descendants(page).compactMap { $0 as? GamePopUpButton }
                            .first { $0.accessibilityLabel() == GameLocalisation.text("Level selection") })
                        let scroll = try XCTUnwrap(last.enclosingScrollView)
                        last.scrollToVisible(last.bounds)
                        host.layoutSubtreeIfNeeded()
                        XCTAssertGreaterThanOrEqual(last.bounds.height, 28)
                        XCTAssertTrue(scroll.documentVisibleRect.contains(last.frame))
                        let centre = last.convert(CGPoint(x: last.bounds.midX, y: last.bounds.midY), to: host)
                        XCTAssertTrue(host.hitTest(centre) === last)
                        scroll.contentView.scroll(to: .zero)
                        scroll.reflectScrolledClipView(scroll.contentView)
                    }
                }
            }
        }
    }

    @MainActor func testSelectionTargetsPreviewApplyAndCancel() throws {
        try withSettings { host, window in
            openPicker(in: host)
            let french = try language(.french, in: host)
            try click(french, in: host)
            XCTAssertEqual(GameLocalisation.currentLanguagePreference, .french)
            XCTAssertEqual(GameLocalisation.interface.language, "fr")
            XCTAssertEqual(InterfaceLanguagePreference.load(from: .standard), .system)
            XCTAssertEqual(try language(.french, in: host).state, .on)
            XCTAssertEqual(try language(.system, in: host).state, .off)
            let picker = try XCTUnwrap(GameScreen.shared.controllerPage(in: window) as? GameMenuPage)
            picker.controllerBackButton.performClick(nil)
            XCTAssertEqual(GameLocalisation.currentLanguagePreference, .system)

            openPicker(in: host)
            try click(try language(.french, in: host), in: host)
            let apply = try XCTUnwrap(descendants(host).compactMap { $0 as? GameActionButton }
                .first { $0.title == GameLocalisation.text("Apply") && !$0.isHiddenOrHasHiddenAncestor })
            apply.performClick(nil)
            XCTAssertEqual(InterfaceLanguagePreference.load(from: .standard), .french)
            openPicker(in: host)
            XCTAssertEqual(try language(.french, in: host).state, .on)
            try click(try language(.system, in: host), in: host)
            let reopened = try XCTUnwrap(GameScreen.shared.controllerPage(in: window) as? GameMenuPage)
            reopened.controllerBackButton.performClick(nil)
            XCTAssertEqual(GameLocalisation.currentLanguagePreference, .french)
            XCTAssertEqual(InterfaceLanguagePreference.load(from: .standard), .french)
        }
    }

    @MainActor func testEveryLanguageRetainsMouseKeyboardAccessibilityAndRenderedStates() throws {
        try withSettings { host, window in
            openPicker(in: host)
            let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent()
            let output = root.appendingPathComponent(".build/language-picker-renders")
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            for size in [CGSize(width: 900, height: 620), CGSize(width: 1280, height: 800)] {
                window.setContentSize(size)
                for choice in GameLocalisation.languageOptions {
                    for fraction: CGFloat in [0.02, 0.5, 0.98] {
                        try click(try language(choice, in: host), in: host, fraction: fraction)
                        XCTAssertEqual(GameLocalisation.currentLanguagePreference, choice)
                    }
                    let selected = try language(choice, in: host)
                    XCTAssertEqual(selected.state, .on)
                    XCTAssertEqual(selected.accessibilityRole(), .radioButton)
                    XCTAssertEqual((selected.accessibilityValue() as? NSNumber)?.intValue, 1)
                    XCTAssertTrue(window.firstResponder === selected)
                    let choices = descendants(host).compactMap { $0 as? GameButton }
                        .filter { !$0.isHiddenOrHasHiddenAncestor }
                    XCTAssertEqual(choices.filter { $0.state == .on }.count, 1)
                    if [.english, .french, .tamil].contains(choice) {
                        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                        host.displayIgnoringOpacity(host.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)))
                        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(
                            to: output.appendingPathComponent("picker-\(Int(size.width))-\(choice.rawValue).png"))
                    }
                }
                let english = try language(.english, in: host)
                GameScreen.shared.keyboardNavigation.focus(english, in: window)
                let page = try XCTUnwrap(GameScreen.shared.controllerPage(in: window))
                XCTAssertTrue(GameScreen.shared.keyboardNavigation.handle(try XCTUnwrap(NSEvent.keyEvent(with: .keyDown,
                    location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                    context: nil, characters: " ", charactersIgnoringModifiers: " ", isARepeat: false, keyCode: 49)),
                    in: page, window: window, dismiss: {}))
                XCTAssertEqual(GameLocalisation.currentLanguagePreference, .english)
                _ = try language(.french, in: host).accessibilityPerformPress()
                XCTAssertEqual(GameLocalisation.currentLanguagePreference, .french)
            }
        }
    }

    @MainActor func testReleaseNotesUseCurrentVersionAndRetainTranslatedTargets() throws {
        try withSettings { host, window in
            let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent()
            let info = try XCTUnwrap(NSDictionary(contentsOf: root.appendingPathComponent("Resources/Info.plist")))
            XCTAssertEqual(ReleaseWelcome.notesVersion, info["CFBundleShortVersionString"] as? String)
            let output = root.appendingPathComponent(".build/language-picker-renders")
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            for choice in GameLocalisation.languageOptions where choice != .system {
                GameScreen.shared.dismissAll()
                GameLocalisation.setLanguage(choice)
                XCTAssertEqual(ReleaseWelcome.subtitle, GameLocalisation.text("Pull up a chair. We've got a level to finish."))
                let expectedHeading = AppDistribution.isStore && !GameMenuLogo.usesRestoredArtwork
                    ? GameLocalisation.text("Ultimate Lemmix") : GameLocalisation.text("Home and Play")
                XCTAssertEqual(ReleaseWelcome.sections.first?.0, expectedHeading)
                if choice != .english {
                    XCTAssertNotEqual(GameLocalisation.text("Continue"), "Continue")
                }
                let welcome = ReleaseWelcome(build: 88, version: ReleaseWelcome.notesVersion)
                var continued = false
                welcome.show(in: window) { continued = true }
                let page = try XCTUnwrap(GameScreen.shared.controllerPage(in: window) as? GameMenuPage)
                for size in [CGSize(width: 900, height: 620), CGSize(width: 1280, height: 800)] {
                    window.setContentSize(size)
                    host.layoutSubtreeIfNeeded()
                    let notes = try XCTUnwrap(page.body.subviews.first as? AboutMarkdownView)
                    let scroll = notes.scroll
                    let document = try XCTUnwrap(scroll.documentView)
                    XCTAssertTrue(document.subviews.allSatisfy { document.bounds.contains($0.frame) })
                    let action = try XCTUnwrap(page.controllerInitialControl as? NSButton)
                    action.scrollToVisible(action.bounds)
                    let frame = action.convert(action.bounds, to: page)
                    XCTAssertTrue(page.bounds.contains(frame))
                    XCTAssertFalse(frame.intersects(scroll.convert(scroll.bounds, to: page)))
                    XCTAssertTrue(host.hitTest(action.convert(CGPoint(x: action.bounds.midX, y: action.bounds.midY), to: host)) === action)
                    let bitmap = try XCTUnwrap(page.bitmapImageRepForCachingDisplay(in: page.bounds))
                    page.displayIgnoringOpacity(page.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)))
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(
                        to: output.appendingPathComponent("welcome-\(Int(size.width))-\(choice.rawValue).png"))
                }
                page.controllerInitialControl.performClick(nil)
                XCTAssertTrue(continued)
                XCTAssertFalse(GameScreen.shared.contains(page))
            }
        }
    }

    @MainActor private func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(descendants)
    }

    @MainActor private func openPicker(in host: NSView) {
        host.layoutSubtreeIfNeeded()
        let popup = descendants(host).compactMap { $0 as? GamePopUpButton }
            .first { $0.itemTitles == GameLocalisation.languageOptions.map(\.title) }
        XCTAssertNotNil(popup)
        popup?.performClick(nil)
        host.layoutSubtreeIfNeeded()
    }

    @MainActor private func language(_ language: InterfaceLanguage, in host: NSView) throws -> NSButton {
        host.layoutSubtreeIfNeeded()
        return try XCTUnwrap(descendants(host).compactMap { $0 as? NSButton }
            .first { $0.title == language.title && !$0.isHiddenOrHasHiddenAncestor })
    }

    @MainActor private func click(_ button: NSButton, in host: NSView, fraction: CGFloat = 0.5) throws {
        button.scrollToVisible(button.bounds)
        host.layoutSubtreeIfNeeded()
        let centre = CGPoint(x: button.bounds.width * fraction, y: button.bounds.midY)
        XCTAssertTrue(host.hitTest(button.convert(centre, to: host)) === button)
        let point = button.convert(centre, to: nil)
        let window = try XCTUnwrap(button.window)
        let down = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point,
            modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1))
        let hit = try XCTUnwrap(button.cell).hitTest(for: down, in: button.bounds, of: button)
        XCTAssertTrue(hit.contains(.trackableArea), "The visible stone button must accept clicks across its face")
        if hit.contains(.trackableArea) { button.performClick(nil) }
    }
}
#endif
