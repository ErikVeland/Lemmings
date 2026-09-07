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
    /// Channel gains for this voice, worked out once when it starts.
    ///
    /// Panning is constant power: the two gains are a cosine and a sine of the
    /// same angle, so their squares sum to one and a sound keeps its loudness
    /// as it moves across the stereo field. The trigonometry belongs here, not
    /// in the render loop, because the angle cannot change while a voice runs.
    var leftGain: Float = 1
    var rightGain: Float = 1
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

  init(voiceCount: Int = 16) {
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
      var mixLeft: Float = 0
      var mixRight: Float = 0
      if !isMuted {
        for voiceIndex in voices.indices where voices[voiceIndex].isActive {
          var voice = voices[voiceIndex]
          let position = Int(voice.position)
          if position >= voice.samples.count {
            voice.isActive = false
            voices[voiceIndex] = voice
            continue
          }
          let rawSample = voice.samples[position]
          mixLeft += rawSample * voice.leftGain
          mixRight += rawSample * voice.rightGain
          voice.position += voice.increment
          voices[voiceIndex] = voice
        }
      }
      let finalLevel = Float(level) * 0.6
      left?[index] = max(-1, min(1, mixLeft * finalLevel))
      right?[index] = max(-1, min(1, mixRight * finalLevel))
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

  /// Loads the Amiga digitised sounds from the two banks on the game disk.
  ///
  /// `basicfx` holds the voices and the common effects. `fullfx` holds the
  /// trap sounds. Names are matched without case, because the banks mix
  /// `Splat` with `chink`. Sounds whose name is empty are skipped: nothing
  /// says which effect they belong to, and binding them to a guess would play
  /// the wrong sound rather than none.
  @discardableResult
  func loadAmigaSounds(directory: URL) throws -> [ClassicSoundEffect] {
    var byName: [String: AmigaSound] = [:]
    for bank in ["basicfx", "fullfx"] {
      let url = directory.appendingPathComponent(bank)
      guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { continue }
      for sound in try AmigaSoundBank.decode(data) {
        guard let name = sound.name else { continue }
        byName[name.lowercased()] = sound
      }
    }

    lock.lock()
    library = [:]
    rates = [:]
    for (effect, name) in ClassicSoundMapping.amigaVoiceNames {
      guard let sound = byName[name.lowercased()] else { continue }
      library[effect] = sound.samples
      rates[effect] = sound.sampleRate
    }
    let loaded = library.keys.sorted { $0.rawValue < $1.rawValue }
    lock.unlock()

    loadedEffects = loaded
    return loaded
  }

  // MARK: - Playing

  /// Turns a stereo position into a pair of channel gains.
  ///
  /// A pan of -1 is hard left, 0 is centre, and +1 is hard right. Values
  /// outside that range are brought back into it.
  static func constantPowerGains(pan: Float) -> (left: Float, right: Float) {
    let clamped = max(-1, min(1, pan))
    let angle = (clamped + 1) * Float.pi / 4
    return (cos(angle), sin(angle))
  }

  /// Starts an effect with optional spatial stereo panning (-1.0 left to +1.0 right).
  func play(_ effect: ClassicSoundEffect, pan: Float = 0.0) {
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
    let gains = Self.constantPowerGains(pan: pan)
    voices[index] = Voice(
      samples: samples, position: 0, increment: rate / sampleRate,
      leftGain: gains.left, rightGain: gains.right, isActive: true)
  }

  func play(_ effects: [ClassicSoundEffect], pan: Float = 0.0) {
    for effect in effects { play(effect, pan: pan) }
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
