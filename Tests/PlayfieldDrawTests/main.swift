import AppKit
import NxlvKit

// The playing view and the panel share one window-sized backing layer, so
// AppKit hands each of them a dirty rectangle that covers the whole window.
// A view that fills that rectangle paints over its neighbours. The panel is
// drawn after the playing view, so the fault turned the whole game black and
// left only the panel readable.
//
// The test draws the real views into a bitmap and reads the pixels back.

private struct Failure: Error, CustomStringConvertible {
  let description: String
}

private final class BombPreviewSession: GameSession {
  var animationTick = 0
  var y = 80
  var actors: [SessionLemming]?
  let levelWidth = 320, levelHeight = 160, ticksPerSecond = 17
  var lemmings: [SessionLemming] {
    actors ?? [.init(id:0,x:160,y:y,pose:.explosion,facingLeft:false,animationFrame:animationTick,countdown:nil)]
  }
  let entranceX: Int? = nil
  let released = 1, total = 1, saved = 0, required = 1, rate = 50
  let rateLabel = "Rate"
  let remainingSeconds: Int? = nil
  let isComplete = false, didWin = false, isNuking = false, canUndoNuke = false, supportsRewind = false
  let skills: [SessionSkill] = [], lastCues: [ClassicSoundEffect] = []
  var currentTick: Int { animationTick }
  func tick() { animationTick += 1 }
  func assign(skillIndex: Int, to lemmingID: Int) -> String? { nil }
  func assignmentState(skillIndex: Int, to lemmingID: Int) -> AssignmentState { .unavailable }
  func adjustRate(by delta: Int) {}
  func nuke() {}
  func undoNuke() {}
  func rewind(seconds: Double) -> Bool { false }
  func stepBackward() -> Bool { false }
  func stepForward() -> Bool { false }
}

@MainActor private func testBombFlashFrames() throws {
  let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  let out = root.appendingPathComponent(".build/bomb-pop")
  try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
  let view = PlayfieldView(frame:NSRect(x:0,y:0,width:640,height:320))
  let session = BombPreviewSession()
  view.session = session; view.phase = .playing; view.viewport.zoom = 2
  view.assets = try ClassicMainDATAssets.load(from:root.appendingPathComponent("Content/lemming1.pc"))
  view.palette = ClassicLemmingPalette.panelVGA
  view.levelImage = CGContext(data:nil,width:320,height:160,bitsPerComponent:8,bytesPerRow:1280,
    space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()
  let testApp = ProcessInfo.processInfo.environment["LEMMINGS_TEST_APP"].map { URL(fileURLWithPath: $0) }
    ?? root.appendingPathComponent(".build/local/Ultimate Lemmings.app")
  let macRoot = testApp.appendingPathComponent("Contents/Resources/MacArtwork/lemmings")
  let modes = FileManager.default.fileExists(atPath:macRoot.path) ? ["pc","mac"] : ["pc"]
  for mode in modes {
    view.macArtwork = mode == "mac" ? try ClassicMacArtwork(directory:macRoot) : nil
    for tick in [0,1,2,3,4,50] {
      session.animationTick = tick
      let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds)!
      view.cacheDisplay(in:view.bounds,to:bitmap)
      try require(tick < 2 ? view.hdrFlashes.count == 2 : view.hdrFlashes.isEmpty,
        "HDR flash did not follow the short core lifetime")
      if let expires = view.hdrFlashes.first?.expiresAt {
        try require(ExplosionHDR.mask(width:640,height:320,flashes:view.hdrFlashes,now:expires).allSatisfy {$0 == 0},
          "pausing the explosion left HDR pixels lit")
      }
      let data = bitmap.representation(using:.png,properties:[:])!
      try data.write(to:out.appendingPathComponent("\(mode)-\(tick).png"))
      var lit = 0
      for y in 0..<bitmap.pixelsHigh { for x in 0..<bitmap.pixelsWide {
        if bitmap.colorAt(x:x,y:y)!.brightnessComponent > 0.1 { lit += 1 }
      } }
      try require(tick < 4 ? lit > 0 : lit == 0, "\(mode) bomb pop at tick \(tick) has \(lit) lit pixels")
    }
  }
  view.hdEffectsEnabled = false
  session.animationTick = 0
  view.cacheDisplay(in: view.bounds, to: view.bitmapImageRepForCachingDisplay(in: view.bounds)!)
  try require(view.hdrFlashes.isEmpty, "Old-school mode retained the HDR core")
  session.animationTick = 4
  let oldSchool = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
  view.cacheDisplay(in: view.bounds, to: oldSchool)
  try require((0..<oldSchool.pixelsHigh).contains { y in
    (0..<oldSchool.pixelsWide).contains { x in oldSchool.colorAt(x: x, y: y)!.brightnessComponent > 0.1 }
  }, "Old-school mode did not restore the original explosion animation")
  view.hdEffectsEnabled = true
  session.y = 165; session.animationTick = 0
  view.cacheDisplay(in:view.bounds,to:view.bitmapImageRepForCachingDisplay(in:view.bounds)!)
  let composedMask = ExplosionHDR.mask(width:640,height:400,flashes:view.hdrFlashes)
  try require(composedMask[(320*640)...].allSatisfy {$0 == 0}, "an edge explosion put HDR pixels into the CRT panel")
  print("PASS real PC/Mac explosion frames: opaque pop followed by an empty frame")
}

