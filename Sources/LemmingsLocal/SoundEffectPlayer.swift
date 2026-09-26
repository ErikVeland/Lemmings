import AVFoundation
import Foundation
import NxlvKit

/// Plays effects through a fixed pool of spatial mono sources.
/// Nodes remain attached during play to avoid graph changes between effects.
final class SoundEffectPlayer: @unchecked Sendable {
  private struct Voice {
    var samples: [Float] = []
    var position: Double = 0
    var increment: Double = 1
    var isActive = false
  }

  var onPlay: (@Sendable ([Float], Double, Float) -> Void)?
  private let engine = AVAudioEngine()
  private let environment = AVAudioEnvironmentNode()
  private var sourceNodes: [AVAudioSourceNode] = []
  private var spatialMixers: [AVAudioMixerNode] = []
  private let lock = NSLock()

  // Guarded by `lock`.
  private var library: [ClassicSoundEffect: [Float]] = [:]
  private var rates: [ClassicSoundEffect: Double] = [:]
  private var voices: [Voice]
  private var isMuted = false
  private var level: Double = 1.0
  private let recentSampleLimit = 44_100
  private var recentSamples: [Float]
  private var recentSamplePositions: [Int64]
  private var latestRecentSample: Int64?

  private let sampleRate = 44100.0
  private(set) var isRunning = false
  private(set) var loadedEffects: [ClassicSoundEffect] = []

  init(voiceCount: Int = 16) {
    voices = [Voice](repeating: Voice(), count: max(1, voiceCount))
    recentSamples = [Float](repeating: 0, count: recentSampleLimit)
    recentSamplePositions = [Int64](repeating: .min, count: recentSampleLimit)
    // A short builder-like chink is available even in previews without a bank.
    library[.builderWarning] = (0..<3528).map { i in
      let t = Double(i) / 44100
      return Float(sin(2 * .pi * 1320 * t) * exp(-t * 65) * 0.45)
    }
    rates[.builderWarning] = 44100
  }

  // MARK: - Engine

  func start() throws {
    guard !isRunning else { return }
    let mono = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    let stereo = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
    engine.attach(environment)
    environment.outputType = .auto
    environment.distanceAttenuationParameters.rolloffFactor = 0
    environment.reverbParameters.enable = false
    engine.connect(environment, to: engine.mainMixerNode, format: stereo)
    for index in voices.indices {
      let mixer = AVAudioMixerNode()
      let node = AVAudioSourceNode(format: mono) { [weak self] _, timestamp, frameCount, buffers in
        let list = UnsafeMutableAudioBufferListPointer(buffers)
        guard let self else {
          for buffer in list { memset(buffer.mData, 0, Int(buffer.mDataByteSize)) }
          return noErr
        }
        self.fillVoice(index, buffers: list, frames: Int(frameCount), sampleTime: timestamp.pointee.mSampleTime)
        return noErr
      }
      engine.attach(node)
      engine.attach(mixer)
      engine.connect(node, to: mixer, format: mono)
      engine.connect(mixer, to: environment, fromBus: 0, toBus: AVAudioNodeBus(index), format: mono)
      mixer.renderingAlgorithm = .auto
      mixer.sourceMode = .pointSource
      mixer.position = AVAudio3DPoint(x: 0, y: 0, z: -1)
      sourceNodes.append(node)
      spatialMixers.append(mixer)
    }
    do { try engine.start() }
    catch { detachSources(); throw error }
    isRunning = true
  }

  private func detachSources() {
    for node in sourceNodes { engine.detach(node) }
    for mixer in spatialMixers { engine.detach(mixer) }
    engine.detach(environment)
    sourceNodes = []
    spatialMixers = []
  }

  func stop() {
    guard isRunning else { return }
    engine.stop()
    detachSources()
    silence()
    isRunning = false
  }

  func suspendOutput() { if isRunning { engine.pause() } }

  func resumeOutput() throws {
    if isRunning && !engine.isRunning { try engine.start() }
  }

