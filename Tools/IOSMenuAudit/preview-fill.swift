import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkPreviewFill(typography: GameMenuTypography, content: URL, output: URL) throws {
        let ports = content.deletingLastPathComponent()
        let storage = MobileStorage(directory: output.appendingPathComponent("isolated-storage"))
        let libraries: [any MobileGameLibrary] = [try ClassicMobileLibrary(directory: content),
            try Lemmings2MobileLibrary(directory: ports.appendingPathComponent("Lemm2"), storage: storage),
            try Lemmings3MobileLibrary(directory: ports.appendingPathComponent("LEM3CD"), storage: storage)]
        var levels = try libraries.map { library in
            let level = try library.loadLevel(at: 0)
            return (level.session.engineIdentifier, level)
        }
        let catalogue = MobileCatalogue(portsRoot: ports, fanFolders: [ports.deletingLastPathComponent().appendingPathComponent("LevelPacks")])
        if let pack = catalogue.pack(id: "lldb-547") {
            let library = try catalogue.library(for: pack)
            guard let index = library.levels.firstIndex(where: { $0.title == "Cellbash" }) else { throw Failure.missingArtwork }
            levels.append(("cellbash", try library.loadLevel(at: index)))
        } else {
            print("SKIP: Cellbash pack is unavailable.")
        }
        var captures = 0
        for (name, level) in levels {
            let session = level.session
            let frame = try session.render(highlight: nil)
            guard let image = MobileBitmapRenderer.image(frame) else { throw Failure.missingArtwork }
            let source = MobileMenuPreview.sourceRect(frame: frame, origin: session.menuPreviewOrigin, renderScale: session.renderScale)
            guard source.width == min(320 * session.renderScale, Double(frame.width)),
                  source.height == min(160 * session.renderScale, Double(frame.height)),
                  source.x >= 0, source.y >= 0,
                  source.x + source.width <= Double(frame.width), source.y + source.height <= Double(frame.height)
            else { throw invalidTargets(line: #line) }
            for (pose, size) in [("portrait", CGSize(width: 390, height: 844)),
                ("landscape", CGSize(width: 844, height: 390)), ("tablet", CGSize(width: 834, height: 1194)),
                ("tv", CGSize(width: 1920, height: 1080))] {
                for setting in ClassicInterfaceSize.allCases {
                    let page = GameFrontEnd.Page(title: level.summary.title, subtitle: level.summary.caption,
                        details: ["\(session.snapshot.total) Lemmings   Save \(session.snapshot.required)", "Time 5:00"],
                        footer: [.init("library", "Library"), .init("start", "Start", primary: true)], preview: true)
                    let scale = MobileSettingsArt.interfaceScale(setting, width: size.width, television: pose == "tv")
                    let layout = GameFrontEnd.layout(page, width: size.width / scale, minimumHeight: size.height / scale)
                    for target in layout.targets {
                        guard target.frame.width * scale >= 44, target.frame.height * scale >= 44,
                              layout.action(at: .init(x: target.frame.midX, y: target.frame.midY)) == target.action.id,
                              !layout.preview.intersects(target.frame) else { throw invalidTargets(line: #line) }
                    }
                    let context = try bitmapContext(size: .init(width: size.width, height: ceil(layout.size.height * scale)))
                    context.scaleBy(x: scale, y: scale)
                    GameFrontEnd.draw(page, layout: layout, typography: typography, preview: image,
                        previewSource: CGRect(x: source.x, y: source.y, width: source.width, height: source.height), in: context)
                    try save(context: context, to: output.appendingPathComponent("\(name)-\(pose)-\(setting.rawValue).png"))
                    captures += 1
                }
            }
        }
        // A solid source exposes padding, letterboxing and border overdraw at every aspect ratio.
        let source = try bitmapContext(size: .init(width: 320, height: 160))
        source.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        source.fill(CGRect(x: 0, y: 0, width: 320, height: 160))
        guard let image = source.makeImage() else { throw Failure.missingArtwork }
        for size in [CGSize(width: 300, height: 150), .init(width: 200, height: 200), .init(width: 400, height: 100)] {
            let context = try bitmapContext(size: size)
            GameDisplayArt.drawPreview(in: context, frame: CGRect(origin: .zero, size: size), image: image)
            guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else { throw Failure.missingArtwork }
            for y in 0..<context.height {
                for x in 0..<context.width {
                    let offset = y * context.bytesPerRow + x * 4
                    let red = data[offset] > 250 && data[offset + 1] < 5 && data[offset + 2] < 5
                    let inside = x >= 2 && y >= 2 && x < context.width - 2 && y < context.height - 2
                    guard red == inside else { throw invalidTargets(line: #line) }
                }
            }
        }
        guard GameSupport.page.previewFitsImage else { throw invalidTargets(line: #line) }
        print("PASS: \(captures) Classic/L2/L3 preview renders, Library/Start targets, opening crops, edge fill and border containment. Windowless and muted.")
    }
}
