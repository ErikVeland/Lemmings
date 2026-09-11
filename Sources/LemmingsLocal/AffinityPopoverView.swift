import AppKit
import NxlvKit

@MainActor final class AffinityPopoverView: NSView {
    private let affinity: TrolleyArchetype
    private let font: MacInterfaceRenderer?
    private let forRun: Bool
    override var isFlipped: Bool { true }
    init(affinity: TrolleyArchetype, font: MacInterfaceRenderer?, forRun: Bool) {
        self.affinity = affinity; self.font = font; self.forRun = forRun
        super.init(frame: CGRect(x: 0, y: 0, width: 480, height: 334))
        setAccessibilityElement(true)
        setAccessibilityLabel("\(affinity.name). \(affinity.philosophySummary) \(forRun ? "This run" : "Play style"): \(affinity.affinityDescription)")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func draw(_ dirtyRect: NSRect) {
        GameStyle.fill(bounds, .black)
        let heading = CGRect(x: 24, y: 22, width: 432, height: 24)
        let summary = CGRect(x: 24, y: 66, width: 432, height: 130)
        let label = CGRect(x: 24, y: 218, width: 432, height: 20)
        let reason = CGRect(x: 24, y: 254, width: 432, height: 66)
        GameStyle.fill(CGRect(x: 24, y: 202, width: 432, height: 1), GameStyle.muted.withAlphaComponent(0.3))
        if let font {
            let face: ClassicMacUserInterface.Face = font.width(of: MacInterfaceRenderer.menuText(affinity.name), face: .large, scale: 1) <= heading.width ? .large : .small
            font.menuLine(affinity.name, in: heading, face: face, alignment: .left)
            font.menuParagraph(affinity.philosophySummary, in: summary, alignment: .left)
            font.menuLine(forRun ? "This run" : "Play style", in: label, alignment: .left, alpha: 0.7)
            font.menuParagraph(affinity.affinityDescription, in: reason, alignment: .left)
        } else {
            GamePixelText.draw(affinity.name, in: heading)
            GamePixelText.draw(affinity.philosophySummary, in: summary)
            GamePixelText.draw(forRun ? "This run" : "Play style", in: label)
            GamePixelText.draw(affinity.affinityDescription, in: reason)
        }
    }
}
