import CryptoKit
import Foundation
import NxlvKit

/// A fixed-size, top-to-bottom RGBA8 level preview.
struct LevelPreviewBitmap: Sendable {
    let width: Int
    let height: Int
    let rgba: Data

    var byteCount: Int { rgba.count }
}

/// The source data needed to reproduce one level preview.
enum LevelPreviewSource: Sendable {
    case classic(
        dataSet: ClassicDataSet,
        root: URL,
        levelIndex: Int,
        sourceFingerprint: String?)
    case fanClassic(
        pack: URL,
        entry: FanLevelLibrary.Entry,
        archiveFingerprint: String,
        portsRoot: URL)
    case lemmings2(
        root: URL,
        selection: Lemmings2PlayWindow.LevelSelection,
        expectedLevelID: String)
    case lemmings3(
        root: URL,
        selection: Lemmings3PlayWindow.LevelSelection,
        expectedLevelID: String)

    fileprivate var cacheIdentity: String {
        switch self {
        case let .classic(dataSet, root, levelIndex, sourceFingerprint):
            return ["classic", root.standardizedFileURL.path, dataSet.identifierKey,
                    String(levelIndex), sourceFingerprint ?? "bundled"].joined(separator: "\u{0}")
        case let .fanClassic(pack, entry, archiveFingerprint, portsRoot):
            return ["fan-classic", pack.standardizedFileURL.path, entry.file,
                    String(entry.section ?? -1), archiveFingerprint,
                    portsRoot.standardizedFileURL.path].joined(separator: "\u{0}")
        case let .lemmings2(root, selection, expectedLevelID):
            return ["lemmings2", root.standardizedFileURL.path,
                    String(selection.tribe), String(selection.level), expectedLevelID]
                .joined(separator: "\u{0}")
        case let .lemmings3(root, selection, expectedLevelID):
            return ["lemmings3", root.standardizedFileURL.path,
                    String(selection.tribe.rawValue), String(selection.level), expectedLevelID]
                .joined(separator: "\u{0}")
        }
    }

    /**
     * Identifies the level data and every visual or physics dependency used by this source.
     */
    func sourceRevision(rootRevision: String? = nil) throws -> String {
        switch self {
        case let .classic(_, root, _, sourceFingerprint):
            guard let revision = sourceFingerprint
                    ?? FanLevelLibrary.directoryFingerprint(root) else {
                throw LevelPreviewError.levelUnavailable
            }
            return revision
        case let .fanClassic(_, _, archiveFingerprint, _):
            return archiveFingerprint
        case let .lemmings2(root, _, _), let .lemmings3(root, _, _):
            guard let dependency = try LevelPreviewRenderer.dependencyFingerprint(for: self) else {
                throw LevelPreviewError.levelUnavailable
            }
            guard let content = rootRevision
                    ?? FanLevelLibrary.directoryFingerprint(root) else {
                throw LevelPreviewError.levelUnavailable
            }
            return dependency + ":" + content
        }
    }
}

/// A revision-aware request for a reproducible level preview.
struct LevelPreviewRequest: Sendable {
    static let currentRendererRevision = "level-preview-rgba-1"

    let identity: LevelCatalogueIdentity
    let catalogueRevision: String
    let rendererRevision: String
    let source: LevelPreviewSource

    init(
        identity: LevelCatalogueIdentity,
        catalogueRevision: String,
        source: LevelPreviewSource,
        rendererRevision: String = currentRendererRevision
    ) {
        self.identity = identity
        self.catalogueRevision = catalogueRevision
        self.rendererRevision = rendererRevision
        self.source = source
    }

    var artworkKey: String {
        [rendererRevision, catalogueRevision, identity.engine.rawValue,
         identity.packID, identity.levelID, source.cacheIdentity]
            .joined(separator: "\u{0}")
    }
}

