import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkGridHUD(typography: GameMenuTypography, content: URL, output: URL) throws {
        let session = try ClassicMobileLibrary(directory: content).loadLevel(at: 0).session
        var settings = ClassicSettings()
        settings.music = .silent
        session.applySettings(settings)
        let original = session.snapshot
        let bounds = CGRect(x: 0, y: 0, width: 465, height: 650)
        let panel = session.panelFrame.flatMap(MobileBitmapRenderer.image)
        let icons = original.skills.indices.map { session.skillCursorFrame(control: $0).flatMap(MobileBitmapRenderer.image) }
        for engine in ["classic", "lemmings2", "lemmings3"] {
            for hasRate in [false, true] {
                let snapshot = MobileGameSnapshot(tick: original.tick, released: original.released, total: original.total,
                    saved: original.saved, required: original.required, remainingSeconds: original.remainingSeconds,
                    releaseRate: hasRate ? 50 : nil, isComplete: false, didWin: false,
                    isEndingRun: false, skills: original.skills)
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
                      (hasRate ? portrait.rateValue?.minX == bounds.minX + 44 : firstTransport.frame.minX == bounds.minX),
                      zip(skills, skills.dropFirst()).allSatisfy({ $0.frame.maxX == $1.frame.minX }),
                      zip(navigation, navigation.dropFirst()).allSatisfy({ $0.frame.maxX == $1.frame.minX }),
                      zip(transport, transport.dropFirst()).allSatisfy({ $0.frame.maxX == $1.frame.minX })
                else { throw invalidTargets(line: #line) }
                let edge = targets.map { MobileHUDRenderer.edgeInputFrame(for: $0, layout: layout, displayBounds: bounds, screenEdges: true) }
                guard edge.enumerated().allSatisfy({ index, frame in
                    bounds.contains(frame) && edge.dropFirst(index + 1).allSatisfy { !frame.intersects($0) }
                }) else { throw invalidTargets(line: #line) }
                let context = try bitmapContext(size: bounds.size)
                context.saveGState()
                context.addPath(CGPath(roundedRect: bounds, cornerWidth: 90, cornerHeight: 90, transform: nil))
                context.clip()
                MobileHUDRenderer(layout: layout, snapshot: snapshot, selectedSkill: 0, paused: false, speed: 1,
                    endRunArmed: false, panelImage: panel, typography: typography, skillIcons: icons,
                    playerName: "PLA", shape: .rounded, duoCorners: true, displayBounds: bounds,
                    displayCornerRadius: 90).draw(in: context, bounds: bounds)
                GameMinimapArt.draw(in: context, bounds: portrait.minimap, image: nil, visible: .zero,
                    levelSize: .zero, overlay: true)
                context.restoreGState()
                try save(context: context, to: output.appendingPathComponent("\(engine)-\(hasRate ? "rate" : "no-rate").png"))
            }
        }
        print("PASS: six muted, windowless grid renders; joined rows, minimap and non-overlapping input targets.")
    }
}
