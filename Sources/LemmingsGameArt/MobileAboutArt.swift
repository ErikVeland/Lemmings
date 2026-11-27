import Foundation
import NxlvKit

/// Offline mobile credits. Heritage follows Resources/About/Heritage.md;
/// Lix and community attribution follow the published Website/content/credits.html.
public enum MobileAboutArt {
    public static var action: GameFrontEnd.Action { .init("about", L10n.text("About")) }

    public static func page(productName: String, version: String?, build: String?, showsLixCredits: Bool) -> GameFrontEnd.Page {
        let version = version ?? L10n.text("Unknown"), build = build ?? L10n.text("Unknown")
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
        if showsLixCredits {
            section(L10n.text("Lix artwork"), [
                L10n.text("Selected Lix artwork and music use the CC0 dedication."),
                "Simon Naarmann, Matt C., geoo, Proxima, Amanda (NaOH), Raymanni"
            ])
            section(L10n.text("Soundtrack"), [
                "Menu Lix · Mike Spanner (Rubix) · CC0 1.0",
                "Assembly Line, Beach and Sailboats, Driving, Foggy Streets at Night, Meadow Sunrise · Minim and mobius · CC0 1.0",
                "Earthen Energy, Winter · Mike Spanner (Rubix) · CC BY 4.0"
            ])
        }
        section(L10n.text("Community"), [
            L10n.text("NeoLemmix Introduction Pack: \("IchoTolot")"),
            L10n.text("Thanks to the community for fan levels, styles, replays, soundtrack work and preservation research."),
            L10n.text("This is an unofficial project. Original games, artwork and music remain with their respective rights holders.")
        ])
        var page = GameFrontEnd.Page(title: L10n.text("About \(productName)"),
            subtitle: L10n.text("Version \(version) - Build \(build)"), details: details,
            footer: [.init("aboutBack", L10n.text("Back"), backNavigation: true)])
        page.reading = true
        page.detailHeadings = headings
        return page
    }
}
