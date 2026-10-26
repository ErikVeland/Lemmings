import AppKit
import AVFoundation
import Foundation
import NxlvKit

struct MusicRewindFailure: Error { let message: String }
func assertMusicRewind(_ value: Bool, _ message: String) throws {
    if !value { throw MusicRewindFailure(message: message) }
}
func stereoBuffer(_ frames: Int) -> AVAudioPCMBuffer {
    let result = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!, frameCapacity: AVAudioFrameCount(frames))!
    result.frameLength = AVAudioFrameCount(frames)
    return result
}
func energy(_ buffer: AVAudioPCMBuffer) -> Double {
    (0..<Int(buffer.frameLength)).reduce(0) { $0 + abs(Double(buffer.floatChannelData![0][$1])) }
}
extension MusicRewindBuffer {
    fileprivate var capturedFrames: Int64 { lock.lock(); defer { lock.unlock() }; return written }
    fileprivate var cursor: Double { lock.lock(); defer { lock.unlock() }; return readHead }
}
func checkReverseGroove() throws {
    let history = MusicRewindBuffer()
    try assertMusicRewind(!history.trigger(), "Empty history produced a pretend music rewind")
    let source = stereoBuffer(44100)
    for i in 0..<44100 {
        source.floatChannelData![0][i] = Float(i) / 44100
        source.floatChannelData![1][i] = -Float(i) / 88200
    }
    history.record(source)
    let count = history.capturedFrames
    try assertMusicRewind(history.trigger(), "A recorded groove could not reverse")
    let reverse = stereoBuffer(1024)
    history.render(UnsafeMutableAudioBufferListPointer(reverse.mutableAudioBufferList), frames: 1024)
    for i in 900..<1024 {
        let l = reverse.floatChannelData![0][i], r = reverse.floatChannelData![1][i]
        try assertMusicRewind(l > 0 && abs(l / -2 - r) < 0.00001, "Rewind lost its stereo channels")
        try assertMusicRewind(l < reverse.floatChannelData![0][i - 1], "Music samples travelled forwards")
    }
    history.record(source)
    try assertMusicRewind(history.capturedFrames == count, "Reverse audio fed back into the groove")
    let cursor = history.cursor
    history.cancel()
    try assertMusicRewind(history.trigger() && history.cursor == cursor, "Rapid taps restarted the same music fragment")
    for _ in 0..<24 { history.render(UnsafeMutableAudioBufferListPointer(reverse.mutableAudioBufferList), frames: 1024) }
    try assertMusicRewind(!history.isRewinding && energy(reverse) == 0, "Reverse impulse did not reach silence")
    history.cancel(clearHistory: true)
    try assertMusicRewind(!history.trigger(), "A new track retained the previous groove")
    print("PASS backwards PCM, stereo, rapid-tap continuation, no self-feedback, bounded impulse and track reset")
}

func checkBackspinPitchAndEdges() throws {
    for rate in [44_100.0, 48_000.0] {
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
        let source = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(rate))!
        source.frameLength = source.frameCapacity
        for i in 0..<Int(source.frameLength) {
            let tone = Float(sin(Double(i) * 2 * .pi * 440 / rate)) * 0.3
            source.floatChannelData![0][i] = tone
            source.floatChannelData![1][i] = -tone * 0.5
        }
        let history = MusicRewindBuffer(sampleRate: rate)
        history.record(source)
        try assertMusicRewind(history.trigger(), "Tone history could not backspin")
        let count = Int(rate * VinylBackspin.seconds)
        let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count + 1))!
        output.frameLength = output.frameCapacity
        history.render(UnsafeMutableAudioBufferListPointer(output.mutableAudioBufferList), frames: count + 1)
        let samples = output.floatChannelData![0]
        func crossings(_ start: Double, _ end: Double) -> Int {
            (Int(rate * start)..<Int(rate * end)).filter { samples[$0] * samples[$0 + 1] < 0 }.count
        }
        try assertMusicRewind(crossings(0.03, 0.13) > 2 * crossings(0.30, 0.40),
            "Backspin pitch did not fall from a fast reverse to a slow stop")
        try assertMusicRewind(samples[0] == 0 && samples[count - 1] == 0 && samples[count] == 0,
            "Backspin clicked at an endpoint")
        try assertMusicRewind((0..<count).allSatisfy { samples[$0].isFinite && abs(samples[$0]) <= 0.3 },
            "Backspin introduced an invalid or boosted sample")
        try assertMusicRewind((1..<Int(rate * 0.010)).allSatisfy { abs(samples[$0] - samples[$0 - 1]) < 0.025 },
            "Backspin started with a sharp transient")
        try assertMusicRewind(!history.isRewinding, "Backspin continued after its stop")
    }
    print("PASS 480 ms backspin, falling source pitch, soft endpoints and bounded attack at 44.1 and 48 kHz")
}

