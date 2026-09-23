import AVFoundation
import Foundation
import NxlvKit

/// Plays ProTracker modules through the system audio output.
///
/// The render callback runs on the audio thread. All shared state sits behind
/// one lock, and the callback holds it for the whole fill. Loading a module is
/// rare and brief, so the two rarely contend. A real-time safe handoff would
/// swap buffers without locking, which is worth doing if this ever glitches.
final class ModuleMusicPlayer: @unchecked Sendable {
  private let engine = AVAudioEngine()
  private let reverb = AVAudioUnitReverb()
  private let spatialMixer = AVAudioMixerNode()
  private var sourceNode: AVAudioSourceNode?
  private let lock = NSLock()

  // Guarded by `lock`.
  private var player: ProTrackerEnhancedPlayer?
  private var enhancements: ProTrackerEnhancements = .faithful
  private var isMuted = false
  private var level: Double = 1.0
  private var tempoScale = 1.0
  private var interpolationPhase = 1.0
  private var currentFrame: (left: Float, right: Float) = (0, 0)
  private var nextFrame: (left: Float, right: Float) = (0, 0)
  private var outputSuspended = false
  private var pauseFadeFrames = 0
  private var startFadeFrames = 0
  private var pauseWorkItem: DispatchWorkItem?

  private let loopCrossfadeFrames = 2048
  private var loopTail = [(left: Float, right: Float)](
    repeating: (left: 0, right: 0), count: 2048)
  private var loopTailWriteIndex = 0
  private var loopTailCount = 0
  private var previousLoopTail: [(left: Float, right: Float)] = []
  private var loopBlendIndex: Int?

  private let sampleRate = 44100.0
  private(set) var isRunning = false
  var isOutputRunning: Bool {
    lock.lock()
    defer { lock.unlock() }
    return isRunning && !outputSuspended
  }
  private(set) var currentTitle: String?
  private(set) var currentURL: URL?

  /// Modules found in the chosen directory, sorted by name.
  private(set) var library: [URL] = []

  // MARK: - Engine

  func start() throws {
    guard !isRunning else { return }
    let format = AVAudioFormat(
      standardFormatWithSampleRate: sampleRate, channels: 2)!

    let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, buffers in
      let list = UnsafeMutableAudioBufferListPointer(buffers)
      guard let self else {
        for buffer in list {
          memset(buffer.mData, 0, Int(buffer.mDataByteSize))
        }
        return noErr
      }
      self.fill(list, frames: Int(frameCount))
      return noErr
    }

