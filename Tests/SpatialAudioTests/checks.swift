extension SoundEffectPlayer {
  func prepareOfflineForCheck() throws {
    try engine.enableManualRenderingMode(.offline,
      format: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!, maximumFrameCount: 512)
  }

  func checkCameraMovement() throws {
    try prepareOfflineForCheck()
    try start()
    let tone = (0..<44100).map { Float(sin(Double($0) * 2 * .pi * 440 / 44100)) * 0.25 }
    let point = GameplaySoundPoint(x: 0, y: 80)
    setViewport(.init(x: 0, y: 0, width: 320, height: 160))
    play(samples: tone, rate: 44100, at: point)
    let slot = voices.firstIndex(where: { $0.isActive })!
    let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 512)!
    func energy() throws -> (Double, Double) {
      var l = 0.0, r = 0.0
      for step in 0..<12 {
        let status = try engine.renderOffline(512, to: buffer)
        precondition(status == .success)
        if step < 4 { continue }
        for frame in 0..<Int(buffer.frameLength) {
          l += pow(Double(buffer.floatChannelData![0][frame]), 2)
          r += pow(Double(buffer.floatChannelData![1][frame]), 2)
        }
      }
      return (l, r)
    }
    let left = try energy()
    setViewport(.init(x: -320, y: 0, width: 320, height: 160))
    let right = try energy()
    precondition(left.0 > left.1 && right.1 > right.0, "Active sound failed to follow the camera")
    setViewport(.init(x: 640, y: 0, width: 320, height: 160))
    precondition(voices[slot].distanceGain < 0.1 && spatialMixers[slot].position.x < 0)
    silence()
    setViewport(.init(x: 0, y: 0, width: 320, height: 160))
    play([PositionedSoundCue(.builderWarning, at: .init(x: 0, y: 80)),
          PositionedSoundCue(.builderWarning, at: .init(x: 4, y: 80)),
          PositionedSoundCue(.builderWarning, at: .init(x: 320, y: 80))])
    precondition(voices.filter(\.isActive).count == 2, "Spatial dedup collapsed opposite sides or stacked neighbours")
    stop(); engine.disableManualRenderingMode()
    print("PASS offline spatial output follows camera movement, offscreen distance and separate event positions")
  }

  func renderForCheck(pan: Float) throws -> (Double, Double) {
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
    try start()
    play(.builderWarning, pan: pan)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
    var left = 0.0, right = 0.0
    for _ in 0..<12 {
      let result = try engine.renderOffline(512, to: buffer)
      precondition(result == .success)
      for i in 0..<Int(buffer.frameLength) {
        let l = Double(buffer.floatChannelData![0][i])
        let r = Double(buffer.floatChannelData![1][i])
        precondition(l.isFinite && r.isFinite)
        left += l*l; right += r*r
      }
    }
    stop()
    engine.disableManualRenderingMode()
    return (left, right)
  }

  func pauseBacklogForCheck() throws -> (Double, Double) {
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
    try start()
    play(.builderWarning)
    suspendOutput()
    play(.builderWarning)
    try resumeOutput()
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
    func energy() throws -> Double {
      let result = try engine.renderOffline(512, to: buffer)
      precondition(result == .success)
      return (0..<Int(buffer.frameLength)).reduce(0) { total, index in
        total + abs(Double(buffer.floatChannelData![0][index]))
      }
    }
    let stale = try energy()
    play(.builderWarning)
    let fresh = try energy()
    stop()
    engine.disableManualRenderingMode()
    return (stale, fresh)
  }
}
let player = SoundEffectPlayer(voiceCount: 4)
try player.checkCameraMovement()
let left = try player.renderForCheck(pan: -1)
let right = try player.renderForCheck(pan: 1)
precondition(left.0 > left.1 && right.1 > right.0)
precondition(left.0 > 0 && right.1 > 0)
let backlog = try player.pauseBacklogForCheck()
precondition(backlog.0 == 0 && backlog.1 > 0)
try player.prepareOfflineForCheck()
try player.start()
player.setMuted(true)
player.play(.builderWarning)
player.suspendOutput()
try player.resumeOutput()
player.stop()
print("Spatial audio: finite output, positioning, restart, mute and pause backlog passed", left, right)

