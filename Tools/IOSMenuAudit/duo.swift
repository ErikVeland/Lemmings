import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkDuo(typography: GameMenuTypography, artwork: URL, content: URL, output: URL) throws {
        let ports = content.deletingLastPathComponent()
        let storage = MobileStorage(directory: output.appendingPathComponent("isolated-storage"))
        let libraries: [any MobileGameLibrary] = [try ClassicMobileLibrary(directory: content),
            try Lemmings2MobileLibrary(directory: ports.appendingPathComponent("Lemm2"), storage: storage),
            try Lemmings3MobileLibrary(directory: ports.appendingPathComponent("LEM3CD"), storage: storage)]
        let poses: [(String, MobileSize, MobileInsets, [MobileReservedRegion])] = [
            ("book", .init(width: 1194, height: 834), .init(top: 20, bottom: 20),
                [.init(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834))]),
            ("stacked", .init(width: 834, height: 1194), .init(top: 20, bottom: 20),
                [.init(kind: .division, frame: .init(x: 0, y: 589, width: 834, height: 16))]),
            ("wide-stacked", .init(width: 1194, height: 834), .init(top: 20, bottom: 20),
                [.init(kind: .division, frame: .init(x: 0, y: 405, width: 1194, height: 24))]),
            ("compact-book", .init(width: 650, height: 465), .init(top: 20, bottom: 20),
                [.init(kind: .division, frame: .init(x: 318, y: 0, width: 14, height: 465))]),
            ("compact-stacked", .init(width: 465, height: 650), .init(top: 20, bottom: 20),
                [.init(kind: .division, frame: .init(x: 0, y: 318, width: 465, height: 14))]),
            ("closed-landscape", .init(width: 650, height: 465), .init(top: 20, left: 20, bottom: 20, right: 20), []),
            ("closed-portrait", .init(width: 465, height: 650), .init(top: 20, bottom: 20), []),
            ("navigation-right", .init(width: 495, height: 720), .init(top: 10, left: 10, bottom: 44, right: 95), []),
            ("navigation-left", .init(width: 495, height: 720), .init(top: 10, left: 95, bottom: 44, right: 10), []),
            ("camera-book", .init(width: 1194, height: 834), .init(top: 20, bottom: 20),
                [.init(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834)),
                 .init(kind: .occlusion, frame: .init(x: 1120, y: 740, width: 74, height: 94))])
        ]
        var captures = 0
        var previewImage: CGImage?
        var previewSource = CGRect.zero
        for library in libraries {
            let session = try library.loadLevel(at: 0).session
            var settings = ClassicSettings(); settings.music = .silent
            session.applySettings(settings)
            for _ in 0..<100 { session.tick() }
            let image = MobileBitmapRenderer.image(try session.render(highlight: nil))
            if previewImage == nil {
                previewImage = image
                previewSource = CGRect(x: session.initialCameraOrigin.x, y: 0, width: 320, height: 160)
            }
            let panel = session.panelFrame.flatMap(MobileBitmapRenderer.image)
            let icons = session.snapshot.skills.indices.map { session.skillCursorFrame(control: $0).flatMap(MobileBitmapRenderer.image) }
            for (pose, size, insets, regions) in poses {
                for state in ["running", "paused", "selected-last", "fast", "armed", "undo"] {
                    let original = session.snapshot
                    let snapshot = MobileGameSnapshot(tick: original.tick, released: original.released, total: original.total,
                        saved: original.saved, required: original.required, remainingSeconds: original.remainingSeconds,
                        releaseRate: original.releaseRate, isComplete: false, didWin: false,
                        isEndingRun: state == "undo", skills: original.skills)
                    let rail: MobileRect? = pose.hasPrefix("navigation-")
                        ? .init(x: pose == "navigation-right" ? 404 : 4, y: 60, width: 87, height: 600) : nil
                    let layout = MobileHUDLayout.make(container: size, safeArea: insets,
                        hasRate: snapshot.releaseRate != nil, skillCount: snapshot.skills.count,
                        reservedRegions: regions, supportsRewind: true, hasPlayer: true, engineIdentifier: session.engineIdentifier,
                        navigationRail: rail)
                    guard layout.canPlay, let minimap = layout.minimapFrame else { throw invalidTargets(line: #line) }
                    if let deck = layout.portrait {
                        guard deck.skillContentWidth <= deck.skills.width + 0.001 else { throw invalidTargets(line: #line) }
                    } else {
                        guard ["classic", "classic-dos"].contains(session.engineIdentifier),
                              let panel = layout.panel, panel.scale >= 3,
                              panel.frame.width == 320 * panel.scale else { throw invalidTargets(line: #line) }
                    }
                    let paused = state == "paused"
                    let selected = state == "selected-last" ? snapshot.skills.count - 1 : 0
                    let speed = state == "fast" ? 4.0 : 1
                    let targets = MobileHUDRenderer.targets(layout: layout, snapshot: snapshot,
                        selectedSkill: selected, paused: paused, speed: speed, endRunArmed: state == "armed")
                    let field = cg(layout.interface.playfieldFrame)
                    if let rail {
                        let pause = targets.first { $0.action == .pause }?.frame
                        let end = targets.first { $0.action == .endRun }?.frame
                        guard let deck = layout.portrait,
                              layout.interface.controlsPlacement == .trailingRail,
                              layout.interface.controlsFrame == rail,
                              pause?.minY == deck.skills.minY, pause?.maxY == deck.skills.maxY,
                              end?.minY == deck.minimap.minY, end?.height == deck.minimap.height
                        else { throw invalidTargets(line: #line) }
                    }
                    for (index, item) in targets.enumerated() {
                        let frame = item.inputFrame
                        guard frame.width >= 44 - 0.001, frame.height >= 44, hudTargetFits(item, layout: layout),
                              !frame.intersects(field), !frame.intersects(minimap),
                              !frame.intersects(cg(layout.interface.statusFrame)),
                              regions.allSatisfy({ !frame.intersects(cg($0.frame)) }),
                              targets.first(where: { $0.inputFrame.contains(CGPoint(x: frame.midX, y: frame.midY)) })?.action == item.action,
                              !item.accessibilityLabel.isEmpty else { throw invalidTargets(line: #line) }
                        for other in targets.dropFirst(index + 1) {
                            let overlap = frame.intersection(other.inputFrame)
                            guard overlap.isNull || overlap.width <= 0.001 || overlap.height <= 0.001 else { throw invalidTargets(line: #line) }
                        }
                    }
                    if let division = regions.first(where: { $0.kind == .division }) {
                        guard field.minX == layout.interface.safeFrame.minX,
                              field.maxX == layout.interface.safeFrame.maxX,
                              layout.interface.controlsFrame.maxY == layout.interface.safeFrame.maxY else { throw invalidTargets(line: #line) }
                        if let deck = layout.portrait {
                            guard deck.skills.width == layout.interface.safeFrame.width else { throw invalidTargets(line: #line) }
                        } else {
                            guard let panel = layout.panel, division.frame.width > division.frame.height,
                                  panel.frame.minY >= division.frame.maxY else { throw invalidTargets(line: #line) }
                        }
                        if division.frame.height > division.frame.width {
                            guard field.intersects(cg(division.frame)), field.maxY == minimap.minY else { throw invalidTargets(line: #line) }
                        } else {
                            guard field.maxY == division.frame.minY,
                                  layout.interface.controlsFrame.minY >= division.frame.maxY else { throw invalidTargets(line: #line) }
                        }
                        let status = MobileHUDRenderer.statusFrames(layout: layout, hasPlayer: true)
                        for frame in [status.player, status.counters].compactMap({ $0 }) {
                            guard regions.allSatisfy({ !frame.intersects(cg($0.frame)) }) else { throw invalidTargets(line: #line) }
                        }
                    }
                    if rail != nil {
                        let status = MobileHUDRenderer.statusFrames(layout: layout, hasPlayer: true)
                        let fields = MobileHUDRenderer.statusFields(in: status.counters, snapshot: snapshot,
                            details: nil, engineIdentifier: session.engineIdentifier, paused: paused,
                            speed: speed, typography: typography)
                        guard fields.contains(where: { $0.id == "score" }),
                              fields.contains(where: { $0.id == "time" }),
                              fields.allSatisfy({ !$0.bitmapOnly && status.counters.contains($0.frame) })
                        else { throw invalidTargets(line: #line) }
                    }
                    let context = try bitmapContext(size: CGSize(width: size.width, height: size.height))
                    context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    var viewport = MobileViewport(levelSize: session.levelSize,
                        viewSize: .init(width: field.width, height: field.height), pixelAspect: session.renderScale == 1 ? 1.2 : 1)
                    viewport.fitGameplay(in: .init(width: field.width, height: field.height), centring: session.entrancePoint)
                    if let image {
                        context.saveGState(); context.translateBy(x: field.minX, y: field.minY)
                        MobileBitmapRenderer.draw(image, viewport: viewport, in: context); context.restoreGState()
                    }
                    MobileHUDRenderer(layout: layout, snapshot: snapshot, selectedSkill: selected, paused: paused, speed: speed,
                        endRunArmed: state == "armed", panelImage: panel, typography: typography,
                        skillIcons: icons, playerName: "ALICE").draw(in: context, bounds: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    GameMinimapArt.draw(in: context, bounds: minimap, image: image,
                        visible: cg(viewport.visibleLevelRect), levelSize: CGSize(width: session.levelSize.width, height: session.levelSize.height), overlay: true)
                    for region in regions {
                        context.setFillColor(CGColor(gray: 0.15, alpha: 1)); context.fill(cg(region.frame))
                    }
                    try save(context: context, to: output.appendingPathComponent("\(session.engineIdentifier)-\(pose)-\(state).png"))
                    captures += 1
                }
            }
        }
        for size in [CGSize(width: 589, height: 794), .init(width: 834, height: 549),
                     .init(width: 650, height: 425), .init(width: 465, height: 610)] {
            for setting in ClassicInterfaceSize.allCases {
                let scale = MobileSettingsArt.interfaceScale(setting, width: size.width)
                let page = GameFrontEnd.Page(title: "Just Dig!", subtitle: "Fun 1/30",
                    details: ["10 Lemmings save 1", "Time 5:01"],
                    footer: [.init("back", "Library"), .init("start", "Start", primary: true)], preview: true)
                let layout = GameFrontEnd.layout(page, width: size.width / scale, minimumHeight: size.height / scale)
                for target in layout.targets {
                    guard CGRect(origin: .zero, size: layout.size).contains(target.frame),
                          target.frame.height * scale >= 44,
                          layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == target.action.id
                    else { throw invalidTargets(line: #line) }
                }
                let context = try bitmapContext(size: CGSize(width: layout.size.width * scale, height: layout.size.height * scale))
                context.scaleBy(x: scale, y: scale)
                GameFrontEnd.draw(page, layout: layout, typography: typography, preview: previewImage,
                    previewSource: previewSource, in: context)
                try save(context: context, to: output.appendingPathComponent("preview-\(Int(size.width))-\(setting.rawValue).png"))
                captures += 1
            }
        }
        captures += try checkDuoDeskClock(typography: typography, artwork: artwork,
            poses: poses.filter { ["book", "stacked", "compact-stacked", "closed-landscape", "closed-portrait"].contains($0.0) },
            output: output)
        print("PASS: \(captures) Duo bitmap captures, all three native engines, gameplay across both upper panes, lower-area fill, complete skills, status, minimap, target sizes, hit testing, preview actions and the Desk Clock. Windowless and muted.")
    }

    /// The Desk Clock in each pose: the scene clear of the hinge, and the close control's target. Stacked pose
    /// shows only Close in the lower pane; other poses show Close as it appears after a touch.
    @MainActor static func checkDuoDeskClock(typography: GameMenuTypography, artwork: URL,
                                             poses: [(String, MobileSize, MobileInsets, [MobileReservedRegion])],
                                             output: URL) throws -> Int {
        guard poses.count == 5, let art = GameDeskClockArt(directory: artwork) else { throw Failure.missingArtwork }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_GB")
        let now = Date(timeIntervalSince1970: 1_792_143_000)
        let event = DeskClockEvent(start: now.addingTimeInterval(5 * 60), title: "Standup", nuke: false)
        let sim = DeskClockSimulation.still(at: now, event: event, uses24Hour: true, calendar: calendar)
        var captures = 0
        for (pose, size, insets, regions) in poses {
            let safe = MobileRect(x: insets.left, y: insets.top, width: size.width - insets.left - insets.right,
                                  height: size.height - insets.top - insets.bottom)
            let layout = DeskClockLayout.make(safe: safe, regions: regions)
            let scene = cg(layout.scene), close = cg(layout.close), safeFrame = cg(safe)
            guard layout.stacked == pose.hasSuffix("stacked"), safeFrame.contains(scene), safeFrame.contains(close),
                  close.width >= 44, close.height >= 44, scene.width >= 280,
                  regions.allSatisfy({ !cg($0.frame).intersects(scene) && !cg($0.frame).intersects(close) })
            else { throw invalidTargets(line: #line) }
            if let pane = layout.pane.map(cg) {
                // The scene above already shows the event, so the lower pane holds only Close.
                guard pane.contains(close), !pane.intersects(scene) else { throw invalidTargets(line: #line) }
            } else {
                guard scene.contains(close) else { throw invalidTargets(line: #line) }
            }
            let context = try bitmapContext(size: CGSize(width: size.width, height: size.height))
            context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
            art.draw(sim, event: event, now: now, time: 0.25, in: context, rect: scene, nightDim: false)
            // The same drawing as MobilePixelButton, the primary stone control.
            GameStoneArt.draw(in: context, frame: close, selected: true, pixel: 1)
            GamePixelTypography.draw(L10n.text("Close"), in: CGRect(x: close.minX + 12, y: close.midY - 10,
                width: close.width - 24, height: 20), context: context, typography: typography, palette: .green)
            for region in regions {
                context.setFillColor(CGColor(gray: 0.15, alpha: 1)); context.fill(cg(region.frame))
            }
            try save(context: context, to: output.appendingPathComponent("desk-clock-\(pose).png"))
            captures += 1
        }
        return captures
    }
}
