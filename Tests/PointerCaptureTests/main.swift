import AppKit

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { FileHandle.standardError.write(Data((message + "\n").utf8)); exit(1) }
}

// Simulate crossing onto displays on all sides. No test moves the system cursor.
for frame in [CGRect(x: 0, y: 0, width: 2560, height: 1440),
              CGRect(x: -1920, y: 280, width: 1920, height: 1080),
              CGRect(x: 2560, y: -900, width: 1440, height: 900),
              CGRect(x: 0, y: 1440, width: 1920, height: 1080)] {
    var capture = PointerConfinement()
    let centre = CGPoint(x: frame.midX, y: frame.midY)
    let outside = CGPoint(x: frame.minX - 300, y: frame.midY)
    check(capture.sample(outside, in: frame, active: true, releaseRequested: false) == nil,
          "Starting play pulled a pointer off another display")
    check(capture.sample(centre, in: frame, active: true, releaseRequested: false) == centre,
          "Entering the game failed to capture the pointer")
    for _ in 0..<120 {
        let edge = capture.sample(outside, in: frame, active: true, releaseRequested: false)
        check(edge == CGPoint(x: frame.minX + 1, y: frame.midY), "Repeated left scrolling escaped onto a neighbouring display")
    }
    for point in [CGPoint(x: frame.maxX + 500, y: frame.midY),
                  CGPoint(x: frame.midX, y: frame.minY - 500)] {
        let confined = capture.sample(point, in: frame, active: true, releaseRequested: false)!
        check(frame.contains(confined), "A right or bottom edge escaped")
    }
    check(capture.sample(CGPoint(x: frame.midX, y: frame.maxY - 1), in: frame,
                         active: true, releaseRequested: false) == nil && !capture.isCaptured,
          "The native menu-bar reveal edge retained pointer capture")
    for y in [frame.maxY + 10, frame.maxY, frame.maxY - 12, frame.maxY - 31] {
        check(capture.sample(CGPoint(x: frame.midX, y: y), in: frame,
                             active: true, releaseRequested: false) == nil && !capture.isCaptured,
              "The pointer rearmed inside the native menu strip")
    }
    let returned = CGPoint(x: frame.midX, y: frame.maxY - 32)
    check(capture.sample(returned, in: frame, active: true, releaseRequested: false) == returned
          && capture.isCaptured, "Returning inside the game failed to rearm capture")
    check(capture.sample(outside, in: frame, active: true, releaseRequested: true) == nil && !capture.isCaptured,
          "Holding Option failed to release capture")
    check(capture.sample(outside, in: frame, active: true, releaseRequested: false) == nil,
          "Releasing Option pulled the pointer back from another display")
    _ = capture.sample(centre, in: frame, active: true, releaseRequested: false)
    check(capture.sample(outside, in: frame, active: false, releaseRequested: false) == nil && !capture.isCaptured,
          "Focus loss or disabling capture failed to release it")
    _ = capture.sample(centre, in: frame, active: true, releaseRequested: false)
    let moved = frame.offsetBy(dx: frame.width * 2, dy: 0)
    check(capture.sample(centre, in: moved, active: true, releaseRequested: false) == nil,
          "Moving the window dragged the pointer across displays")
}
check(PointerConfinement.quartzPoint(CGPoint(x: -100, y: 500), primaryDisplayTop: 1440) == CGPoint(x: -100, y: 940),
      "A left display lost its negative X coordinate")
check(PointerConfinement.quartzPoint(CGPoint(x: 3000, y: -200), primaryDisplayTop: 1440) == CGPoint(x: 3000, y: 1640),
      "A lower display used the wrong Y axis")
check(PointerConfinement.quartzPoint(CGPoint(x: 100, y: 1600), primaryDisplayTop: 1440) == CGPoint(x: 100, y: -160),
      "An upper display used the wrong Y axis")
var capture = PointerConfinement()
check(capture.sample(.zero, in: .zero, active: true, releaseRequested: false) == nil, "An empty view captured the pointer")
// A window AppKit calls key and visible can still be off screen, e.g. while a
// full-screen transition stalls. Capture there traps the pointer in an empty rectangle.
let ready = PointerCaptureGate(appActive: true, windowKey: true, windowOrdered: true, onScreen: true,
                               miniaturized: false, viewHidden: false, liveResize: false, sheetAttached: false)
