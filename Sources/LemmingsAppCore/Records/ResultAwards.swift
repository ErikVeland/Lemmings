import NxlvKit

/// Both result screens use the same star and final-note reward rules.
public enum ResultAwards {
    public static func ornament(report: ArcadeReport, celebration: TrolleyCelebration, history: TrolleyHistory) -> Bool {
        guard report.run.qualifies else { return false }
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
