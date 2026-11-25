#if os(iOS) || os(tvOS)
import LemmingsGameArt
import NxlvKit
import LemmingsMobileCore
import UIKit

@MainActor final class MobileReplaySkillView: UIView {
    private var uses: [MobileReplaySkillUse] = []
    private var tick = 0
    private var rate: Double?
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear; isOpaque = false
        isUserInteractionEnabled = false; isAccessibilityElement = true
        accessibilityTraits = .staticText; isHidden = true
    }
    required init?(coder: NSCoder) { nil }
    func update(_ uses: [MobileReplaySkillUse], tick: Int, rate: Double, visible: Bool) {
        isHidden = !visible || uses.isEmpty || bounds.isEmpty
        let historyChanged = self.uses != uses || self.rate != rate
        let highlightChanged = self.tick != tick && uses.contains { $0.tick == self.tick || $0.tick == tick }
        self.tick = tick
        if historyChanged {
            self.uses = uses; self.rate = rate
            let history = uses.suffix(3).map { ReplayGameTime.skillUse($0.name, tick: $0.tick, rate: rate) }
            accessibilityLabel = history.isEmpty ? nil : L10n.text("Skills used: \(history.joined(separator: ", "))")
        }
        if historyChanged || highlightChanged { setNeedsDisplay() }
    }
    override func draw(_ rect: CGRect) {
        guard let rate, let context = UIGraphicsGetCurrentContext() else { return }
        MobileReplaySkillArt.draw(uses: uses, tick: tick, rate: rate, in: bounds,
            typography: MobileGameArt.typography, context: context)
    }
}
#endif
