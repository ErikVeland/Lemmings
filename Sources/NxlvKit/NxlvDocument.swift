import Foundation

public enum NxlvDiagnosticSeverity: String, Sendable {
    case warning
    case error
}

public enum NxlvDiagnosticCode: String, Sendable {
    case unexpectedEnd
    case unterminatedSection
    case invalidSectionMarker
    case missingRequiredField
    case malformedInteger
    case malformedUnsignedInteger
    case invalidSkill
    case invalidSkillQuantity
    case invalidDirection
    case tooManySkillTypes
    case invalidTalismanColor
    case invalidTimeLimit
    case missingDependency
}

public struct NxlvDiagnostic: Sendable, Equatable {
    public let severity: NxlvDiagnosticSeverity
    public let code: NxlvDiagnosticCode
    public let message: String
    public let line: Int?

    public init(
        severity: NxlvDiagnosticSeverity,
        code: NxlvDiagnosticCode,
        message: String,
        line: Int? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.line = line
    }
}

public struct NxlvLine: Sendable, Equatable {
    /// The case-insensitive form used for lookups.
    public let keyword: String
    /// The spelling found in the source document.
    public let originalKeyword: String
    public let value: String
    public let lineNumber: Int

    public var key: String { keyword }

    init(keyword: String, value: String, lineNumber: Int) {
        originalKeyword = keyword
        self.keyword = keyword.lowercased()
        self.value = value
        self.lineNumber = lineNumber
    }
}

public enum NxlvEntry: Sendable {
    case line(NxlvLine)
    case section(NxlvSection)
}

/// An ordered NeoLemmix text-format section.
///
/// `entries` retains the relative order of lines and nested sections. The
/// `lines` and `subsections` views remain available for source compatibility.
public final class NxlvSection: @unchecked Sendable {
    /// The case-insensitive form used for lookups.
    public let keyword: String
    /// The spelling found in the source document.
    public let originalKeyword: String
    public let openingLine: Int
    public private(set) var entries: [NxlvEntry] = []

    public var lines: [(key: String, value: String)] {
        lineRecords.map { (key: $0.keyword, value: $0.value) }
    }

    public var lineRecords: [NxlvLine] {
        entries.compactMap {
            guard case let .line(line) = $0 else { return nil }
            return line
        }
    }

    public var subsections: [NxlvSection] {
        entries.compactMap {
            guard case let .section(section) = $0 else { return nil }
            return section
        }
    }

    init(keyword: String, openingLine: Int = 0) {
        originalKeyword = keyword
        self.keyword = keyword.lowercased()
        self.openingLine = openingLine
    }

    func addLine(key: String, value: String, lineNumber: Int) {
        entries.append(.line(NxlvLine(keyword: key, value: value, lineNumber: lineNumber)))
    }

    func addSubsection(_ section: NxlvSection) {
        entries.append(.section(section))
    }

    public func line(_ key: String) -> String? {
        lastLineRecord(key)?.value
    }

    public func allLines(_ key: String) -> [String] {
        allLineRecords(key).map(\.value)
    }

    public func allLineRecords(_ key: String) -> [NxlvLine] {
        let normalizedKey = key.lowercased()
        return lineRecords.filter { $0.keyword == normalizedKey }
    }

    public func lastLineRecord(_ key: String) -> NxlvLine? {
        let normalizedKey = key.lowercased()
        return lineRecords.last(where: { $0.keyword == normalizedKey })
    }

    public func hasLine(_ key: String) -> Bool {
        lastLineRecord(key) != nil
    }

    public func trimmedLine(_ key: String) -> String? {
        line(key)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func numeric(_ key: String) -> Int? {
        trimmedLine(key).flatMap(NxlvNumber.integer)
    }

    public func numeric(_ key: String, default defaultValue: Int) -> Int {
        numeric(key) ?? defaultValue
    }

    public func unsignedNumeric(_ key: String) -> UInt64? {
        trimmedLine(key).flatMap(NxlvNumber.unsignedInteger)
    }

    public func section(_ key: String) -> NxlvSection? {
        let normalizedKey = key.lowercased()
        return subsections.last(where: { $0.keyword == normalizedKey })
    }

    public func allSections(_ key: String) -> [NxlvSection] {
        let normalizedKey = key.lowercased()
        return subsections.filter { $0.keyword == normalizedKey }
    }

    /// Produces a canonical text representation while retaining entry order,
    /// source keyword spelling, values, and unknown fields.
    public func rendered() -> String {
        renderEntries(indentation: "", includeMarkers: !keyword.isEmpty)
    }

    private func renderEntries(indentation: String, includeMarkers: Bool) -> String {
        var output: [String] = []
        let childIndentation = includeMarkers ? indentation + "  " : indentation

        if includeMarkers {
            output.append("\(indentation)$\(originalKeyword)")
        }

        for entry in entries {
            switch entry {
            case let .line(line):
                let suffix = line.value.isEmpty ? "" : " \(line.value)"
                output.append("\(childIndentation)\(line.originalKeyword)\(suffix)")
            case let .section(section):
                output.append(section.renderEntries(
                    indentation: childIndentation,
                    includeMarkers: true
                ))
            }
        }

        if includeMarkers {
            output.append("\(indentation)$END")
        }

        return output.joined(separator: "\n")
    }
}

public struct NxlvParseResult: Sendable {
    public let document: NxlvSection
    public let diagnostics: [NxlvDiagnostic]

