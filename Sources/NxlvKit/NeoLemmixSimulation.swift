import Foundation

// MARK: - Public value types

public enum NeoLemmixSimulationError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidDimensions(width: Int, height: Int)
    case invalidMask(name: String, expected: Int, actual: Int)
    case invalidOneWayValue(index: Int, value: UInt8)
    case invalidConfiguration(String)

    public var description: String {
        switch self {
        case let .invalidDimensions(width, height):
            "The simulation dimensions are invalid: \(width) by \(height)."
        case let .invalidMask(name, expected, actual):
            "The \(name) mask has \(actual) bytes. It needs \(expected) bytes."
        case let .invalidOneWayValue(index, value):
            "The one-way mask has invalid value \(value) at index \(index)."
        case let .invalidConfiguration(message):
            message
        }
    }
}

public struct NeoLemmixPoint: Codable, Equatable, Hashable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public struct NeoLemmixRect: Codable, Equatable, Hashable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = max(0, width)
        self.height = max(0, height)
    }

    public func contains(_ point: NeoLemmixPoint) -> Bool {
        point.x >= x && point.x < x + width && point.y >= y && point.y < y + height
    }
}

public enum NeoLemmixDirection: Int, Codable, CaseIterable, Sendable {
    case left = -1
    case right = 1

    public var opposite: NeoLemmixDirection {
        self == .left ? .right : .left
    }
}

public enum NeoLemmixOneWayDirection: UInt8, Codable, CaseIterable, Sendable {
    case none = 0
    case left = 1
    case right = 2
    case up = 3
    case down = 4
}

public enum NeoLemmixSkill: String, Codable, CaseIterable, Sendable {
    case walker
    case jumper
    case shimmier
    case slider
    case climber
    case swimmer
    case floater
    case glider
    case disarmer
    case bomber
    case stoner
    case blocker
    case platformer
    case builder
    case stacker
    case laserer
    case basher
    case fencer
    case miner
    case digger
    case cloner

    public init(_ skill: NxlvSkill) {
        self = NeoLemmixSkill(rawValue: skill.rawValue) ?? .walker
    }
}

public enum NeoLemmixSkillSupply: Codable, Equatable, Sendable {
    case finite(Int)
    case infinite

    public var availableCount: Int? {
        switch self {
        case let .finite(count): max(0, count)
        case .infinite: nil
        }
    }
}

public enum NeoLemmixTrait: String, Codable, CaseIterable, Sendable {
    case shimmier
    case slider
    case climber
    case swimmer
    case floater
    case glider
    case disarmer
    case blocker
    case zombie
    case neutral

    public init(_ trait: NxlvLemmingTrait) {
        self = NeoLemmixTrait(rawValue: trait.rawValue) ?? .neutral
    }
}

public enum NeoLemmixAction: String, Codable, CaseIterable, Sendable {
    case walking
    case ascending
    case falling
    case climbing
    case hoisting
    case floating
    case gliding
    case dehoisting
    case sliding
    case swimming
    case blocking
    case building
    case platforming
    case stacking
    case bashing
    case mining
    case digging
    case jumping
    case reaching
    case shimmying
    case disarming
    case shrugging
    case ohNo
    case stoning
    case exploding
    case stoneFinish
    case splatting
    case exiting
    case drowning
    case vaporizing
    case removed
}

public enum NeoLemmixRemovalReason: String, Codable, Sendable {
    case saved
    case splatted
    case drowned
    case burned
    case trapped
    case exploded
    case stoned
    case fellOut
    case timeExpired
}

public enum NeoLemmixZoneEffect: String, Codable, Sendable {
    case exit
    case water
    case fire
    case trap
    case oneShotTrap
}

public struct NeoLemmixZone: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let effect: NeoLemmixZoneEffect
    public let bounds: NeoLemmixRect
    public let isDisarmable: Bool

    public init(
        id: Int,
        effect: NeoLemmixZoneEffect,
        bounds: NeoLemmixRect,
        isDisarmable: Bool = false
    ) {
        self.id = id
        self.effect = effect
        self.bounds = bounds
        self.isDisarmable = isDisarmable
    }
}

public struct NeoLemmixEntrance: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let position: NeoLemmixPoint
    public let direction: NeoLemmixDirection
    public let traits: Set<NeoLemmixTrait>
    public let lemmingLimit: Int?

    public init(
        id: Int,
        position: NeoLemmixPoint,
        direction: NeoLemmixDirection = .right,
        traits: Set<NeoLemmixTrait> = [],
        lemmingLimit: Int? = nil
    ) {
        self.id = id
        self.position = position
        self.direction = direction
        self.traits = traits
        self.lemmingLimit = lemmingLimit.map { max(0, $0) }
    }
}

public struct NeoLemmixPreplacedLemming: Codable, Equatable, Sendable {
    public let position: NeoLemmixPoint
    public let direction: NeoLemmixDirection
    public let traits: Set<NeoLemmixTrait>

    public init(
        position: NeoLemmixPoint,
        direction: NeoLemmixDirection = .right,
        traits: Set<NeoLemmixTrait> = []
    ) {
        self.position = position
        self.direction = direction
        self.traits = traits
    }
}

public struct NeoLemmixTerrain: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    public private(set) var solidMask: [UInt8]
    public private(set) var steelMask: [UInt8]
    public private(set) var oneWayMask: [UInt8]

    public init(
        width: Int,
        height: Int,
        solidMask: [UInt8],
        steelMask: [UInt8],
        oneWayMask: [UInt8]
    ) throws {
        guard width > 0, height > 0, width <= Int.max / height else {
            throw NeoLemmixSimulationError.invalidDimensions(width: width, height: height)
        }
        let count = width * height
        guard solidMask.count == count else {
            throw NeoLemmixSimulationError.invalidMask(
                name: "solid",
                expected: count,
                actual: solidMask.count
            )
        }
        guard steelMask.count == count else {
            throw NeoLemmixSimulationError.invalidMask(
                name: "steel",
                expected: count,
                actual: steelMask.count
            )
        }
        guard oneWayMask.count == count else {
            throw NeoLemmixSimulationError.invalidMask(
                name: "one-way",
                expected: count,
                actual: oneWayMask.count
            )
        }
        if let invalid = oneWayMask.enumerated().first(where: {
            NeoLemmixOneWayDirection(rawValue: $0.element) == nil
        }) {
            throw NeoLemmixSimulationError.invalidOneWayValue(
                index: invalid.offset,
                value: invalid.element
            )
        }
        self.width = width
        self.height = height
        self.solidMask = solidMask.map { $0 == 0 ? 0 : 1 }
        self.steelMask = steelMask.map { $0 == 0 ? 0 : 1 }
        self.oneWayMask = oneWayMask
    }

    public init(width: Int, height: Int) throws {
        guard width > 0, height > 0, width <= Int.max / height else {
            throw NeoLemmixSimulationError.invalidDimensions(width: width, height: height)
        }
        let count = width * height
        try self.init(
            width: width,
            height: height,
            solidMask: Array(repeating: 0, count: count),
            steelMask: Array(repeating: 0, count: count),
            oneWayMask: Array(repeating: 0, count: count)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case width
        case height
        case solidMask
        case steelMask
        case oneWayMask
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            width: container.decode(Int.self, forKey: .width),
            height: container.decode(Int.self, forKey: .height),
            solidMask: container.decode([UInt8].self, forKey: .solidMask),
            steelMask: container.decode([UInt8].self, forKey: .steelMask),
            oneWayMask: container.decode([UInt8].self, forKey: .oneWayMask)
        )
    }

    public func contains(x: Int, y: Int) -> Bool {
        x >= 0 && y >= 0 && x < width && y < height
    }

    public func isSolid(x: Int, y: Int) -> Bool {
        guard contains(x: x, y: y) else { return false }
        return solidMask[y * width + x] != 0
    }

    public func isSteel(x: Int, y: Int) -> Bool {
        guard contains(x: x, y: y) else { return false }
        return steelMask[y * width + x] != 0
    }

    public func oneWayDirection(x: Int, y: Int) -> NeoLemmixOneWayDirection {
        guard contains(x: x, y: y) else { return .none }
        return NeoLemmixOneWayDirection(rawValue: oneWayMask[y * width + x]) ?? .none
    }

    @discardableResult
    public mutating func setSolid(_ solid: Bool, x: Int, y: Int) -> Bool {
        guard contains(x: x, y: y) else { return false }
        let index = y * width + x
        let value: UInt8 = solid ? 1 : 0
        guard solidMask[index] != value else { return false }
        solidMask[index] = value
        if !solid {
            steelMask[index] = 0
            oneWayMask[index] = NeoLemmixOneWayDirection.none.rawValue
        }
        return true
    }

    @discardableResult
    public mutating func setSteel(_ steel: Bool, x: Int, y: Int) -> Bool {
        guard contains(x: x, y: y) else { return false }
        let index = y * width + x
        let value: UInt8 = steel ? 1 : 0
        guard steelMask[index] != value else { return false }
        steelMask[index] = value
        if steel { solidMask[index] = 1 }
        return true
    }

    @discardableResult
    public mutating func setOneWay(
        _ direction: NeoLemmixOneWayDirection,
        x: Int,
        y: Int
    ) -> Bool {
        guard contains(x: x, y: y) else { return false }
        let index = y * width + x
        guard oneWayMask[index] != direction.rawValue else { return false }
        oneWayMask[index] = direction.rawValue
        return true
    }
}

public struct NeoLemmixConfiguration: Codable, Equatable, Sendable {
    public let totalLemmings: Int
    public let requiredToSave: Int
    public let timeLimitTicks: Int?
    public let spawnInterval: Int
    public let spawnIntervalLocked: Bool
    public let entranceOpenTick: Int
    public let firstSpawnDelay: Int
    public let entrances: [NeoLemmixEntrance]
    public let zones: [NeoLemmixZone]
    public let preplacedLemmings: [NeoLemmixPreplacedLemming]
    public let skills: [NeoLemmixSkill: NeoLemmixSkillSupply]

