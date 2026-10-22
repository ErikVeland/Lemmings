import Foundation

/**
 * Excludes exact bundled records without changing imports, archive bytes or saved identities.
 */
public struct BundledPlayableScope: Sendable {
    private struct Manifest: Decodable {
        struct Entry: Decodable, Sendable {
            let pack: String
            let archiveSHA256: String
            let member: String
        }
        let version: Int
        let exclusions: [Entry]
    }
    private let directory: URL
    private let exclusions: [Manifest.Entry]

    public init(directory: URL, manifest: Data) throws {
        let decoded = try JSONDecoder().decode(Manifest.self, from: manifest)
        self.directory = directory.standardizedFileURL
        exclusions = decoded.version == 1 ? decoded.exclusions : []
    }

    public init(resources: URL) throws {
        try self.init(directory: resources.appendingPathComponent("LevelPacks"),
            manifest: Data(contentsOf: resources.appendingPathComponent("Progression/bundled-playable-exclusions.json")))
    }

    public func applies(to pack: URL) -> Bool {
        pack.deletingLastPathComponent().standardizedFileURL.path == directory.path
            && exclusions.contains { $0.pack == pack.lastPathComponent }
    }

    public func members(in pack: URL, archiveSHA256: String) -> Set<String> {
        guard applies(to: pack) else { return [] }
        return Set(exclusions.filter {
            $0.pack == pack.lastPathComponent && $0.archiveSHA256 == archiveSHA256
        }.map(\.member))
    }

    public func entries(in pack: ClassicFanPack) -> [ClassicFanPack.Entry] {
        let excluded = members(in: pack.url, archiveSHA256: pack.fingerprint)
        return pack.entries().filter { !excluded.contains($0.key) }
    }
}
