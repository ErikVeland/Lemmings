import Foundation
import NxlvKit

@MainActor public enum RecordLevelNavigation {
    /// Unplayed entries have empty boards. Saved entries retain their exact rules.
    public static func levels(current: ArcadeLevel, entries: [(id: String, title: String)],
                              records: ArcadeRecords) -> [ArcadeLevel] {
        guard let conditions = current.conditions else { return savedLevels(current: current, records: records) }
        let recorded = records.runs.map(\.level)
            + records.trolley.attempts.map { $0.run.level } + [current]
        var known: [String: ArcadeLevel] = [:]
        for level in recorded {
            guard let c = level.conditions, c.gameID == conditions.gameID,
                  c.packID == conditions.packID else { continue }
            known[c.levelID] = level
        }
        return entries.map { entry in
            known[entry.id] ?? ArcadeLevel(id: "unplayed:" + [conditions.gameID, conditions.packID, entry.id].joined(separator: "|"),
                title: entry.title, game: current.game, rules: current.rules, total: 1, required: 0)
        }
    }

    public static func savedLevels(current: ArcadeLevel?, records: ArcadeRecords) -> [ArcadeLevel] {
        let levels = records.runs.map(\.level)
            + records.trolley.attempts.map { $0.run.level } + [current].compactMap { $0 }
        return Dictionary(grouping: levels, by: \.boardID).values.compactMap(\.last)
            .sorted { ($0.game, $0.title, $0.boardID) < ($1.game, $1.title, $1.boardID) }
    }
}
