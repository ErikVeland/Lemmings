import NxlvKit

/// Shared release copy keeps the invitation and feature scope consistent across platforms.
public enum GameReleaseCopy {
    public static var invitation: String { L10n.text("Pull up a chair. We've got a level to finish.") }
    public static var sections: [(String, String)] { [
        (L10n.text("Desk Clock"), L10n.text("Mac widgets start correctly and fill every size. The clock stays visible in full-colour, tinted and monochrome appearances.")),
        (L10n.text("Pause and resume"), L10n.text("The mobile Pause control responds on touch-down. Resume shows the frozen playfield before the next game tick.")),
        (L10n.text("Your game"), L10n.text("Saved progress and Ready handovers keep their existing safeguards. The Desk Clock does not interrupt a level."))
    ] }
    public static var compatibility: String {
        L10n.text("Classic and The Tribes are Complete. Chronicles and NeoLemmix remain Beta. The mobile Journey is Classic-only.")
    }
}
