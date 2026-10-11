#if os(iOS)
import LemmingsGameArt
import LemmingsMobileCore
import UIKit

@MainActor enum MobileHUDAction: Equatable {
    case releaseRate(Int)
    case skill(Int)
    case pause
    case endRun
    case speed
    case speedStep(Int)
    case step
    case menu
}

/// The level overview beside the speed control. It draws the latest level frame and the visible window.
@MainActor final class MobileMinimapView: UIView {
    var image: CGImage? { didSet { setNeedsDisplay() } }
    var visible = CGRect.zero { didSet { setNeedsDisplay() } }
    var levelSize = CGSize.zero { didSet { setNeedsDisplay() } }

    /// The level, fitted whole inside the touch area.
    var content: CGRect {
        guard levelSize.width > 0, levelSize.height > 0 else { return .zero }
        let scale = min(bounds.width / levelSize.width, bounds.height / levelSize.height)
        let size = CGSize(width: levelSize.width * scale, height: levelSize.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                      width: size.width, height: size.height)
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
        let map = content
        guard !map.isEmpty else { return }
        context.interpolationQuality = .none
        if let image {
            context.setAlpha(0.8)
            GameStoneArt.drawImage(image, in: map, context: context)
            context.setAlpha(1)
        }
        let scale = map.width / levelSize.width
        let window = CGRect(x: map.minX + visible.minX * scale, y: map.minY + visible.minY * scale,
                            width: visible.width * scale, height: visible.height * scale).intersection(map)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(1)
        context.stroke(window)
    }
}

@MainActor final class MobileHUDView: UIView {
    private struct Item {
        let action: MobileHUDAction
        let frame: CGRect
        let sourceCell: Int?
        let accessibilityLabel: String
    }

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

    private static let shortNames = [
        "walker": "WALK", "jumper": "JUMP", "shimmier": "SHIM", "slider": "SLIDE", "climber": "CLIMB",
        "swimmer": "SWIM", "floater": "FLOAT", "glider": "GLIDE", "disarmer": "DISARM", "bomber": "BOMB",
        "stoner": "STONE", "blocker": "BLOCK", "platformer": "PLAT", "builder": "BUILD", "stacker": "STACK",
        "laserer": "LASER", "basher": "BASH", "fencer": "FENCE", "miner": "MINE", "digger": "DIG", "cloner": "CLONE",
    ]

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
        descriptors.append((.step, nil, "Advance one tick"))
        descriptors.append((.menu, nil, "Menu"))

