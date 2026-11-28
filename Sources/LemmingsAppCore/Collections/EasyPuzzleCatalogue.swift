import Foundation
import NxlvKit

public enum EasyPuzzleCatalogue {
    public struct Puzzle: Decodable, Sendable {
        public let entry: LevelPlaylistEntry
        public let score: Int
        public let skills: [String]
    }

    public static var title: String { L10n.text("Easy puzzles") }
    public static let puzzles = puzzles(storage: .current())
    public static let maximumWins = 3
    public static let queueSize = 6

    public static func puzzles(storage: AppStorage) -> [Puzzle] {
        let url = storage.resources.appendingPathComponent("Progression/easy-puzzles.json")
        guard let data = try? Data(contentsOf: url),
              let values = try? JSONDecoder().decode([Puzzle].self, from: data) else { return [] }
        return values.filter {
            $0.entry.identity.engine == .classic && (0..<200).contains($0.score)
                && !$0.skills.isEmpty && LearningJourney.isSinglePlayer($0.entry)
        }
    }

    public static func queue(from puzzles: [Puzzle], familiarSkills: Set<String>,
                             excluding: Set<LevelCatalogueIdentity>, seed: UInt64,
                             limit: Int = queueSize) -> [LevelPlaylistEntry] {
        var pool = puzzles.filter { !excluding.contains($0.entry.identity) }
        let ordered = pool.map(\.entry).sorted {
            ($0.identity.packID, $0.identity.levelID) < ($1.identity.packID, $1.identity.levelID)
        }
        guard let shuffled = try? LevelShuffleAlgorithm.splitMix64FisherYatesV1.ordered(ordered, seed: seed)
        else { return [] }
        let tieBreak = Dictionary(uniqueKeysWithValues: shuffled.enumerated().map { ($0.element.identity, $0.offset) })
        var result: [Puzzle] = []
        var familiar = familiarSkills
        while !pool.isEmpty && result.count < limit {
            let previous = result.last
            let preferFan = result.count.isMultiple(of: 2)
            func cost(_ puzzle: Puzzle) -> Int {
                let identity = puzzle.entry.identity
                let skills = Set(puzzle.skills)
                let newSkills = familiar.isEmpty ? 0 : skills.subtracting(familiar).count
                let repeatedPack = previous?.entry.identity.packID == identity.packID
                let step = previous.map { max(0, puzzle.score - $0.score - 25) / 5 } ?? 0
                let preferredSource = identity.packID.hasPrefix("fan:") == preferFan
                return puzzle.score / 20 + step + newSkills * 4 + (repeatedPack ? 16 : 0) + (preferredSource ? 0 : 4)
            }
            guard let index = pool.indices.min(by: {
                (cost(pool[$0]), tieBreak[pool[$0].entry.identity, default: 0])
                    < (cost(pool[$1]), tieBreak[pool[$1].entry.identity, default: 0])
            }) else { break }
            let next = pool.remove(at: index)
            familiar.formUnion(next.skills)
            result.append(next)
        }
        return result.map(\.entry)
    }

    public static func run(entries: [LevelPlaylistEntry]) throws -> LevelSequenceRun {
        try LevelSequenceRun(source: .easyPuzzles, pool: LevelPool(id: "easy-puzzles-v1", summary: title),
                             entries: Array(entries.prefix(queueSize)))
    }

    public static func canContinue(_ run: LevelSequenceRun, wins: Set<LevelCatalogueIdentity>) -> Bool {
        !run.isAtEnd && run.entries.prefix(run.currentIndex + 1).filter { wins.contains($0.identity) }.count < maximumWins
    }

    @MainActor public static func exclusions(profileID: String, sessionID: String?,
                                             current: LevelCatalogueIdentity? = nil) -> Set<LevelCatalogueIdentity> {
        let progress = GameProgressPreferences.learning(profileID: profileID, sessionID: sessionID)
        let clearedFans = GameProgressPreferences.fanLevels(profileID: profileID, sessionID: sessionID)
        let progressOwner = sessionID.map { "hotseat." + $0 } ?? profileID
        var exclude = progress.completed.union(progress.later)
            .union(swaps(profileID: profileID, sessionID: sessionID))
        if let current { exclude.insert(current) }
        var clearedCampaigns: [String: Set<Int>] = [:]
        for puzzle in puzzles {
            let entry = puzzle.entry
            let identity = entry.identity
            if identity.packID.hasPrefix("fan:lldb-") {
                let label = identity.levelID.hasSuffix("#-1")
                    ? String(identity.levelID.dropLast(3)).components(separatedBy: "/").last ?? entry.levelNameSnapshot
                    : entry.levelNameSnapshot
                if clearedFans.contains("v2|catalogue:\(identity.packID.dropFirst(4))|\(label)") {
                    exclude.insert(identity)
                }
            } else if let release = identity.packID.split(separator: "-").first,
                      let number = identity.levelID.split(separator: ":").first.flatMap({ Int($0) }) {
                let key = "release/" + release
                if clearedCampaigns[key] == nil {
                    clearedCampaigns[key] = GameProgressPreferences.completed(pack: key, profileID: progressOwner)
                }
                if clearedCampaigns[key]?.contains(number) == true { exclude.insert(identity) }
            }
        }
        return exclude
    }

    @MainActor public static func swaps(profileID: String, sessionID: String?, defaults: UserDefaults = .standard)
        -> Set<LevelCatalogueIdentity> {
        guard let data = defaults.data(forKey: swapKey(profileID: profileID, sessionID: sessionID)) else { return [] }
        return (try? JSONDecoder().decode(Set<LevelCatalogueIdentity>.self, from: data)) ?? []
    }

    @MainActor public static func rememberSwap(_ entry: LevelPlaylistEntry, profileID: String, sessionID: String?,
                                    defaults: UserDefaults = .standard) throws {
        var saved = swaps(profileID: profileID, sessionID: sessionID, defaults: defaults)
        guard saved.insert(entry.identity).inserted else { return }
        defaults.set(try JSONEncoder().encode(saved), forKey: swapKey(profileID: profileID, sessionID: sessionID))
    }

    @MainActor private static func swapKey(profileID: String, sessionID: String?) -> String {
        sessionID.map { "HotSeat.\($0).EasyPuzzleSwaps" } ?? ArcadeStore.progressKey("EasyPuzzleSwaps", profileID: profileID)
    }
}
