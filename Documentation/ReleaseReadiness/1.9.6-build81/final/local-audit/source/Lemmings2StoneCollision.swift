/// PROCESS B08D–B2F1 sweeps four points from the thrown stone's origin.
public enum Lemmings2StoneCollision {
    public static func sweep(x: Int, y: Int, toX: Int, toY: Int,
                             solid: (Int, Int) -> Bool) -> Lemmings2AirCollision.Result {
        let dx = abs(toX-x), dy = abs(toY-y)
        let sx = toX < x ? -1 : 1, sy = toY < y ? -1 : 1
        var x = x, y = y
        let horizontal = dx > dy
        let major = horizontal ? dx : dy
        var error = major/2
        for _ in 0..<major {
            if horizontal {
                x += sx; error -= dy
                if error < 0 { y += sy; error += dx }
            } else {
                y += sy; error -= dx
                if error < 0 { x += sx; error += dy }
            }
            for (probe, offset) in [(2,0),(4,2),(2,4),(0,2)].enumerated() {
                guard solid(x+offset.0,y+offset.1) else { continue }
                var px = x, py = y
                // The first three probes share B1C5 even on the vertical path.
                if horizontal || probe < 3 {
                    px -= sx
                    if error-dx+dy >= 0 { py -= sy }
                } else {
                    py -= sy
                    if error-dy+dx >= 0 { px -= sx }
                }
                return .init(x:x,y:y,previousX:px,previousY:py,contact:.body)
            }
        }
        return .init(x:x,y:y,previousX:x,previousY:y,contact:.clear)
    }
}
