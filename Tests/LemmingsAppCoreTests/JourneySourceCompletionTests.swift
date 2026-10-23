import Foundation
import NxlvKit
import Testing
@testable import LemmingsAppCore

@MainActor struct JourneySourceCompletionTests {
    private func entry(pack: String, level: String, name: String = "Lesson", number: Int = 1) throws -> LevelPlaylistEntry {
        try .init(identity: .init(engine: .classic, packID: pack, levelID: level),
            catalogueRevision: "fixture", sourceRevision: "fixture", packNameSnapshot: "Pack",
            levelNameSnapshot: name, levelNumberSnapshot: number)
    }

    @Test func winsCreditTheirSourceAndNeverCountDeferredOrImportedLevelsAsRetail() throws {
        var history = LearningJourneyProgress()
        for identity in [LevelCatalogueIdentity(engine: .classic, packID: "lemmings-LEVEL-120", levelID: "4:Fun:5:9:3"),
                         .init(engine: .classic, packID: "ohNoMoreLemmings-LEVEL-100", levelID: "21:Crazy:2:1:2"),
                         .init(engine: .classic, packID: "ohYesMoreLemmings-LEVEL-60", levelID: "32:Mega Drive Sunsoft:3:2:0"),
                         .init(engine: .lemmings2, packID: "tribes-11", levelID: "9:fixture"),
                         .init(engine: .lemmings3, packID: "chronicles-3", levelID: "29:fixture"),
                         .init(engine: .classic, packID: "lemmings-LEVEL-120:source-other", levelID: "5:Fun:6:9:4"),
                         .init(engine: .classic, packID: "imported:revision:path", levelID: "6:All:7:0:6")] {
            history.record(identity, won: true)
        }
        history.record(.init(engine: .classic, packID: "lemmings-LEVEL-120", levelID: "7:Fun:8:9:7"), won: false)
        let credits = JourneySourceCompletion.progress(history)
        try credits.validate()
        #expect(credits.values["cleared/release/lemmings"] == .completed([4]))
        #expect(credits.values["cleared/release/ohNoMoreLemmings"] == .completed([21]))
        #expect(credits.values["cleared/release/ohYesMoreLemmings"] == .completed([32]))
        #expect(credits.values["cleared/release/lemmings2TheTribes"] == .completed([119]))
        #expect(credits.values["cleared/release/lemmings3TheChronicles"] == .completed([89]))
        #expect(credits.values["nativeL2Campaign.v1.bundled"] == nil)
        #expect(credits.values["nativeL3ShadowPreview.v1.bundled"] == nil)
        #expect(JourneySourceCompletion.classicIndices(packID: "imported:revision:path", learning: history) == [6])
        #expect(JourneySourceCompletion.classicIndices(packID: "imported:other:path", learning: history).isEmpty)
    }

    @Test func earlierWinsAppearInSourceProgressAndCloudWithoutReplaying() throws {
        let storage = try AppStorage.temporary(named: "journey-earlier-source-wins")
        defer { storage.removeTemporaryFiles() }
        var history = LearningJourneyProgress()
        history.record(.init(engine: .classic, packID: "lemmings-LEVEL-120", levelID: "4:Fun:5:9:3"), won: true)
        storage.defaults.set(try JSONEncoder().encode(history), forKey: "ArcadeProfile.player.LearningJourneyProgress")
        #expect(GameProgressPreferences.completed(pack: "release/lemmings", profileID: "player", defaults: storage.defaults) == [4])
        let portable = GameProgressPreferences.capture(defaults: storage.defaults, profileID: "player", profileIDs: ["player"])
        #expect(portable.values["cleared/release/lemmings"] == .completed([4]))
        let flow = GameProgressPreferences.classicProgress(nil, completed: [4], ranks: [.init(name: "Fun", levelIndices: Array(0..<30))])
        #expect(flow.passed == ["Fun#4"])
        #expect(flow.furthestReached["Fun"] == 5)
        #expect(GameProgressPreferences.completed(pack: "release/lemmings", profileID: "other", defaults: storage.defaults).isEmpty)
    }

    @Test func savedCreditsUnionCampaignAndFanWinsWithinOnlyTheirSession() throws {
        let storage = try AppStorage.temporary(named: "journey-source-scope")
        defer { storage.removeTemporaryFiles() }
        let fan = try entry(pack: "fan:lldb-42", level: "archive.dat#3", name: "A fan level", number: 8)
        let whole = try entry(pack: "fan:file-custom.zip", level: "folder/Puzzle.lvl#-1", name: "Title inside the level", number: 2)
        var history = LearningJourneyProgress()
        for identity in [fan.identity, whole.identity,
                         .init(engine: .classic, packID: "lemmings-LEVEL-120", levelID: "4:Fun:5:9:3")] {
            history.record(identity, won: true)
        }
        let key = GameProgressPreferences.completedKey(pack: "release/lemmings", profileID: "hotseat.team")
        storage.defaults.set([0, 4], forKey: key)
        storage.defaults.set([1], forKey: "mobile.completed.release/lemmings.hotseat.team")
        storage.defaults.set(["previous"], forKey: "HotSeat.team.FanLevelsPassed")
        for _ in 0..<2 {
            try GameProgressPreferences.saveLearning(history, profileID: "player", sessionID: "team",
                entries: [fan, whole], defaults: storage.defaults)
        }
        #expect(storage.defaults.array(forKey: key) as? [Int] == [0, 1, 4])
        #expect(storage.defaults.array(forKey: "mobile.completed.release/lemmings.hotseat.team") as? [Int] == [0, 1, 4])
        #expect(GameProgressPreferences.fanLevels(profileID: "player", sessionID: "team", defaults: storage.defaults)
            == ["previous", "v2|catalogue:lldb-42|A fan level", "v2|file:custom.zip|Puzzle.lvl"])
        #expect(GameProgressPreferences.completed(pack: "lldb-42", profileID: "hotseat.team", defaults: storage.defaults) == [7])
        #expect(GameProgressPreferences.completed(pack: "release/lemmings", profileID: "player", defaults: storage.defaults).isEmpty)
        #expect(GameProgressPreferences.fanLevels(profileID: "player", sessionID: "other", defaults: storage.defaults).isEmpty)
    }
}
