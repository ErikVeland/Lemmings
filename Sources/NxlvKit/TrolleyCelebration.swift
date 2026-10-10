import Foundation

/// Progress is derived from completed attempts. Retries never add duplicate level stars.
public struct TrolleyCareerScore: Equatable, Sendable {
    public let profileID: String
    public let stars: Int
    public let clearedLevels: Int
    public let threeStarLevels: Int

    public static func levelKey(_ run: ArcadeRun) -> String { levelKey(run.level) }
    public static func levelKey(_ level: ArcadeLevel) -> String {
        guard let c = level.conditions else { return level.id }
        return [c.gameID, c.packID, c.levelID].joined(separator: "|")
    }
    public init(profileID: String, attempts: [TrolleyAttempt], assisted: Bool) {
        self.profileID = profileID
        let personal = attempts.filter { $0.run.profileID == profileID && $0.run.assisted == assisted }
        let best = Dictionary(grouping: personal, by: { Self.levelKey($0.run) }).values.map {
            $0.map { $0.goals.stars }.max() ?? 0
        }
        stars = best.reduce(0, +)
        clearedLevels = best.filter { $0 > 0 }.count
        threeStarLevels = best.filter { $0 == 3 }.count
    }
    public static func rank(attempts: [TrolleyAttempt], assisted: Bool) -> [Self] {
        Set(attempts.filter { $0.run.assisted == assisted }.map { $0.run.profileID }).map {
            Self(profileID: $0, attempts: attempts, assisted: assisted)
        }.sorted {
            if $0.stars != $1.stars { return $0.stars > $1.stars }
            if $0.threeStarLevels != $1.threeStarLevels { return $0.threeStarLevels > $1.threeStarLevels }
            if $0.clearedLevels != $1.clearedLevels { return $0.clearedLevels > $1.clearedLevels }
            return $0.profileID < $1.profileID
        }
    }
}

public struct TrolleyAwardDelta: Equatable, Sendable {
    public let award: TrolleyAchievement
    public let before: TrolleyAchievementProgress
    public let after: TrolleyAchievementProgress
    public let isNew: Bool
    public init(award: TrolleyAchievement, before: TrolleyAchievementProgress, after: TrolleyAchievementProgress, isNew: Bool) {
        self.award = award; self.before = before; self.after = after; self.isNew = isNew
    }
    public var gained: Int { max(0, after.value - before.value) }
    public var remaining: Int { max(0, after.goal - after.value) }
    public var status: String {
        if isNew { return "NEW AWARD" }
        if after.earned { return "Earned" }
        return "\(after.value)/\(after.goal)" + (gained > 0 ? " (+\(gained))" : "")
    }
    public var next: String {
        if after.earned { return award.detail }
        switch award {
        case .moralSurplus: return "Save \(remaining) more above requirements."
        case .greatDebate, .philosopherKing: return "Clear with \(remaining) more play styles."
        case .schoolOfThought: return "Use one play style on \(remaining) more levels."
        case .unbrokenArgument: return "Match targets on \(remaining) more consecutive levels."
        case .absoluteMaximum: return "Match verified maxima on \(remaining) more levels."
        default: return "Match rescue targets on \(remaining) more levels."
        }
    }
}

public struct TrolleyRankChange: Equatable, Sendable {
    public let board: TrolleyBoard
    public let before: Int?
    public let after: Int?
    public let players: Int
    public let improved: Bool
    public var label: String {
        guard let after else { return "Clear the level to rank" }
        if let before, after < before { return "#\(before) > #\(after) of \(players)" }
        return "#\(after) of \(players)" + (improved && before != nil ? " - new best" : "")
    }
}

