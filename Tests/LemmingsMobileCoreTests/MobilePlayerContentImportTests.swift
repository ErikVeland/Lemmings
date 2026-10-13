import Foundation
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobilePlayerContentImportTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["LEMMINGS_MOBILE_L2_DATA"] != nil))
    @MainActor
    func importsAndRendersPlayerOwnedLemmings2Data() throws {
        let source = try #require(Self.source("LEMMINGS_MOBILE_L2_DATA"))
        let root = Self.temporaryRoot("L2")
        defer { try? FileManager.default.removeItem(at: root) }

        let store = MobileContentStore(root: root.appendingPathComponent("Support", isDirectory: true))
        try store.install(directory: source, for: .lemmings2)
        let library = try #require(try store.loadLemmings2Library(
            storage: MobileStorage(directory: root.appendingPathComponent("Progress", isDirectory: true))))
        #expect(library.levels.count == 120)

        for index in stride(from: 0, to: library.levels.count, by: 10) {
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

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LEMMINGS_MOBILE_L3_DATA"] != nil))
    @MainActor
    func importsAndRendersPlayerOwnedLemmings3Data() throws {
        let source = try #require(Self.source("LEMMINGS_MOBILE_L3_DATA"))
        let root = Self.temporaryRoot("L3")
        defer { try? FileManager.default.removeItem(at: root) }

        let store = MobileContentStore(root: root.appendingPathComponent("Support", isDirectory: true))
        try store.install(directory: source, for: .lemmings3)
        let library = try #require(try store.loadLemmings3Library(
            storage: MobileStorage(directory: root.appendingPathComponent("Progress", isDirectory: true))))
        #expect(library.levels.count == 90)

        for index in [0, 30, 60] {
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

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LEMMINGS_MOBILE_NEOLEMMIX_DATA"] != nil))
    func validatesAndInstallsPlayerOwnedNeoLemmixPacks() throws {
        let source = try #require(Self.source("LEMMINGS_MOBILE_NEOLEMMIX_DATA"))
        let root = Self.temporaryRoot("NeoLemmix")
        defer { try? FileManager.default.removeItem(at: root) }

        let store = MobileContentStore(root: root.appendingPathComponent("Support", isDirectory: true))
        try store.install(directory: source, for: .neoLemmix)
        let installed = store.dataDirectory(for: .neoLemmix)
        #expect(FileManager.default.fileExists(atPath: installed.path))
        let supported = NeoLemmixLibrary.discover([.init(
            levelsRoot: MobileNeoLemmixDataLayout.levelsRoot(in: installed),
            stylesRoot: MobileNeoLemmixDataLayout.stylesRoot(in: installed)
        )]).flatMap { pack in pack.pack.levels.filter { pack.stylesRoot(for: $0) != nil } }
        #expect(!supported.isEmpty)
    }

    private static func source(_ key: String) -> URL? {
        guard let path = ProcessInfo.processInfo.environment[key], !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private static func temporaryRoot(_ suffix: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MobilePlayerContent-\(suffix)-\(UUID().uuidString)", isDirectory: true)
    }

}
