import Foundation
import NxlvKit

/// Touch timing shared by the native controls and windowless checks.
public struct MobileHUDPress: Sendable {
    public enum Kind: Sendable { case tap, rate, speed, rewind, pause, nuke }
    public enum Effect: Equatable, Sendable {
        case activate, hold, pedal(Bool, allowTap: Bool)
    }
    private let kind: Kind
    private var startedAt: TimeInterval?
    private var nextRepeat: TimeInterval = 0
    private var held = false
    public init(_ kind: Kind) { self.kind = kind }

    public mutating func begin(at now: TimeInterval) -> [Effect] {
        guard startedAt == nil else { return [] }
        startedAt = now; held = false; nextRepeat = now + 0.35
        switch kind {
        case .rate: return [.activate]
        case .speed, .rewind: return [.pedal(true, allowTap: false)]
        default: return []
        }
    }
    public mutating func update(at now: TimeInterval) -> [Effect] {
        guard let start = startedAt else { return [] }
        if kind == .rate, now >= nextRepeat {
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
        guard let start = startedAt else { return [] }
        let pending = cancelled ? [] : update(at: now)
        startedAt = nil
        switch kind {
        case .speed:
            return pending + [.pedal(false, allowTap: false)]
                + (!cancelled && now - start < GameplaySpeed.holdDelay ? [.activate] : [])
        case .rewind: return pending + [.pedal(false, allowTap: false)]
        case .rate: return pending
        default: return pending + (!cancelled && !held ? [.activate] : [])
        }
    }
}
