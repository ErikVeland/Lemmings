import Foundation

/**
 * Shares one validated presentation resource tree across the platform shells.
 */
public enum GameResources {
    public static let changed = Notification.Name("GameResourcesChanged")

    private struct Snapshot: Sendable {
        let bundleURL: URL
        let resourceURL: URL?
        let revision: String
        let hasRestoredOriginalAssets: Bool
    }
    private final class Storage: @unchecked Sendable {
        private let lock = NSLock()
        private var generation: UInt64 = 0
        private var value = Snapshot(bundleURL: Bundle.main.bundleURL,
            resourceURL: Bundle.main.resourceURL, revision: Bundle.main.bundleURL.path + "#0", hasRestoredOriginalAssets: false)
        func read() -> Snapshot {
            lock.lock(); defer { lock.unlock() }
            return value
        }
        func activate(_ bundle: Bundle, force: Bool) -> Bool {
            lock.lock(); defer { lock.unlock() }
            guard force || value.bundleURL != bundle.bundleURL else { return false }
            generation &+= 1
            value = Snapshot(bundleURL: bundle.bundleURL, resourceURL: bundle.resourceURL,
                revision: bundle.bundleURL.standardizedFileURL.path + "#" + String(generation),
                hasRestoredOriginalAssets: bundle.bundleIdentifier == "academy.glasscode.ultimatelemmix.owned-resources")
            return true
        }
    }
    private static let storage = Storage()
    public static var resourceURL: URL? { storage.read().resourceURL }
    public static var hasRestoredOriginalAssets: Bool { storage.read().hasRestoredOriginalAssets }
    public static var revision: String { storage.read().revision }
    public static var bundle: Bundle { Bundle(url: storage.read().bundleURL) ?? .main }
    public static var hasFanCatalogue: Bool { file("LevelPacks/packs.json") != nil }

    /**
     * Activates an already validated, immutable data bundle without loading code.
     */
    @MainActor public static func activate(bundleURL: URL?, forceReload: Bool = false) throws {
        let next: Bundle
        if let bundleURL {
            guard let loaded = Bundle(url: bundleURL), let root = loaded.resourceURL,
                  (try? root.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                throw CocoaError(.fileReadCorruptFile)
            }
            next = loaded
        } else { next = .main }
        if storage.activate(next, force: forceReload) {
            NotificationCenter.default.post(name: changed, object: nil)
        }
    }

    public static func directory(_ relativePath: String) -> URL? { resolved(relativePath, directory: true) }
    public static func file(_ relativePath: String) -> URL? { resolved(relativePath, directory: false) }

    private static func resolved(_ path: String, directory: Bool) -> URL? {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
              let root = resourceURL?.resolvingSymlinksInPath().standardizedFileURL else { return nil }
        let result = root.appendingPathComponent(path).resolvingSymlinksInPath().standardizedFileURL
        guard result.path.hasPrefix(root.path + "/") else { return nil }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: result.path, isDirectory: &isDirectory),
              isDirectory.boolValue == directory else { return nil }
        return result
    }
}
