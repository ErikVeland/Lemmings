#if os(iOS)
import Foundation
import Testing
import UIKit
import LemmingsMobileCore
@testable import LemmingsMobileUI

@MainActor private final class BrowsingTouch: UITouch {
    var point = CGPoint(x: 80, y: 60)
    var time = ProcessInfo.processInfo.systemUptime - 1
    override var timestamp: TimeInterval { time }
    override var type: UITouch.TouchType { .direct }
    override func location(in view: UIView?) -> CGPoint { point }
}

private final class TouchBrowsingSession: MobileGameSession {
    let engineIdentifier: String
    let engineFingerprint = "touch-fixture"
    let levelIdentifier = "touch-fixture"
    let levelIndex = 0
    let levelFingerprint = "touch-fixture"
    let levelSize = MobileSize(width: 640, height: 160)
    let ticksPerSecond = 25.0
    var candidates: [MobileTargetCandidate] = (1...3).map {
        .init(id: $0, point: .init(x: 80, y: 60), direction: 1, assignment: .eligible)
    }
    var assignments: [Int] = []
    var snapshot: MobileGameSnapshot {
        .init(tick: 1, released: 3, total: 10, saved: 0, required: 5,
            remainingSeconds: 100, releaseRate: nil, isComplete: false, didWin: false,
            isEndingRun: false, skills: (0..<8).map { .init(name: "Skill \($0)", count: 10) })
    }
    init(engine: String) { engineIdentifier = engine }
    func tick() {}
    func targetCandidates(for control: Int) -> [MobileTargetCandidate] { candidates }
    func assign(control: Int, to target: Int) -> Bool { assignments.append(target); return true }
    func adjustReleaseRate(by delta: Int) -> Bool { false }
    func beginEndRun() -> Bool { false }
    func undoEndRun() -> Bool { false }
    func checkpointPayload() throws -> Data { Data() }
    func restoreCheckpointPayload(_ data: Data) throws {}
    func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        try .init(width: 640, height: 160, rgba: Data(repeating: 0, count: 640 * 160 * 4))
    }
}

@MainActor struct MobileTouchBrowsingTests {
    @Test func heldTouchOwnsCameraGesturesAndRejectsRemainingContactsAfterRelease() {
        let field = MobilePlayfieldView(viewport: .init(levelSize: .init(width: 640, height: 160),
            viewSize: .init(width: 320, height: 160), zoom: 1))
        field.frame = CGRect(x: 0, y: 0, width: 320, height: 160)
        field.canHoldSelection = { _ in true }
        var effects: [MobileTouchEffect] = []
        field.onTouchEffects = { effects += $0 }
        let selection = BrowsingTouch(), camera = BrowsingTouch(), extra = BrowsingTouch()
        field.touchesBegan([selection], with: nil)
        field.advanceVisualEffects()
        #expect(effects.contains(.holdSelection(.init(x: 80, y: 60))))
        #expect(!field.gestureRecognizerShouldBegin(UIPinchGestureRecognizer()))
        #expect(!field.gestureRecognizerShouldBegin(UISwipeGestureRecognizer()))
        #expect(!field.gestureRecognizerShouldBegin(UITapGestureRecognizer()))
        camera.point = CGPoint(x: 200, y: 60)
        field.touchesBegan([camera], with: nil)
        camera.point.x = 180
        field.touchesMoved([camera], with: nil)
        #expect(effects.last == .panHoldingSelection(.init(x: -20, y: 0)))
        field.touchesEnded([selection], with: nil)
        #expect(effects.last == .commitSelection)
        let count = effects.count
        camera.point.x = 160
        field.touchesMoved([camera], with: nil)
        field.touchesBegan([extra], with: nil)
        field.touchesEnded([extra, camera], with: nil)
        #expect(effects.count == count)
        let tap = BrowsingTouch()
        field.touchesBegan([tap], with: nil)
        field.touchesEnded([tap], with: nil)
        #expect(effects.last == .commit(.init(x: 80, y: 60)))
    }

    @Test func cameraFingerCannotStartInAReservedRegion() {
        let field = MobilePlayfieldView(viewport: .init(levelSize: .init(width: 640, height: 160),
            viewSize: .init(width: 320, height: 160), zoom: 1))
        field.frame = CGRect(x: 0, y: 0, width: 320, height: 160)
        field.blockedInputFrames = [CGRect(x: 150, y: 0, width: 20, height: 160)]
        field.canHoldSelection = { _ in true }
        var effects: [MobileTouchEffect] = []
        field.onTouchEffects = { effects += $0 }
        let selection = BrowsingTouch(), camera = BrowsingTouch()
        field.touchesBegan([selection], with: nil)
        field.advanceVisualEffects()
        camera.point.x = 160
        field.touchesBegan([camera], with: nil)
        #expect(effects.last == .cancelPreview)
        field.touchesEnded([selection, camera], with: nil)
        #expect(!effects.contains(.commitSelection))
    }

