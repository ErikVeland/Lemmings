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
        var captures = 0
        for width in [1280.0, 1920, 3840] {
            let height = width * 9 / 16
            for engine in ["classic", "neolemmix", "lemmings2", "lemmings3"] {
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
                    let details = MobileHUDRenderer.StatusDetails(lostCount: lost, deathCounter: death)
                    let paused = state == "paused"
                    let speed = state == "nuking" ? 4.0 : 1
                    let layout = MobileHUDLayout.make(container: .init(width: width, height: height),
                        safeArea: .init(top: height * 0.05, left: width * 0.05, bottom: height * 0.05, right: width * 0.05),
                        hasRate: rate != nil, skillCount: skills, supportsRewind: true, hasPlayer: true,
                        engineIdentifier: engine, showsMenuButton: false, television: true)
                    let baseline = MobileHUDLayout.make(container: .init(width: width, height: height),
                        safeArea: .init(top: height * 0.05, left: width * 0.05, bottom: height * 0.05, right: width * 0.05),
                        hasRate: rate != nil, skillCount: skills, supportsRewind: true, hasPlayer: true,
                        engineIdentifier: engine, showsMenuButton: false)
                    let lines = MobileHUDRenderer.televisionStatusLines(snapshot: snapshot, details: details,
                        engineIdentifier: engine, paused: paused, speed: speed)
                    let label = "\(Int(width))-\(engine)-\(state)"
                    let header = layout.interface.statusFrame
                    try check(layout.interface.controlFrames == baseline.interface.controlFrames
                        && layout.minimapFrame == baseline.minimapFrame && layout.panel == baseline.panel,
                        label + " existing controls retain their bounds")
                    try check(!baseline.television && baseline.interface.statusFrame.height == 44, label + " mobile header is unchanged")
                    try check(header.minY == layout.interface.safeFrame.minY && header.maxY == layout.interface.playfieldFrame.minY,
                              label + " status stays above gameplay")
                    try check(lines[0].contains("(\(saved * 100 / 80)%)") && lines[1].contains(death.visible), label + " percent and Mac failure count")
                    try check(lines[1].contains("LOST \(lost)"), label + " actual deaths")
                    try check((rate == nil) == !lines[1].contains("RATE"), label + " native rate support")
                    if engine == "lemmings3" { try check(lines[0].contains("LEFT 0"), label + " reserve") }
                    for line in lines {
                        try check(typography.width(of: GameMenuTypography.menuText(line), face: .small, scale: 1) <= header.width - 16,
                                  label + " complete caption: " + line)
                        try check(typography.height(of: line, face: .small, scale: 1) <= 28, label + " caption height")
                    }
                    let targets = MobileHUDRenderer.targets(layout: layout, snapshot: snapshot, selectedSkill: 0,
                        paused: paused, speed: speed, endRunArmed: false)
                    try check(!targets.contains { $0.action == .menu }, label + " hardware Menu")
                    for target in targets {
                        let statusRect = CGRect(x: header.x, y: header.y, width: header.width, height: header.height)
                        try check(!target.inputFrame.intersects(statusRect), label + " header cannot activate controls")
                        try check(target.inputFrame.width >= 44 && target.inputFrame.height >= 44, label + " target size")
                        let centre = CGPoint(x: target.inputFrame.midX, y: target.inputFrame.midY)
                        try check(targets.first(where: { $0.inputFrame.contains(centre) })?.action == target.action,
                                  label + " unambiguous activation centre")
                    }
                    let identity = MobileHUDRenderer.statusFrames(layout: layout, hasPlayer: true)
                    try check(identity.player?.height == 20 && identity.counters.height == 56, label + " owner and counters")
                    guard let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8,
                        bytesPerRow: Int(width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.check("Bitmap") }
                    context.translateBy(x: 0, y: height); context.scaleBy(x: 1, y: -1)
                    MobileHUDRenderer(layout: layout, snapshot: snapshot, selectedSkill: 0, paused: paused, speed: speed,
                        endRunArmed: false, panelImage: engine == "classic" ? panel : nil, typography: typography,
                        playerName: "ABC", statusDetails: details).draw(in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))
                    guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(
                        output.appendingPathComponent(label + ".png") as CFURL, "public.png" as CFString, 1, nil) else { throw Failure.check("PNG") }
                    if let skull = lines[1].range(of: "💀"), let font = typography.font(.small) {
                        let lineWidth = typography.width(of: GameMenuTypography.menuText(lines[1]), face: .small, scale: 1)
                        let prefix = lines[1].distance(from: lines[1].startIndex, to: skull.lowerBound)
                        let glyphRect = CGRect(x: floor(header.midX - lineWidth / 2) + Double(prefix * font.cellWidth),
                            y: header.minY + 48, width: Double(font.cellWidth), height: 28)
                        guard let glyph = image.cropping(to: glyphRect),
                            let sample = CGContext(data: nil, width: font.cellWidth, height: 28, bitsPerComponent: 8,
                                bytesPerRow: font.cellWidth * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                            throw Failure.check(label + " skull crop")
                        }
                        sample.draw(glyph, in: CGRect(x: 0, y: 0, width: font.cellWidth, height: 28))
                        guard let data = sample.data else { throw Failure.check(label + " skull pixels") }
                        let pixels = Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: font.cellWidth * 28 * 4))
                        try check(stride(from: 0, to: pixels.count - 3, by: 4).contains {
                            pixels[$0 + 2] > pixels[$0 + 1] && pixels[$0 + 1] > pixels[$0]
                        }, label + " skull has visible blue pixels")
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
        print("PASS \(captures) TV HUD bitmap renders at 720p, 1080p and 4K; percentages, deaths, SAFE/failure, pause, speed, nuke, native L3 extras and input bounds")
    }
}