    public init(
        totalLemmings: Int,
        requiredToSave: Int,
        timeLimitTicks: Int? = nil,
        spawnInterval: Int,
        spawnIntervalLocked: Bool = false,
        entranceOpenTick: Int = NeoLemmixRules.entranceOpenTick,
        firstSpawnDelay: Int = NeoLemmixRules.firstSpawnDelay,
        entrances: [NeoLemmixEntrance],
        zones: [NeoLemmixZone] = [],
        preplacedLemmings: [NeoLemmixPreplacedLemming] = [],
        skills: [NeoLemmixSkill: NeoLemmixSkillSupply] = [:]
    ) throws {
        guard totalLemmings >= 0 else {
            throw NeoLemmixSimulationError.invalidConfiguration(
                "The total lemming count cannot be negative."
            )
        }
        guard requiredToSave >= 0 else {
            throw NeoLemmixSimulationError.invalidConfiguration(
                "The save requirement cannot be negative."
            )
        }
        guard preplacedLemmings.count <= totalLemmings else {
            throw NeoLemmixSimulationError.invalidConfiguration(
                "The preplaced lemming count exceeds the total lemming count."
            )
        }
        if totalLemmings > preplacedLemmings.count && entrances.isEmpty {
            throw NeoLemmixSimulationError.invalidConfiguration(
                "The level needs an entrance for the lemmings that are not preplaced."
            )
        }
        guard Set(entrances.map(\.id)).count == entrances.count else {
            throw NeoLemmixSimulationError.invalidConfiguration(
                "Entrance IDs must be unique."
            )
        }
        guard Set(zones.map(\.id)).count == zones.count else {
            throw NeoLemmixSimulationError.invalidConfiguration(
                "Zone IDs must be unique."
            )
        }
        guard zones.allSatisfy({ $0.bounds.width > 0 && $0.bounds.height > 0 }) else {
            throw NeoLemmixSimulationError.invalidConfiguration(
                "Each zone must have a positive width and height."
            )
        }
        let lemmingsToSpawn = totalLemmings - preplacedLemmings.count
        if lemmingsToSpawn > 0,
           entrances.allSatisfy({ $0.lemmingLimit != nil }),
           entrances.compactMap(\.lemmingLimit).reduce(0, +) < lemmingsToSpawn {
            throw NeoLemmixSimulationError.invalidConfiguration(
                "The entrance limits cannot release all non-preplaced lemmings."
            )
        }
        if let timeLimitTicks, timeLimitTicks < 0 {
            throw NeoLemmixSimulationError.invalidConfiguration(
                "The time limit cannot be negative."
            )
        }
        guard entranceOpenTick >= 0, firstSpawnDelay >= 0 else {
            throw NeoLemmixSimulationError.invalidConfiguration(
                "The entrance timing cannot be negative."
            )
        }
        for (skill, supply) in skills {
            if case let .finite(count) = supply, count < 0 {
                throw NeoLemmixSimulationError.invalidConfiguration(
                    "The \(skill.rawValue) skill count cannot be negative."
                )
            }
        }
        self.totalLemmings = totalLemmings
        self.requiredToSave = requiredToSave
        self.timeLimitTicks = timeLimitTicks
        self.spawnInterval = max(NeoLemmixRules.minimumSpawnInterval, spawnInterval)
        self.spawnIntervalLocked = spawnIntervalLocked
        self.entranceOpenTick = entranceOpenTick
        self.firstSpawnDelay = firstSpawnDelay
        self.entrances = entrances
        self.zones = zones
        self.preplacedLemmings = preplacedLemmings
        self.skills = skills
    }

    private enum CodingKeys: String, CodingKey {
        case totalLemmings
        case requiredToSave
        case timeLimitTicks
        case spawnInterval
        case spawnIntervalLocked
        case entranceOpenTick
        case firstSpawnDelay
        case entrances
        case zones
        case preplacedLemmings
        case skills
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            totalLemmings: container.decode(Int.self, forKey: .totalLemmings),
            requiredToSave: container.decode(Int.self, forKey: .requiredToSave),
            timeLimitTicks: container.decodeIfPresent(Int.self, forKey: .timeLimitTicks),
            spawnInterval: container.decode(Int.self, forKey: .spawnInterval),
            spawnIntervalLocked: container.decode(Bool.self, forKey: .spawnIntervalLocked),
            entranceOpenTick: container.decode(Int.self, forKey: .entranceOpenTick),
            firstSpawnDelay: container.decode(Int.self, forKey: .firstSpawnDelay),
            entrances: container.decode([NeoLemmixEntrance].self, forKey: .entrances),
            zones: container.decode([NeoLemmixZone].self, forKey: .zones),
            preplacedLemmings: container.decode(
                [NeoLemmixPreplacedLemming].self,
                forKey: .preplacedLemmings
            ),
            skills: container.decode(
                [NeoLemmixSkill: NeoLemmixSkillSupply].self,
                forKey: .skills
            )
        )
    }

    public init(level: NxlvLevel, renderedLevel: NxlvRenderedLevel) throws {
        let unsupported = NeoLemmixRules.unsupportedFeatures(level: level, renderedLevel: renderedLevel)
        guard unsupported.isEmpty else {
            throw NeoLemmixSimulationError.invalidConfiguration(
                "This level needs NeoLemmix features that are not yet supported: " + unsupported.joined(separator: ", ") + ".")
        }
        var sourceGadgets = level.gadgets
        var entrances: [NeoLemmixEntrance] = []
        var zones: [NeoLemmixZone] = []

        func sourceGadget(for rendered: NxlvRenderedGadget) -> NxlvGadget? {
            guard let index = sourceGadgets.firstIndex(where: { gadget in
                let styleMatches = gadget.style?.caseInsensitiveCompare(rendered.style) == .orderedSame
                let pieceMatches = gadget.piece?.caseInsensitiveCompare(rendered.piece) == .orderedSame
                return styleMatches && pieceMatches
            }) else { return nil }
            return sourceGadgets.remove(at: index)
        }

        for rendered in renderedLevel.gadgets {
            let source = sourceGadget(for: rendered)
            let bounds = NeoLemmixRect(
                x: rendered.triggerX ?? rendered.x,
                y: rendered.triggerY ?? rendered.y,
                width: rendered.triggerWidth ?? max(1, rendered.width),
                height: rendered.triggerHeight ?? max(1, rendered.height)
            )
            switch rendered.effect {
            case .entrance:
                let sourceDirection: NeoLemmixDirection = source?.direction == .left ? .left : .right
                let direction = source?.flipLemming == true ? sourceDirection.opposite : sourceDirection
                entrances.append(NeoLemmixEntrance(
                    id: entrances.count,
                    position: NeoLemmixPoint(x: bounds.x, y: bounds.y),
                    direction: direction,
                    traits: Set((source?.lemmingTraits ?? []).map(NeoLemmixTrait.init)),
                    lemmingLimit: source?.lemmings
                ))
            case .exit:
                zones.append(NeoLemmixZone(id: zones.count, effect: .exit, bounds: bounds))
            case .water:
                zones.append(NeoLemmixZone(id: zones.count, effect: .water, bounds: bounds))
            case .fire:
                zones.append(NeoLemmixZone(id: zones.count, effect: .fire, bounds: bounds))
            case .trap:
                zones.append(NeoLemmixZone(
                    id: zones.count,
                    effect: .trap,
                    bounds: bounds,
                    isDisarmable: true
                ))
            case .trapOnce:
                zones.append(NeoLemmixZone(
                    id: zones.count,
                    effect: .oneShotTrap,
                    bounds: bounds,
                    isDisarmable: true
                ))
            default:
                break
            }
        }

        let preplaced = level.preplacedLemmings.compactMap { lemming -> NeoLemmixPreplacedLemming? in
            guard let x = lemming.x, let y = lemming.y else { return nil }
            return NeoLemmixPreplacedLemming(
                position: NeoLemmixPoint(x: x, y: y),
                direction: lemming.direction == .left ? .left : .right,
                traits: Set(lemming.traits.map(NeoLemmixTrait.init))
            )
        }
        let timeLimitTicks: Int?
        switch level.timeLimit {
        case let .seconds(seconds):
            timeLimitTicks = max(0, seconds) * NeoLemmixRules.ticksPerSecond
        case .infinite, .none:
            timeLimitTicks = nil
        }
        let skills = Dictionary(uniqueKeysWithValues: level.skillQuantities.map { skill, quantity in
            let supply: NeoLemmixSkillSupply
            switch quantity {
            case let .finite(count): supply = .finite(max(0, count))
            case .infinite: supply = .infinite
            }
            return (NeoLemmixSkill(skill), supply)
        })
        try self.init(
            totalLemmings: max(level.lemmingsCount, preplaced.count),
            requiredToSave: level.saveRequirement,
            timeLimitTicks: timeLimitTicks,
            spawnInterval: level.spawnInterval,
            spawnIntervalLocked: level.spawnIntervalLocked,
            entrances: entrances,
            zones: zones,
            preplacedLemmings: preplaced,
            skills: skills
        )
    }
}

public enum NeoLemmixRules {
    public static let ticksPerSecond = 17
    public static let minimumSpawnInterval = 4
    public static let entranceOpenTick = 35
    public static let firstSpawnDelay = 20
    public static let maximumSafeFallDistance = 62
    public static let bomberCountdownTicks = 84

    public static let implementedSkills: Set<NeoLemmixSkill> = [
        .walker, .jumper, .shimmier, .slider, .climber, .swimmer, .floater,
        .glider, .disarmer, .bomber, .stoner, .blocker, .platformer, .builder,
        .stacker, .basher, .miner, .digger, .cloner,
    ]

    public static let unsupportedSkills: Set<NeoLemmixSkill> = [.fencer, .laserer]
}

public struct NeoLemmixLemming: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public var position: NeoLemmixPoint
    public var direction: NeoLemmixDirection
    public var action: NeoLemmixAction
    public var animationFrame: Int
    public var actionProgress: Int
    public var fallDistance: Int
    public var trueFallDistance: Int
    public var traits: Set<NeoLemmixTrait>
    public var bomberCountdown: Int?
    public var pendingExplosionSkill: NeoLemmixSkill?
    public var bricksRemaining: Int
    public var targetZoneID: Int?
    public var dehoistPinY: Int?
    public var cloneParentID: Int?
    public var pendingRemovalReason: NeoLemmixRemovalReason?
    public var removalReason: NeoLemmixRemovalReason?
    public var isStartingAction: Bool

    public var isActive: Bool { action != .removed }
    public var canReceiveSkills: Bool {
        isActive && !traits.contains(.zombie) && !traits.contains(.neutral)
    }

    public init(
        id: Int,
        position: NeoLemmixPoint,
        direction: NeoLemmixDirection,
        action: NeoLemmixAction = .falling,
        traits: Set<NeoLemmixTrait> = [],
        cloneParentID: Int? = nil
    ) {
        self.id = id
        self.position = position
        self.direction = direction
        self.action = traits.contains(.blocker) ? .blocking : action
        self.animationFrame = 0
        self.actionProgress = 0
        self.fallDistance = 0
        self.trueFallDistance = 0
        self.traits = traits
        self.bomberCountdown = nil
        self.pendingExplosionSkill = nil
        self.bricksRemaining = 0
        self.targetZoneID = nil
        self.dehoistPinY = nil
        self.cloneParentID = cloneParentID
        self.pendingRemovalReason = nil
        self.removalReason = nil
        self.isStartingAction = true
    }
}

