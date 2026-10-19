import Foundation
import Metal
#if canImport(NxlvKit)
import NxlvKit
#endif

/// Capabilities choose a starting point. Sustained measurements choose quality.
public struct FXDeviceProfile: Sendable {
    public let initialQuality: FXQuality
    public let maximumQuality: FXQuality
    public let supportsEnhancedEffects: Bool
    public let maximumOverlayPixels: Int

    public init(hasMetal: Bool, modernGPU: Bool, enhancedEffectsSupported: Bool,
                processorCount: Int, recommendedWorkingSet: UInt64, television: Bool = false,
                physicalMemory: UInt64 = .max) {
        let resources = DeviceEffectResources(physicalMemory: physicalMemory, processorCount: processorCount)
        maximumQuality = hasMetal ? FXQuality(rawValue: resources.qualityCeiling)! : .minimal
        // TV omits the extra full-screen speed and cinematic explosion surface.
        supportsEnhancedEffects = hasMetal && enhancedEffectsSupported && resources.enhancedEffectsAllowed && !television
        let seed: FXQuality = !hasMetal || processorCount <= 2 ? .minimal : (modernGPU && !television ? .full : .balanced)
        initialQuality = FXQuality(rawValue: min(seed.rawValue, maximumQuality.rawValue))!
        // Reserve capacity for simultaneous surfaces, textures and the game itself.
        let pixels = recommendedWorkingSet > 0 ? recommendedWorkingSet / 64 : 1_048_576
        maximumOverlayPixels = min(resources.maximumOverlayPixels, Int(min(television ? 720_000 : 8_388_608, max(262_144, pixels))))
    }

    public static func detect(device: MTLDevice?, mobile: Bool, television: Bool = false) -> Self {
        let cores = ProcessInfo.processInfo.processorCount
        #if targetEnvironment(simulator)
        let simulator = true
        #else
        let simulator = false
        #endif
        return Self(hasMetal: device != nil, modernGPU: device?.supportsFamily(.apple7) == true,
                    enhancedEffectsSupported: allowsEnhancedEffects(hasMetal: device != nil, mobile: mobile,
                        processorCount: cores, supportsApple4: device?.supportsFamily(.apple4) == true, simulator: simulator),
                    processorCount: cores, recommendedWorkingSet: device?.recommendedMaxWorkingSetSize ?? 0,
                    television: television, physicalMemory: ProcessInfo.processInfo.physicalMemory)
    }

    /// Simulator exposes an Apple 2-like translation layer, not the named phone's GPU.
    static func allowsEnhancedEffects(hasMetal: Bool, mobile: Bool, processorCount: Int,
                                      supportsApple4: Bool, simulator: Bool) -> Bool {
        hasMetal && (!mobile || (processorCount > 2 && (supportsApple4 || simulator)))
    }
}

/// Soft effects scale independently of the sharp playfield and selection outline.
public struct FXPresentationBudget: Sendable {
    public let cpuQuality: FXQuality
    public let gpuQuality: FXQuality
    public let framesPerSecond: Double
    public let maximumOverlayPixels: Int
    public let enhancedEffectsAllowed: Bool
    public var bloomAllowed: Bool { quality != .minimal }

    public var quality: FXQuality { FXQuality(rawValue: min(cpuQuality.rawValue, gpuQuality.rawValue))! }
    public var bloomScale: Double { gpuQuality.bloomScale }
    public var overlayScale: Double { gpuQuality.overlayScale }
    public var effectHz: Double { min(framesPerSecond, quality.effectHz) }
    public var trailLimit: Int { cpuQuality.trailLimit }
    public var trailEchoLimit: Int { cpuQuality.trailEchoLimit }
    public var explosionLimit: Int { gpuQuality.explosionLimit }
    /// TV keeps native menu/HUD lettering without a 4K floating-point playfield.
    public func televisionPlayfieldScale(nativeScale: Double) -> Double {
        guard nativeScale.isFinite, nativeScale > 0 else { return 1 }
        return min(1, nativeScale)
    }
    /// Drop optional bloom under pressure or when presentation cannot sustain 60 Hz.
    public var televisionBloomAllowed: Bool { quality != .minimal && framesPerSecond >= 60 }

    public init(cpuQuality: FXQuality, gpuQuality: FXQuality, framesPerSecond: Double = 60,
                maximumOverlayPixels: Int = 8_388_608, enhancedEffectsAllowed: Bool = true) {
        self.cpuQuality = cpuQuality; self.gpuQuality = gpuQuality
        self.framesPerSecond = framesPerSecond.isFinite ? max(1, min(60, framesPerSecond)) : 60
        self.maximumOverlayPixels = max(1, maximumOverlayPixels)
        self.enhancedEffectsAllowed = enhancedEffectsAllowed && min(cpuQuality.rawValue, gpuQuality.rawValue) > FXQuality.minimal.rawValue
    }

    public func overlayRenderScale(width: Double, height: Double, nativeScale: Double) -> Double {
        guard width.isFinite, height.isFinite, nativeScale.isFinite,
              width > 0, height > 0, nativeScale > 0 else { return 1 }
        return min(nativeScale * overlayScale, sqrt(Double(maximumOverlayPixels) / width / height))
    }
}

/// One policy for Mac, iPhone, iPad and Apple TV.
public struct AdaptiveFXPerformance: Sendable {
    public let profile: FXDeviceProfile
    public private(set) var cpu: AdaptiveFXQuality
    public private(set) var gpu: AdaptiveFXQuality
    private var ceiling: FXQuality
    private var framesPerSecond: Double = 60
    private var maximumOverlayPixels: Int
    private var enhancedEffectsAllowed: Bool
    private var cpuCosts: [String: (seconds: Double, at: Double)] = [:]
    private var gpuCosts: [String: (seconds: Double, at: Double)] = [:]

    public init(profile: FXDeviceProfile) {
        self.profile = profile; ceiling = profile.maximumQuality
        maximumOverlayPixels = profile.maximumOverlayPixels
        enhancedEffectsAllowed = profile.supportsEnhancedEffects
        cpu = AdaptiveFXQuality(initial: profile.initialQuality)
        gpu = AdaptiveFXQuality(initial: profile.initialQuality)
    }

    public var presentation: FXPresentationBudget {
        FXPresentationBudget(cpuQuality: cpu.quality, gpuQuality: gpu.quality,
                             framesPerSecond: framesPerSecond, maximumOverlayPixels: maximumOverlayPixels,
                             enhancedEffectsAllowed: enhancedEffectsAllowed)
    }

    public mutating func setPressure(ceiling: FXQuality, framesPerSecond: Double, now: Double,
                                    resources: DeviceEffectResources? = nil) {
        guard now.isFinite, framesPerSecond.isFinite, framesPerSecond > 0 else { return }
        self.ceiling = FXQuality(rawValue: min(profile.maximumQuality.rawValue, ceiling.rawValue, resources?.qualityCeiling ?? 2))!
        maximumOverlayPixels = min(profile.maximumOverlayPixels, resources?.maximumOverlayPixels ?? profile.maximumOverlayPixels)
        enhancedEffectsAllowed = profile.supportsEnhancedEffects && (resources?.enhancedEffectsAllowed ?? true)
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
