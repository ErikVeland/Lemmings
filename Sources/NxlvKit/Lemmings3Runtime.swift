import Foundation

/// Separate Chronicles simulation. Movement constants are experimental until
/// compared with original-engine traces. No L1 or L2 physics are reused.
public struct Lemmings3Runtime: Sendable {
    public enum Action: String, CaseIterable, Sendable { case walker, blocker, jumper, use, drop }
    public enum State: String, Sendable { case walking, falling, floating, swimming, jumping, climbing, shimmying, blocking, building, digging, drowning, trapped, exiting, saved, dead }
    public enum Tool: Int, Sendable, CaseIterable {
        case bricks = 5000, bomb = 5001, spade = 5002, shimmy = 5003, sucker = 5004, umbrella = 5005, hadoken = 5006, grenade = 5007, swimmer = 5008, clock = 5009
        public var initialQuantity: Int { self == .grenade ? 4 : (self == .bricks || self == .spade ? 6 : 1) }
        public var label: String { switch self { case .bricks: "B"; case .bomb: "BO"; case .spade: "D"; case .shimmy: "SH"; case .sucker: "CL"; case .umbrella: "U"; case .hadoken: "H"; case .grenade: "G"; case .swimmer: "S"; case .clock: "C" } }
    }
    public enum Direction: String, CaseIterable, Sendable {
        case upLeft, up, upRight, left, right, downLeft, down, downRight
        public var dx: Int { switch self { case .upLeft, .left, .downLeft: -1; case .upRight, .right, .downRight: 1; default: 0 } }
        public var dy: Int { switch self { case .upLeft, .up, .upRight: -1; case .downLeft, .down, .downRight: 1; default: 0 } }
    }
    public struct Pickup: Equatable, Sendable {
        public let id: Int, tool: Tool
        public var x: Int, y: Int, quantity: Int
        public var ignoredBy: Int?
        public init(id: Int, tool: Tool, x: Int, y: Int, quantity: Int? = nil) {
            self.id = id; self.tool = tool; self.x = x; self.y = y; self.quantity = quantity ?? tool.initialQuantity
        }
    }
    public struct Extra: Sendable {
        public let x: Int, y: Int, direction: Int
        public init(x: Int, y: Int, direction: Int) { self.x = x; self.y = y; self.direction = direction }
    }
    public struct Trap: Sendable {
        public let id: Int, frameCount: Int
        public let startFrame: Int, frameDelay: Int, cyclePause: Int
        public let cells: [Point]
        public var cycleTicks: Int { (frameCount - startFrame) * (frameDelay + 1) + cyclePause }
        public init(id: Int, cells: [Point], frameCount: Int, startFrame: Int = 0, frameDelay: Int = 2, cyclePause: Int = 0) {
            self.id = id; self.cells = cells; self.frameCount = frameCount
            self.startFrame = startFrame; self.frameDelay = frameDelay; self.cyclePause = cyclePause
        }
    }
    public struct Explosive: Equatable, Sendable {
        public let id: Int, tool: Tool
        public var x: Int, y: Int, velocityX: Int, velocityY: Int, age = 0
        public var fuseTicks: Int { (tool == .bomb ? 5 : 8) * 23 }
    }
    public struct Blast: Sendable {
        public let x: Int, y: Int, tick: Int
    }
    public struct Fireball: Equatable, Sendable {
        public var x: Int, y: Int, direction: Int, age = 0
    }
    public struct Creature: Equatable, Sendable {
        public enum Kind: Int, Sendable { case fatale = 10010, mole = 10012, buzzard = 10014, potato = 10016 }
        public let id: Int, kind: Kind
        public var x: Int, y: Int, direction: Int
        public var alive = true
        public var target: Int?
        public var cooldown = 0
        public var age = 0
        public var digDirection: Direction
        public var width: Int { kind == .buzzard ? 48 : (kind == .potato ? 32 : 16) }
        public var height: Int { kind == .buzzard ? 48 : (kind == .mole ? 18 : 24) }
        public var objectID: Int { kind.rawValue + (direction > 0 ? 1 : 0) }
        public init(id: Int, kind: Kind, x: Int, y: Int, direction: Int = 1) {
            self.id = id; self.kind = kind; self.x = x; self.y = y; self.direction = direction
            digDirection = direction > 0 ? .right : .left
        }
    }
    public struct Lemming: Equatable, Sendable {
        public let id: Int
        public var x: Int
        public var y: Int
        public var direction = 1
        public var state: State = .falling
        public var age = 0
        public var fall = 0
        public var velocityY = 0
        public var tool: Tool?
        public var quantity = 0
        public var workDirection: Direction = .right
        public var swimTicks = 0
        public var trapTicks = 0
        /// Active climbing equipment has a provisional five-second lifetime.
        public var mobilityTool: Tool?
        public var mobilityTicks = 0
        public var charmedBy: Int?
        public var charmTicks = 0
        public var charmImmunity = 0
        public var active: Bool { state != .saved && state != .dead }
    }
    public struct Point: Sendable { public let x: Int; public let y: Int
        public init(x: Int, y: Int) { self.x = x; self.y = y }
    }
    public struct Configuration: Sendable {
        public let width: Int, height: Int, total: Int, releaseInterval: Int, releaseDelay: Int, timeLimit: Int
        public let attributes: [UInt16]
        public let backgroundAttributes: [UInt16]
        public let entrance: Point
        public let additionalEntrances: [Point]
        public let exits: [Point]
        public let pickups: [Pickup]
        public let extras: [Extra]
        public let traps: [Trap]
        public let creatures: [Creature]
        public let sourceLevelReference: Int?
        public init(width: Int, height: Int, attributes: [UInt16], entrance: Point, exits: [Point],
                    total: Int = 20, releaseInterval: Int = 23, releaseDelay: Int = 46, timeLimit: Int = 420,
                    pickups: [Pickup] = [], extras: [Extra] = [], backgroundAttributes: [UInt16]? = nil,
                    sourceLevelReference: Int? = nil, traps: [Trap] = [], creatures: [Creature] = [], additionalEntrances: [Point] = []) {
            self.width = width; self.height = height; self.attributes = attributes
            self.entrance = entrance; self.exits = exits; self.total = total
            self.releaseInterval = releaseInterval; self.releaseDelay = releaseDelay; self.timeLimit = timeLimit
            self.pickups = pickups; self.extras = extras
            self.backgroundAttributes = backgroundAttributes ?? Array(repeating: 0x1000, count: attributes.count)
            self.sourceLevelReference = sourceLevelReference
            self.traps = traps
            self.creatures = creatures
            self.additionalEntrances = additionalEntrances
        }
    }
    public let configuration: Configuration
    public private(set) var lemmings: [Lemming] = []
    public private(set) var tick = 0
    public private(set) var released = 0
    public private(set) var isComplete = false
    public private(set) var attributes: [UInt16]
    public private(set) var pickups: [Pickup]
    /// Pixel changes let the renderer reveal the background after digging.
    public private(set) var terrainEdits: [Int: Bool] = [:]
    public private(set) var bonusSeconds = 0
    public private(set) var explosives: [Explosive] = []
    public private(set) var blasts: [Blast] = []
    public private(set) var fireballs: [Fireball] = []
    public private(set) var creatures: [Creature] = []
    private var nextExplosiveID = 0
    private var nextPickupID: Int
    private var trapStarted: [Int: Int] = [:]
    /// Native OBJ timing includes a delay counter and a pause at the cycle boundary.
    public func trapFrame(id: Int) -> Int {
        guard let trap = configuration.traps.first(where: { $0.id == id }) else { return 0 }
        guard let start = trapStarted[id], tick - start < trap.cycleTicks else { return trap.startFrame }
        return trap.startFrame + max(0, tick - start - trap.cyclePause) / (trap.frameDelay + 1)
    }
    public var reserve: Int { configuration.total - released }
    public var survivors: Int { saved + reserve }
    private var releaseTarget: Int {
        min(configuration.total, 10 + lemmings.filter { $0.id >= configuration.extras.count && $0.state == .dead }.count)
    }
    public static let ticksPerSecond = 23.0
    public var saved: Int { lemmings.filter { $0.state == .saved }.count }
    public var lost: Int { lemmings.filter { $0.state == .dead }.count }
    public var remainingSeconds: Int { max(0, configuration.timeLimit + bonusSeconds - tick / 23) }

