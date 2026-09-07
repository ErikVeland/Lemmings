/// Rail-mounted cannon and catapult mechanisms from the original L2 object routines.
public struct Lemmings2RailMachine: Sendable {
    public enum Kind: Sendable { case cannon, catapult }
    public let id: Int
    public let kind: Kind
    public let originX: Int
    public let y: Int
    public let minimumX: Int
    public let maximumX: Int
    public let leftControls: [Lemmings2Runtime.Rect]
    public let rightControls: [Lemmings2Runtime.Rect]
    public let triggers: [Lemmings2Runtime.Rect]
    public let frameCount: Int
    public private(set) var x: Int
    public private(set) var frame = 0
    public private(set) var delay = 0
    public private(set) var active = false
    public var captureX: Int { x + (kind == .cannon ? 8 : 24) }
    public var displacement: Int { x - originX }

    public init(id: Int, kind: Kind, x: Int, y: Int, minimumX: Int, maximumX: Int,
                leftControls: [Lemmings2Runtime.Rect], rightControls: [Lemmings2Runtime.Rect],
                triggers: [Lemmings2Runtime.Rect], frameCount: Int) {
        self.id = id; self.kind = kind; self.x = x; self.originX = x; self.y = y
        self.minimumX = minimumX; self.maximumX = maximumX
        self.leftControls = leftControls; self.rightControls = rightControls; self.triggers = triggers
        self.frameCount = max(6, frameCount)
    }
    public mutating func move(atX px: Int, y py: Int) -> Bool {
        if leftControls.contains(where: { $0.contains(px,py) }) { x = max(minimumX,x-1); return true }
        if rightControls.contains(where: { $0.contains(px,py) }) { x = min(maximumX,x+1); return true }
        return false
    }
    public mutating func capture(x: Int, y: Int) -> Bool {
        guard !active, x == captureX, triggers.contains(where: { $0.contains(x,y) }) else { return false }
        active = true; frame = 0; delay = kind == .cannon ? 46 : 52
        return true
    }
    public mutating func step() {
        guard active else { return }
        if delay > 0 { delay -= 1; return }
        frame += 1
        if frame >= frameCount { frame = 0; active = false }
    }
    public func riderPosition(phase: Int) -> (x: Int, y: Int) {
        let path = kind == .cannon ? Self.cannonPath : Self.catapultPath
        let point = path[max(0,min(path.count-1,phase))]
        return (x+8+point.0, y+(kind == .cannon ? 24+point.1 : 12-point.1))
    }
    public static func resolve(parts: Lemmings2Objects) throws -> [Self] {
        try Set(parts.parts.filter { [1,7].contains($0.type) }.map(\.objectIndex)).sorted().map { id in
            let pieces = parts.parts.filter { $0.objectIndex == id }
            guard pieces.count >= 5, let first = pieces.first, let last = pieces.last else {
                throw SequelDataError.invalid("Incomplete L2 rail machine.")
            }
            let cannon = first.type == 1, base = pieces[pieces.count-(cannon ? 1 : 2)]
            let control = cannon ? 0 : 3
            func controls(_ interaction: Int) -> [Lemmings2Runtime.Rect] {
                pieces.filter { $0.component.interaction == interaction && $0.component.triggerFlags & 0x18 == 0x18 }.map {
                    .init(x:$0.x,y:$0.y,width:$0.frames.first?.width ?? 16,height:$0.frames.first?.height ?? 8)
                }
            }
            return .init(id:id,kind:cannon ? .cannon : .catapult,x:base.x,y:base.y,
                minimumX:first.x+(cannon ? 12 : 16),maximumX:pieces[pieces.count-(cannon ? 2 : 3)].x-(cannon ? 28 : 48),
                leftControls:controls(control),rightControls:controls(control+1),
                triggers:pieces.filter { $0.component.interaction == (cannon ? 2 : 5) }.compactMap(\.trigger),
                frameCount:last.frames.count)
        }
    }
    // PROCESS 0x3e5d position table.
    private static let cannonPath: [(Int,Int)] = [
        (0,0),(0,0),(0,0),(0,0),(0,0),(0,0),(1,0),(2,0),
        (3,0),(4,0),(5,0),(6,0),(7,0),(8,0),(9,0),(10,0),
        (11,0),(12,0),(13,0),(14,0),(15,0),(16,0),(17,0),(18,0),
        (19,0),(19,0),(19,0),(19,0),(19,0),(19,0),(19,0),(19,0),
        (19,0),(19,-1),(19,-2),(19,-3),(19,-3),(19,-3),(19,-3),(19,-3),
        (19,-3),(19,-3),(19,-3),(19,-3),(19,-3),
    ]
    // PROCESS 0x3f56 position table.
    private static let catapultPath: [(Int,Int)] = [
        (15,4),(15,4),(15,4),(15,4),(15,4),(15,5),(15,6),(15,7),
        (15,7),(15,7),(15,8),(15,8),(15,9),(15,9),(15,9),(15,9),
        (15,9),(15,9),(15,9),(15,9),(15,9),(15,11),(15,15),(15,18),
        (15,19),(15,20),(15,20),(15,20),(15,20),(15,20),(15,20),(15,20),
        (16,20),(17,20),(18,20),(19,21),(20,21),(21,21),(22,21),(23,23),
        (24,23),(25,23),(26,23),(27,25),(28,25),(29,25),(30,25),(31,28),
        (33,29),(34,29),(36,28),(36,28),(36,27),(36,26),(36,27),(36,28),
        (26,37),(6,44),
    ]
}
