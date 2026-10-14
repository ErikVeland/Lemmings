import Foundation

/// A replay check stops when its recorded level or live state has drifted.
public enum NxrpReplayPlaybackError: Error, Equatable, Sendable {
    case incompleteReplay([NxrpRecordedCheckIssue])
    case invalidFrame(sequence: UInt64)
    case missingLemming(sequence: UInt64)
    case assignmentStateMismatch(
        sequence: UInt64,
        expectedPosition: NeoLemmixPoint,
        actualPosition: NeoLemmixPoint,
        expectedDirection: NeoLemmixDirection,
        actualDirection: NeoLemmixDirection,
        actualAction: NeoLemmixAction
    )
    case spawnedCountMismatch(sequence: UInt64)
    case assignmentRejected(sequence: UInt64, reason: NeoLemmixAssignmentRejection)
    case unsupportedCommand(sequence: UInt64)
    case completionFrameMismatch(expected: Int, actual: Int?)
}

/// A source replay assignment whose repair metadata no longer matches the
/// selected native lemming. CE keeps playing, but the mismatch is useful when
/// locating the first physics divergence.
public struct NxrpSourceStateDivergence: Codable, Equatable, Sendable {
    public let sequence: UInt64
    public let expectedPosition: NeoLemmixPoint
    public let actualPosition: NeoLemmixPoint
    public let expectedDirection: NeoLemmixDirection
    public let actualDirection: NeoLemmixDirection
    public let actualAction: NeoLemmixAction
}

public struct NxrpSourceRemovalObservation: Codable, Equatable, Sendable {
    public let tick: Int
    public let lemmingID: Int
    public let reason: NeoLemmixRemovalReason
    public let position: NeoLemmixPoint
}

/// Applies source replay frames to a fresh native simulation with live checks.
public struct NxrpReplayPlayback: Codable, Equatable, Sendable {
    public private(set) var simulation: NeoLemmixSimulation
    /// Assignment failures CE ignored while playing a source replay.
    public private(set) var sourceAssignmentRejections: [NeoLemmixAssignmentResult]
    /// Repair-metadata mismatches CE ignores during normal source playback.
    public private(set) var sourceStateDivergences: [NxrpSourceStateDivergence]
    public private(set) var sourceRemovalObservations: [NxrpSourceRemovalObservation]
    public var observedCompletionFrame: Int? { firstRescueFrame }

    private let replay: NxrpReplay
    private let expectedCompletionFrame: Int?
    private let validatesRecordedState: Bool
    private var identifiers: [Int: String]
    private var firstRescueFrame: Int?

    public init(
        replay: NxrpReplay,
        level: NxlvLevel,
        renderedLevel: NxlvRenderedLevel
    ) throws {
        try replay.verifyLevelIdentity(level)
        let issues = replay.recordedCheckIssues()
        guard issues.isEmpty, let completionFrame = replay.metadata.expectedCompletionFrame,
              completionFrame > 0 else {
            throw NxrpReplayPlaybackError.incompleteReplay(issues)
        }
        guard replay.commands.allSatisfy({ $0.tick >= 0 && $0.tick < Int.max }) else {
            throw NxrpReplayPlaybackError.invalidFrame(
                sequence: replay.commands.first { $0.tick < 0 || $0.tick == Int.max }?.sequence ?? 0
            )
        }

        self.simulation = try NeoLemmixSimulation(level: level, renderedLevel: renderedLevel)
        self.sourceAssignmentRejections = []
        self.sourceStateDivergences = []
        self.sourceRemovalObservations = []
        self.replay = replay
        self.expectedCompletionFrame = completionFrame
        self.validatesRecordedState = true
        self.firstRescueFrame = nil

        var names: [Int: String] = [:]
        var duplicateCounts: [String: Int] = [:]
        for (index, lemming) in simulation.configuration.preplacedLemmings.enumerated() {
            let base = "P\(lemming.position.x).\(lemming.position.y)"
            let duplicate = duplicateCounts[base, default: 0]
            names[index] = duplicate == 0 ? base : base + String(format: ".%03d", duplicate)
            duplicateCounts[base] = duplicate + 1
        }
        self.identifiers = names
    }

