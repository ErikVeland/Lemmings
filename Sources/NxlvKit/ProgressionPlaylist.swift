import Foundation

public enum ProgressionPolicy: String, Codable, CaseIterable, Sendable {
    case smooth, originalPlus, lowPrecision, executionChallenge, techniqueCurriculum
    public var name: String {
        switch self {
        case .smooth: "Smooth Progression"
        case .originalPlus: "Original+ Progression"
        case .lowPrecision: "Low Precision"
        case .executionChallenge: "Execution Challenge"
        case .techniqueCurriculum: "Technique Curriculum"
        }
    }
}

public struct ProgressionCandidate: Sendable {
    public let entry: LevelPlaylistEntry
    public let profile: DifficultyProfile
    /// Supplied by the authoritative content adapter; never inferred from filenames.
    public let isOfficial: Bool
    public let campaignOrder: Int
    /// True when the winning witness must save every released lemming.
    public let requiresFullRescue: Bool
    /// True when the source does not identify a recognised campaign rank.
    public let rankIsUnverified: Bool
    /// Starting release rate from the source level, when known.
    public let startingReleaseRate: Int?
    /// Required rescue fraction from source population and quota, when known.
    public let rescueRequirementRatio: Double?
    /// Number of skill assignments in the validated winning route, when known.
    public let skillAssignmentCount: Int?
    public init(entry: LevelPlaylistEntry, profile: DifficultyProfile, isOfficial: Bool,
                campaignOrder: Int = 0, requiresFullRescue: Bool = false,
                rankIsUnverified: Bool = false, startingReleaseRate: Int? = nil,
                rescueRequirementRatio: Double? = nil, skillAssignmentCount: Int? = nil) {
        self.entry = entry; self.profile = profile; self.isOfficial = isOfficial
        self.campaignOrder = campaignOrder; self.requiresFullRescue = requiresFullRescue
        self.rankIsUnverified = rankIsUnverified
        self.startingReleaseRate = startingReleaseRate
        self.rescueRequirementRatio = rescueRequirementRatio
        self.skillAssignmentCount = skillAssignmentCount
    }
    var stableKey: String { [entry.identity.engine.rawValue, entry.identity.packID, entry.identity.levelID].joined(separator: "\u{0}") }
}

public enum ProgressionModel { public static let version = "progression-3" }

public struct ProgressionConfiguration: Codable, Equatable, Sendable {
    public var maximumLevels = 100
    public var targetStep = 35.0
    public var materialCostDifference = 20.0
    public var officialBonus = 5.0
    public var maximumRegression = 100.0
    public var significantAnchorJump = 100.0
    public var technique: String?
    public init() {}
}

public struct ProgressionSelection: Codable, Equatable, Sendable {
    public let identity: LevelCatalogueIdentity
    public let score: Double
    public let transitionCost: Double
    public let introducedConcepts: [String]
    public let reason: String
}

public struct ProgressionResult: Sendable {
    public let policy: ProgressionPolicy
    public let entries: [LevelPlaylistEntry]
    public let diagnostics: [ProgressionSelection]
    public let warnings: [String]
    public func playlist(id: UUID = UUID(), createdAt: Date = Date()) throws -> LevelPlaylist {
        try LevelPlaylist(id: id, name: policy.name, entries: entries, createdAt: createdAt)
    }
}

