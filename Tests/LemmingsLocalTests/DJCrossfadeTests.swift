import Foundation
import LemmingsAudio
import Testing

struct DJCrossfadeTests {
    @MainActor @Test func legacyHandoffPausesAndUsesTheCurrentVolume() async throws {
        let handoff = LegacyDJCrossfade()
        var volume = 0.8
        var suspended = false
        var legacy = 0.8
        var incoming = 0.0
        var stopped = false
        handoff.start(volume: { volume }, suspended: { suspended },
            legacyGain: { legacy = $0 }, incomingGain: { incoming = $0 }, stopLegacy: { stopped = true })
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(incoming > 0 && legacy < 0.8 && !stopped)
        suspended = true
        try await Task.sleep(nanoseconds: 70_000_000)
        let pausedGain = incoming
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(incoming == pausedGain && !stopped)
        volume = 0.2
        try await Task.sleep(nanoseconds: 70_000_000)
        #expect(abs(legacy * legacy + incoming * incoming - 0.04) < 0.0001)
        suspended = false
        try await Task.sleep(nanoseconds: 2_700_000_000)
        #expect(stopped && incoming == 0.2)
        handoff.cancel()
    }
}
