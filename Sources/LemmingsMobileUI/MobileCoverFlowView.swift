#if os(iOS) || os(tvOS)
import LemmingsGameArt
import NxlvKit
import UIKit

/// A CoverFlow-style level selector, laid out and drawn like the Mac carousel.
@MainActor final class MobileCoverFlowView: UIView {
    var titles: [String] = [] {
        didSet {
            cancelArtwork()
            artwork.removeAll()
            cards.values.forEach { $0.removeFromSuperlayer() }
            cards = [:]; rendered = [:]
            position = min(position, CGFloat(max(0, titles.count - 1))); target = position
            setNeedsLayout()
        }
    }
    var artworkLoader: ((Int) async -> CGImage?)?
    var artworkLoadingEnabled = false {
        didSet {
            if artworkLoadingEnabled { layoutCards() }
            else { cancelArtwork(); link?.invalidate(); link = nil }
        }
    }
    var onSelectionChanged: ((Int) -> Void)?
    var onActivate: ((Int) -> Void)?

    private(set) var selectedIndex = 0
    private var position: CGFloat = 0
    private var target: CGFloat = 0
    private var cards: [Int: CALayer] = [:]
    private var rendered: [Int: RenderState] = [:]
    private var artwork: [Int: CGImage] = [:]
    private var artworkTasks: [Int: Task<Void, Never>] = [:]
    private var artworkGeneration = UUID()
    private var artworkDrain: Task<Void, Never>?
    nonisolated(unsafe) private var link: CADisplayLink?
    private var panStart: CGFloat = 0
    private var renderedSize = CGSize.zero

    private struct RenderState: Equatable {
        let selected: Bool
        let hasArtwork: Bool
        let size: CGSize
        let displayScale: CGFloat
    }

    /// Breaks the retain cycle a display link would hold on its target.
    @MainActor private final class LinkTarget: NSObject {
        weak var owner: MobileCoverFlowView?
        @objc func tick() { owner?.step() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = false
        #if os(iOS)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        addGestureRecognizer(pan)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        #endif
        isAccessibilityElement = true
        accessibilityLabel = L10n.text("Level selector")
        accessibilityTraits = .adjustable
        if #available(iOS 17.0, tvOS 17.0, *) {
            registerForTraitChanges([UITraitDisplayScale.self]) { (view: MobileCoverFlowView, _) in
                view.rendered.removeAll()
                view.layoutCards()
            }
        }
    }

    required init?(coder: NSCoder) { nil }