    engine.attach(node)
    engine.attach(reverb)
    engine.attach(spatialMixer)
    reverb.loadFactoryPreset(.mediumRoom)
    reverb.wetDryMix = 0
    spatialMixer.renderingAlgorithm = .auto
    spatialMixer.sourceMode = .pointSource
    spatialMixer.position = AVAudio3DPoint(x: 0, y: 0, z: -1)
    engine.connect(node, to: reverb, format: format)
    engine.connect(reverb, to: spatialMixer, format: format)
    engine.connect(spatialMixer, to: engine.mainMixerNode, format: format)
    sourceNode = node
    do {
      try engine.start()
    } catch {
      engine.detach(node)
      engine.detach(spatialMixer)
      engine.detach(reverb)
      sourceNode = nil
      throw error
    }
    lock.lock()
    outputSuspended = false
    lock.unlock()
    isRunning = true
  }

  func stop() {
    guard isRunning else { return }
    pauseWorkItem?.cancel()
    pauseWorkItem = nil
    engine.stop()
    if let sourceNode { engine.detach(sourceNode) }
    engine.detach(spatialMixer)
    engine.detach(reverb)
    sourceNode = nil
    lock.lock()
    outputSuspended = false
    pauseFadeFrames = 0
    startFadeFrames = 0
    lock.unlock()
    isRunning = false
  }

  /// Cuts the module quickly, then leaves a short room tail before pausing.
  func suspendOutput() {
    guard isRunning else { return }
    lock.lock()
    guard !outputSuspended else { lock.unlock(); return }
    outputSuspended = true
    pauseFadeFrames = Int(sampleRate * 0.035)
    lock.unlock()
    reverb.wetDryMix = 14
    pauseWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
      guard let self else { return }
      self.lock.lock()
      let shouldPause = self.outputSuspended
      self.lock.unlock()
      if shouldPause { self.engine.pause() }
    }
    pauseWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
  }

  func resumeOutput() throws {
    guard isRunning else { return }
    pauseWorkItem?.cancel()
    pauseWorkItem = nil
    lock.lock()
    outputSuspended = false
    pauseFadeFrames = 0
    startFadeFrames = 0
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

    if interpolationPhase >= 1 {
      currentFrame = nextSourceFrameLocked()
      nextFrame = nextSourceFrameLocked()
      interpolationPhase = 0
    }
    for index in 0..<frames {
      let canAdvance = pauseFadeFrames > 0 || !outputSuspended
      if outputSuspended && pauseFadeFrames > 0 { pauseFadeFrames -= 1 }
      let gain = outputSuspended
        ? Float(pauseFadeFrames) / Float(max(1, Int(sampleRate * 0.035)))
        : startFadeGainLocked()

      let frame: (left: Float, right: Float)
      if canAdvance {
        let blend = Float(interpolationPhase)
        frame = (
          left: currentFrame.left + (nextFrame.left - currentFrame.left) * blend,
          right: currentFrame.right + (nextFrame.right - currentFrame.right) * blend)
        interpolationPhase += tempoScale
        while interpolationPhase >= 1 {
          currentFrame = nextFrame
          nextFrame = nextSourceFrameLocked()
          interpolationPhase -= 1
        }
      } else {
        frame = (left: 0, right: 0)
      }
      left?[index] = frame.left * Float(level) * gain
      right?[index] = frame.right * Float(level) * gain
    }
  }

  private func startFadeGainLocked() -> Float {
    guard startFadeFrames > 0 else { return 1 }
    startFadeFrames -= 1
    return 1 - Float(startFadeFrames) / Float(max(1, Int(sampleRate * 0.14)))
  }

  private func nextSourceFrameLocked() -> (left: Float, right: Float) {
    let raw = player!.nextFrame()
    let frame: (left: Float, right: Float)
    if let blendIndex = loopBlendIndex, blendIndex < previousLoopTail.count {
      let amount = Float(blendIndex + 1) / Float(previousLoopTail.count)
      let tail = previousLoopTail[blendIndex]
      let outgoingGain = cos(amount * .pi / 2)
      let incomingGain = sin(amount * .pi / 2)
      frame = (
        left: tail.left * outgoingGain + raw.left * incomingGain,
        right: tail.right * outgoingGain + raw.right * incomingGain)
      loopBlendIndex = blendIndex + 1 < previousLoopTail.count ? blendIndex + 1 : nil
    } else {
      frame = raw
    }

    loopTail[loopTailWriteIndex] = raw
    loopTailWriteIndex = (loopTailWriteIndex + 1) % loopTail.count
    loopTailCount = min(loopTail.count, loopTailCount + 1)

    // A short equal-power overlap hides the order-list boundary without
    // changing the module clock or its pattern data.
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
    interpolationPhase = 1
  }

  // MARK: - Library

  /// Collects every module under a directory, including subfolders.
  func loadLibrary(at root: URL) {
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
  func play(index: Int) -> String? {
    guard !library.isEmpty else { return nil }
    let url = library[((index % library.count) + library.count) % library.count]
    return play(url: url)
  }

  @discardableResult
  func play(url: URL) -> String? {
    guard let data = try? Data(contentsOf: url),
      let module = try? ProTrackerModule(data: data)
    else { return nil }

    lock.lock()
    loadedModule = module
    player = ProTrackerEnhancedPlayer(
      module: module, sampleRate: sampleRate, enhancements: enhancements)
    interpolationPhase = 1
    loopTail = [(left: 0, right: 0)](repeating: (left: 0, right: 0), count: loopCrossfadeFrames)
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
    return currentTitle
  }

  // MARK: - Controls

  /// Sets the output level, from silent to full.
  func setVolume(_ value: Double) {
    lock.lock()
    level = min(1, max(0, value))
    lock.unlock()
  }

  /// Slows module playback without changing the game clock or pitch abruptly.
  func setTempoScale(_ value: Double) {
    lock.lock()
    tempoScale = min(1, max(0.5, value))
    lock.unlock()
  }

  func setMuted(_ muted: Bool) {
    lock.lock()
    isMuted = muted
    lock.unlock()
  }

  var muted: Bool {
    lock.lock()
    defer { lock.unlock() }
    return isMuted
  }

  var volume: Double {
    lock.lock()
    defer { lock.unlock() }
    return level
  }

  /// Applies new processing, keeping the tune playing from the start.
  func setEnhancements(_ value: ProTrackerEnhancements) {
    lock.lock()
    enhancements = value
    if let module = loadedModule {
      player = ProTrackerEnhancedPlayer(
        module: module, sampleRate: sampleRate, enhancements: value)
      interpolationPhase = 1
    }
    lock.unlock()
  }

  var usesModernPreset: Bool {
    lock.lock()
    defer { lock.unlock() }
    return !enhancements.isFaithful
  }
}
