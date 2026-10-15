import Foundation

/// Separates editable planning from Ready, interruption and result screens.
public struct MobilePlayState: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case ready, running, planning, suspended, completed
    }

    public private(set) var phase: Phase = .ready
    public var isPaused: Bool { phase != .running }
    public var canEdit: Bool { phase == .running || phase == .planning }
    public var canStep: Bool { phase == .planning }

    public init() {}

    @discardableResult public mutating func pauseForPlanning() -> Bool {
        guard canEdit else { return false }
        phase = .planning
        return true
    }

    /// Only an explicit player action can pass a Ready or interruption boundary.
    @discardableResult public mutating func resume(isForeground: Bool, isInterrupted: Bool) -> Bool {
        guard isForeground, !isInterrupted, phase != .completed else { return false }
        phase = .running
        return true
    }

    public mutating func suspend() {
        guard phase != .completed, phase != .ready else { return }
        phase = .suspended
    }

    public mutating func complete() { phase = .completed }
}
