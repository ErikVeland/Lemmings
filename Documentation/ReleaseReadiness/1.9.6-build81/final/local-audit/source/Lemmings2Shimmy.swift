/// Ceiling traversal and edge transfers from PROCESS 724d–73ba and 8b19–8b4e.
public enum Lemmings2Shimmy {
    public enum Contact: Equatable { case shimming, walking, hanging, sliding, climbingTransfer }

    public static func step(x: inout Int, y: inout Int, direction: inout Int,
                            phase: inout Int, rise: inout Int, slider: Bool, climber: Bool,
                            solid: (Int, Int) -> Bool) -> Contact {
        func reset() { if phase < 15 { phase = 4 }; rise = -1 }
        func obstructed(at nextX: Int) -> Contact {
            if solid(x,y) { return .walking }
            if slider { x = nextX-direction; direction = -direction; return .sliding }
            x = nextX-2*direction
            return .hanging
        }
        if [7,8,9,10,17,18,19,20].contains(phase) {
            let nextX = x+direction
            if (0...7).contains(where: { solid(nextX,y-$0) }) { return obstructed(at:nextX) }
            if phase == 10 || phase == 20 {
                if !solid(nextX,y-9) {
                    if let height = (10...12).first(where: { solid(nextX,y-$0) }) { rise = height-9 }
                    else {
                        x = nextX-4*direction
                        if climber {
                            for offset in 0...4 where !solid(x+offset*direction,y-9) {
                                x += (offset-1)*direction
                                return .climbingTransfer
                            }
                            y -= 1
                        } else { direction = -direction }
                        return .hanging
                    }
                } else if !solid(nextX,y-8) { rise = 0 }
                else if !solid(nextX,y-7) { y += 2; reset() }
                else { return obstructed(at:nextX) }
            } else if (7...9).allSatisfy({ solid(nextX,y-$0) }) { return obstructed(at:nextX) }
            x = nextX
        } else if phase == 11 || phase == 21 {
            rise -= 1
            if rise < 0 { y += 1; reset() }
        } else if [12,13,22,23].contains(phase) {
            rise -= 1
            if rise >= 0 { y -= 1 } else { reset() }
        } else if phase == 14 || phase == 24 { reset() }
        phase += 1
        if phase > 24 { phase = 5 }
        return .shimming
    }
}
