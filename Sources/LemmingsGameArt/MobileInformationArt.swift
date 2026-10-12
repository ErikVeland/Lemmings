import Foundation

/// The information pages share their bitmap layout with the headless capture tool.
public enum MobileInformationArt {
    public static func effectsWelcome() -> GameFrontEnd.Page {
        .init(title: "Choose your play style", details: ["Modern aiming aids and variable speed", "Original controls and effects"],
              footer: [.init("welcomeOriginal", "Old school"), .init("welcomeModern", "Modern", primary: true)])
    }
    public static func whatsNew(version: String) -> GameFrontEnd.Page {
        .init(title: "What's new in " + version,
              details: ["Classic campaigns and fan packs", "Players, records and achievements",
                        "Playlists and Hot Seat", "Journey and progression playlists",
                        "Rewind and replay review", "Music and controller settings"],
              footer: [.init("welcomeContinue", "Continue", primary: true)])
    }
    public static func telemetryConsent() -> GameFrontEnd.Page {
        .init(title: "Share play counts?", details: ["Daily use, level results and saves",
              "Solo, Hot Seat and soundtrack choices", "No names, IDs, pack names or replays",
              "The service sees your network address", "Change this in Settings > Privacy"],
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
