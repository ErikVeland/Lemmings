import Foundation

/// A clean-room, fixed-tick simulation foundation for the original DOS game.
///
/// Behavioral references:
/// - github.com/AaronKelley/LemmixPlayer/tree/main/PlayerSourceTrad/Mechanics
/// - github.com/AaronKelley/LemmixPlayer/blob/main/PlayerSourceTrad/LemGame.pas
///
/// This implementation does not copy source code or resource bitmaps.
/// Destructive masks come from the user's MAIN.DAT.
public enum ClassicDOSRules {
    public static let ticksPerSecond = 17
    public static let entranceOpenTick = 35
    public static let firstReleaseCountdown = 20
    public static let minimumX = 0
    public static let classicMaximumX = 1_647
    public static let classicMaximumY = 163
    public static let maximumSafeFallDistance = 60

    /// Returns the number of logic ticks from one release to the next.
    public static func releaseInterval(for releaseRate: Int) -> Int {
        var value = 99 - (releaseRate & 0xFF)
        if value < 0 { value += 256 }
        return value / 2 + 4
    }

    /// Expands one to four DOS hatches into the four-entry release table.
    /// Original Lemmings uses A-B-B-A for two hatches; the later releases use
    /// A-B-A-B. Both use A-B-C-B for three.
    public static func hatchOrder(entranceCount: Int, mechanics: ClassicDOSMechanics = .original) -> [Int] {
        switch entranceCount {
        case 1: return [0, 0, 0, 0]
        case 2: return mechanics == .original ? [0, 1, 1, 0] : [0, 1, 0, 1]
        case 3: return [0, 1, 2, 1]
        default: return [0, 1, 2, 3]
        }
    }
}

/// The DOS rule set a level runs under.
///
/// Oh No! More Lemmings changed three behaviours, and the Xmas and Holiday
/// releases kept them: lemmings leave a hatch one pixel further right, two
/// hatches release A-B-A-B, and giving a climber to a shrugging builder no
/// longer makes it walk. Lemmix models the same split (DOSORIG_MECHANICS and
/// DOSOHNO_MECHANICS). Oh No! Havoc 20 depends on the spawn position.
public enum ClassicDOSMechanics: String, Codable, Sendable {
    case original
    case ohNoMore

    /// The rule set for a level from a release, and a rank for the Oh Yes!
    /// pack, which gathers levels from several releases.
    public init(title: ClassicTitle?, rank: String) {
        switch title {
        case .ohNoMoreLemmings, .xmasLemmings1991, .xmasLemmings1992,
             .holidayLemmings1993, .holidayLemmings1994:
            self = .ohNoMore
        case .ohYesMoreLemmings:
            self = rank == "Oh No! More Lemmings Versus" ? .ohNoMore : .original
        default:
            self = .original
        }
    }

    /// Horizontal distance from a hatch object to its new lemmings' feet.
    var hatchOffsetX: Int { self == .original ? 24 : 25 }
}

public struct ClassicDOSPoint: Codable, Equatable, Hashable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public struct ClassicDOSRect: Codable, Equatable, Sendable {
    public let x1: Int
    public let y1: Int
    public let x2: Int
    public let y2: Int

    public init(x1: Int, y1: Int, x2: Int, y2: Int) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }

    /// DOS trigger bounds are half-open: the right and bottom edges are out.
    public func contains(_ point: ClassicDOSPoint) -> Bool {
        point.x >= x1 && point.x < x2 && point.y >= y1 && point.y < y2
    }
}

public enum ClassicDOSDirection: Int, Codable, Equatable, Sendable {
    case left = -1
    case right = 1

    public var delta: Int { rawValue }

    public mutating func turnAround() {
        self = self == .left ? .right : .left
    }
}

public enum ClassicDOSAction: String, Codable, Equatable, Sendable {
    case walking
    case falling
    case jumping
    case climbing
    case hoisting
    case floating
    case splatting
    case exiting
    case drowning
    case vaporizing
    case blocking
    case building
    case shrugging
    case bashing
    case mining
    case digging
    case ohNo
    case exploding
}

public enum ClassicDOSObjectEffect: Int, Codable, Equatable, Sendable {
    case none = 0
    case exit = 1
    case forceLeft = 2
    case forceRight = 3
    case triggeredTrap = 4
    case water = 5
    case fire = 6
    case oneWayLeft = 7
    case oneWayRight = 8
    case steel = 9
    /// The center cell of a dynamic blocker field.
    case blocker = 10
}

public enum ClassicDOSLemmingOutcome: String, Codable, Equatable, Sendable {
    case active
    case saved
    case lost
}

public struct ClassicDOSLemming: Identifiable, Codable, Equatable, Sendable {
    public let id: Int
    /// Every action uses this single gameplay foot point.
    public var foot: ClassicDOSPoint
    public var direction: ClassicDOSDirection
    public var action: ClassicDOSAction
    public var animationFrame: Int
    public var fallDistance: Int
    public var hasClimber: Bool
    public var hasFloater: Bool
    public var bomberCountdown: Int?
    public var bricksRemaining: Int
    public var outcome: ClassicDOSLemmingOutcome
    public var objectBelow: ClassicDOSObjectEffect
    public var objectInFront: ClassicDOSObjectEffect

    /// This stays true while a bombed blocker performs its countdown and Oh No.
    internal var ownsBlockerField: Bool
    /// DOS writes blocker cells once and leaves them at the assignment point.
    internal var blockerAnchor: ClassicDOSPoint?
    /// A splatter has dx = 0 even though its last facing direction is retained.
    internal var hasZeroHorizontalVelocity: Bool
    internal var isNewDigger: Bool
    internal var floatTableIndex: Int

    public var isActive: Bool { outcome == .active }
    public var hasActiveBlockerField: Bool { ownsBlockerField }

    internal init(id: Int, foot: ClassicDOSPoint) {
        self.id = id
        self.foot = foot
        direction = .right
        action = .falling
        animationFrame = 0
        fallDistance = 3
        hasClimber = false
        hasFloater = false
        bomberCountdown = nil
        bricksRemaining = 0
        outcome = .active
        objectBelow = .none
        objectInFront = .none
        ownsBlockerField = false
        blockerAnchor = nil
        hasZeroHorizontalVelocity = false
        isNewDigger = false
        floatTableIndex = 0
    }
}

public struct ClassicDOSMask: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    /// Draw offset from the lemming foot point.
    public let offsetX: Int
    public let offsetY: Int
    /// One byte per pixel. A nonzero byte removes that pixel.
    public let pixels: Data

    public init(
        width: Int,
        height: Int,
        offsetX: Int = 0,
        offsetY: Int = 0,
        pixels: Data
    ) throws {
        guard width > 0, height > 0, width <= Int.max / height,
              pixels.count == width * height else {
            throw ClassicDOSSimulationError.invalidDestructionMask(
                width: width,
                height: height,
                bytes: pixels.count
            )
        }
        self.width = width
        self.height = height
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.pixels = pixels
    }

    public init(mainDATBitmap: ClassicMonochromeBitmap) throws {
        try self.init(
            width: mainDATBitmap.width,
            height: mainDATBitmap.height,
            offsetX: mainDATBitmap.offsetX,
            offsetY: mainDATBitmap.offsetY,
            pixels: mainDATBitmap.bits
        )
    }
}

public struct ClassicDOSDestructionMaskSet: Codable, Equatable, Sendable {
    public let explosion: ClassicDOSMask
    public let bashRight: [ClassicDOSMask]
    public let bashLeft: [ClassicDOSMask]
    public let mineRight: [ClassicDOSMask]
    public let mineLeft: [ClassicDOSMask]

