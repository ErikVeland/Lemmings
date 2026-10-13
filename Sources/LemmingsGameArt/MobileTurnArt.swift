import Foundation

/// Keeps the attempt owner visible on pages that cover the gameplay HUD.
public enum MobileTurnArt {
    public enum Role: Equatable, Sendable { case current, next, result }
    public static func subtitle(_ subtitle: String, playerName: String?, role: Role = .current) -> String {
        guard let playerName, !playerName.isEmpty else { return subtitle }
        let caption = (role == .result ? "Played: " : role == .next ? "Next: " : "Turn: ") + playerName
        return subtitle.isEmpty ? caption : caption + "  " + subtitle
    }

    public static func page(_ page: GameFrontEnd.Page, playerName: String?, role: Role = .current, sessionName: String? = nil) -> GameFrontEnd.Page {
        guard let playerName, !playerName.isEmpty,
              GameMenuTypography.menuText(page.title) != GameMenuTypography.menuText(playerName) else { return page }
        var identified = page
        if role == .current, GameMenuTypography.menuText(page.title) == "PAUSED" {
            identified.title = "Paused: " + playerName
        } else {
            identified.subtitle = subtitle(page.subtitle, playerName: playerName, role: role)
            if page.home, let sessionName, !sessionName.isEmpty {
                identified.subtitle = sessionName + "  " + identified.subtitle
            }
        }
        return identified
    }
}
