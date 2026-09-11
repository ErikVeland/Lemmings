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
  private(set) var currentURL: URL?
  private var resumeAfterSleep = false
  private var outputSuspended = false
  private(set) var tracks: [URL] = []
  private(set) var volume: Float = 0.8
  private(set) var muted = false

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

  /// Include installed sequel modules and recordings from other ports.
  /// Additional soundtrack folders can live in Application Support.
  static func djSoundtracks(at root: URL, includeOtherSoundtracks: Bool = true) -> [String: [URL]] {
    let roots = [root] + (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first.map {
      [$0.appendingPathComponent("Ultimate Lemmings/Soundtracks", isDirectory: true)]
    } ?? [])
    var found: [String: [URL]] = [:]
    for directory in roots {
      guard let walker = FileManager.default.enumerator(at: directory,
        includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { continue }
      for case let url as URL in walker {
        guard audioExtensions.union(["mod"]).contains(url.pathExtension.lowercased()),
              (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
        let relative = url.deletingLastPathComponent().path.replacingOccurrences(of: directory.path + "/", with: "")
        let classic = relative == "lemmings_music_mod" || relative.hasPrefix("CoLD SToRAGE - Lemmings - the original AMIGA")
        guard includeOtherSoundtracks || classic else { continue }
        found[relative, default: []].append(url)
      }
    }
    return found.mapValues { $0.sorted { $0.path < $1.path } }
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
      // Stop the old player explicitly before releasing it. AVAudioPlayer does
      // not drain its output buffer synchronously on deallocation, so simply
      // replacing `player` can leave both tracks audible at the same time.
      player?.stop()
      player = made
      player?.play()
      currentURL = url
      return url.deletingPathExtension().lastPathComponent
    } catch {
      return nil
    }
  }

  func stop() {
    resumeAfterSleep = false
    outputSuspended = false
    player?.stop()
    player = nil
  }

  func suspendOutput() {
    guard !outputSuspended else { return }
    outputSuspended = true
    resumeAfterSleep = isPlaying
    player?.pause()
  }

  func resumeOutput() {
    guard outputSuspended else { return }
    outputSuspended = false
    if resumeAfterSleep { player?.play() }
    resumeAfterSleep = false
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
