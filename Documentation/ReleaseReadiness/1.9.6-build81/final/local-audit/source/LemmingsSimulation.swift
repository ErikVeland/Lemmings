import Foundation

public struct PixelPoint: Equatable, Sendable {
    public var x: Int
    public var y: Int
    public init(x: Int, y: Int) { self.x = x; self.y = y }
}

public struct TerrainMask: Sendable {
    public let width: Int
    public let height: Int
    private var pixels: [Bool]

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        pixels = Array(repeating: false, count: width * height)
    }

    public subscript(x: Int, y: Int) -> Bool {
        get {
            guard x >= 0, y >= 0, x < width, y < height else { return false }
            return pixels[y * width + x]
        }
        set {
            guard x >= 0, y >= 0, x < width, y < height else { return }
            pixels[y * width + x] = newValue
        }
    }

    public mutating func fill(x: Range<Int>, y: Range<Int>, solid: Bool = true) {
        for py in y where py >= 0 && py < height {
            for px in x where px >= 0 && px < width { self[px, py] = solid }
        }
    }
}

public enum LemmingAction: String, Sendable {
    case falling
    case walking
    case exited
    case lost
}

public struct SimulatedLemming: Identifiable, Sendable {
    public let id: Int
    public var position: PixelPoint
    public var direction: Int
    public var action: LemmingAction
    public var fallDistance: Int
}

public struct SimulationConfiguration: Sendable {
    public var totalLemmings: Int
    public var requiredToSave: Int
    public var spawnIntervalTicks: Int
    public var entrance: PixelPoint
    public var exitX: Range<Int>
    public var exitY: Range<Int>

    public init(totalLemmings: Int, requiredToSave: Int, spawnIntervalTicks: Int,
                entrance: PixelPoint, exitX: Range<Int>, exitY: Range<Int>) {
        self.totalLemmings = totalLemmings
        self.requiredToSave = requiredToSave
        self.spawnIntervalTicks = max(1, spawnIntervalTicks)
        self.entrance = entrance
        self.exitX = exitX
        self.exitY = exitY
    }
}

public struct LemmingsSimulation: Sendable {
    public var terrain: TerrainMask
    public private(set) var lemmings: [SimulatedLemming] = []
    public private(set) var tickCount = 0
    public private(set) var spawned = 0
    public private(set) var saved = 0
    public private(set) var lost = 0
    public let configuration: SimulationConfiguration

    public var isComplete: Bool { saved + lost == configuration.totalLemmings }
    public var didWin: Bool { isComplete && saved >= configuration.requiredToSave }

    public init(terrain: TerrainMask, configuration: SimulationConfiguration) {
        self.terrain = terrain
        self.configuration = configuration
    }

    public mutating func tick() {
        if spawned < configuration.totalLemmings,
           tickCount % configuration.spawnIntervalTicks == 0 {
            lemmings.append(SimulatedLemming(
                id: spawned,
                position: configuration.entrance,
                direction: 1,
                action: .falling,
                fallDistance: 0
            ))
            spawned += 1
        }

        for index in lemmings.indices {
            guard lemmings[index].action != .exited, lemmings[index].action != .lost else { continue }
            updateLemming(at: index)
        }
        tickCount += 1
    }

    private mutating func updateLemming(at index: Int) {
        var lemming = lemmings[index]
        let x = lemming.position.x
        let y = lemming.position.y

        if configuration.exitX.contains(x), configuration.exitY.contains(y) {
            lemming.action = .exited
            saved += 1
            lemmings[index] = lemming
            return
        }

        if y >= terrain.height + 8 || x < -8 || x >= terrain.width + 8 {
            lemming.action = .lost
            lost += 1
            lemmings[index] = lemming
            return
        }

        if !terrain[x, y + 1] {
            lemming.position.y += 1
            lemming.action = .falling
            lemming.fallDistance += 1
        } else {
            lemming.action = .walking
            lemming.fallDistance = 0
            let nextX = x + lemming.direction
            if terrain[nextX, y] {
                if !terrain[nextX, y - 1] {
                    lemming.position = PixelPoint(x: nextX, y: y - 1)
                } else {
                    lemming.direction *= -1
                }
            } else {
                lemming.position.x = nextX
            }
        }
        lemmings[index] = lemming
    }
}
