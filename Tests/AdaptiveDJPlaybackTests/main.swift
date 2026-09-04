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
  let soundtracks = SoundtrackPlayer.soundtracks(at: root)
  guard !soundtracks.isEmpty else {
    print("No soundtrack folders installed. Nothing to mix.")
    return
  }
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
    releasedCount: 10, totalCount: 10, savedCount: 0, requiredCount: 1,
    releaseRate: 50, dangerCount: 0, remainingSeconds: 300)
  for _ in 0..<60 { player.updateTelemetry(quiet) }
  try require(
    player.currentTrackName == opening,
    "a quiet level moved the mix to \(player.currentTrackName)")

  // The first lemming home is the cue this design exists for.
  var rescued = quiet
  rescued.savedCount = 1
  player.updateTelemetry(rescued)
  try require(
    player.currentTrackName != opening,
    "the first rescue did not move the mix off \(opening)")
  print("  first rescue moved to: \(player.currentTrackName)")

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
  player.stop()
  try require(!player.isPlaying, "the mix kept playing after stop")
  print("PASS the mix starts, moves on the first rescue, and moves only once")
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
