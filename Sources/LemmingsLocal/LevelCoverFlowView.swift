import AppKit
import NxlvKit

/// One card in the presentation layer. The typed catalogue remains the launch source.
struct LevelCoverFlowItem: Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    let availability: LevelAvailability
    let artworkKey: String?

    var isAvailable: Bool { availability.canStart }

    init(
        id: String,
        title: String,
        subtitle: String,
        detail: String,
        isAvailable: Bool = true,
        artworkKey: String? = nil,
        availability: LevelAvailability? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.availability = availability ?? (isAvailable ? .available : .unavailable)
        self.artworkKey = artworkKey
    }

    var accessibilityName: String {
        [title, subtitle, detail, isAvailable ? nil : availability.displayName]
            .compactMap { $0 }
            .joined(separator: ". ")
    }
}

/// A CoverFlow-style selector that uses real controls for mouse, controller, and VoiceOver input.
@MainActor final class LevelCoverFlowView: NSView {
    private static let artworkCacheEntryLimit = 21
    private static let artworkCacheCostLimit = 8 * 1_024 * 1_024
    private static let preciseScrollPointsPerItem: CGFloat = 60

    struct VisualState: Equatable {
        let rotationY: CGFloat
        let depth: CGFloat
        let frontDepth: CGFloat
        let backDepth: CGFloat
        let scale: CGFloat
        let stackOrder: CGFloat
        let perspective: CGFloat
        let inputTransformIsIdentity: Bool
        let projectedCoverCorners: [CGPoint]
        let reflectionVisible: Bool
        let artworkKey: String?
        let hasArtwork: Bool
        let activeAnimationKeys: [String]
    }

    typealias ArtworkLoader = @Sendable (String) async -> LevelPreviewBitmap?