for width in [160.0, 320, 960] {
  let view = GameplaySoundViewport(x: 100, y: 50, width: width, height: 160)
  let centre = view.placement(of: .init(x: 100 + width / 2, y: 130))
  precondition(abs(centre.x) < 0.0001 && abs(centre.y) < 0.0001 && centre.gain == 1)
  precondition(view.placement(of: .init(x: 100, y: 130)).x < 0)
  precondition(view.placement(of: .init(x: 100 + width, y: 130)).x > 0)
  precondition(view.placement(of: .init(x: 100 + width / 2, y: 50)).y > 0)
  precondition(view.placement(of: .init(x: 100 + width / 2, y: 210)).y < 0)
  let invalid = view.placement(of: .init(x: .infinity, y: .nan))
  precondition(invalid.x == 0 && invalid.y == 0 && invalid.z == -1)
}
print("PASS camera geometry at zoomed, standard and wide aspect ratios, elevation and invalid-coordinate fallback")

extension SoundEffectPlayer {
  func checkRewindFeedbackAndPolyphony() {
    playRewindScrub()
    precondition(!voices.contains { $0.isActive }, "Silent history invented a rewind effect")
    latestRecentSample = 44_099
    for index in 0..<44_100 {
      recentSamplePositions[index] = Int64(index)
      recentSamples[index] = Float(index) / 44_100 * 0.3
    }
    let original = recentSamples
    playRewindScrub()
    let mixed = voices.first(where: { $0.isActive })!.samples
    precondition(mixed.count == Int(44_100 * VinylBackspin.seconds) && mixed[1000] > mixed[1100],
      "Rewind did not travel backwards through real history")
    precondition(mixed.allSatisfy { $0.isFinite && abs($0) <= 0.3 }
      && mixed.first == 0 && mixed.last == 0, "Rewind had invalid samples or clicking endpoints")
    let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!, frameCapacity: 512)!
    buffer.frameLength = 512
    for _ in 0..<200 {
      for _ in 0..<12 { playRewindScrub() }
      let active = voices.indices.filter { voices[$0].isActive }
      precondition(active.count <= 1, "Rapid rewind taps stacked cues")
      for index in active.isEmpty ? [] : Array(voices.indices) {
        fillVoice(index, buffers: UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList), frames: 512, sampleTime: 0)
        precondition((0..<512).allSatisfy { abs(buffer.floatChannelData![0][$0]) < 0.4 },
          "Rewind exceeded its mix budget")
      }
      precondition(recentSamples == original && latestRecentSample == 44_099,
        "Rewind audio fed back into its own history")
    }
    setMuted(true); playRewindScrub()
    precondition(!voices.contains { $0.isActive }, "Muted rewind started a voice")
    setMuted(false); outputSuspended = true; playRewindScrub()
    precondition(!voices.contains { $0.isActive }, "Suspended output queued a rewind")
    print("PASS silent-history silence, 480 ms backspin, reversed history, idle-source capture isolation, one-voice repeat cap, mute and suspension after 2400 requests")
  }

  func checkCapturedMixAndContinuation() {
    let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!, frameCapacity: 512)!
    buffer.frameLength = 512
    let buffers = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
    voices[0] = Voice(samples: [Float](repeating: 0.4, count: 44_100), isActive: true, gain: 0.5, distanceGain: 0.25)
    voices[1] = Voice(samples: [Float](repeating: 0.2, count: 44_100), isActive: true, gain: 0.25)
    setVolume(0.5)
    for block in 0..<80 {
      for index in voices.indices { fillVoice(index, buffers: buffers, frames: 512, sampleTime: Double(block * 512)) }
    }
    precondition(abs(recentSamples[40_000] - 0.1) < 0.00001,
      "Captured mix ignored effect gains or applied master volume twice")
    silence(); playRewindScrub()
    let index = voices.firstIndex(where: { $0.isActive })!
    let head = rewindHistoryHead
    fillVoice(index, buffers: buffers, frames: 512, sampleTime: 40_960)
    let cursor = rewindHistoryHead
    let tail = lastRewindSample
    precondition(cursor < head, "Backspin did not advance the history cursor")
    silence(); playRewindScrub()
    precondition(rewindSliceHead == cursor, "Sequel silence restarted the same backspin fragment")
    precondition(voices.first(where: { $0.isActive })!.samples.first == tail,
      "Repeated backspin cut its waveform to zero")
    silence()
    latestRecentSample = 44_099
    for offset in 0..<44_100 {
      recentSamplePositions[offset] = Int64(offset)
      recentSamples[offset] = Float(offset) / 44_100 * 4
    }
    playRewindScrub()
    let samples = voices.first(where: { $0.isActive })!.samples
    precondition(samples.allSatisfy { abs($0) <= 1 } && samples[1000] > samples[2000],
      "A loud captured mix clipped flat instead of retaining its shape")
    silence()
    lastRewindTrigger = -.infinity
    for offset in 0..<44_100 {
      recentSamples[offset] = Float(sin(Double(offset) * 2 * .pi * 440 / 44_100)) * 0.3
    }
    playRewindScrub()
    let tone = voices.first(where: { $0.isActive })!.samples
    func crossings(_ start: Double, _ end: Double) -> Int {
      (Int(44_100 * start)..<Int(44_100 * end)).filter { tone[$0] * tone[$0 + 1] < 0 }.count
    }
    precondition(crossings(0.03, 0.13) > 2 * crossings(0.30, 0.40),
      "Effect backspin did not lower the pitch of captured sound")
    print("PASS captured voice/distance gains, single master volume, sequel scrub continuation, proportional chorus headroom and falling effect pitch")
  }
}
SoundEffectPlayer().checkRewindFeedbackAndPolyphony()
SoundEffectPlayer(voiceCount: 4).checkCapturedMixAndContinuation()