    public init(
        explosion: ClassicDOSMask,
        bashRight: [ClassicDOSMask],
        bashLeft: [ClassicDOSMask],
        mineRight: [ClassicDOSMask],
        mineLeft: [ClassicDOSMask]
    ) throws {
        guard explosion.width == 16, explosion.height == 22,
              bashRight.count == 4, bashLeft.count == 4,
              bashRight.allSatisfy({ $0.width == 16 && $0.height == 10 }),
              bashLeft.allSatisfy({ $0.width == 16 && $0.height == 10 }),
              mineRight.count == 2, mineLeft.count == 2,
              mineRight.allSatisfy({ $0.width == 16 && $0.height == 13 }),
              mineLeft.allSatisfy({ $0.width == 16 && $0.height == 13 }) else {
            throw ClassicDOSSimulationError.invalidDestructionMaskSet
        }
        self.explosion = explosion
        self.bashRight = bashRight
        self.bashLeft = bashLeft
        self.mineRight = mineRight
        self.mineLeft = mineLeft
    }

    /// Adapts masks decoded from the user's MAIN.DAT without retaining assets.
    public init(mainDATMasks: ClassicDestructionMasks) throws {
        // MAIN.DAT mine-mask offsets describe the assignment point. Entering
        // the mining action first moves the current foot point down one pixel.
        func mineMask(_ bitmap: ClassicMonochromeBitmap) throws -> ClassicDOSMask {
            try ClassicDOSMask(
                width: bitmap.width,
                height: bitmap.height,
                offsetX: bitmap.offsetX,
                offsetY: bitmap.offsetY - 1,
                pixels: bitmap.bits
            )
        }
        try self.init(
            explosion: ClassicDOSMask(mainDATBitmap: mainDATMasks.explosion),
            bashRight: try mainDATMasks.bashRight.map(ClassicDOSMask.init(mainDATBitmap:)),
            bashLeft: try mainDATMasks.bashLeft.map(ClassicDOSMask.init(mainDATBitmap:)),
            mineRight: try mainDATMasks.mineRight.map(mineMask),
            mineLeft: try mainDATMasks.mineLeft.map(mineMask)
        )
    }
}

public struct ClassicDOSTerrain: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    private var solidPixels: [UInt8]
    private let steelPixels: [UInt8]

    public init(width: Int, height: Int, solidMask: Data, steelMask: Data) throws {
        guard width > 0, height > 0, width <= Int.max / height else {
            throw ClassicDOSSimulationError.invalidTerrainSize(width: width, height: height)
        }
        let count = width * height
        guard solidMask.count == count else {
            throw ClassicDOSSimulationError.invalidSolidMask(expected: count, actual: solidMask.count)
        }
        guard steelMask.count == count else {
            throw ClassicDOSSimulationError.invalidSteelMask(expected: count, actual: steelMask.count)
        }
        self.width = width
        self.height = height
        solidPixels = solidMask.map { $0 == 0 ? 0 : 1 }
        steelPixels = steelMask.map { $0 == 0 ? 0 : 1 }
    }

    public init(renderedLevel: ClassicRenderedLevel) throws {
        try self.init(
            width: renderedLevel.width,
            height: renderedLevel.height,
            solidMask: renderedLevel.solidMask,
            steelMask: renderedLevel.steelMask
        )
    }

    public var solidMask: Data { Data(solidPixels) }
    public var steelMask: Data { Data(steelPixels) }

    /// The two masks end to end, for canonical hashing.
    ///
    /// The pixel arrays are private, so this is the only way a digest can
    /// cover terrain without exposing the storage.
    var canonicalMaskBytes: Data {
        var bytes = Data(capacity: solidPixels.count + steelPixels.count)
        bytes.append(contentsOf: solidPixels)
        bytes.append(contentsOf: steelPixels)
        return bytes
    }

    public func isSolid(x: Int, y: Int) -> Bool {
        guard contains(x: x, y: y) else { return false }
        return solidPixels[y * width + x] != 0
    }

    public func isSteelProtected(x: Int, y: Int) -> Bool {
        guard contains(x: x, y: y) else { return false }
        return steelPixels[y * width + x] != 0
    }

    /// Builder terrain becomes steel-resistant when it enters a protection area.
    @discardableResult
    public mutating func addSolid(x: Int, y: Int) -> Bool {
        guard contains(x: x, y: y) else { return false }
        let index = y * width + x
        guard solidPixels[index] == 0 else { return false }
        solidPixels[index] = 1
        return true
    }

    /// Direct terrain edits preserve steel. DOS skills use their own steel probes.
    @discardableResult
    public mutating func removeSolid(x: Int, y: Int) -> Bool {
        guard contains(x: x, y: y) else { return false }
        let index = y * width + x
        guard solidPixels[index] != 0, steelPixels[index] == 0 else { return false }
        solidPixels[index] = 0
        return true
    }

    /// DOS checks steel at skill-specific probe points before applying a mask.
    /// A mask can overlap protected pixels when its probe is outside steel.
    fileprivate mutating func removeDOSPixel(x: Int, y: Int) -> Bool {
        guard contains(x: x, y: y) else { return false }
        let index = y * width + x
        guard solidPixels[index] != 0 else { return false }
        solidPixels[index] = 0
        return true
    }

    private func contains(x: Int, y: Int) -> Bool {
        x >= 0 && y >= 0 && x < width && y < height
    }
}

public struct ClassicDOSTrigger: Codable, Equatable, Sendable {
    public let id: Int
    public let effect: ClassicDOSObjectEffect
    public let bounds: ClassicDOSRect
    /// Triggered traps reject another lemming for this many ticks.
    public let trapResetTicks: Int

    public init(
        id: Int,
        effect: ClassicDOSObjectEffect,
        bounds: ClassicDOSRect,
        trapResetTicks: Int = 1
    ) {
        self.id = id
        self.effect = effect
        self.bounds = bounds
        self.trapResetTicks = max(1, trapResetTicks)
    }
}

public struct ClassicDOSConfiguration: Codable, Equatable, Sendable {
    public let totalLemmings: Int
    public let requiredToSave: Int
    public let timeLimitTicks: Int?
    public let initialReleaseRate: Int
    public let entrances: [ClassicDOSPoint]
    public let triggers: [ClassicDOSTrigger]
    public let initialSkills: [ClassicSkill: Int]
    public let maximumX: Int
    public let maximumY: Int
    public let mechanics: ClassicDOSMechanics

    public init(
        totalLemmings: Int,
        requiredToSave: Int,
        timeLimitTicks: Int?,
        initialReleaseRate: Int,
        entrances: [ClassicDOSPoint],
        triggers: [ClassicDOSTrigger] = [],
        initialSkills: [ClassicSkill: Int] = [:],
        maximumX: Int = ClassicDOSRules.classicMaximumX,
        maximumY: Int = ClassicDOSRules.classicMaximumY,
        mechanics: ClassicDOSMechanics = .original
    ) {
        self.totalLemmings = max(0, totalLemmings)
        self.requiredToSave = max(0, requiredToSave)
        self.timeLimitTicks = timeLimitTicks.map { max(0, $0) }
        self.initialReleaseRate = initialReleaseRate & 0xFF
        self.entrances = Array(entrances.prefix(4))
        self.triggers = triggers
        self.initialSkills = Dictionary(
            uniqueKeysWithValues: ClassicSkill.allCases.map { ($0, max(0, initialSkills[$0] ?? 0)) }
        )
        self.maximumX = maximumX
        self.maximumY = maximumY
        self.mechanics = mechanics
    }

    private enum CodingKeys: String, CodingKey {
        case totalLemmings, requiredToSave, timeLimitTicks, initialReleaseRate, entrances
        case triggers, initialSkills, maximumX, maximumY, mechanics
    }

    // Checkpoints saved before the rule sets existed decode as original rules.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalLemmings = try c.decode(Int.self, forKey: .totalLemmings)
        requiredToSave = try c.decode(Int.self, forKey: .requiredToSave)
        timeLimitTicks = try c.decodeIfPresent(Int.self, forKey: .timeLimitTicks)
        initialReleaseRate = try c.decode(Int.self, forKey: .initialReleaseRate)
        entrances = try c.decode([ClassicDOSPoint].self, forKey: .entrances)
        triggers = try c.decode([ClassicDOSTrigger].self, forKey: .triggers)
        initialSkills = try c.decode([ClassicSkill: Int].self, forKey: .initialSkills)
        maximumX = try c.decode(Int.self, forKey: .maximumX)
        maximumY = try c.decode(Int.self, forKey: .maximumY)
        mechanics = try c.decodeIfPresent(ClassicDOSMechanics.self, forKey: .mechanics) ?? .original
    }
}

