extension SoundEffectPlayer {
  func prepareOfflineForCheck() throws {
    try engine.enableManualRenderingMode(.offline,
      format: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!, maximumFrameCount: 512)
  }

  func checkCameraMovement() throws {
    try prepareOfflineForCheck()
    try start()
    let tone = (0..<44100).map { Float(sin(Double($0) * 2 * .pi * 440 / 44100)) * 0.25 }
    let point = GameplaySoundPoint(x: 0, y: 80)
    setViewport(.init(x: 0, y: 0, width: 320, height: 160))
    play(samples: tone, rate: 44100, at: point)
    let slot = voices.firstIndex(where: { $0.isActive })!
    let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 512)!
    func energy() throws -> (Double, Double) {
      var l = 0.0, r = 0.0
      for step in 0..<12 {
        let status = try engine.renderOffline(512, to: buffer)
        precondition(status == .success)
        if step < 4 { continue }
        for frame in 0..<Int(buffer.frameLength) {
          l += pow(Double(buffer.floatChannelData![0][frame]), 2)
          r += pow(Double(buffer.floatChannelData![1][frame]), 2)
        }
      }
      return (l, r)
    }
    let left = try energy()
    setViewport(.init(x: -320, y: 0, width: 320, height: 160))
    let right = try energy()
    precondition(left.0 > left.1 && right.1 > right.0, "Active sound failed to follow the camera")
    setViewport(.init(x: 640, y: 0, width: 320, height: 160))
    precondition(voices[slot].distanceGain < 0.1 && spatialMixers[slot].position.x < 0)
    silence()
    setViewport(.init(x: 0, y: 0, width: 320, height: 160))
    play([PositionedSoundCue(.builderWarning, at: .init(x: 0, y: 80)),
          PositionedSoundCue(.builderWarning, at: .init(x: 4, y: 80)),
          PositionedSoundCue(.builderWarning, at: .init(x: 320, y: 80))])
    precondition(voices.filter(\.isActive).count == 2, "Spatial dedup collapsed opposite sides or stacked neighbours")
    stop(); engine.disableManualRenderingMode()
    print("PASS offline spatial output follows camera movement, offscreen distance and separate event positions")
  }

  func renderForCheck(pan: Float) throws -> (Double, Double) {
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
    try start()
    play(.builderWarning, pan: pan)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
    var left = 0.0, right = 0.0
    for _ in 0..<12 {
      let result = try engine.renderOffline(512, to: buffer)
      precondition(result == .success)
      for i in 0..<Int(buffer.frameLength) {
        let l = Double(buffer.floatChannelData![0][i])
        let r = Double(buffer.floatChannelData![1][i])
        precondition(l.isFinite && r.isFinite)
        left += l*l; right += r*r
      }
    }
    stop()
    engine.disableManualRenderingMode()
    return (left, right)
  }

  func pauseBacklogForCheck() throws -> (Double, Double) {
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
    try start()
    play(.builderWarning)
    suspendOutput()
    play(.builderWarning)
    try resumeOutput()
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
    func energy() throws -> Double {
      let result = try engine.renderOffline(512, to: buffer)
      precondition(result == .success)
      return (0..<Int(buffer.frameLength)).reduce(0) { total, index in
        total + abs(Double(buffer.floatChannelData![0][index]))
      }
    }
    let stale = try energy()
    play(.builderWarning)
    let fresh = try energy()
    stop()
    engine.disableManualRenderingMode()
    return (stale, fresh)
  }
}
let player = SoundEffectPlayer(voiceCount: 4)
try player.checkCameraMovement()
let left = try player.renderForCheck(pan: -1)
let right = try player.renderForCheck(pan: 1)
precondition(left.0 > left.1 && right.1 > right.0)
precondition(left.0 > 0 && right.1 > 0)
let backlog = try player.pauseBacklogForCheck()
precondition(backlog.0 == 0 && backlog.1 > 0)
try player.prepareOfflineForCheck()
try player.start()
player.setMuted(true)
player.play(.builderWarning)
player.suspendOutput()
try player.resumeOutput()
player.stop()
print("Spatial audio: finite output, positioning, restart, mute and pause backlog passed", left, right)

for width in [160.0, 320, 960] {
  let view = GameplaySoundViewport(x: 100, y: 50, width: width, height: 160)
  let centre = view.placement(of: .init(x: 100 + width / 2, y: 130))
  precondition(abs(centre.x) < 0.0001 && abs(centre.y) < 0.0001 && centre.gain == 1)
  precondition(view.placement(of: .init(x: 100, y: 130)).x < 0)
  precondition(view.placement(of: .init(x: 100 + width, y: 130)).x > 0)
  precondition(view.placement(of: .init(x: 100 + width / 2, y: 50)).y > 0)
  precondition(view.placement(of: .init(x: 100 + width / 2, y: 210)).y < 0)
  let invalid = view.placement(of: .init(x: .infinity, y: .nan))
  precondition(invalid.x == 0 && invalid.y == 0 && invalid.z == -1)
}
print("PASS camera geometry at zoomed, standard and wide aspect ratios, elevation and invalid-coordinate fallback")
