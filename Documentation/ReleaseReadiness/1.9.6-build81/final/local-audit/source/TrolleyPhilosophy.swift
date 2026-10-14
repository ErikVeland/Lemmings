import Foundation

public enum TrolleyDimension: String, Codable, CaseIterable, Sendable {
    case preservation, sacrifice, utility, duty, pragmatism, intervention
}
public enum TrolleyTitle: String, Codable, CaseIterable, Sendable {
    case absolutist, lastLemming, pyrrhicVictor, trolleyOperator, falsifier
    public var title: String {
        switch self {
        case .falsifier: "The Falsifier"
        case .absolutist: "The Absolutist"
        case .lastLemming: "One Lemming left behind"
        case .pyrrhicVictor: "The Pyrrhic Victor"
        case .trolleyOperator: "The Trolley Operator"
        }
    }
}
public struct TrolleyPhilosophy: Codable, Equatable, Sendable {
    public let modelVersion: Int
    public let dimensions: [TrolleyDimension: Double]
    /// Unknown dimensions have no classification weight. Their stored zero is not a claim of absence.
    public let measuredDimensions: Set<TrolleyDimension>
    public let preservationBasis: String
    public let primaryID: String
    public let secondaryID: String?
    public let affinityScores: [String: Double]
    public let titles: [TrolleyTitle]
    public let explanation: String
    public let contextualLine: String

    public func recognizingBreakthrough(saved: Int, previous: TrolleyMaximum?) -> Self {
        guard let previous, previous.isRescueTarget, let target = previous.value, saved > target else { return self }
        var scores = affinityScores; scores["popper"] = 1
        return Self(modelVersion: modelVersion, dimensions: dimensions, measuredDimensions: measuredDimensions,
                    preservationBasis: preservationBasis, primaryID: "popper", secondaryID: primaryID,
                    affinityScores: scores, titles: titles + [.falsifier],
                    explanation: TrolleyAnalyser.archetype("popper").affinityDescription,
                    contextualLine: "Previous record: \(target). New record: \(saved).")
    }
}

/// Range gates establish evidence eligibility. Weighted target distances select among eligible affinities.
public struct TrolleyArchetype: Sendable {
    public let id: String
    public let name: String
    public let philosopher: String?
    public let title: String
    public let interpretation: String
    public let targets: [TrolleyDimension: Double]
    public let weights: [TrolleyDimension: Double]
    public let minimums: [String: Double]
    public let maximums: [String: Double]
    public let achievementHooks: [TrolleyAchievement]
    public init(id: String, name: String, philosopher: String? = nil, title: String, interpretation: String,
                targets: [TrolleyDimension: Double], weights: [TrolleyDimension: Double],
                minimums: [String: Double] = [:], maximums: [String: Double] = [:],
                achievementHooks: [TrolleyAchievement] = []) {
        self.id = id; self.name = name; self.philosopher = philosopher; self.title = title; self.interpretation = interpretation
        self.targets = targets; self.weights = weights; self.minimums = minimums; self.maximums = maximums
        self.achievementHooks = Array(Set(achievementHooks + (TrolleyAchievement.forPhilosopher(id).map { [$0] } ?? []))).sorted { $0.rawValue < $1.rawValue }
    }
}

