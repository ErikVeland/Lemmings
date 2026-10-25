#if os(iOS) || os(tvOS)
import LemmingsAudio
import LemmingsAppCore
import LemmingsMobileCore
import NxlvKit
import UIKit

/// Each game owns its effect voices, including simulation replays.
@MainActor final class MobileEffects {
    private let player = SoundEffectPlayer(voiceCount: MobileDevicePerformance.constrained ? 12 : 24,
                                          rescueVoiceLimit: MobileDevicePerformance.constrained ? 3 : 6)
    private var prepared = false
    private var suspended = false
    private var source: ClassicSoundSource?
    private var resultPlayed = false
    private var loadedNeoLemmixSoundIdentity: String?
    private var idleTask: Task<Void, Never>?
    private var isTestAudioMuted: Bool { ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] == "muted" }

    func prepare() {
        let settings = MobileSettings.current(from: .standard).classic
        player.setMuted(isTestAudioMuted || settings.sound == .silent)
        player.setVolume(settings.soundVolume)
        player.setBottomFallSounds(settings.bottomFallSounds)
        guard !isTestAudioMuted, settings.sound != .silent, settings.soundVolume > 0 else {
            idleTask?.cancel(); idleTask = nil
            player.stop(); prepared = false
            return
        }
        if source != settings.sound {
            let root = Bundle.main.resourceURL
            let amiga = BundledGameResources.amigaSoundDirectory()
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
        if !prepared { try? player.start(); prepared = player.isRunning }
        scheduleIdleSuspension()
    }

    func update(session: any MobileGameSession, viewport: MobileViewport, rewinding: Bool = false) {
        let cues = session.drainSoundCues()
        let engine = (session as? MobileActionReplaySession)?.engineSession ?? session
        let l2Session = engine as? Lemmings2MobileSession
        let l2Requests = l2Session?.drainLemmings2SoundRequests() ?? []
        guard !isTestAudioMuted, !suspended, prepared else { return }
        let rect = viewport.visibleLevelRect
        player.setViewport(.init(x: rect.x, y: rect.y, width: rect.width, height: rect.height))
        player.setNukeActive(session.snapshot.isEndingRun)
        if let neoLemmix = engine as? NeoLemmixMobileSession,
           let soundDirectory = neoLemmix.soundDirectory {
            let identity = [neoLemmix.levelFingerprint, soundDirectory.path,
                            neoLemmix.gadgetSounds.values.sorted().joined(separator: ",")].joined(separator: "|")
            if loadedNeoLemmixSoundIdentity != identity {
                let resources = Bundle.main.resourceURL
                player.loadNeoLemmixSounds(
                    names: Set(neoLemmix.gadgetSounds.values),
                    soundDirectory: soundDirectory,
                    amigaDirectory: BundledGameResources.amigaSoundDirectory(),
                    fallbackSoundDirectory: resources?.appendingPathComponent("NeoLemmix/sound")
                )
                loadedNeoLemmixSoundIdentity = identity
            }
        }
        guard rewinding || !cues.isEmpty || !l2Requests.isEmpty else { return }
        resumeForCue()
        if rewinding {
            player.playRewindScrub()
        } else if let l2Session {
            play(l2Requests, bank: l2Session.soundBank)
            player.play(cues)
        } else if let chronicles = engine as? Lemmings3MobileSession, let bank = chronicles.soundBank {
            play(cues, bank: bank)
        } else {
            player.play(cues)
        }
    }
    func ready() { guard !isTestAudioMuted, !suspended else { return }; prepare(); guard prepared else { return }; resumeForCue(); player.play(.ready) }
    func rejectedAssignment() { guard !isTestAudioMuted, !suspended, prepared else { return }; resumeForCue(); player.play(.actionRejected) }
    func releaseRate(_ rate: Int) { guard !isTestAudioMuted, !suspended, prepared else { return }; resumeForCue(); player.playReleaseRate(rate) }
    func result(won: Bool) {
        guard !isTestAudioMuted, !suspended, prepared, !resultPlayed else { return }
        resultPlayed = true
        resumeForCue()
        player.silencePreservingRescues()
        player.play(won ? .yippee : .actionRejected)
    }
    func playChime(star: Int, ornament: Bool = false) {
        guard !isTestAudioMuted, !suspended, prepared else { return }
        resumeForCue()
        let samples = ResultChimeSamples.samples(star: star, ornament: ornament).map { Float($0) / 32768 }
        player.play(samples: samples, rate: ResultChimeSamples.sampleRate, gain: 1)
    }
    func movieEffects() -> MobileMovieEffects { MobileMovieEffects(player: player.replayPlayer()) }
    func pause() { idleTask?.cancel(); idleTask = nil; player.suspendOutput() }
    func setVoiceLimit(_ count: Int) { player.setVoiceLimit(count) }
    func suspend() { suspended = true; pause() }
    func resume() { guard !isTestAudioMuted else { return }; suspended = false }
    func stop() { idleTask?.cancel(); idleTask = nil; player.stop(); prepared = false }

    private func resumeForCue() {
        try? player.resumeOutput()
        scheduleIdleSuspension()
    }

    private func scheduleIdleSuspension() {
        idleTask?.cancel()
        idleTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                // Short gaps between effects should not repeatedly restart the graph.
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard let self else { return }
                if self.player.suspendOutputIfIdle() {
                    self.idleTask = nil
                    return
                }
            }
        }
    }

    private func play(_ requests: [Lemmings2SoundRequest], bank: Lemmings2SoundBank?) {
        let bottomFallSounds = MobileSettings.current(from: .standard).classic.bottomFallSounds
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
        let settings = MobileSettings.current(from: .standard).classic
        let engine = (session as? MobileActionReplaySession)?.engineSession ?? session
        let viewport = GameplaySoundViewport(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
        var cues = session.drainSoundCues()
        let requests = session.drainLemmings2SoundRequests()
        guard ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] != "muted", settings.sound != .silent else { return }
        let gain = Float(settings.soundVolume) * 0.5
        if let tribes = engine as? Lemmings2MobileSession {
            var seen = Set<String>()
            for request in requests {
                if let effect = request.supplementalEffect {
                    cues.append(.init(effect: effect, point: request.point)); continue
                }
                guard !request.isBottomFall || settings.bottomFallSounds else { continue }
                let region = request.point.map { "\(Int($0.x / 32)),\(Int($0.y / 32))" } ?? "interface"
                guard seen.insert("\(request.sample):\(request.timeConstant ?? 0):" + region).inserted,
                      let bank = tribes.soundBank, bank.clips.indices.contains(request.sample) else { continue }
                let clip = bank.clips[request.sample]
                recorder.sound(samples: clip.samples,
                    rate: request.timeConstant.map { 1_000_000 / Double(256 - Int($0)) } ?? clip.sampleRate,
                    gain: gain * (request.point.map { viewport.placement(of: $0).gain } ?? 1))
            }
        } else if let chronicles = engine as? Lemmings3MobileSession, let bank = chronicles.soundBank {
            cues = cues.filter { cue in
                guard cue.effect != .fallOut || settings.bottomFallSounds else { return false }
                guard let clip = bank.clips[cue.effect] else { return true }
                recorder.sound(samples: clip.samples, rate: clip.sampleRate,
                    gain: gain * (cue.point.map { viewport.placement(of: $0).gain } ?? 1))
                return false
            }
        }
        for cue in player.movieCues(cues, viewport: viewport, time: Double(session.snapshot.tick) / session.ticksPerSecond) {
            recorder.sound(samples: cue.samples, rate: cue.rate, gain: cue.gain)
        }
    }
}
#endif
