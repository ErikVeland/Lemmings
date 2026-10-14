import AVFoundation
import Foundation
import NxlvKit

/// A bounded stereo groove shared by recording and tracker transports.
/// Capture excludes reverse output. The prewired source can scratch while the
/// normal music transport is parked, without decoding on the audio callback.
final class MusicRewindBuffer: @unchecked Sendable {
  static let seconds = 12.0
  static let impulseSeconds = VinylBackspin.seconds
  private let lock = NSLock()
  let sampleRate: Double
  private var left: [Float]
  private var right: [Float]
  private var written: Int64 = 0
  private var readHead = 0.0
  private var remaining = 0
  private var total = 0
  private var attackFrames = 0
  private var recording = true
  private var gain: Float = 1
  private var lastTrigger = -Double.infinity
  private var anchorWritten: Int64 = -1

  init(sampleRate: Double = 44_100) {
    self.sampleRate = sampleRate
    let capacity = max(2, Int(sampleRate * Self.seconds))
    left = .init(repeating: 0, count: capacity)
    right = .init(repeating: 0, count: capacity)
  }

  var isRewinding: Bool { lock.lock(); defer { lock.unlock() }; return remaining > 0 }
  func setRecording(_ enabled: Bool) { lock.lock(); recording = enabled; lock.unlock() }
  func setGain(_ value: Float) { lock.lock(); gain = min(1, max(0, value)); lock.unlock() }

  func record(_ buffer: AVAudioPCMBuffer) {
    guard let channels = buffer.floatChannelData else { return }
    record(left: channels[0], right: channels[Int(buffer.format.channelCount) > 1 ? 1 : 0], frames: Int(buffer.frameLength))
  }

  func record(left sourceLeft: UnsafePointer<Float>, right sourceRight: UnsafePointer<Float>, frames: Int) {
    // History is optional. Never delay the forward audio for a scratch control.
    guard lock.try() else { return }
    defer { lock.unlock() }
    guard recording, remaining == 0 else { return }
    for index in 0..<frames {
      let slot = Int(written % Int64(left.count))
      left[slot] = sourceLeft[index]; right[slot] = sourceRight[index]
      written += 1
    }
  }

  /// Repeated taps extend the same reverse read rather than layering copies.
  @discardableResult func trigger(skipping frames: Int = 0) -> Bool {
    lock.lock(); defer { lock.unlock() }
    guard written > 1 else { return false }
    let now = ProcessInfo.processInfo.systemUptime
    if remaining == 0 && (now - lastTrigger > VinylBackspin.settleSeconds || anchorWritten != written || readHead < Double(max(0, written - Int64(left.count)))) {
      readHead = Double(max(max(0, written - Int64(left.count)), written - 1 - Int64(max(0, frames))))
    }
    anchorWritten = written
    lastTrigger = now
    if remaining == 0 { attackFrames = 0 }
    total = Int(sampleRate * Self.impulseSeconds)
    remaining = total
    return true
  }

  func cancel(clearHistory: Bool = false) {
    lock.lock(); defer { lock.unlock() }
    remaining = 0
    if clearHistory { written = 0; readHead = 0; lastTrigger = -.infinity; anchorWritten = -1 }
  }

  func source(format: AVAudioFormat) -> AVAudioSourceNode {
    AVAudioSourceNode(format: format) { [weak self] _, _, frames, output in
      let buffers = UnsafeMutableAudioBufferListPointer(output)
      if let self { self.render(buffers, frames: Int(frames)) }
      else { for buffer in buffers { memset(buffer.mData, 0, Int(buffer.mDataByteSize)) } }
      return noErr
    }
  }

  func render(_ buffers: UnsafeMutableAudioBufferListPointer, frames: Int) {
    // This source runs even when no scratch is playing. It must not wait for
    // the recorder or a UI command on the device's render thread.
    guard lock.try() else {
      for buffer in buffers { memset(buffer.mData, 0, Int(buffer.mDataByteSize)) }
      return
    }
    defer { lock.unlock() }
    guard remaining > 0 else {
      for buffer in buffers { memset(buffer.mData, 0, Int(buffer.mDataByteSize)) }
      return
    }
    let oldest = max(0, written - Int64(left.count))
    for index in 0..<frames {
      var l: Float = 0, r: Float = 0
      if remaining > 0, readHead >= Double(oldest), written > 1 {
        let position = Int64(readHead)
        let lower = Int(position % Int64(left.count))
        let upper = Int(min(written - 1, position + 1) % Int64(left.count))
        let fraction = Float(readHead - Double(position))
        let vinyl = VinylBackspin.sample(frame: Double(total - remaining), sampleRate: sampleRate, attackFrame: Double(attackFrames))
        let historyFade = Float(min(1, max(0, (readHead - Double(oldest)) / (sampleRate * 0.020 * vinyl.rate))))
        let envelope = min(vinyl.gain, historyFade) * gain
        l = (left[lower] + (left[upper] - left[lower]) * fraction) * envelope
        r = (right[lower] + (right[upper] - right[lower]) * fraction) * envelope
        readHead -= vinyl.rate
        attackFrames += 1
        remaining -= 1
      } else { remaining = 0 }
      for channel in buffers.indices {
        buffers[channel].mData?.assumingMemoryBound(to: Float.self)[index] = channel == 0 ? l : r
      }
    }
  }
}
