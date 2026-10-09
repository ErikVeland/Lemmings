import Darwin
import Foundation
import NxlvKit

/// Stores one player's playlists and active level sequence outside campaign progress.
@MainActor final class LevelPlaylistStore {
    enum Failure: Error, LocalizedError {
        case unsupportedVersion
        case changedOnDisk
        case busy
        case tooManyPlaylists
        case missingPlaylist
        case duplicatePlaylist
        case invalidDocument

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion:
                "Playlists need a different app version. Existing files were preserved."
            case .changedOnDisk:
                "Playlists changed in another app. Close and reopen this app."
            case .busy:
                "Another app is saving playlists. Try again after it finishes."
            case .tooManyPlaylists:
                "The player has reached the playlist limit."
            case .missingPlaylist:
                "The selected playlist is no longer available."
            case .duplicatePlaylist:
                "A playlist with this identity already exists."
            case .invalidDocument:
                "The playlist file contains invalid data. Existing files were preserved."
            }
        }
    }

    private struct Document: Codable {
        static let currentVersion = 1
        static let maximumPlaylists = 200

        let version: Int
        var playlists: [LevelPlaylist]
        var selectedPlaylistID: UUID?
        var activeRun: LevelSequenceRun?

        init(
            playlists: [LevelPlaylist] = [],
            selectedPlaylistID: UUID? = nil,
            activeRun: LevelSequenceRun? = nil
        ) {
            version = Self.currentVersion
            self.playlists = playlists
            self.selectedPlaylistID = selectedPlaylistID
            self.activeRun = activeRun
        }

        func validated() throws -> Self {
            guard version == Self.currentVersion else { throw Failure.unsupportedVersion }
            guard playlists.count <= Self.maximumPlaylists else {
                throw Failure.tooManyPlaylists
            }
            guard Set(playlists.map(\.id)).count == playlists.count else {
                throw Failure.invalidDocument
            }
            guard selectedPlaylistID == nil
                    || playlists.contains(where: { $0.id == selectedPlaylistID }) else {
                throw Failure.missingPlaylist
            }
            if case let .playlist(playlistID)? = activeRun?.source,
               !playlists.contains(where: { $0.id == playlistID }) {
                throw Failure.missingPlaylist
            }
            return self
        }
    }

    private struct VersionHeader: Decodable {
        let version: Int
    }

    let file: URL
    var backupFile: URL { file.appendingPathExtension("backup") }
    private var document = Document()
    private var expectedData: Data?
    private(set) var recovered = false

    var playlists: [LevelPlaylist] { document.playlists }
    var selectedPlaylistID: UUID? { document.selectedPlaylistID }
    var activeRun: LevelSequenceRun? { document.activeRun }

    static func fileURL(profileID: String) -> URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ultimate Lemmings/Playlists", isDirectory: true)
        let identity = ArcadeStore.fingerprint(Data(profileID.utf8))
        return root.appendingPathComponent(identity + ".json")
    }

    static func removeData(profileID: String) {
        removeData(at: fileURL(profileID: profileID))
    }

    static func removeData(at file: URL) {
        let manager = FileManager.default
        try? manager.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let lockFile = file.appendingPathExtension("lock")
        let descriptor = open(
            lockFile.path,
            O_CREAT | O_RDWR,
            S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { return }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { return }
        defer { flock(descriptor, LOCK_UN) }
        let prefix = file.lastPathComponent + ".unreadable-"
        let preserved = (try? manager.contentsOfDirectory(
            at: file.deletingLastPathComponent(),
            includingPropertiesForKeys: nil))?.filter {
                $0.lastPathComponent.hasPrefix(prefix)
            } ?? []
        for target in [file, file.appendingPathExtension("backup")] + preserved {
            try? manager.removeItem(at: target)
        }
    }

    convenience init(profileID: String) throws {
        try self.init(file: Self.fileURL(profileID: profileID))
    }

    init(file: URL) throws {
        self.file = file
        try load()
    }

    func playlist(id: UUID) -> LevelPlaylist? {
        document.playlists.first { $0.id == id }
    }

    func selectedPlaylist() -> LevelPlaylist? {
        selectedPlaylistID.flatMap { playlist(id: $0) }
    }

    func add(_ playlist: LevelPlaylist, select: Bool = true) throws {
        guard document.playlists.count < Document.maximumPlaylists else {
            throw Failure.tooManyPlaylists
        }
        guard !document.playlists.contains(where: { $0.id == playlist.id }) else {
            throw Failure.duplicatePlaylist
        }
        let previous = document
        document.playlists.append(playlist)
        if select { document.selectedPlaylistID = playlist.id }
        do { try save() } catch { document = previous; throw error }
    }

    func update(_ playlist: LevelPlaylist, select: Bool = true) throws {
        guard let index = document.playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw Failure.missingPlaylist
        }
        let previous = document
        document.playlists[index] = playlist
        if select { document.selectedPlaylistID = playlist.id }
        do { try save() } catch { document = previous; throw error }
    }

    func removePlaylist(id: UUID) throws {
        guard document.playlists.contains(where: { $0.id == id }) else { return }
        let previous = document
        document.playlists.removeAll { $0.id == id }
        if document.selectedPlaylistID == id {
            document.selectedPlaylistID = document.playlists.last?.id
        }
        if case let .playlist(activePlaylistID)? = document.activeRun?.source,
           activePlaylistID == id {
            document.activeRun = nil
        }
        do { try save() } catch { document = previous; throw error }
    }

    func selectPlaylist(id: UUID?) throws {
        guard id == nil || document.playlists.contains(where: { $0.id == id }) else {
            throw Failure.missingPlaylist
        }
        let previous = document
        document.selectedPlaylistID = id
        do { try save() } catch { document = previous; throw error }
    }

    func setActiveRun(_ run: LevelSequenceRun?) throws {
        if case let .playlist(playlistID)? = run?.source,
           !document.playlists.contains(where: { $0.id == playlistID }) {
            throw Failure.missingPlaylist
        }
        let previous = document
        document.activeRun = run
        do { try save() } catch { document = previous; throw error }
    }

    @discardableResult func advanceActiveRun() throws -> Bool {
        guard var run = document.activeRun else { return false }
        guard run.advance() else { return false }
        let previous = document
        document.activeRun = run
        do { try save() } catch { document = previous; throw error }
        return true
    }

    private func decode(_ data: Data) throws -> Document {
        let decoder = JSONDecoder()
        let header = try decoder.decode(VersionHeader.self, from: data)
        guard header.version == Document.currentVersion else {
            throw Failure.unsupportedVersion
        }
        return try decoder.decode(Document.self, from: data).validated()
    }

    private func load() throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: file.path) else {
            guard manager.fileExists(atPath: backupFile.path) else { return }
            try recover(preserving: nil)
            return
        }
        let data = try Data(contentsOf: file)
        do {
            document = try decode(data)
            expectedData = data
        } catch Failure.unsupportedVersion {
            throw Failure.unsupportedVersion
        } catch {
            guard manager.fileExists(atPath: backupFile.path) else { throw error }
            try recover(preserving: data)
        }
    }

    private func withLock<T>(_ operation: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = open(
            file.appendingPathExtension("lock").path,
            O_CREAT | O_RDWR,
            S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            if errno == EWOULDBLOCK { throw Failure.busy }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        defer { flock(descriptor, LOCK_UN) }
        return try operation()
    }

    private func recover(preserving original: Data?) throws {
        try withLock {
            let current = FileManager.default.fileExists(atPath: file.path)
                ? try Data(contentsOf: file) : nil
            guard current == original else { throw Failure.changedOnDisk }
            let data = try Data(contentsOf: backupFile)
            let recoveredDocument = try decode(data)
            if let original {
                let preserved = file.deletingLastPathComponent().appendingPathComponent(
                    file.lastPathComponent + ".unreadable-" + UUID().uuidString)
                try original.write(to: preserved, options: .atomic)
            }
            try data.write(to: file, options: .atomic)
            document = recoveredDocument
            expectedData = data
            recovered = true
        }
    }

    private func save() throws {
        try withLock {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(try document.validated())
            let manager = FileManager.default
            let current = manager.fileExists(atPath: file.path)
                ? try Data(contentsOf: file) : nil
            guard current == expectedData else { throw Failure.changedOnDisk }
            try (current ?? data).write(to: backupFile, options: .atomic)
            try data.write(to: file, options: .atomic)
            expectedData = data
        }
    }
}
