import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore

extension MenuAudit {
    @MainActor static func checkHotSeatFlow(typography: GameMenuTypography, output: URL) async throws {
        var seat = MobileHotSeat(host: "LEM", players: ["AB"])!
        seat.pass(to: "AB")
        let loss = seat.choices(didWin: false)
        let win = seat.choices(didWin: true)
        guard loss.first?.player == "LEM", win.first?.player == "LEM" else { throw Failure.invalidTargets }
        func actions(_ choices: [MobileHotSeat.Choice]) -> [GameFrontEnd.Action] {
            choices.enumerated().map { index, choice in
                .init(String(index), (choice.kind == .next ? "Next: " : "Retry: ") + choice.player, primary: choice.primary)
            } + [.init("library", "Library")]
        }
        typealias State = (String, String?, MobileTurnArt.Role, GameFrontEnd.Page)
        let level = "Fun 1  Just Dig!"
        var states: [State] = [
            ("solo-pause", "LEM", .current, .init(title: "Paused", subtitle: level, footer: [.init("resume", "Resume", primary: true)])),
            ("solo-ready", "LEM", .next, .init(title: "Just Dig!", subtitle: "Fun 1", footer: [.init("start", "Start", primary: true)], preview: true)),
            ("solo-result", "LEM", .result, .init(title: "Level complete", subtitle: level, footer: [.init("library", "Library"), .init("next", "Next level", primary: true)], preview: true)),
            ("ready-host", "LEM", .next, .init(title: "LEM", subtitle: level, footer: [.init("ready", "Ready", primary: true)], preview: true)),
            ("ready-guest", "AB", .next, .init(title: "AB", subtitle: level, footer: [.init("ready", "Ready", primary: true)], preview: true)),
            ("restored-ready", "AB", .next, .init(title: "AB", subtitle: level, footer: [.init("ready", "Ready", primary: true)], preview: true)),
            ("paused-guest", "AB", .current, .init(title: "Paused", subtitle: level, footer: [.init("library", "Library"), .init("resume", "Resume", primary: true)])),
            ("paused-host", "LEM", .current, .init(title: "Paused", subtitle: level, footer: [.init("library", "Library"), .init("resume", "Resume", primary: true)])),
            ("loss", "AB", .result, .init(title: "Try again", subtitle: level, details: ["Saved 0 of 10", "Required 1"], footer: actions(loss), preview: true)),
            ("win-every-level", "AB", .result, .init(title: "Level complete", subtitle: level, details: ["Saved 10 of 10", "Required 1"], footer: actions(win), preview: true)),
            ("hints", "AB", .current, .init(title: "Hints", details: ["Use a digger."], footer: [.init("back", "Back")])),
            ("settings", "AB", .current, .init(title: "Settings", rows: [.init("audio", "Audio")], footer: [.init("back", "Back")])),
            ("save-error", "AB", .current, .init(title: "Hot Seat was not saved", footer: [.init("retry", "Try again", primary: true)])),
            ("saved-shared-journey", "UVA", .next, MobileHomeArt.page(resume: [.init("learningRunResume", "Resume journey run  4/120")], journey: .init("journey", "Learning Journey"), families: [.init("classic", "Classic Lemmings")], initials: "ERI vs UVA")),
            ("saved-solo-journey", "ERI", .next, MobileHomeArt.page(resume: [.init("learningRunResume", "Resume journey run  2/120")], journey: .init("journey", "Learning Journey"), families: [.init("classic", "Classic Lemmings")], initials: "ERI")),
            ("saved-progression", "UVA", .next, MobileHomeArt.page(resume: [.init("learningRunResume", "Resume Easy to hard  3/10")], journey: .init("journey", "Learning Journey"), families: [.init("classic", "Classic Lemmings")], initials: "ERI vs UVA")),
            ("saved-playlist", "UVA", .next, MobileHomeArt.page(resume: [.init("runResume", "Resume My levels  2/10"), .init("resume", "Resume level - UVA")], journey: .init("journey", "Learning Journey"), families: [.init("classic", "Classic Lemmings")], initials: "ERI vs UVA")),
            ("next-library", "LEM", .next, MobileHomeArt.page(journey: .init("journey", "Learning Journey"), families: [.init("classic", "Classic Lemmings")], initials: "LEM v AB")),
            ("level-selection", "LEM", .next, .init(title: "Just Dig!", subtitle: "Fun 1/30", footer: [.init("back", "Back"), .init("play", "Play", primary: true)], preview: true)),
            ("profiles", "LEM", .next, .init(title: "Players", rows: [.init("lem", "LEM"), .init("ab", "AB")], footer: [.init("back", "Back")])),
            ("hot-seat-setup", "LEM", .next, .init(title: "Hot Seat", rows: [.init("rule", "Turns: Every level")], footer: [.init("back", "Back"), .init("start", "Choose a game", primary: true)]))
        ]
        let checkpointDirectory = output.appendingPathComponent("selected-seat-check")
        defer { try? FileManager.default.removeItem(at: checkpointDirectory) }
        var seats = MobileHotSeatStore()
        var selected = seats.start(roster: .init(host: "LEM", players: ["AB"]))!
        selected.pass(to: "AB"); seats.update(selected); seats.endSession()
        guard seats.resume(id: selected.id) == selected else { throw Failure.invalidTargets }
        for engine in ["classic-dos", "lemmings2", "lemmings3"] {
            let familyTitle = engine == "classic-dos" ? "Classic Lemmings" : engine == "lemmings2" ? "Lemmings 2" : "Lemmings 3"
            let checkpoints = MobileCheckpointStore(url: checkpointDirectory.appendingPathComponent(engine + "/current.json"))
            func checkpoint(scope: String?, owner: String, date: Date) -> MobileCheckpointEnvelope {
                .init(runID: UUID(), engine: engine, engineFingerprint: "engine", levelIdentifier: "level", levelIndex: 0,
                      levelFingerprint: "level", tick: 10, selectedControl: 0,
                      camera: .init(origin: .init(x: 0, y: 0), zoom: 1), payload: Data(), savedAt: date, scope: scope, owner: owner)
            }
            let now = Date()
            let solo = checkpoint(scope: nil, owner: "LEM", date: now.addingTimeInterval(1))
            try await checkpoints.save(solo)
            guard try await checkpoints.load(owner: "LEM", scope: selected.scope) == nil else { throw Failure.invalidTargets }
            let empty = MobileHomeArt.page(journey: .init("journey", "Learning Journey"),
                families: [.init("game", familyTitle)], initials: "LEM vs AB")
            states.append(("selected-seat-" + engine + "-no-level", "AB", .next, empty))
            let shared = checkpoint(scope: selected.scope, owner: "AB", date: now)
            try await checkpoints.save(shared)
            guard let restored = try await checkpoints.load(owner: "LEM", scope: selected.scope), restored == shared,
                  let owner = restored.owner else { throw Failure.invalidTargets }
            let resumed = MobileHomeArt.page(resume: [.init("resume", "Resume level - " + owner)],
                journey: .init("journey", "Learning Journey"), families: [.init("game", familyTitle)], initials: "LEM vs AB")
            states.append(("selected-seat-" + engine + "-saved-level", "AB", .next, resumed))
        }
        var captures: [[String: Any]] = []
        for (pose, size) in [("iphone-narrow", CGSize(width: 320, height: 548)),
                             ("iphone-portrait", CGSize(width: 390, height: 763)),
                             ("iphone-landscape", CGSize(width: 756, height: 369)),
                             ("ipad-portrait", CGSize(width: 834, height: 1092)),
                             ("ipad-landscape", CGSize(width: 1112, height: 814))] {
            for (state, owner, role, original) in states {
                let page = MobileTurnArt.page(original, playerName: owner, role: role, sessionName: original.home ? original.homeInitials.replacingOccurrences(of: " v ", with: " vs ") : nil)
                if let owner {
                    guard page.title.contains(owner) || page.subtitle.contains(owner) || page.homeNextPlayerName == owner else { throw invalidTargets(line: #line) }
                    if state.hasPrefix("paused-") { guard page.title == "Paused: " + owner else { throw Failure.invalidTargets } }
                    if role == .result { guard page.subtitle.hasPrefix("Played: " + owner) else { throw Failure.invalidTargets } }
                    if state.contains("ready"), !state.hasPrefix("solo-") { guard page.title == owner, page.subtitle == original.subtitle else { throw Failure.invalidTargets } }
                    if state == "next-library" { guard page.subtitle.isEmpty, page.homeNextPlayerName == "LEM" else { throw invalidTargets(line: #line) } }
                } else { guard page == original else { throw Failure.invalidTargets } }
                if state == "saved-shared-journey" {
                    guard page.subtitle.isEmpty, page.homeNextPlayerName == "UVA",
                          page.rows.first?.id == "learningRunResume", page.rows.first?.primary == true else { throw invalidTargets(line: #line) }
                }
                if state.hasPrefix("selected-seat-") {
                    guard page.subtitle.isEmpty, page.homeNextPlayerName == "AB",
                          !page.rows.contains(where: { $0.id == "seatOther" || $0.title.lowercased().contains("solo") }),
                          page.rows.first?.id == (state.hasSuffix("no-level") ? "journey" : "resume")
                    else { throw invalidTargets(line: #line) }
                }
                let layout = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
                for (index, target) in layout.targets.enumerated() {
                    guard target.frame.width >= 44, target.frame.height >= 44,
                          layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == target.action.id,
                          layout.targets.dropFirst(index + 1).allSatisfy({ !target.frame.intersects($0.frame) }) else { throw Failure.invalidTargets }
                }
                let context = try bitmapContext(size: layout.size)
                GameFrontEnd.draw(page, layout: layout, typography: typography, in: context)
                let file = pose + "-" + state + ".png"
                try save(context: context, to: output.appendingPathComponent(file))
                captures.append(["file": file, "title": page.title, "subtitle": page.subtitle,
                    "heading": [layout.heading.minX, layout.heading.minY, layout.heading.width, layout.heading.height],
                    "identity": [layout.subtitle.minX, layout.subtitle.minY, layout.subtitle.width, layout.subtitle.height],
                    "targets": layout.targets.count])
            }
        }
        guard MobileTurnArt.subtitle("Fun 1/30", playerName: "AB", role: .next) == "Next: AB  Fun 1/30" else { throw Failure.invalidTargets }
        seat.policy = .atFirstFail
        guard seat.choices(didWin: true).first?.player == "AB" else { throw Failure.invalidTargets }
        try JSONSerialization.data(withJSONObject: captures, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("captures.json"))
        print("PASS: \(captures.count) Hot Seat flow renders and targets; Ready, pause, results, hints, settings, recovery, selected-session saves and next-turn library pages.")
    }
}
