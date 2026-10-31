#if os(iOS) || os(tvOS)
import AVFoundation
import LemmingsAudio
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit

/// Original media shares the bitmap menu, focus and input routes on touch devices and TV.
@MainActor final class MobileOriginalMediaController: UIViewController {
    private let directory: URL
    private let items: [MobileOriginalMedia.Item]
    private let canvas = MobileMenuCanvas(frame: .zero)
    private let scroll = MobileMenuScrollView()
    private let input = MobileInputAdapter()
    private let effects = SoundEffectPlayer(voiceCount: 12)
    private var soundtrack: AVAudioPlayer?
    private var media: MobileOriginalMedia?
    private var link: CADisplayLink?
    private var lastTime: Double?
    private var paused = false
    private var failure: String?
    var onClose: (() -> Void)?
    override var canBecomeFirstResponder: Bool { true }

    init(engine: String, directory: URL) {
        self.directory = directory; items = MobileOriginalMedia.Item.all(engine: engine)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.onViewportChange = { [weak self] in self?.canvas.viewportDidScroll() }
        view.addSubview(scroll); scroll.addSubview(canvas)
        canvas.onAction = { [weak self] in self?.perform($0) }
        #if os(tvOS)
        canvas.requiresNeutralActivation = true
        #endif
        input.settings = { MobileSettings.current(from: .standard).classic }
        input.isMenu = { true }
        input.isActive = { [weak self] in self?.view.window?.windowScene?.activationState == .foregroundActive }
        input.onMenuMove = { [weak self] in self?.canvas.moveFocus($0) }
        input.onMenuActivate = { [weak self] in self?.canvas.activateFocused() }
        input.onMenuBack = { [weak self] in self?.perform("back") }
        input.onMenuScroll = { [weak self] in self?.canvas.scrollInput(delta: CGFloat($0)) }
        input.onForcedPause = { [weak self] in self?.pause() }
        NotificationCenter.default.addObserver(self, selector: #selector(pause), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(pause), name: AVAudioSession.interruptionNotification, object: nil)
        rebuild()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
        MobileMusic.shared.suspend()
        let display = CADisplayLink(target: self, selector: #selector(advance))
        display.add(to: .main, forMode: .common); link = display
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        link?.invalidate(); link = nil; soundtrack?.stop(); effects.stop(); input.reset()
        NotificationCenter.default.removeObserver(self)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let fullDisplay = MobileSystemRegions.usesFullDisplay(in: view)
        let region = fullDisplay ? view.bounds : MobileSystemRegions.menuFrame(in: view)
        canvas.obstructionReferenceView = view
        canvas.viewportObstructions = MobileSystemRegions.isFoldable(in: view) ? MobileSystemRegions.layoutObstructions(in: view).map {
            CGRect(x: $0.frame.x, y: $0.frame.y, width: $0.frame.width, height: $0.frame.height)
        } : []
        var scrollFrame = region
        #if os(iOS)
        if view.bounds.height > view.bounds.width && view.bounds.width < 600
            && !MobileSystemRegions.read(in: view).contains(where: { $0.kind == .division }) {
            scrollFrame.origin.y = view.bounds.minY
            scrollFrame.size.height = view.bounds.height
        }
        #endif
        scroll.setViewportFrame(scrollFrame)
        let top = max(0, region.minY - scrollFrame.minY)
        let bottom = max(0, scrollFrame.maxY - region.maxY)
        scroll.unobscuredInsets = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
        let size = canvas.size(width: scroll.bounds.width, minimumHeight: region.height)
        canvas.frame = CGRect(x: 0, y: top, width: size.width, height: size.height)
        scroll.contentSize = CGSize(width: size.width, height: top + size.height + bottom)
    }
    private func rebuild() {
        if let media {
            canvas.page = MobileSequelMenuArt.movie(media.item, paused: paused, finished: media.finished, failure: failure)
            canvas.preview = MobileBitmapRenderer.image(media.frame)
        } else {
            canvas.preview = nil
            canvas.page = MobileSequelMenuArt.movies(engine: items.first == .tribesIntroduction ? "lemmings2" : "lemmings3", failure: failure)
        }
        input.reset(); view.setNeedsLayout()
    }
    private func perform(_ action: String) {
        if action == "back" {
            soundtrack?.stop(); soundtrack = nil; effects.stop()
            if media != nil { media = nil; failure = nil; rebuild() }
            else { dismiss(animated: false) { [weak self] in self?.onClose?() } }
        } else if action == "pause", media != nil {
            paused.toggle(); lastTime = nil; media?.discardElapsedTime()
            if paused { soundtrack?.pause(); effects.suspendOutput() }
            else { soundtrack?.play(); try? effects.resumeOutput() }
            rebuild()
        } else if action == "continue" { media?.requestContinue() }
        else if action.hasPrefix("movie."), let index = Int(action.dropFirst(6)), items.indices.contains(index) {
            do {
                media = try MobileOriginalMedia(item: items[index], directory: directory)
                failure = nil; paused = false; lastTime = nil
                let settings = MobileSettings.current(from: .standard)
                let muted = ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] == "muted"
                effects.setMuted(muted || settings.classic.sound == .silent); effects.setVolume(settings.classic.soundVolume)
                if !muted, settings.classic.sound != .silent { try? effects.start() }
                if !muted, settings.musicEnabled, settings.classic.music != .silent,
                   items[index] == .chronicles(.introduction), let root = Bundle.main.resourceURL {
                    soundtrack = try? AVAudioPlayer(contentsOf: root.appendingPathComponent("Music/All_New_World_of_Lemmings_(IBM_PC_AT)/01 Intro.m4a"))
                    soundtrack?.volume = Float(settings.classic.musicVolume); soundtrack?.play()
                }
            } catch { failure = error.localizedDescription; media = nil }
            rebuild()
        }
    }
    @objc private func pause() {
        paused = true; lastTime = nil; media?.discardElapsedTime()
        soundtrack?.pause(); effects.suspendOutput(); rebuild()
    }
    @objc private func advance(_ display: CADisplayLink) {
        input.poll(context: ObjectIdentifier(canvas), at: display.timestamp)
        let elapsed = lastTime.map { display.timestamp - $0 } ?? 0; lastTime = display.timestamp
        guard let media, !paused, !media.finished, failure == nil else { return }
        do {
            try media.advance(seconds: elapsed)
            canvas.preview = MobileBitmapRenderer.image(media.frame)
            for request in media.drainSounds() {
                guard ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] != "muted",
                      let bank = media.soundBank, bank.clips.indices.contains(request.sample) else { continue }
                let clip = bank.clips[request.sample]
                effects.play(samples: clip.samples,
                    rate: request.timeConstant.map { 1_000_000 / Double(256 - Int($0)) } ?? clip.sampleRate, gain: 0.5)
            }
            if media.finished { soundtrack?.stop(); effects.stop(); rebuild() }
        } catch { failure = error.localizedDescription; soundtrack?.stop(); effects.stop(); rebuild() }
    }
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .menu }) { perform("back"); return }
        if presses.contains(where: { $0.type == .playPause }) { perform("pause"); return }
        super.pressesBegan(presses.subtracting(input.began(presses)), with: event)
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses.subtracting(input.ended(presses)), with: event)
    }
}
#endif
