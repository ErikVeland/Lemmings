#if os(iOS) || os(tvOS)
import LemmingsGameArt
import LemmingsMobileCore
import UIKit

/// Decoration stays behind the scrolling menu and has no input or accessibility surface.
@MainActor final class MobileHomeBackdropView: UIView {
    private var image: CGImage?
    private let artwork = UIImageView()
    private let shade = UIView()
    private var start = CGPoint.zero
    private var goal = CGPoint.zero
    private var clock = GameHomeBackdropClock()
    var canAnimate: Bool {
        guard let image, start != goal, bounds.width > 0, bounds.height > 0 else { return false }
        let size = CGSize(width: image.width, height: image.height)
        let from = GameHomeBackdropArt.source(imageSize: size, viewSize: bounds.size, start: start, goal: start, elapsed: 0)
        let to = GameHomeBackdropArt.source(imageSize: size, viewSize: bounds.size, start: goal, goal: goal, elapsed: 0)
        return from != to
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false; isAccessibilityElement = false
        accessibilityElementsHidden = true; backgroundColor = .black; clipsToBounds = true
        artwork.layer.magnificationFilter = .nearest
        artwork.layer.minificationFilter = .nearest
        artwork.contentMode = .scaleToFill
        addSubview(artwork)
        shade.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        addSubview(shade)
    }
    required init?(coder: NSCoder) { nil }
    func show(_ scenery: MobileHomeBackdrop?) {
        image = scenery.flatMap { MobileBitmapRenderer.image($0.frame) }
        artwork.image = image.map { UIImage(cgImage: $0) }
        start = scenery.map { CGPoint(x: $0.start.x, y: $0.start.y) } ?? .zero
        goal = scenery.map { CGPoint(x: $0.goal.x, y: $0.goal.y) } ?? start
        clock = GameHomeBackdropClock(); setNeedsLayout()
    }
    func advance(at now: TimeInterval, active: Bool, reduceMotion: Bool) {
        let previous = clock.elapsed
        clock.advance(at: now, active: active && image != nil, reduceMotion: reduceMotion)
        if clock.elapsed != previous { setNeedsLayout() }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        shade.frame = bounds
        guard let image, bounds.width > 0, bounds.height > 0 else { return }
        let source = GameHomeBackdropArt.source(imageSize: CGSize(width: image.width, height: image.height),
            viewSize: bounds.size, start: start, goal: goal, elapsed: clock.elapsed)
        let scale = bounds.width / source.width
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        artwork.frame = CGRect(x: -source.minX * scale, y: -source.minY * scale,
            width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        CATransaction.commit()
    }
}
#endif
