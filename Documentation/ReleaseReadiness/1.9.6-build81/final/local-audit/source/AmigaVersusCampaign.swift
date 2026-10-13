import Foundation

/// The two-player levels that shipped on the Amiga disks.
///
/// The Amiga releases stored every level as a plain 2048 byte record inside
/// `level000`, `level001` and so on, four records to a file. The one-player
/// levels come first and the two-player levels follow them, so the versus set
/// is a range of record numbers rather than a separate file.
///
/// The records use the same layout as the DOS levels, so `ClassicLevel` reads
/// them without any change. Only the release and the range differ.
///
/// Holiday Lemmings has no versus levels and no second panel, which is why it
/// is absent here.
public enum AmigaVersusCampaign {
    /// A release that carries versus levels, and where they sit.
    public struct Source: Sendable, Equatable {
        /// Folder name under the extracted Amiga tree.
        public let family: String
        /// Name to show a player.
        public let title: String
        /// Record numbers of the versus levels, counting from the first record
        /// of the first level file.
        public let records: Range<Int>
    }

    public static let sources: [Source] = [
        Source(family: "lemmings", title: "Lemmings", records: 80..<100),
        Source(family: "ohno", title: "Oh No! More Lemmings", records: 100..<110),
    ]

    public struct Entry: Sendable {
        public let source: Source
        /// Position within its own release, counting from one.
        public let number: Int
        public let level: ClassicLevel
    }

    public enum LoadError: Error, CustomStringConvertible {
        case noLevelFiles(family: String)
        case recordOutOfRange(family: String, record: Int, available: Int)

        public var description: String {
            switch self {
            case let .noLevelFiles(family):
                return "No level files were found for \(family)."
            case let .recordOutOfRange(family, record, available):
                return "\(family) has \(available) level records, so record \(record) is missing."
            }
        }
    }

    /// Reads every 2048 byte record of a release, in file then record order.
    public static func records(family: String, in root: URL) throws -> [Data] {
        let folder = root.appendingPathComponent(family, isDirectory: true)
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
            .filter { $0.hasPrefix("level") && $0 != "leveldata" }
            .sorted()
        guard !names.isEmpty else { throw LoadError.noLevelFiles(family: family) }

        var out: [Data] = []
        for name in names {
            let data = try Data(contentsOf: folder.appendingPathComponent(name))
            var start = 0
            while start + ClassicLevel.recordSize <= data.count {
                out.append(data.subdata(in: start..<(start + ClassicLevel.recordSize)))
                start += ClassicLevel.recordSize
            }
        }
        return out
    }

    /// Loads the versus levels of every release present under a root.
    ///
    /// A release whose data is not installed is skipped rather than failing, so
    /// the set that loads follows what the player has.
    public static func load(from root: URL) throws -> [Entry] {
        var entries: [Entry] = []
        for source in sources {
            guard let all = try? records(family: source.family, in: root) else { continue }
            for record in source.records {
                guard record < all.count else {
                    throw LoadError.recordOutOfRange(
                        family: source.family, record: record, available: all.count)
                }
                let level = try ClassicLevel(data: all[record])
                entries.append(Entry(
                    source: source,
                    number: record - source.records.lowerBound + 1,
                    level: level))
            }
        }
        return entries
    }
}
