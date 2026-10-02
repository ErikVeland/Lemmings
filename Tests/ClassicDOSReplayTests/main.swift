import Foundation
import NxlvKit

// Proves three things the project could not previously show:
//   1. The engine can actually complete an official level.
//   2. A recorded replay reproduces its result exactly.
//   3. A replay survives a JSON round trip unchanged.

private struct ReplayFailure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw ReplayFailure(description: message()) }
}

private struct Content {
    let campaign: ClassicCampaign
    let assets: ClassicMainDATAssets
    let grounds: [Int: ClassicGroundSet]
    let specials: [Int: ClassicSpecialGraphic]

    init(directory: URL) throws {
        campaign = try ClassicCampaignDefinition.originalDOSLemmings.load(from: directory)
        assets = try ClassicMainDATAssets.load(from: directory)
        var grounds: [Int: ClassicGroundSet] = [:]
        for style in 0..<5 {
            grounds[style] = try ClassicGroundSet.load(style: style, from: directory)
        }
        self.grounds = grounds
        var specials: [Int: ClassicSpecialGraphic] = [:]
        for index in 0..<4 {
            specials[index + 1] = try ClassicSpecialGraphic.load(index: index, from: directory)
        }
        self.specials = specials
    }

    func simulation(at index: Int) throws -> (ClassicDOSSimulation, ClassicCampaignLevel) {
        let entry = campaign.levels[index]
        let level = entry.level
        guard let ground = grounds[level.groundStyle] else {
            throw ReplayFailure(description: "missing ground style \(level.groundStyle)")
        }
        let rendered = try ClassicLevelRenderer.render(
            level, groundSet: ground, specialGraphic: specials[level.specialStyle])
        let simulation = try ClassicDOSSimulation(
            level: level, renderedLevel: rendered, mainDATAssets: assets)
        return (simulation, entry)
    }
}

private let searchTickLimit = ClassicDOSRules.ticksPerSecond * 120

/// Searches for a win using one skill on one lemming.
///
/// Several early Fun levels need exactly one assignment, so this finds a
/// genuine known-good solution without hand-authoring one.
private func findSingleAssignmentWin(
    content: Content,
    levelIndex: Int,
    skills: [ClassicSkill],
    lemmingIDs: [Int],
    tickRange: StrideThrough<Int>
) throws -> ClassicDOSReplay? {
    let (base, entry) = try content.simulation(at: levelIndex)
    let initialHash = ClassicDOSReplayRecorder.stateHash(of: base)

    for skill in skills where base.remainingSkillCount(skill) > 0 {
        for lemmingID in lemmingIDs {
            for tick in tickRange {
                let events = [
                    ClassicDOSReplayEvent(
                        tick: tick, action: .assign(lemmingID: lemmingID, skill: skill))
                ]
                let candidate = ClassicDOSReplay(
                    rank: entry.rank,
                    number: entry.number,
                    title: entry.level.title.trimmingCharacters(in: .whitespaces),
                    initialStateHash: initialHash,
                    events: events
                )
                guard
                    let outcome = try? ClassicDOSReplayPlayer.run(
                        candidate, simulation: base, tickLimit: searchTickLimit, verify: false)
                else { continue }
                if outcome.didWin {
                    return ClassicDOSReplay(
                        rank: candidate.rank,
                        number: candidate.number,
                        title: candidate.title,
                        initialStateHash: initialHash,
                        events: events,
                        expected: outcome
                    )
                }
            }
        }
    }
    return nil
}

private func testDeterminism(content: Content) throws {
    let (simulation, entry) = try content.simulation(at: 0)
    let replay = ClassicDOSReplay(
        rank: entry.rank,
        number: entry.number,
        title: entry.level.title.trimmingCharacters(in: .whitespaces),
        initialStateHash: ClassicDOSReplayRecorder.stateHash(of: simulation),
        events: [ClassicDOSReplayEvent(tick: 60, action: .assign(lemmingID: 0, skill: .digger))]
    )

    let first = try ClassicDOSReplayPlayer.run(
        replay, simulation: simulation, tickLimit: searchTickLimit, verify: false)
    let second = try ClassicDOSReplayPlayer.run(
        replay, simulation: simulation, tickLimit: searchTickLimit, verify: false)

    try require(first == second, "same replay produced different outcomes")
    try require(
        first.stateHash == second.stateHash,
        "state hash is not deterministic: \(first.stateHash) vs \(second.stateHash)")
    print("PASS determinism — identical hash across runs")
}

private func testInitialHashGuard(content: Content) throws {
    let (simulation, entry) = try content.simulation(at: 0)
    let wrong = ClassicDOSReplay(
        rank: entry.rank,
        number: entry.number,
        title: "wrong",
        initialStateHash: "0000000000000000000000000000000000000000000000000000000000000000",
        events: []
    )
    do {
        _ = try ClassicDOSReplayPlayer.run(wrong, simulation: simulation, verify: true)
        throw ReplayFailure(description: "a bad initial hash was accepted")
    } catch let error as ClassicDOSReplayError {
        guard case .initialStateMismatch = error else {
            throw ReplayFailure(description: "wrong error for hash mismatch: \(error)")
        }
    }
    print("PASS initial state hash rejects mismatched data")
}

