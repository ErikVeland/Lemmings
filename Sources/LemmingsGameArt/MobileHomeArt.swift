import NxlvKit

/// The Mac home order and action groups, shared with the mobile render audit.
public enum MobileHomeArt {
    public static func page(resume: [GameFrontEnd.Action] = [], journey: GameFrontEnd.Action,
                            families: [GameFrontEnd.Action], initials: String,
                            subtitle: String = "") -> GameFrontEnd.Page {
        var rows = resume + [journey] + families
        if let index = rows.firstIndex(where: { $0.enabled }) {
            for row in rows.indices { rows[row].primary = row == index }
        }
        rows.append(.init("collections", "Collections"))
        return .init(title: "Lemmings", subtitle: subtitle, home: true, rows: rows,
            footer: [.init("players", "Profiles"), .init("records", "Records"), .init("playlists", "Playlists"),
                     .init("settings", "Settings"), .init("whatsNew", "What's New")], homeInitials: initials)
    }
}
