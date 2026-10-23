import Foundation
import Testing
@testable import NxlvKit

struct FanLevelOrganisationTests {
    private var content: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Content/LevelPacks")
    }
    private func installed() throws -> [FanLevelOrganisation.Pack] {
        try FileManager.default.contentsOfDirectory(at: content, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "zip" }
            .map { .init(id: ClassicFanPack.catalogueID($0), title: ClassicFanPack.displayName(of: $0)) }
    }
    private func descendants(_ group: FanLevelOrganisation.Group) -> [FanLevelOrganisation.Group] {
        [group] + group.children.flatMap(descendants)
    }

    @Test func everyInstalledPackAppearsExactlyOnceOnBoundedPages() throws {
        let packs = try installed()
        #expect(packs.count >= 535)
        let root = FanLevelOrganisation.library(packs)
        #expect(root.packIDs.count == packs.count)
        #expect(Set(root.packIDs) == Set(packs.map(\.id)))
        #expect(descendants(root).allSatisfy { $0.children.count <= FanLevelOrganisation.maximumRows })
        #expect(root.children.map(\.id) == ["learning", "magazines", "fan", "community", "ports"])
        #expect(root == FanLevelOrganisation.library(Array(packs.reversed())))
    }

    @Test func numberedAndSplitCollectionsStayTogether() throws {
        let groups = descendants(FanLevelOrganisation.library(try installed()))
        for (title, ids) in [("Mikepak", [5, 6, 19]), ("ISteve", [20, 21, 138]),
                             ("geoo", [1, 2, 108, 388, 461]), ("Timpack", [88, 98, 99, 104]),
                             ("JUANJO", [290, 294, 295, 297]), ("weirdy", [133, 137]),
                             ("grams88", [209, 211, 416]), ("ClamSpam", [32, 382, 410]),
                             ("KillerMaster's Lemmings", [505, 509, 510, 511]),
                             ("cLemmings", [526, 529]), ("PSP Special", [216, 217, 218])] {
            let group = try #require(groups.first { $0.title == title && $0.packID == nil })
            #expect(Set(ids.map { "lldb-\($0)" }).isSubset(of: Set(group.packIDs)))
        }
        let mike = try #require(groups.first { $0.title == "Mikepak" && $0.packID == nil })
        #expect(mike.packIDs.prefix(3) == ["lldb-5", "lldb-6", "lldb-7"])
        #expect(mike.packIDs.last == "lldb-19")
    }

    @Test func learningMagazinesAndContestsHaveTheirOwnHomes() throws {
        let root = FanLevelOrganisation.library(try installed())
        for (category, ids) in [("learning", [400, 409]), ("magazines", [577, 578, 579, 580, 584, 585, 594]),
                                ("community", [207, 214, 430, 438, 450]), ("ports", [80, 473, 488, 568])] {
            let group = try #require(root.group(at: [category]))
            #expect(Set(ids.map { "lldb-\($0)" }).isSubset(of: Set(group.packIDs)))
        }
    }

    @Test func searchDownloadsDuplicateIDsAndEmptyLibrariesKeepStableAddresses() {
        let packs: [FanLevelOrganisation.Pack] = [.init(id: "old", title: "Example 2"), .init(id: "new", title: "Example 10")]
        let root = FanLevelOrganisation.library(packs + [packs[0]], query: "EXAMPLE")
        #expect(root.packIDs == ["old", "new"])
        #expect(root.group(at: ["fan", "series:example"])?.packIDs == ["old", "new"])
        #expect(root.group(at: ["missing"]) == nil)
        #expect(FanLevelOrganisation.library(packs, query: "unknown").children.isEmpty)
        #expect(FanLevelOrganisation.library([]).packIDs.isEmpty)
        let numeric = FanLevelOrganisation.library([.init(id: "year", title: "2112")])
        #expect(numeric.packIDs == ["year"])
    }

    @Test func mixedCaseNamesKeepTheSameAlphabeticalOrder() {
        let packs: [FanLevelOrganisation.Pack] = [
            .init(id: "clam", title: "ClamSpam01"), .init(id: "clem", title: "cLemmings Fun"),
            .init(id: "conway", title: "Conway01")
        ]
        for order in [packs, Array(packs.reversed()), [packs[1], packs[0], packs[2]]] {
            #expect(FanLevelOrganisation.library(order).packIDs == ["clam", "clem", "conway"])
        }
    }
}
