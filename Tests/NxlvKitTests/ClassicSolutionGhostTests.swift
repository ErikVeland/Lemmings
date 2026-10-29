import Foundation
import Testing
@testable import NxlvKit

struct ClassicSolutionGhostTests {
    @Test func cursorMatchesReplayThroughPauseRewindAndDivergentLiveInput() throws {
        let width = 640, height = 80
        var mask = [UInt8](repeating: 0, count: width * height)
        for index in 50 * width..<mask.count { mask[index] = 1 }
        let initial = try ClassicDOSSimulation(terrain: .init(width: width, height: height,
            solidMask: Data(mask), steelMask: Data(repeating: 0, count: mask.count)),
            configuration: .init(totalLemmings: 5, requiredToSave: 1, timeLimitTicks: 1000,
                initialReleaseRate: 50, entrances: [.init(x: 20, y: 20)],
                initialSkills: [.climber: 5, .floater: 5], maximumX: width - 1, maximumY: height - 1))
        let hash = ClassicDOSReplayRecorder.stateHash(of: initial)
        var probe = initial
        while probe.lemmings.isEmpty { probe.tick() }
        let id = try #require(probe.lemmings.first?.id), first = probe.tickCount
        let replay = ClassicDOSReplay(rank: "Test", number: 1, title: "Ghost",
            initialStateHash: hash, events: [
                .init(tick: 0, action: .releaseRate(99), afterTick: true),
                .init(tick: first, action: .assign(lemmingID: id, skill: .climber), afterTick: true),
                .init(tick: first + 2, action: .assign(lemmingID: id, skill: .floater)),
                .init(tick: first + 10, action: .releaseRate(25)),
                .init(tick: 400, action: .nuke, afterTick: true),
            ])
        var states: [Int: String] = [:]
        let outcome = try ClassicDOSReplayPlayer.run(replay, simulation: initial, verify: false, observe: {
            states[$0.tickCount] = ClassicDOSReplayRecorder.stateHash(of: $0)
        })
        var ghost = try #require(ClassicSolutionGhost(initial: initial, replay: replay))
        var live = initial
        live.setReleaseRate(10)
        for _ in 0..<first + 20 { live.tick() }
        let liveHash = ClassicDOSReplayRecorder.stateHash(of: live)
        for tick in [0, first, first + 2, 200, 399, 400, 100, 0, 350, 170, 171] {
            ghost.synchronise(to: tick)
            #expect(ClassicDOSReplayRecorder.stateHash(of: ghost.simulation) == states[tick])
            let paused = ClassicDOSReplayRecorder.stateHash(of: ghost.simulation)
            ghost.synchronise(to: tick)
            #expect(ClassicDOSReplayRecorder.stateHash(of: ghost.simulation) == paused)
        }
        let boundedReplay = ClassicDOSReplay(rank: replay.rank, number: replay.number, title: replay.title,
            initialStateHash: hash, events: replay.events, expected: outcome)
        var completed = try #require(ClassicSolutionGhost(initial: initial, replay: boundedReplay))
        completed.synchronise(to: outcome.ticks + 1000)
        #expect(completed.simulation.tickCount == outcome.ticks)
        #expect(ClassicDOSReplayRecorder.stateHash(of: completed.simulation) == outcome.stateHash)
        completed.synchronise(to: 0)
        #expect(ClassicDOSReplayRecorder.stateHash(of: completed.simulation) == states[0])
        #expect(ClassicDOSReplayRecorder.stateHash(of: live) == liveHash)
        #expect(ClassicDOSReplayRecorder.stateHash(of: initial) == hash)
        let mismatch = ClassicDOSReplay(rank: "", number: 1, title: "", initialStateHash: "other", events: [])
        #expect(ClassicSolutionGhost(initial: initial, replay: mismatch) == nil)
    }

    @Test func silhouetteRetainsTransparentSpaceAndAddsAnOutline() {
        let frame = SolutionGhostPixels(rgba: Data([255, 255, 255, 255]), width: 1, height: 1)
        #expect(frame.width == 3 && frame.height == 3 && frame.padding == 1)
        #expect(frame.rgba[(1 * 3 + 1) * 4 + 3] == 50)
        #expect(frame.rgba[(0 * 3 + 1) * 4 + 3] == 110)
        #expect(frame.rgba[3] == 0)
        #expect(SolutionGhostPixels(rgba: Data(repeating: 0, count: 16), width: 2, height: 2).rgba.allSatisfy { $0 == 0 })
    }
}
