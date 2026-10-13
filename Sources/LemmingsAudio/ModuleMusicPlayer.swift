import AVFoundation
import Foundation
import NxlvKit

/// Plays ProTracker modules through the system audio output.
///
/// A serial worker synthesises into eight reusable PCM buffers. The audio engine
/// consumes those buffers without taking the synthesis/control lock.
public final class ModuleMusicPlayer: @unchecked Sendable {
  public init() {}

  private let engine = AVAudioEngine()
  private let nukeEQ = AVAudioUnitEQ(numberOfBands: 2)
  private var nukeFilterAmount: Float = 0
  private let speedPitch = AVAudioUnitTimePitch()
  private let reverb = AVAudioUnitReverb()
  private let mixEQ = AVAudioUnitEQ(numberOfBands: 1)
  private var gameplayPitch: Double = 0
  private var mixPitch: Double = 0
  private var appliedPitch: Float?
  private let spatialMixer = AVAudioMixerNode()
  private let outputMixer = AVAudioMixerNode()
  private let limiter = MusicOutputSafety.limiter()
  private var sourceNode: AVAudioPlayerNode?
  private let rewindAudio = MusicRewindBuffer()
  private var rewindNode: AVAudioSourceNode?
  @MainActor private var rewindTask: Task<Void, Never>?
  private var rewindLeft = [Float](repeating: 0, count: 1024)
  private var rewindRight = [Float](repeating: 0, count: 1024)
  private let synthesisQueue = DispatchQueue(label: "Lemmings.module-pcm", qos: .userInteractive)
  // Only the synthesis queue accesses these values.
  private var bufferGeneration = 0
  private let bufferClockLock = NSLock()
  private var scheduledFrames: Int64 = 0
  private let bufferedFrameCount = 1024
  private let bufferCount = 8
  private final class PCMBuffer: @unchecked Sendable {
    let value: AVAudioPCMBuffer
    init(format: AVAudioFormat, frames: Int) {
      value = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
      value.frameLength = AVAudioFrameCount(frames)
    }
  }
  private let lock = NSLock()

  // Guarded by `lock`.
  private var player: ProTrackerEnhancedPlayer?
  private var enhancements: ProTrackerEnhancements = .faithful
  private var isMuted = false
  private var level: Double = 1.0
  private var tempoScale = 1.0
  private var sourceFrames: Int64 = 0
  /// Turntable speed and level during a vinyl stop or start.
  private var vinylRateLocked = 1.0
  private var vinylGain: Float = 1
  private var interpolationPhase = 1.0
  private var currentFrame: (left: Float, right: Float) = (0, 0)
  private var nextFrame: (left: Float, right: Float) = (0, 0)
  private var outputSuspended = false
  private var rewindBufferedFrames = 0
  private var pauseFadeFrames = 0
  private var rhythmAmount = 0.0
  private var rhythmTarget = 0.0
  private let vinylStopSeconds = 0.5
  /// The reverb rings on after the platter stops, then the engine parks.
  private let vinylTailSeconds = 1.2
  private let vinylTailWet: Float = 40
  private let spinUpSeconds = 0.18
  private let spinUpFloor = 0.3
  private var startFadeFrames = 0
  private var spinUpFrames = 0
  private var pauseWorkItem: DispatchWorkItem?

  private let loopCrossfadeFrames = 2048
  private var loopTail = [(left: Float, right: Float)](
    repeating: (left: 0, right: 0), count: 2048)
  private var loopTailWriteIndex = 0
  private var loopTailCount = 0
  private var previousLoopTail: [(left: Float, right: Float)] = []
  private var loopBlendIndex: Int?

  private let sampleRate = 44100.0
  public private(set) var isRunning = false
  public var isOutputRunning: Bool {
    lock.lock()
    defer { lock.unlock() }
    return isRunning && !outputSuspended
  }
  public private(set) var currentTitle: String?
  public private(set) var currentURL: URL?

  /// Modules found in the chosen directory, sorted by name.
  public private(set) var library: [URL] = []

  // MARK: - Engine

