import Foundation

/// Bounded, process-local storage for decoded assets and verified content identities.
/// Mutable imports still need a fresh content revision before they use a cache entry.
final class GameAssetCache<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Value] = [:]
    private var order: [String] = []
    private let capacity: Int
    init(capacity: Int = 256) { self.capacity = max(1, capacity) }
    func value(for key: String) -> Value? {
        lock.lock(); defer { lock.unlock() }
        return values[key]
    }
    func insert(_ value: Value, for key: String) {
        lock.lock(); defer { lock.unlock() }
        if values[key] == nil { order.append(key) }
        values[key] = value
        while order.count > capacity { values.removeValue(forKey: order.removeFirst()) }
    }

    private static var resourceRoot: String? {
        Bundle.main.resourceURL?.resolvingSymlinksInPath().standardizedFileURL.path
    }
    /// Only the installed application resources are immutable for this process.
    static func bundledKey(_ url: URL) -> String? {
        guard let root = resourceRoot else { return nil }
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        return path.hasPrefix(root + "/") ? path : nil
    }
}
