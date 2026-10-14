import Foundation

/// Hash-bound gain trims and source loop points for recorded music.
public struct MusicPlaybackCatalogue: Decodable, Sendable {
    public struct Entry: Decodable, Sendable {
        public struct Loop: Decodable, Sendable {
            public let startFrame: Int64
            public let endFrame: Int64
            public let sourcePath: String
            public let sourceSHA256: String
        }
        public let variantID: String
        public let path: String
        public let sourceSHA256: String
        public let playbackSHA256: String?
        public let sampleRate: Double
        public let frameCount: Int64
        public let integratedLUFS: Double
        public let truePeakDBTP: Double
        public let gainDB: Double
        public let loop: Loop?
        public let loopStatus: String

        public var expectedSHA256: String { playbackSHA256 ?? sourceSHA256 }

        /// Segment playback keeps the intro once and repeats only the source loop.
        public func segment(first: Bool, repeats: Bool, fileFrames: Int64,
                            fileRate: Double) -> (start: Int64, count: Int64) {
            guard repeats, let loop, fileRate == sampleRate, fileFrames >= loop.endFrame else {
                return (0, fileFrames)
            }
            let start = first ? 0 : loop.startFrame
            return (start, loop.endFrame - start)
        }

        /// The audio-node counter continues across queued loop segments.
        public func position(at elapsedSeconds: Double, repeats: Bool) -> Double {
            guard repeats, let loop else { return max(0, elapsedSeconds) }
            let start = Double(loop.startFrame) / sampleRate
            let end = Double(loop.endFrame) / sampleRate
            guard elapsedSeconds >= end else { return max(0, elapsedSeconds) }
            return start + (elapsedSeconds - end).truncatingRemainder(dividingBy: end - start)
        }
    }

    public let schemaVersion: Int
    public let variants: [Entry]

    public init(data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
        func hash(_ value: String) -> Bool { value.count == 64 && value.allSatisfy(\.isHexDigit) }
        func path(_ value: String) -> Bool {
            !value.isEmpty && !value.hasPrefix("/") && !value.split(separator: "/").contains("..")
        }
        guard schemaVersion == 1, Set(variants.map(\.path)).count == variants.count,
              Set(variants.map(\.variantID)).count == variants.count else { throw InvalidProfile.invalid }
        for entry in variants {
            guard path(entry.path), hash(entry.sourceSHA256), hash(entry.expectedSHA256),
                  entry.sampleRate.isFinite, entry.sampleRate > 0, entry.frameCount > 0,
                  entry.integratedLUFS.isFinite, entry.truePeakDBTP.isFinite,
                  entry.gainDB.isFinite, (-60...6).contains(entry.gainDB),
                  ["verified-vgm", "unverified-source-loop", "source-has-no-loop", "missing-conversion-provenance"].contains(entry.loopStatus),
                  (entry.loop != nil) == (entry.loopStatus == "verified-vgm") else { throw InvalidProfile.invalid }
            if let loop = entry.loop {
                guard entry.loopStatus == "verified-vgm", path(loop.sourcePath), hash(loop.sourceSHA256),
                      loop.startFrame >= 0, loop.endFrame > loop.startFrame,
                      loop.endFrame <= entry.frameCount else { throw InvalidProfile.invalid }
            }
        }
    }
    private enum InvalidProfile: Error { case invalid }

    public static func load(at root: URL) -> Self? {
        guard let data = try? Data(contentsOf: root.appendingPathComponent("recording-playback.json")) else { return nil }
        return try? Self(data: data)
    }
    public func entry(path: String) -> Entry? { variants.first { $0.path == path } }
}