public enum TrolleyAnalyser {
    public static let version = 1
    public static let archetypes: [TrolleyArchetype] = [
        .init(id: "bentham", name: "Jeremy Bentham", philosopher: "Jeremy Bentham", title: "The Classical Utilitarian",
              interpretation: "Aggregate benefit, with an evidenced trade-off.",
              targets: [.preservation: 0.85, .utility: 0.9, .sacrifice: 0.2], weights: [.preservation: 2, .utility: 3, .sacrifice: 2],
              minimums: ["causalBenefit": 1, "preservation": 0.7]),
        .init(id: "mill", name: "John Stuart Mill", philosopher: "John Stuart Mill", title: "The Humane Utilitarian",
              interpretation: "Consequentialist optimisation with a strong rescue outcome.",
              targets: [.preservation: 1, .utility: 0.8, .duty: 0.85], weights: [.preservation: 4, .utility: 3, .duty: 1],
              minimums: ["preservation": 0.85, "utility": 0.55]),
        .init(id: "kant", name: "Immanuel Kant", philosopher: "Immanuel Kant", title: "The Deontologist",
              interpretation: "A duty-shaped result: individual preservation without destructive assignments.",
              targets: [.duty: 1, .preservation: 1, .intervention: 0.2], weights: [.duty: 5, .preservation: 2, .intervention: 1],
              minimums: ["verifiedPerfect": 1, "skills": 1, "duty": 0.9], maximums: ["destructive": 0, "nukes": 0]),
        .init(id: "singer", name: "Peter Singer", philosopher: "Peter Singer", title: "The Effective Altruist",
              interpretation: "Measurable rescue benefit per scarce resource.",
              targets: [.preservation: 1, .utility: 1], weights: [.preservation: 3, .utility: 6],
              minimums: ["preservation": 0.95, "utility": 0.92, "scarceResourcesKnown": 1]),
        .init(id: "aristotle", name: "Aristotle", philosopher: "Aristotle", title: "The Virtue Ethicist",
              interpretation: "Balanced preservation, resource use and intervention in this solution.",
              targets: [.preservation: 0.9, .utility: 0.75, .duty: 0.75, .intervention: 0.25],
              weights: [.preservation: 3, .utility: 2, .duty: 2, .intervention: 1], minimums: ["preservation": 0.75, "utility": 0.4]),
        .init(id: "epicurus", name: "Epicurus", philosopher: "Epicurus", title: "The Minimal Harm Strategist",
              interpretation: "A strong result with little disturbance.",
              targets: [.preservation: 0.95, .intervention: 0, .utility: 0.85], weights: [.preservation: 2, .intervention: 5, .utility: 1],
              minimums: ["preservation": 0.8], maximums: ["intervention": 0.15, "destructive": 0, "nukes": 0]),
        .init(id: "hobbes", name: "Thomas Hobbes", philosopher: "Thomas Hobbes", title: "The Hard Pragmatist",
              interpretation: "A secured clear amid substantial loss.",
              targets: [.pragmatism: 0.8, .sacrifice: 0.5, .utility: 0.7], weights: [.pragmatism: 3, .sacrifice: 3, .utility: 1],
              minimums: ["passed": 1, "sacrifice": 0.25]),
        .init(id: "sartre", name: "Jean-Paul Sartre", philosopher: "Jean-Paul Sartre", title: "The Existentialist",
              interpretation: "A coherent solution with documented unconventional choices.",
              targets: [.preservation: 0.8, .intervention: 0.6], weights: [.preservation: 2, .intervention: 2],
              minimums: ["unconventional": 1, "preservation": 0.5]),
        .init(id: "absurdist", name: "The Absurdist", title: "An improbable resolution",
              interpretation: "A valid clear through extreme intervention.",
              targets: [.intervention: 1, .pragmatism: 0.5], weights: [.intervention: 5, .pragmatism: 1],
              minimums: ["passed": 1, "extremeIntervention": 1]),
        .init(id: "humanist", name: "The Humanist", title: "Room for everyone",
              interpretation: "Preservation well beyond the formal requirement.",
              targets: [.preservation: 1, .duty: 0.9], weights: [.preservation: 3, .duty: 4],
              minimums: ["preservation": 0.9, "surplusFraction": 0.4, "surplus": 3]),
        .init(id: "bureaucrat", name: "The Bureaucrat", title: "Perfectly adequate",
              interpretation: "The rescue requirement has been satisfied with precision.",
              targets: [.pragmatism: 1], weights: [.pragmatism: 5],
              minimums: ["passed": 1, "roomBeyondRequirement": 2], maximums: ["requirementDistance": 1]),
        .init(id: "trolley_operator", name: "The Trolley Operator", title: "A documented trade-off",
              interpretation: "An evidenced sacrifice enabled a larger rescue.",
              targets: [.utility: 0.85, .preservation: 0.9, .intervention: 0.5], weights: [.utility: 3, .preservation: 2, .intervention: 1],
              minimums: ["causalBenefit": 1, "passed": 1], achievementHooks: [.greaterGood]),
        .init(id: "popper", name: "Karl Popper", philosopher: "Karl Popper", title: "The Falsifier",
              interpretation: "A rescue that disproved the previous estimate.", targets: [:], weights: [:],
              minimums: ["surpassedTarget": 1], achievementHooks: [.falsifier]),
        .init(id: "fellow_traveller", name: "The Fellow Traveller", title: "An unfinished argument",
              interpretation: "A recorded attempt, with room for a different solution.", targets: [:], weights: [:])
    ]
    public static func archetype(_ id: String) -> TrolleyArchetype { archetypes.first { $0.id == id } ?? archetypes.last! }
    private static func unit(_ n: Double) -> Double { max(0, min(1, n)) }