    private func withGame(engine: String = "classic-dos",
                          _ body: (MobileGameViewController, TouchBrowsingSession) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let previous = UserDefaults.standard.object(forKey: MobileSettings.activeProfileKey)
        let session = TouchBrowsingSession(engine: engine)
        let game = MobileGameViewController(summary: .init(index: 0, rank: "Test", number: 1, title: "Touch"),
            session: session, checkpointStore: .init(url: directory.appendingPathComponent("current.json")),
            restoredCheckpoint: nil, settingsProfileID: "touch-browsing-test")
        defer {
            game.viewDidDisappear(false)
            UserDefaults.standard.set(previous, forKey: MobileSettings.activeProfileKey)
            try? FileManager.default.removeItem(at: directory)
        }
        game.loadViewIfNeeded()
        game.view.frame = CGRect(x: 0, y: 0, width: 834, height: 1194)
        game.view.layoutIfNeeded()
        game.gameSettings.pauseToAssign = false
        game.gameSettings.classic.favorApproachingLemmings = false
        _ = game.playState.resume(isForeground: true, isInterrupted: false)
        _ = game.playState.pauseForPlanning()
        game.overlay.isHidden = true
        game.playfieldView.gameViewport = .init(levelSize: session.levelSize,
            viewSize: .init(width: 320, height: 160), zoom: 1)
        try body(game, session)
    }

    @Test(arguments: ["classic-dos", "lemmings2", "lemmings3"])
    func heldChoiceSurvivesRenderingAndCameraPansThenCommitsByIdentity(engine: String) throws {
        try withGame(engine: engine) { game, session in
            let point = MobilePoint(x: 80, y: 60)
            #expect(game.playfieldView.canHoldSelection?(point) == true)
            #expect(game.playfieldView.canHoldSelection?(.init(x: 300, y: 60)) == false)
            game.handle([.preview(point), .holdSelection(point), .browseSelection(1)], input: .touch)
            #expect(game.highlightedTarget?.id == 2)
            #expect(game.playfieldView.selectionPoint == point)
            #expect(game.playfieldView.cursorOccupied && game.playfieldView.cursorEligible)
            game.handle([.panHoldingSelection(.init(x: -80, y: 0))], input: .touch)
            #expect(game.playfieldView.gameViewport.origin.x == 80)
            #expect(game.highlightedTarget?.id == 2)
            #expect(game.previewPoint == point)
            #expect(game.paused && session.assignments.isEmpty)
            game.handle([.commitSelection], input: .touch)
            #expect(session.assignments == [2])
            #expect(!game.browsingTouchSelection && game.touchSelection == nil)
        }
    }

    @Test func disappearingOrUnavailableChoicesNeverFallBackToTheNearestActor() throws {
        for removed in [false, true] {
            try withGame { game, session in
                let point = MobilePoint(x: 80, y: 60)
                game.handle([.preview(point), .holdSelection(point), .browseSelection(1)], input: .touch)
                session.candidates = session.candidates.filter { $0.id != 2 }
                if !removed {
                    session.candidates.append(.init(id: 2, point: point, direction: 1, assignment: .unavailable))
                }
                game.renderCurrentFrame(force: true)
                #expect(game.highlightedTarget?.id == (removed ? nil : 2))
                #expect(!game.playfieldView.cursorEligible)
                game.handle([.commitSelection], input: .touch)
                #expect(session.assignments.isEmpty)
            }
        }
    }

    @Test func cancellationClearsHeldStateEvenWhenAMenuAlreadyCoversPlay() throws {
        try withGame { game, session in
            let point = MobilePoint(x: 80, y: 60)
            game.handle([.preview(point), .holdSelection(point)], input: .touch)
            game.overlay.isHidden = false
            game.handle([.cancelPreview], input: .touch)
            #expect(!game.browsingTouchSelection && game.touchSelection == nil)
            game.overlay.isHidden = true
            game.handle([.commitSelection], input: .touch)
            #expect(session.assignments.isEmpty)
        }
    }
}
#endif
