import Foundation

/**
 * Describes one player-selected file without an archive or executable payload.
 */
public struct LocalImportFile: Codable, Equatable, Sendable {
    public let path: String
    public let bytes: Int64

    public init(path: String, bytes: Int64) {
        self.path = path
        self.bytes = bytes
    }
}

/**
 * Bounds a local browser transfer before the native game importer sees it.
 */
public struct LocalImportManifest: Codable, Equatable, Sendable {
    public static let maximumFiles = 20_000
    public static let maximumBytes: Int64 = 2 * 1_024 * 1_024 * 1_024
    public static let maximumFileBytes: Int64 = 256 * 1_024 * 1_024
    public static let maximumChunkBytes = 1_024 * 1_024
    public let files: [LocalImportFile]

    public init(files: [LocalImportFile]) {
        self.files = files
    }

    public func validated() throws -> LocalImportManifest {
        guard !files.isEmpty, files.count <= Self.maximumFiles else {
            throw LocalImportTransferError.limit
        }
        var names = Set<String>()
        var total: Int64 = 0
        for file in files {
            let parts = file.path.split(separator: "/", omittingEmptySubsequences: false)
            guard !file.path.isEmpty, file.path.utf8.count <= 1_024,
                  !file.path.contains("\\"),
                  !file.path.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }),
                  parts.count <= 32,
                  parts.allSatisfy({ !$0.isEmpty && !$0.hasPrefix(".") && $0.utf8.count <= 255 }) else {
                throw LocalImportTransferError.path
            }
            let name = file.path.precomposedStringWithCanonicalMapping.folding(
                options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            guard names.insert(name).inserted else { throw LocalImportTransferError.path }
            guard file.bytes >= 0, file.bytes <= Self.maximumFileBytes,
                  file.bytes <= Self.maximumBytes - total else {
                throw LocalImportTransferError.limit
            }
            total += file.bytes
        }
        var directories = Set<String>()
        for name in names {
            var parts = name.split(separator: "/").map(String.init)
            while parts.count > 1 {
                parts.removeLast()
                let parent = parts.joined(separator: "/")
                if names.contains(parent) { throw LocalImportTransferError.path }
                directories.insert(parent)
                guard names.count + directories.count <= Self.maximumFiles else {
                    throw LocalImportTransferError.limit
                }
            }
        }
        return self
    }
}

public enum LocalImportTransferError: Error, LocalizedError, Equatable {
    case path, limit, request, order, incomplete

    public var errorDescription: String? {
        switch self {
        case .path: "The selected files contain an unsupported or duplicate path."
        case .limit: "The selected files exceed the transfer limits."
        case .request: "The transfer request is invalid. Open the address on the TV again."
        case .order: "The transfer stopped. Select the game folder again."
        case .incomplete: "The transfer is incomplete. Select the game folder again."
        }
    }
}

/**
 * Accepts only bounded HTTP/1.1 requests with one explicit, unambiguous body size.
 */
public struct LocalImportHTTPHead: Sendable {
    public static let maximumHeaderBytes = 8_192
    public static let maximumBodyBytes = 2 * 1_024 * 1_024
    public let method: String
    public let target: String
    public let headers: [String: String]
    public let contentLength: Int
    public let bodyOffset: Int

    public static func decode(_ data: Data) throws -> LocalImportHTTPHead? {
        guard let end = data.range(of: Data("\r\n\r\n".utf8)) else {
            guard data.count <= maximumHeaderBytes else { throw LocalImportTransferError.limit }
            return nil
        }
        guard end.upperBound <= maximumHeaderBytes,
              let text = String(data: data[..<end.lowerBound], encoding: .utf8),
              text.unicodeScalars.allSatisfy({ $0.value == 9 || $0.value == 10 || $0.value == 13
                  || (32...126).contains($0.value) }) else { throw LocalImportTransferError.request }
        let lines = text.components(separatedBy: "\r\n")
        let request = (lines.first ?? "").components(separatedBy: " ")
        guard request.count == 3, ["GET", "POST"].contains(request[0]),
              request[2] == "HTTP/1.1", request[1].hasPrefix("/"),
              request[1].utf8.count <= 1_024 else { throw LocalImportTransferError.request }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { throw LocalImportTransferError.request }
            let name = String(line[..<colon]).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, name.utf8.allSatisfy({ (97...122).contains($0)
                || (48...57).contains($0) || $0 == 45 }),
                  !value.contains("\r"), !value.contains("\n"),
                  headers.updateValue(value, forKey: name) == nil else {
                throw LocalImportTransferError.request
            }
        }
        guard let host = headers["host"], !host.isEmpty, host.utf8.count <= 255,
              !host.contains(" "), !host.contains("\t"),
              headers["transfer-encoding"] == nil, headers["content-encoding"] == nil,
              headers["expect"] == nil else { throw LocalImportTransferError.request }
        let length: Int
        if let raw = headers["content-length"] {
            guard !raw.isEmpty, raw.utf8.allSatisfy({ (48...57).contains($0) }),
                  let parsed = Int(raw), parsed <= maximumBodyBytes else {
                throw LocalImportTransferError.limit
            }
            length = parsed
        } else {
            guard request[0] == "GET" else { throw LocalImportTransferError.request }
            length = 0
        }
        guard request[0] != "GET" || length == 0 else { throw LocalImportTransferError.request }
        return LocalImportHTTPHead(method: request[0], target: request[1], headers: headers,
                                   contentLength: length, bodyOffset: end.upperBound)
    }
}

/**
 * Writes ordered chunks into an isolated staging folder and never installs them.
 */
public final class LocalImportTransferSession {
    public let directory: URL
    public let manifest: LocalImportManifest
    public private(set) var receivedBytes: Int64 = 0
    private let manager: FileManager
    private var received: [Int64]

    public init(manifest: LocalImportManifest, stagingRoot: URL, fileManager: FileManager = .default) throws {
        self.manifest = try manifest.validated()
        self.manager = fileManager
        self.received = Array(repeating: 0, count: manifest.files.count)
        directory = stagingRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            for file in manifest.files {
                let target = directory.appendingPathComponent(file.path)
                try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data().write(to: target, options: .withoutOverwriting)
            }
        } catch {
            try? manager.removeItem(at: directory)
            throw error
        }
    }

    public func append(_ data: Data, file index: Int, offset: Int64) throws {
        guard manifest.files.indices.contains(index), offset == received[index] else {
            throw LocalImportTransferError.order
        }
        guard !data.isEmpty, data.count <= LocalImportManifest.maximumChunkBytes,
              Int64(data.count) <= manifest.files[index].bytes - received[index] else {
            throw LocalImportTransferError.limit
        }
        let target = directory.appendingPathComponent(manifest.files[index].path)
        let values = try target.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              Int64(values.fileSize ?? -1) == received[index] else { throw LocalImportTransferError.order }
        let handle = try FileHandle(forWritingTo: target)
        defer { try? handle.close() }
        _ = try handle.seekToEnd()
        try handle.write(contentsOf: data)
        received[index] += Int64(data.count)
        receivedBytes += Int64(data.count)
    }

    public func completeDirectory() throws -> URL {
        for (index, file) in manifest.files.enumerated() {
            let values = try directory.appendingPathComponent(file.path).resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard received[index] == file.bytes, values.isRegularFile == true,
                  values.isSymbolicLink != true, Int64(values.fileSize ?? -1) == file.bytes else {
                throw LocalImportTransferError.incomplete
            }
        }
        return directory
    }

    public func cancel() {
        try? manager.removeItem(at: directory)
    }

    deinit {
        try? manager.removeItem(at: directory)
    }
}
