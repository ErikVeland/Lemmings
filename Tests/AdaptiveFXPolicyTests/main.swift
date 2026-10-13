import Foundation

private struct Failure: Error { let message: String }
private func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw Failure(message: message) }
}

@main struct AdaptiveFXPolicyTests {
    static func main() throws {
        let modern = FXDeviceProfile(hasMetal: true, modernGPU: true, enhancedEffectsSupported: true,
                                     processorCount: 8, recommendedWorkingSet: 1_073_741_824)
        let older = FXDeviceProfile(hasMetal: true, modernGPU: false, enhancedEffectsSupported: false,
                                    processorCount: 2, recommendedWorkingSet: 33_554_432)
        let unavailable = FXDeviceProfile(hasMetal: false, modernGPU: true, enhancedEffectsSupported: true,
                                          processorCount: 8, recommendedWorkingSet: 0)
        try require(older.initialQuality == .minimal && older.maximumQuality == .full,
                    "Older devices must be able to earn higher quality through measurements")
        try require(!older.supportsEnhancedEffects && !unavailable.supportsEnhancedEffects,
                    "Quality must not enable an unsupported rendering path")
        var promotion = AdaptiveFXPerformance(profile: older)
        for tick in 0..<1_800 {
            let now = Double(tick) / 60
            promotion.recordCPU(0.002, now: now)
            promotion.recordGPU(0.002, source: "crt", now: now)
        }
        try require(promotion.presentation.quality == .full, "A capable older device could not recover to full quality")
        print("PASS capability seeds, software fallback and measured promotion on older devices")

        var cpuPressure = AdaptiveFXPerformance(profile: modern)
        var gpuPressure = AdaptiveFXPerformance(profile: modern)
        for tick in 0..<480 {
            let now = Double(tick) / 60
            cpuPressure.recordCPU(0.02, now: now)
            cpuPressure.recordGPU(0.002, source: "crt", now: now)
            gpuPressure.recordCPU(0.002, now: now)
            gpuPressure.recordGPU(0.02, source: "crt", now: now)
        }
        try require(cpuPressure.presentation.cpuQuality == .minimal && cpuPressure.presentation.gpuQuality == .full,
                    "CPU pressure reduced unrelated GPU detail")
        try require(gpuPressure.presentation.gpuQuality == .minimal && gpuPressure.presentation.cpuQuality == .full,
                    "GPU pressure reduced unrelated CPU detail")
        try require(cpuPressure.presentation.bloomScale == 1 && cpuPressure.presentation.trailLimit == 6,
                    "CPU pressure did not select the independent presentation budgets")
        print("PASS independent CPU/GPU pressure and resource budgets")

        var at30 = AdaptiveFXPerformance(profile: modern)
        var at60 = AdaptiveFXPerformance(profile: modern)
        at30.setPressure(ceiling: .full, framesPerSecond: 30, now: 0)
        for tick in 0..<180 {
            let now = Double(tick) / 30
            at30.recordGPU(0.02, source: "crt", now: now)
            at60.recordGPU(0.02, source: "crt", now: now)
        }
        try require(at30.presentation.gpuQuality == .full && at60.presentation.gpuQuality == .minimal,
                    "Pressure thresholds did not follow the requested frame interval")
        try require(at30.presentation.effectHz == 30, "Effects exceeded the presentation target")
        at30.setPressure(ceiling: .minimal, framesPerSecond: 20, now: 10)
        try require(at30.presentation.quality == .minimal && at30.presentation.effectHz == 20,
                    "Thermal pressure was not immediate while paused")
        at30.setPressure(ceiling: .full, framesPerSecond: 60, now: 11)
        for tick in 0..<600 {
            let now = 11 + Double(tick) / 60
            at30.recordCPU(0.002, now: now); at30.recordGPU(0.002, source: "crt", now: now)
        }
        try require(at30.presentation.quality == .minimal, "Restored power caused premature recovery")
        print("PASS frame interval, thermal restriction, effect cadence and slow recovery")

        var aggregate = AdaptiveFXPerformance(profile: modern)
        for tick in 0..<180 {
            let now = Double(tick) / 60
            aggregate.recordGPU(0.008, source: "crt", now: now)
            aggregate.recordGPU(0.008, source: "effects", now: now)
        }
        try require(aggregate.presentation.gpuQuality == .balanced, "Concurrent effect surfaces were budgeted separately")
        aggregate.recordGPU(0.002, source: "crt", now: 10)
        try require(abs(aggregate.gpu.smoothedCost - 0.002) < 0.000001, "Expired GPU work retained pressure after a gap")
        aggregate.recordGPU(.nan, source: "crt", now: 11)
        aggregate.recordCPU(-1, now: 11)
        try require(aggregate.gpu.smoothedCost.isFinite && aggregate.cpu.smoothedCost.isFinite,
                    "Invalid samples corrupted the budget")
        print("PASS concurrent surfaces, stale samples, lifecycle gaps and invalid measurements")

        var noGPU = AdaptiveFXPerformance(profile: unavailable)
        for tick in 0..<1_800 { noGPU.recordCPU(0.001, now: Double(tick) / 60) }
        try require(noGPU.presentation.quality == .minimal, "Measurements exceeded the software capability ceiling")
        let constrainedBudget = AdaptiveFXPerformance(profile: older).presentation
        let scale = constrainedBudget.overlayRenderScale(width: 3_840, height: 2_160, nativeScale: 2)
        try require(scale > 0 && 3_840 * 2_160 * scale * scale <= Double(older.maximumOverlayPixels) + 1,
                    "A large display exceeded the memory-derived surface budget")
        try require(constrainedBudget.overlayRenderScale(width: 200, height: 100, nativeScale: 2) == 1,
                    "Small surfaces did not retain the available visual detail")
        print("PASS unsupported Metal, memory-derived pixel bounds and native scale")
    }
}
