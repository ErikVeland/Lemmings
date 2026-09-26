import AppKit
import NxlvKit

/// Maps between level pixels and view points for a scrolled, zoomed playfield.
struct Viewport {
  var scrollX = 0.0
  var scrollY = 0.0
  var zoom = 3.0
  var levelSize = CGSize(width: 1, height: 1)
  var viewSize = CGSize(width: 1, height: 1)

  /// Level pixels visible across the view.
  var visibleSize: CGSize {
    CGSize(width: viewSize.width / zoom, height: viewSize.height / zoom)
  }

  var maximumScrollX: Double { max(0, levelSize.width - visibleSize.width) }
  var maximumScrollY: Double { max(0, levelSize.height - visibleSize.height) }

  mutating func clamp() {
    scrollX = min(max(0, scrollX), maximumScrollX)
    scrollY = min(max(0, scrollY), maximumScrollY)
  }

  mutating func scroll(dx: Double, dy: Double) {
    scrollX += dx
    scrollY += dy
    clamp()
  }

  mutating func center(on x: Double) {
    scrollX = x - visibleSize.width / 2
    clamp()
  }

  /// Centers the level when it does not fill the view.
  ///
  /// Classic levels are 160 pixels tall, so at most zoom levels they leave
  /// space above and below.
  var contentOffset: CGPoint {
    let drawn = CGSize(width: levelSize.width * zoom, height: levelSize.height * zoom)
    return CGPoint(
      x: drawn.width < viewSize.width ? (viewSize.width - drawn.width) / 2 : 0,
      y: drawn.height < viewSize.height ? (viewSize.height - drawn.height) / 2 : 0)
  }

  /// Converts a view point to level pixels. The view is flipped, so both
  /// coordinate systems increase downward.
  func levelPoint(from viewPoint: CGPoint) -> CGPoint {
    let offset = contentOffset
    return CGPoint(
      x: scrollX + (viewPoint.x - offset.x) / zoom,
      y: scrollY + (viewPoint.y - offset.y) / zoom)
  }

  func viewPoint(fromLevel point: CGPoint) -> CGPoint {
    let offset = contentOffset
    return CGPoint(
      x: (point.x - scrollX) * zoom + offset.x,
      y: (point.y - scrollY) * zoom + offset.y)
  }

  var visibleLevelRect: CGRect {
    CGRect(x: scrollX, y: scrollY, width: visibleSize.width, height: visibleSize.height)
  }
}

/// What the screen is showing between levels.
enum GamePhase: Equatable {
  case briefing
  case playing
  case results
}

enum ReticleState { case unavailable, eligible, assigned, alreadyAssigned }

struct ReticleFeedback {
  private(set) var successUntil: TimeInterval = 0
  private var orangeUntil: TimeInterval = 0
  private var lastDuplicate: String?
  private var orangeAllowedAt: TimeInterval = 0
  mutating func assigned(now: TimeInterval) { successUntil = now + 0.10 }
  mutating func state(eligible: Bool, duplicate: String?, now: TimeInterval) -> ReticleState {
    if now < successUntil { return .assigned }
    if eligible { lastDuplicate = nil; return .eligible }
    if let duplicate, duplicate != lastDuplicate {
      lastDuplicate = duplicate
      if now >= orangeAllowedAt { orangeUntil = now + 0.08; orangeAllowedAt = now + 0.25 }
    } else if duplicate == nil { lastDuplicate = nil }
    return duplicate != nil && now < orangeUntil ? .alreadyAssigned : .unavailable
  }
  var nextChange: TimeInterval { max(successUntil, orangeUntil) }
}

