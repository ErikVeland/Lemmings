import Foundation

/// Native gameplay model. This is intentionally independent of the DOS
/// simulation and uses floating-point world coordinates and a modern fixed
/// timestep suitable for SpriteKit/AppKit rendering.
public enum ModernSkill: String, CaseIterable, Codable, Sendable {
    case climber, floater, blocker, builder, basher, miner, digger, bomber
}

public enum ModernLemmingState: String, Codable, Sendable {
    case falling, walking, climbing, floating, blocking, building, digging
    case bashing, mining, exploding, exiting, dead
}

public struct ModernPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct ModernRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public func contains(_ point: ModernPoint) -> Bool {
        point.x >= x && point.x < x + width && point.y >= y && point.y < y + height
    }
}

public struct ModernTerrain: Codable, Equatable, Sendable {
    public let bounds: ModernRect
    public private(set) var solids: [ModernRect]
    public private(set) var steel: [ModernRect]

    public init(bounds: ModernRect, solids: [ModernRect] = [], steel: [ModernRect] = []) {
        self.bounds = bounds; self.solids = solids; self.steel = steel
    }

    public mutating func addSolid(_ rect: ModernRect, steel: Bool = false) {
        solids.append(rect); if steel { self.steel.append(rect) }
    }

    public func isSolid(at point: ModernPoint) -> Bool {
        solids.contains { $0.contains(point) }
    }

    public func isSteel(at point: ModernPoint) -> Bool {
        steel.contains { $0.contains(point) }
    }

    public mutating func removeTerrain(in rect: ModernRect) {
        let protected = steel
        var result: [ModernRect] = []
        for candidate in solids {
            guard Self.overlaps(candidate, rect), !protected.contains(candidate) else { result.append(candidate); continue }
            let left = rect.x - candidate.x
            let right = candidate.x + candidate.width - (rect.x + rect.width)
            let bottom = rect.y - candidate.y
            let top = candidate.y + candidate.height - (rect.y + rect.height)
            if left > 0 { result.append(ModernRect(x: candidate.x, y: candidate.y, width: left, height: candidate.height)) }
            if right > 0 { result.append(ModernRect(x: rect.x + rect.width, y: candidate.y, width: right, height: candidate.height)) }
            let middleWidth = max(0, min(candidate.x + candidate.width, rect.x + rect.width) - max(candidate.x, rect.x))
            if bottom > 0 { result.append(ModernRect(x: max(candidate.x, rect.x), y: candidate.y, width: middleWidth, height: bottom)) }
            if top > 0 { result.append(ModernRect(x: max(candidate.x, rect.x), y: rect.y + rect.height, width: middleWidth, height: top)) }
        }
        solids = result.filter { $0.width > 0 && $0.height > 0 }
    }

    private static func overlaps(_ a: ModernRect, _ b: ModernRect) -> Bool {
        a.x < b.x + b.width && a.x + a.width > b.x && a.y < b.y + b.height && a.y + a.height > b.y
    }
}

public struct ModernLemming: Identifiable, Codable, Equatable, Sendable {
    public let id: Int
    public var position: ModernPoint
    public var velocity: ModernPoint
    public var direction: Double
    public var state: ModernLemmingState
    public var skills: Set<ModernSkill>
    public var actionTime: Double
    public var fallDistance: Double
    public var bricksRemaining: Int
}

public struct ModernLevel: Codable, Equatable, Sendable {
    public var bounds: ModernRect
    public var spawn: ModernPoint
    public var exit: ModernRect
    public var totalLemmings: Int
    public var requiredToSave: Int
    public var spawnInterval: Double
    public var timeLimit: Double?
    public var terrain: ModernTerrain
    public var skillInventory: [ModernSkill: Int]

    public init(bounds: ModernRect, spawn: ModernPoint, exit: ModernRect,
                totalLemmings: Int, requiredToSave: Int, spawnInterval: Double,
                terrain: ModernTerrain, skillInventory: [ModernSkill: Int] = [:], timeLimit: Double? = nil) {
        self.bounds = bounds; self.spawn = spawn; self.exit = exit
        self.totalLemmings = totalLemmings; self.requiredToSave = requiredToSave
        self.spawnInterval = max(0.05, spawnInterval); self.terrain = terrain
        self.timeLimit = timeLimit
        self.skillInventory = skillInventory
    }
}

public struct ModernLemmingsEngine: Sendable {
    public private(set) var level: ModernLevel
    public private(set) var lemmings: [ModernLemming] = []
    public private(set) var elapsed: Double = 0
    public private(set) var spawned = 0
    public private(set) var saved = 0
    public private(set) var dead = 0
    private var nextSpawn: Double = 0

    public var isComplete: Bool { saved + dead >= level.totalLemmings || level.timeLimit.map { elapsed >= $0 } == true }
    public var didWin: Bool { isComplete && saved >= level.requiredToSave }

    public init(level: ModernLevel) { self.level = level }

    public mutating func reset() {
        lemmings.removeAll(keepingCapacity: true)
        elapsed = 0; spawned = 0; saved = 0; dead = 0; nextSpawn = 0
    }

    public mutating func nuke() {
        for index in lemmings.indices where lemmings[index].state != .dead && lemmings[index].state != .exiting {
            lemmings[index].state = .exploding
            lemmings[index].actionTime = 1.0
        }
    }

