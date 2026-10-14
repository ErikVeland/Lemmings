import Foundation
import Testing
@testable import NxlvKit

struct ReplayMoveNavigationTests {
    @Test func boundariesUseDistinctSuccessfulMoveTicksAndNeverWrap() {
        let moves = ReplayMoveNavigation(ticks: [10, 30, 10, 20, -1])
        #expect(moves.ticks == [10, 20, 30])
        #expect(moves.target(from: 0, direction: -1) == nil)
        #expect(moves.target(from: 0, direction: 1) == 10)
        #expect(moves.target(from: 20, direction: -1) == 10)
        #expect(moves.target(from: 20, direction: 1) == 30)
        #expect(moves.target(from: 21, direction: -1) == 20)
        #expect(moves.target(from: 30, direction: 1) == nil)
        #expect(ReplayMoveNavigation(ticks: []).target(from: 0, direction: 1) == nil)
    }

    @Test func classicTimelineExcludesRejectedAndDuplicateAssignments() throws {
        let width = 160, height = 80
        var pixels = [UInt8](repeating: 0, count: width * height)
        for index in 50 * width..<pixels.count { pixels[index] = 1 }
        let initial = try ClassicDOSSimulation(terrain: .init(width: width, height: height,
            solidMask: Data(pixels), steelMask: Data(repeating: 0, count: pixels.count)),
            configuration: .init(totalLemmings: 2, requiredToSave: 2, timeLimitTicks: 1000, initialReleaseRate: 99,
                entrances: [.init(x: 20, y: 20)], initialSkills: [.climber: 3, .floater: 3],
                maximumX: width - 1, maximumY: height - 1))
        var probe = initial
        while probe.lemmings.isEmpty, probe.tickCount < 100 { probe.tick() }
        let id = try #require(probe.lemmings.first?.id)
        let first = probe.tickCount, second = first + 2
        let replay = ClassicDOSReplay(rank: "Test", number: 1, title: "Move boundaries",
            initialStateHash: ClassicDOSReplayRecorder.stateHash(of: initial), events: [
            .init(tick: first, action: .assign(lemmingID: id, skill: .climber), afterTick: true),
            .init(tick: first, action: .assign(lemmingID: id, skill: .climber), afterTick: true),
            .init(tick: first + 1, action: .assign(lemmingID: 9999, skill: .floater), afterTick: true),
            .init(tick: second, action: .assign(lemmingID: id, skill: .floater)),
            .init(tick: second + 1, action: .releaseRate(50)),
        ])
        let hash = ClassicDOSReplayRecorder.stateHash(of: initial)
        #expect(ReplayMoveNavigation.classic(initial: initial, replay: replay).ticks == [first, second])
        #expect(ClassicDOSReplayRecorder.stateHash(of: initial) == hash)
    }
}
