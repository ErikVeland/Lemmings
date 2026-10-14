#if os(iOS) || os(tvOS)
import LemmingsGameArt
import NxlvKit
import LemmingsMobileCore
import UIKit

@MainActor final class MobileReplayTitleView: UIView {
    private var artworkScale: CGFloat {
        #if os(tvOS)
        2
        #else
        1
        #endif
    }
    var level: MobileLevelSummary? {
        didSet {
            isHidden = level == nil
            accessibilityLabel = level.map { L10n.text("Replay, \($0.locationLabel), \($0.title)") }
            setNeedsDisplay()
        }
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        isHidden = true
    }
    required init?(coder: NSCoder) { nil }
    func position(in area: CGRect) {
        guard let level else { return }
        let scale = artworkScale
        let size = MobileReplayTitleArt.size(level: level, width: min(600, max(44, (area.width - 16) / scale)))
        frame = CGRect(x: area.minX + 8, y: area.minY + 8, width: size.width * scale, height: size.height * scale)
    }
    override func draw(_ rect: CGRect) {
        guard let level, let context = UIGraphicsGetCurrentContext() else { return }
        context.scaleBy(x: artworkScale, y: artworkScale)
        MobileReplayTitleArt.draw(level: level, in: CGRect(x: 0, y: 0, width: bounds.width / artworkScale,
            height: bounds.height / artworkScale), typography: MobileGameArt.typography, context: context)
    }
}
#endif
