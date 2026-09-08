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
  let levelWidth = 320, levelHeight = 160, ticksPerSecond = 17
  var lemmings: [SessionLemming] {
    [.init(id:0,x:160,y:y,pose:.explosion,facingLeft:false,animationFrame:animationTick,countdown:nil)]
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
  let macRoot = root.appendingPathComponent(".build/local/Ultimate Lemmings.app/Contents/Resources/MacArtwork/lemmings")
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
  for width in [640.0, 960.0, 1920.0] {
    panel.setFrameSize(NSSize(width: width, height: 240))
    for fast in [false, true] {
      panel.isFastForward = fast
      let bitmap = panel.bitmapImageRepForCachingDisplay(in: panel.bounds)!
      panel.cacheDisplay(in: panel.bounds, to: bitmap)
      try require(bitmap.pixelsWide > 0, "Classic panel did not render")
    }
  }
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
  for _ in 0..<200 { session.tick() }
  panel.handlePointerDown(at:nuke,time:10)
  panel.handlePointerUp()
  try require(session.currentTick == tick && ClassicDOSReplayRecorder.stateHash(of:session.simulation) == original,
    "undo did not restore the exact pre-nuke game")
  panel.handlePointerDown(at:nuke,time:10+gap)
  panel.handlePointerUp()
  try require(!session.isNuking && !session.canUndoNuke, "second undo click reactivated nuke")
  var control = session.simulation
  for _ in 0..<100 { session.tick(); _ = control.tick() }
  try require(ClassicDOSReplayRecorder.stateHash(of:session.simulation) == ClassicDOSReplayRecorder.stateHash(of:control),
    "the undone nuke remained in replay history")
  print("PASS real panel double-click activation, single/double-click undo and exact restored history")
}

@MainActor private func testNukeGesturesAndQueuedUndo() throws {
  var gesture = NukeClickGesture()
  try require(gesture.click(canUndo:false,time:1,interval:0.5) == .none, "first click activated")
  try require(gesture.click(canUndo:false,time:2,interval:0.5) == .none, "slow clicks activated")
  try require(gesture.click(canUndo:false,time:2.2,interval:0.5) == .activate, "double-click failed")
  try require(gesture.click(canUndo:true,time:2.3,interval:0.5) == .undo, "single undo failed")
  try require(gesture.click(canUndo:false,time:2.4,interval:0.5) == .none, "undo's second click armed nuke")
  try require(gesture.armedAt == nil, "undo left an armed click")
  try require(gesture.click(canUndo:false,time:4,interval:0.5) == .none, "new gesture activated immediately")
  try require(gesture.click(canUndo:false,time:4.2,interval:0.5) == .activate, "new double-click failed")
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

@MainActor private func run() {
  let app = NSApplication.shared
  app.setActivationPolicy(.accessory)
  do {
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