private func require(
  _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
  guard condition() else { throw Failure(description: message()) }
}

/// The window as the app builds it: the playing view above, the panel below.
@MainActor private func makeWindow() -> (NSWindow, PlayfieldView, PanelView) {
  let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 1000, height: 620),
    styleMask: [.titled], backing: .buffered, defer: false)
  let root = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 620))
  let playfield = PlayfieldView(frame: NSRect(x: 0, y: 142, width: 1000, height: 478))
  let panel = PanelView(frame: NSRect(x: 0, y: 0, width: 1000, height: 142))
  root.addSubview(playfield)
  root.addSubview(panel)
  window.contentView = root
  return (window, playfield, panel)
}

/// Renders the whole window the way the screen does, then counts lit pixels
/// in one horizontal band. The band is measured down from the top.
@MainActor private func litPixels(
  _ window: NSWindow, fromTop: Double, height: Double
) throws -> Int {
  guard let root = window.contentView,
    let rep = root.bitmapImageRepForCachingDisplay(in: root.bounds)
  else { throw Failure(description: "the window would not give a bitmap") }
  root.cacheDisplay(in: root.bounds, to: rep)

  let scale = Double(rep.pixelsWide) / Double(root.bounds.width)
  let first = Int(fromTop * scale)
  let last = min(rep.pixelsHigh, Int((fromTop + height) * scale))
  var lit = 0
  for y in stride(from: first, to: last, by: 2) {
    for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
      guard let color = rep.colorAt(x: x, y: y) else { continue }
      if color.brightnessComponent > 0.25 { lit += 1 }
    }
  }
  return lit
}

/// A menu stands on its own, before any level is loaded.
@MainActor private func testMenuSurvivesThePanel() throws {
  let (window, playfield, panel) = makeWindow()
  panel.isMenuMode = true
  playfield.phase = .briefing
  playfield.overlayTitle = "LEMMINGS"
  playfield.overlayLines = ["FULL QUEST  0/228", "LEMMINGS  0/120"]
  playfield.overlayFooter = "UP AND DOWN TO CHOOSE"
  playfield.overlayHighlight = 0

  let menu = try litPixels(window, fromTop: 0, height: 478)
  try require(
    menu > 200,
    "the menu drew \(menu) lit pixels, so the panel painted over the playing view")
}

/// And the panel still draws its own area.
@MainActor private func testPanelDrawsItself() throws {
  let (window, playfield, panel) = makeWindow()
  panel.isMenuMode = true
  panel.statusText = "Loaded 12 sound effects."
  playfield.phase = .briefing
  playfield.overlayTitle = "LEMMINGS"

  let status = try litPixels(window, fromTop: 478, height: 142)
  try require(status > 20, "the panel drew \(status) lit pixels, so its status is missing")
}

@MainActor private func testCameraResize() throws {
  let view = PlayfieldView(frame: CGRect(x: 0, y: 0, width: 960, height: 480))
  view.viewport.levelSize = CGSize(width: 1600, height: 160)
  view.viewport.viewSize = view.bounds.size
  view.viewport.center(on: 800)
  view.setFrameSize(CGSize(width: 1800, height: 900))
  try require(abs(view.viewport.visibleLevelRect.midX - 800) < 0.01,
    "fullscreen resize moved the starting camera")
  view.viewport.center(on: 0)
  try require(view.viewport.scrollX == 0, "camera escaped the left boundary")
  view.handleMove(to: CGPoint(x: 1, y: 100))
  view.phase = .briefing
  view.phase = .playing
  try require(view.edgeScrollDelta == nil, "menu cursor scrolled the new level")
}

