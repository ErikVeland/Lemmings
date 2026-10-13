import Foundation
import NxlvKit

public typealias Lemmings2MobileRenderer = (
    _ runtime: Lemmings2Runtime,
    _ highlight: MobileTargetSelection?
) throws -> MobilePixelFrame

public final class Lemmings2MobileSession: MobileGameSession {
    private enum Input: Codable, Sendable {
        case assign(tick: Int, control: Int, target: Int)
        case endRun(tick: Int)
    }

    private struct Checkpoint: Codable, Sendable {
        var version = 1
        let initialFingerprint: String
        let tick: Int
        let inputs: [Input]
        var rewindCount: Int? = nil
        var usedRewind: Bool? = nil
        var nukeCount: Int? = nil
        var undoCount: Int? = nil
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
    private var explosionTimeline = PixelExplosionTimeline()
    public var explosions: [MobileExplosion] {
        explosionTimeline.update(tick: runtime.tick, bursts: PixelExplosion.lemmings2(runtime))
        return explosionTimeline.bursts.map { MobileExplosion($0, at: runtime.tick) }
    }
    private var beforeEndRun: Lemmings2Runtime?
    private var inputs: [Input] = []
    private let onCompletion: ((Lemmings2Runtime) -> Void)?
    private var didNotifyCompletion = false
    public private(set) var rewindCount = 0
    public private(set) var usedRewind = false
    public private(set) var nukeCount = 0
    public private(set) var undoCount = 0

    public init(
        runtime: Lemmings2Runtime,
        engineFingerprint: String,
        levelIdentifier: String,
        levelIndex: Int,
        levelFingerprint: String,
        renderer: Lemmings2MobileRenderer? = nil,
        onCompletion: ((Lemmings2Runtime) -> Void)? = nil
    ) {
        initial = runtime
        self.runtime = runtime
        self.engineFingerprint = engineFingerprint
        self.levelIdentifier = levelIdentifier
        self.levelIndex = levelIndex
        self.levelFingerprint = levelFingerprint
        self.renderer = renderer
        self.onCompletion = onCompletion
        levelSize = MobileSize(
            width: Double(runtime.configuration.width),
            height: Double(runtime.configuration.height)
        )
    }

    public var entrancePoint: MobilePoint {
        let point = initial.configuration.entrance
        return MobilePoint(x: Double(point.x), y: Double(point.y))
    }

    public var activeLemmingCount: Int { runtime.lemmings.filter(\.active).count }
    public var assignedSkillCount: Int {
        inputs.filter { if case .assign = $0 { return true }; return false }.count
    }
    public var supportsRewind: Bool { true }

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
        explosionTimeline.update(tick: runtime.tick, bursts: PixelExplosion.lemmings2(runtime))
        _ = runtime.drainSoundEvents()
        if runtime.isComplete, !didNotifyCompletion {
            didNotifyCompletion = true
            onCompletion?(runtime)
        }
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
                isBuilding: lemming.state == .building,
                pointerBounds: MobileRect(x: -9, y: -12, width: 18, height: 24)
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
        nukeCount += 1
        return true
    }

    @discardableResult
    public func undoEndRun() -> Bool {
        guard let beforeEndRun else { return false }
        runtime = beforeEndRun
        explosionTimeline.reset()
        self.beforeEndRun = nil
        if case .endRun = inputs.last { inputs.removeLast() }
        usedRewind = true
        undoCount += 1
        return true
    }

