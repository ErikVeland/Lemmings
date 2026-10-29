import Foundation

/// A silent solution cursor driven only by the live game's simulation tick.
/// It owns its terrain and commands. It never shares the study replay's cursor.
public struct ClassicSolutionGhost: Sendable {
    public private(set) var simulation: ClassicDOSSimulation
    private let initial: ClassicDOSSimulation
    private let replay: ClassicDOSReplay
    private let events: [Int: [ClassicDOSReplayEvent]]
    private var checkpoints: [Int: ClassicDOSSimulation] = [:]
    private let checkpointInterval = ClassicDOSRules.ticksPerSecond * 10

    public init?(initial: ClassicDOSSimulation, replay: ClassicDOSReplay) {
        guard replay.initialStateHash == ClassicDOSReplayRecorder.stateHash(of: initial),
              replay.events.allSatisfy({ $0.tick >= initial.tickCount && $0.tick <= (replay.expected?.ticks ?? Int.max) }),
              replay.sourceRules != .golemsFallingBuilder || !replay.events.contains(where: {
                  if case .assign = $0.action { return $0.afterTick != true }
                  return false
              }) else { return nil }
        var start = initial
        for event in replay.events where event.afterTick != true {
            if case let .assign(id, skill) = event.action {
                guard start.schedule(.init(tick: event.tick, lemmingID: id, skill: skill)) else { return nil }
            }
        }
        self.replay = replay
        events = Dictionary(grouping: replay.events, by: \.tick)
        simulation = start
        self.initial = start
        applyAfterTick()
        checkpoints[simulation.tickCount] = simulation
    }

    public mutating func synchronise(to liveTick: Int) {
        let target = max(initial.tickCount, min(liveTick, replay.expected?.ticks ?? liveTick))
        if target < simulation.tickCount {
            simulation = checkpoints.filter { $0.key <= target }.max(by: { $0.key < $1.key })?.value ?? initial
        }
        while simulation.tickCount < target, !simulation.isComplete {
            let next = simulation.tickCount + 1
            for event in events[next] ?? [] where event.afterTick != true {
                switch event.action {
                case let .releaseRate(value): simulation.setReleaseRate(value)
                case .nuke: simulation.beginNuke()
                case let .bonusSkill(skill): _ = simulation.grantBonusSkill(skill)
                case .assign: break
                }
            }
            simulation.tick()
            applyAfterTick()
            if simulation.tickCount % checkpointInterval == 0 {
                // Bound memory while retaining the start for arbitrarily long rewinds.
                if checkpoints.count >= 64, let oldest = checkpoints.keys.filter({ $0 != initial.tickCount }).min() {
                    checkpoints.removeValue(forKey: oldest)
                }
                checkpoints[simulation.tickCount] = simulation
            }
        }
    }

    private mutating func applyAfterTick() {
        for event in events[simulation.tickCount] ?? [] where event.afterTick == true {
            switch event.action {
            case let .assign(id, skill):
                if replay.sourceRules == .golemsFallingBuilder { _ = simulation.assignGolemsReplay(skill, to: id) }
                else { _ = simulation.assign(skill, to: id) }
            case let .releaseRate(value): simulation.setReleaseRate(value)
            case .nuke: simulation.beginNuke()
            case let .bonusSkill(skill): _ = simulation.grantBonusSkill(skill)
            }
        }
    }
}

/// Stable roster colours shared by every Hot Seat engine and renderer.
public enum ReplayGhostColour: Int, CaseIterable, Codable, Sendable {
    case blue, pink, orange, green, violet, yellow, red, silver

    public var rgb: (UInt8, UInt8, UInt8) {
        switch self {
        case .blue: (105, 220, 255)
        case .pink: (255, 120, 220)
        case .orange: (255, 165, 70)
        case .green: (95, 255, 145)
        case .violet: (180, 135, 255)
        case .yellow: (245, 240, 80)
        case .red: (255, 100, 100)
        case .silver: (210, 220, 230)
        }
    }
}

/// A sharp, translucent silhouette with a separate outline. No terrain pixels.
public struct SolutionGhostPixels: Sendable {
    public let rgba: Data
    public let width: Int
    public let height: Int
    public let padding: Int

    public init(rgba source: Data, width: Int, height: Int, pixelScale: Int = 1, colour: ReplayGhostColour = .blue) {
        padding = max(1, pixelScale)
        self.width = width + padding * 2
        self.height = height + padding * 2
        var pixels = [UInt8](repeating: 0, count: self.width * self.height * 4)
        func solid(_ x: Int, _ y: Int) -> Bool {
            x >= 0 && x < width && y >= 0 && y < height && source[(y * width + x) * 4 + 3] > 0
        }
        if source.count == width * height * 4 {
            for y in -padding..<(height + padding) { for x in -padding..<(width + padding) {
                let inside = solid(x, y)
                let edge = !inside && (solid(x - padding, y) || solid(x + padding, y)
                    || solid(x, y - padding) || solid(x, y + padding))
                guard inside || edge else { continue }
                let offset = ((y + padding) * self.width + x + padding) * 4
                let (r, g, b) = colour.rgb
                pixels[offset] = edge ? UInt8(min(255, Int(r) + 80)) : r
                pixels[offset + 1] = g
                pixels[offset + 2] = b
                pixels[offset + 3] = edge ? 110 : 50
            } }
        }
        rgba = Data(pixels)
    }
}