  public func start() throws {
    guard !isRunning else { return }
    rewindAudio.setRecording(true)
    let format = AVAudioFormat(
      standardFormatWithSampleRate: sampleRate, channels: 2)!

    let node = AVAudioPlayerNode()

    engine.attach(node)
    engine.attach(speedPitch)
    engine.attach(mixEQ)
    mixEQ.bands[0].filterType = .lowShelf
    mixEQ.bands[0].frequency = 180
    mixEQ.bands[0].bypass = false
    engine.attach(nukeEQ)
    NukeMusicFilter.configure(nukeEQ)
    NukeMusicFilter.apply(nukeFilterAmount, to: nukeEQ)
    engine.attach(reverb)
    engine.attach(spatialMixer)
    engine.attach(outputMixer)
    engine.attach(limiter)
    spatialMixer.outputVolume = muted ? 0 : 1
    reverb.loadFactoryPreset(.mediumRoom)
    reverb.wetDryMix = 0
    // Music stays stereo. Positional effects use a separate environment node.
    engine.connect(node, to: speedPitch, format: format)
    engine.connect(speedPitch, to: mixEQ, format: format)
    engine.connect(mixEQ, to: nukeEQ, format: format)
    engine.connect(nukeEQ, to: reverb, format: format)
    engine.connect(reverb, to: spatialMixer, format: format)
    engine.connect(spatialMixer, to: outputMixer, fromBus: 0, toBus: 0, format: format)
    let reverse = rewindAudio.source(format: format)
    engine.attach(reverse)
    engine.connect(reverse, to: outputMixer, fromBus: 0, toBus: 1, format: format)
    engine.connect(outputMixer, to: limiter, format: format)
    engine.connect(limiter, to: engine.mainMixerNode, format: format)
    rewindNode = reverse
    sourceNode = node
    do {
      try engine.start()
    } catch {
      engine.detach(reverse)
      rewindNode = nil
      engine.detach(node)
      engine.detach(speedPitch)
      engine.detach(spatialMixer)
      engine.detach(reverb)
      engine.detach(mixEQ)
      engine.detach(nukeEQ)
      engine.detach(outputMixer)
      engine.detach(limiter)
      sourceNode = nil
      throw error
    }
    lock.lock()
    outputSuspended = false
    lock.unlock()
    isRunning = true
    synthesisQueue.async { [weak self] in
      guard let self else { return }
      self.bufferGeneration += 1
      self.bufferClockLock.lock(); self.scheduledFrames = 0; self.bufferClockLock.unlock()
      let generation = self.bufferGeneration
      for _ in 0..<self.bufferCount {
        let buffer = PCMBuffer(format: format, frames: self.bufferedFrameCount)
        self.queueBuffer(buffer, node: node, generation: generation)
      }
      node.play()
    }
  }

  /// Buffer completion runs outside the audio render callback. Refill on the worker.
  private func queueBuffer(_ buffer: PCMBuffer, node: AVAudioPlayerNode, generation: Int) {
    guard generation == bufferGeneration else { return }
    fill(UnsafeMutableAudioBufferListPointer(buffer.value.mutableAudioBufferList), frames: bufferedFrameCount)
    bufferClockLock.lock(); scheduledFrames += Int64(bufferedFrameCount); bufferClockLock.unlock()
    node.scheduleBuffer(buffer.value, completionCallbackType: .dataConsumed) { [weak self] _ in
      guard let self else { return }
      self.synthesisQueue.async { [weak self] in
        self?.queueBuffer(buffer, node: node, generation: generation)
      }
    }
  }

  /// Compensate the tracker/DJ clock for samples waiting in the player node.
  private var bufferedSeconds: Double {
    guard let node = sourceNode, isRunning else { return 0 }
    bufferClockLock.lock(); let scheduled = scheduledFrames; bufferClockLock.unlock()
    let played = node.lastRenderTime.flatMap { node.playerTime(forNodeTime: $0) }?.sampleTime ?? 0
    return Double(min(Int64(bufferedFrameCount * bufferCount), max(0, scheduled - played))) / sampleRate
  }

