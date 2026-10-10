import Foundation
import NxlvKit

public typealias Lemmings2MobileRenderer = (
    _ runtime: Lemmings2Runtime,
    _ highlight: MobileTargetSelection?
) throws -> MobilePixelFrame

public final class Lemmings2MobileSession: MobileGameSession {
    private enum Input: Codable {
        case assign(tick: Int, control: Int, target: Int)
        case endRun(tick: Int)
    }

    private struct Checkpoint: Codable {
        var version = 1
        let initialFingerprint: String
        let tick: Int
        let inputs: [Input]
    }

    public let engineIdentifier = "lemmings2"
    public let engineFingerprint: String
    public let levelIdentifier: String
    public let levelIndex: Int
    public let levelFingerprint: String
    public let levelSize: MobileSize
    public let ticksPerSecond = Lemmings2Runtime.ticksPerSecond

    private let initial: Lemmings2Runtime
    private let renderer: Lemmings2MobileRenderer?
    private var runtime: Lemmings2Runtime
    private var beforeEndRun: Lemmings2Runtime?
    private var inputs: [Input] = []

    public init(
        runtime: Lemmings2Runtime,
        engineFingerprint: String,
        levelIdentifier: String,
        levelIndex: Int,
        levelFingerprint: String,
        renderer: Lemmings2MobileRenderer? = nil
    ) {
        initial = runtime
        self.runtime = runtime
        self.engineFingerprint = engineFingerprint
        self.levelIdentifier = levelIdentifier
        self.levelIndex = levelIndex
        self.levelFingerprint = levelFingerprint
        self.renderer = renderer
        levelSize = MobileSize(
            width: Double(runtime.configuration.width),
            height: Double(runtime.configuration.height)
        )
    }

    public var snapshot: MobileGameSnapshot {
        MobileGameSnapshot(
            tick: runtime.tick,
            released: runtime.released,
            total: runtime.configuration.total,
            saved: runtime.saved,
            required: 1,
            remainingSeconds: runtime.remainingSeconds,
            releaseRate: nil,
            isComplete: runtime.isComplete,
            didWin: runtime.didWin,
            isEndingRun: runtime.isNuking,
            skills: runtime.configuration.skills.enumerated().map { index, skill in
                MobileSkillState(name: skill.name, count: runtime.supplies[index])
            }
        )
    }

    public func tick() {
        runtime.step()
        _ = runtime.drainSoundEvents()
        if !runtime.isNuking { beforeEndRun = nil }
    }

    public func targetCandidates(for control: Int) -> [MobileTargetCandidate] {
        guard runtime.configuration.skills.indices.contains(control) else { return [] }
        return runtime.lemmings.filter(\.active).map { lemming in
            MobileTargetCandidate(
                id: lemming.id,
                point: MobilePoint(x: Double(lemming.x), y: Double(lemming.y - 5)),
                direction: lemming.direction,
                assignment: runtime.canAssign(slot: control, to: lemming.id) ? .eligible : .unavailable,
                isBuilding: lemming.state == .building
            )
        }
    }

    @discardableResult
    public func assign(control: Int, to target: Int) -> Bool {
        guard runtime.assign(slot: control, to: target) else { return false }
        inputs.append(.assign(tick: runtime.tick, control: control, target: target))
        return true
    }

    public func adjustReleaseRate(by delta: Int) -> Bool { false }

    @discardableResult
    public func beginEndRun() -> Bool {
        guard !runtime.isComplete, !runtime.isNuking, beforeEndRun == nil else { return false }
        beforeEndRun = runtime
        runtime.nuke()
        inputs.append(.endRun(tick: runtime.tick))
        return true
    }

    @discardableResult
    public func undoEndRun() -> Bool {
        guard let beforeEndRun else { return false }
        runtime = beforeEndRun
        self.beforeEndRun = nil
        if case .endRun = inputs.last { inputs.removeLast() }
        return true
    }

    public func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        guard let renderer else { throw MobileSessionError.frameUnavailable }
        return try renderer(runtime, highlight)
    }

    public func checkpointPayload() throws -> Data {
        try JSONEncoder().encode(Checkpoint(
            initialFingerprint: levelFingerprint,
            tick: runtime.tick,
            inputs: inputs
        ))
    }

    public func restoreCheckpointPayload(_ data: Data) throws {
        let checkpoint = try JSONDecoder().decode(Checkpoint.self, from: data)
        guard checkpoint.version == 1 else { throw MobileCheckpointError.version }
        guard checkpoint.initialFingerprint == levelFingerprint else { throw MobileSessionError.changedLevel }
        var restored = initial
        var restoredBeforeEndRun: Lemmings2Runtime?
        for input in checkpoint.inputs {
            let inputTick: Int
            switch input {
            case let .assign(tick, _, _), let .endRun(tick): inputTick = tick
            }
            while restored.tick < inputTick, !restored.isComplete {
                restored.step()
                _ = restored.drainSoundEvents()
            }
            guard restored.tick == inputTick, !restored.isComplete else {
                throw MobileSessionError.invalidCheckpoint
            }
            switch input {
            case let .assign(_, control, target):
                guard restored.assign(slot: control, to: target) else {
                    throw MobileSessionError.invalidCheckpoint
                }
            case .endRun:
                guard !restored.isNuking else { throw MobileSessionError.invalidCheckpoint }
                restoredBeforeEndRun = restored
                restored.nuke()
            }
        }
        while restored.tick < checkpoint.tick, !restored.isComplete {
            restored.step()
            _ = restored.drainSoundEvents()
        }
        guard restored.tick == checkpoint.tick, !restored.isComplete else {
            throw MobileSessionError.invalidCheckpoint
        }
        runtime = restored
        inputs = checkpoint.inputs
        beforeEndRun = restoredBeforeEndRun
    }

    public func releaseTransientResources() {}
}

