/// Cellular terrain flow from L2.RKO 33a9–3686.
public struct Lemmings2FillParticle: Sendable {
    public enum Kind: Int, Sendable { case filler, sand, glue }
    private static let tables: [[UInt8]] = [
            Array("ddddllllddddRlllddddssssddddRsssddddrsLLddddrsrsddddrsrsddddrsrs".utf8),
            Array("ddddllllddddRsssddddRsssddddRsssddddrLLLddddrsssddddrsssddddrsss".utf8),
            Array("dsddlllsdsddlllldsddssssdsddssssddddrsrsddddrsrsssssrsrsddddssrs".utf8),
        ]
    public var x: Int
    public var y: Int
    public var direction: Int
    public let kind: Kind
    public init(x: Int, y: Int, direction: Int, kind: Kind) {
        self.x = x; self.y = y; self.direction = direction < 0 ? -1 : 1; self.kind = kind
    }
    /// Returns true when this step settles the particle into terrain.
    public mutating func step(solid: (Int, Int) -> Bool) -> Bool {
        guard direction != 0 else { return false }
        let bits = (solid(x+1,y) ? 1 : 0) | (solid(x+1,y+1) ? 2 : 0)
            | (solid(x,y+1) ? 4 : 0) | (solid(x-1,y+1) ? 8 : 0) | (solid(x-1,y) ? 16 : 0)
        // d: down, l/r: sideways, L/R: reverse then sideways, s: settle.
        switch Self.tables[kind.rawValue][bits + (direction > 0 ? 32 : 0)] {
        case 100: y += 1
        case 108: x -= 1
        case 114: x += 1
        case 76: direction = -direction; x -= 1
        case 82: direction = -direction; x += 1
        default: direction = 0; return true
        }
        return false
    }
}
