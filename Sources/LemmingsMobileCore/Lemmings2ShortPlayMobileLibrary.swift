import Foundation
import LemmingsAppCore
import NxlvKit

/// Carries the Classic tribe's survivors through the checked five-level opening.
/// Its progress is scoped to the saved queue, never the player's campaign.
public final class Lemmings2ShortPlayMobileLibrary: MobileGameLibrary {
    public let displayName: String
    public let levels: [MobileLevelSummary]
    private let source: Lemmings2MobileLibrary
    private let storage: MobileStorage
    private let entries: [MobileFavourites.Entry]
    public static let progressKey = "bundled"

    public static func entries(directory: URL) throws -> [MobileFavourites.Entry] {
        let campaign = try Lemmings2Campaign(root: directory)
        guard let sequence = ShortPlayCatalogue.sequence(id: "lemmings2") else { throw MobileSessionError.changedLevel }
        return try sequence.levels.enumerated().map { index, level in
            guard campaign.levels[index].fingerprint == level.levelSHA256 else { throw MobileSessionError.changedLevel }
            return .init(pack: level.identity.packID, level: level.identity.levelID, title: campaign.levels[index].title)
        }
    }
    public static func matches(_ entries: [MobileFavourites.Entry]) -> Bool {
        guard let sequence = ShortPlayCatalogue.sequence(id: "lemmings2"), entries.count == sequence.levels.count else { return false }
        return zip(entries, sequence.levels).allSatisfy { $0.pack == $1.identity.packID && $0.level == $1.identity.levelID }
    }
    public init(directory: URL, storage: MobileStorage, entries: [MobileFavourites.Entry], name: String) throws {
        guard Self.matches(entries), try Self.entries(directory: directory) == entries else { throw MobileSessionError.changedLevel }
        self.storage = storage; self.entries = entries; displayName = name
        source = try Lemmings2MobileLibrary(directory: directory, storage: storage)
        levels = Array(source.levels.prefix(entries.count))
    }
    public func levelKey(at index: Int) -> String { levels.indices.contains(index) ? entries[index].level : "" }
    public func checkpointLevelIdentifier(at index: Int) throws -> String? { try source.checkpointLevelIdentifier(at: index) }
    private func campaign() throws -> Lemmings2Campaign {
        var value = try Lemmings2Campaign(root: source.directory)
        if let saved = storage.load(Lemmings2Campaign.Progress.self, name: "lemmings2-campaign") { try value.restore(saved) }
        return value
    }
    public func loadLevel(at index: Int) throws -> MobileLevelContent {
        guard levels.indices.contains(index) else { throw MobileSessionError.changedLevel }
        var progress = try campaign()
        try progress.select(tribe: 0, level: index)
        return try source.loadLevel(at: index, population: progress.population)
    }
    public func record(_ session: any MobileGameSession) throws -> Data? {
        guard let capture = try session.actionCapture(), case let .lemmings2(runtime) = capture.final,
              runtime.isComplete, runtime.didWin, levels.indices.contains(session.levelIndex) else { return nil }
        var value = try campaign()
        try value.select(tribe: 0, level: session.levelIndex)
        guard value.advance(after: runtime) else { throw MobileSessionError.invalidCheckpoint }
        try storage.save(value.progress, name: "lemmings2-campaign")
        return try JSONEncoder().encode(value.progress)
    }
}