extension SoundEffectPlayer {
  func checkJoyMixPolicy() {
    library[.yippee] = [Float](repeating: 0.1, count: 44_100)
    rates[.yippee] = 44_100; gains[.yippee] = 0.6
    let rescue = PositionedSoundCue(.yippee, at: .init(x: 80, y: 80))
    play([PositionedSoundCue](repeating: rescue, count: 32))
    play([PositionedSoundCue](repeating: rescue, count: 16))
    precondition(voices.filter(\.isActive).count == 32 && voices.reduce(0) { $0 + $1.rescueLayers.count } == 16,
      "Simultaneous or consecutive rescue voices were collapsed")
    precondition(voices.filter(\.isActive).allSatisfy { $0.gain == 0.6 },
      "Rescue chorus was attenuated as it accumulated")
    play([PositionedSoundCue](repeating: rescue, count: 80))
    precondition(voices.filter(\.isActive).count + voices.reduce(0) { $0 + $1.rescueLayers.count } == 64,
      "A full spatial pool cut off earlier rescue voices")
    precondition(voices.flatMap(\.rescueLayers).allSatisfy { $0.gain == 0.6 && $0.position == 0 },
      "Overflow rescue layers lost their individual gain or playhead")
    play(.timerWarning)
    let rescuedVoices = voices.filter { $0.isActive && $0.isRescue }.count
      + voices.reduce(0) { $0 + $1.rescueLayers.count }
    precondition(rescuedVoices == 64, "A useful warning cut off the rescue chorus")
    silence()
    precondition(voices.allSatisfy { $0.rescueLayers.isEmpty }, "Silence retained an old rescue chorus")
    play(.actionRejected); play(.actionRejected)
    precondition(voices.filter(\.isActive).count == 1, "Rejected presses repeated without a cooldown")
    precondition(voices.filter(\.isActive).allSatisfy { $0.rescueLayers.isEmpty },
      "A new action resurrected rescue layers after silence")
    play(.actionRejected, at: .init(x: 320, y: 80))
    precondition(voices.filter(\.isActive).count == 2, "Separate targets shared a refusal gate")
    silence()
    // Install a long fixture so every reserved voice remains occupied.
    for index in voices.indices { voices[index] = Voice(samples: [0.1], isActive: true, priority: 3) }
    play(.brickPlace)
    precondition(voices.allSatisfy { $0.priority == 3 }, "Work sound stole an action or warning voice")
    setMuted(true)
    precondition(effectiveVolume == 0 && !voices.contains { $0.isActive })
    setMuted(false); setVolume(0.4)
    precondition(effectiveVolume == 0.4)
    for effect in ClassicSoundEffect.allCases {
      guard let clip = GameplaySupplementSounds.clip(for: effect) else { continue }
      precondition(!clip.samples.isEmpty && clip.sampleRate == 44_100)
      precondition(clip.samples.allSatisfy { $0.isFinite && abs($0) <= 0.8 })
      precondition(clip.samples.first == 0 && clip.samples.last == 0, "Supplement clicks at an endpoint")
      precondition(clip.samples.contains { abs($0) > 0.01 }, "Supplement rendered silence")
    }
    precondition(GameplaySupplementSounds.clip(for: .brickPlace)!.samples !=
      GameplaySupplementSounds.clip(for: .timerWarning)!.samples)
    print("PASS 64 bounded full-gain overlapping yippees, isolated refusal gate, protected actions, mute and finite supplement envelopes")
  }
}
SoundEffectPlayer(resources: DeviceEffectResources(physicalMemory: 16 * 1_073_741_824, processorCount: 8)).checkJoyMixPolicy()

