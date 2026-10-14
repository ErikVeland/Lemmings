import CryptoKit
import Foundation

/// Where downloaded soundtrack libraries live, and whether each one is intact.
public enum MusicLibraryStore {
    /// Folders that hold an installed library, each with its own `Music` directory.
    public static func installedRoots(in directory: URL) -> [URL] {
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return folders.filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("installed.json").path) }
            .map { $0.appendingPathComponent("Music") }.sorted { $0.path < $1.path }
    }

    public static func isInstalled(_ pack: MusicLibraryCatalogue.Pack, in directory: URL) -> Bool {
        let marker = directory.appendingPathComponent(pack.id).appendingPathComponent("installed.json")
        guard let data = try? Data(contentsOf: marker),
              let stored = try? JSONDecoder().decode([String: String].self, from: data) else { return false }
        return stored["sha256"] == pack.sha256 && pack.files.allSatisfy {
            let url = directory.appendingPathComponent(pack.id).appendingPathComponent($0.path)
            return (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } == $0.bytes
        }
    }

    public static func remove(_ pack: MusicLibraryCatalogue.Pack, in directory: URL) throws {
        let folder = directory.appendingPathComponent(pack.id)
        if FileManager.default.fileExists(atPath: folder.path) { try FileManager.default.removeItem(at: folder) }
    }

    /// Hashes a file in 1 MiB steps, so a large recording never sits in memory.
    public static func hash(_ url: URL) throws -> String {
        let stream = try FileHandle(forReadingFrom: url)
        defer { try? stream.close() }
        var hash = SHA256()
        while let bytes = try stream.read(upToCount: 1_048_576), !bytes.isEmpty { hash.update(data: bytes) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

private final class DownloadProgress: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let limit: Int64
    let update: @Sendable (Double) -> Void
    init(limit: Int64, update: @escaping @Sendable (Double) -> Void) { self.limit = limit; self.update = update }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > limit || totalBytesExpectedToWrite > limit { downloadTask.cancel(); return }
        update(min(1, Double(totalBytesWritten) / Double(limit)))
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}

/// Downloads and installs optional soundtrack libraries.
///
/// The app's own index names every file, size and hash, so a download never
/// chooses a path. Each member is read by name into a file this code creates:
/// archive paths and links never reach the file system.
public actor MusicLibraryInstaller {
    public enum Failure: LocalizedError {
        case download, corrupt, archive, busy
        public var errorDescription: String? {
            switch self {
            case .download: return "The soundtrack download is unavailable. Try again later."
            case .corrupt: return "The soundtrack download could not be verified."
            case .archive: return "The soundtrack library contains unexpected files."
            case .busy: return "This soundtrack library is already downloading."
            }
        }
    }

    private var installing = Set<String>()

    public init() {}

    public func download(_ pack: MusicLibraryCatalogue.Pack, to directory: URL,
                         progress: @escaping @Sendable (Double) -> Void) async throws {
        guard installing.insert(pack.id).inserted else { throw Failure.busy }
        defer { installing.remove(pack.id) }
        let delegate = DownloadProgress(limit: pack.bytes, update: progress)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (temporary, response) = try await session.download(from: pack.url)
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard (response as? HTTPURLResponse)?.statusCode == 200, response.url?.scheme == "https" else { throw Failure.download }
        try install(pack, archive: temporary, to: directory)
    }

    /// Installs an archive that is already on disk. `validate` checks the extracted tree before it goes live.
    public func install(_ pack: MusicLibraryCatalogue.Pack, archive archiveURL: URL, to directory: URL,
                        validate: (URL) -> Bool = { SoundtrackCatalogue.load(at: $0) != nil && MusicTimingCatalogue.load(at: $0) != nil }) throws {
        let manager = FileManager.default
        let size = try archiveURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard Int64(size ?? -1) == pack.bytes, try MusicLibraryStore.hash(archiveURL) == pack.sha256 else { throw Failure.corrupt }
        let archive: ZipArchive
        do { archive = try ZipArchive(contentsOf: archiveURL) } catch { throw Failure.archive }
        // The archive must hold exactly the catalogued files, once each, as plain files of the stated size.
        let expected = Dictionary(uniqueKeysWithValues: pack.files.map { ($0.path, $0.bytes) })
        guard archive.members.count == pack.files.count else { throw Failure.archive }
        var seen = Set<String>()
        for member in archive.members {
            guard seen.insert(member.name).inserted, expected[member.name] == Int64(member.uncompressedSize),
                  !member.isSymbolicLink else { throw Failure.archive }
        }
        try Task.checkCancellation()
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let staging = directory.appendingPathComponent(".incoming-" + UUID().uuidString)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: staging) }
        for file in pack.files {
            try Task.checkCancellation()
            guard let member = archive.members.first(where: { $0.name == file.path }) else { throw Failure.archive }
            let destination = staging.appendingPathComponent(file.path)
            try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            manager.createFile(atPath: destination.path, contents: nil)
            let output = try FileHandle(forWritingTo: destination)
            do { try archive.extract(member, to: output); try output.close() }
            catch { try? output.close(); throw Failure.corrupt }
            let written = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize
            guard Int64(written ?? -1) == file.bytes, try MusicLibraryStore.hash(destination) == file.sha256 else { throw Failure.corrupt }
        }
        guard validate(staging.appendingPathComponent("Music")) else { throw Failure.archive }
        let marker = try JSONEncoder().encode(["id": pack.id, "sha256": pack.sha256])
        try marker.write(to: staging.appendingPathComponent("installed.json"), options: .atomic)
        try Task.checkCancellation()
        let final = directory.appendingPathComponent(pack.id)
        if manager.fileExists(atPath: final.path) { _ = try manager.replaceItemAt(final, withItemAt: staging) }
        else { try manager.moveItem(at: staging, to: final) }
        // Recordings are large and can be downloaded again, so they stay out of device backups.
        var excluded = URLResourceValues(); excluded.isExcludedFromBackup = true
        var folder = final
        try? folder.setResourceValues(excluded)
    }
}
