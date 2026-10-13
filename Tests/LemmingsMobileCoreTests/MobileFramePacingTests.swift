import Testing
@testable import LemmingsMobileCore

struct MobileFramePacingTests {
    @Test func missedDeadlinesReduceCadenceEvenWithCheapMeasuredWork() {
        var policy = MobileFramePacing()
        for frame in 0..<150 {
            policy.observe(at: Double(frame) / 30, cpuSeconds: 0.002, gpuSeconds: 0.002, active: true)
        }
        #expect(policy.framesPerSecond == 30)
    }

    @Test func sustainedCPUAndGPUPressureReduceCadence() {
        for gpu in [false, true] {
            var policy = MobileFramePacing(maximumFramesPerSecond: 30)
            for frame in 0..<180 {
                policy.observe(at: Double(frame) / 30,
                    cpuSeconds: gpu ? 0.002 : 0.032, gpuSeconds: gpu ? 0.032 : 0.002, active: true)
            }
            #expect(policy.framesPerSecond == 20)
        }
    }

    @Test func pauseAndLifecycleGapsDoNotCreatePressureOrEarnRecovery() {
        var policy = MobileFramePacing(maximumFramesPerSecond: 30)
        policy.setMaximumFramesPerSecond(60)
        for frame in 0..<1_000 {
            policy.observe(at: Double(frame) / 30, cpuSeconds: 0.002, gpuSeconds: 0.002, active: false)
        }
        #expect(policy.framesPerSecond == 30)
        policy.observe(at: 100, cpuSeconds: 0.1, gpuSeconds: 0.1, active: true)
        policy.observe(at: 200, cpuSeconds: 0.1, gpuSeconds: 0.1, active: true)
        policy.observe(at: .nan, cpuSeconds: 0.1, gpuSeconds: 0.1, active: true)
        #expect(policy.framesPerSecond == 30)
    }

    @Test func isolatedStallIsIgnoredAndRecoveryNeedsSustainedHeadroom() {
        var policy = MobileFramePacing()
        var time = 0.0
        for frame in 0..<180 {
            time += frame == 60 ? 0.1 : 1.0 / 60
            policy.observe(at: time, cpuSeconds: frame == 60 ? 0.1 : 0.002, gpuSeconds: 0.002, active: true)
        }
        #expect(policy.framesPerSecond == 60)
        policy.setMaximumFramesPerSecond(30)
        policy.setMaximumFramesPerSecond(60)
        for _ in 0..<300 {
            time += 1.0 / 30
            policy.observe(at: time, cpuSeconds: 0.002, gpuSeconds: 0.002, active: true)
        }
        #expect(policy.framesPerSecond == 30)
        for _ in 0..<120 {
            time += 1.0 / 30
            policy.observe(at: time, cpuSeconds: 0.002, gpuSeconds: 0.002, active: true)
        }
        #expect(policy.framesPerSecond == 60)
    }

    @Test func thermalCeilingsUseEvenCadenceAndDoNotRestoreImmediately() {
        var policy = MobileFramePacing()
        policy.setMaximumFramesPerSecond(45)
        #expect(policy.framesPerSecond == 30)
        policy.setMaximumFramesPerSecond(20)
        #expect(policy.framesPerSecond == 20)
        policy.setMaximumFramesPerSecond(60)
        #expect(policy.framesPerSecond == 20)
    }

    @Test func everyEngineRetainsItsClockAtEveryCadenceAndSpeed() {
        for rate in [17.0, 17.5, 23.0] {
            for cadence in [20, 30, 60] {
                for speed in [1.0, 2.0, 8.0] {
                    var clock = MobileTickClock(ticksPerSecond: rate, speed: speed,
                        maximumCatchUpTicks: max(4, Int((rate * speed / Double(cadence) * 2).rounded(.up))))
                    _ = clock.advance(at: 0)
                    let ticks = (1...(cadence * 10)).reduce(0) {
                        $0 + clock.advance(at: Double($1) / Double(cadence))
                    }
                    #expect(ticks == Int(rate * speed * 10))
                }
            }
        }
    }
}