@MainActor private func testClassicPanelLabels() throws {
  let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  let directory = root.appendingPathComponent("Sources/Ports/xmas_dos_XmasLemmingsV1.9")
  let level = try ClassicDataSet.detect(directory: directory).campaign.levels[0].level
  let assets = try ClassicMainDATAssets.load(from: directory)
  let ground = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
  let scene = try ClassicLevelRenderer.render(level, groundSet: ground)
  let simulation = try ClassicDOSSimulation(level: level, renderedLevel: scene, mainDATAssets: assets)
  let panel = PanelView(frame: NSRect(x: 0, y: 0, width: 960, height: 160))
  panel.session = ClassicSession(simulation: simulation, width: scene.width, height: scene.height)
  let graphics = assets.panel!
  let pixels = graphics.rgba(using: ClassicLemmingPalette.panelVGA)
  let provider = CGDataProvider(data: pixels as CFData)!
  panel.panelImage = CGImage(width: graphics.width, height: graphics.height, bitsPerComponent: 8,
    bitsPerPixel: 32, bytesPerRow: graphics.width * 4, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
    decode: nil, shouldInterpolate: false, intent: .defaultIntent)
  let testApp = ProcessInfo.processInfo.environment["LEMMINGS_TEST_APP"].map { URL(fileURLWithPath: $0) }
    ?? root.appendingPathComponent(".build/local/Ultimate Lemmings.app")
  let artworkRoot = testApp.appendingPathComponent("Contents/Resources/MacArtwork/lemmings")
  panel.interfaceArtwork = try ClassicMacArtwork(directory: artworkRoot)
  panel.macArtwork = panel.interfaceArtwork
  let labelOutput = root.appendingPathComponent(".build/panel-label-regression")
  try FileManager.default.createDirectory(at: labelOutput, withIntermediateDirectories: true)
  for width in [640.0, 960.0, 1280.0, 1484.0, 1920.0] {
    panel.setFrameSize(NSSize(width: width, height: 240))
    for fast in [false, true] {
      panel.isFastForward = fast
      let bitmap = panel.bitmapImageRepForCachingDisplay(in: panel.bounds)!
      panel.cacheDisplay(in: panel.bounds, to: bitmap)
      try require(bitmap.pixelsWide > 0, "Classic panel did not render")
      let scale = floor(min(width / Double(graphics.width), (240 - 22) / Double(graphics.height)))
      let left = (width - Double(graphics.width) * scale) / 2
      let ratio = Double(bitmap.pixelsWide) / width
      var heights: [Int] = []
      for index in 0..<8 {
        let x0 = Int((left + Double(index + 2) * 16 * scale) * ratio)
        let x1 = Int((left + Double(index + 3) * 16 * scale) * ratio)
        let y0 = Int(10 * scale * ratio), y1 = Int(15 * scale * ratio)
        var rows = Set<Int>()
        for y in y0..<y1 { for x in x0..<x1 {
          guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
          if color.blueComponent > 0.4 || color.greenComponent > 0.5 { rows.insert(y) }
        } }
        for y in y0..<y1 {
          for x in [x0, x1 - 1] {
            let color = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
            try require(color.blueComponent < 0.4 && color.greenComponent < 0.5,
              "Skill label touched its neighbouring cell at \(width)")
          }
        }
        heights.append(rows.count)
      }
      try require(heights.allSatisfy { $0 > 0 } && Set(heights).count == 1,
        "Skill labels changed size across the row at \(width): \(heights)")
      var chosen: PanelButton?
      panel.onButton = { chosen = $0 }
      for index in 0..<8 {
        chosen = nil
        panel.handlePointerDown(at: CGPoint(x: left + Double(index + 2) * 16 * scale + 8 * scale,
                                            y: 28 * scale), time: Double(index + 1))
        panel.handlePointerUp()
        try require(chosen == .skill(index), "Skill label/button target changed at \(width)")
      }
      if !fast {
        try bitmap.representation(using: .png, properties: [:])!.write(
          to: labelOutput.appendingPathComponent("panel-\(Int(width)).png"))
      }

    }
  }
  func captureControlState(_ name: String) throws {
    let bitmap = panel.bitmapImageRepForCachingDisplay(in: panel.bounds)!
    panel.cacheDisplay(in: panel.bounds, to: bitmap)
    try bitmap.representation(using: .png, properties: [:])!.write(
      to: labelOutput.appendingPathComponent(name + ".png"))
  }
  panel.setFrameSize(NSSize(width: 960, height: 160))
  panel.isPaused = true
  try captureControlState("panel-paused")
  try require(PanelGlyph.forButton(.pause, isPaused: true) == .play, "Paused panel lost its Resume symbol")
  panel.isPaused = false
  let mac = panel.macArtwork
  panel.macArtwork = nil
  try captureControlState("panel-dos")
  panel.macArtwork = mac
  let session = panel.session as! ClassicSession
  for _ in 0..<120 { session.tick() }
  let original = ClassicDOSReplayRecorder.stateHash(of: session.simulation)
  let tick = session.currentTick
  panel.setFrameSize(NSSize(width: 320, height: 40))
  panel.cacheDisplay(in: panel.bounds, to: panel.bitmapImageRepForCachingDisplay(in: panel.bounds)!)
  panel.onButton = { button in
    if button == .nuke {
      if session.canUndoNuke { session.undoNuke() } else { session.nuke() }
    }
  }
  let nuke = CGPoint(x:11*16+8,y:28), gap = NSEvent.doubleClickInterval/3
  panel.handlePointerDown(at:nuke,time:1)
  panel.handlePointerUp()
  try require(!session.isNuking, "a single panel click activated nuke")
  panel.handlePointerDown(at:nuke,time:1+gap)
  panel.handlePointerUp()
  try require(session.isNuking && session.canUndoNuke, "double-click did not start an undoable nuke")
  try captureControlState("panel-undo-nuke")
  try require(PanelGlyph.forButton(.nuke, isPaused: false, canUndoNuke: session.canUndoNuke) == .undo, "Nuke undo lost its reversible symbol")
  for _ in 0..<200 { session.tick() }
  panel.handlePointerDown(at:nuke,time:10)
  panel.handlePointerUp()
  try require(session.canUndoNuke && session.currentTick != tick, "single click undid nuke")
  panel.handlePointerDown(at:nuke,time:10+gap)
  panel.handlePointerUp()
  try require(session.currentTick == tick && ClassicDOSReplayRecorder.stateHash(of:session.simulation) == original,
    "double-click undo did not restore the exact pre-nuke game")
  try require(!session.isNuking && !session.canUndoNuke, "double-click did not undo nuke")
  var control = session.simulation
  for _ in 0..<100 { session.tick(); _ = control.tick() }
  try require(ClassicDOSReplayRecorder.stateHash(of:session.simulation) == ClassicDOSReplayRecorder.stateHash(of:control),
    "the undone nuke remained in replay history")
  print("PASS real panel double-click activation, double-click undo and exact restored history")
}

