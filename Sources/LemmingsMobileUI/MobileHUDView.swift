#if os(iOS)
import NxlvKit
import LemmingsGameArt
import LemmingsMobileCore
import UIKit

/// The level overview with its current camera window.
@MainActor final class MobileMinimapView: UIView {
    var image: CGImage? { didSet { setNeedsDisplay() } }
    var visible = CGRect.zero { didSet { setNeedsDisplay() } }
    var levelSize = CGSize.zero { didSet { setNeedsDisplay() } }
    var overlay = false
    var onSeek: ((CGPoint) -> Void)?

    /// The level, fitted whole inside the touch area.
    var content: CGRect {
        GameMinimapArt.content(in: overlay ? bounds.insetBy(dx: 4, dy: 4) : bounds, levelSize: levelSize)
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
        GameMinimapArt.draw(in: context, bounds: bounds, image: image, visible: visible, levelSize: levelSize, overlay: overlay)
    }
    override func accessibilityIncrement() { seek(1) }
    override func accessibilityDecrement() { seek(-1) }
    private func seek(_ direction: CGFloat) {
        onSeek?(CGPoint(x: min(levelSize.width, max(0, visible.midX + direction * visible.width / 2)), y: visible.midY))
    }
}

@MainActor final class MobileHUDView: UIView {
    var onSpeedHold: ((Bool, Bool) -> Void)?
    var onHold: ((MobileHUDAction) -> Void)?
    private typealias Item = MobileHUDRenderer.Item
    var onRewindHold: ((Bool) -> Void)?
    private var readOnly = false
    var playerName: String?
    var playerPortrait: CGImage?
    private let playerIdentity = UIView()
    var onAction: ((MobileHUDAction) -> Void)?
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
        playerIdentity.isAccessibilityElement = true
        playerIdentity.accessibilityTraits = .staticText
        playerIdentity.isUserInteractionEnabled = false
        playerIdentity.isHidden = true
        addSubview(playerIdentity)
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

    func updateMinimap(frame: MobilePixelFrame, visible: MobileRect, levelSize: MobileSize) {
        minimapView.isHidden = layout?.minimapFrame == nil
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
        panel: MobilePixelFrame?,
        readOnly: Bool = false
    ) {
        self.readOnly = readOnly
        self.layout = layout
        let identityFrame = MobileHUDRenderer.statusFrames(layout: layout, hasPlayer: playerName != nil).player
        playerIdentity.frame = identityFrame ?? .zero
        playerIdentity.isHidden = identityFrame == nil
        playerIdentity.accessibilityLabel = playerName.map { "Current turn: " + $0 }
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

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
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
        if layout?.portrait != nil, let status = layout?.interface.statusFrame,
           point.y <= status.maxY { return self }
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
                          panelImage: panelImage, typography: MobileGameArt.typography, counterStyle: counterStyle, skillIcons: skillIcons, readOnly: readOnly, playerName: playerName, playerPortrait: playerPortrait)
    }

    private func rebuildButtons() {
        buttons.forEach { ($0 as? MobileHUDButton)?.cancelPress(); $0.removeFromSuperview() }
        buttons = items.map { item in
            let kind: MobileHUDPress.Kind
            switch item.action {
            case .releaseRate, .speedStep: kind = .rate
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
            button.onEffect = { [weak self] effect in
                switch effect {
                case .activate: self?.onAction?(item.action)
                case .hold: self?.onHold?(item.action)
                case let .pedal(held, allowTap):
                    if item.action == .speed { self?.onSpeedHold?(held, allowTap) }
                    else { self?.onRewindHold?(held) }
                }
            }
            button.onAccessiblePress = { [weak self] in self?.onAction?(item.action) }
            if item.action == .pause {
                button.accessibilityCustomActions = [UIAccessibilityCustomAction(name: "Pause menu") { [weak self] _ in
                    self?.onHold?(.pause); return true
                }]
            }
            addSubview(button)
            return button
        }
    }

    func cancelHeldControls() { buttons.forEach { ($0 as? MobileHUDButton)?.cancelPress() } }

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
    var onEffect: ((MobileHUDPress.Effect) -> Void)?
    var onAccessiblePress: (() -> Void)?
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
        let effects = press.begin(at: ProcessInfo.processInfo.systemUptime)
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
