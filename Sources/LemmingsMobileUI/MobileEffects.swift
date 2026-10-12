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
        guard !isTestAudioMuted, !suspended else { return }
        let rect = viewport.visibleLevelRect
        player.setViewport(.init(x: rect.x, y: rect.y, width: rect.width, height: rect.height))
        player.setNukeActive(session.snapshot.isEndingRun)
        if rewinding { player.playRewindScrub() } else { player.play(cues) }
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
