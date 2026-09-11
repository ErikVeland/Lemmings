import Foundation

public enum TrolleyBoard: String, Codable, CaseIterable, Sendable {
    case mostSaved, rescuePotential, zeroAvoidableLosses, leastSkills, mostUsedSkill, moralSurplus, cleanRescue
    public var title: String {
        switch self {
        case .mostSaved: "Most saved"
        case .rescuePotential: "Rescue potential"
        case .zeroAvoidableLosses: "Zero avoidable losses"
        case .leastSkills: "Least skills"
        case .mostUsedSkill: "Most used skill"
        case .moralSurplus: "Moral surplus"
        case .cleanRescue: "Clean rescue"
        }
    }
    public var ordering: String {
        switch self {
        case .mostSaved: "Most rescued, then fewest skills and fastest time."
        case .rescuePotential: "Verified potential, then most saved, fewest skills and fastest time."
        case .zeroAvoidableLosses: "Verified perfect rescues, then most saved, fewest skills and fastest time."
        case .leastSkills: "Successful clears, fewest skills, then most saved and fastest time."
        case .mostUsedSkill: "Highest count of one skill, then most saved, fewest skills and fastest time."
        case .moralSurplus: "Largest surplus, then most saved, fewest skills and fastest time."
        case .cleanRescue: "Verified rescues: most saved, fewest avoidable losses, fewest skills and fastest time."
        }
    }
}

public enum TrolleyLeaderboards {
    public static func eligible(_ attempt: TrolleyAttempt, board: TrolleyBoard, maximum: TrolleyMaximum) -> Bool {
        switch board {
        case .leastSkills: return attempt.run.didWin
        case .rescuePotential, .zeroAvoidableLosses, .cleanRescue:
            guard maximum.isRescueTarget, maximum.value == attempt.maximum.value,
                  attempt.maximum.isRescueTarget, attempt.metrics.rescuePotential != nil else { return false }
            return board != .zeroAvoidableLosses || attempt.rescueShortfall == 0
        default: return true
        }
    }
    public static func precedes(_ a: TrolleyAttempt, _ b: TrolleyAttempt, board: TrolleyBoard) -> Bool {
        switch board {
        case .leastSkills:
            if a.run.skillCount != b.run.skillCount { return a.run.skillCount < b.run.skillCount }
        case .rescuePotential:
            if a.metrics.rescuePotential != b.metrics.rescuePotential { return (a.metrics.rescuePotential ?? -1) > (b.metrics.rescuePotential ?? -1) }
        case .mostUsedSkill:
            let ac = a.run.skills.values.max() ?? 0, bc = b.run.skills.values.max() ?? 0
            if ac != bc { return ac > bc }
        case .moralSurplus:
            if a.metrics.moralSurplus != b.metrics.moralSurplus { return a.metrics.moralSurplus > b.metrics.moralSurplus }
        default: break
        }
        if a.run.saved != b.run.saved { return a.run.saved > b.run.saved }
        if let al = a.metrics.avoidableLosses, let bl = b.metrics.avoidableLosses, al != bl { return al < bl }
        if a.run.skillCount != b.run.skillCount { return a.run.skillCount < b.run.skillCount }
        if a.run.seconds != b.run.seconds { return a.run.seconds < b.run.seconds }
        if a.run.date != b.run.date { return a.run.date < b.run.date }
        return a.id.uuidString < b.id.uuidString
    }
    public static func rank(_ attempts: [TrolleyAttempt], comparisonID: String, board: TrolleyBoard,
                            maximum: TrolleyMaximum) -> [TrolleyAttempt] {
        let candidates = attempts.filter { $0.comparisonID == comparisonID }.map { $0.assessed(using: maximum) }
            .filter { eligible($0, board: board, maximum: maximum) }
        return Dictionary(grouping: candidates, by: { $0.run.profileID }).values.compactMap {
            $0.sorted { precedes($0, $1, board: board) }.first
        }.sorted { precedes($0, $1, board: board) }
    }
}

public struct TrolleyPersonalRecords: Codable, Equatable, Sendable {
    public let bestSaved: Int?
    public let bestRescuePotential: Double?
    public let lowestAvoidableLosses: Int?
    public let bestMoralSurplus: Int?
    public let leastSkillsSuccessful: Int?
    public let fastestSuccessful: Double?
    public let verifiedPerfectCount: Int
    public let philosopherDistribution: [String: Int]
    public let mostCommonAffinity: String?
    public let rarestAffinity: String?
    public let totalSaved: Int
    public let totalAvoidableLosses: Int
    public let attemptsWithKnownAvoidableLosses: Int
    public let totalMoralSurplus: Int
    public let attempts: Int
    public let retriesAfterSuccessfulClears: Int
    public let skillUsage: [String: Int]
    public let achievements: Set<TrolleyAchievement>

