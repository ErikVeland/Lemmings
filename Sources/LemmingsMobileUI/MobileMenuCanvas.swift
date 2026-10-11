#if os(iOS)
import LemmingsGameArt
import UIKit

/// The artwork and UIKit targets share one layout, including disabled controls.
@MainActor final class MobileMenuCanvas: UIView {
    var page = GameFrontEnd.Page(title: "Lemmings") { didSet { rebuild() } }
    var preview: CGImage? { didSet { setNeedsDisplay() } }
    var previewSource: CGRect? { didSet { setNeedsDisplay() } }
    var onAction: ((String) -> Void)?
    private var targets: [UIButton] = []
    private var highlighted: String?
    private var pageLayout: GameFrontEnd.Layout?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isOpaque = true
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { nil }

    func size(width: CGFloat, minimumHeight: CGFloat) -> CGSize {
        GameFrontEnd.layout(page, width: width, minimumHeight: minimumHeight).size
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let layout = GameFrontEnd.layout(page, width: bounds.width, minimumHeight: bounds.height)
        pageLayout = layout
        for (button, target) in zip(targets, layout.targets) { button.frame = target.frame }
        var elements: [Any] = []
        for (text, frame) in [(page.title, layout.heading), (page.subtitle, layout.subtitle)] + Array(zip(page.details, layout.details)) where !text.isEmpty {
            let element = UIAccessibilityElement(accessibilityContainer: self)
            element.accessibilityLabel = text
            element.accessibilityTraits = .staticText
            element.accessibilityFrameInContainerSpace = frame
            elements.append(element)
        }
        accessibilityElements = elements + targets
        setNeedsDisplay()
    }
    private func rebuild() {
        targets.forEach { $0.removeFromSuperview() }
        targets = (page.rows + page.footer).map { action in
            let button = UIButton(type: .custom)
            button.accessibilityLabel = action.title
            button.accessibilityIdentifier = "menu." + action.id
            button.accessibilityTraits = action.selected ? [.button, .selected] : .button
            button.isEnabled = action.enabled
            button.addAction(UIAction { [weak self] _ in self?.onAction?(action.id) }, for: .touchUpInside)
            button.addAction(UIAction { [weak self] _ in
                self?.highlighted = action.id; self?.setNeedsDisplay()
            }, for: .touchDown)
            button.addAction(UIAction { [weak self] _ in
                self?.highlighted = nil; self?.setNeedsDisplay()
            }, for: [.touchUpInside, .touchCancel, .touchUpOutside])
            addSubview(button)
            return button
        }
        setNeedsLayout()
        setNeedsDisplay()
    }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let layout = pageLayout ?? GameFrontEnd.layout(page, width: bounds.width, minimumHeight: bounds.height)
        guard let typography = MobileGameArt.typography else {
            MobilePixelText.draw(page.title, in: layout.heading, palette: .green)
            for target in layout.targets {
                GameStoneArt.draw(in: context, frame: target.frame, selected: target.action.primary, pixel: 1)
                MobilePixelText.draw(target.action.title, in: target.frame.insetBy(dx: 24, dy: 2))
            }
            return
        }
        GameFrontEnd.draw(page, layout: layout, typography: typography, preview: preview,
                         previewSource: previewSource, highlighted: highlighted, in: context)
    }
}
#endif