check(ready.allowsCapture, "A shown, focused game refused capture")
var offScreen = ready; offScreen.onScreen = false
check(!offScreen.allowsCapture, "An off-screen window captured the pointer")
var sheet = ready; sheet.sheetAttached = true
check(!sheet.allowsCapture, "A system sheet left the pointer captured")
var menu = ready; menu.menuTracking = true
check(!menu.allowsCapture, "A tracking native menu allowed pointer capture")
var background = ready; background.appActive = false
check(!background.allowsCapture, "A background app captured the pointer")
print("PASS pointer capture: sustained side/bottom edges, top-edge menu access, 32-point reacquisition, four display positions, Option/focus/resize gates and Quartz coordinates")

// Supply window state and pointer samples without activating or warping a desktop window.
private final class PointerTestApplication: NSApplication {
    override var isActive: Bool { true }
}

private final class PointerTestWindow: NSWindow {
    override var isKeyWindow: Bool { true }
    override var isVisible: Bool { true }
    override var occlusionState: NSWindow.OcclusionState { [.visible] }
    override var screen: NSScreen? { NSScreen.screens.first }
    private var testOrigin: CGPoint {
        CGPoint(x: (screen?.frame.minX ?? 0) + 100, y: (screen?.frame.minY ?? 0) + 100)
    }
    override func convertToScreen(_ rect: NSRect) -> NSRect {
        rect.offsetBy(dx: testOrigin.x, dy: testOrigin.y)
    }
    override func convertPoint(fromScreen point: NSPoint) -> NSPoint {
        CGPoint(x: point.x - testOrigin.x, y: point.y - testOrigin.y)
    }
}

@MainActor private func testNativeMenuTracking() {
    _ = PointerTestApplication.shared
    guard let screen = NSScreen.screens.first else {
        FileHandle.standardError.write(Data("Native pointer tests need logged-in desktop display access.\n".utf8))
        exit(2)
    }
    let window = PointerTestWindow(contentRect: CGRect(x: 0, y: 0, width: 400, height: 300),
                                   styleMask: [], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    defer { window.close() }
    let view = window.contentView!
    var point = CGPoint(x: screen.frame.minX + 300, y: screen.frame.minY + 250)
    var warps: [CGPoint] = []
    let pointer = GamePointerCapture(readPosition: { point }, warpPosition: { warps.append($0); return .success })
    check(pointer.update(in: view, active: true) == CGPoint(x: 200, y: 150) && pointer.isCaptured,
          "The deterministic native window did not acquire its injected pointer")
    point.y = screen.frame.minY + 399
    check(pointer.update(in: view, active: true) == nil && !pointer.isCaptured,
          "The native adapter warped its top-edge sample away from macOS")
    point.y = screen.frame.minY + 388
    for _ in 0..<120 {
        check(pointer.update(in: view, active: true) == nil && !pointer.isCaptured,
              "The native adapter recaptured inside the revealed menu strip")
    }
    point.y = screen.frame.minY + 250
    check(pointer.update(in: view, active: true) == CGPoint(x: 200, y: 150) && pointer.isCaptured,
          "The native adapter failed to rearm after returning from the top edge")
    let main = NSMenu(title: "Test main menu")
    let submenu = NSMenu(title: "Test submenu")
    NotificationCenter.default.post(name: NSMenu.didBeginTrackingNotification, object: main)
    check(!pointer.isCaptured, "Opening a native menu failed to release capture")
    for _ in 0..<120 {
        check(pointer.update(in: view, active: true) == nil && !pointer.isCaptured,
              "A later frame recaptured the pointer while a native menu was tracking")
    }
    NotificationCenter.default.post(name: NSMenu.didBeginTrackingNotification, object: submenu)
    NotificationCenter.default.post(name: NSMenu.didEndTrackingNotification, object: submenu)
    check(pointer.update(in: view, active: true) == nil && !pointer.isCaptured,
          "Closing a submenu recaptured the pointer before its parent menu closed")
    NotificationCenter.default.post(name: NSMenu.didEndTrackingNotification, object: main)
    check(pointer.update(in: view, active: true) == CGPoint(x: 200, y: 150) && pointer.isCaptured,
          "Closing the final native menu failed to restore normal acquisition")
    check(warps.isEmpty, "A native menu test requested an unexpected system-cursor warp")
    print("PASS native menu tracking: sustained release, nested menus, final reacquisition; no cursor warps or desktop activation")
}

MainActor.assumeIsolated { testNativeMenuTracking() }