    private var items: [LevelCoverFlowItem] = []
    private var cards: [LevelCoverCardButton] = []
    private let artworkImages = LevelCoverFlowImageCache(
        countLimit: artworkCacheEntryLimit,
        costLimit: artworkCacheCostLimit)
    private var artworkFailures: Set<String> = []
    private var artworkFailureOrder: [String] = []
    private var artworkTasks: [String: Task<Void, Never>] = [:]
    private var artworkTaskTokens: [String: UUID] = [:]
    private var discreteScrollRemainder: CGFloat = 0
    private var preciseScrollSnapTask: Task<Void, Never>?
    private var animatesNextLayout = false
    private(set) var selectedIndex = 0
    private(set) var usesReducedMotionLayout = false
    private(set) var coverFlowPosition: CGFloat = 0
    private(set) var isTrackingPreciseScroll = false
    var artworkCacheEntryCount: Int { artworkImages.count }
    var artworkCacheCost: Int { artworkImages.cost }
    var artworkCacheLimits: (entries: Int, cost: Int) {
        (Self.artworkCacheEntryLimit, Self.artworkCacheCostLimit)
    }
    var artworkLoader: ArtworkLoader?
    var onSelectionChanged: ((LevelCoverFlowItem) -> Void)?
    var onStart: ((LevelCoverFlowItem) -> Void)?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        applyStagePerspective()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        applyStagePerspective()
    }

    deinit {
        preciseScrollSnapTask?.cancel()
        artworkTasks.values.forEach { $0.cancel() }
    }

    override func becomeFirstResponder() -> Bool {
        cards.forEach { $0.invalidateVisual() }
        return true
    }

    override func resignFirstResponder() -> Bool {
        cards.forEach { $0.invalidateVisual() }
        return true
    }

    var selectedItem: LevelCoverFlowItem? {
        items.indices.contains(selectedIndex) ? items[selectedIndex] : nil
    }

    func visualState(at index: Int) -> VisualState? {
        cards.first(where: { $0.tag == index }).map { card in
            VisualState(
                rotationY: card.coverFlowRotationY,
                depth: card.coverFlowDepth,
                frontDepth: card.coverFlowFrontDepth,
                backDepth: card.coverFlowBackDepth,
                scale: card.coverFlowScale,
                stackOrder: card.visualZPosition,
                perspective: layer?.sublayerTransform.m34 ?? 0,
                inputTransformIsIdentity: card.inputTransformIsIdentity,
                projectedCoverCorners: card.projectedCoverCorners,
                reflectionVisible: card.reflectionVisible,
                artworkKey: card.artworkKey,
                hasArtwork: card.hasArtwork,
                activeAnimationKeys: card.activeAnimationKeys)
        }
    }

    private func applyStagePerspective(cameraDistance: CGFloat? = nil) {
        guard let layer else { return }
        var perspective = CATransform3DIdentity
        let coverWidth = min(320, max(1, bounds.width * 0.33))
        perspective.m34 = -1 / (cameraDistance ?? coverWidth * 8 / 3)
        layer.sublayerTransform = perspective
    }

    func configure(
        items: [LevelCoverFlowItem],
        selectedID: String? = nil,
        reduceMotion: Bool
    ) {
        let retainedID = selectedID ?? selectedItem?.id
        self.items = items
        stopPreciseScrollTracking()
        discreteScrollRemainder = 0
        selectedIndex = retainedID.flatMap { id in items.firstIndex { $0.id == id } }
            ?? min(selectedIndex, max(0, items.count - 1))
        coverFlowPosition = CGFloat(selectedIndex)
        usesReducedMotionLayout = reduceMotion
        rebuildCards(animated: false)
        if let selectedItem { onSelectionChanged?(selectedItem) }
    }

    /**
     * Changes the presentation without replacing the current items or selection.
     */
    func setReducedMotion(_ enabled: Bool) {
        guard usesReducedMotionLayout != enabled else { return }
        stopPreciseScrollTracking()
        discreteScrollRemainder = 0
        usesReducedMotionLayout = enabled
        coverFlowPosition = CGFloat(selectedIndex)
        rebuildCards(animated: false)
    }

    @discardableResult func moveSelection(_ delta: Int) -> Bool {
        guard !items.isEmpty, delta != 0 else { return false }
        let needsSnap = abs(coverFlowPosition - CGFloat(selectedIndex)) > 0.001
        stopPreciseScrollTracking()
        discreteScrollRemainder = 0
        let next = min(items.count - 1, max(0, selectedIndex + delta))
        guard next != selectedIndex else {
            if needsSnap { rebuildCards(animated: !usesReducedMotionLayout) }
            return false
        }
        selectedIndex = next
        coverFlowPosition = CGFloat(next)
        rebuildCards(animated: !usesReducedMotionLayout)
        if let selectedItem { onSelectionChanged?(selectedItem) }
        return true
    }

    func selectItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        let needsSnap = abs(coverFlowPosition - CGFloat(index)) > 0.001
        stopPreciseScrollTracking()
        discreteScrollRemainder = 0
        coverFlowPosition = CGFloat(index)
        if selectedIndex != index {
            selectedIndex = index
            rebuildCards(animated: !usesReducedMotionLayout)
            onSelectionChanged?(items[index])
        } else if needsSnap {
            rebuildCards(animated: !usesReducedMotionLayout)
        }
    }

    func startSelectedItem() {
        guard let selectedItem, selectedItem.isAvailable else { return }
        onStart?(selectedItem)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123, 126: _ = moveSelection(-1)
        case 124, 125: _ = moveSelection(1)
        case 116: _ = moveSelection(-5)
        case 121: _ = moveSelection(5)
        case 115: selectItem(at: 0)
        case 119: selectItem(at: items.count - 1)
        case 36, 49, 76: startSelectedItem()
        default:
            guard !items.isEmpty,
                  let value = event.charactersIgnoringModifiers?.lowercased(),
                  value.count == 1,
                  let match = (1...self.items.count).lazy
                    .map({ (self.selectedIndex + $0) % max(1, self.items.count) })
                    .first(where: { self.items[$0].title.lowercased().hasPrefix(value) }) else {
                super.keyDown(with: event)
                return
            }
            selectItem(at: match)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        let amount = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
            ? event.scrollingDeltaX : event.scrollingDeltaY
        guard !items.isEmpty else { return }
        if event.hasPreciseScrollingDeltas, !usesReducedMotionLayout {
            updatePreciseScroll(with: event, amount: amount)
            return
        }

        if event.hasPreciseScrollingDeltas {
            discreteScrollRemainder += amount
            guard abs(discreteScrollRemainder) >= 1 else { return }
            let direction = discreteScrollRemainder > 0 ? -1 : 1
            discreteScrollRemainder = 0
            _ = moveSelection(direction)
        } else {
            guard amount != 0 else { return }
            _ = moveSelection(amount > 0 ? -1 : 1)
        }
    }

    private func updatePreciseScroll(with event: NSEvent, amount: CGFloat) {
        preciseScrollSnapTask?.cancel()
        preciseScrollSnapTask = nil
        let phase = event.phase
        let momentum = event.momentumPhase
        let continuesMotion = amount != 0
            || phase.contains(.began) || phase.contains(.changed)
            || momentum.contains(.began) || momentum.contains(.changed)
        if continuesMotion, !isTrackingPreciseScroll {
            isTrackingPreciseScroll = true
            coverFlowPosition = CGFloat(selectedIndex)
        }

        if isTrackingPreciseScroll, amount != 0 {
            coverFlowPosition = min(
                CGFloat(items.count - 1),
                max(0, coverFlowPosition - amount / Self.preciseScrollPointsPerItem))
            let nearest = Int(coverFlowPosition.rounded())
            if nearest != selectedIndex {
                selectedIndex = nearest
                rebuildCards(animated: false)
                onSelectionChanged?(items[nearest])
            } else {
                needsLayout = true
                layoutSubtreeIfNeeded()
            }
        }

        let momentumEnded = momentum.contains(.ended) || momentum.contains(.cancelled)
        if momentumEnded || phase.contains(.cancelled) {
            snapPreciseScroll()
        } else if phase.contains(.ended), momentum.isEmpty {
            // Momentum can arrive in the next event. Allow that event to retain
            // the exact finger position before settling a non-momentum gesture.
            schedulePreciseScrollSnap(after: 40_000_000)
        } else if isTrackingPreciseScroll, phase.isEmpty, momentum.isEmpty {
            schedulePreciseScrollSnap(after: 120_000_000)
        }
    }

    private func schedulePreciseScrollSnap(after nanoseconds: UInt64) {
        preciseScrollSnapTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            self?.snapPreciseScroll()
        }
    }

    private func snapPreciseScroll() {
        guard isTrackingPreciseScroll else { return }
        preciseScrollSnapTask?.cancel()
        preciseScrollSnapTask = nil
        isTrackingPreciseScroll = false
        let nearest = min(items.count - 1, max(0, Int(coverFlowPosition.rounded())))
        let selectionChanged = nearest != selectedIndex
        selectedIndex = nearest
        coverFlowPosition = CGFloat(nearest)
        rebuildCards(animated: true)
        if selectionChanged { onSelectionChanged?(items[nearest]) }
    }

    private func stopPreciseScrollTracking() {
        preciseScrollSnapTask?.cancel()
        preciseScrollSnapTask = nil
        isTrackingPreciseScroll = false
        coverFlowPosition = CGFloat(selectedIndex)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !usesReducedMotionLayout, bounds.contains(point), let hostLayer = layer else {
            return super.hitTest(point)
        }
        let visibleHost = hostLayer.presentation() ?? hostLayer
        let frontToBack = cards.sorted {
            $0.visualZPosition > $1.visualZPosition
        }
        for card in frontToBack {
            guard !card.isHidden, card.alphaValue > 0 else { continue }
            if card.containsInteractivePoint(point, in: visibleHost) { return card }
        }
        return self
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.35).setFill()
        bounds.fill()
    }

    private func rebuildCards(animated: Bool) {
        guard !items.isEmpty else {
            artworkTasks.values.forEach { $0.cancel() }
            artworkTasks.removeAll()
            artworkTaskTokens.removeAll()
            cards.forEach {
                $0.detachVisualLayer()
                $0.removeFromSuperview()
            }
            cards = []
            return
        }

        let visible: [Int]
        if usesReducedMotionLayout {
            let count = min(5, items.count)
            let start = min(max(0, selectedIndex - count / 2), items.count - count)
            visible = Array(start..<(start + count))
        } else {
            visible = (max(0, selectedIndex - 3)...min(items.count - 1, selectedIndex + 3)).map { $0 }
        }
        let existing = Dictionary(cards.map { ($0.tag, $0) }, uniquingKeysWith: { first, _ in first })
        var retained = Set<ObjectIdentifier>()
        var nextCards: [LevelCoverCardButton] = []
        for index in visible {
            let card = existing[index]
                ?? LevelCoverCardButton(item: items[index], selected: index == selectedIndex)
            card.tag = index
            card.update(item: items[index], selected: index == selectedIndex)
            card.onPress = { [weak self, weak card] in
                guard let self, let card else { return }
                self.selectItem(at: card.tag)
            }
            card.onMove = { [weak self] delta in _ = self?.moveSelection(delta) }
            card.onStart = { [weak self] in self?.startSelectedItem() }
            if card.superview == nil { addSubview(card) }
            if let layer { card.attachVisualLayer(to: layer) }
            retained.insert(ObjectIdentifier(card))
            nextCards.append(card)
        }
        cards.filter { !retained.contains(ObjectIdentifier($0)) }
            .forEach {
                $0.detachVisualLayer()
                $0.removeFromSuperview()
            }
        cards = nextCards
        requestVisibleArtwork()
        animatesNextLayout = animated && window != nil
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    override func layout() {
        super.layout()
        if usesReducedMotionLayout { layoutList() }
        else { layoutCoverFlow(animated: animatesNextLayout) }
        animatesNextLayout = false
    }

    private func layoutCoverFlow(animated: Bool) {
        let centreWidth = min(320, bounds.width * 0.33)
        let centreHeight = min(260, bounds.height * 0.70)
        applyStagePerspective(cameraDistance: centreWidth * 8 / 3)
        let centreX = bounds.midX - centreWidth / 2
        let nearPitch = centreWidth * 1.25 * cos(.pi / 8)
            + max(8, centreWidth * 0.025)
        let outerPitch = centreWidth * 0.14
        let stackDepthStep = max(8, centreWidth * 0.04)
        for card in cards {
            let offset = CGFloat(card.tag) - coverFlowPosition
            let distance = abs(offset)
            let direction: CGFloat = offset == 0 ? 0 : offset > 0 ? 1 : -1
            let spacing = min(distance, 1) * nearPitch
                + max(0, distance - 1) * outerPitch
            let frame = CGRect(
                x: centreX + direction * spacing,
                y: (bounds.height - centreHeight) / 2,
                width: centreWidth,
                height: centreHeight)
            let sideProgress = min(distance, 1)
            let outerDistance = max(0, distance - 1)
            let angle = direction * -.pi / 4 * sideProgress
            let scale = 1.5 - sideProgress * 0.5
            let halfDepth = centreWidth * scale * abs(sin(angle)) / 2
            let frontDepth = centreWidth / 15 * (1 - sideProgress)
                - stackDepthStep * (sideProgress + outerDistance)
            let depth = frontDepth - halfDepth
            let backDepth = depth - halfDepth
            let selectedTieBreak: CGFloat = card.tag == selectedIndex ? 0.0005 : 0
            let stackOrder = 0.001 * (10 - distance) + selectedTieBreak
            var transform = CATransform3DIdentity
            transform = CATransform3DTranslate(transform, 0, 0, depth)
            transform = CATransform3DRotate(transform, angle, 0, 1, 0)
            transform = CATransform3DScale(transform, scale, scale, 1)
            card.presentation = card.tag == selectedIndex ? .focused : .cover
            card.applyCoverFlowLayout(
                frame: frame,
                transform: transform,
                rotationY: angle,
                depth: depth,
                frontDepth: frontDepth,
                backDepth: backDepth,
                scale: scale,
                opacity: 1,
                zPosition: stackOrder,
                animated: animated)
        }
    }

    private func layoutList() {
        layer?.sublayerTransform = CATransform3DIdentity
        let gap: CGFloat = 8
        let rowHeight = max(54, min(76, (bounds.height - gap * CGFloat(cards.count - 1)) / CGFloat(max(1, cards.count))))
        let height = rowHeight * CGFloat(cards.count) + gap * CGFloat(max(0, cards.count - 1))
        var y = max(0, (bounds.height - height) / 2)
        for card in cards {
            card.presentation = .list
            card.applyListLayout(frame: CGRect(
                x: 24, y: y, width: bounds.width - 48, height: rowHeight))
            y += rowHeight + gap
        }
    }

    private func requestVisibleArtwork() {
        let visibleKeys = Set(cards.compactMap { items[$0.tag].artworkKey })
        let obsoleteKeys = artworkTasks.keys.filter { !visibleKeys.contains($0) }
        for key in obsoleteKeys {
            artworkTasks.removeValue(forKey: key)?.cancel()
            artworkTaskTokens.removeValue(forKey: key)
        }
        for card in cards {
            let item = items[card.tag]
            guard let key = item.artworkKey else {
                card.setArtwork(nil, key: nil, failed: false)
                continue
            }
            if let image = artworkImages.image(for: key) {
                card.setArtwork(image, key: key, failed: false)
                continue
            }
            if artworkFailures.contains(key) {
                card.setArtwork(nil, key: key, failed: true)
                continue
            }
            card.setArtwork(nil, key: key, failed: false)
            guard artworkTasks[key] == nil, let artworkLoader else { continue }
            let token = UUID()
            artworkTaskTokens[key] = token
            artworkTasks[key] = Task { [weak self] in
                let bitmap = await artworkLoader(key)
                guard let self else { return }
                guard self.artworkTaskTokens[key] == token else { return }
                self.artworkTaskTokens[key] = nil
                self.artworkTasks[key] = nil
                guard !Task.isCancelled else { return }
                guard let bitmap, let image = bitmap.makeImage() else {
                    self.rememberArtworkFailure(key)
                    self.cards.filter { $0.artworkKey == key }
                        .forEach { $0.setArtwork(nil, key: key, failed: true) }
                    return
                }
                self.artworkFailures.remove(key)
                self.artworkFailureOrder.removeAll { $0 == key }
                self.artworkImages.insert(
                    image, for: key,
                    cost: bitmap.width * bitmap.height * 4)
                self.cards.filter { $0.artworkKey == key }
                    .forEach { $0.setArtwork(image, key: key, failed: false) }
            }
        }
    }

    private func rememberArtworkFailure(_ key: String) {
        guard artworkFailures.insert(key).inserted else { return }
        artworkFailureOrder.append(key)
        while artworkFailureOrder.count > 64 {
            artworkFailures.remove(artworkFailureOrder.removeFirst())
        }
    }
}

