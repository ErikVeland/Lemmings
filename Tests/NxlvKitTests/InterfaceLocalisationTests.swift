import Foundation
import XCTest
@testable import NxlvKit

final class InterfaceLocalisationTests: XCTestCase {
    private var resources: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/NxlvKit/Resources/Localization.bundle")
    }
    func testEnglishFallbackPreservesCompleteMessagesAndPlayerValues() {
        let language = InterfaceLocalisation(bundle: nil)
        let name = "Zoë {1} %@"
        XCTAssertEqual(language.text("Ready, \(name). \(2) of \(8) saved.\n100%"), "Ready, Zoë {1} %@. 2 of 8 saved.\n100%")
        XCTAssertEqual(language.text("No time limit"), "No time limit")
    }
    func testEveryEnglishCatalogueEntryRoundTrips() throws {
        let bundle = try XCTUnwrap(Bundle(url: resources))
        let table = try XCTUnwrap(NSDictionary(contentsOf: resources.appendingPathComponent("en.lproj/Interface.strings")) as? [String: String])
        XCTAssertGreaterThan(table.count, 2000)
        let language = InterfaceLocalisation(bundle: bundle, preferredLanguages: ["en"])
        for (key, value) in table {
            XCTAssertEqual(value, key)
            XCTAssertEqual(language.text(InterfaceMessage(stringLiteral: key)), key, key)
        }
    }
    func testSystemLanguageMatchingReorderedArgumentsAndMissingTranslations() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("Test.bundle")
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        for locale in ["en", "de"] { try FileManager.default.createDirectory(at: root.appendingPathComponent("\(locale).lproj"), withIntermediateDirectories: true) }
        let metadata: [String: Any] = ["CFBundleIdentifier": "test.localisation.\(UUID().uuidString)", "CFBundleDevelopmentRegion": "en"]
        try PropertyListSerialization.data(fromPropertyList: metadata, format: .xml, options: 0).write(to: root.appendingPathComponent("Info.plist"))
        let translations = ["{0} saved {1}": "{1} gerettet von {0}", "Invalid {0}": "Ungültig {2}", "Start": "  "]
        for (locale, values) in [("en", [String: String]()), ("de", translations)] {
            try PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0).write(to: root.appendingPathComponent("\(locale).lproj/Interface.strings"))
        }
        let language = InterfaceLocalisation(bundle: try XCTUnwrap(Bundle(url: root)), preferredLanguages: ["de-DE", "en"])
        XCTAssertEqual(language.language, "de")
        XCTAssertEqual(language.text("\("ALICE") saved \(12)"), "12 gerettet von ALICE")
        XCTAssertEqual(language.text("Missing translation"), "Missing translation")
        XCTAssertEqual(language.text("Invalid \("value")"), "Invalid value")
        XCTAssertEqual(language.text("Start"), "Start")
    }
    func testNativePluralRulesAndUnsupportedLanguageFallback() throws {
        let language = InterfaceLocalisation(bundle: try XCTUnwrap(Bundle(url: resources)), preferredLanguages: ["zz-ZZ"])
        XCTAssertEqual(language.language, "en")
        for (count, expected) in [(0, "0 levels"), (1, "1 level"), (2, "2 levels"), (120, "120 levels")] {
            XCTAssertEqual(language.plural("count.levels", count: count, one: "%ld level", other: "%ld levels"), expected)
        }
    }
    func testEveryDraftLocaleLoadsItsStringsAndPluralTable() throws {
        let bundle = try XCTUnwrap(Bundle(url: resources))
        let source = try XCTUnwrap(NSDictionary(contentsOf: resources.appendingPathComponent("en.lproj/Interface.strings")) as? [String: String])
        let expected = [
            "es-419": ("Listo", "1 nivel", "2 niveles"),
            "de": ("Bereit", "1 Level", "2 Level"),
            "fr": ("Prêt", "1 niveau", "2 niveaux"),
            "pt-BR": ("Pronto", "1 fase", "2 fases"),
            "it": ("Pronto", "1 livello", "2 livelli"),
            "nl": ("Klaar", "1 level", "2 levels"),
            "nb": ("Klar", "1 brett", "2 brett"),
            "ta": ("தயார்", "1 நிலை", "2 நிலைகள்"),
        ]
        for (locale, values) in expected {
            let language = InterfaceLocalisation(bundle: bundle, preferredLanguages: [locale])
            XCTAssertEqual(language.language, locale)
            XCTAssertEqual(language.text("Ready"), values.0, locale)
            XCTAssertEqual(language.plural("count.levels", count: 1, one: "%ld level", other: "%ld levels"), values.1, locale)
            XCTAssertEqual(language.plural("count.levels", count: 2, one: "%ld level", other: "%ld levels"), values.2, locale)
            let tableURL = resources.appendingPathComponent("\(locale).lproj/Interface.strings")
            let table = try XCTUnwrap(NSDictionary(contentsOf: tableURL) as? [String: String])
            XCTAssertEqual(Set(table.keys), Set(source.keys), locale)
            for (key, value) in table {
                XCTAssertEqual(language.text(InterfaceMessage(stringLiteral: key)), value, "\(locale): \(key)")
            }
        }
    }
    func testTamilRegionalMatchingCountsPlaceholdersAndCompleteFontCoverage() throws {
        let bundle = try XCTUnwrap(Bundle(url: resources))
        let table = try XCTUnwrap(NSDictionary(contentsOf: resources.appendingPathComponent("ta.lproj/Interface.strings")) as? [String: String])
        let plurals = try XCTUnwrap(NSDictionary(contentsOf: resources.appendingPathComponent("ta.lproj/Interface.stringsdict")) as? [String: [String: Any]])
        XCTAssertEqual(plurals.count, 8)
        var pluralTexts: [String] = []
        for preference in ["ta-IN", "ta-LK"] {
            let language = InterfaceLocalisation(bundle: bundle, preferredLanguages: [preference])
            XCTAssertEqual(language.language, "ta")
            let name = "Zoë {1} %@"
            XCTAssertEqual(language.text("Ready, \(name)"), "தயார், \(name)")
            for count in [0, 1, 2, 12000] {
                let suffix = count == 1 ? "நிலை" : "நிலைகள்"
                XCTAssertEqual(language.plural("count.levels", count: count, one: "%ld level", other: "%ld levels"), "\(language.number(count)) \(suffix)")
                for (key, entry) in plurals {
                    let forms = try XCTUnwrap(entry["count"] as? [String: Any])
                    let template = try XCTUnwrap(forms[count == 1 ? "one" : "other"] as? String)
                    let expected = template.replacingOccurrences(of: "%ld", with: language.number(count))
                    XCTAssertEqual(language.plural(key, count: count, one: "%ld item", other: "%ld items"), expected, key)
                    if preference == "ta-IN" { pluralTexts.append(template) }
                }
            }
        }
        var tamilForms: Set<String> = []
        for (key, value) in Array(table) + pluralTexts.map({ ("plural", $0) }) {
            for sequence in BitmapTamilGlyphs.sequences(in: value) {
                let isTamil = sequence.unicodeScalars.contains {
                    (0x0B80...0x0BFF).contains($0.value) || (0x11FC0...0x11FFF).contains($0.value)
                }
                guard isTamil else { continue }
                XCTAssertTrue(BitmapTamilGlyphs.supports(sequence), "Unsupported Tamil form in \(key): \(sequence)")
                tamilForms.insert(sequence)
            }
        }
        XCTAssertGreaterThan(tamilForms.count, 100)
        let help = "Tap a lemming to assign the selected skill. Drag a finger to pan. Pinch to zoom."
        XCTAssertNotEqual(table[help], help)
        XCTAssertNotNil(table["Eligible lemming {0} of {1}. Skill: {2}."])
    }
    func testTextExpansionLeavesInterpolatedDataAndPreferenceIDsIntact() throws {
        let language = InterfaceLocalisation(bundle: nil, expandsText: true)
        XCTAssertEqual(language.text("Ready, \("ALICE")"), "[Reeaady, ALICE]")
        XCTAssertEqual(ClassicExperiencePreset.original.rawValue, "original")
        XCTAssertEqual(Lemmings2Runtime.Skill.bomber.name, "Exploder")
        XCTAssertEqual(ClassicTitle.classicQuest.first?.rank, "Fun")
    }
}
