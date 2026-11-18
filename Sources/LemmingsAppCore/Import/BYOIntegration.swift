import CryptoKit
import Foundation
import NxlvKit

public enum BYOGame: String, CaseIterable, Codable, Sendable {
    case classic
    case lemmings2
    case lemmings3

    public var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .lemmings2: return "Lemmings 2"
        case .lemmings3: return "Lemmings 3"
        }
    }
}

public struct BYOImportLimits: Sendable {
    public let maximumBytes: Int64
    public let maximumFileBytes: Int64
    public let maximumFiles: Int
    public let maximumDepth: Int

    public init(
        maximumBytes: Int64 = 2 * 1_024 * 1_024 * 1_024,
        maximumFileBytes: Int64 = 256 * 1_024 * 1_024,
        maximumFiles: Int = 20_000, maximumDepth: Int = 32
    ) {
        self.maximumBytes = max(0, maximumBytes)
        self.maximumFileBytes = max(0, maximumFileBytes)
        self.maximumFiles = max(0, maximumFiles)
        self.maximumDepth = max(0, maximumDepth)
    }
}

public struct BYOInstalledContent: Sendable {
    public let game: BYOGame
    public let directory: URL
    public let fileCount: Int
    public let bytes: Int64
}

public typealias BYOContentValidator = @Sendable (URL, BYOGame) throws -> Void
public typealias BYOFileManagerProvider = @Sendable () -> FileManager

public enum BYOIntegrationError: Error, LocalizedError, Equatable {
    case notDirectory
    case symbolicLink
    case unsupportedEntry
    case unsafePath
    case exceedsLimits
    case emptyFolder
    case changedFile(String)
    case invalidManifest
    case rollbackFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notDirectory: return "Choose the folder that contains your game data."
        case .symbolicLink: return "Remove symbolic links from the selected game folder."
        case .unsupportedEntry: return "The game folder contains an unsupported file type."
        case .unsafePath: return "Choose a game folder outside the import storage folder."
        case .exceedsLimits: return "The game folder exceeds the import size, file count or folder depth limit."
        case .emptyFolder: return "The selected game folder is empty."
        case let .changedFile(path): return "The game file changed during import: \(path)."
        case .invalidManifest: return "The installed game data does not match its import record. Import the game folder again."
        case let .rollbackFailed(path): return "The previous import remains in \(path). Keep this folder for recovery."
        }
    }
}

/**
 * Stages player-selected game data and validates it before replacing an installed copy.
 */
public struct BYOIntegration: Sendable {
    public static let manifestName = ".ultimate-lemmix-import.json"
    public let root: URL
    private let fileManagerProvider: BYOFileManagerProvider
    private var fileManager: FileManager { fileManagerProvider() }
    private let limits: BYOImportLimits
    private let validator: BYOContentValidator

    private struct Entry: Codable, Equatable {
        let path: String
        let bytes: Int64
        let sha256: String
    }

    private struct Manifest: Codable {
        let schemaVersion: Int
        let game: BYOGame
        let files: [Entry]
    }

    public init(
        root: URL, limits: BYOImportLimits = BYOImportLimits(),
        fileManager: @escaping BYOFileManagerProvider = { .default },
        validator: @escaping BYOContentValidator = BYOIntegration.validateGame
    ) {
        self.root = root.standardizedFileURL
        self.limits = limits
        fileManagerProvider = fileManager
        self.validator = validator
    }

    /**
     * Returns a recorded import location without reading commercial files at launch.
     */
    public func installedDirectory(for game: BYOGame) -> URL? {
        let directory = destination(for: game)
        guard let values = try? directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              values.isDirectory == true, values.isSymbolicLink != true,
              let data = try? Data(contentsOf: directory.appendingPathComponent(Self.manifestName)),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
              manifest.schemaVersion == 1, manifest.game == game, !manifest.files.isEmpty else { return nil }
        return directory
    }

