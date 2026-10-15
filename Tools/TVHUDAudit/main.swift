import CoreGraphics
import Foundation
import ImageIO
import LemmingsAudio
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

@main struct TVHUDAudit {
    enum Failure: Error { case check(String) }
    static func check(_ value: @autoclosure () -> Bool, _ name: String) throws {
        if !value() { throw Failure.check(name) }
    }

    @MainActor static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = root.appendingPathComponent(".build/tv-hud/renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        guard let typography = GameMenuTypography(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings")) else {
            throw Failure.check("Missing shipped bitmap lettering")
        }
        let library = try ClassicMobileLibrary(directory: root.appendingPathComponent("Sources/Ports/lemmings_dos_1991-07-30"))
        let classic = try library.loadLevel(at: 0).session
        let panel = classic.panelFrame.flatMap(MobileBitmapRenderer.image)
        let poses: [(Double, Double, MobileInsets, Bool)] = [
            (1280, 720, .init(top: 36, left: 64, bottom: 36, right: 64), true),
            (1920, 1080, .init(top: 54, left: 96, bottom: 54, right: 96), true),
            (3840, 2160, .init(top: 108, left: 192, bottom: 108, right: 192), true),
            (320, 568, .init(top: 20), false),
            (390, 844, .init(top: 59, bottom: 34), false),
            (844, 390, .init(left: 59, bottom: 21, right: 59), false),
            (768, 1024, .init(top: 20, bottom: 20), false),
            (1024, 768, .init(top: 20, bottom: 20), false)
        ]
        let storage = MobileStorage(directory: output.appendingPathComponent("fixture-saves"))
        let nativeLibraries: [String: any MobileGameLibrary] = [
            "classic": library,
            "lemmings2": try Lemmings2MobileLibrary(directory: root.appendingPathComponent("Sources/Ports/Lemm2"), storage: storage),
            "lemmings3": try Lemmings3MobileLibrary(directory: root.appendingPathComponent("Sources/Ports/LEM3CD"), storage: storage)
        ]
        var captures = 0
        for (width, height, insets, television) in poses {
            for engine in ["classic", "neolemmix", "lemmings2", "lemmings3"] {
                let native = try nativeLibraries[engine]?.loadLevel(at: 0).session
                let artwork = try native?.render(highlight: nil)
                let playfield = artwork.flatMap(MobileBitmapRenderer.image)
                let nativePanel = native?.panelFrame.flatMap(MobileBitmapRenderer.image)
                let rate = engine == "classic" || engine == "neolemmix" ? 50 : nil
                let skills = engine == "lemmings3" ? 5 : 8
                for state in ["running", "paused", "fraction", "half", "critical", "safe", "failed", "nuking"] {
                    let saved = state == "fraction" ? 1 : state == "half" ? 40 : state == "safe" ? 80 : 0
                    let lost = state == "failed" ? 80 : state == "critical" ? 20 : state == "half" ? 10 : 0
                    let required = engine == "lemmings2" || engine == "lemmings3" ? 1 : 60
                    let snapshot = MobileGameSnapshot(tick: 510, released: 80, total: 80, saved: saved,
                        required: required, remainingSeconds: engine == "neolemmix" ? nil : 97,
                        releaseRate: rate, isComplete: state == "failed" || state == "safe", didWin: state == "safe",
                        isEndingRun: state == "nuking", skills: (0..<skills).map {
                            .init(name: ["Climber", "Floater", "Bomber", "Blocker", "Builder", "Basher", "Miner", "Digger"][$0], count: 10)
                        })
                    let active = max(0, 80 - saved - lost)
                    let death = FailureMoodDecision.deathCounter(saved: saved, active: active, unreleased: 0,
                        required: required, total: 80, isComplete: snapshot.isComplete, didWin: snapshot.didWin)
                    let details = MobileHUDRenderer.StatusDetails(lostCount: lost, deathCounter: death, engineIdentifier: engine)
                    let paused = state == "paused"
                    let speed = state == "nuking" ? 4.0 : 1
                    let layout = MobileHUDLayout.make(container: .init(width: width, height: height),
                        safeArea: insets,
                        hasRate: rate != nil, skillCount: skills, supportsRewind: true, hasPlayer: true,
                        engineIdentifier: engine, showsMenuButton: !television, television: television)
                    let baseline = MobileHUDLayout.make(container: .init(width: width, height: height),
                        safeArea: insets,
                        hasRate: rate != nil, skillCount: skills, supportsRewind: true, hasPlayer: true,
                        engineIdentifier: engine, showsMenuButton: !television)
                    let lines = MobileHUDRenderer.televisionStatusLines(snapshot: snapshot, details: details,
                        engineIdentifier: engine, paused: paused, speed: speed)
                    let label = "\(Int(width))-\(engine)-\(state)"
                    let header = layout.interface.statusFrame
                    try check(layout.interface.controlFrames == baseline.interface.controlFrames
                        && layout.minimapFrame == baseline.minimapFrame && layout.panel == baseline.panel,
                        label + " existing controls retain their bounds")
                    try check(!baseline.television && baseline.interface.statusFrame.height == 44 && header.height == 44, label + " single-row header")
                    try check(header.minY == layout.interface.safeFrame.minY && header.maxY == layout.interface.playfieldFrame.minY,
                              label + " status stays above gameplay")
                    try check(lines[0].contains("(\(saved * 100 / 80)%)") && lines[1].contains(death.visible), label + " percent and Mac failure count")
                    try check(lines[1].contains("LOST \(lost)"), label + " actual deaths")
                    try check((rate == nil) == !lines[1].contains("RATE"), label + " native rate support")
                    if engine == "lemmings3" { try check(lines[0].contains("LEFT 0"), label + " reserve") }
                    for line in television ? lines : [] {
                        try check(typography.width(of: GameMenuTypography.menuText(line), face: .small, scale: 1) <= header.width - 16,
                                  label + " complete caption: " + line)
                        try check(typography.height(of: line, face: .small, scale: 1) <= 28, label + " caption height")
                    }
                    let targets = MobileHUDRenderer.targets(layout: layout, snapshot: snapshot, selectedSkill: 0,
                        paused: paused, speed: speed, endRunArmed: false)
                    try check(targets.contains { $0.action == .menu } == !television, label + " platform Menu")
                    for target in targets {
                        let statusRect = CGRect(x: header.x, y: header.y, width: header.width, height: header.height)
                        try check(!target.inputFrame.intersects(statusRect), label + " header cannot activate controls")
                        try check(target.inputFrame.width >= 44 && target.inputFrame.height >= 44, label + " target size")
                        let centre = CGPoint(x: target.inputFrame.midX, y: target.inputFrame.midY)
                        try check(targets.first(where: { $0.inputFrame.contains(centre) })?.action == target.action,
                                  label + " unambiguous activation centre")
                    }
                    let identity = MobileHUDRenderer.statusFrames(layout: layout, hasPlayer: true)
                    try check(identity.player?.height == 44 && identity.counters.height == 44
                        && identity.player?.midY == identity.counters.midY, label + " owner and counters share one line")
                    let fields = MobileHUDRenderer.statusFields(in: identity.counters, snapshot: snapshot, details: details,
                        engineIdentifier: engine, paused: paused, speed: speed, typography: typography)
                    try check(fields.contains { $0.id == "score" && $0.text.contains("\(saved)/\(required)") }, label + " visible rescue score")
                    try check(fields.contains { $0.id == "time" }, label + " visible clock")
                    if television {
                        try check(fields.contains { $0.id == "allowance" }, label + " visible failure allowance")
                    }
                    for (index, field) in fields.enumerated() {
                        try check(identity.counters.contains(field.frame), label + " contained status field")
                        let natural = field.bitmapOnly ? CGFloat(GamePixelTypography.width(of: field.text)) * field.scale
                            : typography.width(of: GameMenuTypography.menuText(field.text), face: field.face, scale: 1)
                        try check(natural <= field.frame.width, label + " complete visible field")
                        try check(field.frame.midY == identity.counters.midY, label + " single baseline")
                        try check(!fields.dropFirst(index + 1).contains { field.frame.intersects($0.frame) }, label + " separate stats")
                    }
                    guard let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8,
                        bytesPerRow: Int(width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.check("Bitmap") }
                    context.translateBy(x: 0, y: height); context.scaleBy(x: 1, y: -1)
                    if let native, let playfield {
                        let field = layout.interface.playfieldFrame
                        let viewport = MobileViewport(levelSize: native.levelSize,
                            viewSize: .init(width: field.width, height: field.height),
                            origin: native.initialCameraOrigin, zoom: 2, pixelAspect: 1.2)
                        context.saveGState()
                        context.clip(to: CGRect(x: field.x, y: field.y, width: field.width, height: field.height))
                        context.translateBy(x: field.x, y: field.y)
                        MobileBitmapRenderer.draw(playfield, viewport: viewport, in: context)
                        context.restoreGState()
                    }
                    MobileHUDRenderer(layout: layout, snapshot: snapshot, selectedSkill: 0, paused: paused, speed: speed,
                        endRunArmed: false, panelImage: nativePanel ?? (engine == "classic" ? panel : nil), typography: typography,
                        playerName: "ABC", statusDetails: details).draw(in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))
                    guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(
                        output.appendingPathComponent(label + ".png") as CFURL, "public.png" as CFString, 1, nil) else { throw Failure.check("PNG") }
                    if let allowance = fields.first(where: { $0.id == "allowance" }),
                       let skull = allowance.text.range(of: "💀"), let font = typography.font(.small) {
                        let prefix = String(allowance.text[..<skull.lowerBound])
                        let offset = allowance.bitmapOnly ? CGFloat(GamePixelTypography.width(of: prefix + " ") - GamePixelTypography.width(of: " "))
                            : typography.width(of: GameMenuTypography.menuText(prefix), face: .small, scale: 1)
                        let glyphFrame = CGRect(x: allowance.frame.minX + offset, y: allowance.frame.minY,
                            width: CGFloat(allowance.bitmapOnly ? 5 : font.cellWidth), height: allowance.frame.height)
                        guard let glyph = image.cropping(to: glyphFrame), let provider = glyph.dataProvider,
                              let bytes = provider.data else { throw Failure.check(label + " allowance crop") }
                        let pixels = Array(bytes as Data)
                        try check(stride(from: 0, to: pixels.count - 3, by: 4).contains {
                            pixels[$0 + 2] > pixels[$0 + 1] && pixels[$0 + 1] > pixels[$0]
                        }, label + " visible blue death allowance")
                    }
                    CGImageDestinationAddImage(destination, image, nil)
                    try check(CGImageDestinationFinalize(destination), label + " PNG")
                    captures += 1
                }
            }
        }
        // L3 extras are native actors, but are absent from the released entrance count.
        let attributes = [UInt16](repeating: 0x1000, count: 128 * 64)
        let runtime = try Lemmings3Runtime(configuration: .init(width: 128, height: 64, attributes: attributes,
            entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 2, releaseInterval: 20, releaseDelay: 1000,
            extras: [.init(x: 30, y: 40, direction: 1)]))
        let sequel: any MobileGameSession = Lemmings3MobileSession(runtime: runtime, engineFingerprint: "l3",
            levelIdentifier: "l3/extra", levelIndex: 0, levelFingerprint: "extra")
        for _ in 0..<100 { sequel.tick() }
        try check(sequel.snapshot.released == 0 && sequel.lostLemmingCount == 1, "Native L3 counts extra deaths")
        try check(sequel.rewind(seconds: 100 / sequel.ticksPerSecond) && sequel.lostLemmingCount == 0,
                  "Rewind restores native extra deaths")
        try check(classic.lostLemmingCount == max(0, classic.snapshot.released - classic.snapshot.saved - classic.activeLemmingCount), "Classic counts native deaths")
        print("PASS \(captures) iOS/TV HUD bitmap renders across phones, iPads, 720p, 1080p and 4K; percentages, deaths, SAFE/failure, pause, speed, nuke, native L3 extras and input bounds")
    }
}
