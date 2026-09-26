import Foundation

/// Experimental native L2 runtime. This is not the L1 simulation.
/// Terrain skill masks and action phases follow the original PROCESS overlay.
/// Other behaviour still requires original-engine trace testing.
public struct Lemmings2Runtime: Sendable {
    public enum Skill: Int, CaseIterable, Sendable {
        case unused = 0
        case digger = 17, climber = 18, builder = 19, basher = 20
        case miner = 21, floater = 22, bomber = 24, blocker = 51
        case stacker = 31, platformer = 34, stomper = 29
        case superlem = 37
        case archer = 5
        case skier = 30
        case poleVaulter = 32
        case magnoBooter = 25
        case thrower = 16, spearer = 27
        case magicCarpet = 14, surfer = 38
        case slider = 41
        case skater = 10
        case twister = 46
        case jetPack = 43, roller = 13, shimmier = 44, diver = 35, kayaker = 11
        case icarusWings = 49, hangGlider = 50
        case roper = 45, bazooka = 26, mortar = 33
        case rockClimber = 42, planter = 39, ballooner = 4, filler = 3, sandPourer = 47, gluePourer = 48
        case attractor = 6, parachuter = 40, swimmer = 12, blastBomber = 7, hopper = 9
        case jumper = 1, runner = 2, scooper = 8, fencer = 28, clubBasher = 15, laserBlaster = 23, flameThrower = 36
        public var name: String {
            switch self {
            case .unused: ""
            case .bomber: "Exploder"
            case .blastBomber: "Bomber"
            case .clubBasher: "Club Basher"
            case .laserBlaster: "Laser Blaster"
            case .flameThrower: "Flame Thrower"
            case .sandPourer: "Sand Pourer"
            case .gluePourer: "Glue Pourer"
            case .rockClimber: "Rock Climber"
            case .poleVaulter: "Pole Vaulter"
            case .magnoBooter: "Magno Booter"
            case .magicCarpet: "Magic Carpet"
            case .jetPack: "Jet Pack"
            case .icarusWings: "Icarus Wings"
            case .hangGlider: "Hang Glider"
            default: String(describing:self).capitalized
            }
        }
    }
    public enum State: String, Sendable {
        case walking, falling, floating, climbing, building, bashing, mining, digging, blocking
        case stacking, platforming, platformerShrugging, stomping
        case shrugging, exploding, exiting, saved, dead
        case teleporting, switchingValve, trapDying
        case cannonLoading, cannonFlying, catapultLoading
        case chainRiding
        case superFlying
        case arching
        case skiing, skiingAir
        case poleVaulting, poleShrugging
        case magnoBooting
        case throwing, spearing
        case carpetFlying, surfing
        case sliding, hanging, climbingTransfer
        case skating, slipping, iceRecovering, twisting
        case trapped, hopping, hopPreparing, blastBombing, swimming, leavingWater, parachuting, attracting, dancing, jetPacking, rolling, rollingAir, shimmyJump, shimming, diving, drowning, kayaking, kayakPacking, flyingIcarus, hangGliding, roping, firingBazooka, firingMortar, rockClimbing, hoisting, planting, ballooning, filling, sandPouring, gluePouring
        case jumping, tumbling, stunned, running, scooping, fencing, clubBashing, lasering, flaming
    }
    public struct Lemming: Equatable, Sendable {
        public let id: Int
        public var x: Int
        /// Foot position: the first solid pixel below a standing lemming.
        public var y: Int
        public var direction = 1
        public var state: State = .falling
        public var age = 0
        public var fallDistance = 0
        public var work = 0
        public var slider = false
        public var skater = false
        public var iceDirection = 1
        public var rockClimber = false
        public var pose = 0
        public var parachuter = false
        public var driftX = 0
        public var driftY = 0
        public var swimmer = false
        public var runner = false
        public var climber = false
        public var floater = false
        public var interactionID: Int?
        public var restoreMagno = false
        public var deathSprite = 126
        public var machineID: Int?
        public var chainID: Int?
        public var chainLink = 0
        public var superFlight: Lemmings2Superlem?
        public var ski: Lemmings2SkiPhysics?
        public var pole: [Lemmings2PoleVault.Point] = []
        public var poleX = 0
        public var poleY = 0
        public var poleContact: Int?
        public var magno: Lemmings2MagnoBoots?
        public var air: Lemmings2AirPhysics?
        public var bombTicks: Int?
        public var active: Bool { state != .dead && state != .saved }
        /// Held object placement from PROCESS 4093 and 4297, before release.
        public var heldProjectile: (kind:Lemmings2Projectile.Kind,x:Int,y:Int,frame:Int)? {
            guard state == .throwing || state == .spearing else { return nil }
            let spear = state == .spearing
            guard pose < (runner ? (spear ? 26 : 25) : 13) else { return nil }
            let px: Int, py: Int
            if runner {
                px = spear ? (direction > 0 ? 1 : -2) : (direction > 0 ? -1 : -4)
                py = -10
            } else {
                let path = [(-6,-4),(-6,-4),(-7,-4),(-7,-4),(-8,-4),(-8,-4),
                            (-9,-4),(-9,-4),(-9,-4),(-9,-4),(-9,-4),(-9,-5),(-9,-7)]
                let point = path[max(0,min(12,pose))]
                let offset = point.0 + (spear ? 4 : 2)
                px = direction > 0 ? offset : -offset-(spear ? 1 : 5)
                py = point.1-(spear ? 0 : 1)
            }
            return (spear ? .spear : .stone,x+px,y+py,spear ? (direction > 0 ? 15 : 1) : 0)
        }
    }
    public struct Rect: Equatable, Sendable {
        public let x: Int
        public let y: Int
        public let width: Int
        public let height: Int
        public init(x: Int, y: Int, width: Int, height: Int) {
            self.x = x; self.y = y; self.width = width; self.height = height
        }
        func contains(_ x: Int, _ y: Int) -> Bool {
            x >= self.x && y >= self.y && x - self.x < width && y - self.y < height
        }
    }
    public struct Configuration: Sendable {
        public let exitFrameCount: Int
        public let playBounds: Rect
        public let isPractice: Bool
        public let tribe: Int
        public let width: Int
        public let height: Int
        public let pixels: [UInt8]
        public let solid: [Bool]
        public let palette: [UInt8]
        public let entrances: [Rect]
        public let entrance: Rect
        public let exits: [Rect]
        public let skills: [Skill]
        public let supplies: [Int]
        public let total: Int
        public let timeLimit: Int
        public let releaseInterval: Int
        public let firstReleaseTick: Int
        public let levelFingerprint: String?
        public let steel: [Bool]
        public let hazards: [Rect]
        public let machines: [Lemmings2RailMachine]
        public let chains: [Lemmings2Chain]
        public let ice: [Rect]
        public let fireHazards: [Rect]
        public let interactiveObjects: [Lemmings2InteractiveObject]
        public let terrainMasks: Lemmings2TerrainMasks
        public init(width: Int, height: Int, pixels: [UInt8], solid: [Bool], palette: [UInt8],
                    entrance: Rect, exits: [Rect], skills: [Skill], supplies: [Int], total: Int,
                    timeLimit: Int, releaseInterval: Int, terrainMasks: Lemmings2TerrainMasks, firstReleaseTick: Int = 35,
                    steel: [Bool] = [], hazards: [Rect] = [], levelFingerprint: String? = nil,
                    fireHazards: [Rect] = [], interactiveObjects: [Lemmings2InteractiveObject] = [], entrances: [Rect] = [], tribe: Int = 0, ice: [Rect] = [], chains: [Lemmings2Chain] = [], machines: [Lemmings2RailMachine] = [], isPractice: Bool = false, playBounds: Rect? = nil, exitFrameCount: Int = 8) {
            self.exitFrameCount = exitFrameCount
            self.playBounds = playBounds ?? Rect(x:0,y:-16,width:width,height:height+16)
            self.isPractice = isPractice
            self.tribe = tribe
            self.width = width; self.height = height; self.pixels = pixels; self.solid = solid
            self.palette = palette; self.entrance = entrance
            self.entrances = entrances.isEmpty ? [entrance] : entrances; self.exits = exits
            self.skills = skills; self.supplies = supplies; self.total = total
            self.timeLimit = timeLimit; self.releaseInterval = releaseInterval
            self.firstReleaseTick = firstReleaseTick
            self.levelFingerprint = levelFingerprint
            self.steel = steel.isEmpty ? [Bool](repeating: false, count: pixels.count) : steel
            self.hazards = hazards
            self.machines = machines
            self.chains = chains
            self.ice = ice
            self.fireHazards = fireHazards
            self.interactiveObjects = interactiveObjects
            self.terrainMasks = terrainMasks
        }
    }
    public let configuration: Configuration
    public private(set) var pixels: [UInt8]
    public private(set) var solid: [Bool]
    public private(set) var terrainRevision = 0
    public private(set) var supplies: [Int]
    public private(set) var lemmings: [Lemming] = []
    public private(set) var tick = 0
    public private(set) var released = 0
    public private(set) var isComplete = false
    public private(set) var isNuking = false
    public private(set) var objectFrames: [Int: Int] = [:]
    private var activeObjects: Set<Int> = []
    private var fanPoint: (x: Int, y: Int)?
    private var fanTicks = 0
    private var randomSeed: UInt16 = 23247
    private struct FillStream: Sendable {
        let owner: Int
        let kind: Lemmings2FillParticle.Kind
        var particles: [Lemmings2FillParticle] = []
        var finished = false
    }
    public private(set) var timedTraps: [Int:Lemmings2TimedTrap] = [:]
    private var busyValves: Set<Int> = []
    public private(set) var machines: [Lemmings2RailMachine] = []
    public private(set) var chains: [Lemmings2Chain] = []
    public private(set) var rope: Lemmings2Rope?
    private var aimPoint: (x:Int,y:Int,held:Bool) = (0,0,false)
    public mutating func setAim(x:Int,y:Int,held:Bool) { aimPoint = (x,y,held) }
    public mutating func releasePointerInput() {
        aimPoint.held = false; fanPoint = nil; fanTicks = 0
    }
    public private(set) var projectiles: [Lemmings2Projectile] = []
    private var fillStreams: [FillStream] = []
    public var fillParticles: [Lemmings2FillParticle] { fillStreams.flatMap(\.particles).filter { $0.direction != 0 } }
    public mutating func setFan(x: Int, y: Int, active: Bool) {
        fanPoint = active ? (x, y) : nil
        if !active { fanTicks = 0 }
    }
    public private(set) var blastFlashes: [(x:Int,y:Int)] = []
    private var nextToNuke = 0
    private var soundEvents: [Lemmings2SoundRequest] = []
    public mutating func drainSoundEvents() -> [Lemmings2SoundRequest] {
        let events = soundEvents; soundEvents.removeAll(keepingCapacity: true); return events
    }
    private mutating func sound(_ cue: Lemmings2SoundCue) { sound(Lemmings2SoundRequest(cue)) }
    private mutating func sound(_ request: Lemmings2SoundRequest) {
        // Headless runs need not consume audio. Bound their pending queue.
        if soundEvents.count < 256 { soundEvents.append(request) }
    }
    public var saved: Int { lemmings.filter { $0.state == .saved }.count }
    public var lost: Int { lemmings.filter { $0.state == .dead }.count }
    // L2.RKO 034b and 0694: the displayed second is fifteen simulation ticks,
    // even though the engine runs at 17.5 ticks per real second.
    public var remainingSeconds: Int { max(0, configuration.timeLimit - tick / 15) }
    public var didWin: Bool { isComplete && saved > 0 }
    public static let ticksPerSecond = 17.5

