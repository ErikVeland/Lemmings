import Foundation
import NxlvKit

/// L2's original samples use the same independent spatial voices as Classic and L3.
final class Lemmings2SoundPlayer: @unchecked Sendable {
    private let bank: Lemmings2SoundBank
    private let effects = SoundEffectPlayer(voiceCount: 8)
    private var bottomFallSounds = true
    var onPlay: (@Sendable ([Float], Double, Float) -> Void)? {
        get { effects.onPlay }
        set { effects.onPlay = newValue }
    }
    init(root: URL) throws {
        bank = try Lemmings2SoundBank(data: Data(contentsOf: root.appendingPathComponent("MUSIC/SBLAST.VOC")))
    }
    func start() throws { try effects.start() }
    func stop() { effects.stop() }
    func silence() { effects.silence() }
    func playRewindScrub() { effects.playRewindScrub() }
    func suspendOutput() { effects.suspendOutput() }
    func resumeOutput() throws { try effects.resumeOutput() }
    func setNukeActive(_ active: Bool) { effects.setNukeActive(active) }
    func setViewport(_ viewport: GameplaySoundViewport) { effects.setViewport(viewport) }
    func setBottomFallSounds(_ enabled: Bool) { bottomFallSounds = enabled }
    func play(_ requests: [Lemmings2SoundRequest]) {
        var seen = Set<String>()
        for request in requests {
            guard bottomFallSounds || !request.isBottomFall, bank.clips.indices.contains(request.sample) else { continue }
            let region = request.point.map { "\(Int(floor($0.x / 32))),\(Int(floor($0.y / 32)))" } ?? "interface"
            guard seen.insert("\(request.sample):\(request.timeConstant ?? 0):" + region).inserted else { continue }
            let clip = bank.clips[request.sample]
            let rate = request.timeConstant.map { 1_000_000 / Double(256 - Int($0)) } ?? clip.sampleRate
            effects.play(samples: clip.samples, rate: rate, at: request.point)
            if request.sample == Lemmings2SoundCue.explode.rawValue { effects.playNukeImpact(at: request.point) }
        }
    }
    func setMuted(_ muted: Bool) { effects.setMuted(muted) }
    func setVolume(_ value: Double) { effects.setVolume(value) }
    var muted: Bool { effects.muted }
}
