/// Turns horizontal touchpad travel into timeline steps, like a jog wheel.
/// A slide to the left steps back. A slide to the right steps forward.
public struct TouchpadJog: Sendable {
    /// The pad is 2.0 wide, so one swipe across it moves 16 ticks.
    public static let stepWidth = 0.125
    /// A larger jump between two samples is a new touch, not a slide.
    /// It also limits one frame of a fast swipe to four ticks.
    static let jumpLimit = 0.6
    private var anchor: Double?
    public init() {}
    public mutating func reset() { anchor = nil }

    /// Pass the finger position, or nil when no finger is down or the pad is
    /// clicked. GameController reports a lifted finger as (0, 0).
    /// Returns the signed number of ticks to step.
    public mutating func update(x: Double?, y: Double? = nil) -> Int {
        guard let x, !(x == 0 && (y ?? 0) == 0) else { anchor = nil; return 0 }
        guard let start = anchor, abs(x - start) <= Self.jumpLimit else { anchor = x; return 0 }
        let travel = x - start
        let steps = Int(travel / Self.stepWidth)
        guard steps != 0 else { return 0 }
        anchor = start + Double(steps) * Self.stepWidth
        return steps
    }
}
