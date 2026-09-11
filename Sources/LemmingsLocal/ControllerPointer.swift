import AppKit

@MainActor enum ControllerPointer {
    static func draw(_ point: CGPoint?) {
        guard let point else { return }
        let path = NSBezierPath()
        path.move(to: CGPoint(x: point.x - 9, y: point.y)); path.line(to: CGPoint(x: point.x + 9, y: point.y))
        path.move(to: CGPoint(x: point.x, y: point.y - 9)); path.line(to: CGPoint(x: point.x, y: point.y + 9))
        NSColor.black.setStroke(); path.lineWidth = 4; path.stroke()
        NSColor.white.setStroke(); path.lineWidth = 2; path.stroke()
    }
}
