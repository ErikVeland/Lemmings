import AppKit
import NxlvKit

/// Reveals one tier per explicit click. Reopening always starts with the nudge.
@MainActor final class LevelHintWindow {
    static let shared = LevelHintWindow()
    private(set) var page: GameMenuPage?
    private(set) var revealedTier = 0
    private(set) var solutionWindow: SolutionReplayWindow?
    private var verification: Task<Void, Never>?

    func show(_ deck: LevelHintDeck, image: CGImage? = nil, owner: NSWindow,
              solutionSession: ClassicSession? = nil, solutionSource: PlayfieldView? = nil,
              onDismiss: @escaping () -> Void = {}) {
        guard page == nil, !deck.stages.isEmpty else { return }
        let page = GameMenuPage(title: "Level hints", subtitle: deck.title)
        page.backTitle = "Back to game"
        let content = LevelHintContent(deck: deck, image: image)
        content.frame = page.body.bounds
        content.autoresizingMask = [.width, .height]
        page.body.addSubview(content)
        revealedTier = 0
        let next = page.addPrimaryAction(deck.checked ? "Reveal the approach" : "Make a small plan") {}
        // No Return shortcut: repeated help keys must not uncover another tier.
        next.keyEquivalent = ""
        var solution: VerifiedSolution?
        var checking = solutionSession != nil
        let refreshAction = { [weak self, weak next] in
            guard let self, let next else { return }
            let final = self.revealedTier + 1 >= deck.stages.count
            next.title = final ? (solution != nil ? "Show solution replay" : checking ? "Checking solution..." : "All hints revealed")
                : self.revealedTier == 1 ? (deck.checked ? "Reveal opening moves" : "Show practice tips")
                : (deck.checked ? "Reveal the approach" : "Make a small plan")
            next.isEnabled = !final || solution != nil
            next.needsDisplay = true
        }
        let action = HintRevealAction { [weak self, weak content, weak solutionSource] in
            guard let self else { return }
            if self.revealedTier + 1 < deck.stages.count {
                self.revealedTier += 1
                content?.tier = self.revealedTier
                refreshAction()
            } else if let solution, let solutionSource, let solutionSession {
                let warning = GameMenuPage(title: "Reveal full solution?")
                warning.setDetail("This shows the winning moves from start to finish. Your attempt stays paused.")
                warning.backTitle = "Keep trying"
                warning.onBack = { [weak warning] in if let warning { GameScreen.shared.dismiss(warning) } }
                let confirm = warning.addPrimaryAction("Show full solution") { [weak self, weak warning] in
                    // A double-click on the last hint must not accept the spoiler prompt.
                    if let event = NSApp.currentEvent, [.leftMouseDown, .leftMouseUp].contains(event.type), event.clickCount > 1 { return }
                    guard let self, let warning else { return }
                    GameScreen.shared.dismiss(warning)
                    let replay = SolutionReplayWindow(solution: solution, source: solutionSource,
                        width: solutionSession.levelWidth, height: solutionSession.levelHeight)
                    self.solutionWindow = replay
                    replay.show(owner: owner)
                }
                confirm.keyEquivalent = ""
                GameScreen.shared.present(warning, owner: owner, focus: warning.controllerBackButton)
            }
        }
        if let solutionSession {
            let initial = solutionSession.initialSimulation
            let root = Bundle.main.resourceURL
            verification = Task { [weak self, weak page] in
                let result = await Task.detached(priority: .userInitiated) {
                    VerifiedSolution.load(initial: initial, from: root)
                }.value
                guard !Task.isCancelled, let self, let page, self.page === page else { return }
                solution = result; checking = false
                refreshAction()
            }
        }
        next.target = action; next.action = #selector(HintRevealAction.reveal)
        content.revealAction = action
        page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
        self.page = page
        let close = { [weak self] in
            self?.verification?.cancel(); self?.verification = nil
            self?.solutionWindow?.stop(); self?.solutionWindow = nil
            self?.page = nil; onDismiss()
        }
        if !GameScreen.shared.present(page, owner: owner, focus: content, onDismiss: close) { close() }
    }
}

@MainActor private final class HintRevealAction: NSObject {
    let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    @objc func reveal() {
        if !ControllerMenuNavigator.isActivating, let event = NSApp.currentEvent,
           [.leftMouseDown, .leftMouseUp].contains(event.type), event.clickCount > 1 { return }
        action()
    }
}

