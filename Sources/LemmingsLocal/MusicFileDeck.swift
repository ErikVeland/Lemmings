import AVFoundation

/// Plays one decoded music file through a small modern mix chain.
///
/// File segments stream through the audio engine. Two queued passes keep
/// the loop continuous without decoding the whole song on the UI thread.
@MainActor
final class MusicFileDeck {
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let varispeed = AVAudioUnitVarispeed()
  private let speedPitch = AVAudioUnitTimePitch()
  private let equaliser = AVAudioUnitEQ(numberOfBands: 3)
  private let sourceMixer = AVAudioMixerNode()
  private let reverb = AVAudioUnitReverb()
  private let spatialMixer = AVAudioMixerNode()
  private let outputMixer = AVAudioMixerNode()
  private let file: AVAudioFile
  private let repeats: Bool
  private var playbackGeneration = 0
  private(set) var completedLoops = 0
  private var fadeTask: Task<Void, Never>?
  private var outputSuspended = false
  private var resumeAfterSuspend = false
  private var started = false
  private var masterVolume: Float = 1
  private var muted = false

  var volume: Float {
    get { masterVolume }
    set {
      masterVolume = min(1, max(0, newValue))
      outputMixer.outputVolume = muted ? 0 : masterVolume
    }
  }

  var playbackRate: Float {
    get { varispeed.rate }
    set { varispeed.rate = min(1, max(0.5, newValue)) }
  }

  var isPlaying: Bool { started && !outputSuspended && player.isPlaying }

  init?(url: URL, repeats: Bool = true) {
    guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { return nil }
    self.file = file
    self.repeats = repeats

    let bands = equaliser.bands
    bands[0].filterType = .lowShelf
    bands[0].frequency = 90
    bands[0].gain = 1.5
    bands[1].filterType = .parametric
    bands[1].frequency = 520
    bands[1].bandwidth = 0.8
    bands[1].gain = -0.8
    bands[2].filterType = .highShelf
    bands[2].frequency = 7_500
    bands[2].gain = 1.5
    equaliser.globalGain = -1.0

    reverb.loadFactoryPreset(.mediumRoom)
    reverb.wetDryMix = 5

    engine.attach(player)
    engine.attach(varispeed)
    engine.attach(speedPitch)
    engine.attach(equaliser)
    engine.attach(sourceMixer)
    engine.attach(reverb)
    engine.attach(spatialMixer)
    engine.attach(outputMixer)

    let format = file.processingFormat
    engine.connect(player, to: varispeed, format: format)
    engine.connect(varispeed, to: speedPitch, format: format)
    engine.connect(speedPitch, to: equaliser, format: format)
    engine.connect(equaliser, to: sourceMixer, format: format)
    engine.connect(sourceMixer, to: reverb, format: format)
    engine.connect(reverb, to: spatialMixer, format: format)
    engine.connect(spatialMixer, to: outputMixer, format: format)
    engine.connect(outputMixer, to: engine.mainMixerNode, format: format)

    // Let Core Audio choose the best available spatial algorithm for the
    // current output device. Keep the source centred, like a DJ master bus.
    spatialMixer.renderingAlgorithm = .auto
    spatialMixer.sourceMode = .pointSource
    spatialMixer.position = AVAudio3DPoint(x: 0, y: 0, z: -1)
    sourceMixer.outputVolume = 1
    outputMixer.outputVolume = masterVolume
  }

  func setMixBass(_ gain: Float) { equaliser.bands[0].gain = 1.5 + gain; equaliser.bands[0].bypass = false }

  func setSpeedPitch(_ cents: Double) {
    speedPitch.pitch = Float(min(1200 * log2(1.5), max(0, cents)))
  }

  func play() {
    fadeTask?.cancel()
    fadeTask = nil
    outputSuspended = false
    sourceMixer.outputVolume = 0
    do {
      if !engine.isRunning { try engine.start() }
    } catch {
      return
    }
    if !started {
      started = true
      playbackGeneration += 1
      scheduleLoop(generation: playbackGeneration)
      if repeats { scheduleLoop(generation: playbackGeneration) }
    }
    if !player.isPlaying { player.play() }
    fadeTask = Task { @MainActor [weak self] in
      guard let self else { return }
      for step in 1...8 {
        guard !Task.isCancelled, !self.outputSuspended else { return }
        try? await Task.sleep(nanoseconds: 15_000_000)
        self.sourceMixer.outputVolume = Float(step) / 8
      }
      self.fadeTask = nil
    }
  }

  private func scheduleLoop(generation: Int) {
    player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self, self.started, self.playbackGeneration == generation else { return }
        self.completedLoops += 1
        if self.repeats {
          self.scheduleLoop(generation: generation)
        } else {
          self.started = false
          self.player.stop()
        }
      }
    }
  }

  /// Cuts the source quickly, then leaves a short room tail before pausing.
  func suspendOutput() {
    guard started, !outputSuspended else { return }
    outputSuspended = true
    resumeAfterSuspend = player.isPlaying
    fadeTask?.cancel()
    fadeTask = Task { @MainActor [weak self] in
      guard let self else { return }
      let start = self.sourceMixer.outputVolume
      for step in 1...3 {
        guard !Task.isCancelled else { return }
        try? await Task.sleep(nanoseconds: 8_000_000)
        self.sourceMixer.outputVolume = start * Float(3 - step) / 3
      }
      guard !Task.isCancelled, self.outputSuspended else { return }
      if self.resumeAfterSuspend { self.player.pause() }
      try? await Task.sleep(nanoseconds: 140_000_000)
      guard !Task.isCancelled, self.outputSuspended else { return }
      self.engine.pause()
    }
  }

  func resumeOutput() {
    guard outputSuspended else { return }
    fadeTask?.cancel()
    fadeTask = nil
    outputSuspended = false
    sourceMixer.outputVolume = 1
    do { if !engine.isRunning { try engine.start() } }
    catch { return }
    if resumeAfterSuspend && !player.isPlaying { player.play() }
    resumeAfterSuspend = false
  }

  func setMuted(_ muted: Bool) {
    self.muted = muted
    outputMixer.outputVolume = muted ? 0 : masterVolume
  }

  func stop() {
    fadeTask?.cancel()
    fadeTask = nil
    outputSuspended = false
    resumeAfterSuspend = false
    playbackGeneration += 1
    completedLoops = 0
    player.stop()
    engine.stop()
    started = false
  }
}
