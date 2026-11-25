import Testing
@testable import LemmingsMobileCore

@Suite struct RewindCueTests {
    @Test func nothingRewoundShowsNoCue() {
        #expect(RewindCue(currentTick: 100, originTick: 100, ticksPerSecond: 17) == nil)
        #expect(RewindCue(currentTick: 120, originTick: 100, ticksPerSecond: 17) == nil)
    }

    @Test func cueUsesGameSecondsForEachEngineRate() throws {
        // Classic and NeoLemmix 17, Lemmings 2 17.5, Lemmings 3 23 ticks per second.
        for rate in [17.0, 17.5, 23.0] {
            let cue = try #require(RewindCue(currentTick: 0, originTick: Int(rate * 4), ticksPerSecond: rate))
            #expect(abs(cue.secondsBack - 4) < 0.1)
            #expect(cue.text.hasSuffix("REWIND -4.0s"))
            #expect(!cue.text.contains("TICK"))
        }
        for (rate, time) in [(17.0, "0.06"), (17.5, "0.06"), (23.0, "0.04")] {
            let keyboard = try #require(RewindCue(currentTick: 16, originTick: 17, ticksPerSecond: rate))
            let remote = try #require(RewindCue(currentTick: 16, originTick: 17, ticksPerSecond: rate, speed: 2))
            #expect(keyboard.text.hasSuffix("REWIND -" + time + "s"))
            #expect(keyboard.accessibilityLabel == "Rewound " + time + " seconds")
            #expect(remote.accessibilityLabel == keyboard.accessibilityLabel + ", speed 2 of 3")
        }
        let oneSecond = try #require(RewindCue(currentTick: 3, originTick: 20, ticksPerSecond: 17))
        #expect(oneSecond.accessibilityLabel == "Rewound 1 second")
        let long = try #require(RewindCue(currentTick: 0, originTick: 17 * 42, ticksPerSecond: 17))
        #expect(long.text.hasSuffix("REWIND -42s"))
    }

    @Test func speedShowsAsOneToThreeChevrons() throws {
        for (speed, chevrons) in [(0, "<<"), (1, "<<"), (2, "<<<"), (3, "<<<<"), (9, "<<<<")] {
            let cue = try #require(RewindCue(currentTick: 10, originTick: 40, ticksPerSecond: 17, speed: speed))
            #expect(cue.chevrons == chevrons)
            #expect(cue.text.hasPrefix(chevrons + " "))
        }
    }

    @Test func widestTextCoversEveryValue() throws {
        for ticks in [1, 17, 170, 1_700] {
            for speed in 1...3 {
                let cue = try #require(RewindCue(currentTick: 0, originTick: ticks, ticksPerSecond: 17, speed: speed))
                #expect(cue.text.count <= RewindCue.widestText.count)
            }
        }
    }

    @Test func rapidPressesRaiseTheShownSpeed() {
        var presses = MobileRewindPressAcceleration()
        #expect(presses.cueSpeed(at: 0) == 1)
        var speeds: [Int] = []
        for press in 0..<5 {
            let time = Double(press) * 0.3
            _ = presses.ticks(at: time, ticksPerSecond: 17)
            speeds.append(presses.cueSpeed(at: time))
        }
        #expect(speeds == [1, 2, 2, 3, 3])
        #expect(presses.cueSpeed(at: 1.2 + 0.7) == 1)
    }
}
