import CoreGraphics
import Foundation
import LemmingsAppCore
import NxlvKit

public enum MobileAboutArt {
    public enum Section: String, CaseIterable, Sendable {
        case overview, history, contributors

        public var title: String {
            switch self {
            case .overview: L10n.text("About")
            case .history: L10n.text("Version history")
            case .contributors: L10n.text("Contributors")
            }
        }
    }

    public static var action: GameFrontEnd.Action { .init("about", L10n.text("About")) }

    public static func page(productName: String, version: String?, build: String?, showsLixCredits: Bool,
                            content: AboutContent = .init(), section: Section = .overview,
                            selectedRelease: Int? = nil, contributors: String? = nil,
                            contributorStatus: String? = nil, allowsContributorRetry: Bool = false,
                            showsSupportAction: Bool = false, showsTipAction: Bool = false) -> GameFrontEnd.Page {
        let version = version ?? L10n.text("Unknown"), build = build ?? L10n.text("Unknown")
        var page = GameFrontEnd.Page(title: L10n.text("About \(productName)"),
            subtitle: L10n.text("Version \(version) - Build \(build)"),
            footer: [.init("aboutBack", L10n.text("Back"), backNavigation: true)])
        page.reading = true
        page.settingsTabs = Section.allCases.map {
            .init("aboutSection." + $0.rawValue, $0.title, selected: $0 == section)
        }
        switch section {
        case .overview:
            if let heritage = content.heritage {
                append(markdown: heritage, to: &page)
            } else {
                let fallback = fallbackOverview()
                page.details = fallback.details
                page.detailHeadings = fallback.headings
            }
            if showsLixCredits {
                appendSection(L10n.text("Lix artwork"), paragraphs: [
                    L10n.text("Selected Lix artwork and music use the CC0 dedication."),
                    "Simon Naarmann, Matt C., geoo, Proxima, Amanda (NaOH), Raymanni"
                ], to: &page)
                appendSection(L10n.text("Soundtrack"), paragraphs: [
                    "Menu Lix · Mike Spanner (Rubix) · CC0 1.0",
                    "Assembly Line, Beach and Sailboats, Driving, Foggy Streets at Night, Meadow Sunrise · Minim and mobius · CC0 1.0",
                    "Earthen Energy, Winter · Mike Spanner (Rubix) · CC BY 4.0"
                ], to: &page)
            }
            appendSection(L10n.text("Community"), paragraphs: [
                L10n.text("NeoLemmix Introduction Pack: \("IchoTolot")"),
                L10n.text("Thanks to the community for fan levels, styles, replays, soundtrack work and preservation research."),
                L10n.text("This is an unofficial project. Original games, artwork and music remain with their respective rights holders.")
            ], to: &page)
        case .history:
            let markdown = content.versionHistory ?? L10n.text("Version history unavailable.")
            let releases = AboutContent.releases(markdown: markdown)
            if let selectedRelease, releases.indices.contains(selectedRelease) {
                append(markdown: releases[selectedRelease].markdown, to: &page)
                page.footer = [.init("aboutHistoryBack", L10n.text("Back"), backNavigation: true)]
            } else if releases.isEmpty {
                append(markdown: markdown, to: &page)
            } else {
                page.rows = releases.enumerated().map { index, release in
                    .init("aboutRelease.\(index)", release.indexTitle)
                }
                page.singleColumnRows = true
            }
        case .contributors:
            append(markdown: contributors ?? content.contributors ?? L10n.text("No contributors listed yet."), to: &page)
            if let contributorStatus {
                page.subtitle += "\n" + contributorStatus
            }
            if allowsContributorRetry {
                page.rows = [.init("aboutRetry", L10n.text("Retry"))]
            }
        }
        page.footer.append(.init("aboutForums", "Lemmings Forums"))
        if showsTipAction {
            page.footer.append(DeveloperTipArt.action)
        } else if showsSupportAction {
            page.footer.append(.init("donate", L10n.text("Buy me a coffee")))
        }
        return page
    }

    public static var forumsPage: GameFrontEnd.Page {
        var page = GameFrontEnd.Page(title: "Lemmings Forums", details: ["lemmingsforums.net"],
            footer: [.init("aboutForumsBack", L10n.text("Back"), backNavigation: true)], preview: true)
        page.previewFitsImage = true
        return page
    }

    public static let forumsQRCode = GameSupport.qrCode(for: AboutContent.forumsURL)

    private static func append(markdown: String, to page: inout GameFrontEnd.Page) {
        for paragraph in AboutContent.paragraphs(markdown: markdown) {
            if paragraph.heading { page.detailHeadings.insert(page.details.count) }
            if paragraph.title { page.detailTitles.insert(page.details.count) }
            page.details.append((paragraph.bullet ? "- " : "") + paragraph.text)
        }
    }

    private static func appendSection(_ title: String, paragraphs: [String], to page: inout GameFrontEnd.Page) {
        page.detailHeadings.insert(page.details.count)
        page.details.append(title)
        page.details.append(contentsOf: paragraphs)
    }

    private static func fallbackOverview() -> (details: [String], headings: Set<Int>) {
        var details = [L10n.text("Developed by Erik Veland.")]
        var headings: Set<Int> = []
        func section(_ title: String, _ paragraphs: [String]) {
            headings.insert(details.count)
            details.append(title)
            details.append(contentsOf: paragraphs)
        }
        section(L10n.text("Original game heritage"), [
            L10n.text("DMA Design created “Lemmings”. Psygnosis published it."),
            L10n.text("Dave Jones programmed the original Amiga game. Gary Timmons animated it, Scott Johnston drew the graphics, and Brian Johnston and Tim Wright wrote the music."),
            L10n.text("Presage, Inc. made the Macintosh port. Tony Williams arranged the DOS music.")
        ])
        return (details, headings)
    }
}
