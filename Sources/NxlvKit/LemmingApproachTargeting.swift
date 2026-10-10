/// Direction cues for selecting an approaching lemming in a mixed crowd.
public enum LemmingApproachTargeting {
    /// A nearby wall supplies a direction even when the pointer is behind it.
    /// Probe the upper body so floors and short steps do not become walls.
    public static func wallDirection(x: Int, footY: Int, isSolid: (Int, Int) -> Bool) -> Int? {
        func wall(on side: Int) -> Bool {
            (1...8).contains { offset in
                isSolid(x + offset * side, footY - 5) && isSolid(x + offset * side, footY - 9)
            }
        }
        let left = wall(on: -1), right = wall(on: 1)
        guard left != right else { return nil }
        return right ? 1 : -1
    }

    public static func isApproaching(x: Int, direction: Int, clickX: Double, wallDirection: Int?) -> Bool {
        if let wallDirection { return direction == wallDirection }
        // A click exactly over a lemming gives no evidence of approach.
        return (clickX - Double(x)) * Double(direction) > 0
    }
}
