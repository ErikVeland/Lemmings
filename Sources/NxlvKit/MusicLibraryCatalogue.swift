import Foundation

/// The app ships this index so a download never chooses its own paths or hashes.
public struct MusicLibraryCatalogue: Codable, Sendable {
    public struct File: Codable, Sendable {
        public let path: String
        public let bytes: Int64
        public let sha256: String
    }
    public struct Pack: Codable, Sendable {
        public let id: String
        public let title: String
        public let url: URL
        public let bytes: Int64
        public let sha256: String
        public let trackCount: Int
        public let files: [File]
    }
    public let schemaVersion: Int
    public let version: String
    public let packs: [Pack]

    public init(data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
        func hash(_ value: String) -> Bool { value.count == 64 && value.allSatisfy { $0.isHexDigit } }
        guard schemaVersion == 1, Set(packs.map(\.id)).count == packs.count else { throw Invalid.catalogue }
        for pack in packs {
            guard !pack.id.isEmpty, pack.id.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }),
                  pack.url.scheme == "https", pack.url.host != nil, pack.url.user == nil,
                  (1...2_000_000_000).contains(pack.bytes), hash(pack.sha256),
                  (1...1000).contains(pack.trackCount), !pack.files.isEmpty, pack.files.count <= 1100,
                  Set(pack.files.map(\.path)).count == pack.files.count else { throw Invalid.catalogue }
            var total: Int64 = 0
            for file in pack.files {
                let parts = file.path.split(separator: "/", omittingEmptySubsequences: false)
                guard file.path.hasPrefix("Music/"), !file.path.contains("\\"), !file.path.contains("\0"),
                      !file.path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                      !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }),
                      (1...500_000_000).contains(file.bytes), hash(file.sha256) else { throw Invalid.catalogue }
                total += file.bytes
            }
            guard total <= 4_000_000_000 else { throw Invalid.catalogue }
        }
    }
    public enum Invalid: Error { case catalogue }
}
