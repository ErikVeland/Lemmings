import Foundation
import LemmingsAppCore
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobileProgressionBuilderTests {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    private static let ports = root.appendingPathComponent(".build/ios-ports")

    @Test func realCampaignSkillsAndPopulationReachTheSharedScorer() async throws {
        let directory = Self.ports.appendingPathComponent("lemmings_dos_1991-07-30")
        let library = try ClassicMobileLibrary(directory: directory)
        let authored = library.dataSet.campaign.levels[0]
        let revisionsURL = Self.ports.appendingPathComponent("source-revisions.json")
        let revisions = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: revisionsURL))
        let packPrefix = try #require(library.dataSet.identifierKey.split(separator: "-").first.map(String.init))
        let revision = try #require(revisions[packPrefix])
        let entry = try LevelPlaylistEntry(identity: .init(engine: .classic, packID: library.dataSet.identifierKey,
            levelID: "0:\(authored.rank):\(authored.number):\(authored.archiveFile):\(authored.archiveSection)"),
            catalogueRevision: "1.2-runtime-v2", sourceRevision: revision,
            packNameSnapshot: library.displayName, levelNameSnapshot: authored.level.title, levelNumberSnapshot: 1)
        let corpus = try MobileProgressionBuilder.inputs(portsRoot: Self.ports, fanFolders: [], entries: [entry])
        #expect(corpus.failures.isEmpty)
        #expect(corpus.inputs.count == 1)
        let input = try #require(corpus.inputs.first)
        if case let .classic(level, _, _, _) = input.source {
            #expect(level.lemmingCount == authored.level.lemmingCount)
            #expect(level.lemmingCount > 1)
            #expect(level.skills == authored.level.skills)
            #expect(level.skills[.digger, default: 0] > 1)
        } else { Issue.record("Official level did not reach the Classic analyser.") }
        let storage = try AppStorage.temporary(named: "mobile-progression")
        defer { storage.removeTemporaryFiles() }
        let result = try await MobileProgressionBuilder.generate(portsRoot: Self.ports, fanFolders: [], entries: [entry],
            policy: .smooth, storage: storage)
        #expect(result.entries == [entry])
        #expect(FileManager.default.fileExists(atPath: DifficultyLibrary.directory(storage: storage).appendingPathComponent("profiles.json").path))
        let changed = try LevelPlaylistEntry(identity: entry.identity, catalogueRevision: entry.catalogueRevision,
            sourceRevision: "changed", packNameSnapshot: entry.packNameSnapshot,
            levelNameSnapshot: entry.levelNameSnapshot, levelNumberSnapshot: 1)
        let rejected = try MobileProgressionBuilder.inputs(portsRoot: Self.ports, fanFolders: [], entries: [changed])
        #expect(rejected.inputs.isEmpty)
        #expect(rejected.failures.count == 1)
    }
}

struct MobileFanCountStoreTests {
    @Test func measuredCountsSurviveRelaunchAndChangedPacksAreMeasuredAgain() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let packs = root.appendingPathComponent("Content/LevelPacks")
        let originals = try FileManager.default.contentsOfDirectory(at: packs, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "zip" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        let first = try #require(originals.first), second = try #require(originals.dropFirst().first)
        let storage = try AppStorage.temporary(named: "mobile-fan-counts")
        defer { storage.removeTemporaryFiles() }
        let folder = storage.applicationSupport.appendingPathComponent("FixturePacks")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appendingPathComponent(first.lastPathComponent)
        try FileManager.default.copyItem(at: first, to: target)
        let measured = try await MobileFanCountStore(storage: storage).measure(fanFolders: [folder])
        #expect(measured[first.lastPathComponent] == (try ClassicFanPack(url: first).entries().count))
        let restored = try await MobileFanCountStore(storage: storage).measure(fanFolders: [folder])
        #expect(restored == measured)
        try FileManager.default.removeItem(at: target)
        try FileManager.default.copyItem(at: second, to: target)
        let changed = try await MobileFanCountStore(storage: storage).measure(fanFolders: [folder])
        #expect(changed[first.lastPathComponent] == (try ClassicFanPack(url: second).entries().count))
    }
}
