import NxlvKit

/// Shared release copy keeps the invitation and feature scope consistent across platforms.
public enum GameReleaseCopy {
    public static var invitation: String { L10n.text("Pull up a chair. We've got a level to finish.") }
    public static var sections: [(String, String)] { [
        (L10n.text("Desk Clock"), L10n.text("Lemmings rebuild the time each minute. Open the clock on iPhone and iPad, or add its widget on iPhone, iPad and Mac.")),
        (L10n.text("Duo"), L10n.text("Clock access and game controls adapt to the available screen regions. A layout change cancels an unfinished gesture.")),
        (L10n.text("Clearer pages"), L10n.text("Reading pages have more room between paragraphs. Mobile settings group choices and show checked states.")),
        (L10n.text("Your game"), L10n.text("Saved progress and Ready handovers keep their existing safeguards. The Desk Clock does not interrupt a level."))
    ] }
    public static var compatibility: String {
        L10n.text("Classic and The Tribes are Complete. Chronicles and NeoLemmix remain Beta. The mobile Journey is Classic-only.")
    }
}
