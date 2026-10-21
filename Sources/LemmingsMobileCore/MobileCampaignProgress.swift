import Foundation
import LemmingsAppCore
import NxlvKit

/// The sequel files use the same progress values and whole-chain merge rules as Mac.
public enum MobileCampaignProgress {
    public struct Chronicles: Codable, Equatable, Sendable {
        public var currentTribe = 1
        public var tribes: [String: Lemmings3ClassicCampaign.Progress] = [:]
        public init() {}
        private enum CodingKeys: String, CodingKey { case currentTribe, tribes }
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            currentTribe = try values.decode(Int.self, forKey: .currentTribe)
            let saved = try values.decode([String: Lemmings3ClassicCampaign.Progress].self, forKey: .tribes)
            for (label, progress) in saved {
                guard progress.version == 1 else { throw MobileCheckpointError.version }
                let tribe = progress.tribe ?? Lemmings3ClassicCampaign.Tribe.allCases.first { name($0) == label } ?? .classic
                let restored = Lemmings3ClassicCampaign.Progress(index: progress.index, population: progress.population,
                    completed: progress.completed, tribe: tribe)
                let label = name(tribe)
                var merged = GameProgressPreferences(values: tribes[label].map { [key(tribe): .chronicles($0)] } ?? [:])
                try merged.merge(.init(values: [key(tribe): .chronicles(restored)]))
                if case let .chronicles(progress) = merged.values[key(tribe)] { tribes[label] = progress }
            }
        }
        public func progress(for tribe: Lemmings3ClassicCampaign.Tribe) -> Lemmings3ClassicCampaign.Progress? {
            tribes[name(tribe)]
        }
        public mutating func set(_ progress: Lemmings3ClassicCampaign.Progress, tribe: Lemmings3ClassicCampaign.Tribe) {
            tribes[name(tribe)] = progress
        }
    }

    public static func capture(storage: MobileStorage) throws -> GameProgressPreferences {
        var values: [String: GameProgressValue] = [:]
        if let saved = try read(Lemmings2Campaign.Progress.self, storage: storage, name: "lemmings2-campaign") {
            values["nativeL2Campaign.v1.bundled"] = .tribes(saved)
        }
        if let saved = try read(Chronicles.self, storage: storage, name: "lemmings3-campaign") {
            for tribe in Lemmings3ClassicCampaign.Tribe.allCases {
                if let progress = saved.progress(for: tribe) {
                    guard (progress.tribe ?? .classic) == tribe else { throw MobileSessionError.invalidCheckpoint }
                    values[key(tribe)] = .chronicles(progress)
                }
            }
        }
        let result = GameProgressPreferences(values: values)
        try result.validate()
        return result
    }

    /// Called at a safe library boundary before a sequel library reads its campaign.
    public static func reconcile(_ incoming: GameProgressPreferences, storage: MobileStorage) throws {
        let original = try capture(storage: storage)
        var merged = original
        let sequel = incoming.values.filter { key, value in
            switch value {
            case .tribes: return key == "nativeL2Campaign.v1.bundled"
            case .chronicles: return key.hasPrefix("nativeL3")
            default: return false
            }
        }
        try merged.merge(.init(values: sequel))
        if case let .tribes(saved) = merged.values["nativeL2Campaign.v1.bundled"],
           original.values["nativeL2Campaign.v1.bundled"] != .tribes(saved) {
            try storage.save(saved, name: "lemmings2-campaign")
        }
        var chronicles = try read(Chronicles.self, storage: storage, name: "lemmings3-campaign") ?? .init()
        let before = chronicles
        for tribe in Lemmings3ClassicCampaign.Tribe.allCases {
            if case let .chronicles(saved) = merged.values[key(tribe)] {
                chronicles.set(saved, tribe: tribe)
            }
        }
        if chronicles != before { try storage.save(chronicles, name: "lemmings3-campaign") }
    }

    private static func key(_ tribe: Lemmings3ClassicCampaign.Tribe) -> String {
        "nativeL3\(name(tribe))Preview.v1.bundled"
    }
    private static func name(_ tribe: Lemmings3ClassicCampaign.Tribe) -> String {
        switch tribe { case .classic: "Classic"; case .shadow: "Shadow"; case .egyptian: "Egyptian" }
    }

    /// Summary and cloud capture must not move or replace damaged campaign files.
    private static func read<T: Decodable>(_ type: T.Type, storage: MobileStorage, name: String) throws -> T? {
        let primary = storage.directory.appendingPathComponent(name + ".json")
        let backup = storage.directory.appendingPathComponent(name + ".json.bak")
        func decode(_ file: URL) throws -> T {
            let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 1_000_000 else { throw MobileCheckpointError.tooLarge }
            return try JSONDecoder().decode(type, from: Data(contentsOf: file))
        }
        if FileManager.default.fileExists(atPath: primary.path) {
            do { return try decode(primary) }
            catch MobileCheckpointError.version { throw MobileCheckpointError.version }
            catch {
                guard FileManager.default.fileExists(atPath: backup.path) else { throw error }
                return try decode(backup)
            }
        }
        return FileManager.default.fileExists(atPath: backup.path) ? try decode(backup) : nil
    }
}
