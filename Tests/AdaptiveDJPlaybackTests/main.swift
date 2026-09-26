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

extension MusicFileDeck {
@MainActor fileprivate static func checkSpeedPitchSignal() throws {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent("pitch-tone-\(UUID().uuidString).wav")
  defer { try? FileManager.default.removeItem(at: url) }
  let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
  do {
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    let tone = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
    tone.frameLength = 44100
    for channel in 0..<2 { for frame in 0..<44100 {
      tone.floatChannelData![channel][frame] = Float(sin(Double(frame) * 2 * .pi * 440 / 44100)) * 0.25
    } }
    try file.write(from: tone)
  }
  // Distinct tones prove the pause path removes the full mix and plays only
  // its rhythm asset, rather than filtering or merely turning it down.
  let rhythmURL = FileManager.default.temporaryDirectory.appendingPathComponent("drum-tone-\(UUID().uuidString).wav")
  defer { try? FileManager.default.removeItem(at: rhythmURL) }
  do {
    let file = try AVAudioFile(forWriting: rhythmURL, settings: format.settings)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
    buffer.frameLength = 44100
    for channel in 0..<2 { for frame in 0..<44100 {
      buffer.floatChannelData![channel][frame] = Float(sin(Double(frame) * 2 * .pi * 880 / 44100)) * 0.25
    } }
    try file.write(from: buffer)
  }
  do {
    let deck = MusicFileDeck(url: url, rhythmURL: rhythmURL)!
    deck.reverb.wetDryMix = 0; deck.equaliser.bypass = true
    try deck.engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 1024)
    deck.play()
    RunLoop.current.run(until: Date().addingTimeInterval(0.15))
    deck.suspendOutput(rhythmOnly: true)
    RunLoop.current.run(until: Date().addingTimeInterval(0.12))
    try require(deck.musicLayer.outputVolume == 0 && deck.rhythmLayer.outputVolume == 1,
      "Rhythm pause left the full recording audible")
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
    var samples: [Float] = []
    for _ in 0..<32 {
      let rendered = try deck.engine.renderOffline(1024, to: buffer)
      try require(rendered == .success, "Rhythm did not render")
      samples.append(contentsOf: UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
    }
    let crossings = (8193..<samples.count).filter { samples[$0-1] <= 0 && samples[$0] > 0 }.count
    let hz = Double(crossings) * 44100 / Double(samples.count - 8192)
    try require(abs(hz - 880) < 6, "Pause played the melody instead of the rhythm asset: \(hz) Hz")
    deck.suspendOutput()
    // Sample mid-brake. The turntable brake takes 0.5 seconds.
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    try require(deck.varispeed.rate < 0.8 && deck.sourceMixer.outputVolume < 0.9 && deck.sourceMixer.outputVolume > 0,
      "Vinyl stop did not reduce both speed and gain")
    try require(deck.musicLayer.outputVolume == 0, "Vinyl stop restored a paused melody")
    deck.resumeOutput()
    RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    try require(deck.engine.isRunning && deck.player.isPlaying && deck.varispeed.rate == 1,
      "A cancelled vinyl stop paused resumed output")
    try require(deck.musicLayer.outputVolume == 1 && deck.rhythmLayer.outputVolume == 0 && !deck.rhythmPlayer.isPlaying,
      "Resume retained a second rhythm voice")
    deck.suspendOutput()
    // The engine parks after the 0.5-second brake and its 1.2-second reverb tail.
    RunLoop.current.run(until: Date().addingTimeInterval(1.9))
    try require(!deck.engine.isRunning && !deck.player.isPlaying && deck.sourceMixer.outputVolume == 0,
      "Vinyl stop did not reach silence")
    deck.stop()
  }
  print("PASS isolated recording rhythm, vinyl rate/gain ramp, silence and rapid resume")
  for tier in GameplaySpeed.steps {
    let deck = MusicFileDeck(url: url)!
    let ratio = GameplayMusicPitch.ratio(for: tier)
    deck.setSpeedPitch(1200 * log2(ratio))
    deck.reverb.wetDryMix = 0
    deck.equaliser.bypass = true
    try require(deck.playbackRate == 1 && deck.speedPitch.rate == 1, "Speed pitch altered the music tempo")
    try deck.engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 1024)
    try deck.engine.start()
    deck.player.scheduleFile(deck.file, at: nil)
    deck.player.play()
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
    var samples: [Float] = []
    while samples.count < 32768 {
      let status = try deck.engine.renderOffline(1024, to: buffer)
      try require(status == .success, "Pitch graph failed to render audio")
      samples.append(contentsOf: UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
    }
    // Ignore the processor's initial latency. Measure the actual shifted tone.
    var crossings = 0
    for index in 8193..<samples.count where samples[index - 1] <= 0 && samples[index] > 0 { crossings += 1 }
    let frequency = Double(crossings) * 44100 / Double(samples.count - 8192)
    try require(deck.sourceSeconds > 0, "The recording did not expose its source sample position")
    try require(abs(frequency / 440 - ratio) < 0.012,
      "\(tier)× music rendered at \(frequency) Hz instead of \(440 * ratio) Hz")
    deck.setSpeedPitch(10000)
    try require(deck.speedPitch.pitch <= Float(1200 * log2(1.5)) + 0.001, "Audio graph exceeded the pitch cap")
    deck.setSpeedPitch(0)
    try require(deck.speedPitch.pitch == 0, "Normal speed retained pitch processing")
    deck.stop()
  }
  for rate: Float in [0.5, 1, 1.04] {
    let deck = MusicFileDeck(url: url)!
    deck.playbackRate = rate
    if rate > 1 { deck.setMixTempoRatio(Double(rate)) }
    try deck.engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 1024)
    try deck.engine.start()
    deck.player.scheduleFile(deck.file, at: nil)
    deck.player.play()
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
    for _ in 0..<8 { _ = try deck.engine.renderOffline(1024, to: buffer) }
    let start = deck.sourceSeconds
    var matchedSamples: [Float] = []
    for _ in 0..<16 {
      let status = try deck.engine.renderOffline(1024, to: buffer)
      try require(status == .success, "Tempo graph failed to render")
      matchedSamples.append(contentsOf: UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
    }
    let observedRate = (deck.sourceSeconds - start) * 44100 / (16 * 1024)
    try require(abs(observedRate - Double(rate)) < 0.02, "Source position did not follow the rendered tempo: \(observedRate) vs \(rate)")
    if rate > 1 {
      let crossings = (1..<matchedSamples.count).filter { matchedSamples[$0 - 1] <= 0 && matchedSamples[$0] > 0 }.count
      let hz = Double(crossings) * 44100 / Double(matchedSamples.count)
      try require(abs(hz - 440) < 6, "Tempo matching changed musical pitch: \(hz) Hz")
    }
    deck.stop()
  }
  print("PASS rendered music pitch at every tier, unchanged tempo and hard pitch cap")
  print("PASS recording source position at slow, normal and matched playback rates")
}

}

