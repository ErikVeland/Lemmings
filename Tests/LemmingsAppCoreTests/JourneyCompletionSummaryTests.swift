import Foundation
import NxlvKit
import Testing
@testable import LemmingsAppCore

@MainActor struct JourneyCompletionSummaryTests {
    @Test func nativeMobileCloudAndJourneyWinsCountOnceWithoutWriting() throws {
        let storage = try AppStorage.temporary(named: "shared-completion-summary")
        defer { storage.removeTemporaryFiles() }
        let defaults = storage.defaults, prefix = "HotSeat.team."
        let encoder = JSONEncoder()
        defaults.set(try encoder.encode(ClassicGameFlow.Progress(furthestReached: [:], passed: ["Fun#0", "Tricky#0"])),
            forKey: prefix + "ClassicGameProgress.lemmings-LEVEL-120")
        defaults.set([0, 1, 30], forKey: "mobile.completed.release/lemmings.hotseat.team")
        defaults.set([0, 1, 30], forKey: GameProgressPreferences.completedKey(pack: "release/lemmings", profileID: "hotseat.team"))
        defaults.set([99], forKey: "mobile.completed.release/lemmings.hotseat.other")
        defaults.set([98], forKey: "mobile.completed.release/lemmings.player")
        let result = Lemmings2Campaign.Result(startingPopulation: 60, saved: 60, medal: .gold, levelFingerprint: "fixture")
        let l2 = Lemmings2Campaign.Progress(tribe: 0, level: 2, results: [0: result, 1: result])
        let l3 = Lemmings3ClassicCampaign.Progress(index: 2, population: 20, completed: [0: 20, 1: 20], tribe: .classic)
        defaults.set(try encoder.encode(l2), forKey: prefix + "nativeL2Campaign.v1.bundled")
        var history = LearningJourneyProgress()
        for identity in [LevelCatalogueIdentity(engine: .classic, packID: "lemmings-LEVEL-120", levelID: "0:Fun:1:9:1"),
                         .init(engine: .classic, packID: "lemmings-LEVEL-120:source-old", levelID: "passed:Fun#0"),
                         .init(engine: .lemmings2, packID: "tribes-0", levelID: "0:fixture"),
                         .init(engine: .lemmings3, packID: "chronicles-1", levelID: "0:fixture")] {
            history.record(identity, won: true)
        }
        history.record(.init(engine: .classic, packID: "deferred", levelID: "later"), won: false)
        let before = defaults.dictionaryRepresentation()
        let extra = GameProgressPreferences(values: ["nativeL2Campaign.v1.bundled": .tribes(l2),
            "nativeL3ClassicPreview.v1.bundled": .chronicles(l3)])
        #expect(JourneyCompletionSummary.count(profileID: "player", hotSeatID: "team", learning: history,
            profileIDs: ["player", "guest"], additionalProgress: extra, defaults: defaults) == 8)
        #expect(JourneyCompletionSummary.count(profileID: "player", hotSeatID: "empty", learning: .init(),
            defaults: defaults) == 0)
        #expect(NSDictionary(dictionary: before).isEqual(to: defaults.dictionaryRepresentation()))
    }

    @Test func defaultMobilePlayerDoesNotInheritOtherProfilesOrHotSeats() throws {
        let storage = try AppStorage.temporary(named: "default-summary-scope")
        defer { storage.removeTemporaryFiles() }
        storage.defaults.set([0], forKey: "mobile.completed.release/lemmings")
        storage.defaults.set([1], forKey: "mobile.completed.release/lemmings.guest")
        storage.defaults.set([2], forKey: "mobile.completed.release/lemmings.hotseat.team")
        #expect(JourneyCompletionSummary.count(profileID: "default", hotSeatID: nil, learning: .init(),
            profileIDs: ["default", "guest"], defaults: storage.defaults) == 1)
        #expect(JourneyCompletionSummary.count(profileID: "guest", hotSeatID: nil, learning: .init(),
            profileIDs: ["default", "guest"], defaults: storage.defaults) == 1)
    }
}
