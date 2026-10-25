import AppKit
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

private struct Failure: Error { let message: String }
private func require(_ value: Bool, _ message: String) throws {
    if !value { throw Failure(message: message) }
}

@MainActor private func image(_ rgba: Data, width: Int, height: Int, logicalScale: CGFloat = 1) -> NSImage {
    let cg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: CGDataProvider(data: rgba as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    return NSImage(cgImage: cg, size: CGSize(width: CGFloat(width) / logicalScale, height: CGFloat(height) / logicalScale))
}

@MainActor private func indexed(width: Int, height: Int, pixels: [UInt8], opaque: [Bool], palette: [UInt8], mac: Bool) throws -> NSImage {
    let source = try SequelMacFrame(width: width, height: height, pixels: pixels, palette: palette, opaque: opaque)
    let frame = try mac ? SequelMacArtwork.reconstruct(source, category: .sprite) : source
    return image(Data(frame.rgba), width: frame.width, height: frame.height, logicalScale: mac ? 2 : 1)
}

private struct Actor {
    let sprite: NSImage
    let id: Int
    let x: CGFloat
    let y: CGFloat
    var mirrored = false
}

@MainActor private func render(_ actors: [Actor], zoom: CGFloat, backing: CGFloat = 1, stretch: CGFloat = 1,
                              enabled: Bool, crowd: LemmingCrowdPresentation = LemmingCrowdPresentation()) -> CGImage {
    let width = Int(110 * zoom * backing), height = Int(44 * zoom * backing * stretch)
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(srgbRed: 0.17, green: 0.13, blue: 0.10, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: backing, y: -backing)
    context.setShouldAntialias(false); context.interpolationQuality = .none
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    defer { NSGraphicsContext.restoreGraphicsState() }
    crowd.begin(tick: 10, zoom: zoom, enabled: enabled)
    for actor in actors {
        let world = CGRect(origin: CGPoint(x: actor.x, y: actor.y), size: actor.sprite.size)
        let rect = CGRect(x: actor.x * zoom, y: actor.y * zoom * stretch,
            width: world.width * zoom, height: world.height * zoom * stretch)
        crowd.drawBehind(actor.sprite, id: actor.id, rect: rect, worldRect: world, mirrored: actor.mirrored)
        let cg = actor.sprite.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        context.saveGState()
        context.translateBy(x: actor.mirrored ? rect.maxX : rect.minX, y: rect.maxY)
        context.scaleBy(x: actor.mirrored ? -1 : 1, y: -1)
        context.draw(cg, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }
    crowd.finish()
    return context.makeImage()!
}

private func bytes(_ image: CGImage) -> Data { image.dataProvider!.data! as Data }

@MainActor private func mobilePixels(_ actors: [Actor], enabled: Bool) throws -> MobilePixelFrame {
    let scale = actors.map { actor in
        CGFloat(actor.sprite.cgImage(forProposedRect: nil, context: nil, hints: nil)!.width) / actor.sprite.size.width
    }.max() ?? 1
    let width = Int(110 * scale), height = Int(44 * scale)
    var pixels = (0..<(width * height)).flatMap { _ -> [UInt8] in [43, 33, 25, 255] }
    var shadow = MobileCrowdShadow()
    for actor in actors {
        let cg = actor.sprite.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let w = Int(actor.sprite.size.width * scale), h = Int(actor.sprite.size.height * scale)
        let source = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        source.interpolationQuality = .none
        source.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let ink = source.data!.assumingMemoryBound(to: UInt8.self)
        let x = Int(actor.x * scale), y = Int(actor.y * scale)
        func offset(_ sx: Int, _ sy: Int) -> Int { (sy * w + (actor.mirrored ? w - sx - 1 : sx)) * 4 }
        if enabled {
            pixels.withUnsafeMutableBytes { destination in
                shadow.cast(spriteWidth: w, spriteHeight: h, x: x, y: y, width: width, height: height,
                    pixels: destination, opaque: { sx, sy in ink[offset(sx, sy) + 3] >= 128 })
            }
        }
        for sy in 0..<h where (0..<height).contains(y + sy) {
            for sx in 0..<w where (0..<width).contains(x + sx) {
                let from = offset(sx, sy), to = ((y + sy) * width + x + sx) * 4
                guard ink[from + 3] >= 128 else { continue }
                for channel in 0..<4 { pixels[to + channel] = ink[from + channel] }
            }
        }
    }
    return try MobilePixelFrame(width: width, height: height, rgba: Data(pixels))
}

@MainActor private func renderMobile(_ actors: [Actor], zoom: CGFloat, backing: CGFloat = 1,
                                    stretch: CGFloat = 1, enabled: Bool) throws -> CGImage {
    let frame = try mobilePixels(actors, enabled: enabled)
    let width = Int(110 * zoom * backing), height = Int(44 * zoom * backing * stretch)
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: backing, y: -backing * stretch)
    let viewport = MobileViewport(levelSize: .init(width: 110, height: 44),
        viewSize: .init(width: 110 * zoom, height: 44 * zoom), zoom: zoom)
    MobileBitmapRenderer.draw(MobileBitmapRenderer.image(frame)!, viewport: viewport, in: context)
    return context.makeImage()!
}

@MainActor private func checkMobileGeometry() throws {
    let rear = image(Data((0..<16).flatMap { _ -> [UInt8] in [90, 220, 110, 255] }), width: 4, height: 4)
    var frontPixels = (0..<16).flatMap { _ -> [UInt8] in [220, 100, 80, 255] }
    frontPixels[3] = 0
    let front = image(Data(frontPixels), width: 4, height: 4)
    for mirrored in [false, true] {
        for x: CGFloat in [-3, 0, 8, 107, 110, 120] {
            let actors = [Actor(sprite: rear, id: 1, x: x, y: 9),
                Actor(sprite: front, id: 2, x: x + 2, y: 9, mirrored: mirrored)]
            let result = try mobilePixels(actors, enabled: true)
            let original = try mobilePixels(actors, enabled: false)
            var changed = 0
            for y in 0..<result.height { for px in 0..<result.width {
                let i = (y * result.width + px) * 4
                guard result.rgba[i..<i + 4] != original.rgba[i..<i + 4] else { continue }
                changed += 1
                try require(original.rgba[i..<i + 4] == Data([90, 220, 110, 255]), "Mobile shadow touched terrain or foreground ink")
                try require(result.rgba[i..<i + 4] == Data([56, 136, 68, 255]), "Mobile shadow has the wrong strength or alpha")
                try require(CGRect(x: x + 1, y: 8, width: 6, height: 6).contains(CGPoint(x: CGFloat(px), y: CGFloat(y))), "Mobile shadow exceeded one native pixel")
            } }
            if x == 8 { try require(changed > 0, "Mobile overlap has no shadow") }
            try require(try mobilePixels([actors[0]], enabled: true) == mobilePixels([actors[0]], enabled: false), "Isolated mobile sprite changed")
            try require(try mobilePixels(actors + [actors[1], actors[1]], enabled: true) == result, "Dense mobile crowd accumulated black shading")
        }
        let actors = [Actor(sprite: rear, id: 1, x: 8, y: 9), Actor(sprite: front, id: 2, x: 10, y: 9, mirrored: mirrored)]
        for zoom: CGFloat in [1, 2, 2.5, 4, 7.25, 12] { for backing: CGFloat in [1, 2, 3] {
            try require(try bytes(renderMobile(actors, zoom: zoom, backing: backing, enabled: true))
                != bytes(renderMobile(actors, zoom: zoom, backing: backing, enabled: false)), "Mobile shadow disappeared with zoom or display scale")
        } }
    }
    print("PASS mobile shadows: rear ink only, intact foreground/terrain, transparency, mirrors, level edges, dense crowds and 1–12× zoom at 1×/2×/3× display scale")
}
private func save(_ cg: CGImage, _ path: URL) throws {
    try NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!.write(to: path)
}

@MainActor private func checkGeometry() throws {
    let solid = image(Data((0..<16).flatMap { _ -> [UInt8] in [90, 220, 110, 255] }), width: 4, height: 4)
    var cutout = (0..<16).flatMap { _ -> [UInt8] in [90, 220, 110, 255] }
    cutout[3] = 0
    let hole = image(Data(cutout), width: 4, height: 4)
    for zoom: CGFloat in [1, 2, 2.5, 4, 7.25, 12] {
        for backing: CGFloat in [1, 2] {
            for mirrored in [false, true] {
                let actors = [Actor(sprite: solid, id: 1, x: 8, y: 9), Actor(sprite: hole, id: 2, x: 9, y: 9, mirrored: mirrored)]
                let crowd = LemmingCrowdPresentation()
                let modern = render(actors, zoom: zoom, backing: backing, enabled: true, crowd: crowd)
                let original = render(actors, zoom: zoom, backing: backing, enabled: false)
                if zoom <= 2 {
                    try require(bytes(modern) == bytes(original), "Low zoom changed artwork")
                    try require(crowd.target(at: CGPoint(x: 10, y: 10), tick: 10, enabled: true) == nil, "Low zoom changed targeting")
                    continue
                }
                try require(bytes(modern) != bytes(original), "Overlapping sprites have no separating rim")
                let transparent = CGPoint(x: mirrored ? 12.5 : 9.5, y: 9.5)
                try require(crowd.target(at: transparent, tick: 10, enabled: true) == (mirrored ? nil : 1), "Transparent or mirrored margin hid a neighbour")
                try require(crowd.target(at: CGPoint(x: 10.5, y: 10.5), tick: 10, enabled: true) == 2, "Visible foreground ink did not win")
                try require(crowd.target(at: CGPoint(x: 8.5, y: 10.5), tick: 10, enabled: true) == 1, "Exposed background ink became unselectable")
                try require(crowd.target(at: CGPoint(x: 10.5, y: 10.5), tick: 11, enabled: true) == 2, "The displayed frame expired before the next draw")
                try require(crowd.target(at: CGPoint(x: 10.5, y: 10.5), tick: 12, enabled: true) == nil, "Stale frame remained selectable")
                try require(crowd.target(at: CGPoint(x: 10.5, y: 10.5), tick: 9, enabled: true) == nil, "Rewind retained a future target")
                try require(crowd.target(at: CGPoint(x: 10.5, y: 10.5), tick: 10, enabled: false) == nil, "Original cursor retained precision targeting")
                crowd.reset()
                try require(crowd.target(at: CGPoint(x: 10.5, y: 10.5), tick: 10, enabled: true) == nil, "Session reset retained a target")
                let lone = [actors[0]]
                try require(bytes(render(lone, zoom: zoom, backing: backing, enabled: true)) == bytes(render(lone, zoom: zoom, backing: backing, enabled: false)), "A lone sprite gained a rim")
            }
        }
    }
    // A rectangular foreground sprite makes the outside rim measurable.
    for backing: CGFloat in [1, 2] {
        let actors = [Actor(sprite: solid, id: 1, x: 8, y: 9), Actor(sprite: solid, id: 2, x: 10, y: 9)]
        let zoom: CGFloat = 6, scale = zoom * backing
        let modern = render(actors, zoom: zoom, backing: backing, enabled: true)
        let original = render(actors, zoom: zoom, backing: backing, enabled: false)
        let a = Array(bytes(modern)), b = Array(bytes(original))
        var changed = 0
        for y in 0..<modern.height { for x in 0..<modern.width {
            let index = (y * modern.width + x) * 4
            guard a[index..<index + 4] != b[index..<index + 4] else { continue }
            changed += 1
            let outer = CGRect(x: 10 * scale - 1, y: 9 * scale - 1, width: 4 * scale + 2, height: 4 * scale + 2)
            let inner = CGRect(x: 10 * scale, y: 9 * scale, width: 4 * scale, height: 4 * scale)
            let point = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
            try require(outer.contains(point) && !inner.contains(point), "Rim exceeded one physical pixel or changed sprite ink")
        } }
        try require(changed > 0, "No measurable rim")
    }
    print("PASS rim width, native ink, overlap, isolation, zoom, Retina, mirrors, transparent gaps, stale targets and reset")
}

@main struct CrowdAudit {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        try checkGeometry()
        try checkMobileGeometry()
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let output = root.appendingPathComponent(".build/crowd-presentation/renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var fixtures: [(String, [NSImage], CGFloat)] = []
        let classic = try ClassicMainDATAssets.load(from: root.appendingPathComponent("Content/lemming1.pc"))
        let animation = classic.animation(for: .walking, direction: .right)!
        fixtures.append(("classic", try animation.frames.map { image(try $0.rgba(using: ClassicLemmingPalette.panelVGA), width: $0.width, height: $0.height) }, 1))
        let mac = try ClassicMacArtwork(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        fixtures.append(("classic-mac", (0..<8).map { let f = mac.lemming(pose: .walking, left: false, tick: $0)!; return image(f.rgba, width: f.width, height: f.height, logicalScale: 2) }, 1))
        let l2 = root.appendingPathComponent("Sources/Ports/Lemm2")
        let l2bank = try Lemmings2Sprites(data: Data(contentsOf: l2.appendingPathComponent("VLEMMS.DAT")))
        let l2level = try Lemmings2Level(data: Data(contentsOf: l2.appendingPathComponent("LEVELS/LEVEL000.DAT")))
        let l2style = try Lemmings2Style(data: Data(contentsOf: l2.appendingPathComponent("STYLES/\(Lemmings2Campaign.styleNames[l2level.style]).DAT")))
        let l3 = root.appendingPathComponent("Sources/Ports/LEM3CD")
        let l3level = try Lemmings3Level(data: Data(contentsOf: l3.appendingPathComponent("LEVELS/LEVEL001.DAT")))
        let prefix = l3.appendingPathComponent(String(format: "GRAPHICS/TRIBE%03d", l3level.lemmingStyle))
        let l3bank = try Lemmings3Sprites(index: Data(contentsOf: prefix.appendingPathExtension("IND")), commands: Data(contentsOf: prefix.appendingPathExtension("CMP")))
        let l3style = try Lemmings3Style(directory: l3.appendingPathComponent("STYLES"), number: l3level.style)
        for reconstructed in [false, true] {
            let l2frames = try l2bank.animations["LM5C"]!.prefix(8).map { try indexed(width: $0.width, height: $0.height, pixels: $0.pixels, opaque: $0.opaque, palette: l2style.palette, mac: reconstructed) }
            fixtures.append(("l2\(reconstructed ? "-mac" : "")", l2frames, 1.2))
            let a = l3bank.animations[0]
            let l3frames = try a.frames.map { try indexed(width: a.width, height: a.height, pixels: $0.pixels, opaque: $0.opaque, palette: l3style.palette, mac: reconstructed) }
            fixtures.append(("l3\(reconstructed ? "-mac" : "")", l3frames, 1))
        }
        for (name, frames, stretch) in fixtures {
            let actors = (0..<30).map { i in Actor(sprite: frames[i % frames.count], id: i, x: 12 + CGFloat(i) * 2.4, y: 22 - frames[i % frames.count].size.height, mirrored: i % 3 == 0) }
            for zoom: CGFloat in [2, 4, 7.25] {
                for enabled in [false, true] {
                    let cg = render(actors, zoom: zoom, stretch: stretch, enabled: enabled)
                    try save(cg, output.appendingPathComponent("\(name)-\(zoom)-\(enabled ? "modern" : "original").png"))
                }
            }
            for zoom: CGFloat in [2, 4, 12] {
                for enabled in [false, true] {
                    let cg = try renderMobile(actors, zoom: zoom, stretch: stretch, enabled: enabled)
                    try save(cg, output.appendingPathComponent("mobile-\(name)-\(zoom)-\(enabled ? "shadow" : "original").png"))
                }
            }
        }
        print("PASS 36 native Classic, L2 and L3 crowd captures, including Macintosh artwork and L2 aspect ratio")
        print("PASS 36 mobile bitmap crowd captures, including maximum zoom and native/high-resolution artwork")
    }
}
