#if os(iOS)
import LemmingsAudio
import LemmingsGameArt
import NxlvKit
import LemmingsMobileCore
import UIKit

@MainActor final class MobilePlayfieldView: UIView, UIGestureRecognizerDelegate, UIPointerInteractionDelegate {
    var onHover: ((MobilePoint?) -> Void)?
    var blockedInputFrames: [CGRect] = []
    var onTouchEffects: (([MobileTouchEffect]) -> Void)?
    var onViewportChanged: ((MobileViewport) -> Void)?

    var gameViewport: MobileViewport {
        didSet {
            setNeedsDisplay()
            updateTube()
        }
    }

    private var router = MobileTouchRouter()
    private var activeTouchID: Int?
    private var automaticallyFitsViewport: Bool
    private var bitmap: CGImage?
    private let tube = MobileCRTView(tubeDevice: true)
    private var sprites: [String: CGImage] = [:]
    var selectionSprite: MobileSpriteHighlight?
    var assignmentSprite: MobileSpriteHighlight?
    var assignmentProgress: Double?
    var renderScale = 1.0
    var explosions: [MobileExplosion] = []
    private var explosionBirths: [Int: (tick: Int, expires: Double)] = [:]
    private let decoration = MobilePlayfieldDecoration()
    private let failureMood = FailureMoodTransition()
    private let completionGlow = RescueCelebrationTransition()
    func setRescueFeedback(saved: Int, required: Int, total: Int, isComplete: Bool, didWin: Bool) {
        completionGlow.set(active: RescueCelebration.isSecured(saved: saved, required: required, isComplete: isComplete, didWin: didWin),
            brief: RescueCelebration.requiresAll(required: required, total: total),
            animated: !displaySettings.reduceMotion && !displaySettings.reduceFlashes)
    }
    var failed = false { didSet { failureMood.set(active: failed, animated: !displaySettings.reduceMotion) } }
    var displaySettings = MobileSettings.load(from: .standard).classic { didSet { updateTube() } }

