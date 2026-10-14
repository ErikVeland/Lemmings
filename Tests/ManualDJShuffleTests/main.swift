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
        print("PASS manual same-track/all-track crossfades, current-recording exclusion, mute and suspended-output boundaries")
    }
    static func unwrap<T>(_ value: T?) throws -> T {
        guard let value else { throw Failure.invalid("No current recording") }
        return value
    }
}
