import Foundation
import LemmingsAppCore
import NxlvKit
import LemmingsMobileCore

/// The information pages share their bitmap layout with the headless capture tool.
public enum MobileInformationArt {
    public static func effectsWelcome() -> GameFrontEnd.Page {
        var page = GameFrontEnd.Page(title: L10n.text("Choose presentation"),
              footer: [.init("welcomeOriginal", L10n.text("Original")), .init("welcomeModern", L10n.text("Modern"), primary: true)])
        page.backActionID = "welcomeOriginal"
        return page
    }
    public static func whatsNew(version: String) -> GameFrontEnd.Page {
        var page = GameFrontEnd.Page(title: L10n.text("What's new in \(version)"),
              subtitle: GameReleaseCopy.invitation,
              details: GameReleaseCopy.sections.map { $0.1 } + [GameReleaseCopy.compatibility],
              footer: [.init("welcomeContinue", L10n.text("Continue"), primary: true)])
        page.backActionID = "welcomeContinue"
        page.reading = true
        return page
    }
    public static func whatsNew(build: MobileBuildInfo) -> GameFrontEnd.Page {
        var page = GameFrontEnd.Page(title: L10n.text("What's new in \(build.version)"),
            subtitle: [GameReleaseCopy.invitation, build.label, build.dateLabel].filter { !$0.isEmpty }.joined(separator: "\n"),
            details: (build.changes.isEmpty ? GameReleaseCopy.sections.map { $0.1 }
                   : build.changes.map { L10n.text(InterfaceMessage(stringLiteral: $0)) }),
            footer: [.init("welcomeContinue", L10n.text("Continue"), primary: true)])
        page.backActionID = "welcomeContinue"
        page.reading = true
        return page
    }
    /// Asked after the player has a profile, when the worldwide total means something to them.
    /// States each practical consequence once. The full list stays in Settings > Privacy.
    public static func telemetryConsent(worldwide: String = "") -> GameFrontEnd.Page {
        var page = GameFrontEnd.Page(title: L10n.text("Join the count?"), subtitle: worldwide,
              details: [L10n.text("Your rescues add to the worldwide total."),
                        L10n.text("Your initials, scores and replays can appear on public leaderboards."),
                        L10n.text("Anonymous play counts show which levels need work. The service sees your network address."),
                        L10n.text("Change this later in Settings > Privacy.")],
              footer: [.init("telemetryNo", L10n.text("Not now")), .init("telemetryYes", L10n.text("Join"), primary: true)], footerColumns: 2)
        if !worldwide.isEmpty { page.subtitleSizingText = SavedLemmingsCounter.worldwideText(.max) }
        page.backActionID = "telemetryNo"
        return page
    }
    public static func insights(counts: [String: Int], shared: Bool, days: Int,
                                sharingAvailable: Bool, loading: Bool = false, notice: String = "",
                                backID: String = "settingsGroup.privacy", ownerTools: Bool = false) -> GameFrontEnd.Page {
        let names = [("starts", L10n.text("Level starts")), ("wins", L10n.text("Wins")), ("fails", L10n.text("Fails")),
                     ("abandoned", L10n.text("Unfinished")), ("saved", L10n.text("Lemmings saved")),
                     ("solo", L10n.text("Solo starts")), ("hotSeat", L10n.text("Hot Seat starts")),
                     ("music", L10n.text("All music chosen")), ("downloads", L10n.text("Music downloaded"))]
        let installs = shared ? counts["installs"].map(String.init) ?? "N/A" : "N/A"
        let counts: [GameFrontEnd.Action] = names.map { key, title in
            .init("count." + key, "\(title): \(counts[key, default: 0])", enabled: false) }
        let subtitle = !notice.isEmpty ? notice : loading ? L10n.text("Loading...") :
            shared ? L10n.text("Shared: \(days) days") : L10n.text("This device")
        // Shared counts and the access token are owner tools. Players see this device's counts only.
        guard ownerTools else {
            return .init(title: L10n.text("Play Insights"), subtitle: subtitle, rows: counts,
                footer: [.init("insightsClear", L10n.text("Clear local counts")), .init(backID, L10n.text("Back"))])
        }
        let rows = [GameFrontEnd.Action("count.installs", L10n.text("Opted-in installs (all-time): \(installs)"), enabled: false)]
            + counts
        return .init(title: L10n.text("Play Insights"), subtitle: subtitle, rows: rows,
            footer: [.init("insightsLocal", L10n.text("This device"), selected: !shared),
                     .init("insightsDays", L10n.text("Last \(days) days"), enabled: sharingAvailable),
                     .init("insightsShared", L10n.text("Load shared"), enabled: sharingAvailable && !loading),
                     .init("insightsClear", L10n.text("Clear local counts")), .init(backID, L10n.text("Back"))])
    }
    public static func insightsToken(length: Int) -> GameFrontEnd.Page {
        .init(title: L10n.text("Shared play counts"), rows: [.init("insightsTokenEdit", L10n.text("Access token: \(String(repeating: "*", count: min(16, max(0, length))))"))],
              footer: [.init("playInsights", L10n.text("Cancel")), .init("insightsLoad", L10n.text("Load"), enabled: length > 0, primary: true)])
    }
    public static func insightsClear() -> GameFrontEnd.Page {
        .init(title: L10n.text("Clear this device's counts?"), footer: [.init("playInsights", L10n.text("Cancel"), primary: true),
                                                             .init("insightsClearConfirm", L10n.text("Clear counts"))])
    }
}
