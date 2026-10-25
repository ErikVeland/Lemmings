#if os(iOS)
import Foundation
import Testing
import UIKit
import LemmingsGameArt
import LemmingsMobileCore
@testable import LemmingsMobileUI

private final class ReplayCameraSession: MobileGameSession {
    let engineIdentifier: String
    let engineFingerprint = "replay-camera"
    let levelIdentifier = "replay-camera"
    let levelIndex = 0
    let levelFingerprint = "replay-camera"
    let levelSize = MobileSize(width: 1600, height: 640)
    let ticksPerSecond = 25.0
    let isReadOnly = true
    var complete = false
    var assignments = 0
    var snapshot: MobileGameSnapshot {
        .init(tick: 146, released: 3, total: 10, saved: 0, required: 5,
            remainingSeconds: 100, releaseRate: nil, isComplete: complete, didWin: false,
            isEndingRun: false, skills: (0..<8).map { .init(name: "Skill \($0)", count: 10) })
    }
    init(engine: String) { engineIdentifier = engine }
    func tick() {}
    func targetCandidates(for control: Int) -> [MobileTargetCandidate] { [] }
    func assign(control: Int, to target: Int) -> Bool { assignments += 1; return true }
    func adjustReleaseRate(by delta: Int) -> Bool { false }
    func beginEndRun() -> Bool { false }
    func undoEndRun() -> Bool { false }
    func checkpointPayload() throws -> Data { Data() }
    func restoreCheckpointPayload(_ data: Data) throws {}
    func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        try .init(width: 1600, height: 640, rgba: Data(repeating: 0, count: 1600 * 640 * 4))
    }
}

@MainActor struct MobileReplayInteractionTests {
    @Test(arguments: ["classic-dos", "lemmings2", "lemmings3"])
    func replayDragPansWithoutEditingOrChangingTransport(engine: String) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let session = ReplayCameraSession(engine: engine)
        let game = MobileGameViewController(summary: .init(index: 0, rank: "Fun", number: 1, title: "Replay"),
            session: session, checkpointStore: .init(url: directory.appendingPathComponent("current.json")),
            restoredCheckpoint: nil, settingsProfileID: "replay-camera-test")
        defer { game.viewDidDisappear(false); try? FileManager.default.removeItem(at: directory) }
        game.loadViewIfNeeded()
        game.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        game.view.layoutIfNeeded()
        game.overlay.isHidden = true
        for complete in [false, true] {
            session.complete = complete
            for running in [false, true] {
                _ = game.playState.resume(isForeground: true, isInterrupted: false)
                if !running { _ = game.playState.pauseForPlanning() }
                let phase = game.playState.phase
                let before = session.snapshot
                game.playfieldView.gameViewport = .init(levelSize: session.levelSize,
                    viewSize: .init(width: 320, height: 160), zoom: 1)
                game.handle([.preview(.init(x: 80, y: 60)), .pan(.init(x: -80, y: -40)),
                    .commit(.init(x: 80, y: 60))], input: .touch)
                #expect(game.playfieldView.gameViewport.origin == .init(x: 80, y: 40))
                #expect(session.snapshot == before && session.assignments == 0)
                #expect(game.playState.phase == phase && game.previewPoint == nil)
                game.overlay.isHidden = false
                game.handle([.pan(.init(x: -80, y: -40))], input: .touch)
                #expect(game.playfieldView.gameViewport.origin == .init(x: 80, y: 40))
                game.overlay.isHidden = true
            }
        }
    }

    @Test func moveTargetsConsumeDisabledHitsAndLeaveTheMapOpen() throws {
        let moves = MobileReplayMoveView(frame: CGRect(x: 0, y: 0, width: 240, height: 44))
        moves.isHidden = false
        moves.layoutIfNeeded()
        moves.update(previous: false, next: true)
        #expect(moves.hitTest(CGPoint(x: 22, y: 22), with: nil) === moves)
        #expect(moves.hitTest(CGPoint(x: 120, y: 22), with: nil) == nil)
        let next = try #require(moves.hitTest(CGPoint(x: 218, y: 22), with: nil) as? UIButton)
        var direction = 0
        moves.onMove = { direction = $0 }
        next.sendActions(for: .touchUpInside)
        #expect(direction == 1)
        #expect(next.accessibilityLabel == "Next move")
    }
}
#endif
