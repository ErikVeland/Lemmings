import Foundation
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobileLevelSourceTests {
    @Test func preparationFailureRemainsVisibleUntilTheNextRequest() {
        let level = MobileLevelSummary(index: 0, rank: "Classic", number: 1, title: "Level",
                                       origin: .official, packName: "Lemmings 2")
        let error = "The attempt was not saved."
        #expect(level.selectionSubtitle(rankCount: 10, status: "Loading...") == "Loading...")
        #expect(level.selectionSubtitle(rankCount: 10, status: error) == error)
        #expect(level.selectionSubtitle(rankCount: 10).contains("Classic  1/10"))
        #expect(level.selectionSubtitle(rankCount: 10).contains("Official / Lemmings 2"))
    }
    @Test func oldSummariesRemainReadableWithoutInventingAnOrigin() throws {
        let data = Data(#"{"index":0,"rank":"Fun","number":1,"title":"Just dig!"}"#.utf8)
        let level = try JSONDecoder().decode(MobileLevelSummary.self, from: data)
        #expect(level.origin == .unspecified)
        #expect(level.sourceLabel.isEmpty)
        #expect(level.title == "Just dig!")
    }
    @Test func savedSourceSurvivesACollectionChangingItsRankAndPosition() throws {
        let level = MobileLevelSummary(index: 31, rank: "Journey", number: 32,
            title: "An official-sounding fan level", origin: .fanMade, packName: "Community pack")
        let restored = try JSONDecoder().decode(MobileLevelSummary.self, from: JSONEncoder().encode(level))
        #expect(restored == level)
        #expect(restored.caption == "Fan-made / Community pack\nJourney 32")
    }
    @Test func engineDoesNotMakeOfficialSequelsFanMade() {
        for engine in [LevelSourceEngine.classic, .lemmings2, .lemmings3] {
            #expect(LevelCatalogueIdentity(engine: engine, packID: "release", levelID: "0").originLabel == "Official")
            #expect(LevelCatalogueIdentity(engine: engine, packID: "fan:pack", levelID: "0").originLabel == "Fan-made")
        }
        #expect(LevelCatalogueIdentity(engine: .classic, packID: "lldb-123", levelID: "0").originLabel == "Fan-made")
        #expect(LevelCatalogueIdentity(engine: .neolemmix, packID: "pack", levelID: "0").originLabel == "Fan-made")
    }
}
