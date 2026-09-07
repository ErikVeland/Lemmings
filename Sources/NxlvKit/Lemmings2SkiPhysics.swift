/// Ground contact, slope history and fixed-point acceleration from PROCESS 65f4.
public struct Lemmings2SkiPhysics: Equatable, Sendable {
    public enum Mode: Sendable { case ski, roller }
    private let mode: Mode
    public enum Contact: Sendable { case riding, walking, stunned, airborne, exiting }
    public private(set) var velocityX: Int
    public private(set) var velocityY = 0
    private var slopes = [0,0,0,0]
    public init(direction: Int, landingVelocity: Int? = nil, mode: Mode = .ski) {
        self.mode = mode
        velocityX = max(-80,min(80,landingVelocity ?? (mode == .ski ? 32 : 64)*direction))
    }
    public mutating func step(x: inout Int,y: inout Int,direction: inout Int,
                              solid:(Int,Int)->Bool, exit:(Int,Int)->Bool = {_,_ in false}) -> Contact {
        velocityX = max(-80,min(80,velocityX)); velocityY = max(-80,min(80,velocityY))
        let speed = abs(velocityX)/16, vertical = velocityY/16
        guard speed >= 2 else { return .walking }
        let startY = y-1
        var cx = x, cy = startY
        for _ in 0..<speed {
            let nx = cx+direction
            var nextY = cy, delta = 0
            if solid(nx,cy) {
                repeat { if solid(nx,nextY) { nextY -= 1; delta -= 1 } } while delta > -11 && solid(nx,nextY)
            } else {
                repeat { nextY += 1; delta += 1 } while delta < 11 && !solid(nx,nextY)
                // The native downward probe returns the last air pixel, above the contact.
                if solid(nx,nextY) { nextY -= 1; delta -= 1 }
            }
            slopes.insert(delta,at:0); slopes.removeLast()
            if slopes.prefix(speed-1).contains(where:{vertical-5 > $0}) {
                x = cx; y = cy+1
                if speed >= (mode == .ski ? 3 : 4) { return .stunned }
                slopes = [0,0,0,0]; direction = -direction; velocityX = -velocityX; velocityY = -velocityY
                return .riding
            }
            if slopes[0]+slopes[1] > slopes[2]+slopes[3]+1+(speed < 4 ? 1 : 0) {
                x = cx; y = cy+1; return .airborne
            }
            cx = nx; cy = nextY
            if exit(cx,cy+1) { x = cx; y = cy+1; return .exiting }
        }
        x = cx; y = cy+1
        let slope = max(-5,min(5,cy-startY))
        velocityY = slope*16
        let cruise = mode == .ski ? 32 : 48
        let acceleration = mode == .ski ? 1 : 2
        if slope != 0 && !(mode == .roller && slope == -1) {
            velocityX += (slope < 0 ? slope+acceleration : slope)*direction
        } else if abs(velocityX) != cruise {
            velocityX += (abs(velocityX) < cruise ? acceleration : -1)*direction
        }
        return abs(velocityX)/16 < 2 ? .walking : .riding
    }
}