    public init(document: NxlvSection, diagnostics: [NxlvDiagnostic]) {
        self.document = document
        self.diagnostics = diagnostics
    }
}

public enum NxlvNumber {
    public static func integer(_ value: String) -> Int? {
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return nil }

        var digits = token[...]
        var isNegative = false
        if digits.first == "+" {
            digits.removeFirst()
        } else if digits.first == "-" {
            isNegative = true
            digits.removeFirst()
        }

        guard !digits.isEmpty else { return nil }
        guard digits.first == "x" || digits.first == "X" else {
            return Int(token)
        }

        digits.removeFirst()
        guard !digits.isEmpty, let magnitude = UInt64(digits, radix: 16) else { return nil }

        if isNegative {
            let minimumMagnitude = UInt64(Int.max) + 1
            if magnitude == minimumMagnitude { return Int.min }
            guard magnitude <= UInt64(Int.max) else { return nil }
            return -Int(magnitude)
        }

        guard magnitude <= UInt64(Int.max) else { return nil }
        return Int(magnitude)
    }

    public static func unsignedInteger(_ value: String) -> UInt64? {
        var token = value.trimmingCharacters(in: .whitespacesAndNewlines)[...]
        guard !token.isEmpty else { return nil }

        if token.first == "+" { token.removeFirst() }
        guard !token.isEmpty, token.first != "-" else { return nil }

        if token.first == "x" || token.first == "X" {
            token.removeFirst()
            guard !token.isEmpty else { return nil }
            return UInt64(token, radix: 16)
        }

        return UInt64(token, radix: 10)
    }
}

public enum NxlvParser {
    public static func parse(_ text: String) -> NxlvSection {
        parseResult(text).document
    }

    public static func parseResult(_ text: String) -> NxlvParseResult {
        var source = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        if source.first == "\u{feff}" { source.removeFirst() }

        let root = NxlvSection(keyword: "")
        var stack = [root]
        var diagnostics: [NxlvDiagnostic] = []
        let sourceLines = source.split(separator: "\n", omittingEmptySubsequences: false)

        for (offset, rawLine) in sourceLines.enumerated() {
            let lineNumber = offset + 1
            let line = rawLine.drop(while: { $0 == " " || $0 == "\t" })
            guard !line.isEmpty, line.first != "#" else { continue }

            if line.first == "$" {
                let sourceKeyword = line.dropFirst()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !sourceKeyword.isEmpty else {
                    diagnostics.append(NxlvDiagnostic(
                        severity: .warning,
                        code: .invalidSectionMarker,
                        message: "A section marker has no keyword.",
                        line: lineNumber
                    ))
                    continue
                }

                if sourceKeyword.lowercased() == "end" {
                    if stack.count > 1 {
                        stack.removeLast()
                    } else {
                        diagnostics.append(NxlvDiagnostic(
                            severity: .warning,
                            code: .unexpectedEnd,
                            message: "The document contains an unmatched $END.",
                            line: lineNumber
                        ))
                    }
                } else {
                    let section = NxlvSection(keyword: sourceKeyword, openingLine: lineNumber)
                    stack[stack.count - 1].addSubsection(section)
                    stack.append(section)
                }
                continue
            }

            let separator = line.firstIndex(where: { $0 == " " || $0 == "\t" })
            let sourceKey: Substring
            let value: String
            if let separator {
                sourceKey = line[..<separator]
                let remainder = line[separator...]
                    .drop(while: { $0 == " " || $0 == "\t" })
                value = String(remainder)
            } else {
                sourceKey = line
                value = ""
            }

            guard !sourceKey.isEmpty else { continue }
            stack[stack.count - 1].addLine(
                key: String(sourceKey),
                value: value,
                lineNumber: lineNumber
            )
        }

        for section in stack.dropFirst() {
            diagnostics.append(NxlvDiagnostic(
                severity: .warning,
                code: .unterminatedSection,
                message: "Section $\(section.originalKeyword) has no matching $END.",
                line: section.openingLine
            ))
        }

        return NxlvParseResult(document: root, diagnostics: diagnostics)
    }
}
