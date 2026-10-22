import Foundation
import Testing
import NxlvKit
@testable import LemmingsMobileCore

struct BundledFanScopeTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["LEMMINGS_TEST_APP"] != nil))
    func catalogueCountsShuffleAndPlaybackUseTheSameExactScope() throws {
        let app = try #require(ProcessInfo.processInfo.environment["LEMMINGS_TEST_APP"])
        let resources = URL(fileURLWithPath: app).appendingPathComponent("Contents/Resources")
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let manifest = try Data(contentsOf: project.appendingPathComponent("Resources/Progression/bundled-playable-exclusions.json"))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bundled = root.appendingPathComponent("LevelPacks"), imported = root.appendingPathComponent("Imports")
        try FileManager.default.createDirectory(at: bundled, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: imported, withIntermediateDirectories: true)
        let names = ["0386-Gronklems-1.zip", "0437-Level-Design-Game-08.zip",
                     "0508-KillerMasters-Lemmings-1-Wicked.zip", "0509-KillerMasters-Lemmings-1-Havoc.zip"]
        var counts: [String: Int] = [:]
        for name in names {
            let destination = bundled.appendingPathComponent(name)
            try FileManager.default.copyItem(at: resources.appendingPathComponent("LevelPacks/" + name), to: destination)
            counts[name] = try ClassicFanPack(url: destination).entries().count
        }
        try JSONEncoder().encode(counts).write(to: bundled.appendingPathComponent("level-counts.json"))
        let scope = try BundledPlayableScope(directory: bundled, manifest: manifest)
        let ports = resources.appendingPathComponent("Ports")
        let catalogue = MobileCatalogue(portsRoot: ports, fanFolders: [bundled], bundledScope: scope)
        var expected = 0
        for item in catalogue.packs(in: .fan) {
            guard case let .fan(file) = item.source else { Issue.record("Expected fan pack"); continue }
            let pack = try ClassicFanPack(url: file)
            let excluded = scope.members(in: file, archiveSHA256: pack.fingerprint)
            #expect(excluded.count == 1)
            let library = try #require(try catalogue.library(for: item) as? ClassicFanMobileLibrary)
            #expect(library.entries.count == counts[file.lastPathComponent]! - 1)
            #expect(item.levelCount == library.entries.count)
            #expect(library.entries.allSatisfy { !excluded.contains($0.key) })
            for index in library.entries.indices {
                #expect(try library.checkpointLevelIdentifier(at: index)?.hasSuffix(library.entries[index].key) == true)
                let originalIndex = try #require(pack.entries().firstIndex { $0.key == library.entries[index].key })
                let checkpoint = MobileCheckpointEnvelope(runID: UUID(), engine: "classic", engineFingerprint: "fixture",
                    levelIdentifier: try #require(try library.checkpointLevelIdentifier(at: index)), levelIndex: originalIndex,
                    levelFingerprint: "fixture", tick: 0, selectedControl: 0,
                    camera: .init(origin: .init(x: 0, y: 0), zoom: 1), payload: Data())
                #expect(try library.checkpointLevelIndex(for: checkpoint) == index)
            }
            expected += library.entries.count
            let copy = imported.appendingPathComponent(file.lastPathComponent)
            try FileManager.default.copyItem(at: file, to: copy)
            #expect(try ClassicFanMobileLibrary(packURL: copy, portsRoot: ports, bundledScope: scope).entries.count == pack.entries().count)
        }
        #expect(catalogue.fanPool().entries.count == expected)
        catalogue.updateMeasuredCounts(counts)
        #expect(catalogue.packs(in: .fan).compactMap(\.levelCount).reduce(0, +) == expected)
    }
}
