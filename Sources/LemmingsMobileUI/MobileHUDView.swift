#if os(iOS)
import LemmingsGameArt
import LemmingsMobileCore
import UIKit

/// The level overview beside the speed control. It draws the latest level frame and the visible window.
@MainActor final class MobileMinimapView: UIView {
    var image: CGImage? { didSet { setNeedsDisplay() } }
    var visible = CGRect.zero { didSet { setNeedsDisplay() } }
    var levelSize = CGSize.zero { didSet { setNeedsDisplay() } }

    /// The level, fitted whole inside the touch area.
    var content: CGRect {
        GameMinimapArt.content(in: bounds, levelSize: levelSize)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityLabel = "Level map"
        accessibilityTraits = .adjustable
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        GameMinimapArt.draw(in: context, bounds: bounds, image: image, visible: visible, levelSize: levelSize)
    }
}

@MainActor final class MobileHUDView: UIView {
    private typealias Item = MobileHUDRenderer.Item
    var onAction: ((MobileHUDAction) -> Void)?
    /// A touch on the map, as a point in level pixels.
    var onMinimap: ((CGPoint) -> Void)?
    private let minimapView = MobileMinimapView()

    private var items: [Item] = []
    private var buttons: [UIButton] = []
    private var layout: MobileHUDLayout?
    private var snapshot: MobileGameSnapshot?
    private var selectedSkill = 0
    private var paused = true
    private var speed = 1.0
    private var endRunArmed = false
    private var panelImage: CGImage?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = false
        let touch = UILongPressGestureRecognizer(target: self, action: #selector(minimapTouched(_:)))
        touch.minimumPressDuration = 0
        minimapView.addGestureRecognizer(touch)
        addSubview(minimapView)
    }

    required init?(coder: NSCoder) { nil }

    func updateMinimap(frame: MobilePixelFrame, visible: MobileRect, levelSize: MobileSize) {
        minimapView.isHidden = layout?.panel == nil
        guard !minimapView.isHidden else { return }
        minimapView.image = Self.image(frame)
        minimapView.visible = Self.cgRect(visible)
        minimapView.levelSize = CGSize(width: levelSize.width, height: levelSize.height)
    }

    @objc private func minimapTouched(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began || recognizer.state == .changed else { return }
        let map = minimapView.content
        guard !map.isEmpty else { return }
        let point = recognizer.location(in: minimapView)
        guard map.contains(point) else { return }
        let fraction = CGPoint(x: min(1, max(0, (point.x - map.minX) / map.width)),
                               y: min(1, max(0, (point.y - map.minY) / map.height)))
        onMinimap?(CGPoint(x: fraction.x * minimapView.levelSize.width, y: fraction.y * minimapView.levelSize.height))
    }

    func update(
        layout: MobileHUDLayout,
        snapshot: MobileGameSnapshot,
        selectedSkill: Int,
        paused: Bool,
        speed: Double,
        endRunArmed: Bool,
        panel: MobilePixelFrame?
    ) {
        self.layout = layout
        self.snapshot = snapshot
        self.selectedSkill = selectedSkill
        self.paused = paused
        self.speed = speed
        self.endRunArmed = endRunArmed
        panelImage = panel.flatMap(Self.image)
        minimapView.frame = layout.panel?.minimap ?? .zero
        minimapView.isHidden = layout.panel == nil

        let previousActions = items.map(\.action)
        items = MobileHUDRenderer.targets(layout: layout, snapshot: snapshot, selectedSkill: selectedSkill,
                                          paused: paused, speed: speed, endRunArmed: endRunArmed)
        if previousActions != items.map(\.action) { rebuildButtons() }
        for (button, item) in zip(buttons, items) {
            button.frame = item.inputFrame
            button.accessibilityLabel = item.accessibilityLabel
            button.accessibilityTraits = item.action == .skill(selectedSkill)
                ? [.button, .selected] : .button
            button.isEnabled = item.action != .step || paused
        }
        setNeedsDisplay()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Each speed action has a separate target inside the shared speed socket.
        if !minimapView.isHidden, minimapView.frame.contains(point) {
            return minimapView
        }
        for button in buttons.reversed() where button.frame.contains(point) {
            return button.hitTest(convert(point, to: button), with: event)
        }
        return nil
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), let layout, let snapshot else { return }
        MobileHUDRenderer(layout: layout, snapshot: snapshot, selectedSkill: selectedSkill,
                          paused: paused, speed: speed, endRunArmed: endRunArmed,
                          panelImage: panelImage, typography: MobileGameArt.typography).draw(in: context, bounds: bounds)
    }

    private func rebuildButtons() {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = items.map { item in
            let button = UIButton(type: .custom)
            button.frame = item.inputFrame
            button.backgroundColor = .clear
            button.accessibilityLabel = item.accessibilityLabel
            button.accessibilityTraits = item.action == .skill(selectedSkill)
                ? [.button, .selected]
                : .button
            button.isEnabled = item.action != .step || paused
            button.addAction(UIAction { [weak self] _ in self?.onAction?(item.action) }, for: .touchUpInside)
            addSubview(button)
            return button
        }
    }

    private static func cgRect(_ rect: MobileRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }

    private static func image(_ frame: MobilePixelFrame) -> CGImage? {
        guard let provider = CGDataProvider(data: frame.rgba as CFData) else { return nil }
        return CGImage(
            width: frame.width,
            height: frame.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: frame.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
#endif