public enum NeoLemmixAssignmentRejection: String, Codable, Sendable {
    case unsupportedSkill
    case noSuchLemming
    case removedLemming
    case cannotReceiveSkills
    case noSkillAvailable
    case invalidCurrentAction
    case duplicatePermanentSkill
    case conflictingPermanentSkill
    case blockedBySteelOrOneWay
    case noCeiling
    case overlappingBlockerField
}

public enum NeoLemmixAssignmentResult: Codable, Equatable, Sendable {
    case assigned(lemmingID: Int, skill: NeoLemmixSkill)
    case rejected(lemmingID: Int, skill: NeoLemmixSkill, reason: NeoLemmixAssignmentRejection)

    public var wasAssigned: Bool {
        if case .assigned = self { return true }
        return false
    }
}

public enum NeoLemmixCommand: Codable, Equatable, Sendable {
    case assign(lemmingID: Int, skill: NeoLemmixSkill)
    case setSpawnInterval(Int)
    case nuke
}

public struct NeoLemmixReplayCommand: Codable, Equatable, Sendable {
    public let tick: Int
    public let sequence: UInt64
    public let command: NeoLemmixCommand

    public init(tick: Int, sequence: UInt64, command: NeoLemmixCommand) {
        self.tick = tick
        self.sequence = sequence
        self.command = command
    }
}

public enum NeoLemmixEvent: Codable, Equatable, Sendable {
    case entrancesOpened
    case hatched(lemmingID: Int, entranceID: Int)
    case assignment(NeoLemmixAssignmentResult)
    case spawnIntervalChanged(Int)
    case nukeStarted
    case actionChanged(lemmingID: Int, from: NeoLemmixAction, to: NeoLemmixAction)
    case terrainAdded(lemmingID: Int, pixelCount: Int)
    case terrainRemoved(lemmingID: Int, pixelCount: Int)
    case hazardTriggered(lemmingID: Int, zoneID: Int, effect: NeoLemmixZoneEffect)
    case zoneDisarmed(lemmingID: Int, zoneID: Int)
    case cloned(sourceID: Int, cloneID: Int)
    case removed(lemmingID: Int, reason: NeoLemmixRemovalReason)
    case completed(didWin: Bool)
    case unsupportedCommand(NeoLemmixCommand)
}

public struct NeoLemmixSnapshot: Codable, Equatable, Sendable {
    public let tickCount: Int
    public let releasedCount: Int
    public let savedCount: Int
    public let lostCount: Int
    public let clonedCount: Int
    public let remainingTimeTicks: Int?
    public let spawnInterval: Int
    public let entrancesAreOpen: Bool
    public let isNuking: Bool
    public let isComplete: Bool
    public let didWin: Bool
    public let terrainRevision: Int
    public let terrain: NeoLemmixTerrain
    public let skills: [NeoLemmixSkill: NeoLemmixSkillSupply]
    public let lemmings: [NeoLemmixLemming]
    public let disabledZoneIDs: Set<Int>
    public let events: [NeoLemmixEvent]
}

// MARK: - Deterministic simulation

public struct NeoLemmixSimulation: Codable, Equatable, Sendable {
    public let configuration: NeoLemmixConfiguration
    public private(set) var terrain: NeoLemmixTerrain
    public private(set) var lemmings: [NeoLemmixLemming]
    public private(set) var skills: [NeoLemmixSkill: NeoLemmixSkillSupply]
    public private(set) var tickCount: Int
    public private(set) var releasedCount: Int
    public private(set) var savedCount: Int
    public private(set) var lostCount: Int
    public private(set) var clonedCount: Int
    public private(set) var spawnInterval: Int
    public private(set) var remainingTimeTicks: Int?
    public private(set) var entrancesAreOpen: Bool
    public private(set) var isNuking: Bool
    public private(set) var terrainRevision: Int
    public private(set) var disabledZoneIDs: Set<Int>
    public private(set) var queuedCommands: [NeoLemmixReplayCommand]
    public private(set) var lastTickEvents: [NeoLemmixEvent]

    private var nextCommandSequence: UInt64
    private var nextLemmingID: Int
    private var nextEntranceCursor: Int
    private var entranceSpawnCounts: [Int]
    private var nextSpawnCountdown: Int
    private var completionWasReported: Bool
    private var nukeCursor: Int
    private var nukeCountdown: Int

    public var activeLemmings: [NeoLemmixLemming] {
        lemmings.filter(\.isActive)
    }

    public var originalLemmingsRemainingToRelease: Int {
        max(0, configuration.totalLemmings - configuration.preplacedLemmings.count - releasedCount)
    }

    public var totalPopulation: Int { configuration.totalLemmings + clonedCount }

    public var isComplete: Bool {
        originalLemmingsRemainingToRelease == 0 && activeLemmings.isEmpty
    }

    public var didWin: Bool { isComplete && savedCount >= configuration.requiredToSave }

    public init(terrain: NeoLemmixTerrain, configuration: NeoLemmixConfiguration) throws {
        for entrance in configuration.entrances where
            !terrain.contains(x: entrance.position.x, y: entrance.position.y) {
            throw NeoLemmixSimulationError.invalidConfiguration(
                "Entrance \(entrance.id) is outside the simulation terrain."
            )
        }
        for lemming in configuration.preplacedLemmings where
            !terrain.contains(x: lemming.position.x, y: lemming.position.y) {
            throw NeoLemmixSimulationError.invalidConfiguration(
                "A preplaced lemming is outside the simulation terrain."
            )
        }
        self.configuration = configuration
        self.terrain = terrain
        var initialLemmings: [NeoLemmixLemming] = []
        for (index, preplaced) in configuration.preplacedLemmings.enumerated() {
            var lemming = NeoLemmixLemming(
                id: index,
                position: preplaced.position,
                direction: preplaced.direction,
                traits: preplaced.traits
            )
            if preplaced.traits.contains(.shimmier)
                && terrain.isSolid(x: preplaced.position.x, y: preplaced.position.y - 9) {
                lemming.action = .shimmying
            } else if !terrain.isSolid(x: preplaced.position.x, y: preplaced.position.y) {
                lemming.action = .falling
                lemming.traits.remove(.blocker)
            } else if preplaced.traits.contains(.blocker)
                && !initialLemmings.contains(where: {
                    $0.action == .blocking
                        && abs($0.position.x - preplaced.position.x) <= 11
                        && abs($0.position.y - preplaced.position.y) <= 10
                }) {
                lemming.action = .blocking
            } else {
                lemming.action = .walking
                lemming.traits.remove(.blocker)
            }
            initialLemmings.append(lemming)
        }
        self.lemmings = initialLemmings
        self.skills = configuration.skills
        self.tickCount = 0
        self.releasedCount = 0
        self.savedCount = 0
        self.lostCount = 0
        self.clonedCount = 0
        self.spawnInterval = configuration.spawnInterval
        self.remainingTimeTicks = configuration.timeLimitTicks
        self.entrancesAreOpen = configuration.entranceOpenTick == 0
        self.isNuking = false
        self.terrainRevision = 0
        self.disabledZoneIDs = []
        self.queuedCommands = []
        self.lastTickEvents = []
        self.nextCommandSequence = 0
        self.nextLemmingID = configuration.preplacedLemmings.count
        self.nextEntranceCursor = 0
        self.entranceSpawnCounts = Array(repeating: 0, count: configuration.entrances.count)
        self.nextSpawnCountdown = configuration.firstSpawnDelay
        self.completionWasReported = false
        self.nukeCursor = 0
        self.nukeCountdown = 0
    }

    public init(level: NxlvLevel, renderedLevel: NxlvRenderedLevel) throws {
        let configuration = try NeoLemmixConfiguration(level: level, renderedLevel: renderedLevel)
        let terrain = try NeoLemmixTerrain(
            width: renderedLevel.width,
            height: renderedLevel.height,
            solidMask: renderedLevel.solidMask,
            steelMask: renderedLevel.steelMask,
            oneWayMask: renderedLevel.oneWayMask
        )
        try self.init(terrain: terrain, configuration: configuration)
    }

    @discardableResult
    public mutating func enqueue(
        _ command: NeoLemmixCommand,
        atTick requestedTick: Int? = nil
    ) -> UInt64 {
        let sequence = nextCommandSequence
        nextCommandSequence &+= 1
        let scheduledTick = max(tickCount + 1, requestedTick ?? tickCount + 1)
        queuedCommands.append(NeoLemmixReplayCommand(
            tick: scheduledTick,
            sequence: sequence,
            command: command
        ))
        return sequence
    }

    public mutating func enqueueReplay(_ replay: [NeoLemmixReplayCommand]) {
        queuedCommands.append(contentsOf: replay.filter { $0.tick > tickCount })
        if let maximum = replay.map(\.sequence).max(), maximum >= nextCommandSequence {
            nextCommandSequence = maximum &+ 1
        }
    }

    @discardableResult
    public mutating func assign(
        skill: NeoLemmixSkill,
        to lemmingID: Int
    ) -> NeoLemmixAssignmentResult {
        lastTickEvents = []
        let result = performAssignment(skill: skill, lemmingID: lemmingID)
        lastTickEvents.append(.assignment(result))
        return result
    }

    public func snapshot() -> NeoLemmixSnapshot {
        NeoLemmixSnapshot(
            tickCount: tickCount,
            releasedCount: releasedCount,
            savedCount: savedCount,
            lostCount: lostCount,
            clonedCount: clonedCount,
            remainingTimeTicks: remainingTimeTicks,
            spawnInterval: spawnInterval,
            entrancesAreOpen: entrancesAreOpen,
            isNuking: isNuking,
            isComplete: isComplete,
            didWin: didWin,
            terrainRevision: terrainRevision,
            terrain: terrain,
            skills: skills,
            lemmings: lemmings,
            disabledZoneIDs: disabledZoneIDs,
            events: lastTickEvents
        )
    }

