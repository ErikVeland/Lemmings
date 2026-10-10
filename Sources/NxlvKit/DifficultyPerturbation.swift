import Foundation

public struct DifficultyTimingProbe: Codable, Equatable, Sendable {
    public let sequence: UInt64
    public let outcomes: [Int: Bool]
    /// Sampled usable slack on either side of the reference assignment.
    /// A broad one-sided window is forgiving even when the recorded click is at its boundary.
    private func directionalTolerance(_ sign: Int) -> Int {
        var result = 0
        for distance in [1, 2, 4, 8, 16] {
            guard outcomes[sign * distance] == true else { break }
            result = distance
        }
        return result
    }
    public var tolerance: Int { max(directionalTolerance(-1), directionalTolerance(1)) }
    public var sampledWindowWidth: Int { 1 + directionalTolerance(-1) + directionalTolerance(1) }
    public var hasMeasuredBoundaries: Bool {
        outcomes.contains { $0.key < 0 && !$0.value } && outcomes.contains { $0.key > 0 && !$0.value }
    }
    public var isNarrow: Bool {
        (outcomes[-1] == false || outcomes[-2] == false)
            && (outcomes[1] == false || outcomes[2] == false)
    }
}

public struct DifficultyPrecisionEvidence: Codable, Equatable, Sendable {
    public let actions: [DifficultyTimingProbe]
    public let assignmentCount: Int
    public let runCount: Int
    public let completed: Bool
    public var selectionOutcomes: [UInt64: [Int: Bool]] = [:]
    public var alternativeRunCount: Int = 0
    public var orderingOutcomes: [UInt64: Bool] = [:]
    /// Position is not an assignment parameter in these replay engines.
    public var positionSensitivity: Double? { nil }
    public var selectionTolerance: Double? {
        let outcomes = selectionOutcomes.values.flatMap { $0.values }
        return outcomes.isEmpty ? nil : Double(outcomes.filter { $0 }.count) / Double(outcomes.count)
    }
    public var medianTolerance: Int? {
        let sorted = measuredTolerances.sorted()
        return sorted.isEmpty ? nil : sorted[sorted.count / 2]
    }
    private var measuredTolerances: [Int] {
        actions.filter { $0.isNarrow || ($0.outcomes[-1] != nil && $0.outcomes[1] != nil) }.map(\.tolerance)
    }
    public var narrowestTolerance: Int? { measuredTolerances.min() }
    public var burden: Double {
        guard !actions.isEmpty else { return 0 }
        let mean = actions.reduce(0.0) { total, action in
            // Missing probes are unknown, not failures. A partially tested forgiving
            // action must not be labelled precise because larger offsets are untested.
            total + (action.hasMeasuredBoundaries ? 1 - Double(action.tolerance) / 16 : 0)
        } / Double(actions.count)
        let critical = Double(actions.filter(\.isNarrow).count)
        let timing = mean * DifficultyCalibration.timingSensitivity
            + pow(critical, DifficultyCalibration.criticalActionExponent) * DifficultyCalibration.criticalAction
        let selection = selectionTolerance.map { (1 - $0) * DifficultyCalibration.selectionSensitivity } ?? 0
        return (timing + selection).clampedDifficulty
    }
}

/// Probes individual actions, with a fixed run budget and cancellation between runs.
/// Errors and timeouts propagate: they are not evidence of execution sensitivity.
public enum DifficultyPerturbation {
    public static func analyse(commands: [NeoLemmixReplayCommand], maximumRuns: Int = DifficultyModel.maximumProbeRuns,
                               succeeds: ([NeoLemmixReplayCommand]) throws -> Bool?) throws -> DifficultyPrecisionEvidence {
        guard commands.allSatisfy({ $0.tick >= 0 && $0.tick <= Int.max - 16 }),
              Set(commands.map(\.sequence)).count == commands.count else {
            throw DifficultyAnalysisError.invalidReplayCommands
        }
        let assignments = commands.filter { if case .assign = $0.command { true } else { false } }
            .sorted { $0.tick == $1.tick ? $0.sequence < $1.sequence : $0.tick < $1.tick }
        var outcomes: [UInt64: [Int: Bool]] = [:]
        var runs = 0
        var inconclusiveRuns = 0
        // Round-robin offsets cover all actions before spending more on any one action.
        probes: for offset in DifficultyModel.timingOffsets {
            for assignment in assignments {
                try Task.checkCancellation()
                guard runs < max(0, maximumRuns) else { break }
                guard assignment.tick + offset >= 0 else { continue }
                let changed = commands.map { command in
                    command.sequence == assignment.sequence
                        ? NeoLemmixReplayCommand(tick: command.tick + offset, sequence: command.sequence, command: command.command)
                        : command
                }
                let outcome = try succeeds(changed)
                outcomes[assignment.sequence, default: [:]][offset] = outcome
                runs += 1
                if outcome == nil { inconclusiveRuns += 1 }
                if inconclusiveRuns >= 2 { break probes }
            }
        }
        let actions = assignments.compactMap { assignment -> DifficultyTimingProbe? in
            guard let probes = outcomes[assignment.sequence] else { return nil }
            return DifficultyTimingProbe(sequence: assignment.sequence, outcomes: probes)
        }
        let complete = assignments.allSatisfy { assignment in
            DifficultyModel.timingOffsets.filter { assignment.tick + $0 >= 0 }.allSatisfy {
                outcomes[assignment.sequence]?[$0] != nil
            }
        }
        return DifficultyPrecisionEvidence(actions: actions, assignmentCount: assignments.count,
                                           runCount: runs, completed: complete)
    }
}
