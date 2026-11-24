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

    /// Home destinations after Continue. Settings stays in the footer.
    public static let destinationIDs = ["play", "hotSeat", "profile", "worldwide"]

    /// Home answers "what next?": one Continue action, then four destinations.
    /// Games, saved routes and collections live on Play.
    public static func page(continueAction: GameFrontEnd.Action?, hotSeatTurn: String? = nil,
                            initials: String, nextPlayerIndex: Int? = nil,
                            subtitle: String = "") -> GameFrontEnd.Page {
        var rows: [GameFrontEnd.Action] = []
        if var action = continueAction {
            action.title = lineBreakProgress(action.title)
            action.titleRuns = GameSemanticText.resume(action.title)
            rows.append(action)
        }
        rows += [.init("play", L10n.text("Play")),
                 .init("hotSeat", hotSeatTurn.map { L10n.text("Hot Seat: \($0)") } ?? L10n.text("Hot Seat")),
                 .init("profile", L10n.text("Profile")),
                 .init("worldwide", L10n.text("Community"))]
        if let primary = rows.firstIndex(where: \.enabled) {
            for row in rows.indices { rows[row].primary = row == primary }
        }
        var page = GameFrontEnd.Page(title: L10n.text("Lemmings"), subtitle: subtitle, home: true, rows: rows,
            footer: [.init("settings", L10n.text("Settings"))], homeInitials: initials)
        page.homeNextPlayerIndex = nextPlayerIndex
        return page
    }

    /// Builds the current Home from route rows, as render audits and tests describe a session.
    /// Continue is `continueID` when present, otherwise the first enabled Journey or resume row.
    /// Game rows belong to Play, so `families` does not appear on Home.
    public static func page(resume: [GameFrontEnd.Action] = [], journey: GameFrontEnd.Action?,
                            families: [GameFrontEnd.Action] = [], continueID: String? = nil,
                            initials: String, nextPlayerIndex: Int? = nil,
                            subtitle: String = "", hotSeatTurn: String? = nil) -> GameFrontEnd.Page {
        let routes = [journey].compactMap { $0 } + resume
        let chosen = continueID.flatMap { id in routes.first { $0.id == id && $0.enabled } }
            ?? routes.first(where: \.enabled)
        return page(continueAction: chosen, hotSeatTurn: hotSeatTurn, initials: initials,
                    nextPlayerIndex: nextPlayerIndex, subtitle: subtitle)
    }

    /// Play holds every way into a level: the Journey, other saved routes, the games and collections.
    public static func playPage(journey: GameFrontEnd.Action?, resume: [GameFrontEnd.Action] = [],
                                families: [GameFrontEnd.Action], collectionsAvailable: Bool = true,
                                subtitle: String = "") -> GameFrontEnd.Page {
        let continuations = [journey].compactMap { $0 } + resume
        var rows = continuations + families
        for index in rows.indices {
            rows[index].title = lineBreakProgress(rows[index].title)
            rows[index].titleRuns = index < continuations.count ? GameSemanticText.resume(rows[index].title)
                : rows[index].gameLogo == nil ? GameSemanticText.title(rows[index].title) : [.init(rows[index].title, .blue)]
            rows[index].primary = false
        }
        if let primary = rows.firstIndex(where: \.enabled) { rows[primary].primary = true }
        var page = GameFrontEnd.Page(title: L10n.text("Play"), subtitle: subtitle, rows: rows,
            footer: [.init("playBack", L10n.text("Back"), backNavigation: true),
                     .init("collections", L10n.text("Collections"), enabled: collectionsAvailable)])
        page.gameLibrary = true
        return page
    }

    private static func lineBreakProgress(_ title: String) -> String {
        title.replacingOccurrences(of: #"[ \t]+(?=\d+/\d+(?:\s|$))"#, with: "\n", options: .regularExpression)
    }
}
