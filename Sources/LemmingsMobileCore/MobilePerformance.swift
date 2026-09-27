import Foundation

public enum MobileThermalLevel: String, Codable, CaseIterable, Sendable {
    case nominal
    case fair
    case serious
    case critical
}

public struct MobilePerformanceBudget: Codable, Equatable, Sendable {
    public let framesPerSecond: Int
    public let presentsMotionEffects: Bool
    public let presentsFlashEffects: Bool
    public let preloadsAdjacentLevels: Bool
    public let audioVoiceLimit: Int
    public let maximumCatchUpTicks: Int

    public init(
        framesPerSecond: Int,
        presentsMotionEffects: Bool,
        presentsFlashEffects: Bool,
        preloadsAdjacentLevels: Bool,
        audioVoiceLimit: Int,
        maximumCatchUpTicks: Int
    ) {
        self.framesPerSecond = framesPerSecond
        self.presentsMotionEffects = presentsMotionEffects
        self.presentsFlashEffects = presentsFlashEffects
        self.preloadsAdjacentLevels = preloadsAdjacentLevels
        self.audioVoiceLimit = audioVoiceLimit
        self.maximumCatchUpTicks = maximumCatchUpTicks
    }
}

public enum MobileThermalPolicy {
    /// Reduces presentation work only. Simulation ticks keep their authored rate.
    public static func budget(
        for level: MobileThermalLevel,
        lowPowerMode: Bool,
        reduceMotion: Bool,
        reduceFlashes: Bool
    ) -> MobilePerformanceBudget {
        let base: MobilePerformanceBudget
        switch level {
        case .nominal:
            base = MobilePerformanceBudget(
                framesPerSecond: 60,
                presentsMotionEffects: true,
                presentsFlashEffects: true,
                preloadsAdjacentLevels: true,
                audioVoiceLimit: 24,
                maximumCatchUpTicks: 8
            )
        case .fair:
            base = MobilePerformanceBudget(
                framesPerSecond: 45,
                presentsMotionEffects: true,
                presentsFlashEffects: true,
                preloadsAdjacentLevels: false,
                audioVoiceLimit: 16,
                maximumCatchUpTicks: 6
            )
        case .serious:
            base = MobilePerformanceBudget(
                framesPerSecond: 30,
                presentsMotionEffects: false,
                presentsFlashEffects: false,
                preloadsAdjacentLevels: false,
                audioVoiceLimit: 10,
                maximumCatchUpTicks: 4
            )
        case .critical:
            base = MobilePerformanceBudget(
                framesPerSecond: 20,
                presentsMotionEffects: false,
                presentsFlashEffects: false,
                preloadsAdjacentLevels: false,
                audioVoiceLimit: 6,
                maximumCatchUpTicks: 2
            )
        }
        return MobilePerformanceBudget(
            framesPerSecond: lowPowerMode ? min(30, base.framesPerSecond) : base.framesPerSecond,
            presentsMotionEffects: base.presentsMotionEffects && !reduceMotion && !lowPowerMode,
            presentsFlashEffects: base.presentsFlashEffects && !reduceFlashes && !lowPowerMode,
            preloadsAdjacentLevels: base.preloadsAdjacentLevels && !lowPowerMode,
            audioVoiceLimit: lowPowerMode ? min(12, base.audioVoiceLimit) : base.audioVoiceLimit,
            maximumCatchUpTicks: base.maximumCatchUpTicks
        )
    }
}

public struct MobileTickClock: Equatable, Sendable {
    public var ticksPerSecond: Double
    public var speed: Double
    public var maximumCatchUpTicks: Int
    private var lastTime: Double?
    private var accumulator = 0.0

    public init(ticksPerSecond: Double, speed: Double = 1, maximumCatchUpTicks: Int = 8) {
        self.ticksPerSecond = max(1, ticksPerSecond)
        self.speed = max(0.1, speed)
        self.maximumCatchUpTicks = max(1, maximumCatchUpTicks)
    }

    public mutating func advance(at time: Double) -> Int {
        guard time.isFinite else { return 0 }
        guard let previous = lastTime else {
            lastTime = time
            return 0
        }
        lastTime = time
        let elapsed = min(0.25, max(0, time - previous))
        accumulator += elapsed * speed
        let duration = 1 / ticksPerSecond
        let boundaryTolerance = duration * 1e-9
        let available = Int((accumulator + boundaryTolerance) / duration)
        let ticks = min(maximumCatchUpTicks, available)
        accumulator = max(0, accumulator - Double(ticks) * duration)
        if available > maximumCatchUpTicks {
            accumulator = min(accumulator, duration)
        }
        return ticks
    }

    public mutating func suspend() {
        lastTime = nil
        accumulator = 0
    }
}
