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
    private var recentSamples = [Float](repeating: 0, count: 44_100)
    private var recentPositions = [Int64](repeating: Int64.min, count: 44_100)
    private var recentPosition: Int64 = 0
    private var rewindSamples: [Float] = []
    private var rewindIndex = 0
    init(root: URL) throws {
        mixer = Lemmings2SoundMixer(bank: try Lemmings2SoundBank(data:
            Data(contentsOf: root.appendingPathComponent("MUSIC/SBLAST.VOC"))))
    }
    func start() throws {
        guard source == nil else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let node = AVAudioSourceNode(format: format) { [weak self] _, timestamp, frames, buffers in
            let list = UnsafeMutableAudioBufferListPointer(buffers)
            guard let self else {
                for buffer in list { memset(buffer.mData, 0, Int(buffer.mDataByteSize)) }
                return noErr
            }
            self.lock.lock()
            defer { self.lock.unlock() }
            let startingPosition = timestamp.pointee.mSampleTime.isFinite
                ? Int64(timestamp.pointee.mSampleTime) : self.recentPosition
            for i in 0..<Int(frames) {
                let value: Float
                if self.rewindIndex < self.rewindSamples.count {
                    value = self.rewindSamples[self.rewindIndex] * self.volume
                    self.rewindIndex += 1
                } else {
                    value = self.mixer.nextSample()
                    let position = startingPosition + Int64(i)
                    self.recentSamples[Int(position % Int64(self.recentSamples.count) + Int64(self.recentSamples.count)) % self.recentSamples.count] = value
                    self.recentPositions[Int(position % Int64(self.recentPositions.count) + Int64(self.recentPositions.count)) % self.recentPositions.count] = position
                    self.recentPosition = position + 1
                }
                let output = value * self.volume
                for buffer in list { buffer.mData?.assumingMemoryBound(to: Float.self)[i] = output }
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
    func silence() {
        lock.lock(); defer { lock.unlock() }
        mixer.silence(); rewindSamples = []; rewindIndex = 0
    }
    func playRewindScrub() {
        lock.lock(); defer { lock.unlock() }
        let count = min(15_435, recentSamples.count)
        var samples: [Float] = []; samples.reserveCapacity(count)
        for offset in 0..<count {
            let position = recentPosition - 1 - Int64(offset)
            let index = Int(position % Int64(recentSamples.count) + Int64(recentSamples.count)) % recentSamples.count
            guard recentPositions[index] == position else { break }
            samples.append(recentSamples[index])
        }
        rewindSamples = samples
        rewindIndex = 0
    }
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
