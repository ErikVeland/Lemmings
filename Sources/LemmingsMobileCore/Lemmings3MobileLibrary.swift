import CryptoKit
import Foundation
import NxlvKit

/**
 * Loads player-owned Chronicles data and creates native mobile sessions.
 */
public final class Lemmings3MobileLibrary: MobileGameLibrary {
    public static let engineFingerprint = "lemmings3-mobile-runtime-v1"

    public let directory: URL
    public let displayName = "Lemmings 3: Chronicles"
    public let levels: [MobileLevelSummary]

    private struct SavedProgress: Codable {
        var currentTribe = 1
        var tribes: [String: Lemmings3ClassicCampaign.Progress] = [:]
    }

    private let storage: MobileStorage
    private let progressLock = NSRecursiveLock()
    private var savedProgress: SavedProgress
    private var progressFailure: String?

    public var currentLevelIndex: Int {
        progressLock.lock()
        defer { progressLock.unlock() }
        let tribe = Lemmings3ClassicCampaign.Tribe(rawValue: savedProgress.currentTribe) ?? .classic
        let index = savedProgress.tribes[tribe.title]?.index ?? 0
        return (tribe.rawValue - 1) * 30 + index
    }

    public init(directory: URL, storage: MobileStorage) throws {
        self.directory = directory
        self.storage = storage
        savedProgress = storage.load(SavedProgress.self, name: "lemmings3-campaign") ?? SavedProgress()
        levels = try Lemmings3ClassicCampaign.Tribe.allCases.flatMap { tribe in
            let campaign = try Lemmings3ClassicCampaign(root: directory, tribe: tribe)
            return campaign.levels.enumerated().map { index, level in
                MobileLevelSummary(index: (tribe.rawValue - 1) * 30 + index,
                    rank: tribe.title,
                    number: index + 1,
                    title: "Level \(index + 1) • \(level.width)×\(level.height)")
            }
        }
    }

    public func levelKey(at index: Int) -> String {
        guard levels.indices.contains(index), let data = try? levelData(at: index) else { return "" }
        return "lemmings3/\(Self.digest(data))"
    }

    public func checkpointLevelIdentifier(at index: Int) throws -> String? {
        guard levels.indices.contains(index) else { throw MobileSessionError.changedLevel }
        return "lemmings3/\(Self.digest(try levelData(at: index)))"
    }

