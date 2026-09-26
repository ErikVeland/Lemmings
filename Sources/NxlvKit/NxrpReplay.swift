import Foundation

public enum NxrpDiagnosticSeverity: String, Sendable {
    case warning
    case error
}

public enum NxrpDiagnosticCode: String, Sendable {
    case malformedDocument
    case unsupportedLegacyFormat
    case unsupportedSection
    case missingRequiredField
    case malformedInteger
    case invalidValue
    case invalidSkill
}

public struct NxrpDiagnostic: Sendable, Equatable {
    public let severity: NxrpDiagnosticSeverity
    public let code: NxrpDiagnosticCode
    public let message: String
    public let line: Int?

    public init(
        severity: NxrpDiagnosticSeverity,
        code: NxrpDiagnosticCode,
        message: String,
        line: Int? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.line = line
    }
}

/// Identifies the level and player recorded in a current-format NeoLemmix replay.
public struct NxrpMetadata: Sendable, Equatable {
    public let user: String?
    public let title: String?
    public let author: String?
    public let game: String?
    public let group: String?
    public let levelPosition: Int?
    public let levelID: UInt64?
    public let levelVersion: UInt64?
    public let expectedCompletionFrame: Int?

    public init(
        user: String? = nil,
        title: String? = nil,
        author: String? = nil,
        game: String? = nil,
        group: String? = nil,
        levelPosition: Int? = nil,
        levelID: UInt64? = nil,
        levelVersion: UInt64? = nil,
        expectedCompletionFrame: Int? = nil
    ) {
        self.user = user
        self.title = title
        self.author = author
        self.game = game
        self.group = group
        self.levelPosition = levelPosition
        self.levelID = levelID
        self.levelVersion = levelVersion
        self.expectedCompletionFrame = expectedCompletionFrame
    }
}

/// A decoded current-format `.nxrp` replay.
public struct NxrpReplay: Sendable, Equatable {
    public let metadata: NxrpMetadata
    public let commands: [NeoLemmixReplayCommand]

    public init(metadata: NxrpMetadata, commands: [NeoLemmixReplayCommand]) {
        self.metadata = metadata
        self.commands = commands
    }
}

public struct NxrpDecodeResult: Sendable {
    public let replay: NxrpReplay?
    public let diagnostics: [NxrpDiagnostic]

    public init(replay: NxrpReplay?, diagnostics: [NxrpDiagnostic]) {
        self.replay = replay
        self.diagnostics = diagnostics
    }

    public var hasErrors: Bool {
        diagnostics.contains { $0.severity == .error }
    }
}

