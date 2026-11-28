import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import LemmingsAppCore

final class AboutContentTests: XCTestCase {
    func testBundledContentReadsTheInstalledAppsIndependentDocuments() throws {
        let resources = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let about = resources.appendingPathComponent("About", isDirectory: true)
        try FileManager.default.createDirectory(at: about, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: resources) }
        let heritage = "# Original creators\n\nDMA Design\n"
        let history = "# 2.7.5 · Build 128\n\n- Installed release\n"
        let contributors = "# Supporters\n\nFirst supporter\n\nSecond supporter\n"
        for (name, markdown) in [("Heritage.md", heritage), ("VersionHistory.md", history),
                                 ("Contributors.md", contributors)] {
            try markdown.write(to: about.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        let content = AboutContent(resources: resources)
        XCTAssertEqual(content.heritage, heritage)
        XCTAssertEqual(content.versionHistory, history)
        XCTAssertEqual(content.contributors, contributors)
        try FileManager.default.removeItem(at: about.appendingPathComponent("Heritage.md"))
        try " \n\t ".write(to: about.appendingPathComponent("VersionHistory.md"), atomically: true, encoding: .utf8)
        let missing = AboutContent(resources: resources)
        XCTAssertNil(missing.heritage)
        XCTAssertNil(missing.versionHistory)
        XCTAssertEqual(missing.contributors, contributors)
    }

    func testReleaseIndexPreservesOrderAndDistinguishesRepeatedVersions() {
        let markdown = """
        # 2.7.5 · Build 128

        ## Changes

        - Current improvement
          with its continuation.

        # 2.7.5 · Build 127

        - Earlier improvement

        # 2.6 · Build 115

        - Older improvement
        """
        let releases = AboutContent.releases(markdown: markdown)
        XCTAssertEqual(releases.map(\.title), ["2.7.5 · Build 128", "2.7.5 · Build 127", "2.6 · Build 115"])
        XCTAssertEqual(releases.map(\.indexTitle), ["2.7.5 (128)", "2.7.5 (127)", "2.6"])
        XCTAssertTrue(releases[0].markdown.contains("## Changes\n\n- Current improvement\n  with its continuation."))
        XCTAssertFalse(releases[0].markdown.contains("Earlier improvement"))
        XCTAssertTrue(releases[1].markdown.contains("Earlier improvement"))
        XCTAssertTrue(releases[2].markdown.contains("Older improvement"))
    }

    func testProductNamedHistoryAndUnavailableHistoryRemainUsable() {
        let releases = AboutContent.releases(markdown: "# Ultimate Lemmix 2.7.5\n\n## Changes\n\n- Improvement")
        XCTAssertEqual(releases.map(\.indexTitle), ["Ultimate Lemmix 2.7.5"])
        XCTAssertTrue(AboutContent.releases(markdown: "Version history unavailable.").isEmpty)
        XCTAssertTrue(AboutContent.releases(markdown: "").isEmpty)
    }

    func testMarkdownPreservesNamesRolesAndWrappedListItems() {
        let markdown = """
        # Contributors

        ## Supporters

        **First supporter**

        [Second supporter](https://example.com)
        and their published display name.

        - Music: **Brian Johnston**
          and [Tim Wright](https://example.com/music)
        * Animation: Gary Timmons

        Erik Veland 🏳️‍⚧️🇵🇸
        """
        let paragraphs = AboutContent.paragraphs(markdown: markdown)
        XCTAssertEqual(paragraphs.map(\.text), ["Contributors", "Supporters", "First supporter",
            "Second supporter and their published display name.", "Music: Brian Johnston and Tim Wright",
            "Animation: Gary Timmons", "Erik Veland 🏳️‍⚧️🇵🇸"])
        XCTAssertEqual(paragraphs.filter(\.heading).map(\.text), ["Contributors", "Supporters"])
        XCTAssertEqual(paragraphs.filter(\.title).map(\.text), ["Contributors"])
        XCTAssertEqual(paragraphs.filter(\.bullet).map(\.text), ["Music: Brian Johnston and Tim Wright", "Animation: Gary Timmons"])
        XCTAssertTrue(AboutContent.paragraphs(markdown: " \n\n ").isEmpty)
    }

    func testContributorResponseAcceptsUTF8MarkdownInPublishedOrder() throws {
        let markdown = "# Supporters\n\nFirst supporter\n\nSecond supporter 🏳️‍⚧️🇵🇸\n"
        let response = try XCTUnwrap(HTTPURLResponse(url: AboutContent.contributorsURL, statusCode: 200,
            httpVersion: nil, headerFields: ["Content-Type": "text/markdown; charset=utf-8"]))
        XCTAssertEqual(try AboutContent.validatedContributors(data: Data(markdown.utf8), response: response), markdown)
        let limit = String(repeating: "a", count: 65_536)
        XCTAssertEqual(try AboutContent.validatedContributors(data: Data(limit.utf8), response: response), limit)
    }

    func testContributorResponseRejectsFailuresEmptyInvalidOrOversizedContent() throws {
        let secure = try XCTUnwrap(HTTPURLResponse(url: AboutContent.contributorsURL, statusCode: 200,
            httpVersion: nil, headerFields: nil))
        for data in [Data(), Data(" \n\t ".utf8), Data([0xff, 0xfe]), Data(repeating: 97, count: 65_537)] {
            XCTAssertThrowsError(try AboutContent.validatedContributors(data: data, response: secure))
        }
        for (url, status) in [(AboutContent.contributorsURL, 404), (AboutContent.contributorsURL, 500),
                             (URL(string: "http://example.com/contributors.md")!, 200)] {
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status,
                httpVersion: nil, headerFields: nil))
            XCTAssertThrowsError(try AboutContent.validatedContributors(data: Data("# Supporters".utf8), response: response))
        }
    }
}
