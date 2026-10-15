import Foundation
import LemmingsAppCore
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobileBundledContentTests {
    @Test func resolvesBundledContentWithoutCopyingItAndPrefersImports() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let resources = root.appendingPathComponent("Test.app")
        let store = MobileContentStore(root: root.appendingPathComponent("Support"))
        let paths: [MobileGameDataKind: String] = [
            .classic: "BetaGameData", .lemmings2: "Ports/Lemm2",
            .lemmings3: "Ports/LEM3CD", .neoLemmix: "NeoLemmix",
        ]
        for kind in MobileGameDataKind.allCases {
            #expect(store.resolvedDataDirectory(for: kind, bundledResources: resources) == nil)
            let bundled = resources.appendingPathComponent(try #require(paths[kind]), isDirectory: true)
            try FileManager.default.createDirectory(at: bundled, withIntermediateDirectories: true)
            #expect(store.resolvedDataDirectory(for: kind, bundledResources: resources) == bundled)
            #expect(!FileManager.default.fileExists(atPath: store.root.path))
        }
        for kind in MobileGameDataKind.allCases {
            let installed = store.dataDirectory(for: kind)
            try FileManager.default.createDirectory(at: installed, withIntermediateDirectories: true)
            #expect(store.resolvedDataDirectory(for: kind, bundledResources: resources) == installed)
            #expect(store.resolvedDataDirectory(for: kind, bundledResources: nil) == installed)
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LEMMINGS_MOBILE_BUNDLED_RESOURCES"] != nil))
    @MainActor func opensBundledSequelCampaignsWithoutAnImport() throws {
        let resources = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["LEMMINGS_MOBILE_BUNDLED_RESOURCES"]))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MobileContentStore(root: root.appendingPathComponent("Support"))
        let progress = MobileStorage(directory: root.appendingPathComponent("Progress"))
        let appStorage = try AppStorage.temporary(named: "bundled-sequel-start")
        defer { appStorage.removeTemporaryFiles() }
        let records = ArcadeStore(storage: appStorage, bundledProofs: nil)
        let l2 = try #require(try store.loadLemmings2Library(storage: progress, bundledResources: resources))
        let l3 = try #require(try store.loadLemmings3Library(storage: progress, bundledResources: resources))
        #expect(l2.levels.count == 120)
        #expect(l3.levels.count == 90)
        let libraries: [any MobileGameLibrary] = [l2, l3]
        for library in libraries {
            let session = try library.loadLevel(at: 0).session
            let level = ArcadeLevel(id: session.levelFingerprint, title: library.levels[0].title,
                game: library.displayName, rules: session.engineFingerprint,
                total: session.snapshot.total, required: session.snapshot.required)
            #expect(records.beginAttempt(id: UUID(), profileID: records.records.activeProfileID, level: level, previousID: nil))
            let frame = try session.render(highlight: nil)
            #expect(frame.width > 0 && frame.height > 0)
            session.tick()
            let checkpoint = try session.checkpointPayload()
            let restored = try library.loadLevel(at: 0).session
            try restored.restoreCheckpointPayload(checkpoint)
            #expect(restored.snapshot == session.snapshot)
        }
        #expect(!FileManager.default.fileExists(atPath: store.root.path))
    }
}
