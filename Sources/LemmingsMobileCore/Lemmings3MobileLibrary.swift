import CryptoKit
import Foundation
import NxlvKit

/**
 * Loads player-owned Chronicles data and creates native mobile sessions.
 */
public final class Lemmings3MobileLibrary: MobileGameLibrary {
    public static let engineFingerprint = "lemmings3-mobile-runtime-v1"

    public let directory: URL
    public var displayName: String { Lemmings3Brand.current.displayName }
    public let levels: [MobileLevelSummary]
    private let contentFingerprint: String

    private typealias SavedProgress = MobileCampaignProgress.Chronicles

    private let storage: MobileStorage
    private let soundBank: Lemmings3SoundBank?
    private let progressLock = NSRecursiveLock()
    private let panelLock = NSLock()
    private var panelFrames: [Int: MobilePixelFrame] = [:]
    private let artLock = NSLock()
    private struct ArtBank {
        let style: Lemmings3Style
        let sprites: Lemmings3Sprites
        let palette: [UInt8]
    }
    private var artBanks: [Int: ArtBank] = [:]
    private var savedProgress: SavedProgress
    private var progressFailure: String?

    public var currentLevelIndex: Int {
        progressLock.lock()
        defer { progressLock.unlock() }
        let tribe = Lemmings3ClassicCampaign.Tribe(rawValue: savedProgress.currentTribe) ?? .classic
        let index = savedProgress.progress(for: tribe)?.index ?? 0
        return (tribe.rawValue - 1) * 30 + index
    }

    public init(directory: URL, storage: MobileStorage) throws {
        self.directory = directory
        self.storage = storage
        contentFingerprint = try MobileContentFingerprint.digest(directory: directory)
        soundBank = try? Lemmings3SoundBank(root: directory)
        savedProgress = storage.load(SavedProgress.self, name: "lemmings3-campaign") ?? SavedProgress()
        levels = try Lemmings3ClassicCampaign.Tribe.allCases.flatMap { tribe in
            try Task.checkCancellation()
            let campaign = try Lemmings3ClassicCampaign(root: directory, tribe: tribe)
            return campaign.levels.enumerated().map { index, level in
                MobileLevelSummary(index: (tribe.rawValue - 1) * 30 + index,
                    rank: tribe.title,
                    number: index + 1,
                    title: L10n.text("Level \(index + 1) • \(level.width)×\(level.height)"))
            }
        }
    }

    public func canSkipLevel(at index: Int) -> Bool {
        progressLock.lock(); defer { progressLock.unlock() }
        guard progressFailure == nil, levels.indices.contains(index), index % 30 < 29,
              let tribe = Lemmings3ClassicCampaign.Tribe(rawValue: index / 30 + 1) else { return false }
        return savedProgress.progress(for: tribe)?.completed[index % 30] == nil
    }
    public func prepareLevelSkip(at index: Int) throws -> () throws -> Void {
        progressLock.lock(); defer { progressLock.unlock() }
        guard canSkipLevel(at: index), let tribe = Lemmings3ClassicCampaign.Tribe(rawValue: index / 30 + 1) else {
            throw MobileSessionError.changedLevel
        }
        let previous = savedProgress
        var campaign = try Lemmings3ClassicCampaign(root: directory, tribe: tribe)
        if let progress = savedProgress.progress(for: tribe) { try campaign.restore(progress) }
        if campaign.index != index % 30 { try campaign.select(index % 30) }
        guard campaign.skipLevel() else { throw MobileSessionError.changedLevel }
        try save(campaign.progress, tribe: tribe)
        return { [self] in
            progressLock.lock(); defer { progressLock.unlock() }
            try storage.save(previous, name: "lemmings3-campaign")
            savedProgress = previous
        }
    }

    public func levelKey(at index: Int) -> String {
        guard levels.indices.contains(index), let data = try? levelData(at: index) else { return "" }
        let fingerprint = MobileContentFingerprint.levelFingerprint(
            content: contentFingerprint, level: Self.digest(data))
        return "lemmings3/\(fingerprint)"
    }

