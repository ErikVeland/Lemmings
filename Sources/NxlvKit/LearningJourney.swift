import Foundation

/// A teaching order, independent of retail ranks. Estimates never certify human insight.
public struct LearningJourney: Codable, Equatable, Sendable {
    public static let title = "Oh My! All Lemmings!"
    public static let version = "learning-6"
    public static let playlistID = UUID(uuidString: "80368144-659B-4697-B2D0-76894BF20B18")!
    public static let maximumScoreStep = 65.0

    /// These sources contain competitive two-player puzzles, even when a replay
    /// can win them in the single-player simulation.
    public static func isSinglePlayer(_ entry: LevelPlaylistEntry, sourceRank: String? = nil) -> Bool {
        let multiplayerPacks: Set<String> = ["fan:lldb-404", "fan:lldb-405", "fan:lldb-572", "fan:lldb-582", "fan:lldb-583"]
        guard !multiplayerPacks.contains(entry.identity.packID) else { return false }
        let metadata = [entry.packNameSnapshot, entry.identity.levelID, sourceRank ?? ""].joined(separator: " ").lowercased()
        return metadata.range(of: #"\b(versus|multiplayer|2p|two[\s_-]*player|2[\s_-]*player)\b"#, options: .regularExpression) == nil
    }

    public enum Stage: String, Codable, CaseIterable, Sendable {
        case fun = "Fun", intermediate = "Intermediate", difficult = "Difficult", expert = "Expert"
        public var order: Int { Self.allCases.firstIndex(of: self)! }
        public static func forDemand(_ demand: Double) -> Self {
            if demand < 180 { return .fun }
            if demand < 360 { return .intermediate }
            if demand < 600 { return .difficult }
            return .expert
        }
    }

    public struct Lesson: Codable, Equatable, Sendable {
        public let entry: LevelPlaylistEntry
        /// The original evidence score, retained without smoothing or relabelling.
        public let score: Double
        public let intrinsicDemand: Double
        public let demand: Double
        public let stage: Stage
        /// Basic skills without prior practice when a combination starts.
        public let preparationGaps: [String]
        public let concepts: [String]
        public let introduced: [String]
        public let focus: String
        public let needsSupport: Bool
    }
    public let version: String
    public let lessons: [Lesson]

    public func validated() throws -> Self {
        guard version == Self.version, !lessons.isEmpty,
              lessons.count <= LevelPlaylist.maximumEntries,
              Set(lessons.map { $0.entry.identity }).count == lessons.count,
              lessons.allSatisfy({ $0.entry.identity.engine == .classic && Self.isSinglePlayer($0.entry) && $0.score.isFinite
                  && $0.demand.isFinite && (0...1000).contains($0.demand)
                  && $0.stage == Stage.forDemand($0.demand) }),
              zip(lessons, lessons.dropFirst()).allSatisfy({
                  $0.stage.order <= $1.stage.order && Int($0.demand / 35) <= Int($1.demand / 35)
              }) else {
            throw LevelPlaylistError.invalidPool
        }
        return self
    }

    public func playlist() throws -> LevelPlaylist {
        _ = try validated()
        return try LevelPlaylist(id: Self.playlistID, name: Self.title, entries: lessons.map(\.entry))
    }

    /// Use the hardest observed demand as a floor. These curriculum weights and
    /// stage boundaries are editorial estimates, not a new human-calibrated model.
    public static func demand(for profile: DifficultyProfile) -> Double {
        let c = profile.components
        let combinationFloor = Double(max(0, profile.detectedTechniques.count - 1)) * 90
        return min(1000, [profile.overallScore, c.techniqueBurden * 0.85,
            c.solutionComplexity * 0.70, c.executionPrecision * 0.85,
            c.concurrencyBurden * 0.85, c.deductionComplexityProxy * 0.85,
            c.constraintPressure * 0.50, combinationFloor].max()!)
    }

    /// Work through narrow demand bands. Within each band, prepare combinations,
    /// space repeated practice and prefer a small increase in execution demands.
    /// Official puzzles take priority over other puzzles within a demand band.
    /// Retail order is not a teaching prerequisite.
    public static func generate(_ candidates: [ProgressionCandidate]) throws -> Self {
        guard !candidates.isEmpty, candidates.count <= LevelPlaylist.maximumEntries,
              Set(candidates.map { $0.entry.identity }).count == candidates.count,
              candidates.allSatisfy({ $0.entry.identity.engine == .classic && isSinglePlayer($0.entry, sourceRank: $0.profile.sourceRank) && $0.profile.confidence != .low
                  && $0.entry.identity == $0.profile.key.identity
                  && $0.entry.sourceRevision == $0.profile.key.levelRevision }) else { throw LevelPlaylistError.invalidPool }
        let basicSkills: Set<String> = ["climber", "floater", "bomber", "blocker", "builder", "basher", "miner", "digger"]
        var foundations: [String: Double] = [:]
        for candidate in candidates where candidate.profile.detectedTechniques.count == 1 {
            let concept = candidate.profile.detectedTechniques[0]
            foundations[concept] = min(foundations[concept] ?? 1000, demand(for: candidate.profile))
        }
        func placementDemand(_ profile: DifficultyProfile) -> Double {
            guard profile.detectedTechniques.count > 1 else { return demand(for: profile) }
            // A combination cannot precede its easiest available isolated lesson.
            return max(demand(for: profile), profile.detectedTechniques.compactMap { foundations[$0] }.max() ?? 0)
        }
        var remaining = candidates.sorted { $0.stableKey < $1.stableKey }
        var practice: [String: Int] = [:]
        var lessons: [Lesson] = []
        var previous: DifficultyProfile?
        var exposure = [Double](repeating: 0, count: 6)
        func dimensions(_ p: DifficultyProfile) -> [Double] {
            let c = p.components
            return [c.techniqueBurden, c.solutionComplexity, c.executionPrecision,
                    c.concurrencyBurden, c.constraintPressure, c.deductionComplexityProxy]
        }
        func gaps(_ p: DifficultyProfile) -> [String] {
            guard p.detectedTechniques.count > 1 else { return [] }
            let required = p.detectedTechniques.count > 2 ? 2 : 1
            return Set(p.detectedTechniques + p.prerequisiteConcepts).intersection(basicSkills)
                .filter { practice[$0, default: 0] < required }.sorted()
        }
        while !remaining.isEmpty {
            try Task.checkCancellation()
            let minimum = remaining.map { placementDemand($0.profile) }.min()!
            let stage = Stage.forDemand(minimum)
            let band = Int(minimum / 35)
            let eligible = remaining.filter {
                let value = placementDemand($0.profile)
                return Stage.forDemand(value) == stage && Int(value / 35) == band
            }
            // Keep practice prerequisites and raw replay scores close before
            // using origin, technique spacing and execution cost to break ties.
            let prepared = eligible.filter { gaps($0.profile).isEmpty }
            let available = prepared.isEmpty ? eligible : prepared
            let lowestScore = available.map { $0.profile.overallScore }.min()!
            let smooth = available.filter { $0.profile.overallScore <= lowestScore + 10 }
            func cost(_ candidate: ProgressionCandidate) -> Double {
                let p = candidate.profile
                let concepts = Set(p.detectedTechniques)
                let last = lessons.last.map { Set($0.concepts) }
                let repeated = last == concepts && !concepts.isEmpty
                let twice = repeated && lessons.dropLast().last.map { Set($0.concepts) == concepts } == true
                let unfamiliar = concepts.filter { practice[$0, default: 0] == 0 }.count
                let rise = zip(dimensions(p), previous.map(dimensions) ?? exposure)
                    .map { max(0, $0 - $1) }.max() ?? 0
                // A passive opening teaches no action. Passive levels remain in
                // their band as breathers once there is an active alternative.
                let passive = concepts.isEmpty && (lessons.isEmpty || lessons.last?.concepts.isEmpty == true)
                let opening = lessons.isEmpty ? p.components.solutionComplexity * 2 : 0
                return opening + Double(gaps(p).count) * 1000 + Double(max(0, unfamiliar - 1)) * 1000
                    + (passive ? 2000 : 0) + (twice ? 500 : repeated ? 65 : 0)
                    + rise * 0.10 + placementDemand(p) + p.components.solutionComplexity * 0.05
                    + (candidate.isOfficial ? 0 : 100)
            }
            let next = smooth.min {
                let a = cost($0), b = cost($1)
                return a == b ? $0.stableKey < $1.stableKey : a < b
            }!
            let p = next.profile
            let new = p.detectedTechniques.filter { practice[$0, default: 0] == 0 }.sorted()
            let missing = gaps(p)
            let value = placementDemand(p)
            let demandJump = value - (lessons.last?.demand ?? value)
            let unseenDemand = zip(dimensions(p), exposure).map { max(0, $0 - $1) }.max() ?? 0
            let topics = new.isEmpty ? p.detectedTechniques : new
            let names = topics.prefix(2).map { concept in
                switch concept {
                case "multiple-worker-coordination": return "Two workers"
                case "release-rate-manipulation": return "Crowd spacing"
                default: return concept.replacingOccurrences(of: "-", with: " ").capitalized
                }
            }
            let prefix = !new.isEmpty ? "Discover: " : topics.count > 1 ? "Combine: " : "Practise: "
            let focus = names.isEmpty ? "Take a breather" : prefix + names.joined(separator: " + ")
            lessons.append(.init(entry: next.entry, score: p.overallScore, intrinsicDemand: demand(for: p), demand: value,
                stage: stage, preparationGaps: missing, concepts: p.detectedTechniques,
                introduced: new, focus: focus,
                needsSupport: demandJump > maximumScoreStep || unseenDemand > 150 || !missing.isEmpty || new.count > 1))
            for concept in p.detectedTechniques { practice[concept, default: 0] += 1 }
            exposure = zip(exposure, dimensions(p)).map { max($0, $1) }
            previous = p
            remaining.removeAll { $0.entry.identity == next.entry.identity }
        }
        return try Self(version: version, lessons: lessons).validated()
    }

}

/// Visits are not wins. A parked puzzle remains available without granting stars or progress in a retail campaign.
public struct LearningJourneyProgress: Codable, Equatable, Sendable {
    public private(set) var completed: Set<LevelCatalogueIdentity> = []
    public private(set) var later: Set<LevelCatalogueIdentity> = []
    public init() {}
    public mutating func record(_ identity: LevelCatalogueIdentity, won: Bool) {
        if won { completed.insert(identity); later.remove(identity) }
        else if !completed.contains(identity) { later.insert(identity) }
    }
    public func unseen(in journey: LearningJourney) -> [LevelPlaylistEntry] {
        journey.lessons.map(\.entry).filter { !completed.contains($0.identity) && !later.contains($0.identity) }
    }
    /// Solved lessons in this journey. Wins on levels that a later journey
    /// version removed stay recorded but do not count here.
    public func solvedCount(in journey: LearningJourney) -> Int {
        journey.lessons.filter { completed.contains($0.entry.identity) }.count
    }
    public func revisit(in journey: LearningJourney) -> [LevelPlaylistEntry] {
        journey.lessons.map(\.entry).filter { later.contains($0.identity) && !completed.contains($0.identity) }
    }
}
