import Foundation

@main struct Checks {
  @MainActor static func main() {
    let suite = "UltimateLemmix.ResourceAccessTests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    var starts: [URL] = [], stops: [URL] = []
    var stale = false, reject = false
    let url = URL(fileURLWithPath: "/player/levels", isDirectory: true)
    let dependencies = UserResourceAccess.Dependencies(
      bookmark: { if reject { throw CocoaError(.fileReadNoPermission) }; return Data($0.path.utf8) },
      resolve: { (URL(fileURLWithPath: String(decoding: $0, as: UTF8.self), isDirectory: true), stale) },
      start: { starts.append($0); return true },
      stop: { stops.append($0) })
    let first = UserResourceAccess(defaults: defaults, dependencies: dependencies)
    precondition(first.remember(url))
    precondition(first.remember(url))
    precondition(starts == [url], "Repeated selection must retain access once")
    first.stopAll()
    precondition(stops == [url])
    let second = UserResourceAccess(defaults: defaults, dependencies: dependencies)
    stale = true
    precondition(second.restore().isEmpty)
    precondition(starts.count == 2, "Restart must restore bookmarked access")
    precondition(second.restore().isEmpty && starts.count == 2)
    second.stopAll()
    second.stopAll()
    precondition(stops.count == 2)
    reject = true
    precondition(!second.remember(url), "Bookmark failure must be reported")
    print("PASS persistent player-resource access, stale refresh, balanced access and failure reporting")
  }
}
