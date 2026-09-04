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
  private var sourceNode: AVAudioSourceNode?
  private let lock = NSLock()

  // Guarded by `lock`.
  private var player: ProTrackerEnhancedPlayer?
  private var enhancements: ProTrackerEnhancements = .faithful
  private var isMuted = false
  private var level: Double = 1.0

  private let sampleRate = 44100.0
  private(set) var isRunning = false
  private(set) var currentTitle: String?

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
    engine.connect(node, to: engine.mainMixerNode, format: format)
    sourceNode = node
    try engine.start()
    isRunning = true
  }

  func stop() {
    guard isRunning else { return }
    engine.stop()
    if let sourceNode { engine.detach(sourceNode) }
    sourceNode = nil
    isRunning = false
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

    for index in 0..<frames {
      let frame = player!.nextFrame()
      left?[index] = frame.left * Float(level)
      right?[index] = frame.right * Float(level)
      // A module ends by running off its order list. Loop it, as the game does.
      if player!.hasFinished { restartLocked() }
    }
  }

  private var loadedModule: ProTrackerModule?

  private func restartLocked() {
    guard let module = loadedModule else { return }
    player = ProTrackerEnhancedPlayer(
      module: module, sampleRate: sampleRate, enhancements: enhancements)
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
    guard let data = try? Data(contentsOf: url),
      let module = try? ProTrackerModule(data: data)
    else { return nil }

    lock.lock()
    loadedModule = module
    player = ProTrackerEnhancedPlayer(
      module: module, sampleRate: sampleRate, enhancements: enhancements)
    lock.unlock()

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

  /// Applies new processing, keeping the tune playing from the start.
  func setEnhancements(_ value: ProTrackerEnhancements) {
    lock.lock()
    enhancements = value
    if let module = loadedModule {
      player = ProTrackerEnhancedPlayer(
        module: module, sampleRate: sampleRate, enhancements: value)
    }
    lock.unlock()
  }

  var usesModernPreset: Bool {
    lock.lock()
    defer { lock.unlock() }
    return !enhancements.isFaithful
  }
}
