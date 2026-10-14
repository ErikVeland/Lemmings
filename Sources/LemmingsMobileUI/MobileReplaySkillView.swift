#if os(iOS) || os(tvOS)
import LemmingsGameArt
import NxlvKit
import LemmingsMobileCore
import UIKit

@MainActor final class MobileReplaySkillView: UIView {
    private var uses: [MobileReplaySkillUse] = []
    private var tick = 0
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear; isOpaque = false
        isUserInteractionEnabled = false; isAccessibilityElement = true
        accessibilityTraits = .staticText; isHidden = true
    }
    required init?(coder: NSCoder) { nil }
    func update(_ uses: [MobileReplaySkillUse], tick: Int, visible: Bool) {
        isHidden = !visible || uses.isEmpty
        guard self.uses != uses || self.tick != tick else { return }
        self.uses = uses; self.tick = tick
        accessibilityLabel = L10n.text("Skills used: ") + uses.map { L10n.text("\($0.name) at tick \($0.tick)") }.joined(separator: ", ")
        setNeedsDisplay()
    }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        MobileReplaySkillArt.draw(uses: uses, tick: tick, in: bounds,
            typography: MobileGameArt.typography, context: context)
    }
}
#endif
