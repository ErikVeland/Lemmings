#if os(macOS)
import AppKit
import LemmingsAppCore
import XCTest
import NxlvKit
@testable import LemmingsLocal

final class NavigationJourneyTests: XCTestCase {
    @MainActor func testTimelineContainsOnlyTransportAndConsumesDisabledTargetsAndGaps() throws {
        let controls = TimelinePanelControls()
        let owner = NSView(frame: CGRect(x: 0, y: 0, width: 260, height: 38))
        controls.frame = CGRect(x: 4, y: 4, width: 252, height: 30)
        var performed: [TimelinePanelControls.Action] = []
        controls.perform = { performed.append($0) }
        controls.enabled = { $0 == .forward }
        let elements = controls.accessibleControls(owner: owner).compactMap { $0 as? GameAccessibleElement }
        XCTAssertEqual(elements.count, 3)
        XCTAssertFalse(elements.contains { ($0.accessibilityLabel() ?? "").localizedCaseInsensitiveContains("hint") })
        for action in TimelinePanelControls.Action.allCases {
            let frame = controls.rect(for: action)
            XCTAssertTrue(controls.frame.contains(frame))
            XCTAssertGreaterThanOrEqual(frame.width, 44)
            XCTAssertTrue(controls.click(at: CGPoint(x: frame.midX, y: frame.midY)))
        }
        XCTAssertEqual(performed, [.forward])
        let gap = controls.rect(for: .backward)
        XCTAssertTrue(controls.click(at: CGPoint(x: gap.maxX + 1, y: gap.midY)))
        XCTAssertEqual(performed, [.forward])
    }

    @MainActor func testHintsReturnToFailedResultWithoutRetryingOrPassingTheTurn() throws {
        _ = NSApplication.shared
        let previous = ArcadeStore.shared
        let storage = try AppStorage.temporary(named: "result-hint-return")
        let store = ArcadeStore(storage: storage, bundledProofs: nil)
        ArcadeStore.shared = store
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: window.contentView!.bounds)
        defer {
            GameScreen.shared.dismissAll(); window.close()
            ArcadeStore.shared = previous; storage.removeTemporaryFiles()
        }
        let level = ArcadeLevel(id: "hints", title: "Hint return", game: "Classic", rules: "test", total: 10, required: 5)
        let report = try XCTUnwrap(store.previewReport(for: .init(profileID: store.playingProfileID,
            level: level, saved: 0, didWin: false, skills: [:], seconds: 20)))
        let owner = store.playingProfileID
        var retries = 0
        ArcadeWindow.shared.showResult(report, owner: window, retry: { retries += 1 }, next: {}, replay: { _ in },
            later: {}, hints: {
                LevelHintWindow.shared.show(.practice(title: level.title, skills: ["Builder"]), owner: window)
            })
        let result = ArcadeWindow.shared.arcadeView
        result.onHints?()
        XCTAssertTrue(GameScreen.shared.contains(result))
        let hints = try XCTUnwrap(LevelHintWindow.shared.page)
        hints.controllerBackButton.performClick(nil)
        XCTAssertTrue(GameScreen.shared.controllerPage(in: window) === result)
        XCTAssertEqual(result.report?.run.id, report.run.id)
        XCTAssertEqual(store.playingProfileID, owner)
        XCTAssertEqual(retries, 0)
        result.onRetry?()
        XCTAssertEqual(retries, 1)
    }

    @MainActor func testPlayingReturnsToTheSameNestedBrowserAndBackRetracesItsParents() throws {
        _ = NSApplication.shared
        let screen = GameScreen.shared
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 900, height: 620))
        defer { screen.dismissAll(); window.close() }
        var closed = 0, played = 0
        let packs = GameMenuPage(title: "Fan levels")
        let pack = packs.addListAction("Selected pack", at: 0) {}
        screen.present(packs, owner: window, focus: pack, onDismiss: { closed += 1 })
        let levels = GameMenuPage(title: "Selected pack")
        let scroll = NSScrollView(frame: levels.body.bounds)
        scroll.documentView = NSView(frame: CGRect(x: 0, y: 0, width: 900, height: 4000))
        levels.body.addSubview(scroll)
        let play = levels.addPrimaryAction("Play") { played += 1 }
        screen.present(levels, owner: window, focus: play, onDismiss: { closed += 1 })
        scroll.contentView.scroll(to: CGPoint(x: 0, y: 700))
        let offset = scroll.contentView.bounds.origin
        let navigation = try XCTUnwrap(screen.retainNavigation())
        XCTAssertFalse(screen.isPresented)
        XCTAssertEqual(closed, 0)
        // A result and a new game root must not replace the retained browsing context.
        window.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 900, height: 620))
        screen.present(GameMenuPage(title: "Result"), owner: window)
        screen.restoreNavigation(navigation)
        XCTAssertTrue(screen.controllerPage(in: window) === levels)
        XCTAssertTrue(window.firstResponder === play)
        XCTAssertEqual(scroll.contentView.bounds.origin.x, offset.x, accuracy: 0.5)
        XCTAssertEqual(scroll.contentView.bounds.origin.y, offset.y, accuracy: 0.5)
        XCTAssertEqual(played, 0)
        screen.goBack(from: levels)
        XCTAssertTrue(screen.controllerPage(in: window) === packs)
        XCTAssertTrue(window.firstResponder === pack)
        XCTAssertEqual(closed, 1)
        screen.goBack(from: packs)
        XCTAssertFalse(screen.isPresented)
        XCTAssertEqual(closed, 2)
        screen.restoreNavigation(navigation)
        XCTAssertFalse(screen.isPresented, "A consumed return must not reopen an old browser")
    }

    @MainActor func testGlobalBackRetracesRecordPagesBeforeLeavingTheResult() throws {
        _ = NSApplication.shared
        let screen = GameScreen.shared
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { screen.dismissAll(); window.close() }
        let records = ArcadeView()
        var exits = 0
        records.mode = .result
        records.onMenu = { exits += 1 }
        screen.present(records, owner: window)
        records.page(.career)
        records.page(.records)
        screen.goBack(from: records)
        XCTAssertEqual(records.mode, .career)
        XCTAssertTrue(screen.contains(records))
        screen.goBack(from: records)
        XCTAssertEqual(records.mode, .result)
        XCTAssertEqual(exits, 0)
        screen.goBack(from: records)
        XCTAssertEqual(exits, 1)
    }

    @MainActor func testMainMenuDiscardsRetainedNavigationExactlyOnce() throws {
        _ = NSApplication.shared
        let screen = GameScreen.shared
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { screen.dismissAll(); window.close() }
        var closed = 0
        screen.present(GameMenuPage(title: "Levels"), owner: window, onDismiss: { closed += 1 })
        let navigation = try XCTUnwrap(screen.retainNavigation())
        navigation.cancel(); navigation.cancel()
        screen.restoreNavigation(navigation)
        XCTAssertEqual(closed, 1)
        XCTAssertFalse(screen.isPresented)
    }
}
#endif
