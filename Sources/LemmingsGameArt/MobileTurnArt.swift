import Foundation
import NxlvKit

/// Keeps the attempt owner visible on pages that cover the gameplay HUD.
public enum MobileTurnArt {
    public enum Role: Equatable, Sendable { case current, next, result }
    public static func subtitle(_ subtitle: String, playerName: String?, role: Role = .current) -> String {
        guard let playerName, !playerName.isEmpty else { return subtitle }
        let caption = role == .result ? L10n.text("Played: \(playerName)") : role == .next ? L10n.text("Next: \(playerName)") : L10n.text("Turn: \(playerName)")
        return subtitle.isEmpty ? caption : caption + "  " + subtitle
    }

    public static func page(_ page: GameFrontEnd.Page, playerName: String?, role: Role = .current, sessionName: String? = nil) -> GameFrontEnd.Page {
        guard let playerName, !playerName.isEmpty,
              GameMenuTypography.menuText(page.title) != GameMenuTypography.menuText(playerName) else { return page }
        var identified = page
        if role == .current, (page.pause != nil || GameMenuTypography.menuText(page.title) == GameMenuTypography.menuText(L10n.text("Paused"))) {
            identified.title = L10n.text("Paused: \(playerName)")
            identified.titleRuns = [.init(L10n.text("Paused: "), .blue), .init(playerName, .green)]
        } else {
            identified.subtitle = subtitle(page.subtitle, playerName: playerName, role: role)
            if page.home, let sessionName, !sessionName.isEmpty {
                identified.subtitle = sessionName + "  " + identified.subtitle
            }
            let prefix = role == .next ? L10n.text("Next: ") : role == .result ? L10n.text("Played: ") : L10n.text("Turn: ")
            identified.subtitleRuns = []
            if page.home, let sessionName {
                identified.subtitleRuns += GameSemanticText.players(sessionName) + [.init("  ", .blue)]
            }
            identified.subtitleRuns += [.init(prefix, .blue), .init(playerName, .green), .init(page.subtitle.isEmpty ? "" : "  " + page.subtitle, .blue)]
        }
        return identified
    }
}