/// Decodes the section-based replay format written by NeoLemmix 12.14 and CE.
public enum NxrpReplayDecoder {
    public static func decode(_ text: String) -> NxrpDecodeResult {
        let parsed = NxlvParser.parseResult(text)
        let document = parsed.document
        var diagnostics = parsed.diagnostics.map {
            NxrpDiagnostic(
                severity: .error,
                code: .malformedDocument,
                message: $0.message,
                line: $0.line
            )
        }

        if document.subsections.isEmpty, document.hasLine("actions") {
            diagnostics.append(NxrpDiagnostic(
                severity: .error,
                code: .unsupportedLegacyFormat,
                message: "The legacy NeoLemmix replay format is not supported."
            ))
        }

        func optionalString(_ key: String) -> String? {
            guard let value = document.trimmedLine(key), !value.isEmpty else { return nil }
            return value
        }

        func optionalInteger(_ key: String, minimum: Int = 0) -> Int? {
            guard let record = document.lastLineRecord(key) else { return nil }
            guard let value = NxlvNumber.integer(record.value) else {
                diagnostics.append(NxrpDiagnostic(
                    severity: .error,
                    code: .malformedInteger,
                    message: "\(record.originalKeyword) must be an integer.",
                    line: record.lineNumber
                ))
                return nil
            }
            guard value >= minimum else {
                diagnostics.append(NxrpDiagnostic(
                    severity: .error,
                    code: .invalidValue,
                    message: "\(record.originalKeyword) must be at least \(minimum).",
                    line: record.lineNumber
                ))
                return nil
            }
            return value
        }

        func optionalUnsignedInteger(_ key: String) -> UInt64? {
            guard let record = document.lastLineRecord(key) else { return nil }
            guard let value = NxlvNumber.unsignedInteger(record.value) else {
                diagnostics.append(NxrpDiagnostic(
                    severity: .error,
                    code: .malformedInteger,
                    message: "\(record.originalKeyword) must be an unsigned decimal or hexadecimal integer.",
                    line: record.lineNumber
                ))
                return nil
            }
            return value
        }

        let metadata = NxrpMetadata(
            user: optionalString("user"),
            title: optionalString("title"),
            author: optionalString("author"),
            game: optionalString("game"),
            group: optionalString("group"),
            levelPosition: optionalInteger("level"),
            levelID: optionalUnsignedInteger("id"),
            levelVersion: optionalUnsignedInteger("version"),
            expectedCompletionFrame: optionalInteger("completion_frame")
        )

        var commands: [NeoLemmixReplayCommand] = []
        var sequence: UInt64 = 0

        for entry in document.entries {
            guard case let .section(section) = entry else { continue }

            switch section.keyword {
            case "assignment":
                let frame = requiredInteger(
                    "frame", minimum: 0, in: section, diagnostics: &diagnostics
                )
                let lemmingIndex = requiredInteger(
                    "lem_index", minimum: 0, in: section, diagnostics: &diagnostics
                )
                guard let action = section.lastLineRecord("action") else {
                    diagnostics.append(NxrpDiagnostic(
                        severity: .error,
                        code: .missingRequiredField,
                        message: "$\(section.originalKeyword) requires ACTION.",
                        line: section.openingLine
                    ))
                    continue
                }
                guard let skill = NeoLemmixSkill(rawValue: action.value
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()) else {
                    diagnostics.append(NxrpDiagnostic(
                        severity: .error,
                        code: .invalidSkill,
                        message: "ACTION names an unknown NeoLemmix skill.",
                        line: action.lineNumber
                    ))
                    continue
                }
                guard let frame, let lemmingIndex else { continue }
                commands.append(NeoLemmixReplayCommand(
                    tick: frame,
                    sequence: sequence,
                    command: .assign(lemmingID: lemmingIndex, skill: skill)
                ))
                sequence += 1
                continue

            case "spawn_interval":
                let frame = requiredInteger(
                    "frame", minimum: 0, in: section, diagnostics: &diagnostics
                )
                let rateKey = section.hasLine("interval") ? "interval" : "rate"
                let interval = requiredInteger(
                    rateKey, minimum: 1, in: section, diagnostics: &diagnostics
                )
                guard let frame, let interval else { continue }
                commands.append(NeoLemmixReplayCommand(
                    tick: frame,
                    sequence: sequence,
                    command: .setSpawnInterval(interval)
                ))
                sequence += 1

            case "nuke":
                guard let frame = requiredInteger(
                    "frame", minimum: 0, in: section, diagnostics: &diagnostics
                ) else { continue }
                commands.append(NeoLemmixReplayCommand(
                    tick: frame,
                    sequence: sequence,
                    command: .nuke
                ))
                sequence += 1

            default:
                diagnostics.append(NxrpDiagnostic(
                    severity: .warning,
                    code: .unsupportedSection,
                    message: "Replay section $\(section.originalKeyword) is not recognised.",
                    line: section.openingLine
                ))
                continue
            }
        }

        let hasErrors = diagnostics.contains { $0.severity == .error }
        return NxrpDecodeResult(
            replay: hasErrors ? nil : NxrpReplay(metadata: metadata, commands: commands),
            diagnostics: diagnostics
        )
    }

    private static func requiredInteger(
        _ key: String,
        minimum: Int,
        in section: NxlvSection,
        diagnostics: inout [NxrpDiagnostic]
    ) -> Int? {
        guard let record = section.lastLineRecord(key) else {
            diagnostics.append(NxrpDiagnostic(
                severity: .error,
                code: .missingRequiredField,
                message: "$\(section.originalKeyword) requires \(key.uppercased()).",
                line: section.openingLine
            ))
            return nil
        }
        guard let value = NxlvNumber.integer(record.value) else {
            diagnostics.append(NxrpDiagnostic(
                severity: .error,
                code: .malformedInteger,
                message: "\(record.originalKeyword) must be an integer.",
                line: record.lineNumber
            ))
            return nil
        }
        guard value >= minimum else {
            diagnostics.append(NxrpDiagnostic(
                severity: .error,
                code: .invalidValue,
                message: "\(record.originalKeyword) must be at least \(minimum).",
                line: record.lineNumber
            ))
            return nil
        }
        return value
    }
}
