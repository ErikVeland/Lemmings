#if os(iOS) || os(tvOS)
import LemmingsAudio
import LemmingsGameArt
import NxlvKit
import LemmingsMobileCore
import UIKit

@MainActor final class MobilePlayfieldView: UIView, UIGestureRecognizerDelegate {
    var onHover: ((MobilePoint?) -> Void)?
    var blockedInputFrames: [CGRect] = []
    var onTouchEffects: (([MobileTouchEffect]) -> Void)?
    var onViewportChanged: ((MobileViewport) -> Void)?
    var deferFrameUpdates = false

    var gameViewport: MobileViewport {
        didSet {
            setNeedsDisplay()
            if !deferFrameUpdates { updateTube() }
            if gameViewport != oldValue { onViewportChanged?(gameViewport) }
        }
    }

    private var router = MobileTouchRouter()
    private var activeTouchID: ObjectIdentifier?
    private var trackedTouchIDs = Set<ObjectIdentifier>()
    private var ignoresTouchSequenceUntilLift = false
    private var pinchGestureActive = false
    var onDJShuffle: (() -> Bool)?
    private var rawHoverPoint: CGPoint?
    private(set) var touchInput: MobileTargetInput = .touch
    var hasActiveTouch: Bool { activeTouchID != nil }
    var hoverInputPoint: MobilePoint? {
        guard let raw = rawHoverPoint, acceptsInput(at: raw) else { return nil }
        let point = inputPoint(raw)
        return MobilePoint(x: point.x, y: point.y)
    }
    private var automaticallyFitsViewport: Bool
    private let initialCameraFocus: MobilePoint?
    private var bitmap: CGImage?
    private var tubeViewport: MobileViewport?
    private let tubeSurface = MobileBitmapSurface()
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
    var cursorSkillName = ""
    var cursorUnlimited = false
    var cursorRemaining: Int?
    var selectionSprite: MobileSpriteHighlight?
    var selectionOpacity: CGFloat = 1
    var assignmentSprite: MobileSpriteHighlight?
    var assignmentProgress: Double?
    var renderScale = 1.0
    var explosions: [MobileExplosion] = []
    var bombCountdowns: [MobileBombCountdown] = []
    private let bombCountdownView = MobileBombCountdownView()
    private var explosionBirths: [Int: (tick: Int, expires: Double)] = [:]
    private let decoration = MobilePlayfieldDecoration()
    private let failureMood = FailureMoodTransition()
    #if os(iOS)
    private let completionGlow = RescueCelebrationTransition()
    #endif
    func setRescueFeedback(saved: Int, required: Int, total: Int, isComplete: Bool, didWin: Bool) {
        #if os(iOS)
        completionGlow.set(active: RescueCelebration.isSecured(saved: saved, required: required, isComplete: isComplete, didWin: didWin),
            brief: RescueCelebration.requiresAll(required: required, total: total))
        #endif
    }
    var failed = false { didSet { failureMood.set(active: failed, animated: !motionReduced) } }
    private var motionReduced: Bool { displaySettings.reduceMotion || UIAccessibility.isReduceMotionEnabled }
    var displaySettings = MobileSettings.current(from: .standard).classic { didSet { updateTube() } }

