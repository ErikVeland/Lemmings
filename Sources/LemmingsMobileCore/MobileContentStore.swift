import Foundation

public typealias MobileContentValidator = @Sendable (URL) throws -> Void

/// Stages and validates player-owned game data before replacing the live copy.
public struct MobileContentStore: Sendable {
    public static let maximumImportBytes: Int64 = 2 * 1_024 * 1_024 * 1_024

    public let root: URL
    public var gameDataDirectory: URL { root.appendingPathComponent("Game Data", isDirectory: true) }
    public var checkpointURL: URL { root.appendingPathComponent("Checkpoints/current.json") }

    private let validator: MobileContentValidator

    public init(fileManager: FileManager = .default) throws {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        root = applicationSupport.appendingPathComponent("Ultimate Lemmings/iOS", isDirectory: true)
        validator = Self.validateClassicData
    }

    public init(root: URL) {
        self.root = root
        validator = Self.validateClassicData
    }

    public init(root: URL, validator: @escaping MobileContentValidator) {
        self.root = root
        self.validator = validator
    }

    public func loadLibrary() throws -> ClassicMobileLibrary? {
        guard FileManager.default.fileExists(atPath: gameDataDirectory.path) else { return nil }
        return try ClassicMobileLibrary(directory: gameDataDirectory)
    }

    /// Copies a document-picker folder only after complete staged validation.
    public func install(directory source: URL) throws {
        let manager = FileManager.default
        let values = try source.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { throw MobileContentStoreError.notDirectory }
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        let staging = root.appendingPathComponent("Import-\(UUID().uuidString)", isDirectory: true)
        let backup = root.appendingPathComponent("Previous-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        var committed = false
        defer {
            if !committed { try? manager.removeItem(at: staging) }
            try? manager.removeItem(at: backup)
        }

        guard let walker = manager.enumerator(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { throw MobileContentStoreError.unreadable }
        var total: Int64 = 0
        let sourceParts = source.standardizedFileURL.pathComponents
        for case let item as URL in walker {
            let itemValues = try item.resourceValues(forKeys: [
                .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
            ])
            guard itemValues.isSymbolicLink != true else { throw MobileContentStoreError.symbolicLink }
            let parts = item.standardizedFileURL.pathComponents
            guard parts.starts(with: sourceParts) else { throw MobileContentStoreError.unreadable }
            let relative = parts.dropFirst(sourceParts.count)
            guard !relative.isEmpty,
                  !relative.contains(".."),
                  relative.count <= 32 else { throw MobileContentStoreError.unreadable }
            let destination = relative.reduce(staging) { $0.appendingPathComponent($1) }
            if itemValues.isDirectory == true {
                try manager.createDirectory(at: destination, withIntermediateDirectories: true)
            } else if itemValues.isRegularFile == true {
                total += Int64(itemValues.fileSize ?? 0)
                guard total <= Self.maximumImportBytes else { throw MobileContentStoreError.tooLarge }
                try manager.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try manager.copyItem(at: item, to: destination)
            }
        }

        try validator(staging)
        if manager.fileExists(atPath: gameDataDirectory.path) {
            try manager.moveItem(at: gameDataDirectory, to: backup)
        }
        do {
            try manager.moveItem(at: staging, to: gameDataDirectory)
            var installed = gameDataDirectory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try installed.setResourceValues(values)
            committed = true
        } catch {
            if manager.fileExists(atPath: gameDataDirectory.path) {
                try? manager.removeItem(at: gameDataDirectory)
            }
            if manager.fileExists(atPath: backup.path) {
                try? manager.moveItem(at: backup, to: gameDataDirectory)
            }
            throw error
        }
    }

    private static func validateClassicData(at directory: URL) throws {
        _ = try ClassicMobileLibrary(directory: directory)
    }
}

public enum MobileContentStoreError: Error, LocalizedError, Equatable {
    case notDirectory
    case unreadable
    case symbolicLink
    case tooLarge

    public var errorDescription: String? {
        switch self {
        case .notDirectory: return "Choose a folder that contains the original game data."
        case .unreadable: return "The selected game-data folder could not be read safely."
        case .symbolicLink: return "Remove symbolic links from the game-data folder."
        case .tooLarge: return "The selected folder is larger than 2 GB."
        }
    }
}
