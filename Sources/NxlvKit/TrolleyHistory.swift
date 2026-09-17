import Foundation
import CryptoKit

public enum TrolleyAchievement: String, Codable, CaseIterable, Sendable {
    case noLemmingLeftBehind, aboveAndBeyond, trolleyProblem, greaterGood, oneMore, perfectlyAdequate, moralSurplus, absoluteMaximum, falsifier
    case bentham, mill, kant, singer, aristotle, epicurus, hobbes, sartre, absurdist, humanist, bureaucrat, `operator`, traveller
    case rescueRival, potentialRival, recordMatched, economist, signatureMove, publicGood, cleanSweep, tripleCrown
    case comeback, secondThoughts, targetApprentice, targetScholar, targetSage, greatDebate, philosopherKing, schoolOfThought, unbrokenArgument
    public var title: String {
        switch self {
        case .falsifier: "Karl Popper - The Falsifier"
        case .noLemmingLeftBehind: "No Lemming left behind"
        case .aboveAndBeyond: "Above and beyond"
        case .trolleyProblem: "The Trolley Problem"
        case .greaterGood: "The Greater Good"
        case .oneMore: "One more"
        case .perfectlyAdequate: "Perfectly adequate"
        case .moralSurplus: "Moral surplus"
        case .absoluteMaximum: "Absolute maximum"
        default: Self.collection[self]!.title
        }
    }
    public var detail: String {
        switch self {
        case .falsifier: "Clear a level with more rescued than its established rescue target."
        case .noLemmingLeftBehind: "Match a verified maximum."
        case .aboveAndBeyond: "Save at least 5 extra and 20% of the starting population beyond the requirement."
        case .trolleyProblem: "Clear a level with verified unavoidable losses."
        case .greaterGood: "Clear with a verified sacrifice enabling at least three times as many rescues."
        case .oneMore: "Finish one below a verified maximum."
        case .perfectlyAdequate: "Clear with exactly the required rescue count."
        case .moralSurplus: "Save 100 extra Lemmings across recorded attempts."
        case .absoluteMaximum: "Match verified maximums on 10 distinct levels."
        default: Self.collection[self]!.detail
        }
    }
    static func earned(run: ArcadeRun, metrics: TrolleyMetrics, philosophy: TrolleyPhilosophy,
                       history: [TrolleyAttempt]) -> [Self] {
        let personal = history.filter { $0.run.profileID == run.profileID }
        var result: Set<Self> = []
        if philosophy.titles.contains(.falsifier) { result.insert(.falsifier) }
        if philosophy.titles.contains(.absolutist) { result.insert(.noLemmingLeftBehind) }
        if metrics.moralSurplus >= max(5, Int(ceil(Double(run.level.total) * 0.2))) { result.insert(.aboveAndBeyond) }
        if run.didWin && (metrics.unavoidableLosses ?? 0) > 0 { result.insert(.trolleyProblem) }
        if philosophy.titles.contains(.trolleyOperator) { result.insert(.greaterGood) }
        if philosophy.titles.contains(.lastLemming) { result.insert(.oneMore) }
        if run.didWin && metrics.requirementSurplus == 0 { result.insert(.perfectlyAdequate) }
        if personal.reduce(metrics.moralSurplus, { $0 + $1.metrics.moralSurplus }) >= 100 { result.insert(.moralSurplus) }
        var perfectLevels = Set(personal.filter { $0.philosophy.titles.contains(.absolutist) }.map {
            "\($0.run.level.conditions!.gameID)|\($0.run.level.conditions!.packID)|\($0.run.level.conditions!.levelID)"
        })
        if philosophy.titles.contains(.absolutist), let c = run.level.conditions { perfectLevels.insert("\(c.gameID)|\(c.packID)|\(c.levelID)") }
        if perfectLevels.count >= 10 { result.insert(.absoluteMaximum) }
        let existing = Set(personal.flatMap(\.achievements))
        return allCases.filter { result.contains($0) && !existing.contains($0) }
    }
}

