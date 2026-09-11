import CryptoKit
import Foundation

/// A deterministic record of one played level.
///
/// A replay stores player input against tick numbers, never against wall-clock
/// time. Replaying it on the same level data must reproduce the same result on
/// every machine. The initial state hash guards against silent drift: if the
/// level data or the engine changes, the hash stops matching and the replay
/// fails loudly instead of reporting a false pass.

public enum ClassicDOSReplayAction: Codable, Equatable, Sendable {
    case assign(lemmingID: Int, skill: ClassicSkill)
    case releaseRate(Int)
    case nuke
}

public struct ClassicDOSReplayEvent: Codable, Equatable, Sendable {
    public let tick: Int
    public let action: ClassicDOSReplayAction
    /// Live input occurs after the current tick. Missing values preserve legacy replay timing.
    public let afterTick: Bool?

    public init(tick: Int, action: ClassicDOSReplayAction, afterTick: Bool? = nil) {
        self.tick = tick
        self.action = action
        self.afterTick = afterTick
    }
}

public struct ClassicDOSReplayOutcome: Codable, Equatable, Sendable {
    public let ticks: Int
    public let released: Int
    public let saved: Int
    public let required: Int
    public let didWin: Bool
    public let stateHash: String

    public init(
        ticks: Int, released: Int, saved: Int, required: Int, didWin: Bool, stateHash: String
    ) {
        self.ticks = ticks
        self.released = released
        self.saved = saved
        self.required = required
        self.didWin = didWin
        self.stateHash = stateHash
    }
}

public struct ClassicDOSReplay: Codable, Equatable, Sendable {
    /// Campaign rank, such as `Fun` or `Mayhem`.
    public let rank: String
    /// One-based level number inside the rank.
    public let number: Int
    public let title: String
    /// State hash of the simulation before the first tick.
    public let initialStateHash: String
    public let events: [ClassicDOSReplayEvent]
    /// The result a correct engine must reproduce.
    public let expected: ClassicDOSReplayOutcome?

    public init(
        rank: String,
        number: Int,
        title: String,
        initialStateHash: String,
        events: [ClassicDOSReplayEvent],
        expected: ClassicDOSReplayOutcome? = nil
    ) {
        self.rank = rank
        self.number = number
        self.title = title
        self.initialStateHash = initialStateHash
        self.events = events
        self.expected = expected
    }
}

public enum ClassicDOSReplayError: Error, Equatable, CustomStringConvertible {
    case initialStateMismatch(expected: String, actual: String)
    case outcomeMismatch(field: String, expected: String, actual: String)
    case tickLimitReached(Int)
    case commandRejected(tick: Int, lemmingID: Int, skill: ClassicSkill)

    public var description: String {
        switch self {
        case let .initialStateMismatch(expected, actual):
            return "initial state hash mismatch: expected \(expected), got \(actual)"
        case let .outcomeMismatch(field, expected, actual):
            return "replay \(field) mismatch: expected \(expected), got \(actual)"
        case let .tickLimitReached(limit):
            return "replay did not complete within \(limit) ticks"
        case let .commandRejected(tick, lemmingID, skill):
            return "engine refused to queue \(skill.rawValue) for lemming \(lemmingID) at tick \(tick)"
        }
    }
}

public enum ClassicDOSReplayRecorder {
    /// Hashes a simulation into a stable fingerprint.
    ///
    /// This walks the state in a fixed order rather than encoding it. Encoding
    /// looked simpler, but `skills` is keyed by an enum, and Swift writes such
    /// a dictionary as an unkeyed array whose order follows dictionary
    /// iteration. Sorted JSON keys do not reorder array elements, so two loads
    /// of the same level could hash differently and a saved replay would stop
    /// verifying. Every collection below is walked in a defined order.
    public static func stateHash(of simulation: ClassicDOSSimulation) -> String {
        var bytes = Data()

        func append(_ value: Int) {
            withUnsafeBytes(of: Int64(value).littleEndian) { bytes.append(contentsOf: $0) }
        }
        func append(_ value: Bool) { bytes.append(value ? 1 : 0) }
        func append(_ value: Int?) {
            bytes.append(value == nil ? 0 : 1)
            append(value ?? 0)
        }
        func append(_ value: String) { bytes.append(contentsOf: Array(value.utf8)); bytes.append(0) }

        append(simulation.tickCount)
        append(simulation.releasedCount)
        append(simulation.savedCount)
        append(simulation.lostCount)
        append(simulation.releaseRate)
        append(simulation.isNuking)
        append(simulation.remainingTimeTicks)

        // Fixed skill order, never dictionary order.
        for skill in ClassicSkill.allCases {
            append(skill.rawValue)
            append(simulation.remainingSkillCount(skill))
        }

        append(simulation.lemmings.count)
        for lemming in simulation.lemmings {
            append(lemming.id)
            append(lemming.foot.x)
            append(lemming.foot.y)
            append(lemming.direction.rawValue)
            append(lemming.action.rawValue)
            append(lemming.animationFrame)
            append(lemming.fallDistance)
            append(lemming.hasClimber)
            append(lemming.hasFloater)
            append(lemming.bomberCountdown)
            append(lemming.bricksRemaining)
            append(lemming.outcome.rawValue)
            append(lemming.objectBelow.rawValue)
            append(lemming.objectInFront.rawValue)
            append(lemming.ownsBlockerField)
            append(lemming.blockerAnchor?.x)
            append(lemming.blockerAnchor?.y)
            append(lemming.hasZeroHorizontalVelocity)
            append(lemming.isNewDigger)
            append(lemming.floatTableIndex)
        }

        append(simulation.configuration.totalLemmings)
        append(simulation.configuration.requiredToSave)
        append(simulation.configuration.initialReleaseRate)
        append(simulation.configuration.maximumX)
        append(simulation.configuration.maximumY)

        bytes.append(simulation.terrain.canonicalMaskBytes)

        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}

public enum ClassicDOSReplayPlayer {
    /// The default ceiling. Retail levels cap at nine minutes.
    public static let defaultTickLimit = ClassicDOSRules.ticksPerSecond * 60 * 10

