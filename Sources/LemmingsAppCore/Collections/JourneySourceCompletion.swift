import Foundation
import NxlvKit

/// Credits Journey wins to their source without inventing sequel population or medals.
public enum JourneySourceCompletion {
    public static func progress(_ learning: LearningJourneyProgress,
                                entries: [LevelPlaylistEntry] = []) -> GameProgressPreferences {
        var result = GameProgressPreferences()
        for identity in learning.completed {
            let parts = identity.levelID.split(separator: ":", omittingEmptySubsequences: false)
            switch identity.engine {
            case .classic:
                guard !identity.packID.contains(":"), parts.count == 5,
                      let release = identity.packID.split(separator: "-").first,
                      let title = ClassicTitle(rawValue: String(release)),
                      title != .lemmings2TheTribes, title != .lemmings3TheChronicles,
                      let index = Int(parts[0]), let count = title.expectedLevelCount,
                      (0..<count).contains(index) else { continue }
                result.addCompleted([index], pack: "release/" + title.rawValue)
            case .lemmings2:
                guard identity.packID.hasPrefix("tribes-"),
                      let tribe = Int(identity.packID.dropFirst(7)), (0..<12).contains(tribe),
                      parts.count == 2, let index = Int(parts[0]), (0..<10).contains(index) else { continue }
                result.addCompleted([tribe * 10 + index], pack: "release/lemmings2TheTribes")
            case .lemmings3:
                guard identity.packID.hasPrefix("chronicles-"),
                      let tribe = Int(identity.packID.dropFirst(11)), (1...3).contains(tribe),
                      parts.count == 2, let index = Int(parts[0]), (0..<30).contains(index) else { continue }
                result.addCompleted([(tribe - 1) * 30 + index], pack: "release/lemmings3TheChronicles")
            default: continue
            }
        }
        var fan: Set<String> = []
        var seen: Set<LevelCatalogueIdentity> = []
        for entry in entries where learning.completed.contains(entry.identity) {
            let identity = entry.identity
            guard identity.engine == .classic, identity.packID.hasPrefix("fan:"),
                  seen.insert(identity).inserted,
                  let separator = identity.levelID.lastIndex(of: "#"),
                  let section = Int(identity.levelID[identity.levelID.index(after: separator)...]) else { continue }
            let file = String(identity.levelID[..<separator])
            let label = section == -1 ? (file as NSString).lastPathComponent : entry.levelNameSnapshot
            let pack = String(identity.packID.dropFirst(4))
            guard pack.hasPrefix("lldb-") || pack.hasPrefix("file-") else { continue }
            let key = pack.hasPrefix("lldb-") ? "catalogue:" + pack : "file:" + pack.dropFirst(5)
            fan.insert("v2|" + key + "|" + label)
            result.addCompleted([entry.levelNumberSnapshot - 1], pack: pack)
        }
        if !fan.isEmpty { result.values["FanLevelsPassed"] = .fanLevels(fan) }
        return result
    }

    /// Imported campaigns retain their exact source identity.
    public static func classicIndices(packID: String, learning: LearningJourneyProgress) -> Set<Int> {
        Set(learning.completed.compactMap { identity in
            guard identity.engine == .classic, identity.packID == packID,
                  !packID.hasPrefix("fan:") else { return nil }
            let parts = identity.levelID.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 5, let index = Int(parts[0]), index >= 0 else { return nil }
            return index
        })
    }
}
