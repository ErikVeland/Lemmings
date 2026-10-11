import Foundation
import CoreGraphics
import ImageIO
import LemmingsGameArt
import LemmingsMobileCore

@main struct MenuAudit {
    static func main() throws {
        guard CommandLine.arguments.count == 4 else { throw Failure.invalidArguments }
        let artwork = URL(fileURLWithPath: CommandLine.arguments[1])
        let content = URL(fileURLWithPath: CommandLine.arguments[2])
        let output = URL(fileURLWithPath: CommandLine.arguments[3])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        guard let typography = GameMenuTypography(directory: artwork),
              typography.interface.logo != nil,
              typography.font(.small) != nil, typography.font(.large) != nil else { throw Failure.missingArtwork }
        let library = try ClassicMobileLibrary(directory: content)
        let session = try library.loadLevel(at: 0).session
        let bitmap = try session.render(highlight: nil)
        guard let image = MobileBitmapRenderer.image(bitmap) else { throw Failure.missingArtwork }
        let previewSource = CGRect(x: session.initialCameraOrigin.x, y: 0, width: 320, height: 160)
        typealias Action = GameFrontEnd.Action
        let homeRows: [Action] = [.init("classic", "Lemmings  0/120", primary: true),
                                 .init("l2", "Lemmings 2 - Unavailable", enabled: false),
                                 .init("l3", "Lemmings 3 - Unavailable", enabled: false)]
        let footer: [Action] = [.init("settings", "Settings"), .init("data", "Game Data")]
        let pages: [(String, GameFrontEnd.Page)] = [
            ("long-title", .init(title: library.levels.max(by: { $0.title.count < $1.title.count })!.title,
                                subtitle: "Mayhem", footer: [.init("home", "Back"), .init("play", "Play again", primary: true)], preview: true)),
            ("home", .init(title: "Lemmings", home: true, rows: homeRows, footer: footer)),
            ("resume", .init(title: "Lemmings", home: true,
                             rows: [.init("resume", "Resume saved run", primary: true)] + homeRows.map {
                                .init($0.id, $0.title, enabled: $0.enabled) }, footer: footer)),
            ("levels", .init(title: "Just Dig!", subtitle: "Fun 1/30", details: ["10 Lemmings   Save 10", "Time 5:00"],
                             footer: [.init("rankPrevious", "< Rank"), .init("rankNext", "Rank >"),
                                      .init("previous", "< Level", enabled: false), .init("next", "Level >"),
                                      .init("home", "Back"), .init("play", "Play", primary: true)], preview: true, footerColumns: 2)),
            ("briefing", .init(title: "Just Dig!", subtitle: "Fun 1", details: ["10 Lemmings   Save 10", "Time 5:00"],
                               footer: [.init("0", "Start", primary: true), .init("1", "Library")], preview: true)),
            ("pause", .init(title: "Paused", subtitle: "Fun 1  Just Dig!",
                            footer: [.init("0", "Resume", primary: true), .init("1", "Library")])),
            ("win", .init(title: "Level complete", subtitle: "Fun 1  Just Dig!", details: ["Saved 10 of 10", "Required 10"],
                          footer: [.init("0", "Next level", primary: true), .init("1", "Retry"), .init("2", "Library")], preview: true)),
            ("loss", .init(title: "Try again", subtitle: "Fun 1  Just Dig!", details: ["Saved 4 of 10", "Required 10"],
                           footer: [.init("0", "Retry", primary: true), .init("1", "Library")], preview: true)),
            ("settings", .init(title: "Settings", rows: [.init("planning", "Pause to assign", selected: true),
                                                        .init("speed", "Fast speed: 2X")], footer: [.init("home", "Back")])),
            ("data", .init(title: "Game Data", details: ["Lemmings", "120 levels"],
                           footer: [.init("home", "Back"), .init("import", "Import")])),
            ("empty", .init(title: "Game Data", footer: [.init("home", "Back"), .init("import", "Import", primary: true)])),
        ]
        var evidence: [[String: Any]] = []
        for (device, size) in [("ipad-portrait", CGSize(width: 834, height: 1092)),
                               ("ipad-landscape", CGSize(width: 1112, height: 814)),
                               ("iphone-portrait", CGSize(width: 390, height: 763)),
                               ("iphone-landscape", CGSize(width: 756, height: 369)),
                               ("iphone-narrow-portrait", CGSize(width: 320, height: 548)),
                               ("iphone-narrow-landscape", CGSize(width: 568, height: 300))] {
            for (state, page) in pages {
                let layout = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
                guard Set(layout.targets.map { $0.action.id }).count == layout.targets.count,
                      layout.targets.filter({ $0.action.primary && $0.action.enabled }).count <= 1 else { throw Failure.invalidTargets }
                for target in layout.targets {
                    guard target.frame.width >= 44, target.frame.height >= 44,
                          CGRect(origin: .zero, size: layout.size).contains(target.frame),
                          layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == (target.action.enabled ? target.action.id : nil)
                    else { throw Failure.invalidTargets }
                }
                guard layout.action(at: CGPoint(x: layout.board.minX + 1, y: layout.board.midY)) == nil else { throw Failure.invalidTargets }
                for (index, target) in layout.targets.enumerated() {
                    for other in layout.targets.dropFirst(index + 1) where target.frame.intersects(other.frame) { throw Failure.invalidTargets }
                }
                guard let context = CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height),
                                               bitsPerComponent: 8, bytesPerRow: Int(layout.size.width) * 4,
                                               space: CGColorSpaceCreateDeviceRGB(),
                                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.missingArtwork }
                context.translateBy(x: 0, y: layout.size.height); context.scaleBy(x: 1, y: -1)
                GameFrontEnd.draw(page, layout: layout, typography: typography, preview: image,
                                 previewSource: previewSource, in: context)
                guard let result = context.makeImage() else { throw Failure.missingArtwork }
                let file = output.appendingPathComponent("\(device)-\(state).png")
                guard let destination = CGImageDestinationCreateWithURL(file as CFURL, "public.png" as CFString, 1, nil) else { throw Failure.missingArtwork }
                CGImageDestinationAddImage(destination, result, nil)
                guard CGImageDestinationFinalize(destination) else { throw Failure.missingArtwork }
                evidence.append(["device": device, "state": state, "viewportWidth": size.width, "viewportHeight": size.height,
                                 "contentHeight": layout.size.height, "targets": layout.targets.count,
                                 "needsVerticalScroll": layout.size.height > size.height, "file": file.lastPathComponent,
                                 "minimumTouchExtent": 44, "disabledAndGapTargetsBlocked": true])
            }
        }
        let report: [String: Any] = ["renderedStates": evidence.count, "originalMacGlyphsAndLogo": true,
                                    "targetsValidated": true, "audio": "muted", "windows": "none",
                                    "physicalUIKitAcceptance": "pending", "captures": evidence]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("report.json"), options: .atomic)
        print("PASS: \(evidence.count) front-end renders, touch targets, disabled actions, menu gaps and scroll reachability.")
    }
    enum Failure: Error { case invalidArguments, missingArtwork, invalidTargets }
}
