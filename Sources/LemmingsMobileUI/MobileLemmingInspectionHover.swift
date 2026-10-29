#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import UIKit

/// Passive paused inspection; the pointer and gameplay keep every input target.
@MainActor final class MobileLemmingInspectionHover: UIView {
    private var title = ""
    private var story = ""
    private var titleBox = CGRect.zero
    private var storyBox = CGRect.zero
    private var textScale = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isOpaque = true
        isHidden = true
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { nil }

    func show(_ individual: LemmingInspection.Individual, area: CGRect, pointer: CGPoint) {
        let nextStory = [individual.preference, individual.want].joined(separator: "\n")
        #if os(tvOS)
        let scale = area.width >= 1224 ? 2 : 1
        #else
        let scale = 1
        #endif
        guard let layout = LemmingInspectionHoverArt.layout(title: individual.title, story: nextStory,
            area: area, pointer: pointer, scale: scale, typography: MobileGameArt.typography) else {
            isHidden = true
            return
        }
        frame = layout.frame
        titleBox = layout.title
        storyBox = layout.story
        textScale = scale
        title = individual.title
        story = nextStory
        accessibilityLabel = [title, story].joined(separator: "\n")
        isHidden = false
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), let typography = MobileGameArt.typography else { return }
        LemmingInspectionHoverArt.draw(title: title, story: story, bounds: bounds,
            titleBox: titleBox, storyBox: storyBox, scale: textScale,
            typography: typography, context: context)
    }
}
#endif
