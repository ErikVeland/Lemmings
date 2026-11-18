import Foundation
import NxlvKit

/// Product wording changes only at the presentation boundary.
public enum GamePresentationText {
    public static var usesLemmixNames: Bool {
        Bundle.main.object(forInfoDictionaryKey: "UltimateLemmixStore") as? Bool == true
            && !GameResources.hasRestoredOriginalAssets
    }

    private static let titles: [(String, String)] = [
        ("Ultimate Lemmings", "Ultimate Lemmix"),
        ("Lemmings 3: The Chronicles", "Chronicles"),
        ("Lemmings 2: The Tribes", "The Tribes"),
        ("Lemmings 2 — The Tribes", "The Tribes"),
        ("Lemmings 2 - The Tribes", "The Tribes"),
        ("All New World of Lemmings", "All New World"),
        ("The Lemmings Chronicles", "Chronicles"),
        ("Oh No! More Lemmings", "Oh No! More"),
        ("Oh Yes! More Lemmings", "Oh Yes! More"),
        ("Classic Lemmings", "Classic"), ("Holiday Lemmings", "Holiday"),
        ("Xmas Lemmings", "Xmas"), ("Christmas Lemmings", "Christmas"),
        ("Fan Lemmings", "Fan"), ("Lemmings 2", "The Tribes"),
        ("Lemmings 3", "Chronicles")
    ]
    private static let words: NSRegularExpression = {
        let names = titles.map { NSRegularExpression.escapedPattern(for: $0.0) }
        // Paths, links and filenames keep their functional spelling.
        return try! NSRegularExpression(pattern:
            #"(?:https?://|www\.)[^\s]+|(?<![\w/.])(?:"#
                + (names + ["Lemmings?"]).joined(separator: "|")
                + #")(?![\w/]|\.[A-Za-z])"#, options: [.caseInsensitive])
    }()

    public static func display(_ source: String, usesLemmixNames: Bool = usesLemmixNames) -> String {
        guard usesLemmixNames, source.range(of: "lemming", options: .caseInsensitive) != nil else { return source }
        let original = source as NSString
        var result = source
        for match in words.matches(in: source, range: NSRange(location: 0, length: original.length)).reversed() {
            let word = original.substring(with: match.range)
            guard !word.contains("://"), !word.lowercased().hasPrefix("www.") else { continue }
            let replacement = titles.first { $0.0.caseInsensitiveCompare(word) == .orderedSame }?.1 ?? "Lemmix"
            let value = word == word.uppercased() ? replacement.uppercased() : replacement
            if let range = Range(match.range, in: result) { result.replaceSubrange(range, with: value) }
        }
        return result
    }
}

/// Keeps stored labels intact when restoration changes their displayed names.
@propertyWrapper public struct GameDisplayText: Equatable, Sendable {
    private var source: String
    public init(wrappedValue: String) { source = wrappedValue }
    public var wrappedValue: String {
        get { GamePresentationText.display(source) }
        set { source = newValue }
    }
}

/// Platform shells share translations and product wording without changing engine data.
public enum GameLocalisation {
    public static var availableLanguageIdentifiers: [String] { NxlvKit.L10n.availableLanguageIdentifiers }
    public static var languageOptions: [InterfaceLanguage] { NxlvKit.L10n.languageOptions }
    public static var languageDidChange: Notification.Name { NxlvKit.L10n.languageDidChange }
    public static var currentLanguagePreference: InterfaceLanguage { NxlvKit.L10n.currentLanguagePreference }
    public static var interface: InterfaceLocalisation { NxlvKit.L10n.interface }
    @discardableResult public static func setLanguage(_ choice: InterfaceLanguage,
        systemPreferredLanguages: [String] = Locale.preferredLanguages) -> Bool {
        NxlvKit.L10n.setLanguage(choice, systemPreferredLanguages: systemPreferredLanguages)
    }
    public static func text(_ message: InterfaceMessage) -> String {
        GamePresentationText.display(NxlvKit.L10n.text(message))
    }
    public static func originalL2Text(_ source: String) -> String {
        GamePresentationText.display(NxlvKit.L10n.originalL2Text(source))
    }
    public static func plural(_ key: String, count: Int, one: String, other: String) -> String {
        GamePresentationText.display(NxlvKit.L10n.plural(key, count: count, one: one, other: other))
    }
}

typealias L10n = GameLocalisation