extension ModuleMusicPlayer {
  fileprivate func checkSpeedPitch(_ cents: Double) throws {
    try require(speedPitch.pitch == Float(cents), "Module missed the speed pitch")
  }
}
extension MusicFileDeck {
  fileprivate var rhythmIsPlayingForTest: Bool { rhythmBuffer != nil && rhythmPlayer.isPlaying }
  fileprivate func checkSpeedPitch(_ cents: Double) throws {
    try require(speedPitch.pitch == Float(cents), "Recording missed the speed pitch")
  }
}
extension DJDeck {
  fileprivate func checkSpeedPitch(_ cents: Double) throws {
    try recording?.checkSpeedPitch(cents)
    try module?.checkSpeedPitch(cents)
  }
}
extension AdaptiveDJPlayer {
  fileprivate func checkTimingRouting(root: URL) throws {
    guard let grid = timingCatalogue?.variants.first(where: { $0.supportsBarMixing && !$0.path.hasSuffix(".mod") }) else {
      throw Failure(description: "No analysed recording grid loaded")
    }
    guard let deck = makeDeck(root.appendingPathComponent(grid.path)) else {
      throw Failure(description: "Analysed recording did not load")
    }
    try require(deck.timing?.variantID == grid.variantID && deck.beatInfo != nil, "Recording beat grid did not reach the DJ deck")
    deck.playbackRate = 1.04
    try require(abs((deck.beatInfo?.bpm ?? 0) - grid.baseBPM! * 1.04) < 0.001, "Tempo match lost the analysed base BPM")
    // Check the actual recording unit, not just the DJ wrapper's requested rate.
    try deck.checkMatchedRate()
    let saved = timingCatalogue
    defer { timingCatalogue = saved }
    var record = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("timing.json"))) as! [String: Any]
    var entries = record["variants"] as! [[String: Any]]
    for index in entries.indices { entries[index]["sourceSHA256"] = String(repeating: "0", count: 64); entries[index].removeValue(forKey: "playbackSHA256") }
    record["variants"] = entries
    timingCatalogue = try MusicTimingCatalogue(data: JSONSerialization.data(withJSONObject: record))
    let stale = makeDeck(root.appendingPathComponent(grid.path))
    try require(stale != nil && stale?.timing == nil, "A changed audio file kept its stale beat grid")
    print("PASS recording grid routing, actual tempo matching and stale-grid rejection")
  }
  fileprivate func checkSpeedPitchRouting(recordingURL: URL) throws {
    let cents = 1200 * log2(GameplayMusicPitch.ratio(for: 10))
    let bpm = deckA?.beatInfo?.bpm
    setSpeedPitch(cents)
    try deckA?.checkSpeedPitch(cents)
    try require(deckA?.beatInfo?.bpm == bpm, "Module pitch altered the tracker clock")
    let incoming = makeDeck(recordingURL)
    try require(incoming != nil, "Incoming recording did not load")
    try incoming?.checkSpeedPitch(cents)
    setSpeedPitch(0)
    try deckA?.checkSpeedPitch(0)
  }
}
extension DJDeck {
  fileprivate func checkMatchedRate() throws {
    try require(abs((recording?.playbackRate ?? 0) - 1.04) < 0.001, "The recording unit clamped an upward tempo match")
  }
}

