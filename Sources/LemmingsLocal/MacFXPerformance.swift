#if os(macOS)
import AppKit
import Metal
import LemmingsGameArt

/// One presentation policy covers Classic, NeoLemmix and both native sequels.
@MainActor final class MacFXPerformance {
    static let shared = MacFXPerformance()
    private var budget: AdaptiveFXPerformance
    private var lastPoll = -Double.infinity
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
        case .fair: pressure = .balanced
        default: pressure = process.isLowPowerModeEnabled ? .balanced : .full
        }
        budget.setPressure(ceiling: pressure, framesPerSecond: process.isLowPowerModeEnabled ? 30 : 60, now: now)
    }
    func recordCPU(_ seconds: Double) {
        poll()
        let now = ProcessInfo.processInfo.systemUptime
        budget.recordCPU(seconds, now: now)
    }
    func recordGPU(_ seconds: Double, source: String) {
        poll()
        budget.recordGPU(seconds, source: source, now: ProcessInfo.processInfo.systemUptime)
    }
}
#endif
