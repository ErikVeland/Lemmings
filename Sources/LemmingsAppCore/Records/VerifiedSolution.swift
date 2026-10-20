import CryptoKit
import Foundation
import NxlvKit

/// A solution is usable only after the current engine reproduces its winning outcome.
public struct VerifiedSolution: Sendable {
    public let replay: ClassicDOSReplay
    public let initial: ClassicDOSSimulation

    public static func load(initial: ClassicDOSSimulation, from root: URL?) -> Self? {
        guard let root else { return nil }
        let hash = ClassicDOSReplayRecorder.stateHash(of: initial)
        let candidates = ["Hints/solutions.json", "Progression/solutions.json"].compactMap { path -> ClassicDOSReplay? in
            guard let data = try? Data(contentsOf: root.appendingPathComponent(path)),
                  let records = try? JSONDecoder().decode([String: ClassicDOSReplay].self, from: data) else { return nil }
            return records[hash]
        }.sorted { ($0.expected?.saved ?? -1) > ($1.expected?.saved ?? -1) }
        for replay in candidates {
            if let result = validate(replay, initial: initial) { return result }
        }
        return nil
    }

    public func rescueTarget(buildVersion: String) -> TrolleyMaximum? {
        guard let outcome = replay.expected, outcome.didWin else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let bytes = try? encoder.encode(replay) else { return nil }
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let full = outcome.saved == initial.configuration.totalLemmings
        return TrolleyMaximum(value: outcome.saved, status: full ? .verified : .record,
            source: (full ? TrolleyProofCatalogue.sourcePrefix : TrolleyProofCatalogue.recordPrefix) + digest,
            date: Date(), buildVersion: buildVersion)
    }

    public static func validate(_ replay: ClassicDOSReplay, initial: ClassicDOSSimulation) -> Self? {
        guard let expected = replay.expected, expected.didWin,
              expected.ticks > 0,
              !initial.bonusSkillUsed,
              !replay.events.contains(where: { if case .bonusSkill = $0.action { return true }; return false }),
              replay.events.allSatisfy({ $0.tick >= ($0.afterTick == true ? 0 : 1) && $0.tick <= expected.ticks }),
              let outcome = try? ClassicDOSReplayPlayer.run(replay, simulation: initial,
                  tickLimit: max(ClassicDOSReplayPlayer.defaultTickLimit,
                      initial.configuration.timeLimitTicks ?? 0,
                      expected.ticks + ClassicDOSRules.ticksPerSecond)),
              outcome == expected, outcome.didWin else { return nil }
        return Self(replay: replay, initial: initial)
    }
}
