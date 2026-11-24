import NxlvKit

/// The Mac home order and action groups, shared with the mobile render audit.
public enum MobileHomeArt {
    public static func journeyAction(run: LevelSequenceRun?, enabled: Bool = true) -> GameFrontEnd.Action {
        .init("journey", run.map { L10n.text("Resume journey (\($0.currentIndex + 1)/\($0.entries.count))") }
            ?? L10n.text("Start journey"), enabled: enabled)
    }
    public static func journeyMap(completed: Int, enabled: Bool = true) -> GameFrontEnd.Action {
        .init("journey", L10n.text("JOURNEY MAP  \(completed) SOLVED"), enabled: enabled)
    }

    public static func journeyPage(title: String, subtitle: String = "", completed: Int,
        solved: Int, total: Int, revisit: Int, resume: (position: Int, count: Int)?,
        canContinue: Bool) -> GameFrontEnd.Page {
        var footer = [GameFrontEnd.Action("home", L10n.text("Back"))]
        if let resume {
            footer.append(.init("learningResume", L10n.text("Resume  \(resume.position)/\(resume.count)"), primary: true))
        }
        if canContinue {
            footer.append(.init("learningStart", solved == 0 && resume == nil ? L10n.text("Start journey") : L10n.text("Continue journey"), primary: resume == nil))
        } else if resume == nil {
            footer[0].primary = true
        }
        return .init(title: title, subtitle: subtitle, rows: [
            .init("learningBrowse", L10n.text("Choose level"), enabled: resume != nil),
            .init("learningRevisit", L10n.text("Revisit  \(revisit)"), enabled: revisit > 0),
            .init("progression", L10n.text("Progression playlists"))],
            details: [L10n.text("Completed levels \(completed)"), L10n.text("Current route \(solved)/\(total)")],
            footer: footer)
    }

    public static func page(resume: [GameFrontEnd.Action] = [], journey: GameFrontEnd.Action?,
                            families: [GameFrontEnd.Action], continueID: String? = nil,
                            initials: String, nextPlayerIndex: Int? = nil,
                            subtitle: String = "", collectionsAvailable: Bool = true,
                            deskClock: Bool = false) -> GameFrontEnd.Page {
        var continuations = [journey].compactMap { $0 } + resume
        // Continue leads Home. The other resumable rows stay reachable below it.
        if let continueID, let index = continuations.firstIndex(where: { $0.id == continueID && $0.enabled }) {
            continuations.insert(continuations.remove(at: index), at: 0)
        }
        var rows = continuations + families
        for index in rows.indices {
            rows[index].title = rows[index].title.replacingOccurrences(
                of: #"[ \t]+(?=\d+/\d+(?:\s|$))"#, with: "\n", options: .regularExpression)
            rows[index].titleRuns = index < continuations.count ? GameSemanticText.resume(rows[index].title)
                : rows[index].gameLogo == nil ? GameSemanticText.title(rows[index].title) : [.init(rows[index].title, .blue)]
        }
        let primary = continueID.flatMap { id in rows.firstIndex { $0.id == id && $0.enabled } }
            ?? rows.firstIndex(where: \.enabled)
        if let primary {
            for row in rows.indices { rows[row].primary = row == primary }
        }
        var page = GameFrontEnd.Page(title: L10n.text("Lemmings"),
            subtitle: subtitle,
            home: true, rows: rows,
            footer: [.init("players", L10n.text("Players")), .init("records", L10n.text("Progress")),
                     .init("worldwide", L10n.text("Leaderboards")),
                     .init("collections", L10n.text("Collections"), enabled: collectionsAvailable), GameSupport.menuAction]
                + (deskClock ? [GameFrontEnd.Action("deskClock", L10n.text("Desk Clock"))] : [])
                + [.init("settings", L10n.text("Settings")), .init("whatsNew", L10n.text("What's New"))], homeInitials: initials)
        page.homeNextPlayerIndex = nextPlayerIndex
        return page
    }
}