    public init(attempts all: [TrolleyAttempt], starts: [TrolleyStart], profileID: String, comparisonID: String? = nil) {
        let attempts = all.filter { $0.run.profileID == profileID && (comparisonID == nil || $0.comparisonID == comparisonID) }
        bestSaved = attempts.map { $0.run.saved }.max()
        bestRescuePotential = attempts.filter { $0.maximum.isRescueTarget }.compactMap { $0.metrics.rescuePotential }.max()
        lowestAvoidableLosses = attempts.compactMap { $0.metrics.avoidableLosses }.min()
        bestMoralSurplus = attempts.map { $0.metrics.moralSurplus }.max()
        let clears = attempts.filter { $0.run.didWin }
        leastSkillsSuccessful = clears.map { $0.run.skillCount }.min(); fastestSuccessful = clears.map { $0.run.seconds }.min()
        verifiedPerfectCount = attempts.filter { $0.maximum.status == .verified && $0.metrics.avoidableLosses == 0 }.count
        let counts = Dictionary(grouping: attempts, by: { $0.philosophy.primaryID }).mapValues(\.count)
        philosopherDistribution = counts
        mostCommonAffinity = counts.keys.sorted { counts[$0] == counts[$1] ? $0 < $1 : counts[$0]! > counts[$1]! }.first
        rarestAffinity = counts.keys.sorted { counts[$0] == counts[$1] ? $0 < $1 : counts[$0]! < counts[$1]! }.first
        totalSaved = attempts.reduce(0) { $0 + $1.run.saved }
        totalAvoidableLosses = attempts.reduce(0) { $0 + ($1.metrics.avoidableLosses ?? 0) }
        attemptsWithKnownAvoidableLosses = attempts.filter { $0.metrics.avoidableLosses != nil }.count
        totalMoralSurplus = attempts.reduce(0) { $0 + $1.metrics.moralSurplus }; self.attempts = attempts.count
        retriesAfterSuccessfulClears = starts.filter { $0.profileID == profileID && $0.kind == .retryAfterSuccess
            && (comparisonID == nil || $0.conditions.comparisonID(assisted: false) == comparisonID
                || $0.conditions.comparisonID(assisted: true) == comparisonID) }.count
        skillUsage = attempts.reduce(into: [:]) { result, attempt in
            for (skill, count) in attempt.run.skills { result[skill, default: 0] += count }
        }
        achievements = Set(attempts.flatMap(\.achievements))
    }
}

public struct TrolleyRetryTarget: Codable, Equatable, Sendable {
    public let label: String
    public let detail: String
    public let targetSaved: Int?
    public static func suggest(_ attempt: TrolleyAttempt, previousBest: Int?, localBest: Int?) -> Self {
        let saved = attempt.run.saved, maximum = attempt.maximum
        let ceiling = attempt.run.level.conditions?.maximumPopulation
        if maximum.isRescueTarget, let value = maximum.value, saved < value {
            if saved == value - 1 { return .init(label: "Save one more", detail: "One Lemming left behind. Bring home \(value).", targetSaved: value) }
            return .init(label: "Reach 100%", detail: "Save \(value - saved) more to reach the \(maximum.status == .record ? "best-known rescue" : "verified maximum") of \(value).", targetSaved: value)
        }
        if let previousBest, saved < previousBest {
            return .init(label: "Match your best", detail: "Bring \(previousBest - saved) more home to match your best.", targetSaved: previousBest)
        }
        if let localBest, saved < localBest {
            let target = min(ceiling ?? (localBest + 1), localBest + 1)
            return .init(label: target > localBest ? "Beat local best" : "Match local best", detail: "Local best: \(localBest). Aim for \(target).", targetSaved: target)
        }
        if !maximum.isRescueTarget, ceiling == nil || saved < ceiling! {
            return .init(label: "Save one more", detail: "Best known is \(maximum.value ?? saved). Can you improve it?", targetSaved: saved + 1)
        }
        return .init(label: "Find a better way", detail: attempt.run.skillCount > 0
            ? "Match this rescue with fewer than \(attempt.run.skillCount) skills." : "Match this rescue in less time.", targetSaved: saved)
    }
}

public struct TrolleyReport: Sendable {
    public let attempt: TrolleyAttempt
    public let previousPersonalBest: Int?
    public let previousLocalBest: Int?
    public let personal: TrolleyPersonalRecords
    public let localBest: Int
    public let localRank: Int
    public let retry: TrolleyRetryTarget
}