public enum ClassicDOSAssignmentResult: String, Codable, Equatable, Sendable {
    case assigned
    case noSuchLemming
    case inactiveLemming
    case noSkillRemaining
    case alreadyHasSkill
    case invalidAction
    case steel
    case wrongOneWayDirection
    case overlappingBlockerField
    case destructionMasksUnavailable
}

public struct ClassicDOSSkillCommand: Codable, Equatable, Sendable {
    /// DOS replay actions are applied after lemming updates on this tick.
    public let tick: Int
    public let lemmingID: Int
    public let skill: ClassicSkill

    public init(tick: Int, lemmingID: Int, skill: ClassicSkill) {
        self.tick = tick
        self.lemmingID = lemmingID
        self.skill = skill
    }
}

public enum ClassicDOSEvent: Codable, Equatable, Sendable {
    case entrancesOpened
    case hatched(lemmingID: Int, entranceIndex: Int)
    case skillAssigned(lemmingID: Int, skill: ClassicSkill)
    case skillAssignmentRejected(
        lemmingID: Int,
        skill: ClassicSkill,
        result: ClassicDOSAssignmentResult
    )
    case actionChanged(lemmingID: Int, from: ClassicDOSAction, to: ClassicDOSAction)
    case directionChanged(lemmingID: Int, direction: ClassicDOSDirection)
    case terrainAdded(lemmingID: Int, skill: ClassicSkill, pixelCount: Int)
    case terrainRemoved(lemmingID: Int, skill: ClassicSkill, pixelCount: Int)
    case hitSteel(lemmingID: Int)
    case builderWarning(lemmingID: Int)
    case triggerActivated(lemmingID: Int, triggerID: Int, effect: ClassicDOSObjectEffect)
    case saved(lemmingID: Int)
    case lost(lemmingID: Int)
    case fellOut(lemmingID: Int)
    case nukeStarted
    case releaseRateChanged(Int)
    case destructionMaskUnavailable(lemmingID: Int, skill: ClassicSkill)
}

public enum ClassicDOSSimulationError: Error, Equatable, CustomStringConvertible {
    case noEntrances
    case invalidTerrainSize(width: Int, height: Int)
    case invalidSolidMask(expected: Int, actual: Int)
    case invalidSteelMask(expected: Int, actual: Int)
    case invalidDestructionMask(width: Int, height: Int, bytes: Int)
    case invalidDestructionMaskSet

    public var description: String {
        switch self {
        case .noEntrances:
            return "A DOS simulation requires at least one entrance."
        case let .invalidTerrainSize(width, height):
            return "The DOS terrain size \(width)x\(height) is invalid."
        case let .invalidSolidMask(expected, actual):
            return "The solid mask needs \(expected) bytes; found \(actual)."
        case let .invalidSteelMask(expected, actual):
            return "The steel mask needs \(expected) bytes; found \(actual)."
        case let .invalidDestructionMask(width, height, bytes):
            return "The \(width)x\(height) destruction mask has \(bytes) bytes."
        case .invalidDestructionMaskSet:
            return "The DOS destruction mask set has invalid frame counts or sizes."
        }
    }
}

private struct ClassicDOSTriggerState: Codable, Equatable, Sendable {
    let trigger: ClassicDOSTrigger
    var cooldown: Int
}

private struct ClassicDOSQueuedCommand: Codable, Equatable, Sendable {
    let sequence: Int
    let command: ClassicDOSSkillCommand
}

public struct ClassicDOSSimulation: Codable, Equatable, Sendable {
    public private(set) var terrain: ClassicDOSTerrain
    public private(set) var lemmings: [ClassicDOSLemming]
    public private(set) var tickCount: Int
    public private(set) var releasedCount: Int
    public private(set) var savedCount: Int
    public private(set) var lostCount: Int
    public private(set) var releaseRate: Int
    public private(set) var remainingTimeTicks: Int?
    public private(set) var skills: [ClassicSkill: Int]
    public private(set) var isNuking: Bool
    public private(set) var lastTickEvents: [ClassicDOSEvent]
    public let configuration: ClassicDOSConfiguration

    private var releaseLimit: Int
    private var nextReleaseCountdown: Int
    private var triggerStates: [ClassicDOSTriggerState]
    public var comparisonDestructionMasks: ClassicDOSDestructionMaskSet? { destructionMasks }
    private var destructionMasks: ClassicDOSDestructionMaskSet?
    private var nukeCursor: Int
    private let hatchTable: [Int]
    private var commandSequence: Int
    private var queuedCommands: [ClassicDOSQueuedCommand]

    /// Remaining animation ticks for a triggered object, in trigger-map order.
    public func objectCooldown(at index: Int) -> Int {
        triggerStates.indices.contains(index) ? triggerStates[index].cooldown : 0
    }

    public var activeCount: Int { lemmings.lazy.filter(\.isActive).count }
    public var entrancesAreOpen: Bool { tickCount >= ClassicDOSRules.entranceOpenTick }
    public var didTimeOut: Bool { remainingTimeTicks == 0 }
    public var isComplete: Bool {
        didTimeOut || (releasedCount >= releaseLimit && activeCount == 0)
    }
    public var didWin: Bool { isComplete && savedCount >= configuration.requiredToSave }
    public var remainingTimeSeconds: Int? {
        remainingTimeTicks.map { ($0 + ClassicDOSRules.ticksPerSecond - 1) / ClassicDOSRules.ticksPerSecond }
    }

    public init(
        terrain: ClassicDOSTerrain,
        configuration: ClassicDOSConfiguration,
        destructionMasks: ClassicDOSDestructionMaskSet? = nil
    ) throws {
        guard !configuration.entrances.isEmpty else { throw ClassicDOSSimulationError.noEntrances }
        self.terrain = terrain
        self.configuration = configuration
        self.destructionMasks = destructionMasks
        lemmings = []
        tickCount = 0
        releasedCount = 0
        savedCount = 0
        lostCount = 0
        releaseRate = configuration.initialReleaseRate
        remainingTimeTicks = configuration.timeLimitTicks
        skills = configuration.initialSkills
        isNuking = false
        lastTickEvents = []
        releaseLimit = configuration.totalLemmings
        nextReleaseCountdown = ClassicDOSRules.firstReleaseCountdown
        triggerStates = configuration.triggers.map { ClassicDOSTriggerState(trigger: $0, cooldown: 0) }
        nukeCursor = 0
        hatchTable = ClassicDOSRules.hatchOrder(
            entranceCount: configuration.entrances.count, mechanics: configuration.mechanics)
        commandSequence = 0
        queuedCommands = []
    }

    public init(
        level: ClassicLevel,
        renderedLevel: ClassicRenderedLevel,
        destructionMasks: ClassicDOSDestructionMaskSet? = nil,
        mechanics: ClassicDOSMechanics = .original
    ) throws {
        let interactiveObjects = renderedLevel.objects.filter {
            $0.placement.slot < 16 && $0.graphic.triggerEffect != 0
        }
        let triggers = renderedLevel.triggers.enumerated().map { index, zone in
            let object = interactiveObjects.indices.contains(index) ? interactiveObjects[index] : nil
            return ClassicDOSTrigger(
                id: index,
                effect: ClassicDOSObjectEffect(rawValue: zone.effect) ?? .none,
                bounds: ClassicDOSRect(x1: zone.x1, y1: zone.y1, x2: zone.x2, y2: zone.y2),
                trapResetTicks: object?.graphic.frames.count ?? 1
            )
        }
        // DOS builds its hatch table before it excludes visual-fake objects
        // from the interactive object map. Entrances after slot 15 therefore
        // still release lemmings, as several retail levels require.
        let entrances = renderedLevel.objects
            .filter { $0.placement.id == 1 }
            .prefix(4)
            .map {
                ClassicDOSPoint(
                    x: $0.placement.x + mechanics.hatchOffsetX,
                    y: $0.placement.y + 14
                )
        }
        let timeLimit = level.timeLimitMinutes > 0
            ? level.timeLimitMinutes * 60 * ClassicDOSRules.ticksPerSecond
            : nil
        let configuration = ClassicDOSConfiguration(
            totalLemmings: level.lemmingCount,
            requiredToSave: level.saveRequirement,
            timeLimitTicks: timeLimit,
            initialReleaseRate: level.releaseRate,
            entrances: entrances,
            triggers: triggers,
            initialSkills: level.skills,
            maximumX: renderedLevel.width == ClassicLevel.width
                ? ClassicDOSRules.classicMaximumX
                : renderedLevel.width - 1,
            maximumY: renderedLevel.height == ClassicLevel.height
                ? ClassicDOSRules.classicMaximumY
                : renderedLevel.height + 3,
            mechanics: mechanics
        )
        try self.init(
            terrain: ClassicDOSTerrain(renderedLevel: renderedLevel),
            configuration: configuration,
            destructionMasks: destructionMasks
        )
    }