public enum ProgressionGenerator {
    /// Greedy traversal of an implicit directed graph. Scores use the entire learned concept set.
    /// The bounded near-best set prevents official preference from buying a substantial jump.
    public static func generate(candidates: [ProgressionCandidate], policy: ProgressionPolicy,
                                configuration: ProgressionConfiguration = .init(),
                                statistics: DifficultyCorpusStatistics? = nil) throws -> ProgressionResult {
        guard Set(candidates.map { $0.entry.identity }).count == candidates.count else { throw LevelPlaylistError.duplicateEntry }
        guard candidates.allSatisfy({ $0.entry.identity == $0.profile.key.identity
            && $0.entry.sourceRevision == $0.profile.key.levelRevision
            && $0.profile.analyserVersion == DifficultyModel.version }) else { throw LevelPlaylistError.invalidEntry }
        guard configuration.maximumLevels > 0, configuration.targetStep.isFinite, configuration.targetStep > 0,
              configuration.maximumRegression.isFinite, configuration.maximumRegression >= 0,
              configuration.significantAnchorJump.isFinite, configuration.significantAnchorJump > 0,
              configuration.materialCostDifference.isFinite, configuration.officialBonus.isFinite else {
            throw LevelPlaylistError.invalidPool
        }
        var remaining = candidates.sorted { $0.stableKey < $1.stableKey }
        if policy == .techniqueCurriculum {
            guard let technique = configuration.technique, !technique.isEmpty else { throw LevelPlaylistError.invalidPool }
            remaining = remaining.filter { $0.profile.detectedTechniques.contains(technique)
                || $0.profile.prerequisiteConcepts.contains(technique) }
        }
        guard !remaining.isEmpty else { throw LevelPlaylistError.emptyPool }
        var chosen: [ProgressionCandidate] = []
        var diagnostics: [ProgressionSelection] = []
        var learned: Set<String> = []
        var exposures: [String: Int] = [:]
        let officialOrder = remaining.filter(\.isOfficial).sorted {
            $0.campaignOrder == $1.campaignOrder ? $0.stableKey < $1.stableKey : $0.campaignOrder < $1.campaignOrder
        }.map(\.stableKey)
        var warnings: [String] = []
        while !remaining.isEmpty && chosen.count < min(LevelPlaylist.maximumEntries, max(0, configuration.maximumLevels)) {
            try Task.checkCancellation()
            let previous = chosen.last
            let nextOfficial = officialOrder.first { key in remaining.contains { $0.stableKey == key } }
            let anchor = remaining.first { $0.stableKey == nextOfficial }
            if policy == .originalPlus && !officialOrder.isEmpty && anchor == nil { break }
            var eligible = remaining.filter { candidate in
                if policy == .originalPlus, let anchor {
                    if candidate.isOfficial { return candidate.stableKey == nextOfficial }
                    guard let previous, candidate.profile.overallScore <= anchor.profile.overallScore else { return false }
                    let newAnchorConcepts = Set(anchor.profile.detectedTechniques).subtracting(learned)
                    let advancedIntroduction = DifficultyTechniques.definitions.contains {
                        newAnchorConcepts.contains($0.id) && $0.sophistication > 1
                    }
                    guard anchor.profile.overallScore - previous.profile.overallScore > configuration.significantAnchorJump
                        || newAnchorConcepts.count > 1 || advancedIntroduction else { return false }
                    let bridgesScore = candidate.profile.overallScore > previous.profile.overallScore + configuration.targetStep / 4
                        && candidate.profile.overallScore < anchor.profile.overallScore
                    let teachesTarget = !Set(candidate.profile.detectedTechniques).subtracting(learned)
                        .intersection(anchor.profile.detectedTechniques + anchor.profile.prerequisiteConcepts).isEmpty
                    if !bridgesScore && !teachesTarget { return false }
                }
                if let previous, policy != .originalPlus,
                   candidate.profile.overallScore < previous.profile.overallScore - configuration.maximumRegression { return false }
                return true
            }
            if policy != .originalPlus || officialOrder.isEmpty, let previous {
                let advancing = eligible.filter { candidate in
                    let reinforces = candidate.profile.detectedTechniques.contains { exposures[$0, default: 0] < 2 }
                    return candidate.profile.overallScore >= previous.profile.overallScore + max(1, configuration.targetStep / 4)
                        || reinforces
                }
                // Do not spend a finite curriculum on hundreds of mechanically identical priors.
                if !advancing.isEmpty { eligible = advancing }
                else { break }
            }
            guard !eligible.isEmpty else { break }
            var ranked: [(ProgressionCandidate, Double)] = []
            for candidate in eligible {
                let cost = transition(from: previous, to: candidate, learned: learned,
                                      policy: policy, configuration: configuration, statistics: statistics)
                ranked.append((candidate, cost))
            }
            ranked.sort { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.stableKey < rhs.0.stableKey
            }
            let bestCost = ranked[0].1
            let near = ranked.filter { $0.1 <= bestCost + min(10, max(0, configuration.materialCostDifference)) }
            let selected = near.sorted { lhs, rhs in
                let lc = lhs.0.profile.confidence.value, rc = rhs.0.profile.confidence.value
                if lc != rc { return lc > rc }
                let lCost = lhs.1 - (lhs.0.isOfficial ? min(5, max(0, configuration.officialBonus)) : 0)
                let rCost = rhs.1 - (rhs.0.isOfficial ? min(5, max(0, configuration.officialBonus)) : 0)
                if lCost != rCost { return lCost < rCost }
                if lhs.0.isOfficial != rhs.0.isOfficial { return lhs.0.isOfficial }
                return lhs.0.stableKey < rhs.0.stableKey
            }[0]
            let candidate = selected.0
            let introduced = Set(candidate.profile.detectedTechniques).subtracting(learned).sorted()
            let reason = candidate.isOfficial ? "Official level retained."
                : policy == .originalPlus && nextOfficial != nil ? "Community bridge before the next official level." : "Community level fills the next curriculum step."
            diagnostics.append(.init(identity: candidate.entry.identity, score: candidate.profile.overallScore,
                                     transitionCost: selected.1, introducedConcepts: introduced, reason: reason))
            if selected.1 > 250 { warnings.append("Large remaining transition to \(candidate.entry.levelNameSnapshot): \(Int(selected.1)).") }
            chosen.append(candidate); learned.formUnion(candidate.profile.detectedTechniques)
            for concept in candidate.profile.detectedTechniques { exposures[concept, default: 0] += 1 }
            remaining.removeAll { $0.entry.identity == candidate.entry.identity }
        }
        return ProgressionResult(policy: policy, entries: chosen.map(\.entry), diagnostics: diagnostics, warnings: warnings)
    }

