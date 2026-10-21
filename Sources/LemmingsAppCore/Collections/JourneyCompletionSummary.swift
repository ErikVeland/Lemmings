import Foundation
import NxlvKit

/// Counts saved wins across routes without changing campaign progress or records.
public enum JourneyCompletionSummary {
    @MainActor public static func count(profileID: String, hotSeatID: String?,
        learning: LearningJourneyProgress, entries: [LevelPlaylistEntry] = [],
        profileIDs: [String] = [], additionalProgress: GameProgressPreferences = .init(),
        defaults: UserDefaults = .standard) -> Int {
        let prefix = hotSeatID.map { "HotSeat.\($0)." }
            ?? (profileID == ArcadeProfile.legacyID ? "" : "ArcadeProfile.\(profileID).")
        var wins: Set<String> = []
        let names = Dictionary(entries.map { ($0.identity, $0.levelNameSnapshot) }, uniquingKeysWith: { first, _ in first })
        for identity in learning.completed {
            let parts = identity.levelID.split(separator: ":")
            if identity.engine == .classic, identity.levelID.hasPrefix("passed:") {
                // An older imported source can retain its exact saved rank key
                // when its assets no longer match a current catalogue revision.
                wins.insert(classicKey(pack: identity.packID, rankKey: String(identity.levelID.dropFirst(7))))
            } else if identity.engine == .classic, parts.count == 5, let number = Int(parts[2]) {
                wins.insert(classicKey(pack: identity.packID, rankKey: "\(parts[1])#\(number - 1)"))
            } else if identity.engine == .lemmings2, let level = parts.first {
                wins.insert("l2|\(identity.packID)|\(level)")
            } else if identity.engine == .lemmings3, let level = parts.first {
                wins.insert("l3|\(identity.packID)|\(level)")
            } else if identity.packID.hasPrefix("fan:lldb-"), let name = names[identity] {
                let label = identity.levelID.hasSuffix("#-1")
                    ? String(identity.levelID.dropLast(3)).components(separatedBy: "/").last! : name
                wins.insert("fan|v2|catalogue:\(identity.packID.dropFirst(4))|\(label)")
            } else {
                wins.insert("\(identity.engine.rawValue)|\(identity.packID)|\(identity.levelID)")
            }
        }
        let decoder = JSONDecoder()
        for (key, value) in defaults.dictionaryRepresentation() {
            guard key.hasPrefix(prefix) else { continue }
            let base = String(key.dropFirst(prefix.count))
            if base.hasPrefix("ClassicGameProgress."), let data = value as? Data,
               let progress = try? decoder.decode(ClassicGameFlow.Progress.self, from: data) {
                let source = String(base.dropFirst("ClassicGameProgress.".count))
                for level in progress.passed { wins.insert(classicKey(pack: source, rankKey: level)) }
            } else if base == "nativeL2Campaign.v1.bundled", let data = value as? Data,
                      let progress = try? decoder.decode(Lemmings2Campaign.Progress.self, from: data) {
                for index in progress.results.keys { wins.insert("l2|tribes-\(index / 10)|\(index % 10)") }
            } else if ["nativeL3ClassicPreview.v1.bundled", "nativeL3EgyptianPreview.v1.bundled",
                       "nativeL3ShadowPreview.v1.bundled"].contains(base), let data = value as? Data,
                      let progress = try? decoder.decode(Lemmings3ClassicCampaign.Progress.self, from: data) {
                for index in progress.completed.keys { wins.insert("l3|chronicles-\((progress.tribe ?? .classic).rawValue)|\(index)") }
            } else if base == "FanLevelsPassed", let levels = value as? [String] {
                for level in levels { wins.insert("fan|" + level) }
            }
        }
        let portable = GameProgressPreferences.capture(defaults: defaults, profileID: profileID,
            profileIDs: Array(Set(profileIDs + [profileID])), sessionID: hotSeatID)
        for progress in [portable, additionalProgress] {
            for (key, value) in progress.values {
                switch value {
                case .completed(let indices):
                    let pack = String(key.dropFirst("cleared/".count))
                    guard pack.hasPrefix("release/"),
                          let title = ClassicTitle(rawValue: String(pack.dropFirst("release/".count))),
                          let limit = title.expectedLevelCount,
                          title != .lemmings2TheTribes, title != .lemmings3TheChronicles else { continue }
                    for index in indices where (0..<limit).contains(index) { wins.insert("classic|\(pack)|\(index)") }
                case .tribes(let saved):
                    for index in saved.results.keys { wins.insert("l2|tribes-\(index / 10)|\(index % 10)") }
                case .chronicles(let saved):
                    for index in saved.completed.keys { wins.insert("l3|chronicles-\((saved.tribe ?? .classic).rawValue)|\(index)") }
                default: break
                }
            }
        }
        return wins.count
    }

    /// Only stock campaign namespaces can share mobile's linear level indices.
    private static func classicKey(pack: String, rankKey: String) -> String {
        let titleID = String(pack.split(separator: "-").first ?? "")
        guard !pack.contains(":source-"), let title = ClassicTitle(rawValue: titleID),
              let separator = rankKey.lastIndex(of: "#"),
              let position = Int(rankKey[rankKey.index(after: separator)...]) else {
            return "classic|\(pack)|\(rankKey)"
        }
        let ranks: [(String, Int)]
        switch title {
        case .lemmings: ranks = ClassicCampaignDefinition.originalDOSLemmings.ranks.map { ($0.name, $0.order.count) }
        case .ohNoMoreLemmings: ranks = ClassicCampaignDefinition.ohNoMoreLemmings.ranks.map { ($0.name, $0.order.count) }
        case .xmasLemmings1991, .xmasLemmings1992, .holidayLemmings1993, .holidayLemmings1994:
            ranks = ClassicCampaignDefinition.festive(title)!.ranks.map { ($0.name, $0.order.count) }
        case .ohYesMoreLemmings:
            ranks = AmigaVersusCampaign.sources.map { ($0.title + " Versus", $0.records.count) } + [("Mega Drive Sunsoft", 30)]
        default: return "classic|\(pack)|\(rankKey)"
        }
        var offset = 0
        for (rank, count) in ranks {
            if rank == rankKey[..<separator], (0..<count).contains(position) {
                return "classic|release/\(titleID)|\(offset + position)"
            }
            offset += count
        }
        return "classic|\(pack)|\(rankKey)"
    }
}
