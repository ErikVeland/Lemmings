import AVFoundation
import Foundation
import NxlvKit

extension ModuleMusicPlayer {
    func checkBufferedPlayback() throws {
        var bytes = [UInt8](repeating: 0, count: 1084 + 1024 + 64)
        bytes[950] = 1
        for (index, value) in "M.K.".utf8.enumerated() { bytes[1080 + index] = value }
        bytes[43] = 32; bytes[45] = 64; bytes[49] = 32
        bytes[1084] = 1; bytes[1085] = 172; bytes[1086] = 16
        // End the pattern on row two to exercise repeated tracker restart and crossfade.
        bytes[1102] = 0x0D
        for frame in 0..<64 { bytes[2108 + frame] = UInt8(bitPattern: frame < 32 ? 100 : -100) }
        let module = try ProTrackerModule(data: Data(bytes))
        load(module, url: URL(fileURLWithPath: "/tmp/buffer-fixture.mod"))
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
        defer { stop(); engine.disableManualRenderingMode() }
        try start()
        synthesisQueue.sync {}
        precondition(sourceNode?.isPlaying == true && scheduledFrames == 4096)
        let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
        // A control thread may hold the synthesis lock. Buffered rendering must still complete.
        lock.lock()
        let begin = DispatchTime.now().uptimeNanoseconds
        let status = try engine.renderOffline(512, to: output)
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - begin) / 1_000_000
        lock.unlock()
        precondition(status == .success)
        var energy = 0.0
        var previousSeconds = 0.0
        for _ in 0..<80 {
            let result = try engine.renderOffline(512, to: output)
            precondition(result == .success)
            synthesisQueue.sync {}
            for channel in 0..<2 {
                for frame in 0..<Int(output.frameLength) {
                    let sample = output.floatChannelData![channel][frame]
                    precondition(sample.isFinite)
                    energy += Double(sample * sample)
                }
            }
            let seconds = sourceSeconds
            precondition(seconds >= previousSeconds - 0.025)
            previousSeconds = seconds
        }
        precondition(energy > 0 && previousSeconds > 0.5 && scheduledFrames > 4096)
        precondition(previousLoopTail.count == loopCrossfadeFrames)
        setMuted(true)
        precondition(spatialMixer.outputVolume == 0)
        stop()
        try start()
        synthesisQueue.sync {}
        precondition(scheduledFrames == 4096 && sourceNode?.isPlaying == true)
        precondition(spatialMixer.outputVolume == 0)
        print("PASS queued MOD playback, finite signal, source clock, refill, loop crossfade, immediate mute and restart; render with synthesis lock held: \(elapsed) ms")
    }
}

extension SoundEffectPlayer {
    func checkIdleWorkAndHistory() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        output.frameLength = 1024
        let buffers = UnsafeMutableAudioBufferListPointer(output.mutableAudioBufferList)
        for index in voices.indices { fillVoice(index, buffers: buffers, frames: 1024, sampleTime: 0) }
        precondition((0..<1024).allSatisfy { output.floatChannelData![0][$0] == 0 && recentSamplePositions[$0] == Int64($0) })
        voices[1] = Voice(samples: [Float](repeating: 0.1, count: 1024), isActive: true)
        voices[3] = Voice(samples: [Float](repeating: 0.2, count: 1024), isActive: true)
        // Silent sources before and after active sources must not erase the mixed history.
        for index in voices.indices { fillVoice(index, buffers: buffers, frames: 1024, sampleTime: 1024) }
        precondition((1024..<2048).allSatisfy { abs(recentSamples[$0] - 0.3) < 0.00001 })
        silence()
        let begin = DispatchTime.now().uptimeNanoseconds
        for block in 0..<100 {
            for index in voices.indices { fillVoice(index, buffers: buffers, frames: 1024, sampleTime: Double((block + 2) * 1024)) }
        }
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - begin) / 1_000_000 / 100
        print("PASS 64 silent spatial sources and exact mixed rewind history; idle 1024-frame block: \(elapsed) ms (host debug build)")
    }
}

try ModuleMusicPlayer().checkBufferedPlayback()
SoundEffectPlayer().checkIdleWorkAndHistory()