private func testSpeculativeEarlyStop(content: Content) throws {
    let (simulation, entry) = try content.simulation(at: 2)
    let replay = ClassicDOSReplay(
        rank: entry.rank,
        number: entry.number,
        title: entry.level.title.trimmingCharacters(in: .whitespaces),
        initialStateHash: ClassicDOSReplayRecorder.stateHash(of: simulation),
        events: []
    )
    let short = try ClassicDOSReplayPlayer.run(
        replay, simulation: simulation, tickLimit: searchTickLimit,
        verify: false, stopWhenUnwinnable: true)
    try require(!short.didWin, "speculative replay reported a win after losing too many lemmings")
    do {
        let full = try ClassicDOSReplayPlayer.run(
            replay, simulation: simulation, tickLimit: searchTickLimit, verify: false)
        try require(short.ticks < full.ticks,
            "speculative replay did not stop before the full loss: \(short.ticks), \(full.ticks)")
    } catch ClassicDOSReplayError.tickLimitReached(_) {
        try require(short.ticks < searchTickLimit, "speculative replay reached the full tick limit")
    }
    print("PASS speculative loss stops before full replay completion")
}

private func testRoundTrip(_ replay: ClassicDOSReplay) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    let data = try encoder.encode(replay)
    let decoded = try JSONDecoder().decode(ClassicDOSReplay.self, from: data)
    try require(decoded == replay, "replay changed across a JSON round trip")
    print("PASS replay JSON round trip (\(data.count) bytes)")
}

private func testGolemsSourceAssignment() throws {
    let terrain = try ClassicDOSTerrain(
        width: 192, height: 96,
        solidMask: Data(repeating: 0, count: 192 * 96),
        steelMask: Data(repeating: 0, count: 192 * 96)
    )
    func simulation(_ mechanics: ClassicDOSMechanics) throws -> ClassicDOSSimulation {
        try ClassicDOSSimulation(
            terrain: terrain,
            configuration: ClassicDOSConfiguration(
                totalLemmings: 1, requiredToSave: 1, timeLimitTicks: 300,
                initialReleaseRate: 99,
                entrances: [ClassicDOSPoint(x: 40, y: 0)],
                initialSkills: [.builder: 1],
                maximumX: 191, maximumY: 95,
                mechanics: mechanics
            )
        )
    }
    let initial = try simulation(.golems)
    let events = [ClassicDOSReplayEvent(
        tick: 58, action: .assign(lemmingID: 0, skill: .builder), afterTick: true)]
    let source = ClassicDOSReplay(
        rank: "Fan", number: 1, title: "Falling Builder",
        initialStateHash: ClassicDOSReplayRecorder.stateHash(of: initial),
        events: events, sourceRules: .golemsFallingBuilder
    )
    let ordinary = ClassicDOSReplay(
        rank: source.rank, number: source.number, title: source.title,
        initialStateHash: source.initialStateHash, events: events
    )
    do {
        _ = try ClassicDOSReplayPlayer.run(ordinary, simulation: initial)
        throw ReplayFailure(description: "ordinary replay accepted a falling Builder")
    } catch ClassicDOSReplayError.commandRejected(tick: 58, lemmingID: 0, skill: .builder) {}

    let outcome = try ClassicDOSReplayPlayer.run(source, simulation: initial)
    let stored = ClassicDOSReplay(
        rank: source.rank, number: source.number, title: source.title,
        initialStateHash: source.initialStateHash, events: events,
        sourceRules: .golemsFallingBuilder, expected: outcome
    )
    let encoded = try JSONEncoder().encode(stored)
    let decoded = try JSONDecoder().decode(ClassicDOSReplay.self, from: encoded)
    try require(decoded == stored, "source assignment rule changed across JSON")
    let verified = try ClassicDOSReplayPlayer.run(decoded, simulation: initial)
    try require(verified == outcome,
        "saved source replay failed strict verification")
    let ordinaryObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ordinary)) as! [String: Any]
    try require(ordinaryObject["sourceRules"] == nil, "ordinary replay acquired source rules")
    do {
        _ = try ClassicDOSReplayPlayer.run(source, simulation: simulation(.original))
        throw ReplayFailure(description: "Golems source input ran under original mechanics")
    } catch ClassicDOSReplayError.outcomeMismatch(field: "sourceRules", expected: _, actual: _) {}
}

// MARK: - Entry point

let arguments = CommandLine.arguments
let directory = arguments.count > 1
    ? URL(fileURLWithPath: arguments[1], isDirectory: true)
    : URL(fileURLWithPath: "Content/lemming1.pc", isDirectory: true)

do {
    let content = try Content(directory: directory)
    try testDeterminism(content: content)
    try testInitialHashGuard(content: content)
    try testSpeculativeEarlyStop(content: content)

    // Fun 1 is the canonical one-assignment level.
    let solved = try findSingleAssignmentWin(
        content: content,
        levelIndex: 0,
        skills: ClassicSkill.allCases,
        lemmingIDs: [0],
        tickRange: stride(from: 36, through: 400, by: 1)
    )

    guard let solved, let expected = solved.expected else {
        print("NOTE no single-assignment win found for level 1.")
        print("     The engine runs but cannot yet complete Fun 1 unaided.")
        print("     This is the next physics gap to close.")
        exit(1)
    }

    print(
        "PASS solved \(solved.rank) \(solved.number) '\(solved.title)' —"
            + " saved \(expected.saved)/\(expected.required) in \(expected.ticks) ticks")

    let verified = try ClassicDOSReplayPlayer.run(
        solved, simulation: content.simulation(at: 0).0, tickLimit: searchTickLimit, verify: true)
    try require(verified == expected, "verified replay did not match its recorded outcome")
    let speculativeWin = try ClassicDOSReplayPlayer.run(
        solved, simulation: content.simulation(at: 0).0, tickLimit: searchTickLimit,
        verify: false, stopWhenUnwinnable: true)
    try require(speculativeWin == verified, "speculative check changed a winning replay")
    print("PASS recorded replay verifies against a fresh simulation")

    try testRoundTrip(solved)
    try testGolemsSourceAssignment()
    print("Classic DOS replay tests passed.")
} catch {
    FileHandle.standardError.write(Data("Replay tests failed: \(error)\n".utf8))
    exit(1)
}
