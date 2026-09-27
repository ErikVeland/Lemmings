import Foundation

/// A replay check stops when its recorded level or live state has drifted.
public enum NxrpReplayPlaybackError: Error, Equatable, Sendable {
    case incompleteReplay([NxrpRecordedCheckIssue])
    case invalidFrame(sequence: UInt64)
    case missingLemming(sequence: UInt64)
    case assignmentStateMismatch(sequence: UInt64)
    case spawnedCountMismatch(sequence: UInt64)
    case assignmentRejected(sequence: UInt64)
    case unsupportedCommand(sequence: UInt64)
    case completionFrameMismatch(expected: Int, actual: Int?)
}

/// Applies source replay frames to a fresh native simulation with live checks.
public struct NxrpReplayPlayback: Sendable {
    public private(set) var simulation: NeoLemmixSimulation

    private let replay: NxrpReplay
    private let expectedCompletionFrame: Int
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
        self.replay = replay
        self.expectedCompletionFrame = completionFrame
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
        guard sourceFrame < expectedCompletionFrame, !simulation.isComplete else {
            throw NxrpReplayPlaybackError.completionFrameMismatch(
                expected: expectedCompletionFrame, actual: firstRescueFrame
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
            case let .assign(_, skill):
                guard let evidence = replay.commandEvidence.first(where: {
                    if case let .assignment(sequence, _, _, _, _, _) = $0 {
                        return sequence == item.sequence
                    }
                    return false
                }), case let .assignment(_, name?, x?, y?, direction?, _) = evidence,
                    let lemmingID = previewIdentifiers.first(where: { $0.value == name })?.key,
                    let lemming = preview.lemmings.first(where: { $0.id == lemmingID }) else {
                    throw NxrpReplayPlaybackError.missingLemming(sequence: item.sequence)
                }
                guard lemming.isActive,
                      lemming.position == NeoLemmixPoint(x: x, y: y),
                      lemming.direction == direction else {
                    throw NxrpReplayPlaybackError.assignmentStateMismatch(sequence: item.sequence)
                }
                command = .assign(lemmingID: lemmingID, skill: skill)
                guard preview.assign(skill: skill, to: lemmingID).wasAssigned else {
                    throw NxrpReplayPlaybackError.assignmentRejected(sequence: item.sequence)
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
                    spawned == simulation.lemmings.count else {
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
            case let .assignment(.rejected(lemmingID, skill, _)):
                let sequence = due.first {
                    $0.command == .assign(lemmingID: lemmingID, skill: skill)
                }?.sequence ?? 0
                throw NxrpReplayPlaybackError.assignmentRejected(sequence: sequence)
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
        if let actual = firstRescueFrame, actual != expectedCompletionFrame {
            throw NxrpReplayPlaybackError.completionFrameMismatch(
                expected: expectedCompletionFrame, actual: actual
            )
        }
        if simulation.tickCount == expectedCompletionFrame, firstRescueFrame == nil {
            throw NxrpReplayPlaybackError.completionFrameMismatch(
                expected: expectedCompletionFrame, actual: nil
            )
        }
        return events
    }

    /// Runs through the recorded rescue frame; this does not prove final CE state parity.
    public mutating func runToExpectedFrame() throws {
        while simulation.tickCount < expectedCompletionFrame {
            try step()
        }
    }

    private static func priority(_ command: NeoLemmixCommand) -> Int {
        if case .setSpawnInterval = command { return 0 }
        return 1
    }
}
