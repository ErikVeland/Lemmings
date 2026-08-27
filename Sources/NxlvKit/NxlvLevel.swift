import Foundation

public struct NxlvTerrainPlacement: Sendable {
    public let style: String?
    public let piece: String?
    public let x: Int?
    public let y: Int?
    public let width: Int?
    public let height: Int?
    public let rotate: Bool
    public let flipHorizontal: Bool
    public let flipVertical: Bool
    public let noOverwrite: Bool
    public let erase: Bool
    public let oneWay: Bool
    public let source: NxlvSection

    fileprivate init(section: NxlvSection, decoder: inout NxlvValueDecoder) {
        style = decoder.string(section, keys: ["style", "collection"])
        piece = decoder.string(section, keys: ["piece"])
        x = decoder.integer(section, keys: ["x"], context: "terrain X")
        y = decoder.integer(section, keys: ["y"], context: "terrain Y")
        width = decoder.integer(section, keys: ["width"], context: "terrain width")
        height = decoder.integer(section, keys: ["height"], context: "terrain height")
        rotate = section.hasLine("rotate")
        flipHorizontal = section.hasLine("flip_horizontal")
        flipVertical = section.hasLine("flip_vertical")
        noOverwrite = section.hasLine("no_overwrite")
        erase = section.hasLine("erase")
        oneWay = section.hasLine("one_way")
        source = section
    }
}

public struct NxlvTerrainGroup: Sendable {
    public let name: String?
    public let terrain: [NxlvTerrainPlacement]
    public let source: NxlvSection

    fileprivate init(section: NxlvSection, decoder: inout NxlvValueDecoder) {
        name = decoder.string(section, keys: ["name"])
        terrain = section.allSections("terrain").map {
            NxlvTerrainPlacement(section: $0, decoder: &decoder)
        }
        source = section
    }
}

public struct NxlvGadget: Sendable {
    /// A last-value-wins compatibility view. Use `source.entries` when
    /// duplicate fields or exact ordering matter.
    public let raw: [String: String]
    public let source: NxlvSection

    public let style: String?
    public let piece: String?
    public let x: Int?
    public let y: Int?
    public let width: Int?
    public let height: Int?
    public let rotate: Bool
    public let flipHorizontal: Bool
    public let flipVertical: Bool
    public let noOverwrite: Bool
    public let onlyOnTerrain: Bool

    public let lemmings: Int?
    public let pairing: Int?
    public let skill: String?
    public let skillType: NxlvSkill?
    public let skillCount: Int?
    public let direction: NxlvDirection?
    public let flipLemming: Bool
    public let angle: Int?
    public let speed: Int?
    public let lemmingTraits: Set<NxlvLemmingTrait>

    fileprivate init(section: NxlvSection, decoder: inout NxlvValueDecoder) {
        raw = Dictionary(section.lines.map { ($0.key, $0.value) },
                         uniquingKeysWith: { _, last in last })
        source = section
        style = decoder.string(section, keys: ["style", "collection"])
        piece = decoder.string(section, keys: ["piece"])
        x = decoder.integer(section, keys: ["x"], context: "gadget X")
        y = decoder.integer(section, keys: ["y"], context: "gadget Y")
        width = decoder.integer(section, keys: ["width"], context: "gadget width")
        height = decoder.integer(section, keys: ["height"], context: "gadget height")
        rotate = section.hasLine("rotate")
        flipHorizontal = section.hasLine("flip_horizontal")
        flipVertical = section.hasLine("flip_vertical")
        noOverwrite = section.hasLine("no_overwrite")
        onlyOnTerrain = section.hasLine("only_on_terrain")

        lemmings = decoder.integer(section, keys: ["lemmings"], context: "gadget lemming limit")
        pairing = decoder.integer(section, keys: ["pairing"], context: "gadget pairing")
        skill = decoder.string(section, keys: ["skill"])
        skillType = skill.flatMap(NxlvSkill.init(keyword:))
        if let skill, skillType == nil {
            decoder.append(
                severity: .warning,
                code: .invalidSkill,
                message: "Unknown gadget skill '\(skill)'.",
                line: section.lastLineRecord("skill")?.lineNumber
            )
        }
        skillCount = decoder.integer(
            section,
            keys: ["skill_count", "skillcount"],
            context: "pickup skill count"
        )
        let directionValue = decoder.string(section, keys: ["direction"])
        direction = directionValue.flatMap(NxlvDirection.init(keyword:))
        if let directionValue, direction == nil {
            decoder.append(
                severity: .warning,
                code: .invalidDirection,
                message: "Unknown gadget direction '\(directionValue)'.",
                line: section.lastLineRecord("direction")?.lineNumber
            )
        }
        flipLemming = section.hasLine("flip_lemming")
        angle = decoder.integer(section, keys: ["angle"], context: "background angle")
        speed = decoder.integer(section, keys: ["speed"], context: "background speed")
        lemmingTraits = Set(NxlvLemmingTrait.allCases.filter { section.hasLine($0.keyword) })
    }

