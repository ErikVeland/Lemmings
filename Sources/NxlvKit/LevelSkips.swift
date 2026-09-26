import Foundation

/// A player's level skips. Every third unassisted three-star level earns one.
///
/// Earned skips are derived from recorded attempts, so they need no storage of
/// their own. Only the levels a player spent a skip on are stored.
public struct LevelSkipBalance: Equatable, Sendable {
    public static let threeStarLevelsPerSkip = 3

    public let threeStarLevels: Int
    public let spent: Int

    public init(threeStarLevels: Int, spent: Int) {
        self.threeStarLevels = max(0, threeStarLevels)
        self.spent = max(0, spent)
    }

    public var earned: Int { threeStarLevels / Self.threeStarLevelsPerSkip }
    public var available: Int { max(0, earned - spent) }
    /// Three-star levels still needed for the next skip.
    public var threeStarLevelsToNext: Int {
        Self.threeStarLevelsPerSkip - threeStarLevels % Self.threeStarLevelsPerSkip
    }
}

extension ArcadeRecords {
    /// Rewound runs do not earn skips, so only unassisted stars count.
    public func levelSkips(profileID: String) -> LevelSkipBalance {
        let score = TrolleyCareerScore(profileID: profileID, attempts: trolley.attempts, assisted: false)
        return LevelSkipBalance(threeStarLevels: score.threeStarLevels,
                                spent: skippedLevels[profileID]?.count ?? 0)
    }

    public func hasSkipped(_ level: ArcadeLevel, profileID: String) -> Bool {
        skippedLevels[profileID]?.contains(TrolleyCareerScore.levelKey(level)) == true
    }

    /// Spends one skip on `level`. A level takes at most one skip.
    @discardableResult
    public mutating func spendLevelSkip(on level: ArcadeLevel, profileID: String) -> Bool {
        guard profile(profileID) != nil, levelSkips(profileID: profileID).available > 0,
              !hasSkipped(level, profileID: profileID) else { return false }
        skippedLevels[profileID, default: []].append(TrolleyCareerScore.levelKey(level))
        return true
    }
}
