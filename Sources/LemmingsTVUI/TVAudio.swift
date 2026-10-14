#if os(tvOS)
import AVFoundation
import LemmingsAudio
import LemmingsMobileCore
import LemmingsTVCore
import NxlvKit

@MainActor final class TVAudio {
    private let music = ModuleMusicPlayer()
    private let effects = SoundEffectPlayer(voiceCount: 24)
    private let muted = ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] == "muted"
    private var runID: UUID?
    var onInterruption: ((Bool) -> Void)?
    private var observer: NSObjectProtocol?
    init() {
        music.setMuted(muted); effects.setMuted(muted)
        if !muted { try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default) }
        observer = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else { return }
            MainActor.assumeIsolated {
                self?.onInterruption?(type == AVAudioSession.InterruptionType.began.rawValue)
            }
        }
        if let root = BundledGameResources.amigaSoundDirectory() {
            _ = try? effects.loadAmigaSounds(directory: root, supplementDirectory: Bundle.main.resourceURL?.appendingPathComponent("Sounds"))
        }
    }
    func apply(_ preferences: TVPreferences) {
        music.setMuted(muted || !preferences.musicEnabled)
        effects.setMuted(muted || !preferences.effectsEnabled)
    }
    func start(_ game: TVGameExperience) {
        guard !muted else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        try? effects.start()
        try? effects.resumeOutput()
        if runID != game.runID {
            runID = game.runID
            let tune = MobileMusicAssignment.tune(identifier: game.session.levelIdentifier,
                index: game.session.levelIndex, title: game.content.summary.title)
            if let root = Bundle.main.resourceURL?.appendingPathComponent(L10n.text("Music/") + tune.folder),
               let urls = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil),
               let url = urls.first(where: { $0.deletingPathExtension().lastPathComponent.lowercased() == tune.track.lowercased() }) {
                _ = music.play(url: url)
            }
        }
        try? music.resumeOutput()
    }
    func pause() { music.suspendOutput(); effects.silence() }
    func stop() { music.stop(); effects.stop(); runID = nil }
    func update(_ game: TVGameExperience) {
        let cues = game.session.drainSoundCues()
        guard !muted else { return }
        let rect = game.viewport.visibleLevelRect
        effects.setViewport(.init(x: rect.x, y: rect.y, width: rect.width, height: rect.height))
        effects.setNukeActive(game.session.snapshot.isEndingRun)
        effects.play(cues)
    }
}
#endif
