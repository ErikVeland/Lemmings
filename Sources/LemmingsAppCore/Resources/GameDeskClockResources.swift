import CryptoKit
import Foundation
import NxlvKit

/**
 * Publishes selected owned clock artwork for the separate widget process.
 */
public enum GameDeskClockResources {
    public static let applicationGroup = "group.academy.glasscode.lemmings"

    private struct Selection: Codable, Equatable {
        let version: Int
        let artwork: String?
    }

    public static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: applicationGroup)
    }

    /**
     * Uses an injected group container. Nil resources select the bundled Lix artwork.
     */
    @discardableResult
    public static func publish(resourceURL: URL?, containerURL: URL?) throws -> Bool {
        guard let containerURL else { return false }
        let folder = storage(in: containerURL)
        let manager = FileManager.default
        let source = resourceURL?.appendingPathComponent("MacArtwork/lemmings", isDirectory: true)
        var artwork: String?
        if let source, manager.fileExists(atPath: source.path) {
            let files = try regularFiles(in: source)
            var hash = SHA256()
            for file in files {
                hash.update(data: Data(file.lastPathComponent.utf8))
                hash.update(data: Data([0]))
                hash.update(data: try Data(contentsOf: file, options: .mappedIfSafe))
            }
            let identity = hash.finalize().map { String(format: "%02x", $0) }.joined()
            let destination = folder.appendingPathComponent(identity, isDirectory: true)
            if !manager.fileExists(atPath: destination.path) {
                try manager.createDirectory(at: folder, withIntermediateDirectories: true)
                let staging = folder.appendingPathComponent(".staging-" + UUID().uuidString, isDirectory: true)
                defer { try? manager.removeItem(at: staging) }
                let directory = staging.appendingPathComponent("MacArtwork/lemmings", isDirectory: true)
                try manager.createDirectory(at: directory, withIntermediateDirectories: true)
                for file in files {
                    try manager.copyItem(at: file, to: directory.appendingPathComponent(file.lastPathComponent))
                }
                try validate(directory)
                try manager.moveItem(at: staging, to: destination)
            }
            artwork = identity
        }
        let selection = Selection(version: 1, artwork: artwork)
        let manifest = folder.appendingPathComponent("selection.json")
        if let data = try? Data(contentsOf: manifest),
           let previous = try? JSONDecoder().decode(Selection.self, from: data), previous == selection { return false }
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        // Publish last. Existing immutable trees remain available to an in-flight widget render.
        try JSONEncoder().encode(selection).write(to: manifest, options: .atomic)
        return true
    }

    /**
     * Resolves a published tree, or the extension's own licensed fallback resources.
     */
    public static func artworkDirectory(containerURL: URL?, bundledResourceURL: URL?) -> URL? {
        if let containerURL {
            let folder = storage(in: containerURL)
            if let data = try? Data(contentsOf: folder.appendingPathComponent("selection.json")),
               let selection = try? JSONDecoder().decode(Selection.self, from: data), selection.version == 1,
               let identity = selection.artwork, identity.count == 64,
               identity.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) {
                let directory = folder.appendingPathComponent(identity + "/MacArtwork/lemmings", isDirectory: true)
                if FileManager.default.fileExists(atPath: directory.appendingPathComponent("manifest.json").path) {
                    return directory
                }
            }
        }
        return bundledResourceURL?.appendingPathComponent("MacArtwork/lemmings", isDirectory: true)
    }

    private static func storage(in container: URL) -> URL {
        container.appendingPathComponent("Library/Application Support/UltimateLemmix/DeskClockArtwork", isDirectory: true)
    }

    private static func regularFiles(in directory: URL) throws -> [URL] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey]
        let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else { throw CocoaError(.fileReadCorruptFile) }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys))
        for file in files {
            let values = try file.resourceValues(forKeys: keys)
            guard values.isRegularFile == true, values.isSymbolicLink != true else { throw CocoaError(.fileReadCorruptFile) }
        }
        return files.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func validate(_ directory: URL) throws {
        let artwork = try ClassicMacArtwork(directory: directory)
        let required = [(1400, 75), (1500, 3), (1500, 10), (1600, 0), (1600, 16)]
        guard required.allSatisfy({ artwork.frame($0.0, $0.1) != nil }),
              let interface = ClassicMacUserInterface(artwork: artwork),
              interface.font(.small) != nil, interface.font(.large) != nil else { throw CocoaError(.fileReadCorruptFile) }
    }
}
