import AVFoundation
import AppKit
import Foundation
import NxlvKit

// The director decides when the music changes. This checks the other half:
// that the player actually loads audio, starts it, and moves to a different
// track when a cue arrives. It runs against whatever soundtracks are
// installed, so it proves the real files play rather than a fixture.

private struct Failure: Error, CustomStringConvertible {
  let description: String
}

private func require(
  _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
  guard condition() else { throw Failure(description: message()) }
}

private typealias Telemetry = AdaptiveDJEngine.Telemetry

@MainActor private func run(_ root: URL) throws {
  let loopURL = FileManager.default.temporaryDirectory.appendingPathComponent("music-loop-\(UUID().uuidString).wav")
  defer { try? FileManager.default.removeItem(at: loopURL) }
  let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
  do {
    let file = try AVAudioFile(forWriting: loopURL, settings: format.settings)
    let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4410)!
    silence.frameLength = 4410
    for channel in 0..<2 { silence.floatChannelData![channel].initialize(repeating: 0, count: 4410) }
    try file.write(from: silence)
  }
  guard let recording = MusicFileDeck(url: loopURL) else { throw Failure(description: "Streaming fixture did not open") }
  recording.volume = 0; recording.play()
  RunLoop.current.run(until: Date().addingTimeInterval(0.8))
  try require(recording.completedLoops >= 3, "Stream did not queue consecutive loops")
  recording.suspendOutput()
  RunLoop.current.run(until: Date().addingTimeInterval(0.25))
  try require(!recording.isPlaying, "Stream ignored suspension")
  recording.resumeOutput()
  RunLoop.current.run(until: Date().addingTimeInterval(0.25))
  try require(recording.isPlaying, "Stream did not resume")
  recording.stop()
  RunLoop.current.run(until: Date().addingTimeInterval(0.25))
  try require(!recording.isPlaying && recording.completedLoops == 0, "Old streaming callback restarted stopped audio")

  let soundtracks = SoundtrackPlayer.djSoundtracks(at: root)
  guard !soundtracks.isEmpty else {
    print("No soundtrack folders installed. Nothing to mix.")
    return
  }
  try require(soundtracks.keys.contains { $0.contains("lemmings_2") }, "L2 modules missing from DJ")
  try require(soundtracks.keys.contains { $0.contains("lemmings_3") }, "L3 modules missing from DJ")
  let restricted = SoundtrackPlayer.djSoundtracks(at: root, includeOtherSoundtracks: false)
  try require(!restricted.keys.contains { $0.contains("lemmings_2") || $0.contains("lemmings_3") }, "DJ opt-out did not remove sequels")
  let tracks = soundtracks.values.reduce(0) { $0 + $1.count }
  print("  soundtracks: \(soundtracks.count), tracks: \(tracks)")

  let player = AdaptiveDJPlayer()
  player.load(soundtracks: soundtracks)
  try require(player.hasTracks, "the player found no tracks to mix")

  player.setVolume(0)  // The test makes no noise.
  let assigned = root.appendingPathComponent("lemmings_music_mod/cancan.mod")
  let module = try ProTrackerModule(data: Data(contentsOf: assigned))
  var clock = ProTrackerPlayer(module: module)
  try require(clock.secondsUntilNextBeat == 0, "Fresh module did not start on the beat")
  _ = clock.nextSample()
  let before = clock.secondsUntilNextBeat
  for _ in 0..<2205 { _ = clock.nextSample() }
  try require(abs((before - clock.secondsUntilNextBeat) - 0.05) < 0.001,
    "Beat clock did not follow rendered audio time")
  player.startLevel(url: assigned, identity: "level-one")
  try require(player.currentURL == assigned, "Assigned opening track ignored")
  try require(player.isPlaying, "the mix did not start")
  let opening = player.currentTrackName
  try require(!opening.isEmpty, "the mix started without naming a track")
  print("  opened on: \(opening)")

  player.startLevel(url: root.appendingPathComponent("lemmings_music_mod/doggie.mod"), identity: "level-one")
  try require(player.currentURL == assigned, "Repeated level entry replaced the track")

  // A quiet level must not move the music.
  let quiet = Telemetry(
    releasedCount: 10, totalCount: 10, savedCount: 0, requiredCount: 5,
    releaseRate: 50, dangerCount: 0, remainingSeconds: 300)
  for _ in 0..<60 { player.updateTelemetry(quiet) }
  try require(
    player.currentTrackName == opening,
    "a quiet level moved the mix to \(player.currentTrackName)")

  var danger = quiet
  danger.isNuking = true; danger.dangerCount = 100; danger.releaseRate = 99
  for _ in 0..<100 { player.updateTelemetry(danger) }
  player.load(soundtracks: soundtracks)
  try require(player.currentTrackName == opening, "Danger or library refresh changed level music")

  // Meeting the quota must not interrupt a level that is still active.
  var rescued = quiet
  rescued.savedCount = 5
  player.updateTelemetry(rescued)
  try require(player.currentTrackName == opening, "Quota changed active level music")
  rescued.didWin = true; rescued.isComplete = true
  player.updateTelemetry(rescued)
  RunLoop.current.run(until: Date().addingTimeInterval(1.2))
  try require(
    player.currentTrackName != opening,
    "the rescue target did not move the mix off \(opening)")
  print("  completed win moved to: \(player.currentTrackName)")

  // And it moves once, not on every frame that follows.
  let afterCue = player.currentTrackName
  for saved in 2...9 {
    var later = quiet
    later.savedCount = saved
    player.updateTelemetry(later)
  }
  try require(
    player.currentTrackName == afterCue,
    "the mix kept moving after the cue, ending on \(player.currentTrackName)")

  // Both decks run during a crossfade, and the old one is retired after it.
  try require(player.isPlaying, "the mix stopped during the crossfade")
  try require(player.playingDeckCount == 2, "both decks were not audible mid-crossfade")
  let crossfadingTrack = player.currentTrackName

  // Suspending pauses both fading decks without retiring either - resuming
  // should pick the crossfade back up exactly where it left off.
  player.suspendOutput()
  try require(player.playingDeckCount == 0, "suspending output did not pause both fading decks")

  // The game can call start() again for the next level without stopping the
  // DJ first (playMusicForCurrentLevel only stops the other music sources).
  // Calling it here, while suspended, must neither sneak in an audible deck
  // behind the suspension nor maroon the crossfade's other deck so it can
  // resurface later playing alongside a different track.
  player.resetLevel()
  player.start()
  try require(player.playingDeckCount == 0, "start() produced audible output while the mix was suspended")

  player.resumeOutput()
  try require(
    player.isCrossfading && player.playingDeckCount == 2 && player.currentTrackName == crossfadingTrack,
    "resuming did not continue the original crossfade cleanly - a stray start() call left "
      + "\(player.playingDeckCount) deck(s) playing on \"\(player.currentTrackName)\" instead")

  player.suspendOutput()
  player.startLevel(url: assigned, identity: "retry")
  try require(player.playingDeckCount == 0, "New level bypassed suspension")
  player.resumeOutput()
  RunLoop.current.run(until: Date().addingTimeInterval(4.5))
  try require(player.currentURL == assigned && player.playingDeckCount == 1, "Retry did not finish on the assigned single deck")
  player.updateTelemetry(.init(didWin: false, isComplete: true))
  try require(player.currentURL == assigned, "No failure theme should substitute an arbitrary tune")
  player.stop()
  try require(!player.isPlaying, "the mix kept playing after stop")
  print("PASS assigned track, quota stability, completed win, one cue, and suspended crossfade")
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let arguments = CommandLine.arguments
let root = URL(
  fileURLWithPath: arguments.count > 1
    ? arguments[1] : ".build/local/Ultimate Lemmings.app/Contents/Resources/Music")

do {
  guard FileManager.default.fileExists(atPath: root.path) else {
    print("No Music folder at \(root.path). Build the app first.")
    exit(0)
  }
  try MainActor.assumeIsolated { try run(root) }
  print("Adaptive DJ playback tests passed.")
} catch {
  FileHandle.standardError.write(Data("Adaptive DJ playback tests failed: \(error)\n".utf8))
  exit(1)
}
