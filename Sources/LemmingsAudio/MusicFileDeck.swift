import AVFoundation
import AudioToolbox
import Foundation
import NxlvKit

/// Peak protection follows EQ, pitch and reverb so their boosts cannot clip.
enum MusicOutputSafety {
  static func limiter() -> AVAudioUnitEffect {
    AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
      componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_PeakLimiter,
      componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0))
  }
}

/// Decode ahead on one worker. Neither the UI nor the render callback reads files.
private final class MusicPCMStream: @unchecked Sendable {
  private final class Buffer: @unchecked Sendable {
    let pcm: AVAudioPCMBuffer
    init(format: AVAudioFormat, frames: Int) {
      pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
    }
  }
  private let queue = DispatchQueue(label: "Lemmings.recording-pcm", qos: .userInitiated)
  private let file: AVAudioFile
  private let node: AVAudioPlayerNode
  private let repeats: Bool
  private let firstSegment: (start: Int64, count: Int64)
  private let loopSegment: (start: Int64, count: Int64)
  private let scratch: AVAudioPCMBuffer
  private let frames = 2048
  private let bufferCount = 8
  // Only the worker accesses decoder and scheduling state.
  private var generation = 0
  private var segmentEnd: Int64 = 0
  private var ended = false
  private var lastSamples: [Float]
  private var joinOffsets: [Float]
  private var joining = false
  private var joinFrame = 0
  private let joinFrames: Int

  init(file: AVAudioFile, node: AVAudioPlayerNode, repeats: Bool, profile: MusicPlaybackCatalogue.Entry?) {
    self.file = file; self.node = node; self.repeats = repeats
    firstSegment = profile?.segment(first: true, repeats: repeats, fileFrames: file.length,
      fileRate: file.processingFormat.sampleRate) ?? (0, file.length)
    loopSegment = profile?.segment(first: false, repeats: repeats, fileFrames: file.length,
      fileRate: file.processingFormat.sampleRate) ?? (0, file.length)
    scratch = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 2048)!
    lastSamples = .init(repeating: 0, count: Int(file.processingFormat.channelCount))
    joinOffsets = lastSamples
    joinFrames = max(1, Int(file.processingFormat.sampleRate * 0.003))
  }

  func start(offline: Bool, completion: @escaping @Sendable () -> Void) throws {
    try queue.sync {
      generation += 1
      let token = generation
      file.framePosition = firstSegment.start
      segmentEnd = firstSegment.start + firstSegment.count
      ended = false; joining = false; joinFrame = joinFrames
      lastSamples = .init(repeating: 0, count: lastSamples.count)
      joinOffsets = lastSamples
      for _ in 0..<bufferCount where !ended {
        let buffer = Buffer(format: file.processingFormat, frames: frames)
        try schedule(buffer, token: token, offline: offline, completion: completion)
      }
    }
  }

  func stop() { queue.sync { generation += 1; ended = true } }
  /// Lets offline tests wait for refill without yielding the main actor.
  func drain() { queue.sync {} }

  private func schedule(_ buffer: Buffer, token: Int, offline: Bool,
                        completion: @escaping @Sendable () -> Void) throws {
    guard generation == token, !ended else { return }
    let pcm = buffer.pcm
    var filled = 0
    while filled < frames {
      if file.framePosition >= segmentEnd {
        guard repeats else { ended = true; break }
        file.framePosition = loopSegment.start
        segmentEnd = loopSegment.start + loopSegment.count
        joining = true; joinFrame = 0
      }
      let count = min(frames - filled, Int(segmentEnd - file.framePosition))
      try file.read(into: scratch, frameCount: AVAudioFrameCount(count))
      let read = Int(scratch.frameLength)
      guard read > 0 else { ended = true; break }
      for index in 0..<read {
        if joining {
          for channel in lastSamples.indices {
            let delta = lastSamples[channel] - scratch.floatChannelData![channel][index]
            // Leave continuous source loops untouched. Correct abrupt seams
            // from the last sample, without changing the source frame count.
            joinOffsets[channel] = abs(delta) > 0.05 ? delta : 0
          }
          joining = false
        }
        let weight = joinFrame < joinFrames
          ? Float(0.5 + 0.5 * cos(.pi * Double(joinFrame) / Double(joinFrames))) : 0
        for channel in lastSamples.indices {
          let value = scratch.floatChannelData![channel][index] + joinOffsets[channel] * weight
          pcm.floatChannelData![channel][filled + index] = value
          lastSamples[channel] = value
        }
        joinFrame += 1
      }
      filled += read
    }
    pcm.frameLength = AVAudioFrameCount(filled)
    guard filled > 0 else { return }
    let final = !repeats && file.framePosition >= segmentEnd
    if final { ended = true }
    let callback: AVAudioPlayerNodeCompletionCallbackType = final
      ? (offline ? .dataRendered : .dataPlayedBack) : .dataConsumed
    node.scheduleBuffer(pcm, completionCallbackType: callback) { [weak self] _ in
      guard let self else { return }
      self.queue.async { [weak self] in
        guard let self, self.generation == token else { return }
        if final { completion() }
        else { try? self.schedule(buffer, token: token, offline: offline, completion: completion) }
      }
    }
  }
}

