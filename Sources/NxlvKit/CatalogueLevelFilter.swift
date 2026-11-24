import Foundation

public enum CatalogueProgressFilter: CaseIterable, Equatable, Sendable {
    case all, incomplete, cleared

    public var title: String {
        switch self {
        case .all: L10n.text("All levels")
        case .incomplete: L10n.text("Incomplete")
        case .cleared: L10n.text("Cleared")
        }
    }

    public var next: Self {
        switch self {
        case .all: .incomplete
        case .incomplete: .cleared
        case .cleared: .all
        }
    }

    public func levelsInPack<T>(_ levels: [T], query: String, title: (T) -> String,
                                completed: (T) -> Bool) -> [T] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var incomplete: [T] = []
        var cleared: [T] = []
        for level in levels where query.isEmpty || title(level).localizedStandardContains(query) {
            if completed(level) {
                if self != .incomplete { cleared.append(level) }
            } else if self != .cleared {
                incomplete.append(level)
            }
        }
        return incomplete + cleared
    }
}

extension ArcadeRecords {
    public func clearedNeoLemmixLevels(profileID: String) -> Set<LevelCatalogueIdentity> {
        var wins: Set<LevelCatalogueIdentity> = []
        func include(_ run: ArcadeRun) {
            guard run.profileID == profileID, run.qualifies,
                  let conditions = run.level.conditions, conditions.gameID == "neolemmix" else { return }
            wins.insert(.init(engine: .neolemmix, packID: conditions.packID, levelID: conditions.levelID))
        }
        for run in runs { include(run) }
        for attempt in trolley.attempts { include(attempt.run) }
        return wins
    }
}