/// Keeps a bounded set of previews and coalesces concurrent requests.
actor LevelPreviewStore {
    static let shared = LevelPreviewStore()

    private struct CacheEntry {
        let bitmap: LevelPreviewBitmap
        var access: UInt64
    }

    private struct InFlightRender {
        let generation: UUID
        let task: Task<Void, Never>
        var waiters: [UUID: CheckedContinuation<LevelPreviewBitmap, Error>]
    }

    private struct StorageIdentity {
        let key: String
        let dependencyFingerprint: String?
    }

    private enum RenderResult: Sendable {
        case success(LevelPreviewBitmap)
        case failure(String)
        case cancelled
    }

    private let maximumCost: Int
    private var cache: [String: CacheEntry] = [:]
    private var inFlight: [String: InFlightRender] = [:]
    private var totalCost = 0
    private var access = UInt64(0)

    init(maximumCost: Int = 32 * 1_024 * 1_024) {
        self.maximumCost = max(LevelPreviewRenderer.outputByteCount, maximumCost)
    }

    func bitmap(for request: LevelPreviewRequest) async throws -> LevelPreviewBitmap {
        try Task.checkCancellation()
        let storage = try await storageIdentity(for: request)
        let key = storage.key
        try Task.checkCancellation()
        if var entry = cache[key] {
            access &+= 1
            entry.access = access
            cache[key] = entry
            try Task.checkCancellation()
            return entry.bitmap
        }

        let waiter = UUID()
        return try await withTaskCancellationHandler {
            let bitmap = try await withCheckedThrowingContinuation { continuation in
                enqueue(
                    continuation,
                    waiter: waiter,
                    key: key,
                    request: request,
                    dependencyFingerprint: storage.dependencyFingerprint)
            }
            try Task.checkCancellation()
            return bitmap
        } onCancel: {
            Task { await self.cancelWaiter(waiter, for: key) }
        }
    }

    func removeAll() {
        let renders = Array(inFlight.values)
        inFlight.removeAll(keepingCapacity: false)
        for render in renders {
            render.task.cancel()
            for continuation in render.waiters.values {
                continuation.resume(throwing: CancellationError())
            }
        }
        cache.removeAll(keepingCapacity: false)
        totalCost = 0
    }

    private func storageIdentity(for request: LevelPreviewRequest) async throws -> StorageIdentity {
        switch request.source {
        case .classic, .fanClassic:
            return StorageIdentity(key: request.artworkKey, dependencyFingerprint: nil)
        case .lemmings2, .lemmings3:
            break
        }
        let fingerprintTask = Task.detached(priority: .userInitiated) {
            try LevelPreviewRenderer.dependencyFingerprint(for: request)
        }
        let fingerprint = try await withTaskCancellationHandler {
            try await fingerprintTask.value
        } onCancel: {
            fingerprintTask.cancel()
        }
        try Task.checkCancellation()
        return StorageIdentity(
            key: fingerprint.map { request.artworkKey + "\u{0}" + $0 } ?? request.artworkKey,
            dependencyFingerprint: fingerprint)
    }

    private func enqueue(
        _ continuation: CheckedContinuation<LevelPreviewBitmap, Error>,
        waiter: UUID,
        key: String,
        request: LevelPreviewRequest,
        dependencyFingerprint: String?
    ) {
        if var render = inFlight[key] {
            render.waiters[waiter] = continuation
            inFlight[key] = render
            return
        }

        let generation = UUID()
        let task = Task.detached(priority: .userInitiated) {
            let result: RenderResult
            do {
                result = .success(try LevelPreviewRenderer.render(
                    request,
                    expectedDependencyFingerprint: dependencyFingerprint))
            } catch is CancellationError {
                result = .cancelled
            } catch {
                result = .failure(error.localizedDescription)
            }
            await self.completeRender(result, key: key, generation: generation)
        }
        inFlight[key] = InFlightRender(
            generation: generation,
            task: task,
            waiters: [waiter: continuation])
    }

    private func cancelWaiter(_ waiter: UUID, for key: String) {
        guard var render = inFlight[key],
              let continuation = render.waiters.removeValue(forKey: waiter) else { return }
        continuation.resume(throwing: CancellationError())
        if render.waiters.isEmpty {
            inFlight[key] = nil
            render.task.cancel()
        } else {
            inFlight[key] = render
        }
    }

    private func completeRender(
        _ result: RenderResult,
        key: String,
        generation: UUID
    ) {
        guard let render = inFlight[key], render.generation == generation else { return }
        inFlight[key] = nil
        if case let .success(bitmap) = result {
            insert(bitmap, for: key)
        }
        for continuation in render.waiters.values {
            switch result {
            case let .success(bitmap):
                continuation.resume(returning: bitmap)
            case let .failure(description):
                continuation.resume(throwing: LevelPreviewRenderFailure(description))
            case .cancelled:
                continuation.resume(throwing: CancellationError())
            }
        }
    }

    private func insert(_ bitmap: LevelPreviewBitmap, for key: String) {
        if let previous = cache.removeValue(forKey: key) {
            totalCost -= previous.bitmap.byteCount
        }
        access &+= 1
        cache[key] = CacheEntry(bitmap: bitmap, access: access)
        totalCost += bitmap.byteCount

        while totalCost > maximumCost,
              let oldest = cache.min(by: { $0.value.access < $1.value.access }) {
            totalCost -= oldest.value.bitmap.byteCount
            cache.removeValue(forKey: oldest.key)
        }
    }
}

