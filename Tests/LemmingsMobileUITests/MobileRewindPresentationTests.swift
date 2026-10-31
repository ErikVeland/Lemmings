#if os(iOS) || os(tvOS)
import Foundation
import XCTest
import UIKit
import NxlvKit
import LemmingsMobileCore
@testable import LemmingsMobileUI

@MainActor final class MobileRewindPresentationTests: XCTestCase {
    func testRecordedFramesPlayBackwardAndInputRestoresTheExactDestination() async throws {
        guard ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] == "muted" else {
            XCTFail("Mechanical audio must be muted")
            return
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let runtime = try Lemmings3Runtime(configuration: .init(width: 128, height: 64,
            attributes: [UInt16](repeating: 0, count: 128 * 64), entrance: .init(x: 20, y: 20),
            exits: [.init(x: 110, y: 46)], total: 100, releaseInterval: 20, releaseDelay: 0))
        let session = Lemmings3MobileSession(runtime: runtime, engineFingerprint: "rewind-presentation",
            levelIdentifier: "rewind-presentation", levelIndex: 0, levelFingerprint: "rewind-presentation",
            renderer: { runtime, _ in
                try MobilePixelFrame(width: 128, height: 64,
                    rgba: Data(repeating: UInt8(runtime.tick % 256), count: 128 * 64 * 4))
            })
        let game = MobileGameViewController(summary: .init(index: 0, rank: "Test", number: 1, title: "Rewind"),
            session: session, checkpointStore: .init(url: directory.appendingPathComponent("current.json")),
            restoredCheckpoint: nil, turn: nil, settingsProfileID: "rewind-presentation-test")
        game.loadViewIfNeeded()
        game.view.frame = CGRect(x: 0, y: 0, width: 834, height: 600)
        game.view.layoutIfNeeded()
        game.gameSettings.classic.reduceMotion = false
        let resumed = game.playState.resume(isForeground: true, isInterrupted: false)
        XCTAssertTrue(resumed)
        game.overlay.isHidden = true
        for _ in 0..<60 { session.tick(); game.renderCurrentFrame(force: true) }
        XCTAssertEqual(session.snapshot.tick, 60)
        let expectedTick = 60 - Int((2 * session.ticksPerSecond).rounded())
        let history = try XCTUnwrap(Mirror(reflecting: game).children.first { $0.label == "rewindFrames" }?.value
            as? MobileRewindFrameHistory<MobilePixelFrame>)
        XCTAssertGreaterThan(history.retainedBytes, 0,
            "lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled), thermal=\(ProcessInfo.processInfo.thermalState.rawValue), reduceMotion=\(UIAccessibility.isReduceMotionEnabled), paused=\(game.paused), overlay=\(game.overlay.isHidden), constrained=\(MobileDevicePerformance.constrained), cache=\(RuntimeMemoryBudget.shared.snapshot().cacheBytes), leased=\(RuntimeMemoryBudget.shared.retainedCacheBytes)")
        XCTAssertNotNil(history.frames(from: 60, through: expectedTick, maximumOriginGap: 2, maximumSampleGap: 6))
        game.rewindFromPress()
        let deadline = ProcessInfo.processInfo.systemUptime + 3
        while session.snapshot.tick == 60 && ProcessInfo.processInfo.systemUptime < deadline {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertEqual(session.snapshot.tick, expectedTick)
        XCTAssertEqual(session.rewindCount, 1)
        let start = try XCTUnwrap(game.playfieldView.bitmap?.dataProvider?.data as Data?).first
        XCTAssertEqual(start, 60)
        try await Task.sleep(nanoseconds: 150_000_000)
        let middle = try XCTUnwrap(game.playfieldView.bitmap?.dataProvider?.data as Data?).first
        XCTAssertTrue(middle != nil && middle! < 60 && Int(middle!) > expectedTick)
        game.aim(at: MobilePoint(x: 10, y: 10))
        let destination = try XCTUnwrap(game.playfieldView.bitmap?.dataProvider?.data as Data?).first
        XCTAssertEqual(destination, UInt8(expectedTick))
        XCTAssertEqual(session.snapshot.tick, expectedTick)
        XCTAssertEqual(session.rewindCount, 1)
    }
}
#endif
