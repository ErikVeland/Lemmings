import Foundation

public enum NxlvStyleAssetKind: String, Sendable, Hashable {
    case theme
    case terrain
    case object
    case background
    case lemmings
}

public struct NxlvStyleAssetReference: Sendable, Hashable {
    public let kind: NxlvStyleAssetKind
    public let style: String
    public let piece: String?
    public let sourceLine: Int?

    public init(
        kind: NxlvStyleAssetKind,
        style: String,
        piece: String? = nil,
        sourceLine: Int? = nil
    ) {
        self.kind = kind
        self.style = style
        self.piece = piece
        self.sourceLine = sourceLine
    }
}

public enum NxlvStyleDiagnosticSeverity: String, Sendable {
    case warning
    case error
}

public enum NxlvStyleDiagnosticCode: String, Sendable {
    case stylesRootUnavailable
    case unreadableDirectory
    case unsafeIdentifier
    case unsafeResolvedPath
    case missingStyleIdentifier
    case missingPieceIdentifier
    case malformedBackgroundIdentifier
    case missingStyle
    case ambiguousStyle
    case missingAssetDirectory
    case ambiguousAssetDirectory
    case missingPieceGraphic
    case ambiguousPieceGraphic
    case missingPieceMetadata
    case ambiguousPieceMetadata
    case ambiguousAliasFile
    case malformedAlias
    case missingAliasField
    case malformedAliasIdentifier
    case malformedAliasInteger
    case ambiguousAlias
    case aliasCycle
    case aliasDepthExceeded
    case metadataTooLarge
    case unreadableMetadata
    case invalidMetadataEncoding
    case malformedMetadata
    case malformedMetadataInteger
    case missingMetadataField
    case unknownObjectEffect
}

public struct NxlvStyleDiagnostic: Sendable, Equatable {
    public let severity: NxlvStyleDiagnosticSeverity
    public let code: NxlvStyleDiagnosticCode
    public let message: String
    /// A level line for resolution errors, or a metadata line for metadata errors.
    public let line: Int?
    public let path: String?
    public let reference: NxlvStyleAssetReference?

    public init(
        severity: NxlvStyleDiagnosticSeverity,
        code: NxlvStyleDiagnosticCode,
        message: String,
        line: Int? = nil,
        path: String? = nil,
        reference: NxlvStyleAssetReference? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.line = line
        self.path = path
        self.reference = reference
    }
}

public struct NxlvResizeAxes: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let horizontal = NxlvResizeAxes(rawValue: 1 << 0)
    public static let vertical = NxlvResizeAxes(rawValue: 1 << 1)
    public static let both: NxlvResizeAxes = [.horizontal, .vertical]
}

public struct NxlvNineSliceMargins: Sendable, Equatable {
    public let top: Int?
    public let left: Int?
    public let right: Int?
    public let bottom: Int?

    public init(top: Int?, left: Int?, right: Int?, bottom: Int?) {
        self.top = top
        self.left = left
        self.right = right
        self.bottom = bottom
    }
}

public struct NxlvTerrainMetadata: Sendable, Equatable {
    public let isSteel: Bool
    public let isDeprecated: Bool
    public let resizeAxes: NxlvResizeAxes
    public let nineSlice: NxlvNineSliceMargins
    public let defaultWidth: Int?
    public let defaultHeight: Int?

    public init(
        isSteel: Bool,
        isDeprecated: Bool,
        resizeAxes: NxlvResizeAxes,
        nineSlice: NxlvNineSliceMargins,
        defaultWidth: Int?,
        defaultHeight: Int?
    ) {
        self.isSteel = isSteel
        self.isDeprecated = isDeprecated
        self.resizeAxes = resizeAxes
        self.nineSlice = nineSlice
        self.defaultWidth = defaultWidth
        self.defaultHeight = defaultHeight
    }
}

public enum NxlvObjectEffect: Sendable, Equatable {
    case none
    case entrance
    case exit
    case lockedExit
    case unlockButton
    case pickupSkill
    case trap
    case trapOnce
    case fire
    case water
    case teleporter
    case receiver
    case updraft
    case splatPad
    case antiSplatPad
    case splitter
    case oneWayLeft
    case oneWayRight
    case oneWayDown
    case oneWayUp
    case forceLeft
    case forceRight
    case background
    case animation
    case animationOnce
    case paint
    case neutralizer
    case deneutralizer
    case addSkill
    case removeSkills
    case portal
    case unknown(String)

    public init(keyword: String?) {
        guard let keyword else {
            self = .none
            return
        }

        switch keyword.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "": self = .none
        case "ENTRANCE": self = .entrance
        case "EXIT": self = .exit
        case "LOCKEDEXIT": self = .lockedExit
        case "UNLOCKBUTTON": self = .unlockButton
        case "PICKUPSKILL": self = .pickupSkill
        case "TRAP": self = .trap
        case "TRAPONCE": self = .trapOnce
        case "FIRE": self = .fire
        case "WATER": self = .water
        case "TELEPORTER": self = .teleporter
        case "RECEIVER": self = .receiver
        case "UPDRAFT": self = .updraft
        case "SPLATPAD": self = .splatPad
        case "ANTISPLATPAD": self = .antiSplatPad
        case "SPLITTER": self = .splitter
        case "ONEWAYLEFT": self = .oneWayLeft
        case "ONEWAYRIGHT": self = .oneWayRight
        case "ONEWAYDOWN": self = .oneWayDown
        case "ONEWAYUP": self = .oneWayUp
        case "FORCELEFT": self = .forceLeft
        case "FORCERIGHT": self = .forceRight
        case "BACKGROUND": self = .background
        case "NO_EFFECT", "ANIMATION": self = .animation
        case "ANIMATIONONCE": self = .animationOnce
        case "PAINT": self = .paint
        case "NEUTRALIZER": self = .neutralizer
        case "DENEUTRALIZER": self = .deneutralizer
        case "ADDSKILL": self = .addSkill
        case "REMOVESKILLS": self = .removeSkills
        case "PORTAL": self = .portal
        default: self = .unknown(keyword)
        }
    }
}

public enum NxlvAnimationInitialFrame: Sendable, Equatable {
    case index(Int)
    case random
}

public struct NxlvObjectAnimationMetadata: Sendable, Equatable {
    public let isPrimary: Bool
    public let name: String?
    public let frames: Int?
    public let usesHorizontalStrip: Bool
    public let zIndex: Int
    public let initialFrame: NxlvAnimationInitialFrame?
    public let offsetX: Int
    public let offsetY: Int
    public let nineSlice: NxlvNineSliceMargins
    public let startsHidden: Bool
    public let initialState: String?
    public let editorHidden: Bool
    public let declaredWidth: Int?
    public let declaredHeight: Int?

    public init(
        isPrimary: Bool,
        name: String?,
        frames: Int?,
        usesHorizontalStrip: Bool,
        zIndex: Int,
        initialFrame: NxlvAnimationInitialFrame?,
        offsetX: Int,
        offsetY: Int,
        nineSlice: NxlvNineSliceMargins,
        startsHidden: Bool,
        initialState: String?,
        editorHidden: Bool,
        declaredWidth: Int? = nil,
        declaredHeight: Int? = nil
    ) {
        self.isPrimary = isPrimary
        self.name = name
        self.frames = frames
        self.usesHorizontalStrip = usesHorizontalStrip
        self.zIndex = zIndex
        self.initialFrame = initialFrame
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.nineSlice = nineSlice
        self.startsHidden = startsHidden
        self.initialState = initialState
        self.editorHidden = editorHidden
        self.declaredWidth = declaredWidth
        self.declaredHeight = declaredHeight
    }
}