    public init(configuration c: Configuration) throws {
        guard c.width > 0, c.height > 0, c.width <= 4096, c.height <= 4096,
              c.width * c.height <= 4_194_304, c.attributes.count == c.width * c.height,
              c.backgroundAttributes.count == c.attributes.count,
              (1...1000).contains(c.total), (1...1000).contains(c.releaseInterval),
              (0...1000).contains(c.releaseDelay), (1...3600).contains(c.timeLimit),
              c.entrance.x >= 0, c.entrance.x < c.width, c.entrance.y >= 0, c.entrance.y < c.height,
              c.additionalEntrances.count <= 255,
              c.additionalEntrances.allSatisfy({ $0.x >= 0 && $0.x < c.width && $0.y >= 0 && $0.y < c.height }),
              c.pickups.count <= 4096, c.extras.count <= 255,
              c.creatures.count <= 255, Set(c.creatures.map(\.id)).count == c.creatures.count,
              c.creatures.allSatisfy({ $0.id >= 0 && [-1, 1].contains($0.direction) && $0.x >= 0 && $0.x < c.width && $0.y >= 0 && $0.y < c.height }),
              c.traps.count <= 4096, Set(c.traps.map(\.id)).count == c.traps.count,
              c.traps.allSatisfy({ $0.id >= 0 && (1...256).contains($0.frameCount) && (0..<$0.frameCount).contains($0.startFrame) && (0...127).contains($0.frameDelay) && (0...127).contains($0.cyclePause) && !$0.cells.isEmpty && $0.cells.count <= 4096 && $0.cells.allSatisfy({ $0.x >= 0 && $0.y >= 0 && $0.x + 8 <= c.width && $0.y + 2 <= c.height }) }),
              Set(c.pickups.map(\.id)).count == c.pickups.count,
              c.pickups.allSatisfy({ $0.id >= 0 && $0.id < 1_000_000 && $0.quantity > 0 && $0.quantity <= 1000 && $0.x >= 0 && $0.y >= 0 && $0.x + 8 <= c.width && $0.y + 8 <= c.height }),
              c.extras.allSatisfy({ [-1, 1].contains($0.direction) && $0.x >= 0 && $0.x < c.width && $0.y >= 0 && $0.y < c.height }),
              !c.exits.isEmpty, c.exits.allSatisfy({ $0.x >= 0 && $0.y >= 0 && $0.x + 8 <= c.width && $0.y + 2 <= c.height }) else {
            throw SequelDataError.invalid("Invalid Chronicles simulation configuration.")
        }
        configuration = c
        attributes = c.attributes; pickups = c.pickups
        creatures = c.creatures
        nextPickupID = (c.pickups.map(\.id).max() ?? -1) + 1
        lemmings = c.extras.enumerated().map { index, extra in
            var lem = Lemming(id: index, x: extra.x, y: extra.y)
            lem.direction = extra.direction; return lem
        }
    }