    /**
     * Checks installed bytes against the import record and the native data readers.
     */
    public func verifyInstalled(game: BYOGame) throws -> BYOInstalledContent {
        let directory = destination(for: game)
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(Self.manifestName)),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
              manifest.schemaVersion == 1, manifest.game == game else {
            throw BYOIntegrationError.invalidManifest
        }
        let files = try inventory(directory)
        guard files == manifest.files else { throw BYOIntegrationError.invalidManifest }
        try validator(directory, game)
        return receipt(game: game, directory: directory, files: files)
    }

    /**
     * Copies and validates an import. A failed replacement restores the previous copy.
     */
    @discardableResult
    public func install(directory source: URL, game: BYOGame) throws -> BYOInstalledContent {
        let source = source.standardizedFileURL
        let sourceParts = source.resolvingSymlinksInPath().pathComponents
        let rootParts = root.resolvingSymlinksInPath().pathComponents
        guard !sourceParts.starts(with: rootParts), !rootParts.starts(with: sourceParts) else {
            throw BYOIntegrationError.unsafePath
        }
        let files = try inventory(source)
        guard !files.isEmpty else { throw BYOIntegrationError.emptyFolder }
        if fileManager.fileExists(atPath: root.path) { try requireDirectory(root) }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let staging = root.appendingPathComponent("Import-\(UUID().uuidString)", isDirectory: true)
        let backup = root.appendingPathComponent("Previous-\(UUID().uuidString)", isDirectory: true)
        let destination = destination(for: game)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: staging) }

        for file in files {
            let target = staging.appendingPathComponent(file.path)
            try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.copyItem(at: source.appendingPathComponent(file.path), to: target)
        }
        guard try inventory(staging) == files else { throw BYOIntegrationError.invalidManifest }
        try validator(staging, game)
        let manifest = Manifest(schemaVersion: 1, game: game, files: files)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(manifest).write(to: staging.appendingPathComponent(Self.manifestName), options: .atomic)

        let hadPrevious = fileManager.fileExists(atPath: destination.path)
        if hadPrevious {
            try requireDirectory(destination)
            try fileManager.moveItem(at: destination, to: backup)
        }
        do {
            try fileManager.moveItem(at: staging, to: destination)
        } catch {
            if hadPrevious {
                do { try fileManager.moveItem(at: backup, to: destination) }
                catch { throw BYOIntegrationError.rollbackFailed(backup.path) }
            }
            throw error
        }
        if hadPrevious { try? fileManager.removeItem(at: backup) }
        return receipt(game: game, directory: destination, files: files)
    }

    /**
     * Validates required campaign and artwork files with the existing native readers.
     */
    public static func validateGame(directory: URL, game: BYOGame) throws {
        switch game {
        case .classic:
            let dataSet = try ClassicDataSet.detect(directory: directory)
            _ = try ClassicMainDATAssets.load(from: directory)
            for style in Set(dataSet.campaign.levels.map(\.level.groundStyle)) {
                _ = try ClassicGroundSet.load(style: style, from: directory)
            }
            for style in Set(dataSet.campaign.levels.map(\.level.specialStyle)).filter({ $0 > 0 }) {
                _ = try ClassicSpecialGraphic.load(index: style - 1, from: directory)
            }
        case .lemmings2:
            _ = try Lemmings2Campaign(root: directory)
            _ = try Lemmings2Practice(root: directory)
            _ = try Lemmings2FrontEnd(root: directory)
            _ = try Lemmings2Sprites(data: Data(contentsOf: directory.appendingPathComponent("VLEMMS.DAT")))
            _ = try Lemmings2TerrainMasks(root: directory)
            _ = try Lemmings2Explosion(root: directory)
            for name in Lemmings2Campaign.styleNames {
                _ = try Lemmings2Style(data: Data(contentsOf: directory.appendingPathComponent("STYLES/\(name).DAT")))
            }
        case .lemmings3:
            for tribe in Lemmings3ClassicCampaign.Tribe.allCases {
                let campaign = try Lemmings3ClassicCampaign(root: directory, tribe: tribe)
                let style = try Lemmings3Style(directory: directory.appendingPathComponent("STYLES"), number: tribe.rawValue)
                _ = try style.constructionTile()
                let prefix = String(format: "GRAPHICS/TRIBE%03d", tribe.spriteStyle)
                _ = try Lemmings3Sprites(index: Data(contentsOf: directory.appendingPathComponent(prefix + ".IND")),
                    commands: Data(contentsOf: directory.appendingPathComponent(prefix + ".CMP")))
                for level in campaign.levels {
                    _ = try Lemmings3Objects(data: Data(contentsOf: directory.appendingPathComponent(
                        String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
                    _ = try Lemmings3Objects(data: Data(contentsOf: directory.appendingPathComponent(
                        String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
                }
            }
        }
    }

    private func destination(for game: BYOGame) -> URL {
        root.appendingPathComponent(game.rawValue, isDirectory: true)
    }

    private func receipt(game: BYOGame, directory: URL, files: [Entry]) -> BYOInstalledContent {
        BYOInstalledContent(game: game, directory: directory, fileCount: files.count, bytes: files.reduce(0) { $0 + $1.bytes })
    }

    private func requireDirectory(_ directory: URL) throws {
        let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else { throw BYOIntegrationError.symbolicLink }
        guard values.isDirectory == true else { throw BYOIntegrationError.notDirectory }
    }

    private func inventory(_ directory: URL) throws -> [Entry] {
        try requireDirectory(directory)
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        var enumerationError: Error?
        guard let walker = fileManager.enumerator(at: directory, includingPropertiesForKeys: Array(keys),
            options: [], errorHandler: { _, error in enumerationError = error; return false }) else {
            throw BYOIntegrationError.notDirectory
        }
        let base = directory.standardizedFileURL.pathComponents
        var total: Int64 = 0
        var entries = 0
        var names = Set<String>()
        var files: [Entry] = []
        for case let item as URL in walker {
            entries += 1
            guard entries <= limits.maximumFiles else { throw BYOIntegrationError.exceedsLimits }
            let values = try item.resourceValues(forKeys: keys)
            guard values.isSymbolicLink != true else { throw BYOIntegrationError.symbolicLink }
            let parts = item.standardizedFileURL.pathComponents
            guard parts.starts(with: base) else { throw BYOIntegrationError.unsafePath }
            let relative = Array(parts.dropFirst(base.count))
            guard !relative.isEmpty, !relative.contains(".."), relative.count <= limits.maximumDepth else {
                throw BYOIntegrationError.exceedsLimits
            }
            let path = relative.joined(separator: "/")
            guard names.insert(path.lowercased()).inserted else { throw BYOIntegrationError.unsafePath }
            if values.isDirectory == true { continue }
            guard values.isRegularFile == true else { throw BYOIntegrationError.unsupportedEntry }
            if relative.count == 1, path == Self.manifestName { continue }
            let size = Int64(values.fileSize ?? 0)
            guard size <= limits.maximumFileBytes, size <= limits.maximumBytes - total else {
                throw BYOIntegrationError.exceedsLimits
            }
            total += size
            files.append(Entry(path: path, bytes: size, sha256: try hash(item, expectedBytes: size)))
        }
        if let enumerationError { throw enumerationError }
        return files.sorted { $0.path < $1.path }
    }

    private func hash(_ url: URL, expectedBytes: Int64) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var value = SHA256()
        var count: Int64 = 0
        while let data = try handle.read(upToCount: 1_024 * 1_024), !data.isEmpty {
            count += Int64(data.count)
            guard count <= expectedBytes else { throw BYOIntegrationError.changedFile(url.lastPathComponent) }
            value.update(data: data)
        }
        guard count == expectedBytes else { throw BYOIntegrationError.changedFile(url.lastPathComponent) }
        return value.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
