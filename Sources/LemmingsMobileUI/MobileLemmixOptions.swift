#if os(iOS) || os(tvOS)
import AVFAudio
import LemmingsMobileCore
import NxlvKit
import UIKit

/**
 * Keeps clean-edition choices in the current app's preferences domain.
 */
@MainActor final class MobileLemmixPreferences {
    private let defaults: UserDefaults
    private static let artworkKey = "lemmix.lixArtwork"
    private static let musicKey = "lemmix.music.enabled"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Self.artworkKey: true, Self.musicKey: true])
    }

    var lixArtworkEnabled: Bool {
        get { defaults.bool(forKey: Self.artworkKey) }
        set { defaults.set(newValue, forKey: Self.artworkKey) }
    }

    var musicEnabled: Bool {
        get { defaults.bool(forKey: Self.musicKey) }
        set { defaults.set(newValue, forKey: Self.musicKey) }
    }
}

/**
 * Plays only documented Lix menu or level entries from the bundled catalogue.
 */
@MainActor final class MobileLixMusicPlayer {
    var enabled: Bool {
        didSet { if !enabled { pause() } }
    }
    private let musicRoot: URL?
    private var player: AVAudioPlayer?
    private var currentURL: URL?
    private var mechanicalTest: Bool {
        ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] == "muted"
    }

    init(resources: URL?, enabled: Bool) {
        musicRoot = resources?.appendingPathComponent("Music", isDirectory: true)
        self.enabled = enabled
    }

    func play(menu: Bool, level: Int = 0) {
        guard enabled, !mechanicalTest, let musicRoot,
              let catalogue = SoundtrackCatalogue.load(at: musicRoot) else {
            stop()
            return
        }
        let tracks = catalogue.tracks.filter {
            $0.game == "lix" && $0.role == (menu ? "menu" : "level")
        }.sorted { $0.id < $1.id }
        guard !tracks.isEmpty else { stop(); return }
        let track = tracks[max(0, level) % tracks.count]
        guard let variant = track.variants.first(where: {
            $0.port == "lix" && $0.confidence == "documented" && $0.path.hasSuffix(".mp3")
        }) else { stop(); return }
        let url = musicRoot.appendingPathComponent(variant.path)
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true, values.isSymbolicLink != true else { stop(); return }
        if currentURL == url, player != nil {
            resume()
            return
        }
        do {
            let next = try AVAudioPlayer(contentsOf: url)
            next.numberOfLoops = -1
            next.volume = 0.55
            next.prepareToPlay()
            player?.stop()
            player = next
            currentURL = url
            next.play()
        } catch {
            stop()
        }
    }

    func pause() { player?.pause() }
    func resume() {
        guard enabled, !mechanicalTest else { return }
        player?.play()
    }
    func stop() {
        player?.stop()
        player = nil
        currentURL = nil
    }
}

/**
 * Presents artwork and music choices with the same pixel controls as gameplay.
 */
@MainActor final class MobileLemmixOptionsViewController: UIViewController {
    private let preferences: MobileLemmixPreferences
    private let canUseOriginalCharacters: Bool
    private let onChange: () -> Void
    private let heading = MobilePixelLabel()
    private let artwork = MobilePixelButton()
    private let music = MobilePixelButton()
    private let back = MobilePixelButton()

    init(preferences: MobileLemmixPreferences, canUseOriginalCharacters: Bool,
         onChange: @escaping () -> Void) {
        self.preferences = preferences
        self.canUseOriginalCharacters = canUseOriginalCharacters
        self.onChange = onChange
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { nil }

    override var preferredFocusEnvironments: [UIFocusEnvironment] { [artwork.isEnabled ? artwork : music] }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        heading.text = "SETTINGS"
        heading.palette = .green
        artwork.title = "LIX ARTWORK"
        artwork.isToggle = true
        artwork.isEnabled = canUseOriginalCharacters
        artwork.accessibilityHint = canUseOriginalCharacters ? nil
            : "Import your own Classic files to use original artwork."
        artwork.onPress = { [weak self] in
            guard let self, self.canUseOriginalCharacters else { return }
            self.preferences.lixArtworkEnabled.toggle()
            self.refresh()
            self.onChange()
        }
        music.title = "LIX MUSIC"
        music.isToggle = true
        music.onPress = { [weak self] in
            guard let self else { return }
            self.preferences.musicEnabled.toggle()
            self.refresh()
            self.onChange()
        }
        back.title = "BACK"
        back.isPrimary = true
        back.onPress = { [weak self] in self?.dismiss(animated: true) }
        [heading, artwork, music, back].forEach(view.addSubview)
        refresh()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.safeAreaLayoutGuide.layoutFrame
        let width = min(760, max(0, safe.width - 32))
        let x = safe.midX - width / 2
        let height: CGFloat = traitCollection.userInterfaceIdiom == .tv ? 72 : 52
        let top = max(safe.minY + 16, safe.midY - (height * 4 + 60) / 2)
        heading.frame = CGRect(x: x, y: top, width: width, height: 44)
        artwork.frame = CGRect(x: x, y: heading.frame.maxY + 24, width: width, height: height)
        music.frame = CGRect(x: x, y: artwork.frame.maxY + 16, width: width, height: height)
        back.frame = CGRect(x: x, y: music.frame.maxY + 36, width: width, height: height)
    }

    #if os(tvOS)
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .menu }) { dismiss(animated: true) }
        else { super.pressesEnded(presses, with: event) }
    }
    #endif

    private func refresh() {
        artwork.isSelectedState = !canUseOriginalCharacters || preferences.lixArtworkEnabled
        music.isSelectedState = preferences.musicEnabled
    }
}
#endif
