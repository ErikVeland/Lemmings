import AVFoundation
import Foundation
import NxlvKit

/// Plays effects through a fixed pool of spatial mono sources.
/// Nodes remain attached during play to avoid graph changes between effects.
public final class SoundEffectPlayer: @unchecked Sendable {
  private struct RescueLayer {
    var identity: UInt64 = 0
    var samples: [Float]
    var position: Double = 0
    var increment: Double
    var gain: Float
    var worldPoint: GameplaySoundPoint?
    var distanceGain: Float
  }
  private struct Voice {
    var identity: UInt64 = 0
    var rewindHead = 0.0
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
    var lastSample: Float = 0
    var transitionFrom: Float = 0
    var transitionRemaining = 0
  }

  public var onPlay: (@Sendable ([Float], Double, Float) -> Void)?
  private let engine = AVAudioEngine()
  private let environment = AVAudioEnvironmentNode()
  private let limiter = MusicOutputSafety.limiter()
  private var sourceNodes: [AVAudioPlayerNode] = []
  private var bufferedSource: BufferedAudioSource?
  private var lastActiveFrame: Int64 = 0
  public var audioDiagnostics: AudioBufferStatistics { bufferedSource?.diagnostics ?? AudioBufferStatistics() }
  private var spatialMixers: [AVAudioMixerNode] = []
  private let controlLock = NSLock()
  private let historyLock = NSLock()
  private let voiceBridge: VoiceBridge
  private var workerVoices: [Voice]
  private var controlBaseline: [Voice] = []
  private var nextIdentity: UInt64 = 0
  private var workerBlockStart = -Double.infinity
  private var workerMuted = false
  private var workerGain = 1.0
  private var workerReverseCount = 0
  private var workerHistoryMix = [Float](repeating: 0, count: 512)

  /// Control work prepares immutable commands; PCM owns all running playheads.
  /// Only fixed-size command/status transfers take this separate lock.
  private final class VoiceBridge {
    class Progress {
      var readable = false
      var identity: UInt64 = 0
      var position = 0.0
      var isActive = false
      var lastSample: Float = 0
      var layerIDs = [UInt64](repeating: 0, count: 64)
      var layerPositions = [Double](repeating: 0, count: 64)
      var layerCount = 0
    }
    final class Slot: Progress {
      var pending: Voice?
    }
    let lock = NSLock()
    let slots: [Slot]
    // Only the serial control side uses these snapshots. Copy scalar progress
    // under the bridge lock, then reconcile mutable arrays after releasing it.
    let controlProgress: [Progress]
    var muted = false
    var gain = 1.0
    init(count: Int) {
      slots = (0..<count).map { _ in Slot() }
      controlProgress = (0..<count).map { _ in Progress() }
    }

    func progress(into voices: inout [Voice]) {
      lock.lock()
      for index in voices.indices {
        let slot = slots[index]
        let progress = controlProgress[index]
        progress.readable = slot.pending == nil && voices[index].identity == slot.identity
        guard progress.readable else { continue }
        progress.position = slot.position
        progress.isActive = slot.isActive
        progress.lastSample = slot.lastSample
        progress.layerCount = slot.layerCount
        for layer in 0..<slot.layerCount {
          progress.layerIDs[layer] = slot.layerIDs[layer]
          progress.layerPositions[layer] = slot.layerPositions[layer]
        }
      }
      lock.unlock()
      for index in voices.indices {
        let progress = controlProgress[index]
        guard progress.readable else { continue }
        voices[index].position = progress.position
        voices[index].isActive = progress.isActive
        voices[index].lastSample = progress.lastSample
        for layer in voices[index].rescueLayers.indices {
          if let position = (0..<progress.layerCount).first(where: { progress.layerIDs[$0] == voices[index].rescueLayers[layer].identity }) {
            voices[index].rescueLayers[layer].position = progress.layerPositions[position]
          } else {
            voices[index].rescueLayers[layer].position = Double(voices[index].rescueLayers[layer].samples.count)
          }
        }
        voices[index].rescueLayers.removeAll { $0.position >= Double($0.samples.count) }
      }
    }

    func publish(_ voices: [Voice], previous: [Voice], muted: Bool, gain: Double) {
      // Equality and preparation stay outside the transfer lock.
      var changed: [(Int, Voice)] = []
      for index in voices.indices {
        let v = voices[index]
        let old = previous.indices.contains(index) ? previous[index] : nil
        let equal = old.map { old in
          old.identity == v.identity && old.isActive == v.isActive && old.gain == v.gain
            && old.distanceGain == v.distanceGain && (old.position >= Double(old.samples.count)) == (v.position >= Double(v.samples.count))
            && old.rescueLayers.count == v.rescueLayers.count
            && zip(old.rescueLayers, v.rescueLayers).allSatisfy { a, b in
              a.identity == b.identity && a.gain == b.gain && a.distanceGain == b.distanceGain
            }
        } ?? false
        if !equal { changed.append((index, v)) }
      }
      var retired = [Voice?](repeating: nil, count: changed.count)
      lock.lock()
      for (offset, change) in changed.enumerated() {
        retired[offset] = slots[change.0].pending
        slots[change.0].pending = change.1
      }
      self.muted = muted; self.gain = gain
      lock.unlock()
      // Replacing a pending command can release a large clip. Keep destruction
      // off the handoff lock as well as sample generation and voice cleanup.
      withExtendedLifetime(retired) {}
    }

