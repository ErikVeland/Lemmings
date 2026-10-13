import Foundation

/// Keeps the attempt owner visible on pages that cover the gameplay HUD.
public enum MobileTurnArt {
    public static func subtitle(_ subtitle: String, playerName: String?) -> String {
        guard let playerName, !playerName.isEmpty else { return subtitle }
        return subtitle.isEmpty ? playerName : playerName + "  " + subtitle
    }

    public static func page(_ page: GameFrontEnd.Page, playerName: String?) -> GameFrontEnd.Page {
        guard let playerName, !playerName.isEmpty,
              GameMenuTypography.menuText(page.title) != GameMenuTypography.menuText(playerName) else { return page }
        var identified = page
        identified.subtitle = subtitle(page.subtitle, playerName: playerName)
        return identified
    }
}
