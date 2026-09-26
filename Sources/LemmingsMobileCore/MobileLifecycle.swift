import Foundation

public enum MobileCheckpointReason: String, Codable, Equatable, Sendable {
    case suspension
    case audioInterruption
    case memoryPressure
    case sceneDisconnect
    case periodic
}

public enum MobileLifecycleEvent: Equatable, Sendable {
    case becameInactive
    case enteredBackground
    case becameActive
    case audioInterruptionBegan
    case audioInterruptionEnded
    case memoryWarning
    case sceneDisconnected
    case playerRequestedResume
}

public enum MobileLifecycleEffect: Equatable, Sendable {
    case pauseSimulation
    case resumeSimulation
    case cancelInput
    case saveCheckpoint(MobileCheckpointReason)
    case suspendAudio
    case prepareAudio
    case resumeAudio
    case showResumeControl
    case purgeTransientResources
}

public struct MobileLifecycleState: Equatable, Sendable {
    public private(set) var isForeground = true
    public private(set) var isInterrupted = false
    public private(set) var isPaused = false
    public private(set) var requiresPlayerResume = false
    private var checkpointedForSuspension = false

    public init() {}

    /// Returns work for adapters. The reducer never resumes play by itself.
    public mutating func handle(_ event: MobileLifecycleEvent) -> [MobileLifecycleEffect] {
        switch event {
        case .becameInactive:
            isForeground = false
            requiresPlayerResume = true
            let firstPause = !isPaused
            isPaused = true
            var effects: [MobileLifecycleEffect] = [.cancelInput]
            if firstPause { effects.append(.pauseSimulation) }
            if !checkpointedForSuspension {
                checkpointedForSuspension = true
                effects.append(.saveCheckpoint(.suspension))
            }
            effects.append(.suspendAudio)
            return effects

        case .enteredBackground:
            isForeground = false
            requiresPlayerResume = true
            isPaused = true
            if checkpointedForSuspension { return [.suspendAudio] }
            checkpointedForSuspension = true
            return [.cancelInput, .pauseSimulation, .saveCheckpoint(.suspension), .suspendAudio]

        case .becameActive:
            isForeground = true
            checkpointedForSuspension = false
            guard requiresPlayerResume || isInterrupted else { return [.prepareAudio] }
            return [.prepareAudio, .showResumeControl]

        case .audioInterruptionBegan:
            let firstInterruption = !isInterrupted
            isInterrupted = true
            requiresPlayerResume = true
            let firstPause = !isPaused
            isPaused = true
            var effects: [MobileLifecycleEffect] = [.cancelInput]
            if firstPause { effects.append(.pauseSimulation) }
            if firstInterruption { effects.append(.saveCheckpoint(.audioInterruption)) }
            effects.append(.suspendAudio)
            return effects

        case .audioInterruptionEnded:
            isInterrupted = false
            guard isForeground else { return [] }
            return [.prepareAudio, .showResumeControl]

        case .memoryWarning:
            return [.saveCheckpoint(.memoryPressure), .purgeTransientResources]

        case .sceneDisconnected:
            isForeground = false
            requiresPlayerResume = true
            isPaused = true
            return [.cancelInput, .pauseSimulation, .saveCheckpoint(.sceneDisconnect), .suspendAudio]

        case .playerRequestedResume:
            guard isForeground, !isInterrupted, requiresPlayerResume else { return [] }
            requiresPlayerResume = false
            isPaused = false
            return [.resumeSimulation, .resumeAudio]
        }
    }
}
