import Foundation

/// One builder-style warning at each remaining second from ten through one.
public struct LastSecondsWarning: Sendable {
    private var previous: Int?
    public init() {}
    public mutating func reset(seconds: Int?) { previous = seconds }
    public mutating func update(seconds: Int?) -> Bool {
        defer { previous = seconds }
        guard let seconds, let previous, seconds < previous else { return false }
        return (1...10).contains(seconds)
    }
}
