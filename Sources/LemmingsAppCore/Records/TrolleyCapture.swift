import Foundation
import NxlvKit

/// Translates engine observations into records without participating in simulation or campaign decisions.
/// The Mac adds the session observations in `TrolleyCapture+Session.swift`.
@MainActor public enum TrolleyCapture {
    nonisolated public static func classicFingerprint(_ simulation: ClassicDOSSimulation) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var bytes = Data(ClassicDOSReplayRecorder.stateHash(of: simulation).utf8)
        bytes.append((try? encoder.encode(simulation.configuration.entrances)) ?? Data())
        bytes.append((try? encoder.encode(simulation.configuration.triggers)) ?? Data())
        bytes.append((try? encoder.encode(simulation.comparisonDestructionMasks)) ?? Data())
        return ArcadeStore.fingerprint(bytes)
    }
    public static var buildVersion: String { buildVersion(storage: .current()) }
    public static func buildVersion(storage: AppStorage) -> String {
        let version = storage.bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        let build = storage.bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "local"
        return "\(version) (\(build))"
    }
    public static func skillKey(_ name: String) -> String { name.lowercased().replacingOccurrences(of: " ", with: "_") }
    public static func destructiveCount(_ skills: [String: Int]) -> Int {
        let destructive: Set<String> = ["bomber", "basher", "miner", "digger", "stoner", "fencer", "laserer", "batter",
            "exploder", "scooper", "stomper", "club_basher", "laser_blaster", "flame_thrower", "bazooka", "mortar",
            "thrower", "spearer", "archer", "bomb", "grenade", "spade", "hadoken"]
        return skills.reduce(0) { $0 + (destructive.contains(skillKey($1.key)) ? $1.value : 0) }
    }
}
