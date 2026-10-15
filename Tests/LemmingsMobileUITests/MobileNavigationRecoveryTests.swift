#if os(iOS) || os(tvOS)
import Foundation
import Testing
import UIKit
import NxlvKit
import LemmingsMobileCore
@testable import LemmingsMobileUI

@MainActor struct MobileNavigationRecoveryTests {
    private func withGame(rendered: @escaping () -> Void = {},
                          _ body: (MobileGameViewController) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let previous = UserDefaults.standard.object(forKey: MobileSettings.activeProfileKey)
        let runtime = try Lemmings3Runtime(configuration: .init(width: 128, height: 64,
            attributes: [UInt16](repeating: 0, count: 128 * 64), entrance: .init(x: 20, y: 20),
            exits: [], total: 1, releaseInterval: 20, releaseDelay: 0))
        let session = Lemmings3MobileSession(runtime: runtime, engineFingerprint: "fixture", levelIdentifier: "fixture",
            levelIndex: 0, levelFingerprint: "fixture", renderer: { _, _ in
                rendered()
                return try MobilePixelFrame(width: 128, height: 64, rgba: Data(repeating: 0, count: 128 * 64 * 4))
            })
        let controller = MobileGameViewController(summary: .init(index: 0, rank: "Classic", number: 1, title: "Fixture"),
            session: session, checkpointStore: .init(url: root.appendingPathComponent("current.json")),
            restoredCheckpoint: nil, settingsProfileID: "navigation-test")
        defer {
            controller.viewDidDisappear(false)
            UserDefaults.standard.set(previous, forKey: MobileSettings.activeProfileKey)
            try? FileManager.default.removeItem(at: root)
        }
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 834, height: 1194)
        try await body(controller)
    }

    #if os(tvOS)
    @Test func controllerSkillBurstsDrawOnceWithoutWaitingForPhysics() async throws {
        var renders = 0
        try await withGame(rendered: { renders += 1 }) { game in
            game.gameSettings.pauseToAssign = false
            let resumed = game.playState.resume(isForeground: true, isInterrupted: false)
            let planning = game.playState.pauseForPlanning()
            #expect(resumed && planning)
            game.overlay.isHidden = true
            let tick = game.session.snapshot.tick
            let before = renders
            for skill in [1, 2, 0, 1, 2] {
                game.processTVControllerButtonEvent { game.performCommand(.skill(skill)) }
                #expect(game.selectedControl == skill)
                #expect(renders == before)
                #expect(!game.pollingController)
            }
            game.flushControllerFrameUpdates()
            #expect(renders == before + 1)
            #expect(game.playfieldView.cursorSkillName == game.session.snapshot.skills[2].name)
            #expect(game.session.snapshot.tick == tick)
            game.flushControllerFrameUpdates()
            #expect(renders == before + 1)
        }
    }

    @Test func controllerBatchCannotSelectThroughReadyOrSuspension() async throws {
        try await withGame { game in
            let selected = game.selectedControl
            game.processTVControllerButtonEvent { game.performCommand(.skill(1)) }
            #expect(game.selectedControl == selected && game.playState.phase == .ready)
            let resumed = game.playState.resume(isForeground: true, isInterrupted: false)
            #expect(resumed)
            game.overlay.isHidden = true
            _ = game.lifecycle.handle(.becameInactive)
            game.processTVControllerButtonEvent { game.performCommand(.skill(1)) }
            #expect(game.selectedControl == selected)
            #expect(!game.pollingController)
        }
    }
    #endif

    @Test func helpReturnsToReadyWithoutStartingTheAttempt() async throws {
        try await withGame { game in
            game.pausePlay(showControls: false)
            game.showControlsHelp()
            game.overlayCanvas.goBack()
            #expect(game.playState.phase == .ready)
            #expect(game.overlayCanvas.page.footer.contains { $0.title == L10n.text("START") })
            #expect(game.session.snapshot.tick == 0)
        }
    }

    @Test func settingsRefreshThePausedPlayfieldImmediately() async throws {
        try await withGame { game in
            game.pausePlay(showControls: false)
            let state = game.session.snapshot
            for display in ClassicDisplayMode.allCases {
                var settings = game.gameSettings
                settings.classic.display = display
                settings.classic.graphics = .macintoshMonochrome
                settings.classic.hdEffectsEnabled.toggle()
                game.applyGameSettings(settings)
                #expect(game.playfieldView.displaySettings == settings.classic)
                #expect(game.gameSettings == settings)
                #expect(game.playState.phase == .ready)
                #expect(game.session.snapshot == state)
            }
        }
    }

    @Test func anImmediateEndShowsResultsAndSubpageBackRestoresThem() async throws {
        try await withGame { game in
            #expect(game.session.beginEndRun())
            game.pausePlay(showControls: true)
            #expect(game.overlayCanvas.page.result)
            game.showControlsHelp()
            game.overlayCanvas.goBack()
            #expect(game.overlayCanvas.page.result)
            #expect(!game.overlayCanvas.page.footer.contains { $0.title == L10n.text("RESUME") })
            game.showRecoveryOverlay(title: "Fixture", retry: {})
            game.overlayCanvas.goBack()
            #expect(game.overlayCanvas.page.result)
        }
    }

    @Test func recordSaveErrorsCanLeaveWithoutRetiringTheCheckpoint() async throws {
        try await withGame { game in
            var exit: MobileGameExitAction?
            game.onExit = { exit = $0 }
            game.onRecordCompletion = { _ in ([], "Fixture save failure") }
            #expect(game.session.beginEndRun())
            game.pausePlay(showControls: true)
            let menu = try #require(game.overlayCanvas.page.footer.first { $0.title == L10n.text("MENU") })
            game.overlayCanvas.onAction?(menu.id)
            #expect(exit == .menu)
        }
    }

    @Test func cancellingASaveDoesNotExitAfterTheWriterFinishes() async throws {
        try await withGame { game in
            var exited = false
            game.onExit = { _ in exited = true }
            game.leaveToLibrary()
            #expect(game.overlayCanvas.page.backAction?.title == L10n.text("CANCEL"))
            game.overlayCanvas.goBack()
            for _ in 0..<20 { await Task.yield() }
            #expect(!exited)
            #expect(game.playState.phase == .ready)
        }
    }

    @Test func leavingHintsInvalidatesThePendingResponse() async throws {
        try await withGame { game in
            game.showHints()
            let request = game.hintRequestID
            game.overlayCanvas.goBack()
            #expect(game.hintRequestID != request)
            let page = game.overlayCanvas.page
            for _ in 0..<20 { await Task.yield() }
            #expect(game.overlayCanvas.page == page)
        }
    }
}
#endif
