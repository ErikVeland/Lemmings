import Foundation

/// A teaching order, independent of retail ranks. Estimates never certify human insight.
public struct LearningJourney: Codable, Equatable, Sendable {
    public static let title = "Oh My! All Lemmings!"
    public static let version = "learning-13"
    public static let communityPlacementPolicy = "redux-calibrated-2"
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
        public static func forLesson(demand: Double, objective: String?) -> Self {
            if demand < 180 { return .fun }
            if objective != nil, objective?.hasPrefix("introduce:") != true, demand < 360 { return .intermediate }
            return forDemand(demand)
        }
        public static func forDemand(_ demand: Double) -> Self {
            if demand < 180 { return .fun }
            if demand < 360 { return .intermediate }
            if demand < 600 { return .difficult }
            return .expert
        }
    }

    /// Community order is ordinal evidence, not a measured interval scale.
    public struct Placement: Codable, Equatable, Sendable {
        public let basis: String
        public let reference: String
        public let sourceURL: String
        public let position: Double
        public let lower: Double
        public let upper: Double
        public let sourceRevision: String
        public let replayRevision: String
    }

    public struct Lesson: Codable, Equatable, Sendable {
        public let entry: LevelPlaylistEntry
        public let objective: String?
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
        public var placement: Placement? = nil
    }
    public let version: String
    public let lessons: [Lesson]
    public var placementPolicy: String? = nil

    public func excluding(_ identities: Set<LevelCatalogueIdentity>) -> Self {
        Self(version: version, lessons: lessons.filter { !identities.contains($0.entry.identity) },
             placementPolicy: placementPolicy)
    }

    public func validated() throws -> Self {
        guard version == Self.version, !lessons.isEmpty,
              lessons.count <= LevelPlaylist.maximumEntries,
              Set(lessons.map { $0.entry.identity }).count == lessons.count,
              Set(lessons.compactMap(\.objective)).count == lessons.compactMap(\.objective).count,
              lessons.allSatisfy({ $0.entry.identity.engine == .classic && Self.isSinglePlayer($0.entry) && $0.score.isFinite
                  && $0.demand.isFinite && (0...1000).contains($0.demand)
                  && $0.stage == Stage.forLesson(demand: $0.demand, objective: $0.objective) }),
              zip(lessons, lessons.dropFirst()).allSatisfy({
                  $0.stage.order <= $1.stage.order && Int($0.demand / 35) <= Int($1.demand / 35)
              }) else {
            throw LevelPlaylistError.invalidPool
        }
        if placementPolicy != nil {
            guard placementPolicy == Self.communityPlacementPolicy,
                  lessons.allSatisfy({ lesson in
                      guard let p = lesson.placement else { return false }
                      return ["reduxClassicCounterpart", "reviewedFan", "solutionEstimate"].contains(p.basis)
                          && !p.reference.isEmpty && p.sourceURL.hasPrefix("https://")
                          && p.position.isFinite && p.lower.isFinite && p.upper.isFinite
                          && 0 <= p.lower && p.lower <= p.position && p.position <= p.upper
                          && p.upper <= 1000 && p.upper - p.lower <= (p.basis == "solutionEstimate" ? 1000 : 20)
                          && lesson.demand == p.position && p.sourceRevision == lesson.entry.sourceRevision
                          && !p.replayRevision.isEmpty
                          && (!lesson.entry.identity.packID.hasPrefix("fan:") || ["reviewedFan", "solutionEstimate"].contains(p.basis))
                  }),
                  zip(lessons, lessons.dropFirst()).allSatisfy({
                      (0...Self.maximumScoreStep).contains($1.demand - $0.demand)
                  }) else { throw LevelPlaylistError.invalidPool }
        }
        return self
    }

    /// Replace an older built-in queue without inventing wins or changing its owner.
    /// Keep a retained current lesson; a withdrawn lesson returns to the first unvisited reference.
    public func migrating(_ run: LevelSequenceRun) throws -> LevelSequenceRun? {
        guard run.source == .playlist(Self.playlistID),
              run.pool.id.hasPrefix("learning-"),
              let oldVersion = Int(run.pool.id.dropFirst("learning-".count)),
              let newVersion = Int(version.dropFirst("learning-".count)),
              oldVersion < newVersion else { return run }
        _ = try validated()
        guard placementPolicy == Self.communityPlacementPolicy else { return run }
        let visited = Set(run.entries.prefix(run.currentIndex).map(\.identity))
        let current = lessons.firstIndex { $0.entry.identity == run.currentEntry.identity
            && $0.entry.sourceRevision == run.currentEntry.sourceRevision }
        let future = lessons.dropFirst(current ?? 0).map(\.entry).filter { !visited.contains($0.identity) }
        guard !future.isEmpty else { return nil }
        // Past visits are history, not proof of completion. Progress records stay untouched.
        let past = Array(run.entries.prefix(run.currentIndex))
        return try LevelSequenceRun(id: run.id, source: run.source,
            pool: LevelPool(id: version, summary: run.pool.summary), entries: past + future,
            currentIndex: past.count, seed: run.seed, algorithm: run.algorithm, createdAt: run.createdAt)
    }

    public func playlist() throws -> LevelPlaylist {
        _ = try validated()
        return try LevelPlaylist(id: Self.playlistID, name: Self.title, entries: lessons.map(\.entry))
    }

    /// Use retail rank and full-rescue requirements as conservative placement floors.
    /// These are editorial estimates, not human-calibrated difficulty scores.
    public static func rankDemandFloor(for entry: LevelPlaylistEntry, sourceRank: String?) -> Double {
        let rank = [sourceRank ?? "", entry.packNameSnapshot].joined(separator: " ").lowercased()
        let words = Set(rank.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        if !words.isDisjoint(with: ["fun", "easy", "tame"]) { return 0 }
        if !words.isDisjoint(with: ["tricky", "medium", "flurry"]) { return 180 }
        if !words.isDisjoint(with: ["taxing", "hard", "awkward"]) { return 360 }
        if !words.isDisjoint(with: ["mayhem", "daunting", "crazy", "wild", "expert", "insane"]) { return 600 }
        return 0
    }

    public static func hasRecognisedRank(for entry: LevelPlaylistEntry, sourceRank: String?) -> Bool {
        let rank = [sourceRank ?? "", entry.packNameSnapshot].joined(separator: " ").lowercased()
        let words = Set(rank.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        return !words.isDisjoint(with: ["fun", "easy", "tame", "tricky", "medium", "flurry",
            "taxing", "hard", "awkward", "mayhem", "daunting", "crazy", "wild", "expert", "insane"])
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

    /// Keep source levels with tight release or rescue constraints out of the opening stages.
    public static let demandingLevelFloor = 360.0
    public static let highRescueRequirementRatio = 0.95
    public static let highAssignmentCount = 12

    /// Experimental replay-only ordering. The bundled journey must use the
    /// community placement policy, which does not use these heuristic floors.
    /// Work through narrow demand bands. Within each band, prepare combinations,
    /// space repeated practice and prefer a small increase in execution demands.
    /// Official puzzles take priority over other puzzles within a demand band.
    /// Retail order is not a teaching prerequisite.
    public static func generate(_ candidates: [ProgressionCandidate], focuses: [LevelCatalogueIdentity: String] = [:], objectives: [LevelCatalogueIdentity: String] = [:]) throws -> Self {
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
        // Three-concept routes need two earlier encounters with each basic skill.
        // Include short combinations when finding the second practice floor.
        let secondPractice = Dictionary(uniqueKeysWithValues: basicSkills.compactMap { skill -> (String, Double)? in
            let values = candidates.filter { $0.profile.detectedTechniques.count <= 2
                && $0.profile.detectedTechniques.contains(skill) }.map { demand(for: $0.profile) }.sorted()
            return values.count >= 2 ? (skill, values[1]) : nil
        })
        var practice: [String: Int] = [:]
        var lessons: [Lesson] = []
        func missingPractice(_ profile: DifficultyProfile) -> [String] {
            guard profile.detectedTechniques.count > 1 else { return [] }
            let required = profile.detectedTechniques.count > 2 ? 2 : 1
            return Set(profile.detectedTechniques + profile.prerequisiteConcepts).intersection(basicSkills)
                .filter { practice[$0, default: 0] < required }.sorted()
        }
        func placementDemand(_ candidate: ProgressionCandidate) -> Double {
            let profile = candidate.profile
            let rankFloor = candidate.rankIsUnverified ? 180.0
                : Self.rankDemandFloor(for: candidate.entry, sourceRank: profile.sourceRank)
            let rescueFloor = candidate.requiresFullRescue ? 360.0 : 0.0
            let sourceConstraintFloor = candidate.startingReleaseRate == nil
                || candidate.rescueRequirementRatio == nil
                || candidate.startingReleaseRate == 99
                || !profile.criticalActions.isEmpty
                || (candidate.rescueRequirementRatio ?? 0) >= Self.highRescueRequirementRatio
                || (candidate.skillAssignmentCount ?? 0) >= Self.highAssignmentCount
                ? Self.demandingLevelFloor : 0.0
            let missingPracticeFloor = missingPractice(profile).isEmpty ? 0.0 : 180.0
            let sequenceFloor = lessons.last?.demand ?? 0.0
            let observed = demand(for: profile)
            guard profile.detectedTechniques.count > 1 else {
                return [observed, rankFloor, rescueFloor, sourceConstraintFloor, sequenceFloor].max()!
            }
            // A combination cannot precede its easiest available isolated lesson.
            let preparation = profile.detectedTechniques.count > 2
                ? profile.detectedTechniques.compactMap { secondPractice[$0] }.max() ?? 0 : 0
            return [observed, profile.detectedTechniques.compactMap { foundations[$0] }.max() ?? 0,
                    preparation, rankFloor, rescueFloor, sourceConstraintFloor,
                    missingPracticeFloor, sequenceFloor].max()!
        }
        func effectiveDemand(_ candidate: ProgressionCandidate) -> Double {
            [demand(for: candidate.profile),
             candidate.rankIsUnverified ? 180.0
                : Self.rankDemandFloor(for: candidate.entry, sourceRank: candidate.profile.sourceRank),
             candidate.requiresFullRescue ? 360.0 : 0.0,
             candidate.startingReleaseRate == nil
                || candidate.rescueRequirementRatio == nil
                || candidate.startingReleaseRate == 99
                || !candidate.profile.criticalActions.isEmpty
                || (candidate.rescueRequirementRatio ?? 0) >= Self.highRescueRequirementRatio
                || (candidate.skillAssignmentCount ?? 0) >= Self.highAssignmentCount
                ? Self.demandingLevelFloor : 0.0].max()!
        }
        var remaining = candidates.sorted { $0.stableKey < $1.stableKey }
        var previous: DifficultyProfile?
        var exposure = [Double](repeating: 0, count: 6)
        func dimensions(_ p: DifficultyProfile) -> [Double] {
            let c = p.components
            return [c.techniqueBurden, c.solutionComplexity, c.executionPrecision,
                    c.concurrencyBurden, c.constraintPressure, c.deductionComplexityProxy]
        }
        func gaps(_ p: DifficultyProfile) -> [String] {
            missingPractice(p)
        }
        while !remaining.isEmpty {
            try Task.checkCancellation()
            func stage(for candidate: ProgressionCandidate) -> Stage {
                Stage.forLesson(demand: placementDemand(candidate), objective: objectives[candidate.entry.identity])
            }
            let currentStage = remaining.map { stage(for: $0) }.min { $0.order < $1.order }!
            let minimum = remaining.filter { stage(for: $0) == currentStage }.map(placementDemand).min()!
            let band = Int(minimum / 35)
            let eligible = remaining.filter {
                return stage(for: $0) == currentStage && Int(placementDemand($0) / 35) == band
            }
            // Keep practice prerequisites and raw replay scores close before
            // using origin, technique spacing and execution cost to break ties.
            let gradual = eligible.filter { placementDemand($0) - (lessons.last?.demand ?? minimum) <= maximumScoreStep }
            let bounded = gradual.isEmpty ? eligible : gradual
            let prepared = bounded.filter { gaps($0.profile).isEmpty }
            let available = prepared.isEmpty ? bounded : prepared
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
                    + rise * 0.10 + effectiveDemand(candidate) + p.components.solutionComplexity * 0.05
                    + (candidate.isOfficial ? 0 : 100)
            }
            let next = smooth.min {
                let a = cost($0), b = cost($1)
                return a == b ? $0.stableKey < $1.stableKey : a < b
            }!
            let p = next.profile
            let new = p.detectedTechniques.filter { practice[$0, default: 0] == 0 }.sorted()
            let missing = gaps(p)
            let value = placementDemand(next)
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
            lessons.append(.init(entry: next.entry, objective: objectives[next.entry.identity], score: p.overallScore, intrinsicDemand: demand(for: p), demand: value,
                stage: Stage.forLesson(demand: value, objective: objectives[next.entry.identity]), preparationGaps: missing, concepts: p.detectedTechniques,
                introduced: new, focus: focuses[next.entry.identity] ?? focus,
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