@MainActor private func testNukeGesturesAndQueuedUndo() throws {
  var gesture = NukeClickGesture()
  try require(gesture.click(canUndo:false,time:1,interval:0.5) == .none, "first click activated")
  try require(gesture.click(canUndo:false,time:2,interval:0.5) == .none, "slow clicks activated")
  try require(gesture.click(canUndo:false,time:2.2,interval:0.5) == .activate, "double-click failed")
  try require(gesture.click(canUndo:true,time:2.3,interval:0.5) == .none, "third click undid nuke")
  try require(gesture.click(canUndo:true,time:2.4,interval:0.5) == .undo, "second double-click did not undo")
  try require(gesture.click(canUndo:false,time:2.5,interval:0.5) == .none, "extra undo click armed nuke")
  try require(gesture.armedAt == nil, "undo left an armed click")
  try require(gesture.click(canUndo:false,time:4,interval:0.5) == .none, "new gesture activated immediately")
  try require(gesture.click(canUndo:false,time:4.2,interval:0.5) == .activate, "new double-click failed")
  try require(gesture.click(canUndo:true,time:5,interval:0.5) == .none, "first undo click restored game")
  try require(gesture.click(canUndo:true,time:6,interval:0.5) == .none, "slow undo clicks restored game")
  gesture.reset()
  try require(gesture.click(canUndo:true,time:6.1,interval:0.5) == .none, "reset preserved armed undo")
  try require(gesture.click(canUndo:true,time:6.2,interval:0.5) == .undo, "fresh undo double-click failed")
  let terrain = try NeoLemmixTerrain(width:64,height:64)
  let configuration = try NeoLemmixConfiguration(totalLemmings:2,requiredToSave:1,spawnInterval:20,
    entrances:[.init(id:0,position:.init(x:20,y:10))])
  let initial = try NeoLemmixSimulation(terrain:terrain,configuration:configuration)
  let neo = NeoLemmixSession(simulation:initial,width:64,height:64)
  neo.nuke()
  try require(neo.canUndoNuke, "queued nuke cannot be undone before its first tick")
  neo.undoNuke()
  try require(neo.simulation == initial, "queued nuke survived undo")
  neo.nuke()
  for _ in 0..<100 { neo.tick() }
  neo.undoNuke()
  try require(neo.simulation == initial, "NeoLemmix undo did not restore full state")
  for tick in 0..<4 { try require(PlayfieldView.bombPopIsVisible(tick:tick), "flash ended too early") }
  for tick in [4,5,17,50,51] { try require(!PlayfieldView.bombPopIsVisible(tick:tick), "explosion lingered") }
  print("PASS nuke gesture boundaries, queued undo and abrupt four-tick bomb pop")
}

