import Foundation

/// Experimental native L2 runtime. This is not the L1 simulation.
/// Terrain skill masks and action phases follow the original PROCESS overlay.
/// Other behaviour still requires original-engine trace testing.
public struct Lemmings2Runtime: Sendable {
    public enum Skill: Int, CaseIterable, Sendable {
        case digger = 17, climber = 18, builder = 19, basher = 20
        case miner = 21, floater = 22, bomber = 24, blocker = 51
        case stacker = 31, platformer = 34
        public var name: String { self == .bomber ? "Exploder" : String(describing: self).capitalized }
    }
    public enum State: String, Sendable {
        case walking, falling, floating, climbing, building, bashing, mining, digging, blocking
        case stacking, platforming, platformerShrugging
        case shrugging, exploding, exiting, saved, dead
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
        public var climber = false
        public var floater = false
        public var bombTicks: Int?
        public var active: Bool { state != .dead && state != .saved }
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
        public let width: Int
        public let height: Int
        public let pixels: [UInt8]
        public let solid: [Bool]
        public let palette: [UInt8]
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
        public let fireHazards: [Rect]
        public let terrainMasks: Lemmings2TerrainMasks
        public init(width: Int, height: Int, pixels: [UInt8], solid: [Bool], palette: [UInt8],
                    entrance: Rect, exits: [Rect], skills: [Skill], supplies: [Int], total: Int,
                    timeLimit: Int, releaseInterval: Int, terrainMasks: Lemmings2TerrainMasks, firstReleaseTick: Int = 35,
                    steel: [Bool] = [], hazards: [Rect] = [], levelFingerprint: String? = nil,
                    fireHazards: [Rect] = []) {
            self.width = width; self.height = height; self.pixels = pixels; self.solid = solid
            self.palette = palette; self.entrance = entrance; self.exits = exits
            self.skills = skills; self.supplies = supplies; self.total = total
            self.timeLimit = timeLimit; self.releaseInterval = releaseInterval
            self.firstReleaseTick = firstReleaseTick
            self.levelFingerprint = levelFingerprint
            self.steel = steel.isEmpty ? [Bool](repeating: false, count: pixels.count) : steel
            self.hazards = hazards
            self.fireHazards = fireHazards
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
    private var nextToNuke = 0
    private var soundEvents: [Lemmings2SoundRequest] = []
    public mutating func drainSoundEvents() -> [Lemmings2SoundRequest] {
        let events = soundEvents; soundEvents.removeAll(keepingCapacity: true); return events
    }
    private mutating func sound(_ cue: Lemmings2SoundCue) {
        // Headless runs need not consume audio. Bound their pending queue.
        if soundEvents.count < 256 { soundEvents.append(Lemmings2SoundRequest(cue)) }
    }
    public var saved: Int { lemmings.filter { $0.state == .saved }.count }
    public var lost: Int { lemmings.filter { $0.state == .dead }.count }
    // L2.RKO 034b and 0694: the displayed second is fifteen simulation ticks,
    // even though the engine runs at 17.5 ticks per real second.
    public var remainingSeconds: Int { max(0, configuration.timeLimit - tick / 15) }
    public var didWin: Bool { isComplete && saved > 0 }
    public static let ticksPerSecond = 17.5

    public init(configuration c: Configuration) throws {
        guard c.width > 0, c.height > 0, c.width <= 4096, c.height <= 4096,
              c.width * c.height <= 4_194_304, c.pixels.count == c.width * c.height,
              c.solid.count == c.pixels.count, c.steel.count == c.pixels.count, c.palette.count == 1024,
              c.skills.count == c.supplies.count, c.supplies.allSatisfy({ $0 >= 0 }),
              c.total > 0, c.total <= 1000, c.timeLimit > 0, c.timeLimit <= 3600,
              c.releaseInterval > 0, c.releaseInterval <= 1000,
              c.firstReleaseTick > 0, c.firstReleaseTick <= 2000,
              c.entrance.x >= 0, c.entrance.x < c.width, c.entrance.y >= 0, c.entrance.y < c.height,
              !c.exits.isEmpty else {
            throw SequelDataError.invalid("Invalid native L2 runtime configuration.")
        }
        configuration = c; pixels = c.pixels; solid = c.solid; supplies = c.supplies
    }

    /// Only simple Classic objects are supported by this initial runtime.
    public init(level: Lemmings2Level, style: Lemmings2Style, masks: Lemmings2TerrainMasks, total: Int = 60) throws {
        guard level.style == 0 else { throw SequelDataError.invalid("This tribe is not playable yet. Only Classic currently has a complete set of supported skills and objects.") }
        let terrain = try Lemmings2Terrain(level: level, style: style)
        let objects = try Lemmings2Objects(level: level, style: style)
        var pixels = terrain.image.pixels, solid = terrain.solid
        var steel = [Bool](repeating: false, count: pixels.count)
        var entrance: Rect?
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
                guard entrance == nil else { throw SequelDataError.invalid("Multiple entrances are not supported by this preview.") }
                entrance = Rect(x: placed.x - 16 + object.parameters[0], y: placed.y - 16 + object.parameters[1], width: 1, height: 1)
            case 3, 5, 6, 11: break
            default:
                throw SequelDataError.invalid("Object type \(object.type) is not yet supported by the native preview.")
            }
        }
        for part in objects.parts where part.component.solidity & 0x10 != 0 {
            guard let frame = part.frames.first else { continue }
            for y in 0..<frame.height { for x in 0..<frame.width {
                let px = part.x + frame.x + x, py = part.y + frame.y + y
                guard px >= 0, py >= 0, px < terrain.image.width, py < terrain.image.height else { continue }
                let colour = frame.pixels[y * frame.width + x]
                if colour != 0 {
                    let index = py * terrain.image.width + px
                    pixels[index] = colour; solid[index] = true; steel[index] = true
                }
            } }
        }
        guard let entrance else { throw SequelDataError.invalid("No entrance in the native L2 level.") }
        let skills = try level.skills.map { slot -> Skill in
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
            exits: exits, skills: skills, supplies: level.skills.map(\.count), total: total,
            timeLimit: level.timeLimitSeconds, releaseInterval: releaseInterval,
            terrainMasks: masks, firstReleaseTick: 30 + releaseInterval, steel: steel, hazards: hazards,
            levelFingerprint: level.fingerprint,
            fireHazards: objects.parts.filter { $0.type == 11 }.compactMap(\.trigger)))
    }

    public func isSolid(_ x: Int, _ y: Int) -> Bool {
        x >= 0 && x < configuration.width && y >= 0 && y < configuration.height && solid[y * configuration.width + x]
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
        lemming.state = state; lemming.age = 0; lemming.work = 0
    }
    public func canAssign(slot: Int, to id: Int) -> Bool {
        guard !isComplete, !isNuking, supplies.indices.contains(slot), supplies[slot] > 0,
              let lem = lemmings.first(where: { $0.id == id && $0.active }),
              lem.state != .exiting, lem.state != .exploding else { return false }
        switch configuration.skills[slot] {
        case .climber: return !lem.climber
        case .floater: return !lem.floater
        case .bomber: return lem.bombTicks == nil
        default:
            let states: [Skill: State] = [.builder: .building, .basher: .bashing, .miner: .mining,
                .digger: .digging, .blocker: .blocking, .stacker: .stacking, .platformer: .platforming]
            return [.walking, .building, .bashing, .mining, .digging, .shrugging,
                    .stacking, .platforming, .platformerShrugging].contains(lem.state) && states[configuration.skills[slot]] != lem.state
        }
    }
    /// Hover and click use the same stable, eligible-first target selection.
    public func target(slot: Int, x: Int, y: Int) -> Lemming? {
        lemmings.filter { $0.active && $0.state != .exiting && $0.state != .exploding &&
            abs($0.x - x) <= 9 && abs($0.y - 5 - y) <= 12 }.min { a, b in
                let eligibleA = canAssign(slot: slot, to: a.id), eligibleB = canAssign(slot: slot, to: b.id)
                if eligibleA != eligibleB { return eligibleA }
                let da = abs(a.x - x) + abs(a.y - 5 - y), db = abs(b.x - x) + abs(b.y - 5 - y)
                return da == db ? a.id < b.id : da < db
            }
    }
    @discardableResult public mutating func assign(slot: Int, to id: Int) -> Bool {
        guard canAssign(slot: slot, to: id), let index = lemmings.firstIndex(where: { $0.id == id }) else { return false }
        var lem = lemmings[index]
        switch configuration.skills[slot] {
        case .climber:
            guard !lem.climber else { return false }; lem.climber = true
        case .floater:
            guard !lem.floater else { return false }; lem.floater = true
        case .bomber:
            guard lem.bombTicks == nil else { return false }; lem.bombTicks = 75
        default:
            guard [.walking, .building, .bashing, .mining, .digging, .shrugging,
                   .stacking, .platforming, .platformerShrugging].contains(lem.state) else { return false }
            let state: State
            switch configuration.skills[slot] {
            case .builder: state = .building
            case .basher: state = .bashing
            case .miner: state = .mining
            case .digger: state = .digging
            case .blocker: state = .blocking
            case .stacker: state = .stacking
            case .platformer: state = .platforming
            default: return false
            }
            guard lem.state != state else { return false }
            let previous = lem.state
            change(&lem, state)
            if state == .stacking {
                lem.work = 12
                // The stacker alternates facing within one 32-frame bank.
                if lem.direction < 0 { lem.age = 16 }
            } else if state == .platforming {
                lem.work = previous == .platformerShrugging ? 12 : 11
                if previous == .platformerShrugging { lem.age = 21 }
            }
        }
        supplies[slot] -= 1; lemmings[index] = lem
        sound(.assignSkill)
        return true
    }
    public mutating func nuke() {
        guard !isComplete, !isNuking else { return }
        isNuking = true
        nextToNuke = 0
    }

    public mutating func step() {
        guard !isComplete else { return }
        tick += 1
        if tick == 6 { sound(.levelStart) }
        if tick == 21 { sound(.doorOpen) }
        if !isNuking && released < configuration.total && tick >= configuration.firstReleaseTick &&
            (tick - configuration.firstReleaseTick) % configuration.releaseInterval == 0 {
            lemmings.append(Lemming(id: released, x: configuration.entrance.x, y: configuration.entrance.y))
            released += 1
        }
        for index in lemmings.indices where lemmings[index].active {
            var lem = lemmings[index]
            if let countdown = lem.bombTicks {
                lem.bombTicks = countdown - 1
                if countdown <= 1 {
                    lem.bombTicks = nil
                    change(&lem, .exploding)
                }
            }
            if configuration.hazards.contains(where: { $0.contains(lem.x, lem.y) }) && lem.state != .exiting {
                sound(configuration.fireHazards.contains(where: { $0.contains(lem.x, lem.y) }) ? .fire : .drown)
                lem.state = .dead; lemmings[index] = lem; continue
            }
            if configuration.exits.contains(where: { $0.contains(lem.x, lem.y) }) &&
                (lem.state == .walking || lem.state == .building) { change(&lem, .exiting) }
            let stateAtStart = lem.state
            switch lem.state {
            case .falling, .floating:
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
            case .walking:
                let nx = lem.x + lem.direction
                if lemmings.contains(where: { $0.id != lem.id && $0.state == .blocking &&
                    abs($0.y - lem.y) <= 4 && abs($0.x - nx) <= 6 && ($0.x - lem.x) * lem.direction > 0 }) {
                    lem.direction = -lem.direction
                } else if isSolid(nx, lem.y - 1) {
                    if let rise = (1...4).first(where: { !isSolid(nx, lem.y - $0 - 1) && isSolid(nx, lem.y - $0) }) {
                        lem.x = nx; lem.y -= rise
                    } else if lem.climber { change(&lem, .climbing) }
                    else { lem.direction = -lem.direction }
                } else {
                    lem.x = nx
                    if let drop = (0...3).first(where: { isSolid(nx, lem.y + $0) }) { lem.y += drop }
                    else { lem.y += 3; change(&lem, .falling); lem.fallDistance = 0 }
                }
            case .climbing:
                if isSolid(lem.x, lem.y - 9) { lem.direction = -lem.direction; change(&lem, .falling) }
                else if !isSolid(lem.x + lem.direction, lem.y - 7) {
                    lem.x += lem.direction * 2; lem.y -= 7; change(&lem, .walking)
                } else { lem.y -= 1 }
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
                if lem.age >= 8 { lem.state = .saved }
            case .saved, .dead: break
            }
            if lem.x < 0 || lem.x >= configuration.width || lem.y >= configuration.height || lem.y < -16 {
                if lem.active { sound(.fallOut) }; lem.state = .dead
            }
            if lem.state == stateAtStart { lem.age += 1 }
            lemmings[index] = lem
        }
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
