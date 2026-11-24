import CoreGraphics
import Foundation
import ImageIO
import LemmingsAppCore
import LemmingsGameArt

extension MenuAudit {
    @MainActor static func checkLevelLoading(typography: GameMenuTypography, output: URL) throws {
        let page = GameFrontEnd.levelLoading("Just Dig!")
        guard page.previewAction == nil, page.backAction?.id == "back" else { throw invalidTargets(line: #line) }
        for size in [CGSize(width: 375, height: 667), CGSize(width: 1080, height: 810),
                     CGSize(width: 810, height: 1080), CGSize(width: 495, height: 720),
                     CGSize(width: 720, height: 495), CGSize(width: 1920, height: 1080)] {
            for headerNavigation in [false, true] {
                var displayed = page
                if headerNavigation { displayed.footer.removeAll() }
                let layout = GameFrontEnd.layout(displayed, width: size.width, minimumHeight: size.height)
                guard layout.targets.map(\.action.id) == (headerNavigation ? [] : ["back"]),
                      layout.action(at: .init(x: layout.heading.midX, y: layout.heading.midY)) == nil,
                      layout.action(at: .init(x: layout.subtitle.midX, y: layout.subtitle.midY)) == nil
                else { throw invalidTargets(line: #line) }
                for target in layout.targets {
                    guard target.frame.width >= 44, target.frame.height >= 44,
                          layout.action(at: .init(x: target.frame.midX, y: target.frame.midY)) == "back"
                    else { throw invalidTargets(line: #line) }
                }
                let context = try bitmapContext(size: layout.size)
                GameFrontEnd.draw(displayed, layout: layout, typography: typography, in: context)
                try save(context: context, to: output.appendingPathComponent(
                    "loading-\(Int(size.width))-\(Int(size.height))-header-\(headerNavigation).png"))
            }
        }
        print("PASS loading pages expose cancellation only; loading text has no input target")
    }

    @MainActor static func checkFirstPlayer(typography: GameMenuTypography, portraits: GamePortraitArt?, output: URL) throws {
        guard let portraits, portraits.image(2) != nil else { throw Failure.missingArtwork }
        let devices = [("phone", CGSize(width: 320, height: 568)), ("ipad", CGSize(width: 768, height: 1024)),
                       ("duo", CGSize(width: 495, height: 720)), ("tv", CGSize(width: 960, height: 540))]
        for (device, size) in devices {
            for (state, initials, total, busy) in [("empty", "", nil, false), ("ready", "ABC", 123456, false),
                                                   ("offline", "AB", nil, false), ("loading", "X", 123456, true)] {
                let page = MobileCareerArt.firstPlayer(initials: initials, portrait: 2,
                    status: busy ? "Loading..." : "", busy: busy)
                let layout = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
                guard page.backAction == nil, layout.targets.map(\.action.id) == ["playerPortrait", "nameField", "firstPlay"],
                      // Identity comes before community: the worldwide total belongs to the consent step.
                      !page.subtitle.contains("123,456"), !page.subtitle.contains("—"), total != -1 else { throw invalidTargets(line: #line) }
                for target in layout.targets {
                    let enabled = !busy && (target.action.id != "firstPlay" || !initials.isEmpty)
                    guard target.action.enabled == enabled, target.frame.height >= 44, target.frame.width >= 44,
                          CGRect(origin: .zero, size: size).contains(target.frame),
                          layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == (enabled ? target.action.id : nil)
                    else { throw invalidTargets(line: #line) }
                }
                let context = try bitmapContext(size: layout.size)
                GameFrontEnd.draw(page, layout: layout, typography: typography, portraits: portraits, in: context)
                try save(context: context, to: output.appendingPathComponent("first-player-\(device)-\(state).png"))
            }
        }
        print("PASS first player renders and input targets on phone, iPad, Duo and TV")
    }

    @MainActor static func checkStartup(output: URL) throws {
        let path = URL(fileURLWithPath: "Apps/UltimateLemmingsIOS/Assets.xcassets/StartupLogo.imageset/startup-logo.png")
        guard let source = CGImageSourceCreateWithURL(path as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw Failure.missingArtwork }
        for size in [CGSize(width: 950, height: 667), CGSize(width: 495, height: 720),
                     CGSize(width: 720, height: 495), CGSize(width: 320, height: 180)] {
            let bounds = CGRect(origin: .zero, size: size)
            let layout = GameStartupArt.layout(in: bounds)
            let width = min(640, size.width - 48, (size.height - 100) * 1440 / 380)
            let height = width * 380 / 1440
            guard abs(layout.logo.midX - bounds.midX) < 0.01,
                  abs(layout.logo.midY - (bounds.midY - 28)) < 0.01,
                  abs(layout.logo.width - width) < 0.01,
                  abs(layout.logo.height - height) < 0.01,
                  bounds.contains(layout.logo), bounds.contains(layout.hourglass) else { throw invalidTargets(line: #line) }
            let context = try bitmapContext(size: size)
            context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(bounds)
            GameStoneArt.drawImage(image, in: layout.logo, context: context)
            GameStartupArt.drawHourglass(in: layout.hourglass, context: context)
            try save(context: context, to: output.appendingPathComponent("startup-\(Int(size.width))-\(Int(size.height)).png"))
        }
        print("PASS full-display startup logo and hourglass geometry")
    }
}
