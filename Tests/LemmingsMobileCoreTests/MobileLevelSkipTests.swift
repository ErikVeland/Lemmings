import Foundation
import Testing
import NxlvKit
import LemmingsMobileCore

struct MobileLevelSkipTests {
    private let resources = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LEMMINGS_TEST_RESOURCES"]
        ?? "/Applications/Ultimate Lemmings.app/Contents/Resources")

    @Test func sequelSkipsPreservePopulationAndCanRollBackWithoutAwardingAClear() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for engine in [2, 3] {
            let storage = MobileStorage(directory: root.appendingPathComponent("engine-\(engine)"))
            let library: any MobileGameLibrary
            if engine == 2 { library = try Lemmings2MobileLibrary(directory: resources.appendingPathComponent("Ports/Lemm2"), storage: storage) }
            else { library = try Lemmings3MobileLibrary(directory: resources.appendingPathComponent("Ports/LEM3CD"), storage: storage) }
            let index = engine == 2 ? 10 : 0
            let available = library.canSkipLevel(at: index)
            #expect(available)
            #expect(!library.canSkipLevel(at: engine == 2 ? 19 : 29))
            let rollback = try library.prepareLevelSkip(at: index)
            let next = try library.loadLevel(at: index + 1)
            if let l2 = next.session as? Lemmings2MobileSession {
                #expect(l2.snapshot.total == 60)
                let saved = try #require(storage.load(Lemmings2Campaign.Progress.self, name: "lemmings2-campaign"))
                #expect(saved.level == 1 && saved.results[10] == nil && saved.skipped?[10] == 60)
            } else {
                let l3 = try #require(next.session as? Lemmings3MobileSession)
                #expect(l3.initialRuntime.configuration.total == 20)
                let saved = try #require(storage.load(MobileCampaignProgress.Chronicles.self, name: "lemmings3-campaign"))
                #expect(saved.progress(for: .classic)?.index == 1 && saved.progress(for: .classic)?.completed[0] == nil)
            }
            try rollback()
            #expect(library.canSkipLevel(at: index))
            if let l2 = library as? Lemmings2MobileLibrary { #expect(l2.currentLevelIndex == index) }
            if let l3 = library as? Lemmings3MobileLibrary { #expect(l3.currentLevelIndex == 0) }
        }
    }

    @Test func failedCampaignSaveDoesNotMoveTheLevel() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for engine in [2, 3] {
            let blocked = root.appendingPathComponent("engine-\(engine)")
            try Data([1]).write(to: blocked)
            let storage = MobileStorage(directory: blocked)
            let library: any MobileGameLibrary
            if engine == 2 { library = try Lemmings2MobileLibrary(directory: resources.appendingPathComponent("Ports/Lemm2"), storage: storage) }
            else { library = try Lemmings3MobileLibrary(directory: resources.appendingPathComponent("Ports/LEM3CD"), storage: storage) }
            let index = engine == 2 ? 10 : 0
            #expect(throws: (any Error).self) { _ = try library.prepareLevelSkip(at: index) }
            let available = library.canSkipLevel(at: index)
            #expect(available)
        }
    }
}