@MainActor private final class LevelCoverFlowImageCache {
    private struct Entry {
        let image: NSImage
        let cost: Int
    }

    private let countLimit: Int
    private let costLimit: Int
    private var entries: [String: Entry] = [:]
    private var leastToMostRecent: [String] = []
    private(set) var cost = 0
    var count: Int { entries.count }

    init(countLimit: Int, costLimit: Int) {
        self.countLimit = countLimit
        self.costLimit = costLimit
    }

    func image(for key: String) -> NSImage? {
        guard let entry = entries[key] else { return nil }
        touch(key)
        return entry.image
    }

    func insert(_ image: NSImage, for key: String, cost: Int) {
        if let previous = entries.removeValue(forKey: key) {
            self.cost -= previous.cost
            leastToMostRecent.removeAll { $0 == key }
        }
        guard cost <= costLimit else { return }
        entries[key] = Entry(image: image, cost: cost)
        self.cost += cost
        leastToMostRecent.append(key)
        while entries.count > countLimit || self.cost > costLimit {
            guard let oldest = leastToMostRecent.first else { break }
            leastToMostRecent.removeFirst()
            if let removed = entries.removeValue(forKey: oldest) {
                self.cost -= removed.cost
            }
        }
    }

    private func touch(_ key: String) {
        leastToMostRecent.removeAll { $0 == key }
        leastToMostRecent.append(key)
    }
}

