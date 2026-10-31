// This test uses the device clock. Run through Tools/UITestRunner/run.py to mute output.
import AVFoundation
import Foundation
import NxlvKit

private final class LiveSignalProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var blocks = 0
    private var zeroRun = 0
    private var longestZeroRun = 0
    private var peak: Float = 0
    private var heardSignal = false

    func record(_ buffer: AVAudioPCMBuffer) {
        lock.lock(); defer { lock.unlock() }
        blocks += 1
        // Ignore leading silence only. Retain gaps after the first audible sample.
        for frame in 0..<Int(buffer.frameLength) {
            var magnitude: Float = 0
            for channel in 0..<Int(buffer.format.channelCount) {
                magnitude = max(magnitude, abs(buffer.floatChannelData![channel][frame]))
            }
            if magnitude >= 0.000001 { heardSignal = true }
            guard heardSignal else { continue }
            peak = max(peak, magnitude)
            zeroRun = magnitude < 0.000001 ? zeroRun + 1 : 0
            longestZeroRun = max(longestZeroRun, zeroRun)
        }
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        blocks = 0; zeroRun = 0; longestZeroRun = 0; peak = 0; heardSignal = false
    }

    func result() -> (blocks: Int, gap: Int, peak: Float) {
        lock.lock(); defer { lock.unlock() }
        return (blocks, longestZeroRun, peak)
    }
}

extension SoundEffectPlayer {
    fileprivate func checkLiveStartAndNuke() throws -> Bool {
        let probe = LiveSignalProbe()
        let tone = (0..<441_000).map { Float(sin(Double($0) * 0.04)) * 0.1 }
        for _ in voices.indices { play(samples: tone, rate: 44100, gain: 0.5) }
        try start()
        environment.installTap(onBus: 0, bufferSize: 512, format: nil) { buffer, _ in probe.record(buffer) }
        defer { environment.removeTap(onBus: 0); stop() }
        // No worker drains or manual rendering: the hardware clock keeps running.
        Thread.sleep(forTimeInterval: 1)
        library[.explode] = Array(tone.prefix(22_050))
        rates[.explode] = 44100
        setNukeActive(true)
        for tick in 0..<40 {
            play(.explode, at: .init(x: Double((tick % 12) * 32), y: 20))
            Thread.sleep(forTimeInterval: 0.05)
        }
        setNukeActive(false)
        let signal = probe.result()
        let stats = audioDiagnostics
        print("LIVE voices=\(voices.count) blocks=\(signal.blocks) longest_zero_run=\(signal.gap) peak=\(signal.peak)")
        print(String(data: try JSONEncoder().encode(stats), encoding: .utf8)!)
        return signal.blocks > 10 && signal.peak > 0.01 && signal.gap < 512
            && stats.refills > 20 && stats.emptyReserveObservations == 0
            && stats.queueWaitsOverReserve == 0 && stats.refillFailures == 0
    }
}

private func checkFirstVoiceStartup(count: Int) throws -> Bool {
    let engine = AVAudioEngine()
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    let source = BufferedAudioSource(label: "test.live-start", format: format, count: count) { _, buffer, time in
        for frame in 0..<Int(buffer.frameLength) {
            buffer.floatChannelData![0][frame] = Float(sin(Double(time + Int64(frame)) * 0.04)) * 0.1
        }
    }
    for node in source.nodes {
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }
    let probe = LiveSignalProbe()
    source.nodes[0].installTap(onBus: 0, bufferSize: 512, format: format) { buffer, _ in probe.record(buffer) }
    try engine.start()
    defer { source.stop(); engine.stop(); source.nodes[0].removeTap(onBus: 0) }
    // Capture starts before source.start(), including the sequential player starts.
    var passed = true
    for attempt in 0..<3 {
        probe.reset()
        source.start()
        Thread.sleep(forTimeInterval: 1)
        let signal = probe.result()
        print("FIRST VOICE count=\(count) attempt=\(attempt) blocks=\(signal.blocks) longest_zero_run=\(signal.gap) peak=\(signal.peak)")
        passed = passed && signal.blocks > 5 && signal.peak > 0.01 && signal.gap < 512
        engine.pause()
        source.stop()
        if attempt < 2 { try engine.start() }
    }
    return passed
}

private func checkQueuedEffectsResume() throws -> Bool {
    let commands = AudioPlaybackQueue(label: "test.live-effects-controls")
    let player = SoundEffectPlayer(voiceCount: 24)
    let ready = DispatchSemaphore(value: 0)
    commands.submit(persistent: true) { try? player.start(); ready.signal() }
    guard ready.wait(timeout: .now() + 5) == .success else { return false }
    var longestSubmission = 0.0
    for _ in 0..<5 {
        let completed = DispatchSemaphore(value: 0)
        let began = ProcessInfo.processInfo.systemUptime
        commands.cancelPending()
        commands.submit(persistent: true) { player.suspendOutput() }
        commands.submit { try? player.resumeOutput(); completed.signal() }
        longestSubmission = max(longestSubmission, ProcessInfo.processInfo.systemUptime - began)
        guard completed.wait(timeout: .now() + 5) == .success else { return false }
    }
    let stopped = DispatchSemaphore(value: 0)
    commands.submit(persistent: true) { player.stop(); stopped.signal() }
    guard stopped.wait(timeout: .now() + 5) == .success else { return false }
    print("QUEUED EFFECTS longest_submission_seconds=\(longestSubmission)")
    return longestSubmission < 0.05
}

do {
    var passed = try checkQueuedEffectsResume()
    if try !checkFirstVoiceStartup(count: 24) { passed = false }
    if try !checkFirstVoiceStartup(count: 1) { passed = false }
    for count in [24, 12, 24] {
        let resources = DeviceEffectResources(physicalMemory: 16 * 1_073_741_824, processorCount: 8)
        let player = SoundEffectPlayer(voiceCount: count, rescueVoiceLimit: 6, resources: resources)
        if try !player.checkLiveStartAndNuke() { passed = false }
    }
    print(passed ? "PASS muted live-clock level starts and nuke bursts" : "FAIL live-clock audio reserve or signal gap")
    exit(passed ? 0 : 1)
} catch {
    print("FAIL live-clock audio: \(error)")
    exit(1)
}
