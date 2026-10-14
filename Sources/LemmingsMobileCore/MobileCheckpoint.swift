import CryptoKit
import NxlvKit
import Foundation

public struct MobileCameraState: Codable, Equatable, Sendable {
    public let origin: MobilePoint
    public let zoom: Double

    public init(origin: MobilePoint, zoom: Double) {
        self.origin = origin
        self.zoom = zoom
    }
}

public struct MobileCheckpointEnvelope: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public let runID: UUID
    public let engine: String
    public let engineFingerprint: String
    public let levelIdentifier: String
    public let levelIndex: Int
    public let levelFingerprint: String
    public let tick: Int
    public let selectedControl: Int
    public let camera: MobileCameraState
    public let payload: Data
    public var savedAt: Date
    /// The shared session this run belongs to. Nil for a solo run.
    public var scope: String?
    /// The Hot Seat player who owns the attempt.
    public var owner: String?

    public init(
        runID: UUID,
        engine: String,
        engineFingerprint: String,
        levelIdentifier: String,
        levelIndex: Int,
        levelFingerprint: String,
        tick: Int,
        selectedControl: Int,
        camera: MobileCameraState,
        payload: Data,
        savedAt: Date = Date(),
        scope: String? = nil,
        owner: String? = nil
    ) {
        self.runID = runID
        self.engine = engine
        self.engineFingerprint = engineFingerprint
        self.levelIdentifier = levelIdentifier
        self.levelIndex = levelIndex
        self.levelFingerprint = levelFingerprint
        self.tick = tick
        self.selectedControl = selectedControl
        self.camera = camera
        self.payload = payload
        self.savedAt = savedAt
        self.scope = scope
        self.owner = owner
    }

    @discardableResult
    public func validated() throws -> MobileCheckpointEnvelope {
        let strings = [engine, engineFingerprint, levelIdentifier, levelFingerprint]
        guard schemaVersion == 1,
              strings.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 4_096 }),
              (0..<100_000).contains(levelIndex),
              (0...10_000_000).contains(tick),
              (0..<1_000).contains(selectedControl),
              camera.origin.x.isFinite,
              camera.origin.y.isFinite,
              camera.zoom.isFinite,
              camera.zoom > 0,
              savedAt.timeIntervalSinceReferenceDate.isFinite,
              payload.count <= MobileCheckpointStore.maximumDocumentBytes else {
            throw MobileCheckpointError.invalid
        }
        return self
    }
}

public enum MobileCheckpointError: Error, LocalizedError, Equatable {
    case invalid
    case version
    case tooLarge

    public var errorDescription: String? {
        switch self {
        case .invalid:
            return L10n.text("The saved run could not be verified. Its backup was preserved.")
        case .version:
            return L10n.text("This saved run needs a different app version.")
        case .tooLarge:
            return L10n.text("The saved run is too large to open safely.")
        }
    }
}