public struct NxlvObjectMetadata: Sendable, Equatable {
    public let effect: NxlvObjectEffect
    public let triggerX: Int?
    public let triggerY: Int?
    public let triggerWidth: Int?
    public let triggerHeight: Int?
    public let sound: String?
    public let keyFrame: Int?
    public let resizeAxes: NxlvResizeAxes
    public let defaultWidth: Int?
    public let defaultHeight: Int?
    public let isDeprecated: Bool
    public let editorCrop: Bool?
    public let digitX: Int?
    public let digitY: Int?
    public let digitAlignment: Int?
    public let digitLength: Int?
    public let animations: [NxlvObjectAnimationMetadata]

    public init(
        effect: NxlvObjectEffect,
        triggerX: Int?,
        triggerY: Int?,
        triggerWidth: Int?,
        triggerHeight: Int?,
        sound: String?,
        keyFrame: Int?,
        resizeAxes: NxlvResizeAxes,
        defaultWidth: Int?,
        defaultHeight: Int?,
        isDeprecated: Bool,
        editorCrop: Bool?,
        digitX: Int?,
        digitY: Int?,
        digitAlignment: Int?,
        digitLength: Int?,
        animations: [NxlvObjectAnimationMetadata]
    ) {
        self.effect = effect
        self.triggerX = triggerX
        self.triggerY = triggerY
        self.triggerWidth = triggerWidth
        self.triggerHeight = triggerHeight
        self.sound = sound
        self.keyFrame = keyFrame
        self.resizeAxes = resizeAxes
        self.defaultWidth = defaultWidth
        self.defaultHeight = defaultHeight
        self.isDeprecated = isDeprecated
        self.editorCrop = editorCrop
        self.digitX = digitX
        self.digitY = digitY
        self.digitAlignment = digitAlignment
        self.digitLength = digitLength
        self.animations = animations
    }
}

public struct NxlvTerrainMetadataDecodeResult: Sendable {
    public let metadata: NxlvTerrainMetadata
    public let diagnostics: [NxlvStyleDiagnostic]
}

public struct NxlvObjectMetadataDecodeResult: Sendable {
    public let metadata: NxlvObjectMetadata
    public let diagnostics: [NxlvStyleDiagnostic]
}

public enum NxlvStyleMetadataDecoder {
    public static func decodeTerrain(
        text: String,
        path: String? = nil
    ) -> NxlvTerrainMetadataDecodeResult {
        let parsed = NxlvParser.parseResult(text)
        var decoder = MetadataValueDecoder(
            document: parsed.document,
            path: path,
            parserDiagnostics: parsed.diagnostics
        )
        let root = parsed.document
        let metadata = NxlvTerrainMetadata(
            isSteel: root.hasLine("steel"),
            isDeprecated: root.hasLine("deprecated"),
            resizeAxes: resizeAxes(root),
            nineSlice: decoder.nineSlice(root),
            defaultWidth: decoder.integer(root, key: "default_width"),
            defaultHeight: decoder.integer(root, key: "default_height")
        )
        return NxlvTerrainMetadataDecodeResult(
            metadata: metadata,
            diagnostics: decoder.diagnostics
        )
    }

    public static func decodeObject(
        text: String,
        path: String? = nil
    ) -> NxlvObjectMetadataDecodeResult {
        let parsed = NxlvParser.parseResult(text)
        var decoder = MetadataValueDecoder(
            document: parsed.document,
            path: path,
            parserDiagnostics: parsed.diagnostics
        )
        let root = parsed.document
        let effectLine = root.lastLineRecord("effect")
        let effect = NxlvObjectEffect(keyword: effectLine?.value)
        if case let .unknown(keyword) = effect {
            decoder.append(
                severity: .error,
                code: .unknownObjectEffect,
                message: "Unknown object effect '\(keyword)'.",
                line: effectLine?.lineNumber
            )
        }

        let primarySections = root.allSections("primary_animation")
        var animationSections: [(section: NxlvSection, primary: Bool)] = []
        animationSections += primarySections.map { ($0, true) }
        animationSections += root.allSections("animation").map { ($0, false) }
        if primarySections.isEmpty {
            decoder.append(
                severity: .error,
                code: .missingMetadataField,
                message: "The object metadata has no $PRIMARY_ANIMATION section.",
                line: nil
            )
        } else if primarySections.count > 1 {
            decoder.append(
                severity: .error,
                code: .malformedMetadata,
                message: "The object metadata has more than one $PRIMARY_ANIMATION section.",
                line: primarySections[1].openingLine
            )
        }

        let animations = animationSections.map { item in
            decodeAnimation(item.section, isPrimary: item.primary, decoder: &decoder)
        }

        let decodedTriggerWidth = decoder.integer(root, key: "trigger_width")
        let decodedTriggerHeight = decoder.integer(root, key: "trigger_height")
        let triggerWidth: Int?
        let triggerHeight: Int?
        switch effect {
        case .entrance, .receiver:
            triggerWidth = decodedTriggerWidth ?? 1
            triggerHeight = decodedTriggerHeight ?? 1
        case .none, .background, .paint:
            triggerWidth = 0
            triggerHeight = 0
        default:
            triggerWidth = decodedTriggerWidth
            triggerHeight = decodedTriggerHeight
        }

        let metadata = NxlvObjectMetadata(
            effect: effect,
            triggerX: decoder.integer(root, key: "trigger_x"),
            triggerY: decoder.integer(root, key: "trigger_y"),
            triggerWidth: triggerWidth,
            triggerHeight: triggerHeight,
            sound: trimmed(root.line("sound")),
            keyFrame: decoder.integer(root, key: "key_frame"),
            resizeAxes: resizeAxes(root),
            defaultWidth: decoder.integer(root, key: "default_width"),
            defaultHeight: decoder.integer(root, key: "default_height"),
            isDeprecated: root.hasLine("deprecated"),
            editorCrop: decoder.boolean(root, key: "editor_crop"),
            digitX: decoder.integer(root, key: "digit_x"),
            digitY: decoder.integer(root, key: "digit_y"),
            digitAlignment: decoder.integer(root, key: "digit_align"),
            digitLength: decoder.integer(root, key: "digit_length"),
            animations: animations
        )
        return NxlvObjectMetadataDecodeResult(
            metadata: metadata,
            diagnostics: decoder.diagnostics
        )
    }

