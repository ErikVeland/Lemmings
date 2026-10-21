import NxlvKit

/// Shared release copy keeps the invitation and feature scope consistent across platforms.
public enum GameReleaseCopy {
    public static var invitation: String { L10n.text("Pull up a chair. We've got a level to finish.") }
    public static var sections: [(String, String)] { [
        (L10n.text("Journey"), L10n.text("One Resume gets you back to your game. Campaign and Journey wins count each level once.")),
        (L10n.text("Your turn"), L10n.text("Your journeys and playlists keep their place. Solo and Hot Seat progress stay separate. Ready waits for you.")),
        (L10n.text("Clearer controls"), L10n.text("Smoother Mac wheel zoom, clearer Bonus skill controls and a fix for Apple TV selection.")),
        (L10n.text("Lemmings lettering"), L10n.text("Refined bitmap lettering and new countdown numerals. Even counting to three got some attention."))
    ] }
    public static var compatibility: String {
        L10n.text("Classic and The Tribes are Complete. Chronicles and NeoLemmix remain Beta. The mobile Journey is Classic-only.")
    }
}
