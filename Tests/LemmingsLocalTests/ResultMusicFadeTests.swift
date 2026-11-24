import Foundation
import LemmingsAudio
import XCTest

@MainActor final class ResultMusicFadeTests: XCTestCase {
    func testFinishingOnceAndRetiringBeforeAnotherTrackStarts() async throws {
        var gains: [Float] = []
        var stops = 0
        let fade = ResultMusicFade(gain: { gains.append($0) }, stop: { stops += 1 })
        let first = UUID()
        fade.begin(attempt: first)
        fade.begin(attempt: first)
        try await Task.sleep(nanoseconds: 850_000_000)
        XCTAssertEqual(stops, 1)
        XCTAssertEqual(gains.last, 0)
        XCTAssertTrue(zip(gains, gains.dropFirst()).allSatisfy { $0 >= $1 })
        fade.retire()
        XCTAssertEqual(stops, 1)
        XCTAssertEqual(gains.last, 1)

        fade.begin(attempt: UUID())
        try await Task.sleep(nanoseconds: 40_000_000)
        fade.retire()
        XCTAssertEqual(stops, 2)
        let afterNextTrackStarts = gains
        fade.retire()
        try await Task.sleep(nanoseconds: 650_000_000)
        XCTAssertNil(fade.owner)
        XCTAssertEqual(stops, 2)
        XCTAssertEqual(gains, afterNextTrackStarts)
    }
}
