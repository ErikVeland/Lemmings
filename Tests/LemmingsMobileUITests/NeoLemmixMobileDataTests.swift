import Foundation
import Testing
import LemmingsMobileCore
@testable import LemmingsMobileUI

struct NeoLemmixMobileDataTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["LEMMINGS_MOBILE_BUNDLED_RESOURCES"] != nil))
    func opensBundledNeoLemmixWithoutAnImport() throws {
        let resources = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["LEMMINGS_MOBILE_BUNDLED_RESOURCES"]))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MobileContentStore(root: root.appendingPathComponent("Support"))
        let directory = try #require(store.resolvedDataDirectory(for: .neoLemmix, bundledResources: resources))
        let library = try NeoLemmixMobileLibrary(directory: directory,
            storage: MobileStorage(directory: root.appendingPathComponent("Progress")))
        #expect(!library.levels.isEmpty)
        for index in Set([0, library.levels.count / 2, library.levels.count - 1]) {
            let session = try library.loadLevel(at: index).session
            let frame = try session.render(highlight: nil)
            #expect(frame.width > 0 && frame.height > 0)
            session.tick()
            let checkpoint = try session.checkpointPayload()
            let restored = try library.loadLevel(at: index).session
            try restored.restoreCheckpointPayload(checkpoint)
            #expect(restored.snapshot == session.snapshot)
        }
        #expect(!FileManager.default.fileExists(atPath: store.root.path))
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LEMMINGS_MOBILE_NEOLEMMIX_DATA"] != nil))
    func opensRendersAndRestoresEverySupportedPlayerOwnedNeoLemmixLevel() throws {
        let sourcePath = try #require(ProcessInfo.processInfo.environment["LEMMINGS_MOBILE_NEOLEMMIX_DATA"])
        let source = URL(fileURLWithPath: sourcePath, isDirectory: true)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("NeoLemmixMobileData-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = MobileContentStore(root: root.appendingPathComponent("Support", isDirectory: true))
        try store.install(directory: source, for: .neoLemmix)
        let library = try NeoLemmixMobileLibrary(
            directory: store.dataDirectory(for: .neoLemmix),
            storage: MobileStorage(directory: root.appendingPathComponent("Progress", isDirectory: true)))
        #expect(!library.levels.isEmpty)

        for index in library.levels.indices {
            let session = try library.loadLevel(at: index).session
            let frame = try session.render(highlight: nil)
            #expect(frame.width > 0)
            #expect(frame.height > 0)
            session.tick()

            let checkpoint = try session.checkpointPayload()
            let resumed = try library.loadLevel(at: index).session
            try resumed.restoreCheckpointPayload(checkpoint)
            #expect(resumed.snapshot == session.snapshot)
        }
    }
}
