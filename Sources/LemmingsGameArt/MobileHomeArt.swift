import NxlvKit

/// The Mac home order and action groups, shared with the mobile render audit.
public enum MobileHomeArt {
    public static func page(resume: [GameFrontEnd.Action] = [], journey: GameFrontEnd.Action,
                            families: [GameFrontEnd.Action], initials: String,
                            subtitle: String = "", collectionsAvailable: Bool = true) -> GameFrontEnd.Page {
        var rows = resume + [journey] + families
        for index in rows.indices {
            rows[index].titleRuns = rows[index].gameLogo == nil ? GameSemanticText.title(rows[index].title) : [.init(rows[index].title, .green)]
        }
        if let index = rows.firstIndex(where: { $0.enabled }) {
            for row in rows.indices { rows[row].primary = row == index }
        }
        return .init(title: L10n.text("Lemmings"), subtitle: subtitle, home: true, rows: rows,
            footer: [.init("players", L10n.text("Profiles")), .init("records", L10n.text("Records")),
                     .init("collections", L10n.text("Collections / Playlists"), enabled: collectionsAvailable),
                     .init("settings", L10n.text("Settings")), .init("whatsNew", L10n.text("What's New"))], homeInitials: initials)
    }
}
