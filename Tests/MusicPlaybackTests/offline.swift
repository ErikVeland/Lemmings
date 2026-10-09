import Foundation

extension MusicFileDeck {
  @MainActor static func checkRecordedLoopSignal() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("music-source-loop-\(UUID().uuidString).wav")
    defer { try? FileManager.default.removeItem(at: url) }
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    do {
      let file = try AVAudioFile(forWriting: url, settings: format.settings)
      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 132300)!
      buffer.frameLength = 132300
      for channel in 0..<2 { for frame in 0..<132300 {
        // An intro, the repeatable body, and an unmistakable negative outro.
        buffer.floatChannelData![channel][frame] = frame < 44100 ? 0.1 : frame < 88200 ? 0.4 : -0.6
      } }
      try file.write(from: buffer)
    }
    let hash = String(repeating: "a", count: 64)
    let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "variants": [[
      "variantID": "fixture", "path": "fixture.wav", "sourceSHA256": hash,
      "sampleRate": 44100.0, "frameCount": 132300, "integratedLUFS": -22.0,
      "truePeakDBTP": -10.0, "gainDB": -3.0, "loopStatus": "verified-vgm",
      "loop": ["startFrame": 44100, "endFrame": 88200, "sourcePath": "fixture.vgm", "sourceSHA256": hash]]]])
    let profile = try MusicPlaybackCatalogue(data: data).variants[0]
    let deck = MusicFileDeck(url: url, profile: profile)!
    precondition(deck.equaliser.globalGain == -4, "Measured trim did not reach the recording graph")
    deck.reverb.wetDryMix = 0; deck.equaliser.bypass = true
    try deck.engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 1024)
    deck.play()
    deck.fadeTask?.cancel(); deck.fadeTask = nil; deck.sourceMixer.outputVolume = 1
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
    var introFrames = 0, loopFrames = 0, outroFrames = 0
    for _ in 0..<260 {
      let result = try deck.engine.renderOffline(1024, to: buffer)
      precondition(result == .success)
      for frame in 0..<Int(buffer.frameLength) {
        let sample = buffer.floatChannelData![0][frame]
        if sample > 0.08 && sample < 0.12 { introFrames += 1 }
        if sample > 0.35 { loopFrames += 1 }
        if sample < -0.1 { outroFrames += 1 }
      }
      await Task.yield()
      try await Task.sleep(nanoseconds: 1_000_000)
    }
    print("Offline loop signal frames: intro=\(introFrames), body=\(loopFrames), outro=\(outroFrames), completed=\(deck.completedLoops)")
    precondition((40_000...46_000).contains(introFrames), "The intro repeated or went missing")
    precondition(loopFrames > 150_000 && outroFrames == 0, "Source loop repeated its fade/outro or stopped")
    precondition(deck.completedLoops >= 3, "Rendered loop completions did not replenish the queue")
    deck.stop(); deck.engine.disableManualRenderingMode()
    print("PASS offline recording signal: intro once, continuing exact loop, no rendered outro/fade and measured trim routing")
  }
}

try await MusicFileDeck.checkRecordedLoopSignal()
