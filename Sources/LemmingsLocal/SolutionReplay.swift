import AppKit
import NxlvKit

/// A solution is usable only after the current engine reproduces its winning outcome.
struct VerifiedSolution: Sendable {
    let replay: ClassicDOSReplay
    let initial: ClassicDOSSimulation

    static func load(initial: ClassicDOSSimulation, from root: URL?) -> Self? {
        guard let root,
              let data = try? Data(contentsOf: root.appendingPathComponent("Hints/solutions.json")),
              let records = try? JSONDecoder().decode([String: ClassicDOSReplay].self, from: data),
              let replay = records[ClassicDOSReplayRecorder.stateHash(of: initial)] else { return nil }
        return validate(replay, initial: initial)
    }

    static func validate(_ replay: ClassicDOSReplay, initial: ClassicDOSSimulation) -> Self? {
        guard let expected = replay.expected, expected.didWin,
              expected.ticks > 0, expected.ticks <= ClassicDOSReplayPlayer.defaultTickLimit,
              replay.events.allSatisfy({ $0.tick >= ($0.afterTick == true ? 0 : 1) && $0.tick <= expected.ticks }),
              let outcome = try? ClassicDOSReplayPlayer.run(replay, simulation: initial),
              outcome == expected, outcome.didWin else { return nil }
        return Self(replay: replay, initial: initial)
    }
}

/// Playback owns its simulation and never calls the campaign, saves or result handlers.
@MainActor final class SolutionPlayback {
    let solution: VerifiedSolution
    private(set) var session: ClassicSession
    private let events: [Int: [ClassicDOSReplayEvent]]
    private(set) var lastAssignment: (id: Int, skill: ClassicSkill)?

    init(_ solution: VerifiedSolution, width: Int, height: Int) {
        self.solution = solution
        var simulation = solution.initial
        for event in solution.replay.events where event.afterTick != true {
            if case let .assign(id, skill) = event.action {
                precondition(simulation.schedule(.init(tick: event.tick, lemmingID: id, skill: skill)))
            }
        }
        events = Dictionary(grouping: solution.replay.events, by: \.tick)
        session = ClassicSession(simulation: simulation, width: width, height: height)
        for event in events[0] ?? [] { apply(event.action) }
    }

    /// Moves the read-only replay to a nearby recorded tick.
    func seek(by delta: Int) {
        let target = max(0, min(solution.replay.expected?.ticks ?? 0, session.currentTick + delta))
        guard target != session.currentTick else { return }
        var simulation = solution.initial
        for event in solution.replay.events where event.afterTick != true {
            if case let .assign(id, skill) = event.action {
                precondition(simulation.schedule(.init(tick: event.tick, lemmingID: id, skill: skill)))
            }
        }
        session = ClassicSession(simulation: simulation, width: session.levelWidth, height: session.levelHeight)
        for event in events[0] ?? [] { apply(event.action) }
        for _ in 0..<target { tick() }
    }

    func tick() {
        guard !session.isComplete else { return }
        lastAssignment = nil
        let next = session.currentTick + 1
        for event in events[next] ?? [] where event.afterTick != true {
            if case let .assign(id, skill) = event.action { lastAssignment = (id, skill) }
            else { apply(event.action) }
        }
        session.tick()
        for event in events[next] ?? [] where event.afterTick == true { apply(event.action) }
    }

    private func apply(_ action: ClassicDOSReplayAction) {
        switch action {
        case let .assign(id, skill):
            if let index = ClassicSkill.allCases.firstIndex(of: skill), session.assign(skillIndex: index, to: id) == nil {
                lastAssignment = (id, skill)
            }
        case let .releaseRate(value): session.adjustRate(by: value - session.rate)
        case .nuke: session.nuke()
        }
    }
}

@MainActor final class SolutionReplayWindow {
    let page: GameMenuPage
    private(set) var playback: SolutionPlayback
    let field = PlayfieldView(frame: .zero)
    private let marker = SolutionMarker(frame: .zero)
    private let status = HintBitmapText()
    private var timer: Timer?
    private var paused = false
    private var speed = 1
    private var assignmentUntil = 0.0
    private var followedID: Int?
    private weak var transport: NSButton?
    private weak var speedButton: NSButton?