    init(viewport: MobileViewport, automaticallyFitsViewport: Bool = true) {
        gameViewport = viewport
        self.automaticallyFitsViewport = automaticallyFitsViewport
        super.init(frame: .zero)
        backgroundColor = .black
        isOpaque = true
        contentMode = .redraw
        isMultipleTouchEnabled = true
        if let tube { addSubview(tube) }
        decoration.isUserInteractionEnabled = false
        decoration.accessibilityElementsHidden = true
        decoration.isOpaque = false
        decoration.backgroundColor = .clear
        addSubview(decoration)
        failureMood.onChange = { [weak self] value in self?.decoration.failureAmount = value }
        completionGlow.onChange = { [weak self] value in self?.decoration.rescueAmount = value }

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)
        addGestureRecognizer(UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:))))
        addInteraction(UIPointerInteraction(delegate: self))

        isAccessibilityElement = true
        accessibilityLabel = "Game playfield"
        accessibilityHint = "Tap a lemming to assign the selected skill. Drag to pan. Pinch to zoom."
        accessibilityTraits = .allowsDirectInteraction
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    @objc private func handleHover(_ gesture: UIHoverGestureRecognizer) {
        if gesture.state == .ended || gesture.state == .cancelled { onHover?(nil); return }
        let point = inputPoint(gesture.location(in: self))
        guard !blockedInputFrames.contains(where: { $0.contains(point) }) else { onHover?(nil); return }
        onHover?(MobilePoint(x: point.x, y: point.y))
    }
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        let path = UIBezierPath()
        for (x, y, dx, dy) in [(-10.0, -10.0, 1.0, 1.0), (10, -10, -1, 1), (-10, 10, 1, -1), (10, 10, -1, -1)] {
            path.move(to: CGPoint(x: x + dx * 5, y: y)); path.addLine(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x, y: y + dy * 5))
        }
        return UIPointerStyle(shape: .path(path))
    }

    func update(frame: MobilePixelFrame) throws {
        guard let image = MobileBitmapRenderer.image(frame) else { throw MobileSessionError.frameUnavailable }
        bitmap = image
        updateTube()
        setNeedsDisplay()
    }

    func purgeBitmap() {
        bitmap = nil
        tube?.isHidden = true
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
        guard tube?.isHidden != false, let context = UIGraphicsGetCurrentContext(), let bitmap else { return }
        MobileBitmapRenderer.draw(bitmap, viewport: gameViewport, in: context)
        if let effect = selectionEffect(viewport: gameViewport) { LemmingSelectionRenderer.draw(effect, in: context) }
        if let sprite = assignmentSprite, let progress = assignmentProgress, let image = spriteImage(sprite) {
            SpriteAssignmentPulse.draw(sprite: image, in: spriteRect(sprite, viewport: gameViewport), context: context,
                progress: progress, reduceMotion: displaySettings.reduceMotion, reduceFlashes: displaySettings.reduceFlashes)
        }
        _ = drawExplosionCores(viewport: gameViewport, context: context)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        decoration.frame = bounds
        guard bounds.width > 1, bounds.height > 1 else { return }
        let size = MobileSize(width: bounds.width, height: bounds.height)
        if automaticallyFitsViewport {
            gameViewport.fitGameplay(in: size)
            automaticallyFitsViewport = false
        } else {
            gameViewport.resize(size)
        }
        updateTube()
        setNeedsDisplay()
        onViewportChanged?(gameViewport)
    }

    private func updateTube() {
        guard let tube else { return }
        tube.frame = bounds
        tube.isHidden = displaySettings.display == .flat || bitmap == nil
        guard !tube.isHidden, let bitmap, bounds.width > 1, bounds.height > 1 else { return }
        // Draw at native vertical resolution. The tube supplies the final display scale.
        let width = max(1, Int(ceil(bounds.width / max(0.1, gameViewport.zoom) * renderScale)))
        let height = max(1, Int(ceil(bounds.height / max(0.1, gameViewport.zoom) * renderScale)))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        var viewport = gameViewport
        viewport.viewSize = MobileSize(width: Double(width), height: Double(height))
        viewport.zoom = renderScale
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        MobileBitmapRenderer.draw(bitmap, viewport: viewport, in: context)
        if let sprite = assignmentSprite, let progress = assignmentProgress, let image = spriteImage(sprite) {
            SpriteAssignmentPulse.draw(sprite: image, in: spriteRect(sprite, viewport: viewport), context: context,
                progress: progress, reduceMotion: displaySettings.reduceMotion, reduceFlashes: displaySettings.reduceFlashes)
        }
        let flashes = drawExplosionCores(viewport: viewport, context: context)
        guard let image = context.makeImage() else { return }
        tube.selection = selectionEffect(viewport: viewport)
        tube.update(image: image, settings: displaySettings, flashMask: ExplosionGlow.textureMask(width: width, height: height, flashes: flashes))
    }

    private func drawExplosionCores(viewport: MobileViewport, context: CGContext) -> [ExplosionGlow.Flash] {
        guard displaySettings.hdEffectsEnabled, !displaySettings.reduceFlashes else { explosionBirths.removeAll(); return [] }
        let now = ProcessInfo.processInfo.systemUptime
        var flashes: [ExplosionGlow.Flash] = []
        for explosion in explosions {
            let sprite = explosion.rect
            let point = viewport.viewPoint(fromLevel: .init(x: sprite.x + sprite.width / 2, y: sprite.y + sprite.height / 2))
            let pixel = max(1, floor(viewport.zoom))
            ExplosionGlow.drawCore(at: CGPoint(x: point.x, y: point.y), pixel: CGSize(width: pixel * viewport.pixelAspect, height: pixel), phase: explosion.phase, context: context)
            if explosionBirths[explosion.id]?.tick != explosion.birthTick {
                explosionBirths[explosion.id] = (explosion.birthTick, now + 0.14)
            }
            guard (explosionBirths[explosion.id]?.expires ?? 0) > now else { continue }
            let x = floor(point.x / pixel) * pixel, y = floor(point.y / pixel) * pixel
            let strength: Float = explosion.phase == 0 ? 1 : 0.5
            flashes.append(.init(rect: CGRect(x: x - 3 * pixel, y: y - pixel, width: 6 * pixel, height: 2 * pixel), strength: strength))
            flashes.append(.init(rect: CGRect(x: x - pixel, y: y - 3 * pixel, width: 2 * pixel, height: 6 * pixel), strength: strength))
        }
        return flashes
    }

    private func spriteImage(_ sprite: MobileSpriteHighlight) -> CGImage? {
        if let cached = sprites[sprite.cacheKey] { return cached }
        guard let image = MobileBitmapRenderer.image(sprite.frame) else { return nil }
        if sprites.count >= LemmingSelectionRenderer.cacheLimit { sprites.removeAll(keepingCapacity: true) }
        sprites[sprite.cacheKey] = image
        return image
    }

    private func spriteRect(_ sprite: MobileSpriteHighlight, viewport: MobileViewport) -> CGRect {
        let origin = viewport.viewPoint(fromLevel: .init(x: sprite.rect.x, y: sprite.rect.y))
        return CGRect(x: origin.x, y: origin.y, width: sprite.rect.width * viewport.zoom * viewport.pixelAspect,
                      height: sprite.rect.height * viewport.zoom)
    }

    private func selectionEffect(viewport: MobileViewport) -> LemmingSelectionEffect? {
        guard let sprite = selectionSprite, let image = spriteImage(sprite) else { return nil }
        let content = viewport.contentFrame
        return .init(sprite: image, rect: spriteRect(sprite, viewport: viewport),
            clipRect: CGRect(x: content.x, y: content.y, width: content.width, height: content.height),
            bloom: true, time: sprite.time)
    }

    private func inputPoint(_ point: CGPoint) -> CGPoint {
        tube?.isHidden == false ? (tube?.sourceViewPoint(point) ?? point) : point
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouchID == nil, let touch = touches.first else { return }
        let initial = inputPoint(touch.location(in: self))
        guard !blockedInputFrames.contains(where: { $0.contains(initial) }) else { return }
        let id = ObjectIdentifier(touch).hashValue
        activeTouchID = id
        let point = inputPoint(touch.location(in: self))
        onTouchEffects?(router.began(
            id: id,
            at: MobilePoint(x: point.x, y: point.y),
            time: touch.timestamp
        ))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let id = activeTouchID,
              let touch = touches.first(where: { ObjectIdentifier($0).hashValue == id }) else { return }
        let point = inputPoint(touch.location(in: self))
        onTouchEffects?(router.moved(id: id, to: MobilePoint(x: point.x, y: point.y)))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let id = activeTouchID,
              let touch = touches.first(where: { ObjectIdentifier($0).hashValue == id }) else { return }
        activeTouchID = nil
        let point = inputPoint(touch.location(in: self))
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
        let anchor = inputPoint(recognizer.location(in: self))
        gameViewport.magnify(
            by: recognizer.scale,
            around: MobilePoint(x: anchor.x, y: anchor.y)
        )
        recognizer.scale = 1
        onViewportChanged?(gameViewport)
        setNeedsDisplay()
    }
}
@MainActor private final class MobilePlayfieldDecoration: UIView {
    var failureAmount: CGFloat = 0 { didSet { setNeedsDisplay() } }
    var rescueAmount: CGFloat = 0 { didSet { setNeedsDisplay() } }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        RescueCelebration.draw(in: bounds, amount: rescueAmount, context: context)
        guard failureAmount > 0 else { return }
        context.setBlendMode(.color)
        context.setFillColor(CGColor(gray: 0.28, alpha: 0.72 * failureAmount))
        context.fill(bounds)
        context.setBlendMode(.normal)
        context.setFillColor(CGColor(gray: 0, alpha: 0.26 * failureAmount))
        context.fill(bounds)
    }
}
#endif
