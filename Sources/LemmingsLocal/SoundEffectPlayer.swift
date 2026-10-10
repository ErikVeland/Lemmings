import AVFoundation
import Foundation
import NxlvKit

/// Plays effects through a fixed pool of spatial mono sources.
/// Nodes remain attached during play to avoid graph changes between effects.
final class SoundEffectPlayer: @unchecked Sendable {
  private struct RescueLayer {
    var samples: [Float]
    var position: Double = 0
    var increment: Double
    var gain: Float
    var worldPoint: GameplaySoundPoint?
    var distanceGain: Float
  }
  private struct Voice {
    var samples: [Float] = []
    var position: Double = 0
    var increment: Double = 1
    var isActive = false
    var worldPoint: GameplaySoundPoint?
    var gain: Float = 0.6
    var distanceGain: Float = 1
    var rewindSequence: UInt64?
    var priority: Int = 1
    var isRescue = false
    var isReleaseRate = false
    var rescueLayers: [RescueLayer] = []
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
  private var gains: [ClassicSoundEffect: Float] = [:]
  private var supplementalEffects = Set<ClassicSoundEffect>()
  private var recentEffectTimes: [String: Double] = [:]
  private var namedSounds: [String: (samples: [Float], rate: Double)] = [:]
  private var releaseRateSound: (samples: [Float], rate: Double)?
  private var lastReleaseRateTime = -Double.infinity
  private var voices: [Voice]
  private var isMuted = false
  private var outputSuspended = false
  private var level: Double = 1.0
  private var viewport = GameplaySoundViewport(x: 0, y: 0, width: 320, height: 160)
  private let recentSampleLimit = 44_100
  private var recentSamples: [Float]
  private var recentSamplePositions: [Int64]
  private var latestRecentSample: Int64?
  private var rewindSequence: UInt64 = 0
  private var rewindRenderStart: Int64?
  private var rewindRenderFrames = 0
  private var rewindRenderCount = 0
  private var rewindRenderedVoices: [Bool]

  private let sampleRate = 44100.0
  private(set) var isRunning = false
  private(set) var loadedEffects: [ClassicSoundEffect] = []

  init(voiceCount: Int = 64) {
    voices = [Voice](repeating: Voice(), count: max(1, voiceCount))
    rewindRenderedVoices = [Bool](repeating: false, count: max(1, voiceCount))
    recentSamples = [Float](repeating: 0, count: recentSampleLimit)
    recentSamplePositions = [Int64](repeating: .min, count: recentSampleLimit)
    installPresentationSoundsLocked()
  }

  /// Replays share the selected samples and settings, but own their voices and output.
  func replayPlayer() -> SoundEffectPlayer {
    let copy = SoundEffectPlayer()
    lock.lock(); defer { lock.unlock() }
    copy.library = library; copy.rates = rates; copy.gains = gains
    copy.supplementalEffects = supplementalEffects; copy.namedSounds = namedSounds
    copy.releaseRateSound = releaseRateSound
    copy.loadedEffects = loadedEffects
    copy.isMuted = isMuted; copy.level = level; copy.bottomFallSounds = bottomFallSounds
    return copy
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
    lock.lock()
    outputSuspended = false
    lock.unlock()
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
    lock.lock()
    outputSuspended = false
    lock.unlock()
  }

  func suspendOutput() {
    guard isRunning else { return }
    lock.lock()
    outputSuspended = true
    for index in voices.indices {
      voices[index].isActive = false
      voices[index].rescueLayers.removeAll()
    }
    lock.unlock()
    engine.pause()
  }

  func resumeOutput() throws {
    guard isRunning else { return }
    if !engine.isRunning { try engine.start() }
    lock.lock()
    outputSuspended = false
    lock.unlock()
  }

