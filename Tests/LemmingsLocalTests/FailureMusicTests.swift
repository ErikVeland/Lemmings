import XCTest
@testable import LemmingsLocal

final class FailureMusicTests: XCTestCase {
    @MainActor func testFinalPopRestoresTempoWhileFailureVisualsRemain() async throws {
        let music = FailureMusicTransition(duration: 0.12, recoveryDuration: 0.12)
        let visual = FailureMoodTransition(duration: 0.12)
        var rates: [Double] = []
        music.onChange = { rates.append($0) }
        visual.set(active: true)
        music.update(failed: true, isNuking: true, allPopped: false)
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(music.rate, 0.72, accuracy: 0.0001)
        // Repeated updates before the last explosion must keep the dirge.
        music.update(failed: true, isNuking: true, allPopped: false)
        XCTAssertEqual(music.rate, 0.72, accuracy: 0.0001)
        rates = []
        music.update(failed: true, isNuking: true, allPopped: true)
        // No simulation ticks are needed once the result screen opens.
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(music.rate, 1)
        XCTAssertEqual(visual.amount, 1)
        XCTAssertTrue(rates.contains { $0 > 0.72 && $0 < 1 })
        XCTAssertTrue(zip(rates, rates.dropFirst()).allSatisfy { $0 <= $1 })
        music.update(failed: true, isNuking: true, allPopped: true)
        XCTAssertEqual(music.rate, 1)
        // Rewinding into the countdown restores the effect.
        music.update(failed: true, isNuking: true, allPopped: false)
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(music.rate, 0.72, accuracy: 0.0001)
        music.update(failed: false, isNuking: false, allPopped: false)
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(music.rate, 1)
    }

    @MainActor func testOrdinaryLossAndWinningNukeKeepTheirMusicPolicy() async throws {
        let music = FailureMusicTransition(duration: 0.05, recoveryDuration: 0.05)
        music.update(failed: true, isNuking: false, allPopped: true)
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(music.rate, 0.72, accuracy: 0.0001)
        music.update(failed: false, isNuking: true, allPopped: true)
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(music.rate, 1)
    }
}
