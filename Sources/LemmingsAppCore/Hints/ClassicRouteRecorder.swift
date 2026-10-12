import Foundation
import CryptoKit
import NxlvKit

/// Preserves completed player inputs for replay verification, including fan levels.
/// The Mac records a finished session in `ClassicRouteRecorder+Session.swift`.
public enum ClassicRouteRecorder {
    private static let queue = DispatchQueue(label: "academy.glasscode.lemmings.classic-routes", qos: .utility)
    public static var folder: URL { folder(storage: .current()) }
    public static func folder(storage: AppStorage) -> URL {
        if storage.isIntegrationTestBuild {
            return FileManager.default.temporaryDirectory.appendingPathComponent("LemmingsIntegrationClassicRoutes")
        }
        return storage.applicationSupport.appendingPathComponent("ClassicRoutes", isDirectory: true)
    }

    /// Saves a verified winning route in the background. Errors go to `onError` on the main actor.
    public static func record(_ replay: ClassicDOSReplay, initial: ClassicDOSSimulation, conditions: TrolleyConditions?,
                              folder destination: URL = folder, onError: @escaping @MainActor @Sendable (String) -> Void) {
        queue.async {
            do { _ = try save(replay, initial: initial, conditions: conditions, folder: destination) }
            catch { let message = error.localizedDescription; Task { @MainActor in onError(message) } }
        }
    }

    @discardableResult
    public static func save(_ replay: ClassicDOSReplay, initial: ClassicDOSSimulation,
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

    public static func flush() { queue.sync {} }
}
