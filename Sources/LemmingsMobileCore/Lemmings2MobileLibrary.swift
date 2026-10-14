import Foundation
import NxlvKit

/**
 * Loads player-owned L2 data and creates campaign-aware mobile sessions.
 */
public final class Lemmings2MobileLibrary: MobileGameLibrary {
    public static let engineFingerprint = "lemmings2-mobile-runtime-v1"

    public let directory: URL
    public let displayName = L10n.text("Lemmings 2")
    public let levels: [MobileLevelSummary]
    private let levelFingerprints: [String]

    private let storage: MobileStorage
    private let campaignLock = NSRecursiveLock()
    private var campaign: Lemmings2Campaign
    private var styles: [Int: Lemmings2Style] = [:]
    private var assets: Assets?
    private var progressFailure: String?

    private struct Assets {
        let sprites: Lemmings2Sprites
        let intern: Lemmings2SpecialGraphics
        let masks: Lemmings2TerrainMasks
        let walker: Lemmings2Walker?
        let explosion: Lemmings2Explosion
        let soundBank: Lemmings2SoundBank?
        let panel: Lemmings2Panel?

        init(root: URL) throws {
            panel = try? Lemmings2Panel(root: root)
            sprites = try Lemmings2Sprites(data: Data(contentsOf: root.appendingPathComponent("VLEMMS.DAT")))
            intern = try Lemmings2SpecialGraphics(data: Data(contentsOf: root.appendingPathComponent("INTERN.DAT")))
            masks = try Lemmings2TerrainMasks(root: root)
            walker = (try? Data(contentsOf: root.appendingPathComponent("WALKER.DAT")))
                .flatMap { try? Lemmings2Walker(data: $0) }
            explosion = try Lemmings2Explosion(root: root)
            soundBank = (try? Data(contentsOf: root.appendingPathComponent("MUSIC/SBLAST.VOC")))
                .flatMap { try? Lemmings2SoundBank(data: $0) }
        }
    }

    public var currentLevelIndex: Int {
        campaignLock.lock()
        defer { campaignLock.unlock() }
        return campaign.tribe * 10 + campaign.level
    }

    public init(directory: URL, storage: MobileStorage) throws {
        self.directory = directory
        self.storage = storage
        let contentFingerprint = try MobileContentFingerprint.digest(directory: directory)
        var campaign = try Lemmings2Campaign(root: directory)
        if let saved = storage.load(Lemmings2Campaign.Progress.self, name: "lemmings2-campaign") {
            try campaign.restore(saved)
        }
        self.campaign = campaign
        levelFingerprints = campaign.levels.map {
            MobileContentFingerprint.levelFingerprint(content: contentFingerprint, level: $0.fingerprint)
        }
        levels = campaign.levels.enumerated().map { index, level in
            let tribe = index / 10
            return MobileLevelSummary(index: index,
                rank: Lemmings2Campaign.tribeNames[tribe], number: index % 10 + 1,
                title: level.title.isEmpty ? "Level \(index % 10 + 1)" : level.title)
        }
    }

    public func levelKey(at index: Int) -> String {
        guard levels.indices.contains(index) else { return "" }
        return "lemmings2/\(levelFingerprints[index])"
    }

    public func checkpointLevelIdentifier(at index: Int) throws -> String? {
        guard levels.indices.contains(index) else { throw MobileSessionError.changedLevel }
        return "lemmings2/\(levelFingerprints[index])"
    }

