import Foundation
import NxlvKit

/// A level's briefing and library entry, independent of its simulation engine.
public struct MobileLevelSummary: Codable, Equatable, Sendable {
    public let index: Int
    public let rank: String
    public let number: Int
    public let title: String
    public enum Origin: String, Codable, Sendable {
        case official, fanMade, unspecified
        public var label: String {
            switch self { case .official: L10n.text("Official"); case .fanMade: L10n.text("Fan-made"); case .unspecified: "" }
        }
    }
    public let origin: Origin
    public let packName: String
    public var sourceLabel: String { [origin.label, packName].filter { !$0.isEmpty }.joined(separator: " / ") }
    public var locationLabel: String { "\(rank == packName ? "Level" : rank) \(number)" }
    public var caption: String { [sourceLabel, locationLabel].filter { !$0.isEmpty }.joined(separator: "\n") }

    /// Phone and carousel pages show preparation status in the same briefing slot.
    public func selectionSubtitle(rankCount: Int, status: String = "") -> String {
        if !status.isEmpty { return status }
        return sourceLabel + L10n.text("\n\(rank == packName ? L10n.text("Level") : rank)  \(number)/\(rankCount)")
    }

    private enum CodingKeys: String, CodingKey { case index, rank, number, title, origin, packName }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        index = try values.decode(Int.self, forKey: .index)
        rank = try values.decode(String.self, forKey: .rank)
        number = try values.decode(Int.self, forKey: .number)
        title = try values.decode(String.self, forKey: .title)
        origin = try values.decodeIfPresent(Origin.self, forKey: .origin) ?? .unspecified
        packName = try values.decodeIfPresent(String.self, forKey: .packName) ?? ""
    }

    public init(index: Int, rank: String, number: Int, title: String, origin: Origin = .unspecified, packName: String = "") {
        self.index = index
        self.rank = rank
        self.number = number
        self.title = title
        self.origin = origin
        self.packName = packName
    }
}

public struct MobileLevelContent {
    public let summary: MobileLevelSummary
    public let session: any MobileGameSession

    public init(summary: MobileLevelSummary, session: any MobileGameSession) {
        self.summary = summary
        self.session = session
    }
}

/// Content loaders create native sessions. The shell uses the shared contract.
public protocol MobileGameLibrary: AnyObject {
    var displayName: String { get }
    var levels: [MobileLevelSummary] { get }
    func loadLevel(at index: Int) throws -> MobileLevelContent
    func canSkipLevel(at index: Int) -> Bool
    /// Saves campaign advancement and returns a rollback for a failed transition.
    func prepareLevelSkip(at index: Int) throws -> () throws -> Void
    /// A key for the level that survives a pack gaining or losing other levels.
    func levelKey(at index: Int) -> String
    /// Identifies a saved run without constructing its simulation or artwork.
    func checkpointLevelIdentifier(at index: Int) throws -> String?
}

public extension MobileGameLibrary {
    func canSkipLevel(at index: Int) -> Bool { false }
    func prepareLevelSkip(at index: Int) throws -> () throws -> Void { throw MobileSessionError.changedLevel }
    func checkpointLevelIdentifier(at index: Int) throws -> String? { nil }

    /**
     * Finds a saved level after catalogue entries move, while preserving index-only libraries.
     */
    func checkpointLevelIndex(for checkpoint: MobileCheckpointEnvelope) throws -> Int {
        let preferred = checkpoint.levelIndex
        if levels.indices.contains(preferred) {
            let identifier = try checkpointLevelIdentifier(at: preferred)
            if identifier == nil || identifier == checkpoint.levelIdentifier { return preferred }
        }
        if let index = try levels.indices.first(where: {
            try checkpointLevelIdentifier(at: $0) == checkpoint.levelIdentifier
        }) { return index }
        throw MobileSessionError.changedLevel
    }

    func levelKey(at index: Int) -> String {
        guard levels.indices.contains(index) else { return "" }
        return "\(levels[index].rank)/\(levels[index].number)"
    }
}

public typealias ClassicMobileLevelSummary = MobileLevelSummary
public typealias ClassicMobileContent = MobileLevelContent
