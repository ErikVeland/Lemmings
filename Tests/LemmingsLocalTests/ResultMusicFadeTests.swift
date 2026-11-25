import Foundation
import LemmingsAudio
import XCTest

@MainActor final class ResultMusicFadeTests: XCTestCase {
    func testFinishingOnceAndRetiringBeforeAnotherTrackStarts() async throws {
        var gains: [Float] = []
        var filters: [Float] = []
        var stops = 0
        let fade = ResultMusicFade(gain: { gains.append($0) }, filter: { filters.append($0) }, stop: { stops += 1 })
        let first = UUID()
        fade.begin(attempt: first)
        fade.begin(attempt: first)
        try await Task.sleep(nanoseconds: 850_000_000)
        // The result holds the track in the muffled room instead of stopping it.
        XCTAssertEqual(stops, 0)
        XCTAssertEqual(gains.last, ResultMusicFade.Room.gain)
        XCTAssertEqual(filters.last, ResultMusicFade.Room.filter)
        XCTAssertTrue(zip(gains, gains.dropFirst()).allSatisfy { $0 >= $1 })
        XCTAssertTrue(zip(filters, filters.dropFirst()).allSatisfy { $0 <= $1 })
        let held = gains.count
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(gains.count, held, "A settled room must not keep writing to the bus")

        // Leaving the result stops the track once and restores the bus for the next owner.
        fade.retire()
        XCTAssertEqual(stops, 1)
        XCTAssertEqual(filters.last, 0)
        XCTAssertEqual(gains.last, 1)

        fade.begin(attempt: UUID())
        try await Task.sleep(nanoseconds: 40_000_000)
        fade.retire()
        XCTAssertEqual(stops, 2)
        let afterNextTrackStarts = (gains, filters)
        fade.retire()
        try await Task.sleep(nanoseconds: 650_000_000)
        XCTAssertNil(fade.owner)
        XCTAssertEqual(stops, 2)
        XCTAssertEqual(gains, afterNextTrackStarts.0)
        XCTAssertEqual(filters, afterNextTrackStarts.1)
    }
}
