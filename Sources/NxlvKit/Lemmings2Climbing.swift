/// Original wall and overhang probes from PROCESS 403e and 7056.
public enum Lemmings2Climbing {
    public enum Contact: Equatable { case climbing, hoisting, falling, hanging }

    public static func classic(x: inout Int, y: inout Int, direction: inout Int,
                               phase: Int, solid: (Int,Int) -> Bool) -> Contact {
        let frame = (phase+1)&7
        if frame > 3 {
            y -= 1
            if solid(x-direction,y-8) {
                direction = -direction; x += 2*direction
                return .falling
            }
        } else if !solid(x,y-7-frame) {
            y -= 6+frame
            return .hoisting
        }
        return .climbing
    }

    public static func rock(x: inout Int, y: inout Int, direction: Int,
                            phase: Int, pose: inout Int, previousSlope: inout Int,
                            solid: (Int,Int) -> Bool) -> Contact {
        let frame = (phase+1)&7
        guard pose == 2 ? [3,7].contains(frame) : frame%2 == 1 else { return .climbing }
        let probeY = y-9
        var slope = 0
        if solid(x,probeY) && !solid(x-direction,probeY) { slope = 0 }
        else if !solid(x,probeY) && !solid(x-direction,probeY) {
            if !solid(x+direction,probeY) { y -= 8; return .hoisting }
            slope = -1
        } else {
            x -= direction
            if !solid(x-direction,probeY) { slope = 1 }
            else {
                x -= direction
                if !solid(x-direction,probeY) { slope = 2 }
                else { y += 1; return .hanging }
            }
        }
        // The original adds only AL, preserving the high byte of the slope.
        let trend = Int(Int16(bitPattern:UInt16((slope & 0xff00) | ((slope+previousSlope)&255))))
        if trend > 2 { y += 1; return .hanging }
        if trend <= -1 { y -= 8; return .hoisting }
        previousSlope = slope; pose = trend; y -= 1
        return .climbing
    }
}
