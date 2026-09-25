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
  static let audioExtensions: Set<String> = ["wav", "aif", "aiff", "aifc", "mp3", "m4a", "caf", "flac"]

  private var player: MusicFileDeck?
  private(set) var currentURL: URL?
  private var resumeAfterSleep = false
  private var outputSuspended = false
  private(set) var tracks: [URL] = []
  private(set) var volume: Float = 0.8
  private(set) var muted = false
  private(set) var playbackRate: Float = 1
  private var speedPitch: Double = 0

  /// The soundtracks found under a root, one per folder.
  ///
  /// A folder counts only when it holds audio files directly. Module folders
  /// belong to the module player and are left out.
  static func soundtracks(at root: URL) -> [String: [URL]] {
    let manager = FileManager.default
    guard let walker = manager.enumerator(at: root,
      includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [:] }
    var found: [String: [URL]] = [:]
    let sourceOnly = SoundtrackCatalogue.load(at: root)?.sourceOnlyPaths ?? []
    for case let url as URL in walker {
      if url.lastPathComponent == "By Track" { walker.skipDescendants(); continue }
      guard audioExtensions.contains(url.pathExtension.lowercased()),
            (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
      guard let relative = relativePath(url, under: root), !sourceOnly.contains(relative) else { continue }
      let folder = (relative as NSString).deletingLastPathComponent
      found[folder, default: []].append(url)
    }
    return found.mapValues { $0.sorted { $0.path < $1.path } }
  }

  /// The path of a file below a root. The directory enumerator can return
  /// resolved paths for a root reached through a symbolic link, so compare
  /// both sides after resolution.
  static func relativePath(_ url: URL, under root: URL) -> String? {
    let base = root.resolvingSymlinksInPath().path + "/"
    let path = url.resolvingSymlinksInPath().path
    return path.hasPrefix(base) ? String(path.dropFirst(base.count)) : nil
  }

  /// Resolve recordings through composition identity before using legacy aliases.
  static func matches(_ url: URL, trackID: String, root: URL) -> Bool {
    guard let relative = relativePath(url, under: root) else { return false }
    if let entry = SoundtrackCatalogue.load(at: root)?.entry(path: relative) {
      return entry.track.id == trackID && entry.variant.confidence == "documented"
    }
    return LevelMusicSelection.matchesRecording(url.deletingPathExtension().lastPathComponent,
      track: String(trackID.split(separator: ".").last ?? ""))
  }

  /// Some port-exclusive themes have no Amiga module counterpart.
  static func recording(trackID: String, root: URL) -> URL? {
    guard let catalogue = SoundtrackCatalogue.load(at: root) else { return nil }
    let paths = Set((catalogue.track(id: trackID)?.variants ?? []).filter {
      audioExtensions.contains(URL(fileURLWithPath: $0.path).pathExtension.lowercased()) &&
        FileManager.default.isReadableFile(atPath: root.appendingPathComponent($0.path).path)
    }.map(\.path))
    return catalogue.select(trackID: trackID, cycle: 0, availablePaths: paths)
      .map { root.appendingPathComponent($0.path) }
  }

  static func isSeasonal(_ name: String) -> Bool {
    let name = name.lowercased()
    return ["holiday", "xmas", "christmas"].contains { name.contains($0) }
  }

  static func isSeasonal(_ title: ClassicTitle?) -> Bool {
    switch title {
    case .xmasLemmings1991, .xmasLemmings1992, .holidayLemmings1993, .holidayLemmings1994: return true
    default: return false
    }
  }

  static func djSoundtracks(at root: URL, includeOtherSoundtracks: Bool = true, seasonal: Bool = false) -> [String: [URL]] {
    let roots = [root] + (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first.map {
      [$0.appendingPathComponent("Ultimate Lemmings/Soundtracks", isDirectory: true)]
    } ?? [])
    var found: [String: [URL]] = [:]
    for directory in roots {
      guard let walker = FileManager.default.enumerator(at: directory,
        includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { continue }
      let catalogue = SoundtrackCatalogue.load(at: directory)
      let sourceOnly = catalogue?.sourceOnlyPaths ?? []
      for case let url as URL in walker {
        if url.lastPathComponent == "By Track" { walker.skipDescendants(); continue }
        guard audioExtensions.union(["mod"]).contains(url.pathExtension.lowercased()),
              (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
        guard let trackPath = relativePath(url, under: directory), !sourceOnly.contains(trackPath) else { continue }
        let relative = (trackPath as NSString).deletingLastPathComponent
        let classic = relative == "lemmings_music_mod" || relative.hasPrefix("CoLD SToRAGE - Lemmings - the original AMIGA")
        let entry = catalogue?.entry(path: trackPath)
        let isHoliday = entry.map { $0.track.game == "holiday" } ?? isSeasonal(trackPath)
        guard isHoliday == seasonal else { continue }
        let exclusiveSpecial = entry.map { $0.track.role == "special" && !$0.track.variants.contains { $0.quality == "native-module" } } ?? false
        guard seasonal || includeOtherSoundtracks || classic || exclusiveSpecial else { continue }
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
    guard let made = MusicFileDeck(url: url) else { return nil }
    made.volume = muted ? 0 : volume
    made.playbackRate = playbackRate
    made.setSpeedPitch(speedPitch)
    player?.stop()
    player = made
    made.play()
    currentURL = url
    return url.deletingPathExtension().lastPathComponent
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
    player?.suspendOutput()
  }

  func resumeOutput() {
    guard outputSuspended else { return }
    outputSuspended = false
    if resumeAfterSleep { player?.resumeOutput() }
    resumeAfterSleep = false
  }

  func setVolume(_ value: Double) {
    volume = Float(min(1, max(0, value)))
    player?.volume = muted ? 0 : volume
  }

  func setPlaybackRate(_ value: Double) {
    playbackRate = Float(min(1, max(0.5, value)))
    player?.playbackRate = playbackRate
  }

  func setSpeedPitch(_ cents: Double) {
    speedPitch = cents
    player?.setSpeedPitch(cents)
  }

  func setMuted(_ value: Bool) {
    muted = value
    player?.volume = muted ? 0 : volume
  }

  var isPlaying: Bool { player?.isPlaying == true }
}
