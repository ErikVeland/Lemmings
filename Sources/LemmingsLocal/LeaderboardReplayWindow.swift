#if os(macOS)
import AppKit
import NxlvKit
import LemmingsAppCore

/// A level supplies its shipped renderer and an independent starting simulation.
@MainActor struct LeaderboardReplayContext {
    let conditions: String
    let initial: ActionReplayState
    let makeField: () throws -> (NSView, (ActionReplayState) -> Void)
    let suspend: () -> (() -> Void)
}

@MainActor final class LeaderboardReplayWindow {
    static var current: LeaderboardReplayWindow?
    private static var requestID = UUID()
    let page = SolutionReplayPage()
    private(set) var cursor: ActionReplayCursor
    let field: NSView
    private let render: (ActionReplayState) -> Void
    private let title: String
    private var resume: (() -> Void)?
    private var timer: Timer?
    private var paused = true
    private var speed = 1
    private let status = GameLabel()
    private let skillPanel = ReplaySkillPanel(frame: .zero)
    private var buttons: [GameActionButton] = []
    private var play: GameActionButton!
    private var credit = 0.0
    private var lastTime = 0.0
    init(cursor replayCursor: ActionReplayCursor, field: NSView, render: @escaping (ActionReplayState) -> Void, title: String) {
        self.cursor = replayCursor; self.field = field; self.render = render; self.title = title
        status.isEditable = false; status.isSelectable = false; status.isBordered = false; status.drawsBackground = false
        page.addSubview(field); page.addSubview(status); page.addSubview(skillPanel)
        page.setAccessibilityLabel(title + ". Action replay. Space or P plays or pauses. Left and right seek one second.")
        func button(_ text: String, primary: Bool = false, action: @escaping () -> Void) -> GameActionButton {
            let b = GameActionButton(title: text, primary: primary, onPress: action)
            buttons.append(b); page.addSubview(b); return b
        }
        _ = button(L10n.text("Back")) { [weak self] in self?.close() }
        _ = button(L10n.text("Restart")) { [weak self] in self?.seek(0) }
        _ = button(L10n.text("Back 1s")) { [weak self] in guard let self else { return }; seek(cursor.state.tick - Int(cursor.state.ticksPerSecond)) }
        play = button(L10n.text("Play"), primary: true) { [weak self] in self?.toggle() }
        _ = button(L10n.text("Step +1")) { [weak self] in guard let self else { return }; seek(cursor.state.tick + 1) }
        _ = button(L10n.text("Ahead 1s")) { [weak self] in guard let self else { return }; seek(cursor.state.tick + Int(cursor.state.ticksPerSecond)) }
        _ = button(L10n.text("Speed 1x")) { [weak self] in
            guard let self else { return }; speed = speed == 1 ? 2 : speed == 2 ? 5 : 1
            buttons.last?.title = L10n.text("Speed \(speed)x")
        }
        page.onLayout = { [weak self] in self?.layout() }
        page.onKey = { [weak self] event in
            guard let self else { return false }
            guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return false }
            switch event.keyCode {
            case 49, 35: toggle(); return true
            case 123: seek(cursor.state.tick - Int(cursor.state.ticksPerSecond)); return true
            case 124: seek(cursor.state.tick + Int(cursor.state.ticksPerSecond)); return true
            case 53: close(); return true
            default: return false
            }
        }
        refresh()
    }
    private func layout() {
        let w = page.bounds.width, h = page.bounds.height
        let columns = max(1, min(7, Int(w / 130))), rows = (buttons.count + columns - 1) / columns
        field.frame = CGRect(x: 0, y: 32, width: w, height: max(1, h - 42 - CGFloat(rows) * 46))
        status.frame = CGRect(x: 12, y: 2, width: w - 24, height: 26)
        let width = (w - 24 - CGFloat(columns - 1) * 6) / CGFloat(columns)
        render(cursor.state)
        layoutSkillPanel()
        for (i, b) in buttons.enumerated() {
            b.frame = CGRect(x: 12 + CGFloat(i % columns) * (width + 6), y: field.frame.maxY + 6 + CGFloat(i / columns) * 46, width: width, height: 40)
        }
    }
    func show(owner: NSWindow, resume: @escaping () -> Void) {
        self.resume = resume
        guard GameScreen.shared.present(page, owner: owner, focus: page, onDismiss: { [weak self] in self?.stop() }) else { stop(); return }
        lastTime = ProcessInfo.processInfo.systemUptime
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advance() }
        }
    }
    private func advance() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = min(0.1, max(0, now - lastTime)); lastTime = now
        guard !paused else { return }
        credit += elapsed * cursor.state.ticksPerSecond * Double(speed)
        do {
            while credit >= 1, cursor.state.tick < cursor.replay.ticks { try cursor.step(); credit -= 1 }
            if cursor.state.tick == cursor.replay.ticks { paused = true; credit = 0 }
            refresh()
        } catch { paused = true; status.stringValue = L10n.text("Replay unavailable") }
    }
    func seek(_ tick: Int) {
        paused = true; credit = 0
        do { try cursor.seek(to: tick); refresh() }
        catch { status.stringValue = L10n.text("Replay unavailable") }
    }
    private func toggle() {
        if cursor.state.tick == cursor.replay.ticks { seek(0) }
        paused.toggle(); credit = 0; lastTime = ProcessInfo.processInfo.systemUptime; refresh()
    }
    private func layoutSkillPanel() {
        let size = skillPanel.logicalSize
        skillPanel.frame = CGRect(x: max(8, page.bounds.width - size.width - 8), y: field.frame.minY + 8,
            width: size.width, height: size.height)
        skillPanel.bounds.size = size
    }
    private func refresh() {
        skillPanel.update(stocks: ReplaySkillPresentation.stocks(cursor.state),
            uses: cursor.skillUses.suffix(3).map { .init(tick: $0.tick, name: $0.name) },
            tick: cursor.state.tick, title: cursor.state.engine == "lemmings3" ? L10n.text(L10n.text("TOOLS HELD")) : L10n.text("LEFT"))
        layoutSkillPanel()
        render(cursor.state); field.needsDisplay = true
        field.setAccessibilityLabel(L10n.text("Action replay. \(cursor.state.saved) of \(cursor.state.population) saved. Tick \(cursor.state.tick) of \(cursor.replay.ticks)."))
        status.stringValue = title + "   " + "\(ArcadeView.time(Double(cursor.state.tick) / cursor.state.ticksPerSecond)) / \(ArcadeView.time(Double(cursor.replay.ticks) / cursor.state.ticksPerSecond))"
        play?.title = paused ? L10n.text("Play") : L10n.text("Pause")
        play?.setAccessibilityLabel(paused ? L10n.text("Play action replay") : L10n.text("Pause action replay"))
    }
    func close() { GameScreen.shared.dismiss(page) }
    private func stop() {
        timer?.invalidate(); timer = nil
        let restore = resume; resume = nil; restore?()
        if Self.current === self { Self.current = nil }
    }
    static func open(_ replay: LeaderboardActionReplay, context: LeaderboardReplayContext?, owner: NSWindow?, title: String) {
        guard let context, let owner, context.conditions == replay.conditions.fingerprint else {
            GameScreen.shared.message(L10n.text("Replay unavailable"), detail: L10n.text("Open this level with its original game data to watch the action replay.")); return
        }
        let ticket = UUID(); requestID = ticket
        let sourcePage = GameScreen.shared.controllerPage(in: owner)
        Task {
            do {
                let cursor = try await Task.detached(priority: .userInitiated) { try replay.checked(initial: context.initial) }.value
                guard requestID == ticket, GameScreen.shared.controllerPage(in: owner) === sourcePage else { return }
                let (field, render) = try context.makeField()
                let controller = Self(cursor: cursor, field: field, render: render, title: title)
                current = controller; controller.show(owner: owner, resume: context.suspend())
            } catch {
                guard requestID == ticket, GameScreen.shared.controllerPage(in: owner) === sourcePage else { return }
                GameScreen.shared.message(L10n.text("Replay unavailable"), detail: L10n.text("The actions do not reproduce this run with the installed engine and level data."))
            }
        }
    }
}
#endif
