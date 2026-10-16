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
        let styleResolved = library.styleResolvedLevelIndices
        let first = try #require(styleResolved.first)
        let middle = styleResolved[styleResolved.count / 2]
        let last = try #require(styleResolved.last)
        for index in Set([first, middle, last]) {
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

    @Test
    func keepsImportedLevelsWithMissingStylesVisibleAndGated() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("NeoLemmixMissingStyle-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let pack = root.appendingPathComponent("levels", isDirectory: true)
        try FileManager.default.createDirectory(at: pack.appendingPathComponent("styles", isDirectory: true),
                                                withIntermediateDirectories: true)
        try "TITLE Example pack\n".write(to: pack.appendingPathComponent("info.nxmi"),
                                            atomically: true, encoding: .utf8)
        try "LEVEL community.nxlv\n".write(to: pack.appendingPathComponent("levels.nxmi"),
                                              atomically: true, encoding: .utf8)
        try """
        TITLE Community level
        ID x0000000000000001
        WIDTH 160
        HEIGHT 80
        LEMMINGS 1
        SAVE_REQUIREMENT 1
        $TERRAIN
          STYLE missing_community_style
          PIECE block
          X 0
          Y 0
        $END
        """.write(to: pack.appendingPathComponent("community.nxlv"),
                  atomically: true, encoding: .utf8)

        let library = try NeoLemmixMobileLibrary(directory: pack,
            storage: MobileStorage(directory: root.appendingPathComponent("Progress", isDirectory: true)))
        #expect(library.levels.count == 1)
        #expect(library.levels[0].title == "Community level")
        #expect(library.styleResolvedLevelIndices.isEmpty)

        do {
            _ = try library.loadLevel(at: 0)
            Issue.record("A level with a missing style started without a gate.")
        } catch {
            #expect(error.localizedDescription.contains("Community level"))
        }
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
        let supportedIndices = library.styleResolvedLevelIndices
        #expect(!supportedIndices.isEmpty)

        for index in supportedIndices {
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
