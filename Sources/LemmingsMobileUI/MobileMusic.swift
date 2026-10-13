#if os(iOS)
import LemmingsAudio
import LemmingsMobileCore
import NxlvKit
import UIKit

/// Uses the shared music decks and level-theme assignment on iPad.
@MainActor final class MobileMusic {
    static let shared = MobileMusic()
    private let module = ModuleMusicPlayer()
    private let recordings = SoundtrackPlayer()
    private let dj = AdaptiveDJPlayer()
    private var playing: String?
    private var usingRecording = false
    private var usingDJ = false
    private var paused = true
    private var resultComplete = false
    private var inactive = false
    private var speed = 1.0
    private var rewinding = false
    private var pitch = GameplayMusicPitch()
    private var failureMusic = FailureMusicTransition()
    private let nukeMood = NukeMusicSweep()
    private var lastTrack: URL?
    private var lastPitchCents: Double?
    private var cachedSettings = MobileSettings.load(from: .standard)
    var onTrackChange: ((String, String) -> Void)?
    var currentTrackURL: URL? { usingDJ ? dj.currentURL : lastTrack }
    private init() { connectFailureMusic() }
    private func connectFailureMusic() {
        failureMusic.onChange = { [weak self] rate in
            self?.module.setTempoScale(rate); self?.recordings.setPlaybackRate(rate); self?.dj.setPlaybackRate(rate)
        }
        nukeMood.onChange = { [weak self] amount in
            self?.module.setNukeAmount(Float(amount)); self?.recordings.setNukeAmount(Float(amount)); self?.dj.setNukeAmount(Float(amount))
        }
    }