/// Serial, atomic checkpoint storage with a validated previous copy.
public actor MobileCheckpointStore {
    fileprivate struct Document: Codable {
        var version = 1
        let payload: Data
        let checksum: String
    }

    public static let maximumDocumentBytes = 64 * 1_024 * 1_024
    public let url: URL
    public var backupURL: URL { url.appendingPathExtension("backup") }
    private var retiredRuns: Set<UUID> = []

    public init(url: URL) {
        self.url = url
    }

    public func hasSavedSoloRun(owner: String) async throws -> Bool {
        guard let saved = try await load(owner: owner, scope: nil), saved.scope == nil else { return false }
        return (saved.owner ?? MobileProfiles.defaultID) == owner
    }

    public func load() throws -> MobileCheckpointEnvelope? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            guard FileManager.default.fileExists(atPath: backupURL.path) else { return nil }
            let backup = try read(backupURL)
            let value = try decode(backup)
            try restoreBackup(backup)
            return value
        }
        do {
            return try decode(read(url))
        } catch MobileCheckpointError.version {
            throw MobileCheckpointError.version
        } catch {
            guard FileManager.default.fileExists(atPath: backupURL.path) else { throw error }
            let backup = try read(backupURL)
            let value = try decode(backup)
            try restoreBackup(backup)
            return value
        }
    }

    /// Loads only this solo owner or shared session, including matching legacy global saves.
    public func load(owner: String, scope: String?) async throws -> MobileCheckpointEnvelope? {
        let scoped = scopedURL(owner: owner, scope: scope)
        if FileManager.default.fileExists(atPath: scoped.path)
            || FileManager.default.fileExists(atPath: scoped.appendingPathExtension("backup").path) {
            return try await MobileCheckpointStore(url: scoped).load()
        }
        guard let saved = try load(), saved.scope == scope else { return nil }
        if scope == nil, (saved.owner ?? MobileProfiles.defaultID) != owner { return nil }
        return saved
    }

    public func save(_ envelope: MobileCheckpointEnvelope) throws {
        guard !retiredRuns.contains(envelope.runID) else { return }
        let validated = try envelope.validated()
        let payload = try JSONEncoder().encode(validated)
        let document = Document(payload: payload, checksum: Self.hash(payload))
        let bytes = try JSONEncoder().encode(document)
        guard bytes.count <= Self.maximumDocumentBytes else { throw MobileCheckpointError.tooLarge }
        try rejectFutureVersion(at: url)
        try rejectFutureVersion(at: backupURL)
        // Preserve the old global owner before a different player or session takes this slot.
        if let previousBytes = try? read(url), let previous = try? decode(previousBytes) {
            try saveScoped(previous, bytes: previousBytes)
        }
        try saveScoped(validated, bytes: bytes)
        let newest = [url, backupURL].compactMap { path -> MobileCheckpointEnvelope? in
            guard FileManager.default.fileExists(atPath: path.path),
                  let bytes = try? read(path) else { return nil }
            return try? decode(bytes)
        }.max { lhs, rhs in
            if lhs.savedAt != rhs.savedAt { return lhs.savedAt < rhs.savedAt }
            return lhs.tick < rhs.tick
        }
        if let newest {
            guard newest.savedAt <= validated.savedAt else { return }
            if newest.savedAt == validated.savedAt,
               newest.runID == validated.runID,
               newest.tick > validated.tick {
                return
            }
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: url.path),
           let current = try? read(url),
           (try? decode(current)) != nil {
            try current.write(to: backupURL, options: .atomic)
        } else if !FileManager.default.fileExists(atPath: backupURL.path) {
            try bytes.write(to: backupURL, options: .atomic)
        }
        try bytes.write(to: url, options: .atomic)
    }

    public func remove() throws {
        for path in [url, backupURL] where FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
        }
    }

    /// Deletes only this player's solo checkpoints, including older backup runs.
    public func removeSoloRuns(owner: String) throws {
        let scoped = scopedURL(owner: owner, scope: nil)
        let paths = [url, backupURL, scoped, scoped.appendingPathExtension("backup")]
        var owned: [(URL, UUID)] = []
        for path in paths where FileManager.default.fileExists(atPath: path.path) {
            let saved = try decode(read(path))
            if saved.scope == nil, (saved.owner ?? MobileProfiles.defaultID) == owner {
                owned.append((path, saved.runID))
            }
        }
        for (path, runID) in owned {
            retiredRuns.insert(runID)
            try FileManager.default.removeItem(at: path)
        }
    }

    /// Late saves from a finished run cannot restore it or delete a newer run.
    public func retire(runID: UUID) throws {
        retiredRuns.insert(runID)
        let directory = url.deletingLastPathComponent()
        let scoped = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))?
            .filter { $0.lastPathComponent.hasPrefix("scoped-") && ["json", "backup"].contains($0.pathExtension) } ?? []
        for path in [url, backupURL] + scoped where FileManager.default.fileExists(atPath: path.path) {
            if let bytes = try? read(path), let envelope = try? decode(bytes), envelope.runID == runID {
                try FileManager.default.removeItem(at: path)
            }
        }
    }

    private func scopedURL(owner: String, scope: String?) -> URL {
        let key = scope.map { "shared:" + $0 } ?? "solo:" + owner
        return url.deletingLastPathComponent().appendingPathComponent("scoped-" + Self.hash(Data(key.utf8)) + ".json")
    }

    private func saveScoped(_ envelope: MobileCheckpointEnvelope, bytes: Data) throws {
        guard !retiredRuns.contains(envelope.runID) else { return }
        let target = scopedURL(owner: envelope.owner ?? MobileProfiles.defaultID, scope: envelope.scope)
        try rejectFutureVersion(at: target)
        let backup = target.appendingPathExtension("backup")
        try rejectFutureVersion(at: backup)
        if let storedBytes = try? read(target), let stored = try? decode(storedBytes) {
            guard stored.savedAt <= envelope.savedAt else { return }
            if stored.savedAt == envelope.savedAt, stored.runID == envelope.runID, stored.tick > envelope.tick { return }
            if storedBytes == bytes { return }
            try storedBytes.write(to: backup, options: .atomic)
        }
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: backup.path) { try bytes.write(to: backup, options: .atomic) }
        try bytes.write(to: target, options: .atomic)
    }

    private func rejectFutureVersion(at target: URL) throws {
        guard let bytes = try? read(target) else { return }
        do { _ = try decode(bytes) }
        catch MobileCheckpointError.version { throw MobileCheckpointError.version }
        catch { return }
    }

    private func read(_ path: URL) throws -> Data {
        let size = try path.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= Self.maximumDocumentBytes else { throw MobileCheckpointError.tooLarge }
        let data = try Data(contentsOf: path, options: .mappedIfSafe)
        guard data.count <= Self.maximumDocumentBytes else { throw MobileCheckpointError.tooLarge }
        return data
    }

    private func decode(_ bytes: Data) throws -> MobileCheckpointEnvelope {
        let document = try JSONDecoder().decode(Document.self, from: bytes)
        guard document.version == 1 else { throw MobileCheckpointError.version }
        guard document.checksum == Self.hash(document.payload) else {
            throw MobileCheckpointError.invalid
        }
        return try JSONDecoder().decode(MobileCheckpointEnvelope.self, from: document.payload).validated()
    }

    private func restoreBackup(_ bytes: Data) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try bytes.write(to: url, options: .atomic)
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
