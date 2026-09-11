import Foundation
import Darwin
import NxlvKit

/// Keeps the previous validated save and refuses to overwrite a changed file.
final class ArcadeRecordFile {
    enum Failure: Error, LocalizedError {
        case unsupportedVersion
        case changedOnDisk
        case busy
        var errorDescription: String? {
            switch self {
            case .unsupportedVersion: return "Records need a different app version. Existing files were preserved."
            case .changedOnDisk: return "Records changed in another app. Close and reopen this app."
            case .busy: return "Another app is saving records. Try again after it finishes."
            }
        }
    }
    let url: URL
    var backupURL: URL { url.appendingPathExtension("backup") }
    private var expectedData: Data?
    private(set) var recovered = false
    private(set) var preservedURL: URL?

    init(url: URL) { self.url = url }

    private func decode(_ data: Data) throws -> ArcadeRecords {
        struct Header: Decodable { let version: Int }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object["version"] != nil {
            guard let header = try? JSONDecoder().decode(Header.self, from: data), (1...2).contains(header.version) else {
                throw Failure.unsupportedVersion
            }
        }
        return try JSONDecoder().decode(ArcadeRecords.self, from: data).validated()
    }

    func load() throws -> ArcadeRecords? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            guard fm.fileExists(atPath: backupURL.path) else { return nil }
            return try recover(preserving: nil)
        }
        // A read failure is not evidence that the file is corrupt.
        let data = try Data(contentsOf: url)
        do {
            let records = try decode(data)
            expectedData = data
            return records
        } catch Failure.unsupportedVersion {
            throw Failure.unsupportedVersion
        } catch {
            guard fm.fileExists(atPath: backupURL.path) else { throw error }
            return try recover(preserving: data)
        }
    }

    private func withLock<T>(_ operation: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = open(url.appendingPathExtension("lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            if errno == EWOULDBLOCK { throw Failure.busy }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        defer { flock(descriptor, LOCK_UN) }
        return try operation()
    }

    private func recover(preserving original: Data?) throws -> ArcadeRecords {
        try withLock { try restoreBackup(preserving: original) }
    }

    private func restoreBackup(preserving original: Data?) throws -> ArcadeRecords {
        let current = FileManager.default.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
        guard current == original else { throw Failure.changedOnDisk }
        let data = try Data(contentsOf: backupURL)
        let records = try decode(data)
        if let original {
            let preserved = url.deletingLastPathComponent()
                .appendingPathComponent("\(url.lastPathComponent).unreadable-\(UUID().uuidString)")
            try original.write(to: preserved, options: .atomic)
            preservedURL = preserved
        }
        try data.write(to: url, options: .atomic)
        expectedData = data
        recovered = true
        return records
    }

    func save(_ records: ArcadeRecords) throws {
        try withLock { try write(records) }
    }

    private func write(_ records: ArcadeRecords) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(records.validated())
        let fm = FileManager.default
        let current = fm.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
        guard current == expectedData else { throw Failure.changedOnDisk }
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Save the prior good version before replacing the primary. The first save also gets a backup.
        try (current ?? data).write(to: backupURL, options: .atomic)
        try data.write(to: url, options: .atomic)
        expectedData = data
    }
}
