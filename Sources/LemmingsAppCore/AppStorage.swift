import Foundation

/// The storage locations for one app installation. Tests inject a temporary root.
///
/// `UserDefaults` and `Bundle` are thread-safe, but the SDK does not mark them `Sendable`.
/// The struct is immutable, so `@unchecked Sendable` is safe here.
public struct AppStorage: @unchecked Sendable {
    /// The folder name below Application Support. The Mac has used this name since 1.0.
    public static let folderName = "Ultimate Lemmings"

    /// Mac: `~/Library/Application Support/Ultimate Lemmings`.
    public let applicationSupport: URL
    /// The bundled game data, `Bundle.main.resourceURL` in the app.
    public let resources: URL
    /// The settings and campaign progress store, `UserDefaults.standard` in the app.
    public let defaults: UserDefaults
    /// True when the bundle ID contains "preview". Preview builds keep separate records.
    public let isPreviewBuild: Bool
    /// True when the bundle ID contains "integration-tests". These builds write to temporary folders.
    public let isIntegrationTestBuild: Bool
    /// The bundle that supplies Info.plist values, for example the version.
    public let bundle: Bundle
    /// The temporary folder and settings suite to remove after a test, or nil for a real installation.
    let temporary: (root: URL, suite: String)?

    public init(applicationSupport: URL, resources: URL, defaults: UserDefaults, bundle: Bundle = .main,
                isPreviewBuild: Bool = false, isIntegrationTestBuild: Bool = false) {
        self.init(applicationSupport: applicationSupport, resources: resources, defaults: defaults, bundle: bundle,
                  isPreviewBuild: isPreviewBuild, isIntegrationTestBuild: isIntegrationTestBuild, temporary: nil)
    }

    private init(applicationSupport: URL, resources: URL, defaults: UserDefaults, bundle: Bundle,
                 isPreviewBuild: Bool, isIntegrationTestBuild: Bool, temporary: (root: URL, suite: String)?) {
        self.applicationSupport = applicationSupport
        self.resources = resources
        self.defaults = defaults
        self.bundle = bundle
        self.isPreviewBuild = isPreviewBuild
        self.isIntegrationTestBuild = isIntegrationTestBuild
        self.temporary = temporary
    }

    /// The real locations of the running app.
    public static func current(bundle: Bundle = .main) -> AppStorage {
        #if os(tvOS)
        let directory: FileManager.SearchPathDirectory = .cachesDirectory
        #else
        let directory: FileManager.SearchPathDirectory = .applicationSupportDirectory
        #endif
        let support = FileManager.default.urls(for: directory, in: .userDomainMask)[0]
        let identifier = bundle.bundleIdentifier ?? ""
        let integration = identifier.contains("integration-tests")
        let root = support.appendingPathComponent(folderName)
        // A separate preferences suite alone does not isolate playlists or checkpoints.
        let applicationSupport = integration
            ? FileManager.default.temporaryDirectory.appendingPathComponent("LemmingsIntegrationTests")
                .appendingPathComponent(identifier).appendingPathComponent(String(ProcessInfo.processInfo.processIdentifier))
            : root
        return AppStorage(applicationSupport: applicationSupport,
                          resources: bundle.resourceURL ?? bundle.bundleURL,
                          defaults: .standard, bundle: bundle,
                          isPreviewBuild: identifier.contains("preview"),
                          isIntegrationTestBuild: integration)
    }

    /// Empty folders and empty settings below the temporary directory. Each call makes a new root.
    public static func temporary(named name: String) throws -> AppStorage {
        let token = UUID().uuidString
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LemmingsAppCore-\(name)-\(token)", isDirectory: true)
        let support = root.appendingPathComponent("Application Support/\(folderName)", isDirectory: true)
        let resources = root.appendingPathComponent("Resources", isDirectory: true)
        for folder in [support, resources] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let suite = "LemmingsAppCore.\(name).\(token)"
        guard let defaults = UserDefaults(suiteName: suite) else { throw CocoaError(.fileWriteUnknown) }
        return AppStorage(applicationSupport: support, resources: resources, defaults: defaults, bundle: .main,
                          isPreviewBuild: false, isIntegrationTestBuild: false, temporary: (root, suite))
    }

    /// Removes the folders and settings that `temporary(named:)` made. It does nothing for a real installation.
    public func removeTemporaryFiles() {
        guard let temporary else { return }
        try? FileManager.default.removeItem(at: temporary.root)
        defaults.removePersistentDomain(forName: temporary.suite)
    }
}
