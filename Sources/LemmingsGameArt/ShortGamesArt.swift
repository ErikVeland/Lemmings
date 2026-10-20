import LemmingsAppCore
import NxlvKit

/// Shared phone, tablet and TV selection for the optional campaign openings.
public enum ShortGamesArt {
    public static func page(classicAvailable: Bool, loading: Bool = false, subtitle: String = "") -> GameFrontEnd.Page {
        let rows = ShortPlayCatalogue.sequences.map { sequence in
            GameFrontEnd.Action("shortSelect." + sequence.id, sequence.title + "  " + sequence.caption,
                enabled: sequence.engine == .classic && classicAvailable,
                selected: sequence.engine == .classic)
        }
        return .init(title: L10n.text("Short games"), subtitle: loading ? L10n.text("Loading...") : subtitle,
            rows: rows, details: [L10n.text("Sequel short games are unavailable on this device.")],
            footer: [.init("collections", L10n.text("Back")),
                .init("shortPlay", L10n.text("Play"), enabled: !loading && classicAvailable, primary: true)])
    }
}