/// Keep the countdown audible while progressively removing treble.
public enum NukeMusicFilter {
  public static func configure(_ eq: AVAudioUnitEQ) {
    eq.bands[0].filterType = .lowShelf
    eq.bands[0].frequency = 180
    eq.bands[0].bypass = false
    eq.bands[1].filterType = .lowPass
  }

  public static func apply(_ value: Float, to eq: AVAudioUnitEQ) {
    let amount = value.isFinite ? min(1, max(0, value)) : 0
    eq.bands[0].gain = 3 * amount
    eq.bands[1].frequency = 20000 * pow(450.0 / 20000, amount)
    eq.bands[1].bypass = amount == 0
    eq.globalGain = 0
  }
}

/// Plays one decoded music file through a small modern mix chain.
///
/// A bounded PCM queue keeps source loops independent of UI and disk timing.
@MainActor
public final class MusicFileDeck {
  private let engine = AVAudioEngine()
  private let nukeEQ = AVAudioUnitEQ(numberOfBands: 2)
  private var nukeFilterAmount: Float = 0
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
  private let limiter = MusicOutputSafety.limiter()
  private lazy var rewindAudio = MusicRewindBuffer(sampleRate: file.processingFormat.sampleRate)
  private var rewindTask: Task<Void, Never>?
  private var rewindNode: AVAudioSourceNode?
  private let file: AVAudioFile
  private let stream: MusicPCMStream
  private let repeats: Bool
  private let originalMix: Bool
  private var restingWet: Float { originalMix ? 0 : Turntable.restingWet }
  private let profile: MusicPlaybackCatalogue.Entry?
  private var playbackGeneration = 0
  public var completedLoops: Int {
    guard started, let time = player.lastRenderTime.flatMap({ player.playerTime(forNodeTime: $0) }) else { return 0 }
    let first: (start: Int64, count: Int64) = profile?.segment(first: true, repeats: repeats, fileFrames: file.length,
      fileRate: file.processingFormat.sampleRate) ?? (0, file.length)
    let loop: (start: Int64, count: Int64) = profile?.segment(first: false, repeats: repeats, fileFrames: file.length,
      fileRate: file.processingFormat.sampleRate) ?? (0, file.length)
    guard time.sampleTime >= first.count else { return 0 }
    return 1 + (repeats ? Int((time.sampleTime - first.count) / max(1, loop.count)) : 0)
  }
  private var fadeTask: Task<Void, Never>?
  private var outputSuspended = false
  private var resumeAfterSuspend = false
  private var started = false
  private var masterVolume: Float = 1
  private var requestedRate: Float = 1
  private var gameplayPitch: Double = 0
  private var mixPitch: Double = 0
  private var appliedPitch: Float?
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

  public var volume: Float {
    get { masterVolume }
    set {
      masterVolume = min(1, max(0, newValue))
      if masterVolume == 0 { cancelRewind() }
      applyOutputVolume()
    }
  }

  private var vinyl: (rate: Float, gain: Float) = (1, 1)

  public var playbackRate: Float {
    get { requestedRate }
    set { requestedRate = min(1.08, max(0.5, newValue)); applyRate() }
  }

  /// The player's timeline excludes pauses and advances in source samples.
  public var sourceSeconds: Double {
    guard let renderTime = player.lastRenderTime,
      let time = player.playerTime(forNodeTime: renderTime), time.sampleRate > 0 else { return 0 }
    let elapsed = Double(time.sampleTime) / time.sampleRate
    let sourceLoopApplies = profile?.sampleRate == file.processingFormat.sampleRate
      && (profile?.loop?.endFrame ?? 0) <= file.length
    return profile?.position(at: elapsed, repeats: repeats && sourceLoopApplies) ?? elapsed
  }

