import Foundation

/// Chooses the main menu theme once for each launch.
///
/// Most launches play the Amiga intro. A small share plays a title theme from
/// another port, including Macintosh, so the menu sometimes sounds like a different machine.
public enum MenuThemeSelection {
    public enum Choice: Equatable, Sendable {
        /// `lemmings_music_mod/intro.mod`.
        case amigaIntro
        /// `MacMusic/classic/lemming1.m4a`, bundled only in the Mac app.
        case macintoshLemming1
        /// A recording path relative to the `Music` catalogue root.
        case recording(String)
    }

    /// One launch in eight plays another port's title theme.
    public static let otherVersionChance = 0.125

    /// Documented Classic title themes other than the Amiga module.
    public static func otherVersions(in catalogue: SoundtrackCatalogue, isAvailable: (String) -> Bool) -> [String] {
        catalogue.tracks.filter { $0.game == "classic" && $0.role == "menu" }
            .flatMap(\.variants)
            .filter { $0.quality != "native-module" && $0.confidence == "documented" && isAvailable($0.path) }
            .map(\.path).sorted()
    }

    /// Other versions installed below a `Music` root.
    public static func otherVersions(at musicRoot: URL) -> [String] {
        guard let catalogue = SoundtrackCatalogue.load(at: musicRoot) else { return [] }
        return otherVersions(in: catalogue) {
            FileManager.default.isReadableFile(atPath: musicRoot.appendingPathComponent($0).path)
        }
    }

    public static func choose<G: RandomNumberGenerator>(macintoshAvailable: Bool, otherVersions: [String],
                                                        using generator: inout G) -> Choice {
        let alternatives = otherVersions.map(Choice.recording)
            + (macintoshAvailable ? [.macintoshLemming1] : [])
        if !alternatives.isEmpty,
           Double.random(in: 0..<1, using: &generator) < otherVersionChance,
           let other = alternatives.randomElement(using: &generator) {
            return other
        }
        return .amigaIntro
    }

    public static func choose(macintoshAvailable: Bool, otherVersions: [String]) -> Choice {
        var generator = SystemRandomNumberGenerator()
        return choose(macintoshAvailable: macintoshAvailable, otherVersions: otherVersions, using: &generator)
    }
}
