#if os(iOS) || os(tvOS)
import LemmingsAudio
import LemmingsAppCore
import LemmingsMobileCore
import NxlvKit
import UIKit
import AVFAudio
import os

/// Each game owns its effect voices, including simulation replays.
@MainActor final class MobileEffects {
    private var player = SoundEffectPlayer(voiceCount: MobileDevicePerformance.constrained ? 12 : 24,
                                          rescueVoiceLimit: MobileDevicePerformance.constrained ? 3 : 6)
    private let playback = AudioPlaybackQueue(label: "Lemmings.mobile-effects-control")
    private let audioObservers = MobileNotificationObserverBag()
    private let logger = Logger(subsystem: "com.ultimatelemmings.audio", category: "Effects")
    var audioDiagnostics: AudioBufferStatistics { player.audioDiagnostics }
    init() {
        audioObservers.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.stop()
                self.player = SoundEffectPlayer(voiceCount: MobileDevicePerformance.constrained ? 12 : 24,
                    rescueVoiceLimit: MobileDevicePerformance.constrained ? 3 : 6)
                self.source = nil
                self.loadedNeoLemmixSoundIdentity = nil
            }
        })
    }
    private var prepared = false
    private var suspended = false
    private var source: ClassicSoundSource?
    private var resultPlayed = false
    private var loadedNeoLemmixSoundIdentity: String?
    private var idleTask: Task<Void, Never>?
    private var keepOutputReady = false
    private var isTestAudioMuted: Bool { ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] == "muted" }

    private func enqueue(persistent: Bool = false, _ operation: @escaping @Sendable (SoundEffectPlayer) -> Void) {
        let player = player
        playback.submit(persistent: persistent) { operation(player) }
    }

    func prepare() {
        let settings = MobileSettings.current(from: .standard).classic
        let muted = isTestAudioMuted || settings.sound == .silent
        let sound = settings.sound
        let volume = settings.soundVolume
        let bottomFall = settings.bottomFallSounds
        guard !muted, volume > 0 else {
            idleTask?.cancel(); idleTask = nil
            keepOutputReady = false
            playback.cancelPending()
            enqueue(persistent: true) { player in player.setMuted(true); player.stop() }
            prepared = false
            return
        }
        let needsLibrary = source != sound
        source = sound
        let amiga = needsLibrary ? BundledGameResources.amigaSoundDirectory() : nil
        let image = needsLibrary ? BundledGameResources.macintoshSoundImage() : nil
        let supplements = Bundle.main.resourceURL?.appendingPathComponent("Sounds")
        let logger = logger
        // Prepared means that configuration is queued before any following cue.
        prepared = true
        enqueue(persistent: true) { player in
            player.setMuted(false)
            player.setVolume(volume)
            player.setBottomFallSounds(bottomFall)
            if needsLibrary {
                switch sound {
                case .macintoshResources:
                    if let image {
                        _ = try? player.loadMacintoshSounds(imageURL: image,
                            amigaFallbackDirectory: amiga, supplementDirectory: supplements)
                    } else if let amiga {
                        _ = try? player.loadAmigaSounds(directory: amiga, supplementDirectory: supplements)
                    }
                case .amigaVoices:
                    if let amiga {
                        _ = try? player.loadAmigaSounds(directory: amiga,
                            macintoshFallbackImage: image, supplementDirectory: supplements)
                    }
                default: player.loadSupplementSounds(directory: supplements)
                }
            }
            do { try player.start() }
            catch { logger.error("Effects start failed: \(String(describing: error), privacy: .public)") }
        }
        scheduleIdleSuspension()
    }

    func update(session: any MobileGameSession, viewport: MobileViewport, rewinding: Bool = false,
                snapshot: MobileGameSnapshot? = nil) {
        let cues = session.drainSoundCues()
        let engine = (session as? MobileActionReplaySession)?.engineSession ?? session
        let l2Session = engine as? Lemmings2MobileSession
        let l2Requests = l2Session?.drainLemmings2SoundRequests() ?? []
        guard !isTestAudioMuted, !suspended, prepared else { return }
        let current = snapshot ?? session.snapshot
        let needsReadyOutput = session.activeLemmingCount > 0 || current.isEndingRun
        let becameActive = needsReadyOutput && !keepOutputReady
        keepOutputReady = needsReadyOutput
        if becameActive { resumeForCue() }
        let rect = viewport.visibleLevelRect
        let soundViewport = GameplaySoundViewport(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
        let ending = current.isEndingRun
        enqueue { player in player.setViewport(soundViewport); player.setNukeActive(ending) }
        if let neoLemmix = engine as? NeoLemmixMobileSession,
           let soundDirectory = neoLemmix.soundDirectory {
            let identity = [neoLemmix.levelFingerprint, soundDirectory.path,
                            neoLemmix.gadgetSounds.values.sorted().joined(separator: ",")].joined(separator: "|")
            if loadedNeoLemmixSoundIdentity != identity {
                let resources = Bundle.main.resourceURL
                let names = Set(neoLemmix.gadgetSounds.values)
                let amiga = BundledGameResources.amigaSoundDirectory()
                enqueue(persistent: true) { player in
                    player.loadNeoLemmixSounds(names: names, soundDirectory: soundDirectory,
                        amigaDirectory: amiga, fallbackSoundDirectory: resources?.appendingPathComponent("NeoLemmix/sound"))
                }
                loadedNeoLemmixSoundIdentity = identity
            }
        }
        guard rewinding || !cues.isEmpty || !l2Requests.isEmpty else { return }
        resumeForCue()
        if rewinding {
            enqueue { $0.playRewindScrub() }
        } else if let l2Session {
            let bank = l2Session.soundBank
            let bottomFall = MobileSettings.current(from: .standard).classic.bottomFallSounds
            enqueue { player in
                Self.play(l2Requests, bank: bank, player: player, bottomFallSounds: bottomFall)
                player.play(cues)
            }
        } else if let chronicles = engine as? Lemmings3MobileSession, let bank = chronicles.soundBank {
            enqueue { Self.play(cues, bank: bank, player: $0) }
        } else {
            enqueue { $0.play(cues) }
        }
    }
    func ready() { guard !isTestAudioMuted, !suspended else { return }; prepare(); guard prepared else { return }; resumeForCue(); enqueue { $0.play(.ready) } }
    func rejectedAssignment() { guard !isTestAudioMuted, !suspended, prepared else { return }; resumeForCue(); enqueue { $0.play(.actionRejected) } }
    func releaseRate(_ rate: Int) { guard !isTestAudioMuted, !suspended, prepared else { return }; resumeForCue(); enqueue { $0.playReleaseRate(rate) } }
    func result(won: Bool) {
        guard !isTestAudioMuted, !suspended, prepared, !resultPlayed else { return }
        resultPlayed = true
        resumeForCue()
        enqueue { player in
            player.silencePreservingRescues()
            player.play(won ? .yippee : .actionRejected)
        }
    }
    func playChime(star: Int, ornament: Bool = false) {
        guard !isTestAudioMuted, !suspended, prepared else { return }
        resumeForCue()
        let samples = ResultChimeSamples.samples(star: star, ornament: ornament).map { Float($0) / 32768 }
        enqueue { $0.play(samples: samples, rate: ResultChimeSamples.sampleRate, gain: 1) }
    }
    func movieEffects() async -> MobileMovieEffects {
        let player = player
        let copy: SoundEffectPlayer = await withCheckedContinuation { continuation in
            playback.submit(persistent: true) { continuation.resume(returning: player.replayPlayer()) }
        }
        return MobileMovieEffects(player: copy)
    }
    func pause() { idleTask?.cancel(); idleTask = nil; keepOutputReady = false; playback.cancelPending(); enqueue(persistent: true) { $0.suspendOutput() } }
    func setVoiceLimit(_ count: Int) { enqueue { $0.setVoiceLimit(count) } }
    func suspend() { suspended = true; pause() }
    func resume() { guard !isTestAudioMuted else { return }; suspended = false }
    func stop() { idleTask?.cancel(); idleTask = nil; keepOutputReady = false; playback.cancelPending(); enqueue(persistent: true) { $0.stop() }; prepared = false }

    private func resumeForCue() {
        let logger = logger
        enqueue { player in
            do { try player.resumeOutput() }
            catch { logger.error("Effects resume failed: \(String(describing: error), privacy: .public)") }
        }
        scheduleIdleSuspension()
    }

    private func scheduleIdleSuspension() {
        guard idleTask == nil else { return }
        idleTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                // Short gaps between effects should not repeatedly restart the graph.
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard let self else { return }
                if self.keepOutputReady { continue }
                let player = self.player
                let parked: Bool = await withCheckedContinuation { continuation in
                    self.playback.submit(persistent: true) {
                        continuation.resume(returning: player.suspendOutputIfIdle())
                    }
                }
                guard !Task.isCancelled else { return }
                if parked { self.idleTask = nil; return }
            }
        }
    }

    nonisolated private static func play(_ requests: [Lemmings2SoundRequest], bank: Lemmings2SoundBank?,
                                        player: SoundEffectPlayer, bottomFallSounds: Bool) {
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

    nonisolated private static func play(_ cues: [PositionedSoundCue], bank: Lemmings3SoundBank, player: SoundEffectPlayer) {
        for cue in cues {
            guard let clip = bank.clips[cue.effect] else {
                player.play([cue])
                continue
            }
            player.play(samples: clip.samples, rate: clip.sampleRate, gain: 0.5,
                at: cue.point, semanticEffect: cue.effect)
        }
    }

    nonisolated private static func semanticEffect(for sample: Int) -> ClassicSoundEffect? {
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
                    cues.append(.init(effect, at: request.point)); continue
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
