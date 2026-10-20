#if os(macOS)
import AppKit
import Metal
import LemmingsGameArt
import NxlvKit

/// One presentation policy covers Classic, NeoLemmix and both native sequels.
@MainActor final class MacFXPerformance {
    static let shared = MacFXPerformance()
    private var budget: AdaptiveFXPerformance
    private var lastPoll = -Double.infinity
    private var displayFramesPerSecond: Double = 60
    #if PERFORMANCE_TESTS
    var overrideQuality: FXQuality?
    #endif
    var quality: FXQuality {
        presentation.quality
    }
    var presentation: FXPresentationBudget {
        #if PERFORMANCE_TESTS
        if let overrideQuality { return FXPresentationBudget(cpuQuality: overrideQuality, gpuQuality: overrideQuality) }
        #endif
        poll()
        return budget.presentation
    }
    private init() {
        budget = AdaptiveFXPerformance(profile: .detect(device: MTLCreateSystemDefaultDevice(), mobile: false))
    }
    private func poll() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPoll >= 1 else { return }
        lastPoll = now
        let process = ProcessInfo.processInfo
        let pressure: FXQuality
        switch process.thermalState {
        case .serious, .critical: pressure = .minimal
        case .fair: pressure = budget.profile.prefersFullDesktopEffects && !process.isLowPowerModeEnabled ? .full : .balanced
        case .nominal: pressure = process.isLowPowerModeEnabled ? .balanced : .full
        @unknown default: pressure = .minimal
        }
        let sharedResources = DeviceEffectPressure.shared.snapshot()
        let resources: DeviceEffectResources
        if budget.profile.prefersFullDesktopEffects {
            // Mild warmth and routine timing do not constrain M-series desktop effects.
            let thermal = process.thermalState == .critical ? 3 : process.thermalState == .serious ? 2 : 0
            resources = DeviceEffectResources(physicalMemory: process.physicalMemory, processorCount: process.processorCount)
                .underPressure(thermalLevel: thermal, lowPower: process.isLowPowerModeEnabled,
                    memoryPressure: sharedResources.maximumOverlayPixels <= 262_144)
        } else { resources = sharedResources }
        budget.setPressure(ceiling: pressure,
                           framesPerSecond: min(displayFramesPerSecond, process.isLowPowerModeEnabled ? 30 : 60), now: now,
                           resources: resources)
    }
    func configureDisplay(_ screen: NSScreen) {
        let rate = Double(max(1, min(60, screen.maximumFramesPerSecond)))
        guard rate != displayFramesPerSecond else { return }
        displayFramesPerSecond = rate; lastPoll = -.infinity
        poll()
    }
    func recordCPU(_ seconds: Double) {
        poll()
        let now = ProcessInfo.processInfo.systemUptime
        budget.recordCPU(seconds, now: now)
        DeviceEffectPressure.shared.setAudioQuality(budget.cpu.quality.rawValue)
    }
    func recordGPU(_ seconds: Double, source: String) {
        poll()
        budget.recordGPU(seconds, source: source, now: ProcessInfo.processInfo.systemUptime)
    }
}
#endif
