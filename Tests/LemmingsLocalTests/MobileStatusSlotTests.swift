#if os(macOS)
import CoreGraphics
import LemmingsGameArt
import LemmingsMobileCore
import XCTest

/// The iPad and tvOS top bar keeps every statistic centred in a fixed slot.
@MainActor final class MobileStatusSlotTests: XCTestCase {
    private func snapshot(released: Int, saved: Int, seconds: Int?, rate: Int?, complete: Bool = false,
                          ending: Bool = false) -> MobileGameSnapshot {
        MobileGameSnapshot(tick: 0, released: released, total: 100, saved: saved, required: 80,
                           remainingSeconds: seconds, releaseRate: rate, isComplete: complete, didWin: false,
                           isEndingRun: ending, skills: [])
    }

    private func centres(_ snapshot: MobileGameSnapshot, width: CGFloat, paused: Bool = false, speed: Double = 1,
                         lost: Int = 0, engine: String = "classic") -> [String: CGFloat] {
        let details = MobileHUDRenderer.StatusDetails(lostCount: lost,
            deathCounter: (lost == 0 ? "SAFE" : "\(lost)/21 💀", ""), engineIdentifier: engine)
        let fields = MobileHUDRenderer.statusFields(in: CGRect(x: 0, y: 0, width: width, height: 44),
            snapshot: snapshot, details: details, engineIdentifier: engine, paused: paused, speed: speed, typography: nil)
        return Dictionary(uniqueKeysWithValues: fields.map { ($0.id, $0.frame.midX) })
    }

    func testStatisticsKeepTheirCentresAsValuesChange() {
        for width: CGFloat in [400, 900, 1700] {
            for engine in ["classic", "lemmings2", "lemmings3"] {
                let start = centres(snapshot(released: 1, saved: 0, seconds: 65, rate: 1), width: width, engine: engine)
                let later = centres(snapshot(released: 100, saved: 100, seconds: 599, rate: 99, ending: true),
                                    width: width, speed: 0.5, lost: 21, engine: engine)
                let paused = centres(snapshot(released: 42, saved: 7, seconds: 9, rate: 50), width: width,
                                     paused: true, speed: 16, lost: 3, engine: engine)
                for (id, centre) in start where id != "state" {
                    XCTAssertEqual(later[id] ?? -1, centre, accuracy: 1, "\(id) moved at width \(width) in \(engine)")
                    XCTAssertEqual(paused[id] ?? -1, centre, accuracy: 1, "\(id) moved at width \(width) in \(engine)")
                }
                if let ending = later["state"], let pause = paused["state"] {
                    XCTAssertEqual(ending, pause, accuracy: 1, "state moved at width \(width) in \(engine)")
                }
            }
        }
    }
}
#endif