  private func fillVoice(_ index: Int, buffers: UnsafeMutableAudioBufferListPointer, frames: Int, sampleTime: Double) {
    lock.lock()
    defer { lock.unlock() }
    var voice = voices[index]
    let start = sampleTime.isFinite && sampleTime >= 0
      ? Int64(sampleTime.rounded())
      : (latestRecentSample.map { $0 + 1 } ?? 0)
    // Scrub slices may contain the same effects. Share one mix budget across
    // the whole render block, even when an earlier source finishes mid-block.
    if rewindRenderStart != start || rewindRenderFrames != frames || rewindRenderedVoices[index] {
      rewindRenderStart = start
      rewindRenderFrames = frames
      rewindRenderCount = voices.reduce(0) { $0 + ($1.isActive && $1.rewindSequence != nil ? 1 : 0) }
      for index in rewindRenderedVoices.indices { rewindRenderedVoices[index] = false }
    }
    rewindRenderedVoices[index] = true
    let rewindGain: Float = voice.rewindSequence == nil ? 1 : 1 / Float(max(1, rewindRenderCount))
    for frame in 0..<frames {
      var sample: Float = 0
      var sourceSample: Float = 0
      if !isMuted && voice.isActive {
        let position = Int(voice.position)
        if position >= voice.samples.count && voice.rescueLayers.isEmpty { voice.isActive = false }
        if position < voice.samples.count {
          let next = min(position + 1, voice.samples.count - 1)
          sourceSample = voice.samples[position] + (voice.samples[next] - voice.samples[position]) * Float(voice.position - Double(position))
          sample = sourceSample * Float(level) * voice.gain * voice.distanceGain * rewindGain
          voice.position += voice.increment
        }
        for index in voice.rescueLayers.indices {
          let position = Int(voice.rescueLayers[index].position)
          guard position < voice.rescueLayers[index].samples.count else { continue }
          let next = min(position + 1, voice.rescueLayers[index].samples.count - 1)
          let layerSample = voice.rescueLayers[index].samples[position]
            + (voice.rescueLayers[index].samples[next] - voice.rescueLayers[index].samples[position])
            * Float(voice.rescueLayers[index].position - Double(position))
          sourceSample += layerSample
          sample += layerSample * Float(level) * voice.rescueLayers[index].gain * voice.rescueLayers[index].distanceGain
          voice.rescueLayers[index].position += voice.rescueLayers[index].increment
        }
        voice.rescueLayers.removeAll { $0.position >= Double($0.samples.count) }
      }
      for buffer in buffers { buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample }

      // Rewind output must never feed the history it will reverse next.
      guard voice.rewindSequence == nil else { continue }
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
    gains = [:]; supplementalEffects = []
    releaseRateSound = byName["MousePress"].map { ($0.floatSamples(), $0.sampleRate) }
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
    installPresentationSoundsLocked()
    let loaded = library.keys.sorted { $0.rawValue < $1.rawValue }
    lock.unlock()

    loadedEffects = loaded
    return loaded
  }

  /// Fills each still-silent event from a sound file named after it, such as
  /// `yippee.mp3`. Neither the Mac disk nor the Amiga banks has a Yippee.
  private func fillFromSupplementLocked(_ directory: URL?) {
    guard let directory else { return }
    for effect in ClassicSoundEffect.allCases where library[effect] == nil || supplementalEffects.contains(effect) {
      for ext in ["wav", "m4a", "mp3"] {
        let url = directory.appendingPathComponent(effect.rawValue).appendingPathExtension(ext)
        guard let decoded = Self.monoSamples(url) else { continue }
        library[effect] = decoded.samples
        rates[effect] = decoded.rate
        gains[effect] = 0.6
        supplementalEffects.remove(effect)
        break
      }
    }
  }

  private func installPresentationSoundsLocked() {
    for effect in ClassicSoundEffect.allCases where library[effect] == nil {
      guard let clip = GameplaySupplementSounds.clip(for: effect) else { continue }
      library[effect] = clip.samples; rates[effect] = clip.sampleRate; gains[effect] = clip.gain
      supplementalEffects.insert(effect)
    }
  }

  /// Original voices supplied by the app take precedence over preview effects.
  func loadSupplementSounds(directory: URL?) {
    lock.lock(); defer { lock.unlock() }
    fillFromSupplementLocked(directory)
    installPresentationSoundsLocked()
    loadedEffects = library.keys.sorted { $0.rawValue < $1.rawValue }
  }

  /// Decodes a sound file to mono samples at its own rate.
  private static func monoSamples(_ url: URL) -> (samples: [Float], rate: Double)? {
    guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 16 * 1024 * 1024,
          let file = try? AVAudioFile(forReading: url), file.length > 0, file.length <= 4_000_000,
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
  /// the wrong sound rather than none. The Macintosh recording fills gaps
  /// where the Amiga banks have no named sample.
  @discardableResult
  func loadAmigaSounds(directory: URL, macintoshFallbackImage: URL? = nil,
                       supplementDirectory: URL? = nil) throws -> [ClassicSoundEffect] {
    var macintosh: [String: ClassicMacSound] = [:]
    if let image = macintoshFallbackImage {
      let volume = try ClassicHFSVolume(image: Data(contentsOf: image, options: .mappedIfSafe))
      for sound in ClassicMacSoundDecoder.sounds(in: try volume.resourceFork(named: "Lemmings")) {
        if let name = sound.name { macintosh[name] = sound }
      }
    }
    let byName = try Self.amigaSounds(in: directory)

    lock.lock()
    library = [:]
    rates = [:]
    gains = [:]; supplementalEffects = []
    releaseRateSound = macintosh["MousePress"].map { ($0.floatSamples(), $0.sampleRate) }
    for (effect, name) in ClassicSoundMapping.amigaVoiceNames {
      guard let sound = byName[name.lowercased()] else { continue }
      library[effect] = sound.samples
      rates[effect] = sound.sampleRate
    }
    for (effect, name) in ClassicSoundMapping.macintoshNames where library[effect] == nil {
      guard let sound = macintosh[name] else { continue }
      library[effect] = sound.floatSamples()
      rates[effect] = sound.sampleRate
    }
    fillFromSupplementLocked(supplementDirectory)
    installPresentationSoundsLocked()
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

  /// Load only the current level's named samples. No file IO occurs during a tick.
  /// Player-supplied samples override the original Amiga trap bank.
  func loadNeoLemmixSounds(names: Set<String>, soundDirectory: URL, amigaDirectory: URL?, fallbackSoundDirectory: URL? = nil) {
    var clips: [String: (samples: [Float], rate: Double)] = [:]
    let original = amigaDirectory.flatMap { try? Self.amigaSounds(in: $0) } ?? [:]
    let root = soundDirectory.resolvingSymlinksInPath().standardizedFileURL
    for name in names {
      let key = name.lowercased()
      if let sound = original[key == "tenton" ? "tentonn" : key] { clips[key] = (sound.samples, sound.sampleRate) }
      // NeoLemmix names may contain subdirectories. Reject traversal and symlink escapes.
      guard !name.hasPrefix("/"), !name.contains("\\"),
            !name.split(separator: "/").contains("..") else { continue }
      if let fallbackSoundDirectory {
        for ext in ["ogg", "wav", "aiff", "aif", "mp3", "m4a"] {
          let url = fallbackSoundDirectory.appendingPathComponent(name).appendingPathExtension(ext)
            .resolvingSymlinksInPath().standardizedFileURL
          let fallbackRoot = fallbackSoundDirectory.resolvingSymlinksInPath().standardizedFileURL
          guard url.path.hasPrefix(fallbackRoot.path + "/") else { continue }
          if let decoded = Self.monoSamples(url) { clips[key] = decoded; break }
        }
      }
      for ext in ["ogg", "wav", "aiff", "aif", "mp3", "m4a"] {
        let url = root.appendingPathComponent(name).appendingPathExtension(ext)
          .resolvingSymlinksInPath().standardizedFileURL
        guard url.path.hasPrefix(root.path + "/") else { continue }
        if let decoded = Self.monoSamples(url) { clips[key] = decoded; break }
      }
    }
    lock.lock(); defer { lock.unlock() }
    namedSounds = clips
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
      gains[effect] = 0.6; supplementalEffects.remove(effect)
    }
    loadedEffects = library.keys.sorted { $0.rawValue < $1.rawValue }
  }

  func silence() {
    lock.lock()
    defer { lock.unlock() }
    for index in voices.indices {
      voices[index].isActive = false
      voices[index].rescueLayers.removeAll()
    }
    recentEffectTimes.removeAll(keepingCapacity: true)
  }

  /// Let the final rescue chorus finish as the result page opens.
  func silencePreservingRescues() {
    lock.lock()
    defer { lock.unlock() }
    for index in voices.indices {
      if voices[index].isActive && voices[index].isRescue { continue }
      if voices[index].isActive && !voices[index].rescueLayers.isEmpty {
        voices[index].position = Double(voices[index].samples.count)
      } else {
        voices[index].isActive = false
        voices[index].rescueLayers.removeAll()
      }
    }
    recentEffectTimes.removeAll(keepingCapacity: true)
  }

  /// Plays a short reversed slice of recent effects while the run is scrubbed.
  /// This gives rewind the character of a tape transport without changing the
  /// original effect samples or adding a new game sound.
  func playRewindScrub() {
    lock.lock()
    defer { lock.unlock() }
    guard !isMuted, !outputSuspended, let latest = latestRecentSample else { return }
    var samples: [Float] = []
    samples.reserveCapacity(11_025)
    for offset in 0..<11_025 {
      let position = latest - Int64(offset)
      let slot = Int((position % Int64(recentSampleLimit) + Int64(recentSampleLimit)) % Int64(recentSampleLimit))
      guard recentSamplePositions[slot] == position else { break }
      samples.append(max(-1, min(1, recentSamples[slot])))
    }
    guard !samples.isEmpty else { return }
    let scrubs = voices.indices.filter { voices[$0].isActive && voices[$0].rewindSequence != nil }
    let oldest = scrubs.min { voices[$0].rewindSequence! < voices[$1].rewindSequence! }
    let index = scrubs.count >= 4 ? oldest! :
      (voices.firstIndex { !$0.isActive } ?? oldest ?? voices.startIndex)
    rewindSequence &+= 1
    voices[index] = Voice(samples: samples, position: 0, increment: 1, isActive: true,
      rewindSequence: rewindSequence)
    if spatialMixers.indices.contains(index) { spatialMixers[index].position = AVAudio3DPoint(x: 0, y: 0, z: -1) }
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

  /// Refresh active one-shots as well as the next event when the camera moves.
  func setViewport(_ value: GameplaySoundViewport) {
    lock.lock(); defer { lock.unlock() }
    viewport = value
    for index in voices.indices where voices[index].isActive { placeVoice(index) }
  }

  private func placeVoice(_ index: Int) {
    for layer in voices[index].rescueLayers.indices {
      voices[index].rescueLayers[layer].distanceGain = voices[index].rescueLayers[layer].worldPoint
        .map { viewport.placement(of: $0).gain } ?? 1
    }
    guard let point = voices[index].worldPoint else { return }
    let placement = viewport.placement(of: point)
    voices[index].distanceGain = placement.gain
    if spatialMixers.indices.contains(index) {
      spatialMixers[index].position = AVAudio3DPoint(x: placement.x, y: placement.y, z: placement.z)
    }
  }

  private var nukeActive = false
  private var lastNukeImpact = -Double.infinity
  // A brief downward pitch sweep, with a quiet octave for smaller speakers.
  static let nukeBass: [Float] = (0..<15_435).map { i in
    let t = Double(i) / 44100
    let phase = 2 * Double.pi * (48 * t + 22 * 0.045 * (1 - exp(-t / 0.045)))
    let envelope = min(1, t / 0.012) * exp(-t * 14) * pow(max(0, 1 - t / 0.35), 2)
    return Float((sin(phase) + 0.18 * sin(phase * 2)) * envelope)
  }

  func setNukeActive(_ active: Bool) {
    lock.lock(); defer { lock.unlock() }
    guard active != nukeActive else { return }
    nukeActive = active
    lastNukeImpact = -Double.infinity
    if active {
      playLocked(samples: Self.nukeBass, rate: sampleRate, gain: 0.12, pan: 0, at: nil)
    }
  }

  func playNukeImpact(at point: GameplaySoundPoint?) {
    lock.lock(); defer { lock.unlock() }
    playNukeImpactLocked(at: point)
  }

  private func playNukeImpactLocked(at point: GameplaySoundPoint?) {
    let now = ProcessInfo.processInfo.systemUptime
    guard nukeActive, !isMuted, !outputSuspended, now - lastNukeImpact >= 0.3 else { return }
    lastNukeImpact = now
    playLocked(samples: Self.nukeBass, rate: sampleRate, gain: 0.22, pan: 0, at: point)
  }

  func play(_ effect: ClassicSoundEffect, pan: Float = 0.0, at point: GameplaySoundPoint? = nil) {
    lock.lock(); defer { lock.unlock() }
    guard effect != .fallOut || bottomFallSounds, let samples = library[effect],
          allowsEffectLocked(effect, at: point) else { return }
    playLocked(samples: samples, rate: rates[effect] ?? sampleRate, gain: gains[effect] ?? 0.6,
      pan: pan, at: point, priority: effect.presentationPriority, rescue: effect.isRescue)
    if effect == .explode || effect == .pop { playNukeImpactLocked(at: point) }
  }

  /// Held rate controls keep one centred cue, without filling the spatial voice pool.
  func playReleaseRate(_ rate: Int, time: Double = ProcessInfo.processInfo.systemUptime) {
    lock.lock(); defer { lock.unlock() }
    guard !isMuted, !outputSuspended, time - lastReleaseRateTime >= 0.02,
      let clip = releaseRateSound else { return }
    lastReleaseRateTime = time
    playLocked(samples: clip.samples, rate: clip.rate * ClassicMacReleaseRate.playbackRatio(rate: rate),
      gain: 0.6, pan: 0, at: nil, priority: 3, releaseRate: true)
  }

  /// Shared spatial voices also play L2's original bank and sample pitches.
  func play(samples: [Float], rate: Double, gain: Float = 0.5, at point: GameplaySoundPoint? = nil,
            semanticEffect: ClassicSoundEffect? = nil) {
    lock.lock(); defer { lock.unlock() }
    if let semanticEffect, !allowsEffectLocked(semanticEffect, at: point) { return }
    playLocked(samples: samples, rate: rate, gain: gain, pan: 0, at: point,
      priority: semanticEffect?.presentationPriority ?? 1, rescue: semanticEffect?.isRescue ?? false)
  }

  private func allowsEffectLocked(_ effect: ClassicSoundEffect, at point: GameplaySoundPoint?) -> Bool {
    guard !isMuted, !outputSuspended else { return false }
    guard effect.repetitionInterval > 0 else { return true }
    let key = effect.rawValue + Self.regionKey(point)
    let now = ProcessInfo.processInfo.systemUptime
    if let previous = recentEffectTimes[key], now - previous < effect.repetitionInterval { return false }
    recentEffectTimes[key] = now
    if recentEffectTimes.count > 256 {
      recentEffectTimes = recentEffectTimes.filter { now - $0.value < 1 }
    }
    return true
  }

  private static func regionKey(_ point: GameplaySoundPoint?) -> String {
    guard let point, point.x.isFinite, point.y.isFinite else { return ":interface" }
    return ":\(floor(point.x / 32)),\(floor(point.y / 32))"
  }

  private func playLocked(samples: [Float], rate: Double, gain: Float, pan: Float, at point: GameplaySoundPoint?,
                          priority: Int = 1, rescue: Bool = false, releaseRate: Bool = false) {
    guard !isMuted, !outputSuspended, !samples.isEmpty, rate.isFinite, rate > 0 else { return }
    let available = (releaseRate ? voices.firstIndex { $0.isReleaseRate } : nil)
      ?? voices.firstIndex { !$0.isActive }
    if rescue, available == nil {
      // A full spatial pool must never cut off the rescue chorus. Extra voices
      // retain their own playheads and gain within the nearest spatial source.
      let rescuers = voices.indices.filter { voices[$0].isRescue || !voices[$0].rescueLayers.isEmpty }
      let candidates = rescuers.isEmpty ? Array(voices.indices) : rescuers
      func distance(_ index: Int) -> Double {
        guard let point, let origin = voices[index].worldPoint else { return 0 }
        return hypot(point.x - origin.x, point.y - origin.y)
      }
      let index = candidates.min { distance($0) < distance($1) }!
      let distanceGain = point.map { viewport.placement(of: $0).gain } ?? 1
      voices[index].rescueLayers.append(RescueLayer(samples: samples, increment: rate / sampleRate,
        gain: gain, worldPoint: point, distanceGain: distanceGain))
      voices[index].priority = max(voices[index].priority, priority)
      onPlay?(samples, rate, Float(level) * gain * distanceGain)
      return
    }
    let index = available ?? voices.indices.min {
      if voices[$0].priority != voices[$1].priority { return voices[$0].priority < voices[$1].priority }
      return (Double(voices[$0].samples.count) - voices[$0].position) / voices[$0].increment <
      (Double(voices[$1].samples.count) - voices[$1].position) / voices[$1].increment
    }!
    guard !voices[index].isActive || voices[index].priority <= priority else { return }
    var retainedRescues = voices[index].isActive ? voices[index].rescueLayers : []
    if voices[index].isActive, voices[index].isRescue, voices[index].position < Double(voices[index].samples.count) {
      retainedRescues.append(RescueLayer(samples: voices[index].samples, position: voices[index].position,
        increment: voices[index].increment, gain: voices[index].gain,
        worldPoint: voices[index].worldPoint, distanceGain: voices[index].distanceGain))
    }
    voices[index] = Voice(samples: samples, position: 0, increment: rate / sampleRate,
                          isActive: true, worldPoint: point, gain: gain, priority: priority, isRescue: rescue,
                          isReleaseRate: releaseRate,
                          rescueLayers: retainedRescues)
    if spatialMixers.indices.contains(index) {
      let angle = (pan.isFinite ? max(-1, min(1, pan)) : 0) * Float.pi / 3
      spatialMixers[index].position = AVAudio3DPoint(x: sin(angle), y: 0, z: -cos(angle))
    }
    placeVoice(index)
    onPlay?(samples, rate, Float(level) * gain * voices[index].distanceGain)
  }

  func play(_ cues: [PositionedSoundCue]) {
    // Collapse nearby copies, while retaining distinct sources on opposite sides.
    var seen = Set<String>()
    for cue in cues {
      let region = Self.regionKey(cue.point)
      let key = cue.sampleName?.lowercased() ?? cue.effect.rawValue
      guard cue.effect.isRescue || seen.insert(key + region).inserted else { continue }
      if let name = cue.sampleName {
        lock.lock()
        let clip = namedSounds[name.lowercased()]
        if let clip, allowsEffectLocked(cue.effect, at: cue.point) {
          playLocked(samples: clip.samples, rate: clip.rate, gain: 0.6, pan: 0, at: cue.point,
            priority: cue.effect.presentationPriority, rescue: cue.effect.isRescue)
        }
        lock.unlock()
        if clip != nil || !cue.allowsFallback { continue }
      }
      play(cue.effect, at: cue.point)
    }
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
    if muted {
      for index in voices.indices {
        voices[index].isActive = false
        voices[index].rescueLayers.removeAll()
      }
      recentEffectTimes.removeAll(keepingCapacity: true)
    }
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

  var effectiveVolume: Double {
    lock.lock(); defer { lock.unlock() }
    return isMuted || outputSuspended ? 0 : level
  }
}
