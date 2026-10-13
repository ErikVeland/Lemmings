import Foundation
import CoreGraphics

/// Retain the selected actor during a short, smooth release. Repeated empty
/// frames cannot restart the fade. The normal game frame advances it.
public struct SelectionFade<Value> {
    public static var duration: TimeInterval { 0.35 }
    private var value: Value?
    private var releasedAt: TimeInterval?
    public init() {}
    public mutating func reset() { value = nil; releasedAt = nil }
    public mutating func set(_ selected: Value?, at now: TimeInterval) {
        if let selected { value = selected; releasedAt = nil }
        else if value != nil, releasedAt == nil { releasedAt = now }
    }
    public func sample(at now: TimeInterval) -> (value: Value, opacity: CGFloat)? {
        guard let value else { return nil }
        guard let releasedAt else { return (value, 1) }
        let t = min(1, max(0, (now - releasedAt) / Self.duration))
        guard t < 1 else { return nil }
        return (value, CGFloat(1 - t * t * (3 - 2 * t)))
    }
    public func isFading(at now: TimeInterval) -> Bool { releasedAt != nil && sample(at: now) != nil }
}
