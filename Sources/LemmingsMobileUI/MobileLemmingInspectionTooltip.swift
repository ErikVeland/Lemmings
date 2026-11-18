#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import UIKit

/// Shows a Lemming's name and story without taking gameplay input.
@MainActor final class MobileLemmingInspectionTooltip: UIView {
    private let canvas = MobileMenuCanvas(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        canvas.isUserInteractionEnabled = false
        addSubview(canvas)
    }

    required init?(coder: NSCoder) { nil }

    func show(_ individual: LemmingInspection.Individual, in area: CGRect, near point: CGPoint) {
        let available = area.insetBy(dx: 12, dy: 12)
        guard available.width >= 280, available.height >= 140 else {
            isHidden = true
            return
        }

        let page = LemmingInspectionArt.hoverPage(individual)
        if canvas.page != page { canvas.page = page }
        let width = min(460, max(280, available.width * 0.44))
        let measured = canvas.size(width: width, minimumHeight: min(260, available.height))
        let size = CGSize(width: min(width, measured.width),
                          height: min(260, max(140, measured.height)))
        let x = point.x < available.midX ? available.maxX - size.width : available.minX
        let y = point.y < available.midY ? available.maxY - size.height : available.minY
        frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
        canvas.frame = bounds
        accessibilityLabel = ([page.title] + page.details).joined(separator: ", ")
        isHidden = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        canvas.frame = bounds
    }
}
#endif
