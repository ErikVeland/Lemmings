import Foundation

public struct DifficultyAssignment: Codable, Equatable, Sendable {
    public let frame: Int
    public let worker: Int
    public let skill: String
    public let x: Int
    public let y: Int
    public init(frame: Int, worker: Int, skill: String, x: Int = 0, y: Int = 0) {
        self.frame = frame; self.worker = worker; self.skill = skill; self.x = x; self.y = y
    }
}

/// Direct observations from a validated successful replay. Absence is not proof of impossibility.
public struct DifficultySolutionEvidence: Sendable {
    public var assignments: [DifficultyAssignment] = []
    public var observedConcepts: Set<String> = []
    public var meaningfulTransitions = 0
    public var maximumConcurrentWorkers = 0
    public var maximumConcurrentRegions = 0
    public var duration = 0
    public var saved = 0
    public var remainingTime: Int?
    public var remainingSkills: [String: Int] = [:]
    public init() {}
}

public struct DifficultyTechniqueDefinition: Sendable {
    public let id: String
    public let sophistication: Double
    public let prerequisites: [String]
    public let evidenceRequirement: String
}

public enum DifficultyTechniques {
    public static let definitions: [DifficultyTechniqueDefinition] =
        NeoLemmixSkill.allCases.map {
            DifficultyTechniqueDefinition(id: $0.rawValue, sophistication: 1, prerequisites: [],
                evidenceRequirement: "Successful assignment in a winning replay. This proves use, not necessity.")
        } + [
            .init(id: "skill-cancellation", sophistication: 3, prerequisites: [],
                  evidenceRequirement: "Assignment changes a worker from an active skill to another action."),
            .init(id: "blocker-turnaround", sophistication: 3, prerequisites: ["blocker"],
                  evidenceRequirement: "A walking lemming reverses within an active blocker's field."),
            .init(id: "multiple-worker-coordination", sophistication: 3, prerequisites: [],
                  evidenceRequirement: "Two assigned workers execute skills in the same simulation frame."),
            .init(id: "release-rate-manipulation", sophistication: 2, prerequisites: [],
                  evidenceRequirement: "Simulation reports a spawn interval change."),
            .init(id: "pickup-skill-interaction", sophistication: 2, prerequisites: [],
                  evidenceRequirement: "Simulation reports skill pickup; dependency is not inferred."),
            .init(id: "button-interaction", sophistication: 2, prerequisites: [],
                  evidenceRequirement: "Simulation reports a pressed unlock button."),
            .init(id: "trap-disarming", sophistication: 2, prerequisites: ["disarmer"],
                  evidenceRequirement: "Simulation reports a disarmed trap."),
            .init(id: "teleporter-interaction", sophistication: 2, prerequisites: [],
                  evidenceRequirement: "An assigned or unassigned lemming enters teleporting state.")
        ]
    public static func detect(_ evidence: DifficultySolutionEvidence) -> [String] {
        let used = Set(evidence.assignments.map(\.skill)).union(evidence.observedConcepts)
        return definitions.filter { used.contains($0.id) }.map(\.id).sorted()
    }
    public static func burden(_ concepts: [String]) -> Double {
        let selected = definitions.filter { concepts.contains($0.id) }
        let advanced = selected.filter { $0.sophistication > 1 }
        return (selected.reduce(0) { $0 + $1.sophistication * DifficultyCalibration.basicTechnique }
                + Double(max(0, advanced.count - 1)) * DifficultyCalibration.advancedCombination).clampedDifficulty
    }
}

public struct DifficultyMetadataEvidence: Sendable {
    public var availableSkills: [String: Int]
    public var population: Int
    public var rescueRequirement: Int
    public var timeLimitFrames: Int?
    public var interactingSystems: Int
    public var rank: String?
    /// Optional normalised calibration from an authoritative pack adapter. Never inferred from rank names.
    public var rankCalibration: Double?
    public init(availableSkills: [String: Int] = [:], population: Int = 0, rescueRequirement: Int = 0,
                timeLimitFrames: Int? = nil, interactingSystems: Int = 0, rank: String? = nil,
                rankCalibration: Double? = nil) {
        self.availableSkills = availableSkills; self.population = population
        self.rescueRequirement = rescueRequirement; self.timeLimitFrames = timeLimitFrames
        self.interactingSystems = interactingSystems; self.rank = rank; self.rankCalibration = rankCalibration
    }
    public init(level: NxlvLevel) {
        self.init(availableSkills: level.skillset, population: level.lemmingsCount,
                  rescueRequirement: level.saveRequirement,
                  interactingSystems: Set(level.gadgets.compactMap(\.piece)).count)
    }
}

