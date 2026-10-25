#if os(macOS)
import AppKit
import LemmingsAppCore
import LemmingsGameArt
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class FavouriteAndReturnTests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    @MainActor func testBackRetracesNestedRecordPagesAndNewEntryClearsHistory() {
        _ = NSApplication.shared
        let view = ArcadeView()
        var closed = 0
        view.onClose = { closed += 1 }
        view.mode = .result
        view.page(.career)
        view.page(.records)
        view.page(.details)
        view.back()
        XCTAssertEqual(view.mode, .records)
        view.back()
        XCTAssertEqual(view.mode, .career)
        XCTAssertEqual(view.backTitle, L10n.text("Back to result"))
        view.back()
        XCTAssertEqual(view.mode, .result)
        XCTAssertEqual(closed, 0)
        view.page(.goals)
        view.mode = .records
        view.boardScope = .level
        view.page(.career)
        view.page(.records, scope: .career)
        view.back()
        XCTAssertEqual(view.mode, .career)
        view.back()
        XCTAssertEqual(view.mode, .records)
        XCTAssertEqual(view.boardScope, .level)
        view.back()
        XCTAssertEqual(closed, 1)
    }

    @MainActor func testCancelConfirmationRestoresTheExactPageAndFocus() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 900, height: 620))
        defer { GameScreen.shared.dismissAll(); window.close() }
        let source = GameMenuPage(title: "Technique curriculum")
        let selected = source.addListAction("Builder", at: 0) {}
        GameScreen.shared.present(source, owner: window, focus: selected)
        var accepted = false
        GameScreen.shared.confirm("Replace?", detail: "Fixture", actionTitle: "Replace", owner: window) { accepted = true }
        let confirmation = try XCTUnwrap(GameScreen.shared.controllerPage(in: window) as? GameMenuPage)
        confirmation.controllerBackButton.performClick(nil)
        XCTAssertTrue(GameScreen.shared.controllerPage(in: window) === source)
        XCTAssertTrue(window.firstResponder === selected)
        XCTAssertFalse(accepted)
    }

    @MainActor func testFavouriteUsesOnlyAStarAtEveryWidthAndRetainsItsTarget() throws {
        _ = NSApplication.shared
        let output = root.appendingPathComponent(".build/favourite-return-captures")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for width: CGFloat in [44, 96, 232] {
            let button = GameFavouriteButton()
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: width, height: 48),
                styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = button
            defer { window.close() }
            var presses = 0
            button.onPress = { presses += 1 }
            for saved in [false, true] {
                button.showSaved(saved)
                XCTAssertEqual(button.accessibilityLabel(), saved ? L10n.text("Remove favourite") : L10n.text("Add favourite"))
                for enabled in [false, true] {
                    button.isEnabled = enabled
                    for focused in [false, true] {
                        window.makeFirstResponder(focused ? button : nil)
                        func render() throws -> Data {
                            let bitmap = try XCTUnwrap(button.bitmapImageRepForCachingDisplay(in: button.bounds))
                            button.needsDisplay = true
                            button.cacheDisplay(in: button.bounds, to: bitmap)
                            return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                        }
                        button.title = "Favourite"
                        let image = try render()
                        button.title = "A caption that must never be rendered"
                        XCTAssertEqual(try render(), image)
                        try image.write(to: output.appendingPathComponent("mac-\(Int(width))-\(saved)-\(enabled)-\(focused).png"))
                        XCTAssertTrue(button.hitTest(CGPoint(x: width / 2, y: 24)) === button)
                    }
                }
            }
            button.isEnabled = true
            button.performClick(nil)
            XCTAssertEqual(presses, 1)
        }
    }

    func testSharedFavouriteRenderIgnoresCaptionAndKeepsAccessibleAction() throws {
        let typography = try XCTUnwrap(GameMenuTypography(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings")))
        let output = root.appendingPathComponent(".build/favourite-return-captures")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for width: CGFloat in [320, 390, 740, 1194, 1920] {
            for saved in [false, true] {
                for enabled in [false, true] {
                    let action = GameFrontEnd.Action("favourite", saved ? "Remove favourite" : "Add favourite", enabled: enabled, selected: saved, icon: .favourite)
                    var page = GameFrontEnd.Page(title: "Level", footer: [action, .init("back", "Back"), .init("play", "Play", primary: true)])
                    func render() throws -> Data {
                        let layout = GameFrontEnd.layout(page, width: width, minimumHeight: 480)
                        let target = try XCTUnwrap(layout.targets.first { $0.action.id == "favourite" })
                        XCTAssertGreaterThanOrEqual(target.frame.width, 44)
                        XCTAssertGreaterThanOrEqual(target.frame.height, 44)
                        XCTAssertEqual(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)), enabled ? "favourite" : nil)
                        let context = try XCTUnwrap(CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height),
                            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                        context.translateBy(x: 0, y: layout.size.height); context.scaleBy(x: 1, y: -1)
                        GameFrontEnd.draw(page, layout: layout, typography: typography, highlighted: "favourite", in: context)
                        return try XCTUnwrap(NSBitmapImageRep(cgImage: try XCTUnwrap(context.makeImage())).representation(using: .png, properties: [:]))
                    }
                    let image = try render()
                    page.footer[0].title = "This caption must never affect the layout or drawing"
                    XCTAssertEqual(try render(), image)
                    try image.write(to: output.appendingPathComponent("shared-\(Int(width))-\(saved)-\(enabled).png"))
                }
            }
        }
    }

    @MainActor func testResultStarRendersAndTogglesForEveryGame() throws {
        _ = NSApplication.shared
        let storage = try AppStorage.temporary(named: "result-favourite")
        let previous = ArcadeStore.shared
        let store = ArcadeStore(storage: storage, bundledProofs: nil)
        ArcadeStore.shared = store
        defer { ArcadeStore.shared = previous; storage.removeTemporaryFiles() }
        let artwork = try ClassicMacArtwork(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        let font = MacInterfaceRenderer(interface: try XCTUnwrap(ClassicMacUserInterface(artwork: artwork)))
        let output = root.appendingPathComponent(".build/favourite-return-captures")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for engine in [LevelSourceEngine.classic, .lemmings2, .lemmings3] {
            let level = ArcadeLevel(id: engine.rawValue, title: "Favourite fixture", game: engine.displayName,
                rules: "fixture", total: 10, required: 5)
            let report = try XCTUnwrap(store.previewReport(for: .init(profileID: store.records.activeProfileID,
                level: level, saved: 5, didWin: true, skills: [:], seconds: 20)))
            let entry = try LevelPlaylistEntry(identity: .init(engine: engine, packID: "fixture", levelID: engine.rawValue),
                catalogueRevision: "fixture", sourceRevision: "fixture", packNameSnapshot: "Fixture",
                levelNameSnapshot: level.title, levelNumberSnapshot: 1)
            LevelCollections.record(entry, profileID: report.run.profileID, attemptID: report.run.id)
            for width: CGFloat in [900, 1120] {
                let view = ArcadeView(frame: CGRect(x: 0, y: 0, width: width, height: 720))
                let window = NSWindow(contentRect: view.bounds, styleMask: [.titled], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.contentView = view
                defer { window.close() }
                view.mode = .result; view.report = report; view.level = level; view.font = font
                for saved in [false, true] {
                    let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                    view.needsDisplay = true
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(
                        to: output.appendingPathComponent("result-\(engine.rawValue)-\(Int(width))-\(saved).png"))
                    let buttons = (view.accessibilityChildren() ?? []).compactMap { $0 as? GameAccessibleElement }
                        .filter { $0.accessibilityRole() == .button }
                    let star = try XCTUnwrap(buttons.first { $0.accessibilityLabel() == (saved ? L10n.text("Remove favourite") : L10n.text("Add favourite")) })
                    XCTAssertTrue(view.bounds.contains(star.localFrame))
                    XCTAssertTrue(buttons.filter { $0 !== star }.allSatisfy { !$0.localFrame.intersects(star.localFrame) })
                    XCTAssertTrue(star.accessibilityPerformPress())
                    XCTAssertEqual(LevelCollections.isFavourite(entry, profileID: report.run.profileID), !saved)
                }
            }
        }
    }
}
#endif
