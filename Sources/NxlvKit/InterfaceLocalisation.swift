import Foundation

/**
 * Interface choices retain stable locale identifiers and each language's own name.
 */
public enum InterfaceLanguage: String, CaseIterable, Hashable, Sendable {
    case system
    case english = "en"
    case spanishLatinAmerica = "es-419"
    case german = "de"
    case french = "fr"
    case portugueseBrazil = "pt-BR"
    case italian = "it"
    case dutch = "nl"
    case norwegianBokmal = "nb"
    case tamil = "ta"

    public var title: String {
        switch self {
        case .system: return L10n.text("System default")
        case .english: return "English"
        case .spanishLatinAmerica: return "Español (Latinoamérica)"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .portugueseBrazil: return "Português (Brasil)"
        case .italian: return "Italiano"
        case .dutch: return "Nederlands"
        case .norwegianBokmal: return "Norsk bokmål"
        case .tamil: return "தமிழ்"
        }
    }
}

/**
 * App-wide persistence is separate from temporary language previews.
 */
public enum InterfaceLanguagePreference {
    public static let defaultsKey = "InterfaceLanguageOverrideV1"

    public static func options(availableLanguages: [String]) -> [InterfaceLanguage] {
        let available = Set(availableLanguages.map { $0.replacingOccurrences(of: "_", with: "-").lowercased() })
        return InterfaceLanguage.allCases.filter {
            $0 == .system || $0 == .english || available.contains($0.rawValue.lowercased())
        }
    }

    public static func load(from defaults: UserDefaults,
                            availableLanguages: [String] = L10n.availableLanguageIdentifiers) -> InterfaceLanguage {
        guard let stored = defaults.string(forKey: defaultsKey), let choice = InterfaceLanguage(rawValue: stored),
              options(availableLanguages: availableLanguages).contains(choice) else { return .system }
        return choice
    }

    public static func save(_ choice: InterfaceLanguage, to defaults: UserDefaults) {
        if choice == .system { defaults.removeObject(forKey: defaultsKey) }
        else { defaults.set(choice.rawValue, forKey: defaultsKey) }
    }

    /**
     * The test environment takes priority over the saved choice and system language order.
     */
    public static func resolve(_ choice: InterfaceLanguage, systemPreferredLanguages: [String] = Locale.preferredLanguages,
                               testLanguage: String? = nil,
                               availableLanguages: [String] = L10n.availableLanguageIdentifiers) -> [String] {
        if let testLanguage { return [testLanguage] }
        return choice == .system || !options(availableLanguages: availableLanguages).contains(choice)
            ? systemPreferredLanguages : [choice.rawValue]
    }
}

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

/// Immutable localisation snapshot, shared by menus, game controls and accessibility.
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
            && (!translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || message.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    fileprivate func contains(_ key: String) -> Bool {
        let missing = "\u{F8FF}missing\u{F8FF}"
        return bundle?.localizedString(forKey: key, value: missing, table: "Interface") != missing && bundle != nil
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
    private static let resourceBundle: Bundle? = {
        #if SWIFT_PACKAGE
        return Bundle.module.url(forResource: "Localization", withExtension: "bundle").flatMap { Bundle(url: $0) }
        #else
        return Bundle.main.url(forResource: "Localization", withExtension: "bundle").flatMap { Bundle(url: $0) }
        #endif
    }()
    public static let availableLanguageIdentifiers = resourceBundle?.localizations.filter { $0 != "Base" } ?? ["en"]
    public static let languageOptions = InterfaceLanguagePreference.options(availableLanguages: availableLanguageIdentifiers)
    public static let languageDidChange = Notification.Name("InterfaceLanguageDidChange")
    private static let testLanguage = ProcessInfo.processInfo.environment["LEMMINGS_TEST_LANGUAGE"]

    /**
     * Only snapshot reads and replacements hold the lock. Translation runs after the lock is released.
     */
    private final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var preference: InterfaceLanguage
        private var localisation: InterfaceLocalisation

        init(preference: InterfaceLanguage, localisation: InterfaceLocalisation) {
            self.preference = preference
            self.localisation = localisation
        }

        func read() -> (preference: InterfaceLanguage, localisation: InterfaceLocalisation) {
            lock.lock(); defer { lock.unlock() }
            return (preference, localisation)
        }

        func replace(preference: InterfaceLanguage, localisation: InterfaceLocalisation) -> Bool {
            lock.lock(); defer { lock.unlock() }
            let changed = self.preference != preference || self.localisation.language != localisation.language
                || self.localisation.expandsText != localisation.expandsText
            self.preference = preference
            self.localisation = localisation
            return changed
        }
    }

    private static let state: State = {
        let preference = InterfaceLanguagePreference.load(from: .standard, availableLanguages: availableLanguageIdentifiers)
        return State(preference: preference, localisation: makeInterface(preference))
    }()

    public static var currentLanguagePreference: InterfaceLanguage { state.read().preference }
    public static var interface: InterfaceLocalisation { state.read().localisation }

    /**
     * Preview a choice synchronously without saving it. The caller refreshes its visible controls.
     */
    @discardableResult public static func setLanguage(_ choice: InterfaceLanguage,
                                                     systemPreferredLanguages: [String] = Locale.preferredLanguages) -> Bool {
        let preference = languageOptions.contains(choice) ? choice : .system
        let localisation = makeInterface(preference, systemPreferredLanguages: systemPreferredLanguages)
        let changed = state.replace(preference: preference, localisation: localisation)
        if changed { NotificationCenter.default.post(name: languageDidChange, object: nil) }
        return changed
    }

    private static func makeInterface(_ choice: InterfaceLanguage,
                                      systemPreferredLanguages: [String] = Locale.preferredLanguages) -> InterfaceLocalisation {
        InterfaceLocalisation(bundle: resourceBundle,
            preferredLanguages: InterfaceLanguagePreference.resolve(choice,
                systemPreferredLanguages: systemPreferredLanguages, testLanguage: testLanguage),
            expandsText: testLanguage == "en-XA")
    }

    public static func text(_ message: InterfaceMessage) -> String { interface.text(message) }
    public static func originalL2Text(_ source: String) -> String {
        let localisation = interface
        if localisation.language == "en" && !localisation.expandsText { return source }
        return source.components(separatedBy: "\r").map { line in
            let key = line.trimmingCharacters(in: .whitespaces)
            guard localisation.contains(key) else { return line }
            return localisation.text(InterfaceMessage(stringLiteral: key))
        }.joined(separator: "\r")
    }
    public static func plural(_ key: String, count: Int, one: String, other: String) -> String {
        interface.plural(key, count: count, one: one, other: other)
    }
}