  private func fillVoice(_ index: Int, buffers: UnsafeMutableAudioBufferListPointer, frames: Int, sampleTime: Double) {
    lock.lock()
    defer { lock.unlock() }
    var voice = voices[index]
    let start = sampleTime.isFinite && sampleTime >= 0
      ? Int64(sampleTime.rounded())
      : (latestRecentSample.map { $0 + 1 } ?? 0)
    for frame in 0..<frames {
      var sample: Float = 0
      var sourceSample: Float = 0
      if !isMuted && voice.isActive {
        let position = Int(voice.position)
        if position < voice.samples.count {
          sourceSample = voice.samples[position]
          sample = sourceSample * Float(level) * 0.6
          voice.position += voice.increment
        } else {
          voice.isActive = false
        }
      }
      for buffer in buffers { buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample }

      let position = start + Int64(frame)
      let slot = Int((position % Int64(recentSampleLimit) + Int64(recentSampleLimit)) % Int64(recentSampleLimit))
      if recentSamplePositions[slot] != position {
        recentSamplePositions[slot] = position
        recentSamples[slot] = 0
      }
      recentSamples[slot] += sourceSample
      latestRecentSample = max(latestRecentSample ?? position, position)
    }
    voices[index] = voice
  }

  // MARK: - Library

  /// Loads effects from a Macintosh disk image.
  ///
  /// The Mac release names its sounds, so the binding is by name rather than
  /// by position, and each sound keeps the rate its resource records. The Mac
  /// disk has no sound for some events. A named Amiga sample fills each gap,
  /// then a supplied sound named after the event.
  @discardableResult
  func loadMacintoshSounds(imageURL: URL, amigaFallbackDirectory: URL? = nil,
                           supplementDirectory: URL? = nil) throws -> [ClassicSoundEffect] {
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
    if let amigaFallbackDirectory {
      // A missing or damaged Amiga bank leaves these gaps silent, as before.
      let amiga = (try? Self.amigaSounds(in: amigaFallbackDirectory)) ?? [:]
      for (effect, name) in ClassicSoundMapping.amigaVoiceNames where library[effect] == nil {
        guard let sound = amiga[name.lowercased()] else { continue }
        library[effect] = sound.samples
        rates[effect] = sound.sampleRate
      }
    }
    fillFromSupplementLocked(supplementDirectory)
    let loaded = library.keys.sorted { $0.rawValue < $1.rawValue }
    lock.unlock()

    loadedEffects = loaded
    return loaded
  }

  /// Fills each still-silent event from a sound file named after it, such as
  /// `yippee.mp3`. Neither the Mac disk nor the Amiga banks has a Yippee.
  private func fillFromSupplementLocked(_ directory: URL?) {
    guard let directory else { return }
    for effect in ClassicSoundEffect.allCases where library[effect] == nil {
      for ext in ["wav", "m4a", "mp3"] {
        let url = directory.appendingPathComponent(effect.rawValue).appendingPathExtension(ext)
        guard let decoded = Self.monoSamples(url) else { continue }
        library[effect] = decoded.samples
        rates[effect] = decoded.rate
        break
      }
    }
  }

  /// Decodes a sound file to mono samples at its own rate.
  private static func monoSamples(_ url: URL) -> (samples: [Float], rate: Double)? {
    guard let file = try? AVAudioFile(forReading: url), file.length > 0,
          let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
          (try? file.read(into: buffer)) != nil, let channels = buffer.floatChannelData else { return nil }
    let count = Int(buffer.frameLength), channelCount = Int(buffer.format.channelCount)
    guard count > 0, channelCount > 0 else { return nil }
    var samples = [Float](repeating: 0, count: count)
    for channel in 0..<channelCount {
      for index in 0..<count { samples[index] += channels[channel][index] / Float(channelCount) }
    }
    return (samples, file.processingFormat.sampleRate)
  }

  /// Loads the Amiga digitised sounds from the two banks on the game disk.
  ///
  /// `basicfx` holds the voices and the common effects. `fullfx` holds the
  /// trap sounds. Names are matched without case, because the banks mix
  /// `Splat` with `chink`. Sounds whose name is empty are skipped: nothing
  /// says which effect they belong to, and binding them to a guess would play
  /// the wrong sound rather than none.
  @discardableResult
  func loadAmigaSounds(directory: URL, deathFallbackImage: URL? = nil,
                       supplementDirectory: URL? = nil) throws -> [ClassicSoundEffect] {
    // The Amiga death sample is unnamed. Use the identified Macintosh voice.
    var death: ClassicMacSound?
    if let image = deathFallbackImage {
      let volume = try ClassicHFSVolume(image: Data(contentsOf: image, options: .mappedIfSafe))
      death = ClassicMacSoundDecoder.sounds(in: try volume.resourceFork(named: "Lemmings")).first { $0.name == "Die" }
    }
    let byName = try Self.amigaSounds(in: directory)

    lock.lock()
    library = [:]
    rates = [:]
    if let death { library[.fallOut] = death.floatSamples(); rates[.fallOut] = death.sampleRate }
    for (effect, name) in ClassicSoundMapping.amigaVoiceNames {
      guard let sound = byName[name.lowercased()] else { continue }
      library[effect] = sound.samples
      rates[effect] = sound.sampleRate
    }
    fillFromSupplementLocked(supplementDirectory)
    let loaded = library.keys.sorted { $0.rawValue < $1.rawValue }
    lock.unlock()

    loadedEffects = loaded
    return loaded
  }