/// One snapshot per result, shared by the screen, accessibility and ranking links.
public struct TrolleyCelebration: Sendable {
    public let goals: TrolleyRescueGoals
    public let previousStars: Int
    public let bestStars: Int
    public let careerBefore: TrolleyCareerScore
    public let career: TrolleyCareerScore
    public let careerRank: Int?
    public let careerPlayers: Int
    public let awards: [TrolleyAwardDelta]
    public let ranks: [TrolleyRankChange]
    public let nextGoal: String
    public let levelAwards: [ArcadeLevelAchievement]
    public let recordMessage: String
    public var addedStars: Int { max(0, career.stars - careerBefore.stars) }
    public var newAwards: [TrolleyAwardDelta] { awards.filter(\.isNew) }
    public var nextCareerGoal: TrolleyAwardDelta? {
        awards.filter { !$0.after.earned && $0.after.goal > 1 }.sorted {
            if ($0.gained > 0) != ($1.gained > 0) { return $0.gained > 0 }
            let left = Double($0.after.value) / Double($0.after.goal)
            let right = Double($1.after.value) / Double($1.after.goal)
            return left == right ? $0.award.rawValue < $1.award.rawValue : left > right
        }.first
    }
    public init(report: ArcadeReport, history: TrolleyHistory) {
        let run = report.run
        // A revisited result must not include attempts completed after it.
        let index = history.attempts.firstIndex { $0.id == run.id } ?? history.attempts.count
        let before = Array(history.attempts.prefix(index))
        let after = before + (report.trolley.map { [$0.attempt] } ?? [])
        func assessed(_ attempts: [TrolleyAttempt]) -> [TrolleyAttempt] {
            attempts.map { attempt in
                guard let c = attempt.run.level.conditions else { return attempt }
                return attempt.assessed(using: history.maximum(conditions: c, assisted: attempt.run.assisted))
            }
        }
        let current = assessed(after)
        let old = assessed(before)
        let maximum = run.level.conditions.map { history.maximum(conditions: $0, assisted: run.assisted) } ?? TrolleyMaximum()
        goals = TrolleyRescueGoals(run: run, maximum: maximum)
        let same = old.filter { $0.run.profileID == run.profileID && $0.run.assisted == run.assisted
            && $0.run.level.boardID == run.level.boardID }
        previousStars = same.map { $0.goals.stars }.max() ?? 0
        bestStars = max(previousStars, goals.stars)
        careerBefore = .init(profileID: run.profileID, attempts: old, assisted: run.assisted)
        career = .init(profileID: run.profileID, attempts: current, assisted: run.assisted)
        let careerBoard = TrolleyCareerScore.rank(attempts: current, assisted: run.assisted)
        careerRank = careerBoard.firstIndex { $0.profileID == run.profileID }.map { $0 + 1 }
        careerPlayers = careerBoard.count
        let new = Set(report.trolley?.attempt.achievements ?? [])
        awards = TrolleyAchievement.allCases.filter { award in award.isOffered || new.contains(award)
            || before.contains(where: { $0.run.profileID == run.profileID && $0.achievements.contains(award) }) }.map { award in
            TrolleyAwardDelta(award: award, before: award.progress(attempts: before, profileID: run.profileID),
                after: award.progress(attempts: after, profileID: run.profileID), isNew: new.contains(award))
        }
        if let c = run.level.conditions {
            ranks = [TrolleyBoard.mostSaved, .leastSkills, .cleanRescue].map { board in
                let a = TrolleyLeaderboards.rank(before, comparisonID: c.comparisonID(assisted: run.assisted), board: board, maximum: maximum)
                let b = TrolleyLeaderboards.rank(after, comparisonID: c.comparisonID(assisted: run.assisted), board: board, maximum: maximum)
                return .init(board: board, before: a.firstIndex { $0.run.profileID == run.profileID }.map { $0 + 1 },
                    after: b.firstIndex { $0.run.profileID == run.profileID }.map { $0 + 1 }, players: b.count,
                    improved: b.first { $0.run.profileID == run.profileID }?.id == run.id)
            }
        } else { ranks = [] }
        levelAwards = report.earned
        if report.newRescueBest, let previous = report.previousBest {
            recordMessage = "NEW BEST! \(previous.saved) > \(run.saved) rescued"
        } else if report.newSkillBest {
            recordMessage = "NEW SKILL RECORD! \(run.skillCount) skills"
        } else if report.previousBest == nil && run.qualifies {
            recordMessage = "FIRST CLEAR! Record set."
        } else {
            recordMessage = "Best: \(bestStars)/3 stars, \(max(run.saved, report.previousBest?.saved ?? 0)) rescued"
        }
        if !run.qualifies {
            nextGoal = run.saved < run.level.required
                ? "\(run.level.required - run.saved) more to rescue for the first star."
                : "Rescue count met. Complete the level to earn stars."
        } else if goals.stars == 3 {
            nextGoal = "ALL THREE STARS! This level's rescue goals are met."
        } else if goals.stars == 1 {
            nextGoal = "\(max(0, goals.extraSaved - run.saved)) more to rescue for two stars."
        } else if let full = goals.fullSaved {
            let gap = max(0, full - run.saved)
            nextGoal = "\(gap == 1 ? "SO CLOSE! " : "")\(gap) more to rescue for three stars."
        } else {
            nextGoal = "Third-star target unknown. Your clear still counts."
        }
    }
}