    public func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        guard let renderer else { throw MobileSessionError.frameUnavailable }
        return try renderer(runtime, highlight)
    }

    public func checkpointPayload() throws -> Data {
        try prepareCheckpointPayload().encode()
    }

    public func prepareCheckpointPayload() -> MobileCheckpointPayload {
        MobileCheckpointPayload(Checkpoint(
            initialFingerprint: levelFingerprint,
            tick: runtime.tick,
            inputs: inputs,
            rewindCount: rewindCount,
            usedRewind: usedRewind,
            nukeCount: nukeCount,
            undoCount: undoCount
        ))
    }

    public func restoreCheckpointPayload(_ data: Data) throws {
        let checkpoint = try JSONDecoder().decode(Checkpoint.self, from: data)
        guard checkpoint.version == 1 else { throw MobileCheckpointError.version }
        guard checkpoint.initialFingerprint == levelFingerprint else { throw MobileSessionError.changedLevel }
        let (restored, restoredBeforeEndRun) = try replay(inputs: checkpoint.inputs, through: checkpoint.tick)
        runtime = restored
        explosionTimeline.reset()
        didNotifyCompletion = false
        inputs = checkpoint.inputs
        beforeEndRun = restoredBeforeEndRun
        rewindCount = checkpoint.rewindCount ?? 0
        usedRewind = checkpoint.usedRewind ?? false
        nukeCount = checkpoint.nukeCount ?? checkpoint.inputs.reduce(into: 0) { count, input in
            if case .endRun = input { count += 1 }
        }
        undoCount = checkpoint.undoCount ?? 0
    }

    @discardableResult
    public func rewind(seconds: Double) -> Bool {
        guard seconds.isFinite, seconds >= 0 else { return false }
        let distance = Int(min(Double(runtime.tick), (seconds * ticksPerSecond).rounded()))
        guard distance > 0 else { return false }
        return move(to: runtime.tick - distance)
    }

    @discardableResult
    public func stepBackward() -> Bool {
        move(to: runtime.tick - 1)
    }

    @discardableResult
    public func stepForward() -> Bool {
        guard !runtime.isComplete else { return false }
        tick()
        return true
    }

    public func resumeFromCurrentTick() {}

    private func move(to tick: Int) -> Bool {
        guard tick >= 0, tick < runtime.tick else { return false }
        do {
            let retainedInputs = inputs.filter { inputTick($0) <= tick }
            let (restored, restoredBeforeEndRun) = try replay(inputs: retainedInputs, through: tick)
            runtime = restored
            inputs = retainedInputs
            beforeEndRun = restoredBeforeEndRun
            explosionTimeline.reset()
            didNotifyCompletion = false
            usedRewind = true
            rewindCount += 1
            return true
        } catch {
            return false
        }
    }

    private func replay(inputs: [Input], through tick: Int) throws -> (Lemmings2Runtime, Lemmings2Runtime?) {
        var restored = initial
        var restoredBeforeEndRun: Lemmings2Runtime?
        var inputIndex = 0
        while restored.tick <= tick {
            while inputIndex < inputs.count, inputTick(inputs[inputIndex]) == restored.tick {
                switch inputs[inputIndex] {
                case let .assign(_, control, target):
                    guard restored.assign(slot: control, to: target) else { throw MobileSessionError.invalidCheckpoint }
                case .endRun:
                    guard !restored.isNuking else { throw MobileSessionError.invalidCheckpoint }
                    restoredBeforeEndRun = restored
                    restored.nuke()
                }
                inputIndex += 1
            }
            if restored.tick == tick { break }
            guard !restored.isComplete else { throw MobileSessionError.invalidCheckpoint }
            restored.step()
            _ = restored.drainSoundEvents()
        }
        guard restored.tick == tick, inputIndex == inputs.count, !restored.isComplete else {
            throw MobileSessionError.invalidCheckpoint
        }
        return (restored, restoredBeforeEndRun)
    }

    private func inputTick(_ input: Input) -> Int {
        switch input {
        case let .assign(tick, _, _), let .endRun(tick): tick
        }
    }

    public func releaseTransientResources() {}
}

public typealias Lemmings3MobileRenderer = (
    _ runtime: Lemmings3Runtime,
    _ highlight: MobileTargetSelection?
) throws -> MobilePixelFrame

public final class Lemmings3MobileSession: MobileGameSession {
    private struct Input: Codable, Sendable {
        let tick: Int
        let action: String
        let target: Int?
    }

    private struct Checkpoint: Codable, Sendable {
        var version = 1
        let initialFingerprint: String
        let tick: Int
        let inputs: [Input]
        var rewindCount: Int? = nil
        var usedRewind: Bool? = nil
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
    private var explosionTimeline = PixelExplosionTimeline()
    public var explosions: [MobileExplosion] {
        explosionTimeline.update(tick: runtime.tick, bursts: PixelExplosion.lemmings3(runtime))
        return explosionTimeline.bursts.map { MobileExplosion($0, at: runtime.tick) }
    }
    private var inputs: [Input] = []
    private let onCompletion: ((Lemmings3Runtime) -> Void)?
    private var didNotifyCompletion = false
    public private(set) var rewindCount = 0
    public private(set) var usedRewind = false

