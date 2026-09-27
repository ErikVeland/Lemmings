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
    case fencing
    case lasering
    case teleporting
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
    case splatPad
    case antiSplatPad
    case pickupSkill
    case lockedExit
    case unlockButton
    case forceLeft
    case forceRight
    case splitter
    case teleporter
    case receiver
    case animation
    case animationOnce
    case updraft
    case neutralizer
    case deneutralizer
    case addSkill
    case removeSkills
    case portal
}

public struct NeoLemmixSecondaryAnimationDefinition: Codable, Equatable, Sendable {
    public let frameCount: Int
    public let initialFrame: Int
    public let initialState: NxlvAnimationPlaybackState
    public let initiallyVisible: Bool
    public let triggers: [NxlvRenderedAnimationTrigger]

    public init(
        frameCount: Int,
        initialFrame: Int = 0,
        initialState: NxlvAnimationPlaybackState = .play,
        initiallyVisible: Bool = true,
        triggers: [NxlvRenderedAnimationTrigger] = []
    ) {
        self.frameCount = max(1, frameCount)
        self.initialFrame = min(max(0, initialFrame), self.frameCount - 1)
        self.initialState = initialState
        self.initiallyVisible = initiallyVisible
        self.triggers = triggers
    }

    public init(_ rendered: NxlvRenderedGadgetAnimation) {
        frameCount = max(1, rendered.framesRGBA.count)
        initialFrame = min(max(0, rendered.initialFrame), frameCount - 1)
        initialState = rendered.state
        initiallyVisible = rendered.initiallyVisible
        triggers = rendered.triggers
    }
}

public struct NeoLemmixSecondaryAnimationState: Codable, Equatable, Sendable {
    public var frame: Int
    public var state: NxlvAnimationPlaybackState
    public var isVisible: Bool

    public init(frame: Int, state: NxlvAnimationPlaybackState, isVisible: Bool) {
        self.frame = frame
        self.state = state
        self.isVisible = isVisible
    }
}

public struct NeoLemmixZone: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let effect: NeoLemmixZoneEffect
    public let bounds: NeoLemmixRect
    public let isDisarmable: Bool
    public let skill: NeoLemmixSkill?
    public let skillCount: Int?
    public let direction: NeoLemmixDirection?
    public let pairing: Int?
    public let flipsLemming: Bool?
    public let animationFrames: Int?
    public let keyFrame: Int?
    public let lemmingLimit: Int?
    public let visualGadgetID: Int?
    public let secondaryAnimations: [NeoLemmixSecondaryAnimationDefinition]?

    public init(
        id: Int,
        effect: NeoLemmixZoneEffect,
        bounds: NeoLemmixRect,
        isDisarmable: Bool = false,
        skill: NeoLemmixSkill? = nil,
        skillCount: Int? = nil,
        direction: NeoLemmixDirection? = nil,
        pairing: Int? = nil,
        flipsLemming: Bool = false,
        animationFrames: Int = 1,
        keyFrame: Int? = nil,
        lemmingLimit: Int? = nil,
        visualGadgetID: Int? = nil,
        secondaryAnimations: [NeoLemmixSecondaryAnimationDefinition]? = nil
    ) {
        self.id = id
        self.effect = effect
        self.bounds = bounds
        self.isDisarmable = isDisarmable
        self.skill = skill
        self.skillCount = skillCount
        self.direction = direction
        self.pairing = pairing
        self.flipsLemming = flipsLemming
        self.animationFrames = max(1, animationFrames)
        self.keyFrame = keyFrame
        self.lemmingLimit = lemmingLimit.flatMap { $0 > 0 ? $0 : nil }
        self.visualGadgetID = visualGadgetID
        self.secondaryAnimations = secondaryAnimations
    }
}