@MainActor private extension LevelPreviewBitmap {
    func makeImage() -> NSImage? {
        guard width > 0, height > 0,
              width <= Int.max / height,
              width * height <= Int.max / 4,
              rgba.count == width * height * 4,
              let provider = CGDataProvider(data: rgba as CFData),
              let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent) else { return nil }
        return NSImage(cgImage: image, size: CGSize(width: width, height: height))
    }
}

@MainActor private final class LevelCoverCardButton: NSButton {
    enum Presentation { case cover, focused, list }

    private lazy var visualLayer = LevelCoverCardSurfaceLayer(card: self)
    private var item: LevelCoverFlowItem
    private var selected: Bool
    private var artwork: NSImage?
    private var artworkFailed = false
    private(set) var artworkKey: String?
    private(set) var coverFlowRotationY: CGFloat = 0
    private(set) var coverFlowDepth: CGFloat = 0
    private(set) var coverFlowFrontDepth: CGFloat = 0
    private(set) var coverFlowBackDepth: CGFloat = 0
    private(set) var coverFlowScale: CGFloat = 1
    var hasArtwork: Bool { artwork != nil }
    var reflectionVisible: Bool { presentation != .list }
    var inputTransformIsIdentity: Bool {
        guard let layer else { return true }
        return CATransform3DEqualToTransform(layer.transform, CATransform3DIdentity)
    }
    var visualZPosition: CGFloat { visualLayer.zPosition }
    var projectedCoverCorners: [CGPoint] {
        projectedCorners(for: visualLayer)
    }
    private func projectedCorners(for layer: CALayer) -> [CGPoint] {
        guard let stageLayer = superview?.layer else { return [] }
        let interactiveBounds = presentation == .list
            ? layer.bounds : coverBounds(for: layer.bounds)
        let corners = [
            CGPoint(x: interactiveBounds.minX, y: interactiveBounds.minY),
            CGPoint(x: interactiveBounds.maxX, y: interactiveBounds.minY),
            CGPoint(x: interactiveBounds.maxX, y: interactiveBounds.maxY),
            CGPoint(x: interactiveBounds.minX, y: interactiveBounds.maxY),
        ]
        let anchor = CGPoint(
            x: layer.bounds.minX + layer.bounds.width * layer.anchorPoint.x,
            y: layer.bounds.minY + layer.bounds.height * layer.anchorPoint.y)
        return corners.map { point in
            let local = SIMD4<Double>(
                Double(point.x - anchor.x), Double(point.y - anchor.y), 0, 1)
            let transform = layer.transform
            let transformed = SIMD4<Double>(
                local.x * Double(transform.m11) + local.y * Double(transform.m21)
                    + local.z * Double(transform.m31) + local.w * Double(transform.m41),
                local.x * Double(transform.m12) + local.y * Double(transform.m22)
                    + local.z * Double(transform.m32) + local.w * Double(transform.m42),
                local.x * Double(transform.m13) + local.y * Double(transform.m23)
                    + local.z * Double(transform.m33) + local.w * Double(transform.m43),
                local.x * Double(transform.m14) + local.y * Double(transform.m24)
                    + local.z * Double(transform.m34) + local.w * Double(transform.m44))
            let projectedW = transformed.w
                + transformed.z * Double(stageLayer.sublayerTransform.m34)
            return CGPoint(
                x: layer.position.x + CGFloat(transformed.x / projectedW),
                y: layer.position.y + CGFloat(transformed.y / projectedW))
        }
    }
    var activeAnimationKeys: [String] {
        let inputKeys = layer?.animationKeys() ?? []
        let visualKeys = visualLayer.animationKeys() ?? []
        return Array(Set(inputKeys + visualKeys)).sorted()
    }
    var onPress: (() -> Void)?
    var onMove: ((Int) -> Void)?
    var onStart: (() -> Void)?
    var presentation: Presentation = .cover {
        didSet {
            guard oldValue != presentation else { return }
            invalidateVisual()
        }
    }