    private var settings: MobileSettings { cachedSettings }
    private var musicRoot: URL? { Bundle.main.resourceURL?.appendingPathComponent("Music") }
    private var isTestAudioMuted: Bool { ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] == "muted" }

    var soundtrackNames: [String] {
        ["Original", "Adaptive DJ"] + (musicRoot.map { SoundtrackPlayer.soundtracks(at: $0).keys.sorted() } ?? [])
    }
    var soundtrack: String {
        get { soundtrackNames.contains(settings.soundtrack) ? settings.soundtrack : "Original" }
        set {
            var value = settings; value.soundtrack = newValue
            value.classic.music = newValue == "Adaptive DJ" ? .adaptiveDJ : .amigaModules
            value.save(to: .standard)
            cachedSettings = value
            stop()
        }
    }
    var isEnabled: Bool {
        get { settings.musicEnabled }
        set { var value = settings; value.musicEnabled = newValue; value.save(to: .standard); applySettings() }
    }
    func cycleSoundtrack() {
        let names = soundtrackNames
        soundtrack = names[((names.firstIndex(of: soundtrack) ?? 0) + 1) % names.count]
    }
    func applySettings() {
        cachedSettings = MobileSettings.load(from: .standard)
        let c = settings.classic
        if let playing, !playing.hasSuffix("|" + soundtrack) { stop() }
        module.setEnhancements(c.musicStyle == .modern ? .modern : .faithful)
        dj.setEnhancements(c.musicStyle == .modern ? .modern : .faithful)
        let volume = c.musicVolume
        module.setVolume(volume); recordings.setVolume(volume); dj.setVolume(volume)
        module.setMuted(!isEnabled || isTestAudioMuted)
        recordings.setMuted(!isEnabled || isTestAudioMuted)
        dj.setMuted(!isEnabled || isTestAudioMuted)
        if !isEnabled || isTestAudioMuted { stop() }
    }

    func play(identifier: String, index: Int, title: String, attemptID: UUID, context: MobileMusicContext = .init()) {
        applySettings()
        guard isEnabled, !isTestAudioMuted else { return }
        let key = attemptID.uuidString + "|" + soundtrack
        guard playing != key else { return }
        lastPitchCents = nil
        let position = context.scorePosition ?? index
        let tune = MobileMusicAssignment.tune(identifier: identifier, index: position, title: title)
        let cycle = MobileMusicAssignment.cycle(tune: tune, index: position, titles: context.titles, isFan: context.isFan)
        let source = moduleURL(tune)
        if soundtrack == "Adaptive DJ" || context.isLearningJourney, let root = musicRoot {
            var pools = SoundtrackPlayer.djSoundtracks(at: root,
                includeOtherSoundtracks: settings.classic.djIncludesOtherSoundtracks,
                seasonal: SoundtrackPlayer.isSeasonal(tune.folder))
            if let source { pools["Original", default: []].append(source) }
            dj.load(soundtracks: pools, catalogueRoot: root)
            dj.setCelebrationAlternates(settings.classic.djIncludesOtherSoundtracks)
            let started: Bool
            if soundtrack == "Adaptive DJ" {
                started = dj.startJourney(trackID: tune.game + "." + tune.track.lowercased(), cycle: cycle,
                    identity: attemptID.uuidString, fallback: source, includeAlternates: settings.classic.djIncludesOtherSoundtracks)
            } else {
                let selected = recordingURL(tune: tune) ?? source
                    ?? SoundtrackPlayer.recording(trackID: tune.game + "." + tune.track.lowercased(), root: root)
                started = selected.map { dj.startLevel(url: $0, identity: attemptID.uuidString) } ?? false
            }
            if started {
                module.stop(); recordings.stop(); usingDJ = true; usingRecording = false
                playing = key
                dj.onTrackChange = { [weak self] _ in self?.announce(self?.dj.currentURL, soundtrack: self?.soundtrack ?? "Original") }
                announce(dj.currentURL, soundtrack: soundtrack)
                applyOutputState(); return
            }
        }
        usingDJ = false; dj.stop()
        if playRecording(tune: tune) {
            module.stop(); usingRecording = true; playing = key
            applyOutputState(); return
        }
        recordings.stop(); usingRecording = false
        guard let source else { return }
        do {
            try module.start()
            guard module.play(url: source) != nil else { return }
            playing = key; announce(source, soundtrack: "Original")
            applyOutputState()
        } catch { playing = nil }
    }

    private func moduleURL(_ tune: MobileMusicAssignment.Tune) -> URL? {
        guard let root = BundledGameResources.music(tune.folder) else { return nil }
        return (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil))?.first {
            $0.deletingPathExtension().lastPathComponent.lowercased() == tune.track.lowercased()
                && $0.pathExtension.lowercased() == "mod"
        }
    }
    private func recordingURL(tune: MobileMusicAssignment.Tune) -> URL? {
        guard soundtrack != "Original", soundtrack != "Adaptive DJ", let root = musicRoot,
              let tracks = SoundtrackPlayer.soundtracks(at: root)[soundtrack] else { return nil }
        return tracks.first {
            SoundtrackPlayer.matches($0, trackID: tune.game + "." + tune.track.lowercased(), root: root)
        }
    }
    private func playRecording(tune: MobileMusicAssignment.Tune) -> Bool {
        guard let selected = recordingURL(tune: tune) else { return false }
        recordings.load([selected], originalMix: settings.classic.musicStyle == .faithful)
        guard recordings.play(index: 0) != nil else { return false }
        announce(selected, soundtrack: soundtrack)
        return true
    }
    private func announce(_ url: URL?, soundtrack: String) {
        guard let url, url != lastTrack else { return }
        lastTrack = url
        let title = musicRoot.flatMap { root in
            SoundtrackPlayer.cataloguePath(url, root: root).flatMap { SoundtrackCatalogue.load(at: root)?.entry(path: $0)?.track.title }
        } ?? url.deletingPathExtension().lastPathComponent
        onTrackChange?(title, soundtrack)
    }

    /// Pause, speed and reverse scratches use the shared Mac transports.
    func setGameplayState(paused: Bool, speed: Double, rewinding: Bool = false) {
        let changed = self.paused != paused
        self.paused = paused; self.speed = speed; self.rewinding = rewinding
        pitch.update(speed: settings.classic.variableSpeedEnabled ? speed : 1, at: ProcessInfo.processInfo.systemUptime)
        applyPitch()
        if changed { applySettings(); applyOutputState() }
    }
    func update(_ snapshot: MobileGameSnapshot, active: Int? = nil, nukeRemainingTicks: Int? = nil,
                allNukePopped: Bool? = nil, ticksPerSecond: Double = 17) {
        guard !isTestAudioMuted else { return }
        if resultComplete != snapshot.isComplete { resultComplete = snapshot.isComplete; applyOutputState() }
        let failed = snapshot.isComplete ? !snapshot.didWin : active.map {
            FailureMoodDecision.isUnrecoverable(saved: snapshot.saved, active: $0,
                unreleased: snapshot.total - snapshot.released, required: snapshot.required)
        } ?? false
        let allPopped = allNukePopped ?? (snapshot.isComplete || active == 0)
        let now = ProcessInfo.processInfo.systemUptime
        failureMusic.update(failed: failed, isNuking: snapshot.isEndingRun, allPopped: allPopped,
            remainingTicks: nukeRemainingTicks, oneCountTicks: Int(ticksPerSecond), tick: snapshot.tick, now: now)
        nukeMood.update(active: snapshot.isEndingRun && settings.classic.hdEffectsEnabled,
            tick: snapshot.tick, durationTicks: 79, remainingTicks: nukeRemainingTicks, allPopped: allPopped, now: now)
        guard usingDJ else { return }
        dj.updateTelemetry(.init(releasedCount: snapshot.released, totalCount: snapshot.total,
            savedCount: snapshot.saved, requiredCount: snapshot.required, releaseRate: snapshot.releaseRate ?? 50,
            remainingSeconds: snapshot.remainingSeconds, isNuking: snapshot.isEndingRun,
            didWin: snapshot.didWin, isComplete: snapshot.isComplete))
    }
    func advance() {
        guard !inactive, !isTestAudioMuted else { return }
        let now = ProcessInfo.processInfo.systemUptime
        failureMusic.advance(at: now); nukeMood.advanceReturn(at: now)
        pitch.update(speed: settings.classic.variableSpeedEnabled ? speed : 1, at: now)
        applyPitch()
    }
    private func applyPitch() {
        if let lastPitchCents, abs(lastPitchCents - pitch.cents) < 0.1 { return }
        lastPitchCents = pitch.cents
        module.setSpeedPitch(pitch.cents); recordings.setSpeedPitch(pitch.cents); dj.setSpeedPitch(pitch.cents)
    }
    private func applyOutputState() {
        guard playing != nil else { return }
        if (paused && !resultComplete) || inactive {
            let rhythm = !inactive && settings.classic.pauseMusicBeatOnly
            module.suspendOutput(rhythmOnly: rhythm); recordings.suspendOutput(rhythmOnly: rhythm)
            dj.suspendOutput(rhythmOnly: rhythm)
        } else {
            try? module.resumeOutput(); recordings.resumeOutput(); dj.resumeOutput()
        }
    }
    func playRewind() {
        guard !inactive, isEnabled, !isTestAudioMuted else { return }
        module.playRewind(); recordings.playRewind(); dj.playRewind()
    }
    func vinylStop() { module.vinylStop(); recordings.vinylStop(); dj.vinylStop(); playing = nil }
    func suspend() { inactive = true; applyOutputState() }
    func resume() { inactive = false; applyOutputState() }
    func stop() {
        module.stop(); recordings.stop(); dj.stop()
        playing = nil; lastTrack = nil; resultComplete = false
        lastPitchCents = nil
        nukeMood.reset(); failureMusic = FailureMusicTransition(); connectFailureMusic()
        module.setTempoScale(1); recordings.setPlaybackRate(1); dj.setPlaybackRate(1)
    }
}
#endif