  /// Turntable speed and level for a vinyl stop or start. Varispeed cannot
  /// go below a quarter speed, so the gain carries the last of the brake.
  public func setVinyl(rate: Double, gain: Double) {
    vinyl = (Float(rate), Float(min(1, max(0, gain))))
    applyRate()
    applyOutputVolume()
  }

  private func applyRate() { if !outputSuspended { varispeed.rate = max(0.25, requestedRate * vinyl.rate) } }
  private func applyOutputVolume() { outputMixer.outputVolume = muted ? 0 : masterVolume * vinyl.gain }

  public var isPlaying: Bool { started && !outputSuspended && player.isPlaying }

  public init?(url: URL, repeats: Bool = true, rhythmURL: URL? = nil,
        profile: MusicPlaybackCatalogue.Entry? = nil, originalMix: Bool = false) {
    guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { return nil }
    self.file = file
    self.stream = MusicPCMStream(file: file, node: player, repeats: repeats, profile: profile)
    self.repeats = repeats
    self.originalMix = originalMix
    self.profile = profile
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
    // A constant measured trim preserves attacks and the recording's dynamics.
    if originalMix { bands.forEach { $0.gain = 0 } }
    equaliser.globalGain = (originalMix ? 0 : -1.0) + Float(profile?.gainDB ?? 0)

    reverb.loadFactoryPreset(.mediumRoom)
    reverb.wetDryMix = restingWet

    engine.attach(player)
    engine.attach(musicLayer)
    engine.attach(inputMixer)
    engine.attach(varispeed)
    engine.attach(speedPitch)
    engine.attach(equaliser)
    engine.attach(sourceMixer)
    engine.attach(nukeEQ)
    NukeMusicFilter.configure(nukeEQ)
    NukeMusicFilter.apply(nukeFilterAmount, to: nukeEQ)
    engine.attach(reverb)
    engine.attach(spatialMixer)
    engine.attach(outputMixer)
    engine.attach(limiter)

    let sourceFormat = file.processingFormat
    // Reverb and pitch processing use a stable stereo bus. The layer mixers
    // convert mono recordings before those effects, at the source sample rate.
    let format = AVAudioFormat(standardFormatWithSampleRate: sourceFormat.sampleRate, channels: 2)!
    engine.connect(player, to: musicLayer, format: sourceFormat)
    engine.connect(musicLayer, to: inputMixer, fromBus: 0, toBus: 0, format: format)
    if rhythmBuffer != nil {
      engine.attach(rhythmPlayer); engine.attach(rhythmLayer)
      engine.connect(rhythmPlayer, to: rhythmLayer, format: sourceFormat)
      engine.connect(rhythmLayer, to: inputMixer, fromBus: 0, toBus: 1, format: format)
      rhythmLayer.outputVolume = 0
    }
    engine.connect(inputMixer, to: varispeed, format: format)
    engine.connect(varispeed, to: speedPitch, format: format)
    engine.connect(speedPitch, to: equaliser, format: format)
    engine.connect(equaliser, to: sourceMixer, format: format)
    engine.connect(sourceMixer, to: nukeEQ, format: format)
    engine.connect(nukeEQ, to: reverb, format: format)
    engine.connect(reverb, to: spatialMixer, format: format)
    engine.connect(spatialMixer, to: outputMixer, fromBus: 0, toBus: 0, format: format)
    let history = rewindAudio
    let reverse = history.source(format: format)
    engine.attach(reverse)
    engine.connect(reverse, to: outputMixer, fromBus: 0, toBus: 1, format: format)
    rewindNode = reverse
    player.installTap(onBus: 0, bufferSize: 1024, format: sourceFormat) { @Sendable buffer, _ in history.record(buffer) }
    engine.connect(outputMixer, to: limiter, format: format)
    engine.connect(limiter, to: engine.mainMixerNode, format: format)

    // Music stays stereo. Positional effects use a separate environment node.
    sourceMixer.outputVolume = 1
    applyOutputVolume()
  }

  /// Independent of the DJ bass swap and the user's normal music mix.
  public func setNukeAmount(_ value: Float) {
    nukeFilterAmount = value.isFinite ? min(1, max(0, value)) : 0
    NukeMusicFilter.apply(nukeFilterAmount, to: nukeEQ)
  }

  public func setMixBass(_ gain: Float) { equaliser.bands[0].gain = (originalMix ? 0 : 1.5) + gain; equaliser.bands[0].bypass = false }

  public func setSpeedPitch(_ cents: Double) {
    gameplayPitch = min(1200 * log2(1.5), max(0, cents))
    applyPitch()
  }