    /// Loads an older source replay that has state checks but no recorded
    /// completion frame. NeoLemmix matches these replays by level ID and uses
    /// the recorded lemming index when no stable identifier is present.
    public init(
        sourceCompatibleReplay replay: NxrpReplay,
        level: NxlvLevel,
        renderedLevel: NxlvRenderedLevel
    ) throws {
        guard let replayID = replay.metadata.levelID, let levelID = level.id else {
            throw NxrpReplayIdentityError.missingIdentity
        }
        guard replayID == levelID else {
            throw NxrpReplayIdentityError.differentLevel
        }
        let issues = replay.recordedCheckIssues().filter {
            if case .missingCompletionFrame = $0 { return false }
            return true
        }
        guard issues.isEmpty else {
            throw NxrpReplayPlaybackError.incompleteReplay(issues)
        }
        guard replay.commands.allSatisfy({ $0.tick >= 0 && $0.tick < Int.max }) else {
            throw NxrpReplayPlaybackError.invalidFrame(
                sequence: replay.commands.first { $0.tick < 0 || $0.tick == Int.max }?.sequence ?? 0
            )
        }

        self.simulation = try NeoLemmixSimulation(level: level, renderedLevel: renderedLevel)
        self.sourceAssignmentRejections = []
        self.sourceStateDivergences = []
        self.sourceRemovalObservations = []
        self.replay = replay
        self.expectedCompletionFrame = replay.metadata.expectedCompletionFrame
        // CE uses the identifier or recorded index to select a lemming. The
        // position and direction fields are replay-repair metadata and are not
        // playback preconditions. CE also keeps playing after a rejected
        // assignment instead of treating it as a corrupt replay.
        self.validatesRecordedState = false
        self.firstRescueFrame = nil

        var names: [Int: String] = [:]
        var duplicateCounts: [String: Int] = [:]
        for (index, lemming) in simulation.configuration.preplacedLemmings.enumerated() {
            let base = "P\(lemming.position.x).\(lemming.position.y)"
            let duplicate = duplicateCounts[base, default: 0]
            names[index] = duplicate == 0 ? base : base + String(format: ".%03d", duplicate)
            duplicateCounts[base] = duplicate + 1
        }
        self.identifiers = names
    }

