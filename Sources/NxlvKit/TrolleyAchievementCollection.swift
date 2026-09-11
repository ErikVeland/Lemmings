import Foundation

public enum TrolleyAchievementGroup: String, CaseIterable, Sendable {
    case rescue = "Rescue", philosophy = "Philosophy", rivalries = "Rivalries", mastery = "Mastery"
}
public enum TrolleyAchievementTier: String, Sendable { case bronze = "Bronze", silver = "Silver", gold = "Gold", legendary = "Legendary" }

public struct TrolleyAchievementProgress: Equatable, Sendable {
    public let value: Int
    public let goal: Int
    public let earned: Bool
    public var label: String { earned ? "Earned" : value >= goal ? "Ready to claim" : "\(value)/\(goal)" }
}

extension TrolleyAchievement {
    /// These objectives need evidence that the playable engines do not produce.
    public var isOffered: Bool {
        ![Self.bentham, .sartre, .operator, .greaterGood, .trolleyProblem].contains(self)
    }
    struct Definition {
        let title: String
        let detail: String
        let group: TrolleyAchievementGroup
        let tier: TrolleyAchievementTier
        let goal: Int
        let philosopher: String?
        init(_ title: String, _ detail: String, _ group: TrolleyAchievementGroup, _ tier: TrolleyAchievementTier = .bronze,
             goal: Int = 1, philosopher: String? = nil) {
            self.title = title; self.detail = detail; self.group = group; self.tier = tier; self.goal = goal; self.philosopher = philosopher
        }
    }
    static let collection: [Self: Definition] = [
        .bentham: .init("The Greater Sum", "Clear a level as Jeremy Bentham, with an evidenced trade-off.", .philosophy, .gold, philosopher: "bentham"),
        .mill: .init("A Mill-ion Reasons", "Clear a level with the John Stuart Mill play style.", .philosophy, philosopher: "mill"),
        .kant: .init("Kant Touch This", "Clear a level with the Immanuel Kant play style.", .philosophy, .silver, philosopher: "kant"),
        .singer: .init("Small Budget, Big Heart", "Clear a level with the Peter Singer play style.", .philosophy, .silver, philosopher: "singer"),
        .aristotle: .init("The Golden Mean", "Clear a level with the Aristotle play style.", .philosophy, philosopher: "aristotle"),
        .epicurus: .init("Do Not Disturb", "Clear a level with the Epicurus play style.", .philosophy, philosopher: "epicurus"),
        .hobbes: .init("Order from Chaos", "Clear a level with the Thomas Hobbes play style.", .philosophy, philosopher: "hobbes"),
        .sartre: .init("No Exit? Watch Me", "Clear as Jean-Paul Sartre, with an evidenced unconventional route.", .philosophy, .gold, philosopher: "sartre"),
        .absurdist: .init("Somehow, That Worked", "Clear a level with The Absurdist play style.", .philosophy, .silver, philosopher: "absurdist"),
        .humanist: .init("People, Not Percentages", "Clear a level with The Humanist play style.", .philosophy, philosopher: "humanist"),
        .bureaucrat: .init("Form 27B/6", "Clear a level with The Bureaucrat play style.", .philosophy, philosopher: "bureaucrat"),
        .operator: .init("Mind the Points", "Clear as The Trolley Operator, with an evidenced rescue trade-off.", .philosophy, .gold, philosopher: "trolley_operator"),
        .traveller: .init("Still Thinking", "Clear a level with The Fellow Traveller play style.", .philosophy, philosopher: "fellow_traveller"),
        .rescueRival: .init("Room for One More", "Take Most Saved from another local player by rescuing more.", .rivalries, .silver),
        .potentialRival: .init("Raising the Bar", "Beat your rescue percentage against the same established target.", .rivalries, .bronze),
        .recordMatched: .init("Target Acquired", "Match an established rescue target in a successful clear.", .rivalries, .silver),
        .economist: .init("Occam's Razor", "Beat your best clear's skill count without saving fewer.", .rivalries, .silver),
        .signatureMove: .init("One-Track Mind", "Clear with one skill type and at least five assignments.", .rivalries, .bronze),
        .publicGood: .init("The More the Merrier", "Save at least 20 more than required in one successful clear.", .rivalries, .silver),
        .cleanSweep: .init("Clean Sweep", "Match the target and take Clean Rescue from another local player.", .rivalries, .gold),
        .tripleCrown: .init("The Triple Crown", "Take Most Saved, Least Skills and Clean Rescue from rivals in one clear.", .rivalries, .legendary),
        .comeback: .init("The Last Word", "Win a direct retry of your failed attempt.", .mastery, .bronze),
        .secondThoughts: .init("Second Thoughts", "Retry a clear: save more, or match it with fewer skills or less time.", .mastery, .silver),
        .targetApprentice: .init("A Sound Argument", "Match rescue targets on 3 distinct levels.", .mastery, .silver, goal: 3),
        .targetScholar: .init("Beyond Reasonable Doubt", "Match rescue targets on 10 distinct levels.", .mastery, .gold, goal: 10),
        .targetSage: .init("The Grand Thesis", "Match rescue targets on 30 distinct levels.", .mastery, .legendary, goal: 30),
        .greatDebate: .init("The Great Debate", "Clear levels with 5 different philosophical affinities.", .mastery, .silver, goal: 5),
        .philosopherKing: .init("The Philosopher King", "Clear levels with 10 different philosophical affinities.", .mastery, .legendary, goal: 10),
        .schoolOfThought: .init("School of Thought", "Earn the same play style on 5 distinct cleared levels.", .mastery, .gold, goal: 5),
        .unbrokenArgument: .init("An Unbroken Argument", "Match targets on 5 distinct levels in consecutive attempts, without rewind.", .mastery, .legendary, goal: 5)
    ]
    public var group: TrolleyAchievementGroup { self == .falsifier ? .philosophy : Self.collection[self]?.group ?? .rescue }
    public var tier: TrolleyAchievementTier {
        if self == .falsifier { return .legendary }
        if self == .absoluteMaximum { return .gold }
        return Self.collection[self]?.tier ?? .bronze
    }
    public var philosopherID: String? { self == .falsifier ? "popper" : Self.collection[self]?.philosopher }
    public static func forPhilosopher(_ id: String) -> Self? { allCases.first { $0.philosopherID == id } }
    public static func forBoard(_ board: TrolleyBoard) -> Self {
        switch board {
        case .mostSaved: .rescueRival
        case .rescuePotential: .potentialRival
        case .zeroAvoidableLosses: .recordMatched
        case .leastSkills: .economist
        case .mostUsedSkill: .signatureMove
        case .moralSurplus: .publicGood
        case .cleanRescue: .cleanSweep
        }
    }
    private static func levelKey(_ a: TrolleyAttempt) -> String {
        guard let c = a.run.level.conditions else { return a.run.level.id }
        return [c.gameID, c.packID, c.levelID].joined(separator: "|")
    }
    private static func matched(_ a: TrolleyAttempt) -> Bool { a.run.qualifies && a.maximum.isRescueTarget && a.rescueShortfall == 0 }

