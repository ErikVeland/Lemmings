import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore

extension MenuAudit {
    @MainActor static func checkHotSeatFlow(typography: GameMenuTypography, output: URL) throws {
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
        let states: [State] = [
            ("solo-pause", nil, .current, .init(title: "Paused", subtitle: level, footer: [.init("resume", "Resume", primary: true)])),
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
            ("saved-solo-journey", nil, .next, MobileHomeArt.page(resume: [.init("learningRunResume", "Resume journey run  2/120")], journey: .init("journey", "Learning Journey"), families: [.init("classic", "Classic Lemmings")], initials: "ERI")),
            ("saved-progression", "UVA", .next, MobileHomeArt.page(resume: [.init("learningRunResume", "Resume Easy to hard  3/10")], journey: .init("journey", "Learning Journey"), families: [.init("classic", "Classic Lemmings")], initials: "ERI vs UVA")),
            ("saved-playlist", "UVA", .next, MobileHomeArt.page(resume: [.init("runResume", "Resume My levels  2/10"), .init("resume", "Resume level - UVA")], journey: .init("journey", "Learning Journey"), families: [.init("classic", "Classic Lemmings")], initials: "ERI vs UVA")),
            ("next-library", "LEM", .next, MobileHomeArt.page(journey: .init("journey", "Learning Journey"), families: [.init("classic", "Classic Lemmings")], initials: "LEM v AB")),
            ("level-selection", "LEM", .next, .init(title: "Just Dig!", subtitle: "Fun 1/30", footer: [.init("back", "Back"), .init("play", "Play", primary: true)], preview: true)),
            ("profiles", "LEM", .next, .init(title: "Players", rows: [.init("lem", "LEM"), .init("ab", "AB")], footer: [.init("back", "Back")])),
            ("hot-seat-setup", "LEM", .next, .init(title: "Hot Seat", rows: [.init("rule", "Turns: Every level")], footer: [.init("back", "Back"), .init("start", "Choose a game", primary: true)]))
        ]
        var captures: [[String: Any]] = []
        for (pose, size) in [("iphone-narrow", CGSize(width: 320, height: 548)),
                             ("iphone-portrait", CGSize(width: 390, height: 763)),
                             ("iphone-landscape", CGSize(width: 756, height: 369)),
                             ("ipad-portrait", CGSize(width: 834, height: 1092)),
                             ("ipad-landscape", CGSize(width: 1112, height: 814))] {
            for (state, owner, role, original) in states {
                let page = MobileTurnArt.page(original, playerName: owner, role: role, sessionName: original.home ? original.homeInitials.replacingOccurrences(of: " v ", with: " vs ") : nil)
                if let owner {
                    guard page.title.contains(owner) || page.subtitle.contains(owner) else { throw Failure.invalidTargets }
                    if state.hasPrefix("paused-") { guard page.title == "Paused: " + owner else { throw Failure.invalidTargets } }
                    if role == .result { guard page.subtitle.hasPrefix("Played: " + owner) else { throw Failure.invalidTargets } }
                    if state.contains("ready") { guard page.title == owner, page.subtitle == original.subtitle else { throw Failure.invalidTargets } }
                    if state == "next-library" { guard page.subtitle == "LEM vs AB  Next: LEM" else { throw Failure.invalidTargets } }
                } else { guard page == original else { throw Failure.invalidTargets } }
                if state == "saved-shared-journey" {
                    guard page.subtitle == "ERI vs UVA  Next: UVA",
                          page.rows.first?.title == "Resume journey run  4/120", page.rows.first?.primary == true else { throw Failure.invalidTargets }
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
        print("PASS: \(captures.count) Hot Seat flow renders and targets; Ready, pause, results, hints, settings, recovery and next-turn library pages.")
    }
}
