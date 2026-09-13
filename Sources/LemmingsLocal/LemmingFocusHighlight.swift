import AppKit

@MainActor final class LemmingFocusHighlight {
    private var notice: String?
    private var noticeUntil: TimeInterval = 0
    func showNotice(_ text: String) { notice = text; noticeUntil = ProcessInfo.processInfo.systemUptime + 2 }
    func drawNotice() {
        guard let notice, ProcessInfo.processInfo.systemUptime < noticeUntil else { return }
        GameTypography.annotation(notice, at: CGPoint(x: 12, y: 12))
    }
    private var id: Int?
    private var until: TimeInterval = 0
    var target: Int? { ProcessInfo.processInfo.systemUptime < until ? id : nil }
    func show(_ id: Int) { self.id = id; until = ProcessInfo.processInfo.systemUptime + 2 }
    func clear() { id = nil }
    func draw(at point: CGPoint, scale: CGFloat) {
        guard target != nil else { return }
        NSColor.systemYellow.setStroke()
        let ring = NSBezierPath(ovalIn: CGRect(x: point.x - 9 * scale, y: point.y - 9 * scale, width: 18 * scale, height: 18 * scale))
        ring.lineWidth = max(2, scale)
        ring.stroke()
    }
}
