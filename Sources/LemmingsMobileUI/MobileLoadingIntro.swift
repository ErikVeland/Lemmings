#if os(iOS)
import LemmingsGameArt
import NxlvKit
import UIKit

/// Visual feedback only. The level preparation task never waits for this view or its timer.
@MainActor final class MobileLoadingIntro {
    private var pending: Task<Void, Never>?
    private var overlay: MobileLoadingIntroView?
    var isPresented: Bool { overlay != nil }

    func start(in host: UIView, title: String, reduceMotion: Bool, reduceFlashes: Bool,
               isLoading: @escaping @MainActor () -> Bool, cancel: @escaping @MainActor () -> Void) {
        stop()
        pending = Task { [weak self, weak host] in
            do { try await Task.sleep(nanoseconds: GameLoadingIntroArt.visualDelay) } catch { return }
            guard !Task.isCancelled, let self, let host, isLoading(),
                  host.window?.windowScene?.activationState == .foregroundActive else { return }
            let overlay = MobileLoadingIntroView(title: title, reduceMotion: reduceMotion,
                                                reduceFlashes: reduceFlashes, cancel: cancel)
            overlay.frame = host.bounds
            self.overlay = overlay
            host.addSubview(overlay)
        }
    }

    func bringToFront(in host: UIView) {
        guard let overlay, overlay.superview === host, host.subviews.last !== overlay else { return }
        host.bringSubviewToFront(overlay)
    }

    func stop() {
        pending?.cancel()
        pending = nil
        overlay?.removeFromSuperview()
        overlay = nil
    }
}

/// Decorative checking scenery. It never owns input, VoiceOver or the startup task.
@MainActor final class MobileStartupCracktroView: UIView {
    private var start: CFTimeInterval = 0
    nonisolated(unsafe) private var displayLink: CADisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentMode = .redraw
        contentScaleFactor = 1
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        isHidden = true
    }

    required init?(coder: NSCoder) { nil }

    func begin(reduceMotion: Bool, reduceFlashes: Bool) {
        start = CACurrentMediaTime()
        isHidden = false
        setNeedsDisplay()
        guard !reduceMotion, !reduceFlashes, !UIAccessibility.isReduceMotionEnabled else { return }
        let target = MobileDisplayLinkTarget { [weak self] _ in
            guard let self, window?.windowScene?.activationState == .foregroundActive else { return }
            setNeedsDisplay()
        }
        let link = CADisplayLink(target: target, selector: #selector(MobileDisplayLinkTarget.frame(_:)))
        link.preferredFramesPerSecond = 15
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stopAnimating() }
    }

    deinit { displayLink?.invalidate() }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let elapsed = displayLink == nil || UIAccessibility.isReduceMotionEnabled ? 0 : CACurrentMediaTime() - start
        GameLoadingIntroArt.drawBackdrop(in: bounds, elapsed: elapsed, context: context)
    }
}

@MainActor private final class MobileLoadingIntroView: UIView {
    private let title: String
    private let message = L10n.text("Loading...")
    private let reduceMotion: Bool
    private let reduceFlashes: Bool
    private let cancelHandler: @MainActor () -> Void
    private let cancelButton = UIButton(type: .system)
    private let status = UILabel()
    private let start = CACurrentMediaTime()
    nonisolated(unsafe) private var displayLink: CADisplayLink?

    init(title: String, reduceMotion: Bool, reduceFlashes: Bool, cancel: @escaping @MainActor () -> Void) {
        self.title = title
        self.reduceMotion = reduceMotion
        self.reduceFlashes = reduceFlashes
        cancelHandler = cancel
        super.init(frame: .zero)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentMode = .redraw
        backgroundColor = UIColor(red: 8 / 255, green: 7 / 255, blue: 25 / 255, alpha: 1)
        accessibilityViewIsModal = true
        status.accessibilityLabel = message
        status.accessibilityIdentifier = "level.cracktro.status"
        status.isAccessibilityElement = true
        status.accessibilityTraits = .staticText
        status.frame = .zero
        addSubview(status)
        var configuration = UIButton.Configuration.borderedTinted()
        configuration.title = L10n.text("Cancel")
        configuration.baseForegroundColor = .white
        cancelButton.configuration = configuration
        cancelButton.accessibilityIdentifier = "level.cracktro.cancel"
        cancelButton.addAction(UIAction { [weak self] _ in self?.cancelHandler() }, for: .primaryActionTriggered)
        addSubview(cancelButton)
        accessibilityElements = [status, cancelButton]
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        let safe = safeAreaLayoutGuide.layoutFrame
        let size = cancelButton.sizeThatFits(CGSize(width: max(44, safe.width), height: 54))
        let width = min(safe.width, max(104, size.width + 16))
        status.frame = CGRect(x: safe.midX - 20, y: safe.midY - 20, width: 40, height: 40)
        cancelButton.frame = CGRect(x: safe.midX - width / 2, y: safe.maxY - 56, width: width, height: 44)
    }

    override func accessibilityPerformEscape() -> Bool {
        cancelHandler()
        return true
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        displayLink?.invalidate()
        displayLink = nil
        guard window != nil, !reduceMotion, !reduceFlashes, !UIAccessibility.isReduceMotionEnabled else { return }
        let target = MobileDisplayLinkTarget { [weak self] _ in self?.setNeedsDisplay() }
        let link = CADisplayLink(target: target, selector: #selector(MobileDisplayLinkTarget.frame(_:)))
        link.preferredFramesPerSecond = 30
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    deinit { displayLink?.invalidate() }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let elapsed = GameLoadingIntroArt.frameElapsed(CACurrentMediaTime() - start,
            reduceMotion: reduceMotion || UIAccessibility.isReduceMotionEnabled, reduceFlashes: reduceFlashes)
        // Reserve space below the artwork for the touch target, even in landscape.
        let artwork = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width,
                             height: max(0, cancelButton.frame.minY - 8 - bounds.minY))
        GameLoadingIntroArt.draw(in: artwork, title: title, message: message, elapsed: elapsed, context: context)
    }
}
#endif
