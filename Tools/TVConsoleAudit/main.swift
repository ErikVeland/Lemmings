import CoreGraphics
import Foundation
import ImageIO
import LemmingsGameArt
import LemmingsMobileCore
import LemmingsTVCore
import NxlvKit

@main struct TVConsoleAudit {
    enum Failure: Error { case check(String) }
    static func check(_ condition: @autoclosure () -> Bool, _ name: String) throws {
        if !condition() { throw Failure.check(name) }
    }
    @MainActor static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = root.appendingPathComponent(".build/tv-console/renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        guard let original = GameMenuTypography(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings")) else {
            throw Failure.check("Missing bitmap artwork")
        }
        let typography = GameMenuTypography(interface: original.interface,
            homeLogos: GameHomeLogoArt(resources: root.appendingPathComponent(".build/tv-console/runtime/resources")))
        let families: [GameFrontEnd.Action] = [
            .init("family.classic", "Classic Lemmings  120/120"), .init("family.ohNo", "Oh No! More Lemmings  100/100"),
            .init("family.holiday", "Holiday Lemmings  64/64"), .init("family.ohYes", "Oh Yes! More Lemmings  60/60"),
            .init("family.fan", "Fan-made Lemmings  10/1000"), .init("family.neo", "NeoLemmix  25/1000"),
            .init("l2", "Lemmings 2", gameLogo: .lemmings2), .init("l3", "All New World of Lemmings", gameLogo: .lemmings3)]
        let viewports: [(String, CGSize)] = [("1080-safe", .init(width: 1728, height: 972)),
            ("1080", .init(width: 1920, height: 1080)), ("4k-safe", .init(width: 3456, height: 1944))]
        var captures = 0, settingsPages = 0
        for (name, viewport) in viewports {
            for size in ClassicInterfaceSize.allCases {
                let preferred = MobileSettingsArt.interfaceScale(size, width: viewport.width, television: true)
                for saved in 0...3 {
                    for disabled in [false, true] {
                        let libraries = families.map { action in var action = action; action.enabled = !disabled; return action }
                        let resume = (0..<saved).map { GameFrontEnd.Action("resume.\($0)", ["Resume journey - ABC", "Resume level - ABC", "Resume playlist  12/120"][$0]) }
                        let page = TVMenuPresentation.homePage(MobileHomeArt.page(resume: resume, journey: .init("journey", "Journey map  25/120 solved"), families: libraries,
                            initials: saved == 3 ? "ABC v DEF v GHI v JKL" : "LEM", subtitle: "Version 2.0 (2)\n15 October 2026, 2:30 pm\nCatalogue ready"))
                        let scale = TVMenuPresentation.homeScale(preferred, page: page, width: viewport.width, height: viewport.height)
                        let layout = TVMenuPresentation.homeLayout(page, width: viewport.width / scale, height: viewport.height / scale)
                        let label = "\(name)-home-\(size.rawValue)-saved\(saved)-disabled\(disabled)"
                        try validate(page, layout: layout, viewport: viewport, scale: scale, name: label)
                        try render(page, layout: layout, scale: scale, viewport: viewport, typography: typography, output: output, name: label)
                        captures += 1
                    }
                }
                var settings = MobileSettings()
                settings.classic.interfaceSize = size
                var sources = [MobileSettingsArt.groups(television: true)]
                for group in MobileSettingsGroup.allCases where group != .deskClock {
                    var page = MobileSettingsArt.page(group, settings: settings, displayAvailable: true)
                    page.televisionGrid = true
                    if group == .controller {
                        page.rows += [.init("setting.tvAim", "Aim sensitivity: 200%"), .init("setting.tvDeadZone", "Stick dead zone: 35%"),
                            .init("setting.tvTriggerFeedback", "Adaptive triggers", selected: true)]
                    }
                    sources.append(page)
                }
                var mappings = MobileSettingsArt.controllerMappings(settings, television: true)
                mappings.televisionGrid = true
                mappings.rows += mappings.footer.filter { !$0.isBackNavigation }
                mappings.footer.removeAll { !$0.isBackNavigation }
                sources.append(mappings)
                var soundtrack = GameFrontEnd.Page(title: "Soundtrack", subtitle: "8/12", rows: (0..<12).map {
                    .init("lib.\($0)", "Original soundtrack \($0)  Included", enabled: $0 >= 8, selected: $0 < 8)
                }, footer: [.init("settingsGroup.audio", "Back")])
                soundtrack.televisionGrid = true
                sources.append(soundtrack)
                for (sourceIndex, original) in sources.enumerated() {
                    let source = MobileTurnArt.page(original, playerName: "ABC")
                    let scale = TVMenuPresentation.settingsScale(preferred, page: source, width: viewport.width, height: viewport.height)
                    var index = 0, seen: [String] = []
                    while true {
                        let page = TVMenuPresentation.settingsPage(source, index: index, width: viewport.width / scale, height: viewport.height / scale)
                        let layout = GameFrontEnd.layout(page, width: viewport.width / scale, minimumHeight: viewport.height / scale)
                        let label = "\(name)-settings-\(sourceIndex)-\(size.rawValue)-page\(index)"
                        try validate(page, layout: layout, viewport: viewport, scale: scale, name: label)
                        try check(page.backAction?.id == source.backAction?.id, label + " retains Back")
                        seen += page.rows.map(\.id)
                        try render(page, layout: layout, scale: scale, viewport: viewport, typography: typography, output: output, name: label)
                        captures += 1; settingsPages += 1
                        if !page.footer.contains(where: { $0.id == TVMenuPresentation.nextID && $0.enabled }) { break }
                        index += 1
                        try check(index < 30, "Bounded settings navigation")
                    }
                    try check(seen == source.rows.map(\.id), "All settings are reachable exactly once")
                }
            }
        }
        print("PASS \(captures) fixed TV renders, including \(settingsPages) settings pages; all actions visible, captions complete, disabled states and hit targets checked")
    }
    static func validate(_ page: GameFrontEnd.Page, layout: GameFrontEnd.Layout, viewport: CGSize, scale: CGFloat, name: String) throws {
        try check(layout.size.height * scale <= viewport.height + 0.01, name + " fits screen: \(layout.size.height * scale) > \(viewport.height)")
        let visible = CGRect(origin: .zero, size: layout.size)
        try check(visible.contains(layout.heading), name + " title")
        if !page.subtitle.isEmpty { try check(visible.contains(layout.subtitle), name + " subtitle") }
        for (index, target) in layout.targets.enumerated() {
            try check(visible.contains(target.frame) && layout.board.contains(target.frame), name + " contains " + target.action.id)
            try check(target.frame.width * scale >= 44 && target.frame.height * scale >= 44, name + " target size")
            try check(!layout.targets.dropFirst(index + 1).contains { target.frame.intersects($0.frame) }, name + " target overlap")
            try check(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == (target.action.enabled ? target.action.id : nil), name + " hit test")
            if target.action.gameLogo == nil && !["settings", "whatsNew"].contains(target.action.id) {
                let height = GameTextLayout.height(target.action.title, width: target.frame.width - (target.action.primary ? 48 : 24))
                try check(height <= target.frame.height - 4, name + " complete caption " + target.action.id)
            }
        }
    }
    static func render(_ page: GameFrontEnd.Page, layout: GameFrontEnd.Layout, scale: CGFloat, viewport: CGSize,
                       typography: GameMenuTypography, output: URL, name: String) throws {
        guard let context = CGContext(data: nil, width: Int(viewport.width), height: Int(viewport.height), bitsPerComponent: 8,
            bytesPerRow: Int(viewport.width) * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.check("Bitmap") }
        context.translateBy(x: 0, y: viewport.height); context.scaleBy(x: scale, y: -scale)
        GameFrontEnd.draw(page, layout: layout, typography: typography,
            highlighted: page.rows.first(where: \.enabled)?.id, in: context)
        guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(name + ".png") as CFURL,
            "public.png" as CFString, 1, nil) else { throw Failure.check("PNG") }
        CGImageDestinationAddImage(destination, image, nil)
        try check(CGImageDestinationFinalize(destination), "PNG export")
    }
}
