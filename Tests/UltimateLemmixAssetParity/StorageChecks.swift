import Foundation

@main struct StorageChecks {
    @MainActor static func main() {
        do { try run() }
        catch { print("FAIL: \(error)"); exit(1) }
    }

    @MainActor private static func run() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let rootPath = environment["LEMMINGS_TEST_APPLICATION_SUPPORT"],
              let fixturePath = environment["LEMMIX_PARITY_STORAGE_FIXTURE"] else {
            print("FAIL: isolated storage fixture is missing")
            exit(1)
        }
        let root = URL(fileURLWithPath: rootPath, isDirectory: true).standardizedFileURL
        let fixture = URL(fileURLWithPath: fixturePath, isDirectory: true)
        let contents = fixture.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("Resources"), withIntermediateDirectories: true)
        let info: [String: String] = [
            "CFBundleIdentifier": "academy.glasscode.lemmings.integration-tests.asset-parity-storage",
            "CFBundlePackageType": "BNDL",
            "CFBundleVersion": "1",
        ]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        guard let bundle = Bundle(url: fixture) else {
            print("FAIL: isolated bundle did not load")
            exit(1)
        }
        let storage = AppStorage.current(bundle: bundle)
        guard storage.applicationSupport.standardizedFileURL == root, storage.isIntegrationTestBuild else {
            print("FAIL: integration storage changes with the process instead of retaining the supplied isolated root")
            exit(1)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let checkpoint = root.appendingPathComponent("cross-process-checkpoint.txt")
        if environment["LEMMIX_PARITY_STORAGE_PHASE"] == "reopen" {
            guard try String(contentsOf: checkpoint, encoding: .utf8) == "retained" else {
                print("FAIL: the isolated checkpoint did not survive process reopen")
                exit(1)
            }
        } else {
            try "retained".write(to: checkpoint, atomically: true, encoding: .utf8)
        }
        guard AppStorage.current().applicationSupport.standardizedFileURL != root else {
            print("FAIL: an ordinary process used the integration-only storage override")
            exit(1)
        }
        let catalogue = contents.appendingPathComponent("Resources/LevelPacks/packs.json")
        if FileManager.default.fileExists(atPath: catalogue.path) { try FileManager.default.removeItem(at: catalogue) }
        try GameResources.activate(bundleURL: fixture, forceReload: true)
        guard !GameResources.hasFanCatalogue else {
            print("FAIL: clean resources exposed an absent fan catalogue")
            exit(1)
        }
        try FileManager.default.createDirectory(at: catalogue.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{\"packs\":[]}".utf8).write(to: catalogue)
        try GameResources.activate(bundleURL: fixture, forceReload: true)
        guard GameResources.hasFanCatalogue else {
            print("FAIL: the selected owned fan catalogue remained unavailable")
            exit(1)
        }
        print("PASS: stable isolated storage \(environment["LEMMIX_PARITY_STORAGE_PHASE"] ?? "write")")
    }
}
