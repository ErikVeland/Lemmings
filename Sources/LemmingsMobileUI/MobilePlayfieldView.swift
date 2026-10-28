#if os(iOS) || os(tvOS)
import LemmingsAudio
import LemmingsGameArt
import NxlvKit
import LemmingsMobileCore
import UIKit

@MainActor final class MobilePlayfieldView: UIView, UIGestureRecognizerDelegate {
    #if os(tvOS)
    override var canBecomeFirstResponder: Bool { true }
    #endif
    var onHover: ((MobilePoint?) -> Void)?
    var blockedInputFrames: [CGRect] = []
    var onTouchEffects: (([MobileTouchEffect]) -> Void)?
    var canHoldSelection: ((MobilePoint) -> Bool)?
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
    private var scrollGestureActive = false
    var onDJShuffle: (() -> Bool)?
    var onCycleGraphics: (() -> Bool)?
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
    private(set) var bitmap: CGImage?
    private var arrowGlints: ClassicMacScene.ArrowGlints?
    private var tubeViewport: MobileViewport?
    private let tubeSurface = MobileBitmapSurface()
    private let tube = MobileCRTView(tubeDevice: true)
    private var hdr: MobileHDRView?
    private var attemptedHDR = false
    private var spriteTrails = MobileSpriteTrails()
    private var speedMultiplier = 1.0
    private var speedEffectsActive = false
    private var sprites: [String: CGImage] = [:]
    var selectionPoint: MobilePoint?
    var cursorPoint: MobilePoint?
    var cursorOccupied = false
    var cursorEligible = false
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
    // Core Animation scales the engine bitmap on the GPU. CPU drawing covers only the overlays above it.
    private let bitmapClip = CALayer()
    private let bitmapLayer = CALayer()
    private var layerBitmap: CGImage?
    private let overlay = MobilePlayfieldOverlay()
    private let failureMood = FailureMoodTransition()
    private var failureAmount: CGFloat = 0
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
        let immediate: [String: any CAAction] = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "hidden": NSNull()]
        bitmapClip.actions = immediate
        bitmapClip.masksToBounds = true
        bitmapClip.isHidden = true
        bitmapLayer.actions = immediate
        bitmapLayer.magnificationFilter = .nearest
        bitmapLayer.minificationFilter = .nearest
        bitmapClip.addSublayer(bitmapLayer)
        layer.addSublayer(bitmapClip)
        overlay.drawContent = { [weak self] context in self?.drawOverlay(in: context) }
        addSubview(overlay)
        #if os(iOS)
        isMultipleTouchEnabled = true
        for direction: UISwipeGestureRecognizer.Direction in [.left, .right, .up, .down] {
            let shuffle = UISwipeGestureRecognizer(target: self, action: #selector(shuffleSwiped(_:)))
            shuffle.numberOfTouchesRequired = 2
            shuffle.direction = direction
            shuffle.delegate = self
            addGestureRecognizer(shuffle)
        }
        let graphics = UITapGestureRecognizer(target: self, action: #selector(graphicsTapped(_:)))
        graphics.numberOfTouchesRequired = 3
        graphics.delegate = self
        addGestureRecognizer(graphics)
        accessibilityCustomActions = [UIAccessibilityCustomAction(name: L10n.text("DJ shuffle")) { [weak self] _ in
            self?.onDJShuffle?() ?? false
        }, UIAccessibilityCustomAction(name: L10n.text("Graphics")) { [weak self] _ in
            self?.onCycleGraphics?() ?? false
        }]
        #endif
        if let tube { addSubview(tube) }
        addSubview(bombCountdownView)
        decoration.isUserInteractionEnabled = false
        decoration.accessibilityElementsHidden = true
        decoration.isOpaque = false
        decoration.backgroundColor = .clear
        addSubview(decoration)
        failureMood.onChange = { [weak self] value in
            guard let self else { return }
            self.failureAmount = value
            self.tube?.failureAmount = value
            self.setNeedsDisplay()
        }
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
        accessibilityIdentifier = "game.playfield"
        accessibilityLabel = L10n.text("Game playfield")
        accessibilityHint = L10n.text("Tap to assign. Hold, then slide left or right to browse lemmings. While holding, drag a second finger to pan. Lift the first finger to assign. Drag to pan. Pinch to zoom.")
        accessibilityTraits = .allowsDirectInteraction
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    #if os(iOS)
    @objc private func shuffleSwiped(_ gesture: UISwipeGestureRecognizer) {
        guard gesture.state == .ended, !UIAccessibility.isVoiceOverRunning else { return }
        cancelInteraction()
        _ = onDJShuffle?()
    }

    @objc private func graphicsTapped(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, !UIAccessibility.isVoiceOverRunning else { return }
        cancelInteraction()
        _ = onCycleGraphics?()
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
        if router.isHoldingSelection,
           gestureRecognizer is UIPinchGestureRecognizer || gestureRecognizer is UISwipeGestureRecognizer
            || gestureRecognizer is UITapGestureRecognizer { return false }
        if UIAccessibility.isVoiceOverRunning,
           gestureRecognizer is UITapGestureRecognizer || gestureRecognizer is UISwipeGestureRecognizer {
            return false
        }
        #endif
        return acceptsInput(at: gestureRecognizer.location(in: self))
    }

    @objc private func handleScroll(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began { scrollGestureActive = true }
        guard gesture.state == .began || gesture.state == .changed else {
            scrollGestureActive = false
            return
        }
        let delta = gesture.translation(in: self)
        gesture.setTranslation(.zero, in: self)
        guard scrollGestureActive, acceptsInput(at: gesture.location(in: self)) else { return }
        // The pointer stays at its screen position as the camera moves beneath it.
        rawHoverPoint = gesture.location(in: self)
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
    func captureSpriteTrails(session: any MobileGameSession) {
        let enabled = displaySettings.hdEffectsEnabled && !motionReduced && !displaySettings.reduceFlashes
            && !MobileDevicePerformance.constrained
        guard enabled else { spriteTrails.reset(); return }
        let visible = gameViewport.visibleLevelRect
        var current: [Int: MobileSpriteHighlight] = [:]
        let limit = MobileDevicePerformance.constrained ? 24 : 48
        for actor in session.spriteActorIDs {
            guard let sprite = session.spriteHighlight(for: actor),
                  sprite.rect.x + sprite.rect.width >= visible.x, sprite.rect.x <= visible.x + visible.width,
                  sprite.rect.y + sprite.rect.height >= visible.y, sprite.rect.y <= visible.y + visible.height else { continue }
            current[actor] = sprite
            if current.count >= limit { break }
        }
        spriteTrails.sample(current, tick: session.snapshot.tick, time: ProcessInfo.processInfo.systemUptime,
            fast: speedEffectsActive && speedMultiplier > 1, enabled: enabled, budget: limit * 2)
    }

    private func drawSpriteTrails(viewport: MobileViewport, context: CGContext) {
        guard !motionReduced, !displaySettings.reduceFlashes, displaySettings.hdEffectsEnabled else { return }
        let content = viewport.contentFrame, now = ProcessInfo.processInfo.systemUptime
        context.saveGState(); defer { context.restoreGState() }
        context.clip(to: CGRect(x: content.x, y: content.y, width: content.width, height: content.height))
        context.interpolationQuality = .none
        for echo in spriteTrails.echoes {
            guard let image = spriteImage(echo.sprite) else { continue }
            let rect = spriteRect(echo.sprite, viewport: viewport)
            context.saveGState()
            context.setAlpha(echo.opacity(at: now))
            context.translateBy(x: rect.minX, y: rect.maxY); context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(origin: .zero, size: rect.size))
            context.restoreGState()
        }
    }

    func advanceVisualEffects() {
        let now = ProcessInfo.processInfo.systemUptime
        if !spriteTrails.echoes.isEmpty {
            spriteTrails.expire(at: now); updateTube(); setNeedsDisplay()
        }
        let touchEffects = router.advance(at: now, horizontalRange: 0...max(0, Double(bounds.width)))
        if !touchEffects.isEmpty { onTouchEffects?(touchEffects) }
        #if os(iOS)
        completionGlow.advance(at: now)
        #endif
        if explosionBirths.values.contains(where: { $0.expires > 0 && $0.expires <= now }) {
            for (id, value) in explosionBirths where value.expires > 0 && value.expires <= now { explosionBirths[id] = (value.tick, 0) }
            updateTube(); setNeedsDisplay()
        }
        guard enhancedEffects else { releaseHDR(); return }
        let content = gameViewport.contentFrame
        let glints = displaySettings.hdEffectsEnabled && !MobileDevicePerformance.constrained ? arrowGlints : nil
        if glints != nil { prepareHDR() }
        let glintPlacement = glints.flatMap(arrowGlintRect)
        hdr?.setArrowGlints(glintPlacement == nil ? nil : glints, in: glintPlacement ?? .null,
            clip: CGRect(x: content.x, y: content.y, width: content.width, height: content.height))
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
    func suspendVisualEffects() { spriteTrails.reset(); hdr?.clear(); speedEffectsActive = false; failureMood.finish() }
    func resetTransientEffects(preservingTrails: Bool = false) {
        if !preservingTrails { spriteTrails.reset() }
        hdr?.clear(); explosionBirths.removeAll()
    }
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
        arrowGlints = frame.arrowGlints
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
        spriteTrails.reset(); hdr?.clear(); explosionBirths.removeAll()
        bitmap = nil; arrowGlints = nil
        updateBombCountdowns()
        tube?.isHidden = true
        setNeedsDisplay()
    }

    func stopAutomaticFitting() {
        automaticallyFitsViewport = false
    }

    func cancelInteraction(clearHover: Bool = false) {
        activeTouchID = nil
        if !trackedTouchIDs.isEmpty { ignoresTouchSequenceUntilLift = true }
        // Changed events from an old pose must wait for a fresh gesture begin.
        pinchGestureActive = false
        scrollGestureActive = false
        if clearHover { rawHoverPoint = nil }
        onTouchEffects?(router.cancel())
    }

    override func setNeedsDisplay() {
        super.setNeedsDisplay()
        layoutBitmap()
    }

    /// Blend the funeral mood with the actual scene, never a transparent sibling layer.
    /// Normal play keeps GPU scaling. Oversized bitmaps also use the drawing path.
    private var bitmapUsesLayer: Bool {
        failureAmount == 0 && (bitmap.map { max($0.width, $0.height) <= 8192 } ?? false)
    }

    /// The view area of the arrow glint mask on the flat bitmap layer. The curved tube has no glints.
    private func arrowGlintRect(_ glints: ClassicMacScene.ArrowGlints) -> CGRect? {
        guard tube?.isHidden != false, let bitmap, bitmapUsesLayer, bitmap.width > 0, bitmap.height > 0 else { return nil }
        let content = gameViewport.contentFrame
        let scaleX = gameViewport.zoom * gameViewport.pixelAspect, scaleY = gameViewport.zoom
        let pixelX = gameViewport.levelSize.width * scaleX / Double(bitmap.width)
        let pixelY = gameViewport.levelSize.height * scaleY / Double(bitmap.height)
        return CGRect(x: content.x - gameViewport.origin.x * scaleX + Double(glints.x) * pixelX,
            y: content.y - gameViewport.origin.y * scaleY + Double(glints.y) * pixelY,
            width: Double(glints.width) * pixelX, height: Double(glints.height) * pixelY)
    }

    /// Places the bitmap with the camera used for touch input. Fractional pan keeps its pixel alignment.
    private func layoutBitmap() {
        let content = gameViewport.contentFrame
        let flat = tube?.isHidden != false
        if flat, let bitmap, bitmapUsesLayer, content.width > 0, content.height > 0 {
            if layerBitmap !== bitmap { bitmapLayer.contents = bitmap; layerBitmap = bitmap }
            let scaleX = gameViewport.zoom * gameViewport.pixelAspect, scaleY = gameViewport.zoom
            bitmapClip.frame = CGRect(x: content.x, y: content.y, width: content.width, height: content.height)
            bitmapLayer.frame = CGRect(x: -gameViewport.origin.x * scaleX, y: -gameViewport.origin.y * scaleY,
                width: gameViewport.levelSize.width * scaleX, height: gameViewport.levelSize.height * scaleY)
            bitmapClip.isHidden = false
        } else {
            bitmapClip.isHidden = true
            bitmapLayer.contents = nil; layerBitmap = nil
        }
        // An empty overlay keeps no backing store and costs no drawing.
        let showsOverlay = flat && bitmap != nil && (!bitmapUsesLayer || hasOverlayContent)
        overlay.isHidden = !showsOverlay
        if showsOverlay { overlay.setNeedsDisplay() }
    }

    private var hasOverlayContent: Bool {
        (displaySettings.lemmingSelectionStyle == .obvious && selectionPoint != nil) || selectionSprite != nil
            || (assignmentSprite != nil && assignmentProgress != nil) || !explosions.isEmpty
            || cursorPoint != nil || failureAmount > 0 || !spriteTrails.echoes.isEmpty
    }

    private func drawOverlay(in context: CGContext) {
        guard tube?.isHidden != false, let bitmap else { return }
        let drawStarted = ProcessInfo.processInfo.systemUptime
        defer { MobileDevicePerformance.recordCPU(ProcessInfo.processInfo.systemUptime - drawStarted, source: "bitmap") }
        if !bitmapUsesLayer {
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(bounds)
            MobileBitmapRenderer.draw(bitmap, viewport: gameViewport, in: context)
        }
        drawSpriteTrails(viewport: gameViewport, context: context)
        drawObviousSelection(viewport: gameViewport, context: context)
        if let effect = selectionEffect(viewport: gameViewport) { LemmingSelectionRenderer.draw(effect, in: context) }
        if let sprite = assignmentSprite, let progress = assignmentProgress, let image = spriteImage(sprite) {
            SpriteAssignmentPulse.draw(sprite: image, in: spriteRect(sprite, viewport: gameViewport), context: context,
                progress: progress, reduceMotion: motionReduced, reduceFlashes: displaySettings.reduceFlashes)
        }
        _ = drawExplosionCores(viewport: gameViewport, context: context)
        drawCursorBadge(viewport: gameViewport, context: context)
        FailureMoodArt.draw(in: bounds, amount: failureAmount, context: context)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        decoration.frame = bounds
        overlay.frame = bounds
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
        layoutBitmap()
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
        drawSpriteTrails(viewport: viewport, context: context)
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
        #if os(iOS)
        if displaySettings.gameplayCursorStyle == .modern {
            let frame = CGRect(x: point.x - 7 * sourceFactor, y: point.y - 7 * sourceFactor,
                               width: 14 * sourceFactor, height: 14 * sourceFactor)
            let marks = AssignmentPointerShape.marks(in: frame, arm: 5 * sourceFactor,
                stroke: sourceFactor, occupied: cursorOccupied, eligible: cursorEligible)
            context.saveGState()
            context.setShouldAntialias(false)
            context.setFillColor(cursorEligible ? CGColor(srgbRed: 0.3, green: 0.85, blue: 0.2, alpha: 1)
                : cursorOccupied ? CGColor(srgbRed: 1, green: 0.8, blue: 0.15, alpha: 1) : CGColor(gray: 0.6, alpha: 1))
            marks.forEach { context.fill($0) }
            context.restoreGState()
        }
        #endif
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
        if trackedTouchIDs.count == 2, activeTouchID != nil, router.isHoldingSelection,
           touches.count == 1, let touch = touches.first, touch.type == .direct,
           acceptsInput(at: touch.location(in: self)) {
            let point = inputPoint(touch.location(in: self))
            onTouchEffects?(router.began(id: ObjectIdentifier(touch).hashValue,
                at: .init(x: point.x, y: point.y), time: touch.timestamp))
            return
        }
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
            allowsPanning: touch.type != .pencil,
            allowsHolding: touch.type == .direct && canHoldSelection?(.init(x: point.x, y: point.y)) == true
        ))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouchID != nil, !ignoresTouchSequenceUntilLift else { return }
        // Process the selection finger first when both contacts move in one event.
        let ordered = touches.sorted { ObjectIdentifier($0) == activeTouchID && ObjectIdentifier($1) != activeTouchID }
        var effects: [MobileTouchEffect] = []
        for touch in ordered {
            guard acceptsInput(at: touch.location(in: self)) else { cancelInteraction(); return }
            let point = inputPoint(touch.location(in: self))
            effects += router.moved(id: ObjectIdentifier(touch).hashValue,
                to: .init(x: point.x, y: point.y), time: touch.timestamp)
        }
        if !effects.isEmpty { onTouchEffects?(effects) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        trackedTouchIDs.subtract(touches.map(ObjectIdentifier.init))
        if ignoresTouchSequenceUntilLift {
            resetTouchSequenceIfNeeded()
            return
        }
        guard let touchID = activeTouchID else { resetTouchSequenceIfNeeded(); return }
        guard touches.allSatisfy({ acceptsInput(at: $0.location(in: self)) }) else {
            cancelInteraction()
            resetTouchSequenceIfNeeded()
            return
        }
        let ordered = touches.sorted { ObjectIdentifier($0) != touchID && ObjectIdentifier($1) == touchID }
        for touch in ordered {
            let point = inputPoint(touch.location(in: self))
            onTouchEffects?(router.ended(id: ObjectIdentifier(touch).hashValue,
                at: .init(x: point.x, y: point.y), time: touch.timestamp))
            if ObjectIdentifier(touch) == touchID { activeTouchID = nil }
        }
        if activeTouchID == nil, !trackedTouchIDs.isEmpty { ignoresTouchSequenceUntilLift = true }
        resetTouchSequenceIfNeeded()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        trackedTouchIDs.subtract(touches.map(ObjectIdentifier.init))
        if ignoresTouchSequenceUntilLift {
            resetTouchSequenceIfNeeded()
            return
        }
        cancelInteraction()
        resetTouchSequenceIfNeeded()
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
            guard pinchGestureActive, acceptsInput(at: recognizer.location(in: self)) else {
                recognizer.scale = 1
                return
            }
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
/// Selection, cursor and effect overlays above the GPU-scaled bitmap.
@MainActor private final class MobilePlayfieldOverlay: UIView {
    var drawContent: ((CGContext) -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        isHidden = true
    }
    required init?(coder: NSCoder) { nil }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        drawContent?(context)
    }
}
@MainActor private final class MobilePlayfieldDecoration: UIView {
    var rescueAmount: CGFloat = 0 { didSet { setNeedsDisplay() } }
    override func draw(_ rect: CGRect) {
        #if os(iOS)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        RescueCelebration.draw(in: bounds, amount: rescueAmount, context: context)
        #endif
    }
}
#endif
