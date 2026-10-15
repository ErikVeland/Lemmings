#if os(macOS)
import AppKit
import LemmingsAppCore
import LemmingsAudio
import NxlvKit

/// Hints move one tier per deliberate action. Reopening starts with the nudge.
@MainActor final class LevelHintWindow {
    static let shared = LevelHintWindow()
    private(set) var page: GameMenuPage?
    private(set) var revealedTier = 0
    private(set) var solutionWindow: SolutionReplayWindow?
    private var verification: Task<Void, Never>?
    private var retainedRunID: UUID?
    private var retainedOwnerKey = ""
    private weak var retainedOwner: NSWindow?
    private var pauseGame: (() -> Void)?
    private weak var ghostSource: PlayfieldView?
    private var gameSelector: SolutionSwitchView?
    private var switchMonitor: Any?
    func hasSolution(for runID: UUID) -> Bool { retainedRunID == runID && solutionWindow != nil }

    func clearSolution() {
        if let replay = solutionWindow, GameScreen.shared.contains(replay.page) { GameScreen.shared.dismiss(replay.page) }
        solutionWindow?.stop(); solutionWindow = nil
        ghostSource?.solutionGhost = nil; ghostSource?.ghostSolutionEnabled = false; ghostSource = nil
        gameSelector?.removeFromSuperview(); gameSelector = nil
        retainedRunID = nil; retainedOwner = nil; pauseGame = nil
        retainedOwnerKey = ""
        if let switchMonitor { NSEvent.removeMonitor(switchMonitor) }; switchMonitor = nil
    }

    func toggleGhostSolution() {
        guard let source = ghostSource, source.solutionGhost != nil else { return }
        source.ghostSolutionEnabled.toggle()
        gameSelector?.ghostEnabled = source.ghostSolutionEnabled
    }

    func reattachSolutionSelector(to owner: NSWindow) {
        guard retainedOwner === owner, let selector = gameSelector, let root = owner.contentView else { return }
        if selector.superview !== root {
            selector.removeFromSuperview()
            root.addSubview(selector, positioned: .above, relativeTo: nil)
        }
        selector.frame = CGRect(x: max(8, (root.bounds.width - 320) / 2),
            y: root.isFlipped ? 8 : max(0, root.bounds.height - 108), width: 320, height: 100)
        selector.autoresizingMask = [.minXMargin, .maxXMargin, root.isFlipped ? .maxYMargin : .minYMargin]
    }

    func selectSolutionMode(_ mode: SolutionReplayMode) {
        guard let replay = solutionWindow, let owner = retainedOwner else { return }
        if mode == .solution, GameScreen.shared.contains(replay.page) { return }
        if mode == .game, !GameScreen.shared.contains(replay.page), page == nil { return }
        pauseGame?()
        replay.suspend()
        if mode == .game {
            GameScreen.shared.dismiss(replay.page)
            if let page { GameScreen.shared.dismiss(page) }
            pauseGame?()
            gameSelector?.mode = .game
        } else if !GameScreen.shared.contains(replay.page) {
            if let page { GameScreen.shared.dismiss(page) }
            replay.show(owner: owner)
        }
    }

    func rebindSolution(session: ClassicSession?, owner: NSWindow, runID: UUID, ownerKey: String, pause: @escaping () -> Void) {
        guard let replay = solutionWindow else { return }
        guard let session, retainedOwner === owner, retainedOwnerKey == ownerKey,
              ClassicDOSReplayRecorder.stateHash(of: session.initialSimulation)
                == ClassicDOSReplayRecorder.stateHash(of: replay.playback.solution.initial) else { clearSolution(); return }
        retainedRunID = runID; pauseGame = pause
        replay.suspend()
    }

