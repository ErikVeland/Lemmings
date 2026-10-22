import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkDuoRelease(typography: GameMenuTypography, artwork: URL, output: URL) throws {
        var captures = 0
        let states: [(String, CGSize)] = [("phone", .init(width: 390, height: 763)),
            ("ipad", .init(width: 834, height: 1092)), ("book-pane", .init(width: 589, height: 794)),
            ("stacked-pane", .init(width: 834, height: 569)), ("compact-stacked", .init(width: 465, height: 298))]
        var home = MobileHomeArt.page(journey: .init("journey", "Journey map"),
            families: [.init("classic", "Classic"), .init("l2", "Lemmings 2", gameLogo: .lemmings2),
                       .init("l3", "Lemmings 3", gameLogo: .lemmings3)], initials: "LEM")
        home.footer.insert(.init("deskClock", "Desk Clock"), at: 4)
        for (name, size) in states {
            let homeLayout = GameFrontEnd.layout(home, width: size.width, minimumHeight: size.height)
            guard homeLayout.targets.contains(where: { $0.action.id == "deskClock" && $0.frame.width >= 44 && $0.frame.height >= 44 }),
                  homeLayout.targets.allSatisfy({ homeLayout.board.contains($0.frame) }),
                  homeLayout.targets.enumerated().allSatisfy({ index, target in
                    homeLayout.targets.dropFirst(index + 1).allSatisfy { !$0.frame.intersects(target.frame) }
                  }) else { throw invalidTargets(line: #line) }
            let homeContext = try bitmapContext(size: homeLayout.size)
            GameFrontEnd.draw(home, layout: homeLayout, typography: typography, in: homeContext)
            try save(context: homeContext, to: output.appendingPathComponent("\(name)-home-clock.png"))
            captures += 1
            for group in MobileSettingsGroup.allCases {
                let page = MobileSettingsArt.page(group, settings: .init(), displayAvailable: true, foldable: true, ghostsVisible: false)
                let layout = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
                guard Set(layout.targets.map { $0.action.id }) == Set((page.rows + page.footer).map(\.id)),
                      footerNavigationIsValid(page, layout: layout) else { throw invalidTargets(line: #line) }
                for (index, target) in layout.targets.enumerated() {
                    guard layout.board.contains(target.frame), target.frame.height >= 44, target.frame.width >= 44,
                          layout.targets.dropFirst(index + 1).allSatisfy({ !$0.frame.intersects(target.frame) }),
                          layout.action(at: .init(x: target.frame.midX, y: target.frame.midY)) == (target.action.enabled ? target.action.id : nil)
                    else { throw invalidTargets(line: #line) }
                }
                if group == .gameplay {
                    guard page.rows.contains(where: { $0.id == "setting.hotSeatGhosts" && $0.toggleValue == false }),
                          page.rows.contains(where: { $0.id == "setting.cursor" }),
                          page.rows.contains(where: { $0.id == "setting.inspect" }) else { throw invalidTargets(line: #line) }
                }
                let context = try bitmapContext(size: layout.size)
                GameFrontEnd.draw(page, layout: layout, typography: typography, in: context)
                try save(context: context, to: output.appendingPathComponent("\(name)-\(group.rawValue).png"))
                captures += 1
            }
            var reading = GameFrontEnd.Page(title: "A few things before we go", details: [
                "One lemming has a plan. The others would like to see it before the bridge runs out.",
                "Take your time. You can pause, look around and try another route.\n\nReady waits for you."],
                footer: [.init("back", "Back")])
            reading.reading = true
            let layout = GameFrontEnd.layout(reading, width: size.width, minimumHeight: size.height)
            guard layout.details.count == 2, layout.details[1].minY - layout.details[0].maxY >= 24,
                  layout.details.allSatisfy({ $0.width <= 720 }),
                  GameTextLayout.lines("First paragraph.\n\nSecond paragraph.", width: 720, preservesCase: true).contains("")
            else { throw invalidTargets(line: #line) }
            let context = try bitmapContext(size: layout.size)
            GameFrontEnd.draw(reading, layout: layout, typography: typography, in: context)
            try save(context: context, to: output.appendingPathComponent("\(name)-paragraphs.png"))
            captures += 1
        }
        let clockArtwork = ProcessInfo.processInfo.environment["LEMMINGS_CLOCK_ARTWORK"].map { URL(fileURLWithPath: $0) } ?? artwork
        let frames = try ClassicMacArtwork(directory: clockArtwork)
        guard let art = GameDeskClockArt(directory: clockArtwork),
              let clockType = GameMenuTypography(directory: clockArtwork),
              clockType.font(.small) != nil, clockType.font(.large) != nil else { throw Failure.missingArtwork }
        for pose in [ClassicLemmingPose.walking, .falling, .digging, .building, .blocking,
                     .umbrellaOpening, .floating, .exiting, .ohNo, .explosion] {
            for left in [false, true] {
                guard (0..<32).allSatisfy({ frames.lemming(pose: pose, left: left, tick: $0) != nil })
                else { throw Failure.missingArtwork }
            }
        }
        let now = Date(timeIntervalSince1970: 1_792_670_400)
        for (state, event) in [("calm", Optional<DeskClockEvent>.none),
            ("soon", .init(start: now.addingTimeInterval(300), title: "A meeting about bridges", nuke: false)),
            ("start", .init(start: now, title: "A meeting about bridges", nuke: false)),
            ("nuke", .init(start: now, title: "A meeting about bridges", nuke: true))] {
            for (family, size) in [("small", CGSize(width: 158, height: 158)), ("medium", CGSize(width: 338, height: 158)),
                ("large", CGSize(width: 338, height: 354)), ("app", CGSize(width: 834, height: 569))] {
                let context = try bitmapContext(size: size)
                let simulation = DeskClockSimulation.still(at: now, event: event, uses24Hour: true)
                if family == "app" {
                    art.draw(simulation, event: event, now: now, time: 0,
                             in: context, rect: CGRect(origin: .zero, size: size), nightDim: false)
                } else {
                    art.drawWidget(simulation, event: event, now: now, in: context,
                        rect: CGRect(origin: .zero, size: size), compact: family == "small")
                }
                try save(context: context, to: output.appendingPathComponent("clock-\(state)-\(family).png"))
                captures += 1
            }
        }
        print("PASS \(captures) Duo release renders: settings actions, targets, paragraphs and clock states. No windows or audio.")
    }
}
