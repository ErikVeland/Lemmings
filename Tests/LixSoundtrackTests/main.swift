import Foundation
import NxlvKit

@MainActor final class FakeLixPlayer: LixSoundtrackPlaying {
  var stopped = 0
  var loaded: [String: [URL]] = [:]
  var root: URL?
  var trackID: String?
  func stop() { stopped += 1 }
  func load(soundtracks: [String: [URL]], catalogueRoot: URL?) {
    loaded = soundtracks
    root = catalogueRoot
  }
  func startJourney(trackID: String, cycle: Int, identity: String,
    fallback: URL?, includeAlternates: Bool) -> Bool {
    precondition(cycle == 0 && fallback == nil && !includeAlternates)
    self.trackID = trackID
    return true
  }
}

@main struct LixSoundtrackTests {
  @MainActor static func main() throws {
    let resources = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let root = resources.appendingPathComponent("Music")
    precondition(LixSoundtrack.isSelected(.remix(name: "Lix"), storeEdition: false))
    precondition(LixSoundtrack.isSelected(.adaptiveDJ, storeEdition: true))
    precondition(!LixSoundtrack.isSelected(.adaptiveDJ, storeEdition: true, gameMusicAvailable: true))
    precondition(!LixSoundtrack.isSelected(.adaptiveDJ, storeEdition: false))
    precondition(!LixSoundtrack.isSelected(.amigaModules, storeEdition: true))
    precondition(!LixSoundtrack.isSelected(.silent, storeEdition: true))
    let level = LixSoundtrack.selection(roots: [root], position: 0, menu: false)!
    let menu = LixSoundtrack.selection(roots: [root], position: 0, menu: true)!
    precondition(level.trackID == "lix.assembly-line" && menu.trackID == "lix.menulix")
    precondition(LixSoundtrack.selection(roots: [root], position: 0, menu: false,
      readable: { _ in false }) == nil)
    let empty = try SoundtrackCatalogue(data: Data("{\"schemaVersion\":1,\"tracks\":[]}".utf8))
    precondition(LixSoundtrack.selection(roots: [root], position: 0, menu: false,
      catalogue: { _ in empty }) == nil)
    let player = FakeLixPlayer()
    precondition(LixSoundtrack.start(player: player, resources: resources, position: 1,
      identity: "sequel-with-no-original-music"))
    precondition(player.stopped == 1 && player.loaded["Lix"]?.count == 6)
    precondition(player.trackID == "lix.beach-and-sailboats")
    precondition(!LixSoundtrack.start(player: player, resources: nil, position: 0, identity: "missing"))
    precondition(player.stopped == 2)
    print("PASS Lix soundtrack selection, role boundaries, missing media and injected sequel player. No audio played.")
  }
}
