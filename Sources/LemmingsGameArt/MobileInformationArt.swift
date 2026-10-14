import Foundation

/// The information pages share their bitmap layout with the headless capture tool.
public enum MobileInformationArt {
    public static func effectsWelcome() -> GameFrontEnd.Page {
        var page = GameFrontEnd.Page(title: "Choose your play style", details: ["Modern", "Aiming aids", "Variable speed",
                                                        "Old school", "Original inputs", "Classic effects"],
              footer: [.init("welcomeOriginal", "Old school"), .init("welcomeModern", "Modern", primary: true)])
        page.detailHeadings = [0, 3]
        return page
    }
    public static func whatsNew(version: String) -> GameFrontEnd.Page {
        .init(title: "What's new in " + version,
              details: ["Classic + fans", "Hot Seat player HUD", "Bomb countdowns", "Smooth music loops",
                        "Rewind scratch", "Portrait controls", "Pointer targeting", "Shared saves/replays"],
              footer: [.init("welcomeContinue", "Continue", primary: true)])
    }
    public static func telemetryConsent() -> GameFrontEnd.Page {
        .init(title: "Share play counts?", details: ["Daily use", "Level results", "Saved lemmings",
              "Solo / Hot Seat", "Soundtrack use", "No names or IDs", "No pack names", "No replays", "Service sees IP"],
              footer: [.init("telemetryNo", "Not now"), .init("telemetryYes", "Share counts", primary: true)])
    }
    public static func insights(counts: [String: Int], shared: Bool, days: Int,
                                sharingAvailable: Bool, loading: Bool = false, notice: String = "") -> GameFrontEnd.Page {
        let names = [("starts", "Level starts"), ("wins", "Wins"), ("fails", "Fails"),
                     ("abandoned", "Unfinished"), ("saved", "Lemmings saved"),
                     ("solo", "Solo starts"), ("hotSeat", "Hot Seat starts"),
                     ("music", "All music chosen"), ("downloads", "Music downloaded")]
        return .init(title: "Play Insights", subtitle: !notice.isEmpty ? notice : loading ? "Loading..." :
            shared ? "Shared: \(days) days" : "This device", rows: names.map { key, title in
                .init("count." + key, "\(title): \(counts[key, default: 0])", enabled: false)
            }, footer: [.init("insightsLocal", "This device", selected: !shared),
                     .init("insightsDays", "Last \(days) days", enabled: sharingAvailable),
                     .init("insightsShared", "Load shared", enabled: sharingAvailable && !loading),
                     .init("insightsClear", "Clear local counts"), .init("settingsGroup.privacy", "Back")])
    }
    public static func insightsToken(length: Int) -> GameFrontEnd.Page {
        .init(title: "Shared play counts", rows: [.init("insightsTokenEdit", "Access token: " +
            String(repeating: "*", count: min(16, max(0, length))))],
              footer: [.init("playInsights", "Cancel"), .init("insightsLoad", "Load", enabled: length > 0, primary: true)])
    }
    public static func insightsClear() -> GameFrontEnd.Page {
        .init(title: "Clear this device's counts?", footer: [.init("playInsights", "Cancel", primary: true),
                                                             .init("insightsClearConfirm", "Clear counts")])
    }
}
