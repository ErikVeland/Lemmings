import AVFoundation
import Foundation
import NxlvKit

/// A separate L2 voice mixer keeps effects independent of module music.
final class Lemmings2SoundPlayer: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private let lock = NSLock()
    private var mixer: Lemmings2SoundMixer
    init(root: URL) throws {
        mixer = Lemmings2SoundMixer(bank: try Lemmings2SoundBank(data:
            Data(contentsOf: root.appendingPathComponent("MUSIC/SBLAST.VOC"))))
    }
    func start() throws {
        guard source == nil else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frames, buffers in
            let list = UnsafeMutableAudioBufferListPointer(buffers)
            guard let self else {
                for buffer in list { memset(buffer.mData, 0, Int(buffer.mDataByteSize)) }
                return noErr
            }
            self.lock.lock()
            defer { self.lock.unlock() }
            for i in 0..<Int(frames) {
                let value = self.mixer.nextSample()
                for buffer in list { buffer.mData?.assumingMemoryBound(to: Float.self)[i] = value }
            }
            return noErr
        }
        engine.attach(node); engine.connect(node, to: engine.mainMixerNode, format: format)
        source = node
        try engine.start()
    }
    func stop() { engine.stop(); silence() }
    func silence() { lock.lock(); defer { lock.unlock() }; mixer.silence() }
    func play(_ requests: [Lemmings2SoundRequest]) {
        lock.lock(); defer { lock.unlock() }
        // Simultaneous lemmings share a cue, without stacking dozens of copies.
        var played: Set<Lemmings2SoundRequest> = []
        for request in requests where played.insert(request).inserted { mixer.play(request) }
    }
    func setMuted(_ muted: Bool) { lock.lock(); defer { lock.unlock() }; mixer.setMuted(muted) }
    var muted: Bool { lock.lock(); defer { lock.unlock() }; return mixer.muted }
}
