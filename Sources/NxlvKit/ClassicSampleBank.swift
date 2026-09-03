import Foundation

/// A bank of digitized sound effects stored as a length table plus one
/// concatenated block of samples.
///
/// The Lemmings Chronicles CD ships `SFX001.IND` and `SFX001.RAW`. The index
/// holds one little-endian length per effect. The raw file holds the effects
/// end to end as unsigned 8-bit PCM, silence at 128.
///
/// The declared lengths can overrun the raw file slightly, so the last effect
/// is clamped rather than rejected. Refusing to load the whole bank over a few
/// missing bytes would throw away every working effect.
public struct ClassicSampleBank: Sendable {
    public struct Sample: Sendable {
        public let index: Int
        /// Unsigned 8-bit PCM, silence at 128.
        public let pcm: [UInt8]
        /// True when the file ran out before the declared length.
        public let wasTruncated: Bool

        public var frameCount: Int { pcm.count }

        /// Converts to signed floating point in the range -1 to 1.
        public func floatSamples() -> [Float] {
            pcm.map { (Float($0) - 128.0) / 128.0 }
        }

        /// Peak level, for spotting empty or clipped effects.
        public var peak: Float {
            floatSamples().reduce(0) { Swift.max($0, abs($1)) }
        }
    }

    public let samples: [Sample]
    /// Bytes the index claimed beyond the end of the raw file.
    public let missingBytes: Int

    public enum LoadError: Error, CustomStringConvertible {
        case emptyIndex
        case malformedIndex(Int)

        public var description: String {
            switch self {
            case .emptyIndex: return "the index file is empty"
            case let .malformedIndex(count):
                return "the index is \(count) bytes, which is not a whole number of entries"
            }
        }
    }

    public init(indexData: Data, rawData: Data) throws {
        guard !indexData.isEmpty else { throw LoadError.emptyIndex }
        guard indexData.count % 4 == 0 else {
            throw LoadError.malformedIndex(indexData.count)
        }

        let index = [UInt8](indexData)
        let raw = [UInt8](rawData)
        var lengths: [Int] = []
        for offset in stride(from: 0, to: index.count, by: 4) {
            let value = UInt32(index[offset])
                | UInt32(index[offset + 1]) << 8
                | UInt32(index[offset + 2]) << 16
                | UInt32(index[offset + 3]) << 24
            lengths.append(Int(value))
        }

        var built: [Sample] = []
        var cursor = 0
        var missing = 0
        for (number, length) in lengths.enumerated() {
            let end = cursor + length
            let clamped = Swift.min(end, raw.count)
            let truncated = clamped < end
            if truncated { missing += end - clamped }
            let pcm = cursor < clamped ? Array(raw[cursor..<clamped]) : []
            built.append(Sample(index: number, pcm: pcm, wasTruncated: truncated))
            cursor = end
        }
        samples = built
        missingBytes = missing
    }

    /// Loads a bank from an index and a raw file.
    public static func load(indexURL: URL, rawURL: URL) throws -> ClassicSampleBank {
        try ClassicSampleBank(
            indexData: Data(contentsOf: indexURL, options: .mappedIfSafe),
            rawData: Data(contentsOf: rawURL, options: .mappedIfSafe))
    }

    /// Finds `SFX###.IND` and its matching raw file in a directory.
    public static func discover(in directory: URL) throws -> [ClassicSampleBank] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        let indexes = contents
            .filter { $0.pathExtension.lowercased() == "ind" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return try indexes.compactMap { indexURL in
            let base = indexURL.deletingPathExtension().lastPathComponent
            let candidates = contents.filter {
                $0.deletingPathExtension().lastPathComponent.caseInsensitiveCompare(base)
                    == .orderedSame && $0.pathExtension.lowercased() == "raw"
            }
            guard let rawURL = candidates.first else { return nil }
            return try load(indexURL: indexURL, rawURL: rawURL)
        }
    }
}
