import NxlvKit

/// Shared release copy keeps the feature descriptions consistent across platforms.
public enum GameReleaseCopy {
    public static var invitation: String { L10n.text("Pull up a chair. We've got a level to finish.") }
    public static var sections: [(String, String)] { [
        (L10n.text("Home and Play"), L10n.text("Open the main menu sooner on iPhone and iPad, and see an intro on longer level loads.")),
        (L10n.text("Progress"), L10n.text("Return to the main menu after a win without losing your place.")),
        (L10n.text("Collections"), L10n.text("Explore starter playlists and resume saved routes.")),
        (L10n.text("Settings"), L10n.text("Choose Catalan or Swiss German. On iPhone and iPad, open About for credits and version details."))
    ] }
}