    public init(
        level: ClassicLevel,
        renderedLevel: ClassicRenderedLevel,
        mainDATAssets: ClassicMainDATAssets,
        mechanics: ClassicDOSMechanics = .original
    ) throws {
        try self.init(
            level: level,
            renderedLevel: renderedLevel,
            destructionMasks: ClassicDOSDestructionMaskSet(
                mainDATMasks: mainDATAssets.destructionMasks
            ),
            mechanics: mechanics
        )
    }

    public func remainingSkillCount(_ skill: ClassicSkill) -> Int {
        skills[skill] ?? 0
    }

    public var pendingSkillCommands: [ClassicDOSSkillCommand] {
        queuedCommands.map(\.command)
    }

    /// Queues a replay-style command. Commands for one tick keep insertion order.
    @discardableResult
    public mutating func schedule(_ command: ClassicDOSSkillCommand) -> Bool {
        guard command.tick > tickCount else { return false }
        queuedCommands.append(ClassicDOSQueuedCommand(sequence: commandSequence, command: command))
        commandSequence += 1
        queuedCommands.sort {
            if $0.command.tick != $1.command.tick { return $0.command.tick < $1.command.tick }
            return $0.sequence < $1.sequence
        }
        return true
    }

    public mutating func setReleaseRate(_ value: Int) {
        lastTickEvents = []
        let minimum = min(99, max(0, configuration.initialReleaseRate))
        let adjusted = min(99, max(minimum, value))
        guard adjusted != releaseRate else { return }
        releaseRate = adjusted
        lastTickEvents = [.releaseRateChanged(adjusted)]
    }

    public mutating func beginNuke() {
        lastTickEvents = []
        guard !isNuking else { return }
        isNuking = true
        releaseLimit = releasedCount
        nukeCursor = 0
        lastTickEvents = [.nukeStarted]
    }

    @discardableResult
    public mutating func assign(_ skill: ClassicSkill, to lemmingID: Int) -> ClassicDOSAssignmentResult {
        var events: [ClassicDOSEvent] = []
        let result = performAssignment(skill, to: lemmingID, events: &events)
        lastTickEvents = events
        return result
    }

    /// Advances one 1/17-second DOS logic tick.
    @discardableResult
    public mutating func tick() -> [ClassicDOSEvent] {
        guard !isComplete else {
            lastTickEvents = []
            return []
        }

        var events: [ClassicDOSEvent] = []
        tickCount += 1
        if let remainingTimeTicks, remainingTimeTicks > 0 {
            self.remainingTimeTicks = remainingTimeTicks - 1
        }
        if tickCount == ClassicDOSRules.entranceOpenTick {
            events.append(.entrancesOpened)
        }
        releaseLemmingIfNeeded(events: &events)

        for index in lemmings.indices {
            guard lemmings[index].isActive else { continue }
            var lemming = lemmings[index]
            if let countdown = lemming.bomberCountdown {
                lemming.bomberCountdown = countdown - 1
                if countdown - 1 == 0 {
                    lemming.bomberCountdown = nil
                    let immediate = [
                        ClassicDOSAction.vaporizing,
                        .drowning,
                        .floating,
                        .falling,
                    ].contains(lemming.action)
                    transition(&lemming, to: immediate ? .exploding : .ohNo, events: &events)
                    lemmings[index] = lemming
                    continue
                }
            }

            let handleObjects = handleAction(&lemming, events: &events)
            if handleObjects, lemming.isActive {
                checkInteractiveObjects(&lemming, events: &events)
            }
            lemmings[index] = lemming
        }

        updateNuke(events: &events)
        // DOS advances triggered-object animation after all lemmings. A trap
        // that fires this tick is therefore still unavailable to later
        // lemmings in the same tick, then advances one frame at tick end.
        for index in triggerStates.indices where triggerStates[index].cooldown > 0 {
            triggerStates[index].cooldown -= 1
        }
        applyQueuedCommands(events: &events)
        lastTickEvents = events
        return events
    }

    private mutating func applyQueuedCommands(events: inout [ClassicDOSEvent]) {
        while let queued = queuedCommands.first, queued.command.tick <= tickCount {
            queuedCommands.removeFirst()
            let result = performAssignment(
                queued.command.skill,
                to: queued.command.lemmingID,
                events: &events
            )
            if result != .assigned {
                events.append(.skillAssignmentRejected(
                    lemmingID: queued.command.lemmingID,
                    skill: queued.command.skill,
                    result: result
                ))
            }
        }
    }

    private mutating func performAssignment(
        _ skill: ClassicSkill,
        to lemmingID: Int,
        events: inout [ClassicDOSEvent]
    ) -> ClassicDOSAssignmentResult {
        guard let index = lemmings.firstIndex(where: { $0.id == lemmingID }) else {
            return .noSuchLemming
        }
        guard lemmings[index].isActive else { return .inactiveLemming }
        guard remainingSkillCount(skill) > 0 else { return .noSkillRemaining }
        let result = assign(skill, toLemmingAt: index, events: &events)
        if result == .assigned {
            skills[skill, default: 0] -= 1
            events.append(.skillAssigned(lemmingID: lemmingID, skill: skill))
        }
        return result
    }

    private mutating func releaseLemmingIfNeeded(events: inout [ClassicDOSEvent]) {
        guard entrancesAreOpen, !isNuking else { return }
        nextReleaseCountdown -= 1
        guard nextReleaseCountdown == 0 else { return }
        nextReleaseCountdown = ClassicDOSRules.releaseInterval(for: releaseRate)
        guard releasedCount < releaseLimit else { return }

        let tableIndex = releasedCount % 4
        let entranceIndex = hatchTable[tableIndex]
        let lemming = ClassicDOSLemming(
            id: releasedCount,
            foot: configuration.entrances[entranceIndex]
        )
        lemmings.append(lemming)
        events.append(.hatched(lemmingID: releasedCount, entranceIndex: entranceIndex))
        releasedCount += 1
    }

    private mutating func updateNuke(events: inout [ClassicDOSEvent]) {
        guard isNuking else { return }
        while nukeCursor < lemmings.count, !lemmings[nukeCursor].isActive {
            nukeCursor += 1
        }
        guard nukeCursor < lemmings.count else { return }
        let action = lemmings[nukeCursor].action
        if lemmings[nukeCursor].bomberCountdown == nil,
           action != .splatting,
           action != .exploding {
            lemmings[nukeCursor].bomberCountdown = 79
        }
        nukeCursor += 1
    }

