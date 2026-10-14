#if os(iOS)
import LemmingsAudio
import LemmingsAppCore
import LemmingsMobileCore
import NxlvKit
import UIKit

/// Each game owns its effect voices, including simulation replays.
@MainActor final class MobileEffects {
    private let player = SoundEffectPlayer()
    private var prepared = false
    private var suspended = false
    private var source: ClassicSoundSource?
    private var resultPlayed = false
    private var loadedNeoLemmixSoundIdentity: String?
    private var isTestAudioMuted: Bool { ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] == "muted" }

    func prepare() {
        let settings = MobileSettings.load(from: .standard).classic
        player.setMuted(isTestAudioMuted || settings.sound == .silent)
        player.setVolume(settings.soundVolume)
        player.setBottomFallSounds(settings.bottomFallSounds)
        guard !isTestAudioMuted else { return }
        if source != settings.sound {
            let root = Bundle.main.resourceURL
            let amiga = root?.appendingPathComponent("Ports/amiga_extracted/lemmings")
            let supplements = root?.appendingPathComponent("Sounds")
            switch settings.sound {
            case .macintoshResources:
                if let image = BundledGameResources.macintoshSoundImage() {
                    _ = try? player.loadMacintoshSounds(imageURL: image,
                        amigaFallbackDirectory: amiga, supplementDirectory: supplements)
                } else if let amiga {
                    _ = try? player.loadAmigaSounds(directory: amiga, supplementDirectory: supplements)
                }
            case .amigaVoices:
                if let amiga {
                    _ = try? player.loadAmigaSounds(directory: amiga,
                        macintoshFallbackImage: BundledGameResources.macintoshSoundImage(), supplementDirectory: supplements)
                }
            default: player.loadSupplementSounds(directory: supplements)
            }
            source = settings.sound
        }
        if !prepared { try? player.start(); prepared = true }
    }

    func update(session: any MobileGameSession, viewport: MobileViewport, rewinding: Bool = false) {
        let cues = session.drainSoundCues()
        let l2Session = session as? Lemmings2MobileSession
        let l2Requests = l2Session?.drainLemmings2SoundRequests() ?? []
        guard !isTestAudioMuted, !suspended else { return }
        let rect = viewport.visibleLevelRect
        player.setViewport(.init(x: rect.x, y: rect.y, width: rect.width, height: rect.height))
        player.setNukeActive(session.snapshot.isEndingRun)
        if let neoLemmix = session as? NeoLemmixMobileSession,
           let soundDirectory = neoLemmix.soundDirectory {
            let identity = [neoLemmix.levelFingerprint, soundDirectory.path,
                            neoLemmix.gadgetSounds.values.sorted().joined(separator: ",")].joined(separator: "|")
            if loadedNeoLemmixSoundIdentity != identity {
                let resources = Bundle.main.resourceURL
                player.loadNeoLemmixSounds(
                    names: Set(neoLemmix.gadgetSounds.values),
                    soundDirectory: soundDirectory,
                    amigaDirectory: resources?.appendingPathComponent("Ports/amiga_extracted/lemmings"),
                    fallbackSoundDirectory: resources?.appendingPathComponent("NeoLemmix/sound")
                )
                loadedNeoLemmixSoundIdentity = identity
            }
        }
        if rewinding {
            player.playRewindScrub()
        } else if let l2Session {
            play(l2Requests, bank: l2Session.soundBank)
            player.play(cues)
        } else if let chronicles = session as? Lemmings3MobileSession, let bank = chronicles.soundBank {
            play(cues, bank: bank)
        } else {
            player.play(cues)
        }
    }
    func ready() { guard !isTestAudioMuted else { return }; prepare(); player.play(.ready) }
    func assignment(accepted: Bool) { guard !isTestAudioMuted else { return }; player.play(accepted ? .assignSkill : .actionRejected) }
    func releaseRate(_ rate: Int) { guard !isTestAudioMuted else { return }; player.playReleaseRate(rate) }
    func result(won: Bool) {
        guard !isTestAudioMuted, !resultPlayed else { return }
        resultPlayed = true
        player.silencePreservingRescues()
        player.play(won ? .yippee : .actionRejected)
    }
    func playChime(star: Int, ornament: Bool = false) {
        guard !isTestAudioMuted, !suspended else { return }
        let samples = ResultChimeSamples.samples(star: star, ornament: ornament).map { Float($0) / 32768 }
        player.play(samples: samples, rate: ResultChimeSamples.sampleRate, gain: 1)
    }
    func movieEffects() -> MobileMovieEffects { MobileMovieEffects(player: player.replayPlayer()) }
    func pause() { player.silence() }
    func suspend() { suspended = true; player.suspendOutput() }
    func resume() { guard !isTestAudioMuted else { return }; suspended = false; try? player.resumeOutput() }
    func stop() { player.stop() }

    private func play(_ requests: [Lemmings2SoundRequest], bank: Lemmings2SoundBank?) {
        let bottomFallSounds = MobileSettings.load(from: .standard).classic.bottomFallSounds
        var seen = Set<String>()
        for request in requests {
            if let effect = request.supplementalEffect {
                player.play(effect, at: request.point)
                continue
            }
            guard !request.isBottomFall || bottomFallSounds else { continue }
            let region = request.point.map { "\(Int(floor($0.x / 32))),\(Int(floor($0.y / 32)))" } ?? "interface"
            guard seen.insert("\(request.sample):\(request.timeConstant ?? 0):\(region)").inserted else { continue }
            if let bank, bank.clips.indices.contains(request.sample) {
                let clip = bank.clips[request.sample]
                let rate = request.timeConstant.map { 1_000_000 / Double(256 - Int($0)) } ?? clip.sampleRate
                player.play(samples: clip.samples, rate: rate, gain: 0.5, at: request.point,
                    semanticEffect: Self.semanticEffect(for: request.sample))
            } else if let effect = request.supplementalEffect ?? Self.semanticEffect(for: request.sample) {
                player.play(effect, at: request.point)
            }
            if request.sample == Lemmings2SoundCue.explode.rawValue { player.playNukeImpact(at: request.point) }
        }
    }

    private func play(_ cues: [PositionedSoundCue], bank: Lemmings3SoundBank) {
        for cue in cues {
            guard let clip = bank.clips[cue.effect] else {
                player.play([cue])
                continue
            }
            player.play(samples: clip.samples, rate: clip.sampleRate, gain: 0.5,
                at: cue.point, semanticEffect: cue.effect)
        }
    }

    private static func semanticEffect(for sample: Int) -> ClassicSoundEffect? {
        switch Lemmings2SoundCue(rawValue: sample) {
        case .assignSkill: .assignSkill
        case .builderWarning: .builderWarning
        case .hitSteel: .hitSteel
        case .splat: .splat
        case .drown: .drown
        case .fire: .vaporize
        case .fallOut: .fallOut
        case .explode: .explode
        default: nil
        }
    }
}

@MainActor final class MobileMovieEffects {
    private let player: SoundEffectPlayer
    fileprivate init(player: SoundEffectPlayer) { self.player = player }
    func record(session: any MobileGameSession, viewport: MobileViewport, into recorder: ReplayMovieRecorder) {
        let rect = viewport.visibleLevelRect
        player.setNukeActive(session.snapshot.isEndingRun)
        let cues = player.movieCues(session.drainSoundCues(),
            viewport: .init(x: rect.x, y: rect.y, width: rect.width, height: rect.height),
            time: Double(session.snapshot.tick) / session.ticksPerSecond)
        for cue in cues { recorder.sound(samples: cue.samples, rate: cue.rate, gain: cue.gain) }
    }
}
#endif
