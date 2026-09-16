import Foundation
import CryptoKit
import NxlvKit

/// Preserves completed player inputs for replay verification, including fan levels.
enum ClassicRouteRecorder {
    private static let queue = DispatchQueue(label: "academy.glasscode.lemmings.classic-routes", qos: .utility)
    static var folder: URL {
        if Bundle.main.bundleIdentifier?.contains("integration-tests") == true {
            return FileManager.default.temporaryDirectory.appendingPathComponent("LemmingsIntegrationClassicRoutes")
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ultimate Lemmings/ClassicRoutes", isDirectory: true)
    }

    @MainActor static func record(session: ClassicSession, level: ArcadeLevel, title: String, rank: String, number: Int,
                                  onError: @escaping @MainActor @Sendable (String) -> Void) {
        guard session.isComplete, session.didWin else { return }
        let final = session.simulation
        let replay = ClassicDOSReplay(rank: rank, number: number, title: title,
            initialStateHash: session.initialStateHash, events: session.recoveryEvents,
            expected: .init(ticks: final.tickCount, released: final.releasedCount, saved: final.savedCount,
                required: final.configuration.requiredToSave, didWin: final.didWin,
                stateHash: ClassicDOSReplayRecorder.stateHash(of: final)))
        let initial = session.initialSimulation
        let destination = folder
        queue.async {
            do { _ = try save(replay, initial: initial, conditions: level.conditions, folder: destination) }
            catch { let message = error.localizedDescription; Task { @MainActor in onError(message) } }
        }
    }

    @discardableResult
    static func save(_ replay: ClassicDOSReplay, initial: ClassicDOSSimulation,
                     conditions: TrolleyConditions?, folder: URL) throws -> URL {
        guard replay.events.allSatisfy({ $0.afterTick == true }),
              VerifiedSolution.validate(replay, initial: initial) != nil else { throw RunRecoveryError.invalid }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var object = try JSONSerialization.jsonObject(with: encoder.encode(replay)) as! [String: Any]
        if let conditions { object["conditions"] = try JSONSerialization.jsonObject(with: encoder.encode(conditions)) }
        object["engineFingerprint"] = RunRecovery.bundledEngine
        let bytes = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let path = folder.appendingPathComponent(digest + ".json")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: path.path) {
            guard try Data(contentsOf: path) == bytes else { throw RunRecoveryError.changed }
        } else {
            let temporary = folder.appendingPathComponent(".route-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: temporary) }
            try bytes.write(to: temporary, options: .withoutOverwriting)
            do { try FileManager.default.linkItem(at: temporary, to: path) }
            catch {
                guard (try? Data(contentsOf: path)) == bytes else { throw error }
            }
        }
        return path
    }

    static func flush() { queue.sync {} }
}