public enum DifficultyScorer {
    public static func analyse(key: DifficultyCacheKey, metadata: DifficultyMetadataEvidence,
                               solution: DifficultySolutionEvidence? = nil,
                               precision: DifficultyPrecisionEvidence? = nil,
                               exactReplay: Bool = false) -> DifficultyProfile {
        let rescuePressure = metadata.population > 0
            ? Double(metadata.rescueRequirement) / Double(metadata.population) : 0
        guard let solution else {
            // A broad prior. Available skills are possibilities, never detected requirements.
            let choice = Double(metadata.availableSkills.values.filter { $0 != 0 }.count)
            let components = DifficultyComponents(
                techniqueBurden: min(DifficultyCalibration.priorTechniqueCeiling, choice * DifficultyCalibration.priorSkillChoice),
                solutionComplexity: Double(min(4, metadata.interactingSystems)) * DifficultyCalibration.interactingSystem,
                constraintPressure: rescuePressure * DifficultyCalibration.priorRescuePressure,
                deductionComplexityProxy: min(DifficultyCalibration.priorDeductionCeiling, choice * DifficultyCalibration.priorDeductionChoice + Double(metadata.interactingSystems) * DifficultyCalibration.priorDeductionSystem)
                    + (metadata.rankCalibration?.clampedDifficulty ?? 0) * DifficultyCalibration.metadataCalibrationWeight)
            return DifficultyProfile(key: key, confidence: .low, components: components,
                explanation: ["Estimate from resources and object structure; no validated solution.",
                              "Precision, required techniques and human deduction are unknown."]
                    + (metadata.rank.map { ["Source rank: \($0)."] } ?? []), sourceRank: metadata.rank)
        }
        let assignments = solution.assignments.sorted { $0.frame < $1.frame }
        let concepts = DifficultyTechniques.detect(solution)
        let workers = Set(assignments.map(\.worker)).count
        let skills = Set(assignments.map(\.skill)).count
        let workerChains = Dictionary(grouping: assignments, by: \.worker).values.map { actions -> String in
            var chain: [String] = []
            for action in actions where chain.last != action.skill { chain.append(action.skill) }
            return chain.joined(separator: "/")
        }
        let independentWorkers = max(Set(workerChains).count, solution.maximumConcurrentRegions)
        var lastSkill: [Int: String] = [:]
        var dependentChanges = 0
        var regionSwitches = 0
        for (index, action) in assignments.enumerated() {
            if let previous = lastSkill[action.worker], previous != action.skill { dependentChanges += 1 }
            lastSkill[action.worker] = action.skill
            if index > 0 {
                let previous = assignments[index - 1]
                if previous.worker != action.worker,
                   action.frame - previous.frame <= DifficultyModel.nearbyActionFrames,
                   abs(previous.x - action.x) + abs(previous.y - action.y) >= DifficultyModel.regionDistance {
                    regionSwitches += 1
                }
            }
        }
        let usedSkills = Set(assignments.map(\.skill))
        let resourcePressure = usedSkills.isEmpty ? 0 : usedSkills.sorted().reduce(0.0) { total, skill in
            guard let remaining = solution.remainingSkills[skill], remaining >= 0 else { return total }
            return total + 1 / Double(remaining + 1)
        } / Double(max(1, usedSkills.count))
        let timePressure: Double
        if let limit = metadata.timeLimitFrames, limit > 0, let remaining = solution.remainingTime {
            timePressure = max(0, 1 - Double(remaining) / Double(limit))
        } else { timePressure = 0 }
        let components = DifficultyComponents(
            techniqueBurden: DifficultyTechniques.burden(concepts),
            solutionComplexity: Double(skills) * DifficultyCalibration.distinctSkill + Double(dependentChanges) * DifficultyCalibration.dependentSkillChange
                + Double(max(0, independentWorkers - 1)) * DifficultyCalibration.additionalWorker + log2(Double(assignments.count) + 1) * DifficultyCalibration.logarithmicRepetition,
            executionPrecision: precision?.burden ?? 0,
            concurrencyBurden: Double(max(0, solution.maximumConcurrentRegions - 1)) * DifficultyCalibration.concurrentWorker
                + Double(regionSwitches) * DifficultyCalibration.rapidRegionSwitch,
            constraintPressure: resourcePressure * DifficultyCalibration.depletedResources + rescuePressure * DifficultyCalibration.rescuePressure + timePressure * DifficultyCalibration.timePressure,
            deductionComplexityProxy: Double(dependentChanges) * DifficultyCalibration.deductionDependency
                + Double(max(0, metadata.availableSkills.values.filter { $0 != 0 }.count - skills)) * DifficultyCalibration.unusedSkillChoice
                + Double(metadata.interactingSystems) * DifficultyCalibration.interactingSystem)
        let confidence: DifficultyConfidence = exactReplay && precision?.completed == true ? .high : .medium
        return DifficultyProfile(key: key, confidence: confidence, components: components,
            detectedTechniques: concepts,
            prerequisiteConcepts: DifficultyTechniques.definitions.filter { concepts.contains($0.id) }.flatMap(\.prerequisites),
            precision: precision,
            explanation: ["\(skills) used skill types; \(workers) assigned workers; \(dependentChanges) same-worker skill changes.",
                          "Maximum concurrent worker regions: \(solution.maximumConcurrentRegions).",
                          "Timing probes: \(precision?.runCount ?? 0). Untested alternatives remain unknown.",
                          "Deduction is a conservative proxy. Observed techniques are not proof of necessity."]
                + (metadata.rank.map { ["Source rank: \($0)."] } ?? []), sourceRank: metadata.rank)
    }
}

/// Spatially connected workers form one situation, not one situation per click.
/// This is a conservative concurrency proxy, not a causal crowd dependency graph.
public enum DifficultyWorkerRegions {
    public static func count(_ positions: [(Int, Int)]) -> Int {
        var remaining = Array(positions.indices)
        var regions = 0
        while let seed = remaining.popLast() {
            regions += 1
            var frontier = [seed]
            while let current = frontier.popLast() {
                let connected = remaining.filter { index in
                    abs(positions[current].0 - positions[index].0)
                        + abs(positions[current].1 - positions[index].1) <= DifficultyModel.regionDistance
                }
                let found = Set(connected)
                remaining.removeAll { found.contains($0) }
                frontier.append(contentsOf: connected)
            }
        }
        return regions
    }
}