    @discardableResult
    public mutating func tick() -> [NeoLemmixEvent] {
        guard !isComplete else {
            lastTickEvents = []
            reportCompletionIfNeeded()
            return lastTickEvents
        }
        lastTickEvents = []
        let nextTick = tickCount + 1
        processCommands(for: nextTick)
        tickCount = nextTick

        if let time = remainingTimeTicks {
            remainingTimeTicks = max(0, time - 1)
            if remainingTimeTicks == 0 {
                expireLevel()
                reportCompletionIfNeeded()
                return lastTickEvents
            }
        }

        if !entrancesAreOpen, tickCount >= configuration.entranceOpenTick {
            entrancesAreOpen = true
            lastTickEvents.append(.entrancesOpened)
        }
        releaseLemmingIfDue()
        updateNuke()

        let updateIDs = lemmings.filter(\.isActive).map(\.id).sorted()
        for id in updateIDs {
            updateLemming(id: id)
        }
        reportCompletionIfNeeded()
        return lastTickEvents
    }

    public mutating func run(ticks: Int) {
        guard ticks > 0 else { return }
        for _ in 0..<ticks where !isComplete {
            tick()
        }
    }
}

private extension NeoLemmixSimulation {
    mutating func processCommands(for tick: Int) {
        let due = queuedCommands.enumerated()
            .filter { $0.element.tick <= tick }
            .sorted {
                if $0.element.tick != $1.element.tick {
                    return $0.element.tick < $1.element.tick
                }
                if $0.element.sequence != $1.element.sequence {
                    return $0.element.sequence < $1.element.sequence
                }
                return $0.offset < $1.offset
            }
            .map(\.element)
        queuedCommands.removeAll { $0.tick <= tick }
        for replay in due {
            switch replay.command {
            case let .assign(lemmingID, skill):
                let result = performAssignment(skill: skill, lemmingID: lemmingID)
                lastTickEvents.append(.assignment(result))
            case let .setSpawnInterval(interval):
                guard !configuration.spawnIntervalLocked else {
                    lastTickEvents.append(.unsupportedCommand(replay.command))
                    continue
                }
                let newValue = min(
                    configuration.spawnInterval,
                    max(NeoLemmixRules.minimumSpawnInterval, interval)
                )
                if newValue != spawnInterval {
                    spawnInterval = newValue
                    lastTickEvents.append(.spawnIntervalChanged(newValue))
                }
            case .nuke:
                if !isNuking {
                    isNuking = true
                    nukeCursor = 0
                    nukeCountdown = 0
                    lastTickEvents.append(.nukeStarted)
                }
            }
        }
    }

    mutating func performAssignment(
        skill: NeoLemmixSkill,
        lemmingID: Int
    ) -> NeoLemmixAssignmentResult {
        guard NeoLemmixRules.implementedSkills.contains(skill) else {
            return .rejected(lemmingID: lemmingID, skill: skill, reason: .unsupportedSkill)
        }
        guard let index = lemmings.firstIndex(where: { $0.id == lemmingID }) else {
            return .rejected(lemmingID: lemmingID, skill: skill, reason: .noSuchLemming)
        }
        guard lemmings[index].isActive else {
            return .rejected(lemmingID: lemmingID, skill: skill, reason: .removedLemming)
        }
        guard lemmings[index].canReceiveSkills else {
            return .rejected(lemmingID: lemmingID, skill: skill, reason: .cannotReceiveSkills)
        }
        guard hasSupply(for: skill) else {
            return .rejected(lemmingID: lemmingID, skill: skill, reason: .noSkillAvailable)
        }

        var lemming = lemmings[index]
        if let rejection = assignmentRejection(skill: skill, lemming: lemming) {
            return .rejected(lemmingID: lemmingID, skill: skill, reason: rejection)
        }

        switch skill {
        case .slider:
            lemming.traits.insert(.slider)
        case .climber:
            lemming.traits.insert(.climber)
        case .swimmer:
            lemming.traits.insert(.swimmer)
            if lemming.action == .drowning { transition(&lemming, to: .swimming) }
        case .floater:
            lemming.traits.insert(.floater)
        case .glider:
            lemming.traits.insert(.glider)
        case .disarmer:
            lemming.traits.insert(.disarmer)
        case .walker:
            if lemming.action == .walking {
                lemming.direction = lemming.direction.opposite
            } else {
                transition(&lemming, to: .walking)
            }
        case .jumper:
            transition(&lemming, to: .jumping)
        case .shimmier:
            if [.climbing, .dehoisting, .sliding, .jumping].contains(lemming.action) {
                transition(&lemming, to: .shimmying)
            } else {
                transition(&lemming, to: .reaching)
            }
        case .bomber, .stoner:
            lemming.bomberCountdown = 1
            lemming.pendingExplosionSkill = skill
        case .blocker:
            lemming.traits.insert(.blocker)
            transition(&lemming, to: .blocking)
        case .platformer:
            transition(&lemming, to: .platforming)
        case .builder:
            transition(&lemming, to: .building)
        case .stacker:
            transition(&lemming, to: .stacking)
        case .basher:
            transition(&lemming, to: .bashing)
        case .miner:
            transition(&lemming, to: .mining)
        case .digger:
            transition(&lemming, to: .digging)
            _ = digRow(for: lemming, y: lemming.position.y - 1)
        case .cloner:
            clone(lemming)
        case .fencer, .laserer:
            return .rejected(lemmingID: lemmingID, skill: skill, reason: .unsupportedSkill)
        }
        consume(skill: skill)
        lemmings[index] = lemming
        return .assigned(lemmingID: lemmingID, skill: skill)
    }

    func assignmentRejection(
        skill: NeoLemmixSkill,
        lemming: NeoLemmixLemming
    ) -> NeoLemmixAssignmentRejection? {
        let terminal: Set<NeoLemmixAction> = [
            .ohNo, .stoning, .exploding, .stoneFinish, .splatting, .exiting,
            .vaporizing, .removed,
        ]
        let workActions: Set<NeoLemmixAction> = [
            .walking, .shrugging, .platforming, .building, .stacking, .bashing,
            .mining, .digging,
        ]
        switch skill {
        case .slider:
            return lemming.traits.contains(.slider) ? .duplicatePermanentSkill
                : terminal.contains(lemming.action) ? .invalidCurrentAction : nil
        case .climber:
            return lemming.traits.contains(.climber) ? .duplicatePermanentSkill
                : terminal.contains(lemming.action) ? .invalidCurrentAction : nil
        case .swimmer:
            return lemming.traits.contains(.swimmer) ? .duplicatePermanentSkill
                : terminal.contains(lemming.action) ? .invalidCurrentAction : nil
        case .floater:
            if lemming.traits.contains(.floater) { return .duplicatePermanentSkill }
            if lemming.traits.contains(.glider) { return .conflictingPermanentSkill }
            return terminal.contains(lemming.action) ? .invalidCurrentAction : nil
        case .glider:
            if lemming.traits.contains(.glider) { return .duplicatePermanentSkill }
            if lemming.traits.contains(.floater) { return .conflictingPermanentSkill }
            return terminal.contains(lemming.action) ? .invalidCurrentAction : nil
        case .disarmer:
            return lemming.traits.contains(.disarmer) ? .duplicatePermanentSkill
                : terminal.contains(lemming.action) || lemming.action == .drowning
                    ? .invalidCurrentAction : nil
        case .walker:
            let allowed = workActions.union([.blocking, .reaching, .shimmying])
            return allowed.contains(lemming.action) ? nil : .invalidCurrentAction
        case .jumper:
            let allowed = workActions.union([.climbing, .sliding])
            return allowed.contains(lemming.action) ? nil : .invalidCurrentAction
        case .shimmier:
            let allowed = workActions.union([.climbing, .dehoisting, .sliding, .jumping])
            guard allowed.contains(lemming.action) else { return .invalidCurrentAction }
            let x = lemming.position.x
            let y = lemming.position.y
            return (terrain.isSolid(x: x, y: y - 9) || terrain.isSolid(x: x, y: y - 10))
                ? nil : .noCeiling
        case .bomber, .stoner:
            return terminal.contains(lemming.action) || lemming.action == .drowning
                ? .invalidCurrentAction : nil
        case .blocker:
            guard workActions.contains(lemming.action) else { return .invalidCurrentAction }
            guard !blockerFieldOverlaps(lemming) else { return .overlappingBlockerField }
            return terrain.isSolid(x: lemming.position.x, y: lemming.position.y)
                ? nil : .invalidCurrentAction
        case .platformer, .builder, .stacker, .basher:
            return workActions.contains(lemming.action) ? nil : .invalidCurrentAction
        case .miner:
            guard workActions.contains(lemming.action) else { return .invalidCurrentAction }
            return isIndestructible(
                x: lemming.position.x,
                y: lemming.position.y,
                skill: .miner,
                direction: lemming.direction
            ) ? .blockedBySteelOrOneWay : nil
        case .digger:
            guard workActions.contains(lemming.action) else { return .invalidCurrentAction }
            return isIndestructible(
                x: lemming.position.x,
                y: lemming.position.y,
                skill: .digger,
                direction: lemming.direction
            ) ? .blockedBySteelOrOneWay : nil
        case .cloner:
            let allowed = workActions.union([
                .ascending, .falling, .floating, .gliding, .dehoisting, .sliding, .swimming,
                .disarming, .reaching, .shimmying, .jumping,
            ])
            return allowed.contains(lemming.action) ? nil : .invalidCurrentAction
        case .fencer, .laserer:
            return .unsupportedSkill
        }
    }

    func hasSupply(for skill: NeoLemmixSkill) -> Bool {
        switch skills[skill] ?? .finite(0) {
        case let .finite(count): count > 0
        case .infinite: true
        }
    }

    mutating func consume(skill: NeoLemmixSkill) {
        guard case let .finite(count) = skills[skill] ?? .finite(0) else { return }
        skills[skill] = .finite(max(0, count - 1))
    }

