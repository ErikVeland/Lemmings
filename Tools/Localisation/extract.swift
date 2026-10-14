import Foundation
import SwiftParser
import SwiftSyntax

/// Parse Swift expressions so quotes, interpolation and multiline messages retain their meaning.
final class Messages: SyntaxVisitor {
    let file: String
    let locations: SourceLocationConverter
    var messages: [[String: Any]] = []
    var uncovered: [[String: Any]] = []
    init(file: String, tree: SourceFileSyntax) {
        self.file = file
        locations = SourceLocationConverter(fileName: file, tree: tree)
        super.init(viewMode: .sourceAccurate)
    }
    func template(_ literal: StringLiteralExprSyntax) -> String? {
        var index = 0
        let segments = literal.segments.map { segment -> StringLiteralSegmentListSyntax.Element in
            if segment.is(ExpressionSegmentSyntax.self) {
                defer { index += 1 }
                return .stringSegment(StringSegmentSyntax(content: .stringSegment("{\(index)}")))
            }
            return segment
        }
        return literal.with(\.segments, StringLiteralSegmentListSyntax(segments)).representedLiteralValue
    }
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        let callee = node.calledExpression.trimmedDescription
        if callee == "L10n.text", let literal = node.arguments.first?.expression.as(StringLiteralExprSyntax.self), let key = template(literal) {
            messages.append(["key": key, "kind": "text", "file": file, "line": locations.location(for: node.positionAfterSkippingLeadingTrivia).line])
        } else if callee == "L10n.plural", let key = node.arguments.first?.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue {
            var row: [String: Any] = ["key": key, "kind": "plural", "file": file, "line": locations.location(for: node.positionAfterSkippingLeadingTrivia).line]
            for argument in node.arguments where ["one", "other"].contains(argument.label?.text ?? "") {
                row[argument.label!.text] = argument.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
            }
            messages.append(row)
        }
        return .visitChildren
    }
    override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        guard let source = template(node), source.contains(where: { $0.isLetter }) else { return .visitChildren }
        var parent = node.parent
        var ui = false
        while let value = parent {
            if let call = value.as(FunctionCallExprSyntax.self), ["L10n.text", "L10n.plural"].contains(call.calledExpression.trimmedDescription) { return .visitChildren }
            if let argument = value.as(LabeledExprSyntax.self), ["title", "label", "subtitle", "messageText", "informativeText", "accessibilityLabel", "accessibilityHint", "placeholder", "placeholderString"].contains(argument.label?.text ?? "") { ui = true }
            if let call = value.as(FunctionCallExprSyntax.self) {
                if call.calledExpression.trimmedDescription.hasSuffix("setAccessibilityLabel") || call.calledExpression.trimmedDescription.hasSuffix("setAccessibilityHelp") { ui = true }
                if call.calledExpression.trimmedDescription == "UIAccessibilityCustomAction", call.arguments.first?.label?.text == "name" { ui = true }
                break
            }
            if let sequence = value.as(SequenceExprSyntax.self) {
                let parts = Array(sequence.elements)
                if parts.count > 2, parts[1].is(AssignmentExprSyntax.self),
                   ["title", "text", "stringValue", "messageText", "informativeText", "accessibilityLabel", "accessibilityHint", "placeholderString"].contains(parts[0].trimmedDescription.components(separatedBy: ".").last ?? "") { ui = true }
                break
            }
            parent = value.parent
        }
        if ui { uncovered.append(["source": source, "file": file, "literal": node.trimmedDescription, "start": node.positionAfterSkippingLeadingTrivia.utf8Offset, "end": node.endPositionBeforeTrailingTrivia.utf8Offset, "line": locations.location(for: node.positionAfterSkippingLeadingTrivia).line]) }
        return .visitChildren
    }
}
var messages: [[String: Any]] = [], uncovered: [[String: Any]] = []
for file in CommandLine.arguments.dropFirst() {
    let source = try String(contentsOfFile: file, encoding: .utf8)
    let tree = Parser.parse(source: source)
    guard !tree.hasError else {
        FileHandle.standardError.write(Data("Cannot extract localisation from invalid Swift: \(file)\n".utf8))
        exit(1)
    }
    let visitor = Messages(file: file, tree: tree)
    visitor.walk(tree)
    messages += visitor.messages
    uncovered += visitor.uncovered
}
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: ["messages": messages, "uncovered": uncovered], options: [.sortedKeys]))
