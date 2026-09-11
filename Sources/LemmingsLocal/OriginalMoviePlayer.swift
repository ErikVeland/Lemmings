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
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Original Lemmings 3 movie. Space pauses. Escape returns to the movie list.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @discardableResult func present(owner: NSWindow?) -> Bool {
        guard GameScreen.shared.present(self, owner: owner, onDismiss: { [weak self] in
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
    func togglePause() { paused.toggle(); accumulator = 0; lastTime = ProcessInfo.processInfo.systemUptime; needsDisplay = true }

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
        needsDisplay = true
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
            let scale = min(bounds.width / CGFloat(movie.width), max(0, bounds.height - 40) / CGFloat(movie.height))
            let size = CGSize(width: CGFloat(movie.width) * scale, height: CGFloat(movie.height) * scale)
            let rect = CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - 40 - size.height) / 2,
                width: size.width, height: size.height)
            NSImage(cgImage: frameImage, size: size).draw(in: rect, from: .zero, operation: .sourceOver,
                fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
        }
        let label = failure.map { "Movie could not continue: \($0) · Esc: back" }
            ?? (finished ? "Movie ended · Esc: back" : paused ? "Paused · Space: play · Esc: back" : "Space: pause · Esc: back")
        label.draw(in: CGRect(x: 20, y: max(0, bounds.height - 30), width: max(0, bounds.width - 40), height: 24),
            withAttributes: [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 14)])
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 || event.keyCode == 36 { close() }
        else if event.keyCode == 49 { togglePause() }
        else { super.keyDown(with: event) }
    }
    override func mouseDown(with event: NSEvent) { if finished { close() } else { togglePause() } }
}
