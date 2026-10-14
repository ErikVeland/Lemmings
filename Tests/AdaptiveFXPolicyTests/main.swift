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

        for (gib, expectedQuality, expectedVoices) in [(2, FXQuality.minimal, 8), (4, .balanced, 12), (8, .full, 24), (16, .full, 32)] {
            let resources = DeviceEffectResources(physicalMemory: UInt64(gib) * 1_073_741_824, processorCount: 8)
            let profile = FXDeviceProfile(hasMetal: true, modernGPU: true, enhancedEffectsSupported: true,
                                          processorCount: 8, recommendedWorkingSet: 8_589_934_592,
                                          physicalMemory: UInt64(gib) * 1_073_741_824)
            try require(profile.maximumQuality == expectedQuality && resources.audioVoiceLimit == expectedVoices,
                        "Physical RAM did not constrain effect surfaces and audio sources")
            var policy = AdaptiveFXPerformance(profile: profile)
            for tick in 0..<1_800 { policy.recordCPU(0.001, now: Double(tick) / 60) }
            try require(policy.presentation.quality.rawValue <= expectedQuality.rawValue,
                        "Fast samples promoted effects beyond the memory ceiling")
            let warning = resources.underPressure(thermalLevel: 0, lowPower: false, memoryPressure: true)
            policy.setPressure(ceiling: .full, framesPerSecond: 60, now: 31, resources: warning)
            try require(!policy.presentation.bloomAllowed && !policy.presentation.enhancedEffectsAllowed
                        && policy.presentation.maximumOverlayPixels <= 262_144
                        && warning.audioVoiceLimit == 6 && warning.rescueVoiceLimit == 2,
                        "Memory pressure retained expensive surfaces or stacked sound layers")
            policy.setPressure(ceiling: .full, framesPerSecond: 60, now: 32, resources: resources)
            try require(policy.presentation.quality == .minimal, "Pressure relief restored effects without measured recovery")
            let thermal = resources.underPressure(thermalLevel: 3, lowPower: false, memoryPressure: false)
            let battery = resources.underPressure(thermalLevel: 0, lowPower: true, memoryPressure: false)
            let cpuBound = resources.limitingAudio(toQuality: 0)
            try require(thermal.audioVoiceLimit <= 6 && thermal.rescueVoiceLimit <= 2
                        && !thermal.enhancedEffectsAllowed && battery.audioVoiceLimit <= 12
                        && battery.rescueVoiceLimit <= 4 && !battery.enhancedEffectsAllowed,
                        "Power and thermal policy did not constrain audio and HDR together")
            try require(cpuBound.audioVoiceLimit <= 6 && cpuBound.rescueVoiceLimit <= 2
                        && cpuBound.maximumOverlayPixels == resources.maximumOverlayPixels,
                        "CPU audio limits changed unrelated GPU memory budgets")
            for thermal in 0...3 {
                for lowPower in [false, true] {
                    for warning in [false, true] {
                        let combined = resources.underPressure(thermalLevel: thermal, lowPower: lowPower, memoryPressure: warning)
                        try require(combined.audioVoiceLimit <= [32, 16, 10, 6][thermal]
                                    && combined.rescueVoiceLimit <= [64, 8, 4, 2][thermal],
                                    "Combined pressure weakened a thermal audio limit")
                    }
                }
            }
        }
        let twoCore = DeviceEffectResources(physicalMemory: 16 * 1_073_741_824, processorCount: 2)
        try require(twoCore.audioVoiceLimit <= 8 && twoCore.rescueVoiceLimit <= 4 && !twoCore.enhancedEffectsAllowed,
                    "Two-core devices retained a large rescue mix or HDR surface")
        print("PASS 2/4/8/16 GiB memory ceilings, audio budgets, pressure release and conservative FX recovery")

        let television = FXDeviceProfile(hasMetal: true, modernGPU: true, enhancedEffectsSupported: true,
                                         processorCount: 6, recommendedWorkingSet: 1_073_741_824, television: true)
        let olderTV = FXDeviceProfile(hasMetal: true, modernGPU: false, enhancedEffectsSupported: true,
                                     processorCount: 2, recommendedWorkingSet: 33_554_432, television: true)
        try require(television.initialQuality == .balanced && olderTV.initialQuality == .minimal,
                    "TV must reserve capacity before effects have device measurements")
        try require(!television.supportsEnhancedEffects && !olderTV.supportsEnhancedEffects && modern.supportsEnhancedEffects,
                    "TV full-screen effects policy changed another platform or enabled the costly surface")
        try require(television.maximumOverlayPixels <= 720_000, "TV allowed a desktop-sized soft overlay")
        for quality in FXQuality.allCases {
            let budget = FXPresentationBudget(cpuQuality: quality, gpuQuality: quality)
            try require(budget.televisionPlayfieldScale(nativeScale: 2) == 1,
                        "TV enabled a 4K floating-point playfield")
            try require(budget.televisionPlayfieldScale(nativeScale: 1) == 1,
                        "TV changed a 1080p playfield")
        }
        var tvPressure = AdaptiveFXPerformance(profile: television)
        try require(tvPressure.presentation.televisionBloomAllowed, "TV lost balanced CRT bloom")
        for tick in 0..<180 {
            let now = Double(tick) / 60
            tvPressure.recordCPU(0.002, now: now)
            tvPressure.recordGPU(0.020, source: "crt", now: now)
        }
        try require(!tvPressure.presentation.televisionBloomAllowed,
                    "TV retained bloom after sustained GPU pressure")
        let cpuBoundTV = FXPresentationBudget(cpuQuality: .minimal, gpuQuality: .full)
        try require(!cpuBoundTV.televisionBloomAllowed, "TV retained optional bloom during CPU pressure")
        let reducedCadenceTV = FXPresentationBudget(cpuQuality: .full, gpuQuality: .full, framesPerSecond: 30)
        try require(!reducedCadenceTV.televisionBloomAllowed, "TV restored bloom while presentation remained at 30 Hz")
        for tick in 0..<600 {
            let now = 3 + Double(tick) / 60
            tvPressure.recordCPU(0.002, now: now)
            tvPressure.recordGPU(0.002, source: "crt", now: now)
        }
        try require(!tvPressure.presentation.televisionBloomAllowed, "TV restored bloom before measured recovery")
        for tick in 600..<960 {
            let now = 3 + Double(tick) / 60
            tvPressure.recordCPU(0.002, now: now)
            tvPressure.recordGPU(0.002, source: "crt", now: now)
        }
        try require(tvPressure.presentation.televisionBloomAllowed, "TV could not recover affordable CRT bloom")
        tvPressure.setPressure(ceiling: .minimal, framesPerSecond: 60, now: 20)
        try require(!tvPressure.presentation.televisionBloomAllowed, "TV thermal pressure did not drop bloom immediately")
        print("PASS TV conservative startup, disabled full-screen effects, 4K bounds, bloom removal and measured recovery")
    }
}