    public init(configuration c: Configuration) throws {
        guard (0..<12).contains(c.tribe), c.width > 0, c.height > 0, c.width <= 4096, c.height <= 4096,
              c.width * c.height <= 4_194_304, c.pixels.count == c.width * c.height,
              c.solid.count == c.pixels.count, c.steel.count == c.pixels.count, c.palette.count == 1024,
              c.exitFrameCount > 0, c.exitFrameCount <= 256,
              c.playBounds.width > 0, c.playBounds.height > 0,
              c.skills.count == c.supplies.count, c.supplies.allSatisfy({ $0 >= 0 }),
              c.total > 0, c.total <= 1000, c.timeLimit > 0, c.timeLimit <= 3600,
              c.releaseInterval > 0, c.releaseInterval <= 1000,
              c.firstReleaseTick > 0, c.firstReleaseTick <= 2000,
              c.entrance.x >= 0, c.entrance.x < c.width, c.entrance.y >= 0, c.entrance.y < c.height,
              (!c.exits.isEmpty || c.isPractice) else {
            throw SequelDataError.invalid("Invalid native L2 runtime configuration.")
        }
        guard !c.skills.contains(.archer) || c.terrainMasks.arrow.count == 32,
              !c.skills.contains(.thrower) || c.terrainMasks.stone.count == 4,
              !c.skills.contains(.spearer) || c.terrainMasks.spear.count == 16 else {
            throw SequelDataError.invalid("Missing native L2 thrown-object graphics.")
        }
        guard !c.skills.contains(.twister) || c.terrainMasks.twister != nil else {
            throw SequelDataError.invalid("Missing native L2 Twister mask.")
        }
        guard !c.skills.contains(.planter) || c.terrainMasks.plant.count == 8 else {
            throw SequelDataError.invalid("The Planter terrain frames are required.")
        }
        guard !c.skills.contains(where: { [.blastBomber, .bazooka, .mortar].contains($0) }) || c.terrainMasks.blast != nil else {
            throw SequelDataError.invalid("The Bomber terrain mask is required.")
        }
        guard !c.skills.contains(.stomper) || c.terrainMasks.stomper != nil else {
            throw SequelDataError.invalid("The Stomper terrain mask is required.")
        }
        guard !c.skills.contains(.scooper) || c.terrainMasks.scooper.count == 12,
              !c.skills.contains(.fencer) || c.terrainMasks.fencer.count == 2,
              !c.skills.contains(.clubBasher) || c.terrainMasks.clubBasher.count == 14,
              !c.skills.contains(.laserBlaster) || c.terrainMasks.laser.count == 1,
              !c.skills.contains(.flameThrower) || c.terrainMasks.flame.count == 2 else {
            throw SequelDataError.invalid("Native terrain masks are required for the selected tribe skills.")
        }
        guard c.entrances.count <= 8, c.entrances.allSatisfy({
            $0.x >= 0 && $0.x < c.width && $0.y >= 0 && $0.y < c.height
        }) else { throw SequelDataError.invalid("Invalid L2 entrance positions.") }
        guard Set(c.interactiveObjects.map(\.id)).count == c.interactiveObjects.count,
              c.interactiveObjects.allSatisfy({ $0.frameCount <= 1024 }) else {
            throw SequelDataError.invalid("Invalid L2 interactive object configuration.")
        }
        machines = c.machines
        chains = c.chains
        for object in c.interactiveObjects where object.kind == .timedTrap { timedTraps[object.id] = .init() }
        guard c.interactiveObjects.filter({$0.kind == .teleporter || $0.kind == .valve}).allSatisfy({ object in
            c.interactiveObjects.contains { $0.id == object.linkedID && $0.kind == (object.kind == .valve ? .launcher : .teleporter) }
        }) else { throw SequelDataError.invalid("An L2 valve or teleporter has no matching object.") }
        activeObjects = Set(c.interactiveObjects.filter(\.initiallyActive).map(\.id))
        configuration = c; pixels = c.pixels; solid = c.solid; supplies = c.supplies
    }

    /// Native campaign loader for the twelve tribes.
    public init(level: Lemmings2Level, style: Lemmings2Style, masks: Lemmings2TerrainMasks, total: Int = 60, allowExperimentalTribes: Bool = true, practiceSkills: [Skill]? = nil) throws {
        guard level.style == 0 || allowExperimentalTribes else { throw SequelDataError.invalid("This caller has restricted native play to the Classic tribe.") }
        let terrain = try Lemmings2Terrain(level: level, style: style)
        let objects = try Lemmings2Objects(level: level, style: style)
        var pixels = terrain.image.pixels, solid = terrain.solid
        var steel = [Bool](repeating: false, count: pixels.count)
        var entrances: [Rect] = []
        let entranceOffsets = [(22,8),(20,8),(22,10),(22,9),(22,8),(16,22),(22,29),(22,8),(22,8),(22,8),(22,10),(22,9)]
        let openingFrames = [10,8,9,9,9,8,9,8,10,9,9,9]
        guard entranceOffsets.indices.contains(level.style) else { throw SequelDataError.invalid("Unknown L2 tribe.") }
        let exits = objects.parts.filter { $0.type == 3 }.compactMap(\.trigger)
        guard exits.allSatisfy({ $0.x >= 0 && $0.y >= 0 && $0.x < terrain.image.width && $0.y < terrain.image.height }) else {
            throw SequelDataError.invalid("This level has an exit outside the decoded terrain. Its lower map boundary is not resolved yet.")
        }
        let hazards = objects.parts.filter { $0.type == 6 || $0.type == 11 }.compactMap(\.trigger)
        for placed in level.objects where placed.identifier != 65535 {
            guard style.objects.indices.contains(placed.identifier) else {
                throw SequelDataError.invalid("Unknown native L2 object.")
            }
            let object = style.objects[placed.identifier]
            switch object.type {
            case 2:
                let offset = entranceOffsets[level.style]
                entrances.append(Rect(x: placed.x - 16 + offset.0, y: placed.y - 16 + offset.1, width: 1, height: 1))
            case 0, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14: break
            default:
                throw SequelDataError.invalid("Object type \(object.type) is not yet supported by the native preview.")
            }
        }
        // L2.RKO 18e8–19ad replaces map tiles with ordinary object graphics.
        // Non-solid artwork clears its entire tile area, including buried exits.
        // Special sprites (0x20) remain overlays and do not replace the map.
        for part in objects.parts where part.component.graphicsFlags & 0xa0 == 0 {
            guard let frame = part.frames.first else { continue }
            for y in 0..<frame.height { for x in 0..<frame.width {
                let px = part.x + frame.x + x, py = part.y + frame.y + y
                guard px >= 0, py >= 0, px < terrain.image.width, py < terrain.image.height else { continue }
                let colour = frame.pixels[y * frame.width + x]
                let index = py * terrain.image.width + px
                let collidable = part.component.solidity & 0x40 == 0
                pixels[index] = collidable ? colour : 0
                solid[index] = collidable && colour != 0
                steel[index] = solid[index] && part.component.solidity & 0x10 != 0
            } }
        }
        var chains: [Lemmings2Chain] = []
        for id in Set(objects.parts.filter{$0.type == 0}.map(\.objectIndex)).sorted() {
            let parts = objects.parts.filter{$0.objectIndex == id}
            let links = parts.filter{$0.component.graphicsFlags & 0xe0 == 0xe0 && $0.component.graphics == 5}
            guard let first = links.first, chains.count < 5 else { throw SequelDataError.invalid("Invalid native L2 chain.") }
            let controls = parts.filter{$0.component.interaction == 14}.map {
                Rect(x:$0.x,y:$0.y,width:$0.frames.first?.width ?? 16,height:$0.frames.first?.height ?? 8)
            }
            chains.append(.init(id:id,x:first.x,y:first.y-12,count:links.count,controls:controls))
        }
        guard let entrance = entrances.first else { throw SequelDataError.invalid("No entrance in the native L2 level.") }
        let skills = try practiceSkills ?? level.skills.map { slot -> Skill in
            if slot.count == 0 { return .unused }
            guard let skill = Skill(rawValue: slot.identifier) else {
                throw SequelDataError.invalid("Skill \(slot.identifier) is not yet supported by the native preview.")
            }
            return skill
        }
        // L2.RKO 14eb and PROCESS 0190: subtract the native setting from 21,
        // then count down to zero. Classic opens after a 20-tick delay and
        // ten entrance frames (PROCESS 023b).
        let releaseInterval = 21 - level.releaseRate
        guard releaseInterval > 0, releaseInterval <= 1000 else {
            throw SequelDataError.invalid("Invalid native L2 release rate.")
        }
        try self.init(configuration: Configuration(width: terrain.image.width, height: terrain.image.height,
            pixels: pixels, solid: solid, palette: style.palette, entrance: entrance,
            exits: exits, skills: skills, supplies: practiceSkills == nil ? level.skills.map(\.count) : Array(repeating:99,count:skills.count), total: total,
            timeLimit: level.timeLimitSeconds, releaseInterval: releaseInterval,
            terrainMasks: masks, firstReleaseTick: 20 + openingFrames[level.style] + releaseInterval, steel: steel, hazards: hazards,
            levelFingerprint: practiceSkills == nil ? level.fingerprint : nil,
            fireHazards: objects.parts.filter { $0.type == 11 }.compactMap(\.trigger),
            interactiveObjects: Lemmings2InteractiveObject.resolve(level: level, style: style, parts: objects), entrances: entrances, tribe: level.style, ice: objects.parts.filter { $0.type == 8 }.compactMap(\.trigger), chains:chains, machines:try Lemmings2RailMachine.resolve(parts:objects), isPractice:practiceSkills != nil,
            // PROCESS 0000/03ef: authored screen limits include the lower eight-pixel margin.
            playBounds:Rect(x:level.minimumScreenX+1,y:level.minimumScreenY+1,
                width:level.maximumScreenX+319-level.minimumScreenX,
                height:level.maximumScreenY+168-level.minimumScreenY),
            exitFrameCount:[8,12,32,21,14,28,30,14,23,23,27,11][level.style]))
    }

