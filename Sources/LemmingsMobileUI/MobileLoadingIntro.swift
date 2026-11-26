#if os(iOS) || os(tvOS)
import LemmingsAudio
import LemmingsGameArt
import UIKit

@MainActor final class MobileLoadingIntro {
    private var pending: Task<Void, Never>?
    private var overlay: MobileLoadingIntroView?
    private var audio: MobileAudioSessionController?
    private var music: GameLoadingIntroMusic?
    private var musicChanged: (@MainActor () -> Void)?
    var isPresented: Bool { overlay != nil }
    var isPlayingMusic: Bool { music != nil }

    func start(in host: UIView, configuration: LemmingsMobileConfiguration, message: String, reduceMotion: Bool,
               volume: Double = 0, musicChanged: (@MainActor () -> Void)? = nil,
               isLoading: @escaping @MainActor () -> Bool) {
        stop()
        self.musicChanged = musicChanged
        let title = configuration == .ultimateLemmix ? "Ultimate Lemmix" : "Ultimate Lemmings"
        pending = Task { [weak self, weak host] in
            try? await Task.sleep(nanoseconds: GameLoadingIntroArt.visualDelay)
            guard !Task.isCancelled, let self, let host, isLoading(),
                  host.window?.windowScene?.activationState == .foregroundActive else { return }
            let overlay = MobileLoadingIntroView(title: title, message: message, reduceMotion: reduceMotion)
            overlay.frame = host.bounds
            self.overlay = overlay
            host.addSubview(overlay)
            guard volume > 0, ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] != "muted" else { return }
            try? await Task.sleep(nanoseconds: GameLoadingIntroArt.musicDelay)
            guard !Task.isCancelled, isLoading(), !MobileMusic.shared.startupAuthenticationPending,
                  host.window?.windowScene?.activationState == .foregroundActive,
                  MobileAudioSessionWorkQueue.shared.playbackAllowed else { return }
            self.startMusic(volume: volume, overlay: overlay)
        }
    }

    func bringToFront(in host: UIView) {
        guard let overlay, overlay.superview === host else { return }
        host.bringSubviewToFront(overlay)
    }

    func stop(restoreMenuMusic: Bool = true) {
        pending?.cancel()
        pending = nil
        overlay?.removeFromSuperview()
        overlay = nil
        stopMusic(restoreMenuMusic: restoreMenuMusic)
        musicChanged = nil
    }

    private func startMusic(volume: Double, overlay: MobileLoadingIntroView) {
        let audio = MobileAudioSessionController()
        self.audio = audio
        audio.onEvent = { [weak self] _ in self?.stopMusic(restoreMenuMusic: false) }
        audio.resume { [weak self, weak overlay] ready in
            guard let self, let overlay, self.overlay === overlay else { return }
            guard ready, overlay.window?.windowScene?.activationState == .foregroundActive else {
                self.stopMusic(restoreMenuMusic: false)
                return
            }
            let music = GameLoadingIntroMusic()
            guard music.play(volume: volume) else {
                self.stopMusic(restoreMenuMusic: false)
                return
            }
            self.music = music
            self.musicChanged?()
        }
    }

    private func stopMusic(restoreMenuMusic: Bool) {
        audio?.suspend()
        audio = nil
        let wasPlaying = music != nil
        music?.stop()
        music = nil
        if wasPlaying, restoreMenuMusic { musicChanged?() }
    }
}

@MainActor private final class MobileLoadingIntroView: UIView {
    private let title: String
    private let message: String
    private let reduceMotion: Bool
    private let start = CACurrentMediaTime()
    nonisolated(unsafe) private var displayLink: CADisplayLink?

    init(title: String, message: String, reduceMotion: Bool) {
        self.title = title
        self.message = message
        self.reduceMotion = reduceMotion
        super.init(frame: .zero)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentMode = .redraw
        backgroundColor = .black
        isAccessibilityElement = true
        accessibilityLabel = message
        accessibilityViewIsModal = true
    }

    required init?(coder: NSCoder) { nil }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        displayLink?.invalidate()
        displayLink = nil
        guard window != nil, !reduceMotion, !UIAccessibility.isReduceMotionEnabled else { return }
        let target = MobileDisplayLinkTarget { [weak self] _ in self?.setNeedsDisplay() }
        let link = CADisplayLink(target: target, selector: #selector(MobileDisplayLinkTarget.frame(_:)))
        link.preferredFramesPerSecond = 30
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    deinit { displayLink?.invalidate() }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let elapsed = reduceMotion || UIAccessibility.isReduceMotionEnabled ? 0 : CACurrentMediaTime() - start
        GameLoadingIntroArt.draw(in: bounds, title: title, message: message, elapsed: elapsed, context: context)
    }
}
#endif