    mutating func clone(_ source: NeoLemmixLemming) {
        var clone = source
        clone = NeoLemmixLemming(
            id: nextLemmingID,
            position: source.position,
            direction: source.direction.opposite,
            action: source.action,
            traits: source.traits.subtracting([.blocker]),
            cloneParentID: source.id
        )
        clone.animationFrame = source.animationFrame
        clone.actionProgress = source.actionProgress
        clone.fallDistance = source.fallDistance
        clone.trueFallDistance = source.trueFallDistance
        clone.bricksRemaining = source.bricksRemaining
        clone.dehoistPinY = source.dehoistPinY
        clone.isStartingAction = source.isStartingAction
        nextLemmingID += 1
        clonedCount += 1
        lemmings.append(clone)
        lastTickEvents.append(.cloned(sourceID: source.id, cloneID: clone.id))
    }

    mutating func releaseLemmingIfDue() {
        guard entrancesAreOpen, !isNuking, originalLemmingsRemainingToRelease > 0 else { return }
        if nextSpawnCountdown > 0 { nextSpawnCountdown -= 1 }
        guard nextSpawnCountdown == 0, let entranceIndex = nextAvailableEntranceIndex() else { return }
        let entrance = configuration.entrances[entranceIndex]
        let lemming = NeoLemmixLemming(
            id: nextLemmingID,
            position: entrance.position,
            direction: entrance.direction,
            traits: entrance.traits
        )
        lemmings.append(lemming)
        nextLemmingID += 1
        releasedCount += 1
        entranceSpawnCounts[entranceIndex] += 1
        nextEntranceCursor = configuration.entrances.isEmpty
            ? 0 : (entranceIndex + 1) % configuration.entrances.count
        nextSpawnCountdown = spawnInterval
        lastTickEvents.append(.hatched(lemmingID: lemming.id, entranceID: entrance.id))
    }

    mutating func nextAvailableEntranceIndex() -> Int? {
        guard !configuration.entrances.isEmpty else { return nil }
        for offset in 0..<configuration.entrances.count {
            let index = (nextEntranceCursor + offset) % configuration.entrances.count
            let limit = configuration.entrances[index].lemmingLimit
            if limit == nil || entranceSpawnCounts[index] < (limit ?? 0) { return index }
        }
        return nil
    }

    mutating func updateNuke() {
        guard isNuking else { return }
        if nukeCountdown > 0 {
            nukeCountdown -= 1
            return
        }
        let activeIDs = lemmings.filter(\.isActive).map(\.id).sorted()
        while nukeCursor < activeIDs.count {
            let id = activeIDs[nukeCursor]
            nukeCursor += 1
            guard let index = lemmings.firstIndex(where: { $0.id == id }),
                  lemmings[index].bomberCountdown == nil else { continue }
            lemmings[index].bomberCountdown = NeoLemmixRules.bomberCountdownTicks
            lemmings[index].pendingExplosionSkill = .bomber
            nukeCountdown = 0
            return
        }
    }

    mutating func transition(
        _ lemming: inout NeoLemmixLemming,
        to action: NeoLemmixAction,
        turn: Bool = false
    ) {
        if turn { lemming.direction = lemming.direction.opposite }
        guard lemming.action != action else { return }
        let old = lemming.action
        lemming.action = action
        lemming.animationFrame = 0
        lemming.actionProgress = 0
        lemming.isStartingAction = true
        lemming.targetZoneID = action == .disarming ? lemming.targetZoneID : nil
        if action == .dehoisting {
            lemming.dehoistPinY = lemming.position.y
        } else if action != .sliding {
            lemming.dehoistPinY = nil
        }
        switch action {
        case .building, .platforming:
            lemming.bricksRemaining = 12
        case .stacking:
            lemming.bricksRemaining = 8
        default:
            break
        }
        if action == .blocking { lemming.traits.insert(.blocker) }
        if old == .blocking && action != .blocking { lemming.traits.remove(.blocker) }
        lastTickEvents.append(.actionChanged(lemmingID: lemming.id, from: old, to: action))
    }

    mutating func remove(
        _ lemming: inout NeoLemmixLemming,
        reason: NeoLemmixRemovalReason
    ) {
        guard lemming.isActive else { return }
        if reason == .saved { savedCount += 1 } else { lostCount += 1 }
        if lemming.action == .blocking { lemming.traits.remove(.blocker) }
        lemming.removalReason = reason
        lemming.action = .removed
        lemming.animationFrame = 0
        lastTickEvents.append(.removed(lemmingID: lemming.id, reason: reason))
    }

    mutating func expireLevel() {
        let unresolvedOriginals = originalLemmingsRemainingToRelease
        if unresolvedOriginals > 0 { lostCount += unresolvedOriginals }
        releasedCount += unresolvedOriginals
        for index in lemmings.indices where lemmings[index].isActive {
            var lemming = lemmings[index]
            remove(&lemming, reason: .timeExpired)
            lemmings[index] = lemming
        }
    }

    mutating func reportCompletionIfNeeded() {
        guard isComplete, !completionWasReported else { return }
        completionWasReported = true
        lastTickEvents.append(.completed(didWin: didWin))
    }
}

private extension NeoLemmixSimulation {
    func canDehoist(_ lemming: NeoLemmixLemming, alreadyMovedX: Bool) -> Bool {
        let direction = lemming.direction.rawValue
        let currentX = alreadyMovedX ? lemming.position.x - direction : lemming.position.x
        let nextX = alreadyMovedX ? lemming.position.x : lemming.position.x + direction
        guard terrain.contains(x: nextX, y: lemming.position.y),
              terrain.isSolid(x: currentX, y: lemming.position.y),
              !terrain.isSolid(x: nextX, y: lemming.position.y) else { return false }
        for offset in 1...3 {
            if terrain.isSolid(x: nextX, y: lemming.position.y + offset) { return false }
            if !terrain.isSolid(x: currentX, y: lemming.position.y + offset) { break }
        }
        return true
    }

    func findGroundPixel(x: Int, y: Int) -> Int {
        var result = 0
        if terrain.isSolid(x: x, y: y) {
            while result > -7 && terrain.isSolid(x: x, y: y + result - 1) {
                result -= 1
            }
        } else {
            result = 1
            while result < 4 && !terrain.isSolid(x: x, y: y + result) {
                result += 1
            }
        }
        return result
    }

    func isIndestructible(
        x: Int,
        y: Int,
        skill: NeoLemmixSkill,
        direction: NeoLemmixDirection
    ) -> Bool {
        if terrain.isSteel(x: x, y: y) { return true }
        switch terrain.oneWayDirection(x: x, y: y) {
        case .none:
            return false
        case .up:
            return [.basher, .miner, .digger].contains(skill)
        case .down:
            return [.basher, .fencer, .laserer].contains(skill)
        case .left:
            return direction == .right && [.basher, .fencer, .miner, .laserer].contains(skill)
        case .right:
            return direction == .left && [.basher, .fencer, .miner, .laserer].contains(skill)
        }
    }

    mutating func eraseDestructible(
        x: Int,
        y: Int,
        skill: NeoLemmixSkill,
        direction: NeoLemmixDirection
    ) -> Bool {
        guard terrain.isSolid(x: x, y: y),
              !isIndestructible(x: x, y: y, skill: skill, direction: direction) else {
            return false
        }
        return terrain.setSolid(false, x: x, y: y)
    }

    @discardableResult
    mutating func digRow(for lemming: NeoLemmixLemming, y: Int) -> Int {
        var removed = 0
        var centralRemoved = 0
        for offset in -4...4 {
            if eraseDestructible(
                x: lemming.position.x + offset,
                y: y,
                skill: .digger,
                direction: lemming.direction
            ) {
                removed += 1
                if offset > -4 && offset < 4 { centralRemoved += 1 }
            }
        }
        emitTerrainRemoved(lemmingID: lemming.id, count: removed)
        return centralRemoved
    }

    @discardableResult
    mutating func addBrick(
        x: Int,
        y: Int,
        direction: NeoLemmixDirection,
        length: Int
    ) -> Int {
        guard length > 0 else { return 0 }
        var added = 0
        for offset in 0..<length {
            if terrain.setSolid(true, x: x + offset * direction.rawValue, y: y) {
                added += 1
            }
        }
        return added
    }

    mutating func emitTerrainAdded(lemmingID: Int, count: Int) {
        guard count > 0 else { return }
        terrainRevision += 1
        lastTickEvents.append(.terrainAdded(lemmingID: lemmingID, pixelCount: count))
    }

    mutating func emitTerrainRemoved(lemmingID: Int, count: Int) {
        guard count > 0 else { return }
        terrainRevision += 1
        lastTickEvents.append(.terrainRemoved(lemmingID: lemmingID, pixelCount: count))
    }

    func blockerFieldOverlaps(_ candidate: NeoLemmixLemming) -> Bool {
        lemmings.contains { blocker in
            blocker.id != candidate.id && blocker.isActive && blocker.action == .blocking
                && abs(blocker.position.x - candidate.position.x) <= 11
                && abs(blocker.position.y - candidate.position.y) <= 10
        }
    }

    func blockerTurns(_ lemming: NeoLemmixLemming, atX x: Int) -> Bool {
        lemmings.contains { blocker in
            guard blocker.id != lemming.id, blocker.isActive, blocker.action == .blocking,
                  (blocker.position.y - 6...blocker.position.y + 4).contains(lemming.position.y) else {
                return false
            }
            if lemming.direction == .right {
                return (blocker.position.x - 6..<blocker.position.x).contains(x)
            }
            return (blocker.position.x + 1...blocker.position.x + 6).contains(x)
        }
    }

    func isInWater(_ point: NeoLemmixPoint) -> Bool {
        configuration.zones.contains {
            !disabledZoneIDs.contains($0.id) && $0.effect == .water && $0.bounds.contains(point)
        }
    }

    func movementPath(from start: NeoLemmixPoint, to end: NeoLemmixPoint) -> [NeoLemmixPoint] {
        var result: [NeoLemmixPoint] = [start]
        var current = start
        while current.x != end.x {
            current.x += current.x < end.x ? 1 : -1
            result.append(current)
        }
        while current.y != end.y {
            current.y += current.y < end.y ? 1 : -1
            result.append(current)
        }
        return result
    }

