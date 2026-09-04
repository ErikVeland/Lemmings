import AVFoundation
import AppKit
import NxlvKit

/// Plays a soundtrack made of ordinary audio files.
///
/// The module player reproduces the Amiga hardware, note for note. This plays
/// recordings instead: a rip of the Amiga audio, a console version, or a
/// remix. Each folder of audio files is one soundtrack, so a player can keep
/// several and choose between them.
///
/// The player supplies the files. Nothing here ships with the app.
@MainActor final class SoundtrackPlayer {
  /// Extensions the system decoder reads without extra work.
  static let audioExtensions: Set<String> = ["wav", "aif", "aiff", "mp3", "m4a", "caf", "flac"]

  private var player: AVAudioPlayer?
  private(set) var tracks: [URL] = []
  private var volume: Float = 0.8
  private var muted = false

  /// The soundtracks found under a root, one per folder.
  ///
  /// A folder counts only when it holds audio files directly. Module folders
  /// belong to the module player and are left out.
  static func soundtracks(at root: URL) -> [String: [URL]] {
    let manager = FileManager.default
    guard let entries = try? manager.contentsOfDirectory(
      at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
    else { return [:] }

    var found: [String: [URL]] = [:]
    for entry in entries {
      let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory
      guard isDirectory == true else { continue }
      guard let files = try? manager.contentsOfDirectory(
        at: entry, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
      else { continue }
      let audio = files
        .filter { audioExtensions.contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
      if !audio.isEmpty { found[entry.lastPathComponent] = audio }
    }
    return found
  }

  func load(_ urls: [URL]) {
    stop()
    tracks = urls
  }

  /// Plays a track, wrapping around, and returns its name for the status line.
  @discardableResult
  func play(index: Int) -> String? {
    guard !tracks.isEmpty else { return nil }
    let url = tracks[((index % tracks.count) + tracks.count) % tracks.count]
    do {
      let made = try AVAudioPlayer(contentsOf: url)
      // A level outlasts a track, so the track repeats, as the module did.
      made.numberOfLoops = -1
      made.volume = muted ? 0 : volume
      made.prepareToPlay()
      made.play()
      player = made
      return url.deletingPathExtension().lastPathComponent
    } catch {
      return nil
    }
  }

  func stop() {
    player?.stop()
    player = nil
  }

  func setVolume(_ value: Double) {
    volume = Float(min(1, max(0, value)))
    player?.volume = muted ? 0 : volume
  }

  func setMuted(_ value: Bool) {
    muted = value
    player?.volume = muted ? 0 : volume
  }

  var isPlaying: Bool { player?.isPlaying == true }
}
