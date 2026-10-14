import Foundation
import ImageIO
import NxlvKit

public typealias MobileContentValidator = @Sendable (URL) throws -> Void

/// Identifies the native game format whose player-owned data is being installed.
public enum MobileGameDataKind: String, CaseIterable, Codable, Equatable, Sendable {
    case classic
    case lemmings2
    case lemmings3
    case neoLemmix

    fileprivate var directoryName: String {
        switch self {
        case .classic: "Game Data"
        case .lemmings2: "Lemmings 2"
        case .lemmings3: "Lemmings 3"
        case .neoLemmix: "NeoLemmix"
        }
    }

    public var displayTitle: String {
        switch self {
        case .classic: "Classic Lemmings"
        case .lemmings2: "Lemmings 2"
        case .lemmings3: "Lemmings 3"
        case .neoLemmix: "NeoLemmix"
        }
    }
}

/**
 * Resolves the common NeoLemmix install layout and direct pack folders.
 */
public enum MobileNeoLemmixDataLayout {
    public static func levelsRoot(in directory: URL) -> URL {
        let manager = FileManager.default
        let directPackMarkers = ["levels.nxmi", "info.nxmi"].contains {
            manager.fileExists(atPath: directory.appendingPathComponent($0).path)
        } || ((try? manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .contains { $0.pathExtension.caseInsensitiveCompare("nxlv") == .orderedSame }
        if directPackMarkers { return directory }

        let nested = directory.appendingPathComponent("levels", isDirectory: true)
        var isDirectory: ObjCBool = false
        return manager.fileExists(atPath: nested.path, isDirectory: &isDirectory) && isDirectory.boolValue
            ? nested : directory
    }

    public static func stylesRoot(in directory: URL) -> URL {
        let nested = directory.appendingPathComponent("styles", isDirectory: true)
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: nested.path, isDirectory: &isDirectory) && isDirectory.boolValue
            ? nested : directory
    }
}

/// Stages and validates player-owned game data before replacing the live copy.
public struct MobileContentStore: Sendable {
    public static let maximumImportBytes: Int64 = 2 * 1_024 * 1_024 * 1_024
    public static let maximumImportEntries = 100_000

    public let root: URL
    public var gameDataDirectory: URL { root.appendingPathComponent("Game Data", isDirectory: true) }
    public var checkpointURL: URL { root.appendingPathComponent("Checkpoints/current.json") }

    private let validators: [MobileGameDataKind: MobileContentValidator]

    public func dataDirectory(for kind: MobileGameDataKind) -> URL {
        kind == .classic
            ? gameDataDirectory
            : root.appendingPathComponent(kind.directoryName, isDirectory: true)
    }

