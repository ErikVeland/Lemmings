import Foundation
import LemmingsAppCore
import NxlvKit

/// Learning visits and the immutable queue belong to the current player or Hot Seat.
public struct MobileLearningState: Codable, Equatable, Sendable {
    public var progress = LearningJourneyProgress()
    public var run: LevelSequenceRun?
    public init() {}
    public mutating func start(_ entries: [LevelPlaylistEntry], name: String, poolID: String,
                               playlistID: UUID = LearningJourney.playlistID) throws {
        run = try LevelSequenceRun(source: .playlist(playlistID),
            pool: LevelPool(id: poolID, summary: name), entries: entries)
    }
    public mutating func record(won: Bool) {
        guard let run else { return }
        if run.pool.id.hasPrefix("learning-") { progress.record(run.currentEntry.identity, won: won) }
    }
    @discardableResult public mutating func advance() -> Bool {
        guard var current = run else { return false }
        guard current.advance() else { run = nil; return false }
        run = current; return true
    }
}

/// A shared catalogue queue opens only its current pack. Missing entries never disappear.
public final class MobileJourneyLibrary: MobileGameLibrary {
    public let entries: [LevelPlaylistEntry]
    public let displayName: String
    public let levels: [MobileLevelSummary]
    private let catalogue: MobileCatalogue
    private var opened: [String: (any MobileGameLibrary)] = [:]
    private var revisions: [String: String] = [:]
    public init(entries: [LevelPlaylistEntry], name: String, catalogue: MobileCatalogue) {
        self.entries = entries; displayName = name; self.catalogue = catalogue
        levels = entries.enumerated().map {
            MobileLevelSummary(index: $0.offset, rank: $0.element.packNameSnapshot,
                               number: $0.offset + 1, title: $0.element.levelNameSnapshot)
        }
    }
    public func levelKey(at index: Int) -> String {
        guard entries.indices.contains(index) else { return "" }
        return entries[index].identity.packID + "|" + entries[index].identity.levelID
    }
    public func origin(of index: Int) throws -> (pack: String, index: Int, library: any MobileGameLibrary) {
        guard entries.indices.contains(index) else { throw MobileSessionError.changedLevel }
        let entry = entries[index], identity = entry.identity
        guard identity.engine == .classic else { throw MobileSessionError.frameUnavailable }
        let pack: MobileContentPack?
        if identity.packID.hasPrefix("fan:") { pack = catalogue.pack(id: String(identity.packID.dropFirst(4))) }
        else {
            let release = identity.packID.split(separator: "-").first.map(String.init) ?? ""
            pack = catalogue.pack(id: "release/" + release)
        }
        guard let pack else { throw MobileSessionError.changedLevel }
        if opened[pack.id] == nil { opened[pack.id] = try catalogue.library(for: pack) }
        guard let library = opened[pack.id] else { throw MobileSessionError.changedLevel }
        let index: Int?
        if let fan = library as? ClassicFanMobileLibrary {
            revisions[pack.id] = fan.pack.fingerprint
            index = fan.entries.firstIndex { $0.key == identity.levelID }
        } else {
            let parts = identity.levelID.split(separator: ":", omittingEmptySubsequences: false)
            index = parts.first.flatMap { Int($0) }
            guard let index, library.levels.indices.contains(index), parts.count == 5,
                  library.levels[index].rank == parts[1], library.levels[index].number == Int(parts[2]),
                  library.levels[index].title == entry.levelNameSnapshot else { throw MobileSessionError.changedLevel }
            if revisions[pack.id] == nil {
                let data = try? Data(contentsOf: catalogue.portsRoot.appendingPathComponent("source-revisions.json"))
                let staged = data.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) }
                if let revision = staged?[identity.packID] ?? staged?[String(identity.packID.split(separator: "-").first ?? "")] {
                    revisions[pack.id] = revision
                }
                else if let stock = library as? ClassicMobileLibrary {
                    revisions[pack.id] = ClassicSourceRevision.bundledCampaign(stock.dataSet.title, root: stock.directory)
                } else if library is ClassicOhYesMobileLibrary {
                    revisions[pack.id] = ClassicSourceRevision.bundledCampaign(.ohYesMoreLemmings, root: catalogue.portsRoot)
                }
            }
        }
        guard let index, revisions[pack.id] == entry.sourceRevision else { throw MobileSessionError.changedLevel }
        return (pack.id, index, library)
    }
    public func loadLevel(at index: Int) throws -> MobileLevelContent {
        let origin = try origin(of: index)
        let loaded = try origin.library.loadLevel(at: origin.index)
        return .init(summary: levels[index], session: loaded.session)
    }
}
