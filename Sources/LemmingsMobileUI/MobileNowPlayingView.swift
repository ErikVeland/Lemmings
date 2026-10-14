#if os(iOS) || os(tvOS)
import LemmingsGameArt
import LemmingsMobileCore
import UIKit

/// A track change shares the Mac's bitmap lettering and never covers an input target.
@MainActor final class MobileNowPlayingView: UIView {
    private var title = ""
    private var soundtrack = ""
    private var dismissal: Task<Void, Never>?
    private var generation = UUID()
    private var displayArea = CGRect.zero
    private var card: MusicTitleCard.Layout?
    private var shownAt: TimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        isHidden = true
    }
    required init?(coder: NSCoder) { nil }

    func show(title: String, soundtrack: String) {
        let settings = MobileSettings.current(from: .standard).classic
        guard settings.showSongInfo else { hide(); return }
        let reduceMotion = UIAccessibility.isReduceMotionEnabled || settings.reduceMotion
        dismissal?.cancel()
        layer.removeAllAnimations()
        let token = UUID(); generation = token
        self.title = title; self.soundtrack = soundtrack
        shownAt = ProcessInfo.processInfo.systemUptime
        rebuildCard()
        accessibilityLabel = title + ", " + soundtrack
        isHidden = false; alpha = reduceMotion ? 1 : 0
        setNeedsDisplay()
        if !reduceMotion {
            UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
                self.alpha = 1
            }
        }
        scheduleDisplay(token: token)
    }
    func position(in area: CGRect) {
        guard displayArea != area else { return }
        displayArea = area
        rebuildCard()
        guard !isHidden else { return }
        generation = UUID()
        dismissal?.cancel(); layer.removeAllAnimations(); alpha = 1
        scheduleDisplay(token: generation)
    }
    private func rebuildCard() {
        card = MusicTitleCard.layout(title: title, soundtrack: soundtrack,
            maximumWidth: max(0, displayArea.width - 16),
            maximumHeight: max(0, min(displayArea.height - 16, displayArea.height * 0.45)))
        frame = MusicTitleCard.frame(size: card?.size ?? .zero, in: displayArea, margin: 8)
        setNeedsDisplay()
    }
    private func scheduleDisplay(token: UUID) {
        dismissal = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.generation == token, let card = self.card, !card.pages.isEmpty else { return }
                let elapsed = ProcessInfo.processInfo.systemUptime - self.shownAt
                let reduceMotion = UIAccessibility.isReduceMotionEnabled || MobileSettings.current(from: .standard).classic.reduceMotion
                let fadeDuration: TimeInterval = reduceMotion ? 0 : 0.5
                let dismissAt = card.duration - fadeDuration
                if elapsed >= dismissAt {
                    UIView.animate(withDuration: fadeDuration, animations: { self.alpha = 0 }) { [weak self] _ in
                        guard self?.generation == token else { return }
                        self?.isHidden = true
                    }
                    return
                }
                self.setNeedsDisplay()
                let delay = min(card.nextPageTime(after: elapsed), dismissAt) - elapsed
                try? await Task.sleep(for: .seconds(max(0.01, delay)))
            }
        }
    }
    func hide() {
        generation = UUID(); dismissal?.cancel(); dismissal = nil
        layer.removeAllAnimations(); isHidden = true
    }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        guard let card else { return }
        MusicTitleCard.draw(card, elapsed: ProcessInfo.processInfo.systemUptime - shownAt,
                           typography: MobileGameArt.typography, in: context)
    }
}
#endif
