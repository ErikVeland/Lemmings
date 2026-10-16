import CryptoKit
import Foundation
import LemmingsMobileCore
import NxlvKit

/**
 * Opens supported levels from bundled or player-imported NeoLemmix CE packs.
 */
final class NeoLemmixMobileLibrary: MobileGameLibrary {
    private struct Entry {
        let pack: NeoLemmixPack
        let level: NeoLemmixPackLevel
        let stylesRoot: URL?
        let summary: MobileLevelSummary

        var identifier: String { "neolemmix/\(pack.id)/\(level.levelID)" }
    }

    private struct Progress: Codable {
        var currentIndex = 0
        var currentLevelIdentifier: String?
        var bestSaved: [String: Int] = [:]
    }

    static let engineFingerprint = "neolemmix-mobile-runtime-v1"
    let directory: URL
    let displayName = L10n.text("NeoLemmix")
    let levels: [MobileLevelSummary]
    private let entries: [Entry]
    private let storage: MobileStorage
    private let progressLock = NSRecursiveLock()
    private var progress: Progress
    private var progressFailure: String?

    /// Indices whose level dependencies resolve before full runtime validation.
    var styleResolvedLevelIndices: [Int] {
        entries.indices.filter { entries[$0].stylesRoot != nil }
    }

    var currentLevelIndex: Int {
        progressLock.lock()
        defer { progressLock.unlock() }
        return levels.indices.contains(progress.currentIndex) ? progress.currentIndex : 0
    }

    init(directory: URL, storage: MobileStorage) throws {
        self.directory = directory
        self.storage = storage
        progress = storage.load(Progress.self, name: "neolemmix-library") ?? Progress()
        let source = NeoLemmixLibrary.Source(
            levelsRoot: MobileNeoLemmixDataLayout.levelsRoot(in: directory),
            stylesRoot: MobileNeoLemmixDataLayout.stylesRoot(in: directory))
        let resolvedPacks = NeoLemmixLibrary.discover([source])
        var entries: [Entry] = []
        for resolvedPack in resolvedPacks {
            for (index, level) in resolvedPack.pack.levels.enumerated() {
                let stylesRoot = resolvedPack.stylesRoot(for: level)
                let group = level.groups.last ?? resolvedPack.pack.title
                let title = level.title.isEmpty ? L10n.text("Level \(index + 1)") : level.title
                let summary = MobileLevelSummary(index: entries.count, rank: group,
                    number: index + 1, title: title)
                entries.append(Entry(pack: resolvedPack.pack, level: level,
                                     stylesRoot: stylesRoot, summary: summary))
            }
        }
        guard !entries.isEmpty else { throw NeoLemmixMobileLibraryError.noSupportedLevels }
        if let identifier = progress.currentLevelIdentifier,
           let index = entries.firstIndex(where: { $0.identifier == identifier }) {
            progress.currentIndex = index
        } else if !entries.indices.contains(progress.currentIndex) {
            progress.currentIndex = 0
        }
        self.entries = entries
        levels = entries.map(\.summary)
    }

    func levelKey(at index: Int) -> String {
        guard entries.indices.contains(index) else { return "" }
        let entry = entries[index]
        return entry.identifier + "/\(entry.level.sourceRevision)"
    }

    func checkpointLevelIdentifier(at index: Int) throws -> String? {
        guard entries.indices.contains(index) else { throw MobileSessionError.changedLevel }
        let entry = entries[index]
        return entry.identifier
    }

