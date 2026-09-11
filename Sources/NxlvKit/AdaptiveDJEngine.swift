import Foundation

/// State machine and telemetry evaluator for the Adaptive DJ Soundtrack Engine.
///
/// Evaluates live game telemetry (active lemmings, release rate, danger count,
/// remaining time, nuke state, victory quota) to drive smooth transitions,
/// beat drops, and crossfades across all Lemmings soundtracks.
public struct AdaptiveDJEngine: Sendable {
    public enum DJEnergyLevel: String, CaseIterable, Codable, Sendable {
        case chill
        case building
        case climax
        case nukeDrop
        case victory
    }

    public struct Telemetry: Sendable, Equatable {
        public var releasedCount: Int
        public var totalCount: Int
        public var savedCount: Int
        public var requiredCount: Int
        public var releaseRate: Int
        public var dangerCount: Int
        public var remainingSeconds: Int?
        public var isNuking: Bool
        public var didWin: Bool

        public init(
            releasedCount: Int = 0,
            totalCount: Int = 100,
            savedCount: Int = 0,
            requiredCount: Int = 50,
            releaseRate: Int = 50,
            dangerCount: Int = 0,
            remainingSeconds: Int? = 300,
            isNuking: Bool = false,
            didWin: Bool = false
        ) {
            self.releasedCount = releasedCount
            self.totalCount = totalCount
            self.savedCount = savedCount
            self.requiredCount = requiredCount
            self.releaseRate = releaseRate
            self.dangerCount = dangerCount
            self.remainingSeconds = remainingSeconds
            self.isNuking = isNuking
            self.didWin = didWin
        }
    }

    public private(set) var currentEnergy: DJEnergyLevel = .chill

    public init() {}

    /// Evaluates current telemetry and returns the target DJ energy state.
    public mutating func evaluate(telemetry: Telemetry) -> DJEnergyLevel {
        if telemetry.requiredCount > 0 && telemetry.savedCount >= telemetry.requiredCount {
            currentEnergy = .victory
            return .victory
        }

        if telemetry.isNuking {
            currentEnergy = .nukeDrop
            return .nukeDrop
        }

        let dangerRatio = telemetry.releasedCount > 0 ? Double(telemetry.dangerCount) / Double(telemetry.releasedCount) : 0.0
        let timeWarning = (telemetry.remainingSeconds ?? 999) < 60

        if dangerRatio > 0.3 || timeWarning || telemetry.releaseRate > 80 {
            currentEnergy = .climax
        } else if telemetry.releaseRate > 40 || telemetry.savedCount > telemetry.requiredCount / 2 {
            currentEnergy = .building
        } else {
            currentEnergy = .chill
        }

        return currentEnergy
    }
}
