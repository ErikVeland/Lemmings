import AppKit

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
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
                  CGPoint(x: frame.midX, y: frame.maxY + 500),
                  CGPoint(x: frame.midX, y: frame.minY - 500)] {
        let confined = capture.sample(point, in: frame, active: true, releaseRequested: false)!
        check(frame.contains(confined), "A right, top or bottom edge escaped")
    }
    check(capture.sample(outside, in: frame, active: true, releaseRequested: true) == nil && !capture.isCaptured,
          "Holding Option failed to release capture")
    check(capture.sample(outside, in: frame, active: true, releaseRequested: false) == nil,
          "Releasing Option pulled the pointer back from another display")
    _ = capture.sample(centre, in: frame, active: true, releaseRequested: false)
    check(capture.sample(outside, in: frame, active: false, releaseRequested: false) == nil && !capture.isCaptured,
          "Pause, menus, focus loss or disabling capture failed to release it")
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
print("PASS pointer capture: sustained edges, four display positions, release, reacquisition, moved windows and Quartz coordinates")
