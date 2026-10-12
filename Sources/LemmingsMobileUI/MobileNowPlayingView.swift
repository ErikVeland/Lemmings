#if os(iOS)
import LemmingsGameArt
import LemmingsMobileCore
import UIKit

/// A track change shares the Mac's bitmap lettering and never covers an input target.
@MainActor final class MobileNowPlayingView: UIView {
    private var title = ""
    private var soundtrack = ""
    private var dismissal: Task<Void, Never>?
    private var generation = UUID()

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
        let settings = MobileSettings.load(from: .standard).classic
        guard settings.showSongInfo else { hide(); return }
        let reduceMotion = UIAccessibility.isReduceMotionEnabled || settings.reduceMotion
        dismissal?.cancel()
        layer.removeAllAnimations()
        let token = UUID(); generation = token
        self.title = title; self.soundtrack = soundtrack
        accessibilityLabel = title + ", " + soundtrack
        isHidden = false; alpha = reduceMotion ? 1 : 0
        setNeedsDisplay()
        if !reduceMotion {
            UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
                self.alpha = 1
            }
        }
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, let self, self.generation == token else { return }
            let reduceMotion = UIAccessibility.isReduceMotionEnabled || MobileSettings.load(from: .standard).classic.reduceMotion
            UIView.animate(withDuration: reduceMotion ? 0 : 0.5, animations: { self.alpha = 0 }) { [weak self] _ in
                guard self?.generation == token else { return }
                self?.isHidden = true
            }
        }
    }
    func hide() {
        generation = UUID(); dismissal?.cancel(); dismissal = nil
        layer.removeAllAnimations(); isHidden = true
    }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        GameStoneArt.draw(in: context, frame: bounds, selected: false, pixel: 1)
        let inset = bounds.insetBy(dx: 12, dy: 8)
        let upper = CGRect(x: inset.minX, y: inset.minY, width: inset.width, height: inset.height / 2)
        let lower = CGRect(x: inset.minX, y: upper.maxY, width: inset.width, height: inset.height / 2)
        if let typography = MobileGameArt.typography {
            GamePixelTypography.draw(title, in: upper, context: context, typography: typography, palette: .green)
            GamePixelTypography.draw(soundtrack, in: lower, context: context, typography: typography, palette: .blue)
        } else {
            MobilePixelText.draw(title, in: upper, palette: .green)
            MobilePixelText.draw(soundtrack, in: lower)
        }
    }
}
#endif