    public func checkpointLevelIdentifier(at index: Int) throws -> String? {
        guard levels.indices.contains(index) else { throw MobileSessionError.changedLevel }
        let fingerprint = MobileContentFingerprint.levelFingerprint(
            content: contentFingerprint, level: Self.digest(try levelData(at: index)))
        return "lemmings3/\(fingerprint)"
    }

    public func loadLevel(at index: Int) throws -> MobileLevelContent { try loadLevel(at: index, population: nil) }

    public func loadLevel(at index: Int, population override: Int?) throws -> MobileLevelContent {
        try Task.checkCancellation()
        guard levels.indices.contains(index) else { throw MobileSessionError.changedLevel }
        let tribe = Lemmings3ClassicCampaign.Tribe(rawValue: index / 30 + 1)!
        let localIndex = index % 30
        let level = try Lemmings3Level(data: levelData(at: index))
        let art = try artBank(for: tribe)
        let style = art.style
        let panel = try panelFrame(for: tribe.spriteStyle)
        let permanent = try Lemmings3Objects(data: Data(contentsOf: objectURL(level.permanentObjectsReference, temporary: false)))
        let temporary = try Lemmings3Objects(data: Data(contentsOf: objectURL(level.temporaryObjectsReference, temporary: true)))
        let scene = try Lemmings3Scene(level: level, style: style, permanent: permanent, temporary: temporary)
        try Task.checkCancellation()
        let graphicsPrefix = String(format: "GRAPHICS/TRIBE%03d", tribe.spriteStyle)
        let sprites = try Lemmings3Sprites(
            index: Data(contentsOf: directory.appendingPathComponent(graphicsPrefix + ".IND")),
            commands: Data(contentsOf: directory.appendingPathComponent(graphicsPrefix + ".CMP")))
        let actorPalette = try Lemmings3Sprites.palette(
            Data(contentsOf: directory.appendingPathComponent(graphicsPrefix + ".PAL")), over: style.palette)
        try Task.checkCancellation()

        progressLock.lock()
        let loadedCampaign: Lemmings3ClassicCampaign
        do {
            if let progressFailure { throw Lemmings3MobileLibraryError.progressSave(progressFailure) }
            var campaign = try Lemmings3ClassicCampaign(root: directory, tribe: tribe)
            if let progress = savedProgress.progress(for: tribe) { try campaign.restore(progress) }
            if campaign.index != localIndex {
                try campaign.select(localIndex)
                if override == nil { try save(campaign.progress, tribe: tribe) }
            }
            loadedCampaign = campaign
            progressLock.unlock()
        } catch {
            progressLock.unlock()
            throw error
        }

        let runtime = try Lemmings3Runtime(level: level, style: style, permanent: permanent,
                                           temporary: temporary, total: override ?? loadedCampaign.population)
        var creatureBanks: [Lemmings3Runtime.Creature.Kind: Lemmings3MobileSceneRenderer.CreatureBank] = [:]
        for kind in Set(runtime.creatures.map(\.kind)) {
            try Task.checkCancellation()
            let prefix = String(format: "GRAPHICS/CREAT%03d", (kind.rawValue - 10008) / 2)
            let bank = try Lemmings3Sprites(
                index: Data(contentsOf: directory.appendingPathComponent(prefix + ".IND")),
                commands: Data(contentsOf: directory.appendingPathComponent(prefix + ".CMP")))
            let creaturePalette = try Lemmings3Sprites.palette(
                Data(contentsOf: directory.appendingPathComponent(prefix + ".PAL")), over: style.palette)
            creatureBanks[kind] = .init(animations: bank.animations, palette: creaturePalette)
        }
        var animatedFrames: [Int: [Lemmings3MobileSceneRenderer.AnimatedObject.Frame]] = [:]
        let animatedObjects = try permanent.placements.enumerated().compactMap { index, placement -> Lemmings3MobileSceneRenderer.AnimatedObject? in
            try Task.checkCancellation()
            guard let definition = style.permanent.objects[placement.identifier],
                  (0x4002...0x400a).contains(definition.flags), definition.frameCount > 1 else { return nil }
            let frames: [Lemmings3MobileSceneRenderer.AnimatedObject.Frame]
            if let cached = animatedFrames[placement.identifier] {
                frames = cached
            } else {
                frames = try (0..<definition.frameCount).map { frameIndex in
                    try Task.checkCancellation()
                    let image = try style.permanent.image(object: placement.identifier, frame: frameIndex, palette: style.palette)
                    return try Lemmings3MobileSceneRenderer.AnimatedObject.Frame(
                        width: image.width, height: image.height, pixels: image.pixels, palette: image.palette)
                }
                animatedFrames[placement.identifier] = frames
            }
            return Lemmings3MobileSceneRenderer.AnimatedObject(
                id: index, x: placement.x, y: placement.y, frames: frames)
        }
        let renderer = try Lemmings3MobileSceneRenderer(scene: scene, style: style,
                                                       sprites: sprites, palette: actorPalette,
                                                       creatureBanks: creatureBanks,
                                                       animatedObjects: animatedObjects, terrainStyle: level.style)
        let fingerprint = MobileContentFingerprint.levelFingerprint(
            content: contentFingerprint, level: Self.digest(level.rawData))
        let session = Lemmings3MobileSession(runtime: runtime,
            engineFingerprint: Self.engineFingerprint,
            levelIdentifier: "lemmings3/\(fingerprint)", levelIndex: index,
            levelFingerprint: fingerprint, panelFrame: panel,
            directionPickerFrames: try renderer.directionPickerFrames(), renderer: renderer.render,
            ghostRenderer: { runtime, highlight, ghosts in
                try renderer.render(runtime, highlight: highlight, ghosts: ghosts)
            },
            soundBank: soundBank) { [weak self] completed in
                if override == nil { self?.record(completed, at: localIndex, tribe: tribe) }
            }
        session.spriteProvider = renderer.spriteHighlight
        session.artworkRenderer = { runtime, highlight, ghosts, mac in
            try renderer.render(runtime, highlight: highlight, ghosts: ghosts, macintosh: mac)
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
            if let progress = savedProgress.progress(for: tribe) { try campaign.restore(progress) }
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
        proposed.set(progress, tribe: tribe)
        try storage.save(proposed, name: "lemmings3-campaign")
        savedProgress = proposed
    }

    private func levelData(at index: Int) throws -> Data {
        let tribe = Lemmings3ClassicCampaign.Tribe(rawValue: index / 30 + 1)!
        return try Data(contentsOf: directory.appendingPathComponent(
            String(format: "LEVELS/LEVEL%03d.DAT", tribe.firstLevel + index % 30)))
    }

    private func artBank(for tribe: Lemmings3ClassicCampaign.Tribe) throws -> ArtBank {
        artLock.lock()
        defer { artLock.unlock() }
        try Task.checkCancellation()
        if let cached = artBanks[tribe.rawValue] { return cached }
        let style = try Lemmings3Style(directory: directory.appendingPathComponent("STYLES"), number: tribe.rawValue)
        try Task.checkCancellation()
        let prefix = String(format: "GRAPHICS/TRIBE%03d", tribe.spriteStyle)
        let sprites = try Lemmings3Sprites(index: Data(contentsOf: directory.appendingPathComponent(prefix + ".IND")),
            commands: Data(contentsOf: directory.appendingPathComponent(prefix + ".CMP")))
        let palette = try Lemmings3Sprites.palette(
            Data(contentsOf: directory.appendingPathComponent(prefix + ".PAL")), over: style.palette)
        try Task.checkCancellation()
        let bank = ArtBank(style: style, sprites: sprites, palette: palette)
        // A library has three tribes. Each decoded bank stays bound to this content revision.
        artBanks[tribe.rawValue] = bank
        return bank
    }

    private func panelFrame(for tribe: Int) throws -> MobilePixelFrame {
        panelLock.lock()
        defer { panelLock.unlock() }
        if let cached = panelFrames[tribe] { return cached }
        let frame = try Lemmings3MobileSceneRenderer.panelFrame(directory: directory, tribe: tribe)
        panelFrames[tribe] = frame
        return frame
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
        case let .progressSave(reason): L10n.text("Lemmings 3 progress could not be saved: \(reason)")
        }
    }
}