    public init(
        runtime: Lemmings3Runtime,
        engineFingerprint: String,
        levelIdentifier: String,
        levelIndex: Int,
        levelFingerprint: String,
        renderer: Lemmings3MobileRenderer? = nil,
        onCompletion: ((Lemmings3Runtime) -> Void)? = nil
    ) {
        initial = runtime
        self.runtime = runtime
        self.engineFingerprint = engineFingerprint
        self.levelIdentifier = levelIdentifier
        self.levelIndex = levelIndex
        self.levelFingerprint = levelFingerprint
        self.renderer = renderer
        self.onCompletion = onCompletion
        levelSize = MobileSize(
            width: Double(runtime.configuration.width),
            height: Double(runtime.configuration.height)
        )
    }

    public var entrancePoint: MobilePoint {
        let point = initial.configuration.entrance
        return MobilePoint(x: Double(point.x), y: Double(point.y))
    }

    public var activeLemmingCount: Int { runtime.lemmings.filter(\.active).count }
    public var assignedSkillCount: Int { inputs.filter { $0.action != "abort" }.count }
    public var supportsRewind: Bool { true }

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
        explosionTimeline.update(tick: runtime.tick, bursts: PixelExplosion.lemmings3(runtime))
        if runtime.isComplete, !didNotifyCompletion {
            didNotifyCompletion = true
            onCompletion?(runtime)
        }
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
                hasTool: lemming.tool != nil,
                pointerBounds: MobileRect(x: -9, y: -12, width: 18, height: 24)
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
        try prepareCheckpointPayload().encode()
    }

    public func prepareCheckpointPayload() throws -> MobileCheckpointPayload {
        guard !runtime.isComplete else { throw MobileSessionError.invalidCheckpoint }
        return MobileCheckpointPayload(Checkpoint(
            initialFingerprint: levelFingerprint,
            tick: runtime.tick,
            inputs: inputs,
            rewindCount: rewindCount,
            usedRewind: usedRewind
        ))
    }

    public func restoreCheckpointPayload(_ data: Data) throws {
        let checkpoint = try JSONDecoder().decode(Checkpoint.self, from: data)
        guard checkpoint.version == 1 else { throw MobileCheckpointError.version }
        guard checkpoint.initialFingerprint == levelFingerprint else { throw MobileSessionError.changedLevel }
        let restored = try replay(inputs: checkpoint.inputs, through: checkpoint.tick)
        runtime = restored
        explosionTimeline.reset()
        inputs = checkpoint.inputs
        didNotifyCompletion = false
        rewindCount = checkpoint.rewindCount ?? 0
        usedRewind = checkpoint.usedRewind ?? false
    }

    @discardableResult
    public func rewind(seconds: Double) -> Bool {
        guard seconds.isFinite, seconds >= 0 else { return false }
        let distance = Int(min(Double(runtime.tick), (seconds * ticksPerSecond).rounded()))
        guard distance > 0 else { return false }
        return move(to: runtime.tick - distance)
    }

    @discardableResult
    public func stepBackward() -> Bool { move(to: runtime.tick - 1) }

    @discardableResult
    public func stepForward() -> Bool {
        guard !runtime.isComplete else { return false }
        tick()
        return true
    }

    public func resumeFromCurrentTick() {}

    private func move(to tick: Int) -> Bool {
        guard tick >= 0, tick < runtime.tick else { return false }
        do {
            let retainedInputs = inputs.filter { $0.tick <= tick }
            let restored = try replay(inputs: retainedInputs, through: tick)
            runtime = restored
            inputs = retainedInputs
            explosionTimeline.reset()
            didNotifyCompletion = false
            usedRewind = true
            rewindCount += 1
            return true
        } catch {
            return false
        }
    }

