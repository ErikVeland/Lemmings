import AVFoundation

/// Plays one decoded music file through a small modern mix chain.
///
/// File segments stream through the audio engine. Two queued passes keep
/// the loop continuous without decoding the whole song on the UI thread.
@MainActor
final class MusicFileDeck {
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let rhythmPlayer = AVAudioPlayerNode()
  private let musicLayer = AVAudioMixerNode()
  private let rhythmLayer = AVAudioMixerNode()
  private let inputMixer = AVAudioMixerNode()
  private var rhythmBuffer: AVAudioPCMBuffer?
  private var rhythmMode = false
  private var rhythmTask: Task<Void, Never>?
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
  private var requestedRate: Float = 1
  private var gameplayPitch: Double = 0
  private var mixPitch: Double = 0
  private var muted = false

  /// Turntable timings for a pause and the spin-up that follows it.
  private enum Turntable {
    static let brakeSeconds = 0.5
    static let tailSeconds = 1.2
    static let spinUpSeconds = 0.18
    static let spinUpFloor: Float = 0.3
    static let restingWet: Float = 5
    static let tailWet: Float = 40
  }

  var volume: Float {
    get { masterVolume }
    set {
      masterVolume = min(1, max(0, newValue))
      applyOutputVolume()
    }
  }

  private var vinyl: (rate: Float, gain: Float) = (1, 1)

  var playbackRate: Float {
    get { requestedRate }
    set { requestedRate = min(1.08, max(0.5, newValue)); applyRate() }
  }

  /// The player's timeline excludes pauses and advances in source samples.
  var sourceSeconds: Double {
    guard let renderTime = player.lastRenderTime,
      let time = player.playerTime(forNodeTime: renderTime), time.sampleRate > 0 else { return 0 }
    return Double(time.sampleTime) / time.sampleRate
  }

  /// Turntable speed and level for a vinyl stop or start. Varispeed cannot
  /// go below a quarter speed, so the gain carries the last of the brake.
  func setVinyl(rate: Double, gain: Double) {
    vinyl = (Float(rate), Float(min(1, max(0, gain))))
    applyRate()
    applyOutputVolume()
  }

  private func applyRate() { if !outputSuspended { varispeed.rate = max(0.25, requestedRate * vinyl.rate) } }
  private func applyOutputVolume() { outputMixer.outputVolume = muted ? 0 : masterVolume * vinyl.gain }

  var isPlaying: Bool { started && !outputSuspended && player.isPlaying }

  init?(url: URL, repeats: Bool = true, rhythmURL: URL? = nil) {
    guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { return nil }
    self.file = file
    self.repeats = repeats
    if let rhythmURL, let drumFile = try? AVAudioFile(forReading: rhythmURL),
      drumFile.length > 0, Double(drumFile.length) / drumFile.processingFormat.sampleRate <= 13,
      drumFile.processingFormat.sampleRate == file.processingFormat.sampleRate,
      drumFile.processingFormat.channelCount == file.processingFormat.channelCount,
      let buffer = AVAudioPCMBuffer(pcmFormat: drumFile.processingFormat, frameCapacity: AVAudioFrameCount(drumFile.length)),
      (try? drumFile.read(into: buffer)) != nil { rhythmBuffer = buffer }

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
    reverb.wetDryMix = Turntable.restingWet

    engine.attach(player)
    engine.attach(musicLayer)
    engine.attach(inputMixer)
    engine.attach(varispeed)
    engine.attach(speedPitch)
    engine.attach(equaliser)
    engine.attach(sourceMixer)
    engine.attach(reverb)
    engine.attach(spatialMixer)
    engine.attach(outputMixer)

    let format = file.processingFormat
    engine.connect(player, to: musicLayer, format: format)
    engine.connect(musicLayer, to: inputMixer, fromBus: 0, toBus: 0, format: format)
    if rhythmBuffer != nil {
      engine.attach(rhythmPlayer); engine.attach(rhythmLayer)
      engine.connect(rhythmPlayer, to: rhythmLayer, format: format)
      engine.connect(rhythmLayer, to: inputMixer, fromBus: 0, toBus: 1, format: format)
      rhythmLayer.outputVolume = 0
    }
    engine.connect(inputMixer, to: varispeed, format: format)
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
    applyOutputVolume()
  }

  func setMixBass(_ gain: Float) { equaliser.bands[0].gain = 1.5 + gain; equaliser.bands[0].bypass = false }

  func setSpeedPitch(_ cents: Double) {
    gameplayPitch = min(1200 * log2(1.5), max(0, cents))
    speedPitch.pitch = Float(gameplayPitch + mixPitch)
  }

  func setMixTempoRatio(_ ratio: Double) {
    mixPitch = -1200 * log2(min(1.08, max(0.92, ratio)))
    speedPitch.pitch = Float(gameplayPitch + mixPitch)
  }

