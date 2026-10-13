#if os(iOS)
import Foundation
import Metal
import LemmingsGameArt

/// Older GPUs and two-core iPads reserve more time for simulation and audio.
@MainActor enum MobileDevicePerformance {
    static let profile = FXDeviceProfile.detect(device: MTLCreateSystemDefaultDevice(), mobile: true)
    private static var adaptive = AdaptiveFXPerformance(profile: profile)
    private static var framesPerSecond: Double = constrained ? 30 : 60
    private static var lastPoll = -Double.infinity
    static var presentation: FXPresentationBudget {
        refreshPressure()
        return adaptive.presentation
    }
    static var enhancedEffectsAllowed: Bool {
        profile.supportsEnhancedEffects && !ProcessInfo.processInfo.isLowPowerModeEnabled
            && ProcessInfo.processInfo.thermalState != .serious && ProcessInfo.processInfo.thermalState != .critical
    }
    static var constrained: Bool { !profile.supportsEnhancedEffects }
    static var cpuFrameCost: Double { adaptive.cpu.smoothedCost }
    static var gpuFrameCost: Double { adaptive.gpu.smoothedCost }

    static func update(framesPerSecond: Int) {
        self.framesPerSecond = Double(max(1, framesPerSecond))
        refreshPressure(force: true)
    }
    private static func refreshPressure(force: Bool = false) {
        let now = ProcessInfo.processInfo.systemUptime
        guard force || now - lastPoll >= 1 else { return }
        lastPoll = now
        let process = ProcessInfo.processInfo
        let ceiling: FXQuality
        switch process.thermalState {
        case .serious, .critical: ceiling = .minimal
        case .fair: ceiling = .balanced
        case .nominal: ceiling = process.isLowPowerModeEnabled ? .balanced : .full
        @unknown default: ceiling = .minimal
        }
        adaptive.setPressure(ceiling: ceiling, framesPerSecond: framesPerSecond, now: now)
    }
    static func recordCPU(_ seconds: Double, source: String) {
        refreshPressure()
        adaptive.recordCPU(seconds, source: source, now: ProcessInfo.processInfo.systemUptime)
    }
    static func recordGPU(_ seconds: Double, source: String) {
        refreshPressure()
        adaptive.recordGPU(seconds, source: source, now: ProcessInfo.processInfo.systemUptime)
    }
}
#endif
