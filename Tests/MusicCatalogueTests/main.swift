import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let catalogue = try SoundtrackCatalogue(data: Data(contentsOf: root.appendingPathComponent("Resources/Music/catalogue.json")))
let paths = Set(catalogue.tracks.flatMap(\.variants).map(\.path))
require(paths.count == 486, "A source version was omitted or duplicated")
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
print("PASS 486 versions, authentic first cycles, deterministic alternates, same-tune fallback, special roles, port-safe cues and source coverage")
