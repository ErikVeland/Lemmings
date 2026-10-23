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
            identified.titleRuns = GameSemanticText.named(identified.title, name: playerName)
        } else if page.home, let sessionName,
            sessionName.range(of: " v ", options: .caseInsensitive) != nil
                || sessionName.range(of: " vs ", options: .caseInsensitive) != nil {
            if identified.homeInitials.isEmpty { identified.homeInitials = sessionName }
            if identified.homeNextPlayerIndex == nil {
                let names = sessionName.replacingOccurrences(of: " vs ", with: " v ", options: .caseInsensitive)
                    .components(separatedBy: " v ")
                let matches = names.indices.filter { names[$0].caseInsensitiveCompare(playerName) == .orderedSame }
                if matches.count == 1 { identified.homeNextPlayerIndex = matches[0] }
            }
            if !identified.subtitle.hasPrefix("PVP") {
                identified.subtitle = (["PVP", identified.subtitle].filter { !$0.isEmpty }).joined(separator: "  ")
            }
            identified.subtitleRuns = [.init(identified.subtitle, .blue)]
        } else {
            identified.subtitle = subtitle(page.subtitle, playerName: playerName, role: role)
            identified.subtitleRuns = []
            identified.subtitleRuns += GameSemanticText.named(subtitle(page.subtitle, playerName: playerName, role: role), name: playerName)
        }
        return identified
    }
}