    init(viewport: MobileViewport, automaticallyFitsViewport: Bool = true, initialCameraFocus: MobilePoint? = nil) {
        gameViewport = viewport
        self.automaticallyFitsViewport = automaticallyFitsViewport
        self.initialCameraFocus = initialCameraFocus
        super.init(frame: .zero)
        backgroundColor = .black
        isOpaque = true
        contentMode = .redraw
        #if os(iOS)
        isMultipleTouchEnabled = true
        let shuffle = UITapGestureRecognizer(target: self, action: #selector(shuffleTapped(_:)))
        shuffle.numberOfTouchesRequired = 2
        shuffle.delegate = self
        addGestureRecognizer(shuffle)
        accessibilityCustomActions = [UIAccessibilityCustomAction(name: L10n.text("DJ shuffle")) { [weak self] _ in
            self?.onDJShuffle?() ?? false
        }]
        #endif
        if let tube { addSubview(tube) }
        addSubview(bombCountdownView)
        decoration.isUserInteractionEnabled = false
        decoration.accessibilityElementsHidden = true
        decoration.isOpaque = false
        decoration.backgroundColor = .clear
        addSubview(decoration)
        failureMood.onChange = { [weak self] value in self?.decoration.failureAmount = value }
        #if os(iOS)
        completionGlow.onChange = { [weak self] value in
            guard let self else { return }
            self.decoration.rescueAmount = value
        }
        #endif

        #if os(iOS)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)
        let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        hover.delegate = self
        addGestureRecognizer(hover)
        let scroll = UIPanGestureRecognizer(target: self, action: #selector(handleScroll(_:)))
        scroll.allowedScrollTypesMask = .all
        scroll.allowedTouchTypes = []
        scroll.cancelsTouchesInView = false
        scroll.delegate = self
        addGestureRecognizer(scroll)
        addInteraction(UIPointerInteraction(delegate: self))
        #endif

        isAccessibilityElement = true
        accessibilityLabel = L10n.text("Game playfield")
        accessibilityHint = L10n.text("Tap a lemming to assign the selected skill. Drag a finger to pan. Pinch to zoom.")
        accessibilityTraits = .allowsDirectInteraction
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    #if os(iOS)
    @objc private func shuffleTapped(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, !UIAccessibility.isVoiceOverRunning else { return }
        cancelInteraction()
        _ = onDJShuffle?()
    }
    #endif

    #if os(iOS)
    @objc private func handleHover(_ gesture: UIHoverGestureRecognizer) {
        switch gesture.state {
        case .began, .changed: rawHoverPoint = gesture.location(in: self)
        case .ended, .cancelled, .failed: rawHoverPoint = nil
        default: return
        }
        if !hasActiveTouch { onHover?(hoverInputPoint) }
    }

    #endif
    private func acceptsInput(at point: CGPoint) -> Bool {
        bounds.contains(point) && !blockedInputFrames.contains(where: { $0.contains(point) })
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        #if os(iOS)
        gestureRecognizer is UIHoverGestureRecognizer || other is UIHoverGestureRecognizer
        #else
        false
        #endif
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        #if os(iOS)
        if let tap = gestureRecognizer as? UITapGestureRecognizer, tap.numberOfTouchesRequired == 2,
           UIAccessibility.isVoiceOverRunning { return false }
        #endif
        return acceptsInput(at: gestureRecognizer.location(in: self))
    }

    @objc private func handleScroll(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .began || gesture.state == .changed else { return }
        let delta = gesture.translation(in: self)
        gesture.setTranslation(.zero, in: self)
        // The pointer stays at its screen position as the camera moves beneath it.
        if acceptsInput(at: gesture.location(in: self)) {
            rawHoverPoint = gesture.location(in: self)
        }
        onTouchEffects?([.pan(MobilePoint(x: delta.x, y: delta.y))])
    }
    #if os(iOS)
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        let path = UIBezierPath()
        for (x, y, dx, dy) in [(-10.0, -10.0, 1.0, 1.0), (10, -10, -1, 1), (-10, 10, 1, -1), (10, 10, -1, -1)] {
            path.move(to: CGPoint(x: x + dx * 5, y: y)); path.addLine(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x, y: y + dy * 5))
        }
        return UIPointerStyle(shape: .path(path))
    }

    #endif
    func advanceVisualEffects() {
        let now = ProcessInfo.processInfo.systemUptime
        #if os(iOS)
        completionGlow.advance(at: now)
        #endif
        if explosionBirths.values.contains(where: { $0.expires > 0 && $0.expires <= now }) {
            for (id, value) in explosionBirths where value.expires > 0 && value.expires <= now { explosionBirths[id] = (value.tick, 0) }
            updateTube(); setNeedsDisplay()
        }
        guard enhancedEffects else { releaseHDR(); return }
        let content = gameViewport.contentFrame
        hdr?.advance(at: now, multiplier: speedMultiplier, enabled: speedEffectsActive && !motionReduced && !MobileDevicePerformance.constrained,
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
        if active && multiplier > 1.01 && !motionReduced && enhancedEffects && !MobileDevicePerformance.constrained { prepareHDR() }
    }
    private func prepareHDR() {
        guard hdr == nil, !attemptedHDR, enhancedEffects else { return }
        attemptedHDR = true
        guard let view = MobileHDRView(effects: true) else { return }
        view.frame = bounds
        // The decoration and input stay above the light surface.
        insertSubview(view, belowSubview: bombCountdownView)
        hdr = view
    }
    func suspendVisualEffects() { hdr?.clear(); speedEffectsActive = false }
    func resetTransientEffects() { hdr?.clear(); explosionBirths.removeAll() }
    func releaseEffectResources() {
        releaseHDR()
        tube?.releaseEffectResources()
    }
    private func releaseHDR() {
        hdr?.clear(); hdr?.removeFromSuperview(); hdr = nil; attemptedHDR = false
    }
    func redrawSelection() {
        if let tube, !tube.isHidden, let tubeViewport {
            tube.selection = selectionEffect(viewport: tubeViewport)
            tube.setNeedsDisplay()
        } else { setNeedsDisplay() }
    }

    func update(frame: MobilePixelFrame) throws {
        guard let image = MobileBitmapRenderer.image(frame) else { throw MobileSessionError.frameUnavailable }
        bitmap = image
        #if os(iOS)
        let now = ProcessInfo.processInfo.systemUptime
        let liveIDs = Set(explosions.map(\.id))
        explosionBirths = explosionBirths.filter { liveIDs.contains($0.key) }
        if !displaySettings.hdEffectsEnabled || displaySettings.reduceFlashes { explosionBirths.removeAll(); hdr?.clear() }
        else {
            var fresh: [CGRect] = []
            for explosion in explosions where (0..<2).contains(explosion.phase) && explosionBirths[explosion.id]?.tick != explosion.birthTick {
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
        #endif
        updateTube()
        setNeedsDisplay()
    }

    func purgeBitmap() {
        hdr?.clear(); explosionBirths.removeAll()
        bitmap = nil
        updateBombCountdowns()
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
    }

    private func updateTube() {
        updateBombCountdowns()
        guard let tube else { return }
        tube.frame = bounds
        tube.isHidden = displaySettings.display == .flat || bitmap == nil
        guard !tube.isHidden, let bitmap, bounds.width > 1, bounds.height > 1 else { return }
        // Draw at native vertical resolution. The tube supplies the final display scale.
        let width = max(1, Int(ceil(bounds.width / max(0.1, gameViewport.zoom) * renderScale)))
        let height = max(1, Int(ceil(bounds.height / max(0.1, gameViewport.zoom) * renderScale)))
        guard let context = tubeSurface.prepare(width: width, height: height) else { return }
        var viewport = gameViewport
        viewport.viewSize = MobileSize(width: Double(width), height: Double(height))
        viewport.zoom = renderScale
        tubeViewport = viewport
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        MobileBitmapRenderer.draw(bitmap, viewport: viewport, in: context)
        drawObviousSelection(viewport: viewport, context: context)
        if let sprite = assignmentSprite, let progress = assignmentProgress, let image = spriteImage(sprite) {
            SpriteAssignmentPulse.draw(sprite: image, in: spriteRect(sprite, viewport: viewport), context: context,
                progress: progress, reduceMotion: motionReduced, reduceFlashes: displaySettings.reduceFlashes)
        }
        let flashes = drawExplosionCores(viewport: viewport, context: context)
        drawCursorBadge(viewport: viewport, context: context)
        tube.selection = selectionEffect(viewport: viewport)
        tube.update(context: context, settings: displaySettings, flashes: flashes)
    }

    private func updateBombCountdowns() {
        bombCountdownView.frame = bounds
        let curved = displaySettings.display != .flat && tube != nil && bitmap != nil
        bombCountdownView.update(bitmap == nil ? [] : bombCountdowns, viewport: gameViewport,
            project: curved ? { [weak self] point in self?.tube?.outputViewPoint(point) ?? point } : nil)
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
        let height = 14 * scale
        let gap = 18 * sourceFactor
        var rect = CGRect(x: point.x + gap, y: point.y + gap, width: height, height: height)
        if size != .none {
            rect = SkillPointerBadge.draw(icon: cursorIcon, name: cursorSkillName,
                count: cursorUnlimited ? "*" : cursorRemaining.map(String.init),
                at: CGPoint(x: point.x, y: point.y),
                within: CGRect(x: 0, y: 0, width: viewport.viewSize.width, height: viewport.viewSize.height),
                scale: scale, context: context)
        }
        if displaySettings.showReticleCount, let cursorCount {
            let countWidth = Double(String(cursorCount).count * 6) * scale
            GamePixelTypography.draw(String(cursorCount), in: CGRect(x: max(0, point.x - gap - countWidth), y: rect.minY, width: countWidth, height: height),
                context: context, typography: nil, maximumScale: scale, bitmapOnly: true)
        }
    }

    private func drawExplosionCores(viewport: MobileViewport, context: CGContext) -> [ExplosionGlow.Flash] {
        context.saveGState()
        context.clip(to: CGRect(x: viewport.contentFrame.x, y: viewport.contentFrame.y,
            width: viewport.contentFrame.width, height: viewport.contentFrame.height))
        defer { context.restoreGState() }
        let pixel = CGSize(width: viewport.zoom * viewport.pixelAspect, height: viewport.zoom)
        for explosion in explosions {
            let origin = explosion.sprayOrigin
            let point = viewport.viewPoint(fromLevel: origin)
            let burst = PixelExplosion(id: explosion.id, birthTick: explosion.birthTick,
                x: Int(origin.x), y: Int(origin.y))
            ExplosionGlow.drawSpray(burst, at: explosion.birthTick + explosion.phase,
                origin: CGPoint(x: point.x, y: point.y), pixel: pixel, context: context)
        }
        #if os(tvOS)
        return []
        #else
        guard displaySettings.hdEffectsEnabled, !displaySettings.reduceFlashes else { explosionBirths.removeAll(); return [] }
        let now = ProcessInfo.processInfo.systemUptime
        var flashes: [ExplosionGlow.Flash] = []
        for explosion in explosions where (0..<2).contains(explosion.phase) {
            let sprite = explosion.rect
            let point = viewport.viewPoint(fromLevel: .init(x: sprite.x + sprite.width / 2, y: sprite.y + sprite.height / 2))
            let pixel = max(1, floor(viewport.zoom))
            if explosionBirths[explosion.id]?.tick != explosion.birthTick {
                explosionBirths[explosion.id] = (explosion.birthTick, now + 0.14)
            }
            guard (explosionBirths[explosion.id]?.expires ?? 0) > now else { continue }
            ExplosionGlow.drawCore(at: CGPoint(x: point.x, y: point.y), pixel: CGSize(width: pixel * viewport.pixelAspect, height: pixel), phase: explosion.phase, context: context)
            let x = floor(point.x / pixel) * pixel, y = floor(point.y / pixel) * pixel
            let strength: Float = explosion.phase == 0 ? 1 : 0.5
            flashes.append(.init(rect: CGRect(x: x - 3 * pixel, y: y - pixel, width: 6 * pixel, height: 2 * pixel), strength: strength))
            flashes.append(.init(rect: CGRect(x: x - pixel, y: y - 3 * pixel, width: 2 * pixel, height: 6 * pixel), strength: strength))
        }
        return flashes
        #endif
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

    func controllerInputPoint(_ point: CGPoint) -> CGPoint { inputPoint(point) }
    func controllerOutputPoint(_ point: CGPoint) -> CGPoint {
        tube?.isHidden == false ? (tube?.outputViewPoint(point) ?? point) : point
    }

    private func inputPoint(_ point: CGPoint) -> CGPoint {
        tube?.isHidden == false ? (tube?.sourceViewPoint(point) ?? point) : point
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        trackedTouchIDs.formUnion(touches.map(ObjectIdentifier.init))
        guard !ignoresTouchSequenceUntilLift else { return }
        guard trackedTouchIDs.count == 1, activeTouchID == nil, let touch = touches.first else {
            ignoresTouchSequenceUntilLift = true
            activeTouchID = nil
            let effects = router.cancelForMultiTouch()
            if !effects.isEmpty { onTouchEffects?(effects) }
            return
        }
        let initial = touch.location(in: self)
        guard acceptsInput(at: initial) else { return }
        let touchID = ObjectIdentifier(touch)
        let id = touchID.hashValue
        activeTouchID = touchID
        touchInput = touch.type == .direct ? .touch : .precision
        let point = inputPoint(touch.location(in: self))
        onTouchEffects?(router.began(
            id: id,
            at: MobilePoint(x: point.x, y: point.y),
            time: touch.timestamp,
            allowsPanning: touch.type != .pencil
        ))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touchID = activeTouchID,
              let touch = touches.first(where: { ObjectIdentifier($0) == touchID }) else { return }
        let point = inputPoint(touch.location(in: self))
        onTouchEffects?(router.moved(id: touchID.hashValue, to: MobilePoint(x: point.x, y: point.y)))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        trackedTouchIDs.subtract(touches.map(ObjectIdentifier.init))
        if ignoresTouchSequenceUntilLift {
            resetTouchSequenceIfNeeded()
            return
        }
        guard let touchID = activeTouchID,
              let touch = touches.first(where: { ObjectIdentifier($0) == touchID }) else { return }
        activeTouchID = nil
        let point = inputPoint(touch.location(in: self))
        guard acceptsInput(at: touch.location(in: self)) else {
            onTouchEffects?(router.cancel())
            return
        }
        onTouchEffects?(router.ended(
            id: touchID.hashValue,
            at: MobilePoint(x: point.x, y: point.y),
            time: touch.timestamp
        ))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        trackedTouchIDs.subtract(touches.map(ObjectIdentifier.init))
        if ignoresTouchSequenceUntilLift {
            resetTouchSequenceIfNeeded()
            return
        }
        guard let activeTouchID,
              touches.contains(where: { ObjectIdentifier($0) == activeTouchID }) else { return }
        self.activeTouchID = nil
        onTouchEffects?(router.cancel())
    }

    private func resetTouchSequenceIfNeeded() {
        guard trackedTouchIDs.isEmpty, !pinchGestureActive else { return }
        ignoresTouchSequenceUntilLift = false
        router.resetAfterAllTouchesEnded()
    }

    #if os(iOS)
    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        if recognizer.state == .began {
            pinchGestureActive = true
            automaticallyFitsViewport = false
            ignoresTouchSequenceUntilLift = true
            activeTouchID = nil
            let effects = router.cancelForMultiTouch()
            if !effects.isEmpty { onTouchEffects?(effects) }
        }
        if recognizer.state == .began || recognizer.state == .changed {
            let anchor = inputPoint(recognizer.location(in: self))
            gameViewport.magnify(
                by: recognizer.scale,
                around: MobilePoint(x: anchor.x, y: anchor.y)
            )
            recognizer.scale = 1
            setNeedsDisplay()
        } else if recognizer.state == .ended || recognizer.state == .cancelled || recognizer.state == .failed {
            pinchGestureActive = false
            resetTouchSequenceIfNeeded()
        }
    }
    #endif
}
#if os(iOS)
extension MobilePlayfieldView: UIPointerInteractionDelegate {}
#endif
@MainActor private final class MobilePlayfieldDecoration: UIView {
    var failureAmount: CGFloat = 0 { didSet { setNeedsDisplay() } }
    var rescueAmount: CGFloat = 0 { didSet { setNeedsDisplay() } }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        #if os(iOS)
        RescueCelebration.draw(in: bounds, amount: rescueAmount, context: context)
        #endif
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
