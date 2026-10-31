import NxlvKit

/// Shared release copy keeps the invitation and feature scope consistent across platforms.
public enum GameReleaseCopy {
    public static var invitation: String { L10n.text("Pull up a chair. We've got a level to finish.") }
    public static var sections: [(String, String)] { [
        (L10n.text("Find your way back"), L10n.text("Start or resume your Journey from Home. Earlier saved Hot Seats remain available, and level previews open the selected level.")),
        (L10n.text("Clearer controls"), L10n.text("Joined stone controls bring skills, speed and transport together. A pulsing marker shows a selected lemming's walking direction.")),
        (L10n.text("Rewind and busy scenes"), L10n.text("Classic keeps recent rewind states close. Repeated rewind presses on Apple TV move further back, and scenes use less work while you play.")),
        (L10n.text("Music and sound"), L10n.text("Music transitions and sound effects have been updated for busy play and moving between screens."))
    ] }
    public static var compatibility: String {
        L10n.text("Classic and The Tribes are Complete. Chronicles and NeoLemmix remain Beta. The mobile Journey is Classic-only.")
    }
}