    public init(fileManager: FileManager = .default) throws {
        let applicationSupport = try fileManager.url(
            for: MobileStorage.localDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        root = applicationSupport.appendingPathComponent("Ultimate Lemmings/iOS", isDirectory: true)
        validators = Self.defaultValidators
    }

    public init(root: URL) {
        self.root = root
        validators = Self.defaultValidators
    }

    public init(root: URL, validator: @escaping MobileContentValidator) {
        self.root = root
        validators = [.classic: validator]
    }

    public init(root: URL, validators: [MobileGameDataKind: MobileContentValidator]) {
        self.root = root
        self.validators = validators
    }

    public func loadLibrary(bundledDirectory: URL? = nil) throws -> ClassicMobileLibrary? {
        if FileManager.default.fileExists(atPath: gameDataDirectory.path) {
            return try ClassicMobileLibrary(directory: gameDataDirectory)
        }
        guard let bundledDirectory,
              FileManager.default.fileExists(atPath: bundledDirectory.path) else { return nil }
        return try ClassicMobileLibrary(directory: bundledDirectory)
    }

    public func loadLemmings2Library(storage: MobileStorage) throws -> Lemmings2MobileLibrary? {
        let directory = dataDirectory(for: .lemmings2)
        guard FileManager.default.fileExists(atPath: directory.path) else { return nil }
        return try Lemmings2MobileLibrary(directory: directory, storage: storage)
    }

    public func loadLemmings3Library(storage: MobileStorage) throws -> Lemmings3MobileLibrary? {
        let directory = dataDirectory(for: .lemmings3)
        guard FileManager.default.fileExists(atPath: directory.path) else { return nil }
        return try Lemmings3MobileLibrary(directory: directory, storage: storage)
    }

    /// Copies a document-picker folder only after complete staged validation.
    public func install(directory source: URL, for kind: MobileGameDataKind = .classic) throws {
        guard let validator = validators[kind] else { throw MobileContentStoreError.validatorUnavailable(kind) }
        let manager = FileManager.default
        let values = try source.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { throw MobileContentStoreError.notDirectory }
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        let destination = dataDirectory(for: kind)
        try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let staging = root.appendingPathComponent("Import-\(kind.rawValue)-\(UUID().uuidString)", isDirectory: true)
        let backup = root.appendingPathComponent("Previous-\(kind.rawValue)-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        var committed = false
        defer {
            if !committed { try? manager.removeItem(at: staging) }
            try? manager.removeItem(at: backup)
        }

        guard let walker = manager.enumerator(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { throw MobileContentStoreError.unreadable }
        var total: Int64 = 0
        var entryCount = 0
        let sourceParts = source.standardizedFileURL.pathComponents
        for case let item as URL in walker {
            entryCount += 1
            try Self.validateImportEntryCount(entryCount)
            let itemValues = try item.resourceValues(forKeys: [
                .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
            ])
            guard itemValues.isSymbolicLink != true else { throw MobileContentStoreError.symbolicLink }
            let parts = item.standardizedFileURL.pathComponents
            guard parts.starts(with: sourceParts) else { throw MobileContentStoreError.unreadable }
            let relative = parts.dropFirst(sourceParts.count)
            guard !relative.isEmpty,
                  !relative.contains(".."),
                  relative.count <= 32 else { throw MobileContentStoreError.unreadable }
            let destination = relative.reduce(staging) { $0.appendingPathComponent($1) }
            if itemValues.isDirectory == true {
                try manager.createDirectory(at: destination, withIntermediateDirectories: true)
            } else if itemValues.isRegularFile == true {
                guard let reportedSize = itemValues.fileSize, reportedSize >= 0 else {
                    throw MobileContentStoreError.unreadable
                }
                let fileSize = Int64(reportedSize)
                guard fileSize >= 0, fileSize <= Self.maximumImportBytes - total else {
                    throw MobileContentStoreError.tooLarge
                }
                total += fileSize
                try manager.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try manager.copyItem(at: item, to: destination)
            }
        }

        try validator(staging)
        if manager.fileExists(atPath: destination.path) {
            try manager.moveItem(at: destination, to: backup)
        }
        do {
            try manager.moveItem(at: staging, to: destination)
            var installed = destination
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try installed.setResourceValues(values)
            committed = true
        } catch {
            if manager.fileExists(atPath: destination.path) {
                try? manager.removeItem(at: destination)
            }
            if manager.fileExists(atPath: backup.path) {
                try? manager.moveItem(at: backup, to: destination)
            }
            throw error
        }
    }

    static func validateImportEntryCount(_ count: Int) throws {
        guard count <= maximumImportEntries else { throw MobileContentStoreError.tooManyEntries }
    }

    private static let defaultValidators: [MobileGameDataKind: MobileContentValidator] = [
        .classic: { directory in _ = try ClassicMobileLibrary(directory: directory) },
        .lemmings2: validateLemmings2Data,
        .lemmings3: validateLemmings3Data,
        .neoLemmix: validateNeoLemmixData,
    ]

    private static func validateLemmings2Data(at directory: URL) throws {
        let campaign = try Lemmings2Campaign(root: directory)
        let styles = try Lemmings2Campaign.styleNames.map { styleName in
            let styleURL = directory.appendingPathComponent("STYLES/\(styleName).DAT")
            return try Lemmings2Style(data: Data(contentsOf: styleURL))
        }
        _ = try Lemmings2Sprites(data: Data(contentsOf: directory.appendingPathComponent("VLEMMS.DAT")))
        let masks = try Lemmings2TerrainMasks(root: directory)
        for level in campaign.levels {
            guard styles.indices.contains(level.style) else { throw MobileContentStoreError.invalidData(.lemmings2) }
            let style = styles[level.style]
            _ = try Lemmings2Runtime(level: level, style: style, masks: masks, total: 60)
        }
    }

    private static func validateLemmings3Data(at directory: URL) throws {
        for tribe in Lemmings3ClassicCampaign.Tribe.allCases {
            let campaign = try Lemmings3ClassicCampaign(root: directory, tribe: tribe)
            let style = try Lemmings3Style(directory: directory.appendingPathComponent("STYLES"),
                                           number: tribe.rawValue, lemmingStyle: tribe.spriteStyle)
            let graphicsPrefix = String(format: "GRAPHICS/TRIBE%03d", tribe.spriteStyle)
            let sprites = try Lemmings3Sprites(
                index: Data(contentsOf: directory.appendingPathComponent(graphicsPrefix + ".IND")),
                commands: Data(contentsOf: directory.appendingPathComponent(graphicsPrefix + ".CMP")))
            _ = try Lemmings3Sprites.palette(
                Data(contentsOf: directory.appendingPathComponent(graphicsPrefix + ".PAL")), over: style.palette)
            _ = try Lemmings3MobileSceneRenderer.panelFrame(directory: directory, tribe: tribe.spriteStyle)
            guard sprites.animations.count >= 2,
                  sprites.animations.prefix(2).allSatisfy({ !$0.frames.isEmpty }) else {
                throw MobileContentStoreError.invalidData(.lemmings3)
            }
            _ = try style.constructionTile()
            for tool in Lemmings3Runtime.Tool.allCases {
                _ = try style.permanent.image(object: tool.sourceIdentifier, palette: style.palette)
            }
            var validatedCreatureKinds = Set<Lemmings3Runtime.Creature.Kind>()
            for level in campaign.levels {
                let permanent = try Lemmings3Objects(data: Data(contentsOf: directory.appendingPathComponent(
                    String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
                let temporary = try Lemmings3Objects(data: Data(contentsOf: directory.appendingPathComponent(
                    String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
                _ = try Lemmings3Scene(level: level, style: style, permanent: permanent, temporary: temporary)
                let runtime = try Lemmings3Runtime(level: level, style: style, permanent: permanent,
                                                   temporary: temporary, total: 20)
                let newCreatureKinds = Set(runtime.creatures.map(\.kind)).subtracting(validatedCreatureKinds)
                try validateLemmings3CreatureSpriteBanks(directory: directory,
                    kinds: newCreatureKinds, palette: style.palette)
                validatedCreatureKinds.formUnion(newCreatureKinds)
            }
        }
    }

    static func validateLemmings3CreatureSpriteBanks(
        directory: URL,
        kinds: Set<Lemmings3Runtime.Creature.Kind>,
        palette: [UInt8]
    ) throws {
        for kind in kinds {
            let prefix = String(format: "GRAPHICS/CREAT%03d", (kind.rawValue - 10008) / 2)
            let bank = try Lemmings3Sprites(
                index: Data(contentsOf: directory.appendingPathComponent(prefix + ".IND")),
                commands: Data(contentsOf: directory.appendingPathComponent(prefix + ".CMP")))
            _ = try Lemmings3Sprites.palette(
                Data(contentsOf: directory.appendingPathComponent(prefix + ".PAL")), over: palette)
            guard bank.animations.count >= 2,
                  bank.animations.prefix(2).allSatisfy({ !$0.frames.isEmpty }) else {
                throw MobileContentStoreError.invalidData(.lemmings3)
            }
        }
    }

    private static func validateNeoLemmixData(at directory: URL) throws {
        let levelsRoot = MobileNeoLemmixDataLayout.levelsRoot(in: directory)
        let stylesRoot = MobileNeoLemmixDataLayout.stylesRoot(in: directory)
        let packs = try NeoLemmixPackLibrary.discover(in: levelsRoot)
        guard !packs.isEmpty else { throw MobileContentStoreError.invalidData(.neoLemmix) }
        let resolver = NxlvStyleResolver(stylesRootURL: stylesRoot)
        let renderer = NxlvRenderer()
        var validatedSpriteThemes = Set<String>()
        var supportedLevelCount = 0
        for levelFile in packs.flatMap(\.levels) {
            let data = try Data(contentsOf: levelFile.url)
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
                  let level = NxlvLevel(text: text) else {
                throw MobileContentStoreError.invalidData(.neoLemmix)
            }
            let resolution = resolver.resolve(level: level)
            // A pack can include levels that need styles the player did not import.
            // The mobile library omits those levels and keeps compatible entries.
            guard resolution.isComplete else { continue }
            let result = renderer.render(level: level, resolution: resolution)
            guard let rendered = result.renderedLevel, !result.hasErrors,
                  NeoLemmixRules.unsupportedFeatures(level: level, renderedLevel: rendered).isEmpty else {
                throw MobileContentStoreError.invalidData(.neoLemmix)
            }
            let theme = level.themeStyle.isEmpty ? "default" : level.themeStyle.lowercased()
            if validatedSpriteThemes.insert(theme).inserted {
                try validateNeoLemmixSprites(level: level, resolver: resolver)
            }
            _ = try NeoLemmixSimulation(level: level, renderedLevel: rendered)
            supportedLevelCount += 1
        }
        guard supportedLevelCount > 0 else { throw MobileContentStoreError.invalidData(.neoLemmix) }
    }

    private static func validateNeoLemmixSprites(level: NxlvLevel, resolver: NxlvStyleResolver) throws {
        let themeName = level.themeStyle.isEmpty ? "default" : level.themeStyle
        let themeResolution = resolver.resolve(references: [
            NxlvStyleAssetReference(kind: .theme, style: themeName),
        ])
        guard themeResolution.isComplete,
              let themeURL = themeResolution.assets.first?.metadataURL,
              let themeText = try? String(contentsOf: themeURL, encoding: .utf8) else {
            throw MobileContentStoreError.invalidData(.neoLemmix)
        }
        let theme = NxlvParser.parse(themeText)
        let spriteStyle = theme.trimmedLine("lemmings") ?? "default"
        let spriteResolution = resolver.resolve(references: [
            NxlvStyleAssetReference(kind: .lemmings, style: spriteStyle),
        ])
        guard spriteResolution.isComplete,
              let spriteAsset = spriteResolution.assets.first,
              let schemeURL = spriteAsset.metadataURL,
              let schemeText = try? String(contentsOf: schemeURL, encoding: .utf8),
              let animationSections = NxlvParser.parse(schemeText).section("animations") else {
            throw MobileContentStoreError.invalidData(.neoLemmix)
        }
        var graphics: [String: URL] = [:]
        for url in spriteAsset.graphicURLs {
            let name = url.deletingPathExtension().lastPathComponent.lowercased()
            guard graphics.updateValue(url, forKey: name) == nil else {
                throw MobileContentStoreError.invalidData(.neoLemmix)
            }
        }
        var animations: [String: NxlvSection] = [:]
        for section in animationSections.subsections {
            guard animations.updateValue(section, forKey: section.keyword.lowercased()) == nil else {
                throw MobileContentStoreError.invalidData(.neoLemmix)
            }
        }
        for name in NeoLemmixMobileSupport.requiredAnimationNames {
            guard let animation = animations[name],
                  let frameCount = animation.numeric("frames"), frameCount > 0,
                  let right = animation.section("right"), let left = animation.section("left"),
                  let rightX = right.numeric("foot_x"), let rightY = right.numeric("foot_y"),
                  let leftX = left.numeric("foot_x"), let leftY = left.numeric("foot_y"),
                  let url = graphics[name],
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  width > 0, width <= 8_192, height > 0, height <= 8_192,
                  width <= 16_777_216 / height,
                  width.isMultiple(of: 2), height.isMultiple(of: frameCount) else {
                throw MobileContentStoreError.invalidData(.neoLemmix)
            }
            let frameWidth = width / 2
            let frameHeight = height / frameCount
            guard (0...frameWidth).contains(rightX), (0...frameHeight).contains(rightY),
                  (0...frameWidth).contains(leftX), (0...frameHeight).contains(leftY) else {
                throw MobileContentStoreError.invalidData(.neoLemmix)
            }
        }
    }
}

public enum MobileContentStoreError: Error, LocalizedError, Equatable {
    case notDirectory
    case unreadable
    case symbolicLink
    case tooLarge
    case tooManyEntries
    case validatorUnavailable(MobileGameDataKind)
    case invalidData(MobileGameDataKind)

    public var errorDescription: String? {
        switch self {
        case .notDirectory: return "Choose a folder that contains the original game data."
        case .unreadable: return "The selected game-data folder could not be read safely."
        case .symbolicLink: return "Remove symbolic links from the game-data folder."
        case .tooLarge: return "The selected folder is larger than 2 GB."
        case .tooManyEntries: return "The selected folder contains too many items."
        case let .validatorUnavailable(kind): return "The \(kind.displayTitle) data validator is not available."
        case let .invalidData(kind): return "The selected \(kind.displayTitle) data is incomplete or invalid."
        }
    }
}
