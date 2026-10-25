import LemmingsAppCore
import NxlvKit

/// Shared phone, tablet and TV selection for the optional campaign openings.
public enum ShortGamesArt {
    public static func page(classicAvailable: Bool, tribesAvailable: Bool = false, selected: String = "classic", loading: Bool = false, subtitle: String = "") -> GameFrontEnd.Page {
        let rows = ShortPlayCatalogue.sequences.map { sequence in
            GameFrontEnd.Action("shortSelect." + sequence.id, sequence.title + "  " + sequence.caption,
                enabled: sequence.engine == .classic ? classicAvailable : sequence.engine == .lemmings2 && tribesAvailable,
                selected: sequence.id == selected)
        }
        return .init(title: L10n.text("Short games"), subtitle: loading ? L10n.text("Loading...") : subtitle,
            rows: rows, details: [],
            footer: [.init("collections", L10n.text("Back")),
                .init("shortPlay", L10n.text("Play"), enabled: !loading && (selected == "classic" ? classicAvailable : selected == "lemmings2" && tribesAvailable), primary: true)])
    }
}
