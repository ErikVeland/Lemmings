/// A projectile-driven rope path, limited to the original 64 stored pixels.
public struct Lemmings2Rope: Sendable {
    public struct Point: Equatable, Sendable {
        public let x: Int
        public let y: Int
        public init(x: Int, y: Int) { self.x = x; self.y = y }
    }
    public let owner: Int
    public private(set) var points: [Point]
    public private(set) var anchored = false
    public private(set) var finished = false
    private var hook: Lemmings2Projectile
    public var x: Int { hook.x }
    public var y: Int { hook.y }
    public var frame: Int { hook.frame }
    public private(set) var anchor: Point?
    public init(owner: Int, x: Int, y: Int, targetX: Int, targetY: Int) throws {
        var dx = targetX-x, dy = targetY-y
        guard abs(dx) <= 8192, abs(dy) <= 8192 else {
            throw SequelDataError.invalid("Rope aim exceeds the level bounds.")
        }
        // PROCESS a762 extends short aims before launching the hook.
        var length = max(abs(dx),abs(targetY-x))
        if length >= 16 && length < 64 {
            repeat { length *= 2; dx *= 2; dy *= 2 } while length < 64
        }
        hook = try .aimedArrow(x:x,y:y,targetX:x+dx,targetY:y+dy)
        self.owner = owner; points = [.init(x:x,y:y)]
    }
    public mutating func step(solid: (Int,Int)->Bool) {
        guard !finished else { return }
        let previous = hook.tip
        hook.step()
        let hit = Lemmings2AirCollision.sweep(x:previous.x,y:previous.y,toX:hook.tip.x,toY:hook.tip.y,height:0,solid:solid)
        var endX = hook.x, endY = hook.y
        if hit.contact != .clear {
            endX = hit.x-(hook.tip.x-hook.x); endY = hit.y-(hook.tip.y-hook.y)
            anchor = .init(x:endX,y:endY)
        }
        guard let last = points.last else { finished = true; return }
        var x = last.x, y = last.y
        let dx = abs(endX-x), dy = abs(endY-y), sx = endX < x ? -1 : 1, sy = endY < y ? -1 : 1
        var error = max(dx,dy)/2
        for _ in 0..<max(dx,dy) {
            if points.count >= 64 { finished = true; anchor = nil; return }
            if dx >= dy {
                x += sx; error -= dy
                if error < 0 { y += sy; error += dx }
            } else {
                y += sy; error -= dx
                if error < 0 { x += sx; error += dy }
            }
            points.append(.init(x:x,y:y))
        }
        if anchor != nil { anchored = true; finished = true }
    }
}
