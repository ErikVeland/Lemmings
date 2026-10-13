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
        let progressStorage = MobileStorage(directory: root.appendingPathComponent("Progress", isDirectory: true))
        let installed = store.dataDirectory(for: .lemmings2)
        let sourceCampaign = try Lemmings2Campaign(root: installed)
        let results = Dictionary(uniqueKeysWithValues: sourceCampaign.levels.enumerated().map { index, level in
            (index, Lemmings2Campaign.Result(startingPopulation: 60, saved: 60,
                medal: Lemmings2Campaign.medal(saved: 60, total: 60,
                                               allowedLosses: level.allowedLossesForGold),
                levelFingerprint: level.fingerprint))
        })
        try progressStorage.save(Lemmings2Campaign.Progress(tribe: 1, level: 0, results: results),
                                 name: "lemmings2-campaign")
        let library = try #require(try store.loadLemmings2Library(storage: progressStorage))
        #expect(library.levels.count == 120)

        let checkpointIndices = Set(stride(from: 0, to: library.levels.count, by: 10))
        for index in library.levels.indices {
            let session = try library.loadLevel(at: index).session
            let frame = try session.render(highlight: nil)
            #expect(frame.width > 0)
            #expect(frame.height > 0)
            session.tick()
            if checkpointIndices.contains(index) {
                let checkpoint = try session.checkpointPayload()
                let resumed = try library.loadLevel(at: index).session
                try resumed.restoreCheckpointPayload(checkpoint)
                #expect(resumed.snapshot == session.snapshot)
            }
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

        let checkpointIndices: Set<Int> = [0, 15, 29, 30, 45, 59, 60, 75, 89]
        for index in library.levels.indices {
            let session = try library.loadLevel(at: index).session
            let frame = try session.render(highlight: nil)
            #expect(frame.width > 0)
            #expect(frame.height > 0)
            session.tick()
            if checkpointIndices.contains(index) {
                let checkpoint = try session.checkpointPayload()
                let resumed = try library.loadLevel(at: index).session
                try resumed.restoreCheckpointPayload(checkpoint)
                #expect(resumed.snapshot == session.snapshot)
            }
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