    init(section: NxlvSection) {
        var decoder = NxlvValueDecoder()
        self.init(section: section, decoder: &decoder)
    }
}

public struct NxlvLemming: Sendable {
    public let x: Int?
    public let y: Int?
    public let direction: NxlvDirection
    public let traits: Set<NxlvLemmingTrait>
    public let source: NxlvSection

    fileprivate init(section: NxlvSection, decoder: inout NxlvValueDecoder) {
        x = decoder.integer(section, keys: ["x"], context: "preplaced lemming X")
        y = decoder.integer(section, keys: ["y"], context: "preplaced lemming Y")
        if section.hasLine("flip_horizontal") {
            direction = .left
        } else if let directionLine = section.lastLineRecord("direction") {
            if let legacyDirection = NxlvDirection(keyword: directionLine.value) {
                direction = legacyDirection
            } else {
                direction = .right
                decoder.append(
                    severity: .warning,
                    code: .invalidDirection,
                    message: "Unknown preplaced lemming direction '\(directionLine.value)'.",
                    line: directionLine.lineNumber
                )
            }
        } else {
            direction = .right
        }
        traits = Set(NxlvLemmingTrait.allCases.filter { section.hasLine($0.keyword) })
        source = section
    }
}

public struct NxlvTalisman: Sendable {
    public let title: String?
    public let id: UInt64?
    public let color: NxlvTalismanColor?
    public let saveRequirement: Int?
    public let timeLimitFrames: Int?
    public let skillLimit: Int?
    public let skillTypeLimit: Int?
    public let perSkillLimits: [NxlvSkill: Int]
    public let skillEachLimit: Int?
    public let useOnlySkill: NxlvSkill?
    public let source: NxlvSection

    public var effectiveColor: NxlvTalismanColor { color ?? .bronze }

    public var effectivePerSkillLimits: [NxlvSkill: Int] {
        var result = perSkillLimits
        if let skillEachLimit {
            for skill in NxlvSkill.allCases { result[skill] = skillEachLimit }
        }
        if let useOnlySkill {
            for skill in NxlvSkill.allCases where skill != useOnlySkill {
                result[skill] = 0
            }
        }
        return result
    }

    fileprivate init(section: NxlvSection, decoder: inout NxlvValueDecoder) {
        title = decoder.string(section, keys: ["title"])
        id = decoder.unsignedInteger(section, keys: ["id"], context: "talisman ID")

        if let colorLine = section.lastLineRecord("color") {
            color = NxlvTalismanColor(keyword: colorLine.value)
            if color == nil {
                decoder.append(
                    severity: .warning,
                    code: .invalidTalismanColor,
                    message: "Unknown talisman color '\(colorLine.value)'.",
                    line: colorLine.lineNumber
                )
            }
        } else {
            color = nil
        }

        saveRequirement = decoder.integer(
            section,
            keys: ["save_requirement", "save"],
            context: "talisman save requirement"
        )
        timeLimitFrames = decoder.integer(
            section,
            keys: ["time_limit"],
            context: "talisman time limit"
        )
        skillLimit = decoder.integer(
            section,
            keys: ["skill_limit"],
            context: "talisman skill limit"
        )
        skillTypeLimit = decoder.integer(
            section,
            keys: ["skill_type_limit"],
            context: "talisman skill-type limit"
        )

        var limits: [NxlvSkill: Int] = [:]
        for skill in NxlvSkill.allCases {
            if let limit = decoder.integer(
                section,
                keys: ["\(skill.rawValue)_limit"],
                context: "\(skill.rawValue) talisman limit"
            ) {
                limits[skill] = limit
            }
        }
        perSkillLimits = limits
        skillEachLimit = decoder.integer(
            section,
            keys: ["skill_each_limit"],
            context: "per-skill talisman limit"
        )

        if let onlySkillLine = section.lastLineRecord("use_only_skill") {
            useOnlySkill = NxlvSkill(keyword: onlySkillLine.value)
            if useOnlySkill == nil {
                decoder.append(
                    severity: .warning,
                    code: .invalidSkill,
                    message: "Unknown USE_ONLY_SKILL value '\(onlySkillLine.value)'.",
                    line: onlySkillLine.lineNumber
                )
            }
        } else {
            useOnlySkill = nil
        }
        source = section
    }
}

