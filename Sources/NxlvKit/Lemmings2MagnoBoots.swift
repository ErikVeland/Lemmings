/// Eight-orientation surface traversal from PROCESS 6034–6495.
public struct Lemmings2MagnoBoots: Equatable, Sendable {
    public private(set) var x: Int
    public private(set) var y: Int
    public private(set) var frame = 0
    public private(set) var orientation = 0
    private var previousX = 0
    private var previousY = 0
    private var stationary = 0
    private static let offsets = [(0,0),(8,9),(-1,17),(-9,8),(4,4),(4,13),(-5,13),(-5,4)]
    public var displayX: Int { x + Self.offsets[frame / 8].0 }
    public var displayY: Int { y + Self.offsets[frame / 8].1 }
    public init(x: Int,y: Int) { self.x = x; self.y = y }
    /// Returns false when contact is lost or the actor remains trapped in one cell.
    public mutating func step(direction: inout Int, solid: (Int,Int)->Bool) -> Bool {
        let phase = (frame+1)&7
        frame = phase
        func detachedDirection(_ orientation: Int, _ direction: Int) -> Int {
            let table = direction > 0 ? [0,1,1,0,0,1,1,0] : [0,0,1,1,0,1,1,0]
            return table[orientation] == 1 ? direction : -direction
        }
        guard solid(x,y) else {
            frame += orientation*8; direction = detachedDirection(orientation,direction); return false
        }
        let moves = orientation & 4 == 0 ? [0,0,0,1,1,1,1,0] : [0,0,0,1,1,1,0,0]
        guard moves[phase] != 0 else { frame += orientation*8; return true }
        if ((x-previousX)&0xfc) == 0 && ((y-previousY)&0xfc) == 0 {
            stationary += 1
            if stationary == 15 { frame += orientation*8; direction = detachedDirection(orientation,direction); return false }
        } else { previousX = x; previousY = y; stationary = 0 }
        let index = orientation + (direction < 0 ? 8 : 0)
        let transitions = [
            [4,1,7,3],[5,2,4,0],[6,3,5,1],[7,0,6,2],
            [1,5,0,7],[2,6,1,4],[3,7,2,5],[0,4,3,6],
            [7,3,4,1],[4,0,5,2],[5,1,6,3],[6,2,7,0],
            [0,7,1,5],[1,4,2,6],[2,5,3,7],[3,6,0,4]][index]
        let forward = [(1,0),(0,1),(-1,0),(0,-1),(1,1),(-1,1),(-1,-1),(1,-1),
                       (-1,0),(0,-1),(1,0),(0,1),(-1,-1),(1,-1),(1,1),(-1,1)][index]
        let outside = [(0,-1),(1,0),(0,1),(-1,0),(1,-1),(1,1),(-1,1),(-1,-1)][orientation]
        let back = [(0,-1),(1,0),(0,1),(-1,0),(1,-1),(1,1),(-1,1),(-1,-1),
                    (0,-1),(1,0),(0,1),(-1,0),(1,-1),(1,1),(-1,1),(-1,-1)][index]
        let inside = [(0,1),(-1,0),(0,-1),(1,0),(-1,1),(-1,-1),(1,-1),(1,1)][orientation]
        let startX = x, startY = y
        var cx = x, cy = y, px = x, py = y
        func reset() { cx = startX; cy = startY; px = cx; py = cy }
        @discardableResult func move(_ delta: (Int,Int)) -> Bool {
            cx += delta.0; cy += delta.1; px += delta.0; py += delta.1
            return solid(px,py)
        }
        func probe(_ delta: (Int,Int)) -> Bool { px += delta.0; py += delta.1; return solid(px,py) }
        move(forward)
        let savedPX = px, savedPY = py
        let hitsOutside = probe(outside)
        px = savedPX; py = savedPY
        var transitionalFrame: Int?
        if !hitsOutside {
            if !solid(px,py) {
                if move(inside) {
                    if move(forward) { reset(); move(forward); move(inside) }
                    else { orientation = transitions[0]; reset() }
                } else {
                    transitionalFrame = transitions[0]; orientation = transitions[1]; reset()
                }
            }
        } else {
            move(back)
            if move(back) {
                reset()
                if !move(forward) { reset() }
                orientation = transitions[3]; transitionalFrame = transitions[2]
            } else {
                if move(forward) && !move(back) { orientation = transitions[2]; reset() }
                else { reset(); move(back); move(forward) }
            }
        }
        x = cx; y = cy
        frame = phase + (transitionalFrame ?? orientation)*8
        return true
    }
}
