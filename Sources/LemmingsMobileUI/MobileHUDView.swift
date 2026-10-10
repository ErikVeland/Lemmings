#if os(iOS)
import LemmingsMobileCore
import UIKit

@MainActor enum MobileHUDAction: Equatable {
    case releaseRate(Int)
    case skill(Int)
    case pause
    case endRun
    case speed
}

@MainActor final class MobileHUDView: UIView {
    private struct Item {
        let action: MobileHUDAction
        let frame: CGRect
        let sourceCell: Int?
        let accessibilityLabel: String
    }

    var onAction: ((MobileHUDAction) -> Void)?

    private var items: [Item] = []
    private var buttons: [UIButton] = []
    private var statusFrame = CGRect.zero
    private var snapshot: MobileGameSnapshot?
    private var selectedSkill = 0
    private var paused = true
    private var speed = 1.0
    private var endRunArmed = false
    private var panelImage: UIImage?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { nil }

    func update(
        layout: MobileInterfaceLayout,
        snapshot: MobileGameSnapshot,
        selectedSkill: Int,
        paused: Bool,
        speed: Double,
        endRunArmed: Bool,
        panel: MobilePixelFrame?
    ) {
        self.snapshot = snapshot
        self.selectedSkill = selectedSkill
        self.paused = paused
        self.speed = speed
        self.endRunArmed = endRunArmed
        statusFrame = Self.cgRect(layout.statusFrame)
        panelImage = panel.flatMap(Self.image)

        var descriptors: [(MobileHUDAction, Int?, String)] = []
        if let rate = snapshot.releaseRate {
            descriptors.append((.releaseRate(-1), 0, "Decrease release rate, currently \(rate)"))
            descriptors.append((.releaseRate(1), 1, "Increase release rate, currently \(rate)"))
        }
        for (index, skill) in snapshot.skills.enumerated() {
            let amount = skill.isUnlimited ? "unlimited" : "\(skill.count) remaining"
            let selected = index == selectedSkill ? ", selected" : ""
            descriptors.append((.skill(index), index + 2, "\(skill.name), \(amount)\(selected)"))
        }
        descriptors.append((.pause, 10, paused ? "Resume" : "Pause"))
        let endRunLabel = snapshot.isEndingRun
            ? "Undo end run"
            : (endRunArmed ? "Confirm end run" : "End run")
        descriptors.append((.endRun, 11, endRunLabel))
        descriptors.append((.speed, nil, "Game speed \(Self.speedLabel(speed))"))

        items = zip(descriptors, layout.controlFrames).map { descriptor, frame in
            Item(
                action: descriptor.0,
                frame: Self.cgRect(frame),
                sourceCell: descriptor.1,
                accessibilityLabel: descriptor.2
            )
        }
        rebuildButtons()
        setNeedsDisplay()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for button in buttons where button.frame.contains(point) {
            return button.hitTest(convert(point, to: button), with: event)
        }
        return nil
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setShouldAntialias(false)
        context.setFillColor(UIColor.black.cgColor)
        context.fill(statusFrame)
        drawStatus()
        for item in items { draw(item, context: context) }
    }

    private func rebuildButtons() {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = items.map { item in
            let button = UIButton(type: .custom)
            button.frame = item.frame
            button.backgroundColor = .clear
            button.accessibilityLabel = item.accessibilityLabel
            button.accessibilityTraits = item.action == .skill(selectedSkill)
                ? [.button, .selected]
                : .button
            button.addAction(UIAction { [weak self] _ in self?.onAction?(item.action) }, for: .touchUpInside)
            addSubview(button)
            return button
        }
    }

    private func drawStatus() {
        guard let snapshot else { return }
        let time: String
        if let remaining = snapshot.remainingSeconds {
            time = String(format: "%d:%02d", remaining / 60, remaining % 60)
        } else {
            time = "--:--"
        }
        let status = "OUT \(snapshot.released)  HOME \(snapshot.saved)/\(snapshot.required)  \(time)"
        MobilePixelText.draw(status, in: statusFrame.insetBy(dx: 6, dy: 4),
                             palette: snapshot.didWin ? .green : .blue, maximumScale: 2)
    }