@MainActor private final class LevelHintContent: NSView {
    private let deck: LevelHintDeck
    private let image: CGImage?
    private let progress = HintBitmapText()
    private let heading = HintBitmapText(face: .large)
    private let prose = HintBitmapText()
    private let scroll = NSScrollView()
    private var mapArea = CGRect.zero
    private var resetScroll = true
    private let note = HintBitmapText()
    var revealAction: AnyObject?
    var tier = 0 { didSet { refresh() } }
    override var isFlipped: Bool { true }

    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) {
        let maximum = max(0, prose.frame.height - scroll.contentSize.height)
        let current = scroll.contentView.bounds.minY
        let destination: CGFloat
        switch event.keyCode {
        case 125: destination = current + 24
        case 126: destination = current - 24
        case 121: destination = current + scroll.contentSize.height * 0.9
        case 116: destination = current - scroll.contentSize.height * 0.9
        case 115: destination = 0
        case 119: destination = maximum
        default: super.keyDown(with: event); return
        }
        scroll.contentView.scroll(to: CGPoint(x: 0, y: min(maximum, max(0, destination))))
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    init(deck: LevelHintDeck, image: CGImage?) {
        self.deck = deck; self.image = image
        super.init(frame: .zero)
        for label in [progress, heading, note] { addSubview(label) }
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = prose
        addSubview(scroll)
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    private func refresh() {
        let stage = deck.stages[tier]
        progress.stringValue = "HINT \(tier + 1) OF \(deck.stages.count)"
        heading.stringValue = stage.title
        prose.stringValue = stage.body
        note.stringValue = deck.checked
            ? (tier == 2 ? "Match the direction and adjust crowd spacing. Release rate, timing and your current terrain can change the opening." : "No moves are made for you. Reveal another hint only when you want more detail.")
            : "General coaching for this level."
        setAccessibilityLabel("\(progress.stringValue). \(stage.title). \(stage.body). \(note.stringValue)")
        resetScroll = true
        needsLayout = true; needsDisplay = true
    }
    override func layout() {
        super.layout()
        progress.frame = CGRect(x: 32, y: 0, width: 928, height: 22)
        heading.frame = CGRect(x: 32, y: 30, width: 928, height: 38)
        let noteHeight = note.requiredHeight(width: 928)
        note.frame = CGRect(x: 32, y: bounds.height - noteHeight, width: 928, height: noteHeight)
        let hasMap = image != nil && !deck.stages[tier].moves.isEmpty
        mapArea = CGRect(x: 32, y: note.frame.minY - 136, width: 928, height: 120)
        let proseBottom = hasMap ? mapArea.minY - 16 : note.frame.minY - 24
        scroll.frame = CGRect(x: 32, y: 82, width: 928, height: max(0, proseBottom - 82))
        scroll.layoutSubtreeIfNeeded()
        let width = scroll.contentSize.width
        prose.frame = CGRect(x: 0, y: 0, width: width,
                             height: max(scroll.contentSize.height, prose.requiredHeight(width: width)))
        if resetScroll {
            scroll.contentView.scroll(to: .zero)
            scroll.reflectScrolledClipView(scroll.contentView)
            resetScroll = false
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let stage = deck.stages[tier]
        guard let image, !stage.moves.isEmpty, stage.width > 0, stage.height > 0 else { return }
        let scaleX = Double(image.width) / Double(stage.width)
        let left = max(0, stage.moves.map(\.x).min()! - 100), right = min(stage.width, stage.moves.map(\.x).max()! + 100)
        let crop = CGRect(x: Double(left) * scaleX, y: 0, width: Double(right - left) * scaleX, height: Double(image.height))
        guard let cropped = image.cropping(to: crop) else { return }
        let area = mapArea
        GameStyle.fill(area, .black, radius: 8)
        let fit = min(area.width / CGFloat(right - left), area.height / CGFloat(stage.height))
        let rect = CGRect(x: area.midX - CGFloat(right - left) * fit / 2, y: area.midY - CGFloat(stage.height) * fit / 2,
                          width: CGFloat(right - left) * fit, height: CGFloat(stage.height) * fit)
        NSImage(cgImage: cropped, size: rect.size).draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1,
            respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
        var labels: [CGPoint] = []
        for (index, move) in stage.moves.enumerated() {
            let point = CGPoint(x: rect.minX + CGFloat(move.x - left) * fit, y: rect.minY + CGFloat(move.y) * fit)
            var label = CGPoint(x: point.x, y: max(area.minY + 15, point.y - 25))
            while labels.contains(where: { hypot($0.x - label.x, $0.y - label.y) < 28 }) { label.x += 30 }
            labels.append(label)
            let line = NSBezierPath(); line.move(to: label); line.line(to: point)
            GameStyle.gold.setStroke(); line.lineWidth = 2; line.stroke()
            GameStyle.fill(CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6), .white, radius: 3)
            GameStyle.fill(CGRect(x: label.x - 13, y: label.y - 13, width: 26, height: 26), GameStyle.gold, radius: 13)
            GameStyle.fill(CGRect(x: label.x - 11, y: label.y - 11, width: 22, height: 22), .black, radius: 11)
            let caption = CGRect(x: label.x - 10, y: label.y - 8, width: 20, height: 18)
            if let font = GameMenuArtwork.renderer() {
                font.menuLine(String(index + 1), in: caption)
            } else { GamePixelText.draw(String(index + 1), in: caption) }
        }
    }
}

/// Bitmap text keeps its complete readable value available to assistive tools.
@MainActor final class HintBitmapText: NSView {
    private let renderer = GameMenuArtwork.renderer()
    private let face: ClassicMacUserInterface.Face
    var stringValue = "" {
        didSet {
            setAccessibilityValue(stringValue)
            needsDisplay = true
        }
    }
    override var isFlipped: Bool { true }
    init(face: ClassicMacUserInterface.Face = .small) {
        self.face = face
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    private var cellWidth: Int { renderer?.font(face)?.cellWidth ?? 12 }
    private var lineHeight: Int { (renderer?.font(face)?.cellHeight ?? 14) + 6 }
    func lines(width: CGFloat) -> [String] {
        MacInterfaceRenderer.menuLines(stringValue, columns: max(1, Int(width) / cellWidth))
    }
    func requiredHeight(width: CGFloat) -> CGFloat { CGFloat(lines(width: width).count * lineHeight) }
    override func draw(_ dirtyRect: NSRect) {
        for (index, line) in lines(width: bounds.width).enumerated() {
            let rect = CGRect(x: 0, y: CGFloat(index * lineHeight), width: bounds.width, height: CGFloat(lineHeight))
            if let renderer, renderer.font(face) != nil {
                renderer.menuLine(line, in: rect, face: face, alignment: .left)
            } else {
                let width = CGFloat(line.count * 12)
                GamePixelText.draw(line, in: CGRect(x: 0, y: rect.minY, width: width, height: 14))
            }
        }
    }
}