    init(solution: VerifiedSolution, source: PlayfieldView, width: Int, height: Int) {
        playback = SolutionPlayback(solution, width: width, height: height)
        page = GameMenuPage(title: "Solution replay", subtitle: solution.replay.title)
        page.backTitle = "Back to hints"
        field.frame = CGRect(x: 0, y: 70, width: 992, height: 340)
        field.classicScene = source.classicScene; field.macScene = source.macScene
        field.macArtwork = source.macArtwork; field.assets = source.assets; field.palette = source.palette
        field.levelImage = source.levelImage; field.imageScale = source.imageScale
        field.presentsHDR = false; field.session = playback.session
        field.viewport = source.viewport
        field.viewport.levelSize = CGSize(width: width, height: height)
        field.viewport.viewSize = field.bounds.size
        field.viewport.zoom = min(3, field.bounds.height / CGFloat(height))
        field.viewport.clamp()
        page.body.addSubview(field)
        marker.frame = field.frame; marker.field = field
        page.body.addSubview(marker)
        status.frame = CGRect(x: 24, y: 422, width: 944, height: 32)
        page.body.addSubview(status)
        transport = page.addPrimaryAction("Pause") { [weak self] in
            guard let self else { return }
            if self.playback.session.isComplete {
                self.playback = SolutionPlayback(solution, width: width, height: height)
                self.field.session = self.playback.session
                self.marker.point = nil
                self.assignmentUntil = 0
                self.followedID = nil
                self.paused = false
            } else { self.paused.toggle() }
            self.refresh()
        }
        transport?.keyEquivalent = " "
        transport?.setAccessibilityLabel("Play or pause solution replay. Space.")
        let back = GameActionButton(title: "Back 1s", primary: false) { [weak self] in
            guard let self else { return }
            self.paused = true
            self.playback.seek(by: -ClassicDOSRules.ticksPerSecond)
            self.refresh()
        }
        back.frame = CGRect(x: 24, y: 8, width: 136, height: 44)
        back.setAccessibilityLabel("Move the solution replay back one second.")
        page.body.addSubview(back)
        let step = GameActionButton(title: "Step +1", primary: false) { [weak self] in
            guard let self else { return }
            self.paused = true
            self.playback.seek(by: 1)
            self.refresh()
        }
        step.frame = CGRect(x: 168, y: 8, width: 136, height: 44)
        step.setAccessibilityLabel("Step the solution replay forward one tick.")
        page.body.addSubview(step)
        let rate = GameActionButton(title: "1x", primary: false) { [weak self] in
            guard let self else { return }
            self.speed = self.speed == 1 ? 3 : self.speed == 3 ? 10 : 1
            self.speedButton?.title = "\(self.speed)x"
            self.speedButton?.needsDisplay = true
        }
        rate.setAccessibilityLabel("Playback speed. Cycle 1, 3 and 10 times.")
        rate.frame = CGRect(x: 832, y: 8, width: 136, height: 44)
        page.body.addSubview(rate); speedButton = rate
        page.onBack = { [weak self] in if let self { GameScreen.shared.dismiss(self.page) } }
        refresh()
    }

    func show(owner: NSWindow) {
        guard GameScreen.shared.present(page, owner: owner, onDismiss: { [weak self] in self?.stop() }) else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1 / Double(ClassicDOSRules.ticksPerSecond), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advance() }
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    func advance() {
        guard !paused, !playback.session.isComplete, !page.isHidden else { return }
        for _ in 0..<speed {
            playback.tick()
            if let assignment = playback.lastAssignment,
               let lemming = playback.session.lemmings.first(where: { $0.id == assignment.id }) {
                followedID = lemming.id
                field.viewport.center(on: Double(lemming.x))
                marker.point = CGPoint(x: lemming.x, y: lemming.y)
                status.stringValue = "Tick \(playback.session.currentTick): \(assignment.skill.rawValue)"
                assignmentUntil = ProcessInfo.processInfo.systemUptime + 1.5
                // Keep each skill assignment visible even at high playback speeds.
                break
            }
        }
        if let followed = playback.session.lemmings.first(where: { $0.id == followedID }) ?? playback.session.lemmings.first {
            field.viewport.center(on: Double(followed.x))
        }
        refresh()
    }

    private func refresh() {
        if playback.session.isComplete {
            status.stringValue = "\(playback.session.simulation.savedCount) rescued"
            marker.point = nil
        } else if ProcessInfo.processInfo.systemUptime > assignmentUntil {
            let total = playback.solution.replay.expected?.ticks ?? 0
            status.stringValue = "Tick \(playback.session.currentTick) / \(total)"
            marker.point = nil
        }
        transport?.title = playback.session.isComplete ? "Replay" : paused ? "Play" : "Pause"
        transport?.needsDisplay = true
        field.needsDisplay = true; marker.needsDisplay = true
    }
}

@MainActor private final class SolutionMarker: NSView {
    weak var field: PlayfieldView?
    var point: CGPoint?
    override var isFlipped: Bool { true }
    // The replay surface accepts viewing only, never gameplay input.
    override func hitTest(_ point: NSPoint) -> NSView? { self }
    override func draw(_ dirtyRect: NSRect) {
        guard let field, let point else { return }
        let center = field.viewport.viewPoint(fromLevel: point)
        NSColor.green.setStroke()
        let box = CGRect(x: center.x - 12, y: center.y - 18, width: 24, height: 30)
        let path = NSBezierPath(rect: box)
        path.lineWidth = 2; path.stroke()
    }
}
