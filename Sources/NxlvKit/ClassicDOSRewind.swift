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
        captureIfNeeded()
        return events
    }

    @discardableResult
    public mutating func assign(_ skill: ClassicSkill, to lemmingID: Int)
        -> ClassicDOSAssignmentResult
    {
        let result = simulation.assign(skill, to: lemmingID)
        if result == .assigned {
            commands.append(LoggedCommand(
                tick: simulation.tickCount,
                action: .assign(lemmingID: lemmingID, skill: skill)))
        }
        return result
    }

    public mutating func setReleaseRate(_ value: Int) {
        let before = simulation.releaseRate
        simulation.setReleaseRate(value)
        guard simulation.releaseRate != before else { return }
        commands.append(LoggedCommand(
            tick: simulation.tickCount, action: .releaseRate(simulation.releaseRate)))
    }

    public mutating func beginNuke() {
        guard !simulation.isNuking else { return }
        simulation.beginNuke()
        commands.append(LoggedCommand(tick: simulation.tickCount, action: .nuke))
    }

    private mutating func captureIfNeeded() {
        guard simulation.tickCount % interval == 0 else { return }
        guard keyframes.last?.tick != simulation.tickCount else { return }
        keyframes.append(Keyframe(
            tick: simulation.tickCount, state: simulation, commandCount: commands.count))
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
            advance(to: target, from: commandIndexAfter(tick: simulation.tickCount))
            return simulation.tickCount == target
        }

        guard let keyframe = keyframes.last(where: { $0.tick <= target }) else { return false }
        simulation = keyframe.state
        // Drop keyframes that are now in the future, so history stays ordered.
        keyframes.removeAll { $0.tick > target }
        advance(to: target, from: keyframe.commandCount)
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
        let ticks = Int((Double(ClassicDOSRules.ticksPerSecond) * seconds).rounded())
        return seek(toTick: max(earliestTick, simulation.tickCount - ticks))
    }

    private func commandIndexAfter(tick: Int) -> Int {
        commands.firstIndex { $0.tick > tick } ?? commands.count
    }

    /// Simulates forward to a tick, applying logged commands as they come up.
    private mutating func advance(to target: Int, from commandIndex: Int) {
        var index = commandIndex
        while simulation.tickCount < target {
            _ = simulation.tick()
            while index < commands.count, commands[index].tick == simulation.tickCount {
                apply(commands[index].action)
                index += 1
            }
            captureIfNeeded()
            // A finished level cannot advance further.
            if simulation.isComplete { break }
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
            events: commands.map { ClassicDOSReplayEvent(tick: $0.tick, action: $0.action) }
        )
    }
}
