import Foundation
import CoreGraphics
import ImageIO
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

@main struct MenuAudit {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 4 else { throw Failure.invalidArguments }
        let artwork = URL(fileURLWithPath: CommandLine.arguments[1])
        let content = URL(fileURLWithPath: CommandLine.arguments[2])
        let output = URL(fileURLWithPath: CommandLine.arguments[3])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        guard let typography = GameMenuTypography(directory: artwork),
              typography.interface.logo != nil,
              typography.font(.small) != nil, typography.font(.large) != nil else { throw Failure.missingArtwork }
        let library = try ClassicMobileLibrary(directory: content)
        let session = try library.loadLevel(at: 0).session
        let bitmap = try session.render(highlight: nil)
        guard let image = MobileBitmapRenderer.image(bitmap) else { throw Failure.missingArtwork }
        let previewSource = CGRect(x: session.initialCameraOrigin.x, y: 0, width: 320, height: 160)
        typealias Action = GameFrontEnd.Action
        let homeRows: [Action] = [.init("classic", "Lemmings  0/120", primary: true),
                                 .init("l2", "Lemmings 2 - Unavailable", enabled: false),
                                 .init("l3", "Lemmings 3 - Unavailable", enabled: false)]
        let footer: [Action] = [.init("settings", "Settings"), .init("data", "Game Data")]
        var pages: [(String, GameFrontEnd.Page)] = [
            ("long-title", .init(title: library.levels.max(by: { $0.title.count < $1.title.count })!.title,
                                subtitle: "Mayhem", footer: [.init("home", "Back"), .init("play", "Play again", primary: true)], preview: true)),
            ("home", .init(title: "Lemmings", home: true, rows: homeRows, footer: footer)),
            ("resume", .init(title: "Lemmings", home: true,
                             rows: [.init("resume", "Resume saved run", primary: true)] + homeRows.map {
                                .init($0.id, $0.title, enabled: $0.enabled) }, footer: footer)),
            ("levels", .init(title: "Just Dig!", subtitle: "Fun 1/30", details: ["10 Lemmings   Save 10", "Time 5:00"],
                             footer: [.init("rankPrevious", "< Rank"), .init("rankNext", "Rank >"),
                                      .init("previous", "< Level", enabled: false), .init("next", "Level >"),
                                      .init("home", "Back"), .init("play", "Play", primary: true)], preview: true, footerColumns: 2)),
            ("briefing", .init(title: "Just Dig!", subtitle: "Fun 1", details: ["10 Lemmings   Save 10", "Time 5:00"],
                               footer: [.init("0", "Start", primary: true), .init("1", "Library")], preview: true)),
            ("pause", .init(title: "Paused", subtitle: "Fun 1  Just Dig!",
                            footer: [.init("0", "Resume", primary: true), .init("1", "Library")])),
            ("win", .init(title: "Level complete", subtitle: "Fun 1  Just Dig!", details: ["Saved 10 of 10", "Required 10"],
                          footer: [.init("0", "Next level", primary: true), .init("1", "Retry"), .init("2", "Library")], preview: true)),
            ("loss", .init(title: "Try again", subtitle: "Fun 1  Just Dig!", details: ["Saved 4 of 10", "Required 10"],
                           footer: [.init("0", "Retry", primary: true), .init("1", "Library")], preview: true)),
            ("settings", MobileSettingsArt.groups()),
            ("data", .init(title: "Game Data", details: ["Lemmings", "120 levels"],
                           footer: [.init("home", "Back"), .init("import", "Import")])),
            ("empty", .init(title: "Game Data", footer: [.init("home", "Back"), .init("import", "Import", primary: true)])),
        ]
        pages += MobileSettingsGroup.allCases.map {
            ("settings-" + $0.rawValue, MobileSettingsArt.page($0, settings: MobileSettings()))
        }
        pages.append(("settings-controller-remap", MobileSettingsArt.controllerMappings(MobileSettings())))
        let insightCounts = ["starts": 120, "wins": 80, "fails": 30, "abandoned": 10,
                             "saved": 560, "solo": 70, "hotSeat": 50, "music": 1, "downloads": 1]
        pages += [("effects-welcome", MobileInformationArt.effectsWelcome()),
                  ("whats-new", MobileInformationArt.whatsNew(version: "2.0")),
                  ("telemetry-consent", MobileInformationArt.telemetryConsent()),
                  ("insights-local", MobileInformationArt.insights(counts: insightCounts, shared: false, days: 30, sharingAvailable: false)),
                  ("insights-shared", MobileInformationArt.insights(counts: insightCounts, shared: true, days: 7, sharingAvailable: true)),
                  ("insights-token", MobileInformationArt.insightsToken(length: 12)),
                  ("insights-clear", MobileInformationArt.insightsClear())]
        pages += try careerPages()
        let portraits = GamePortraitArt(directory: artwork)
        guard (0..<8).allSatisfy({ portraits?.image($0) != nil }) else { throw Failure.missingArtwork }
        var evidence: [[String: Any]] = []
        for (device, size) in [("ipad-portrait", CGSize(width: 834, height: 1092)),
                               ("ipad-landscape", CGSize(width: 1112, height: 814)),
                               ("iphone-portrait", CGSize(width: 390, height: 763)),
                               ("iphone-landscape", CGSize(width: 756, height: 369)),
                               ("iphone-narrow-portrait", CGSize(width: 320, height: 548)),
                               ("iphone-narrow-landscape", CGSize(width: 568, height: 300))] {
            for (state, page) in pages {
                let layout = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
                guard Set(layout.targets.map { $0.action.id }).count == layout.targets.count,
                      layout.targets.filter({ $0.action.primary && $0.action.enabled }).count <= 1 else { throw Failure.invalidTargets }
                for target in layout.targets {
                    guard target.frame.width >= 44, target.frame.height >= 44,
                          CGRect(origin: .zero, size: layout.size).contains(target.frame),
                          layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == (target.action.enabled ? target.action.id : nil)
                    else { throw Failure.invalidTargets }
                }
                guard layout.action(at: CGPoint(x: layout.board.minX + 1, y: layout.board.midY)) == nil else { throw Failure.invalidTargets }
                for (index, target) in layout.targets.enumerated() {
                    for other in layout.targets.dropFirst(index + 1) where target.frame.intersects(other.frame) { throw Failure.invalidTargets }
                }
                guard let context = CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height),
                                               bitsPerComponent: 8, bytesPerRow: Int(layout.size.width) * 4,
                                               space: CGColorSpaceCreateDeviceRGB(),
                                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.missingArtwork }
                context.translateBy(x: 0, y: layout.size.height); context.scaleBy(x: 1, y: -1)
                GameFrontEnd.draw(page, layout: layout, typography: typography, preview: image,
                                 previewSource: previewSource, portraits: portraits, in: context)
                guard let result = context.makeImage() else { throw Failure.missingArtwork }
                let file = output.appendingPathComponent("\(device)-\(state).png")
                guard let destination = CGImageDestinationCreateWithURL(file as CFURL, "public.png" as CFString, 1, nil) else { throw Failure.missingArtwork }
                CGImageDestinationAddImage(destination, result, nil)
                guard CGImageDestinationFinalize(destination) else { throw Failure.missingArtwork }
                evidence.append(["device": device, "state": state, "viewportWidth": size.width, "viewportHeight": size.height,
                                 "contentHeight": layout.size.height, "targets": layout.targets.count,
                                 "needsVerticalScroll": layout.size.height > size.height, "file": file.lastPathComponent,
                                 "minimumTouchExtent": 44, "disabledAndGapTargetsBlocked": true])
            }
        }
        let adaptive = try auditAdaptive(session: session, typography: typography, artwork: artwork, output: output)
        let covers = try auditBrowser(typography: typography, preview: image, output: output)
        let settingsSizes = try auditSettingsSizes(typography: typography, output: output)
        let report: [String: Any] = ["renderedStates": evidence.count, "originalMacGlyphsAndLogo": true,
                                    "targetsValidated": true, "audio": "muted", "windows": "none",
                                    "physicalUIKitAcceptance": "pending", "captures": evidence, "adaptiveHUD": adaptive,
                                    "coverArtwork": covers, "settingsSizes": settingsSizes]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("report.json"), options: .atomic)
        print("PASS: \(evidence.count) pages, \(adaptive.count) HUD states , \(covers.count) cover states and 3 unfold frames; touch targets, reserved regions and scroll reachability.")
    }
    static func careerPages() throws -> [(String, GameFrontEnd.Page)] {
        var profiles = MobileProfiles()
        profiles.rename(MobileProfiles.defaultID, to: "AB")
        for index in 1..<8 {
            _ = profiles.add(name: "AB", id: "player-\(index)")
            profiles.setPortrait("player-\(index)", to: index)
        }
        var records = ArcadeRecords()
        try records.importProfiles(profiles.players.map { .init(id: $0.id, initials: $0.name, portrait: $0.portrait) }, activeID: profiles.activeID)
        let empty = records
        let level = ArcadeLevel(id: "fun-1", title: "Just Dig!", game: "Lemmings", rules: "DOS", total: 10, required: 5)
        _ = records.record(.init(profileID: profiles.activeID, level: level, saved: 10, didWin: true, skills: [:], seconds: 12.34))
        _ = records.record(.init(profileID: profiles.activeID, level: level, saved: 8, didWin: true, skills: ["dig": 1], seconds: 18, assisted: true))
        typealias Action = GameFrontEnd.Action
        let communityRows: [Action] = [.init("rankCategory", "Career stars"), .init("rankShare", "Share records", selected: true)]
        let boards: [Action] = ["Career stars", "Levels cleared", "Three-star levels", "This level", "Fastest clear", "Fastest 100%"].enumerated().map {
            .init("rankBoard.board-\($0.offset)", $0.element, selected: $0.offset == 0)
        }
        return [
            ("players-full", MobileCareerArt.players(profiles, subtitle: "", canDelete: true)),
            ("players-protected", MobileCareerArt.players(profiles, subtitle: "", canDelete: false)),
            ("players-delete", MobileCareerArt.players(profiles, subtitle: "", canDelete: true, confirmingDelete: true)),
            ("players-new", MobileCareerArt.players(profiles, subtitle: "", draft: "", creating: true, portrait: 7)),
            ("players-edit", MobileCareerArt.players(profiles, subtitle: "", draft: "AB", portrait: 3)),
            ("records-empty", MobileCareerArt.recordsPage(records: empty, profileID: profiles.activeID, profileName: "AB", subtitle: "")),
            ("records-levels", MobileCareerArt.recordsPage(records: records, profileID: profiles.activeID, profileName: "AB", subtitle: "")),
            ("records-direct", MobileCareerArt.recordLevelPage("direct|" + level.boardID, records: records, profileID: profiles.activeID, profileName: "AB", subtitle: "")),
            ("records-assisted", MobileCareerArt.recordLevelPage("assisted|" + level.boardID, records: records, profileID: profiles.activeID, profileName: "AB", subtitle: "")),
            ("achievements-empty", MobileCareerArt.achievementsPage(records: empty, profileID: profiles.activeID, profileName: "AB", subtitle: "")),
            ("achievements-earned", MobileCareerArt.achievementsPage(records: records, profileID: profiles.activeID, profileName: "AB", subtitle: "")),
            ("rankings-loading", MobileCareerArt.rankings(community: true, subtitle: "", busy: true, status: "", rows: communityRows, connected: false, available: true)),
            ("rankings-empty", MobileCareerArt.rankings(community: true, subtitle: "", busy: false, status: "No scores", rows: communityRows, connected: false, available: true)),
            ("rankings-offline", MobileCareerArt.rankings(community: true, subtitle: "", busy: false, status: "Connection unavailable", rows: communityRows, connected: false, available: true)),
            ("rankings-replays", MobileCareerArt.rankings(community: true, subtitle: "", busy: false, status: "", rows: communityRows + [.init("rankReplay.1", "#1 AB 12:34", enabled: true), .init("rankReplay.2", "#2 CD 12:56", enabled: false)], connected: false, available: true)),
            ("gamecenter-unavailable", MobileCareerArt.rankings(community: false, subtitle: "", busy: false, status: "Unavailable", rows: boards.map { .init($0.id, $0.title, enabled: false) }, connected: false, available: false)),
            ("gamecenter-connect", MobileCareerArt.rankings(community: false, subtitle: "", busy: false, status: "", rows: boards, connected: false, available: true)),
            ("gamecenter-scores", MobileCareerArt.rankings(community: false, subtitle: "", busy: false, status: "", rows: boards + [.init("rankRow.1", "#1 AB 120", enabled: false)], connected: true, available: true))
        ]
    }
    static func auditSettingsSizes(typography: GameMenuTypography, output: URL) throws -> [[String: Any]] {
        var evidence: [[String: Any]] = []
        for (device, size) in [("ipad-portrait", CGSize(width: 834, height: 1092)),
                               ("ipad-landscape", CGSize(width: 1112, height: 814)),
                               ("iphone-portrait", CGSize(width: 390, height: 763)),
                               ("iphone-landscape", CGSize(width: 756, height: 369)),
                               ("iphone-narrow-portrait", CGSize(width: 320, height: 548)),
                               ("iphone-narrow-landscape", CGSize(width: 568, height: 300))] {
            for interfaceSize in [ClassicInterfaceSize.large, .extraLarge] {
                var settings = MobileSettings(); settings.classic.interfaceSize = interfaceSize
                let scale = MobileSettingsArt.interfaceScale(interfaceSize, width: size.width)
                for group in MobileSettingsGroup.allCases {
                    let page = MobileSettingsArt.page(group, settings: settings)
                    let layout = GameFrontEnd.layout(page, width: size.width / scale, minimumHeight: size.height / scale)
                    let transform = CGAffineTransform(scaleX: scale, y: scale)
                    let content = CGSize(width: layout.size.width * scale, height: layout.size.height * scale)
                    guard abs(content.width - size.width) < 0.01 else { throw Failure.invalidTargets }
                    for target in layout.targets {
                        let actual = target.frame.applying(transform)
                        guard actual.width >= 44, actual.height >= 44,
                              CGRect(origin: .zero, size: content).contains(actual),
                              layout.action(at: CGPoint(x: actual.midX / scale, y: actual.midY / scale))
                                == (target.action.enabled ? target.action.id : nil) else { throw Failure.invalidTargets }
                    }
                    let context = try bitmapContext(size: content)
                    context.scaleBy(x: scale, y: scale)
                    GameFrontEnd.draw(page, layout: layout, typography: typography, in: context)
                    let file = "\(device)-settings-\(group.rawValue)-\(interfaceSize.rawValue).png"
                    try save(context: context, to: output.appendingPathComponent(file))
                    evidence.append(["device": device, "group": group.rawValue, "size": interfaceSize.rawValue,
                                     "scale": scale, "targets": layout.targets.count, "file": file,
                                     "minimumTouchExtent": 44, "contentFitsWidth": true])
                }
            }
        }
        return evidence
    }
    @MainActor static func auditAdaptive(session: any MobileGameSession, typography: GameMenuTypography,
                              artwork: URL, output: URL) throws -> [[String: Any]] {
        let vertical = MobileReservedRegion(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834))
        let horizontal = MobileReservedRegion(kind: .division, frame: .init(x: 0, y: 405, width: 1194, height: 24))
        let poses: [(String, MobileSize, [MobileReservedRegion])] = [
            ("ipad-landscape", .init(width: 1112, height: 834), []),
            ("ipad-portrait", .init(width: 834, height: 1112), []),
            ("pocket", .init(width: 390, height: 844), []),
            ("open", .init(width: 1194, height: 834), [vertical]),
            ("diorama", .init(width: 1194, height: 834), [horizontal]),
            ("camera", .init(width: 1194, height: 834), [vertical, .init(kind: .occlusion, frame: .init(x: 1120, y: 740, width: 74, height: 94))]),
            ("resized", .init(width: 568, height: 320), []),
            ("unavailable", .init(width: 280, height: 160), []),
        ]
        let image = MobileBitmapRenderer.image(try session.render(highlight: nil))
        let panel = session.panelFrame.flatMap(MobileBitmapRenderer.image)
        var evidence: [[String: Any]] = []
        for (pose, size, regions) in poses {
            for (state, paused, ending, selected, speed) in [
                ("ready", true, false, 0, 1.0), ("running", false, false, 1, 1.0),
                ("fast", false, false, 3, 5.0), ("armed", true, false, 2, 1.0),
                ("undo", true, true, 7, 1.0),
            ] {
                let original = session.snapshot
                let snapshot = MobileGameSnapshot(tick: original.tick, released: original.released, total: original.total,
                    saved: original.saved, required: original.required, remainingSeconds: original.remainingSeconds,
                    releaseRate: original.releaseRate, isComplete: false, didWin: false, isEndingRun: ending, skills: original.skills)
                let layout = MobileHUDLayout.make(container: size, safeArea: .init(top: 20, bottom: 20),
                    hasRate: true, skillCount: snapshot.skills.count, reservedRegions: regions, supportsRewind: true)
                let targets = MobileHUDRenderer.targets(layout: layout, snapshot: snapshot, selectedSkill: selected,
                    paused: paused, speed: speed, endRunArmed: state == "armed")
                let safe = cg(layout.interface.safeFrame)
                for (index, target) in targets.enumerated() {
                    let frame = target.inputFrame
                    guard frame.width >= 44 - 0.001, frame.height >= 44, safe.contains(frame),
                          !target.accessibilityLabel.isEmpty,
                          regions.allSatisfy({ !frame.intersects(cg($0.frame)) }) else { throw Failure.invalidTargets }
                    for other in targets.dropFirst(index + 1) where frame.intersection(other.inputFrame).width > 0.001
                        && frame.intersection(other.inputFrame).height > 0.001 { throw Failure.invalidTargets }
                    let hit = targets.first { $0.inputFrame.contains(CGPoint(x: frame.midX, y: frame.midY)) }
                    guard hit?.action == target.action else { throw Failure.invalidTargets }
                }
                let context = try bitmapContext(size: CGSize(width: size.width, height: size.height))
                context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
                if let image {
                    let field = cg(layout.interface.playfieldFrame)
                    let viewport = MobileViewport(levelSize: session.levelSize, viewSize: .init(width: field.width, height: field.height),
                        origin: .init(x: 400, y: 0), zoom: 2, pixelAspect: 1.2)
                    context.saveGState(); context.translateBy(x: field.minX, y: field.minY)
                    context.clip(to: CGRect(origin: .zero, size: field.size))
                    MobileBitmapRenderer.draw(image, viewport: viewport, in: context); context.restoreGState()
                }
                MobileHUDRenderer(layout: layout, snapshot: snapshot, selectedSkill: selected, paused: paused, speed: speed,
                    endRunArmed: state == "armed", panelImage: panel, typography: typography)
                    .draw(in: context, bounds: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                if let panel = layout.panel {
                    let field = layout.interface.playfieldFrame
                    let camera = MobileViewport(levelSize: session.levelSize, viewSize: field.size,
                                                origin: .init(x: 400, y: 0), zoom: 2, pixelAspect: 1.2)
                    GameMinimapArt.draw(in: context, bounds: panel.minimap, image: image,
                                       visible: cg(camera.visibleLevelRect), levelSize: CGSize(width: session.levelSize.width, height: session.levelSize.height))
                }
                if !layout.canPlay {
                    let page = GameFrontEnd.Page(title: "Paused", footer: [.init("library", "Library", primary: true)])
                    let menu = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
                    GameFrontEnd.draw(page, layout: menu, typography: typography, in: context)
                }
                let file = "hud-\(pose)-\(state).png"
                try save(context: context, to: output.appendingPathComponent(file))
                evidence.append(["pose": pose, "state": state, "targets": targets.count, "canPlay": layout.canPlay,
                                 "diorama": layout.isDiorama, "file": file])
            }
        }
        guard let unfold = GameUnfoldArt(directory: artwork) else { throw Failure.missingArtwork }
        for progress in [CGFloat(0), 0.5, 1] {
            let context = try bitmapContext(size: .init(width: 600, height: 400))
            let page = GameFrontEnd.Page(title: "Lemmings", home: true, rows: [.init("play", "Lemmings", primary: true)])
            let layout = GameFrontEnd.layout(page, width: 600, minimumHeight: 400)
            GameFrontEnd.draw(page, layout: layout, typography: typography, in: context)
            let region = CGRect(x: 0, y: 0, width: 600, height: 400)
            guard region.contains(unfold.frame(in: region, progress: progress)),
                  layout.targets.allSatisfy({ !$0.frame.intersects(unfold.frame(in: region, progress: progress)) })
            else { throw Failure.invalidTargets }
            unfold.draw(in: context, region: region, progress: progress)
            try save(context: context, to: output.appendingPathComponent("unfold-\(Int(progress * 100)).png"))
        }
        return evidence
    }

    static func auditBrowser(typography: GameMenuTypography, preview: CGImage, output: URL) throws -> [[String: Any]] {
        var evidence: [[String: Any]] = []
        for (pose, size) in [("portrait", CGSize(width: 834, height: 1112)), ("landscape", CGSize(width: 1112, height: 834))] {
            let safe = CGRect(x: 0, y: 20, width: size.width, height: size.height - 40)
            let layout = LevelBrowserGeometry(safe: safe)
            for (index, frame) in layout.actions.enumerated() {
                guard frame.width >= 44, frame.height >= 44, safe.contains(frame),
                      layout.actions.dropFirst(index + 1).allSatisfy({ !frame.intersects($0) }) else { throw Failure.invalidTargets }
            }
            let geometry = LevelCoverArt.geometry(for: layout.stage.size)
            let card = CGRect(x: layout.stage.midX - geometry.cardSize.width * 0.75,
                              y: layout.stage.midY - geometry.cardSize.height * 0.75,
                              width: geometry.cardSize.width * 1.5, height: geometry.cardSize.height * 1.5)
            guard layout.stage.contains(card), !layout.actions.contains(where: { $0.intersects(card) }) else { throw Failure.invalidTargets }
            for (state, selected, image) in [("selected", true, preview as CGImage?), ("inactive", false, preview as CGImage?), ("loading", true, nil)] {
                let context = try bitmapContext(size: size)
                context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(origin: .zero, size: size))
                GameMenuFrameArt.draw(in: context, board: layout.board)
                GamePixelTypography.draw("Just Dig!", in: layout.title, context: context, typography: typography, palette: .green, face: .large)
                GamePixelTypography.draw("Fun 1/30", in: layout.subtitle, context: context, typography: typography)
                LevelCoverArt.draw(in: context, bounds: card, title: "1  Just Dig!", artwork: image, selected: selected, typography: typography)
                for (index, frame) in layout.actions.enumerated() {
                    GameStoneArt.draw(in: context, frame: frame, selected: index == 3, pixel: 1)
                    GamePixelTypography.draw(["Back", "< Rank", "Rank >", "Play"][index], in: frame.insetBy(dx: 12, dy: 2),
                                             context: context, typography: typography, palette: index == 3 ? .green : .blue)
                }
                let file = "cover-\(pose)-\(state).png"
                try save(context: context, to: output.appendingPathComponent(file))
                evidence.append(["pose": pose, "state": state, "file": file, "targets": layout.actions.count,
                                 "perspectiveLayersAndUIKitHitDispatch": "pending"])
            }
        }
        return evidence
    }

    static func cg(_ rect: MobileRect) -> CGRect { CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height) }
    static func bitmapContext(size: CGSize) throws -> CGContext {
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.missingArtwork }
        context.translateBy(x: 0, y: size.height); context.scaleBy(x: 1, y: -1)
        return context
    }
    static func save(context: CGContext, to file: URL) throws {
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(file as CFURL, "public.png" as CFString, 1, nil)
        else { throw Failure.missingArtwork }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw Failure.missingArtwork }
    }
    enum Failure: Error { case invalidArguments, missingArtwork, invalidTargets }
}