    private func count(in personal: [TrolleyAttempt]) -> Int {
        let clears = personal.filter { $0.run.qualifies }
        if let philosopherID { return clears.contains { $0.philosophy.primaryID == philosopherID } ? 1 : 0 }
        switch self {
        case .moralSurplus: return personal.reduce(0) { $0 + $1.metrics.moralSurplus }
        case .absoluteMaximum:
            return Set(personal.filter { $0.philosophy.titles.contains(.absolutist) }.map(Self.levelKey)).count
        case .targetApprentice, .targetScholar, .targetSage:
            return Set(clears.filter(Self.matched).map(Self.levelKey)).count
        case .greatDebate, .philosopherKing: return Set(clears.map { $0.philosophy.primaryID }).count
        case .schoolOfThought:
            return Dictionary(grouping: clears, by: { $0.philosophy.primaryID }).values.map { Set($0.map(Self.levelKey)).count }.max() ?? 0
        case .unbrokenArgument:
            var levels = Set<String>()
            for attempt in personal.reversed() {
                guard !attempt.run.assisted, Self.matched(attempt), levels.insert(Self.levelKey(attempt)).inserted else { break }
            }
            return levels.count
        case .recordMatched: return clears.contains(where: Self.matched) ? 1 : 0
        case .signatureMove: return clears.contains { $0.run.skills.count == 1 && $0.run.skillCount >= 5 } ? 1 : 0
        case .publicGood: return clears.contains { $0.metrics.moralSurplus >= 20 } ? 1 : 0
        default: return 0
        }
    }
    public func progress(attempts: [TrolleyAttempt], profileID: String) -> TrolleyAchievementProgress {
        let personal = attempts.filter { $0.run.profileID == profileID }
        let earned = personal.contains { $0.achievements.contains(self) }
        let goal = self == .moralSurplus ? 100 : self == .absoluteMaximum ? 10 : Self.collection[self]?.goal ?? 1
        return .init(value: earned ? goal : min(goal, count(in: personal)), goal: goal, earned: earned)
    }
    static func collectionEarned(attempt: TrolleyAttempt, history: [TrolleyAttempt]) -> [Self] {
        guard attempt.run.qualifies else { return [] }
        let personal = history.filter { $0.run.profileID == attempt.run.profileID }
        let same = personal.filter { $0.comparisonID == attempt.comparisonID && $0.run.qualifies }
        let all = personal + [attempt]
        var candidates = Set(collection.keys.filter { $0.count(in: all) >= collection[$0]!.goal })
        if same.contains(where: { $0.maximum.isRescueTarget && $0.maximum.value == attempt.maximum.value && $0.run.saved < attempt.run.saved }),
           attempt.maximum.isRescueTarget { candidates.insert(.potentialRival) }
        if let best = same.min(by: { $0.run.skillCount < $1.run.skillCount }),
           attempt.run.skillCount < best.run.skillCount,
           attempt.run.saved >= same.filter({ $0.run.skillCount == best.run.skillCount }).map({ $0.run.saved }).max()! {
            candidates.insert(.economist)
        }
        func takes(_ board: TrolleyBoard) -> Bool {
            guard TrolleyLeaderboards.eligible(attempt, board: board, maximum: attempt.maximum),
                  let leader = TrolleyLeaderboards.rank(history, comparisonID: attempt.comparisonID, board: board, maximum: attempt.maximum).first,
                  leader.run.profileID != attempt.run.profileID, leader.run.qualifies else { return false }
            let changed = attempt.run.saved != leader.run.saved || attempt.run.skillCount != leader.run.skillCount || attempt.run.seconds != leader.run.seconds
            return changed && TrolleyLeaderboards.precedes(attempt, leader, board: board)
        }
        if takes(.mostSaved), let prior = TrolleyLeaderboards.rank(history, comparisonID: attempt.comparisonID, board: .mostSaved, maximum: attempt.maximum).first,
           attempt.run.saved > prior.run.saved { candidates.insert(.rescueRival) }
        if Self.matched(attempt) && takes(.cleanRescue) { candidates.insert(.cleanSweep) }
        if Self.matched(attempt) && [.mostSaved, .leastSkills, .cleanRescue].allSatisfy(takes) { candidates.insert(.tripleCrown) }
        if let start = attempt.start, let parentID = start.parentAttemptID,
           let parent = personal.first(where: { $0.id == parentID && $0.comparisonID == attempt.comparisonID }) {
            if start.kind == .retryAfterFailure && !parent.run.qualifies { candidates.insert(.comeback) }
            if start.kind == .retryAfterSuccess && parent.run.qualifies,
               attempt.run.saved > parent.run.saved || (attempt.run.saved == parent.run.saved
                    && (attempt.run.skillCount < parent.run.skillCount || (attempt.run.skillCount == parent.run.skillCount && attempt.run.seconds < parent.run.seconds))) {
                candidates.insert(.secondThoughts)
            }
        }
        let existing = Set(personal.flatMap { $0.achievements })
        return allCases.filter { candidates.contains($0) && !existing.contains($0) }
    }
}
