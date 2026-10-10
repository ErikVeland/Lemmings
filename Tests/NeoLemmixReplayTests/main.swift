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
    try require(replay.commandEvidence == [
        .assignment(
            sequence: 0,
            lemmingIdentifier: "ABCDEF",
            x: 20,
            y: 40,
            direction: .right,
            highlighted: false
        ),
        .spawnInterval(sequence: 1, spawnedLemmings: 1),
    ], "Replay assignment and spawn cross-checks were not retained.")
    try require(replay.recordedCheckIssues().isEmpty,
                "A complete replay reported missing source checks.")

    let matchingLevel = try NxlvLevel(text: "TITLE Fixture\nID x1234ABCD\nVERSION x00000002")
        .unwrap("A matching level did not decode.")
    try replay.verifyLevelIdentity(matchingLevel)
    let otherLevel = try NxlvLevel(text: "TITLE Fixture\nID x1234ABCD\nVERSION x00000003")
        .unwrap("A changed level did not decode.")
    do {
        try replay.verifyLevelIdentity(otherLevel)
        throw TestFailure(description: "A replay accepted a changed level version.")
    } catch NxrpReplayIdentityError.differentLevel {}

    let zeroVersionReplay = NxrpReplay(
        metadata: NxrpMetadata(levelID: 0x1234_ABCD, levelVersion: 0),
        commands: []
    )
    let implicitZeroLevel = try NxlvLevel(text: "TITLE Fixture\nID x1234ABCD")
        .unwrap("An implicit-version level did not decode.")
    try zeroVersionReplay.verifyLevelIdentity(implicitZeroLevel)
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

private func testSourceDirectionAliases() throws {
    let decoded = NxrpReplayDecoder.decode("""
    $ASSIGNMENT
      FRAME 1
      LEM_INDEX 0
      LEM_DIR l
      ACTION builder
    $END
    $ASSIGNMENT
      FRAME 2
      LEM_INDEX 1
      LEM_DIR R
      ACTION builder
    $END
    """)
    let replay = try decoded.replay.unwrap("A direction-alias replay did not decode.")
    try require(replay.commandEvidence == [
        .assignment(sequence: 0, lemmingIdentifier: nil, x: nil, y: nil,
                    direction: .left, highlighted: false),
        .assignment(sequence: 1, lemmingIdentifier: nil, x: nil, y: nil,
                    direction: .right, highlighted: false),
    ], "NeoLemmix replay direction aliases were not retained.")
}

private func testLegacyIndexAssignmentChecks() throws {
    let decoded = NxrpReplayDecoder.decode("""
    ID x1
    VERSION 1
    COMPLETION_FRAME 10
    $ASSIGNMENT
      FRAME 1
      LEM_INDEX 0
      LEM_X 20
      LEM_Y 40
      LEM_DIR right
      ACTION builder
    $END
    """)
    let replay = try decoded.replay.unwrap("An index-based replay did not decode.")
    try require(replay.recordedCheckIssues().isEmpty,
                "A replay with the source index and state checks required a newer identifier.")
}

