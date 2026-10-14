import Foundation
import LemmingsAudio
import NxlvKit

@main struct ManualDJShuffleTests {
    enum Failure: Error { case invalid(String) }
    static func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
        if !value() { throw Failure.invalid(message) }
    }
    @MainActor static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("Sources/Music")
        let catalogue = try SoundtrackCatalogue(data: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("Resources/Music/catalogue.json")))
        let player = AdaptiveDJPlayer()
        let pools = SoundtrackPlayer.djSoundtracks(at: root, includeOtherSoundtracks: true)
        player.load(soundtracks: pools, catalogueRoot: root)
        player.setVolume(0)
        let original = root.appendingPathComponent("lemmings_music_mod/cancan.mod")
        try require(player.startLevel(url: original, identity: "manual-shuffle"), "Original did not start")
        try require(player.shuffle(scope: .sameTrack), "Same-track shuffle did not start a mix")
        let alternate = try unwrap(player.currentURL)
        try require(alternate != original && player.isCrossfading, "Shuffle repeated the current recording or cut the mix")
        let path = SoundtrackPlayer.cataloguePath(alternate, root: root) ?? ""
        try require(catalogue.entry(path: path)?.track.id == "classic.cancan", "Same-track shuffle changed composition")
        player.setMuted(true)
        try require(!player.shuffle(scope: .allTracks) && player.currentURL == alternate, "Muted shuffle changed the track")
        player.setMuted(false)
        player.suspendOutput()
        try require(!player.shuffle(scope: .allTracks), "Shuffle bypassed suspended output")
        player.resumeOutput()
        try require(player.shuffle(scope: .allTracks), "All-track shuffle did not retarget the active mix")
        try require(player.currentURL != alternate && player.isCrossfading, "All-track shuffle repeated the recording")
        let destination = player.currentURL
        let deadline = Date().addingTimeInterval(25)
        while player.isCrossfading, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
        try require(!player.isCrossfading && player.currentURL == destination && player.playingDeckCount == 1,
            "The retargeted mix did not settle on one deck")
        player.stop()
        let paths = Set(catalogue.tracks.flatMap(\.variants).map(\.path))
        for game in ["classic.cancan", "lemmings2.medieval", "lemmings3.classic1"] {
            let legacy = AdaptiveDJPlayer()
            legacy.load(soundtracks: pools, catalogueRoot: root)
            legacy.setVolume(0)
            let originalVariant = try unwrap(catalogue.select(trackID: game, cycle: 0, availablePaths: paths))
            let source = root.appendingPathComponent(originalVariant.path)
            try require(legacy.shuffle(from: source, scope: .sameTrack, identity: game, fallbackTrackID: game),
                "Ordinary soundtrack could not enter manual DJ: " + game)
            let selected = try unwrap(legacy.currentURL)
            let selectedPath = SoundtrackPlayer.cataloguePath(selected, root: root) ?? ""
            try require(selected != source && catalogue.entry(path: selectedPath)?.track.id == game,
                "Legacy handoff changed composition or repeated its source: " + game)
            legacy.stop()
        }
        let mainVariants = catalogue.tracks.filter { $0.game != "demo" }.flatMap(\.variants).filter {
            $0.quality == "native-module" && FileManager.default.isReadableFile(atPath: root.appendingPathComponent($0.path).path)
        }
        let mainPools = ["Main": mainVariants.map { root.appendingPathComponent($0.path) }]
        for game in ["classic.cancan", "lemmings2.medieval", "lemmings3.classic1"] {
            let mainPlayer = AdaptiveDJPlayer()
            mainPlayer.load(soundtracks: mainPools, catalogueRoot: root)
            mainPlayer.setVolume(0)
            let originalVariant = try unwrap(catalogue.select(trackID: game, cycle: 0,
                availablePaths: Set(mainVariants.map(\.path))))
            let source = root.appendingPathComponent(originalVariant.path)
            try require(mainPlayer.startLevel(url: source, identity: "main:" + game), "Main-bundle source did not start: " + game)
            try require(mainPlayer.shuffle(scope: .sameTrack), "Default shuffle did nothing with only main-bundle music: " + game)
            let selected = try unwrap(mainPlayer.currentURL)
            let selectedPath = SoundtrackPlayer.cataloguePath(selected, root: root) ?? ""
            try require(selected != source && mainPlayer.isCrossfading && catalogue.entry(path: selectedPath)?.track.id != game,
                "Main-bundle shuffle did not mix into another theme: " + game)
            mainPlayer.stop()
        }
        print("PASS manual same-track/all-track crossfades, current-recording exclusion, mute and suspended-output boundaries")
        print("PASS ordinary-source handoff into manual DJ for Classic, Lemmings 2 and Lemmings 3")
        print("PASS default shuffle changes theme with main-bundle music in Classic, Lemmings 2 and Lemmings 3")
    }
    static func unwrap<T>(_ value: T?) throws -> T {
        guard let value else { throw Failure.invalid("No current recording") }
        return value
    }
}