    func consume(_ index: Int, into voice: inout Voice) -> (Bool, Double) {
      lock.lock()
      let pending = slots[index].pending
      slots[index].pending = nil
      let state = (muted, gain)
      lock.unlock()
      if let command = pending {
        let starts = command.identity != voice.identity
        if starts {
          voice.identity = command.identity; voice.samples = command.samples
          voice.position = command.position; voice.increment = command.increment
          voice.transitionFrom = command.transitionFrom; voice.transitionRemaining = command.transitionRemaining
          voice.rewindSequence = command.rewindSequence; voice.rewindHead = command.rewindHead
          voice.priority = command.priority; voice.isRescue = command.isRescue; voice.isReleaseRate = command.isReleaseRate
        }
        if !starts, command.position >= Double(command.samples.count) { voice.position = max(voice.position, command.position) }
        voice.isActive = command.isActive; voice.gain = command.gain; voice.distanceGain = command.distanceGain
        voice.rescueLayers.removeAll { layer in !command.rescueLayers.contains { $0.identity == layer.identity } }
        for layer in command.rescueLayers {
          if let existing = voice.rescueLayers.firstIndex(where: { $0.identity == layer.identity }) {
            voice.rescueLayers[existing].gain = layer.gain
            voice.rescueLayers[existing].distanceGain = layer.distanceGain
          } else if voice.rescueLayers.count < 64 { voice.rescueLayers.append(layer) }
        }
      }
      return state
    }

    func report(_ index: Int, voice: Voice) {
      lock.lock()
      let slot = slots[index]
      slot.identity = voice.identity; slot.position = voice.position
      slot.isActive = voice.isActive; slot.lastSample = voice.lastSample
      slot.layerCount = min(64, voice.rescueLayers.count)
      for layer in 0..<slot.layerCount {
        slot.layerIDs[layer] = voice.rescueLayers[layer].identity
        slot.layerPositions[layer] = voice.rescueLayers[layer].position
      }
      lock.unlock()
    }
  }

  private func beginControls() {
    controlLock.lock()
    beginLockedControls()
  }
  private func beginLockedControls() {
    if bufferedSource != nil { voiceBridge.progress(into: &voices) }
    controlBaseline = voices
  }
  private func endControls() {
    if bufferedSource != nil { voiceBridge.publish(voices, previous: controlBaseline, muted: isMuted, gain: level) }
    controlBaseline = []
    controlLock.unlock()
  }
  private func identity() -> UInt64 { nextIdentity &+= 1; return nextIdentity }


  // Guarded by `lock`.
  private var library: [ClassicSoundEffect: [Float]] = [:]
  private var rates: [ClassicSoundEffect: Double] = [:]
  private var gains: [ClassicSoundEffect: Float] = [:]
  private var supplementalEffects = Set<ClassicSoundEffect>()
  private var pendingPlayNotifications: [MovieCue] = []
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
  private var rewindHistoryHead = 0.0
  private var rewindSliceHead = 0.0
  private var rewindHistoryAnchor: Int64?
  private var lastRewindTrigger = -Double.infinity
  private var lastRewindSample: Float = 0
  private var rewindSequence: UInt64 = 0
  private var rewindRenderStart: Int64?
  private var recentRenderPrepared = false
  private var rewindRenderFrames = 0
  private var rewindRenderCount = 0
  private var rewindRenderedVoices: [Bool]

  private let sampleRate = 44100.0
  public private(set) var isRunning = false
  public private(set) var loadedEffects: [ClassicSoundEffect] = []

  private let rescueVoiceLimit: Int?
  private let fixedResources: DeviceEffectResources?
  private var requestedVoiceLimit: Int
  private var activeVoiceLimit: Int
  private var activeRescueLimit: Int

  public init(voiceCount: Int = 64, rescueVoiceLimit: Int? = nil, resources: DeviceEffectResources? = nil) {
    self.rescueVoiceLimit = rescueVoiceLimit.map { max(1, $0) }
    fixedResources = resources
    let process = ProcessInfo.processInfo
    let budget = resources ?? DeviceEffectResources(physicalMemory: process.physicalMemory, processorCount: process.processorCount)
    let count = max(1, min(voiceCount, budget.audioVoiceLimit))
    requestedVoiceLimit = count; activeVoiceLimit = count
    activeRescueLimit = min(rescueVoiceLimit ?? budget.rescueVoiceLimit, budget.rescueVoiceLimit)
    voiceBridge = VoiceBridge(count: count)
    workerVoices = (0..<count).map { _ in
      var voice = Voice()
      voice.rescueLayers.reserveCapacity(64)
      return voice
    }
    voices = [Voice](repeating: Voice(), count: count)
    rewindRenderedVoices = [Bool](repeating: false, count: count)
    recentSamples = [Float](repeating: 0, count: recentSampleLimit)
    recentSamplePositions = [Int64](repeating: .min, count: recentSampleLimit)
    installPresentationSoundsLocked()
    refreshResourceBudgetLocked()
  }

  /// Replays share the selected samples and settings, but own their voices and output.
  public func replayPlayer() -> SoundEffectPlayer {
    beginControls(); defer { endControls() }
    let copy = SoundEffectPlayer(voiceCount: voices.count, rescueVoiceLimit: rescueVoiceLimit, resources: fixedResources)
    copy.requestedVoiceLimit = requestedVoiceLimit
    copy.refreshResourceBudgetLocked()
    copy.library = library; copy.rates = rates; copy.gains = gains
    copy.supplementalEffects = supplementalEffects; copy.namedSounds = namedSounds
    copy.releaseRateSound = releaseRateSound
    copy.loadedEffects = loadedEffects
    copy.isMuted = isMuted; copy.level = level; copy.bottomFallSounds = bottomFallSounds
    return copy
  }

  // MARK: - Engine