    func loadLevel(at index: Int) throws -> MobileLevelContent {
        try Task.checkCancellation()
        guard entries.indices.contains(index) else { throw MobileSessionError.changedLevel }
        let entry = entries[index]
        progressLock.lock()
        let savedFailure = progressFailure
        progressLock.unlock()
        if let savedFailure { throw NeoLemmixMobileLibraryError.progressSave(savedFailure) }

        let data = try Data(contentsOf: entry.level.url)
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
              let level = NxlvLevel(text: text),
              Self.digest(data) == entry.level.sourceRevision else {
            throw MobileSessionError.changedLevel
        }
        guard let stylesRoot = entry.stylesRoot else {
            throw NeoLemmixMobileLibraryError.incompleteStyles(level.title)
        }
        let resolution = NxlvStyleResolver(stylesRootURL: stylesRoot).resolve(level: level)
        try Task.checkCancellation()
        guard resolution.isComplete else { throw NeoLemmixMobileLibraryError.incompleteStyles(level.title) }
        let result = NxlvRenderer(retainsVisualLayers: true).render(level: level, resolution: resolution)
        try Task.checkCancellation()
        guard let rendered = result.renderedLevel, !result.hasErrors,
              NeoLemmixRules.unsupportedFeatures(level: level, renderedLevel: rendered).isEmpty else {
            throw NeoLemmixMobileLibraryError.unsupportedLevel(level.title)
        }
        let simulation = try NeoLemmixSimulation(level: level, renderedLevel: rendered)
        let controls = NxlvSkill.allCases.filter { level.skillQuantities[$0] != nil }.map(NeoLemmixSkill.init)
        let sprites = try NeoLemmixMobileSpriteSet(stylesRootURL: stylesRoot, themeStyle: level.themeStyle)
        let renderer = NeoLemmixMobileSceneRenderer(renderedLevel: rendered, sprites: sprites,
                                                   stylesRootURL: stylesRoot)
        let gadgetSounds = NeoLemmixSoundCue.gadgetSounds(for: rendered.gadgets, resolution: resolution)
        let fingerprint = try Self.fingerprint(levelData: data, resolution: resolution)
        let identifier = entry.identifier
        progressLock.lock()
        defer { progressLock.unlock() }
        if let progressFailure { throw NeoLemmixMobileLibraryError.progressSave(progressFailure) }
        if progress.currentIndex != index || progress.currentLevelIdentifier != identifier {
            var updated = progress
            updated.currentIndex = index
            updated.currentLevelIdentifier = identifier
            try storage.save(updated, name: "neolemmix-library")
            progress = updated
        }
        let session = NeoLemmixMobileSession(simulation: simulation, controls: controls,
            engineFingerprint: Self.engineFingerprint, levelIdentifier: identifier,
            levelIndex: index, levelFingerprint: fingerprint, renderer: renderer.render,
            gadgetSounds: gadgetSounds,
            soundDirectory: stylesRoot.deletingLastPathComponent().appendingPathComponent("sound")) { [weak self] result in
                self?.record(result, key: identifier, at: index)
            }
        return MobileLevelContent(summary: entry.summary, session: session)
    }

    private func record(_ simulation: NeoLemmixSimulation, key: String, at index: Int) {
        guard simulation.isComplete, simulation.didWin else { return }
        progressLock.lock()
        defer { progressLock.unlock() }
        guard progressFailure == nil else { return }
        var updated = progress
        updated.currentIndex = index
        updated.currentLevelIdentifier = key
        updated.bestSaved[key] = max(updated.bestSaved[key] ?? 0, simulation.snapshot().savedCount)
        do {
            try storage.save(updated, name: "neolemmix-library")
            progress = updated
        } catch {
            progressFailure = error.localizedDescription
        }
    }

    private static func fingerprint(levelData: Data, resolution: NxlvStyleResolution) throws -> String {
        var hasher = SHA256()
        hasher.update(data: levelData)
        for asset in resolution.assets {
            let urls = asset.graphicURLs + [asset.metadataURL].compactMap { $0 }
            for url in urls.sorted(by: { $0.path < $1.path }) {
                hasher.update(data: Data(url.lastPathComponent.utf8))
                hasher.update(data: try Data(contentsOf: url))
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private enum NeoLemmixMobileLibraryError: Error, LocalizedError {
    case noSupportedLevels
    case incompleteStyles(String)
    case unsupportedLevel(String)
    case progressSave(String)

    var errorDescription: String? {
        switch self {
        case .noSupportedLevels:
            L10n.text("The imported NeoLemmix folder has no levels with resolved styles.")
        case let .incompleteStyles(level):
            L10n.text("NeoLemmix styles for \(level) are incomplete.")
        case let .unsupportedLevel(level):
            L10n.text("\(level) uses a feature that is not supported in this NeoLemmix build.")
        case let .progressSave(reason):
            L10n.text("NeoLemmix progress could not be saved: \(reason)")
        }
    }
}
