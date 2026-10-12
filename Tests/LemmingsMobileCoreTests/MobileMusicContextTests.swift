import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobileMusicContextTests {
    @Test func arrangementCyclesCountTheRealCampaignOccurrences() {
        var titles = (0..<35).map { "Level \($0)" }
        let tune = MobileMusicAssignment.tune(identifier: "lemmings-LEVEL-120/Fun/18", index: 17, title: titles[17])
        #expect(MobileMusicAssignment.cycle(tune: tune, index: 17, titles: titles, isFan: false) == 1)
        #expect(MobileMusicAssignment.cycle(tune: tune, index: 34, titles: titles, isFan: false) == 2)
        titles[0] = "A Beast of a level"
        #expect(MobileMusicAssignment.cycle(tune: tune, index: 17, titles: titles, isFan: false) == 0)
        #expect(MobileMusicAssignment.cycle(tune: tune, index: 17, titles: titles, isFan: true) == 1)
    }
    @Test func journeyContextRetainsItsFullScorePosition() {
        let context = MobileMusicContext(scorePosition: 20, titles: (0..<40).map { "Lesson \($0)" },
                                         isFan: true, isLearningJourney: true)
        let tune = MobileMusicAssignment.tune(identifier: "fan/lldb-547/revision/level.dat#0",
            index: context.scorePosition ?? 0, title: context.titles[20])
        #expect(tune.track == LevelMusicSelection.classic[3])
        #expect(MobileMusicAssignment.cycle(tune: tune, index: context.scorePosition ?? 0,
            titles: context.titles, isFan: context.isFan) == 1)
    }
}