    public func loadLevel(at index: Int) throws -> MobileLevelContent {
        guard levels.indices.contains(index) else { throw MobileSessionError.changedLevel }
        let tribe = index / 10
        let levelNumber = index % 10
        let selectedLevel: Lemmings2Level
        let population: Int
        let style: Lemmings2Style
        campaignLock.lock()
        do {
            if let progressFailure { throw Lemmings2MobileLibraryError.progressSave(progressFailure) }
            var proposed = campaign
            try proposed.select(tribe: tribe, level: levelNumber)
            if proposed.progress != campaign.progress {
                try storage.save(proposed.progress, name: "lemmings2-campaign")
                campaign = proposed
            }
            selectedLevel = proposed.current
            population = proposed.population
            if let cached = styles[tribe] {
                style = cached
            } else {
                let name = Lemmings2Campaign.styleNames[tribe]
                let url = directory.appendingPathComponent("STYLES/\(name).DAT")
                let loaded = try Lemmings2Style(data: Data(contentsOf: url))
                styles[tribe] = loaded
                style = loaded
            }
            campaignLock.unlock()
        } catch {
            campaignLock.unlock()
            throw error
        }

        let assets = try loadAssets()
        let runtime = try Lemmings2Runtime(level: selectedLevel, style: style,
                                           masks: assets.masks, total: population)
        let renderer = try Lemmings2MobileSceneRenderer(level: selectedLevel, style: style,
                                                        sprites: assets.sprites, intern: assets.intern,
                                                        walker: assets.walker, explosion: assets.explosion)
        let identifier = "lemmings2/\(levelFingerprints[index])"
        let session = renderer.makeSession(runtime: runtime,
            engineFingerprint: Self.engineFingerprint,
            levelIdentifier: identifier, levelIndex: index,
            levelFingerprint: levelFingerprints[index], soundBank: assets.soundBank) { [weak self] completedRuntime in
                self?.record(completedRuntime, at: index)
            }
        session.skillCursorFrames = runtime.configuration.skills.map { skill in
            guard let panel = assets.panel, panel.skills.indices.contains(skill.rawValue - 1) else { return nil }
            let frame = panel.skills[skill.rawValue - 1]
            let palette = Lemmings2Panel.palette(over: runtime.configuration.palette)
            var rgba = [UInt8](repeating: 0, count: frame.width * frame.height * 4)
            Lemmings2MobileSceneRenderer.composite(frame, palette: palette, atX: 0, y: 0,
                width: frame.width, height: frame.height, into: &rgba)
            guard let image = try? MobilePixelFrame(width: frame.width, height: frame.height, rgba: Data(rgba)) else { return nil }
            // Panel sprites include empty padding; fit the actual skill art beside the pointer.
            let visible = frame.opaque.indices.filter { frame.opaque[$0] }
            guard let left = visible.map({ $0 % frame.width }).min(),
                  let right = visible.map({ $0 % frame.width }).max(),
                  let top = visible.map({ $0 / frame.width }).min(),
                  let bottom = visible.map({ $0 / frame.width }).max() else { return nil }
            return try? image.cropped(around: .init(x: Double(left + right + 1) / 2, y: Double(top + bottom + 1) / 2),
                width: right - left + 1, height: bottom - top + 1)
        }
        return MobileLevelContent(summary: levels[index], session: session)
    }

    private func loadAssets() throws -> Assets {
        campaignLock.lock()
        defer { campaignLock.unlock() }
        if let assets { return assets }
        let loaded = try Assets(root: directory)
        assets = loaded
        return loaded
    }

    func record(_ runtime: Lemmings2Runtime, at index: Int) {
        guard levels.indices.contains(index) else { return }
        campaignLock.lock()
        defer { campaignLock.unlock() }
        guard progressFailure == nil else { return }
        do {
            var proposed = campaign
            try proposed.select(tribe: index / 10, level: index % 10)
            let accepted = proposed.level < 9
                ? proposed.advance(after: runtime)
                : proposed.record(runtime)
            guard accepted, proposed.progress != campaign.progress else { return }
            try storage.save(proposed.progress, name: "lemmings2-campaign")
            campaign = proposed
        } catch {
            progressFailure = error.localizedDescription
        }
    }
}

public enum Lemmings2MobileLibraryError: Error, LocalizedError {
    case progressSave(String)

    public var errorDescription: String? {
        switch self {
        case let .progressSave(reason):
            L10n.text("Lemmings 2 progress could not be saved: \(reason)")
        }
    }
}
