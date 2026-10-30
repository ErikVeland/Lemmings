import Foundation
import NxlvKit

/// Touch timing shared by the native controls and windowless checks.
public struct MobileHUDPress: Sendable {
    public enum Kind: Sendable { case tap, step, rate, releaseRate, speed, rewind, pause, nuke }
    public enum Effect: Equatable, Sendable {
        case activate, step(Int), hold, doubleTap, pedal(Bool, allowTap: Bool)
    }
    private let kind: Kind
    private var startedAt: TimeInterval?
    private var nextRepeat: TimeInterval = 0
    private var held = false
    private var lastTapEndedAt: TimeInterval?
    private var isDoubleTap = false
    private var activatedOnBegin = false
    public init(_ kind: Kind) { self.kind = kind }

    public mutating func begin(at now: TimeInterval, activateOnBegin: Bool = false) -> [Effect] {
        guard startedAt == nil else { return [] }
        startedAt = now; held = false; nextRepeat = now + 0.35
        activatedOnBegin = kind == .pause && activateOnBegin
        isDoubleTap = kind == .releaseRate && lastTapEndedAt.map { now >= $0 && now - $0 <= 0.3 } == true
        lastTapEndedAt = nil
        if isDoubleTap { return [.doubleTap] }
        switch kind {
        case .step: return [.step(1)]
        case .rate, .releaseRate: return [.activate]
        case .speed, .rewind: return [.pedal(true, allowTap: false)]
        case .pause: return activatedOnBegin ? [.activate] : []
        default: return []
        }
    }
    public mutating func update(at now: TimeInterval) -> [Effect] {
        guard let start = startedAt else { return [] }
        if kind == .step, now >= nextRepeat {
            held = true
            let elapsed = now - start
            nextRepeat = now + (elapsed >= 2 ? 0.08 : elapsed >= 1 ? 0.12 : 0.16)
            return [.step(elapsed >= 2 ? 4 : elapsed >= 1 ? 2 : 1)]
        }
        if kind == .rewind, now >= nextRepeat {
            held = true
            nextRepeat = now + 0.08
            return [.activate]
        }
        if (kind == .rate || kind == .releaseRate), !isDoubleTap, now >= nextRepeat {
            held = true
            nextRepeat = now + 0.08
            return [.activate]
        }
        if kind == .nuke, !held, now - start >= 0.6 {
            held = true
            return [.hold]
        }
        return []
    }
    public mutating func end(at now: TimeInterval, cancelled: Bool = false) -> [Effect] {
        guard let start = startedAt else {
            if cancelled { lastTapEndedAt = nil }
            return []
        }
        let pending = cancelled || kind == .step || kind == .rewind ? [] : update(at: now)
        startedAt = nil
        if kind == .releaseRate, !cancelled, !held, !isDoubleTap, now - start < 0.3 { lastTapEndedAt = now }
        else { lastTapEndedAt = nil }
        switch kind {
        case .speed:
            return pending + [.pedal(false, allowTap: !cancelled && now - start >= GameplaySpeed.holdDelay)]
                + (!cancelled && now - start < GameplaySpeed.holdDelay ? [.activate] : [])
        case .rewind: return pending + [.pedal(false, allowTap: false)]
        case .step, .rate, .releaseRate: return pending
        default: return pending + (!cancelled && !held && !activatedOnBegin ? [.activate] : [])
        }
    }

    /// Rewind covers more game time as the player keeps the control down.
    public static func rewindSeconds(heldFor duration: TimeInterval) -> Double {
        duration >= 2 ? 1.6 : duration >= 1 ? 0.8 : 0.4
    }
}

/// Accumulates rewind distance while an exact seek is still being reconstructed.
/// Only one seek runs at a time; further input becomes one subsequent destination.
public struct MobileRewindQueue: Sendable {
    public struct Request: Equatable, Sendable {
        public let tick: Int
        public let backwardSteps: Int
    }

    public private(set) var targetTick: Int?
    private var pendingSteps = 0

    public init() {}

    @discardableResult public mutating func append(ticks: Int, from currentTick: Int,
                                                  earliestTick: Int, backwardSteps: Int = 1) -> Bool {
        let origin = targetTick ?? currentTick
        let distance = min(max(0, ticks), max(0, origin - earliestTick))
        guard distance > 0 else { return false }
        targetTick = origin - distance
        pendingSteps += min(distance, max(1, backwardSteps))
        return true
    }

    public mutating func takePending() -> Request? {
        guard let targetTick, pendingSteps > 0 else { return nil }
        let request = Request(tick: targetTick, backwardSteps: pendingSteps)
        pendingSteps = 0
        return request
    }

    /// Keep the accumulated destination until every accepted input has committed.
    public mutating func didCommit() {
        if pendingSteps == 0 { targetTick = nil }
    }

    public mutating func cancel() { self = .init() }
}

/// Rapid rewind presses cover progressively more game time, even after a seek commits.
public struct MobileRewindPressAcceleration: Sendable {
    private var lastPress: Double?
    private var burstIndex = 0

    public init() {}

    public mutating func ticks(at time: Double, ticksPerSecond: Double, preciseFirstTap: Bool = false) -> Int {
        if let lastPress, time >= lastPress, time - lastPress <= 0.65 {
            burstIndex = min(4, burstIndex + 1)
        } else {
            burstIndex = 0
        }
        lastPress = time
        if preciseFirstTap && burstIndex == 0 { return 1 }
        let seconds = preciseFirstTap ? 0.4 * Double(1 << (burstIndex - 1)) : min(16, 2 * Double(1 << burstIndex))
        return max(1, Int((seconds * ticksPerSecond).rounded()))
    }

    public mutating func reset() { self = .init() }
}
