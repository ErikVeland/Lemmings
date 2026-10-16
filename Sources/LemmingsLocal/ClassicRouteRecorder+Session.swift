#if os(macOS)
import Foundation
import LemmingsAppCore
import NxlvKit

extension ClassicRouteRecorder {
    @MainActor static func record(session: ClassicSession, level: ArcadeLevel, title: String, rank: String, number: Int,
                                  onError: @escaping @MainActor @Sendable (String) -> Void) {
        guard session.isComplete, session.didWin else { return }
        let final = session.simulation
        let replay = ClassicDOSReplay(rank: rank, number: number, title: title,
            initialStateHash: session.initialStateHash,
            initialLevelFingerprint: session.initialSimulation.levelSourceFingerprint,
            events: session.recoveryEvents,
            expected: .init(ticks: final.tickCount, released: final.releasedCount, saved: final.savedCount,
                required: final.configuration.requiredToSave, didWin: final.didWin,
                stateHash: ClassicDOSReplayRecorder.stateHash(of: final)))
        let initial = session.initialSimulation
        let destination = folder
        record(replay, initial: initial, conditions: level.conditions, folder: destination, onError: onError)
    }
}
#endif