    mutating func checkZones(
        _ lemming: inout NeoLemmixLemming,
        from oldPosition: NeoLemmixPoint
    ) {
        guard ![
            .exiting, .drowning, .vaporizing, .splatting, .ohNo, .stoning,
            .exploding, .stoneFinish, .disarming,
        ].contains(lemming.action) else { return }

        let path = movementPath(from: oldPosition, to: lemming.position)
        for point in path {
            let matchingZones = configuration.zones.filter {
                !disabledZoneIDs.contains($0.id) && $0.bounds.contains(point)
            }
            for zone in matchingZones {
                switch zone.effect {
                case .fire:
                    lemming.position = point
                    lemming.pendingRemovalReason = .burned
                    lastTickEvents.append(.hazardTriggered(
                        lemmingID: lemming.id,
                        zoneID: zone.id,
                        effect: zone.effect
                    ))
                    transition(&lemming, to: .vaporizing)
                    return
                case .water:
                    lemming.position = point
                    lastTickEvents.append(.hazardTriggered(
                        lemmingID: lemming.id,
                        zoneID: zone.id,
                        effect: zone.effect
                    ))
                    if lemming.traits.contains(.swimmer) {
                        transition(&lemming, to: .swimming)
                    } else {
                        transition(&lemming, to: .drowning)
                    }
                    return
                case .trap, .oneShotTrap:
                    lemming.position = point
                    lastTickEvents.append(.hazardTriggered(
                        lemmingID: lemming.id,
                        zoneID: zone.id,
                        effect: zone.effect
                    ))
                    if zone.isDisarmable && lemming.traits.contains(.disarmer) {
                        lemming.targetZoneID = zone.id
                        transition(&lemming, to: .disarming)
                    } else {
                        lemming.pendingRemovalReason = .trapped
                        transition(&lemming, to: .vaporizing)
                        if zone.effect == .oneShotTrap { disabledZoneIDs.insert(zone.id) }
                    }
                    return
                case .exit:
                    guard !lemming.traits.contains(.zombie) else { continue }
                    lemming.position = point
                    lastTickEvents.append(.hazardTriggered(
                        lemmingID: lemming.id,
                        zoneID: zone.id,
                        effect: zone.effect
                    ))
                    transition(&lemming, to: .exiting)
                    return
                }
            }
        }
    }

    mutating func checkBounds(_ lemming: inout NeoLemmixLemming) {
        guard lemming.position.x >= 0,
              lemming.position.x < terrain.width,
              lemming.position.y >= -9,
              lemming.position.y <= terrain.height + 9 else {
            remove(&lemming, reason: .fellOut)
            return
        }
    }

    mutating func explode(_ lemming: inout NeoLemmixLemming) {
        let centerX = lemming.position.x
        let centerY = lemming.position.y - 7
        var removedPixels = 0
        for offsetY in -8...8 {
            for offsetX in -8...8 where offsetX * offsetX + offsetY * offsetY <= 64 {
                let x = centerX + offsetX
                let y = centerY + offsetY
                guard terrain.isSolid(x: x, y: y), !terrain.isSteel(x: x, y: y) else { continue }
                if terrain.setSolid(false, x: x, y: y) { removedPixels += 1 }
            }
        }
        emitTerrainRemoved(lemmingID: lemming.id, count: removedPixels)
        remove(&lemming, reason: .exploded)
    }

    mutating func finishStoner(_ lemming: inout NeoLemmixLemming) {
        let centerX = lemming.position.x
        let centerY = lemming.position.y - 5
        var addedPixels = 0
        for offsetY in -5...5 {
            for offsetX in -6...6 where
                offsetX * offsetX * 25 + offsetY * offsetY * 36 <= 900 {
                if terrain.setSolid(true, x: centerX + offsetX, y: centerY + offsetY) {
                    addedPixels += 1
                }
            }
        }
        emitTerrainAdded(lemmingID: lemming.id, count: addedPixels)
        remove(&lemming, reason: .stoned)
    }
}

private extension NeoLemmixSimulation {
    mutating func updateLemming(id: Int) {
        guard let index = lemmings.firstIndex(where: { $0.id == id }), lemmings[index].isActive else {
            return
        }
        var lemming = lemmings[index]
        let oldPosition = lemming.position
        lemming.animationFrame += 1
        updateExplosionCountdown(&lemming)

        if lemming.isActive {
            switch lemming.action {
            case .walking:
                updateWalking(&lemming)
            case .ascending:
                updateAscending(&lemming)
            case .falling:
                updateFalling(&lemming)
            case .climbing:
                updateClimbing(&lemming)
            case .hoisting:
                updateHoisting(&lemming)
            case .floating:
                updateFloating(&lemming)
            case .gliding:
                updateGliding(&lemming)
            case .dehoisting:
                updateDehoisting(&lemming)
            case .sliding:
                updateSliding(&lemming)
            case .swimming:
                updateSwimming(&lemming)
            case .blocking:
                updateBlocking(&lemming)
            case .building:
                updateBuilding(&lemming)
            case .platforming:
                updatePlatforming(&lemming)
            case .stacking:
                updateStacking(&lemming)
            case .bashing:
                updateBashing(&lemming)
            case .mining:
                updateMining(&lemming)
            case .digging:
                updateDigging(&lemming)
            case .jumping:
                updateJumping(&lemming)
            case .reaching:
                updateReaching(&lemming)
            case .shimmying:
                updateShimmying(&lemming)
            case .disarming:
                updateDisarming(&lemming)
            case .shrugging:
                if lemming.animationFrame >= 8 { transition(&lemming, to: .walking) }
            case .ohNo:
                if lemming.animationFrame >= 16 { transition(&lemming, to: .exploding) }
            case .stoning:
                if lemming.animationFrame >= 16 { transition(&lemming, to: .stoneFinish) }
            case .exploding:
                explode(&lemming)
            case .stoneFinish:
                finishStoner(&lemming)
            case .splatting:
                if lemming.animationFrame >= 16 { remove(&lemming, reason: .splatted) }
            case .exiting:
                if lemming.animationFrame >= 8 { remove(&lemming, reason: .saved) }
            case .drowning:
                if lemming.animationFrame >= 16 { remove(&lemming, reason: .drowned) }
            case .vaporizing:
                if lemming.animationFrame >= 14 {
                    remove(&lemming, reason: lemming.pendingRemovalReason ?? .burned)
                }
            case .removed:
                break
            }
        }

        if lemming.isActive {
            checkZones(&lemming, from: oldPosition)
            checkBounds(&lemming)
        }
        lemmings[index] = lemming
    }

    mutating func updateExplosionCountdown(_ lemming: inout NeoLemmixLemming) {
        guard let countdown = lemming.bomberCountdown else { return }
        let next = countdown - 1
        lemming.bomberCountdown = max(0, next)
        if next <= 0 {
            let skill = lemming.pendingExplosionSkill ?? .bomber
            lemming.bomberCountdown = nil
            lemming.pendingExplosionSkill = nil
            transition(&lemming, to: skill == .stoner ? .stoning : .ohNo)
        }
    }

    mutating func updateWalking(_ lemming: inout NeoLemmixLemming) {
        lemming.animationFrame %= 4
        let forwardX = lemming.position.x + lemming.direction.rawValue
        if blockerTurns(lemming, atX: forwardX) {
            lemming.direction = lemming.direction.opposite
        }
        lemming.position.x += lemming.direction.rawValue
        var deltaY = findGroundPixel(x: lemming.position.x, y: lemming.position.y)

        if deltaY > 0,
           lemming.traits.contains(.slider),
           canDehoist(lemming, alreadyMovedX: true) {
            lemming.position.x -= lemming.direction.rawValue
            transition(&lemming, to: .dehoisting, turn: true)
            return
        }

        if deltaY < -6 {
            if lemming.traits.contains(.climber) {
                transition(&lemming, to: .climbing)
            } else {
                lemming.direction = lemming.direction.opposite
                lemming.position.x += lemming.direction.rawValue
            }
        } else if deltaY < -2 {
            lemming.position.y -= 2
            transition(&lemming, to: .ascending)
        } else if deltaY < 1 {
            lemming.position.y += deltaY
        }

        guard lemming.action == .walking || lemming.action == .ascending else { return }
        deltaY = findGroundPixel(x: lemming.position.x, y: lemming.position.y)
        if deltaY > 3 {
            lemming.position.y += 4
            lemming.fallDistance = 4
            lemming.trueFallDistance = 4
            transition(&lemming, to: .falling)
        } else if deltaY > 0 {
            lemming.position.y += deltaY
        }
    }