    public init(level: Lemmings3Level, style: Lemmings3Style, permanent: Lemmings3Objects,
                temporary: Lemmings3Objects, total: Int = 20) throws {
        guard (1...3).contains(level.style) else {
            throw SequelDataError.invalid("Unknown Chronicles style.")
        }
        let scene = try Lemmings3Scene(level: level, style: style, permanent: permanent, temporary: temporary)
        var entrances: [Point] = []
        var exits: [Point] = []
        var pickups: [Pickup] = []
        var extras: [Extra] = []
        var traps: [Trap] = []
        var creatures: [Creature] = []
        for (index, placed) in permanent.placements.enumerated() {
            guard let definition = style.permanent.objects[placed.identifier] else {
                throw SequelDataError.invalid("Missing Chronicles object definition.")
            }
            if let tool = Tool(rawValue: placed.identifier) {
                pickups.append(.init(id: index, tool: tool, x: placed.x, y: placed.y)); continue
            }
            if [10006, 10007].contains(placed.identifier) {
                extras.append(.init(x: placed.x + 8, y: placed.y + 16, direction: placed.identifier == 10006 ? -1 : 1)); continue
            }
            if let kind = Creature.Kind(rawValue: placed.identifier / 2 * 2) {
                creatures.append(.init(id: index, kind: kind,
                    x: placed.x + definition.columns * 4, y: placed.y + definition.rows * 2,
                    direction: placed.identifier.isMultiple(of: 2) ? -1 : 1))
                continue
            }
            if (0x4002...0x400a).contains(definition.flags) {
                guard definition.animationMode == 1, definition.animationStartFrame == 1, definition.frameCount > 1 else {
                    throw SequelDataError.invalid("Unsupported Chronicles trap animation cycle.")
                }
                let tags = try style.permanent.attributes(object: placed.identifier)
                let cells = tags.enumerated().compactMap { cell, tag -> Point? in
                    guard tag & 0x4000 != 0 else { return nil }
                    return Point(x: placed.x + cell % definition.columns * 8, y: placed.y + cell / definition.columns * 2)
                }
                traps.append(.init(id: index, cells: cells, frameCount: definition.frameCount,
                    startFrame: definition.animationStartFrame, frameDelay: definition.animationFrameDelay,
                    cyclePause: definition.animationCyclePause)); continue
            }
            guard [0, 0x1000, 0x1800, 0x0402, 0x4001].contains(definition.flags), placed.identifier < 5000 else {
                throw SequelDataError.invalid("Unsupported Chronicles object \(placed.identifier) (flags \(definition.flags)).")
            }
            let tags = try style.permanent.attributes(object: placed.identifier)
            for (index, tag) in tags.enumerated() {
                let x = placed.x + index % definition.columns * 8
                let y = placed.y + index / definition.columns * 2
                if definition.flags == 0x0402 && tag & 0x0400 != 0 {
                    entrances.append(Point(x: x + 4, y: y + 2))
                }
                if definition.flags == 0x4001 && tag & 0x4000 != 0 { exits.append(Point(x: x, y: y)) }
            }
        }
        guard let entrance = entrances.first else { throw SequelDataError.invalid("Missing Chronicles entrance trigger.") }
        guard extras.count == level.extraLemmings else { throw SequelDataError.invalid("Chronicles extra-lemming count does not match its placements.") }
        guard creatures.count == level.enemyCount else { throw SequelDataError.invalid("Chronicles creature count does not match its placements.") }
        try self.init(configuration: .init(width: level.width, height: level.height, attributes: scene.attributes,
            entrance: entrance, exits: exits, total: total, releaseInterval: level.releaseRate,
            releaseDelay: level.releaseDelay, timeLimit: level.timeLimitSeconds, pickups: pickups, extras: extras,
            backgroundAttributes: scene.backgroundAttributes, sourceLevelReference: level.permanentObjectsReference,
            traps: traps, creatures: creatures, additionalEntrances: Array(entrances.dropFirst())))
    }
    public func isSolid(_ x: Int, _ y: Int) -> Bool {
        x >= 0 && y >= 0 && x < configuration.width && y < configuration.height &&
        attributes[y * configuration.width + x] & 0x20 != 0
    }
    @discardableResult public mutating func assign(_ action: Action, to id: Int) -> Bool {
        guard !isComplete, let index = lemmings.firstIndex(where: { $0.id == id }) else { return false }
        if action == .walker && [.climbing, .shimmying].contains(lemmings[index].state) {
            lemmings[index].state = .falling; lemmings[index].age = 0; lemmings[index].fall = 0
            lemmings[index].mobilityTool = nil; lemmings[index].mobilityTicks = 0
            if isSolid(lemmings[index].x + lemmings[index].direction, lemmings[index].y - 1) { lemmings[index].direction *= -1 }
            return true
        }
        if action == .walker && lemmings[index].state == .swimming {
            // The native practice transcript requires a second aid to turn.
            guard lemmings[index].tool == .swimmer, lemmings[index].quantity >= 2 else { return false }
            lemmings[index].quantity -= 1; lemmings[index].direction *= -1; return true
        }
        guard
              [.walking, .blocking, .building, .digging].contains(lemmings[index].state), isSolid(lemmings[index].x, lemmings[index].y) else { return false }
        switch action {
        case .walker:
            if lemmings[index].state == .walking { lemmings[index].direction *= -1 }
            lemmings[index].state = .walking
        case .blocker:
            guard lemmings[index].state != .blocking else { return false }
            lemmings[index].state = .blocking
        case .jumper: lemmings[index].state = .jumping; lemmings[index].velocityY = -4
        case .use: return useTool(to: id, direction: lemmings[index].direction > 0 ? .right : .left)
        case .drop:
            guard let tool = lemmings[index].tool else { return false }
            var pickup = Pickup(id: nextPickupID, tool: tool, x: max(0, min(configuration.width - 8, lemmings[index].x - 4)),
                y: max(0, lemmings[index].y - 8), quantity: lemmings[index].quantity)
            nextPickupID += 1; pickup.ignoredBy = id; pickups.append(pickup)
            lemmings[index].tool = nil; lemmings[index].quantity = 0; lemmings[index].state = .walking
        }
        distract(index)
        lemmings[index].age = 0
        return true
    }
    private mutating func distract(_ index: Int) {
        guard let source = lemmings[index].charmedBy else { return }
        lemmings[index].charmedBy = nil; lemmings[index].charmTicks = 0
        lemmings[index].charmImmunity = 46
        if let creature = creatures.firstIndex(where: { $0.id == source }) { creatures[creature].target = nil }
    }
    public mutating func abort() {
        for index in lemmings.indices where lemmings[index].active { lemmings[index].state = .dead }
        isComplete = true
    }
    @discardableResult public mutating func useTool(to id: Int, direction: Direction) -> Bool {
        guard !isComplete, let index = lemmings.firstIndex(where: { $0.id == id }),
              [.walking, .blocking, .building, .digging].contains(lemmings[index].state),
              let tool = lemmings[index].tool, lemmings[index].quantity > 0,
              [.bricks, .spade, .sucker, .shimmy, .bomb, .grenade, .hadoken].contains(tool),
              isSolid(lemmings[index].x, lemmings[index].y), !(tool == .bricks && direction == .down) else { return false }
        if tool == .hadoken {
            distract(index)
            let lem = lemmings[index]
            fireballs.append(.init(x: lem.x, y: lem.y - 8, direction: lem.direction))
            lemmings[index].quantity -= 1
            if lemmings[index].quantity == 0 { lemmings[index].tool = nil }
            lemmings[index].state = .walking; lemmings[index].age = 0
            return true
        }
        if tool == .bomb || tool == .grenade {
            distract(index)
            let lem = lemmings[index]
            explosives.append(.init(id: nextExplosiveID, tool: tool, x: lem.x, y: lem.y - 1,
                velocityX: tool == .grenade ? lem.direction * 4 : 0, velocityY: tool == .grenade ? -4 : 0))
            nextExplosiveID += 1; lemmings[index].quantity -= 1
            if lemmings[index].quantity == 0 { lemmings[index].tool = nil }
            lemmings[index].state = .walking; lemmings[index].age = 0
            return true
        }
        if tool == .sucker || tool == .shimmy {
            guard lemmings[index].mobilityTool == nil else { return false }
            distract(index)
            lemmings[index].mobilityTool = tool; lemmings[index].mobilityTicks = 5 * Int(Self.ticksPerSecond)
            lemmings[index].quantity -= 1
            if lemmings[index].quantity == 0 { lemmings[index].tool = nil }
            lemmings[index].state = tool == .shimmy ? .jumping : .walking
            if tool == .shimmy { lemmings[index].velocityY = -4 }
            lemmings[index].age = 0
            return true
        }
        lemmings[index].workDirection = direction
        distract(index)
        if direction.dx != 0 { lemmings[index].direction = direction.dx }
        lemmings[index].state = tool == .bricks ? .building : .digging
        lemmings[index].age = 0
        return true
    }
    private func inBounds(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < configuration.width && y < configuration.height }
    private func isWater(_ x: Int, _ y: Int) -> Bool {
        inBounds(x, y) && attributes[y * configuration.width + x] & 0x800 != 0
    }
    private func consumeTool(_ lem: inout Lemming) {
        lem.quantity -= 1
        if lem.quantity == 0 { lem.tool = nil }
    }
    private mutating func work(_ lem: inout Lemming) {
        guard lem.age % 8 == 0 else { return }
        guard let tool = lem.tool, lem.quantity > 0 else { lem.state = .walking; return }
        let dx = lem.workDirection.dx, dy = lem.workDirection.dy
        // Eight-pixel work steps are provisional pending original-engine traces.
        let nx = lem.x + dx * 8, ny = lem.y + dy * 8
        let left = dx == 0 ? lem.x - 4 : (dx > 0 ? lem.x + 1 : nx)
        let top = tool == .bricks ? ny : (dy > 0 ? lem.y : ny - 16)
        let height = tool == .bricks ? 8 : (dy > 0 ? 8 : 16)
        let cells = (top..<(top + height)).flatMap { y in (left..<(left + 8)).map { (x: $0, y: y) } }
        guard inBounds(nx, ny), cells.allSatisfy({ inBounds($0.x, $0.y) }),
              !cells.contains(where: { configuration.backgroundAttributes[$0.y * configuration.width + $0.x] & 0x20 != 0 }) else {
            lem.state = .walking; return
        }
        if tool == .spade && !cells.contains(where: { isSolid($0.x, $0.y) }) { lem.state = .walking; return }
        if tool == .bricks && cells.allSatisfy({ isSolid($0.x, $0.y) }) { lem.state = .walking; return }
        if tool == .bricks && ((ny - 16)..<ny).contains(where: { isSolid(nx, $0) }) { lem.state = .walking; return }
        for cell in cells {
            let index = cell.y * configuration.width + cell.x
            attributes[index] = tool == .bricks ? 0x2020 : configuration.backgroundAttributes[index]
            terrainEdits[index] = tool == .bricks
        }
        lem.x = nx; lem.y = ny; lem.quantity -= 1
        if lem.quantity == 0 { lem.tool = nil; lem.state = .walking }
        if !isSolid(lem.x, lem.y) { lem.state = .falling; lem.fall = 0; lem.age = 0 }
    }
    private mutating func updateExplosives() {
        blasts.removeAll { tick - $0.tick >= 8 }
        for index in explosives.indices {
            var item = explosives[index]
            item.age += 1
            // Trajectory, bounce damping and blast radii are provisional.
            if item.velocityX != 0 {
                let dx = item.velocityX > 0 ? 1 : -1
                for _ in 0..<abs(item.velocityX) {
                    if !inBounds(item.x + dx, item.y) || isSolid(item.x + dx, item.y) { item.velocityX = -item.velocityX / 2; break }
                    item.x += dx
                }
            }
            if item.age % 2 == 0 { item.velocityY = min(4, item.velocityY + 1) }
            if item.velocityY != 0 {
                let dy = item.velocityY > 0 ? 1 : -1
                for _ in 0..<abs(item.velocityY) {
                    if isSolid(item.x, item.y + dy) {
                        item.velocityY = dy > 0 ? -item.velocityY / 2 : 0
                        if dy > 0 { item.velocityX /= 2 }
                        break
                    }
                    item.y += dy
                }
            }
            explosives[index] = item
            if item.age == item.fuseTicks && inBounds(item.x, item.y) {
                blasts.append(.init(x: item.x, y: item.y, tick: tick))
                for y in max(0, item.y - 20)...max(0, min(configuration.height - 1, item.y + 20)) {
                    for x in max(0, item.x - 20)...max(0, min(configuration.width - 1, item.x + 20)) {
                        let offset = y * configuration.width + x
                        if (x - item.x) * (x - item.x) + (y - item.y) * (y - item.y) <= 400,
                           attributes[offset] & 0x20 != 0, configuration.backgroundAttributes[offset] & 0x20 == 0 {
                            attributes[offset] = configuration.backgroundAttributes[offset]; terrainEdits[offset] = false
                        }
                    }
                }
                for lemIndex in lemmings.indices where lemmings[lemIndex].active && lemmings[lemIndex].state != .exiting {
                    let lem = lemmings[lemIndex]
                    if (lem.x - item.x) * (lem.x - item.x) + (lem.y - 8 - item.y) * (lem.y - 8 - item.y) <= 24 * 24 {
                        lemmings[lemIndex].state = .dead
                    }
                }
                for creatureIndex in creatures.indices where creatures[creatureIndex].alive {
                    let creature = creatures[creatureIndex]
                    let dx = creature.x - item.x, dy = creature.y - creature.height / 2 - item.y
                    if dx * dx + dy * dy <= 24 * 24 { killCreature(creatureIndex) }
                }
            }
        }
        explosives.removeAll { $0.age >= $0.fuseTicks || $0.y >= configuration.height || $0.y < -32 }
    }
    private mutating func updateFireballs() {
        // Travel speed, range and terrain collision remain provisional.
        for index in fireballs.indices {
            fireballs[index].age += 1
            for _ in 0..<4 {
                let nx = fireballs[index].x + fireballs[index].direction
                if !inBounds(nx, fireballs[index].y) || isSolid(nx, fireballs[index].y) {
                    fireballs[index].age = 64; break
                }
                fireballs[index].x = nx
                if let hit = creatures.firstIndex(where: { $0.alive && abs($0.x - nx) <= $0.width / 2 && fireballs[index].y >= $0.y - $0.height && fireballs[index].y < $0.y }) {
                    killCreature(hit); fireballs[index].age = 64; break
                }
            }
        }
        fireballs.removeAll { $0.age >= 64 }
    }
    private mutating func killCreature(_ index: Int) {
        creatures[index].alive = false
        for lemIndex in lemmings.indices where lemmings[lemIndex].charmedBy == creatures[index].id { distract(lemIndex) }
        creatures[index].target = nil
    }
    private mutating func updateCreatures() {
        // Patrol speed, ranges, attack delays and charm duration are provisional.
        for index in creatures.indices where creatures[index].alive {
            var creature = creatures[index]
            creature.age += 1; creature.cooldown = max(0, creature.cooldown - 1)
            if creature.age % 2 == 0 {
                if creature.kind == .mole {
                    if creature.age % 8 == 0 { moveMole(&creature) }
                } else if creature.kind == .buzzard {
                    let target = lemmings.filter { $0.active && ![.exiting, .drowning, .trapped].contains($0.state) }
                        .min { abs($0.x - creature.x) + abs($0.y - creature.y) < abs($1.x - creature.x) + abs($1.y - creature.y) }
                    if let target, abs(target.x - creature.x) + abs(target.y - creature.y) <= 160 {
                        if target.x != creature.x { creature.direction = target.x > creature.x ? 1 : -1 }
                        let dy = target.y == creature.y ? 0 : (target.y > creature.y ? 1 : -1)
                        if !isSolid(creature.x, creature.y + dy - 1) { creature.y += dy }
                    }
                    let nx = creature.x + creature.direction
                    if nx < 0 || nx >= configuration.width || isSolid(nx, creature.y - 1) { creature.direction *= -1 }
                    else { creature.x = nx }
                } else if !isSolid(creature.x, creature.y) {
                    creature.y += 1
                } else {
                    let nx = creature.x + creature.direction
                    if nx < 0 || nx >= configuration.width { creature.direction *= -1 }
                    else if isSolid(nx, creature.y - 1) {
                        if let rise = (1...4).first(where: { isSolid(nx, creature.y - $0) && !isSolid(nx, creature.y - $0 - 1) }) {
                            creature.x = nx; creature.y -= rise
                        } else { creature.direction *= -1 }
                    } else { creature.x = nx }
                }
            }
            if creature.y >= configuration.height || isWater(creature.x, creature.y - 1) {
                creatures[index] = creature; killCreature(index); continue
            }
            if creature.kind == .fatale {
                if let target = creature.target, !lemmings.contains(where: { $0.id == target && $0.active && $0.charmedBy == creature.id && $0.state == .walking }) {
                    if let lem = lemmings.firstIndex(where: { $0.id == target }) { distract(lem) }
                    creature.target = nil
                }
                if creature.target == nil, let target = lemmings.firstIndex(where: {
                    $0.state == .walking && $0.charmedBy == nil && $0.charmImmunity == 0 && abs($0.x - creature.x) <= 64 && abs($0.y - creature.y) <= 24
                }) {
                    creature.target = lemmings[target].id
                    lemmings[target].charmedBy = creature.id; lemmings[target].charmTicks = 115
                }
                if let target = creature.target, let lem = lemmings.firstIndex(where: { $0.id == target }) {
                    lemmings[lem].charmTicks -= 1
                    if lemmings[lem].x != creature.x { lemmings[lem].direction = creature.x > lemmings[lem].x ? 1 : -1 }
                    if lemmings[lem].charmTicks <= 0 {
                        lemmings[lem].state = .dead; lemmings[lem].charmedBy = nil; creature.target = nil
                    }
                }
            } else if creature.kind != .mole && creature.cooldown == 0, let victim = lemmings.firstIndex(where: {
                $0.active && ![.exiting, .drowning, .trapped].contains($0.state) && abs($0.x - creature.x) <= 12 && abs($0.y - creature.y) <= 16
            }) {
                lemmings[victim].state = .dead; creature.cooldown = 23
            }
            creatures[index] = creature
        }
    }
    private mutating func moveMole(_ creature: inout Creature) {
        // Dig masks, movement rate and clockwise steering are provisional.
        let direction = creature.digDirection
        let nx = creature.x + direction.dx * 2, ny = creature.y + direction.dy * 2
        let cells = ((ny - 16)..<ny).flatMap { y in ((nx - 4)..<(nx + 4)).map { (x: $0, y: y) } }
        let blocked = cells.contains { cell in
            !inBounds(cell.x, cell.y) ||
            configuration.backgroundAttributes[cell.y * configuration.width + cell.x] & 0x20 != 0 ||
            attributes[cell.y * configuration.width + cell.x] & 0x2000 != 0
        }
        if blocked {
            switch direction {
            case .right: creature.digDirection = .down
            case .down: creature.digDirection = .left
            case .left: creature.digDirection = .up
            default: creature.digDirection = .right
            }
            if creature.digDirection.dx != 0 { creature.direction = creature.digDirection.dx }
            return
        }
        if direction.dy == 0 && !isSolid(creature.x, creature.y) && !cells.contains(where: { isSolid($0.x, $0.y) }) {
            creature.y += 2; return
        }
        for cell in cells where isSolid(cell.x, cell.y) {
            let index = cell.y * configuration.width + cell.x
            attributes[index] = configuration.backgroundAttributes[index]; terrainEdits[index] = false
        }
        creature.x = nx; creature.y = ny
    }
    public mutating func step() {
        guard !isComplete else { return }
        tick += 1
        updateExplosives()
        updateFireballs()
        updateCreatures()
        if released < releaseTarget && tick >= configuration.releaseDelay && (tick - configuration.releaseDelay) % configuration.releaseInterval == 0 {
            // Shared release count with round-robin hatches is provisional.
            let entrances = [configuration.entrance] + configuration.additionalEntrances
            let entrance = entrances[released % entrances.count]
            lemmings.append(Lemming(id: configuration.extras.count + released, x: entrance.x, y: entrance.y)); released += 1
        }
        for index in lemmings.indices where lemmings[index].active {
            var lem = lemmings[index]
            lem.charmImmunity = max(0, lem.charmImmunity - 1)
            if lem.mobilityTicks > 0 {
                lem.mobilityTicks -= 1
                if lem.mobilityTicks == 0 {
                    lem.mobilityTool = nil
                    if [.climbing, .shimmying].contains(lem.state) { lem.state = .falling; lem.age = 0; lem.fall = 0 }
                }
            }
            if [.walking, .falling, .floating, .jumping, .swimming].contains(lem.state) {
                for pickupIndex in pickups.indices where pickups[pickupIndex].quantity > 0 {
                    let box = pickups[pickupIndex]
                    let overlaps = lem.x >= box.x && lem.x < box.x + 8 && lem.y > box.y && lem.y <= box.y + 12
                    if box.ignoredBy == lem.id {
                        if !overlaps { pickups[pickupIndex].ignoredBy = nil }
                        continue
                    }
                    if overlaps && box.tool == .clock {
                        bonusSeconds += 60 * box.quantity; pickups[pickupIndex].quantity = 0; continue
                    }
                    if overlaps && (lem.tool == nil || lem.tool == box.tool) {
                        lem.tool = box.tool; lem.quantity += box.quantity; pickups[pickupIndex].quantity = 0
                    }
                }
            }
            if ![.saved, .dead, .exiting, .drowning, .trapped].contains(lem.state),
               inBounds(lem.x, lem.y - 1), attributes[(lem.y - 1) * configuration.width + lem.x] & 0x4000 != 0 {
                for trap in configuration.traps {
                    if let start = trapStarted[trap.id], tick - start < trap.cycleTicks { continue }
                    if trap.cells.contains(where: { lem.x >= $0.x && lem.x < $0.x + 8 && lem.y - 1 >= $0.y && lem.y - 1 < $0.y + 2 }) {
                        trapStarted[trap.id] = tick; lem.state = .trapped; lem.age = 0
                        lem.trapTicks = trap.cycleTicks; break
                    }
                }
            }
            if ![.saved, .dead, .exiting, .drowning, .swimming, .trapped].contains(lem.state), isWater(lem.x, lem.y) {
                lem.state = lem.tool == .swimmer ? .swimming : .drowning; lem.age = 0
                if lem.state == .swimming { lem.swimTicks = 5 * Int(Self.ticksPerSecond) }
            }
            if lem.state == .falling && lem.tool == .umbrella && lem.fall >= 16 {
                lem.state = .floating; lem.age = 0
            }
            if lem.state == .walking && configuration.exits.contains(where: { lem.x >= $0.x && lem.x < $0.x + 8 && lem.y - 1 >= $0.y && lem.y - 1 < $0.y + 2 }) {
                lem.state = .exiting; lem.age = 0
            }
            switch lem.state {
            case .walking:
                let nx = lem.x + lem.direction
                if lemmings.contains(where: { $0.state == .blocking && $0.id != lem.id && abs($0.y - lem.y) < 5 && abs($0.x - nx) < 9 && ($0.x - lem.x) * lem.direction > 0 }) {
                    lem.direction *= -1
                } else if isSolid(nx, lem.y - 1) {
                    if let rise = (1...4).first(where: { isSolid(nx, lem.y - $0) && !isSolid(nx, lem.y - $0 - 1) }) { lem.x = nx; lem.y -= rise }
                    else if lem.mobilityTool == .sucker { lem.state = .climbing; lem.age = 0 }
                    else { lem.direction *= -1 }
                } else {
                    lem.x = nx
                    if let drop = (0...3).first(where: { isSolid(nx, lem.y + $0) }) { lem.y += drop }
                    else { lem.state = .falling; lem.age = 0; lem.fall = 0 }
                }
            case .falling:
                for _ in 0..<min(4, 1 + lem.age / 3) {
                    if isSolid(lem.x, lem.y) {
                        lem.state = lem.fall > 96 ? .dead : .walking; lem.age = 0; lem.fall = 0; break
                    }
                    lem.y += 1; lem.fall += 1
                }
            case .floating:
                if isSolid(lem.x, lem.y) {
                    consumeTool(&lem); lem.state = .walking; lem.age = 0; lem.fall = 0
                } else { lem.y += 1; lem.fall += 1 }
            case .swimming:
                lem.swimTicks -= 1
                if lem.swimTicks <= 0 {
                    consumeTool(&lem)
                    if lem.tool == .swimmer { lem.swimTicks = 5 * Int(Self.ticksPerSecond) }
                    else { lem.state = .drowning; lem.age = 0 }
                }
                if lem.state == .swimming {
                    let nx = lem.x + lem.direction
                    if !isSolid(nx, lem.y - 1) { lem.x = nx }
                    else if let rise = (1...4).first(where: { isSolid(nx, lem.y - $0) && !isSolid(nx, lem.y - $0 - 1) }) {
                        lem.x = nx; lem.y -= rise
                    } else { lem.direction *= -1 }
                    if !isWater(lem.x, lem.y) {
                        lem.state = isSolid(lem.x, lem.y) ? .walking : .falling; lem.age = 0; lem.fall = 0
                        consumeTool(&lem); lem.swimTicks = 0
                    }
                }
            case .climbing:
                let nx = lem.x + lem.direction
                if isSolid(lem.x, lem.y - 17) {
                    lem.state = .falling; lem.direction *= -1; lem.age = 0; lem.fall = 0
                } else if !isSolid(nx, lem.y - 1) {
                    lem.x = nx; lem.state = .walking; lem.age = 0
                } else { lem.y -= 1 }
            case .shimmying:
                let nx = lem.x + lem.direction
                if !isSolid(nx, lem.y - 16) || isSolid(nx, lem.y - 15) {
                    lem.state = .falling; lem.age = 0; lem.fall = 0
                    lem.mobilityTool = nil; lem.mobilityTicks = 0
                } else { lem.x = nx }
            case .jumping:
                let nx = lem.x + (lem.mobilityTool == .shimmy ? 0 : lem.direction * 2)
                if !isSolid(nx, lem.y - 8) { lem.x = nx }
                else { lem.direction *= -1 }
                let dy = lem.velocityY < 0 ? -1 : 1
                for _ in 0..<abs(lem.velocityY) {
                    if dy > 0 && isSolid(lem.x, lem.y) { lem.state = .walking; lem.age = 0; break }
                    if dy < 0 && isSolid(lem.x, lem.y - 16) {
                        if lem.mobilityTool == .shimmy { lem.state = .shimmying; lem.age = 0 }
                        lem.velocityY = 0; break
                    }
                    lem.y += dy
                }
                if lem.state == .jumping && lem.mobilityTool == .shimmy && lem.velocityY <= 0 && isSolid(lem.x, lem.y - 16) {
                    lem.state = .shimmying; lem.age = 0; lem.velocityY = 0
                }
                if lem.age % 2 == 0 { lem.velocityY = min(4, lem.velocityY + 1) }
                if lem.state == .jumping && lem.age > 24 { lem.state = .falling; lem.fall = 0; lem.age = 0 }
            case .blocking:
                if !isSolid(lem.x, lem.y) { lem.state = .falling; lem.fall = 0; lem.age = 0 }
            case .building, .digging: work(&lem)
            case .drowning: if lem.age >= 3 * Int(Self.ticksPerSecond) { lem.state = .dead }
            case .trapped: if lem.age >= lem.trapTicks { lem.state = .dead }
            case .exiting: if lem.age >= 8 { lem.state = .saved }
            case .saved, .dead: break
            }
            if lem.x < 0 || lem.x >= configuration.width || lem.y < -32 || lem.y >= configuration.height { lem.state = .dead }
            lem.age += 1; lemmings[index] = lem
        }
        if remainingSeconds == 0 { abort() }
        if released >= releaseTarget && !lemmings.contains(where: \.active) { isComplete = true }
    }
}
