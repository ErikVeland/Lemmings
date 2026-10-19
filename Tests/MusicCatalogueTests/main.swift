import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let catalogue = try SoundtrackCatalogue(data: Data(contentsOf: root.appendingPathComponent("Resources/Music/catalogue.json")))
let paths = Set(catalogue.tracks.flatMap(\.variants).map(\.path))
require(paths.count == 495, "A source version was omitted or duplicated")
func pick(_ id: String, _ cycle: Int = 0, _ port: String = "amiga") -> SoundtrackCatalogue.Variant? {
    catalogue.select(trackID: id, cycle: cycle, preferredPort: port, availablePaths: paths)
}
for game in ["classic.cancan", "ohno.tune4", "holiday.jb", "lemmings2.medieval", "lemmings3.classic1"] {
    require(pick(game)?.quality == "native-module", "First cycle must use the original module: \(game)")
    require(pick(game, 1) != pick(game), "Later cycle did not expose an alternate: \(game)")
    for cycle in 0..<30 {
        require(pick(game, cycle) == pick(game, cycle), "Retry changed version")
        require(catalogue.entry(path: pick(game, cycle)!.path)?.track.id == game, "Journey changed composition")
    }
    require(catalogue.select(trackID: game, cycle: 10, availablePaths: paths, includeAlternates: false) == pick(game), "Opt-out changed the original")
}
require((0..<4).compactMap { pick("classic.tim2", $0)?.remix }.contains("mandelsoft"),
    "Remixes are unreachable during a normal-length campaign")
require(pick("classic.cancan", 0, "dos-opl2")?.port == "dos-opl2", "Preferred original port ignored")
require(pick("classic.beastii")?.path.hasSuffix("beastII.mod") == true, "Beast II confused with Beast I")
require(catalogue.track(id: "classic.beastii")?.role == "special", "Special track entered ordinary rotation")
require(catalogue.track(id: "classic.intro")?.role == "menu", "Intro entered ordinary rotation")
let original = pick("classic.cancan")!
require(catalogue.result(won: true, currentPath: original.path, availablePaths: paths) == nil, "Win stole another game's ending")
require(catalogue.result(won: false, currentPath: original.path, availablePaths: paths) == nil, "Loss stole Lemmings 3D's failure")
let arcade = pick("classic.cancan", 0, "arcade")!
let cue = catalogue.result(won: true, currentPath: arcade.path, availablePaths: paths)
require(cue?.port == "arcade" && cue?.path.contains("Clear") == true, "Native clear cue missing")
require(catalogue.result(won: true, currentPath: "unknown/path", availablePaths: paths) == nil, "Unknown source guessed a cue")
let fallbackPaths = paths.subtracting([original.path])
require(catalogue.select(trackID: "classic.cancan", cycle: 0, availablePaths: fallbackPaths)?.path != original.path, "Missing file selected")
require(catalogue.select(trackID: "classic.cancan", cycle: 0, availablePaths: []) == nil, "Empty install selected a file")
require(pick("classic.cancan", -1) == pick("classic.cancan"), "Negative cycle unsafe")
for track in catalogue.tracks where track.role == "unverified" {
    require(pick(track.id) == nil, "Unverified identity entered the journey")
}
let ohno4 = catalogue.track(id: "ohno.tune4")!
require(ohno4.title == "Much Joviality", "Amiga/DOS numbering was conflated")
require(ohno4.variants.contains { $0.path.contains("27 Much Joviality") }, "DOS Oh No mapping missing")
let remix12 = catalogue.entry(path: "Remixes/orig_music_mandelsoft/orig_12.m4a")
require(remix12?.track.id == "classic.doggie", "MandelSoft numbering was treated as VGM ordering")
require(remix12?.variant.quality == "lossy-source", "Transcode was promoted to lossless source fidelity")
require(catalogue.track(id: "lemmings2.classic")?.variants.allSatisfy { !["game-boy", "mega-drive"].contains($0.port) } == true,
    "Different tribe compositions were conflated")