public struct NxlvTextBlock: Sendable {
    public let lines: [String]
    public let source: NxlvSection

    fileprivate init(section: NxlvSection) {
        lines = section.allLines("line")
        source = section
    }
}

public struct NxlvLevel: Sendable {
    public let document: NxlvSection
    public let diagnostics: [NxlvDiagnostic]

    public let title: String
    public let author: String
    public let themeStyle: String
    public let musicFile: String?
    public let id: UInt64?
    public let version: UInt64?
    public let lemmingsCount: Int
    public let saveRequirement: Int
    public let timeLimit: NxlvTimeLimit?
    public let spawnInterval: Int
    public let spawnIntervalLocked: Bool
    public let width: Int
    public let height: Int
    public let startX: Int
    public let startY: Int
    public let screenStart: NxlvScreenStart
    public let background: String?

    /// The complete typed skill supply, including explicit `INFINITE` values.
    public let skillQuantities: [NxlvSkill: NxlvSkillQuantity]
    public var skills: [NxlvSkill: NxlvSkillQuantity] { skillQuantities }
    /// Compatibility view of `skillQuantities`; infinite supplies map to 100.
    public let skillset: [String: Int]

    public let terrainPieces: [NxlvTerrainPlacement]
    public var terrain: [NxlvTerrainPlacement] { terrainPieces }
    public let terrainGroups: [NxlvTerrainGroup]
    public let gadgets: [NxlvGadget]
    public let preplacedLemmings: [NxlvLemming]
    public var lemmings: [NxlvLemming] { preplacedLemmings }
    public let talismans: [NxlvTalisman]
    public let preTextBlocks: [NxlvTextBlock]
    public let postTextBlocks: [NxlvTextBlock]
    public var preText: [String] { preTextBlocks.flatMap(\.lines) }
    public var postText: [String] { postTextBlocks.flatMap(\.lines) }

    public let dependencyScan: NxlvDependencyScan
    public var dependencies: NxlvDependencyScan { dependencyScan }

    public init?(text: String) {
        let result = Self.decode(text: text)
        guard let level = result.level else { return nil }
        self = level
    }

    public static func decode(text: String) -> NxlvLevelDecodeResult {
        let parseResult = NxlvParser.parseResult(text)
        var decoder = NxlvValueDecoder(diagnostics: parseResult.diagnostics)
        let level = NxlvLevel(document: parseResult.document, decoder: &decoder)
        return NxlvLevelDecodeResult(
            document: parseResult.document,
            level: level,
            diagnostics: decoder.diagnostics
        )
    }