extension SoundEffectPlayer {
  func checkRescueLayerLifecycle() throws {
    try prepareOfflineForCheck()
    try start()
    defer { stop(); engine.disableManualRenderingMode() }
    library[.yippee] = [Float](repeating: 0.1, count: 44_100)
    rates[.yippee] = 44_100; gains[.yippee] = 0.6
    let rescue = PositionedSoundCue(.yippee, at: .init(x: 80, y: 80))
    for operation in ["mute", "suspend"] {
      play([PositionedSoundCue](repeating: rescue, count: 128)); play(.timerWarning)
      precondition(!voices.flatMap(\.rescueLayers).isEmpty, "The lifecycle fixture did not fill the chorus")
      if operation == "mute" { setMuted(true); setMuted(false) }
      else { suspendOutput(); try resumeOutput() }
      precondition(voices.allSatisfy { !$0.isActive && $0.rescueLayers.isEmpty },
        "\(operation) retained stale rescue layers")
      play(.actionRejected)
      precondition(voices.filter(\.isActive).count == 1 && voices.allSatisfy { $0.rescueLayers.isEmpty },
        "An action resurrected rescue layers after \(operation)")
      silence()
    }
    play([PositionedSoundCue](repeating: rescue, count: 128)); play(.timerWarning)
    silencePreservingRescues()
    let preserved = voices.filter { $0.isActive && $0.isRescue }.count
      + voices.reduce(0) { $0 + $1.rescueLayers.count }
    precondition(preserved == 64, "Result cleanup cut off the final rescue chorus")
    precondition(voices.filter { $0.isActive && !$0.isRescue }.allSatisfy {
      $0.position == Double($0.samples.count) && !$0.rescueLayers.isEmpty
    }, "Result cleanup kept an ordinary sound playing")
    print("PASS rescue overflow cleanup after silence, mute and suspend; final result chorus preserved")
  }
}
try SoundEffectPlayer(resources: DeviceEffectResources(physicalMemory: 16 * 1_073_741_824, processorCount: 8)).checkRescueLayerLifecycle()