    /// Runs a replay against a fresh simulation and returns what happened.
    ///
    /// Skill assignments go through `schedule`, so the engine applies them in
    /// its own DOS order. Release-rate and nuke changes apply before the tick
    /// they are recorded against.
    @discardableResult
    public static func run(
        _ replay: ClassicDOSReplay,
        simulation: ClassicDOSSimulation,
        tickLimit: Int = defaultTickLimit,
        verify: Bool = true
    ) throws -> ClassicDOSReplayOutcome {
        var simulation = simulation

        if verify {
            let actual = ClassicDOSReplayRecorder.stateHash(of: simulation)
            guard actual == replay.initialStateHash else {
                throw ClassicDOSReplayError.initialStateMismatch(
                    expected: replay.initialStateHash, actual: actual)
            }
        }

        var immediate: [Int: [ClassicDOSReplayAction]] = [:]
        var afterTick: [Int: [ClassicDOSReplayAction]] = [:]
        for event in replay.events {
            if event.afterTick == true {
                afterTick[event.tick, default: []].append(event.action)
                continue
            }
            switch event.action {
            case let .assign(lemmingID, skill):
                let command = ClassicDOSSkillCommand(
                    tick: event.tick, lemmingID: lemmingID, skill: skill)
                guard simulation.schedule(command) else {
                    throw ClassicDOSReplayError.commandRejected(
                        tick: event.tick, lemmingID: lemmingID, skill: skill)
                }
            case .releaseRate, .nuke:
                immediate[event.tick, default: []].append(event.action)
            }
        }

        func applyLiveCommands(at tick: Int, to simulation: inout ClassicDOSSimulation) throws {
            for action in afterTick[tick] ?? [] {
                switch action {
                case let .assign(lemmingID, skill):
                    guard simulation.assign(skill, to: lemmingID) == .assigned else {
                        throw ClassicDOSReplayError.commandRejected(tick: tick, lemmingID: lemmingID, skill: skill)
                    }
                case let .releaseRate(value): simulation.setReleaseRate(value)
                case .nuke: simulation.beginNuke()
                }
            }
        }
        try applyLiveCommands(at: simulation.tickCount, to: &simulation)
        var ticks = 0
        while !simulation.isComplete {
            if ticks >= tickLimit { throw ClassicDOSReplayError.tickLimitReached(tickLimit) }
            let next = simulation.tickCount + 1
            for action in immediate[next] ?? [] {
                switch action {
                case let .releaseRate(value): simulation.setReleaseRate(value)
                case .nuke: simulation.beginNuke()
                case .assign: break
                }
            }
            _ = simulation.tick()
            try applyLiveCommands(at: simulation.tickCount, to: &simulation)
            ticks += 1
        }

        let outcome = ClassicDOSReplayOutcome(
            ticks: simulation.tickCount,
            released: simulation.releasedCount,
            saved: simulation.savedCount,
            required: simulation.configuration.requiredToSave,
            didWin: simulation.didWin,
            stateHash: ClassicDOSReplayRecorder.stateHash(of: simulation)
        )

        if verify, let expected = replay.expected {
            try compare(expected: expected, actual: outcome)
        }
        return outcome
    }

    private static func compare(
        expected: ClassicDOSReplayOutcome, actual: ClassicDOSReplayOutcome
    ) throws {
        if expected.saved != actual.saved {
            throw ClassicDOSReplayError.outcomeMismatch(
                field: "saved", expected: "\(expected.saved)", actual: "\(actual.saved)")
        }
        if expected.didWin != actual.didWin {
            throw ClassicDOSReplayError.outcomeMismatch(
                field: "didWin", expected: "\(expected.didWin)", actual: "\(actual.didWin)")
        }
        if expected.ticks != actual.ticks {
            throw ClassicDOSReplayError.outcomeMismatch(
                field: "ticks", expected: "\(expected.ticks)", actual: "\(actual.ticks)")
        }
        if expected.stateHash != actual.stateHash {
            throw ClassicDOSReplayError.outcomeMismatch(
                field: "stateHash", expected: expected.stateHash, actual: actual.stateHash)
        }
    }
}
