import AVFoundation
import Foundation
import NxlvKit

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

@MainActor private let energyFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!

extension MusicFileDeck {
    fileprivate func useOfflineOutput() throws {
        try engine.enableManualRenderingMode(.offline, format: energyFormat, maximumFrameCount: 1024)
    }

    fileprivate func checkImmediateSuspension() async throws {
        try useOfflineOutput()
        play()
        suspendOutput(rhythmOnly: true)
        suspendOutput(immediately: true)
        require(!engine.isRunning && !player.isPlaying && !rhythmPlayer.isPlaying,
                "Inactive recording retained an audio renderer")
        require(fadeTask == nil && rhythmTask == nil && rewindTask == nil,
                "Inactive recording retained an animation task")
        suspendOutput(immediately: true)
        resumeOutput()
        require(engine.isRunning && player.isPlaying, "Immediate suspension lost the recording's resume state")
        let output = AVAudioPCMBuffer(pcmFormat: energyFormat, frameCapacity: 1024)!
        let rendered = try engine.renderOffline(1024, to: output)
        require(rendered == .success, "Resumed recording did not render")
        suspendOutput()
        await energyDelay(0.05)
        suspendOutput(immediately: true)
        await energyDelay(0.2)
        require(!engine.isRunning && fadeTask == nil, "A late vinyl task restarted suspended output")
        stop()
    }

    fileprivate var outputIsRunning: Bool { engine.isRunning }
}

extension ModuleMusicPlayer {
    @MainActor fileprivate func checkImmediateSuspension(url: URL) throws {
        try engine.enableManualRenderingMode(.offline, format: energyFormat, maximumFrameCount: 1024)
        require(play(url: url) != nil, "Tracker fixture did not load")
        try start()
        suspendOutput(rhythmOnly: true)
        suspendOutput(immediately: true)
        require(!engine.isRunning && !isOutputRunning && pauseWorkItem == nil,
                "Inactive tracker retained its renderer or delayed brake")
        suspendOutput(immediately: true)
        try resumeOutput()
        require(engine.isRunning && isOutputRunning, "Tracker could not resume after immediate suspension")
        stop()
    }
}

extension DJDeck {
    fileprivate func useOfflineOutput() throws { try recording?.useOfflineOutput() }
    fileprivate var outputIsRunning: Bool { recording?.outputIsRunning == true }
}

extension AdaptiveDJPlayer {
    fileprivate func checkSuspendedFade(first: URL, second: URL) async throws {
        let outgoing = DJDeck(first)!, incoming = DJDeck(second)!
        try outgoing.useOfflineOutput(); try incoming.useOfflineOutput()
        deckA = outgoing
        setGain(1, for: outgoing)
        require(outgoing.play(), "Outgoing fixture did not start")
        require(crossfade(seconds: Fade.levelEntry, destination: second, prepared: incoming, immediate: true),
                "Crossfade fixture did not start")
        await energyDelay(0.1)
        suspendOutput()
        require(fadeTask == nil, "Paused DJ kept polling its crossfade")
        suspendOutput(immediately: true)
        let position = fadePosition
        require(allDecks.allSatisfy { !$0.outputIsRunning }, "Inactive DJ left an audio graph running")
        await energyDelay(0.2)
        require(fadePosition == position && fadeTask == nil, "Suspended DJ advanced its fade")
        resumeOutput()
        require(fadeTask != nil && playingDeckCount == 2, "DJ did not restore its suspended crossfade")
        await energyDelay(0.15)
        require(fadePosition > position, "Resumed DJ fade did not advance")
        suspendOutput(immediately: true)
        require(allDecks.allSatisfy { !$0.outputIsRunning }, "Second suspension left a DJ renderer running")
        stop()
    }
}

extension SoundEffectPlayer {
    @MainActor fileprivate func checkIdleSuspension() throws {
        try engine.enableManualRenderingMode(.offline, format: energyFormat, maximumFrameCount: 1024)
        try start()
        require(suspendOutputIfIdle() && !engine.isRunning, "Empty effects graph did not park")
        try resumeOutput()
        play(samples: [Float](repeating: 0.1, count: 2048), rate: 44100, gain: 1)
        require(!suspendOutputIfIdle() && engine.isRunning, "Idle parking cut off an active effect")
        let output = AVAudioPCMBuffer(pcmFormat: energyFormat, frameCapacity: 1024)!
        for _ in 0..<8 {
            let rendered = try engine.renderOffline(1024, to: output)
            require(rendered == .success, "Effect fixture did not render")
        }
        require(suspendOutputIfIdle() && !engine.isRunning, "Effects renderer ran after its last voice finished")
        try resumeOutput()
        play(samples: [Float](repeating: 0.1, count: 2048), rate: 44100, gain: 1)
        require(engine.isRunning && !suspendOutputIfIdle(), "Parked effects could not play the next cue")
        suspendOutput()
        require(!engine.isRunning, "Lifecycle suspension left effects running")
        stop()
    }
}

@MainActor private func energyDelay(_ seconds: Double) async {
    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
}

@main private struct MobileEnergyChecks {
    @MainActor static func main() async throws {
        require(ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] == "muted", "Energy checks must be silent")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("energy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("first.wav"), second = root.appendingPathComponent("second.wav")
        for url in [first, second] {
            let file = try AVAudioFile(forWriting: url, settings: energyFormat.settings)
            let samples = AVAudioPCMBuffer(pcmFormat: energyFormat, frameCapacity: 44100)!
            samples.frameLength = 44100
            for channel in 0..<2 { for index in 0..<44100 {
                samples.floatChannelData![channel][index] = Float(sin(Double(index) * 2 * .pi * 440 / 44100)) * 0.1
            } }
            try file.write(from: samples)
        }
        let moduleURL = root.appendingPathComponent("fixture.mod")
        var bytes = [UInt8](repeating: 0, count: 1084 + 1024 + 64)
        bytes[950] = 1
        for (index, value) in "M.K.".utf8.enumerated() { bytes[1080 + index] = value }
        bytes[43] = 32; bytes[45] = 64; bytes[49] = 32
        bytes[1084] = 1; bytes[1085] = 172; bytes[1086] = 16
        for index in 0..<64 { bytes[2108 + index] = UInt8(bitPattern: index < 32 ? 100 : -100) }
        try Data(bytes).write(to: moduleURL)
        try await MusicFileDeck(url: first, rhythmURL: second)!.checkImmediateSuspension()
        try ModuleMusicPlayer().checkImmediateSuspension(url: moduleURL)
        try await AdaptiveDJPlayer().checkSuspendedFade(first: first, second: second)
        try SoundEffectPlayer(voiceCount: 2).checkIdleSuspension()
        print("PASS immediate recording/tracker/DJ suspension, parked crossfades, explicit resume and idle sound effects (offline, muted)")
    }
}