    init(item: LevelCoverFlowItem, selected: Bool) {
        self.item = item
        self.selected = selected
        artworkKey = item.artworkKey
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layer?.masksToBounds = false
        focusRingType = .none
        isBordered = false
        title = ""
        target = self
        action = #selector(invoke)
        setButtonType(.momentaryPushIn)
        setAccessibilityLabel(item.accessibilityName)
        setAccessibilityHelp(selected ? "Selected item" : "Select this item")
        setAccessibilitySelected(selected)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    func invalidateVisual() {
        redrawVisualLayer()
    }

    func attachVisualLayer(to stageLayer: CALayer) {
        guard visualLayer.superlayer !== stageLayer else { return }
        visualLayer.removeFromSuperlayer()
        stageLayer.addSublayer(visualLayer)
        redrawVisualLayer()
    }

    func detachVisualLayer() {
        visualLayer.removeFromSuperlayer()
    }

    func applyCoverFlowLayout(
        frame targetFrame: CGRect,
        transform targetTransform: CATransform3D,
        rotationY: CGFloat,
        depth: CGFloat,
        frontDepth: CGFloat,
        backDepth: CGFloat,
        scale: CGFloat,
        opacity targetOpacity: CGFloat,
        zPosition: CGFloat,
        animated: Bool
    ) {
        coverFlowRotationY = rotationY
        coverFlowDepth = depth
        coverFlowFrontDepth = frontDepth
        coverFlowBackDepth = backDepth
        coverFlowScale = scale
        guard let inputLayer = layer else {
            frame = targetFrame
            alphaValue = targetOpacity
            return
        }
        let displayedInputLayer = inputLayer.presentation() ?? inputLayer
        let displayedVisualLayer = visualLayer.presentation() ?? visualLayer
        let previousInputPosition = displayedInputLayer.position
        let previousInputBounds = displayedInputLayer.bounds
        let previousVisualPosition = displayedVisualLayer.position
        let previousVisualBounds = displayedVisualLayer.bounds
        let previousTransform = displayedVisualLayer.transform
        let previousOpacity = displayedVisualLayer.opacity
        let canAnimate = animated && !frame.isEmpty
        let surfaceSizeChanged = visualLayer.bounds.size != targetFrame.size

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        frame = targetFrame
        inputLayer.transform = CATransform3DIdentity
        visualLayer.bounds = CGRect(origin: .zero, size: targetFrame.size)
        visualLayer.position = CGPoint(x: targetFrame.midX, y: targetFrame.midY)
        visualLayer.zPosition = zPosition
        visualLayer.transform = targetTransform
        visualLayer.opacity = Float(targetOpacity)
        visualLayer.shadowColor = NSColor.black.cgColor
        visualLayer.shadowOffset = CGSize(width: 0, height: 10)
        visualLayer.shadowRadius = selected ? 22 : 12
        visualLayer.shadowOpacity = selected ? 0.52 : 0.32
        CATransaction.commit()
        if surfaceSizeChanged { redrawVisualLayer() }

        guard canAnimate else {
            inputLayer.removeAllAnimations()
            visualLayer.removeAllAnimations()
            return
        }
        let timing = CAMediaTimingFunction(name: .easeInEaseOut)
        animate(layer: inputLayer, keyPath: "position", from: NSValue(point: previousInputPosition),
            duration: 0.34, timing: timing)
        animate(layer: inputLayer, keyPath: "bounds", from: NSValue(rect: previousInputBounds),
            duration: 0.34, timing: timing)
        animate(layer: visualLayer, keyPath: "position", from: NSValue(point: previousVisualPosition),
            duration: 0.34, timing: timing)
        animate(layer: visualLayer, keyPath: "bounds", from: NSValue(rect: previousVisualBounds),
            duration: 0.34, timing: timing)
        animate(layer: visualLayer, keyPath: "transform", from: NSValue(caTransform3D: previousTransform),
            duration: 0.34, timing: timing)
        animate(layer: visualLayer, keyPath: "opacity", from: NSNumber(value: previousOpacity),
            duration: 0.24, timing: timing)
    }

    func applyListLayout(frame targetFrame: CGRect) {
        coverFlowRotationY = 0
        coverFlowDepth = 0
        coverFlowFrontDepth = 0
        coverFlowBackDepth = 0
        coverFlowScale = 1
        guard let inputLayer = layer else {
            frame = targetFrame
            alphaValue = 1
            return
        }
        inputLayer.removeAllAnimations()
        visualLayer.removeAllAnimations()
        let surfaceSizeChanged = visualLayer.bounds.size != targetFrame.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        frame = targetFrame
        inputLayer.transform = CATransform3DIdentity
        visualLayer.bounds = CGRect(origin: .zero, size: targetFrame.size)
        visualLayer.position = CGPoint(x: targetFrame.midX, y: targetFrame.midY)
        visualLayer.zPosition = 0
        visualLayer.transform = CATransform3DIdentity
        visualLayer.opacity = 1
        visualLayer.shadowOpacity = 0
        CATransaction.commit()
        if surfaceSizeChanged { redrawVisualLayer() }
    }

    private func redrawVisualLayer() {
        guard !visualLayer.bounds.isEmpty else {
            visualLayer.setNeedsDisplay()
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        visualLayer.removeAnimation(forKey: "contents")
        visualLayer.contents = nil
        visualLayer.setNeedsDisplay()
        visualLayer.displayIfNeeded()
        visualLayer.removeAnimation(forKey: "contents")
        CATransaction.commit()
    }

    private func animate(
        layer: CALayer,
        keyPath: String,
        from value: Any,
        duration: CFTimeInterval,
        timing: CAMediaTimingFunction
    ) {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = value
        animation.duration = duration
        animation.timingFunction = timing
        layer.add(animation, forKey: "coverFlow.\(keyPath)")
    }

    @objc private func invoke() { onPress?() }

    override func accessibilityPerformPress() -> Bool {
        guard superview != nil, !isHidden else { return false }
        onPress?()
        return true
    }

    override func accessibilityValue() -> Any? { selected ? 1 : 0 }

    override func accessibilityValueDescription() -> String? {
        selected ? "Selected" : "Not selected"
    }

    func update(item: LevelCoverFlowItem, selected: Bool) {
        let selectionChanged = self.selected != selected
        if self.item.artworkKey != item.artworkKey {
            artwork = nil
            artworkFailed = false
            artworkKey = item.artworkKey
        }
        self.item = item
        self.selected = selected
        setAccessibilityLabel(item.accessibilityName)
        setAccessibilitySelected(selected)
        setAccessibilityHelp(item.isAvailable
            ? selected ? "Selected item" : "Select this item"
            : item.availability == .locked ? "Locked item" : "Unavailable item")
        if selectionChanged, selected, window != nil {
            NSAccessibility.post(element: self, notification: .valueChanged)
        }
        invalidateVisual()
    }

    func setArtwork(_ image: NSImage?, key: String?, failed: Bool) {
        guard key == item.artworkKey else { return }
        artwork = image
        artworkKey = key
        artworkFailed = failed
        invalidateVisual()
    }

    func containsInteractivePoint(_ point: CGPoint, in _: CALayer) -> Bool {
        let visibleVisual = visualLayer.presentation() ?? visualLayer
        let corners = projectedCorners(for: visibleVisual)
        guard corners.count == 4 else { return false }
        var windingSign: CGFloat?
        for index in corners.indices {
            let start = corners[index]
            let end = corners[(index + 1) % corners.count]
            let cross = (end.x - start.x) * (point.y - start.y)
                - (end.y - start.y) * (point.x - start.x)
            guard abs(cross) > 0.001 else { continue }
            let sign: CGFloat = cross > 0 ? 1 : -1
            if let windingSign, windingSign != sign { return false }
            windingSign = sign
        }
        return windingSign != nil
    }

    // NSButton tracks the release against the raw frame, but the carousel
    // hit-tests the projected cover. A click on the visible edge of a side
    // card fell outside the raw frame and did nothing.
    override func mouseDown(with event: NSEvent) {
        guard let window, let stage = superview else { return super.mouseDown(with: event) }
        while let next = window.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) {
            guard next.type == .leftMouseUp else { continue }
            let point = stage.convert(next.locationInWindow, from: nil)
            if frame.contains(point) || containsInteractivePoint(point, in: stage.layer ?? CALayer()) {
                onPress?()
            }
            return
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123, 126: onMove?(-1)
        case 124, 125: onMove?(1)
        case 116: onMove?(-5)
        case 121: onMove?(5)
        case 36, 76: onStart?()
        default: super.keyDown(with: event)
        }
    }

    fileprivate func drawVisual(in dirtyRect: NSRect) {
        let surfaceBounds = visualLayer.bounds
        let cardBounds = presentation == .list ? surfaceBounds : coverBounds
        drawCard(in: cardBounds, drawsFocus: true)
        if presentation != .list { drawReflection(of: cardBounds) }
    }

    private var coverBounds: CGRect {
        coverBounds(for: bounds)
    }

    private func coverBounds(for bounds: CGRect) -> CGRect {
        let gap = max(3, min(7, bounds.height * 0.018))
        let reflectionHeight = min(86, bounds.height * 0.21)
        return CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width,
            height: max(1, bounds.height - reflectionHeight - gap))
    }

