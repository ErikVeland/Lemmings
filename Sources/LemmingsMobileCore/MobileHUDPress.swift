import Foundation
import NxlvKit

/// Touch timing shared by the native controls and windowless checks.
public struct MobileHUDPress: Sendable {
    public enum Kind: Sendable { case tap, rate, releaseRate, speed, rewind, pause, nuke }
    public enum Effect: Equatable, Sendable {
        case activate, hold, doubleTap, pedal(Bool, allowTap: Bool)
    }
    private let kind: Kind
    private var startedAt: TimeInterval?
    private var nextRepeat: TimeInterval = 0
    private var held = false
    private var lastTapEndedAt: TimeInterval?
    private var isDoubleTap = false
    public init(_ kind: Kind) { self.kind = kind }

    public mutating func begin(at now: TimeInterval) -> [Effect] {
        guard startedAt == nil else { return [] }
        startedAt = now; held = false; nextRepeat = now + 0.35
        isDoubleTap = kind == .releaseRate && lastTapEndedAt.map { now >= $0 && now - $0 <= 0.3 } == true
        lastTapEndedAt = nil
        if isDoubleTap { return [.doubleTap] }
        switch kind {
        case .rate, .releaseRate: return [.activate]
        case .speed, .rewind: return [.pedal(true, allowTap: false)]
        default: return []
        }
    }
    public mutating func update(at now: TimeInterval) -> [Effect] {
        guard let start = startedAt else { return [] }
        if (kind == .rate || kind == .releaseRate), !isDoubleTap, now >= nextRepeat {
            held = true
            nextRepeat = now + 0.08
            return [.activate]
        }
        if (kind == .pause || kind == .nuke), !held, now - start >= 0.6 {
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
        let pending = cancelled ? [] : update(at: now)
        startedAt = nil
        if kind == .releaseRate, !cancelled, !held, !isDoubleTap, now - start < 0.3 { lastTapEndedAt = now }
        else { lastTapEndedAt = nil }
        switch kind {
        case .speed:
            return pending + [.pedal(false, allowTap: !cancelled && now - start >= GameplaySpeed.holdDelay)]
                + (!cancelled && now - start < GameplaySpeed.holdDelay ? [.activate] : [])
        case .rewind: return pending + [.pedal(false, allowTap: false)]
        case .rate, .releaseRate: return pending
        default: return pending + (!cancelled && !held ? [.activate] : [])
        }
    }
}
