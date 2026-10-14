import CoreGraphics
import Foundation
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import LemmingsTVCore
import NxlvKit

extension TVExperienceAudit {
    @MainActor static func checkSharedFrontend(typography: GameMenuTypography, portraits: GamePortraitArt?,
                                              library: ClassicMobileLibrary, root: URL) throws {
        let output = root.appendingPathComponent(".build/tv-experience/shared-frontend")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        typealias Action = GameFrontEnd.Action
        var profiles = MobileProfiles()
        _ = profiles.add(name: "Guest player", id: "guest")
        var players = MobileCareerArt.players(profiles, subtitle: "", canDelete: true)
        players.rows.append(.init("cloudSaves", "Cloud saves"))
        guard players.rows.contains(where: { $0.id == "playerRename" && $0.enabled }),
              !players.footer.contains(where: { $0.id == "playerRename" }) else {
            throw Failure.invalid("Profile editing must be reachable in the player list")
        }
        var roster = MobileHotSeatRoster(host: "default", players: ["guest"])
        roster.toggle("guest")
        let deselected = MobileCareerArt.hotSeat(profiles, subtitle: "", roster: roster,
            policy: .everyLevel, active: false, hasSaved: false)
        guard deselected.rows.contains(where: { $0.id == "seat.guest" && !$0.selected && $0.enabled }),
              deselected.rows.contains(where: { $0.id == "seat.default" && $0.selected && !$0.enabled }),
              deselected.footer.contains(where: { $0.id == "seatStart" && !$0.enabled }) else {
            throw Failure.invalid("Guest deselection and the locked host must match their targets")
        }
        let home = MobileHomeArt.page(resume: [.init("resume", "Resume level - Player 1")],
            journey: .init("journey", "Journey  29/295 solved"),
            families: [.init("classic", "Classic Lemmings"), .init("ohNo", "Oh No! More Lemmings"),
                       .init("holiday", "Holiday Lemmings"), .init("ohYes", "Oh Yes! More Lemmings"),
                       .init("fan", "Fan Lemmings"), .init("neolemmix", "NeoLemmix Preview"),
                       .init("l2", "Lemmings 2"), .init("l3", "Lemmings 3 Preview")], initials: "P1")
        var pages: [(String, GameFrontEnd.Page)] = [
            ("home", home), ("settings", MobileSettingsArt.groups()),
            ("players", players),
            ("edit-player", MobileCareerArt.players(profiles, subtitle: "", draft: "LEM", portrait: 6)),
            ("new-player", MobileCareerArt.players(profiles, subtitle: "", draft: "", creating: true, portrait: 1)),
            ("delete-player", MobileCareerArt.players(profiles, subtitle: "", canDelete: true, confirmingDelete: true)),
            ("hot-seat-deselected", deselected),
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
                                  .init("faster", "Faster"), .init("slower", "Slower"), .init("end", "End run")],
                                  footer: [.init("back", "Back"), .init("resume", "Resume", primary: true)])),
            ("transfer", .init(title: "Import files", details: ["Open this address on another device:", "http://192.168.1.12:50000/0123456789abcdef0123456789abcdef"], footer: [.init("back", "Back")])),
        ]
        pages.append(("controller-mappings", MobileSettingsArt.controllerMappings(.init(), television: true)))
        var personalSettings = MobileSettings()
        personalSettings.classic.controllerSwapSticks = true
        personalSettings.classic.controllerTapSpeed = false
        personalSettings.classic.reduceMotion = true
        personalSettings.classic.reduceFlashes = true
        personalSettings.classic.showSongInfo = false
        personalSettings.djShuffleScope = .allTracks
        pages.append(("player-controller", MobileSettingsArt.page(.controller, settings: personalSettings)))
        pages.append(("player-accessibility", MobileSettingsArt.page(.accessibility, settings: personalSettings)))
        pages.append(("dj-shuffle-all", MobileSettingsArt.page(.audio, settings: personalSettings)))
        pages.append(("controller-help", .init(title: "Controls", details: TVControllerBindings.help.components(separatedBy: "\n"),
            footer: [.init("back", "Back")])))
        pages.append(("controller-triggers", .init(title: "Controller", rows: [
            .init("setting.tvTriggerFeedback", "Adaptive triggers", selected: true),
            .init("setting.tvAim", "Aim sensitivity: 100%"),
            .init("setting.tvDeadZone", "Stick dead zone: 15%")], footer: [.init("back", "Back")])))
        let nativeBudget = FXPresentationBudget(cpuQuality: .full, gpuQuality: .full)
        let pressuredBudget = FXPresentationBudget(cpuQuality: .full, gpuQuality: .balanced)
        guard nativeBudget.televisionPlayfieldScale(nativeScale: 2) == 2,
              pressuredBudget.televisionPlayfieldScale(nativeScale: 2) == 1 else {
            throw Failure.invalid("TV pressure must reduce CRT pixel cost without changing menu scale")
        }
        for group in MobileSettingsGroup.allCases {
            pages.append(("settings-" + group.rawValue, MobileSettingsArt.page(group, settings: .init(), displayAvailable: true)))
        }
        let cloud = CloudSyncArt.page(status: "Cloud saves", providers: "", enabled: false)
        pages.append(("save-backup", TVSharedMenuArt.cloud(cloud, restoring: false, hasCode: false, enteringCode: false, busy: false)))
        pages.append(("save-restore", TVSharedMenuArt.cloud(cloud, restoring: true, hasCode: false, enteringCode: false, busy: false)))
        let content = try library.loadLevel(at: 0)
        let summary = MobilePauseSummary(level: content.summary, snapshot: content.session.snapshot,
            activeCount: 0, ticksPerSecond: content.session.ticksPerSecond, speed: 1, assignedSkills: 0,
            supportsRewind: true, usedRewind: false, isReplay: false,
            soundtrack: "Original", track: "A tune", audio: "Music paused")
        pages.append(("pause", MobilePauseArt.page(summary, actions: [.init("resume", "Resume", primary: true), .init("library", "Library")])))
        var captures = 0
        for size in ClassicInterfaceSize.allCases {
            for (name, page) in pages {
                let scale = page.pause != nil
                    ? MobilePauseArt.interfaceScale(size, width: 1728, height: 960, television: true)
                    : MobileSettingsArt.interfaceScale(size, width: 1728, television: true)
                guard scale == floor(scale) else { throw Failure.invalid("Fractional TV artwork scale") }
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