extension SoundtrackPlayer {
    @MainActor fileprivate func installRewindTestDeck(_ deck: MusicFileDeck) { player = deck }
}
extension MusicFileDeck {
    @MainActor fileprivate static func checkRecordingRewind() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("music-rewind-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let source = stereoBuffer(44100 * 3)
        for i in 0..<Int(source.frameLength) {
            let value = Float(sin(Double(i) * 2 * .pi * (240 + Double(i) / 1800) / 44100)) * 0.3
            source.floatChannelData![0][i] = value
            source.floatChannelData![1][i] = value * -0.5
        }
        do { let file = try AVAudioFile(forWriting: url, settings: source.format.settings); try file.write(from: source) }
        let deck = MusicFileDeck(url: url, originalMix: true)!
        deck.equaliser.bypass = true; deck.reverb.wetDryMix = 0
        try deck.engine.enableManualRenderingMode(.offline, format: source.format, maximumFrameCount: 1024)
        deck.play()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        let output = stereoBuffer(1024)
        for _ in 0..<40 {
            _ = try deck.engine.renderOffline(1024, to: output)
            // Offline time advances faster than the decoder's wall clock.
            deck.stream.drain(); deck.rewindAudio.drain()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        try assertMusicRewind(deck.rewindAudio.capturedFrames > 4096, "The recording tap did not capture real soundtrack PCM")
        deck.suspendOutput()
        RunLoop.current.run(until: Date().addingTimeInterval(1.8))
        try assertMusicRewind(!deck.engine.isRunning, "Paused recording did not park")
        let soundtrack = SoundtrackPlayer()
        soundtrack.installRewindTestDeck(deck)
        soundtrack.playRewind()
        try assertMusicRewind(deck.engine.isRunning && deck.spatialMixer.outputVolume == 0,
            "Rewind failed to wake a parked recording or left its forward mix audible")
        var reverseEnergy = 0.0
        for _ in 0..<6 {
            let status = try deck.engine.renderOffline(1024, to: output)
            try assertMusicRewind(status == .success, "The parked recording could not render a scratch")
            deck.rewindAudio.drain()
            reverseEnergy += energy(output)
        }
        try assertMusicRewind(reverseEnergy > 1, "The recording rewind was silent")
        deck.setMuted(true)
        for _ in 0..<4 { _ = try deck.engine.renderOffline(1024, to: output) }
        try assertMusicRewind(energy(output) == 0, "Mute leaked reversed recording audio")
        deck.setMuted(false)
        deck.playRewind(); deck.suspendOutput()
        try assertMusicRewind(!deck.rewindAudio.isRewinding, "Suspension retained the recording scratch")
        deck.playRewind()
        RunLoop.current.run(until: Date().addingTimeInterval(VinylBackspin.settleSeconds + 0.08))
        try assertMusicRewind(!deck.engine.isRunning && !deck.player.isPlaying, "A rewind unpaused normal recording playback")
        deck.resumeOutput()
        RunLoop.current.run(until: Date().addingTimeInterval(VinylBackspin.settleSeconds + 0.08))
        try assertMusicRewind(deck.engine.isRunning && deck.player.isPlaying && deck.varispeed.rate == 1,
            "Rewind broke the normal vinyl spin-up")
        deck.stop()
        try assertMusicRewind(!deck.rewindAudio.trigger(), "Stopped recording retained rewind audio")
        print("PASS real recording PCM, soundtrack routing, parked rewind output, mute, suspension, retained pause and vinyl spin-up")
    }
}

func rewindModule() throws -> ProTrackerModule {
    var bytes = [UInt8](repeating: 0, count: 1084 + 1024 + 64)
    bytes[950] = 1
    for (i, value) in "M.K.".utf8.enumerated() { bytes[1080 + i] = value }
    bytes[43] = 32; bytes[45] = 64; bytes[49] = 32
    bytes[1084] = 1; bytes[1085] = 172; bytes[1086] = 16
    for i in 0..<64 { bytes[2108 + i] = UInt8(bitPattern: i < 32 ? 100 : -100) }
    return try ProTrackerModule(data: Data(bytes))
}
extension ModuleMusicPlayer {
    @MainActor fileprivate func checkModuleRewind() throws {
        load(try rewindModule(), url: URL(fileURLWithPath: "/tmp/music-rewind.mod"))
        let output = stereoBuffer(1024)
        try engine.enableManualRenderingMode(.offline, format: output.format, maximumFrameCount: 1024)
        defer { stop(); engine.disableManualRenderingMode() }
        try start(); synthesisQueue.sync {}; rewindAudio.drain()
        for _ in 0..<40 {
            _ = try engine.renderOffline(1024, to: output)
            synthesisQueue.sync {}; rewindAudio.drain()
        }
        try assertMusicRewind(rewindAudio.capturedFrames > 4096, "The MOD mixer did not capture its own samples")
        try resumeOutput()
        try assertMusicRewind(startFadeFrames == 0 && spinUpFrames == 0,
            "Resuming a playing MOD restarted its fade-in and dropped the music to silence")
        suspendOutput()
        for _ in 0..<32 { _ = try engine.renderOffline(1024, to: output); synthesisQueue.sync {}; rewindAudio.drain() }
        RunLoop.current.run(until: Date().addingTimeInterval(1.8))
        try assertMusicRewind(!engine.isRunning, "Paused MOD output did not park")
        playRewind()
        try assertMusicRewind(engine.isRunning && spatialMixer.outputVolume == 0,
            "MOD rewind failed to wake parked output or retained the forward mix")
        var reverseEnergy = 0.0
        for _ in 0..<6 { _ = try engine.renderOffline(1024, to: output); reverseEnergy += energy(output); synthesisQueue.sync {}; rewindAudio.drain() }
        try assertMusicRewind(reverseEnergy > 1, "The MOD scratch was silent")
        setVolume(0); playRewind()
        for _ in 0..<4 { _ = try engine.renderOffline(1024, to: output); synthesisQueue.sync {}; rewindAudio.drain() }
        try assertMusicRewind(energy(output) == 0, "Zero music volume leaked reversed MOD audio")
        setVolume(0.7); playRewind(); setMuted(true)
        for _ in 0..<4 { _ = try engine.renderOffline(1024, to: output); synthesisQueue.sync {}; rewindAudio.drain() }
        try assertMusicRewind(energy(output) == 0 && !rewindAudio.isRewinding, "Mute leaked a MOD scratch")
        setMuted(false); playRewind(); suspendOutput()
        try assertMusicRewind(!rewindAudio.isRewinding, "Suspension retained the MOD scratch")
        playRewind()
        RunLoop.current.run(until: Date().addingTimeInterval(VinylBackspin.settleSeconds + 0.08))
        try assertMusicRewind(!engine.isRunning && outputSuspended, "A MOD rewind resumed forward playback")
        try resumeOutput()
        try assertMusicRewind(spinUpFrames > 0 && engine.isRunning, "MOD rewind bypassed the normal vinyl spin-up")
        print("PASS real MOD samples, parked rewind output, volume, mute, suspension, retained pause and vinyl spin-up")
    }
}
extension MusicFileDeck {
    @MainActor fileprivate func prepareRewindRoutingCheck(_ groove: AVAudioPCMBuffer) throws {
        try engine.enableManualRenderingMode(.offline, format: groove.format, maximumFrameCount: 1024)
        play()
        rewindAudio.record(groove)
    }
    fileprivate var scratchActive: Bool { rewindAudio.isRewinding }
    @MainActor fileprivate func scratchEnergy() throws -> Double {
        let output = stereoBuffer(1024)
        _ = try engine.renderOffline(1024, to: output)
        return energy(output)
    }
}
extension DJDeck {
    @MainActor fileprivate func prepareRewindRoutingCheck(_ groove: AVAudioPCMBuffer) throws { try recording!.prepareRewindRoutingCheck(groove) }
    fileprivate var scratchActive: Bool { recording!.scratchActive }
    @MainActor fileprivate func scratchEnergy() throws -> Double { try recording!.scratchEnergy() }
}
extension AdaptiveDJPlayer {
    @MainActor fileprivate static func checkRewindRouting() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dj-rewind-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let groove = stereoBuffer(44100)
        for i in 0..<44100 { groove.floatChannelData![0][i] = 0.25; groove.floatChannelData![1][i] = -0.125 }
        do { let file = try AVAudioFile(forWriting: url, settings: groove.format.settings); try file.write(from: groove) }
        let dj = AdaptiveDJPlayer()
        let a = DJDeck(url)!, b = DJDeck(url)!, silent = DJDeck(url)!
        dj.deckA = a; dj.deckB = b; dj.carryDecks = [silent]
        defer { dj.stop() }
        dj.setGain(0.8, for: a); dj.setGain(0.2, for: b); dj.setGain(0, for: silent)
        dj.setVolume(0.7)
        for deck in [a, b, silent] { try deck.prepareRewindRoutingCheck(groove) }
        dj.playRewind()
        try assertMusicRewind(a.scratchActive && b.scratchActive && !silent.scratchActive,
            "DJ rewind missed an audible layer or woke a silent deck")
        let aEnergy = try a.scratchEnergy(), bEnergy = try b.scratchEnergy()
        try assertMusicRewind(aEnergy > 1 && abs(aEnergy / bEnergy - 4) < 0.01,
            "DJ rewind changed the current mix gains")
        dj.setMuted(true); dj.playRewind()
        try assertMusicRewind(!a.scratchActive && !b.scratchActive, "Muted DJ restarted a scratch")
        dj.setMuted(false); dj.setVolume(0); dj.playRewind()
        try assertMusicRewind(!a.scratchActive && !b.scratchActive, "Zero DJ volume restarted a scratch")
        dj.setVolume(0.7); dj.playRewind(); dj.suspendOutput()
        try assertMusicRewind(!a.scratchActive && !b.scratchActive, "DJ suspension retained its scratches")
        print("PASS Adaptive DJ audible-layer routing, exact mix gains, silent decks, mute, zero volume and suspension")
    }
}
let application = NSApplication.shared
application.setActivationPolicy(.accessory)
try checkReverseGroove()
try checkBackspinPitchAndEdges()
try MusicFileDeck.checkRecordingRewind()
try ModuleMusicPlayer().checkModuleRewind()
try AdaptiveDJPlayer.checkRewindRouting()
