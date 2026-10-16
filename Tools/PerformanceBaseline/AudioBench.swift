// Compile after the frozen audio player sources in one generated Swift file.
import AVFoundation
import Foundation
import NxlvKit

extension SoundEffectPlayer {
    func baselineBlocks(active: Bool) -> [Double] {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        output.frameLength = 1024
        let buffers = UnsafeMutableAudioBufferListPointer(output.mutableAudioBufferList)
        let samples = [Float](repeating: 0.1, count: 1024 * 256)
        var times: [Double] = []
        for repeatIndex in 0..<8 {
            silence()
            if active {
                for index in voices.indices { voices[index] = Voice(samples: samples, isActive: true) }
            }
            let start = DispatchTime.now().uptimeNanoseconds
            for block in 0..<128 {
                for index in voices.indices {
                    fillVoice(index, buffers: buffers, frames: 1024, sampleTime: Double(block * 1024))
                }
            }
            let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000 / 128
            if repeatIndex > 0 { times.append(ms) }
        }
        return times
    }
}

extension ModuleMusicPlayer {
    func baselineSynthesis() throws -> [Double] {
        var bytes = [UInt8](repeating: 0, count: 1084 + 1024 + 64)
        bytes[950] = 1
        for (index, value) in "M.K.".utf8.enumerated() { bytes[1080 + index] = value }
        bytes[43] = 32; bytes[45] = 64; bytes[49] = 32
        bytes[1084] = 1; bytes[1085] = 172; bytes[1086] = 16; bytes[1102] = 0x0D
        for index in 0..<64 { bytes[2108 + index] = UInt8(bitPattern: index < 32 ? 100 : -100) }
        let module = try ProTrackerModule(data: Data(bytes))
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        output.frameLength = 1024
        let buffers = UnsafeMutableAudioBufferListPointer(output.mutableAudioBufferList)
        var times: [Double] = []
        for repeatIndex in 0..<8 {
            load(module, url: URL(fileURLWithPath: "/tmp/lemmings-baseline-fixture.mod"))
            fill(buffers, frames: 1024)
            let start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<128 { fill(buffers, frames: 1024) }
            let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000 / 128
            if repeatIndex > 0 { times.append(ms) }
        }
        return times
    }
}

do {
    let budget = DeviceEffectResources(physicalMemory: 8 * 1_073_741_824, processorCount: 8)
    let effects = SoundEffectPlayer(resources: budget)
    let results: [String: [Double]] = [
        "sfx-idle-1024-frames-ms": effects.baselineBlocks(active: false),
        "sfx-active-1024-frames-ms": effects.baselineBlocks(active: true),
        "mod-worker-1024-frames-ms": try ModuleMusicPlayer().baselineSynthesis(),
    ]
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(results).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    print("PASS offline synthesis and \(budget.audioVoiceLimit) silent/active effect sources. No audio engine started.")
} catch { fputs("ERROR: \(error)\n", stderr); exit(1) }