  public func stop() {
    cancelRewind()
    rewindAudio.setRecording(false)
    rewindAudio.cancel(clearHistory: true)
    resetVinyl()
    guard isRunning else { return }
    pauseWorkItem?.cancel()
    pauseWorkItem = nil
    synthesisQueue.sync { bufferGeneration += 1 }
    sourceNode?.stop()
    engine.stop()
    if let sourceNode { engine.detach(sourceNode) }
    engine.detach(speedPitch)
    engine.detach(spatialMixer)
    engine.detach(reverb)
    engine.detach(mixEQ)
    engine.detach(nukeEQ)
    engine.detach(outputMixer)
    engine.detach(limiter)
    sourceNode = nil
    if let rewindNode { engine.detach(rewindNode) }
    rewindNode = nil
    lock.lock()
    outputSuspended = false
    pauseFadeFrames = 0
    rhythmTarget = 0
    rhythmAmount = 0
    startFadeFrames = 0
    spinUpFrames = 0
    lock.unlock()
    isRunning = false
  }

  /// Keep native percussion, or slow the source into a short vinyl stop.
  public func suspendOutput(rhythmOnly: Bool = false) {
    cancelRewind()
    guard isRunning else { return }
    let queuedFrames = min(bufferedFrameCount * bufferCount, Int(bufferedSeconds * sampleRate))
    lock.lock()
    if rhythmOnly, player?.hasRhythm == true {
      pauseWorkItem?.cancel()
      rhythmTarget = 1
      outputSuspended = false
      pauseFadeFrames = 0
      lock.unlock()
      if !engine.isRunning { try? engine.start() }
      return
    }
    guard !outputSuspended else { lock.unlock(); return }
    pauseWorkItem?.cancel()
    outputSuspended = true
    rewindBufferedFrames = queuedFrames
    pauseFadeFrames = Int(sampleRate * vinylStopSeconds)
    spinUpFrames = 0
    lock.unlock()
    reverb.wetDryMix = vinylTailWet
    pauseWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
      guard let self else { return }
      self.lock.lock()
      let shouldPause = self.outputSuspended
      self.lock.unlock()
      if shouldPause && !self.rewindAudio.isRewinding { self.engine.pause(); self.reverb.wetDryMix = 0 }
    }
    pauseWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + vinylStopSeconds + vinylTailSeconds, execute: work)
  }

  public func resumeOutput() throws {
    cancelRewind()
    guard isRunning else { return }
    pauseWorkItem?.cancel()
    pauseWorkItem = nil
    lock.lock()
    if outputSuspended { spinUpFrames = Int(sampleRate * spinUpSeconds) }
    outputSuspended = false
    rhythmTarget = 0
    pauseFadeFrames = 0
    startFadeFrames = Int(sampleRate * 0.14)
    lock.unlock()
    reverb.wetDryMix = 0
    if !engine.isRunning { try engine.start() }
  }

  private func fill(_ buffers: UnsafeMutableAudioBufferListPointer, frames: Int) {
    lock.lock()
    defer { lock.unlock() }

    let left = buffers.count > 0 ? buffers[0].mData?.assumingMemoryBound(to: Float.self) : nil
    let right = buffers.count > 1 ? buffers[1].mData?.assumingMemoryBound(to: Float.self) : left

    guard !isMuted, player != nil else {
      for buffer in buffers { memset(buffer.mData, 0, Int(buffer.mDataByteSize)) }
      return
    }

    if frames > rewindLeft.count {
      rewindLeft = .init(repeating: 0, count: frames)
      rewindRight = .init(repeating: 0, count: frames)
    }
    if interpolationPhase >= 1 {
      currentFrame = nextSourceFrameLocked()
      nextFrame = nextSourceFrameLocked()
      interpolationPhase = 0
    }
    for index in 0..<frames {
      let canAdvance = pauseFadeFrames > 0 || !outputSuspended
      if outputSuspended && pauseFadeFrames > 0 { pauseFadeFrames -= 1 }
      let gain = outputSuspended
        ? Float(pauseFadeFrames) / Float(max(1, Int(sampleRate * vinylStopSeconds)))
        : startFadeGainLocked()

      let frame: (left: Float, right: Float)
      if canAdvance {
        let blend = Float(interpolationPhase)
        frame = (
          left: currentFrame.left + (nextFrame.left - currentFrame.left) * blend,
          right: currentFrame.right + (nextFrame.right - currentFrame.right) * blend)
        interpolationPhase += tempoScale * vinylRateLocked * (outputSuspended ? max(0.02, Double(gain) * Double(gain)) : spinUpRateLocked())
        while interpolationPhase >= 1 {
          currentFrame = nextFrame
          nextFrame = nextSourceFrameLocked()
          interpolationPhase -= 1
        }
      } else {
        frame = (left: 0, right: 0)
      }
      rewindLeft[index] = frame.left
      rewindRight[index] = frame.right
      left?[index] = frame.left * Float(level) * gain * vinylGain
      right?[index] = frame.right * Float(level) * gain * vinylGain
    }
    if !outputSuspended {
      rewindLeft.withUnsafeBufferPointer { l in rewindRight.withUnsafeBufferPointer { r in
        rewindAudio.record(left: l.baseAddress!, right: r.baseAddress!, frames: frames)
      } }
    }
  }

  /// Eases the platter from a crawl back to full speed after a pause.
  private func spinUpRateLocked() -> Double {
    guard spinUpFrames > 0 else { return 1 }
    spinUpFrames -= 1
    let progress = 1 - Double(spinUpFrames) / Double(max(1, Int(sampleRate * spinUpSeconds)))
    return spinUpFloor + (1 - spinUpFloor) * (1 - (1 - progress) * (1 - progress))
  }

  private func startFadeGainLocked() -> Float {
    guard startFadeFrames > 0 else { return 1 }
    startFadeFrames -= 1
    return 1 - Float(startFadeFrames) / Float(max(1, Int(sampleRate * 0.14)))
  }

  private func nextSourceFrameLocked() -> (left: Float, right: Float) {
    rhythmAmount += min(1, 1 / (sampleRate * 0.018)) * (rhythmTarget - rhythmAmount)
    let raw = player!.nextFrame(rhythmAmount: rhythmAmount)
    sourceFrames += 1
    let frame: (left: Float, right: Float)
    if let blendIndex = loopBlendIndex, blendIndex < previousLoopTail.count {
      let amount = Float(blendIndex) / Float(previousLoopTail.count)
      let tail = previousLoopTail.last!
      let incomingGain = 0.5 - 0.5 * cos(amount * .pi)
      frame = (
        left: tail.left + (raw.left - tail.left) * incomingGain,
        right: tail.right + (raw.right - tail.right) * incomingGain)
      loopBlendIndex = blendIndex + 1 < previousLoopTail.count ? blendIndex + 1 : nil
    } else {
      frame = raw
    }

    loopTail[loopTailWriteIndex] = raw
    loopTailWriteIndex = (loopTailWriteIndex + 1) % loopTail.count
    loopTailCount = min(loopTail.count, loopTailCount + 1)

    // Join from the final sample. Replaying the start of the saved tail here
    // made an abrupt backward jump at every order-list boundary.
    if player!.hasFinished {
      previousLoopTail = loopTailSnapshotLocked()
      loopTailWriteIndex = 0
      loopTailCount = 0
      loopBlendIndex = previousLoopTail.isEmpty ? nil : 0
      restartLocked()
    }
    return frame
  }

  private func loopTailSnapshotLocked() -> [(left: Float, right: Float)] {
    guard loopTailCount > 0 else { return [] }
    let start = loopTailCount == loopTail.count ? loopTailWriteIndex : 0
    return (0..<loopTailCount).map { loopTail[(start + $0) % loopTail.count] }
  }

  private var loadedModule: ProTrackerModule?

  private func restartLocked() {
    guard let module = loadedModule else { return }
    player = ProTrackerEnhancedPlayer(
      module: module, sampleRate: sampleRate, enhancements: enhancements)
  }

  // MARK: - Library

  /// Collects every module under a directory, including subfolders.
  public func loadLibrary(at root: URL) {
    guard let walker = FileManager.default.enumerator(
      at: root, includingPropertiesForKeys: nil) else {
      library = []
      return
    }
    library = walker.compactMap { $0 as? URL }
      .filter { $0.pathExtension.lowercased() == "mod" }
      .sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }
  }

  /// Plays the module at an index, wrapping around the library.
  @discardableResult
  public func play(index: Int) -> String? {
    guard !library.isEmpty else { return nil }
    let url = library[((index % library.count) + library.count) % library.count]
    return play(url: url)
  }

  @discardableResult
  public func play(url: URL) -> String? {
    guard let data = try? Data(contentsOf: url),
      let module = try? ProTrackerModule(data: data)
    else { return nil }
    let title = module.title.isEmpty ? url.deletingPathExtension().lastPathComponent : module.title
    if vinylStopping {
      // The braking record finishes first. Its release starts this module.
      vinylPending = (module, url)
      currentURL = url
      currentTitle = title
      return title
    }
    load(module, url: url)
    if vinylHeld {
      vinylHeld = false
      MainActor.assumeIsolated { vinylStart() }
    }
    return title
  }

  private func load(_ module: ProTrackerModule, url: URL) {
    cancelRewind()
    let prepared = ProTrackerEnhancedPlayer(module: module, sampleRate: sampleRate, enhancements: enhancements)
    lock.lock()
    rewindAudio.cancel(clearHistory: true)
    spatialMixer.outputVolume = isMuted ? 0 : 1
    loadedModule = module
    rhythmTarget = 0
    rhythmAmount = 0
    sourceFrames = 0
    player = prepared
    interpolationPhase = 1
    loopTail = Array(repeating: (left: 0, right: 0), count: loopCrossfadeFrames)
    loopTailWriteIndex = 0
    loopTailCount = 0
    previousLoopTail = []
    loopBlendIndex = nil
    startFadeFrames = Int(sampleRate * 0.14)
    lock.unlock()

    currentURL = url
    currentTitle = module.title.isEmpty
      ? url.deletingPathExtension().lastPathComponent
      : module.title
  }

  // MARK: - Vinyl

  // Main actor only.
  private var vinylRamp: VinylRamp?
  private var vinylStopping = false
  private var vinylHeld = false
  private var vinylPending: (module: ProTrackerModule, url: URL)?
  private var vinylReleaseRequested = false

  /// Whether a retry is braking the record now.
  public var isVinylBraking: Bool { vinylStopping }
  /// The turntable speed factor, where 1 is normal speed.
  public var vinylRate: Double {
    lock.lock()
    defer { lock.unlock() }
    return vinylRateLocked
  }

  /// Applies a turntable speed and level directly, for a DJ deck's own ramp.
  public func applyVinyl(rate: Double, gain: Double) {
    lock.lock()
    vinylRateLocked = rate
    vinylGain = Float(gain)
    lock.unlock()
  }

  /// Brakes the playing module like a record stopped by hand.
  ///
  /// The record then rests silent. `vinylRelease()` lets it run on from where
  /// the hand stopped it. A `play(url:)` releases its new module instead.
  /// Either waits for the brake when it comes early.
  @MainActor public func vinylStop() {
    guard isRunning, currentURL != nil, !vinylStopping, !vinylHeld else { return }
    vinylStopping = true
    let ramp = vinylRamp ?? VinylRamp()
    vinylRamp = ramp
    ramp.run(.stop, apply: { [weak self] rate, gain in self?.applyVinyl(rate: rate, gain: gain) }) { [weak self] in
      guard let self else { return }
      self.vinylStopping = false
      let release = self.vinylReleaseRequested
      self.vinylReleaseRequested = false
      if let pending = self.vinylPending {
        self.vinylPending = nil
        self.load(pending.module, url: pending.url)
        self.vinylStart()
      } else if release {
        self.vinylStart()
      } else {
        self.vinylHeld = true
      }
    }
  }

  /// Lets a braked record run on from the finger hold.
  @MainActor public func vinylRelease() {
    if vinylStopping { vinylReleaseRequested = true; return }
    guard vinylHeld else { return }
    vinylHeld = false
    vinylStart()
  }

  @MainActor private func vinylStart() {
    lock.lock()
    startFadeFrames = 0
    lock.unlock()
    let ramp = vinylRamp ?? VinylRamp()
    vinylRamp = ramp
    ramp.run(.start, apply: { [weak self] rate, gain in self?.applyVinyl(rate: rate, gain: gain) }) { [weak self] in
      self?.applyVinyl(rate: 1, gain: 1)
    }
  }

  private func resetVinyl() {
    if Thread.isMainThread { MainActor.assumeIsolated { vinylRamp?.cancel() } }
    vinylStopping = false
    vinylHeld = false
    vinylPending = nil
    vinylReleaseRequested = false
    applyVinyl(rate: 1, gain: 1)
  }

  public func cancelRewind() {
    rewindAudio.cancel()
    spatialMixer.outputVolume = muted || volume == 0 ? 0 : 1
    if Thread.isMainThread {
      MainActor.assumeIsolated { rewindTask?.cancel(); rewindTask = nil }
    }
  }

  /// Scratches recent mixed tracker samples without replaying the tracker on the UI thread.
  @MainActor public func playRewind() {
    let queuedFrames = min(bufferedFrameCount * bufferCount, Int(bufferedSeconds * sampleRate))
    // A parked player has no render clock. Retain the queue offset measured
    // before the pause instead of treating its whole lifetime as queued audio.
    let skip = lock.withLock { outputSuspended ? rewindBufferedFrames : queuedFrames }
    guard isRunning, !muted, volume > 0,
      rewindAudio.trigger(skipping: skip) else { return }
    spatialMixer.outputVolume = 0
    do { if !engine.isRunning { try engine.start() } }
    catch { rewindAudio.cancel(); spatialMixer.outputVolume = muted ? 0 : 1; return }
    rewindTask?.cancel()
    rewindTask = Task { @MainActor [weak self] in
      do { try await Task.sleep(nanoseconds: 200_000_000) } catch { return }
      guard let self else { return }
      self.rewindAudio.cancel()
      self.spatialMixer.outputVolume = self.muted ? 0 : 1
      let park = self.lock.withLock { self.outputSuspended && self.pauseFadeFrames == 0 }
      if park { self.engine.pause() }
      self.rewindTask = nil
    }
  }

  // MARK: - Controls

  /// Sets the output level, from silent to full.
  public func setVolume(_ value: Double) {
    lock.lock()
    level = min(1, max(0, value))
    rewindAudio.setGain(Float(level))
    lock.unlock()
    if value <= 0 { cancelRewind() }
    else if !rewindAudio.isRewinding { spatialMixer.outputVolume = muted ? 0 : 1 }
  }

  /// Tracker beat timing, including tempo commands on the opening row.
  public var beatInfo: (bpm: Double, delay: Double)? {
    let buffered = bufferedSeconds
    lock.lock(); defer { lock.unlock() }
    guard let player else { return nil }
    var clock = player.player
    if !isRunning {
      _ = clock.nextSample()
      return (clock.musicalBPM * tempoScale, 0)
    }
    let bpm = clock.musicalBPM * tempoScale
    let delay = (clock.secondsUntilNextBeat / tempoScale + buffered).truncatingRemainder(dividingBy: 60 / bpm)
    return (bpm, delay)
  }
  public var sourceSeconds: Double {
    let buffered = bufferedSeconds
    lock.lock(); defer { lock.unlock() }
    return max(0, Double(sourceFrames) / sampleRate - buffered * tempoScale)
  }
  /// Independent of the DJ bass swap and the user's normal music mix.
  public func setNukeAmount(_ value: Float) {
    nukeFilterAmount = value.isFinite ? min(1, max(0, value)) : 0
    NukeMusicFilter.apply(nukeFilterAmount, to: nukeEQ)
  }

  public func setMixBass(_ gain: Float) { mixEQ.bands[0].gain = gain }

  /// Gameplay supplies a smoothed pitch in cents. Keep the tracker clock unchanged.
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

  /// Sets module playback rate independently of the game clock.
  public func setTempoScale(_ value: Double) {
    lock.lock()
    tempoScale = min(1.08, max(0.5, value))
    lock.unlock()
  }

  public func setMuted(_ muted: Bool) {
    lock.lock()
    isMuted = muted
    if muted { rewindAudio.cancel() }
    lock.unlock()
    // Silence already queued samples and the effect tail immediately.
    spatialMixer.outputVolume = muted || volume == 0 || rewindAudio.isRewinding ? 0 : 1
  }

  public var muted: Bool {
    lock.lock()
    defer { lock.unlock() }
    return isMuted
  }

  public var volume: Double {
    lock.lock()
    defer { lock.unlock() }
    return level
  }

  /// Applies new processing without restarting the tune or its beat clock.
  public func setEnhancements(_ value: ProTrackerEnhancements) {
    lock.lock()
    guard enhancements != value else { lock.unlock(); return }
    enhancements = value
    player = player?.replacingEnhancements(value)
    lock.unlock()
  }

  public var usesModernPreset: Bool {
    lock.lock()
    defer { lock.unlock() }
    return !enhancements.isFaithful
  }
}