private struct LevelPreviewRenderFailure: LocalizedError, Sendable {
    let description: String

    init(_ description: String) {
        self.description = description
    }

    var errorDescription: String? { description }
}

private enum LevelPreviewError: LocalizedError, Sendable {
    case contentChanged
    case levelUnavailable
    case invalidBitmap

    var errorDescription: String? {
        switch self {
        case .contentChanged:
            "The selected level data changed. Open Level Select and choose it again."
        case .levelUnavailable:
            "The selected level is not available."
        case .invalidBitmap:
            "The level renderer returned invalid bitmap data."
        }
    }
}

private enum LevelPreviewRenderer {
    private struct Dependency {
        let label: String
        let url: URL
        let data: Data?

        init(_ label: String, _ url: URL, data: Data? = nil) {
            self.label = label
            self.url = url
            self.data = data
        }
    }

    static let width = 320
    static let height = 160
    static let outputByteCount = width * height * 4

    static func render(
        _ request: LevelPreviewRequest,
        expectedDependencyFingerprint: String?
    ) throws -> LevelPreviewBitmap {
        try Task.checkCancellation()
        let bitmap: LevelPreviewBitmap
        switch request.source {
        case let .classic(dataSet, root, levelIndex, sourceFingerprint):
            bitmap = try renderClassic(
                dataSet: dataSet,
                root: root,
                levelIndex: levelIndex,
                sourceFingerprint: sourceFingerprint)
        case let .fanClassic(pack, entry, archiveFingerprint, portsRoot):
            bitmap = try renderFanClassic(
                pack: pack,
                entry: entry,
                archiveFingerprint: archiveFingerprint,
                portsRoot: portsRoot)
        case let .lemmings2(root, selection, expectedLevelID):
            bitmap = try renderLemmings2(
                root: root,
                selection: selection,
                expectedLevelID: expectedLevelID)
        case let .lemmings3(root, selection, expectedLevelID):
            bitmap = try renderLemmings3(
                root: root,
                selection: selection,
                expectedLevelID: expectedLevelID)
        }
        try Task.checkCancellation()
        if let expectedDependencyFingerprint,
           try dependencyFingerprint(for: request) != expectedDependencyFingerprint {
            throw LevelPreviewError.contentChanged
        }
        return bitmap
    }

    static func dependencyFingerprint(for request: LevelPreviewRequest) throws -> String? {
        try dependencyFingerprint(for: request.source)
    }

