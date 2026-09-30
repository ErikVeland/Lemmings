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
    precondition(deck.nukeEQ.bands[0].gain == -24 * amount)
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
      precondition(nukeEQ.bands[0].gain == -24 && nukeEQ.globalGain == -5)
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
  let drained = try MusicFileDeck.nukeEnergy(frequency: frequency, amount: 1)
  precondition(dry > 0 && drained < dry * 0.3)
  print("PASS nuke EQ at \(frequency) Hz: \(10 * log10(drained / dry)) dB")
}
print("PASS nuke bass envelope, spatial origin, mass-explosion limit, reset and mute (offline only)")