public typealias Lemmings3MobileRenderer = (
    _ runtime: Lemmings3Runtime,
    _ highlight: MobileTargetSelection?
) throws -> MobilePixelFrame

public final class Lemmings3MobileSession: MobileGameSession {
    private struct Input: Codable {
        let tick: Int
        let action: String
        let target: Int?
    }

    private struct Checkpoint: Codable {
        var version = 1
        let initialFingerprint: String
        let tick: Int
        let inputs: [Input]
    }

    public let engineIdentifier = "lemmings3"
    public let engineFingerprint: String
    public let levelIdentifier: String
    public let levelIndex: Int
    public let levelFingerprint: String
    public let levelSize: MobileSize
    public let ticksPerSecond = Lemmings3Runtime.ticksPerSecond

    private let initial: Lemmings3Runtime
    private let renderer: Lemmings3MobileRenderer?
    private var runtime: Lemmings3Runtime
    private var inputs: [Input] = []

    public init(
        runtime: Lemmings3Runtime,
        engineFingerprint: String,
        levelIdentifier: String,
        levelIndex: Int,
        levelFingerprint: String,
        renderer: Lemmings3MobileRenderer? = nil
    ) {
        initial = runtime
        self.runtime = runtime
        self.engineFingerprint = engineFingerprint
        self.levelIdentifier = levelIdentifier
        self.levelIndex = levelIndex
        self.levelFingerprint = levelFingerprint
        self.renderer = renderer
        levelSize = MobileSize(
            width: Double(runtime.configuration.width),
            height: Double(runtime.configuration.height)
        )
    }

    public var snapshot: MobileGameSnapshot {
        MobileGameSnapshot(
            tick: runtime.tick,
            released: runtime.released,
            total: runtime.configuration.total,
            saved: runtime.saved,
            required: 1,
            remainingSeconds: runtime.remainingSeconds,
            releaseRate: nil,
            isComplete: runtime.isComplete,
            didWin: runtime.isComplete && runtime.saved > 0,
            isEndingRun: false,
            skills: Lemmings3Runtime.Action.allCases.map {
                MobileSkillState(name: $0.rawValue.capitalized, count: 0, isUnlimited: true)
            }
        )
    }

    public func tick() {
        runtime.step()
    }

    public func targetCandidates(for control: Int) -> [MobileTargetCandidate] {
        guard Lemmings3Runtime.Action.allCases.indices.contains(control) else { return [] }
        let action = Lemmings3Runtime.Action.allCases[control]
        return runtime.lemmings.filter(\.active).map { lemming in
            var probe = runtime
            return MobileTargetCandidate(
                id: lemming.id,
                point: MobilePoint(x: Double(lemming.x), y: Double(lemming.y - 8)),
                direction: lemming.direction,
                assignment: probe.assign(action, to: lemming.id) ? .eligible : .unavailable,
                isBuilding: lemming.state == .building,
                hasTool: lemming.tool != nil
            )
        }
    }

    @discardableResult
    public func assign(control: Int, to target: Int) -> Bool {
        guard Lemmings3Runtime.Action.allCases.indices.contains(control) else { return false }
        let action = Lemmings3Runtime.Action.allCases[control]
        guard runtime.assign(action, to: target) else { return false }
        inputs.append(Input(tick: runtime.tick, action: action.rawValue, target: target))
        return true
    }

    public func adjustReleaseRate(by delta: Int) -> Bool { false }

    @discardableResult
    public func beginEndRun() -> Bool {
        guard !runtime.isComplete else { return false }
        inputs.append(Input(tick: runtime.tick, action: "abort", target: nil))
        runtime.abort()
        return true
    }

    public func undoEndRun() -> Bool { false }

    public func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        guard let renderer else { throw MobileSessionError.frameUnavailable }
        return try renderer(runtime, highlight)
    }

    public func checkpointPayload() throws -> Data {
        guard !runtime.isComplete else { throw MobileSessionError.invalidCheckpoint }
        return try JSONEncoder().encode(Checkpoint(
            initialFingerprint: levelFingerprint,
            tick: runtime.tick,
            inputs: inputs
        ))
    }

    public func restoreCheckpointPayload(_ data: Data) throws {
        let checkpoint = try JSONDecoder().decode(Checkpoint.self, from: data)
        guard checkpoint.version == 1 else { throw MobileCheckpointError.version }
        guard checkpoint.initialFingerprint == levelFingerprint else { throw MobileSessionError.changedLevel }
        var restored = initial
        for input in checkpoint.inputs {
            while restored.tick < input.tick, !restored.isComplete { restored.step() }
            guard restored.tick == input.tick, !restored.isComplete else {
                throw MobileSessionError.invalidCheckpoint
            }
            if input.action == "abort" {
                restored.abort()
            } else if let action = Lemmings3Runtime.Action(rawValue: input.action),
                      let target = input.target,
                      restored.assign(action, to: target) {
                continue
            } else {
                throw MobileSessionError.invalidCheckpoint
            }
        }
        while restored.tick < checkpoint.tick, !restored.isComplete { restored.step() }
        guard restored.tick == checkpoint.tick, !restored.isComplete else {
            throw MobileSessionError.invalidCheckpoint
        }
        runtime = restored
        inputs = checkpoint.inputs
    }

    public func releaseTransientResources() {}
}