    private func replay(inputs: [Input], through tick: Int) throws -> Lemmings3Runtime {
        var restored = initial
        var inputIndex = 0
        while restored.tick <= tick {
            while inputIndex < inputs.count, inputs[inputIndex].tick == restored.tick {
                let input = inputs[inputIndex]
                if input.action == "abort" {
                    restored.abort()
                } else if let action = Lemmings3Runtime.Action(rawValue: input.action),
                          let target = input.target,
                          restored.assign(action, to: target) {
                    // The input is now part of the reconstructed timeline.
                } else {
                    throw MobileSessionError.invalidCheckpoint
                }
                inputIndex += 1
            }
            if restored.tick == tick { break }
            guard !restored.isComplete else { throw MobileSessionError.invalidCheckpoint }
            restored.step()
        }
        guard restored.tick == tick, inputIndex == inputs.count, !restored.isComplete else {
            throw MobileSessionError.invalidCheckpoint
        }
        return restored
    }

    public func releaseTransientResources() {}
}

public typealias NeoLemmixMobileRenderer = (
    _ simulation: NeoLemmixSimulation,
    _ highlight: MobileTargetSelection?
) throws -> MobilePixelFrame

/**
 * Adapts the supported NeoLemmix simulation to the shared mobile session contract.
 */
public final class NeoLemmixMobileSession: MobileGameSession {
    private struct Checkpoint: Codable, Sendable {
        var version = 1
        let levelFingerprint: String
        let simulation: NeoLemmixSimulation
        let simulationBeforeNuke: NeoLemmixSimulation?
        let requestedSpawnInterval: Int?
    }

    public let engineIdentifier = "neolemmix"
    public let engineFingerprint: String
    public let levelIdentifier: String
    public let levelIndex: Int
    public let levelFingerprint: String
    public let levelSize: MobileSize
    public let ticksPerSecond = Double(NeoLemmixRules.ticksPerSecond)

    private let initial: NeoLemmixSimulation
    private let controls: [NeoLemmixSkill]
    private let renderer: NeoLemmixMobileRenderer?
    private let onCompletion: ((NeoLemmixSimulation) -> Void)?
    private var simulation: NeoLemmixSimulation
    private var simulationBeforeNuke: NeoLemmixSimulation?
    private var requestedSpawnInterval: Int?
    private var didNotifyCompletion = false

    public init(simulation: NeoLemmixSimulation, controls: [NeoLemmixSkill],
                engineFingerprint: String, levelIdentifier: String, levelIndex: Int,
                levelFingerprint: String, renderer: NeoLemmixMobileRenderer? = nil,
                onCompletion: ((NeoLemmixSimulation) -> Void)? = nil) {
        initial = simulation
        self.simulation = simulation
        self.controls = controls
        self.engineFingerprint = engineFingerprint
        self.levelIdentifier = levelIdentifier
        self.levelIndex = levelIndex
        self.levelFingerprint = levelFingerprint
        self.renderer = renderer
        self.onCompletion = onCompletion
        levelSize = MobileSize(width: Double(simulation.terrain.width), height: Double(simulation.terrain.height))
    }

    public var snapshot: MobileGameSnapshot {
        let state = simulation.snapshot()
        let skillStates = controls.map { skill -> MobileSkillState in
            switch state.skills[skill] ?? .finite(0) {
            case let .finite(count): MobileSkillState(name: skill.rawValue.capitalized, count: count)
            case .infinite: MobileSkillState(name: skill.rawValue.capitalized, count: 0, isUnlimited: true)
            }
        }
        return MobileGameSnapshot(
            tick: state.tickCount,
            released: state.releasedCount,
            total: simulation.configuration.totalLemmings,
            saved: state.savedCount,
            required: simulation.configuration.requiredToSave,
            remainingSeconds: state.remainingTimeTicks.map { max(0, $0 / NeoLemmixRules.ticksPerSecond) },
            releaseRate: max(1, min(99, (53 - state.spawnInterval) * 2)),
            isComplete: state.isComplete,
            didWin: state.didWin,
            isEndingRun: state.isNuking || simulationBeforeNuke != nil,
            skills: skillStates
        )
    }

