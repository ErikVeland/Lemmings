import Foundation
import Testing
@testable import NxlvKit

struct LevelCatalogueTests {
    @Test func resolvesTheFullTypedIdentity() throws {
        let classic = LevelCatalogueIdentity(
            engine: .classic, packID: "original", levelID: "fun-1")
        let sequel = LevelCatalogueIdentity(
            engine: .lemmings2, packID: "original", levelID: "fun-1")
        let entry = LevelCatalogueEntry(
            identity: classic,
            packName: "Lemmings",
            levelName: "Just dig!",
            number: 1,
            status: .complete)
        let catalogue = LevelCatalogue(
            revision: "fixture-1",
            packs: [LevelCataloguePack(
                engine: .classic,
                id: "original",
                name: "Lemmings",
                status: .complete,
                levels: [entry])])

        #expect(catalogue.resolve(classic) == entry)
        #expect(catalogue.resolve(sequel) == nil)
    }

    @Test func packRejectsEntriesFromAnotherEngineOrPack() {
        let accepted = LevelCatalogueEntry(
            identity: .init(engine: .classic, packID: "fan-1", levelID: "a"),
            packName: "Fan One", levelName: "A", number: 1, status: .playable)
        let wrongEngine = LevelCatalogueEntry(
            identity: .init(engine: .lemmings3, packID: "fan-1", levelID: "b"),
            packName: "Fan One", levelName: "B", number: 2, status: .preview)
        let wrongPack = LevelCatalogueEntry(
            identity: .init(engine: .classic, packID: "fan-2", levelID: "c"),
            packName: "Fan Two", levelName: "C", number: 3, status: .playable)

        let pack = LevelCataloguePack(
            engine: .classic, id: "fan-1", name: "Fan One",
            status: .playable, levels: [accepted, wrongEngine, wrongPack])

        #expect(pack.levels == [accepted])
        #expect(pack.availableLevelCount == 1)
    }

    @Test func catalogueRoundTripKeepsRevisionAndReleaseBoundary() throws {
        let locked = LevelCatalogueEntry(
            identity: .init(engine: .lemmings2, packID: "beach", levelID: "2"),
            packName: "Beach", levelName: "Level 2", number: 2,
            status: .preview, isAvailable: false)
        let original = LevelCatalogue(
            revision: "catalogue-42",
            packs: [.init(
                engine: .lemmings2, id: "beach", name: "Beach",
                status: .preview, levels: [locked])])

        let restored = try JSONDecoder().decode(
            LevelCatalogue.self, from: JSONEncoder().encode(original))

        #expect(restored.revision == "catalogue-42")
        #expect(restored.resolve(locked.identity)?.status == .preview)
        #expect(restored.resolve(locked.identity)?.isAvailable == false)
    }
}
