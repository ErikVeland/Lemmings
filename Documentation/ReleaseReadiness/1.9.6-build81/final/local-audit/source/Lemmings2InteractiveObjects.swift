/// Stateful triggers resolved from the original L2 object records.
public struct Lemmings2InteractiveObject: Sendable {
    public enum Kind: Sendable { case trap, launcher, trampoline, timedTrap, valve, teleporter }
    public let linkedID: Int?
    public let destinationX: Int
    public let destinationY: Int
    public let minimumFrame: Int
    public let maximumFrame: Int
    public let deathSprite: Int
    public let inactiveFrame: Int
    public let activeFrame: Int
    public let id: Int
    public let kind: Kind
    public let triggers: [Lemmings2Runtime.Rect]
    public let frameCount: Int
    public let velocityX: Int
    public let velocityY: Int
    public let flags: Int
    public let initiallyActive: Bool

    public init(id: Int, kind: Kind, triggers: [Lemmings2Runtime.Rect], frameCount: Int,
                velocityX: Int = 0, velocityY: Int = 0, flags: Int = 0, initiallyActive: Bool = false,
                linkedID: Int? = nil, destinationX: Int = 0, destinationY: Int = 0,
                minimumFrame: Int = 0, maximumFrame: Int = 0, deathSprite: Int = 126,
                inactiveFrame: Int = 0, activeFrame: Int = 0) {
        self.linkedID = linkedID; self.destinationX = destinationX; self.destinationY = destinationY
        self.minimumFrame = minimumFrame; self.maximumFrame = maximumFrame; self.deathSprite = deathSprite
        self.inactiveFrame = inactiveFrame; self.activeFrame = activeFrame
        self.id = id; self.kind = kind; self.triggers = triggers; self.frameCount = max(1, frameCount)
        self.velocityX = max(-8, min(8, velocityX)); self.velocityY = max(-8, min(8, velocityY))
        self.flags = flags; self.initiallyActive = initiallyActive
    }

    public static func resolve(level: Lemmings2Level, style: Lemmings2Style,
                               parts: Lemmings2Objects) -> [Self] {
        let placedObjects = level.objects.enumerated().filter {
            $0.element.identifier != 65535 && style.objects.indices.contains($0.element.identifier)
        }
        let valves = placedObjects.filter { style.objects[$0.element.identifier].type == 13 }.map(\.offset)
        let launchers = placedObjects.filter {
            let o = style.objects[$0.element.identifier]; return o.type == 12 && o.parameters[3] & 2 == 0
        }.map(\.offset)
        let portals = placedObjects.filter { style.objects[$0.element.identifier].type == 14 }.map(\.offset)
        return placedObjects.compactMap { index, placed in
            guard placed.identifier != 65535, style.objects.indices.contains(placed.identifier) else { return nil }
            let object = style.objects[placed.identifier]
            guard [4, 9, 10, 12, 13, 14].contains(object.type) else { return nil }
            let resolved = parts.parts.filter { $0.objectIndex == index }
            let interaction = [4:11,9:6,10:7,12:9,13:10,14:12][object.type]!
            let kind: Kind = [4:.trampoline,9:.trap,10:.timedTrap,12:.launcher,13:.valve,14:.teleporter][object.type]!
            var link: Int?
            if kind == .valve, let position = valves.firstIndex(of:index), launchers.indices.contains(position) { link = launchers[position] }
            if kind == .teleporter, let position = portals.firstIndex(of:index), portals.indices.contains(position ^ 1) { link = portals[position ^ 1] }
            let origin = resolved.first
            let triggers = resolved.filter { $0.component.interaction == interaction }.compactMap(\.trigger)
            return .init(id: index, kind: kind, triggers: triggers,
                         frameCount: resolved.map { $0.frames.count }.max() ?? 1,
                         velocityX: Int(Int16(truncatingIfNeeded: object.parameters[1])),
                         velocityY: Int(Int16(truncatingIfNeeded: object.parameters[2])),
                         flags: object.parameters[3], initiallyActive: object.parameters[0] != 0,
                         linkedID:link,destinationX:(origin?.x ?? 0)+object.parameters[1],
                         destinationY:(origin?.y ?? 0)+object.parameters[2],
                         minimumFrame:object.parameters[2],maximumFrame:object.parameters[3],deathSprite:object.parameters[4],
                         inactiveFrame:object.parameters[4],activeFrame:object.parameters[5])
        }
    }
}