        let previousActions = items.map(\.action)
        items = zip(descriptors, layout.interface.controlFrames).map { descriptor, frame in
            Item(
                action: descriptor.0,
                frame: Self.cgRect(frame),
                sourceCell: descriptor.1,
                accessibilityLabel: descriptor.2
            )
        }
        if let panel = layout.panel {
            items.append(Item(action: .speedStep(-1), frame: panel.speedArrows[0], sourceCell: nil,
                              accessibilityLabel: "Slower"))
            items.append(Item(action: .speedStep(1), frame: panel.speedArrows[1], sourceCell: nil,
                              accessibilityLabel: "Faster"))
        }
        if previousActions != items.map(\.action) { rebuildButtons() }
        for (button, item) in zip(buttons, items) {
            button.frame = item.frame
            button.accessibilityLabel = item.accessibilityLabel
            button.accessibilityTraits = item.action == .skill(selectedSkill)
                ? [.button, .selected] : .button
            button.isEnabled = item.action != .step || paused
        }
        setNeedsDisplay()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Arrows sit over the speed box, so the last button added wins.
        if !minimapView.isHidden, minimapView.frame.contains(point) {
            return minimapView
        }
        for button in buttons.reversed() where button.frame.contains(point) {
            return button.hitTest(convert(point, to: button), with: event)
        }
        return nil
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), let layout else { return }
        context.setShouldAntialias(false)
        context.interpolationQuality = .none
        let statusFrame = Self.cgRect(layout.interface.statusFrame)
        if let panel = layout.panel {
            context.setFillColor(UIColor.black.cgColor)
            context.fill(CGRect(x: 0, y: panel.frame.minY, width: bounds.width, height: bounds.height - panel.frame.minY))
            drawPanel(panel, context: context)
        } else {
            context.setFillColor(UIColor.black.cgColor)
            context.fill(statusFrame)
            for item in items { drawCell(item, context: context) }
        }
        drawStatus(in: statusFrame, panelMode: layout.panel != nil)
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
            button.isEnabled = item.action != .step || paused
            button.addAction(UIAction { [weak self] _ in self?.onAction?(item.action) }, for: .touchUpInside)
            addSubview(button)
            return button
        }
    }

    // MARK: - Classic panel

    private func drawPanel(_ panel: MobilePanelMetrics, context: CGContext) {
        if let panelImage {
            GameStoneArt.drawImage(panelImage, in: panel.frame, context: context)
        }
        for item in items {
            switch item.action {
            case .pause, .endRun:
                drawGlyphButton(item, context: context, pixel: panel.bevel)
            case .speed:
                drawSpeed(item.frame, panel: panel, context: context)
            case .step, .menu:
                drawTextButton(item, context: context)
            case .speedStep:
                break
            case .releaseRate, .skill:
                break
            }
        }
        drawCounts(panel, context: context)
        drawSkillLabels(panel, context: context)
        if let item = items.first(where: { $0.action == .skill(selectedSkill) }) {
            outline(item.frame, context: context)
        }
    }

    private func drawCounts(_ panel: MobilePanelMetrics, context: CGContext) {
        guard let snapshot else { return }
        for item in items {
            let value: String
            switch item.action {
            case .releaseRate:
                guard let rate = snapshot.releaseRate else { continue }
                value = "\(rate)"
            case let .skill(index):
                guard let skill = snapshot.skills[safe: index] else { continue }
                value = skill.isUnlimited ? "∞" : "\(skill.count)"
            default:
                continue
            }
            // Quantities sit in their own strip above the skill artwork.
            let box = CGRect(x: item.frame.minX, y: panel.frame.minY + panel.scale,
                             width: item.frame.width, height: 9 * panel.scale)
            context.setFillColor(UIColor.black.cgColor)
            context.fill(box)
            drawGameLabel(value, in: box, context: context)
        }
    }

    private func drawSkillLabels(_ panel: MobilePanelMetrics, context: CGContext) {
        guard let snapshot else { return }
        let names = snapshot.skills.map { Self.shortNames[$0.name.lowercased()] ?? $0.name.uppercased() }
        let longest = names.map(\.count).max() ?? 1
        for item in items {
            guard case let .skill(index) = item.action, let name = names[safe: index] else { continue }
            let box = CGRect(x: item.frame.minX, y: panel.frame.minY + 10 * panel.scale,
                             width: item.frame.width, height: 5 * panel.scale)
            context.setFillColor(UIColor.black.cgColor)
            context.fill(box)
            let fits = MobileGameArt.typography.map { typography in
                typography.font(.small).map {
                    $0.cellWidth * longest <= Int(box.width) && $0.cellHeight <= Int(box.height)
                } ?? false
            } ?? false
            if fits {
                MobilePixelText.draw(name, in: box, maximumScale: 1)
            } else {
                let scale = max(1, min(3, floor(min(box.height / 7, box.width / CGFloat(longest * 6)))))
                MobilePixelText.draw(name, in: box, maximumScale: scale, bitmapOnly: true)
            }
        }
    }

    private func drawSpeed(_ frame: CGRect, panel: MobilePanelMetrics, context: CGContext) {
        let active = speed > 1
        drawStoneSocket(frame, selected: active, pixel: panel.bevel, context: context)
        let pixel = SpeedPanelArt.pixel(forHeight: frame.height)
        let boxes = SpeedPanelArt.boxes(in: frame)
        SpeedPanelArt.drawArrow(in: context, box: boxes[0], pointsRight: false)
        SpeedPanelArt.drawArrow(in: context, box: boxes[2], pointsRight: true)
        let label = boxes[1].insetBy(dx: frame.height >= 60 ? 4 * pixel : pixel, dy: 6 * pixel)
        drawGameLabel(Self.speedLabel(speed), in: label, context: context)
    }

    private func outline(_ frame: CGRect, context: CGContext) {
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2)
        context.stroke(frame.insetBy(dx: 2, dy: 2))
    }

    // MARK: - Compact cells

    private func drawCell(_ item: Item, context: CGContext) {
        let frame = item.frame.insetBy(dx: 1, dy: 1)
        let selected: Bool
        if case let .skill(index) = item.action { selected = index == selectedSkill }
        else if item.action == .pause { selected = paused }
        else if item.action == .endRun { selected = snapshot?.isEndingRun == true }
        else if item.action == .speed { selected = speed > 1 }
        else { selected = false }

        switch item.action {
        case .releaseRate, .skill:
            if let cell = item.sourceCell, let image = panelImage?.cropping(to: CGRect(x: cell * 16, y: 16, width: 16, height: 24)) {
                GameStoneArt.drawImage(image, in: frame, context: context)
            } else {
                drawStoneSocket(frame, selected: selected, pixel: 1, context: context)
            }
            drawCompactCount(item, in: frame, selected: selected, context: context)
            if selected { outline(frame, context: context) }
        case .pause, .endRun:
            drawGlyphButton(Item(action: item.action, frame: frame, sourceCell: item.sourceCell,
                                 accessibilityLabel: item.accessibilityLabel), context: context, pixel: 1)
        case .speed:
            drawStoneSocket(frame, selected: selected, pixel: 1, context: context)
            drawGameLabel(Self.speedLabel(speed), in: frame.insetBy(dx: 4, dy: 4), context: context)
        case .step, .menu:
            drawTextButton(Item(action: item.action, frame: frame, sourceCell: item.sourceCell,
                                accessibilityLabel: item.accessibilityLabel), context: context)
        case .speedStep:
            break
        }
    }

    private func drawCompactCount(_ item: Item, in frame: CGRect, selected: Bool, context: CGContext) {
        let value: String
        switch item.action {
        case .releaseRate:
            guard let rate = snapshot?.releaseRate else { return }
            value = "\(rate)"
        case let .skill(index):
            guard let skill = snapshot?.skills[safe: index] else { return }
            value = skill.isUnlimited ? "∞" : "\(skill.count)"
        default:
            return
        }
        let box = CGRect(x: frame.minX + 2, y: frame.minY + 2, width: frame.width - 4, height: 20)
        context.setFillColor(UIColor.black.cgColor)
        context.fill(box)
        drawGameLabel(value, in: box, context: context)
        if case let .skill(index) = item.action, let skill = snapshot?.skills[safe: index] {
            let name = Self.shortNames[skill.name.lowercased()] ?? skill.name.uppercased()
            let label = CGRect(x: frame.minX + 1, y: frame.maxY - 12, width: frame.width - 2, height: 10)
            context.setFillColor(UIColor.black.cgColor)
            context.fill(label)
            let scale = max(1, min(2, floor(min(label.height / 7, label.width / CGFloat(max(1, name.count * 6))))))
            MobilePixelText.draw(name, in: label, maximumScale: scale, bitmapOnly: true)
        }
    }

    // MARK: - Shared pieces

    private func drawStoneSocket(_ frame: CGRect, selected: Bool, pixel: CGFloat, context: CGContext) {
        GameStoneArt.drawSocket(in: context, frame: frame, selected: selected, pixel: pixel)
        if let rock = Self.glyphImage(.rock, fitting: frame.size) {
            GameStoneArt.drawTile(in: context, image: rock.image, logicalSize: rock.size, frame: frame, pixel: pixel)
        }
        GameStoneArt.drawAccent(in: context, frame: frame, selected: selected, pixel: pixel)
    }

    private func drawGlyphButton(_ item: Item, context: CGContext, pixel: CGFloat) {
        let selected = item.action == .pause ? paused : (snapshot?.isEndingRun == true)
        let glyph: PanelGlyphArt
        if item.action == .pause { glyph = paused ? .play : .pause }
        else { glyph = snapshot?.isEndingRun == true ? .undo : .nuke }
        drawStoneSocket(item.frame, selected: selected, pixel: pixel, context: context)
        let well = GameStoneArt.well(item.frame, pixel: pixel)
        if glyph.isOriginalTile {
            if let image = Self.glyphImage(glyph, fitting: item.frame.size) {
                GameStoneArt.drawTile(in: context, image: image.image, logicalSize: image.size,
                                      frame: item.frame, pixel: pixel)
            }
        } else if let image = Self.glyphImage(glyph, fitting: well.size) {
            GameStoneArt.drawImage(image.image, in: CGRect(
                x: floor(well.midX - image.size.width / 2), y: floor(well.midY - image.size.height / 2),
                width: image.size.width, height: image.size.height), context: context)
        }
        if item.action == .endRun, endRunArmed, !selected { outline(item.frame, context: context) }
    }

    private func drawTextButton(_ item: Item, context: CGContext) {
        let enabled = item.action != .step || paused
        GameStoneArt.draw(in: context, frame: item.frame, selected: false, pixel: 1)
        let title = item.action == .step ? "STEP" : "MENU"
        MobilePixelText.draw(title, in: item.frame.insetBy(dx: 8, dy: 2), palette: .blue, alpha: enabled ? 1 : 0.45)
    }

    /// Panel text in the game font, falling back to the pixel font when it will not fit.
    private func drawGameLabel(_ text: String, in box: CGRect, context: CGContext) {
        let plain = text.replacingOccurrences(of: "∞", with: "*")
        if let font = MobileGameArt.typography?.font(.small),
           font.cellHeight <= Int(box.height), font.cellWidth * plain.count <= Int(box.width) {
            MobilePixelText.draw(plain, in: box, maximumScale: 1)
        } else {
            let scale = max(1, min(3, floor(min(box.height / 7, box.width / CGFloat(max(1, plain.count * 6))))))
            MobilePixelText.draw(plain, in: box, maximumScale: scale, bitmapOnly: true)
        }
    }

    private func drawStatus(in frame: CGRect, panelMode: Bool) {
        guard let snapshot else { return }
        let time: String
        if let remaining = snapshot.remainingSeconds {
            time = String(format: "%d:%02d", remaining / 60, remaining % 60)
        } else {
            time = "--:--"
        }
        let status = "OUT \(snapshot.released)  HOME \(snapshot.saved)/\(snapshot.required)  \(time)"
        let inset = panelMode ? CGFloat(8) : 6
        MobilePixelText.draw(status, in: frame.insetBy(dx: inset, dy: 2),
                             palette: snapshot.didWin ? .green : .blue, maximumScale: 1,
                             alignment: panelMode ? .left : .center)
    }

    private static func speedLabel(_ speed: Double) -> String {
        speed.rounded() == speed ? "\(Int(speed))X" : String(format: "%.1fX", speed)
    }

    private static func cgRect(_ rect: MobileRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }

    private static var glyphCache: [String: (image: CGImage, size: CGSize)] = [:]

    private static func glyphImage(_ glyph: PanelGlyphArt, fitting box: CGSize) -> (image: CGImage, size: CGSize)? {
        let steps = glyph.scale(fitting: box)
        guard steps >= 1 else { return nil }
        let key = "\(glyph.rawValue)-\(steps)"
        if let hit = glyphCache[key] { return hit }
        guard let image = glyph.cgImage(scale: steps) else { return nil }
        let size = CGSize(width: CGFloat(image.width) / (glyph.isOriginalTile ? 2 : 1), height: CGFloat(image.height))
        glyphCache[key] = (image, size)
        return (image, size)
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