    public mutating func update(deltaTime: Double) {
        guard deltaTime > 0, !isComplete else { return }
        let dt = min(deltaTime, 0.1)
        elapsed += dt; nextSpawn -= dt
        while spawned < level.totalLemmings && nextSpawn <= 0 {
            spawn()
            nextSpawn += level.spawnInterval
        }
        for index in lemmings.indices where lemmings[index].state != .dead && lemmings[index].state != .exiting {
            step(index: index, deltaTime: dt)
        }
    }

    @discardableResult
    public mutating func assign(_ skill: ModernSkill, to id: Int) -> Bool {
        guard let count = level.skillInventory[skill], count > 0,
              let index = lemmings.firstIndex(where: { $0.id == id }),
              lemmings[index].state == .walking else { return false }
        level.skillInventory[skill] = count - 1
        lemmings[index].skills.insert(skill)
        switch skill {
        case .blocker: lemmings[index].state = .blocking
        case .builder: lemmings[index].state = .building
        case .basher: lemmings[index].state = .bashing
        case .miner: lemmings[index].state = .mining
        case .digger: lemmings[index].state = .digging
        case .bomber: lemmings[index].state = .exploding; lemmings[index].actionTime = 3
        default: break
        }
        return true
    }

    private mutating func spawn() {
        lemmings.append(ModernLemming(id: spawned, position: level.spawn,
                                      velocity: ModernPoint(x: 0, y: 0), direction: 1,
                                      state: .falling, skills: [], actionTime: 0,
                                      fallDistance: 0, bricksRemaining: 20))
        spawned += 1
    }

    private mutating func step(index: Int, deltaTime dt: Double) {
        var lemming = lemmings[index]
        if level.exit.contains(lemming.position) { lemming.state = .exiting; saved += 1; lemmings[index] = lemming; return }
        switch lemming.state {
        case .falling, .floating:
            let gravity = lemming.skills.contains(.floater) ? 140.0 : 420.0
            lemming.velocity.y += gravity * dt
            lemming.position.y += lemming.velocity.y * dt
            lemming.fallDistance += abs(lemming.velocity.y * dt)
            if terrainFloor(at: lemming.position) {
                if lemming.fallDistance > 180 && !lemming.skills.contains(.floater) { lemming.state = .dead; dead += 1 }
                else { lemming.state = .walking; lemming.velocity.y = 0; lemming.fallDistance = 0 }
            }
        case .walking:
            let next = ModernPoint(x: lemming.position.x + lemming.direction * 42 * dt, y: lemming.position.y)
            if lemmings.contains(where: { $0.id != lemming.id && $0.state == .blocking && abs($0.position.x - lemming.position.x) < 14 && abs($0.position.y - lemming.position.y) < 12 }) { lemming.direction *= -1 }
            else if level.terrain.isSolid(at: ModernPoint(x: next.x, y: next.y - 8)) {
                if lemming.skills.contains(.climber) && !level.terrain.isSolid(at: ModernPoint(x: lemming.position.x, y: lemming.position.y - 18)) { lemming.state = .climbing }
                else { lemming.direction *= -1 }
            }
            else { lemming.position = next }
            if !terrainFloor(at: lemming.position) { lemming.state = .falling }
        case .climbing:
            lemming.position.y -= 34 * dt
            if !level.terrain.isSolid(at: ModernPoint(x: lemming.position.x + lemming.direction * 8, y: lemming.position.y - 8)) { lemming.state = .walking }
        case .building:
            lemming.actionTime += dt
            if lemming.actionTime >= 0.18 {
                level.terrain.addSolid(ModernRect(x: lemming.position.x + lemming.direction * 10, y: lemming.position.y - 10, width: 16, height: 5))
                lemming.position.x += lemming.direction * 8
                lemming.bricksRemaining -= 1
                lemming.actionTime = 0
            }
            if lemming.bricksRemaining <= 0 { lemming.state = .walking }
        case .bashing, .mining, .digging:
            lemming.actionTime += dt
            if lemming.actionTime >= 0.12 {
                let width = lemming.state == .digging ? 18.0 : 28.0
                let y = lemming.state == .digging ? lemming.position.y : lemming.position.y - 12
                level.terrain.removeTerrain(in: ModernRect(x: lemming.position.x - width / 2, y: y, width: width, height: 24))
                lemming.actionTime = 0
                if lemming.state == .digging { lemming.position.y += 4 }
                else { lemming.position.x += lemming.direction * 5 }
            }
        case .exploding:
            lemming.actionTime -= dt
            if lemming.actionTime <= 0 { level.terrain.removeTerrain(in: ModernRect(x: lemming.position.x - 32, y: lemming.position.y - 32, width: 64, height: 64)); lemming.state = .dead; dead += 1 }
        case .blocking, .exiting, .dead: break
        }
        if lemming.position.y > level.bounds.y + level.bounds.height + 40 { lemming.state = .dead; dead += 1 }
        lemmings[index] = lemming
    }

    private func terrainFloor(at point: ModernPoint) -> Bool {
        level.terrain.isSolid(at: ModernPoint(x: point.x, y: point.y + 10))
    }
}
