import AVFoundation
import Foundation
import NxlvKit

/// A separate L2 voice mixer keeps effects independent of module music.
final class Lemmings2SoundPlayer: @unchecked Sendable {
    var onPlay: (@Sendable ([Float], Double, Float) -> Void)?
    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private let environment = AVAudioEnvironmentNode()
    private let spatialMixer = AVAudioMixerNode()
    private let lock = NSLock()
    private var mixer: Lemmings2SoundMixer
    private var volume: Float = 1
    init(root: URL) throws {
        mixer = Lemmings2SoundMixer(bank: try Lemmings2SoundBank(data:
            Data(contentsOf: root.appendingPathComponent("MUSIC/SBLAST.VOC"))))
    }
    func start() throws {
        guard source == nil else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frames, buffers in
            let list = UnsafeMutableAudioBufferListPointer(buffers)
            guard let self else {
                for buffer in list { memset(buffer.mData, 0, Int(buffer.mDataByteSize)) }
                return noErr
            }
            self.lock.lock()
            defer { self.lock.unlock() }
            for i in 0..<Int(frames) {
                let value = self.mixer.nextSample() * self.volume
                for buffer in list { buffer.mData?.assumingMemoryBound(to: Float.self)[i] = value }
            }
            return noErr
        }
        engine.attach(node)
        engine.attach(spatialMixer)
        engine.attach(environment)
        environment.outputType = .auto
        environment.distanceAttenuationParameters.rolloffFactor = 0
        engine.connect(node, to: spatialMixer, format: format)
        engine.connect(spatialMixer, to: environment, format: format)
        engine.connect(environment, to: engine.mainMixerNode,
                       format: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!)
        spatialMixer.renderingAlgorithm = .auto
        spatialMixer.sourceMode = .pointSource
        spatialMixer.position = AVAudio3DPoint(x: 0, y: 0, z: -1)
        source = node
        do { try engine.start() }
        catch { detachSources(); throw error }
    }
    func stop() {
        engine.stop()
        detachSources()
        silence()
    }
    private func detachSources() {
        guard let source else { return }
        engine.detach(source)
        engine.detach(spatialMixer)
        engine.detach(environment)
        self.source = nil
    }
    func silence() { lock.lock(); defer { lock.unlock() }; mixer.silence() }
    func suspendOutput() { if source != nil { engine.pause() } }
    func resumeOutput() throws { if source != nil && !engine.isRunning { try engine.start() } }
    private var bottomFallSounds = true
    func setBottomFallSounds(_ enabled: Bool) {
        lock.lock(); defer { lock.unlock() }; bottomFallSounds = enabled
    }
    func play(_ requests: [Lemmings2SoundRequest]) {
        lock.lock(); defer { lock.unlock() }
        // Simultaneous lemmings share a cue, without stacking dozens of copies.
        var played: Set<Lemmings2SoundRequest> = []
        for request in requests where played.insert(request).inserted {
            guard bottomFallSounds || !request.isBottomFall else { continue }
            mixer.play(request)
            if !mixer.muted, mixer.bank.clips.indices.contains(request.sample) {
                let clip = mixer.bank.clips[request.sample]
                let rate = request.timeConstant.map { 1_000_000 / Double(256 - Int($0)) } ?? clip.sampleRate
                onPlay?(clip.samples, rate, volume * 0.5)
            }
        }
    }
    func setMuted(_ muted: Bool) { lock.lock(); defer { lock.unlock() }; mixer.setMuted(muted) }
    func setVolume(_ value: Double) { lock.lock(); defer { lock.unlock() }; volume = Float(min(1, max(0, value))) }
    var muted: Bool { lock.lock(); defer { lock.unlock() }; return mixer.muted }
}