    static func dependencyFingerprint(for source: LevelPreviewSource) throws -> String? {
        switch source {
        case .classic, .fanClassic:
            return nil
        case let .lemmings2(root, selection, _):
            guard Lemmings2Campaign.tribeNames.indices.contains(selection.tribe),
                  (0..<10).contains(selection.level),
                  Lemmings2Campaign.styleNames.indices.contains(selection.tribe) else {
                throw LevelPreviewError.levelUnavailable
            }
            let number = selection.tribe * 10 + selection.level
            return try fingerprint(files: [
                Dependency(
                    "level",
                    root.appendingPathComponent(String(format: "LEVELS/LEVEL%03d.DAT", number))),
                Dependency(
                    "style",
                    root.appendingPathComponent(
                        "STYLES/\(Lemmings2Campaign.styleNames[selection.tribe]).DAT"))
            ])
        case let .lemmings3(root, selection, _):
            guard (0..<30).contains(selection.level) else {
                throw LevelPreviewError.levelUnavailable
            }
            let number = selection.tribe.firstLevel + selection.level
            let levelURL = root.appendingPathComponent(
                String(format: "LEVELS/LEVEL%03d.DAT", number))
            let levelData = try read(levelURL)
            let level = try Lemmings3Level(data: levelData)
            let style = selection.tribe.rawValue
            let styles = root.appendingPathComponent("STYLES")
            return try fingerprint(files: [
                Dependency("level", levelURL, data: levelData),
                Dependency("style-permanent-objects", styles.appendingPathComponent(
                    String(format: "PERM%03d.OBJ", style))),
                Dependency("style-permanent-frames", styles.appendingPathComponent(
                    String(format: "PERM%03d.FRL", style))),
                Dependency("style-permanent-blocks", styles.appendingPathComponent(
                    String(format: "PERM%03d.BLK", style))),
                Dependency("style-temporary-objects", styles.appendingPathComponent(
                    String(format: "TEMP%03d.OBJ", style))),
                Dependency("style-temporary-frames", styles.appendingPathComponent(
                    String(format: "TEMP%03d.FRL", style))),
                Dependency("style-temporary-blocks", styles.appendingPathComponent(
                    String(format: "TEMP%03d.BLK", style))),
                Dependency("style-palette", styles.appendingPathComponent(
                    String(format: "DATA%03d.PAL", style))),
                Dependency("tribe-palette", root.appendingPathComponent(
                    String(format: "GRAPHICS/TRIBE%03d.PAL", selection.tribe.spriteStyle))),
                Dependency("permanent-objects", root.appendingPathComponent(String(
                    format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))),
                Dependency("temporary-objects", root.appendingPathComponent(String(
                    format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference)))
            ])
        }
    }

    private static func renderClassic(
        dataSet: ClassicDataSet,
        root: URL,
        levelIndex: Int,
        sourceFingerprint: String?
    ) throws -> LevelPreviewBitmap {
        try validateDirectory(root, fingerprint: sourceFingerprint)
        guard dataSet.campaign.levels.indices.contains(levelIndex) else {
            throw LevelPreviewError.levelUnavailable
        }
        let entry = dataSet.campaign.levels[levelIndex]
        let artworkRoot: URL
        let fallbackRoot: URL?
        if dataSet.title == .ohYesMoreLemmings {
            artworkRoot = PortExclusivePack.artworkDirectory(for: entry, portsRoot: root)
            fallbackRoot = PortExclusivePack.fallbackArtworkDirectory(for: entry, portsRoot: root)
        } else {
            artworkRoot = root
            fallbackRoot = nil
        }
        let ground = try ClassicGroundSet.load(
            style: entry.level.groundStyle,
            from: artworkRoot,
            fallbackDirectory: fallbackRoot)
        let special = try classicSpecialGraphic(
            for: entry.level,
            root: artworkRoot,
            fallbackRoot: fallbackRoot)
        try Task.checkCancellation()
        let bitmap = try classicBitmap(
            level: entry.level,
            ground: ground,
            special: special,
            mechanics: ClassicDOSMechanics(title: dataSet.title, rank: entry.rank))
        try validateDirectory(root, fingerprint: sourceFingerprint)
        return bitmap
    }

    private static func renderFanClassic(
        pack: URL,
        entry: FanLevelLibrary.Entry,
        archiveFingerprint: String,
        portsRoot: URL
    ) throws -> LevelPreviewBitmap {
        guard FanLevelLibrary.archiveMatches(pack, fingerprint: archiveFingerprint) else {
            throw LevelPreviewError.contentChanged
        }
        let (level, styleName) = try FanLevelLibrary.level(entry, in: pack)
        let ground = try FanLevelLibrary.groundSet(
            for: level,
            styleName: styleName,
            portsRoot: portsRoot,
            pack: pack,
            entry: entry)
        let special = try FanLevelLibrary.specialGraphic(
            for: level,
            entry: entry,
            pack: pack,
            portsRoot: portsRoot)
        try Task.checkCancellation()
        let bitmap = try classicBitmap(
            level: level,
            ground: ground,
            special: special,
            mechanics: ClassicDOSMechanics(title: nil, rank: "Fan"))
        guard FanLevelLibrary.archiveMatches(pack, fingerprint: archiveFingerprint) else {
            throw LevelPreviewError.contentChanged
        }
        return bitmap
    }

