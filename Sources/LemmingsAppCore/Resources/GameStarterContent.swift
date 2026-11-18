import CryptoKit
import Foundation
import NxlvKit

/**
 * Loads the pinned project-authored starter through the existing Classic data formats.
 */
public enum GameStarterContent {
    public static let identifier = "ultimate-lemmix-open-starter-v1"
    public static let displayName = "Open Starter"
    public static let relativeDirectory = "Ports/ultimate_lemmix_starter"

    public enum LoadError: Error, LocalizedError {
        case invalidStarter
        public var errorDescription: String? { "The starter level data is missing or has changed." }
    }

    private struct Marker: Decodable { let identifier: String }
    private static let files: [(String, Int, String)] = [
        ("GROUND0O.DAT", 1_056, "3e2abf438f827a31ccdd7bdfb90b01cd7b5859f51d94d703fa85c194ad792043"),
        ("LEVEL000.DAT", 6_207, "220730774faeb51c40ef46d9a496539232eacf996b5c5457a8d150a408a56872"),
        ("VGAGR0.DAT", 1_390, "de982848a5ae523746486d62e7bb2bc22b347b839ccb4a0aba1c2455602081d9"),
    ]

    public static func directory(in bundle: Bundle = GameResources.bundle) -> URL? {
        directory(in: bundle.resourceURL)
    }

    public static func directory(in resourceURL: URL?) -> URL? {
        guard let directory = resourceURL?.appendingPathComponent(relativeDirectory, isDirectory: true),
              isStarter(directory: directory) else { return nil }
        return directory
    }

    public static func isStarter(directory: URL) -> Bool {
        let required = Set(files.map { $0.0 } + ["starter-manifest.json"])
        guard let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil),
              Set(contents.map(\.lastPathComponent)).subtracting(["README.md"]) == required else { return false }
        let marker = directory.appendingPathComponent("starter-manifest.json")
        guard let markerData = boundedFile(marker, maximum: 16_384),
              let value = try? JSONDecoder().decode(Marker.self, from: markerData),
              value.identifier == identifier else { return false }
        for (name, size, fingerprint) in files {
            guard let data = boundedFile(directory.appendingPathComponent(name), maximum: size),
                  data.count == size,
                  SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == fingerprint else { return false }
        }
        return true
    }

    public static func dataSet(in directory: URL) throws -> ClassicDataSet {
        guard isStarter(directory: directory) else { throw LoadError.invalidStarter }
        return try ClassicDataSet.detect(directory: directory)
    }

    public static func groundSet(in directory: URL) throws -> ClassicGroundSet {
        guard isStarter(directory: directory) else { throw LoadError.invalidStarter }
        return try ClassicGroundSet.load(style: 0, from: directory)
    }

    private static func boundedFile(_ url: URL, maximum: Int) -> Data? {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true, values.isSymbolicLink != true,
              let count = values.fileSize, count > 0, count <= maximum else { return nil }
        return try? Data(contentsOf: url)
    }
}
