import XCTest
import NxlvKit
@testable import LemmingsLocal

final class NeoLemmixSoundTests: XCTestCase {
    private func makeSession(preplaced: Bool = true) throws -> NeoLemmixSession {
        var terrain = try NeoLemmixTerrain(width: 160, height: 64)
        for x in 0..<160 { terrain.setSolid(true, x: x, y: 40) }
        let configuration = try NeoLemmixConfiguration(
            totalLemmings: 1, requiredToSave: 1, spawnInterval: 4,
            entranceOpenTick: 1, firstSpawnDelay: 1,
            entrances: [.init(id: 0, position: .init(x: 20, y: 40))],
            preplacedLemmings: preplaced ? [.init(position: .init(x: 20, y: 40))] : [],
            skills: [.climber: .finite(2), .bomber: .finite(1)])
        return NeoLemmixSession(simulation: try .init(terrain: terrain, configuration: configuration),
                               width: 160, height: 64)
    }

    func testHatchAndAssignmentReachSessionSoundOutput() throws {
        let session = try makeSession(preplaced: false)
        for _ in 0..<5 {
            session.tick()
            if session.lastCues.contains(.doorOpen) { break }
        }
        XCTAssertEqual(session.lastCues, [.doorOpen, .letsGo])
        XCTAssertEqual(session.lastPositionedCues.first?.point, .init(x: 20, y: 40))
        for _ in 0..<10 where session.lemmings.isEmpty { session.tick() }
        let id = try XCTUnwrap(session.lemmings.first?.id)
        let skill = try XCTUnwrap(session.skills.firstIndex { $0.name == "Climber" })
        XCTAssertNil(session.assign(skillIndex: skill, to: id))
        XCTAssertEqual(session.lastCues, [.assignSkill])
        XCTAssertNotNil(session.lastPositionedCues.first?.point)
        XCTAssertNotNil(session.assign(skillIndex: skill, to: id))
        XCTAssertTrue(session.lastCues.isEmpty)
        session.tick()
        XCTAssertFalse(session.lastCues.contains(.assignSkill))
    }

    func testQueuedNukeAndUndoDoNotReplayOldCues() throws {
        let session = try makeSession()
        let skill = try XCTUnwrap(session.skills.firstIndex { $0.name == "Climber" })
        XCTAssertNil(session.assign(skillIndex: skill, to: 0))
        session.nuke()
        XCTAssertTrue(session.lastCues.isEmpty)
        session.tick()
        XCTAssertTrue(session.lastCues.contains(.nuke))
        session.undoNuke()
        XCTAssertTrue(session.lastCues.isEmpty)
        session.tick()
        XCTAssertFalse(session.lastCues.contains(.nuke))
    }

    func testNukeExplosionSoundsOnceWithoutChangingSimulation() throws {
        let session = try makeSession()
        session.nuke()
        var reference = session.simulation
        var effects: [ClassicSoundEffect] = []
        for _ in 0..<400 where !session.isComplete {
            session.tick()
            _ = reference.tick()
            XCTAssertEqual(session.simulation, reference)
            effects += session.lastCues
        }
        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(effects.filter { $0 == .nuke }.count, 1)
        XCTAssertEqual(effects.filter { $0 == .explode }.count, 1)
        session.tick()
        XCTAssertTrue(session.lastCues.isEmpty)
    }

    func testDeathsAndRescuesKeepTheirPositionsWithoutDuplicateDeathSounds() {
        let lemming = NeoLemmixLemming(id: 7, position: .init(x: 90, y: 30), direction: .right)
        let events: [NeoLemmixEvent] = [
            .actionChanged(lemmingID: 7, from: .walking, to: .splatting),
            .removed(lemmingID: 7, reason: .splatted),
            .actionChanged(lemmingID: 7, from: .walking, to: .drowning),
            .removed(lemmingID: 7, reason: .drowned),
            .actionChanged(lemmingID: 7, from: .walking, to: .vaporizing),
            .removed(lemmingID: 7, reason: .burned),
            .removed(lemmingID: 7, reason: .trapped),
            .removed(lemmingID: 7, reason: .fellOut),
            .removed(lemmingID: 7, reason: .saved),
            .completed(didWin: true)]
        let cues = NeoLemmixSoundCue.positionedCues(for: events, lemmings: [lemming], entrances: [])
        XCTAssertEqual(cues.map(\.effect), [.splat, .drown, .vaporize, .vaporize, .fallOut, .exitLevel, .yippee])
        XCTAssertTrue(cues.allSatisfy { $0.point == .init(x: 90, y: 30) })
    }
}