    public func loadLevel(at index: Int) throws -> MobileLevelContent {
        guard levels.indices.contains(index) else { throw MobileSessionError.changedLevel }
        let tribe = Lemmings3ClassicCampaign.Tribe(rawValue: index / 30 + 1)!
        let localIndex = index % 30
        let level = try Lemmings3Level(data: levelData(at: index))
        let style = try Lemmings3Style(directory: directory.appendingPathComponent("STYLES"), number: tribe.rawValue)
        let permanent = try Lemmings3Objects(data: Data(contentsOf: objectURL(level.permanentObjectsReference, temporary: false)))
        let temporary = try Lemmings3Objects(data: Data(contentsOf: objectURL(level.temporaryObjectsReference, temporary: true)))
        let scene = try Lemmings3Scene(level: level, style: style, permanent: permanent, temporary: temporary)
        let graphicsPrefix = String(format: "GRAPHICS/TRIBE%03d", tribe.spriteStyle)
        let sprites = try Lemmings3Sprites(
            index: Data(contentsOf: directory.appendingPathComponent(graphicsPrefix + ".IND")),
            commands: Data(contentsOf: directory.appendingPathComponent(graphicsPrefix + ".CMP")))
        let actorPalette = try Lemmings3Sprites.palette(
            Data(contentsOf: directory.appendingPathComponent(graphicsPrefix + ".PAL")), over: style.palette)

        progressLock.lock()
        let loadedCampaign: Lemmings3ClassicCampaign
        do {
            if let progressFailure { throw Lemmings3MobileLibraryError.progressSave(progressFailure) }
            var campaign = try Lemmings3ClassicCampaign(root: directory, tribe: tribe)
            if let progress = savedProgress.tribes[tribe.title] { try campaign.restore(progress) }
            if campaign.index != localIndex {
                try campaign.select(localIndex)
                try save(campaign.progress, tribe: tribe)
            }
            loadedCampaign = campaign
            progressLock.unlock()
        } catch {
            progressLock.unlock()
            throw error
        }

        let runtime = try Lemmings3Runtime(level: level, style: style, permanent: permanent,
                                           temporary: temporary, total: loadedCampaign.population)
        var creatureBanks: [Lemmings3Runtime.Creature.Kind: Lemmings3MobileSceneRenderer.CreatureBank] = [:]
        for kind in Set(runtime.creatures.map(\.kind)) {
            let prefix = String(format: "GRAPHICS/CREAT%03d", (kind.rawValue - 10008) / 2)
            let bank = try Lemmings3Sprites(
                index: Data(contentsOf: directory.appendingPathComponent(prefix + ".IND")),
                commands: Data(contentsOf: directory.appendingPathComponent(prefix + ".CMP")))
            let creaturePalette = try Lemmings3Sprites.palette(
                Data(contentsOf: directory.appendingPathComponent(prefix + ".PAL")), over: style.palette)
            creatureBanks[kind] = .init(animations: bank.animations, palette: creaturePalette)
        }
        let renderer = try Lemmings3MobileSceneRenderer(scene: scene, style: style,
                                                       sprites: sprites, palette: actorPalette,
                                                       creatureBanks: creatureBanks)
        let fingerprint = Self.digest(level.rawData)
        let session = Lemmings3MobileSession(runtime: runtime,
            engineFingerprint: Self.engineFingerprint,
            levelIdentifier: "lemmings3/\(fingerprint)", levelIndex: index,
            levelFingerprint: fingerprint, renderer: renderer.render) { [weak self] completed in
                self?.record(completed, at: localIndex, tribe: tribe)
            }
        return MobileLevelContent(summary: levels[index], session: session)
    }

    private func record(_ runtime: Lemmings3Runtime, at index: Int,
                        tribe: Lemmings3ClassicCampaign.Tribe) {
        progressLock.lock()
        defer { progressLock.unlock() }
        guard progressFailure == nil else { return }
        do {
            var campaign = try Lemmings3ClassicCampaign(root: directory, tribe: tribe)
            if let progress = savedProgress.tribes[tribe.title] { try campaign.restore(progress) }
            if campaign.index != index { try campaign.select(index) }
            guard campaign.record(runtime) else { return }
            _ = campaign.advance(after: runtime)
            try save(campaign.progress, tribe: tribe)
        } catch {
            progressFailure = error.localizedDescription
        }
    }

    private func save(_ progress: Lemmings3ClassicCampaign.Progress,
                      tribe: Lemmings3ClassicCampaign.Tribe) throws {
        var proposed = savedProgress
        proposed.currentTribe = tribe.rawValue
        proposed.tribes[tribe.title] = progress
        try storage.save(proposed, name: "lemmings3-campaign")
        savedProgress = proposed
    }

    private func levelData(at index: Int) throws -> Data {
        let tribe = Lemmings3ClassicCampaign.Tribe(rawValue: index / 30 + 1)!
        return try Data(contentsOf: directory.appendingPathComponent(
            String(format: "LEVELS/LEVEL%03d.DAT", tribe.firstLevel + index % 30)))
    }

    private func objectURL(_ reference: Int, temporary: Bool) -> URL {
        directory.appendingPathComponent(String(format: "LEVELS/%@%03d.OBS", temporary ? "TEMP" : "PERM", reference))
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

public enum Lemmings3MobileLibraryError: Error, LocalizedError {
    case progressSave(String)

    public var errorDescription: String? {
        switch self {
        case let .progressSave(reason): "Lemmings 3 progress could not be saved: \(reason)"
        }
    }
}
