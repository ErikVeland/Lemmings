import LemmingsAppCore
import NxlvKit

/// Shared phone, tablet and TV selection for the five-level routes.
public enum ShortGamesArt {
    public static func page(available: Set<String>, selected: String = "classic", loading: Bool = false, subtitle: String = "") -> GameFrontEnd.Page {
        let rows = ShortPlayCatalogue.sequences.map { sequence in
            GameFrontEnd.Action("shortSelect." + sequence.id, sequence.title + "  " + sequence.caption,
                enabled: !loading && sequence.supportsCarriedSequence && available.contains(sequence.id),
                selected: sequence.id == selected)
        }
        return .init(title: L10n.text("Short games"), subtitle: loading ? L10n.text("Loading...") : subtitle,
            rows: rows, details: [],
            footer: [.init("collections", L10n.text("Back")),
                .init("shortPlay", L10n.text("Play"), enabled: rows.contains { $0.selected && $0.enabled }, primary: true)])
    }
}