  func play() {
    setRhythmMode(false)
    // A deck held for its next beat was not playing when paused. Play still
    // starts it, as it did before the spin-up.
    if outputSuspended, started { resumeAfterSuspend = true; resumeOutput(); return }
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
        do { try await Task.sleep(nanoseconds: 15_000_000) } catch { return }
        guard !Task.isCancelled, !self.outputSuspended else { return }
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
          self.rhythmTask?.cancel()
          if self.rhythmBuffer != nil { self.rhythmPlayer.stop() }
          self.rhythmMode = false
          self.musicLayer.outputVolume = 1
          self.rhythmLayer.outputVolume = 0
        }
      }
    }
  }

  /// A vinyl stop slows the source, lets the reverb ring out, then parks the engine.
  func suspendOutput(rhythmOnly: Bool = false) {
    if rhythmOnly, rhythmBuffer != nil, started {
      if outputSuspended { resumeOutput() }
      setRhythmMode(true)
      return
    }
    guard started, !outputSuspended else { return }
    outputSuspended = true
    resumeAfterSuspend = player.isPlaying
    fadeTask?.cancel()
    fadeTask = Task { @MainActor [weak self] in
      guard let self else { return }
      let start = self.sourceMixer.outputVolume
      let began = ProcessInfo.processInfo.systemUptime
      while true {
        guard !Task.isCancelled else { return }
        do { try await Task.sleep(nanoseconds: 8_000_000) } catch { return }
        guard !Task.isCancelled, self.outputSuspended else { return }
        let remaining = Float(max(0, 1 - (ProcessInfo.processInfo.systemUptime - began) / Turntable.brakeSeconds))
        // Varispeed stops at a quarter speed, so the level carries the end of the brake.
        self.varispeed.rate = max(0.25, self.requestedRate * self.vinyl.rate * remaining * remaining)
        self.sourceMixer.outputVolume = start * remaining.squareRoot()
        self.reverb.wetDryMix = Turntable.restingWet + (Turntable.tailWet - Turntable.restingWet) * (1 - remaining)
        if remaining == 0 { break }
      }
      guard !Task.isCancelled, self.outputSuspended else { return }
      if self.resumeAfterSuspend { self.player.pause() }
      do { try await Task.sleep(nanoseconds: UInt64(Turntable.tailSeconds * 1_000_000_000)) } catch { return }
      guard !Task.isCancelled, self.outputSuspended else { return }
      self.engine.pause()
      self.reverb.wetDryMix = Turntable.restingWet
      self.varispeed.rate = max(0.25, self.requestedRate * self.vinyl.rate)
    }
  }

  func resumeOutput() {
    setRhythmMode(false)
    guard outputSuspended else { return }
    fadeTask?.cancel()
    fadeTask = nil
    outputSuspended = false
    reverb.wetDryMix = Turntable.restingWet
    varispeed.rate = max(0.25, requestedRate * vinyl.rate * Turntable.spinUpFloor)
    sourceMixer.outputVolume = Turntable.spinUpFloor
    do { if !engine.isRunning { try engine.start() } }
    catch { applyRate(); sourceMixer.outputVolume = 1; return }
    if resumeAfterSuspend && !player.isPlaying { player.play() }
    resumeAfterSuspend = false
    // A quick spin-up brings the platter back to speed.
    fadeTask = Task { @MainActor [weak self] in
      guard let self else { return }
      let began = ProcessInfo.processInfo.systemUptime
      while true {
        do { try await Task.sleep(nanoseconds: 8_000_000) } catch { return }
        guard !Task.isCancelled, !self.outputSuspended else { return }
        let progress = Float(min(1, (ProcessInfo.processInfo.systemUptime - began) / Turntable.spinUpSeconds))
        let eased = 1 - (1 - progress) * (1 - progress)
        let speed = Turntable.spinUpFloor + (1 - Turntable.spinUpFloor) * eased
        self.varispeed.rate = max(0.25, self.requestedRate * self.vinyl.rate * speed)
        self.sourceMixer.outputVolume = speed
        if progress == 1 { break }
      }
      self.fadeTask = nil
    }
  }

  func setMuted(_ muted: Bool) {
    self.muted = muted
    applyOutputVolume()
  }

  func stop() {
    rhythmTask?.cancel(); rhythmTask = nil; rhythmMode = false
    if rhythmBuffer != nil { rhythmPlayer.stop() }
    musicLayer.outputVolume = 1; rhythmLayer.outputVolume = 0
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

  private func setRhythmMode(_ enabled: Bool) {
    guard let rhythmBuffer, enabled != rhythmMode else { return }
    rhythmMode = enabled
    rhythmTask?.cancel()
    if enabled && !rhythmPlayer.isPlaying {
      rhythmPlayer.scheduleBuffer(rhythmBuffer, at: nil, options: .loops)
      rhythmPlayer.play()
    }
    let start = rhythmLayer.outputVolume
    rhythmTask = Task { @MainActor [weak self] in
      guard let self else { return }
      for step in 1...10 {
        do { try await Task.sleep(nanoseconds: 8_000_000) } catch { return }
        let gain = start + ((enabled ? 1 : 0) - start) * Float(step) / 10
        self.musicLayer.outputVolume = 1 - gain
        self.rhythmLayer.outputVolume = gain
      }
      if !enabled { self.rhythmPlayer.stop() }
    }
  }
}