@MainActor private func run(_ root: URL, signalOnly: Bool) throws {
  try MusicFileDeck.checkSpeedPitchSignal()
  if signalOnly { return }
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
  let oneShot = MusicFileDeck(url: loopURL, repeats: false, rhythmURL: loopURL)!
  oneShot.volume = 0; oneShot.play(); oneShot.suspendOutput(rhythmOnly: true)
  RunLoop.current.run(until: Date().addingTimeInterval(0.4))
  try require(!oneShot.isPlaying && !oneShot.rhythmIsPlayingForTest, "A completed one-shot left its rhythm loop playing")
  oneShot.stop()
  print("PASS one-shot rhythm stops with its cue")
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

  guard let cue = MusicFileDeck(url: loopURL, repeats: false) else { throw Failure(description: "One-shot fixture did not open") }
  cue.volume = 0; cue.play()
  RunLoop.current.run(until: Date().addingTimeInterval(0.5))
  try require(cue.completedLoops == 1 && !cue.isPlaying, "One-shot cue repeated")
  cue.suspendOutput(); cue.resumeOutput()
  RunLoop.current.run(until: Date().addingTimeInterval(0.2))
  try require(cue.completedLoops == 1 && !cue.isPlaying, "Completed cue resumed after handover")
  cue.stop()

  let soundtracks = SoundtrackPlayer.djSoundtracks(at: root)
  guard !soundtracks.isEmpty else {
    throw Failure(description: "No soundtrack folders at \(root.path). Build the app or use --signal-only.")
  }
  try require(soundtracks.keys.contains { $0.contains("lemmings_2") }, "L2 modules missing from DJ")
  try require(soundtracks.keys.contains { $0.contains("lemmings_3") }, "L3 modules missing from DJ")
  let unsafeMP3 = root.appendingPathComponent("Lemmings (MP3)/13 As Long As You Try Your Best.mp3")
  try require(!soundtracks.values.flatMap { $0 }.contains(unsafeMP3), "DJ offered a replaced source MP3")
  try require(!SoundtrackPlayer.soundtracks(at: root).values.flatMap { $0 }.contains(unsafeMP3), "Album offered a replaced source MP3")
  let restricted = SoundtrackPlayer.djSoundtracks(at: root, includeOtherSoundtracks: false)
  try require(!restricted.keys.contains { $0.contains("lemmings_2") || $0.contains("lemmings_3") }, "DJ opt-out did not remove sequels")
  let tracks = soundtracks.values.reduce(0) { $0 + $1.count }
  print("  soundtracks: \(soundtracks.count), tracks: \(tracks)")

  let player = AdaptiveDJPlayer()
  player.load(soundtracks: soundtracks, catalogueRoot: root)
  try require(player.hasTracks, "the player found no tracks to mix")
  try player.checkTimingRouting(root: root)

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
  try player.checkSpeedPitchRouting(recordingURL: loopURL)
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
  player.load(soundtracks: soundtracks, catalogueRoot: root)
  try require(player.currentTrackName == opening, "Danger or library refresh changed level music")

  // The rescue target allows one transition. Completion must not repeat it.
  var rescued = quiet
  rescued.savedCount = 5
  player.updateTelemetry(rescued)
  try require(player.currentURL != assigned, "Quota did not start the next version")
  let celebration = player.currentURL
  rescued.didWin = true; rescued.isComplete = true
  player.updateTelemetry(rescued)
  try require(player.currentURL == celebration, "Completed win repeated the quota transition")
  let nextLevel = root.appendingPathComponent("lemmings_music_mod/doggie.mod")
  player.startLevel(url: nextLevel, identity: "level-two")
  RunLoop.current.run(until: Date().addingTimeInterval(1.2))
  try require(player.currentURL == nextLevel, "Next level did not crossfade to its assigned tune")

  // And it moves once, not on every frame that follows.
  let afterCue = player.currentTrackName
  for saved in 2...4 {
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

  // Suspending silences both decks. Resume replans against the current bar grid.
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
    player.isCrossfading && (1...2).contains(player.playingDeckCount) && player.currentTrackName == crossfadingTrack,
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
  for (trackID, modulePath) in [
    ("lemmings2.medieval", "lemmings_2_music_mod_tsyu/medieval.mod"),
    ("lemmings3.classic1", "lemmings_3_music_mod_tsyu/CLASSIC1.mod")
  ] {
    let fallback = root.appendingPathComponent(modulePath)
    player.startJourney(trackID: trackID, cycle: 0, identity: trackID + ":first", fallback: fallback)
    try require(player.currentURL == fallback, "Sequel did not start authentically")
    player.startJourney(trackID: trackID, cycle: 1, identity: trackID + ":later", fallback: fallback)
    try require(player.currentURL != fallback, "Sequel did not select its alternate version")
    let alternate = player.currentURL
    player.startJourney(trackID: trackID, cycle: 1, identity: trackID + ":retry", fallback: fallback)
    try require(player.currentURL == alternate, "Retry changed sequel arrangement")
    player.stop()
  }
  let mariarti = root.appendingPathComponent("Archimedes/14. Professor Mariarti (Archimedes).mp3")
  try require(SoundtrackPlayer.recording(trackID: "classic.mariarti", root: root) == mariarti,
    "Recording-only special fallback missing")
  player.load(soundtracks: restricted, catalogueRoot: root)
  try require(player.startJourney(trackID: "classic.mariarti", cycle: 0, identity: "mariarti", includeAlternates: false),
    "Special requires a nonexistent Amiga module")
  try require(player.currentURL == mariarti && player.isPlaying, "Special recording did not start")
  player.stop()
  player.load(soundtracks: soundtracks, catalogueRoot: root)
  let sms = root.appendingPathComponent("Lemmings-SMS/Lemmings - 02 - Can-Can (Galop Infernal).m4a")
  player.startLevel(url: sms, identity: "sms-result")
  player.updateTelemetry(.init(didWin: false, isComplete: true))
  try require(player.currentURL == sms, "A failure replaced the track instead of preserving funeral mood")
  player.stop()
  print("PASS assigned tracks, score journeys in all engines, protected cues, retry stability and suspended crossfade")
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let arguments = CommandLine.arguments
let signalOnly = arguments.count == 2 && arguments[1] == "--signal-only"
let root = URL(
  fileURLWithPath: arguments.count > 1
    ? arguments[1] : ".build/local/Ultimate Lemmings.app/Contents/Resources/Music")

do {
  try require(arguments.count <= 2, "Use one Music folder or --signal-only.")
  try require(signalOnly || FileManager.default.fileExists(atPath: root.path),
    "No Music folder at \(root.path). Build the app or use --signal-only.")
  try MainActor.assumeIsolated { try run(root, signalOnly: signalOnly) }
  print(signalOnly ? "Adaptive DJ signal tests passed." : "Adaptive DJ playback tests passed.")
} catch {
  FileHandle.standardError.write(Data("Adaptive DJ playback tests failed: \(error)\n".utf8))
  exit(1)
}