    private init?(document root: NxlvSection, decoder: inout NxlvValueDecoder) {
        guard let titleLine = root.lastLineRecord("title") else {
            decoder.append(
                severity: .error,
                code: .missingRequiredField,
                message: "The level has no TITLE field.",
                line: nil
            )
            return nil
        }

        document = root
        title = titleLine.value
        author = root.line("author") ?? ""
        themeStyle = root.trimmedLine("theme") ?? ""
        musicFile = root.trimmedLine("music")
        id = decoder.unsignedInteger(root, keys: ["id"], context: "level ID")
        version = decoder.unsignedInteger(root, keys: ["version"], context: "level version")
        lemmingsCount = decoder.integer(root, keys: ["lemmings"], context: "lemming count") ?? 0
        saveRequirement = decoder.integer(
            root,
            keys: ["save_requirement", "requirement"],
            context: "save requirement"
        ) ?? 0
        timeLimit = decoder.timeLimit(root)

        if let maximum = decoder.integer(
            root,
            keys: ["max_spawn_interval"],
            context: "maximum spawn interval"
        ) {
            spawnInterval = maximum
        } else {
            let releaseRate = decoder.integer(
                root,
                keys: ["release_rate"],
                context: "legacy release rate"
            ) ?? 0
            spawnInterval = 53 - (releaseRate / 2)
        }
        spawnIntervalLocked = root.hasLine("spawn_interval_locked")
            || root.hasLine("release_rate_locked")

        width = decoder.integer(root, keys: ["width"], context: "level width") ?? 0
        height = decoder.integer(root, keys: ["height"], context: "level height") ?? 0
        let parsedStartX = decoder.integer(root, keys: ["start_x"], context: "screen start X")
        let parsedStartY = decoder.integer(root, keys: ["start_y"], context: "screen start Y")
        startX = parsedStartX ?? 0
        startY = parsedStartY ?? 0
        if let parsedStartX, let parsedStartY {
            screenStart = .position(x: parsedStartX, y: parsedStartY)
        } else {
            screenStart = .automatic
        }
        background = root.trimmedLine("background")

        let skillResult = Self.decodeSkills(root.section("skillset"), decoder: &decoder)
        skillQuantities = skillResult
        skillset = Dictionary(
            uniqueKeysWithValues: skillResult.map { ($0.key.rawValue, $0.value.legacyCount) }
        )

        terrainPieces = root.allSections("terrain").map {
            NxlvTerrainPlacement(section: $0, decoder: &decoder)
        }
        terrainGroups = root.allSections("terraingroup").map {
            NxlvTerrainGroup(section: $0, decoder: &decoder)
        }

        let gadgetSections = root.allSections("gadget")
        let selectedGadgetSections = gadgetSections.isEmpty
            ? root.allSections("object")
            : gadgetSections
        gadgets = selectedGadgetSections.map {
            NxlvGadget(section: $0, decoder: &decoder)
        }
        preplacedLemmings = root.allSections("lemming").map {
            NxlvLemming(section: $0, decoder: &decoder)
        }
        talismans = root.allSections("talisman").map {
            NxlvTalisman(section: $0, decoder: &decoder)
        }
        preTextBlocks = root.allSections("pretext").map(NxlvTextBlock.init(section:))
        postTextBlocks = root.allSections("posttext").map(NxlvTextBlock.init(section:))

        dependencyScan = Self.scanDependencies(
            root: root,
            themeStyle: themeStyle,
            musicFile: musicFile,
            background: background,
            terrain: terrainPieces,
            groups: terrainGroups,
            gadgets: gadgets
        )
        diagnostics = decoder.diagnostics
    }

    private static func decodeSkills(
        _ section: NxlvSection?,
        decoder: inout NxlvValueDecoder
    ) -> [NxlvSkill: NxlvSkillQuantity] {
        guard let section else { return [:] }
        var result: [NxlvSkill: NxlvSkillQuantity] = [:]

        for line in section.lineRecords {
            guard let skill = NxlvSkill(keyword: line.keyword) else {
                decoder.append(
                    severity: .warning,
                    code: .invalidSkill,
                    message: "Unknown skill '\(line.originalKeyword)' in $SKILLSET.",
                    line: line.lineNumber
                )
                continue
            }

            let value = line.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.caseInsensitiveCompare("INFINITE") == .orderedSame {
                result[skill] = .infinite
            } else if let quantity = NxlvNumber.integer(value) {
                result[skill] = .finite(quantity)
            } else {
                decoder.append(
                    severity: .warning,
                    code: .invalidSkillQuantity,
                    message: "Invalid quantity '\(line.value)' for \(skill.keyword).",
                    line: line.lineNumber
                )
            }
        }

        if result.count > 10 {
            decoder.append(
                severity: .warning,
                code: .tooManySkillTypes,
                message: "The skillset contains \(result.count) skill types; NeoLemmix supports at most 10.",
                line: section.openingLine
            )
        }
        return result
    }

