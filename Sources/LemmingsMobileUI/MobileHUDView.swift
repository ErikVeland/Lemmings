#if os(iOS) || os(tvOS)
import NxlvKit
import LemmingsGameArt
import LemmingsMobileCore
import UIKit

/// The level overview with its current camera window.
@MainActor final class MobileMinimapView: UIView {
    var image: CGImage? { didSet { if oldValue !== image { setNeedsDisplay() } } }
    var visible = CGRect.zero { didSet { if oldValue != visible { setNeedsDisplay() } } }
    var levelSize = CGSize.zero { didSet { if oldValue != levelSize { setNeedsDisplay() } } }
    var overlay = false
    var onSeek: ((CGPoint) -> Void)?
    private let thumbnail = GameMinimapThumbnail()

    /// The level, fitted whole inside the touch area.
    var content: CGRect {
        GameMinimapArt.content(in: overlay ? bounds.insetBy(dx: 4, dy: 4) : bounds, levelSize: levelSize)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityLabel = L10n.text("Level map")
        accessibilityTraits = .adjustable
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        GameMinimapArt.draw(in: context, bounds: bounds, image: image, visible: visible, levelSize: levelSize, overlay: overlay,
                            thumbnail: thumbnail)
    }
    override func accessibilityIncrement() { seek(1) }
    override func accessibilityDecrement() { seek(-1) }
    private func seek(_ direction: CGFloat) {
        onSeek?(CGPoint(x: min(levelSize.width, max(0, visible.midX + direction * visible.width / 2)), y: visible.midY))
    }
}

@MainActor final class MobileHUDView: UIView, UIGestureRecognizerDelegate {
    var onRateDoubleTap: ((Bool) -> Void)?
    var onSpeedHold: ((Bool, Bool) -> Void)?
    var onHold: ((MobileHUDAction) -> Void)?
    private typealias Item = MobileHUDRenderer.Item
    var onRewindHold: ((Bool) -> Void)?
    private var readOnly = false
    var playerName: String?
    var playerPortrait: CGImage?
    private let playerIdentity = UIView()
    private let statusIdentity = UIView()
    var statusDetails: MobileHUDRenderer.StatusDetails?
    private let toolDirectionPicker = MobileToolDirectionPickerView()
    private let rateValueTap = UITapGestureRecognizer()
    var onAction: ((MobileHUDAction) -> Void)?
    var onToolDirection: ((Lemmings3Runtime.Direction?) -> Void)?
    /// A touch on the map, as a point in level pixels.
    var onMinimap: ((CGPoint) -> Void)?
    private let minimapView = MobileMinimapView()
    private let skillScroll = MobileSkillScrollView()
    private let skillCanvas = MobileSkillCanvas()

