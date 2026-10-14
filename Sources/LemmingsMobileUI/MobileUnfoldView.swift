#if os(iOS) || os(tvOS)
import LemmingsGameArt
import LemmingsMobileCore
import UIKit

/// Decoration only. It neither delays navigation nor intercepts a player's input.
@MainActor final class MobileUnfoldView: UIView {
    private static let artwork: GameUnfoldArt? = Bundle.main.resourceURL.flatMap {
        GameUnfoldArt(directory: $0.appendingPathComponent("MacArtwork/lemmings"))
    }
    private let walker = CALayer()
    private var generation = UUID()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
        isHidden = true
        walker.magnificationFilter = .nearest
        walker.minificationFilter = .nearest
        layer.addSublayer(walker)
    }
    required init?(coder: NSCoder) { nil }

    func play(in region: CGRect) {
        stop()
        guard !UIAccessibility.isReduceMotionEnabled, !MobileSettings.load(from: .standard).classic.reduceMotion,
              let art = Self.artwork, region.width >= 280, region.height >= 88 else { return }
        frame = superview?.bounds ?? .zero
        let start = art.frame(in: region, progress: 0), end = art.frame(in: region, progress: 1)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        walker.frame = end
        walker.contents = art.frames.last
        CATransaction.commit()
        let walk = CAKeyframeAnimation(keyPath: "contents")
        walk.values = (0..<16).map { art.frames[$0 % art.frames.count] }
        walk.calculationMode = .discrete
        walk.duration = 1.2
        let move = CABasicAnimation(keyPath: "position")
        move.fromValue = CGPoint(x: start.midX, y: start.midY)
        move.toValue = CGPoint(x: end.midX, y: end.midY)
        move.duration = 1.2
        isHidden = false
        CATransaction.begin()
        let token = generation
        CATransaction.setCompletionBlock { [weak self] in
            guard self?.generation == token else { return }
            self?.stop()
        }
        walker.add(walk, forKey: "walk")
        walker.add(move, forKey: "move")
        CATransaction.commit()
    }

    func stop() {
        generation = UUID()
        walker.removeAllAnimations()
        isHidden = true
    }
}
#endif