    private static func classicSpecialGraphic(
        for level: ClassicLevel,
        root: URL,
        fallbackRoot: URL?
    ) throws -> ClassicSpecialGraphic? {
        guard level.specialStyle > 0 else { return nil }
        return try ClassicSpecialGraphic.load(
            index: level.specialStyle - 1,
            from: root,
            fallbackDirectory: fallbackRoot)
    }

    private static func classicBitmap(
        level: ClassicLevel,
        ground: ClassicGroundSet,
        special: ClassicSpecialGraphic?,
        mechanics: ClassicDOSMechanics
    ) throws -> LevelPreviewBitmap {
        let rendered = try ClassicLevelRenderer.render(
            level,
            groundSet: ground,
            specialGraphic: special)
        let simulation = try ClassicDOSSimulation(
            level: level,
            renderedLevel: rendered,
            mechanics: mechanics)
        let rgba = ClassicSceneFrame.rgba(rendered, simulation: simulation)
        return try crop(
            rgba: rgba,
            sourceWidth: rendered.width,
            sourceHeight: rendered.height,
            x: level.startX,
            y: 0)
    }

    private static func renderLemmings2(
        root: URL,
        selection: Lemmings2PlayWindow.LevelSelection,
        expectedLevelID: String
    ) throws -> LevelPreviewBitmap {
        try Task.checkCancellation()
        guard Lemmings2Campaign.tribeNames.indices.contains(selection.tribe),
              (0..<10).contains(selection.level) else {
            throw LevelPreviewError.levelUnavailable
        }
        let number = selection.tribe * 10 + selection.level
        let level = try Lemmings2Level(data: Data(contentsOf:
            root.appendingPathComponent(String(format: "LEVELS/LEVEL%03d.DAT", number))))
        guard level.fingerprint == expectedLevelID,
              level.style == selection.tribe,
              Lemmings2Campaign.styleNames.indices.contains(selection.tribe) else {
            throw LevelPreviewError.contentChanged
        }
        let styleName = Lemmings2Campaign.styleNames[selection.tribe]
        let style = try Lemmings2Style(data: Data(contentsOf:
            root.appendingPathComponent("STYLES/\(styleName).DAT")))
        let terrain = try Lemmings2Terrain(level: level, style: style)
        let scene = try lemmings2ScenePixels(
            terrain: terrain,
            objects: Lemmings2Objects(level: level, style: style))
        try Task.checkCancellation()
        return try crop(
            rgba: try indexedRGBA(pixels: scene, palette: style.palette),
            sourceWidth: terrain.image.width,
            sourceHeight: terrain.image.height,
            x: level.screenX,
            y: level.screenY)
    }

    private static func lemmings2ScenePixels(
        terrain: Lemmings2Terrain,
        objects: Lemmings2Objects
    ) throws -> [UInt8] {
        var pixels = terrain.image.pixels
        let width = terrain.image.width
        let height = terrain.image.height
        for part in objects.parts {
            try Task.checkCancellation()
            guard let frame = part.frames.first,
                  frame.pixels.count == frame.width * frame.height,
                  frame.opaque.count == frame.pixels.count else { continue }
            let originX = part.x + frame.x
            let originY = part.y + frame.y
            for sourceY in 0..<frame.height {
                let targetY = originY + sourceY
                guard (0..<height).contains(targetY) else { continue }
                for sourceX in 0..<frame.width {
                    let source = sourceY * frame.width + sourceX
                    guard frame.opaque[source] else { continue }
                    let targetX = originX + sourceX
                    guard (0..<width).contains(targetX) else { continue }
                    pixels[targetY * width + targetX] = frame.pixels[source]
                }
            }
        }
        return pixels
    }

