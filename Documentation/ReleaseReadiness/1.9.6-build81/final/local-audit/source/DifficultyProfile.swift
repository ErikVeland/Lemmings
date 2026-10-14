import Foundation

public enum DifficultyGrade: Int, Codable, CaseIterable, Sendable {
    case beginner = 1, easy, moderate, tricky, challenging, hard, veryHard, expert, extreme, master
    public var name: String {
        ["Beginner", "Easy", "Moderate", "Tricky", "Challenging", "Hard", "Very Hard", "Expert", "Extreme", "Master"][rawValue - 1]
    }
    public init(score: Double) {
        self = Self(rawValue: min(10, max(1, Int((score.isFinite ? score : 0).clampedDifficulty / 100) + 1)))!
    }
}

extension Double {
    var clampedDifficulty: Double { isFinite ? min(1000, max(0, self)) : 0 }
}

public enum DifficultyConfidence: String, Codable, Sendable {
    case low, medium, high
    public var value: Double { switch self { case .low: 0.2; case .medium: 0.6; case .high: 0.9 } }
}

/// All components use 0...1000. Deduction is a proxy, never a measurement of human insight.
public struct DifficultyComponents: Codable, Equatable, Sendable {
    public var techniqueBurden: Double
    public var solutionComplexity: Double
    public var executionPrecision: Double
    public var concurrencyBurden: Double
    public var constraintPressure: Double
    public var deductionComplexityProxy: Double
    public init(techniqueBurden: Double = 0, solutionComplexity: Double = 0,
                executionPrecision: Double = 0, concurrencyBurden: Double = 0,
                constraintPressure: Double = 0, deductionComplexityProxy: Double = 0) {
        self.techniqueBurden = techniqueBurden.clampedDifficulty
        self.solutionComplexity = solutionComplexity.clampedDifficulty
        self.executionPrecision = executionPrecision.clampedDifficulty
        self.concurrencyBurden = concurrencyBurden.clampedDifficulty
        self.constraintPressure = constraintPressure.clampedDifficulty
        self.deductionComplexityProxy = deductionComplexityProxy.clampedDifficulty
    }
    public var values: [Double] { [techniqueBurden, solutionComplexity, executionPrecision,
                                  concurrencyBurden, constraintPressure, deductionComplexityProxy] }
}

/// Bump this version for scoring, detector, or probe-policy changes.
public enum DifficultyModel {
    public static let version = "difficulty-3"
    public static let simulationVersion = "neolemmix-ce-2026-09-27"
    // Technique and dependency evidence dominate. Deduction receives the least weight.
    public static let weights = [0.25, 0.22, 0.20, 0.13, 0.13, 0.07]
    public static let timingOffsets = [-1, 1, -2, 2, -4, 4, -8, 8, -16, 16]
    public static let maximumProbeRuns = 160
    public static let maximumFrames = 30_600
    public static let nearbyActionFrames = 34
    public static let regionDistance = 64
    public static func score(_ components: DifficultyComponents) -> Double {
        zip(components.values, weights).reduce(0) { $0 + $1.0 * $1.1 }.clampedDifficulty
    }
}

public struct DifficultyCacheKey: Codable, Hashable, Sendable {
    public let identity: LevelCatalogueIdentity
    public let levelRevision: String
    public let replayRevision: String
    public let analyserVersion: String
    public let simulationVersion: String
    /// Includes style/mask revisions and analysis configuration, not just level text.
    public let assetsRevision: String
    public init(identity: LevelCatalogueIdentity, levelRevision: String, replayRevision: String = "none",
                assetsRevision: String = "none", analyserVersion: String = DifficultyModel.version,
                simulationVersion: String = DifficultyModel.simulationVersion) {
        self.identity = identity; self.levelRevision = levelRevision; self.replayRevision = replayRevision
        self.assetsRevision = assetsRevision; self.analyserVersion = analyserVersion
        self.simulationVersion = simulationVersion
    }
}

public struct DifficultyProfile: Codable, Equatable, Sendable {
    public let key: DifficultyCacheKey
    public let overallScore: Double
    public var grade: DifficultyGrade { DifficultyGrade(score: overallScore) }
    public let confidence: DifficultyConfidence
    public let sourceRank: String?
    public let components: DifficultyComponents
    public let detectedTechniques: [String]
    public let prerequisiteConcepts: [String]
    public let criticalActions: [UInt64]
    public let precision: DifficultyPrecisionEvidence?
    public let explanation: [String]
    public var analyserVersion: String { key.analyserVersion }
    public init(key: DifficultyCacheKey, confidence: DifficultyConfidence, components: DifficultyComponents,
                detectedTechniques: [String] = [], prerequisiteConcepts: [String] = [],
                precision: DifficultyPrecisionEvidence? = nil, explanation: [String] = [], sourceRank: String? = nil) {
        self.key = key; self.confidence = confidence; self.components = components
        self.sourceRank = sourceRank
        overallScore = DifficultyModel.score(components)
        self.detectedTechniques = Array(Set(detectedTechniques)).sorted()
        self.prerequisiteConcepts = Array(Set(prerequisiteConcepts)).sorted()
        self.precision = precision
        criticalActions = precision?.actions.filter(\.isNarrow).map(\.sequence).sorted() ?? []
        self.explanation = explanation
    }
}

/// A disposable cache. Its schema never participates in saved-run decoding.
public actor DifficultyProfileCache {
    private let file: URL
    private var profiles: [DifficultyCacheKey: DifficultyProfile] = [:]
    public init(file: URL) {
        self.file = file
        if let data = try? Data(contentsOf: file),
           let values = try? JSONDecoder().decode([DifficultyProfile].self, from: data) {
            for value in values where value.key.analyserVersion == DifficultyModel.version
                && value.key.simulationVersion == DifficultyModel.simulationVersion {
                profiles[value.key] = value
            }
        }
    }
    public func profile(for key: DifficultyCacheKey) -> DifficultyProfile? { profiles[key] }
    public func store(_ profile: DifficultyProfile, flush: Bool = true) throws {
        profiles[profile.key] = profile
        if flush { try save() }
    }
    public func save() throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let values = profiles.values.sorted { $0.key.canonical < $1.key.canonical }
        try encoder.encode(values).write(to: file, options: .atomic)
    }
}

extension DifficultyCacheKey {
    var canonical: String {
        [identity.engine.rawValue, identity.packID, identity.levelID, levelRevision,
         replayRevision, assetsRevision, analyserVersion, simulationVersion].joined(separator: "\u{0}")
    }
}
