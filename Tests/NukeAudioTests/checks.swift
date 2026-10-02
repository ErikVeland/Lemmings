import AVFoundation
import Foundation

extension MusicFileDeck {
  static func nukeEnergy(frequency: Double, amount: Float) throws -> Double {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("nuke-\(UUID().uuidString).wav")
    defer { try? FileManager.default.removeItem(at: url) }
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
    input.frameLength = 44100
    for c in 0..<2 { for i in 0..<44100 {
      input.floatChannelData![c][i] = Float(sin(Double(i) * 2 * .pi * frequency / 44100)) * 0.2
    } }
    do { let file = try AVAudioFile(forWriting: url, settings: format.settings); try file.write(from: input) }
    let deck = MusicFileDeck(url: url)!
    deck.setNukeAmount(1)
    deck.setNukeAmount(amount)
    deck.setMixBass(-9)
    precondition(deck.nukeEQ.bands[0].gain == 3 * amount)
    deck.setMixBass(0)
    deck.reverb.wetDryMix = 0
    deck.sourceMixer.outputVolume = 1
    deck.outputMixer.outputVolume = 1
    try deck.engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
    try deck.engine.start()
    defer { deck.engine.stop() }
    deck.player.scheduleBuffer(input)
    deck.player.play()
    let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
    var energy = 0.0
    for block in 0..<70 {
      let status = try deck.engine.renderOffline(512, to: output)
      precondition(status == .success)
      if block > 20 { for i in 0..<512 { let v = Double(output.floatChannelData![0][i]); energy += v * v } }
    }
    return energy
  }
}
extension SoundEffectPlayer {
  func checkNukeLimits() {
    precondition(Self.nukeBass.first == 0 && abs(Self.nukeBass.last!) < 0.00001)
    precondition(Self.nukeBass.allSatisfy { $0.isFinite && abs($0) < 1.18 })
    setNukeActive(true)
    precondition(voices.filter(\.isActive).count == 1)
    let point = GameplaySoundPoint(x: 10, y: 20)
    for _ in 0..<80 { playNukeImpact(at: point) }
    precondition(voices.filter(\.isActive).count == 2)
    precondition(voices[1].worldPoint == point)
    setNukeActive(false); silence()
    playNukeImpact(at: point)
    precondition(!voices.contains { $0.isActive })
    setMuted(true); setNukeActive(true); playNukeImpact(at: point)
    precondition(!voices.contains { $0.isActive })
  }
}
extension ModuleMusicPlayer {
  func checkNukeRestart() throws {
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
    setNukeAmount(1)
    for _ in 0..<2 {
      try start()
      precondition(nukeEQ.bands.allSatisfy { !$0.bypass })
      precondition(nukeEQ.bands[0].gain == 3 && nukeEQ.globalGain == 0
        && abs(nukeEQ.bands[1].frequency - 450) < 0.01)
      stop()
    }
    setNukeAmount(0)
    precondition(nukeEQ.globalGain == 0 && nukeEQ.bands.allSatisfy { $0.gain == 0 })
  }
}
try ModuleMusicPlayer().checkNukeRestart()
SoundEffectPlayer().checkNukeLimits()
for frequency in [100.0, 800, 8000] {
  let dry = try MusicFileDeck.nukeEnergy(frequency: frequency, amount: 0)
  let filtered = try MusicFileDeck.nukeEnergy(frequency: frequency, amount: 1)
  precondition(dry > 0)
  if frequency == 100 { precondition(filtered > dry * 1.3 && filtered < dry * 2.1) }
  else { precondition(filtered < dry * 0.3) }
  print("PASS nuke EQ at \(frequency) Hz: \(10 * log10(filtered / dry)) dB")
}
var treble: [Double] = []
for amount: Float in [0, 0.25, 0.5, 0.75, 1] {
  treble.append(try MusicFileDeck.nukeEnergy(frequency: 8000, amount: amount))
}
precondition(zip(treble, treble.dropFirst()).allSatisfy { $0 > $1 })
for duration in [75, 79, 84] {
  let sweep = NukeMusicSweep()
  sweep.update(active: true, tick: 100, durationTicks: duration)
  precondition(sweep.amount == 0)
  sweep.update(active: true, tick: 100 + duration / 2, durationTicks: duration)
  let halfway = sweep.amount
  precondition(halfway > 0.45 && halfway <= 0.5)
  sweep.update(active: true, tick: 100 + duration / 2, durationTicks: duration)
  precondition(sweep.amount == halfway) // Paused simulation.
  sweep.update(active: true, tick: 100 + duration, durationTicks: duration)
  precondition(sweep.amount == 1) // Fast-forward lands at the same endpoint.
  sweep.update(active: true, tick: 100 + duration / 2, durationTicks: duration)
  precondition(sweep.amount == halfway) // Rewind follows the countdown.
  sweep.update(active: false, tick: 0, durationTicks: duration)
  precondition(sweep.amount == 0)
  sweep.update(active: true, tick: 800, durationTicks: duration, remainingTicks: duration / 2)
  precondition(sweep.amount >= 0.5 && sweep.amount < 0.55) // Restored countdown.
}
print("PASS progressive treble sweep, retained bass, pause, speed, rewind and restored countdown")
print("PASS nuke bass envelope, spatial origin, mass-explosion limit, reset and mute (offline only)")

for duration in [75, 79, 84] {
  let sweep = NukeMusicSweep()
  sweep.update(active: true, tick: 100, durationTicks: duration, now: 0)
  sweep.update(active: true, tick: 100 + duration + 20, durationTicks: duration, now: 1)
  precondition(sweep.amount == 1) // Hold while later lemmings still have to pop.
  sweep.update(active: true, tick: 100 + duration + 21, durationTicks: duration,
    allPopped: true, now: 2)
  precondition(sweep.amount == 1) // No discontinuity at the last pop.
  sweep.advanceReturn(at: 2 + NukeMusicSweep.returnDuration / 2)
  precondition(abs(sweep.amount - 0.5) < 0.0001)
  // Repeated result refreshes must not restart the return sweep.
  sweep.update(active: true, tick: 100 + duration + 21, durationTicks: duration,
    allPopped: true, now: 2 + NukeMusicSweep.returnDuration)
  precondition(sweep.amount < 0.0001)
  sweep.advanceReturn(at: 4)
  precondition(sweep.amount == 0)
  sweep.update(active: true, tick: 100 + duration / 2, durationTicks: duration, now: 5)
  precondition(sweep.amount > 0.45 && sweep.amount <= 0.5) // Rewind re-enters the countdown.
  sweep.update(active: true, tick: 100 + duration, durationTicks: duration, allPopped: true, now: 6)
  sweep.reset()
  sweep.advanceReturn(at: 6.1)
  precondition(sweep.amount == 0) // Retry, undo and disabling HD cannot retain a return.
}
print("PASS last-pop hold, 280 ms filter return, stopped simulation ticks, result refresh, rewind and cancellation")