    private static func decodeAnimation(
        _ section: NxlvSection,
        isPrimary: Bool,
        decoder: inout MetadataValueDecoder
    ) -> NxlvObjectAnimationMetadata {
        let frames = decoder.integer(section, key: "frames")
        let name = trimmed(section.line("name"))
        let isGenerated = name?.hasPrefix("*") == true
        if frames == nil && section.lastLineRecord("frames") == nil && !isGenerated {
            decoder.append(
                severity: .error,
                code: .missingMetadataField,
                message: "An object animation has no FRAMES field.",
                line: section.openingLine
            )
        }

        let initialFrame: NxlvAnimationInitialFrame?
        if let line = section.lastLineRecord("initial_frame") {
            let value = line.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.caseInsensitiveCompare("random") == .orderedSame {
                initialFrame = .random
            } else if let index = NxlvNumber.integer(value) {
                initialFrame = .index(index)
            } else {
                decoder.append(
                    severity: .error,
                    code: .malformedMetadataInteger,
                    message: "Invalid INITIAL_FRAME value '\(line.value)'.",
                    line: line.lineNumber
                )
                initialFrame = nil
            }
        } else {
            initialFrame = nil
        }

        return NxlvObjectAnimationMetadata(
            isPrimary: isPrimary,
            name: name,
            frames: frames,
            usesHorizontalStrip: section.hasLine("horizontal_strip"),
            zIndex: decoder.integer(section, key: "z_index") ?? (isPrimary ? 1 : 0),
            initialFrame: initialFrame,
            offsetX: decoder.integer(section, key: "offset_x") ?? 0,
            offsetY: decoder.integer(section, key: "offset_y") ?? 0,
            nineSlice: decoder.nineSlice(section),
            startsHidden: section.hasLine("hide"),
            initialState: trimmed(section.line("state")),
            editorHidden: section.hasLine("editor_hide"),
            declaredWidth: decoder.integer(section, key: "width"),
            declaredHeight: decoder.integer(section, key: "height")
        )
    }

    private static func resizeAxes(_ section: NxlvSection) -> NxlvResizeAxes {
        var axes: NxlvResizeAxes = []
        if section.hasLine("resize_both") || section.hasLine("resize_horizontal") {
            axes.insert(.horizontal)
        }
        if section.hasLine("resize_both") || section.hasLine("resize_vertical") {
            axes.insert(.vertical)
        }
        return axes
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}

private struct MetadataValueDecoder {
    let path: String?
    var diagnostics: [NxlvStyleDiagnostic]

    init(
        document: NxlvSection,
        path: String?,
        parserDiagnostics: [NxlvDiagnostic]
    ) {
        self.path = path
        diagnostics = parserDiagnostics.map { diagnostic in
            NxlvStyleDiagnostic(
                severity: diagnostic.severity == .error ? .error : .warning,
                code: .malformedMetadata,
                message: diagnostic.message,
                line: diagnostic.line,
                path: path
            )
        }
    }

    mutating func integer(_ section: NxlvSection, key: String) -> Int? {
        guard let line = section.lastLineRecord(key) else { return nil }
        guard let value = NxlvNumber.integer(line.value) else {
            append(
                severity: .error,
                code: .malformedMetadataInteger,
                message: "Invalid integer '\(line.value)' for \(line.originalKeyword).",
                line: line.lineNumber
            )
            return nil
        }
        return value
    }

    mutating func boolean(_ section: NxlvSection, key: String) -> Bool? {
        guard let line = section.lastLineRecord(key) else { return nil }
        let value = line.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.caseInsensitiveCompare("true") == .orderedSame { return true }
        if value.caseInsensitiveCompare("false") == .orderedSame { return false }
        append(
            severity: .error,
            code: .malformedMetadata,
            message: "Invalid Boolean '\(line.value)' for \(line.originalKeyword).",
            line: line.lineNumber
        )
        return nil
    }

    mutating func nineSlice(_ section: NxlvSection) -> NxlvNineSliceMargins {
        NxlvNineSliceMargins(
            top: integer(section, key: "nine_slice_top"),
            left: integer(section, key: "nine_slice_left"),
            right: integer(section, key: "nine_slice_right"),
            bottom: integer(section, key: "nine_slice_bottom")
        )
    }

    mutating func append(
        severity: NxlvStyleDiagnosticSeverity,
        code: NxlvStyleDiagnosticCode,
        message: String,
        line: Int?
    ) {
        diagnostics.append(NxlvStyleDiagnostic(
            severity: severity,
            code: code,
            message: message,
            line: line,
            path: path
        ))
    }
}

public struct NxlvStyleReferenceScan: Sendable {
    public let references: [NxlvStyleAssetReference]
    public let diagnostics: [NxlvStyleDiagnostic]
}

public extension NxlvLevel {
    func scanStyleAssetReferences() -> NxlvStyleReferenceScan {
        var references: [NxlvStyleAssetReference] = []
        var diagnostics: [NxlvStyleDiagnostic] = []

        if !themeStyle.isEmpty {
            references.append(NxlvStyleAssetReference(
                kind: .theme,
                style: themeStyle,
                sourceLine: document.lastLineRecord("theme")?.lineNumber
            ))
        }

        func appendPlacement(
            kind: NxlvStyleAssetKind,
            style: String?,
            piece: String?,
            section: NxlvSection
        ) {
            if style?.caseInsensitiveCompare("*GROUP") == .orderedSame { return }
            guard let style, !style.isEmpty else {
                diagnostics.append(NxlvStyleDiagnostic(
                    severity: .error,
                    code: .missingStyleIdentifier,
                    message: "A \(kind.rawValue) reference has no STYLE field.",
                    line: section.openingLine
                ))
                return
            }
            guard let piece, !piece.isEmpty else {
                diagnostics.append(NxlvStyleDiagnostic(
                    severity: .error,
                    code: .missingPieceIdentifier,
                    message: "A \(kind.rawValue) reference has no PIECE field.",
                    line: section.openingLine
                ))
                return
            }
            references.append(NxlvStyleAssetReference(
                kind: kind,
                style: style,
                piece: piece,
                sourceLine: section.lastLineRecord("piece")?.lineNumber
                    ?? section.lastLineRecord("style")?.lineNumber
                    ?? section.lastLineRecord("collection")?.lineNumber
                    ?? section.openingLine
            ))
        }

        for placement in terrainPieces {
            appendPlacement(
                kind: .terrain,
                style: placement.style,
                piece: placement.piece,
                section: placement.source
            )
        }
        for group in terrainGroups {
            for placement in group.terrain {
                appendPlacement(
                    kind: .terrain,
                    style: placement.style,
                    piece: placement.piece,
                    section: placement.source
                )
            }
        }
        for gadget in gadgets {
            appendPlacement(
                kind: .object,
                style: gadget.style,
                piece: gadget.piece,
                section: gadget.source
            )
        }

        if let background, !background.isEmpty {
            let fields = background.split(separator: ":", omittingEmptySubsequences: false)
            if fields.count == 2, !fields[0].isEmpty, !fields[1].isEmpty {
                references.append(NxlvStyleAssetReference(
                    kind: .background,
                    style: String(fields[0]),
                    piece: String(fields[1]),
                    sourceLine: document.lastLineRecord("background")?.lineNumber
                ))
            } else {
                diagnostics.append(NxlvStyleDiagnostic(
                    severity: .error,
                    code: .malformedBackgroundIdentifier,
                    message: "BACKGROUND must use the form STYLE:PIECE.",
                    line: document.lastLineRecord("background")?.lineNumber
                ))
            }
        }

        var seen: Set<String> = []
        let unique = references.filter { reference in
            let identity = [
                reference.kind.rawValue,
                normalized(reference.style),
                normalized(reference.piece ?? "")
            ].joined(separator: "\u{0}")
            return seen.insert(identity).inserted
        }
        return NxlvStyleReferenceScan(references: unique, diagnostics: diagnostics)
    }
}

public struct NxlvResolvedStyleAsset: Sendable {
    public let reference: NxlvStyleAssetReference
    /// The physical style and piece after all aliases have been applied.
    public let resolvedReference: NxlvStyleAssetReference
    public let styleDirectoryURL: URL
    public let graphicURLs: [URL]
    public let metadataURL: URL?
    public let terrainMetadata: NxlvTerrainMetadata?
    public let objectMetadata: NxlvObjectMetadata?
    /// Alias-provided dimensions. NeoLemmix uses these when a placement has
    /// no explicit width or height.
    public let aliasDefaultWidth: Int?
    public let aliasDefaultHeight: Int?

