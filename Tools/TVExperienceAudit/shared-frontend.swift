import CoreGraphics
import Foundation
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension TVExperienceAudit {
    @MainActor static func checkSharedFrontend(typography: GameMenuTypography, portraits: GamePortraitArt?,
                                              library: ClassicMobileLibrary, root: URL) throws {
        let output = root.appendingPathComponent(".build/tv-experience/shared-frontend")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        typealias Action = GameFrontEnd.Action
        var profiles = MobileProfiles()
        _ = profiles.add(name: "Guest player", id: "guest")
        let home = MobileHomeArt.page(resume: [.init("resume", "Resume level - Player 1")],
            journey: .init("journey", "Journey  29/295 solved"),
            families: [.init("classic", "Classic Lemmings"), .init("ohNo", "Oh No! More Lemmings"),
                       .init("holiday", "Holiday Lemmings"), .init("ohYes", "Oh Yes! More Lemmings"),
                       .init("fan", "Fan Lemmings"), .init("neolemmix", "NeoLemmix Preview"),
                       .init("l2", "Lemmings 2"), .init("l3", "Lemmings 3 Preview")], initials: "P1")
        var pages: [(String, GameFrontEnd.Page)] = [
            ("home", home), ("settings", MobileSettingsArt.groups()),
            ("players", MobileCareerArt.players(profiles, subtitle: "")),
            ("hot-seat", MobileCareerArt.hotSeat(profiles, subtitle: "", roster: .init(host: "default", players: ["guest"]),
                                               policy: .atFirstFail, active: true, hasSaved: true)),
            ("records-empty", MobileCareerArt.recordsPage(records: .init(), profileID: "default", profileName: "Player 1", subtitle: "")),
            ("collections", .init(title: "Collections", rows: [.init("favourites", "Favourites"), .init("recents", "Recently played"),
                                   .init("playlists", "Playlists")], footer: [.init("home", "Back")])),
            ("hints", .init(title: "Watch the walkers", details: ["Make a safe route before the next group arrives."],
                            footer: [.init("back", "Back"), .init("next", "Next hint", primary: true)])),
            ("ready", MobileTurnArt.page(.init(title: "Ready", footer: [.init("library", "Library"), .init("ready", "Ready", primary: true)]),
                                        playerName: "Guest player", role: .next)),
            ("save-failure", .init(title: "Hot Seat was not saved", footer: [.init("retry", "Try again", primary: true)])),
            ("retry", .init(title: "Retry level?", footer: [.init("cancel", "Cancel"), .init("retry", "Retry", primary: true)])),
            ("transport", .init(title: "Game controls", rows: [.init("skills", "Skills"), .init("camera", "Camera"),
                                  .init("forward", "Step forward"), .init("backward", "Step back"), .init("rewind", "Rewind"),
                                  .init("faster", "Faster"), .init("slower", "Slower"), .init("end", "End run")], footer: [.init("back", "Back")])),
            ("transfer", .init(title: "Import files", details: ["Open this address on another device:", "http://192.168.1.12:50000/0123456789abcdef0123456789abcdef"], footer: [.init("back", "Back")])),
        ]
        for group in MobileSettingsGroup.allCases {
            pages.append(("settings-" + group.rawValue, MobileSettingsArt.page(group, settings: .init(), displayAvailable: true)))
        }
        let content = try library.loadLevel(at: 0)
        let summary = MobilePauseSummary(level: content.summary, snapshot: content.session.snapshot,
            activeCount: 0, ticksPerSecond: content.session.ticksPerSecond, speed: 1, assignedSkills: 0,
            supportsRewind: true, usedRewind: false, isReplay: false,
            soundtrack: "Original", track: "A tune", audio: "Music paused")
        pages.append(("pause", MobilePauseArt.page(summary, actions: [.init("resume", "Resume", primary: true), .init("library", "Library")])))
        var captures = 0
        for size in ClassicInterfaceSize.allCases {
            let scale = MobileSettingsArt.interfaceScale(size, width: 1728, television: true)
            for (name, page) in pages {
                let layout = GameFrontEnd.layout(page, width: 1728 / scale, minimumHeight: 960 / scale)
                let context = try context(width: 1728, height: Int(ceil(layout.size.height * scale)))
                context.scaleBy(x: scale, y: scale)
                GameFrontEnd.draw(page, layout: layout, typography: typography, preview: nil, previewSource: nil,
                                  highlighted: layout.targets.first(where: { $0.action.enabled })?.action.id,
                                  portraits: portraits, in: context)
                for (index, target) in layout.targets.enumerated() {
                    guard target.frame.width * scale >= 44, target.frame.height * scale >= 44,
                          CGRect(origin: .zero, size: layout.size).contains(target.frame) else {
                        throw Failure.invalid("Shared TV target outside canvas: \(name)/\(target.action.id)")
                    }
                    for other in layout.targets.dropFirst(index + 1) where target.frame.intersects(other.frame) {
                        throw Failure.invalid("Shared TV targets overlap: \(name)/\(target.action.id)/\(other.action.id)")
                    }
                }
                try png(context, at: output.appendingPathComponent(name + "-" + size.rawValue + ".png"))
                captures += 1
            }
        }
        print("PASS \(captures) shared frontend TV renders and input targets at Standard, Large and Extra Large")
    }
}
