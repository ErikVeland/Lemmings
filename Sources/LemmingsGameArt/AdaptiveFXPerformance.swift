import Foundation
import Metal

/// Capabilities choose a starting point. Sustained measurements choose quality.
public struct FXDeviceProfile: Sendable {
    public let initialQuality: FXQuality
    public let maximumQuality: FXQuality
    public let supportsEnhancedEffects: Bool
    public let maximumOverlayPixels: Int

    public init(hasMetal: Bool, modernGPU: Bool, enhancedEffectsSupported: Bool,
                processorCount: Int, recommendedWorkingSet: UInt64) {
        maximumQuality = hasMetal ? .full : .minimal
        supportsEnhancedEffects = hasMetal && enhancedEffectsSupported
        initialQuality = !hasMetal || processorCount <= 2 ? .minimal : (modernGPU ? .full : .balanced)
        // Reserve capacity for simultaneous surfaces, textures and the game itself.
        let pixels = recommendedWorkingSet > 0 ? recommendedWorkingSet / 64 : 1_048_576
        maximumOverlayPixels = Int(min(8_388_608, max(262_144, pixels)))
    }

    public static func detect(device: MTLDevice?, mobile: Bool) -> Self {
        let cores = ProcessInfo.processInfo.processorCount
        return Self(hasMetal: device != nil, modernGPU: device?.supportsFamily(.apple7) == true,
                    enhancedEffectsSupported: !mobile || (cores > 2 && device?.supportsFamily(.apple4) == true),
                    processorCount: cores, recommendedWorkingSet: device?.recommendedMaxWorkingSetSize ?? 0)
    }
}

/// Soft effects scale independently of the sharp playfield and selection outline.
public struct FXPresentationBudget: Sendable {
    public let cpuQuality: FXQuality
    public let gpuQuality: FXQuality
    public let framesPerSecond: Double
    public let maximumOverlayPixels: Int

    public var quality: FXQuality { FXQuality(rawValue: min(cpuQuality.rawValue, gpuQuality.rawValue))! }
    public var bloomScale: Double { gpuQuality.bloomScale }
    public var overlayScale: Double { gpuQuality.overlayScale }
    public var effectHz: Double { min(framesPerSecond, quality.effectHz) }
    public var trailLimit: Int { cpuQuality.trailLimit }
    public var trailEchoLimit: Int { cpuQuality.trailEchoLimit }
    public var explosionLimit: Int { gpuQuality.explosionLimit }

    public init(cpuQuality: FXQuality, gpuQuality: FXQuality, framesPerSecond: Double = 60,
                maximumOverlayPixels: Int = 8_388_608) {
        self.cpuQuality = cpuQuality; self.gpuQuality = gpuQuality
        self.framesPerSecond = framesPerSecond.isFinite ? max(1, min(60, framesPerSecond)) : 60
        self.maximumOverlayPixels = max(1, maximumOverlayPixels)
    }

    public func overlayRenderScale(width: Double, height: Double, nativeScale: Double) -> Double {
        guard width.isFinite, height.isFinite, nativeScale.isFinite,
              width > 0, height > 0, nativeScale > 0 else { return 1 }
        return min(nativeScale * overlayScale, sqrt(Double(maximumOverlayPixels) / width / height))
    }
}

/// One policy for Mac, iPhone and iPad, also usable by a future tvOS adapter.
public struct AdaptiveFXPerformance: Sendable {
    public let profile: FXDeviceProfile
    public private(set) var cpu: AdaptiveFXQuality
    public private(set) var gpu: AdaptiveFXQuality
    private var ceiling: FXQuality
    private var framesPerSecond: Double = 60
    private var cpuCosts: [String: (seconds: Double, at: Double)] = [:]
    private var gpuCosts: [String: (seconds: Double, at: Double)] = [:]

    public init(profile: FXDeviceProfile) {
        self.profile = profile; ceiling = profile.maximumQuality
        cpu = AdaptiveFXQuality(initial: profile.initialQuality)
        gpu = AdaptiveFXQuality(initial: profile.initialQuality)
    }

    public var presentation: FXPresentationBudget {
        FXPresentationBudget(cpuQuality: cpu.quality, gpuQuality: gpu.quality,
                             framesPerSecond: framesPerSecond, maximumOverlayPixels: profile.maximumOverlayPixels)
    }

    public mutating func setPressure(ceiling: FXQuality, framesPerSecond: Double, now: Double) {
        guard now.isFinite, framesPerSecond.isFinite, framesPerSecond > 0 else { return }
        self.ceiling = FXQuality(rawValue: min(profile.maximumQuality.rawValue, ceiling.rawValue))!
        self.framesPerSecond = min(60, framesPerSecond)
        cpu.restrict(to: self.ceiling, now: now); gpu.restrict(to: self.ceiling, now: now)
    }

    public mutating func recordCPU(_ seconds: Double, source: String = "frame", now: Double) {
        guard seconds.isFinite, seconds >= 0, now.isFinite else { return }
        cpuCosts = cpuCosts.filter { now >= $0.value.at && now - $0.value.at < 0.5 }
        cpuCosts[source] = (seconds, now)
        cpu.observe(cpuSeconds: cpuCosts.values.reduce(0) { $0 + $1.seconds }, gpuSeconds: 0, now: now,
                    ceiling: ceiling, framesPerSecond: framesPerSecond)
    }

    public mutating func recordGPU(_ seconds: Double, source: String, now: Double) {
        guard seconds.isFinite, seconds >= 0, now.isFinite else { return }
        // Completion samples are estimates of active surface cost, not end-to-end latency.
        gpuCosts = gpuCosts.filter { now >= $0.value.at && now - $0.value.at < 0.5 }
        gpuCosts[source] = (seconds, now)
        gpu.observe(cpuSeconds: 0, gpuSeconds: gpuCosts.values.reduce(0) { $0 + $1.seconds }, now: now,
                    ceiling: ceiling, framesPerSecond: framesPerSecond)
    }
}