    private func retain(_ replay: SolutionReplayWindow, source: PlayfieldView, owner: NSWindow, runID: UUID?, ownerKey: String, pause: @escaping () -> Void) {
        solutionWindow = replay; retainedOwner = owner; retainedRunID = runID; pauseGame = pause
        retainedOwnerKey = ownerKey
        ghostSource = source
        source.solutionGhost = ClassicSolutionGhost(initial: replay.playback.solution.initial, replay: replay.playback.solution.replay)
        source.ghostSolutionEnabled = false
        replay.onReturnToGame = { [weak self] in self?.selectSolutionMode(.game) }
        if let root = owner.contentView {
            let selector = SolutionSwitchView(frame: CGRect(x: max(8, (root.bounds.width - 320) / 2), y: root.isFlipped ? 8 : max(0, root.bounds.height - 108), width: 320, height: 100))
            selector.autoresizingMask = [.minXMargin, .maxXMargin, root.isFlipped ? .maxYMargin : .minYMargin]
            selector.onSelect = { [weak self] mode in self?.selectSolutionMode(mode) }
            selector.onToggleGhost = { [weak self] in self?.toggleGhostSolution() }
            selector.onPointerEntered = { [weak source] in source?.clearPointer() }
            root.addSubview(selector, positioned: .above, relativeTo: nil)
            gameSelector = selector
        }
        switchMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak owner] event in
            guard let self, let owner, event.window === owner, owner.isKeyWindow,
                  !(owner.firstResponder is NSTextView),
                  event.modifierFlags.intersection([.command, .control, .option, .shift]) == .control,
                  event.keyCode == 48,
                  !GameScreen.shared.isPresented || GameScreen.shared.controllerPage(in: owner) === self.solutionWindow?.page else { return event }
            if !event.isARepeat { self.selectSolutionMode(GameScreen.shared.contains(replay.page) ? .game : .solution) }
            return nil
        }
    }

    func show(_ deck: LevelHintDeck, image: CGImage? = nil, owner: NSWindow,
              solutionSession: ClassicSession? = nil, solutionSource: PlayfieldView? = nil,
              solutionEffects: SoundEffectPlayer? = nil,
              runID: UUID? = nil, ownerKey: String = "", pauseForSolution: @escaping () -> Void = {},
              onDismiss: @escaping () -> Void = {}) {
        guard page == nil, !deck.stages.isEmpty else { return }
        if retainedRunID != runID || solutionSession == nil { clearSolution() }
        let page = GameMenuPage(title: L10n.text("Level hints"), subtitle: deck.title)
        page.backTitle = L10n.text("Back to game")
        let content = LevelHintContent(deck: deck, image: image)
        content.frame = page.body.bounds
        content.autoresizingMask = [.width, .height]
        page.body.addSubview(content)
        revealedTier = 0
        let previous = page.addSecondaryAction(L10n.text("Previous")) {}
        previous.setAccessibilityLabel(L10n.text("Previous hint"))
        previous.isEnabled = false
        let next = page.addPrimaryAction(deck.checked ? L10n.text("Reveal the approach") : L10n.text("Make a small plan")) {}
        // No Return shortcut: repeated help keys must not uncover another tier.
        next.keyEquivalent = ""
        var solution: VerifiedSolution?
        var checking = solutionSession != nil
        let refreshAction = { [weak self, weak next, weak previous] in
            guard let self, let next else { return }
            previous?.isEnabled = self.revealedTier > 0
            previous?.needsDisplay = true
            let final = self.revealedTier + 1 >= deck.stages.count
            next.title = final ? (solution != nil ? L10n.text("Show solution replay") : checking ? L10n.text("Checking solution...") : L10n.text("All hints revealed"))
                : self.revealedTier == 1 ? (deck.checked ? L10n.text("Reveal opening moves") : L10n.text("Show practice tips"))
                : (deck.checked ? L10n.text("Reveal the approach") : L10n.text("Make a small plan"))
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
                if self.solutionWindow != nil { self.selectSolutionMode(.solution); return }
                let warning = GameMenuPage(title: L10n.text("Reveal full solution?"))
                warning.setDetail(L10n.text("This shows the winning moves from start to finish. Your attempt stays paused."))
                warning.backTitle = L10n.text("Keep trying")
                warning.onBack = { [weak warning] in if let warning { GameScreen.shared.dismiss(warning) } }
                let confirm = warning.addPrimaryAction(L10n.text("Show full solution")) { [weak self, weak warning] in
                    // A double-click on the last hint must not accept the spoiler prompt.
                    if let event = NSApp.currentEvent, [.leftMouseDown, .leftMouseUp].contains(event.type), event.clickCount > 1 { return }
                    guard let self, let warning else { return }
                    GameScreen.shared.dismiss(warning)
                    let replay = SolutionReplayWindow(solution: solution, source: solutionSource,
                        width: solutionSession.levelWidth, height: solutionSession.levelHeight, effects: solutionEffects)
                    self.retain(replay, source: solutionSource, owner: owner, runID: runID, ownerKey: ownerKey, pause: pauseForSolution)
                    self.selectSolutionMode(.solution)
                }
                confirm.keyEquivalent = ""
                warning.preferControllerControl(warning.controllerBackButton)
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
        let moveHint: (Int) -> Void = { [weak self, weak content] direction in
            guard let self else { return }
            let tier = min(deck.stages.count - 1, max(0, self.revealedTier + direction))
            guard tier != self.revealedTier else { return }
            self.revealedTier = tier
            content?.tier = tier
            refreshAction()
        }
        (previous as? GameActionButton)?.onPress = { moveHint(-1) }
        page.onHorizontalNavigation = moveHint
        next.target = action; next.action = #selector(HintRevealAction.reveal)
        content.revealAction = action
        page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
        self.page = page
        let close = { [weak self] in
            self?.verification?.cancel(); self?.verification = nil
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
        progress.stringValue = L10n.text("HINT \(tier + 1) OF \(deck.stages.count)")
        heading.stringValue = stage.title
        prose.stringValue = stage.body
        note.stringValue = deck.checked
            ? (tier == 2 ? L10n.text("Match the direction and adjust crowd spacing. Release rate, timing and your current terrain can change the opening.") : L10n.text("No moves are made for you. Reveal another hint only when you want more detail."))
            : L10n.text("General coaching for this level.")
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(L10n.text("Hint text"))
        setAccessibilityHelp(L10n.text("Left and right arrows change hints. Up and down arrows scroll the text."))
        resetScroll = true
        needsLayout = true; needsDisplay = true
        NSAccessibility.post(element: heading, notification: .valueChanged)
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
            respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
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
    private var lineHeight: Int {
        max((renderer?.font(face)?.cellHeight ?? 14) + 6,
            (renderer?.font(face)?.height(of: MacInterfaceRenderer.menuText(stringValue)) ?? 14) + 2)
    }
    func lines(width: CGFloat) -> [String] {
        MacInterfaceRenderer.menuLines(stringValue, columns: max(1, Int(width) / cellWidth))
    }
    func requiredHeight(width: CGFloat) -> CGFloat { CGFloat(lines(width: width).count * lineHeight) }
    override func draw(_ dirtyRect: NSRect) {
        for (index, line) in lines(width: bounds.width).enumerated() {
            let rect = CGRect(x: 0, y: CGFloat(index * lineHeight), width: bounds.width, height: CGFloat(lineHeight))
            if let renderer, renderer.font(face) != nil {
                renderer.menuLine(line, in: rect, face: face, alignment: .left, palette: face == .large ? .green : .blue)
            } else {
                let width = CGFloat(line.count * 12)
                GamePixelText.draw(line, in: CGRect(x: 0, y: rect.minY, width: width, height: 14))
            }
        }
    }
}
#endif
