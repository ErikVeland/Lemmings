import Foundation
import NxlvKit

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw TestFailure(description: message()) }
}

private func testCurrentReplay() throws {
    let result = NxrpReplayDecoder.decode("""
    USER Test Player
    TITLE Replay Fixture
    AUTHOR Test Author
    GAME Test Pack
    GROUP Rank One
    LEVEL 3
    ID x1234ABCD
    VERSION x00000002
    COMPLETION_FRAME 420
    $ASSIGNMENT
      FRAME 54
      LEM_INDEX 2
      LEM_IDENTIFIER ABCDEF
      LEM_X 20
      LEM_Y 40
      LEM_DIR right
      ACTION builder
    $END
    $SPAWN_INTERVAL
      FRAME 60
      RATE 8
      SPAWNED 1
    $END
    $NUKE
      FRAME 120
    $END
    """)

    let replay = try result.replay.unwrap("A valid current replay did not decode: \(result.diagnostics)")
    try require(!result.hasErrors, "A valid replay reported errors.")
    try require(replay.metadata.user == "Test Player", "The player name was not retained.")
    try require(replay.metadata.levelID == 0x1234_ABCD, "The hexadecimal level ID was not decoded.")
    try require(replay.metadata.levelVersion == 2, "The level version was not decoded.")
    try require(replay.metadata.expectedCompletionFrame == 420, "The completion frame was not decoded.")
    try require(replay.commands == [
        NeoLemmixReplayCommand(
            tick: 54,
            sequence: 0,
            command: .assign(lemmingID: 2, skill: .builder)
        ),
        NeoLemmixReplayCommand(tick: 60, sequence: 1, command: .setSpawnInterval(8)),
        NeoLemmixReplayCommand(tick: 120, sequence: 2, command: .nuke),
    ], "Replay commands did not preserve source order or values.")
}

private func testAllCurrentSkillsAndIntervalAlias() throws {
    let assignments = NeoLemmixSkill.allCases.enumerated().map { index, skill in
        """
        $ASSIGNMENT
          FRAME \(index)
          LEM_INDEX \(index)
          ACTION \(skill.rawValue.uppercased())
        $END
        """
    }.joined(separator: "\n")
    let result = NxrpReplayDecoder.decode(assignments + """

    $SPAWN_INTERVAL
      FRAME 30
      INTERVAL 5
    $END
    """)

    let replay = try result.replay.unwrap("The current skill vocabulary did not decode.")
    try require(
        replay.commands.count == NeoLemmixSkill.allCases.count + 1,
        "The replay did not retain all current skills."
    )
    try require(
        replay.commands.contains(NeoLemmixReplayCommand(
            tick: 15,
            sequence: 15,
            command: .assign(lemmingID: 15, skill: .laserer)
        )),
        "The decoder dropped an imported skill that the simulator does not yet implement."
    )
    try require(
        replay.commands.last == NeoLemmixReplayCommand(
            tick: 30,
            sequence: UInt64(NeoLemmixSkill.allCases.count),
            command: .setSpawnInterval(5)
        ),
        "The INTERVAL compatibility field was not decoded."
    )
}

private func testDiagnostics() throws {
    let legacy = NxrpReplayDecoder.decode("ACTIONS\nASSIGNMENT 1 2 BUILDER\n")
    try require(
        legacy.diagnostics.contains { $0.code == .unsupportedLegacyFormat },
        "The legacy replay format was not rejected explicitly."
    )

    let malformed = NxrpReplayDecoder.decode("""
    LEVEL not-a-number
    ID xnothex
    $ASSIGNMENT
      FRAME never
      LEM_INDEX -1
      ACTION magic
    $END
    $SPAWN_INTERVAL
      FRAME 2
    $END
    """)
    let codes = Set(malformed.diagnostics.map(\.code))
    try require(malformed.replay == nil, "A malformed replay returned a runnable value.")
    try require(codes.contains(.malformedInteger), "Malformed integers were not diagnosed.")
    try require(codes.contains(.invalidValue), "Out-of-range values were not diagnosed.")
    try require(codes.contains(.invalidSkill), "An unknown skill was not diagnosed.")
    try require(codes.contains(.missingRequiredField), "A missing required field was not diagnosed.")

    let unterminated = NxrpReplayDecoder.decode("$NUKE\nFRAME 10\n")
    try require(
        unterminated.diagnostics.contains { $0.code == .malformedDocument },
        "An unterminated section was not rejected."
    )
}

private extension Optional {
    func unwrap(_ message: @autoclosure () -> String) throws -> Wrapped {
        guard let value = self else { throw TestFailure(description: message()) }
        return value
    }
}

do {
    try testCurrentReplay()
    print("PASS current CE replay metadata and command decoding")
    try testAllCurrentSkillsAndIntervalAlias()
    print("PASS all 21 current replay skills and spawn-interval aliases")
    try testDiagnostics()
    print("PASS malformed and legacy replay diagnostics")
    print("NeoLemmix replay tests passed.")
} catch {
    fputs("NeoLemmix replay test failed: \(error)\n", stderr)
    exit(1)
}