    public func tick() {
        _ = simulation.tick()
        requestedSpawnInterval = simulation.snapshot().spawnInterval
        if simulation.isComplete, !didNotifyCompletion {
            didNotifyCompletion = true
            onCompletion?(simulation)
        }
    }

    public func targetCandidates(for control: Int) -> [MobileTargetCandidate] {
        guard controls.indices.contains(control) else { return [] }
        let skill = controls[control]
        return simulation.lemmings.filter(\.canReceiveSkills).map { lemming in
            var probe = simulation
            let accepted = probe.assign(skill: skill, to: lemming.id).wasAssigned
            return MobileTargetCandidate(
                id: lemming.id,
                point: MobilePoint(x: Double(lemming.position.x), y: Double(lemming.position.y - 5)),
                direction: lemming.direction == .left ? -1 : 1,
                assignment: accepted ? .eligible : .unavailable,
                isBuilding: lemming.action == .building || lemming.action == .platforming,
                hasTool: lemming.traits.contains(.climber) || lemming.traits.contains(.floater),
                pointerBounds: MobileRect(x: -8, y: -10, width: 16, height: 20)
            )
        }
    }

    @discardableResult
    public func assign(control: Int, to target: Int) -> Bool {
        guard controls.indices.contains(control) else { return false }
        return simulation.assign(skill: controls[control], to: target).wasAssigned
    }

    @discardableResult
    public func adjustReleaseRate(by delta: Int) -> Bool {
        guard delta != 0, !simulation.isComplete, !simulation.configuration.spawnIntervalLocked else { return false }
        let current = requestedSpawnInterval ?? simulation.snapshot().spawnInterval
        let next = min(simulation.configuration.spawnInterval,
                       max(NeoLemmixRules.minimumSpawnInterval, current - delta))
        guard next != current else { return false }
        requestedSpawnInterval = next
        simulation.enqueue(.setSpawnInterval(next))
        return true
    }

    @discardableResult
    public func beginEndRun() -> Bool {
        guard !simulation.isComplete, !simulation.isNuking, simulationBeforeNuke == nil else { return false }
        simulationBeforeNuke = simulation
        simulation.enqueue(.nuke)
        return true
    }

    @discardableResult
    public func undoEndRun() -> Bool {
        guard let simulationBeforeNuke, !simulation.isComplete else { return false }
        simulation = simulationBeforeNuke
        self.simulationBeforeNuke = nil
        didNotifyCompletion = false
        return true
    }

    public func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        guard let renderer else { throw MobileSessionError.frameUnavailable }
        return try renderer(simulation, highlight)
    }

    public func checkpointPayload() throws -> Data {
        try prepareCheckpointPayload().encode()
    }

    public func prepareCheckpointPayload() throws -> MobileCheckpointPayload {
        guard !simulation.isComplete else { throw MobileSessionError.invalidCheckpoint }
        return MobileCheckpointPayload(Checkpoint(levelFingerprint: levelFingerprint, simulation: simulation,
                                                  simulationBeforeNuke: simulationBeforeNuke,
                                                  requestedSpawnInterval: requestedSpawnInterval))
    }

    public func restoreCheckpointPayload(_ data: Data) throws {
        let checkpoint = try JSONDecoder().decode(Checkpoint.self, from: data)
        guard checkpoint.version == 1 else { throw MobileCheckpointError.version }
        guard checkpoint.levelFingerprint == levelFingerprint else { throw MobileSessionError.changedLevel }
        guard checkpoint.simulation.configuration == initial.configuration,
              !checkpoint.simulation.isComplete else { throw MobileSessionError.invalidCheckpoint }
        if let beforeNuke = checkpoint.simulationBeforeNuke,
           beforeNuke.configuration != initial.configuration || beforeNuke.isComplete {
            throw MobileSessionError.invalidCheckpoint
        }
        simulation = checkpoint.simulation
        simulationBeforeNuke = checkpoint.simulationBeforeNuke
        requestedSpawnInterval = checkpoint.requestedSpawnInterval ?? checkpoint.simulation.snapshot().spawnInterval
        didNotifyCompletion = false
    }

    public func releaseTransientResources() {}
}
