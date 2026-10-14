import Foundation
import Testing
import LemmingsMobileCore
@testable import LemmingsMobileUI

struct NeoLemmixMobileDataTests {
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