for track in catalogue.tracks {
    for variant in track.variants {
        require(FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources/Music/" + variant.path).path), "Missing source: \(variant.path)")
    }
}
print("PASS 495 versions, authentic first cycles, deterministic alternates, same-tune fallback, special roles, port-safe cues and source coverage")

for (path, identity) in [
    ("Lemmings (MP3)/14 Smile if You Love Lemmings.mp3", "classic.lemming3"),
    ("Archimedes/03 - Smile if You Love Lemmings (Archimedes).mp3", "classic.tim2"),
    ("Lemmings (MP3)/15 Keep Your Hair on Mr. Lemming.mp3", "classic.tim7"),
    ("Archimedes/10 - Keep Your Hair On Mr. Lemming (Archimedes).mp3", "classic.lemming3"),
    ("Lemmings-SMS/Lemmings - 11 - Keep Your Hair On Mr Lemming.m4a", "classic.lemming3")
] {
    require(catalogue.entry(path: path)?.track.id == identity, "Collection-specific title confused: \(path)")
}
require(catalogue.track(id: "classic.mariarti")?.role == "special", "Mariarti lost its special role")
require(pick("classic.mariarti")?.port == "archimedes", "Recording-only special unavailable")
for port in ["snes", "master-system"] {
    let theme = pick("classic.cancan", 0, port)!
    require(theme.port == port, "New native port not selectable")
    for won in [true, false] {
        let cue = catalogue.result(won: won, currentPath: theme.path, availablePaths: paths)
        require(cue?.port == port, "New port's result cue was not routed")
        require(catalogue.entry(path: cue!.path)?.track.role == (won ? "victory" : "failure"), "Wrong cue role")
    }
}
require(catalogue.track(id: "classic.master-system-oh-no")?.role == "cue", "Oh No voice was mistaken for a failure song")
require(catalogue.track(id: "classic.snes-intermission")?.role == "intermission", "Intermission entered the level rotation")
require(catalogue.track(id: "classic.snes-staff-roll")?.role == "credits", "Credits entered the level rotation")
print("PASS SNES title collisions, Archimedes special and Master System cues")

for special in ["beasti", "beastii", "awesome", "menace"] {
    let track = catalogue.track(id: "classic." + special)!
    require(track.role == "special" && track.variants.contains { $0.remix == "mandelsoft" }, "Missing named special remix")
    require(pick(track.id)?.quality == "native-module", "Special remix replaced authentic first visit")
}
let paintball = catalogue.tracks.filter { $0.game == "paintball" }
require(paintball.count == 5 && paintball.allSatisfy { $0.role == "bonus" }, "Paintball remixes were assigned to Classic")
require(catalogue.track(id: "classic.march-of-the-greentops")?.variants.count == 1, "Unrecognised remixes merged into March of the Greentops")

require(catalogue.sourceOnlyPaths.contains("Lemmings (MP3)/13 As Long As You Try Your Best.mp3"),
    "Broken MP3 remained a playable variant")
require(catalogue.entry(path: "Lemmings (MP3)/13 As Long As You Try Your Best.m4a")?.track.id == "classic.tim6",
    "Decoder-safe copy lost its composition identity")

// The main menu usually plays Amiga, with Macintosh sharing the rare pool equally.
let menuOthers = MenuThemeSelection.otherVersions(in: catalogue) { paths.contains($0) }
require(!menuOthers.contains("lemmings_music_mod/intro.mod"), "The Amiga intro counted as a rare version")
require(menuOthers.contains("Lemmings_(Arcade)/02 March of the Mods (The Finnjenka Dance).m4a")
    && menuOthers.contains("Lemmings_(NES)/01 Title Screen.m4a"), "Another port's title theme was left out")
require(menuOthers.allSatisfy { catalogue.entry(path: $0).map { $0.track.game == "classic" && $0.track.role == "menu" } == true },
    "A non-menu or sequel track entered the main menu pool")
require(MenuThemeSelection.otherVersions(in: catalogue) { _ in false }.isEmpty, "A missing recording was offered")
struct MenuDice: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
}
var dice = MenuDice(state: 7)
var menuCounts: [String: Int] = [:]
for _ in 0..<8000 {
    let key: String = switch MenuThemeSelection.choose(macintoshAvailable: true, otherVersions: menuOthers, using: &dice) {
    case .amigaIntro: "amiga"
    case .macintoshLemming1: "mac"
    case .recording: "other"
    }
    menuCounts[key, default: 0] += 1
}
let rareCount = (menuCounts["other"] ?? 0) + (menuCounts["mac"] ?? 0)
require((800...1200).contains(rareCount), "Other versions are not rare: \(menuCounts)")
let expectedMacCount = Double(rareCount) / Double(menuOthers.count + 1)
require(abs(Double(menuCounts["mac"] ?? 0) - expectedMacCount) < 60,
    "Macintosh does not share the rare pool equally: \(menuCounts)")
var macOnlyCount = 0
for _ in 0..<8000 {
    if MenuThemeSelection.choose(macintoshAvailable: true, otherVersions: [], using: &dice) == .macintoshLemming1 {
        macOnlyCount += 1
    }
}
require((800...1200).contains(macOnlyCount), "Macintosh must stay rare without other recordings: \(macOnlyCount)")
for _ in 0..<2000 {
    require(MenuThemeSelection.choose(macintoshAvailable: false, otherVersions: menuOthers, using: &dice) != .macintoshLemming1,
        "An unavailable Macintosh bank entered the rare pool")
}
for _ in 0..<200 {
    require(MenuThemeSelection.choose(macintoshAvailable: false, otherVersions: [], using: &dice) == .amigaIntro,
        "Without the Macintosh bank or other versions, the Amiga intro must play")
}
print("PASS main menu theme selection")