  /// The named samples in the two Amiga banks, keyed by lower-case name.
  private static func amigaSounds(in directory: URL) throws -> [String: AmigaSound] {
    var byName: [String: AmigaSound] = [:]
    for bank in ["basicfx", "fullfx"] {
      let url = directory.appendingPathComponent(bank)
      guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { continue }
      for sound in try AmigaSoundBank.decode(data) {
        guard let name = sound.name else { continue }
        byName[name.lowercased()] = sound
      }
    }
    return byName
  }

  // MARK: - Playing

  /// Keep the countdown warning while installing the sequel's named voices.
  func loadLemmings3Sounds(root: URL) throws {
    let bank = try Lemmings3SoundBank(root: root)
    lock.lock()
    defer { lock.unlock() }
    for (effect, clip) in bank.clips {
      library[effect] = clip.samples
      rates[effect] = clip.sampleRate
    }
    loadedEffects = library.keys.sorted { $0.rawValue < $1.rawValue }
  }

  func silence() {
    lock.lock()
    defer { lock.unlock() }
    for index in voices.indices { voices[index].isActive = false }
  }

  /// Plays a short reversed slice of recent effects while the run is scrubbed.
  /// This gives rewind the character of a tape transport without changing the
  /// original effect samples or adding a new game sound.
  func playRewindScrub() {
    lock.lock()
    defer { lock.unlock() }
    guard !isMuted, let latest = latestRecentSample else { return }
    var samples: [Float] = []
    samples.reserveCapacity(11_025)
    for offset in 0..<11_025 {
      let position = latest - Int64(offset)
      let slot = Int((position % Int64(recentSampleLimit) + Int64(recentSampleLimit)) % Int64(recentSampleLimit))
      guard recentSamplePositions[slot] == position else { break }
      samples.append(recentSamples[slot])
    }
    guard !samples.isEmpty else { return }
    let index = voices.firstIndex { !$0.isActive } ?? voices.startIndex
    voices[index] = Voice(samples: samples, position: 0, increment: 1, isActive: true)
  }

  /// Turns a stereo position into a pair of channel gains.
  ///
  /// A pan of -1 is hard left, 0 is centre, and +1 is hard right. Values
  /// outside that range are brought back into it.
  static func constantPowerGains(pan: Float) -> (left: Float, right: Float) {
    let clamped = max(-1, min(1, pan))
    let angle = (clamped + 1) * Float.pi / 4
    return (cos(angle), sin(angle))
  }

  /// Places an effect across the sound stage (-1.0 left to +1.0 right).
  private var bottomFallSounds = true

  func setBottomFallSounds(_ enabled: Bool) {
    lock.lock(); defer { lock.unlock() }; bottomFallSounds = enabled
  }

  func play(_ effect: ClassicSoundEffect, pan: Float = 0.0) {
    lock.lock()
    defer { lock.unlock() }
    guard effect != .fallOut || bottomFallSounds else { return }
    guard !isMuted, let samples = library[effect], !samples.isEmpty else { return }
    let rate = rates[effect] ?? sampleRate
    onPlay?(samples, rate, Float(level) * 0.6)
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
    let clampedPan = pan.isFinite ? max(-1, min(1, pan)) : 0
    if spatialMixers.indices.contains(index) {
      let angle = clampedPan * Float.pi / 3
      spatialMixers[index].position = AVAudio3DPoint(x: sin(angle), y: 0, z: -cos(angle))
    }
    voices[index] = Voice(
      samples: samples, position: 0, increment: rate / sampleRate, isActive: true)
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

  var volume: Double {
    lock.lock()
    defer { lock.unlock() }
    return level
  }
}