    private var items: [Item] = []
    private var buttons: [UIButton] = []
    private var layout: MobileHUDLayout?
    private var snapshot: MobileGameSnapshot?
    private var selectedSkill = 0
    private var paused = true
    private var speed = 1.0
    private var endRunArmed = false
    var skillIcons: [CGImage?] = []
    var counterStyle: ClassicCounterStyle = .game
    private var panelImage: CGImage?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = false
        rateValueTap.numberOfTapsRequired = 2
        rateValueTap.delegate = self
        rateValueTap.addTarget(self, action: #selector(toggleRateValue(_:)))
        addGestureRecognizer(rateValueTap)
        playerIdentity.isAccessibilityElement = true
        playerIdentity.accessibilityTraits = .staticText
        playerIdentity.isUserInteractionEnabled = false
        playerIdentity.isHidden = true
        addSubview(playerIdentity)
        statusIdentity.isAccessibilityElement = true
        statusIdentity.accessibilityTraits = .staticText
        statusIdentity.isUserInteractionEnabled = false
        statusIdentity.isHidden = true
        addSubview(statusIdentity)
        addSubview(toolDirectionPicker)
        toolDirectionPicker.onChoice = { [weak self] direction in self?.onToolDirection?(direction) }
        let touch = UILongPressGestureRecognizer(target: self, action: #selector(minimapTouched(_:)))
        touch.minimumPressDuration = 0
        minimapView.addGestureRecognizer(touch)
        addSubview(minimapView)
        minimapView.onSeek = { [weak self] point in self?.onMinimap?(point) }
        skillScroll.showsHorizontalScrollIndicator = true
        skillScroll.delaysContentTouches = false
        skillScroll.addSubview(skillCanvas)
        addSubview(skillScroll)
        skillCanvas.drawContent = { [weak self] context in
            guard let self, let skills = self.layout?.portrait?.skills else { return }
            context.translateBy(x: -skills.minX, y: -skills.minY)
            self.renderer()?.drawSkills(in: context, clipped: false)
        }
    }

    required init?(coder: NSCoder) { nil }

    func updateMinimap(frame: MobilePixelFrame, visible: MobileRect, levelSize: MobileSize, image: CGImage? = nil) {
        minimapView.isHidden = layout?.minimapFrame == nil
        guard !minimapView.isHidden else { return }
        minimapView.image = image ?? Self.image(frame)
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
        panel: MobilePixelFrame?,
        readOnly: Bool = false
    ) {
        self.readOnly = readOnly
        self.layout = layout
        let identityFrame = MobileHUDRenderer.statusFrames(layout: layout, hasPlayer: playerName != nil).player
        playerIdentity.frame = identityFrame ?? .zero
        playerIdentity.isHidden = identityFrame == nil
        playerIdentity.accessibilityLabel = playerName.map { L10n.text("Current turn: \($0)") }
        statusIdentity.isHidden = false
        statusIdentity.frame = MobileHUDRenderer.statusFrames(layout: layout, hasPlayer: playerName != nil).counters
        let lines = MobileHUDRenderer.televisionStatusLines(snapshot: snapshot, details: statusDetails,
            engineIdentifier: statusDetails?.engineIdentifier ?? (layout.panel?.style == .lemmings3 ? "lemmings3" : "classic"),
            paused: paused, speed: speed)
        statusIdentity.accessibilityLabel = lines.joined(separator: ". ")
            .replacingOccurrences(of: statusDetails?.deathCounter ?? "💀", with: statusDetails?.accessibility ?? "")
        self.snapshot = snapshot
        let previousSkill = self.selectedSkill
        self.selectedSkill = selectedSkill
        self.paused = paused
        self.speed = speed
        self.endRunArmed = endRunArmed
        panelImage = panel.flatMap(Self.image)
        minimapView.frame = layout.minimapFrame ?? .zero
        minimapView.overlay = layout.portrait != nil
        minimapView.isHidden = layout.minimapFrame == nil
        skillScroll.isHidden = layout.portrait == nil
        if let portrait = layout.portrait {
            skillScroll.frame = portrait.skills
            skillScroll.contentSize = CGSize(width: portrait.skillContentWidth, height: portrait.skills.height)
            skillCanvas.frame = CGRect(origin: .zero, size: skillScroll.contentSize)
            if skillScroll.contentSize.width <= skillScroll.bounds.width { skillScroll.contentOffset = .zero }
        }

        let previousActions = items.map(\.action)
        items = MobileHUDRenderer.targets(layout: layout, snapshot: snapshot, selectedSkill: selectedSkill,
                                          paused: paused, speed: speed, endRunArmed: endRunArmed)
        if previousActions != items.map(\.action) { rebuildButtons() }
        for (button, item) in zip(buttons, items) {
            (button as? MobileHUDButton)?.activatesOnPress = item.action == .pause && !paused
            if case .skill = item.action, let portrait = layout.portrait {
                if button.superview !== skillCanvas { skillCanvas.addSubview(button) }
                button.frame = item.inputFrame.offsetBy(dx: -portrait.skills.minX, dy: -portrait.skills.minY)
            } else {
                if button.superview !== self { addSubview(button) }
                button.frame = item.inputFrame
            }
            button.accessibilityLabel = item.accessibilityLabel
            button.accessibilityTraits = item.action == .skill(selectedSkill)
                ? [.button, .selected] : .button
            button.isEnabled = isEnabled(item.action)
            button.accessibilityElementsHidden = readOnly && !button.isEnabled
        }
        if previousSkill != selectedSkill, let button = buttons.first(where: { $0.accessibilityTraits.contains(.selected) }),
           button.superview === skillCanvas { skillScroll.scrollRectToVisible(button.frame, animated: false) }
        setNeedsDisplay()
        skillCanvas.setNeedsDisplay()
    }

    @objc private func toggleRateValue(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, !readOnly else { return }
        onRateDoubleTap?(snapshot?.releaseRate == 99)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === rateValueTap, !readOnly,
              let frame = layout?.portrait?.rateValue else { return false }
        return frame.contains(touch.location(in: self))
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
        if !toolDirectionPicker.isHidden, toolDirectionPicker.frame.contains(point) {
            return toolDirectionPicker.hitTest(convert(point, to: toolDirectionPicker), with: event)
        }
        if !readOnly, layout?.portrait?.rateValue?.contains(point) == true { return self }
        // Each speed action has a separate target inside the shared speed socket.
        if !minimapView.isHidden, minimapView.frame.contains(point) {
            return minimapView
        }
        if !skillScroll.isHidden, skillScroll.frame.contains(point) {
            return skillScroll.hitTest(convert(point, to: skillScroll), with: event)
        }
        for button in buttons.reversed() where button.superview === self && button.frame.contains(point) {
            return button.hitTest(convert(point, to: button), with: event)
        }
        if let layout, layout.interface.statusFrame.minY == layout.interface.safeFrame.minY,
           point.y <= layout.interface.statusFrame.maxY { return self }
        if let status = layout?.interface.statusFrame, Self.cgRect(status).contains(point) { return self }
        return nil
    }

    /// Controller activation uses the visible button bounds, including scrolled skills.
    func pointerAction(at point: CGPoint) -> MobileHUDAction? {
        guard bounds.contains(point), isUserInteractionEnabled else { return nil }
        for (button, item) in zip(buttons, items) where button.isEnabled && !button.isHidden {
            let local = button.convert(point, from: self)
            if button.bounds.contains(local) {
                if button.superview === skillCanvas && !skillScroll.frame.contains(point) { continue }
                return item.action
            }
        }
        return nil
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        renderer()?.draw(in: context, bounds: bounds, includeSkills: layout?.portrait == nil, includeTicks: true)
    }

    private func renderer() -> MobileHUDRenderer? {
        guard let layout, let snapshot else { return nil }
        return MobileHUDRenderer(layout: layout, snapshot: snapshot, selectedSkill: selectedSkill,
                          paused: paused, speed: speed, endRunArmed: endRunArmed,
                          panelImage: panelImage, typography: MobileGameArt.typography, counterStyle: counterStyle, skillIcons: skillIcons, readOnly: readOnly, playerName: playerName, playerPortrait: playerPortrait, statusDetails: statusDetails)
    }

    private func rebuildButtons() {
        buttons.forEach { ($0 as? MobileHUDButton)?.cancelPress(); $0.removeFromSuperview() }
        buttons = items.map { item in
            let kind: MobileHUDPress.Kind
            switch item.action {
            case .releaseRate: kind = .releaseRate
            case .speedStep: kind = .rate
            case .speed: kind = .speed
            case .rewind: kind = .rewind
            case .pause: kind = .pause
            case .endRun: kind = .nuke
            default: kind = .tap
            }
            let button = MobileHUDButton(kind: kind)
            button.frame = item.inputFrame
            button.backgroundColor = .clear
            button.accessibilityLabel = item.accessibilityLabel
            button.accessibilityTraits = item.action == .skill(selectedSkill)
                ? [.button, .selected]
                : .button
            button.isEnabled = isEnabled(item.action)
            var rateStartedAtMaximum = false
            button.onEffect = { [weak self] effect in
                switch effect {
                case .activate:
                    if case .releaseRate = item.action { rateStartedAtMaximum = self?.snapshot?.releaseRate == 99 }
                    self?.onAction?(item.action)
                case .doubleTap: self?.onRateDoubleTap?(rateStartedAtMaximum)
                case .hold: self?.onHold?(item.action)
                case let .pedal(held, allowTap):
                    if item.action == .speed { self?.onSpeedHold?(held, allowTap) }
                    else { self?.onRewindHold?(held) }
                }
            }
            button.onAccessiblePress = { [weak self] in self?.onAction?(item.action) }
            if case .releaseRate = item.action {
                button.accessibilityHint = L10n.text("Actions include minimum or maximum release rate.")
                button.accessibilityCustomActions = [UIAccessibilityCustomAction(name: L10n.text("Toggle minimum or maximum release rate")) { [weak self] _ in
                    self?.onRateDoubleTap?(self?.snapshot?.releaseRate == 99); return true
                }]
            }
            if item.action == .pause {
                button.accessibilityCustomActions = [UIAccessibilityCustomAction(name: L10n.text("Pause menu")) { [weak self] _ in
                    self?.onHold?(.pause); return true
                }]
            }
            addSubview(button)
            return button
        }
    }

    func cancelHeldControls() {
        buttons.forEach { ($0 as? MobileHUDButton)?.cancelPress() }
        rateValueTap.isEnabled = false
        rateValueTap.isEnabled = true
    }

    @discardableResult
    func showToolDirectionPicker(frames: [MobilePixelFrame], target: CGPoint, playfield: CGRect) -> Bool {
        let bounds = MobileRect(x: playfield.minX, y: playfield.minY,
                                width: playfield.width, height: playfield.height)
        guard let frame = MobileDirectionPickerLayout.frame(
            centredAt: MobilePoint(x: target.x, y: target.y), within: bounds
        ) else { return false }
        toolDirectionPicker.present(frames: frames,
            frame: CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height))
        bringSubviewToFront(toolDirectionPicker)
        return true
    }

