import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkGridHUD(typography: GameMenuTypography, content: URL, output: URL) throws {
        func requireHUD<T>(_ value: T?) throws -> T {
            guard let value else { throw invalidTargets(line: #line) }
            return value
        }
        let session = try ClassicMobileLibrary(directory: content).loadLevel(at: 0).session
        var settings = ClassicSettings()
        settings.music = .silent
        session.applySettings(settings)
        let original = session.snapshot
        let panel = session.panelFrame.flatMap(MobileBitmapRenderer.image)
        let icons = original.skills.indices.map { session.skillCursorFrame(control: $0).flatMap(MobileBitmapRenderer.image) }
        let cornerCases: [(String, CGFloat, CGFloat)] = [("uniform", 90, 90), ("tight-left", 8, 90), ("tight-right", 90, 8)]
        for engine in ["classic", "lemmings2", "lemmings3"] {
            let engineSkills = Array(original.skills.prefix(engine == "lemmings3" ? 5 : 8))
            for hasRate in [false, true] {
                for width in [CGFloat(465), CGFloat(467)] {
                    for (name, left, right) in cornerCases {
                        let bounds = CGRect(x: 0, y: 0, width: width, height: 650)
                        let corners = GameControlCornerRadii(topLeft: left, topRight: right, bottomLeft: left, bottomRight: right)
                        let snapshot = MobileGameSnapshot(tick: original.tick, released: original.released, total: original.total,
                            saved: original.saved, required: original.required, remainingSeconds: original.remainingSeconds,
                            releaseRate: hasRate ? 50 : nil, isComplete: false, didWin: false,
                            isEndingRun: false, skills: engineSkills)
                        let layout = MobileHUDLayout.make(container: .init(width: bounds.width, height: bounds.height),
                            safeArea: .init(top: 90, bottom: 90), hasRate: hasRate, skillCount: snapshot.skills.count,
                            supportsRewind: true, hasPlayer: true, engineIdentifier: engine,
                            fillsDisplayWidth: true, menuLeading: true)
                        guard let portrait = layout.portrait else { throw invalidTargets(line: #line) }
                        let targets = MobileHUDRenderer.targets(layout: layout, snapshot: snapshot, selectedSkill: 0,
                            paused: false, speed: 1, endRunArmed: false)
                        let skills = targets.filter { if case .skill = $0.action { return true }; return false }.sorted { $0.frame.minX < $1.frame.minX }
                        let navigation = targets.filter { [.rewind, .stepBackward, .step].contains($0.action) }.sorted { $0.frame.minX < $1.frame.minX }
                        let transport = targets.filter { [.pause, .endRun, .speed].contains($0.action) }.sorted { $0.frame.minX < $1.frame.minX }
                        guard let firstSkill = skills.first, let lastSkill = skills.last,
                              let firstNavigation = navigation.first, let lastNavigation = navigation.last,
                              let firstTransport = transport.first, let lastTransport = transport.last,
                              firstSkill.frame.minX == bounds.minX, lastSkill.frame.maxX == bounds.maxX,
                              firstNavigation.frame.minX == bounds.minX, lastNavigation.frame.maxX == portrait.minimap.minX,
                              portrait.minimap.maxX == bounds.maxX, portrait.minimap.maxY == portrait.skills.minY,
                              portrait.skills.maxY == firstTransport.frame.minY, lastTransport.frame.maxX == bounds.maxX,
                              (hasRate ? (portrait.rateValue?.minX ?? 0) >= bounds.minX + 44 : firstTransport.frame.minX == bounds.minX),
                              zip(skills, skills.dropFirst()).allSatisfy({ $0.frame.maxX == $1.frame.minX }),
                              zip(navigation, navigation.dropFirst()).allSatisfy({ $0.frame.maxX == $1.frame.minX }),
                              zip(transport, transport.dropFirst()).allSatisfy({ $0.frame.maxX == $1.frame.minX })
                        else { throw invalidTargets(line: #line) }
                        let edge = targets.map { MobileHUDRenderer.edgeInputFrame(for: $0, layout: layout, displayBounds: bounds, screenEdges: true) }
                        guard edge.enumerated().allSatisfy({ index, frame in
                            bounds.contains(frame) && edge.dropFirst(index + 1).allSatisfy { !frame.intersects($0) }
                        }) else { throw invalidTargets(line: #line) }
                        if hasRate, skills.count == 8 {
                            guard skills[3].frame.maxX == targets.first(where: { $0.action == .speed })?.frame.maxX,
                                  skills[4].frame.minX == targets.first(where: { $0.action == .endRun })?.frame.minX
                            else { throw invalidTargets(line: #line) }
                        }
                        let status = MobileHUDRenderer.statusFrames(layout: layout, hasPlayer: true, displayBounds: bounds)
                        guard let player = status.player,
                              player.midY == status.counters.midY,
                              abs(player.midY - (layout.interface.statusFrame.maxY + 2) / 2) < 0.01
                        else { throw invalidTargets(line: #line) }
                        let context = try bitmapContext(size: bounds.size)
                        context.saveGState()
                        context.addPath(GameControlGroupArt.path(in: bounds, bottomLeft: true, bottomRight: true, screenEdges: true, topLeft: true, topRight: true, cornerRadii: corners))
                        context.clip()
                        MobileHUDRenderer(layout: layout, snapshot: snapshot, selectedSkill: 0, paused: false, speed: 1,
                            endRunArmed: false, panelImage: panel, typography: typography, skillIcons: icons,
                            playerName: "PLA", shape: .rounded, duoCorners: true, displayBounds: bounds,
                            displayCornerRadius: 90, displayCornerRadii: corners).draw(in: context, bounds: bounds)
                        GameMinimapArt.draw(in: context, bounds: portrait.minimap, image: nil, visible: .zero,
                            levelSize: .zero, overlay: true, displayBounds: bounds)
                        context.restoreGState()
                        // The outline must survive across row boundaries, before applying
                        // a physical screen mask can hide a missing upper arc.
                        let mask = try bitmapContext(size: bounds.size)
                        let deck = CGRect(x: 2, y: layout.interface.controlsFrame.minY,
                            width: bounds.width - 4, height: bounds.height - layout.interface.controlsFrame.minY - 2)
                        mask.setShouldAntialias(false)
                        mask.setFillColor(CGColor(gray: 1, alpha: 1))
                        mask.addPath(GameControlGroupArt.path(in: deck, bottomLeft: true, bottomRight: true,
                            screenEdges: true, cornerRadii: corners.inset(by: 2)))
                        mask.fillPath()
                        mask.setFillColor(CGColor(gray: 0, alpha: 1))
                        mask.addPath(GameControlGroupArt.path(in: deck, inset: 1, bottomLeft: true, bottomRight: true,
                            screenEdges: true, cornerRadii: corners.inset(by: 2)))
                        mask.fillPath()
                        guard let expected = mask.data?.assumingMemoryBound(to: UInt8.self),
                              let actual = context.data?.assumingMemoryBound(to: UInt8.self)
                        else { throw invalidTargets(line: #line) }
                        for pixel in 0..<(Int(bounds.width) * Int(bounds.height)) where expected[pixel * 4] > 128 {
                            guard max(actual[pixel * 4], actual[pixel * 4 + 1], actual[pixel * 4 + 2]) >= 60
                            else { throw invalidTargets(line: #line) }
                        }
                        try save(context: context, to: output.appendingPathComponent("\(engine)-\(hasRate ? "rate" : "no-rate")-\(Int(width))-\(name).png"))
                    }
                }
            }
        }
        for engine in ["classic", "lemmings2", "lemmings3"] {
            let rate = engine == "classic"
            let skills = Array(original.skills.prefix(engine == "lemmings3" ? 5 : 8))
            let snapshot = MobileGameSnapshot(tick: original.tick, released: original.released, total: original.total,
                saved: original.saved, required: original.required, remainingSeconds: original.remainingSeconds,
                releaseRate: rate ? 50 : nil, isComplete: false, didWin: false, isEndingRun: false, skills: skills)
            let size = CGSize(width: 1152, height: 648)
            let layout = MobileHUDLayout.make(container: .init(width: size.width, height: size.height),
                safeArea: .init(), hasRate: rate, skillCount: skills.count, supportsRewind: true,
                hasPlayer: true, engineIdentifier: engine, showsMenuButton: false, television: true)
            guard layout.television, layout.panel == nil, layout.portrait != nil else { throw invalidTargets(line: #line) }
            let targets = MobileHUDRenderer.targets(layout: layout, snapshot: snapshot, selectedSkill: 0,
                paused: false, speed: 1, endRunArmed: false)
            guard targets.allSatisfy({ target in
                CGRect(origin: .zero, size: size).contains(target.frame) && targets.filter { $0.action != target.action }
                    .allSatisfy { !target.frame.intersects($0.frame) }
            }) else { throw invalidTargets(line: #line) }
            let context = try bitmapContext(size: size)
            MobileHUDRenderer(layout: layout, snapshot: snapshot, selectedSkill: 0, paused: false, speed: 1,
                endRunArmed: false, panelImage: panel, typography: typography, skillIcons: icons,
                playerName: "PLA").draw(in: context, bounds: CGRect(origin: .zero, size: size))
            try save(context: context, to: output.appendingPathComponent("tv-\(engine).png"))
        }
        for engine in ["classic", "lemmings2", "lemmings3"] {
            let rate = engine == "classic"
            let skills = Array(original.skills.prefix(engine == "lemmings3" ? 5 : 8))
            let snapshot = MobileGameSnapshot(tick: original.tick, released: original.released, total: original.total,
                saved: original.saved, required: original.required, remainingSeconds: original.remainingSeconds,
                releaseRate: rate ? 50 : nil, isComplete: false, didWin: false, isEndingRun: false, skills: skills)
            for size in [CGSize(width: 834, height: 1194), CGSize(width: 1194, height: 834)] {
                let bounds = CGRect(origin: .zero, size: size)
                let layout = MobileHUDLayout.make(container: .init(width: size.width, height: size.height),
                    safeArea: .init(top: 44, bottom: 20), hasRate: rate, skillCount: skills.count,
                    supportsRewind: true, hasPlayer: true, engineIdentifier: engine,
                    fillsDisplayWidth: true, menuLeading: true)
                let deck = try requireHUD(layout.portrait)
                let targets = MobileHUDRenderer.targets(layout: layout, snapshot: snapshot, selectedSkill: 3,
                    paused: true, speed: 2, endRunArmed: false)
                let tracking = targets.filter { [.rewind, .stepBackward, .step].contains($0.action) }
                    .sorted { $0.frame.minX < $1.frame.minX }
                guard tracking.last?.frame.maxX == deck.minimap.minX,
                      tracking.allSatisfy({ $0.frame.minY == deck.minimap.minY && $0.frame.height == deck.minimap.height }),
                      zip(tracking, tracking.dropFirst()).allSatisfy({ $0.frame.maxX == $1.frame.minX }),
                      targets.first(where: { $0.action == .menu })?.frame.minX == 0
                else { throw invalidTargets(line: #line) }
                if size.width > size.height {
                    let lastSkill = try requireHUD(targets.filter { if case .skill = $0.action { return true }; return false }
                        .max { $0.frame.maxX < $1.frame.maxX })
                    let nuke = try requireHUD(targets.first { $0.action == .endRun })
                    let next = rate ? targets.first { $0.action == .releaseRate(-1) } : targets.first { $0.action == .speed }
                    guard lastSkill.frame.maxX == nuke.frame.minX, nuke.frame.maxX == next?.frame.minX
                    else { throw invalidTargets(line: #line) }
                }
                let context = try bitmapContext(size: size)
                MobileHUDRenderer(layout: layout, snapshot: snapshot, selectedSkill: 3, paused: true, speed: 2,
                    endRunArmed: false, panelImage: panel, typography: typography, skillIcons: icons,
                    playerName: "EKV", shape: .rounded, duoCorners: true, displayBounds: bounds,
                    displayCornerRadius: 48).draw(in: context, bounds: bounds)
                GameMinimapArt.draw(in: context, bounds: deck.minimap, image: nil, visible: .zero,
                    levelSize: .zero, overlay: true, displayBounds: bounds)
                try save(context: context, to: output.appendingPathComponent("inner-\(engine)-\(Int(size.width)).png"))
            }
        }
        let home = TVMenuPresentation.homePage(MobileHomeArt.page(journey: .init("journey", "Journey map"),
            families: [.init("classic", "Classic"), .init("l2", "Lemmings 2"), .init("l3", "Lemmings 3")], initials: "PLA"))
        for width: CGFloat in [576, 864, 1152] {
            let layout = TVMenuPresentation.homeLayout(home, width: width, height: 648)
            for target in layout.targets where home.footer.contains(where: { $0.id == target.action.id }) {
                guard target.action.title.split(whereSeparator: \.isWhitespace).allSatisfy({
                    GameTextLayout.width(of: String($0), font: typography.font(.small)) <= target.frame.width - 24
                }), layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == target.action.id
                else { throw invalidTargets(line: #line) }
            }
            let context = try bitmapContext(size: layout.size)
            GameFrontEnd.draw(home, layout: layout, typography: typography, highlighted: "worldwide", in: context)
            try save(context: context, to: output.appendingPathComponent("tv-home-\(Int(width)).png"))
        }
        print("PASS: muted, windowless grid and TV renders; input targets and home label widths.")
    }
}
