import AppKit
import LemmingsGameArt
import NxlvKit

@MainActor func verifyExplosionPixelRendering(root: URL) throws {
    enum Failure: Error { case invalidPixels }
    let burst = PixelExplosion(id: 4, birthTick: 100, x: 80, y: 60)
    let directory = root.appendingPathComponent(".build/bomb-parity/previews")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for age in [1, 4, 8, 15, 16] {
        guard let context = CGContext(data: nil, width: 640, height: 400, bitsPerComponent: 8,
            bytesPerRow: 640 * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.invalidPixels }
        context.translateBy(x: 0, y: 400); context.scaleBy(x: 1, y: -1)
        ExplosionGlow.drawSpray(burst, at: 100 + age, origin: CGPoint(x: 320, y: 220),
            pixel: CGSize(width: 4, height: 4), context: context)
        guard let image = context.makeImage(), let data = image.dataProvider?.data else { throw Failure.invalidPixels }
        let bytes = data as Data
        var occupied = 0
        for index in stride(from: 0, to: bytes.count, by: 4) {
            if bytes[index + 3] > 0 {
                guard bytes[index + 3] == 255 else { throw Failure.invalidPixels }
                occupied += 1
            }
        }
        if age < 16 && occupied == 0 || age == 16 && occupied != 0 { throw Failure.invalidPixels }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let png = rep.representation(using: .png, properties: [:]) else { throw Failure.invalidPixels }
        try png.write(to: directory.appendingPathComponent("pixel-spray-\(age).png"))
    }
    let dataRoot = root.appendingPathComponent(".build/ios-ports/lemmings_dos_1991-07-30")
    let level = try ClassicDataSet.detect(directory: dataRoot).campaign.levels[0].level
    let assets = try ClassicMainDATAssets.load(from: dataRoot)
    let ground = try ClassicGroundSet.load(style: level.groundStyle, from: dataRoot)
    let scene = try ClassicLevelRenderer.render(level, groundSet: ground)
    let original = try ClassicDOSSimulation(level: level, renderedLevel: scene, mainDATAssets: assets)
    let c = original.configuration
    let start = try ClassicDOSSimulation(terrain: original.terrain,
        configuration: .init(totalLemmings: 1, requiredToSave: 1, timeLimitTicks: nil,
            initialReleaseRate: 99, entrances: c.entrances, triggers: c.triggers,
            initialSkills: [.blocker: 1, .bomber: 1], maximumX: c.maximumX, maximumY: c.maximumY),
        destructionMasks: original.comparisonDestructionMasks)
    for (name, artwork) in [("dos", Optional<URL>.none),
        ("mac", root.appendingPathComponent(".build/mac-artwork/export/lemmings")),
        ("amiga", root.appendingPathComponent(".build/amiga-artwork/export/lemmings"))] {
        let session = ClassicSession(simulation: start, width: scene.width, height: scene.height)
        let view = PlayfieldView(frame: CGRect(x: 0, y: 0, width: 640, height: 320))
        view.classicScene = scene; view.session = session; view.assets = assets
        view.palette = try ClassicLemmingPalette.inLevelVGA(terrainPalette: ground.terrainPalette)
        if let artwork {
            view.macScene = try ClassicMacScene(level: level, rendered: scene,
                artwork: ClassicMacArtwork(directory: artwork), groundSet: ground)
        }
        view.hdEffectsEnabled = false; view.phase = .playing
        var actor: SessionLemming?
        for _ in 0..<200 {
            actor = session.lemmings.first { session.canAssign(skillIndex: 3, to: $0.id) }
            if actor != nil { break }; session.tick()
        }
        guard let actor, session.assign(skillIndex: 3, to: actor.id) == nil,
              session.assign(skillIndex: 2, to: actor.id) == nil else { throw Failure.invalidPixels }
        view.viewport.zoom = 4
        view.viewport.scrollX = Double(actor.x) - 80
        view.viewport.scrollY = Double(actor.y) - 50
        for _ in 0..<250 where session.lemmings.first?.pose != .explosion { session.tick() }
        for age in 0...16 {
            if [0, 4, 8, 16].contains(age) {
                guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw Failure.invalidPixels }
                view.cacheDisplay(in: view.bounds, to: rep)
                guard let png = rep.representation(using: .png, properties: [:]) else { throw Failure.invalidPixels }
                try png.write(to: directory.appendingPathComponent("\(name)-bomb-\(age).png"))
                let world = CGPoint(x: actor.x, y: actor.y)
                let hit = view.viewport.levelPoint(from: view.viewport.viewPoint(fromLevel: world))
                guard hit == world else { throw Failure.invalidPixels }
            }
            session.tick()
        }
    }
    print("PASS pixel spray: opaque square pixels, moving frames and complete expiry")
}
