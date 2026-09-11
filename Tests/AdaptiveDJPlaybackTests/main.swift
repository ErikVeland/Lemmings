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
  player.start()
  try require(player.isPlaying, "the mix did not start")
  let opening = player.currentTrackName
  try require(!opening.isEmpty, "the mix started without naming a track")
  print("  opened on: \(opening)")

  // A quiet level must not move the music.
  let quiet = Telemetry(
    releasedCount: 10, totalCount: 10, savedCount: 0, requiredCount: 5,
    releaseRate: 50, dangerCount: 0, remainingSeconds: 300)
  for _ in 0..<60 { player.updateTelemetry(quiet) }
  try require(
    player.currentTrackName == opening,
    "a quiet level moved the mix to \(player.currentTrackName)")

  // The rescue target is the cue this design exists for.
  var rescued = quiet
  rescued.savedCount = 5
  player.updateTelemetry(rescued)
  try require(
    player.currentTrackName != opening,
    "the rescue target did not move the mix off \(opening)")
  print("  rescue target moved to: \(player.currentTrackName)")

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

  player.stop()
  try require(!player.isPlaying, "the mix kept playing after stop")
  print("PASS the mix starts, moves on the rescue target, moves only once, and start() cannot disturb a suspended crossfade")
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let arguments = CommandLine.arguments
let root = URL(
  fileURLWithPath: arguments.count > 1
    ? arguments[1] : ".build/local/Lemmings Local.app/Contents/Resources/Music")

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
