import AVFoundation
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
    private func soundSession(skill: NeoLemmixSkill, steel: Bool = false) throws -> NeoLemmixSession {
        var terrain = try NeoLemmixTerrain(width: 240, height: 100)
        for x in 0..<(skill == .platformer ? 31 : 240) {
            for y in 60..<100 { terrain.setSolid(true, x: x, y: y) }
        }
        if steel {
            for x in 0..<240 { terrain.setSteel(true, x: x, y: 64) }
        }
        let config = try NeoLemmixConfiguration(totalLemmings: 1, requiredToSave: 1,
            spawnInterval: 4, entrances: [],
            preplacedLemmings: [.init(position: .init(x: 30, y: 60))],
            skills: [skill: .finite(1)])
        return NeoLemmixSession(simulation: try .init(terrain: terrain, configuration: config),
                               width: 240, height: 100)
    }

    func testConstructiveWarningsUseLastThreeBricks() throws {
        for skill in [NeoLemmixSkill.builder, .platformer, .stacker] {
            let session = try soundSession(skill: skill)
            XCTAssertNil(session.assign(skillIndex: 0, to: 0))
            var warnings: [(frame: Int, bricks: Int)] = []
            for _ in 0..<220 {
                session.tick()
                if session.lastCues.contains(.builderWarning) {
                    let worker = try XCTUnwrap(session.simulation.lemmings.first)
                    warnings.append((worker.animationFrame, worker.bricksRemaining))
                    XCTAssertNotNil(session.lastPositionedCues.first?.point)
                }
            }
            XCTAssertEqual(warnings.count, 3, skill.rawValue)
            XCTAssertEqual(warnings.map(\.bricks), skill == .stacker ? [2, 1, 0] : [3, 2, 1])
            XCTAssertEqual(warnings.map(\.frame), skill == .stacker ? [0, 0, 0] : [10, 10, 10])
        }
    }

    func testDiggerSteelContactSoundsOnceAndOrdinaryTerrainStaysSilent() throws {
        for steel in [false, true] {
            let session = try soundSession(skill: .digger, steel: steel)
            XCTAssertNil(session.assign(skillIndex: 0, to: 0))
            var cues: [ClassicSoundEffect] = []
            for _ in 0..<100 { session.tick(); cues += session.lastCues }
            XCTAssertEqual(cues.filter { $0 == .hitSteel }.count, steel ? 1 : 0)
        }
    }

    func testCustomTrapReplacesFallbackAndDisarmingStaysSilent() {
        let worker = NeoLemmixLemming(id: 7, position: .init(x: 90, y: 30), direction: .right)
        let zone = NeoLemmixZone(id: 2, effect: .trap,
            bounds: .init(x: 90, y: 30, width: 4, height: 4), visualGadgetID: 9)
        let event = NeoLemmixEvent.hazardTriggered(lemmingID: 7, zoneID: 2, effect: .trap)
        let cues = NeoLemmixSoundCue.positionedCues(for: [event, .removed(lemmingID: 7, reason: .trapped)],
            lemmings: [worker], entrances: [], zones: [zone], gadgetSounds: [9: "thud"])
        XCTAssertEqual(cues.count, 1)
        XCTAssertEqual(cues.first?.sampleName, "thud")
        XCTAssertEqual(cues.first?.point, .init(x: 90, y: 30))
        let silent = NeoLemmixSoundCue.positionedCues(for: [event, .zoneDisarmed(lemmingID: 7, zoneID: 2)],
            lemmings: [worker], entrances: [], zones: [zone], gadgetSounds: [9: "thud"])
        XCTAssertTrue(silent.isEmpty)
    }

    func testGadgetActivationUsesNamedSamplesWithoutDeathFallback() {
        let worker = NeoLemmixLemming(id: 7, position: .init(x: 90, y: 30), direction: .right)
        for effect in [NeoLemmixZoneEffect.teleporter, .animation, .animationOnce] {
            let zone = NeoLemmixZone(id: 2, effect: effect,
                bounds: .init(x: 90, y: 30, width: 4, height: 4), visualGadgetID: 9)
            let cues = NeoLemmixSoundCue.positionedCues(
                for: [.hazardTriggered(lemmingID: 7, zoneID: 2, effect: effect)],
                lemmings: [worker], entrances: [], zones: [zone], gadgetSounds: [9: "electric"])
            XCTAssertEqual(cues.count, 1)
            XCTAssertEqual(cues.first?.sampleName, "electric")
            XCTAssertEqual(cues.first?.allowsFallback, false)
        }
    }

    func testNamedSamplePlaybackDeduplicatesHonoursMuteAndClearsBetweenLevels() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 22050, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100))
        buffer.frameLength = 100
        for i in 0..<100 { buffer.floatChannelData![0][i] = Float(i) / 100 }
        do {
            let file = try AVAudioFile(forWriting: root.appendingPathComponent("thud.wav"), settings: format.settings)
            try file.write(from: buffer)
        }
        let player = SoundEffectPlayer()
        player.loadNeoLemmixSounds(names: ["thud"], soundDirectory: root, amigaDirectory: nil)
        final class Capture: @unchecked Sendable { var count = 0; var rate = 0.0 }
        let capture = Capture()
        player.onPlay = { _, rate, _ in capture.count += 1; capture.rate = rate }
        let cue = PositionedSoundCue(.vaporize, at: .init(x: 10, y: 20), sampleName: "THUD", allowsFallback: false)
        player.play([cue, cue])
        XCTAssertEqual(capture.count, 1)
        XCTAssertEqual(capture.rate, 22050)
        player.setMuted(true)
        player.play([cue])
        XCTAssertEqual(capture.count, 1)
        player.setMuted(false)
        player.loadNeoLemmixSounds(names: [], soundDirectory: root, amigaDirectory: nil)
        player.play([cue])
        XCTAssertEqual(capture.count, 1)
        player.loadNeoLemmixSounds(names: ["../thud"], soundDirectory: root.appendingPathComponent("child"), amigaDirectory: nil)
        player.play([.init(.vaporize, sampleName: "../thud", allowsFallback: false)])
        XCTAssertEqual(capture.count, 1)
    }

    func testDestructiveSkillsSoundAtSteelButNotOneWayTerrain() throws {
        for skill in [NeoLemmixSkill.basher, .fencer, .miner] {
            for steel in [false, true] {
                var terrain = try NeoLemmixTerrain(width: 240, height: 140)
                for x in 0..<240 {
                    for y in 60..<140 { terrain.setSolid(true, x: x, y: y) }
                }
                if skill != .miner {
                    for x in 31..<240 {
                        for y in 10..<60 { terrain.setSolid(true, x: x, y: y) }
                    }
                }
                for x in 45..<240 {
                    for y in 10..<140 {
                        if steel { terrain.setSteel(true, x: x, y: y) }
                        else { terrain.setOneWay(.left, x: x, y: y) }
                    }
                }
                let config = try NeoLemmixConfiguration(totalLemmings: 1, requiredToSave: 1,
                    spawnInterval: 4, entrances: [],
                    preplacedLemmings: [.init(position: .init(x: 30, y: 60))],
                    skills: [skill: .finite(1)])
                let session = NeoLemmixSession(simulation: try .init(terrain: terrain, configuration: config),
                                               width: 240, height: 140)
                XCTAssertNil(session.assign(skillIndex: 0, to: 0), skill.rawValue)
                var cues: [ClassicSoundEffect] = []
                for _ in 0..<200 { session.tick(); cues += session.lastCues }
                XCTAssertEqual(cues.filter { $0 == .hitSteel }.count, steel ? 1 : 0, skill.rawValue)
            }
        }
    }

    func testSoundEventsRoundTripAndContinueWithoutRepeatingWarning() throws {
        let session = try soundSession(skill: .builder)
        XCTAssertNil(session.assign(skillIndex: 0, to: 0))
        for _ in 0..<200 {
            session.tick()
            if session.lastCues.contains(.builderWarning) { break }
        }
        XCTAssertTrue(session.lastCues.contains(.builderWarning))
        let encoded = try JSONEncoder().encode(session.simulation)
        let decoded = try JSONDecoder().decode(NeoLemmixSimulation.self, from: encoded)
        XCTAssertEqual(decoded, session.simulation)
        let continued = NeoLemmixSession(simulation: decoded, width: 240, height: 100)
        XCTAssertTrue(continued.lastCues.isEmpty)
        for _ in 0..<40 {
            continued.tick(); session.tick()
            XCTAssertEqual(continued.simulation, session.simulation)
            XCTAssertEqual(continued.lastCues, session.lastCues)
        }
    }

    func testResolvedGadgetMetadataKeepsSoundAndVisualIdentity() throws {
        let metadata = try XCTUnwrap(NxlvStyleMetadataDecoder.decodeObject(text: "EFFECT TRAP\nSOUND thud\n").metadata)
        let asset = NxlvResolvedStyleAsset(reference: .init(kind: .object, style: "orig_marble", piece: "trap"),
            styleDirectoryURL: URL(fileURLWithPath: "/unused"), graphicURLs: [], metadataURL: nil,
            terrainMetadata: nil, objectMetadata: metadata)
        let gadget = NxlvRenderedGadget(style: "ORIG_MARBLE", piece: "TRAP", effect: .trap,
            x: 10, y: 20, width: 10, height: 10, triggerX: nil, triggerY: nil,
            triggerWidth: nil, triggerHeight: nil)
        XCTAssertEqual(NeoLemmixSoundCue.gadgetSounds(for: [gadget],
            resolution: .init(assets: [asset], diagnostics: [])), [0: "thud"])
    }

}