    public static func analyse(run: ArcadeRun, metrics: TrolleyMetrics, maximum: TrolleyMaximum) -> TrolleyPhilosophy {
        let telemetry = run.telemetry!
        let total = Double(max(1, run.level.conditions?.maximumPopulation ?? run.population)), saved = Double(run.saved), skills = Double(run.skillCount)
        // An observed record is a lower bound on feasibility, not proof that a first, low rescue was perfect.
        let preservation = maximum.isRescueTarget ? unit(metrics.rescuePotential ?? 0) : unit(saved / total)
        let sacrifice = maximum.status == .verified ? unit(Double(metrics.avoidableLosses ?? 0) / Double(max(1, maximum.value ?? 1))) : 0
        let benefitPerAction = saved / max(1, saved + skills)
        let utility = preservation * (metrics.scarceResourceFractionUsed.map { 0.6 * benefitPerAction + 0.4 * (1 - $0) } ?? benefitPerAction)
        let destructive = Double(telemetry.destructiveSkillCount)
        let intervention = unit(skills / max(1, saved + skills) + destructive / max(1, skills) * 0.3 + (telemetry.nukeCount > 0 ? 0.4 : 0))
        let surplusFraction = unit(Double(metrics.moralSurplus) / Double(max(1, run.level.total - run.level.required)))
        let duty = preservation * (0.7 + 0.3 * surplusFraction) * (1 - unit(destructive / max(1, skills))) * (telemetry.nukeCount > 0 ? 0.5 : 1)
        let distance = abs(run.saved - run.level.required)
        let pragmatism = run.saved > 0 && run.level.required < run.level.total ? unit(1 - Double(distance) / Double(max(1, run.level.total - run.level.required))) : 0
        let dimensions: [TrolleyDimension: Double] = [.preservation: preservation, .sacrifice: sacrifice, .utility: utility,
                                                       .duty: duty, .pragmatism: pragmatism, .intervention: intervention]
        var measured = Set(TrolleyDimension.allCases)
        if maximum.status != .verified { measured.remove(.sacrifice) }
        var features = Dictionary(uniqueKeysWithValues: dimensions.filter { measured.contains($0.key) }.map { ($0.key.rawValue, $0.value) })
        let causal = telemetry.sacrificeEvidence.map { $0.sacrificed <= metrics.lost && $0.enabledRescues <= run.saved
            && $0.enabledRescues >= max(3, $0.sacrificed * 3) } ?? false
        features.merge(["passed": run.didWin ? 1 : 0, "skills": skills, "destructive": destructive,
                        "nukes": Double(telemetry.nukeCount), "surplus": Double(metrics.moralSurplus), "surplusFraction": surplusFraction,
                        "roomBeyondRequirement": Double(run.level.total - run.level.required), "requirementDistance": Double(distance),
                        "verifiedPerfect": maximum.status == .verified && metrics.avoidableLosses == 0 ? 1 : 0,
                        "scarceResourcesKnown": metrics.scarceResourceFractionUsed != nil ? 1 : 0, "causalBenefit": causal ? 1 : 0,
                        "unconventional": telemetry.unconventionalEvidence?.isEmpty == false ? 1 : 0,
                        "extremeIntervention": (telemetry.nukeCount > 0 && run.skills.count >= 3 && intervention >= 0.6)
                            || (telemetry.rewindCount >= 5 && run.skills.count >= 5) ? 1 : 0], uniquingKeysWith: { _, b in b })
        var scores: [String: Double] = [:]
        for archetype in archetypes {
            let eligible = archetype.minimums.allSatisfy { key, value in features[key].map { $0 >= value } ?? false }
                && archetype.maximums.allSatisfy { key, value in features[key].map { $0 <= value } ?? false }
            guard eligible else { continue }
            if archetype.id == "fellow_traveller" { scores[archetype.id] = 0.01; continue }
            let weights = archetype.weights.filter { measured.contains($0.key) }
            let sum = weights.values.reduce(0, +)
            scores[archetype.id] = sum > 0 ? weights.reduce(0) { result, pair in
                result + pair.value * (1 - abs(dimensions[pair.key, default: 0] - archetype.targets[pair.key, default: 0]))
            } / sum : 0
        }
        let ranked = scores.keys.sorted { scores[$0] == scores[$1] ? $0 < $1 : scores[$0]! > scores[$1]! }
        let primary = ranked.first ?? "fellow_traveller"
        var titles: [TrolleyTitle] = []
        if maximum.status == .verified && metrics.avoidableLosses == 0 { titles.append(.absolutist) }
        if maximum.status == .verified && metrics.avoidableLosses == 1 { titles.append(.lastLemming) }
        if run.didWin, let maximum = maximum.status == .verified ? maximum.value : nil,
           maximum - run.level.required >= 3, run.saved <= run.level.required + 1 { titles.append(.pyrrhicVictor) }
        if causal && run.didWin { titles.append(.trolleyOperator) }
        let explanation = archetype(primary).affinityDescription
        let context: String
        if titles.contains(.lastLemming) { context = "One below the maximum rescue." }
        else if metrics.unavoidableLosses ?? 0 > 0, metrics.avoidableLosses == 0 {
            context = "\(metrics.unavoidableLosses!) " + (metrics.unavoidableLosses == 1 ? "loss was" : "losses were") + " unavoidable. None were avoidable."
        } else if maximum.status == .record { context = "Best-known target: \(maximum.value ?? 0) saved; \(max(0, (maximum.value ?? 0) - run.saved)) below target. The minimum losses are not proved." }
        else if maximum.status == .observed { context = "Maximum rescue unknown." }
        else if maximum.status == .unknown { context = "Maximum rescue unknown." }
        else if metrics.unreleased > 0 { context = "\(metrics.unreleased) were never released. Lost counts only those released." }
        else { context = "\(metrics.lost) lost; \(metrics.avoidableLosses ?? 0) below the verified maximum." }
        return TrolleyPhilosophy(modelVersion: version, dimensions: dimensions, measuredDimensions: measured,
            preservationBasis: maximum.status == .verified ? "verified-maximum" : maximum.status == .record ? "best-known-record" : "population-lower-bound",
            primaryID: primary, secondaryID: ranked.dropFirst().first.flatMap { $0 == "fellow_traveller" ? nil : $0 },
            affinityScores: scores, titles: titles, explanation: explanation, contextualLine: context)
    }
}
