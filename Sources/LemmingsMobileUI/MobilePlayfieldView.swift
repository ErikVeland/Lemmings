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
    private let initialCameraFocus: MobilePoint?
    private var bitmap: CGImage?
    private var tubeViewport: MobileViewport?
    private let tube = MobileCRTView(tubeDevice: true)
    private var hdr: MobileHDRView?
    private var attemptedHDR = false
    private var speedMultiplier = 1.0
    private var speedEffectsActive = false
    private var sprites: [String: CGImage] = [:]
    var selectionPoint: MobilePoint?
    var cursorPoint: MobilePoint?
    var cursorIcon: CGImage?
    var cursorCount: Int?
    var cursorRemaining: Int?
    var selectionSprite: MobileSpriteHighlight?
    var selectionOpacity: CGFloat = 1
    var rescueSprites: [MobileSpriteHighlight] = []
    var assignmentSprite: MobileSpriteHighlight?
    var assignmentProgress: Double?
    var renderScale = 1.0
    var explosions: [MobileExplosion] = []
    private var explosionBirths: [Int: (tick: Int, expires: Double)] = [:]
    private let decoration = MobilePlayfieldDecoration()
    private let failureMood = FailureMoodTransition()
    private let completionGlow = RescueCelebrationTransition()
    private let backgroundGlow = RescueBackgroundGlow()
    func setRescueFeedback(saved: Int, required: Int, total: Int, isComplete: Bool, didWin: Bool) {
        completionGlow.set(active: RescueCelebration.isSecured(saved: saved, required: required, isComplete: isComplete, didWin: didWin),
            brief: RescueCelebration.requiresAll(required: required, total: total),
            animated: !motionReduced && !displaySettings.reduceFlashes)
    }
    var failed = false { didSet { failureMood.set(active: failed, animated: !motionReduced) } }
    private var motionReduced: Bool { displaySettings.reduceMotion || UIAccessibility.isReduceMotionEnabled }
    var displaySettings = MobileSettings.load(from: .standard).classic { didSet { updateTube() } }

    init(viewport: MobileViewport, automaticallyFitsViewport: Bool = true, initialCameraFocus: MobilePoint? = nil) {
        gameViewport = viewport
        self.automaticallyFitsViewport = automaticallyFitsViewport
        self.initialCameraFocus = initialCameraFocus
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
        completionGlow.onChange = { [weak self] value in
            guard let self else { return }
            self.decoration.rescueAmount = value
            self.setNeedsDisplay(); self.updateTube()
        }

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
        let raw = gesture.location(in: self)
        let point = inputPoint(raw)
        guard !blockedInputFrames.contains(where: { $0.contains(raw) }) else { onHover?(nil); return }
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

    func advanceVisualEffects() {
        let now = ProcessInfo.processInfo.systemUptime
        if explosionBirths.values.contains(where: { $0.expires > 0 && $0.expires <= now }) {
            for (id, value) in explosionBirths where value.expires > 0 && value.expires <= now { explosionBirths[id] = (value.tick, 0) }
            updateTube(); setNeedsDisplay()
        }
        guard enhancedEffects else { hdr?.clear(); return }
        let content = gameViewport.contentFrame
        hdr?.advance(at: now, multiplier: speedMultiplier, enabled: speedEffectsActive && !motionReduced,
            field: CGRect(x: content.x, y: content.y, width: content.width, height: content.height), project: { [weak self] centre in
                guard let self else { return .zero }
                let point = self.gameViewport.viewPoint(fromLevel: .init(x: Double(centre.x), y: Double(centre.y)))
                let viewPoint = CGPoint(x: point.x, y: point.y)
                return self.tube?.isHidden == false ? self.tube?.outputViewPoint(viewPoint) ?? viewPoint : viewPoint
            })
    }

    private var enhancedEffects: Bool {
        MobileDevicePerformance.enhancedEffectsAllowed && displaySettings.hdEffectsEnabled && !displaySettings.reduceFlashes
    }
    func setSpeedEffects(multiplier: Double, active: Bool) {
        speedMultiplier = multiplier; speedEffectsActive = active
        if active && multiplier > 1.01 && !motionReduced && enhancedEffects { prepareHDR() }
    }
    private func prepareHDR() {
        guard hdr == nil, !attemptedHDR, enhancedEffects else { return }
        attemptedHDR = true
        guard let view = MobileHDRView(effects: true) else { return }
        view.frame = bounds
        // The decoration and input stay above the light surface.
        insertSubview(view, belowSubview: decoration)
        hdr = view
    }
    func suspendVisualEffects() { hdr?.clear(); speedEffectsActive = false }
    func resetTransientEffects() { hdr?.clear(); explosionBirths.removeAll() }
    func redrawSelection() {
        if let tube, !tube.isHidden, let tubeViewport {
            tube.selection = selectionEffect(viewport: tubeViewport)
            tube.setNeedsDisplay()
        } else { setNeedsDisplay() }
    }

    func update(frame: MobilePixelFrame) throws {
        guard let image = MobileBitmapRenderer.image(frame) else { throw MobileSessionError.frameUnavailable }
        bitmap = image
        let now = ProcessInfo.processInfo.systemUptime
        if !displaySettings.hdEffectsEnabled || displaySettings.reduceFlashes { explosionBirths.removeAll(); hdr?.clear() }
        else {
            var fresh: [CGRect] = []
            for explosion in explosions where explosionBirths[explosion.id]?.tick != explosion.birthTick {
                explosionBirths[explosion.id] = (explosion.birthTick, now + 0.14)
                let rect = explosion.rect
                guard gameViewport.visibleLevelRect.contains(.init(x: rect.x + rect.width / 2, y: rect.y + rect.height / 2)) else { continue }
                fresh.append(CGRect(x: rect.x + rect.width / 2 - 3, y: rect.y + rect.height / 2 - 3, width: 6, height: 6))
            }
            if !fresh.isEmpty, enhancedEffects {
                prepareHDR()
                hdr?.trigger(rects: fresh, cinematic: displaySettings.cinematicExplosionsEnabled, at: now)
            }
        }
        updateTube()
        setNeedsDisplay()
    }

    func purgeBitmap() {
        hdr?.clear(); explosionBirths.removeAll()
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
        let drawStarted = ProcessInfo.processInfo.systemUptime
        defer { MobileDevicePerformance.recordCPU(ProcessInfo.processInfo.systemUptime - drawStarted, source: "bitmap") }
        MobileBitmapRenderer.draw(bitmap, viewport: gameViewport, in: context)
        drawRescueBackground(bitmap, viewport: gameViewport, context: context)
        for effect in rescueEffects(viewport: gameViewport) { LemmingSelectionRenderer.draw(effect, in: context) }
        drawObviousSelection(viewport: gameViewport, context: context)
        if let effect = selectionEffect(viewport: gameViewport) { LemmingSelectionRenderer.draw(effect, in: context) }
        if let sprite = assignmentSprite, let progress = assignmentProgress, let image = spriteImage(sprite) {
            SpriteAssignmentPulse.draw(sprite: image, in: spriteRect(sprite, viewport: gameViewport), context: context,
                progress: progress, reduceMotion: motionReduced, reduceFlashes: displaySettings.reduceFlashes)
        }
        _ = drawExplosionCores(viewport: gameViewport, context: context)
        drawCursorBadge(viewport: gameViewport, context: context)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        decoration.frame = bounds
        hdr?.frame = bounds
        guard bounds.width > 1, bounds.height > 1 else { return }
        let size = MobileSize(width: bounds.width, height: bounds.height)
        guard size != gameViewport.viewSize else { return }
        if automaticallyFitsViewport {
            gameViewport.fitGameplay(in: size, centring: initialCameraFocus)
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
        tubeViewport = viewport
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        MobileBitmapRenderer.draw(bitmap, viewport: viewport, in: context)
        drawRescueBackground(bitmap, viewport: viewport, context: context)
        drawObviousSelection(viewport: viewport, context: context)
        if let sprite = assignmentSprite, let progress = assignmentProgress, let image = spriteImage(sprite) {
            SpriteAssignmentPulse.draw(sprite: image, in: spriteRect(sprite, viewport: viewport), context: context,
                progress: progress, reduceMotion: motionReduced, reduceFlashes: displaySettings.reduceFlashes)
        }
        let flashes = drawExplosionCores(viewport: viewport, context: context)
        drawCursorBadge(viewport: viewport, context: context)
        guard let image = context.makeImage() else { return }
        tube.selection = selectionEffect(viewport: viewport)
        tube.rescueAuras = rescueEffects(viewport: viewport)
        tube.update(image: image, settings: displaySettings, flashMask: ExplosionGlow.textureMask(width: width, height: height, flashes: flashes))
    }

    private func drawObviousSelection(viewport: MobileViewport, context: CGContext) {
        guard displaySettings.lemmingSelectionStyle == .obvious, let selectionPoint else { return }
        let point = viewport.viewPoint(fromLevel: selectionPoint)
        LemmingSelectionRenderer.drawObvious(at: CGPoint(x: point.x, y: point.y), scale: viewport.zoom,
            animated: !motionReduced && !displaySettings.reduceFlashes, context: context)
    }

    private func drawCursorBadge(viewport: MobileViewport, context: CGContext) {
        guard let cursorPoint else { return }
        let point = viewport.viewPoint(fromLevel: cursorPoint)
        let sourceFactor = viewport.zoom / max(0.1, gameViewport.zoom)
        let size = displaySettings.skillCursorIconSize
        let scale = (size == .two ? 2.0 : 1.0) * sourceFactor
        let height = 7 * scale
        let gap = 18 * sourceFactor
        let maxX = viewport.viewSize.width, maxY = viewport.viewSize.height
        let width = cursorIcon.map { max(1, floor(height * Double($0.width) / Double($0.height))) } ?? height
        let rect = CGRect(x: min(max(0, point.x + gap), max(0, maxX - width)),
            y: min(max(0, point.y + gap), max(0, maxY - height)), width: width, height: height)
        if size != .none {
            if cursorRemaining == 0 {
                GamePixelTypography.draw("X", in: rect, context: context, typography: nil, palette: .warning, maximumScale: scale, bitmapOnly: true)
            } else if let cursorIcon { GameStoneArt.drawImage(cursorIcon, in: rect, context: context) }
        }
        if displaySettings.showReticleCount, let cursorCount {
            let countWidth = Double(String(cursorCount).count * 6) * scale
            GamePixelTypography.draw(String(cursorCount), in: CGRect(x: max(0, point.x - gap - countWidth), y: rect.minY, width: countWidth, height: height),
                context: context, typography: nil, maximumScale: scale, bitmapOnly: true)
        }
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
        var effect = LemmingSelectionEffect(sprite: image, rect: spriteRect(sprite, viewport: viewport),
            clipRect: CGRect(x: content.x, y: content.y, width: content.width, height: content.height),
            bloom: true, time: motionReduced || displaySettings.reduceFlashes ? nil : sprite.time)
        effect.opacity = selectionOpacity
        return effect
    }

    private func rescueEffects(viewport: MobileViewport) -> [LemmingSelectionEffect] {
        MobileRescueArt.effects(sprites: rescueSprites, viewport: viewport, amount: completionGlow.amount,
            enabled: displaySettings.hdEffectsEnabled && !displaySettings.reduceFlashes, image: spriteImage)
    }

    private func drawRescueBackground(_ image: CGImage, viewport: MobileViewport, context: CGContext) {
        guard completionGlow.amount > 0 else { return }
        let content = viewport.contentFrame
        let sx = viewport.zoom * viewport.pixelAspect, sy = viewport.zoom
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: CGRect(x: content.x, y: content.y, width: content.width, height: content.height))
        backgroundGlow.draw(image, in: CGRect(x: content.x - viewport.origin.x * sx,
            y: content.y - viewport.origin.y * sy, width: viewport.levelSize.width * sx,
            height: viewport.levelSize.height * sy), amount: completionGlow.amount, context: context, slot: "scene")
    }

    private func inputPoint(_ point: CGPoint) -> CGPoint {
        tube?.isHidden == false ? (tube?.sourceViewPoint(point) ?? point) : point
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouchID == nil, let touch = touches.first else { return }
        let initial = touch.location(in: self)
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
        guard !blockedInputFrames.contains(where: { $0.contains(touch.location(in: self)) }) else {
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
