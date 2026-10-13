import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore

extension MenuAudit {
    @MainActor static func checkHotSeat(typography: GameMenuTypography, portraits: GamePortraitArt?, output: URL) throws {
        guard let portraits, (0..<8).allSatisfy({ portraits.image($0) != nil }) else { throw Failure.missingArtwork }
        let solo = MobileProfiles()
        var profiles = solo
        guard let guest = profiles.add(name: "AB", id: "guest") else { throw Failure.invalidTargets }
        profiles.setPortrait(guest, to: 3)
        var roster = MobileHotSeatRoster(host: profiles.activeID)
        let notReady = MobileCareerArt.hotSeat(profiles, subtitle: "", roster: roster, policy: .everyLevel, active: false, hasSaved: false)
        guard notReady.footer.first(where: { $0.id == "seatStart" })?.enabled == false else { throw Failure.invalidTargets }
        roster.toggle(guest)
        var store = MobileHotSeatStore()
        guard var seat = store.start(roster: roster), seat.host == profiles.activeID, seat.turn == profiles.activeID,
              seat.players == [profiles.activeID, guest] else { throw Failure.invalidTargets }
        seat.pass(to: guest); store.update(seat)
        let storage = MobileStorage(directory: output.appendingPathComponent("session-check"))
        try store.save(to: storage)
        let reopened = MobileHotSeatStore.load(from: storage)
        guard reopened.current == seat,
              reopened.current?.choices(didWin: false).first?.player == profiles.activeID else { throw Failure.invalidTargets }
        try FileManager.default.removeItem(at: storage.directory)
        var full = profiles
        for index in 2..<MobileProfiles.maximum { _ = full.add(name: "P\(index)", id: "player-\(index)") }
        let pages: [(String, GameFrontEnd.Page)] = [
            ("profiles-first-player", MobileCareerArt.players(solo, subtitle: "")),
            ("profiles-two-players", MobileCareerArt.players(profiles, subtitle: "")),
            ("profiles-active-session", MobileCareerArt.players(profiles, subtitle: "", hotSeatTurn: "AB")),
            ("profiles-full", MobileCareerArt.players(full, subtitle: "")),
            ("profile-guest-initials", MobileCareerArt.players(profiles, subtitle: "", draft: "", creating: true, portrait: 3)),
            ("setup-first-player", MobileCareerArt.hotSeat(solo, subtitle: "", roster: .init(host: solo.activeID), policy: .everyLevel, active: false, hasSaved: false)),
            ("setup-one-selected", notReady),
            ("setup-ready", MobileCareerArt.hotSeat(profiles, subtitle: "", roster: roster, policy: .everyLevel, active: false, hasSaved: false)),
            ("setup-active", MobileCareerArt.hotSeat(profiles, subtitle: "", roster: roster, policy: .atFirstFail, active: true, hasSaved: true)),
            ("setup-restart", MobileCareerArt.hotSeat(profiles, subtitle: "", roster: roster, policy: .atFirstFail, active: true, hasSaved: true, confirmingRestart: true)),
            ("setup-full", MobileCareerArt.hotSeat(full, subtitle: "", roster: .init(host: full.activeID, players: full.players.map(\.id)), policy: .everyLevel, active: true, hasSaved: true))
        ]
        var renders = 0
        for (device, size) in [("ipad-portrait", CGSize(width: 834, height: 1092)),
                               ("ipad-landscape", CGSize(width: 1112, height: 814)),
                               ("iphone-portrait", CGSize(width: 390, height: 763)),
                               ("iphone-landscape", CGSize(width: 756, height: 369)),
                               ("iphone-narrow", CGSize(width: 320, height: 548))] {
            for (name, page) in pages {
                let layout = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
                guard Set(layout.targets.map { $0.action.id }).count == layout.targets.count,
                      layout.targets.filter({ $0.action.primary && $0.action.enabled }).count <= 1 else { throw Failure.invalidTargets }
                for target in layout.targets {
                    guard target.frame.width >= 44, target.frame.height >= 44,
                          CGRect(origin: .zero, size: layout.size).contains(target.frame),
                          layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == (target.action.enabled ? target.action.id : nil)
                    else { throw Failure.invalidTargets }
                }
                for (index, target) in layout.targets.enumerated() {
                    guard layout.targets.dropFirst(index + 1).allSatisfy({ !target.frame.intersects($0.frame) }) else { throw Failure.invalidTargets }
                }
                if name.hasPrefix("profiles-") {
                    guard let target = layout.targets.first(where: { $0.action.id == "hotSeat" }),
                          target.action.enabled,
                          layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == "hotSeat" else { throw Failure.invalidTargets }
                }
                if name == "setup-ready" {
                    guard layout.targets.first(where: { $0.action.id == "seatStart" })?.action.primary == true,
                          layout.targets.first(where: { $0.action.id == "seat." + guest })?.action.selected == true else { throw Failure.invalidTargets }
                }
                let context = try bitmapContext(size: layout.size)
                GameFrontEnd.draw(page, layout: layout, typography: typography, portraits: portraits, in: context)
                try save(context: context, to: output.appendingPathComponent(device + "-" + name + ".png"))
                renders += 1
            }
        }
        print("PASS: \(renders) Hot Seat/profile renders and input targets, first-session start and retained roster/turn after saving.")
    }
}
