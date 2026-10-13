import NxlvKit
import Testing

struct ExplosionPixelSprayTests {
    @Test func sprayHasDeterministicMotionAndAnExactEnd() {
        let burst = PixelExplosion(id: 4, birthTick: 100, x: 80, y: 60)
        #expect(ExplosionPixelSpray.pixels(for: burst, at: 99).isEmpty)
        let first = ExplosionPixelSpray.pixels(for: burst, at: 101)
        #expect(first.count == ExplosionPixelSpray.particleCount)
        #expect(first == ExplosionPixelSpray.pixels(for: burst, at: 101))
        #expect(first != ExplosionPixelSpray.pixels(for: burst, at: 108))
        #expect(ExplosionPixelSpray.pixels(for: burst, at: 116).isEmpty)
    }
    @Test func timelineRetainsSkippedFramesAndClearsFutureBurstsOnRewind() {
        let burst = PixelExplosion(id: 1, birthTick: 10, x: 40, y: 40)
        var timeline = PixelExplosionTimeline()
        timeline.update(tick: 10, bursts: [burst, burst])
        timeline.update(tick: 18, bursts: [])
        #expect(timeline.bursts == [burst])
        timeline.update(tick: 9, bursts: [])
        #expect(timeline.bursts.isEmpty)
        timeline.update(tick: 10, bursts: [burst])
        timeline.update(tick: 26, bursts: [])
        #expect(timeline.bursts.isEmpty)
    }
}
