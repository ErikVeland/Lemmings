import Foundation

public struct DifficultyCorpusReport: Codable, Sendable {
    public struct CampaignJump: Codable, Sendable {
        public let from: LevelCatalogueIdentity
        public let to: LevelCatalogueIdentity
        public let scoreIncrease: Double
    }
    public let analyserVersion: String
    public let levels: Int
    public let confidencePercent: [String: Double]
    public let levelsPerGrade: [String: Int]
    public let officialLevelsPerGrade: [String: Int]
    public let communityLevelsPerGrade: [String: Int]
    public let techniqueFrequencies: [String: Int]
    public let sortedScores: [Double]
    public let largestOfficialJumps: [CampaignJump]
    public let smoothProgression: [ProgressionSelection]
    public let originalPlusProgression: [ProgressionSelection]
    public let failures: [String]
    public let limitations: [String]
    public init(candidates: [ProgressionCandidate], failures: [String] = [], limitations: [String] = []) throws {
        analyserVersion = DifficultyModel.version; levels = candidates.count
        let grouped = Dictionary(grouping: candidates, by: { $0.profile.confidence.rawValue })
        confidencePercent = grouped.mapValues { Double($0.count) * 100 / Double(max(1, candidates.count)) }
        func grades(_ values: [ProgressionCandidate]) -> [String: Int] {
            let counts = Dictionary(grouping: values, by: { $0.profile.grade.name }).mapValues(\.count)
            return Dictionary(uniqueKeysWithValues: DifficultyGrade.allCases.map { ($0.name, counts[$0.name, default: 0]) })
        }
        levelsPerGrade = grades(candidates)
        officialLevelsPerGrade = grades(candidates.filter(\.isOfficial))
        communityLevelsPerGrade = grades(candidates.filter { !$0.isOfficial })
        let statistics = DifficultyCorpusStatistics(profiles: candidates.map(\.profile))
        techniqueFrequencies = statistics.frequencies
        sortedScores = candidates.map(\.profile.overallScore).sorted()
        var jumps: [CampaignJump] = []
        let campaigns = Dictionary(grouping: candidates.filter(\.isOfficial), by: { $0.entry.identity.packID })
        for name in campaigns.keys.sorted() {
            let campaign = campaigns[name]!.sorted {
                $0.campaignOrder == $1.campaignOrder ? $0.stableKey < $1.stableKey : $0.campaignOrder < $1.campaignOrder
            }
            for (a, b) in zip(campaign, campaign.dropFirst()) {
                jumps.append(.init(from: a.entry.identity, to: b.entry.identity,
                    scoreIncrease: b.profile.overallScore - a.profile.overallScore))
            }
        }
        largestOfficialJumps = Array(jumps.sorted {
            if $0.scoreIncrease != $1.scoreIncrease { return $0.scoreIncrease > $1.scoreIncrease }
            return $0.to.levelID < $1.to.levelID
        }.prefix(30))
        smoothProgression = candidates.isEmpty ? [] : try ProgressionGenerator.generate(candidates: candidates,
            policy: .smooth, statistics: statistics).diagnostics
        originalPlusProgression = candidates.isEmpty ? [] : try ProgressionGenerator.generate(candidates: candidates,
            policy: .originalPlus, statistics: statistics).diagnostics
        self.failures = failures; self.limitations = limitations
    }
}
