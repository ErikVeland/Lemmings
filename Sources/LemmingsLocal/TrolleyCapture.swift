import Foundation
import CryptoKit
import NxlvKit

/// Translates engine observations into records without participating in simulation or campaign decisions.
@MainActor enum TrolleyCapture {
    static var buildVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "local"
        return "\(version) (\(build))"
    }
    static func skillKey(_ name: String) -> String { name.lowercased().replacingOccurrences(of: " ", with: "_") }
    static func skills(_ skills: [SessionSkill]) -> [String: Int] {
        Dictionary(skills.map { (skillKey($0.name), $0.isInfinite ? -1 : $0.count) }, uniquingKeysWith: +)
    }
    static func destructiveCount(_ skills: [String: Int]) -> Int {
        let destructive: Set<String> = ["bomber", "basher", "miner", "digger", "stoner", "fencer", "laserer", "batter",
            "exploder", "scooper", "stomper", "club_basher", "laser_blaster", "flame_thrower", "bazooka", "mortar",
            "thrower", "spearer", "archer", "bomb", "grenade", "spade", "hadoken"]
        return skills.reduce(0) { $0 + (destructive.contains(skillKey($1.key)) ? $1.value : 0) }
    }
    static func telemetry(_ session: any GameSession) -> TrolleyTelemetry {
        var additional: [String: Double] = [:]
        var released = session.released
        if let neo = session as? NeoLemmixSession {
            released = neo.simulation.lemmings.count
            additional["cloned"] = Double(neo.simulation.totalPopulation - neo.simulation.configuration.totalLemmings)
            additional["preplaced"] = Double(neo.simulation.configuration.preplacedLemmings.count)
        }
        return TrolleyTelemetry(released: released, nukeCount: session.nukeCount, rewindCount: session.rewindCount,
            undoCount: session.undoCount, destructiveSkillCount: destructiveCount(session.skillAssignments),
            buildVersion: buildVersion, additionalStatistics: additional)
    }
    static func sessionFingerprint(_ session: any GameSession, source: Data?) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var bytes = source ?? Data()
        if let classic = session as? ClassicSession {
            bytes.append(Data(ClassicDOSReplayRecorder.stateHash(of: classic.simulation).utf8))
            bytes.append((try? encoder.encode(classic.simulation.configuration.entrances)) ?? Data())
            bytes.append((try? encoder.encode(classic.simulation.configuration.triggers)) ?? Data())
            bytes.append((try? encoder.encode(classic.simulation.comparisonDestructionMasks)) ?? Data())
        } else if let neo = session as? NeoLemmixSession {
            bytes.append((try? encoder.encode(neo.simulation.terrain)) ?? Data())
            if let data = try? encoder.encode(neo.simulation.configuration),
               var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                object["skills"] = skills(session.skills)
                func canonical(_ value: Any, key: String = "") -> Any {
                    if let dictionary = value as? [String: Any] { return dictionary.mapValues { canonical($0) }
                        .merging(dictionary.filter { $0.key == "traits" }.mapValues { canonical($0, key: "traits") }, uniquingKeysWith: { _, b in b }) }
                    if key == "traits", let strings = value as? [String] { return strings.sorted() }
                    if let array = value as? [Any] { return array.map { canonical($0) } }
                    return value
                }
                bytes.append((try? JSONSerialization.data(withJSONObject: canonical(object), options: [.sortedKeys])) ?? Data())
            }
        } else { bytes.append(Data(UUID().uuidString.utf8)) }
        return ArcadeStore.fingerprint(bytes)
    }
    /// Asset content participates in sequel identity, including collision tables, objects, terrain and masks.
    /// File paths are relative, so moving an unchanged pack does not invalidate its records.
    private static var contentCache: [String: (Date, Int, String)] = [:]
    static func contentFingerprint(root: URL) -> String {
        if GameAssetCache<String>.bundledKey(root) != nil,
           let cached = FanLevelLibrary.directoryFingerprint(root) { return cached }
        let root = root.resolvingSymlinksInPath().standardizedFileURL
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys,
                                                               options: [.skipsHiddenFiles]) else { return UUID().uuidString }
        var entries: [String: String] = [:]
        for case let url as URL in enumerator {
            // User campaign slots and rendered media cannot change level physics.
            if ["sav", "mp4", "m4a", "wav", "ogg", "mp3", "mod", "mid", "png", "jpg"].contains(url.pathExtension.lowercased()) { continue }
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true,
                  let date = values.contentModificationDate, let size = values.fileSize else { continue }
            let hash: String
            if let cached = contentCache[url.path], cached.0 == date, cached.1 == size { hash = cached.2 }
            else {
                guard let data = try? Data(contentsOf: url) else { return UUID().uuidString }
                hash = ArcadeStore.fingerprint(data); contentCache[url.path] = (date, size, hash)
            }
            entries[String(url.path.dropFirst(root.path.count))] = hash
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return ArcadeStore.fingerprint((try? encoder.encode(entries)) ?? Data(UUID().uuidString.utf8))
    }
}
