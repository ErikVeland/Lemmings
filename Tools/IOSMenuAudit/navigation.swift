import Foundation
import CoreGraphics
import ImageIO
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkNavigation(typography: GameMenuTypography, output: URL) throws {
        typealias Action = GameFrontEnd.Action
        let families: [Action] = [.init("classic", "Classic"), .init("l2", "Lemmings 2", gameLogo: .lemmings2),
            .init("l3", "Lemmings 3", gameLogo: .lemmings3)]
        var pages: [(String, GameFrontEnd.Page)] = [
            ("home", MobileHomeArt.page(journey: .init("journey", "Journey map"), families: families, initials: "LEM")),
            ("home-saves", MobileHomeArt.page(resume: [.init("resume", "Resume level")], journey: .init("journey", "Resume journey"), families: families, initials: "LEM v PAL")),
            ("welcome", MobileInformationArt.effectsWelcome()),
            ("whats-new", MobileInformationArt.whatsNew(version: "2.0")),
            ("consent", MobileInformationArt.telemetryConsent()),
            ("pause-choice", MobileSettingsArt.skillSelectionPauseChoice()),
            ("settings", MobileSettingsArt.groups()),
            ("game-settings", MobileSettingsArt.groups(inGame: true)),
            ("mapping", MobileSettingsArt.controllerMappings(.init())),
            ("tv-mapping", MobileSettingsArt.controllerMappings(.init(), television: true)),
            ("save-error", GameRecoveryArt.page(title: "Run was not saved")),
            ("handover-error", GameRecoveryArt.page(title: "Hot Seat was not saved")),
            ("migration-error", GameRecoveryArt.migrationFailure("Saved data could not be opened")),
            ("migration-long-error", GameRecoveryArt.migrationFailure(String(repeating: "Saved data could not be opened. ", count: 24))),
            ("records-recovery", GameRecoveryArt.recordsReset("Records could not be read.")),
            ("insights-token-empty", MobileInformationArt.insightsToken(length: 0)),
            ("insights-token", MobileInformationArt.insightsToken(length: 12)),
            ("insights-clear", MobileInformationArt.insightsClear()),
        ]
        guard MobileInformationArt.effectsWelcome().backAction?.id == "welcomeOriginal",
              MobileInformationArt.telemetryConsent().backAction?.id == "telemetryNo",
              MobileInformationArt.whatsNew(version: "2.0").backAction?.id == "welcomeContinue",
              MobileSettingsArt.skillSelectionPauseChoice().backAction?.id == "1",
              !MobileSettingsArt.groups(inGame: true).rows.contains(where: { $0.id == "data" }) else { throw invalidTargets(line: #line) }
        for group in MobileSettingsGroup.allCases {
            for inGame in [false, true] {
                let page = MobileSettingsArt.page(group, settings: .init(), sharingAvailable: false, inGame: inGame)
                if inGame, page.rows.contains(where: { $0.id == "cloudSaves" }) { throw invalidTargets(line: #line) }
                pages.append(("settings-\(group.rawValue)-\(inGame)", page))
            }
        }
        pages += try careerPages()
        for busy in [false, true] {
            for mode in ["off", "on", "code", "draft", "draft-ready"] {
                let page = CloudSyncArt.page(status: busy ? "Syncing" : "Offline", providers: "Cloud",
                    enabled: mode != "off", busy: busy, code: mode == "code" ? "ABCD1234EFGH" : nil,
                    draft: mode.hasPrefix("draft") ? (mode == "draft-ready" ? "ABCD1234EFGH" : "") : nil)
                pages.append(("cloud-\(mode)-\(busy)", page))
                pages.append(("tv-cloud-\(mode)-\(busy)", TVSharedMenuArt.cloud(page, restoring: false,
                    hasCode: mode == "code", enteringCode: mode.hasPrefix("draft"), busy: busy)))
            }
        }
        pages.append(("tv-restore-confirm", TVSharedMenuArt.cloud(CloudSyncArt.page(status: "", providers: "", enabled: true),
            restoring: true, hasCode: false, enteringCode: false, busy: false)))
        for loading in [false, true] {
            pages.append(("insights-\(loading)", MobileInformationArt.insights(counts: [:], shared: false, days: 30,
                sharingAvailable: false, loading: loading)))
        }
        for game in ["Classic", "Lemmings 2", "Lemmings 3"] {
            for won in [false, true] {
                var result = GameFrontEnd.Page(title: won ? "Level complete" : "Try again", subtitle: game,
                    details: ["Saved \(won ? 10 : 0)/10   Goal 5"], footer: [
                        .init("retry", won ? "NEXT LEVEL" : "RETRY", primary: true), .init("back", "BACK"), .init("menu", "MENU")], preview: true)
                result.result = true
                pages.append(("\(game)-result-\(won)", result))
            }
        }
        let noBackNeeded: Set<String> = ["home", "home-saves", "migration-error", "migration-long-error"]
        let devices: [(String, CGSize, Bool)] = [("phone-narrow", .init(width: 320, height: 548), false),
            ("phone", .init(width: 390, height: 763), false), ("phone-landscape", .init(width: 568, height: 300), false),
            ("tablet", .init(width: 1194, height: 834), false), ("mac", .init(width: 1120, height: 720), false),
            ("tv", .init(width: 1920, height: 1080), true)]
        var evidence: [[String: Any]] = []
        var renders = 0
        for (name, page) in pages {
            let actions = page.rows + page.footer
            guard actions.contains(where: \.enabled), Set(actions.map(\.id)).count == actions.count,
                  noBackNeeded.contains(name) || page.backAction != nil else { throw invalidTargets(line: #line) }
            for (device, size, television) in devices {
                for setting in ClassicInterfaceSize.allCases {
                    let scale = MobileSettingsArt.interfaceScale(setting, width: size.width, television: television)
                    let layout = GameFrontEnd.layout(page, width: size.width / scale, minimumHeight: size.height / scale)
                    let canvas = CGRect(origin: .zero, size: layout.size)
                    guard (page.home || footerNavigationIsValid(page, layout: layout)), layout.targets.count == actions.count else {
                        FileHandle.standardError.write(Data("Navigation: \(name), \(device), \(setting)\n".utf8))
                        throw invalidTargets(line: #line)
                    }
                    for (index, target) in layout.targets.enumerated() {
                        guard canvas.contains(target.frame), target.frame.width * scale >= 44, target.frame.height * scale >= 44,
                              layout.action(at: .init(x: target.frame.midX, y: target.frame.midY)) == (target.action.enabled ? target.action.id : nil),
                              layout.targets.dropFirst(index + 1).allSatisfy({ !$0.frame.intersects(target.frame) }) else {
                            FileHandle.standardError.write(Data("Target: \(name), \(device), \(setting), \(target.action.id), \(target.frame)\n".utf8))
                            throw invalidTargets(line: #line)
                        }
                    }
                    let scrolls = layout.size.height * scale > size.height
                    if setting == .standard {
                        let context = try makeNavigationContext(layout.size)
                        GameFrontEnd.draw(page, layout: layout, typography: typography,
                            highlighted: page.backAction?.id ?? actions.first(where: \.enabled)?.id, in: context)
                        guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(
                            output.appendingPathComponent("\(device)-\(name).png") as CFURL, "public.png" as CFString, 1, nil) else { throw Failure.missingArtwork }
                        CGImageDestinationAddImage(destination, image, nil)
                        guard CGImageDestinationFinalize(destination) else { throw Failure.missingArtwork }
                        renders += 1
                    }
                    evidence.append(["page": name, "device": device, "scale": scale, "scrolls": scrolls,
                        "enabledActions": actions.filter(\.enabled).count, "backAction": page.backAction?.id ?? "root-or-continue"])
                }
            }
        }
        let report: [String: Any] = ["pages": pages.count, "layoutChecks": evidence.count, "renders": renders,
            "windows": "none", "audio": "muted", "physicalTouchRemoteAndVoiceOver": "pending", "checks": evidence]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("navigation.json"), options: .atomic)
        print("PASS \(pages.count) navigation states, \(evidence.count) layouts and \(renders) bitmap renders")
    }

    private static func makeNavigationContext(_ size: CGSize) throws -> CGContext {
        guard let context = CGContext(data: nil, width: Int(ceil(size.width)), height: Int(ceil(size.height)), bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.missingArtwork }
        context.translateBy(x: 0, y: size.height); context.scaleBy(x: 1, y: -1)
        return context
    }
}
