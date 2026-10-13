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
        let states = [("active", 12, 18, false, false), ("no-margin", 12, 8, false, false),
                      ("unreachable", 12, 7, false, false), ("secured", 60, 5, false, false),
                      ("ending", 12, 18, true, false), ("replay", 12, 18, false, true)]
        for (pose, size) in [("narrow", CGSize(width: 320, height: 548)),
                             ("iphone", CGSize(width: 390, height: 763)),
                             ("landscape", CGSize(width: 756, height: 369)),
                             ("narrow-landscape", CGSize(width: 568, height: 300)),
                             ("ipad", CGSize(width: 834, height: 1092)),
                             ("ipad-landscape", CGSize(width: 1112, height: 814))] {
            for interface in ClassicInterfaceSize.allCases {
                let scale = MobileSettingsArt.interfaceScale(interface, width: size.width)
                let logicalSize = CGSize(width: size.width / scale, height: size.height / scale)
                for (state, saved, active, ending, replay) in states {
                    let info = MobilePauseSummary(level: .init(index: 94, rank: "Lemmings", number: 95, title: content.summary.title),
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
                        : [.init("library", "Library"), .init("hint", "Hint"), .init("controls", "Controls"), .init("resume", "Resume", primary: true)]
                    let page = MobileTurnArt.page(MobilePauseArt.page(info, actions: footer), playerName: replay ? nil : "ERI")
                    let base = GameFrontEnd.layout(page, width: logicalSize.width, minimumHeight: logicalSize.height)
                    guard base.details.count == page.details.count,
                          base.details.allSatisfy({ base.board.contains($0) }),
                          base.details.last!.maxY + 8 < base.targets.first!.frame.minY else { throw Failure.invalidTargets }
                    let countWidth = max(28, CGFloat(info.supplies.map { $0.value.count }.max() ?? 0) * 12)
                    for (index, stock) in info.supplies.enumerated() {
                        guard typography.width(of: stock.label, face: .small, scale: 1) <= base.details[12 + index].width - countWidth - 4
                        else { throw Failure.invalidTargets }
                    }
                    for offset in [CGFloat(0), max(0, base.size.height - logicalSize.height)] {
                        let viewport = CGRect(x: 0, y: offset, width: logicalSize.width, height: logicalSize.height)
                        let layout = MobilePauseArt.pinningFooter(base, viewport: viewport)
                        guard layout.targets.last?.action.id == "resume",
                              layout.targets.filter({ $0.action.primary }).count == 1,
                              layout.targets.map(\.action) == page.orderedFooter,
                              layout.targets.allSatisfy({ viewport.contains($0.frame) && $0.frame.height >= 44 && $0.frame.width >= 44 })
                        else { throw Failure.invalidTargets }
                        for (index, target) in layout.targets.enumerated() {
                            guard typography.width(of: target.action.title, face: .small, scale: 1)
                                <= target.frame.width - (target.action.primary ? 48 : 24) else { throw Failure.invalidTargets }
                            guard layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == target.action.id,
                                  layout.targets.dropFirst(index + 1).allSatisfy({ !$0.frame.intersects(target.frame) }) else { throw Failure.invalidTargets }
                        }
                        guard layout.action(at: CGPoint(x: layout.board.minX + 2, y: viewport.midY)) == nil else { throw Failure.invalidTargets }
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
            "targetsValidated": true, "pinnedResume": true], options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("pause-report.json"))
        print("PASS: \(captures.count) pause renders, scrolling and pinned targets; six rescue states, phone and iPad.")
    }
}
