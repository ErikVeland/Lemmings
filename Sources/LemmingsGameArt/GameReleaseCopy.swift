import NxlvKit

/// Shared release copy keeps the invitation and feature scope consistent across platforms.
public enum GameReleaseCopy {
    public static var invitation: String { L10n.text("Pull up a chair. We've got a level to finish.") }
    public static var sections: [(String, String)] { [
        (L10n.text("Desk Clock"), L10n.text("Duo uses more of its display. Tent Pose opens Desk Clock with your game safely paused. Optional red night vision keeps the clock quiet.")),
        (L10n.text("Your game"), L10n.text("Clearer navigation keeps your place. Fan packs are grouped for browsing, and Golden Path wins count in their original collections.")),
        (L10n.text("Controls"), L10n.text("Shared stone artwork and clearer controls improve every platform. Touch selection and replay controls are easier to use."))
    ] }
    public static var compatibility: String {
        L10n.text("Classic and The Tribes are Complete. Chronicles and NeoLemmix remain Beta. The mobile Journey is Classic-only.")
    }
}