  public func setMixTempoRatio(_ ratio: Double) {
    mixPitch = -1200 * log2(min(1.08, max(0.92, ratio)))
    applyPitch()
  }

  private func applyPitch() {
    let value = Float(gameplayPitch + mixPitch)
    guard appliedPitch.map({ abs(value - $0) >= 0.1 }) ?? true else { return }
    speedPitch.pitch = value
    appliedPitch = value
  }

  public func play() {
    cancelRewind()
    rewindAudio.setRecording(true)
    setRhythmMode(false)
    // A deck held for its next beat was not playing when paused. Play still
    // starts it, as it did before the spin-up.
    if outputSuspended, started { resumeAfterSuspend = true; resumeOutput(); return }
    fadeTask?.cancel()
    fadeTask = nil
    outputSuspended = false
    sourceMixer.outputVolume = 0
    do {
      if !started {
        playbackGeneration += 1
        let generation = playbackGeneration
        try stream.start(offline: engine.isInManualRenderingMode) { [weak self] in
          Task { @MainActor [weak self] in
            guard let self, self.started, self.playbackGeneration == generation else { return }
            self.stop()
          }
        }
      }
      if !engine.isRunning { try engine.start() }
    } catch {
      stream.stop(); player.stop()
      return
    }
    started = true
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

  /// A vinyl stop slows the source, lets the reverb ring out, then parks the engine.
  public func suspendOutput(rhythmOnly: Bool = false) {
    cancelRewind()
    if rhythmOnly, rhythmBuffer != nil, started {
      if outputSuspended { resumeOutput() }
      setRhythmMode(true)
      return
    }
    guard started, !outputSuspended else { return }
    rewindAudio.setRecording(false)
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
        self.reverb.wetDryMix = self.restingWet + (Turntable.tailWet - self.restingWet) * (1 - remaining)
        if remaining == 0 { break }
      }
      guard !Task.isCancelled, self.outputSuspended else { return }
      if self.resumeAfterSuspend { self.player.pause() }
      do { try await Task.sleep(nanoseconds: UInt64(Turntable.tailSeconds * 1_000_000_000)) } catch { return }
      guard !Task.isCancelled, self.outputSuspended else { return }
      while self.rewindAudio.isRewinding {
        do { try await Task.sleep(nanoseconds: 20_000_000) } catch { return }
        guard !Task.isCancelled, self.outputSuspended else { return }
      }
      self.engine.pause()
      self.reverb.wetDryMix = self.restingWet
      self.varispeed.rate = max(0.25, self.requestedRate * self.vinyl.rate)
    }
  }

  public func resumeOutput() {
    cancelRewind()
    rewindAudio.setRecording(true)
    setRhythmMode(false)
    guard outputSuspended else { return }
    fadeTask?.cancel()
    fadeTask = nil
    outputSuspended = false
    reverb.wetDryMix = restingWet
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

  public func setMuted(_ muted: Bool) {
    self.muted = muted
    if muted { cancelRewind() }
    applyOutputVolume()
  }

  public func stop() {
    cancelRewind(clearHistory: true)
    rewindAudio.setRecording(false)
    rhythmTask?.cancel(); rhythmTask = nil; rhythmMode = false
    if rhythmBuffer != nil { rhythmPlayer.stop() }
    musicLayer.outputVolume = 1; rhythmLayer.outputVolume = 0
    fadeTask?.cancel()
    fadeTask = nil
    outputSuspended = false
    resumeAfterSuspend = false
    playbackGeneration += 1
    stream.stop()
    player.stop()
    engine.stop()
    started = false
  }

  /// Pull the current recording backwards, including when gameplay is paused.
  public func playRewind() {
    guard started, !muted, masterVolume > 0, rewindAudio.trigger() else { return }
    spatialMixer.outputVolume = 0
    do { if !engine.isRunning { try engine.start() } }
    catch { cancelRewind(); return }
    rewindTask?.cancel()
    rewindTask = Task { @MainActor [weak self] in
      do { try await Task.sleep(nanoseconds: 200_000_000) } catch { return }
      guard let self else { return }
      self.cancelRewind()
      if self.outputSuspended && !self.player.isPlaying { self.engine.pause() }
    }
  }

  public func cancelRewind(clearHistory: Bool = false) {
    rewindTask?.cancel(); rewindTask = nil
    rewindAudio.cancel(clearHistory: clearHistory)
    spatialMixer.outputVolume = 1
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