    private mutating func assign(
        _ skill: ClassicSkill,
        toLemmingAt index: Int,
        events: inout [ClassicDOSEvent]
    ) -> ClassicDOSAssignmentResult {
        var lemming = lemmings[index]
        switch skill {
        case .climber:
            guard !lemming.hasClimber else { return .alreadyHasSkill }
            guard ![.blocking, .splatting, .exploding].contains(lemming.action) else {
                return .invalidAction
            }
            lemming.hasClimber = true
            // Original Lemmings only: the climber ends a builder's shrug.
            if lemming.action == .shrugging, configuration.mechanics == .original {
                transition(&lemming, to: .walking, events: &events)
            }

        case .floater:
            guard !lemming.hasFloater else { return .alreadyHasSkill }
            guard ![.blocking, .splatting, .exploding].contains(lemming.action) else {
                return .invalidAction
            }
            lemming.hasFloater = true

        case .bomber:
            guard lemming.bomberCountdown == nil,
                  ![.ohNo, .exploding, .vaporizing, .splatting].contains(lemming.action) else {
                return .invalidAction
            }
            lemming.bomberCountdown = 79

        case .blocker:
            let allowed: [ClassicDOSAction] = [.walking, .shrugging, .building, .bashing, .mining, .digging]
            guard allowed.contains(lemming.action) else { return .invalidAction }
            guard !blockerFieldWouldOverlap(lemming) else { return .overlappingBlockerField }
            transition(&lemming, to: .blocking, events: &events)
            lemming.ownsBlockerField = true
            lemming.blockerAnchor = lemming.foot

        case .builder:
            let allowed: [ClassicDOSAction] = [.walking, .shrugging, .bashing, .mining, .digging]
            guard allowed.contains(lemming.action), lemming.foot.y + frameTop(for: lemming.action) >= -5 else {
                return .invalidAction
            }
            transition(&lemming, to: .building, events: &events)

        case .basher:
            guard destructionMasks != nil else { return .destructionMasksUnavailable }
            let allowed: [ClassicDOSAction] = [.walking, .shrugging, .building, .mining, .digging]
            guard allowed.contains(lemming.action) else { return .invalidAction }
            if lemming.objectInFront == .steel { return .steel }
            if blocksDirection(lemming.objectInFront, direction: lemming.direction) {
                return .wrongOneWayDirection
            }
            transition(&lemming, to: .bashing, events: &events)

        case .miner:
            guard destructionMasks != nil else { return .destructionMasksUnavailable }
            let allowed: [ClassicDOSAction] = [.walking, .shrugging, .building, .bashing, .digging]
            guard allowed.contains(lemming.action) else { return .invalidAction }
            if lemming.objectInFront == .steel || lemming.objectBelow == .steel { return .steel }
            if blocksDirection(lemming.objectInFront, direction: lemming.direction) {
                return .wrongOneWayDirection
            }
            transition(&lemming, to: .mining, events: &events)

        case .digger:
            guard lemming.objectBelow != .steel else { return .steel }
            let allowed: [ClassicDOSAction] = [.walking, .shrugging, .building, .bashing, .mining]
            guard allowed.contains(lemming.action) else { return .invalidAction }
            transition(&lemming, to: .digging, events: &events)
        }
        lemmings[index] = lemming
        return .assigned
    }

    private mutating func handleAction(
        _ lemming: inout ClassicDOSLemming,
        events: inout [ClassicDOSEvent]
    ) -> Bool {
        let animationEnded = advanceAnimation(&lemming)
        switch lemming.action {
        case .walking:
            return handleWalking(&lemming, events: &events)
        case .falling:
            return handleFalling(&lemming, events: &events)
        case .jumping:
            return handleJumping(&lemming, events: &events)
        case .climbing:
            return handleClimbing(&lemming, events: &events)
        case .hoisting:
            return handleHoisting(&lemming, animationEnded: animationEnded, events: &events)
        case .floating:
            return handleFloating(&lemming, events: &events)
        case .splatting:
            if animationEnded { lose(&lemming, events: &events) }
            return false
        case .exiting:
            if animationEnded { save(&lemming, events: &events) }
            return false
        case .drowning:
            if animationEnded {
                lose(&lemming, events: &events)
            } else if !terrain.isSolid(
                x: lemming.foot.x + 8 * horizontalDelta(for: lemming),
                y: lemming.foot.y
            ) {
                lemming.foot.x += horizontalDelta(for: lemming)
            }
            return false
        case .vaporizing:
            if animationEnded { lose(&lemming, events: &events) }
            return false
        case .blocking:
            if !hasPixelClipped(x: lemming.foot.x, y: lemming.foot.y, minimumY: 0) {
                clearBlockerField(&lemming)
                transition(&lemming, to: .walking, events: &events)
            }
            return false
        case .building:
            return handleBuilding(&lemming, events: &events)
        case .shrugging:
            if animationEnded {
                transition(&lemming, to: .walking, events: &events)
                return true
            }
            return false
        case .bashing:
            return handleBashing(&lemming, events: &events)
        case .mining:
            return handleMining(&lemming, events: &events)
        case .digging:
            return handleDigging(&lemming, events: &events)
        case .ohNo:
            if animationEnded {
                transition(&lemming, to: .exploding, events: &events)
                return false
            }
            var distance = 0
            while distance < 3,
                  !hasPixelClipped(x: lemming.foot.x, y: lemming.foot.y, minimumY: distance) {
                distance += 1
                lemming.foot.y += 1
            }
            if lemming.foot.y > configuration.maximumY {
                lose(&lemming, events: &events)
                return false
            }
            return true
        case .exploding:
            if lemming.animationFrame == 1 {
                let blockerOwnerID = lemming.ownsBlockerField ? lemming.id : nil
                clearBlockerField(&lemming)
                applyExplosion(
                    for: &lemming,
                    excludingBlockerOwnerID: blockerOwnerID,
                    events: &events
                )
            }
            if animationEnded { lose(&lemming, events: &events) }
            return false
        }
    }

    private mutating func handleWalking(
        _ lemming: inout ClassicDOSLemming,
        events: inout [ClassicDOSEvent]
    ) -> Bool {
        lemming.foot.x += lemming.direction.delta
        guard lemming.foot.x >= ClassicDOSRules.minimumX,
              lemming.foot.x <= configuration.maximumX else {
            turnAround(&lemming, events: &events)
            return true
        }

        if hasPixelClipped(x: lemming.foot.x, y: lemming.foot.y, minimumY: 0) {
            var distance = 0
            var newY = lemming.foot.y
            while distance <= 6,
                  hasPixelClipped(x: lemming.foot.x, y: newY - 1, minimumY: -distance - 1) {
                distance += 1
                newY -= 1
            }
            if distance > 6 {
                if lemming.hasClimber {
                    transition(&lemming, to: .climbing, events: &events)
                } else {
                    turnAround(&lemming, events: &events)
                }
            } else {
                if distance >= 3 {
                    transition(&lemming, to: .jumping, events: &events)
                    newY = lemming.foot.y - 2
                }
                lemming.foot.y = newY
                checkLevelTop(&lemming, events: &events)
            }
            return true
        }

        var distance = 1
        while distance <= 3 {
            lemming.foot.y += 1
            if hasPixelClipped(x: lemming.foot.x, y: lemming.foot.y, minimumY: distance) {
                break
            }
            distance += 1
        }
        if distance > 3 {
            lemming.foot.y += 1
            transition(&lemming, to: .falling, events: &events)
        }
        if lemming.foot.y > configuration.maximumY {
            lose(&lemming, events: &events)
            return false
        }
        return true
    }

    private mutating func handleFalling(
        _ lemming: inout ClassicDOSLemming,
        events: inout [ClassicDOSEvent]
    ) -> Bool {
        if lemming.fallDistance > 16, lemming.hasFloater {
            transition(&lemming, to: .floating, events: &events)
            return true
        }

        var distance = 0
        while distance < 3,
              !hasPixelClipped(x: lemming.foot.x, y: lemming.foot.y, minimumY: distance) {
            distance += 1
            lemming.foot.y += 1
            if lemming.foot.y > configuration.maximumY {
                lose(&lemming, events: &events)
                return false
            }
        }
        if distance == 3 {
            lemming.fallDistance += 3
        } else if lemming.fallDistance > ClassicDOSRules.maximumSafeFallDistance {
            transition(&lemming, to: .splatting, events: &events)
        } else {
            transition(&lemming, to: .walking, events: &events)
        }
        // Returning true after a splat transition preserves the DOS direct-drop
        // exit behavior.
        return true
    }

