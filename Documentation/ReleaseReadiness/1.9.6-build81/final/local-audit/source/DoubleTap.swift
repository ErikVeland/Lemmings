import Foundation

/// Recognises a second press of the same key soon after the first.
public struct DoubleTap: Sendable {
    private var last: (key: String, time: TimeInterval)?

    public init() {}

    public mutating func reset() { last = nil }

    /// Returns true when this press completes a double tap. Held-key repeats
    /// never count, and they clear the first press.
    public mutating func press(_ key: String, at time: TimeInterval, interval: TimeInterval,
                               isRepeat: Bool) -> Bool {
        guard !isRepeat else { last = nil; return false }
        if let last, last.key == key, time >= last.time, time - last.time <= interval {
            self.last = nil
            return true
        }
        last = (key, time)
        return false
    }
}
