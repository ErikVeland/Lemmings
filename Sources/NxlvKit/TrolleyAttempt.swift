import Foundation
import CryptoKit

/// Versioned conditions for rescue comparisons. Presentation and audio settings are deliberately absent.
public struct TrolleyConditions: Codable, Equatable, Sendable {
    public let gameID: String
    public let packID: String
    public let levelID: String
    public let levelFingerprint: String
    public let rulesetVersion: String
    public let physicsMode: String
    public let population: Int
    public let rescueRequirement: Int
    /// -1 denotes an unlimited supply. Keys are stable engine skill identifiers.
    public let startingSkills: [String: Int]
    public let timeLimitSeconds: Double?
    public let modifiers: [String: String]
    public let rewindPolicy: String

    public init(gameID: String, packID: String, levelID: String, levelFingerprint: String,
                rulesetVersion: String, physicsMode: String, population: Int, rescueRequirement: Int,
                startingSkills: [String: Int], timeLimitSeconds: Double?, modifiers: [String: String] = [:],
                rewindPolicy: String = "separate-assisted-v1") {
        self.gameID = gameID; self.packID = packID; self.levelID = levelID
        self.levelFingerprint = levelFingerprint; self.rulesetVersion = rulesetVersion; self.physicsMode = physicsMode
        self.population = population; self.rescueRequirement = rescueRequirement; self.startingSkills = startingSkills
        self.timeLimitSeconds = timeLimitSeconds; self.modifiers = modifiers; self.rewindPolicy = rewindPolicy
    }
    public var fingerprint: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        // All fields are validated before a completed attempt can enter a board.
        return SHA256.hash(data: (try? encoder.encode(self)) ?? Data()).map { String(format: "%02x", $0) }.joined()
    }
    public func comparisonID(assisted: Bool) -> String { "trolley-v1:\(fingerprint):\(assisted ? "assisted" : "direct")" }
    public var maximumPopulation: Int? {
        guard let cloners = startingSkills["cloner"] else { return population }
        return cloners < 0 ? nil : population + cloners
    }
    public var isValid: Bool {
        !gameID.isEmpty && !packID.isEmpty && !levelID.isEmpty && !levelFingerprint.isEmpty && !rulesetVersion.isEmpty
        && population > 0 && population <= 1_000_000 && (0...population).contains(rescueRequirement)
        && startingSkills.values.allSatisfy { (-1...1_000_000).contains($0) }
        && (timeLimitSeconds.map { $0.isFinite && $0 >= 0 } ?? true)
    }
}

/// Optional causal evidence is supplied only by a verifier. Current engines do not infer it from bomber clicks.
public struct TrolleySacrificeEvidence: Codable, Equatable, Sendable {
    public let sacrificed: Int
    public let enabledRescues: Int
    public let source: String
    public init(sacrificed: Int, enabledRescues: Int, source: String) {
        self.sacrificed = sacrificed; self.enabledRescues = enabledRescues; self.source = source
    }
}

public struct TrolleyTelemetry: Codable, Equatable, Sendable {
    public let released: Int
    public let nukeCount: Int
    public let rewindCount: Int
    public let undoCount: Int
    public let destructiveSkillCount: Int
    public let buildVersion: String
    public let additionalStatistics: [String: Double]
    public let sacrificeEvidence: TrolleySacrificeEvidence?
    public let unconventionalEvidence: String?
    public init(released: Int, nukeCount: Int = 0, rewindCount: Int = 0, undoCount: Int = 0,
                destructiveSkillCount: Int = 0, buildVersion: String = "development",
                additionalStatistics: [String: Double] = [:], sacrificeEvidence: TrolleySacrificeEvidence? = nil,
                unconventionalEvidence: String? = nil) {
        self.released = released; self.nukeCount = nukeCount; self.rewindCount = rewindCount; self.undoCount = undoCount
        self.destructiveSkillCount = destructiveSkillCount; self.buildVersion = buildVersion
        self.additionalStatistics = additionalStatistics; self.sacrificeEvidence = sacrificeEvidence
        self.unconventionalEvidence = unconventionalEvidence
    }
    public var isValid: Bool {
        released >= 0 && nukeCount >= 0 && rewindCount >= 0 && undoCount >= 0 && destructiveSkillCount >= 0
        && additionalStatistics.values.allSatisfy(\.isFinite)
        && (sacrificeEvidence.map { $0.sacrificed > 0 && $0.enabledRescues > $0.sacrificed && !$0.source.isEmpty } ?? true)
    }
}

