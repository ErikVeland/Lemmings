import AppKit
import XCTest
import NxlvKit
@testable import LemmingsLocal

final class LearningJourneyDesktopTests: XCTestCase {
    func entry(_ index: Int) throws -> LevelPlaylistEntry {
        try .init(identity: .init(engine: .classic, packID: "test", levelID: "\(index)"),
            catalogueRevision: "v1", sourceRevision: "v1", packNameSnapshot: "Test",
            levelNameSnapshot: "Lesson \(index)", levelNumberSnapshot: index + 1)
    }

    @MainActor func testVisitsPersistAtomicallyAndOldDocumentsMigrate() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("playlists.json")
        try Data(#"{"version":2,"playlists":[]}"#.utf8).write(to: file)
        let store = try LevelPlaylistStore(file: file)
        let playlist = try LevelPlaylist(id: LearningJourney.playlistID, name: LearningJourney.title, entries: [entry(0), entry(1)])
        try store.add(playlist)
        let run = try LevelSequenceRun.playlist(playlist, pool: .init(id: "test", summary: "Test"))
        try store.startRun(run, hotSeatID: nil)
        let stale = try LevelPlaylistStore(file: file)
        XCTAssertThrowsError(try store.advanceLearningJourney(runID: UUID(), won: true))
        XCTAssertTrue(try store.advanceLearningJourney(runID: run.id, won: false))
        XCTAssertTrue(store.learningProgress.completed.isEmpty)
        XCTAssertEqual(store.learningProgress.later, [playlist.entries[0].identity])
        XCTAssertThrowsError(try stale.advanceLearningJourney(runID: run.id, won: true))
        XCTAssertTrue(stale.learningProgress.completed.isEmpty)
        let reloaded = try LevelPlaylistStore(file: file)
        XCTAssertEqual(reloaded.activeRun?.currentIndex, 1)
        XCTAssertEqual(reloaded.learningProgress, store.learningProgress)
        XCTAssertFalse(try reloaded.advanceLearningJourney(runID: run.id, won: true))
        XCTAssertEqual(reloaded.learningProgress.completed, [playlist.entries[1].identity])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        XCTAssertEqual(json["version"] as? Int, 3)
    }

    @MainActor func testLearningFailureActionsAndSharedEngineDefaults() throws {
        _ = NSApplication.shared
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let original = ArcadeStore.shared
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        ArcadeStore.shared = ArcadeStore(file: folder.appendingPathComponent("records.json"), bundledProofs: nil, defaults: defaults)
        defer { ArcadeStore.shared = original; try? FileManager.default.removeItem(at: folder) }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720), styleMask: [.titled], backing: .buffered, defer: false)
        let view = ArcadeView(frame: NSRect(x: 0, y: 0, width: 1120, height: 720))
        window.contentView = view
        var action = ""
        for engine in ["Classic", "Lemmings 2", "Lemmings 3"] {
            var records = ArcadeRecords()
            let level = ArcadeLevel(id: engine, title: "Just dig!", game: engine, rules: "test", total: 10, required: 5)
            let run = ArcadeRun(profileID: records.activeProfileID, level: level, saved: 0, didWin: false, skills: [:], seconds: 1)
            view.report = try XCTUnwrap(records.record(run)); view.level = level; view.mode = .result
            view.onRetry = { action = "retry" }
            view.onLater = engine == "Classic" ? { action = "later" } : nil
            view.onHints = engine == "Classic" ? { action = "hints" } : nil
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.displayIgnoringOpacity(view.bounds, in: NSGraphicsContext(bitmapImageRep: bitmap)!)
            let buttons = (view.accessibilityChildren() ?? []).compactMap { $0 as? GameAccessibleElement }.filter { $0.press != nil }
            for button in buttons { XCTAssertTrue(view.bounds.contains(button.localFrame), button.accessibilityLabel() ?? "") }
            let later = buttons.first { $0.accessibilityLabel() == "Try later" }
            if engine == "Classic" {
                XCTAssertTrue(try XCTUnwrap(later).accessibilityPerformPress()); XCTAssertEqual(action, "later")
                XCTAssertTrue(try XCTUnwrap(buttons.first { $0.accessibilityLabel() == "Hints" }).accessibilityPerformPress())
                XCTAssertEqual(action, "hints")
                if let path = ProcessInfo.processInfo.environment["LEMMINGS_LEARNING_SCREENSHOTS"] {
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path).appendingPathComponent("failure.png"))
                }
            } else { XCTAssertNil(later); XCTAssertFalse(buttons.contains { $0.accessibilityLabel() == "Hints" }) }
            XCTAssertTrue(try XCTUnwrap(buttons.first { $0.accessibilityLabel() == "Try again" }).accessibilityPerformPress())
            XCTAssertEqual(action, "retry")
        }
    }

    @MainActor func testJourneyPagesRenderWithUsableTargets() throws {
        _ = NSApplication.shared
        let value = try entry(0)
        let profile = DifficultyProfile(key: .init(identity: value.identity, levelRevision: "v1"),
            confidence: .medium, components: .init(), detectedTechniques: ["digger"])
        let journey = try LearningJourney.generate([.init(entry: value, profile: profile, isOfficial: true)])
        var action = ""
        let pages: [(String, GameMenuPage)] = [
            ("start", LearningJourneyMenu.hub(next: journey.lessons[0], solved: 0, total: 362, later: 0, resume: false, play: { action = "play" }, revisit: {})),
            ("resume", LearningJourneyMenu.hub(next: journey.lessons[0], solved: 4, total: 362, later: 2, resume: true, play: {}, revisit: {})),
            ("explored", LearningJourneyMenu.hub(next: nil, solved: 360, total: 362, later: 2, resume: false, play: {}, revisit: {})),
            ("complete", LearningJourneyMenu.hub(next: nil, solved: 362, total: 362, later: 0, resume: false, play: {}, revisit: {})),
            ("pause", LearningJourneyMenu.pause(title: "Just dig!", resume: {}, hints: {}, later: { action = "later" }, leave: {}))
        ]
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 1120, height: 720))
        GameScreen.shared.gameWindow = window
        defer { GameScreen.shared.dismissAll(); GameScreen.shared.gameWindow = nil }
        func controls(_ view: NSView) -> [NSButton] { (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(controls) }
        for (name, page) in pages {
            GameScreen.shared.present(page, owner: window)
            window.contentView?.layoutSubtreeIfNeeded(); page.layoutSubtreeIfNeeded()
            for button in controls(page) where button.isEnabled && !button.isHidden {
                let rect = button.convert(button.bounds, to: page)
                XCTAssertTrue(page.bounds.contains(rect), "\(name): \(button.title)")
                let hit = page.hitTest(NSPoint(x: rect.midX, y: rect.midY))
                XCTAssertTrue(hit === button || hit?.isDescendant(of: button) == true)
                XCTAssertTrue(window.makeFirstResponder(button))
            }
            if name == "start" { controls(page).first { $0.title == "Let's play" }?.performClick(nil); XCTAssertEqual(action, "play") }
            if name == "pause" { controls(page).first { $0.title == "Try later" }?.performClick(nil); XCTAssertEqual(action, "later") }
            if let folder = ProcessInfo.processInfo.environment["LEMMINGS_LEARNING_SCREENSHOTS"] {
                try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
                let bitmap = try XCTUnwrap(page.bitmapImageRepForCachingDisplay(in: page.bounds))
                page.cacheDisplay(in: page.bounds, to: bitmap)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: folder).appendingPathComponent(name + ".png"))
            }
            GameScreen.shared.dismiss(page)
        }
    }
}