    private mutating func handleJumping(
        _ lemming: inout ClassicDOSLemming,
        events: inout [ClassicDOSEvent]
    ) -> Bool {
        var distance = 0
        while distance < 2,
              hasPixelClipped(x: lemming.foot.x, y: lemming.foot.y - 1, minimumY: -distance - 1) {
            distance += 1
            lemming.foot.y -= 1
        }
        if distance < 2 { transition(&lemming, to: .walking, events: &events) }
        checkLevelTop(&lemming, events: &events)
        return true
    }

    private mutating func handleClimbing(
        _ lemming: inout ClassicDOSLemming,
        events: inout [ClassicDOSEvent]
    ) -> Bool {
        if lemming.animationFrame <= 3 {
            if !hasPixelClipped(
                x: lemming.foot.x,
                y: lemming.foot.y - 7 - lemming.animationFrame,
                minimumY: 0
            ) {
                lemming.foot.y = lemming.foot.y - lemming.animationFrame + 2
                transition(&lemming, to: .hoisting, events: &events)
                checkLevelTop(&lemming, events: &events)
            }
        } else {
            lemming.foot.y -= 1
            if lemming.foot.y + frameTop(for: .climbing) < -5 ||
                hasPixelClipped(
                    x: lemming.foot.x - lemming.direction.delta,
                    y: lemming.foot.y - 8,
                    minimumY: -8
                ) {
                transition(&lemming, to: .falling, turnAround: true, events: &events)
                lemming.foot.x += lemming.direction.delta * 2
            }
        }
        return true
    }

    private mutating func handleHoisting(
        _ lemming: inout ClassicDOSLemming,
        animationEnded: Bool,
        events: inout [ClassicDOSEvent]
    ) -> Bool {
        if lemming.animationFrame <= 4 {
            lemming.foot.y -= 2
            checkLevelTop(&lemming, events: &events)
            return true
        }
        if animationEnded {
            transition(&lemming, to: .walking, events: &events)
            checkLevelTop(&lemming, events: &events)
            return true
        }
        return false
    }

    private mutating func handleFloating(
        _ lemming: inout ClassicDOSLemming,
        events: inout [ClassicDOSEvent]
    ) -> Bool {
        let table: [(dy: Int, frame: Int)] = [
            (3, 1), (3, 2), (3, 3), (3, 5), (-1, 5), (0, 5), (1, 5), (1, 5),
            (2, 5), (2, 6), (2, 7), (2, 7), (2, 6), (2, 5), (2, 4), (2, 4),
        ]
        let entry = table[lemming.floatTableIndex]
        lemming.animationFrame = entry.frame
        lemming.floatTableIndex += 1
        if lemming.floatTableIndex == table.count { lemming.floatTableIndex = 8 }

        if entry.dy <= 0 {
            lemming.foot.y += entry.dy
        } else {
            var remaining = entry.dy
            var minimumY = 0
            while remaining > 0 {
                if hasPixelClipped(x: lemming.foot.x, y: lemming.foot.y, minimumY: minimumY) {
                    transition(&lemming, to: .walking, events: &events)
                    return true
                }
                lemming.foot.y += 1
                remaining -= 1
                minimumY += 1
            }
        }
        if lemming.foot.y > configuration.maximumY {
            lose(&lemming, events: &events)
            return false
        }
        return true
    }

    private mutating func handleBuilding(
        _ lemming: inout ClassicDOSLemming,
        events: inout [ClassicDOSEvent]
    ) -> Bool {
        if lemming.animationFrame == 10, lemming.bricksRemaining <= 3 {
            events.append(.builderWarning(lemmingID: lemming.id))
        }
        if lemming.animationFrame == 9 ||
            (lemming.animationFrame == 10 && lemming.bricksRemaining == 9) {
            let startX = lemming.direction == .right ? lemming.foot.x : lemming.foot.x - 4
            var added = 0
            for x in startX..<(startX + 6) where terrain.addSolid(x: x, y: lemming.foot.y - 1) {
                added += 1
            }
            if added > 0 {
                events.append(.terrainAdded(lemmingID: lemming.id, skill: .builder, pixelCount: added))
            }
            return false
        }
        guard lemming.animationFrame == 0 else { return true }

        lemming.foot.x += lemming.direction.delta
        lemming.foot.y -= 1
        if lemming.foot.x <= ClassicDOSRules.minimumX ||
            lemming.foot.x > configuration.maximumX ||
            hasPixelClipped(x: lemming.foot.x, y: lemming.foot.y - 1, minimumY: -1) {
            transition(&lemming, to: .walking, turnAround: true, events: &events)
            checkLevelTop(&lemming, events: &events)
            return true
        }
        lemming.foot.x += lemming.direction.delta
        if hasPixelClipped(x: lemming.foot.x, y: lemming.foot.y - 1, minimumY: -1) {
            transition(&lemming, to: .walking, turnAround: true, events: &events)
            checkLevelTop(&lemming, events: &events)
            return true
        }
        lemming.bricksRemaining -= 1
        if lemming.bricksRemaining == 0 {
            transition(&lemming, to: .shrugging, events: &events)
            checkLevelTop(&lemming, events: &events)
            return true
        }
        if hasPixelClipped(
            x: lemming.foot.x + lemming.direction.delta * 2,
            y: lemming.foot.y - 9,
            minimumY: -9
        ) || lemming.foot.x <= ClassicDOSRules.minimumX || lemming.foot.x > configuration.maximumX {
            transition(&lemming, to: .walking, turnAround: true, events: &events)
            checkLevelTop(&lemming, events: &events)
            return true
        }
        if lemming.foot.y + frameTop(for: .building) < -5 {
            transition(&lemming, to: .walking, events: &events)
            checkLevelTop(&lemming, events: &events)
        }
        return true
    }

    private mutating func handleBashing(
        _ lemming: inout ClassicDOSLemming,
        events: inout [ClassicDOSEvent]
    ) -> Bool {
        let frame = lemming.animationFrame % 16
        if (11...15).contains(frame) {
            lemming.foot.x += lemming.direction.delta
            if lemming.foot.x < ClassicDOSRules.minimumX || lemming.foot.x > configuration.maximumX {
                transition(&lemming, to: .walking, turnAround: true, events: &events)
                return true
            }
            var distance = 0
            while distance < 3,
                  !hasPixelClipped(x: lemming.foot.x, y: lemming.foot.y, minimumY: distance) {
                distance += 1
                lemming.foot.y += 1
            }
            if distance == 3 {
                transition(&lemming, to: .falling, events: &events)
            } else {
                let effect = objectEffect(at: ClassicDOSPoint(
                    x: lemming.foot.x + lemming.direction.delta * 8,
                    y: lemming.foot.y - 8
                ))
                if effect == .steel {
                    events.append(.hitSteel(lemmingID: lemming.id))
                }
                if effect == .steel || blocksDirection(effect, direction: lemming.direction) {
                    transition(&lemming, to: .walking, turnAround: true, events: &events)
                }
            }
            return true
        }

        if (2...5).contains(frame) {
            guard let masks = destructionMasks else {
                events.append(.destructionMaskUnavailable(lemmingID: lemming.id, skill: .basher))
                transition(&lemming, to: .walking, events: &events)
                return false
            }
            let frames = lemming.direction == .right ? masks.bashRight : masks.bashLeft
            let removed = removeMask(
                frames[frame - 2],
                atX: lemming.foot.x + frames[frame - 2].offsetX,
                y: lemming.foot.y + frames[frame - 2].offsetY
            )
            if removed > 0 {
                events.append(.terrainRemoved(lemmingID: lemming.id, skill: .basher, pixelCount: removed))
            }
            if lemming.animationFrame == 5 {
                var empty = 0
                var x = lemming.foot.x + lemming.direction.delta * 8
                while empty < 4, !terrain.isSolid(x: x, y: lemming.foot.y - 6) {
                    empty += 1
                    x += lemming.direction.delta
                }
                if empty == 4 { transition(&lemming, to: .walking, events: &events) }
            }
        }
        return false
    }

