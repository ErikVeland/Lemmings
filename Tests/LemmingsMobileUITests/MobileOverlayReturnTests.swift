#if os(iOS) || os(tvOS)
import Foundation
import Testing
import UIKit
import LemmingsGameArt
import NxlvKit
import LemmingsMobileCore
@testable import LemmingsMobileUI

#if os(iOS)
@MainActor private final class MenuBackFixtureGesture: UIScreenEdgePanGestureRecognizer {
    override var state: UIGestureRecognizer.State { get { .ended } set {} }
    override func translation(in view: UIView?) -> CGPoint { CGPoint(x: 90, y: 0) }
    override func velocity(in view: UIView?) -> CGPoint { CGPoint(x: 0, y: 0) }
}
#endif

@MainActor struct MobileOverlayReturnTests {
    private func withGame(_ body: @MainActor (MobileGameViewController) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let previous = UserDefaults.standard.object(forKey: MobileSettings.activeProfileKey)
        let runtime = try Lemmings3Runtime(configuration: .init(width: 128, height: 64,
            attributes: [UInt16](repeating: 0, count: 128 * 64), entrance: .init(x: 20, y: 20),
            exits: [.init(x: 110, y: 46)], total: 1, releaseInterval: 20, releaseDelay: 0))
        let session = Lemmings3MobileSession(runtime: runtime, engineFingerprint: "fixture", levelIdentifier: "fixture",
            levelIndex: 0, levelFingerprint: "fixture", renderer: { _, _ in
                try MobilePixelFrame(width: 128, height: 64, rgba: Data(repeating: 0, count: 128 * 64 * 4))
            })
        let game = MobileGameViewController(summary: .init(index: 0, rank: "Tribe", number: 1, title: "Fixture"),
            session: session, checkpointStore: .init(url: directory.appendingPathComponent("current.json")),
            restoredCheckpoint: nil, settingsProfileID: "overlay-return-test")
        defer {
            game.viewDidDisappear(false)
            UserDefaults.standard.set(previous, forKey: MobileSettings.activeProfileKey)
            try? FileManager.default.removeItem(at: directory)
        }
        game.loadViewIfNeeded()
        game.view.frame = CGRect(x: 0, y: 0, width: 834, height: 1194)
        game.view.layoutIfNeeded()
        try await body(game)
    }

    @Test func helpAndRestartCancelRestoreTheCallerAndItsActions() async throws {
        try await withGame { game in
            var presses = 0
            game.showCustomOverlay(title: "Game controls", details: ["Fixture"], actions: [
                ("Back", { presses += 1 }), ("Selected action", { presses += 10 }),
            ])
            game.overlayCanvas.focusedID = "1"
            let source = game.overlayCanvas.page
            for open in [game.showControlsHelp, game.showRestartLevel] {
                open()
                game.overlayCanvas.goBack()
                #expect(game.overlayCanvas.page == source)
                #expect(game.overlayCanvas.focusedID == "1")
                #expect(game.playState.phase == .ready && game.session.snapshot.tick == 0)
                game.overlayCanvas.onAction?("1")
            }
            #expect(presses == 20)
        }
    }

    @Test func hintStagesReturnToTheOriginalCallerWithoutStartingReady() async throws {
        try await withGame { game in
            var presses = 0
            game.showCustomOverlay(title: "Game controls", details: ["Fixture"], actions: [
                ("Back", {}), ("Selected action", { presses += 1 }),
            ])
            game.overlayCanvas.focusedID = "1"
            let source = game.overlayCanvas.page
            game.showHints(stage: 1)
            for _ in 0..<200 where game.overlayCanvas.page.details.contains(L10n.text("Loading...")) {
                try await Task.sleep(for: .milliseconds(5))
            }
            #expect(!game.overlayCanvas.page.details.contains(L10n.text("Loading...")))
            game.overlayCanvas.goBack()
            #expect(game.overlayCanvas.page == source)
            #expect(game.overlayCanvas.focusedID == "1")
            #expect(game.playState.phase == .ready && game.session.snapshot.tick == 0)
            game.overlayCanvas.onAction?("1")
            #expect(presses == 1)
        }
    }