@MainActor private func testSpeedAfterimages() throws {
  let trails = SpeedTrails()
  let bounds = CGRect(x: 0, y: 0, width: 640, height: 360)
  let playfield = CGRect(x: 20, y: 20, width: 600, height: 280)
  let bitmap = CGContext(data: nil, width: 640, height: 360, bitsPerComponent: 8,
    bytesPerRow: 640 * 4, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  bitmap.translateBy(x: 0, y: 360)
  bitmap.scaleBy(x: 1, y: -1)
  NSGraphicsContext.saveGraphicsState()
  defer { NSGraphicsContext.restoreGraphicsState() }
  NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmap, flipped: true)
  let originalContext = NSGraphicsContext.current!
  let sprite = CGRect(x: 292, y: 120, width: 16, height: 20)
  let source = CGContext(data: nil, width: 8, height: 10, bitsPerComponent: 8,
    bytesPerRow: 32, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  source.setFillColor(red: 0, green: 1, blue: 0, alpha: 1)
  source.fill(CGRect(x: 2, y: 0, width: 4, height: 10))
  let image = NSImage(cgImage: source.makeImage()!, size: CGSize(width: 8, height: 10))
  func render(tick: Int, enabled: Bool, left: Bool = false, showActor: Bool = true) throws -> [UInt8] {
    bitmap.clear(bounds)
    var calls = 0
    trails.draw(enabled: enabled, in: playfield) {
      calls += 1
      if showActor {
        trails.drawBehind(actor: 0, sprite: image, in: sprite,
          motion: CGVector(dx: left ? -1 : 1, dy: 0), pixelSize: CGSize(width: 2, height: 2))
        image.draw(in: sprite, from: .zero, operation: .sourceOver, fraction: 1,
          respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
      }
    }
    try require(calls == 1 && NSGraphicsContext.current === originalContext,
      "fast-forward redirected or repeated the normal draw pass")
    return Array(UnsafeBufferPointer(start: bitmap.data!.assumingMemoryBound(to: UInt8.self), count: 640 * 360 * 4))
  }
  let normal = try render(tick: 4, enabled: false)
  try require(normal[(130 * 640 + 300) * 4 + 3] == 255,
    "the test bitmap's rows do not match view coordinates")
  let fast = try render(tick: 4, enabled: true)
  try require(fast != normal && trails.drawnTrailCount == 1, "fast-forward has no afterimages")
  // Opaque sprite pixels must remain byte-for-byte identical at fast speed.
  for index in stride(from: 0, to: normal.count, by: 4) where normal[index + 3] != 0 {
    try require(normal[index..<index + 4] == fast[index..<index + 4], "afterimages changed a sprite pixel")
  }
  var tailPixels = 0, energyPixels = 0, farTailPixels = 0
  var peakAlpha: UInt8 = 0
  for index in stride(from: 0, to: fast.count, by: 4) where normal[index + 3] == 0 && fast[index + 3] > 0 {
    tailPixels += 1
    peakAlpha = max(peakAlpha,fast[index+3])
    if fast[index+2] > 4 { energyPixels += 1 }
    if (index/4)%640 < Int(sprite.minX)-10 { farTailPixels += 1 }
    try require(fast[index+3] <= 192, "the energy wake became opaque")
  }
  // The tapering wake was removed on purpose. Ghosting alone carries the speed,
  // so the contract is: afterimages exist, they trail behind the sprite, they
  // are visible, and they never become opaque enough to hide the terrain.
  try require(tailPixels > 0 && farTailPixels > 0 && energyPixels > 0 && peakAlpha > 40,
    "super speed lost its trailing afterimages")
  let repeated = try render(tick: 4, enabled: true)
  try require(repeated == fast, "redrawing one tick changed the afterimages")
  let left = try render(tick: 4, enabled: true, left: true)
  try require(left != fast, "afterimages did not follow direction")
  bitmap.clear(bounds)
  trails.draw(enabled: true, in: playfield) {
    trails.drawBehind(actor: 0, sprite: image, in: sprite, motion: CGVector(dx: 0, dy: 1),
      pixelSize: CGSize(width: 2, height: 2))
  }
  let vertical = Array(UnsafeBufferPointer(start: bitmap.data!.assumingMemoryBound(to: UInt8.self), count: fast.count))
  try require(vertical != fast && trails.drawnTrailCount == 1, "falling actors did not leave a vertical tail")
  for motion in [CGVector(dx: 3, dy: 1), CGVector(dx: 3, dy: -1),
    CGVector(dx: -3, dy: 1), CGVector(dx: -1, dy: -3)] {
    bitmap.clear(bounds)
    trails.draw(enabled: true, in: playfield) {
      trails.drawBehind(actor: 0, sprite: image, in: sprite, motion: motion,
        pixelSize: CGSize(width: 2, height: 2))
    }
    let pixels = bitmap.data!.assumingMemoryBound(to: UInt8.self)
    var total: CGFloat = 0, weightedX: CGFloat = 0, weightedY: CGFloat = 0
    for y in 0..<360 { for x in 0..<640 {
      let alpha = CGFloat(pixels[(y * 640 + x) * 4 + 3])
      total += alpha; weightedX += (CGFloat(x) + 0.5) * alpha; weightedY += (CGFloat(y) + 0.5) * alpha
    } }
    try require(total > 0, "the diagonal ghost disappeared")
    let dx = weightedX / total - sprite.midX, dy = weightedY / total - sprite.midY
    let dot = dx * motion.dx + dy * motion.dy
    let cross = dx * motion.dy - dy * motion.dx
    try require(dot < 0 && abs(cross / dot) < 0.2,
      "the ghost did not follow the shallow diagonal: \(motion), offset \(dx),\(dy)")
  }
  let rewound = try render(tick: 4, enabled: true)
  try require(rewound == fast, "rewinding retained a previous effect")
  let paused = try render(tick: 8, enabled: false)
  try require(paused == normal, "pause or normal speed retained trails")
  let empty = try render(tick: 9, enabled: true, showActor: false)
  try require(empty.allSatisfy { $0 == 0 },
    "an absent actor left a ghost frame")
  bitmap.clear(bounds)
  trails.draw(enabled: true, in: playfield) {
    for id in 0..<1000 {
      trails.drawBehind(actor: id, sprite: image, in: sprite.offsetBy(dx: -1000, dy: 0),
        motion: CGVector(dx: 1, dy: 0), pixelSize: CGSize(width: 2, height: 2))
    }
  }
  try require(trails.drawnTrailCount == 0, "offscreen actors used the effect budget")
  trails.draw(enabled: true, in: playfield) {
    for id in 0..<1000 {
      trails.drawBehind(actor: id, sprite: image, in: sprite,
        motion: CGVector(dx: 1, dy: 0), pixelSize: CGSize(width: 2, height: 2))
    }
  }
  try require(trails.drawnTrailCount == 1, "a dense crowd stacked afterimages in one cell")
  trails.draw(enabled: true, in: playfield) {
    for id in 0..<1000 {
      let point = CGPoint(x: 21 + CGFloat(id % 16) * 37.5, y: 21 + CGFloat(id / 16 % 4) * 70)
      trails.drawBehind(actor: id, sprite: image,
        in: CGRect(x: point.x, y: point.y, width: 16, height: 20),
        motion: CGVector(dx: id % 2 == 0 ? -1 : 1, dy: 0), pixelSize: CGSize(width: 2, height: 2))
    }
  }
  try require(trails.drawnTrailCount == SpeedTrails.maximumTrails, "the crowd effect exceeded its fixed budget")
  let bytes = bitmap.data!.assumingMemoryBound(to: UInt8.self)
  for y in 0..<360 { for x in 0..<640 where !playfield.contains(CGPoint(x: x, y: y)) {
    try require(bytes[(y * 640 + x) * 4 + 3] == 0, "afterimages painted outside the playfield at \(x),\(y)")
  } }
  trails.reset()
  try require(trails.drawnTrailCount == 0, "reset retained the previous frame")
  func measured(tick: Int, x: Int, y: Int, enabled: Bool = true) -> CGVector {
    trails.update(tick: tick, enabled: enabled, actors: [.init(id: 1, position: CGPoint(x: x, y: y))])
    return trails.motion(actor: 1)
  }
  try require(measured(tick: 20, x: 100, y: 100) == .zero, "a new actor guessed a direction")
  try require(measured(tick: 22, x: 106, y: 98) == CGVector(dx: 3, dy: -1), "uphill movement lost its slope")
  try require(measured(tick: 22, x: 106, y: 98) == CGVector(dx: 3, dy: -1), "a redraw lost its motion")
  try require(measured(tick: 23, x: 106, y: 98) == .zero, "a stationary actor retained a ghost")
  try require(measured(tick: 24, x: 104, y: 101) == CGVector(dx: -2, dy: 3), "a reversal retained the old direction")
  try require(measured(tick: 25, x: 1000, y: 100) == .zero, "a teleport produced a trail")
  try require(measured(tick: 21, x: 103, y: 99) == .zero, "rewinding reused future movement")
  _ = measured(tick: 22, x: 106, y: 98, enabled: false)
  try require(measured(tick: 23, x: 109, y: 97) == .zero, "normal speed retained movement history")
  trails.update(tick: 24, enabled: true, actors: [])
  try require(measured(tick: 25, x: 115, y: 95) == .zero, "a removed actor retained movement history")
  print("PASS speed afterimages: sharp sprites, direct draw, direction, pause, rewind, clipping and bounded crowd cost")
}

@MainActor private func testTickDirectionContinuity() throws {
  let trails = SpeedTrails()
  var position = CGPoint(x: 100, y: 100)
  func sample(_ tick: Int, dx: CGFloat, dy: CGFloat, movement: String = "walking") -> CGVector {
    position.x += dx; position.y += dy
    trails.update(tick: tick, enabled: true, actors: [.init(id: 1, position: position, movement: movement)])
    return trails.motion(actor: 1)
  }
  _ = sample(0, dx: 0, dy: 0)
  _ = sample(1, dx: 3, dy: -1)
  _ = sample(2, dx: 3, dy: 0)
  let uphill = sample(3, dx: 3, dy: -1)
  let angle = trails.direction(actor: 1)
  let next = sample(4, dx: 3, dy: 0)
  try require(trails.direction(actor: 1) == angle, "The cached trail angle flickered across a shallow slope")
  try require(uphill.dx > 0 && uphill.dy < 0 && next.dx > 0 && next.dy < 0,
    "Pixel stair steps made the ghosts alternate between horizontal and uphill")
  let left = sample(5, dx: -3, dy: 0)
  try require(left == CGVector(dx: -3, dy: 0) && trails.direction(actor: 1) == 8, "Smoothing delayed a direction reversal")
  let fall = sample(6, dx: 0, dy: 3, movement: "falling")
  try require(fall == CGVector(dx: 0, dy: 3), "Falling retained a horizontal wake")
  let climb = sample(7, dx: 0, dy: -2, movement: "climbing")
  try require(climb == CGVector(dx: 0, dy: -2), "Climbing retained the falling direction")
  for _ in 0..<20 {
    trails.update(tick: 7, enabled: true, actors: [.init(id: 1, position: position, movement: "climbing")])
    try require(trails.motion(actor: 1) == climb, "Repeated live or replay sampling changed a tick's direction")
  }
  trails.update(tick: 7, enabled: true, actors: [])
  try require(trails.motion(actor: 1) == .zero, "A skill assignment between ticks retained its old wake")
  _ = sample(8, dx: 0, dy: 0)
  try require(sample(9, dx: 0, dy: 0) == .zero, "A stopped actor retained motion")
  print("PASS tick-based direction: stable slopes, immediate turns, falls, climbs and repeated capture")
}

/// Mac artwork doubles the source image (`imageScale == 2`). A crop edge
/// that does not land on an even image pixel used to divide back into a
/// fractional point width once scaled by zoom, and nearest-neighbor
/// upscaling of a fractional destination samples source pixels unevenly.
/// That showed up as scrambled pixels on small, detailed objects such as
/// the entrance hatch, and worse at some zoom levels than others.
private func testMacArtworkCropStaysPixelAligned() throws {
  let imageScale: CGFloat = 2
  let imageSize = CGSize(width: 400, height: 40)
  // Sweep scroll positions (whole and fractional level pixels) and window
  // widths, so both even and odd image-pixel crop edges are exercised.
  for scrollX in stride(from: 0.0, through: 6.0, by: 0.5) {
    for viewWidth in [4.0, 5.0, 7.0, 12.0, 37.0] {
      for zoom in [1.0, 2.0, 3.0, 4.0] {
        let visibleWidth = viewWidth / zoom
        let visible = CGRect(
          x: scrollX * imageScale, y: 0,
          width: visibleWidth * imageScale, height: 8 * imageScale)
        let crop = PlayfieldView.levelCropRect(visible: visible, imageScale: imageScale, imageSize: imageSize)
        let context = "scrollX=\(scrollX) viewWidth=\(viewWidth) zoom=\(zoom)"
        try require(crop.minX.truncatingRemainder(dividingBy: imageScale) == 0,
          "\(context): crop origin \(crop.minX) is not a whole level pixel")
        try require(crop.width.truncatingRemainder(dividingBy: imageScale) == 0,
          "\(context): crop width \(crop.width) is not a whole level pixel")
        let destinationWidth = crop.width * zoom / imageScale
        try require(destinationWidth.truncatingRemainder(dividingBy: 1) == 0,
          "\(context): destination width \(destinationWidth) is not a whole point, "
            + "so nearest-neighbor scaling would sample source pixels unevenly")
        try require(crop.minX >= 0 && crop.minX + crop.width <= imageSize.width,
          "\(context): crop \(crop) escaped the image bounds \(imageSize)")
      }
    }
  }
  // imageScale == 1 (DOS, no Mac artwork) must draw exactly the old crop.
  let visible = CGRect(x: 5.5, y: 0, width: 12.3, height: 8)
  let crop = PlayfieldView.levelCropRect(visible: visible, imageScale: 1, imageSize: CGSize(width: 400, height: 40))
  try require(crop == CGRect(x: 5, y: 0, width: 14, height: 9),
    "imageScale 1 changed its crop from the original floor/ceil-plus-one behavior: \(crop)")
  print("PASS Mac artwork level crop always lands on whole level pixels, at every zoom")
}

@MainActor private func testSpeedSpritesStayOnTop() throws {
  let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  let view = PlayfieldView(frame: CGRect(x: 0, y: 0, width: 640, height: 320))
  let session = BombPreviewSession()
  // Neighbours straddle effect cells so the later actor's ghost crosses the earlier sprite.
  session.actors = [159, 161, 179, 181].enumerated().map { index, x in
    SessionLemming(id: index, x: x, y: 80, pose: .walking, facingLeft: false,
      animationFrame: index * 2, countdown: nil)
  }
  view.session = session; view.phase = .playing; view.viewport.zoom = 2
  view.assets = try ClassicMainDATAssets.load(from: root.appendingPathComponent("Content/lemming1.pc"))
  view.palette = ClassicLemmingPalette.panelVGA
  view.levelImage = CGContext(data: nil, width: 320, height: 160, bitsPerComponent: 8,
    bytesPerRow: 1280, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()
  func render(fast: Bool) -> NSBitmapImageRep {
    view.isFastForward = fast
    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: bitmap)
    return bitmap
  }
  let normal = render(fast: false)
  let actors = session.actors!
  session.actors = actors.map { actor in
    SessionLemming(id: actor.id, x: actor.x - 3, y: actor.y + 1, pose: actor.pose,
      facingLeft: actor.facingLeft, animationFrame: actor.animationFrame, countdown: nil)
  }
  _ = render(fast: true)
  session.actors = actors; session.tick()
  let fast = render(fast: true)
  var spritePixels = 0, ghostPixels = 0
  for y in 0..<normal.pixelsHigh { for x in 0..<normal.pixelsWide {
    let original = normal.colorAt(x: x, y: y)!, updated = fast.colorAt(x: x, y: y)!
    if original.brightnessComponent > 0 {
      spritePixels += 1
      try require(original == updated, "a neighbouring ghost painted over a solid sprite at \(x),\(y)")
    } else if updated.brightnessComponent > 0 { ghostPixels += 1 }
  } }
  try require(spritePixels > 0 && ghostPixels > 0, "the overlap test did not draw both sprites and ghosts")
  view.hdEffectsEnabled = false
  let oldSchool = render(fast: true)
  try require(oldSchool.representation(using: .png, properties: [:]) == normal.representation(using: .png, properties: [:]),
    "Old-school speed mode retained ghost pixels")
  print("PASS every solid sprite stays above neighbouring additive ghosts")
}

@MainActor private func run() {
  let app = NSApplication.shared
  app.setActivationPolicy(.accessory)
  do {
    try testTickDirectionContinuity()
    try testMacArtworkCropStaysPixelAligned()
    try testSpeedSpritesStayOnTop()
    try testSpeedAfterimages()
    try testBombFlashFrames()
    try testNukeGesturesAndQueuedUndo()
    try testClassicPanelLabels()
    print("PASS Xmas panel labels at multiple sizes with speed control")
    try testCameraResize()
    print("PASS camera survives resizing and clears menu edge scrolling")
    try testMenuSurvivesThePanel()
    print("PASS a menu survives the panel drawn over it")
    try testPanelDrawsItself()
    print("PASS the panel still draws its own area")
    print("Playfield drawing tests passed.")
  } catch {
    FileHandle.standardError.write(Data("Playfield drawing tests failed: \(error)\n".utf8))
    exit(1)
  }
}

run()
