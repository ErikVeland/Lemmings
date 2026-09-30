import Foundation

/// The replay player's observer exposes existing events without duplicating DOS input timing.
public enum ClassicDifficultyAnalysis {
    public static func analyse(initial: ClassicDOSSimulation, replay: ClassicDOSReplay,
                               key: DifficultyCacheKey,
                               maximumProbeRuns: Int = DifficultyModel.maximumProbeRuns) throws -> DifficultyProfile {
        guard replay.expected?.didWin == true else { throw DifficultyAnalysisError.replayDidNotWin }
        let tickLimit = max(ClassicDOSReplayPlayer.defaultTickLimit,
            initial.configuration.timeLimitTicks ?? 0,
            (replay.expected?.ticks ?? 0) + ClassicDOSRules.ticksPerSecond)
        var evidence = DifficultySolutionEvidence()
        var assigned: Set<Int> = []
        var previousRate = initial.releaseRate
        var previousObservedTick = initial.tickCount
        var successfulInputs: Set<Int> = []
        let outcome = try ClassicDOSReplayPlayer.run(replay, simulation: initial, tickLimit: tickLimit) { simulation in
            try Task.checkCancellation()
            // The player observes the tick, then each live input at that tick.
            let afterTick = simulation.tickCount == previousObservedTick
            previousObservedTick = simulation.tickCount
            // Legacy rate inputs run before tick(), which replaces lastTickEvents.
            if simulation.releaseRate != previousRate {
                evidence.observedConcepts.insert("release-rate-manipulation")
                previousRate = simulation.releaseRate
            }
            for event in simulation.lastTickEvents {
                switch event {
                case let .skillAssigned(id, skill):
                    if let input = replay.events.enumerated().first(where: {
                        !successfulInputs.contains($0.offset) && $0.element.tick == simulation.tickCount
                            && ($0.element.afterTick == true) == afterTick
                            && $0.element.action == .assign(lemmingID: id, skill: skill)
                    }) { successfulInputs.insert(input.offset) }
                    let worker = simulation.lemmings.first { $0.id == id }
                    evidence.assignments.append(.init(frame: simulation.tickCount, worker: id, skill: skill.rawValue,
                        x: worker?.foot.x ?? 0, y: worker?.foot.y ?? 0))
                    assigned.insert(id)
                case .releaseRateChanged: evidence.observedConcepts.insert("release-rate-manipulation")
                case .actionChanged: evidence.meaningfulTransitions += 1
                default: break
                }
            }
            let workers = simulation.lemmings.filter {
                assigned.contains($0.id) && ["building", "bashing", "mining", "digging"].contains($0.action.rawValue)
            }
            let regions = DifficultyWorkerRegions.count(workers.map { ($0.foot.x, $0.foot.y) })
            evidence.maximumConcurrentWorkers = max(workers.count, evidence.maximumConcurrentWorkers)
            evidence.maximumConcurrentRegions = max(regions, evidence.maximumConcurrentRegions)
            if regions > 1 { evidence.observedConcepts.insert("multiple-worker-coordination") }
            evidence.duration = simulation.tickCount; evidence.saved = simulation.savedCount
            evidence.remainingTime = simulation.remainingTimeTicks
            evidence.remainingSkills = Dictionary(uniqueKeysWithValues: simulation.skills.map { ($0.key.rawValue, $0.value) })
        }
        guard outcome.didWin else { throw DifficultyAnalysisError.replayDidNotWin }
        let assignments = replay.events.enumerated().compactMap { index, event -> NeoLemmixReplayCommand? in
            guard successfulInputs.contains(index), case let .assign(id, skill) = event.action,
                  let nativeSkill = NeoLemmixSkill(rawValue: skill.rawValue) else { return nil }
            // Failed legacy inputs and commands after completion cannot consume
            // the timing budget or dilute the measured execution burden.
            return .init(tick: event.tick, sequence: UInt64(index), command: .assign(lemmingID: id, skill: nativeSkill))
        }
        let precision = try DifficultyPerturbation.analyse(commands: assignments, maximumRuns: maximumProbeRuns) { commands in
            let frames = Dictionary(uniqueKeysWithValues: commands.map { (Int($0.sequence), $0.tick) })
            let events = replay.events.enumerated().map { index, event in
                ClassicDOSReplayEvent(tick: frames[index] ?? event.tick, action: event.action, afterTick: event.afterTick)
            }
            let variant = ClassicDOSReplay(rank: replay.rank, number: replay.number, title: replay.title,
                initialStateHash: replay.initialStateHash, events: events)
            do {
                return try ClassicDOSReplayPlayer.run(variant, simulation: initial,
                    tickLimit: tickLimit, verify: false) { _ in
                    try Task.checkCancellation()
                }.didWin
            } catch ClassicDOSReplayError.commandRejected { return false }
            catch ClassicDOSReplayError.tickLimitReached { return nil }
        }
        let config = initial.configuration
        let metadata = DifficultyMetadataEvidence(
            availableSkills: Dictionary(uniqueKeysWithValues: config.initialSkills.map { ($0.key.rawValue, $0.value) }),
            population: config.totalLemmings, rescueRequirement: config.requiredToSave,
            timeLimitFrames: config.timeLimitTicks, interactingSystems: Set(config.triggers.map(\.effect)).count,
            rank: replay.rank)
        return DifficultyScorer.analyse(key: key, metadata: metadata, solution: evidence, precision: precision, exactReplay: true)
    }
}