    private func draw(_ item: Item, context: CGContext) {
        let frame = item.frame.insetBy(dx: 1, dy: 1)
        if let cell = item.sourceCell,
           let image = panelImage?.cgImage,
           let crop = image.cropping(to: CGRect(x: cell * 16, y: 16, width: 16, height: 24)) {
            context.saveGState()
            context.interpolationQuality = .none
            UIImage(cgImage: crop).draw(in: frame)
            context.restoreGState()
        } else {
            drawStone(frame, context: context)
        }

        let selected: Bool
        if case let .skill(index) = item.action { selected = index == selectedSkill }
        else if item.action == .pause { selected = paused }
        else if item.action == .endRun { selected = endRunArmed || snapshot?.isEndingRun == true }
        else if item.action == .speed { selected = speed > 1 }
        else { selected = false }
        if selected {
            context.setStrokeColor((item.action == .endRun && endRunArmed
                ? MobilePixelText.Palette.warning.colour
                : MobilePixelText.Palette.green.colour).cgColor)
            context.setLineWidth(2)
            context.stroke(frame.insetBy(dx: 3, dy: 3))
        }

        switch item.action {
        case let .releaseRate(delta):
            MobilePixelText.draw(delta < 0 ? "-" : "+", in: frame.insetBy(dx: 5, dy: 7),
                                 palette: .green, maximumScale: 3)
        case let .skill(index):
            guard let skill = snapshot?.skills[safe: index] else { return }
            let amount = skill.isUnlimited ? "*" : "\(skill.count)"
            MobilePixelText.draw(amount, in: CGRect(x: frame.minX + 2, y: frame.minY + 2,
                                                     width: frame.width - 4, height: 10),
                                 palette: selected ? .green : .blue, maximumScale: 1)
            let label = String(skill.name.prefix(5)).uppercased()
            MobilePixelText.draw(label, in: CGRect(x: frame.minX + 2, y: frame.maxY - 12,
                                                    width: frame.width - 4, height: 10),
                                 palette: selected ? .green : .blue, maximumScale: 1)
        case .pause:
            if paused {
                MobilePixelText.draw(">", in: frame.insetBy(dx: 8, dy: 8), palette: .green)
            } else {
                context.setFillColor(MobilePixelText.Palette.green.colour.cgColor)
                let width = max(3, floor(frame.width / 9))
                let height = max(14, floor(frame.height / 2))
                context.fill(CGRect(x: frame.midX - width * 1.5, y: frame.midY - height / 2,
                                    width: width, height: height))
                context.fill(CGRect(x: frame.midX + width * 0.5, y: frame.midY - height / 2,
                                    width: width, height: height))
            }
        case .endRun:
            MobilePixelText.draw(snapshot?.isEndingRun == true ? "UNDO" : "X",
                                 in: frame.insetBy(dx: 5, dy: 7),
                                 palette: endRunArmed ? .warning : .green, maximumScale: 2)
        case .speed:
            MobilePixelText.draw(">> \(Self.speedLabel(speed))", in: frame.insetBy(dx: 4, dy: 7),
                                 palette: speed > 1 ? .green : .blue, maximumScale: 2)
        }
    }

    private func drawStone(_ frame: CGRect, context: CGContext) {
        context.setFillColor(UIColor(red: 0.16, green: 0.17, blue: 0.19, alpha: 1).cgColor)
        context.fill(frame)
        context.setStrokeColor(UIColor(white: 0.44, alpha: 1).cgColor)
        context.setLineWidth(2)
        context.stroke(frame.insetBy(dx: 1, dy: 1))
    }

    private static func speedLabel(_ speed: Double) -> String {
        speed.rounded() == speed ? "\(Int(speed))X" : String(format: "%.1fX", speed)
    }

    private static func cgRect(_ rect: MobileRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }

    private static func image(_ frame: MobilePixelFrame) -> UIImage? {
        guard let provider = CGDataProvider(data: frame.rgba as CFData),
              let image = CGImage(
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
              ) else { return nil }
        return UIImage(cgImage: image)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
#endif
