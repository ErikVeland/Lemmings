import AppKit
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

@main struct BombCountdownTests {
    enum Failure: Error { case invalidRender(String) }
    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw Failure.invalidRender(message) }
    }
    @MainActor static func main() {
        do { try run() } catch { print("FAIL: \(error)"); exit(1) }
    }
    @MainActor static func run() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = root.appendingPathComponent(".build/native-countdown/previews")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let renderer = BombCountdownRenderer()
        for backing in [1, 2, 3] {
            for zoom in [1.5, 3.0, 4.5] {
                var digitWidth: CGFloat?
                for digit in 1...5 {
                    let context = try canvas(width: 300, height: 100, backing: backing)
                    let frame = renderer.draw(seconds: digit, above: CGPoint(x: 150, y: 80), zoom: zoom, in: context)
                    try require(abs(frame.midX - 150) < 0.001 && abs(frame.maxY - 80) < 0.001, "Digit drifted from sprite anchor")
                    if let digitWidth { try require(abs(frame.width - digitWidth) < 0.001, "Digits changed width") }
                    digitWidth = frame.width
                    let image = context.makeImage()!
                    let pixels = image.dataProvider!.data! as Data
                    let alpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
                    try require((alpha.max() ?? 0) > 128, "Native digit is too faint")
                    for offset in stride(from: 0, to: pixels.count, by: 4) {
                        try require(pixels[offset] == pixels[offset + 3]
                            && pixels[offset + 1] == pixels[offset + 3]
                            && pixels[offset + 2] == pixels[offset + 3], "Digit is not neutral white")
                    }
                    try require(alpha.contains { $0 > 0 && $0 < 255 }, "Digit has no native antialiased edge")
                    try save(image, to: output.appendingPathComponent("digit-\(digit)-\(backing)x-zoom\(zoom).png"))
                }
            }
        }
        let empty = try canvas(width: 100, height: 100, backing: 3)
        try require(renderer.draw(seconds: 0, above: CGPoint(x: 50, y: 80), zoom: 3, in: empty).isNull,
            "Expired countdown drew a digit")
        try require((empty.makeImage()!.dataProvider!.data! as Data).allSatisfy { $0 == 0 }, "Expired countdown left pixels")

        let directory = root.appendingPathComponent(".build/ios-ports/lemmings_dos_1991-07-30")
        let level = try ClassicDataSet.detect(directory: directory).campaign.levels[0].level
        let ground = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
        let assets = try ClassicMainDATAssets.load(from: directory)
        let scene = try ClassicLevelRenderer.render(level, groundSet: ground)
        let original = try ClassicDOSSimulation(level: level, renderedLevel: scene, mainDATAssets: assets)
        let c = original.configuration
        let initial = try ClassicDOSSimulation(terrain: original.terrain,
            configuration: .init(totalLemmings: 1, requiredToSave: 1, timeLimitTicks: nil,
                initialReleaseRate: 99, entrances: c.entrances, triggers: c.triggers,
                initialSkills: [.blocker: 1, .bomber: 1], maximumX: c.maximumX, maximumY: c.maximumY),
            destructionMasks: original.comparisonDestructionMasks)
        let bundle = output.appendingPathComponent("Artwork")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        for (name, export) in [("MacArtwork", "mac-artwork"), ("AmigaArtwork", "amiga-artwork")] {
            let link = bundle.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: link.path) {
                try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root.appendingPathComponent(".build/\(export)/export"))
            }
        }
        for (name, graphics) in [("dos", ClassicGraphicsSource.dosVGA), ("mac", .macintosh), ("amiga", .amiga)] {
            let game = ClassicMobileSession(simulation: initial, renderedLevel: scene, assets: assets,
                palette: try ClassicLemmingPalette.inLevelVGA(terrainPalette: ground.terrainPalette),
                levelIdentifier: "countdown", levelIndex: 0, authoredLevel: level, ground: ground,
                artworkFamily: "lemmings", artworkRoot: bundle)
            var settings = ClassicSettings(); settings.graphics = graphics; settings.colorDepth = .full
            game.applySettings(settings)
            for _ in 0..<200 where !game.targetCandidates(for: 3).contains(where: { $0.assignment == .eligible }) { game.tick() }
            let target = game.targetCandidates(for: 3).first(where: { $0.assignment == .eligible })!
            try require(game.assign(control: 3, to: target.id), "Blocker assignment failed")
            try require(game.assign(control: 2, to: target.id), "Bomb assignment failed")
            var captured: Set<Int> = []
            while let countdown = game.bombCountdowns.first {
                if captured.insert(countdown.seconds).inserted {
                    let bitmap = try game.render(highlight: nil)
                    let context = try canvas(width: 390, height: 240, backing: 3)
                    let viewport = MobileViewport(levelSize: game.levelSize, viewSize: .init(width: 390, height: 240),
                        origin: .init(x: target.point.x - 45, y: target.point.y - 42), zoom: 4,
                        pixelAspect: game.renderScale == 1 ? 1.2 : 1)
                    MobileBitmapRenderer.draw(MobileBitmapRenderer.image(bitmap)!, viewport: viewport, in: context)
                    let point = viewport.viewPoint(fromLevel: countdown.anchor)
                    renderer.draw(seconds: countdown.seconds, above: CGPoint(x: point.x, y: point.y), zoom: viewport.zoom, in: context)
                    let recovered = viewport.levelPoint(fromView: point)
                    try require(abs(recovered.x - countdown.anchor.x) < 0.001 && abs(recovered.y - countdown.anchor.y) < 0.001,
                        "Countdown changed viewport input mapping")
                    try save(context.makeImage()!, to: output.appendingPathComponent("\(name)-bomb-\(countdown.seconds)-retina.png"))
                }
                game.tick()
            }
            try require(captured == [1, 2, 3, 4, 5], "Countdown omitted a digit")
        }
        print("PASS native countdown: five digits, fixed width, 1x/2x/3x edges, fractional zoom, expiry, three artwork sets and viewport input mapping")
    }
    static func canvas(width: Int, height: Int, backing: Int) throws -> CGContext {
        guard let context = CGContext(data: nil, width: width * backing, height: height * backing,
            bitsPerComponent: 8, bytesPerRow: width * backing * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.invalidRender("No bitmap context") }
        context.translateBy(x: 0, y: CGFloat(height * backing))
        context.scaleBy(x: CGFloat(backing), y: -CGFloat(backing))
        return context
    }
    static func save(_ image: CGImage, to url: URL) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let png = rep.representation(using: .png, properties: [:]) else { throw Failure.invalidRender("No PNG output") }
        try png.write(to: url)
    }
}
