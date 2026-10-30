import Testing
@testable import LemmingsMobileCore

struct MobileRewindPressAccelerationTests {
    @Test func repeatedRewindPressesAccelerateAfterEachCompletedSeek() {
        var acceleration = MobileRewindPressAcceleration()
        var queue = MobileRewindQueue()
        var tick = 2000
        var distances: [Int] = []
        for press in 0..<6 {
            let distance = acceleration.ticks(at: Double(press) * 0.3, ticksPerSecond: 17)
            distances.append(distance)
            _ = queue.append(ticks: distance, from: tick, earliestTick: 0)
            let request = queue.takePending()
            tick = request?.tick ?? tick
            queue.didCommit()
        }
        #expect(distances == [34, 68, 136, 272, 272, 272])
        #expect(tick == 946)
        let afterPause = acceleration.ticks(at: 2.2, ticksPerSecond: 17)
        #expect(afterPause == 34)
    }

    @Test func rapidTVTriggerTapsGrowBeyondSingleFrameSteps() {
        var acceleration = MobileRewindPressAcceleration()
        var distances: [Int] = []
        for press in 0..<6 {
            distances.append(acceleration.ticks(at: Double(press) * 0.3, ticksPerSecond: 17, preciseFirstTap: true))
        }
        #expect(distances == [1, 7, 14, 27, 54, 54])
        let afterPause = acceleration.ticks(at: 2.2, ticksPerSecond: 17, preciseFirstTap: true)
        #expect(afterPause == 1)
        acceleration.reset()
        let afterResume = acceleration.ticks(at: 2.3, ticksPerSecond: 17, preciseFirstTap: true)
        #expect(afterResume == 1)
    }

    @Test func acceleratedPressesStackWhileReconstructionIsBusy() {
        for rate in [17.0, 20, 30] {
            var acceleration = MobileRewindPressAcceleration()
            var queue = MobileRewindQueue()
            let firstDistance = acceleration.ticks(at: 0, ticksPerSecond: rate)
            _ = queue.append(ticks: firstDistance, from: 2000, earliestTick: 0)
            _ = queue.takePending()
            for time in [0.2, 0.4] {
                let distance = acceleration.ticks(at: time, ticksPerSecond: rate)
                _ = queue.append(ticks: distance, from: 2000, earliestTick: 0)
            }
            queue.didCommit()
            let stacked = queue.takePending()
            #expect(stacked?.tick == 2000 - Int(14 * rate))
            #expect(stacked?.backwardSteps == 2)
        }
    }
}
