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
    func testTextExpansionLeavesInterpolatedDataAndPreferenceIDsIntact() throws {
        let language = InterfaceLocalisation(bundle: nil, expandsText: true)
        XCTAssertEqual(language.text("Ready, \("ALICE")"), "[Reeaady, ALICE]")
        XCTAssertEqual(ClassicExperiencePreset.original.rawValue, "original")
        XCTAssertEqual(Lemmings2Runtime.Skill.bomber.name, "Exploder")
        XCTAssertEqual(ClassicTitle.classicQuest.first?.rank, "Fun")
    }
}
