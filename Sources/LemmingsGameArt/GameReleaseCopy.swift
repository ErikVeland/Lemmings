import NxlvKit

/// Shared release copy keeps the feature descriptions consistent across platforms.
public enum GameReleaseCopy {
    public static var invitation: String { L10n.text("Pull up a chair. We've got a level to finish.") }
    public static var sections: [(String, String)] { [
        (L10n.text("Home and Play"), L10n.text("Start or resume from Home. Play groups games, saved routes and collections.")),
        (L10n.text("Settings"), L10n.text("Find related controls together and return from a settings page without losing your place.")),
        (L10n.text("Speed and rewind"), L10n.text("Choose a speed directly and use replay controls to revisit moves.")),
        (L10n.text("Music and sound"), L10n.text("Soundtrack variants follow the route as you play."))
    ] }
}
