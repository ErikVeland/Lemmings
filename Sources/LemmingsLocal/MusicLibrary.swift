import Foundation
import CryptoKit
import NxlvKit

enum MusicLibrary {
    static let changed = Notification.Name("MusicLibraryChanged")
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ultimate Lemmings/MusicLibraries", isDirectory: true)
    }
    static func catalogue(at musicRoot: URL? = Bundle.main.resourceURL?.appendingPathComponent("Music")) -> MusicLibraryCatalogue? {
        guard let url = musicRoot?.appendingPathComponent("libraries.json"), let data = try? Data(contentsOf: url) else { return nil }
        return try? MusicLibraryCatalogue(data: data)
    }
    static func installedRoots(in directory: URL = directory) -> [URL] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return folders.filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("installed.json").path) }
            .map { $0.appendingPathComponent("Music") }.sorted { $0.path < $1.path }
    }
    static func isInstalled(_ pack: MusicLibraryCatalogue.Pack, in directory: URL = directory) -> Bool {
        let marker = directory.appendingPathComponent(pack.id).appendingPathComponent("installed.json")
        guard let data = try? Data(contentsOf: marker), let stored = try? JSONDecoder().decode([String: String].self, from: data)
        else { return false }
        return stored["sha256"] == pack.sha256 && pack.files.allSatisfy {
            let url = directory.appendingPathComponent(pack.id).appendingPathComponent($0.path)
            return (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } == $0.bytes
        }
    }
    static func hash(_ url: URL) throws -> String {
        let stream = try FileHandle(forReadingFrom: url)
        defer { try? stream.close() }
        var hash = SHA256()
        while let bytes = try stream.read(upToCount: 1_048_576), !bytes.isEmpty { hash.update(data: bytes) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func rhythmURL(for source: URL, musicRoot: URL? = Bundle.main.resourceURL?.appendingPathComponent("Music")) -> URL? {
        for root in [musicRoot].compactMap({ $0 }) + installedRoots() {
            let prefix = root.standardizedFileURL.path + "/"
            guard source.standardizedFileURL.path.hasPrefix(prefix),
                  let data = try? Data(contentsOf: root.appendingPathComponent("rhythm.json")),
                  let catalogue = try? MusicRhythmCatalogue(data: data),
                  let entry = catalogue.variants.first(where: { $0.path == String(source.standardizedFileURL.path.dropFirst(prefix.count)) }),
                  (try? hash(source)) == entry.sourceSHA256 else { continue }
            let loop = root.appendingPathComponent(entry.loopPath)
            if (try? hash(loop)) == entry.sha256 { return loop }
        }
        return nil
    }
}

private final class MusicDownloadProgress: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let limit: Int64
    let update: @Sendable (Double) -> Void
    init(limit: Int64, update: @escaping @Sendable (Double) -> Void) { self.limit = limit; self.update = update }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > limit || totalBytesExpectedToWrite > limit { downloadTask.cancel(); return }
        update(min(1, Double(totalBytesWritten) / Double(limit)))
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}

