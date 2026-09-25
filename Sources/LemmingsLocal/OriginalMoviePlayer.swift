import AppKit
import NxlvKit

/// Decodes one original FLIC frame at a time inside the game window.
@MainActor final class OriginalMoviePlayer: NSView {
    enum Movie: String, CaseIterable {
        case introduction = "INTRO.FLI", classic = "C-LEV15.FLI", shadow = "SHA-WALK.FLI"
        case egyptian = "E-LEV10.FLI", ending = "THE-END.FLI"
        var title: String {
            switch self {
            case .introduction: "Introduction"
            case .classic: "Classic tribe movie"
            case .shadow: "Shadow tribe movie"
            case .egyptian: "Egyptian tribe movie"
            case .ending: "Ending"
            }
        }
    }
    private let movie: FLICMovie
    private var decoder: FLICMovie.Decoder
    private var frameImage: CGImage?
    private var timer: Timer?
    private var lastTime = ProcessInfo.processInfo.systemUptime
    private var accumulator = 0.0
    private(set) var paused = false
    private(set) var displayedFrames = 0
    private(set) var finished = false
    private(set) var failure: String?
    private let playbackButton = GameActionButton(title: "Pause")
    private let backButton = GameActionButton(title: "Back", primary: false)
    var onClose: (() -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    init(url: URL) throws {
        movie = try FLICMovie(contentsOf: url)
        guard movie.width > 0, movie.height > 0, movie.width <= 1920, movie.height <= 1080,
              movie.frameCount > 0, movie.frameOffsets.count >= movie.frameCount else {
            throw SequelDataError.invalid("The original movie has invalid frame dimensions or missing frames.")
        }
        decoder = movie.makeDecoder()
        super.init(frame: .zero)
        try readFrame()
        playbackButton.onPress = { [weak self] in self?.togglePause() }
        backButton.onPress = { [weak self] in self?.close() }
        addSubview(playbackButton); addSubview(backButton)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Original Lemmings 3 movie")
        setAccessibilityHelp("Space pauses. Escape returns to the movie list.")
        updatePlaybackControls()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @discardableResult func present(owner: NSWindow?) -> Bool {
        guard GameScreen.shared.present(self, owner: owner, focus: playbackButton, onDismiss: { [weak self] in
            self?.stop()
            let callback = self?.onClose; self?.onClose = nil; callback?()
        }) else { return false }
        lastTime = ProcessInfo.processInfo.systemUptime
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let now = ProcessInfo.processInfo.systemUptime
                let elapsed = now - self.lastTime; self.lastTime = now
                guard !self.isHidden, self.window != nil else { return }
                self.advance(seconds: elapsed)
            }
        }
        return true
    }
    func stop() { timer?.invalidate(); timer = nil }
    func close() { GameScreen.shared.dismiss(self) }
    func togglePause() {
        guard !finished else { return }
        paused.toggle(); accumulator = 0; lastTime = ProcessInfo.processInfo.systemUptime
        updatePlaybackControls(); needsDisplay = true
    }
    private func updatePlaybackControls() {
        playbackButton.title = paused ? "Play" : "Pause"
        playbackButton.isEnabled = !finished
        playbackButton.needsDisplay = true
        if finished, window?.firstResponder === playbackButton { window?.makeFirstResponder(backButton) }
        setAccessibilityValue(failure ?? (finished ? "Movie ended" : paused ? "Paused" : "Playing"))
    }
    override func layout() {
        super.layout()
        playbackButton.frame = CGRect(x: bounds.midX - 184, y: bounds.height - 44, width: 174, height: 36)
        backButton.frame = CGRect(x: bounds.midX + 10, y: bounds.height - 44, width: 174, height: 36)
    }

    func advance(seconds: Double) {
        guard !paused, !finished, seconds.isFinite, seconds > 0 else { return }
        accumulator += min(seconds, 0.25)
        do {
            while accumulator >= movie.frameDuration && !finished {
                accumulator -= movie.frameDuration
                if displayedFrames == movie.frameCount { finished = true; stop(); break }
                try readFrame()
            }
        } catch { failure = String(describing: error); finished = true; stop() }
        updatePlaybackControls(); needsDisplay = true
    }
    private func readFrame() throws {
        guard let frame = try decoder.nextFrame() else {
            throw SequelDataError.invalid("The original movie ended before its declared final frame.")
        }
        let rgba = Data(frame.rgbaBytes())
        frameImage = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: CGDataProvider(data: rgba as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        displayedFrames += 1
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); bounds.fill()
        if let frameImage {
            let scale = min(bounds.width / CGFloat(movie.width), max(0, bounds.height - 76) / CGFloat(movie.height))
            let size = CGSize(width: CGFloat(movie.width) * scale, height: CGFloat(movie.height) * scale)
            let rect = CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - 76 - size.height) / 2,
                width: size.width, height: size.height)
            NSImage(cgImage: frameImage, size: size).draw(in: rect, from: .zero, operation: .sourceOver,
                fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
        }
        if let status = failure ?? (finished ? "Movie ended" : nil) {
            GamePixelText.draw(MacInterfaceRenderer.menuText(status),
                in: CGRect(x: 20, y: max(0, bounds.height - 72), width: max(0, bounds.width - 40), height: 24))
        }
    }
    override func keyDown(with event: NSEvent) {
        if event.isARepeat, [36, 76, 49, 53].contains(event.keyCode) { return }
        if event.keyCode == 53 || event.keyCode == 36 || event.keyCode == 76 { close() }
        else if event.keyCode == 49 { togglePause() }
        else { super.keyDown(with: event) }
    }
    override func mouseDown(with event: NSEvent) { if finished { close() } else { togglePause() } }
}
