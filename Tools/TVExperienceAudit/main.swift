import CoreGraphics
import Foundation
import ImageIO
import LemmingsGameArt
import LemmingsMobileCore
import LemmingsTVCore
import NxlvKit

@main struct TVExperienceAudit {
    enum Failure: Error { case invalid(String) }
    @MainActor static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = root.appendingPathComponent("Documentation/ReleaseReadiness/TVExperience-2026-10-14")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        guard let typography = GameMenuTypography(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings")) else { throw Failure.invalid("Missing shipped menu artwork") }
        let portraits = GamePortraitArt(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        let library = try ClassicMobileLibrary(directory: root.appendingPathComponent("Sources/Ports/lemmings_dos_1991-07-30"))
        let game = try TVGameExperience(content: library.loadLevel(at: 0), owner: "host")
        game.session.applySettings(.init())
        guard game.session.renderScale == 2 else { throw Failure.invalid("Native Macintosh gameplay artwork missing from audit bundle") }
        game.resize(.init(width: 1728, height: 776)); _ = game.resume()
        for tick in 0...140 { _ = game.advance(at: Double(tick) / game.session.ticksPerSecond) }
        game.pause(); game.cycleTarget(1)
        let scene = MobileBitmapRenderer.image(try game.session.render(highlight: game.target))
        let previewScene = MobileBitmapRenderer.image(try game.session.render(highlight: nil))
        let visible = game.viewport.visibleLevelRect
        let renderScale = game.session.renderScale
        let preview = previewScene?.cropping(to: CGRect(x: visible.x * renderScale, y: visible.y * renderScale, width: visible.width * renderScale, height: visible.height * renderScale).integral)
        let pages: [(String, GameFrontEnd.Page)] = [
            ("home", .init(title: "Ultimate Lemmings", subtitle: "Player 1", home: true, rows: [.init("hotseat", "Hot Seat"), .init("players", "Players"), .init("settings", "Settings"), .init("play", "Play")], footer: [.init("resume", "Resume - Player 1", primary: true)])),
            ("games", .init(title: "Choose a game", rows: [.init("classic", "Lemmings", primary: true), .init("l2", "Lemmings 2", enabled: false), .init("l3", "Lemmings 3", enabled: false)], footer: [.init("back", "Back")])),
            ("ranks", .init(title: "Lemmings", rows: [.init("fun", "Fun"), .init("tricky", "Tricky"), .init("taxing", "Taxing"), .init("mayhem", "Mayhem")], footer: [.init("back", "Back"), .init("previous", "<", enabled: false), .init("more", ">", enabled: false)])),
            ("levels", .init(title: "Fun", subtitle: "1-4 / 30", rows: [.init("level.0", "1 - Just dig!", selected: true), .init("level.1", "2 - Only floaters can survive this"), .init("level.2", "3 - Tailor made for blockers"), .init("level.3", "4 - Now use miners and climbers")], footer: [.init("back", "Back"), .init("previous", "<", enabled: false), .init("more", ">")])),
            ("briefing", .init(title: "Just dig!", subtitle: "Fun", rows: [.init("ready", "Start", primary: true)], details: ["10 LEMMINGS / SAVE 1", "5 MINUTES"], footer: [.init("back", "Back")], preview: true)),
            ("handover", .init(title: "Just dig!", subtitle: "Player 2", rows: [.init("ready", "Ready", primary: true, portrait: 1)], details: ["10 LEMMINGS / SAVE 1", "5 MINUTES"], footer: [.init("back", "Back")], preview: true)),
            ("paused", .init(title: "Paused", subtitle: "Player 1", rows: [.init("skills", "Skills"), .init("targets", "Lemmings"), .init("camera", "Camera"), .init("time", "Time and actions"), .init("help", "Controls")], footer: [.init("library", "Library"), .init("retry", "Retry"), .init("resume", "Resume", primary: true)])),
            ("camera", .init(title: "Camera", rows: [.init("overview", "Overview"), .init("play", "Play", selected: true), .init("precision", "Precision"), .init("entrance", "Entrance"), .init("exit", "Exit")], footer: [.init("back", "Back"), .init("pan", "Move camera", primary: true)])),
            ("skills", .init(title: "Skills", rows: [.init("climber", "Climber  10"), .init("floater", "Floater  0", enabled: false), .init("builder", "Builder  10", selected: true), .init("basher", "Basher  10")], footer: [.init("back", "Back"), .init("previous", "<", enabled: false), .init("next", ">")])),
            ("success", .init(title: "Level complete", subtitle: "Player 1", rows: [.init("retry", "Retry - Player 1", portrait: 0), .init("next", "Next - Player 2", primary: true, portrait: 1)], details: ["10 / 10 RESCUED"], footer: [.init("library", "Library")], preview: true)),
            ("partial-success", .init(title: "Level complete", subtitle: "Player 1", rows: [.init("again", "Retry - Player 1", portrait: 0), .init("next", "Next - Player 2", primary: true, portrait: 1)], details: ["1 / 10 RESCUED"], footer: [.init("library", "Library")], preview: true)),
            ("failure", .init(title: "Try again", subtitle: "Player 1", rows: [.init("again", "Retry - Player 1", portrait: 0), .init("retry", "Retry - Player 2", primary: true, portrait: 1)], details: ["0 / 10 RESCUED"], footer: [.init("library", "Library")], preview: true)),
            ("confirmation", .init(title: "End attempt?", footer: [.init("cancel", "Cancel", primary: true), .init("end", "End attempt")])),
            ("settings", .init(title: "Settings", rows: [.init("planning", "Pause on skill change", selected: true), .init("aim", "Aim 1.0"), .init("text", "Large menu text"), .init("swap", "Swap sticks"), .init("audio", "Audio")], footer: [.init("back", "Back")])),
            ("audio", .init(title: "Audio", rows: [.init("music", "Music", selected: true), .init("effects", "Sound effects", selected: false)], footer: [.init("back", "Back")])),
            ("player", .init(title: "Player 2", rows: [.init("name", "Name"), .init("portrait", "Portrait", portrait: 1), .init("choose", "Choose player", primary: true)], footer: [.init("back", "Back")])),
            ("roster", .init(title: "Hot Seat", rows: [.init("host", "Player 1", enabled: false, selected: true, portrait: 0), .init("guest", "Player 2", selected: true, portrait: 1), .init("third", "Player 3", portrait: 2), .init("fourth", "Player 4", portrait: 3)], footer: [.init("back", "Back"), .init("more", ">"), .init("continue", "Continue", primary: true)])),
            ("transport", .init(title: "Time and actions", rows: [.init("step", "Step forward"), .init("backStep", "Step back", enabled: false), .init("rewind", "Rewind", enabled: false), .init("speed", "Speed 1X"), .init("end", "End attempt")], footer: [.init("back", "Back")])),
            ("help", .init(title: "Controls", details: ["LEFT STICK: AIM / RIGHT STICK: CAMERA", "SHOULDERS: SKILLS / D-PAD: TARGETS", "PRIMARY BUTTON: ASSIGN / MENU: PAUSE", "REMOTE: MOVE, CLICK TO ASSIGN", "PLAY/PAUSE: PAUSE / BACK: CONTROLS", "SKILL CHANGES CAN PAUSE FOR PLANNING", "CAMERA, STEP AND SPEED: PAUSED CONTROLS"], footer: [.init("back", "Back")]))
        ]
        var records: [[String: Any]] = []
        for (name, page) in pages {
            let layout = TVMenuArt.layout(page)
            for (index, target) in layout.targets.enumerated() {
                guard layout.board.contains(target.frame.insetBy(dx: -3, dy: -3)), target.frame.height >= 44 else { throw Failure.invalid(name + " bounds") }
                for other in layout.targets.dropFirst(index + 1) where target.frame.insetBy(dx: -3, dy: -3).intersects(other.frame.insetBy(dx: -3, dy: -3)) {
                    throw Failure.invalid(name + " overlap " + target.action.id + "/" + other.action.id)
                }
            }
            let focused = (page.rows + page.orderedFooter).first(where: { $0.primary && $0.enabled })?.id
                ?? (page.rows + page.orderedFooter).first(where: \.enabled)?.id
            for textScale in [1.0, 1.25] { for scale in [1, 2] {
                let context = try context(width: 864 * scale, height: 480 * scale)
                context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
                TVMenuArt.draw(page, focused: focused, preview: preview, typography: typography, portraits: portraits, textScale: textScale, in: context)
                let filename = name + (textScale > 1 ? "-large" : "") + "-\(scale)x.png"
                try png(context, at: output.appendingPathComponent(filename))
                records.append(["state": name, "scale": scale, "largeText": textScale > 1, "capture": filename, "targets": layout.targets.count])
            } }
        }
        for mode in TVCameraMode.allCases {
            game.setCamera(mode)
            let context = try context(width: 1728, height: 960)
            let renderer = TVPlayfieldArt(typography: typography, portraits: portraits)
            renderer.ownerName = "Player 1"
            renderer.draw(game: game, image: scene, skillImage: game.session.skillCursorFrame(control: game.selectedControl).flatMap(MobileBitmapRenderer.image),
                bounds: CGRect(x: 0, y: 0, width: 1728, height: 960), in: context)
            try png(context, at: output.appendingPathComponent("play-\(mode.rawValue).png"))
        }
        game.setCamera(.play); _ = game.resume()
        for (name, control) in [("active", game.selectedControl), ("unavailable", 0)] {
            game.selectSkill(control)
            let context = try context(width: 1728, height: 960)
            let renderer = TVPlayfieldArt(typography: typography, portraits: portraits)
            renderer.ownerName = "Player 1"
            renderer.draw(game: game, image: MobileBitmapRenderer.image(try game.session.render(highlight: game.target)),
                skillImage: game.session.skillCursorFrame(control: control).flatMap(MobileBitmapRenderer.image),
                bounds: CGRect(x: 0, y: 0, width: 1728, height: 960), in: context)
            try png(context, at: output.appendingPathComponent("play-" + name + ".png"))
        }
        let start = try TVGameExperience(content: library.loadLevel(at: 0), owner: "host")
        start.session.applySettings(.init()); start.resize(.init(width: 1728, height: 776)); _ = start.resume()
        let startContext = try context(width: 1728, height: 960)
        let startRenderer = TVPlayfieldArt(typography: typography, portraits: portraits)
        startRenderer.ownerName = "Player 1"
        startRenderer.draw(game: start,
            image: MobileBitmapRenderer.image(try start.session.render(highlight: nil)), skillImage: nil,
            bounds: CGRect(x: 0, y: 0, width: 1728, height: 960), in: startContext)
        try png(startContext, at: output.appendingPathComponent("countdown.png"))
        let data = try JSONSerialization.data(withJSONObject: ["menuCaptures": records, "playfieldCaptures": 6, "nativeRenderScale": game.session.renderScale, "scope": "Shared shipping bitmap renderers and target geometry; no UIKit event or physical TV acceptance"], options: [.prettyPrinted, .sortedKeys])
        try data.write(to: output.appendingPathComponent("captures.json"), options: .atomic)
        print("PASS \(records.count) TV menu renders and target layouts, 6 native gameplay renders")
    }
    static func context(width: Int, height: Int) throws -> CGContext {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.invalid("Bitmap allocation") }
        context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1); return context
    }
    static func png(_ context: CGContext, at url: URL) throws {
        guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { throw Failure.invalid("PNG") }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw Failure.invalid("PNG save") }
    }
}
