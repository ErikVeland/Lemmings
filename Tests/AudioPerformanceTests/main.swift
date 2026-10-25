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
        precondition(sourceNode?.isPlaying == true && scheduledFrames == Int64(bufferedFrameCount * bufferCount))
        let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
        // A control thread may hold the synthesis lock. Buffered rendering must still complete.
        lock.lock()
        let begin = DispatchTime.now().uptimeNanoseconds
        let status = try engine.renderOffline(512, to: output)
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - begin) / 1_000_000
        // Cover a 140 ms worker stall, beyond the old 93 ms reserve.
        for _ in 0..<11 {
            let bufferedStatus = try engine.renderOffline(512, to: output)
            precondition(bufferedStatus == .success)
        }
        let bufferedEnergy = (0..<Int(output.frameLength)).reduce(0.0) {
            $0 + abs(Double(output.floatChannelData![0][$1]))
        }
        lock.unlock()
        precondition(status == .success)
        precondition(bufferedEnergy > 0.01, "Tracker reserve ran dry during a bounded synthesis stall")
        // The reverse source shares this engine and runs during forward music.
        // A UI command or recorder must never block its render callback.
        rewindAudio.drain()
        var energy = 0.0
        var previousSeconds = 0.0
        for _ in 0..<80 {
            let result = try engine.renderOffline(512, to: output)
            precondition(result == .success)
            synthesisQueue.sync {}
            rewindAudio.drain()
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
        precondition(energy > 0 && previousSeconds > 0.5 && scheduledFrames > Int64(bufferedFrameCount * bufferCount))
        precondition(previousLoopTail.count == loopCrossfadeFrames)
        // The first loop sample must join the final sample, rather than jump
        // back to the beginning of the saved tail.
        lock.lock()
        previousLoopTail = [(left: -0.7, right: 0.7), (left: 0.3, right: -0.3)]
        loopBlendIndex = 0
        let join = nextSourceFrameLocked()
        lock.unlock()
        precondition(abs(join.left - 0.3) < 0.00001 && abs(join.right + 0.3) < 0.00001)
        engine.stop()
        try resumeOutput()
        synthesisQueue.sync {}
        precondition(sourceNode?.isPlaying == true && engine.isRunning, "Tracker did not restore its queue after engine reset")
        setMuted(true)
        precondition(spatialMixer.outputVolume == 0)
        stop()
        try start()
        synthesisQueue.sync {}
        precondition(scheduledFrames == Int64(bufferedFrameCount * bufferCount) && sourceNode?.isPlaying == true)
        precondition(spatialMixer.outputVolume == 0)
        print("PASS queued MOD playback, finite signal, source clock, refill, loop crossfade, immediate mute and restart; render with synthesis lock held: \(elapsed) ms")
    }
}

extension MusicRewindBuffer {
    func checkBufferedReverse() throws {
        let engine = AVAudioEngine()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let node = source(format: format)
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
        let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
        input.frameLength = 44100
        for channel in 0..<2 {
            for frame in 0..<44100 { input.floatChannelData![channel][frame] = Float(sin(Double(frame) * 0.05)) * 0.2 }
        }
        record(input)
        try engine.start()
        precondition(trigger())
        let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
        lock.lock()
        let began = ProcessInfo.processInfo.systemUptime
        var energy = 0.0
        for _ in 0..<2 {
            let status = try engine.renderOffline(512, to: output)
            precondition(status == .success)
            record(output)
            energy += (0..<512).reduce(0) { $0 + abs(Double(output.floatChannelData![0][$1])) }
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - began
        lock.unlock()
        precondition(energy > 0.01 && elapsed < 0.1, "Reverse audio stopped during a bounded control stall")
        cancel()
        engine.stop()
        engine.disableManualRenderingMode()
        print("PASS buffered reverse audio survives a held history lock without zeroing output")
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
        precondition((1024..<1984).allSatisfy { abs(recentSamples[$0] - 0.18) < 0.00001 })
        precondition(recentSamples[2047] == 0, "Effect endpoint did not fade out")
        silence()
        let begin = DispatchTime.now().uptimeNanoseconds
        for block in 0..<100 {
            for index in voices.indices { fillVoice(index, buffers: buffers, frames: 1024, sampleTime: Double((block + 2) * 1024)) }
        }
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - begin) / 1_000_000 / 100
        print("PASS \(voices.count) silent spatial sources and exact mixed rewind history; idle 1024-frame block: \(elapsed) ms (host debug build)")
    }
}

try ModuleMusicPlayer().checkBufferedPlayback()
let reverseBuffer = MusicRewindBuffer()
try reverseBuffer.checkBufferedReverse()
SoundEffectPlayer().checkIdleWorkAndHistory()

