import Foundation

/// Device-only names. Nothing in this file belongs in records, checkpoints or sync.
/// The lock protects the lazy state and all writes, including inspection from other threads.
public final class FamiliarNamesStore: @unchecked Sendable {
    public static let shared = FamiliarNamesStore(directory: AppStorage.current().applicationSupport
        .appendingPathComponent("Private Familiar Names", isDirectory: true))
    private struct State: Codable {
        var names: [String] = []
        var cohorts: [String: [String]] = [:]
    }
    private let directory: URL
    private let lock = NSLock()
    private var state: State?
    private var generation: UInt64 = 0
    public init(directory: URL) { self.directory = directory }
    private var file: URL { directory.appendingPathComponent("names-v1.json") }
    public var revision: UInt64 { lock.lock(); defer { lock.unlock() }; return generation }

    /// Preserve compound given names, accents and spelling. Case and canonical Unicode
    /// equivalence do not create duplicates. No locale-dependent sorting affects identity.
    public static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let clean = value.precomposedStringWithCanonicalMapping
                .components(separatedBy: .controlCharacters).joined()
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            guard !clean.isEmpty,
                  seen.insert(clean.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))).inserted else { return nil }
            return clean
        }
    }
    public static func typed(_ text: String) -> [String] {
        unique(text.components(separatedBy: CharacterSet(charactersIn: ",;\n\r")))
    }
    public func names() throws -> [String] {
        lock.lock(); defer { lock.unlock() }
        return try read().names
    }
    public func replace(with names: [String]) throws {
        lock.lock(); defer { lock.unlock() }
        var next = try read()
        next.names = Self.unique(names)
        try write(next)
        generation &+= 1
    }
    /// The initial-state scope is identical on retry and checkpoint restoration.
    /// Freeze the whole ordered list, so later edits cannot rename this cohort.
    public func names(for scope: String) throws -> [String] {
        lock.lock(); defer { lock.unlock() }
        var next = try read()
        if let existing = next.cohorts[scope] { return existing }
        guard !next.names.isEmpty else { return [] }
        next.cohorts[scope] = next.names
        try write(next)
        return next.names
    }
    /// Forget also removes every retained assignment. There is deliberately no undo copy.
    public func forget() throws {
        lock.lock(); defer { lock.unlock() }
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        state = State()
        generation &+= 1
    }
    private func read() throws -> State {
        if let state { return state }
        let loaded: State
        if FileManager.default.fileExists(atPath: file.path) {
            loaded = try JSONDecoder().decode(State.self, from: Data(contentsOf: file))
        } else { loaded = State() }
        state = loaded
        return loaded
    }
    private func write(_ next: State) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        var url = directory
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        try JSONEncoder().encode(next).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        state = next
    }
}
