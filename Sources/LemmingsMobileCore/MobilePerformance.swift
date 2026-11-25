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
        reduceFlashes: Bool,
        constrainedDevice: Bool = false
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
            framesPerSecond: lowPowerMode || constrainedDevice ? min(30, base.framesPerSecond) : base.framesPerSecond,
            presentsMotionEffects: base.presentsMotionEffects && !reduceMotion && !lowPowerMode,
            presentsFlashEffects: base.presentsFlashEffects && !reduceFlashes && !lowPowerMode,
            preloadsAdjacentLevels: base.preloadsAdjacentLevels && !lowPowerMode,
            audioVoiceLimit: lowPowerMode ? min(12, base.audioVoiceLimit) : base.audioVoiceLimit,
            maximumCatchUpTicks: constrainedDevice ? min(4, base.maximumCatchUpTicks) : base.maximumCatchUpTicks
        )
    }
}

/// Changes presentation cadence only. Engine clocks retain their authored tick rate.
public struct MobileFramePacing: Sendable {
    public private(set) var framesPerSecond: Int
    private var maximumFramesPerSecond: Int
    private var lastTime: Double?
    private var pressureSince: Double?
    private var spareSince: Double?
    private var smoothedWork = 0.0
    private var missedFraction = 0.0

    public init(maximumFramesPerSecond: Int = 60) {
        let rate = Self.rate(below: maximumFramesPerSecond)
        self.maximumFramesPerSecond = rate
        framesPerSecond = rate
    }

    public mutating func setMaximumFramesPerSecond(_ maximum: Int) {
        maximumFramesPerSecond = Self.rate(below: maximum)
        if framesPerSecond > maximumFramesPerSecond {
            framesPerSecond = maximumFramesPerSecond
            resetSamples()
        }
    }

    public mutating func observe(at time: Double, cpuSeconds: Double, gpuSeconds: Double, active: Bool) {
        guard time.isFinite, cpuSeconds.isFinite, gpuSeconds.isFinite,
              cpuSeconds >= 0, gpuSeconds >= 0 else { return }
        guard active else { resetSamples(); return }
        let previous = lastTime
        lastTime = time
        guard let previous else { return }
        let elapsed = time - previous
        guard elapsed > 0, elapsed <= 0.25 else {
            resetSamples(); lastTime = time
            return
        }
        let interval = 1 / Double(framesPerSecond)
        let blend = 1 - exp(-elapsed / 0.5)
        smoothedWork += (max(cpuSeconds, gpuSeconds) - smoothedWork) * blend
        missedFraction += ((elapsed > interval * 1.4 ? 1.0 : 0.0) - missedFraction) * blend
        if smoothedWork > interval * 0.82 || missedFraction > 0.2 {
            spareSince = nil
            if pressureSince == nil { pressureSince = time }
            if time - pressureSince! >= 3, framesPerSecond > 20 {
                framesPerSecond = framesPerSecond > 30 ? 30 : 20
                resetSamples()
            }
        } else if smoothedWork < interval * 0.35 && missedFraction < 0.02 {
            pressureSince = nil
            if spareSince == nil { spareSince = time }
            let higher = framesPerSecond < 30 ? 30 : 60
            // Recovery must also have capacity at the higher rate.
            if time - spareSince! >= 12, higher <= maximumFramesPerSecond,
               smoothedWork < 0.55 / Double(higher) {
                framesPerSecond = higher
                resetSamples()
            }
        } else { pressureSince = nil; spareSince = nil }
    }

    private static func rate(below maximum: Int) -> Int {
        // Whole divisors avoid an uneven 45 Hz cadence on a 60 Hz panel.
        maximum >= 60 ? 60 : (maximum >= 30 ? 30 : 20)
    }

    private mutating func resetSamples() {
        lastTime = nil; pressureSince = nil; spareSince = nil
        smoothedWork = 0; missedFraction = 0
    }
}

public struct MobileTickClock: Equatable, Sendable {
    private static let maximumDelay = 0.25
    public var ticksPerSecond: Double
    public var speed: Double {
        didSet {
            if speed < oldValue {
                let duration = 1 / ticksPerSecond
                accumulator = accumulator.truncatingRemainder(dividingBy: duration)
                if accumulator >= duration * (1 - 1e-9) { accumulator = 0 }
            }
        }
    }
    public var maximumCatchUpTicks: Int
    public private(set) var lastAdvanceElapsed = 0.0
    private var lastTime: Double?
    private var accumulator = 0.0

    public init(ticksPerSecond: Double, speed: Double = 1, maximumCatchUpTicks: Int = 8) {
        self.ticksPerSecond = max(1, ticksPerSecond)
        self.speed = max(0.1, speed)
        self.maximumCatchUpTicks = max(1, maximumCatchUpTicks)
    }

    public mutating func advance(at time: Double) -> Int {
        lastAdvanceElapsed = 0
        guard time.isFinite else { return 0 }
        guard let previous = lastTime else {
            lastTime = time
            return 0
        }
        // A queued display callback can predate the completed Resume frame.
        guard time >= previous else { return 0 }
        lastTime = time
        lastAdvanceElapsed = time - previous
        let elapsed = min(Self.maximumDelay, lastAdvanceElapsed)
        accumulator = min(accumulator + elapsed * speed, maximumCredit)
        let duration = 1 / ticksPerSecond
        let boundaryTolerance = duration * 1e-9
        let available = Int((accumulator + boundaryTolerance) / duration)
        let ticks = min(maximumCatchUpTicks, available)
        accumulator = max(0, accumulator - Double(ticks) * duration)
        return ticks
    }

    public mutating func suspend() {
        lastTime = nil
        lastAdvanceElapsed = 0
        accumulator = 0
    }

    /// Start timing after the frozen Resume frame has finished its presentation work.
    public mutating func resume(at time: Double) {
        suspend()
        if time.isFinite { lastTime = time }
    }

    /// Retains ticks admitted by the clock when the current frame exhausts its CPU budget.
    public mutating func deferTicks(_ ticks: Int) {
        guard ticks > 0 else { return }
        accumulator = min(accumulator + Double(ticks) / ticksPerSecond, maximumCredit)
    }

    private var maximumCredit: Double { Self.maximumDelay * speed + 1 / ticksPerSecond }
}
