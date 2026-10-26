#if os(iOS) || os(tvOS)
import CoreGraphics
import Foundation
import Testing
import UIKit
import LemmingsMobileCore
@testable import LemmingsMobileUI

private final class OverlayBackgroundSession: MobileGameSession {
    let engineIdentifier: String
    let engineFingerprint = "overlay-background"
    let levelIdentifier = "overlay-background"
    let levelIndex = 0
    let levelFingerprint = "overlay-background"
    let levelSize = MobileSize(width: 320, height: 160)
    let ticksPerSecond = 25.0
    var completed = false
    var won = false
    var snapshot: MobileGameSnapshot {
        .init(tick: 0, released: 0, total: 10, saved: won ? 10 : 0, required: 5,
            remainingSeconds: 120, releaseRate: nil, isComplete: completed, didWin: won,
            isEndingRun: false, skills: (0..<8).map { .init(name: "Skill \($0)", count: 10) })
    }
    init(engine: String) { engineIdentifier = engine }
    func tick() {}
    func targetCandidates(for control: Int) -> [MobileTargetCandidate] { [] }
    func assign(control: Int, to target: Int) -> Bool { false }
    func adjustReleaseRate(by delta: Int) -> Bool { false }
    func beginEndRun() -> Bool { false }
    func undoEndRun() -> Bool { false }
    func checkpointPayload() throws -> Data { Data() }
    func restoreCheckpointPayload(_ data: Data) throws {}
    func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        try .init(width: 320, height: 160, rgba: Data(repeating: 0, count: 320 * 160 * 4))
    }
}

@MainActor struct MobileOverlayBackgroundTests {
    /**
     * Samples the composited layer tree without a window or a display link.
     */
    private func pixel(_ view: UIView, at point: CGPoint) throws -> [UInt8] {
        let context = try #require(CGContext(data: nil, width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.translateBy(x: -point.x, y: -point.y)
        view.layer.render(in: context)
        let data = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: data, count: 4))
    }

    @Test(arguments: ["classic-dos", "lemmings2", "lemmings3"])
    func readyAndResultsCoverTheAreaOutsideTheirSafeContent(engine: String) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let session = OverlayBackgroundSession(engine: engine)
        let previous = UserDefaults.standard.object(forKey: MobileSettings.activeProfileKey)
        let game = MobileGameViewController(summary: .init(index: 0, rank: "Fun", number: 1, title: "Fixture"),
            session: session, checkpointStore: .init(url: directory.appendingPathComponent("current.json")),
            restoredCheckpoint: nil, settingsProfileID: "overlay-background-test")
        defer {
            game.viewDidDisappear(false)
            UserDefaults.standard.set(previous, forKey: MobileSettings.activeProfileKey)
            try? FileManager.default.removeItem(at: directory)
        }
        game.loadViewIfNeeded()
        let underlay = UIView()
        underlay.backgroundColor = .magenta
        underlay.isUserInteractionEnabled = false
        game.view.insertSubview(underlay, belowSubview: game.overlayBackdrop)
        for size in [CGSize(width: 1194, height: 834), .init(width: 834, height: 1194),
                     .init(width: 1194, height: 690)] {
            game.view.frame = CGRect(origin: .zero, size: size)
            game.view.layoutIfNeeded()
            underlay.frame = game.view.bounds
            for state in ["ready", "win", "loss", "pause"] {
                session.completed = state == "win" || state == "loss"
                session.won = state == "win"
                game.playState = MobilePlayState()
                if session.completed { game.playState.complete() }
                if state == "pause" {
                    game.playState.resume(isForeground: true, isInterrupted: false)
                    game.playState.pauseForPlanning()
                }
                var actions = 0
                game.showOverlay(title: state, actions: [("Continue", { actions += 1 })], results: session.completed)
                /**
                 * Supplies the safe content rectangle directly. Runtime cutout APIs need a device.
                 */
                let content = game.view.bounds.insetBy(dx: 40, dy: 80)
                game.globalNavigation.frame = CGRect(x: content.minX, y: content.minY,
                    width: content.width, height: 44)
                game.overlay.setViewportFrame(content.inset(by: .init(top: 44, left: 0, bottom: 0, right: 0)))
                #expect(game.overlayBackdrop.frame == game.view.bounds)
                #expect(!game.overlayBackdrop.isHidden && game.overlayBackdrop.isOpaque)
                #expect(!game.overlayBackdrop.isUserInteractionEnabled && game.overlayBackdrop.accessibilityElementsHidden)
                let probes = [CGPoint(x: size.width / 2, y: 8), CGPoint(x: 8, y: size.height / 2),
                              CGPoint(x: size.width / 2, y: size.height - 8)]
                for point in probes { #expect(try pixel(game.view, at: point) == [0, 0, 0, 255]) }
                let snapshot = session.snapshot
                let phase = game.playState.phase
                game.overlayCanvas.onAction?("0")
                #expect(actions == 1 && session.snapshot == snapshot && game.playState.phase == phase)
                game.overlay.isHidden = true
                #expect(game.overlayBackdrop.isHidden)
                #expect(try pixel(game.view, at: probes[0]) == [255, 0, 255, 255])
            }
        }
    }
}
#endif