public enum TrolleyVerificationState: String, Codable, Sendable { case local = "LOCAL", replayVerified = "REPLAY_VERIFIED", serverVerified = "SERVER_VERIFIED" }
public struct TrolleyReplayReference: Codable, Equatable, Sendable {
    public let attemptID: UUID
    public let relativePath: String
    public let sha256: String
    public let kind: String
    public let verification: TrolleyVerificationState
    public init(attemptID: UUID, relativePath: String, sha256: String, kind: String = "rendered-movie",
                verification: TrolleyVerificationState = .local) {
        self.attemptID = attemptID; self.relativePath = relativePath; self.sha256 = sha256
        self.kind = kind; self.verification = verification
    }
}

/// Reuses ArcadeRecords' atomic file and existing profile IDs. Legacy runs are never synthesised as attempts.
public struct TrolleyHistory: Codable, Equatable, Sendable {
    public private(set) var version = 1
    public let installationID: String
    public private(set) var attempts: [TrolleyAttempt] = []
    public private(set) var starts: [TrolleyStart] = []
    public private(set) var maxima: [String: TrolleyMaximumRecord] = [:]
    public private(set) var replays: [TrolleyReplayReference] = []
    public init() { installationID = UUID().uuidString }
    public mutating func begin(_ start: TrolleyStart) {
        guard start.conditions.isValid, !starts.contains(where: { $0.id == start.id }),
              !attempts.contains(where: { $0.id == start.id }) else { return }
        starts.append(start)
    }
    public mutating func acceptMaximum(_ evidence: TrolleyMaximum, conditions: TrolleyConditions, assisted: Bool) throws {
        guard conditions.isValid else { throw SequelDataError.invalid("Invalid maximum conditions.") }
        let key = conditions.comparisonID(assisted: assisted)
        var record = maxima[key] ?? TrolleyMaximumRecord()
        try record.acceptVerified(evidence, population: conditions.maximumPopulation ?? 1_000_000)
        maxima[key] = record
    }
    public func maximum(conditions: TrolleyConditions, assisted: Bool) -> TrolleyMaximum {
        maxima[conditions.comparisonID(assisted: assisted)]?.current ?? TrolleyMaximum()
    }
    public mutating func retainBundledMaxima(_ current: [String: TrolleyMaximum]) {
        for key in Array(maxima.keys) { maxima[key]?.retainBundledEvidence(current[key]) }
    }
    /// Removes one player's attempts. Returns their replay references so the caller can delete the files.
    @discardableResult public mutating func removeProfile(_ profileID: String) -> [TrolleyReplayReference] {
        let removed = Set(attempts.filter { $0.run.profileID == profileID }.map(\.id))
        attempts.removeAll { removed.contains($0.id) }
        starts.removeAll { $0.profileID == profileID }
        let orphaned = replays.filter { removed.contains($0.attemptID) }
        replays.removeAll { removed.contains($0.attemptID) }
        for key in Array(maxima.keys) {
            guard let observed = maxima[key]?.observedAttemptID, removed.contains(observed) else { continue }
            maxima[key]?.forgetObservation()
            for attempt in attempts where attempt.comparisonID == key { maxima[key]?.observe(attempt.run) }
        }
        return orphaned
    }
    public func personal(profileID: String, comparisonID: String? = nil) -> TrolleyPersonalRecords {
        .init(attempts: attempts.map { $0.assessed(using: maxima[$0.comparisonID]?.current ?? TrolleyMaximum()) }, starts: starts, profileID: profileID, comparisonID: comparisonID)
    }
    public func leaderboard(conditions: TrolleyConditions, assisted: Bool, board: TrolleyBoard) -> [TrolleyAttempt] {
        TrolleyLeaderboards.rank(attempts, comparisonID: conditions.comparisonID(assisted: assisted), board: board,
                                 maximum: maximum(conditions: conditions, assisted: assisted))
    }
    public static func isLegitimate(_ run: ArcadeRun) -> Bool {
        guard let conditions = run.level.conditions, let t = run.telemetry, conditions.isValid, t.isValid,
              conditions.population == run.level.total, conditions.rescueRequirement == run.level.required,
              (t.additionalStatistics["cloned"].map { $0 >= 0 && $0 <= 1_000_000 && $0.rounded() == $0 } ?? true),
              run.saved >= 0, run.saved <= (conditions.maximumPopulation ?? 1_000_000),
              (run.saved...run.population).contains(t.released), t.destructiveSkillCount <= run.skillCount,
              run.assisted == (t.rewindCount > 0 || t.undoCount > 0), run.seconds.isFinite, run.seconds >= 0,
              run.skills.values.allSatisfy({ $0 > 0 && $0 <= 1_000_000 }) else { return false }
        return conditions.startingSkills.isEmpty || run.skills.allSatisfy { skill, count in
            guard let supply = conditions.startingSkills[skill] else { return false }
            return supply == -1 || count <= supply
        }
    }
    @discardableResult public mutating func record(_ run: ArcadeRun) -> TrolleyReport? {
        guard Self.isLegitimate(run), !attempts.contains(where: { $0.id == run.id }) else { return nil }
        let start = starts.first { $0.id == run.id }
        guard start.map({ $0.profileID == run.profileID && $0.conditions == run.level.conditions }) ?? true else { return nil }
        let conditions = run.level.conditions!, key = conditions.comparisonID(assisted: run.assisted)
        let previousBoard = leaderboard(conditions: conditions, assisted: run.assisted, board: .mostSaved)
        let previousBest = previousBoard.first { $0.run.profileID == run.profileID }?.run.saved
        let previousLocal = previousBoard.first?.run.saved
        var metadata = maxima[key] ?? TrolleyMaximumRecord()
        let prior = metadata.current
        let surpassedTarget = run.qualifies && prior.isRescueTarget && run.saved > (prior.value ?? Int.max) ? prior : nil
        metadata.observe(run); maxima[key] = metadata
        let maximum = metadata.current
        let metrics = TrolleyMetrics(run: run, telemetry: run.telemetry!, maximum: maximum)
        let philosophy = TrolleyAnalyser.analyse(run: run, metrics: metrics, maximum: maximum)
            .recognizingBreakthrough(saved: run.saved, previous: surpassedTarget)
        let baseAwards = TrolleyAchievement.earned(run: run, metrics: metrics, philosophy: philosophy, history: attempts)
        let candidate = TrolleyAttempt(run: run, start: start, maximum: maximum, metrics: metrics,
                                       philosophy: philosophy, achievements: [], surpassedTarget: surpassedTarget)
        let awardSet = Set(baseAwards + TrolleyAchievement.collectionEarned(attempt: candidate, history: attempts))
        let awards = TrolleyAchievement.allCases.filter { awardSet.contains($0) }
        let attempt = TrolleyAttempt(run: run, start: start, maximum: maximum,
                                     metrics: metrics, philosophy: philosophy, achievements: awards, surpassedTarget: surpassedTarget)
        attempts.append(attempt)
        let board = leaderboard(conditions: conditions, assisted: run.assisted, board: .mostSaved)
        return TrolleyReport(attempt: attempt, previousPersonalBest: previousBest, previousLocalBest: previousLocal,
            personal: personal(profileID: run.profileID, comparisonID: key), localBest: board.first?.run.saved ?? run.saved,
            localRank: (board.firstIndex { $0.run.profileID == run.profileID } ?? 0) + 1,
            retry: .suggest(attempt, previousBest: previousBest, localBest: previousLocal))
    }
    public mutating func attachReplay(_ replay: TrolleyReplayReference) {
        guard attempts.contains(where: { $0.id == replay.attemptID }), !replays.contains(where: { $0.attemptID == replay.attemptID }),
              replay.verification == .local, !replay.relativePath.hasPrefix("/"), !replay.relativePath.contains(".."),
              replay.sha256.count == 64 else { return }
        replays.append(replay)
    }
    public func submission(attemptID: UUID, publicInitials: String? = nil, spritePortrait: Int? = nil) -> TrolleySubmission? {
        guard let attempt = attempts.first(where: { $0.id == attemptID }) else { return nil }
        let identity = SHA256.hash(data: Data((installationID + ":" + attempt.run.profileID).utf8))
            .map { String(format: "%02x", $0) }.joined()
        return TrolleySubmission(attempt: attempt, anonymousPlayerID: identity, publicInitials: publicInitials,
            spritePortrait: spritePortrait, replay: replays.first { $0.attemptID == attemptID })
    }
    public func validated(profileIDs: Set<String>) throws -> Self {
        guard version == 1, UUID(uuidString: installationID) != nil, Set(attempts.map(\.id)).count == attempts.count,
              Set(starts.map(\.id)).count == starts.count,
              starts.allSatisfy({ profileIDs.contains($0.profileID) && $0.conditions.isValid }),
              maxima.allSatisfy({ key, record in
                  record.current.isValid(population: 1_000_000)
                    && (record.highestObserved.map { value in attempts.contains { $0.id == record.observedAttemptID
                        && $0.comparisonID == key && $0.run.saved == value } } ?? true)
              }),
              attempts.allSatisfy({ a in
                  guard a.schemaVersion == 1, profileIDs.contains(a.run.profileID), Self.isLegitimate(a.run),
                        a.maximum.isValid(population: a.run.level.conditions!.maximumPopulation ?? 1_000_000), (a.maximum.value ?? a.run.saved) >= a.run.saved,
                        a.metrics == TrolleyMetrics(run: a.run, telemetry: a.run.telemetry!, maximum: a.maximum),
                        a.rescueGoals.map({ $0 == TrolleyRescueGoals(run: a.run, maximum: a.maximum) }) ?? true,
                        a.surpassedTarget.map({ a.run.qualifies && $0.isRescueTarget
                            && $0.isValid(population: a.run.level.conditions!.maximumPopulation ?? 1_000_000)
                            && ($0.value ?? Int.max) < a.run.saved && a.philosophy.titles.contains(.falsifier) }) ?? true,
                        Set(a.philosophy.dimensions.keys) == Set(TrolleyDimension.allCases),
                        a.philosophy.dimensions.values.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return false }
                  return a.start.map { $0.id == a.id && $0.profileID == a.run.profileID && $0.conditions == a.run.level.conditions } ?? true
              }), replays.allSatisfy({ replay in attempts.contains { $0.id == replay.attemptID } }) else {
            throw SequelDataError.invalid("Invalid Trolley attempt history. The saved file must be preserved.")
        }
        return self
    }
}

/// An explicit export value only. This model has no transport or automatic submission path.
public struct TrolleySubmission: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let anonymousPlayerID: String
    public let publicInitials: String?
    public let spritePortrait: Int?
    public let attempt: TrolleyAttempt
    public let replay: TrolleyReplayReference?
    public let verification: TrolleyVerificationState
    public let submissionTimestamp: Date?
    public init(attempt: TrolleyAttempt, anonymousPlayerID: String, publicInitials: String? = nil, spritePortrait: Int? = nil,
                replay: TrolleyReplayReference? = nil, submissionTimestamp: Date? = nil) {
        schemaVersion = 1; self.anonymousPlayerID = anonymousPlayerID; self.publicInitials = publicInitials
        self.spritePortrait = spritePortrait; self.attempt = attempt; self.replay = replay
        verification = .local; self.submissionTimestamp = submissionTimestamp
    }
}
