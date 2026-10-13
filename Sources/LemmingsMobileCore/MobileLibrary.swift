import Foundation

/// A level's briefing and library entry, independent of its simulation engine.
public struct MobileLevelSummary: Codable, Equatable, Sendable {
    public let index: Int
    public let rank: String
    public let number: Int
    public let title: String

    public init(index: Int, rank: String, number: Int, title: String) {
        self.index = index
        self.rank = rank
        self.number = number
        self.title = title
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
