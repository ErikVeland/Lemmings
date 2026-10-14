import Foundation

/// A level's briefing and library entry, independent of its simulation engine.
public struct MobileLevelSummary: Codable, Equatable, Sendable {
    public let index: Int
    public let rank: String
    public let number: Int
    public let title: String
    public enum Origin: String, Codable, Sendable {
        case official, fanMade, unspecified
        public var label: String {
            switch self { case .official: "Official"; case .fanMade: "Fan-made"; case .unspecified: "" }
        }
    }
    public let origin: Origin
    public let packName: String
    public var sourceLabel: String { [origin.label, packName].filter { !$0.isEmpty }.joined(separator: " / ") }
    public var locationLabel: String { "\(rank == packName ? "Level" : rank) \(number)" }
    public var caption: String { [sourceLabel, locationLabel].filter { !$0.isEmpty }.joined(separator: "\n") }

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
    /// A key for the level that survives a pack gaining or losing other levels.
    func levelKey(at index: Int) -> String
    /// Identifies a saved run without constructing its simulation or artwork.
    func checkpointLevelIdentifier(at index: Int) throws -> String?
}

public extension MobileGameLibrary {
    func checkpointLevelIdentifier(at index: Int) throws -> String? { nil }
    func levelKey(at index: Int) -> String {
        guard levels.indices.contains(index) else { return "" }
        return "\(levels[index].rank)/\(levels[index].number)"
    }
}

public typealias ClassicMobileLevelSummary = MobileLevelSummary
public typealias ClassicMobileContent = MobileLevelContent
