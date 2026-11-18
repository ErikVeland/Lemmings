import Foundation

/**
 * Gives the shared frontend one resource tree for bundled or imported artwork.
 */
enum GameResources {
  static let changed = Notification.Name("GameResourcesChanged")

  private struct Snapshot: Sendable {
    let bundleURL: URL
    let resourceURL: URL?
    let revision: String
  }

  private final class Storage: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Snapshot(bundleURL: Bundle.main.bundleURL,
      resourceURL: Bundle.main.resourceURL, revision: Bundle.main.bundleURL.path)

    func read() -> Snapshot {
      lock.lock()
      defer { lock.unlock() }
      return value
    }

    func replace(_ next: Snapshot) -> Bool {
      lock.lock()
      defer { lock.unlock() }
      guard value.revision != next.revision else { return false }
      value = next
      return true
    }
  }

  private static let storage = Storage()
  static var resourceURL: URL? { storage.read().resourceURL }
  static var revision: String { storage.read().revision }
  static var bundle: Bundle { Bundle(url: storage.read().bundleURL) ?? .main }

  /**
   * Activates an already validated, immutable resource installation.
   */
  @MainActor static func activate(bundleURL: URL?, forceReload: Bool = false) throws {
    let next: Bundle
    if let bundleURL {
      guard let loaded = Bundle(url: bundleURL), let root = loaded.resourceURL,
        FileManager.default.fileExists(atPath: root.path) else {
        throw CocoaError(.fileReadCorruptFile)
      }
      next = loaded
    } else {
      next = .main
    }
    let state = Snapshot(bundleURL: next.bundleURL, resourceURL: next.resourceURL,
      revision: next.bundleURL.standardizedFileURL.path + (forceReload ? ":" + UUID().uuidString : ""))
    if storage.replace(state) { NotificationCenter.default.post(name: changed, object: nil) }
  }

  static func directory(_ relativePath: String) -> URL? {
    resolved(relativePath, directory: true)
  }

  static func file(_ relativePath: String) -> URL? {
    resolved(relativePath, directory: false)
  }

  private static func resolved(_ relativePath: String, directory: Bool) -> URL? {
    let parts = relativePath.split(separator: "/", omittingEmptySubsequences: false)
    guard !parts.isEmpty, parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
      let root = resourceURL?.resolvingSymlinksInPath().standardizedFileURL else { return nil }
    let result = root.appendingPathComponent(relativePath).resolvingSymlinksInPath().standardizedFileURL
    guard result.path.hasPrefix(root.path + "/") else { return nil }
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: result.path, isDirectory: &isDirectory),
      isDirectory.boolValue == directory else { return nil }
    return result
  }
}