  public func start() throws {
    guard !isRunning else { return }
    let mono = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    let stereo = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
    engine.attach(environment)
    environment.outputType = .auto
    environment.distanceAttenuationParameters.rolloffFactor = 0
    environment.reverbParameters.enable = false
    engine.attach(limiter)
    engine.connect(environment, to: limiter, format: stereo)
    engine.connect(limiter, to: engine.mainMixerNode, format: stereo)
    let source = BufferedAudioSource(label: "Lemmings.effects-pcm", format: mono, count: voices.count) { [weak self] index, buffer, time in
      self?.fillVoice(index, buffers: UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList),
        frames: Int(buffer.frameLength), sampleTime: Double(time))
    }
    bufferedSource = source
    for index in voices.indices {
      let mixer = AVAudioMixerNode()
      let node = source.nodes[index]
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
    engine.mainMixerNode.outputVolume = isMuted || level == 0 ? 0 : 1
    do { try engine.start() }
    catch { source.stop(); detachSources(); throw error }
    voiceBridge.publish(voices, previous: [], muted: isMuted, gain: level)
    source.start()
    isRunning = true
   beginControls()
    outputSuspended = false
    endControls()
  }

  private func detachSources() {
    for node in sourceNodes { engine.detach(node) }
    for mixer in spatialMixers { engine.detach(mixer) }
    engine.detach(environment)
    engine.detach(limiter)
    bufferedSource = nil
    sourceNodes = []
    spatialMixers = []
  }

  public func stop() {
    guard isRunning else { return }
    engine.stop()
    bufferedSource?.stop()
    detachSources()
    silence()
    isRunning = false
    beginControls()
    outputSuspended = false
    endControls()
  }

  public func suspendOutput() {
    guard isRunning else { return }
    controlLock.lock()
    if outputSuspended && !engine.isRunning { controlLock.unlock(); return }
    beginLockedControls()
    outputSuspended = true
    rewindSequence &+= 1
   for index in voices.indices {
      voices[index].isActive = false
      voices[index].rescueLayers.removeAll()
    }
    endControls()
    engine.pause()
    bufferedSource?.stopAfterPausingEngine()
  }

  /// Park a silent graph after the last voice finishes. Playback adapters own retries.
  @discardableResult public func suspendOutputIfIdle() -> Bool {
    beginControls()
    let idle = !voices.contains { $0.isActive }
    historyLock.lock()
    let tail = lastActiveFrame
    historyLock.unlock()
    endControls()
    guard idle, bufferedSource.map({ $0.playedFrame >= tail }) ?? true else { return false }
    suspendOutput()
    return true
 }

  public func resumeOutput() throws {
    guard isRunning else { return }
    controlLock.lock()
    if !outputSuspended && engine.isRunning { controlLock.unlock(); return }
    beginLockedControls()
    let wasSuspended = outputSuspended
    outputSuspended = false
    endControls()
    if wasSuspended { bufferedSource?.drain() }
    do { if !engine.isRunning { try engine.start() } }
    catch { suspendOutput(); throw error }
    bufferedSource?.start()
  }

  private func fillVoice(_ index: Int, buffers: UnsafeMutableAudioBufferListPointer, frames: Int, sampleTime: Double) {
    if bufferedSource == nil {
      beginControls()
      defer { endControls() }
      var voice = voices[index]
      renderVoice(index, voice: &voice, renderedVoices: voices, muted: isMuted, gain: level,
        buffers: buffers, frames: frames, sampleTime: sampleTime)
      voices[index] = voice
    } else {
      // The PCM worker never takes the control/library lock and never copies its voice array.
      if workerBlockStart != sampleTime || index == 0 {
        workerBlockStart = sampleTime
        for slot in workerVoices.indices {
          let state = voiceBridge.consume(slot, into: &workerVoices[slot])
          workerMuted = state.0; workerGain = state.1
        }
        workerReverseCount = workerVoices.reduce(0) { $0 + ($1.isActive && $1.rewindSequence != nil ? 1 : 0) }
      }
      workerVoices.withUnsafeMutableBufferPointer { voices in
        renderVoice(index, voice: &voices[index], rewindCount: workerReverseCount, muted: workerMuted, gain: workerGain,
          buffers: buffers, frames: frames, sampleTime: sampleTime)
        voiceBridge.report(index, voice: voices[index])
      }
    }
  }

