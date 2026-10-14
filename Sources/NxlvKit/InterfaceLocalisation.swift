import Foundation

/// A complete interface message. Interpolated values are kept out of translation keys.
public struct InterfaceMessage: ExpressibleByStringLiteral, ExpressibleByStringInterpolation, Sendable {
    public let key: String
    public let arguments: [String]

    public init(stringLiteral value: String) { key = value; arguments = [] }
    public init(stringInterpolation: StringInterpolation) {
        key = stringInterpolation.key
        arguments = stringInterpolation.arguments
    }

    public struct StringInterpolation: StringInterpolationProtocol, Sendable {
        fileprivate var key = ""
        fileprivate var arguments: [String] = []
        public init(literalCapacity: Int, interpolationCount: Int) {
            key.reserveCapacity(literalCapacity)
            arguments.reserveCapacity(interpolationCount)
        }
        public mutating func appendLiteral(_ literal: String) { key += literal }
        public mutating func appendInterpolation<T>(_ value: T) {
            key += "{\(arguments.count)}"
            arguments.append(String(describing: value))
        }
    }
}

/// Immutable localisation state, shared by menus, game controls and accessibility.
public struct InterfaceLocalisation: Sendable {
    public let language: String
    public let locale: Locale
    public let expandsText: Bool
    private let bundle: Bundle?

    public init(bundle: Bundle?, preferredLanguages: [String] = Locale.preferredLanguages,
                expandsText: Bool = false) {
        let available = bundle?.localizations.filter { $0 != "Base" } ?? ["en"]
        let selected = Bundle.preferredLocalizations(from: available, forPreferences: preferredLanguages).first ?? "en"
        self.language = selected
        self.locale = Locale(identifier: selected)
        self.expandsText = expandsText
        self.bundle = bundle?.url(forResource: selected, withExtension: "lproj").flatMap { Bundle(url: $0) }
    }

    public func text(_ message: InterfaceMessage) -> String {
        let translated = bundle?.localizedString(forKey: message.key, value: message.key, table: "Interface") ?? message.key
        // A damaged translation must not hide a value or display a placeholder.
        let valid = Self.placeholders(translated) == Self.placeholders(message.key)
        let template = valid ? translated : message.key
        return Self.render(expandsText ? Self.expanded(template) : template, arguments: message.arguments)
    }

    /// Uses Apple's plural selection from Interface.stringsdict. Counts stay numeric.
    public func plural(_ key: String, count: Int, one: String, other: String) -> String {
        let fallback = count == 1 ? one : other
        let format = bundle?.localizedString(forKey: key, value: fallback, table: "Interface") ?? fallback
        let result = String(format: format, locale: locale, arguments: [count])
        return expandsText ? Self.expanded(result) : result
    }

    public func number(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    private static let placeholder = try! NSRegularExpression(pattern: #"\{([0-9]+)\}"#)
    private static func placeholders(_ text: String) -> Set<String> {
        let string = text as NSString
        return Set(placeholder.matches(in: text, range: NSRange(location: 0, length: string.length))
            .map { string.substring(with: $0.range(at: 1)) })
    }

    private static func render(_ template: String, arguments: [String]) -> String {
        let string = template as NSString
        let matches = placeholder.matches(in: template, range: NSRange(location: 0, length: string.length))
        var result = "", cursor = 0
        for match in matches {
            result += string.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            if let index = Int(string.substring(with: match.range(at: 1))), arguments.indices.contains(index) {
                result += arguments[index]
            } else { result += string.substring(with: match.range) }
            cursor = NSMaxRange(match.range)
        }
        return result + string.substring(from: cursor)
    }

    /// ASCII expansion exercises the shipped bitmap fonts without changing player data.
    private static func expanded(_ text: String) -> String {
        "[" + text.map { "aeiouAEIOU".contains($0) ? String(repeating: String($0), count: 2) : String($0) }.joined() + "]"
    }
}

public enum L10n {
    public static let interface: InterfaceLocalisation = {
        let resource: Bundle?
        #if SWIFT_PACKAGE
        resource = Bundle.module.url(forResource: "Localization", withExtension: "bundle").flatMap { Bundle(url: $0) }
        #else
        resource = Bundle.main.url(forResource: "Localization", withExtension: "bundle").flatMap { Bundle(url: $0) }
        #endif
        let testLanguage = ProcessInfo.processInfo.environment["LEMMINGS_TEST_LANGUAGE"]
        return InterfaceLocalisation(bundle: resource,
            preferredLanguages: testLanguage.map { [$0] } ?? Locale.preferredLanguages,
            expandsText: testLanguage == "en-XA")
    }()

    public static func text(_ message: InterfaceMessage) -> String { interface.text(message) }
    public static func plural(_ key: String, count: Int, one: String, other: String) -> String {
        interface.plural(key, count: count, one: one, other: other)
    }
}
