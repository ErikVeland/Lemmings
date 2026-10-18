import CoreGraphics
import Foundation
import ImageIO
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkPause(library: ClassicMobileLibrary, typography: GameMenuTypography, output: URL) throws {
        let content = try library.loadLevel(at: 26)
        let session = content.session
        let preview = MobileBitmapRenderer.image(try session.render(highlight: nil))
        let source = CGRect(x: session.initialCameraOrigin.x, y: 0, width: 320, height: 160)
        var captures: [[String: Any]] = []
        var wordBreaks = Set<String>()
        let states = [("active", 12, 18, false, false), ("no-margin", 12, 8, false, false),
                      ("unreachable", 12, 7, false, false), ("secured", 60, 5, false, false),
                      ("ending", 12, 18, true, false), ("replay", 12, 18, false, true)]
        for (pose, size) in [("narrow", CGSize(width: 320, height: 548)),
                             ("iphone", CGSize(width: 390, height: 763)),
                             ("landscape", CGSize(width: 756, height: 369)),
                             ("narrow-landscape", CGSize(width: 568, height: 300)),
                             ("ipad", CGSize(width: 834, height: 1092)),
                             ("ipad-landscape", CGSize(width: 1112, height: 814)),
                             ("tv", CGSize(width: 1920, height: 1080))] {
            for interface in ClassicInterfaceSize.allCases {
                let scale = MobilePauseArt.interfaceScale(interface, width: size.width, height: size.height, television: pose == "tv")
                let logicalSize = CGSize(width: size.width / scale, height: size.height / scale)
                for (state, saved, active, ending, replay) in states {
                    let info = MobilePauseSummary(level: .init(index: 94, rank: "Lemmings", number: 95, title: content.summary.title, origin: .official, packName: "Lemmings"),
                        snapshot: .init(tick: 510, released: saved == 60 ? 70 : 40, total: 80, saved: saved, required: 60,
                            remainingSeconds: state == "replay" ? nil : 157, releaseRate: 50, isComplete: false,
                            didWin: false, isEndingRun: ending, skills: session.snapshot.skills),
                        activeCount: active, ticksPerSecond: 17, speed: 1, assignedSkills: 8,
                        supportsRewind: true, usedRewind: state == "unreachable", isReplay: replay,
                        soundtrack: state == "replay" ? "Adaptive DJ" : "Original",
                        track: "A long soundtrack title that wraps across the music sleeve",
                        audio: state == "ending" ? "Music off   /   SFX off" : "Music: beat only   /   SFX 90%")
                    let footer: [GameFrontEnd.Action] = replay
                        ? [.init("back", "Back"), .init("resume", "Resume", primary: true)]
                        : [.init("library", "Library"), .init("hint", "Hint"), .init("restart", "Restart level"),
                           pose == "tv" ? .init("controls", "Game controls") : .init("controlsHelp", "Controls help"),
                           .init("settings", "Settings"), .init("resume", "Resume", primary: true)]
                    let page = MobileTurnArt.page(MobilePauseArt.page(info, actions: footer), playerName: replay ? nil : "ERI")
                    let base = GameFrontEnd.layout(page, width: logicalSize.width, minimumHeight: logicalSize.height)
                    guard replay ? page.title == "Replay" : page.title.hasPrefix("Paused"),
                          page.subtitle.contains("95"), page.details.contains(info.level.title),
                          page.details.contains("Lost: \(info.lost)"), page.details.contains(info.track),
                          replay || page.footer.contains(where: { $0.id == "restart" }) else { throw invalidTargets(line: #line) }
                    guard base.details.count == page.details.count,
                          base.details.allSatisfy({ base.board.contains($0) }),
                          base.details.last!.maxY + 8 < base.targets.first!.frame.minY else { throw invalidTargets(line: #line) }
                    let countWidth = max(28, CGFloat(info.supplies.map { $0.value.count }.max() ?? 0) * 12)
                    for (index, stock) in info.supplies.enumerated() {
                        guard typography.width(of: stock.label, face: .small, scale: 1) <= base.details[12 + index].width - countWidth - 4
                        else { throw invalidTargets(line: #line) }
                    }
                    for offset in [CGFloat(0), max(0, base.size.height - logicalSize.height)] {
                        let viewport = CGRect(x: 0, y: offset, width: logicalSize.width, height: logicalSize.height)
                        let layout = MobilePauseArt.pinningFooter(base, viewport: viewport)
                        guard layout.targets.last?.action.id == "resume",
                              layout.targets.filter({ $0.action.primary }).count == 1,
                              footerNavigationIsValid(page, layout: layout),
                              layout.targets.allSatisfy({ viewport.contains($0.frame) && $0.frame.height >= 44 && $0.frame.width >= 44 })
                        else { throw invalidTargets(line: #line) }
                        for (index, target) in layout.targets.enumerated() {
                            // Captions may wrap at word boundaries. A word wider than its button is
                            // broken by the renderer; report it rather than hide it.
                            let captionWidth = target.frame.width - (target.action.primary ? 48 : 24)
                            guard GameTextLayout.height(target.action.title, width: captionWidth) + 8 <= target.frame.height
                            else { throw invalidTargets(line: #line) }
                            if !target.action.title.split(separator: " ").allSatisfy({
                                typography.width(of: String($0), face: .small, scale: 1) <= captionWidth }) {
                                wordBreaks.insert("\(pose)-\(interface.rawValue): \(target.action.title)")
                            }
                            guard layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == target.action.id,
                                  layout.targets.dropFirst(index + 1).allSatisfy({ !$0.frame.intersects(target.frame) }) else { throw invalidTargets(line: #line) }
                        }
                        guard layout.action(at: CGPoint(x: layout.board.minX + 2, y: viewport.midY)) == nil else { throw invalidTargets(line: #line) }
                        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                            bytesPerRow: Int(size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.missingArtwork }
                        context.translateBy(x: 0, y: size.height); context.scaleBy(x: 1, y: -1)
                        context.scaleBy(x: scale, y: scale)
                        context.translateBy(x: 0, y: -offset)
                        GameFrontEnd.draw(page, layout: layout, typography: typography, preview: preview,
                            previewSource: source, in: context)
                        guard let image = context.makeImage() else { throw Failure.missingArtwork }
                        let file = "\(pose)-\(interface.rawValue)-\(state)-\(offset == 0 ? "top" : "bottom").png"
                        guard let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(file) as CFURL,
                            "public.png" as CFString, 1, nil) else { throw Failure.missingArtwork }
                        CGImageDestinationAddImage(destination, image, nil)
                        guard CGImageDestinationFinalize(destination) else { throw Failure.missingArtwork }
                        captures.append(["file": file, "state": state, "pose": pose, "scrollOffset": offset,
                            "contentHeight": base.size.height, "targetCount": layout.targets.count])
                    }
                }
            }
        }
        try JSONSerialization.data(withJSONObject: ["captures": captures, "audio": "muted", "windows": "none",
            "targetsValidated": true, "pinnedResume": true, "wordBreaks": wordBreaks.sorted()], options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("pause-report.json"))
        for item in wordBreaks.sorted() { print("WARN: word broken inside button: \(item)") }
        print("PASS: \(captures.count) pause renders, scrolling and pinned targets; six rescue states, phone and iPad.")
        for width: CGFloat in [280, 390, 600, 960] {
            var confirmation = GameFrontEnd.Page(title: "Restart level?", details: ["Journey 34", "The Crankshaft"],
                footer: [.init("cancel", "Cancel"), .init("restart", "Restart level", primary: true)], footerColumns: 1)
            confirmation.detailTitles = [1]
            let confirmationLayout = GameFrontEnd.layout(confirmation, width: width, minimumHeight: 300)
            guard confirmationLayout.targets.count == 2,
                  confirmationLayout.targets.last?.action.id == "restart",
                  confirmationLayout.targets.allSatisfy({
                      typography.width(of: $0.action.title, face: .small, scale: 1)
                          <= $0.frame.width - ($0.action.primary ? 48 : 24)
                          && confirmationLayout.action(at: CGPoint(x: $0.frame.midX, y: $0.frame.midY)) == $0.action.id
                  }) else { throw invalidTargets(line: #line) }
            guard let confirmationContext = CGContext(data: nil, width: Int(confirmationLayout.size.width),
                height: Int(confirmationLayout.size.height), bitsPerComponent: 8,
                bytesPerRow: Int(confirmationLayout.size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.missingArtwork }
            confirmationContext.translateBy(x: 0, y: confirmationLayout.size.height); confirmationContext.scaleBy(x: 1, y: -1)
            GameFrontEnd.draw(confirmation, layout: confirmationLayout, typography: typography, in: confirmationContext)
            guard let confirmationImage = confirmationContext.makeImage(), let confirmationDestination = CGImageDestinationCreateWithURL(
                output.appendingPathComponent("restart-confirm-\(Int(width)).png") as CFURL, "public.png" as CFString, 1, nil)
            else { throw Failure.missingArtwork }
            CGImageDestinationAddImage(confirmationDestination, confirmationImage, nil)
            guard CGImageDestinationFinalize(confirmationDestination) else { throw Failure.missingArtwork }
            let level = MobileLevelSummary(index: 33, rank: "Journey", number: 34,
                title: "The Crankshaft and a long level name that must retain its complete ending")
            let size = MobileReplayTitleArt.size(level: level, width: width)
            guard size.height >= 68,
                  GameTextLayout.lines(level.title, width: width - 24).joined(separator: " ") == level.title.uppercased()
            else { throw invalidTargets(line: #line) }
            guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                bytesPerRow: Int(size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.missingArtwork }
            context.translateBy(x: 0, y: size.height); context.scaleBy(x: 1, y: -1)
            MobileReplayTitleArt.draw(level: level, in: CGRect(origin: .zero, size: size), typography: typography, context: context)
            guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(
                output.appendingPathComponent("replay-title-\(Int(width)).png") as CFURL, "public.png" as CFString, 1, nil)
            else { throw Failure.missingArtwork }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { throw Failure.missingArtwork }
        }
        print("PASS: replay number and full wrapped title at four widths.")
    }
}
