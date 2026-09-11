extension SoundEffectPlayer {
  func renderForCheck(pan: Float) throws -> (Double, Double) {
    try start()
    engine.stop()
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
    try engine.start()
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
}
let player = SoundEffectPlayer(voiceCount: 4)
let left = try player.renderForCheck(pan: -1)
let right = try player.renderForCheck(pan: 1)
precondition(left.0 > left.1 && right.1 > right.0)
precondition(left.0 > 0 && right.1 > 0)
try player.start()
player.setMuted(true)
player.play(.builderWarning)
player.suspendOutput()
try player.resumeOutput()
player.stop()
print("Spatial audio: finite output, left/right positioning, restart, mute and pause/resume passed", left, right)
