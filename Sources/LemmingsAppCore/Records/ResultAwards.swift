import NxlvKit

/// Both result screens use the same star and final-note reward rules.
public enum ResultAwards {
    public struct EarnedReward: Equatable, Sendable {
        public let title: String
        public let reason: String
        public let isConsumable: Bool
        public init(title: String, reason: String, isConsumable: Bool = false) {
            self.title = title
            self.reason = reason
            self.isConsumable = isConsumable
        }
    }

    /// A receipt for this attempt. Balances and previously earned awards are not new rewards.
    public static func earnedRewards(report: ArcadeReport, celebration: TrolleyCelebration) -> [EarnedReward] {
        let run = report.run
        var rewards: [EarnedReward] = []
        if run.earnsConsumableRewards {
            if celebration.precisionRewards.superzoomUses > 0 {
                rewards.append(.init(title: L10n.text("+\(celebration.precisionRewards.superzoomUses) SUPERZOOM"),
                    reason: L10n.text("Three-star levels: \(celebration.careerBefore.threeStarLevels) to \(celebration.career.threeStarLevels). One Superzoom per 3 distinct levels without rewind, undo or a bonus skill."), isConsumable: true))
            }
            if report.earnedLevelSkip {
                rewards.append(.init(title: L10n.text("+1 LEVEL SKIP"),
                    reason: L10n.text("Three-star levels: \(celebration.careerBefore.threeStarLevels) to \(celebration.career.threeStarLevels). One Level Skip per 3 distinct levels without rewind, undo or a bonus skill."), isConsumable: true))
            }
            if report.earnedExtraSkill {
                rewards.append(.init(title: L10n.text("RARE: +1 BONUS SKILL"),
                    reason: L10n.text("Ten distinct three-star levels without rewind, undo or a bonus skill."), isConsumable: true))
            }
        }
        rewards += report.earned.map { award in
            let reason: String
            switch award {
            case .firstClear: reason = L10n.text("First clear of this level. Rescued \(run.saved); target \(run.level.required).")
            case .allHome: reason = L10n.text("Rescued all \(run.population) lemmings.")
            case .noSkills: reason = L10n.text("Cleared the level without assigning a skill.")
            case .oneSkill: reason = L10n.text("Cleared the level using one skill type.")
            case .betterRescue: reason = L10n.text("Rescued \(run.saved), up from your previous best of \(report.previousBest?.saved ?? 0).")
            case .fewerSkills: reason = L10n.text("Used \(run.skillCount) skills instead of \(report.previousBest?.skillCount ?? 0), with at least as many rescued.")
            }
            return .init(title: award.title, reason: reason)
        }
        rewards += celebration.newAwards.map { .init(title: $0.award.title, reason: $0.award.detail) }
        return rewards
    }

    public static func explanation(for award: TrolleyAchievement) -> String {
        guard award.group == .philosophy, let id = award.philosopherID else { return award.detail }
        return award.detail + "\n" + TrolleyAnalyser.archetype(id).affinityDescription
    }

    public static func ornament(report: ArcadeReport, celebration: TrolleyCelebration, history: TrolleyHistory) -> Bool {
        guard report.run.qualifies, !report.run.usedBonusSkill else { return false }
        let improved = report.previousBest != nil && (report.newRescueBest || report.newSkillBest)
        let rareAward = celebration.newAwards.contains { $0.award.tier == .gold || $0.award.tier == .legendary }
        if improved || rareAward { return true }
        guard let attempt = report.trolley?.attempt, let conditions = attempt.run.level.conditions,
              let index = history.attempts.firstIndex(where: { $0.id == attempt.id }) else { return false }
        let before = Array(history.attempts.prefix(index))
        let maximum = history.maximum(conditions: conditions, assisted: attempt.run.assisted)
        return [TrolleyBoard.fastestClear, .fastestAllSaved].contains { board in
            guard TrolleyLeaderboards.eligible(attempt, board: board, maximum: maximum),
                  let previous = TrolleyLeaderboards.rank(before, comparisonID: attempt.comparisonID,
                                                         board: board, maximum: maximum)
                    .first(where: { $0.run.profileID == attempt.run.profileID }) else { return false }
            return attempt.run.seconds < previous.run.seconds
        }
    }
}
