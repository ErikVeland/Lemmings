import AVFoundation
import AudioToolbox
import os
import Foundation

/// PCM synthesis runs on a worker. Device callbacks only consume queued buffers.
/// Four blocks bound control latency to 46 ms at 44.1 kHz, plus the device buffer.
final class BufferedAudioSource: @unchecked Sendable {
  private final class Batch: @unchecked Sendable {
    let buffers: [AVAudioPCMBuffer]
    var pending: Int = 0
    init(format: AVAudioFormat, count: Int, frames: Int) {
      buffers = (0..<count).map { _ in
        AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
      }
    }
  }
  let nodes: [AVAudioPlayerNode]
  let frames = 512
  let depth = 4
  private let queue: DispatchQueue
  private let format: AVAudioFormat
  private let fill: @Sendable (Int, AVAudioPCMBuffer, Int64) -> Void
  private var generation = 0
  private var running = false
  private var nextFrame: Int64 = 0
  private var startFrame: Int64 = 0
  private var lastPlayedFrame: Int64 = 0
  private var statistics = AudioBufferStatistics()
  private var batches: [Batch] = []

  init(label: String, format: AVAudioFormat, count: Int = 1,
       fill: @escaping @Sendable (Int, AVAudioPCMBuffer, Int64) -> Void) {
    queue = DispatchQueue(label: label, qos: .userInteractive)
    self.format = format; self.fill = fill
    nodes = (0..<count).map { _ in AVAudioPlayerNode() }
    batches = (0..<depth).map { _ in Batch(format: format, count: count, frames: frames) }
  }

  /// Call after starting the engine. Never hold the synthesis lock.
  func start() {
    queue.sync {
      guard !running || !nodes.allSatisfy(\.isPlaying) else { return }
      if running { for node in nodes { node.stop() } }
      generation &+= 1
      running = true
      statistics.starts += 1
      startFrame = nextFrame
      lastPlayedFrame = startFrame
      for batch in batches { schedule(batch, token: generation) }
      for node in nodes { node.play() }
    }
  }

  func stop() {
    queue.sync {
      lastPlayedFrame = currentPlayedFrame()
      running = false
      generation &+= 1
      for node in nodes { node.stop() }
    }
  }

  func drain() { queue.sync {} }
  var playedFrame: Int64 { queue.sync { currentPlayedFrame() } }
  private func currentPlayedFrame() -> Int64 {
    guard running, let time = nodes[0].lastRenderTime,
      let played = nodes[0].playerTime(forNodeTime: time) else { return lastPlayedFrame }
    return startFrame + played.sampleTime
  }
  var diagnostics: AudioBufferStatistics { queue.sync { statistics } }

  private func schedule(_ batch: Batch, token: Int) {
    guard running, generation == token else { return }
    let began = ProcessInfo.processInfo.systemUptime
    for (index, buffer) in batch.buffers.enumerated() {
      buffer.frameLength = AVAudioFrameCount(frames)
      fill(index, buffer, nextFrame)
    }
    nextFrame += Int64(frames)
    statistics.recordRefill(seconds: ProcessInfo.processInfo.systemUptime - began,
      reserveSeconds: Double(frames * (depth - 1)) / format.sampleRate)
    batch.pending = nodes.count
    for (index, node) in nodes.enumerated() {
      node.scheduleBuffer(batch.buffers[index], completionCallbackType: .dataConsumed) { [weak self] _ in
        guard let self else { return }
        self.queue.async { [weak self] in
          guard let self, self.running, self.generation == token else { return }
          batch.pending -= 1
          // All spatial nodes must release their buffer before any buffer is reused.
          if batch.pending == 0 {
            if let time = self.nodes[0].lastRenderTime,
               let played = self.nodes[0].playerTime(forNodeTime: time) {
              self.statistics.observeReserve(frames: max(0, self.nextFrame - self.startFrame - played.sampleTime))
            }
            self.schedule(batch, token: token)
          }
        }
      }
    }
  }
}

/// Worker measurements, not a hardware underrun counter. Safe to export off the audio thread.
public struct AudioBufferStatistics: Codable, Sendable {
  private static let logger = Logger(subsystem: "com.ultimatelemmings.audio", category: "PCM")
  public internal(set) var starts = 0
  public internal(set) var refills = 0
  public internal(set) var refillFailures = 0
  public internal(set) var refillsOverReserve = 0
  public internal(set) var maximumRefillSeconds = 0.0
  public internal(set) var lastError: String?
  public internal(set) var emptyReserveObservations = 0
  public internal(set) var minimumReserveFrames: Int64?

  mutating func observeReserve(frames: Int64) {
    minimumReserveFrames = min(minimumReserveFrames ?? frames, frames)
    if frames == 0 { emptyReserveObservations += 1 }
  }

  mutating func recordRefill(seconds: Double, reserveSeconds: Double) {
    refills += 1
    maximumRefillSeconds = max(maximumRefillSeconds, seconds)
    if seconds > reserveSeconds {
      refillsOverReserve += 1
      if refillsOverReserve == 1 {
        Self.logger.error("Audio refill exceeded reserve: \(seconds, privacy: .public) seconds, reserve \(reserveSeconds, privacy: .public)")
      }
    }
  }
  mutating func recordFailure(_ error: Error) {
    refillFailures += 1
    lastError = String(describing: error)
    Self.logger.error("Audio refill failed: \(String(describing: error), privacy: .public)")
  }
}

/// Peak protection follows EQ, pitch and reverb so their boosts cannot clip.
enum MusicOutputSafety {
  static func limiter() -> AVAudioUnitEffect {
    AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
      componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_PeakLimiter,
      componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0))
  }
}