    mutating func updateAscending(_ lemming: inout NeoLemmixLemming) {
        var moved = 0
        while moved < 2,
              lemming.actionProgress < 5,
              terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 1) {
            moved += 1
            lemming.position.y -= 1
            lemming.actionProgress += 1
        }
        if moved < 2 && !terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 1) {
            transition(&lemming, to: .walking)
            return
        }
        let blockedAtFour = lemming.actionProgress == 4
            && terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 1)
            && terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 2)
        let blockedAtFive = lemming.actionProgress >= 5
            && terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 1)
        if blockedAtFour || blockedAtFive {
            lemming.position.x -= lemming.direction.rawValue
            while terrain.isSolid(x: lemming.position.x, y: lemming.position.y),
                  lemming.actionProgress > 0 {
                lemming.position.y += 1
                lemming.actionProgress -= 1
            }
            transition(&lemming, to: .falling, turn: true)
        }
    }

    mutating func updateFalling(_ lemming: inout NeoLemmixLemming) {
        lemming.animationFrame %= 4
        if lemming.traits.contains(.floater), lemming.trueFallDistance > 16 {
            transition(&lemming, to: .floating)
            return
        }
        if lemming.traits.contains(.glider), lemming.trueFallDistance > 8 {
            transition(&lemming, to: .gliding)
            return
        }

        var moved = 0
        while moved < 3 && !terrain.isSolid(x: lemming.position.x, y: lemming.position.y) {
            lemming.position.y += 1
            moved += 1
            lemming.fallDistance = min(
                NeoLemmixRules.maximumSafeFallDistance + 1,
                lemming.fallDistance + 1
            )
            lemming.trueFallDistance = min(
                NeoLemmixRules.maximumSafeFallDistance + 1,
                lemming.trueFallDistance + 1
            )
            if lemming.traits.contains(.floater), lemming.trueFallDistance > 16 {
                transition(&lemming, to: .floating)
                return
            }
            if lemming.traits.contains(.glider), lemming.trueFallDistance > 8 {
                transition(&lemming, to: .gliding)
                return
            }
        }
        if moved < 3 {
            if lemming.fallDistance > NeoLemmixRules.maximumSafeFallDistance {
                transition(&lemming, to: .splatting)
            } else {
                lemming.fallDistance = 0
                lemming.trueFallDistance = 0
                transition(&lemming, to: .walking)
            }
        }
    }

    mutating func updateFloating(_ lemming: inout NeoLemmixLemming) {
        let table = [3, 3, 3, 3, -1, 0, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2]
        if lemming.animationFrame > 17 { lemming.animationFrame = 9 }
        let maximum = table[max(1, lemming.animationFrame) - 1]
        let ground = max(0, findGroundPixel(x: lemming.position.x, y: lemming.position.y))
        if maximum > ground {
            lemming.position.y += ground
            lemming.fallDistance = 0
            lemming.trueFallDistance = 0
            transition(&lemming, to: .walking)
        } else {
            lemming.position.y += maximum
        }
    }

    mutating func updateGliding(_ lemming: inout NeoLemmixLemming) {
        let table = [3, 3, 3, 3, -1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        if lemming.animationFrame > 17 { lemming.animationFrame = 9 }
        let maximum = table[max(1, lemming.animationFrame) - 1]
        lemming.position.x += lemming.direction.rawValue
        if maximum < 0 { lemming.position.y += maximum }
        let ground = findGroundPixel(x: lemming.position.x, y: lemming.position.y)
        if ground < -4 {
            lemming.position.x -= lemming.direction.rawValue
            lemming.direction = lemming.direction.opposite
        } else if ground < 0 {
            lemming.position.y += ground
            lemming.fallDistance = 0
            lemming.trueFallDistance = 0
            transition(&lemming, to: .walking)
        } else if maximum > 0 {
            if maximum > ground {
                lemming.position.y += ground
                lemming.fallDistance = 0
                lemming.trueFallDistance = 0
                transition(&lemming, to: .walking)
            } else {
                lemming.position.y += maximum
            }
        }
    }

    mutating func updateClimbing(_ lemming: inout NeoLemmixLemming) {
        if lemming.animationFrame > 7 { lemming.animationFrame = 0 }
        let frame = lemming.animationFrame
        if frame <= 3 {
            var clipped = terrain.isSolid(
                x: lemming.position.x - lemming.direction.rawValue,
                y: lemming.position.y - 6 - frame
            )
            clipped = clipped || (
                terrain.isSolid(
                    x: lemming.position.x - lemming.direction.rawValue,
                    y: lemming.position.y - 5 - frame
                ) && !lemming.isStartingAction
            )
            if frame == 0 {
                clipped = clipped && terrain.isSolid(
                    x: lemming.position.x - lemming.direction.rawValue,
                    y: lemming.position.y - 7
                )
            }
            if clipped {
                if !lemming.isStartingAction { lemming.position.y = lemming.position.y - frame + 3 }
                if lemming.traits.contains(.slider) {
                    lemming.position.y -= 1
                    transition(&lemming, to: .sliding)
                } else {
                    lemming.position.x -= lemming.direction.rawValue
                    transition(&lemming, to: .falling, turn: true)
                    lemming.fallDistance = 1
                }
            } else if !terrain.isSolid(
                x: lemming.position.x,
                y: lemming.position.y - 7 - frame
            ) {
                if !(lemming.isStartingAction && frame == 1) {
                    lemming.position.y = lemming.position.y - frame + 2
                    lemming.isStartingAction = false
                }
                transition(&lemming, to: .hoisting)
            }
        } else {
            lemming.position.y -= 1
            lemming.isStartingAction = false
            var clipped = terrain.isSolid(
                x: lemming.position.x - lemming.direction.rawValue,
                y: lemming.position.y - 7
            )
            if frame == 7 {
                clipped = clipped && terrain.isSolid(
                    x: lemming.position.x,
                    y: lemming.position.y - 7
                )
            }
            if clipped {
                lemming.position.y += 1
                if lemming.traits.contains(.slider) {
                    transition(&lemming, to: .sliding)
                } else {
                    lemming.position.x -= lemming.direction.rawValue
                    transition(&lemming, to: .falling, turn: true)
                }
            }
        }
    }

    mutating func updateHoisting(_ lemming: inout NeoLemmixLemming) {
        if lemming.animationFrame <= 4 { lemming.position.y -= 2 }
        if lemming.animationFrame >= 8 { transition(&lemming, to: .walking) }
    }

    mutating func updateSliding(_ lemming: inout NeoLemmixLemming) {
        lemming.animationFrame = 0
        for _ in 0..<2 {
            lemming.position.y += 1
            let wallX = lemming.position.x + lemming.direction.rawValue
            if terrain.isSolid(x: lemming.position.x, y: lemming.position.y)
                && !terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 1) {
                transition(&lemming, to: .walking)
                return
            }
            if !terrain.isSolid(x: wallX, y: lemming.position.y - 7) {
                transition(&lemming, to: .falling)
                return
            }
        }
    }

    mutating func updateDehoisting(_ lemming: inout NeoLemmixLemming) {
        if lemming.animationFrame >= 7 {
            let wallX = lemming.position.x - lemming.direction.rawValue
            if terrain.isSolid(x: wallX, y: lemming.position.y - 7) {
                transition(&lemming, to: .sliding)
            } else {
                transition(&lemming, to: .falling)
            }
            return
        }
        guard lemming.animationFrame >= 2 else { return }
        for _ in 0..<2 {
            lemming.position.y += 1
            let wallX = lemming.position.x - lemming.direction.rawValue
            let pinned = lemming.dehoistPinY == lemming.position.y
                && terrain.isSolid(x: wallX, y: lemming.position.y + 1)
            if !terrain.isSolid(x: wallX, y: lemming.position.y - 7) && !pinned {
                transition(&lemming, to: .falling)
                return
            }
        }
    }

    mutating func updateSwimming(_ lemming: inout NeoLemmixLemming) {
        lemming.animationFrame %= 8
        lemming.fallDistance = 0
        lemming.trueFallDistance = 0
        lemming.position.x += lemming.direction.rawValue
        if !isInWater(lemming.position) {
            let ground = findGroundPixel(x: lemming.position.x, y: lemming.position.y)
            if ground > 1 {
                lemming.position.y += 1
                transition(&lemming, to: .falling)
            } else {
                lemming.position.y += max(0, ground)
                transition(&lemming, to: .walking)
            }
            return
        }
        if isInWater(NeoLemmixPoint(x: lemming.position.x, y: lemming.position.y - 1))
            && !terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 1) {
            lemming.position.y -= 1
        }
        let ground = findGroundPixel(x: lemming.position.x, y: lemming.position.y)
        if ground < -6 {
            if lemming.traits.contains(.climber)
                && !isInWater(NeoLemmixPoint(x: lemming.position.x, y: lemming.position.y - 1)) {
                transition(&lemming, to: .climbing)
            } else {
                lemming.direction = lemming.direction.opposite
                lemming.position.x += lemming.direction.rawValue
            }
        } else if ground <= -3 {
            lemming.position.y -= 2
            transition(&lemming, to: .ascending)
        } else if ground <= -1 {
            lemming.position.y += ground
            transition(&lemming, to: .walking)
        }
    }

    mutating func updateBlocking(_ lemming: inout NeoLemmixLemming) {
        lemming.animationFrame %= 16
        if !terrain.isSolid(x: lemming.position.x, y: lemming.position.y) {
            transition(&lemming, to: .falling)
        }
    }

    mutating func updateBuilding(_ lemming: inout NeoLemmixLemming) {
        if lemming.animationFrame > 15 { lemming.animationFrame = 0 }
        if lemming.animationFrame == 9 {
            let count = addBrick(
                x: lemming.position.x,
                y: lemming.position.y - 1,
                direction: lemming.direction,
                length: 6
            )
            emitTerrainAdded(lemmingID: lemming.id, count: count)
        } else if lemming.animationFrame == 0 {
            lemming.bricksRemaining -= 1
            let direction = lemming.direction.rawValue
            if terrain.isSolid(x: lemming.position.x + direction, y: lemming.position.y - 2) {
                transition(&lemming, to: .walking, turn: true)
                return
            }
            lemming.position.y -= 1
            lemming.position.x += 2 * direction
            if terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 2)
                || terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 3) {
                transition(&lemming, to: .walking, turn: true)
            } else if lemming.bricksRemaining <= 0 {
                transition(&lemming, to: .shrugging)
            }
        }
    }

    mutating func updatePlatforming(_ lemming: inout NeoLemmixLemming) {
        if lemming.animationFrame > 15 { lemming.animationFrame = 0 }
        if lemming.animationFrame == 9 {
            let count = addBrick(
                x: lemming.position.x,
                y: lemming.position.y,
                direction: lemming.direction,
                length: 6
            )
            emitTerrainAdded(lemmingID: lemming.id, count: count)
        } else if lemming.animationFrame == 15 {
            lemming.position.x += lemming.direction.rawValue
        } else if lemming.animationFrame == 0 {
            lemming.position.x += 2 * lemming.direction.rawValue
            lemming.bricksRemaining -= 1
            if lemming.bricksRemaining <= 0 { transition(&lemming, to: .shrugging) }
        }
    }

    mutating func updateStacking(_ lemming: inout NeoLemmixLemming) {
        if lemming.animationFrame > 7 { lemming.animationFrame = 0 }
        if lemming.animationFrame == 7 {
            let rowY = lemming.position.y - 9 + lemming.bricksRemaining
            var count = 0
            for offset in 1...3 {
                if terrain.setSolid(
                    true,
                    x: lemming.position.x + offset * lemming.direction.rawValue,
                    y: rowY
                ) { count += 1 }
            }
            emitTerrainAdded(lemmingID: lemming.id, count: count)
        } else if lemming.animationFrame == 0 {
            lemming.bricksRemaining -= 1
            if lemming.bricksRemaining <= 0 { transition(&lemming, to: .shrugging) }
        }
    }

    mutating func updateDigging(_ lemming: inout NeoLemmixLemming) {
        if lemming.animationFrame > 15 { lemming.animationFrame = 0 }
        if lemming.animationFrame == 0 || lemming.animationFrame == 8 {
            lemming.position.y += 1
            let removed = digRow(for: lemming, y: lemming.position.y - 1)
            let blocked = isIndestructible(
                x: lemming.position.x,
                y: lemming.position.y,
                skill: .digger,
                direction: lemming.direction
            )
            if blocked {
                transition(&lemming, to: .walking)
            } else if removed == 0 {
                transition(&lemming, to: .falling)
            }
        }
    }

    mutating func updateBashing(_ lemming: inout NeoLemmixLemming) {
        if lemming.animationFrame > 15 { lemming.animationFrame = 0 }
        if (2...5).contains(lemming.animationFrame) {
            let phase = lemming.animationFrame - 2
            var removed = 0
            for forward in (phase * 3 + 1)...(phase * 3 + 4) {
                for rise in 1...7 {
                    let x = lemming.position.x + forward * lemming.direction.rawValue
                    let y = lemming.position.y - rise
                    if eraseDestructible(x: x, y: y, skill: .basher, direction: lemming.direction) {
                        removed += 1
                    }
                }
            }
            emitTerrainRemoved(lemmingID: lemming.id, count: removed)
        }
        if lemming.animationFrame == 5 {
            var canContinue = false
            for forward in 1...14 {
                for rise in 5...6 {
                    let x = lemming.position.x + forward * lemming.direction.rawValue
                    let y = lemming.position.y - rise
                    if terrain.isSolid(x: x, y: y)
                        && !isIndestructible(x: x, y: y, skill: .basher, direction: lemming.direction) {
                        canContinue = true
                    }
                }
            }
            if !canContinue {
                transition(
                    &lemming,
                    to: terrain.isSolid(x: lemming.position.x, y: lemming.position.y)
                        ? .walking : .falling
                )
                return
            }
        }
        if (11...15).contains(lemming.animationFrame) {
            lemming.position.x += lemming.direction.rawValue
            let delta = findGroundPixel(x: lemming.position.x, y: lemming.position.y)
            if isIndestructible(
                x: lemming.position.x,
                y: lemming.position.y - 4,
                skill: .basher,
                direction: lemming.direction
            ) {
                lemming.position.x -= lemming.direction.rawValue
                transition(&lemming, to: .walking, turn: true)
            } else if delta >= 4 {
                lemming.position.y += 4
                transition(&lemming, to: .falling)
            } else if delta >= -2 {
                lemming.position.y += delta
            } else {
                lemming.position.x -= lemming.direction.rawValue
            }
        }
    }

    mutating func updateMining(_ lemming: inout NeoLemmixLemming) {
        if lemming.animationFrame > 23 { lemming.animationFrame = 0 }
        if lemming.animationFrame == 1 || lemming.animationFrame == 2 {
            let phase = lemming.animationFrame - 1
            var removed = 0
            for forward in 0...7 {
                let centerY = lemming.position.y - 2 + forward / 2 + phase
                for offsetY in -2...2 {
                    let x = lemming.position.x + forward * lemming.direction.rawValue
                    let y = centerY + offsetY
                    if eraseDestructible(x: x, y: y, skill: .miner, direction: lemming.direction) {
                        removed += 1
                    }
                }
            }
            emitTerrainRemoved(lemmingID: lemming.id, count: removed)
        } else if lemming.animationFrame == 3 || lemming.animationFrame == 15 {
            let nextX = lemming.position.x + 2 * lemming.direction.rawValue
            let nextY = lemming.position.y + 1
            if isIndestructible(
                x: nextX,
                y: nextY - 1,
                skill: .miner,
                direction: lemming.direction
            ) {
                transition(&lemming, to: .walking, turn: true)
                return
            }
            lemming.position.x = nextX
            lemming.position.y = nextY
            if !terrain.isSolid(x: lemming.position.x, y: lemming.position.y) {
                lemming.position.y += 1
                transition(&lemming, to: .falling)
            }
        }
    }

    mutating func updateJumping(_ lemming: inout NeoLemmixLemming) {
        let patterns: [[NeoLemmixPoint]] = [
            [.init(x: 0, y: -1), .init(x: 0, y: -1), .init(x: 1, y: 0), .init(x: 0, y: -1), .init(x: 0, y: -1), .init(x: 1, y: 0)],
            [.init(x: 0, y: -1), .init(x: 1, y: 0), .init(x: 0, y: -1), .init(x: 1, y: 0), .init(x: 0, y: -1), .init(x: 1, y: 0)],
            [.init(x: 0, y: -1), .init(x: 1, y: 0), .init(x: 0, y: -1), .init(x: 1, y: 0), .init(x: 1, y: 0)],
            [.init(x: 0, y: -1), .init(x: 1, y: 0), .init(x: 1, y: 0), .init(x: 0, y: -1), .init(x: 1, y: 0)],
            [.init(x: 1, y: 0), .init(x: 1, y: 0), .init(x: 1, y: 0), .init(x: 1, y: 0)],
            [.init(x: 1, y: 0), .init(x: 0, y: 1), .init(x: 1, y: 0), .init(x: 1, y: 0), .init(x: 0, y: 1)],
            [.init(x: 1, y: 0), .init(x: 1, y: 0), .init(x: 0, y: 1), .init(x: 1, y: 0), .init(x: 0, y: 1)],
            [.init(x: 1, y: 0), .init(x: 0, y: 1), .init(x: 1, y: 0), .init(x: 0, y: 1), .init(x: 1, y: 0), .init(x: 0, y: 1)],
            [.init(x: 1, y: 0), .init(x: 0, y: 1), .init(x: 0, y: 1), .init(x: 1, y: 0), .init(x: 0, y: 1), .init(x: 0, y: 1)],
        ]
        let progress = lemming.actionProgress
        let patternIndex: Int
        switch progress {
        case 0...1: patternIndex = 0
        case 2...3: patternIndex = 1
        case 4...8: patternIndex = progress - 2
        case 9...10: patternIndex = 7
        case 11...12: patternIndex = 8
        default:
            transition(&lemming, to: .walking)
            return
        }

        var firstStep = progress == 0
        for step in patterns[patternIndex] {
            if step.x != 0 {
                let checkX = lemming.position.x + lemming.direction.rawValue
                if terrain.isSolid(x: checkX, y: lemming.position.y) {
                    var opening: Int?
                    for rise in 1...8 where !terrain.isSolid(x: checkX, y: lemming.position.y - rise) {
                        opening = rise
                        break
                    }
                    if let opening {
                        lemming.position.x = checkX
                        if opening <= 2 {
                            lemming.position.y -= opening - 1
                            transition(&lemming, to: .walking)
                        } else {
                            lemming.position.y -= opening - (opening <= 5 ? 5 : 8)
                            transition(&lemming, to: .hoisting)
                        }
                    } else if lemming.traits.contains(.climber) {
                        lemming.position.x = checkX
                        transition(&lemming, to: .climbing)
                    } else {
                        transition(&lemming, to: .falling, turn: true)
                    }
                    return
                }
            }
            if step.y < 0 && !firstStep {
                for rise in 1...9 where terrain.isSolid(
                    x: lemming.position.x,
                    y: lemming.position.y - rise
                ) {
                    transition(&lemming, to: .falling)
                    return
                }
            }
            lemming.position.x += step.x * lemming.direction.rawValue
            lemming.position.y += step.y
            if firstStep {
                firstStep = false
            } else if terrain.isSolid(x: lemming.position.x, y: lemming.position.y) {
                transition(&lemming, to: .walking)
                return
            }
        }
        lemming.actionProgress += 1
        lemming.animationFrame = lemming.actionProgress
        if lemming.actionProgress >= 8 && lemming.traits.contains(.glider) {
            transition(&lemming, to: .gliding)
        } else if lemming.actionProgress >= 13 {
            transition(&lemming, to: .walking)
        }
    }

    mutating func updateReaching(_ lemming: inout NeoLemmixLemming) {
        let movement = [0, 3, 2, 2, 1, 1, 1, 0]
        let frame = min(7, lemming.animationFrame)
        var emptyPixels = 4
        for offset in 0...3 where terrain.isSolid(
            x: lemming.position.x,
            y: lemming.position.y - 10 - offset
        ) {
            emptyPixels = offset
            break
        }
        if (5...8).contains(where: {
            terrain.isSolid(x: lemming.position.x, y: lemming.position.y - $0)
        }) || (frame == 1 && terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 9)) {
            transition(&lemming, to: .falling)
        } else if emptyPixels <= movement[frame] {
            lemming.position.y -= emptyPixels + 1
            transition(&lemming, to: .shimmying)
        } else {
            lemming.position.y -= movement[frame]
            if frame == 7 { transition(&lemming, to: .falling) }
        }
    }

    mutating func updateShimmying(_ lemming: inout NeoLemmixLemming) {
        if lemming.animationFrame > 19 { lemming.animationFrame = 0 }
        guard lemming.animationFrame.isMultiple(of: 2) else { return }
        let nextX = lemming.position.x + lemming.direction.rawValue
        for drop in 0...2 where terrain.isSolid(x: nextX, y: lemming.position.y - drop)
            && !terrain.isSolid(x: nextX, y: lemming.position.y - drop - 1) {
            lemming.position.x = nextX
            lemming.position.y -= drop
            transition(&lemming, to: .walking)
            return
        }
        for rise in 3...5 where terrain.isSolid(x: nextX, y: lemming.position.y - rise)
            && !terrain.isSolid(x: nextX, y: lemming.position.y - rise - 1) {
            lemming.position.x = nextX
            lemming.position.y -= rise - 4
            transition(&lemming, to: .hoisting)
            lemming.animationFrame = 2
            return
        }
        if (6...7).contains(where: {
            terrain.isSolid(x: nextX, y: lemming.position.y - $0)
        }) {
            if lemming.traits.contains(.slider) {
                lemming.position.x = nextX
                transition(&lemming, to: .sliding)
            } else {
                transition(&lemming, to: .falling)
            }
            return
        }
        guard terrain.isSolid(x: nextX, y: lemming.position.y - 9)
                || terrain.isSolid(x: nextX, y: lemming.position.y - 10),
              !(terrain.isSolid(x: nextX, y: lemming.position.y - 8)
                && !terrain.isSolid(x: nextX, y: lemming.position.y - 9)) else {
            transition(&lemming, to: .falling)
            return
        }
        lemming.position.x = nextX
        if terrain.isSolid(x: nextX, y: lemming.position.y - 8) {
            lemming.position.y += 1
        } else if !terrain.isSolid(x: nextX, y: lemming.position.y - 9) {
            lemming.position.y -= 1
        }
    }

    mutating func updateDisarming(_ lemming: inout NeoLemmixLemming) {
        lemming.actionProgress += 1
        if lemming.actionProgress < 42 { return }
        if let zoneID = lemming.targetZoneID {
            disabledZoneIDs.insert(zoneID)
            lastTickEvents.append(.zoneDisarmed(lemmingID: lemming.id, zoneID: zoneID))
        }
        lemming.targetZoneID = nil
        transition(&lemming, to: .walking)
    }
}
