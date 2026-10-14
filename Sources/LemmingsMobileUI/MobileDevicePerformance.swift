#if os(iOS) || os(tvOS)
import Foundation
import Metal
import LemmingsGameArt
import NxlvKit

/// Older GPUs and two-core devices reserve more time for simulation and audio.
@MainActor enum MobileDevicePerformance {
    #if os(tvOS)
    static let profile = FXDeviceProfile.detect(device: MTLCreateSystemDefaultDevice(), mobile: true, television: true)
    #else
    static let profile = FXDeviceProfile.detect(device: MTLCreateSystemDefaultDevice(), mobile: true)
    #endif
    private static var adaptive = AdaptiveFXPerformance(profile: profile)
    private static var framesPerSecond: Double = constrained ? 30 : 60
    private static var lastPoll = -Double.infinity
    static var presentation: FXPresentationBudget {
        refreshPressure()
        return adaptive.presentation
    }
    static var enhancedEffectsAllowed: Bool {
        presentation.enhancedEffectsAllowed && !ProcessInfo.processInfo.isLowPowerModeEnabled
            && ProcessInfo.processInfo.thermalState != .serious && ProcessInfo.processInfo.thermalState != .critical
    }
    // A12 iPads support the shaders, but cannot afford desktop-sized effects.
    static let constrained = MTLCreateSystemDefaultDevice()?.supportsFamily(.apple7) != true
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
        adaptive.setPressure(ceiling: ceiling, framesPerSecond: framesPerSecond, now: now,
                             resources: DeviceEffectPressure.shared.snapshot())
    }
    static func memoryWarning() {
        DeviceEffectPressure.shared.noteMemoryPressure()
        refreshPressure(force: true)
    }
    static func recordCPU(_ seconds: Double, source: String) {
        refreshPressure()
        adaptive.recordCPU(seconds, source: source, now: ProcessInfo.processInfo.systemUptime)
        DeviceEffectPressure.shared.setAudioQuality(adaptive.cpu.quality.rawValue)
    }
    static func recordGPU(_ seconds: Double, source: String) {
        refreshPressure()
        adaptive.recordGPU(seconds, source: source, now: ProcessInfo.processInfo.systemUptime)
    }
}
#endif