    private func drawCard(in cardBounds: CGRect, drawsFocus: Bool) {
        let pressed = isHighlighted || selected
        GameStoneButton.draw(cardBounds, selected: pressed, pixel: presentation == .focused ? 2 : 1)
        let content = GameStoneButton.well(cardBounds,
            pixel: presentation == .focused ? 2 : 1).insetBy(dx: 10, dy: 8)
        let alpha: CGFloat = item.isAvailable ? 1 : 0.45
        if presentation == .list, artwork != nil || artworkFailed {
            drawArtworkList(in: content, alpha: alpha)
            drawAvailabilityMark(in: content)
            if drawsFocus { drawFocus(in: cardBounds) }
            return
        }
        if presentation != .list, artwork != nil || artworkFailed {
            drawArtworkCover(in: content, alpha: alpha)
            drawAvailabilityMark(in: content)
            if drawsFocus { drawFocus(in: cardBounds) }
            return
        }
        guard let renderer = GameMenuArtwork.renderer() else {
            if !item.isAvailable {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current?.cgContext.setAlpha(alpha)
            }
            if presentation == .list {
                GamePixelText.draw(item.title, in: CGRect(
                    x: content.minX, y: content.minY,
                    width: content.width * 0.55, height: content.height), maxScale: 1)
                GamePixelText.draw(item.subtitle + "  " + statusDetail, in: CGRect(
                    x: content.minX + content.width * 0.57, y: content.minY,
                    width: content.width * 0.43, height: content.height), maxScale: 1)
            } else {
                GamePixelText.draw(item.title, in: CGRect(
                    x: content.minX, y: content.minY,
                    width: content.width, height: content.height * 0.55), maxScale: 2,
                    palette: selected ? .green : .blue)
                if presentation == .focused {
                    GamePixelText.draw(item.subtitle, in: CGRect(
                        x: content.minX, y: content.minY + content.height * 0.58,
                        width: content.width, height: content.height * 0.18), maxScale: 1)
                    GamePixelText.draw(item.detail, in: CGRect(
                        x: content.minX, y: content.minY + content.height * 0.78,
                        width: content.width, height: content.height * 0.18), maxScale: 1)
                }
            }
            if !item.isAvailable { NSGraphicsContext.restoreGraphicsState() }
            drawAvailabilityMark(in: content)
            if drawsFocus { drawFocus(in: cardBounds) }
            return
        }

        switch presentation {
        case .list:
            let title = CGRect(x: content.minX, y: content.minY,
                width: content.width * 0.57, height: content.height)
            let detail = CGRect(x: title.maxX + 8, y: content.minY,
                width: content.maxX - title.maxX - 8, height: content.height)
            renderer.menuLine(item.title, in: title, face: .small,
                alignment: .left, alpha: alpha, palette: selected ? .green : .blue)
            renderer.menuLine(item.subtitle + "  " + statusDetail, in: detail,
                face: .small, alignment: .right, alpha: alpha, palette: .blue)
        case .cover, .focused:
            let titleHeight = presentation == .focused ? content.height * 0.56 : content.height * 0.68
            renderer.menuParagraph(item.title, in: CGRect(x: content.minX, y: content.minY + 8,
                width: content.width, height: titleHeight), alignment: .center,
                face: presentation == .focused ? .large : .small,
                palette: selected ? .green : .blue, alpha: alpha)
            if presentation == .focused {
                renderer.menuParagraph(item.subtitle + "\n" + statusDetail,
                    in: CGRect(x: content.minX, y: content.minY + titleHeight + 12,
                        width: content.width, height: content.height - titleHeight - 16),
                    alignment: .center, face: .small, palette: .blue, alpha: alpha)
            }
        }
        drawAvailabilityMark(in: content)
        if drawsFocus { drawFocus(in: cardBounds) }
    }

