import Foundation

/// Cursor flight, turn and landing phases from PROCESS 43ce–4692.
public struct Lemmings2Superlem: Equatable, Sendable {
    public enum Result: Sendable { case active, walking, falling, stunned, tumbling }
    public private(set) var x: Int
    public private(set) var y: Int
    public private(set) var pose = 0
    public private(set) var stage = 1
    public private(set) var velocityX = 0
    public private(set) var velocityY = 0
    private var noseX: Int
    private var noseY: Int
    public var horizontal: Bool { stage == 2 || stage == 4 }
    public init(x:Int,y:Int) { self.x = x; self.y = y; noseX = x; noseY = y-8 }
    public mutating func step(targetX:Int,targetY:Int,solid:(Int,Int)->Bool) -> Result {
        let oldX = x, oldY = y
        switch stage {
        case 1:
            guard solid(x,y) else { return .falling }
            if pose < 19 { pose += 1; return .active }
            y -= 7
            if max(abs(targetX-x),abs(targetY-y)) < 8 { y += 7; stage = 9; pose = 12; return .active }
            stage = 2
        case 5:
            pose += 1
            if pose < 64 {
                y -= [3,2,1,1,1,0,0,-1,-1,-1,-2,-3][pose-52]
                if solid(x-9,y) { return .tumbling }
                return .active
            }
            stage = 6; pose = 63
        case 7:
            pose += 1
            if pose < 84 { return .active }
            stage = 8; pose = 12; return .active
        case 8:
            pose += 1
            if pose < 20 { return .active }
            stage = 9; pose = 11; return .active
        case 9:
            pose -= 1
            return pose < 0 ? .walking : .active
        default: break
        }
        if stage == 6 {
            let hit = Lemmings2AirCollision.sweep(x:x,y:y-1,toX:x,toY:y+3,height:0,solid:solid)
            if hit.contact == .clear { y += 3; pose = pose >= 79 ? 64 : pose+1 }
            else { y = hit.y; stage = 7; pose = 80 }
            return .active
        }
        if stage == 2 {
            let dx = targetX-x, dy = targetY-y
            if max(abs(dx),abs(dy)) < 8 { stage = 4 }
            else {
                let ax = abs(dx), ay = abs(dy), sx = dx < 0 ? -1 : 1, sy = dy < 0 ? -1 : 1
                var error = max(ax,ay)/2
                for _ in 0..<8 {
                    if ax > ay { x += sx; error -= ay; if error < 0 { y += sy; error += ax } }
                    else { y += sy; error -= ax; if error < 0 { x += sx; error += ay } }
                }
                pose = 20+(Int((atan2(Double(dy),Double(dx))*16 / .pi).rounded()+32)%32)
            }
        }
        if stage == 4 {
            if pose == 44 { stage = 5; pose = 51; y += 8; return .active }
            let turn = [(8,0),(8,2),(7,3),(7,4),(6,6),(4,7),(3,7),(2,8),(0,8),(-2,8),(-3,7),(-4,7),(-6,6),(-7,4),(-7,3),(-8,2),(-8,0),(-7,-2),(-6,-3),(-5,-5),(-4,-6),(-3,-6),(-2,-6),(-1,-6),(0,-6),(1,-6),(2,-6),(3,-6),(4,-5),(5,-4),(6,-3),(7,-2)][max(0,min(31,pose-20))]
            x += turn.0; y += turn.1
            pose = (28..<44).contains(pose) ? pose+1 : pose == 20 ? 51 : pose-1
        }
        velocityX = x-oldX; velocityY = y-oldY
        let angle = max(0,min(31,pose-20)), octant = angle&7
        var tx = [4,4,4,3,3,2,2,1][octant], ty = [0,1,2,2,3,3,4,4][octant]
        if angle >= 24 { let old = tx; tx = ty; ty = -old }
        else if angle >= 16 { tx = -tx; ty = -ty }
        else if angle >= 8 { let old = tx; tx = -ty; ty = old }
        let hit = Lemmings2AirCollision.sweep(x:noseX,y:noseY-1,toX:x+tx,toY:y+ty,height:0,solid:solid)
        noseX = x+tx; noseY = y+ty
        if hit.contact != .clear {
            x = hit.previousX; y = hit.previousY
            if velocityY < 0, let floor = (1...9).first(where:{solid(x,y+$0)}) { y += floor; return .stunned }
            velocityX = max(-8,min(8,velocityX/8)); velocityY = max(-8,min(8,velocityY/8))
            return .tumbling
        }
        return .active
    }
}
