import Foundation
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobileRewindQueueTests {
    @Test func rapidPressesAccumulateBeyondTheDisplayedTick() throws {
        var queue = MobileRewindQueue()
        let appendedFirst = queue.append(ticks: 34, from: 200, earliestTick: 0)
        #expect(appendedFirst)
        let firstRequest = queue.takePending()
        let first = try #require(firstRequest)
        #expect(first.tick == 166)
        #expect(first.backwardSteps == 1)
        // Reconstruction has not committed: the displayed session still says 200.
        for _ in 0..<3 {
            let appended = queue.append(ticks: 34, from: 200, earliestTick: 0)
            #expect(appended)
        }
        queue.didCommit()
        let pendingRequest = queue.takePending()
        let stacked = try #require(pendingRequest)
        #expect(stacked.tick == 64)
        #expect(stacked.backwardSteps == 3)
        let pendingEmpty = queue.takePending() == nil
        #expect(pendingEmpty)
        // Releasing the control adds no new distance and leaves the accepted target intact.
        #expect(queue.targetTick == 64)
        queue.didCommit()
        #expect(queue.targetTick == nil)
        let appendedStep = queue.append(ticks: 1, from: 64, earliestTick: 0)
        #expect(appendedStep)
        let steppedOnce = queue.takePending()?.tick == 63
        #expect(steppedOnce)
    }

    @Test func historyBoundaryAndCancellationDoNotLeaveStaleWork() throws {
        var queue = MobileRewindQueue()
        let appendedFirst = queue.append(ticks: 4, from: 12, earliestTick: 5, backwardSteps: 4)
        #expect(appendedFirst)
        let firstTargetMatches = queue.takePending()?.tick == 8
        #expect(firstTargetMatches)
        let appendedToBoundary = queue.append(ticks: 4, from: 12, earliestTick: 5, backwardSteps: 4)
        #expect(appendedToBoundary)
        let rejectedPastBoundary = !queue.append(ticks: 40, from: 12, earliestTick: 5)
        #expect(rejectedPastBoundary)
        queue.didCommit()
        let boundaryRequest = queue.takePending()
        let final = try #require(boundaryRequest)
        #expect(final.tick == 5)
        #expect(final.backwardSteps == 3)
        queue.cancel()
        let cancelledPending = queue.takePending() == nil
        #expect(cancelledPending)
        #expect(queue.targetTick == nil)
        let rejectedAtBoundary = !queue.append(ticks: 1, from: 5, earliestTick: 5)
        #expect(rejectedAtBoundary)
        let rejectedZero = !queue.append(ticks: 0, from: 100, earliestTick: 5)
        #expect(rejectedZero)
        let rejectedNegative = !queue.append(ticks: -1, from: 100, earliestTick: 5)
        #expect(rejectedNegative)
        let appendedAfterCancel = queue.append(ticks: 2, from: 100, earliestTick: 5)
        #expect(appendedAfterCancel)
        let freshTargetMatches = queue.takePending()?.tick == 98
        #expect(freshTargetMatches)
    }

    @Test @MainActor func stackedSeeksCommitExactStatesAndCountsAcrossEngines() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = MobileStorage(directory: directory)
        let classic = try ClassicMobileLibrary(directory: root.appendingPathComponent("Sources/Ports/lemmings_dos_1991-07-30"))
        let l2 = try Lemmings2MobileLibrary(directory: root.appendingPathComponent("Sources/Ports/Lemm2"), storage: storage)
        let l3 = try Lemmings3MobileLibrary(directory: root.appendingPathComponent("Sources/Ports/LEM3CD"), storage: storage)
        var terrain = try NeoLemmixTerrain(width: 512, height: 64)
        for x in 0..<512 { terrain.setSolid(true, x: x, y: 48) }
        let neo = NeoLemmixMobileSession(simulation: try NeoLemmixSimulation(terrain: terrain, configuration: .init(
            totalLemmings: 1, requiredToSave: 1, spawnInterval: 30, entrances: [],
            preplacedLemmings: [.init(position: .init(x: 30, y: 48))], skills: [.builder: .infinite])),
            controls: [.builder], engineFingerprint: "queue", levelIdentifier: "queue", levelIndex: 0, levelFingerprint: "queue")
        let games: [any MobileGameSession] = [try classic.loadLevel(at: 0).session,
            try l2.loadLevel(at: 0).session, try l3.loadLevel(at: 0).session, neo]
        for game in games {
            for _ in 0..<60 { game.tick() }
            let expected = game.snapshot
            let expectedHash = try game.actionCapture()?.final.hash()
            for _ in 0..<100 { game.tick() }
            #expect(game.snapshot.tick == 160)
            var queue = MobileRewindQueue()
            let appendedFirst = queue.append(ticks: 40, from: game.snapshot.tick, earliestTick: game.earliestRewindTick)
            #expect(appendedFirst)
            let firstRequest = queue.takePending()
            let first = try #require(firstRequest)
            let operation = try #require(game.prepareSeek(to: first.tick, backwardSteps: first.backwardSteps))
            let appendedSecond = queue.append(ticks: 20, from: game.snapshot.tick, earliestTick: game.earliestRewindTick)
            #expect(appendedSecond)
            let appendedThird = queue.append(ticks: 40, from: game.snapshot.tick, earliestTick: game.earliestRewindTick)
            #expect(appendedThird)
            while try !operation.advance(seconds: 0) {}
            #expect(game.snapshot.tick == 120)
            queue.didCommit()
            let stackedRequest = queue.takePending()
            let stacked = try #require(stackedRequest)
            let final = try #require(game.prepareSeek(to: stacked.tick, backwardSteps: stacked.backwardSteps))
            while try !final.advance(seconds: 0) {}
            queue.didCommit()
            #expect(game.snapshot == expected, "\(game.engineIdentifier)")
            #expect(try game.actionCapture()?.final.hash() == expectedHash, "\(game.engineIdentifier)")
            #expect(game.rewindCount == 3)
            #expect(game.usedRewind)
            #expect(queue.targetTick == nil)
        }
    }
}
