#if os(iOS) || os(tvOS)
import Foundation
import Testing
import UIKit
import GameController
import NxlvKit
import LemmingsGameArt
import LemmingsMobileCore
@testable import LemmingsMobileUI

#if os(iOS)
@MainActor private final class PointerFixtureHover: UIHoverGestureRecognizer {
    var fixtureState: UIGestureRecognizer.State = .changed
    override var state: UIGestureRecognizer.State { get { fixtureState } set { fixtureState = newValue } }
    override func location(in view: UIView?) -> CGPoint { CGPoint(x: 80, y: 60) }
}
#endif

@MainActor struct MobileNavigationRecoveryTests {
    private func withGame(turn: MobileGameTurn? = nil, rendered: @escaping () -> Void = {},
                          _ body: @MainActor (MobileGameViewController) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let previous = UserDefaults.standard.object(forKey: MobileSettings.activeProfileKey)
        let runtime = try Lemmings3Runtime(configuration: .init(width: 128, height: 64,
            attributes: [UInt16](repeating: 0, count: 128 * 64), entrance: .init(x: 20, y: 20),
            exits: [.init(x: 110, y: 46)], total: 1, releaseInterval: 20, releaseDelay: 0))
        let session = Lemmings3MobileSession(runtime: runtime, engineFingerprint: "fixture", levelIdentifier: "fixture",
            levelIndex: 0, levelFingerprint: "fixture", renderer: { _, _ in
                rendered()
                return try MobilePixelFrame(width: 128, height: 64, rgba: Data(repeating: 0, count: 128 * 64 * 4))
            })
        let controller = MobileGameViewController(summary: .init(index: 0, rank: "Classic", number: 1, title: "Fixture"),
            session: session, checkpointStore: .init(url: root.appendingPathComponent("current.json")),
            restoredCheckpoint: nil, turn: turn, settingsProfileID: "navigation-test")
        defer {
            controller.viewDidDisappear(false)
            UserDefaults.standard.set(previous, forKey: MobileSettings.activeProfileKey)
            try? FileManager.default.removeItem(at: root)
        }
        controller.loadViewIfNeeded()
        _ = controller.inputAdapter
        controller.view.frame = CGRect(x: 0, y: 0, width: 834, height: 1194)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
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

    #if os(iOS)
    @Test func pauseTargetStopsOnTouchDownAndPlayWaitsForRelease() async throws {
        try await withGame { game in
            game.resumePlay()
            game.pauseForPlanning()
            game.resumePlay()
            let layout = MobileHUDLayout.make(container: .init(width: game.view.bounds.width, height: game.view.bounds.height),
                safeArea: .init(), hasRate: game.session.snapshot.releaseRate != nil,
                skillCount: game.session.snapshot.skills.count, supportsRewind: game.session.supportsRewind,
                hasPlayer: true, engineIdentifier: game.session.engineIdentifier)
            let target = try #require(MobileHUDRenderer.targets(layout: layout, snapshot: game.session.snapshot,
                selectedSkill: game.selectedControl, paused: false, speed: 1, endRunArmed: false).first { $0.action == .pause })
            let point = CGPoint(x: target.inputFrame.midX, y: target.inputFrame.midY)
            let button = try #require(game.hud.hitTest(point, with: nil) as? UIControl)
            #expect(button.accessibilityLabel == L10n.text("Pause, hold for pause menu"))
            @MainActor func renderedButton(_ name: String) throws -> Data {
                game.hud.layer.displayIfNeeded()
                let image = UIGraphicsImageRenderer(size: target.inputFrame.size).image { context in
                    context.cgContext.translateBy(x: -target.inputFrame.minX, y: -target.inputFrame.minY)
                    game.hud.layer.render(in: context.cgContext)
                }
                let data = try #require(image.pngData())
                if let path = ProcessInfo.processInfo.environment["LEMMINGS_PAUSE_RENDER_DIR"] {
                    let directory = URL(fileURLWithPath: path)
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    try data.write(to: directory.appendingPathComponent(name + ".png"))
                }
                return data
            }
            let runningImage = try renderedButton("running")
            let snapshot = game.session.snapshot
            button.sendActions(for: .touchDown)
            #expect(game.paused && game.session.snapshot == snapshot)
            #expect(button.accessibilityLabel == L10n.text("Resume, hold for pause menu"))
            let pausedImage = try renderedButton("paused")
            #expect(pausedImage != runningImage)
            #expect(game.hud.hitTest(point, with: nil) === button)
            button.sendActions(for: .touchUpInside)
            #expect(game.paused)
            button.sendActions(for: .touchDown)
            #expect(game.paused)
            button.sendActions(for: .touchUpInside)
            #expect(!game.paused && game.session.snapshot == snapshot)
            #expect(button.accessibilityLabel == L10n.text("Pause, hold for pause menu"))
            #expect(try renderedButton("resumed") == runningImage)
        }
    }

    @Test(arguments: [MobileTargetInput.touch, .precision])
    func releasedContactClearsAimWithoutHover(input: MobileTargetInput) async throws {
        try await withGame { game in
            _ = game.lifecycle.handle(.becameActive)
            _ = game.playState.resume(isForeground: true, isInterrupted: false)
            game.overlay.isHidden = true
            let point = MobilePoint(x: 80, y: 60)
            game.handle([.preview(point)], input: input)
            #expect(game.previewPoint == point)
            #expect(game.playfieldView.cursorPoint != nil)
            game.handle([.commit(point)], input: input)
            #expect(game.previewPoint == nil)
            #expect(game.highlightedTarget == nil)
            #expect(game.playfieldView.cursorPoint == nil)
            game.handle([.preview(point), .cancelPreview], input: input)
            #expect(game.previewPoint == nil && game.playfieldView.cursorPoint == nil)
        }
    }

    @Test func releasedClickReturnsToHoverAndHoverExitClearsAim() async throws {
        try await withGame { game in
            _ = game.lifecycle.handle(.becameActive)
            _ = game.playState.resume(isForeground: true, isInterrupted: false)
            game.overlay.isHidden = true
            let hover = PointerFixtureHover(target: nil, action: nil)
            game.playfieldView.perform(NSSelectorFromString("handleHover:"), with: hover)
            let click = MobilePoint(x: 40, y: 30)
            game.handle([.preview(click), .commit(click)], input: .precision)
            #expect(game.previewPoint == .init(x: 80, y: 60))
            hover.fixtureState = .ended
            game.playfieldView.perform(NSSelectorFromString("handleHover:"), with: hover)
            #expect(game.previewPoint == nil && game.playfieldView.cursorPoint == nil)
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

    @Test(arguments: [false, true])
    func restoringPlayableSizeKeepsTheStartBoundary(shared: Bool) async throws {
        let turn: MobileGameTurn? = shared ? .init(scope: "hotseat.pose", owner: "guest", ownerName: "GUEST",
            ownerPortrait: 0, choices: { _ in [] }) : nil
        try await withGame(turn: turn) { game in
            game.viewDidLayoutSubviews()
            let snapshot = game.session.snapshot
            game.view.frame.size = CGSize(width: 100, height: 100)
            game.viewDidLayoutSubviews()
            game.view.frame.size = CGSize(width: 834, height: 1194)
            game.viewDidLayoutSubviews()
            #expect(game.playState.phase == .ready)
            #expect(game.session.snapshot == snapshot)
            #expect(game.overlayCanvas.page.footer.contains { $0.title == L10n.text(shared ? "READY" : "START") })
            #expect(!game.overlayCanvas.page.footer.contains { $0.title == L10n.text("RESUME") })
        }
    }

    @Test func suspensionStopsFramesUntilThePlayerResumes() async throws {
        var renders = 0
        try await withGame(rendered: { renders += 1 }) { game in
            game.viewWillAppear(false)
            #expect(game.isDisplayLinkPaused == GCController.controllers().isEmpty)
            game.resumePlay()
            #expect(!game.isDisplayLinkPaused)
            _ = game.clock.advance(at: 1)
            game.applyLifecycle(.becameInactive)
            #expect(game.isDisplayLinkPaused && game.paused)
            let snapshot = game.session.snapshot
            let before = renders
            let target = MobileDisplayLinkTarget { _ in }
            let frame = CADisplayLink(target: target, selector: #selector(MobileDisplayLinkTarget.frame(_:)))
            defer { frame.invalidate() }
            for _ in 0..<10 { game.displayFrame(frame) }
            #expect(renders == before && game.session.snapshot == snapshot)
            game.applyLifecycle(.enteredBackground)
            game.applyLifecycle(.becameActive)
            #expect(game.paused && !game.overlay.isHidden)
            #expect(game.isDisplayLinkPaused == GCController.controllers().isEmpty)
            #expect(game.overlayCanvas.page.footer.contains { $0.title == L10n.text("RESUME") })
            game.resumePlay()
            #expect(!game.paused && !game.isDisplayLinkPaused)
            #expect(game.clock.advance(at: 1000) == 0)
        }
    }

    @Test func firstResumeFrameRetainsTheFrozenTickAndDiscardsOldDisplayTime() async throws {
        try await withGame { game in
            game.viewWillAppear(false)
            game.resumePlay()
            game.pauseForPlanning()
            for menu in [false, true] {
                if menu { game.pausePlay(showControls: true) }
                let snapshot = game.session.snapshot
                game.resumePlay()
                let target = MobileDisplayLinkTarget { _ in }
                let frame = CADisplayLink(target: target, selector: #selector(MobileDisplayLinkTarget.frame(_:)))
                game.displayFrame(frame)
                frame.invalidate()
                #expect(game.session.snapshot == snapshot)
                #expect(game.clock.advance(at: frame.timestamp) == 0)
                #expect(game.clock.advance(at: CACurrentMediaTime()) == 0)
                game.pauseForPlanning()
            }
        }
    }

    @Test func hiddenGameCannotRenderOrRestartItsFrameLoop() async throws {
        var renders = 0
        try await withGame(rendered: { renders += 1 }) { game in
            game.viewWillAppear(false)
            game.resumePlay()
            game.viewWillDisappear(false)
            #expect(game.isDisplayLinkPaused && game.paused)
            let before = renders
            let snapshot = game.session.snapshot
            game.applyLifecycle(.becameInactive)
            game.applyLifecycle(.becameActive)
            #expect(game.isDisplayLinkPaused && game.paused)
            #expect(renders == before && game.session.snapshot == snapshot)
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