    public init(
        reference: NxlvStyleAssetReference,
        styleDirectoryURL: URL,
        graphicURLs: [URL],
        metadataURL: URL?,
        terrainMetadata: NxlvTerrainMetadata?,
        objectMetadata: NxlvObjectMetadata?,
        resolvedReference: NxlvStyleAssetReference? = nil,
        aliasDefaultWidth: Int? = nil,
        aliasDefaultHeight: Int? = nil
    ) {
        self.reference = reference
        self.resolvedReference = resolvedReference ?? reference
        self.styleDirectoryURL = styleDirectoryURL
        self.graphicURLs = graphicURLs
        self.metadataURL = metadataURL
        self.terrainMetadata = terrainMetadata
        self.objectMetadata = objectMetadata
        self.aliasDefaultWidth = aliasDefaultWidth
        self.aliasDefaultHeight = aliasDefaultHeight
    }
}

public struct NxlvStyleResolution: Sendable {
    public let assets: [NxlvResolvedStyleAsset]
    public let diagnostics: [NxlvStyleDiagnostic]

    public var isComplete: Bool {
        !diagnostics.contains { $0.severity == .error }
    }

    public init(
        assets: [NxlvResolvedStyleAsset],
        diagnostics: [NxlvStyleDiagnostic]
    ) {
        self.assets = assets
        self.diagnostics = diagnostics
    }
}

public struct NxlvStyleResolver {
    public let stylesRootURL: URL
    public let maximumMetadataBytes: Int
    public let maximumAliasDepth: Int

    public init(
        stylesRootURL: URL,
        maximumMetadataBytes: Int = 1_048_576,
        maximumAliasDepth: Int = 64
    ) {
        self.stylesRootURL = stylesRootURL
        self.maximumMetadataBytes = max(1, maximumMetadataBytes)
        self.maximumAliasDepth = max(1, maximumAliasDepth)
    }

    public func resolve(level: NxlvLevel) -> NxlvStyleResolution {
        let scan = level.scanStyleAssetReferences()
        var engine = ResolutionEngine(
            stylesRootURL: stylesRootURL,
            maximumMetadataBytes: maximumMetadataBytes,
            maximumAliasDepth: maximumAliasDepth,
            diagnostics: scan.diagnostics
        )
        return engine.resolve(references: scan.references)
    }

    public func resolve(
        references: [NxlvStyleAssetReference]
    ) -> NxlvStyleResolution {
        var engine = ResolutionEngine(
            stylesRootURL: stylesRootURL,
            maximumMetadataBytes: maximumMetadataBytes,
            maximumAliasDepth: maximumAliasDepth,
            diagnostics: []
        )
        return engine.resolve(references: references)
    }
}

private enum AliasKind: String {
    case style
    case terrain
    case object
    case background
    case lemmings

    init(assetKind: NxlvStyleAssetKind) {
        switch assetKind {
        case .theme: self = .style
        case .terrain: self = .terrain
        case .object: self = .object
        case .background: self = .background
        case .lemmings: self = .lemmings
        }
    }

    var sectionKeyword: String {
        switch self {
        case .style: "style"
        case .terrain: "terrain"
        case .object: "gadget"
        case .background: "background"
        case .lemmings: "lemmings"
        }
    }

    var usesPieceIdentifier: Bool {
        switch self {
        case .terrain, .object, .background: true
        case .style, .lemmings: false
        }
    }
}

private struct AliasIdentifier: Equatable {
    var style: String
    var piece: String?

    var normalizedIdentity: String {
        [normalized(style), normalized(piece ?? "")].joined(separator: "\u{0}")
    }
}

private struct AliasRule {
    let kind: AliasKind
    let source: AliasIdentifier
    let destination: AliasIdentifier
    let defaultWidth: Int?
    let defaultHeight: Int?
    let sourceLine: Int
    let path: String

    var normalizedIdentity: String {
        [
            kind.rawValue,
            source.normalizedIdentity,
            destination.normalizedIdentity,
            defaultWidth.map(String.init) ?? "",
            defaultHeight.map(String.init) ?? ""
        ].joined(separator: "\u{0}")
    }
}

private struct AliasResolution {
    let reference: NxlvStyleAssetReference
    let defaultWidth: Int?
    let defaultHeight: Int?
}

private enum AliasMatch {
    case none
    case rule(AliasRule)
    case ambiguous
}

private struct ResolutionEngine {
    let fileManager = FileManager.default
    let requestedRootURL: URL
    let rootURL: URL
    let maximumMetadataBytes: Int
    let maximumAliasDepth: Int
    var diagnostics: [NxlvStyleDiagnostic]
    var aliasRules: [AliasRule] = []
    var loadedAliasStyles: Set<String> = []

    init(
        stylesRootURL: URL,
        maximumMetadataBytes: Int,
        maximumAliasDepth: Int,
        diagnostics: [NxlvStyleDiagnostic]
    ) {
        requestedRootURL = stylesRootURL.standardizedFileURL
        rootURL = stylesRootURL.standardizedFileURL.resolvingSymlinksInPath()
        self.maximumMetadataBytes = maximumMetadataBytes
        self.maximumAliasDepth = maximumAliasDepth
        self.diagnostics = diagnostics
    }