    @Test func landscapeSettingsTabsReturnToTheOriginalPausedCaller() async throws {
        try await withGame { game in
            let library = MobileLibraryViewController()
            library.view.frame = CGRect(x: 0, y: 0, width: 1194, height: 834)
            library.addChild(game)
            defer { game.willMove(toParent: nil); game.removeFromParent() }
            game.view.frame = library.view.bounds
            game.showCustomOverlay(title: "Caller", details: [], actions: [("Back", {})])
            let caller = game.overlayCanvas.page
            let snapshot = game.session.snapshot
            game.showInGameSettings()
            #expect(game.overlayCanvas.page.settingsTabs?.first(where: { $0.selected })?.id == "settingsTab.gameplay")
            for id in ["settingsTab.audio", "settingsTab.privacy", "settingsTab.controller"] {
                game.settingsTabs.activate(id)
                #expect(game.overlayCanvas.page.settingsTabs?.first(where: { $0.selected })?.id == id)
                #expect(game.playState.phase == .ready && game.session.snapshot == snapshot)
                #expect(game.globalNavigation.frame.minY >= game.overlay.frame.maxY)
            }
            game.overlayCanvas.goBack()
            #expect(game.overlayCanvas.page == caller)
            #expect(game.playState.phase == .ready && game.session.snapshot == snapshot)
        }
    }

    @Test func settingsBackRetracesTheGroupAndCaller() async throws {
        try await withGame { game in
            let library = MobileLibraryViewController()
            library.addChild(game)
            defer { game.willMove(toParent: nil); game.removeFromParent() }
            game.showCustomOverlay(title: "Caller", details: [], actions: [("Back", {})])
            let caller = game.overlayCanvas.page
            game.showInGameSettings()
            let settings = game.overlayCanvas.page
            game.overlayCanvas.onAction?("settingsGroup.gameplay")
            #expect(game.overlayCanvas.page != settings)
            game.overlayCanvas.goBack()
            #expect(game.overlayCanvas.page == settings)
            game.overlayCanvas.goBack()
            #expect(game.overlayCanvas.page == caller)
            #expect(game.playState.phase == .ready)
        }
    }

    @Test func saveCancelRestoresTheCallerWithoutExitingLater() async throws {
        try await withGame { game in
            var exits = 0
            game.onExit = { _ in exits += 1 }
            game.showCustomOverlay(title: "Game controls", details: ["Fixture"], actions: [("Back", {})])
            let source = game.overlayCanvas.page
            game.leaveToLibrary()
            game.overlayCanvas.goBack()
            for _ in 0..<20 { await Task.yield() }
            #expect(game.overlayCanvas.page == source)
            #expect(game.playState.phase == .ready && exits == 0)
        }
    }

    @Test func mainMenuSaveCanBeCancelledWithoutExitingLater() async throws {
        try await withGame { game in
            var exits = 0
            game.onExit = { _ in exits += 1 }
            game.showCustomOverlay(title: "Settings", details: ["Fixture"], actions: [("Back", {})])
            let source = game.overlayCanvas.page
            game.leaveToMainMenu()
            game.overlayCanvas.goBack()
            for _ in 0..<20 { await Task.yield() }
            #expect(game.overlayCanvas.page == source)
            #expect(game.playState.phase == .ready && exits == 0)
            #expect(game.globalNavigation.isUserInteractionEnabled)
        }
    }

    #if os(iOS)
    @Test func edgeBackUsesTheVisibleMenusReturnActionAndIsDisabledDuringPlay() async throws {
        try await withGame { game in
            var backs = 0
            game.showCustomOverlay(title: "Controls", details: [], actions: [("Back", { backs += 1 })])
            let gesture = try #require(game.view.gestureRecognizers?.first { $0 is UIScreenEdgePanGestureRecognizer })
            #expect(gesture.isEnabled)
            game.perform(NSSelectorFromString("menuEdgeBack:"), with: MenuBackFixtureGesture())
            #expect(backs == 1)
            game.overlay.isHidden = true
            #expect(!gesture.isEnabled && game.globalNavigation.isHidden)
            game.perform(NSSelectorFromString("menuEdgeBack:"), with: MenuBackFixtureGesture())
            #expect(backs == 1 && game.session.snapshot.tick == 0)
        }
    }
    #endif
}
#endif