    /// Advances one CE frame. The source processes replay input before this update.
    @discardableResult
    public mutating func step() throws -> [NeoLemmixEvent] {
        let sourceFrame = simulation.tickCount
        guard (!validatesRecordedState || expectedCompletionFrame.map({ sourceFrame < $0 }) ?? true),
              !simulation.isComplete else {
            throw NxrpReplayPlaybackError.completionFrameMismatch(
                expected: expectedCompletionFrame ?? sourceFrame, actual: firstRescueFrame
            )
        }

        let due = replay.commands.filter { $0.tick == sourceFrame }.sorted { left, right in
            let leftPriority = Self.priority(left.command)
            let rightPriority = Self.priority(right.command)
            return leftPriority == rightPriority
                ? left.sequence < right.sequence : leftPriority < rightPriority
        }
        var planned: [NeoLemmixCommand] = []
        var preview = simulation
        var previewIdentifiers = identifiers
        for item in due {
            let command: NeoLemmixCommand
            switch item.command {
            case let .assign(recordedIndex, skill):
                guard let evidence = replay.commandEvidence.first(where: {
                    if case let .assignment(sequence, _, _, _, _, _) = $0 {
                        return sequence == item.sequence
                    }
                    return false
                }), case let .assignment(_, name, x?, y?, direction?, _) = evidence else {
                    throw NxrpReplayPlaybackError.missingLemming(sequence: item.sequence)
                }
                let lemmingID: Int
                if let recordedName = name {
                    guard let identifiedID = previewIdentifiers.first(where: {
                        $0.value == recordedName
                    })?.key else {
                        throw NxrpReplayPlaybackError.missingLemming(sequence: item.sequence)
                    }
                    lemmingID = identifiedID
                } else {
                    lemmingID = recordedIndex
                }
                guard let lemming = preview.lemmings.first(where: { $0.id == lemmingID }) else {
                    throw NxrpReplayPlaybackError.missingLemming(sequence: item.sequence)
                }
                if !validatesRecordedState,
                   !lemming.isActive
                    || lemming.position != NeoLemmixPoint(x: x, y: y)
                    || lemming.direction != direction {
                    sourceStateDivergences.append(NxrpSourceStateDivergence(
                        sequence: item.sequence,
                        expectedPosition: NeoLemmixPoint(x: x, y: y),
                        actualPosition: lemming.position,
                        expectedDirection: direction,
                        actualDirection: lemming.direction,
                        actualAction: lemming.action
                    ))
                }
                guard !validatesRecordedState || (
                    lemming.isActive
                        && lemming.position == NeoLemmixPoint(x: x, y: y)
                        && lemming.direction == direction
                ) else {
                    throw NxrpReplayPlaybackError.assignmentStateMismatch(
                        sequence: item.sequence,
                        expectedPosition: NeoLemmixPoint(x: x, y: y),
                        actualPosition: lemming.position,
                        expectedDirection: direction,
                        actualDirection: lemming.direction,
                        actualAction: lemming.action
                    )
                }
                command = .assign(lemmingID: lemmingID, skill: skill)
                let assignment = preview.assign(skill: skill, to: lemmingID)
                guard assignment.wasAssigned || !validatesRecordedState else {
                    guard case let .rejected(_, _, reason) = assignment else {
                        preconditionFailure("A non-assigned result must contain a rejection reason.")
                    }
                    throw NxrpReplayPlaybackError.assignmentRejected(
                        sequence: item.sequence,
                        reason: reason
                    )
                }
                if skill == .cloner, let clone = preview.lemmings.last,
                   clone.cloneParentID == lemmingID {
                    previewIdentifiers[clone.id] = "C\(sourceFrame)"
                }
            case let .setSpawnInterval(interval):
                guard let evidence = replay.commandEvidence.first(where: {
                    if case let .spawnInterval(sequence, _) = $0 { return sequence == item.sequence }
                    return false
                }), case let .spawnInterval(_, spawned?) = evidence,
                    (!validatesRecordedState || spawned == simulation.lemmings.count) else {
                    throw NxrpReplayPlaybackError.spawnedCountMismatch(sequence: item.sequence)
                }
                command = .setSpawnInterval(interval)
            case .nuke:
                command = .nuke
            }
            planned.append(command)
        }
        for command in planned {
            simulation.enqueue(command, atTick: sourceFrame + 1)
        }

        let events = simulation.tick()
        for event in events {
            switch event {
            case let .hatched(lemmingID, _):
                identifiers[lemmingID] = "N\(simulation.releasedCount - 1)"
            case let .cloned(_, cloneID):
                identifiers[cloneID] = "C\(sourceFrame)"
            case let .assignment(.rejected(lemmingID, skill, reason)):
                guard validatesRecordedState else {
                    sourceAssignmentRejections.append(.rejected(
                        lemmingID: lemmingID,
                        skill: skill,
                        reason: reason
                    ))
                    break
                }
                let sequence = due.first {
                    $0.command == .assign(lemmingID: lemmingID, skill: skill)
                }?.sequence ?? 0
                throw NxrpReplayPlaybackError.assignmentRejected(sequence: sequence, reason: reason)
            case let .removed(lemmingID, reason):
                if let lemming = simulation.lemmings.first(where: { $0.id == lemmingID }) {
                    sourceRemovalObservations.append(NxrpSourceRemovalObservation(
                        tick: simulation.tickCount,
                        lemmingID: lemmingID,
                        reason: reason,
                        position: lemming.position
                    ))
                }
            case let .unsupportedCommand(command):
                let sequence = due.first { $0.command == command }?.sequence ?? 0
                throw NxrpReplayPlaybackError.unsupportedCommand(sequence: sequence)
            default:
                break
            }
        }

        if simulation.configuration.requiredToSave > 0,
           simulation.savedCount >= simulation.configuration.requiredToSave,
           firstRescueFrame == nil {
            firstRescueFrame = simulation.tickCount
        }
        if validatesRecordedState,
           let expectedCompletionFrame, let actual = firstRescueFrame,
           actual != expectedCompletionFrame {
            throw NxrpReplayPlaybackError.completionFrameMismatch(
                expected: expectedCompletionFrame, actual: actual
            )
        }
        if validatesRecordedState,
           let expectedCompletionFrame,
           simulation.tickCount == expectedCompletionFrame,
           firstRescueFrame == nil {
            throw NxrpReplayPlaybackError.completionFrameMismatch(
                expected: expectedCompletionFrame, actual: nil
            )
        }
        return events
    }

    /// Runs through the recorded rescue frame; this does not prove final CE state parity.
    public mutating func runToExpectedFrame() throws {
        guard let expectedCompletionFrame else {
            throw NxrpReplayPlaybackError.incompleteReplay([.missingCompletionFrame])
        }
        while simulation.tickCount < expectedCompletionFrame {
            try step()
        }
    }

    /// Uses the same five-minute tail as NeoLemmix's replay checker when an
    /// older replay has no completion frame. The return value reports whether
    /// the native run reached the level's rescue requirement.
    public mutating func runToSourceCutoff(tailFrames: Int = 5 * 60 * 17) throws -> Bool {
        let lastActionFrame = replay.commands.map(\.tick).max() ?? 0
        let cutoff = max(lastActionFrame, expectedCompletionFrame ?? 0) + max(0, tailFrames)
        while simulation.tickCount <= cutoff && !simulation.isComplete
            && firstRescueFrame == nil {
            try step()
        }
        return simulation.savedCount >= simulation.configuration.requiredToSave
    }

    private static func priority(_ command: NeoLemmixCommand) -> Int {
        if case .setSpawnInterval = command { return 0 }
        return 1
    }
}
