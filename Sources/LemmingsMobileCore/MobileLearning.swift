import Foundation
import LemmingsAppCore
import NxlvKit

/// Learning visits and the immutable queue belong to the current player or Hot Seat.
public struct MobileLearningState: Codable, Equatable, Sendable {
    public var progress = LearningJourneyProgress()
    public var run: LevelSequenceRun?
    public var journeySession: JourneySessionSnapshot?
    public private(set) var savedRuns: [LevelSequenceRun] = []
    public init() {}
    private enum CodingKeys: String, CodingKey { case progress, run, journeySession, savedRuns }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        progress = try values.decode(LearningJourneyProgress.self, forKey: .progress)
        run = try values.decodeIfPresent(LevelSequenceRun.self, forKey: .run)?.removingMultiplayerLevels()
        journeySession = try values.decodeIfPresent(JourneySessionSnapshot.self, forKey: .journeySession)
        savedRuns = try values.decodeIfPresent([LevelSequenceRun].self, forKey: .savedRuns) ?? []
    }

    public mutating func refreshJourneySession() {
        // A progression run does not end the journey saved alongside it.
        guard let run, run.source == .playlist(LearningJourney.playlistID) else { return }
        let current = run
        guard journeySession?.run != current else { return }
        let l2 = current.id == journeySession?.run?.id ? journeySession?.l2Progress ?? [:] : [:]
        journeySession = .init(run: current, l2Progress: l2)
    }
    public mutating func importJourneySession(_ incoming: JourneySessionSnapshot) {
        guard incoming.updatedAt > (journeySession?.updatedAt ?? .distantPast) else { return }
        if run == nil || run?.source == .playlist(LearningJourney.playlistID) { run = incoming.run }
        journeySession = incoming
    }
    public mutating func start(_ entries: [LevelPlaylistEntry], name: String, poolID: String,
                               playlistID: UUID = LearningJourney.playlistID) throws {
        let next = try LevelSequenceRun(source: .playlist(playlistID),
            pool: LevelPool(id: poolID, summary: name), entries: entries.filter { LearningJourney.isSinglePlayer($0) })
        refreshJourneySession()
        preserveCurrentRun()
        run = next
    }
    private mutating func preserveCurrentRun() {
        guard let run else { return }
        savedRuns.removeAll { $0.id == run.id }
        savedRuns.insert(run, at: 0)
    }
    public mutating func resumeJourney() {
        if journeySession == nil, run?.source == .playlist(LearningJourney.playlistID) { return }
        let saved = journeySession.map { $0.run } ?? savedRuns.first {
            $0.source == .playlist(LearningJourney.playlistID)
        }
        guard let saved, saved.id != run?.id else { return }
        preserveCurrentRun()
        savedRuns.removeAll { $0.id == saved.id }
        run = saved
    }
    public mutating func select(_ index: Int) throws {
        guard let current = run else { return }
        run = try LevelSequenceRun(id: current.id, source: current.source, pool: current.pool,
            entries: current.entries, currentIndex: index, seed: current.seed,
            algorithm: current.algorithm, createdAt: current.createdAt)
    }

    public mutating func record(won: Bool) {
        guard let run else { return }
        if run.pool.id.hasPrefix("learning-") { progress.record(run.currentEntry.identity, won: won) }
    }
    @discardableResult public mutating func advance() -> Bool {
        guard var current = run else { return false }
        guard current.advance() else {
            if current.source == .playlist(LearningJourney.playlistID) {
                journeySession = .init(run: nil)
            }
            run = nil
            return false
        }
        run = current; return true
    }
}

/// A saved journey retains its solo owner or complete Hot Seat roster and turn.
public struct MobileLearningResume: Sendable {
    public let state: MobileLearningState
    public let seat: MobileHotSeat?
    public let owner: String
    public var scope: String { seat?.scope ?? owner }
    public var resumeTitle: String {
        guard let run = state.run else { return L10n.text("Resume") }
        if run.pool.id.hasPrefix("learning-") { return L10n.text("Resume journey") }
        return L10n.text("Resume \(run.pool.summary)  \(run.currentIndex + 1)/\(run.entries.count)")
    }

    public static func find(owner: String, seats: MobileHotSeatStore,
                            storage: (String) -> MobileStorage, journeyOnly: Bool = true,
                            currentSessionOnly: Bool = true,
                            snapshot: (String?) -> JourneySessionSnapshot? = { _ in nil }) -> Self? {
        if currentSessionOnly, let current = seats.current, !current.players.contains(owner) { return nil }
        let candidates = [seats.current].compactMap { $0 }.filter { $0.players.contains(owner) }
            + seats.sharedSessions(player: owner)
        let allScopes: [(String, MobileHotSeat?)] = seats.current?.players.contains(owner) == true
            ? [(seats.current!.scope, seats.current)] + [(owner, nil)]
                + candidates.filter { $0.id != seats.current?.id }.map { ($0.scope, $0) }
            : [(owner, nil)] + candidates.map { ($0.scope, $0) }
        let scopes = currentSessionOnly ? Array(allScopes.prefix(1)) : allScopes
        var visited: Set<String> = []
        for (scope, seat) in scopes where visited.insert(scope).inserted {
            var state = storage(scope).load(MobileLearningState.self, name: "learning") ?? .init()
            if let incoming = snapshot(seat?.id) { state.importJourneySession(incoming) }
            if journeyOnly || state.run == nil { state.resumeJourney() }
            guard let run = state.run else { continue }
            if journeyOnly, !(run.source == .playlist(LearningJourney.playlistID) && run.pool.id.hasPrefix("learning-")) { continue }
            return Self(state: state, seat: seat, owner: owner)
        }
        return nil
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
                               number: $0.offset + 1, title: $0.element.levelNameSnapshot,
                               origin: $0.element.identity.packID.hasPrefix("fan:") || $0.element.identity.engine == .neolemmix ? .fanMade : .official,
                               packName: $0.element.packNameSnapshot)
        }
    }
    public func levelKey(at index: Int) -> String {
        guard entries.indices.contains(index) else { return "" }
        return entries[index].identity.packID + "|" + entries[index].identity.levelID
    }
    public func origin(of index: Int) throws -> (pack: String, index: Int, library: any MobileGameLibrary) {
        guard entries.indices.contains(index) else { throw MobileSessionError.changedLevel }
        let entry = entries[index], identity = entry.identity
        guard identity.engine == .classic else { throw MobileSessionError.journeyEngineUnavailable }
        let pack: MobileContentPack?
        if identity.packID.hasPrefix("fan:") { pack = catalogue.pack(id: String(identity.packID.dropFirst(4))) }
        else {
            let release = identity.packID.split(separator: "-").first.map(String.init) ?? ""
            pack = catalogue.pack(id: "release/" + release)
        }
        guard let pack else { throw MobileSessionError.changedLevel }
        if opened[pack.id] == nil {
            let current = try catalogue.library(for: pack)
            opened = [pack.id: current]
        }
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
    public func checkpointLevelIdentifier(at index: Int) throws -> String? {
        let source = try origin(of: index)
        return try source.library.checkpointLevelIdentifier(at: source.index)
    }
    public func loadLevel(at index: Int) throws -> MobileLevelContent {
        let origin = try origin(of: index)
        let loaded = try origin.library.loadLevel(at: origin.index)
        return .init(summary: levels[index], session: loaded.session)
    }
}