    public func isSolid(_ x: Int, _ y: Int) -> Bool {
        x >= 0 && x < configuration.width && y >= 0 && y < configuration.height && solid[y * configuration.width + x]
    }
    private func isWater(_ x: Int, _ y: Int) -> Bool {
        configuration.hazards.contains { $0.contains(x, y) }
            && !configuration.fireHazards.contains { $0.contains(x, y) }
    }
    private mutating func enterHazard(_ lem: inout Lemming) -> Bool {
        guard configuration.hazards.contains(where: { $0.contains(lem.x, lem.y) }), ![.exiting,.teleporting,.trapDying,.cannonLoading,.catapultLoading].contains(lem.state) else { return false }
        if isWater(lem.x, lem.y) && [.surfing, .kayaking, .kayakPacking].contains(lem.state) { return false }
        if isWater(lem.x, lem.y) && lem.swimmer {
            if ![.swimming, .leavingWater].contains(lem.state) {
                lem.y &= ~7; lem.air = nil; change(&lem, .swimming)
            }
            return false
        }
        if isWater(lem.x,lem.y) {
            if lem.state != .drowning { change(&lem, .drowning); lem.y &= ~7; sound(.drown) }
            return false
        }
        change(&lem, .dead)
        return true
    }
    private func touchesSteel(_ x: Int, _ y: Int, width: Int, height: Int) -> Bool {
        let left = max(0, min(configuration.width, x)), top = max(0, min(configuration.height, y))
        for py in top..<max(top, min(configuration.height, y + height)) {
            for px in left..<max(left, min(configuration.width, x + width)) {
                if configuration.steel[py * configuration.width + px] { return true }
            }
        }
        return false
    }
    /// Draw or erase only opaque mask pixels, preserving steel and background.
    private mutating func apply(_ frame: Lemmings2SpriteFrame, x: Int, y: Int, adding: Bool = false) {
        var changed = false
        for row in 0..<frame.height { for column in 0..<frame.width {
            let source = row * frame.width + column
            guard frame.opaque[source] else { continue }
            let px = x + frame.x + column, py = y + frame.y + row
            guard px >= 0, py >= 0, px < configuration.width, py < configuration.height else { continue }
            let destination = py * configuration.width + px
            guard !configuration.steel[destination] else { continue }
            if adding {
                changed = changed || pixels[destination] != frame.pixels[source] || !solid[destination]
                pixels[destination] = frame.pixels[source]; solid[destination] = true
            } else if solid[destination] {
                changed = true
                pixels[destination] = 0; solid[destination] = false
            }
        } }
        if changed { terrainRevision += 1 }
    }
    private func steelProbe(_ lem: Lemming, _ offsets: [(Int, Int)]) -> Bool {
        offsets.contains { dx, dy in
            touchesSteel(lem.x + dx * lem.direction, lem.y - 1 + dy, width: 1, height: 1)
        }
    }
    private func change(_ lemming: inout Lemming, _ state: State) {
        lemming.state = state == .walking && lemming.runner ? .running : state; lemming.age = 0; lemming.work = 0
    }
    public func canAssign(slot: Int, to id: Int) -> Bool {
        guard !isComplete, !isNuking, supplies.indices.contains(slot), supplies[slot] > 0,
              let lem = lemmings.first(where: { $0.id == id && $0.active }),
              ![.exiting,.exploding,.trapped,.cannonLoading,.catapultLoading,.teleporting,.switchingValve,.trapDying].contains(lem.state) else { return false }
        let skill = configuration.skills[slot]
        guard Lemmings2SkillRules.permits(skill,during:lem.state) else { return false }
        if lem.state == .magnoBooting && lem.pose > 7 && skill != .bomber { return false }
        if [.thrower,.spearer,.bazooka,.mortar].contains(configuration.skills[slot]),
           projectiles.count + lemmings.filter({ [.throwing,.spearing,.firingBazooka,.firingMortar].contains($0.state) }).count >= 10 { return false }
        if configuration.skills[slot] == .laserBlaster && lemmings.contains(where: { $0.state == .lasering }) { return false }
        if configuration.skills[slot] == .superlem && lemmings.contains(where:{$0.state == .superFlying}) { return false }
        if configuration.skills[slot] == .archer && lemmings.contains(where:{$0.state == .arching}) { return false }
        if configuration.skills[slot] == .roper && (rope != nil || lemmings.contains { $0.state == .roping }) { return false }
        if [.filler, .sandPourer, .gluePourer].contains(configuration.skills[slot]), fillStreams.count >= 4 { return false }
        switch configuration.skills[slot] {
        case .unused: return false
        case .surfer: return isWater(lem.x,lem.y) && lem.state != .surfing
        case .kayaker: return isWater(lem.x,lem.y) && ![.kayaking,.kayakPacking].contains(lem.state)
        case .slider: return !lem.slider
        case .skater: return !lem.skater
        case .rockClimber: return !lem.rockClimber
        case .parachuter: return !lem.parachuter
        case .swimmer: return !lem.swimmer
        case .runner: return !lem.runner
        case .climber: return !lem.climber
        case .floater: return !lem.floater
        case .bomber: return lem.bombTicks == nil
        case .shimmier where lem.state == .hanging: return true
        case .shimmier:
            return !(1...11).contains(where: { isSolid(lem.x, lem.y - $0) })
        case .jumper, .hopper:
            return !(1...10).contains(where: { isSolid(lem.x, lem.y - $0) })
        default: return true
        }
    }
    /// Hover and input share skill priorities without changing assignment rules.
    public func target(slot: Int, x: Int, y: Int, preferApproaching: Bool = false,
                       preferBombBlockers: Bool = false, preferBuilders: Bool = false) -> Lemming? {
        let candidates = lemmings.filter { $0.active && $0.state != .exiting && $0.state != .exploding &&
            abs($0.x - x) <= 9 && abs($0.y - 5 - y) <= 12 }
        func distance(_ lem: Lemming) -> Int { abs(lem.x - x) + abs(lem.y - 5 - y) }
        func nearer(_ a: Lemming, _ b: Lemming) -> Bool {
            let da = distance(a), db = distance(b)
            return da == db ? a.id < b.id : da < db
        }
        if configuration.skills.indices.contains(slot) {
            let skill = configuration.skills[slot]
            if preferBombBlockers, [.bomber, .blastBomber].contains(skill),
               let blocker = candidates.filter({ $0.state == .blocking && canAssign(slot: slot, to: $0.id) }).min(by: nearer) {
                return blocker
            }
            if preferBuilders, skill == .builder, !isComplete, !isNuking, supplies[slot] > 0,
               let builder = candidates.filter({ [.building, .shrugging].contains($0.state) && canAssign(slot: slot, to: $0.id) }).min(by: nearer) {
                return builder
            }
        }
        guard let nearest = candidates.min(by: { a, b in
            let eligibleA = canAssign(slot: slot, to: a.id), eligibleB = canAssign(slot: slot, to: b.id)
            if eligibleA != eligibleB { return eligibleA }
            let da = distance(a), db = distance(b)
            return da == db ? a.id < b.id : da < db
        }) else { return nil }
        if preferApproaching, nearest.state == .building,
            let follower = candidates.filter({ canAssign(slot: slot, to: $0.id) && isApproaching($0, clickX: x) && isBehind($0, builder: nearest) })
                .min(by: { a, b in
                    let da = distance(a), db = distance(b)
                    return da == db ? a.id < b.id : da < db
                }) {
            return follower
        }
        guard preferApproaching, canAssign(slot: slot, to: nearest.id),
            (x - nearest.x) * nearest.direction < 0 else { return nearest }
        let approaching = candidates.filter {
            canAssign(slot: slot, to: $0.id) && isApproaching($0, clickX: x) && $0.direction != nearest.direction
        }.min { a, b in
            let da = distance(a), db = distance(b)
            return da == db ? a.id < b.id : da < db
        }
        return approaching ?? nearest
    }

    private func isApproaching(_ lemming: Lemming, clickX: Int) -> Bool {
        (clickX - lemming.x) * lemming.direction >= 0
    }

    private func isBehind(_ lemming: Lemming, builder: Lemming) -> Bool {
        lemming.direction == builder.direction &&
            (builder.direction > 0 ? lemming.x < builder.x : lemming.x > builder.x)
    }
    @discardableResult public mutating func assign(slot: Int, to id: Int) -> Bool {
        guard canAssign(slot: slot, to: id), let index = lemmings.firstIndex(where: { $0.id == id }) else { return false }
        var lem = lemmings[index]
        switch configuration.skills[slot] {
        case .surfer:
            lem.y &= ~7; change(&lem, .surfing); lem.work = 45; lem.pose = 0; lem.driftX = 0; lem.driftY = 0
        case .kayaker:
            lem.y &= ~7; change(&lem, .kayaking)
        case .slider:
            lem.slider = true
        case .skater:
            lem.skater = true
        case .rockClimber:
            lem.rockClimber = true
        case .parachuter:
            lem.parachuter = true
        case .swimmer:
            lem.swimmer = true
            if isWater(lem.x, lem.y) { lem.y &= ~7; change(&lem, .swimming) }
        case .runner:
            lem.runner = true
            if lem.state == .walking { change(&lem, .running) }
        case .climber:
            guard !lem.climber else { return false }; lem.climber = true
        case .floater:
            guard !lem.floater else { return false }; lem.floater = true
        case .diver:
            lem.x += 3*lem.direction; change(&lem, .diving)
            lem.air = try? Lemmings2AirPhysics(x:Int16(lem.x),y:Int16(lem.y),
                velocityX:Int16((lem.runner ? 3 : 2)*lem.direction),velocityY:lem.runner ? -3 : -2,
                horizontalCountdown:7,verticalCountdown:lem.runner ? 1 : 0)
        case .hopper:
            change(&lem, .hopping)
            if isSolid(lem.x + lem.direction, lem.y) { lem.x -= lem.direction }
            lem.air = try? Lemmings2AirPhysics(x: Int16(lem.x), y: Int16(lem.y),
                velocityX: Int16(2 * lem.direction), velocityY: -3, horizontalCountdown: 7, verticalCountdown: 1)
        case .jumper, .shimmier:
            let shimmier = configuration.skills[slot] == .shimmier
            if shimmier && lem.state == .hanging {
                lem.direction = -lem.direction; change(&lem,.shimming); lem.age = 15; lem.air = nil
                supplies[slot] -= 1; lemmings[index] = lem; sound(.assignSkill); return true
            }
            let stacked = lem.state == .stacking
            change(&lem, shimmier ? .shimmyJump : .jumping)
            lem.y -= stacked ? 2 : 1
            lem.air = try? Lemmings2AirPhysics(x: Int16(lem.x), y: Int16(lem.y),
                velocityX: Int16((lem.runner ? 4 : 3) * lem.direction), velocityY: lem.runner ? -4 : -3,
                horizontalCountdown: 7, verticalCountdown: 1)
        case .bomber:
            guard lem.bombTicks == nil else { return false }; lem.bombTicks = 75
        default:
            let state: State
            switch configuration.skills[slot] {
            case .superlem: state = .superFlying
            case .archer: state = .arching
            case .skier: state = .skiing
            case .poleVaulter: state = .poleVaulting
            case .magnoBooter: state = .magnoBooting
            case .thrower: state = .throwing
            case .spearer: state = .spearing
            case .magicCarpet: state = .carpetFlying
            case .twister: state = .twisting
            case .jetPack: state = .jetPacking
            case .roller: state = .rolling
            case .icarusWings: state = .flyingIcarus
            case .hangGlider: state = .hangGliding
            case .roper: state = .roping
            case .bazooka: state = .firingBazooka
            case .mortar: state = .firingMortar
            case .planter: state = .planting
            case .ballooner: state = .ballooning
            case .filler: state = .filling
            case .sandPourer: state = .sandPouring
            case .gluePourer: state = .gluePouring
            case .attractor: state = .attracting
            case .blastBomber: state = .blastBombing
            case .builder: state = .building
            case .basher: state = .bashing
            case .miner: state = .mining
            case .digger: state = .digging
            case .blocker: state = .blocking
            case .stacker: state = .stacking
            case .platformer: state = .platforming
            case .stomper: state = .stomping
            case .scooper: state = .scooping
            case .fencer: state = .fencing
            case .clubBasher: state = .clubBashing
            case .laserBlaster: state = .lasering
            case .flameThrower: state = .flaming
            default: return false
            }
            guard lem.state != state else { return false }
            let previous = lem.state
            change(&lem, state)
            if state == .fencing { lem.age = 7 }
            if state == .lasering { lem.work = -1 }
            if state == .stacking {
                lem.work = 12
                // The stacker alternates facing within one 32-frame bank.
                if lem.direction < 0 { lem.age = 16 }
            } else if state == .platforming {
                lem.work = previous == .platformerShrugging ? 12 : 11
                if previous == .platformerShrugging { lem.age = 21 }
            }
        }
        if lem.state == .superFlying { lem.superFlight = .init(x:lem.x,y:lem.y) }
        if lem.state == .arching { lem.pose = 0; lem.work = 6; lem.driftX = 0; lem.driftY = 10 }
        if lem.state == .skiing { lem.ski = .init(direction:lem.direction); lem.pose = 3 }
        if lem.state == .magnoBooting { lem.magno = .init(x:lem.x,y:lem.y) }
        if [.throwing,.spearing].contains(lem.state) { lem.pose = lem.runner ? 20 : 0; lem.work = 3 }
        if lem.state == .carpetFlying { lem.driftX = 0; lem.driftY = 0 }
        if lem.state == .twisting { lem.driftX = 0; lem.driftY = 0 }
        if lem.state == .jetPacking { lem.driftX = 0; lem.driftY = 0; lem.pose = 4 }
        if lem.state == .rolling { lem.ski = .init(direction:lem.direction,mode:.roller); lem.pose = 0 }
        if lem.state == .flyingIcarus { lem.driftX = 0; lem.driftY = 0 }
        if lem.state == .hangGliding { lem.driftX = 256*lem.direction; lem.driftY = -1500 }
        if lem.state == .roping { lem.pose = 0; lem.work = 6 }
        if lem.state == .ballooning { lem.driftX = 0; lem.driftY = 0 }
        if [.filling, .sandPouring, .gluePouring].contains(lem.state) {
            for stream in fillStreams.indices where fillStreams[stream].owner == lem.id { fillStreams[stream].finished = true }
            fillStreams.append(.init(owner:lem.id,kind:lem.state == .filling ? .filler : lem.state == .sandPouring ? .sand : .glue))
        }
        supplies[slot] -= 1; lemmings[index] = lem
        sound(.assignment(skill:configuration.skills[slot],tribe:configuration.tribe))
        return true
    }
    private func advanceWalker(_ lem: inout Lemming) {
                let nx = lem.x + lem.direction
                if lemmings.contains(where: { $0.id != lem.id && $0.state == .blocking &&
                    abs($0.y - lem.y) <= 4 && abs($0.x - nx) <= 6 && ($0.x - lem.x) * lem.direction > 0 }) {
                    lem.direction = -lem.direction
                } else if isSolid(nx, lem.y - 1) {
                    if let rise = (1...4).first(where: { !isSolid(nx, lem.y - $0 - 1) && isSolid(nx, lem.y - $0) }) {
                        lem.x = nx; lem.y -= rise
                    } else if lem.rockClimber { lem.x = nx; lem.pose = 0; change(&lem, .rockClimbing) }
                    else if lem.climber { lem.x = nx; change(&lem, .climbing) }
                    else { lem.direction = -lem.direction }
                } else {
                    lem.x = nx
                    if let drop = (0...3).first(where: { isSolid(nx, lem.y + $0) }) { lem.y += drop }
                    else if lem.slider { change(&lem, .sliding) }
                    else if lem.runner {
                        // PROCESS 50c4–50f8: a runner launches forward at a ledge.
                        change(&lem, .jumping); lem.age = 4
                        lem.x += lem.direction
                        lem.air = try? Lemmings2AirPhysics(x: Int16(lem.x), y: Int16(lem.y),
                            velocityX: Int16(2 * lem.direction), velocityY: 0,
                            horizontalCountdown: 7, verticalCountdown: 0)
                    } else { lem.y += 3; change(&lem, .falling); lem.fallDistance = 0 }
                }
    }

