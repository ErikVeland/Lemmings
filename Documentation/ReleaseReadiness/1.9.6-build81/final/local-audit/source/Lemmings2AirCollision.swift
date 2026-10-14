/// Pixel sweep used by the native L2 airborne routines (PROCESS 3a79–3ad8).
/// Vertical movement is checked before horizontal movement on each iteration.
public enum Lemmings2AirCollision {
    public enum Contact: Equatable, Sendable { case clear, body, head }
    public struct Result: Equatable, Sendable {
        public let x: Int
        public let y: Int
        public let previousX: Int
        public let previousY: Int
        public let contact: Contact
    }
    /// PROCESS 3949–3a24 resolves Jet Pack axes separately and reflects each hit axis.
    public static func bounce(x:inout Int,y:inout Int,toX:Int,toY:Int,
                              velocityX:inout Int,velocityY:inout Int,
                              solid:(Int,Int)->Bool) {
        let dx = x < toX ? 1 : -1
        while x != toX {
            let next = x+dx
            if solid(next,y) || solid(next,y-10) { velocityX = -velocityX; break }
            x = next
        }
        let dy = y < toY ? 1 : -1
        while y != toY {
            let next = y+dy
            if solid(x,next) || solid(x,next-10) { velocityY = -velocityY; break }
            y = next
        }
    }
    public static func sweep(x: Int, y: Int, toX: Int, toY: Int, height: Int = 9,
                             solid: (Int, Int) -> Bool) -> Result {
        var x = x, y = y, px = x, py = y
        while x != toX || y != toY {
            px = x; py = y
            if y != toY {
                y += y < toY ? 1 : -1
                if solid(x, y) { return .init(x: x, y: y, previousX: px, previousY: py, contact: .body) }
            }
            if x != toX {
                x += x < toX ? 1 : -1
                if solid(x, y) { return .init(x: x, y: y, previousX: px, previousY: py, contact: .body) }
            }
            if solid(x, y - height) { return .init(x: x, y: y, previousX: px, previousY: py, contact: .head) }
        }
        return .init(x: x, y: y, previousX: px, previousY: py, contact: .clear)
    }
}