  private func renderVoice(_ index: Int, voice: inout Voice, renderedVoices: [Voice] = [], rewindCount: Int? = nil,
                           muted: Bool, gain: Double, buffers: UnsafeMutableAudioBufferListPointer,
                           frames: Int, sampleTime: Double) {
    let start = sampleTime.isFinite && sampleTime >= 0
      ? Int64(sampleTime.rounded())
      : (latestRecentSample.map { $0 + 1 } ?? 0)
    // Scrub slices may contain the same effects. Share one mix budget across
    // the whole render block, even when an earlier source finishes mid-block.
    if rewindRenderStart != start || rewindRenderFrames != frames || rewindRenderedVoices[index] {
      rewindRenderStart = start
      recentRenderPrepared = false
      rewindRenderFrames = frames
      rewindRenderCount = rewindCount ?? renderedVoices.reduce(0) { $0 + ($1.isActive && $1.rewindSequence != nil ? 1 : 0) }
      for index in rewindRenderedVoices.indices { rewindRenderedVoices[index] = false }
    }
    rewindRenderedVoices[index] = true
   // Clear the history once per block, rather than for every silent spatial source.
    // Scrub-only renders retain their history and never record their own output.
    if rewindRenderCount == 0, voice.rewindSequence == nil, !recentRenderPrepared {
      historyLock.lock()
      for frame in 0..<frames {
        let position = start + Int64(frame)
        let slot = Int((position % Int64(recentSampleLimit) + Int64(recentSampleLimit)) % Int64(recentSampleLimit))
        recentSamplePositions[slot] = position
        recentSamples[slot] = 0
      }
      latestRecentSample = max(latestRecentSample ?? start, start + Int64(max(0, frames - 1)))
      recentRenderPrepared = true
      historyLock.unlock()
   }
    guard !muted, voice.isActive else {
      for buffer in buffers { memset(buffer.mData, 0, Int(buffer.mDataByteSize)) }
      return
    }
    historyLock.lock()
    lastActiveFrame = start + Int64(frames)
    historyLock.unlock()
    if workerHistoryMix.count < frames { workerHistoryMix = [Float](repeating: 0, count: frames) }
    let rewindGain: Float = voice.rewindSequence == nil ? 1 : 1 / Float(max(1, rewindRenderCount))
    var reverseTail: Float?
    for frame in 0..<frames {
      var sample: Float = 0
      var sourceSample: Float = 0
      var historySample: Float = 0
      if !muted && voice.isActive {
        let position = Int(voice.position)
        if position >= voice.samples.count && voice.rescueLayers.isEmpty { voice.isActive = false }
        if position < voice.samples.count {
          let next = min(position + 1, voice.samples.count - 1)
          sourceSample = voice.samples[position] + (voice.samples[next] - voice.samples[position]) * Float(voice.position - Double(position))
          // Short edge fades suppress clicks from sample truncation and voice stealing.
          if voice.rewindSequence == nil {
            sourceSample *= Float(min(1, max(0, (Double(voice.samples.count - 1) - voice.position) / (64 * voice.increment))))
          }
          sample = sourceSample * Float(gain) * voice.gain * voice.distanceGain * rewindGain
          historySample = sourceSample * voice.gain * voice.distanceGain
          voice.position += voice.increment
        }
        for index in voice.rescueLayers.indices {
          let position = Int(voice.rescueLayers[index].position)
          guard position < voice.rescueLayers[index].samples.count else { continue }
          let next = min(position + 1, voice.rescueLayers[index].samples.count - 1)
          let layerSample = voice.rescueLayers[index].samples[position]
            + (voice.rescueLayers[index].samples[next] - voice.rescueLayers[index].samples[position])
            * Float(voice.rescueLayers[index].position - Double(position))
          sample += layerSample * Float(gain) * voice.rescueLayers[index].gain * voice.rescueLayers[index].distanceGain
          historySample += layerSample * voice.rescueLayers[index].gain * voice.rescueLayers[index].distanceGain
          voice.rescueLayers[index].position += voice.rescueLayers[index].increment
        }

      }
      if voice.transitionRemaining > 0 {
        let weight = Float(voice.transitionRemaining) / 64
        historySample = historySample * (1 - weight) + voice.transitionFrom * weight
        sample = historySample * Float(gain)
        voice.transitionRemaining -= 1
      }
      voice.lastSample = historySample
      for buffer in buffers { buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample }
      if voice.rewindSequence != nil { reverseTail = sourceSample }

      // Rewind output must never feed the history it will reverse next.
      guard rewindRenderCount == 0, voice.rewindSequence == nil else { continue }
      workerHistoryMix[frame] = historySample
    }
    historyLock.lock()
    if let reverseTail { lastRewindSample = reverseTail }
    if voice.rewindSequence != nil {
      rewindHistoryHead = voice.rewindHead - VinylBackspin.distance(frames: voice.position, sampleRate: sampleRate)
    } else if rewindRenderCount == 0 {
      for frame in 0..<frames {
        let position = start + Int64(frame)
        let slot = Int((position % Int64(recentSampleLimit) + Int64(recentSampleLimit)) % Int64(recentSampleLimit))
        recentSamples[slot] += workerHistoryMix[frame]
      }
    }
    historyLock.unlock()
    voice.rescueLayers.removeAll { $0.position >= Double($0.samples.count) }
  }

  // MARK: - Library

  /// Loads effects from a Macintosh disk image.
  ///
  /// The Mac release names its sounds, so the binding is by name rather than
  /// by position, and each sound keeps the rate its resource records. The Mac
  /// disk has no sound for some events. A named Amiga sample fills each gap,
  /// then a supplied sound named after the event.
  @discardableResult
  public func loadMacintoshSounds(imageURL: URL, amigaFallbackDirectory: URL? = nil,
                           supplementDirectory: URL? = nil) throws -> [ClassicSoundEffect] {
    let image = try Data(contentsOf: imageURL, options: .mappedIfSafe)
    let volume = try ClassicHFSVolume(image: image)
    let fork = try volume.resourceFork(named: "Lemmings")
    let sounds = ClassicMacSoundDecoder.sounds(in: fork)

    var byName: [String: ClassicMacSound] = [:]
    for sound in sounds {
      if let name = sound.name { byName[name] = sound }
    }

    let supplement = Self.supplementSounds(supplementDirectory)
    let decoded = byName.mapValues { ($0.floatSamples(), $0.sampleRate) }
    let amiga = amigaFallbackDirectory.flatMap { try? Self.amigaSounds(in: $0) } ?? [:]
    beginControls()
    library = [:]
    rates = [:]
    gains = [:]; supplementalEffects = []
    releaseRateSound = decoded["MousePress"]
    for (effect, name) in ClassicSoundMapping.macintoshNames {
      guard let sound = decoded[name] else { continue }
      library[effect] = sound.0
      rates[effect] = sound.1
    }
    if !amiga.isEmpty {
      for (effect, name) in ClassicSoundMapping.amigaVoiceNames where library[effect] == nil {
        guard let sound = amiga[name.lowercased()] else { continue }
        library[effect] = sound.samples
        rates[effect] = sound.sampleRate
      }
    }
    fillFromSupplementLocked(supplement)
    installPresentationSoundsLocked()
    let loaded = library.keys.sorted { $0.rawValue < $1.rawValue }
    endControls()

    loadedEffects = loaded
    return loaded
  }

  /// Fills each still-silent event from a sound file named after it, such as
  /// `yippee.mp3`. Neither the Mac disk nor the Amiga banks has a Yippee.
  private static func supplementSounds(_ directory: URL?) -> [ClassicSoundEffect: (samples: [Float], rate: Double)] {
    guard let directory else { return [:] }
    var clips: [ClassicSoundEffect: (samples: [Float], rate: Double)] = [:]
    for effect in ClassicSoundEffect.allCases {
      for ext in ["wav", "m4a", "mp3"] {
        let url = directory.appendingPathComponent(effect.rawValue).appendingPathExtension(ext)
        guard let decoded = Self.monoSamples(url) else { continue }
        clips[effect] = decoded
        break
      }
    }
    return clips
  }