    private mutating func handleMining(
        _ lemming: inout ClassicDOSLemming,
        events: inout [ClassicDOSEvent]
    ) -> Bool {
        if lemming.animationFrame == 1 || lemming.animationFrame == 2 {
            guard let masks = destructionMasks else {
                events.append(.destructionMaskUnavailable(lemmingID: lemming.id, skill: .miner))
                transition(&lemming, to: .walking, events: &events)
                return false
            }
            let frames = lemming.direction == .right ? masks.mineRight : masks.mineLeft
            let maskIndex = lemming.animationFrame - 1
            let xOffset = maskIndex == 0 ? 0 : lemming.direction.delta
            let yOffset = maskIndex == 0 ? 0 : 1
            let removed = removeMask(
                frames[maskIndex],
                atX: lemming.foot.x + xOffset + frames[maskIndex].offsetX,
                y: lemming.foot.y + yOffset + frames[maskIndex].offsetY
            )
            if removed > 0 {
                events.append(.terrainRemoved(lemmingID: lemming.id, skill: .miner, pixelCount: removed))
            }
            return false
        }

        if lemming.animationFrame == 3 || lemming.animationFrame == 15 {
            for _ in 0..<2 {
                lemming.foot.x += lemming.direction.delta
                if lemming.foot.x < ClassicDOSRules.minimumX || lemming.foot.x > configuration.maximumX {
                    transition(&lemming, to: .walking, turnAround: true, events: &events)
                    return true
                }
            }
            if lemming.animationFrame == 3 {
                lemming.foot.y += 1
                if lemming.foot.y > configuration.maximumY {
                    lose(&lemming, events: &events)
                    return false
                }
            }
            if !hasPixelClipped(x: lemming.foot.x, y: lemming.foot.y, minimumY: 0) {
                transition(&lemming, to: .falling, events: &events)
                return true
            }
            let below = objectEffect(at: lemming.foot)
            if below == .steel { events.append(.hitSteel(lemmingID: lemming.id)) }
            // Original DOS has a missing direction check for right-facing arrows.
            let blocked = below == .steel ||
                (below == .oneWayLeft && lemming.direction != .left) ||
                below == .oneWayRight
            if blocked {
                transition(&lemming, to: .walking, turnAround: true, events: &events)
            }
            return true
        }
        if lemming.animationFrame == 0 {
            lemming.foot.y += 1
            if lemming.foot.y > configuration.maximumY {
                lose(&lemming, events: &events)
                return false
            }
            return true
        }
        return false
    }

    private mutating func handleDigging(
        _ lemming: inout ClassicDOSLemming,
        events: inout [ClassicDOSEvent]
    ) -> Bool {
        if lemming.isNewDigger {
            let first = digRow(y: lemming.foot.y - 2, aroundX: lemming.foot.x)
            let second = digRow(y: lemming.foot.y - 1, aroundX: lemming.foot.x)
            let removed = first.removed + second.removed
            if removed > 0 {
                events.append(.terrainRemoved(lemmingID: lemming.id, skill: .digger, pixelCount: removed))
            }
            lemming.isNewDigger = false
        } else {
            lemming.animationFrame = (lemming.animationFrame + 1) % 16
        }

        if lemming.animationFrame == 0 || lemming.animationFrame == 8 {
            let y = lemming.foot.y
            lemming.foot.y += 1
            if lemming.foot.y > configuration.maximumY {
                lose(&lemming, events: &events)
                return false
            }
            let result = digRow(y: y, aroundX: lemming.foot.x)
            if result.removed > 0 {
                events.append(.terrainRemoved(
                    lemmingID: lemming.id,
                    skill: .digger,
                    pixelCount: result.removed
                ))
            }
            if !result.foundTerrain {
                transition(&lemming, to: .falling, events: &events)
            } else if objectEffect(at: lemming.foot) == .steel {
                events.append(.hitSteel(lemmingID: lemming.id))
                transition(&lemming, to: .walking, events: &events)
            }
            return true
        }
        return false
    }

    private mutating func checkInteractiveObjects(
        _ lemming: inout ClassicDOSLemming,
        events: inout [ClassicDOSEvent]
    ) {
        lemming.objectBelow = objectEffect(at: lemming.foot)
        lemming.objectInFront = objectEffect(at: ClassicDOSPoint(
            x: lemming.foot.x + 8 * horizontalDelta(for: lemming),
            y: lemming.foot.y - 8
        ))

        if let blockerEffect = blockerFieldEffect(at: lemming.foot) {
            let force: ClassicDOSDirection?
            switch blockerEffect {
            case .forceLeft: force = .left
            case .forceRight: force = .right
            default: force = nil
            }
            if let force {
                lemming.hasZeroHorizontalVelocity = false
                if lemming.direction != force {
                    lemming.direction = force
                    events.append(.directionChanged(lemmingID: lemming.id, direction: force))
                }
            }
            return
        }

        guard let triggerIndex = lastTriggerIndex(at: lemming.foot) else { return }
        let trigger = triggerStates[triggerIndex].trigger
        if trigger.effect == .triggeredTrap,
           triggerStates[triggerIndex].cooldown != 0 {
            return
        }
        events.append(.triggerActivated(
            lemmingID: lemming.id,
            triggerID: trigger.id,
            effect: trigger.effect
        ))
        switch trigger.effect {
        case .exit:
            if lemming.action != .falling, hasWalkedIntoExit(lemming, zone: trigger.bounds) {
                transition(&lemming, to: .exiting, events: &events)
            }
        case .forceLeft:
            lemming.hasZeroHorizontalVelocity = false
            if lemming.direction != .left {
                lemming.direction = .left
                events.append(.directionChanged(lemmingID: lemming.id, direction: .left))
            }
        case .forceRight:
            lemming.hasZeroHorizontalVelocity = false
            if lemming.direction != .right {
                lemming.direction = .right
                events.append(.directionChanged(lemmingID: lemming.id, direction: .right))
            }
        case .triggeredTrap:
            triggerStates[triggerIndex].cooldown = trigger.trapResetTicks
            lose(&lemming, events: &events)
        case .water:
            transition(&lemming, to: .drowning, events: &events)
        case .fire:
            transition(&lemming, to: .vaporizing, events: &events)
        case .none, .oneWayLeft, .oneWayRight, .steel, .blocker:
            break
        }
    }

    private func objectEffect(
        at point: ClassicDOSPoint,
        excludingBlockerOwnerID: Int? = nil
    ) -> ClassicDOSObjectEffect {
        if let blockerEffect = blockerFieldEffect(
            at: point,
            excludingOwnerID: excludingBlockerOwnerID
        ) {
            return blockerEffect
        }
        if let triggerIndex = lastTriggerIndex(at: point) {
            return triggerStates[triggerIndex].trigger.effect
        }
        if terrain.isSteelProtected(x: point.x, y: point.y) { return .steel }
        return .none
    }

    /// Use the exit centre when the next walking step stays inside its trigger.
    /// Slopes can lift a walker out of the trigger before it reaches the centre.
    /// Accept that walker now instead of letting it pass a usable exit.
    private func hasWalkedIntoExit(_ lemming: ClassicDOSLemming, zone: ClassicDOSRect) -> Bool {
        let middle = (zone.x1 + zone.x2) / 2
        let reachedMiddle = lemming.direction == .right
            ? lemming.foot.x >= middle : lemming.foot.x <= middle
        if reachedMiddle { return true }
        guard lemming.action == .walking else { return false }
        var preview = self
        var next = lemming
        var ignoredEvents: [ClassicDOSEvent] = []
        _ = preview.handleWalking(&next, events: &ignoredEvents)
        return !zone.contains(next.foot) || next.action != .walking
            || next.direction != lemming.direction
    }

    private func lastTriggerIndex(at point: ClassicDOSPoint) -> Int? {
        triggerStates.indices.last { triggerStates[$0].trigger.bounds.contains(point) }
    }

