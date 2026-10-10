import Foundation

public struct MusicRhythmCatalogue: Decodable, Sendable {
    public struct Entry: Decodable, Sendable {
        public let path: String
        public let sourceSHA256: String
        /// Set when the bundled copy was re-encoded after analysis.
        public let playbackSHA256: String?
        public let loopPath: String
        public let sha256: String
        public let durationSeconds: Double
        public var expectedSHA256: String { playbackSHA256 ?? sourceSHA256 }
    }
    public let schemaVersion: Int
    public let variants: [Entry]
    public init(data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
        guard schemaVersion == 1, Set(variants.map(\.path)).count == variants.count else { throw Invalid.entry }
        for entry in variants {
            guard !entry.path.hasPrefix("/"), !entry.path.split(separator: "/").contains(".."),
                  entry.loopPath.hasPrefix(".rhythm/"), entry.loopPath.split(separator: "/").count == 2,
                  !entry.loopPath.contains(".."), !entry.loopPath.contains("\\"),
                  entry.durationSeconds.isFinite, (0.1...12.01).contains(entry.durationSeconds),
                  [entry.sourceSHA256, entry.sha256, entry.expectedSHA256].allSatisfy({ $0.count == 64 && $0.allSatisfy(\.isHexDigit) }) else { throw Invalid.entry }
        }
    }
    private enum Invalid: Error { case entry }
}