@MainActor final class PlayfieldView: NSView {
  var hdEffectsEnabled = true {
    didSet {
      if !hdEffectsEnabled {
        speedTrails.reset(); hdrBirths.removeAll(); hdrFlashes.removeAll(); hdrOverlay?.clear()
      }
      needsDisplay = true
    }
  }
  var reduceMotion = false {
    didSet {
      assignmentHighlight.reduceMotion = reduceMotion
      if reduceMotion { speedTrails.reset() }
      needsDisplay = true
    }
  }
  var reduceFlashes = false {
    didSet {
      if reduceFlashes { hdrBirths.removeAll(); hdrFlashes.removeAll(); hdrOverlay?.clear() }
      needsDisplay = true
    }
  }
  let startCountdown = FreshLevelCountdown()
  var showReticleCount = false
    var skillCursorIconSize: SkillCursorIconSize = .one
    var favorApproachingLemmings = true
    var favorBombBlockers = true
    var favorBuilders = true
  var speedMultiplier: Double = 3 { didSet { speedTrails.multiplier = speedMultiplier } }
  var isFastForward = false
  private let speedTrails = SpeedTrails()
  private var rewindGhost: CGImage?
  private var rewindCueStartedAt: TimeInterval?
  private var rewindCueUntil: TimeInterval = 0
  private var rewindOriginTick = 0
  private var rewindCurrentTick = 0
  private var rewindCueTask: Task<Void, Never>?
  private var hdrOverlay: ExplosionHDRView?
  private(set) var hdrFlashes: [ExplosionFlash] = []
  private var hdrBirths: [Int:(tick:Int,expires:TimeInterval)] = [:]
  private var hdrLastTick = 0
  var presentsHDR = true {
    didSet {
      hdrOverlay?.isHidden = !presentsHDR
      hdrOverlay?.update(presentsHDR ? hdrFlashes : [],force:true)
    }
  }
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window != nil, hdrOverlay == nil {
      let overlay = ExplosionHDRView(frame:bounds)
      overlay.autoresizingMask = [.width,.height]
      overlay.isHidden = !presentsHDR
      addSubview(overlay)
      hdrOverlay = overlay
    }
    hdrOverlay?.update(presentsHDR ? hdrFlashes : [],force:true)
  }
  /// Lines drawn over the level before it starts or after it ends.
  private let accessibleElements = GameAccessibleElements()
  override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityChildren() -> [Any]? { accessibleControls(owner: self) }
  func accessibleControls(owner: NSView, transform: (CGRect) -> CGRect = { $0 }) -> [Any] {
    guard phase != .playing else {
      let text = "Game playfield" + (turnInitials.map { ". \($0)'s turn" } ?? "")
      return [accessibleElements.element(id: "status", owner: owner, label: text, frame: transform(bounds))]
    }
    var items: [Any] = []
    if let overlayTitle { items.append(accessibleElements.element(id: "title", owner: owner, label: overlayTitle, frame: transform(bounds))) }
    if let rect = overlaySettingsButtonFrame() {
      items.append(accessibleElements.element(
        id: "settings", owner: owner, label: "Settings", frame: transform(rect)
      ) { [weak self] in self?.onSettings?() })
    }
    if let rect = overlayUpdateButtonFrame(), let label = overlayAvailableUpdate {
      items.append(accessibleElements.element(id: "update", owner: owner,
        label: label + ". Show update and release notes", frame: transform(rect)) { [weak self] in self?.onUpdate?() })
    }
    for (index, line) in overlayLines.enumerated() {
      let rect = overlayLineRects.indices.contains(index) ? overlayLineRects[index] : bounds
      let actionable = overlayHighlight != nil || overlayRetryLine == index || overlayReplayLine == index
      let action: (() -> Void)? = actionable ? { [weak self] in
        guard let self else { return }
        if self.overlayRetryLine == index { self.onRetry?() }
        else if self.overlayReplayLine == index { self.onReplay?(false) }
        else { self.onSelectOverlayLine?(index) }
      } : nil
      items.append(accessibleElements.element(id: "line-\(index)", owner: owner, label: line, frame: transform(rect), press: action))
    }
    if overlayHighlight == nil {
      let rect = handoverButtons.count == 2 && overlayHandoverRetryTitle != nil ? handoverButtons[1] : bounds
      items.append(accessibleElements.element(id: "continue", owner: owner, label: overlayHandoverRetryTitle == nil ? "Continue" : "Begin level", frame: transform(rect)) { [weak self] in self?.onAdvancePhase?() })
    }
    if let title = overlayHandoverRetryTitle, let rect = handoverButtons.first {
      items.append(accessibleElements.element(id: "handover-retry", owner: owner, label: title, frame: transform(rect)) { [weak self] in self?.onHandoverRetry?() })
    }
    for (index, rect) in overlayFooterButtons.enumerated() {
      items.append(accessibleElements.element(id: "footer-\(index)", owner: owner, label: ["Player profiles", "Records", "Playlists"][index], frame: transform(rect)) { [weak self] in
        self?.activateFooterButton(index)
      })
    }
    return items
  }
  var overlayTitle: String? {
    didSet { overlayTurnInitials = nil; overlayHandoverRetryTitle = nil }
  }
  var overlayTurnInitials: String?
  var overlayHandoverRetryTitle: String?
  var onHandoverRetry: (() -> Void)?
  private var handoverButtons: [CGRect] = []
  var overlayLines: [String] = []
  var overlayFooter: String? { didSet { overlayProfileInitials = nil } }
  var overlayProfileInitials: String?
  var onProfiles: (() -> Void)?
  var onRecords: (() -> Void)?
  var onPlaylists: (() -> Void)?
  var overlayShowsSettingsButton = false
  var onSettings: (() -> Void)?
  var overlayAvailableUpdate: String?
  var onUpdate: (() -> Void)?
  private var overlayFooterButtons: [CGRect] = []
  private func activateFooterButton(_ index: Int) {
    switch index {
    case 0: onProfiles?()
    case 1: onRecords?()
    case 2: onPlaylists?()
    default: break
    }
  }
  /// Which overlay line is currently chosen, when the screen offers a choice.
  var overlayHighlight: Int?
  /// Marches real lemmings along the foot of the screen.
  var overlayShowsLemmings = false
  /// The hot seat player holding the Mac. Nil in solo play, where there is
  /// nobody to tell apart and the badge would only be clutter. The game pushes
  /// this in every frame, so ending a hot seat or passing the turn cannot leave
  /// a stale name on screen. It is passed in rather than read from the record
  /// store because this view is also compiled on its own by the draw tests.
  var turnInitials: String?
  var turnPortrait: Int?
  private var turnSprite: NSImage?
  private var turnSpriteIndex: Int?
  /// Advanced by the run loop so the march animates while a menu is up.
  var overlayFrame = 0
  var phase: GamePhase = .playing {
    didSet {
      if phase != oldValue { reticleFeedback = ReticleFeedback(); assignedTarget = nil; displayedTarget = nil; cursorViewPoint = nil; overlayReplayLine = nil; overlayRetryLine = nil }
      if phase != oldValue { window?.invalidateCursorRects(for: self) }
    }
  }
  var levelImage: CGImage?
  var imageScale = 1.0
  var macArtwork: ClassicMacArtwork? { didSet { invalidateSprites() } }
  /// Artwork for the menus, which outlives any level.
  ///
  /// A level's artwork is chosen in the settings and is thrown away between
  /// levels. The menus need lettering before a level is loaded and after one
  /// ends, so the front end holds its own reference.
  var interfaceArtwork: ClassicMacArtwork? {
    didSet {
      macInterface = interfaceArtwork
        .flatMap(ClassicMacUserInterface.init(artwork:))
        .map(MacInterfaceRenderer.init(interface:)) ?? GameMenuArtwork.renderer()
    }
  }
  private var macInterface: MacInterfaceRenderer? = GameMenuArtwork.renderer()
  var macScene: ClassicMacScene? { didSet { sceneTick = nil } }
  var classicScene: ClassicRenderedLevel? {
    didSet { sceneTick = nil }
  }
  private var sceneTick: Int?
  #if PERFORMANCE_TESTS
  var sceneRenderSeconds = 0.0
  #endif

  private func refreshClassicScene() {
    guard let classicScene, let session = session as? ClassicSession,
          sceneTick != session.currentTick else { return }
    #if PERFORMANCE_TESTS
    let sceneStarted = ProcessInfo.processInfo.systemUptime
    defer { sceneRenderSeconds += ProcessInfo.processInfo.systemUptime - sceneStarted }
    #endif
    let rgba = macScene?.rgba(simulation: session.simulation)
      ?? ClassicSceneFrame.rgba(classicScene, simulation: session.simulation)
    imageScale = macScene == nil ? 1 : 2
    let width = macScene?.width ?? classicScene.width
    let height = macScene?.height ?? classicScene.height
    guard let provider = CGDataProvider(data: rgba as CFData),
          let image = CGImage(width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return }
    levelImage = image
    sceneTick = session.currentTick
  }
  var session: (any GameSession)? {
    didSet { if oldValue !== session { reticleFeedback = ReticleFeedback(); assignedTarget = nil; displayedTarget = nil; hdrBirths.removeAll(); hdrLastTick = 0; speedTrails.reset() } }
  }
  var failureMoodAmount: CGFloat = 0
  var assets: ClassicMainDATAssets?
  var palette: [ClassicRGBColor] = []
  var viewport = Viewport()
  var onAssign: ((Int) -> Void)?
  var onViewportChanged: (() -> Void)?
  /// Called when a click should dismiss a briefing or a result.
  var onAdvancePhase: (() -> Void)?
  var onSelectOverlayLine: ((Int) -> Void)?
  var overlayReplayLine: Int?
  var onReplay: ((Bool) -> Void)?
  var overlayRetryLine: Int?
  var onRetry: (() -> Void)?
  private var overlayLineRects: [CGRect] = []

  private var spriteCache: [String: NSImage] = [:]
  private var spritePixels: [String: CGImage] = [:]
  private var skillBadgeCache: [Int: NSImage] = [:]
  var usesControllerPointer: Bool { controllerPointer != nil }
  private var controllerPointer: CGPoint?
  func moveControllerPointer(_ dx: Double, _ dy: Double) {
    let p = controllerPointer ?? CGPoint(x: bounds.midX, y: bounds.midY)
    let next = CGPoint(x: max(0, min(bounds.width - 1, p.x + dx * viewport.zoom)),
                       y: max(0, min(bounds.height - 1, p.y + dy * viewport.zoom)))
    handleMove(to: next); controllerPointer = next
  }
  let assignmentHighlight = LemmingFocusHighlight()
  private let assignmentPulse = LemmingAssignmentPulse()
  var selectedSkill: () -> Int = { 0 }
  private var reticleFeedback = ReticleFeedback()
  private var reticleRedraw: Task<Void, Never>?
  private var assignedTarget: Int?

  func didAssign(to id: Int) {
    assignedTarget = id
    assignmentPulse.show(id)
    if !reduceFlashes { reticleFeedback.assigned(now: ProcessInfo.processInfo.systemUptime) }
    needsDisplay = true
    scheduleReticleRedraw()
  }

  private func scheduleReticleRedraw() {
    let remaining = reticleFeedback.nextChange - ProcessInfo.processInfo.systemUptime
    let assignmentRemaining = assignmentPulse.remaining
    let shimmer = cursorViewPoint != nil && !reduceMotion && session != nil
    let delay = max(remaining, assignmentRemaining, shimmer ? 1.0 / 30.0 : 0)
    guard delay > 0 else { return }
    reticleRedraw?.cancel()
    reticleRedraw = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64((delay + 0.005) * 1_000_000_000))
      guard !Task.isCancelled else { return }
      self?.needsDisplay = true
      self?.scheduleReticleRedraw()
    }
  }

  func reticleState(at point: CGPoint, now: TimeInterval) -> ReticleState {
    let target = lemming(at: point)
    let eligible = target.map { session?.canAssign(skillIndex: selectedSkill(), to: $0.id) == true } ?? false
    if eligible { return reticleFeedback.state(eligible: true, duplicate: nil, now: now) }
    let skill = selectedSkill()
    let duplicate = session?.lemmings.filter { contains($0, point) }.sorted {
      distanceSquared($0, point) < distanceSquared($1, point)
    }.first { session?.assignmentState(skillIndex: skill, to: $0.id) == .alreadyAssigned }
    return reticleFeedback.state(eligible: eligible, duplicate: duplicate.map { "\($0.id):\(skill)" }, now: now)
  }
  private var displayedTarget: (id: Int, point: CGPoint, time: TimeInterval)?
  var pointerLemmingID: Int? { cursorViewPoint.flatMap { clickTarget(at: viewport.levelPoint(from: $0))?.id } }
  private var cursorViewPoint: CGPoint?
  private var trackingArea: NSTrackingArea?

  /// Captures the visible state before a rewind starts.
  func beginRewindCue(at tick: Int) {
    rewindGhost = nil
    if let bitmap = bitmapImageRepForCachingDisplay(in: bounds) {
      cacheDisplay(in: bounds, to: bitmap)
      rewindGhost = bitmap.cgImage
    }
    rewindOriginTick = tick
    rewindCurrentTick = tick
    rewindCueStartedAt = ProcessInfo.processInfo.systemUptime
    rewindCueUntil = .infinity
    needsDisplay = true
    scheduleRewindCueRedraw()
  }

  /// Updates the transport cue after a deterministic history seek.
  func updateRewindCue(at tick: Int) {
    rewindCurrentTick = tick
    needsDisplay = true
  }

  /// Leaves the origin ghost on screen briefly, then fades it away.
  func endRewindCue() {
    guard rewindCueStartedAt != nil else { return }
    rewindCueStartedAt = nil
    rewindCueUntil = ProcessInfo.processInfo.systemUptime + 0.35
    needsDisplay = true
    scheduleRewindCueRedraw()
  }

  private func scheduleRewindCueRedraw() {
    rewindCueTask?.cancel()
    guard rewindCueStartedAt != nil || ProcessInfo.processInfo.systemUptime < rewindCueUntil else { return }
    rewindCueTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 33_000_000)
      guard !Task.isCancelled else { return }
      self?.needsDisplay = true
      self?.scheduleRewindCueRedraw()
    }
  }

  override var isFlipped: Bool { true }
  override var acceptsFirstResponder: Bool { true }

  override func setFrameSize(_ newSize: NSSize) {
    let center = viewport.scrollX + viewport.visibleSize.width / 2
    let hadSize = viewport.viewSize.width > 1
    super.setFrameSize(newSize)
    viewport.viewSize = newSize
    if hadSize { viewport.center(on: center) }
    onViewportChanged?()
  }

  // MARK: - Tracking

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let trackingArea { removeTrackingArea(trackingArea) }
    let area = NSTrackingArea(
      rect: bounds,
      options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect],
      owner: self)
    addTrackingArea(area)
    trackingArea = area
  }

  override func resetCursorRects() {
    guard phase == .playing else { return }
    addCursorRect(bounds, cursor: GameCursor.gameplayCursor)
  }

  override func cursorUpdate(with event: NSEvent) {
    if phase == .playing { GameCursor.gameplayCursor.set() } else { NSCursor.arrow.set() }
  }

  /// Takes a cursor position directly.
  ///
  /// When the picture is drawn through the tube the events land on that view,
  /// not this one, so a point arrives already converted.
  func handleMove(to point: CGPoint) {
    controllerPointer = nil
    assignmentHighlight.clear()
    cursorViewPoint = point
    needsDisplay = true
  }

  /// Takes a click position directly.
  func handleClick(at point: CGPoint) {
    guard phase == .playing else {
      if let rect = overlayUpdateButtonFrame(), rect.contains(point) {
        onUpdate?()
        return
      }
      if let rect = overlaySettingsButtonFrame(), rect.contains(point) {
        onSettings?()
        return
      }
      if overlayHandoverRetryTitle != nil, let index = handoverButtons.firstIndex(where: { $0.contains(point) }) {
        if index == 0 { onHandoverRetry?() } else { onAdvancePhase?() }
        return
      }
      if overlayProfileInitials != nil,
        let index = overlayFooterButtons.firstIndex(where: { $0.contains(point) }) {
        activateFooterButton(index)
        return
      }
      if let line = overlayRetryLine, overlayLineRects.indices.contains(line), overlayLineRects[line].contains(point) {
        onRetry?(); return
      }
      if let line = overlayReplayLine, overlayLineRects.indices.contains(line), overlayLineRects[line].contains(point) {
        onReplay?(point.x > bounds.midX); return
      }
      if overlayHighlight != nil {
        if let index = overlayLineRects.firstIndex(where: { $0.contains(point) }) { onSelectOverlayLine?(index) }
      } else { onAdvancePhase?() }
      return
    }
    assignmentHighlight.clear()
    cursorViewPoint = point
    let levelPoint = viewport.levelPoint(from: point)
    let target = clickTarget(at: levelPoint)
    displayedTarget = nil
    if let target { onAssign?(target.id) }
    needsDisplay = true
  }

  override func mouseMoved(with event: NSEvent) {
    controllerPointer = nil
    let point = convert(event.locationInWindow, from: nil)
    assignmentHighlight.clear()
    cursorViewPoint = point
    needsDisplay = true
  }

  override func mouseExited(with event: NSEvent) {
    clearPointer()
  }

  func clearPointer() {
    cursorViewPoint = nil
    displayedTarget = nil
    needsDisplay = true
  }

  /// Level pixels to scroll this frame when the cursor rests near an edge.
  ///
  /// The classic game scrolls while the cursor sits in the outer margin. The
  /// speed rises closer to the edge.
  var edgeScrollDelta: Double? {
    guard let point = cursorViewPoint, bounds.width > 0, bounds.contains(point) else { return nil }
    let margin = 48.0
    if point.x < margin {
      return -((margin - Double(point.x)) / margin) * 8
    }
    if point.x > Double(bounds.width) - margin {
      return ((Double(point.x) - (Double(bounds.width) - margin)) / margin) * 8
    }
    return nil
  }

  override func mouseDown(with event: NSEvent) {
    handleClick(at: convert(event.locationInWindow, from: nil))
  }

  override func scrollWheel(with event: NSEvent) {
    // A trackpad swipe scrolls the level sideways, as the classic game does.
    viewport.scroll(dx: -Double(event.scrollingDeltaX), dy: -Double(event.scrollingDeltaY))
    onViewportChanged?()
    needsDisplay = true
  }

  /// A small allowance covers sprite edges without reaching across the crowd.
  private static let pickBox = (halfWidth: CGFloat(6), top: CGFloat(14), bottom: CGFloat(5))

  /// Hover and input share skill priorities. A current builder takes priority
  /// only while it can accept Build, so lemmings behind it stay selectable.
  func lemming(at point: CGPoint) -> SessionLemming? {
    guard let session else { return nil }
    let skill = selectedSkill()
    let candidates = session.lemmings.filter { contains($0, point) }.sorted {
      let a = distanceSquared($0, point), b = distanceSquared($1, point)
      return a == b ? $0.id > $1.id : a < b
    }
    let name = session.skills.indices.contains(skill) ? session.skills[skill].name.lowercased() : ""
    if favorBuilders, name == "builder", !session.isComplete, !session.isNuking,
       session.skills[skill].isInfinite || session.skills[skill].count > 0,
       let builder = candidates.first(where: {
         [.building, .shrugging].contains($0.pose) && session.canAssign(skillIndex: skill, to: $0.id)
       }) {
      return builder
    }
    let eligible = candidates.filter { session.canAssign(skillIndex: skill, to: $0.id) }
    if favorBombBlockers, name == "bomber", let blocker = eligible.first(where: { $0.pose == .blocking }) {
      return blocker
    }
    guard let nearest = eligible.first else { return nil }
    if favorApproachingLemmings, nearest.pose == .building {
      // A follower behind the builder can sit outside the click's own pick
      // box, so look for one near the builder instead of near the click.
      let builderPoint = CGPoint(x: CGFloat(nearest.x), y: CGFloat(nearest.y))
      let nearbyFollowers = session.lemmings
        .filter { $0.id != nearest.id && contains($0, builderPoint) && session.canAssign(skillIndex: skill, to: $0.id) }
        .sorted { distanceSquared($0, point) < distanceSquared($1, point) }
      if let follower = nearbyFollowers.first(where: { isApproaching($0, point: point) && isBehind($0, builder: nearest) }) {
        return follower
      }
    }
    if favorApproachingLemmings, !isApproaching(nearest, point: point),
       let approaching = eligible.first(where: { isApproaching($0, point: point) && $0.facingLeft != nearest.facingLeft }) {
      return approaching
    }
    return nearest
  }

  /// Whether `point` sits on the side of `lemming` that matches its facing.
  private func isApproaching(_ lemming: SessionLemming, point: CGPoint) -> Bool {
    let direction: CGFloat = lemming.facingLeft ? -1 : 1
    return (point.x - CGFloat(lemming.x)) * direction >= 0
  }

  /// Whether `lemming` follows the builder in the builder's travel direction.
  private func isBehind(_ lemming: SessionLemming, builder: SessionLemming) -> Bool {
    guard lemming.facingLeft == builder.facingLeft else { return false }
    return builder.facingLeft ? lemming.x > builder.x : lemming.x < builder.x
  }

  /// Honour the green target briefly while it walks between display and input.
  func clickTarget(at point: CGPoint) -> SessionLemming? {
    if let session, session.skills.indices.contains(selectedSkill()) {
      let name = session.skills[selectedSkill()].name.lowercased()
      if (favorBuilders && name == "builder") || (favorBombBlockers && name == "bomber") {
        return lemming(at: point)
      }
    }
    if let displayedTarget, ProcessInfo.processInfo.systemUptime - displayedTarget.time <= 0.12,
       hypot(point.x - displayedTarget.point.x, point.y - displayedTarget.point.y) <= 2,
       let session, let target = session.lemmings.first(where: { $0.id == displayedTarget.id }),
       distanceSquared(target, point) <= 16 * 16,
       session.canAssign(skillIndex: selectedSkill(), to: target.id) {
      return target
    }
    return lemming(at: point)
  }

  private func distanceSquared(_ lemming: SessionLemming, _ point: CGPoint) -> CGFloat {
    let dx = CGFloat(lemming.x) - point.x, dy = CGFloat(lemming.y - 5) - point.y
    return dx * dx + dy * dy
  }

  private func contains(_ lemming: SessionLemming, _ point: CGPoint) -> Bool {
    let box = Self.pickBox
    let x = CGFloat(lemming.x), y = CGFloat(lemming.y)
    return point.x >= x - box.halfWidth && point.x <= x + box.halfWidth
      && point.y >= y - box.top && point.y <= y + box.bottom
  }

  func invalidateSprites() { spriteCache.removeAll(); spritePixels.removeAll() }

  // MARK: - Drawing

  override func draw(_ dirtyRect: NSRect) {
    defer {
      if phase == .playing { startCountdown.draw(in: bounds) }
      // The shared corner reticle also represents the controller pointer.
      if let id = assignmentHighlight.target, let lem = session?.lemmings.first(where: { $0.id == id }) {
        assignmentHighlight.draw(at: viewport.viewPoint(fromLevel: CGPoint(x: lem.x, y: lem.y - 6)),
          scale: viewport.zoom, tint: .systemYellow, radius: 7)
      }
    }
    updateSpeedTrails()
    hdrFlashes.removeAll(keepingCapacity:true)
    let tick = session?.currentTick ?? 0
    if tick < hdrLastTick { hdrBirths.removeAll() }
    hdrLastTick = tick
    defer { hdrOverlay?.update(presentsHDR ? hdrFlashes : []) }
    refreshClassicScene()
    // Fill the view's own area, not the dirty rectangle. AppKit passes a
    // rectangle that can cover the whole window, because these views share one
    // backing layer.
    NSColor.black.setFill()
    bounds.fill()

    // A menu can appear before any level is loaded, so the overlay must not
    // depend on there being a picture behind it.
    if let levelImage {
      viewport.viewSize = bounds.size
      viewport.levelSize = CGSize(width: Double(levelImage.width) / imageScale, height: Double(levelImage.height) / imageScale)
      viewport.clamp()

      NSGraphicsContext.current?.imageInterpolation = .none
      if phase != .playing, overlayShowsLemmings {
        // The backdrop behind a menu is decoration, not a view onto a level,
        // so it ignores the viewport. Feeding zoom into the crop width and the
        // scroll position into the crop origin made zooming on a menu move the
        // picture sideways, and change its size only past a threshold.
        // The picture fills the height and is centred on its own width.
        let scale = bounds.height / CGFloat(levelImage.height)
        let width = min(CGFloat(levelImage.width), bounds.width / scale)
        let x = (CGFloat(levelImage.width) - width) / 2
        if let cropped = levelImage.cropping(to: CGRect(x: x, y: 0,
          width: width, height: CGFloat(levelImage.height))) {
          NSImage(cgImage: cropped, size: .zero).draw(in: bounds, from: .zero,
            operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
      } else {
        drawLevel(levelImage)
        speedTrails.draw(enabled: hdEffectsEnabled && !reduceMotion && isFastForward && phase == .playing, in: bounds) { drawLemmings() }
      }
      FailureMoodOverlay.draw(in: bounds, amount: failureMoodAmount)
      drawRewindCue()
      if phase == .playing { drawTurnBadge(); drawCursor() }
    }
    if phase != .playing { drawOverlay() }
  }

  /// Dims the level and shows the briefing or the result over it.
  ///
  /// The original put these on their own screens. Keeping the level visible
  /// behind them means the player can already read the terrain while the
  /// briefing is up, which is the one thing the original made you wait for.
  /// A colour from the level palette, so menus and levels share one table.
  ///
  /// Using system colours here is what makes a menu read as an application
  /// rather than as the game. Everything on screen comes from the same
  /// sixteen entries the terrain uses.
  private func paletteColor(_ index: Int, fallback: NSColor) -> NSColor {
    guard palette.indices.contains(index) else { return fallback }
    let entry = palette[index]
    return NSColor(
      calibratedRed: CGFloat(entry.red) / 255,
      green: CGFloat(entry.green) / 255,
      blue: CGFloat(entry.blue) / 255,
      alpha: 1)
  }

  private struct OverlayLayout {
    let scale: CGFloat
    let rowHeight: CGFloat
    let headerHeight: CGFloat
    let board: CGRect
  }

  private func overlayLayout() -> OverlayLayout {
    let showsLogo = overlayTitle == "LEMMINGS" && macInterface?.interface.logo != nil
    let headerUnits: CGFloat = showsLogo ? 116 : 62
    let marchHeight: CGFloat = overlayShowsLemmings ? 64 : 0
    let scale = min(2.5, bounds.width / 1100,
      max(1, bounds.height - marchHeight - 24)
        / (headerUnits + 106 + CGFloat(overlayLines.count) * 42))
    let width = min(bounds.width - 28 * scale, 900 * scale)
    let headerHeight = headerUnits * scale
    let height = (106 + CGFloat(overlayLines.count) * 42) * scale + headerHeight
    let board = CGRect(
      x: (bounds.width - width) / 2,
      y: max(12, (bounds.height - marchHeight - height) / 2),
      width: width,
      height: height)
    return OverlayLayout(
      scale: scale,
      rowHeight: 42 * scale,
      headerHeight: headerHeight,
      board: board)
  }

  private func overlaySettingsButtonFrame(_ layout: OverlayLayout? = nil) -> CGRect? {
    guard overlayShowsSettingsButton else { return nil }
    let layout = layout ?? overlayLayout()
    let side = max(44, 48 * layout.scale)
    return CGRect(
      x: layout.board.maxX - 18 * layout.scale - side,
      y: layout.board.minY + 18 * layout.scale,
      width: side,
      height: side)
  }

  private func overlayUpdateButtonFrame(_ layout: OverlayLayout? = nil) -> CGRect? {
    guard overlayAvailableUpdate != nil, overlayShowsSettingsButton else { return nil }
    let layout = layout ?? overlayLayout()
    let side = max(44, 48 * layout.scale)
    return CGRect(x: layout.board.minX + 18 * layout.scale, y: layout.board.minY + 18 * layout.scale,
      width: side, height: side)
  }

  private func drawOverlay() {
    overlayLineRects = []
    overlayFooterButtons = []
    handoverButtons = []
    NSColor.black.withAlphaComponent(0.42).setFill()
    bounds.fill()
    let showsLogo = overlayTitle == "LEMMINGS" && macInterface?.interface.logo != nil
    let layout = overlayLayout()
    let scale = layout.scale
    let rowHeight = layout.rowHeight
    let headerHeight = layout.headerHeight
    let board = layout.board
    let settingsButton = overlaySettingsButtonFrame(layout)

    // Chunky stone edging and a moss cap echo the level terrain.
    (macInterface == nil ? NSColor(calibratedRed: 0.09, green: 0.12, blue: 0.16, alpha: 0.97)
      : NSColor(calibratedWhite: 0.015, alpha: 0.96)).setFill()
    board.fill()
    GameMenuFrame.draw(board, scale: scale)

    // Use one face and scale for every row, fitted to the longest label.
    let longest = overlayLines.map { MacInterfaceRenderer.menuText($0).count }.max() ?? 1
    let rowTextWidth = board.width - 64 * scale
    let rowTextHeight = rowHeight - 12 * scale
    var menuFace = ClassicMacUserInterface.Face.small
    var menuScale = 1
    if let macInterface {
      var bestHeight = 0
      for face in [ClassicMacUserInterface.Face.large, .small] {
        guard let font = macInterface.font(face) else { continue }
        let fit = min(Int(rowTextHeight) / font.cellHeight,
          Int(rowTextWidth) / max(1, longest * font.cellWidth))
        if fit >= 1, fit * font.cellHeight > bestHeight {
          menuFace = face; menuScale = fit; bestHeight = fit * font.cellHeight
        }
      }
    }

    var y = board.minY + 19 * scale
    if showsLogo, let macInterface {
      let maximumWidth: CGFloat
      if let settings = settingsButton {
        maximumWidth = max(1, min(
          board.width - 40 * scale,
          2 * (settings.minX - board.midX - 10 * scale)))
      } else {
        maximumWidth = board.width - 40 * scale
      }
      _ = macInterface.drawLogo(
        centerX: bounds.midX, top: y - 4 * scale,
        maximumWidth: maximumWidth, maximumHeight: headerHeight - 26 * scale)
    } else if let overlayTitle {
      let heading = CGRect(x: board.minX + 18 * scale, y: y,
        width: board.width - 36 * scale, height: headerHeight - 18 * scale)
      if !drawMacText(overlayTitle, in: heading, minimumScale: 1) {
        GamePixelText.draw(overlayTitle, in: heading)
      }
    }
    if let settings = settingsButton {
      let hovered = cursorViewPoint.map(settings.contains) ?? false
      let pixel = max(1, floor(scale))
      GameStoneButton.draw(
        settings,
        selected: hovered,
        pixel: pixel,
        backdrop: PanelGlyph.rock.image(fitting: settings.size))
      let well = GameStoneButton.well(settings, pixel: pixel).insetBy(dx: 2 * pixel, dy: 2 * pixel)
      if let image = PanelGlyph.settings.image(fitting: well.size) {
        image.draw(
          in: CGRect(
            x: floor(well.midX - image.size.width / 2),
            y: floor(well.midY - image.size.height / 2),
            width: image.size.width,
            height: image.size.height),
          from: .zero,
          operation: .sourceOver,
          fraction: 1,
          respectFlipped: true,
          hints: [.interpolation: NSImageInterpolation.none])
      }
    }
    if let update = overlayUpdateButtonFrame(layout) {
      let pixel = max(1, floor(scale))
      GameStoneButton.draw(update, selected: cursorViewPoint.map(update.contains) ?? false, pixel: pixel,
        backdrop: PanelGlyph.rock.image(fitting: update.size))
      let well = GameStoneButton.well(update, pixel: pixel).insetBy(dx: 2 * pixel, dy: 2 * pixel)
      if let image = PanelGlyph.download.image(fitting: well.size) {
        image.draw(in: CGRect(x: floor(well.midX - image.size.width / 2), y: floor(well.midY - image.size.height / 2),
          width: image.size.width, height: image.size.height), from: .zero, operation: .sourceOver,
          fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
      }
    }
    y += headerHeight
    for (index, line) in overlayLines.enumerated() {
      let row = CGRect(x: board.minX + 18 * scale, y: y,
        width: board.width - 36 * scale, height: rowHeight - 5 * scale)
      overlayLineRects.append(row)
      let chosen = index == overlayHighlight
      if overlayHighlight != nil {
        (chosen
          ? NSColor(calibratedRed: 0.18, green: 0.27, blue: 0.12, alpha: 1)
          : NSColor(calibratedWhite: 0.07, alpha: 1)).setFill()
        row.fill()
        (chosen
          ? NSColor(calibratedRed: 0.70, green: 0.84, blue: 0.29, alpha: 1)
          : NSColor(calibratedWhite: 0.29, alpha: 1)).setStroke()
        let outline = NSBezierPath(rect: row.insetBy(dx: 0.5, dy: 0.5))
        outline.lineWidth = max(1, scale)
        outline.stroke()
      }
      drawMenuGameText(line, in: row.insetBy(dx: 14 * scale, dy: 0),
        face: menuFace, scale: menuScale)
      if index == 0, let initials = overlayTurnInitials, let macInterface,
        let font = macInterface.font(menuFace) {
        let value = MacInterfaceRenderer.menuText(line)
        let name = MacInterfaceRenderer.menuText(initials)
        let start = row.midX - macInterface.width(of: value, face: menuFace, scale: menuScale) / 2
        let offset = CGFloat((value.count - name.count) * font.cellWidth * menuScale)
        macInterface.draw(name, face: menuFace,
          at: CGPoint(x: start + offset, y: floor(row.midY - CGFloat(font.cellHeight * menuScale) / 2)),
          scale: menuScale, palette: .green)
      }
      if index == 0, turnInitials != nil { drawTurnPortrait(in: row, scale: scale) }
      y += rowHeight
    }
    if let retryTitle = overlayHandoverRetryTitle {
      let footer = CGRect(x: board.minX + 20 * scale, y: y + 12 * scale,
        width: board.width - 40 * scale, height: max(36, 48 * scale))
      let gap = 16 * scale
      let retryWidth = (footer.width - gap) * 0.64
      handoverButtons = [CGRect(x: footer.minX, y: footer.minY, width: retryWidth, height: footer.height),
        CGRect(x: footer.minX + retryWidth + gap, y: footer.minY, width: footer.width - retryWidth - gap, height: footer.height)]
      for (index, label) in [retryTitle, "Begin level"].enumerated() {
        let rect = handoverButtons[index]
        GameStoneButton.draw(rect, selected: index == 1, pixel: max(1, floor(scale)))
        drawMenuGameText(label, in: rect.insetBy(dx: 10 * scale, dy: 6 * scale), face: .small,
          scale: max(1, Int(scale)), palette: index == 1 ? .green : .blue)
      }
    } else if let initials = overlayProfileInitials {
      let footer = CGRect(x: board.minX + 20 * scale, y: y + 12 * scale,
        width: board.width - 40 * scale, height: max(36, 48 * scale))
      let footerScale = max(1, Int(scale.rounded()))
      let gap: CGFloat = 12 * scale
      let labels = ["PROFILES", "RECORDS", "PLAYLISTS"]
      let count = CGFloat(labels.count)
      // Let the roster grow while keeping each footer action readable.
      let cell = CGFloat((macInterface?.font(.small)?.cellWidth ?? 8) * footerScale)
      let natural = CGFloat(MacInterfaceRenderer.menuText(initials).count) * cell + 12 * scale
      let minimumButtonWidth = max(110 * scale, 9 * cell + 16 * scale)
      let widest = max(64 * scale, footer.width - count * (minimumButtonWidth + gap))
      let initialsWidth = max(64 * scale, min(natural, widest))
      let buttonWidth = min(180 * scale, max(0, (footer.width - initialsWidth - gap * count) / count))
      let start = floor(footer.midX - (initialsWidth + count * (buttonWidth + gap)) / 2)
      drawMenuGameText(initials, in: CGRect(x: start, y: footer.minY,
        width: initialsWidth, height: footer.height), face: .small, scale: footerScale, palette: .green)
      for (index, label) in labels.enumerated() {
        let rect = CGRect(x: start + initialsWidth + gap + CGFloat(index) * (buttonWidth + gap),
          y: footer.minY, width: buttonWidth, height: footer.height)
        overlayFooterButtons.append(rect)
        let hovered = cursorViewPoint.map { rect.contains($0) } ?? false
        (hovered ? NSColor(calibratedRed: 0.06, green: 0.16, blue: 0.035, alpha: 1)
          : NSColor(calibratedWhite: 0.025, alpha: 1)).setFill()
        rect.fill()
        (hovered ? NSColor(calibratedRed: 0.48, green: 0.80, blue: 0.24, alpha: 1)
          : NSColor(calibratedWhite: 0.35, alpha: 1)).setStroke()
        NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5)).stroke()
        drawMenuGameText(label, in: rect, face: .small, scale: footerScale,
          palette: hovered ? .green : .blue)
      }
    } else if let overlayFooter {
      let footer = CGRect(x: board.minX + 20 * scale, y: y + 12 * scale,
        width: board.width - 40 * scale, height: max(36, 48 * scale))
      drawMenuGameText(overlayFooter, in: footer, face: .small, scale: 1, wrap: true)
    }
    if overlayShowsLemmings { drawMarchingLemmings() }
  }

  /// Draw the original glyphs on whole pixels and keep long text inside its band.
  private func drawMenuGameText(_ text: String, in rect: CGRect,
    face: ClassicMacUserInterface.Face, scale: Int, wrap: Bool = false,
    palette: MacInterfaceRenderer.Palette = .blue) {
    guard let macInterface, let font = macInterface.font(face) else {
      GamePixelText.draw(MacInterfaceRenderer.menuText(text), in: rect)
      return
    }
    let height = font.cellHeight * scale
    let columns = max(1, Int(rect.width) / (font.cellWidth * scale))
    let lines = wrap ? MacInterfaceRenderer.menuLines(text, columns: columns) : [text]
    let rows = max(1, Int(rect.height) / height)
    let shown = min(rows, lines.count)
    let top = floor(rect.midY - CGFloat(shown * height) / 2)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(rect: rect).addClip()
    for (index, line) in lines.prefix(rows).enumerated() {
      let value = index == rows - 1 && lines.count > rows
        ? String(line.prefix(max(0, columns - 3))) + "..." : line
      macInterface.menuLine(value,
        in: CGRect(x: rect.minX, y: top + CGFloat(index * height),
          width: rect.width, height: CGFloat(height)), face: face, scale: scale, palette: palette)
    }
    NSGraphicsContext.restoreGraphicsState()
  }

  /// Draws a menu line in the release's own character set.
  ///
  /// Both Macintosh character sets are monospaced, so every glyph advances one
  /// cell no matter how wide its own pixels are. The scale stays a whole
  /// number, because a fraction blurs pixels the original never blurred.
  private func drawMacText(
    _ text: String, in rect: CGRect, minimumScale: Int = 1
  ) -> Bool {
    guard let macInterface else { return false }
    // The original menus are upper case throughout.
    let normalized = text.uppercased()
      .replacingOccurrences(of: "—", with: "-")
      .replacingOccurrences(of: "’", with: "'")

    for face in [ClassicMacUserInterface.Face.large, .small] {
      guard let font = macInterface.font(face), font.covers(normalized) else { continue }
      let wide = font.cellWidth * max(1, normalized.count)
      let fit = min(Int(rect.height) / max(1, font.cellHeight), Int(rect.width) / max(1, wide))
      guard fit >= minimumScale else { continue }
      macInterface.drawCentered(
        normalized, face: face, centerX: rect.midX,
        top: rect.midY - macInterface.height(face: face, scale: fit) / 2, scale: fit, palette: .green)
      return true
    }
    return false
  }

  /// Rounds a crop to whole level pixels - multiples of `imageScale` - on
  /// every edge, clamped to the image bounds. Mac artwork doubles the source
  /// image (`imageScale == 2`); a crop edge that lands on an odd image pixel
  /// divides back into a fractional point size below, and nearest-neighbor
  /// upscaling of a fractional destination samples source pixels unevenly.
  /// That showed up as scrambled pixels on small, detailed objects such as
  /// the entrance hatch, and how it landed depended on the screen's own
  /// pixel grid, so it looked worse on some displays than others.
  ///
  /// Exposed (not private) so a test can check the geometry directly rather
  /// than inferring it from rendered pixels.
  nonisolated static func levelCropRect(visible: CGRect, imageScale: CGFloat, imageSize: CGSize) -> CGRect {
    let originX = floor(visible.minX / imageScale) * imageScale
    let originY = floor(visible.minY / imageScale) * imageScale
    let rawWidth = min(ceil(visible.width) + 1, imageSize.width - originX)
    let rawHeight = min(ceil(visible.height) + 1, imageSize.height - originY)
    return CGRect(
      x: originX, y: originY,
      width: min(ceil(rawWidth / imageScale) * imageScale, imageSize.width - originX),
      height: min(ceil(rawHeight / imageScale) * imageScale, imageSize.height - originY))
  }

  private func drawLevel(_ image: CGImage) {
    // Crop in image pixels. CGImage uses a top-left origin, which matches the
    // level coordinate system, so no vertical flip is needed here.
    let logical = viewport.visibleLevelRect
    let visible = CGRect(x: logical.minX * imageScale, y: logical.minY * imageScale,
      width: logical.width * imageScale, height: logical.height * imageScale)
    let crop = Self.levelCropRect(
      visible: visible, imageScale: imageScale,
      imageSize: CGSize(width: image.width, height: image.height))
    guard crop.width > 0, crop.height > 0, let cropped = image.cropping(to: crop) else { return }

    let origin = viewport.viewPoint(fromLevel: CGPoint(x: crop.minX / imageScale, y: crop.minY / imageScale))
    let destination = CGRect(
      x: origin.x, y: origin.y,
      width: crop.width * viewport.zoom / imageScale, height: crop.height * viewport.zoom / imageScale)
    drawPixels(cropped, in: destination)
  }

  private func drawPixels(_ image: CGImage, in rect: CGRect, alpha: CGFloat = 1) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    context.saveGState()
    context.interpolationQuality = .none
    context.setAlpha(alpha)
    context.translateBy(x: rect.minX, y: rect.maxY)
    context.scaleBy(x: 1, y: -1)
    context.draw(image, in: CGRect(origin: .zero, size: rect.size))
    context.restoreGState()
  }

  private func drawSprite(_ sprite: NSImage, key: String, in rect: CGRect, alpha: CGFloat) {
    guard let pixels = spritePixels[key] ?? sprite.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
    if spritePixels.count < 1500 { spritePixels[key] = pixels }
    drawPixels(pixels, in: rect, alpha: alpha)
  }

  private func drawLemmings() {
    guard let session else { return }
    let lemmings = session.lemmings
    if hdEffectsEnabled && !reduceMotion && isFastForward && phase == .playing {
      for lemming in lemmings { draw(lemming, ghostsOnly: true) }
    }
    // Every solid lemming and its labels cover every ghost, including neighbours.
    for lemming in lemmings { draw(lemming) }
  }

  func updateSpeedTrails() {
    let enabled = hdEffectsEnabled && !reduceMotion && isFastForward && phase == .playing
    let actors: [SpeedTrails.Actor] = enabled ? (session?.lemmings ?? []).compactMap { lemming in
      switch lemming.pose {
      case .walking, .jumping, .postClimb, .falling, .umbrellaOpening, .floating, .climbing:
        return .init(id: lemming.id, position: CGPoint(x: lemming.x, y: lemming.y), movement: lemming.pose.rawValue)
      default: return nil
      }
    } : []
    speedTrails.update(tick: session?.currentTick ?? 0, enabled: enabled, actors: actors)
  }

  /// Four opaque ticks, then an immediate cut. The engine's longer explosion
  /// state still controls terrain damage and removal timing.
  static func bombPopIsVisible(tick: Int) -> Bool { (0..<4).contains(tick) }

  private func bombPop(_ rect: CGRect, tick: Int) -> (rect: CGRect, alpha: CGFloat) {
    (rect, !hdEffectsEnabled || Self.bombPopIsVisible(tick: tick) ? 1 : 0)
  }

  /// A white-hot core followed by a yellow tick.
  private func drawBombCore(in rect: CGRect, tick: Int, actor: Int) {
    guard hdEffectsEnabled, !reduceFlashes, (0..<2).contains(tick) else { return }
    let pixel = max(1, floor(viewport.zoom))
    let x = floor(rect.midX/pixel)*pixel, y = floor(rect.midY/pixel)*pixel
    ExplosionHDR.drawCore(at: CGPoint(x: x, y: y), pixel: CGSize(width: pixel, height: pixel), phase: tick)
    if phase == .playing {
      let birthTick = (session?.currentTick ?? 0)-tick
      if hdrBirths[actor]?.tick != birthTick {
        hdrBirths[actor] = (birthTick,ProcessInfo.processInfo.systemUptime+0.14)
      }
      let expires = hdrBirths[actor]!.expires
      let strength: Float = tick == 0 ? 1 : 0.5
      hdrFlashes.append(.init(rect:CGRect(x:x-3*pixel,y:y-pixel,width:6*pixel,height:2*pixel).intersection(bounds),strength:strength,expiresAt:expires))
      hdrFlashes.append(.init(rect:CGRect(x:x-pixel,y:y-3*pixel,width:2*pixel,height:6*pixel).intersection(bounds),strength:strength,expiresAt:expires))
    }
  }

  private func draw(_ lemming: SessionLemming, ghostsOnly: Bool = false) {
    let motion = ghostsOnly ? speedTrails.motion(actor: lemming.id) : .zero
    if ghostsOnly && motion == .zero { return }
    guard let assets, !palette.isEmpty else { return }
    let direction: ClassicSpriteDirection = lemming.facingLeft ? .left : .right
    let pose = lemming.pose
    guard
      let animation = assets.animation(for: pose, direction: direction)
        ?? assets.animation(for: pose, direction: .none),
      !animation.frames.isEmpty
    else { return }

    if let frame = macArtwork?.lemming(pose: pose, left: lemming.facingLeft, tick: lemming.animationFrame) {
      let key = "mac-\(pose.rawValue)-\(direction.rawValue)-\(lemming.animationFrame)"
      let sprite = spriteCache[key] ?? frame.makeNSImage()
      if let sprite {
        if spriteCache.count < 1500 { spriteCache[key] = sprite }
        let origin = viewport.viewPoint(fromLevel: CGPoint(
          x: Double(lemming.x + animation.offsetX) + Double(frame.x) / 2,
          y: Double(lemming.y + animation.offsetY) + Double(frame.y) / 2))
        var rect = CGRect(x: origin.x, y: origin.y,
          width: Double(frame.width) * viewport.zoom / 2, height: Double(frame.height) * viewport.zoom / 2)
        var fraction: CGFloat = 1
        if pose == .explosion { (rect, fraction) = bombPop(rect, tick: lemming.animationFrame) }
        guard rect.intersects(bounds), fraction > 0.01 else { return }
        if ghostsOnly {
          speedTrails.drawBehind(actor: lemming.id, sprite: sprite, in: rect, motion: motion,
            pixelSize: CGSize(width: viewport.zoom, height: viewport.zoom))
          return
        }
        drawSprite(sprite, key: key, in: rect, alpha: fraction)
        drawAssignmentPulse(for: lemming.id, key: key, sprite: sprite, in: rect)
        if pose == .explosion { drawBombCore(in: rect, tick: lemming.animationFrame, actor:lemming.id) }
        if let countdown = lemming.countdown { drawCountdown(countdown, above: rect) }
        return
      }
    }

    let index = abs(lemming.animationFrame) % animation.frames.count
    let key = "\(pose.rawValue)-\(direction.rawValue)-\(index)"
    let sprite: NSImage
    if let cached = spriteCache[key] {
      sprite = cached
    } else {
      guard let made = image(from: animation.frames[index]) else { return }
      spriteCache[key] = made
      sprite = made
    }

    let levelOrigin = CGPoint(
      x: CGFloat(lemming.x + animation.offsetX),
      y: CGFloat(lemming.y + animation.offsetY))
    let origin = viewport.viewPoint(fromLevel: levelOrigin)
    var rect = CGRect(
      x: origin.x, y: origin.y,
      width: sprite.size.width * viewport.zoom, height: sprite.size.height * viewport.zoom)
    var fraction: CGFloat = 1
    if pose == .explosion { (rect, fraction) = bombPop(rect, tick: lemming.animationFrame) }
    guard rect.intersects(bounds), fraction > 0.01 else { return }
    if ghostsOnly {
      speedTrails.drawBehind(actor: lemming.id, sprite: sprite, in: rect, motion: motion,
        pixelSize: CGSize(width: viewport.zoom, height: viewport.zoom))
      return
    }
    drawSprite(sprite, key: key, in: rect, alpha: fraction)
    drawAssignmentPulse(for: lemming.id, key: key, sprite: sprite, in: rect)
    if pose == .explosion { drawBombCore(in: rect, tick: lemming.animationFrame, actor:lemming.id) }

    if let countdown = lemming.countdown {
      drawCountdown(countdown, above: rect)
    }
  }

  private func drawAssignmentPulse(for id: Int, key: String, sprite: NSImage, in rect: CGRect) {
    guard assignmentPulse.target == id,
          let pixels = spritePixels[key] ?? sprite.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { return }
    assignmentPulse.draw(sprite: pixels, in: rect, scale: viewport.zoom,
      reduceMotion: reduceMotion, reduceFlashes: reduceFlashes)
  }

  private func drawCountdown(_ countdown: Int, above rect: CGRect) {
    let seconds = max(1, (countdown + ClassicDOSRules.ticksPerSecond - 1) / ClassicDOSRules.ticksPerSecond)
    let text = "\(seconds)" as NSString
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedDigitSystemFont(ofSize: 10 * viewport.zoom / 3, weight: .bold),
      .foregroundColor: NSColor.white,
    ]
    let size = text.size(withAttributes: attributes)
    text.draw(
      at: CGPoint(x: rect.midX - size.width / 2, y: rect.minY - size.height),
      withAttributes: attributes)
  }

  private func drawCursor() {
    guard !GameCursor.gameplaySuppressed, let cursorViewPoint else { return }
    let point = viewport.levelPoint(from: cursorViewPoint)
    let target = lemming(at: point)
    let now = ProcessInfo.processInfo.systemUptime
    let state = reticleState(at: point, now: now)
    let pulseTarget = state == .assigned ? session?.lemmings.first(where: { $0.id == assignedTarget }) : nil
    scheduleReticleRedraw()
    displayedTarget = target.map { ($0.id, point, ProcessInfo.processInfo.systemUptime) }
    let targetPoint = viewport.viewPoint(
      fromLevel: (pulseTarget ?? target).map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y) - 5) } ?? point)
    let color: NSColor
    switch state {
    case .unavailable: color = target == nil ? NSColor(calibratedWhite: 0.6, alpha: 0.9) : .systemYellow
    case .eligible: color = NSColor(calibratedRed: 0.3, green: 0.85, blue: 0.2, alpha: 1)
    case .assigned: color = NSColor(calibratedRed: 0.65, green: 1, blue: 0.45, alpha: 1)
    case .alreadyAssigned: color = NSColor(calibratedRed: 1, green: 0.62, blue: 0.08, alpha: 1)
    }

    if state == .assigned, hdEffectsEnabled, !reduceFlashes,
       (target != nil || pulseTarget != nil) {
      let pixel = max(1, floor(viewport.zoom))
      let expires = reticleFeedback.successUntil
      hdrFlashes.append(.init(
        rect: CGRect(x: targetPoint.x - pixel, y: targetPoint.y - pixel,
          width: 2 * pixel, height: 2 * pixel).intersection(bounds),
        strength: 0.45, expiresAt: expires, tint: .green))
    }

    // The lemming, rather than the pointer, is the point of attention. Keep
    // this cue soft so it confirms the target without changing play timing or
    // obscuring the native sprite artwork.
    if target != nil, assignmentHighlight.target == nil {
      LemmingSelectionGlow.draw(at: targetPoint, scale: viewport.zoom, radius: 7,
        tint: color, animated: !reduceMotion)
    }

    // Keep the reticle at the actual cursor position. The target glow remains
    // separate, so a target offset does not change click precision.
    GameCursor.drawPlayfieldPointer(at: cursorViewPoint, scale: viewport.zoom,
      tint: GameCursor.targetTint(eligible: target.map { session?.canAssign(skillIndex: selectedSkill(), to: $0.id) == true } == true,
        occupied: session?.lemmings.contains { contains($0, point) } == true))

    if showReticleCount {
      let centres = (session?.lemmings ?? []).map {
        viewport.viewPoint(fromLevel: CGPoint(x: CGFloat($0.x), y: CGFloat($0.y) - 5))
      }
      let count = SkillCursorBadge.count(centres: centres, at: cursorViewPoint, scale: viewport.zoom)
      SkillCursorBadge.drawCount(count, at: cursorViewPoint, scale: viewport.zoom,
        size: skillCursorIconSize, icon: skillCursorIconSize == .none ? nil : skillBadge(for: selectedSkill()), in: bounds)
    }
    SkillCursorBadge.draw(icon: skillBadge(for: selectedSkill()), index: selectedSkill(),
      at: cursorViewPoint, scale: viewport.zoom, tint: color,
      size: skillCursorIconSize, reduceMotion: reduceMotion, in: bounds)
  }

  private func skillBadge(for index: Int) -> NSImage? {
    guard (0..<8).contains(index), let assets else { return nil }
    if let cached = skillBadgeCache[index] { return cached }
    let poses: [ClassicLemmingPose] = [.climbing, .floating, .ohNo, .blocking,
      .building, .bashing, .mining, .digging]
    let animation = assets.animation(for: poses[index], direction: .right)
      ?? assets.animation(for: poses[index], direction: .none)
    guard let frame = animation?.frames.first,
          let image = image(from: frame) else { return nil }
    skillBadgeCache[index] = image
    return image
  }

  private func drawRewindCue() {
    let now = ProcessInfo.processInfo.systemUptime
    guard let ghost = rewindGhost,
          rewindCueStartedAt != nil || now < rewindCueUntil else {
      if rewindCueStartedAt == nil { rewindGhost = nil }
      return
    }
    let fading = rewindCueStartedAt == nil
    let fade = fading ? CGFloat(max(0, rewindCueUntil - now) / 0.35) : 1
    let elapsed = CGFloat(now - (rewindCueStartedAt ?? now))
    let sweep = reduceMotion ? 0 : floor((elapsed * 18).truncatingRemainder(dividingBy: 8))
    let context = NSGraphicsContext.current?.cgContext
    context?.saveGState()
    if let context {
      context.clip(to: CGRect(origin: viewport.contentOffset, size: viewport.visibleSize))
      context.setAlpha(0.10 * fade)
      context.interpolationQuality = .none
      context.draw(ghost, in: bounds.offsetBy(dx: -sweep, dy: 0))
      if !reduceMotion {
        context.setAlpha(0.07 * fade)
        context.setFillColor(NSColor.systemBlue.cgColor)
        context.fill(CGRect(x: viewport.contentOffset.x + sweep,
          y: viewport.contentOffset.y, width: max(1, viewport.zoom), height: viewport.visibleSize.height))
      }
    }
    context?.restoreGState()
    RewindTransportCue.draw(
      origin: CGPoint(x: 12, y: 12),
      currentTick: rewindCurrentTick,
      originTick: rewindOriginTick
    )
  }

  /// Walks a row of real lemmings across the foot of a menu.
  ///
  /// These are the decoded walking frames the game uses in play, not artwork
  /// made for the menu, so the screen is built from the same sprites.
  private func turnPortraitImage() -> NSImage? {
    guard let index = turnPortrait else { return nil }
    if turnSpriteIndex == index, let cached = turnSprite { return cached }
    let poses: [ClassicLemmingPose] = [.walking, .climbing, .floating, .building,
                                       .bashing, .mining, .digging, .blocking]
    guard poses.indices.contains(index),
      let frame = macArtwork?.lemming(pose: poses[index], left: false, tick: 3),
      let image = frame.makeNSImage() else { return nil }
    turnSprite = image; turnSpriteIndex = index
    return image
  }

  /// Names the player on the briefing, beside the line that announces the turn.
  private func drawTurnPortrait(in row: CGRect, scale: CGFloat) {
    guard let image = turnPortraitImage() else { return }
    let height = min(row.height * 1.6, 40 * scale)
    let size = NSSize(width: image.size.width / image.size.height * height, height: height)
    image.draw(in: CGRect(x: row.minX + 8 * scale, y: row.midY - size.height / 2,
        width: size.width, height: size.height),
      from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
      hints: [.interpolation: NSImageInterpolation.none])
  }

  /// A quiet reminder during play. It must not compete with the level.
  private func drawTurnBadge() {
    guard let initials = turnInitials else { return }
    let scale = max(1, min(2, bounds.width / 960))
    let height = 22 * scale
    let image = turnPortraitImage()
    let spriteWidth = image.map { $0.size.width / $0.size.height * height } ?? 0
    let textWidth = CGFloat(MacInterfaceRenderer.menuText(initials).count + 1)
      * CGFloat((macInterface?.font(.small)?.cellWidth ?? 8) * Int(scale))
    let badge = CGRect(x: bounds.maxX - (spriteWidth + textWidth + 14 * scale) - 10 * scale,
      y: bounds.maxY - height - 10 * scale,
      width: spriteWidth + textWidth + 14 * scale, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.cgContext.setAlpha(0.55)
    NSColor.black.withAlphaComponent(0.5).setFill()
    NSBezierPath(rect: badge).fill()
    if let image {
      image.draw(in: CGRect(x: badge.minX + 5 * scale, y: badge.minY, width: spriteWidth, height: height),
        from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.none])
    }
    drawMenuGameText(initials, in: CGRect(x: badge.minX + spriteWidth + 9 * scale,
      y: badge.minY, width: textWidth, height: height), face: .small, scale: Int(scale))
    NSGraphicsContext.restoreGraphicsState()
  }

  private func drawMarchingLemmings() {
    if let macArtwork {
      let scale = max(1.5, min(3, bounds.width / 900))
      let spacing = 32 * scale
      var x = -spacing + (CGFloat(overlayFrame) * scale / 3).truncatingRemainder(dividingBy: spacing)
      var index = 0
      while x < bounds.width {
        if let frame = macArtwork.lemming(pose: .walking, left: false, tick: overlayFrame / 4 + index * 3),
          let image = frame.makeNSImage() {
          image.draw(in: CGRect(x: x + CGFloat(frame.x) * scale,
            y: bounds.height - CGFloat(20 - frame.y) * scale,
            width: CGFloat(frame.width) * scale, height: CGFloat(frame.height) * scale),
            from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        x += spacing; index += 1
      }
      return
    }
    guard let assets, !palette.isEmpty,
      let walk = assets.animation(for: .walking, direction: .right),
      !walk.frames.isEmpty
    else { return }

    let scale: CGFloat = 3
    let spacing: CGFloat = 46
    let baseline = bounds.height - 34 * scale / 3
    let drift = CGFloat(overlayFrame) * 0.6
    var x = -spacing + drift.truncatingRemainder(dividingBy: spacing)

    var index = 0
    while x < bounds.width + spacing {
      // Stagger the frames so they are not all in step, as a crowd would be.
      let frame = walk.frames[(overlayFrame / 4 + index * 3) % walk.frames.count]
      let key = "menu-\(frame.width)x\(frame.height)-\((overlayFrame / 4 + index * 3) % walk.frames.count)"
      let sprite: NSImage
      if let cached = spriteCache[key] {
        sprite = cached
      } else if let made = image(from: frame) {
        spriteCache[key] = made
        sprite = made
      } else {
        return
      }
      sprite.draw(
        in: NSRect(
          x: x, y: baseline,
          width: sprite.size.width * scale, height: sprite.size.height * scale),
        from: .zero, operation: .sourceOver, fraction: 0.85, respectFlipped: true, hints: nil)
      x += spacing
      index += 1
    }
  }

  private func image(from frame: ClassicIndexedBitmap) -> NSImage? {
    guard
      let rgba = try? frame.rgba(using: palette),
      let provider = CGDataProvider(data: rgba as CFData),
      let cg = CGImage(
        width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    else { return nil }
    return NSImage(cgImage: cg, size: CGSize(width: frame.width, height: frame.height))
  }
}

@MainActor extension ClassicMacArtwork.Frame {
  func makeNSImage() -> NSImage? {
    guard let provider = CGDataProvider(data: rgba as CFData),
      let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
    return NSImage(cgImage: image, size: CGSize(width: width, height: height))
  }
}
