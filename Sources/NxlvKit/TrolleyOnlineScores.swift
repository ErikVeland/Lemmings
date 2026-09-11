import Foundation

/// Apple board IDs and exact ranked conditions are supplied by the release catalogue.
public struct TrolleyOnlineConfiguration: Codable, Sendable {
    public struct Level: Codable, Sendable {
        public let conditions: TrolleyConditions
        public let maximum: TrolleyMaximum
        public let leaderboardID: String?
        public init(conditions: TrolleyConditions, maximum: TrolleyMaximum, leaderboardID: String?) {
            self.conditions = conditions; self.maximum = maximum; self.leaderboardID = leaderboardID
        }
    }
    public let enabled: Bool
    public let starsID: String
    public let clearsID: String
    public let perfectID: String
    public let levels: [Level]
    public init(enabled: Bool, starsID: String, clearsID: String, perfectID: String, levels: [Level]) {
        self.enabled = enabled; self.starsID = starsID; self.clearsID = clearsID; self.perfectID = perfectID; self.levels = levels
    }
    public func scores(attempts: [TrolleyAttempt], profileID: String) -> [String: Int] {
        guard isValid else { return [:] }
        let catalogue = Dictionary(levels.map { ($0.conditions.fingerprint, $0) }, uniquingKeysWith: { first, _ in first })
        var best: [String: Int] = [:], scores: [String: Int] = [:]
        for attempt in attempts where attempt.run.profileID == profileID && !attempt.run.assisted && attempt.run.qualifies {
            guard let c = attempt.run.level.conditions, let level = catalogue[c.fingerprint],
                  TrolleyHistory.isLegitimate(attempt.run) else { continue }
            let stars = TrolleyRescueGoals(run: attempt.run, maximum: level.maximum).stars
            let key = TrolleyCareerScore.levelKey(attempt.run)
            best[key] = max(best[key] ?? 0, stars)
            if let id = level.leaderboardID { scores[id] = max(scores[id] ?? 0, attempt.run.saved) }
        }
        if !best.isEmpty {
            scores[starsID] = best.values.reduce(0, +)
            scores[clearsID] = best.values.filter { $0 > 0 }.count
            scores[perfectID] = best.values.filter { $0 == 3 }.count
        }
        return scores
    }
    public var isValid: Bool {
        let ids = [starsID, clearsID, perfectID] + levels.compactMap(\.leaderboardID)
        return !levels.isEmpty && Set(ids).count == ids.count && ids.allSatisfy { !$0.isEmpty && $0.count <= 100 }
            && Set(levels.map { $0.conditions.fingerprint }).count == levels.count
            && levels.allSatisfy { $0.conditions.isValid && $0.maximum.isRescueTarget
                && $0.maximum.isValid(population: $0.conditions.maximumPopulation ?? 1_000_000) }
    }
}
