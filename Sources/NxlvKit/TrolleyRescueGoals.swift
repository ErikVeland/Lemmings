import Foundation

/// Optional rescue awards. Only the original engine outcome permits progression.
public struct TrolleyRescueGoals: Codable, Equatable, Sendable {
    public enum FullRescueBasis: String, Codable, Sendable {
        case unknown, verifiedMaximum, everyoneHome, bestKnownRecord
    }
    public let modelVersion: Int
    public let requiredSaved: Int
    public let extraSaved: Int
    public let fullSaved: Int?
    public let fullRescueBasis: FullRescueBasis
    public let stars: Int

    public init(run: ArcadeRun, maximum: TrolleyMaximum) {
        modelVersion = 1
        requiredSaved = run.level.required
        let ceiling = run.level.conditions.map { $0.maximumPopulation } ?? run.level.total
        let verified = maximum.isRescueTarget ? maximum.value : nil
        // A full finite cohort is observable without promoting its maximum metadata.
        let everyoneHome = ceiling.map { run.saved >= $0 } ?? false
        fullSaved = verified ?? (everyoneHome ? ceiling : nil)
        fullRescueBasis = verified != nil ? (maximum.status == .record ? .bestKnownRecord : .verifiedMaximum) : everyoneHome ? .everyoneHome : .unknown
        extraSaved = min(requiredSaved + 1, max(requiredSaved, verified ?? ceiling ?? (requiredSaved + 1)))
        let full = fullSaved.map { run.saved >= $0 } ?? false
        stars = !run.qualifies ? 0 : full ? 3 : run.saved >= extraSaved ? 2 : 1
    }
}