    mutating func resolve(
        references: [NxlvStyleAssetReference]
    ) -> NxlvStyleResolution {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: .stylesRootUnavailable,
                message: "The selected NeoLemmix styles root is not a directory.",
                path: requestedRootURL.path
            ))
            return NxlvStyleResolution(assets: [], diagnostics: diagnostics)
        }

        guard let styleEntries = directoryEntries(rootURL, reference: nil) else {
            return NxlvStyleResolution(assets: [], diagnostics: diagnostics)
        }

        var assets: [NxlvResolvedStyleAsset] = []
        for reference in references {
            guard isSafeComponent(reference.style),
                  reference.piece.map(isSafeComponent) ?? true else {
                diagnostics.append(NxlvStyleDiagnostic(
                    severity: .error,
                    code: .unsafeIdentifier,
                    message: "The style reference contains an unsafe path component.",
                    line: reference.sourceLine,
                    reference: reference
                ))
                continue
            }

            loadAliases(
                for: "default",
                styleEntries: styleEntries,
                reference: reference
            )
            guard let aliasResolution = resolveAliases(
                reference: reference,
                styleEntries: styleEntries
            ) else { continue }
            let resolvedReference = aliasResolution.reference

            let styleMatches = safeDirectories(
                named: resolvedReference.style,
                in: styleEntries,
                reference: reference
            )
            guard let styleURL = unique(
                styleMatches,
                missingCode: .missingStyle,
                ambiguousCode: .ambiguousStyle,
                missingMessage: "Style '\(resolvedReference.style)' is missing.",
                ambiguousMessage: "Style '\(resolvedReference.style)' has multiple case-insensitive matches.",
                reference: reference
            ) else { continue }

            if let asset = resolve(
                requestedReference: reference,
                resolvedReference: resolvedReference,
                styleURL: styleURL,
                aliasDefaultWidth: aliasResolution.defaultWidth,
                aliasDefaultHeight: aliasResolution.defaultHeight
            ) {
                assets.append(asset)
            }
        }
        return NxlvStyleResolution(assets: assets, diagnostics: diagnostics)
    }

    private mutating func resolveAliases(
        reference: NxlvStyleAssetReference,
        styleEntries: [URL]
    ) -> AliasResolution? {
        let requestedKind = AliasKind(assetKind: reference.kind)
        var current = AliasIdentifier(style: reference.style, piece: reference.piece)
        var defaultWidth: Int?
        var defaultHeight: Int?
        var visited: Set<String> = [current.normalizedIdentity]
        var redirectCount = 0

        while true {
            loadAliases(
                for: current.style,
                styleEntries: styleEntries,
                reference: reference
            )
            var didChange = false

            if requestedKind != .style {
                switch matchingAlias(
                    kind: requestedKind,
                    identifier: current,
                    reference: reference
                ) {
                case .none:
                    break
                case .ambiguous:
                    return nil
                case let .rule(rule):
                    if requestedKind.usesPieceIdentifier {
                        defaultWidth = rule.defaultWidth
                        defaultHeight = rule.defaultHeight
                    }
                    if !sameIdentifier(current, rule.destination) {
                        guard applyAliasTransition(
                            rule.destination,
                            current: &current,
                            visited: &visited,
                            redirectCount: &redirectCount,
                            rule: rule,
                            reference: reference
                        ) else { return nil }
                        didChange = true
                    }
                }
            }

            switch matchingAlias(
                kind: .style,
                identifier: AliasIdentifier(style: current.style, piece: nil),
                reference: reference
            ) {
            case .none:
                break
            case .ambiguous:
                return nil
            case let .rule(rule):
                let destination = AliasIdentifier(
                    style: rule.destination.style,
                    piece: current.piece
                )
                if !sameIdentifier(current, destination) {
                    guard applyAliasTransition(
                        destination,
                        current: &current,
                        visited: &visited,
                        redirectCount: &redirectCount,
                        rule: rule,
                        reference: reference
                    ) else { return nil }
                    didChange = true
                }
            }

            if !didChange {
                return AliasResolution(
                    reference: NxlvStyleAssetReference(
                        kind: reference.kind,
                        style: current.style,
                        piece: current.piece,
                        sourceLine: reference.sourceLine
                    ),
                    defaultWidth: defaultWidth,
                    defaultHeight: defaultHeight
                )
            }
        }
    }

    private mutating func applyAliasTransition(
        _ destination: AliasIdentifier,
        current: inout AliasIdentifier,
        visited: inout Set<String>,
        redirectCount: inout Int,
        rule: AliasRule,
        reference: NxlvStyleAssetReference
    ) -> Bool {
        guard redirectCount < maximumAliasDepth else {
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: .aliasDepthExceeded,
                message: "Alias resolution exceeded the \(maximumAliasDepth)-redirect limit.",
                line: rule.sourceLine,
                path: rule.path,
                reference: reference
            ))
            return false
        }

        redirectCount += 1
        guard visited.insert(destination.normalizedIdentity).inserted else {
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: .aliasCycle,
                message: "Alias resolution contains a cycle at '\(displayIdentifier(destination))'.",
                line: rule.sourceLine,
                path: rule.path,
                reference: reference
            ))
            return false
        }
        current = destination
        return true
    }

    private mutating func matchingAlias(
        kind: AliasKind,
        identifier: AliasIdentifier,
        reference: NxlvStyleAssetReference
    ) -> AliasMatch {
        let matches = aliasRules.filter { rule in
            guard rule.kind == kind,
                  normalized(rule.source.style) == normalized(identifier.style) else {
                return false
            }
            if kind.usesPieceIdentifier {
                return normalized(rule.source.piece ?? "") == normalized(identifier.piece ?? "")
            }
            return true
        }

        var seen: Set<String> = []
        let uniqueMatches = matches.filter { seen.insert($0.normalizedIdentity).inserted }
        guard !uniqueMatches.isEmpty else { return .none }
        guard uniqueMatches.count == 1 else {
            let first = uniqueMatches[0]
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: .ambiguousAlias,
                message: "Alias '\(displayIdentifier(identifier))' has conflicting \(kind.sectionKeyword) redirects.",
                line: first.sourceLine,
                path: first.path,
                reference: reference
            ))
            return .ambiguous
        }
        return .rule(uniqueMatches[0])
    }

    private mutating func loadAliases(
        for style: String,
        styleEntries: [URL],
        reference: NxlvStyleAssetReference
    ) {
        let styleKey = normalized(style)
        guard loadedAliasStyles.insert(styleKey).inserted else { return }

        let styleMatches = safeDirectories(
            named: style,
            in: styleEntries,
            reference: reference
        )
        guard styleMatches.count <= 1 else {
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: .ambiguousStyle,
                message: "Style '\(style)' has multiple case-insensitive matches while loading aliases.",
                line: reference.sourceLine,
                reference: reference
            ))
            return
        }
        guard let styleURL = styleMatches.first,
              let entries = directoryEntries(styleURL, reference: reference) else { return }

        let aliasMatches = safeFiles(
            baseName: "alias",
            extensions: ["nxmi"],
            in: entries,
            reference: reference
        )
        guard aliasMatches.count <= 1 else {
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: .ambiguousAliasFile,
                message: "Style '\(style)' has multiple case-insensitive alias.nxmi files.",
                line: reference.sourceLine,
                path: styleURL.path,
                reference: reference
            ))
            return
        }
        guard let aliasURL = aliasMatches.first,
              let text = readMetadata(aliasURL, reference: reference) else { return }

        let parsed = NxlvParser.parseResult(text)
        diagnostics.append(contentsOf: parsed.diagnostics.map { diagnostic in
            NxlvStyleDiagnostic(
                severity: diagnostic.severity == .error ? .error : .warning,
                code: .malformedAlias,
                message: diagnostic.message,
                line: diagnostic.line,
                path: aliasURL.path,
                reference: reference
            )
        })

        for kind in [AliasKind.style, .object, .terrain, .background, .lemmings] {
            for section in parsed.document.allSections(kind.sectionKeyword) {
                if let rule = decodeAliasRule(
                    section,
                    kind: kind,
                    containingStyle: styleURL.lastPathComponent,
                    path: aliasURL.path,
                    reference: reference
                ) {
                    aliasRules.append(rule)
                }
            }
        }
    }

    private mutating func decodeAliasRule(
        _ section: NxlvSection,
        kind: AliasKind,
        containingStyle: String,
        path: String,
        reference: NxlvStyleAssetReference
    ) -> AliasRule? {
        guard let fromLine = section.lastLineRecord("from"),
              !fromLine.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: .missingAliasField,
                message: "An alias $\(kind.sectionKeyword.uppercased()) section has no FROM field.",
                line: section.openingLine,
                path: path,
                reference: reference
            ))
            return nil
        }
        guard let toLine = section.lastLineRecord("to"),
              !toLine.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: .missingAliasField,
                message: "An alias $\(kind.sectionKeyword.uppercased()) section has no TO field.",
                line: section.openingLine,
                path: path,
                reference: reference
            ))
            return nil
        }

        guard let source = decodeAliasIdentifier(
            fromLine.value,
            kind: kind,
            containingStyle: containingStyle,
            field: "FROM",
            line: fromLine.lineNumber,
            path: path,
            reference: reference
        ), let destination = decodeAliasIdentifier(
            toLine.value,
            kind: kind,
            containingStyle: containingStyle,
            field: "TO",
            line: toLine.lineNumber,
            path: path,
            reference: reference
        ) else { return nil }

        guard let defaultWidth = decodeAliasInteger(
            section.lastLineRecord("width"),
            path: path,
            reference: reference
        ), let defaultHeight = decodeAliasInteger(
            section.lastLineRecord("height"),
            path: path,
            reference: reference
        ) else { return nil }

        return AliasRule(
            kind: kind,
            source: source,
            destination: destination,
            defaultWidth: defaultWidth,
            defaultHeight: defaultHeight,
            sourceLine: section.openingLine,
            path: path
        )
    }

    private mutating func decodeAliasIdentifier(
        _ value: String,
        kind: AliasKind,
        containingStyle: String,
        field: String,
        line: Int,
        path: String,
        reference: NxlvStyleAssetReference
    ) -> AliasIdentifier? {
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let identifier: AliasIdentifier

        if kind.usesPieceIdentifier {
            let fields = token.split(separator: ":", omittingEmptySubsequences: false)
            guard fields.count == 2, !fields[1].isEmpty else {
                diagnostics.append(NxlvStyleDiagnostic(
                    severity: .error,
                    code: .malformedAliasIdentifier,
                    message: "Alias \(field) must use STYLE:PIECE or :PIECE for a \(kind.sectionKeyword) redirect.",
                    line: line,
                    path: path,
                    reference: reference
                ))
                return nil
            }
            identifier = AliasIdentifier(
                style: fields[0].isEmpty ? containingStyle : String(fields[0]),
                piece: String(fields[1])
            )
        } else {
            guard !token.contains(":") else {
                diagnostics.append(NxlvStyleDiagnostic(
                    severity: .error,
                    code: .malformedAliasIdentifier,
                    message: "Alias \(field) must contain one style identifier for a \(kind.sectionKeyword) redirect.",
                    line: line,
                    path: path,
                    reference: reference
                ))
                return nil
            }
            identifier = AliasIdentifier(style: token, piece: nil)
        }

        guard isSafeComponent(identifier.style),
              identifier.piece.map(isSafeComponent) ?? true else {
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: .unsafeIdentifier,
                message: "Alias \(field) contains an unsafe path component.",
                line: line,
                path: path,
                reference: reference
            ))
            return nil
        }
        return identifier
    }

    private mutating func decodeAliasInteger(
        _ line: NxlvLine?,
        path: String,
        reference: NxlvStyleAssetReference
    ) -> Int?? {
        guard let line else { return .some(nil) }
        guard let value = NxlvNumber.integer(line.value) else {
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: .malformedAliasInteger,
                message: "Invalid integer '\(line.value)' for \(line.originalKeyword).",
                line: line.lineNumber,
                path: path,
                reference: reference
            ))
            return nil
        }
        return .some(value)
    }

    private mutating func resolve(
        requestedReference: NxlvStyleAssetReference,
        resolvedReference: NxlvStyleAssetReference,
        styleURL: URL,
        aliasDefaultWidth: Int?,
        aliasDefaultHeight: Int?
    ) -> NxlvResolvedStyleAsset? {
        switch resolvedReference.kind {
        case .theme:
            return resolveTheme(
                requestedReference: requestedReference,
                resolvedReference: resolvedReference,
                styleURL: styleURL
            )
        case .terrain:
            return resolveTerrain(
                requestedReference: requestedReference,
                resolvedReference: resolvedReference,
                styleURL: styleURL,
                aliasDefaultWidth: aliasDefaultWidth,
                aliasDefaultHeight: aliasDefaultHeight
            )
        case .object:
            return resolveObject(
                requestedReference: requestedReference,
                resolvedReference: resolvedReference,
                styleURL: styleURL,
                aliasDefaultWidth: aliasDefaultWidth,
                aliasDefaultHeight: aliasDefaultHeight
            )
        case .background:
            return resolveBackground(
                requestedReference: requestedReference,
                resolvedReference: resolvedReference,
                styleURL: styleURL,
                aliasDefaultWidth: aliasDefaultWidth,
                aliasDefaultHeight: aliasDefaultHeight
            )
        case .lemmings:
            return resolveLemmings(
                requestedReference: requestedReference,
                resolvedReference: resolvedReference,
                styleURL: styleURL
            )
        }
    }

    private mutating func resolveTheme(
        requestedReference: NxlvStyleAssetReference,
        resolvedReference: NxlvStyleAssetReference,
        styleURL: URL
    ) -> NxlvResolvedStyleAsset? {
        guard let entries = directoryEntries(styleURL, reference: requestedReference) else { return nil }
        let matches = safeFiles(
            baseName: "theme",
            extensions: ["nxmi", "nxtm"],
            in: entries,
            reference: requestedReference
        )
        guard let metadataURL = unique(
            matches,
            missingCode: .missingPieceMetadata,
            ambiguousCode: .ambiguousPieceMetadata,
            missingMessage: "Style '\(resolvedReference.style)' has no theme metadata file.",
            ambiguousMessage: "Style '\(resolvedReference.style)' has multiple theme metadata files.",
            reference: requestedReference
        ) else { return nil }

        return NxlvResolvedStyleAsset(
            reference: requestedReference,
            styleDirectoryURL: styleURL,
            graphicURLs: [],
            metadataURL: metadataURL,
            terrainMetadata: nil,
            objectMetadata: nil,
            resolvedReference: resolvedReference
        )
    }

    private mutating func resolveTerrain(
        requestedReference: NxlvStyleAssetReference,
        resolvedReference: NxlvStyleAssetReference,
        styleURL: URL,
        aliasDefaultWidth: Int?,
        aliasDefaultHeight: Int?
    ) -> NxlvResolvedStyleAsset? {
        guard let piece = resolvedReference.piece,
              let directory = assetDirectory(
                named: "terrain",
                styleURL: styleURL,
                styleName: resolvedReference.style,
                reference: requestedReference
              ),
              let entries = directoryEntries(directory, reference: requestedReference) else { return nil }

        let graphics = safeFiles(
            baseName: piece,
            extensions: ["png"],
            in: entries,
            reference: requestedReference
        )
        guard let graphicURL = unique(
            graphics,
            missingCode: .missingPieceGraphic,
            ambiguousCode: .ambiguousPieceGraphic,
            missingMessage: "Terrain graphic '\(resolvedReference.style):\(piece)' is missing.",
            ambiguousMessage: "Terrain graphic '\(resolvedReference.style):\(piece)' is ambiguous.",
            reference: requestedReference
        ) else { return nil }

        let metadataMatches = safeFiles(
            baseName: piece,
            extensions: ["nxmt", "nxtm"],
            in: entries,
            reference: requestedReference
        )
        let metadataURL: URL?
        let metadata: NxlvTerrainMetadata?
        if metadataMatches.isEmpty {
            metadataURL = nil
            metadata = NxlvStyleMetadataDecoder.decodeTerrain(text: "").metadata
        } else if metadataMatches.count > 1 {
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: .ambiguousPieceMetadata,
                message: "Terrain metadata '\(resolvedReference.style):\(piece)' is ambiguous.",
                line: requestedReference.sourceLine,
                reference: requestedReference
            ))
            return nil
        } else {
            metadataURL = metadataMatches[0]
            guard let text = readMetadata(metadataMatches[0], reference: requestedReference) else {
                return nil
            }
            let result = NxlvStyleMetadataDecoder.decodeTerrain(
                text: text,
                path: metadataMatches[0].path
            )
            diagnostics.append(contentsOf: result.diagnostics.map {
                withReference($0, reference: requestedReference)
            })
            metadata = result.metadata
        }

        return NxlvResolvedStyleAsset(
            reference: requestedReference,
            styleDirectoryURL: styleURL,
            graphicURLs: [graphicURL],
            metadataURL: metadataURL,
            terrainMetadata: metadata,
            objectMetadata: nil,
            resolvedReference: resolvedReference,
            aliasDefaultWidth: aliasDefaultWidth,
            aliasDefaultHeight: aliasDefaultHeight
        )
    }

    private mutating func resolveObject(
        requestedReference: NxlvStyleAssetReference,
        resolvedReference: NxlvStyleAssetReference,
        styleURL: URL,
        aliasDefaultWidth: Int?,
        aliasDefaultHeight: Int?
    ) -> NxlvResolvedStyleAsset? {
        guard let piece = resolvedReference.piece,
              let directory = assetDirectory(
                named: "objects",
                styleURL: styleURL,
                styleName: resolvedReference.style,
                reference: requestedReference
              ),
              let entries = directoryEntries(directory, reference: requestedReference) else { return nil }

        let metadataMatches = safeFiles(
            baseName: piece,
            extensions: ["nxmo"],
            in: entries,
            reference: requestedReference
        )
        guard let metadataURL = unique(
            metadataMatches,
            missingCode: .missingPieceMetadata,
            ambiguousCode: .ambiguousPieceMetadata,
            missingMessage: "Object metadata '\(resolvedReference.style):\(piece)' is missing.",
            ambiguousMessage: "Object metadata '\(resolvedReference.style):\(piece)' is ambiguous.",
            reference: requestedReference
        ), let text = readMetadata(metadataURL, reference: requestedReference) else { return nil }

        let result = NxlvStyleMetadataDecoder.decodeObject(text: text, path: metadataURL.path)
        diagnostics.append(contentsOf: result.diagnostics.map {
            withReference($0, reference: requestedReference)
        })

        var animationBaseNames: [String] = []
        var seen: Set<String> = []
        let animations = result.metadata.animations.isEmpty
            ? [NxlvObjectAnimationMetadata(
                isPrimary: true,
                name: nil,
                frames: nil,
                usesHorizontalStrip: false,
                zIndex: 1,
                initialFrame: nil,
                offsetX: 0,
                offsetY: 0,
                nineSlice: NxlvNineSliceMargins(
                    top: nil,
                    left: nil,
                    right: nil,
                    bottom: nil
                ),
                startsHidden: false,
                initialState: nil,
                editorHidden: false
            )]
            : result.metadata.animations

        for animation in animations {
            if let name = animation.name, !isSafeComponent(name) {
                diagnostics.append(NxlvStyleDiagnostic(
                    severity: .error,
                    code: .unsafeIdentifier,
                    message: "Object animation '\(name)' contains an unsafe path component.",
                    line: requestedReference.sourceLine,
                    path: metadataURL.path,
                    reference: requestedReference
                ))
                continue
            }
            if animation.name?.hasPrefix("*") == true { continue }
            let baseName = animation.name.map { "\(piece)_\($0)" } ?? piece
            if seen.insert(normalized(baseName)).inserted {
                animationBaseNames.append(baseName)
            }
        }

        var graphicURLs: [URL] = []
        for baseName in animationBaseNames {
            let matches = safeFiles(
                baseName: baseName,
                extensions: ["png"],
                in: entries,
                reference: requestedReference
            )
            if let graphicURL = unique(
                matches,
                missingCode: .missingPieceGraphic,
                ambiguousCode: .ambiguousPieceGraphic,
                missingMessage: "Object animation graphic '\(baseName).png' is missing.",
                ambiguousMessage: "Object animation graphic '\(baseName).png' is ambiguous.",
                reference: requestedReference
            ) {
                graphicURLs.append(graphicURL)
            }
        }

        return NxlvResolvedStyleAsset(
            reference: requestedReference,
            styleDirectoryURL: styleURL,
            graphicURLs: graphicURLs,
            metadataURL: metadataURL,
            terrainMetadata: nil,
            objectMetadata: result.metadata,
            resolvedReference: resolvedReference,
            aliasDefaultWidth: aliasDefaultWidth,
            aliasDefaultHeight: aliasDefaultHeight
        )
    }

    private mutating func resolveBackground(
        requestedReference: NxlvStyleAssetReference,
        resolvedReference: NxlvStyleAssetReference,
        styleURL: URL,
        aliasDefaultWidth: Int?,
        aliasDefaultHeight: Int?
    ) -> NxlvResolvedStyleAsset? {
        guard let piece = resolvedReference.piece,
              let directory = assetDirectory(
                named: "backgrounds",
                styleURL: styleURL,
                styleName: resolvedReference.style,
                reference: requestedReference
              ),
              let entries = directoryEntries(directory, reference: requestedReference) else { return nil }

        let graphics = safeFiles(
            baseName: piece,
            extensions: ["png"],
            in: entries,
            reference: requestedReference
        )
        guard let graphicURL = unique(
            graphics,
            missingCode: .missingPieceGraphic,
            ambiguousCode: .ambiguousPieceGraphic,
            missingMessage: "Background graphic '\(resolvedReference.style):\(piece)' is missing.",
            ambiguousMessage: "Background graphic '\(resolvedReference.style):\(piece)' is ambiguous.",
            reference: requestedReference
        ) else { return nil }

        let metadataMatches = safeFiles(
            baseName: piece,
            extensions: ["nxmb"],
            in: entries,
            reference: requestedReference
        )
        let metadataURL: URL?
        if metadataMatches.count > 1 {
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: .ambiguousPieceMetadata,
                message: "Background metadata '\(resolvedReference.style):\(piece)' is ambiguous.",
                line: requestedReference.sourceLine,
                reference: requestedReference
            ))
            return nil
        } else {
            metadataURL = metadataMatches.first
        }

        return NxlvResolvedStyleAsset(
            reference: requestedReference,
            styleDirectoryURL: styleURL,
            graphicURLs: [graphicURL],
            metadataURL: metadataURL,
            terrainMetadata: nil,
            objectMetadata: nil,
            resolvedReference: resolvedReference,
            aliasDefaultWidth: aliasDefaultWidth,
            aliasDefaultHeight: aliasDefaultHeight
        )
    }

    private mutating func resolveLemmings(
        requestedReference: NxlvStyleAssetReference,
        resolvedReference: NxlvStyleAssetReference,
        styleURL: URL
    ) -> NxlvResolvedStyleAsset? {
        guard let directory = assetDirectory(
            named: "lemmings",
            styleURL: styleURL,
            styleName: resolvedReference.style,
            reference: requestedReference
        ), let entries = directoryEntries(directory, reference: requestedReference) else {
            return nil
        }

        let graphicURLs = safeFiles(
            extensions: ["png"],
            in: entries,
            reference: requestedReference
        )
        guard !graphicURLs.isEmpty else {
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: .missingPieceGraphic,
                message: "Lemming sprite set '\(resolvedReference.style)' has no PNG graphics.",
                line: requestedReference.sourceLine,
                reference: requestedReference
            ))
            return nil
        }

        let groups = Dictionary(grouping: graphicURLs) {
            normalized($0.deletingPathExtension().lastPathComponent)
        }
        if let ambiguous = groups.values.first(where: { $0.count > 1 }) {
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: .ambiguousPieceGraphic,
                message: "Lemming sprite '\(ambiguous[0].deletingPathExtension().lastPathComponent)' is ambiguous.",
                line: requestedReference.sourceLine,
                path: directory.path,
                reference: requestedReference
            ))
            return nil
        }

        let metadataMatches = safeFiles(
            baseName: "scheme",
            extensions: ["nxmi"],
            in: entries,
            reference: requestedReference
        )
        guard metadataMatches.count <= 1 else {
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: .ambiguousPieceMetadata,
                message: "Lemming sprite set '\(resolvedReference.style)' has multiple scheme.nxmi files.",
                line: requestedReference.sourceLine,
                path: directory.path,
                reference: requestedReference
            ))
            return nil
        }

        return NxlvResolvedStyleAsset(
            reference: requestedReference,
            styleDirectoryURL: styleURL,
            graphicURLs: graphicURLs,
            metadataURL: metadataMatches.first,
            terrainMetadata: nil,
            objectMetadata: nil,
            resolvedReference: resolvedReference
        )
    }

    private mutating func assetDirectory(
        named name: String,
        styleURL: URL,
        styleName: String,
        reference: NxlvStyleAssetReference
    ) -> URL? {
        guard let entries = directoryEntries(styleURL, reference: reference) else { return nil }
        let matches = safeDirectories(named: name, in: entries, reference: reference)
        return unique(
            matches,
            missingCode: .missingAssetDirectory,
            ambiguousCode: .ambiguousAssetDirectory,
            missingMessage: "Style '\(styleName)' has no \(name) directory.",
            ambiguousMessage: "Style '\(styleName)' has multiple \(name) directories.",
            reference: reference
        )
    }

    private mutating func directoryEntries(
        _ directory: URL,
        reference: NxlvStyleAssetReference?
    ) -> [URL]? {
        do {
            return try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ).sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: .unreadableDirectory,
                message: "Cannot read directory '\(directory.path)'.",
                line: reference?.sourceLine,
                path: directory.path,
                reference: reference
            ))
            return nil
        }
    }

    private mutating func safeDirectories(
        named name: String,
        in entries: [URL],
        reference: NxlvStyleAssetReference
    ) -> [URL] {
        entries.filter { normalized($0.lastPathComponent) == normalized(name) }
            .compactMap { candidate in
                let resolved = candidate.resolvingSymlinksInPath()
                guard isWithinRoot(resolved) else {
                    diagnostics.append(unsafePathDiagnostic(candidate, reference: reference))
                    return nil
                }
                guard (try? resolved.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                    return nil
                }
                return resolved
            }
    }

    private mutating func safeFiles(
        baseName: String,
        extensions: Set<String>,
        in entries: [URL],
        reference: NxlvStyleAssetReference
    ) -> [URL] {
        let normalizedExtensions = Set(extensions.map(normalized))
        return entries.filter { candidate in
            normalized(candidate.deletingPathExtension().lastPathComponent) == normalized(baseName)
                && normalizedExtensions.contains(normalized(candidate.pathExtension))
        }.compactMap { candidate in
            let resolved = candidate.resolvingSymlinksInPath()
            guard isWithinRoot(resolved) else {
                diagnostics.append(unsafePathDiagnostic(candidate, reference: reference))
                return nil
            }
            guard (try? resolved.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                return nil
            }
            return resolved
        }
    }

    private mutating func safeFiles(
        extensions: Set<String>,
        in entries: [URL],
        reference: NxlvStyleAssetReference
    ) -> [URL] {
        let normalizedExtensions = Set(extensions.map(normalized))
        return entries.filter { candidate in
            normalizedExtensions.contains(normalized(candidate.pathExtension))
        }.compactMap { candidate in
            let resolved = candidate.resolvingSymlinksInPath()
            guard isWithinRoot(resolved) else {
                diagnostics.append(unsafePathDiagnostic(candidate, reference: reference))
                return nil
            }
            guard (try? resolved.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                return nil
            }
            return resolved
        }
    }

    private mutating func unique(
        _ matches: [URL],
        missingCode: NxlvStyleDiagnosticCode,
        ambiguousCode: NxlvStyleDiagnosticCode,
        missingMessage: String,
        ambiguousMessage: String,
        reference: NxlvStyleAssetReference
    ) -> URL? {
        if matches.isEmpty {
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: missingCode,
                message: missingMessage,
                line: reference.sourceLine,
                reference: reference
            ))
            return nil
        }
        if matches.count > 1 {
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: ambiguousCode,
                message: ambiguousMessage,
                line: reference.sourceLine,
                reference: reference
            ))
            return nil
        }
        return matches[0]
    }

    private mutating func readMetadata(
        _ url: URL,
        reference: NxlvStyleAssetReference
    ) -> String? {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? NSNumber,
               size.int64Value > Int64(maximumMetadataBytes) {
                diagnostics.append(NxlvStyleDiagnostic(
                    severity: .error,
                    code: .metadataTooLarge,
                    message: "Metadata exceeds the \(maximumMetadataBytes)-byte limit.",
                    line: reference.sourceLine,
                    path: url.path,
                    reference: reference
                ))
                return nil
            }

            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            if let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .windowsCP1252) {
                return text
            }
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: .invalidMetadataEncoding,
                message: "Metadata is not valid UTF-8 or Windows-1252 text.",
                line: reference.sourceLine,
                path: url.path,
                reference: reference
            ))
        } catch {
            diagnostics.append(NxlvStyleDiagnostic(
                severity: .error,
                code: .unreadableMetadata,
                message: "Cannot read metadata '\(url.path)'.",
                line: reference.sourceLine,
                path: url.path,
                reference: reference
            ))
        }
        return nil
    }

    private func isWithinRoot(_ url: URL) -> Bool {
        let rootComponents = rootURL.standardizedFileURL.pathComponents
        let candidateComponents = url.standardizedFileURL.pathComponents
        guard candidateComponents.count >= rootComponents.count else { return false }
        return zip(rootComponents, candidateComponents).allSatisfy(==)
    }

    private func unsafePathDiagnostic(
        _ url: URL,
        reference: NxlvStyleAssetReference
    ) -> NxlvStyleDiagnostic {
        NxlvStyleDiagnostic(
            severity: .error,
            code: .unsafeResolvedPath,
            message: "A matching asset resolves outside the selected styles root.",
            line: reference.sourceLine,
            path: url.path,
            reference: reference
        )
    }

    private func withReference(
        _ diagnostic: NxlvStyleDiagnostic,
        reference: NxlvStyleAssetReference
    ) -> NxlvStyleDiagnostic {
        NxlvStyleDiagnostic(
            severity: diagnostic.severity,
            code: diagnostic.code,
            message: diagnostic.message,
            line: diagnostic.line,
            path: diagnostic.path,
            reference: reference
        )
    }
}

private func sameIdentifier(_ lhs: AliasIdentifier, _ rhs: AliasIdentifier) -> Bool {
    lhs.normalizedIdentity == rhs.normalizedIdentity
}

private func displayIdentifier(_ identifier: AliasIdentifier) -> String {
    guard let piece = identifier.piece else { return identifier.style }
    return "\(identifier.style):\(piece)"
}

private func normalized(_ value: String) -> String {
    value.precomposedStringWithCanonicalMapping.folding(
        options: [.caseInsensitive],
        locale: Locale(identifier: "en_US_POSIX")
    )
}

private func isSafeComponent(_ value: String) -> Bool {
    guard !value.isEmpty, value != ".", value != ".." else { return false }
    let forbidden = CharacterSet(charactersIn: "/\\:\u{0}")
        .union(.controlCharacters)
    return value.rangeOfCharacter(from: forbidden) == nil
}
