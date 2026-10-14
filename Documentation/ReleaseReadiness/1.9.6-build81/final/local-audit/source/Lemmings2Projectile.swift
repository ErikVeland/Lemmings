/// Native thrown-object motion uses eighth-pixel positions and its own drag timer.
public struct Lemmings2Projectile: Sendable {
    public enum Kind: Sendable { case bazooka, mortar, stone, spear, arrow }
    public let kind: Kind
    public private(set) var fixedX: Int16
    public private(set) var fixedY: Int16
    public private(set) var velocityX: Int16
    public private(set) var velocityY: Int16
    private var horizontalDelay = 9
    private var dragPeriod = 9
    private var straight: (dx:Int,dy:Int,sx:Int,sy:Int,error:Int,left:Int,steps:Int)?
    private var verticalDelay: Int
    public var x: Int { Int(fixedX) >> 3 }
    public var y: Int { Int(fixedY) >> 3 }
    public var angle: Int {
        func quantize(_ value: Int16) -> Int {
            value == 0 ? 0 : max(-8,min(8,(Int(value) >> 3) + (value > 0 ? 1 : 0)))
        }
        let x = quantize(velocityX), y = quantize(velocityY)
        let lookup = [
            0,0,0,0,0,0,0,0,0, 8,4,2,1,1,0,0,0,0,
            8,6,4,2,2,1,1,1,1, 8,7,6,4,3,2,2,1,1,
            8,7,6,5,4,3,2,2,2, 8,8,7,6,5,4,3,2,2,
            8,8,7,6,6,5,4,3,2, 8,8,7,7,6,6,5,4,3,
            8,8,7,7,6,6,6,5,4]
        let swapped = (x < 0) != (y < 0)
        let base = y < 0 ? (x < 0 ? 16 : 24) : (x < 0 ? 8 : 0)
        return (base + lookup[9 * abs(swapped ? x : y) + abs(swapped ? y : x)]) % 32
    }
    public var frame: Int {
        if kind == .arrow { return angle }
        if kind == .spear { return angle & 15 }
        if kind == .stone { return (age * (velocityX < 0 ? -1 : 1)) & 3 }
        return [1,1,1,2,2,2,2,3,3,3,6,6,6,6,5,5,5,5,4,4,4,4,4,4,0,0,0,0,0,0,0,1][angle]
    }
    private var age = 0
    public var tip: (x: Int, y: Int) {
        let a = angle, octant = a & 7
        if kind == .stone { return (x,y) }
        var dx = kind == .arrow ? [4,4,4,3,3,2,2,1][octant] : kind == .spear ? [7,7,7,7,6,5,3,2][octant] : octant < 6 ? 1 : 0
        var dy = kind == .arrow ? [0,1,2,2,3,3,4,4][octant] : kind == .spear ? [0,2,3,5,6,7,7,7][octant] : octant < 3 ? 0 : 1
        if a >= 24 { let old = dx; dx = dy; dy = -old }
        else if a >= 16 { dx = -dx; dy = -dy }
        else if a >= 8 { let old = dx; dx = -dy; dy = old }
        return (x+dx,y+dy)
    }
    public init(kind: Kind, x: Int, y: Int, velocityX: Int, velocityY: Int) throws {
        guard (-8...8).contains(velocityX), (-8...8).contains(velocityY) else {
            throw SequelDataError.invalid("Invalid L2 projectile launch velocity.")
        }
        self.kind = kind
        fixedX = Int16(truncatingIfNeeded:x*8); fixedY = Int16(truncatingIfNeeded:y*8)
        self.velocityX = Int16(velocityX*8); self.velocityY = Int16(velocityY*8)
        verticalDelay = [0,0,0,1,1,2,2,3,3][abs(velocityY)]
    }
    public static func aimedArrow(x:Int,y:Int,targetX:Int,targetY:Int) throws -> Self {
        let dx = targetX-x, dy = targetY-y
        guard max(abs(dx),abs(dy)) >= 16, abs(dx) <= 8192, abs(dy) <= 8192 else {
            throw SequelDataError.invalid("Aim the arrow farther away.")
        }
        // PROCESS a7ae–a865: integer length, angle correction and signed shifts.
        let length = Int(Double(dx*dx+dy*dy).squareRoot())
        let angle = Int(Self.aimAngles[min(256,abs(dy)*256/length)]) / 4
        let factor = Self.aimFactors[angle]
        let vx = length > 64 ? dx*64/length : dx
        let vy = length > 64 ? dy*64/length : dy
        let nx = (vx*factor) >> 6, ny = (vy*factor) >> 6
        var result = try Self(kind:.arrow,x:x,y:y,velocityX:0,velocityY:0)
        result.velocityX = Int16(nx); result.velocityY = Int16(ny)
        result.dragPeriod = 19; result.horizontalDelay = 19
        let distance = max(abs(nx),abs(ny))
        result.straight = (abs(nx),abs(ny),nx < 0 ? -1 : 1,ny < 0 ? -1 : 1,distance/2,distance,min(64,length)/8+1)
        return result
    }
    public mutating func step() {
        age += 1
        if var path = straight {
            var px = x, py = y
            for _ in 0..<path.steps {
                if path.dx > path.dy {
                    px += path.sx; path.error -= path.dy
                    if path.error < 0 { py += path.sy; path.error += path.dx }
                } else {
                    py += path.sy; path.error -= path.dx
                    if path.error < 0 { px += path.sx; path.error += path.dy }
                }
                path.left -= 1
            }
            fixedX = Int16(truncatingIfNeeded:px*8); fixedY = Int16(truncatingIfNeeded:py*8)
            if path.left <= 0 {
                straight = nil
                velocityX = (velocityX >> 3) * 8; velocityY = (velocityY >> 3) * 8
                verticalDelay = [0,0,0,1,1,2,2,3,3][min(8,abs(Int(velocityY))/8)]
            } else { straight = path }
            return
        }
        fixedX = fixedX &+ velocityX; fixedY = fixedY &+ velocityY
        if abs(Int(velocityX)) > 8 {
            horizontalDelay -= 1
            if horizontalDelay < 0 {
                velocityX += velocityX < 0 ? 8 : -8; horizontalDelay = dragPeriod
            }
        }
        verticalDelay -= 1
        if verticalDelay < 0 {
            velocityY = min(64,velocityY+8)
            verticalDelay = [0,0,0,1,1,2,2,3,3][abs(Int(velocityY))/8] + abs(Int(velocityX))/16
        }
    }
    // PROCESS 9880 and b763 native aiming tables.
    private static let aimAngles: [UInt8] = [
        0,0,0,1,1,1,1,2,2,2,2,2,3,3,3,3,4,4,4,4,4,5,5,5,
        5,6,6,6,6,7,7,7,7,7,8,8,8,8,9,9,9,9,9,10,10,10,10,11,
        11,11,11,11,12,12,12,12,13,13,13,13,14,14,14,14,14,15,15,15,15,16,16,16,
        16,17,17,17,17,18,18,18,18,18,19,19,19,19,20,20,20,20,21,21,21,21,22,22,
        22,22,23,23,23,23,23,24,24,24,24,25,25,25,25,26,26,26,26,27,27,27,27,28,
        28,28,28,29,29,29,29,30,30,30,31,31,31,31,32,32,32,32,33,33,33,33,34,34,
        34,35,35,35,35,36,36,36,36,37,37,37,38,38,38,38,39,39,39,40,40,40,40,41,
        41,41,42,42,42,43,43,43,43,44,44,44,45,45,45,46,46,46,47,47,47,48,48,48,
        49,49,49,50,50,50,51,51,51,52,52,52,53,53,54,54,54,55,55,56,56,56,57,57,
        58,58,58,59,59,60,60,61,61,62,62,62,63,63,64,64,65,66,66,67,67,68,68,69,
        70,70,71,72,72,73,74,75,76,77,78,79,80,81,83,85,90,
    ]
    private static let aimFactors = [71,70,65,64,59,58,55,54,55,52,49,49,48,49,47,47,48,47,48,49,48,48,48]

}
