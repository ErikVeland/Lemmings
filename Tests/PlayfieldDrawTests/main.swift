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

@MainActor private func run() {
  let app = NSApplication.shared
  app.setActivationPolicy(.accessory)
  do {
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
