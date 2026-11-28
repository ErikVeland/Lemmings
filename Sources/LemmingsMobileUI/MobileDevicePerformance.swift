#if os(iOS) || os(tvOS)
import Foundation
import Metal
import LemmingsGameArt
import NxlvKit
import UIKit

/// Older GPUs and two-core devices reserve more time for simulation and audio.
@MainActor enum MobileDevicePerformance {
    private static let device = MTLCreateSystemDefaultDevice()
    #if os(tvOS)
    private static let baseProfile = FXDeviceProfile.detect(device: device, mobile: true, television: true)
    #else
    private static let baseProfile = FXDeviceProfile.detect(device: device, mobile: true, allowFixedMobileEffects: false)
    #endif
    // Retain audio-pressure tracking even when the visual quality is fixed.
    private static var adaptive = AdaptiveFXPerformance(profile: baseProfile)
    private static var fixedVisuals: AdaptiveFXPerformance? = {
        #if os(iOS)
        let profile = FXDeviceProfile.detect(device: device, mobile: true)
        if profile.prefersFixedMobileEffects { return AdaptiveFXPerformance(profile: profile) }
        #endif
        return nil
    }()
    private static var framesPerSecond: Double = constrained ? 30 : 60
    private static var lastPoll = -Double.infinity
    static var presentation: FXPresentationBudget {
        refreshPressure()
        return fixedVisuals?.presentation ?? adaptive.presentation
    }
    static var enhancedEffectsAllowed: Bool {
        let allowed = presentation.enhancedEffectsAllowed
        if fixedVisuals != nil { return allowed }
        return allowed && !ProcessInfo.processInfo.isLowPowerModeEnabled
            && ProcessInfo.processInfo.thermalState != .serious && ProcessInfo.processInfo.thermalState != .critical
    }

    // Runtime hinge detection also covers a Duo running on its outer display.
    // Once recognised, keep the same visual policy through fold/unfold.
    static func configureVisuals(in view: UIView) {
        #if os(iOS)
        guard fixedVisuals == nil, view.window != nil,
              MobileSystemRegions.isFoldable(in: view) else { return }
        let profile = FXDeviceProfile.detect(device: device, mobile: true, foldable: true)
        if profile.prefersFixedMobileEffects {
            fixedVisuals = AdaptiveFXPerformance(profile: profile)
            refreshPressure(force: true)
        }
        #endif
    }
    static var visualEffectsConstrained: Bool { fixedVisuals == nil && constrained }

    // An older GPU can support the shaders without affording desktop-sized effects.
    #if targetEnvironment(simulator)
    static let constrained = false
    #else
    static let constrained = device?.supportsFamily(.apple7) != true
    #endif
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
        let resources = DeviceEffectPressure.shared.snapshot()
        adaptive.setPressure(ceiling: ceiling, framesPerSecond: framesPerSecond, now: now, resources: resources)
        fixedVisuals?.setPressure(ceiling: ceiling, framesPerSecond: framesPerSecond, now: now, resources: resources)
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