  private func fillFromSupplementLocked(_ clips: [ClassicSoundEffect: (samples: [Float], rate: Double)]) {
    for (effect, clip) in clips where library[effect] == nil || supplementalEffects.contains(effect) {
      library[effect] = clip.samples
      rates[effect] = clip.rate
      gains[effect] = 0.6
      supplementalEffects.remove(effect)
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
  public func loadSupplementSounds(directory: URL?) {
    let supplement = Self.supplementSounds(directory)
    beginControls(); defer { endControls() }
    fillFromSupplementLocked(supplement)
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
  public func loadAmigaSounds(directory: URL, macintoshFallbackImage: URL? = nil,
                       supplementDirectory: URL? = nil) throws -> [ClassicSoundEffect] {
    var macintosh: [String: ClassicMacSound] = [:]
    if let image = macintoshFallbackImage {
      let volume = try ClassicHFSVolume(image: Data(contentsOf: image, options: .mappedIfSafe))
      for sound in ClassicMacSoundDecoder.sounds(in: try volume.resourceFork(named: "Lemmings")) {
        if let name = sound.name { macintosh[name] = sound }
      }
    }
    let byName = try Self.amigaSounds(in: directory)
    let supplement = Self.supplementSounds(supplementDirectory)
    let decoded = macintosh.mapValues { ($0.floatSamples(), $0.sampleRate) }

    beginControls()
    library = [:]
    rates = [:]
    gains = [:]; supplementalEffects = []
    releaseRateSound = decoded["MousePress"]
    for (effect, name) in ClassicSoundMapping.amigaVoiceNames {
      guard let sound = byName[name.lowercased()] else { continue }
      library[effect] = sound.samples
      rates[effect] = sound.sampleRate
    }
    for (effect, name) in ClassicSoundMapping.macintoshNames where library[effect] == nil {
      guard let sound = decoded[name] else { continue }
      library[effect] = sound.0
      rates[effect] = sound.1
    }
    fillFromSupplementLocked(supplement)
    installPresentationSoundsLocked()
    let loaded = library.keys.sorted { $0.rawValue < $1.rawValue }
    endControls()

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
  public func loadNeoLemmixSounds(names: Set<String>, soundDirectory: URL, amigaDirectory: URL?, fallbackSoundDirectory: URL? = nil) {
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
    beginControls(); defer { endControls() }
    namedSounds = clips
  }

  // MARK: - Playing

  /// Keep the countdown warning while installing the sequel's named voices.
  public func loadLemmings3Sounds(root: URL) throws {
    let bank = try Lemmings3SoundBank(root: root)
    beginControls()
    defer { endControls() }
    for (effect, clip) in bank.clips {
      library[effect] = clip.samples
      rates[effect] = clip.sampleRate
      gains[effect] = 0.6; supplementalEffects.remove(effect)
    }
    loadedEffects = library.keys.sorted { $0.rawValue < $1.rawValue }
  }

  public func silence() {
    beginControls()
    rewindSequence &+= 1
    for index in voices.indices {
      voices[index].isActive = false
      voices[index].rescueLayers.removeAll()
    }
    recentEffectTimes.removeAll(keepingCapacity: true)
    let restart = isRunning && !outputSuspended && engine.isRunning
    endControls()
    bufferedSource?.stop()
    if restart { bufferedSource?.start() }
  }

  /// Let the final rescue chorus finish as the result page opens.
  public func silencePreservingRescues() {
    beginControls()
    rewindSequence &+= 1
    defer { endControls() }
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

  /// Backspin the captured effect mix with a falling pitch and soft envelope.
  /// Repeated requests continue the active groove without stacking voices.
  public func playRewindScrub() {
    let audibleFrame = bufferedSource?.playedFrame
    // Allocate before taking the synthesis lock. Copy only bounded PCM history;
    // resampling, envelopes and normalisation happen without blocking refills.
    var history = [Float](repeating: 0, count: recentSampleLimit)
    var positions = [Int64](repeating: 0, count: recentSampleLimit)
    beginControls()
    guard !isMuted, !outputSuspended else { endControls(); return }
    historyLock.lock()
    guard let captured = latestRecentSample else { historyLock.unlock(); endControls(); return }
    history.withUnsafeMutableBufferPointer { destination in
      recentSamples.withUnsafeBufferPointer { source in destination.baseAddress!.update(from: source.baseAddress!, count: source.count) }
    }
    positions.withUnsafeMutableBufferPointer { destination in
      recentSamplePositions.withUnsafeBufferPointer { source in destination.baseAddress!.update(from: source.baseAddress!, count: source.count) }
    }
    let expectedSequence = rewindSequence
    let carriedSample = lastRewindSample
    let latest = min(captured, audibleFrame.map { $0 - 1 } ?? captured)
    guard latest >= 0 else { historyLock.unlock(); endControls(); return }
    let now = ProcessInfo.processInfo.systemUptime
    let continuing = rewindHistoryAnchor == latest && now - lastRewindTrigger <= VinylBackspin.settleSeconds
    let head: Double
    if continuing {
      head = rewindHistoryHead
    } else { head = Double(latest) }
    historyLock.unlock()
    endControls()
    let count = Int(sampleRate * VinylBackspin.seconds)
    var samples = [Float](repeating: 0, count: count)
    var foundHistory = false
    var peak: Float = 1
    for offset in samples.indices {
      let cursor = head - VinylBackspin.distance(frames: Double(offset), sampleRate: sampleRate)
      guard cursor >= 0 else { break }
      let position = Int64(cursor)
      let slot = Int((position % Int64(recentSampleLimit) + Int64(recentSampleLimit)) % Int64(recentSampleLimit))
      guard positions[slot] == position else { break }
      let nextSlot = (slot + 1) % recentSampleLimit
      let next = positions[nextSlot] == position + 1 ? history[nextSlot] : history[slot]
      let value = history[slot] + (next - history[slot]) * Float(cursor - Double(position))
      peak = max(peak, abs(value))
      samples[offset] = value * VinylBackspin.sample(frame: Double(offset), sampleRate: sampleRate).gain
      foundHistory = foundHistory || samples[offset] != 0
    }
    guard foundHistory else { return }
    // Fade short histories too, so their last captured sample cannot click.
    if let end = samples.lastIndex(where: { $0 != 0 }) {
      let fade = min(end + 1, Int(sampleRate * 0.030))
      for offset in 0..<fade { samples[end - offset] *= Float(offset) / Float(fade) }
    }
    // Preserve the mix shape when a large chorus exceeds the mono headroom.
    if peak > 1 { for offset in samples.indices { samples[offset] /= peak } }
    if continuing {
      // Carry the last output into the new attack instead of cutting to zero.
      for offset in 0..<min(samples.count, Int(sampleRate * 0.020)) {
        let attack = VinylBackspin.sample(frame: Double(offset), sampleRate: sampleRate).gain
        samples[offset] += carriedSample * (1 - attack)
      }
    }
    beginControls()
    defer { deliverPlayNotificationsAndUnlock() }
    guard !isMuted, !outputSuspended, rewindSequence == expectedSequence else { return }
    refreshResourceBudgetLocked()
    let previous = voices.indices.first { voices[$0].isActive && voices[$0].rewindSequence != nil }
    for index in voices.indices where voices[index].rewindSequence != nil { voices[index].isActive = false }
    historyLock.lock()
    if !continuing { lastRewindSample = 0 }
    historyLock.unlock()
    let index = previous ?? voices.firstIndex { !$0.isActive } ?? voices.startIndex
    historyLock.lock()
    rewindHistoryHead = head; rewindSliceHead = head; rewindHistoryAnchor = latest
    historyLock.unlock()
    lastRewindTrigger = now
    rewindSequence &+= 1
    voices[index] = Voice(identity: identity(), rewindHead: head, samples: samples, position: 0, increment: 1, isActive: true,
      gain: 0.4, rewindSequence: rewindSequence)
    if spatialMixers.indices.contains(index) { spatialMixers[index].position = AVAudio3DPoint(x: 0, y: 0, z: -1) }
    enqueuePlayLocked(samples, rate: sampleRate, gain: Float(level) * 0.4)
  }

  /// Turns a stereo position into a pair of channel gains.
  ///
  /// A pan of -1 is hard left, 0 is centre, and +1 is hard right. Values
  /// outside that range are brought back into it.
  public static func constantPowerGains(pan: Float) -> (left: Float, right: Float) {
    let clamped = max(-1, min(1, pan))
    let angle = (clamped + 1) * Float.pi / 4
    return (cos(angle), sin(angle))
  }

  /// Places an effect across the sound stage (-1.0 left to +1.0 right).
  private var bottomFallSounds = true

  public func setBottomFallSounds(_ enabled: Bool) {
    beginControls(); defer { endControls() }; bottomFallSounds = enabled
  }

  /// Refresh active one-shots as well as the next event when the camera moves.
  public func setViewport(_ value: GameplaySoundViewport) {
    controlLock.lock()
    let budget = voiceBudgetLocked()
    guard viewport != value || activeVoiceLimit != budget.voice || activeRescueLimit != budget.rescue else {
      controlLock.unlock(); return
    }
    beginLockedControls(); defer { endControls() }
    applyVoiceBudgetLocked(voiceLimit: budget.voice, rescueLimit: budget.rescue)
    guard viewport != value else { return }
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
  public static let nukeBass: [Float] = (0..<15_435).map { i in
    let t = Double(i) / 44100
    let phase = 2 * Double.pi * (48 * t + 22 * 0.045 * (1 - exp(-t / 0.045)))
    let envelope = min(1, t / 0.012) * exp(-t * 14) * pow(max(0, 1 - t / 0.35), 2)
    return Float((sin(phase) + 0.18 * sin(phase * 2)) * envelope)
  }

  public func setNukeActive(_ active: Bool) {
    controlLock.lock()
    guard active != nukeActive else { controlLock.unlock(); return }
    beginLockedControls(); defer { deliverPlayNotificationsAndUnlock() }
    nukeActive = active
    lastNukeImpact = -Double.infinity
    if active {
      playLocked(samples: Self.nukeBass, rate: sampleRate, gain: 0.12, pan: 0, at: nil)
    }
  }

  public func playNukeImpact(at point: GameplaySoundPoint?) {
    beginControls(); defer { deliverPlayNotificationsAndUnlock() }
    playNukeImpactLocked(at: point)
  }

  private func playNukeImpactLocked(at point: GameplaySoundPoint?) {
    let now = ProcessInfo.processInfo.systemUptime
    guard nukeActive, !isMuted, !outputSuspended, now - lastNukeImpact >= 0.3 else { return }
    lastNukeImpact = now
    playLocked(samples: Self.nukeBass, rate: sampleRate, gain: 0.22, pan: 0, at: point)
  }

  public func play(_ effect: ClassicSoundEffect, pan: Float = 0.0, at point: GameplaySoundPoint? = nil) {
    beginControls(); defer { deliverPlayNotificationsAndUnlock() }
    guard effect != .fallOut || bottomFallSounds, let samples = library[effect],
          allowsEffectLocked(effect, at: point) else { return }
    playLocked(samples: samples, rate: rates[effect] ?? sampleRate, gain: gains[effect] ?? 0.6,
      pan: pan, at: point, priority: effect.presentationPriority, rescue: effect.isRescue)
    if effect == .explode || effect == .pop { playNukeImpactLocked(at: point) }
  }

  /// Held rate controls keep one centred cue, without filling the spatial voice pool.
  public func playReleaseRate(_ rate: Int, time: Double = ProcessInfo.processInfo.systemUptime) {
    beginControls(); defer { deliverPlayNotificationsAndUnlock() }
    guard !isMuted, !outputSuspended, time - lastReleaseRateTime >= 0.02,
      let clip = releaseRateSound else { return }
    lastReleaseRateTime = time
    playLocked(samples: clip.samples, rate: clip.rate * ClassicMacReleaseRate.playbackRatio(rate: rate),
      gain: 0.6, pan: 0, at: nil, priority: 3, releaseRate: true)
  }

  /// Shared spatial voices also play L2's original bank and sample pitches.
  public func play(samples: [Float], rate: Double, gain: Float = 0.5, at point: GameplaySoundPoint? = nil,
            semanticEffect: ClassicSoundEffect? = nil) {
    beginControls(); defer { deliverPlayNotificationsAndUnlock() }
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

  private func enqueuePlayLocked(_ samples: [Float], rate: Double, gain: Float) {
    if onPlay != nil { pendingPlayNotifications.append(MovieCue(samples: samples, rate: rate, gain: gain)) }
  }

  private func deliverPlayNotificationsAndUnlock() {
    let callback = onPlay
    let notifications = pendingPlayNotifications
    pendingPlayNotifications = []
    endControls()
    for cue in notifications { callback?(cue.samples, cue.rate, cue.gain) }
  }

  private func playLocked(samples: [Float], rate: Double, gain: Float, pan: Float, at point: GameplaySoundPoint?,
                          priority: Int = 1, rescue: Bool = false, releaseRate: Bool = false) {
    refreshResourceBudgetLocked()
    guard !isMuted, !outputSuspended, !samples.isEmpty, rate.isFinite, rate > 0 else { return }
    // Bound both spatial sources and the extra playheads in a rescue chorus.
    if rescue,
       voices.reduce(0, { $0 + ($1.isActive && $1.isRescue ? 1 : 0) + $1.rescueLayers.count }) >= activeRescueLimit { return }
    let available = (releaseRate ? voices.firstIndex { $0.isReleaseRate } : nil)
      ?? (voices.reduce(0) { $0 + ($1.isActive ? 1 : 0) } < activeVoiceLimit ? voices.firstIndex { !$0.isActive } : nil)
    if rescue, available == nil {
      // A full spatial pool must never cut off the rescue chorus. Extra voices
      // retain their own playheads and gain within the nearest spatial source.
      let rescuers = voices.indices.filter { voices[$0].isActive && (voices[$0].isRescue || !voices[$0].rescueLayers.isEmpty) }
      let candidates = rescuers.isEmpty ? voices.indices.filter { voices[$0].isActive } : rescuers
      func distance(_ index: Int) -> Double {
        guard let point, let origin = voices[index].worldPoint else { return 0 }
        return hypot(point.x - origin.x, point.y - origin.y)
      }
      let index = candidates.min { distance($0) < distance($1) }!
      let distanceGain = point.map { viewport.placement(of: $0).gain } ?? 1
      voices[index].rescueLayers.append(RescueLayer(identity: identity(), samples: samples, increment: rate / sampleRate,
        gain: gain, worldPoint: point, distanceGain: distanceGain))
      voices[index].priority = max(voices[index].priority, priority)
      enqueuePlayLocked(samples, rate: rate, gain: Float(level) * gain * distanceGain)
      return
    }
    let index = available ?? voices.indices.filter { voices[$0].isActive }.min {
      if voices[$0].priority != voices[$1].priority { return voices[$0].priority < voices[$1].priority }
      return (Double(voices[$0].samples.count) - voices[$0].position) / voices[$0].increment <
      (Double(voices[$1].samples.count) - voices[$1].position) / voices[$1].increment
    }!
    guard !voices[index].isActive || voices[index].priority <= priority else { return }
    var retainedRescues = voices[index].isActive ? voices[index].rescueLayers : []
    if voices[index].isActive, voices[index].isRescue, voices[index].position < Double(voices[index].samples.count) {
      retainedRescues.append(RescueLayer(identity: identity(), samples: voices[index].samples, position: voices[index].position,
        increment: voices[index].increment, gain: voices[index].gain,
        worldPoint: voices[index].worldPoint, distanceGain: voices[index].distanceGain))
    }
    let previousSample = voices[index].isActive ? voices[index].lastSample : 0
    voices[index] = Voice(identity: identity(), samples: samples, position: 0, increment: rate / sampleRate,
                          isActive: true, worldPoint: point, gain: gain, priority: priority, isRescue: rescue,
                          isReleaseRate: releaseRate,
                          rescueLayers: retainedRescues, transitionFrom: previousSample, transitionRemaining: 64)
    if spatialMixers.indices.contains(index) {
      let angle = (pan.isFinite ? max(-1, min(1, pan)) : 0) * Float.pi / 3
      spatialMixers[index].position = AVAudio3DPoint(x: sin(angle), y: 0, z: -cos(angle))
    }
    placeVoice(index)
    enqueuePlayLocked(samples, rate: rate, gain: Float(level) * gain * voices[index].distanceGain)
  }

  /// Admission changes without rebuilding the audio graph or changing settings.
  public func setVoiceLimit(_ count: Int) {
    controlLock.lock()
    requestedVoiceLimit = max(1, min(voices.count, count))
    let budget = voiceBudgetLocked()
    guard activeVoiceLimit != budget.voice || activeRescueLimit != budget.rescue else {
      controlLock.unlock(); return
    }
    beginLockedControls(); defer { endControls() }
    applyVoiceBudgetLocked(voiceLimit: budget.voice, rescueLimit: budget.rescue)
  }

  private func refreshResourceBudgetLocked() {
    let budget = voiceBudgetLocked()
    applyVoiceBudgetLocked(voiceLimit: budget.voice, rescueLimit: budget.rescue)
  }

  private func voiceBudgetLocked() -> (voice: Int, rescue: Int) {
    let budget = fixedResources ?? DeviceEffectPressure.shared.snapshot()
    return (min(requestedVoiceLimit, budget.audioVoiceLimit),
            min(rescueVoiceLimit ?? budget.rescueVoiceLimit, budget.rescueVoiceLimit,
                requestedVoiceLimit < voices.count ? requestedVoiceLimit : Int.max))
  }

  private func applyVoiceBudgetLocked(voiceLimit: Int, rescueLimit: Int) {
    let voiceLimit = max(1, min(voices.count, voiceLimit)), rescueLimit = max(1, rescueLimit)
    guard voiceLimit != activeVoiceLimit || rescueLimit != activeRescueLimit else { return }
    activeVoiceLimit = voiceLimit; activeRescueLimit = rescueLimit
    // Keep actions and warnings before decorative sounds when pressure arrives.
    let active = voices.indices.filter { voices[$0].isActive }.sorted {
      if voices[$0].priority != voices[$1].priority { return voices[$0].priority > voices[$1].priority }
      return $0 < $1
    }
    for index in active.dropFirst(voiceLimit) { voices[index] = Voice() }
    var remaining = rescueLimit
    for index in active.prefix(voiceLimit) {
      if voices[index].isRescue {
        if remaining > 0 { remaining -= 1 }
        else { voices[index] = Voice(); continue }
      }
      let retained = min(remaining, voices[index].rescueLayers.count)
      if retained < voices[index].rescueLayers.count {
        voices[index].rescueLayers.removeLast(voices[index].rescueLayers.count - retained)
      }
      remaining -= retained
    }
  }

  public func play(_ cues: [PositionedSoundCue]) {
    // Collapse nearby copies, while retaining distinct sources on opposite sides.
    var seen = Set<String>()
    for cue in cues {
      let region = Self.regionKey(cue.point)
      let key = cue.sampleName?.lowercased() ?? cue.effect.rawValue
      guard cue.effect.isRescue || seen.insert(key + region).inserted else { continue }
      if let name = cue.sampleName {
        beginControls()
        let clip = namedSounds[name.lowercased()]
        if let clip, allowsEffectLocked(cue.effect, at: cue.point) {
          playLocked(samples: clip.samples, rate: clip.rate, gain: 0.6, pan: 0, at: cue.point,
            priority: cue.effect.presentationPriority, rescue: cue.effect.isRescue)
        }
        deliverPlayNotificationsAndUnlock()
        if clip != nil || !cue.allowsFallback { continue }
      }
      play(cue.effect, at: cue.point)
    }
  }

  public func play(_ effects: [ClassicSoundEffect], pan: Float = 0.0) {
    for effect in effects { play(effect, pan: pan) }
  }

  public struct MovieCue: Sendable {
    public let samples: [Float]
    public let rate: Double
    public let gain: Float
  }

  /// Resolves movie samples on simulation time without starting an audio engine.
  public func movieCues(_ cues: [PositionedSoundCue], viewport: GameplaySoundViewport, time: Double) -> [MovieCue] {
    beginControls(); defer { endControls() }
    guard !isMuted, !outputSuspended else { return [] }
    var seen = Set<String>()
    var result: [MovieCue] = []
    for cue in cues {
      guard cue.effect != .fallOut || bottomFallSounds else { continue }
      let region = Self.regionKey(cue.point)
      let key = (cue.sampleName?.lowercased() ?? cue.effect.rawValue) + region
      guard cue.effect.isRescue || seen.insert(key).inserted else { continue }
      if cue.effect.repetitionInterval > 0 {
        if let previous = recentEffectTimes[key], time - previous < cue.effect.repetitionInterval { continue }
        recentEffectTimes[key] = time
      }
      let named = cue.sampleName.flatMap { namedSounds[$0.lowercased()] }
      if cue.sampleName != nil, named == nil, !cue.allowsFallback { continue }
      guard let samples = named?.samples ?? library[cue.effect] else { continue }
      let rate = named?.rate ?? rates[cue.effect] ?? sampleRate
      let gain = Float(level) * (named == nil ? gains[cue.effect] ?? 0.6 : 0.6)
        * (cue.point.map { viewport.placement(of: $0).gain } ?? 1)
      result.append(.init(samples: samples, rate: rate, gain: gain))
      if nukeActive, cue.effect == .explode || cue.effect == .pop, time - lastNukeImpact >= 0.3 {
        lastNukeImpact = time
        result.append(.init(samples: Self.nukeBass, rate: sampleRate, gain: Float(level) * 0.22))
      }
    }
    return result
  }

  /// Sets the output level, from silent to full.
  public func setVolume(_ value: Double) {
    beginControls()
    level = value.isFinite ? min(1, max(0, value)) : 0
    engine.mainMixerNode.outputVolume = isMuted || level == 0 ? 0 : 1
    endControls()
  }

  public func setMuted(_ muted: Bool) {
    beginControls()
    isMuted = muted
    engine.mainMixerNode.outputVolume = muted || level == 0 ? 0 : 1
    if muted {
      for index in voices.indices {
        voices[index].isActive = false
        voices[index].rescueLayers.removeAll()
      }
      recentEffectTimes.removeAll(keepingCapacity: true)
    }
    endControls()
    if muted {
      bufferedSource?.stop()
      if isRunning && engine.isRunning { bufferedSource?.start() }
    }
  }

  public var muted: Bool {
    beginControls()
    defer { endControls() }
    return isMuted
  }

  public var volume: Double {
    beginControls()
    defer { endControls() }
    return level
  }

  public var effectiveVolume: Double {
    beginControls(); defer { endControls() }
    return isMuted || outputSuspended ? 0 : level
  }
}
