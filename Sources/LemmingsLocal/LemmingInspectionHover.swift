#if os(macOS)
import AppKit
import LemmingsAppCore
import LemmingsGameArt
import NxlvKit

/// Paused details stay outside the pointer and never receive gameplay input.
@MainActor final class LemmingInspectionHover: NSView {
    private let nameLabel = GameLabel(wrappingLabelWithString: "")
    private let detailLabel = GameLabel(wrappingLabelWithString: "")
    private var displayed: LemmingInspection.Individual?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override init(frame: NSRect) {
        super.init(frame: frame)
        nameLabel.role = .heading
        nameLabel.alignment = .left; detailLabel.alignment = .left
        addSubview(nameLabel); addSubview(detailLabel)
        setAccessibilityRole(.group)
        isHidden = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func show(_ individual: LemmingInspection.Individual, in root: NSView, area: CGRect, pointer: CGPoint) {
        let available = area.intersection(root.bounds).insetBy(dx: 12, dy: 12)
        guard available.width >= 240, available.height >= 160 else { isHidden = true; return }
        let width = min(360, floor(available.width * 0.48))
        var recent = Array(individual.actions.suffix(3).map(\.text))
        let nameHeight = max(24, GameTextLayout.height(individual.title, width: width - 24))
        func detailText() -> String {
            ([individual.preference, individual.want, individual.status]
                + (recent.isEmpty ? [] : [L10n.text("Recent actions")] + recent)).joined(separator: "\n")
        }
        var detail = detailText()
        var height = nameHeight + max(24, GameTextLayout.height(detail, width: width - 24)) + 36
        while height > available.height && recent.count > 1 {
            recent.removeFirst(); detail = detailText()
            height = nameHeight + max(24, GameTextLayout.height(detail, width: width - 24)) + 36
        }
        guard height <= available.height else { isHidden = true; return }
        nameLabel.stringValue = individual.title; detailLabel.stringValue = detail
        let x = pointer.x < available.midX ? available.maxX - width : available.minX
        let y = root.isFlipped ? available.maxY - height : available.minY
        frame = CGRect(x: x, y: y, width: width, height: height)
        nameLabel.frame = CGRect(x: 12, y: 12, width: width - 24, height: nameHeight)
        detailLabel.frame = CGRect(x: 12, y: nameHeight + 20, width: width - 24, height: max(0, height - nameHeight - 32))
        if superview !== root { removeFromSuperview(); root.addSubview(self) }
        isHidden = false
        if displayed != individual || detailLabel.accessibilityLabel() != detail {
            displayed = individual
            nameLabel.setAccessibilityLabel(individual.title)
            detailLabel.setAccessibilityLabel(detail)
            nameLabel.needsDisplay = true; detailLabel.needsDisplay = true; needsDisplay = true
            NSAccessibility.post(element: nameLabel, notification: .valueChanged)
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        GameStyle.fill(bounds, .black)
        GameMenuFrame.draw(bounds)
    }

    /// Inspection picks visible feet without skill eligibility or assignment bias.
    static func nearestID(at point: CGPoint, actors: [(id: Int, x: Int, y: Int)]) -> Int? {
        actors.filter {
            abs(CGFloat($0.x) - point.x) <= 6 && point.y >= CGFloat($0.y - 14) && point.y <= CGFloat($0.y + 5)
        }.min {
            let a = hypot(CGFloat($0.x) - point.x, CGFloat($0.y) - point.y)
            let b = hypot(CGFloat($1.x) - point.x, CGFloat($1.y) - point.y)
            return a == b ? $0.id < $1.id : a < b
        }?.id
    }
}
#endif