    private func blockerFieldEffect(
        at point: ClassicDOSPoint,
        excludingOwnerID: Int? = nil
    ) -> ClassicDOSObjectEffect? {
        let pointCell = blockerCell(x: point.x, y: point.y)
        for lemming in lemmings.reversed()
        where lemming.id != excludingOwnerID && lemming.isActive && lemming.ownsBlockerField {
            guard let anchor = lemming.blockerAnchor else { continue }
            for yOffset in [-6, -2, 2] {
                if pointCell == blockerCell(x: anchor.x - 4, y: anchor.y + yOffset) {
                    return .forceLeft
                }
                if pointCell == blockerCell(x: anchor.x, y: anchor.y + yOffset) {
                    return .blocker
                }
                if pointCell == blockerCell(x: anchor.x + 4, y: anchor.y + yOffset) {
                    return .forceRight
                }
            }
        }
        return nil
    }

    private func blockerFieldWouldOverlap(_ candidate: ClassicDOSLemming) -> Bool {
        let existing = Set(lemmings.lazy
            .filter { $0.isActive && $0.ownsBlockerField }
            .compactMap(\.blockerAnchor)
            .flatMap(blockerCells(anchor:)))
        return blockerCells(anchor: candidate.foot).contains { existing.contains($0) }
    }

    private func blockerCells(anchor: ClassicDOSPoint) -> [ClassicDOSPoint] {
        [-6, -2, 2].flatMap { yOffset in
            [-4, 0, 4].map { xOffset in
                blockerCell(x: anchor.x + xOffset, y: anchor.y + yOffset)
            }
        }
    }

    private func blockerCell(x: Int, y: Int) -> ClassicDOSPoint {
        ClassicDOSPoint(x: floorToMultipleOfFour(x), y: floorToMultipleOfFour(y))
    }

    private func floorToMultipleOfFour(_ value: Int) -> Int {
        value >= 0 ? value & ~3 : -((-value + 3) & ~3)
    }

    private func blocksDirection(
        _ effect: ClassicDOSObjectEffect,
        direction: ClassicDOSDirection
    ) -> Bool {
        (effect == .oneWayLeft && direction != .left) ||
            (effect == .oneWayRight && direction != .right)
    }

    private func hasPixelClipped(x: Int, y: Int, minimumY: Int) -> Bool {
        terrain.isSolid(x: x, y: y < minimumY ? minimumY : y)
    }

    private mutating func removeMask(_ mask: ClassicDOSMask, atX x: Int, y: Int) -> Int {
        let pixels = [UInt8](mask.pixels)
        var removed = 0
        for maskY in 0..<mask.height {
            for maskX in 0..<mask.width where pixels[maskY * mask.width + maskX] != 0 {
                if terrain.removeDOSPixel(x: x + maskX, y: y + maskY) { removed += 1 }
            }
        }
        return removed
    }

    private mutating func applyExplosion(
        for lemming: inout ClassicDOSLemming,
        excludingBlockerOwnerID: Int?,
        events: inout [ClassicDOSEvent]
    ) {
        let centerEffect = objectEffect(
            at: lemming.foot,
            excludingBlockerOwnerID: excludingBlockerOwnerID
        )
        guard centerEffect != .steel, centerEffect != .water else { return }
        guard let explosion = destructionMasks?.explosion else {
            events.append(.destructionMaskUnavailable(lemmingID: lemming.id, skill: .bomber))
            return
        }
        let removed = removeMask(
            explosion,
            atX: lemming.foot.x + explosion.offsetX,
            y: lemming.foot.y + explosion.offsetY
        )
        if removed > 0 {
            events.append(.terrainRemoved(lemmingID: lemming.id, skill: .bomber, pixelCount: removed))
        }
    }

    private mutating func digRow(y: Int, aroundX x: Int) -> (foundTerrain: Bool, removed: Int) {
        let row = max(0, y)
        var foundTerrain = false
        var removed = 0
        for pixelX in (x - 4)...(x + 4) {
            if terrain.isSolid(x: pixelX, y: row) { foundTerrain = true }
            if terrain.removeDOSPixel(x: pixelX, y: row) { removed += 1 }
        }
        return (foundTerrain, removed)
    }

    private mutating func transition(
        _ lemming: inout ClassicDOSLemming,
        to action: ClassicDOSAction,
        turnAround shouldTurn: Bool = false,
        events: inout [ClassicDOSEvent]
    ) {
        if shouldTurn { turnAround(&lemming, events: &events) }
        guard lemming.action != action else { return }
        let oldAction = lemming.action
        lemming.action = action
        lemming.animationFrame = 0
        lemming.fallDistance = 0
        lemming.bricksRemaining = 0
        switch action {
        case .falling:
            lemming.fallDistance = 3
        case .floating:
            lemming.floatTableIndex = 0
        case .building:
            lemming.bricksRemaining = 12
        case .mining:
            lemming.foot.y += 1
        case .digging:
            lemming.isNewDigger = true
        case .splatting:
            lemming.bomberCountdown = nil
            lemming.hasZeroHorizontalVelocity = true
        default:
            break
        }
        events.append(.actionChanged(lemmingID: lemming.id, from: oldAction, to: action))
    }

    private func animationMaximum(for action: ClassicDOSAction) -> (maximum: Int, loops: Bool)? {
        switch action {
        case .walking: return (7, true)
        case .falling: return (3, true)
        case .jumping: return nil
        case .climbing: return (7, true)
        case .hoisting: return (7, false)
        case .floating, .digging: return nil
        case .splatting: return (15, false)
        case .exiting: return (7, false)
        case .drowning: return (15, false)
        case .vaporizing: return (13, false)
        case .blocking: return (15, true)
        case .building: return (15, true)
        case .shrugging: return (7, false)
        case .bashing: return (31, true)
        case .mining: return (23, true)
        case .ohNo: return (15, false)
        case .exploding: return (51, false)
        }
    }

    private func advanceAnimation(_ lemming: inout ClassicDOSLemming) -> Bool {
        guard let animation = animationMaximum(for: lemming.action) else { return false }
        if lemming.animationFrame < animation.maximum {
            lemming.animationFrame += 1
            return false
        }
        if animation.loops { lemming.animationFrame = 0 }
        return true
    }

    private func frameTop(for action: ClassicDOSAction) -> Int {
        switch action {
        case .climbing, .hoisting, .digging: return -12
        case .floating: return -16
        case .exiting, .building, .mining: return -13
        case .vaporizing: return -14
        case .exploding: return -25
        default: return -10
        }
    }

    private mutating func checkLevelTop(
        _ lemming: inout ClassicDOSLemming,
        events: inout [ClassicDOSEvent]
    ) {
        let top = frameTop(for: lemming.action)
        if lemming.foot.y + top < -5 {
            lemming.foot.y = -7 - top
            turnAround(&lemming, events: &events)
            if lemming.action == .jumping {
                transition(&lemming, to: .walking, events: &events)
            }
        }
    }

    private func turnAround(
        _ lemming: inout ClassicDOSLemming,
        events: inout [ClassicDOSEvent]
    ) {
        lemming.direction.turnAround()
        events.append(.directionChanged(lemmingID: lemming.id, direction: lemming.direction))
    }

    private mutating func save(
        _ lemming: inout ClassicDOSLemming,
        events: inout [ClassicDOSEvent]
    ) {
        guard lemming.isActive else { return }
        clearBlockerField(&lemming)
        lemming.outcome = .saved
        savedCount += 1
        events.append(.saved(lemmingID: lemming.id))
    }

    private mutating func lose(
        _ lemming: inout ClassicDOSLemming,
        events: inout [ClassicDOSEvent]
    ) {
        guard lemming.isActive else { return }
        if lemming.foot.y > configuration.maximumY {
            events.append(.fellOut(lemmingID: lemming.id))
        }
        clearBlockerField(&lemming)
        lemming.outcome = .lost
        lostCount += 1
        events.append(.lost(lemmingID: lemming.id))
    }

    private func horizontalDelta(for lemming: ClassicDOSLemming) -> Int {
        lemming.hasZeroHorizontalVelocity ? 0 : lemming.direction.delta
    }

    private func clearBlockerField(_ lemming: inout ClassicDOSLemming) {
        lemming.ownsBlockerField = false
        lemming.blockerAnchor = nil
    }
}
