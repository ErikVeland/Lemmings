import Foundation

public struct DifficultyPrerequisite: Codable, Equatable, Sendable {
    public let concept: String
    public let prerequisite: String
    public let support: Int
    public let conditionalFrequency: Double
}

/// Correlations are curriculum hints, not logical prerequisites or proof of necessity.
public struct DifficultyCorpusStatistics: Codable, Equatable, Sendable {
    public let analyserVersion: String
    public let corpusKeys: [DifficultyCacheKey]
    public let frequencies: [String: Int]
    public let cooccurrences: [String: [String: Int]]
    public let occurrencesByPack: [String: [String: Int]]
    public let occurrencesByRank: [String: [String: Int]]
    public let prerequisites: [DifficultyPrerequisite]
    public init(profiles: [DifficultyProfile]) {
        analyserVersion = DifficultyModel.version
        let ordered = profiles.sorted { $0.key.canonical < $1.key.canonical }
        corpusKeys = ordered.map(\.key)
        var frequencies: [String: Int] = [:]
        var pairs: [String: [String: Int]] = [:]
        var packs: [String: [String: Int]] = [:]
        var ranks: [String: [String: Int]] = [:]
        for profile in ordered where profile.confidence != .low {
            for concept in profile.detectedTechniques {
                frequencies[concept, default: 0] += 1
                packs[profile.key.identity.packID, default: [:]][concept, default: 0] += 1
                if let rank = profile.sourceRank {
                    ranks[profile.key.identity.packID + "/" + rank, default: [:]][concept, default: 0] += 1
                }
                for other in profile.detectedTechniques where other != concept {
                    pairs[concept, default: [:]][other, default: 0] += 1
                }
            }
        }
        var edges: [DifficultyPrerequisite] = []
        // Strict frequency growth makes the inferred graph acyclic.
        for concept in frequencies.keys.sorted() {
            for prerequisite in frequencies.keys.sorted() where prerequisite != concept {
                let support = pairs[concept]?[prerequisite] ?? 0
                let total = frequencies[concept] ?? 0
                let base = frequencies[prerequisite] ?? 0
                guard support >= 5, base >= total * 2, Double(support) / Double(total) >= 0.9 else { continue }
                edges.append(.init(concept: concept, prerequisite: prerequisite, support: support,
                                   conditionalFrequency: Double(support) / Double(total)))
            }
        }
        occurrencesByRank = ranks
        self.frequencies = frequencies; cooccurrences = pairs; occurrencesByPack = packs; prerequisites = edges
    }
    public func isCurrent(for profiles: [DifficultyProfile]) -> Bool {
        analyserVersion == DifficultyModel.version && corpusKeys == profiles.sorted { $0.key.canonical < $1.key.canonical }.map(\.key)
    }
}