    func hideToolDirectionPicker() { toolDirectionPicker.dismiss() }

    private func isEnabled(_ action: MobileHUDAction) -> Bool {
        switch action {
        case .skill, .releaseRate, .endRun: return !readOnly
        case .step: return paused
        case .rewind, .stepBackward: return (snapshot?.tick ?? 0) > 0
        default: return true
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

@MainActor private final class MobileToolDirectionPickerView: UIView {
    private struct Cell {
        let direction: Lemmings3Runtime.Direction?
        let frameIndex: Int?
        let label: String
    }

    private static var cells: [Cell] { MobileDirectionPickerLayout.gridDirections.map { direction in
        guard let direction else {
            return Cell(direction: nil, frameIndex: nil, label: L10n.text("Cancel tool direction"))
        }
        let label: String
        switch direction {
        case .upLeft: label = L10n.text("Up-left")
        case .up: label = L10n.text("Up")
        case .upRight: label = L10n.text("Up-right")
        case .left: label = L10n.text("Left")
        case .right: label = L10n.text("Right")
        case .downLeft: label = L10n.text("Down-left")
        case .down: label = L10n.text("Down")
        case .downRight: label = L10n.text("Down-right")
        }
        return Cell(direction: direction, frameIndex: MobileDirectionPickerLayout.frameIndex(for: direction), label: label)
    } }

    var onChoice: ((Lemmings3Runtime.Direction?) -> Void)?
    private var buttons: [UIButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.92)
        layer.borderWidth = 2
        layer.borderColor = UIColor(red: 0.25, green: 0.9, blue: 0.35, alpha: 1).cgColor
        isHidden = true
        isAccessibilityElement = false
        accessibilityViewIsModal = false
    }

    required init?(coder: NSCoder) { nil }

    func present(frames: [MobilePixelFrame], frame: CGRect) {
        guard frames.count == 8 else { return }
        buttons.forEach { $0.removeFromSuperview() }
        buttons.removeAll(keepingCapacity: true)
        let extent = CGFloat(MobileDirectionPickerLayout.cellExtent)
        self.frame = frame
        for (index, cell) in Self.cells.enumerated() {
            let button = MobileFocusButton(type: .custom)
            button.frame = CGRect(x: CGFloat(index % 3) * extent,
                                  y: CGFloat(index / 3) * extent,
                                  width: extent, height: extent)
            button.backgroundColor = .clear
            button.accessibilityLabel = cell.label
            button.accessibilityTraits = .button
            button.accessibilityIdentifier = "game.l3.direction.\(cell.direction.map { $0.rawValue.lowercased() } ?? "cancel")"
            var configuration = UIButton.Configuration.plain()
            if let frameIndex = cell.frameIndex,
               let image = MobileBitmapRenderer.image(frames[frameIndex]) {
                configuration.image = UIImage(cgImage: image).withRenderingMode(.alwaysOriginal)
                configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
            } else {
                configuration.image = Self.cancelImage()?.withRenderingMode(.alwaysOriginal)
                configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
            }
            button.configuration = configuration
            button.imageView?.contentMode = .scaleAspectFit
            button.imageView?.layer.magnificationFilter = .nearest
            button.addAction(UIAction { [weak self] _ in self?.onChoice?(cell.direction) },
                             for: .gameActivation)
            addSubview(button)
            buttons.append(button)
        }
        accessibilityLabel = L10n.text("Choose Lemmings 3 tool direction")
        accessibilityViewIsModal = true
        isHidden = false
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        UIAccessibility.post(notification: .screenChanged, argument: buttons.first)
    }

    func dismiss() {
        guard !isHidden else { return }
        isHidden = true
        buttons.forEach { $0.removeFromSuperview() }
        buttons.removeAll(keepingCapacity: true)
        accessibilityViewIsModal = false
    }

    private static func cancelImage() -> UIImage? {
        let size = 8
        var rgba = [UInt8](repeating: 0, count: size * size * 4)
        for point in 1...6 {
            for x in [point, size - point - 1] {
                let index = (point * size + x) * 4
                rgba[index] = 255
                rgba[index + 1] = 74
                rgba[index + 2] = 48
                rgba[index + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let image = CGImage(width: size, height: size, bitsPerComponent: 8,
                  bitsPerPixel: 32, bytesPerRow: size * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: false,
                  intent: .defaultIntent) else { return nil }
        return UIImage(cgImage: image)
    }
}

@MainActor private final class MobileSkillCanvas: UIView {
    var drawContent: ((CGContext) -> Void)?
    override init(frame: CGRect) { super.init(frame: frame); isOpaque = false; backgroundColor = .clear }
    required init?(coder: NSCoder) { nil }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setShouldAntialias(false); context.interpolationQuality = .none
        drawContent?(context)
    }
}

@MainActor private final class MobileSkillScrollView: UIScrollView {
    override func touchesShouldCancel(in view: UIView) -> Bool {
        view is MobileHUDButton || super.touchesShouldCancel(in: view)
    }
}

@MainActor private final class MobileHUDButton: UIButton {
    #if os(tvOS)
    override var canBecomeFocused: Bool { false }
    #endif
    var onEffect: ((MobileHUDPress.Effect) -> Void)?
    var onAccessiblePress: (() -> Void)?
    var activatesOnPress = false
    private var press: MobileHUDPress
    private var timer: Timer?
    init(kind: MobileHUDPress.Kind) {
        press = MobileHUDPress(kind)
        super.init(frame: .zero)
        addAction(UIAction { [weak self] _ in self?.beginPress() }, for: .touchDown)
        addAction(UIAction { [weak self] _ in self?.finishPress(cancelled: false) }, for: .touchUpInside)
        addAction(UIAction { [weak self] _ in self?.cancelPress() }, for: [.touchUpOutside, .touchCancel, .touchDragExit])
    }
    required init?(coder: NSCoder) { nil }
    override var isEnabled: Bool { didSet { if !isEnabled { cancelPress() } } }
    override func didMoveToWindow() { super.didMoveToWindow(); if window == nil { cancelPress() } }
    override func accessibilityActivate() -> Bool {
        guard isEnabled else { return false }
        onAccessiblePress?(); return true
    }
    func cancelPress() { finishPress(cancelled: true) }
    private func beginPress() {
        let effects = press.begin(at: ProcessInfo.processInfo.systemUptime, activateOnBegin: activatesOnPress)
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.04, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.deliver(self.press.update(at: ProcessInfo.processInfo.systemUptime))
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        deliver(effects)
    }
    private func finishPress(cancelled: Bool) {
        timer?.invalidate(); timer = nil
        deliver(press.end(at: ProcessInfo.processInfo.systemUptime, cancelled: cancelled))
    }
    private func deliver(_ effects: [MobileHUDPress.Effect]) { effects.forEach { onEffect?($0) } }
}

private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
#endif
