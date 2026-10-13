#if os(iOS)
import LemmingsGameArt
import LemmingsMobileCore
import UIKit

/// One Retina surface for every countdown; it never receives gameplay input.
@MainActor final class MobileBombCountdownView: UIView {
    private let renderer = BombCountdownRenderer()
    private var countdowns: [MobileBombCountdown] = []
    private var viewport = MobileViewport(levelSize: .init(width: 1, height: 1), viewSize: .init(width: 1, height: 1))
    private var projection: ((CGPoint) -> CGPoint)?

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        contentMode = .redraw
    }
    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func update(_ countdowns: [MobileBombCountdown], viewport: MobileViewport,
        project: ((CGPoint) -> CGPoint)?) {
        self.countdowns = countdowns; self.viewport = viewport; projection = project
        isHidden = countdowns.isEmpty
        setNeedsDisplay()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        contentScaleFactor = window?.screen.scale ?? traitCollection.displayScale
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.clip(to: bounds)
        for countdown in countdowns where viewport.visibleLevelRect.contains(countdown.anchor) {
            let point = viewport.viewPoint(fromLevel: countdown.anchor)
            let anchor = CGPoint(x: point.x, y: point.y)
            renderer.draw(seconds: countdown.seconds, above: projection?(anchor) ?? anchor,
                zoom: viewport.zoom, in: context)
        }
    }
}
#endif
