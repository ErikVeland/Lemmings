#if os(iOS) || os(tvOS)
import LemmingsAudio
import LemmingsMobileCore
import NxlvKit
import UIKit
import AVFAudio

/// Uses the shared music decks and level-theme assignment on iPad.
@MainActor final class MobileMusic {
    static let shared = MobileMusic()
    private var module = ModuleMusicPlayer()
    private var recordings = SoundtrackPlayer()
    private var dj = AdaptiveDJPlayer()
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
    private var resultTransitionTask: Task<Void, Never>?
    private var lastTrack: URL?
    private var lastPitchCents: Double?
    private var appliedRespectMuteSetting: Bool?
    private var cachedSettings = MobileSettings.current(from: .standard)
    private var profileID = MobileProfiles.defaultID
    private var compositionID: String?
    /// One main theme plays on the library menus for the whole launch.
    private var menuTheme: MenuThemeSelection.Choice?
    /// Launch loads art, saves and sync on many threads at once. A first theme
    /// started during that burst underruns its render thread and crackles.
    private static let launchSettleSeconds = 1.5
    private var launchSettled = false
    private var launchSettleTask: Task<Void, Never>?
    private var requestedMenu = (visible: false, active: false)
    private static let menuSuspendDelay = 0.4
    private var menuSuspendTask: Task<Void, Never>?
    private var menuKey: String { "menu|" + soundtrack }
    private(set) var currentTrackTitle: String?
    private(set) var currentSoundtrackName: String?
    var onTrackChange: ((String, String) -> Void)?
    var currentTrackURL: URL? { usingDJ ? dj.currentURL : lastTrack }
    private let audioObservers = MobileNotificationObserverBag()
    var audioDiagnostics: [AudioBufferStatistics] {
        usingDJ ? dj.audioDiagnostics : usingRecording ? [recordings.audioDiagnostics].compactMap { $0 } : [module.audioDiagnostics]
    }
    private init() {
        connectFailureMusic()
        audioObservers.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let resumeMenu = self.playing == self.menuKey && !self.inactive
                self.stop()
                // Media-services resets invalidate every existing engine and audio unit.
                self.module = ModuleMusicPlayer()
                self.recordings = SoundtrackPlayer()
                self.dj = AdaptiveDJPlayer()
                self.appliedRespectMuteSetting = nil
                self.applySettings()
                if resumeMenu && UIApplication.shared.applicationState == .active {
                    self.setMenu(visible: true, active: true)
                }
            }
        })
    }
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
    /// The rendered Macintosh SONG bank, as in the Mac app.
    let macintoshMusic = Bundle.main.resourceURL.flatMap { ClassicMacMusicLibrary(root: $0.appendingPathComponent("MacMusic")) }
    private var isTestAudioMuted: Bool { ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] == "muted" }

    var soundtrackNames: [String] {
        ["Original"] + (macintoshMusic == nil ? [] : [Self.macintosh]) + ["Adaptive DJ"] + (musicRoot.map { SoundtrackPlayer.soundtracks(at: $0).keys.sorted() } ?? [])
    }
    var soundtrack: String {
        get { soundtrackNames.contains(settings.soundtrack) ? settings.soundtrack : "Original" }
        set {
            var value = settings; value.soundtrack = newValue
            value.classic.music = Self.source(soundtrack: newValue)
            value.save(to: .standard, profileID: profileID)
            cachedSettings = value
            stop()
        }
    }
    var isEnabled: Bool {
        get { settings.musicEnabled }
        set { var value = settings; value.musicEnabled = newValue; value.save(to: .standard, profileID: profileID); applySettings() }
    }
    static let macintosh = "Macintosh"
    /// The shared setting that matches a mobile soundtrack choice.
    static func source(soundtrack: String) -> ClassicMusicSource {
        soundtrack == "Adaptive DJ" ? .adaptiveDJ : soundtrack == macintosh ? .macintoshMIDI : .amigaModules
    }
    func cycleSoundtrack() {
        let names = soundtrackNames
        soundtrack = names[((names.firstIndex(of: soundtrack) ?? 0) + 1) % names.count]
    }
    func selectProfile(_ id: String) {
        profileID = id
        applySettings()
    }
    func applySettings(profileID: String? = nil) {
        if let profileID { self.profileID = profileID }
        cachedSettings = MobileSettings.load(from: .standard, profileID: self.profileID)
        if appliedRespectMuteSetting != settings.respectMuteSetting {
            appliedRespectMuteSetting = settings.respectMuteSetting
            MobileAudioSessionController.applySettings()
        }
        let c = settings.classic
        if let playing, !playing.hasSuffix("|" + soundtrack) { stop() }
        module.setEnhancements(c.musicStyle == .modern ? .modern : .faithful)
        dj.setEnhancements(c.musicStyle == .modern ? .modern : .faithful)
        let volume = c.musicVolume
        module.setVolume(volume); recordings.setVolume(volume); dj.setVolume(volume)
        module.setMuted(!isEnabled || isTestAudioMuted)
        recordings.setMuted(!isEnabled || isTestAudioMuted)
        dj.setMuted(!isEnabled || isTestAudioMuted)
        if !isEnabled || volume <= 0 || isTestAudioMuted || (playing == menuKey && !c.menuMusic) { stop() }
    }

    /// Plays the main theme while the library shows and no level is open.
    func setMenu(visible: Bool, active: Bool) {
        requestedMenu = (visible, active)
        applySettings()
        guard visible, isEnabled, settings.classic.menuMusic, settings.classic.musicVolume > 0, !isTestAudioMuted else {
            if playing == menuKey { stop() }
            return
        }
        if playing == menuKey {
            if active { menuSuspendTask?.cancel(); menuSuspendTask = nil; if inactive { resume() }; return }
            // Folding or unfolding Duo deactivates the scene for a moment. Cutting the
            // decks there and fading them back in clicked, so wait before suspending.
            guard menuSuspendTask == nil, !inactive else { return }
            menuSuspendTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Self.menuSuspendDelay * 1_000_000_000))
                guard let self, !Task.isCancelled else { return }
                self.menuSuspendTask = nil
                if self.playing == self.menuKey, !self.requestedMenu.active { self.suspend() }
            }
            return
        }
        // A level's attempt owns the decks until it exits and stops them.
        guard active, playing == nil else { return }
        guard launchSettled else {
            guard launchSettleTask == nil else { return }
            launchSettleTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Self.launchSettleSeconds * 1_000_000_000))
                guard let self else { return }
                self.launchSettled = true
                self.launchSettleTask = nil
                // Use the latest library state: a level or the clock may have opened meanwhile.
                self.setMenu(visible: self.requestedMenu.visible, active: self.requestedMenu.active)
            }
            return
        }
        let theme = menuTheme ?? MenuThemeSelection.choose(macintoshAvailable: macintoshMusic != nil,
            otherVersions: musicRoot.map(MenuThemeSelection.otherVersions(at:)) ?? [])
        menuTheme = theme
        usingDJ = false; dj.stop()
        paused = false; inactive = false; resultComplete = false
        let recording: URL? = switch theme {
        case .macintoshLemming1: macintoshMusic?.root.appendingPathComponent("classic/lemming1.m4a")
        case let .recording(path): musicRoot?.appendingPathComponent(path)
        case .amigaIntro: nil
        }
        if let url = recording {
            module.stop()
            recordings.load([url], originalMix: theme == .macintoshLemming1 || settings.classic.musicStyle == .faithful)
            if recordings.play(index: 0) != nil {
                usingRecording = true; playing = menuKey
                announce(url, soundtrack: soundtrack); applyOutputState(); return
            }
        }
        // Any recording that fails to open falls back to the Amiga intro.
        recordings.stop(); usingRecording = false
        guard let intro = BundledGameResources.music("lemmings_music_mod")?.appendingPathComponent("intro.mod") else { return }
        do {
            try module.start()
            guard module.play(url: intro) != nil else { return }
            playing = menuKey; announce(intro, soundtrack: "Original")
            applyOutputState()
        } catch { playing = nil }
    }

    func play(identifier: String, index: Int, title: String, attemptID: UUID, context: MobileMusicContext = .init()) {
        applySettings()
        guard isEnabled, settings.classic.musicVolume > 0, !isTestAudioMuted else { return }
        let key = attemptID.uuidString + "|" + soundtrack
        guard playing != key else { return }
        lastPitchCents = nil
        let position = context.scorePosition ?? index
        let tune = MobileMusicAssignment.tune(identifier: identifier, index: position, title: title)
        compositionID = tune.game + "." + tune.track.lowercased()
        let cycle = MobileMusicAssignment.cycle(tune: tune, index: position, titles: context.titles, isFan: context.isFan)
        let source = moduleURL(tune)
        if playMacintosh(tune: tune, index: position, title: title) {
            module.stop(); usingDJ = false; dj.stop(); usingRecording = true; playing = key
            applyOutputState(); return
        }
        if let root = musicRoot {
            var pools = SoundtrackPlayer.djSoundtracks(at: root,
                includeOtherSoundtracks: true,
                seasonal: SoundtrackPlayer.isSeasonal(tune.folder))
            for (name, tracks) in SoundtrackPlayer.djSoundtracks(at: root, includeOtherSoundtracks: true,
                seasonal: !SoundtrackPlayer.isSeasonal(tune.folder)) {
                pools[name, default: []].append(contentsOf: tracks)
            }
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

    @discardableResult func shuffle(scope: SoundtrackCatalogue.ShuffleScope) -> Bool {
        guard isEnabled, !isTestAudioMuted, usingDJ, !paused, !inactive, !resultComplete else { return false }
        return dj.shuffle(scope: scope, fallbackTrackID: compositionID)
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
    /// The Mac app's Macintosh source: the original song for this level, without the modern mix.
    private func playMacintosh(tune: MobileMusicAssignment.Tune, index: Int, title: String) -> Bool {
        guard soundtrack == Self.macintosh, let macintoshMusic else { return false }
        let release: ClassicTitle? = tune.game == "holiday" ? .xmasLemmings1991 : tune.game == "ohno" ? .ohNoMoreLemmings : nil
        guard let url = macintoshMusic.track(index: index, levelTitle: title, title: release) else { return false }
        recordings.load([url], originalMix: true)
        guard recordings.play(index: 0) != nil else { return false }
        announce(url, soundtrack: soundtrack)
        return true
    }
    private func playRecording(tune: MobileMusicAssignment.Tune) -> Bool {
        guard let selected = recordingURL(tune: tune) else { return false }
        recordings.load([selected], originalMix: settings.classic.musicStyle == .faithful)
        guard recordings.play(index: 0) != nil else { return false }
        announce(selected, soundtrack: soundtrack)
        return true
    }
    private func announce(_ url: URL?, soundtrack: String) {
        guard let url else { return }
        guard url != lastTrack else { return }
        lastTrack = url
        // Name Macintosh songs as the Mac app does: the catalogue title of the composition.
        if let macintoshMusic, let relative = SoundtrackPlayer.relativePath(url, under: macintoshMusic.root),
           ClassicMacMusicLibrary.requiredPaths.contains(relative) {
            let family = relative.split(separator: "/").first.map(String.init) ?? "classic"
            let name = url.deletingPathExtension().lastPathComponent
            let catalogue = musicRoot.flatMap { SoundtrackCatalogue.load(at: $0) }
            let title = catalogue?.track(id: (family == "xmas" ? "holiday" : family) + "." + name)?.title ?? name.capitalized
            currentTrackTitle = title
            currentSoundtrackName = L10n.text("Macintosh (original)")
            onTrackChange?(title, L10n.text("Macintosh (original)"))
            return
        }
        let path = musicRoot.flatMap { SoundtrackPlayer.cataloguePath(url, root: $0) }
        let entry = musicRoot.flatMap { root in
            path.flatMap { SoundtrackCatalogue.load(at: root)?.entry(path: $0) }
        }
        let title = entry?.track.title ?? url.deletingPathExtension().lastPathComponent
        // The composition can stay the same when its celebratory arrangement starts.
        // Identify the recording, rather than repeating the soundtrack preference.
        let library = path.flatMap { path in
            MusicLibrary.catalogue(at: musicRoot)?.packs.first { pack in
                pack.files.contains { $0.path == "Music/" + path }
            }?.title
        }
        let source = library ?? entry.map {
            $0.variant.remix == "original"
                ? ($0.variant.port == "amiga" ? L10n.text("Amiga") : $0.variant.port.uppercased())
                : $0.variant.remix.replacingOccurrences(of: "-", with: " ").capitalized
        } ?? soundtrack
        currentTrackTitle = title
        currentSoundtrackName = source
        onTrackChange?(title, source)
    }

    /// Pause, speed and reverse scratches use the shared Mac transports.
    func setGameplayState(paused: Bool, speed: Double, rewinding: Bool = false) {
        guard self.paused != paused || self.speed != speed || self.rewinding != rewinding else { return }
        let changed = self.paused != paused
        self.paused = paused; self.speed = speed; self.rewinding = rewinding
        pitch.update(speed: settings.classic.variableSpeedEnabled ? speed : 1, at: ProcessInfo.processInfo.systemUptime)
        applyPitch()
        if changed { applyOutputState() }
    }
    func update(_ snapshot: MobileGameSnapshot, active: Int? = nil, nukeRemainingTicks: Int? = nil,
                allNukePopped: Bool? = nil, ticksPerSecond: Double = 17) {
        guard !isTestAudioMuted else { return }
        if resultComplete != snapshot.isComplete { resultComplete = snapshot.isComplete; applyOutputState() }
        let failed = snapshot.isComplete ? !snapshot.didWin : active.map {
            FailureMoodDecision.isUnrecoverable(saved: snapshot.saved, active: $0,
                unreleased: snapshot.total - snapshot.released, required: snapshot.required)
        } ?? false
        let allPopped = snapshot.isComplete || (allNukePopped ?? (active == 0))
        let now = ProcessInfo.processInfo.systemUptime
        failureMusic.update(failed: failed, isNuking: snapshot.isEndingRun, allPopped: allPopped,
            remainingTicks: nukeRemainingTicks, oneCountTicks: Int(ticksPerSecond), tick: snapshot.tick, now: now)
        nukeMood.update(active: snapshot.isEndingRun && settings.classic.hdEffectsEnabled,
            tick: snapshot.tick, durationTicks: 79, remainingTicks: nukeRemainingTicks, allPopped: allPopped, now: now)
        if snapshot.isComplete, nukeMood.amount > 0, resultTransitionTask == nil, !inactive {
            // Results have no frame loop. Finish this finite audio transition separately.
            resultTransitionTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
                    guard let self, !self.inactive else { return }
                    self.nukeMood.advanceReturn(at: ProcessInfo.processInfo.systemUptime)
                    if self.nukeMood.amount == 0 { self.resultTransitionTask = nil; return }
                }
            }
        }
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
        // Retry clears the track key before its vinyl brake finishes.
        // Lifecycle suspension must still park every existing transport.
        if inactive {
            module.suspendOutput(immediately: true)
            recordings.suspendOutput(immediately: true)
            dj.suspendOutput(immediately: true)
            return
        }
        guard playing != nil else { return }
        if paused && !resultComplete {
            let rhythm = settings.classic.pauseMusicBeatOnly
            module.suspendOutput(rhythmOnly: rhythm)
            recordings.suspendOutput(rhythmOnly: rhythm)
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
    func suspend() {
        menuSuspendTask?.cancel(); menuSuspendTask = nil
        inactive = true
        resultTransitionTask?.cancel(); resultTransitionTask = nil
        failureMusic.finish()
        nukeMood.advanceReturn(at: ProcessInfo.processInfo.systemUptime + NukeMusicSweep.returnDuration)
        applyOutputState()
    }
    func resume() { menuSuspendTask?.cancel(); menuSuspendTask = nil; inactive = false; applyOutputState() }
    func stop() {
        resultTransitionTask?.cancel(); resultTransitionTask = nil
        module.stop(); recordings.stop(); dj.stop()
        playing = nil; lastTrack = nil; currentTrackTitle = nil; currentSoundtrackName = nil; resultComplete = false
        lastPitchCents = nil
        nukeMood.reset(); failureMusic = FailureMusicTransition(); connectFailureMusic()
        module.setTempoScale(1); recordings.setPlaybackRate(1); dj.setPlaybackRate(1)
    }
}
#endif
