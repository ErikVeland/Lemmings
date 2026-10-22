import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    static func footerNavigationIsValid(_ page: GameFrontEnd.Page, layout: GameFrontEnd.Layout) -> Bool {
        let footer = layout.targets.filter { page.footer.contains($0.action) }
        guard Set(footer.map { $0.action.id }) == Set(page.footer.map(\.id)) else { return false }
        let ordered = footer.sorted { $0.frame.minY == $1.frame.minY ? $0.frame.minX < $1.frame.minX : $0.frame.minY < $1.frame.minY }
        guard footer.map(\.action) == ordered.map(\.action) else { return false }
        if let back = footer.first(where: { $0.action.isBackNavigation }) {
            let forward = footer.last { $0.action.primary && !$0.action.isBackNavigation }
            let stacked = forward.map { $0.frame.minX == back.frame.minX && $0.frame.minY > back.frame.maxY } ?? false
            guard back.frame.minX == footer.map({ $0.frame.minX }).min(),
                  stacked ? footer.dropLast().last?.action.id == back.action.id
                    : back.frame.maxY == footer.map({ $0.frame.maxY }).max() else { return false }
        }
        if let forward = footer.last(where: { $0.action.primary && !$0.action.isBackNavigation }) {
            guard forward.frame.maxX == footer.map({ $0.frame.maxX }).max(),
                  forward.frame.maxY == footer.map({ $0.frame.maxY }).max() else { return false }
        }
        return true
    }
    @MainActor static func checkHierarchy(library: ClassicMobileLibrary, typography: GameMenuTypography, output: URL) throws {
        let content = try library.loadLevel(at: 26)
        let image = MobileBitmapRenderer.image(try content.session.render(highlight: nil))
        let source = CGRect(x: content.session.initialCameraOrigin.x, y: 0, width: 320, height: 160)
        var captures = 0
        for (device, size) in [("narrow", CGSize(width: 320, height: 548)), ("phone", CGSize(width: 390, height: 763)),
                               ("landscape", CGSize(width: 756, height: 369)), ("short", CGSize(width: 568, height: 300)),
                               ("ipad", CGSize(width: 834, height: 1092)), ("wide", CGSize(width: 1112, height: 814))] {
            for setting in ClassicInterfaceSize.allCases {
                let scale = MobileSettingsArt.interfaceScale(setting, width: size.width)
                let logical = CGSize(width: size.width / scale, height: size.height / scale)
                for origin in [MobileLevelSummary.Origin.official, .fanMade] {
                    let level = MobileLevelSummary(index: 0, rank: "Journey", number: 95,
                        title: "Let's be careful out there with a very long level title", origin: origin,
                        packName: origin == .official ? "Lemmings" : "A community adventure")
                    var selection = GameFrontEnd.Page(title: level.title, subtitle: level.caption,
                        details: ["80 lemmings / Save 60", "Time 4:00"], footer: [.init("back", "Back"), .init("play", "Play", primary: true)], preview: true)
                    var result = selection
                    result.title = "Level complete"; result.details = [level.title, "Saved 60 / 80", "Required 60"]
                    result.detailTitles = [0]
                    result.footer = [.init("library", "Library"), .init("retry", "Retry"), .init("next", "Next level", primary: true)]
                    var handover = selection
                    handover.title = "ERI's turn"; handover.details = [level.title] + selection.details; handover.detailTitles = [0]
                    handover.footer = [.init("library", "Library"), .init("ready", "Ready", primary: true)]
                    selection = MobileTurnArt.page(selection, playerName: "ERI", role: .next)
                    for (state, page) in [("selection", selection), ("result", result), ("handover", handover), ("settings", MobileSettingsArt.groups()), ("groups", MobileInformationArt.effectsWelcome())] {
                        let layout = GameFrontEnd.layout(page, width: logical.width, minimumHeight: logical.height)
                        let titleScale = layout.heading.width >= 580 ? 2 : 1
                        guard GameTextLayout.height(page.title, width: layout.heading.width, face: .large, scale: titleScale) <= layout.heading.height,
                              GameTextLayout.height(page.subtitle, width: layout.subtitle.width) <= layout.subtitle.height,
                              layout.heading.maxY <= layout.subtitle.minY,
                              layout.details.count == page.details.count,
                              footerNavigationIsValid(page, layout: layout) else { throw Failure.invalidTargets }
                        for (index, text) in page.details.enumerated() {
                            let box = layout.details[index]
                            guard layout.board.contains(box), GameTextLayout.height(text, width: box.width, face: page.detailTitles.contains(index) ? .large : .small) <= box.height,
                                  layout.targets.allSatisfy({ !$0.frame.intersects(box) }) else { throw Failure.invalidTargets }
                        }
                        for (index, target) in layout.targets.enumerated() {
                            guard target.frame.width * scale >= 44, target.frame.height * scale >= 44,
                                  layout.board.contains(target.frame),
                                  layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == (target.action.enabled ? target.action.id : nil),
                                  layout.targets.dropFirst(index + 1).allSatisfy({ !$0.frame.intersects(target.frame) }) else { throw Failure.invalidTargets }
                        }
                        let context = try bitmapContext(size: layout.size)
                        GameFrontEnd.draw(page, layout: layout, typography: typography, preview: image, previewSource: source, in: context)
                        try save(context: context, to: output.appendingPathComponent("\(device)-\(setting.rawValue)-\(origin.rawValue)-\(state).png"))
                        captures += 1
                    }
                }
                // Explicit breaks and long unbroken names must retain every character.
                for title in ["First line\nSecond line", String(repeating: "LONGNAME", count: 12)] {
                    let lines = GameTextLayout.lines(title, width: logical.width - 72, face: .large)
                    guard lines.joined().replacingOccurrences(of: " ", with: "") == GameMenuTypography.menuText(title).replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\n", with: "") else { throw Failure.invalidTargets }
                }
            }
            let safe = CGRect(origin: .zero, size: size)
            let title = "Let's be careful out there with a very long level title"
            let subtitle = "Fan-made / A community adventure\nJourney 95"
            let browser = LevelBrowserGeometry(safe: safe, titleText: title, subtitleText: subtitle)
            guard browser.title.height >= GameTextLayout.height(title, width: browser.title.width, face: .large),
                  browser.subtitle.height >= GameTextLayout.height(subtitle, width: browser.subtitle.width),
                  browser.stage.height > 0, browser.actions.allSatisfy({ safe.contains($0) && !$0.intersects(browser.stage) }) else { throw Failure.invalidTargets }
        }
        try JSONSerialization.data(withJSONObject: ["captures": captures, "audio": "muted", "windows": "none", "fullTitlesAndTargets": true], options: .prettyPrinted)
            .write(to: output.appendingPathComponent("hierarchy-report.json"))
        print("PASS: \(captures) hierarchy captures; full titles, source labels, text scales and targets.")
    }
}
