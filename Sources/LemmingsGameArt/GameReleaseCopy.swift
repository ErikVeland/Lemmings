import NxlvKit

/// Shared release copy keeps the feature descriptions consistent across platforms.
public enum GameReleaseCopy {
    public static var invitation: String { L10n.text("Pull up a chair. We've got a level to finish.") }
    public static var sections: [(String, String)] { [
        (L10n.text("Game Data"), L10n.text("Import missing game data before opening a level. Downloads can continue in the background on iPhone and iPad.")),
        (L10n.text("Home and Play"), L10n.text("Watch the intro while game files are checked on iPhone and iPad.")),
        (L10n.text("About"), L10n.text("Browse credits, contributors and version history on every platform.")),
        (L10n.text("Haptics"), L10n.text("Feel nukes, bridge warnings and selected impacts on supported devices and controllers."))
    ] }
}