    private static func scanDependencies(
        root: NxlvSection,
        themeStyle: String,
        musicFile: String?,
        background: String?,
        terrain: [NxlvTerrainPlacement],
        groups: [NxlvTerrainGroup],
        gadgets: [NxlvGadget]
    ) -> NxlvDependencyScan {
        var result: [NxlvDependency] = []

        if !themeStyle.isEmpty {
            let line = root.lastLineRecord("theme")?.lineNumber
            result.append(NxlvDependency(kind: .theme, identifier: themeStyle, sourceLine: line))
            result.append(NxlvDependency(kind: .style, identifier: themeStyle, sourceLine: line))
        }

        func appendStyle(_ style: String?, line: Int?) {
            guard let style, !style.isEmpty, !style.hasPrefix("*") else { return }
            result.append(NxlvDependency(kind: .style, identifier: style, sourceLine: line))
        }

        for placement in terrain {
            appendStyle(placement.style, line: placement.source.lastLineRecord("style")?.lineNumber
                        ?? placement.source.lastLineRecord("collection")?.lineNumber)
        }
        for group in groups {
            for placement in group.terrain {
                appendStyle(placement.style, line: placement.source.lastLineRecord("style")?.lineNumber
                            ?? placement.source.lastLineRecord("collection")?.lineNumber)
            }
        }
        for gadget in gadgets {
            appendStyle(gadget.style, line: gadget.source.lastLineRecord("style")?.lineNumber
                        ?? gadget.source.lastLineRecord("collection")?.lineNumber)
        }

        if let background, !background.isEmpty {
            let line = root.lastLineRecord("background")?.lineNumber
            result.append(NxlvDependency(kind: .background, identifier: background, sourceLine: line))
            if let separator = background.firstIndex(of: ":") {
                appendStyle(String(background[..<separator]), line: line)
            }
        }
        if let musicFile, !musicFile.isEmpty {
            result.append(NxlvDependency(
                kind: .music,
                identifier: musicFile,
                sourceLine: root.lastLineRecord("music")?.lineNumber
            ))
        }

        return NxlvDependencyScan(dependencies: result)
    }
}

public struct NxlvLevelDecodeResult: Sendable {
    public let document: NxlvSection
    public let level: NxlvLevel?
    public let diagnostics: [NxlvDiagnostic]

    public init(
        document: NxlvSection,
        level: NxlvLevel?,
        diagnostics: [NxlvDiagnostic]
    ) {
        self.document = document
        self.level = level
        self.diagnostics = diagnostics
    }
}

fileprivate struct NxlvValueDecoder {
    var diagnostics: [NxlvDiagnostic]

    init(diagnostics: [NxlvDiagnostic] = []) {
        self.diagnostics = diagnostics
    }

    mutating func append(
        severity: NxlvDiagnosticSeverity,
        code: NxlvDiagnosticCode,
        message: String,
        line: Int?
    ) {
        diagnostics.append(NxlvDiagnostic(
            severity: severity,
            code: code,
            message: message,
            line: line
        ))
    }

    func string(_ section: NxlvSection, keys: [String]) -> String? {
        selectedLine(section, keys: keys)?.value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func integer(_ section: NxlvSection, keys: [String], context: String) -> Int? {
        guard let line = selectedLine(section, keys: keys) else { return nil }
        guard let value = NxlvNumber.integer(line.value) else {
            append(
                severity: .warning,
                code: .malformedInteger,
                message: "Invalid integer '\(line.value)' for \(context).",
                line: line.lineNumber
            )
            return nil
        }
        return value
    }

    mutating func unsignedInteger(
        _ section: NxlvSection,
        keys: [String],
        context: String
    ) -> UInt64? {
        guard let line = selectedLine(section, keys: keys) else { return nil }
        guard let value = NxlvNumber.unsignedInteger(line.value) else {
            append(
                severity: .warning,
                code: .malformedUnsignedInteger,
                message: "Invalid unsigned integer '\(line.value)' for \(context).",
                line: line.lineNumber
            )
            return nil
        }
        return value
    }

    mutating func timeLimit(_ section: NxlvSection) -> NxlvTimeLimit? {
        guard let line = selectedLine(section, keys: ["time_limit"]) else { return nil }
        let value = line.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty || value.caseInsensitiveCompare("INFINITE") == .orderedSame {
            return .infinite
        }
        if let seconds = NxlvNumber.integer(value) {
            return .seconds(seconds)
        }
        append(
            severity: .warning,
            code: .invalidTimeLimit,
            message: "Invalid TIME_LIMIT value '\(line.value)'.",
            line: line.lineNumber
        )
        return nil
    }

    private func selectedLine(_ section: NxlvSection, keys: [String]) -> NxlvLine? {
        for key in keys {
            if let line = section.lastLineRecord(key) { return line }
        }
        return nil
    }
}