extension SoundEffectPlayer {
    func checkResourceAdmission() {
        let budget = fixedResources!
        precondition(voices.count == budget.audioVoiceLimit)
        library[.yippee] = [Float](repeating: 0.1, count: 44_100)
        rates[.yippee] = 44_100
        let cues = [PositionedSoundCue](repeating: .init(.yippee, at: .init(x: 80, y: 80)), count: 4_000)
        play(cues)
        func rescues() -> Int {
            voices.reduce(0) { $0 + ($1.isActive && $1.isRescue ? 1 : 0) + $1.rescueLayers.count }
        }
        precondition(rescues() == budget.rescueVoiceLimit, "Rescue overflow escaped the device budget")
        for _ in 0..<4_000 { play(samples: [0.1, 0.2], rate: 44_100) }
        play(.timerWarning)
        precondition(voices.filter(\.isActive).count <= budget.audioVoiceLimit)
        precondition(rescues() <= budget.rescueVoiceLimit)
        precondition(voices.contains { $0.isActive && $0.priority == ClassicSoundEffect.timerWarning.presentationPriority },
                     "Stacked effects prevented a warning")
        applyVoiceBudgetLocked(voiceLimit: 6, rescueLimit: 2)
        precondition(voices.filter(\.isActive).count <= 6 && rescues() <= 2,
                     "Pressure failed to trim existing sources and rescue layers")
        precondition(voices.contains { $0.isActive && $0.priority == ClassicSoundEffect.timerWarning.presentationPriority },
                     "Pressure trimmed the warning before decorative effects")
        setVoiceLimit(6)
        for _ in 0..<4_000 { play(samples: [0.1, 0.2], rate: 44_100) }
        precondition(voices.filter(\.isActive).count <= 6, "Later sounds bypassed the reduced admission limit")
        let replay = replayPlayer()
        precondition(replay.requestedVoiceLimit == requestedVoiceLimit && replay.rescueVoiceLimit == rescueVoiceLimit,
                     "Replay discarded the source device's audio budget")
        silence()
        precondition(voices.allSatisfy { !$0.isActive && $0.rescueLayers.isEmpty })
    }
}
for gib in [2, 4, 8, 16] {
    let resources = DeviceEffectResources(physicalMemory: UInt64(gib) * 1_073_741_824, processorCount: 8)
    SoundEffectPlayer(resources: resources).checkResourceAdmission()
    SoundEffectPlayer(resources: resources.underPressure(thermalLevel: 0, lowPower: false, memoryPressure: true)).checkResourceAdmission()
}
print("PASS bounded sources and rescue layers on 2/4/8/16 GiB devices, pressure trimming, warning priority and replay budgets")


extension SoundEffectPlayer {
    func checkBufferedEffects() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
        let tone = (0..<44100).map { Float(sin(Double($0) * 0.05)) * 0.9 }
        for _ in voices.indices { play(samples: tone, rate: 44100, gain: 1) }
        try start()
        defer { stop(); engine.disableManualRenderingMode() }
        let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
        for _ in 0..<16 {
            let status = try engine.renderOffline(512, to: output)
            precondition(status == .success)
            bufferedSource?.drain()
        }
        lock.lock()
        let began = ProcessInfo.processInfo.systemUptime
        var energy = 0.0
        for _ in 0..<2 {
            let status = try engine.renderOffline(512, to: output)
            precondition(status == .success)
            for frame in 0..<512 {
                let sample = output.floatChannelData![0][frame]
                precondition(sample.isFinite && abs(sample) <= 1.001, "Effect chorus clipped")
                energy += Double(sample * sample)
            }
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - began
        lock.unlock()
        precondition(energy > 1 && elapsed < 0.1, "Effect output waited for a control lock")
        bufferedSource?.drain()
        setMuted(true)
        for _ in 0..<6 {
            let status = try engine.renderOffline(512, to: output)
            precondition(status == .success)
            bufferedSource?.drain()
            precondition((0..<512).allSatisfy { output.floatChannelData![0][$0] == 0 }, "Mute leaked queued effects")
        }
        print("PASS buffered spatial chorus survives control contention, limits peaks and mutes queued PCM")
    }
}
let bufferedEffects = SoundEffectPlayer(voiceCount: 24)
try bufferedEffects.checkBufferedEffects()
let callbackEffects = SoundEffectPlayer(voiceCount: 4)
callbackEffects.onPlay = { [weak callbackEffects] _, _, _ in callbackEffects?.setVolume(0.5) }
callbackEffects.play(.builderWarning)
precondition(callbackEffects.volume == 0.5, "Replay callback did not run synchronously outside the effects lock")
print("PASS synchronous replay capture can re-enter effect controls without blocking synthesis")