    private func drawArtworkCover(in content: CGRect, alpha: CGFloat) {
        let artworkFrame = coverArtworkFrame(in: content)
        drawArtwork(in: artworkFrame, alpha: alpha)
        if presentation == .focused {
            let label = CGRect(
                x: artworkFrame.minX + 1,
                y: artworkFrame.maxY - min(26, artworkFrame.height * 0.20),
                width: artworkFrame.width - 2,
                height: min(25, artworkFrame.height * 0.20))
            NSColor.black.withAlphaComponent(0.58).setFill()
            label.fill()
            if let renderer = GameMenuArtwork.renderer() {
                renderer.menuLine(item.title, in: label.insetBy(dx: 5, dy: 1),
                    face: .small, alignment: .center,
                    alpha: alpha, palette: selected ? .green : .blue)
            } else {
                GamePixelText.draw(item.title, in: label.insetBy(dx: 5, dy: 1), maxScale: 1,
                    palette: selected ? .green : .blue)
            }
        }
    }

    private func coverArtworkFrame(in content: CGRect) -> CGRect {
        let height = min(content.width / 2, content.height)
        return CGRect(
            x: content.minX,
            y: floor(content.midY - height / 2),
            width: content.width,
            height: height)
    }

    private func drawArtworkList(in content: CGRect, alpha: CGFloat) {
        let thumbnailWidth = min(112, content.width * 0.18)
        let thumbnail = CGRect(
            x: content.minX,
            y: content.minY,
            width: thumbnailWidth,
            height: content.height)
        drawArtwork(in: thumbnail, alpha: alpha)
        let title = CGRect(
            x: thumbnail.maxX + 12,
            y: content.minY,
            width: content.width * 0.42,
            height: content.height)
        let detail = CGRect(
            x: title.maxX + 8,
            y: content.minY,
            width: max(1, content.maxX - title.maxX - 8),
            height: content.height)
        if let renderer = GameMenuArtwork.renderer() {
            renderer.menuLine(item.title, in: title, face: .small,
                alignment: .left, alpha: alpha, palette: selected ? .green : .blue)
            renderer.menuLine(item.subtitle + "  " + statusDetail, in: detail,
                face: .small, alignment: .right, alpha: alpha, palette: .blue)
        } else {
            GamePixelText.draw(item.title, in: title, maxScale: 1,
                palette: selected ? .green : .blue)
            GamePixelText.draw(item.subtitle + "  " + statusDetail, in: detail, maxScale: 1)
        }
    }

