import Foundation

public enum DifficultyAnalysisError: Error { case frameBudgetExceeded, replayDidNotWin, invalidReplayCommands }

/// Uses the existing source replay adapter, including stable target identifiers and CE ordering.
public enum NeoLemmixDifficultyAnalysis {
    public static func analyse(level: NxlvLevel, rendered: NxlvRenderedLevel, replay: NxrpReplay,
                               key: DifficultyCacheKey,
                               maximumProbeRuns: Int = DifficultyModel.maximumProbeRuns) throws -> DifficultyProfile {
        try replay.verifyLevelIdentity(level)
        var playback: NxrpReplayPlayback
        let exact = replay.recordedCheckIssues().isEmpty
        if exact {
            playback = try NxrpReplayPlayback(replay: replay, level: level, renderedLevel: rendered)
        } else {
            playback = try NxrpReplayPlayback(sourceCompatibleReplay: withoutCompletion(replay), level: level, renderedLevel: rendered)
        }
        let sourceCutoff = min(DifficultyModel.maximumFrames,
            min(DifficultyModel.maximumFrames, max(replay.commands.map(\.tick).max() ?? 0, replay.metadata.expectedCompletionFrame ?? 0)) + 5 * 60 * 17)
        var evidence = DifficultySolutionEvidence()
        var assignedWorkers: Set<Int> = []
        var alternatives: [(UInt64, Int)] = []
        while playback.simulation.savedCount < level.saveRequirement {
            try Task.checkCancellation()
            guard playback.simulation.tickCount < sourceCutoff else { throw DifficultyAnalysisError.frameBudgetExceeded }
            guard !playback.simulation.isComplete else { throw DifficultyAnalysisError.replayDidNotWin }
            let before = playback.simulation
            let events = try playback.step()
            for event in events {
                switch event {
                case let .assignment(.assigned(id, skill)):
                    let worker = before.lemmings.first { $0.id == id }
                    evidence.assignments.append(.init(frame: before.tickCount, worker: id, skill: skill.rawValue,
                                                      x: worker?.position.x ?? 0, y: worker?.position.y ?? 0))
                    assignedWorkers.insert(id)
                    if let worker {
                        let sequence = replay.commands.first {
                            $0.tick == before.tickCount && $0.command == .assign(lemmingID: id, skill: skill)
                        }?.sequence
                        if let sequence {
                            let nearby = before.lemmings.filter {
                                $0.id != id && $0.isActive
                                && abs($0.position.x - worker.position.x) + abs($0.position.y - worker.position.y) <= 12
                            }.sorted { $0.id < $1.id }
                            for other in nearby.prefix(2) {
                                var eligibility = before
                                if eligibility.assign(skill: skill, to: other.id).wasAssigned { alternatives.append((sequence, other.id)) }
                            }
                        }
                    }
                    if let worker, isWorking(worker.action), worker.action != playback.simulation.lemmings.first(where: { $0.id == id })?.action {
                        evidence.observedConcepts.insert("skill-cancellation")
                    }
                case .actionChanged:
                    evidence.meaningfulTransitions += 1
                case .spawnIntervalChanged: evidence.observedConcepts.insert("release-rate-manipulation")
                case .skillPickedUp: evidence.observedConcepts.insert("pickup-skill-interaction")
                case .buttonPressed: evidence.observedConcepts.insert("button-interaction")
                case .zoneDisarmed: evidence.observedConcepts.insert("trap-disarming")
                default: break
                }
            }
            let active = playback.simulation.lemmings.filter { assignedWorkers.contains($0.id) && isWorking($0.action) }
            let regions = DifficultyWorkerRegions.count(active.map { ($0.position.x, $0.position.y) })
            evidence.maximumConcurrentWorkers = max(evidence.maximumConcurrentWorkers, active.count)
            evidence.maximumConcurrentRegions = max(evidence.maximumConcurrentRegions, regions)
            if regions > 1 { evidence.observedConcepts.insert("multiple-worker-coordination") }
            if playback.simulation.lemmings.contains(where: { $0.teleportTicksRemaining != nil }) {
                evidence.observedConcepts.insert("teleporter-interaction")
            }
        }
        evidence.duration = playback.simulation.tickCount
        evidence.saved = playback.simulation.savedCount
        evidence.remainingTime = playback.simulation.remainingTimeTicks
        evidence.remainingSkills = Dictionary(uniqueKeysWithValues: playback.simulation.skills.map { ($0.key.rawValue, $0.value.availableCount ?? -1) })
        func succeeds(_ variant: NxrpReplay) throws -> Bool? {
            var runner = try NxrpReplayPlayback(sourceCompatibleReplay: variant, level: level, renderedLevel: rendered)
            while runner.simulation.savedCount < level.saveRequirement && !runner.simulation.isComplete {
                try Task.checkCancellation()
                guard runner.simulation.tickCount < sourceCutoff + 16 else { return nil }
                do { try runner.step() } catch NxrpReplayPlaybackError.missingLemming { return false }
            }
            return runner.simulation.savedCount >= level.saveRequirement
        }
        let timingBudget = alternatives.isEmpty ? maximumProbeRuns : maximumProbeRuns * 4 / 5
        var precision = try DifficultyPerturbation.analyse(commands: replay.commands, maximumRuns: timingBudget) { commands in
            try succeeds(withoutCompletion(replay, commands: commands))
        }
        var remainingBudget = max(0, maximumProbeRuns - precision.runCount)
        for (sequence, target) in alternatives where remainingBudget > 0 {
            try Task.checkCancellation()
            let commands = replay.commands.map { item -> NeoLemmixReplayCommand in
                guard item.sequence == sequence, case let .assign(_, skill) = item.command else { return item }
                return .init(tick: item.tick, sequence: sequence, command: .assign(lemmingID: target, skill: skill))
            }
            let checks = replay.commandEvidence.map { evidence -> NxrpCommandEvidence in
                guard case let .assignment(index, _, x, y, direction, highlighted) = evidence, index == sequence else { return evidence }
                return .assignment(sequence: sequence, lemmingIdentifier: nil, x: x, y: y, direction: direction, highlighted: highlighted)
            }
            let variant = withoutCompletion(NxrpReplay(metadata: replay.metadata, commands: commands, commandEvidence: checks))
            precision.selectionOutcomes[sequence, default: [:]][target] = try succeeds(variant)
            remainingBudget -= 1
            precision.alternativeRunCount += 1
        }
        var metadata = DifficultyMetadataEvidence(level: level)
        metadata.timeLimitFrames = playback.simulation.configuration.timeLimitTicks
        return DifficultyScorer.analyse(key: key, metadata: metadata, solution: evidence,
                                         precision: precision, exactReplay: exact)
    }

    private static func isWorking(_ action: NeoLemmixAction) -> Bool {
        ["building", "platforming", "stacking", "bashing", "mining", "digging", "fencing", "lasering", "shimmying"].contains(action.rawValue)
    }

    /// Perturbations must be free to finish earlier or later than the reference replay.
    /// Source state repair fields stay intact. Production replay validation is unchanged.
    private static func withoutCompletion(_ replay: NxrpReplay, commands: [NeoLemmixReplayCommand]? = nil) -> NxrpReplay {
        let metadata = replay.metadata
        return NxrpReplay(metadata: NxrpMetadata(user: metadata.user, title: metadata.title, author: metadata.author,
            game: metadata.game, group: metadata.group, levelPosition: metadata.levelPosition,
            levelID: metadata.levelID, levelVersion: metadata.levelVersion),
            commands: commands ?? replay.commands, commandEvidence: replay.commandEvidence)
    }
}
