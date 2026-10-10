import Foundation
import NxlvKit

func require(_ value: Bool, _ message: String) {
    if !value { print("FAIL: " + message); exit(1) }
}

let hash = String(repeating: "a", count: 64)
var row: [String: Any] = ["variantID": "version", "path": "theme.m4a", "sourceSHA256": hash,
    "sampleRate": 44100.0, "frameCount": 441000, "integratedLUFS": -22.0,
    "truePeakDBTP": -10.0, "gainDB": 2.0, "loopStatus": "verified-vgm",
    "loop": ["startFrame": 44100, "endFrame": 176400, "sourcePath": "theme.vgz", "sourceSHA256": hash]]
func profile(_ rows: [[String: Any]]) throws -> MusicPlaybackCatalogue {
    try MusicPlaybackCatalogue(data: JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "variants": rows]))
}
let entry = try profile([row]).variants[0]
let first = entry.segment(first: true, repeats: true, fileFrames: 441000, fileRate: 44100)
let repeatLoop = entry.segment(first: false, repeats: true, fileFrames: 441000, fileRate: 44100)
require(first.start == 0 && first.count == 176400, "The intro must play once, without the render fade")
require(repeatLoop.start == 44100 && repeatLoop.count == 132300, "Only the exact source loop must repeat")
let cue = entry.segment(first: true, repeats: false, fileFrames: 441000, fileRate: 44100)
require(cue.start == 0 && cue.count == 441000, "A one-shot must retain its full ending")
require(entry.position(at: 3.5, repeats: true) == 3.5 && entry.position(at: 4, repeats: true) == 1
    && entry.position(at: 7.5, repeats: true) == 1.5, "Loop position must follow queued playback segments")
let invalidRate = entry.segment(first: false, repeats: true, fileFrames: 441000, fileRate: 48000)
require(invalidRate.start == 0 && invalidRate.count == 441000, "A changed sample rate inherited source loop frames")
let truncated = entry.segment(first: false, repeats: true, fileFrames: 44100, fileRate: 44100)
require(truncated.start == 0 && truncated.count == 44100, "A truncated file read beyond its frames")
row["gainDB"] = 7.0
require((try? profile([row])) == nil, "Unbounded gain was accepted")
row["gainDB"] = 2.0
require((try? profile([row, row])) == nil, "Duplicate profile paths were accepted")
row["loop"] = ["startFrame": 176400, "endFrame": 44100, "sourcePath": "theme.vgz", "sourceSHA256": hash]
require((try? profile([row])) == nil, "An inverted loop was accepted")
print("PASS exact intro/loop segments, full one-shots, position mapping and profile validation")

func variant(_ id: String, _ quality: String, _ remix: String = "original") -> [String: String] {
    ["id": id, "path": id + ".m4a", "port": "amiga", "quality": quality,
     "remix": remix, "confidence": "documented", "sourcePath": id + ".wav"]
}
let native = variant("native", "native-module"), chip = variant("chip", "chip-render")
var gameBoy = variant("game-boy", "chip-render")
gameBoy["port"] = "game-boy"
let otherRemix = variant("other-remix", "lossy-source", "different-arrangement")
let otherComposer = variant("other-composer", "composer-recording")
let composer = variant("composer", "composer-recording"), remix = variant("remix", "lossy-source", "arrangement")
let result = variant("result", "chip-render")
let catalogue = try SoundtrackCatalogue(data: JSONSerialization.data(withJSONObject: ["schemaVersion": 1,
    "tracks": [["id": "level.theme", "game": "classic", "title": "Theme", "role": "level",
                "variants": [native, chip, gameBoy, composer, otherComposer, remix, otherRemix]],
               ["id": "result.win", "game": "classic", "title": "Win", "role": "victory", "variants": [result]]]]))
let paths = Set(["native.m4a", "chip.m4a", "composer.m4a", "remix.m4a", "result.m4a"])
require(catalogue.celebration(currentPath: "native.m4a", cycle: 0, availablePaths: paths)?.path == "remix.m4a",
    "Rescue quota must prefer an arrangement of the same tune")
require(catalogue.celebration(currentPath: "chip.m4a", cycle: 0,
    availablePaths: paths.subtracting(["remix.m4a"]))?.path == "composer.m4a",
    "An available composer recording must supply the fidelity lift")
require(catalogue.celebration(currentPath: "remix.m4a", cycle: 0, availablePaths: paths) == nil,
    "A joyful arrangement must not fall back to a lesser version")
require(catalogue.celebration(currentPath: "native.m4a", cycle: 0,
    availablePaths: ["native.m4a", "chip.m4a", "game-boy.m4a"]) == nil,
    "An arbitrary recorded port was mistaken for a musical lift")
require(catalogue.celebration(currentPath: "composer.m4a", cycle: 0,
    availablePaths: paths.union(["other-composer.m4a"]).subtracting(["remix.m4a"])) == nil,
    "A composer recording moved sideways or downgraded")
require(catalogue.celebration(currentPath: "composer.m4a", cycle: 0, availablePaths: paths)?.path == "remix.m4a",
    "An explicit remix must lift a composer recording")
require(catalogue.celebration(currentPath: "remix.m4a", cycle: 0,
    availablePaths: paths.union(["other-remix.m4a"])) == nil,
    "An existing remix moved sideways to another arrangement")
require(catalogue.celebration(currentPath: "native.m4a", cycle: 0,
    availablePaths: ["native.m4a", "result.m4a"]) == nil, "A result jingle replaced the level tune")
require(catalogue.celebration(currentPath: "native.m4a", cycle: 0, availablePaths: paths,
    includeAlternates: false) == nil, "Disabled alternates changed the tune")
print("PASS same-composition victory lift, arrangement preference, no downgrade and result-jingle exclusion")

if CommandLine.arguments.count > 1 {
    let profiles = try MusicPlaybackCatalogue(data: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    require(profiles.variants.count == 422, "Recorded catalogue coverage changed")
    print("PASS bundled recorded-music profile decoding")
}