    #if os(tvOS)
    override var canBecomeFocused: Bool { !titles.isEmpty }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        layer.borderWidth = isFocused ? 2 : 0
        layer.borderColor = UIColor.white.cgColor
    }
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .leftArrow }) { select(selectedIndex - 1, animated: false); return }
        if presses.contains(where: { $0.type == .rightArrow }) { select(selectedIndex + 1, animated: false); return }
        super.pressesBegan(presses, with: event)
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .select }) { onActivate?(selectedIndex); return }
        super.pressesEnded(presses, with: event)
    }
    #endif

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // iOS 16 predates targeted trait registration.
        if #available(iOS 17.0, tvOS 17.0, *) { return }
        guard previousTraitCollection?.displayScale != traitCollection.displayScale else { return }
        rendered.removeAll()
        layoutCards()
    }

    deinit {
        link?.invalidate()
        artworkTasks.values.forEach { $0.cancel() }
    }

    // MARK: - Selection

    func select(_ index: Int, animated: Bool) {
        guard !titles.isEmpty else { return }
        target = CGFloat(min(max(0, index), titles.count - 1))
        if animated { startLink() } else { position = target; positionChanged() }
    }

    override func accessibilityIncrement() { select(selectedIndex + 1, animated: true) }
    override func accessibilityDecrement() { select(selectedIndex - 1, animated: true) }
    override func accessibilityActivate() -> Bool {
        guard !titles.isEmpty else { return false }
        onActivate?(selectedIndex)
        return true
    }

    private func startLink() {
        guard link == nil else { return }
        let proxy = LinkTarget()
        proxy.owner = self
        let link = CADisplayLink(target: proxy, selector: #selector(LinkTarget.tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    private func step() {
        let difference = target - position
        if abs(difference) < 0.002 {
            position = target
            link?.invalidate(); link = nil
        } else {
            position += difference * 0.22
        }
        positionChanged()
    }

    private func positionChanged() {
        let index = titles.isEmpty ? 0 : min(titles.count - 1, max(0, Int(position.rounded())))
        let changed = index != selectedIndex
        selectedIndex = index
        layoutCards()
        if changed {
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
            accessibilityValue = titles.indices.contains(index) ? titles[index] : nil
            onSelectionChanged?(index)
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutCards()
    }

    private func layoutCards() {
        guard !titles.isEmpty, bounds.width > 0, bounds.height > 0 else { return }
        let geometry = LevelCoverArt.geometry(for: bounds.size)
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / geometry.cameraDistance
        layer.sublayerTransform = perspective
        let lower = max(0, Int(floor(position)) - 5), upper = min(titles.count - 1, Int(ceil(position)) + 5)
        guard lower <= upper else { return }
        for index in cards.keys where index < lower || index > upper {
            cards.removeValue(forKey: index)?.removeFromSuperlayer()
            rendered[index] = nil
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for index in lower...upper {
            let card = cards[index] ?? makeCard(index)
            let selected = index == selectedIndex
            let state = RenderState(selected: selected, hasArtwork: artwork[index] != nil, size: geometry.cardSize,
                                    displayScale: traitCollection.displayScale)
            if rendered[index] != state { render(card, index: index, state: state) }
            let placement = LevelCoverArt.placement(offset: CGFloat(index) - position, selected: selected, geometry: geometry)
            var transform = CATransform3DIdentity
            transform = CATransform3DTranslate(transform, 0, 0, placement.depth)
            transform = CATransform3DRotate(transform, placement.angle, 0, 1, 0)
            transform = CATransform3DScale(transform, placement.scale, placement.scale, 1)
            card.bounds = CGRect(origin: .zero, size: geometry.cardSize)
            card.position = CGPoint(x: bounds.midX + placement.x, y: bounds.midY)
            card.zPosition = placement.zPosition
            card.transform = transform
        }
        CATransaction.commit()
        requestArtwork(near: selectedIndex)
    }

    private func makeCard(_ index: Int) -> CALayer {
        let card = CALayer()
        card.magnificationFilter = .nearest
        card.minificationFilter = .nearest
        card.allowsEdgeAntialiasing = true
        card.contentsScale = traitCollection.displayScale
        layer.addSublayer(card)
        cards[index] = card
        return card
    }

    private func render(_ card: CALayer, index: Int, state: RenderState) {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = state.displayScale
        let image = UIGraphicsImageRenderer(size: state.size, format: format).image { context in
            LevelCoverArt.draw(in: context.cgContext, bounds: CGRect(origin: .zero, size: state.size),
                               title: titles[index], artwork: artwork[index], selected: state.selected,
                               typography: MobileGameArt.typography)
        }
        card.contents = image.cgImage
        card.contentsScale = format.scale
        rendered[index] = state
    }

    // MARK: - Artwork

    private func cancelArtwork() {
        artworkGeneration = UUID()
        drainArtwork(Array(artworkTasks.values))
        artworkTasks.removeAll()
    }

    func stopArtworkLoading() -> Task<Void, Never>? {
        artworkLoadingEnabled = false
        return artworkDrain
    }

    private func drainArtwork(_ tasks: [Task<Void, Never>]) {
        guard !tasks.isEmpty else { return }
        tasks.forEach { $0.cancel() }
        let previous = artworkDrain
        artworkDrain = Task {
            await previous?.value
            for task in tasks { await task.value }
        }
    }

    private func requestArtwork(near centre: Int) {
        guard artworkLoadingEnabled else { return }
        guard let artworkLoader else { return }
        let generation = artworkGeneration
        // Queue the selected cover first so Play never waits behind distant levels.
        let process = ProcessInfo.processInfo
        let adjacent = !MobileDevicePerformance.constrained && !process.isLowPowerModeEnabled
            && process.thermalState == .nominal
        let indices = (adjacent ? [centre, centre - 1, centre + 1] : [centre])
            .filter { titles.indices.contains($0) }
        let allowed = Set(indices)
        let obsolete = artworkTasks.filter { !allowed.contains($0.key) }
        drainArtwork(Array(obsolete.values))
        for index in obsolete.keys { artworkTasks[index] = nil }
        for index in indices
        where artwork[index] == nil && artworkTasks[index] == nil {
            artworkTasks[index] = Task { [weak self] in
                let image = await artworkLoader(index)
                guard let self, !Task.isCancelled, self.artworkLoadingEnabled,
                      self.artworkGeneration == generation else { return }
                self.artworkTasks[index] = nil
                if let image { self.artwork[index] = image; self.layoutCards() }
            }
        }
    }

    // MARK: - Input

    @objc private func panned(_ recognizer: UIPanGestureRecognizer) {
        let pitch = max(1, LevelCoverArt.geometry(for: bounds.size).nearPitch)
        switch recognizer.state {
        case .began:
            link?.invalidate(); link = nil
            panStart = position
        case .changed:
            position = min(CGFloat(titles.count - 1), max(0, panStart - recognizer.translation(in: self).x / pitch))
            target = position
            positionChanged()
        case .ended, .cancelled:
            let projected = position - recognizer.velocity(in: self).x / pitch * 0.18
            select(Int(projected.rounded()), animated: true)
        default:
            break
        }
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self)
        let geometry = LevelCoverArt.geometry(for: bounds.size)
        let hit = cards.keys.sorted { abs(CGFloat($0) - position) < abs(CGFloat($1) - position) }.first { index in
            guard let card = cards[index] else { return false }
            let local = card.convert(point, from: layer)
            return LevelCoverArt.coverBounds(for: CGRect(origin: .zero, size: geometry.cardSize)).contains(local)
        }
        guard let hit else { return }
        if hit == selectedIndex { onActivate?(hit) } else { select(hit, animated: true) }
    }
}
#endif