    private static func renderLemmings3(
        root: URL,
        selection: Lemmings3PlayWindow.LevelSelection,
        expectedLevelID: String
    ) throws -> LevelPreviewBitmap {
        try Task.checkCancellation()
        guard (0..<30).contains(selection.level) else {
            throw LevelPreviewError.levelUnavailable
        }
        let number = selection.tribe.firstLevel + selection.level
        let level = try Lemmings3Level(data: Data(contentsOf:
            root.appendingPathComponent(String(format: "LEVELS/LEVEL%03d.DAT", number))))
        let currentLevelID = SHA256.hash(data: level.rawData)
            .map { String(format: "%02x", $0) }.joined()
        guard currentLevelID == expectedLevelID,
              level.style == selection.tribe.rawValue,
              level.lemmingStyle == selection.tribe.spriteStyle else {
            throw LevelPreviewError.contentChanged
        }
        let style = try Lemmings3Style(
            directory: root.appendingPathComponent("STYLES"),
            number: selection.tribe.rawValue)
        let permanent = try Lemmings3Objects(data: Data(contentsOf:
            root.appendingPathComponent(String(
                format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
        let temporary = try Lemmings3Objects(data: Data(contentsOf:
            root.appendingPathComponent(String(
                format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
        let scene = try Lemmings3Scene(
            level: level,
            style: style,
            permanent: permanent,
            temporary: temporary)
        try Task.checkCancellation()
        return try crop(
            rgba: Data(scene.image.rgba()),
            sourceWidth: scene.image.width,
            sourceHeight: scene.image.height,
            x: level.screenX,
            y: level.screenY)
    }

    private static func validateDirectory(_ root: URL, fingerprint: String?) throws {
        guard let fingerprint else { return }
        guard FanLevelLibrary.directoryFingerprint(root) == fingerprint else {
            throw LevelPreviewError.contentChanged
        }
    }

    private static func read(_ url: URL) throws -> Data {
        try Task.checkCancellation()
        let data = try Data(contentsOf: url)
        try Task.checkCancellation()
        return data
    }

    private static func fingerprint(files: [Dependency]) throws -> String {
        var manifest = Data()
        for file in files {
            try Task.checkCancellation()
            let data = try file.data ?? read(file.url)
            let digest = SHA256.hash(data: data)
                .map { String(format: "%02x", $0) }
                .joined()
            try Task.checkCancellation()
            manifest.append(contentsOf: file.label.utf8)
            manifest.append(0)
            manifest.append(contentsOf: digest.utf8)
            manifest.append(0)
        }
        try Task.checkCancellation()
        return SHA256.hash(data: manifest)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func indexedRGBA(pixels: [UInt8], palette: [UInt8]) throws -> Data {
        guard palette.count == 256 * 4 else { throw LevelPreviewError.invalidBitmap }
        var output = [UInt8](repeating: 0, count: pixels.count * 4)
        for (index, colour) in pixels.enumerated() {
            let source = Int(colour) * 4
            let destination = index * 4
            output[destination] = palette[source]
            output[destination + 1] = palette[source + 1]
            output[destination + 2] = palette[source + 2]
            output[destination + 3] = palette[source + 3]
        }
        return Data(output)
    }

    private static func crop(
        rgba: Data,
        sourceWidth: Int,
        sourceHeight: Int,
        x: Int,
        y: Int
    ) throws -> LevelPreviewBitmap {
        guard sourceWidth > 0, sourceHeight > 0,
              sourceWidth <= Int.max / sourceHeight,
              sourceWidth * sourceHeight <= Int.max / 4,
              rgba.count == sourceWidth * sourceHeight * 4 else {
            throw LevelPreviewError.invalidBitmap
        }
        let originX = min(max(0, x), max(0, sourceWidth - width))
        let originY = min(max(0, y), max(0, sourceHeight - height))
        let copyWidth = min(width, sourceWidth)
        let copyHeight = min(height, sourceHeight)
        var output = [UInt8](repeating: 0, count: outputByteCount)
        for alpha in stride(from: 3, to: output.count, by: 4) { output[alpha] = 255 }
        rgba.withUnsafeBytes { sourceBytes in
            guard let source = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            output.withUnsafeMutableBytes { outputBytes in
                guard let destination = outputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                for row in 0..<copyHeight {
                    let sourceOffset = ((originY + row) * sourceWidth + originX) * 4
                    let destinationOffset = row * width * 4
                    destination.advanced(by: destinationOffset).update(
                        from: source.advanced(by: sourceOffset),
                        count: copyWidth * 4)
                }
            }
        }
        return LevelPreviewBitmap(width: width, height: height, rgba: Data(output))
    }
}
