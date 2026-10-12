#if os(iOS)
import LemmingsMobileCore
import UIKit

@MainActor final class MobilePlayfieldView: UIView, UIGestureRecognizerDelegate {
    var blockedInputFrames: [CGRect] = []
    var onTouchEffects: (([MobileTouchEffect]) -> Void)?
    var onViewportChanged: ((MobileViewport) -> Void)?

    var gameViewport: MobileViewport {
        didSet {
            setNeedsDisplay()
        }
    }

    private var router = MobileTouchRouter()
    private var activeTouchID: Int?
    private var automaticallyFitsViewport: Bool
    private var bitmap: CGImage?

    init(viewport: MobileViewport, automaticallyFitsViewport: Bool = true) {
        gameViewport = viewport
        self.automaticallyFitsViewport = automaticallyFitsViewport
        super.init(frame: .zero)
        backgroundColor = .black
        isOpaque = true
        contentMode = .redraw
        isMultipleTouchEnabled = true

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)

        isAccessibilityElement = true
        accessibilityLabel = "Game playfield"
        accessibilityHint = "Tap a lemming to assign the selected skill. Drag to pan. Pinch to zoom."
        accessibilityTraits = .allowsDirectInteraction
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func update(frame: MobilePixelFrame) throws {
        guard let image = MobileBitmapRenderer.image(frame) else { throw MobileSessionError.frameUnavailable }
        bitmap = image
        setNeedsDisplay()
    }

    func purgeBitmap() {
        bitmap = nil
        setNeedsDisplay()
    }

    func stopAutomaticFitting() {
        automaticallyFitsViewport = false
    }

    func cancelInteraction() {
        activeTouchID = nil
        onTouchEffects?(router.cancel())
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), let bitmap else { return }
        MobileBitmapRenderer.draw(bitmap, viewport: gameViewport, in: context)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 1, bounds.height > 1 else { return }
        let size = MobileSize(width: bounds.width, height: bounds.height)
        if automaticallyFitsViewport {
            gameViewport.fitGameplay(in: size)
            automaticallyFitsViewport = false
        } else {
            gameViewport.resize(size)
        }
        setNeedsDisplay()
        onViewportChanged?(gameViewport)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouchID == nil, let touch = touches.first else { return }
        let initial = touch.location(in: self)
        guard !blockedInputFrames.contains(where: { $0.contains(initial) }) else { return }
        let id = ObjectIdentifier(touch).hashValue
        activeTouchID = id
        let point = touch.location(in: self)
        onTouchEffects?(router.began(
            id: id,
            at: MobilePoint(x: point.x, y: point.y),
            time: touch.timestamp
        ))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let id = activeTouchID,
              let touch = touches.first(where: { ObjectIdentifier($0).hashValue == id }) else { return }
        let point = touch.location(in: self)
        onTouchEffects?(router.moved(id: id, to: MobilePoint(x: point.x, y: point.y)))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let id = activeTouchID,
              let touch = touches.first(where: { ObjectIdentifier($0).hashValue == id }) else { return }
        activeTouchID = nil
        let point = touch.location(in: self)
        guard !blockedInputFrames.contains(where: { $0.contains(point) }) else {
            onTouchEffects?(router.cancel())
            return
        }
        onTouchEffects?(router.ended(
            id: id,
            at: MobilePoint(x: point.x, y: point.y),
            time: touch.timestamp
        ))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouchID = nil
        onTouchEffects?(router.cancel())
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        if recognizer.state == .began {
            automaticallyFitsViewport = false
            activeTouchID = nil
            onTouchEffects?(router.cancel())
        }
        guard recognizer.state == .began || recognizer.state == .changed else { return }
        let anchor = recognizer.location(in: self)
        gameViewport.magnify(
            by: recognizer.scale,
            around: MobilePoint(x: anchor.x, y: anchor.y)
        )
        recognizer.scale = 1
        onViewportChanged?(gameViewport)
        setNeedsDisplay()
    }
}
#endif
