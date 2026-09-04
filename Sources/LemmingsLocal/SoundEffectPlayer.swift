import AVFoundation
import Foundation
import NxlvKit

/// Plays one-shot sound effects.
///
/// A fixed pool of voices mixes in one render callback rather than attaching a
/// player node per sound. Attaching and detaching nodes during play is the
/// usual source of clicks and stalls in this kind of engine.
///
/// Sounds arrive already decoded, each with the rate its own resource records,
/// so playback resamples per voice instead of assuming one rate for the set.
final class SoundEffectPlayer: @unchecked Sendable {
  private struct Voice {
    var samples: [Float] = []
    var position: Double = 0
    var increment: Double = 1
    var isActive = false
  }

  private let engine = AVAudioEngine()
  private var sourceNode: AVAudioSourceNode?
  private let lock = NSLock()

  // Guarded by `lock`.
  private var library: [ClassicSoundEffect: [Float]] = [:]
  private var rates: [ClassicSoundEffect: Double] = [:]
  private var voices: [Voice]
  private var isMuted = false
  private var level: Double = 1.0

  private let sampleRate = 44100.0
  private(set) var isRunning = false
  private(set) var loadedEffects: [ClassicSoundEffect] = []

  init(voiceCount: Int = 8) {
    voices = [Voice](repeating: Voice(), count: max(1, voiceCount))
  }

  // MARK: - Engine

  func start() throws {
    guard !isRunning else { return }
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
    let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, buffers in
      let list = UnsafeMutableAudioBufferListPointer(buffers)
      guard let self else {
        for buffer in list { memset(buffer.mData, 0, Int(buffer.mDataByteSize)) }
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

    for index in 0..<frames {
      var mix: Float = 0
      if !isMuted {
        for voiceIndex in voices.indices where voices[voiceIndex].isActive {
          var voice = voices[voiceIndex]
          let position = Int(voice.position)
          if position >= voice.samples.count {
            voice.isActive = false
            voices[voiceIndex] = voice
            continue
          }
          mix += voice.samples[position]
          voice.position += voice.increment
          voices[voiceIndex] = voice
        }
      }
      // Several effects can overlap, so leave headroom rather than clip.
      let value = max(-1, min(1, mix * 0.6 * Float(level)))
      left?[index] = value
      right?[index] = value
    }
  }

  // MARK: - Library

  /// Loads effects from a Macintosh disk image.
  ///
  /// The Mac release names its sounds, so the binding is by name rather than
  /// by position, and each sound keeps the rate its resource records.
  @discardableResult
  func loadMacintoshSounds(imageURL: URL) throws -> [ClassicSoundEffect] {
    let image = try Data(contentsOf: imageURL, options: .mappedIfSafe)
    let volume = try ClassicHFSVolume(image: image)
    let fork = try volume.resourceFork(named: "Lemmings")
    let sounds = ClassicMacSoundDecoder.sounds(in: fork)

    var byName: [String: ClassicMacSound] = [:]
    for sound in sounds {
      if let name = sound.name { byName[name] = sound }
    }

    lock.lock()
    library = [:]
    rates = [:]
    for (effect, name) in ClassicSoundMapping.macintoshNames {
      guard let sound = byName[name] else { continue }
      library[effect] = sound.floatSamples()
      rates[effect] = sound.sampleRate
    }
    let loaded = library.keys.sorted { $0.rawValue < $1.rawValue }
    lock.unlock()

    loadedEffects = loaded
    return loaded
  }

  // MARK: - Playing

  /// Starts an effect, taking the quietest voice when all are busy.
  func play(_ effect: ClassicSoundEffect) {
    lock.lock()
    defer { lock.unlock() }
    guard !isMuted, let samples = library[effect], !samples.isEmpty else { return }
    let rate = rates[effect] ?? sampleRate

    var slot = voices.firstIndex { !$0.isActive }
    if slot == nil {
      // Steal the voice closest to finishing, which is least noticeable.
      slot = voices.indices.max {
        let a = voices[$0].samples.count - Int(voices[$0].position)
        let b = voices[$1].samples.count - Int(voices[$1].position)
        return a > b
      }
    }
    guard let index = slot else { return }
    voices[index] = Voice(
      samples: samples, position: 0, increment: rate / sampleRate, isActive: true)
  }

  func play(_ effects: [ClassicSoundEffect]) {
    for effect in effects { play(effect) }
  }

  /// Sets the output level, from silent to full.
  func setVolume(_ value: Double) {
    lock.lock()
    level = min(1, max(0, value))
    lock.unlock()
  }

  func setMuted(_ muted: Bool) {
    lock.lock()
    isMuted = muted
    if muted { for index in voices.indices { voices[index].isActive = false } }
    lock.unlock()
  }

  var muted: Bool {
    lock.lock()
    defer { lock.unlock() }
    return isMuted
  }
}
