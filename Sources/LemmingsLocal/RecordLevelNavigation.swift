#if os(macOS)
import Foundation
import NxlvKit

@MainActor enum RecordLevelNavigation {
    /// Unplayed entries have empty boards. Saved entries retain their exact rules.
    static func levels(current: ArcadeLevel, entries: [(id: String, title: String)]) -> [ArcadeLevel] {
        guard let conditions = current.conditions else { return savedLevels(current: current) }
        let recorded = ArcadeStore.shared.records.runs.map(\.level)
            + ArcadeStore.shared.records.trolley.attempts.map { $0.run.level } + [current]
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

    static func savedLevels(current: ArcadeLevel?) -> [ArcadeLevel] {
        let levels = ArcadeStore.shared.records.runs.map(\.level)
            + ArcadeStore.shared.records.trolley.attempts.map { $0.run.level } + [current].compactMap { $0 }
        return Dictionary(grouping: levels, by: \.boardID).values.compactMap(\.last)
            .sorted { ($0.game, $0.title, $0.boardID) < ($1.game, $1.title, $1.boardID) }
    }
}
#endif