actor MusicLibraryInstaller {
    enum Failure: LocalizedError {
        case download, corrupt, archive, busy
        var errorDescription: String? {
            switch self {
            case .download: return "The soundtrack download is unavailable. Try again later."
            case .corrupt: return "The soundtrack download could not be verified."
            case .archive: return "The soundtrack library contains unexpected files."
            case .busy: return "This soundtrack library is already downloading."
            }
        }
    }
    private var installing = Set<String>()

    func download(_ pack: MusicLibraryCatalogue.Pack, to directory: URL = MusicLibrary.directory,
                  progress: @escaping @Sendable (Double) -> Void) async throws {
        guard installing.insert(pack.id).inserted else { throw Failure.busy }
        defer { installing.remove(pack.id) }
        let delegate = MusicDownloadProgress(limit: pack.bytes, update: progress)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (temporary, response) = try await session.download(from: pack.url)
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard (response as? HTTPURLResponse)?.statusCode == 200, response.url?.scheme == "https" else { throw Failure.download }
        try install(pack, archive: temporary, to: directory)
    }

    /// Extract each named member to a file we created. ZIP paths and symlinks never reach the filesystem.
    func install(_ pack: MusicLibraryCatalogue.Pack, archive: URL, to directory: URL) throws {
        let manager = FileManager.default
        let size = try archive.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard Int64(size ?? -1) == pack.bytes, try MusicLibrary.hash(archive) == pack.sha256 else { throw Failure.corrupt }
        try validateArchive(pack, archive: archive)
        try Task.checkCancellation()
        let listing = try run(["-Z1", archive.path])
        let names = String(decoding: listing, as: UTF8.self).split(separator: "\n").map(String.init)
        guard names.count == pack.files.count, Set(names) == Set(pack.files.map(\.path)) else { throw Failure.archive }
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let staging = directory.appendingPathComponent(".incoming-" + UUID().uuidString)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: staging) }
        for file in pack.files {
            try Task.checkCancellation()
            let destination = staging.appendingPathComponent(file.path)
            try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            manager.createFile(atPath: destination.path, contents: nil)
            let output = try FileHandle(forWritingTo: destination)
            // unzip treats member names as patterns, including literal brackets in song titles.
            let pattern = file.path.reduce("") { $0 + ("[]*?\\".contains($1) ? "\\" : "") + String($1) }
            do { _ = try run(["-p", archive.path, pattern], output: output); try output.close() }
            catch { try? output.close(); throw error }
            let written = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize
            guard Int64(written ?? -1) == file.bytes, try MusicLibrary.hash(destination) == file.sha256 else { throw Failure.corrupt }
        }
        guard SoundtrackCatalogue.load(at: staging.appendingPathComponent("Music")) != nil,
              MusicTimingCatalogue.load(at: staging.appendingPathComponent("Music")) != nil else { throw Failure.archive }
        let marker = try JSONEncoder().encode(["id": pack.id, "sha256": pack.sha256])
        try marker.write(to: staging.appendingPathComponent("installed.json"), options: .atomic)
        try Task.checkCancellation()
        let final = directory.appendingPathComponent(pack.id)
        if manager.fileExists(atPath: final.path) {
            _ = try manager.replaceItemAt(final, withItemAt: staging)
        } else { try manager.moveItem(at: staging, to: final) }
    }

    private func validateArchive(_ pack: MusicLibraryCatalogue.Pack, archive: URL) throws {
        let data = try Data(contentsOf: archive, options: .mappedIfSafe)
        func u16(_ p: Int) -> Int { Int(data[p]) | Int(data[p+1]) << 8 }
        func u32(_ p: Int) -> Int { u16(p) | u16(p+2) << 16 }
        guard data.count >= 22,
              let end = stride(from: data.count-22, through: max(0, data.count-65557), by: -1).first(where: {
                  u32($0) == 0x06054b50 && $0 + 22 + u16($0+20) == data.count
              }), u16(end+4) == 0, u16(end+6) == 0,
              u16(end+8) == pack.files.count, u16(end+10) == pack.files.count else { throw Failure.archive }
        let expected = Dictionary(uniqueKeysWithValues: pack.files.map { ($0.path, $0.bytes) })
        var offset = u32(end+16), seen = Set<String>()
        guard offset <= end, u32(end+12) == end-offset else { throw Failure.archive }
        for _ in pack.files {
            guard offset+46 <= end, u32(offset) == 0x02014b50 else { throw Failure.archive }
            let length = u16(offset+28)
            let next = offset+46+length+u16(offset+30)+u16(offset+32)
            guard next <= end, u16(offset+8) & 1 == 0, [0,8].contains(u16(offset+10)),
                  u16(offset+34) == 0,
                  (u32(offset+38) >> 16) & 0xF000 != 0xA000 else { throw Failure.archive }
            let name = String(decoding: data[(offset+46)..<(offset+46+length)], as: UTF8.self)
            guard seen.insert(name).inserted, expected[name] == Int64(u32(offset+24)) else { throw Failure.archive }
            offset = next
        }
        guard offset == end else { throw Failure.archive }
    }

    private func run(_ arguments: [String], output: FileHandle? = nil) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = arguments
        let pipe = Pipe()
        if let output { process.standardOutput = output } else { process.standardOutput = pipe }
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output == nil ? pipe.fileHandleForReading.readDataToEndOfFile() : Data()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw Failure.archive }
        return data
    }
}