    public static func transition(from previous: ProgressionCandidate?, to next: ProgressionCandidate,
                                  learned: Set<String>, policy: ProgressionPolicy,
                                  configuration: ProgressionConfiguration, statistics: DifficultyCorpusStatistics? = nil) -> Double {
        let profile = next.profile
        let priorScore = previous?.profile.overallScore ?? 0
        let increase = profile.overallScore - priorScore
        let introduced = Set(profile.detectedTechniques).subtracting(learned)
        let advanced = DifficultyTechniques.definitions.filter { introduced.contains($0.id) && $0.sophistication > 1 }.count
        let prerequisites = Set(profile.prerequisiteConcepts + (statistics?.prerequisites.filter {
            profile.detectedTechniques.contains($0.concept)
        }.map(\.prerequisite) ?? [])).subtracting(learned).subtracting(profile.detectedTechniques)
        let componentJumps = zip(profile.components.values, previous?.profile.components.values ?? Array(repeating: 0, count: 6))
            .reduce(0.0) { $0 + pow(max(0, $1.0 - $1.1 - ProgressionWeights.componentSlack) / ProgressionWeights.componentScale, 2) * ProgressionWeights.componentJump }
        var cost = abs(increase - configuration.targetStep) * ProgressionWeights.stepDistance
            + pow(max(0, increase - configuration.targetStep) / ProgressionWeights.jumpScale, 2) * ProgressionWeights.jumpPenalty
            + Double(introduced.count * introduced.count) * ProgressionWeights.newConcept + Double(advanced * advanced) * ProgressionWeights.newAdvancedConcept
            + Double(prerequisites.count) * ProgressionWeights.missingPrerequisite + componentJumps
        if let previous {
            if previous.profile.detectedTechniques == profile.detectedTechniques { cost += ProgressionWeights.repetition }
            if previous.entry.identity.packID == next.entry.identity.packID { cost += ProgressionWeights.samePack }
        }
        if policy == .lowPrecision {
            cost += profile.components.executionPrecision * ProgressionWeights.lowPrecision + profile.components.concurrencyBurden * ProgressionWeights.lowConcurrency
            if profile.precision == nil { cost += ProgressionWeights.unknownPrecision }
        }
        if policy == .executionChallenge { cost -= min(ProgressionWeights.maximumExecutionBonus, profile.components.executionPrecision * ProgressionWeights.executionBonus) }
        cost += (1 - profile.confidence.value) * ProgressionWeights.uncertainty
        cost += (1 - (previous?.profile.confidence.value ?? 1)) * ProgressionWeights.previousUncertainty
        return cost
    }
}
