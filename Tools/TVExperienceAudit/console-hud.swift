import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension TVExperienceAudit {
    @MainActor static func checkConsoleHUD(typography: GameMenuTypography, root: URL) throws {
        let output = root.appendingPathComponent(".build/tv-experience/console-hud")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let storage = MobileStorage(directory: output.appendingPathComponent("saves"))
        let libraries: [any MobileGameLibrary] = [
            try ClassicMobileLibrary(directory: root.appendingPathComponent("Sources/Ports/lemmings_dos_1991-07-30")),
            try Lemmings2MobileLibrary(directory: root.appendingPathComponent("Sources/Ports/Lemm2"), storage: storage),
            try Lemmings3MobileLibrary(directory: root.appendingPathComponent("Sources/Ports/LEM3CD"), storage: storage)
        ]
        var captures = 0
        for library in libraries {
            let session = try library.loadLevel(at: 0).session
            let snapshot = session.snapshot
            for size in [MobileSize(width: 1920, height: 1080), .init(width: 1280, height: 720), .init(width: 640, height: 360)] {
                let touch = MobileHUDLayout.make(container: size, safeArea: .init(), hasRate: snapshot.releaseRate != nil,
                    skillCount: snapshot.skills.count, supportsRewind: session.supportsRewind,
                    hasPlayer: true, engineIdentifier: session.engineIdentifier)
                let console = MobileHUDLayout.make(container: size, safeArea: .init(), hasRate: snapshot.releaseRate != nil,
                    skillCount: snapshot.skills.count, supportsRewind: session.supportsRewind,
                    hasPlayer: true, engineIdentifier: session.engineIdentifier, showsMenuButton: false)
                for paused in [false, true] {
                    let touchItems = MobileHUDRenderer.targets(layout: touch, snapshot: snapshot, selectedSkill: 0,
                        paused: paused, speed: 1, endRunArmed: false)
                    let items = MobileHUDRenderer.targets(layout: console, snapshot: snapshot, selectedSkill: 0,
                        paused: paused, speed: 1, endRunArmed: false)
                    guard console.canPlay, !items.contains(where: { $0.action == .menu }),
                          items.map(\.action) == touchItems.filter({ $0.action != .menu }).map(\.action),
                          console.interface.controlFrames.count == touch.interface.controlFrames.count - 1 else {
                        throw Failure.invalid("Console HUD menu or remaining actions differ: " + session.engineIdentifier)
                    }
                    for (index, item) in items.enumerated() {
                        guard item.inputFrame.width >= 44, item.inputFrame.height >= 44,
                              CGRect(x: 0, y: 0, width: size.width, height: size.height).contains(item.inputFrame),
                              !items.dropFirst(index + 1).contains(where: { item.inputFrame.intersects($0.inputFrame) }) else {
                            throw Failure.invalid("Console HUD input bounds: \(session.engineIdentifier) \(size.width) \(item.action) \(item.inputFrame)")
                        }
                    }
                    let bitmap = try context(width: Int(size.width), height: Int(size.height))
                    bitmap.setFillColor(CGColor(gray: 0, alpha: 1))
                    bitmap.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    let renderer = MobileHUDRenderer(layout: console, snapshot: snapshot, selectedSkill: 0,
                        paused: paused, speed: 1, endRunArmed: false,
                        panelImage: session.panelFrame.flatMap(MobileBitmapRenderer.image), typography: typography,
                        playerName: "Player 1")
                    renderer.draw(in: bitmap, bounds: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    try png(bitmap, at: output.appendingPathComponent("\(session.engineIdentifier)-\(Int(size.width))-\(paused ? "paused" : "active").png"))
                    captures += 1
                }
            }
        }
        print("PASS \(captures) console HUD renders and input layouts across Classic, L2 and L3; no Menu target")
    }
}
