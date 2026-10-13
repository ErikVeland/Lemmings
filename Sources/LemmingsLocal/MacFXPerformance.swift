#if os(macOS)
import AppKit
import Metal
import LemmingsGameArt

/// One presentation policy covers Classic, NeoLemmix and both native sequels.
@MainActor final class MacFXPerformance {
    static let shared = MacFXPerformance()
    private var budget = AdaptiveFXQuality()
    private var hardwareCeiling = FXQuality.full
    private var ceiling = FXQuality.full
    private var lastPoll = -Double.infinity
    private var gpuCosts: [String: (seconds: Double, at: Double)] = [:]
    #if PERFORMANCE_TESTS
    var overrideQuality: FXQuality?
    #endif
    var quality: FXQuality {
        #if PERFORMANCE_TESTS
        if let overrideQuality { return overrideQuality }
        #endif
        poll()
        return FXQuality(rawValue: min(budget.quality.rawValue, ceiling.rawValue))!
    }
    private init() {
        if let device = MTLCreateSystemDefaultDevice() {
            if device.recommendedMaxWorkingSetSize < 256 * 1024 * 1024 { hardwareCeiling = .balanced }
        } else { hardwareCeiling = .minimal }
    }
    private func poll() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPoll >= 1 else { return }
        lastPoll = now
        let process = ProcessInfo.processInfo
        let pressure: FXQuality
        switch process.thermalState {
        case .serious, .critical: pressure = .minimal
        default: pressure = process.isLowPowerModeEnabled ? .balanced : .full
        }
        ceiling = FXQuality(rawValue: min(hardwareCeiling.rawValue, pressure.rawValue))!
    }
    func recordCPU(_ seconds: Double) {
        poll()
        let now = ProcessInfo.processInfo.systemUptime
        gpuCosts = gpuCosts.filter { now - $0.value.at < 0.5 }
        budget.observe(cpuSeconds: seconds, gpuSeconds: gpuCosts.values.reduce(0) { $0 + $1.seconds },
                       now: now, ceiling: ceiling)
    }
    func recordGPU(_ seconds: Double, source: String) {
        guard seconds.isFinite, seconds >= 0 else { return }
        gpuCosts[source] = (seconds, ProcessInfo.processInfo.systemUptime)
    }
}
#endif
