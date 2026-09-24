import CryptoKit
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
        savedAt: Date = Date()
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
            return "The saved run could not be verified. Its backup was preserved."
        case .version:
            return "This saved run needs a different app version."
        case .tooLarge:
            return "The saved run is too large to open safely."
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

    public init(url: URL) {
        self.url = url
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

    public func save(_ envelope: MobileCheckpointEnvelope) throws {
        let validated = try envelope.validated()
        let payload = try JSONEncoder().encode(validated)
        let document = Document(payload: payload, checksum: Self.hash(payload))
        let bytes = try JSONEncoder().encode(document)
        guard bytes.count <= Self.maximumDocumentBytes else { throw MobileCheckpointError.tooLarge }
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
