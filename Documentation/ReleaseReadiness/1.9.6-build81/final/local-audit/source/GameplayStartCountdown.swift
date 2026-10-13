import Foundation

/// Only active, visible gameplay advances a fresh start.
public struct GameplayStartCountdown: Equatable, Sendable {
    public private(set) var remaining: Double?
    public var isActive: Bool { remaining != nil }
    public var number: Int? { remaining.map { max(1, Int(ceil($0))) } }
    public init() {}
    public mutating func arm() { remaining = 3 }
    public mutating func cancel() { remaining = nil }
    @discardableResult public mutating func advance(seconds: Double, visible: Bool) -> Bool {
        guard visible, seconds.isFinite, let remaining else { return false }
        let next = remaining - max(0, seconds)
        if next <= 0 { cancel(); return true }
        self.remaining = next
        return false
    }
}