    private mutating func advanceAirborne(_ lem: inout Lemming) {
        guard var air = lem.air else { change(&lem, .falling); return }
        let skiing = lem.state == .skiingAir
        let rolling = lem.state == .rollingAir || skiing
        let diving = lem.state == .diving
        let hopping = lem.state == .hopping
        let shimmy = lem.state == .shimmyJump
        let jumping = lem.state == .jumping || hopping || shimmy
        let oldX = lem.x, oldY = lem.y
        air.step()
        let targetY = Int(air.y)
        let hit = Lemmings2AirCollision.sweep(x: oldX, y: oldY - (jumping ? 1 : 0),
            toX: Int(air.x), toY: targetY, height:diving ? 0 : 9, solid: isSolid)
        lem.x = hit.x; lem.y = hit.y
        lem.fallDistance = max(0, Int(air.fallDistance) - max(0, targetY - hit.y))
        switch hit.contact {
        case .clear:
            if jumping && !hopping && lem.fallDistance > 39 { change(&lem, .tumbling) }
            if !jumping && !diving && !rolling && air.velocityY >= 0 && abs(Int(air.velocityX)) < 2 && lem.floater {
                change(&lem, .floating)
            }
        case .head:
            if shimmy {
                lem.x = hit.x; lem.y = hit.y
                if isSolid(lem.x,lem.y-9) { lem.y += 1 }
                change(&lem, .shimming); lem.age = 15; lem.air = nil; return
            }
            lem.x = hit.previousX; lem.y = hit.previousY
            if jumping { change(&lem, .tumbling) }
            air.resolve(x: lem.x, y: lem.y, velocityX: 0, velocityY: 0)
        case .body:
            var landed = false
            if !isSolid(hit.x, hit.y - 1) { landed = true }
            else if !isSolid(hit.x, hit.y - 2) { lem.y -= 1; landed = true }
            else if isSolid(hit.x - lem.direction, hit.y - 1) {
                lem.x = hit.previousX; lem.y = hit.previousY; landed = true
            } else if isSolid(hit.x - lem.direction, hit.y) {
                lem.x -= lem.direction; landed = true
            }
            if landed {
                if lem.fallDistance > 99 { sound(.splat); change(&lem, .dead) }
                else if hopping { change(&lem, .hopPreparing) }
                else if skiing { change(&lem, .skiing); lem.ski = .init(direction:lem.direction,landingVelocity:Int(air.velocityX)*16) }
                else if rolling { change(&lem, .rolling); lem.ski = .init(direction:lem.direction,landingVelocity:Int(air.velocityX)*16,mode:.roller) }
                else if !jumping || lem.fallDistance > 64 { change(&lem, .stunned) }
                else { change(&lem, .walking) }
            } else {
                lem.x -= lem.direction
                lem.direction = -lem.direction
                if diving { change(&lem, .tumbling) }
                let divisor = jumping && !hopping ? 2 : 4
                let vx = abs(Int(air.velocityX)) / divisor * lem.direction
                air.resolve(x: lem.x, y: lem.y, velocityX: vx,
                            velocityY: jumping && !hopping ? nil : Int(air.velocityY) >> 1)
            }
        }
        air.resolve(x: lem.x, y: lem.y, fallDistance: lem.fallDistance)
        lem.air = [.jumping, .tumbling, .hopping, .diving, .shimmyJump, .rollingAir, .skiingAir, .cannonFlying].contains(lem.state) ? air : nil
    }

    private func beginHanging(_ lem: inout Lemming) {
        if isSolid(lem.x,lem.y) || isSolid(lem.x,lem.y+1) {
            if isSolid(lem.x,lem.y) { lem.y -= 1 }
            lem.direction = -lem.direction; change(&lem, .walking)
        } else { change(&lem, .hanging); lem.work = 2 }
    }

    private func advanceShimmy(_ lem: inout Lemming) {
        var phase = lem.age
        let contact = Lemmings2Shimmy.step(x:&lem.x,y:&lem.y,direction:&lem.direction,
            phase:&phase,rise:&lem.work,slider:lem.slider,climber:lem.climber || lem.rockClimber,solid:isSolid)
        switch contact {
        case .shimming: lem.age = phase-1
        case .walking: change(&lem,.walking)
        case .hanging: beginHanging(&lem)
        case .sliding: change(&lem,.sliding); lem.age = 9; lem.pose = 9
        case .climbingTransfer: change(&lem,.climbingTransfer)
        }
    }

    @discardableResult public mutating func releaseChain(x:Int,y:Int) -> Bool {
        guard !isComplete, let chain = chains.first(where:{$0.controls.contains(where:{$0.contains(x,y)})}) else { return false }
        for index in lemmings.indices where lemmings[index].state == .chainRiding && lemmings[index].chainID == chain.id {
            var lem = lemmings[index]
            guard chain.links.indices.contains(lem.chainLink) else { continue }
            let link = chain.links[lem.chainLink]
            change(&lem, .tumbling); lem.chainID = nil
            lem.air = try? Lemmings2AirPhysics(x:Int16(lem.x),y:Int16(lem.y),
                velocityX:Int16(link.velocityX),velocityY:Int16(link.velocityY),horizontalCountdown:7,verticalCountdown:0)
            lemmings[index] = lem
        }
        return true
    }

    private mutating func advanceRope() {
        guard var rope else { return }
        rope.step(solid:isSolid)
        if rope.finished {
            if rope.anchored {
                if let anchor = rope.anchor, configuration.terrainMasks.ropeHook.indices.contains(rope.frame) {
                    apply(configuration.terrainMasks.ropeHook[rope.frame],x:anchor.x-7,y:anchor.y-7,adding:true)
                }
                for p in rope.points where p.x >= 0 && p.y >= 0 && p.x < configuration.width && p.y < configuration.height {
                    let index = p.y*configuration.width+p.x
                    if !configuration.steel[index] { pixels[index] = 4; solid[index] = true; terrainRevision += 1 }
                }
            }
            self.rope = nil
        } else { self.rope = rope }
    }

    private mutating func advanceProjectiles() {
        var remaining: [Lemmings2Projectile] = []
        for var shot in projectiles {
            let x = shot.tip.x, y = shot.tip.y
            shot.step()
            guard shot.x >= -8, shot.x < configuration.width+8, shot.y < configuration.height+8 else { continue }
            if isWater(shot.x,shot.y) { continue }
            let hit = Lemmings2AirCollision.sweep(x:x,y:y,toX:shot.tip.x,toY:shot.tip.y,height:0,solid:{ px,py in
                if shot.kind == .stone { return (-2...2).contains { dy in (-2...2).contains { dx in self.isSolid(px+dx,py+dy) } } }
                return self.isSolid(px,py)
            })
            if hit.contact != .clear {
                if shot.kind == .stone {
                    apply(configuration.terrainMasks.stone[shot.frame],x:hit.previousX,y:hit.previousY,adding:true)
                } else if shot.kind == .spear || shot.kind == .arrow {
                    let offsetX = shot.tip.x-shot.x, offsetY = shot.tip.y-shot.y
                    let bank = shot.kind == .spear ? configuration.terrainMasks.spear : configuration.terrainMasks.arrow
                    apply(bank[shot.frame],x:hit.x-offsetX-7,y:hit.y-offsetY-7,adding:true)
                } else {
                    if let mask = configuration.terrainMasks.blast { apply(mask,x:hit.x-11,y:hit.y-13) }
                    applyBlast(x:hit.x,y:hit.y); sound(.explode)
                }
            } else { remaining.append(shot) }
        }
        projectiles = remaining
    }

    private mutating func advanceFills() {
        for stream in fillStreams.indices {
            if !lemmings.contains(where: { $0.id == fillStreams[stream].owner && [.filling, .sandPouring, .gluePouring].contains($0.state) }) {
                fillStreams[stream].finished = true
            }
            for index in fillStreams[stream].particles.indices {
                var particle = fillStreams[stream].particles[index]
                for _ in 0..<2 where particle.direction != 0 {
                    if particle.x < 0 || particle.y < 0 || particle.x >= configuration.width || particle.y >= configuration.height {
                        particle.direction = 0; break
                    }
                    if particle.step(solid:isSolid) {
                        let offset = particle.y * configuration.width + particle.x
                        if !configuration.steel[offset] {
                            pixels[offset] = 3; solid[offset] = true; terrainRevision += 1
                        }
                        break
                    }
                }
                fillStreams[stream].particles[index] = particle
            }
        }
        fillStreams.removeAll { $0.finished && !$0.particles.contains { $0.direction != 0 } }
    }

    private func withinAttraction(_ actor: Lemming) -> Bool {
        let rows = [0x0180,0x03c0,0x07e0,0x0ff0,0x1ff8,0x1ff8,0x1ff8,0x0ff0,0x07e0,0x03c0]
        return lemmings.contains { source in
            guard source.state == .attracting, source.id != actor.id else { return false }
            let column = (actor.x >> 4) - ((source.x - 128) >> 4)
            let row = (actor.y >> 3) - (max(0, source.y - 40) >> 3)
            return rows.indices.contains(row) && (0..<16).contains(column)
                && rows[row] & (0x8000 >> column) != 0
        }
    }

    private mutating func applyBlast(x: Int, y: Int) {
        blastFlashes.append((x-17,y-20))
        // PROCESS 0c93: rectangular reach, signed integer impulse, then tumble.
        for index in lemmings.indices where lemmings[index].active {
            var actor = lemmings[index]
            let dx = actor.x - x, dy = actor.y - y
            guard abs(dx) < 48, abs(dy) < 48 else { continue }
            let vx = dx == 0 ? 0 : (6 - abs(dx) / 8) * (dx < 0 ? -1 : 1)
            let vy = vx == 0 ? -5 : -abs(vx) + 1
            if dx != 0 { actor.direction = dx < 0 ? -1 : 1 }
            actor.air = try? Lemmings2AirPhysics(x: Int16(actor.x), y: Int16(actor.y),
                velocityX: Int16(vx), velocityY: Int16(vy), horizontalCountdown: 7,
                verticalCountdown: [0,0,0,1,1,2,2,3,3][abs(vy)])
            actor.y -= 1
            change(&actor, .tumbling); actor.fallDistance = 0
            lemmings[index] = actor
        }
    }

    /// Operate a rail control once per held-pointer tick.
    public mutating func moveMachine(x: Int, y: Int) -> Bool {
        guard !isComplete else { return false }
        for index in machines.indices { if machines[index].move(atX:x,y:y) { return true } }
        return false
    }

    public mutating func nuke() {
        guard !isComplete, !isNuking else { return }
        isNuking = true
        nextToNuke = 0
    }

