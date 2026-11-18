#if os(macOS)
import Foundation

/**
 * Keeps access to folders the player selects in the sandboxed application.
 */
@MainActor final class UserResourceAccess {
  struct Dependencies {
    var bookmark: (URL) throws -> Data
    var resolve: (Data) throws -> (url: URL, stale: Bool)
    var start: (URL) -> Bool
    var stop: (URL) -> Void

    static var live: Self {
      Self(
        bookmark: { try $0.bookmarkData(options: .withSecurityScope,
          includingResourceValuesForKeys: nil, relativeTo: nil) },
        resolve: { data in
          var stale = false
          let url = try URL(resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI], relativeTo: nil,
            bookmarkDataIsStale: &stale)
          return (url, stale)
        },
        start: { $0.startAccessingSecurityScopedResource() },
        stop: { $0.stopAccessingSecurityScopedResource() })
    }
  }

  static let shared = UserResourceAccess()
  private let defaults: UserDefaults
  private let dependencies: Dependencies
  private let key = "OwnedResourceBookmarksV1"
  private var active: [String: URL] = [:]

  init(defaults: UserDefaults = .standard, dependencies: Dependencies = .live) {
    self.defaults = defaults
    self.dependencies = dependencies
  }

  /**
   * Saves access before the selected path becomes a library preference.
   */
  @discardableResult func remember(_ url: URL) -> Bool {
    do {
      let path = url.standardizedFileURL.path
      let bookmark = try dependencies.bookmark(url)
      var saved = defaults.dictionary(forKey: key) as? [String: Data] ?? [:]
      saved[path] = bookmark
      defaults.set(saved, forKey: key)
      if active[path] == nil, dependencies.start(url) { active[path] = url }
      return true
    } catch { return false }
  }

  /**
   * Restores access without opening system dialogs during launch.
   */
  @discardableResult func restore() -> [String] {
    let saved = defaults.dictionary(forKey: key) as? [String: Data] ?? [:]
    var failures: [String] = []
    for (path, data) in saved {
      guard active[path] == nil else { continue }
      do {
        let resolved = try dependencies.resolve(data)
        guard dependencies.start(resolved.url) else { failures.append(path); continue }
        active[path] = resolved.url
        if resolved.stale, !remember(resolved.url) { failures.append(path) }
      } catch { failures.append(path) }
    }
    return failures.sorted()
  }

  /**
   * Balances each access retained for this application session.
   */
  func stopAll() {
    for url in active.values { dependencies.stop(url) }
    active.removeAll()
  }
}

#endif