public enum TrolleyStartKind: String, Codable, Sendable { case fresh, retryAfterSuccess, retryAfterFailure, restartDuringPlay }
public struct TrolleyStart: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let profileID: String
    public let conditions: TrolleyConditions
    public let date: Date
    public let parentAttemptID: UUID?
    public let kind: TrolleyStartKind
    public init(id: UUID, profileID: String, conditions: TrolleyConditions, date: Date = Date(),
                parentAttemptID: UUID? = nil, kind: TrolleyStartKind = .fresh) {
        self.id = id; self.profileID = profileID; self.conditions = conditions; self.date = date
        self.parentAttemptID = parentAttemptID; self.kind = kind
    }
}

public struct TrolleyMetrics: Codable, Equatable, Sendable {
    public let lost: Int
    public let unreleased: Int
    public let moralSurplus: Int
    public let requirementSurplus: Int
    public let unavoidableLosses: Int?
    public let avoidableLosses: Int?
    public let rescuePotential: Double?
    public let rescuedPerSkill: Double?
    public let scarceResourceFractionUsed: Double?
    public init(run: ArcadeRun, telemetry: TrolleyTelemetry, maximum: TrolleyMaximum) {
        lost = telemetry.released - run.saved
        unreleased = run.population - telemetry.released
        requirementSurplus = run.saved - run.level.required
        moralSurplus = max(0, requirementSurplus)
        let verified = maximum.status == .verified ? maximum.value : nil
        // A level-wide proof cannot establish unavoidable deaths in a partially released cohort.
        unavoidableLosses = unreleased == 0 ? verified.flatMap { telemetry.released >= $0 ? telemetry.released - $0 : nil } : nil
        avoidableLosses = verified.map { max(0, $0 - run.saved) }
        rescuePotential = maximum.value.flatMap { $0 > 0 ? Double(run.saved) / Double($0) : nil }
        rescuedPerSkill = run.skillCount > 0 ? Double(run.saved) / Double(run.skillCount) : nil
        if let supplies = run.level.conditions?.startingSkills, !supplies.isEmpty {
            let finite = supplies.filter { $0.value >= 0 }
            let available = finite.values.reduce(0, +)
            let used = finite.keys.reduce(0) { $0 + (run.skills[$1] ?? 0) }
            scarceResourceFractionUsed = available > 0 ? min(1, Double(used) / Double(available)) : nil
        } else { scarceResourceFractionUsed = nil }
    }
}

/// A completed attempt is append-only. New evidence does not rewrite its historical interpretation.
public struct TrolleyAttempt: Codable, Equatable, Sendable, Identifiable {
    public let schemaVersion: Int
    public let run: ArcadeRun
    public let start: TrolleyStart?
    public let maximum: TrolleyMaximum
    public let metrics: TrolleyMetrics
    public let philosophy: TrolleyPhilosophy
    public let achievements: [TrolleyAchievement]
    /// Absent in older history. Its original run and evidence still define the same goals.
    public let rescueGoals: TrolleyRescueGoals?
    /// Evidence before this run raised or disproved the target. Absent in older attempts.
    public let surpassedTarget: TrolleyMaximum?
    public var goals: TrolleyRescueGoals { rescueGoals ?? TrolleyRescueGoals(run: run, maximum: maximum) }
    public var rescueShortfall: Int? { maximum.isRescueTarget ? maximum.value.map { max(0, $0 - run.saved) } : nil }
    public var targetSacrifices: Int? { maximum.isRescueTarget ? maximum.value.map { max(0, run.level.total - $0) } : nil }
    /// Reassess a display or leaderboard entry without rewriting the saved attempt.
    public func assessed(using current: TrolleyMaximum) -> Self {
        guard current.isRescueTarget, let value = current.value, value >= run.saved else { return self }
        let metrics = TrolleyMetrics(run: run, telemetry: run.telemetry!, maximum: current)
        return Self(run: run, start: start, maximum: current, metrics: metrics,
                    philosophy: TrolleyAnalyser.analyse(run: run, metrics: metrics, maximum: current)
                        .recognizingBreakthrough(saved: run.saved, previous: surpassedTarget),
                    achievements: achievements, surpassedTarget: surpassedTarget)
    }
    public var id: UUID { run.id }
    public var comparisonID: String { run.level.conditions?.comparisonID(assisted: run.assisted) ?? "invalid:" + id.uuidString }
    public init(run: ArcadeRun, start: TrolleyStart?, maximum: TrolleyMaximum,
                metrics: TrolleyMetrics, philosophy: TrolleyPhilosophy, achievements: [TrolleyAchievement],
                surpassedTarget: TrolleyMaximum? = nil) {
        schemaVersion = 1; self.run = run; self.start = start; self.maximum = maximum
        self.metrics = metrics; self.philosophy = philosophy; self.achievements = achievements
        self.surpassedTarget = surpassedTarget
        rescueGoals = TrolleyRescueGoals(run: run, maximum: maximum)
    }
}