    public mutating func step() {
        guard !isComplete else { return }
        tick += 1
        blastFlashes.removeAll(keepingCapacity:true)
        if fanPoint != nil { fanTicks = min(74, fanTicks + 1) }
        if aimPoint.held && fanPoint == nil {
            _ = moveMachine(x:aimPoint.x,y:aimPoint.y)
            _ = releaseChain(x:aimPoint.x,y:aimPoint.y)
        }
        for index in machines.indices { machines[index].step() }
        for index in chains.indices {
            chains[index].step(fanX:fanPoint?.x ?? 0,fanY:fanPoint?.y ?? 0,
                               power:fanPoint == nil ? 0 : Lemmings2FanPhysics.power(heldTicks:fanTicks))
        }
        for object in configuration.interactiveObjects where object.kind == .timedTrap {
            timedTraps[object.id]?.step(frameCount:object.frameCount,minimum:object.minimumFrame,maximum:object.maximumFrame)
            objectFrames[object.id] = timedTraps[object.id]?.frame ?? 0
        }
        for object in configuration.interactiveObjects where activeObjects.contains(object.id) &&
            [.trap,.launcher,.trampoline].contains(object.kind) {
            let next = (objectFrames[object.id] ?? 0) + 1
            objectFrames[object.id] = next % object.frameCount
            if next >= object.frameCount && (object.kind != .launcher || object.flags & 2 != 0) {
                activeObjects.remove(object.id)
            }
        }
        if tick == 6 { sound(.levelStart) }
        if tick == 21 { sound(.doorOpen) }
        if !isNuking && released < configuration.total && tick >= configuration.firstReleaseTick &&
            (tick - configuration.firstReleaseTick) % configuration.releaseInterval == 0 {
            let entrance = configuration.entrances[released % configuration.entrances.count]
            lemmings.append(Lemming(id: released, x: entrance.x, y: entrance.y))
            released += 1
        }
        for index in lemmings.indices where lemmings[index].active {
            var lem = lemmings[index]
            if let countdown = lem.bombTicks {
                lem.bombTicks = countdown - 1
                if countdown <= 1 {
                    lem.bombTicks = nil
                    if configuration.tribe != 0 {
                        if let mask = configuration.terrainMasks.blast {
                            apply(mask,x:lem.x-11,y:lem.y-15)
                        }
                        change(&lem,.dead); lemmings[index] = lem
                        applyBlast(x:lem.x,y:lem.y); sound(.explode)
                        continue
                    }
                    sound(.countdown); change(&lem, .exploding)
                }
            }
            if enterHazard(&lem) {
                sound(configuration.fireHazards.contains(where: { $0.contains(lem.x, lem.y) }) ? .fire : .drown)
                lemmings[index] = lem; continue
            }
            var leavingIce = false
            var blast: (x: Int, y: Int)?
            let stateAtStart = lem.state
            switch lem.state {
            case .filling, .sandPouring, .gluePouring:
                if lem.age == 4, let stream = fillStreams.lastIndex(where: { $0.owner == lem.id && !$0.finished }) {
                    let x = lem.x + 4 * lem.direction, y = lem.y - 8
                    if fillStreams[stream].particles.count >= 78 || isSolid(x,y) || isSolid(x,y-1) {
                        fillStreams[stream].finished = true
                    } else {
                        let kind = fillStreams[stream].kind
                        fillStreams[stream].particles.append(.init(x:x,y:y,direction:lem.direction,kind:kind))
                        fillStreams[stream].particles.append(.init(x:x,y:y-1,direction:lem.direction,kind:kind))
                        lem.age = 3
                    }
                } else if lem.age + 1 >= 11 { change(&lem, .walking) }
            case .trapDying:
                let count = [126:17,127:15,128:11][lem.deathSprite] ?? 1
                if lem.age+1 >= count { change(&lem,.dead) }
            case .switchingValve:
                if lem.age+1 >= 9 {
                    if let id = lem.interactionID { busyValves.remove(id) }
                    lem.interactionID = nil; lem.x += lem.direction; change(&lem,.walking)
                }
            case .teleporting:
                if lem.work == 0 {
                    lem.pose += 1
                    if lem.pose >= 27, let destination = configuration.interactiveObjects.first(where:{$0.id == lem.interactionID}) {
                        lem.x = destination.destinationX; lem.y = destination.destinationY; lem.work = 1; sound(.teleporter)
                    }
                } else {
                    lem.pose -= 1
                    if lem.pose <= 9 {
                        lem.x += lem.direction
                        change(&lem,lem.restoreMagno ? .magnoBooting : .walking)
                        if lem.restoreMagno { lem.magno = .init(x:lem.x,y:lem.y) }
                        lem.interactionID = nil
                    }
                }
            case .cannonLoading, .catapultLoading:
                guard let machine = machines.first(where: { $0.id == lem.machineID }) else {
                    change(&lem,.falling); break
                }
                let cannon = lem.state == .cannonLoading
                if cannon && lem.pose == 44 && machine.frame == 5 {
                    lem.x += 2; lem.y -= 11; change(&lem,.cannonFlying); lem.pose = 45
                    lem.air = try? .init(x:Int16(lem.x),y:Int16(lem.y),velocityX:8,velocityY:-6,horizontalCountdown:7,verticalCountdown:7)
                    lem.machineID = nil; sound(.launched)
                } else {
                    lem.pose = min(cannon ? 44 : 57,lem.pose+1)
                    let point = machine.riderPosition(phase:lem.pose); lem.x = point.x; lem.y = point.y
                    if !cannon && lem.pose == 57 {
                        change(&lem,.tumbling)
                        lem.air = try? .init(x:Int16(lem.x),y:Int16(lem.y),velocityX:-8,velocityY:-6,horizontalCountdown:7,verticalCountdown:7)
                        lem.machineID = nil; sound(.launched)
                    }
                }
            case .cannonFlying:
                advanceAirborne(&lem)
                if lem.state == .cannonFlying {
                    if lem.pose > 45 || (lem.air?.velocityY ?? 0) < 0 { lem.pose += 1 }
                    if lem.pose >= 53 { change(&lem,.tumbling) }
                }
            case .chainRiding:
                if let chain = chains.first(where:{$0.id == lem.chainID}), let position = chain.riderPosition(link:lem.chainLink) {
                    lem.x = position.x; lem.y = position.y; lem.pose = position.pose
                } else { change(&lem, .falling); lem.fallDistance = 0 }
            case .superFlying:
                if var flight = lem.superFlight {
                    let result = flight.step(targetX:aimPoint.x,targetY:aimPoint.y,solid:isSolid)
                    lem.superFlight = flight; lem.x = flight.x; lem.y = flight.y; lem.pose = flight.pose
                    if flight.velocityX != 0 { lem.direction = flight.velocityX > 0 ? 1 : -1 }
                    switch result {
                    case .active: break
                    case .walking: change(&lem, .walking)
                    case .falling: change(&lem, .falling); lem.fallDistance = 0
                    case .stunned: change(&lem, .stunned)
                    case .tumbling:
                        change(&lem, .tumbling)
                        lem.air = try? Lemmings2AirPhysics(x:Int16(lem.x),y:Int16(lem.y),
                            velocityX:Int16(flight.velocityX),velocityY:Int16(flight.velocityY),horizontalCountdown:7,verticalCountdown:0)
                    }
                } else { change(&lem, .falling); lem.fallDistance = 0 }
            case .arching:
                if !isSolid(lem.x,lem.y) { change(&lem, .falling); lem.fallDistance = 0 }
                else if lem.age < 16 { lem.pose = min(15,lem.age+1) }
                else if lem.driftX == 0 {
                    let dx = aimPoint.x-lem.x, dy = aimPoint.y+8-lem.y
                    let angle = Int((atan2(Double(dy),Double(dx))*16 / .pi).rounded()+32)%32
                    lem.pose = 32+[10,11,12,12,12,0,0,1,2,3,4,5,6,7,8,9][angle/2]
                    if aimPoint.held {
                        lem.work -= 1
                        if lem.work == 0 { change(&lem, .walking) }
                        else if projectiles.count < 10, let shot = try? Lemmings2Projectile.aimedArrow(
                            x:lem.x,y:lem.y-8,targetX:aimPoint.x,targetY:aimPoint.y) {
                            projectiles.append(shot); lem.driftX = 1; sound(.rope)
                        }
                    }
                } else if lem.pose < 58 { lem.pose += 13 }
                else { lem.driftY -= 1; if lem.driftY == 0 { change(&lem, .walking) } }
            case .skiing:
                if var ski = lem.ski {
                    let contact = ski.step(x:&lem.x,y:&lem.y,direction:&lem.direction,solid:isSolid,
                        exit:{x,y in configuration.exits.contains(where:{$0.contains(x,y)})})
                    lem.ski = ski
                    let speed = min(5,abs(ski.velocityX)/16)
                    lem.pose = speed < 3 ? (lem.pose+1)%16 : 17+(speed-3)*3+(ski.velocityY == 0 ? 0 : ski.velocityY < 0 ? 1 : -1)
                    switch contact {
                    case .exiting: change(&lem,.exiting)
                    case .riding: break
                    case .walking: change(&lem, .walking)
                    case .stunned: change(&lem, .stunned)
                    case .airborne:
                        change(&lem, .skiingAir)
                        lem.air = try? Lemmings2AirPhysics(x:Int16(lem.x),y:Int16(lem.y),
                            velocityX:Int16(ski.velocityX/16),velocityY:Int16(ski.velocityY/16),horizontalCountdown:7,verticalCountdown:0)
                    }
                } else { change(&lem, .walking) }
            case .poleShrugging:
                if lem.age + 1 >= 21 { change(&lem, .walking) }
            case .poleVaulting:
                let phase = min(55,lem.age)
                let obstructed = lem.poleContact != nil
                if obstructed && phase < 25 { change(&lem, .poleShrugging); break }
                if phase < 24 {
                    for _ in 0..<2 {
                        let nx = lem.x+lem.direction
                        if let rise = (-3...3).first(where:{isSolid(nx,lem.y+$0) && !isSolid(nx,lem.y+$0-1)}) {
                            lem.x = nx; lem.y += rise
                        } else { change(&lem, .walking); break }
                    }
                    if phase == 19 && !isSolid(lem.x+68*lem.direction,lem.y) { change(&lem, .poleShrugging) }
                }
                if lem.state == .poleVaulting {
                    let entry = Lemmings2PoleVault.phases[phase]
                    lem.pose = entry.pose
                    var blocked = false
                    if entry.deltaX != 0 || entry.rise != 0 {
                        let hit = Lemmings2AirCollision.sweep(x:lem.x,y:lem.y-1,
                            toX:lem.x+entry.deltaX*lem.direction,toY:lem.y-entry.rise-1,height:10,solid:isSolid)
                        blocked = hit.contact != .clear
                        lem.x = blocked ? hit.previousX : hit.x
                        lem.y = (blocked ? hit.previousY : hit.y)+1
                    }
                    if phase <= 20 { lem.poleX = lem.x; lem.poleY = lem.y-71 }
                    let limit = phase+1 < 16 ? (phase+1)*4 : 0
                    lem.pole = Lemmings2PoleVault.points(pose:entry.polePose,x:lem.poleX,y:lem.poleY,direction:lem.direction,limit:limit)
                    lem.poleContact = lem.pole.firstIndex(where:{isSolid($0.x,$0.y)})
                    if let contact = lem.poleContact { lem.pole = Array(lem.pole.prefix(contact+1)) }
                    if blocked || phase == 54 || (obstructed && !(phase == 54 && (lem.poleContact ?? 100) <= 16)) {
                        let next = Lemmings2PoleVault.phases[phase+1]
                        let vx = next.deltaX == 0 && phase <= 28 ? 2 : next.deltaX
                        change(&lem, .tumbling)
                        lem.air = try? Lemmings2AirPhysics(x:Int16(lem.x),y:Int16(lem.y),
                            velocityX:Int16(vx*lem.direction),velocityY:Int16(-next.rise),horizontalCountdown:7,verticalCountdown:0)
                    }
                }
            case .magnoBooting:
                if var boots = lem.magno {
                    let attached = boots.step(direction:&lem.direction,solid:isSolid)
                    lem.x = boots.displayX; lem.y = boots.displayY; lem.pose = boots.frame; lem.magno = boots
                    if !attached { change(&lem, .falling); lem.fallDistance = 0; lem.magno = nil }
                } else { change(&lem, .falling); lem.fallDistance = 0 }
            case .throwing, .spearing:
                if !isSolid(lem.x,lem.y) { change(&lem, .falling); lem.fallDistance = 0 }
                else {
                    let spear = lem.state == .spearing
                    lem.pose += 1
                    if lem.runner && lem.pose == 25 {
                        lem.work -= 1
                        if lem.work > 0 { lem.pose = 21 }
                    }
                    let launchFrame = lem.runner ? (spear ? 26 : 25) : 13
                    if lem.pose == launchFrame, projectiles.count < 10 {
                        let vx = (spear ? 6 : 5) + (lem.runner ? 1 : 0)
                        if let shot = try? Lemmings2Projectile(kind:spear ? .spear : .stone,
                            x:lem.x-(spear ? 1 : 4),y:lem.y-(spear ? 8 : 6),
                            velocityX:vx*lem.direction,velocityY:spear ? -4 : -5) { projectiles.append(shot) }
                    }
                    if lem.runner && lem.pose <= 26 && lem.pose != launchFrame {
                        for _ in 0..<2 {
                            let nx = lem.x+lem.direction
                            let contact: Int?
                            if isSolid(nx,lem.y-1) {
                                contact = (1...4).first(where:{!isSolid(nx,lem.y-$0-1)}).map { -$0 }
                            } else { contact = (0...3).first(where:{isSolid(nx,lem.y+$0)}) }
                            guard let contact else { change(&lem, .walking); break }
                            lem.x = nx; lem.y += contact
                        }
                    }
                    if lem.pose >= (lem.runner ? 40 : 21) { change(&lem, .walking) }
                }
            case .carpetFlying:
                if lem.age + 1 == 16 { lem.y -= 1 }
                else if lem.age >= 16 {
                    let distance = (0..<8).first(where:{isSolid(lem.x,lem.y+$0)})
                    let motion = Lemmings2FanPhysics.step(x:lem.x,y:lem.y,velocityX:lem.driftX,
                        velocityY:lem.driftY,fanX:fanPoint?.x ?? lem.x,fanY:fanPoint?.y ?? lem.y,
                        power:fanPoint == nil ? 0 : Lemmings2FanPhysics.power(heldTicks:fanTicks),
                        mode:.magicCarpet,lift:distance.map{(8-$0)*64} ?? -150)
                    lem.driftX = motion.velocityX; lem.driftY = motion.velocityY
                    let hit = Lemmings2AirCollision.sweep(x:lem.x,y:lem.y,toX:lem.x+2*lem.direction,
                        toY:lem.y+motion.deltaY,height:10,solid:isSolid)
                    let nx = hit.contact == .clear ? hit.x : hit.previousX
                    let ny = hit.contact == .clear ? hit.y : hit.previousY
                    if nx == lem.x && ny == lem.y { change(&lem, .falling); lem.fallDistance = 0 }
                    lem.x = nx; lem.y = ny
                }
            case .surfing:
                if lem.pose < 11 { lem.pose += 1 }
                else {
                    let motion = Lemmings2FanPhysics.step(x:lem.x,y:lem.y,velocityX:lem.driftX,
                        velocityY:lem.driftY,fanX:fanPoint?.x ?? lem.x,fanY:fanPoint?.y ?? lem.y,
                        power:fanPoint == nil ? 0 : Lemmings2FanPhysics.power(heldTicks:fanTicks),mode:.surfer)
                    lem.driftX = motion.velocityX; lem.driftY = motion.velocityY
                    lem.x += motion.deltaX
                    if motion.deltaX == 0 {
                        lem.work -= 1; lem.pose = lem.pose >= 19 ? 11 : lem.pose+1
                        if lem.work == 0 { change(&lem, lem.swimmer ? .swimming : .drowning) }
                    } else {
                        lem.direction = motion.deltaX > 0 ? 1 : -1; lem.pose = 11; lem.work = 45
                        if isSolid(lem.x+10*lem.direction,lem.y) {
                            lem.y -= 1; change(&lem, .jumping)
                            lem.air = try? Lemmings2AirPhysics(x:Int16(lem.x),y:Int16(lem.y),
                                velocityX:Int16(3*lem.direction),velocityY:-3,horizontalCountdown:7,verticalCountdown:1)
                        }
                    }
                }
            case .sliding:
                let frame = min(lem.age + 1,11)
                lem.pose = frame
                if frame >= 9 {
                    for _ in 0..<(frame == 9 ? 6 : 2) {
                        if isSolid(lem.x,lem.y) { change(&lem, .walking); break }
                        lem.y += 1
                    }
                    if lem.state == .sliding && !isSolid(lem.x-lem.direction,lem.y-6) {
                        lem.x -= lem.direction; lem.y += 2
                        beginHanging(&lem)
                    }
                }
                if lem.age >= 11 { lem.age = 9 }
            case .hanging:
                if (0...4).contains(where:{isSolid(lem.x,lem.y-$0)}) {
                    lem.y += 1; lem.direction = -lem.direction; change(&lem, .walking)
                } else {
                    var release = (4...8).contains(where:{isSolid(lem.x,lem.y-$0)}) || !isSolid(lem.x,lem.y-10)
                    if lem.age + 1 >= 8 { lem.work -= 1; release = release || lem.work == 0; lem.age = 0 }
                    if release {
                        lem.direction = -lem.direction
                        if (0...4).contains(where:{isSolid(lem.x+lem.direction,lem.y+3-$0)}) {
                            lem.y += 1; lem.direction = -lem.direction; change(&lem, .walking)
                        } else { change(&lem, .falling); lem.fallDistance = 0 }
                    }
                }
            case .climbingTransfer:
                if !isSolid(lem.x,lem.y-9) { change(&lem, .falling); lem.fallDistance = 0 }
                else if lem.age + 1 >= 5 {
                    lem.direction = -lem.direction
                    if lem.rockClimber { lem.pose = 0; change(&lem, .rockClimbing) }
                    else { lem.y -= 1; change(&lem, .climbing) }
                }
            case .skating, .slipping:
                if !isSolid(lem.x,lem.y) { change(&lem, .falling); lem.fallDistance = 0 }
                else {
                    var strides = 1
                    if lem.state == .skating {
                        let table = [512,513,514,515,772,773,774,775,776,776,776,776,520,520,520,520,
                                     521,522,523,524,781,782,783,784,785,785,785,785,529,529,529,529]
                        let entry = table[lem.age % 32]; lem.pose = entry & 255; strides = entry >> 8
                    } else if (lem.age + 1) % 8 == 0 {
                        lem.work -= 1
                        if lem.work == 0 {
                            if lem.iceDirection != lem.direction { lem.x -= lem.direction }
                            change(&lem, .iceRecovering); lem.work = 6; lem.pose = 0
                        }
                    }
                    if lem.state != .iceRecovering {
                        for _ in 0..<strides {
                            let nx = lem.x + lem.direction
                            if !configuration.ice.contains(where:{$0.contains(nx,lem.y)}) || isSolid(nx,lem.y-1) {
                                if isSolid(nx,lem.y-1) { lem.y -= 1 }
                                change(&lem, .walking); leavingIce = true; break
                            }
                            lem.x = nx
                        }
                    }
                }
            case .iceRecovering:
                if !isSolid(lem.x,lem.y) { change(&lem, .falling); lem.fallDistance = 0 }
                else {
                    if lem.pose == 4 || lem.pose == 9 {
                        lem.work -= 1
                        if lem.work == 0 { lem.work = lem.pose == 4 ? 4 : 6; lem.pose += 1 }
                    } else { lem.pose += 1 }
                    if lem.pose >= 14 {
                        if !lem.skater { lem.direction = -lem.direction }
                        change(&lem, .slipping); lem.work = 2
                    }
                }
            case .twisting:
                let motion = Lemmings2FanPhysics.step(x:lem.x,y:lem.y,velocityX:lem.driftX,
                    velocityY:lem.driftY,fanX:fanPoint?.x ?? lem.x,fanY:fanPoint?.y ?? lem.y,
                    power:fanPoint == nil ? 0 : Lemmings2FanPhysics.power(heldTicks:fanTicks),mode:.twister)
                lem.driftX = motion.velocityX; lem.driftY = motion.velocityY
                lem.x += motion.deltaX; lem.y += motion.deltaY
                if let mask = configuration.terrainMasks.twister { apply(mask,x:lem.x-8,y:lem.y-11) }
                if !(0..<5).contains(where:{isSolid(lem.x,lem.y+$0)}) {
                    change(&lem, .falling); lem.fallDistance = 0
                } else if steelProbe(lem,[(0,1),(4,-5),(0,-10),(-4,-5)]) { change(&lem, .walking) }
            case .jetPacking:
                let distance = (0..<12).first(where:{isSolid(lem.x,lem.y+$0)})
                let lift = distance.map { (17-$0)*64 } ?? -300
                let motion = Lemmings2FanPhysics.step(x:lem.x,y:lem.y,velocityX:lem.driftX,
                    velocityY:lem.driftY,fanX:fanPoint?.x ?? lem.x,fanY:fanPoint?.y ?? lem.y,
                    power:fanPoint == nil ? 0 : Lemmings2FanPhysics.power(heldTicks:fanTicks),mode:.jetPack,lift:lift)
                let targetX = lem.x+motion.deltaX, targetY = lem.y+motion.deltaY
                lem.driftX = motion.velocityX; lem.driftY = motion.velocityY
                Lemmings2AirCollision.bounce(x:&lem.x,y:&lem.y,toX:targetX,toY:targetY,
                    velocityX:&lem.driftX,velocityY:&lem.driftY,solid:isSolid)
                if lem.x == targetX { lem.pose = 4 }
                else if lem.x > targetX && lem.pose != 2 { lem.pose = lem.pose+1 > 2 ? 1 : lem.pose+1 }
                else if lem.x < targetX && lem.pose != 6 { lem.pose = lem.pose+1 <= 3 ? 4 : lem.pose+1 }
                if lem.age + 1 >= 150 { change(&lem, .falling); lem.fallDistance = 0 }
            case .rolling:
                if var roller = lem.ski {
                    let contact = roller.step(x:&lem.x,y:&lem.y,direction:&lem.direction,solid:isSolid,
                        exit:{x,y in configuration.exits.contains(where:{$0.contains(x,y)})})
                    lem.ski = roller
                    if lem.pose < 3 { lem.pose += 1 }
                    else {
                        let speed = max(abs(roller.velocityX),abs(roller.velocityY))/16
                        lem.pose += [3,3,3,4,5,6][min(5,speed)]
                        if lem.pose >= 19 { lem.pose -= 16 }
                    }
                    switch contact {
                    case .exiting: change(&lem,.exiting)
                    case .riding: break
                    case .walking: change(&lem, .walking)
                    case .stunned: change(&lem, .stunned)
                    case .airborne:
                        change(&lem, .rollingAir)
                        lem.air = try? Lemmings2AirPhysics(x:Int16(lem.x),y:Int16(lem.y),
                            velocityX:Int16(roller.velocityX/16),velocityY:Int16(roller.velocityY/16),
                            horizontalCountdown:7,verticalCountdown:0)
                    }
                } else { change(&lem, .walking) }
            case .shimming:
                advanceShimmy(&lem)
            case .diving:
                if lem.runner || lem.age >= 3 { advanceAirborne(&lem) }
            case .drowning:
                if lem.age + 1 >= 16 { change(&lem, .dead) }
                else if isWater(lem.x+5*lem.direction,lem.y) { lem.x += lem.direction }
                else { lem.direction = -lem.direction }
            case .kayaking:
                if lem.age + 1 >= 24 {
                    for _ in 0..<2 {
                        lem.x += lem.direction
                        let probeX = lem.x + (lem.direction > 0 ? 4 : -5)
                        let blocked = isSolid(probeX,lem.y-1)
                        if !isWater(probeX,lem.y) || blocked {
                            change(&lem, .kayakPacking); lem.work = blocked ? 1 : 0; break
                        }
                    }
                }
            case .kayakPacking:
                if lem.age + 1 >= 24 {
                    if lem.work == 1 {
                        lem.x += 4*lem.direction; lem.y -= 1; change(&lem, .leavingWater); lem.work = 1
                    } else {
                        let x = lem.x + (lem.direction > 0 ? 4 : -5)
                        if !isSolid(x,lem.y-9) { lem.x = x; lem.y -= 9; change(&lem, .leavingWater) }
                        else { lem.direction = -lem.direction; change(&lem, .drowning) }
                    }
                }
            case .flyingIcarus, .hangGliding:
                let icarus = lem.state == .flyingIcarus
                let motion = Lemmings2FanPhysics.step(x:lem.x,y:lem.y,velocityX:lem.driftX,
                    velocityY:lem.driftY,fanX:fanPoint?.x ?? lem.x,fanY:fanPoint?.y ?? lem.y,
                    power:fanPoint == nil ? 0 : Lemmings2FanPhysics.power(heldTicks:fanTicks),
                    mode:icarus ? .icarus : .hangGlider)
                lem.driftX = motion.velocityX; lem.driftY = motion.velocityY
                if icarus && motion.deltaX != 0 { lem.direction = motion.deltaX < 0 ? -1 : 1 }
                let hit = Lemmings2AirCollision.sweep(x:lem.x,y:lem.y,
                    toX:lem.x + (icarus ? 1 : 2)*lem.direction,
                    toY:lem.y + motion.deltaY + (icarus ? (lem.age < 8 ? -1 : 0) : 1),
                    height:icarus ? 8 : 7,solid:isSolid)
                lem.x = hit.x; lem.y = hit.y
                if hit.contact != .clear {
                    lem.x -= lem.direction
                    change(&lem, !icarus && hit.contact == .body ? .walking : .falling)
                    lem.fallDistance = 0
                }
            case .roping:
                if !isSolid(lem.x,lem.y) { change(&lem, .falling); lem.fallDistance = 0 }
                else if lem.pose == 0 && lem.age >= 19 { lem.pose = 1 }
                else if lem.pose == 1 && aimPoint.held {
                    if let launched = try? Lemmings2Rope(owner:lem.id,x:lem.x,y:lem.y-1,targetX:aimPoint.x,targetY:aimPoint.y) {
                        rope = launched; lem.pose = 2; lem.age = 0; sound(.rope)
                    } else {
                        lem.work -= 1
                        if lem.work <= 0 { lem.x -= lem.direction; change(&lem, .walking) }
                    }
                } else if lem.pose == 2 && rope == nil { lem.x -= lem.direction; change(&lem, .walking) }
            case .firingBazooka, .firingMortar:
                let bazooka = lem.state == .firingBazooka
                let phase = lem.age + 1
                if !isSolid(lem.x,lem.y) { change(&lem, .falling); lem.fallDistance = 0 }
                else if phase >= (bazooka ? 27 : 23) { change(&lem, .walking) }
                else if phase == (bazooka ? 10 : 12), projectiles.count < 10 {
                    let x = lem.x + (bazooka ? -2 : 1) - (lem.direction < 0 ? 3 : 0)
                    if let shot = try? Lemmings2Projectile(kind:bazooka ? .bazooka : .mortar,
                        x:x,y:lem.y-(bazooka ? 6 : 1),velocityX:(bazooka ? 8 : 5)*lem.direction,
                        velocityY:bazooka ? -3 : -5) { projectiles.append(shot) }
                }
            case .hoisting:
                if !isSolid(lem.x, lem.y) { change(&lem, .falling); lem.fallDistance = 0 }
                else if lem.age + 1 >= 8 { change(&lem, .walking) }
            case .rockClimbing:
                let contact = Lemmings2Climbing.rock(x:&lem.x,y:&lem.y,direction:lem.direction,
                    phase:lem.age,pose:&lem.pose,previousSlope:&lem.work,solid:isSolid)
                switch contact {
                case .climbing: break
                case .hoisting: change(&lem,.hoisting)
                case .hanging: beginHanging(&lem)
                case .falling: change(&lem,.falling); lem.fallDistance = 0
                }
            case .planting:
                let phase = lem.age + 1
                if phase >= 30 { change(&lem, .walking) }
                else if phase >= 22 {
                    apply(configuration.terrainMasks.plant[phase-22],
                          x:lem.x-16+3*lem.direction,y:lem.y-8,adding:true)
                }
            case .ballooning:
                if lem.age + 1 >= 8 {
                    let motion = Lemmings2FanPhysics.step(x:lem.x,y:lem.y,velocityX:lem.driftX,
                        velocityY:lem.driftY,fanX:fanPoint?.x ?? lem.x,fanY:fanPoint?.y ?? lem.y,
                        power:fanPoint == nil ? 0 : Lemmings2FanPhysics.power(heldTicks:fanTicks),mode:.balloon)
                    lem.driftX = motion.velocityX; lem.driftY = motion.velocityY
                    let hit = Lemmings2AirCollision.sweep(x:lem.x,y:lem.y,
                        toX:lem.x+motion.deltaX,toY:lem.y+motion.deltaY,solid:isSolid)
                    lem.x = hit.contact == .clear ? hit.x : hit.previousX
                    lem.y = hit.contact == .clear ? hit.y : hit.previousY
                    let probes = [(0,-30),(0,-25),(0,-19),(0,-14),(-5,-21),(-4,-28),(7,-21),(6,-28)]
                    if probes.contains(where:{isSolid(lem.x+$0.0,lem.y+$0.1)}) {
                        sound(.balloonPop); change(&lem, .falling); lem.fallDistance = 0
                    }
                    if lem.y < 0 { change(&lem, .dead) }
                }
            case .attracting:
                if !isSolid(lem.x, lem.y) { change(&lem, .falling); lem.fallDistance = 0 }
            case .dancing:
                if !withinAttraction(lem) { change(&lem, .walking) }
                else if !isSolid(lem.x, lem.y) { change(&lem, .falling); lem.fallDistance = 0 }
            case .parachuting:
                let motion = Lemmings2FanPhysics.step(x:lem.x,y:lem.y,velocityX:lem.driftX,
                    velocityY:lem.driftY,fanX:fanPoint?.x ?? lem.x,fanY:fanPoint?.y ?? lem.y,
                    power:fanPoint == nil ? 0 : Lemmings2FanPhysics.power(heldTicks:fanTicks))
                lem.driftX = motion.velocityX; lem.driftY = motion.velocityY
                let hit = Lemmings2AirCollision.sweep(x:lem.x,y:lem.y,
                    toX:lem.x + motion.deltaX,toY:lem.y + 1,solid:isSolid)
                lem.x = hit.contact == .clear ? hit.x : hit.previousX
                lem.y = hit.contact == .clear ? hit.y : hit.previousY
                if hit.contact != .clear { change(&lem, .walking); lem.fallDistance = 0 }
            case .swimming:
                let nextX = lem.x + lem.direction
                let probeX = nextX + 4 * lem.direction
                if isWater(probeX, lem.y) {
                    if isSolid(probeX, lem.y - 1) {
                        lem.x = probeX; lem.y -= 1; change(&lem, .leavingWater); lem.work = 1
                    } else { lem.x = nextX }
                } else if !isSolid(probeX, lem.y - 9) {
                    lem.x = probeX; lem.y -= 9; change(&lem, .leavingWater); lem.work = 0
                } else {
                    lem.direction = -lem.direction
                }
            case .leavingWater:
                if lem.age + 1 >= (lem.work == 1 ? 3 : 13) { change(&lem, .walking) }
            case .blastBombing:
                if lem.age + 1 == 10 {
                    if let mask = configuration.terrainMasks.blast {
                        apply(mask, x: lem.x - 11, y: lem.y - 15)
                    }
                    blast = (lem.x, lem.y)
                    sound(.explode)
                }
            case .trapped:
                change(&lem, .dead)
            case .hopPreparing:
                if lem.age + 1 >= 3 {
                    change(&lem, .hopping)
                    lem.air = try? Lemmings2AirPhysics(x: Int16(lem.x), y: Int16(lem.y),
                        velocityX: Int16(2 * lem.direction), velocityY: -3, horizontalCountdown: 7, verticalCountdown: 1)
                }
            case .jumping, .tumbling, .hopping, .shimmyJump, .rollingAir, .skiingAir:
                advanceAirborne(&lem)
                if lem.state == .rollingAir, let air = lem.air {
                    let speed = min(8,max(abs(Int(air.velocityX)),abs(Int(air.velocityY))))
                    lem.pose += [3,3,3,4,5,6,7,7,7][speed]
                    if lem.pose >= 19 { lem.pose -= 16 }
                }
            case .stunned:
                if !isSolid(lem.x, lem.y) { change(&lem, .falling); lem.fallDistance = 0 }
                else if lem.age + 1 >= 35 { change(&lem, .walking) }
            case .falling, .floating:
                if lem.state == .falling && lem.parachuter && lem.fallDistance >= 16 {
                    change(&lem, .parachuting); lem.driftX = 2000 * lem.direction; lem.driftY = 0
                    break
                }
                if lem.state == .falling && lem.floater && lem.fallDistance >= 16 { change(&lem, .floating) }
                // PROCESS 5ed6: the umbrella opens with a short upward tug,
                // then descends at two pixels per tick.
                let floatSpeeds = [3, 3, 3, 3, -1, 0, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2]
                let distance = lem.state == .floating ? floatSpeeds[min(15, lem.age)] : 3
                if distance < 0 { lem.y += distance }
                for _ in 0..<max(0, distance) {
                    if isSolid(lem.x, lem.y) {
                        if lem.fallDistance > 64 && lem.state != .floating { sound(.splat) }
                        change(&lem, lem.fallDistance > 64 && lem.state != .floating ? .dead : .walking)
                        lem.fallDistance = 0; break
                    }
                    lem.y += 1; lem.fallDistance += 1
                }
            case .walking, .running:
                let strides = lem.state == .running ? 2 : 1
                for _ in 0..<strides {
                    let direction = lem.direction
                    advanceWalker(&lem)
                    if lem.state != .walking && lem.state != .running { break }
                    if strides == 2 && enterHazard(&lem) {
                        sound(configuration.fireHazards.contains(where: { $0.contains(lem.x, lem.y) }) ? .fire : .drown)
                        change(&lem, .dead); break
                    }
                    if strides == 2 && configuration.exits.contains(where: { $0.contains(lem.x, lem.y) }) {
                        change(&lem, .exiting); break
                    }
                    if lem.direction != direction { break }
                }
            case .climbing:
                let contact = Lemmings2Climbing.classic(x:&lem.x,y:&lem.y,direction:&lem.direction,
                    phase:lem.age,solid:isSolid)
                switch contact {
                case .climbing: break
                case .hoisting: change(&lem,.hoisting)
                case .falling: change(&lem,.falling); lem.fallDistance = 0
                case .hanging: beginHanging(&lem)
                }
            case .building:
                let phase = (lem.age + 1) % 16
                if phase == 10 && lem.work >= 9 { sound(.builderWarning) }
                if phase == 9 {
                    apply(configuration.terrainMasks.brick, x: lem.x - 8 - (lem.direction < 0 ? 4 : 0),
                          y: lem.y - 1, adding: true)
                } else if phase == 0 {
                    lem.x += lem.direction; lem.y -= 1
                    if isSolid(lem.x, lem.y - 1) || isSolid(lem.x + lem.direction, lem.y - 1) {
                        lem.direction = -lem.direction; change(&lem, .walking)
                    } else {
                        lem.x += lem.direction; lem.work += 1
                        if lem.work == 12 { change(&lem, .shrugging) }
                        else if isSolid(lem.x + 2 * lem.direction, lem.y - 9) {
                            lem.direction = -lem.direction; change(&lem, .walking)
                        }
                    }
                }
            case .stacking:
                let phase = (lem.age + 1) % 32
                if phase == 7 || phase == 23 {
                    if lem.work <= 3 { sound(.builderWarning) }
                    apply(configuration.terrainMasks.stacker[phase == 7 ? 0 : 1],
                          x: lem.x - 7 - (lem.direction < 0 ? 1 : 0), y: lem.y - 6, adding: true)
                } else if phase == 11 || phase == 27 {
                    lem.y -= 2
                } else if phase == 12 || phase == 28 {
                    lem.direction = -lem.direction
                    lem.x -= lem.direction
                } else if phase == 0 || phase == 16 {
                    lem.work -= 1
                    if lem.work == 0 {
                        // PROCESS 8a78 aligns the left-facing shrug animation.
                        if lem.direction < 0 { lem.x += 1 }
                        change(&lem, .shrugging)
                    } else if isSolid(lem.x, lem.y - 10) { change(&lem, .walking) }
                }
            case .platforming:
                var phase = lem.age + 1
                if phase == 38 {
                    lem.work -= 1
                    if lem.work == 0 { change(&lem, .platformerShrugging); break }
                    phase = 22
                }
                // The first brick has a 22-frame lead-in. Later bricks repeat
                // frames 22–37, not the complete animation.
                lem.age = phase - 1
                if phase == 10 || phase == 28 {
                    if phase == 28 && lem.work <= 3 { sound(.builderWarning) }
                    let first = phase == 10
                    let x = lem.x + lem.direction - (first ? 5 : 6) - (lem.direction < 0 ? (first ? 4 : 2) : 0)
                    apply(configuration.terrainMasks.platformer, x: x, y: lem.y - (first ? 8 : 6), adding: true)
                    if isSolid(lem.x + (first ? 6 : 5) * lem.direction, lem.y - (first ? 2 : 0)) {
                        change(&lem, .walking)
                    }
                } else if phase == 14 {
                    lem.x += lem.direction; lem.y -= 1
                } else if phase == 15 {
                    lem.y -= 1
                } else if [16, 18, 19, 20, 29, 31, 33, 35].contains(phase) {
                    lem.x += lem.direction
                    if isSolid(lem.x - (lem.direction < 0 ? 1 : 0), lem.y - 1) {
                        change(&lem, .platformerShrugging)
                    }
                }
            case .flaming:
                if !isSolid(lem.x, lem.y) { change(&lem, .falling); lem.fallDistance = 0 }
                else if lem.age + 1 == 16 { change(&lem, .walking) }
                else {
                    apply(configuration.terrainMasks.flame[lem.direction > 0 ? 0 : 1],
                          x: lem.x - (lem.direction < 0 ? 32 : 0), y: lem.y - 12)
                }
            case .lasering:
                if !isSolid(lem.x, lem.y) { change(&lem, .falling); lem.fallDistance = 0; break }
                let x = lem.x - 8 + 2 * lem.direction, y = lem.y - 17
                if lem.age % 16 == 0 {
                    var reach = 0
                    while reach < 12 {
                        let top = y - reach * 8
                        if top < 0 { reach -= 1; break }
                        if [(6,0),(9,0),(9,7),(6,7)].contains(where: { isSolid(x + $0.0, top + $0.1) }) { break }
                        reach += 1
                    }
                    if reach == lem.work { change(&lem, .walking); break }
                    lem.work = reach
                }
                if lem.work >= 0 {
                    for segment in 0...lem.work {
                        apply(configuration.terrainMasks.laser[0], x: x, y: y - segment * 8)
                    }
                }
            case .scooping:
                let phase = (lem.age + 1) % 20
                if phase < 17 && !isSolid(lem.x, lem.y) {
                    change(&lem, .falling); lem.fallDistance = 0; break
                }
                if phase >= 17 {
                    lem.x += [2, 2, 1][phase - 17] * lem.direction
                    lem.y += [0, 2, 2][phase - 17]
                }
                if (1...6).contains(phase) {
                    let frame = phase - 1 + (lem.direction < 0 ? 6 : 0)
                    apply(configuration.terrainMasks.scooper[frame],
                          x: lem.x + (lem.direction > 0 ? -6 : -9), y: lem.y - 12)
                    if steelProbe(lem, [(1, 2), (7, 0), (7, -7)]) {
                        sound(.hitSteel); change(&lem, .walking)
                    }
                }
            case .fencing:
                let phase = (lem.age + 1) % 16
                if phase == 8 {
                    if steelProbe(lem, [(12, -3), (6, -10)]) {
                        sound(.hitSteel); change(&lem, .walking)
                    } else {
                        apply(configuration.terrainMasks.fencer[lem.direction > 0 ? 0 : 1],
                              x: lem.x - (lem.direction > 0 ? 3 : 12), y: lem.y - 16)
                    }
                } else if phase == 11 {
                    let x = lem.x + lem.direction + 10 - (lem.direction < 0 ? 22 : 0)
                    if !(0...2).contains(where: { isSolid(x + $0, lem.y - 3) }) { change(&lem, .walking) }
                } else if [4, 7, 12, 15].contains(phase) {
                    let x = lem.x + lem.direction
                    var y = lem.y
                    if isSolid(x, y) || isSolid(x, y - 1) {
                        var clear = false
                        for _ in 0..<4 { y -= 1; if !isSolid(x, y) { clear = true; break } }
                        if !clear { lem.direction = -lem.direction; change(&lem, .walking); break }
                        y += 1
                    } else {
                        y += 1
                        if !isSolid(x, y) { y += 1 }
                        if !isSolid(x, y) {
                            lem.x = x; change(&lem, .falling); lem.fallDistance = 0; break
                        }
                    }
                    lem.x = x; lem.y = y
                }
            case .clubBashing:
                let phase = (lem.age + 1) % 32
                if (3...9).contains(phase) {
                    let probes = [[(-10,-3),(-1,-3)],[(-10,-3),(-4,-3)],[(-10,-5),(-5,-8)],
                                  [(-9,-9),(-4,-9)],[(-6,-17),(-3,-17)],[(3,-17),(7,-13)],[(10,-7),(10,-3)]]
                    if steelProbe(lem, probes[phase - 3]) { sound(.hitSteel); change(&lem, .walking); break }
                    let offsets = [(-3,8),(-3,6),(-4,5),(-3,3),(5,1),(9,6),(9,8)]
                    let delta = offsets[phase - 3]
                    apply(configuration.terrainMasks.clubBasher[phase - 3 + (lem.direction < 0 ? 7 : 0)],
                          x: lem.x + delta.0 * lem.direction - 8, y: lem.y + delta.1 - 24)
                } else if [18,19,20,21,24,25,28,29].contains(phase) {
                    let x = lem.x + lem.direction
                    var y = lem.y
                    if !isSolid(x, y) && !isSolid(x, y - 1) {
                        y += 1
                        if !isSolid(x, y) { y += 1 }
                        if !isSolid(x, y) { change(&lem, .falling); lem.fallDistance = 0; break }
                    }
                    lem.x = x; lem.y = y
                    if phase == 18 {
                        let probeX = x + (lem.direction > 0 ? 10 : -13)
                        if !(0...3).contains(where: { isSolid(probeX + $0, y - 6) }) { change(&lem, .walking) }
                    }
                }
            case .stomping:
                // PROCESS 6579–65c6: cut on frame 7, then descend two pixels.
                if (lem.age + 1) % 8 == 7 {
                    if steelProbe(lem, [(-3, 0), (3, 0)]) {
                        sound(.hitSteel); change(&lem, .walking)
                    } else if let mask = configuration.terrainMasks.stomper {
                        apply(mask, x: lem.x - 8, y: lem.y - 6)
                        lem.y += 2
                        if !isSolid(lem.x, lem.y) { change(&lem, .falling); lem.fallDistance = 0 }
                    }
                }
            case .digging:
                if (lem.age + 1) % 8 == 0 {
                    apply(configuration.terrainMasks.digger, x: lem.x - 8, y: lem.y - 2)
                    if steelProbe(lem, [(0, 0), (-4, 0), (4, 0)]) { sound(.hitSteel); change(&lem, .walking) }
                    else {
                        lem.y += 1
                        if !(0...4).contains(where: { isSolid(lem.x + $0, lem.y) }) { change(&lem, .falling) }
                    }
                }
            case .bashing:
                let phase = (lem.age + 1) % 32
                if (2...5).contains(phase % 16) {
                    let frame = phase % 16 - 2 + (lem.direction < 0 ? 4 : 0)
                    apply(configuration.terrainMasks.basher[frame], x: lem.x - 7 + lem.direction, y: lem.y - 16)
                    let steel = steelProbe(lem, [(0, -1), (7, -6), (0, -9)])
                    if steel { sound(.hitSteel) }
                    if steel ||
                        (phase == 5 && !(8...10).contains(where: { isSolid(lem.x + $0 * lem.direction, lem.y - 6) })) {
                        change(&lem, .walking)
                    }
                } else if (11...15).contains(phase % 16) {
                    lem.x += lem.direction
                    if let drop = (0...2).first(where: { isSolid(lem.x, lem.y + $0) }) { lem.y += drop }
                    else { lem.y += 3; change(&lem, .falling) }
                }
            case .mining:
                let phase = (lem.age + 1) % 24
                if phase == 1 || phase == 2 {
                    let frame = phase - 1 + (lem.direction < 0 ? 2 : 0)
                    apply(configuration.terrainMasks.miner[frame],
                          x: lem.x - 7 + (phase == 2 ? lem.direction : 0), y: lem.y - 16 + (phase == 2 ? 1 : 0))
                    if steelProbe(lem, [(0, -1), (6, -6), (6, -1)]) { sound(.hitSteel); change(&lem, .walking) }
                } else if phase == 0 { lem.y += 1 }
                else if phase == 3 || phase == 15 {
                    if phase == 3 { lem.y += 1 }
                    lem.x += 2 * lem.direction
                    if !isSolid(lem.x, lem.y) { change(&lem, .falling) }
                }
            case .shrugging:
                if lem.age >= 7 { change(&lem, .walking) }
            case .platformerShrugging:
                if lem.age >= 9 { change(&lem, .walking) }
            case .exploding:
                if lem.age < 15 {
                    for _ in 0..<3 where !isSolid(lem.x, lem.y) { lem.y += 1 }
                } else if lem.age == 15 {
                    sound(.explode)
                    apply(configuration.terrainMasks.exploder, x: lem.x - 8, y: lem.y - 14)
                } else if lem.age >= 68 { lem.state = .dead }
            case .blocking:
                if !isSolid(lem.x, lem.y) { change(&lem, .falling); lem.fallDistance = 0 }
            case .exiting:
                if lem.age + 1 >= configuration.exitFrameCount { lem.state = .saved }
            case .saved, .dead: break
            }
            if lem.state == .falling || ([.jumping,.shimmyJump].contains(lem.state) && lem.fallDistance <= 39) {
                for chain in chains {
                    if let link = chain.catchingLink(x:lem.x,y:lem.y), let position = chain.riderPosition(link:link) {
                        change(&lem, .chainRiding); lem.chainID = chain.id; lem.chainLink = link; lem.air = nil
                        lem.x = position.x; lem.y = position.y; lem.pose = position.pose; break
                    }
                }
            }
            if !configuration.playBounds.contains(lem.x,lem.y) {
                if lem.active { sound(Lemmings2SoundRequest(.fallOut, isBottomFall: lem.y >= configuration.playBounds.y + configuration.playBounds.height)) }; lem.state = .dead
            }
            if lem.state == stateAtStart { lem.age += 1 }
            // PROCESS 03ef/0752 dispatches exit contact after the skill update.
            if lem.active && ![.exiting,.stunned,.trapped,.trapDying].contains(lem.state),
               configuration.exits.contains(where:{$0.contains(lem.x,lem.y)}) {
                change(&lem,.exiting); lem.air = nil
            }
            if !leavingIce && [.walking,.running,.falling,.slipping].contains(lem.state),
               configuration.ice.contains(where:{$0.contains(lem.x,lem.y)}) {
                if lem.skater { lem.y &= ~7; change(&lem, .skating) }
                else if lem.state != .slipping { lem.y &= ~7; change(&lem, .slipping); lem.work = 2; lem.iceDirection = lem.direction }
            }
            if lem.state == .walking && withinAttraction(lem) {
                randomSeed = randomSeed &* 0x05e5 &+ 0x29
                if randomSeed & 0x0c == 0 { change(&lem, .dancing) }
            }
            if lem.active && ![.trapped,.exiting,.exploding,.stunned,.drowning,.dancing,.cannonLoading,.catapultLoading,.teleporting,.switchingValve,.trapDying].contains(lem.state) {
                for machine in machines.indices {
                    if machines[machine].capture(x:lem.x,y:lem.y) {
                        let cannon = machines[machine].kind == .cannon
                        change(&lem,cannon ? .cannonLoading : .catapultLoading)
                        lem.machineID = machines[machine].id; lem.direction = cannon ? 1 : -1; lem.pose = 0; lem.air = nil
                        if !cannon { lem.x -= 1 }
                        break
                    }
                }
            }
            if lem.active && ![.trapped, .exiting, .exploding, .stunned, .drowning,.cannonLoading,.catapultLoading,.teleporting,.switchingValve,.trapDying].contains(lem.state) {
                for object in configuration.interactiveObjects where object.triggers.contains(where: { $0.contains(lem.x, lem.y) }) {
                    if object.kind == .timedTrap {
                        if timedTraps[object.id]?.touch() == true {
                            change(&lem,.trapDying); lem.deathSprite = object.deathSprite; lem.air = nil; break
                        }
                        continue
                    }
                    if object.kind == .valve {
                        guard !busyValves.contains(object.id), let target = configuration.interactiveObjects.first(where:{$0.id == object.linkedID}) else { continue }
                        busyValves.insert(object.id)
                        if activeObjects.contains(target.id) { activeObjects.remove(target.id); objectFrames[target.id] = target.inactiveFrame }
                        else { activeObjects.insert(target.id); objectFrames[target.id] = target.activeFrame }
                        sound(.valve); change(&lem,.switchingValve); lem.interactionID = object.id; lem.air = nil; break
                    }
                    if object.kind == .teleporter {
                        guard let destination = object.linkedID else { continue }
                        lem.restoreMagno = lem.state == .magnoBooting
                        sound(.teleporter); change(&lem,.teleporting); lem.interactionID = destination; lem.pose = 0; lem.air = nil; break
                    }
                    if object.kind == .trampoline {
                        guard !activeObjects.contains(object.id), [.falling, .jumping, .tumbling, .hopping].contains(lem.state) else { continue }
                        activeObjects.insert(object.id); objectFrames[object.id] = 0
                        let segment = lem.x & 15
                        let strength = segment <= 1 || segment >= 14 ? 4 : (segment <= 4 || segment >= 11 ? 5 : 6)
                        let vx = max(-8, min(8, Int(lem.air?.velocityX ?? Int16(2 * lem.direction))
                            + lem.direction * (strength == 4 ? 1 : 2)))
                        if lem.state == .falling { change(&lem, .jumping); lem.y -= 1 }
                        lem.air = try? Lemmings2AirPhysics(x:Int16(lem.x),y:Int16(lem.y),
                            velocityX:Int16(vx),velocityY:Int16(-strength),
                            horizontalCountdown:7,verticalCountdown:strength == 4 ? 1 : 2)
                        lem.fallDistance = 0
                        break
                    }
                    if object.kind == .trap {
                        guard !activeObjects.contains(object.id) else { continue }
                        activeObjects.insert(object.id); objectFrames[object.id] = 1 % object.frameCount
                        change(&lem, .trapped); break
                    }
                    if object.flags & 2 != 0 {
                        guard !activeObjects.contains(object.id) else { continue }
                        activeObjects.insert(object.id); objectFrames[object.id] = 0
                    } else if !activeObjects.contains(object.id) { continue }
                    let vx = object.velocityX * (object.flags & 1 != 0 ? 1 : lem.direction)
                    let delays: [Int8] = [0,0,0,1,1,2,2,3,3]
                    lem.air = try? Lemmings2AirPhysics(x:Int16(lem.x),y:Int16(lem.y),
                        velocityX:Int16(vx),velocityY:Int16(object.velocityY),
                        horizontalCountdown:7,verticalCountdown:delays[abs(object.velocityY)])
                    change(&lem, .tumbling); lem.fallDistance = 0
                    break
                }
            }
            lemmings[index] = lem
            if let blast { applyBlast(x: blast.x, y: blast.y) }
        }
        busyValves = Set(lemmings.filter{$0.state == .switchingValve}.compactMap(\.interactionID))
        advanceRope()
        advanceProjectiles()
        advanceFills()
        // PROCESS 03b0 arms one live lemming after each physics tick.
        if isNuking {
            while nextToNuke < lemmings.count {
                let index = nextToNuke; nextToNuke += 1
                guard lemmings[index].active, lemmings[index].state != .exiting,
                      lemmings[index].state != .exploding, lemmings[index].bombTicks == nil else { continue }
                lemmings[index].bombTicks = 75
                break
            }
        }
        if remainingSeconds == 0 {
            for index in lemmings.indices where lemmings[index].active { lemmings[index].state = .dead }
            isComplete = true
        } else if (released == configuration.total || isNuking) && !lemmings.contains(where: \.active) {
            isComplete = true
        }
    }
}
