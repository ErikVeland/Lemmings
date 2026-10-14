/// Opening, holding and closing phases from L2.RKO 3f37–3fd9.
public struct Lemmings2TimedTrap: Sendable {
    public private(set) var mode = 1
    public private(set) var frame = 0
    private var delay = 0
    private var direction = 1
    public init() {}
    /// Returns true while the trap can kill; a closing trap reopens on contact.
    public mutating func touch() -> Bool {
        switch mode {
        case 1: mode = 2
        case 3: return true
        case 4: mode = 5
        default: break
        }
        return false
    }
    public mutating func step(frameCount: Int, minimum: Int, maximum: Int) {
        switch mode {
        case 2:
            direction = 1; frame += 1
            if frame >= frameCount { frame = 0; mode = 1 }
            else if frame >= minimum { mode = 3; delay = 20 }
        case 3:
            frame += direction; delay -= 1
            if delay == 0 { mode = 4 }
            else if frame < minimum || frame > maximum { direction = -direction; frame += direction }
        case 4:
            direction = 1; frame += 1
            if frame >= frameCount { frame = 0; mode = 1 }
        case 5:
            direction = -1; frame -= 1
            if frame < minimum { frame = max(0,frame); mode = 2 }
            else if frame <= maximum { mode = 3; delay = 20 }
        default: break
        }
    }
}