private func testCheckedPlayback() throws {
    let level = try NxlvLevel(text: """
    TITLE Checked replay
    ID x0000000A
    VERSION x00000001
    WIDTH 64
    HEIGHT 64
    LEMMINGS 1
    SAVE_REQUIREMENT 1
    SPAWN_INTERVAL 10
    $SKILLSET
      CLIMBER 1
      CLONER 1
    $END
    $GADGET
      STYLE default
      PIECE exit
      X 22
      Y 40
    $END
    $LEMMING
      X 20
      Y 48
    $END
    """).unwrap("The checked replay level did not decode.")
    let pixels = 64 * 64
    let solid = (0..<pixels).map { $0 / 64 >= 48 ? UInt8(1) : UInt8(0) }
    let rendered = NxlvRenderedLevel(
        width: 64,
        height: 64,
        rgba: Array(repeating: 0, count: pixels * 4),
        solidMask: solid,
        steelMask: Array(repeating: 0, count: pixels),
        oneWayMask: Array(repeating: 0, count: pixels),
        oneWayEligibleMask: Array(repeating: 0, count: pixels),
        gadgets: [NxlvRenderedGadget(
            style: "default", piece: "exit", effect: .exit,
            x: 22, y: 40, width: 8, height: 12,
            triggerX: 22, triggerY: 46, triggerWidth: 6, triggerHeight: 3
        )]
    )
    var baseline = try NeoLemmixSimulation(level: level, renderedLevel: rendered)
    baseline.enqueue(.setSpawnInterval(4), atTick: 1)
    baseline.enqueue(.assign(lemmingID: 0, skill: .climber), atTick: 1)
    for _ in 0..<100 where baseline.savedCount == 0 { baseline.tick() }
    try require(baseline.savedCount == 1, "The checked replay fixture did not reach its exit.")

    func replayText(x: Int = 20, spawned: Int = 1) -> String {
        """
        ID x0000000A
        VERSION x00000001
        COMPLETION_FRAME \(baseline.tickCount)
        $ASSIGNMENT
          FRAME 0
          LEM_INDEX 0
          LEM_IDENTIFIER P20.48
          LEM_X \(x)
          LEM_Y 48
          LEM_DIR right
          ACTION climber
        $END
        $SPAWN_INTERVAL
          FRAME 0
          RATE 4
          SPAWNED \(spawned)
        $END
        """
    }
    let replay = try NxrpReplayDecoder.decode(replayText()).replay
        .unwrap("The checked replay did not decode.")
    var playback = try NxrpReplayPlayback(replay: replay, level: level, renderedLevel: rendered)
    let firstEvents = try playback.step()
    try require(firstEvents.first == .spawnIntervalChanged(4),
                "CE spawn-interval changes did not run before assignments.")
    try require(firstEvents.contains(.assignment(.assigned(lemmingID: 0, skill: .climber))),
                "The frame-zero assignment did not run on the first native tick.")
    let checkpoint = try JSONEncoder().encode(playback)
    var recoveredPlayback = try JSONDecoder().decode(NxrpReplayPlayback.self, from: checkpoint)
    try playback.runToExpectedFrame()
    try recoveredPlayback.runToExpectedFrame()
    try require(playback.simulation.savedCount == 1,
                "The checked replay did not reach its recorded rescue frame.")
    try require(recoveredPlayback == playback,
                "Encoded checked replay playback diverged after recovery.")
    var repeated = try NxrpReplayPlayback(replay: replay, level: level, renderedLevel: rendered)
    try repeated.runToExpectedFrame()
    try require(repeated.simulation.snapshot() == playback.simulation.snapshot(),
                "Checked replay playback changed between identical runs.")

    let sourceText = replayText()
        .replacingOccurrences(of: "VERSION x00000001", with: "VERSION x00000000")
        .replacingOccurrences(
            of: "COMPLETION_FRAME \(baseline.tickCount)\n",
            with: ""
        )
    let sourceReplay = try NxrpReplayDecoder.decode(sourceText).replay
        .unwrap("The older source-compatible replay did not decode.")
    var sourcePlayback = try NxrpReplayPlayback(
        sourceCompatibleReplay: sourceReplay,
        level: level,
        renderedLevel: rendered
    )
    let sourceCompleted = try sourcePlayback.runToSourceCutoff()
    try require(sourceCompleted,
                "The older source-compatible replay did not complete.")
    try require(sourcePlayback.simulation.savedCount == 1,
                "The older replay did not preserve its winning result.")

    let checkedSourceReplay = try NxrpReplayDecoder.decode(
        sourceText.replacingOccurrences(
            of: "VERSION x00000000\n",
            with: "VERSION x00000000\nCOMPLETION_FRAME \(baseline.tickCount)\n"
        )
    ).replay.unwrap("The source-compatible replay with a completion frame did not decode.")
    var checkedSourcePlayback = try NxrpReplayPlayback(
        sourceCompatibleReplay: checkedSourceReplay,
        level: level,
        renderedLevel: rendered
    )
    let checkedSourceCompleted = try checkedSourcePlayback.runToSourceCutoff()
    try require(checkedSourceCompleted,
                "Source-compatible playback continued past its matching rescue frame.")

    let staleCheckedSourceReplay = try NxrpReplayDecoder.decode(
        sourceText.replacingOccurrences(
            of: "VERSION x00000000\n",
            with: "VERSION x00000000\nCOMPLETION_FRAME \(baseline.tickCount + 1)\n"
        )
    ).replay.unwrap("The source replay with a stale completion frame did not decode.")
    var staleCheckedSourcePlayback = try NxrpReplayPlayback(
        sourceCompatibleReplay: staleCheckedSourceReplay,
        level: level,
        renderedLevel: rendered
    )
    let staleCheckedSourceCompleted = try staleCheckedSourcePlayback.runToSourceCutoff()
    try require(staleCheckedSourceCompleted,
                "CE-compatible checking rejected a replay that completed before its stale frame.")

    let sourceMoved = try NxrpReplayDecoder.decode(
        sourceText.replacingOccurrences(of: "LEM_X 20", with: "LEM_X 21")
    ).replay.unwrap("The source replay with repair metadata drift did not decode.")
    var sourceMovedPlayback = try NxrpReplayPlayback(
        sourceCompatibleReplay: sourceMoved,
        level: level,
        renderedLevel: rendered
    )
    let sourceMovedCompleted = try sourceMovedPlayback.runToSourceCutoff()
    try require(sourceMovedCompleted,
                "CE-compatible playback treated repair coordinates as a precondition.")

    let rejectedSourceText = sourceText + """

    $ASSIGNMENT
      FRAME 1
      LEM_INDEX 0
      LEM_IDENTIFIER P20.48
      LEM_X 21
      LEM_Y 48
      LEM_DIR right
      ACTION climber
    $END
    """
    let rejectedSource = try NxrpReplayDecoder.decode(rejectedSourceText).replay
        .unwrap("The source replay with a rejected assignment did not decode.")
    var rejectedSourcePlayback = try NxrpReplayPlayback(
        sourceCompatibleReplay: rejectedSource,
        level: level,
        renderedLevel: rendered
    )
    let rejectedSourceCompleted = try rejectedSourcePlayback.runToSourceCutoff()
    try require(rejectedSourceCompleted,
                "CE-compatible playback aborted after a rejected assignment.")
    try require(rejectedSourcePlayback.sourceAssignmentRejections.count == 1,
                "CE-compatible playback did not retain its ignored assignment rejection.")

    let moved = try NxrpReplayDecoder.decode(replayText(x: 21)).replay
        .unwrap("The changed-position replay did not decode.")
    var movedPlayback = try NxrpReplayPlayback(replay: moved, level: level, renderedLevel: rendered)
    do {
        try movedPlayback.step()
        throw TestFailure(description: "A replay accepted changed lemming coordinates.")
    } catch NxrpReplayPlaybackError.assignmentStateMismatch(sequence: 0, _, _, _, _, _) {}

    let countChanged = try NxrpReplayDecoder.decode(replayText(spawned: 2)).replay
        .unwrap("The changed-spawn replay did not decode.")
    var countPlayback = try NxrpReplayPlayback(
        replay: countChanged, level: level, renderedLevel: rendered
    )
    do {
        try countPlayback.step()
        throw TestFailure(description: "A replay accepted a changed spawned count.")
    } catch NxrpReplayPlaybackError.spawnedCountMismatch(sequence: 1) {}
    try require(countPlayback.simulation.queuedCommands.isEmpty,
                "A rejected replay left a partial command queue.")
    var sourceCountPlayback = try NxrpReplayPlayback(
        sourceCompatibleReplay: countChanged, level: level, renderedLevel: rendered
    )
    let sourceCountCompleted = try sourceCountPlayback.runToSourceCutoff()
    try require(sourceCountCompleted,
                "Source-compatible playback rejected a recorded spawned-count mismatch.")
    try require(sourceCountPlayback.simulation.savedCount == 1,
                "The tolerated spawned-count mismatch changed the winning result.")

    var cloneBaseline = try NeoLemmixSimulation(level: level, renderedLevel: rendered)
    cloneBaseline.enqueue(.assign(lemmingID: 0, skill: .cloner), atTick: 1)
    cloneBaseline.enqueue(.assign(lemmingID: 1, skill: .climber), atTick: 1)
    for _ in 0..<100 where cloneBaseline.savedCount == 0 { cloneBaseline.tick() }
    try require(cloneBaseline.savedCount > 0, "The clone replay fixture did not reach an exit.")
    let cloneText = """
    ID x0000000A
    VERSION x00000001
    COMPLETION_FRAME \(cloneBaseline.tickCount)
    $ASSIGNMENT
      FRAME 0
      LEM_INDEX 0
      LEM_IDENTIFIER P20.48
      LEM_X 20
      LEM_Y 48
      LEM_DIR right
      ACTION cloner
    $END
    $ASSIGNMENT
      FRAME 0
      LEM_INDEX 1
      LEM_IDENTIFIER C0
      LEM_X 20
      LEM_Y 48
      LEM_DIR left
      ACTION climber
    $END
    """
    let cloneReplay = try NxrpReplayDecoder.decode(cloneText).replay
        .unwrap("The same-frame clone replay did not decode.")
    var clonePlayback = try NxrpReplayPlayback(
        replay: cloneReplay, level: level, renderedLevel: rendered
    )
    let cloneEvents = try clonePlayback.step()
    try require(cloneEvents.contains(.assignment(.assigned(lemmingID: 1, skill: .climber))),
                "The same-frame assignment to the clone was not applied.")
    try clonePlayback.runToExpectedFrame()
    try require(clonePlayback.simulation.snapshot() == cloneBaseline.snapshot(),
                "The same-frame clone replay diverged from direct assignments.")

    let changedClone = try NxrpReplayDecoder.decode(
        cloneText.replacingOccurrences(of: "LEM_IDENTIFIER C0", with: "LEM_IDENTIFIER C1")
    ).replay.unwrap("The changed clone replay did not decode.")
    var changedClonePlayback = try NxrpReplayPlayback(
        replay: changedClone, level: level, renderedLevel: rendered
    )
    do {
        try changedClonePlayback.step()
        throw TestFailure(description: "A replay accepted a clone with a changed identifier.")
    } catch NxrpReplayPlaybackError.missingLemming(sequence: 1) {}
    try require(changedClonePlayback.simulation.queuedCommands.isEmpty,
                "A rejected clone replay left a partial command queue.")
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

    let invalidChecks = NxrpReplayDecoder.decode("""
    $ASSIGNMENT
      FRAME 1
      LEM_INDEX 0
      LEM_X wrong
      LEM_DIR sideways
      ACTION builder
    $END
    $SPAWN_INTERVAL
      FRAME 2
      RATE 8
      SPAWNED -1
    $END
    """)
    try require(invalidChecks.replay == nil, "Invalid replay cross-checks were accepted.")
    try require(
        invalidChecks.diagnostics.contains { $0.code == .malformedInteger }
            && invalidChecks.diagnostics.filter { $0.code == .invalidValue }.count == 2,
        "Invalid replay cross-check fields were not diagnosed."
    )

    let incomplete = NxrpReplayDecoder.decode("""
    $ASSIGNMENT
      FRAME 1
      LEM_INDEX 0
      ACTION builder
    $END
    """)
    let incompleteReplay = try incomplete.replay.unwrap("A minimal import replay did not decode.")
    try require(
        incompleteReplay.recordedCheckIssues() == [
            .missingLevelIdentity, .missingCompletionFrame, .missingAssignmentCheck(0)
        ],
        "The replay gate did not identify missing playback source checks."
    )

    let zeroFrame = NxrpReplayDecoder.decode("ID x1\nVERSION x1\nCOMPLETION_FRAME 0")
    try require(zeroFrame.replay?.recordedCheckIssues() == [.missingCompletionFrame],
                "A zero completion frame was accepted as winning replay evidence.")
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
    try testSourceDirectionAliases()
    print("PASS source replay direction aliases")
    try testLegacyIndexAssignmentChecks()
    print("PASS legacy replay index fallback with source state checks")
    try testCheckedPlayback()
    print("PASS source-frame timing, CE command order and replay state checks")
    try testDiagnostics()
    print("PASS malformed and legacy replay diagnostics")
    print("NeoLemmix replay tests passed.")
} catch {
    fputs("NeoLemmix replay test failed: \(error)\n", stderr)
    exit(1)
}