public struct NeoLemmixEntrance: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let position: NeoLemmixPoint
    public let direction: NeoLemmixDirection
    public let traits: Set<NeoLemmixTrait>
    public let lemmingLimit: Int?
    public let visualGadgetID: Int?
    public let secondaryAnimations: [NeoLemmixSecondaryAnimationDefinition]?

    public init(
        id: Int,
        position: NeoLemmixPoint,
        direction: NeoLemmixDirection = .right,
        traits: Set<NeoLemmixTrait> = [],
        lemmingLimit: Int? = nil,
        visualGadgetID: Int? = nil,
        secondaryAnimations: [NeoLemmixSecondaryAnimationDefinition]? = nil
    ) {
        self.id = id
        self.position = position
        self.direction = direction
        self.traits = traits
        self.lemmingLimit = lemmingLimit.flatMap { $0 > 0 ? $0 : nil }
        self.visualGadgetID = visualGadgetID
        self.secondaryAnimations = secondaryAnimations
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
    /// Current visual opacity. CE constructive pixels replace existing terrain
    /// only when its visual alpha is below 255.
    public private(set) var visualOpaqueMask: [UInt8]
    /// Zero means original or unpainted terrain. Values 1...12 identify CE's
    /// twelve constructive gradient steps. Optional for old saved states.
    public private(set) var constructionShadeMask: [UInt8]?
    /// The owning lemming ID plus one for pixels added by a Stoner. Optional
    /// for states written before terrain visual provenance was retained.
    public private(set) var stonerOwnerMask: [Int32]?
    /// The one-based source pixel within CE's 16-by-11 Stoner artwork.
    public private(set) var stonerSourceMask: [UInt16]?

    public init(
        width: Int,
        height: Int,
        solidMask: [UInt8],
        steelMask: [UInt8],
        oneWayMask: [UInt8],
        visualOpaqueMask: [UInt8]? = nil,
        constructionShadeMask: [UInt8]? = nil,
        stonerOwnerMask: [Int32]? = nil,
        stonerSourceMask: [UInt16]? = nil
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
        if let constructionShadeMask, constructionShadeMask.count != count {
            throw NeoLemmixSimulationError.invalidMask(
                name: "construction shade",
                expected: count,
                actual: constructionShadeMask.count
            )
        }
        if let visualOpaqueMask, visualOpaqueMask.count != count {
            throw NeoLemmixSimulationError.invalidMask(
                name: "visual opacity",
                expected: count,
                actual: visualOpaqueMask.count
            )
        }
        if let stonerOwnerMask, stonerOwnerMask.count != count {
            throw NeoLemmixSimulationError.invalidMask(
                name: "stoner owner",
                expected: count,
                actual: stonerOwnerMask.count
            )
        }
        if let stonerSourceMask, stonerSourceMask.count != count {
            throw NeoLemmixSimulationError.invalidMask(
                name: "stoner source",
                expected: count,
                actual: stonerSourceMask.count
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
        self.visualOpaqueMask = (visualOpaqueMask ?? solidMask).map { $0 == 0 ? 0 : 1 }
        self.constructionShadeMask = constructionShadeMask?.map { min($0, 12) }
        self.stonerOwnerMask = stonerOwnerMask
        self.stonerSourceMask = stonerSourceMask
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
        case visualOpaqueMask
        case constructionShadeMask
        case stonerOwnerMask
        case stonerSourceMask
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            width: container.decode(Int.self, forKey: .width),
            height: container.decode(Int.self, forKey: .height),
            solidMask: container.decode([UInt8].self, forKey: .solidMask),
            steelMask: container.decode([UInt8].self, forKey: .steelMask),
            oneWayMask: container.decode([UInt8].self, forKey: .oneWayMask),
            visualOpaqueMask: container.decodeIfPresent([UInt8].self, forKey: .visualOpaqueMask),
            constructionShadeMask: container.decodeIfPresent(
                [UInt8].self,
                forKey: .constructionShadeMask
            ),
            stonerOwnerMask: container.decodeIfPresent([Int32].self, forKey: .stonerOwnerMask),
            stonerSourceMask: container.decodeIfPresent([UInt16].self, forKey: .stonerSourceMask)
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

    public func constructionShade(x: Int, y: Int) -> Int? {
        guard contains(x: x, y: y),
              let value = constructionShadeMask?[y * width + x], value > 0 else { return nil }
        return Int(value - 1)
    }

    public func stonerOwnerID(x: Int, y: Int) -> Int? {
        guard contains(x: x, y: y),
              let value = stonerOwnerMask?[y * width + x], value > 0 else { return nil }
        return Int(value - 1)
    }

    public func stonerSourceIndex(x: Int, y: Int) -> Int? {
        guard contains(x: x, y: y),
              let value = stonerSourceMask?[y * width + x], value > 0 else { return nil }
        return Int(value - 1)
    }

    @discardableResult
    public mutating func setSolid(_ solid: Bool, x: Int, y: Int) -> Bool {
        guard contains(x: x, y: y) else { return false }
        let index = y * width + x
        let value: UInt8 = solid ? 1 : 0
        guard solidMask[index] != value else { return false }
        solidMask[index] = value
        visualOpaqueMask[index] = value
        constructionShadeMask?[index] = 0
        stonerOwnerMask?[index] = 0
        stonerSourceMask?[index] = 0
        if !solid {
            steelMask[index] = 0
            oneWayMask[index] = NeoLemmixOneWayDirection.none.rawValue
        }
        return true
    }

    @discardableResult
    public mutating func setConstructiveSolid(
        x: Int,
        y: Int,
        shade: Int
    ) -> Bool {
        guard contains(x: x, y: y) else { return false }
        let index = y * width + x
        guard solidMask[index] == 0 || visualOpaqueMask[index] == 0 else { return false }
        solidMask[index] = 1
        visualOpaqueMask[index] = 1
        if constructionShadeMask == nil {
            constructionShadeMask = Array(repeating: 0, count: solidMask.count)
        }
        constructionShadeMask?[index] = UInt8(min(11, max(0, shade)) + 1)
        stonerOwnerMask?[index] = 0
        stonerSourceMask?[index] = 0
        return true
    }

    @discardableResult
    public mutating func setStonerSolid(
        x: Int,
        y: Int,
        ownerID: Int,
        sourceIndex: Int
    ) -> Bool {
        guard contains(x: x, y: y), ownerID >= 0, ownerID < Int(Int32.max),
              sourceIndex >= 0, sourceIndex < Int(UInt16.max) else { return false }
        let index = y * width + x
        guard solidMask[index] == 0 else { return false }
        solidMask[index] = 1
        visualOpaqueMask[index] = 1
        constructionShadeMask?[index] = 0
        if stonerOwnerMask == nil {
            stonerOwnerMask = Array(repeating: 0, count: solidMask.count)
        }
        stonerOwnerMask?[index] = Int32(ownerID + 1)
        if stonerSourceMask == nil {
            stonerSourceMask = Array(repeating: 0, count: solidMask.count)
        }
        stonerSourceMask?[index] = UInt16(sourceIndex + 1)
        return true
    }

    @discardableResult
    public mutating func setSteel(_ steel: Bool, x: Int, y: Int) -> Bool {
        guard contains(x: x, y: y) else { return false }
        let index = y * width + x
        let value: UInt8 = steel ? 1 : 0
        guard steelMask[index] != value else { return false }
        steelMask[index] = value
        if steel {
            solidMask[index] = 1
            visualOpaqueMask[index] = 1
        }
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
        guard zones.allSatisfy({
            $0.effect != .pickupSkill || ($0.skill != nil && ($0.skillCount ?? 0) > 0)
        }) else {
            throw NeoLemmixSimulationError.invalidConfiguration(
                "Each skill pickup needs a known skill and a positive count."
            )
        }
        for teleporter in zones where teleporter.effect == .teleporter {
            guard let pairing = teleporter.pairing,
                  zones.contains(where: { $0.effect == .receiver && $0.pairing == pairing }) else {
                throw NeoLemmixSimulationError.invalidConfiguration(
                    "Each teleporter needs a paired receiver."
                )
            }
        }
        for portal in zones where portal.effect == .portal {
            guard let pairing = portal.pairing,
                  zones.contains(where: {
                      $0.id != portal.id && $0.effect == .portal && $0.pairing == pairing
                  }) else {
                throw NeoLemmixSimulationError.invalidConfiguration(
                    "Each portal needs a paired portal."
                )
            }
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

        for (visualGadgetID, rendered) in renderedLevel.gadgets.enumerated() {
            let source = sourceGadget(for: rendered)
            let secondaryAnimations = rendered.secondaryAnimations.isEmpty ? nil
                : rendered.secondaryAnimations.map(NeoLemmixSecondaryAnimationDefinition.init)
            let bounds = NeoLemmixRect(
                x: rendered.triggerX ?? rendered.x,
                y: rendered.triggerY ?? rendered.y,
                width: rendered.triggerWidth ?? max(1, rendered.width),
                height: rendered.triggerHeight ?? max(1, rendered.height)
            )
            switch rendered.effect {
            case .entrance:
                // CE stores horizontal gadget flipping and the deprecated
                // DIRECTION/FLIP_LEMMING spellings in the same physics flag.
                // They are aliases, not transformations that cancel out.
                let direction: NeoLemmixDirection = source?.direction == .left
                    || source?.flipLemming == true
                    || source?.flipHorizontal == true ? .left : .right
                entrances.append(NeoLemmixEntrance(
                    id: entrances.count,
                    position: NeoLemmixPoint(x: bounds.x, y: bounds.y),
                    direction: direction,
                    traits: Set((source?.lemmingTraits ?? []).map(NeoLemmixTrait.init)),
                    lemmingLimit: source?.lemmings.flatMap { $0 > 0 ? $0 : nil },
                    visualGadgetID: visualGadgetID,
                    secondaryAnimations: secondaryAnimations
                ))
            case .exit:
                zones.append(NeoLemmixZone(
                    id: zones.count,
                    effect: .exit,
                    bounds: bounds,
                    lemmingLimit: source?.lemmings,
                    visualGadgetID: visualGadgetID,
                    secondaryAnimations: secondaryAnimations
                ))
            case .lockedExit:
                zones.append(NeoLemmixZone(
                    id: zones.count,
                    effect: .lockedExit,
                    bounds: bounds,
                    animationFrames: rendered.animationFrames,
                    lemmingLimit: source?.lemmings,
                    visualGadgetID: visualGadgetID,
                    secondaryAnimations: secondaryAnimations
                ))
            case .unlockButton:
                zones.append(NeoLemmixZone(
                    id: zones.count,
                    effect: .unlockButton,
                    bounds: bounds,
                    animationFrames: rendered.animationFrames,
                    visualGadgetID: visualGadgetID,
                    secondaryAnimations: secondaryAnimations
                ))
            case .water:
                zones.append(NeoLemmixZone(id: zones.count, effect: .water, bounds: bounds))
            case .fire:
                zones.append(NeoLemmixZone(id: zones.count, effect: .fire, bounds: bounds))
            case .trap:
                zones.append(NeoLemmixZone(
                    id: zones.count,
                    effect: .trap,
                    bounds: bounds,
                    isDisarmable: true,
                    animationFrames: rendered.animationFrames,
                    visualGadgetID: visualGadgetID,
                    secondaryAnimations: secondaryAnimations
                ))
            case .trapOnce:
                zones.append(NeoLemmixZone(
                    id: zones.count,
                    effect: .oneShotTrap,
                    bounds: bounds,
                    isDisarmable: true,
                    animationFrames: rendered.animationFrames,
                    visualGadgetID: visualGadgetID,
                    secondaryAnimations: secondaryAnimations
                ))
            case .splatPad:
                zones.append(NeoLemmixZone(id: zones.count, effect: .splatPad, bounds: bounds))
            case .antiSplatPad:
                zones.append(NeoLemmixZone(id: zones.count, effect: .antiSplatPad, bounds: bounds))
            case .pickupSkill:
                guard let skill = source?.skillType else {
                    throw NeoLemmixSimulationError.invalidConfiguration(
                        "A skill pickup has no known skill."
                    )
                }
                zones.append(NeoLemmixZone(
                    id: zones.count,
                    effect: .pickupSkill,
                    bounds: bounds,
                    skill: NeoLemmixSkill(skill),
                    skillCount: max(1, source?.skillCount ?? 1),
                    visualGadgetID: visualGadgetID,
                    secondaryAnimations: secondaryAnimations
                ))
            case .forceLeft:
                zones.append(NeoLemmixZone(id: zones.count, effect: .forceLeft, bounds: bounds))
            case .forceRight:
                zones.append(NeoLemmixZone(id: zones.count, effect: .forceRight, bounds: bounds))
            case .splitter:
                zones.append(NeoLemmixZone(
                    id: zones.count,
                    effect: .splitter,
                    bounds: bounds,
                    direction: source?.direction == .left || source?.flipHorizontal == true
                        ? .left : .right
                ))
            case .teleporter, .receiver:
                zones.append(NeoLemmixZone(
                    id: zones.count,
                    effect: rendered.effect == .teleporter ? .teleporter : .receiver,
                    bounds: bounds,
                    pairing: source?.pairing,
                    flipsLemming: source?.flipLemming == true || source?.flipHorizontal == true,
                    animationFrames: rendered.animationFrames,
                    keyFrame: rendered.keyFrame,
                    visualGadgetID: visualGadgetID,
                    secondaryAnimations: secondaryAnimations
                ))
            case .animation, .animationOnce:
                zones.append(NeoLemmixZone(
                    id: zones.count,
                    effect: rendered.effect == .animation ? .animation : .animationOnce,
                    bounds: bounds,
                    animationFrames: rendered.animationFrames,
                    visualGadgetID: visualGadgetID,
                    secondaryAnimations: secondaryAnimations
                ))
            case .updraft:
                zones.append(NeoLemmixZone(id: zones.count, effect: .updraft, bounds: bounds))
            case .neutralizer:
                zones.append(NeoLemmixZone(id: zones.count, effect: .neutralizer, bounds: bounds))
            case .deneutralizer:
                zones.append(NeoLemmixZone(id: zones.count, effect: .deneutralizer, bounds: bounds))
            case .addSkill:
                guard let skill = source?.skillType else {
                    throw NeoLemmixSimulationError.invalidConfiguration(
                        "A skill-adder object has no known permanent skill."
                    )
                }
                zones.append(NeoLemmixZone(
                    id: zones.count,
                    effect: .addSkill,
                    bounds: bounds,
                    skill: NeoLemmixSkill(skill)
                ))
            case .removeSkills:
                zones.append(NeoLemmixZone(id: zones.count, effect: .removeSkills, bounds: bounds))
            case .portal:
                zones.append(NeoLemmixZone(
                    id: zones.count,
                    effect: .portal,
                    bounds: bounds,
                    pairing: source?.pairing
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
        var effectiveTotal = max(level.lemmingsCount, preplaced.count)
        if entrances.isEmpty {
            effectiveTotal = preplaced.count
        } else if entrances.allSatisfy({ $0.lemmingLimit != nil }) {
            let entranceCapacity = entrances.compactMap(\.lemmingLimit).reduce(0, +)
            effectiveTotal = min(effectiveTotal, preplaced.count + entranceCapacity)
        }

        // CE builds the entrance order before it validates the rescue target, so
        // only zombies that can actually hatch reduce the possible save count.
        var zombieCount = preplaced.filter { $0.traits.contains(.zombie) }.count
        var remainingEntranceCapacity = entrances.map(\.lemmingLimit)
        var entranceCursor = 0
        for _ in 0..<max(0, effectiveTotal - preplaced.count) {
            var selected: Int?
            for offset in 0..<entrances.count {
                let index = (entranceCursor + offset) % entrances.count
                if remainingEntranceCapacity[index] == nil
                    || (remainingEntranceCapacity[index] ?? 0) > 0 {
                    selected = index
                    break
                }
            }
            guard let selected else { break }
            if entrances[selected].traits.contains(.zombie) { zombieCount += 1 }
            if let capacity = remainingEntranceCapacity[selected] {
                remainingEntranceCapacity[selected] = capacity - 1
            }
            entranceCursor = (selected + 1) % entrances.count
        }

        let inventoryCloners: Int
        switch skills[.cloner] ?? .finite(0) {
        case let .finite(count): inventoryCloners = min(max(0, count), 99)
        case .infinite: inventoryCloners = 99
        }
        let pickupCloners = zones.reduce(into: 0) { count, zone in
            if zone.effect == .pickupSkill && zone.skill == .cloner {
                count += max(0, zone.skillCount ?? 0)
            }
        }
        var effectiveRequired = min(
            level.saveRequirement,
            max(0, effectiveTotal + inventoryCloners + pickupCloners - zombieCount)
        )
        let exits = zones.filter { $0.effect == .exit || $0.effect == .lockedExit }
        if exits.allSatisfy({ $0.lemmingLimit != nil }) {
            effectiveRequired = min(
                effectiveRequired,
                exits.compactMap(\.lemmingLimit).reduce(0, +)
            )
        }
        try self.init(
            totalLemmings: effectiveTotal,
            requiredToSave: effectiveRequired,
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
        .stacker, .laserer, .basher, .fencer, .miner, .digger, .cloner,
    ]

    public static let unsupportedSkills: Set<NeoLemmixSkill> = []
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
    public var placedBrick: Bool?
    public var targetZoneID: Int?
    public var laserHitPoint: NeoLemmixPoint?
    public var lastSplitterZoneID: Int?
    public var teleportTargetZoneID: Int?
    public var teleportTicksRemaining: Int?
    public var teleportReturnAction: NeoLemmixAction?
    public var portalTargetZoneID: Int?
    public var portalWarpFrame: Int?
    public var lastPortalZoneID: Int?
    public var dehoistPinY: Int?
    public var cloneParentID: Int?
    public var pendingRemovalReason: NeoLemmixRemovalReason?
    public var removalReason: NeoLemmixRemovalReason?
    public var isStartingAction: Bool
    /// CE permanently excludes a lemming from skill-adder gadgets after its
    /// first Oh-No transition. Optional for older encoded recovery states.
    public var hasBeenOhNo: Bool?

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
        self.placedBrick = nil
        self.targetZoneID = nil
        self.laserHitPoint = nil
        self.lastSplitterZoneID = nil
        self.teleportTargetZoneID = nil
        self.teleportTicksRemaining = nil
        self.teleportReturnAction = nil
        self.portalTargetZoneID = nil
        self.portalWarpFrame = nil
        self.lastPortalZoneID = nil
        self.dehoistPinY = nil
        self.cloneParentID = cloneParentID
        self.pendingRemovalReason = nil
        self.removalReason = nil
        self.isStartingAction = true
        self.hasBeenOhNo = false
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
    case skillPickedUp(lemmingID: Int, zoneID: Int, skill: NeoLemmixSkill, count: Int)
    case buttonPressed(lemmingID: Int, zoneID: Int)
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
    public let splitterDirections: [Int: NeoLemmixDirection]?
    public let remainingZoneLemmingCounts: [Int: Int]?
    public let gadgetAnimationFrames: [Int: Int]?
    public let secondaryAnimationStates: [Int: [NeoLemmixSecondaryAnimationState]]?
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
    public private(set) var splitterDirections: [Int: NeoLemmixDirection]?
    /// Current primary-animation frame for stateful gadgets. Optional so
    /// recovery files written before live gadget animation remain decodable.
    public private(set) var gadgetAnimationFrames: [Int: Int]?
    /// Live secondary-animation frames keyed by retained visual gadget index.
    /// Optional for recovery files written before secondary state was retained.
    public private(set) var secondaryAnimationStates: [Int: [NeoLemmixSecondaryAnimationState]]?
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
    /// Exclusive tick at which a triggered gadget becomes ready again. Optional
    /// so older encoded states decode with no busy gadgets.
    private var gadgetBusyUntil: [Int: Int]?
    /// Gadgets currently advancing toward their permanent frame-zero state.
    /// Optional for backward-compatible recovery decoding.
    private var gadgetAnimatingZoneIDs: Set<Int>?
    /// Remaining capacity for finite entrances to exits. Optional so states
    /// written before exit limits were implemented still decode.
    private var remainingZoneLemmingCounts: [Int: Int]?

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
        self.splitterDirections = Dictionary(uniqueKeysWithValues: configuration.zones.compactMap {
            $0.effect == .splitter ? ($0.id, $0.direction ?? .right) : nil
        })
        let hasButtons = configuration.zones.contains { $0.effect == .unlockButton }
        self.gadgetAnimationFrames = Dictionary(uniqueKeysWithValues:
            configuration.zones.compactMap { zone in
                guard [
                    NeoLemmixZoneEffect.unlockButton, .lockedExit, .trap, .oneShotTrap,
                    .animation, .animationOnce,
                ].contains(zone.effect) else { return nil }
                let frameCount = max(1, zone.animationFrames ?? 1)
                let startsOpen = zone.effect == .lockedExit && !hasButtons
                let startsOnFrameOne = zone.effect == .unlockButton
                    || zone.effect == .oneShotTrap
                    || zone.effect == .animationOnce
                    || (zone.effect == .lockedExit && !startsOpen)
                return (zone.id, startsOnFrameOne && frameCount > 1 ? 1 : 0)
            })
        self.secondaryAnimationStates = [:]
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
        self.gadgetBusyUntil = [:]
        self.gadgetAnimatingZoneIDs = []
        self.remainingZoneLemmingCounts = Dictionary(uniqueKeysWithValues:
            configuration.zones.compactMap { zone in
                guard (zone.effect == .exit || zone.effect == .lockedExit),
                      let limit = zone.lemmingLimit else { return nil }
                return (zone.id, limit)
            })
        initializeSecondaryAnimations()
    }

    public init(level: NxlvLevel, renderedLevel: NxlvRenderedLevel) throws {
        let configuration = try NeoLemmixConfiguration(level: level, renderedLevel: renderedLevel)
        let terrain = try NeoLemmixTerrain(
            width: renderedLevel.width,
            height: renderedLevel.height,
            solidMask: renderedLevel.solidMask,
            steelMask: renderedLevel.steelMask,
            oneWayMask: renderedLevel.oneWayMask,
            visualOpaqueMask: renderedLevel.terrainOpaqueMask
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
            splitterDirections: splitterDirections,
            remainingZoneLemmingCounts: remainingZoneLemmingCounts,
            gadgetAnimationFrames: gadgetAnimationFrames,
            secondaryAnimationStates: secondaryAnimationStates,
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

        let updateIDs = lemmings.filter(\.isActive).map(\.id).sorted()
        for id in updateIDs {
            updateLemming(id: id)
        }
        updateNuke()
        applyZombieInfection()
        updateGadgetAnimations()
        updateSecondaryAnimations()
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
    mutating func initializeSecondaryAnimations() {
        var states: [Int: [NeoLemmixSecondaryAnimationState]] = [:]
        for entrance in configuration.entrances {
            guard let visualID = entrance.visualGadgetID,
                  let animations = entrance.secondaryAnimations else { continue }
            states[visualID] = animations.map {
                NeoLemmixSecondaryAnimationState(
                    frame: $0.initialFrame,
                    state: $0.initialState,
                    isVisible: $0.initiallyVisible
                )
            }
        }
        for zone in configuration.zones {
            guard let visualID = zone.visualGadgetID,
                  let animations = zone.secondaryAnimations else { continue }
            states[visualID] = animations.map {
                NeoLemmixSecondaryAnimationState(
                    frame: $0.initialFrame,
                    state: $0.initialState,
                    isVisible: $0.initiallyVisible
                )
            }
        }
        secondaryAnimationStates = states
        updateSecondaryAnimations(advanceFrames: false)
    }

    mutating func updateSecondaryAnimations(advanceFrames: Bool = true) {
        guard secondaryAnimationStates != nil else { secondaryAnimationStates = [:]; return }
        for entrance in configuration.entrances {
            guard let visualID = entrance.visualGadgetID,
                  let definitions = entrance.secondaryAnimations,
                  var states = secondaryAnimationStates?[visualID] else { continue }
            for index in definitions.indices where states.indices.contains(index) {
                updateSecondaryAnimation(
                    definition: definitions[index],
                    state: &states[index],
                    condition: { entranceTrigger($0, entrance: entrance) },
                    primaryFrame: entrancePrimaryFrame(),
                    advanceFrame: advanceFrames
                )
            }
            secondaryAnimationStates?[visualID] = states
        }
        for zone in configuration.zones {
            guard let visualID = zone.visualGadgetID,
                  let definitions = zone.secondaryAnimations,
                  var states = secondaryAnimationStates?[visualID] else { continue }
            for index in definitions.indices where states.indices.contains(index) {
                updateSecondaryAnimation(
                    definition: definitions[index],
                    state: &states[index],
                    condition: { zoneTrigger($0, zone: zone) },
                    primaryFrame: primaryFrame(for: zone),
                    advanceFrame: advanceFrames
                )
            }
            secondaryAnimationStates?[visualID] = states
        }
    }

    func entranceTrigger(
        _ condition: NxlvAnimationTriggerCondition,
        entrance: NeoLemmixEntrance
    ) -> Bool {
        let exhausted: Bool
        if let limit = entrance.lemmingLimit,
           let index = configuration.entrances.firstIndex(where: { $0.id == entrance.id }) {
            exhausted = entranceSpawnCounts[index] >= limit
        } else {
            exhausted = false
        }
        return switch condition {
        case .unconditional: true
        case .ready: entrancesAreOpen && !exhausted
        case .busy: entrancesAreOpen && entrancePrimaryFrame() != 0
        case .disabled, .exhausted: exhausted
        }
    }

    func zoneTrigger(_ condition: NxlvAnimationTriggerCondition, zone: NeoLemmixZone) -> Bool {
        let disabled = disabledZoneIDs.contains(zone.id)
        let locallyBusy = (gadgetBusyUntil?[zone.id] ?? 0) > tickCount
            || (gadgetAnimatingZoneIDs?.contains(zone.id) == true)
        let pairedBusy: Bool
        if let pairing = zone.pairing,
           zone.effect == .teleporter || zone.effect == .receiver {
            pairedBusy = configuration.zones.contains {
                $0.id != zone.id && $0.pairing == pairing
                    && ($0.effect == .teleporter || $0.effect == .receiver)
                    && ((gadgetBusyUntil?[$0.id] ?? 0) > tickCount
                        || gadgetAnimatingZoneIDs?.contains($0.id) == true)
            }
        } else {
            pairedBusy = false
        }
        let busy = locallyBusy || pairedBusy
        let hasPair: Bool
        if let pairing = zone.pairing, zone.effect == .teleporter {
            hasPair = configuration.zones.contains { $0.effect == .receiver && $0.pairing == pairing }
        } else if let pairing = zone.pairing, zone.effect == .receiver {
            hasPair = configuration.zones.contains { $0.effect == .teleporter && $0.pairing == pairing }
        } else {
            hasPair = zone.effect != .teleporter && zone.effect != .receiver
        }
        let remaining = remainingZoneLemmingCounts?[zone.id]
        let exhausted = remaining == 0 || [
            NeoLemmixZoneEffect.pickupSkill, .unlockButton, .oneShotTrap, .animationOnce,
        ].contains(zone.effect) && frameForExhaustion(zone) == 0
        let frame = primaryFrame(for: zone)
        switch condition {
        case .unconditional:
            return true
        case .ready:
            switch zone.effect {
            case .exit: return true
            case .lockedExit: return !exhausted && frame == 0
            case .unlockButton, .oneShotTrap, .animationOnce: return frame == 1 && !disabled
            case .trap, .animation: return !disabled && !busy && frame == 0
            case .teleporter, .receiver: return hasPair && !disabled && !busy && frame == 0
            case .pickupSkill: return frame % 2 != 0
            default: return true
            }
        case .busy:
            switch zone.effect {
            case .lockedExit, .unlockButton, .oneShotTrap, .animationOnce: return frame > 1
            case .trap, .animation, .teleporter, .receiver: return busy || frame > 0
            default: return busy
            }
        case .disabled:
            switch zone.effect {
            case .exit, .lockedExit: return exhausted || (zone.effect == .lockedExit && frame == 1)
            case .unlockButton: return frame == 0
            case .oneShotTrap, .animationOnce: return disabled || frame == 0
            case .pickupSkill: return frame % 2 == 0
            case .trap: return disabled
            case .teleporter, .receiver: return !hasPair
            default: return false
            }
        case .exhausted:
            switch zone.effect {
            case .exit, .lockedExit, .pickupSkill, .unlockButton, .oneShotTrap, .animationOnce:
                return exhausted
            default:
                return false
            }
        }
    }

    func frameForExhaustion(_ zone: NeoLemmixZone) -> Int {
        primaryFrame(for: zone)
    }

    func primaryFrame(for zone: NeoLemmixZone) -> Int {
        if let frame = gadgetAnimationFrames?[zone.id] { return frame }
        if zone.effect == .pickupSkill { return disabledZoneIDs.contains(zone.id) ? 0 : 1 }
        if (gadgetBusyUntil?[zone.id] ?? 0) > tickCount {
            let frameCount = max(1, zone.animationFrames ?? 1)
            return max(1, frameCount - max(0, (gadgetBusyUntil?[zone.id] ?? tickCount) - tickCount))
                % frameCount
        }
        return 0
    }

    func entrancePrimaryFrame() -> Int {
        guard entrancesAreOpen else { return 1 }
        let elapsed = max(0, tickCount - configuration.entranceOpenTick)
        return elapsed == 0 ? 2 : 0
    }

    func updateSecondaryAnimation(
        definition: NeoLemmixSecondaryAnimationDefinition,
        state: inout NeoLemmixSecondaryAnimationState,
        condition: (NxlvAnimationTriggerCondition) -> Bool,
        primaryFrame: Int,
        advanceFrame: Bool
    ) {
        if let trigger = definition.triggers.last(where: { condition($0.condition) }) {
            state.state = trigger.state
            state.isVisible = trigger.isVisible
        } else {
            state.state = definition.initialState
            state.isVisible = definition.initiallyVisible
        }
        let count = max(1, definition.frameCount)
        if advanceFrame, state.state != .pause,
           !(state.state == .loopToZero && state.frame == 0) {
            state.frame = (state.frame + 1) % count
        }
        switch state.state {
        case .stop:
            state.frame = 0
            state.state = .pause
        case .loopToZero where state.frame == 0:
            state.state = .pause
        case .matchPrimary:
            state.frame = primaryFrame % count
        case .play, .pause, .loopToZero:
            break
        }
    }

    /// CE advances a pressed button and every newly unlocked exit after all
    /// lemmings have been processed for the tick. The animation then settles
    /// permanently on frame zero.
    mutating func updateGadgetAnimations() {
        guard let active = gadgetAnimatingZoneIDs, !active.isEmpty else { return }
        if gadgetAnimationFrames == nil { gadgetAnimationFrames = [:] }
        var finished: Set<Int> = []
        for zoneID in active.sorted() {
            guard let zone = configuration.zones.first(where: { $0.id == zoneID }) else {
                finished.insert(zoneID)
                continue
            }
            let frameCount = max(1, zone.animationFrames ?? 1)
            let nextFrame = (gadgetAnimationFrames?[zoneID] ?? 1) + 1
            if nextFrame >= frameCount {
                gadgetAnimationFrames?[zoneID] = 0
                finished.insert(zoneID)
            } else {
                gadgetAnimationFrames?[zoneID] = nextFrame
            }
        }
        gadgetAnimatingZoneIDs?.subtract(finished)
    }

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
        guard lemmings[index].portalWarpFrame == nil else {
            return .rejected(lemmingID: lemmingID, skill: skill, reason: .invalidCurrentAction)
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
        case .fencer:
            transition(&lemming, to: .fencing)
        case .laserer:
            transition(&lemming, to: .lasering)
        case .miner:
            transition(&lemming, to: .mining)
        case .digger:
            transition(&lemming, to: .digging)
        case .cloner:
            clone(lemming)
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
            .drowning, .vaporizing, .teleporting, .removed,
        ]
        let workActions: Set<NeoLemmixAction> = [
            .walking, .shrugging, .platforming, .building, .stacking, .bashing,
            .fencing, .lasering, .mining, .digging,
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
                : terminal.subtracting([.drowning]).contains(lemming.action)
                    ? .invalidCurrentAction : nil
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
            // CE lets ground-based workers start the Reacher even without a
            // ceiling. The Reacher itself decides whether it catches one.
            if workActions.contains(lemming.action) { return nil }
            let x = lemming.position.x
            let y = lemming.position.y
            if lemming.action == .jumping {
                for offset in -1...3 where
                    terrain.isSolid(x: x, y: y - 9 - offset)
                    && !terrain.isSolid(x: x, y: y - 8 - offset) {
                    return nil
                }
                return .noCeiling
            }
            return (terrain.isSolid(x: x, y: y - 9) || terrain.isSolid(x: x, y: y - 10))
                ? nil : .noCeiling
        case .bomber, .stoner:
            return terminal.contains(lemming.action) || lemming.action == .drowning
                ? .invalidCurrentAction : nil
        case .blocker:
            guard workActions.contains(lemming.action) else { return .invalidCurrentAction }
            guard !blockerFieldOverlaps(lemming) else { return .overlappingBlockerField }
            return nil
        case .builder:
            let allowed = workActions.subtracting([.building])
            return allowed.contains(lemming.action) ? nil : .invalidCurrentAction
        case .platformer:
            let allowed = workActions.subtracting([.platforming])
            return allowed.contains(lemming.action) ? nil : .invalidCurrentAction
        case .stacker:
            let allowed = workActions.subtracting([.stacking])
            return allowed.contains(lemming.action) ? nil : .invalidCurrentAction
        case .basher:
            let allowed = workActions.subtracting([.bashing])
            return allowed.contains(lemming.action) ? nil : .invalidCurrentAction
        case .fencer:
            let allowed = workActions.subtracting([.fencing])
            return allowed.contains(lemming.action) ? nil : .invalidCurrentAction
        case .laserer:
            return workActions.subtracting([.lasering]).contains(lemming.action)
                ? nil : .invalidCurrentAction
        case .miner:
            guard workActions.subtracting([.mining]).contains(lemming.action) else {
                return .invalidCurrentAction
            }
            return isIndestructible(
                x: lemming.position.x,
                y: lemming.position.y,
                skill: .miner,
                direction: lemming.direction
            ) ? .blockedBySteelOrOneWay : nil
        case .digger:
            guard workActions.subtracting([.digging]).contains(lemming.action) else {
                return .invalidCurrentAction
            }
            return isIndestructible(
                x: lemming.position.x,
                y: lemming.position.y,
                skill: .digger,
                direction: lemming.direction
            ) ? .blockedBySteelOrOneWay : nil
        case .cloner:
            let allowed = workActions.union([
                .ascending, .falling, .floating, .gliding, .swimming,
                .disarming, .reaching, .shimmying, .jumping, .lasering,
            ])
            return allowed.contains(lemming.action) ? nil : .invalidCurrentAction
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
        clone.placedBrick = source.placedBrick
        clone.laserHitPoint = source.laserHitPoint
        clone.lastSplitterZoneID = source.lastSplitterZoneID
        clone.teleportTargetZoneID = source.teleportTargetZoneID
        clone.teleportTicksRemaining = source.teleportTicksRemaining
        clone.teleportReturnAction = source.teleportReturnAction
        clone.portalTargetZoneID = source.portalTargetZoneID
        clone.portalWarpFrame = source.portalWarpFrame
        clone.lastPortalZoneID = source.lastPortalZoneID
        clone.dehoistPinY = source.dehoistPinY
        clone.isStartingAction = source.isStartingAction
        clone.hasBeenOhNo = source.hasBeenOhNo
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
        while nukeCursor < lemmings.count - 1 && !lemmings[nukeCursor].isActive {
            nukeCursor += 1
        }
        guard nukeCursor < lemmings.count else { return }
        if lemmings[nukeCursor].bomberCountdown == nil,
           ![.splatting, .exploding].contains(lemmings[nukeCursor].action) {
            lemmings[nukeCursor].bomberCountdown = NeoLemmixRules.bomberCountdownTicks
            lemmings[nukeCursor].pendingExplosionSkill = .bomber
        }
        nukeCursor += 1
        nukeCountdown = 0
    }

    mutating func applyZombieInfection() {
        let zombies = lemmings.filter { $0.isActive && $0.traits.contains(.zombie) }
        guard !zombies.isEmpty else { return }
        for index in lemmings.indices where lemmings[index].isActive
            && lemmings[index].action != .exiting
            && !lemmings[index].traits.contains(.zombie) {
            let candidate = lemmings[index].position
            let infected = zombies.contains { zombie in
                guard (zombie.position.y - 6...zombie.position.y + 4).contains(candidate.y) else {
                    return false
                }
                return (zombie.position.x - 5...zombie.position.x + 5).contains(candidate.x)
                    || candidate.x == zombie.position.x + 6 * zombie.direction.rawValue
            }
            if infected { lemmings[index].traits.insert(.zombie) }
        }
    }

    mutating func transition(
        _ lemming: inout NeoLemmixLemming,
        to action: NeoLemmixAction,
        turn: Bool = false
    ) {
        if turn { lemming.direction = lemming.direction.opposite }
        let old = lemming.action
        let oldIsStartingAction = lemming.isStartingAction
        let target: NeoLemmixAction = action == .walking
            && !terrain.isSolid(x: lemming.position.x, y: lemming.position.y)
            ? .falling : action
        guard old != target else { return }
        if target == .ohNo || target == .stoning {
            lemming.hasBeenOhNo = true
            lemming.traits.subtract([
                .slider, .climber, .swimmer, .floater, .glider, .disarmer,
            ])
        }

        if target == .falling, old != .swimming {
            switch old {
            case .walking, .bashing:
                lemming.fallDistance = 3
            case .mining, .digging:
                lemming.fallDistance = 0
            case .blocking, .jumping, .lasering:
                lemming.fallDistance = -1
            default:
                lemming.fallDistance = 1
            }
            lemming.trueFallDistance = lemming.fallDistance
        }

        if (target == .shimmying || target == .jumping) && old == .climbing
            || target == .jumping && old == .sliding {
            lemming.direction = lemming.direction.opposite
            lemming.position.x += lemming.direction.rawValue
            if target == .shimmying,
               terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 8) {
                lemming.position.y += 1
            }
        }
        if target == .shimmying && old == .sliding {
            lemming.position.y += 2
            if terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 8) {
                lemming.position.y += 1
            }
        }
        if target == .shimmying && old == .dehoisting {
            lemming.position.y += 2
            if terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 8) {
                lemming.position.y += 1
            }
        }
        if target == .shimmying && old == .jumping {
            for offset in -1...3 where
                terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 9 - offset)
                && !terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 8 - offset) {
                lemming.position.y -= offset
                break
            }
        }

        lemming.action = target
        lemming.animationFrame = 0
        lemming.actionProgress = 0
        lemming.isStartingAction = target == .hoisting ? oldIsStartingAction : true
        lemming.targetZoneID = target == .disarming ? lemming.targetZoneID : nil
        if target == .dehoisting {
            lemming.dehoistPinY = lemming.position.y
        } else if target != .sliding {
            lemming.dehoistPinY = nil
        }
        if target != .lasering { lemming.laserHitPoint = nil }
        switch target {
        case .building, .platforming:
            lemming.bricksRemaining = 12
            lemming.placedBrick = nil
        case .stacking:
            lemming.bricksRemaining = 8
        case .lasering:
            lemming.actionProgress = 10
        default:
            break
        }
        if target == .swimming {
            var rise = 0
            while rise < 4,
                  isInWater(NeoLemmixPoint(
                    x: lemming.position.x,
                    y: lemming.position.y - rise - 1
                  )),
                  !terrain.isSolid(
                    x: lemming.position.x,
                    y: lemming.position.y - rise - 1
                  ) {
                rise += 1
            }
            lemming.position.y -= rise
        }
        if target == .blocking { lemming.traits.insert(.blocker) }
        if lemming.traits.contains(.blocker),
           ![.blocking, .ohNo, .stoning].contains(target) {
            lemming.traits.remove(.blocker)
        }
        lastTickEvents.append(.actionChanged(lemmingID: lemming.id, from: old, to: target))
    }

    mutating func remove(
        _ lemming: inout NeoLemmixLemming,
        reason: NeoLemmixRemovalReason
    ) {
        guard lemming.isActive else { return }
        if reason == .saved { savedCount += 1 } else { lostCount += 1 }
        lemming.traits.remove(.blocker)
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

    func sliderHasPixelAt(_ lemming: NeoLemmixLemming, x: Int, y: Int) -> Bool {
        if terrain.isSolid(x: x, y: y) { return true }
        return x == lemming.position.x
            && y == lemming.dehoistPinY
            && y >= 0
            && terrain.isSolid(x: x, y: y + 1)
    }

    mutating func sliderTerrainChecks(
        _ lemming: inout NeoLemmixLemming,
        maximumYCheckOffset: Int = 7
    ) -> Bool {
        let x = lemming.position.x
        let y = lemming.position.y
        if sliderHasPixelAt(lemming, x: x, y: y)
            && !sliderHasPixelAt(lemming, x: x, y: y - 1) {
            transition(&lemming, to: .walking)
            return false
        }
        if !sliderHasPixelAt(
            lemming,
            x: x,
            y: y - min(maximumYCheckOffset, 7)
        ) {
            transition(&lemming, to: .falling)
            return false
        }
        guard sliderHasPixelAt(lemming, x: x, y: y) else { return true }

        let behindX = x - lemming.direction.rawValue
        if isInWater(NeoLemmixPoint(x: behindX, y: y)) {
            lemming.position.x = behindX
            transition(
                &lemming,
                to: lemming.traits.contains(.swimmer) ? .swimming : .drowning,
                turn: true
            )
            return false
        }
        if sliderHasPixelAt(lemming, x: behindX, y: y) {
            lemming.position.x = behindX
            transition(&lemming, to: .walking, turn: true)
            return false
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
        length: Int,
        shade: Int
    ) -> Int {
        guard length > 0 else { return 0 }
        var added = 0
        for offset in 0..<length {
            if terrain.setConstructiveSolid(
                x: x + offset * direction.rawValue,
                y: y,
                shade: shade
            ) {
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
        let candidateStart = candidate.position.x - 6
            + (candidate.direction == .right ? 1 : 0)
        let vertices = [
            NeoLemmixPoint(x: candidateStart, y: candidate.position.y - 6),
            NeoLemmixPoint(x: candidateStart + 11, y: candidate.position.y - 6),
            NeoLemmixPoint(x: candidateStart, y: candidate.position.y + 4),
            NeoLemmixPoint(x: candidateStart + 11, y: candidate.position.y + 4),
        ]
        return lemmings.contains { blocker in
            guard blocker.id != candidate.id,
                  blocker.isActive,
                  blocker.traits.contains(.blocker) else { return false }
            let blockerStart = blocker.position.x - 6
                + (blocker.direction == .right ? 1 : 0)
            // CE tests the candidate field's four vertices against only the
            // existing field's central DOM_BLOCKER band. Its two force lobes
            // do not count as an overlapping blocker field.
            let blockerX = blockerStart + 4...blockerStart + 7
            let blockerY = blocker.position.y - 6...blocker.position.y + 4
            return vertices.contains { blockerX.contains($0.x) && blockerY.contains($0.y) }
        }
    }

    func blockerForcedDirection(_ lemming: NeoLemmixLemming) -> NeoLemmixDirection? {
        lemmings.compactMap { blocker -> NeoLemmixDirection? in
            guard blocker.id != lemming.id, blocker.isActive, blocker.traits.contains(.blocker),
                  (blocker.position.y - 6...blocker.position.y + 4).contains(lemming.position.y) else {
                return nil
            }
            if lemming.action == .building {
                let distance = blocker.direction == lemming.direction ? 2 : 3
                let checkX = lemming.position.x + distance * lemming.direction.rawValue
                if blocker.position.x == checkX,
                   (blocker.position.y - 1...blocker.position.y + 3).contains(lemming.position.y) {
                    return nil
                }
            }
            let fieldStart = blocker.position.x - 6 + (blocker.direction == .right ? 1 : 0)
            if (fieldStart...fieldStart + 3).contains(lemming.position.x) { return .left }
            if (fieldStart + 8...fieldStart + 11).contains(lemming.position.x) { return .right }
            return nil
        }.last
    }

    func isInWater(_ point: NeoLemmixPoint) -> Bool {
        configuration.zones.contains {
            !disabledZoneIDs.contains($0.id) && $0.effect == .water && $0.bounds.contains(point)
        }
    }

    func isInUpdraft(_ point: NeoLemmixPoint) -> Bool {
        configuration.zones.contains {
            !disabledZoneIDs.contains($0.id) && $0.effect == .updraft && $0.bounds.contains(point)
        }
    }

    func movementPath(
        from start: NeoLemmixPoint,
        to end: NeoLemmixPoint,
        oldAction: NeoLemmixAction,
        currentAction: NeoLemmixAction
    ) -> [NeoLemmixPoint] {
        var result: [NeoLemmixPoint] = [start]
        var current = start
        func moveHorizontal() {
            while current.x != end.x {
                current.x += current.x < end.x ? 1 : -1
                result.append(current)
            }
        }
        func moveVertical() {
            while current.y != end.y {
                current.y += current.y < end.y ? 1 : -1
                result.append(current)
            }
        }

        // CE checks gadget pixels in an action-specific order. Miners check
        // the first downward pixel before moving horizontally. Builders check
        // vertical movement before horizontal movement even while stepping up.
        if oldAction == .mining {
            if current.y < end.y {
                current.y += 1
                result.append(current)
            }
            moveHorizontal()
            moveVertical()
        } else if (end.y < start.y || currentAction == .falling) && oldAction != .building {
            moveHorizontal()
            moveVertical()
        } else {
            moveVertical()
            moveHorizontal()
        }
        return result
    }

    mutating func addPermanentSkill(
        _ skill: NeoLemmixSkill,
        to lemming: inout NeoLemmixLemming
    ) {
        guard lemming.hasBeenOhNo != true else { return }
        switch skill {
        case .slider: lemming.traits.insert(.slider)
        case .climber: lemming.traits.insert(.climber)
        case .swimmer:
            lemming.traits.insert(.swimmer)
            if lemming.action == .drowning { transition(&lemming, to: .swimming) }
        case .floater:
            if !lemming.traits.contains(.glider) { lemming.traits.insert(.floater) }
        case .glider:
            if !lemming.traits.contains(.floater) { lemming.traits.insert(.glider) }
        case .disarmer: lemming.traits.insert(.disarmer)
        default: break
        }
    }

    mutating func removePermanentSkills(from lemming: inout NeoLemmixLemming) {
        let permanent: Set<NeoLemmixTrait> = [
            .slider, .climber, .swimmer, .floater, .glider, .disarmer,
        ]
        guard !lemming.traits.isDisjoint(with: permanent) else { return }
        lemming.traits.subtract(permanent)
        switch lemming.action {
        case .climbing, .dehoisting, .sliding, .floating, .gliding:
            lemming.fallDistance = -1
            lemming.trueFallDistance = -1
            transition(&lemming, to: .falling)
        case .swimming:
            transition(&lemming, to: .drowning)
        default:
            break
        }
    }

    mutating func checkZones(
        _ lemming: inout NeoLemmixLemming,
        from oldPosition: NeoLemmixPoint,
        oldAction: NeoLemmixAction,
        deferredLandingAction: NeoLemmixAction? = nil
    ) {
        guard ![
            .exiting, .drowning, .vaporizing, .splatting, .ohNo, .stoning,
            .exploding, .stoneFinish, .disarming, .teleporting,
        ].contains(lemming.action) else { return }

        let path = movementPath(
            from: oldPosition,
            to: lemming.position,
            oldAction: oldAction,
            currentAction: lemming.action
        )
        for point in path {
            let matchingZones = configuration.zones.filter {
                !disabledZoneIDs.contains($0.id)
                    && (gadgetBusyUntil?[$0.id] ?? 0) <= tickCount
                    && (($0.effect != .animation && $0.effect != .animationOnce)
                        || gadgetAnimatingZoneIDs?.contains($0.id) != true)
                    && $0.bounds.contains(point)
            }
            if point == lemming.position,
               lemming.action == .falling,
               let deferredLandingAction,
               !(deferredLandingAction == .splatting
                    && matchingZones.contains(where: { $0.effect == .water })) {
                transition(&lemming, to: deferredLandingAction)
            }
            if !lemming.traits.contains(.zombie) {
                if let zone = matchingZones.last(where: { $0.effect == .pickupSkill }),
                   let skill = zone.skill, let count = zone.skillCount {
                    disabledZoneIDs.insert(zone.id)
                    if case let .finite(current) = skills[skill] ?? .finite(0) {
                        skills[skill] = .finite(current >= 99 ? 99 : current + min(count, 99 - current))
                    }
                    lastTickEvents.append(.skillPickedUp(
                        lemmingID: lemming.id, zoneID: zone.id, skill: skill, count: count
                    ))
                }
                if let zone = matchingZones.last(where: { $0.effect == .unlockButton }) {
                    disabledZoneIDs.insert(zone.id)
                    if gadgetAnimatingZoneIDs == nil { gadgetAnimatingZoneIDs = [] }
                    gadgetAnimatingZoneIDs?.insert(zone.id)
                    if !configuration.zones.contains(where: {
                        $0.effect == .unlockButton && !disabledZoneIDs.contains($0.id)
                    }) {
                        for exit in configuration.zones where exit.effect == .lockedExit {
                            gadgetAnimatingZoneIDs?.insert(exit.id)
                        }
                    }
                    lastTickEvents.append(.buttonPressed(lemmingID: lemming.id, zoneID: zone.id))
                }
            }
            // CE checks trigger classes in this order and selects the last
            // matching gadget within a class. Do not let NXLV object order
            // decide whether a portal, exit, or state changer wins.
            func triggerPriority(_ effect: NeoLemmixZoneEffect) -> Int {
                switch effect {
                case .fire: 0
                case .water: 1
                case .trap, .oneShotTrap: 2
                case .portal: 3
                case .teleporter: 4
                case .neutralizer: 5
                case .deneutralizer: 6
                case .addSkill: 7
                case .removeSkills: 8
                case .exit, .lockedExit: 9
                case .splitter: 10
                case .animation, .animationOnce: 11
                default: 12
                }
            }
            let orderedZones = matchingZones.sorted {
                let left = triggerPriority($0.effect)
                let right = triggerPriority($1.effect)
                return left == right ? $0.id > $1.id : left < right
            }
            var handledEffects: Set<NeoLemmixZoneEffect> = []
            var handledAnimation = false
            for zone in orderedZones where handledEffects.insert(zone.effect).inserted {
                if zone.effect == .animation || zone.effect == .animationOnce {
                    guard !handledAnimation else { continue }
                    handledAnimation = true
                }
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
                    if lemming.traits.contains(.swimmer) {
                        continue
                    } else {
                        lemming.position = point
                        lastTickEvents.append(.hazardTriggered(
                            lemmingID: lemming.id,
                            zoneID: zone.id,
                            effect: zone.effect
                        ))
                        transition(&lemming, to: .drowning)
                        return
                    }
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
                        if gadgetBusyUntil == nil { gadgetBusyUntil = [:] }
                        gadgetBusyUntil?[zone.id] = tickCount + (zone.animationFrames ?? 1)
                        if gadgetAnimatingZoneIDs == nil { gadgetAnimatingZoneIDs = [] }
                        gadgetAnimatingZoneIDs?.insert(zone.id)
                        if zone.effect == .oneShotTrap { disabledZoneIDs.insert(zone.id) }
                        remove(&lemming, reason: .trapped)
                    }
                    return
                case .exit, .lockedExit:
                    guard !lemming.traits.contains(.zombie) else { continue }
                    guard ![.falling, .splatting, .jumping, .reaching].contains(lemming.action)
                    else { continue }
                    guard remainingZoneLemmingCounts?[zone.id] != 0 else { continue }
                    if zone.effect == .lockedExit && configuration.zones.contains(where: {
                        $0.effect == .unlockButton && !disabledZoneIDs.contains($0.id)
                    }) { continue }
                    if let remaining = remainingZoneLemmingCounts?[zone.id] {
                        remainingZoneLemmingCounts?[zone.id] = remaining - 1
                    }
                    lemming.position = point
                    lastTickEvents.append(.hazardTriggered(
                        lemmingID: lemming.id,
                        zoneID: zone.id,
                        effect: zone.effect
                    ))
                    transition(&lemming, to: .exiting)
                    return
                case .teleporter:
                    guard let pairing = zone.pairing,
                          let receiver = configuration.zones.first(where: {
                              $0.effect == .receiver && $0.pairing == pairing
                          }) else { continue }
                    lemming.position = point
                    let returnAction = lemming.action
                    if zone.flipsLemming == true { lemming.direction = lemming.direction.opposite }
                    transition(&lemming, to: .teleporting)
                    lemming.teleportTargetZoneID = receiver.id
                    let departure = zone.keyFrame.map { max(1, $0) }
                        ?? zone.animationFrames ?? 1
                    let arrival = receiver.keyFrame.map { max(1, $0) }
                        ?? max(1, (receiver.animationFrames ?? 1) - 1)
                    lemming.teleportTicksRemaining = departure + arrival
                    lemming.teleportReturnAction = returnAction
                    if gadgetBusyUntil == nil { gadgetBusyUntil = [:] }
                    let readyTick = tickCount + departure + arrival
                    for paired in configuration.zones where
                        (paired.effect == .teleporter || paired.effect == .receiver)
                            && paired.pairing == pairing {
                        gadgetBusyUntil?[paired.id] = readyTick
                    }
                    return
                case .neutralizer:
                    if !lemming.traits.contains(.zombie) { lemming.traits.insert(.neutral) }
                case .deneutralizer:
                    if !lemming.traits.contains(.zombie) { lemming.traits.remove(.neutral) }
                case .addSkill:
                    if let skill = zone.skill { addPermanentSkill(skill, to: &lemming) }
                case .removeSkills:
                    removePermanentSkills(from: &lemming)
                case .portal:
                    guard lemming.lastPortalZoneID != zone.id,
                          let pairing = zone.pairing,
                          let destination = configuration.zones.first(where: {
                              $0.id != zone.id && $0.effect == .portal && $0.pairing == pairing
                          }) else { continue }
                    lemming.position = point
                    lemming.portalTargetZoneID = destination.id
                    lemming.portalWarpFrame = 1
                    lemming.lastPortalZoneID = zone.id
                    return
                case .animation, .animationOnce:
                    if gadgetAnimatingZoneIDs == nil { gadgetAnimatingZoneIDs = [] }
                    gadgetAnimatingZoneIDs?.insert(zone.id)
                    if zone.effect == .animationOnce { disabledZoneIDs.insert(zone.id) }
                case .splatPad, .antiSplatPad:
                    continue
                case .pickupSkill, .unlockButton:
                    continue
                case .splitter:
                    guard ![.blocking, .jumping].contains(lemming.action),
                          lemming.lastSplitterZoneID != zone.id else { continue }
                    let output = splitterDirections?[zone.id] ?? zone.direction ?? .right
                    lemming.direction = output
                    if splitterDirections == nil { splitterDirections = [:] }
                    splitterDirections?[zone.id] = output.opposite
                    lemming.lastSplitterZoneID = zone.id
                case .forceLeft, .forceRight, .receiver, .updraft:
                    continue
                }
            }
        }

        let finalZones = configuration.zones.filter { $0.bounds.contains(lemming.position) }
        if !finalZones.contains(where: { $0.effect == .splitter }) {
            lemming.lastSplitterZoneID = nil
        }
        if !finalZones.contains(where: { $0.effect == .portal }) {
            lemming.lastPortalZoneID = nil
        }
        let blockerForce = blockerForcedDirection(lemming)
        let forcedDirection: NeoLemmixDirection?
        if blockerForce == .left || finalZones.contains(where: { $0.effect == .forceLeft }) {
            forcedDirection = .left
        } else if blockerForce == .right || finalZones.contains(where: { $0.effect == .forceRight }) {
            forcedDirection = .right
        } else {
            forcedDirection = nil
        }
        if let forcedDirection,
           lemming.action != .jumping,
           !(lemming.action == .mining && [1, 2].contains(lemming.animationFrame)) {
            if lemming.direction != forcedDirection
                && ![.hoisting, .dehoisting].contains(lemming.action) {
                lemming.direction = forcedDirection
                if [.climbing, .sliding].contains(lemming.action) {
                    lemming.position.x += forcedDirection.rawValue
                    if !lemming.isStartingAction { lemming.position.y += 1 }
                    transition(&lemming, to: .walking)
                }
            }
        }
        if lemming.traits.contains(.swimmer),
           finalZones.contains(where: { $0.effect == .water }),
           ![.climbing, .hoisting, .ohNo, .exploding, .stoning, .stoneFinish,
             .vaporizing, .exiting, .splatting].contains(lemming.action) {
            transition(&lemming, to: .swimming)
        }
    }

    mutating func checkBounds(_ lemming: inout NeoLemmixLemming) {
        guard lemming.position.x >= 0,
              lemming.position.x < terrain.width,
              lemming.position.y > 0,
              lemming.position.y <= terrain.height + 9 else {
            remove(&lemming, reason: .fellOut)
            return
        }
    }

    mutating func explode(_ lemming: inout NeoLemmixLemming) {
        let spans: [(first: Int, last: Int)] = [
            (5, 10), (4, 11), (3, 12), (3, 12), (2, 13), (2, 13),
            (1, 14), (1, 14), (1, 14), (1, 14), (0, 15), (0, 15),
            (0, 15), (0, 15), (0, 15), (0, 15), (1, 14), (1, 14),
            (1, 14), (2, 13), (3, 12), (5, 10),
        ]
        let maskLeft = lemming.position.x + (lemming.direction == .right ? 1 : 0) - 8
        let maskTop = lemming.position.y - 14
        var removedPixels = 0
        for (row, span) in spans.enumerated() {
            for column in span.first...span.last {
                let x = maskLeft + column
                let y = maskTop + row
                guard terrain.isSolid(x: x, y: y), !terrain.isSteel(x: x, y: y) else { continue }
                if terrain.setSolid(false, x: x, y: y) { removedPixels += 1 }
            }
        }
        emitTerrainRemoved(lemmingID: lemming.id, count: removedPixels)
        remove(&lemming, reason: .exploded)
    }

    mutating func finishStoner(_ lemming: inout NeoLemmixLemming) {
        let spans: [(first: Int, last: Int)] = [
            (7, 8), (6, 9), (6, 9), (7, 8), (6, 9), (6, 9),
            (6, 9), (7, 8), (7, 8), (7, 8), (7, 8),
        ]
        let maskLeft = lemming.position.x + (lemming.direction == .right ? 1 : 0) - 8
        let maskTop = lemming.position.y - 10
        var addedPixels = 0
        for (row, span) in spans.enumerated() {
            for column in span.first...span.last {
                if terrain.setStonerSolid(
                    x: maskLeft + column,
                    y: maskTop + row,
                    ownerID: lemming.id,
                    sourceIndex: row * 16 + column
                ) {
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
        let oldAction = lemming.action
        var deferredLandingAction: NeoLemmixAction?
        if lemming.portalWarpFrame != nil {
            updatePortalWarp(&lemming)
            if lemming.isActive {
                checkZones(&lemming, from: lemming.position, oldAction: oldAction)
                checkBounds(&lemming)
            }
            lemmings[index] = lemming
            return
        }
        let wasTeleporting = lemming.action == .teleporting
        lemming.animationFrame += 1
        if updateExplosionCountdown(&lemming) {
            lemmings[index] = lemming
            return
        }

        if lemming.isActive {
            switch lemming.action {
            case .walking:
                updateWalking(&lemming)
            case .ascending:
                updateAscending(&lemming)
            case .falling:
                deferredLandingAction = updateFalling(&lemming)
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
            case .fencing:
                updateFencing(&lemming)
            case .lasering:
                updateLasering(&lemming)
            case .teleporting:
                updateTeleporting(&lemming)
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
                updateOhNoing(&lemming, completion: .exploding)
            case .stoning:
                updateOhNoing(&lemming, completion: .stoneFinish)
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
            checkZones(
                &lemming,
                from: wasTeleporting ? lemming.position : oldPosition,
                oldAction: oldAction,
                deferredLandingAction: deferredLandingAction
            )
            checkBounds(&lemming)
        }
        lemmings[index] = lemming
    }

    mutating func updateExplosionCountdown(_ lemming: inout NeoLemmixLemming) -> Bool {
        guard let countdown = lemming.bomberCountdown else { return false }
        let next = countdown - 1
        lemming.bomberCountdown = max(0, next)
        if next <= 0 {
            let skill = lemming.pendingExplosionSkill ?? .bomber
            lemming.bomberCountdown = nil
            lemming.pendingExplosionSkill = nil
            let explodesImmediately: Set<NeoLemmixAction> = [
                .vaporizing, .drowning, .floating, .gliding, .falling,
                .swimming, .reaching, .shimmying, .jumping,
            ]
            let target: NeoLemmixAction
            if explodesImmediately.contains(lemming.action) {
                target = skill == .stoner ? .stoneFinish : .exploding
            } else {
                target = skill == .stoner ? .stoning : .ohNo
            }
            transition(&lemming, to: target)
            return true
        }
        return false
    }

    mutating func updateOhNoing(
        _ lemming: inout NeoLemmixLemming,
        completion: NeoLemmixAction
    ) {
        if lemming.animationFrame >= 16 {
            transition(&lemming, to: completion)
            return
        }
        guard !terrain.isSolid(x: lemming.position.x, y: lemming.position.y) else { return }
        lemming.traits.remove(.blocker)
        let maximum = isInUpdraft(lemming.position) ? 2 : 3
        lemming.position.y += min(findGroundPixel(
            x: lemming.position.x,
            y: lemming.position.y
        ), maximum)
    }

    mutating func updateTeleporting(_ lemming: inout NeoLemmixLemming) {
        let remaining = max(0, (lemming.teleportTicksRemaining ?? 1) - 1)
        lemming.teleportTicksRemaining = remaining
        guard remaining == 0,
              let targetID = lemming.teleportTargetZoneID,
              let receiver = configuration.zones.first(where: { $0.id == targetID }) else {
            return
        }
        lemming.position = NeoLemmixPoint(x: receiver.bounds.x, y: receiver.bounds.y)
        let returnAction = lemming.teleportReturnAction ?? .walking
        lemming.teleportTargetZoneID = nil
        lemming.teleportTicksRemaining = nil
        lemming.teleportReturnAction = nil
        transition(&lemming, to: returnAction)
    }

    mutating func updatePortalWarp(_ lemming: inout NeoLemmixLemming) {
        let nextFrame = (lemming.portalWarpFrame ?? 0) + 1
        lemming.portalWarpFrame = nextFrame
        if nextFrame == 4,
           let targetID = lemming.portalTargetZoneID,
           let destination = configuration.zones.first(where: { $0.id == targetID }) {
            lemming.position = NeoLemmixPoint(
                x: destination.bounds.x + (destination.bounds.width + 1) / 2 - 1,
                y: destination.bounds.y + destination.bounds.height - 1
            )
            lemming.lastPortalZoneID = destination.id
        } else if nextFrame >= 7 {
            lemming.portalWarpFrame = nil
            lemming.portalTargetZoneID = nil
        }
    }

    mutating func updateWalking(_ lemming: inout NeoLemmixLemming) {
        lemming.animationFrame %= 4
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

    mutating func updateFalling(_ lemming: inout NeoLemmixLemming) -> NeoLemmixAction? {
        lemming.animationFrame %= 4
        if lemming.traits.contains(.floater), lemming.trueFallDistance > 16 {
            transition(&lemming, to: .floating)
            return nil
        }
        if lemming.traits.contains(.glider), lemming.trueFallDistance > 8 {
            transition(&lemming, to: .gliding)
            return nil
        }

        var moved = 0
        let maximumMovement = isInUpdraft(lemming.position) ? 2 : 3
        while moved < maximumMovement && !terrain.isSolid(x: lemming.position.x, y: lemming.position.y) {
            if moved > 0,
               lemming.traits.contains(.glider),
               lemming.trueFallDistance > 8 {
                transition(&lemming, to: .gliding)
                return nil
            }
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
            if isInUpdraft(lemming.position) { lemming.fallDistance = 0 }
        }
        if moved < maximumMovement {
            let protected = lemming.traits.contains(.floater)
                || lemming.traits.contains(.glider)
                || configuration.zones.contains {
                    $0.effect == .antiSplatPad && $0.bounds.contains(lemming.position)
                }
            let forcedSplat = configuration.zones.contains {
                $0.effect == .splatPad && $0.bounds.contains(lemming.position)
            }
            if !protected && (lemming.fallDistance > NeoLemmixRules.maximumSafeFallDistance
                || forcedSplat) {
                return .splatting
            } else {
                lemming.fallDistance = 0
                lemming.trueFallDistance = 0
                return .walking
            }
        }
        return nil
    }

    mutating func updateFloating(_ lemming: inout NeoLemmixLemming) {
        let table = [3, 3, 3, 3, -1, 0, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2]
        if lemming.animationFrame > 17 { lemming.animationFrame = 9 }
        var maximum = table[max(1, lemming.animationFrame) - 1]
        if isInUpdraft(lemming.position) { maximum -= 1 }
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
        var maximum = table[max(1, lemming.animationFrame) - 1]
        if isInUpdraft(lemming.position) {
            maximum -= 1
            if lemming.animationFrame >= 9 && lemming.animationFrame.isMultiple(of: 2) == false {
                maximum -= 1
            }
        }
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
        if lemming.animationFrame == 1 && lemming.isStartingAction {
            lemming.position.y -= 1
        } else if lemming.animationFrame <= 4 {
            lemming.position.y -= 2
        }
        if lemming.animationFrame >= 8 { transition(&lemming, to: .walking) }
    }

    mutating func updateSliding(_ lemming: inout NeoLemmixLemming) {
        if (lemming.position.x <= 0 && lemming.direction == .left)
            || (lemming.position.x >= terrain.width - 1 && lemming.direction == .right) {
            remove(&lemming, reason: .fellOut)
            return
        }
        if lemming.animationFrame > 2 { lemming.animationFrame = 1 }
        for _ in 0..<2 {
            lemming.position.y += 1
            if !sliderTerrainChecks(&lemming) { return }
        }
    }

    mutating func updateDehoisting(_ lemming: inout NeoLemmixLemming) {
        if lemming.animationFrame >= 7 {
            if (lemming.position.x <= 0 && lemming.direction == .left)
                || (lemming.position.x >= terrain.width - 1 && lemming.direction == .right) {
                remove(&lemming, reason: .fellOut)
                return
            }
            if terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 7) {
                transition(&lemming, to: .sliding)
            } else {
                transition(&lemming, to: .falling)
            }
            return
        }
        guard lemming.animationFrame >= 2 else { return }
        for substep in 0..<2 {
            lemming.position.y += 1
            let maximumOffset = lemming.animationFrame * 2 - 3 + substep
            if !sliderTerrainChecks(&lemming, maximumYCheckOffset: maximumOffset) { return }
        }
    }

    mutating func updateSwimming(_ lemming: inout NeoLemmixLemming) {
        lemming.animationFrame %= 8
        lemming.fallDistance = 0
        lemming.trueFallDistance = 0
        lemming.position.x += lemming.direction.rawValue

        if !isInWater(lemming.position)
            && !terrain.isSolid(x: lemming.position.x, y: lemming.position.y) {
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

        let ground = findGroundPixel(x: lemming.position.x, y: lemming.position.y)
        if ground >= -1
            && isInWater(NeoLemmixPoint(x: lemming.position.x, y: lemming.position.y - 1))
            && !terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 1) {
            lemming.position.y -= 1
        } else if ground < -6 {
            var diveDistance = 1
            while diveDistance <= 4
                && terrain.isSolid(
                    x: lemming.position.x,
                    y: lemming.position.y + diveDistance
                ) {
                diveDistance += 1
                lemming.fallDistance += 1
                if isInWater(NeoLemmixPoint(
                    x: lemming.position.x,
                    y: lemming.position.y + diveDistance
                )) {
                    lemming.fallDistance = 0
                }
            }
            if diveDistance <= 4 {
                lemming.position.y += diveDistance
                if !isInWater(lemming.position) {
                    transition(&lemming, to: .walking)
                }
            } else if lemming.traits.contains(.climber)
                && !isInWater(NeoLemmixPoint(x: lemming.position.x, y: lemming.position.y - 1)) {
                transition(&lemming, to: .climbing)
            } else {
                lemming.direction = lemming.direction.opposite
                lemming.position.x += lemming.direction.rawValue
            }
        } else if ground <= -3 {
            transition(&lemming, to: .ascending)
            lemming.position.y -= 2
        } else if ground <= -1 || (ground == 0 && !isInWater(lemming.position)) {
            transition(&lemming, to: .walking)
            lemming.position.y += ground
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
                length: 6,
                shade: 12 - lemming.bricksRemaining
            )
            emitTerrainAdded(lemmingID: lemming.id, count: count)
        } else if lemming.animationFrame == 0 {
            lemming.bricksRemaining -= 1
            let direction = lemming.direction.rawValue
            if terrain.isSolid(x: lemming.position.x + direction, y: lemming.position.y - 2) {
                transition(&lemming, to: .walking, turn: true)
                return
            }
            if terrain.isSolid(x: lemming.position.x + direction, y: lemming.position.y - 3)
                || terrain.isSolid(x: lemming.position.x + 2 * direction, y: lemming.position.y - 2)
                || (terrain.isSolid(
                    x: lemming.position.x + 2 * direction,
                    y: lemming.position.y - 10
                ) && lemming.bricksRemaining > 0) {
                lemming.position.y -= 1
                lemming.position.x += direction
                transition(&lemming, to: .walking, turn: true)
                return
            }
            lemming.position.y -= 1
            lemming.position.x += 2 * direction
            if terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 2)
                || terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 3)
                || terrain.isSolid(x: lemming.position.x + direction, y: lemming.position.y - 3)
                || (terrain.isSolid(
                    x: lemming.position.x + direction,
                    y: lemming.position.y - 9
                ) && lemming.bricksRemaining > 0) {
                transition(&lemming, to: .walking, turn: true)
            } else if lemming.bricksRemaining == 0 {
                transition(&lemming, to: .shrugging)
            }
        }
    }

    mutating func updatePlatforming(_ lemming: inout NeoLemmixLemming) {
        func terrainAhead(_ distance: Int) -> Bool {
            let x = lemming.position.x + distance * lemming.direction.rawValue
            return terrain.isSolid(x: x, y: lemming.position.y - 1)
                || terrain.isSolid(x: x, y: lemming.position.y - 2)
        }
        func canPlaceBrick() -> Bool {
            let direction = lemming.direction.rawValue
            let addsPixel = (0...5).contains {
                !terrain.isSolid(x: lemming.position.x + $0 * direction, y: lemming.position.y)
            }
            return addsPixel
                && !terrain.isSolid(x: lemming.position.x + direction, y: lemming.position.y - 1)
                && !terrain.isSolid(x: lemming.position.x + 2 * direction, y: lemming.position.y - 1)
        }
        if lemming.animationFrame > 15 { lemming.animationFrame = 0 }
        if lemming.animationFrame == 9 {
            lemming.placedBrick = canPlaceBrick()
            let count = addBrick(
                x: lemming.position.x,
                y: lemming.position.y,
                direction: lemming.direction,
                length: 6,
                shade: 12 - lemming.bricksRemaining
            )
            emitTerrainAdded(lemmingID: lemming.id, count: count)
        } else if lemming.animationFrame == 15 {
            if lemming.placedBrick != true {
                transition(&lemming, to: .walking, turn: true)
            } else if terrainAhead(2) {
                lemming.position.x += lemming.direction.rawValue
                transition(&lemming, to: .walking, turn: true)
            } else {
                lemming.position.x += lemming.direction.rawValue
            }
        } else if lemming.animationFrame == 0 {
            let direction = lemming.direction.rawValue
            if terrainAhead(2) && lemming.bricksRemaining > 1 {
                lemming.position.x += direction
                transition(&lemming, to: .walking, turn: true)
                return
            }
            if terrainAhead(3) && lemming.bricksRemaining > 1 {
                lemming.position.x += 2 * direction
                transition(&lemming, to: .walking, turn: true)
                return
            }
            lemming.position.x += 2 * direction
            lemming.bricksRemaining -= 1
            if lemming.bricksRemaining == 0 {
                if terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 1) {
                    lemming.position.x -= direction
                }
                transition(&lemming, to: .shrugging)
            }
        }
    }

    mutating func updateStacking(_ lemming: inout NeoLemmixLemming) {
        if lemming.animationFrame > 7 { lemming.animationFrame = 0 }
        if lemming.animationFrame == 7 {
            let rowY = lemming.position.y - 9 + lemming.bricksRemaining
            var count = 0
            for offset in 1...3 {
                if terrain.setConstructiveSolid(
                    x: lemming.position.x + offset * lemming.direction.rawValue,
                    y: rowY,
                    shade: 12 - lemming.bricksRemaining
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
        if lemming.isStartingAction {
            lemming.isStartingAction = false
            _ = digRow(for: lemming, y: lemming.position.y - 1)
            // CE cancels the first physics-frame advance, making the first
            // digger cycle one frame longer and applying both initial rows on
            // the assignment frame.
            lemming.animationFrame = max(0, lemming.animationFrame - 1)
        }
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

    mutating func updateBashing(
        _ lemming: inout NeoLemmixLemming,
        checksContinuation: Bool = true
    ) {
        func basherIsIndestructible(_ x: Int, _ y: Int) -> Bool {
            (-5 ... -3).contains { offset in
                isIndestructible(
                    x: x,
                    y: y + offset,
                    skill: .basher,
                    direction: lemming.direction
                )
            }
        }
        func canStepUp(_ x: Int, _ y: Int, _ direction: Int, _ step: Int) -> Bool {
            func solid(_ forward: Int, _ vertical: Int) -> Bool {
                terrain.isSolid(x: x + forward * direction, y: y + vertical)
            }
            if step == -1 {
                if !solid(1, step - 1)
                    && solid(1, step)
                    && solid(2, step)
                    && solid(2, step - 1)
                    && solid(2, step - 2) { return false }
                if !solid(1, step - 2)
                    && solid(1, step)
                    && solid(1, step - 1)
                    && solid(2, step - 1)
                    && solid(2, step - 2) { return false }
                if solid(1, step - 2)
                    && solid(1, step - 1)
                    && solid(1, step) { return false }
            } else if step == -2 {
                if !solid(1, step)
                    && solid(1, step + 1)
                    && solid(2, step + 1)
                    && solid(2, step)
                    && solid(2, step - 1) { return false }
                if !solid(1, step - 1)
                    && solid(1, step)
                    && solid(2, step)
                    && solid(2, step - 1) { return false }
                if solid(1, step - 1) && solid(1, step) { return false }
            }
            return true
        }
        func turnBasher(_ lemming: inout NeoLemmixLemming) {
            lemming.position.x -= lemming.direction.rawValue
            transition(&lemming, to: .walking, turn: true)
        }

        if lemming.animationFrame > 15 { lemming.animationFrame = 0 }
        if (2...5).contains(lemming.animationFrame) {
            applyBasherMask(lemming, frame: lemming.animationFrame - 2)
        }
        if lemming.animationFrame == 5 && checksContinuation {
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
                canContinue = basherTurnsAtSteel(lemming)
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

            if delta > 0,
               lemming.traits.contains(.slider),
               canDehoist(lemming, alreadyMovedX: true) {
                lemming.position.x -= lemming.direction.rawValue
                transition(&lemming, to: .dehoisting, turn: true)
            } else if delta == 4 {
                lemming.position.y += 4
                transition(&lemming, to: .falling)
            } else if delta == 3 {
                lemming.position.y += 3
                transition(&lemming, to: .walking)
            } else if (0...2).contains(delta) {
                if basherIsIndestructible(lemming.position.x, lemming.position.y + delta) {
                    turnBasher(&lemming)
                } else {
                    lemming.position.y += delta
                }
            } else if delta == -1 || delta == -2 {
                if basherIsIndestructible(lemming.position.x, lemming.position.y + delta) {
                    turnBasher(&lemming)
                } else if !canStepUp(
                    lemming.position.x,
                    lemming.position.y,
                    lemming.direction.rawValue,
                    delta
                ) {
                    if basherIsIndestructible(
                        lemming.position.x + lemming.direction.rawValue,
                        lemming.position.y + 2
                    ) {
                        turnBasher(&lemming)
                    } else {
                        lemming.position.x -= lemming.direction.rawValue
                    }
                } else {
                    lemming.position.y += delta
                }
            } else if delta < -2 {
                if basherIsIndestructible(lemming.position.x, lemming.position.y) {
                    turnBasher(&lemming)
                } else {
                    lemming.position.x -= lemming.direction.rawValue
                }
            } else {
                lemming.position.y += delta
            }
        }
    }

    /// CE keeps a Basher working when the next two strokes will make it turn
    /// at steel, even if frame 5 cannot currently see destructible terrain.
    func basherTurnsAtSteel(_ lemming: NeoLemmixLemming) -> Bool {
        var probe = self
        var copy = lemming
        let originalDirection = copy.direction
        copy.animationFrame = 10

        for _ in 0...10 {
            if copy.animationFrame == 0 || copy.animationFrame == 16 {
                for maskFrame in 0...3 {
                    probe.applyBasherMask(copy, frame: maskFrame)
                }
                copy.animationFrame = 10
            }
            copy.animationFrame += 1
            probe.updateBashing(&copy, checksContinuation: false)
            if copy.direction != originalDirection && copy.action != .dehoisting {
                return true
            }
            if !copy.isActive || copy.action != .bashing { return false }
        }
        return false
    }

    /// Applies the four 16-by-10 CE Basher masks as foot-relative row spans.
    mutating func applyBasherMask(_ lemming: NeoLemmixLemming, frame: Int) {
        let spans: [[(rise: Int, first: Int, last: Int)]] = [
            [(9, 0, 5), (8, 0, 6), (7, 0, 4), (6, 0, 2), (5, 0, 2),
             (4, 0, 2), (3, 0, 2), (2, 0, 2), (1, 0, 1)],
            [(9, 1, 5), (8, 2, 6), (7, 3, 6), (6, 3, 5), (5, 3, 5)],
            [(9, 1, 5), (8, 2, 6), (7, 3, 7), (6, 3, 7), (5, 3, 6),
             (4, 3, 5), (3, 4, 5)],
            [(9, 1, 5), (8, 2, 6), (7, 3, 7), (6, 3, 7), (5, 3, 7),
             (4, 3, 7), (3, 3, 7), (2, 3, 7), (1, 2, 6)],
        ]
        guard spans.indices.contains(frame) else { return }
        var removed = 0
        for span in spans[frame] {
            for forward in span.first...span.last where eraseDestructible(
                x: lemming.position.x + forward * lemming.direction.rawValue,
                y: lemming.position.y - span.rise,
                skill: .basher,
                direction: lemming.direction
            ) { removed += 1 }
        }
        emitTerrainRemoved(lemmingID: lemming.id, count: removed)
    }

    /// Applies the four 16-by-10 Fencer cuts from the CE mask as row spans.
    /// The spans are expressed from the lemming's foot position, so the
    /// implementation does not embed or distribute the oracle bitmap.
    mutating func applyFencerMask(_ lemming: NeoLemmixLemming, frame: Int) {
        let spans: [[(rise: Int, first: Int, last: Int)]] = [
            [(6, 0, 3), (5, 0, 5), (4, 0, 1)],
            [(6, 0, 3), (5, 0, 5), (4, 0, 6), (3, 0, 4), (2, 0, 2)],
            [(6, 0, 5), (5, 0, 6), (4, 0, 6), (3, 0, 4), (2, 0, 2)],
            [(10, 4, 5), (9, 2, 6), (8, 0, 6), (7, 0, 6), (6, 0, 6),
             (5, 0, 6), (4, 0, 6), (3, 0, 4), (2, 0, 2)],
        ]
        guard spans.indices.contains(frame) else { return }
        var removed = 0
        for span in spans[frame] {
            for forward in span.first...span.last {
                if eraseDestructible(
                    x: lemming.position.x + forward * lemming.direction.rawValue,
                    y: lemming.position.y - span.rise,
                    skill: .fencer,
                    direction: lemming.direction
                ) { removed += 1 }
            }
        }
        emitTerrainRemoved(lemmingID: lemming.id, count: removed)
    }

    func fencerStepUpIsClear(
        x: Int,
        y: Int,
        direction: NeoLemmixDirection,
        step: Int
    ) -> Bool {
        let dx = direction.rawValue
        if step == -1 {
            if !terrain.isSolid(x: x + dx, y: y - 2)
                && terrain.isSolid(x: x + dx, y: y - 1)
                && terrain.isSolid(x: x + 2 * dx, y: y - 1)
                && terrain.isSolid(x: x + 2 * dx, y: y - 2)
                && terrain.isSolid(x: x + 2 * dx, y: y - 3) { return false }
            if !terrain.isSolid(x: x + dx, y: y - 3)
                && terrain.isSolid(x: x + dx, y: y - 1)
                && terrain.isSolid(x: x + dx, y: y - 2)
                && terrain.isSolid(x: x + 2 * dx, y: y - 2)
                && terrain.isSolid(x: x + 2 * dx, y: y - 3) { return false }
            if terrain.isSolid(x: x + dx, y: y - 3)
                && terrain.isSolid(x: x + dx, y: y - 2)
                && terrain.isSolid(x: x + dx, y: y - 1) { return false }
        } else if step == -2 {
            if !terrain.isSolid(x: x + dx, y: y - 2)
                && terrain.isSolid(x: x + dx, y: y - 1)
                && terrain.isSolid(x: x + 2 * dx, y: y - 1)
                && terrain.isSolid(x: x + 2 * dx, y: y - 2)
                && terrain.isSolid(x: x + 2 * dx, y: y - 3) { return false }
            if !terrain.isSolid(x: x + dx, y: y - 3)
                && terrain.isSolid(x: x + dx, y: y - 2)
                && terrain.isSolid(x: x + 2 * dx, y: y - 2)
                && terrain.isSolid(x: x + 2 * dx, y: y - 3) { return false }
            if terrain.isSolid(x: x + dx, y: y - 3)
                && terrain.isSolid(x: x + dx, y: y - 2) { return false }
        }
        return true
    }

    mutating func turnFencer(_ lemming: inout NeoLemmixLemming, undoRise: Bool) {
        lemming.position.x -= lemming.direction.rawValue
        if undoRise { lemming.position.y += 1 }
        transition(&lemming, to: .walking, turn: true)
    }

    mutating func updateFencing(_ lemming: inout NeoLemmixLemming) {
        if lemming.animationFrame > 15 { lemming.animationFrame = 0 }
        if (2...5).contains(lemming.animationFrame) {
            applyFencerMask(lemming, frame: lemming.animationFrame - 2)
        }
        if lemming.animationFrame == 15 { lemming.isStartingAction = false }

        if lemming.animationFrame == 5 {
            var canContinue = false
            for forward in 1...14 {
                for rise in 5...6 {
                    let x = lemming.position.x + forward * lemming.direction.rawValue
                    let y = lemming.position.y - rise
                    if terrain.isSolid(x: x, y: y)
                        && !isIndestructible(x: x, y: y, skill: .fencer, direction: lemming.direction) {
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

        guard (11...14).contains(lemming.animationFrame) else { return }
        lemming.position.x += lemming.direction.rawValue
        var ground = findGroundPixel(x: lemming.position.x, y: lemming.position.y)
        var undoRise = false
        if ground == -1 && (lemming.animationFrame == 11 || lemming.animationFrame == 13) {
            lemming.position.y -= 1
            ground = 0
            undoRise = true
        }

        if ground > 0 && lemming.traits.contains(.slider)
            && canDehoist(lemming, alreadyMovedX: true) {
            lemming.position.x -= lemming.direction.rawValue
            transition(&lemming, to: .dehoisting, turn: true)
        } else if ground == 4 {
            lemming.position.y += ground
            transition(&lemming, to: .falling)
        } else if ground > 0 {
            lemming.position.y += ground
            transition(&lemming, to: .walking)
        } else if ground == 0 {
            if isIndestructible(
                x: lemming.position.x,
                y: lemming.position.y - 3,
                skill: .fencer,
                direction: lemming.direction
            ) { turnFencer(&lemming, undoRise: undoRise) }
        } else if ground == -1 || ground == -2 {
            if isIndestructible(
                x: lemming.position.x,
                y: lemming.position.y + ground - 3,
                skill: .fencer,
                direction: lemming.direction
            ) {
                turnFencer(&lemming, undoRise: undoRise)
            } else if !fencerStepUpIsClear(
                x: lemming.position.x,
                y: lemming.position.y,
                direction: lemming.direction,
                step: ground
            ) {
                let nextX = lemming.position.x + lemming.direction.rawValue
                if isIndestructible(
                    x: nextX,
                    y: lemming.position.y - 1,
                    skill: .fencer,
                    direction: lemming.direction
                ) {
                    turnFencer(&lemming, undoRise: undoRise)
                } else {
                    lemming.position.x -= lemming.direction.rawValue
                    if undoRise { lemming.position.y += 1 }
                }
            } else {
                lemming.position.y += ground
            }
        } else {
            if isIndestructible(
                x: lemming.position.x,
                y: lemming.position.y - 3,
                skill: .fencer,
                direction: lemming.direction
            ) {
                turnFencer(&lemming, undoRise: undoRise)
            } else {
                lemming.position.x -= lemming.direction.rawValue
            }
        }
    }

    enum LaserHit: Equatable {
        case none
        case destructible
        case indestructible
        case outOfBounds
    }

    func laserHit(at target: NeoLemmixPoint, direction: NeoLemmixDirection) -> LaserHit {
        guard target.x >= -4, target.y >= -4, target.x < terrain.width + 4 else {
            return .outOfBounds
        }
        let offsets = [
            NeoLemmixPoint(x: 1, y: -1), .init(x: 0, y: -1), .init(x: 1, y: 0),
            .init(x: -1, y: -1), .init(x: -1, y: -2), .init(x: 0, y: -2),
            .init(x: 1, y: -2), .init(x: 2, y: -1), .init(x: 2, y: 0),
            .init(x: 2, y: 2), .init(x: 1, y: 1),
        ]
        var foundIndestructible = false
        for offset in offsets {
            let x = target.x + offset.x * direction.rawValue
            let y = target.y + offset.y
            guard terrain.isSolid(x: x, y: y) else { continue }
            if isIndestructible(x: x, y: y, skill: .laserer, direction: direction) {
                foundIndestructible = true
            } else {
                return .destructible
            }
        }
        return foundIndestructible ? .indestructible : .none
    }

    mutating func applyLaserMask(_ lemming: NeoLemmixLemming, at target: NeoLemmixPoint) {
        let halfWidths = [1, 2, 3, 4, 4, 4, 3, 2, 1]
        var removed = 0
        for row in 0..<9 {
            let y = target.y + row - 4
            let halfWidth = halfWidths[row]
            for offsetX in -halfWidth...halfWidth {
                let x = target.x + offsetX
                guard y < lemming.position.y else { continue }
                if lemming.direction == .right && x < lemming.position.x { continue }
                if lemming.direction == .left && x > lemming.position.x { continue }
                if eraseDestructible(
                    x: x,
                    y: y,
                    skill: .laserer,
                    direction: lemming.direction
                ) { removed += 1 }
            }
        }
        emitTerrainRemoved(lemmingID: lemming.id, count: removed)
    }

    mutating func updateLasering(_ lemming: inout NeoLemmixLemming) {
        guard terrain.isSolid(x: lemming.position.x, y: lemming.position.y) else {
            transition(&lemming, to: .falling)
            return
        }

        var target = NeoLemmixPoint(
            x: lemming.position.x + 2 * lemming.direction.rawValue,
            y: lemming.position.y - 5
        )
        var hit: LaserHit = .none
        for _ in 0..<112 {
            hit = laserHit(at: target, direction: lemming.direction)
            guard hit == .none else { break }
            target.x += lemming.direction.rawValue
            target.y -= 1
        }

        switch hit {
        case .destructible:
            lemming.laserHitPoint = target
            applyLaserMask(lemming, at: target)
            lemming.actionProgress = 10
        case .indestructible:
            lemming.laserHitPoint = target
            lemming.actionProgress -= 1
        case .none, .outOfBounds:
            lemming.laserHitPoint = nil
            lemming.actionProgress -= 1
        }
        if lemming.actionProgress <= 0 { transition(&lemming, to: .walking) }
    }

    mutating func updateMining(_ lemming: inout NeoLemmixLemming) {
        func minerIsIndestructible(_ x: Int, _ y: Int) -> Bool {
            isIndestructible(x: x, y: y, skill: .miner, direction: lemming.direction)
        }
        func turnMiner(_ lemming: inout NeoLemmixLemming) {
            if terrain.isSolid(x: lemming.position.x, y: lemming.position.y - 1) {
                lemming.position.y -= 1
            }
            transition(&lemming, to: .walking, turn: true)
        }

        if lemming.animationFrame > 23 { lemming.animationFrame = 0 }
        if lemming.animationFrame == 1 || lemming.animationFrame == 2 {
            applyMinerMask(lemming, frame: lemming.animationFrame - 1)
        } else if lemming.animationFrame == 3 || lemming.animationFrame == 15 {
            if lemming.traits.contains(.slider), canDehoist(lemming, alreadyMovedX: false) {
                transition(&lemming, to: .dehoisting, turn: true)
                return
            }

            let direction = lemming.direction.rawValue
            lemming.position.x += 2 * direction
            lemming.position.y += 1

            if lemming.traits.contains(.slider), canDehoist(lemming, alreadyMovedX: true) {
                lemming.position.x -= direction
                transition(&lemming, to: .dehoisting, turn: true)
            } else if minerIsIndestructible(
                lemming.position.x - direction,
                lemming.position.y - 1
            ) && minerIsIndestructible(lemming.position.x, lemming.position.y - 1) {
                lemming.position.x -= 2 * direction
                turnMiner(&lemming)
            } else if lemming.animationFrame == 3,
                      minerIsIndestructible(
                        lemming.position.x - direction,
                        lemming.position.y - 2
                      ) {
                lemming.position.x -= 2 * direction
                turnMiner(&lemming)
            } else if !terrain.isSolid(
                x: lemming.position.x - direction,
                y: lemming.position.y - 1
            ) && !terrain.isSolid(
                x: lemming.position.x - direction,
                y: lemming.position.y
            ) && !terrain.isSolid(
                x: lemming.position.x - direction,
                y: lemming.position.y + 1
            ) {
                lemming.position.x -= direction
                lemming.position.y += 1
                transition(&lemming, to: .falling)
                lemming.fallDistance += 1
            } else if minerIsIndestructible(lemming.position.x, lemming.position.y - 2) {
                lemming.position.x -= direction
                turnMiner(&lemming)
            } else if !terrain.isSolid(x: lemming.position.x, y: lemming.position.y) {
                lemming.position.y += 1
                transition(&lemming, to: .falling)
            } else if minerIsIndestructible(
                lemming.position.x + direction,
                lemming.position.y - 2
            ) || minerIsIndestructible(lemming.position.x, lemming.position.y) {
                turnMiner(&lemming)
            }
        }
    }

    /// Applies the two 16-by-13 CE Miner masks as foot-relative row spans.
    mutating func applyMinerMask(_ lemming: NeoLemmixLemming, frame: Int) {
        let spans: [[(rise: Int, first: Int, last: Int)]] = [
            [(12, 0, 5), (11, 0, 6), (10, 0, 7), (9, 0, 7), (8, 0, 7),
             (7, 0, 5), (6, 0, 2), (5, 0, 1), (4, 0, 1), (3, 0, 1),
             (2, 0, 1), (1, 0, 1)],
            [(9, 7, 7), (8, 7, 7), (7, 2, 8), (6, 1, 8), (5, 1, 8),
             (4, 1, 8), (3, 1, 8), (2, 1, 8), (1, 1, 8), (0, 1, 7),
             (-1, 3, 6)],
        ]
        guard spans.indices.contains(frame) else { return }
        var removed = 0
        for span in spans[frame] {
            for forward in span.first...span.last where eraseDestructible(
                x: lemming.position.x + forward * lemming.direction.rawValue,
                y: lemming.position.y - span.rise,
                skill: .miner,
                direction: lemming.direction
            ) { removed += 1 }
        }
        emitTerrainRemoved(lemmingID: lemming.id, count: removed)
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
                    for rise in 1...8 {
                        if !terrain.isSolid(x: checkX, y: lemming.position.y - rise) {
                            lemming.position.x = checkX
                            if rise <= 2 {
                                lemming.position.y -= rise - 1
                                transition(&lemming, to: .walking)
                            } else if rise <= 5 {
                                lemming.position.y -= rise - 5
                                transition(&lemming, to: .hoisting)
                            } else {
                                lemming.position.y -= rise - 8
                                transition(&lemming, to: .hoisting)
                            }
                            return
                        }
                        if (rise == 5 && !lemming.traits.contains(.climber)) || rise == 7 {
                            if lemming.traits.contains(.climber) {
                                lemming.position.x = checkX
                                transition(&lemming, to: .climbing)
                            } else if lemming.traits.contains(.slider) {
                                lemming.position.x = checkX
                                transition(&lemming, to: .sliding)
                            } else {
                                transition(&lemming, to: .falling, turn: true)
                            }
                            return
                        }
                    }
                }
            }
            if step.y < 0 {
                for rise in 1...9 {
                    if firstStep && rise == 1 { continue }
                    if terrain.isSolid(x: lemming.position.x, y: lemming.position.y - rise) {
                        transition(&lemming, to: .falling)
                        return
                    }
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
