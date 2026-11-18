import Foundation
import NxlvKit

/**
 * Supplies the small playback boundary used by an independent Lix soundtrack.
 */
@MainActor protocol LixSoundtrackPlaying: AnyObject {
  func stop()
  func load(soundtracks: [String: [URL]], catalogueRoot: URL?)
  @discardableResult func startJourney(trackID: String, cycle: Int, identity: String,
    fallback: URL?, includeAlternates: Bool) -> Bool
}

/**
 * Selects Lix compositions without relabelling them as original game music.
 */
enum LixSoundtrack {
  struct Selection: Sendable {
    let root: URL
    let trackID: String
    let files: [URL]
  }

  static func isSelected(_ source: ClassicMusicSource, storeEdition: Bool,
    gameMusicAvailable: Bool = false) -> Bool {
    source == .remix(name: "Lix") || source == .remix(name: "Traditional Remixes")
      || (storeEdition && source == .adaptiveDJ && !gameMusicAvailable)
  }

  static func selection(roots: [URL], position: Int, menu: Bool, preferRemixes: Bool = false,
    catalogue: (URL) -> SoundtrackCatalogue? = { SoundtrackCatalogue.load(at: $0) },
    readable: (URL) -> Bool = { FileManager.default.isReadableFile(atPath: $0.path) }
  ) -> Selection? {
    for root in roots {
      guard let content = catalogue(root) else { continue }
      if preferRemixes {
        let remixes = content.tracks.filter { track in
          track.variants.contains { $0.confidence == "documented" && $0.path.hasPrefix("Traditional Remixes/") && readable(root.appendingPathComponent($0.path)) }
        }
        if !remixes.isEmpty {
          let files = remixes.flatMap(\.variants).filter { $0.confidence == "documented" && $0.path.hasPrefix("Traditional Remixes/") }
            .map { root.appendingPathComponent($0.path) }.filter(readable)
          return Selection(root: root, trackID: remixes[max(0, position) % remixes.count].id, files: files)
        }
      }
      let tracks = content.tracks.filter {
        $0.game == "lix" && $0.role == (menu ? "menu" : "level")
          && $0.variants.contains { $0.confidence == "documented" && readable(root.appendingPathComponent($0.path)) }
      }
      guard !tracks.isEmpty else { continue }
      let files = content.tracks.filter { $0.game == "lix" }.flatMap(\.variants)
        .filter { $0.confidence == "documented" }
        .map { root.appendingPathComponent($0.path) }.filter(readable)
      return Selection(root: root, trackID: tracks[max(0, position) % tracks.count].id, files: files)
    }
    return nil
  }

  @MainActor @discardableResult
  static func start(player: any LixSoundtrackPlaying, resources: URL?, position: Int,
    identity: String, menu: Bool = false, preferRemixes: Bool = false) -> Bool {
    player.stop()
    guard let resources,
      let selected = selection(roots: [resources.appendingPathComponent("Music"),
        resources.appendingPathComponent("AlternativeAssets/Music")], position: position, menu: menu, preferRemixes: preferRemixes) else { return false }
    player.load(soundtracks: [selected.trackID.hasPrefix("lix.") ? "Lix" : "Traditional Remixes": selected.files], catalogueRoot: selected.root)
    return player.startJourney(trackID: selected.trackID, cycle: 0, identity: identity,
      fallback: nil, includeAlternates: false)
  }
}
