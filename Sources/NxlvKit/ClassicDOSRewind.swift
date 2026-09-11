import Foundation

/// Rewind and frame stepping for the DOS engine.
///
/// Storing a copy of the simulation every tick is not practical, because each
/// one carries two full terrain masks. This keeps a keyframe every few seconds
/// and a log of every command, then reconstructs any exact tick by restoring
/// the nearest earlier keyframe and simulating forward. The result is exact,
/// not approximate, because the engine is deterministic.
///
/// Each keyframe records how many commands had been applied when it was taken.
/// Replay resumes from that index, which removes any ambiguity about commands
/// issued on the same tick the keyframe was captured.
public struct ClassicDOSRewind: Sendable {
    /// A command as it was actually applied, with the tick it landed on.
    public struct LoggedCommand: Codable, Equatable, Sendable {
        public let tick: Int
        public let action: ClassicDOSReplayAction

        public init(tick: Int, action: ClassicDOSReplayAction) {
            self.tick = tick
            self.action = action
        }
    }

    private struct Keyframe: Sendable {
        let tick: Int
        let state: ClassicDOSSimulation
        /// Commands already applied when this was captured.
        let commandCount: Int
    }

    public private(set) var simulation: ClassicDOSSimulation
    public private(set) var commands: [LoggedCommand] = []

    private var keyframes: [Keyframe] = []
    private var appliedCommandCount = 0
    private let interval: Int
    private let maximumKeyframes: Int

    /// - Parameters:
    ///   - keyframeInterval: ticks between keyframes. Larger values use less
    ///     memory and take longer to seek.
    ///   - maximumKeyframes: how far back the history reaches.
    public init(
        simulation: ClassicDOSSimulation,
        keyframeInterval: Int = ClassicDOSRules.ticksPerSecond * 3,
        maximumKeyframes: Int = 120
    ) {
        self.simulation = simulation
        self.interval = max(1, keyframeInterval)
        self.maximumKeyframes = max(2, maximumKeyframes)
        keyframes = [Keyframe(tick: simulation.tickCount, state: simulation, commandCount: 0)]
    }

    // MARK: - Running forward

    @discardableResult
    public mutating func tick() -> [ClassicDOSEvent] {
        let events = simulation.tick()
        applyPendingCommands()
        captureIfNeeded()
        return events
    }

    @discardableResult
    public mutating func assign(_ skill: ClassicSkill, to lemmingID: Int)
        -> ClassicDOSAssignmentResult
    {
        let result = simulation.assign(skill, to: lemmingID)
        if result == .assigned {
            discardFutureCommands()
            commands.append(LoggedCommand(
                tick: simulation.tickCount,
                action: .assign(lemmingID: lemmingID, skill: skill)))
            appliedCommandCount = commands.count
        }
        return result
    }

    public mutating func setReleaseRate(_ value: Int) {
        let before = simulation.releaseRate
        simulation.setReleaseRate(value)
        guard simulation.releaseRate != before else { return }
        discardFutureCommands()
        commands.append(LoggedCommand(
            tick: simulation.tickCount, action: .releaseRate(simulation.releaseRate)))
        appliedCommandCount = commands.count
    }

    public mutating func beginNuke() {
        guard !simulation.isNuking else { return }
        simulation.beginNuke()
        discardFutureCommands()
        commands.append(LoggedCommand(tick: simulation.tickCount, action: .nuke))
        appliedCommandCount = commands.count
    }

    private mutating func captureIfNeeded() {
        guard simulation.tickCount % interval == 0 else { return }
        guard keyframes.last?.tick != simulation.tickCount else { return }
        keyframes.append(Keyframe(
            tick: simulation.tickCount, state: simulation, commandCount: appliedCommandCount))
        if keyframes.count > maximumKeyframes { keyframes.removeFirst() }
    }

    // MARK: - Going back

    /// The earliest tick that history still reaches.
    public var earliestTick: Int { keyframes.first?.tick ?? simulation.tickCount }
    public var currentTick: Int { simulation.tickCount }
    public var canRewind: Bool { simulation.tickCount > earliestTick }

    /// Moves to an exact tick, forward or back.
    ///
    /// Returns false when the target is outside the history that is still held.
    @discardableResult
    public mutating func seek(toTick target: Int) -> Bool {
        guard target >= earliestTick else { return false }
        if target == simulation.tickCount { return true }

        // Seeking forward from here is cheaper than restarting from a keyframe.
        if target > simulation.tickCount {
            advance(to: target)
            return simulation.tickCount == target
        }

        guard let keyframe = keyframes.last(where: { $0.tick <= target }) else { return false }
        simulation = keyframe.state
        appliedCommandCount = keyframe.commandCount
        applyPendingCommands()
        // Drop keyframes that are now in the future, so history stays ordered.
        keyframes.removeAll { $0.tick > target }
        advance(to: target)
        return simulation.tickCount == target
    }

    /// Steps back one tick.
    @discardableResult
    public mutating func stepBackward() -> Bool {
        seek(toTick: simulation.tickCount - 1)
    }

    /// Steps forward one tick.
    @discardableResult
    public mutating func stepForward() -> Bool {
        guard !simulation.isComplete else { return false }
        tick()
        return true
    }

    /// Rewinds by a number of seconds, clamped to what history holds.
    @discardableResult
    public mutating func rewind(seconds: Double) -> Bool {
        guard seconds.isFinite, seconds >= 0 else { return false }
        let available = simulation.tickCount - earliestTick
        let requested = (Double(ClassicDOSRules.ticksPerSecond) * seconds).rounded()
        let ticks = requested >= Double(available) ? available : Int(requested)
        return seek(toTick: simulation.tickCount - ticks)
    }

    /// A successful new command replaces the abandoned future branch.
    private mutating func discardFutureCommands() {
        commands.removeSubrange(appliedCommandCount...)
        keyframes.removeAll { $0.tick > simulation.tickCount }
    }

    private mutating func applyPendingCommands() {
        while appliedCommandCount < commands.count,
              commands[appliedCommandCount].tick == simulation.tickCount {
            apply(commands[appliedCommandCount].action)
            appliedCommandCount += 1
        }
    }

    /// Simulates forward with the same command timing as normal playback.
    private mutating func advance(to target: Int) {
        while simulation.tickCount < target, !simulation.isComplete {
            tick()
        }
    }

    private mutating func apply(_ action: ClassicDOSReplayAction) {
        switch action {
        case let .assign(lemmingID, skill):
            _ = simulation.assign(skill, to: lemmingID)
        case let .releaseRate(value):
            simulation.setReleaseRate(value)
        case .nuke:
            simulation.beginNuke()
        }
    }

    // MARK: - Reporting

    /// Rough memory held by the history, for tuning the interval.
    public var estimatedMemoryBytes: Int {
        let terrain = simulation.terrain.width * simulation.terrain.height * 2
        return keyframes.count * (terrain + 4_096)
    }

    public var keyframeCount: Int { keyframes.count }

    /// Turns the session into a replay, so a rewound run still records one.
    public func replay(rank: String, number: Int, title: String, initialStateHash: String)
        -> ClassicDOSReplay
    {
        ClassicDOSReplay(
            rank: rank,
            number: number,
            title: title,
            initialStateHash: initialStateHash,
            events: commands.prefix(appliedCommandCount).map { ClassicDOSReplayEvent(tick: $0.tick, action: $0.action, afterTick: true) }
        )
    }
}