    private func drawArtwork(in frame: CGRect, alpha: CGFloat) {
        NSColor.black.setFill()
        frame.fill()
        if let artwork {
            let sourceAspect = artwork.size.width / max(1, artwork.size.height)
            let targetAspect = frame.width / max(1, frame.height)
            let size = sourceAspect > targetAspect
                ? CGSize(width: frame.width, height: frame.width / sourceAspect)
                : CGSize(width: frame.height * sourceAspect, height: frame.height)
            let destination = CGRect(
                x: floor(frame.midX - size.width / 2),
                y: floor(frame.midY - size.height / 2),
                width: ceil(size.width),
                height: ceil(size.height))
            artwork.draw(in: destination, from: .zero, operation: .sourceOver,
                fraction: alpha, respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.none])
        } else if artworkFailed {
            GamePixelText.draw("PREVIEW UNAVAILABLE", in: frame.insetBy(dx: 8, dy: 8), maxScale: 1)
        }
        NSColor(calibratedWhite: 0.72, alpha: alpha).setStroke()
        let border = NSBezierPath(rect: frame.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()
    }

    private func drawReflection(of cardBounds: CGRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let gap = max(3, min(7, bounds.height * 0.018))
        let content = GameStoneButton.well(cardBounds,
            pixel: presentation == .focused ? 2 : 1).insetBy(dx: 10, dy: 8)
        let artworkFrame = coverArtworkFrame(in: content)
        let reflection = CGRect(
            x: artworkFrame.minX,
            y: cardBounds.maxY + gap,
            width: artworkFrame.width,
            height: max(0, bounds.maxY - cardBounds.maxY - gap))
        guard reflection.height > 0 else { return }

        NSGraphicsContext.saveGraphicsState()
        context.clip(to: reflection)
        context.translateBy(x: 0, y: reflection.minY + artworkFrame.maxY)
        context.scaleBy(x: 1, y: -1)
        drawArtwork(in: artworkFrame, alpha: item.isAvailable ? 1 : 0.45)
        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.saveGraphicsState()
        context.clip(to: reflection)
        context.setBlendMode(.destinationIn)
        let colours = [
            NSColor.white.withAlphaComponent(selected ? 0.42 : 0.32).cgColor,
            NSColor.clear.cgColor
        ] as CFArray
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colours,
            locations: [0, 1]) {
            context.drawLinearGradient(gradient,
                start: CGPoint(x: reflection.midX, y: reflection.minY),
                end: CGPoint(x: reflection.midX, y: reflection.maxY),
                options: [])
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private var statusDetail: String {
        item.detail + (item.isAvailable ? "" : "  " + item.availability.displayName.uppercased())
    }

    private func drawAvailabilityMark(in content: CGRect) {
        guard !item.isAvailable else { return }
        let size = min(28, max(18, min(content.width, content.height) * 0.16))
        let box = CGRect(x: content.maxX - size, y: content.minY, width: size, height: size)
        guard item.availability == .locked else {
            GamePixelText.draw("X", in: box.insetBy(dx: 4, dy: 4))
            return
        }
        let pixel = max(1, floor(size / 12))
        let body = CGRect(
            x: box.minX + 2 * pixel,
            y: box.minY + 6 * pixel,
            width: box.width - 4 * pixel,
            height: box.height - 7 * pixel)
        NSColor.white.setFill()
        body.fill()
        let shackle = NSBezierPath()
        shackle.move(to: CGPoint(x: box.minX + 4 * pixel, y: box.minY + 7 * pixel))
        shackle.line(to: CGPoint(x: box.minX + 4 * pixel, y: box.minY + 4 * pixel))
        shackle.curve(
            to: CGPoint(x: box.maxX - 4 * pixel, y: box.minY + 4 * pixel),
            controlPoint1: CGPoint(x: box.minX + 4 * pixel, y: box.minY + pixel),
            controlPoint2: CGPoint(x: box.maxX - 4 * pixel, y: box.minY + pixel))
        shackle.line(to: CGPoint(x: box.maxX - 4 * pixel, y: box.minY + 7 * pixel))
        shackle.lineWidth = 2 * pixel
        NSColor.white.setStroke()
        shackle.stroke()
        NSColor.black.setFill()
        CGRect(x: body.midX - pixel / 2, y: body.midY - pixel,
            width: pixel, height: 3 * pixel).fill()
    }

    private func drawFocus(in rect: CGRect) {
        guard window?.firstResponder === self
                || selected && window?.firstResponder === superview else { return }
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: rect.insetBy(dx: 3, dy: 3))
        path.lineWidth = 2
        path.setLineDash([3, 3], count: 2, phase: 0)
        path.stroke()
    }
}

/// Draws the cover directly in the shared perspective stage.
@MainActor private final class LevelCoverCardSurfaceLayer: CALayer {
    nonisolated(unsafe) private weak var card: LevelCoverCardButton?

    init(card: LevelCoverCardButton) {
        self.card = card
        super.init()
        masksToBounds = false
        allowsEdgeAntialiasing = true
        magnificationFilter = .nearest
        minificationFilter = .nearest
        needsDisplayOnBoundsChange = true
        contentsScale = NSScreen.main?.backingScaleFactor ?? 2
    }

    override init(layer: Any) {
        card = (layer as? LevelCoverCardSurfaceLayer)?.card
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func draw(in context: CGContext) {
        guard let card else { return }
        let transferredContext = LevelCoverFlowSynchronousTransfer(context)
        let drawBounds = bounds
        MainActor.assumeIsolated {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(
                cgContext: transferredContext.value, flipped: true)
            card.drawVisual(in: drawBounds)
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}

/// Transfers a value only for Core Animation's synchronous main-thread display callback.
private struct LevelCoverFlowSynchronousTransfer<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
